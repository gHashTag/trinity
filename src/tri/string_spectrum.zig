// @origin(spec:string_spectrum.tri) @regen(manual-impl)
//! String Spectrum — vibrational modes with φ-harmonic frequencies.
//!
//! Bosonic:  ω = base × √n
//! Fermionic: ω = base × √(n + ½)  (half-integer shift)
//! φ-harmonic: ω × φ^(1/12)  (golden chromatic step)

const std = @import("std");
const SacredConstants = @import("sacred_constants.zig").SacredConstants;

const PHI = SacredConstants.PHI;

pub const VibrationalMode = struct {
    frequency: f64 = 440.0,
    mode_number: u32 = 0,
    fermionic: bool = false,

    /// Construct a vibrational mode.
    /// Bosonic: freq = base × √n.  Fermionic: freq = base × √(n + 0.5).
    /// n=0 bosonic → frequency = 0 (ground state / massless).
    pub fn init(n: u32, name: []const u8, fermionic: bool) @This() {
        _ = name;
        const base: f64 = 440.0; // concert A anchor
        const nf: f64 = @floatFromInt(n);
        const effective_n: f64 = if (fermionic) nf + 0.5 else nf;
        const freq: f64 = base * @sqrt(effective_n);
        return .{
            .frequency = freq,
            .mode_number = n,
            .fermionic = fermionic,
        };
    }

    /// φ-harmonic: raise frequency by one golden chromatic step φ^(1/12)
    pub fn phiHarmonic(self: @This()) f64 {
        return self.frequency * std.math.pow(f64, PHI, 1.0 / 12.0);
    }

    /// Mass² ∝ (n - a) where a = 0 (bosonic) or ½ (fermionic)
    /// Returns n - a in string tension units.
    pub fn massSquared(self: @This()) f64 {
        const nf: f64 = @floatFromInt(self.mode_number);
        return if (self.fermionic) nf - 0.5 else nf;
    }

    /// Is this a massless mode? (n=0 bosonic or n=0 fermionic with m²<0 tachyon excluded)
    pub fn isMassless(self: @This()) bool {
        return self.mode_number == 0 and !self.fermionic;
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

const testing = std.testing;

test "ground state bosonic is massless" {
    const m = VibrationalMode.init(0, "ground", false);
    try testing.expectEqual(@as(f64, 0.0), m.frequency);
    try testing.expect(m.isMassless());
    try testing.expectEqual(@as(f64, 0.0), m.massSquared());
}

test "first excited bosonic mode" {
    const m = VibrationalMode.init(1, "breathing", false);
    // freq = 440 × √1 = 440
    try testing.expect(@abs(m.frequency - 440.0) < 1e-10);
    try testing.expectEqual(@as(f64, 1.0), m.massSquared());
    try testing.expect(!m.isMassless());
}

test "fermionic half-integer shift" {
    const m = VibrationalMode.init(0, "fermion_ground", true);
    // freq = 440 × √0.5 ≈ 311.127
    try testing.expect(@abs(m.frequency - 440.0 * @sqrt(0.5)) < 1e-10);
    try testing.expect(!m.isMassless());
    // m² = 0 - 0.5 = -0.5 (tachyonic)
    try testing.expect(@abs(m.massSquared() + 0.5) < 1e-10);
}

test "higher mode frequency scales as sqrt(n)" {
    const m4 = VibrationalMode.init(4, "n4", false);
    // freq = 440 × √4 = 880
    try testing.expect(@abs(m4.frequency - 880.0) < 1e-10);
}

test "phi-harmonic raises by golden chromatic step" {
    const m = VibrationalMode.init(1, "test", false);
    const ph = m.phiHarmonic();
    const expected = 440.0 * std.math.pow(f64, PHI, 1.0 / 12.0);
    try testing.expect(@abs(ph - expected) < 1e-10);
    // φ^(1/12) > 1, so phi-harmonic is higher
    try testing.expect(ph > m.frequency);
}

// φ² + 1/φ² = 3 = TRINITY
