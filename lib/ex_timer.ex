defmodule ExTimer.Node do
  @type msg :: tuple() | atom()
  @type time_ms() :: non_neg_integer()
  @type t :: %ExTimer.Node{due_ms: time_ms(), msg: msg()}

  defstruct due_ms: 0, msg: {}
end

defmodule ExTimer do
  @moduledoc """
  ExTimer module.
  """

  require Logger
  alias ExTimer.Node

  @type timer_node :: ExTimer.Node.t()
  @type timer_node_msg :: ExTimer.Node.msg()
  @type time_ms :: ExTimer.Node.time_ms()
  @type state :: term()

  defstruct timers: [], now_ms: nil

  @type t :: %__MODULE__{
          timers: [timer_node()],
          now_ms: (-> integer())
        }

  def new(opts \\ []) do
    now_fn = Keyword.get(opts, :now_ms, fn -> System.system_time(:millisecond) end)
    %ExTimer{now_ms: now_fn}
  end

  @doc ~S"""
  add new timer to send msg after time milliseconds.

  ## Examples

  ```elixir
  iex> now_ref = fn -> 500 end
  iex> timer = ExTimer.new(now_ms: now_ref)
  %ExTimer{now_ms: now_ref, timers: []}
  iex> timer = ExTimer.add(timer, {:handler, :name, "uhaha"}, 2000)
  %ExTimer{now_ms: now_ref, timers: [%ExTimer.Node{due_ms: 2500, msg: {:handler, :name, "uhaha"}}]}
  iex> [timer_node] = timer.timers
  [%ExTimer.Node{due_ms: 2500, msg: {:handler, :name, "uhaha"}}]
  iex> timer_node.msg == {:handler, :name, "uhaha"}
  true
  iex> timer_node.due_ms == 2500
  true

  ```

  """
  @spec add(t(), timer_node_msg(), time_ms()) :: t()
  def add(timer, msg, delta_ms) when is_tuple(msg) or is_atom(msg) do
    put_in(
      timer.timers,
      insert(timer.timers, %Node{due_ms: timer.now_ms.() + delta_ms, msg: msg})
    )
  end

  @doc """
  delete the previous registerd timer.

  ## Examples

  ```elixir
  iex> timer = %{timers: [%ExTimer.Node{msg: {:handler, :name, "uhaha"}, due_ms: 2000}]}
  iex> ExTimer.remove(timer, {:handler, :name, "uhaha"})
  %{timers: []}

  ```
  """
  @spec remove(t(), timer_node_msg()) :: t()
  def remove(timer, msg) when is_tuple(msg) or is_atom(msg) do
    timers = timer.timers
    timers = delete(timers, msg)
    put_in(timer.timers, timers)
  end

  @doc ~S"""
  delete all the registerd timers.

  ## Examples
  ```elixir
  iex> state = %{}
  iex> now_ref = fn -> 500 end
  iex> timer = ExTimer.new(now_ms: now_ref)
  iex> timer = ExTimer.add(timer, {:handler, :name, "uhaha"}, 2000)
  %ExTimer{timers: [%ExTimer.Node{due_ms: 2500, msg: {:handler, :name, "uhaha"}}], now_ms: now_ref}
  iex> {_state, _timer} = ExTimer.clear(state, timer)
  {%{}, %ExTimer{timers: [], now_ms: now_ref}}
  ```
  """
  defmacro clear(state, timer, callback? \\ false) do
    quote bind_quoted: [state: state, timer: timer, callback?: callback?] do
      ExTimer.clear_expired(__ENV__.module, timer, state, callback?)
    end
  end

  @doc false
  @spec clear_expired(module(), t(), state(), boolean()) :: {state(), t()}
  def clear_expired(caller, timer, state, callback?) do
    {state, timer} =
      if callback? do
        Enum.reduce(timer.timers, {state, timer}, fn timer, {state, timer} ->
          caller.handle_timer(timer.msg, timer, state)
        end)
      else
        {state, timer}
      end

    {state, put_in(timer.timers, [])}
  end

  @doc """
  call the callback handler (handle_timer) for the timer that has elapsed.

  ## Examples
  def handle_timer({:tick}, state) do
    ...
    {state, timer} = ExTimer.update(state, timer)
    ...
    {:noreply, state}
  end
  ```
  """
  defmacro update(state, timer) do
    quote bind_quoted: [state: state, timer: timer] do
      ExTimer.update_expired(__ENV__.module, state, timer)
    end
  end

  @doc false
  @spec update_expired(module(), state(), t()) :: {state(), t()}
  def update_expired(caller, state, timer) do
    now_ms = timer.now_ms.()
    {timer, removed_timers} = reduce_expired(timer.timers, {timer, []}, now_ms)

    Enum.reduce(removed_timers, {state, timer}, fn early_timer, {state, timer} ->
      caller.handle_timer(early_timer.msg, timer, state)
    end)
  end

  @doc """
  return true if found the timer at the given msg, otherwise return false

  ## Examples
  ```elixir
  iex> timer = %ExTimer{timers: [%ExTimer.Node{msg: {:handler, :name, "uhaha"}, due_ms: 2000}]}
  iex> ExTimer.exist?(timer, {:handler, :name, "uhaha"})
  true

  ```
  """
  @spec exist?(t(), timer_node_msg()) :: boolean()
  def exist?(timer, msg), do: exist_internal?(timer.timers, msg)

  @spec exist_internal?(nil | [timer_node()], timer_node_msg()) :: boolean()
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
    if h.due_ms < timer.due_ms do
      [h | insert(t, timer)]
    else
      [timer | sorted]
    end
  end

  @doc """
  get the minimum time(milliseconds) for the timer to expired.

  ## Examples

  ```elixir

  def handle_timer({:tick}, state) do
    ...
    state = ExTimer.update(state, timer)
    ...
    Process.send_after(self(), {:tick}, ExTimer.next_expire_ticks(state.timer, 1000))
    {:noreply, state}
  end
  ```
  """
  @spec next_expire_ticks(t(), time_ms()) :: time_ms()
  def next_expire_ticks(timer, min_time) do
    if Enum.empty?(timer.timers) do
      min_time
    else
      min(hd(timer.timers).due_ms - timer.now_ms.(), 0)
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

  @spec equal?(timer_node_msg(), timer_node_msg()) :: boolean()
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

  @spec reduce_expired(nil | [timer_node()], {t(), [timer_node()]}, integer()) ::
          {t(), [timer_node()]}
  defp reduce_expired(nil, {timer, []}, _now_ms), do: {timer, []}

  defp reduce_expired([], {timer, remove_timers}, _now_ms),
    do: {put_in(timer.timers, []), remove_timers}

  defp reduce_expired([h | t] = timers, {timer, remove_timers}, now_ms) do
    if h.due_ms <= now_ms do
      reduce_expired(t, {timer, [h | remove_timers]}, now_ms)
    else
      {put_in(timer.timers, timers), remove_timers}
    end
  end
end
