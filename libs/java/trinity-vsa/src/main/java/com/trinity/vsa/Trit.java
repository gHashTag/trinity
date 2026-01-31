package com.trinity.vsa;

/**
 * Balanced ternary value: -1, 0, or +1
 */
public enum Trit {
    NEG(-1),
    ZERO(0),
    POS(1);

    private final byte value;

    Trit(int value) {
        this.value = (byte) value;
    }

    public byte getValue() {
        return value;
    }

    public Trit multiply(Trit other) {
        int result = this.value * other.value;
        return fromInt(result);
    }

    public Trit negate() {
        return fromInt(-this.value);
    }

    public static Trit fromInt(int value) {
        if (value > 0) return POS;
        if (value < 0) return NEG;
        return ZERO;
    }

    public static Trit fromByte(byte value) {
        return fromInt(value);
    }
}
