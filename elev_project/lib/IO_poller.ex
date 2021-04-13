defmodule ButtonPoller do
  use Task

  def start_link(floor, button_type) do
    Task.start_link(__MODULE__, :button_poller, [floor, button_type, :released])
  end

  def child_spec(floor, button_type) do
    %{
      id: to_string(floor) <> "-" <> to_string(button_type),
      start: {__MODULE__, :start_link, [floor, button_type]},
      restart: :permanent,
      type: :worker
    }
  end

  def button_poller(floor, button_type, button_state) do
    Process.sleep(200)
    state = Driver.get_order_button_state(floor, button_type)

    case state do
      0 ->
        button_poller(floor, button_type, :released)

      1 ->
        if button_state == :released do
          IO.puts("Button pressed at: " <> to_string(floor) <> " " <> to_string(button_type))
          Order.send_order({0, floor, button_type}, :IO)
        end

        button_poller(floor, button_type, :pressed)

      {:error, :timeout} ->
        button_poller(floor, button_type, :released)
    end
  end
end

defmodule SensorPoller do
  use Task

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

  def sensor_poller(:floor_sensor, :between_floors) do
    sensor_poller(:floor_sensor, Driver.get_floor_sensor_state())
  end

  def sensor_poller(:floor_sensor, :idle) do
    case Driver.get_floor_sensor_state() do
      :between_floors -> sensor_poller(:floor_sensor, :between_floors)
      _other -> sensor_poller(:floor_sensor, :idle)
    end
  end

  def sensor_poller(:floor_sensor, floor) do
    IO.puts("Lift at " <> to_string(floor))

    Elevator.serve_floor(floor)

    Driver.set_floor_indicator(floor)
    sensor_poller(:floor_sensor, :idle)
  end

  def sensor_poller(:obstruction_sensor, :inactive) do
    case Driver.get_obstruction_switch_state() do
      :inactive ->
        sensor_poller(:obstruction_sensor, :inactive)

      :active ->
        IO.puts("Obstruction active!")
        Elevator.obstruction_switch(:active)
        sensor_poller(:obstruction_sensor, :active)
    end
  end

  def sensor_poller(:obstruction_sensor, :active) do
    case Driver.get_obstruction_switch_state() do
      :inactive ->
        IO.puts("Obstruction released!")
        Elevator.obstruction_switch(:inactive)
        sensor_poller(:obstruction_sensor, :inactive)

      :active ->
        sensor_poller(:obstruction_sensor, :active)
    end
  end
end
