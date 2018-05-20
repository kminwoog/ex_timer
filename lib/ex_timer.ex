defmodule ExTimer.Node do
  defstruct due: 0, time: 0, msg: {}

  @type t :: %ExTimer.Node{due: integer, time: integer, msg: tuple}
end

defmodule ExTimer do
  @moduledoc """
  Documentation for ExTimer.
  """

  alias ExTimer.Node

  defstruct __timers__: []
  @type t :: %ExTimer{__timers__: list}

  @doc """
  add new timer.

  ## Examples

      iex> state = %{ __timers__: [] }
      iex> ExTimer.add(state, {:handler, :name, "uhaha"}, 2000)
      %{__timers__: [%ExTimer{msg: {:handler, :name, "uhaha"}, time: 2000}]}

  """
  @spec add(map, tuple, integer) :: map
  def add(state, msg, time) when is_tuple(msg) do
    timers = state.__timers__
    timers = insert(timers, %Node{due: now() + time, time: time, msg: msg})
    put_in(state.__timers__, timers)
  end

  defp insert([], timer) do
    [timer]
  end

  defp insert([h | t] = sorted, timer) do
    if h.time < timer.time do
      [h | insert(t, timer)]
    else
      [timer | sorted]
    end
  end

  defp now() do
    :os.system_time(:milliseconds)
  end

  @doc """
  delete the previous registerd timer.

  ## Examples

      iex> state = %{__timers__: [%ExTimer{msg: {:handler, :name, "uhaha"}, time: 2000}]}
      iex> ExTimer.delete(state, {:handler, :name, "uhaha"})
      %{__timers__: []}

  """
  @spec delete(map, tuple) :: map
  def delete(state, msg) when is_tuple(msg) do
    timers = state.__timers__
    timers = remove(timers, msg)
    put_in(state.__timers__, timers)
  end

  defp remove(list, msg)

  defp remove([], _msg), do: []

  defp remove([h | t], msg) do
    if equal?(h.msg, msg) do
      t
    else
      [h | remove(t, msg)]
    end
  end

  defp equal?(lhs, rhs) when is_tuple(lhs) and is_tuple(rhs) do
    size = tuple_size(lhs)
    size == tuple_size(rhs) and Enum.all?(0..(size - 1), fn i -> elem(lhs, i) == elem(rhs, i) end)
  end

  def update(state) do
    timers = state.__timers__
    expired(state, timers, now())
  end

  defp expired(state, [], _now) do
    state
  end

  defp expired(state, [h | t], now) do
    if h.due >= now do
      quote do
        __CALLER__.module.handle_call(h.msg, state)
      end

      state = put_in(state.__timers__, t)
      expired(state, t, now)
    else
      state
    end
  end

  def handle_call(_msg, _state) do
  end
end
