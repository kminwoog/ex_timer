defmodule Helper do
  def add_timer(state, message, delay_ms) do
    put_in(state.timer, ExTimer.add(state.timer, message, delay_ms))
  end

  def remove_timer(state, message) do
    put_in(state.timer, ExTimer.remove(state.timer, message))
  end

  defmacro update_timer(state, delay_ms) do
    quote bind_quoted: [state: state, delay_ms: delay_ms] do
      Process.sleep(delay_ms)
      {state, timer} = ExTimer.update(state, state.timer)
      put_in(state.timer, timer)
    end
  end

  defmacro clear_timer(state) do
    quote bind_quoted: [state: state] do
      {state, timer} = ExTimer.clear(state, state.timer)
      put_in(state.timer, timer)
    end
  end
end
