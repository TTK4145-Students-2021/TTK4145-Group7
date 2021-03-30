defmodule ElevatorProject.Application do
  use Application

  def start(_type, args) do
    IO.puts("STARTING ELEVATOR")
    IO.inspect(args)

    [port, elevator_number] = args

    children = [
      {ElevProject.Supervisor, {port, elevator_number}}
    ]

    opts = [strategy: :one_for_one, name: ElevatorProject.Application]
    Supervisor.start_link(children, opts)
  end
end
