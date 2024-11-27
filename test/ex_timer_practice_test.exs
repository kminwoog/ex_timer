defmodule ExTimerPracticeTest do
  use ExUnit.Case
  require ExTimer

  test "ex_timer - use extra module" do
    # you should be define `timers`(list) `elapsed_ticks`(non_neg_integer)
    state = %{timers: [], elapsed_ticks: 0, calls: 0}

    state = ExtraTimer.start_timer(state)
    assert state.calls == 0
    assert length(state.timers) == 2

    # elasped 100 ticks(ms)
    state = ExTimer.update(state, 100)
    assert state.calls == 1
    assert length(state.timers) == 1

    # elasped 100 ticks(ms)
    state = ExTimer.update(state, 100)
    assert state.calls == 2
    assert length(state.timers) == 0
  end

  def handle_info({:timeout_type1, module, function}, state) do
    {:noreply, state} = apply(module, function, [state])
    {:noreply, state}
  end

  def handle_info({:timeout_type2, function_ref}, state) do
    {:noreply, state} = function_ref.(state)
    {:noreply, state}
  end
end

defmodule ExtraTimer do
  require ExTimer

  def start_timer(state) do
    state = ExTimer.add(state, {:timeout_type1, ExtraTimer, :handle_timer_1}, 100)
    state = ExTimer.add(state, {:timeout_type2, &handle_timer_2/1}, 200)
    state
  end

  def handle_timer_1(state) do
    state = put_in(state.calls, state.calls + 1)
    {:noreply, state}
  end

  def handle_timer_2(state) do
    state = put_in(state.calls, state.calls + 1)
    {:noreply, state}
  end
end
