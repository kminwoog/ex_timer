# ex_timer
High-performance timer in elixir

_not using gen_server and not using any other processes_

## Overview
In general, It used a timer to schedule any works in the future.  
`Process.send_after/4` provides its function in elixir.  
But, If you register a lot of timers, its `mailbox` getting bigger.  
In elixir as the number of queues increases, cause performance issues.  
Maybe the most important point to note that you should be keep a small queue called as `mailbox`.

## Specification

* To insert new timer is very fast, but not fast to delete
* Don't inspect all registered a lot of timers to check if time has expired.
  * be lightweight what it check time-out 
  
## Usage

