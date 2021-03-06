defmodule Elevator_FSM do
  use GenStateMachine

  @name :elevator_FSM
  
  # Client
  def start_link do
    GenStateMachine.start_link(__MODULE__, [], name: @name)
    GenStateMachine.cast(@name, :complete_init)
  end

  def init(_) do
    # To do: Get to known state
    Driver.start_link([])
    data = %{order: nil, floor: nil, direction: nil}
    {:ok, :init, data}
  end

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
  def handle_event(:cast, {:start_moving, direction}, :idle, data) do
    Driver.set_motor_direction(direction)
    {:next_state, :moving, data}
  end

  def handle_event(:cast, :serve_floor, :idle, data) do
    Driver.set_door_open_light(:on)
    {:next_state, :door_open, data}
  end

  def handle_event(:cast, {:serve_floor, floor}, :moving, data) when floor == data.order do
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:on)
    Driver.set_floor_indicator(floor)
    {:next_state, :door_open, data}
  end

  def handle_event(:cast, {:serve_floor, floor}, :moving, data) do
    Driver.set_floor_indicator(floor)
    {:next_state, :moving, data}
  end

  def handle_event(:cast, :close_door, :door_open, data) do
    Driver.set_door_open_light(:on)
    {:next_state, :idle, data}
  end

  def handle_event(:cast, :complete_init, :init, data) do
    # go to a defined floor/state

    {:next_state, :idle, data}
  end
end


