;; Unit tests for nupln.metta
;;
;; Run with:
;;   ~/Work/TrueAGI/PeTTa/run.sh test_nupln.metta
;;
;; This file imports the code from nupln.metta (which transitively loads
;; lib_import.metta, lib_memo, and lib_nupln.pl) and then exercises
;; nupln_bc with a small knowledge base.

;; Load the code under test
!(import! &self ./nupln.metta)

;; Import memoization library
!(import! &self (library lib_memo))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;;;;;;;;;;;;;;;;;;;;;; ;;
;; ;; Helper Unit Tests ;; ;;
;; ;;;;;;;;;;;;;;;;;;;;;;; ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Test countArgsRA
!(test
  (countArgsRA , a)
  1)
!(test
  (countArgsRA , (∧ a b))
  1)
!(test
  (countArgsRA , (, a b))
  2)
!(test
  (countArgsRA , (, a (, b c)))
  3)

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
!(test
  (n< (∧ F1 (∧ (¬ F2) F3)) (∧ (¬ F3) (∨ (¬ F1) F2)))
  True)

;; Test isShallowNormal
!(test
  (isShallowNormal 𝕋)
  True)
!(test
  (isShallowNormal 𝔽)
  True)
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
!(test
  (isShallowNormal (∨ F G))
  True)
!(test
  (isShallowNormal (∨ F F))
  False)
!(test
  (isShallowNormal (∨ F (∨ G H)))
  True)
!(test
  (isShallowNormal (∨ H (∨ G F)))
  False)
!(test
  (isShallowNormal (∨ F (∨ H F)))
  True)
!(test
  (isShallowNormal (∨ F (¬ F)))
  False)
!(test
  (isShallowNormal (∨ F (∨ (¬ F) G)))
  False)

;; Test isNormal
!(test
  (isNormal 𝕋)
  True)
!(test
  (isNormal 𝔽)
  True)
!(test
  (isNormal F)
  True)
!(test
  (isNormal (¬ 𝕋))
  False)
!(test
  (isNormal (¬ 𝔽))
  False)
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
!(test
  (isNormal (∨ F G))
  True)
!(test
  (isNormal (∨ F F))
  False)
!(test
  (isNormal (∨ F (∨ G H)))
  True)
!(test
  (isNormal (∨ H (∨ G F)))
  False)
!(test
  (isNormal (∨ F (∨ H F)))
  False)
!(test
  (isNormal (∨ F (¬ F)))
  False)
!(test
  (isNormal (∨ F (∨ (¬ F) G)))
  False)
!(test
  (isNormal (∧ (∨ F1 (¬ F2)) (∨ (¬ F1) F2)))
  True)
!(test
  (isNormal (∧ (¬ F1) F2))
  True)
!(test
  (isNormal (∧ F1 (∧ (¬ F2) F3)))
  True)
!(test
  (isNormal (∨ (∧ F1 (∧ (¬ F2) F3))
               (∧ (¬ F1) F2)))
  True)
!(test
  (isNormal (∧ (¬ F3) (∨ (¬ F1) F2)))
  True)
!(test
  (isNormal (∨ (∧ F1 (∧ (¬ F2) F3))
               (∨ (∧ (¬ F1) F2)
                  (∧ (¬ F3) (∨ (¬ F1) F2)))))
  True)
!(test
  (isNormal (∨ F1 (∨ (¬ F2) F3)))
  True)
!(test
  (isNormal (∧ (∨ F1 (∨ (¬ F2) F3))
               (∨ (∧ F1 (∧ (¬ F2) F3))
                  (∨ (∧ (¬ F1) F2)
                     (∧ (¬ F3) (∨ (¬ F1) F2))))))
  True)
!(test
  (isNormal (∧ F (∨ F G)))
  False)
!(test
  (isNormal (∧ (¬ F) (∨ (¬ F) G)))
  False)
!(test
  (isNormal (∨ F (∧ F G)))
  False)
!(test
  (isNormal (∧ F (∧ (∨ F H) G)))
  False)
;; Reduction: a literal whose complement is an operand of a sibling
;; dual clause is not in normal form, since the complement can be
;; removed (e.g. (∧ (¬ F) (∨ F G)) ≡ (∧ (¬ F) G)).
!(test
  (isNormal (∧ (¬ F) (∨ F G)))
  False)
!(test
  (isNormal (∧ F (∨ (¬ F) G)))
  False)
!(test
  (isNormal (∨ (¬ F) (∧ F G)))
  False)
!(test
  (isNormal (∨ F (∧ (¬ F) G)))
  False)
!(test
  (isNormal (∧ (¬ F) G))
  True)
;; Deep (non adjacent) absorption and reduction inside a three
;; operand chain.
!(test
  (isNormal (∧ H (∨ F (∨ G H))))
  False)
!(test
  (isNormal (∧ (¬ H) (∨ F (∨ G H))))
  False)
!(test
  (isNormal (∧ (¬ H) (∨ F G)))
  True)

;; Test toNormal
!(test
  (toNormal (¬ 𝕋))
  𝔽)
!(test
  (toNormal (¬ 𝔽))
  𝕋)
!(test
  (toNormal (∧ F F))
  F)
!(test
  (toNormal (∨ F F))
  F)
!(test
  (toNormal (¬ (¬ F)))
  F)
!(test
  (toNormal (∧ F (∨ F G)))
  F)
!(test
  (toNormal (∧ (¬ F) (∨ (¬ F) G)))
  (¬ F))
!(test
  (toNormal (∨ F (∧ F G)))
  F)
!(test
  (toNormal (∧ F (∧ (∨ F H) G)))
  (∧ F G))
!(test
  (toNormal (∧ (∨ (∧ (∨ (¬ F1) F2) (¬ F3))
                  (∨ (∧ (¬ F1) F2)
                     (∧ F1 (∧ (¬ F2) F3))))
               (∨ F1 (∨ (¬ F2) F3))))
  (∧ (∨ F1 (∨ (¬ F2) F3))
     (∨ (∧ F1 (∧ (¬ F2) F3))
        (∨ (∧ (¬ F1) F2)
           (∧ (¬ F3) (∨ (¬ F1) F2))))))
;; Reduction in toNormal: complement literals are removed from the
;; sibling dual clause.
!(test
  (toNormal (∧ (¬ F) (∨ F G)))
  (∧ (¬ F) G))
!(test
  (toNormal (∧ F (∨ (¬ F) G)))
  (∧ F G))
!(test
  (toNormal (∨ (¬ F) (∧ F G)))
  (∨ (¬ F) G))
!(test
  (toNormal (∨ F (∧ (¬ F) G)))
  (∨ F G))
!(test
  (toNormal (∧ (¬ F) (∨ F (∨ G H))))
  (∧ (¬ F) (∨ G H)))
;; Cascading reductions through clause collapse: (∨ F G) collapses
;; to G, which then removes (¬ G) from its sibling.
!(test
  (toNormal (∧ (¬ F) (∧ (∨ F G) (∨ (¬ G) H))))
  (∧ (¬ F) (∧ G H)))
;; Re-sorting after a clause collapses into a literal: H drops below
;; G after (∨ (¬ F) G) becomes G, so (∧ F (∧ H ...)) rebuilds to
;; (∧ F (∧ G H)).
!(test
  (toNormal (∧ F (∧ H (∨ (¬ F) G))))
  (∧ F (∧ G H)))
;; Deep absorption: H absorbs (∨ F (∨ G H)).
!(test
  (toNormal (∧ H (∨ F (∨ G H))))
  H)
!(test
  (toNormal (∧ F (∧ G (∨ (¬ F) (¬ G)))))
  𝔽)
!(test
  (toNormal (∨ (¬ F) (∨ (¬ G) (∧ F G))))
  𝕋)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;
;; ;; Test nuPLN backward chainer ;; ;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; After introducing depth in the control structure, memoization no
;; longer helps, thus is disabled for now.
;;
;; ;; Enable memoization for nupln_bc
;; !(memoize nupln_bc)
;; ;; Settings suggested by Minimax-m3
;; !(config-memoize (unique-limit 10000) (strategy wtinylfu) (size-limit 5))

;; Define F and G over values 0, 1, 2 and 3
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
  (nupln_bc &kb (MkControl 1 1) (: F $a))
  (, (MkControl 0 0) (: F (-> UInt Bool))))

;; Type check G
!(test
  (nupln_bc &kb (MkControl 1 1) (: G $a))
  (, (MkControl 0 0) (: G (-> UInt Bool))))

;; Type check (∧ F G)
!(test
  (nupln_bc &kb (MkControl 3 2) (: (∧ F G) $a))
  (, (MkControl 0 0) (: (∧ F G) (-> UInt Bool))))

;; Type check (∨ F G)
!(test
  (nupln_bc &kb (MkControl 3 2) (: (∨ F G) $a))
  (, (MkControl 0 0) (: (∨ F G) (-> UInt Bool))))

;; Type check (⊙ 0)
!(test
  (nupln_bc &kb (MkControl 2 2) (: (⊙ 0) $a))
  (, (MkControl 0 0) (: (⊙ 0) (-> UInt Bool))))

;; Type check (→ (⊙ 0) (∧ F G))
!(test
  (nupln_bc &kb (MkControl 6 3) (: (→ (⊙ 0) (∧ F G)) $a))
  (, (MkControl 0 0) (: (→ (⊙ 0) (∧ F G)) (CPred (-> UInt Bool)))))

;; Evaluate (∧ F G) over 0
!(test
  (nupln_bc &kb (MkControl 9 4) (: $prf (≞ (→ (⊙ 0) (∧ F G)) $tv)))
  (, (MkControl 0 0) (: (cet (→ (⊙ 0) (∧ F G)) f0t g0t) (≞ (→ (⊙ 0) (∧ F G)) ⊤))))

;; Evaluate (∧ F G) over 1
!(test
  (nupln_bc &kb (MkControl 8 4) (: $prf (≞ (→ (⊙ 1) (∧ F G)) $tv)))
  (, (MkControl 0 0) (: (cefl (→ (⊙ 1) (∧ F G)) f1f) (≞ (→ (⊙ 1) (∧ F G)) ⊥))))

;; Evaluate (∨ F G) over 1, true from right since (F 1) is False but (G 1) is True
!(test
  (nupln_bc &kb (MkControl 8 4) (: $prf (≞ (→ (⊙ 1) (∨ F G)) $tv)))
  (, (MkControl 0 0) (: (detr (→ (⊙ 1) (∨ F G)) g1t) (≞ (→ (⊙ 1) (∨ F G)) ⊤))))

;; Evaluate (∨ F G) over 2, true from left since (F 2) is True and (G 2) is False
!(test
  (nupln_bc &kb (MkControl 8 4) (: $prf (≞ (→ (⊙ 2) (∨ F G)) $tv)))
  (, (MkControl 0 0) (: (detl (→ (⊙ 2) (∨ F G)) f2t) (≞ (→ (⊙ 2) (∨ F G)) ⊤))))

;; Evaluate (∨ F G) over 3, false since both (F 3) and (G 3) are False
!(test
  (nupln_bc &kb (MkControl 9 4) (: $prf (≞ (→ (⊙ 3) (∨ F G)) $tv)))
  (, (MkControl 0 0) (: (def (→ (⊙ 3) (∨ F G)) f3f g3f) (≞ (→ (⊙ 3) (∨ F G)) ⊥))))

;; Find proof of the evaluation of F over 3 values.  Note that depth
;; of 1 works because product cost nothing in terms of depth budget.
!(test
  (nupln_bc &kb (MkControl 5 1)
            (: $prf (, (≞ (→ (⊙ 0) F) ⊤)
                    (, (≞ (→ (⊙ 1) F) ⊥)
                       (≞ (→ (⊙ 2) F) ⊤)))))
  (, (MkControl 0 0)
     (: (, f0t (, f1f f2t))
        (, (≞ (→ (⊙ 0) F) ⊤)
        (, (≞ (→ (⊙ 1) F) ⊥)
           (≞ (→ (⊙ 2) F) ⊤))))))

;; Find proof of (∧ F G) evaluation over 2 values
!(test
  (nupln_bc &kb (MkControl 18 4)
            (: $prf (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
                       (≞ (→ (⊙ 1) (∧ F G)) ⊥))))
  (, (MkControl 0 0)
     (: (, (cet (→ (⊙ 0) (∧ F G)) f0t g0t)
           (cefl (→ (⊙ 1) (∧ F G)) f1f))
        (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
           (≞ (→ (⊙ 1) (∧ F G)) ⊥)))))

;; Find proof of (∧ F G) evaluation over 3 values
!(test
  (nupln_bc &kb (MkControl 27 4)
            (: $prf (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
                    (, (≞ (→ (⊙ 1) (∧ F G)) ⊥)
                       (≞ (→ (⊙ 2) (∧ F G)) ⊥)))))
  (, (MkControl 0 0)
     (: (, (cet (→ (⊙ 0) (∧ F G)) f0t g0t)
        (, (cefl (→ (⊙ 1) (∧ F G)) f1f)
           (cefr (→ (⊙ 2) (∧ F G)) g2f)))
        (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
        (, (≞ (→ (⊙ 1) (∧ F G)) ⊥)
           (≞ (→ (⊙ 2) (∧ F G)) ⊥))))))

;; Find proof of (∨ F G) evaluation over 3 values.  On 1 (G true, F
;; false) the disjunction is True from the right; on 2 (F true, G
;; false) it is True from the left; on 3 (both false) it is False.
;; Values are chosen so that exactly one of detl, detr or def applies
;; at each input, giving a unique proof.
!(test
  (nupln_bc &kb (MkControl 27 4)
            (: $prf (, (≞ (→ (⊙ 1) (∨ F G)) ⊤)
                    (, (≞ (→ (⊙ 2) (∨ F G)) ⊤)
                       (≞ (→ (⊙ 3) (∨ F G)) ⊥)))))
  (, (MkControl 0 0)
     (: (, (detr (→ (⊙ 1) (∨ F G)) g1t)
        (, (detl (→ (⊙ 2) (∨ F G)) f2t)
           (def (→ (⊙ 3) (∨ F G)) f3f g3f)))
        (, (≞ (→ (⊙ 1) (∨ F G)) ⊤)
        (, (≞ (→ (⊙ 2) (∨ F G)) ⊤)
           (≞ (→ (⊙ 3) (∨ F G)) ⊥))))))

;; Infer what predicates could evaluate to the partial truth table
;; corresponding to F.
!(test
  (sort-atom
   (collapse (nupln_bc &kb (MkControl 18 4)
                       (: $prf (, (≞ (→ (⊙ 0) $pred) ⊤)
                                  (≞ (→ (⊙ 1) $pred) ⊥))))))
  (sort-atom
   ((, (MkControl 0 0)
       (: (, (cet (→ (⊙ 0) (∧ F G)) f0t g0t)
             (cefl (→ (⊙ 1) (∧ F G)) f1f))
          (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
             (≞ (→ (⊙ 1) (∧ F G)) ⊥))))
    (, (MkControl 15 3)
       (: (, f0t f1f)
          (, (≞ (→ (⊙ 0) F) ⊤)
             (≞ (→ (⊙ 1) F) ⊥)))))))

;; Infer what predicates could evaluate to the partial truth table
;; corresponding to (¬ F).  The proof for (¬ F 0) = ⊥ uses (nef f0t)
;; because (F 0) = ⊤; the proof for (¬ F 1) = ⊤ uses (net f1f) because
;; (F 1) = ⊥.  Budget: 1 for outer `,` + 7 for (nef f0t) + 7 for (net
;; f1f) = 15.
!(test
  (nupln_bc &kb (MkControl 15 4)
            (: $prf (, (≞ (→ (⊙ 0) $pred) ⊥)
                       (≞ (→ (⊙ 1) $pred) ⊤))))
  (, (MkControl 0 0)
     (: (, (nef (→ (⊙ 0) (¬ F)) f0t)
           (net (→ (⊙ 1) (¬ F)) f1f))
        (, (≞ (→ (⊙ 0) (¬ F)) ⊥)
           (≞ (→ (⊙ 1) (¬ F)) ⊤)))))

;; Infer what predicates could evaluate to the partial truth table
;; corresponding to (∧ F G)
!(test
  (nupln_bc &kb (MkControl 8 4) (: $prf (≞ (→ (⊙ 2) (∧ F G)) ⊥)))
  (, (MkControl 0 0)
     (: (cefr (→ (⊙ 2) (∧ F G)) g2f) (≞ (→ (⊙ 2) (∧ F G)) ⊥))))

;; Infer what predicates could evaluate to the partial truth table
;; corresponding to (∧ F G)
!(test
  (nupln_bc &kb (MkControl 18 4)
            (: $prf (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
                       (≞ (→ (⊙ 2) (∧ F G)) ⊥))))
  (, (MkControl 0 0)
     (: (, (cet (→ (⊙ 0) (∧ F G)) f0t g0t)
           (cefr (→ (⊙ 2) (∧ F G)) g2f))
        (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
           (≞ (→ (⊙ 2) (∧ F G)) ⊥)))))

;; Infer what predicates could evaluate to the partial truth table
;; corresponding to (∧ F G)
!(test
  (nupln_bc &kb (MkControl 27 4)
            (: $prf (, (≞ (→ (⊙ 0) $pred) ⊤)
                    (, (≞ (→ (⊙ 1) $pred) ⊥)
                       (≞ (→ (⊙ 2) $pred) ⊥)))))
  (, (MkControl 0 0)
     (: (, (cet (→ (⊙ 0) (∧ F G)) f0t g0t)
        (, (cefl (→ (⊙ 1) (∧ F G)) f1f)
           (cefr (→ (⊙ 2) (∧ F G)) g2f)))
        (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
        (, (≞ (→ (⊙ 1) (∧ F G)) ⊥)
           (≞ (→ (⊙ 2) (∧ F G)) ⊥))))))

;; Infer what predicates could evaluate to the full truth table
;; corresponding to (∧ F G).
!(test
  (sort-atom
   (collapse
    (nupln_bc &kb (MkControl 36 4) (: $prf (, (≞ (→ (⊙ 0) $pred) ⊤)
                                           (, (≞ (→ (⊙ 1) $pred) ⊥)
                                           (, (≞ (→ (⊙ 2) $pred) ⊥)
                                              (≞ (→ (⊙ 3) $pred) ⊥))))))))
  (sort-atom
   ((, (MkControl 0 0)
       (: (, (cet (→ (⊙ 0) (∧ F G)) f0t g0t)
          (, (cefl (→ (⊙ 1) (∧ F G)) f1f)
          (, (cefr (→ (⊙ 2) (∧ F G)) g2f)
             (cefl (→ (⊙ 3) (∧ F G)) f3f))))
          (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
          (, (≞ (→ (⊙ 1) (∧ F G)) ⊥)
          (, (≞ (→ (⊙ 2) (∧ F G)) ⊥)
             (≞ (→ (⊙ 3) (∧ F G)) ⊥))))))
    (, (MkControl 0 0)
       (: (, (cet (→ (⊙ 0) (∧ F G)) f0t g0t)
          (, (cefl (→ (⊙ 1) (∧ F G)) f1f)
          (, (cefr (→ (⊙ 2) (∧ F G)) g2f)
             (cefr (→ (⊙ 3) (∧ F G)) g3f))))
          (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
          (, (≞ (→ (⊙ 1) (∧ F G)) ⊥)
          (, (≞ (→ (⊙ 2) (∧ F G)) ⊥)
             (≞ (→ (⊙ 3) (∧ F G)) ⊥)))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Test composite predicate synthesis ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Define KB to test whether synthesized composite predicates are in
;; normal form.
!(bind! &kbn (new-space))
!(add-atom &kbn (: F (-> UInt Bool)))
!(add-atom &kbn (: G (-> UInt Bool)))
!(add-atom &kbn (: H (-> UInt Bool)))

;; Enumerate composite predicates in normal form up to depth 3.
!(test
  (sort-atom
   (collapse (nupln_bc &kbn (MkControl 6 3) (: $cnd (-> UInt Bool)))))
  (sort-atom
   ((, (MkControl 5 2) (: F (-> UInt Bool)))
    (, (MkControl 5 2) (: G (-> UInt Bool)))
    (, (MkControl 5 2) (: H (-> UInt Bool)))
    (, (MkControl 3 1) (: (∧ F G) (-> UInt Bool)))
    (, (MkControl 3 1) (: (∧ F H) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∧ F (∧ G H)) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∧ F (∨ G H)) (-> UInt Bool)))
    (, (MkControl 2 0) (: (∧ F (¬ G)) (-> UInt Bool)))
    (, (MkControl 2 0) (: (∧ F (¬ H)) (-> UInt Bool)))
    (, (MkControl 3 1) (: (∧ G H) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∧ G (∨ F H)) (-> UInt Bool)))
    (, (MkControl 2 0) (: (∧ G (¬ H)) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∧ H (∨ F G)) (-> UInt Bool)))
    (, (MkControl 2 0) (: (∧ (¬ F) G) (-> UInt Bool)))
    (, (MkControl 2 0) (: (∧ (¬ F) H) (-> UInt Bool)))
    (, (MkControl 0 0) (: (∧ (¬ F) (∧ G H)) (-> UInt Bool)))
    (, (MkControl 0 0) (: (∧ (¬ F) (∨ G H)) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∧ (¬ F) (¬ G)) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∧ (¬ F) (¬ H)) (-> UInt Bool)))
    (, (MkControl 2 0) (: (∧ (¬ G) H) (-> UInt Bool)))
    (, (MkControl 0 0) (: (∧ (¬ G) (∨ F H)) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∧ (¬ G) (¬ H)) (-> UInt Bool)))
    (, (MkControl 0 0) (: (∧ (¬ H) (∨ F G)) (-> UInt Bool)))
    (, (MkControl 3 1) (: (∨ F G) (-> UInt Bool)))
    (, (MkControl 3 1) (: (∨ F H) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∨ F (∧ G H)) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∨ F (∨ G H)) (-> UInt Bool)))
    (, (MkControl 2 0) (: (∨ F (¬ G)) (-> UInt Bool)))
    (, (MkControl 2 0) (: (∨ F (¬ H)) (-> UInt Bool)))
    (, (MkControl 3 1) (: (∨ G H) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∨ G (∧ F H)) (-> UInt Bool)))
    (, (MkControl 2 0) (: (∨ G (¬ H)) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∨ H (∧ F G)) (-> UInt Bool)))
    (, (MkControl 2 0) (: (∨ (¬ F) G) (-> UInt Bool)))
    (, (MkControl 2 0) (: (∨ (¬ F) H) (-> UInt Bool)))
    (, (MkControl 0 0) (: (∨ (¬ F) (∧ G H)) (-> UInt Bool)))
    (, (MkControl 0 0) (: (∨ (¬ F) (∨ G H)) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∨ (¬ F) (¬ G)) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∨ (¬ F) (¬ H)) (-> UInt Bool)))
    (, (MkControl 2 0) (: (∨ (¬ G) H) (-> UInt Bool)))
    (, (MkControl 0 0) (: (∨ (¬ G) (∧ F H)) (-> UInt Bool)))
    (, (MkControl 1 0) (: (∨ (¬ G) (¬ H)) (-> UInt Bool)))
    (, (MkControl 0 0) (: (∨ (¬ H) (∧ F G)) (-> UInt Bool)))
    (, (MkControl 4 1) (: (¬ F) (-> UInt Bool)))
    (, (MkControl 4 1) (: (¬ G) (-> UInt Bool)))
    (, (MkControl 4 1) (: (¬ H) (-> UInt Bool))))))
