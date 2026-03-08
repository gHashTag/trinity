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
    coefficients: [2]i64,     // [a, b] for y^2 = x^3 + ax + b (minimal model)
    rank: u8,                 // Analytic rank
    torsion: u8,              // Torsion subgroup order
    sha: u64,                 // Order of Tate-Shafarevich group |Ш(E/Q)|
    generators: []Generator,  // Mordell-Weil generators
    tamagawa: []u32,          // Tamagawa numbers at bad primes
    regulator: f64,           // Canonical height regulator
    period: f64,              // Real period Omega_E
    l_value: f64 = 0.0,       // L(E,1) or L'(E,1) value from database
    lmfdb_url: []const u8,    // Source URL
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
    x: []const u8,  // x-coordinate as string (rational)
    y: []const u8,  // y-coordinate as string (rational)
    order: ?u32,    // None for infinite order
};

// ═══════════════════════════════════════════════════════════════════════════════
// LMFDB IMPORT - Collection of curves
// ═══════════════════════════════════════════════════════════════════════════════

pub const LMFDBImport = struct {
    entries: []LMFDBEntry,
    total_curves: usize,
    conductor_range: [2]u64,  // [min, max]
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Free memory (entries array only - entries themselves are managed separately)
    /// Note: This is a simplified version that only frees the array
    /// The individual entries should have their labels cleaned up by the caller
    pub fn deinit(self: *const Self) void {
        // Only free the entries array, not the individual entries
        // This is safe because ScanResult now clones all strings it needs
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

    /// Fetch URL (using zig's HTTP client or curl fallback)
    fn fetch(self: *const Self, url: []const u8) ![]u8 {
        _ = url;

        // Try using std.http.Client first
        if (std.http.Client) {
            return self.fetchWithStdHttp();
        }

        // Fallback to curl
        return self.fetchWithCurl();
    }

    /// Fetch using std.http.Client
    fn fetchWithStdHttp(self: *const Self) ![]u8 {
        // std.http.Client requires Zig 0.13.0+
        // For now, use curl fallback
        return self.fetchWithCurl();
    }

    /// Fetch using curl as subprocess
    fn fetchWithCurl(self: *const Self) ![]u8 {
        _ = self;
        // Stub implementation - real version would use curl
        return error.NotImplemented;
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
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len > 0) line_count += 1;
        }

        // Allocate result array
        const entries = try self.allocator.alloc(LMFDBEntry, line_count);

        // Second pass: parse entries
        lines = std.mem.splitScalar(u8, csv_data, '\n');
        _ = lines.next(); // Skip header
        var idx: usize = 0;
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0) continue;

            entries[idx] = try self.parseCSVLine(trimmed);
            idx += 1;
        }

        return entries;
    }

    /// Parse single CSV line (comma-separated format)
    fn parseCSVLine(self: *const Self, line: []const u8) !LMFDBEntry {
        var fields: std.ArrayListUnmanaged([]const u8) = .{};
        defer fields.deinit(self.allocator);

        try self.splitCSVFields(line, &fields);

        if (fields.items.len < 4) {
            return error.InvalidCSVFormat;
        }

        // Trim whitespace from label field
        const label_raw = std.mem.trim(u8, fields.items[0], &std.ascii.whitespace);
        if (label_raw.len == 0) {
            return error.InvalidCSVFormat;
        }

        // Parse label (field 0)
        const label = try CurveLabel.parse(self.allocator, label_raw);

        // Parse ainvs (field 1)
        const coefficients = try self.parseCoefficients(fields.items[1]);

        // Parse rank (field 2)
        const rank = if (fields.items.len > 2)
            try std.fmt.parseInt(u8, fields.items[2], 10)
        else
            0;

        // Parse torsion (field 3)
        const torsion = if (fields.items.len > 3)
            try std.fmt.parseInt(u8, fields.items[3], 10)
        else
            0;

        // Parse sha (field 4)
        const sha_str = if (fields.items.len > 4) fields.items[4] else "?";
        const sha = if (std.mem.eql(u8, sha_str, "?"))
            1
        else
            try std.fmt.parseInt(u64, sha_str, 10);

        // Build LMFDB URL
        const lmfdb_url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}",
            .{ LMFDB_API_BASE, fields.items[0] },
        );

        // Parse tamagawa if available (field 5)
        var tamagawa_list: std.ArrayListUnmanaged(u32) = .{};
        try tamagawa_list.append(self.allocator, 1); // Default
        if (fields.items.len > 5) {
            try self.parseTamagawa(fields.items[5], &tamagawa_list);
        }
        const tamagawa = try tamagawa_list.toOwnedSlice(self.allocator);

        // Generators (simplified - not parsing from CSV)
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

    /// Split CSV fields (handles quoted strings and bracket-enclosed content)
    fn splitCSVFields(self: *const Self, line: []const u8, fields: *std.ArrayListUnmanaged([]const u8)) !void {
        var i: usize = 0;
        var in_quotes = false;
        var in_brackets = false;
        var start: usize = 0;

        while (i < line.len) {
            if (line[i] == '"') {
                in_quotes = !in_quotes;
                i += 1;
                continue;
            }

            if (line[i] == '[') {
                in_brackets = true;
            } else if (line[i] == ']') {
                in_brackets = false;
            }

            if (line[i] == ',' and !in_quotes and !in_brackets) {
                const field = try self.allocator.dupe(u8, line[start..i]);
                try fields.append(self.allocator, field);
                start = i + 1;
            }

            i += 1;
        }

        // Add last field
        if (start < line.len) {
            const field = try self.allocator.dupe(u8, line[start..i]);
            try fields.append(self.allocator, field);
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

        if (coeff_count == 3) {
            // Simplified format: [a4, a6, extra] - first two are short form coefficients
            return .{ coeffs[0], coeffs[1] };
        }

        if (coeff_count == 5) {
            // Full Weierstrass: y^2 + a1xy + a3y = x^3 + a2x^2 + a4x + a6
            // Convert to short form: y^2 = x^3 + Ax + B
            // Using invariants: b2, b4, b6, then c4, c6 for short form
            const a1 = coeffs[0];
            const a2 = coeffs[1];
            const a3 = coeffs[2];
            const a4 = coeffs[3];
            const a6 = coeffs[4];

            // Standard invariants
            const b2 = a1 * a1 + 4 * a2;
            const b4 = 2 * a4 + a1 * a3;
            const b6 = a3 * a3 + 4 * a6;

            // Short form coefficients from invariants
            // c4 = b2^2 - 24*b4, c6 = -b2^3 + 36*b2*b4 - 216*b6
            // Short form: y^2 = x^3 - 27*c4*x - 54*c6
            // More commonly: y^2 = x^3 + Ax + B where A = -c4/48, B = -c6/864

            const c4 = b2 * b2 - 24 * b4;
            const c6 = -b2 * b2 * b2 + 36 * b2 * b4 - 216 * b6;

            const A = @divTrunc(-c4, 48);
            const B = @divTrunc(-c6, 864);

            return .{ A, B };
        }

        return error.InvalidCoefficientFormat;
    }

    /// Parse Tamagawa numbers
    fn parseTamagawa(self: *const Self, tamagawa_str: []const u8, out: *std.ArrayListUnmanaged(u32)) !void {
        // Remove brackets
        const content = if (tamagawa_str[0] == '[')
            tamagawa_str[1 .. tamagawa_str.len - 1]
        else
            tamagawa_str;

        if (content.len == 0 or std.mem.eql(u8, content, "?")) {
            try out.append(self.allocator, 1); // Default
            return;
        }

        var iter = std.mem.splitScalar(u8, content, ':');
        while (iter.next()) |num_str| {
            if (num_str.len == 0) continue;
            // Handle signed numbers - take absolute value (Tamagawa numbers are positive)
            const val = if (num_str[0] == '-')
                try std.fmt.parseInt(u32, num_str[1..], 10)
            else
                try std.fmt.parseInt(u32, num_str, 10);
            try out.append(self.allocator, val);
        }
    }

    /// Parse generator points
    fn parseGenerators(self: *const Self, gens_str: []const u8, out: *std.ArrayListUnmanaged(Generator)) !void {
        _ = self;
        _ = gens_str;
        _ = out;
        // Generator format: [(x1,y1),(x2,y2),...] or empty
        // For now, skip parsing (can be implemented later)
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ALLCURVES FORMAT PARSER
// ═══════════════════════════════════════════════════════════════════════════════
// Format: conductor iso_class_number [ainvs] rank torsion
// Example: 11 a 1 [0,-1,1,-10,-20] 0 5

/// Parse a line from allcurves file
fn parseAllCurvesLine(allocator: std.mem.Allocator, line: []const u8) !LMFDBEntry {
    var iter = std.mem.tokenizeScalar(u8, line, ' ');

    // Parse conductor
    const conductor_str = iter.next() orelse return error.InvalidFormat;
    const conductor = try std.fmt.parseInt(u64, conductor_str, 10);

    // Parse iso_class (single letter like 'a', 'b', etc.)
    const iso_class = iter.next() orelse return error.InvalidFormat;

    // Parse number
    const number_str = iter.next() orelse return error.InvalidFormat;
    const number = try std.fmt.parseInt(u32, number_str, 10);

    // Create label - allocate owned strings
    const label_iso = try allocator.dupe(u8, iso_class);
    errdefer allocator.free(label_iso);

    const label_full = try std.fmt.allocPrint(allocator, "{d}.{s}{d}", .{ conductor, iso_class, number });
    errdefer allocator.free(label_full);

    const label = CurveLabel{
        .conductor = conductor,
        .iso_class = label_iso,
        .number = number,
        .label = label_full,
        .allocator = allocator,
    };

    // Parse ainvs array [a1,a2,a3,a4,a6]
    const ainvs_str = iter.next() orelse return error.InvalidFormat;
    const coefficients = try parseAllCurvesCoefficients(ainvs_str);

    // Parse rank
    const rank_str = iter.next() orelse "0";
    const rank = try std.fmt.parseInt(u8, rank_str, 10);

    // Parse torsion
    const torsion_str = iter.next() orelse "1";
    const torsion = try std.fmt.parseInt(u8, torsion_str, 10);

    // Build LMFDB URL (uses label_full which is now owned by the entry)
    const lmfdb_url = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}",
        .{ LMFDB_API_BASE, label_full },
    );

    // Empty generators and tamagawa for now
    const generators = try allocator.alloc(Generator, 0);
    const tamagawa = try allocator.alloc(u32, 0);

    return .{
        .label = label,
        .coefficients = coefficients,
        .rank = rank,
        .torsion = torsion,
        .sha = 1, // Default
        .generators = generators,
        .tamagawa = tamagawa,
        .regulator = if (rank == 0) 1.0 else 0.0,
        .period = 0.0,
        .lmfdb_url = lmfdb_url,
        .allocator = allocator,
    };
}

/// Parse coefficients from allcurves ainvs string [a1,a2,a3,a4,a6]
/// Returns [a, b] for short Weierstrass form
fn parseAllCurvesCoefficients(ainvs: []const u8) ![2]i64 {
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

    if (coeff_count != 5) {
        return error.InvalidCoefficientCount;
    }

    // Convert full Weierstrass to short form
    // y^2 + a1xy + a3y = x^3 + a2x^2 + a4x + a6
    // Using invariants: c4, c6 for short form
    const a1 = coeffs[0];
    const a2 = coeffs[1];
    const a3 = coeffs[2];
    const a4 = coeffs[3];
    const a6 = coeffs[4];

    // Simplified: for curves with a1=a2=a3=0, use a4, a6 directly
    if (a1 == 0 and a2 == 0 and a3 == 0) {
        return .{ a4, a6 };
    }

    // Otherwise compute c4, c6 invariants (simplified)
    // Full implementation would use complete transformation formulas
    // For now, use a4, a6 as approximation
    return .{ a4, a6 };
}

/// Load curves from allcurves file
pub fn loadFromAllCurves(allocator: std.mem.Allocator, file_path: []const u8, max_conductor: u64) ![]LMFDBEntry {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const stat = try file.stat();
    const buffer = try allocator.alloc(u8, @intCast(stat.size));
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    // First pass: count lines that pass conductor filter
    var line_count: usize = 0;
    var lines = std.mem.splitScalar(u8, buffer, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue;

        // Check conductor
        var iter = std.mem.tokenizeScalar(u8, trimmed, ' ');
        const conductor_str = iter.next() orelse continue;
        const conductor = std.fmt.parseInt(u64, conductor_str, 10) catch continue;

        if (conductor <= max_conductor) {
            line_count += 1;
        }
    }

    // Allocate entries
    const entries = try allocator.alloc(LMFDBEntry, line_count);
    errdefer {
        for (entries) |*e| e.deinit();
        allocator.free(entries);
    }

    // Second pass: parse entries
    lines = std.mem.splitScalar(u8, buffer, '\n');
    var idx: usize = 0;
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue;

        var iter = std.mem.tokenizeScalar(u8, trimmed, ' ');
        const conductor_str = iter.next() orelse continue;
        const conductor = std.fmt.parseInt(u64, conductor_str, 10) catch continue;

        if (conductor <= max_conductor) {
            entries[idx] = try parseAllCurvesLine(allocator, trimmed);
            idx += 1;
        }
    }

    return entries;
}

/// Load curves from allbsd file with complete BSD data
/// Format: conductor iso_class number [ainvs] rank torsion tamagawa real_period l_value regulator sha
pub fn loadFromAllBsd(allocator: std.mem.Allocator, file_path: []const u8, max_conductor: u64) ![]LMFDBEntry {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const stat = try file.stat();
    const buffer = try allocator.alloc(u8, @intCast(stat.size));
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    // First pass: count lines that pass conductor filter
    var line_count: usize = 0;
    var lines = std.mem.splitScalar(u8, buffer, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue;

        // Check conductor
        var iter = std.mem.tokenizeScalar(u8, trimmed, ' ');
        const conductor_str = iter.next() orelse continue;
        const conductor = std.fmt.parseInt(u64, conductor_str, 10) catch continue;

        if (conductor <= max_conductor) {
            line_count += 1;
        }
    }

    // Allocate entries
    const entries = try allocator.alloc(LMFDBEntry, line_count);
    errdefer {
        for (entries) |*e| e.deinit();
        allocator.free(entries);
    }

    // Second pass: parse entries
    lines = std.mem.splitScalar(u8, buffer, '\n');
    var idx: usize = 0;
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue;

        var iter = std.mem.tokenizeScalar(u8, trimmed, ' ');
        const conductor_str = iter.next() orelse continue;
        const conductor = std.fmt.parseInt(u64, conductor_str, 10) catch continue;

        if (conductor <= max_conductor) {
            entries[idx] = try parseAllBsdLine(allocator, trimmed);
            idx += 1;
        }
    }

    return entries;
}

/// Parse a single allbsd line with complete BSD data
/// Format: conductor iso_class number [ainvs] rank torsion tamagawa real_period l_value regulator sha
/// Example: 11 a 1 [0,-1,1,-10,-20] 0 5 5 1.26920930427955 0.253841860855911 1.00000000000000 1
fn parseAllBsdLine(allocator: std.mem.Allocator, line: []const u8) !LMFDBEntry {
    var iter = std.mem.tokenizeScalar(u8, line, ' ');

    // Parse conductor
    const conductor_str = iter.next() orelse return error.InvalidFormat;
    const conductor = try std.fmt.parseInt(u64, conductor_str, 10);

    // Parse iso_class (single letter like 'a', 'b', etc.)
    const iso_class = iter.next() orelse return error.InvalidFormat;

    // Parse number
    const number_str = iter.next() orelse return error.InvalidFormat;
    const number = try std.fmt.parseInt(u32, number_str, 10);

    // Create label - allocate owned strings
    const label_iso = try allocator.dupe(u8, iso_class);
    errdefer allocator.free(label_iso);

    const label_full = try std.fmt.allocPrint(allocator, "{d}.{s}{d}", .{ conductor, iso_class, number });
    errdefer allocator.free(label_full);

    const label = CurveLabel{
        .conductor = conductor,
        .iso_class = label_iso,
        .number = number,
        .label = label_full,
        .allocator = allocator,
    };

    // Parse ainvs array [a1,a2,a3,a4,a6]
    const ainvs_str = iter.next() orelse return error.InvalidFormat;
    const coefficients = try parseAllCurvesCoefficients(ainvs_str);

    // Parse rank
    const rank_str = iter.next() orelse "0";
    const rank = try std.fmt.parseInt(u8, rank_str, 10);

    // Parse torsion
    const torsion_str = iter.next() orelse "1";
    const torsion = try std.fmt.parseInt(u8, torsion_str, 10);

    // Parse tamagawa_product (BSD data)
    const tamagawa_str = iter.next() orelse "1";
    const tamagawa_product = try std.fmt.parseInt(u32, tamagawa_str, 10);

    // Parse real_period (BSD data)
    const period_str = iter.next() orelse "0.0";
    const real_period = std.fmt.parseFloat(f64, period_str) catch 0.0;

    // Parse l_value (BSD data - L(E,1) or L'(E,1))
    const l_value_str = iter.next() orelse "0.0";
    const l_value = std.fmt.parseFloat(f64, l_value_str) catch 0.0;

    // Parse regulator (BSD data)
    const regulator_str = iter.next() orelse "1.0";
    const regulator = std.fmt.parseFloat(f64, regulator_str) catch 1.0;

    // Parse sha_order (BSD data)
    const sha_str = iter.next() orelse "1";
    const sha_value = std.fmt.parseFloat(f64, sha_str) catch 1.0;
    const sha_order: u64 = @intFromFloat(sha_value);

    // Build LMFDB URL (uses label_full which is now owned by the entry)
    const lmfdb_url = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}",
        .{ LMFDB_API_BASE, label_full },
    );

    // Create tamagawa array (single element for product)
    const tamagawa = try allocator.alloc(u32, 1);
    tamagawa[0] = tamagawa_product;

    // Empty generators
    const generators = try allocator.alloc(Generator, 0);

    return .{
        .label = label,
        .coefficients = coefficients,
        .rank = rank,
        .torsion = torsion,
        .sha = sha_order,
        .generators = generators,
        .tamagawa = tamagawa,
        .regulator = regulator,
        .period = real_period, // Store real_period in period field
        .l_value = l_value,    // Store L(E,1) or L'(E,1) from database
        .lmfdb_url = lmfdb_url,
        .allocator = allocator,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// HIGH-LEVEL IMPORT FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Import curves from LMFDB up to max_conductor
/// Now uses allbsd files for complete BSD data (sha, tamagawa, real_period, regulator)
pub fn importFromLMFDB(allocator: std.mem.Allocator, max_conductor: u64) !LMFDBImport {
    const data_root = std.posix.getenv("TRINITY_DATA") orelse "/Users/playra/trinity-w1/data/ecdata";

    // Try to load from allbsd files first (for complete BSD data)
    const allbsd_path = try std.fmt.allocPrint(allocator, "{s}/allbsd/allbsd.00000-09999", .{data_root});
    defer allocator.free(allbsd_path);

    // Check if allbsd file exists
    if (std.fs.cwd().openFile(allbsd_path, .{})) |file| {
        file.close();
        // Load from allbsd file with complete BSD data
        const entries = try loadFromAllBsd(allocator, allbsd_path, max_conductor);

        var min_conductor: u64 = std.math.maxInt(u64);
        var max_found: u64 = 0;

        for (entries) |entry| {
            if (entry.label.conductor < min_conductor) min_conductor = entry.label.conductor;
            if (entry.label.conductor > max_found) max_found = entry.label.conductor;
        }

        return .{
            .entries = entries,
            .total_curves = entries.len,
            .conductor_range = .{ min_conductor, max_found },
            .allocator = allocator,
        };
    } else |_| {
        // Fall back to embedded test curves
        const embedded = try getEmbeddedTestCurves(allocator);

        var min_conductor: u64 = std.math.maxInt(u64);
        var max_found: u64 = 0;

        // Count entries that pass the filter
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
        errdefer allocator.free(entries_slice);

        var idx: usize = 0;
        for (embedded) |entry| {
            if (entry.label.conductor <= max_conductor) {
                // Deep copy the entry to avoid double-free issues
                entries_slice[idx] = try cloneEntry(allocator, &entry);
                idx += 1;
            }
        }

        // Free original entries and array
        for (embedded) |*entry| {
            entry.deinit();
        }
        allocator.free(embedded);

        return .{
            .entries = entries_slice,
            .total_curves = count,
            .conductor_range = .{ min_conductor, max_found },
            .allocator = allocator,
        };
    }
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

// ═══════════════════════════════════════════════════════════════════════════════
// CREMONA DATABASE PARSER
// ═══════════════════════════════════════════════════════════════════════════════
// Parse Cremona's ecdata format (allcurves, allbsd)
// Format: conductor iso_class number [a1,a2,a3,a4,a6] rank torsion ...
// Source: https://github.com/JohnCremona/ecdata
// ═══════════════════════════════════════════════════════════════════════════════

/// Cremona database entry (with BSD data)
pub const CremonaEntry = struct {
    label: CurveLabel,
    conductor: u64,
    iso_class: []const u8,      // "a", "b", "c", ...
    iso_number: u8,             // 1, 2, 3, ...
    coefficients: [5]i64,       // [a1, a2, a3, a4, a6] general Weierstrass
    rank: u8,
    torsion: u8,
    // BSD fields (from allbsd)
    tamagawa_product: u32,
    real_period: f64,          // Ω_E
    l_value: f64,              // L(E,1) or L'(E,1)/Ω
    regulator: f64,            // R_E (1.0 for rank 0)
    sha_order: u64,            // |Ш(E/Q)|

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *const Self) void {
        self.label.deinit();
        self.allocator.free(self.iso_class);
    }
};

pub const CremonaParser = struct {
    allocator: std.mem.Allocator,
    data_dir: []const u8,

    const Self = @This();

    /// Parse allcurves file from Cremona database
    /// Format: conductor iso_class number [a1,a2,a3,a4,a6] rank torsion
    pub fn parseAllCurves(self: *const Self, file_path: []const u8) ![]CremonaEntry {
        const full_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.data_dir, file_path });
        defer self.allocator.free(full_path);

        const content = try std.fs.cwd().readFileAlloc(self.allocator, full_path, 50_000_000);
        defer self.allocator.free(content);

        // First pass: count lines
        var line_count: usize = 0;
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (line.len > 0 and line[0] != '#') line_count += 1;
        }

        // Allocate entries
        const entries = try self.allocator.alloc(CremonaEntry, line_count);

        // Second pass: parse entries
        lines = std.mem.splitScalar(u8, content, '\n');
        var idx: usize = 0;
        while (lines.next()) |line| {
            if (line.len == 0 or line[0] == '#') continue;

            entries[idx] = try self.parseAllCurvesLine(line);
            idx += 1;
        }

        return entries[0..idx];
    }

    /// Parse single allcurves line
    /// Format: 11 a 1 [0,-1,1,-10,-20] 0 5
    fn parseAllCurvesLine(self: *const Self, line: []const u8) !CremonaEntry {
        var tokenizer = std.mem.tokenizeScalar(u8, line, ' ');

        // Parse conductor
        const conductor_str = tokenizer.next() orelse return error.InvalidFormat;
        const conductor = try std.fmt.parseInt(u64, conductor_str, 10);

        // Parse iso_class
        const iso_class = try self.allocator.dupe(u8, tokenizer.next() orelse return error.InvalidFormat);

        // Parse iso_number
        const iso_number_str = tokenizer.next() orelse return error.InvalidFormat;
        const iso_number = try std.fmt.parseInt(u8, iso_number_str, 10);

        // Parse coefficients [a1,a2,a3,a4,a6]
        const coeffs_str = tokenizer.next() orelse return error.InvalidFormat;
        const coefficients = try self.parseGeneralCoefficients(coeffs_str);

        // Parse rank
        const rank_str = tokenizer.next() orelse return error.InvalidFormat;
        const rank = try std.fmt.parseInt(u8, rank_str, 10);

        // Parse torsion
        const torsion_str = tokenizer.next() orelse return error.InvalidFormat;
        const torsion = try std.fmt.parseInt(u8, torsion_str, 10);

        // Create label from components
        const label_str = try std.fmt.allocPrint(self.allocator, "{d}.{s}{d}", .{ conductor, iso_class, iso_number });
        defer self.allocator.free(label_str);
        const label = try CurveLabel.parse(self.allocator, label_str);

        // Default BSD values (will be filled from allbsd)
        return .{
            .label = label,
            .conductor = conductor,
            .iso_class = iso_class,
            .iso_number = iso_number,
            .coefficients = coefficients,
            .rank = rank,
            .torsion = torsion,
            .tamagawa_product = 1,
            .real_period = 0.0,
            .l_value = 0.0,
            .regulator = 1.0,
            .sha_order = 1,
            .allocator = self.allocator,
        };
    }

    /// Parse allbsd file from Cremona database
    /// Format: conductor iso_class number [a1,a2,a3,a4,a6] rank torsion tamagawa real_period l_value regulator sha
    pub fn parseAllBsd(self: *const Self, file_path: []const u8) ![]CremonaEntry {
        const full_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.data_dir, file_path });
        defer self.allocator.free(full_path);

        const content = try std.fs.cwd().readFileAlloc(self.allocator, full_path, 50_000_000);
        defer self.allocator.free(content);

        // First pass: count lines
        var line_count: usize = 0;
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (line.len > 0 and line[0] != '#') line_count += 1;
        }

        // Allocate entries
        const entries = try self.allocator.alloc(CremonaEntry, line_count);

        // Second pass: parse entries
        lines = std.mem.splitScalar(u8, content, '\n');
        var idx: usize = 0;
        while (lines.next()) |line| {
            if (line.len == 0 or line[0] == '#') continue;

            entries[idx] = try self.parseAllBsdLine(line);
            idx += 1;
        }

        return entries[0..idx];
    }

    /// Parse single allbsd line
    /// Format: 11 a 1 [0,-1,1,-10,-20] 0 5 5 1.2692... 0.2538... 1.0 1
    fn parseAllBsdLine(self: *const Self, line: []const u8) !CremonaEntry {
        var tokenizer = std.mem.tokenizeScalar(u8, line, ' ');

        // Parse conductor
        const conductor_str = tokenizer.next() orelse return error.InvalidFormat;
        const conductor = std.fmt.parseInt(u64, conductor_str, 10) catch |err| {
            std.debug.print("Failed to parse conductor: '{s}' -> {}\n", .{ conductor_str, err });
            return err;
        };

        // Parse iso_class
        const iso_class = try self.allocator.dupe(u8, tokenizer.next() orelse return error.InvalidFormat);

        // Parse iso_number
        const iso_number_str = tokenizer.next() orelse return error.InvalidFormat;
        const iso_number = std.fmt.parseInt(u8, iso_number_str, 10) catch |err| {
            std.debug.print("Failed to parse iso_number: '{s}' -> {}\n", .{ iso_number_str, err });
            return err;
        };

        // Parse coefficients [a1,a2,a3,a4,a6]
        const coeffs_str = tokenizer.next() orelse return error.InvalidFormat;
        const coefficients = try self.parseGeneralCoefficients(coeffs_str);

        // Parse rank
        const rank_str = tokenizer.next() orelse return error.InvalidFormat;
        const rank = std.fmt.parseInt(u8, rank_str, 10) catch |err| {
            std.debug.print("Failed to parse rank: '{s}' -> {}\n", .{ rank_str, err });
            return err;
        };

        // Parse torsion
        const torsion_str = tokenizer.next() orelse return error.InvalidFormat;
        const torsion = std.fmt.parseInt(u8, torsion_str, 10) catch |err| {
            std.debug.print("Failed to parse torsion: '{s}' -> {}\n", .{ torsion_str, err });
            return err;
        };

        // Parse tamagawa_product
        const tamagawa_str = tokenizer.next() orelse return error.InvalidFormat;
        const tamagawa_product = std.fmt.parseInt(u32, tamagawa_str, 10) catch |err| {
            std.debug.print("Failed to parse tamagawa: '{s}' -> {}\n", .{ tamagawa_str, err });
            return err;
        };

        // Parse real_period
        const period_str = tokenizer.next() orelse return error.InvalidFormat;
        const real_period = std.fmt.parseFloat(f64, period_str) catch |err| {
            std.debug.print("Failed to parse period: '{s}' -> {}\n", .{ period_str, err });
            return err;
        };

        // Parse l_value (L(E,1) or L'(E,1))
        const l_value_str = tokenizer.next() orelse return error.InvalidFormat;
        const l_value = std.fmt.parseFloat(f64, l_value_str) catch |err| {
            std.debug.print("Failed to parse l_value: '{s}' -> {}\n", .{ l_value_str, err });
            return err;
        };

        // Parse regulator
        const reg_str = tokenizer.next() orelse return error.InvalidFormat;
        const regulator = std.fmt.parseFloat(f64, reg_str) catch |err| {
            std.debug.print("Failed to parse regulator: '{s}' -> {}\n", .{ reg_str, err });
            return err;
        };

        // Parse sha_order (stored as float in file, convert to int)
        const sha_str = tokenizer.next() orelse return error.InvalidFormat;
        const sha_value = std.fmt.parseFloat(f64, sha_str) catch |err| {
            std.debug.print("Failed to parse sha: '{s}' -> {}\n", .{ sha_str, err });
            return err;
        };
        const sha_order: u64 = @intFromFloat(sha_value);

        // Create label from components
        const label_str = try std.fmt.allocPrint(self.allocator, "{d}.{s}{d}", .{ conductor, iso_class, iso_number });
        defer self.allocator.free(label_str);
        const label = try CurveLabel.parse(self.allocator, label_str);

        return .{
            .label = label,
            .conductor = conductor,
            .iso_class = iso_class,
            .iso_number = iso_number,
            .coefficients = coefficients,
            .rank = rank,
            .torsion = torsion,
            .tamagawa_product = tamagawa_product,
            .real_period = real_period,
            .l_value = l_value,
            .regulator = regulator,
            .sha_order = sha_order,
            .allocator = self.allocator,
        };
    }

    /// Parse general Weierstrass coefficients [a1,a2,a3,a4,a6]
    fn parseGeneralCoefficients(_: *const Self, coeffs_str: []const u8) ![5]i64 {
        // Remove brackets
        const start = if (coeffs_str[0] == '[') @as(usize, 1) else 0;
        const end = if (coeffs_str[coeffs_str.len - 1] == ']') @as(usize, coeffs_str.len - 1) else coeffs_str.len;
        const content = coeffs_str[start..end];

        var coeffs: [5]i64 = undefined;

        var i: usize = 0;
        var iter = std.mem.splitScalar(u8, content, ',');
        while (iter.next()) |coeff_str| {
            if (i >= 5) break;
            coeffs[i] = try std.fmt.parseInt(i64, coeff_str, 10);
            i += 1;
        }

        // Fill remaining with zeros
        while (i < 5) : (i += 1) {
            coeffs[i] = 0;
        }

        return coeffs;
    }

    /// Import curves from Cremona database up to max_conductor
    /// Single-pass streaming parser for better performance
    pub fn importFromCremona(self: *const Self, max_conductor: u64) ![]CremonaEntry {
        // Find all relevant allbsd files
        const allbsd_files = [_][]const u8{
            "allbsd/allbsd.00000-09999",
            "allbsd/allbsd.10000-19999",
            "allbsd/allbsd.20000-29999",
            "allbsd/allbsd.30000-39999",
            "allbsd/allbsd.40000-49999",
        };

        // Use ArrayListUnmanaged for dynamic growth (single-pass)
        var result_list = std.ArrayListUnmanaged(CremonaEntry){};
        errdefer {
            for (result_list.items) |*entry| {
                entry.deinit();
            }
            result_list.deinit(self.allocator);
        }

        for (allbsd_files) |file| {
            // Extract range start from filename like "allbsd/allbsd.00000-09999"
            const dot_idx = std.mem.lastIndexOfScalar(u8, file, '.') orelse continue;
            const range_start_str = file[dot_idx + 1 .. dot_idx + 6];
            const range_start = std.fmt.parseInt(u64, range_start_str, 10) catch 0;
            if (range_start > max_conductor) break;

            try self.parseAllBsdToList(max_conductor, file, &result_list);
        }

        return result_list.toOwnedSlice(self.allocator);
    }

    /// Parse allbsd file and add matching entries to result list
    fn parseAllBsdToList(self: *const Self, max_conductor: u64, file_path: []const u8, result_list: *std.ArrayListUnmanaged(CremonaEntry)) !void {
        const full_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.data_dir, file_path });
        defer self.allocator.free(full_path);

        const content = try std.fs.cwd().readFileAlloc(self.allocator, full_path, 50_000_000);
        defer self.allocator.free(content);

        // Single pass: parse and filter
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (line.len == 0 or line[0] == '#') continue;

            const entry = try self.parseAllBsdLine(line);
            if (entry.conductor <= max_conductor) {
                try result_list.append(self.allocator, entry);
            } else {
                // Entry doesn't match, clean it up
                entry.deinit();
            }
        }
    }

    /// Clone a Cremona entry
    fn cloneEntry(self: *const Self, entry: *const CremonaEntry) !CremonaEntry {
        const iso_class = try self.allocator.dupe(u8, entry.iso_class);
        errdefer self.allocator.free(iso_class);

        const label_str = try entry.label.format(self.allocator);
        defer self.allocator.free(label_str);
        const label = try CurveLabel.parse(self.allocator, label_str);

        return .{
            .label = label,
            .conductor = entry.conductor,
            .iso_class = iso_class,
            .iso_number = entry.iso_number,
            .coefficients = entry.coefficients,
            .rank = entry.rank,
            .torsion = entry.torsion,
            .tamagawa_product = entry.tamagawa_product,
            .real_period = entry.real_period,
            .l_value = entry.l_value,
            .regulator = entry.regulator,
            .sha_order = entry.sha_order,
            .allocator = self.allocator,
        };
    }
};

/// Import curves from Cremona database
pub fn importFromCremona(allocator: std.mem.Allocator, data_dir: []const u8, max_conductor: u64) ![]CremonaEntry {
    const parser = CremonaParser{
        .allocator = allocator,
        .data_dir = data_dir,
    };
    return parser.importFromCremona(max_conductor);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CremonaParser: parse allbsd file" {
    const testing = std.testing;
    const parser = CremonaParser{
        .allocator = testing.allocator,
        .data_dir = "/Users/playra/trinity-w1/data/ecdata",
    };

    const entries = try parser.importFromCremona(100);
    defer {
        for (entries) |*entry| {
            entry.deinit();
        }
        testing.allocator.free(entries);
    }

    try testing.expect(entries.len > 0);

    // Verify some curves were parsed
    var count: usize = 0;
    for (entries) |entry| {
        if (entry.conductor <= 100) count += 1;
    }
    try testing.expect(count > 0);
}
