// ═══════════════════════════════════════════════════════════════════════════════
// ANTIPATTERN DETECTOR - Runtime verification onand VIBEE beforeand
// ═══════════════════════════════════════════════════════════════════════════════
// SACRED FORMULA: V = n × 3^k × π^m × φ^p × e^q
//  : φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════
// :  bootstrap code for intoand and filein
// andtoand: specs/antipatterns.tri
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// SEVERITY LEVELS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Severity = enum {
    critical, // ⛔ toand toand
    high, // ⚠️  andwithinand
    medium, // ℹ️ towith andwithinand
    low, // 💡 and

    pub fn symbol(self: Severity) []const u8 {
        return switch (self) {
            .critical => "⛔",
            .high => "⚠️",
            .medium => "ℹ️",
            .low => "💡",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ANTIPATTERN TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const AntipatternType = enum {
    direct_implementation, // .zig  .tri
    legacy_web_files, // .html/.css/.js
    missing_tests, //  test_cases
    missing_creation_pattern, //  creation_pattern
    false_optimization_claims, //  toand
    esoteric_over_science, // fromandto  withinand
    missing_pas_analysis, //  PAS onand
    manual_code_without_spec, //  code  withandtoand
    spec_implementation_mismatch, // andtoand not withanswerwithin to

    pub fn severity(self: AntipatternType) Severity {
        return switch (self) {
            .direct_implementation => .critical,
            .legacy_web_files => .critical,
            .manual_code_without_spec => .critical,
            .missing_tests => .high,
            .missing_creation_pattern => .high,
            .spec_implementation_mismatch => .high,
            .false_optimization_claims => .medium,
            .esoteric_over_science => .medium,
            .missing_pas_analysis => .low,
        };
    }

    pub fn description(self: AntipatternType) []const u8 {
        return switch (self) {
            .direct_implementation => "andwithand .zig file  .tri withandtoand",
            .legacy_web_files => "yesand legacy web filein (.html/.css/.js)",
            .missing_tests => "andtoand  test_cases",
            .missing_creation_pattern => "andtoand  creation_pattern",
            .false_optimization_claims => " toand  andand",
            .esoteric_over_science => "fromandto  on withinand",
            .missing_pas_analysis => "and  PAS onand",
            .manual_code_without_spec => " to before notandinwith and .tri",
            .spec_implementation_mismatch => " not withfrominwithin withandtoand",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VIOLATION REPORT
// ═══════════════════════════════════════════════════════════════════════════════

pub const Violation = struct {
    antipattern: AntipatternType,
    file_path: []const u8,
    line: ?u32,
    message: []const u8,

    pub fn format(self: Violation, buf: []u8) []u8 {
        const sev = self.antipattern.severity();
        const result = std.fmt.bufPrint(buf, "{s} [{s}] {s}:{?d}: {s}", .{
            sev.symbol(),
            @tagName(self.antipattern),
            self.file_path,
            self.line,
            self.message,
        }) catch return buf[0..0];
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXCEPTIONS - File, which   onandwith on
// ═══════════════════════════════════════════════════════════════════════════════

const BOOTSTRAP_EXCEPTIONS = [_][]const u8{
    "parser.zig",
    "codegen.zig",
    "vm.zig",
    "pas.zig",
    "antipattern_detector.zig", // from file
    // and with withinand withandtoand
    "vm_core.zig", // specs/vm_core.tri
    "vm_opcodes.zig", // specs/vm_opcodes.tri
    "vm_jit.zig", // specs/vm_jit.tri
    "vm_isolation.zig", // specs/vm_isolation.tri
    "vm_minimal.zig", // specs/vm_minimal.tri (TODO: create)
    "vm_cache.zig", // specs/vm_cache.tri (TODO: create)
    "fuzz.zig", // specs/fuzz.tri (TODO: create)
};

fn isBootstrapException(file_name: []const u8) bool {
    for (BOOTSTRAP_EXCEPTIONS) |exception| {
        if (std.mem.eql(u8, file_name, exception)) {
            return true;
        }
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DETECTOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const AntipatternDetector = struct {
    allocator: Allocator,
    violations: std.ArrayList(Violation),
    specs_dir: []const u8,

    // Statistics
    files_scanned: u32,
    violations_critical: u32,
    violations_high: u32,
    violations_medium: u32,
    violations_low: u32,

    pub fn init(allocator: Allocator, specs_dir: []const u8) AntipatternDetector {
        return .{
            .allocator = allocator,
            .violations = std.ArrayList(Violation).init(allocator),
            .specs_dir = specs_dir,
            .files_scanned = 0,
            .violations_critical = 0,
            .violations_high = 0,
            .violations_medium = 0,
            .violations_low = 0,
        };
    }

    pub fn deinit(self: *AntipatternDetector) void {
        self.violations.deinit();
    }

    /// Check if a .zig file has a corresponding .tri spec
    pub fn checkDirectImplementation(self: *AntipatternDetector, file_path: []const u8) !void {
        self.files_scanned += 1;

        // Extract file name
        const file_name = std.fs.path.basename(file_path);

        // Check if it's a bootstrap exception
        if (isBootstrapException(file_name)) {
            return;
        }

        // Check extension
        if (!std.mem.endsWith(u8, file_name, ".zig")) {
            return;
        }

        // Construct expected spec path
        // base_name would be used to check specs/{base_name}.tri
        _ = file_name[0 .. file_name.len - 4]; // Remove .zig (unused in simplified version)

        // Check if spec exists (simplified - just record violation)
        // In real implementation, would check filesystem
        try self.addViolation(.{
            .antipattern = .direct_implementation,
            .file_path = file_path,
            .line = null,
            .message = " withfrominwithin .tri withandtoand",
        });
    }

    /// Check for legacy web files
    pub fn checkLegacyWebFile(self: *AntipatternDetector, file_path: []const u8) !void {
        self.files_scanned += 1;

        const file_name = std.fs.path.basename(file_path);

        // Allow runtime.html
        if (std.mem.eql(u8, file_name, "runtime.html")) {
            return;
        }

        // Check for forbidden extensions
        const forbidden = [_][]const u8{ ".html", ".css", ".js", ".ts", ".jsx", ".tsx" };

        for (forbidden) |ext| {
            if (std.mem.endsWith(u8, file_name, ext)) {
                try self.addViolation(.{
                    .antipattern = .legacy_web_files,
                    .file_path = file_path,
                    .line = null,
                    .message = "Legacy web file - and in runtime/runtime.html",
                });
                return;
            }
        }
    }

    fn addViolation(self: *AntipatternDetector, violation: Violation) !void {
        try self.violations.append(violation);

        switch (violation.antipattern.severity()) {
            .critical => self.violations_critical += 1,
            .high => self.violations_high += 1,
            .medium => self.violations_medium += 1,
            .low => self.violations_low += 1,
        }
    }

    pub fn hasBlockingViolations(self: *const AntipatternDetector) bool {
        return self.violations_critical > 0;
    }

    pub fn getReport(self: *const AntipatternDetector) DetectorReport {
        return .{
            .files_scanned = self.files_scanned,
            .total_violations = @intCast(self.violations.items.len),
            .critical = self.violations_critical,
            .high = self.violations_high,
            .medium = self.violations_medium,
            .low = self.violations_low,
            .should_block = self.hasBlockingViolations(),
        };
    }
};

pub const DetectorReport = struct {
    files_scanned: u32,
    total_violations: u32,
    critical: u32,
    high: u32,
    medium: u32,
    low: u32,
    should_block: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SPEC VALIDATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const SpecValidator = struct {
    pub fn validateCompleteness(content: []const u8) SpecValidation {
        var result = SpecValidation{
            .has_creation_pattern = false,
            .has_behaviors = false,
            .has_test_cases = false,
            .has_pas_analysis = false,
            .missing = undefined,
            .missing_count = 0,
        };

        // Simple string search (real implementation would parse YAML)
        if (std.mem.indexOf(u8, content, "creation_pattern:") != null) {
            result.has_creation_pattern = true;
        } else {
            result.missing[result.missing_count] = "creation_pattern";
            result.missing_count += 1;
        }

        if (std.mem.indexOf(u8, content, "behaviors:") != null) {
            result.has_behaviors = true;
        } else {
            result.missing[result.missing_count] = "behaviors";
            result.missing_count += 1;
        }

        if (std.mem.indexOf(u8, content, "test_cases:") != null) {
            result.has_test_cases = true;
        } else {
            result.missing[result.missing_count] = "test_cases";
            result.missing_count += 1;
        }

        if (std.mem.indexOf(u8, content, "pas_analysis:") != null) {
            result.has_pas_analysis = true;
        }

        return result;
    }
};

pub const SpecValidation = struct {
    has_creation_pattern: bool,
    has_behaviors: bool,
    has_test_cases: bool,
    has_pas_analysis: bool,
    missing: [4][]const u8,
    missing_count: u8,

    pub fn isComplete(self: *const SpecValidation) bool {
        return self.has_creation_pattern and self.has_behaviors and self.has_test_cases;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "bootstrap exceptions" {
    try std.testing.expect(isBootstrapException("parser.zig"));
    try std.testing.expect(isBootstrapException("vm.zig"));
    try std.testing.expect(!isBootstrapException("type_feedback.zig"));
}

test "severity levels" {
    try std.testing.expectEqual(Severity.critical, AntipatternType.direct_implementation.severity());
    try std.testing.expectEqual(Severity.critical, AntipatternType.legacy_web_files.severity());
    try std.testing.expectEqual(Severity.high, AntipatternType.missing_tests.severity());
}

test "spec validation" {
    const complete_spec =
        \\name: test
        \\creation_pattern:
        \\  source: A
        \\behaviors:
        \\  - name: test
        \\    test_cases:
        \\      - name: case1
        \\pas_analysis:
        \\  current: O(n)
    ;

    const validation = SpecValidator.validateCompleteness(complete_spec);
    try std.testing.expect(validation.has_creation_pattern);
    try std.testing.expect(validation.has_behaviors);
    try std.testing.expect(validation.has_test_cases);
    try std.testing.expect(validation.has_pas_analysis);
    try std.testing.expect(validation.isComplete());
}

test "incomplete spec validation" {
    const incomplete_spec =
        \\name: test
        \\behaviors:
        \\  - name: test
    ;

    const validation = SpecValidator.validateCompleteness(incomplete_spec);
    try std.testing.expect(!validation.has_creation_pattern);
    try std.testing.expect(validation.has_behaviors);
    try std.testing.expect(!validation.has_test_cases);
    try std.testing.expect(!validation.isComplete());
}

test "detector report" {
    var detector = AntipatternDetector.init(std.testing.allocator, "specs/");
    defer detector.deinit();

    // Simulate violations
    try detector.addViolation(.{
        .antipattern = .direct_implementation,
        .file_path = "test.zig",
        .line = null,
        .message = "test",
    });

    const report = detector.getReport();
    try std.testing.expectEqual(@as(u32, 1), report.critical);
    try std.testing.expect(report.should_block);
}

// ═══════════════════════════════════════════════════════════════════════════════
// VM INTEGRATION - Runtime antipattern checking
// ═══════════════════════════════════════════════════════════════════════════════

pub const VMAntipatternChecker = struct {
    detector: AntipatternDetector,
    enabled: bool,
    check_on_load: bool,

    pub fn init(allocator: Allocator) VMAntipatternChecker {
        return .{
            .detector = AntipatternDetector.init(allocator, "specs/"),
            .enabled = true,
            .check_on_load = true,
        };
    }

    pub fn deinit(self: *VMAntipatternChecker) void {
        self.detector.deinit();
    }

    /// Check if a module being loaded has a valid spec
    pub fn checkModuleLoad(self: *VMAntipatternChecker, module_path: []const u8) !void {
        if (!self.enabled or !self.check_on_load) return;

        try self.detector.checkDirectImplementation(module_path);
    }

    /// Validate that code follows Creation Pattern
    pub fn validateCreationPattern(self: *VMAntipatternChecker, spec_content: []const u8) SpecValidation {
        _ = self;
        return SpecValidator.validateCompleteness(spec_content);
    }

    /// Get current violation status
    pub fn hasViolations(self: *const VMAntipatternChecker) bool {
        return self.detector.violations.items.len > 0;
    }

    /// Get blocking status
    pub fn shouldBlock(self: *const VMAntipatternChecker) bool {
        return self.detector.hasBlockingViolations();
    }

    /// Print violations to writer
    pub fn printViolations(self: *const VMAntipatternChecker, writer: anytype) !void {
        const report = self.detector.getReport();

        try writer.print("\n═══════════════════════════════════════════════════════════════\n", .{});
        try writer.print("ANTIPATTERN DETECTOR REPORT\n", .{});
        try writer.print("═══════════════════════════════════════════════════════════════\n", .{});
        try writer.print("Files scanned:    {d}\n", .{report.files_scanned});
        try writer.print("Total violations: {d}\n", .{report.total_violations});
        try writer.print("  ⛔ Critical:    {d}\n", .{report.critical});
        try writer.print("  ⚠️  High:        {d}\n", .{report.high});
        try writer.print("  ℹ️  Medium:      {d}\n", .{report.medium});
        try writer.print("  💡 Low:         {d}\n", .{report.low});
        try writer.print("Should block:     {s}\n", .{if (report.should_block) "YES" else "NO"});
        try writer.print("═══════════════════════════════════════════════════════════════\n", .{});

        if (report.total_violations > 0) {
            try writer.print("\nViolations:\n", .{});
            for (self.detector.violations.items) |violation| {
                var buf: [512]u8 = undefined;
                const formatted = violation.format(&buf);
                try writer.print("  {s}\n", .{formatted});
            }
        }
    }
};

test "VM antipattern checker" {
    var checker = VMAntipatternChecker.init(std.testing.allocator);
    defer checker.deinit();

    // Initially no violations
    try std.testing.expect(!checker.hasViolations());
    try std.testing.expect(!checker.shouldBlock());
}

test "spec validation completeness" {
    const complete =
        \\name: test
        \\creation_pattern:
        \\  source: A
        \\behaviors:
        \\  - name: b
        \\    test_cases:
        \\      - name: c
    ;

    var checker = VMAntipatternChecker.init(std.testing.allocator);
    defer checker.deinit();

    const validation = checker.validateCreationPattern(complete);
    try std.testing.expect(validation.isComplete());
}
