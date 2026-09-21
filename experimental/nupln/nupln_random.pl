%% nupln_random.pl
%%
%% Minimal SWI-Prolog helper for nuPLN's random sampling. The only
%% things this module does are:
%%
%%   1. expose `nupln_uniform/2`, a referentially-transparent uniform
%%      sampler;
%%   2. expose `nupln_set_seed/1`, a thin wrapper around SWI's
%%      `set_random(seed(_))`.
%%
%% `nupln_uniform/2` draws one sample as follows:
%%
%%   1. hash the first argument with term_hash/2 (-> TermHash);
%%   2. capture the current global random state with getrand/1
%%      (-> OldState);
%%   3. mix the two together (term_hash(seed_combo(OldState,
%%      TermHash), Seed)) to produce the new seed;
%%   4. seed a fresh generator with that seed and draw a uniform
%%      float;
%%   5. restore the previous global random state with setrand/1.
%%
%% Step (3) is what makes the user-controllable bit of randomness
%% work: changing the global seed (e.g. via `set-random-seed!` from
%% MeTTa, or `set_random(seed(N))` directly from Prolog) changes
%% `OldState`, which changes the temporary seed, which changes the
%% sample. The `term_hash` step additionally guarantees that
%% different terms produce different seeds even when the global
%% state is identical.
%%
%% Step (5) makes every call referentially transparent: the global
%% state seen by the rest of the program is unchanged.

:- module(nupln_random, [nupln_uniform/2, nupln_set_seed/2]).

:- use_module(library(random)).

%% nupln_uniform(+Term, -R)
%%   R is a uniformly distributed float in [0.0, 1.0) drawn from a
%%   generator seeded with hash(OldState, term_hash(Term)). The
%%   previous global random state is preserved.
nupln_uniform(Term, R) :-
    term_hash(Term, TermHash),
    getrand(OldState),
    term_hash(seed_combo(OldState, TermHash), Seed),
    set_random(seed(Seed)),
    random(R),
    setrand(OldState).

%% nupln_set_seed(+N, -_)
%%   Re-seeds SWI's global random generator with the integer N and
%%   succeeds with a fresh output variable. The dummy second
%%   argument is needed so the predicate fits PeTTa's "function
%%   form" convention (last argument is the output), which lets it
%%   be registered via `import_prolog_function` and called from
%%   MeTTa as `(set-random-seed! N)`.
%%
%%   Useful for reproducible runs: after (set-random-seed! 42) the
%%   same sequence of `(bernoulli T P)` calls will produce the same
%%   sequence of booleans across runs.
nupln_set_seed(N, _) :- set_random(seed(N)).
