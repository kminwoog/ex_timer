# ex_timer
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
    {:ex_timer, "~> 0.1.0"}
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

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(state) do
    Process.send_after(self(), :tick, 1000)
    ExTimer.add(state, {:timeout1, 1, 9}, 2000)
    ExTimer.add(state, {:timeout2, 3, 9}, 5000)
    {:ok, state}
  end

  def handle_info(:tick, state) do
    state = ExTimer.update(state)
    {:noreply, state}
  end
  
  def handle_info({:timeout1, arg0, arg1}, state) do
    IO.puts("#{inspect(__ENV__.function)} (#{arg0}, #{arg1}) called")
    {:noreply, state}
  end
  
  def handle_info({:timeout2, arg0, arg1}, state) do
    IO.puts("#{inspect(__ENV__.function)} (#{arg0}, #{arg1}) called")
    {:noreply, state}
  end
end
```



