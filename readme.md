# NREPL

An blocking networked REPL for Chicken Scheme. Each new incoming
connection runs in a new srfi-18 thread.

## (nrepl <port> [spawn])

Listen to TCP port <port> and wait for incoming connections, doing
`(spawn thunk)` for each. `spawn` defaults to `thread-start!`.

# Example

At the very beginning of your application, you can get network REPL access by doing this:

```scheme
(use nrepl)
(define repl-thread (thread-start! (lambda () (nrepl 1234))))
```
