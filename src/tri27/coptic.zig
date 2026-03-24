// TRI-27 OPTIC SYSTEM — Coptic Alphabet 3-Bank Model
// Issue #407 — Wave 1

const std = @import("std");

/// 27 Coptic registers (t0-t26) with 3-bank model
/// Bank 0 (ALU): t0-t8 (alpha0-eta7)
/// Bank 1 (Sacred): t9-t17 (iota9-rho17)
/// Bank 2 (Const): t18-t26 (sigma18-shmima26)
pub const CopticReg = enum(u5) {
    // Bank 0: ALU registers (t0-t8)
    alpha0,
    beta1,
    gamma2,
    delta3,
    epsilon4,
    zeta5,
    theta6,
    eta7,
    theta8,

    // Bank 1: Sacred registers (t9-t17)
    iota9,
    kappa10,
    lambda11,
    mu12,
    nu13,
    xi14,
    omicron15,
    pi16,
    rho17,

    // Bank 2: Const registers (t18-t26)
    sigma18,
    tau19,
    upsilon20,
    phi21,
    chi22,
    psi23,
    omega24,
    omega25,
    shmima26,

    /// Get bank number (0=ALU, 1=Sacred, 2=Const)
    pub fn bank(self: CopticReg) u2 {
        const val = @intFromEnum(self);
        if (val <= 8) return 0;   // 0-8: ALU
        if (val <= 17) return 1;  // 9-17: Sacred
        return 2;                 // 18-26: Const
    }

    pub fn glyph(self: CopticReg) []const u8 {
        return switch (self) {
            .alpha0 => "\xE2\xB2\x80", .beta1 => "\xE2\xB2\x81", .gamma2 => "\xE2\xB2\x82", .delta3 => "\xE2\xB2\x83",
            .epsilon4 => "\xE2\xB2\x84", .zeta5 => "\xE2\xB2\x85", .theta6 => "\xE2\xB2\x86", .eta7 => "\xE2\xB2\x87", .theta8 => "\xE2\xB2\x88",
            .iota9 => "\xE2\xB2\x89", .kappa10 => "\xE2\xB2\x8A", .lambda11 => "\xE2\xB2\x8B", .mu12 => "\xE2\xB2\x8C", .nu13 => "\xE2\xB2\x8D",
            .xi14 => "\xE2\xB2\x8E", .omicron15 => "\xE2\xB2\x8F", .pi16 => "\xE2\xB2\x90", .rho17 => "\xE2\xB2\x91",
            .sigma18 => "\xE2\xB2\x92", .tau19 => "\xE2\xB2\x93", .upsilon20 => "\xE2\xB2\x94", .phi21 => "\xE2\xB2\x95", .chi22 => "\xE2\xB2\x96",
            .psi23 => "\xE2\xB2\x97", .omega24 => "\xE2\xB2\x98", .omega25 => "\xE2\xB2\x99", .shmima26 => "\xE2\xB2\x9B",
        };
    }

    pub fn name(self: CopticReg) []const u8 {
        return switch (self) {
            .alpha0 => "alpha0", .beta1 => "beta1", .gamma2 => "gamma2", .delta3 => "delta3",
            .epsilon4 => "epsilon4", .zeta5 => "zeta5", .theta6 => "theta6", .eta7 => "eta7", .theta8 => "theta8",
            .iota9 => "iota9", .kappa10 => "kappa10", .lambda11 => "lambda11", .mu12 => "mu12",
            .nu13 => "nu13", .xi14 => "xi14", .omicron15 => "omicron15", .pi16 => "pi16", .rho17 => "rho17",
            .sigma18 => "sigma18", .tau19 => "tau19", .upsilon20 => "upsilon20", .phi21 => "phi21",
            .chi22 => "chi22", .psi23 => "psi23", .omega24 => "omega24", .omega25 => "omega25",
            .shmima26 => "shmima26",
        };
    }
};

// Test Coptic register properties
test "Coptic register banks" {
    const testing = std.testing;

    try testing.expectEqual(@as(u2, 0), CopticReg.alpha0.bank());
    try testing.expectEqual(@as(u2, 1), CopticReg.iota9.bank());
    try testing.expectEqual(@as(u2, 2), CopticReg.sigma18.bank());
    try testing.expectEqual(@as(u2, 2), CopticReg.shmima26.bank());
}

test "Coptic register count" {
    const testing = std.testing;

    // Verify we have exactly 27 registers (0-26)
    try testing.expectEqual(@as(u5, 26), @intFromEnum(CopticReg.shmima26));
}
