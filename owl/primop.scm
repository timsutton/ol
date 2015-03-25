;; vm rimops

;; todo: convert tuple to variable arity
;; todo: convert arity checks 17 -> 25

;; todo: maybe move ncar, and other "n" to the normal but with macroses on top level with type checking.

(define-library (owl primop)
   (export 
      primops
      primop-name ;; primop → symbol | primop
      multiple-return-variable-primops
      variable-input-arity?
      special-bind-primop?

      ;; primop wrapper functions
      bind
      ff-bind
      mkt

      ; todo: оформить как-то в особом модуле, что ли...      
      run
      halt
      wait
      
      set-ticker-value
      _yield
      
      ;; extra ops
      set-memory-limit get-word-size get-memory-limit start-seccomp

      apply apply-cont ;; apply post- and pre-cps
      
      call/cc call-with-current-continuation 
      lets/cc)

   (import
      (owl defmac))

   (begin
      ;; Список кодов виртуальной машины:
      (define JF2 25)
      (define APPLY 20)
      (define RET 24)
   
   
      ;; changing any of the below 3 primops is tricky. they have to be recognized by the primop-of of 
      ;; the repl which builds the one in which the new ones will be used, so any change usually takes 
      ;; 2 rebuilds.

      ; these 2 primops require special handling, mainly in cps

      ;; turn to badinst soon, possibly return later
      (define ff-bind '__ff-bind__)  ; (func '(2 49))
      (define bind    '__bind__)     ; (func '(2 32 4 5  24 5))
      ; this primop is the only one with variable input arity
      (define mkt     '__mkt__)      ; (func '(4 23 3 4 5 6 7  24 7))

      ; пара служебных функций:
      (define (append a b) ; append
         (if (eq? a '())
            b
            (cons (car a) (append (cdr a) b))))
            

      ; то, что я добавил - надо еще тестировать
      (define (- a b)
         (let* ((n _ (fx- a b)))
            n))
      (define (+ a b)
         (let* ((n _ (fx+ a b)))
            n))
      (define (nth o n)
         (if (eq? n 0)
            (car o)
            (nth (cdr o) (- n 1))))
      
      (define (length lst) ; length of lst
         (let loop ((lst lst) (n 0))
            (if (eq? lst '())
               n
               (loop (cdr lst) (+ n 1)))))

      ; трансформаторы кода в реальный байткод
      (define (func lst)
         (let*
            ((arity (car lst))
             (lst (cdr lst))
             (len (length lst)))
            (raw
               (append (list JF2 arity 0 len)
                       (append lst '(17)))   ; fail if arity mismatch (17 == arity-error)
               type-bytecode #false)))
               

      ; todo: переделать с разименованием через define-syntax
      (define (desc name bytecode function)
         (tuple name   (nth bytecode 1)
                    (- (nth bytecode 0) 1) 1 function))


      ;; these rest are easy
      ; 24 = RET
      ;                  '(arity . (command arguments . command arguments))
      ; арность + непосредственный байткод примитивов
      ; дело в том, что эти команды оформляются как JF2 арность байткод, JF2 проверяет (и выравнивает, если надо) арность
;      (define (primop name code inargs outargs)
;         (let*
;            ((arity     (+ inargs outargs))
;             (bytecode  code)
;             (len       (length bytecode))
;             (primitive (raw
;                          (append (list 25 arity 0 len) ; 25 == JF2
;                                  (append bytecode '(17)))    ; 17 == ARITY-ERROR
;                          type-bytecode #false)))
;            (tuple name (car bytecode) inargs outargs primitive)))
      (define (primop name code inargs outargs)
         (let*
            ((arity     (+ inargs outargs))
             (bytecode  code)
             (len       (length bytecode))
             (primitive (raw
                          (append (list JF2 arity 0 len) ; 25 == JF2
                                  bytecode)    ; 17 == ARITY-ERROR == добавляется автоматически в (assemble-code)
                          type-bytecode #false)))
            (tuple name (car bytecode) inargs outargs primitive)))



      ; clock - специальная команда, надо использовать как (let* ((s ms (clock))) ... )
      (define _sleep      (func '(2 37 4 5        24 5)))   ;; todo: <- move to sys
;      (define _connect    (func '(3 34 4 5 6      24 6)))   ;; todo: <- move to sys

      ; 2
      (define mkblack  (func '(5 42 4 5 6 7 8 24 8)))
      (define mkred    (func '(5 43 4 5 6 7 8 24 8)))
      (define red?     (func '(2 41 4 5 24 5)))
      (define ff-toggle   (func '(2 46 4 5        24 5)))
      (define listuple (func '(4 35 4 5 6 7 24 7)))

;      (define cons     (func '(3 51 4 5  6  24 6)))
;      (define clock       (func '(1  61 3 4 2 5 2))) ; 9 = MOVE, 61 = CLOCK
;      (define clock       (raw (list JF2 1 0 6   61 3 4 2 5 2 17) type-bytecode #false))


      ; выглядит так, что байткод не особо то и нужен - он для
      ; 1) вычисления длины команды (для jf2)
      ; 2) ознакомительных целей
      (define primitives
         (list
            ; пара специальных вещей. todo: разобраться, почему они тут а не в общем списке функци в/м
            (tuple 'bind         32    1 #false bind)     ;; (bind thing (lambda (name ...) body)), fn is at CONT so arity is really 1
            (tuple 'ff-bind      49    1 #false ff-bind)  ;; SPECIAL ** (ffbind thing (lambda (name ...) body)) 
            (tuple 'mkt          23   'any   1  mkt)      ;; mkt type v0 .. vn t


;            (primop 'cons       '(51 4 5  6  24 6)  2 1)

            (tuple 'cons        51 2 1 (raw (list JF2 3 0 6  51 4 5 6  24 6  17) type-bytecode #false))              ;; must add 61 to the multiple-return-variable-primops list

            ; tmp
;            (primop 'sys-prim2  '(61 4 24 4)  'any 1) ; todo: rename sys-prim to syscall

            ; последний элемент используется в primop-arities
            (tuple 'clock       61 0 2 '())              ;; must add 61 to the multiple-return-variable-primops list
;                (raw '() type-bytecode #false))
                ;clock)   ; (clock) → posix-time x ms
;             (define clock     (func '(1  9 3 5        61 3 4 2 5 2))) ; 9 = MOVE, 61 = CLOCK
;            (primop 'clock      '(62                 )  0 2)

            ;                                   arity     len
;            (tuple 'clock 62 0 2 (raw (list JF2 2      0  1   62) type-bytecode #false))
            
            ; apply

            ; непосредственный код
            (primop 'raw        '(60 4 5 6    7  24 7)  3 1) ;; make raw object, and *add padding byte count to type variant*
            (primop 'sys        '(27 4 5 6 7  8  24 8)  4 1) ; тут было что-то особенное (в смысле, что количество аргументов было 4, а не 3 написано)
            (primop 'run        '(50 4 5      6  24 6)  2 1)            

            (primop 'sys-prim   '(63 4 5 6 7  8  24 8)  4 1) ; todo: rename sys-prim to syscall
            
            ; https://www.gnu.org/software/emacs/manual/html_node/eintr/Strange-Names.html#Strange-Names
            ; Strange Names
            ; The name of the cons function is not unreasonable: it is an abbreviation of the word `construct'.
            ; The origins of the names for car and cdr, on the other hand, are esoteric: car is an acronym from
            ; the phrase `Contents of the Address part of the Register'; and cdr (pronounced `could-er') is an
            ; acronym from the phrase `Contents of the Decrement part of the Register'. These phrases refer to
            ; specific pieces of hardware on the very early computer on which the original Lisp was developed.
            ; Besides being obsolete, the phrases have been completely irrelevant for more than 25 years to anyone
            ; thinking about Lisp. Nonetheless, although a few brave scholars have begun to use more reasonable
            ; names for these functions, the old terms are still in use. In particular, since the terms are used
            ; in the Emacs Lisp source code, we will use them in this introduction.
;            (primop 'cons       '(51 4 5  6  24 6)  2 1)

            (primop 'type       '(15 4    5  24 5)  1 1)  ;; get just the type bits (new)
            (primop 'size       '(36 4    5  24 5)  1 1)  ;; get object size (- 1)
            (primop 'cast       '(22 4 5  6  24 6)  2 1)  ;; cast object type (works for immediates and allocated)
            
            (primop 'car        '(52 4    5  24 5)  1 1)
            (primop 'cdr        '(53 4    5  24 5)  1 1)
            (primop 'ref        '(47 4 5  6  24 6)  2 1)   ; op47 = ref t o r = prim_ref(A0, A1)
            
            (primop 'set        '(45 4 5 6  7  24 7)  3 1) ; (set tuple pos val) -> tuple'
            (primop 'set-car!   '(11 4 5    6  24 6)  2 1)
            (primop 'set-cdr!   '(12 4 5    6  24 6)  2 1)
;           (primop 'set!       '(10 4 5 6  7  24 7)  3 1) ; (set! tuple pos val)
            
            (primop 'eq?        '(54 4 5  6  24 6)  2 1)
            (primop 'lesser?    '(44 4 5  6  24 6)  2 1)
            
            ; поддержка больших чисел
            ;; вопрос - а нахрена именно числовой набор функций? может обойдемся обычным?
            (primop 'ncons      '(29 4 5  6  24 6)  2 1)
            (primop 'ncar       '(30 4    5  24 5)  1 1)
            (primop 'ncdr       '(31 4    5  24 5)  1 1)
            
            ;; логика
            (primop 'fxband     '(55 4 5  6  24 6)  2 1)
            (primop 'fxbor      '(56 4 5  6  24 6)  2 1)
            (primop 'fxbxor     '(57 4 5  6  24 6)  2 1)
            
            ;; строки
            (primop 'refb       '(48 4 5  6  24 6)  2 1)
            (primop 'sizeb      '(28 4    5  24 5)  1 1)   ;; raw-obj -> numbe of bytes (fixnum)


            ;; математика
;            (primop 'fx+        '(38 4 5    6 7    24 7)  2 2)
;            (primop 'fx*        '(39 4 5    6 7    24 7)  2 2)
;            (primop 'fx-        '(40 4 5    6 7    24 7)  2 2)
;            (primop 'fx/        '(26 4 5 6  7 8 9  24 7)  3 3) 
;            (primop 'fx>>       '(58 4 5    6 7    24 7)  2 2)
;            (primop 'fx<<       '(59 4 5    6 7    24 7)  2 2)
            (primop 'fx+        '(38 4 5    6 7    24 7)  2 2)
            (primop 'fx*        '(39 4 5    6 7    24 7)  2 2)
            (primop 'fx-        '(40 4 5    6 7    24 7)  2 2)
            (primop 'fx/        '(26 4 5 6  7 8 9  24 7)  3 3) 
            (primop 'fx>>       '(58 4 5    6 7    24 7)  2 2)
            (primop 'fx<<       '(59 4 5    6 7    24 7)  2 2)

            ; todo: move this to the sys-prim
            (tuple '_sleep       37 1 1 _sleep)   ;; (_sleep nms) -> #true

            ; поддержка ff деревьев
            (tuple 'listuple     35 3 1 listuple)  ;; (listuple type size lst)
            (tuple 'mkblack      42 4 1 mkblack)   ; (mkblack l k v r)
            (tuple 'mkred        43 4 1 mkred)   ; ditto
            (tuple 'red?         41 1 #false red?)  ;; (red? node) -> bool
            (tuple 'ff-toggle    46 1 1 ff-toggle)  ;; (fftoggle node) -> node', toggle redness
       ))

      (define primops primitives)

      (define (get-primitive name)
         (let loop ((p primops))
            (if (eq? (ref (car p) 1) name)
                (car p)
                (loop (cdr p)))))
                
      ; не понимаю, зачем run экспортить. А, да, еще она не была включена в primops
      (define run (ref (get-primitive 'run) 5))

;; Список sys-prim'ов
; поэтапный перевод sys-prim'ов в syscall'ы
; 1. добавить 100 к старым номерам
; 2. завести правильные новые
; 3. удалить старые

;      (define (__fsend) (sys-prim 0 #false #false #false))
;      1 __fopen
;      2 __close
;      3 __sopen
;      4 __accept
      
;      5 __fread
;      +6 __exit
;      +7 __set-memory-limit
;      +8 __get-machine-word-size
;      +9 __get-memory-limit
;      +10 __enter-linux-seccomp
;      +22 __set-ticker-value

;      30 __dlopen
;      31 __dlsym
;      32 __pinvoke
;      33 __gc ; TEMP
      
;      11 __sys-open-dir
;      12 __sys-read-dir
;      13 __sys-closedir
;      14 __set-ticks
;      15 __fsocksend
;      16 __getenv
;      17 __exec[v]
;      20 __chdir
;      19 wait <pid> <respair>
;      18 fork
;      21 kill



      ;; special things exposed by the vm
      (define (set-memory-limit n) (sys-prim 1007 n n n))
      (define (get-word-size)      (sys-prim 1008 #false #false #false))
      (define (get-memory-limit)   (sys-prim 1009 #false #false #false))
      (define (start-seccomp)      (sys-prim 1010 #false #false #false)) ; not enabled by defa

      ;; stop the vm *immediately* without flushing input or anything else with return value n
      (define (halt n)             (sys-prim 1006 n n n))
      ;; make thread sleep for a few thread scheduler rounds
      (define (set-ticker-value n) (sys-prim 1022 n #false #false))
      (define (_yield)             (set-ticker-value 0))
      (define (wait n)
         (if (eq? n 0)
            n
            (let* ((n (- n 1)))
               (_yield)
               (wait n))))



      ;; from cps
      (define (special-bind-primop? op)
         (or (eq? op 32) (eq? op 49)))  ; __bind__ or __ff-bind__

      ;; fixme: handle multiple return value primops sanely (now a list)
      (define multiple-return-variable-primops
         (list
            49 ; (ref (get-primitive 'ff-bind) 2) ; 49
            26 ; (ref (get-primitive 'fxqr) 2) ; 26
            
            38 39 40 58 59 37 61
            ))

      (define (variable-input-arity? op) (eq? op 23)) ;; mkt

      (define apply      (raw (list APPLY)              type-bytecode #false)) ;; <- no arity, just call 20
      (define apply-cont (raw (list (fxbor APPLY #x40)) type-bytecode #false))

      ; call/cc
      (define call-with-current-continuation
         ('_sans_cps
            (λ (k f)
               (f k
                  (case-lambda
                     ((c a) (k a))
                     ((c a b) (k a b))
                     ((c . x) (apply-cont k x)))))))
      (define call/cc call-with-current-continuation)


      (define-syntax lets/cc 
         (syntax-rules (call/cc)
            ((lets/cc (om . nom) . fail) 
               (syntax-error "let/cc: continuation name cannot be " (quote (om . nom)))) 
            ((lets/cc var . body) 
               (call/cc (λ (var) (lets . body))))))

      ;; non-primop instructions that can report errors
      (define (instruction-name op)
         (cond
            ((eq? op 17) 'arity-error)
            ((eq? op 32) 'bind)
;            ((eq? op 50) 'run)
            (else #false)))
         
      (define (primop-name pop)
         (let ((pop (fxband pop 63))) ; ignore top bits which sometimes have further data
            (or (instruction-name pop)
               (let loop ((primops primops))
                  (cond
                     ((null? primops) pop)
                     ((eq? pop (ref (car primops) 2))
                        (ref (car primops) 1))
                     (else
                        (loop (cdr primops))))))))


; проверку типов вынесем на уровень компилятора!
; можно и в отдельный файл
      ; from interop.scm
      (define (interop op a b)
         (call/cc (λ (resume) (sys resume op a b))))
      (define (error reason info)
         (interop 5 reason info))
      (define (pair? x) (eq? type-pair (type x))) ; list.scm
      (define (fixnum? x) 
         (let ((t (type x)))
            (or 
               (eq? t type-fix+)
               (eq? t type-fix-)
               )))



      (define (set-car! object value)
         (if (and (pair? object) (fixnum? value))
            (set-car! object value)
            (error "set-car! first argument is not a pair")))
      (define (set-cdr! object value)
         (if (and (pair? object) (fixnum? value))
            (set-cdr! object value)
            (error "set-car! first argument is not a pair")))

))
