//! Pattern matching for AGENT MU
//!
//! Searches REGRESSION_PATTERNS.md for similar past errors and their solutions.

const std = @import("std");
const ArrayListManaged = std.array_list.AlignedManaged;
const diagnostic = @import("diagnostic.zig");

/// Match result from REGRESSION_PATTERNS.md
pub const PatternMatch = struct {
    found: bool,
    anti_pattern: []const u8,
    correct_approach: []const u8,
    files: [][]const u8,
    attempted_fixes: [][]const u8,

    /// Free allocated memory
    pub fn deinit(self: *const PatternMatch, allocator: std.mem.Allocator) void {
        allocator.free(self.anti_pattern);
        allocator.free(self.correct_approach);
        for (self.files) |f| allocator.free(f);
        allocator.free(self.files);
        for (self.attempted_fixes) |f| allocator.free(f);
        allocator.free(self.attempted_fixes);
    }
};

/// Search REGRESSION_PATTERNS.md for matching error patterns
///
/// Parameters:
///   - allocator: Memory allocator
///   - error_type: The FixType of the current error
///   - error_message: The error message to match against
///
/// Returns: PatternMatch with found solution or empty if no match
pub fn searchRegressionPatterns(
    allocator: std.mem.Allocator,
    error_type: diagnostic.FixType,
    error_message: []const u8,
) !PatternMatch {
    const patterns_file = ".ralph/memory/REGRESSION_PATTERNS.md";

    // Try to open the file
    const file = std.fs.cwd().openFile(patterns_file, .{}) catch |err| {
        if (err == error.FileNotFound) {
            // File doesn't exist yet - return empty match
            return PatternMatch{
                .found = false,
                .anti_pattern = "",
                .correct_approach = "",
                .files = &[_][]const u8{},
                .attempted_fixes = &[_][]const u8{},
            };
        }
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024); // Max 1MB
    defer allocator.free(content);

    // Search for pattern entries
    var entries = std.mem.splitSequence(u8, content, "---");

    while (entries.next()) |entry| {
        if (entry.len < 10) continue; // Skip empty entries

        // Check if this entry matches our error
        if (entryMatchesError(entry, error_type, error_message)) {
            // Extract the solution from this entry
            return try extractSolution(allocator, entry);
        }
    }

    // No match found
    return PatternMatch{
        .found = false,
        .anti_pattern = "",
        .correct_approach = "",
        .files = &[_][]const u8{},
        .attempted_fixes = &[_][]const u8{},
    };
}

/// Check if a pattern entry matches the current error
fn entryMatchesError(
    entry: []const u8,
    error_type: diagnostic.FixType,
    error_message: []const u8,
) bool {
    // Convert entry to lowercase for case-insensitive matching
    const entry_lower = toLowerAlloc(std.heap.page_allocator, entry) catch return false;
    defer std.heap.page_allocator.free(entry_lower);

    const msg_lower = toLowerAlloc(std.heap.page_allocator, error_message) catch return false;
    defer std.heap.page_allocator.free(msg_lower);

    // Check for error type keywords
    const type_keyword = switch (error_type) {
        .IMPORT_FIX => "import",
        .TYPE_FIX => "type",
        .SYNTAX_FIX => "syntax",
        .TEMPLATE_FIX => "template",
        .SPEC_FIX => "spec",
        .GENERATOR_PATCH => "generator",
        .UNKNOWN => "error",
        // Zig-specific (v8.10)
        .ALLOCATOR_FIX => "allocator",
        .ERROR_UNION_FIX => "error",
        .COMPTIME_FIX => "comptime",
        .VSA_FIX => "vsa",
        .MEM_FIX => "memory",
        // Zig 0.15 specific (v8.11)
        .IOPATTERN_FIX => "io",
        .COMPTIME_QUOTA_FIX => "quota",
        .UNMANAGED_FIX => "unmanaged",
        .TYPEFUNCTION_FIX => "typefunction",
        .INLINE_FIX => "inline",
    };

    // Check if entry contains relevant keywords
    if (std.mem.indexOf(u8, entry_lower, type_keyword) == null) {
        return false;
    }

    // Check for common error message patterns
    if (std.mem.indexOf(u8, msg_lower, "expected type") != null) {
        return std.mem.indexOf(u8, entry_lower, "expected type") != null or
            std.mem.indexOf(u8, entry_lower, "type mismatch") != null;
    }

    if (std.mem.indexOf(u8, msg_lower, "undeclared") != null) {
        return std.mem.indexOf(u8, entry_lower, "undeclared") != null or
            std.mem.indexOf(u8, entry_lower, "identifier") != null;
    }

    if (std.mem.indexOf(u8, msg_lower, "semicolon") != null) {
        return std.mem.indexOf(u8, entry_lower, "semicolon") != null or
            std.mem.indexOf(u8, entry_lower, "syntax") != null;
    }

    // Generic keyword matching
    var iter = std.mem.splitScalar(u8, msg_lower, ' ');
    while (iter.next()) |word| {
        if (word.len > 4) { // Only match significant words
            if (std.mem.indexOf(u8, entry_lower, word) != null) {
                return true;
            }
        }
    }

    return false;
}

/// Extract solution information from a pattern entry
fn extractSolution(allocator: std.mem.Allocator, entry: []const u8) !PatternMatch {
    var lines = std.mem.splitScalar(u8, entry, '\n');

    var anti_pattern: []const u8 = "";
    var correct_approach: []const u8 = "";
    var files_list = ArrayListManaged([]const u8, null).init(allocator);
    var fixes_list = ArrayListManaged([]const u8, null).init(allocator);

    errdefer {
        if (files_list.items.len > 0) {
            for (files_list.items) |f| allocator.free(f);
        }
        if (fixes_list.items.len > 0) {
            for (fixes_list.items) |f| allocator.free(f);
        }
    }

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

        if (std.mem.startsWith(u8, trimmed, "- **Anti-pattern:**")) {
            const start = trimmed["- **Anti-pattern:**".len..];
            anti_pattern = std.mem.trim(u8, start, &std.ascii.whitespace);
        } else if (std.mem.startsWith(u8, trimmed, "- **Correct approach:**")) {
            const start = trimmed["- **Correct approach:**".len..];
            correct_approach = std.mem.trim(u8, start, &std.ascii.whitespace);
        } else if (std.mem.startsWith(u8, trimmed, "- **Files:**")) {
            // Parse file list (format: `file1.zig`, `file2.zig`)
            // TODO: Implement proper parsing
            _ = trimmed["- **Files:**".len..];
        } else if (std.mem.indexOf(u8, trimmed, "**") != null) {
            // Store other lines as attempted fixes
            try fixes_list.append(try allocator.dupe(u8, trimmed));
        }
    }

    return PatternMatch{
        .found = true,
        .anti_pattern = try allocator.dupe(u8, anti_pattern),
        .correct_approach = try allocator.dupe(u8, correct_approach),
        .files = try files_list.toOwnedSlice(),
        .attempted_fixes = try fixes_list.toOwnedSlice(),
    };
}

/// Convert string to lowercase (allocator-allocated)
fn toLowerAlloc(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, s.len);
    for (s, 0..) |c, i| {
        result[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    return result;
}
