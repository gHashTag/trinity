//! Auto-Code-Patching Engine for Sacred Mathematics
//!
//! This module provides automated code patching capabilities for discovering
//! and applying sacred mathematics improvements to Zig source code.
//!
//! Features:
//! - Scan code for sacred patterns (formulas, constants, gematria values)
//! - Generate patches with confidence scoring
//! - Validate patches before application
//! - Safely apply patches with automatic rollback
//! - Directory-wide scanning and patching

const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const process = std.process;

/// Use Managed ArrayList for easier API (has built-in allocator)
const ArrayList = std.array_list.Managed;

/// Sacred mathematical constants
pub const SacredConstants = struct {
    pub const PHI: f64 = 1.6180339887498948482045868343656; // Golden ratio
    pub const PHI_SQUARED: f64 = 2.6180339887498948482045868343656; // φ²
    pub const PHI_INVERSE: f64 = 0.61803398874989484820458683436564; // 1/φ
    pub const PI: f64 = 3.1415926535897932384626433832795;
    pub const E: f64 = 2.7182818284590452353602874713527;
    pub const TRINITY: f64 = 3.0; // φ² + 1/φ² = 3
    pub const SQRT_5: f64 = 2.2360679774997896964091736687313;
    pub const LUCAS_3: f64 = 3.0; // L(2) in Lucas sequence
    pub const MU: f64 = 0.0382; // φ^(-4) - sacred micro constant
    pub const CHI: f64 = 0.0618; // χ = φ - 2
    pub const SIGMA: f64 = 1.6180339887498948482045868343656; // σ = φ
    pub const EPSILON: f64 = 0.33333333333333333333333333333333; // ε = 1/3
};

/// Types of patches the engine can generate
pub const PatchType = enum {
    FORMULA_OPTIMIZATION,
    CONSTANT_REPLACEMENT,
    GEMATRIA_ENHANCEMENT,
    PHI_WEIGHTED_FIX,
    TRINITY_IDENTITY,
    SACRED_RATIO,
};

/// Result of a patch operation
pub const PatchResult = struct {
    applied_count: usize = 0,
    skipped_count: usize = 0,
    failed_count: usize = 0,
    rolled_back_count: usize = 0,
    total_patches: usize = 0,
    success_rate: f64 = 0.0,

    pub fn format(self: PatchResult, allocator: mem.Allocator) ![]const u8 {
        const rate_fmt = try std.fmt.allocPrint(allocator, "{d:.2}", .{self.success_rate * 100.0});
        defer allocator.free(rate_fmt);

        return try std.fmt.allocPrint(allocator,
            \\Patch Results:
            \\  Total:      {d}
            \\  Applied:    {d}
            \\  Skipped:    {d}
            \\  Failed:     {d}
            \\  Rollbacks:  {d}
            \\  Success:    {s}%
        , .{
            self.total_patches,
            self.applied_count,
            self.skipped_count,
            self.failed_count,
            self.rolled_back_count,
            rate_fmt,
        });
    }
};

/// Statistics from directory scanning
pub const PatchStats = struct {
    files_scanned: usize = 0,
    patches_found: usize = 0,
    patches_applied: usize = 0,
    patches_rolled_back: usize = 0,
    total_lines_analyzed: usize = 0,

    pub fn format(self: PatchStats, allocator: mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator,
            \\Directory Scan Results:
            \\  Files scanned:     {d}
            \\  Patches found:     {d}
            \\  Patches applied:   {d}
            \\  Patches rolled back: {d}
            \\  Lines analyzed:    {d}
        , .{
            self.files_scanned,
            self.patches_found,
            self.patches_applied,
            self.patches_rolled_back,
            self.total_lines_analyzed,
        });
    }
};

/// A single auto-generated patch
pub const AutoCodePatch = struct {
    file_path: []const u8,
    line_number: usize,
    original_code: []const u8,
    patched_code: []const u8,
    patch_type: PatchType,
    reason: []const u8,
    confidence: f64,
    applied: bool,
    rollback_backup: ?[]const u8,

    /// Create a new patch
    pub fn init(
        allocator: mem.Allocator,
        file_path: []const u8,
        line_number: usize,
        original_code: []const u8,
        patched_code: []const u8,
        patch_type: PatchType,
        reason: []const u8,
        confidence: f64,
    ) !AutoCodePatch {
        return AutoCodePatch{
            .file_path = try allocator.dupe(u8, file_path),
            .line_number = line_number,
            .original_code = try allocator.dupe(u8, original_code),
            .patched_code = try allocator.dupe(u8, patched_code),
            .patch_type = patch_type,
            .reason = try allocator.dupe(u8, reason),
            .confidence = confidence,
            .applied = false,
            .rollback_backup = null,
        };
    }

    /// Free patch resources
    pub fn deinit(self: *AutoCodePatch, allocator: mem.Allocator) void {
        allocator.free(self.file_path);
        allocator.free(self.original_code);
        allocator.free(self.patched_code);
        allocator.free(self.reason);
        if (self.rollback_backup) |backup| {
            allocator.free(backup);
        }
    }

    /// Validate that this patch is safe to apply
    pub fn validate(self: AutoCodePatch) bool {
        // Check confidence threshold
        if (self.confidence < 0.95) return false;

        // Check that patched code is not empty
        if (self.patched_code.len == 0) return false;

        // Check that original and patched are different
        if (mem.eql(u8, self.original_code, self.patched_code)) return false;

        // Check that patched code is valid (basic syntax checks)
        if (!self.isValidZigCode()) return false;

        return true;
    }

    /// Basic validation that patched code is valid Zig
    fn isValidZigCode(self: AutoCodePatch) bool {
        const code = self.patched_code;

        // Check for balanced braces
        var brace_depth: i32 = 0;
        var paren_depth: i32 = 0;
        var bracket_depth: i32 = 0;

        for (code) |c| {
            switch (c) {
                '{' => brace_depth += 1,
                '}' => brace_depth -= 1,
                '(' => paren_depth += 1,
                ')' => paren_depth -= 1,
                '[' => bracket_depth += 1,
                ']' => bracket_depth -= 1,
                else => {},
            }

            // Negative depth means unbalanced
            if (brace_depth < 0 or paren_depth < 0 or bracket_depth < 0) {
                return false;
            }
        }

        // All should be balanced at end
        if (brace_depth != 0 or paren_depth != 0 or bracket_depth != 0) {
            return false;
        }

        return true;
    }

    /// Format patch for display
    pub fn format(self: AutoCodePatch, allocator: mem.Allocator) ![]const u8 {
        const type_str = @tagName(self.patch_type);
        const conf_fmt = try std.fmt.allocPrint(allocator, "{d:.2}", .{self.confidence * 100.0});
        defer allocator.free(conf_fmt);

        return try std.fmt.allocPrint(allocator,
            \\Patch: {s}
            \\  File:      {s}
            \\  Line:      {d}
            \\  Type:      {s}
            \\  Confidence: {s}%
            \\  Reason:    {s}
            \\  Original:  {s}
            \\  Patched:   {s}
        , .{
            if (self.applied) "[APPLIED]" else "[PENDING]",
            self.file_path,
            self.line_number,
            type_str,
            conf_fmt,
            self.reason,
            self.original_code,
            self.patched_code,
        });
    }
};

/// Pattern matchers for sacred code detection
const SacredPattern = struct {
    name: []const u8,
    pattern: []const u8,
    replacement: []const u8,
    patch_type: PatchType,
    confidence: f64,

    fn init(
        name: []const u8,
        pattern: []const u8,
        replacement: []const u8,
        patch_type: PatchType,
        confidence: f64,
    ) SacredPattern {
        return SacredPattern{
            .name = name,
            .pattern = pattern,
            .replacement = replacement,
            .patch_type = patch_type,
            .confidence = confidence,
        };
    }
};

/// Get all sacred patterns to scan for
fn getSacredPatterns(allocator: mem.Allocator) ![]SacredPattern {
    var patterns = ArrayList(SacredPattern).init(allocator);
    defer patterns.deinit();

    // Magic number replacements
    try patterns.append(SacredPattern.init(
        "Magic 1.618",
        "1.618",
        "SacredConstants.PHI",
        PatchType.CONSTANT_REPLACEMENT,
        0.98,
    ));

    try patterns.append(SacredPattern.init(
        "Magic 2.618",
        "2.618",
        "SacredConstants.PHI_SQUARED",
        PatchType.CONSTANT_REPLACEMENT,
        0.98,
    ));

    try patterns.append(SacredPattern.init(
        "Magic 0.618",
        "0.618",
        "SacredConstants.PHI_INVERSE",
        PatchType.CONSTANT_REPLACEMENT,
        0.98,
    ));

    try patterns.append(SacredPattern.init(
        "Magic 3.0 as trinity",
        "= 3.0",
        "= SacredConstants.TRINITY",
        PatchType.TRINITY_IDENTITY,
        0.96,
    ));

    try patterns.append(SacredPattern.init(
        "Magic 3 as trinity",
        "= 3",
        "= SacredConstants.TRINITY",
        PatchType.TRINITY_IDENTITY,
        0.95,
    ));

    try patterns.append(SacredPattern.init(
        "Magic 0.0382",
        "0.0382",
        "SacredConstants.MU",
        PatchType.CONSTANT_REPLACEMENT,
        0.99,
    ));

    try patterns.append(SacredPattern.init(
        "Magic 0.0618",
        "0.0618",
        "SacredConstants.CHI",
        PatchType.CONSTANT_REPLACEMENT,
        0.99,
    ));

    try patterns.append(SacredPattern.init(
        "Magic 0.333",
        "0.333",
        "SacredConstants.EPSILON",
        PatchType.CONSTANT_REPLACEMENT,
        0.97,
    ));

    return patterns.toOwnedSlice();
}

/// Analyze a file for sacred patches
pub fn analyzeFileForSacredPatches(allocator: mem.Allocator, file_path: []const u8) ![]AutoCodePatch {
    const file = try fs.cwd().openFile(file_path, .{});
    defer file.close();

    const stat = try file.stat();
    const content = try file.readAllAlloc(allocator, stat.size);
    defer allocator.free(content);

    var patches = ArrayList(AutoCodePatch).init(allocator);
    defer {
        for (patches.items) |*p| p.deinit(allocator);
        patches.deinit();
    }

    const patterns = try getSacredPatterns(allocator);
    defer allocator.free(patterns);

    var lines = mem.splitScalar(u8, content, '\n');
    var line_num: usize = 0;

    while (lines.next()) |line| {
        line_num += 1;

        // Skip comments and empty lines
        const trimmed = mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue;
        if (mem.startsWith(u8, trimmed, "//")) continue;
        if (mem.startsWith(u8, trimmed, "///")) continue;

        // Check each pattern
        for (patterns) |pattern| {
            if (mem.indexOf(u8, line, pattern.pattern)) |idx| {
                // Verify it's not already using the constant
                if (mem.indexOf(u8, line, "SacredConstants.") != null) continue;

                // Verify it's in a valid context (assignment or comparison)
                if (!isValidContext(line, idx)) continue;

                const patched = try applyPattern(allocator, line, pattern);

                const patch = try AutoCodePatch.init(
                    allocator,
                    file_path,
                    line_num,
                    line,
                    patched,
                    pattern.patch_type,
                    pattern.name,
                    pattern.confidence,
                );

                try patches.append(patch);
            }
        }

        // Check for phi-weighted calculation patterns
        if (try detectPhiWeightedPattern(allocator, file_path, line_num, line)) |patch| {
            try patches.append(patch);
        }

        // Check for trinity identity patterns
        if (try detectTrinityIdentityPattern(allocator, file_path, line_num, line)) |patch| {
            try patches.append(patch);
        }
    }

    return patches.toOwnedSlice();
}

/// Check if pattern is in valid context (not in string literal)
fn isValidContext(line: []const u8, idx: usize) bool {
    // Check if inside string literal
    var in_string = false;
    var quote_char: u8 = 0;

    for (line[0..idx]) |c| {
        if (c == '"' or c == '\'') {
            if (!in_string) {
                in_string = true;
                quote_char = c;
            } else if (c == quote_char) {
                in_string = false;
            }
        }
    }

    return !in_string;
}

/// Apply a pattern to a line
fn applyPattern(allocator: mem.Allocator, line: []const u8, pattern: SacredPattern) ![]const u8 {
    var result = ArrayList(u8).init(allocator);
    defer result.deinit();

    const idx = mem.indexOf(u8, line, pattern.pattern) orelse return error.PatternNotFound;

    try result.appendSlice(line[0..idx]);
    try result.appendSlice(pattern.replacement);
    try result.appendSlice(line[idx + pattern.pattern.len ..]);

    return result.toOwnedSlice();
}

/// Detect phi-weighted calculation patterns
fn detectPhiWeightedPattern(allocator: mem.Allocator, file_path: []const u8, line_num: usize, line: []const u8) !?AutoCodePatch {
    // Pattern: value * 0.618 or value * 1.618
    if (mem.indexOf(u8, line, "* 0.618")) |idx| {
        if (!isValidContext(line, idx)) return null;

        const patched = try replacePhiWeight(allocator, line, "0.618", "PHI_INVERSE");

        return try AutoCodePatch.init(
            allocator,
            file_path,
            line_num,
            line,
            patched,
            PatchType.PHI_WEIGHTED_FIX,
            "Replace magic phi weight with sacred constant",
            0.96,
        );
    }

    if (mem.indexOf(u8, line, "* 1.618")) |idx| {
        if (!isValidContext(line, idx)) return null;

        const patched = try replacePhiWeight(allocator, line, "1.618", "PHI");

        return try AutoCodePatch.init(
            allocator,
            file_path,
            line_num,
            line,
            patched,
            PatchType.PHI_WEIGHTED_FIX,
            "Replace magic phi weight with sacred constant",
            0.96,
        );
    }

    return null;
}

/// Replace phi weight in line
fn replacePhiWeight(allocator: mem.Allocator, line: []const u8, magic: []const u8, constant: []const u8) ![]const u8 {
    const pattern = try std.fmt.allocPrint(allocator, "* {s}", .{magic});
    defer allocator.free(pattern);

    const replacement = try std.fmt.allocPrint(allocator, "* SacredConstants.{s}", .{constant});
    defer allocator.free(replacement);

    const idx = mem.indexOf(u8, line, pattern) orelse return error.PatternNotFound;

    var result = ArrayList(u8).init(allocator);
    defer result.deinit();
    try result.appendSlice(line[0..idx]);
    try result.appendSlice(replacement);
    try result.appendSlice(line[idx + pattern.len ..]);

    return result.toOwnedSlice();
}

/// Detect trinity identity patterns
fn detectTrinityIdentityPattern(allocator: mem.Allocator, file_path: []const u8, line_num: usize, line: []const u8) !?AutoCodePatch {
    // Pattern: 2.618 + 0.382 or similar trinity combinations
    if (mem.indexOf(u8, line, "+ 0.382")) |idx| {
        if (!isValidContext(line, idx)) return null;

        if (mem.indexOf(u8, line, "2.618") != null) {
            // This is φ² + 1/φ² = 3 pattern
            const patched = try std.fmt.allocPrint(allocator, "SacredConstants.TRINITY // φ² + 1/φ² = 3", .{});

            return try AutoCodePatch.init(
                allocator,
                file_path,
                line_num,
                line,
                patched,
                PatchType.TRINITY_IDENTITY,
                "Simplify trinity identity: φ² + 1/φ² = 3",
                0.97,
            );
        }
    }

    return null;
}

/// Validate a patch before applying
pub fn validatePatch(patch: AutoCodePatch) bool {
    return patch.validate();
}

/// Apply a single patch to a file
pub fn applyPatch(allocator: mem.Allocator, patch: *AutoCodePatch) !void {
    if (!patch.validate()) {
        return error.InvalidPatch;
    }

    // Read original file
    const file = try fs.cwd().openFile(patch.file_path, .{});
    defer file.close();

    const stat = try file.stat();
    const content = try file.readAllAlloc(allocator, stat.size);
    defer allocator.free(content);

    // Create backup
    patch.rollback_backup = try allocator.dupe(u8, content);

    // Apply patch
    var result = ArrayList(u8).init(allocator);
    defer result.deinit();
    var lines = mem.splitScalar(u8, content, '\n');
    var current_line: usize = 0;

    while (lines.next()) |line| : (current_line += 1) {
        if (current_line == patch.line_number - 1) {
            try result.appendSlice(patch.patched_code);
        } else {
            try result.appendSlice(line);
        }

        if (lines.index != null) {
            try result.append('\n');
        }
    }

    // Write patched file
    {
        const out_file = try fs.cwd().createFile(patch.file_path, .{ .truncate = true });
        defer out_file.close();

        try out_file.writeAll(result.items);
    }

    patch.applied = true;
}

/// Rollback a patch
pub fn rollbackPatch(allocator: mem.Allocator, patch: *AutoCodePatch) !void {
    if (patch.rollback_backup == null) {
        return error.NoBackup;
    }

    // Write backup back to file
    const file = try fs.cwd().createFile(patch.file_path, .{ .truncate = true });
    defer file.close();

    try file.writeAll(patch.rollback_backup.?);

    // Clear backup and mark as not applied
    allocator.free(patch.rollback_backup.?);
    patch.rollback_backup = null;
    patch.applied = false;
}

/// Apply multiple patches with automatic rollback on test failure
pub fn applyPatchesWithRollback(allocator: mem.Allocator, patches: []AutoCodePatch) !PatchResult {
    var result = PatchResult{
        .total_patches = patches.len,
    };

    // Apply patches one by one
    for (patches, 0..) |*patch, i| {
        if (!patch.validate()) {
            result.skipped_count += 1;
            continue;
        }

        // Apply patch
        applyPatch(allocator, patch) catch |err| {
            std.log.err("Failed to apply patch to {s}:{}", .{ patch.file_path, err });
            result.failed_count += 1;
            continue;
        };

        // Run tests to validate
        if (!runTests()) {
            std.log.warn("Tests failed after patch to {s}, rolling back", .{patch.file_path});

            // Rollback this patch
            rollbackPatch(allocator, patch) catch |err| {
                std.log.err("Failed to rollback patch: {}", .{err});
            };

            result.rolled_back_count += 1;
            continue;
        }

        result.applied_count += 1;
        std.log.info("Patch {d}/{d} applied successfully to {s}", .{ i + 1, patches.len, patch.file_path });
    }

    // Calculate success rate
    if (result.total_patches > 0) {
        result.success_rate = @as(f64, @floatFromInt(result.applied_count)) / @as(f64, @floatFromInt(result.total_patches));
    }

    return result;
}

/// Run tests to validate patches
fn runTests() bool {
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{ "zig", "build", "test" },
    }) catch return false;

    defer {
        std.heap.page_allocator.free(result.stdout);
        std.heap.page_allocator.free(result.stderr);
    }

    return (switch (result.term) {
        .Exited => |code| code,
        else => @as(u32, 1),
    }) == 0;
}

/// Scan a directory and apply patches
pub fn scanAndPatchDirectory(allocator: mem.Allocator, dir_path: []const u8) !PatchStats {
    var stats = PatchStats{};

    var dir = try fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var all_patches = ArrayList(AutoCodePatch).init(allocator);
    defer {
        for (all_patches.items) |*p| p.deinit(allocator);
        all_patches.deinit();
    }

    while (try walker.next()) |entry| {
        // Only process .zig files
        if (!mem.eql(u8, std.fs.path.extension(entry.path), ".zig")) continue;

        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.path });
        defer allocator.free(full_path);

        std.log.info("Scanning: {s}", .{full_path});

        // Analyze file
        const patches = try analyzeFileForSacredPatches(allocator, full_path);
        defer {
            for (patches) |*p| p.deinit(allocator);
            allocator.free(patches);
        }

        stats.files_scanned += 1;
        stats.patches_found += patches.len;

        // Count lines analyzed
        const file = try fs.cwd().openFile(full_path, .{});
        const file_stat = try file.stat();
        const file_content = try file.readAllAlloc(allocator, file_stat.size);
        file.close();
        defer allocator.free(file_content);

        stats.total_lines_analyzed += mem.count(u8, file_content, "\n") + 1;

        // Add patches to list
        for (patches) |patch| {
            const patch_copy = try AutoCodePatch.init(
                allocator,
                patch.file_path,
                patch.line_number,
                patch.original_code,
                patch.patched_code,
                patch.patch_type,
                patch.reason,
                patch.confidence,
            );
            try all_patches.append(patch_copy);
        }
    }

    // Apply all patches with rollback
    std.log.info("Applying {d} patches...", .{all_patches.items.len});

    const patch_result = try applyPatchesWithRollback(allocator, all_patches.items);
    stats.patches_applied = patch_result.applied_count;
    stats.patches_rolled_back = patch_result.rolled_back_count;

    return stats;
}

/// Generate a summary report
pub fn generateSummaryReport(allocator: mem.Allocator, stats: PatchStats, patches: []const AutoCodePatch) ![]const u8 {
    var result = ArrayList(u8).init(allocator);
    defer result.deinit();

    try result.appendSlice("╔══════════════════════════════════════════════════════════════╗\n");
    try result.appendSlice("║     SACRED AUTO-CODE PATCHING ENGINE - SUMMARY REPORT       ║\n");
    try result.appendSlice("╚══════════════════════════════════════════════════════════════╝\n\n");

    const stats_fmt = try stats.format(allocator);
    defer allocator.free(stats_fmt);

    try result.appendSlice(stats_fmt);
    try result.appendSlice("\n\n");

    // Group by patch type
    try result.appendSlice("Patches by Type:\n");

    var type_counts = std.StringHashMap(usize).init(allocator);
    defer type_counts.deinit();

    for (patches) |patch| {
        const type_str = @tagName(patch.patch_type);
        const entry = try type_counts.getOrPut(type_str);
        if (!entry.found_existing) {
            entry.value_ptr.* = 0;
        }
        entry.value_ptr.* += 1;
    }

    var type_iter = type_counts.iterator();
    while (type_iter.next()) |entry| {
        try result.appendSlice("  ");
        try result.appendSlice(entry.key_ptr.*);
        try result.appendSlice(": ");
        const count_str = try std.fmt.allocPrint(allocator, "{d}\n", .{entry.value_ptr.*});
        defer allocator.free(count_str);
        try result.appendSlice(count_str);
    }

    try result.appendSlice("\nHigh-Confidence Patches (>98%):\n");

    for (patches) |patch| {
        if (patch.confidence >= 0.98) {
            try result.appendSlice("  ");
            try result.appendSlice(patch.file_path);
            try result.appendSlice(":");
            const line_str = try std.fmt.allocPrint(allocator, "{d}", .{patch.line_number});
            defer allocator.free(line_str);
            try result.appendSlice(line_str);
            try result.appendSlice(" - ");
            try result.appendSlice(@tagName(patch.patch_type));
            try result.appendSlice("\n");
        }
    }

    try result.appendSlice("\n══════════════════════════════════════════════════════════\n");
    try result.appendSlice("Sacred Mathematics Patching Complete\n");
    try result.appendSlice("══════════════════════════════════════════════════════════\n");

    return result.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "AutoCodePatch initialization" {
    var patch = try AutoCodePatch.init(
        std.testing.allocator,
        "/test/file.zig",
        42,
        "const x = 1.618;",
        "const x = SacredConstants.PHI;",
        PatchType.CONSTANT_REPLACEMENT,
        "Replace magic number",
        0.98,
    );
    defer patch.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 42), patch.line_number);
    try std.testing.expectEqual(false, patch.applied);
    try std.testing.expect(patch.rollback_backup == null);
    try std.testing.expectEqual(@as(f64, 0.98), patch.confidence);
}

test "AutoCodePatch validation - valid patch" {
    var patch = try AutoCodePatch.init(
        std.testing.allocator,
        "/test/file.zig",
        1,
        "const x: f64 = 1.618;",
        "const x: f64 = SacredConstants.PHI;",
        PatchType.CONSTANT_REPLACEMENT,
        "Replace magic phi",
        0.98,
    );
    defer patch.deinit(std.testing.allocator);

    try std.testing.expectEqual(true, patch.validate());
}

test "AutoCodePatch validation - low confidence" {
    var patch = try AutoCodePatch.init(
        std.testing.allocator,
        "/test/file.zig",
        1,
        "const x: f64 = 1.618;",
        "const x: f64 = SacredConstants.PHI;",
        PatchType.CONSTANT_REPLACEMENT,
        "Replace magic phi",
        0.90, // Below threshold
    );
    defer patch.deinit(std.testing.allocator);

    try std.testing.expectEqual(false, patch.validate());
}

test "AutoCodePatch validation - same code" {
    var patch = try AutoCodePatch.init(
        std.testing.allocator,
        "/test/file.zig",
        1,
        "const x: f64 = 1.618;",
        "const x: f64 = 1.618;", // Same as original
        PatchType.CONSTANT_REPLACEMENT,
        "No change",
        0.98,
    );
    defer patch.deinit(std.testing.allocator);

    try std.testing.expectEqual(false, patch.validate());
}

test "AutoCodePatch validation - invalid Zig syntax" {
    var patch = try AutoCodePatch.init(
        std.testing.allocator,
        "/test/file.zig",
        1,
        "const x = 1.618;",
        "const x = (unclosed brace", // Unbalanced braces
        PatchType.CONSTANT_REPLACEMENT,
        "Broken syntax",
        0.98,
    );
    defer patch.deinit(std.testing.allocator);

    try std.testing.expectEqual(false, patch.validate());
}

test "PatchResult format" {
    const result = PatchResult{
        .total_patches = 10,
        .applied_count = 8,
        .skipped_count = 1,
        .failed_count = 1,
        .rolled_back_count = 0,
        .success_rate = 0.8,
    };

    const formatted = try result.format(std.testing.allocator);
    defer std.testing.allocator.free(formatted);

    try std.testing.expect(mem.indexOf(u8, formatted, "Total:      10") != null);
    try std.testing.expect(mem.indexOf(u8, formatted, "Applied:    8") != null);
    try std.testing.expect(mem.indexOf(u8, formatted, "Success:") != null);
}

test "PatchStats format" {
    const stats = PatchStats{
        .files_scanned = 5,
        .patches_found = 15,
        .patches_applied = 12,
        .patches_rolled_back = 2,
        .total_lines_analyzed = 1000,
    };

    const formatted = try stats.format(std.testing.allocator);
    defer std.testing.allocator.free(formatted);

    try std.testing.expect(mem.indexOf(u8, formatted, "Files scanned:     5") != null);
    try std.testing.expect(mem.indexOf(u8, formatted, "Patches found:     15") != null);
    try std.testing.expect(mem.indexOf(u8, formatted, "Lines analyzed:    1000") != null);
}

test "detect phi-weighted pattern - phi inverse" {
    const line = "const weighted = value * 0.618;";
    var patch = try detectPhiWeightedPattern(
        std.testing.allocator,
        "/test.zig",
        10,
        line,
    );

    defer {
        if (patch) |*p| p.deinit(std.testing.allocator);
    }

    try std.testing.expect(patch != null);
    if (patch) |*p| {
        try std.testing.expectEqual(PatchType.PHI_WEIGHTED_FIX, p.patch_type);
        try std.testing.expect(mem.indexOf(u8, p.patched_code, "SacredConstants.PHI_INVERSE") != null);
    }
}

test "detect phi-weighted pattern - phi" {
    const line = "const weighted = value * 1.618;";
    var patch = try detectPhiWeightedPattern(
        std.testing.allocator,
        "/test.zig",
        10,
        line,
    );

    defer {
        if (patch) |*p| p.deinit(std.testing.allocator);
    }

    try std.testing.expect(patch != null);
    if (patch) |*p| {
        try std.testing.expectEqual(PatchType.PHI_WEIGHTED_FIX, p.patch_type);
        try std.testing.expect(mem.indexOf(u8, p.patched_code, "SacredConstants.PHI") != null);
    }
}

test "pattern matching in string literal should be ignored" {
    const line = "const message = \"The value 1.618 is sacred\";";
    const idx = mem.indexOf(u8, line, "1.618").?;

    // Should detect it's in a string literal
    try std.testing.expectEqual(false, isValidContext(line, idx));
}

test "pattern matching in code should be valid" {
    const line = "const phi: f64 = 1.618;";
    const idx = mem.indexOf(u8, line, "1.618").?;

    // Should detect it's in code context
    try std.testing.expectEqual(true, isValidContext(line, idx));
}

test "replacePhiWeight - phi inverse" {
    const line = "const weighted = value * 0.618;";
    const patched = try replacePhiWeight(std.testing.allocator, line, "0.618", "PHI_INVERSE");
    defer std.testing.allocator.free(patched);

    try std.testing.expect(mem.indexOf(u8, patched, "* SacredConstants.PHI_INVERSE") != null);
    try std.testing.expect(mem.indexOf(u8, patched, "* 0.618") == null);
}

test "replacePhiWeight - phi" {
    const line = "const weighted = value * 1.618;";
    const patched = try replacePhiWeight(std.testing.allocator, line, "1.618", "PHI");
    defer std.testing.allocator.free(patched);

    try std.testing.expect(mem.indexOf(u8, patched, "* SacredConstants.PHI") != null);
    try std.testing.expect(mem.indexOf(u8, patched, "* 1.618") == null);
}

test "getSacredPatterns returns expected patterns" {
    const patterns = try getSacredPatterns(std.testing.allocator);
    defer std.testing.allocator.free(patterns);

    try std.testing.expect(patterns.len > 0);

    // Check for key patterns
    var found_phi = false;
    var found_trinity = false;
    var found_mu = false;

    for (patterns) |p| {
        if (mem.eql(u8, p.pattern, "1.618")) found_phi = true;
        if (mem.eql(u8, p.pattern, "= 3.0")) found_trinity = true;
        if (mem.eql(u8, p.pattern, "0.0382")) found_mu = true;
    }

    try std.testing.expect(found_phi);
    try std.testing.expect(found_trinity);
    try std.testing.expect(found_mu);
}

test "AutoCodePatch format" {
    var patch = try AutoCodePatch.init(
        std.testing.allocator,
        "/test/sacred.zig",
        42,
        "const x = 1.618;",
        "const x = SacredConstants.PHI;",
        PatchType.CONSTANT_REPLACEMENT,
        "Replace magic phi",
        0.98,
    );
    defer patch.deinit(std.testing.allocator);

    const formatted = try patch.format(std.testing.allocator);
    defer std.testing.allocator.free(formatted);

    try std.testing.expect(mem.indexOf(u8, formatted, "/test/sacred.zig") != null);
    try std.testing.expect(mem.indexOf(u8, formatted, "Line:      42") != null);
    try std.testing.expect(mem.indexOf(u8, formatted, "CONSTANT_REPLACEMENT") != null);
    try std.testing.expect(mem.indexOf(u8, formatted, "98.00%") != null);
}

test "generateSummaryReport" {
    const stats = PatchStats{
        .files_scanned = 2,
        .patches_found = 5,
        .patches_applied = 4,
        .patches_rolled_back = 1,
        .total_lines_analyzed = 500,
    };

    var patch1 = try AutoCodePatch.init(
        std.testing.allocator,
        "/test1.zig",
        10,
        "const x = 1.618;",
        "const x = SacredConstants.PHI;",
        PatchType.CONSTANT_REPLACEMENT,
        "Replace phi",
        0.98,
    );
    defer patch1.deinit(std.testing.allocator);

    const patches = &[_]AutoCodePatch{patch1};

    const report = try generateSummaryReport(std.testing.allocator, stats, patches);
    defer std.testing.allocator.free(report);

    try std.testing.expect(mem.indexOf(u8, report, "SACRED AUTO-CODE PATCHING") != null);
    try std.testing.expect(mem.indexOf(u8, report, "Files scanned:     2") != null);
    try std.testing.expect(mem.indexOf(u8, report, "Patches by Type:") != null);
    try std.testing.expect(mem.indexOf(u8, report, "High-Confidence Patches") != null);
}
