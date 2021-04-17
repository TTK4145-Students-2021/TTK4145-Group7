defmodule ElevProject.Supervisor do
  use Supervisor

  def start_link(port) do
    Supervisor.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    children = [
      {HardwareSupervisor, [port]},
      {Order, []},
      {Lights, []},
      {Network, []},
      {WatchDog, []}
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end
