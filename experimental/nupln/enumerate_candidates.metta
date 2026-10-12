;; Script to easily exhaustively enumerate candidates

;; Load the code under test
!(import! &self ./nupln.metta)

;; Define new KB to test synthesized candidates
!(bind! &kbn (new-space))
!(add-atom &kbn (: F (-> UInt Bool)))
!(add-atom &kbn (: G (-> UInt Bool)))
!(add-atom &kbn (: H (-> UInt Bool)))

;; Enumerate candidates up to depth 5
!(nupln_bc &kbn (MkControl 1000 5) (: $cnd (-> UInt Bool)))
