# Optimal `nupln_bc` Clause Ordering in `nupln.metta`

## TL;DR

**Move `product` to FIRST, `orT` to SECOND, `implT` to THIRD, and `base` to FOURTH.** This yields ~11% faster parity inference (N=2: 0.76s → 0.67s) with **no change in the solution found or the budget consumed**.

### Recommended clause order (was → now):

| # | Original (nupln.metta:493–1008) | Recommended |
|---|----------------------------------|-------------|
| 1 | `(nupln_bc ... $x $a)` — **base / KB lookup** | `(nupln_bc ... (, $x $y) (, $a $b))` — **product / `,` split** |
| 2 | `(nupln_bc ... (∧ $f $g) (-> $a Bool))` — **andT** | `(nupln_bc ... (∨ $f $g) (-> $a Bool))` — **orT** |
| 3 | `(nupln_bc ... (∨ $f $g) (-> $a Bool))` — **orT** | `(nupln_bc ... (→ $f $g) (CPred (-> $a Bool)))` — **implT** |
| 4 | `(nupln_bc ... (¬ $f) (-> $a Bool))` — **notT** | `(nupln_bc ... $x $a)` — **base / KB lookup** |
| 5 | `(nupln_bc ... (⊙ $x) (-> $a Bool))` — **singleT** | `(nupln_bc ... (∧ $f $g) (-> $a Bool))` — **andT** |
| 6 | `(nupln_bc ... (→ $f $g) (CPred (-> $a Bool)))` — **implT** | `(nupln_bc ... (¬ $f) (-> $a Bool))` — **notT** |
| 7 | `(nupln_bc ... (cet ...))` — eval (∧)⊤ | `(nupln_bc ... (⊙ $x) (-> $a Bool))` — **singleT** |
| 8–14 | other eval rules (cefl, cefr, detl, detr, def, net, nef) | unchanged (eval rules in original order) |
| 15 | `(nupln_bc ... (, $x $y) (, $a $b))` — **product / `,` split** | — |

Concretely, swap four things in `nupln.metta`:
1. Move the `product` clause (line 1008) to **first**.
2. Move the `orT` clause (line 555) to **second**.
3. Move the `implT` clause (line 628) to **third**.
4. Move the `base` clause (line 493) to **fourth**.
5. The other typing rules (`andT`, `notT`, `singleT`) and all eval rules stay in their current relative positions; only the typing rule ORDER is now `orT, implT, andT, notT, singleT`.

---

## Background

In `nupln.metta`, every `(= (nupln_bc $kb ...) body)` rule is compiled by PeTTa (`src/translator.pl:translate_clause/2,3`) into a Prolog clause `nupln_bc(KB, Control, Goal, Out) :- BodyOut.` via `assertz(Clause)` (translator.pl:38, 275). **Prolog's `assertz` appends to the end of the clause list, so the source order in `nupln.metta` IS the Prolog search order.** Reordering the `(= (nupln_bc ...) ...)` blocks in the source file directly reorders which clause Prolog tries first.

For an `once` query — as in `test_parity.metta:189` — the *first* rule to match determines the solution found. Different orderings can return different (but equivalent) solutions; some orderings make the chainer explore deeply before backtracking, others let it commit quickly to a shallow proof.

## Method

1. Used `/tmp/dump_nupln.metta` + `/tmp/extract_heads.pl` to dump all 15 compiled `nupln_bc` clauses in source order.
2. Wrote `/tmp/exp_gen*.py` to programmatically reorder the 15 clauses by name (preserving the header and stripping/keeping `(trace! ...)` wrappers as needed).
3. Wrote `/tmp/bench3.metta` — a parity benchmark using `(paritySize)` and `(MkControl ... ...)` placeholders, with `(once (nupln_bc &kb MKCONTROL (buildParityQuery (paritySize))))` as the hot loop.
4. Wrote `/tmp/run_bench_vN.sh` to substitute placeholders, time each variant via `/usr/bin/time`, and count `(👁 nupln_bc_base)` (Clause #1 attempts) and `(👁 nupln_bc ...)` (Clauses #2–15 attempts) in the cleaned stdout.

Worked in `/home/nilg/Work/TrueAGI/pln-experimental/experimental/nupln/`. Generated variants `exp_nupln_traced_<name>.metta` next to `nupln.metta`.

## Results — N=2, `MkControl 200 6` (recommended for N=2)

| Variant | Wall (s) | `nupln_bc_base` calls | Other calls | Budget used |
|---------|---------:|----------------------:|------------:|------------:|
| **orig** (current)              | 0.760 | 8505 | 10634 | 135 |
| swap_typing                     | 0.728 | 8127 |  9872 | 135 |
| best5                           | 0.720 | 8124 |  9872 | 135 |
| b3                              | 0.669 | 7626 |  8548 | 135 |
| **c4 (recommended)**            | **0.667** | **7612** | **8548** | **135** |
| c7                              | 0.666 | 7626 |  8548 | 135 |

c4 saves ~12.3% wall time and ~10.5% base calls vs `orig`. All variants find the same solution `(∧ (∨ F1 (¬ F2)) (∨ (¬ F1) F2))` with the same budget consumption.

## Variants that HURT performance (do NOT use)

| Variant | Wall | Why it loses |
|---------|-----:|--------------|
| `eval_then_typing` (base LAST)              | 1.996 s | 2.6× more base calls — base lookup happens for every type-check call, delaying the cheaper typing-rule matches |
| `typing_first` (∧/∨/¬/⊙/→ before base)     | 2.045 s | Typing rules return MULTIPLE bindings for type-check goals (one per rule), so the chainer explores many `once`-incompatible paths before reaching base |
| `neg_early` (net/nef/detl/detr first)      | 3.340 s | 4.3× more base calls — `net`/`nef` build negated-leaves first, which doesn't match the `(∨)`-and-`(∧)`-shaped XOR proof |
| `xor_first` (∨ before everything else)     | 4.472 s | 5.6× more base calls — type-checks for `∧` and `→` happen later, causing the chainer to retry |
| `single_first` (⊙ very early)              | 2.404 s | 3.2× more base calls — `⊙` is rare in the parity proof tree, so an early `⊙` match wastes effort |

The general lesson: **putting `base` LAST is the worst mistake**, because Clause #1's `match $kb ...` is called for every recursive sub-query and adds a KB scan (≈19 atom unifications for N=2) on every fallback.

## Why the recommended order works

For the parity query, every recursive sub-query `(: $X (≞ (→ (⊙ x) $pred) v))` recurses into three categories:

1. **Compound type-check** `(: $compound (-> UInt Bool))` — most common in the proof tree (recursion on the operands of every cet/cefl/.../detl/detr/def/net/nef node).
2. **Atom type-check** `(: $atom (-> UInt Bool))` for `$atom` already bound to a literal like `F1` or `F2` — matched by Clause #1 (base) against KB atoms like `(: F1 (-> UInt Bool))`.
3. **Leaf evaluation** `(: $proof-name (≞ (→ (⊙ x) Fi) v))` — matched by Clause #1 against `(: fi-xt (≞ (→ (⊙ x) Fi) tv))` atoms.

For category 1 the goal's first element is a compound like `(∨ F1 (¬ F2))`. Trying each typing rule in order:

- `product` fails (no `,` shape) — fast.
- `orT` matches when `$compound = (∨ $f $g)` — **MATCH in 2 attempts**. This is the common case for parity because every XOR proof contains nested `∨`s.
- `implT` fails (no `→` shape) unless the type-check is for a predicate's arrow form, then matches.
- `base` scans KB — wastes ~19 unification attempts when there is no KB atom whose first element is `(∨ ...)`.

In the original order, `base` is tried BEFORE `orT`, so every compound type-check incurs the KB scan even when `orT` would have matched in one step.

The optimal order places the **shape predicates by frequency of appearance in the proof tree**:
- `∨` (orT) — most frequent in XOR proofs (every disjunct is an `∨`)
- `→` (implT) — type-check for the `(→ ... (CPred ...))` proof constructor
- `∧` (andT) — type-check for the top-level conjunction
- `¬` (notT) — type-check for negations
- `⊙` (singleT) — only at the leaves

`base` is placed after the most common shape predicate so that compound type-checks commit quickly without the KB scan, while still being available for leaves and atom type-checks.

## Caveats

1. **Budget-dependent**: when the budget is too small to find *any* solution (e.g., `MkControl 100 6` for N=2), all orderings exhaust the budget the same way and have identical wall time and call counts. The ~11% improvement appears only when the budget is sufficient.
2. **Query-dependent**: this ordering is tuned for the **parity test** shape. For other query families (e.g., ones whose proof tree has more `∧` than `∨`), the optimal order of `andT`/`orT` may need to swap. The general principle is "ordering by frequency in the proof tree."
3. **Single-solution mode**: `test_parity.metta:189` uses `(once ...)`, so this benchmark only sees the FIRST solution. With `(collapse ...)`, the order might differ.
4. **Generated variants live in `experimental/nupln/`** (`exp_nupln_traced_*.metta`). The recommended edit is to **physically reorder the 15 `(= (nupln_bc ...) ...)` blocks in `nupln.metta` itself** per the table above — the test infrastructure and benchmarks don't need to change.

## Reproduction

```bash
cd /home/nilg/Work/TrueAGI/pln-experimental/experimental/nupln
python3 /tmp/exp_gen8.py    # generates exp_nupln_traced_c4.metta and friends
rm -rf /tmp/bench_out
/tmp/run_bench_v9.sh 2 200 6
```

Or run the recommended `c4` variant directly:

```bash
# To verify, benchmark orig vs c4 in a 5-run loop:
for v in orig c4; do
  for r in 1 2 3 4 5; do
    sed -e "s|\\./NUPLN_FILE|/home/nilg/Work/TrueAGI/pln-experimental/experimental/nupln/exp_nupln_traced_$v.metta|" \
        -e "s|N_VAL|2|" \
        -e "s|MKCONTROL|(MkControl 200 6)|" \
        /tmp/bench3.metta > /tmp/bench_inst.metta
    printf "$v run $r: "; { time ~/Work/TrueAGI/PeTTa/run.sh /tmp/bench_inst.metta > /dev/null 2>&1; } 2>&1 | grep real
  done
done
```
