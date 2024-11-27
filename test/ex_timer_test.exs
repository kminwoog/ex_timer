defmodule ExTimerTest do
  use ExUnit.Case
  require ExTimer
  doctest ExTimer

  test "ex_timer" do
    # you should be define `timers`(list) `elapsed_ticks`(non_neg_integer)
    state = %{timers: [], elapsed_ticks: 0, calls: 0}
    state = ExTimer.add(state, {:timeout_no_delay, :name, "min"}, 0)
    state = ExTimer.update(state, 0)
    assert state.calls == 1
    assert length(state.timers) == 0

    state = ExTimer.add(state, {:timeout_with_delay, :name, "woog"}, 400)
    state = ExTimer.update(state, 100)
    assert state.calls == 1
    assert length(state.timers) != 0

    # after sleep for delay
    state = ExTimer.update(state, 300)
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
    state = put_in(state.elapsed_ticks, 0)
    state = put_in(state.calls, 0)

    # delay
    state = ExTimer.add(state, {:timer4, 1, 2}, 2300)
    assert elem(hd(state.timers).msg, 0) == :timer4
    assert hd(state.timers).delay == 2300
    state = ExTimer.add(state, {:timer5, 1, 2}, 1700)
    assert elem(hd(state.timers).msg, 0) == :timer5
    assert hd(state.timers).delay == 1700
    state = ExTimer.add(state, {:timer6, 1, 2}, 1900)
    assert elem(hd(state.timers).msg, 0) == :timer5
    assert hd(state.timers).delay == 1700

    # adjust
    assert state.elapsed_ticks == 0
    assert state.calls == 0
    assert length(state.timers) == 3
    state = ExTimer.update(state, 0)
    assert length(state.timers) == 3
    assert state.calls == 0

    # elapsed_ticks 1300ms
    state = ExTimer.update(state, 1300)
    assert length(state.timers) == 3
    assert state.calls == 0
    # elapsed_ticks 400ms (total 1700ms)
    state = ExTimer.update(state, 400)
    assert elem(hd(state.timers).msg, 0) == :timer6
    assert length(state.timers) == 2
    assert state.calls == 1
    # elapsed_ticks 200ms (total 1900ms)
    state = ExTimer.update(state, 200)
    assert elem(hd(state.timers).msg, 0) == :timer4
    assert length(state.timers) == 1
    assert state.calls == 2
    # elapsed_ticks 600ms (total 2300ms)
    state = ExTimer.update(state, 600)
    assert length(state.timers) == 0
    assert state.calls == 3
  end

  test "ex_timer - add timer in expired timeout handler" do
    state = %{timers: [], elapsed_ticks: 0, calls: 0}
    state = ExTimer.add(state, {:on_timeout_repeat_1}, 0)
    assert length(state.timers) == 1
    # call timeout handler {:on_timeout_repeat_1}
    state = ExTimer.update(state, 0)
    assert state.calls == 1
    # add new timer(with no_delay) in timeout handler {:on_timeout_repeat_1}
    assert length(state.timers) == 1
    state = ExTimer.update(state, 0)
    assert state.calls == 2
    assert length(state.timers) == 0
  end

  test "ex_timer - gurantee order of timers after expired timers" do
    state = %{timers: [], elapsed_ticks: 0, calls: 0}
    state = ExTimer.add(state, {:some_timer3}, 3)
    state = ExTimer.add(state, {:some_timer2}, 2)
    state = ExTimer.add(state, {:some_timer1}, 1)
    state = ExTimer.add(state, {:some_timer4}, 4)
    state = ExTimer.add(state, {:some_timer5}, 5)
    assert length(state.timers) == 5
    assert Enum.at(state.timers, 0).msg == {:some_timer1}
    assert Enum.at(state.timers, 1).msg == {:some_timer2}
    assert Enum.at(state.timers, 2).msg == {:some_timer3}
    assert Enum.at(state.timers, 3).msg == {:some_timer4}
    assert Enum.at(state.timers, 4).msg == {:some_timer5}

    # call timeout handler
    state = ExTimer.update(state, 3)
    assert state.calls == 3
    assert length(state.timers) == 2

    # check order of timers
    assert Enum.at(state.timers, 0).msg == {:some_timer4}
    assert Enum.at(state.timers, 1).msg == {:some_timer5}
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

  def handle_info({:on_timeout_repeat_1}, state) do
    state = ExTimer.add(state, {:on_timeout_repeat_2}, 0)
    state = put_in(state.calls, state.calls + 1)
    {:noreply, state}
  end

  def handle_info({:on_timeout_repeat_2}, state) do
    state = put_in(state.calls, state.calls + 1)
    {:noreply, state}
  end

  def handle_info({_some_timer}, state) do
    state = put_in(state.calls, state.calls + 1)
    {:noreply, state}
  end

  def handle_info({_arg0, _arg1, _arg2}, state) do
    state = put_in(state.calls, state.calls + 1)
    {:noreply, state}
  end
end
