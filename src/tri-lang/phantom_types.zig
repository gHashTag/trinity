// ═══════════════════════════════════════════════════════════════════════════
// phantom_types.zig - Phantom Types for Bank Safety (Wave 2 Step 2)
// ═══════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Issue #411: Linear Types + Ownership Modes
//
// Phantom types enforce bank safety at compile time:
// - Banked<T, Bank> — value tagged with specific bank (0-8)
// - Bank0, Bank1, ..., Bank8 type-level bank identifiers
// - Cannot mix values from different banks without explicit transfer
// - TRI-27 lowering: bank number encoded in high bits of address
//
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════
// BANK TAGS — Type-level bank identifiers
// ═══════════════════════════════════════════════════════════════════════

/// Bank0 type tag (Coptic: ⲁ)
pub const Bank0 = struct {};
/// Bank1 type tag (Coptic: Ⲃ)
pub const Bank1 = struct {};
/// Bank2 type tag (Coptic: Ⲅ)
pub const Bank2 = struct {};
/// Bank3 type tag (Coptic: Ⲇ)
pub const Bank3 = struct {};
/// Bank4 type tag (Coptic: Ⲉ)
pub const Bank4 = struct {};
/// Bank5 type tag (Coptic: Ⲋ)
pub const Bank5 = struct {};
/// Bank6 type tag (Coptic: Ⲍ)
pub const Bank6 = struct {};
/// Bank7 type tag (Coptic: Ⲏ)
pub const Bank7 = struct {};
/// Bank8 type tag (Coptic: Ⲑ)
pub const Bank8 = struct {};

// ═══════════════════════════════════════════════════════════════════════
// BANKED VALUE — Value tagged with bank
// ═══════════════════════════════════════════════════════════════════════

/// Banked — value tagged with specific bank at type level
/// Bank parameter is phantom: only used for type checking, not stored
pub fn Banked(comptime T: type, comptime Bank: type) type {
    return struct {
        /// The actual value
        value: T,

        /// Create a new banked value
        pub fn init(v: T) @This() {
            return @This(){ .value = v };
        }

        /// Get the bank number (0-8)
        pub fn bankNumber() usize {
            return comptime bankFromType(Bank);
        }

        /// Transfer value to different bank (requires explicit operation)
        pub fn transferTo(self: @This(), comptime NewBank: type) Banked(T, NewBank) {
            return Banked(T, NewBank){ .value = self.value };
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════
// BANK TYPE UTILITIES
// ═══════════════════════════════════════════════════════════════════════

/// Get bank number from type tag (comptime)
pub fn bankFromType(comptime Bank: type) usize {
    if (Bank == Bank0) return 0;
    if (Bank == Bank1) return 1;
    if (Bank == Bank2) return 2;
    if (Bank == Bank3) return 3;
    if (Bank == Bank4) return 4;
    if (Bank == Bank5) return 5;
    if (Bank == Bank6) return 6;
    if (Bank == Bank7) return 7;
    if (Bank == Bank8) return 8;
    @compileError("Invalid bank type - must be Bank0 through Bank8");
}

/// Get bank type from number (comptime)
pub fn bankFromNumber(comptime n: usize) type {
    return switch (n) {
        0 => Bank0,
        1 => Bank1,
        2 => Bank2,
        3 => Bank3,
        4 => Bank4,
        5 => Bank5,
        6 => Bank6,
        7 => Bank7,
        8 => Bank8,
        else => @compileError("Bank number must be 0-8"),
    };
}

/// Check if two banked values are from same bank (comptime)
pub fn isSameBank(comptime BankA: type, comptime BankB: type) bool {
    return bankFromType(BankA) == bankFromType(BankB);
}

// ═══════════════════════════════════════════════════════════════════════
// BANK OPERATIONS — Safe operations across banks
// ═══════════════════════════════════════════════════════════════════════

/// Add two banked values (must be from same bank)
pub fn addBanked(
    comptime T: type,
    comptime Bank: type,
    a: Banked(T, Bank),
    b: Banked(T, Bank),
) Banked(T, Bank) {
    const result = a.value + b.value;
    return Banked(T, Bank).init(result);
}

/// Subtract two banked values (must be from same bank)
pub fn subBanked(
    comptime T: type,
    comptime Bank: type,
    a: Banked(T, Bank),
    b: Banked(T, Bank),
) Banked(T, Bank) {
    const result = a.value - b.value;
    return Banked(T, Bank).init(result);
}

/// Combine values from different banks (explicit cross-bank operation)
/// Result goes to first bank
pub fn crossBankAdd(
    comptime T: type,
    comptime BankA: type,
    comptime BankB: type,
    a: Banked(T, BankA),
    b: Banked(T, BankB),
) Banked(T, BankA) {
    const result = a.value + b.value;
    return Banked(T, BankA).init(result);
}

// ═══════════════════════════════════════════════════════════════════════
// TRI-27 LOWERING
// ═══════════════════════════════════════════════════════════════════════

/// Lowered banked value for TRI-27 VM
/// Bank encoded in high bits (bits 12-14 for 9 banks)
pub const LoweredBanked = struct {
    /// Value (lower 12 bits)
    value: u16,
    /// Bank number (0-8, encoded in bits 12-14)
    bank: u4,
};

/// Lower banked value to TRI-27 representation
pub fn lowerBankedToTRI27(comptime T: type, comptime Bank: type, banked: Banked(T, Bank)) LoweredBanked {
    return LoweredBanked{
        .value = @intCast(banked.value),
        .bank = @intCast(bankFromType(Bank)),
    };
}

/// Get TRI-27 register address for banked value
/// Format: [bank:3bits][offset:12bits]
pub fn bankedAddress(bank: u4, offset: u12) u16 {
    return (@as(u16, bank) << 12) | offset;
}

// ═══════════════════════════════════════════════════════════════════════
// EXAMPLE USAGE (as comments)
// ═══════════════════════════════════════════════════════════════════════

// Example 1: Create banked values
// In Zig:
// ```
// var x = Banked(i32, Bank0).init(42);
// var y = Banked(i32, Bank0).init(10);
// var z = addBanked(i32, Bank0, x, y); // OK: same bank
// ```
//
// Example 2: Cannot mix banks directly
// ```
// var a = Banked(i32, Bank0).init(42);
// var b = Banked(i32, Bank1).init(10);
// var c = addBanked(i32, Bank0, a, b); // COMPILE ERROR: different banks
// ```
//
// Example 3: Explicit cross-bank operation
// ```
// var a = Banked(i32, Bank0).init(42);
// var b = Banked(i32, Bank1).init(10);
// var c = crossBankAdd(i32, Bank0, Bank1, a, b); // OK: explicit
// ```

// ═══════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════

test "banked_value_init" {
    const value = Banked(i32, Bank0).init(42);
    try std.testing.expectEqual(@as(i32, 42), value.value);
}

test "bank_number_from_type" {
    try std.testing.expectEqual(@as(usize, 0), bankFromType(Bank0));
    try std.testing.expectEqual(@as(usize, 4), bankFromType(Bank4));
    try std.testing.expectEqual(@as(usize, 8), bankFromType(Bank8));
}

test "bank_from_number" {
    try std.testing.expect(Bank0 == bankFromNumber(0));
    try std.testing.expect(Bank4 == bankFromNumber(4));
    try std.testing.expect(Bank8 == bankFromNumber(8));
}

test "is_same_bank" {
    try std.testing.expect(isSameBank(Bank0, Bank0));
    try std.testing.expect(isSameBank(Bank3, Bank3));
    try std.testing.expect(!isSameBank(Bank0, Bank1));
    try std.testing.expect(!isSameBank(Bank4, Bank7));
}

test "add_banked_same_bank" {
    const a = Banked(i32, Bank2).init(30);
    const b = Banked(i32, Bank2).init(12);
    const result = addBanked(i32, Bank2, a, b);
    try std.testing.expectEqual(@as(i32, 42), result.value);
}

test "sub_banked_same_bank" {
    const a = Banked(i32, Bank5).init(50);
    const b = Banked(i32, Bank5).init(8);
    const result = subBanked(i32, Bank5, a, b);
    try std.testing.expectEqual(@as(i32, 42), result.value);
}

test "cross_bank_add" {
    const a = Banked(i32, Bank0).init(30);
    const b = Banked(i32, Bank3).init(12);
    const result = crossBankAdd(i32, Bank0, Bank3, a, b);
    try std.testing.expectEqual(@as(i32, 42), result.value);
}

test "transfer_to_bank" {
    const original = Banked(i32, Bank1).init(99);
    const transferred = original.transferTo(Bank7);
    try std.testing.expectEqual(@as(i32, 99), transferred.value);
}

test "lower_to_tri27" {
    const value = Banked(u16, Bank3).init(0x123);
    const lowered = lowerBankedToTRI27(u16, Bank3, value);
    try std.testing.expectEqual(@as(u16, 0x123), lowered.value);
    try std.testing.expectEqual(@as(u4, 3), lowered.bank);
}

test "banked_address" {
    const addr1 = bankedAddress(0, 0xFFF);
    try std.testing.expectEqual(@as(u16, 0x0FFF), addr1);

    const addr2 = bankedAddress(5, 0x123);
    try std.testing.expectEqual(@as(u16, 0x5123), addr2);

    const addr3 = bankedAddress(8, 0x000);
    try std.testing.expectEqual(@as(u16, 0x8000), addr3);
}
