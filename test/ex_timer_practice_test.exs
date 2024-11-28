Code.require_file("helper.exs", __DIR__)

defmodule ExTimerPracticeTest do
  use ExUnit.Case
  require ExTimer
  require Helper

  test "ex_timer - use extra module" do
    state = ExtraTimer.start_timer(%{})
    assert state.calls == 0
    assert length(state.timer.timers) == 2

    # elasped 100 ticks(ms)
    state = Helper.update_timer(state, 100)
    assert state.calls == 1
    assert length(state.timer.timers) == 1

    # elasped 100 ticks(ms)
    state = Helper.update_timer(state, 100)
    assert state.calls == 2
    assert length(state.timer.timers) == 0
  end

  def handle_timer({:timeout_type1, module, function}, timer, state) do
    {state, timer} = apply(module, function, [state, timer])
    {state, timer}
  end

  def handle_timer({:timeout_type2, function_ref}, timer, state) do
    {state, timer} = function_ref.(state, timer)
    {state, timer}
  end
end

defmodule ExtraTimer do
  require ExTimer

  def start_timer(_state) do
    state = %{timer: 0, calls: 0}
    state = put_in(state.timer, ExTimer.new())
    state = Helper.add_timer(state, {:timeout_type1, ExtraTimer, :handle_timer_1}, 100)
    state = Helper.add_timer(state, {:timeout_type2, &handle_timer_2/2}, 200)
    state
  end

  def handle_timer_1(state, timer) do
    state = put_in(state.calls, state.calls + 1)
    {state, timer}
  end

  def handle_timer_2(state, timer) do
    state = put_in(state.calls, state.calls + 1)
    {state, timer}
  end
end
