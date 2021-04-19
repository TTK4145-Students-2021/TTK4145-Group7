defmodule Elevator do
  @moduledoc """
  Implements a FSM to control the elevator. 
  """

  use GenStateMachine

  @name :elevator_state_machine

  @door_open_time             Application.fetch_env!(:elevator_project, :door_timer_interval)
  @try_to_close_door_interval Application.fetch_env!(:elevator_project, :try_to_close_door_interval)
  
  @doc """
  Struct used for holding data of one elevator. 
  """
  defstruct [:order, :floor, :direction, :obstruction]

  @doc """
  Starts the elevator FSM.
  """
  def start_link(args \\ []) do
    GenStateMachine.start_link(__MODULE__, args, name: @name)
  end

  @doc """
  Serve floor when elevator is at a floor. **WARNING** Do not call if elevator is between floors.
  """
  def serve_floor(floor) do
    GenStateMachine.cast(@name, {:serve_floor, floor})
  end

  @doc """
  Changes the floor the elevator tries to reach.
  """
  def new_order(at_floor) do
    GenStateMachine.cast(@name, {:new_order, at_floor})
  end

  @doc """
  Updates the obstruction state in elevator data. 
  """
  def obstruction_switch(obstruction_state) do
    GenStateMachine.cast(@name, {:update_obstruction, obstruction_state})
  end

  @doc """
  Returns the elevator's data. 
  """
  def get_elevator_data() do
    GenStateMachine.call(@name, :get_elevator_data)
  end

  @impl true
  def init(_) do
    data = %Elevator{
      order: nil,
      floor: nil,
      direction: nil,
      obstruction: nil
    }
    
    data = %{
      data | 
      obstruction: Driver.get_obstruction_switch_state(), 
      direction: :down
    }

    Driver.set_door_open_light(:off)
    Driver.set_motor_direction(:down)

    {:ok, :init, data}
  end

  @impl true
  def handle_event(:cast, {:serve_floor, floor}, :moving, data) when floor == data.order do
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:on)
    Order.order_completed(floor)

    Process.send_after(@name, :close_door, @door_open_time)

    {:next_state, :door_open, %{data | floor: floor, order: nil}}
  end

  @impl true
  def handle_event(:cast, {:serve_floor, floor}, :moving, data) do
    new_data =
      cond do
        floor > data.order ->
          Driver.set_motor_direction(:down)
          %{data | direction: :down}

        floor < data.order ->
          Driver.set_motor_direction(:up)
          %{data | direction: :up}
      end

    {:keep_state, %{new_data | floor: floor}}
  end

  @impl true
  def handle_event(:cast, {:serve_floor, floor}, :init, data) do
    Driver.set_motor_direction(:stop)

    {:next_state, :idle, %{data | floor: floor}}
  end

  @impl true
  def handle_event(:info, :close_door, :door_open, data) when data.obstruction === :active do
    Process.send_after(@name, :close_door, @try_to_close_door_interval)
    :keep_state_and_data
  end

  @impl true
  def handle_event(:info, :close_door, :door_open, data) do
    Driver.set_door_open_light(:off)

    {:next_state, :idle, data}
  end

  @impl true
  def handle_event(:cast, {:new_order, at_floor}, :idle, data) when at_floor === data.floor do
    Driver.set_door_open_light(:on)
    Order.order_completed(at_floor)

    Process.send_after(@name, :close_door, @door_open_time)

    {:next_state, :door_open, data}
  end
  
  @impl true
  def handle_event(:cast, {:new_order, at_floor}, :idle, data) do
    new_data =
      cond do
        at_floor < data.floor ->
          Driver.set_motor_direction(:down)
          %{data | direction: :down}

        at_floor > data.floor ->
          Driver.set_motor_direction(:up)
          %{data | direction: :up}
      end

    new_data = %{new_data | order: at_floor}
    {:next_state, :moving, new_data}
  end

  @impl true
  def handle_event(:cast, {:new_order, at_floor}, :moving, data) do
    Driver.set_motor_direction(data.direction)

    {:keep_state, %{data | order: at_floor}}
  end

  @impl true
  def handle_event(:cast, {:new_order, _at_floor}, _state, _data) do
    :keep_state_and_data
  end

  @impl true
  def handle_event(:cast, {:update_obstruction, obstruction_state}, _state, data) do
    {:keep_state, %{data | obstruction: obstruction_state}}
  end

  @impl true
  def handle_event({:call, from}, :get_elevator_data, _state, data) do
    {:keep_state_and_data, [{:reply, from, data}]}
  end
end