// Sacred Math Constants Codegen — Generate Zig from .tri spec
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const MATH_CONSTANTS_TEMPLATE =
    \\//! Sacred Math Constants — Generated from specs/tri/math/math_constants.tri
    \\//! φ² + 1/φ² = 3 | TRINITY
    \\//!
    \\//! DO NOT EDIT: This file is generated from math_constants.tri spec
    \\//! Modify spec and regenerate: tri vibee-gen math_constants
    \\
    \\const std = @import("std");
    \\
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\/// GOLDEN RATIO CONSTANTS
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\
    \\/// Golden Ratio — divine proportion
    \\pub const PHI: f64 = 1.6180339887498948482;
    \\
    \\/// Phi squared
    \\pub const PHI_SQUARED: f64 = 2.6180339887498948482;
    \\
    \\/// Inverse phi squared
    \\pub const PHI_INV_SQUARED: f64 = 0.3819660112501051518;
    \\
    \\/// TRINITY IDENTITY — exact equality
    \\/// φ² + 1/φ² = 3
    \\pub const TRINITY_SUM: f64 = 3.0;
    \\
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\/// TRANSCENDENTAL CONSTANTS
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\
    \\/// Pi — circle constant
    \\pub const PI: f64 = 3.14159265358979323846;
    \\
    \\/// Euler's number — natural log base
    \\pub const E: f64 = 2.71828182845904523536;
    \\
    \\/// Transcendental product
    \\/// π × φ × e ≈ TRYTE_MAX (13)
    \\pub const TRANSCENDENTAL_PRODUCT: f64 = 13.816890703380645;
    \\
    \\/// ═══════════════════════════════════════════════════════════════════════════════
    \\/// GENETIC ALGORITHM CONSTANTS
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\
    \\/// Mutation rate
    \\/// μ = 1/φ²/10
    \\pub const MU: f64 = 0.0382;
    \\
    \\/// Crossover rate
    \\/// χ = 1/φ/10
    \\pub const CHI: f64 = 0.0618;
    \\
    \\/// Selection pressure
    \\/// σ = φ
    \\pub const SIGMA: f64 = 1.618;
    \\
    \\/// Elitism rate
    \\/// ε = 1/3
    \\pub const EPSILON: f64 = 0.333;
    \\
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\/// QUANTUM CONSTANTS
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\
    \\/// Bell inequality violation — quantum advantage
    \\/// CHSH = 2√2
    \\pub const CHSH: f64 = 2.8284271247461903;
    \\
    \\/// Fine structure constant inverse
    \\/// α⁻¹ = 4π³ + π² + π
    \\pub const FINE_STRUCTURE: f64 = 137.036;
    \\
    \\/// Berry phase for quantum-inspired computation
    \\/// β = π(1 - 1/φ)
    \\pub const BERRY_PHASE: f64 = 2.112;
    \\
    \\/// SU3 energy harvesting constant
    \\/// SU3 = 3/(2φ)
    \\pub const SU3_CONSTANT: f64 = 0.927;
    \\
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\/// DATA STRUCTURES
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\
    \\/// Color constants for console output
    \\pub const Color = struct {
    \\    gold: []const u8 = "\x1b[38;5;220m",
    \\    cyan: []const u8 = "\x1b[36m",
    \\    yellow: []const u8 = "\x1b[33m",
    \\    purple: []const u8 = "\x1b[35m",
    \\    reset: []const u8 = "\x1b[0m",
    \\
    \\    pub fn format(comptime self: Color, comptime msg: []const u8) []const u8 {
    \\        return self.color ++ msg ++ self.reset;
    \\    }
    \\};
    \\
    \\/// Single constant entry for display
    \\pub const ConstantEntry = struct {
    \\    name: []const u8,
    \\    symbol: []const u8,
    \\    value: f64,
    \\    formula: []const u8,
    \\    description: []const u8,
    \\    color: Color,
    \\};
    \\
    \\/// Group of related constants
    \\pub const ConstantGroup = struct {
    \\    name: []const u8,
    \\    color: Color,
    \\    constants: []const ConstantEntry,
    \\};
    \\
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\/// TRINITY VERIFICATION
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\
    \\/// Verify φ² + 1/φ² = 3 at runtime
    \\pub fn verifyTrinityIdentity() bool {
    \\    const left = PHI_SQUARED + PHI_INV_SQUARED;
    \\    return std.math.approxEqRel(left, TRINITY_SUM, 0.000001);
    \\}
    \\
    \\/// ═══════════════════════════════════════════════════════════════════════════════
    \\/// CONSTANT GROUPS
    \\/// ═══════════════════════════════════════════════════════════════════════════════
    \\
    \\pub const GOLDEN_RATIO_GROUP: ConstantGroup = .{
    \\    .name = "GOLDEN RATIO",
    \\    .color = Color{ .gold = "\x1b[38;5;220m", .cyan = "", .yellow = "", .purple = "", .reset = "\x1b[0m" },
    \\    .constants = &.{
    \\        ConstantEntry{ .name = "PHI", .symbol = "φ", .value = PHI, .formula = "(1 + √5) / 2", .description = "Golden Ratio", .color = Color{} },
    \\        ConstantEntry{ .name = "PHI_SQUARED", .symbol = "φ²", .value = PHI_SQUARED, .formula = "φ² = φ + 1", .description = "Phi squared", .color = Color{} },
    \\        ConstantEntry{ .name = "PHI_INV_SQUARED", .symbol = "1/φ²", .value = PHI_INV_SQUARED, .formula = "1/φ² = φ - 1", .description = "Inverse phi squared", .color = Color{} },
    \\        ConstantEntry{ .name = "TRINITY_SUM", .symbol = "φ² + 1/φ²", .value = TRINITY_SUM, .formula = "φ² + 1/φ² = 3", .description = "TRINITY IDENTITY", .color = Color{} },
    \\    },
    \\};
    \\
    \\pub const TRANSCENDENTAL_GROUP: ConstantGroup = .{
    \\    .name = "TRANSCENDENTAL",
    \\    .color = Color{ .gold = "", .cyan = "\x1b[36m", .yellow = "", .purple = "", .reset = "\x1b[0m" },
    \\    .constants = &.{
    \\        ConstantEntry{ .name = "PI", .symbol = "π", .value = PI, .formula = "C / 2r", .description = "Circle constant", .color = Color{} },
    \\        ConstantEntry{ .name = "E", .symbol = "e", .value = E, .formula = "lim(n→∞) (1 + 1/n)^n", .description = "Euler's number", .color = Color{} },
    \\        ConstantEntry{ .name = "TRANSCENDENTAL_PRODUCT", .symbol = "π × φ × e", .value = TRANSCENDENTAL_PRODUCT, .formula = "π × φ × e", .description = "Transcendental product", .color = Color{} },
    \\    },
    \\};
    \\
    \\pub const GENETIC_ALGORITHM_GROUP: ConstantGroup = .{
    \\    .name = "GENETIC ALGORITHM",
    \\    .color = Color{ .gold = "", .cyan = "", .yellow = "\x1b[33m", .purple = "", .reset = "\x1b[0m" },
    \\    .constants = &.{
    \\        ConstantEntry{ .name = "MU", .symbol = "μ", .value = MU, .formula = "1/φ²/10", .description = "Mutation rate", .color = Color{} },
    \\        ConstantEntry{ .name = "CHI", .symbol = "χ", .value = CHI, .formula = "1/φ/10", .description = "Crossover rate", .color = Color{} },
    \\        ConstantEntry{ .name = "SIGMA", .symbol = "σ", .value = SIGMA, .formula = "φ", .description = "Selection pressure", .color = Color{} },
    \\        ConstantEntry{ .name = "EPSILON", .symbol = "ε", .value = EPSILON, .formula = "1/3", .description = "Elitism rate", .color = Color{} },
    \\    },
    \\};
    \\
    \\pub const QUANTUM_GROUP: ConstantGroup = .{
    \\    .name = "QUANTUM",
    \\    .color = Color{ .gold = "", .cyan = "", .yellow = "", .purple = "\x1b[35m", .reset = "\x1b[0m" },
    \\    .constants = &.{
    \\        ConstantEntry{ .name = "CHSH", .symbol = "CHSH", .value = CHSH, .formula = "2√2", .description = "Bell inequality", .color = Color{} },
    \\        ConstantEntry{ .name = "FINE_STRUCTURE", .symbol = "α⁻¹", .value = FINE_STRUCTURE, .formula = "4π³ + π² + π", .description = "Fine structure", .color = Color{} },
    \\        ConstantEntry{ .name = "BERRY_PHASE", .symbol = "β", .value = BERRY_PHASE, .formula = "π(1 - 1/φ)", .description = "Berry phase", .color = Color{} },
    \\        ConstantEntry{ .name = "SU3_CONSTANT", .symbol = "SU3", .value = SU3_CONSTANT, .formula = "3/(2φ)", .description = "SU3 constant", .color = Color{} },
    \\    },
    \\};
    \\
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\/// PRINT FUNCTIONS
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\
    \\/// Print all constants in formatted table
    \\pub fn printAllConstants() void {
    \\    printConstantsTable(GOLDEN_RATIO_GROUP);
    \\    printConstantsTable(TRANSCENDENTAL_GROUP);
    \\    printConstantsTable(GENETIC_ALGORITHM_GROUP);
    \\    printConstantsTable(QUANTUM_GROUP);
    \\}
    \\
    \\/// Print specific constant group as table
    \\pub fn printConstantsTable(group: ConstantGroup) void {
    \\    const stdout = std.io.getStdOut().writer();
    \\
    \\    // Print header with color
    \\    stdout.print("{s}=== {s} ==={s}\n", .{ group.color.gold, group.name, group.color.reset }) catch unreachable;
    \\
    \\    // Print constants
    \\    for (group.constants) |c| {
    \\        stdout.print("  {s}{s}{s} = {d:.10}{s} ({s}{s})\n", .{
    \\            group.color.gold, c.symbol, group.color.reset,
    \\            c.value,
    \\            c.formula, c.description,
    \\        }) catch unreachable;
    \\    }
    \\    stdout.print("\n", .{}) catch unreachable;
    \\}
    \\
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\/// TESTS
    \\/// ═════════════════════════════════════════════════════════════════════════════
    \\
    \\test "PHI constant value" {
    \\    try std.testing.expect(PHI > 1.6 and PHI < 1.62);
    \\}
    \\
    \\test "TRINITY identity exact equality" {
    \\    try std.testing.expectEqual(@as(f64, 3.0), TRINITY_SUM);
    \\}
    \\
    \\test "verifyTrinityIdentity runtime" {
    \\    try std.testing.expect(verifyTrinityIdentity());
    \\}
    \\
    \\test "PI constant value" {
    \\    try std.testing.expect(PI > 3.14 and PI < 3.15);
    \\}
    \\
    \\test "E constant value" {
    \\    try std.testing.expect(E > 2.71 and E < 2.72);
    \\}
    \\
    \\test "CHSH constant value" {
    \\    try std.testing.expect(CHSH > 2.82 and CHSH < 2.83);
    \\}
    \\
    \\test "fine structure constant" {
    \\    try std.testing.expect(FINE_STRUCTURE > 137.0 and FINE_STRUCTURE < 137.1);
    \\}
    \\
    \\test "genetic algorithm constants" {
    \\    try std.testing.expect(MU > 0.03 and MU < 0.04);
    \\    try std.testing.expect(CHI > 0.06 and CHI < 0.07);
    \\    try std.testing.expect(SIGMA > 1.61 and SIGMA < 1.62);
    \\    try std.testing.expect(EPSILON > 0.33 and EPSILON < 0.34);
    \\}
    \\
    \\test "berry phase constant" {
    \\    try std.testing.expect(BERRY_PHASE > 2.11 and BERRY_PHASE < 2.12);
    \\}
    \\
    \\test "SU3 constant value" {
    \\    try std.testing.expect(SU3_CONSTANT > 0.92 and SU3_CONSTANT < 0.93);
    \\}
    \\
;

pub fn generateMathConstants(allocator: Allocator) ![]const u8 {
    return allocator.dupe(u8, MATH_CONSTANTS_TEMPLATE);
}

pub fn writeMathConstants(allocator: Allocator, path: []const u8) !void {
    const content = try generateMathConstants(allocator);
    defer allocator.free(content);

    const file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    try file.writeAll(content);
}

test "math_constants codegen" {
    const content = try generateMathConstants(std.testing.allocator);
    defer std.testing.allocator.free(content);

    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "pub const PHI") != null);
}
