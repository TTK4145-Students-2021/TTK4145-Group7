defmodule Main do
    use Application
    require Logger

    def start(port, elevator_number, number_of_elevators) do
        Application.put_env(:elevator_project, :number_of_elevators, number_of_elevators)
        Application.put_env(:elevator_project, :elevator_number, elevator_number)
        Logger.info("MY ELEVATOR NUMBER: " <> to_string(Application.fetch_env!(:elevator_project, :elevator_number)))
        start(:normal, {port,elevator_number, number_of_elevators})
    end

    def stop() do
        Process.exit(self(), :normal)
    end

    def start(_type, args) do
        {port, _elevator_number, _number_of_elevators} = args
        Network.boot_node()
        ElevProject.Supervisor.start_link port
    end
end