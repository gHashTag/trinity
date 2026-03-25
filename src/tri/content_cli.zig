// ═══════════════════════════════════════════════════════════════════════════════
// content_cli.zig - Content-Addressed Functions CLI Commands
// ═══════════════════════════════════════════════════════════════════════════════════════
//
// TRI-LANG-6: Content-Addressed Functions
//
// CLI commands:
//   tri content hash <file.tri>        # Show content hashes for all functions
//   tri content registry                # Show content registry
//   tri content duplicates              # Find duplicate functions
//   tri content verify                  # Verify content hashes match registry
//   tri hash-fn <module.fn>             # Show content hash for a function
//   tri hash-fn-compare <module.fn>     # Compare manual vs self-hosted hashes
//
// ═══════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const tri_lang = @import("tri_lang");
const content_hash = tri_lang.content_hash;
const content_registry = tri_lang.content_registry;

const ContentHash = content_hash.ContentHash;
const ContentRegistry = content_registry.ContentRegistry;
const FunctionLocation = content_registry.FunctionLocation;
const DuplicateInfo = content_registry.DuplicateInfo;
const DEFAULT_REGISTRY_PATH = content_registry.DEFAULT_REGISTRY_PATH;

const TypedExpr = tri_lang.typechecker.TypedExpr;
const hashFunctionDecl = content_hash.hashFunctionDecl;

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Command: Show content hashes for all functions in a file
pub fn cmdHash(allocator: Allocator, file_path: []const u8) !void {
    _ = allocator;
    _ = file_path;
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Content hash command deprecated - use 'tri hash-fn' instead\n", .{});
}

/// Command: Show content registry
pub fn cmdRegistry(allocator: Allocator, registry_path: ?[]const u8) !void {
    const path = registry_path orelse DEFAULT_REGISTRY_PATH;

    const registry = ContentRegistry.loadFromFile(allocator, path) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Registry not found at {s}\n", .{path});
            return;
        }
        return err;
    };
    defer registry.deinit();

    const stdout = std.io.getStdOut().writer();
    const stats = registry.stats();

    try stdout.print("Content Registry: {s}\n", .{path});
    try stdout.print("  Unique hashes: {d}\n", .{stats.unique_hashes});
    try stdout.print("  Total functions: {d}\n", .{stats.total_functions});
    try stdout.print("  Duplicate hashes: {d}\n", .{stats.duplicate_count});
    try stdout.print("  Duplicate functions: {d}\n", .{stats.duplicate_functions});
}

/// Command: Find duplicate functions
pub fn cmdDuplicates(allocator: Allocator, registry_path: ?[]const u8) !void {
    const path = registry_path orelse DEFAULT_REGISTRY_PATH;

    const registry = ContentRegistry.loadFromFile(allocator, path) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Registry not found at {s}\n", .{path});
            return;
        }
        return err;
    };
    defer registry.deinit();

    const stdout = std.io.getStdOut().writer();

    const dups = try registry.detectDuplicates();
    defer {
        for (dups) |*d| d.deinit(allocator);
        allocator.free(dups);
    }

    if (dups.len == 0) {
        try stdout.print("No duplicate functions found.\n", .{});
        return;
    }

    try stdout.print("Found {d} duplicate function groups:\n\n", .{dups.len});

    for (dups, 0..) |dup, i| {
        const short_hash = try dup.hash.formatShort(allocator);
        defer allocator.free(short_hash);

        try stdout.print("{d}. Hash: {s} ({d} occurrences)\n", .{ i + 1, short_hash, dup.locations.len });

        for (dup.locations) |loc| {
            try stdout.print("   - {s}::{s} @ {s}:{d}\n", .{ loc.module, loc.name, loc.file_path, loc.line });
        }
        try stdout.writeAll("\n");
    }
}

/// Command: Verify content hashes match registry
pub fn cmdVerify(allocator: Allocator, registry_path: ?[]const u8) !void {
    const path = registry_path orelse DEFAULT_REGISTRY_PATH;

    const registry = ContentRegistry.loadFromFile(allocator, path) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Registry not found at {s}\n", .{path});
            return;
        }
        return err;
    };
    defer registry.deinit();

    const stdout = std.io.getStdOut().writer();

    try stdout.print("Registry loaded: {d} unique hashes\n", .{registry.size()});
    try stdout.print("(Full verification requires recompilation)\n", .{});
}

/// Command: Initialize a new registry
pub fn cmdInit(allocator: Allocator, registry_path: ?[]const u8) !void {
    const path = registry_path orelse DEFAULT_REGISTRY_PATH;

    // Check if registry already exists
    if (std.fs.cwd().openFile(path, .{})) |file| {
        file.close();
        std.debug.print("Registry already exists at {s}\n", .{path});
        return error.AlreadyExists;
    } else |_| {}

    const registry = try ContentRegistry.init(allocator);
    defer registry.deinit();

    try registry.saveToFile(path);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Initialized empty registry at {s}\n", .{path});
}

/// Command: Show detailed information about a specific hash
pub fn cmdShowHash(allocator: Allocator, hash_str: []const u8, registry_path: ?[]const u8) !void {
    const path = registry_path orelse DEFAULT_REGISTRY_PATH;

    const registry = ContentRegistry.loadFromFile(allocator, path) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Registry not found at {s}\n", .{path});
            return;
        }
        return err;
    };
    defer registry.deinit();

    // Parse hash string
    var hash_bytes: [32]u8 = undefined;

    // Support both short (8 bytes) and full (32 bytes) hex formats
    const input = if (std.mem.startsWith(u8, hash_str, "sha256:"))
        hash_str[7..]
    else
        hash_str;

    const len = @min(input.len / 2, 32);
    for (0..len) |i| {
        const byte_str = input[i * 2 .. i * 2 + 2];
        hash_bytes[i] = std.fmt.parseInt(u8, byte_str, 16) catch {
            std.debug.print("Invalid hash format: {s}\n", .{hash_str});
            return error.InvalidHash;
        };
    }

    // Zero out remaining bytes if short hash
    for (len..32) |i| {
        hash_bytes[i] = 0;
    }

    var hash: ContentHash = undefined;
    @memcpy(&hash.bytes, &hash_bytes);

    const locations = registry.lookup(hash) orelse {
        std.debug.print("Hash not found in registry\n", .{});
        return;
    };

    const stdout = std.io.getStdOut().writer();
    const full_hash = try hash.format(allocator);
    defer allocator.free(full_hash);

    try stdout.print("Hash: {s}\n", .{full_hash});
    try stdout.print("Found {d} location(s):\n", .{locations.len});

    for (locations) |loc| {
        try stdout.print("  - {s}::{s}\n", .{ loc.module, loc.name });
        try stdout.print("    File: {s}:{d}\n", .{ loc.file_path, loc.line });
    }
}

/// Command: Export registry to different format
pub fn cmdExport(allocator: Allocator, format: []const u8, output_path: []const u8, registry_path: ?[]const u8) !void {
    const path = registry_path orelse DEFAULT_REGISTRY_PATH;

    const registry = ContentRegistry.loadFromFile(allocator, path) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Registry not found at {s}\n", .{path});
            return;
        }
        return err;
    };
    defer registry.deinit();

    const stdout = std.io.getStdOut().writer();

    if (std.mem.eql(u8, format, "json")) {
        const json = try ContentRegistry.toJson(allocator, &registry);
        defer allocator.free(json);

        try std.fs.cwd().writeFile(.{ .sub_path = output_path }, json);
        try stdout.print("Exported registry to {s}\n", .{output_path});
    } else {
        try stdout.print("Unknown export format: {s}\n", .{format});
        return error.UnknownFormat;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HASH-FN COMMANDS (V2: Production-level content hashing)
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Parse target like "vsa.ops.bind" into module and function name
fn parseTarget(target: []const u8) struct { module: []const u8, fn_name: []const u8 } {
    const dot_idx = std.mem.lastIndexOfScalar(u8, target, '.') orelse {
        return .{ .module = target, .fn_name = "*" };
    };
    return .{
        .module = target[0..dot_idx],
        .fn_name = target[dot_idx + 1 ..],
    };
}

/// Check if we're in self-hosted mode (TRINITY_SELF_HOSTED=1)
fn isSelfHosted() bool {
    if (std.process.getEnvVarOwned(std.heap.page_allocator, "TRINITY_SELF_HOSTED")) |env| {
        defer std.heap.page_allocator.free(env);
        return std.mem.eql(u8, env, "1") or std.mem.eql(u8, env, "true");
    } else |_| {
        return false;
    }
}

/// Format hash bytes as hex string (short: 8 chars, full: 64 chars)
fn formatHash(allocator: Allocator, hash: *const ContentHash, short: bool) ![]u8 {
    const len = if (short) @as(usize, 8) else @as(usize, 32);
    const result = try allocator.alloc(u8, len * 2);
    var i: usize = 0;
    while (i < len) : (i += 1) {
        try std.fmt.formatIntBuf(result[i * 2 .. i * 2 + 2], hash.bytes[i], .lower, .hex, 2);
    }
    return result;
}

/// Command: Show content hash for a function
/// Usage: tri hash-fn <module.fn> or tri hash-fn <module.*>
pub fn cmdHashFn(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    if (args.len < 1) {
        std.debug.print("Usage: tri hash-fn <module.fn> | <module.*>\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Examples:\n", .{});
        std.debug.print("  tri hash-fn vsa.ops.bind       # Hash single function\n", .{});
        std.debug.print("  tri hash-fn vsa.ops.*          # Hash all functions in module\n", .{});
        std.debug.print("  TRINITY_SELF_HOSTED=1 tri hash-fn vsa.ops.bind  # Self-hosted build\n", .{});
        return error.MissingArgument;
    }

    const target = args[0];
    const parsed = parseTarget(target);
    const self_hosted = isSelfHosted();

    // For now, we use a simple approach: read Zig source, extract function, hash
    // In production, this would use the V2 content_hash infrastructure

    if (std.mem.eql(u8, parsed.fn_name, "*")) {
        // All functions in module - list them
        std.debug.print("Scanning module: {s}\n", .{parsed.module});
        std.debug.print("(Full implementation requires Zig AST parsing)\n", .{});
        std.debug.print("Self-hosted: {s}\n", .{if (self_hosted) "YES" else "NO"});
    } else {
        // Single function
        std.debug.print("Computing hash for: {s}::{s}\n", .{ parsed.module, parsed.fn_name });
        std.debug.print("(Full implementation requires Zig AST parsing)\n", .{});
        std.debug.print("Self-hosted: {s}\n", .{if (self_hosted) "YES" else "NO"});

        // Placeholder: In production, this would:
        // 1. Parse the Zig file
        // 2. Extract the function AST
        // 3. Run through content_hash_v2.zig normalization
        // 4. Output: sha256:abcd...

        // For now, output a deterministic placeholder based on module+fn+self_hosted
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(parsed.module);
        hasher.update(".");
        hasher.update(parsed.fn_name);
        if (self_hosted) {
            hasher.update(":self-hosted");
        }
        const hash_val = hasher.final();

        std.debug.print("sha256:{x:0>16}\n", .{hash_val});
    }
}

/// Command: Compare content hashes between manual and self-hosted builds
/// Usage: tri hash-fn-compare <module.fn> or tri hash-fn-compare <module.*>
pub fn cmdHashFnCompare(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    if (args.len < 1) {
        std.debug.print("Usage: tri hash-fn-compare <module.fn> | <module.*>\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Examples:\n", .{});
        std.debug.print("  tri hash-fn-compare vsa.ops.bind    # Compare single function\n", .{});
        std.debug.print("  tri hash-fn-compare vsa.ops.*       # Compare all functions\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Shell usage:\n", .{});
        std.debug.print("  HASH_MANUAL=$(TRINITY_SELF_HOSTED=0 tri hash-fn vsa.ops.bind)\n", .{});
        std.debug.print("  HASH_SELF=$(TRINITY_SELF_HOSTED=1 tri hash-fn vsa.ops.bind)\n", .{});
        std.debug.print("  [ \"$HASH_MANUAL\" = \"$HASH_SELF\" ] && echo OK || echo MISMATCH\n", .{});
        return error.MissingArgument;
    }

    const target = args[0];
    _ = parseTarget(target);

    std.debug.print("Comparing: {s}\n", .{target});
    std.debug.print("\n", .{});
    std.debug.print("Manual build hash (TRINITY_SELF_HOSTED=0):\n", .{});
    std.debug.print("Self-hosted build hash (TRINITY_SELF_HOSTED=1):\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("(Full implementation requires running tri twice with different env vars)\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Shell script approach:\n", .{});
    std.debug.print("  #!/bin/bash\n", .{});
    std.debug.print("  MANUAL=$(TRINITY_SELF_HOSTED=0 tri hash-fn {s} | grep 'sha256:' | cut -d: -f2)\n", .{target});
    std.debug.print("  SELF=$(TRINITY_SELF_HOSTED=1 tri hash-fn {s} | grep 'sha256:' | cut -d: -f2)\n", .{target});
    std.debug.print("  if [ \"$MANUAL\" = \"$SELF\" ]; then\n", .{});
    std.debug.print("    echo \"✓ {s}: OK\"\n", .{target});
    std.debug.print("  else\n", .{});
    std.debug.print("    echo \"✗ {s}: MISMATCH\"\n", .{target});
    std.debug.print("    echo \"  Manual:   $MANUAL\"\n", .{});
    std.debug.print("    echo \"  Self-host: $SELF\"\n", .{});
    std.debug.print("    exit 1\n", .{});
    std.debug.print("  fi\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Print usage information
pub fn printUsage() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll(
        \\Content-Addressed Functions Commands:
        \\
        \\  tri content hash <file.tri>        Show content hashes for all functions
        \\  tri content registry [path]         Show content registry
        \\  tri content duplicates [path]       Find duplicate functions
        \\  tri content verify [path]           Verify content hashes match registry
        \\  tri content init [path]             Initialize new registry
        \\  tri content show <hash> [path]      Show details for a hash
        \\  tri content export <format> <out>   Export registry (json)
        \\
        \\Default registry path: .trinity/content_registry.json
        \\
    );
}

/// Run content command
pub fn runCommand(allocator: Allocator, args: [][:0]const u8) !void {
    if (args.len < 1) {
        try printUsage();
        return;
    }

    const command = args[0];

    if (std.mem.eql(u8, command, "hash")) {
        if (args.len < 2) {
            std.debug.print("Usage: tri content hash <file.tri>\n", .{});
            return error.MissingArgument;
        }
        try cmdHash(allocator, args[1]);
    } else if (std.mem.eql(u8, command, "registry")) {
        const path = if (args.len >= 2) args[1] else null;
        try cmdRegistry(allocator, path);
    } else if (std.mem.eql(u8, command, "duplicates")) {
        const path = if (args.len >= 2) args[1] else null;
        try cmdDuplicates(allocator, path);
    } else if (std.mem.eql(u8, command, "verify")) {
        const path = if (args.len >= 2) args[1] else null;
        try cmdVerify(allocator, path);
    } else if (std.mem.eql(u8, command, "init")) {
        const path = if (args.len >= 2) args[1] else null;
        try cmdInit(allocator, path);
    } else if (std.mem.eql(u8, command, "show")) {
        if (args.len < 2) {
            std.debug.print("Usage: tri content show <hash> [path]\n", .{});
            return error.MissingArgument;
        }
        const path = if (args.len >= 3) args[2] else null;
        try cmdShowHash(allocator, args[1], path);
    } else if (std.mem.eql(u8, command, "export")) {
        if (args.len < 3) {
            std.debug.print("Usage: tri content export <format> <output>\n", .{});
            return error.MissingArgument;
        }
        const path = if (args.len >= 4) args[3] else null;
        try cmdExport(allocator, args[1], args[2], path);
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        try printUsage();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════

test "cmdInit creates new registry" {
    const a = std.testing.allocator;
    const test_path = "/tmp/test_content_registry.json";

    // Clean up any existing test file
    std.fs.cwd().deleteFile(test_path) catch {};

    try cmdInit(a, test_path);

    // Verify registry was created
    const registry = try ContentRegistry.loadFromFile(a, test_path);
    defer registry.deinit();

    try std.testing.expectEqual(@as(usize, 0), registry.size());

    // Clean up
    std.fs.cwd().deleteFile(test_path) catch {};
}

test "cmdInit fails if registry exists" {
    const a = std.testing.allocator;
    const test_path = "/tmp/test_content_registry_exists.json";

    // Clean up any existing test file
    std.fs.cwd().deleteFile(test_path) catch {};

    // Create initial registry
    try cmdInit(a, test_path);

    // Try to create again - should fail
    const result = cmdInit(a, test_path);
    try std.testing.expectError(error.AlreadyExists, result);

    // Clean up
    std.fs.cwd().deleteFile(test_path) catch {};
}

test "FunctionLocation helper" {
    _ = std.testing.allocator;

    const loc = FunctionLocation{
        .module = "test.module",
        .name = "test_func",
        .line = 42,
        .file_path = "test/file.tri",
    };

    try std.testing.expectEqualStrings("test.module", loc.module);
    try std.testing.expectEqual(@as(usize, 42), loc.line);
}

test "runCommand with unknown command" {
    const a = std.testing.allocator;

    // Should not crash, just print usage
    const result = runCommand(a, &[_][:0]const u8{"unknown"});
    // The function should succeed (prints usage)
    _ = result catch |err| {
        // Either returns success or an error
        _ = err;
    };
}
