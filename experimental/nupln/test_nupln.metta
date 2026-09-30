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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;;;;;;;;;;;;;;;;;;;;;; ;;
;; ;; Helper Unit Tests ;; ;;
;; ;;;;;;;;;;;;;;;;;;;;;;; ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

;;;;;;;;;;;;;;;;
;; ;;;;;;;;;; ;;
;; ;; Test ;; ;;
;; ;;;;;;;;;; ;;
;;;;;;;;;;;;;;;;

;; Enable memoization for nupln_bc
!(memoize nupln_bc)
;; Settings suggested by Minimax-m3
!(config-memoize (unique-limit 10000) (strategy wtinylfu) (size-limit 5))

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
;; corresponding to (¬ F).  The proof for (¬ F 0) = ⊥ uses (nef f0t)
;; because (F 0) = ⊤; the proof for (¬ F 1) = ⊤ uses (net f1f) because
;; (F 1) = ⊥.  Budget: 1 for outer `,` + 7 for (nef f0t) + 7 for (net
;; f1f) = 15.
!(test
  (nupln_bc &kb 15 (: $prf (, (≞ (→ (⊙ 0) $pred) ⊥)
                              (≞ (→ (⊙ 1) $pred) ⊤))))
  (MkSized 15 (: (, (nef f0t) (net f1f))
                 (, (≞ (→ (⊙ 0) (¬ F)) ⊥)
                    (≞ (→ (⊙ 1) (¬ F)) ⊤)))))

;; Infer what predicates could evaluate to the truth table
;; corresponding to (∧ F G)
!(test
  (nupln_bc &kb 27 (: $prf (, (≞ (→ (⊙ 0) $pred) ⊤)
                           (, (≞ (→ (⊙ 1) $pred) ⊥)
                              (≞ (→ (⊙ 2) $pred) ⊥)))))
  (MkSized 27 (: (, (cet f0t g0t) (, (cefl f1f) (cefr g2f)))
                 (, (≞ (→ (⊙ 0) (∧ F G)) ⊤)
                 (, (≞ (→ (⊙ 1) (∧ F G)) ⊥)
                    (≞ (→ (⊙ 2) (∧ F G)) ⊥))))))
