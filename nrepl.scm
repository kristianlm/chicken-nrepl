(use srfi-18 ;; threads
     (only tcp tcp-listen tcp-accept tcp-read-timeout))

(define nrepl-prompt (make-parameter (lambda () (display ";> "))))

(define (nrepl-loop #!key
                    (eval eval)
                    (read read)
                    (print print)
                    ;; repl-print-hook is nice because it limits printout size
                    (writeln (lambda (x) (##sys#repl-print-hook x (current-output-port)))))

  (define (print-repl-prompt)
    ((nrepl-prompt))
    (flush-output))

  ;; stolen from Chicken Core's eval.scm
  (define (write-results xs)
    (cond ((null? xs)
           (print "; no values\n"))
          ((eq? (void) (car xs)) ;; <-- don't print #<unspecified>
           (newline))
          (else
           (for-each writeln xs)
           (when (pair? (cdr xs))
             (print "; " (length xs) " values\n")))))

  (let loop ()
    (handle-exceptions root-exn
      #f ;; <-- returns from repl-prompt

      (print-repl-prompt)
      (handle-exceptions exn
        (begin (print-error-message exn (current-error-port))
               (print-call-chain (current-error-port) 4) ;; remove 4 internal traces
               (loop))

        (let ([sexp (read)])
          ;; eof, exit repl loop
          (if (not (eof-object? sexp))
              (begin
                (receive result (eval sexp)
                  (if (eq? (void) result)
                      (void) ;; don't print unspecified's
                      (write-results result)))
                (loop))))))))

;; blocking repl, spawns new threads on incomming connections
(define (nrepl port #!optional
               (spawn! (lambda ()
                         (thread-start!
                          (lambda ()
                            (print ";; nrepl on " (argv))
                            (nrepl-loop)))
                         #t)))
  (define socket (tcp-listen port))
  (let loop ()
    (let-values (((in out) (tcp-accept socket))) ;; <-- blocks
      (parameterize ((tcp-read-timeout #f)
                     (current-input-port in)
                     (current-output-port out)
                     (current-error-port out))
        (if (spawn!)
            (loop))))))
