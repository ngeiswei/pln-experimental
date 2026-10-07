# nuPLN

PoC of νPLN.

## Probabilistic Programming Language

νPLN starts with the definition of a probabilistic programming
language.  For now we start with a language with no variable like
[Predicate Functor Logic)(https://en.wikipedia.org/wiki/Predicate_functor_logic)
enriched with random sampling functions.

## Inference Control

The general idea of inference control is to modulate the recursive
calls of the backward chainer.  The ultimate control is when
absolutely everything that has an impact on the recursive calls is
being modulated.  To realize that we suggest the following approach,
best illustrated with some pseudo MeTTa code:

```metta
(: bc (-> Control   ; Control structure
          $a        ; Query
          $a)       ; Fulfilled query
(= (bc $ctl (: ($f $x) $b))
   ;; Entry gate
   (if ((Control.EntryGate $ctl) (: ($f $x) $b))
       ;; Gate is on, can go on with recursion
       (let* (;; Update backward chainer and control for first premise
              ((, $bc0 $ctl0) ((Control.Update $ctl) (: ($f $x) $b) 0))
              ;; Recursive call on first premise (and get post control)
              ((, $pctl0 (: $f (-> $a $b))) ($bc0 $ctl0 (: $f (-> $a $b))))
              ;; Update backward chainer and control for second premise
              ((, $bc1 $ctl1) ((Control.Update $pctl0) (: ($f $x) $b) 1))
              ;; Recursive call on second premise (and get post control)
              ((, $pctl1 (: $x $a)) ($bc1 $ctl1 (: $x $a))))
          ;; Exit gate
          (if ((Control.ExitGate $pctl1) (: ($f $x) $b))
              (, $pctl1 (: ($f $x) $b))
              (empty)))
    (empty)))
```

where

- Control.EntryGate: takes a control object and outputs a predicate on
  the query, indicating whether to enter the call.
- Control.Update: takes a control object and outputs a function on the
  query, the premise index and outputs a pair containing the new
  backward chainer to be called on the premise of that index alongside
  its control structure.
- Control.ExistGate: takes a control object and outputs a predicate on
  the result, indicating whether not to prune the result.

Note the absence of budget and knowledge bases, this can be part of
the control structure.  In fact this could also be part of the updated
backward chainer.

Updating the backward chainer can be a bit constraining
programmatically speaking, although MeTTa certainly allows it, but one
can move the update to the control structure and leave the backward
chainer unchanged.  In this case the code simplifies to:

```metta
(: bc (-> Control   ; Control structure
          $a        ; Query
          $a)       ; Fulfilled query
(= (bc $ctl (: ($f $x) $b))
   ;; Entry gate
   (if ((Control.EntryGate $ctl) (: ($f $x) $b))
       ;; Gate is on, can go on with recursion
       (let* (;; Update backward chainer and control for first premise
              ($ctl0 ((Control.Update $ctl) (: ($f $x) $b) 0))
              ;; Recursive call on first premise (and get post control)
              ((, $pctl0 (: $f (-> $a $b))) (bc $ctl0 (: $f (-> $a $b))))
              ;; Update backward chainer and control for second premise
              ($ctl1 ((Control.Update $pctl0) (: ($f $x) $b) 1))
              ;; Recursive call on second premise (and get post control)
              ((, $pctl1 (: $x $a)) (bc $ctl1 (: $x $a))))
          ;; Exit gate
          (if ((Control.ExitGate $pctl1) (: ($f $x) $b))
              (, $pctl1 (: ($f $x) $b))
              (empty)))
    (empty)))
```

## Tags

nuPLN versions organized in git tags.

- nupln-v0.1:
  - Specialized backward chainer for nuPLN.
  - Only boolean truth values.
  - Hardcoded reduction gates so that only candidates in normal form
    can be synthesized.
  - No inference control beside proof size and depth budgets.
  - Tests on even parity (borrowed from MOSES).
