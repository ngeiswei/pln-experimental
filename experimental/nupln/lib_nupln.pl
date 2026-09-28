%% lib_nupln.pl
%%
%% Custom predicates for nuPLN implemented in Prolog

:- module(lib_nupln, [nupln_uniform/2, nupln_set_seed/2]).

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
