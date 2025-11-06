defmodule BetterStructTest do
  use ExUnit.Case
  doctest BetterStruct

  test "greets the world" do
    assert BetterStruct.hello() == :world
  end
end
