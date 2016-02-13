p(a).
p(b).

q(1).
q(2).

q(X,Y) :- (p(X) -> p(Y); q(Y)).

?- q(a,Y).     % expected: a b
?- q(1,Y).     % expected: 1 2
