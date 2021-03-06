defmodule HardwareSupervisor do
    use Supervisor

    def start_link(floors) do
        Supervisor.start_link(__MODULE__, {:ok,floors}, name: __MODULE__)
    end

    def init({:ok,floors}) do
        children = [
            {Driver, []},
            {ButtonPoller.Supervisor, [floors]},
            {SensorPoller.Supervisor, []}
        ]

        opts = [strategy: :rest_for_one]
        Supervisor.init(children, opts)
    end
end