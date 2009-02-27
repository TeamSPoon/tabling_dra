%%%                                                                          %%%
%%%  Check the consistency of the loaded program.                            %%%
%%%  An auxiliary of top_level.                                              %%%
%%%                                                                          %%%
%%%  Written by Feliks Kluzniak at UTD (January 2009).                       %%%
%%%                                                                          %%%
%%%  Last update: 20 February 2009.                                          %%%
%%%                                                                          %%%


:- ensure_loaded( utilities ).
:- ensure_loaded( open_set_in_tree ).



%% The following things are being checked:
%%  - is there a call to an undefined predicate?
%%  - is there a defined predicate that is not called and not declared as top?
%%  - is there a predicate that was declared as top, but not defined?
%%  - is there a predicate that was declared as support, but not defined?

check_general_consistency :-
        findall( PredSpec,
                 ( current_predicate_in_module( interpreted, PredSpec )
                 , predspec_to_pattern( PredSpec, Pattern )
                 , \+ builtin( Pattern )
                 ),
                 ListOfDefined
               ),
        findall( PredSpec,
                 current_predicate_in_module( support, PredSpec ),
                 ListOfDefinedSupport
               ),
        findall( P/K
               , ( top( Pattern )
                 , functor( Pattern, P, K )
                 )
               , ListOfDeclaredTop
               ),
        findall( P/K
               , ( support( Pattern )
                 , functor( Pattern, P, K )
                 )
               , ListOfDeclaredSupport
               ),

        list_to_oset( ListOfDefined        , OSetOfDefined         ),
        list_to_oset( ListOfDeclaredSupport, OSetOfDeclaredSupport ),
        list_to_oset( ListOfDefinedSupport , OSetOfDefinedSupport  ),
        list_to_oset( ListOfDeclaredTop    , OSetOfDeclaredTop     ),

        oset_difference( OSetOfDeclaredTop, OSetOfDefined, OSetOfUndefinedTop ),
        oset_difference( OSetOfDeclaredSupport, OSetOfDefinedSupport,
                         OSetOfUndefinedSupport
                       ),
        declared_undefined_warnings( OSetOfUndefinedTop    , top     ),
        declared_undefined_warnings( OSetOfUndefinedSupport, support ),

        oset_intersection( OSetOfDefinedSupport, OSetOfDeclaredSupport,
                           OSetOfCallableSupport
                         ),
        oset_union( OSetOfDefined, OSetOfCallableSupport, OSetOfAllDefined ),

        get_called_predicates( OSetOfDefined, OSetOfAllDefined, OSetOfCalled ),
        oset_difference( OSetOfDefined, OSetOfCalled, OSetOfDefinedUncalled ),
        oset_difference( OSetOfDefinedUncalled, OSetOfDeclaredTop,
                         OSetOfUncalled
                       ),
        uncalled_warnings( OSetOfUncalled ).


%
declared_undefined_warnings( OSetOfPredSpecs, KindOfDeclaration ) :-
        generate_member_of_oset( OSetOfPredSpecs, PredSpec ),
        warning( [ 'Predicate ', PredSpec,
                   ' declared as \"', KindOfDeclaration, '\" but not defined'
                 ]
               ),
        fail.

declared_undefined_warnings( _, _ ).


%
uncalled_warnings( OSetOfPredSpecs ) :-
        generate_member_of_oset( OSetOfPredSpecs, PredSpec ),
        warning( [ 'Predicate ', PredSpec, ' defined but not called' ] ),
        fail.

uncalled_warnings( _ ).



%% get_called_predicates( + open set of predicates,
%%                        + open set of all defined predicates,
%%                        - open set of predicates called from the defined ones
%%                      ):
%% Produce the set of predicates called from the first set, at the same time
%% producing warnings about calls to predicates that are not in the second set.

get_called_predicates( OSetOfPredicates, OSetOfDefined, OSetOfCalled ) :-
        sets_of_called( OSetOfPredicates, OSetOfDefined, ListOfSetsOfCalled ),
        empty_oset( Empty ),
        fold( oset_union, Empty, ListOfSetsOfCalled, OSetOfCalled ).

%
sets_of_called( OsetOfPredicates, OSetOfDefined, ListOfSetsOfCalled ) :-
        oset_to_list( OsetOfPredicates, ListOfPredicates ),
        map( [ set_of_called, OSetOfDefined ],
             ListOfPredicates, ListOfSetsOfCalled
           ).

%
set_of_called( OSetOfDefined, PredSpec, OSetOfCalled ) :-
        predspec_to_pattern( PredSpec, Pattern ),
        findall( OSetOfCalled
               , ( clause_in_module( interpreted, Pattern, Body )
                 , extract_called( Body, OSetOfCalled )
                 )
               , OSetsOfCalled
               ),
        empty_oset( Empty ),
        fold( oset_union, Empty, OSetsOfCalled, OSetOfCalled ),
        oset_difference( OSetOfCalled, OSetOfDefined, OSetOfCallsToUndefined ),
        warnings_about_called( OSetOfCallsToUndefined, PredSpec ).

%
warnings_about_called( OSetOfPredSpecsBad, ParentPredSpec ) :-
        generate_member_of_oset( OSetOfPredSpecsBad, PredSpecBad ),
        predspec_to_pattern( PredSpecBad, Pattern ),
        \+ builtin( Pattern ),
        warning( [ 'Undefined predicate ', PredSpecBad,
                   ' called from ', ParentPredSpec
                 ]
               ),
        fail.

warnings_about_called( _, _ ).


%% extract_called( + clause body, - open set of called predicates ):
%% Extract the list of predicates called by this body, except for predicates
%% declared as builtin.

extract_called( Binary, OSetOfCalled ) :-
        ( Binary = ( A ; B )
        ; Binary = ( A , B )
        ; Binary = ( A -> B )
        ),
        !,
        extract_called( A, OSetOfCalledA ),
        extract_called( B, OSetOfCalledB ),
        oset_union( OSetOfCalledA, OSetOfCalledB, OSetOfCalled ).

extract_called( Unary, OSetOfCalled ) :-
        ( Unary = (\+ A)
        ; Unary = once( A )
        ; Unary = call( A )
        ),
        !,
        extract_called( A, OSetOfCalled ).

extract_called( Predicate, OSetOfCalled ) :-
        callable( Predicate ),
        !,
        functor( Predicate, P, K ),
        empty_oset( OSetOfCalled ),
        add_to_oset( P/K, OSetOfCalled ).

extract_called( _, Empty ) :-
        empty_oset( Empty ).
