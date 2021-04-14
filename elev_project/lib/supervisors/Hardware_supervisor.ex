defmodule HardwareSupervisor do
  use Supervisor

  def start_link([port]) do
    Supervisor.start_link(__MODULE__, {:ok, Application.fetch_env!(:elevator_project, :top_floor) , port}, name: __MODULE__)
  end

  def init({:ok, top_floor, port}) do
    children = [
      {Driver, [port]},
      {Elevator, []},
      {ButtonPoller.Supervisor, [top_floor]},
      {SensorPoller.Supervisor, []}
    ]

    opts = [strategy: :rest_for_one]
    Supervisor.init(children, opts)
  end
end
