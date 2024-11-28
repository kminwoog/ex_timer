Code.require_file("helper.exs", __DIR__)

defmodule ExTimerTest do
  use ExUnit.Case
  require ExTimer
  require Helper
  doctest ExTimer

  test "ex_timer" do
    # you should be define `timers`(list) `elapsed_ticks`(non_neg_integer)
    state = %{timer: 0, calls: 0}
    state = put_in(state.timer, ExTimer.new())
    state = Helper.add_timer(state, {:timeout_no_delay, :name, "min"}, 300)
    state = Helper.update_timer(state, 300)
    assert state.calls == 1
    assert length(state.timer.timers) == 0

    state = Helper.add_timer(state, {:timeout_with_delay, :name, "woog"}, 400)
    state = Helper.update_timer(state, 100)
    assert state.calls == 1
    assert length(state.timer.timers) != 0

    # after sleep for due_ms
    state = Helper.update_timer(state, 300)
    assert state.calls == 2
    assert length(state.timer.timers) == 0

    # remove timer with tuple
    state = Helper.add_timer(state, {:timer1, :name, "111"}, 400)
    assert length(state.timer.timers) == 1
    state = Helper.remove_timer(state, {:timer1, :name})
    assert length(state.timer.timers) == 1
    state = Helper.remove_timer(state, {:timer1, "1", "111"})
    assert length(state.timer.timers) == 1
    state = Helper.remove_timer(state, {:timer1, :name, "222"})
    assert length(state.timer.timers) == 1
    state = Helper.remove_timer(state, {:timer1, :name, "111"})
    assert length(state.timer.timers) == 0

    # remove timer with atom
    state = Helper.add_timer(state, :timer, 100)
    assert length(state.timer.timers) == 1
    state = Helper.remove_timer(state, :no_tuple)
    assert length(state.timer.timers) == 1
    state = Helper.remove_timer(state, :timer)
    assert length(state.timer.timers) == 0

    # clear timers
    state = Helper.add_timer(state, {:timer1, :name, "min1"}, 400)
    state = Helper.add_timer(state, {:timer1, :name, "min2"}, 400)
    assert length(state.timer.timers) == 2
    state = Helper.clear_timer(state)
    assert length(state.timer.timers) == 0

    # clear value
    state = put_in(state.calls, 0)

    # order by due_ms
    state = Helper.add_timer(state, {:timer4, 1, 2}, 300)
    assert elem(hd(state.timer.timers).msg, 0) == :timer4
    state = Helper.add_timer(state, {:timer5, 1, 2}, 100)
    assert elem(hd(state.timer.timers).msg, 0) == :timer5
    state = Helper.add_timer(state, {:timer6, 1, 2}, 900)
    assert elem(hd(state.timer.timers).msg, 0) == :timer5

    # elapsed_ticks 10ms
    state = Helper.update_timer(state, 10)
    assert length(state.timer.timers) == 3
    assert state.calls == 0
    # elapsed_ticks 100ms (total 90ms)
    state = Helper.update_timer(state, 90)
    assert elem(hd(state.timer.timers).msg, 0) == :timer4
    assert length(state.timer.timers) == 2
    assert state.calls == 1
    # elapsed_ticks 300ms (total 200ms)
    state = Helper.update_timer(state, 200)
    assert elem(hd(state.timer.timers).msg, 0) == :timer6
    assert length(state.timer.timers) == 1
    assert state.calls == 2
    # elapsed_ticks 900ms (total 600ms)
    state = Helper.update_timer(state, 600)
    assert length(state.timer.timers) == 0
    assert state.calls == 3
  end

  test "ex_timer - add timer in expired timeout handler" do
    state = %{timer: 0, calls: 0}
    state = put_in(state.timer, ExTimer.new())
    state = Helper.add_timer(state, {:on_timeout_repeat_1}, 100)
    assert length(state.timer.timers) == 1
    # call timeout handler {:on_timeout_repeat_1}
    state = Helper.update_timer(state, 100)
    assert state.calls == 1
    # add new timer(with no_delay) in timeout handler {:on_timeout_repeat_1}
    assert length(state.timer.timers) == 1
    state = Helper.update_timer(state, 100)
    assert state.calls == 2
    assert length(state.timer.timers) == 0
  end

  test "ex_timer - gurantee order of timers after expired timers" do
    state = %{timer: 0, calls: 0}
    state = put_in(state.timer, ExTimer.new())
    state = Helper.add_timer(state, {:some_timer3}, 300)
    state = Helper.add_timer(state, {:some_timer2}, 200)
    state = Helper.add_timer(state, {:some_timer1}, 100)
    state = Helper.add_timer(state, {:some_timer4}, 400)
    state = Helper.add_timer(state, {:some_timer5}, 500)
    assert length(state.timer.timers) == 5
    assert Enum.at(state.timer.timers, 0).msg == {:some_timer1}
    assert Enum.at(state.timer.timers, 1).msg == {:some_timer2}
    assert Enum.at(state.timer.timers, 2).msg == {:some_timer3}
    assert Enum.at(state.timer.timers, 3).msg == {:some_timer4}
    assert Enum.at(state.timer.timers, 4).msg == {:some_timer5}

    # call timeout handler
    state = Helper.update_timer(state, 300)
    assert state.calls == 3
    assert length(state.timer.timers) == 2

    # check order of timers
    assert Enum.at(state.timer.timers, 0).msg == {:some_timer4}
    assert Enum.at(state.timer.timers, 1).msg == {:some_timer5}
  end

  def handle_timer({:timeout_no_delay, arg0, arg1}, timer, state) do
    assert arg0 == :name
    assert arg1 == "min"
    state = put_in(state.calls, state.calls + 1)
    {state, timer}
  end

  def handle_timer({:timeout_with_delay, arg0, arg1}, timer, state) do
    assert arg0 == :name
    assert arg1 == "woog"
    state = put_in(state.calls, state.calls + 1)
    {state, timer}
  end

  def handle_timer({:on_timeout_repeat_1}, timer, state) do
    timer = ExTimer.add(timer, {:on_timeout_repeat_2}, 0)
    state = put_in(state.calls, state.calls + 1)
    {state, timer}
  end

  def handle_timer({:on_timeout_repeat_2}, timer, state) do
    state = put_in(state.calls, state.calls + 1)
    {state, timer}
  end

  def handle_timer({_some_timer}, timer, state) do
    state = put_in(state.calls, state.calls + 1)
    {state, timer}
  end

  def handle_timer({_arg0, _arg1, _arg2}, timer, state) do
    state = put_in(state.calls, state.calls + 1)
    {state, timer}
  end
end
