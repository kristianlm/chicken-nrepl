# NREPL

A blocking networked REPL for Chicken Scheme. Each new incoming
connection runs in a new srfi-18 thread.

## Requirements

None except the core tcp and srfi-18 units.

## API

    [procedure] (nrepl port [spawn])

Listen to TCP port <port> and wait for incoming connections, doing
`(spawn thunk)` for each new connected peer. `spawn` defaults to `thread-start!`.

## Example

At the very beginning of your application, you can get network REPL
access by doing this:

```scheme
(use nrepl)
(thread-start! (lambda () (nrepl 1234)))
```

## Source code repository

You can find the source [here](https://github.com/Adellica/chicken-nrepl).

## Author

Kristian Lein-Mathisen at [Adellica](https://github.com/Adellica/)

## License

BSD
