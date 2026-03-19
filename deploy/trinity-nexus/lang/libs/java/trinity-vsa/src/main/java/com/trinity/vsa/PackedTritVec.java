package com.trinity.vsa;

/**
 * Packed trit vector using bitsliced storage (2 bits per trit)
 */
public class PackedTritVec {
    private final long[] pos;
    private final long[] neg;
    private final int dim;
    private final int numWords;

    public PackedTritVec(long[] pos, long[] neg, int dim) {
        this.pos = pos;
        this.neg = neg;
        this.dim = dim;
        this.numWords = pos.length;
    }

    /**
     * Create from dense vector
     */
    public static PackedTritVec fromVector(TritVector v) {
        int numWords = (v.getDim() + 63) / 64;
        long[] pos = new long[numWords];
        long[] neg = new long[numWords];
        byte[] data = v.getData();

        for (int i = 0; i < v.getDim(); i++) {
            int wordIdx = i / 64;
            int bitIdx = i % 64;
            if (data[i] == 1) {
                pos[wordIdx] |= 1L << bitIdx;
            } else if (data[i] == -1) {
                neg[wordIdx] |= 1L << bitIdx;
            }
        }
        return new PackedTritVec(pos, neg, v.getDim());
    }

    /**
     * Convert to dense vector
     */
    public TritVector toVector() {
        byte[] data = new byte[dim];
        for (int i = 0; i < dim; i++) {
            int wordIdx = i / 64;
            int bitIdx = i % 64;
            boolean posSet = ((pos[wordIdx] >> bitIdx) & 1) == 1;
            boolean negSet = ((neg[wordIdx] >> bitIdx) & 1) == 1;
            if (posSet) data[i] = 1;
            else if (negSet) data[i] = -1;
        }
        return new TritVector(data);
    }

    public int getDim() {
        return dim;
    }

    public int getNumWords() {
        return numWords;
    }

    long[] getPos() {
        return pos;
    }

    long[] getNeg() {
        return neg;
    }

    /**
     * Fast packed bind
     */
    public static PackedTritVec bind(PackedTritVec a, PackedTritVec b) {
        if (a.dim != b.dim) {
            throw new IllegalArgumentException("Dimension mismatch");
        }
        long[] pos = new long[a.numWords];
        long[] neg = new long[a.numWords];

        for (int i = 0; i < a.numWords; i++) {
            // +1 when: (+1,+1) or (-1,-1)
            pos[i] = (a.pos[i] & b.pos[i]) | (a.neg[i] & b.neg[i]);
            // -1 when: (+1,-1) or (-1,+1)
            neg[i] = (a.pos[i] & b.neg[i]) | (a.neg[i] & b.pos[i]);
        }
        return new PackedTritVec(pos, neg, a.dim);
    }

    /**
     * Fast packed dot product
     */
    public static long dot(PackedTritVec a, PackedTritVec b) {
        if (a.dim != b.dim) {
            throw new IllegalArgumentException("Dimension mismatch");
        }
        long posCount = 0;
        long negCount = 0;

        for (int i = 0; i < a.numWords; i++) {
            posCount += Long.bitCount((a.pos[i] & b.pos[i]) | (a.neg[i] & b.neg[i]));
            negCount += Long.bitCount((a.pos[i] & b.neg[i]) | (a.neg[i] & b.pos[i]));
        }
        return posCount - negCount;
    }
}
