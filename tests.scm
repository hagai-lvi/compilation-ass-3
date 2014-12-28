;;; Copyright (c) 2012 Andrew W. Keep
;;; See the accompanying file Copyright for detatils
(load "compiler.scm")
(import
	(rnrs)
	(rough-draft unit-test)
	(rough-draft console-test-runner))

(define-test-suite foo

	(define-test test-parse-or
		(assert-equal? (parse '(or)) '(const #f) )
		(assert-equal? (parse '(or #f)) '(const #f) )
		(assert-equal? (parse '(or 1)) '(const 1) )
		(assert-equal? (parse '(or 1 2 3)) '(or ((const 1) (const 2) (const 3))) )
		(assert-equal? (parse '(or a b c)) '(or ((var a) (var b) (var c) )) )
	)

	(define-test test-find-minor
		(assert-equal? (find-minor 'a '(a b c)) 0 )
		(assert-equal? (find-minor 'c '(a b c)) 2 )
		(assert-equal? (find-minor 'x '(a b c)) #f )
	)

	(define-test test-find-major-minor
		(assert-equal? (find-major-minor `a `((a) (x)) ) `(bvar a 0 0) )
		(assert-equal? (find-major-minor `x `((a x) (x) (x)) ) `(bvar x 0 1) )
		(assert-equal? (find-major-minor `not `((a b) (c) (d)) ) #f )
	)

	(define-test test-get-var-annotation
		(assert-equal? (get-var-annotation 'x '((x) (a) (b))) `(pvar x 0) )
		(assert-equal? (get-var-annotation 'x '((x y z) (x) (x))) `(pvar x 0) )
		(assert-equal? (get-var-annotation 'y '((x y z) (x) (x))) `(pvar y 1) )

		(assert-equal? (get-var-annotation 'a '((x) (a) (b))) `(bvar a 0 0) )
		(assert-equal? (get-var-annotation 'b '((x y z) (a b c) (a b c) (b))) `(bvar b 0 1) )

		(assert-equal? (get-var-annotation 'not '((a) (b) (c))) `(fvar not) )
	)

)

;(run-test-suites foo)
;(run-test foo first-test)
;(run-tests foo test-one)


(exit (run-test-suites foo))
