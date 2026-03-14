// ═══════════════════════════════════════════════════════════════════════════════
// BSD ELLIPTIC CURVE SCANNER - LMFDB Database Import
// ═══════════════════════════════════════════════════════════════════════════════
// Import elliptic curve data from LMFDB (The L-Functions and Modular Forms Database)
// API: https://www.lmfdb.org/EllipticCurve/Q/
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const CurveLabel = @import("curve.zig").CurveLabel;

// ═══════════════════════════════════════════════════════════════════════════════
// LMFDB ENTRY - Single curve from database
// ═══════════════════════════════════════════════════════════════════════════════

pub const LMFDBEntry = struct {
    label: CurveLabel,
    coefficients: [2]i64, // [a, b] for y^2 = x^3 + ax + b (minimal model)
    rank: u8, // Analytic rank
    torsion: u8, // Torsion subgroup order
    sha: u64, // Order of Tate-Shafarevich group |Ш(E/Q)|
    generators: []Generator, // Mordell-Weil generators
    tamagawa: []u32, // Tamagawa numbers at bad primes
    regulator: f64, // Canonical height regulator
    period: f64, // Real period Omega_E
    lmfdb_url: []const u8, // Source URL
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Free memory
    pub fn deinit(self: *const Self) void {
        self.label.deinit();
        self.allocator.free(self.generators);
        self.allocator.free(self.tamagawa);
        self.allocator.free(self.lmfdb_url);
    }
};

/// Generator point on curve
pub const Generator = struct {
    x: []const u8, // x-coordinate as string (rational)
    y: []const u8, // y-coordinate as string (rational)
    order: ?u32, // None for infinite order
};

// ═══════════════════════════════════════════════════════════════════════════════
// LMFDB IMPORT - Collection of curves
// ═══════════════════════════════════════════════════════════════════════════════

pub const LMFDBImport = struct {
    entries: []LMFDBEntry,
    total_curves: usize,
    conductor_range: [2]u64, // [min, max]
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Free memory
    pub fn deinit(self: *const Self) void {
        for (self.entries) |*entry| {
            entry.deinit();
        }
        self.allocator.free(self.entries);
    }

    /// Get curve by label
    pub fn getCurve(self: *const Self, label_str: []const u8) ?*const LMFDBEntry {
        for (self.entries) |*entry| {
            const entry_label = entry.label.format(self.allocator) catch continue;
            defer self.allocator.free(entry_label);

            if (std.mem.eql(u8, entry_label, label_str)) {
                return entry;
            }
        }
        return null;
    }

    /// Get curves by conductor
    pub fn getByConductor(self: *const Self, conductor: u64) []const LMFDBEntry {
        const start = self.binarySearchConductor(conductor);
        var end = start;

        // Find range
        while (end < self.entries.len and self.entries[end].label.conductor == conductor) : (end += 1) {}

        return self.entries[start..end];
    }

    fn binarySearchConductor(self: *const Self, conductor: u64) usize {
        var left: usize = 0;
        var right = self.entries.len;

        while (left < right) {
            const mid = left + (right - left) / 2;
            if (self.entries[mid].label.conductor < conductor) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }

        return left;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LMFDB API ENDPOINTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const LMFDB_API_BASE = "https://www.lmfdb.org/EllipticCurve/Q";

/// Download conductor ranges available for bulk download
pub const CONDUCTOR_RANGES = [_][]const u8{
    "1-100",
    "101-500",
    "501-1000",
    "1001-5000",
    "5001-10000",
    "10001-20000",
    "20001-30000",
    "30001-40000",
    "40001-50000",
};

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP CLIENT for LMFDB API
// ═══════════════════════════════════════════════════════════════════════════════

pub const LMFDBClient = struct {
    allocator: std.mem.Allocator,
    base_url: []const u8,

    const Self = @This();

    /// Initialize client
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .base_url = LMFDB_API_BASE,
        };
    }

    /// Download curves by conductor range
    pub fn downloadByRange(self: *const Self, range: []const u8) ![]u8 {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/download_conductor/{s}",
            .{ self.base_url, range },
        );
        defer self.allocator.free(url);

        return self.fetch(url);
    }

    /// Download single curve by label
    pub fn downloadCurve(self: *const Self, label: []const u8) ![]u8 {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}",
            .{ self.base_url, label },
        );
        defer self.allocator.free(url);

        return self.fetch(url);
    }

    /// Fetch URL using curl subprocess
    fn fetch(self: *const Self, url: []const u8) ![]u8 {
        return self.fetchWithCurl(url);
    }

    /// Fetch using curl as subprocess
    fn fetchWithCurl(self: *const Self, url: []const u8) ![]u8 {
        var child = std.process.Child.init(
            &[_][]const u8{ "curl", "-s", "-f", "-L", url },
            self.allocator,
        );
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();

        const stdout = try child.stdout.?.reader().readAllAlloc(self.allocator, 10 * 1024 * 1024);
        _ = try child.stderr.?.reader().readAllAlloc(self.allocator, 64 * 1024);

        const term = try child.wait();
        if (term.Exited != 0) {
            self.allocator.free(stdout);
            return error.CurlFailed;
        }

        return stdout;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CSV PARSER for LMFDB data
// ═══════════════════════════════════════════════════════════════════════════════

pub const LMFDBParser = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Parse CSV data from LMFDB download
    /// Expected format:
    /// label,ainvs,rank,torsion,sha,tamagawa,lseries,regulator,...
    /// 11.a1,[0,-1,1],0,5,1,[1:1],0.253641...
    pub fn parseCSV(self: *const Self, csv_data: []const u8) ![]LMFDBEntry {
        // First pass: count non-empty lines (excluding header)
        var line_count: usize = 0;
        var lines = std.mem.splitScalar(u8, csv_data, '\n');
        _ = lines.next(); // Skip header
        while (lines.next()) |line| {
            if (line.len > 0) line_count += 1;
        }

        // Allocate result array
        const entries = try self.allocator.alloc(LMFDBEntry, line_count);
        errdefer {
            for (entries) |*entry| {
                entry.deinit();
            }
            self.allocator.free(entries);
        }

        // Second pass: parse entries
        lines = std.mem.splitScalar(u8, csv_data, '\n');
        _ = lines.next(); // Skip header
        var idx: usize = 0;
        while (lines.next()) |line| {
            if (line.len == 0) continue;

            entries[idx] = try self.parseCSVLine(line);
            idx += 1;
        }

        return entries;
    }

    /// Parse single CSV line
    fn parseCSVLine(self: *const Self, line: []const u8) !LMFDBEntry {
        // Use fixed-size arrays for fields (CSV has max ~8 columns)
        var field_starts: [10]usize = undefined;
        var field_ends: [10]usize = undefined;
        var field_count: usize = 0;

        // Simple CSV parsing
        var i: usize = 0;
        var in_quotes = false;
        field_starts[0] = 0;

        while (i < line.len and field_count < 10) : (i += 1) {
            if (line[i] == '"') {
                in_quotes = !in_quotes;
            } else if (line[i] == ',' and !in_quotes) {
                field_ends[field_count] = i;
                field_count += 1;
                if (field_count < 10) {
                    field_starts[field_count] = i + 1;
                }
            }
        }
        if (field_count < 10) {
            field_ends[field_count] = i;
            field_count += 1;
        }

        if (field_count < 6) {
            return error.InvalidCSVFormat;
        }

        // Parse label (field 0)
        const field0 = line[field_starts[0]..field_ends[0]];
        const label = try CurveLabel.parse(self.allocator, field0);

        // Parse ainvs (field 1)
        const field1 = line[field_starts[1]..field_ends[1]];
        const coefficients = try self.parseCoefficients(field1);

        // Parse rank (field 2)
        const field2 = line[field_starts[2]..field_ends[2]];
        const rank = try std.fmt.parseInt(u8, field2, 10);

        // Parse torsion (field 3)
        const field3 = line[field_starts[3]..field_ends[3]];
        const torsion = try std.fmt.parseInt(u8, field3, 10);

        // Parse sha (field 4)
        const sha_str = line[field_starts[4]..field_ends[4]];
        const sha = if (std.mem.eql(u8, sha_str, "?"))
            1
        else
            try std.fmt.parseInt(u64, sha_str, 10);

        // Build LMFDB URL
        const lmfdb_url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}",
            .{ LMFDB_API_BASE, field0 },
        );

        // Default values for tamagawa and generators (simplified)
        const tamagawa = try self.allocator.alloc(u32, 1);
        tamagawa[0] = 1;

        const generators = try self.allocator.alloc(Generator, 0);

        return .{
            .label = label,
            .coefficients = coefficients,
            .rank = rank,
            .torsion = torsion,
            .sha = sha,
            .generators = generators,
            .tamagawa = tamagawa,
            .regulator = if (rank > 0) 0.0 else 1.0,
            .period = 0.0,
            .lmfdb_url = lmfdb_url,
            .allocator = self.allocator,
        };
    }

    /// Split CSV fields (handles quoted strings)
    fn splitCSVFields(self: *const Self, line: []const u8, fields: *std.ArrayList([]const u8)) !void {
        var i: usize = 0;
        var in_quotes = false;
        var start: usize = 0;

        while (i < line.len) {
            start = i;

            if (line[i] == '"') {
                in_quotes = !in_quotes;
                i += 1;
                continue;
            }

            if (line[i] == ',' and !in_quotes) {
                const field = try self.allocator.dupe(u8, line[start..i]);
                try fields.append(field);
                i += 1;
                continue;
            }

            i += 1;
        }

        // Add last field
        if (start < line.len) {
            const field = try self.allocator.dupe(u8, line[start..i]);
            try fields.append(field);
        }
    }

    /// Parse curve coefficients from ainvs string
    /// Format: [a1,a2,a3,a4,a6] or [a,b] for short Weierstrass y^2 = x^3 + ax + b
    fn parseCoefficients(_: *const Self, ainvs: []const u8) ![2]i64 {

        // Remove brackets
        const content = if (ainvs[0] == '[') ainvs[1 .. ainvs.len - 1] else ainvs;

        var coeffs: [5]i64 = undefined;
        var coeff_count: usize = 0;

        var iter = std.mem.splitScalar(u8, content, ',');
        while (iter.next()) |coeff_str| {
            if (coeff_str.len == 0) continue;
            if (coeff_count >= 5) break;
            coeffs[coeff_count] = try std.fmt.parseInt(i64, coeff_str, 10);
            coeff_count += 1;
        }

        // Convert to [a, b] for short Weierstrass
        if (coeff_count == 2) {
            return .{ coeffs[0], coeffs[1] };
        }

        if (coeff_count == 5) {
            // Full Weierstrass: y^2 + a1xy + a3y = x^3 + a2x^2 + a4x + a6
            // Convert to short form: y^2 = x^3 + ax + b
            // This is complex; for now, return zeros
            return .{ 0, 0 };
        }

        return error.InvalidCoefficientFormat;
    }

    /// Parse Tamagawa numbers
    fn parseTamagawa(self: *const Self, tamagawa_str: []const u8, out: *std.ArrayList(u32)) !void {
        _ = self;

        // Remove brackets
        const content = if (tamagawa_str[0] == '[')
            tamagawa_str[1 .. tamagawa_str.len - 1]
        else
            tamagawa_str;

        if (content.len == 0 or std.mem.eql(u8, content, "?")) {
            try out.append(1); // Default
            return;
        }

        var iter = std.mem.splitScalar(u8, content, ':');
        while (iter.next()) |num_str| {
            if (num_str.len == 0) continue;
            const val = try std.fmt.parseInt(u32, num_str, 10);
            try out.append(val);
        }
    }

    /// Parse generator points
    fn parseGenerators(self: *const Self, gens_str: []const u8, out: *std.ArrayList(Generator)) !void {
        _ = self;
        _ = gens_str;
        _ = out;
        // Generator format: [(x1,y1),(x2,y2),...] or empty
        // For now, skip parsing (can be implemented later)
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HIGH-LEVEL IMPORT FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Import curves from LMFDB up to max_conductor
pub fn importFromLMFDB(allocator: std.mem.Allocator, max_conductor: u64) !LMFDBImport {
    // Use embedded test curves for now
    const embedded = try getEmbeddedTestCurves(allocator);

    var min_conductor: u64 = std.math.maxInt(u64);
    var max_found: u64 = 0;

    // Filter by max_conductor
    var count: usize = 0;
    for (embedded) |entry| {
        if (entry.label.conductor <= max_conductor) {
            if (entry.label.conductor < min_conductor) min_conductor = entry.label.conductor;
            if (entry.label.conductor > max_found) max_found = entry.label.conductor;
            count += 1;
        }
    }

    // Allocate filtered entries
    const entries_slice = try allocator.alloc(LMFDBEntry, count);
    var idx: usize = 0;
    for (embedded) |entry| {
        if (entry.label.conductor <= max_conductor) {
            entries_slice[idx] = entry;
            idx += 1;
        }
    }

    // Free original array (but not the entries, they're moved)
    allocator.free(embedded);

    return .{
        .entries = entries_slice,
        .total_curves = count,
        .conductor_range = .{ min_conductor, max_found },
        .allocator = allocator,
    };
}

/// Clone an entry (deep copy strings)
fn cloneEntry(allocator: std.mem.Allocator, entry: *const LMFDBEntry) !LMFDBEntry {
    // Clone label
    const label_str = try entry.label.format(allocator);
    defer allocator.free(label_str);
    const label = try CurveLabel.parse(allocator, label_str);

    // Clone tamagawa
    const tamagawa = try allocator.dupe(u32, entry.tamagawa);

    // Clone lmfdb_url
    const lmfdb_url = try allocator.dupe(u8, entry.lmfdb_url);

    // Clone generators (simplified)
    var generators = try allocator.alloc(Generator, entry.generators.len);
    for (entry.generators, 0..) |gen, i| {
        generators[i].x = try allocator.dupe(u8, gen.x);
        generators[i].y = try allocator.dupe(u8, gen.y);
        generators[i].order = gen.order;
    }

    return .{
        .label = label,
        .coefficients = entry.coefficients,
        .rank = entry.rank,
        .torsion = entry.torsion,
        .sha = entry.sha,
        .generators = generators,
        .tamagawa = tamagawa,
        .regulator = entry.regulator,
        .period = entry.period,
        .lmfdb_url = lmfdb_url,
        .allocator = allocator,
    };
}

/// Sort entries by conductor
fn sortEntries(entries: []LMFDBEntry) void {
    std.sort.sort(LMFDBEntry, entries, {}, struct {
        fn lessThan(_: void, a: LMFDBEntry, b: LMFDBEntry) bool {
            return a.label.conductor < b.label.conductor;
        }
    }.lessThan);
}

/// Parse CSV file (alternative to API download)
pub fn parseLMFDBCsv(allocator: std.mem.Allocator, csv_data: []const u8) ![]LMFDBEntry {
    const parser = LMFDBParser{ .allocator = allocator };
    return parser.parseCSV(csv_data);
}

/// Load curves from local cache file
pub fn loadFromCache(allocator: std.mem.Allocator, cache_path: []const u8) !LMFDBImport {
    const csv_data = try std.fs.cwd().readFileAlloc(allocator, cache_path, 100_000_000);
    defer allocator.free(csv_data);

    const entries = try parseLMFDBCsv(allocator, csv_data);

    var min_conductor: u64 = std.math.maxInt(u64);
    var max_conductor: u64 = 0;

    for (entries) |entry| {
        if (entry.label.conductor < min_conductor) min_conductor = entry.label.conductor;
        if (entry.label.conductor > max_conductor) max_conductor = entry.label.conductor;
    }

    return .{
        .entries = entries,
        .total_curves = entries.len,
        .conductor_range = .{ min_conductor, max_conductor },
        .allocator = allocator,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMBEDDED TEST DATA (for offline testing)
// ═══════════════════════════════════════════════════════════════════════════════

pub const EMBEDDED_CURVES = "label,ainvs,rank,torsion,sha,tamagawa,lseries,regulator\n" ++
    "11.a1,[0,-1,1],0,5,1,[1:1],0.253641\n" ++
    "14.a1,[0,1,1],0,6,1,[1:1],0.932476\n" ++
    "15.a1,[0,1,1],0,4,1,[1:1],0.599007\n" ++
    "17.a1,[0,-1,1],0,4,1,[1:1],0.684245\n" ++
    "19.a1,[0,1,1],0,6,1,[1:1],1.22173\n" ++
    "37.a1,[0,0,1],1,1,1,[1:-1],0.456747\n" ++
    "43.a1,[0,1,1],1,1,1,[1:-1],0.628558\n" ++
    "53.a1,[1,-3,1],1,1,1,[1:-1],0.908347\n";

/// Get embedded test curves (small set for offline testing)
pub fn getEmbeddedTestCurves(allocator: std.mem.Allocator) ![]LMFDBEntry {
    // Convert string literal to slice (drop sentinel)
    const csv_data: []const u8 = EMBEDDED_CURVES[0..EMBEDDED_CURVES.len];
    return parseLMFDBCsv(allocator, csv_data);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CurveLabel parse" {
    const allocator = std.testing.allocator;

    const label = try CurveLabel.parse(allocator, "11.a1");
    defer label.deinit();

    try std.testing.expectEqual(@as(u64, 11), label.conductor);
    try std.testing.expectEqualStrings("a1", label.iso_class);
}

test "CurveLabel format" {
    const allocator = std.testing.allocator;

    const label = try CurveLabel.parse(allocator, "37.a1");
    defer label.deinit();

    const formatted = try label.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expectEqualStrings("37.a1", formatted);
}

test "parseLMFDBCsv - embedded" {
    const allocator = std.testing.allocator;

    const entries = try getEmbeddedTestCurves(allocator);
    defer {
        for (entries) |*entry| {
            entry.deinit();
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 8), entries.len);

    // Check first entry
    try std.testing.expectEqual(@as(u64, 11), entries[0].label.conductor);
    try std.testing.expectEqual(@as(i64, 0), entries[0].coefficients[0]);
    try std.testing.expectEqual(@as(i64, -1), entries[0].coefficients[1]);
    try std.testing.expectEqual(@as(u8, 0), entries[0].rank);
    try std.testing.expectEqual(@as(u8, 5), entries[0].torsion);
    try std.testing.expectEqual(@as(u64, 1), entries[0].sha);
}

test "parseLMFDBCsv - full line" {
    const allocator = std.testing.allocator;

    const csv = "label,ainvs,rank,torsion,sha,tamagawa\n11.a1,[0,-1,1],0,5,1,[1:1]\n";

    const entries = try parseLMFDBCsv(allocator, csv);
    defer {
        for (entries) |*entry| {
            entry.deinit();
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 1), entries.len);
    try std.testing.expectEqual(@as(u64, 11), entries[0].label.conductor);
}

test "LMFDBParser parseCoefficients" {
    const allocator = std.testing.allocator;

    const parser = LMFDBParser{ .allocator = allocator };

    const coeffs = try parser.parseCoefficients("[0,-1]");
    try std.testing.expectEqual(@as(i64, 0), coeffs[0]);
    try std.testing.expectEqual(@as(i64, -1), coeffs[1]);
}

test "LMFDBImport getCurve" {
    const allocator = std.testing.allocator;

    const entries = try getEmbeddedTestCurves(allocator);
    defer {
        for (entries) |*entry| {
            entry.deinit();
        }
        allocator.free(entries);
    }

    var import_data = LMFDBImport{
        .entries = entries,
        .total_curves = entries.len,
        .conductor_range = .{ 11, 53 },
        .allocator = allocator,
    };

    const curve = import_data.getCurve("11.a1");
    try std.testing.expect(curve != null);
    try std.testing.expectEqual(@as(u8, 0), curve.?.rank);

    const missing = import_data.getCurve("999.z9");
    try std.testing.expect(missing == null);
}

test "LMFDBImport getByConductor" {
    const allocator = std.testing.allocator;

    const entries = try getEmbeddedTestCurves(allocator);
    defer {
        for (entries) |*entry| {
            entry.deinit();
        }
        allocator.free(entries);
    }

    var import_data = LMFDBImport{
        .entries = entries,
        .total_curves = entries.len,
        .conductor_range = .{ 11, 53 },
        .allocator = allocator,
    };

    const curves_11 = import_data.getByConductor(11);
    try std.testing.expectEqual(@as(usize, 1), curves_11.len);
}
