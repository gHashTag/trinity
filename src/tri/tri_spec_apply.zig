// ═══════════════════════════════════════════════════════════════════════════════
// TRI SPEC APPLY — TRI-27 Idiom 11 Auto-Annotation
// ═══════════════════════════════════════════════════════════════════════════════════════
//
// Generates and applies @spec/@require/@ensure/@example annotations
// to .tri files based on type signatures and existing test_cases.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const colors = @import("tri_colors.zig");
const YELLOW = colors.YELLOW;
const GREEN = colors.GREEN;
const RED = colors.RED;
const RESET = colors.RESET;
const GOLDEN = colors.GOLDEN;

// ═══════════════════════════════════════════════════════════════════════════════════════
// Recommendation Data Structures
// ═══════════════════════════════════════════════════════════════════════════════════════

pub const AnnotationRecommendation = struct {
    behavior_name: []const u8,
    spec: ?[]const u8 = null,
    requires: std.ArrayListUnmanaged([]const u8),
    ensures: std.ArrayListUnmanaged([]const u8),
    examples: std.ArrayList(ExampleRecommendation),

    pub fn init(allocator: Allocator) AnnotationRecommendation {
        return .{
            .behavior_name = "",
            .spec = null,
            .requires = .init(allocator),
            .ensures = .init(allocator),
            .examples = .init(allocator),
        };
    }

    pub fn deinit(self: *AnnotationRecommendation) void {
        self.requires.deinit();
        self.ensures.deinit();
        self.examples.deinit();
    }
};

pub const ExampleRecommendation = struct {
    input: []const u8,
    expect: []const u8,
    tolerance: ?f64 = null,
};

pub const ApplyResult = struct {
    files_scanned: usize,
    files_modified: usize,
    annotations_added: usize,
    errors: std.ArrayList(ErrorEntry),

    pub fn init(allocator: Allocator) ApplyResult {
        return .{
            .files_scanned = 0,
            .files_modified = 0,
            .annotations_added = 0,
            .errors = std.ArrayList(ErrorEntry).init(allocator),
        };
    }

    pub fn deinit(self: *ApplyResult) void {
        self.errors.deinit();
    }
};

pub const ErrorEntry = struct {
    file_path: []const u8,
    message: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════════════
// Type Inference for Contract Generation
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Infer preconditions from parameter type
fn inferRequires(allocator: Allocator, param_name: []const u8, param_type: []const u8) ![]const u8 {
    // Unsigned integers: non-negative
    if (std.mem.startsWith(u8, param_type, "u") or
        std.mem.eql(u8, param_type, "usize") or
        std.mem.eql(u8, param_type, "uint"))
    {
        return try std.fmt.allocPrint(allocator, "{s} >= 0", .{param_name});
    }

    // Signed integers: no specific constraint by default
    if (std.mem.startsWith(u8, param_type, "i") or
        std.mem.eql(u8, param_type, "isize"))
    {
        return try std.fmt.allocPrint(allocator, "true", .{});
    }

    // Floats: no specific constraint by default
    if (std.mem.startsWith(u8, param_type, "f")) {
        return try std.fmt.allocPrint(allocator, "true", .{});
    }

    // Boolean
    if (std.mem.eql(u8, param_type, "bool")) {
        return try std.fmt.allocPrint(allocator, "true", .{});
    }

    // Slices: can check non-empty if desired
    if (std.mem.endsWith(u8, param_type, "[]") or
        std.mem.endsWith(u8, param_type, "[]const u8"))
    {
        return try std.fmt.allocPrint(allocator, "true", .{});
    }

    // Allocator: always valid
    if (std.mem.indexOf(u8, param_type, "Allocator") != null) {
        return try std.fmt.allocPrint(allocator, "true", .{});
    }

    // Default: no constraint
    return try std.fmt.allocPrint(allocator, "true", .{});
}

/// Infer postconditions from return type
fn inferEnsures(allocator: Allocator, return_type: []const u8) ![]const u8 {
    // Unsigned return: always non-negative
    if (std.mem.startsWith(u8, return_type, "u") or
        std.mem.eql(u8, return_type, "usize") or
        std.mem.eql(u8, return_type, "uint"))
    {
        return try std.fmt.allocPrint(allocator, "result >= 0", .{});
    }

    // Float return: positive if typical computation
    if (std.mem.eql(u8, return_type, "f64") or
        std.mem.eql(u8, return_type, "f32"))
    {
        return try std.fmt.allocPrint(allocator, "true", .{});
    }

    // Bool: no specific postcondition
    if (std.mem.eql(u8, return_type, "bool")) {
        return try std.fmt.allocPrint(allocator, "true", .{});
    }

    // Error union: check if Ok
    if (std.mem.indexOf(u8, return_type, "!") != null) {
        return try std.fmt.allocPrint(allocator, "true", .{});
    }

    // Optional: check if some
    if (return_type.len > 0 and return_type[0] == '?') {
        return try std.fmt.allocPrint(allocator, "true", .{});
    }

    // Slice: return valid slice
    if (std.mem.endsWith(u8, return_type, "[]")) {
        return try std.fmt.allocPrint(allocator, "true", .{});
    }

    // Void: no return value
    if (std.mem.eql(u8, return_type, "void")) {
        return try std.fmt.allocPrint(allocator, "true", .{});
    }

    // Default: no constraint
    return try std.fmt.allocPrint(allocator, "true", .{});
}

/// Generate @spec name from behavior name (camelCase to snake_case)
fn inferSpecName(allocator: Allocator, behavior_name: []const u8) ![]const u8 {
    var result = std.ArrayList(u8, null).init(allocator);

    for (behavior_name) |c| {
        if (c >= 'A' and c <= 'Z') {
            if (result.items.len > 0) {
                try result.append('_');
            }
            try result_append(std.ascii.toLower(c));
        } else {
            try result.append(c);
        }
    }

    return result.toOwnedSlice();
}

// Helper function (append with lowercase conversion)
fn result_append(list: *std.ArrayList(u8), c: u8) !void {
    try list.append(if (c >= 'A' and c <= 'Z') std.ascii.toLower(c) else c);
}

// ═══════════════════════════════════════════════════════════════════════════════════════
// YAML Generation
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Generate YAML annotation block for a behavior
pub fn generateAnnotationYAML(
    allocator: Allocator,
    rec: *const AnnotationRecommendation,
    indent: []const u8,
) ![]const u8 {
    var result = std.ArrayList(u8, null).init(allocator);

    // @spec
    if (rec.spec) |spec| {
        try result.writer().print("{s}spec: {s}\n", .{ indent, spec });
    }

    // @require
    for (rec.requires.items) |req| {
        try result.writer().print("{s}require: \"{s}\"\n", .{ indent, req });
    }

    // @ensure
    for (rec.ensures.items) |ens| {
        try result.writer().print("{s}ensure: \"{s}\"\n", .{ indent, ens });
    }

    // @example
    for (rec.examples.items) |ex| {
        try result.writer().print("{s}example:\n", .{indent});
        try result.writer().print("{s}  input: \"{s}\"\n", .{ indent, ex.input });
        try result.writer().print("{s}  expect: \"{s}\"", .{ indent, ex.expect });
        if (ex.tolerance) |tol| {
            try result.writer().print("\n{s}  tolerance: {d:.4}", .{ indent, tol });
        }
        try result.append('\n');
    }

    return result.toOwnedSlice();
}

/// Apply annotations to a .tri file
pub fn applyAnnotations(
    allocator: Allocator,
    file_path: []const u8,
    recommendations: []const AnnotationRecommendation,
    dry_run: bool,
) !bool {
    _ = allocator;
    _ = file_path;
    _ = recommendations;
    _ = dry_run;

    // For now, just report that the file would be modified
    // Full implementation requires AST-based insertion
    return false; // No modifications yet
}

// ═══════════════════════════════════════════════════════════════════════════════════════
// Main Apply Command
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Run `tri spec apply` on directory or files
pub fn runSpecApply(allocator: Allocator, args: []const []const u8) !void {
    var dry_run = false;
    var verbose = false;
    var targets = std.ArrayListUnmanaged([]const u8){};

    // Parse args
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--dry-run") or std.mem.eql(u8, arg, "-n")) {
            dry_run = true;
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printApplyHelp();
            return;
        } else {
            try targets.append(allocator, arg);
        }
    }

    // Default to specs/ if no targets specified
    if (targets.items.len == 0) {
        try targets.append(allocator, "specs");
    }

    std.debug.print("{s}tri spec apply{s} — Auto-annotate .tri files\n\n", .{ YELLOW, RESET });

    if (dry_run) {
        std.debug.print("{s}Mode:{s} DRY RUN (no modifications)\n\n", .{ YELLOW, RESET });
    }

    for (targets.items) |target| {
        try applyToTarget(allocator, target, dry_run, verbose);
    }
}

fn applyToTarget(allocator: Allocator, target: []const u8, dry_run: bool, verbose: bool) !void {
    _ = dry_run;
    std.debug.print("{s}Scanning: {s}{s}\n", .{ GREEN, target, RESET });

    // Check if target is a file or directory
    const file = std.fs.cwd().openFile(target, .{}) catch |err| {
        std.debug.print("{s}Error:{s} Cannot open {s}: {any}\n", .{ RED, RESET, target, err });
        return;
    };
    defer file.close();

    const stat = try file.stat();
    if (stat.kind == .directory) {
        // Scan directory for .tri files
        var dir = try std.fs.cwd().openDir(target, .{});
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            const ext = std.fs.path.extension(entry.name);
            if (!std.mem.eql(u8, ext, ".tri")) continue;

            const path = try std.fs.path.join(allocator, &[_][]const u8{ target, "/", entry.name });
            defer allocator.free(path);

            if (verbose) {
                std.debug.print("  → {s}\n", .{entry.name});
            }
        }
    } else if (stat.kind == .file) {
        // Process single file
        if (verbose) {
            std.debug.print("  → Processing single file\n", .{});
        }
    }

    std.debug.print("\n{s}⚠️  Coming soon:{s} Full annotation generation\n", .{ YELLOW, RESET });
    std.debug.print("  • Type-based @require/@ensure inference\n", .{});
    std.debug.print("  • @spec name derivation from behavior names\n", .{});
    std.debug.print("  • @example migration from legacy test_cases\n", .{});
    std.debug.print("\n  Use {s}tri spec audit{s} to see what's missing.\n", .{ YELLOW, RESET });
}

fn printApplyHelp() void {
    std.debug.print("\n{s}TRI SPEC APPLY — Auto-annotate .tri files{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n{s}Usage:{s} tri spec apply [options] [paths...]\n\n", .{ YELLOW, RESET });
    std.debug.print("{s}Options:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  {s}-n, --dry-run{d}Show changes without applying\n", .{ RESET, 15 });
    std.debug.print("  {s}-v, --verbose{d}Show detailed output\n", .{ RESET, 15 });
    std.debug.print("  {s}-h, --help{d}Show this help\n", .{ RESET, 15 });
    std.debug.print("\n{s}Examples:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  tri spec apply              # Annotate specs/\n", .{});
    std.debug.print("  tri spec apply specs/fpga   # Annotate specific dir\n", .{});
    std.debug.print("  tri spec apply -n specs/    # Dry run\n", .{});
    std.debug.print("\n{s}Generated Annotations:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  {s}@spec{s}       — Derived from behavior name (snake_case)\n", .{ GREEN, RESET });
    std.debug.print("  {s}@require{s}    — Inferred from parameter types (e.g., u32 → n >= 0)\n", .{ GREEN, RESET });
    std.debug.print("  {s}@ensure{s}     — Inferred from return type (e.g., f64 → result > 0)\n", .{ GREEN, RESET });
    std.debug.print("  {s}@example{s}    — Migrated from existing test_cases\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});
}

// Tests
test "infer spec name from camelCase" {
    const allocator = std.testing.allocator;
    const result = try inferSpecName(allocator, "computeSpiral");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("compute_spiral", result);
}

test "infer requires for unsigned int" {
    const allocator = std.testing.allocator;
    const result = try inferRequires(allocator, "n", "u32");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("n >= 0", result);
}

test "infer ensures for unsigned return" {
    const allocator = std.testing.allocator;
    const result = try inferEnsures(allocator, "u32");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("result >= 0", result);
}
