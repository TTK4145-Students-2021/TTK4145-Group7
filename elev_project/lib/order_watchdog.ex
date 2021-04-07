defmodule WatchDog do
  @name :order_watchdog
  @order_timeout 10_000

  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, "test", name: @name)
  end

  @impl true

  def init(_args) do
    # Backup here?
    state = %{}
    {:ok, state}
  end

  def new_order(order) do
    GenServer.call(@name, {:new_order, order})
  end

  def get_order_states() do
    GenServer.call(@name, {:get_order_state})
  end

  def complete_order(order) do
    GenServer.cast(@name, {:stop_timer, order})
  end

   @impl true
  def handle_call({:new_order, order}, _from, state) do
    timer = Process.send_after(self(), {:timed_out, order}, @order_timeout)
    state = Map.put(state, order, timer)
    IO.inspect state
    {:reply, :ok, state}
  end
  
  @impl true
  def handle_cast({:stop_timer, order}, state) do
    {timer, state} = Map.pop!(state, order)
    Process.cancel_timer(timer)
    IO.puts "REMOVED"
    IO.inspect state
    {:noreply, state}
  end

  @impl true
  def handle_info({:timed_out, order}, state) do
    IO.puts "Order timed out"
    {_val, state} = Map.pop(state, order)
    IO.inspect state
    # send to order
    {:noreply, state}
  end
  
  # Orderi s {elev_num, floor, order_type}


#   @impl true
#   def handle_call({:new_order, order}, _from, state) do
#     timer = Process.send_after(self(), {:work, order, @order_timeout}, 1_000)
#     state = Map.put(state, order, {@order_timeout, :timer_active})
#     {:reply, :ok, state}
#   end

 

#   @impl true
#   def handle_call({:get_order_state}, _from, state) do
#     {:reply, state, state}
#   end

#   @impl true
#   def handle_info({:work, order, 0}, state) do
#     # Send it back into order distribution?
#     IO.puts("ORDER TIMED OUT")
#     # Order.send_IO_order(order)
#     {_time, state} = Map.pop(state, order)
#     {:noreply, state}
#   end
  
#   @impl true
#   def handle_info({:work, order, counter}, state) do
#     IO.puts("Counting")
#     counter = counter - 1
#     IO.inspect(state)

#     timer = Process.send_after(self(), {:work, order, counter}, 1_000)
#     state = Map.put(state, order, counter)
#     {:noreply, state}
#   end
end
