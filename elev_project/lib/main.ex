defmodule Main do
    use Application

    def start(port, elevator_number, number_of_elevators) do
        Application.put_env(:elevator_project, :number_of_elevators, number_of_elevators)
        start(:normal, {port,elevator_number, number_of_elevators})
    end

    def stop() do
        Process.exit(self(), :kill)
    end

    def start(_type, args) do
        {port, elevator_number, _number_of_elevators} = args
        IO.inspect(args)
        ElevProject.Supervisor.start_link port,elevator_number
    end

end