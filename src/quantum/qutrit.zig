// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  TRINITY QUTRIT — Ternary Quantum Bit Primitives                            ║
// ║  Week 2 Day 5: Qutrit operations for TQNN                                   ║
// ║                                                                              ║
// ║  Qutrit states: |0⟩ = -1, |1⟩ = 0, |2⟩ = +1                                ║
// ║  Encoding: 2-bit packed trits                                               ║
// ║                                                                              ║
// ║  φ² + 1/φ² = 3 = TRINITY                                                    ║
// ╚════════════════════════════════════════════════════════════════════════════╝

const std = @import("std");

/// Trit values for ternary logic
pub const Trit = i2;
pub const TRIT_NEG: Trit = -1;
pub const TRIT_ZERO: Trit = 0;
pub const TRIT_POS: Trit = 1;

/// Qutrit: quantum-inspired ternary bit
/// Represents a ternary state with quantum superposition capability
pub const Qutrit = struct {
    /// The trit value (-1, 0, +1)
    value: Trit = TRIT_ZERO,

    /// Phase angle (0-255, represents 0-2π)
    phase: u8 = 0,

    /// Coherence flag (quantum coherence maintained)
    coherent: bool = true,

    /// Create a qutrit from a trit value
    pub fn from_trit(t: Trit) Qutrit {
        return .{
            .value = t,
            .phase = 0,
            .coherent = true,
        };
    }

    /// Create a qutrit from a float value
    /// Maps: negative -> -1, ~0 -> 0, positive -> +1
    pub fn from_float(f: f32) Qutrit {
        const threshold = 0.5;
        if (f < -threshold) return from_trit(TRIT_NEG);
        if (f > threshold) return from_trit(TRIT_POS);
        return from_trit(TRIT_ZERO);
    }

    /// Create a qutrit from a 2-bit packed encoding
    /// 00 -> -1, 01 -> 0, 10 -> +1, 11 -> reserved (treats as 0)
    pub fn from_packed(p: u2) Qutrit {
        return switch (p) {
            0b00 => from_trit(TRIT_NEG),
            0b01 => from_trit(TRIT_ZERO),
            0b10 => from_trit(TRIT_POS),
            0b11 => from_trit(TRIT_ZERO), // Reserved
        };
    }

    /// Convert qutrit to float
    pub fn to_float(q: Qutrit) f32 {
        return @as(f32, @floatFromInt(q.value));
    }

    /// Convert qutrit to packed 2-bit encoding
    pub fn to_packed(q: Qutrit) u2 {
        return switch (q.value) {
            TRIT_NEG => 0b00,
            TRIT_ZERO => 0b01,
            TRIT_POS => 0b10,
        };
    }

    /// Apply Hadamard gate to qutrit
    /// H|ψ⟩ transforms: -1→+1, 0→-1, +1→0
    pub fn hadamard(q: *Qutrit) void {
        q.value = switch (q.value) {
            TRIT_NEG => TRIT_POS,
            TRIT_ZERO => TRIT_NEG,
            TRIT_POS => TRIT_ZERO,
            else => TRIT_ZERO, // Fallback for invalid values
        };
        // Hadamard adds π phase
        q.phase +%= 128;
    }

    /// Apply Pauli-X (NOT) gate to qutrit
    /// X|ψ⟩ flips: -1↔+1, 0 stays
    pub fn pauli_x(q: *Qutrit) void {
        if (q.value != TRIT_ZERO) {
            q.value = -q.value;
        }
        q.phase +%= 64;
    }

    /// Apply Rotation gate by angle (0-255)
    /// Small angle: stay, Medium: rotate +1, Large: rotate +2 (flip)
    pub fn rotate(q: *Qutrit, angle: u8) void {
        const rotation = angle >> 6; // Top 2 bits
        switch (rotation) {
            0b00 => {}, // No change
            0b01 => { // Rotate +1: -1→0→+1→-1
                q.value = switch (q.value) {
                    TRIT_NEG => TRIT_ZERO,
                    TRIT_ZERO => TRIT_POS,
                    TRIT_POS => TRIT_NEG,
                    else => TRIT_ZERO,
                };
            },
            else => { // Rotate +2 or flip
                if (q.value != TRIT_ZERO) {
                    q.value = -q.value;
                }
            },
        }
        q.phase +%= angle;
    }

    /// Apply Sacred Phase (Golden Angle: 137.5°)
    /// Golden angle = 2π × (1 - 1/φ) ≈ 137.5°
    pub fn sacred_phase(q: *Qutrit) void {
        q.phase +%= GOLDEN_ANGLE_U8;
        // Apply phase flip if phase wraps
        if (q.phase < GOLDEN_ANGLE_U8) {
            // Phase wrapped around - apply small transformation
            q.value = switch (q.value) {
                TRIT_NEG => TRIT_ZERO,
                TRIT_ZERO => TRIT_POS,
                TRIT_POS => TRIT_NEG,
                else => TRIT_ZERO,
            };
        }
    }

    /// Apply CPhase (Controlled Phase) gate
    /// Flips if control is +1 and phase > 128
    pub fn cphase(q: *Qutrit, control: Qutrit, phase: u8) void {
        if (control.value == TRIT_POS and phase > 128) {
            if (q.value != TRIT_ZERO) {
                q.value = -q.value;
            }
        }
        q.phase +%= phase;
    }

    /// Measure qutrit (collapse to classical trit)
    /// In this implementation, qutrits are always "measured"
    pub fn measure(q: Qutrit) Trit {
        _ = q.coherent; // In real quantum, coherence affects measurement
        return q.value;
    }

    /// Compute inner product of two qutrits
    pub fn inner_product(a: Qutrit, b: Qutrit) i2 {
        return @as(i2, @intCast(a.value)) * @as(i2, @intCast(b.value));
    }

    /// Check if two qutrits are orthogonal (different states)
    pub fn orthogonal(a: Qutrit, b: Qutrit) bool {
        return a.value != b.value;
    }
};

/// Golden ratio constant
pub const PHI: f32 = 1.618033988749895;

/// Golden angle in degrees
pub const GOLDEN_ANGLE_DEG: f32 = 137.507764;

/// Golden angle encoded as 8-bit (0-255)
pub const GOLDEN_ANGLE_U8: u8 = 98; // 137.5/360 * 256 ≈ 97.78

/// Sacred phase constant (φ²)
pub const SACRED_PHASE: f32 = PHI * PHI;

/// Trinity constant (φ² + 1/φ²)
pub const TRINITY: f32 = 3.0;

//==============================================================================
// QUTRIT ARRAY OPERATIONS
//==============================================================================

/// Array of qutrits for vector operations
pub fn QutritArray(comptime size: usize) type {
    return struct {
        data: [size]Qutrit = undefined,

        /// Initialize from trit array
        pub fn from_trits(trits: [size]Trit) @This() {
            var result: @This() = undefined;
            for (trits, 0..) |t, i| {
                result.data[i] = Qutrit.from_trit(t);
            }
            return result;
        }

        /// Initialize from float array
        pub fn from_floats(floats: [size]f32) @This() {
            var result: @This() = undefined;
            for (floats, 0..) |f, i| {
                result.data[i] = Qutrit.from_float(f);
            }
            return result;
        }

        /// Apply Hadamard to all qutrits
        pub fn hadamard_all(qa: *@This()) void {
            for (&qa.data) |*q| {
                q.hadamard();
            }
        }

        /// Apply Sacred Phase to all qutrits
        pub fn sacred_phase_all(qa: *@This()) void {
            for (&qa.data) |*q| {
                q.sacred_phase();
            }
        }

        /// Apply Rotation to all qutrits with angle gradient
        pub fn rotate_all(qa: *@This(), base_angle: u8) void {
            for (&qa.data, 0..) |*q, i| {
                const local_angle = base_angle + @as(u8, @intCast(i * 16));
                q.rotate(local_angle);
            }
        }

        /// Compute coherence (balanced distribution)
        /// Returns true if positive and negative qutrits are balanced
        pub fn coherence(qa: *@This()) bool {
            var pos_count: usize = 0;
            var neg_count: usize = 0;
            var zero_count: usize = 0;

            for (qa.data) |q| {
                switch (q.value) {
                    TRIT_POS => pos_count += 1,
                    TRIT_NEG => neg_count += 1,
                    TRIT_ZERO => zero_count += 1,
                    else => {}, // Invalid trit values - ignore
                }
            }

            // Coherent: significant pos and neg, not too many zeros
            return (pos_count > size / 4) and (neg_count > size / 4);
        }

        /// Get quantum state summary
        pub fn quantum_state(qa: *@This()) struct { pos: usize, neg: usize, zero: usize } {
            var result: struct { pos: usize, neg: usize, zero: usize } = .{
                .pos = 0,
                .neg = 0,
                .zero = 0,
            };

            for (qa.data) |q| {
                switch (q.value) {
                    TRIT_POS => result.pos += 1,
                    TRIT_NEG => result.neg += 1,
                    TRIT_ZERO => result.zero += 1,
                }
            }

            return result;
        }

        /// Measure all qutrits to trits
        pub fn measure_all(qa: @This()) [size]Trit {
            var result: [size]Trit = undefined;
            for (qa.data, 0..) |q, i| {
                result[i] = q.measure();
            }
            return result;
        }

        /// Convert to packed bits (2 bits per qutrit)
        pub fn to_packed(qa: @This()) PackedArray(size) {
            var result: PackedArray(size) = undefined;
            for (qa.data, 0..) |q, i| {
                result.set(i, q.to_packed());
            }
            return result;
        }
    };
}

/// Packed qutrit array (2 bits per qutrit)
pub fn PackedArray(comptime size: usize) type {
    const byte_count = (size * 2 + 7) / 8;
    return struct {
        data: [byte_count]u8 = [_]u8{0} ** byte_count,

        /// Get qutrit at index
        pub fn get(pa: @This(), index: usize) u2 {
            const bit_pos = index * 2;
            const byte_idx = bit_pos / 8;
            const bit_offset: u3 = @intCast(bit_pos % 8);
            const mask: u8 = @as(u8, 0b11) << bit_offset;
            return @as(u2, @intCast((pa.data[byte_idx] & mask) >> bit_offset));
        }

        /// Set qutrit at index
        pub fn set(pa: *@This(), index: usize, value: u2) void {
            const bit_pos = index * 2;
            const byte_idx = bit_pos / 8;
            const bit_offset: u3 = @intCast(bit_pos % 8);
            const mask: u8 = ~(@as(u8, 0b11) << bit_offset);
            pa.data[byte_idx] = (pa.data[byte_idx] & mask) | (@as(u8, value) << bit_offset);
        }
    };
}

//==============================================================================
// TESTS
//==============================================================================

const testing = std.testing;

test "Qutrit from_float" {
    const q_neg = Qutrit.from_float(-1.0);
    try testing.expectEqual(TRIT_NEG, q_neg.value);

    const q_zero = Qutrit.from_float(0.0);
    try testing.expectEqual(TRIT_ZERO, q_zero.value);

    const q_pos = Qutrit.from_float(1.0);
    try testing.expectEqual(TRIT_POS, q_pos.value);
}

test "Qutrit hadamard" {
    var q = Qutrit.from_trit(TRIT_NEG);
    q.hadamard();
    try testing.expectEqual(TRIT_POS, q.value);

    q = Qutrit.from_trit(TRIT_ZERO);
    q.hadamard();
    try testing.expectEqual(TRIT_NEG, q.value);

    q = Qutrit.from_trit(TRIT_POS);
    q.hadamard();
    try testing.expectEqual(TRIT_ZERO, q.value);
}

test "Qutrit sacred_phase" {
    var q = Qutrit.from_trit(TRIT_NEG);
    const old_phase = q.phase;
    q.sacred_phase();
    try testing.expect(q.phase != old_phase);
}

test "QutritArray hadamard_all" {
    var qa = QutritArray(16).from_trits([_]Trit{TRIT_NEG} ** 16);
    qa.hadamard_all();
    for (qa.data) |q| {
        try testing.expectEqual(TRIT_POS, q.value);
    }
}

test "QutritArray coherence" {
    // Balanced: should be coherent
    var pos_trits: [16]Trit = undefined;
    for (0..8) |i| pos_trits[i] = TRIT_POS;
    for (8..16) |i| pos_trits[i] = TRIT_NEG;
    var qa_balanced = QutritArray(16).from_trits(pos_trits);
    try testing.expect(qa_balanced.coherence());

    // Unbalanced: should not be coherent
    var qa_unbalanced = QutritArray(16).from_trits([_]Trit{TRIT_ZERO} ** 16);
    try testing.expect(!qa_unbalanced.coherence());
}

test "PackedArray get/set" {
    var pa: PackedArray(16) = .{};
    pa.set(0, 0b10);
    pa.set(1, 0b01);
    pa.set(15, 0b00);

    try testing.expectEqual(@as(u2, 0b10), pa.get(0));
    try testing.expectEqual(@as(u2, 0b01), pa.get(1));
    try testing.expectEqual(@as(u2, 0b00), pa.get(15));
}

// φ² + 1/φ² = 3 = TRINITY
// Cycle #127 — Week 2 Day 5
