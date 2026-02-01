const std = @import("std");

// ============================================================================
// TRINITY VALIDATOR - THE CONSCIENCE
// ============================================================================
// The Sacred Judge that examines all code and determines its worthiness.
// No code shall pass without the blessing of the Conscience.

/// Severity of sins
pub const Severity = enum {
    MORTAL_SIN, // Immediate failure
    VENIAL_SIN, // Warning, but passable
    MINOR_SIN, // Suggestion only

    pub fn weight(self: Severity) i32 {
        return switch (self) {
            .MORTAL_SIN => 100,
            .VENIAL_SIN => 10,
            .MINOR_SIN => 1,
        };
    }
};

/// A single sin found in the code
pub const Sin = struct {
    law: []const u8,
    severity: Severity,
    line: usize,
    column: usize,
    description: []const u8,
    evidence: []const u8,
};

/// Suggested penance for a sin
pub const Penance = struct {
    for_law: []const u8,
    suggestion: []const u8,
};

/// The final verdict
pub const Verdict = struct {
    is_valid: bool,
    sins: []const Sin,
    total_severity: i32,
    suggested_penance: []const Penance,

    pub fn format(self: Verdict, allocator: std.mem.Allocator) ![]const u8 {
        var result = std.ArrayListUnmanaged(u8){};

        if (self.is_valid) {
            try result.appendSlice(allocator, "✅ CODE IS BLESSED. No mortal sins detected.\n");
        } else {
            try result.appendSlice(allocator, "❌ CODE IS PROFANE. Sins detected:\n");
        }

        for (self.sins) |sin| {
            const line_str = try std.fmt.allocPrint(allocator, "  Line {d}: [{s}] {s}\n", .{ sin.line, @tagName(sin.severity), sin.description });
            defer allocator.free(line_str);
            try result.appendSlice(allocator, line_str);
        }

        if (self.suggested_penance.len > 0) {
            try result.appendSlice(allocator, "\n📿 PENANCE REQUIRED:\n");
            for (self.suggested_penance) |p| {
                const penance_str = try std.fmt.allocPrint(allocator, "  - {s}: {s}\n", .{ p.for_law, p.suggestion });
                defer allocator.free(penance_str);
                try result.appendSlice(allocator, penance_str);
            }
        }

        return try result.toOwnedSlice(allocator);
    }
};

/// The Conscience - validates code against the Sacred Canon
pub const Validator = struct {
    allocator: std.mem.Allocator,
    sins: std.ArrayListUnmanaged(Sin),
    penance: std.ArrayListUnmanaged(Penance),

    pub fn init(allocator: std.mem.Allocator) Validator {
        return Validator{
            .allocator = allocator,
            .sins = .{},
            .penance = .{},
        };
    }

    pub fn deinit(self: *Validator) void {
        self.sins.deinit(self.allocator);
        self.penance.deinit(self.allocator);
    }

    /// The main validation function
    pub fn validate(self: *Validator, code: []const u8) !Verdict {
        // Reset state
        self.sins.clearRetainingCapacity();
        self.penance.clearRetainingCapacity();

        // Run all checks
        try self.checkMagicNumbers(code);
        try self.checkProfaneNames(code);
        try self.checkMainEntryPoint(code);
        try self.checkConstPreference(code);
        try self.checkExplicitAllocation(code);
        try self.checkHolyDocumentation(code);
        try self.checkErrorSensitivity(code);
        try self.checkDivineTypes(code);

        // Calculate total severity
        var total: i32 = 0;
        var has_mortal: bool = false;
        for (self.sins.items) |sin| {
            total += sin.severity.weight();
            if (sin.severity == .MORTAL_SIN) has_mortal = true;
        }

        // Verdict: valid if no mortal sins and total < 50
        const is_valid = !has_mortal and total < 50;

        return Verdict{
            .is_valid = is_valid,
            .sins = self.sins.items,
            .total_severity = total,
            .suggested_penance = self.penance.items,
        };
    }

    /// LAW: NO_MAGIC_NUMBERS
    fn checkMagicNumbers(self: *Validator, code: []const u8) !void {
        var line_num: usize = 1;
        var i: usize = 0;

        while (i < code.len) {
            // Find start of a number
            if (std.ascii.isDigit(code[i])) {
                const start = i;
                var has_dot = false;

                // Consume the number
                while (i < code.len and (std.ascii.isDigit(code[i]) or code[i] == '.')) {
                    if (code[i] == '.') has_dot = true;
                    i += 1;
                }

                const num_str = code[start..i];
                const len = num_str.len;

                // Check if it's a forbidden magic number
                const is_magic = if (has_dot)
                    len > 3 and !std.mem.eql(u8, num_str, "0.0") and !std.mem.eql(u8, num_str, "1.0")
                else
                    len >= 4; // 4+ digit integers are suspicious

                if (is_magic) {
                    try self.sins.append(self.allocator, Sin{
                        .law = "NO_MAGIC_NUMBERS",
                        .severity = .VENIAL_SIN,
                        .line = line_num,
                        .column = start,
                        .description = "Magic number detected",
                        .evidence = num_str,
                    });

                    try self.penance.append(self.allocator, Penance{
                        .for_law = "NO_MAGIC_NUMBERS",
                        .suggestion = "Express this constant using PHI, PI, or E",
                    });
                }
            } else {
                if (code[i] == '\n') line_num += 1;
                i += 1;
            }
        }
    }

    /// LAW: SACRED_NAMING
    fn checkProfaneNames(self: *Validator, code: []const u8) !void {
        const profane = [_][]const u8{ "tmp", "temp", "foo", "bar", "baz", "data", "info", "stuff" };

        var line_num: usize = 1;
        var i: usize = 0;

        while (i < code.len) {
            // Find identifier start
            if (std.ascii.isAlphabetic(code[i]) or code[i] == '_') {
                const start = i;
                while (i < code.len and (std.ascii.isAlphanumeric(code[i]) or code[i] == '_')) {
                    i += 1;
                }
                const ident = code[start..i];

                for (profane) |p| {
                    if (std.mem.eql(u8, ident, p)) {
                        try self.sins.append(self.allocator, Sin{
                            .law = "SACRED_NAMING",
                            .severity = .MINOR_SIN,
                            .line = line_num,
                            .column = start,
                            .description = "Profane placeholder name",
                            .evidence = ident,
                        });

                        try self.penance.append(self.allocator, Penance{
                            .for_law = "SACRED_NAMING",
                            .suggestion = "Rename with purpose-revealing name",
                        });
                    }
                }
            } else {
                if (code[i] == '\n') line_num += 1;
                i += 1;
            }
        }
    }

    /// Check for main entry point (The Alpha)
    fn checkMainEntryPoint(self: *Validator, code: []const u8) !void {
        if (std.mem.indexOf(u8, code, "pub fn main") == null and
            std.mem.indexOf(u8, code, "fn main") == null)
        {
            try self.sins.append(self.allocator, Sin{
                .law = "THE_ALPHA",
                .severity = .MORTAL_SIN,
                .line = 1,
                .column = 0,
                .description = "Code lacks main entry point (The Alpha)",
                .evidence = "",
            });

            try self.penance.append(self.allocator, Penance{
                .for_law = "THE_ALPHA",
                .suggestion = "Add 'pub fn main() !void { ... }'",
            });
        }
    }

    /// LAW: CONST_PREFERENCE
    fn checkConstPreference(self: *Validator, code: []const u8) !void {
        // Count 'var ' occurrences
        var var_count: usize = 0;
        var i: usize = 0;

        while (i + 4 < code.len) {
            if (std.mem.eql(u8, code[i .. i + 4], "var ")) {
                var_count += 1;
            }
            i += 1;
        }

        // If there are too many vars, suggest const
        if (var_count > 10) {
            try self.sins.append(self.allocator, Sin{
                .law = "CONST_PREFERENCE",
                .severity = .MINOR_SIN,
                .line = 0,
                .column = 0,
                .description = "Excessive use of 'var' - consider using 'const' where possible",
                .evidence = "",
            });

            try self.penance.append(self.allocator, Penance{
                .for_law = "CONST_PREFERENCE",
                .suggestion = "Review var declarations and change to const if not mutated",
            });
        }
    }

    /// LAW: LAW_EXPLICIT_ALLOCATION
    fn checkExplicitAllocation(self: *Validator, code: []const u8) !void {
        // Check for global allocator usage
        if (std.mem.indexOf(u8, code, "std.heap.page_allocator")) |idx| {
            try self.sins.append(self.allocator, Sin{
                .law = "LAW_EXPLICIT_ALLOCATION",
                .severity = .MORTAL_SIN,
                .line = self.getLineNumber(code, idx),
                .column = idx,
                .description = "Explicit memory allocation required. Do not use global allocators.",
                .evidence = "std.heap.page_allocator",
            });

            try self.penance.append(self.allocator, Penance{
                .for_law = "LAW_EXPLICIT_ALLOCATION",
                .suggestion = "Pass an allocator explicitly to your function or struct init()",
            });
        }
    }

    /// LAW: LAW_HOLY_DOCUMENTATION
    fn checkHolyDocumentation(self: *Validator, code: []const u8) !void {
        var i: usize = 0;
        while (std.mem.indexOfPos(u8, code, i, "pub fn")) |idx| {
            // Check previous lines for ///
            var documented = false;
            var check_idx = idx;

            // Skip whitespace backwards
            while (check_idx > 0) {
                check_idx -= 1;
                const c = code[check_idx];
                if (c == '\n') {
                    // Check previous line content
                    var line_start = check_idx;
                    while (line_start > 0 and code[line_start - 1] != '\n') {
                        line_start -= 1;
                    }
                    if (line_start < check_idx) {
                        const line = code[line_start..check_idx];
                        const trimmed = std.mem.trim(u8, line, " \t\r");
                        if (std.mem.startsWith(u8, trimmed, "///")) {
                            documented = true;
                        }
                    }
                    break;
                } else if (!std.ascii.isWhitespace(c)) {
                    break;
                }
            }

            if (!documented) {
                try self.sins.append(self.allocator, Sin{
                    .law = "LAW_HOLY_DOCUMENTATION",
                    .severity = .VENIAL_SIN,
                    .line = self.getLineNumber(code, idx),
                    .column = idx,
                    .description = "Public function lacks Sacred Documentation (///)",
                    .evidence = "pub fn",
                });

                try self.penance.append(self.allocator, Penance{
                    .for_law = "LAW_HOLY_DOCUMENTATION",
                    .suggestion = "Add /// documentation comment before this public function",
                });
            }
            i = idx + 1;
        }
    }

    /// LAW: LAW_ERROR_SENSITIVITY
    fn checkErrorSensitivity(self: *Validator, code: []const u8) !void {
        const patterns = [_][]const u8{ "catch unreachable", "catch {}" };
        const descs = [_][]const u8{ "Hubris (catch unreachable)", "Ignorance (catch {})" };

        for (patterns, 0..) |p, idx| {
            var i: usize = 0;
            while (std.mem.indexOfPos(u8, code, i, p)) |match_idx| {
                try self.sins.append(self.allocator, Sin{
                    .law = "LAW_ERROR_SENSITIVITY",
                    .severity = .VENIAL_SIN,
                    .line = self.getLineNumber(code, match_idx),
                    .column = match_idx,
                    .description = descs[idx],
                    .evidence = p,
                });

                try self.penance.append(self.allocator, Penance{
                    .for_law = "LAW_ERROR_SENSITIVITY",
                    .suggestion = "Handle errors explicitly or propagate with 'try'",
                });
                i = match_idx + 1;
            }
        }
    }

    /// LAW: LAW_DIVINE_TYPES
    fn checkDivineTypes(self: *Validator, code: []const u8) !void {
        // If @cImport is present, we are lenient
        if (std.mem.indexOf(u8, code, "@cImport") != null) return;

        const profane = [_][]const u8{ "c_int", "c_uint", "c_long" };

        for (profane) |p| {
            var i: usize = 0;
            while (std.mem.indexOfPos(u8, code, i, p)) |match_idx| {
                // Ensure whole word
                const end = match_idx + p.len;
                if (end < code.len and (std.ascii.isAlphanumeric(code[end]) or code[end] == '_')) {
                    i = match_idx + 1;
                    continue;
                }

                try self.sins.append(self.allocator, Sin{
                    .law = "LAW_DIVINE_TYPES",
                    .severity = .MINOR_SIN,
                    .line = self.getLineNumber(code, match_idx),
                    .column = match_idx,
                    .description = "Profane C type used without @cImport",
                    .evidence = p,
                });

                try self.penance.append(self.allocator, Penance{
                    .for_law = "LAW_DIVINE_TYPES",
                    .suggestion = "Use sacred Zig types (usize, i32) or wrap C types",
                });
                i = match_idx + 1;
            }
        }
    }

    /// Helper: Get line number from index
    fn getLineNumber(_: *Validator, code: []const u8, idx: usize) usize {
        var lines: usize = 1;
        for (code[0..idx]) |c| {
            if (c == '\n') lines += 1;
        }
        return lines;
    }
};

// ============================================================================
// TEST HARNESS
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("⚖️ TRINITY VALIDATOR - The Conscience (v3.1)\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});

    // Test code with NEW sins
    const sinful_code =
        \\const buffer_size = 4096;
        \\
        \\pub fn process() void {
        \\    var gpa = std.heap.page_allocator; 
        \\    _ = gpa;
        \\    const x: c_int = 10;
        \\    run() catch unreachable;
        \\}
    ;

    // Test code that is BLESSED
    const blessed_code =
        \\const std = @import("std");
        \\pub const PHI: f64 = 1.618;
        \\
        \\/// Main entry point for the application
        \\pub fn main() void {
        \\    const x: usize = 10;
        \\    // Handled error
        \\    run() catch |err| { std.debug.print("Error: {}", .{err}); };
        \\}
        \\
        \\fn run() !void {}
    ;

    var validator = Validator.init(allocator);
    defer validator.deinit();

    std.debug.print("📜 Testing SINFUL code (New Laws):\n{s}\n\n", .{sinful_code});
    const verdict1 = try validator.validate(sinful_code);
    const report1 = try verdict1.format(allocator);
    defer allocator.free(report1);
    std.debug.print("{s}\n", .{report1});

    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});

    std.debug.print("📜 Testing BLESSED code:\n{s}\n\n", .{blessed_code});
    const verdict2 = try validator.validate(blessed_code);
    const report2 = try verdict2.format(allocator);
    defer allocator.free(report2);
    std.debug.print("{s}\n", .{report2});
}
