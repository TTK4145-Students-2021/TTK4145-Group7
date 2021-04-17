defmodule Lights do
  
  @moduledoc """
  Retrieves the order map from the order module, 
  and sets the lights accordingly by interfacing with driver
  """
  
  use Task
  
  @lights_update_interval Application.fetch_env!(:elevator_project, :lights_update_interval)

  def start_link(_args) do
    Task.start_link(__MODULE__, :run, [])
  end

  @doc """
  The main run function that recursively runs to update the lights
  """
  def run() do
    order_map = Order.get_order_map()
    driving_elevator = Application.fetch_env!(:elevator_project, :elevator_number)
    order_map 
    |> Enum.group_by(
      fn {{_elev_num, floor, type}, _is_ordered} -> {floor, type} end,
      fn {{elev_num, _floor, _type}, is_ordered} -> {elev_num, is_ordered} end
    )
    |> Enum.each( fn orders -> update_lights(orders, driving_elevator) end)

    Process.sleep(@lights_update_interval)
    run()
  end

  @doc """
  For every floor and type sets the light of a list of {elev, is_ordered} elements.
  """
  def update_lights({{floor, type}, is_ordered_list}, driving_elevator) do
    case type do
      :hall_up -> set_light(floor, type, is_ordered_list)
      :hall_down -> set_light(floor, type, is_ordered_list)
      :cab -> set_light(floor, type, driving_elevator, is_ordered_list)
    end
  end

  @doc """
  Sets the light of :cab orders
  """
  def set_light(floor, :cab, driving_elevator, is_ordered_list) do
    is_ordered_list 
    |> Enum.each(fn is_ordered -> 
        case is_ordered do
          {elev, true} when elev === driving_elevator -> Driver.set_order_button_light(:cab, floor, :on)
          {elev, false} when elev === driving_elevator-> Driver.set_order_button_light(:cab, floor, :off)
          {_elev, _value} ->  nil #Do nothing
        end 
      end)
  end

  @doc """
  Sets the light of :hall_up and :hall_down orders
  """
  def set_light(floor, order_type, is_ordered_list) do
    case Enum.any?(is_ordered_list, fn x -> elem(x,1) end) do
      true -> Driver.set_order_button_light(order_type, floor, :on)
      false -> Driver.set_order_button_light(order_type, floor, :off)
    end
  end
end
