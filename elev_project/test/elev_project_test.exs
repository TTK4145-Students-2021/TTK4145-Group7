defmodule ElevProjectTest do
  use ExUnit.Case
  doctest ElevProject

  test "greets the world" do
    assert ElevProject.hello() == :world
  end
end
