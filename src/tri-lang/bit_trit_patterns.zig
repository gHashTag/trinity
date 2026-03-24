// ═══════════════════════════════════════════════════════════════════════════
// bit_trit_patterns.zig - Bit/Trit-Level Pattern Matching for Tri Language
// ═══════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Issue #409: Bit/Trit-Level Pattern Matching
//
// Implements:
// - Bit-level patterns: 0b0010xxxx (mask for don't-care bits)
// - Trit-level patterns: 0tPPN (ternary patterns with wildcards)
// - Typed holes: ?name for autogeneration
//
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Location in source file for error reporting
pub const SourceLocation = struct {
    line: usize,
    column: usize,
};

// ═══════════════════════════════════════════════════════════════════════
// BIT PATTERNS
// ═════════════════════════════════════════════════════════════════════════════════════

/// Bit-level pattern: 0b0010xxxx
/// Used for matching binary data with don't-care bits
pub const BitPattern = struct {
    /// The actual bits (x = 0 in don't-care positions)
    bits: u64,
    /// Mask: 1 = must match, 0 = don't-care (wildcard)
    mask: u64,
    /// Width of pattern in bits (max 64)
    width: u8,
    loc: SourceLocation,

    /// Create a new bit pattern
    pub fn init(bits: u64, mask: u64, width: u8, loc: SourceLocation) BitPattern {
        std.debug.assert(width <= 64, "BitPattern width cannot exceed 64 bits");
        std.debug.assert(mask < (@as(u64, 1) << @intCast(width)), "Mask exceeds pattern width");

        return .{
            .bits = bits & ((@as(u64, 1) << @intCast(width)) - 1),
            .mask = mask & ((@as(u64, 1) << @intCast(width)) - 1),
            .width = width,
            .loc = loc,
        };
    }

    /// Parse from string: "0b0010xxxx"
    pub fn parse(str: []const u8, loc: SourceLocation) !BitPattern {
        if (str.len < 3) return error.InvalidPattern;
        if (!std.mem.eql(u8, str[0..2], "0b")) return error.InvalidPattern;

        var bits: u64 = 0;
        var mask: u64 = 0;
        var width: u8 = 0;

        for (str[2..]) |c| {
            if (c == '0') {
                bits = (bits << 1) | 0;
                mask = (mask << 1) | 1; // must match 0
                width += 1;
            } else if (c == '1') {
                bits = (bits << 1) | 1;
                mask = (mask << 1) | 1; // must match 1
                width += 1;
            } else if (c == 'x' or c == 'X' or c == '?') {
                bits = bits << 1;
                mask = mask << 1; // don't-care
                width += 1;
            } else if (c == '_') {
                // skip separator
            } else {
                return error.InvalidPattern;
            }

            if (width > 64) return error.PatternTooWide;
        }

        return BitPattern{
            .bits = bits,
            .mask = mask,
            .width = width,
            .loc = loc,
        };
    }

    /// Check if value matches this pattern
    pub fn matches(self: BitPattern, value: u64) bool {
        const masked = value & self.mask;
        return masked == self.bits;
    }

    /// Extract matched bits from value
    pub fn extract(self: BitPattern, value: u64) u64 {
        return value & self.mask;
    }

    /// Format pattern as string
    pub fn format(self: BitPattern, allocator: std.mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8).init(allocator);
        try result.appendSlice("0b");

        var i: u8 = self.width;
        while (i > 0) : (i -= 1) {
            const bit_pos = i - 1;
            const mask_bit = (self.mask >> bit_pos) & 1;
            if (mask_bit == 0) {
                try result.append('x');
            } else {
                const bit_val = (self.bits >> bit_pos) & 1;
                try result.append(if (bit_val == 1) '1' else '0');
            }

            // Add separator every 4 bits
            if (bit_pos > 0 and bit_pos % 4 == 0) try result.append('_');
        }

        return result.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════
// TRIT PATTERNS
// ═════════════════════════════════════════════════════════════════════════════════════

/// Trit value: -1, 0, +1
pub const Trit = enum(i2) {
    Neg = -1,
    Zero = 0,
    Pos = 1,

    pub fn fromChar(c: u8) !Trit {
        return switch (c) {
            '-', 'N', 'n' => .Neg,
            '0', 'Z', 'z' => .Zero,
            '+', 'P', 'p' => .Pos,
            else => error.InvalidTrit,
        };
    }

    pub fn toChar(self: Trit) u8 {
        return switch (self) {
            .Neg => '-',
            .Zero => '0',
            .Pos => '+',
        };
    }
};

/// Trit-level pattern: 0tPPN
/// Used for matching ternary data with wildcards
pub const TritPattern = struct {
    /// The trit values (-1, 0, +1)
    trits: [27]i2, // Support up to 27-trit words
    /// Mask: true = must match, false = wildcard
    mask: [27]bool,
    /// Width of pattern in trits (max 27)
    width: u8,
    loc: SourceLocation,

    /// Create a new trit pattern
    pub fn init(width: u8, loc: SourceLocation) TritPattern {
        std.debug.assert(width <= 27, "TritPattern width cannot exceed 27 trits");

        return .{
            .trits = [_]i2{0} ** 27,
            .mask = [_]bool{false} ** 27,
            .width = width,
            .loc = loc,
        };
    }

    /// Parse from string: "0tPPN", "0tP_Z", "0t+0-"
    pub fn parse(str: []const u8, loc: SourceLocation) !TritPattern {
        if (str.len < 3) return error.InvalidPattern;
        if (!std.mem.eql(u8, str[0..2], "0t")) return error.InvalidPattern;

        var pattern = TritPattern.init(0, loc);

        for (str[2..], 0..) |c, i| {
            if (i >= 27) return error.PatternTooWide;

            if (c == '_') {
                continue; // skip separator
            }

            pattern.mask[i] = true; // must match by default
            pattern.trits[i] = try Trit.fromChar(c);
            pattern.width = @intCast(i + 1);
        }

        return pattern;
    }

    /// Check if value matches this pattern
    pub fn matches(self: TritPattern, value: []const i2) bool {
        if (value.len < self.width) return false;

        for (0..self.width) |i| {
            if (self.mask[i] and self.trits[i] != value[i]) {
                return false;
            }
        }
        return true;
    }

    /// Format pattern as string
    pub fn format(self: TritPattern, allocator: std.mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8).init(allocator);
        try result.appendSlice("0t");

        for (0..self.width) |i| {
            if (i > 0 and i % 3 == 0) try result.append('_'); // separator every 3 trits

            if (self.mask[i]) {
                try result.append(self.trits[i].toChar());
            } else {
                try result.append('?'); // wildcard
            }
        }

        return result.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════
// TYPED HOLES
// ═════════════════════════════════════════════════════════════════════════════════════

/// Typed hole: ?name or just ?
/// Used for autocode generation - agent fills in the implementation
pub const Hole = struct {
    /// Name of the hole (empty for anonymous holes)
    name: []const u8,
    /// Expected type (may be inferred from context)
    expected_type: ?[]const u8,
    /// Context for the agent (hints for generation)
    context: ?[]const u8,
    loc: SourceLocation,

    /// Create a new hole
    pub fn init(name: []const u8, loc: SourceLocation) Hole {
        return .{
            .name = name,
            .expected_type = null,
            .context = null,
            .loc = loc,
        };
    }

    /// Parse from string: "?name" or "?"
    pub fn parse(str: []const u8, loc: SourceLocation) !Hole {
        if (str.len < 1 or str[0] != '?') return error.InvalidPattern;

        const name = if (str.len > 1) str[1..] else "";

        return Hole{
            .name = name,
            .expected_type = null,
            .context = null,
            .loc = loc,
        };
    }

    /// Check if this is an anonymous hole
    pub fn isAnonymous(self: Hole) bool {
        return self.name.len == 0;
    }

    /// Format hole as string
    pub fn format(self: Hole, allocator: std.mem.Allocator) ![]u8 {
        if (self.isAnonymous()) {
            return try allocator.dupe(u8, "?");
        }
        const result = try std.ArrayList(u8).initCapacity(allocator, self.name.len + 1);
        try result.append('?');
        try result.appendSlice(self.name);
        return result.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════
// PATTERN MATCHER
// ═════════════════════════════════════════════════════════════════════════════════════

/// Pattern matcher for bit and trit patterns
pub const PatternMatcher = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Match a value against a list of patterns
    pub fn matchBit(self: Self, value: u64, patterns: []const BitPattern) ?usize {
        for (patterns, 0..) |pattern, i| {
            if (pattern.matches(value)) {
                return i;
            }
        }
        return null;
    }

    /// Match a ternary value against a list of patterns
    pub fn matchTrit(self: Self, value: []const i2, patterns: []const TritPattern) ?usize {
        for (patterns, 0..) |pattern, i| {
            if (pattern.matches(value)) {
                return i;
            }
        }
        return null;
    }

    /// Extract bits from value based on pattern
    pub fn extractBits(self: Self, pattern: BitPattern, value: u64) u64 {
        return pattern.extract(value);
    }
};

// ═══════════════════════════════════════════════════════════════════════
// PRECOMPILED PATTERNS (Common TRIT-27 opcodes)
// ═════════════════════════════════════════════════════════════════════════════════════

/// Precompiled TRI-27 opcode patterns for fast dispatch
pub const OpcodePatterns = struct {
    /// ADD opcode: 00000-------
    pub const ADD: BitPattern = BitPattern.init(0b00000_000000000, 0b11111_000000000, 18, .{ .line = 0, .column = 0 });

    /// SUB opcode: 00001-------
    pub const SUB: BitPattern = BitPattern.init(0b00001_000000000, 0b11111_000000000, 18, .{ .line = 0, .column = 0 });

    /// FADD opcode: 00010-------
    pub const FADD: BitPattern = BitPattern.init(0b00010_000000000, 0b11111_000000000, 18, .{ .line = 0, .column = 0 });

    /// DOT opcode: 00110-------
    pub const DOT: BitPattern = BitPattern.init(0b00110_000000000, 0b11111_000000000, 18, .{ .line = 0, .column = 0 });

    /// Match opcode by bits
    pub fn matchOpcode(bits: u18) ?[]const u8 {
        if (ADD.matches(@as(u64, bits))) return "ADD";
        if (SUB.matches(@as(u64, bits))) return "SUB";
        if (FADD.matches(@as(u64, bits))) return "FADD";
        if (DOT.matches(@as(u64, bits))) return "DOT";
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════

test "bit_pattern_parse_simple" {
    const pattern = try BitPattern.parse("0b1010", .{ .line = 1, .column = 1 });
    try std.testing.expectEqual(@as(u8, 4), pattern.width);
    try std.testing.expectEqual(@as(u64, 0b1010), pattern.bits);
    try std.testing.expectEqual(@as(u64, 0b1111), pattern.mask);
}

test "bit_pattern_parse_wildcard" {
    const pattern = try BitPattern.parse("0b10xx", .{ .line = 1, .column = 1 });
    try std.testing.expectEqual(@as(u8, 4), pattern.width);
    try std.testing.expectEqual(@as(u64, 0b1000), pattern.bits); // xx = 00
    try std.testing.expectEqual(@as(u64, 0b1100), pattern.mask); // xx = 00
}

test "bit_pattern_matches" {
    const pattern = try BitPattern.parse("0b10xx", .{ .line = 1, .column = 1 });

    try std.testing.expect(pattern.matches(0b1000));
    try std.testing.expect(pattern.matches(0b1001));
    try std.testing.expect(pattern.matches(0b1010));
    try std.testing.expect(pattern.matches(0b1011));

    try std.testing.expect(!pattern.matches(0b0000));
    try std.testing.expect(!pattern.matches(0b1100));
}

test "trit_pattern_parse_simple" {
    const pattern = try TritPattern.parse("0t+0-", .{ .line = 1, .column = 1 });
    try std.testing.expectEqual(@as(u8, 3), pattern.width);
    try std.testing.expectEqual(@as(i2, 1), pattern.trits[0]); // +
    try std.testing.expectEqual(@as(i2, 0), pattern.trits[1]); // 0
    try std.testing.expectEqual(@as(i2, -1), pattern.trits[2]); // -
}

test "trit_pattern_parse_wildcard" {
    const pattern = try TritPattern.parse("0t+??", .{ .line = 1, .column = 1 });
    try std.testing.expectEqual(@as(u8, 3), pattern.width);
    try std.testing.expectEqual(@as(i2, 1), pattern.trits[0]); // +
    try std.testing.expect(!pattern.mask[1]); // ? = wildcard
    try std.testing.expect(!pattern.mask[2]); // ? = wildcard
}

test "trit_pattern_matches" {
    const pattern = try TritPattern.parse("0t+0-", .{ .line = 1, .column = 1 });

    const value = [_]i2{ 1, 0, -1 };
    try std.testing.expect(pattern.matches(&value));

    const value2 = [_]i2{ 1, 1, -1 };
    try std.testing.expect(!pattern.matches(&value2));
}

test "hole_parse_anonymous" {
    const hole = try Hole.parse("?", .{ .line = 1, .column = 1 });
    try std.testing.expect(hole.isAnonymous());
    try std.testing.expectEqual(@as(usize, 0), hole.name.len);
}

test "hole_parse_named" {
    const hole = try Hole.parse("?phi_part", .{ .line = 1, .column = 1 });
    try std.testing.expect(!hole.isAnonymous());
    try std.testing.expectEqualStrings("phi_part", hole.name);
}

test "opcode_patterns_add" {
    const bits: u18 = 0b00000_000000000;
    const name = OpcodePatterns.matchOpcode(bits) orelse "UNKNOWN";
    try std.testing.expectEqualStrings("ADD", name);
}

test "opcode_patterns_fadd" {
    const bits: u18 = 0b00010_000000000;
    const name = OpcodePatterns.matchOpcode(bits) orelse "UNKNOWN";
    try std.testing.expectEqualStrings("FADD", name);
}
