;; PoC of nuPLN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Loading the Prolog helper                                          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Import custom import library
!(import! &self (library lib_import.metta))

;; Import memoization library
!(import! &self (library lib_memo))

;; Import custom code implemented in Prolog
!(import_prolog_functions_from_file "./lib_nupln.pl"
                                    (nupln_uniform
                                     nupln_set_seed))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;
;; ;; Probabilistic Programming Language ;; ;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;
;; Sampling ;;
;;;;;;;;;;;;;;

;; The idea is to see any random sampling as obtained from a random
;; variable in the statistical sense.  For instance sampling a boolean
;; value would be obtained from
;;
;; Xᵢ : Ω -> Domain -> Bool
;;
;; A *world seed* value is theoretically derived from a world ω ∈ Ω,
;; and then the outcome of Xᵢ for a particular value i ∈ Domain, is
;; obtained by creating a *data seed* specially for i by combining the
;; world seed and the content of i.  Then randomly sample according to
;; that data seed.
;;
;; Of course in practice we do not know ω, thus the world seed is user
;; defined.

!(nupln_set_seed 42)
(= (bernoulli $term $p) (<= (nupln_uniform $term) $p))

;; !(Bernoulli &rng 0.9)

;;;;;;;;;;;;;;;;;
;; Combinators ;;
;;;;;;;;;;;;;;;;;

;; Functions, and predicates in particular, are built using
;; combinators to avoid introducing variables beside MeTTa built-in
;; variables.
;;
;; * ⊙: a -> a -> Bool, to build a predicate given a value, such that
;;   this predicate is True for this value and False everywhere else.
;;
;; * pad: a -> b -> a, to preprend an argument to a
;;   function/predicate.
;;
;; * drop: (a -> b) -> b, to drop the first argument of a
;;   function/predicate.  The new function obtained should be such
;;   that the probability of
;;
;;   (drop f)
;;
;;   being True reflects the probability of
;;
;;   (f x)
;;
;;   being True with x sampled from its domain according to its prior.
;;
;; * ∧: a -> a -> a, to build the point-wise conjunction of two
;;   predicates.
;;
;; * ∨: a -> a -> a, to build the point-wise disjunction of two
;;   predicates.
;;
;; * ¬: a -> a, to build the point-wise negation of a predicate.
;;
;; * ?: a -> a -> a -> a, to build the point-wise trinary conditional
;;   of three predicates.
;;
;; * ∀: TODO
;;
;; * ∃: TODO

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;;;;;;;;;;;;;;;;;;;;; ;;
;; ;; PLN Truth Values ;; ;;
;; ;;;;;;;;;;;;;;;;;;;;;; ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; For now we have only two truth values, ⊤, meaning absolutely true,
;; and ⊥, meaning absolutely false.
;;
;; Beware that absolutely true is represented by ⊤, the unicode top
;; character, not the letter T.
;;
;; ⊤ may correspond to the simple truth value (stv 1 1), while ⊥ may
;; correspond to the simple truth value (stv 0 1).

;;;;;;;;;;;;;;;;;;;;;;;
;; ;;;;;;;;;;;;;;;;; ;;
;; ;; Conditional ;; ;;
;; ;;;;;;;;;;;;;;;;; ;;
;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;
;; Where ;;
;;;;;;;;;;;

;; Evaluate the branch is the condition is True, prune the branch
;; otherwise.
(: where (-> Bool Atom $a))
(= (where $c $x) (if $c $x (empty)))

;; Test
!(where True 42)
!(where False (trace! "Not OK" 42))

;; NEXT: before using ubiquitously, benchmark to make sure it does not
;;       introduces slow downs.

;;;;;;;;;;;;;;;;;;
;; ;;;;;;;;;;;; ;;
;; ;; Syntax ;; ;;
;; ;;;;;;;;;;;; ;;
;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;
;; isExpression ;;
;;;;;;;;;;;;;;;;;;

;; Check if $x is an expression
(= (isExpression $x)
   (case (get-metatype $x)
     (;; Base cases
      (Symbol False)
      (Variable False)
      (Grounded False)
      (Expression True)
      ($else False))))

;;;;;;;;;;;
;; Arity ;;
;;;;;;;;;;;

;; Calculate the arity of a term, which is the number of elements of a
;; tuple if the metatype is Expression, 0 otherwise.
(= (getArity $x)
   (if (isExpression $x)
       (if (== $x ())
           0
           (+ 1 (getArity (cdr-atom $x))))
       0))

;;;;;;;;;;;;;;;;;;;
;; Get Arguments ;;
;;;;;;;;;;;;;;;;;;;

;; Get first argument of (f x1 ... xn)
(= (getFstArg ($f $x)) $x)
(= (getFstArg ($f $x1 $x2)) $x1)
(= (getFstArg ($f $x1 $x2 $x3)) $x1)

;; Get second argument of (f x1 ... xn)
(= (getSndArg ($f $x1 $x2)) $x2)
(= (getSndArg ($f $x1 $x2 $x3)) $x2)

;;;;;;;;;;;;;;;
;; isLiteral ;;
;;;;;;;;;;;;;;;

;; Check if $x is a literal, meaning that if it is an expression, then
;; it can only be a negation of a Symbol, Grounded or Variable
;; (although I am not completely sure about Variable, we'll see).
(= (isLiteral $x)
   (if (isExpression $x)
       (case $x
         ((($f $x1) (and (== $f ¬) (not (isExpression $x1))))
          ($else False)))
       True))

;; Check if $x is a binary call with a given operator
(= (isBinaryOp $op $x)
   (if (isExpression $x)
       (case $x
         ((($op $f $g) True)
          ($else False)))
       False))

;; Check if $x is a conjunction, meaning its root operator is ∧.
(= (isConjunction $x)
   (isBinaryOp ∧ $x))

;; Test isConjunction
!(test
  (isConjunction (∧ F G))
  True)
!(test
  (isConjunction (∨ F G))
  False)
!(test
  (isConjunction F)
  False)

;; Check if $x is a disjunction, meaning its root operator is ∨.
(= (isDisjunction $x)
   (isBinaryOp ∨ $x))

;;;;;;;;;;;;;;;;
;; isNegation ;;
;;;;;;;;;;;;;;;;

;; Check if $x is a negation, meaning its root operator is ¬.
(= (isNegation $x)
   (if (isExpression $x)
       (case $x
         ((($f $g) (== $f ¬))
          ($else False)))
       False))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Custom Syntactic Comparison ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Put $x in a polarized form, meaning, if $x = (¬ $y) then outputs
;;
;; (, $y 1)
;;
;; otherwise outputs
;;
;; (, $x 0)
;;
;; This is useful for defining n< the custom syntactic less than
;; operator to have a negated term contiguously placed to its non
;; negated version in the strict order.
(= (polarize $x)
   (if (isNegation $x)
       (, (getFstArg $x) 1)
       (, $x 0)))

;; Define a custom version of @< such that negation is immediately
;; contiguous in the order, meaning that for instance F is less than
;; (¬ F), but G is greater than (¬ F).  This is convenient to identify
;; patterns like (∧ F (¬ F)) which are not in normal form as (¬ F)
;; will be placed right after F.  It is called n< for normal order.
(= (n< $x $y)
   (if (or (isNegation $x) (isNegation $y))
       (@< (polarize $x) (polarize $y))
       (@< $x $y)))

;; Test n<
!(test
  (n< F (¬ F))
  True)
!(test
  (n< (¬ F) F)
  False)
!(test
  (n< (¬ F) G)
  True)
!(test
  (n< (¬ F) (∧ F G))
  True)

;;;;;;;;;;;;;;;;;;;;;
;; ;;;;;;;;;;;;;;; ;;
;; ;; Reduction ;; ;;
;; ;;;;;;;;;;;;;;; ;;
;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;
;; Normal Form Checker ;;
;;;;;;;;;;;;;;;;;;;;;;;;;

;; Output True iff the arguments of the given conjunction are properly
;; sorted.
(= (isConjSorted (∧ $f $g))
   (if (isConjunction $g)
       (n< $f (getFstArg $g))
       (n< $f $g)))

;; Output True iff the second literal of the given conjunction does
;; not correspond to the negation of the first one.
(= (isConjNonContradict (∧ $f $g))
   (if (isConjunction $g)
       (!= (¬ $f) (getFstArg $g))
       (!= (¬ $f) $g)))

;; Output True iff the arguments of the given disjunction are properly
;; sorted.
(= (isDisjSorted (∨ $f $g))
   (if (isDisjunction $g)
       (n< $f (getFstArg $g))
       (n< $f $g)))

;; Output True iff the second literal of the given disjunction does
;; not correspond to the negation of the first one.
(= (isDisjNonContradict (∨ $f $g))
   (if (isDisjunction $g)
       (!= (¬ $f) (getFstArg $g))
       (!= (¬ $f) $g)))

;; Check if the surface of given term is already in normal form.  The
;; idea is that since this would be called by the backward chainer to
;; construct the term, then by structural induction each elements of
;; its tuple should be in normal form as well.
;;
;; Early benchmark indicates that enabling isShallowNormal can
;; speed-up chaining by multiple orders of magnitude.
;;
;; Actually the code is being broken up inside inference rules for
;; earlier pruning, that way pruning can occur halfway through the
;; proof.  The speed-up is not enormous but significant, at least 2x,
;; probably more.  That code remains here under this form to test
;; normal form checking ideas.
(= (isShallowNormal $x)
   (if (isExpression $x)
       (if (== $x ())
           True
           (case $x
             (;; Nullary application
              (($f) True)
              ;; Unary application
              ;; Like in MOSES, ¬ must be pushed to the leaves
              ((¬ $g) (not (isExpression $g)))
              ;; Binary application
              ;; For now only ∧ is supported.
              ((∧ $g $h)
               ;; Must be in left associative form, with sorted and
               ;; non contradicting arguments.
               (and (not (isConjunction $g))
                    (and (isConjSorted (∧ $g $h))
                         (isConjNonContradict (∧ $g $h)))))
              ($else True))))
       True))

;; Test isShallowNormal
!(test
  (isShallowNormal F)
  True)
!(test
  (isShallowNormal (¬ F))
  True)
!(test
  (isShallowNormal (¬ (¬ F)))
  False)
!(test
  (isShallowNormal (∧ F G))
  True)
!(test
  (isShallowNormal (∧ F F))
  False)
!(test
  (isShallowNormal (∧ F (∧ G H)))
  True)
!(test
  (isShallowNormal (∧ H (∧ G F)))
  False)
!(test
  (isShallowNormal (∧ F (∧ H F)))
  True)
!(test
  (isShallowNormal (∧ F (¬ F)))
  False)
!(test
  (isShallowNormal (∧ F (∧ (¬ F) G)))
  False)

;; Check if the given term is already in normal form (shallow and
;; deep).
;;
;; Early benchmarks indicate that isNormal is a few fold slower than
;; isShallowNormal.
(= (isNormal $x)
   (if (isExpression $x)
       (if (== $x ())
           True
           (let* (($hd (car-atom $x))
                  ($tl (cdr-atom $x)))
             (and (isShallowNormal $x)
                  (and (isNormal $hd) (isNormal $tl)))))
       True))

;; Test isNormal
!(test
  (isNormal F)
  True)
!(test
  (isNormal (¬ F))
  True)
!(test
  (isNormal (¬ (¬ F)))
  False)
!(test
  (isNormal (∧ F G))
  True)
!(test
  (isNormal (∧ F F))
  False)
!(test
  (isNormal (∧ F (∧ G H)))
  True)
!(test
  (isNormal (∧ H (∧ G F)))
  False)
!(test
  (isNormal (∧ F (∧ H F)))
  False)
!(test
  (isNormal (∧ F (∧ (¬ F) G)))
  False)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;;;;;;;;;;;;;;;;;;;;;; ;;
;; ;; Backward Chaining ;; ;;
;; ;;;;;;;;;;;;;;;;;;;;;;; ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; nuPLN Backward Chainer ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Base case
(= (nupln_bc $kb $budget (: $x $a))
   ;; (trace! (👁 nupln_bc_base $kb $budget (: $x $a))
   (if (<= 1 $budget)
       (match $kb (: $x $a) (MkSized 1 (: $x $a)))
       (empty)))
   ;; )

;; Type check conjunction, ∧.  For now conjunction can only be
;; introduced between predicates of identical type. For
;;
;; (∧ F G)
;;
;; to be well typed, F and G must be of the same type.  For now the
;; type is assumed to be
;;
;; a -> Bool
;;
;; but this will probably need to be generalized to a -> b, depending
;; on how predicate arity is handled.  Failing to specialize this type
;; check by enforcing a function or a predicate results in producing
;; weird things like
;;
;; (: (∧ g0t g0t) (≞ (→ (⊙ 0) G) ⊤))
;;
;; thus why we need to be more specific.
;;
;; Additionally it checks that (∧ $f $g) is in normal form as it
;; progressively builds it.  The criteria to check are that (∧ $f $g)
;; be in left associative form, with sorted and non contradicting
;; arguments.  Checking is done as early as possible for maximum
;; pruning.
(= (nupln_bc $kb $budget (: (∧ $f $g) (-> $a Bool)))
   ;; (trace! (👁 nupln_bc $kb $budget (: (∧ $f $g) (-> $a Bool)))
   ;; The budget must be at least 3: 1 for the type checking of $f, 1
   ;; for the type checking of $g, and 1 for the introduction of ∧.
   (if (<= 3 $budget)
       ;; Recurse on premise 1, check that $f is of type (-> $a Bool)
       (let (MkSized $fs (: $f (-> $a Bool)))
         (nupln_bc $kb (- $budget 2) (: $f (-> $a Bool)))
         ;; Check that $f is not a conjunction so that (∧ $f $g) may
         ;; possibly be in left associative form
         (if (isConjunction $f)
             (empty)
             ;; Recurse on premise 2, check that $g is or type (-> $a Bool)
             (let (MkSized $gs (: $g (-> $a Bool)))
               (nupln_bc $kb (- $budget (+ $fs 1)) (: $g (-> $a Bool)))
               ;; Check that (∧ $f $g) is sorted according to the
               ;; normal order with non contradicting arguments.
               (if (and (isConjSorted (∧ $f $g)) (isConjNonContradict (∧ $f $g)))
                   (MkSized (+ 1 (+ $fs $gs)) (: (∧ $f $g) (-> $a Bool)))
                   (empty)))))
       (empty)))
   ;; )

;; Type check disjunction, ∨.  Similar to ∧, see above for more
;; information.
(= (nupln_bc $kb $budget (: (∨ $f $g) (-> $a Bool)))
   ;; (trace! (👁 nupln_bc $kb $budget (: (∨ $f $g) (-> $a Bool)))
   ;; The budget must be at least 3: 1 for the type checking of $f, 1
   ;; for the type checking of $g, and 1 for the introduction of ∨.
   (if (<= 3 $budget)
       ;; Recurse on premise 1, check that $f is of type (-> $a Bool)
       (let (MkSized $fs (: $f (-> $a Bool)))
         (nupln_bc $kb (- $budget 2) (: $f (-> $a Bool)))
         ;; Check that $f is not a disjunction so that (∨ $f $g) may
         ;; possibly be in left associative form
         (if (isDisjunction $f)
             (empty)
             ;; Recurse on premise 2, check that $g is of type (-> $a Bool)
             (let (MkSized $gs (: $g (-> $a Bool)))
               (nupln_bc $kb (- $budget (+ $fs 1)) (: $g (-> $a Bool)))
               ;; Check that (∨ $f $g) is sorted according to the
               ;; normal order with non contradicting arguments.
               (if (and (isDisjSorted (∨ $f $g)) (isDisjNonContradict (∨ $f $g)))
                   (MkSized (+ 1 (+ $fs $gs)) (: (∨ $f $g) (-> $a Bool)))
                   (empty)))))
       (empty)))
   ;; )

;; Type check negation, ¬. Similar to ∧ and ∨, see above for more
;; information.
(= (nupln_bc $kb $budget (: (¬ $f) (-> $a Bool)))
   ;; (trace! (👁 nupln_bc $kb $budget (: (¬ $f) (-> $a Bool)))
   ;; The budget must be at least 2: 1 for the type checking of $f and
   ;; 1 for the introduction of ¬.
   (if (<= 2 $budget)
       ;; Recurse on premise, check that $f is of type (->  $a Bool)
       (let (MkSized $fs (: $f (-> $a Bool)))
         (nupln_bc $kb (- $budget 1) (: $f (-> $a Bool)))
         ;; Check that $f is not an expression because, as in MOSES, ¬
         ;; is expected to be on literals only.
         (if (isExpression $f)
             (empty)
             (MkSized (+ 1 $fs) (: (¬ $f) (-> $a Bool)))))))

;; Type check singleton construction, ⊙.  If $x is of type $a, then
;; (⊙ $x) is of type $a -> Bool.
(= (nupln_bc $kb $budget (: (⊙ $x) (-> $a Bool)))
   ;; (trace! (👁 nupln_bc $kb $budget (: (⊙ $x) (-> $a Bool)))
   ;; The budget must be at least 2: 1 for the type checking of $x,
   ;; and 1 for the introduction of ⊙.
   (if (<= 2 $budget)
       (let (MkSized $xs (: $x $a)) (nupln_bc $kb (- $budget 1) (: $x $a))
            (MkSized (+ 1 $xs) (: (⊙ $x) (-> $a Bool))))
       (empty)))
   ;; )

;; Type check implication, →.  For now it is assumed that implication
;; can only be established between predicates of identical type.  For
;;
;; (→ F G)
;;
;; to be well typed, F and G must be of the same type.  Also the type
;; of an implication is not itself a predicate but a PLN statement.
;; It might be that in the future we do type it as a predicate of
;; perhaps a conditional predicate but for now it is merely a PLN
;; statement.
(= (nupln_bc $kb $budget (: (→ $f $g) Statement))
   ;; (trace! (👁 nupln_bc $kb $budget (: (→ $f $g) Statement))
   ;; The budget must be at least 3: 1 for the type checking of $f, 1
   ;; for the type checking of $g, and 1 for the introduction of →.
   (if (<= 3 $budget)
       (let* (;; Recurse on premise 1 to check that $f is or type $a
              ((MkSized $fs (: $f $a))
               (nupln_bc $kb (- $budget 2) (: $f $a)))
              ;; Recurse on premise 2 to check that $g is or type $a
              ((MkSized $gs (: $g $a))
               (nupln_bc $kb (- $budget (+ $fs 1)) (: $g $a))))
         (MkSized (+ 1 (+ $fs $gs)) (: (→ $f $g) Statement)))
       (empty)))
   ;; )

;; Conjunction evaluation to ⊤.  The query
;;
;; (≞ (→ (⊙ $x) (∧ $f $g)) ⊤)
;;
;; means that ((∧ $f $g) $x) evaluates to True.  The premises are that
;; both ($f $x) and ($g $x) evaluate to True.
;;
;; `cet` stands for conjunction evaluate to true.
(= (nupln_bc $kb $budget (: (cet $fp $gp) (≞ (→ (⊙ $x) (∧ $f $g)) ⊤)))
   ;; (trace! (👁 nupln_bc $kb $budget (: (cet $fp $gp) (≞ (→ (⊙ $x) (∧ $f $g)) ⊤)))
   ;; The budget must be at least 4: 1 for the type checking of (→ (⊙
   ;; $x) (∧ $f $g)), 1 for the evaluation of (→ (⊙ $x) $f), 1 for the
   ;; evaluation of (→ (⊙ $x) $g), and 1 for the introduction of ∧.
   (if (<= 4 $budget)
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (∧ $f $g))
              ((MkSized $as (: (→ (⊙ $x) (∧ $f $g)) $a))
               (nupln_bc $kb (- $budget 3) (: (→ (⊙ $x) (∧ $f $g)) $a)))
              ;; Recurse on premise 2 to make sure that $f evaluates
              ;; to true on $x
              ((MkSized $fs (: $fp (≞ (→ (⊙ $x) $f) ⊤)))
               (nupln_bc $kb (- $budget (+ $as 2)) (: $fp (≞ (→ (⊙ $x) $f) ⊤))))
              ;; Recurse on premise 3 to make sure that $g evaluates
              ;; to true on $x
              ((MkSized $gs (: $gp (≞ (→ (⊙ $x) $g) ⊤)))
               (nupln_bc $kb (- $budget (+ (+ $as $fs) 1))
                         (: $gp (≞ (→ (⊙ $x) $g) ⊤)))))
         ;; Build conclusion
         (MkSized (+ 1 (+ $as (+ $fs $gs)))
                  (: (cet $fp $gp) (≞ (→ (⊙ $x) (∧ $f $g)) ⊤))))
       (empty)))
   ;; )

;; Conjunction evaluation to ⊥, left.  The query
;;
;; (≞ (→ (⊙ $x) (∧ $f $g)) ⊥)
;;
;; means that ((∧ $f $g) $x) evaluates to False based on $f, the left
;; argument.  The premise is that ($f $x) evaluates to False.
;;
;; `cefl` stands for conjunction evaluates to false from left.
(= (nupln_bc $kb $budget (: (cefl $fp) (≞ (→ (⊙ $x) (∧ $f $g)) ⊥)))
   ;; (trace! (👁 nupln_bc $kb $budget (: (cefl $fp) (≞ (→ (⊙ $x) (∧ $f $g)) ⊥)))
   ;; The budget must be at least 3: 1 for the type checking of (→ (⊙
   ;; $x) (∧ $f $g)), 1 for the evaluation of (→ (⊙ $x) $f), and 1 for
   ;; the introduction of ∧.
   (if (<= 3 $budget)
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (∧ $f $g))
              ((MkSized $as (: (→ (⊙ $x) (∧ $f $g)) $a))
               (nupln_bc $kb (- $budget 2) (: (→ (⊙ $x) (∧ $f $g)) $a)))
              ;; Recurse on premise 2 to make sure that $f evaluates
              ;; to false on $x
              ((MkSized $fs (: $fp (≞ (→ (⊙ $x) $f) ⊥)))
               (nupln_bc $kb (- $budget (+ $as 1)) (: $fp (≞ (→ (⊙ $x) $f) ⊥)))))
         ;; Build conclusion
         (MkSized (+ 1 (+ $as $fs)) (: (cefl $fp) (≞ (→ (⊙ $x) (∧ $f $g)) ⊥))))
       (empty)))
   ;; )

;; Conjunction evaluation to ⊥, right.  The query
;;
;; (≞ (→ (⊙ $x) (∧ $f $g)) ⊥)
;;
;; means that ((∧ $f $g) $x) evaluates to False based on $g, the right
;; argument.  The premise is that ($g $x) evaluates to False.
;;
;; `cefr` stands for conjunction evaluates to false from right.
(= (nupln_bc $kb $budget (: (cefr $gp) (≞ (→ (⊙ $x) (∧ $f $g)) ⊥)))
   ;; (trace! (👁 nupln_bc $kb $budget (: (cefr $gp) (≞ (→ (⊙ $x) (∧ $f $g)) ⊥)))
   ;; The budget must be at least 3: 1 for the type checking of (→ (⊙
   ;; $x) (∧ $f $g)), 1 for the evaluation of (→ (⊙ $x) $g), and 1 for
   ;; the introduction of ∧.
   (if (<= 3 $budget)
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (∧ $f $g))
              ((MkSized $as (: (→ (⊙ $x) (∧ $f $g)) $a))
               (nupln_bc $kb (- $budget 2) (: (→ (⊙ $x) (∧ $f $g)) $a)))
              ;; Recurse on premise 2 to make sure that $g evaluates
              ;; to false on $x
              ((MkSized $gs (: $gp (≞ (→ (⊙ $x) $g) ⊥)))
               (nupln_bc $kb (- $budget (+ $as 1)) (: $gp (≞ (→ (⊙ $x) $g) ⊥)))))
         ;; Build conclusion
         (MkSized (+ 1 (+ $as $gs)) (: (cefr $gp) (≞ (→ (⊙ $x) (∧ $f $g)) ⊥))))
       (empty)))
   ;; )

;; Disjunction evaluation to ⊤, left.  The query
;;
;; (≞ (→ (⊙ $x) (∨ $f $g)) ⊤)
;;
;; means that ((∨ $f $g) $x) evaluates to True because $f (the left
;; argument) evaluates to True.  Unlike for conjunction, the right
;; argument does not need to be evaluated, since True is already
;; sufficient to make the disjunction True.
;;
;; `detl` stands for disjunction evaluates to true from left.
(= (nupln_bc $kb $budget (: (detl $fp) (≞ (→ (⊙ $x) (∨ $f $g)) ⊤)))
   ;; (trace! (👁 nupln_bc $kb $budget (: (detl $fp) (≞ (→ (⊙ $x) (∨ $f $g)) ⊤)))
   ;; The budget must be at least 3: 1 for the type checking of (→ (⊙
   ;; $x) (∨ $f $g)), 1 for the evaluation of (→ (⊙ $x) $f), and 1 for
   ;; the introduction of ∨.
   (if (<= 3 $budget)
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (∨ $f $g))
              ((MkSized $as (: (→ (⊙ $x) (∨ $f $g)) $a))
               (nupln_bc $kb (- $budget 2) (: (→ (⊙ $x) (∨ $f $g)) $a)))
              ;; Recurse on premise 2 to make sure that $f evaluates
              ;; to true on $x.  Note that no premise is required on
              ;; $g, since True suffices for the disjunction.
              ((MkSized $fs (: $fp (≞ (→ (⊙ $x) $f) ⊤)))
               (nupln_bc $kb (- $budget (+ $as 1)) (: $fp (≞ (→ (⊙ $x) $f) ⊤)))))
         ;; Build conclusion
         (MkSized (+ 1 (+ $as $fs)) (: (detl $fp) (≞ (→ (⊙ $x) (∨ $f $g)) ⊤))))
       (empty)))
   ;; )

;; Disjunction evaluation to ⊤, right.  The query
;;
;; (≞ (→ (⊙ $x) (∨ $f $g)) ⊤)
;;
;; means that ((∨ $f $g) $x) evaluates to True because $g (the right
;; argument) evaluates to True.  Unlike for conjunction, the left
;; argument does not need to be evaluated, since True is already
;; sufficient to make the disjunction True.
;;
;; `detr` stands for disjunction evaluates to true from right.
(= (nupln_bc $kb $budget (: (detr $gp) (≞ (→ (⊙ $x) (∨ $f $g)) ⊤)))
   ;; (trace! (👁 nupln_bc $kb $budget (: (detr $gp) (≞ (→ (⊙ $x) (∨ $f $g)) ⊤)))
   ;; The budget must be at least 3: 1 for the type checking of (→ (⊙
   ;; $x) (∨ $f $g)), 1 for the evaluation of (→ (⊙ $x) $g), and 1 for
   ;; the introduction of ∨.
   (if (<= 3 $budget)
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (∨ $f $g))
              ((MkSized $as (: (→ (⊙ $x) (∨ $f $g)) $a))
               (nupln_bc $kb (- $budget 2) (: (→ (⊙ $x) (∨ $f $g)) $a)))
              ;; Recurse on premise 2 to make sure that $g evaluates
              ;; to true on $x.  Note that no premise is required on
              ;; $f, since True suffices for the disjunction.
              ((MkSized $gs (: $gp (≞ (→ (⊙ $x) $g) ⊤)))
               (nupln_bc $kb (- $budget (+ $as 1)) (: $gp (≞ (→ (⊙ $x) $g) ⊤)))))
         ;; Build conclusion
         (MkSized (+ 1 (+ $as $gs)) (: (detr $gp) (≞ (→ (⊙ $x) (∨ $f $g)) ⊤))))
       (empty)))
   ;; )

;; Disjunction evaluation to ⊥.  The query
;;
;; (≞ (→ (⊙ $x) (∨ $f $g)) ⊥)
;;
;; means that ((∨ $f $g) $x) evaluates to False.  Unlike for
;; conjunction where the False of one operand is sufficient, for
;; disjunction the premises are that both ($f $x) and ($g $x) evaluate
;; to False.
;;
;; `def` stands for disjunction evaluates to false.
(= (nupln_bc $kb $budget (: (def $fp $gp) (≞ (→ (⊙ $x) (∨ $f $g)) ⊥)))
   ;; (trace! (👁 nupln_bc $kb $budget (: (def $fp $gp) (≞ (→ (⊙ $x) (∨ $f $g)) ⊥)))
   ;; The budget must be at least 4: 1 for the type checking of (→ (⊙
   ;; $x) (∨ $f $g)), 1 for the evaluation of (→ (⊙ $x) $f), 1 for the
   ;; evaluation of (→ (⊙ $x) $g), and 1 for the introduction of ∨.
   (if (<= 4 $budget)
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (∨ $f $g))
              ((MkSized $as (: (→ (⊙ $x) (∨ $f $g)) $a))
               (nupln_bc $kb (- $budget 3) (: (→ (⊙ $x) (∨ $f $g)) $a)))
              ;; Recurse on premise 2 to make sure that $f evaluates
              ;; to false on $x
              ((MkSized $fs (: $fp (≞ (→ (⊙ $x) $f) ⊥)))
               (nupln_bc $kb (- $budget (+ $as 2)) (: $fp (≞ (→ (⊙ $x) $f) ⊥))))
              ;; Recurse on premise 3 to make sure that $g evaluates
              ;; to false on $x
              ((MkSized $gs (: $gp (≞ (→ (⊙ $x) $g) ⊥)))
               (nupln_bc $kb (- $budget (+ (+ $as $fs) 1))
                         (: $gp (≞ (→ (⊙ $x) $g) ⊥)))))
         ;; Build conclusion
         (MkSized (+ 1 (+ $as (+ $fs $gs)))
                  (: (def $fp $gp) (≞ (→ (⊙ $x) (∨ $f $g)) ⊥))))
       (empty)))
   ;; )

;; Product.  The query
;;
;; (: (, $x $y) (, $a $b))
;;
;; means that both $a $b must be proven for (, $a $b) to be proven.
(= (nupln_bc $kb $budget (: (, $x $y) (, $a $b)))
   ;; (trace! (👁 nupln_bc $kb $budget (: (, $x $y) (, $a $b)))
   ;; The budget must be at least 3: 1 for $a, 1 for $b and 1 for the
   ;; introduction of `,`.
   (if (<= 3 $budget)
       (let* (;; Recurse on premise 1 to prove $a
              ((MkSized $xs (: $x $a))
               (nupln_bc $kb (- $budget 2) (: $x $a)))
              ;; Recurse on premise 2 to prove $b
              ((MkSized $ys (: $y $b))
               (nupln_bc $kb (- $budget (+ $xs 1)) (: $y $b))))
         ;; Build product
         (MkSized (+ 1 (+ $xs $ys)) (: (, $x $y) (, $a $b))))
       (empty)))
   ;; )

;;;;;;;;;;;;;;;;
;; ;;;;;;;;;; ;;
;; ;; Test ;; ;;
;; ;;;;;;;;;; ;;
;;;;;;;;;;;;;;;;

;; Enable memoization for nupln_bc
!(memoize nupln_bc)
;; Settings suggested by Minimax-m3
!(config-memoize (unique-limit 10000) (strategy wtinylfu) (size-limit 5))

;; Define F and G over values 0, 1 and 2
!(bind! &kb (new-space))
!(add-atom &kb (: 0 UInt))
!(add-atom &kb (: 1 UInt))
!(add-atom &kb (: 2 UInt))
!(add-atom &kb (: 3 UInt))
!(add-atom &kb (: F (-> UInt Bool)))
!(add-atom &kb (: G (-> UInt Bool)))
!(add-atom &kb (: f0t (≞ (→ (⊙ 0) F) ⊤)))   ; (F 0) = True
!(add-atom &kb (: f1f (≞ (→ (⊙ 1) F) ⊥)))   ; (F 1) = False
!(add-atom &kb (: f2t (≞ (→ (⊙ 2) F) ⊤)))   ; (F 1) = True
!(add-atom &kb (: f3f (≞ (→ (⊙ 3) F) ⊥)))   ; (F 3) = False
!(add-atom &kb (: g0t (≞ (→ (⊙ 0) G) ⊤)))   ; (F 0) = True
!(add-atom &kb (: g1t (≞ (→ (⊙ 1) G) ⊤)))   ; (F 1) = True
!(add-atom &kb (: g2f (≞ (→ (⊙ 2) G) ⊥)))   ; (F 1) = False
!(add-atom &kb (: g3f (≞ (→ (⊙ 3) G) ⊥)))   ; (G 3) = False

;; Type check F
!(test
  (nupln_bc &kb 1 (: F $a))
  (MkSized 1 (: F (-> UInt Bool))))

;; Type check G
!(test
  (nupln_bc &kb 1 (: G $a))
  (MkSized 1 (: G (-> UInt Bool))))

;; Type check (∧ F G)
!(test
  (nupln_bc &kb 3 (: (∧ F G) $a))
  (MkSized 3 (: (∧ F G) (-> UInt Bool))))

;; Type check (∨ F G)
!(test
  (nupln_bc &kb 3 (: (∨ F G) $a))
  (MkSized 3 (: (∨ F G) (-> UInt Bool))))

;; Type check (⊙ 0)
!(test
  (nupln_bc &kb 2 (: (⊙ 0) $a))
  (MkSized 2 (: (⊙ 0) (-> UInt Bool))))

;; Type check (→ (⊙ 0) (∧ F G))
!(test
  (nupln_bc &kb 6 (: (→ (⊙ 0) (∧ F G)) $a))
  (MkSized 6 (: (→ (⊙ 0) (∧ F G)) Statement)))

;; Evaluate (∧ F G) over 0
!(test
  (nupln_bc &kb 9 (: $prf (≞ (→ (⊙ 0) (∧ F G)) $tv)))
  (MkSized 9 (: (cet f0t g0t) (≞ (→ (⊙ 0) (∧ F G)) ⊤))))

;; Evaluate (∧ F G) over 1
!(test
  (nupln_bc &kb 8 (: $prf (≞ (→ (⊙ 1) (∧ F G)) $tv)))
  (MkSized 8 (: (cefl f1f) (≞ (→ (⊙ 1) (∧ F G)) ⊥))))

;; Evaluate (∨ F G) over 1, true from right since (F 1) is False but (G 1) is True
!(test
  (nupln_bc &kb 8 (: $prf (≞ (→ (⊙ 1) (∨ F G)) $tv)))
  (MkSized 8 (: (detr g1t) (≞ (→ (⊙ 1) (∨ F G)) ⊤))))

;; Evaluate (∨ F G) over 2, true from left since (F 2) is True and (G 2) is False
!(test
  (nupln_bc &kb 8 (: $prf (≞ (→ (⊙ 2) (∨ F G)) $tv)))
  (MkSized 8 (: (detl f2t) (≞ (→ (⊙ 2) (∨ F G)) ⊤))))

;; Evaluate (∨ F G) over 3, false since both (F 3) and (G 3) are False
!(test
  (nupln_bc &kb 9 (: $prf (≞ (→ (⊙ 3) (∨ F G)) $tv)))
  (MkSized 9 (: (def f3f g3f) (≞ (→ (⊙ 3) (∨ F G)) ⊥))))

;; Find proof of the evaluation of F over 3 values
!(test
  (nupln_bc &kb 5 (: $prf (, (≞ (→ (⊙ 0) F) ⊤)
                          (, (≞ (→ (⊙ 1) F) ⊥)
                             (≞ (→ (⊙ 2) F) ⊤)))))
  (MkSized 5 (: (, f0t (, f1f f2t))
                (, (≞ (→ (⊙ 0) F) ⊤)
                (, (≞ (→ (⊙ 1) F) ⊥)
                   (≞ (→ (⊙ 2) F) ⊤))))))

;; Find proof of (∧ F G) evaluation over 2 values
!(test
  (nupln_bc &kb 18 (: $prf (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
                              (≞ (→ (⊙ 1) (∧ F G)) ⊥))))
  (MkSized 18 (: (, (cet f0t g0t) (cefl f1f))
                 (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
                    (≞ (→ (⊙ 1) (∧ F G)) ⊥)))))

;; Find proof of (∧ F G) evaluation over 3 values
!(test
  (nupln_bc &kb 27 (: $prf (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
                           (, (≞ (→ (⊙ 1) (∧ F G)) ⊥)
                              (≞ (→ (⊙ 2) (∧ F G)) ⊥)))))
  (MkSized 27 (: (, (cet f0t g0t) (, (cefl f1f) (cefr g2f)))
                 (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
                 (, (≞ (→ (⊙ 1) (∧ F G)) ⊥)
                    (≞ (→ (⊙ 2) (∧ F G)) ⊥))))))

;; Find proof of (∨ F G) evaluation over 3 values.  On 1 (G true, F
;; false) the disjunction is True from the right; on 2 (F true, G
;; false) it is True from the left; on 3 (both false) it is False.
;; Values are chosen so that exactly one of detl, detr or def applies
;; at each input, giving a unique proof.
!(test
  (nupln_bc &kb 27 (: $prf (, (≞ (→ (⊙ 1) (∨ F G)) ⊤)
                           (, (≞ (→ (⊙ 2) (∨ F G)) ⊤)
                              (≞ (→ (⊙ 3) (∨ F G)) ⊥)))))
  (MkSized 27 (: (, (detr g1t) (, (detl f2t) (def f3f g3f)))
                 (, (≞ (→ (⊙ 1) (∨ F G)) ⊤)
                 (, (≞ (→ (⊙ 2) (∨ F G)) ⊤)
                    (≞ (→ (⊙ 3) (∨ F G)) ⊥))))))

;; Infer what predicates could evaluate to the partial truth table
;; corresponding to F.
!(test
  (collapse (nupln_bc &kb 18 (: $prf (, (≞ (→ (⊙ 0) $pred) ⊤)
                                        (≞ (→ (⊙ 1) $pred) ⊥)))))
  ((MkSized 18 (: (, (cet f0t g0t) (cefl f1f))
                  (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
                     (≞ (→ (⊙ 1) (∧ F G)) ⊥))))
   (MkSized 3 (: (, f0t f1f)
                 (, (≞ (→ (⊙ 0) F) ⊤)
                    (≞ (→ (⊙ 1) F) ⊥))))))

;; Infer what predicates could evaluate to the partial truth table
;; corresponding to (¬ F).
;; !(test
  !(nupln_bc &kb 18 (: $prf (, (≞ (→ (⊙ 0) $pred) ⊥)
                               (≞ (→ (⊙ 1) $pred) ⊤))))
  ;; ((MkSized 18 (: (, (cet f0t g0t) (cefl f1f))
  ;;                 (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
  ;;                    (≞ (→ (⊙ 1) (∧ F G)) ⊥))))
  ;;  (MkSized 3 (: (, f0t f1f)
  ;;                (, (≞ (→ (⊙ 0) F) ⊤)
  ;;                   (≞ (→ (⊙ 1) F) ⊥))))))

;; ;; Infer what predicates could evaluate to the truth table
;; ;; corresponding to (∧ F G)
;; !(test
;;   (nupln_bc &kb 27 (: $prf (, (≞ (→ (⊙ 0) $pred) ⊤)
;;                            (, (≞ (→ (⊙ 1) $pred) ⊥)
;;                               (≞ (→ (⊙ 2) $pred) ⊥)))))
;;   (MkSized 27 (: (, (cet f0t g0t) (, (cefl f1f) (cefr g2f)))
;;                  (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
;;                  (, (≞ (→ (⊙ 1) (∧ F G)) ⊥)
;;                     (≞ (→ (⊙ 2) (∧ F G)) ⊥))))))
