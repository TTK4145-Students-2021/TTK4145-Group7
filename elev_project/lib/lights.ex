defmodule Lights do
    use Task

    def start_link() do
        Task.start_link(__MODULE__, :run, [])
    end

    def run() do
        order_map = Order.get_order_map()
        {driving_elevator, order_map} = Map.pop(order_map, :elevator_number)
        Enum.each(order_map, fn order -> update_light(order, driving_elevator) end)
        Process.sleep(200)
        run()
    end

    def update_light({{elevator_number, floor, order_type}, value}, driving_elevator) when elevator_number === driving_elevator do
        case value do
            1 -> Driver.set_order_button_light(order_type, floor, :on)
            0 -> Driver.set_order_button_light(order_type, floor, :off)
        end
    end

    def update_light({{elevator_number, floor, order_type}, value}, driving_elevator) when order_type === :hall_up or order_type === :hall_down do
        case value do
            1 -> Driver.set_order_button_light(order_type, floor, :on)
            0 -> Driver.set_order_button_light(order_type, floor, :off)
        end
    end
    def update_light({{elevator_number, floor, order_type}, value}, driving_elevator) do
        #Do nothing baby
    end

end