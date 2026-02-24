// ═══════════════════════════════════════════════════════════════════════════════
// tri_spec_parser.zig — Parser for .tri Sacred Spec format (sacred-spec-v1)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Format: YAML-like, simpler than .vibee (no types/behaviors/FSMs)
// Header: format: sacred-spec-v1
// Sections: bases, search, constants, predictions
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

// ═══════════════════════════════════════════════════════════════════════════════
// Data Types
// ═══════════════════════════════════════════════════════════════════════════════

pub const SacredConstant = struct {
    name: []const u8,
    symbol: []const u8,
    value: f64,
    category: []const u8,
    description: []const u8,
};

pub const SacredPrediction = struct {
    name: []const u8,
    formula: []const u8,
    n: i8,
    k: i8,
    m: i8,
    p: i8,
    q: i8,
    unit: []const u8,
};

pub const SearchBounds = struct {
    n_range: [2]i8 = .{ 1, 9 },
    k_range: [2]i8 = .{ -4, 4 },
    m_range: [2]i8 = .{ -3, 3 },
    p_range: [2]i8 = .{ -4, 4 },
    q_range: [2]i8 = .{ -3, 3 },
};

pub const SacredSpec = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
    bases: [4]f64, // TRINITY, PI, PHI, E (fixed order)
    search: SearchBounds,
    constants: ArrayList(SacredConstant),
    predictions: ArrayList(SacredPrediction),
    allocator: Allocator,

    pub fn init(allocator: Allocator) SacredSpec {
        return .{
            .name = "",
            .version = "",
            .description = "",
            .bases = .{ 3.0, std.math.pi, 1.6180339887498948482, std.math.e },
            .search = .{},
            .constants = .{},
            .predictions = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SacredSpec) void {
        self.constants.deinit(self.allocator);
        self.predictions.deinit(self.allocator);
    }

    pub fn constantCount(self: *const SacredSpec) usize {
        return self.constants.items.len;
    }

    pub fn predictionCount(self: *const SacredSpec) usize {
        return self.predictions.items.len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Parser
// ═══════════════════════════════════════════════════════════════════════════════

pub const TriSpecParser = struct {
    const Self = @This();

    allocator: Allocator,
    source: []const u8,
    pos: usize,
    line: usize,

    pub fn init(allocator: Allocator, source: []const u8) TriSpecParser {
        return .{
            .allocator = allocator,
            .source = source,
            .pos = 0,
            .line = 1,
        };
    }

    pub fn parse(self: *Self) !SacredSpec {
        var spec = SacredSpec.init(self.allocator);

        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const key = self.readKey();
            if (key.len == 0) {
                self.pos += 1;
                continue;
            }

            // Skip colon after key
            if (self.pos < self.source.len and self.source[self.pos] == ':') {
                self.pos += 1;
            }

            if (std.mem.eql(u8, key, "format")) {
                self.skipInlineWhitespace();
                const val = self.readValue();
                if (!std.mem.eql(u8, val, "sacred-spec-v1")) {
                    return error.UnsupportedFormat;
                }
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "name")) {
                self.skipInlineWhitespace();
                spec.name = self.readValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "version")) {
                self.skipInlineWhitespace();
                spec.version = self.readQuotedValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "description")) {
                self.skipInlineWhitespace();
                spec.description = self.readQuotedValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "bases")) {
                self.skipToNextLine();
                self.parseBases(&spec);
            } else if (std.mem.eql(u8, key, "search")) {
                self.skipToNextLine();
                self.parseSearch(&spec.search);
            } else if (std.mem.eql(u8, key, "constants")) {
                self.skipToNextLine();
                try self.parseConstants(&spec.constants);
            } else if (std.mem.eql(u8, key, "predictions")) {
                self.skipToNextLine();
                try self.parsePredictions(&spec.predictions);
            } else {
                self.skipToNextLine();
            }
        }

        return spec;
    }

    // ─── Section Parsers ─────────────────────────────────────────────────────

    fn parseBases(self: *Self, spec: *SacredSpec) void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const key = self.readKey();
            if (self.pos < self.source.len and self.source[self.pos] == ':') {
                self.pos += 1;
            }
            self.skipInlineWhitespace();
            const val_str = self.readValue();
            const val = std.fmt.parseFloat(f64, val_str) catch 0;

            if (std.mem.eql(u8, key, "TRINITY")) {
                spec.bases[0] = val;
            } else if (std.mem.eql(u8, key, "PI")) {
                spec.bases[1] = val;
            } else if (std.mem.eql(u8, key, "PHI")) {
                spec.bases[2] = val;
            } else if (std.mem.eql(u8, key, "E")) {
                spec.bases[3] = val;
            }
            self.skipToNextLine();
        }
    }

    fn parseSearch(self: *Self, search: *SearchBounds) void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const key = self.readKey();
            if (self.pos < self.source.len and self.source[self.pos] == ':') {
                self.pos += 1;
            }
            self.skipInlineWhitespace();
            const range = self.parseRange();

            if (std.mem.eql(u8, key, "n_range")) {
                search.n_range = range;
            } else if (std.mem.eql(u8, key, "k_range")) {
                search.k_range = range;
            } else if (std.mem.eql(u8, key, "m_range")) {
                search.m_range = range;
            } else if (std.mem.eql(u8, key, "p_range")) {
                search.p_range = range;
            } else if (std.mem.eql(u8, key, "q_range")) {
                search.q_range = range;
            }
            self.skipToNextLine();
        }
    }

    fn parseConstants(self: *Self, constants: *ArrayList(SacredConstant)) Allocator.Error!void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            // Expect "- " prefix for list items
            if (self.pos + 1 < self.source.len and self.source[self.pos] == '-' and self.source[self.pos + 1] == ' ') {
                self.pos += 2; // skip "- "
                var constant = SacredConstant{
                    .name = "",
                    .symbol = "",
                    .value = 0,
                    .category = "",
                    .description = "",
                };

                // First field on same line as "-"
                self.parseField(&constant);
                self.skipToNextLine();

                // Remaining fields (deeper indent)
                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const field_indent = self.countIndent();
                    if (field_indent < 4) break;
                    self.pos += field_indent;

                    // Check if this is a new list item
                    if (self.pos < self.source.len and self.source[self.pos] == '-') break;

                    self.parseField(&constant);
                    self.skipToNextLine();
                }

                try constants.append(self.allocator, constant);
            } else {
                self.skipToNextLine();
            }
        }
    }

    fn parsePredictions(self: *Self, predictions: *ArrayList(SacredPrediction)) Allocator.Error!void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            if (self.pos + 1 < self.source.len and self.source[self.pos] == '-' and self.source[self.pos + 1] == ' ') {
                self.pos += 2;
                var pred = SacredPrediction{
                    .name = "",
                    .formula = "",
                    .n = 0,
                    .k = 0,
                    .m = 0,
                    .p = 0,
                    .q = 0,
                    .unit = "",
                };

                self.parsePredField(&pred);
                self.skipToNextLine();

                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const field_indent = self.countIndent();
                    if (field_indent < 4) break;
                    self.pos += field_indent;

                    if (self.pos < self.source.len and self.source[self.pos] == '-') break;

                    self.parsePredField(&pred);
                    self.skipToNextLine();
                }

                try predictions.append(self.allocator, pred);
            } else {
                self.skipToNextLine();
            }
        }
    }

    // ─── Field Parsers ───────────────────────────────────────────────────────

    fn parseField(self: *Self, c: *SacredConstant) void {
        const key = self.readKey();
        if (self.pos < self.source.len and self.source[self.pos] == ':') {
            self.pos += 1;
        }
        self.skipInlineWhitespace();

        if (std.mem.eql(u8, key, "name")) {
            c.name = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "symbol")) {
            c.symbol = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "value")) {
            const val_str = self.readValue();
            c.value = std.fmt.parseFloat(f64, val_str) catch 0;
        } else if (std.mem.eql(u8, key, "category")) {
            c.category = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "description")) {
            c.description = self.readQuotedValue();
        }
    }

    fn parsePredField(self: *Self, p: *SacredPrediction) void {
        const key = self.readKey();
        if (self.pos < self.source.len and self.source[self.pos] == ':') {
            self.pos += 1;
        }
        self.skipInlineWhitespace();

        if (std.mem.eql(u8, key, "name")) {
            p.name = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "formula")) {
            p.formula = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "n")) {
            p.n = self.readI8();
        } else if (std.mem.eql(u8, key, "k")) {
            p.k = self.readI8();
        } else if (std.mem.eql(u8, key, "m")) {
            p.m = self.readI8();
        } else if (std.mem.eql(u8, key, "p")) {
            p.p = self.readI8();
        } else if (std.mem.eql(u8, key, "q")) {
            p.q = self.readI8();
        } else if (std.mem.eql(u8, key, "unit")) {
            p.unit = self.readQuotedValue();
        }
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    fn readKey(self: *Self) []const u8 {
        const start = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ':' or c == ' ' or c == '\n' or c == '\r') break;
            self.pos += 1;
        }
        return self.source[start..self.pos];
    }

    fn readValue(self: *Self) []const u8 {
        self.skipInlineWhitespace();
        const start = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == '\n' or c == '\r') break;
            if (c == '#') break;
            self.pos += 1;
        }
        return std.mem.trim(u8, self.source[start..self.pos], " \t");
    }

    fn readQuotedValue(self: *Self) []const u8 {
        self.skipInlineWhitespace();
        if (self.pos < self.source.len and self.source[self.pos] == '"') {
            self.pos += 1;
            const start = self.pos;
            while (self.pos < self.source.len and self.source[self.pos] != '"') {
                self.pos += 1;
            }
            const value = self.source[start..self.pos];
            if (self.pos < self.source.len) self.pos += 1;
            return value;
        }
        return self.readValue();
    }

    fn readI8(self: *Self) i8 {
        const val_str = self.readValue();
        return std.fmt.parseInt(i8, val_str, 10) catch 0;
    }

    fn parseRange(self: *Self) [2]i8 {
        // Parse "[min, max]" format
        var result: [2]i8 = .{ 0, 0 };
        const val = self.readValue();

        // Find numbers between [ and ]
        var idx: usize = 0;
        // Skip to first number
        while (idx < val.len and (val[idx] == '[' or val[idx] == ' ')) : (idx += 1) {}
        const start1 = idx;
        while (idx < val.len and val[idx] != ',' and val[idx] != ']') : (idx += 1) {}
        const num1 = std.mem.trim(u8, val[start1..idx], " \t");
        result[0] = std.fmt.parseInt(i8, num1, 10) catch 0;

        // Skip comma
        if (idx < val.len and val[idx] == ',') idx += 1;
        while (idx < val.len and val[idx] == ' ') : (idx += 1) {}
        const start2 = idx;
        while (idx < val.len and val[idx] != ']' and val[idx] != ' ') : (idx += 1) {}
        const num2 = std.mem.trim(u8, val[start2..idx], " \t]");
        result[1] = std.fmt.parseInt(i8, num2, 10) catch 0;

        return result;
    }

    fn countIndent(self: *Self) usize {
        var count: usize = 0;
        const start = self.pos;
        while (self.pos < self.source.len and self.source[self.pos] == ' ') {
            count += 1;
            self.pos += 1;
        }
        self.pos = start; // Rewind
        return count;
    }

    fn skipInlineWhitespace(self: *Self) void {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ' ' or c == '\t') {
                self.pos += 1;
            } else break;
        }
    }

    fn skipToNextLine(self: *Self) void {
        while (self.pos < self.source.len and self.source[self.pos] != '\n') {
            self.pos += 1;
        }
        if (self.pos < self.source.len) {
            self.pos += 1;
            self.line += 1;
        }
    }

    fn skipEmptyLinesAndComments(self: *Self) void {
        while (self.pos < self.source.len) {
            const line_start = self.pos;

            // Skip whitespace at start of line
            while (self.pos < self.source.len and (self.source[self.pos] == ' ' or self.source[self.pos] == '\t')) {
                self.pos += 1;
            }

            if (self.pos >= self.source.len) break;

            const c = self.source[self.pos];
            if (c == '\n' or c == '\r') {
                // Empty line
                self.pos += 1;
                if (c == '\r' and self.pos < self.source.len and self.source[self.pos] == '\n') {
                    self.pos += 1;
                }
                self.line += 1;
                continue;
            }

            if (c == '#') {
                // Comment line
                self.skipToNextLine();
                continue;
            }

            // Non-empty, non-comment line — rewind to line start
            self.pos = line_start;
            break;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Load spec from file
// ═══════════════════════════════════════════════════════════════════════════════

pub fn loadSpecFromFile(allocator: Allocator, path: []const u8) !struct { spec: SacredSpec, source: []const u8 } {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
    var parser = TriSpecParser.init(allocator, source);
    const spec = try parser.parse();

    return .{ .spec = spec, .source = source };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parse sacred spec header" {
    const source =
        \\format: sacred-spec-v1
        \\name: sacred_formula
        \\version: "1.0.0"
        \\description: "Test spec"
        \\
        \\bases:
        \\  TRINITY: 3.0
        \\  PI: 3.14159265358979323846
        \\  PHI: 1.6180339887498948482
        \\  E: 2.71828182845904523536
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqualStrings("sacred_formula", spec.name);
    try std.testing.expectEqualStrings("1.0.0", spec.version);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), spec.bases[0], 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 1.618033988749894), spec.bases[2], 1e-6);
}

test "parse search bounds" {
    const source =
        \\format: sacred-spec-v1
        \\name: test
        \\
        \\search:
        \\  n_range: [1, 9]
        \\  k_range: [-4, 4]
        \\  m_range: [-3, 3]
        \\  p_range: [-4, 4]
        \\  q_range: [-3, 3]
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(i8, 1), spec.search.n_range[0]);
    try std.testing.expectEqual(@as(i8, 9), spec.search.n_range[1]);
    try std.testing.expectEqual(@as(i8, -4), spec.search.k_range[0]);
    try std.testing.expectEqual(@as(i8, 4), spec.search.k_range[1]);
}

test "parse constants" {
    const source =
        \\format: sacred-spec-v1
        \\name: test
        \\
        \\constants:
        \\  - name: "1/alpha"
        \\    symbol: "FINE_STRUCTURE_INV"
        \\    value: 137.036
        \\    category: "particle_physics"
        \\    description: "Inverse fine-structure constant"
        \\
        \\  - name: "H_0"
        \\    symbol: "HUBBLE"
        \\    value: 67.4
        \\    category: "cosmology"
        \\    description: "Hubble constant"
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 2), spec.constantCount());
    try std.testing.expectEqualStrings("1/alpha", spec.constants.items[0].name);
    try std.testing.expectApproxEqAbs(@as(f64, 137.036), spec.constants.items[0].value, 1e-6);
    try std.testing.expectEqualStrings("cosmology", spec.constants.items[1].category);
}

test "parse predictions" {
    const source =
        \\format: sacred-spec-v1
        \\name: test
        \\
        \\predictions:
        \\  - name: "Neutrino mass hint"
        \\    formula: "1*3^-1*pi^-1*phi^-4*e^-1"
        \\    n: 1
        \\    k: -1
        \\    m: -1
        \\    p: -4
        \\    q: -1
        \\    unit: "eV"
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 1), spec.predictionCount());
    try std.testing.expectEqualStrings("Neutrino mass hint", spec.predictions.items[0].name);
    try std.testing.expectEqual(@as(i8, -4), spec.predictions.items[0].p);
    try std.testing.expectEqual(@as(i8, -1), spec.predictions.items[0].q);
}

test "reject wrong format" {
    const source =
        \\format: wrong-format
        \\name: test
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    const result = parser.parse();
    try std.testing.expectError(error.UnsupportedFormat, result);
}
