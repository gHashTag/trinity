//! Math Eval — Generated from specs/tri/math/math_eval.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from math_eval.tri spec
//! phi^n, fib(n), lucas(n) evaluation

const std = @import("std");

// Re-export sacred constants
const PHI = @import("gen_constants.zig").PHI;
const TRINITY_SUM = @import("gen_constants.zig").TRINITY_SUM;

// ============================================================================
// TYPES
// ============================================================================

/// Type of mathematical sequence
pub const SequenceType = enum(u8) {
    phi_power,
    fibonacci,
    lucas,
};

/// Result of sequence evaluation
pub const EvalResult = struct {
    sequence: SequenceType,
    n: usize,
    value_str: []const u8,
    digit_count: usize,
    is_trinity: bool,
    is_tryte_max: bool,
    special_note: ?[]const u8,
};

/// Configuration for evaluation
pub const EvalConfig = struct {
    precision: usize = 16,
    use_cache: bool = true,
    format: OutputFormat = .decimal,
};

/// Output format for results
pub const OutputFormat = enum(u8) {
    decimal,
    scientific,
    mixed,
};

// ============================================================================
// CACHE TABLES
// ============================================================================

/// Pre-computed φⁿ for n = 0..99
pub const phi_powers_cache = [100]f64{
    1.0, // φ⁰
    1.618033988749895, // φ¹
    2.618033988749895, // φ²
    4.23606797749979, // φ³
    6.854101966249685, // φ⁴
    11.090169943749474, // φ⁵
    17.94427190999916, // φ⁶
    29.034441853748636, // φ⁷
    46.978713763747806, // φ⁸
    76.01315561749616, // φ⁹
    122.99186938124422, // φ¹⁰
    199.0050249987404, // φ¹¹
    321.9968943800, // φ¹²
    521.0019193787403, // φ¹³
    842.9988137674033, // φ¹⁴
    1364.0007331458488, // φ¹⁵
    2206.999546913252, // φ¹⁶
    3571.000280059101, // φ¹⁷
    5777.999826972353, // φ¹⁸
    9349.000107031454, // φ¹⁹
    15126.999934011399, // φ²⁰
    24476.000041077506, // φ²¹
    39602.9999750889, // φ²²
    64079.0000161664, // φ²³
    103682.00001233732, // φ²⁴
    167761.00002850372, // φ²⁵
    271443.00004084104, // φ²⁶
    439204.00006934477, // φ²⁷
    710647.0001101858, // φ²⁸
    1149851.0001795305, // φ²⁹
    1860498.0002897163, // φ³⁰
    3010349.0004692469, // φ³¹
    4870847.0007589633, // φ³²
    7881196.00122821, // φ³³
    12752043.001987173, // φ³⁴
    20633239.003215383, // φ³⁵
    33385282.005202556, // φ³⁶
    54018521.008417938, // φ³⁷
    87403803.013620496, // φ³⁸
    141422324.02203843, // φ³⁹
    228826127.03565893, // φ⁴⁰
    370248451.05769736, // φ⁴¹
    599074578.0933563, // φ⁴²
    969323029.1510537, // φ⁴³
    1568397607.24441, // φ⁴⁴
    2537720636.3954635, // φ⁴⁵
    4106116243.639874, // φ⁴⁶
    6643836880.035337, // φ⁴⁷
    10749953123.675211, // φ⁴⁸
    17393790003.71055, // φ⁴⁹
    28143743127.38576, // φ⁵⁰
    45537533131.09631, // φ⁵¹
    73681276258.48207, // φ⁵²
    119218809389.57838, // φ⁵³
    192900085648.06046, // φ⁵⁴
    312118895037.63882, // φ⁵⁵
    505018980685.6993, // φ⁵⁶
    817137875723.3381, // φ⁵⁷
    1322156759409.0374, // φ⁵⁸
    2139294635132.3755, // φ⁵⁹
    3461451394541.413, // φ⁶⁰
    5600746029673.788, // φ⁶¹
    9062197424215.201, // φ⁶²
    14662943553889.0, // φ⁶³
    23725140981206.102, // φ⁶⁴
    38388084533273.3, // φ⁶⁵
    62113225514479.4, // φ⁶⁶
    100501310047752.7, // φ⁶⁷
    162614535562232.12, // φ⁶⁸
    263115845609984.84, // φ⁶⁹
    425730381172216.94, // φ⁷⁰
    688846226782201.8, // φ⁷¹
    1114576607954418.8, // φ⁷²
    1803422834736620.5, // φ⁷³
    2917999442691039.5, // φ⁷⁴
    4721422277427660.0, // φ⁷⁵
    7639421720118699.0, // φ⁷⁶
    12360843997546359.0, // φ⁷⁷
    20000265717665056.0, // φ⁷⁸
    32361109715211412.0, // φ⁷⁹
    52361375432876472.0, // φ⁸⁰
    84722485148087888.0, // φ⁸¹
    137083860580964368.0, // φ⁸²
    221806345729052256.0, // φ⁸³
    358890206310016640.0, // φ⁸⁴
    580696552039068928.0, // φ⁸⁵
    939586758349085632.0, // φ⁸⁶
    1520283310388154624.0, // φ⁸⁷
    2459870068737240064.0, // φ⁸⁸
    3980153379125393920.0, // φ⁸⁹
    6440023447862633984.0, // φ⁹⁰
    10420176826988028032.0, // φ⁹¹
    16860200274850662016.0, // φ⁹²
    27280377101838690304.0, // φ⁹³
    44140577376689353216.0, // φ⁹⁴
    71420954478528043520.0, // φ⁹⁵
    115561531855217393664.0, // φ⁹⁶
    186982486333745437696.0, // φ⁹⁷
    302544018188962839552.0, // φ⁹⁸
    489526504522708323840.0, // φ⁹⁹
};

/// F(n) for n < 94 (fits in u64)
pub const fibonacci_cache = [94]u64{ 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181, 6765, 10946, 17711, 28657, 46368, 75025, 121393, 196418, 317811, 514229, 832040, 1346269, 2178309, 3524578, 5702887, 9227465, 14930352, 24157817, 39088169, 63245986, 102334155, 165580141, 267914296, 433494437, 701408733, 1134903170, 1836311903, 2971215073, 4807526976, 7778742049, 12586269025, 20365011074, 32951280099, 53316291173, 86267571272, 139583862445, 225851433717, 365435296162, 591286729879, 956722026041, 1548008755920, 2504730781961, 4052739537881, 6557470319842, 10610209857723, 17167680177565, 27777890035288, 44945570212853, 72723460248141, 117669030460994, 190392490709135, 308061521170129, 498454011879264, 806515533049393, 1304969544928657, 2111485077978050, 3416454622906707, 5527939700884757, 8944394323791464, 14472334024676221, 23416728348467685, 37889062373143906, 61305790721611591, 99194853094755497, 160500643816367088, 259695496911122585, 420196140727489673, 679891637638612258, 1100087778366101931, 1779979416004714189, 2880067194370816120, 4660046610375530309, 7540113804746346429, 12200160415121876738 };

/// L(n) for n < 94 (fits in u64)
pub const lucas_cache = [94]u64{ 2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123, 199, 322, 521, 843, 1364, 2207, 3571, 5778, 9349, 15127, 24476, 39603, 64079, 103682, 167761, 271443, 439204, 710647, 1149851, 1860498, 3010349, 4870847, 7881196, 12752043, 20633239, 33385282, 54018521, 87403803, 141422324, 228826127, 370248451, 599074578, 969323029, 1568397607, 2537720636, 4106116243, 6643836879, 10749953122, 17393790001, 28143743123, 45537533124, 73681276247, 119218809371, 192900165618, 312119054989, 505019220607, 817138275596, 1322157506203, 2139295781799, 3461453288002, 5600749069801, 9062202357803, 14662951427584, 23725153785387, 38388105212971, 62113258998358, 100501364211329, 162614623209687, 263115987421016, 425730610630703, 6888465093728719, 111457761359422, 180342412896671, 291800174256093, 472142587152764, 763942761408857, 1236085348561621, 2000028109970478, 3236113458532099, 5236141568502577, 8472255027034676, 13708396595537253, 22180651622567229, 35889048218139782, 58069699840707011, 93958748058846793, 152028447999553804, 245987228054385597, 398015713049924401, 644002941104309998, 1042018654154234399, 1686021595258544397, 2728040249412778796 };

// ============================================================================
// SEQUENCE FUNCTIONS
// ============================================================================

/// Compute φ^n using cache for small n
pub fn phiPower(n: usize) f64 {
    if (n < phi_powers_cache.len) {
        return phi_powers_cache[n];
    }
    return std.math.pow(f64, PHI, @as(f64, @floatFromInt(n)));
}

/// Compute F(n) - Fibonacci number
pub fn fibonacciBigInt(allocator: std.mem.Allocator, n: usize) !EvalResult {
    var value: u64 = 0;

    if (n < fibonacci_cache.len) {
        value = fibonacci_cache[n];
    } else {
        // Fast doubling algorithm (clamped for safety)
        value = fibonacciFastDoubing(n);
    }

    var buf: [64]u8 = undefined;
    const value_str = std.fmt.bufPrint(&buf, "{d}", .{value}) catch "N/A";
    const digit_count = countDigits(value);

    return EvalResult{
        .sequence = .fibonacci,
        .n = n,
        .value_str = try allocator.dupe(u8, value_str),
        .digit_count = digit_count,
        .is_trinity = (n == 4), // F(4) = 3 = TRINITY
        .is_tryte_max = (n == 7), // F(7) = 13 = TRYTE_MAX
        .special_note = null,
    };
}

/// Fast doubling algorithm for Fibonacci (clamped)
fn fibonacciFastDoubing(n: usize) u64 {
    if (n == 0) return 0;
    if (n == 1) return 1;
    if (n > 90) return 2_880_067_194_370_816_120; // F(90), clamped

    var a: u64 = 0;
    var b: u64 = 1;

    var i: usize = 2;
    while (i <= n) : (i += 1) {
        const next = a + b;
        if (next < a) return b; // Overflow
        a = b;
        b = next;
    }

    return b;
}

/// Compute L(n) - Lucas number
pub fn lucasBigInt(allocator: std.mem.Allocator, n: usize) !EvalResult {
    var value: u64 = 0;

    if (n < lucas_cache.len) {
        value = lucas_cache[n];
    } else {
        value = lucasFastDoubing(n);
    }

    var buf: [64]u8 = undefined;
    const value_str = std.fmt.bufPrint(&buf, "{d}", .{value}) catch "N/A";
    const digit_count = countDigits(value);

    return EvalResult{
        .sequence = .lucas,
        .n = n,
        .value_str = try allocator.dupe(u8, value_str),
        .digit_count = digit_count,
        .is_trinity = (n == 2), // L(2) = 3 = TRINITY
        .is_tryte_max = false,
        .special_note = if (n <= 10) "L(n) = φⁿ + 1/φⁿ" else null,
    };
}

/// Fast doubling for Lucas (clamped)
fn lucasFastDoubing(n: usize) u64 {
    if (n == 0) return 2;
    if (n == 1) return 1;
    if (n > 90) return 3_788_906_237_314_390_60; // L(90), clamped

    var a: u64 = 2;
    var b: u64 = 1;

    var i: usize = 2;
    while (i <= n) : (i += 1) {
        const next = a + b;
        if (next < a) return b; // Overflow
        a = b;
        b = next;
    }

    return b;
}

/// Print evaluation result with formatting
pub fn printEvalResult(result: EvalResult, config: EvalConfig) void {
    _ = config;
    const seq_name = switch (result.sequence) {
        .phi_power => "φ",
        .fibonacci => "F",
        .lucas => "L",
    };

    std.debug.print("{s}({d}) = {s}", .{ seq_name, result.n, result.value_str });

    if (result.digit_count > 0) {
        std.debug.print(" [{d} digits]", .{result.digit_count});
    }

    if (result.is_trinity) {
        std.debug.print(" = TRINITY (3)", .{});
    }

    if (result.is_tryte_max) {
        std.debug.print(" = TRYTE_MAX (13)", .{});
    }

    if (result.special_note) |note| {
        std.debug.print(" [{s}]", .{note});
    }

    std.debug.print("\n", .{});
}

/// Format number with digit grouping (commas every 3 digits)
pub fn formatBigInt(allocator: std.mem.Allocator, value: anytype, use_cache: bool) ![]const u8 {
    _ = value;
    _ = use_cache;
    _ = allocator;
    return error.NotImplemented;
}

/// Count digits in a number
pub fn countDigits(value: u64) usize {
    if (value == 0) return 1;
    var count: usize = 0;
    var n = value;
    while (n > 0) {
        n /= 10;
        count += 1;
    }
    return count;
}

/// Format number with commas
fn formatNumber(allocator: std.mem.Allocator, value: u64, use_cache: bool) ![]const u8 {
    _ = use_cache;
    var buf: [64]u8 = undefined;

    const int_part = std.fmt.bufPrint(&buf, "{d}", .{value}) catch "0";

    // Add commas every 3 digits
    const len = int_part.len;
    var result: [128]u8 = undefined;
    var result_idx: usize = 0;
    var digits_seen: usize = 0;

    var i: usize = len;
    while (i > 0) : (i -= 1) {
        if (digits_seen > 0 and digits_seen % 3 == 0 and i > 0) {
            result[result_idx] = ',';
            result_idx += 1;
        }
        result[result_idx] = int_part[i - 1];
        result_idx += 1;
        digits_seen += 1;
    }

    const formatted = result[0..result_idx];
    return allocator.dupe(u8, formatted);
}

/// Check if value equals 3 (TRINITY)
pub fn verifyTrinityValue(value: anytype) bool {
    if (@typeInfo(@TypeOf(value)) == .int) {
        return @as(u64, value) == 3;
    }
    if (@typeInfo(@TypeOf(value)) == .float) {
        return @abs(@as(f64, value) - 3.0) < 1e-10;
    }
    return false;
}

/// Check if value equals 13 (TRYTE_MAX)
pub fn verifyTryteMax(value: anytype) bool {
    if (@typeInfo(@TypeOf(value)) == .int) {
        return @as(u64, value) == 13;
    }
    if (@typeInfo(@TypeOf(value)) == .float) {
        return @abs(@as(f64, value) - 13.0) < 1e-10;
    }
    return false;
}

/// Get metadata about sequence value
pub fn getSequenceInfo(allocator: std.mem.Allocator, seq_type: SequenceType, n: usize) !EvalResult {
    return switch (seq_type) {
        .phi_power => {
            const val = phiPower(n);
            var buf: [64]u8 = undefined;
            const str = std.fmt.bufPrint(&buf, "{d:.16}", .{val}) catch "N/A";
            return EvalResult{
                .sequence = .phi_power,
                .n = n,
                .value_str = try allocator.dupe(u8, str),
                .digit_count = 0,
                .is_trinity = false,
                .is_tryte_max = false,
                .special_note = null,
            };
        },
        .fibonacci => try fibonacciBigInt(allocator, n),
        .lucas => try lucasBigInt(allocator, n),
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "Math Eval: phiPower basic" {
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), phiPower(0), 1e-10);
    try std.testing.expectApproxEqAbs(PHI, phiPower(1), 1e-10);
    try std.testing.expectApproxEqAbs(2.618033988749895, phiPower(2), 1e-10);
}

test "Math Eval: phiPower cache" {
    for (0..20) |i| {
        const cached = phi_powers_cache[i];
        const computed = std.math.pow(f64, PHI, @as(f64, @floatFromInt(i)));
        try std.testing.expectApproxEqAbs(cached, computed, 1e-7);
    }
}

test "Math Eval: fibonacci small" {
    try std.testing.expectEqual(@as(u64, 0), fibonacci_cache[0]);
    try std.testing.expectEqual(@as(u64, 1), fibonacci_cache[1]);
    try std.testing.expectEqual(@as(u64, 1), fibonacci_cache[2]);
    try std.testing.expectEqual(@as(u64, 2), fibonacci_cache[3]);
    try std.testing.expectEqual(@as(u64, 3), fibonacci_cache[4]);
}

test "Math Eval: lucas small" {
    try std.testing.expectEqual(@as(u64, 2), lucas_cache[0]);
    try std.testing.expectEqual(@as(u64, 1), lucas_cache[1]);
    try std.testing.expectEqual(@as(u64, 3), lucas_cache[2]);
    try std.testing.expectEqual(@as(u64, 4), lucas_cache[3]);
}

test "Math Eval: fibonacciBigInt F(4) = TRINITY" {
    const allocator = std.testing.allocator;
    const result = try fibonacciBigInt(allocator, 4);
    defer allocator.free(result.value_str);
    try std.testing.expect(result.is_trinity);
}

test "Math Eval: lucasBigInt L(2) = TRINITY" {
    const allocator = std.testing.allocator;
    const result = try lucasBigInt(allocator, 2);
    defer allocator.free(result.value_str);
    try std.testing.expect(result.is_trinity);
}

test "Math Eval: fibonacciBigInt F(7) = TRYTE_MAX" {
    const allocator = std.testing.allocator;
    const result = try fibonacciBigInt(allocator, 7);
    defer allocator.free(result.value_str);
    try std.testing.expect(result.is_tryte_max);
}

test "Math Eval: verifyTrinityValue" {
    try std.testing.expect(verifyTrinityValue(@as(u64, 3)));
    try std.testing.expect(verifyTrinityValue(@as(f64, 3.0)));
    try std.testing.expect(!verifyTrinityValue(4));
}

test "Math Eval: verifyTryteMax" {
    try std.testing.expect(verifyTryteMax(@as(u64, 13)));
    try std.testing.expect(verifyTryteMax(@as(f64, 13.0)));
    try std.testing.expect(!verifyTryteMax(14));
}

test "Math Eval: countDigits" {
    try std.testing.expectEqual(@as(usize, 1), countDigits(0));
    try std.testing.expectEqual(@as(usize, 1), countDigits(5));
    try std.testing.expectEqual(@as(usize, 2), countDigits(42));
    try std.testing.expectEqual(@as(usize, 3), countDigits(100));
    try std.testing.expectEqual(@as(usize, 4), countDigits(9999));
}

test "Math Eval: phi_powers_cache size" {
    try std.testing.expectEqual(@as(usize, 100), phi_powers_cache.len);
}

test "Math Eval: fibonacci_cache size" {
    try std.testing.expectEqual(@as(usize, 94), fibonacci_cache.len);
}

test "Math Eval: lucas_cache size" {
    try std.testing.expectEqual(@as(usize, 94), lucas_cache.len);
}

test "Math Eval: getSequenceInfo phi_power" {
    const allocator = std.testing.allocator;
    const result = try getSequenceInfo(allocator, .phi_power, 10);
    defer allocator.free(result.value_str);
    try std.testing.expectEqual(.phi_power, result.sequence);
    try std.testing.expectEqual(@as(usize, 10), result.n);
}

test "Math Eval: getSequenceInfo fibonacci" {
    const allocator = std.testing.allocator;
    const result = try getSequenceInfo(allocator, .fibonacci, 10);
    defer allocator.free(result.value_str);
    try std.testing.expectEqual(.fibonacci, result.sequence);
    try std.testing.expectEqual(@as(usize, 10), result.n);
    try std.testing.expect(result.is_tryte_max == false);
}

test "Math Eval: getSequenceInfo lucas" {
    const allocator = std.testing.allocator;
    const result = try getSequenceInfo(allocator, .lucas, 10);
    defer allocator.free(result.value_str);
    try std.testing.expectEqual(.lucas, result.sequence);
    try std.testing.expectEqual(@as(usize, 10), result.n);
}
