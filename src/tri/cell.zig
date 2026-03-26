// ═══════════════════════════════════════════════════════════════════════════════
// cell.zig — Signature Generation for NA-R11 (.t27 files must be signed)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Issue #407: Coptic Alphabet + 3-Bank + NA-R11
//
// Every .t27 file must be signed by tri CLI to be valid.
// Signature = SHA256(content_without_signature + secret_from_.trinity/keys/t27.key)
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const crypto = std.crypto;
const sha2 = std.crypto.hash.sha2;

const Signature = @import("../signature.zig").Signature;

/// Signature header format for .t27 files
pub const T27SignatureHeader = struct {
    timestamp: i64,
    hash_type: []const u8 = "sha256",
    pipeline: []const u8,
    author: []const u8,
    module: []const u8,
    neuro: []const u8,
};

/// Generate signature for .t27 file content
pub fn generateSignature(
    allocator: Allocator,
    content: []const u8,
    pipeline: []const u8,
    author: []const u8,
    module: []const u8,
    neuro: []const u8,
) ![]const u8 {
    const timestamp = std.time.timestamp();

    // Format: tri-cli:TIMESTAMP:sha256:HASH
    var hash_buffer: [32]u8 = undefined;
    const content_hash = try hashContent(content, &hash_buffer);

    // Build signature string
    var signature = std.ArrayList(u8).init(allocator);
    defer signature.deinit();

    try signature.appendSlice("tri-cli:");
    try signature.writer().print("{d}", .{timestamp});
    try signature.appendSlice(":sha256:");
    try signature.appendSlice(content_hash);

    return signature.toOwned();
}

/// Hash content without signature header
pub fn hashContent(content: []const u8, buffer: *[32]u8) ![32]u8 {
    // Find where signature header ends (first non-comment line without ; TRI27_)
    var content_start: usize = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (!std.mem.startsWith(u8, line, ";")) {
            content_start = lines.index.?;
            break;
        }
        // Skip signature headers
        if (std.mem.indexOf(u8, line, "; TRI27_SIGNATURE") != null) continue;
        if (std.mem.indexOf(u8, line, "; TRI27_PIPELINE") != null) continue;
        if (std.mem.indexOf(u8, line, "; TRI27_AUTHOR") != null) continue;
        if (std.mem.indexOf(u8, line, "; @module:") != null) continue;
        if (std.mem.indexOf(u8, line, "; @neuro:") != null) continue;

        // Regular comment, skip
        content_start = lines.index.?;
    }

    // Hash the actual content
    const actual_content = content[content_start..];
    var h = Sha256.init(.{});
    h.update(actual_content);
    const hash = h.finalResult();

    // Convert to hex string
    var hash_str: [64]u8 = undefined;
    for (hash, 0..) |byte, i| {
        std.fmt.formatIntBuf(&hash_str[i * 2 .. i * 2 + 2], "{x:0>2}", .{byte});
    }

    buffer.* = hash_str.*;
    return buffer.*;
}

const Sha256 = sha2.Sha256;

/// Extract signature from .t27 file content
pub fn extractSignature(content: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, content, '\n');

    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "; TRI27_SIGNATURE: ")) |idx| {
            return line[idx + "; TRI27_SIGNATURE: ".len ..];
        }
    }

    return null;
}

/// Verify signature matches content
pub fn verifySignature(content: []const u8, signature: []const u8) !bool {
    _ = content;
    _ = signature;
    // TODO: Implement full verification with secret key
    // For now, just check format
    if (!std.mem.startsWith(u8, signature, "tri-cli:")) {
        return false;
    }
    return true;
}

/// Insert signature header into .t27 content
pub fn insertSignatureHeader(
    allocator: Allocator,
    content: []const u8,
    signature: T27SignatureHeader,
) ![]const u8 {
    var result = std.ArrayList(u8).initCapacity(allocator, content.len + 200) catch unreachable;

    // Add signature header
    try result.appendSlice("; TRI27_SIGNATURE: tri-cli:{d}:sha256:{s}\n", .{
        signature.timestamp,
        "{placeholder}", // Will be replaced by actual hash
    });

    try result.appendSlice("; TRI27_PIPELINE: {s}\n", .{signature.pipeline});
    try result.appendSlice("; TRI27_AUTHOR: {s}\n", .{signature.author});
    try result.appendSlice("; @module: {s}\n", .{signature.module});
    try result.appendSlice("; @neuro: {s}\n", .{signature.neuro});
    try result.appendSlice("\n");

    // Add original content
    try result.appendSlice(content);

    return result.toOwned();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "extractSignature finds valid signature" {
    const content = "; TRI27_SIGNATURE: tri-cli:1711900800:sha256:a3f2b7c1\n; Some code\nLDI t0, 10\n";
    const sig = extractSignature(content);
    try std.testing.expect(sig != null);
    try std.testing.expectEqualStrings("tri-cli:1711900800:sha256:a3f2b7c1", sig.?);
}

test "extractSignature returns null for unsigned file" {
    const content = "; Some comment\nLDI t0, 10\n";
    const sig = extractSignature(content);
    try std.testing.expect(sig == null);
}
