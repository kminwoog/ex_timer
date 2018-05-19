defmodule ExTimer do
  @moduledoc """
  Documentation for ExTimer.
  """

  defstruct time: 0, msg: {}

  @type t :: %ExTimer{time: integer, msg: tuple}

  @doc """
  add new timer.

  ## Examples

      iex> state = %{ __timer__: [] }
      iex> ExTimer.add(state, {:handler, :name, "uhaha"}, 2000)
      %{__timer__: [%ExTimer{msg: {:handler, :name, "uhaha"}, time: 2000}]}

  """
  @spec add(map, tuple, integer) :: map
  def add(state, msg, time) when is_tuple(msg) do
    timers = state.__timer__
    timers = insert(timers, %ExTimer{time: time, msg: msg})
    put_in(state.__timer__, timers)
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

  @doc """
  add new timer.

  ## Examples

      iex> state = %{__timer__: [%ExTimer{msg: {:handler, :name, "uhaha"}, time: 2000}]}
      iex> ExTimer.delete(state, {:handler, :name, "uhaha"})
      %{__timer__: []}

  """
  @spec delete(map, tuple) :: map
  def delete(state, msg) when is_tuple(msg) do
    timers = state.__timer__
    timers = remove(timers, msg)
    put_in(state.__timer__, timers)
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
end
