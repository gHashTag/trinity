package com.trinity.vsa

import kotlin.math.sqrt
import kotlin.random.Random

/** Balanced ternary value: -1, 0, or +1 */
typealias Trit = Byte

const val TRIT_NEG: Trit = -1
const val TRIT_ZERO: Trit = 0
const val TRIT_POS: Trit = 1

/** Dense vector of balanced ternary values */
class TritVector(val data: ByteArray) {
    val dim: Int get() = data.size

    operator fun get(i: Int): Trit = data[i]
    operator fun set(i: Int, value: Trit) { data[i] = value }

    /** Number of non-zero elements */
    fun nnz(): Int = data.count { it != TRIT_ZERO }

    /** Sparsity (fraction of zeros) */
    fun sparsity(): Double = 1.0 - nnz().toDouble() / dim

    /** Negate in place */
    fun negate() {
        for (i in data.indices) data[i] = (-data[i]).toByte()
    }

    /** Clone vector */
    fun copy(): TritVector = TritVector(data.copyOf())

    companion object {
        /** Create zero vector */
        fun zeros(dim: Int) = TritVector(ByteArray(dim))

        /** Create random vector with balanced distribution */
        fun random(dim: Int, seed: Long? = null): TritVector {
            val rng = seed?.let { Random(it) } ?: Random
            val data = ByteArray(dim) { (rng.nextInt(3) - 1).toByte() }
            return TritVector(data)
        }
    }
}

/** Bind two vectors (element-wise multiplication) */
fun bind(a: TritVector, b: TritVector): TritVector {
    require(a.dim == b.dim) { "Dimension mismatch" }
    val result = ByteArray(a.dim) { i -> (a.data[i] * b.data[i]).toByte() }
    return TritVector(result)
}

/** Unbind (inverse of bind) */
fun unbind(a: TritVector, b: TritVector) = bind(a, b)

/** Bundle multiple vectors via majority voting */
fun bundle(vectors: List<TritVector>): TritVector {
    require(vectors.isNotEmpty()) { "Empty vector list" }
    val dim = vectors[0].dim
    val result = ByteArray(dim)
    for (i in 0 until dim) {
        val sum = vectors.sumOf { it.data[i].toInt() }
        result[i] = when {
            sum > 0 -> TRIT_POS
            sum < 0 -> TRIT_NEG
            else -> TRIT_ZERO
        }
    }
    return TritVector(result)
}

/** Circular permutation */
fun permute(v: TritVector, shift: Int): TritVector {
    val result = ByteArray(v.dim)
    for (i in 0 until v.dim) {
        val newIdx = Math.floorMod(i + shift, v.dim)
        result[newIdx] = v.data[i]
    }
    return TritVector(result)
}

/** Dot product */
fun dot(a: TritVector, b: TritVector): Long {
    require(a.dim == b.dim) { "Dimension mismatch" }
    return a.data.indices.sumOf { a.data[it].toLong() * b.data[it].toLong() }
}

/** Cosine similarity */
fun similarity(a: TritVector, b: TritVector): Double {
    val d = dot(a, b).toDouble()
    val normA = sqrt(dot(a, a).toDouble())
    val normB = sqrt(dot(b, b).toDouble())
    return if (normA == 0.0 || normB == 0.0) 0.0 else d / (normA * normB)
}

/** Hamming distance */
fun hammingDistance(a: TritVector, b: TritVector): Int {
    require(a.dim == b.dim) { "Dimension mismatch" }
    return a.data.indices.count { a.data[it] != b.data[it] }
}

/** Packed trit vector using bitsliced storage */
class PackedTritVec(val pos: LongArray, val neg: LongArray, val dim: Int) {
    val numWords: Int get() = pos.size

    companion object {
        fun from(v: TritVector): PackedTritVec {
            val numWords = (v.dim + 63) / 64
            val pos = LongArray(numWords)
            val neg = LongArray(numWords)
            for (i in 0 until v.dim) {
                val wordIdx = i / 64
                val bitIdx = i % 64
                when (v.data[i]) {
                    TRIT_POS -> pos[wordIdx] = pos[wordIdx] or (1L shl bitIdx)
                    TRIT_NEG -> neg[wordIdx] = neg[wordIdx] or (1L shl bitIdx)
                }
            }
            return PackedTritVec(pos, neg, v.dim)
        }
    }

    fun toVector(): TritVector {
        val data = ByteArray(dim)
        for (i in 0 until dim) {
            val wordIdx = i / 64
            val bitIdx = i % 64
            val posSet = (pos[wordIdx] shr bitIdx) and 1L
            val negSet = (neg[wordIdx] shr bitIdx) and 1L
            data[i] = when {
                posSet == 1L -> TRIT_POS
                negSet == 1L -> TRIT_NEG
                else -> TRIT_ZERO
            }
        }
        return TritVector(data)
    }
}

/** Fast packed bind */
fun packedBind(a: PackedTritVec, b: PackedTritVec): PackedTritVec {
    require(a.dim == b.dim) { "Dimension mismatch" }
    val pos = LongArray(a.numWords)
    val neg = LongArray(a.numWords)
    for (i in 0 until a.numWords) {
        pos[i] = (a.pos[i] and b.pos[i]) or (a.neg[i] and b.neg[i])
        neg[i] = (a.pos[i] and b.neg[i]) or (a.neg[i] and b.pos[i])
    }
    return PackedTritVec(pos, neg, a.dim)
}

/** Fast packed dot product */
fun packedDot(a: PackedTritVec, b: PackedTritVec): Long {
    require(a.dim == b.dim) { "Dimension mismatch" }
    var posCount = 0L
    var negCount = 0L
    for (i in 0 until a.numWords) {
        posCount += java.lang.Long.bitCount((a.pos[i] and b.pos[i]) or (a.neg[i] and b.neg[i]))
        negCount += java.lang.Long.bitCount((a.pos[i] and b.neg[i]) or (a.neg[i] and b.pos[i]))
    }
    return posCount - negCount
}
