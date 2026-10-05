;; Parity bit test for nupln.metta
;;
;; Run with:
;;   ~/Work/TrueAGI/PeTTa/run.sh test_parity_bit.metta
;;
;; The goal of this test is to have nupln_bc *infer* an expression for
;; the parity bit of the N input features F1, ..., FN.  Parity here
;; means: True when an even number of Fi's are True, False when an
;; even number are.  The features are encoded in the natural way,
;; Fi(x) = (bit (i-1) of x), over the domain x ∈ {0, ..., 2^N - 1}.
;; This file populates the knowledge base and builds the parity query
;; automatically from the single hyper-parameter `(paritySize)`, so
;; that changing N only requires changing that one place.
;;
;; This file does NOT assert a specific expected proof: parity is
;; non-trivially ambiguous (XOR has multiple equivalent
;; expressions), and the order of `collapse` is fragile.  We simply
;; invoke nupln_bc directly so that one can see all the expressions
;; that match the parity truth table, and pick an expected output
;; by hand.

;; Load the code under test
!(import! &self ./nupln.metta)

;;;;;;;;;;;;;;;;;;;;
;; Hyper-parameter ;;
;;;;;;;;;;;;;;;;;;;;

;; Number of input features (i.e. bits).  Features are named F1, F2,
;; ..., FN, and the domain is {0, 1, ..., 2^N - 1}.
(= (paritySize) 3)

;;;;;;;;;;;;;;;
;; Helpers ;;
;;;;;;;;;;;;;;;

;; getBit x i: i-th bit of integer x (returns 0 or 1, 0-indexed).
(= (getBit $x $i)
   (if (== $i 0)
       (#mod $x 2)
       (getBit (#div $x 2) (#- $i 1))))

;; parityBit x n: parity of bits 0..n-1 of x.  Returns ⊤ if the count
;; of set bits is even, ⊥ otherwise.
(= (parityBit $x $n)
   (if (== $n 0)
       ⊤
       (let* (($bit (== (getBit $x (#- $n 1)) 1))
              ($rest (parityBit $x (#- $n 1))))
         (if $bit
             (if (== $rest ⊥) ⊤ ⊥)
             $rest))))

;; predName i: "F1", "F2", ..., the name of the i-th input feature.
(= (predName $i) (atom_concat "F" $i))

;; truthName i x tv: atom name for the truth value of Fi at x.
;; Format: f{i}-{x}{t|f}, e.g. f1-0t, f2-3f.
(= (truthName $i $x ⊤)
   (atom_concat (atom_concat (atom_concat (atom_concat "f" $i) "-") $x) "t"))
(= (truthName $i $x ⊥)
   (atom_concat (atom_concat (atom_concat (atom_concat "f" $i) "-") $x) "f"))

;; Fi(x) = (bit (i-1) of x)
(= (bitValueOfPred $i $x)
   (if (== (getBit $x (#- $i 1)) 1) ⊤ ⊥))

;;;;;;;;;;;;;;;;;;;;;;;
;; KB construction ;;
;;;;;;;;;;;;;;;;;;;;;;;

;; Add (: 0 UInt), (: 1 UInt), ..., (: (2^N - 1) UInt).
(= (addUIntAtoms $kb $n)
   (if (== $n 0)
       ()
       (let* (($v (#- $n 1))
              ($_ (add-atom $kb (: $v UInt))))
         (addUIntAtoms $kb $v))))

;; Add type signatures for F1, ..., FN.
(= (addPredTypes $kb $i)
   (if (== $i 0)
       ()
       (let* (($pname (predName $i))
              ($_ (add-atom $kb (: $pname (-> UInt Bool)))))
         (addPredTypes $kb (#- $i 1)))))

;; Add the truth value atom for Fi at domain point x.
(= (addTruthAtom $kb $i $x)
   (let* (($tv (bitValueOfPred $i $x))
          ($name (truthName $i $x $tv))
          ($pred (predName $i)))
     (add-atom $kb (: $name (≞ (→ (⊙ $x) $pred) $tv)))))

;; For Fi, add truth value atoms at all x ∈ {0, ..., 2^N - 1}.
(= (addTruthAtomsForPred $kb $i $n $x)
   (if (== $x (pow-math 2 $n))
       ()
       (progn (addTruthAtom $kb $i $x)
              (addTruthAtomsForPred $kb $i $n (#+ $x 1)))))

;; Add truth value atoms for all F1, ..., FN.
(= (addAllTruthAtoms $kb $i $n)
   (if (== $i 0)
       ()
       (progn (addTruthAtomsForPred $kb $i $n 0)
              (addAllTruthAtoms $kb (#- $i 1) $n))))

;; Master driver: populate &kb with everything needed.
(= (populateKb $kb $n)
   (progn (addUIntAtoms $kb (pow-math 2 $n))
          (addPredTypes $kb $n)
          (addAllTruthAtoms $kb $n $n)))

;;;;;;;;;;;;;;;;;;;;;
;; Query building ;;
;;;;;;;;;;;;;;;;;;;;;

;; Build the left-leaning nested `,` of parity evaluations.
;; (buildParityQuery-rec $x $n $pred) =
;;   when x = 2^n - 1: (≞ (→ (⊙ x) $pred) (parityBit x n))
;;   otherwise:        (, (≞ (→ (⊙ x) $pred) (parityBit x n))
;;                         (buildParityQuery-rec (+ x 1) n $pred))
(= (buildParityQuery-rec $x $n $pred)
   (if (== $x (#- (pow-math 2 $n) 1))
       (≞ (→ (⊙ $x) $pred) (parityBit $x $n))
       (, (≞ (→ (⊙ $x) $pred) (parityBit $x $n))
          (buildParityQuery-rec (#+ $x 1) $n $pred))))

;; Like above but without needed to pass $pred.
(= (buildParityQuery $n) (: $prf (buildParityQuery-rec 0 $n $pred)))

;;;;;;;;;;;;;;;
;; Run test ;;
;;;;;;;;;;;;;;;

;; Populate kb
!(bind! &kb (new-space))
!(populateKb &kb (paritySize))

;; Trace kb and query
!(trace! (kb (get-atoms &kb)) (empty))
!(trace! (query (buildParityQuery (paritySize))) ())

;; Run the chainer to find every $pred over F1, ..., FN whose
;; evaluation matches the parity truth table.  Reasonable choices for
;; size and depth budgets are:
;;
;; * N=1: (MkControl 15 4) with solution: (¬ F1)
;; * N=2: (MkControl 135 6) with solutions:
;;   (∨ (∧ F1 F2) (∧ (¬ F1) (¬ F2)))
;;   (∧ (∨ F1 (¬ F2)) (∨ (¬ F1) F2))
;; * N=3: (MkControl ? ?) with solutions:
!(once
  (nupln_bc &kb (MkControl 500 8) (buildParityQuery (paritySize))))
