## Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic

import std/[random, math, sequtils]

type
  Trit* = int8  ## -1, 0, or +1
  TritVector* = seq[Trit]

proc zeros*(dim: int): TritVector =
  newSeq[Trit](dim)

proc random*(dim: int, seed: int64 = 0): TritVector =
  if seed != 0: randomize(seed)
  result = newSeq[Trit](dim)
  for i in 0..<dim:
    result[i] = Trit(rand(2) - 1)

proc `bind`*(a, b: TritVector): TritVector =
  assert a.len == b.len, "Dimension mismatch"
  result = newSeq[Trit](a.len)
  for i in 0..<a.len:
    result[i] = a[i] * b[i]

proc unbind*(a, b: TritVector): TritVector =
  `bind`(a, b)

proc bundle*(vectors: seq[TritVector]): TritVector =
  assert vectors.len > 0, "Empty vector list"
  let dim = vectors[0].len
  result = newSeq[Trit](dim)
  for i in 0..<dim:
    var sum = 0
    for v in vectors:
      sum += v[i].int
    result[i] = if sum > 0: 1 elif sum < 0: -1 else: 0

proc permute*(v: TritVector, shift: int): TritVector =
  let dim = v.len
  result = newSeq[Trit](dim)
  for i in 0..<dim:
    let newIdx = (i + shift + dim * 1000) mod dim
    result[newIdx] = v[i]

proc dot*(a, b: TritVector): int64 =
  assert a.len == b.len, "Dimension mismatch"
  for i in 0..<a.len:
    result += a[i].int64 * b[i].int64

proc similarity*(a, b: TritVector): float64 =
  let d = dot(a, b).float64
  let normA = sqrt(dot(a, a).float64)
  let normB = sqrt(dot(b, b).float64)
  if normA == 0 or normB == 0: 0.0
  else: d / (normA * normB)

proc hammingDistance*(a, b: TritVector): int =
  assert a.len == b.len, "Dimension mismatch"
  for i in 0..<a.len:
    if a[i] != b[i]: inc result
