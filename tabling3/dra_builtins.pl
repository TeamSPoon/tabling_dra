%%%%%  Built-in predicates for the "dra" interpreter  %%%%

%%% If the interpreted program invokes a built-in predicate, that predicate must
%%% be declared in the table "builtin/1" below.
%%% Every addition should be considered carefully: some built-ins might require
%%% special treatment by the interpreter.

%%  NOTE: findall/3 is not opaque to coinductive and tabled ancestors.

%%  NOTE: Just adding "!" won't do the trick, the main interpreter would
%%        have to be modified substantially (but first: what are the semantics?)
:-dynamic(builtin/4).
:-dynamic(builtin/1).

%builtin(_, ',',2          ).  % special treatment in solve/4
%builtin( (_ -> _)           ).  % special treatment in solve/4
%builtin( (_ -> _ ; _)       ).  % special treatment in solve/4
%builtin( (_ ; _)            ).  % special treatment in solve/4
%builtin( \+( _ )            ).  % special treatment in solve/4
%builtin( assert( _ )        ).  % special treatment in solve/4
%builtin( findall( _, _, _ ) ).  % special treatment in solve/4
%builtin( once( _ )          ).  % special treatment in solve/4
%builtin( retractall( _ )    ).  % special treatment in solve/4
builtin( _ < _              ).
builtin( _ = _              ).
builtin( _ =:= _            ).
builtin( _ =< _             ).
builtin( _ =\= _            ).
builtin( _ > _              ).
builtin( _ >= _             ).
builtin( _ \= _             ).
builtin( _ is _             ).
builtin( append( _, _, _ )  ).
builtin( atom( _ )          ).
builtin( call( _ )          ).
builtin( fail               ).
builtin( false              ).
builtin( length( _, _ )     ).
builtin( member( _, _ )     ).
builtin( nl                 ).
builtin( read( _ )          ).
builtin( set_flag( _, _ )   ).
builtin( sort( _, _ )       ).
builtin( true               ).
builtin( var( _ )           ).
builtin( write( _ )         ).
builtin( write_term( _, _ ) ).
builtin( writeln( _ )       ).
builtin( 'C'( _, _, _ )     ).  % for DCG's on some Prolog systems
builtin( set_print_depth( _ ) ).          % not a real built-in, see "top_level"

builtin(_, delete(_,_,_)  ,delete, 3).
builtin(_,G,F,A):- (var(G)->functor(G,F,A);true), builtin(G).
