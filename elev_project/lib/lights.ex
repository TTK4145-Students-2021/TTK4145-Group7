defmodule Lights do
  use Task

  def start_link(_args) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    {driving_elevator, order_map} = Order.get_order_state()

    orders_grouped_by_floor =
      Enum.group_by(
        order_map,
        fn {{elev_num, floor, type}, value} -> {floor, type} end,
        fn {{elev_num, floor, type}, value} -> value end
      )

    Enum.each(orders_grouped_by_floor, fn orders -> update_lights(orders, driving_elevator) end)

    Process.sleep(700)
    run()
  end

  def update_lights({{floor, type}, values}, driving_elevator) do
    case type do
      :hall_up -> set_light(floor, type, values)
      :hall_down -> set_light(floor, type, values)
      :cab -> set_light(floor, type, values, driving_elevator)
    end
  end

  def set_light(floor, :cab, values, driving_elevator) do
    case Enum.at(values, driving_elevator - 1) do
      true -> Driver.set_order_button_light(:cab, floor, :on)
      false -> Driver.set_order_button_light(:cab, floor, :off)
    end
  end

  def set_light(floor, order_type, values) do
    case Enum.any?(values) do
      true -> Driver.set_order_button_light(order_type, floor, :on)
      false -> Driver.set_order_button_light(order_type, floor, :off)
    end
  end
end
