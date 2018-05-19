defmodule ExTimerTest do
  use ExUnit.Case
  doctest ExTimer

  test "greets the world" do
    assert ExTimer.hello() == :world
  end
end
