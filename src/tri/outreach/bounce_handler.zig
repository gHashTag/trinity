//! Bounce Handler — Automatically mark invalid emails
//!
//! PROBLEM: Without bounce handling, we'll keep emailing invalid addresses,
//! damaging domain reputation.
//!
//! SOLUTION: Parse SMTP bounce responses and auto-mark scientists as
//! do_not_email to never contact them again.

const std = @import("std");

pub const BounceType = enum {
    /// Permanent bounce — invalid email, domain doesn't exist
    permanent,

    /// Temporary bounce — mailbox full, server down
    temporary,

    /// Spam complaint — recipient marked as spam
    spam_complaint,

    /// Unknown bounce type
    unknown,
};

pub const BounceInfo = struct {
    email: []const u8,
    bounce_type: BounceType,
    reason: []const u8,
    timestamp: i64,

    /// Never email this address again
    do_not_email: bool = false,
};

pub const BounceHandler = struct {
    allocator: std.mem.Allocator,
    bounce_file: []const u8,

    pub fn init(allocator: std.mem.Allocator, bounce_file: []const u8) BounceHandler {
        return .{
            .allocator = allocator,
            .bounce_file = bounce_file,
        };
    }

    /// Parse SMTP response to detect bounce
    pub fn parseResponse(self: *BounceHandler, response: []const u8, email: []const u8) !?BounceInfo {
        _ = self;

        // Permanent bounce codes
        const permanent_patterns = [_][]const u8{
            "550", // No such user
            "551", // User not local
            "552", // Exceeded storage
            "553", // Mailbox name not allowed
            "550 5.1.1", // Recipient address rejected
            "550 5.1.2", // Bad destination system
            "permanent error",
            "does not exist",
            "no such user",
            "invalid recipient",
            "recipient rejected",
            "mailbox unavailable",
            "address rejected",
        };

        // Temporary bounce codes
        const temporary_patterns = [_][]const u8{
            "450", // Requested mail action not taken
            "451", // Requested action aborted
            "452", // Requested action not taken
            "421", // Service not available
            "temporary error",
            "mailbox full",
            "rate limit",
            "try again later",
            "service unavailable",
        };

        // Spam complaint patterns
        const spam_patterns = [_][]const u8{
            "spam complaint",
            "reported spam",
            "blocked as spam",
            "spam",
        };

        const response_lower = try toLower(self.allocator, response);
        defer self.allocator.free(response_lower);

        // Check for spam first (most serious)
        for (spam_patterns) |pattern| {
            if (std.mem.indexOf(u8, response_lower, try toLower(self.allocator, pattern))) |_| {
                return BounceInfo{
                    .email = email,
                    .bounce_type = .spam_complaint,
                    .reason = "Recipient marked as spam",
                    .timestamp = std.time.timestamp(),
                    .do_not_email = true,
                };
            }
        }

        // Check for permanent bounces
        for (permanent_patterns) |pattern| {
            if (std.mem.indexOf(u8, response_lower, try toLower(self.allocator, pattern))) |_| {
                return BounceInfo{
                    .email = email,
                    .bounce_type = .permanent,
                    .reason = extractReason(response),
                    .timestamp = std.time.timestamp(),
                    .do_not_email = true,
                };
            }
        }

        // Check for temporary bounces
        for (temporary_patterns) |pattern| {
            if (std.mem.indexOf(u8, response_lower, try toLower(self.allocator, pattern))) |_| {
                return BounceInfo{
                    .email = email,
                    .bounce_type = .temporary,
                    .reason = extractReason(response),
                    .timestamp = std.time.timestamp(),
                    .do_not_email = false, // Retry later
                };
            }
        }

        return null;
    }

    /// Record bounce to file for tracking
    pub fn recordBounce(self: *BounceHandler, bounce: BounceInfo) !void {
        const file = try std.fs.createFileAbsolute(
            self.bounce_file,
            .{ .read = true, .write = true },
        );
        defer file.close();

        const writer = file.writer();
        try writer.print("{d},{s},{s},{s},{d}\n", .{
            bounce.timestamp,
            bounce.email,
            @tagName(bounce.bounce_type),
            bounce.reason,
            @intFromBool(bounce.do_not_email),
        });
    }

    /// Check if email should be blocked (pre-send check)
    pub fn shouldBlockEmail(self: *BounceHandler, email: []const u8) !bool {
        const file = std.fs.openFileAbsolute(
            self.bounce_file,
            .{} catch return false,
        );
        defer file.close();

        var buffer: [1024]u8 = undefined;
        while (try file.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            if (std.mem.indexOf(u8, line, email)) |_| {
                // Check if marked as do_not_email (last column = 1)
                if (std.mem.lastIndexOfScalar(u8, line, '1')) |_| {
                    return true;
                }
            }
        }

        return false;
    }

    /// Get bounce statistics
    pub fn getStats(self: *BounceHandler) !BounceStats {
        const file = std.fs.openFileAbsolute(
            self.bounce_file,
            .{} catch return .{
                .permanent = 0,
                .temporary = 0,
                .spam = 0,
                .total = 0,
            },
        );
        defer file.close();

        var stats = BounceStats{};
        var buffer: [1024]u8 = undefined;

        while (try file.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            stats.total += 1;

            if (std.mem.indexOf(u8, line, "permanent")) |_| {
                stats.permanent += 1;
            } else if (std.mem.indexOf(u8, line, "temporary")) |_| {
                stats.temporary += 1;
            } else if (std.mem.indexOf(u8, line, "spam")) |_| {
                stats.spam += 1;
            }
        }

        return stats;
    }
};

pub const BounceStats = struct {
    permanent: u32 = 0,
    temporary: u32 = 0,
    spam: u32 = 0,
    total: u32 = 0,

    pub fn format(self: BounceStats, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(
            allocator,
            "Bounce Stats: {d} total ({d} permanent, {d} temporary, {d} spam)",
            .{ self.total, self.permanent, self.temporary, self.spam },
        );
    }
};

/// Extract human-readable reason from bounce response
fn extractReason(response: []const u8) []const u8 {
    // Find first meaningful line after status code
    var lines = std.mem.splitScalar(u8, response, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \r");
        if (trimmed.len > 10) { // Skip status codes, get message
            return trimmed;
        }
    }
    return "Unknown bounce reason";
}

fn toLower(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    for (s) |c| {
        try result.append(if (c >= 'A' and c <= 'Z') c + 32 else c);
    }
    return result.toOwnedSlice();
}

test "parseResponse — permanent bounce" {
    const std = @import("std");
    const allocator = std.testing.allocator;
    var handler = BounceHandler.init(allocator, "/tmp/test_bounce.txt");

    const response = "550 5.1.1 The email account that you tried to reach does not exist.";
    const result = try handler.parseResponse(response, "test@example.com");

    try std.testing.expect(result != null);
    try std.testing.expectEqual(BounceType.permanent, result.?.bounce_type);
    try std.testing.expect(result.?.do_not_email);
}

test "parseResponse — temporary bounce" {
    const std = @import("std");
    const allocator = std.testing.allocator;
    var handler = BounceHandler.init(allocator, "/tmp/test_bounce.txt");

    const response = "450 4.2.1 The user you are trying to contact is receiving mail too quickly.";
    const result = try handler.parseResponse(response, "test@example.com");

    try std.testing.expect(result != null);
    try std.testing.expectEqual(BounceType.temporary, result.?.bounce_type);
    try std.testing.expect(!result.?.do_not_email);
}

test "parseResponse — spam complaint" {
    const std = @import("std");
    const allocator = std.testing.allocator;
    var handler = BounceHandler.init(allocator, "/tmp/test_bounce.txt");

    const response = "550 5.7.1 Message rejected as spam by recipient";
    const result = try handler.parseResponse(response, "test@example.com");

    try std.testing.expect(result != null);
    try std.testing.expectEqual(BounceType.spam_complaint, result.?.bounce_type);
    try std.testing.expect(result.?.do_not_email);
}
