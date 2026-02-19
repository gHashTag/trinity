/// Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic
module TrinityVSA

open System

type Trit = sbyte
type TritVector = Trit array

let zeros dim : TritVector = Array.zeroCreate dim

let random dim (seed: int) : TritVector =
    let rng = Random(seed)
    Array.init dim (fun _ -> sbyte (rng.Next(3) - 1))

let bind (a: TritVector) (b: TritVector) : TritVector =
    if a.Length <> b.Length then failwith "Dimension mismatch"
    Array.map2 (fun x y -> x * y) a b

let unbind a b = bind a b

let bundle (vectors: TritVector list) : TritVector =
    if List.isEmpty vectors then failwith "Empty vector list"
    let dim = vectors.[0].Length
    Array.init dim (fun i ->
        let sum = vectors |> List.sumBy (fun v -> int v.[i])
        if sum > 0 then 1y elif sum < 0 then -1y else 0y)

let permute (v: TritVector) shift : TritVector =
    let dim = v.Length
    let result = Array.zeroCreate dim
    for i in 0 .. dim - 1 do
        let newIdx = ((i + shift) % dim + dim) % dim
        result.[newIdx] <- v.[i]
    result

let dot (a: TritVector) (b: TritVector) : int64 =
    if a.Length <> b.Length then failwith "Dimension mismatch"
    Array.fold2 (fun acc x y -> acc + int64 x * int64 y) 0L a b

let similarity a b =
    let d = float (dot a b)
    let normA = sqrt (float (dot a a))
    let normB = sqrt (float (dot b b))
    if normA = 0.0 || normB = 0.0 then 0.0
    else d / (normA * normB)

let hammingDistance (a: TritVector) (b: TritVector) =
    if a.Length <> b.Length then failwith "Dimension mismatch"
    Array.fold2 (fun acc x y -> if x <> y then acc + 1 else acc) 0 a b
