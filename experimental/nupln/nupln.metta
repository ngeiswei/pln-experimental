;; PoC of nuPLN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Loading the Prolog helper                                          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; `import!` consults the file via PeTTa's import machinery. We pull
;; in `lib_import` to get the helper that consults a .pl file and
;; registers each predicate as a MeTTa function. `library/1`
;; resolves the path through PeTTa's SWI-Prolog library search.
!(import! &self (library lib_import.metta))

;; Consult the helper file from the directory of this MeTTa file
;; (PeTTa's main sets `working_dir` to that directory) and register
;; its public predicates as MeTTa functions. The last argument of
;; `nupln_uniform/2` is the output, so it fits PeTTa's "function
;; form" convention. `nupln_set_seed/1` is a side-effecting command
;; (it perturbs the global random state) but we still register it
;; here because we want the convenience of calling it from MeTTa.
!(import_prolog_functions_from_file "./nupln_random.pl"
                                    (nupln_uniform nupln_set_seed))

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
;; type is assumed to be a -> Bool but this will probably need to be
;; generalized to a -> b, depending on how predicate arity is handled.
;; Failing to specialize this type check by enforcing a function or a
;; predicate results in producing weird things like
;;
;; (: (∧ g0t g0t) (≞ (→ (⊙ 0) G) ⊤))
;;
;; thus why we need to be more specific.
(= (nupln_bc $kb $budget (: (∧ $f $g) (-> $a Bool)))
   ;; (trace! (👁 nupln_bc $kb $budget (: (∧ $f $g) (-> $a Bool)))
   ;; The budget must be at least 3: 1 for the type checking of $f, 1
   ;; for the type checking of $g, and 1 for the introduction of ∧.
   (if (<= 3 $budget)
       (let* (;; Recurse on premise 1 to check that $f is or type $a
              ((MkSized $fs (: $f (-> $a Bool)))
               (nupln_bc $kb (- $budget 2) (: $f (-> $a Bool))))
              ;; Recurse on premise 2 to check that $g is or type $a
              ((MkSized $gs (: $g (-> $a Bool)))
               (nupln_bc $kb (- $budget (+ $fs 1)) (: $g (-> $a Bool)))))
         (MkSized (+ 1 (+ $fs $gs)) (: (∧ $f $g) (-> $a Bool))))
       (empty)))
   ;; )

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

;; Define F and G over values 0, 1 and 2
!(bind! &kb (new-space))
!(add-atom &kb (: 0 UInt))
!(add-atom &kb (: 1 UInt))
!(add-atom &kb (: 2 UInt))
!(add-atom &kb (: F (-> UInt Bool)))
!(add-atom &kb (: G (-> UInt Bool)))
!(add-atom &kb (: f0t (≞ (→ (⊙ 0) F) ⊤)))   ; (F 0) = True
!(add-atom &kb (: f1f (≞ (→ (⊙ 1) F) ⊥)))   ; (F 1) = False
!(add-atom &kb (: f2t (≞ (→ (⊙ 2) F) ⊤)))   ; (F 1) = True
!(add-atom &kb (: g0t (≞ (→ (⊙ 0) G) ⊤)))   ; (F 0) = True
!(add-atom &kb (: g1t (≞ (→ (⊙ 1) G) ⊤)))   ; (F 1) = True
!(add-atom &kb (: g2f (≞ (→ (⊙ 2) G) ⊥)))   ; (F 1) = False

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

;; Infer what predicates could evaluate to the truth table
;; corresponding to (∧ F G)
!(test
  (once (nupln_bc &kb 27 (: $prf (, (≞ (→ (⊙ 0) $pred) ⊤)
                                 (, (≞ (→ (⊙ 1) $pred) ⊥)
                                    (≞ (→ (⊙ 2) $pred) ⊥))))))
  (MkSized 27 (: (, (cet f0t g0t) (, (cefl f1f) (cefr g2f)))
                 (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
                 (, (≞ (→ (⊙ 1) (∧ F G)) ⊥)
                    (≞ (→ (⊙ 2) (∧ F G)) ⊥))))))

;; NEXT: introduce reduction rules to avoid (∧ F F) and the like.
