defmodule ExTimerTest do
  use ExUnit.Case
  require ExTimer
  doctest ExTimer

  test "ex_timer" do
    state = %{__timers__: [], call: 0}
    state = ExTimer.add(state, {:timeout_no_delay, :name, "min"}, 0)
    state = ExTimer.update(state)
    assert state.call == 1
    assert length(state.__timers__) == 0

    state = ExTimer.add(state, {:timeout_with_delay, :name, "woog"}, 400)
    state = ExTimer.update(state)
    assert state.call == 1
    assert length(state.__timers__) != 0
    :timer.sleep(500)

    # after sleep for delay
    state = ExTimer.update(state)
    assert state.call == 2
    assert length(state.__timers__) == 0
  end

  def handle_call({:timeout_no_delay, arg0, arg1}, state) do
    assert arg0 == :name
    assert arg1 == "min"
    state = put_in(state[:call], state.call + 1)
    {:noreply, state}
  end

  def handle_call({:timeout_with_delay, arg0, arg1}, state) do
    assert arg0 == :name
    assert arg1 == "woog"
    state = put_in(state[:call], state.call + 1)
    {:noreply, state}
  end
end
