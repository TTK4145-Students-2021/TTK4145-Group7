defmodule Elevator do

  @name :elevator_FSM

  defstruct [:order, :floor, :direction, :state]

  use GenServer
  @moduledoc """
  Documentation for `Elevator`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Elevator.hello()
      :world

  """

  def start_link(_default) do
    GenServer.start_link(__MODULE__, [], name: @name)
    Driver.set_motor_direction(:down)
  end

  @impl true
  def init(state) do
    Driver.start_link([])
    state = %Elevator{
      order: nil,
      floor: nil,
      direction: nil,
      state: :init
    }
    {:ok, state}
  end

  # Client
  def new_order(floor) do
    GenServer.cast(@name, {:new_order, floor})
  end

  def floor_arrival(floor) do
    GenServer.cast(@name, {:floor_arrival, floor})
  end

  #Server (callbacks)
  @impl true
  def handle_cast({:new_order, floor}, state) do
    Driver.set_stop_button_light(:on)
    new_state = Map.put(state, :order, floor)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:floor_arrival, floor}, state) when state.state == :init do
    Driver.set_floor_indicator(floor)
    Driver.set_motor_direction(:stop)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:floor_arrival, floor}, state) when floor == state.order do
    Driver.set_motor_direction(:stop)
    Driver.set_floor_indicator(floor)
    Driver.set_door_open_light(:on)
    new_state = Map.put(state, :floor, floor)

    # Tell Order that order was completed

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:floor_arrival, floor}, state) do
    Driver.set_floor_indicator(floor)
    {:noreply, state}
  end
end


