// ═══════════════════════════════════════════════════════════════════════════
// linear_types.zig - Linear Types + Ownership Modes for Tri Language
// ═══════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Issue #411: Linear Types + Ownership Modes
//
// Implements:
// - Linear types (consume-once semantics from Austral)
// - Ownership modes (let/inout/sink/set from Hylo)
// - Phantom types (for bank safety)
//
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Location in source file for error reporting
pub const SourceLocation = struct {
    line: usize,
    column: usize,
};

// ═══════════════════════════════════════════════════════════════════════
// OWNERSHIP MODES (Hylo-style)
// ═════════════════════════════════════════════════════════════════════════════════════

/// Ownership mode for variables
pub const OwnershipMode = enum(u2) {
    /// let x = ... — immutable, can be read multiple times
    /// Value is copied on read (for small types) or borrowed (for large types)
    Let = 0,

    /// inout x = ... — mutable reference
    /// Can be read/written multiple times, but never moved
    Inout = 1,

    /// sink x = ... — consumes value, must be used exactly once
    /// Linear: value MUST be consumed (moved, passed, or sunk)
    Sink = 2,

    /// set x = ... — mutable owned value
    /// Can be modified, but ownership stays with variable
    Set = 3,

    pub fn isLinear(self: OwnershipMode) bool {
        return self == .Sink;
    }

    pub fn isMutable(self: OwnershipMode) bool {
        return self == .Inout or self == .Set;
    }

    pub fn canRead(self: OwnershipMode) bool {
        return true; // All modes allow reading
    }

    pub fn canWrite(self: OwnershipMode) bool {
        return self == .Inout or self == .Set;
    }

    pub fn canMove(self: OwnershipMode) bool {
        return self == .Sink or self == .Set;
    }
};

// ═══════════════════════════════════════════════════════════════════════
// LINEAR TYPE ANNOTATION
// ═════════════════════════════════════════════════════════════════════════════════════

/// Linear type wrapper enforces consume-once semantics
/// Usage: linear T — must be consumed exactly once
pub fn Linear(comptime T: type) type {
    return struct {
        value: T,
        consumed: bool = false,

        const Self = @This();

        /// Consume the value, marking it as used
        pub fn consume(self: *Self) !T {
            if (self.consumed) {
                return error.LinearValueAlreadyConsumed;
            }
            self.consumed = true;
            return self.value;
        }

        /// Move value to new owner
        pub fn move(self: *Self) !Self {
            if (self.consumed) {
                return error.LinearValueAlreadyConsumed;
            }
            self.consumed = true;
            return Self{ .value = self.value, .consumed = false };
        }

        /// Check if value is still available
        pub fn isAvailable(self: *const Self) bool {
            return !self.consumed;
        }

        /// Create new linear value
        pub fn init(value: T) Self {
            return Self{ .value = value };
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════
// PHANTOM TYPES (Haskell-style for bank safety)
// ═════════════════════════════════════════════════════════════════════════════════════

/// Bank identifier for Coptic register safety
pub const Bank = enum(u2) {
    /// Bank 0: ALU registers (t0-t8, Ⲁ-Ⲑ)
    ALU = 0,

    /// Bank 1: Sacred accumulators (t9-t17, Ⲓ-Ⲣ)
    Sacred = 1,

    /// Bank 2: Constants (t18-t26, Ⲥ-Ϥ) — immutable
    Constant = 2,

    pub fn fromReg(reg: u5) Bank {
        return @intCast(reg / 9);
    }
};

/// Phantom type for bank-safe registers
/// Usage: Banked(T, Bank) — T is the value type, Bank is the bank
pub fn Banked(comptime T: type, comptime bank: Bank) type {
    return struct {
        value: T,

        const Self = @This();

        /// Get bank at compile time
        pub fn getBank() Bank {
            return bank;
        }

        /// Create new banked value
        pub fn init(value: T) Self {
            return Self{ .value = value };
        }

        /// Get the value
        pub fn get(self: *const Self) T {
            return self.value;
        }

        /// Set the value
        pub fn set(self: *Self, value: T) void {
            self.value = value;
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════
// LINEAR VARIABLE TRACKING
// ═════════════════════════════════════════════════════════════════════════════════════

/// Track linear variable usage during compilation
pub const LinearTracker = struct {
    allocator: std.mem.Allocator,
    /// Map from variable name to consumed state
    variables: std.StringHashMap(bool),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .variables = std.StringHashMap(bool).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.variables.deinit();
    }

    /// Declare a linear variable
    pub fn declare(self: *Self, name: []const u8) !void {
        try self.variables.put(name, false);
    }

    /// Mark variable as consumed
    pub fn consume(self: *Self, name: []const u8) !void {
        const entry = self.variables.get(name) orelse return error.VariableNotFound;
        if (entry) return error.LinearValueAlreadyConsumed;
        try self.variables.put(name, true);
    }

    /// Check if variable is consumed
    pub fn isConsumed(self: *const Self, name: []const u8) bool {
        const entry = self.variables.get(name) orelse return false;
        return entry;
    }

    /// Check if variable exists
    pub fn exists(self: *const Self, name: []const u8) bool {
        return self.variables.get(name) != null;
    }

    /// Verify all linear variables are consumed (end of scope)
    pub fn verifyAllConsumed(self: *const Self) !void {
        var iter = self.variables.iterator();
        while (iter.next()) |entry| {
            if (!entry.value_ptr.*) {
                std.debug.print("Linear variable '{s}' was not consumed\n", .{entry.key_ptr.*});
                return error.LinearVariableNotConsumed;
            }
        }
    }

    /// Clear all tracking (new scope)
    pub fn clear(self: *Self) void {
        self.variables.clearRetainingCapacity();
    }

    /// Get list of unconsumed variables
    pub fn getUnconsumed(self: *Self, allocator: std.mem.Allocator) ![][]const u8 {
        var list = std.ArrayList([]const u8).init(allocator);
        var iter = self.variables.iterator();
        while (iter.next()) |entry| {
            if (!entry.value_ptr.*) {
                try list.append(entry.key_ptr.*);
            }
        }
        return list.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════
// BANK SAFETY CHECKER
// ═════════════════════════════════════════════════════════════════════════════════════

/// Bank safety errors
pub const BankError = error{
    BankMismatch,
    ImmutableBankWrite,
    InvalidBankForOpcode,
};

/// Check if opcode is valid for given bank
pub fn validateOpcodeBank(opcode: []const u8, bank: Bank) !void {
    // ALU operations only work with Bank 0
    if (std.mem.eql(u8, opcode, "ADD") or
        std.mem.eql(u8, opcode, "SUB") or
        std.mem.eql(u8, opcode, "MUL") or
        std.mem.eql(u8, opcode, "DIV"))
    {
        if (bank != .ALU) return error.InvalidBankForOpcode;
    }

    // Sacred float operations only work with Bank 1
    if (std.mem.eql(u8, opcode, "FADD") or
        std.mem.eql(u8, opcode, "FMUL") or
        std.mem.eql(u8, opcode, "FDOT"))
    {
        if (bank != .Sacred) return error.InvalidBankForOpcode;
    }

    // Store operations cannot write to Bank 2 (immutable constants)
    if (std.mem.startsWith(u8, opcode, "ST_")) {
        if (bank == .Constant) return error.ImmutableBankWrite;
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MUST-USE ANNOTATION
// ═════════════════════════════════════════════════════════════════════════════════════

/// Must-use wrapper (Austral-style)
/// Forces the value to be used (checked at end of scope)
pub fn MustUse(comptime T: type) type {
    return struct {
        value: T,
        used: bool = false,

        const Self = @This();

        /// Get the value and mark as used
        pub fn get(self: *Self) T {
            self.used = true;
            return self.value;
        }

        /// Check if value was used
        pub fn isUsed(self: *const Self) bool {
            return self.used;
        }

        /// Create new must-use value
        pub fn init(value: T) Self {
            return Self{ .value = value };
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════
// BORROW CHECKER (Lightweight)
// ═════════════════════════════════════════════════════════════════════════════════════

/// Borrow type
pub const BorrowKind = enum {
    /// Shared borrow — multiple readers, no writers
    Shared,
    /// Mutable borrow — single writer, no other access
    Mutable,
};

/// Borrow tracking for references
pub const BorrowChecker = struct {
    allocator: std.mem.Allocator,
    /// Track active borrows: variable -> list of borrow kinds
    borrows: std.StringHashMap(std.ArrayList(BorrowKind)),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .borrows = std.StringHashMap(std.ArrayList(BorrowKind)).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.borrows.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.borrows.deinit();
    }

    /// Borrow a variable
    pub fn borrow(self: *Self, var_name: []const u8, kind: BorrowKind) !void {
        const entry = try self.borrows.getOrPut(var_name);

        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(BorrowKind).init(self.allocator);
        }

        // Check borrow rules
        for (entry.value_ptr.*.items) |existing| {
            if (kind == .Mutable or existing == .Mutable) {
                // Only one mutable borrow, or no mutable borrow with shared
                return error.CannotBorrow;
            }
        }

        try entry.value_ptr.*.append(kind);
    }

    /// Release a borrow
    pub fn release(self: *Self, var_name: []const u8) !void {
        const entry = self.borrows.get(var_name) orelse return error.BorrowNotFound;
        if (entry.items.len == 0) return error.NoActiveBorrow;
        _ = entry.orderedRemove(entry.items.len - 1);

        // Clean up if no more borrows
        if (entry.items.len == 0) {
            _ = self.borrows.remove(var_name);
        }
    }

    /// Check if variable has active borrows
    pub fn hasActiveBorrows(self: *const Self, var_name: []const u8) bool {
        const entry = self.borrows.get(var_name) orelse return false;
        return entry.items.len > 0;
    }

    /// Check if variable has mutable borrow
    pub fn hasMutableBorrow(self: *const Self, var_name: []const u8) bool {
        const entry = self.borrows.get(var_name) orelse return false;
        for (entry.items) |kind| {
            if (kind == .Mutable) return true;
        }
        return false;
    }
};

// ═══════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════

test "linear_type_consume_once" {
    const Lin = Linear(i32);
    var val = Lin.init(42);

    try std.testing.expectEqual(@as(i32, 42), val.consume());
    try std.testing.expectError(error.LinearValueAlreadyConsumed, val.consume());
}

test "linear_type_move" {
    const Lin = Linear(i32);
    var val1 = Lin.init(42);

    const val2 = try val1.move();
    try std.testing.expect(!val1.isAvailable());
    try std.testing.expect(val2.isAvailable());
    try std.testing.expectEqual(@as(i32, 42), val2.consume());
}

test "bank_from_reg" {
    try std.testing.expectEqual(Bank.ALU, Bank.fromReg(0));   // t0
    try std.testing.expectEqual(Bank.ALU, Bank.fromReg(8));   // t8
    try std.testing.expectEqual(Bank.Sacred, Bank.fromReg(9)); // t9
    try std.testing.expectEqual(Bank.Sacred, Bank.fromReg(17)); // t17
    try std.testing.expectEqual(Bank.Constant, Bank.fromReg(18)); // t18
    try std.testing.expectEqual(Bank.Constant, Bank.fromReg(26)); // t26
}

test "validate_opcode_bank_alu" {
    try validateOpcodeBank("ADD", .ALU);
    try validateOpcodeBank("SUB", .ALU);
    try std.testing.expectError(error.InvalidBankForOpcode, validateOpcodeBank("ADD", .Sacred));
    try std.testing.expectError(error.InvalidBankForOpcode, validateOpcodeBank("ADD", .Constant));
}

test "validate_opcode_bank_sacred" {
    try validateOpcodeBank("FADD", .Sacred);
    try validateOpcodeBank("FMUL", .Sacred);
    try std.testing.expectError(error.InvalidBankForOpcode, validateOpcodeBank("FADD", .ALU));
    try std.testing.expectError(error.InvalidBankForOpcode, validateOpcodeBank("FADD", .Constant));
}

test "validate_opcode_bank_immutable" {
    try std.testing.expectError(error.ImmutableBankWrite, validateOpcodeBank("ST_F", .Constant));
}

test "linear_tracker_consume" {
    const allocator = std.testing.allocator;
    var tracker = LinearTracker.init(allocator);
    defer tracker.deinit();

    try tracker.declare("x");
    try std.testing.expect(tracker.exists("x"));
    try std.testing.expect(!tracker.isConsumed("x"));

    try tracker.consume("x");
    try std.testing.expect(tracker.isConsumed("x"));

    try std.testing.expectError(error.LinearValueAlreadyConsumed, tracker.consume("x"));
}

test "linear_tracker_verify_all_consumed" {
    const allocator = std.testing.allocator;
    var tracker = LinearTracker.init(allocator);
    defer tracker.deinit();

    try tracker.declare("x");
    try tracker.declare("y");

    try tracker.consume("x");
    try std.testing.expectError(error.LinearVariableNotConsumed, tracker.verifyAllConsumed());

    try tracker.consume("y");
    try tracker.verifyAllConsumed();
}

test "linear_tracker_get_unconsumed" {
    const allocator = std.testing.allocator;
    var tracker = LinearTracker.init(allocator);
    defer tracker.deinit();

    try tracker.declare("x");
    try tracker.declare("y");
    try tracker.declare("z");

    try tracker.consume("y");

    const unconsumed = try tracker.getUnconsumed(allocator);
    defer {
        for (unconsumed) |u| allocator.free(u);
        allocator.free(unconsumed);
    }

    try std.testing.expectEqual(@as(usize, 2), unconsumed.len);
}

test "must_use_annotation" {
    const Mu = MustUse(i32);
    var val = Mu.init(42);

    try std.testing.expect(!val.isUsed());
    const v = val.get();
    try std.testing.expect(val.isUsed());
    try std.testing.expectEqual(@as(i32, 42), v);
}

test "borrow_checker_shared_borrows" {
    const allocator = std.testing.allocator;
    var checker = BorrowChecker.init(allocator);
    defer checker.deinit();

    try checker.borrow("x", .Shared);
    try checker.borrow("x", .Shared);
    try checker.borrow("x", .Shared);

    try std.testing.expect(checker.hasActiveBorrows("x"));
    try std.testing.expect(!checker.hasMutableBorrow("x"));

    try checker.release("x");
    try checker.release("x");
    try checker.release("x");
    try std.testing.expect(!checker.hasActiveBorrows("x"));
}

test "borrow_checker_mutable_borrow_exclusive" {
    const allocator = std.testing.allocator;
    var checker = BorrowChecker.init(allocator);
    defer checker.deinit();

    try checker.borrow("x", .Mutable);
    try std.testing.expect(checker.hasMutableBorrow("x"));

    // Cannot add any borrow while mutable is active
    try std.testing.expectError(error.CannotBorrow, checker.borrow("x", .Shared));
    try std.testing.expectError(error.CannotBorrow, checker.borrow("x", .Mutable));

    try checker.release("x");
    try std.testing.expect(!checker.hasActiveBorrows("x"));
}

test "ownership_mode_properties" {
    try std.testing.expect(OwnershipMode.Let.isLinear() == false);
    try std.testing.expect(OwnershipMode.Sink.isLinear() == true);

    try std.testing.expect(OwnershipMode.Let.canWrite() == false);
    try std.testing.expect(OwnershipMode.Inout.canWrite() == true);
    try std.testing.expect(OwnershipMode.Set.canWrite() == true);

    try std.testing.expect(OwnershipMode.Sink.canMove() == true);
    try std.testing.expect(OwnershipMode.Set.canMove() == true);
}

test "banked_type_phantom" {
    const BankedI32_ALU = Banked(i32, .ALU);
    const BankedI32_Sacred = Banked(i32, .Sacred);

    var val_alu = BankedI32_ALU.init(42);
    var val_sacred = BankedI32_Sacred.init(100);

    try std.testing.expectEqual(Bank.ALU, BankedI32_ALU.getBank());
    try std.testing.expectEqual(Bank.Sacred, BankedI32_Sacred.getBank());

    try std.testing.expectEqual(@as(i32, 42), val_alu.get());
    try std.testing.expectEqual(@as(i32, 100), val_sacred.get());
}
