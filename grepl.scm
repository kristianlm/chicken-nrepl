(use srfi-18 ;; threads
     tcp)

;; like read but catches socket timeouts and retries
(define (read* port)
  (let loop ()
    (condition-case (read port)
                    ((exn i/o net timeout) (loop)))))

(define (grepl-loop in-port out-port)

  (define (repl-prompt op)
    (display "@> " op)
    (flush-output op))

  ;; stolen from Chicken Core's eval.scm
  (define (write-results xs port)
    (cond ((null? xs)
           (##sys#print "; no values\n" #f port))
          (else
           (for-each (cut ##sys#repl-print-hook <> port) xs)
           (when (pair? (cdr xs))
             (##sys#print
              (string-append "; " (##sys#number->string (length xs)) " values\n")
              #f port)))))

  (let loop ()
    (handle-exceptions root-exn
      #f ;; <-- returns from repl-prompt

      (repl-prompt out-port)
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
(define (make-grepl port #!optional (spawn! thread-start!))
  (define socket (tcp-listen port))

  (let loop ()
    (let-values (((in out) (tcp-accept socket))) ;; <-- blocks
      ;; TODO: use these values somehow
      (let-values (((local-adr  remote-adr)  (tcp-addresses in))
                   ((local-port remote-port) (tcp-port-numbers in)))
        (spawn! (lambda () (grepl-loop in out)))))
    (loop)))
