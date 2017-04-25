(use srfi-18 ;; threads
     ports
     tcp)

;; like read but catches socket timeouts and retries
(define (read* port)
  (let loop ()
    (condition-case (read port)
                    ((exn i/o net timeout) (loop)))))

(define (nrepl-loop in-port out-port)

  (define (print-repl-prompt op)
    (display ((repl-prompt)) op)
    (flush-output op))

  ;; stolen from Chicken Core's eval.scm
  (define (write-results xs port)
    (cond ((null? xs)
           (##sys#print "; no values\n" #f port))
          ((eq? (void) (car xs)) ;; <-- don't print #<unspecified>
           (##sys#write-char-0 #\newline port))
          (else
           (for-each (cut ##sys#repl-print-hook <> port) xs)
           (when (pair? (cdr xs))
             (##sys#print
              (string-append "; " (##sys#number->string (length xs)) " values\n")
              #f port)))))

  (let loop ()
    (handle-exceptions root-exn
      #f ;; <-- returns from repl-prompt

      (print-repl-prompt out-port)
      (handle-exceptions exn
        (begin (print-error-message exn out-port)
               (print-call-chain out-port 4)
               (loop))
        ;; reading from in-port will probably yield:
        (let ([sexp (read* in-port)])
          ;; eof, exit repl loop
          (if (not (eof-object? sexp))
              (begin
                (with-output-to-port out-port
                  (lambda ()
                    (with-error-output-to-port
                     out-port
                     (lambda ()
                       (receive result (eval sexp)
                         (if (eq? (void) result)
                             (void) ;; don't print unspecified's
                             (write-results result out-port)))))))
                (loop))))))))

;; blocking repl, spawns new threads on incomming connections
(define (nrepl port #!optional
               (spawn! (lambda (in out)
                         (thread-start!
                          (lambda ()
                            (display ";; nrepl on " out)
                            (display (argv) out)
                            (display "\n" out)
                            (nrepl-loop in out)))
                         #t)))
  (define socket (tcp-listen port))
  (let loop ()
    (let-values (((in out) (tcp-accept socket))) ;; <-- blocks
      (if (spawn! in out)
          (loop)))))
