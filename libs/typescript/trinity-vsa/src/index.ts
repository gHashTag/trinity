/**
 * Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic
 */

export type Trit = -1 | 0 | 1;

/**
 * Dense trit vector
 */
export class TritVector {
  readonly data: Int8Array;
  readonly dim: number;

  constructor(data: Int8Array) {
    this.data = data;
    this.dim = data.length;
  }

  /**
   * Create zero vector
   */
  static zeros(dim: number): TritVector {
    return new TritVector(new Int8Array(dim));
  }

  /**
   * Create random vector with balanced distribution
   */
  static random(dim: number, seed?: number): TritVector {
    const data = new Int8Array(dim);
    let rng = seed ?? Math.random() * 0xffffffff;
    
    for (let i = 0; i < dim; i++) {
      // Simple LCG for reproducibility
      rng = (rng * 1103515245 + 12345) & 0x7fffffff;
      data[i] = ((rng % 3) - 1) as Trit;
    }
    return new TritVector(data);
  }

  /**
   * Clone vector
   */
  clone(): TritVector {
    return new TritVector(new Int8Array(this.data));
  }

  /**
   * Get element
   */
  get(i: number): Trit {
    return this.data[i] as Trit;
  }

  /**
   * Set element
   */
  set(i: number, value: Trit): void {
    this.data[i] = value;
  }

  /**
   * Number of non-zero elements
   */
  nnz(): number {
    let count = 0;
    for (let i = 0; i < this.dim; i++) {
      if (this.data[i] !== 0) count++;
    }
    return count;
  }

  /**
   * Sparsity (fraction of zeros)
   */
  sparsity(): number {
    return 1 - this.nnz() / this.dim;
  }

  /**
   * Negate in place
   */
  negate(): void {
    for (let i = 0; i < this.dim; i++) {
      this.data[i] = -this.data[i] as Trit;
    }
  }
}

/**
 * Bind two vectors (element-wise multiplication)
 */
export function bind(a: TritVector, b: TritVector): TritVector {
  if (a.dim !== b.dim) throw new Error('Dimension mismatch');
  
  const result = new Int8Array(a.dim);
  for (let i = 0; i < a.dim; i++) {
    result[i] = (a.data[i] * b.data[i]) as Trit;
  }
  return new TritVector(result);
}

/**
 * Unbind (inverse of bind, same operation for balanced ternary)
 */
export function unbind(a: TritVector, b: TritVector): TritVector {
  return bind(a, b);
}

/**
 * Bundle multiple vectors via majority voting
 */
export function bundle(vectors: TritVector[]): TritVector {
  if (vectors.length === 0) throw new Error('Empty vector list');
  
  const dim = vectors[0].dim;
  const result = new Int8Array(dim);
  
  for (let i = 0; i < dim; i++) {
    let sum = 0;
    for (const v of vectors) {
      sum += v.data[i];
    }
    if (sum > 0) result[i] = 1;
    else if (sum < 0) result[i] = -1;
    else result[i] = 0;
  }
  return new TritVector(result);
}

/**
 * Circular permutation
 */
export function permute(v: TritVector, shift: number): TritVector {
  const result = new Int8Array(v.dim);
  for (let i = 0; i < v.dim; i++) {
    let newIdx = (i + shift) % v.dim;
    if (newIdx < 0) newIdx += v.dim;
    result[newIdx] = v.data[i];
  }
  return new TritVector(result);
}

/**
 * Dot product
 */
export function dot(a: TritVector, b: TritVector): number {
  if (a.dim !== b.dim) throw new Error('Dimension mismatch');
  
  let sum = 0;
  for (let i = 0; i < a.dim; i++) {
    sum += a.data[i] * b.data[i];
  }
  return sum;
}

/**
 * Cosine similarity
 */
export function similarity(a: TritVector, b: TritVector): number {
  const d = dot(a, b);
  const normA = Math.sqrt(dot(a, a));
  const normB = Math.sqrt(dot(b, b));
  if (normA === 0 || normB === 0) return 0;
  return d / (normA * normB);
}

/**
 * Hamming distance
 */
export function hammingDistance(a: TritVector, b: TritVector): number {
  if (a.dim !== b.dim) throw new Error('Dimension mismatch');
  
  let count = 0;
  for (let i = 0; i < a.dim; i++) {
    if (a.data[i] !== b.data[i]) count++;
  }
  return count;
}

/**
 * Packed trit vector using bitsliced storage
 */
export class PackedTritVec {
  readonly pos: BigUint64Array;
  readonly neg: BigUint64Array;
  readonly dim: number;
  readonly numWords: number;

  constructor(pos: BigUint64Array, neg: BigUint64Array, dim: number) {
    this.pos = pos;
    this.neg = neg;
    this.dim = dim;
    this.numWords = pos.length;
  }

  /**
   * Create from dense vector
   */
  static fromVector(v: TritVector): PackedTritVec {
    const numWords = Math.ceil(v.dim / 64);
    const pos = new BigUint64Array(numWords);
    const neg = new BigUint64Array(numWords);

    for (let i = 0; i < v.dim; i++) {
      const wordIdx = Math.floor(i / 64);
      const bitIdx = BigInt(i % 64);
      if (v.data[i] === 1) {
        pos[wordIdx] |= 1n << bitIdx;
      } else if (v.data[i] === -1) {
        neg[wordIdx] |= 1n << bitIdx;
      }
    }
    return new PackedTritVec(pos, neg, v.dim);
  }

  /**
   * Convert to dense vector
   */
  toVector(): TritVector {
    const data = new Int8Array(this.dim);
    for (let i = 0; i < this.dim; i++) {
      const wordIdx = Math.floor(i / 64);
      const bitIdx = BigInt(i % 64);
      const posSet = (this.pos[wordIdx] >> bitIdx) & 1n;
      const negSet = (this.neg[wordIdx] >> bitIdx) & 1n;
      if (posSet === 1n) data[i] = 1;
      else if (negSet === 1n) data[i] = -1;
    }
    return new TritVector(data);
  }
}

/**
 * Fast packed bind
 */
export function packedBind(a: PackedTritVec, b: PackedTritVec): PackedTritVec {
  if (a.dim !== b.dim) throw new Error('Dimension mismatch');

  const pos = new BigUint64Array(a.numWords);
  const neg = new BigUint64Array(a.numWords);

  for (let i = 0; i < a.numWords; i++) {
    // +1 when: (+1,+1) or (-1,-1)
    pos[i] = (a.pos[i] & b.pos[i]) | (a.neg[i] & b.neg[i]);
    // -1 when: (+1,-1) or (-1,+1)
    neg[i] = (a.pos[i] & b.neg[i]) | (a.neg[i] & b.pos[i]);
  }
  return new PackedTritVec(pos, neg, a.dim);
}

/**
 * Popcount for BigInt
 */
function popcount64(x: bigint): number {
  let count = 0;
  while (x !== 0n) {
    x &= x - 1n;
    count++;
  }
  return count;
}

/**
 * Fast packed dot product
 */
export function packedDot(a: PackedTritVec, b: PackedTritVec): number {
  if (a.dim !== b.dim) throw new Error('Dimension mismatch');

  let posCount = 0;
  let negCount = 0;

  for (let i = 0; i < a.numWords; i++) {
    posCount += popcount64((a.pos[i] & b.pos[i]) | (a.neg[i] & b.neg[i]));
    negCount += popcount64((a.pos[i] & b.neg[i]) | (a.neg[i] & b.pos[i]));
  }
  return posCount - negCount;
}
