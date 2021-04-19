defmodule WatchDog do
  @moduledoc """
  A module that implements watchdog for the elevator orders. 
  """
  use GenServer
  require Logger

  @name :order_watchdog
  
  @order_timeout Application.fetch_env!(:elevator_project, :order_timeout)

  @doc """
  Starts the Watchdog module.
  """
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  @doc """
  Adds the given `order` to a map containing all orders to be timed. 
  After `@order_timeout`ms the Process sends a message to itself saying the order
  has been timed out, which in turn is resent back to the `Order` module
  """
  def new_order(order) do
    GenServer.call(@name, {:new_order, order})
  end

  @doc """
  Input is an order which is used as a key in the map containing all timers. 
  If the timer exists it is stopped and removed.
  """
  def complete_order(order) do
    {elevator_number, floor, _order_type} = order

    Enum.each([:hall_up,:hall_down], 
      fn type -> GenServer.cast(@name, {:stop_timer, {elevator_number, floor, type}}) end
    )
  end

  @impl true
  def init(_args) do
    state = %{}

    {:ok, state}
  end

  @impl true
  def handle_call({:new_order, order}, _from, state) do
    state = if !Map.has_key?(state, order) do
        timer = Process.send_after(self(), {:timed_out, order}, @order_timeout)
        Map.put(state, order, timer)
      else 
        state
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:stop_timer, order}, state) do
    {timer, state} = Map.pop(state, order, :non_existing)

    if timer !== :non_existing do
      Process.cancel_timer(timer)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:timed_out, order}, state) do
    Logger.info(Order_timed_out: order)

    {_val, state} = Map.pop(state, order)
    Task.start(Order, :send_order, [order, @name])

    {:noreply, state}
  end
end