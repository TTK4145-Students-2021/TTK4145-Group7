defmodule Order do

    @name :order_server
    @n_elevators 2
    @m_floors 3
    @stop_cost 1
    @travel_cost 1
    use GenServer

    def start_link(args) do
        GenServer.start_link(__MODULE__, args, name: @name)
    end 
    
    def send_IO_order(order) do
        %{floor: floor, type: order_type} = order
        elevator_number = get_elevator_number()

        {node_costs, bad_nodes1} = GenServer.multi_call(@name, {:calc_cost, floor, order_type, elevator_number}) #timeout #Get all the costs back from all the elevators
        #Do we need anything else here?
        {replies2, bad_nodes2} = GenServer.multi_call(Node.list(), @name, {:new_order, floor, order_type, node_costs}) #timeout #Sends the result of the auction to every elevator
        IO.inspect(node_costs)
        n = Enum.count(replies2)
        #How to handle single elevator mode?
        if (n>0 or order_type === :cab) do
            GenServer.call(@name, {:new_order, floor, order_type, node_costs})
        end
    end

    def get_order_map() do
        GenServer.call(@name, :get_order_map)
    end

    def get_elevator_number() do
        GenServer.call(@name, :get_elevator_number)
    end

    def get_active_orders(elevator_number, floor_range, order_map) do
        order_map |> Enum.filter(fn x -> elem(elem(x,0),0) === elevator_number end) 
                  |> Enum.filter(fn x -> elem(x,1) end) 
                  |> Enum.filter(fn x -> elem(elem(x,1),0) in floor_range end)
    end

    def calculate_cost(ordered_floor, order_map, current_floor, current_direction, elevator_number) do
        desired_direction = if ordered_floor < current_floor do :down else :up

        checking_floor = if desired_direction !== current_direction do
                            if current_direction == :down do 0 else @m_floors
                         else 
                            current_floor
                         end

        orders_to_be_served = get_active_orders(elevator_number, checking_floor..ordered_floor, order_map)

        max_floor = orders_to_be_served |> Enum.max_by(fn x -> elem(elem(x,0),1))
        min_floor = orders_to_be_served |> Enum.min_by(fn x -> elem(elem(x,0),1))

        checking_floor = if desired_direction !== current_direction do
                            if current_direction == :down do min_floor else max_floor
                         else 
                            current_floor
                         end
        
        travel_distance = current_floor + abs(current_floor - checking_floor) + abs(checking_floor - ordered_floor)
        n_stops = Enum.count(orders_to_be_served)

        cost = @travel_cost * travel_distance + @stop_cost * n_stops                   
    end
    
    def create_order_map(num_of_elevators, total_floors, order_map \\ %{}) do     
        order_map = Enum.reduce(ButtonPoller.Supervisor.get_all_buttons(total_floors), order_map,
                    fn element, order_map -> %{floor: floor, type: type} = element; 
                    Map.put(order_map, {num_of_elevators, floor, type}, false) end)

        if num_of_elevators > 1 do
            order_map = create_order_map(num_of_elevators-1, total_floors, order_map)
        else
            order_map
        end
    end
    
    @impl true
    def init(elevator_number) do
        order_map = create_order_map(@n_elevators, @m_floors)
        order_map = Map.put(order_map, :elevator_number, elevator_number)
        {:ok, order_map}
    end

    @impl true
    def handle_call({:new_order, floor, order_type, node_costs}, _from, order_map) do        
        {cost, winning_elevator} = Enum.min(Keyword.values(node_costs))
        order_map = Map.put(order_map, {winning_elevator, floor, order_type}, true)
        IO.inspect(order_map)
        {:reply, :ok, order_map}
    end

    @impl true
    def handle_call(:get_elevator_number, _from, order_map) do
        elevator_number = Map.fetch!(order_map, :elevator_number)
        {:reply, elevator_number, order_map}
    end


    @impl true
    def handle_call({:calc_cost, floor, :cab, elevator_that_sent_order}, _from, order_map) do
        current_elevator = Map.fetch!(order_map, :elevator_number)
        cost = if(current_elevator === elevator_that_sent_order) do 0 else 10 end
        {:reply, {cost, current_elevator}, order_map}
    end

    @impl true
    def handle_call({:calc_cost, floor, order_type, elevator_number}, _from, order_map) do
        # Calculate the cost of THIS elevator to take the given order
        current_elevator = Map.fetch!(order_map, :elevator_number)
        
        cost = calculate_cost(floor, order_type)

        {:reply, {cost, elevator_number}, order_map}
    end


    @impl true
    def handle_call(:get_order_map, _from, order_map) do
        {:reply, order_map, order_map}
    end

end