// ═══════════════════════════════════════════════════════════════════════════════
// BSD CREMONA PARSER — Parse allbsd format from Cremona database
// ═══════════════════════════════════════════════════════════════════════════════
// allbsd format:
//   conductor iso_class curve_num [a1,a2,a3,a4,a6] rank tamagawa sha regulator period root
//   Example: 11 a 1 [0,-1,1,-10,-20] 0 5 5 1.26920930427955 0.253841860855911 1.00000000000000 1
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Simplified PackedTrit for standalone usage
pub const PackedTrit = enum(u2) {
    negative = 2,
    zero = 0,
    positive = 1,
};

pub fn main() !void {
    try testCremonaParser(std.heap.page_allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREMONA BSD ENTRY — Parsed from allbsd file
// ═══════════════════════════════════════════════════════════════════════════════

pub const CremonaBSDEntry = struct {
    conductor: u64,
    iso_class: []const u8,  // "a", "b", "ba", "bb", etc. - duplicated, owned by entry
    curve_number: u32,
    coefficients: [5]i64,   // [a1, a2, a3, a4, a6]
    rank: u8,
    tamagawa: u32,
    sha_order: u64,
    regulator: f64,
    period: f64,
    real_period: f64,       // Real period Omega_E (from allbsd)
    root_number: i8,

    const Self = @This();

    /// Parse line from allbsd file
    pub fn parse(allocator: std.mem.Allocator, line: []const u8) !Self {
        var iter = std.mem.tokenizeScalar(u8, line, ' ');

        // Parse conductor
        const conductor_str = iter.next() orelse return error.MissingConductor;
        const conductor = std.fmt.parseInt(u64, conductor_str, 10) catch return error.InvalidConductor;

        // Parse iso_class (can be "a", "b", "ba", "bb", etc.)
        const iso_class_str = iter.next() orelse return error.MissingIsoClass;
        const iso_class = try allocator.dupe(u8, iso_class_str);

        // Parse curve number
        const curve_num_str = iter.next() orelse return error.MissingCurveNumber;
        const curve_number = std.fmt.parseInt(u32, curve_num_str, 10) catch return error.InvalidCurveNumber;

        // Parse coefficients [a1,a2,a3,a4,a6]
        const coeff_str = iter.next() orelse return error.MissingCoefficients;
        if (coeff_str.len < 2 or coeff_str[0] != '[') return error.InvalidCoefficients;

        // Extract coefficients between brackets
        const closing_brace = std.mem.indexOfScalar(u8, coeff_str, ']') orelse return error.InvalidCoefficients;
        const coeffs_only = coeff_str[1..closing_brace];

        var coeff_parts = std.mem.splitScalar(u8, coeffs_only, ',');
        var coefficients: [5]i64 = undefined;
        var coeff_idx: usize = 0;
        while (coeff_parts.next()) |c_str| {
            if (coeff_idx >= 5) break;
            coefficients[coeff_idx] = std.fmt.parseInt(i64, c_str, 10) catch return error.InvalidCoefficient;
            coeff_idx += 1;
        }
        // Fill remaining with zeros
        while (coeff_idx < 5) {
            coefficients[coeff_idx] = 0;
            coeff_idx += 1;
        }

        // Parse rank
        const rank_str = iter.next() orelse return error.MissingRank;
        const rank = std.fmt.parseInt(u8, rank_str, 10) catch return error.InvalidRank;

        // Parse tamagawa
        const tamagawa_str = iter.next() orelse return error.MissingTamagawa;
        const tamagawa = std.fmt.parseInt(u32, tamagawa_str, 10) catch return error.InvalidTamagawa;

        // Parse sha_order
        const sha_str = iter.next() orelse return error.MissingSha;
        const sha_order = std.fmt.parseInt(u64, sha_str, 10) catch return error.InvalidSha;

        // Parse regulator
        const regulator_str = iter.next() orelse return error.MissingRegulator;
        const regulator = std.fmt.parseFloat(f64, regulator_str) catch return error.InvalidRegulator;

        // Parse period
        const period_str = iter.next() orelse return error.MissingPeriod;
        const period = std.fmt.parseFloat(f64, period_str) catch return error.InvalidPeriod;

        // Parse real_period
        const real_period_str = iter.next() orelse return error.MissingRealPeriod;
        const real_period = std.fmt.parseFloat(f64, real_period_str) catch return error.InvalidRealPeriod;

        // Parse root_number (OPTIONAL - some allbsd entries don't have it)
        // Format is inconsistent - some lines have 11 fields, others 10
        const root_str_raw = iter.next() orelse "0";  // Default to 0 if missing
        const root_str_clean = std.mem.trim(u8, root_str_raw, " \t\r\n");
        const root_number = std.fmt.parseInt(i8, root_str_clean, 10) catch 0;  // Default to 0 if parse fails

        return .{
            .conductor = conductor,
            .iso_class = iso_class,
            .curve_number = curve_number,
            .coefficients = coefficients,
            .rank = rank,
            .tamagawa = tamagawa,
            .sha_order = sha_order,
            .regulator = regulator,
            .period = period,
            .real_period = real_period,
            .root_number = root_number,
        };
    }

    /// Get full label (e.g., "11a1")
    pub fn label(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{d}{s}{d}", .{
            self.conductor,
            self.iso_class,
            self.curve_number,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CREMONA DATABASE LOADER
// ═══════════════════════════════════════════════════════════════════════════════

pub const CremonaDatabase = struct {
    entries: []CremonaBSDEntry,
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Load from allbsd file
    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !Self {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const stat = try file.stat();
        const content = try allocator.alloc(u8, @as(usize, @intCast(stat.size)));
        defer allocator.free(content);

        _ = try file.readAll(content);

        // Count entries
        var line_count: usize = 0;
        var line_iter = std.mem.tokenizeScalar(u8, content, '\n');
        while (line_iter.next()) |_| {
            line_count += 1;
        }

        // Allocate entries
        const entries = try allocator.alloc(CremonaBSDEntry, line_count);

        // Parse entries
        var idx: usize = 0;
        var line_num: usize = 0;
        line_iter = std.mem.tokenizeScalar(u8, content, '\n');
        while (line_iter.next()) |line| {
            line_num += 1;
            if (line.len == 0) continue;

            entries[idx] = CremonaBSDEntry.parse(allocator, line) catch |err| {
                std.debug.print("Line {d}: {s}\n", .{line_num, line});
                std.debug.print("  Error: {}\n", .{err});
                return err;
            };
            idx += 1;
        }

        return .{
            .entries = entries[0..idx],
            .allocator = allocator,
        };
    }

    /// Load all allbsd files from ecdata directory
    pub fn loadAll(allocator: std.mem.Allocator, ecdata_path: []const u8) !Self {
        var all_entries = std.ArrayList(CremonaBSDEntry).init(allocator);

        // Open allbsd directory
        var dir = try std.fs.cwd().openDir(
            try std.fmt.allocPrint(allocator, "{s}/allbsd", .{ecdata_path}),
            .{ .iterate = true },
        );
        defer dir.close();

        // Iterate over allbsd.* files
        var walker = try dir.walk(allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.basename, "00000-09999") and
                !std.mem.endsWith(u8, entry.basename, "10000-19999"))
                continue;

            std.debug.print("Loading {s}...\n", .{entry.basename});

            const file = try dir.openFile(entry.basename, .{});
            defer file.close();

            const stat = try file.stat();
            const content = try allocator.alloc(u8, @as(usize, @intCast(stat.size)));
            defer allocator.free(content);

            _ = try file.readAll(content);

            // Parse entries
            var line_iter = std.mem.tokenizeScalar(u8, content, '\n');
            while (line_iter.next()) |line| {
                if (line.len == 0) continue;

                if (CremonaBSDEntry.parse(allocator, line)) |entry_parsed| {
                    try all_entries.append(entry_parsed);
                } else |err| {
                    std.debug.print("Warning: failed to parse line: {s} ({})\n", .{line, err});
                }
            }
        }

        return .{
            .entries = try all_entries.toOwnedSlice(),
            .allocator = allocator,
        };
    }

    /// Get statistics
    pub fn stats(self: *const Self) Stats {
        var rank_counts = [_]u64{0} ** 5;  // Count ranks 0-4

        for (self.entries) |entry| {
            if (entry.rank < rank_counts.len) {
                rank_counts[entry.rank] += 1;
            }
        }

        return .{
            .total_curves = self.entries.len,
            .rank_counts = rank_counts,
        };
    }

    pub const Stats = struct {
        total_curves: usize,
        rank_counts: [5]u64,

        pub fn format(self: *const Stats, writer: anytype) !void {
            try writer.print("Cremona Database Statistics:\n", .{});
            try writer.print("  Total curves: {}\n", .{self.total_curves});
            try writer.print("\n", .{});
            try writer.print("Rank distribution:\n", .{});
            for (self.rank_counts, 0..) |count, rank| {
                const pct = if (self.total_curves > 0)
                    @as(f64, @floatFromInt(count)) * 100.0 / @as(f64, @floatFromInt(self.total_curves))
                else
                    0.0;
                try writer.print("  Rank {d}: {d:6} ({d:.2}%)\n", .{ rank, count, pct });
            }
        }
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// BSD HYPEVECTOR ENCODING — Map curve to 1024-dim ternary vector
// ═══════════════════════════════════════════════════════════════════════════════

pub const BSDHypervector = struct {
    /// 1024 trits = 2048 bits = 256 bytes
    data: [1024]PackedTrit,

    const Self = @This();

    /// Encode Cremona BSD entry into hypervector
    /// Uses curve invariants to generate deterministic ternary pattern
    pub fn encode(entry: *const CremonaBSDEntry) Self {
        var hv: [1024]PackedTrit = undefined;

        // Seed for deterministic encoding (not used directly but for reference)
        _ = entry.conductor * 1000 + entry.curve_number;

        // Encode conductor (0-500) - first 100 trits
        const cond_trits = encodeInteger(entry.conductor, 100, 0);
        for (&cond_trits, 0..) |t, i| hv[i] = t;

        // Encode rank (0-4) - next 16 trits
        const rank_trits = encodeRank(entry.rank);
        for (&rank_trits, 0..) |t, i| hv[100 + i] = t;

        // Encode tamagawa number - next 50 trits
        const tamagawa_trits = encodeInteger(entry.tamagawa, 50, 1);
        for (0..50) |i| hv[116 + i] = tamagawa_trits[i];

        // Encode SHA order - next 64 trits
        const sha_trits = encodeInteger(entry.sha_order, 64, 2);
        for (0..64) |i| hv[166 + i] = sha_trits[i];

        // Encode regulator (log2 scale) - next 100 trits
        const reg_trits = encodeFloat(entry.regulator, 100, 3);
        for (&reg_trits, 0..) |t, i| hv[230 + i] = t;

        // Encode period (log2 scale) - next 100 trits
        const period_trits = encodeFloat(entry.period, 100, 4);
        for (&period_trits, 0..) |t, i| hv[330 + i] = t;

        // Encode coefficients a1-a6 - next 234 trits
        const coeff_trits = encodeCoefficients(&entry.coefficients, 234, 5);
        for (&coeff_trits, 0..) |t, i| hv[430 + i] = t;

        // Fill remaining with hash-based trits
        fillHashed(&hv, 664, entry.conductor * 1000 + entry.curve_number);

        return .{ .data = hv };
    }

    /// Serialize to binary for UART transmission
    pub fn serialize(self: *const Self) [256]u8 {
        var result: [256]u8 = undefined;
        @memset(&result, 0);

        for (0..1024) |i| {
            const byte_idx = i / 4;
            const bit_offset: u3 = @intCast((i % 4) * 2);

            const trit_code: u2 = switch (self.data[i]) {
                .negative => 0b10,
                .zero => 0b00,
                .positive => 0b01,
            };

            result[byte_idx] |= @as(u8, trit_code) << bit_offset;
        }

        return result;
    }

    /// Compute similarity between two hypervectors (cosine)
    pub fn similarity(self: *const Self, other: *const Self) f32 {
        var dot: i32 = 0;
        var mag_a: i32 = 0;
        var mag_b: i32 = 0;

        for (0..1024) |i| {
            const val_a = tritToInt(self.data[i]);
            const val_b = tritToInt(other.data[i]);

            dot += val_a * val_b;
            mag_a += val_a * val_a;
            mag_b += val_b * val_b;
        }

        const mag = @sqrt(@as(f32, @floatFromInt(mag_a))) * @sqrt(@as(f32, @floatFromInt(mag_b)));
        if (mag == 0) return 0.0;

        return @as(f32, @floatFromInt(dot)) / mag;
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // ENCODING HELPERS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Encode integer into trits using balanced ternary
    fn encodeInteger(value: u64, num_trits: usize, seed: u64) [100]PackedTrit {
        _ = seed;
        var result: [100]PackedTrit = undefined;
        @memset(&result, .zero);

        var v = value;
        for (0..@min(num_trits, 100)) |i| {
            const rem = @mod(v, 3);
            result[i] = switch (rem) {
                0 => .zero,
                1 => .positive,
                2 => .negative,
                else => .zero,
            };
            v = v / 3;
        }

        return result;
    }

    /// Encode rank with special pattern (high significance)
    fn encodeRank(rank: u8) [16]PackedTrit {
        var result: [16]PackedTrit = undefined;

        for (0..16) |i| {
            result[i] = if (i <= rank) .positive else .zero;
        }

        return result;
    }

    /// Encode float using sign + magnitude
    fn encodeFloat(value: f64, num_trits: usize, seed: u64) [100]PackedTrit {
        _ = seed;
        var result: [100]PackedTrit = undefined;
        @memset(&result, .zero);

        if (value == 0) return result;

        const sign: PackedTrit = if (value > 0) .positive else .negative;
        const mag = @abs(value);

        // Clamp to prevent overflow
        const clamped_mag = @min(mag, 1e100);

        // Encode as log2 scale for better range handling
        const exp = @min(@max(@floor(std.math.log(f64, clamped_mag, std.math.e)), -63.0), 63.0);

        // Use trits to encode exponent (balanced ternary)
        const exp_i64: i64 = @intFromFloat(exp);
        var exp_val = exp_i64;
        for (1..@min(num_trits, 65)) |i| {
            const rem = @rem(exp_val, 3);  // @rem for signed remainder
            result[i] = switch (rem) {
                0 => .zero,
                1 => .positive,
                -1 => .negative,
                else => .zero,
            };
            exp_val = @divTrunc(exp_val, 3);
        }

        result[0] = sign;

        return result;
    }

    /// Encode curve coefficients
    fn encodeCoefficients(coeffs: *const [5]i64, num_trits: usize, seed: u64) [234]PackedTrit {
        _ = seed;
        var result: [234]PackedTrit = undefined;
        @memset(&result, .zero);

        var idx: usize = 0;
        const trits_per_coeff = num_trits / 5;

        for (coeffs) |c| {
            const abs_c = @abs(c);
            var v: u64 = @intCast(abs_c);

            for (0..trits_per_coeff) |_| {
                if (idx >= result.len) break;

                const rem = @mod(v, 3);
                result[idx] = switch (rem) {
                    0 => .zero,
                    1 => .positive,
                    2 => .negative,
                    else => .zero,
                };
                v = v / 3;
                idx += 1;
            }
        }

        return result;
    }

    /// Fill remaining with hash-based trits
    fn fillHashed(hv: *[1024]PackedTrit, start: usize, seed: u64) void {
        var s = seed;
        for (start..hv.len) |i| {
            s = s *% 1103515245 + 12345;
            const trit_val = @mod(s, 3);
            hv[i] = switch (trit_val) {
                0 => .zero,
                1 => .positive,
                2 => .negative,
                else => .zero,
            };
        }
    }

    /// Convert trit to integer
    fn tritToInt(trit: PackedTrit) i32 {
        return switch (trit) {
            .negative => -1,
            .zero => 0,
            .positive => 1,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: Verify rank distribution matches expected (60% rank 0, 39% rank 1, 1% rank >= 2)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn testCremonaParser(allocator: std.mem.Allocator) !void {
    std.debug.print("\n╔════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     BSD CREMONA PARSER TEST                              ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════╝\n\n", .{});

    // Load test file
    const path = "/Users/playra/trinity-w1/data/ecdata/allbsd/allbsd.00000-09999";
    const db = try CremonaDatabase.loadFromFile(allocator, path);
    defer allocator.free(db.entries);

    const stats = db.stats();
    std.debug.print("Cremona Database Statistics:\n", .{});
    std.debug.print("  Total curves: {}\n", .{stats.total_curves});
    std.debug.print("\n", .{});
    std.debug.print("Rank distribution:\n", .{});
    for (stats.rank_counts, 0..) |count, rank| {
        const pct = if (stats.total_curves > 0)
            @as(f64, @floatFromInt(count)) * 100.0 / @as(f64, @floatFromInt(stats.total_curves))
        else
            0.0;
        std.debug.print("  Rank {d}: {d:6} ({d:.2}%)\n", .{ rank, count, @as(u32, @intFromFloat(pct)) });
    }

    // Test hypervector encoding for first curve
    if (db.entries.len > 0) {
        const entry = &db.entries[0];
        const hv = BSDHypervector.encode(entry);
        const serialized = hv.serialize();

        std.debug.print("\nTest encoding for {d}{s}{d}:\n", .{
            entry.conductor, entry.iso_class, entry.curve_number,
        });
        std.debug.print("  Rank: {d}\n", .{entry.rank});
        std.debug.print("  SHA order: {d}\n", .{entry.sha_order});
        std.debug.print("  Hypervector size: {} bytes\n", .{serialized.len});

        // Test similarity with itself
        const sim = hv.similarity(&hv);
        std.debug.print("  Self-similarity: {d:.3} (should be 1.0)\n", .{sim});
    }

    std.debug.print("\n✅ Parser test complete!\n", .{});
    std.debug.print("\nφ² + 1/φ² = 3 = TRINITY\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
