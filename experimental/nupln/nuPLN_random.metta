;; nuPLN_random.metta
;;
;; PoC of nuPLN's random-sampling layer on top of MeTTa (PeTTa
;; backend).
;;
;; This file exposes two referentially transparent random samplers
;; whose output is fully determined by their MeTTa arguments AND
;; the current global random seed:
;;
;;   (uniform       $term)        -> a Float in [0.0, 1.0)
;;   (bernoulli     $term $p)     -> True with prob $p, else False
;;   (set-random-seed! $n)        -> re-seed the global generator
;;
;; Implementation strategy:
;;   1. Hash the MeTTa term with SWI-Prolog's term_hash/2.
;;   2. Capture the global random state.
;;   3. Mix the term hash with the captured state to produce a
;;      temporary seed.
;;   4. Seed a fresh generator with that, draw a uniform sample,
;;      threshold it for Bernoulli.
;;   5. Restore the previous global random state so the call has no
;;      observable side effect on the rest of the program.
;;
;; All of the hashing, state management, and uniform sampling is
;; done in `nupln_random.pl`. The Bernoulli sampler and the
;; aggregation helpers in this file are *pure MeTTa* -- they
;; compose ordinary MeTTa primitives (`if`, `<`, `filter-atom`,
;; `size-atom`, `/`) with the uniform sampler.

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public API                                                         ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; uniform $term
;;   A deterministic uniform [0, 1) sample derived from
;;   term_hash($term) *combined with the current global random
;;   seed*. Calling it twice with the same argument *and the same
;;   global seed* always yields the same float; changing the global
;;   seed (via `set-random-seed!` below) gives a different sample.
(= (uniform $term) (nupln_uniform $term))

;; set-random-seed! $n
;;   Re-seed SWI's global random generator with the integer $n.
;;   This is the user-visible knob: it changes the global state
;;   that nupln_uniform mixes with each term hash to derive its
;;   temporary seed. Useful for reproducibility.
(= (set-random-seed! $n) (nupln_set_seed $n))

;; bernoulli $term $p
;;   Pure MeTTa Bernoulli sampler. The uniform draw is delegated
;;   to `uniform`, then we threshold it against $p. Returns True
;;   with probability $p and False otherwise. Like `uniform`, its
;;   output depends on both $term and the global seed.
(= (bernoulli $term $p)
   (if (< (uniform $term) $p) True False))

;; bernoulli? $term $p
;;   Predicate-style form of bernoulli/2: succeeds iff the bernoulli
;;   sample is True. Handy inside `if` / `match` where the caller
;;   wants to branch on the outcome without pattern-matching on the
;;   literal atom `True`.
(= (bernoulli? $term $p) (if (== (bernoulli $term $p) True) True False))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Convenience: aggregating samples over a list of events             ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; bernoulli-count $terms $p
;;   Counts how many elements of the list `$terms` yield True under
;;   (bernoulli _ $p). Demonstrates that the samplers compose with
;;   ordinary MeTTa list combinators.
(= (bernoulli-count $terms $p)
   (size-atom (filter-atom $terms $t (bernoulli? $t $p))))

;; bernoulli-frequency $terms $p
;;   Empirical success frequency (True count / total count) for the
;;   bernoulli($_, $p) distribution applied to a list of seeds.
(= (bernoulli-frequency $terms $p)
   (let $n (size-atom $terms)
        (if (== $n 0)
            0
            (/ (bernoulli-count $terms $p) $n))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Self-tests                                                         ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

!(nupln_set_seed 42)

!(uniform 5)

;; ;; --- Determinism: same term + same global seed -> same sample ---
;; ;; We fix the global seed so the test is reproducible regardless of
;; ;; how SWI initialised its random state at startup.
;; !(set-random-seed! 42)
;; !(test (uniform (foo bar baz))
;;        (uniform (foo bar baz)))
;; !(set-random-seed! 42)
;; !(test (bernoulli (foo bar baz) 0.5)
;;        (bernoulli (foo bar baz) 0.5))

;; ;; --- The user can influence outcomes via the global seed ---
;; ;; The same term sampled under two different global seeds gives
;; ;; (almost certainly) two different uniform values. We just print
;; ;; them and trust the user to verify they differ.
;; !(let* (($_ (set-random-seed! 1))
;;         ($u1 (uniform (foo bar baz))))
;;        (println! ($u1 is uniform under seed 1)))
;; !(let* (($_ (set-random-seed! 2))
;;         ($u2 (uniform (foo bar baz))))
;;        (println! ($u2 is uniform under seed 2)))

;; ;; --- Boundary probabilities (do not depend on the seed) ---
;; ;; P = 1.0 means the sample is always True regardless of the term
;; ;; or the global seed.
;; !(test (bernoulli (any term) 1.0) true)
;; ;; P = 0.0 means the sample is always False regardless of the term
;; ;; or the global seed.
;; !(test (bernoulli (any term) 0.0) false)

;; ;; --- Frequency sanity check over a small synthetic event list ---
;; ;; Reset the seed so this test is reproducible across runs, then
;; ;; sample bernoulli(_, 0.7) on the integers 1..20. The empirical
;; ;; success rate should land roughly around 0.7 (we just print it
;; ;; since randomness doesn't allow exact equality).
;; !(set-random-seed! 7)
;; !(let* (($events (1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20))
;;         ($freq   (bernoulli-frequency $events 0.7)))
;;        (println! (Empirical frequency for p=0.7 over 20 events is $freq)))
