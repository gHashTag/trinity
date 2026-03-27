// ═══════════════════════════════════════════════════════════════════════════════
// t27_cli.zig — `tri t27 verify` command for NA-R11 signature verification
// ═══════════════════════════════════════════════════════════════════════════════
//
// Issue #407: Coptic Alphabet + 3-Bank + NA-R11
//
// CLI Commands:
//   tri t27 verify <file>     — Verify single .t27 file signature
//   tri t27 verify --all      — Verify all .t27 in src/tri27/
//   tri t27 sign <file>       — Re-sign .t27 file after tri canonize
//   tri t27 diff <file>       — Show changes vs signed version
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const cell = @import("cell.zig");
const AsmError = @import("../tri27/emu/asm_parser.zig").AsmError;

/// t27 verify command options
pub const VerifyOptions = struct {
    file: ?[]const u8 = null,
    all: bool = false,
    strict: bool = false,
};

/// Verify single .t27 file
pub fn verifyFile(path: []const u8, strict: bool) !VerificationResult {
    const content = try std.fs.cwd().allocator.readFile(path);

    // Check for signature header
    const sig = cell.extractSignature(content) orelse {
        return .{
            .path = path,
            .valid = false,
            .err = "T27NotSignedByTriCli",
            .message = "File does not contain TRI27_SIGNATURE header",
        };
    };

    // Verify signature
    const valid = try cell.verifySignature(content, sig);

    if (!valid) {
        return .{
            .path = path,
            .valid = false,
            .err = "T27SignatureMismatch",
            .message = "Signature verification failed",
        };
    }

    // In strict mode, also try to assemble to catch syntax errors
    if (strict) {
        // TODO: Call assembler to verify syntax
        // For now, just check signature
    }

    return .{
        .path = path,
        .valid = true,
        .err = null,
        .message = "Signature verified",
    };
}

/// Verify all .t27 files in src/tri27/
pub fn verifyAll(strict: bool) ![]VerificationResult {
    const allocator = std.fs.cwd().allocator;
    var results = std.ArrayList(VerificationResult).init(allocator);

    const src_tri27 = "src/tri27";
    var dir = try std.fs.cwd().openDir(src_tri27, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator, src_tri27);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.endsWith(u8, entry.path, ".t27")) {
            const result = try verifyFile(entry.path, strict);
            try results.append(result);
        }
    }

    return results.toOwned();
}

/// Verification result
pub const VerificationResult = struct {
    path: []const u8,
    valid: bool,
    err: ?[]const u8,
    message: []const u8,
};

/// Main entry point for `tri t27 verify` command
pub fn runVerify(options: VerifyOptions) !u8 {
    if (options.all) {
        const results = try verifyAll(options.strict);
        var exit_code: u8 = 0;

        for (results) |result| {
            if (!result.valid) {
                std.debug.print("❌ {s}: {s}\n", .{ result.path, result.message });
                if (result.err) |err| {
                    std.debug.print("   Error: {s}\n", .{err});
                }
                exit_code = 1;
            } else {
                std.debug.print("✅ {s}: {s}\n", .{ result.path, result.message });
            }
        }

        const total = results.len;
        const valid = blk: {
            var count: usize = 0;
            for (results) |r| {
                if (r.valid) count += 1;
            }
            break :count;
        };

        std.debug.print("\nSummary: {d}/{d} files valid\n", .{ valid, total });

        return exit_code;
    }

    if (options.file) |file_path| {
        const result = try verifyFile(file_path, options.strict);

        if (!result.valid) {
            std.debug.print("❌ {s}: {s}\n", .{ result.path, result.message });
            if (result.err) |err| {
                std.debug.print("   Error: {s}\n", .{err});
            }
            return 1;
        } else {
            std.debug.print("✅ {s}: {s}\n", .{ result.path, result.message });
            return 0;
        }
    }

    std.debug.print("Error: Either --file or --all must be specified\n", .{});
    return 1;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "verifyFile rejects unsigned file" {
    const content = "; Unsigned file\nLDI t0, 10\n";
    const path = "test_unsigned.t27";

    // Create temp file
    {
        const file = try std.fs.cwd().createFile(path, .{ .read = true });
        defer file.close();
        try file.writeAll(content);
    }
    defer {
        std.fs.cwd().deleteFile(path) catch {};
    }

    const result = try verifyFile(path, false);
    try std.testing.expect(!result.valid);
    try std.testing.expectEqualStrings("T27NotSignedByTriCli", result.err.?);
}

test "verifyFile accepts signed file" {
    const content = "; TRI27_SIGNATURE: tri-cli:1711900800:sha256:a3f2b7c1\nLDI t0, 10\n";
    const path = "test_signed.t27";

    {
        const file = try std.fs.cwd().createFile(path, .{ .read = true });
        defer file.close();
        try file.writeAll(content);
    }
    defer {
        std.fs.cwd().deleteFile(path) catch {};
    }

    const result = try verifyFile(path, false);
    try std.testing.expect(result.valid);
}
