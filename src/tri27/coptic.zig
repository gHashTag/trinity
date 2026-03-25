// @origin(manual) @regen(manual-impl)
// COPTIC — TRI-27 Alphabet Register Naming (27 letters, 3 banks)
//
// Maps Coptic alphabet to TRI-27 register banks:
// - Bank 0 (α-η): registers r0-r7 (alpha-eta) — sacred/math constants
// - Bank 1 (ι-ρ): registers r8-r15 (iota-rho) — temporal/counters
// - Bank 2 (σ-ϡ): registers r16-r26 (sigma-shmima) — spatial/data
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Coptic alphabet letters mapped to TRI-27 registers
pub const CopticLetter = enum(u5) {
    // Bank 0: α-η (alpha through eta, r0-r7)
    alpha = 0,
    beta = 1,
    gamma = 2,
    delta = 3,
    epsilon = 4,
    digamma = 5,
    zeta = 6,
    eta = 7,

    // Bank 1: ι-ρ (iota through rho, r8-r15)
    theta = 8,
    iota = 9,
    kappa = 10,
    lambda = 11,
    mu = 12,
    nu = 13,
    xi = 14,
    omicron = 15,

    // Bank 2: σ-ϡ (sigma through shmima, r16-r26)
    pi = 16,
    koppa = 17,
    rho = 18,
    sigma = 19,
    tau = 20,
    upsilon = 21,
    phi = 22,
    chi = 23,
    psi = 24,
    omega = 25,
    shmima = 26,
};

/// TRI-27 register bank (for validation)
pub const Bank = enum(u2) {
    sacred = 0,   // α-η (r0-r7): sacred/math constants
    temporal = 1, // ι-ρ (r8-r15): temporal/counters
    spatial = 2,  // σ-ϡ (r16-r26): spatial/data
};

/// Get bank for a given Coptic letter
pub fn getBank(letter: CopticLetter) Bank {
    const reg = @intFromEnum(letter);
    if (reg <= 7) return .sacred;
    if (reg <= 15) return .temporal;
    return .spatial;
}

/// Validate that registers stay within their bank
/// Returns error if cross-bank operation detected
pub const BankError = error{
    CrossBankOperation,
    InvalidRegister,
};

/// Check if two registers are in the same bank
pub fn sameBank(reg1: u5, reg2: u5) bool {
    return getBankForReg(reg1) == getBankForReg(reg2);
}

/// Get bank for raw register number
pub fn getBankForReg(reg: u5) Bank {
    if (reg <= 7) return .sacred;
    if (reg <= 15) return .temporal;
    return .spatial;
}

/// Validate 3-bank constraint: operations within same bank only
pub fn validateOp(dst: u5, src1: u5, src2: u5) BankError!void {
    if (dst >= 27 or src1 >= 27 or src2 >= 27) return error.InvalidRegister;
    if (!sameBank(dst, src1) or !sameBank(dst, src2)) {
        return error.CrossBankOperation;
    }
}

/// Coptic letter name to register mapping
pub const letter_names = [_]struct { []const u8, CopticLetter }{
    .{ "α", .alpha },   .{ "alpha", .alpha },
    .{ "β", .beta },    .{ "beta", .beta },
    .{ "γ", .gamma },   .{ "gamma", .gamma },
    .{ "δ", .delta },   .{ "delta", .delta },
    .{ "ε", .epsilon }, .{ "epsilon", .epsilon },
    .{ "ϝ", .digamma }, .{ "digamma", .digamma },
    .{ "ζ", .zeta },    .{ "zeta", .zeta },
    .{ "η", .eta },     .{ "eta", .eta },

    .{ "θ", .theta },   .{ "theta", .theta },
    .{ "ι", .iota },    .{ "iota", .iota },
    .{ "κ", .kappa },   .{ "kappa", .kappa },
    .{ "λ", .lambda },  .{ "lambda", .lambda },
    .{ "μ", .mu },      .{ "mu", .mu },
    .{ "ν", .nu },      .{ "nu", .nu },
    .{ "ξ", .xi },      .{ "xi", .xi },
    .{ "ο", .omicron }, .{ "omicron", .omicron },

    .{ "π", .pi },      .{ "pi", .pi },
    .{ "ϟ", .koppa },   .{ "koppa", .koppa },
    .{ "ρ", .rho },     .{ "rho", .rho },
    .{ "σ", .sigma },   .{ "sigma", .sigma },
    .{ "τ", .tau },     .{ "tau", .tau },
    .{ "υ", .upsilon }, .{ "upsilon", .upsilon },
    .{ "φ", .phi },     .{ "phi", .phi },
    .{ "χ", .chi },     .{ "chi", .chi },
    .{ "ψ", .psi },     .{ "psi", .psi },
    .{ "ω", .omega },   .{ "omega", .omega },
    .{ "ϡ", .shmima },  .{ "shmima", .shmima },
};

/// Parse Coptic letter name to register number
pub fn parseLetter(name: []const u8) ?u5 {
    for (letter_names) |entry| {
        if (std.mem.eql(u8, entry.@"0", name)) {
            return @intFromEnum(entry.@"1");
        }
    }
    return null;
}

/// Get Coptic letter name for register
pub fn letterName(reg: u5) []const u8 {
    const letter: CopticLetter = @enumFromInt(@min(reg, 26));
    return @tagName(letter);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "coptic bank assignment" {
    try std.testing.expectEqual(Bank.sacred, getBank(.alpha));
    try std.testing.expectEqual(Bank.sacred, getBank(.eta));
    try std.testing.expectEqual(Bank.temporal, getBank(.theta));
    try std.testing.expectEqual(Bank.temporal, getBank(.omicron));
    try std.testing.expectEqual(Bank.spatial, getBank(.pi));
    try std.testing.expectEqual(Bank.spatial, getBank(.shmima));
}

test "coptic same_bank check" {
    try std.testing.expect(sameBank(0, 7));   // Both sacred
    try std.testing.expect(sameBank(8, 15));  // Both temporal
    try std.testing.expect(sameBank(16, 26)); // Both spatial
    try std.testing.expect(!sameBank(0, 8));  // sacred != temporal
    try std.testing.expect(!sameBank(8, 16)); // temporal != spatial
}

test "coptic validate cross-bank operations" {
    // Same bank: valid
    try validateOp(0, 1, 2);  // All sacred
    try validateOp(8, 9, 10); // All temporal
    try validateOp(16, 17, 18); // All spatial

    // Cross-bank: invalid
    try std.testing.expectError(error.CrossBankOperation, validateOp(0, 8, 1));
    try std.testing.expectError(error.CrossBankOperation, validateOp(8, 16, 9));

    // Invalid register
    try std.testing.expectError(error.InvalidRegister, validateOp(27, 0, 1));
}

test "coptic parse letter names" {
    try std.testing.expectEqual(@as(u5, 0), parseLetter("α"));
    try std.testing.expectEqual(@as(u5, 0), parseLetter("alpha"));
    try std.testing.expectEqual(@as(u5, 9), parseLetter("ι"));
    try std.testing.expectEqual(@as(u5, 9), parseLetter("iota"));
    try std.testing.expectEqual(@as(u5, 19), parseLetter("σ"));
    try std.testing.expectEqual(@as(u5, 26), parseLetter("ϡ"));
    try std.testing.expectEqual(@as(u5, 26), parseLetter("shmima"));
}

test "coptic letter name for register" {
    try std.testing.expectEqualStrings("alpha", letterName(0));
    try std.testing.expectEqualStrings("eta", letterName(7));
    try std.testing.expectEqualStrings("theta", letterName(8));
    try std.testing.expectEqualStrings("omicron", letterName(15));
    try std.testing.expectEqualStrings("pi", letterName(16));
    try std.testing.expectEqualStrings("shmima", letterName(26));
}
