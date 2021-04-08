defmodule Order do
  @name :order_server
  @n_elevators 2
  @m_floors 3
  @stop_cost 1
  @travel_cost 1
  use GenServer

  def start_link([args]) do
    {:ok, pid} = GenServer.start_link(__MODULE__, args, name: @name)
    Process.send_after(@name, :check_for_orders, 500)
    {:ok, pid}
  end

  def send_IO_order(order) do
    %{floor: floor, type: order_type} = order
    elevator_number = get_elevator_number()

    # timeout #Get all the costs back from all the elevators
    {node_costs, bad_nodes_cost_calc} =
      GenServer.multi_call(@name, {:calc_cost, floor, order_type, elevator_number})

    # Do we need anything else here?
    # timeout #Sends the result of the auction to every elevator
    {acks, bad_nodes_ack} =
      GenServer.multi_call(Node.list(), @name, {:new_order, floor, order_type, node_costs})

    IO.puts("Cost:")
    IO.inspect(node_costs)
    n = Enum.count(acks)
    # How to handle single elevator mode?
    n = 1

    if n > 0 or order_type === :cab do
      GenServer.call(@name, {:new_order, floor, order_type, node_costs})
    end

    node_costs
  end

  def order_completed(floor) do
    # GenServer.cast(@name, {:order_completed, floor})
    GenServer.multi_call(@name, {:order_completed, floor, get_elevator_number()})
  end

  def get_order_state() do
    GenServer.call(@name, :get_order_state)
  end

  def get_elevator_number() do
    GenServer.call(@name, :get_elevator_number)
  end

  def get_active_orders(order_map, elevator_number, direction, filter, floor_range \\ 0..@m_floors) do
    filter_out_order_type =
      case filter do
        :filter_active -> if direction === :down do :hall_up else :hall_down end
        _filter -> :no_filter
      end
    
    order_map
    |> Enum.filter(fn x ->
      {{order_elevator_number, _, _}, _} = x
      order_elevator_number === elevator_number
    end)
    |> Enum.filter(fn x -> elem(x, 1) end)
    |> Enum.filter(fn x ->
      {{_, floor, _}, _} = x
      floor in floor_range
    end)
    |> Enum.filter(fn x ->
      {{_, _, order_type}, _} = x
      order_type !== filter_out_order_type
    end)
  end

  def calculate_cost(order, order_map, elevator_state) do
    
    {elevator_number, ordered_floor, order_type} = order
    
    %{
      direction: elevator_direction,
      floor: elevator_current_floor,
      obstruction: _obstruction,
      order: elevator_current_order
    } = elevator_state

    order_map = Map.put(order_map, order, true)

    {checking_floor, next_direction} =
      cond do       
        elevator_direction === :down ->
          {0, :up}

        elevator_direction === :up ->
          {@m_floors, :down}

        true ->
          {0, :up}
      end

    orders_to_be_served = get_active_orders(order_map, elevator_number, elevator_direction, :filter_active, elevator_current_floor..checking_floor) |> Enum.map(fn x -> elem(x,0) end)
    #IO.inspect(order_map)
    #IO.puts("Checking floor")
    #IO.inspect(checking_floor)
    #IO.puts("Elevator direction")
    #IO.inspect(elevator_direction)
    #IO.puts("elevator_current_floor..checking_floor")
    #IO.inspect(elevator_current_floor..checking_floor)
    #IO.inspect(orders_to_be_served)
    #IO.puts("Checking floor")
    #IO.inspect(checking_floor)
    

    if Enum.member?(orders_to_be_served, order) do
      n_stops = get_active_orders(order_map, elevator_number, elevator_direction, :filter_active, elevator_current_floor..ordered_floor) |>  Enum.map(fn x -> elem(x,0) end) |> Enum.count()
      #orders_to_be_served_temp = get_active_orders(order_map, elevator_number, elevator_direction, :filter_active, elevator_current_floor..ordered_floor) |> Enum.map(fn x -> elem(x,0) end)
      #n_stops = Enum.count(orders_to_be_served_temp)
      #IO.inspect(elevator_current_floor..ordered_floor)
      #IO.inspect(orders_to_be_served_temp)
      #IO.puts("n_stops: " <> to_string(n_stops))
      @travel_cost * abs(ordered_floor - elevator_current_floor) + @stop_cost * n_stops - 1 #-1 to not count stop at ordered floor
    else
      n_stops = Enum.count(orders_to_be_served)
      orders_to_be_served_no_filter = get_active_orders(order_map, elevator_number, elevator_direction, :no_filter, elevator_current_floor..checking_floor) |> Enum.map(fn x -> elem(x,0) end)
      
      extreme_floor =
      if elevator_direction == :down do
        orders_to_be_served_no_filter
        |> Enum.min_by(
          fn x ->
            elem(x,1)
          end,
          &>=/2,
          fn -> {0, @m_floors, :dummy} end)
        |> elem(1)
        |> min(elevator_current_floor)
      else
        orders_to_be_served_no_filter
        |> Enum.max_by(
          fn x ->
            elem(x,1)
          end,
          &>=/2,
          fn -> {0, 0, :dummy} end)
        |> elem(1)
        |> max(elevator_current_floor)
      end

      #IO.puts("n_stops: " <> to_string(n_stops))
      order_map = Map.merge(order_map, Map.new(orders_to_be_served, fn x -> {x, false} end))
      @travel_cost * abs(extreme_floor - elevator_current_floor) + @stop_cost * n_stops + 
        calculate_cost(order, order_map, %{direction: next_direction,floor: extreme_floor,obstruction: :dummy,order: elevator_current_order})
    end
  end

  def calculate_cost_old(ordered_floor, order_map, elevator_current_floor, elevator_direction, elevator_current_order, elevator_number) do
    # Better name for checking_floor?
    # @m_floors should maybe be exchanged by @m_floors - 1

    IO.inspect({ordered_floor, elevator_current_floor, elevator_direction, elevator_current_order, elevator_number})

    {checking_floor, desired_direction} =
      cond do
        elevator_direction == :down and ordered_floor > elevator_current_floor ->
          {0, :up}

        elevator_direction == :up and ordered_floor < elevator_current_floor ->
          {@m_floors, :down}

        elevator_current_order !== nil and ordered_floor === elevator_current_floor ->
          {elevator_current_order, if elevator_direction === :down do :up else :down end}

        true ->
          {elevator_current_floor, elevator_direction}
      end

    IO.inspect({checking_floor, desired_direction})

    orders_to_be_served =
      get_active_orders(
        order_map,
        elevator_number,
        elevator_direction,
        :filter_active,
        elevator_current_floor..checking_floor
      )
      |> Enum.concat(
        get_active_orders(
          order_map,
          elevator_number,
          desired_direction,
          :filter_active,
          checking_floor..ordered_floor
        )
      )
      |> Enum.dedup()
      |> Enum.filter(fn x ->
        {{_, floor, _}, _} = x
        floor !== ordered_floor
      end)

    IO.inspect(orders_to_be_served)

    max_floor =
      orders_to_be_served
      |> Enum.max_by(
        fn x ->
          {{_, floor, _}, _} = x
          floor
        end,
        &>=/2,
        fn -> {{0, 0, :dummy}, false} end
      )
      |> elem(0)
      |> elem(1)
      |> List.duplicate(1)
      |> Enum.concat([elevator_current_floor, ordered_floor])
      |> Enum.max()

    min_floor =
      orders_to_be_served
      |> Enum.min_by(
        fn x ->
          {{_, floor, _}, _} = x
          floor
        end,
        &>=/2,
        fn -> {{0, @m_floor, :dummy}, false} end
      )
      |> elem(0)
      |> elem(1)
      |> List.duplicate(1)
      |> Enum.concat([elevator_current_floor, ordered_floor])
      |> Enum.min()

    checking_floor =
      if elevator_direction == :down do
        min_floor
      else
        max_floor
      end

    travel_distance = abs(elevator_current_floor - checking_floor) + abs(checking_floor - ordered_floor)

    # Does not count stop at ordered floor, but counts stop at current floor if the order is not cleared.
    n_stops = Enum.count(orders_to_be_served)

    @travel_cost * travel_distance + @stop_cost * n_stops
  
  end

  def create_order_map(num_of_elevators, total_floors, order_map \\ %{}) do
    order_map =
      Enum.reduce(ButtonPoller.Supervisor.get_all_buttons(total_floors), order_map, fn element,
                                                                                       order_map ->
        %{floor: floor, type: type} = element
        Map.put(order_map, {num_of_elevators, floor, type}, false)
      end)

    if num_of_elevators > 1 do
      order_map = create_order_map(num_of_elevators - 1, total_floors, order_map)
    else
      order_map
    end
  end

  @impl true
  def init(elevator_number) do
    order_map = create_order_map(@n_elevators, @m_floors)
    state = {elevator_number, order_map}
    {:ok, state}
  end

  @impl true
  def handle_call(
        {:new_order, floor, order_type, node_costs},
        _from,
        {elevator_number, order_map}
      ) do
    {winning_elevator, cost} =
      Enum.min_by(Keyword.values(node_costs), fn x ->
        {_, cost} = x
        cost
      end)

    order_map = Map.put(order_map, {winning_elevator, floor, order_type}, true)
    {:reply, :ok, {elevator_number, order_map}}
  end

  @impl true
  def handle_call(:get_elevator_number, _from, {elevator_number, order_map}) do
    {:reply, elevator_number, {elevator_number, order_map}}
  end

  @impl true
  def handle_call({:calc_cost, ordered_floor, :cab, elevator_that_sent_order}, _from, {elevator_number, order_map}) do
    cost =
      if(elevator_number === elevator_that_sent_order) do
        calculate_cost({elevator_that_sent_order,ordered_floor, :cab}, order_map, Elevator.get_elevator_state())
      else
        100
      end

    {:reply, {elevator_number, cost}, {elevator_number, order_map}}
  end

  @impl true
  def handle_call(
        {:calc_cost, ordered_floor, order_type, elevator_that_sent_order},
        _from,
        {elevator_number, order_map}
      ) do

    cost = calculate_cost({elevator_that_sent_order,ordered_floor, order_type}, order_map, Elevator.get_elevator_state())

    {:reply, {elevator_number, cost}, {elevator_number, order_map}}
  end

  @impl true
  def handle_call(:get_order_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(
        {:order_completed, floor, elevator_number},
        _from,
        {current_elevator, order_map}
      ) do
    order_map = Map.put(order_map, {elevator_number, floor, :hall_down}, false)
    order_map = Map.put(order_map, {elevator_number, floor, :cab}, false)
    order_map = Map.put(order_map, {elevator_number, floor, :hall_up}, false)
    {:reply, :ok, {current_elevator, order_map}}
  end

  @impl true
  def handle_info(:check_for_orders, {current_elevator, order_map}) do
    elevator_state = Elevator.get_elevator_state()

    %{
      direction: elevator_direction,
      floor: elevator_current_floor,
      obstruction: _obstruction,
      order: elevator_current_order
    } = elevator_state
    
    active_orders = get_active_orders(order_map, current_elevator, elevator_direction, :no_filter)

    destination =
      if Enum.count(active_orders) > 0 do
        cost = []

        costs =
          Enum.reduce(active_orders, cost, fn order, cost ->
            {{_elev_nr, ordered_floor, order_type}, _active} = order

            cost ++
              [
                {calculate_cost(
                   {current_elevator,ordered_floor,order_type},
                   order_map,
                   Elevator.get_elevator_state()
                 ), ordered_floor}
              ]
          end)

        {min_cost, dest} = Enum.min(costs)
        Process.send_after(@name, :check_for_orders, 750)
        dest
      else
        Process.send_after(@name, :check_for_orders, 750)
        nil
      end

    Elevator.new_order(destination)
    {:noreply, {current_elevator, order_map}}
  end
end
