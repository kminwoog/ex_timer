defmodule ExTimer.Node do
  defstruct due: 0, time: 0, msg: {}

  @type t :: %ExTimer.Node{due: integer, time: integer, msg: tuple | atom}
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
    iex> state = %{ timers: [] }
    iex> state = ExTimer.add(state, {:handler, :name, "uhaha"}, 2000)
    iex> [node] = state.timers
    iex> node.msg == {:handler, :name, "uhaha"}
    true
    iex> node.time == 2000
    true
  """
  @spec add(state, tuple | atom, integer) :: state
  def add(state, msg, time) when is_tuple(msg) or is_atom(msg) do
    timers =
      insert(state.timers, %Node{
        due: now() + time,
        time: time,
        msg: msg
      })

    put_in(state.timers, timers)
  end

  @doc """
  delete the previous registerd timer.
  ## Examples
    iex> state = %{timers: [%ExTimer.Node{msg: {:handler, :name, "uhaha"}, time: 2000}]}
    iex> ExTimer.remove(state, {:handler, :name, "uhaha"})
    %{timers: []}
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
    iex> state = %{timers: [%ExTimer.Node{msg: {:handler, :name, "uhaha"}, time: 2000}]}
    iex> ExTimer.clear(state)
    %{timers: []}
  """
  @spec clear(state, boolean) :: state
  defmacro clear(state, callback? \\ false) do
    timer = __ENV__.module

    quote bind_quoted: [state: state, timer: timer, callback?: callback?] do
      timer.clear_expired(state, __ENV__.module, callback?)
    end
  end

  def clear_expired(state, caller, callback?) do
    if callback? do
      {state, _} =
        reduce(state.timers, state, 0, fn node, state ->
          {:noreply, state} = caller.handle_info(node.msg, state)
          state
        end)

      put_in(state.timers, [])
    else
      put_in(state.timers, [])
    end
  end

  defmacro update(state) do
    timer = __ENV__.module

    quote bind_quoted: [state: state, timer: timer] do
      timer.update_expired(state, __ENV__.module)
    end
  end

  def update_expired(state, caller) do
    {state, timers} =
      reduce(state.timers, state, now(), fn node, state ->
        {:noreply, state} = caller.handle_info(node.msg, state)
        state
      end)

    put_in(state.timers, timers)
  end

  defp insert(nil, timer), do: [timer]
  defp insert([], timer), do: [timer]

  defp insert([h | t] = sorted, timer) do
    if h.time < timer.time do
      [h | insert(t, timer)]
    else
      [timer | sorted]
    end
  end

  defp now() do
    :os.system_time(:milli_seconds)
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
        is_atom(elem(lhs, i)) == is_atom(elem(rhs, i))
      end)
  end

  defp equal?(lhs, rhs) when is_atom(lhs) and is_atom(rhs) do
    lhs == rhs
  end

  defp equal?(_lhs, _rhs), do: false
  def reduce(nil, state, _now, _func), do: {state, []}
  def reduce([], state, _now, _func), do: {state, []}

  def reduce([h | t] = list, state, now, func) do
    if now == 0 or h.due <= now do
      reduce(t, func.(h, state), now, func)
    else
      {state, list}
    end
  end
end
