defmodule ExTimer.Node do
  defstruct delay: 0, msg: {}

  @type t :: %ExTimer.Node{delay: float, msg: tuple | atom}
end

defmodule ExTimer do
  @moduledoc """
    ExTimer module.
  """

  alias ExTimer.Node

  @type state :: map

  @doc """
  add new timer.

  ## Examples
    iex> state = %{ timers: [], elapsed: 0 }
    iex> state = ExTimer.add(state, {:handler, :name, "uhaha"}, 2000)
    iex> [timer] = state.timers
    iex> timer.msg == {:handler, :name, "uhaha"}
    true
    iex> timer.delay == 2000/1000
    true
  """
  @spec add(state, tuple | atom, integer) :: state
  def add(state, msg, delay) when is_tuple(msg) or is_atom(msg) do
    timers =
      insert(state.timers, %Node{
        delay: delay / 1000,
        msg: msg
      })

    put_in(state.timers, timers)
  end

  @doc """
  delete the previous registerd timer.
  ## Examples
    iex> state = %{timers: [%ExTimer.Node{msg: {:handler, :name, "uhaha"}, delay: 2000}], elapsed: 0}
    iex> ExTimer.remove(state, {:handler, :name, "uhaha"})
    %{timers: [], elapsed: 0}
  """
  @spec remove(state, tuple | atom) :: state
  def remove(state, msg) when is_tuple(msg) or is_atom(msg) do
    timers = state.timers
    timers = delete(timers, msg)
    put_in(state.timers, timers)
  end

  @doc """
  delete all the registerd timers.
  ## Examples
    iex> state = %{timers: [%ExTimer.Node{msg: {:handler, :name, "uhaha"}, delay: 2000}], elapsed: 0}
    iex> ExTimer.clear(state)
    %{timers: [], elapsed: 0}
  """
  @spec clear(state, boolean) :: state
  defmacro clear(state, callback? \\ false) do
    timer = __ENV__.module

    quote bind_quoted: [state: state, timer: timer, callback?: callback?] do
      timer.clear_expired(state, __ENV__.module, callback?)
    end
  end

  @doc false
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

  @spec update(state, float) :: state
  defmacro update(state, delta) do
    timer = __ENV__.module

    quote bind_quoted: [state: state, delta: delta, timer: timer] do
      timer.update_expired(state, delta, __ENV__.module)
    end
  end

  @doc false
  def update_expired(state, delta, caller) do
    state = put_in(state.elapsed, state.elapsed + delta)

    {state, timers} =
      reduce(state.timers, state, fn timer, state ->
        {:noreply, state} = caller.handle_info(timer.msg, state)
        state
      end)

    put_in(state.timers, timers)
  end

  defp insert(nil, timer), do: [timer]
  defp insert([], timer), do: [timer]

  defp insert([h | t] = sorted, timer) do
    if h.delay < timer.delay do
      [h | insert(t, timer)]
    else
      [timer | sorted]
    end
  end

  @spec next_expire_time(state, integer) :: integer
  def next_expire_time(state, min_time) do
    if Enum.empty?(state.timers) do
      min_time
    else
      min(hd(state.timers).delay - state.elapsed, 0)
    end
  end

  defp delete(nil, _msg), do: []
  defp delete([], _msg), do: []

  defp delete([h | t], msg) do
    if equal?(h.msg, msg) do
      t
    else
      [h | delete(t, msg)]
    end
  end

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

  @spec reduce(nil | list, state, function) :: {state, list}
  def reduce(nil, state, _func), do: {state, []}
  def reduce([], state, _func), do: {state, []}

  def reduce([h | t] = list, state, func) do
    if h.delay <= state.elapsed do
      reduce(t, func.(h, state), func)
    else
      {state, list}
    end
  end

  @spec adjust(state, list) :: list
  def adjust(state) do
    timers = adjust(state.elapsed, state.timers)
    put_in(state.timers, timers)
  end

  defp adjust(_elapsed, []), do: []

  defp adjust(elapsed, [timer | t]) do
    delay =
      if timer.delay > elapsed do
        timer.delay - elapsed
      else
        0
      end

    timer = put_in(timer.delay, delay)
    [timer | adjust(elapsed, t)]
  end
end
