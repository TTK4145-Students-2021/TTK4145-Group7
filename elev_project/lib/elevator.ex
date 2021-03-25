defmodule Elevator do
  use GenStateMachine

  @name :elevator_machine
  @door_open_time 2_000
  defstruct [:order, :floor, :direction, :obstruction]

  # Client
  def start_link(args \\ []) do
    GenStateMachine.start_link(__MODULE__, args, name: @name)
  end

  def serve_floor(floor) do
    GenStateMachine.cast(@name, {:serve_floor, floor})
  end

  def new_order(at_floor) do
    GenStateMachine.cast(@name, {:new_order, at_floor})
  end

  def obstruction_switch(obstruction_state) do
    GenStateMachine.cast(@name, {:obstruction, obstruction_state})
  end

  def get_elevator_state() do
    GenStateMachine.call(@name, :get_elevator_state) #Need timeout?
  end

  # Server (callbacks)
  @impl true
  def init(_) do
    data = %Elevator{
      order: nil, 
      floor: nil, 
      direction: nil,
      obstruction: :off
    }
    Driver.set_motor_direction(:down)
    {:ok, :init, data}
  end

  @impl true
  def handle_event(:cast, {:serve_floor, floor}, :moving, data) when floor == data.order do
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:on)
    Process.send_after(@name, :close_door, @door_open_time)
    new_data = %{data | floor: floor, order: nil}
    {:next_state, :door_open, new_data}
  end

  @impl true
  def handle_event(:cast, {:serve_floor, floor}, :moving, data) do
    new_data = %{data | floor: floor}
    {:keep_state, new_data}
  end

  @impl true
  def handle_event(:cast, {:serve_floor, floor}, :init, data) do
    Driver.set_motor_direction(:stop)
    new_data = %{data | floor: floor}
    {:next_state, :idle, new_data}
  end

  @impl true
  def handle_event(:info, :close_door, :door_open, data) when data.obstruction === :off do
    Driver.set_door_open_light(:off)
    {:next_state, :idle, data}
  end

  @impl true
  def handle_event(:info, :close_door, :door_open, data) when data.obstruction === :on do
    Process.send_after(@name, :close_door, @door_open_time)
    {:next_state, :obstruction, data}
  end

  @impl true
  def handle_event(:info, :close_door, :obstruction, data) do
    Process.send_after(@name, :close_door, @door_open_time)
    :keep_state_and_data
  end

  @impl true
  def handle_event(:cast, {:new_order, at_floor}, :idle, data) when at_floor !== data.floor do
    #flawed but temporary :)
    new_data = case at_floor < data.floor do
      true  -> Driver.set_motor_direction(:down)
               %{data | direction: :down}
      false -> Driver.set_motor_direction(:up)
               %{data | direction: :up}
    end
    Driver.set_door_open_light(:off)
    new_data = %{new_data | order: at_floor}
    {:next_state, :moving, new_data}
  end

  @impl true
  def handle_event(:cast, {:new_order, at_floor}, :idle, data) do
    Driver.set_door_open_light(:on)
    Process.send_after(@name, :close_door, @door_open_time)
    {:next_state, :door_open, data}
  end

  # Beware this might make the elevator move out of bounds, hopefully fixed in order
  @impl true
  def handle_event(:cast, {:new_order, at_floor}, :moving, data) do
    new_data = %{data | order: at_floor}
    {:keep_state, new_data}
  end

  @impl true
  def handle_event(:cast, {:new_order, at_floor}, :door_open, data) do
    new_data = %{data | order: at_floor}
    {:keep_state, new_data}
  end

  @impl true
  def handle_event(:cast, {:new_order, at_floor}, _state, data) do
    :keep_state_and_data
  end

  @impl true
  def handle_event(:cast, {:obstruction, obstruction_state}, :door_open, data) when obstruction_state == :on do
    new_data = %{data | obstruction: :on}
    {:next_state, :obstruction, new_data}
  end

  @impl true
  def handle_event(:cast, {:obstruction, obstruction_state}, _state, data) when obstruction_state == :on do
    new_data = %{data | obstruction: :on}
    {:keep_state, new_data}
  end

  @impl true
  def handle_event(:cast, {:obstruction, obstruction_state}, :obstruction, data) when obstruction_state == :off do
    new_data = %{data | obstruction: :off}
    {:next_state, :door_open, new_data}
  end

  @impl true
  def handle_event(:cast, {:obstruction, obstruction_state}, _state, data) when obstruction_state == :off do
    new_data = %{data | obstruction: :off}
    {:keep_state, new_data}
  end



  @impl true
  def handle_event({:call, from}, :get_elevator_state, _state, data) do
    {:keep_state_and_data, [{:reply, from, data}]}
  end
end