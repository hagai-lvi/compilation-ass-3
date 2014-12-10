;;; Copyright (c) 2012 Andrew W. Keep
;;; See the accompanying file Copyright for detatils
;(load "formatter.scm")
(display 'abc)
(newline)
(import
	(rnrs)
	(rough-draft unit-test)
	(rough-draft console-test-runner))

(define-test-suite foo

	(define-test test-mock
		(assert-equal? 1 1)
	)

)

;(run-test-suites foo)
;(run-test foo first-test)
;(run-tests foo test-one)


(exit (run-test-suites foo))





















<string>
