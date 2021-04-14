defmodule ElevatorOrder do
  defstruct floor: nil, type: nil
end

defmodule ButtonPoller.Supervisor do
  @moduledoc """
  This sets up the supervisor for all the different buttons going over all the floors.
  """
  use Supervisor

  def start_link([top_floor]) do
    Supervisor.start_link(__MODULE__, {:ok, top_floor}, name: Button.Supervisor)
  end

  def init({:ok, top_floor}) do
    all_possible_orders = get_all_buttons(top_floor)

    children =
      Enum.map(all_possible_orders, fn button ->
        ButtonPoller.child_spec(button.floor, button.type)
      end)

    options = [strategy: :one_for_one, name: Button.Supervisor]
    Supervisor.init(children, options)
  end

  # From Jostein Løwer
  def get_all_button_types do
    [:hall_up, :hall_down, :cab]
  end

  def get_buttons_of_type(button_type, top_floor) do
    floor_list =
      case button_type do
        :hall_up -> 0..(top_floor - 1)
        :hall_down -> 1..top_floor
        :cab -> 0..top_floor
      end

    floor_list |> Enum.map(fn floor -> %ElevatorOrder{floor: floor, type: button_type} end)
  end

  def get_all_buttons(top_floor) do
    get_all_button_types()
    |> Enum.map(fn button_type -> get_buttons_of_type(button_type, top_floor) end)
    |> List.flatten()
  end
end
