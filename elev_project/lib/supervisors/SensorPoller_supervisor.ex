defmodule SensorPoller.Supervisor do
  @moduledoc """
  This supervisor supervises both the :floor_sensor and the :obstruction_sensor.
  """
  use Supervisor

  @doc """
  Starts all the SensorPollers.
  """
  def start_link([]) do
    Supervisor.start_link(__MODULE__, {:ok}, name: Sensor.Supervisor)
  end

  def init({:ok}) do
    options = [strategy: :one_for_one, name: Sensor.Supervisor]

    children =
      get_all_sensor_types() |> Enum.map(fn sensor -> SensorPoller.child_spec(sensor) end)

    Supervisor.init(children, options)
  end

  defp get_all_sensor_types do
    [:floor_sensor, :obstruction_sensor]
  end
end
