defmodule WatchDog do
  @name :order_watchdog
  @order_timeout 10

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

  # Orderi s {elev_num, floor, order_type}
  @impl true
  def handle_call({:new_order, order}, _from, state) do
    timer = Process.send_after(self(), {:work, order, @order_timeout}, 1_000)
    state = Map.put(state, order, @order_timeout)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_order_state}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info({:work, order, 0}, state) do
    # Send it back into order distribution?
    IO.puts("ORDER TIMED OUT")
    # Order.send_IO_order(order)
    {_time, state} = Map.pop(state, order)
    {:noreply, state}
  end

  @impl true
  def handle_info({:work, order, counter}, state) do
    IO.puts("Counting")
    counter = counter - 1
    IO.inspect(counter)

    timer = Process.send_after(self(), {:work, order, counter}, 1_000)
    state = Map.put(state, order, counter)
    {:noreply, state}
  end
end
