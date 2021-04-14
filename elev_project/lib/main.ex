defmodule Main do
    use Application

    def start(port, elevator_number, number_of_elevators) do
        Application.put_env(:elevator_project, :number_of_elevators, number_of_elevators)
        Application.put_env(:elevator_project, :elevator_number, elevator_number)
        IO.inspect(Application.fetch_env!(:elevator_project, :elevator_number), label: "MY ELEVATOR NUMBER")
        start(:normal, {port,elevator_number, number_of_elevators})
    end

    def stop() do
        Process.exit(self(), :kill)
    end

    def start(_type, args) do
        {port, elevator_number, _number_of_elevators} = args
        IO.inspect(args)

        Network.boot_node(to_string(elevator_number))
        ElevProject.Supervisor.start_link port,elevator_number
    end
end