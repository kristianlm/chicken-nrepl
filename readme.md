# GREPL

An blocking networked REPL for Chicken Scheme. Each new incoming
connection runs in a new thread.

## (grepl <port> [spawn])

Listen to TCP port <port> and wait for incoming connections, doing
`(spawn thunk)` for each. `spawn` defaults to `thread-start!`.
