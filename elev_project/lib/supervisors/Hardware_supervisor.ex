defmodule HardwareSupervisor do
  use Supervisor

  @floors Application.fetch_env!(:elevator_project, :top_floor)
  def start_link([port]) do
    Supervisor.start_link(__MODULE__, {:ok, @floors, port}, name: __MODULE__)
  end

  def init({:ok, floors, port}) do
    children = [
      {Driver, [port]},
      {Elevator, []},
      {ButtonPoller.Supervisor, [floors]},
      {SensorPoller.Supervisor, []}
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end
