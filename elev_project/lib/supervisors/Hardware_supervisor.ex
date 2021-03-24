defmodule HardwareSupervisor do
    use Supervisor
    @floors 3

    def start_link(port,elev_num) do
        Supervisor.start_link(__MODULE__, {:ok,@floors,port,elev_num}, name: __MODULE__)
    end

    def init({:ok,floors,port,elev_num}) do
        children = [
            {Driver, [port]},
            {Elevator, []},
            {ButtonPoller.Supervisor, [floors]},
            {SensorPoller.Supervisor, []},
            {Order, [elev_num]},
            {Lights, []}
        ]

        opts = [strategy: :rest_for_one]
        Supervisor.init(children, opts)
    end
end