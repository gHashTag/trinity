package com.trinity.vsa;

import java.util.List;

/**
 * Vector Symbolic Architecture operations
 */
public final class VSA {
    private VSA() {}

    /**
     * Bind two vectors (element-wise multiplication)
     */
    public static TritVector bind(TritVector a, TritVector b) {
        if (a.getDim() != b.getDim()) {
            throw new IllegalArgumentException("Dimension mismatch");
        }
        byte[] result = new byte[a.getDim()];
        byte[] aData = a.getData();
        byte[] bData = b.getData();
        
        for (int i = 0; i < a.getDim(); i++) {
            result[i] = (byte) (aData[i] * bData[i]);
        }
        return new TritVector(result);
    }

    /**
     * Unbind (inverse of bind, same operation for balanced ternary)
     */
    public static TritVector unbind(TritVector a, TritVector b) {
        return bind(a, b);
    }

    /**
     * Bundle multiple vectors via majority voting
     */
    public static TritVector bundle(List<TritVector> vectors) {
        if (vectors.isEmpty()) {
            throw new IllegalArgumentException("Empty vector list");
        }
        int dim = vectors.get(0).getDim();
        byte[] result = new byte[dim];
        
        for (int i = 0; i < dim; i++) {
            int sum = 0;
            for (TritVector v : vectors) {
                sum += v.get(i);
            }
            if (sum > 0) result[i] = 1;
            else if (sum < 0) result[i] = -1;
            else result[i] = 0;
        }
        return new TritVector(result);
    }

    /**
     * Bundle array of vectors
     */
    public static TritVector bundle(TritVector... vectors) {
        return bundle(List.of(vectors));
    }

    /**
     * Circular permutation
     */
    public static TritVector permute(TritVector v, int shift) {
        int dim = v.getDim();
        byte[] result = new byte[dim];
        byte[] data = v.getData();
        
        for (int i = 0; i < dim; i++) {
            int newIdx = Math.floorMod(i + shift, dim);
            result[newIdx] = data[i];
        }
        return new TritVector(result);
    }

    /**
     * Dot product
     */
    public static long dot(TritVector a, TritVector b) {
        if (a.getDim() != b.getDim()) {
            throw new IllegalArgumentException("Dimension mismatch");
        }
        long sum = 0;
        byte[] aData = a.getData();
        byte[] bData = b.getData();
        
        for (int i = 0; i < a.getDim(); i++) {
            sum += aData[i] * bData[i];
        }
        return sum;
    }

    /**
     * Cosine similarity
     */
    public static double similarity(TritVector a, TritVector b) {
        double d = dot(a, b);
        double normA = Math.sqrt(dot(a, a));
        double normB = Math.sqrt(dot(b, b));
        if (normA == 0 || normB == 0) return 0;
        return d / (normA * normB);
    }

    /**
     * Hamming distance
     */
    public static int hammingDistance(TritVector a, TritVector b) {
        if (a.getDim() != b.getDim()) {
            throw new IllegalArgumentException("Dimension mismatch");
        }
        int count = 0;
        byte[] aData = a.getData();
        byte[] bData = b.getData();
        
        for (int i = 0; i < a.getDim(); i++) {
            if (aData[i] != bData[i]) count++;
        }
        return count;
    }
}
