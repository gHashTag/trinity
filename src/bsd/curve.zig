// ═══════════════════════════════════════════════════════════════════════════════
// BSD ELLIPTIC CURVE SCANNER - Core Curve Types and Arithmetic
// ═══════════════════════════════════════════════════════════════════════════════
// Elliptic curve E: y^2 = x^3 + ax + b over Q
// Birch and Swinnerton-Dyer conjecture verification
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CURVE LABEL - LMFDB format "11.a1", "37.a1", etc.
// ═══════════════════════════════════════════════════════════════════════════════

pub const CurveLabel = struct {
    conductor: u64,
    iso_class: []const u8, // "a1", "b2", etc. - owned slice
    number: u32 = 1, // Curve number within isogeny class
    label: []const u8 = "", // Full label string - owned slice
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Parse curve label from string "11.a1" or "37a1"
    pub fn parse(allocator: std.mem.Allocator, label_str: []const u8) !Self {
        var i: usize = 0;

        // Skip digits for conductor
        while (i < label_str.len and std.ascii.isDigit(label_str[i])) : (i += 1) {}
        const conductor_end = i;

        // Check for separator
        if (i < label_str.len and label_str[i] == '.') {
            i += 1; // Skip '.'
        }

        // Extract isogeny class
        const iso_start = i;
        while (i < label_str.len and std.ascii.isAlphanumeric(label_str[i])) : (i += 1) {}

        const conductor = try std.fmt.parseInt(u64, label_str[0..conductor_end], 10);
        const iso_class = try allocator.dupe(u8, label_str[iso_start..i]);
        const label = try allocator.dupe(u8, label_str);

        return .{
            .conductor = conductor,
            .iso_class = iso_class,
            .label = label,
            .allocator = allocator,
        };
    }

    /// Format label as string
    pub fn format(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{d}.{s}", .{ self.conductor, self.iso_class });
    }

    /// Free memory
    pub fn deinit(self: *const Self) void {
        self.allocator.free(self.iso_class);
        if (self.label.len > 0) self.allocator.free(self.label);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// POINT ON ELLIPTIC CURVE (simplified - using i128 instead of BigInt)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Point = struct {
    x: i128,
    y: i128,
    is_infinity: bool,

    const Self = @This();

    /// Create point at infinity
    pub fn infinity() Self {
        return .{
            .x = 0,
            .y = 0,
            .is_infinity = true,
        };
    }

    /// Create point from coordinates
    pub fn affine(x: i128, y: i128) Self {
        return .{
            .x = x,
            .y = y,
            .is_infinity = false,
        };
    }

    /// Check if point is on curve
    pub fn isOnCurve(self: Self, a: i64, b: i64) bool {
        if (self.is_infinity) return true;
        const rhs = (self.x * self.x % 1000000007 * self.x + @as(i128, a) * self.x + b) % 1000000007;
        const lhs = (self.y * self.y) % 1000000007;
        return @as(i128, @intCast(lhs)) == @as(i128, @intCast(rhs));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ELLIPTIC CURVE
// ═══════════════════════════════════════════════════════════════════════════════

pub const EllipticCurve = struct {
    a: i64,
    b: i64,
    discriminant: i64, // Delta = -16(4a^3 + 27b^2)
    conductor: u64,
    j_invariant: f64, // j = 1728 * 4a^3 / (4a^3 + 27b^2)
    label: CurveLabel,
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create curve from coefficients
    pub fn init(allocator: std.mem.Allocator, a: i64, b: i64) !Self {
        const discriminant = computeDiscriminant(a, b);
        const conductor = estimateConductor(discriminant);
        const j_inv = computeJInvariant(a, b);

        // Create default label
        const label = try CurveLabel.parse(allocator, "1.a1");
        errdefer label.deinit();

        return .{
            .a = a,
            .b = b,
            .discriminant = discriminant,
            .conductor = conductor,
            .j_invariant = j_inv,
            .label = label,
            .allocator = allocator,
        };
    }

    /// Create curve from label and coefficients
    pub fn fromLabel(allocator: std.mem.Allocator, label: CurveLabel, a: i64, b: i64) !Self {
        const discriminant = computeDiscriminant(a, b);
        const conductor = estimateConductor(discriminant);
        const j_inv = computeJInvariant(a, b);

        return .{
            .a = a,
            .b = b,
            .discriminant = discriminant,
            .conductor = conductor,
            .j_invariant = j_inv,
            .label = label,
            .allocator = allocator,
        };
    }

    /// Free memory
    pub fn deinit(self: *const Self) void {
        self.label.deinit();
    }

    /// Check if curve is non-singular (discriminant != 0)
    pub fn isNonSingular(self: *const Self) bool {
        return self.discriminant != 0;
    }

    /// Check if point is on curve
    pub fn containsPoint(self: *const Self, x: i128, y: i128) bool {
        const x_i64: i64 = @intCast(x);
        const y_i64: i64 = @intCast(y);
        const rhs = @as(i128, x_i64) * x_i64 % 1000000007 * x_i64 + @as(i128, self.a) * x_i64 + self.b;
        const lhs = @as(i128, y_i64) * y_i64;
        return @rem(lhs, 1000000007) == @rem(rhs, 1000000007);
    }
};

/// Compute discriminant Delta = -16(4a^3 + 27b^2)
fn computeDiscriminant(a: i64, b: i64) i64 {
    const four_a_cubed = 4 * a * a * a;
    const twenty_seven_b_squared = 27 * b * b;
    const delta = -16 * (four_a_cubed + twenty_seven_b_squared);
    return delta;
}

/// Compute j-invariant j = 1728 * 4a^3 / (4a^3 + 27b^2)
fn computeJInvariant(a: i64, b: i64) f64 {
    const four_a_cubed: f64 = @floatFromInt(4 * a * a * a);
    const twenty_seven_b_squared: f64 = @floatFromInt(27 * b * b);
    const denominator = four_a_cubed + twenty_seven_b_squared;

    if (denominator == 0) {
        return std.math.inf(f64);
    }

    return 1728.0 * four_a_cubed / denominator;
}

/// Estimate conductor from discriminant (simplified)
fn estimateConductor(discriminant: i64) u64 {
    const abs_disc = @abs(discriminant);

    // Simple heuristic based on discriminant size
    if (abs_disc == 0) return 1;

    // Approximate conductor using number of prime factors
    var n: u64 = 1;
    var d: u64 = @intCast(abs_disc);
    var p: u64 = 2;

    while (p * p <= d and d > 1) {
        var count: u32 = 0;
        while (d % p == 0) : (d /= p) {
            count += 1;
        }
        if (count > 0) {
            n *= p;
        }
        p += 1;
    }

    if (d > 1) n *= d;

    return @as(u64, @max(11, @as(i64, @intCast(n)) * 11));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "computeDiscriminant" {
    // y^2 = x^3 - x: Delta = -16(4*(-1)^3 + 27*0) = -16(-4) = 64
    const delta = computeDiscriminant(-1, 0);
    try std.testing.expectEqual(@as(i64, 64), delta);
}

test "computeJInvariant" {
    const j = computeJInvariant(-1, 0);
    try std.testing.expectEqual(@as(f64, 1728.0), j);
}

test "EllipticCurve.init" {
    const allocator = std.testing.allocator;
    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    try std.testing.expectEqual(@as(i64, -1), curve.a);
    try std.testing.expectEqual(@as(i64, 0), curve.b);
    try std.testing.expect(curve.isNonSingular());
}
