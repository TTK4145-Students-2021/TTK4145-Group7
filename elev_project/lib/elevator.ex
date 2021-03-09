defmodule Elevator do
  use GenStateMachine

  @name :elevator_machine
  defstruct [:order, :floor, :direction]

  # Client
  def start_link(args \\ []) do
    GenStateMachine.start_link(__MODULE__, args, name: @name)
  end

  def start_moving(direction) do
    GenStateMachine.cast(@name, {:start_moving, direction})
  end

  def serve_floor(floor) do
    GenStateMachine.cast(@name, {:serve_floor,floor})
  end

  def new_order(at_floor) do
    GenStateMachine.cast(@name, {:new_order, at_floor})
  end

  # Server (callbacks)
  @impl true
  def init(_) do
    data = %Elevator{
      order: nil, 
      floor: nil, 
      direction: nil
    }
    Driver.set_motor_direction(:down)
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
  def handle_event(:cast, {:serve_floor, floor}, :moving, data) when floor == data.order do
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:on)
    Process.send_after(@name, :close_door, 2_000)
    new_data = %{data | floor: floor, order: nil}
    {:next_state, :door_open, new_data}
  end

  @impl true
  def handle_event(:cast, {:serve_floor, floor}, :moving, data) do
    new_data = Map.put(data, :floor, floor)
    {:next_state, :moving, new_data}
  end

  @impl true
  def handle_event(:cast, {:serve_floor, floor}, :init, data) do
    Driver.set_motor_direction(:stop)
    new_data = Map.put(data, :floor, floor)
    {:next_state, :idle, new_data}
  end

  @impl true
  def handle_event(:info, :close_door, :door_open, data) do
    Driver.set_door_open_light(:off)
    {:next_state, :idle, data}
  end

  @impl true
  def handle_event(:cast, {:new_order, at_floor}, :idle, data) do
    new_data = data
    case at_floor < data.floor do
      true -> new_data = %{data | direction: :down}
              Driver.set_motor_direction(:down)
      false -> new_data = %{data | direction: :up}
              Driver.set_motor_direction(:up)
    end
    Driver.set_door_open_light(:off)
    new_data = %{data | order: at_floor}
    {:next_state, :moving, new_data}
  end

  @impl true
  def handle_event(:cast, {:new_order, at_floor}, :moving, data) do
    new_data = %{data | order: at_floor}
    {:next_state, :moving, new_data}
  end

  @impl true
  def handle_event(:cast, {:new_order, at_floor}, :door_open, data) do
    new_data = %{data | order: at_floor}
    {:next_state, :door_open, new_data}
  end
end