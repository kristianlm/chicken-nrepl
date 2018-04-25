  [spiffy]: http://api.call-cc.org/doc/spiffy
  [Emacs]: https://www.gnu.org/software/emacs/
  [rlwrap]: http://freecode.com/projects/rlwrap
  [modules]: http://api.call-cc.org/doc/chicken/modules
# NREPL

A networked REPL for Chicken Scheme. Each new incoming connection runs
in a new `srfi-18` thread.

## Requirements

None except the `tcp` and `srfi-18` units from CHICKEN core.

## API

    [procedure] (nrepl port [spawn])

Listen to TCP port `port` number and (blockingly) wait for incoming
connections.  `(spawn)` is called for each incomming connection
without arguments where `current-input-port`, `current-output-port`
and `current-error-port` are bound to the TCP connection.

You can use `spawn`, for example, for authentication:

```scheme
(nrepl 1234
       (lambda ()
         (thread-start! ;; otherwise accept-loop will be blocked
          (lambda ()
            (display ";; please enter an accept token: ")
            (define token (read-line))
            (if (equal? token "abc")
                (nrepl-loop)
                (begin (print ";; access denied")
                       (close-input-port (current-input-port))
                       (close-output-port (current-output-port))
		       (close-output-port (current-error-port))))))))
```

> You can use `tcp-addresses` and `tcp-port-numbers` to find out where
> the new session is coming from.

`nrepl` will loop for accepting incomming connections unless `spawn`
returns `#f`.

    [procedure] (nrepl-loop #!key eval read print writeln)

Start a standard REPL-loop: print the prompt, read an s-expression,
evaluate the expression, print the result and repeat. Exceptions are
reported and data is flushed. This can be used inside the optionally
supplied `spawn`-procedure above.

## Practical use

Any source-code you send down a `nrepl` session will not be persisted
anywhere.  You can reset your program state by restarting your program
which may be useful sometimes.

### Terminal users

Editing code directly from `nc localhost 1234` isn't
pleasant. Luckily, [rlwrap] works along `nrepl` to improve this
experience:

```bash
 ➤ rlwrap nc localhost 1234
;; nrepl on (csi -s example.scm)
#;1> (define (hello) (print "this will be in my history"))
```

[rlwrap] will also save your read-line history for the next invokation
`rlwrap nc localhost 1234` which is handy!


### [Emacs] users

`nrepl` plays very nicely with [Emacs]! If you're used to running `M-x
run-scheme` and sending source-code from buffers into your REPL, an
`nrepl` endpoint can be used as a Scheme interpreter. You can specify
that you want to use `nrepl` with a prefix. For example: 

    C-u M-x run-scheme RET nc localhost 1234

Note that telling [Emacs] that `nc localhost 1234` is your Scheme
interpreter is tricky because `C-u M-x run-scheme` might not let you
enter spaces. You can enter spaces by pressing `C-q` before pressing
space.

### Example HTTP-server work-flow

A real-world use-case for `nrepl` might be something like the
following. Let's make a simple hello-world HTTP server using [spiffy].

```scheme
(use spiffy nrepl)

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
 ➤ curl localhost:8080
hello world
```

What's nice about this is that, since `app` is a top-level variable,
it can be replaced from the REPL:

```bash
 ➤ nc localhost 1234
;; nrepl on (csi -s example.scm)
#;1> (define (app c) (send-response body: "repl hijack!\n"))
#;1> ^C
```

Now `spiffy` will use our top-level `app` for its proceeding requests:

```bash
 ➤ curl localhost:8080
repl hijack!
```

Note that `app` must be wrapped in a `lambda` for this to work,
because the REPL can only replace top-level variable definitions.

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
;;;     echo '(thread-sleep! 1)' | rlwrap nc localhost 1234
;;; should pause the game-loop for 1 second
(use nrepl)

(define with-main-mutex
  (let ((main-mutex (make-mutex)))
    (lambda (proc)
      (dynamic-wind (lambda () (mutex-lock! main-mutex))
                    proc
                    (lambda () (mutex-unlock! main-mutex))))))

(thread-start!
 (lambda ()
   (nrepl 1234
          (lambda ()
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

### `nrepl` on Android

`nrepl` has been used successfully on Android target hardware for
remote interactive development.  Check
out [this](https://github.com/chicken-mobile/chicken-android-template)
Android example project.

## Source code repository

You can find the
source [here](https://github.com/Adellica/chicken-nrepl).

## Author

Kristian Lein-Mathisen at [Adellica](https://github.com/Adellica/)

## License

BSD
