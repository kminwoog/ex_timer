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
    {:ex_timer, "~> 1.0"}
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

  defmodule State do
    defstruct timers: [], elapsed: 0, last_tick: 0
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    Process.send_after(self(), :tick, :rand.uniform(1000))

    state = %State{}
    state = ExTimer.add(state, {:timeout1, 1, 9}, 2000)
    state = ExTimer.add(state, {:timeout2, 3, 9}, 9000)
    {:ok, state}
  end

  def handle_info(:tick, state) do
    now = System.system_time(:millisecond)
    delta_ticks = now - state.last_tick
    state = put_in(state.last_tick, now)
    state = ExTimer.update(state, delta_ticks)

    Process.send_after(self(), :tick, :rand.uniform(1000))
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


```elixir
defmodule ExTimerTest do
  use ExUnit.Case
  require ExTimer
  doctest ExTimer

  test "ex_timer" do
    # you should be define `timers`(list) `elapsed`(float)
    state = %{timers: [], elapsed: 0, calls: 0}
    state = ExTimer.add(state, {:timeout_no_delay, :name, "min"}, 0)
    state = ExTimer.update(state, 0)
    assert state.calls == 1
    assert length(state.timers) == 0

    state = ExTimer.add(state, {:timeout_with_delay, :name, "woog"}, 400)
    state = ExTimer.update(state, 100)
    assert state.calls == 1
    assert length(state.timers) != 0

    # after sleep for delay
    state = ExTimer.update(state, 300)
    assert state.calls == 2
    assert length(state.timers) == 0

    # remove timer with tuple
    state = ExTimer.add(state, {:timer1, :name, "111"}, 400)
    assert length(state.timers) == 1
    state = ExTimer.remove(state, {:timer1, :name})
    assert length(state.timers) == 1
    state = ExTimer.remove(state, {:timer1, "1", "111"})
    assert length(state.timers) == 1
    state = ExTimer.remove(state, {:timer1, :name, "222"})
    assert length(state.timers) == 1
    state = ExTimer.remove(state, {:timer1, :name, "111"})
    assert length(state.timers) == 0

    # remove timer with atom
    state = ExTimer.add(state, :timer, 100)
    assert length(state.timers) == 1
    state = ExTimer.remove(state, :no_tuple)
    assert length(state.timers) == 1
    state = ExTimer.remove(state, :timer)
    assert length(state.timers) == 0

    # clear timers
    state = ExTimer.add(state, {:timer1, :name, "min1"}, 400)
    state = ExTimer.add(state, {:timer1, :name, "min2"}, 400)
    assert length(state.timers) == 2
    state = ExTimer.clear(state)
    assert length(state.timers) == 0

    # clear value
    state = put_in(state.elapsed, 0)
    state = put_in(state.calls, 0)

    # delay
    state = ExTimer.add(state, {:timer4, 1, 2}, 2300)
    assert elem(hd(state.timers).msg, 0) == :timer4
    assert hd(state.timers).delay == 2300
    state = ExTimer.add(state, {:timer5, 1, 2}, 1700)
    assert elem(hd(state.timers).msg, 0) == :timer5
    assert hd(state.timers).delay == 1700
    state = ExTimer.add(state, {:timer6, 1, 2}, 1900)
    assert elem(hd(state.timers).msg, 0) == :timer5
    assert hd(state.timers).delay == 1700

    # adjust
    assert state.elapsed == 0
    assert state.calls == 0
    assert length(state.timers) == 3
    state = ExTimer.update(state, 0)
    assert length(state.timers) == 3
    assert state.calls == 0

    # elapsed 1300ms
    state = ExTimer.update(state, 1300)
    assert length(state.timers) == 3
    assert state.calls == 0
    # elapsed 400ms (total 1700ms)
    state = ExTimer.update(state, 400)
    assert elem(hd(state.timers).msg, 0) == :timer6
    assert length(state.timers) == 2
    assert state.calls == 1
    # elapsed 200ms (total 1900ms)
    state = ExTimer.update(state, 200)
    assert elem(hd(state.timers).msg, 0) == :timer4
    assert length(state.timers) == 1
    assert state.calls == 2
    # elapsed 600ms (total 2300ms)
    state = ExTimer.update(state, 600)
    assert length(state.timers) == 0
    assert state.calls == 3
  end

  def handle_info({:timeout_no_delay, arg0, arg1}, state) do
    assert arg0 == :name
    assert arg1 == "min"
    state = put_in(state.calls, state.calls + 1)
    {:noreply, state}
  end

  def handle_info({:timeout_with_delay, arg0, arg1}, state) do
    assert arg0 == :name
    assert arg1 == "woog"
    state = put_in(state.calls, state.calls + 1)
    {:noreply, state}
  end

  def handle_info({_arg0, _arg1, _arg2}, state) do
    state = put_in(state.calls, state.calls + 1)
    {:noreply, state}
  end
end
```
