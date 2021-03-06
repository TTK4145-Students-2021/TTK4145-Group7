defmodule Elevator do
  use GenStateMachine

  @name :elevator
  defstruct [:order, :floor, :direction]

<<<<<<< HEAD
  defstruct [:order, :floor, :direction, :state]

  use GenServer
  @moduledoc """
  Documentation for `Elevator`.
  """
=======
  # Client
  def start_link do
    GenStateMachine.start_link(__MODULE__, [], name: @name)
    GenStateMachine.cast(@name, :complete_init)
  end
>>>>>>> elev_FSM

  def start_moving(direction) do
    GenStateMachine.cast(@name, {:start_moving, direction})
  end

  def serve_floor(floor) do
    GenStateMachine.cast(@name, {:serve_floor,floor})
  end

  def close_door() do
    GenStateMachine.cast(@name, :close_door)
  end

  # Server (callbacks)
  @impl true
  def init(_) do
    # To do: Get to known state
    Driver.start_link([])
    data = %Elevator{
      order: nil, 
      floor: nil, 
      direction: nil
    }
    {:ok, :init, data}
  end

  @impl true
  def handle_event(:cast, {:start_moving, direction}, :idle, data) do
    Driver.set_motor_direction(direction)
    {:next_state, :moving, data}
  end

  @impl true
  def handle_event(:cast, {:start_moving, direction}, :door_open, data) do
    Driver.set_door_open_light(:off)
    Driver.set_motor_direction(direction)
    {:next_state, :moving, data}
  end

  @impl true
  def handle_event(:cast, :serve_floor, :idle, data) do
    Driver.set_door_open_light(:on)
    {:next_state, :door_open, data}
  end

  @impl true
  def handle_event(:cast, {:serve_floor, floor}, :moving, data) when floor == data.order do
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:on)
    Driver.set_floor_indicator(floor)
    new_data = Map.put(data, :floor, floor)
    {:next_state, :door_open, new_data}
  end

  @impl true
  def handle_event(:cast, {:serve_floor, floor}, :moving, data) do
    Driver.set_floor_indicator(floor)
    {:next_state, :moving, data}
  end

  @impl true
  def handle_event(:cast, :close_door, :door_open, data) do
    Driver.set_door_open_light(:on)
    {:next_state, :idle, data}
  end

  @impl true
  def handle_event(:cast, :complete_init, :init, data) do
    # go to a defined floor/state

    {:next_state, :idle, data}
  end
end


