/*-------------------------------------------------------------------------*/
/* Benchmark (Finite Domain)            INRIA Rocquencourt - ChLoE Project */
/*                                                                         */
/* Name           : alpha.pl                                               */
/* Title          : alphacipher                                            */
/* Original Source: Daniel Diaz - INRIA France                             */
/* Adapted by     :                                                        */
/* Date           : January 1993                                           */
/*                                                                         */
/* This problem comes from the news group rec.puzzle.                      */
/* The numbers 1 - 26 have been randomly assigned to the letters of the    */
/* alphabet. The numbers beside each word are the total of the values      */
/* assigned to the letters in the word. e.g for LYRE L,Y,R,E might equal   */
/* 5,9,20 and 13 respectively or any other combination that add up to 47.  */
/* Find the value of each letter under the equations:                      */
/*                                                                         */
/*    BALLET  45     GLEE  66     POLKA      59     SONG     61            */
/*    CELLO   43     JAZZ  58     QUARTET    50     SOPRANO  82            */
/*    CONCERT 74     LYRE  47     SAXOPHONE 134     THEME    72            */
/*    FLUTE   30     OBOE  53     SCALE      51     VIOLIN  100            */
/*    FUGUE   50     OPERA 65     SOLO       37     WALTZ    34            */
/*                                                                         */
/* Solution:                                                               */
/*  [A, B,C, D, E,F, G, H, I, J, K,L,M, N, O, P,Q, R, S,T,U, V,W, X, Y, Z] */
/*  [5,13,9,16,20,4,24,21,25,17,23,2,8,12,10,19,7,11,15,3,1,26,6,22,14,18] */
/*-------------------------------------------------------------------------*/

go:-	
    statistics(runtime,_),
    top,
    statistics(runtime,[_,Y]), 
    write('time : '), write(Y), nl.

top:-
    alpha(LD).
%    write(LD), nl.

alpha(LD):-
	LD=[A,B,C,_D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z],
	domain(LD,1,26),

	alldifferent(LD),
    
	B+A+L+L+E+T       #= 45,
	C+E+L+L+O         #= 43,
	C+O+N+C+E+R+T     #= 74,
	F+L+U+T+E         #= 30,
	F+U+G+U+E         #= 50,
	G+L+E+E           #= 66,
	J+A+Z+Z           #= 58,
	L+Y+R+E           #= 47,
	O+B+O+E           #= 53,
	O+P+E+R+A         #= 65,
	P+O+L+K+A         #= 59,
	Q+U+A+R+T+E+T     #= 50,
	S+A+X+O+P+H+O+N+E #= 134,
	S+C+A+L+E         #= 51,
	S+O+L+O           #= 37,
	S+O+N+G           #= 61,
	S+O+P+R+A+N+O     #= 82,
	T+H+E+M+E         #= 72,
	V+I+O+L+I+N       #= 100,
	W+A+L+T+Z         #= 34,

	labeling(LD).


excludable(L):-b_EXCLUDABLE_LIST_c(L).
