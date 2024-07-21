  [spiffy]: http://api.call-cc.org/doc/spiffy
  [Emacs]: https://www.gnu.org/software/emacs/
  [rlwrap]: https://github.com/hanslub42/rlwrap
  [modules]: http://api.call-cc.org/doc/chicken/modules
# NREPL

A networked REPL for Chicken Scheme, basically `csi` over a TCP
socket. `nrepl` is intended to be used during development and is
insecure by nature.

`nrepl` can be useful when it's complicated to launch your Chicken
Scheme application, yet you want a REPL available. For [Emacs] users,
it can replace your usual `run-scheme` interpreter, see below.

## Requirements

- The `srfi-18` egg.

## API

    [procedure] (nrepl port #!key host backlog spawn)

Listen to TCP port `port` number and wait for incoming
connections. The `host` and `backlog` parameters are passed to
`tcp-listen`.

`host` defaults to `"127.0.0.1"` which will allow incoming connections
from the local machine only. If you plan on exposing the REPL
publicly, you can specify `(nrepl 1234 #:port "0.0.0.0")`. Note that
this has major security drawbacks as a host can easily be compromised
using a REPL.

`(spawn)` is called for each incomming connection without arguments
where `current-input-port`, `current-output-port` and
`current-error-port` are bound to the TCP connection. `spawn` defaults
to creating a new `srfi-18` thread and printing a welcome message.

> You can use `tcp-addresses` and `tcp-port-numbers` to find out where
> the new session is coming from.

`nrepl` will loop for accepting incomming connections unless `spawn`
returns `#f`.

    [procedure] (nrepl-loop #!key eval read print writeln)

Start a standard REPL-loop: print the prompt, read an s-expression,
evaluate the expression, print the result and repeat. This procedure
can be used in the optional `spawn`-procedure of `nrepl`.

It reports exceptions, ensures data is flushed and limits the print
output to avoid flooding your nrepl session (so that `(make-vector
10000)` is safe).

## Practical use

### [rlwrap]

Editing code directly from `nc localhost 1234` isn't
pleasant. Luckily, [rlwrap] works along `nrepl` to improve this
experience:

```bash
$ csi -R nrepl -P '(nrepl 1234)' &
$ rlwrap nc localhost 1234
;; nrepl on (csi -R nrepl -P (nrepl 1234))
#;> (define (hello) (print "this will be in my history"))
```

[rlwrap] will also save your read-line history for the next invokation
`rlwrap nc localhost 1234` which is handy!

### [Emacs]

If you're used to running `M-x run-scheme` and sending source-code
from buffers into your REPL, an `nrepl` endpoint can be used as a
Scheme interpreter like this:

    C-u M-x run-scheme RET nc localhost 1234

> If [Emacs] doesn't let you enter spaces, press `C-q` before pressing
> space.

### Example HTTP-server work-flow

A real-world use-case for `nrepl` might be something like the
following. Let's make a simple hello-world HTTP server using [spiffy].

```scheme
(import nrepl srfi-18 spiffy)

(define (app c)
  (send-response body: "hello world\n"))

(thread-start!
 (lambda ()
   (vhost-map `((".*" . ,(lambda (c) (app c)))))
   (start-server)))

(print "starting nrepl on port 1234")
(nrepl 1234)
```

Now spiffy runs on port `8080`:

```bash
$ curl localhost:8080
hello world
```

What's nice about this is that, since `app` is a top-level variable,
it can be replaced from the REPL:

```bash
$ rlwrap nc localhost 1234
;; nrepl on (csi -s example.scm)
#;1> (define (app c) (send-response body: "repl hijack!\n"))
#;1> ^C
```

Now `spiffy` will use our top-level `app` for its proceeding requests:

```bash
$ curl localhost:8080
repl hijack!
```

Note that `app` must be wrapped in a `lambda` for this to work,
because only top-level symbols can be redefined.

The implications of this can be quite dramatic in terms of
work-flow. If you write your app in a REPL-friendly way like this, you
can modify you program behaviour on-the-fly from the REPL and never
have to restart your process and lose its state.

### Example CPU-intensive main thread

`nrepl` can be used for live-coding interactive application such as
games. Adding `(thread-start! (lambda () (nrepl 1234)))` usually Just
Works, where you can redefine top-level function and game state
on-the-fly.

However, if the game-loop is eating up a lot of scheduler-time, you
may find that your REPL becomes unresponsive. A good way to fix this
is to wrap both the REPL and the game-loop in a mutex. This has
another advantage in that it will ensure your REPL will not interfere
with game-state (or OpenGL state) during game-loop iteration.

```scheme
;;; wrapping nrepl eval in a mutex for responsiveness
;;; and game-loop thread-safety. running this and then doing:
;;;     echo '(thread-sleep! 1)' | nc localhost 1234
;;; should pause the game-loop for 1 second
(import nrepl srfi-18 chicken.time)

(define with-main-mutex
  (let ((main-mutex (make-mutex)))
    (lambda (proc)
      (dynamic-wind (lambda () (mutex-lock! main-mutex))
                    proc
                    (lambda () (mutex-unlock! main-mutex))))))

(thread-start!
 (lambda ()
   (nrepl 1234
          #:spawn (lambda ()
                    (thread-start!
                     (lambda ()
                       (nrepl-loop eval: (lambda (x) (with-main-mutex (lambda () (eval x)))))))))))

(define (game-step)
  (print* "\r"  (current-milliseconds) "   ")
  (thread-sleep! 0.05))

(let loop ()
  (with-main-mutex game-step)
  (loop))
```

### `nrepl` in compiled code

`nrepl` also works inside a compiled program. However, sometimes
[modules] disappear due to compiler optimizations.

## Source code repository

You can find the
source [here](https://github.com/kristianlm/chicken-nrepl).

## Author

Kristian Lein-Mathisen

## License

BSD
