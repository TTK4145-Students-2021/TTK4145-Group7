defmodule ButtonPoller do

  @moduledoc """
  Module used for creating a process to monitor a single button.
  """
  @name :button_poller
  
  @polling_time Application.fetch_env!(:elevator_project, :polling_interval)

  use Task
  require Logger

  def start_link(floor, button_type) do
    Task.start_link(__MODULE__, :button_poller, [floor, button_type, :released])
  end

  @doc """
  Retrieve the child_spec for ButtonPoller
  """
  def child_spec(floor, button_type) do
    %{
      id: to_string(floor) <> "-" <> to_string(button_type),
      start: {__MODULE__, :start_link, [floor, button_type]},
      restart: :permanent,
      type: :worker
    }
  end

  @doc """
  Main loop that a ButtonPoller runs through.
  """
  def button_poller(floor, button_type, button_state) do
    Process.sleep(@polling_time)
    state = Driver.get_order_button_state(floor, button_type)

    %{
      direction: _elevator_direction,
      floor: elevator_current_floor,
      order: _elevator_current_order,
      obstruction: _obstruction,
    } = Elevator.get_elevator_state()
    new_button_state = 
      cond do
        state === 0 ->
          :released

        state === 1 and button_state == :released ->
          Logger.info("Button pressed at: " <> to_string(floor) <> " " <> to_string(button_type))
          if elevator_current_floor !== nil do Order.send_order({:elevator_number, floor, button_type}, @name) end
          :pressed
        
        state === 1 ->
          :pressed
      end

    button_poller(floor, button_type, new_button_state)
  end
end

defmodule SensorPoller do
  @moduledoc """
  Module used to poll the sensors of the Driver hardware.
  """
  use Task
  require Logger

  @polling_time Application.fetch_env!(:elevator_project, :polling_interval)

  def start_link(sensor_type) do
    case sensor_type do
      :floor_sensor ->
        Task.start_link(__MODULE__, :sensor_poller, [sensor_type, :between_floors])

      :obstruction_sensor ->
        Task.start_link(__MODULE__, :sensor_poller, [
          sensor_type,
          Driver.get_obstruction_switch_state()
        ])
    end
  end

  def child_spec(sensor_type) do
    %{
      id: to_string(sensor_type),
      start: {__MODULE__, :start_link, [sensor_type]},
      restart: :permanent,
      type: :worker
    }
  end

  @doc """
  Starts a sensor poller for a `:floor_sensor` or `:obstruction_sensor`.
  """
  def sensor_poller(:floor_sensor, :between_floors) do
    Process.sleep(@polling_time)
    sensor_poller(:floor_sensor, Driver.get_floor_sensor_state())
  end

  def sensor_poller(:floor_sensor, :poller_idle) do
    Process.sleep(@polling_time)
    case Driver.get_floor_sensor_state() do
      :between_floors -> sensor_poller(:floor_sensor, :between_floors)
      _other -> sensor_poller(:floor_sensor, :poller_idle)
    end
  end

  def sensor_poller(:floor_sensor, floor) do
    Logger.info("Lift at " <> to_string(floor))
    Elevator.serve_floor(floor)
    Driver.set_floor_indicator(floor)

    sensor_poller(:floor_sensor, :poller_idle)
  end


  def sensor_poller(:obstruction_sensor, :inactive) do
    Process.sleep(@polling_time)
    case Driver.get_obstruction_switch_state() do
      :inactive ->
        sensor_poller(:obstruction_sensor, :inactive)

      :active ->
        Logger.info("Obstruction active!")
        Elevator.obstruction_switch(:active)
        sensor_poller(:obstruction_sensor, :active)
    end
  end

  def sensor_poller(:obstruction_sensor, :active) do
    Process.sleep(@polling_time)
    case Driver.get_obstruction_switch_state() do
      :inactive ->
        Logger.info("Obstruction released!")
        Elevator.obstruction_switch(:inactive)
        sensor_poller(:obstruction_sensor, :inactive)

      :active ->
        sensor_poller(:obstruction_sensor, :active)
    end
  end
end
