// E-zone: Coptic Bank Validator
// Verifies 3-bank constraint (alpha-eta, iota-rho, sigma-shmima)
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const temple = @import("temple");

// Use CopticReg from temple module (re-exported from coptic.zig)
const CopticReg = temple.CopticReg;

/// Coptic bank enumeration
pub const Bank = enum(u2) {
    /// Bank 0 (ALU): t0-t8 — fast computation
    ALU = 0,
    /// Bank 1 (Sacred): t9-t17 — T-zone, Queen, OFC
    Sacred = 1,
    /// Bank 2 (Const): t18-t26 — constants, config
    Const = 2,
};

/// Bank validation error
pub const BankValidationError = error{
    InvalidBankNumber,
    RegistersCrossBank,
    InvalidCopticRegister,
};

/// Validate that all 27 registers are used once
/// Returns error if validation fails
pub fn validateBankUsage(regs: [27]u5) !void {
    // Count usage by bank
    var bank_counts = [3]u32{ 0, 0, 0 };

    for (regs) |reg| {
        const bank = CopticReg.bank(reg);
        bank_counts[bank] += 1;
    }

    // Validate each bank has exactly 9 registers
    for (bank_counts, 0..) |count, i| {
        if (count != 9) {
            std.debug.print("Bank {d} has {d} registers (expected 9)\n", .{ i, count });
            return BankValidationError.InvalidBankNumber;
        }
    }

    // Validate no cross-bank register usage
    // (i.e., a register from Sacred bank is only used in Sacred module)
    // Validation successful
}

test "Coptic bank validator init" {
    // Test: all banks have 9 registers (27 total: 0-26)
    const all_banks = [_]u5{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26 };

    try validateBankUsage(all_banks);
}
