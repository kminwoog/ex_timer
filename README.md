# ex_timer
High-performance timer in elixir

_not using gen_server and not using any other processes_

## Overview
In general, It used a timer to schedule any works in the future.  
`Process.send_after/4` provides its function in elixir.  
But, If you register a lot of timers, its `mailbox` getting larger.  
In elixir as the number of queues increases, cause performance issues.  
Maybe the most important point to note that you should be keep a small queue called as `mailbox`.

## Specification
* To insert new timer is very fast, but not fast to delete
  * insertion : O(logn)
  * deletion  : O(n)
* Don't inspect all registered a lot of timers to check if time has expired.
  * be lightweight what it check time-out 
  
## Usage
```elixir
defmodule Scheduler do
  def init(state) do
    ExTimer.add(state, {do_timer1/2, 1, 9}, 2000)
    ExTimer.add(state, {do_timer1/2, 2, 9}, 2000)
    ExTimer.add(state, {do_timer2/2, 3, 9}, 8000)
    ExTimer.add(state, {do_timer2/2, 3, 9}, 5000)
  end
  
  def update(state) do
    ExTimer.update(state)
  end
  
  def do_timer1({id, value}, state) do
    IO.puts("#{inspect(__ENV__.function)} (#{id}, #{value}) called")
    state
  end
  
  def do_timer2({id, value}, state) do
    IO.puts("#{inspect(__ENV__.function)} (#{id}, #{value}) called")
    state
  end
end
