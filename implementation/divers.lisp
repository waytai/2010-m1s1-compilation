;; variables "locales" : documentation
(defvar documentation '(function variable struct)) ;; TODO

(defvar meval-op '(car cdr funcall apply mapcar last + - * / read caaaar caaadr caadar caaddr cadaar cadadr caddar cadddr 
		       cdaaar cdaadr cdadar cdaddr cddaar cddadr cdddar cddddr caaar caadr cadar caddr cdaar cdadr cddar
		       cdddr caar cadr cdar cddr first second third fourth fifth sixth seventh eighth ninth tenth
		       tree-equal char schar string string= make-string ))



;; TODO : décider de quelles "primitives" on a besoin.
;; "Primitives" :
;; - (%asm in-values out-values clobber-registers instructions)
;; - (%eval expr env)
;; - (%push-new-env "description")
;; - (%add-top-level-fun-binding name value)
;; - (%add-top-level-var-binding name value)
;; - (%add-fun-binding name value)
;; - (%add-var-binding name value)
;; - (%ref-fun name)
;; Les ref-xxx renvoient un bout de code ASM comme ci-dessous :
;; - Pour une valeur dans la pile :
;;   (%asm () (r0) (r0) "load X(sp) r0;") 
;;   où X est la position dans la pile de name
;; - Pour une valeur dans le top-level :
;;   (%asm () (r0) (r0) "load X(bp) r0;")
;; - Pour une valeur dans le tas (si on en a un)
;;   (%asm () (r0) (r0) "load X r0;")

(defmacro defun (name args &rest body)
  (let ((has-docstring
		 (and (stringp (car body))
			  (cdr body))))
	`(progn
	   (when ,has-docstring
		 (push (car body) documentation)) ;; TODO
	   (%top-level-fun-bind
		,name
		(lambda ,args
		  ,@(if has-docstring
				(cdr body)
			  body))))))

(defmacro setf (place value)
  (cond ((eq (car place) 'car)
		 `(%set-car ,place ,value))
		((eq (car place) 'cdr)
		 `(%set-cdr ,place ,value))
		;; TODO
		(t (error 'setf-invalid-place "setf : invalid place ~a" place))))

(defmacro cond (&rest conditions)
  (if (atom conditions)
	  nil
	`(if ,(caar conditions)
		 ,(if (atom (cdr (cdar conditions))) ;; Si une seule instruction dans la partie droite
			  (car (cdar conditions)) ;; On la met telle qu'elle
			'(progn ,@(cdar conditions))) ;; Sinon, on met un progn autour.
	   (cond ,@(cdr conditions)))))


(defmacro car (list)
  (%asm )) ;; TODO : list dans rX, résultat dans rY => move [indirect rX], rY

(defmacro cdr (list)
  (%asm )) ;; TODO : list dans rX, résultat dans rY => move rX, rY; incr rY; move [indirect rY], rY;

(defmacro let (bindings &rest body)
  `((lambda ,(mapcar #'car bindings)
	  ,@body)
	,@(mapcar #'cadr bindings)))

(defmacro let* (bindings &rest body)
  (if (endp bindings)
      `(progn ,@body)
      `(let (,(car bindings))
         (let* ,(cdr bindings)
           ,@body))))

(defmacro labels (f-bindings &rest body)
  ;; TODO
  )

(defmacro funcall (function &rest args)
  ;; TODO
  )

(defmacro apply (function &rest args)
  ;; TODO
  ;; (last args) est la liste des arguments, les précédents sont des arguments "fixes".
  )

(defun mapcar (fun &rest lists)
  (if (atom list)
	  nil
	(cons (if (atom (cdr lists))
			  (apply fun (caar lists))
			(apply fun (mapcar #'car lists))
			(mapcar fun (mapcar #'cdr lists))))))

(defun last (list)
  (if (atom (cdr list))
	  list
	(last (cdr list))))
