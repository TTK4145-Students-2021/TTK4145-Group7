defmodule Order do
  @moduledoc """
  Module that starts a `GenServer` keeping track of all the orders for every connected elevator.
  The `GenServer` state consists of a tuple containing the current elevator id and its complete
  `order_map`. An `order` entry in the map always has a key in the form `{elevator_number, floor, order_type}
  """
  @name :order_server

  @check_for_orders_interval  Application.fetch_env!(:elevator_project, :check_for_orders_interval) 
  @top_floor                  Application.fetch_env!(:elevator_project, :top_floor)    
  @stop_cost                  Application.fetch_env!(:elevator_project, :stop_cost)
  @travel_cost                Application.fetch_env!(:elevator_project, :travel_cost)
  @multi_call_timeout         Application.fetch_env!(:elevator_project, :multi_call_timeout)
  @initialization_time        Application.fetch_env!(:elevator_project, :initialization_time)
  @order_penalty              Application.fetch_env!(:elevator_project, :order_penalty)

  @max_cost (2*@top_floor * (@stop_cost+@travel_cost))

  use GenServer
  require Logger

  def start_link([args]) do
    {:ok, pid} = GenServer.start_link(__MODULE__, args, name: @name)
    Process.send_after(@name, :check_for_orders, @initialization_time)
    {:ok, pid}
  end

  @doc """
  Sends an order to the order server. Asks every connected elevator to calculate their costs,
  then sends the results to the connected elevators.
  """
  def send_order(order, from) do
    {order_elevator_number, floor, order_type} = order
    elevator_number = get_elevator_number()

    {node_costs, bad_nodes_cost_calc} =
      GenServer.multi_call([node() | Node.list()],@name, {:calc_cost, {elevator_number, floor, order_type}}, @multi_call_timeout)

    {winning_elevator, cost}  = 
      if from === :order_watchdog do
        node_costs
        |> Keyword.values()
        |> Enum.map(fn x -> {elev_n, cost} = x;
          cost = if elev_n === order_elevator_number do @max_cost + @order_penalty else cost end
          {elev_n, cost} end)
        |> Enum.min_by(fn x -> elem(x,1) end)
      else
        node_costs
        |> Keyword.values()
        |> Enum.min_by(fn x -> elem(x,1) end)
      end

    {acks, bad_nodes_new_order} =
      GenServer.multi_call(Node.list(), @name, {:new_order, {winning_elevator, floor, order_type}}, @multi_call_timeout)

    n = Enum.count(acks)
    
    n_elevators = Application.fetch_env!(:elevator_project, :number_of_elevators)
    if n > 0 or order_type === :cab or n_elevators === 1 or from === :order_watchdog do
      GenServer.call(@name, {:new_order, {winning_elevator, floor, order_type}})

      if from === :order_watchdog do
        GenServer.multi_call([node() | Node.list()],@name, {:order_timed_out, order}, @multi_call_timeout)
      end

    end

    if length(bad_nodes_cost_calc) > 0 or length(bad_nodes_new_order) > 0 do
      Logger.warning(%{bad_nodes_cost_calc: bad_nodes_cost_calc,
        bad_nodes_new_order: bad_nodes_new_order})
    end
    Logger.debug(%{node_costs: node_costs, winning_elevator: winning_elevator, cost: cost})

    node_costs
  end

  @doc """
  Asks order server to clear orders at the given floor.
  Clears the completed `order` from the `order_map`. Stops the WatchDog timer as well.
  """
  def order_completed(floor) do
    elev_num = get_elevator_number()
    GenServer.multi_call([node() | Node.list()],@name, {:order_completed, {elev_num, floor, :dummy}},@multi_call_timeout)
  end

  @doc """
  Function called when an elevator reconnects to the other nodes. Compares all the order maps
  and asks the `order_server` to update their `order_map`.
  """
  def compare_order_states() do  
    {good_nodes, bad_nodes} = GenServer.multi_call([node() | Node.list()], @name, :get_order_state, @multi_call_timeout)
    all_available_order_maps = Enum.reduce(Keyword.values(good_nodes), [], fn x, acc -> acc++[elem(x,1)] end)
    all_orders = Enum.reduce(all_available_order_maps, %{}, fn order_map, combined_orders ->
                              Map.merge(combined_orders, order_map, fn _order, ordered_in1, ordered_in2 ->
                                  ordered_in1 or ordered_in2
                                end)
                              end)

    if length(bad_nodes) > 0 do
      Logger.warning(%{bad_nodes: bad_nodes})
    end

    GenServer.cast(@name, {:update_order_map, all_orders})
  end

  @doc """
  Returns the `{elevator_number, order_map}` tuple from the order_server.
  """
  def get_order_state() do
    GenServer.call(@name, :get_order_state)
  end

  @doc """
  Returns only the `elevator_number`.
  """
  def get_elevator_number() do
    Application.fetch_env!(:elevator_project, :elevator_number)
  end


  @impl true
  def init(elevator_number) do
    n_elevators = Application.fetch_env!(:elevator_project, :number_of_elevators)
    order_map = create_order_map(n_elevators, @top_floor)
    state = {elevator_number, order_map}
    {:ok, state}
  end

  @doc """
  Tells this order_server what elevator has the lowest cost, adds it to the `order_map` and starts a WatchDog for this `order`.
  """
  @impl true
  def handle_call({:new_order, order}, _from, {elevator_number, order_map}) do
    {_elev_num, _floor, order_type} = order
    order_map = Map.put(order_map, order, true)

    n_elevators = Application.fetch_env!(:elevator_project, :number_of_elevators)
    if order_type !== :cab and n_elevators > 1 do
      Task.start(WatchDog, :new_order, [order])
    end
    
    {:reply, :ok, {elevator_number, order_map}}
  end

  @impl true
  def handle_call(:get_elevator_number, _from, {elevator_number, order_map}) do
    {:reply, elevator_number, {elevator_number, order_map}}
  end

  @impl true
  def handle_call({:calc_cost, {elevator_that_sent_order, ordered_floor, :cab}}, _from, {elevator_number, order_map}) do
    cost =
      if(elevator_number === elevator_that_sent_order) do
        calculate_cost({elevator_number, ordered_floor, :cab}, order_map, Elevator.get_elevator_state())
      else
        @max_cost + @order_penalty
      end

    {:reply, {elevator_number, cost}, {elevator_number, order_map}}
  end

  @impl true
  def handle_call({:calc_cost, order}, _from, {elevator_number, order_map}) do
    {_elevator_that_sendt_order, ordered_floor, order_type} = order

    cost = calculate_cost({elevator_number,ordered_floor,order_type}, order_map, Elevator.get_elevator_state())

    {:reply, {elevator_number, cost}, {elevator_number, order_map}}
  end

  @impl true
  def handle_call(:get_order_state, _from, state) do
    {:reply, state, state}
  end


  @impl true
  def handle_call({:order_completed, order}, _from, {current_elevator, order_map}) do
    {elevator_number, floor, _order_type} = order

    order_map = order_map
      |> Map.put({elevator_number, floor, :hall_down}, false)
      |> Map.put({elevator_number, floor, :cab}, false)
      |> Map.put({elevator_number, floor, :hall_up}, false)

    Task.start(WatchDog, :complete_order, [order])

    {:reply, :ok, {current_elevator, order_map}}
  end

  @impl true
  def handle_call({:order_timed_out, order}, _from, {current_elevator, order_map}) do
    order_map = Map.put(order_map, order, false)

    {:reply, :ok, {current_elevator, order_map}}
  end

  @doc """
  Periodically checks the `order_map` for orders with a lower cost, these orders are then
  sent to the elevator as the next order.
  """
  @impl true
  def handle_info(:check_for_orders, {current_elevator, order_map}) do
    elevator_state = Elevator.get_elevator_state()
    %{
      direction: elevator_direction,
      floor: elevator_current_floor,
      order: _elevator_current_order,
      obstruction: _obstruction,
    } = elevator_state

    active_orders = get_active_orders(order_map, current_elevator, elevator_direction, :no_filter)

    if Enum.count(active_orders) > 0 and elevator_current_floor !== nil do
      cost = []

      {_min_cost,destination} =
        active_orders
        |> Enum.reduce( cost, fn order, cost ->
          cost ++
            [
              {calculate_cost(
                  order,
                  order_map,
                  elevator_state
                ), elem(order,1)}
            ]
          end)
        |>Enum.min()

      Process.send_after(@name, :check_for_orders, @check_for_orders_interval)
      Elevator.new_order(destination)
    else
      Process.send_after(@name, :check_for_orders, @check_for_orders_interval)
    end

    {:noreply, {current_elevator, order_map}}
  end

  @impl true
  def handle_cast({:update_order_map, new_order_map}, {elevator_number, _order_map}) do
    {:noreply, {elevator_number, new_order_map}}
  end

  defp get_active_orders(order_map, elevator_number, direction, filter, floor_range \\ 0..@top_floor) do
    filter_out_order_type =
      case filter do
        :filter_active -> if direction === :down do :hall_up else :hall_down end
        _filter -> :no_filter
      end
    
    order_map
    |> Enum.filter(fn x ->
      {{order_elevator_number, _, _}, _} = x
      order_elevator_number === elevator_number end)
    |> Enum.filter(fn x -> elem(x, 1) end)
    |> Enum.filter(fn x ->
      {{_, floor, _}, _} = x
      floor in floor_range end)
    |> Enum.filter(fn x ->
      {{_, _, order_type}, _} = x
      order_type !== filter_out_order_type end)
    |> Enum.map(fn x -> elem(x,0) end)
  end

  defp get_max_floor(order_lst, elevator_current_floor, ordered_floor) do
    order_lst
    |> Enum.max_by(
      fn x -> elem(x,1) end,
      &>=/2,
      fn -> {0, 0, :dummy} end)
    |> elem(1)
    |> List.duplicate(1)
    |> Enum.concat([elevator_current_floor, ordered_floor])
    |> Enum.max()
  end

  defp get_min_floor(order_lst, elevator_current_floor, ordered_floor) do
    order_lst
    |> Enum.min_by(
      fn x -> elem(x,1) end,
      &>=/2,
      fn -> {0, @top_floor, :dummy} end)
    |> elem(1)
    |> List.duplicate(1)
    |> Enum.concat([elevator_current_floor, ordered_floor])
    |> Enum.min()
  end

  defp calculate_cost(order, order_map, elevator_state) do 
    {elevator_number, ordered_floor, order_type} = order
    
    %{
      direction: elevator_direction,
      floor: elevator_current_floor,
      obstruction: _obstruction,
      order: elevator_current_order
    } = elevator_state

    {checking_floor, desired_direction} =
      cond do
        elevator_current_order !== nil and ordered_floor === elevator_current_floor ->
          {elevator_current_order, if elevator_direction === :down do :up else :down end}

        (elevator_direction === :down and ordered_floor > elevator_current_floor) ->
          {0, :up}

        (elevator_direction === :up and ordered_floor < elevator_current_floor) ->
          {@top_floor, :down}

        order_type === :hall_up ->
          {0,:up}
        
        order_type === :hall_down ->
          {@top_floor, :down}
          
        true ->
          {elevator_current_floor, elevator_direction}
      end

    orders_to_be_served =
      get_active_orders(
        order_map,
        elevator_number,
        elevator_direction,
        :filter_active,
        elevator_current_floor..checking_floor)
      |> Enum.concat(
        get_active_orders(
          order_map,
          elevator_number,
          desired_direction,
          :filter_active,
          checking_floor..ordered_floor))
      |> Enum.uniq()
      |> Enum.filter(fn x ->
        {_, floor, _} = x
        floor !== ordered_floor and floor !== elevator_current_floor
        end)
      
    checking_floor =
      if elevator_direction == :down do
        get_min_floor(orders_to_be_served, elevator_current_floor, ordered_floor)
      else
        get_max_floor(orders_to_be_served, elevator_current_floor, ordered_floor)
      end
    
    travel_distance = abs(elevator_current_floor - checking_floor) + abs(checking_floor - ordered_floor)

    # Does not count stop at ordered floor
    n_stops = Enum.count(orders_to_be_served)

    Logger.debug(%{order: order, 
      elevator_state: elevator_state,
      orders_to_be_served: orders_to_be_served, 
      checking_floor: checking_floor,
      desired_direction: desired_direction,
      travel_distance: travel_distance,
      n_stops: n_stops})

    @travel_cost * travel_distance + @stop_cost * n_stops
  
  end

  defp create_order_map(num_of_elevators, top_floor, order_map \\ %{}) do
    order_map =
      Enum.reduce(ButtonPoller.Supervisor.get_all_buttons(top_floor), order_map, 
        fn x, order_map ->
        %{floor: floor, type: type} = x
        Map.put(order_map, {num_of_elevators, floor, type}, false)
      end)

    if num_of_elevators > 1 do
      create_order_map(num_of_elevators - 1, top_floor, order_map)
    else
      order_map
    end
  end
end
