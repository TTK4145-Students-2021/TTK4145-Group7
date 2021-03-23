defmodule Order do

    @name :order_server
    @n_elevators 2
    @m_floors 3
    use GenServer

    def start_link(args) do
        GenServer.start_link(__MODULE__, args, name: @name)
    end 
    
    def send_IO_order(order) do
        %{floor: floor, type: order_type} = order
        elevator_number = get_elevator_number()

        {node_costs, bad_nodes1} = GenServer.multi_call(@name, {:calc_cost, floor, order_type}) #timeout #Get all the costs back from all the elevators
        #Do we need anything else here?
        {replies2, bad_nodes2} = GenServer.multi_call(Node.list(), @name, {:new_order, floor, order_type, node_costs}) #timeout #Sends the result of the auction
        IO.inspect(node_costs)
        n = Enum.count(replies2)

        if (n>0 or order_type === :cab) do
            GenServer.call(@name, {:new_order, floor, order_type, node_costs})
        end
    end

    def get_elevator_number() do
        GenServer.call(@name, :get_elevator_number)
    end

    def calculate_cost() do
        :rand.uniform(10)
    end
    
    def create_order_map(num_of_elevators, total_floors, order_map \\ %{}) do     
        order_map = Enum.reduce(ButtonPoller.Supervisor.get_all_buttons(total_floors), order_map,
                    fn element, order_map -> %{floor: floor, type: type} = element; 
                    Map.put(order_map, {num_of_elevators, floor, type}, 0) end)

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
        order_map = Map.put(order_map, {winning_elevator, floor, order_type}, 1)
        IO.inspect(order_map)
        {:reply, :ok, order_map}
    end

    @impl true
    def handle_call(:get_elevator_number, _from, order_map) do
        elevator_number = Map.fetch!(order_map, :elevator_number)
        {:reply, elevator_number, order_map}
    end

    @impl true
    def handle_call({:calc_cost, floor, order_type}, _from, order_map) do
        # Calculate the cost of THIS elevator to take the given order

        cost = calculate_cost()
        
        
        {:reply, {cost, Map.fetch!(order_map, :elevator_number)}, order_map}
    end
end