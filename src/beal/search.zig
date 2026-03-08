// ═══════════════════════════════════════════════════════════════════════════════
// BEAL SEARCH ENGINE - Parallel Counterexample Scanner
// ═══════════════════════════════════════════════════════════════════════════════
// Multi-threaded search for Beal Conjecture counterexamples
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const gcd = @import("gcd.zig");
const mod_filter = @import("mod_filter.zig");
const bigint_verify = @import("bigint_verify.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SEARCH CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const SearchConfig = struct {
    max_base: u32 = 1000,
    min_exponent: u8 = 3,
    max_exponent: u8 = 10,
    num_threads: usize = 4,
    checkpoint_interval: u64 = 100000,

    pub fn fromEnv() SearchConfig {
        return .{};
    }
};

pub const SearchStats = struct {
    total_checked: std.atomic.Value(u64),
    candidates_found: std.atomic.Value(u64),
    gcd_rejections: std.atomic.Value(u64),
    modular_rejections: std.atomic.Value(u64),
    bigint_verifications: std.atomic.Value(u64),

    pub fn init() SearchStats {
        return .{
            .total_checked = std.atomic.Value(u64).init(0),
            .candidates_found = std.atomic.Value(u64).init(0),
            .gcd_rejections = std.atomic.Value(u64).init(0),
            .modular_rejections = std.atomic.Value(u64).init(0),
            .bigint_verifications = std.atomic.Value(u64).init(0),
        };
    }
};

pub const Counterexample = struct {
    a: u32,
    b: u32,
    c: u32,
    x: u8,
    y: u8,
    z: u8,

    pub fn format(self: *const Counterexample, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "{d}^{d} + {d}^{d} = {d}^{d}",
            .{ self.a, self.x, self.b, self.y, self.c, self.z },
        );
    }

    pub fn verify(self: *const Counterexample, allocator: std.mem.Allocator) !bool {
        // Use BigInt for exact verification
        return bigint_verify.verifyBealEquation(
            allocator,
            self.a,
            self.x,
            self.b,
            self.y,
            self.c,
            self.z,
        );
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WORK CHUNK FOR PARALLEL PROCESSING
// ═══════════════════════════════════════════════════════════════════════════════

pub const WorkChunk = struct {
    allocator: std.mem.Allocator,
    a_start: u32,
    a_end: u32,
    thread_id: usize,
    power_table: *const mod_filter.PowerTable,
    config: *const SearchConfig,
    stats: *SearchStats,
    results: std.ArrayList(Counterexample),

    pub fn init(
        allocator: std.mem.Allocator,
        a_start: u32,
        a_end: u32,
        thread_id: usize,
        power_table: *const mod_filter.PowerTable,
        config: *const SearchConfig,
        stats: *SearchStats,
    ) WorkChunk {
        return .{
            .allocator = allocator,
            .a_start = a_start,
            .a_end = a_end,
            .thread_id = thread_id,
            .power_table = power_table,
            .config = config,
            .stats = stats,
            .results = std.ArrayList(Counterexample).initCapacity(allocator, 0) catch unreachable,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEQUENTIAL SEARCH
// ═══════════════════════════════════════════════════════════════════════════════

/// Search a range of A values for counterexamples
pub fn searchRange(
    allocator: std.mem.Allocator,
    power_table: *const mod_filter.PowerTable,
    config: *const SearchConfig,
    stats: *SearchStats,
    a_start: u32,
    a_end: u32,
) ![]Counterexample {
    var results = try std.ArrayList(Counterexample).initCapacity(allocator, 16);
    errdefer results.deinit(allocator);

    var a: u32 = a_start;
    while (a < a_end) : (a += 1) {
        // A must be at least 2
        if (a < 2) continue;

        var b: u32 = 2;
        while (b < config.max_base) : (b += 1) {
            // GCD filter: skip non-coprime pairs (~60% rejection)
            if (!gcd.isPairCoprime(a, b)) {
                _ = stats.gcd_rejections.fetchAdd(1, .monotonic);
                continue;
            }

            // Try all exponent combinations
            var x: u8 = config.min_exponent;
            while (x <= config.max_exponent) : (x += 1) {
                var y: u8 = config.min_exponent;
                while (y <= config.max_exponent) : (y += 1) {
                    // Compute A^x + B^y and check if it's a perfect power C^z
                    // Use u64 when possible, BigInt for overflow
                    const maybe_found = try checkPowerSumIsPerfectPower(
                        allocator,
                        a,
                        x,
                        b,
                        y,
                        config.min_exponent,
                        config.max_exponent,
                        config.max_base,
                    ) orelse continue;

                    const c = maybe_found.base;
                    const z = maybe_found.exp;

                    // Check if triple is coprime
                    if (!gcd.isCoprime(a, b, c)) {
                        _ = stats.gcd_rejections.fetchAdd(1, .monotonic);
                        continue;
                    }

                    // Modular filter
                    if (!mod_filter.checkModularAll(power_table, a, b, c, x, y, z)) {
                        _ = stats.modular_rejections.fetchAdd(1, .monotonic);
                        continue;
                    }

                    // Candidate found!
                    _ = stats.candidates_found.fetchAdd(1, .monotonic);

                    const counterexample = Counterexample{
                        .a = a,
                        .b = b,
                        .c = c,
                        .x = x,
                        .y = y,
                        .z = z,
                    };

                    std.debug.print("POTENTIAL COUNTEREXAMPLE: {d}^{d} + {d}^{d} = {d}^{d}\n", .{ a, x, b, y, c, z });

                    try results.append(allocator, counterexample);
                }
            }

            _ = stats.total_checked.fetchAdd(1, .monotonic);
        }
    }

    return results.toOwnedSlice(allocator);
}

const PerfectPower = struct { base: u32, exp: u8 };

/// Maximum bit length for valid C^z where C < max_base
fn maxBitLengthForValidPower(max_base: u32, max_exp: u8) u64 {
    const max_c = max_base - 1;
    const max_bits = @as(u64, @intCast(max_exp)) * @as(u64, @bitSizeOf(u32)) - @clz(max_c);
    return max_bits;
}

/// Check if A^x + B^y could possibly equal C^z for some C < max_base, z in [min_exp, max_exp]
/// Uses bit length estimation to quickly rule out impossible cases
inline fn couldBeValidPower(
    a: u32,
    x: u8,
    b: u32,
    y: u8,
    max_base: u32,
    min_exp: u8,
    max_exp: u8,
) bool {
    // Estimate bit length of A^x + B^y
    const a_bits = @as(u64, @intCast(x)) * (@as(u64, @bitSizeOf(u32)) - @clz(a));
    const b_bits = @as(u64, @intCast(y)) * (@as(u64, @bitSizeOf(u32)) - @clz(b));
    const sum_bits = @max(a_bits, b_bits) + 1; // +1 for addition

    // Maximum bit length for valid C^z
    const max_valid_bits = maxBitLengthForValidPower(max_base, max_exp);
    // Minimum bit length for valid C^z (using min_exp with smallest C)
    const min_valid_bits = @as(u64, @intCast(min_exp)) * 1; // log2(2) = 1

    return sum_bits >= min_valid_bits and sum_bits <= max_valid_bits;
}

/// Check if A^x + B^y is a perfect power C^z
/// Uses u64 when possible, falls back to BigInt for overflow
fn checkPowerSumIsPerfectPower(
    allocator: std.mem.Allocator,
    a: u32,
    x: u8,
    b: u32,
    y: u8,
    min_exp: u8,
    max_exp: u8,
    max_base: u32,
) !?PerfectPower {
    // First try u64 (fast path)
    const sum = computePowerSum(allocator, a, x, b, y) catch |err| {
        if (err == error.Overflow) {
            // Overflow: use BigInt path
            return try checkPowerSumIsPerfectPowerBigInt(allocator, a, x, b, y, min_exp, max_exp, max_base);
        }
        return err;
    };

    // u64 path: check if sum is a perfect power
    if (try findPerfectPower(allocator, sum, min_exp, max_exp)) |found| {
        if (found.base >= max_base) return null;
        return found;
    }

    return null;
}

/// BigInt path: check if A^x + B^y is a perfect power C^z
/// This is slower but handles arbitrary precision
/// OPTIMIZED: Uses logarithm estimation to directly compute C and z
fn checkPowerSumIsPerfectPowerBigInt(
    allocator: std.mem.Allocator,
    a: u32,
    x: u8,
    b: u32,
    y: u8,
    min_exp: u8,
    max_exp: u8,
    max_base: u32,
) !?PerfectPower {
    // Quick bit-length filter: rule out obviously impossible cases
    if (!couldBeValidPower(a, x, b, y, max_base, min_exp, max_exp)) {
        return null;
    }

    // Compute A^x + B^y using BigInt (done once)
    const a_pow = try bigint_verify.BigInt.pow(allocator, a, x);
    defer a_pow.deinit();

    const b_pow = try bigint_verify.BigInt.pow(allocator, b, y);
    defer b_pow.deinit();

    const sum = try a_pow.add(&b_pow);
    defer sum.deinit();

    // Use f64 approximation to estimate base C for each exponent
    const sum_approx = sum.toFloat64() orelse return null;

    // For each possible exponent, estimate base via logarithm
    var exp: u8 = min_exp;
    while (exp <= max_exp) : (exp += 1) {
        // Estimate base: C ≈ sum^(1/z)
        // Using: C = sum^(1/z) = exp(log(sum) / z)
        const log_sum = std.math.log(f64, std.math.e, sum_approx);
        const exp_result = log_sum / @as(f64, @floatFromInt(exp));
        const estimated_base_float = std.math.exp(exp_result);

        // Check nearby integer candidates (at most 3)
        const base_start = @as(u32, @intFromFloat(@max(1, estimated_base_float - 1)));
        const base_end = @min(max_base - 1, @as(u32, @intFromFloat(estimated_base_float)) + 2);

        var base: u32 = base_start;
        while (base <= base_end) : (base += 1) {
            // Quick modular filter check before BigInt computation
            // Use precomputed modular values if available
            const mod_valid = checkModularForBaseExp(a, x, b, y, base, exp);
            if (!mod_valid) continue;

            // Verify: base^exp == sum?
            const verify = try bigint_verify.BigInt.pow(allocator, base, exp);
            defer verify.deinit();
            if (verify.eq(&sum)) {
                return PerfectPower{ .base = base, .exp = exp };
            }
        }
    }

    return null;
}

/// Quick modular check for A^x + B^y ≡ C^z using small primes
/// Returns true if congruence holds
inline fn checkModularForBaseExp(a: u32, x: u8, b: u32, y: u8, c: u32, z: u8) bool {
    const primes = [3]u64{ 1009, 1013, 1019 }; // Small primes for quick check

    for (primes) |p| {
        const ax = powModFast(a, x, p);
        const by = powModFast(b, y, p);
        const cz = powModFast(c, z, p);

        if ((ax + by) % p != cz) {
            return false;
        }
    }
    return true;
}

/// Fast modular exponentiation for small primes
inline fn powModFast(base: u32, exp: u8, modulus: u64) u64 {
    const b = @as(u64, @intCast(base)) % modulus;
    if (b == 0) return 0;
    if (exp == 0) return 1;

    var result: u64 = 1;
    var current = b;
    var remaining = exp;

    while (remaining > 0) {
        if (remaining & 1 == 1) {
            result = (result * current) % modulus;
        }
        remaining >>= 1;
        current = (current * current) % modulus;
    }

    return result;
}

/// Find integer nth root of BigInt using binary search
fn bigintNthRoot(allocator: std.mem.Allocator, n: *const bigint_verify.BigInt, exp: u8) !?u32 {
    if (exp == 1) {
        if (n.fitsU64()) {
            const val = n.toU64();
            if (val <= std.math.maxInt(u32)) {
                return @as(u32, @intCast(val));
            }
        }
        return null;
    }

    // Binary search for base: base^exp ≈ n
    var low: u64 = 1;
    var high: u64 = 1000; // max_base for MVP

    while (low <= high) {
        const mid = low + (high - low) / 2;
        const power = try bigint_verify.BigInt.pow(allocator, mid, exp);
        defer power.deinit();

        const cmp = power.compare(n);
        if (cmp == .eq) {
            return @as(u32, @intCast(mid));
        } else if (cmp == .lt) {
            low = mid + 1;
        } else {
            if (high == mid) break; // Avoid infinite loop
            high = @max(mid, high) - 1;
        }
    }

    return null;
}

/// Find if n is a perfect power: n = c^z with z in [min_exp, max_exp]
/// Returns null if not a perfect power
fn findPerfectPower(allocator: std.mem.Allocator, n: u64, min_exp: u8, max_exp: u8) !?PerfectPower {
    if (n < 2) return null;

    var exp: u8 = min_exp;
    while (exp <= max_exp) : (exp += 1) {
        // Binary search for integer base: base^exp = n
        if (try integerNthRoot(allocator, n, exp)) |base| {
            if (std.math.pow(u64, base, exp) == n) {
                return PerfectPower{ .base = base, .exp = exp };
            }
        }
    }

    return null;
}

/// Compute integer nth root of n
fn integerNthRoot(allocator: std.mem.Allocator, n: u64, exp: u8) !?u32 {
    _ = allocator;
    if (n == 0) return 0;
    if (exp == 1) return @as(u32, @intCast(n));

    // Binary search
    var low: u64 = 1;
    var high: u64 = n;

    while (low <= high) {
        const mid = low + (high - low) / 2;
        const power = std.math.pow(u64, mid, exp);

        if (power == n) {
            return @as(u32, @intCast(mid));
        } else if (power < n) {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    return null;
}

/// Compute A^x + B^y (may overflow for large values)
fn computePowerSum(allocator: std.mem.Allocator, a: u32, x: u8, b: u32, y: u8) !u64 {
    _ = allocator;

    // For small bases/exponents, use direct computation
    const ax = std.math.pow(u64, @as(u64, a), @as(u64, x));
    const by = std.math.pow(u64, @as(u64, b), @as(u64, y));

    // Check for overflow
    const ov = @addWithOverflow(ax, by);
    if (ov[1] != 0) {
        return error.Overflow;
    }

    return ov[0];
}

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL SEARCH
// ═══════════════════════════════════════════════════════════════════════════════

/// Worker thread function
fn workerFn(chunk: *WorkChunk) void {
    const results = searchRange(
        chunk.allocator,
        chunk.power_table,
        chunk.config,
        chunk.stats,
        chunk.a_start,
        chunk.a_end,
    ) catch |err| {
        std.debug.print("Thread {} error: {}\n", .{ chunk.thread_id, err });
        return;
    };

    // Copy results to chunk's results array
    for (results) |r| {
        chunk.results.append(chunk.allocator, r) catch {};
    }
}

/// Run parallel search across multiple threads
pub fn searchParallel(
    allocator: std.mem.Allocator,
    power_table: *const mod_filter.PowerTable,
    config: *const SearchConfig,
) ![]Counterexample {
    const num_threads = config.num_threads;
    const actual_threads = @min(num_threads, @max(1, config.max_base / 10));

    if (actual_threads <= 1) {
        var stats = SearchStats.init();
        return searchRange(
            allocator,
            power_table,
            config,
            &stats,
            2,
            config.max_base,
        );
    }

    // Partition work
    const chunk_size = (config.max_base - 2 + actual_threads - 1) / actual_threads;

    var chunks = try std.ArrayList(WorkChunk).initCapacity(allocator, actual_threads);
    defer chunks.deinit(allocator);

    var threads = try std.ArrayList(std.Thread).initCapacity(allocator, actual_threads);
    defer threads.deinit(allocator);

    var stats = SearchStats.init();

    // Create work chunks
    var i: usize = 0;
    while (i < actual_threads) : (i += 1) {
        const a_start = @as(u32, @intCast(2 + i * chunk_size));
        const a_end = @as(u32, @intCast(@min(a_start + chunk_size, config.max_base)));

        try chunks.append(allocator, WorkChunk.init(
            allocator,
            a_start,
            a_end,
            i,
            power_table,
            config,
            &stats,
        ));
    }

    // Spawn threads
    for (chunks.items) |*chunk| {
        const thread = try std.Thread.spawn(
            .{},
            struct {
                fn inner(c: *WorkChunk) void {
                    workerFn(c);
                }
            }.inner,
            .{chunk},
        );
        try threads.append(allocator, thread);
    }

    // Wait for completion
    for (threads.items) |thread| {
        thread.join();
    }

    // Collect results
    var all_results = std.ArrayList(Counterexample).initCapacity(allocator, 0) catch unreachable;
    for (chunks.items) |*chunk| {
        try all_results.appendSlice(allocator, chunk.results.items);
        chunk.results.deinit(allocator);
    }

    // Print statistics
    try printStats(&stats, config);

    return all_results.toOwnedSlice(allocator);
}

/// Print search statistics
fn printStats(stats: *const SearchStats, config: *const SearchConfig) !void {
    _ = config;
    const total = stats.total_checked.load(.monotonic);
    const candidates = stats.candidates_found.load(.monotonic);
    const gcd_rej = stats.gcd_rejections.load(.monotonic);
    const mod_rej = stats.modular_rejections.load(.monotonic);

    std.debug.print(
        \\
        \\═══════════════════════════════════════════════════════════════
        \\ BEAL SEARCH RESULTS
        \\═══════════════════════════════════════════════════════════════
        \\
    , .{});

    std.debug.print("  Total checked:     {d}\n", .{total});
    std.debug.print("  Candidates found:  {d}\n", .{candidates});
    std.debug.print("  GCD rejections:    {d}\n", .{gcd_rej});
    std.debug.print("  Modular rejections: {d}\n", .{mod_rej});

    if (total > 0) {
        const gcd_rate: f64 = @as(f64, @floatFromInt(gcd_rej)) / @as(f64, @floatFromInt(total)) * 100;
        const mod_rate: f64 = @as(f64, @floatFromInt(mod_rej)) / @as(f64, @floatFromInt(total)) * 100;
        std.debug.print("  GCD filter rate:   {d:.1}%\n", .{gcd_rate});
        std.debug.print("  Modular filter rate: {d:.1}%\n", .{mod_rate});
    }

    std.debug.print(
        \\═══════════════════════════════════════════════════════════════
        \\
    , .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "integerNthRoot" {
    const allocator = std.testing.allocator;

    // Perfect cubes
    try std.testing.expectEqual(@as(u32, 3), (try integerNthRoot(allocator, 27, 3)).?);
    try std.testing.expectEqual(@as(u32, 5), (try integerNthRoot(allocator, 125, 3)).?);
    try std.testing.expectEqual(@as(u32, 10), (try integerNthRoot(allocator, 1000, 3)).?);

    // Perfect squares
    try std.testing.expectEqual(@as(u32, 7), (try integerNthRoot(allocator, 49, 2)).?);
    try std.testing.expectEqual(@as(u32, 12), (try integerNthRoot(allocator, 144, 2)).?);
}

test "findPerfectPower" {
    const allocator = std.testing.allocator;

    // 27 = 3^3
    const result1 = try findPerfectPower(allocator, 27, 3, 10);
    try std.testing.expect(result1 != null);
    try std.testing.expectEqual(@as(u32, 3), result1.?.base);
    try std.testing.expectEqual(@as(u8, 3), result1.?.exp);

    // 125 = 5^3
    const result2 = try findPerfectPower(allocator, 125, 3, 10);
    try std.testing.expect(result2 != null);
    try std.testing.expectEqual(@as(u32, 5), result2.?.base);

    // 100 = 10^2
    const result3 = try findPerfectPower(allocator, 100, 2, 5);
    try std.testing.expect(result3 != null);
    try std.testing.expectEqual(@as(u32, 10), result3.?.base);

    // 101 is not a perfect power
    const result4 = try findPerfectPower(allocator, 101, 2, 10);
    try std.testing.expect(result4 == null);
}

test "computePowerSum" {
    const allocator = std.testing.allocator;

    // 3^2 + 4^2 = 9 + 16 = 25
    const sum1 = try computePowerSum(allocator, 3, 2, 4, 2);
    try std.testing.expectEqual(@as(u64, 25), sum1);

    // 2^3 + 3^3 = 8 + 27 = 35
    const sum2 = try computePowerSum(allocator, 2, 3, 3, 3);
    try std.testing.expectEqual(@as(u64, 35), sum2);
}
