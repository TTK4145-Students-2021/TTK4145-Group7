defmodule ElevProject.Supervisor do
    use Supervisor
    @floors 3
    def start_link() do
        Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
    end

    def init(:ok) do
        children = [
            {HardwareSupervisor, @floors}
        ]

        opts = [strategy: :one_for_one]
        Supervisor.init(children, opts)
    end
end