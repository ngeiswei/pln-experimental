;; PoC of nuPLN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Loading the Prolog helper                                          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Import custom import library
!(import! &self (library lib_import.metta))

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
   (== (get-metatype $x) Expression))

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

;;;;;;;;;;;;;;;;;;;;;
;; Count Arguments ;;
;;;;;;;;;;;;;;;;;;;;;

;; Count the number of arguments of a binary operator in right
;; associative form.  For instance (∧ F (∧ G H)) has 3 arguments.
(= (countArgsRA $op $x)
   (if (isExpression $x)
       (case $x
         ((($f $x1 $x2) (if (== $op $f)
                            (+ 1 (countArgsRA $op $x2))
                            1))
          ($else 1)))
       1))

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
              ((∧ $g $h)
               ;; Must be in left associative form, with sorted and
               ;; non contradicting arguments.
               (and (not (isConjunction $g))
                    (and (isConjSorted (∧ $g $h))
                         (isConjNonContradict (∧ $g $h)))))
              ((∨ $g $h)
               ;; Must be in left associative form, with sorted and
               ;; non contradicting arguments.
               (and (not (isDisjunction $g))
                    (and (isDisjSorted (∨ $g $h))
                         (isDisjNonContradict (∨ $g $h)))))
              ($else True))))
       True))

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

;;;;;;;;;;;;;;;;;;;;;;;;;
;; Normal Form Builder ;;
;;;;;;;;;;;;;;;;;;;;;;;;;

;; Reduce a term to an equivalent term in normal form.  The strategy
;; is to recursively normalize every subterm, then for binary ∧ and ∨
;; collect the operands (flattening left-associative chains), sort
;; them using the normal order (which agrees with Prolog's @< on the
;; resulting expressions), and finally rebuild a left-associative
;; binary tree.
;;
;; Note that this is a syntactic reduction: it does not attempt to
;; simplify tautologies (∨ F (¬ F)) or contradictions (∧ F (¬ F)) nor
;; to absorb redundant literals.  The result is an equivalent term
;; that satisfies isNormal.
;;
;; Note also that (¬ g) is normalized by normalizing g, which
;; preserves the property that ¬ only wraps literals when the input
;; was already of that shape.  Inputs that violate that property
;; (like (¬ (∧ F G))) are left as-is, since pushing negation in is a
;; separate transformation.
(= (toNormal $x)
   (if (isExpression $x)
       (case $x
         (;; Nullary application or empty expression: already normal.
          (($f) $x)
          ;; Negation.  Recursively normalize the argument; the
          ;; result is unchanged modulo the inner term being
          ;; normalized.
          ((¬ $g) (¬ (toNormal $g)))
          ;; Conjunction: flatten the ∧ chain across the two
          ;; (already-normalized) arguments, sort and rebuild.
          ((∧ $g $h)
           (buildOp ∧ (sortByN< (flattenOp ∧ (toNormal $g)
                                           (flattenOp ∧ (toNormal $h) ())))))
          ;; Disjunction: same as above, with ∨.
          ((∨ $g $h)
           (buildOp ∨ (sortByN< (flattenOp ∨ (toNormal $g)
                                           (flattenOp ∨ (toNormal $h) ())))))
          ;; Other expressions (e.g. function applications): leave
          ;; as is, they are not part of the boolean fragment.
          ($else $x)))
       $x))

;; Flatten an operator chain.  If the term is a binary `(op a b)`
;; expression whose head matches the operator being flattened,
;; recursively flatten `a` and `b` and concatenate them in front of
;; the accumulator.  Otherwise, prepend the term to the accumulator.
;;
;; This is written as a single guarded clause rather than two
;; pattern-matching clauses because two clauses — one matching
;; `($op $a $b)` and one matching `$x` — would both match the same
;; input (since `$x` matches any term), producing two solutions and
;; making `flattenOp` non-deterministic.  The guard makes the
;; decision locally, leaving only one clause for the function and
;; avoiding spurious choice points.
(= (flattenOp $op $x $acc)
   (if (and (isExpression $x) (== (car-atom $x) $op))
       (flattenOp $op (car-atom (cdr-atom $x))
                  (flattenOp $op (car-atom (cdr-atom (cdr-atom $x))) $acc))
       (cons-atom $x $acc)))

;; Rebuild a left-associative binary tree from a non-empty list of
;; operands.  The result is a single operand when the list has one
;; element, or (op hd (buildOp op tl)) otherwise.
;;
;; The base case tests `(cdr-atom $xs) == ()` rather than `$xs ==
;; ()` because the latter would mistake a single-element list for the
;; empty list and yield `(op hd ())` instead of `hd`.  Also, using a
;; single guarded clause (rather than two pattern-matching clauses)
;; avoids a subtle issue with MeTTa's metta->prolog translation where
;; a recursive clause headed `(buildOp $xs ...)` also matches the
;; empty list, causing findall to backtrack into infinite recursion.
(= (buildOp $op $xs)
   (if (== (cdr-atom $xs) ())
       (car-atom $xs)
       ($op (car-atom $xs)
            (buildOp $op (cdr-atom $xs)))))

;; Sort a list of operands using the normal order `n<`.  Because
;; `n<` agrees with `@<` everywhere except when one operand is a
;; negation, the trick is to wrap each element as a (sortKey . orig)
;; pair where sortKey is the polarized literal for negations and the
;; element itself otherwise.  Sorting pairs with `sort-atom` (which
;; uses `@<` lexicographically on the pair) yields the correct n<
;; order.  The original elements are then recovered by stripping the
;; sortKey wrapper.
(= (sortByN< $list)
   (pairSeconds (sort-atom (map makeSortPair $list))))

;; Wrap an element for n<-based sorting.  Each element is paired
;; with its `polarize` value as the sortKey.  `polarize` already
;; implements the ordering trick used by `n<`: it tags a positive
;; element with `(, x 0)` and a negation `(¬ x)` with `(, x 1)`,
;; so the tagged forms sort next to each other in the right order.
;; Sorting pairs with `sort-atom` (which uses `@<` lexicographically)
;; yields the same order as `n<` on the originals.  We then strip
;; the tagged sortKey, leaving the original elements in n<-sorted
;; order.
(= (makeSortPair $x)
   (cons-atom (polarize $x) (cons-atom $x ())))

;; Project the second element out of every pair in a list.  See the
;; note on `buildOp` above for why this uses `if` instead of a base
;; clause.
(= (pairSeconds $xs)
   (if (== $xs ())
       ()
       (cons-atom (car-atom (cdr-atom (car-atom $xs)))
                  (pairSeconds (cdr-atom $xs)))))

;; Apply a unary function to every element of a list.  Used here to
;; build the sortKey/original pairs in `sortByN<`.  See the note on
;; `buildOp` above for why this uses `if` instead of a base clause.
(= (map $f $xs)
   (if (== $xs ())
       ()
       (cons-atom ($f (car-atom $xs))
                  (map $f (cdr-atom $xs)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;;;;;;;;;;;;;;;;;;;;;; ;;
;; ;; Backward Chaining ;; ;;
;; ;;;;;;;;;;;;;;;;;;;;;;; ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;
;; Control Structure ;;
;;;;;;;;;;;;;;;;;;;;;;;

;; Define control type and constructors for inference control
;;
;; nupln_bc takes a control structure in argument for instance
;; control.  It also returns, alongside the query result, the control
;; structure with for now the *remaining* budgets after the proof:
;;
;; (, (MkControl $size $depth) $result)
;;
;; A proof consumes one unit of size per symbol, and one unit of depth
;; per inference step, except products (`,`) which consume no depth so
;; that conjunctions of queries keep a balanced depth budget.
(: Control Type)
(: MkControl (-> Number                 ; Remaining size budget
                 Number                 ; Remaining depth budget
                 Control))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; nuPLN Backward Chainer ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Base case
(= (nupln_bc $kb (MkControl $size $depth) (: $x $a))
   ;; (trace! (👁 nupln_bc_base $kb (MkControl $size $depth) (: $x $a))
   (if (and (<= 1 $size) (<= 1 $depth))
       (match $kb (: $x $a) (, (MkControl (- $size 1) (- $depth 1)) (: $x $a)))
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
(= (nupln_bc $kb (MkControl $size $depth) (: (∧ $f $g) (-> $a Bool)))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth) (: (∧ $f $g) (-> $a Bool)))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of ∧ plus the proofs of the premises.  The first
   ;; premise is charged the unit of ∧, the second premise inherits
   ;; the remaining budget of the first one, and the conclusion
   ;; returns the remaining budget of the second premise.
   (if (and (<= 3 $size) (<= 2 $depth))
       ;; Recurse on premise 1, check that $f is of type (-> $a Bool)
       (let (, (MkControl $fsize $fdepth) (: $f (-> $a Bool)))
         (nupln_bc $kb (MkControl (- $size 1) (- $depth 1))
                   (: $f (-> $a Bool)))
         ;; Check that $f is not a conjunction so that (∧ $f $g) may
         ;; possibly be in left associative form
         (if (isConjunction $f)
             (empty)
             ;; Recurse on premise 2, check that $g is or type (-> $a Bool)
             (let (, (MkControl $gsize $gdepth) (: $g (-> $a Bool)))
               (nupln_bc $kb (MkControl $fsize (- $depth 1))
                         (: $g (-> $a Bool)))
               ;; Check that (∧ $f $g) is sorted according to the
               ;; normal order with non contradicting arguments.
               (if (and (isConjSorted (∧ $f $g)) (isConjNonContradict (∧ $f $g)))
                   (, (MkControl $gsize (min $fdepth $gdepth))
                      (: (∧ $f $g) (-> $a Bool)))
                   (empty)))))
       (empty)))
   ;; )

;; Type check disjunction, ∨.  Similar to ∧, see above for more
;; information.
(= (nupln_bc $kb (MkControl $size $depth) (: (∨ $f $g) (-> $a Bool)))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth) (: (∨ $f $g) (-> $a Bool)))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of ∨ plus the proofs of the premises.  The first
   ;; premise is charged the unit of ∨, the second premise inherits
   ;; the remaining budget of the first one, and the conclusion
   ;; returns the remaining budget of the second premise.
   (if (and (<= 3 $size) (<= 2 $depth))
       ;; Recurse on premise 1, check that $f is of type (-> $a Bool)
       (let (, (MkControl $fsize $fdepth) (: $f (-> $a Bool)))
         (nupln_bc $kb (MkControl (- $size 1) (- $depth 1))
                   (: $f (-> $a Bool)))
         ;; Check that $f is not a disjunction so that (∨ $f $g) may
         ;; possibly be in left associative form
         (if (isDisjunction $f)
             (empty)
             ;; Recurse on premise 2, check that $g is of type (-> $a Bool)
             (let (, (MkControl $gsize $gdepth) (: $g (-> $a Bool)))
               (nupln_bc $kb (MkControl $fsize (- $depth 1))
                         (: $g (-> $a Bool)))
               ;; Check that (∨ $f $g) is sorted according to the
               ;; normal order with non contradicting arguments.
               (if (and (isDisjSorted (∨ $f $g)) (isDisjNonContradict (∨ $f $g)))
                   (, (MkControl $gsize (min $fdepth $gdepth))
                      (: (∨ $f $g) (-> $a Bool)))
                   (empty)))))
       (empty)))
   ;; )

;; Type check negation, ¬. Similar to ∧ and ∨, see above for more
;; information.
(= (nupln_bc $kb (MkControl $size $depth) (: (¬ $f) (-> $a Bool)))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth) (: (¬ $f) (-> $a Bool)))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of ¬ plus the proof of the premise.  The premise is
   ;; charged the unit of ¬ and the conclusion returns the remaining
   ;; budget of the premise.
   (if (and (<= 2 $size) (<= 2 $depth))
       ;; Recurse on premise, check that $f is of type (->  $a Bool)
       (let (, (MkControl $fsize $fdepth) (: $f (-> $a Bool)))
         (nupln_bc $kb (MkControl (- $size 1) (- $depth 1))
                   (: $f (-> $a Bool)))
         ;; Check that $f is not an expression because, as in MOSES, ¬
         ;; is expected to be on literals only.
         (if (isExpression $f)
             (empty)
             (, (MkControl $fsize $fdepth) (: (¬ $f) (-> $a Bool)))))))
   ;; )

;; Type check singleton construction, ⊙.  If $x is of type $a, then
;; (⊙ $x) is of type $a -> Bool.
(= (nupln_bc $kb (MkControl $size $depth) (: (⊙ $x) (-> $a Bool)))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth) (: (⊙ $x) (-> $a Bool)))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of ⊙ plus the proof of the premise.  The premise is
   ;; charged the unit of ⊙ and the conclusion returns the remaining
   ;; budget of the premise.
   (if (and (<= 2 $size) (<= 2 $depth))
       (let (, (MkControl $xsize $xdepth) (: $x $a))
         (nupln_bc $kb (MkControl (- $size 1) (- $depth 1)) (: $x $a))
         (, (MkControl $xsize $xdepth) (: (⊙ $x) (-> $a Bool))))
       (empty)))
   ;; )

;; Type check implication, →.  For now it is assumed that implication
;; can only be established between predicates of identical type.  For
;;
;; (→ F G)
;;
;; to be well typed, F and G must be of the same type.  Also the type
;; of an implication is for now labelled as a (CPred (-> $a Bool))
;; which stands for a conditioned predicate.  This may change in the
;; future though.
(= (nupln_bc $kb (MkControl $size $depth) (: (→ $f $g) (CPred (-> $a Bool))))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth) (: (→ $f $g) Statement))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of → plus the proofs of the premises.  The first
   ;; premise is charged the unit of →, the second premise inherits
   ;; the remaining budget of the first one, and the conclusion
   ;; returns the remaining budget of the second premise.
   (if (and (<= 3 $size) (<= 2 $depth))
       (let* (;; Recurse on premise 1 to check that $f is or type $a
              ((, (MkControl $fsize $fdepth) (: $f (-> $a Bool)))
               (nupln_bc $kb (MkControl (- $size 1) (- $depth 1))
                         (: $f (-> $a Bool))))
              ;; Recurse on premise 2 to check that $g is or type $a
              ((, (MkControl $gsize $gdepth) (: $g (-> $a Bool)))
               (nupln_bc $kb (MkControl $fsize (- $depth 1))
                         (: $g (-> $a Bool)))))
         (, (MkControl $gsize (min $fdepth $gdepth))
            (: (→ $f $g) (CPred (-> $a Bool)))))
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
;;
;; Note that (→ (⊙ $x) (∧ $f $g)) is placed as proof argument for full
;; transparancy since it cost size and depth budgets.
(= (nupln_bc $kb (MkControl $size $depth)
             (: (cet (→ (⊙ $x) (∧ $f $g)) $fp $gp)
                (≞ (→ (⊙ $x) (∧ $f $g)) ⊤)))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth)
   ;;            (: (cet (→ (⊙ $x) (∧ $f $g)) $fp $gp)
   ;;               (≞ (→ (⊙ $x) (∧ $f $g)) ⊤)))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of ∧ plus the type check of (→ (⊙ $x) (∧ $f $g))
   ;; and the evaluations of (→ (⊙ $x) $f) and (→ (⊙ $x) $g).  The
   ;; first premise is charged the unit of ∧, each subsequent premise
   ;; inherits the remaining budget of the previous one, and the
   ;; conclusion returns the remaining budget of the last premise.
   (if (and (<= 4 $size) (<= 2 $depth))
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (∧ $f $g))
              ((, (MkControl $asize $adepth) (: (→ (⊙ $x) (∧ $f $g)) $a))
               (nupln_bc $kb (MkControl (- $size 1) (- $depth 1))
                         (: (→ (⊙ $x) (∧ $f $g)) $a)))
              ;; Recurse on premise 2 to make sure that $f evaluates
              ;; to true on $x
              ((, (MkControl $fsize $fdepth) (: $fp (≞ (→ (⊙ $x) $f) ⊤)))
               (nupln_bc $kb (MkControl $asize (- $depth 1))
                         (: $fp (≞ (→ (⊙ $x) $f) ⊤))))
              ;; Recurse on premise 3 to make sure that $g evaluates
              ;; to true on $x
              ((, (MkControl $gsize $gdepth) (: $gp (≞ (→ (⊙ $x) $g) ⊤)))
               (nupln_bc $kb (MkControl $fsize (- $depth 1))
                         (: $gp (≞ (→ (⊙ $x) $g) ⊤)))))
         ;; Build conclusion
         (, (MkControl $gsize (min $adepth (min $fdepth $gdepth)))
            (: (cet (→ (⊙ $x) (∧ $f $g)) $fp $gp)
               (≞ (→ (⊙ $x) (∧ $f $g)) ⊤))))
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
;;
;; Note that (→ (⊙ $x) (∧ $f $g)) is placed as proof argument for full
;; transparancy since it cost size and depth budgets.
(= (nupln_bc $kb (MkControl $size $depth)
             (: (cefl (→ (⊙ $x) (∧ $f $g)) $fp)
                (≞ (→ (⊙ $x) (∧ $f $g)) ⊥)))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth)
   ;;            (: (cefl (→ (⊙ $x) (∧ $f $g)) $fp)
   ;;               (≞ (→ (⊙ $x) (∧ $f $g)) ⊥)))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of ∧ plus the type check of (→ (⊙ $x) (∧ $f $g))
   ;; and the evaluation of (→ (⊙ $x) $f).  The first premise is
   ;; charged the unit of ∧, the second premise inherits the remaining
   ;; budget of the first one, and the conclusion returns the remaining
   ;; budget of the second premise.
   (if (and (<= 3 $size) (<= 2 $depth))
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (∧ $f $g))
              ((, (MkControl $asize $adepth) (: (→ (⊙ $x) (∧ $f $g)) $a))
               (nupln_bc $kb (MkControl (- $size 1) (- $depth 1))
                         (: (→ (⊙ $x) (∧ $f $g)) $a)))
              ;; Recurse on premise 2 to make sure that $f evaluates
              ;; to false on $x
              ((, (MkControl $fsize $fdepth) (: $fp (≞ (→ (⊙ $x) $f) ⊥)))
               (nupln_bc $kb (MkControl $asize (- $depth 1))
                         (: $fp (≞ (→ (⊙ $x) $f) ⊥)))))
         ;; Build conclusion
         (, (MkControl $fsize (min $adepth $fdepth))
            (: (cefl (→ (⊙ $x) (∧ $f $g)) $fp)
               (≞ (→ (⊙ $x) (∧ $f $g)) ⊥))))
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
;;
;; Note that (→ (⊙ $x) (∧ $f $g)) is placed as proof argument for full
;; transparancy since it cost size and depth budgets.
(= (nupln_bc $kb (MkControl $size $depth)
             (: (cefr (→ (⊙ $x) (∧ $f $g)) $gp)
                (≞ (→ (⊙ $x) (∧ $f $g)) ⊥)))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth)
   ;;            (: (cefr (→ (⊙ $x) (∧ $f $g)) $gp)
   ;;               (≞ (→ (⊙ $x) (∧ $f $g)) ⊥)))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of ∧ plus the type check of (→ (⊙ $x) (∧ $f $g))
   ;; and the evaluation of (→ (⊙ $x) $g).  The first premise is
   ;; charged the unit of ∧, the second premise inherits the remaining
   ;; budget of the first one, and the conclusion returns the remaining
   ;; budget of the second premise.
   (if (and (<= 3 $size) (<= 2 $depth))
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (∧ $f $g))
              ((, (MkControl $asize $adepth) (: (→ (⊙ $x) (∧ $f $g)) $a))
               (nupln_bc $kb (MkControl (- $size 1) (- $depth 1))
                         (: (→ (⊙ $x) (∧ $f $g)) $a)))
              ;; Recurse on premise 2 to make sure that $g evaluates
              ;; to false on $x
              ((, (MkControl $gsize $gdepth) (: $gp (≞ (→ (⊙ $x) $g) ⊥)))
               (nupln_bc $kb (MkControl $asize (- $depth 1))
                         (: $gp (≞ (→ (⊙ $x) $g) ⊥)))))
         ;; Build conclusion
         (, (MkControl $gsize (min $adepth $gdepth))
            (: (cefr (→ (⊙ $x) (∧ $f $g)) $gp)
               (≞ (→ (⊙ $x) (∧ $f $g)) ⊥))))
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
;;
;; Note that (→ (⊙ $x) (∨ $f $g)) is placed as proof argument for full
;; transparancy since it cost size and depth budgets.
(= (nupln_bc $kb (MkControl $size $depth)
             (: (detl (→ (⊙ $x) (∨ $f $g)) $fp)
                (≞ (→ (⊙ $x) (∨ $f $g)) ⊤)))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth)
   ;;            (: (detl (→ (⊙ $x) (∨ $f $g)) $fp)
   ;;               (≞ (→ (⊙ $x) (∨ $f $g)) ⊤)))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of ∨ plus the type check of (→ (⊙ $x) (∨ $f $g))
   ;; and the evaluation of (→ (⊙ $x) $f).  The first premise is
   ;; charged the unit of ∨, the second premise inherits the remaining
   ;; budget of the first one, and the conclusion returns the remaining
   ;; budget of the second premise.
   (if (and (<= 3 $size) (<= 2 $depth))
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (∨ $f $g))
              ((, (MkControl $asize $adepth) (: (→ (⊙ $x) (∨ $f $g)) $a))
               (nupln_bc $kb (MkControl (- $size 1) (- $depth 1))
                         (: (→ (⊙ $x) (∨ $f $g)) $a)))
              ;; Recurse on premise 2 to make sure that $f evaluates
              ;; to true on $x.  Note that no premise is required on
              ;; $g, since True suffices for the disjunction.
              ((, (MkControl $fsize $fdepth) (: $fp (≞ (→ (⊙ $x) $f) ⊤)))
               (nupln_bc $kb (MkControl $asize (- $depth 1))
                         (: $fp (≞ (→ (⊙ $x) $f) ⊤)))))
         ;; Build conclusion
         (, (MkControl $fsize (min $adepth $fdepth))
            (: (detl (→ (⊙ $x) (∨ $f $g)) $fp)
               (≞ (→ (⊙ $x) (∨ $f $g)) ⊤))))
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
;;
;; Note that (→ (⊙ $x) (∨ $f $g)) is placed as proof argument for full
;; transparancy since it cost size and depth budgets.
(= (nupln_bc $kb (MkControl $size $depth)
             (: (detr (→ (⊙ $x) (∨ $f $g)) $gp)
                (≞ (→ (⊙ $x) (∨ $f $g)) ⊤)))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth)
   ;;            (: (detr (→ (⊙ $x) (∨ $f $g)) $gp)
   ;;               (≞ (→ (⊙ $x) (∨ $f $g)) ⊤)))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of ∨ plus the type check of (→ (⊙ $x) (∨ $f $g))
   ;; and the evaluation of (→ (⊙ $x) $g).  The first premise is
   ;; charged the unit of ∨, the second premise inherits the remaining
   ;; budget of the first one, and the conclusion returns the remaining
   ;; budget of the second premise.
   (if (and (<= 3 $size) (<= 2 $depth))
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (∨ $f $g))
              ((, (MkControl $asize $adepth) (: (→ (⊙ $x) (∨ $f $g)) $a))
               (nupln_bc $kb (MkControl (- $size 1) (- $depth 1))
                         (: (→ (⊙ $x) (∨ $f $g)) $a)))
              ;; Recurse on premise 2 to make sure that $g evaluates
              ;; to true on $x.  Note that no premise is required on
              ;; $f, since True suffices for the disjunction.
              ((, (MkControl $gsize $gdepth) (: $gp (≞ (→ (⊙ $x) $g) ⊤)))
               (nupln_bc $kb (MkControl $asize (- $depth 1))
                         (: $gp (≞ (→ (⊙ $x) $g) ⊤)))))
         ;; Build conclusion
         (, (MkControl $gsize (min $adepth $gdepth))
            (: (detr (→ (⊙ $x) (∨ $f $g)) $gp)
               (≞ (→ (⊙ $x) (∨ $f $g)) ⊤))))
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
;;
;; Note that (→ (⊙ $x) (∨ $f $g)) is placed as proof argument for full
;; transparancy since it cost size and depth budgets.
(= (nupln_bc $kb (MkControl $size $depth)
             (: (def (→ (⊙ $x) (∨ $f $g)) $fp $gp)
                (≞ (→ (⊙ $x) (∨ $f $g)) ⊥)))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth)
   ;;            (: (def (→ (⊙ $x) (∨ $f $g)) $fp $gp)
   ;;               (≞ (→ (⊙ $x) (∨ $f $g)) ⊥)))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of ∨ plus the type check of (→ (⊙ $x) (∨ $f $g))
   ;; and the evaluations of (→ (⊙ $x) $f) and (→ (⊙ $x) $g).  The
   ;; first premise is charged the unit of ∨, each subsequent premise
   ;; inherits the remaining budget of the previous one, and the
   ;; conclusion returns the remaining budget of the last premise.
   (if (and (<= 4 $size) (<= 2 $depth))
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (∨ $f $g))
              ((, (MkControl $asize $adepth) (: (→ (⊙ $x) (∨ $f $g)) $a))
               (nupln_bc $kb (MkControl (- $size 1) (- $depth 1))
                         (: (→ (⊙ $x) (∨ $f $g)) $a)))
              ;; Recurse on premise 2 to make sure that $f evaluates
              ;; to false on $x
              ((, (MkControl $fsize $fdepth) (: $fp (≞ (→ (⊙ $x) $f) ⊥)))
               (nupln_bc $kb (MkControl $asize (- $depth 1))
                         (: $fp (≞ (→ (⊙ $x) $f) ⊥))))
              ;; Recurse on premise 3 to make sure that $g evaluates
              ;; to false on $x
              ((, (MkControl $gsize $gdepth) (: $gp (≞ (→ (⊙ $x) $g) ⊥)))
               (nupln_bc $kb (MkControl $fsize (- $depth 1))
                         (: $gp (≞ (→ (⊙ $x) $g) ⊥)))))
         ;; Build conclusion
         (, (MkControl $gsize (min $adepth (min $fdepth $gdepth)))
            (: (def (→ (⊙ $x) (∨ $f $g)) $fp $gp)
               (≞ (→ (⊙ $x) (∨ $f $g)) ⊥))))
       (empty)))
   ;; )

;; Negation evaluation to ⊤.  The query
;;
;; (≞ (→ (⊙ $x) (¬ $f)) ⊤)
;;
;; means that ((¬ $f) $x) evaluates to True.  This is the case when
;; ($f $x) evaluates to False.
;;
;; `net` stands for negation evaluates to true.
;;
;; Note that (→ (⊙ $x) (¬ $f)) is placed as proof argument for full
;; transparancy since it cost size and depth budgets.
(= (nupln_bc $kb (MkControl $size $depth)
             (: (net (→ (⊙ $x) (¬ $f)) $fp)
                (≞ (→ (⊙ $x) (¬ $f)) ⊤)))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth)
   ;;            (: (net (→ (⊙ $x) (¬ $f)) $fp)
   ;;               (≞ (→ (⊙ $x) (¬ $f)) ⊤)))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of ¬ plus the type check of (→ (⊙ $x) (¬ $f))
   ;; and the evaluation of (→ (⊙ $x) $f).  The first premise is
   ;; charged the unit of ¬, the second premise inherits the remaining
   ;; budget of the first one, and the conclusion returns the remaining
   ;; budget of the second premise.
   (if (and (<= 3 $size) (<= 2 $depth))
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (¬ $f))
              ((, (MkControl $asize $adepth) (: (→ (⊙ $x) (¬ $f)) $a))
               (nupln_bc $kb (MkControl (- $size 1) (- $depth 1))
                         (: (→ (⊙ $x) (¬ $f)) $a)))
              ;; Recurse on premise 2 to make sure that $f evaluates
              ;; to false on $x
              ((, (MkControl $fsize $fdepth) (: $fp (≞ (→ (⊙ $x) $f) ⊥)))
               (nupln_bc $kb (MkControl $asize (- $depth 1))
                         (: $fp (≞ (→ (⊙ $x) $f) ⊥)))))
         ;; Build conclusion
         (, (MkControl $fsize (min $adepth $fdepth))
            (: (net (→ (⊙ $x) (¬ $f)) $fp)
               (≞ (→ (⊙ $x) (¬ $f)) ⊤))))
       (empty)))
   ;; )

;; Negation evaluation to ⊥.  The query
;;
;; (≞ (→ (⊙ $x) (¬ $f)) ⊥)
;;
;; means that ((¬ $f) $x) evaluates to False.  This is the case when
;; ($f $x) evaluates to True.
;;
;; `nef` stands for negation evaluates to false.
;;
;; Note that (→ (⊙ $x) (¬ $f)) is placed as proof argument for full
;; transparancy since it cost size and depth budgets.
(= (nupln_bc $kb (MkControl $size $depth)
             (: (nef (→ (⊙ $x) (¬ $f)) $fp)
                (≞ (→ (⊙ $x) (¬ $f)) ⊥)))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth)
   ;;            (: (nef (→ (⊙ $x) (¬ $f)) $fp)
   ;;               (≞ (→ (⊙ $x) (¬ $f)) ⊥)))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of ¬ plus the type check of (→ (⊙ $x) (¬ $f))
   ;; and the evaluation of (→ (⊙ $x) $f).  The first premise is
   ;; charged the unit of ¬, the second premise inherits the remaining
   ;; budget of the first one, and the conclusion returns the remaining
   ;; budget of the second premise.
   (if (and (<= 3 $size) (<= 2 $depth))
       (let* (;; Recurse on premise 1 to check the correctness of the
              ;; type of (→ (⊙ $x) (¬ $f))
              ((, (MkControl $asize $adepth) (: (→ (⊙ $x) (¬ $f)) $a))
               (nupln_bc $kb (MkControl (- $size 1) (- $depth 1))
                         (: (→ (⊙ $x) (¬ $f)) $a)))
              ;; Recurse on premise 2 to make sure that $f evaluates
              ;; to true on $x
              ((, (MkControl $fsize $fdepth) (: $fp (≞ (→ (⊙ $x) $f) ⊤)))
               (nupln_bc $kb (MkControl $asize (- $depth 1))
                         (: $fp (≞ (→ (⊙ $x) $f) ⊤)))))
         ;; Build conclusion
         (, (MkControl $fsize (min $adepth $fdepth))
            (: (nef (→ (⊙ $x) (¬ $f)) $fp)
               (≞ (→ (⊙ $x) (¬ $f)) ⊥))))
       (empty)))
   ;; )

;; Product.  The query
;;
;; (: (, $x $y) (, $a $b))
;;
;; means that both $a $b must be proven for (, $a $b) to be proven.
;;
;; Note that the product does not consume any depth.  This is done so
;; in order to view it as flattened and to avoid deeper queries buried
;; in the left associativity to require a higher depth, thus keep
;; elements among the product with a balanced depth budget.  The same
;; cannot be done with the size budget otherwise, an unconstrained
;; theorem would be allow grow a product of products arbitrarily
;; large.
(= (nupln_bc $kb (MkControl $size $depth) (: (, $x $y) (, $a $b)))
   ;; (trace! (👁 nupln_bc $kb (MkControl $size $depth) (: (, $x $y) (, $a $b)))
   ;; The size budget must cover the whole proof: 1 for the
   ;; introduction of `,` plus the proofs of the premises.  The first
   ;; premise is charged the unit of `,`, the second premise inherits
   ;; the remaining budget of the first one, and the conclusion
   ;; returns the remaining budget of the second premise.  Note that
   ;; the depth budget is not consumed by the product, and that the
   ;; returned depth is the minimum of the depths returned by the
   ;; premises.
   (if (and (<= 3 $size) (<= 1 $depth))
       (let* (;; Count the number of components
              ($n_cpn (countArgsRA , (, $a $b)))
              ;; Get number of commas
              ($n_com (- $n_cpn 1))
              ;; Get total budget for all components
              ($tcb (- $size $n_com))
              ;; Calculate the size budget to allocate to the first
              ;; component assuming fair distribution across components
              ($fsts (+ (#div $tcb $n_cpn) (#mod $tcb $n_cpn)))
              ;; Recurse on premise 1 to prove $a
              ((, (MkControl $xsize $xdepth) (: $x $a))
               (nupln_bc $kb (MkControl $fsts $depth) (: $x $a)))
              ;; Calculate the size budget to allocate to the
              ;; remaining components
              ($rems (- $size (+ 1 (- $fsts $xsize))))
              ;; Recurse on premise 2 to prove $b
              ((, (MkControl $ysize $ydepth) (: $y $b))
               (nupln_bc $kb (MkControl $rems $depth) (: $y $b))))
         ;; Build product
         (, (MkControl $ysize (min $xdepth $ydepth))
            (: (, $x $y) (, $a $b))))
       (empty)))
   ;; )
