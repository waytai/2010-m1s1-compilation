(defun make-vm (size &optional debug)
  (cons (make-array size :initial-element 0)
	`(;; Registres généraux.
	  (R0 . 0)
	  (R1 . 0)
	  (R2 . 0)
	  ;; Base de la pile.
	  (BP . 0)
	  ;; Sommet de la pile.
	  (SP . 0)
	  ;; Sommet du cadre de la pile
	  (FP . 0)
	  ;; Pointeur de code : fin de la mémoire.
	  (PC . ,(- size 1))
	  ;; registres booléens = faux (nil).
	  (PP . nil)
	  (EQ . nil)
	  (PG . nil)
	  ;; Quand HALT passe à t, on arrête la machine.
	  (HALT . nil)
	  ;; Sert uniquement pour le debug
	  (DEBUG . ,debug))))

(defun get-memory (vm index)
  (aref (car vm) index))
(defun set-memory (vm index value)
  (setf (aref (car vm) index) value))
(defun get-register-list (vm)
  (mapcar #'car (cdr vm)))
(defun get-register (vm reg)
  (cdr (assoc reg (cdr vm))))
(defun set-register (vm reg value)
  (setf (cdr (assoc reg (cdr vm))) value))
(defun size-memory (vm)
  (length (car vm)))
(defun get-debug-mode (vm)
  (cdr (assoc 'debug (cdr vm))))

;; TODO : Reste a ajouter la resolution d'etiquette
(defun load-asm (asm &optional (stack-size 100) (debug nil))
  (let ((vm (make-vm (+ (length asm) stack-size) debug))
        (size-vm (+ (length asm) stack-size)))
    (labels ((load-asm-rec (vm index asm debug)
                           (if (endp asm)
                               vm
                             (progn (set-memory vm index (car asm))
                                    (load-asm-rec vm (- index 1) (cdr asm) debug)))))
      (load-asm-rec vm (- size-vm 1) asm debug))))

;;TODO : Rajouter une fonction resolve pour resoudre les differents modes d'adresssage.
;; TODO : Penser a ajouter une table des opcodes

(defvar *table-operateurs*
  '(load store move add sub mult div incr decr push pop
    jmp jsr rtn cmp jeq jpg jpp jpe jge jne nop halt))

(defvar *table-modes-adressage*
  '(constant direct registre indexé indirect indirect-registre indirect-indexé))

;; Fonctions de manipulation de bits :
;; http://psg.com/~dlamkins/sl/chapter18.html
;;   (integer-length n) ≡ ⎡log₂(n)⎤
;;   (ash n décalage) = décalage binaire à gauche (ou droite si négatif)
;;   (logior a b) = ou binaire de a et b.

(defun position1 (x l) (+ 1 (position x l)))

;; TODO : faire une fonction (append-bits n1 size2 n2 size3 n3 ... sizen nn)

(defun append-bits (&optional (n1 0) &rest rest)
  (if (endp rest)
      n1
      (apply #'append-bits
             (logior (ash n1 (car rest))
                     (cadr rest))
             (cddr rest))))

(defvar *nb-operateurs* (length *table-operateurs*))
(defvar *nb-modes-adressage* (length *table-modes-adressage*))
(defvar *nb-opcode-bytes*
  (ceiling (/ (+ (integer-length (+ 1 *nb-operateurs*))
                 (* 2
                    (integer-length (+ 1 *nb-modes-adressage*))))
              ;; On divise par 8 car 8 bits dans un byte.
              8)))

(defun isn-decode (opcode)
  opcode)

;; Instruction est une liste
;; '(operateur mode-adressage-1 valeur-1 mode-adressage-2 valeur-2)
;; Si l'instruction ne prend qu'un (ou zéro) paramètre, les champs
;; correspondants sont mis à nil.

(defun isn-encode (instruction)
  (loop
     for (operateur mode-adressage-1 valeur-1 mode-adressage-2 valeur-2) = instruction
     return (list (append-bits (position1 operateur *table-operateurs*)
                               *nb-modes-adressage*
                               (position1 mode-adressage-1 *table-modes-adressage*)
                               *nb-modes-adressage*
                               (position1 mode-adressage-2 *table-modes-adressage*))
                  (if (eq mode-adressage-1 'registre)
                      (position1 valeur-1 (get-register-list (make-vm 1)))
                      valeur-1)
                  (if (eq mode-adressage-2 'registre)
                      (position1 valeur-2 (get-register-list (make-vm 1)))
                      valeur-2))))

(defun dump-vm (vm)
  (dotimes (i (size-memory vm))
    (let ((val (get-memory vm i)))
      (format T "~&~8,'0x ~2,'0x ~3d ~a" i val val (isn-decode val))))
    (mapcar (lambda (reg)
              (let ((val (get-register vm reg)))
                (format T "~&~4a ~2,'0x ~3d" (string reg) val val)))
            (get-register-list vm))
    (let ((isn (get-memory vm (get-register vm 'PC))))
      (format T "~&Current instruction : ~2,'0x ~a~&" isn (isn-decode isn))))

(defun ISN-LOAD (vm address register)
  (set-register vm register (get-memory vm address)))

(defun ISN-STORE (vm register address)
  (set-memory vm address (get-register vm register)))

(defun ISN-MOVE (vm reg1 reg2)
  (set-register vm reg2 (get-register vm reg1)))

(defun ISN--OP- (vm op reg1 reg2)
  (set-register vm reg2 (funcall op
                                 (get-register vm reg2)
                                 (get-register vm reg1))))

(defun ISN-ADD  (vm reg1 reg2) (ISN--OP- vm #'+ reg1 reg2))
(defun ISN-SUB  (vm reg1 reg2) (ISN--OP- vm #'- reg1 reg2))
(defun ISN-MULT (vm reg1 reg2) (ISN--OP- vm #'* reg1 reg2))
(defun ISN-DIV  (vm reg1 reg2) (ISN--OP- vm #'/ reg1 reg2))

(defun ISN-INCR (vm register)
  (set-register vm register (+ (get-register vm register) 1)))

(defun ISN-DECR (vm register)
  (set-register vm register (- (get-register vm register) 1)))

(defun ISN-PUSH (vm register)
  (ISN-INCR vm 'SP)
  (ISN-STORE vm register (get-register vm 'SP)))

(defun ISN-POP (vm register)
  (ISN-LOAD vm (get-register vm 'SP) register)
  (ISN-DECR vm 'SP))

(defun ISN-JMP (vm dst)
  (set-register vm 'PC (- dst 1)))

(defun ISN-JSR (vm dst)
  (ISN-PUSH vm 'PC)
  (ISN-JMP vm dst))

(defun ISN-RTN (vm)
  (ISN-POP vm 'PC))

(defun ISN-CMP (vm reg1 reg2)
  (set-register vm 'EQ (= (get-register vm reg1) (get-register vm reg2)))
  (set-register vm 'PP (< (get-register vm reg1) (get-register vm reg2)))
  (set-register vm 'PG (> (get-register vm reg1) (get-register vm reg2))))

(defun ISN--JCOND- (pp eq pg vm dst)
  (if (or (and eq (get-register vm 'EQ))
          (and pg (get-register vm 'PG))
          (and pp (get-register vm 'PP)))
      (ISN-JMP vm dst)))

(defun ISN-JEQ (vm dst)
  (ISN--JCOND- nil t nil vm dst))

(defun ISN-JPG (vm dst)
  (ISN--JCOND- nil nil t vm dst))

(defun ISN-JPP (vm dst)
  (ISN--JCOND- t nil nil vm dst))

(defun ISN-JPE (vm dst)
  (ISN--JCOND- t t nil vm dst))

(defun ISN-JGE (vm dst)
  (ISN--JCOND- nil t t vm dst))

(defun ISN-JNE (vm dst)
  (ISN--JCOND- t nil t vm dst))

(defun ISN-NOP (vm)
  vm)

(defun ISN-HALT (vm)
  (set-register vm 'HALT t))


;;Test Unitaire
;; TODO : Faire deftestvar
;; TODO : Finir le test unitaire
(require 'test-unitaire "test-unitaire")
(erase-tests virtual-machine)
(deftestvar virtual-machine t-r0-value (+ 1 (random-test 42))) ;; r0 > 0 pour la division.
(deftestvar virtual-machine t-r1-value (random-test 42))
(deftestvar virtual-machine t-m-value (random-test 42))
(deftestvar virtual-machine t-vm-size (+ 10 (random-test 10)))
(deftestvar virtual-machine t-address (random-test t-vm-size))
(deftestvar virtual-machine vm
  (let ((vm (make-vm t-vm-size)))
	(set-register vm 'R0 t-r0-value)
	(set-register vm 'R1 t-r1-value)
	(set-memory vm t-address t-m-value)
    vm))

(deftest virtual-machine
  (progn (ISN-LOAD vm t-address 'R0)
         (get-register vm 'R0))
  t-m-value)

(deftest virtual-machine
  (progn (ISN-STORE vm 'R0 t-address)
         (get-memory vm t-address))
  t-r0-value)

(deftest virtual-machine
  (progn (ISN-MOVE vm 'R0 'R1)
         (get-register vm 'R1))
  t-r0-value)

(deftest virtual-machine
  (progn (ISN-ADD vm 'R0 'R1)
         (get-register vm 'R1))
  (+ t-r1-value t-r0-value))

(deftest virtual-machine
  (progn (ISN-SUB vm 'R0 'R1)
         (get-register vm 'R1))
  (- t-r1-value t-r0-value))

(deftest virtual-machine
  (progn
	;; Multiplication par un petit nombre (on ne
	;; gère pas d'éventuels overflows pour l'instant).
	(set-register vm 'R0 2)
	(ISN-MULT vm 'R0 'R1)
	(get-register vm 'R1))
  (* 2 t-r1-value))

(deftest virtual-machine
  (progn (ISN-DIV vm 'R0 'R1) ;; R0 > 0 (voir t-r0-value ci-dessus).
         (get-register vm 'R1))
  (/ t-r1-value t-r0-value))

(deftest virtual-machine
  (progn (ISN-INCR vm 'R1)
         (get-register vm 'R1))
  (+ t-r1-value 1))

(deftest virtual-machine
  (progn (ISN-DECR vm 'R0) ;; R0 > 0 (on ne gère pas les négatifs)
         (get-register vm 'R0))
  (- t-r0-value 1))

(deftest virtual-machine
  (progn (ISN-PUSH vm 'R1)
         (get-memory vm (get-register vm 'SP)))
  t-r1-value)

(provide 'vm)
