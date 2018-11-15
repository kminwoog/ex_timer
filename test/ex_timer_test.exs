defmodule ExTimerTest do
  use ExUnit.Case
  require ExTimer
  doctest ExTimer

  test "ex_timer" do
    # you should be define `timers`(list)
    state = %{timers: [], calls: 0}
    state = ExTimer.add(state, {:timeout_no_delay, :name, "min"}, 0)
    state = ExTimer.update(state)
    assert state.calls == 1
    assert length(state.timers) == 0

    state = ExTimer.add(state, {:timeout_with_delay, :name, "woog"}, 400)
    state = ExTimer.update(state)
    assert state.calls == 1
    assert length(state.timers) != 0
    :timer.sleep(500)

    # after sleep for delay
    state = ExTimer.update(state)
    assert state.calls == 2
    assert length(state.timers) == 0

    # remove timer with tuple
    state = ExTimer.add(state, {:timer1, :name, "111"}, 400)
    assert length(state.timers) == 1
    state = ExTimer.remove(state, {:timer1, :name})
    assert length(state.timers) == 1
    state = ExTimer.remove(state, {:timer1, "1", "111"})
    assert length(state.timers) == 1
    state = ExTimer.remove(state, {:timer1, :name, "222"})
    assert length(state.timers) == 0

    # remove timer with atom
    state = ExTimer.add(state, :timer, 100)
    assert length(state.timers) == 1
    state = ExTimer.remove(state, :no_tuple)
    assert length(state.timers) == 1
    state = ExTimer.remove(state, :timer)
    assert length(state.timers) == 0

    # clear timers
    state = ExTimer.add(state, {:timer1, :name, "min1"}, 400)
    state = ExTimer.add(state, {:timer1, :name, "min2"}, 400)
    assert length(state.timers) == 2
    state = ExTimer.clear(state)
    assert length(state.timers) == 0
  end

  def handle_info({:timeout_no_delay, arg0, arg1}, state) do
    assert arg0 == :name
    assert arg1 == "min"
    state = put_in(state.calls, state.calls + 1)
    {:noreply, state}
  end

  def handle_info({:timeout_with_delay, arg0, arg1}, state) do
    assert arg0 == :name
    assert arg1 == "woog"
    state = put_in(state.calls, state.calls + 1)
    {:noreply, state}
  end
end
