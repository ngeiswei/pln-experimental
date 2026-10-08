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
