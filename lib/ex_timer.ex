defmodule ExTimer.Node do
  @type msg :: tuple() | atom()
  @type time_ms() :: non_neg_integer()
  @type t :: %ExTimer.Node{delay: time_ms(), msg: msg()}

  defstruct delay: 0, msg: {}
end

defmodule ExTimer do
  @moduledoc """
  ExTimer module.
  """

  alias ExTimer.Node

  @type timer_node :: ExTimer.Node.t()
  @type timer_node_msg :: ExTimer.Node.msg()
  @type time_ms :: ExTimer.Node.time_ms()
  @type state :: %{
          :elapsed_ticks => time_ms(),
          :timers => [timer_node()],
          optional(any()) => any()
        }
  import Bitwise
  @int_max (1 <<< 31) - 1

  @doc """
  add new timer to send msg after time milliseconds.

  ## Examples

    iex> state = %{ timers: [], elapsed_ticks: 0 }
    iex> state = ExTimer.add(state, {:handler, :name, "uhaha"}, 2000)
    iex> [timer] = state.timers
    iex> timer.msg == {:handler, :name, "uhaha"}
    true
    iex> timer.delay == 2000
    true
  """
  @spec add(state(), timer_node_msg(), time_ms()) :: state()
  def add(state, msg, delta_ms) when is_tuple(msg) or is_atom(msg) do
    put_in(state.timers, insert(state.timers, %Node{delay: delta_ms, msg: msg}))
  end

  @doc """
  delete the previous registerd timer.

  ## Examples

    iex> state = %{timers: [%ExTimer.Node{msg: {:handler, :name, "uhaha"}, delay: 2000}], elapsed_ticks: 0}
    iex> ExTimer.remove(state, {:handler, :name, "uhaha"})
    %{timers: [], elapsed_ticks: 0}
  """
  @spec remove(state(), timer_node_msg()) :: state()
  def remove(state, msg) when is_tuple(msg) or is_atom(msg) do
    timers = state.timers
    timers = delete(timers, msg)
    put_in(state.timers, timers)
  end

  @doc """
  delete all the registerd timers.

  ## Examples

    iex> state = %{timers: [%ExTimer.Node{msg: {:handler, :name, "uhaha"}, delay: 2000}], elapsed_ticks: 0}
    iex> ExTimer.clear(state)
    %{timers: [], elapsed_ticks: 0}
  """
  defmacro clear(state, callback? \\ false) do
    timer = __ENV__.module

    quote bind_quoted: [state: state, timer: timer, callback?: callback?] do
      timer.clear_expired(state, __ENV__.module, callback?)
    end
  end

  @doc false
  @spec clear_expired(state(), module(), boolean()) :: state()
  def clear_expired(state, caller, callback?) do
    if callback? do
      state =
        Enum.reduce(state.timers, state, fn timer, state ->
          {:noreply, state} = caller.handle_info(timer.msg, state)
          state
        end)

      put_in(state.timers, [])
    else
      put_in(state.timers, [])
    end
  end

  defmacro update(state, delta_ms) do
    timer = __ENV__.module

    quote bind_quoted: [state: state, delta_ms: delta_ms, timer: timer] do
      timer.update_expired(state, delta_ms, __ENV__.module)
    end
  end

  @doc false
  @spec update_expired(state(), time_ms(), module()) :: state()
  def update_expired(state, delta_ms, caller) do
    state = put_in(state.elapsed_ticks, state.elapsed_ticks + delta_ms)

    {state, timers} =
      reduce(state.timers, state, fn timer, state ->
        {:noreply, state} = caller.handle_info(timer.msg, state)
        state
      end)

    state = put_in(state.timers, timers)

    if state.timers == [] or state.elapsed_ticks + delta_ms > @int_max do
      adjust(state)
    else
      state
    end
  end

  @doc """
  return true if found the timer at the given msg, otherwise return false

  ## Examples

    iex> state = %{timers: [%ExTimer.Node{msg: {:handler, :name, "uhaha"}, delay: 2000}], elapsed_ticks: 0}
    iex> ExTimer.exist?(state, {:handler, :name, "uhaha"})
    true
  """
  @spec exist?(state(), timer_node_msg()) :: boolean
  def exist?(state, msg), do: exist_internal?(state.timers, msg)

  @spec exist_internal?(nil | [timer_node()], timer_node_msg()) :: boolean
  defp exist_internal?(nil, _msg), do: false
  defp exist_internal?([], _msg), do: false

  defp exist_internal?([h | t], msg) do
    if equal?(h.msg, msg) do
      true
    else
      exist_internal?(t, msg)
    end
  end

  @spec insert(nil | [timer_node()], timer_node()) :: [timer_node()]
  defp insert(nil, timer), do: [timer]
  defp insert([], timer), do: [timer]

  defp insert([h | t] = sorted, timer) do
    if h.delay < timer.delay do
      [h | insert(t, timer)]
    else
      [timer | sorted]
    end
  end

  @spec next_expire_time(state(), time_ms()) :: time_ms()
  def next_expire_time(state, min_time) do
    if Enum.empty?(state.timers) do
      min_time
    else
      min(hd(state.timers).delay - state.elapsed_ticks, 0)
    end
  end

  @spec delete(nil | [timer_node()], timer_node_msg()) :: [timer_node()]
  defp delete(nil, _msg), do: []
  defp delete([], _msg), do: []

  defp delete([h | t], msg) do
    if equal?(h.msg, msg) do
      t
    else
      [h | delete(t, msg)]
    end
  end

  @spec equal?(timer_node_msg(), timer_node_msg()) :: boolean
  defp equal?(lhs, rhs) when is_tuple(lhs) and is_tuple(rhs) do
    size = tuple_size(lhs)

    size == tuple_size(rhs) and
      Enum.all?(0..(size - 1), fn i ->
        elem(lhs, i) == elem(rhs, i)
      end)
  end

  defp equal?(lhs, rhs) when is_atom(lhs) and is_atom(rhs) do
    lhs == rhs
  end

  defp equal?(_lhs, _rhs), do: false

  @spec reduce(nil | [timer_node()], state(), function()) :: {state(), [timer_node()]}
  defp reduce(nil, state, _func), do: {state, []}
  defp reduce([], state, _func), do: {state, []}

  defp reduce([h | t] = list, state, func) do
    if h.delay <= state.elapsed_ticks do
      reduce(t, func.(h, state), func)
    else
      {state, list}
    end
  end

  @spec adjust(state) :: state()
  def adjust(state) do
    timers = adjust_internal(state.elapsed_ticks, state.timers)
    state = put_in(state.elapsed_ticks, 0)
    put_in(state.timers, timers)
  end

  defp adjust_internal(_elapsed, []), do: []

  defp adjust_internal(elapsed_ticks, [timer | t]) do
    delay =
      if timer.delay > elapsed_ticks do
        timer.delay - elapsed_ticks
      else
        0
      end

    timer = put_in(timer.delay, delay)
    [timer | adjust_internal(elapsed_ticks, t)]
  end
end
