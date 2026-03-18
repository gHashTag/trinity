// ═══════════════════════════════════════════════════════════════════════════════
// ZETA IMPORT — Load Odlyzko's Zeta Zeros Data
// File: src/sacred/zeta_import.zig
// Session 9: Riemann Hypothesis CF Analysis
//
// PURPOSE: Load Andrew Odlyzko's database of Riemann zeta function zeros
// DATA SOURCE: https://www.dtc.umn.edu/~odlyzko/zeta_tables/
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

/// Zeros data loaded from Odlyzko's files
pub const ZerosData = struct {
    gammas: []f64, // Imaginary parts γ_n of ζ(1/2 + iγ_n) = 0
    count: usize, // Number of zeros loaded
    height_T: f64, // Approximate height T (last gamma)
    allocator: std.mem.Allocator,

    /// Free allocated memory
    pub fn deinit(self: *const ZerosData) void {
        self.allocator.free(self.gammas);
    }

    /// Get nth zero (0-indexed, γ_0 = 0 is trivial zero)
    pub fn get(self: *const ZerosData, n: usize) ?f64 {
        if (n >= self.count) return null;
        return self.gammas[n];
    }

    /// Format summary for display
    pub fn formatSummary(self: *const ZerosData, writer: anytype) !void {
        try writer.print("ZerosData: {d} zeros, height T ≈ {d:.1e}\n", .{
            self.count, self.height_T,
        });
    }
};

/// Parse result for individual zeros
pub const ZeroParseResult = struct {
    gammas: []f64,
    count: usize,
    errors: usize,

    pub fn deinit(self: *ZeroParseResult, allocator: std.mem.Allocator) void {
        allocator.free(self.gammas);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HARDCODED ODLYZKO ZEROS — First 100 non-trivial zeros of ζ(s)
// Source: https://www-users.cse.umn.edu/~odlyzko/zeta_tables/zeros1
// ═══════════════════════════════════════════════════════════════════════════════

/// First 100 imaginary parts γ_n where ζ(1/2 + iγ_n) = 0
pub const FIRST_100_ZEROS = [100]f64{
    14.134725142,  21.022039639,  25.010857580,  30.424876126,  32.935061588,
    37.586178159,  40.918719012,  43.327073281,  48.005150881,  49.773832478,
    52.970321478,  56.446247697,  59.347044003,  60.831778525,  65.112544048,
    67.079810529,  69.546401711,  72.067157674,  75.704690699,  77.144840069,
    79.337375020,  82.910380854,  84.735492981,  87.425274613,  88.809111208,
    92.491899271,  94.651344041,  95.870634228,  98.831194218,  101.317851006,
    103.725538040, 105.446623052, 107.168611184, 111.029535543, 111.874659177,
    114.320220915, 116.226680321, 118.790782866, 121.370125002, 122.946829294,
    124.256818554, 127.516683880, 129.578704200, 131.087688531, 133.497737203,
    134.756509753, 138.116042055, 139.736208952, 141.123707404, 143.111845808,
    146.000982487, 147.422765343, 150.053520421, 150.925257612, 153.024693811,
    156.112909294, 157.597591818, 158.849988171, 161.188964138, 163.030709687,
    165.537069188, 167.184439978, 169.094515416, 169.911976479, 173.411536520,
    174.754191523, 176.441434298, 178.377407776, 179.916484020, 182.207078484,
    184.874467848, 185.598783678, 187.228922584, 189.416158656, 192.026656361,
    193.079726604, 195.265396680, 196.876481841, 198.015309676, 201.264751944,
    202.493594514, 204.189671803, 205.394697202, 207.906258888, 209.576509717,
    211.690862595, 213.347919360, 214.547044783, 216.169538508, 219.067596349,
    220.714918839, 221.430705555, 224.007000255, 224.983324670, 227.421444280,
    229.337413306, 231.250188700, 231.987235253, 233.693404179, 236.524229666,
};

/// Load hardcoded first 100 zeros (no file needed)
pub fn loadHardcodedZeros(allocator: std.mem.Allocator) !ZerosData {
    const gammas = try allocator.alloc(f64, FIRST_100_ZEROS.len);
    @memcpy(gammas, &FIRST_100_ZEROS);

    return ZerosData{
        .gammas = gammas,
        .count = FIRST_100_ZEROS.len,
        .height_T = FIRST_100_ZEROS[FIRST_100_ZEROS.len - 1],
        .allocator = allocator,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA LOADING
// ═══════════════════════════════════════════════════════════════════════════════

/// Load Odlyzko zeta zeros from a plain text file
/// File format: one gamma per line, optionally with comments (#...)
pub fn loadOdlyzkoZeros(allocator: std.mem.Allocator, path: []const u8) !ZerosData {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const size = stat.size;

    // Read entire file
    const buffer = try allocator.alloc(u8, @intCast(size));
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    // Parse zeros from buffer
    const result = try parseZerosBuffer(allocator, buffer);

    // Calculate height T
    const height_T = if (result.gammas.len > 0)
        result.gammas[result.gammas.len - 1]
    else
        0.0;

    return ZerosData{
        .gammas = result.gammas,
        .count = result.count,
        .height_T = height_T,
        .allocator = allocator,
    };
}

/// Parse zeros from a memory buffer
fn parseZerosBuffer(allocator: std.mem.Allocator, buffer: []const u8) !ZeroParseResult {
    var gammas = try std.ArrayList(f64).initCapacity(allocator, 100000);
    var errors: usize = 0;

    var iter = std.mem.tokenizeScalar(u8, buffer, '\n');
    var line_num: usize = 0;

    while (iter.next()) |line| {
        line_num += 1;

        // Skip empty lines and comments
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue;
        if (trimmed[0] == '#') continue;

        // Parse number
        if (std.fmt.parseFloat(f64, trimmed)) |gamma| {
            try gammas.append(allocator, gamma);
        } else |_| {
            errors += 1;
        }
    }

    const count = gammas.items.len;
    return ZeroParseResult{
        .gammas = try gammas.toOwnedSlice(allocator),
        .count = count,
        .errors = errors,
    };
}

/// Generate synthetic zeta zeros using asymptotic formula
/// γ_n ≈ 2πn / (W(n/e) + 1) where W is Lambert W function
/// For testing purposes when Odlyzko data is not available
pub fn generateSyntheticZeros(allocator: std.mem.Allocator, n_zeros: usize) !ZerosData {
    var gammas = try std.ArrayList(f64).initCapacity(allocator, n_zeros);

    // Approximation: γ_n ≈ 2π(n - 3/4) / ln((n - 3/4)/π)
    // This is the Gram asymptotic formula
    for (1..n_zeros + 1) |n| {
        const n_f = @as(f64, @floatFromInt(n));
        const term = n_f - 0.75;
        const gamma = 2.0 * std.math.pi * term / @log(term / std.math.pi);
        try gammas.append(allocator, gamma);
    }

    const gammas_slice = try gammas.toOwnedSlice(allocator);
    const height_T = if (gammas_slice.len > 0)
        gammas_slice[gammas_slice.len - 1]
    else
        0.0;

    return ZerosData{
        .gammas = gammas_slice,
        .count = gammas_slice.len,
        .height_T = height_T,
        .allocator = allocator,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA CACHING
// ═══════════════════════════════════════════════════════════════════════════════

/// Cache directory for downloaded zeta data
const CACHE_DIR = ".zeta_cache";

/// Download Odlyzko data from URL (placeholder for HTTP download)
/// For now, returns instructions for manual download
pub fn downloadOdlyzkoData(allocator: std.mem.Allocator, n_zeros: usize) ![]const u8 {
    _ = n_zeros;

    const url = "https://www.dtc.umn.edu/~odlyzko/zeta_tables/zeros1";
    const msg = try std.fmt.allocPrint(allocator,
        \\Download required:
        \\  URL: {s}
        \\  Save to: {s}/zeros1
        \\  Then run: tri math zeta-cf {s}/zeros1
    , .{ url, CACHE_DIR, CACHE_DIR });

    return msg;
}

/// Ensure cache directory exists
pub fn ensureCacheDir() !void {
    _ = std.fs.cwd().makeOpenPath(CACHE_DIR, .{}) catch |err| {
        if (err == error.PathAlreadyExists) {
            return; // Directory already exists, nothing to do
        } else {
            return err;
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND: Import and display zeros info
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runZetaImportCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}╔══════════════════════════════════════════════════════════╗{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}║     ZETA IMPORT — Odlyzko Zeros Data Loader            ║{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════╝{s}\n\n", .{ GOLD, RESET });

    if (args.len < 1) {
        std.debug.print("USAGE:\n", .{});
        std.debug.print("  tri math zeta-import <file>        Load zeros from file\n", .{});
        std.debug.print("  tri math zeta-import --hardcoded   Use first 100 hardcoded zeros\n", .{});
        std.debug.print("  tri math zeta-import --synthetic N Generate synthetic zeros\n\n", .{});
        std.debug.print("DATA SOURCE:\n", .{});
        std.debug.print("  https://www.dtc.umn.edu/~odlyzko/zeta_tables/\n\n", .{});
        return;
    }

    const arg = args[0];

    if (std.mem.eql(u8, arg, "--hardcoded")) {
        std.debug.print("{s}Loading first 100 hardcoded Odlyzko zeros...{s}\n", .{ CYAN, RESET });
        const data = try loadHardcodedZeros(allocator);
        defer data.deinit();

        try printZerosInfo(&data);
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
        return;
    } else if (std.mem.eql(u8, arg, "--synthetic")) {
        // Generate synthetic zeros for testing
        const n_zeros = if (args.len >= 2)
            try std.fmt.parseInt(usize, args[1], 10)
        else
            1000;

        std.debug.print("{s}Generating {d} synthetic zeros...{s}\n", .{ CYAN, n_zeros, RESET });
        const data = try generateSyntheticZeros(allocator, n_zeros);
        defer data.deinit();

        try printZerosInfo(&data);
    } else {
        // Load from file
        std.debug.print("{s}Loading zeros from: {s}{s}\n", .{ CYAN, arg, RESET });
        const data = try loadOdlyzkoZeros(allocator, arg);
        defer data.deinit();

        try printZerosInfo(&data);
    }

    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

fn printZerosInfo(data: *const ZerosData) !void {
    const CYAN = "\x1b[36m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}DATA SUMMARY:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Zeros loaded: {d}\n", .{data.count});
    std.debug.print("  Height T:    {e:.6}\n", .{data.height_T});

    if (data.count > 1) {
        const first_nonzero = if (data.count > 1 and data.gammas[0] == 0)
            data.gammas[1]
        else
            data.gammas[0];

        std.debug.print("  First zero:  {d:.6}\n", .{first_nonzero});

        const last_10 = @min(10, data.count);
        std.debug.print("\n{s}LAST {d} ZEROS:{s}\n", .{ CYAN, last_10, RESET });
        const start_idx = if (data.count > last_10) data.count - last_10 else 0;
        for (start_idx..data.count) |i| {
            std.debug.print("  γ[{d:6}] = {d:.12}\n", .{ i, data.gammas[i] });
        }
    }

    std.debug.print("\nSTATUS: Ready for spacing analysis\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// REFERENCES
// ═══════════════════════════════════════════════════════════════════════════════
//
// [1] A. M. Odlyzko, "The 10^20-th zero of the Riemann zeta function and
//     175 million of its neighbors", 1989
// [2] A. M. Odlyzko, "Tables of zeros of the Riemann zeta function",
//     https://www.dtc.umn.edu/~odlyzko/zeta_tables/
//
// ═══════════════════════════════════════════════════════════════════════════════
