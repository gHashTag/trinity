// ═══════════════════════════════════════════════════════════════════════════════
// Cyrillic Guard — Blocks commits containing Cyrillic characters
// ═══════════════════════════════════════════════════════════════════════════════
//
// Detects Cyrillic characters (U+0400–U+04FF) in staged files.
// Use as git pre-commit hook or standalone check.
//
// Usage:
//   zig build cyrillic-guard
//   ./zig-out/bin/cyrillic-guard              # Check staged files
//   ./zig-out/bin/cyrillic-guard <path>       # Check specific file/dir
//   ./zig-out/bin/cyrillic-guard --all        # Check entire repo
//
// Exit codes:
//   0 — No Cyrillic found (safe to commit)
//   1 — Cyrillic detected (commit blocked)
//   2 — Usage error
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const CyrillicRange = struct { u21, u21 };

// Cyrillic Unicode blocks
const CYRILLIC_BLOCKS = [_]CyrillicRange{
    .{ 0x0400, 0x04FF }, // Cyrillic
    .{ 0x0500, 0x052F }, // Cyrillic Supplement
    .{ 0x2DE0, 0x2DFF }, // Cyrillic Extended-A
    .{ 0xA640, 0xA69F }, // Cyrillic Extended-B
    .{ 0x1C80, 0x1C8F }, // Cyrillic Extended-C
};

fn isCyrillic(cp: u21) bool {
    for (CYRILLIC_BLOCKS) |block| {
        if (cp >= block[0] and cp <= block[1]) return true;
    }
    return false;
}

fn checkFile(allocator: std.mem.Allocator, path: []const u8) !struct {
    has_cyrillic: bool,
    line_count: usize,
    first_line: usize,
} {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("Error opening {s}: {}\n", .{ path, err });
        return error.FileReadError;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 10 * 1024 * 1024) catch |err| {
        std.debug.print("Error reading {s}: {}\n", .{ path, err });
        return error.FileReadError;
    };
    defer allocator.free(content);

    var iter = std.mem.splitScalar(u8, content, '\n');
    var line_num: usize = 0;
    var first_line: usize = 0;

    while (iter.next()) |line| {
        line_num += 1;
        var utf8_iter: std.unicode.Utf8Iterator = .{ .bytes = line, .i = 0 };

        while (utf8_iter.nextCodepoint()) |cp| {
            if (isCyrillic(cp)) {
                if (first_line == 0) first_line = line_num;
                return .{
                    .has_cyrillic = true,
                    .line_count = 1,
                    .first_line = line_num,
                };
            }
        }
    }

    return .{
        .has_cyrillic = false,
        .line_count = line_num,
        .first_line = 0,
    };
}

fn checkPath(allocator: std.mem.Allocator, path: []const u8) !struct {
    files_with_cyrillic: usize,
    total_files: usize,
} {
    var files_with_cyrillic: usize = 0;
    var total_files: usize = 0;

    // Check if path is a file or directory
    const is_dir = std.fs.cwd().statFile(path) catch |err| {
        if (err == error.IsDir) {
            // It's a directory - walk it
            return walkDirectory(allocator, path);
        }
        std.debug.print("Error accessing {s}: {}\n", .{ path, err });
        return .{ .files_with_cyrillic = 0, .total_files = 0 };
    };

    // Single file
    total_files = 1;
    const result = checkFile(allocator, path) catch {
        return .{ .files_with_cyrillic = 0, .total_files = 0 };
    };

    if (result.has_cyrillic) {
        files_with_cyrillic = 1;
        std.debug.print("  ❌ {s}:{d}\n", .{ path, result.first_line });
    }

    return .{ .files_with_cyrillic = files_with_cyrillic, .total_files = total_files };
}

fn walkDirectory(allocator: std.mem.Allocator, path: []const u8) !struct {
    files_with_cyrillic: usize,
    total_files: usize,
} {
    var files_with_cyrillic: usize = 0;
    var total_files: usize = 0;

    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
        std.debug.print("Error opening {s}: {}\n", .{ path, err });
        return .{ .files_with_cyrillic = 0, .total_files = 0 };
    };
    defer dir.close();

    var walker = dir.walk(allocator) catch |err| {
        std.debug.print("Error walking {s}: {}\n", .{ path, err });
        return .{ .files_with_cyrillic = 0, .total_files = 0 };
    };
    defer walker.deinit();

    while (true) {
        const entry_opt = walker.next() catch |err| {
            std.debug.print("Error during walk: {}\n", .{err});
            break;
        };
        const entry = entry_opt orelse break;
        if (entry.kind != .file) continue;

        // Skip common non-code files
        const ext = std.fs.path.extension(entry.basename);
        if (std.mem.eql(u8, ext, ".png") or
            std.mem.eql(u8, ext, ".jpg") or
            std.mem.eql(u8, ext, ".jpeg") or
            std.mem.eql(u8, ext, ".gif") or
            std.mem.eql(u8, ext, ".ico") or
            std.mem.eql(u8, ext, ".woff") or
            std.mem.eql(u8, ext, ".woff2") or
            std.mem.eql(u8, ext, ".ttf") or
            std.mem.eql(u8, ext, ".eot") or
            std.mem.eql(u8, ext, ".zip") or
            std.mem.eql(u8, ext, ".tar") or
            std.mem.eql(u8, ext, ".gz") or
            std.mem.eql(u8, ext, ".o") or
            std.mem.eql(u8, ext, ".a") or
            std.mem.eql(u8, ext, ".so") or
            std.mem.eql(u8, ext, ".dylib") or
            std.mem.eql(u8, ext, ".dll"))
        {
            continue;
        }

        total_files += 1;
        const result = checkFile(allocator, entry.path) catch continue;

        if (result.has_cyrillic) {
            files_with_cyrillic += 1;
            std.debug.print("  ❌ {s}:{d}\n", .{ entry.path, result.first_line });
        }
    }

    return .{ .files_with_cyrillic = files_with_cyrillic, .total_files = total_files };
}

fn getStagedFiles(allocator: std.mem.Allocator) !std.ArrayListUnmanaged([]const u8) {
    var files = std.ArrayListUnmanaged([]const u8){};

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "diff", "--cached", "--name-only", "--diff-filter=ACM" },
    }) catch |err| {
        std.debug.print("Error running git: {}\n", .{err});
        return err;
    };
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.stderr.len > 0) {
        std.debug.print("git error: {s}\n", .{result.stderr});
    }

    var iter = std.mem.splitScalar(u8, result.stdout, '\n');
    while (iter.next()) |file| {
        if (file.len == 0) continue;
        const owned = try allocator.dupe(u8, file);
        try files.append(allocator, owned);
    }

    return files;
}

pub fn main() !u8 {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 2) {
        std.debug.print(
            \\Usage: cyrillic-guard [--all | <path>]
            \\
            \\Options:
            \\  (no args)    Check only staged git files
            \\  --all        Check entire repository
            \\  <path>       Check specific file or directory
            \\
        , .{});
        return 2;
    }

    var total_files: usize = 0;
    var files_with_cyrillic: usize = 0;

    if (args.len == 1) {
        // Check only staged files
        var staged = try getStagedFiles(allocator);
        defer {
            for (staged.items) |f| allocator.free(f);
            staged.deinit(allocator);
        }

        if (staged.items.len == 0) {
            std.debug.print("No staged files found.\n", .{});
            return 0;
        }

        for (staged.items) |file| {
            total_files += 1;
            const result = checkFile(allocator, file) catch continue;
            if (result.has_cyrillic) {
                files_with_cyrillic += 1;
                std.debug.print("  ❌ {s}:{d}\n", .{ file, result.first_line });
            }
        }
    } else if (args.len == 2 and std.mem.eql(u8, args[1], "--all")) {
        // Check entire repo
        std.debug.print("Scanning entire repository...\n", .{});
        const result = try checkPath(allocator, ".");
        files_with_cyrillic = result.files_with_cyrillic;
        total_files = result.total_files;
    } else {
        // Check specific path
        const result = try checkPath(allocator, args[1]);
        files_with_cyrillic = result.files_with_cyrillic;
        total_files = result.total_files;
    }

    std.debug.print("\nChecked {d} file(s)\n", .{total_files});

    if (files_with_cyrillic > 0) {
        std.debug.print(
            \\═══════════════════════════════════════════
            \\❌ CYRILLIC DETECTED
            \\═══════════════════════════════════════════
            \\Found Cyrillic characters in {d} file(s).
            \\
            \\English-only policy: Trinity codebase uses English for all code,
            \\documentation, and commits. Please translate Cyrillic text to English.
            \\
            \\Commit blocked. Remove Cyrillic characters and try again.
            \\═══════════════════════════════════════════
        , .{files_with_cyrillic});
        return 1;
    }

    std.debug.print("✅ No Cyrillic characters found.\n", .{});
    return 0;
}

test "isCyrillic - Cyrillic block" {
    try std.testing.expect(isCyrillic('А')); // U+0410
    try std.testing.expect(isCyrillic('я')); // U+044F
    try std.testing.expect(isCyrillic('Ё')); // U+0401
}

test "isCyrillic - non-Cyrillic" {
    try std.testing.expect(!isCyrillic('A'));
    try std.testing.expect(!isCyrillic('z'));
    try std.testing.expect(!isCyrillic('0'));
    try std.testing.expect(!isCyrillic('中'));
    try std.testing.expect(!isCyrillic('α')); // Greek
}

test "isCyrillic - edge cases" {
    try std.testing.expect(!isCyrillic(0x03FF)); // Just before Cyrillic
    try std.testing.expect(isCyrillic(0x0400)); // First Cyrillic
    try std.testing.expect(isCyrillic(0x04FF)); // Last Cyrillic
    try std.testing.expect(isCyrillic(0x0500)); // Cyrillic Supplement
    try std.testing.expect(isCyrillic(0x052F)); // Last Cyrillic Supplement
    try std.testing.expect(!isCyrillic(0x0530)); // Just after Cyrillic Supplement
}
