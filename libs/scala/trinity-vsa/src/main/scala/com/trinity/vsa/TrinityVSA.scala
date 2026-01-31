package com.trinity.vsa

import scala.util.Random
import scala.math.sqrt

/** Balanced ternary value: -1, 0, or +1 */
type Trit = Byte

object Trit:
  val Neg: Trit = -1
  val Zero: Trit = 0
  val Pos: Trit = 1

/** Dense vector of balanced ternary values */
class TritVector(val data: Array[Byte]):
  def dim: Int = data.length
  def apply(i: Int): Trit = data(i)
  def update(i: Int, v: Trit): Unit = data(i) = v
  
  def nnz: Int = data.count(_ != 0)
  def sparsity: Double = 1.0 - nnz.toDouble / dim
  
  def negate(): Unit = 
    for i <- data.indices do data(i) = (-data(i)).toByte
  
  def copy: TritVector = TritVector(data.clone())

object TritVector:
  def zeros(dim: Int): TritVector = TritVector(new Array[Byte](dim))
  
  def random(dim: Int, seed: Option[Long] = None): TritVector =
    val rng = seed.map(new Random(_)).getOrElse(new Random())
    val data = Array.fill(dim)((rng.nextInt(3) - 1).toByte)
    TritVector(data)

object VSA:
  /** Bind two vectors */
  def bind(a: TritVector, b: TritVector): TritVector =
    require(a.dim == b.dim, "Dimension mismatch")
    TritVector(Array.tabulate(a.dim)(i => (a.data(i) * b.data(i)).toByte))
  
  /** Unbind (inverse of bind) */
  def unbind(a: TritVector, b: TritVector): TritVector = bind(a, b)
  
  /** Bundle via majority voting */
  def bundle(vectors: Seq[TritVector]): TritVector =
    require(vectors.nonEmpty, "Empty vector list")
    val dim = vectors.head.dim
    val result = new Array[Byte](dim)
    for i <- 0 until dim do
      val sum = vectors.map(_.data(i).toInt).sum
      result(i) = if sum > 0 then Trit.Pos else if sum < 0 then Trit.Neg else Trit.Zero
    TritVector(result)
  
  /** Circular permutation */
  def permute(v: TritVector, shift: Int): TritVector =
    val result = new Array[Byte](v.dim)
    for i <- 0 until v.dim do
      val newIdx = Math.floorMod(i + shift, v.dim)
      result(newIdx) = v.data(i)
    TritVector(result)
  
  /** Dot product */
  def dot(a: TritVector, b: TritVector): Long =
    require(a.dim == b.dim, "Dimension mismatch")
    (0 until a.dim).map(i => a.data(i).toLong * b.data(i).toLong).sum
  
  /** Cosine similarity */
  def similarity(a: TritVector, b: TritVector): Double =
    val d = dot(a, b).toDouble
    val normA = sqrt(dot(a, a).toDouble)
    val normB = sqrt(dot(b, b).toDouble)
    if normA == 0 || normB == 0 then 0.0 else d / (normA * normB)
  
  /** Hamming distance */
  def hammingDistance(a: TritVector, b: TritVector): Int =
    require(a.dim == b.dim, "Dimension mismatch")
    (0 until a.dim).count(i => a.data(i) != b.data(i))

/** Packed trit vector */
class PackedTritVec(val pos: Array[Long], val neg: Array[Long], val dim: Int):
  def numWords: Int = pos.length
  
  def toVector: TritVector =
    val data = new Array[Byte](dim)
    for i <- 0 until dim do
      val wordIdx = i / 64
      val bitIdx = i % 64
      val posSet = (pos(wordIdx) >> bitIdx) & 1L
      val negSet = (neg(wordIdx) >> bitIdx) & 1L
      data(i) = if posSet == 1 then Trit.Pos else if negSet == 1 then Trit.Neg else Trit.Zero
    TritVector(data)

object PackedTritVec:
  def from(v: TritVector): PackedTritVec =
    val numWords = (v.dim + 63) / 64
    val pos = new Array[Long](numWords)
    val neg = new Array[Long](numWords)
    for i <- 0 until v.dim do
      val wordIdx = i / 64
      val bitIdx = i % 64
      v.data(i) match
        case Trit.Pos => pos(wordIdx) |= 1L << bitIdx
        case Trit.Neg => neg(wordIdx) |= 1L << bitIdx
        case _ =>
    PackedTritVec(pos, neg, v.dim)
  
  def bind(a: PackedTritVec, b: PackedTritVec): PackedTritVec =
    require(a.dim == b.dim, "Dimension mismatch")
    val pos = Array.tabulate(a.numWords)(i => (a.pos(i) & b.pos(i)) | (a.neg(i) & b.neg(i)))
    val neg = Array.tabulate(a.numWords)(i => (a.pos(i) & b.neg(i)) | (a.neg(i) & b.pos(i)))
    PackedTritVec(pos, neg, a.dim)
  
  def dot(a: PackedTritVec, b: PackedTritVec): Long =
    require(a.dim == b.dim, "Dimension mismatch")
    var posCount = 0L
    var negCount = 0L
    for i <- 0 until a.numWords do
      posCount += java.lang.Long.bitCount((a.pos(i) & b.pos(i)) | (a.neg(i) & b.neg(i)))
      negCount += java.lang.Long.bitCount((a.pos(i) & b.neg(i)) | (a.neg(i) & b.pos(i)))
    posCount - negCount
