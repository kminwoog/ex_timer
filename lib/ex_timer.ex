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

      iex> state = %{ __timers__: [] }
      iex> state = ExTimer.add(state, {:handler, :name, "uhaha"}, 2000)
      iex> [node] = state[:__timers__]
      iex> node.msg == {:handler, :name, "uhaha"}
      true
      iex> node.time == 2000
      true

  """
  @spec add(state, tuple | atom, integer) :: state
  def add(state, msg, time) when is_tuple(msg) or is_atom(msg) do
    timers = state[:__timers__]
    timers = insert(timers, %Node{due: now() + time, time: time, msg: msg})
    put_in(state[:__timers__], timers)
  end

  defp insert(nil, timer) do
    [timer]
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

  @doc false
  def now() do
    :os.system_time(:milli_seconds)
  end

  @doc """
  delete the previous registerd timer.

  ## Examples

      iex> state = %{__timers__: [%ExTimer.Node{msg: {:handler, :name, "uhaha"}, time: 2000}]}
      iex> ExTimer.remove(state, {:handler, :name, "uhaha"})
      %{__timers__: []}

  """
  @spec remove(state, tuple | atom) :: state
  def remove(state, msg) when is_tuple(msg) or is_atom(msg) do
    timers = state[:__timers__]
    timers = delete(timers, msg)
    put_in(state[:__timers__], timers)
  end

  @doc """
  delete all the registerd timers.

  ## Examples

      iex> state = %{__timers__: [%ExTimer.Node{msg: {:handler, :name, "uhaha"}, time: 2000}]}
      iex> ExTimer.clear(state)
      %{__timers__: []}

  """
  @spec clear(state) :: state
  def clear(state) do
    put_in(state[:__timers__], [])
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

  # defp equal?(lhs, rhs) when is_tuple(lhs) and is_tuple(rhs) do
  #   size = tuple_size(lhs)
  #   size == tuple_size(rhs) and Enum.all?(0..(size - 1), fn i -> elem(lhs, i) == elem(rhs, i) end)
  # end

  defmacro update(state) do
    quote bind_quoted: [state: state] do
      timers = state[:__timers__]
      ExTimer.expired(state, timers, ExTimer.now(), __ENV__.module)
    end
  end

  @doc false
  def expired(state, nil, _now, _module), do: state

  @doc false
  def expired(state, [], _now, _module), do: state

  @doc false
  def expired(state, [h | t], now, module) do
    if h.due <= now do
      {:noreply, state} = module.handle_info(h.msg, state)
      state = put_in(state[:__timers__], t)
      expired(state, t, now, module)
    else
      state
    end
  end
end
