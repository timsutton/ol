(define-library (scheme char)
   (export 
      char-ci=?
      char-ci<?
      char-ci>?
      char-ci<=?
      char-ci>=?
   ;;    char-downcase
   ;;    char-foldcase

   ;;    char-alphabetic?
   ;;    char-numeric?
      char-whitespace?
   ;;    char-upper-case?
   ;;    char-lower-case?

      char-upcase
   ;;    digit-value
   ;;    string-ci<=?  * (owl string)
   ;;    string-ci<?   * (owl string)
   ;;    string-ci=?   * (owl string)
   ;;    string-ci>=?  * (owl string)
   ;;    string-ci>?   * (owl string)
   ;;    string-downcase
   ;;    string-foldcase
   ;;    string-upcase
      alphabetic-chars
      numeric-chars
      whitespace-chars
   )

   (import
      (scheme core)
      (owl list)
      (scheme srfi-1)
      (owl math)
      (owl ff) (owl iff))
   (include "owl/unicode-char-folds.scm")

   (begin

      (define (left a b) a)
      (define (putT a) (cons a #T))

      (define uppercase-chars (alist->ff
         (map putT (iota (- #\Z #\A -1) #\A)) ))
      (define lowercase-chars (alist->ff
         (map putT (iota (- #\z #\a -1) #\a)) ))

      (define alphabetic-chars (ff-union #false
         uppercase-chars
         lowercase-chars)) ; will not intersect

      (define numeric-chars (alist->ff
         (map putT (iota (- #\9 #\0 -1) #\0)) ))

      (define whitespace-chars (alist->ff
         (map putT (list #\tab #\newline #\space #\return)) ))


      (define (char-whitespace? ch)
         (whitespace-chars ch #false))

      ; * internal staff
      ; large table 'char => uppercase char'
      (define char-fold-iff
         (fold
            (λ (iff node)
               (if (eq? (length node) 2)
                  (iput iff (car node) (cadr node))
                  (iput iff (car node) (cdr node))))
            #empty char-folds))

      (define (compare cmp a b)
         (let loop ((a a) (b b))
            (or (null? b)
                (and (cmp a (car b))
                     (loop (car b) (cdr b))))))

      ; procedure:  (char-ci=? char1 char2 ...)
      (define (=? a b)
         (or (eq? a b)
             (eq? (iget char-fold-iff a a)
                  (iget char-fold-iff b b))))

      (define (char-ci=? a . b)
         (compare =? a b))

      (assert (char-ci=? #\a)           ===> #true)
      (assert (char-ci=? #\a #\A)       ===> #true)
      (assert (char-ci=? #\A #\A #\a)   ===> #true)
      (assert (char-ci=? #\a #\b)       ===> #false)
      (assert (char-ci=? #\Σ #\σ)       ===> #true) ; greek 'sigma'
      (assert (char-ci=? #\я #\Я)       ===> #true) ; cyrillic 'ja'
      (assert (char-ci=? #\ä #\Ä)       ===> #true) ; baltic 'aeae'


      ; procedure:  (char-ci<? char1 char2 ...)
      (define (<? a b)
          (less? (iget char-fold-iff a a)
                 (iget char-fold-iff b b)))

      (define (char-ci<? a . b)
         (compare <? a b))

      (assert (char-ci<? #\a)           ===> #true)
      (assert (char-ci<? #\a #\B)       ===> #true)
      (assert (char-ci<? #\b #\A)       ===> #false)
      (assert (char-ci<? #\A #\b #\C)   ===> #true)
      (assert (char-ci<? #\A #\c #\b)   ===> #false)
      (assert (char-ci<? #\a #\a)       ===> #false)
      (assert (char-ci<? #\у #\Я)       ===> #true) ; cyrillic
      (assert (char-ci<? #\У #\я)       ===> #true)
      (assert (char-ci<? #\Я #\у)       ===> #false)
      (assert (char-ci<? #\я #\У)       ===> #false)
      (assert (char-ci<? #\ä #\Ö)       ===> #true) ; baltic

      ; procedure:  (char-ci>? char1 char2 ...)
      (define (>? a b)
          (less? (iget char-fold-iff b b)
                 (iget char-fold-iff a a)))

      (define (char-ci>? a . b)
         (compare >? a b))

      ; procedure:  (char-ci<=? char1 char2 ...)
      (define (<=? a b)
          (or (eq? a b)
              (let ((a (iget char-fold-iff a a))
                    (b (iget char-fold-iff b b)))
                 (or (eq? a b)
                     (less? a b)))))

      (define (char-ci<=? a . b)
         (compare <=? a b))

      ; procedure:  (char-ci>=? char1 char2 ...)
      (define (>=? a b)
          (or (eq? a b)
              (let ((a (iget char-fold-iff a a))
                    (b (iget char-fold-iff b b)))
                 (or (eq? a b)
                     (less? b a)))))

      (define (char-ci>=? a . b)
         (compare >=? a b))

      ; procedure:  (char-upcase char)
      (define (char-upcase char)
         (iget char-fold-iff char char))

))
