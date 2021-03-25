defmodule Lights do
    use Task

    def start_link(_args) do
        Task.start_link(__MODULE__, :run, [])
    end

    def run() do
        order_map = Order.get_order_map()
        {driving_elevator, order_map} = Map.pop(order_map, :elevator_number)
        Enum.each(order_map, fn order -> clear_lights(order) end)
        Enum.each(order_map, fn order -> update_light(order, driving_elevator) end)
        Process.sleep(700)
        run()
    end


    def clear_lights({{elevator_number, floor, order_type}, value}) do
        Driver.set_order_button_light(order_type, floor, :off) #Does a bit too much might need refactoring.
    end


    def update_light({{elevator_number, floor, order_type}, value}, driving_elevator) when elevator_number === driving_elevator do
        case value do
            true -> Driver.set_order_button_light(order_type, floor, :on)
            false -> #OTHING
        end
    end

    def update_light({{elevator_number, floor, order_type}, value}, driving_elevator) when order_type === :hall_up or order_type === :hall_down do
        case value do
            true -> Driver.set_order_button_light(order_type, floor, :on)
            false -> #NOTHING
        end
    end
    def update_light({{elevator_number, floor, order_type}, value}, driving_elevator) do
        #Do nothing baby
    end

end