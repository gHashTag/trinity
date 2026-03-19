package com.trinity.vsa;

import java.util.Random;

/**
 * Dense vector of balanced ternary values
 */
public class TritVector {
    private final byte[] data;
    private final int dim;

    public TritVector(byte[] data) {
        this.data = data;
        this.dim = data.length;
    }

    /**
     * Create zero vector
     */
    public static TritVector zeros(int dim) {
        return new TritVector(new byte[dim]);
    }

    /**
     * Create random vector with balanced distribution
     */
    public static TritVector random(int dim, long seed) {
        Random rng = new Random(seed);
        byte[] data = new byte[dim];
        for (int i = 0; i < dim; i++) {
            data[i] = (byte) (rng.nextInt(3) - 1);
        }
        return new TritVector(data);
    }

    /**
     * Create random vector with random seed
     */
    public static TritVector random(int dim) {
        return random(dim, System.nanoTime());
    }

    public int getDim() {
        return dim;
    }

    public byte get(int i) {
        return data[i];
    }

    public void set(int i, byte value) {
        data[i] = value;
    }

    public void set(int i, Trit value) {
        data[i] = value.getValue();
    }

    /**
     * Clone vector
     */
    public TritVector copy() {
        byte[] newData = new byte[dim];
        System.arraycopy(data, 0, newData, 0, dim);
        return new TritVector(newData);
    }

    /**
     * Number of non-zero elements
     */
    public int nnz() {
        int count = 0;
        for (byte b : data) {
            if (b != 0) count++;
        }
        return count;
    }

    /**
     * Sparsity (fraction of zeros)
     */
    public double sparsity() {
        return 1.0 - (double) nnz() / dim;
    }

    /**
     * Negate in place
     */
    public void negate() {
        for (int i = 0; i < dim; i++) {
            data[i] = (byte) -data[i];
        }
    }

    // Package-private access to raw data
    byte[] getData() {
        return data;
    }
}
