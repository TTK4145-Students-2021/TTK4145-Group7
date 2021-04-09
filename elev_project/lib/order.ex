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

  def calculate_cost(ordered_floor, order_type, order_map, elevator_current_floor, elevator_direction, elevator_current_order, elevator_number) do
    # Better name for checking_floor?
    # @m_floors should maybe be exchanged by @m_floors - 1

    {checking_floor, desired_direction} =
      cond do
        elevator_current_order !== nil and ordered_floor === elevator_current_floor ->
          {elevator_current_order, if elevator_direction === :down do :up else :down end}

        (elevator_direction === :down and ordered_floor > elevator_current_floor) or order_type === :hall_up ->
          {0, :up}

        (elevator_direction === :up and ordered_floor < elevator_current_floor) or order_type === :hall_down ->
          {@m_floors, :down}

        true ->
          {elevator_current_floor, elevator_direction}
      end

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
        %{
            direction: elevator_direction,
            floor: elevator_current_floor,
            obstruction: _obstruction,
            order: elevator_current_order
          } = Elevator.get_elevator_state()
    cost =
      if(elevator_number === elevator_that_sent_order) do
        calculate_cost(ordered_floor, :cab, order_map, elevator_current_floor, elevator_direction, elevator_current_order, elevator_number)
      else
        100
      end

    {:reply, {elevator_number, cost}, {elevator_number, order_map}}
  end

  @impl true
  def handle_call(
        {:calc_cost, floor, order_type, elevator_that_sent_order},
        _from,
        {elevator_number, order_map}
      ) do
    %{
      direction: elevator_direction,
      floor: elevator_current_floor,
      obstruction: _obstruction,
      order: elevator_current_order
    } = Elevator.get_elevator_state()

    cost = calculate_cost(floor, order_type, order_map, elevator_current_floor, elevator_direction, elevator_current_order, elevator_number)

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
    %{
      direction: elevator_direction,
      floor: elevator_current_floor,
      obstruction: _obstruction,
      order: elevator_current_order
    } = Elevator.get_elevator_state()

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
                   ordered_floor,
                   order_type,
                   order_map,
                   elevator_current_floor,
                   elevator_direction,
                   elevator_current_order,
                   current_elevator
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
