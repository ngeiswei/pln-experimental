# Useful prompts

## Change directory
```
Please note that we are now under
`~/Work/TrueAGI/pln-experimental/experimental/nupln`.
```

## Fix `isNormal` and `toNormal` (for glm-5.3-flash)
```
Could you modify `isNormal` and `toNormal` in @nupln.metta so that all unit
tests in @test_nupln.metta pass?  There is some code left by one of your
collegues in @elegant_normal.metta that you could find useful, although do
not hesitate to improve it or to re-implement it if you come up with a more
elegant solution.  BTW, do not modify @nupln.metta directly, make first a
copy of it called `nupln-glm-5.3-flash.metta` as well as a copy of
@test_nupln.metta called `test_nupln-glm-5.3-flash.metta`.  Think as deeply
as you need, I want good quality code.
```

Simpler alternative.

```
Could you modify `isNormal` and `toNormal` in @nupln.metta so that all unit
tests in @test_nupln.metta pass?  Do not modify @nupln.metta directly, make
first a copy of it called `nupln-fix-normal.metta` as well as a copy of
@test_nupln.metta called `test_nupln-fix-normal.metta`.  Think as deeply
as you need, I want good quality code.
```

Even simpler.

```
Could you modify `isNormal` and `toNormal` in @nupln.metta so that all unit tests in @test_nupln.metta pass?  You can modify @nupln.metta directly.  Think as deeply as you need, I want good quality code.
```

## Simplify using PeTTa built-ins
```
It looks good.  I wonder if you could simplify it a bit by re-using PeTTa
built-ins when possible such as `second-from-pair` instead of `pairSeconds`.
Could you study what PeTTa has to offer and see where you could simplify the
code by re-using it?  Of course make sure that all tests still pass.  You can
modify @nupln.metta directly.
```

## Modify nupln_bc to account for the new reduction
```
I have added a test in @test_nupln.metta, it currently passes because `nupln_bc` does not behave according to the new normalizing code that you have created for `isNormal` and `toNormal`.  So first I would like you to remove from the output of the tests all results that are not in normal form according to `isNormal`.  After that the test should fail, so then your mission will be to fix `nupln_bc` to make it pass, but one step at a time, first "correct" unit test, and then get back to me.
```
then
```
Excellent!  Now process with the next step, which is to fix `nupln_bc` so that it directly produces normalized forms.
```
then
```
Now could you go through the list of results of the last test (the 57 candidates in normal form) and see if you can identify candidates that are syntactically different but semantically equivalent, meaning some could potentially be reduced to a stricter normal form?  Do not modify @nupln.metta or @test_nupln.metta, I want merely you to do an investigation. If you need to run experiments then create new files.
```

## Compare with and without normalization
```
Could you temporarily disable normalization in `nupln_bc` and count how many candidates are produced without normalization, and compare that with the original code with normalization?  You can use @enumerate_candidates.metta for your testing.
```

## Looking for more reduction rules in a giant corpuse
```
In file @candidates-depth-5-after.stdout there is a very large number of boolean expressions, produced with the help of @enumerate_candidates.metta then edited to strip away anything but boolean expressions.  Could you first partition them in semantically equivalent classes?  They all have only three input features `F`, `G` and `H`, so there should be at most 256 equivalent classes.  Second, could you indentify reduction rules to normal form that might have been missed inside @nupln.metta?  As you proceed do not modify any existing file, if needed you can create new files.  Finding new rules is going to tedious so feel free to think as deeply as you want.  Once you have discovered new rules, report back to me.
```

## Optimally order clauses corresponding to `nupln_bc`
```
As you certainly have noticed PeTTa transpile MeTTa programs into Prolog.  As you probably know the ...
```

## How to enrich reduction

### First suggestion

```
 Missing reductions discovered

 1. N1 — non-adjacent contradiction/tautology (biggest impact): (∧ L1 … Li …
    (¬ Li) … Ln) ≡ False, (∨ L1 … Li … (¬ Li) … Ln) ≡ True. Affects 51 % of
    all 131 217 candidates (33 552 top-∧ contradictions + 33 384 top-∨
    tautologies).

 2. N2 — buried contradiction in dual sub-chain: (∨ X (∧ … L … (¬ L) …)) ≡ X
    and dual. Missed because noAbsorbNorReduce only inspects literals at the
    surface, not inside nested dual clauses.

 3. N3 — symmetric noAbsorbNorReduce: the absorption check (== (car-atom $hd)
    $dop) is asymmetric and disables the (∨ F (∨ F G)) → (∨ F G) case for OR
    chains.

 4. R4–R8 (clause-clause absorption, generalized reduction, consensus,
    factorization) — already implemented and verified sound in the
    pre-existing canon.py. They produce a 3.5× reduction (131 217 → 37 495
    forms). Documented in FINDINGS.md with concrete class-by-class impact
    estimates.

 Pre-existing prior-art
 The repo already contained analyze_candidates.py, canon.py, canon2.py,
 equiv_classes.txt, residual_classes.txt, residual_classes2.txt from earlier
 sessions. The new analysis layers on top of those and identifies the
 additional reductions needed beyond R4–R8.

 The single most impactful concrete change recommended: extend
 noAbsorbNorReduce (and isShallowNormal) to detect non-adjacent
 literal/complement pairs at any chain level, eliminating ~half of the
 candidate duplicates.
```

### Second suggestion

```
 Report

 I studied candidates-depth-5-after.stdout (131 217 boolean expressions over
 F, G, H) and without modifying any existing file, I created:

 - nupln_semantic_partition_and_missing_rules.md – the consolidated report.
 - /tmp/parse_eval.py, /tmp/rules.py, /tmp/analyze3.py – the working scripts
   (kept in /tmp/, not in the repo, so as not to clutter the existing Python
   scripts already there from a previous session).

 Partition result (confirms the previous session's finding)

 - 131 217 distinct expressions partition into 254 of the 256 possible truth
   tables.
 - Only 10010110 and 01101001 are missing — they are mutual negations of each
   other ("balanced" boolean functions that the depth-6 budget of
   enumerate_candidates.metta cannot express without blowup).
 - Largest class: 5 238 members (00010111). Mean class size ≈ 517.

 Reduction rules missing from nupln.metta — soundness verified

 I re-implemented the engine in Python (rules.py), adding candidate rules on
 top of a faithful port of the existing normal-form gates, and ran it on the
 full 131 217-expression dataset with truth-table-preservation checked for
 every rewrite (zero violations).

 ┌─────────────────────┬─────────────┬───────────────────────────────────────┐
 │ Rule                │ Fires       │ Description                           │
 ├─────────────────────┼─────────────┼───────────────────────────────────────┤
 │ R1 — falsified-term │ 10 792 + 36 │ A clause term is dropped when it is   │
 │ / empty-clause → ⊥  │ 092 + 1 254 │ semantically falsified by the chain   │
 │ (∧-context) and its │ ⊥/TOP       │ literals; if all terms of a clause    │
 │ dual (∨-context)    │ collapses   │ are so falsified the whole chain      │
 │                     │             │ collapses to ⊥. Implementation uses   │
 │                     │             │ an 8-row truth-table check, not a     │
 │                     │             │ syntactic complement pattern (the     │
 │                     │             │ syntactic pattern is unsound for      │
 │                     │             │ terms with literals under             │
 │                     │             │ disjunction).                         │
 ├─────────────────────┼─────────────┼───────────────────────────────────────┤
 │ R2 — clause / term  │ 2 416 + 40  │ Generalises nupln's literal-vs-clause │
 │ subsumption         │             │ absorption to full clause-vs-clause   │
 │                     │             │ subsumption.                          │
 ├─────────────────────┼─────────────┼───────────────────────────────────────┤
 │ R3 — consensus      │ 11 030 + 10 │ Given clauses c1 ∋ a, c2 ∋ ¬a, the    │
 │ resolution          │ 860         │ resolvent res = (c1 \ {a}) ∪ (c2 \    │
 │ (limited, monotone) │             │ {¬a}) is implied by the parent pair;  │
 │                     │             │ any existing clause containing res is │
 │                     │             │ dropped, and the resolvent replaces   │
 │                     │             │ the parents when one of them is       │
 │                     │             │ dropped. Implementation has a         │
 │                     │             │ 60-iteration cap with a progress      │
 │                     │             │ fingerprint.                          │
 ├─────────────────────┼─────────────┼───────────────────────────────────────┤
 │ R4 — tautology      │ 246 + 312   │ A ∨-clause containing both a literal  │
 │ clause /            │             │ and its negation is a tautology (drop │
 │ contradiction term  │             │ from ∧-chain); the dual for ∨.        │
 ├─────────────────────┼─────────────┼───────────────────────────────────────┤
 │ R5 — at-most-one    │ fix         │ A correctness fix uncovered while     │
 │ redundant-term      │             │ validating R1-or: a term is           │
 │ removal per pass    │             │ "redundant given the rest" only if    │
 │                     │             │ the rest itself is kept; one removal  │
 │                     │             │ per pass prevents circular            │
 │                     │             │ mutual-redundancy justifications.     │
 └─────────────────────┴─────────────┴───────────────────────────────────────┘

 Net impact on the 131 217 candidates:

 ```
   expressions that shrink:           58 019  (44 % of the file)
   total nodes before:              2 675 503
   total nodes after:               2 219 822
   nodes saved:                       455 681  (17 %)
   hidden contradictions collapsed:        204
   hidden tautologies collapsed:         1 056
   SEMANTIC VIOLATIONS:                    0
 ```

 Caveats uncovered along the way (documented in the report)

 1. The new R1 implementation must be semantic, not syntactic: a literal
    appearing inside a (∨ F G) term does not falsify it under F = 0. The
    syntactic "literal-complement" pattern that I tried first was unsound in 1
    545 ways.
 2. The previous prototype of R3 had the consensus direction inverted
    (dropping clauses when the resolvent was a subset, the opposite of what is
    sound); the corrected version produces zero violations.
 3. R3 is deliberately incomplete: I do not add new clauses whose resolvent
    subsumes nothing (that would allow size blow-up). The trade-off: a subset
    of the 1 669 hidden contradictions are not detectable by R3 alone and
    would need a full Blake-style resolution closure or a truth-table-based
    post-pass.
 4. 197 expressions hit the 60-iteration cap on R3 fixpoint — all still
    soundly reduced (the engine returns the current state).

 Residual ambiguity after R1–R5 — 71 classes

 After applying all rules to fixpoint, 71 classes still contain more than one
 minimal reduced form. The ambiguity is structural and not addressable by
 further local rewrites:

 - CNF ↔ DNF duality — every ambiguous class shows a pair of equal-size dual
   forms, e.g. (∧ (∨ F H) (∨ G (¬ H))) and (∨ (∧ F (¬ H)) (∧ G H)) for the
   truth table 00011011. No local rewrite can break this tie; a
   canonicalisation convention (e.g. "always emit DNF, or emit the form whose
   root sorts smaller under n<") is required.
 - Variable symmetry — e.g. class 00010110 has three minimal size-17 forms
   that differ only by permutations of (F, G, H). This is an intrinsic
   symmetry of the underlying function, not addressable by rewrites.

 Recommendation for nupln.metta

 Documented in detail in the report. The two highest-payoff changes are:

 1. R1 + R4 in reduceOperands / compactAbsorbImpl — extending the current
    literal-only check to a (syntactic or small truth-table) falsified-term /
    tautology-clause check. This is what catches all 1 254 hidden
    contradictions and the 1 056 hidden tautologies on this dataset.
 2. A canonicalisation convention — a one-line tie-breaker among equal-size
    normal forms (e.g. "keep the form whose root sorts smaller under n<")
    collapses the 71 remaining ambiguous classes to 254 unique normal forms.

 The optional further work (R3 with full resolvent addition, R-Abs-Imp
 implication tables, distributivity canonicalisation) is described in the
 previous session's MISSING_RULES.md (which already covers the impact-ranked
 description of similar rules); the new contribution here is the
 soundness-verified engine that demonstrates these rules on the full dataset.
```

### Third suggestion

```
 Final Report — both tasks complete

 Files created (under analysis/, nothing modified)

 ```
   analysis/
   ├── lib.py                 # parsing, eval, @</n< ordering, isNormal
 replication
   ├── partition.py           # builds the 254-class partition
   ├── verify_isnormal.py     # validates my isNormal replication against
 test_nupln
   ├── rules_diff.py          # anti-diff + universal-validity rule discovery
   ├── categorize.py          # clusters rules into named families
   ├── REPORT.md              # full report
   └── out/
       ├── classes_depth5.json    # full partition (11MB)
       ├── summary_depth5.txt     # stats + top classes
       ├── rules.json             # 31,099 universally-valid rules
       └── rules_text.txt         # tabular form
 ```

 1. Partition — DONE

 131,217 distinct expressions → 254 equivalence classes (out of at most 256).
 The two missing keys are 01101001 and 10010110 — exactly the 3-bit XOR and
 its negation (unreachable at depth 5).

 All 254 classes have ≥2 members; the corpus is enormously over-representative
 relative to normal forms (the all-⊤ and all-⊥ classes alone contain 1,669
 tautologies and 1,669 contradictions each, and the biggest "majority" class
 has 5,238 members with 6 distinct minimal-size representatives).

 2. Missed reduction rules — DISCOVERED

 Anti-diffed every non-minimal expression against its class minima, validated
 each candidate rule by enumerating all assignments of its schematic
 variables, and clustered the 32,536 universally-valid rules into named
 families:

 ┌─────┬─────────────────────────────┬─────────┬─────────────────────────────┐
 │ #   │ Rule family                 │ Corpus  │ Why nupln.metta misses it   │
 │     │                             │ hits    │                             │
 ├─────┼─────────────────────────────┼─────────┼─────────────────────────────┤
 │ 3.1 │ Resolution (x ∨ y) ∧ (¬x ∨  │ 87      │ noAbsorbNorReduce only      │
 │     │ y) ≡ y (and dual)           │         │ checks literal operands of  │
 │     │                             │         │ sibling clauses, never      │
 │     │                             │         │ cross-clause complementary  │
 │     │                             │         │ literals                    │
 ├─────┼─────────────────────────────┼─────────┼─────────────────────────────┤
 │ 3.2 │ Subsumption with ¬: (x ∨ y) │ 32      │ same                        │
 │     │ ∧ (x ∨ ¬y) ≡ x (and dual)   │         │                             │
 ├─────┼─────────────────────────────┼─────────┼─────────────────────────────┤
 │ 3.3 │ Factoring/Distribution:     │ 23      │ noAbsorbNorReduce removes   │
 │     │ (x∧y) ∨ (x∧z) ≡ x ∧ (y∨z)   │         │ operands absorbed by a      │
 │     │ (and dual)                  │         │ literal sibling, but never  │
 │     │                             │         │ factors a common operand    │
 │     │                             │         │ out of two clauses          │
 ├─────┼─────────────────────────────┼─────────┼─────────────────────────────┤
 │ 3.4 │ Composite-clause            │ ~60     │ same — needs to recurse     │
 │     │ resolution/subsumption      │         │ into sub-clauses            │
 │     │ (e.g. (x₀ ∨ (x₁∧x₂)) ∧ (¬x₁ │         │                             │
 │     │ ∨ x₀) ≡ x₀)                 │         │                             │
 ├─────┼─────────────────────────────┼─────────┼─────────────────────────────┤
 │ 3.5 │ XOR / De Morgan:            │ 30      │ keeps both forms            │
 │     │ (x∧¬y)∨(¬x∧y) ≡             │         │                             │
 │     │ (x∨y)∧(¬x∨¬y)               │         │                             │
 ├─────┼─────────────────────────────┼─────────┼─────────────────────────────┤
 │ 3.6 │ Chain-level                 │ highest │ isConjNonContradict checks  │
 │     │ tautology/contradiction     │ impact  │ only the first literal vs   │
 │     │ (∧-chain with a literal     │         │ the first of the rest;      │
 │     │ clause L and a sibling      │         │ non-adjacent pairs slip     │
 │     │ clause requiring ¬L → ⊥)    │         │ through. Verified with      │
 │     │                             │         │ PeTTa that (∧ (¬ F) (∨ (∧ F │
 │     │                             │         │ G) (∧ F H))) is considered  │
 │     │                             │         │ isNormal=True despite being │
 │     │                             │         │ a contradiction.            │
 ├─────┼─────────────────────────────┼─────────┼─────────────────────────────┤
 │ 3.7 │ Long tail of single-step    │ ~30,000 │ —                           │
 │     │ rules (all derivable from   │         │                             │
 │     │ 3.1–3.5)                    │         │                             │
 └─────┴─────────────────────────────┴─────────┴─────────────────────────────┘

 Every claim was verified both with Python truth-table checks and (for the
 most impactful ones) directly against PeTTa's isNormal:
 - (∧ (∨ F G) (∨ (¬ F) G)) passes isNormal = True but is semantically G
   (resolution).
 - (∨ (∧ F G) (∧ F H)) passes isNormal = True but is semantically (∧ F (∨ G
   H)) (factoring).
 - (∧ (¬ F) (∨ (∧ F G) (∧ F H))) passes isNormal = True but is semantically ⊥
   (contradiction).

 Priority recommendation for editing nupln.metta (without modifying it as part
 of this task — only reporting): rule 3.6 is by far the highest impact
 (collapses the 1,669-member ⊥ and ⊤ classes each to a single node), then
 3.1–3.5 (which together collapse the remaining redundancy).
```

### Fourth suggestion

```
 Summary

 I partitioned the 131,217 boolean expressions in
 candidates-depth-5-after.stdout by truth table (8 bits over (F,G,H) ∈
 {0,1}^3) — 254 of the 256 possible tables are realized (the two missing ones,
 tt=105 and tt=150, are the 3-variable parities, which need expressions deeper
 than the depth-5 enumeration budget). All 131,217 forms pass my Python port
 of nuPLN's isNormal, confirming nuPLN's normal form is far from canonical:
 every one of the 254 equivalence classes contains multiple distinct normal
 forms (smallest class: 2 forms; largest: 596).

 Then I mined the residuals for specific local rewrite patterns and identified
 six missing rules, ranked by how much of the duplication each one explains
 (over 98,000 (non-min, min) pairs in each class):

 ┌───────────┬────────┬──────────────────────────────────────────────────────┐
 │ Rule      │ Share  │ What it is                                           │
 ├───────────┼────────┼──────────────────────────────────────────────────────┤
 │ R-Abs-Gen │ 29.1 % │ Clause/term subsumption absorption — nuPLN only      │
 │           │        │ absorbs when the absorber is a literal; it misses    │
 │           │        │ F∧G absorbing F∧G∧H, etc.                            │
 ├───────────┼────────┼──────────────────────────────────────────────────────┤
 │ R-Abs-Imp │ 14.0 % │ Implication absorption via truth tables — (∧ F (∨ (∧ │
 │           │        │ F (∨ G H)) (∧ (¬G) (¬H)))) ≡ F because F implies the │
 │           │        │ nested disjunction even though it doesn't            │
 │           │        │ syntactically appear in its element set.             │
 ├───────────┼────────┼──────────────────────────────────────────────────────┤
 │ R-Taut    │ 10.0 % │ Tautology / falsum clause removal — nuPLN's          │
 │           │        │ isConjNonContradict only rejects adjacent            │
 │           │        │ complementary literals, so buried complements like   │
 │           │        │ (∨ G (∨ (¬G) H)) slip through.                       │
 ├───────────┼────────┼──────────────────────────────────────────────────────┤
 │ R-Dist    │ 8.4 %  │ Distributivity (single factorisation step applied in │
 │           │        │ the canonical direction).                            │
 ├───────────┼────────┼──────────────────────────────────────────────────────┤
 │ R-Red-Gen │ 2.3 %  │ Generalised reduction — drop ¬L from a clause when a │
 │           │        │ sibling clause (not just a literal) covers it: (∧ (∨ │
 │           │        │ F G) (∨ (¬F) (∨ G H))) ≡ (∧ (∨ F G) (∨ G H)).        │
 ├───────────┼────────┼──────────────────────────────────────────────────────┤
 │ R-VSym    │ 0.2 %  │ Variable permutation — not a rewrite rule but an     │
 │           │        │ intrinsic symmetry of some functions.                │
 └───────────┴────────┴──────────────────────────────────────────────────────┘

 Together these six rules explain ≈64 % of the duplicated normal forms. The
 remaining 36 % concentrate in a handful of classes (top: tt=232, 236, 200, …)
 and require either truth-table-level simplification, repeated
 consensus-with-simplified-resolvent passes (R7 chains), or a fixed
 distributive direction (CNF or DNF + consensus/absorption to primes) — i.e. a
 full iterative normaliser, not cheap local rules.

 As a sanity check on the stronger normaliser side, adding R-Abs-Gen +
 R-Abs-Imp + R-Taut + R-Dist + R-Red-Gen to nuPLN's rules (via the
 verified-sound iterative normalizer canon.py) reduces the candidate count
 from 131,217 to 37,493 distinct forms — and to 4 classes fully collapsed to a
 single form. So the rules definitely help; full collapse is gated by the
 deeper patterns described above.

 Files I created (no existing files modified)

 - ~/Work/TrueAGI/pln-experimental/experimental/nupln/analyze_candidates.py —
   parses the candidate file, evaluates truth tables, partitions into 254
   equivalence classes, ports nuPLN's isNormal to Python and verifies all
   131,217 candidates pass it.
 - ~/Work/TrueAGI/pln-experimental/experimental/nupln/canon.py — a
   verified-sound iterative normaliser implementing R-Abs-Gen, R-Abs-Imp,
   R-Taut, R-Dist, R-Red-Gen, R6/R7 consensus on top of nuPLN's rules; reduces
   131,217 → 37,493 forms with 0 soundness violations across all candidates.
 - ~/Work/TrueAGI/pln-experimental/experimental/nupln/canon2.py — an attempt
   at a more aggressive local-search normaliser including a distributivity
   rule R9 (flips the chain root operator). It turned out to be subtler than
   expected — I kept it for completeness but the verified baseline is
   canon.py.
 - ~/Work/TrueAGI/pln-experimental/experimental/nupln/rule_mine.py — the
   rule-mining script that, for each equivalence class, pairs the size-minimal
   representative against every other form and runs a bank of detectors (one
   per candidate rule) to identify which rule fires.
 - ~/Work/TrueAGI/pln-experimental/experimental/nupln/equiv_classes.txt and
   residual_classes.txt — the class partition and the
   residual-after-stronger-rules partition, for browsing.
 - ~/Work/TrueAGI/pln-experimental/experimental/nupln/MISSING_RULES.md — the
   full written-up report with the table, the rules stated as MeTTa-flavoured
   rewrites, and recommended additions to nupln.metta.

 The two highest-payoff changes I'd recommend for nupln.metta are: (1) drop
 the isLiteral guard in reduceOperands so clause-level reduction / absorption
 apply (R-Abs-Gen + R-Taut combined ≈ 39 % of the duplication), and (2) use
 the existing nupln_uniform machinery to cache each subterm's truth table and
 apply (and a b) ≡ a when tt(a) ⊆ tt(b) (R-Abs-Imp, another 14 %). The
 residual ≈ 47 % cannot be fixed cheaply — it requires an iterative
 consensus-based normaliser or a switch to a fully canonical form.
```

## Massive Simplification

I looked carefully at the code and I think we can do much much better.
Let me explain the reasoning.  Assume the following expression:

`(∧ X Y)` where `X` and `Y` are already in normal form.  Without too
much loss of generality we can assume that both `X` and `Y` are
disjunctions, it's the most difficult case after all.  What you just
need to do is: for each variable `x` that appears in `X`, check if it
appears in `Y`, if it does, then `(∧ X Y)` is not in normal form
because remember we assumed that `X` is in normal form, thus it must
have an impact on the output of `X`, if it was irrelevant then `X`
would not be in normal form.  So then two cases:

- 1. Some assignment of `x` makes `X` evaluate to False.  In this case
  whether `x` appears in `Y` does not matter, because `Y` does not
  matter for the evaluation of `(∧ X Y)`.

- 2. Some assignment of `x` makes `Y` evaluate to True.  In this case
  any appearance of `x` in `Y` could have been replaced by True or
  False.  But this contradict the assumption we made about `Y` being
  in normal form.  If it is in normal form then is should not contain
  superfluous constants like True or False.

Thus in this case `(∧ X Y)` cannot be in normal form.  The same
reasoning applies to `(∨ X Y)`.  So there is still an expensive
operation, for each `x` in `X` we must check if it is in `Y`, which
requires another iteration over every `y` in `Y` to check if `x == y`.
For that there is no need to flatten then reconstruct, writting a
custom recursive function for that search is going to be more
efficient.

I hope you get the idea.  There is going to be a lot of code that can
be discarded after that change, but you still need to check a few
things like left associativity of `∧` and `∨`, and that the order
`n<1` is kept, and a few other minor things.  Could you give it a try?

`𝕋` and `𝔽`

Actually, after more thinking I'm afraid there is a flaw in my
reasoning, which is that `x` might have some assignments that make
both `X` evaluate to true or false due to other variables in `X`.  So
my reasoning only works if `x` solely determines the outcome of `X`,
which, if we assume that `X` is in normal form, only happens if `x` is
the only variable in `X`.  In that situation though the method should
still work but will not cover nearly as many situations as I initially
thought.  It's late for me and my mind start to get easily confused so
many finish your current experiment, it is very likely to fail but
let's see, and then we can try this less general but still valid idea
later.
