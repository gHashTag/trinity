// ═══════════════════════════════════════════════════════════════════════════════
// coptic.zig — Coptic Alphabet for TRI-27 Registers
// ═══════════════════════════════════════════════════════════════════════════════
//
// Issue #407: Coptic Alphabet + 3-Bank + NA-R11
//
// 27 Coptic glyphs mapped to TRI-27 registers (t0-t26)
// 3-bank architecture:
//   Bank 0 (Units 1-9):   ALU registers (integer ops)
//   Bank 1 (Tens 10-90):  Sacred accumulators (FADD/FMUL)
//   Bank 2 (Hundreds 100-900): Constants (immutable)
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Coptic Register — enum of 27 Coptic glyphs mapped to TRI-27 registers
pub const CopticReg = enum(u5) {
    // Bank 0: ALU registers (Units 1-9)
    alpha = 0, // Ⲁ  → t0 (accumulator)
    beta = 1, // Ⲃ  → t1 (base pointer)
    gamma = 2, // Ⲅ  → t2 (general)
    dalda = 3, // Ⲇ  → t3
    ei = 4, // Ⲉ  → t4
    sou = 5, // Ⲋ  → t5
    zeta = 6, // Ⲍ  → t6
    ita = 7, // Ⲏ  → t7
    tita = 8, // Ⲑ  → t8

    // Bank 1: Sacred accumulators (Tens 10-90)
    iota = 9, // Ⲓ  → t9 (GF16 accumulator)
    kappa = 10, // Ⲕ  → t10
    laula = 11, // Ⲗ  → t11
    mi = 12, // Ⲙ  → t12
    ni = 13, // Ⲛ  → t13
    ksi = 14, // Ⲝ  → t14
    o = 15, // Ⲟ  → t15
    pi = 16, // Ⲡ  → t16
    ro = 17, // Ⲣ  → t17

    // Bank 2: Constants (Hundreds 100-900)
    sima = 18, // Ⲥ  → t18 (constant register)
    tau = 19, // Ⲧ  → t19
    ypsilon = 20, // Ⲩ  → t20
    phi = 21, // Ⲫ  → t21
    chi = 22, // Ⲭ  → t22
    psi = 23, // Ⲯ  → t23
    omega = 24, // Ⲱ  → t24
    shai = 25, // Ϣ  → t25
    fay = 26, // Ϥ  → t26

    /// Returns the bank number (0, 1, or 2) for this register
    pub fn bank(self: CopticReg) u2 {
        return @intCast(@intFromEnum(self) / 9);
    }

    /// Returns the TRI-27 register number (t0-t26) for this Coptic glyph
    pub fn regIndex(self: CopticReg) u5 {
        return @intFromEnum(self);
    }

    /// Returns the Coptic glyph name as a string slice
    pub fn name(self: CopticReg) []const u8 {
        return @tagName(self);
    }
};

/// Array of Coptic glyphs in order (maps 1:1 to CopticReg enum values)
pub const coptic_glyphs = [27][]const u8{
    "Ⲁ", "Ⲃ", "Ⲅ", "Ⲇ", "Ⲉ", "Ⲋ", "Ⲍ", "Ⲏ", "Ⲑ",
    "Ⲓ", "Ⲕ", "Ⲗ", "Ⲙ", "Ⲛ", "Ⲝ", "Ⲟ", "Ⲡ", "Ⲣ",
    "Ⲥ", "Ⲧ", "Ⲩ", "Ⲫ", "Ⲭ", "Ⲯ", "Ⲱ", "Ϣ",  "Ϥ",
};

/// Lookup table: Coptic glyph → CopticReg (O(N) for small N=27)
pub fn glyphToReg(glyph: []const u8) ?CopticReg {
    for (coptic_glyphs, 0..) |g, i| {
        if (std.mem.eql(u8, g, glyph)) {
            return @enumFromInt(i);
        }
    }
    return null;
}

/// Bank constants
pub const Bank0: u2 = 0;
pub const Bank1: u2 = 1;
pub const Bank2: u2 = 2;

/// Bank names for debugging
pub fn bankName(bank: u2) []const u8 {
    return switch (bank) {
        0 => "Bank0:ALU",
        1 => "Bank1:Sacred",
        2 => "Bank2:Constants",
        else => "Invalid",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "CopticReg bank() returns correct bank" {
    // Bank 0 (0-8)
    try std.testing.expectEqual(@as(u2, 0), CopticReg.alpha.bank());
    try std.testing.expectEqual(@as(u2, 0), CopticReg.beta.bank());
    try std.testing.expectEqual(@as(u2, 0), CopticReg.tita.bank());

    // Bank 1 (9-17)
    try std.testing.expectEqual(@as(u2, 1), CopticReg.iota.bank());
    try std.testing.expectEqual(@as(u2, 1), CopticReg.ro.bank());

    // Bank 2 (18-26)
    try std.testing.expectEqual(@as(u2, 2), CopticReg.sima.bank());
    try std.testing.expectEqual(@as(u2, 2), CopticReg.fay.bank());
}

test "glyphToReg finds correct register" {
    try std.testing.expectEqual(CopticReg.alpha, try glyphToReg("Ⲁ"));
    try std.testing.expectEqual(CopticReg.iota, try glyphToReg("Ⲓ"));
    try std.testing.expectEqual(CopticReg.sima, try glyphToReg("Ⲥ"));
    try std.testing.expectEqual(CopticReg.fay, try glyphToReg("Ϥ"));

    // Invalid glyph returns null
    try std.testing.expect(glyphToReg("X") == null);
}

test "coptic_glyphs array has 27 entries" {
    try std.testing.expectEqual(@as(usize, 27), coptic_glyphs.len);
}

test "CopticReg name returns correct tag" {
    try std.testing.expectEqualStrings("alpha", CopticReg.alpha.name());
    try std.testing.expectEqualStrings("iota", CopticReg.iota.name());
    try std.testing.expectEqualStrings("sima", CopticReg.sima.name());
}
