defmodule Elevator_FSM do
  @behaviour :gen_statem

  # Client

  def start_link do
    :gen_statem.start_link( __MODULE__, {idle, data})
  end

  @impl :gen_statem
  def init(_), do
    # To do: Get to known state
     {:ok, :idle, nil}

  @impl :gen_statem
  def callback_mode, do: :handle_event_function

  def start_moving(pid, direction:) do
    GenStateMachine.cast(pid, :start_moving, direction:)
  end

  def serve_floor(pid) do
    GenStateMachine.cast(pid, :serve_floor)
  end

  def close_door(pid) do
    GenStateMachine.cast(pid, :close_door)
  end

  # Server (callbacks)

  @impl :gen_statem
  def handle_event(cast, :idle, :start_moving, data, direction:) do
    Driver.set_motor_direction(direction:)
    {:next_state, :moving}
  end

  def handle_event(cast, :idle, :serve_floor, data) do
    Driver.set_door_open_light(:on)
    {:next_state, :door_open}
  end

  def handle_event(cast, :moving, :serve_floor, data) do
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:on)
    {:next_state, :door_open}
  end

  def handle_event(cast, :door_open, :close_door, data) do
    Driver.set_door_open_light(:on)
    {:next_state, :idle}
  end
end


