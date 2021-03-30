defmodule SensorPoller.Supervisor do
  use Supervisor

  def start_link([]) do
    Supervisor.start_link(__MODULE__, {:ok}, name: Sensor.Supervisor)
  end

  def init({:ok}) do
    options = [strategy: :one_for_one, name: Sensor.Supervisor]

    children =
      get_all_sensor_types() |> Enum.map(fn sensor -> SensorPoller.child_spec(sensor) end)

    Supervisor.init(children, options)
  end

  def get_all_sensor_types do
    [:floor_sensor, :obstruction_sensor]
  end
end
