;;; Copyright (c) 2012 Andrew W. Keep
;;; See the accompanying file Copyright for detatils
(load "compiler.scm")
(import
	(rnrs)
	(rough-draft unit-test)
	(rough-draft console-test-runner))

(define-test-suite foo

	(define-test test-mock
		(assert-equal? 1 1)
	)

	(define-test test-find-minor
		(assert-equal? (find-minor 'a '(a b c)) 0 )
		(assert-equal? (find-minor 'c '(a b c)) 2 )
		(assert-equal? (find-minor 'x '(a b c)) #f )
		
	)

)

;(run-test-suites foo)
;(run-test foo first-test)
;(run-tests foo test-one)


(exit (run-test-suites foo))





















<string>
