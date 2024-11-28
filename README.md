# ex_timer
 [![Hex.pm Version](https://img.shields.io/hexpm/v/ex_timer.svg)](https://hex.pm/packages/ex_timer)
 
Better-performance timer in elixir

_not using extra gen_server and not using any other processes for timer_

## Overview
In general, It used a timer to schedule any works in the future.  
`Process.send_after/4` provides its function in elixir.  
But, If you register a lot of timers, its `mailbox` getting larger.  
In elixir as the number of queues increases, cause performance issues.  
Maybe the most important point to note that you should be keep a small queue called as `mailbox`.

## Specification
* To insert and delete new timer is reasonably fast.
  * insertion, deletion : O(n)
* Don't inspect all registered a lot of timers to check if time has expired.
  * be lightweight what it check time-out : O(1)
  
## Installation
If [available in Hex](https://hex.pm/docs/publish), add in deps of `mix.exs`
```elixir
def deps do
  [
    {:ex_timer, "~> 1.5"}
  ]
end
```
then run as
```sh
$ mix deps.get
```

## Usage
```elixir
defmodule Scheduler do
  use GenServer
  require ExTimer

  defmodule State do
    defstruct [:timer, calls: 0]
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    Process.send_after(self(), :tick, :rand.uniform(1000))

    state = %State{timer: ExTimer.new()}
    state = put_in(state.timer, ExTimer.add(state.timer, {:timeout1, 1, 9}, 2000))
    state = put_in(state.timer, ExTimer.add(state.timer, {:timeout2, 3, 9}, 9000))
    state = ExtraTimer.start_timer(state)
    {:ok, state}
  end

  def handle_info(:tick, state) do
    {state, timer} = ExTimer.update(state, state.timer)
    state = put_in(state.timer, timer)
    Process.send_after(self(), :tick, :rand.uniform(1000))
    {:noreply, state}
  end
  
  def handle_timer({:timeout1, arg0, arg1}, timer, state) do
    IO.puts("#{inspect(__ENV__.function)} (#{arg0}, #{arg1}) called")
    {state, timer}
  end
  
  def handle_timer({:timeout_type1, module, function}, timer, state) do
    apply(module, function, [state, timer])
  end

  def handle_timer({:timeout_type2, function_ref}, timer, state) do
    function_ref.(state, timer)
  end
end

defmodule ExtraTimer do
  def start_timer(state) do
    state = %{state | timer: 0, calls: 0}
    state = put_in(state.timer, ExTimer.new())
    state = put_in(state.timer, ExTimer.add(state.timer, {:timeout_type1, ExtraTimer, :handle_timeout_1}, 100))
    state = put_in(state.timer, ExTimer.add(state.timer, {:timeout_type2, &handle_timeout_2/2}, 100))
    state
  end
  
  def handle_timeout_1(state, timer) do
    state = put_in(state.calls, state.calls + 1)
    {state, timer}
  end

  def handle_timeout_2(state, timer) do
    state = put_in(state.calls, state.calls + 1)
    {state, timer}
  end
end
```

