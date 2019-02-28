defmodule ExTimerTest do
  use ExUnit.Case
  require ExTimer
  doctest ExTimer

  test "ex_timer" do
    # you should be define `timers`(list) `elapsed`(float)
    state = %{timers: [], elapsed: 0, calls: 0}
    state = ExTimer.add(state, {:timeout_no_delay, :name, "min"}, 0)
    state = ExTimer.update(state, 0)
    assert state.calls == 1
    assert length(state.timers) == 0

    state = ExTimer.add(state, {:timeout_with_delay, :name, "woog"}, 400)
    state = ExTimer.update(state, 100 / 1000)
    assert state.calls == 1
    assert length(state.timers) != 0

    # after sleep for delay
    state = ExTimer.update(state, 300 / 1000)
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
    assert length(state.timers) == 1
    state = ExTimer.remove(state, {:timer1, :name, "111"})
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

    # clear value
    state = put_in(state.elapsed, 0)
    state = put_in(state.calls, 0)

    # delay
    state = ExTimer.add(state, {:timer4, 1, 2}, 2300)
    assert elem(hd(state.timers).msg, 0) == :timer4
    assert hd(state.timers).delay == 2.3
    state = ExTimer.add(state, {:timer5, 1, 2}, 1700)
    assert elem(hd(state.timers).msg, 0) == :timer5
    assert hd(state.timers).delay == 1.7
    state = ExTimer.add(state, {:timer6, 1, 2}, 1900)
    assert elem(hd(state.timers).msg, 0) == :timer5
    assert hd(state.timers).delay == 1.7

    # adjust
    assert state.elapsed == 0
    assert state.calls == 0
    assert length(state.timers) == 3
    state = ExTimer.update(state, 0)
    assert length(state.timers) == 3
    assert state.calls == 0

    # elapsed 1300ms
    state = ExTimer.update(state, 1.3)
    assert length(state.timers) == 3
    assert state.calls == 0
    # elapsed 400ms (total 1700ms)
    state = ExTimer.update(state, 0.4)
    assert elem(hd(state.timers).msg, 0) == :timer6
    assert length(state.timers) == 2
    assert state.calls == 1
    # elapsed 200ms (total 1900ms)
    state = ExTimer.update(state, 0.2)
    assert elem(hd(state.timers).msg, 0) == :timer4
    assert length(state.timers) == 1
    assert state.calls == 2
    # elapsed 600ms (total 2300ms)
    state = ExTimer.update(state, 0.6)
    assert length(state.timers) == 0
    assert state.calls == 3
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

  def handle_info({_arg0, _arg1, _arg2}, state) do
    state = put_in(state.calls, state.calls + 1)
    {:noreply, state}
  end
end
