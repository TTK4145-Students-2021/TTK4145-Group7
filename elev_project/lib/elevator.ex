defmodule Elevator do

  @name :elevator_FSM

  use GenServer
  @moduledoc """
  Documentation for `Elevator`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Elevator.hello()
      :world

  """

  # Client
  def start_link(_default) do
    GenServer.start_link(__MODULE__,[], name: @name)
  end

  def new_order() do
    GenServer.cast(@name, :new_order)

  end


  #Server (callbacks)
  @impl true
  def init(state) do
    #Driver.start_link([])
    {:ok, state}
  end


  @impl true
  def handle_cast(:new_order,state) do
    #Driver.set_stop_button_light(:on)
    {:noreply, state}
  end
end


