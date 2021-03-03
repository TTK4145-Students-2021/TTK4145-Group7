defmodule ElevatorTest do
  use ExUnit.Case
  doctest Elevator

  test "greets the world" do
    assert Elevator.hello() == :world
  end
end
