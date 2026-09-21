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

!(Bernoulli &rng 0.9)

;;;;;;;;;;;;;;;;;
;; Combinators ;;
;;;;;;;;;;;;;;;;;

;; Functions, and predicates in particular, are built using
;; combinators to avoid introducing variables beside MeTTa built-in
;; variables.
;;
;; * pad: a -> b -> a, to preprend an argument to a function.
;;
;; * drop: (a -> b) -> b, to drop the first argument of a function.
;;   The new function obtained should be such that the probability of
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
