(load "pattern-matcher.scm")
(print-gensym #f)
(define (id x) x)
;;;;;;;;;;;
;; const ;;
;;;;;;;;;;;


(define tagged-with
	(lambda (tag exp)
		(eq? tag (car exp))))

(define annotate-tc
	(lambda (pe)
		(letrec ((atp
					(lambda (pe is-tp)
						(cond	((tagged-with `const pe) pe)
								((tagged-with `var pe) pe)
								((tagged-with `define pe)
									`(define ,(cadr pe) ,(atp (caddr pe) #f) ))
								((tagged-with `or pe)
									(let* (	(reversed-pe (reverse (cadr pe)))
											(last (car reversed-pe))
											(rest (reverse (cdr reversed-pe))))
										`(or 
										,(append	(map (lambda (exp) (atp exp #f) ) rest )
													(list (atp last is-tp))))))
								((tagged-with `lambda-simple pe)
									(with pe (lambda (name param body) `(,name ,param ,(atp body #t)))))
								((tagged-with `lambda-opt pe)
									(with pe (lambda (name param rest body) `(,name ,param ,rest ,(atp body #t)))))
								((tagged-with `lambda-variadic pe)
									(with pe (lambda (name param body) `(,name ,param ,(atp body #t)))))
								((tagged-with `applic pe)
									(if	is-tp
										(with pe (lambda (name operator params)
												`(applic-tp ,(atp operator #f) ,(map (lambda (exp)
																					(atp exp #f)) params))))
										(with pe (lambda (name operator params)
												`(applic ,(atp operator #f) ,(map (lambda (exp)
																					(atp exp #f)) params))))))
								((tagged-with `seq pe)
									(let* (	(reversed-pe (reverse (cadr pe)))
											(last (car reversed-pe))
											(rest (reverse (cdr reversed-pe))))
										`(seq 
										,(append	(map (lambda (exp) (atp exp #f) ) rest )
													(list (atp last is-tp))))))
								((tagged-with `if3 pe)
									(let* (	(first (cadr pe))
											(rest (cddr pe)))
										`(if3 
										,@(append	(list (atp first #f))
													(map (lambda (exp) (atp exp is-tp) ) rest )))))
								(else pe)))))
		(atp pe #f))))


(define get-var-annotation
	(lambda (var-name envs)
		(let ((minor (find-minor var-name (car envs))))
			(if	minor
				`(pvar ,var-name ,minor)
				(let ((major-minor (find-major-minor var-name (cdr envs))))
					(if	major-minor
						major-minor
						`(fvar ,var-name)))))))


(define find-major-minor
	(lambda (var-name envs)
		(letrec ((f (lambda (var-name envs counter)
						(if (null? envs)
							#f
							(let ((minor (find-minor var-name (car envs))))
								(if	minor
									`(bvar ,var-name ,counter ,minor)
									(f var-name (cdr envs) (+ 1 counter) )))))))
		(f var-name envs 0))))

(define find-minor
	(lambda (var-name env)
		(letrec ((f (lambda (var-name env counter)
					(cond	((null? env) #f)
							((eq? var-name (car env)) counter)
							(else (f var-name (cdr env) (+ 1 counter)))))))
		(f var-name env 0))))

(define (^const? x)
	(or 	(boolean? x)
			(char? x)
			(number? x)
			(string? x)
			))

(define (^var? x)
(and (symbol? x)(let ((p (member x *reserved-words*)))
	(if p #f #t))))

(define *reserved-words*
  '(and begin cond define do else if lambda
    let let* letrec or quasiquote unquote 
    unquote-splicing quote set!))

(define *void-object* (void))

(define (^opt-lambda-args-list? list)
	(if (not (list? list))
	    #f
	    (andmap ^var? list)))

(define (^reg-lambda-args-list? list)
	(if (not (list? list))
	    #f
	    (andmap ^var? list)))


;splits the improper list to a pair of proper list and single argument: (opt-lambda-args-list '(a b c . d)) returns '((a b c) . d)
(define (opt-lambda-args-list args-list succ)
	(if (not (pair? args-list))
	    (succ (cons '() args-list))
	    (opt-lambda-args-list (cdr args-list) (lambda (partial-args-list) 
	    (succ (cons (cons (car args-list) (car partial-args-list)) (cdr partial-args-list)))))))

(define (improper-list? x) ;TODO add tests
	(and 	(pair? x)
			(not (null? (cdr (last-pair x))))))

(define (get-opt-lambda-mandatory-args x) (car x))
(define (get-opt-lambda-optional-args x) (cdr x))


(define (let-vars-expressions-list? list) 	;TODO think what are the criterions for a let-vars-expressions-list
	(andmap (lambda (x)vector for each sheme
				(and (list? x) (^var? (car x))))
			list))

(define (get-lambda-variables vars)
	(if (=(length vars)0)
		'()
		(cons (caar vars) (get-lambda-variables (cdr vars)))))


(define (get-lambda-arguments exp)
	(if (=(length exp)0)
		'()
		(cons (cadar exp) (get-lambda-arguments (cdr exp)))))

(define expand-qq
  (lambda (e)
    (cond ((unquote? e) (cadr e))
	  ((unquote-splicing? e)
	   (error 'expand-qq "unquote-splicing here makes no sense!"))
	  ((pair? e)
	   (let ((a (car e))
		 (b (cdr e)))
	     (cond ((unquote-splicing? a) `(append ,(cadr a) ,(expand-qq b)))
		   ((unquote-splicing? b) `(cons ,(expand-qq a) ,(cadr b)))
		   (else `(cons ,(expand-qq a) ,(expand-qq b))))))
	  ((vector? e) `(list->vector ,(expand-qq (vector->list e))))
	  ((or (null? e) (symbol? e)) `',e)
	  (else e))))

(define ^quote?
  (lambda (tag)
    (lambda (e)
      (and (pair? e)
	   (eq? (car e) tag)
	   (pair? (cdr e))
	   (null? (cddr e))))))

(define quasiquote? 
	(lambda (e)
 (eq? e 'quasiquote)))

(define unquote? (^quote? 'unquote))
(define unquote-splicing? (^quote? 'unquote-splicing))

(define s 'unquote)
(define parse
	(let ((run
		(compose-patterns
		(pattern-rule
			(? 'c ^const?)
			(lambda (c) `(const ,c)))
		(pattern-rule
			`(quote ,(? 'c))
			(lambda (c) `(const ,c)))
		(pattern-rule
			`,(? 'v ^var?)
			(lambda (v) `(var ,v)))
		(pattern-rule 	;if3
			`(if ,(? 'test) ,(? 'dit))
			(lambda (test dit)
				`(if3 ,(parse test) ,(parse dit) (const ,*void-object*))))
		(pattern-rule 	;if2
			`(if ,(? 'test) ,(? 'dit) ,(? 'dif))
			(lambda (test dit dif)
				`(if3 ,(parse test) ,(parse dit) ,(parse dif))))
		(pattern-rule 	;lambda-variadic
			`(lambda ,(? `var ^var?) . ,(? `body))	;TODO need to check if the body is legal (also in opt and regular lambdas)
			(lambda (args body)
				`(lambda-variadic ,args ,(parse `(begin ,@body)) )))
		(pattern-rule 	;opt-lambda
			`(lambda ,(? 'opt-arg-list improper-list?) . ,(? 'body))
			(lambda (opt-arg-list body)
				(let* ( 	(args-list (opt-lambda-args-list opt-arg-list (lambda (x) x)))
							(mandatory-args (get-opt-lambda-mandatory-args args-list))
							(optional-arg (get-opt-lambda-optional-args args-list)))
					`(lambda-opt ,mandatory-args ,optional-arg ,(parse `(begin ,@body))))))
		(pattern-rule 	;letrec
			`(letrec ,(? let-vars-expressions-list?) . ,(? 'body))
			(lambda (exp-list body)
				(parse (expand-letrec `(letrec ,exp-list ,@body) ))))
		(pattern-rule 	;reg-lambda
			`(lambda ,(? 'arg-list ^reg-lambda-args-list?) . ,(? 'body))
			(lambda (arg-list body) `(lambda-simple ,arg-list ,(parse `(begin ,@body)))))
	   (pattern-rule
			`(define ,(? 'var ^var?) ,(? 'ex) )
			(lambda (vari ex)
				`(define (var ,vari) ,(parse ex))))
	  	(pattern-rule
			`(define (,(? 'name) . ,(? 'varb)) ,(? 'exp))
			(lambda (first rest exp)
				`(define (var ,first) ,(parse `(lambda ,rest ,exp)))))
		(pattern-rule
			`(define (,(? 'name) . ,(? 'varb)) ,(? 'exp))
			(lambda (first rest exp)
				`(define (var ,first) ,(parse `(lambda ,rest ,exp)))))
		(pattern-rule
			`(begin)
			(lambda()
				`(const ,*void-object*)))
		(pattern-rule
			`(begin ,(? `rest))
			(lambda(rest)
				(parse rest)))
		(pattern-rule
			`(begin . ,(? `rest))
			(lambda(rest)
				`(seq ,(map (lambda(exp)(parse exp))  rest))))
		(pattern-rule
			`(,(? 'a quasiquote?) . ,(? `rest))
			(lambda(first rest)
				(parse (expand-qq (car rest)))))
		(pattern-rule
			`(let ,(? 'va ) . ,(? 'body))
			(lambda(vars body)
				(parse `((lambda ,(get-lambda-variables vars) ,@body) ,@(get-lambda-arguments vars)))))
		(pattern-rule 	;let*
			`(let* ,(? let-vars-expressions-list?) ,(? 'body1) . ,(? 'body-rest))
			(lambda (exp-list body1 body-rest)
				(parse (expand-letstar exp-list body1 body-rest ))))
		(pattern-rule 	;and
			`(and)
			(lambda ()
			`(const #t)))
		(pattern-rule
			`(and ,(? 'first))
			(lambda (first)
				(parse first)))
		(pattern-rule 	;and
			`(and ,(? 'first) ,(? 'second))
			(lambda (first second)
				(parse `(if ,first ,second #f))))
		(pattern-rule 	;and
			`(and ,(? 'first) . ,(? 'rest))
			(lambda (first rest)
				(parse `(if ,first (and ,@rest) #f))))
		(pattern-rule 
			`(or)
			(lambda () (parse #f)))
		(pattern-rule 
			`(or ,(? 'e1))
			(lambda (e1) (parse e1) ))
		(pattern-rule 
			`(or . ,(? 'exps))
			(lambda (exps)
				(let ((parsed-exps (map parse exps)))
					`(or ,parsed-exps))))
		(pattern-rule
			`(,(? 'va  ^var?) . ,(? 'varb list?))
			(lambda (vari variables)
				`(applic (var ,vari) ,(map (lambda (s)(parse s)) variables ))))
		(pattern-rule
			`(,(? 'va list?) . ,(? 'va2 list?))
			(lambda (first rest)
				`(applic ,(parse first) ,(map (lambda (exp)(parse exp)) rest))))
		(pattern-rule
			`(let ,(? 'va ) ,(? 'body))
			(lambda (vars body)
				(parse  `((lambda ,(get-lambda-variables vars) ,body) ,@(get-lambda-arguments vars)))))
		(pattern-rule
			`(cond . ,(? 'cond-list)) ; TODO add identifier for cond list
			(lambda (cond-list) (parse (expand-cond cond-list))))
	)))
	(lambda (e)
		(run e
			(lambda ()
				(error 'parse
				(format "I can't recognize this: ~s" e)))))))

(define expand-letstar (lambda (exp-list body1 body-rest)
	(if (= (length exp-list) 0)
	    (apply beginify `(,body1 ,@body-rest))
	    (let*( 	(seperated-exp-list (seperate-last-element exp-list))
				(last (cdr seperated-exp-list))
				(rest (car seperated-exp-list)))
		(expand-letstar rest `((lambda (,(car last)) ,(apply beginify `(,body1 ,@body-rest)) ) ,(cadr last)) `())
	))))





(define (expand-cond cond-list)
	(letrec ((f (lambda (cond-list succ)
					(cond 	((null? cond-list) (succ cond-list))
							((and (eqv? `else (caar cond-list)) (null? (cdr cond-list)) ) (succ `(begin ,@(cdar cond-list)))) ; TODO handle else
							((and (eqv? `else (caar cond-list)) (not (null? (cdr cond-list))) ) (error `expand-cond (format "else clause must be the last in a cond expression."))) ; TODO ERROR
							(else 	(f 	(cdr cond-list)
										(lambda (rest)
											(if 	(null? rest)
													(succ `(if ,(caar cond-list) (begin ,@(cdar cond-list)) ))
													(succ `(if ,(caar cond-list) (begin ,@(cdar cond-list)) ,rest))))))))))
		(f cond-list (lambda (x) x))))

(define Ym
  (lambda fs
    (let ((ms (map
		(lambda (fi)
		  (lambda ms
		    (apply fi (map (lambda (mi)
				     (lambda args
				       (apply (apply mi ms) args))) ms))))
		fs)))
      (apply (car ms) ms))))

(define expand-letrec
  (lambda (letrec-expr)
    (with letrec-expr
      (lambda (_letrec ribs . exprs)
	(let* ((fs (map car ribs))
	       (lambda-exprs (map cdr ribs))
	       (nu (gensym))
	       (nu+fs `(,nu ,@fs))
	       (body-f `(lambda ,nu+fs ,@exprs))
	       (hofs
		(map (lambda (lambda-expr) `(lambda ,nu+fs ,@lambda-expr))
		  lambda-exprs)))
	  `(Ym ,body-f ,@hofs))))))

(define with (lambda (s f)
					(apply f s)))
;;;;;;;;;;;;;;;;;;
;;; HAGAI-TODO ;;;
;;; lambda-variadic ;;;
;;; letrec
;;;;;;;;;;;;;;;;;;

; return a pair that contain the head of the list and the last element of the list
; example: (seperate-last-element '(1 2 3 4) returns '((1 2 3) . 4)
(define (seperate-last-element list)
	(letrec ((f (lambda (list succ)
					(if (null? (cdr list))
					    (succ `() (car list))
					    (f (cdr list) (lambda (rest last)
					    					(succ (cons (car list) rest) last)))))))
	(f list (lambda (x y) (cons x y)))))

(define (beginify exp1 . lst)
	(if (and (list? lst) (> (length lst) 0))
	    `(begin ,exp1 ,@lst)
	    exp1))


(define (add-list new-list bound-list)

	(cons new-list bound-list)
	)


; (define (treverse-pe-a pe bound-list)
; 	(letrec ((treverse-pe (trace-lambda what(pe bound-list)
; 	(cond 	((null? pe) pe) 
; 			((and (pair? pe)(eq? (car pe) 'lambda-simple))(treverse-pe (cdr pe)(add-list (cadr pe) bound-list)))
; 			((and (pair? pe)(eq? (car pe) 'var))((set-car! pe 'haha)pe))

; 		(else (cons (treverse-pe (car pe) bound-list) (treverse-pe (cdr pe) bound-list))))))
	
; 	(begin (treverse-pe pe bound-list)
; 		pe)))
	(define (pe->lex-pe pe)
		(treverse pe '(())))

	(define (treverse pe bound-list)
		(cond 
			((null? pe) pe)
			((or (^const? pe)(symbol? pe))pe)
			((and (pair? pe)(eq? (car pe) 'lambda-simple))
				(cons 
					(treverse (car pe) (add-list (cadr pe) bound-list))
					(treverse (cdr pe) (add-list (cadr pe) bound-list))
					))
			((and (pair? pe)(eq? (car pe) 'lambda-opt))(cons 
				(treverse (car pe) (add-list (append (cadr pe) (cddr pe)) bound-list))
				(treverse (cdr pe) (add-list (append (cadr pe) (cddr pe)) bound-list))
				))
			((and (pair? pe)(eq? (car pe) 'lambda-variadic))(cons 
				(treverse (car pe) (add-list (cdr pe) bound-list))
				(treverse (cdr pe) (add-list (cdr pe) bound-list))
				))
			
			((and (pair? pe)(eq? (car pe) 'var)) (get-var-annotation (cadr pe) bound-list))
			(else (cons (treverse (car pe) bound-list)(treverse (cdr pe) bound-list)))))
