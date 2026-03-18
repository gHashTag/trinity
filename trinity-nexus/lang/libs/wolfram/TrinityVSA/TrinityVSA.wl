(* ::Package:: *)
(* Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic *)

BeginPackage["TrinityVSA`"]

TritZeros::usage = "TritZeros[dim] creates a zero trit vector"
TritRandom::usage = "TritRandom[dim, seed] creates a random trit vector"
TritBind::usage = "TritBind[a, b] binds two vectors"
TritUnbind::usage = "TritUnbind[a, b] unbinds two vectors"
TritBundle::usage = "TritBundle[vectors] bundles vectors via majority voting"
TritPermute::usage = "TritPermute[v, shift] circular permutation"
TritDot::usage = "TritDot[a, b] dot product"
TritSimilarity::usage = "TritSimilarity[a, b] cosine similarity"
TritHammingDistance::usage = "TritHammingDistance[a, b] hamming distance"

Begin["`Private`"]

TritZeros[dim_Integer] := ConstantArray[0, dim]

TritRandom[dim_Integer, seed_Integer] := Module[{},
  SeedRandom[seed];
  RandomInteger[{-1, 1}, dim]
]

TritBind[a_List, b_List] /; Length[a] == Length[b] := a * b

TritUnbind[a_List, b_List] := TritBind[a, b]

TritBundle[vectors_List] /; Length[vectors] > 0 := Module[{dim, sums},
  dim = Length[First[vectors]];
  sums = Total[vectors];
  Map[Which[# > 0, 1, # < 0, -1, True, 0] &, sums]
]

TritPermute[v_List, shift_Integer] := RotateRight[v, shift]

TritDot[a_List, b_List] /; Length[a] == Length[b] := Total[a * b]

TritSimilarity[a_List, b_List] := Module[{d, normA, normB},
  d = TritDot[a, b];
  normA = Sqrt[TritDot[a, a]];
  normB = Sqrt[TritDot[b, b]];
  If[normA == 0 || normB == 0, 0., d / (normA * normB)]
]

TritHammingDistance[a_List, b_List] /; Length[a] == Length[b] := 
  Count[a - b, x_ /; x != 0]

End[]
EndPackage[]
