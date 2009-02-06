%%%                                                                          %%%
%%%  An interpreter for tabled logic programming with coinduction:           %%%
%%%  see the description below for more information.                         %%%
%%%  Written by Feliks Kluzniak at UTD (January-February 2009).              %%%
%%%                                                                          %%%
%%%  Last update: 6 February 2009.                                           %%%
%%%                                                                          %%%

%%% NOTE:
%%%
%%%    1. See ../general/top_level.ecl for a description of how to load
%%%       and run programs.
%%%
%%%    2. Tabled and coinductive predicates should be declared as such in
%%%       the program file, e.g.,
%%%           :- tabled      ancestor/2 .
%%%           :- coinductive comember/2 .
%%%
%%%       To include files use the usual Prolog syntax:
%%%           :- [ file1, file2, ... ].
%%%
%%%       To produce a wallpaper trace use the trace directive. For example,
%%%           :- trace p/3, q/0, r/1.
%%%       will trace predicates "p/3", "q/0" and "r/1".  If you want to trace
%%%       everything, use
%%%           :- trace all.
%%%       These directives are cumulative.
%%%
%%%    2. The program should contain no other directives. It may, however,
%%%       contain queries, which will be executed immediately upon reading.
%%%
%%%    3. If the program invokes a built-in predicate, that predicate must
%%%       be declared in the table "builtin/1" below.  Every addition should
%%%       be considered carefully: some might require special treatment by
%%%       the interpreter.
%%%
%%%    4. The program may contain clauses that modify the definition of the
%%%       interpreter's predicate "essence_hook/2" (the clauses will be asserted
%%%       at the front of the predicate, and will thus override the default
%%%       definition for some cases).  The default definition is
%%%
%%%          essence_hook( T, T ).
%%%
%%%       This predicate is invoked _in certain contexts_ when:
%%%          - two terms are about to be compared (either for equality or to
%%%            check whether they are variants of each other);
%%%          - an answer is tabled;
%%%          - an answer is retrieved from the table.
%%%
%%%       The primary intended use is to suppress arguments that carry only
%%%       administrative information and that may differ in two terms that are
%%%       "semantically" equal or variants of each other. (Such, for example, is
%%%       the argument that carries the set of coinductive hypotheses in a
%%%       co-logic program translated into Prolog: see
%%%       "../coind/translate_clp". Mind you, that translation need not be
%%%       applied to programs executed by this interpreter).
%%%
%%%       For example, the presence of
%%%
%%%          essence_hook( p( A, B, _ ),  p( A, B ) ).
%%%
%%%       will result in "p( a, b, c )" and "p( a, b, d )" being treated as
%%%       identical, as each of them will be translated to "p( a, b )" before
%%%       comparison.
%%%
%%%       NOTE: This facility should be used with the utmost caution, as it
%%%             may drastically affect the semantics of the interpreted program
%%%             in a fashion that would be hard to understand for someone who
%%%             does not understand the details of the interpreter.

%%% LIMITATIONS: - The interpreted program should not contain cuts.
%%%              - Error detection is quite rudimentary.


/*******************************************************************************

   General description
   -------------------

   A simple (and very inefficient) interpreter that attempts to emulate
   "top-down tabled programming", as described in

     [1] Hai-Feng Guo, Gopal Gupta:
         Tabled Logic Programming with Dynamic Ordering of Alternatives
         (17th ICLP, 2001)

   The terminology has been modified under the influence of

     [2] Neng-Fa Zhou, Taisuke Sato, Yi-Dong Shen:
         Linear Tabling Strategies and Optimizations
         (TPLP 2008 (?))

   More specifically, "masters" and "slaves" are called "pioneers" and
   "followers", respectively (although in a sense somewhat different than in
   [2]: we use "pioneer" for "topmost looping goal"), and "strongly
   connected components" are called "clusters".

   Note that "clusters" are detected dynamically, to achieve greater
   precision (a dependency graph among static calls can only be a rough
   approximation, a dependency graph among predicates is rougher still).


   Nomenclature
   ------------

   Some predicates are "tabled", because the user has declared them to be such
   by using an appropriate directive.  E.g.,

       :- tabled p/2 .

   All calls to a tabled predicate that are present in the interpreted program
   are called "tabled calls".  Instances of such calls are called "tabled
   goals".  In general, we will use the term "call" to refer to a static entity
   in the program, and "goal" to refer to an instance of a call.  We will also
   avoid the conventional overloading of the term "goal" in yet another way: we
   will call a sequence (i.e., conjunction) of goals just that (unless we can
   refer to it as a "query" or a "resolvent").

   Similarly, the user can declare a predicate to be "coinductive", by using
   another directive.  E.g.,

       :- coinductive p/2 .

   Calls and goals that refer to a coinductive predicate will also be called
   "coinductive".


   Limitations
   -----------

   The interpreted program must not contain cuts.  It also must not contain
   calls to built-in-predicates, except for the handful of predicates listed
   in builtin/1 below.  (This list can be easily extended as the need
   arises.  Some built-in predicates, however, cannot be added without
   modifying the interpreter, sometimes extensively: "!/0" is a good
   example.)


   Data structures
   ---------------

   The interpreter uses a number of tables that store information
   accumulated during a computation.  A computation consists in reading a
   program and executing a number of queries.  A query is a sequence (i.e.,
   conjunction) of goals.

   The tables (implemented as dynamic predicates of Prolog) are:

   -- coinductive( generic head )

           Contains an entry for each predicate that has been declared as
           coinductive.  For instance, when the interpreter reads
               :- coinductivve p/2 .
           it stores the fact
               coinductive( p( _, _ ) ).

   -- tabled( generic head )

           Contains an entry for each predicate that has been declared as
           tabled.  For instance, when the interpreter reads
               :- tabled p/2 .
           it stores the fact
               tabled( p( _, _ ) ).

   -- answer( goal, fact )

           Used to store results computed for tabled goals encountered
           during a computation.  Once present, these results are also used
           during further stages of the computation.

           Note that the fact is an instantiation of the goal.  If a tabled
           goal has no solutions, it will have no entry in "answer", even
           though it may have an entry in "completed" (see below).

           In general, a side-effect of each evaluation of a query will be
           the generation -- for each tabled goal encounted during the
           evaluation -- of a set of facts that form the goal's "least fixed
           point interpretation".  (Of course, if this set is not
           sufficiently small, the interpreter will not terminate
           successfully.)  The facts (which need not be ground!) are all
           entered into the table "answered", and the members of different
           sets are distinguished by their association with the appropriate
           goal: a fact in "answered" is a result that is valid only for a
           variant of the accompanying goal.

           The need for annotating a fact with information about the
           corresponding goal might not be immediately obvious.  Consider
           the following example (which is simplistic in that the
           computation itself is trivial):

               program:  :- tabled p/2.
                         p( A, A ).
                         p( a, b ).

               queries:  ?-  p( U, V ).
                         ?-  p( Y, b ).

           During "normal" execution of this Prolog program each of the
           queries would generate a different set of results; to wit:

               p( U, V )  would generate  p( U, U ), p( a, b );
               p( Y, b )  ..............  p( b, b ), p( a, b ).

           In other words, the set of results depends not only on the
           predicate, but also on the form of the goal.

           If these results were tabled without the corresponding goals,
           then the table would be:

               answer( p( U, U ) ).
               answer( p( a, b ) ).
               answer( p( b, b ) ).

           A subsequent invocation of p( U, V ) would then return all three
           results, i.e., also "p( b, b )"!

           The proper contents of "answer" would be as follows (though not
           necessarily in this order):

               answer( p( U, V ), p( U, U ) ).
               answer( p( U, V ), p( a, b ) ).
               answer( p( Y, b ), p( b, b ) ).
               answer( p( Y, b ), p( a, b ) ).

           Please note that entries in "answer" will not be variants of each
           other.

   -- number_of_answers

           This is a non-logical variable that records the size of "answer".
           It is used for determining whether new answers have been
           generated during a phase of the computation.

   -- pioneer( goal, index )

           If the current goal is tabled, and it is not a variant of any of
           its ancestors, then the goal is called a "pioneer" and recorded
           in this table.  (An unique index is also stored, to facilitate
           later removal of this entry and to tag other information related
           to the pioneer---see below.)  If a variant goal is encountered
           subsequently, it will be treated as a "follower".  The table is
           used to detect whether a tabled goal (when first encountered) is
           a pioneer or a follower.

           If a pioneer is determined not to be the "topmost looping goal"
           in a "cluster" of interdependent goals (see ref. [2]), then it
           loses the status of a pioneer, and its role will be overtaken by
           the topmost goal in the cluster.  The role of a pioneer is to
           compute the fixpoint (by tabling answers) for itself and its
           cluster before failing: this is why the results for followers can
           be obtained by querying "answer", without using their clauses
           (which prevents endless recursion).

           No two entries in "pioneer" are variants of each other (even when
           we disregard the index).

           This table is cleared before the evaluation of a new query and
           when the pioneer finally becomes complete.

   -- pioneer_index

           This is a non-logical variable that holds the index to be used for
           the next entry in "pioneer".

           The variable is cleared before the evaluation of a new query.

   -- loop( index, list of goals )

           A loop is discovered when the current tabled goal is a variant of
           one of its ancestors.  If the ancestor is a pioneer, the unique
           index of the pioneer ancestor and a list of the tabled goals
           between the pioneer and the variant are stored in "loop".

           A number of "loop" entries may exist for a given pioneer:
           together, they describe a "cluster" (i.e., a "strongly connected
           component", see ref. [1]).  Before finally failing upon
           backtracking, a pioneer will compute its own fixpoint as well as
           the fixpoints of the goals in its cluster.  When a goal loses its
           pioneer status (because it is determined to be a part of a larger
           loop), the associated entries in "loop" are removed.

           This table is cleared before the evaluation of a new query and
           when the pioneer finally becomes complete.

   -- looping_alternative( index, clause )

           When a goal is determined to be a follower of a pioneer, the
           clause that is currently being used by the pioneer (i.e., the
           clause that led to the follower) is stored in this table,
           together with the unique index of the pioneer.  The clause will
           be used again as backtracking brings the computation back to the
           pioneer.

           This table is cleared before the evaluation of a new query and
           when the pioneer finally becomes complete.

   -- completed( goal )

           Indicates that this tabled goal is complete, i.e., its fixpoint
           has been computed, and all the possible results for variants of
           the goal can be found in table "answer".

           This table is cleared before the evaluation of a new query.

   -- tracing( goal )

           A goal that matches something in this table will show up on the
           wallpaper trace.  This table is empty by default, and filled only
           upon encountering "trace" directives when the interpreted program
           is being read.

*******************************************************************************/


:- ensure_loaded( [ '../general/top_level',
                    '../general/utilities'
                  ]
                ).




% If a file name has no extension, add ".ctp"

default_extension( ".ctp" ).


%% Initialization of tables:

:- dynamic coinductive/1 .
:- dynamic tabled/1 .
:- dynamic answer/2 .
:- dynamic pioneer/2 .
:- dynamic loop/2 .
:- dynamic looping_alternative/3 .
:- dynamic completed/1 .
:- dynamic tracing/1.

:- setval( number_of_answers, 0 ).
:- setval( pioneer_index,     0 ).

initialise :-
        retractall( tabled( _ )                    ),
        retractall( answer( _, _ )                 ),
        retractall( pioneer( _, _ )                ),
        retractall( loop( _, _ )                   ),
        retractall( looping_alternative( _, _, _ ) ),
        retractall( completed( _ )                 ),
        retractall( tracing( _ )                   ),
        setval( number_of_answers, 0 ),
        setval( pioneer_index,     0 ).



%%%%%  Built-in predicates  %%%%
%%
%%  NOTE: Just adding "!" won't do the trick, the main interpreter would
%%        have to be modified substantially.
%%        Certain other built-ins may also require special treatment.

builtin( true               ).
builtin( false              ).
builtin( fail               ).
builtin( \+( _ )            ).  % special treatment in solve/3
builtin( once( _ )          ).  % special treatment in solve/3
builtin( (_ -> _ ; _)       ).  % special treatment in solve/3
builtin( (_ ; _)            ).  % special treatment in solve/3
builtin( (_ , _)            ).  % special treatment in solve/3
builtin( _ = _              ).
builtin( _ \= _             ).
builtin( _ > _              ).
builtin( _ >= _             ).
builtin( _ =< _             ).
builtin( _ < _              ).
builtin( _ is _             ).
builtin( atom( _ )          ).
builtin( var( _ )           ).
builtin( write( _ )         ).
builtin( writeln( _ )       ).
builtin( write_term( _, _ ) ).
builtin( nl                 ).
builtin( read( _ )          ).
builtin( set_flag( _, _ )   ).
builtin( member( _, _ )     ).
builtin( assert( _ )        ).
builtin( retractall( _ )    ).
builtin( set_print_depth( _, _ )   ).      % not a real built-in, see  top_level



%%%%  Hooks

%% Declarations of hook predicates (for the top level):

hook_predicate( essence_hook( _, _ ) ).


%% The default essence_hook:

:- dynamic   essence_hook/2.

essence_hook( T, T ).    % default, may be overridden by the interpreted program




%%%%%  Administration  %%%%%

:- op( 1000, fy, tabled ).    % allow  ":- tabled p/k ."
:- op( 1000, fy, trace  ).    % allow  ":- trace  p/k ."



%% The legal directives (check external form only).  (Used by the top level.)

legal_directive( tabled _ ).
legal_directive( (trace _) ).
legal_directive( (dynamic _) ).


%% Check and process the legal directives

execute_directive( tabled P / K ) :-                  % declaration of tabled
        (atom( P ), integer( K ), K >= 0),            %  seems OK
        !,
        mk_pattern( P, K, Pattern ),                  % Pattern = P( _, _, ... )
        assert( tabled( Pattern ) ).

execute_directive( tabled P / K ) :-                  % declaration of tabled
        (\+ atom( P ) ; \+ integer( K ) ; K < 0),     %  obviously wrong
        !,
        warning( [ "Erroneous directive: \"",
                   (:- tabled P / K),
                   "\" ignored! +++"
                 ]
               ).

execute_directive( (trace all) ) :-
        !,
        will_trace( [ _ ] ).

execute_directive( (trace PredSpecs) ) :-
        predspecs_to_patterns( PredSpecs, Patterns ),
        will_trace( Patterns ).

execute_directive( (dynamic PredSpecs) ) :-
        (dynamic PredSpecs)@interpreted.


%% will_trace( + list of patterns ):
%% Store the patterns in tracing/1:

will_trace( Patterns ) :-
        member( Pattern, Patterns ),
        assert( tracing( Pattern ) ),
        assert( tracing( Pattern ) ),
        fail.

will_trace( _ ).





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%  The interpreter  %%%%%


%% Execute a query.

:- mode query( + ).

query( Goals ) :-
        retractall( pioneer( _, _ )                ),
        retractall( loop( _, _ )                   ),
        retractall( looping_alternative( _, _, _ ) ),
        retractall( completed( _ )                 ),

        solve( Goals, [], 0 ).




%% solve( + sequence of goals, + stack, + level ):
%% Solve the sequence of goals, maintaining information about the current chain
%% of ancestors (stack).  The level is the level of recursion, and is used only
%% for tracing.

:- mode solve( +, +, + ).


% Note that even during the computation of \+/1 a whole set of answers
% may become tabled.

solve( \+ Goal, Stack, Level ) :-
        !,
        NLevel is Level + 1,
        optional_trace( 'Entering normal: ', \+ Goal, Level ),
        (
            \+ solve( Goal, Stack, NLevel ),
            optional_trace( 'Success normal: ', \+ Goal, Level )
        ;
            optional_trace( 'Failure normal: ', \+ Goal, Level ),
            fail
        ).


% Note that even during the computation of once/1 a whole set of answers
% may become tabled.

solve( once( Goal ), Stack, Level ) :-
        !,
        NLevel is Level + 1,
        optional_trace( 'Entering normal: ', once( Goal ), Level ),
        (
            once( solve( Goal, Stack, NLevel ) ),
            optional_trace( 'Success normal: ', once( Goal ), Level )
        ;
            optional_trace( 'Failure normal: ', once( Goal ), Level ),
            fail
        ).


% A conditional.

solve( (Cond -> Then ; _Else), Stack, Level ) :-
        solve( Cond, Stack, Level ),
        !,
        solve( Then, Stack, Level ).

solve( (_Cond -> _Then ; Else), Stack, Level ) :-
        !,
        solve( Else, Stack, Level ).


% A disjunction without a conditional.

solve( (Goals ; _), Stack, Level ) :-
        solve( Goals, Stack, Level ).

solve( (_ ; Goals), Stack, Level ) :-
        !,
        solve( Goals, Stack, Level ).


% A conjunction.

solve( (Goals1 , Goals2), Stack, Level ) :-
        !,
        solve( Goals1, Stack, Level ),
        solve( Goals2, Stack, Level ).


% assert

solve( assert( Clause ), _, _ ) :-
        !,
        (
            \+ is_good_clause( Clause )
        ->
            error( [ "Bad clause argument: ", assert( Clause ) ] )
        ;
            true
        ),
        assert( Clause )@interpreted.


% retractall

solve( retractall( C ), _, _ ) :-
        !,
        retractall( C )@interpreted.


% Some other supported built-in.

solve( BuiltIn, _, _ ) :-
        builtin( BuiltIn ),
        !,
        call( BuiltIn ).


% A "normal" (i.e., not tabled) goal.

solve( Goal, Stack, Level ) :-
        \+ tabled( Goal ),
        !,
        optional_trace( 'Entering normal: ', Goal, Level ),
        (
            solve_by_rules( Goal, Stack, Level ),
            optional_trace( 'Success normal: ', Goal, Level )
        ;
            optional_trace( 'Failure normal: ', Goal, Level ),
            fail
        ).



% A tabled goal that has been completed: all the results are in "answer".

solve( Goal, _, Level ) :-
        is_completed( Goal ),
        !,
        optional_trace( 'Entering completed: ', Goal, Level ),
        (
            get_answer( Goal ),
            optional_trace( 'Success completed: ', Goal, Level )
        ;
            optional_trace( 'Failure completed: ', Goal, Level ),
            fail
        ).


% A tabled goal that has a variant among its ancestors.
% See the comment to variant_of_ancestor for a more detailed description of
% the actions taken.
% Only the existing (most likely incomplete) results from "answer" are
% returned before failure.

solve( Goal, Stack, Level ) :-
        variant_of_ancestor( Goal, Stack ),
        !,
        optional_trace( 'Entering variant: ', Goal, Level ),
        (
            get_answer( Goal ),
            optional_trace( 'Success variant: ', Goal, Level )
        ;
            optional_trace( 'Failure variant: ', Goal, Level ),
            fail
        ).


% A pioneer goal is solved by rules, producing results that are stored in
% "answer": after this is done, "answer" is used to pass on the results.
%
% Moreover, the goal's answer set is extended to the least fixed point and its
% cluster is marked as complete.  The auxiliary information about the pioneer
% is removed.
%
% (Note that a pioneer but may cease to be one when some descendant goal finds
%  a variant ancestor that is also an ancestor of the pioneer.
%  See variant_of_ancestor/2.)

solve( Goal, Stack, Level ) :-
        \+ is_a_variant_of_a_pioneer( Goal, _ ),
        !,
        add_pioneer( Goal, Index ),
        optional_trace( 'Added pioneer: ', Goal, Level ),
        store_all_solutions_by_rules( Goal, Stack, Level ),
        (
            pioneer( _, Index )                    % might have lost its status!
        ->
            compute_fixed_point( Goal, Stack, Level ),
            complete_goal( Goal ),
            complete_cluster( Index ),
            remove_pioneer( Index ),
            remove_loops( Index )
        ;
            true
        ),
        get_answer( Goal ).


% A tabled goal that is not completed, not a pioneer on entry, and has no
% variant among its ancestors.  Something is wrong!

solve( Goal, Stack, _ ) :-
        fatal_error( "IMPOSSIBLE!", [ Goal | Stack ] ).




%% store_all_solutions_by_rules( + goal, + stack, + level ):
%% Invoke solve_by_rules/2 until there are no solutions left, storing
%% the results in "answer".

:- mode store_all_solutions_by_rules( +, +, + ).

store_all_solutions_by_rules( Goal, Stack, Level ) :-
        copy_term( Goal, OriginalGoal ),
        solve_by_rules( Goal, Stack, Level ),
        memo( OriginalGoal, Goal ),
        fail.

store_all_solutions_by_rules( _, _, _ ).



%% solve_by_rules( + goal, + stack, + level ):
%% Solves the goal by using rules (i.e., clauses) only.

:- mode solve_by_rules( +, +, + ).

solve_by_rules( Goal, Stack, Level ) :-
        copy_term( Goal, OriginalGoal ),
        NLevel is Level + 1,
        use_clause( Goal, Body ),
        solve( Body, [ OriginalGoal | Stack ], NLevel ).

%
use_clause( Goal, Body ) :-
        (
            functor( Goal, P, K ),
            current_predicate( P/K )@interpreted
        ->
            clause( Goal, Body )@interpreted
        ;
            warning( [ "Calling an undefined predicate: \"", Goal, "\"" ] ),
            fail
        ).





%% compute_fixed_point( + goal, + stack, + level ):
%% Solve the goal by rules until no more answers are produced, then succeed
%% _without_ instantiating the goal.

:- mode compute_fixed_point( +, +, + ).

compute_fixed_point( Goal, Stack, Level ) :-
        optional_trace( 'Computing fixed point for ', Goal, Level ),
        getval( number_of_answers, NAns ),
        compute_fixed_point_( Goal, Stack, Level, NAns ).

%
:- mode compute_fixed_point_( +, +, +, + ).

compute_fixed_point_( Goal, Stack, Level, _ ) :-
        store_all_solutions_by_rules( Goal, Stack, Level ),     % all solutions
        fail.

compute_fixed_point_( _, _, _, NAns ) :-
        getval( number_of_answers, NAns ),                      % no new answers
        !.

compute_fixed_point_( Goal, Stack, Level, NAns ) :-
        getval( number_of_answers, NA ),
        NA =\= NAns,                                            % new answers,
        compute_fixed_point_( Goal, Stack, Level, NA ).         %   so iterate



%% variant_of_ancestor( + goal, + list of goals ):
%% Succeeds if the goal is a variant of some member of the list.
%%
%% SIDE EFFECT: If successful, then intermediate pioneer goals will lose their
%%              status as pioneers, and the associated entries in "loop" will
%%              be removed.  Moreover, if the variant ancestor is a pioneer,
%%              the entire prefix of the list upto (and including) the variant
%%              ancestor will be added to the cluster of that ancestor (by
%%              storing it in "loop"), after filtering out goals that are not
%%              tabled.

:- mode variant_of_ancestor( +, + ).

variant_of_ancestor( Goal, List ) :-
        append( Prefix, [ G | _ ], List ),                % i.e., split the list
        are_essences_variants( Goal, G ),
        !,
        keep_tabled_goals( Prefix, TabledPrefix ),
        (
            member( M, TabledPrefix ),
            rescind_pioneer_status( M ),
            fail
        ;
            true
        ),
        (
            is_a_variant_of_a_pioneer( G, Index )
        ->
            add_loop( Index, TabledPrefix )
        ;
            true
        ).


%% keep_tabled_goals( + list of goals, - list of goals ):
%% Filter away goals that are not tabled.

:- mode keep_tabled_goals( +, - ).

keep_tabled_goals( [], [] ).

keep_tabled_goals( [ G | Gs ], [ G | TGs ] ) :-
        tabled( G ),
        !,
        keep_tabled_goals( Gs, TGs ).

keep_tabled_goals( [ _G | Gs ], TGs ) :-
        % \+ tabled( G ),
        keep_tabled_goals( Gs, TGs ).


%% rescind_pioneer_status( + goal ):
%% If the goal is tabled in "pioneer", remove the entry and the associated
%% cluster (i.e., entries in "loop").

:- mode rescind_pioneer_status( + ).

rescind_pioneer_status( Goal ) :-
        is_a_variant_of_a_pioneer( Goal, Index ),
        !,
        optional_trace( 'Removing pioneer: ', Goal, '?' ),
        remove_pioneer( Index ),
        remove_loops( Index ).

rescind_pioneer_status( _ ).


%% complete_cluster( + index of a pioneer goal ):
%% If the goal has an associated cluster, make sure all the goals in the cluster
%% are marked as complete.
%% Recall that a cluster may consist of a number of "loops".

:- mode complete_cluster( + ).

complete_cluster( Index ) :-
        loop( Index, Gs ),                     % iterate over loops
        member( G, Gs ),                       % iterate over members of a loop
        complete_goal( G ),
        fail.

complete_cluster( _ ).





%%-----  The tables: access and modification  -----


%% memo( + goal, + fact ):
%% If the table "answer" does not contain a variant of this fact paired with
%% a variant of this goal, then add the pair to the table, increasing
%% "number_of_answers".

:- mode memo( +, + ).

memo( Goal, Fact ) :-
        answer( G, F ),
        are_essences_variants( F, Fact ),
        are_essences_variants( G, Goal ),
        !.

memo( Goal, Fact ) :-
        % No variant pair in "answer",
        optional_trace( 'Storing answer: ', Fact, '?' ),
        assert( answer( Goal, Fact ) ),
        incval( number_of_answers ).



%% get_answer( +- goal ):
%% Get an instantiation (if any) tabled in "answer" for variants of this goal.
%% Sequence through all such instantiations on backtracking.

:- mode get_answer( ? ).

get_answer( Goal ) :-
        answer( G, Ans ),
        once essence_hook( Goal, EssenceOfGoal ),
        once essence_hook( G,    EssenceOfG    ),
        are_variants( EssenceOfGoal, EssenceOfG ),
        EssenceOfGoal = EssenceOfG,    % make sure variables are the right ones
        once essence_hook( Ans, EssenceOfAns ),
        EssenceOfGoal = EssenceOfAns . % instantiate



%% complete_goal( + goal ):
%% Make sure the goal is marked as completed.

:- mode complete_goal( + ).

complete_goal( Goal ) :-
        is_completed( Goal ),
        !.

complete_goal( Goal ) :-
        % \+ is_completed( Goal ),
        optional_trace( 'Completing: ', Goal, '?' ),
        assert( completed( Goal ) ).



%% is_completed( + goal ):
%% Succeeds iff the goal is a variant of a goal that has been stored in
%% the table "completed".

:- mode is_completed( + ).

is_completed( Goal ) :-
        completed( G ),
        are_essences_variants( Goal, G ).



%% is_a_variant_of_a_pioneer( + goal, -index ):
%% Succeeds if the goal is a variant of another goal that is tabled in
%% "pioneer"; returns the index of the relevant entry in table "pioneer".

:- mode is_a_variant_of_a_pioneer( +, - ).

is_a_variant_of_a_pioneer( Goal, Index ) :-
        pioneer( PG, Index ),
        are_essences_variants( Goal, PG ).



%% add_pioneer( + goal, - index ):
%% Add an entry for this goal to "pioneer", return the unique index.

:- mode add_pioneer( +, - ).

add_pioneer( Goal, NewIndex ) :-
        getval( pioneer_index, NewIndex ),
        incval( pioneer_index ),
        assert( pioneer( Goal, NewIndex ) ).



%% remove_pioneer( + index ):
%% Remove the pioneer entry with this index.

:- mode remove_pioneer( + ).

remove_pioneer( Index ) :-
        retract( pioneer( _, Index ) ).



%% add_loop( + index, + list of goals ):
%% Add an entry to "loop".

:- mode add_loop( +, + ).

add_loop( _, [] ) :-                                % empty loops are not stored
        !.

add_loop( Index, Goals ) :-
        assert( loop( Index, Goals ) ).



%% remove_loops( + index ):
%% Remove all the entries in "loop" that have this index.

:- mode remove_loops( + ).

remove_loops( Index ) :-
        retractall( loop( Index, _ ) ).





%%-----  Custom-tailored utilities  -----


%% are_essences_variants( + term, + term ):
%% Are both the terms variants of each other after filtering through
%% essence_hook?

are_essences_variants( T1, T2 ) :-
        once essence_hook( T1, ET1 ),
        once essence_hook( T2, ET2 ),
        are_variants( ET1, ET2 ).


%% optional_trace( + label, + goal, + level ):
%% If the goal matches one of the traced patterns, print out a trace line with
%% this label:

optional_trace( Label, Goal, Level ) :-
        tracing( Goal ),
        !,
        write( output, '[' ),
        write( output, Level ),
        write( output, '] ' ),
        write( output, Label ),
        write( output, Goal ),
        nl( output ).

optional_trace( _, _, _ ).



%% fatal_error( + message, + stack ):
%% Display the message and stack, then abort.

:- mode fatal_error( +, + ).

fatal_error( Message, Stack ) :-
        begin_error,
        writeln(    error, Message ),
        writeln(    error, "" ),
        writeln(    error, "*** The current stack:" ),
        show_stack( error, Stack ),
        end_error.

%
show_stack( Stream, Stack ) :-
        member( Call, Stack ),
        writeln( Stream, Call ),
        fail.

show_stack( _ ).
