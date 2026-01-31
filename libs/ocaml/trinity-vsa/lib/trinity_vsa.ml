(** Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic *)

type trit = int (** -1, 0, or +1 *)
type trit_vector = int array

let zeros dim = Array.make dim 0

let random dim seed =
  Random.init seed;
  Array.init dim (fun _ -> Random.int 3 - 1)

let bind a b =
  if Array.length a <> Array.length b then
    failwith "Dimension mismatch";
  Array.map2 ( * ) a b

let unbind a b = bind a b

let bundle vectors =
  match vectors with
  | [] -> failwith "Empty vector list"
  | v :: _ ->
    let dim = Array.length v in
    Array.init dim (fun i ->
      let sum = List.fold_left (fun acc v -> acc + v.(i)) 0 vectors in
      if sum > 0 then 1 else if sum < 0 then -1 else 0)

let permute v shift =
  let dim = Array.length v in
  Array.init dim (fun i ->
    let idx = (i - shift + dim) mod dim in
    v.(idx))

let dot a b =
  if Array.length a <> Array.length b then
    failwith "Dimension mismatch";
  Array.fold_left2 (fun acc x y -> acc + x * y) 0 a b

let similarity a b =
  let d = float_of_int (dot a b) in
  let norm_a = sqrt (float_of_int (dot a a)) in
  let norm_b = sqrt (float_of_int (dot b b)) in
  if norm_a = 0. || norm_b = 0. then 0.
  else d /. (norm_a *. norm_b)

let hamming_distance a b =
  if Array.length a <> Array.length b then
    failwith "Dimension mismatch";
  Array.fold_left2 (fun acc x y -> if x <> y then acc + 1 else acc) 0 a b
