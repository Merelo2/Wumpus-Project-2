:- dynamic ([visited/1,
             breeze/1,
             stench/1,
             glitter/1,
             moved/2,
             wumpus_location/1,
             pit_location/1,
             gold_location/1,
             agent_location/1,
             time/1,
             score/1,
              wumpus_final/1]).


%AdjacentTo predicate returns true if a room A is adjacent to room B

adjacentTo([X,Y],L) :- Xr is X+1, L=[Xr,Y].
adjacentTo([X,Y],L) :- Xl is X-1, L=[Xl,Y].
adjacentTo([X,Y],L) :- Yt is Y+1, L=[X,Yt].
adjacentTo([X,Y],L) :- Yb is Y-1, L=[X,Yb].

%----------------------------------------------------------------------------

%Limit returns false if a room is within limits and true if it is out of bounds

limit([X,Y]) :- X<1; X>4; Y<1; Y>4.

%----------------------------------------------------------------------------

%Perceive predicate asserts to the KB the state of the room that is being visited. It uses the world parameters to check whether a room needs to be stenchy and/or breezy.
%It also uses the gold world parameter to check if a room is glittery

perceive([X,Y]) :- 
    			forall((pit_location(PL),adjacentTo([X,Y],PL)), (format('there is a breeze in ~p~n',[[X,Y]]),assert(breeze([X,Y])))),
    			forall((wumpus_location(L),adjacentTo([X,Y],L)), (format('there is a stench in ~p~n',[[X,Y]]),assert(stench([X,Y])))),
    			forall((gold_location(G),([X,Y] == G)),(assert(glitter([X,Y])), grabGold([X,Y]))).

%----------------------------------------------------------------------------

%Pit predicate is the main predicate for the intelligent agent to decide whether a certain room has a pit. It has two definitions which are the following:
%- Check if all of the adjacent rooms are visited and breezy from the KB.
%- if not all the adjacent rooms are visited, check for each breezy room whether the adjacent rooms to it are pitsafe. If true, we can safely assume that the original room has a pit.


pit([X,Y]) :- forall(adjacentTo([X,Y],L), (breeze(L);limit(L))).
pit([X,Y]) :- adjacentTo([X,Y],L), visited(L), breeze(L), forall(adjacentTo(L,L2),(L2 == [X,Y] ; psafe(L2) ; limit(L2))).

%----------------------------------------------------------------------------

%Wumpus predicate is the main predicate for the intelligent agent to decide whether a certain room has a wumpus. It has two definitions which are the following:
%- Check if all of the adjacent rooms are visited and stenchy from the KB.
%- if not all the adjacent rooms are visited, check for each stenchy room whether the adjacent rooms to it are wumpussafe. If true, we can safely assume that the original room has a wumpus.

wumpus([X,Y]) :- forall(adjacentTo([X,Y],L), (stench(L);limit(L))), \+limit([X,Y]) ,retractall(wumpus_final(_)),assert(wumpus_final([X,Y])).
wumpus([X,Y]) :- adjacentTo([X,Y],L), visited(L), stench(L), forall(adjacentTo(L,L2),(L2 == [X,Y];wsafe(L2); limit(L2))),
    			 \+limit([X,Y]),retractall(wumpus_final(_)),assert(wumpus_final([X,Y])).

%----------------------------------------------------------------------------

%grabGold predicate checks if the room glitters and if true, it adds it to the score.


grabGold([X,Y]):-   glitter([X,Y]),
    				score(S),
    				N is S + 500 ,
    				format('I have found GOLD, Score is now ~p~n',[N]),
    				retractall(score(_)), assert(score(N)).

%----------------------------------------------------------------------------

%psafe and wsafe predicates return true if for every L adjacent to [X,Y], it is visited and not breezy or stenchy.

psafe([X,Y]) :- adjacentTo([X,Y],L), visited(L), \+ breeze(L).
wsafe([X,Y]) :- adjacentTo([X,Y], L), visited(L), \+ stench(L).

%----------------------------------------------------------------------------

%fail_agent predicate checks whether the agent thinks either a pit or a wumpus is in Room(X,Y) in order to avoid it.

fail_agent([X,Y]) :- pit([X,Y]); wumpus([X,Y]).

%----------------------------------------------------------------------------

%maybe predicate returns true if a certain room is not visited, the agent thinks it is not certain death and is adjacent to a breezy or stenchy room. This predicate is executed when all the safe rooms are explored

maybe([X,Y]) :- \+ visited([X,Y]), \+ fail_agent([X,Y]), ( adjacentTo([X,Y],L), ( breeze(L);stench(L))).

%----------------------------------------------------------------------------
%safe predicate returns true if the room is visited and if it is not it checks if it is pit safe and wumpus safe

safe([X,Y]) :- visited([X,Y]).

safe([X,Y]) :- psafe([X,Y]), wsafe([X,Y]).

%----------------------------------------------------------------------------
%good predicate returns the next safe room that is not visited yet

good([X,Y]) :- safe([X,Y]), \+visited([X,Y]).

%----------------------------------------------------------------------------
%existmaybe and existgood both check for every visited room V, one of its adjacent rooms are good and not visited yet.
%exist predicate combines the two predicates.

existgood(A) :- visited(V), adjacentTo(V,A), good(A), \+ visited(A), \+ limit(A).

existmaybe(A) :- visited(V), adjacentTo(V,A), maybe(A), \+ visited(A), \+ limit(A).

exist(X):- existgood(X);existmaybe(X).

%----------------------------------------------------------------------------
%fail-check predicate runs after every move and checks if the intelligent agent is still alive.

fail_check(X):- wumpus_location(W), pit_location(P), (X=W,  format('I have been eaten by Wumpus!~nFailed!~n'), abort;X=P, format('I have fallen into a Pit!~nFailed!~n'), abort).

%----------------------------------------------------------------------------
%start predicate is the entry point to the program that initiates all the game elements and runs the intelligent agent.

start:-
    init,
    agent_location(AL),
    \+take_action(AL),
    wumpus_final(Z),
    (Z=[-1,-1])->  format('The agent has failed to find the Wumpus~nFAILED~n'); (  wumpus_final(Z), format('The wumpus has been located in ~p! I am shooting my arrow!~nWON~n',[Z])),
    score(S),
    time(T),
    format('Score: ~p~n',[S]),
    format('Time: ~p~n',[T]).

%----------------------------------------------------------------------------
%take_action encapsulates all of the intelligent agent's actions. It asserts the visited rooms, runs the perceive predicate, gets the next room and checks if the intelligent agent fails.

take_action(X):-
    retractall(agent_location(_)),
    assert(agent_location(X)),
    update_score(-1),
    update_time(1),
    format('I am in ~p~n',[X]),
    \+ fail_check(X),
    assert(visited(X)),
    perceive(X),
    exist(L),
    get_next(N,L,X),
    wumpus_final(Z),
    Z = [-1,-1],
    take_action(N).

%----------------------------------------------------------------------------
%get_next predicate allows for the intelligent agent to only move to adjacent rooms.
get_next([X,Y],[X1,Y1],[X2,Y2]):-
    (adjacentTo([X1,Y1],[X2,Y2])) ->  ([X,Y] = [X1,Y1]);(adjacentTo([X1,Y1],L),visited(L)) ->([X,Y]=L).

%----------------------------------------------------------------------------
%update_score predicate updates the scores every time it is called.

update_score(X):-
    score(S),
    Z is S+X,
    retractall(score(_)),
    assert(score(Z)).

%----------------------------------------------------------------------------
%update_time predicate updates the time taken every move.

update_time(X):-
    time(S),
    Z is S+X,
    retractall(time(_)),
    assert(time(Z)).

%----------------------------------------------------------------------------
%init predicate initiates all of the world's needed predicates such as the gold, wumpus, and pits' locations.
init:-
    retractall(time(_)),
    assert(time(0)),
    retractall(score(_)),
    assert(score(30)),
    retractall(gold_location(_)),
    assert(gold_location([2,3])),
    retractall(wumpus_location(_)),
    assert(wumpus_location([3,2])),
    retractall(pit_location(_)),
    assert(pit_location([3,1])),
    assert(pit_location([3,3])),
    assert(pit_location([4,4])),
    retractall(agent_location(_)),
    assert(agent_location([1,1])),
    retractall(wumpus_final(_)),
    assert(wumpus_final([-1,-1])).

