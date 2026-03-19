%% Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic
-module(trinity_vsa).
-export([zeros/1, random/2, bind/2, unbind/2, bundle/1, permute/2, dot/2, similarity/2, hamming_distance/2]).

zeros(Dim) ->
    lists:duplicate(Dim, 0).

random(Dim, Seed) ->
    rand:seed(exsss, {Seed, Seed, Seed}),
    [rand:uniform(3) - 2 || _ <- lists:seq(1, Dim)].

bind(A, B) when length(A) =:= length(B) ->
    lists:zipwith(fun(X, Y) -> X * Y end, A, B).

unbind(A, B) ->
    bind(A, B).

bundle(Vectors) when length(Vectors) > 0 ->
    Dim = length(hd(Vectors)),
    [begin
        Sum = lists:sum([lists:nth(I, V) || V <- Vectors]),
        if Sum > 0 -> 1; Sum < 0 -> -1; true -> 0 end
    end || I <- lists:seq(1, Dim)].

permute(V, Shift) ->
    Dim = length(V),
    [lists:nth(((I - 1 - Shift) rem Dim + Dim) rem Dim + 1, V) || I <- lists:seq(1, Dim)].

dot(A, B) when length(A) =:= length(B) ->
    lists:sum(lists:zipwith(fun(X, Y) -> X * Y end, A, B)).

similarity(A, B) ->
    D = dot(A, B),
    NormA = math:sqrt(dot(A, A)),
    NormB = math:sqrt(dot(B, B)),
    case {NormA, NormB} of
        {0.0, _} -> 0.0;
        {_, 0.0} -> 0.0;
        _ -> D / (NormA * NormB)
    end.

hamming_distance(A, B) when length(A) =:= length(B) ->
    length([1 || {X, Y} <- lists:zip(A, B), X =/= Y]).
