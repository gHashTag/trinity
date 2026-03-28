//! SMTP Email Sending with RFC 8058 List-Unsubscribe Header
//!
//! Gmail requires List-Unsubscribe header since Feb 2024 for bulk senders.
//! See: https://www.rfc-editor.org/rfc/rfc8058.html

const std = @import("std");
const types = @import("types.zig");

pub const SmtpHeader = struct {
    name: []const u8,
    value: []const u8,
};

/// Generate RFC 8058 compliant List-Unsubscribe headers
pub fn generateListUnsubscribeHeaders(allocator: std.mem.Allocator, unsubscribe_url: []const u8) ![]const SmtpHeader {
    const headers = try allocator.alloc(SmtpHeader, 2);

    // List-Unsubscribe: <https://t27.ai/unsubscribe?id=uuid>
    headers[0] = .{
        .name = "List-Unsubscribe",
        .value = try std.fmt.allocPrint(allocator, "<{s}>", .{unsubscribe_url}),
    };

    // List-Unsubscribe-Post: List-Unsubscribe=One-Click
    headers[1] = .{
        .name = "List-Unsubscribe-Post",
        .value = "List-Unsubscribe=One-Click",
    };

    return headers;
}

/// Generate all email headers including List-Unsubscribe
pub fn generateHeaders(allocator: std.mem.Allocator, msg: types.EmailMessage, config: types.OutreachConfig) ![][]const u8 {
    // Base headers
    var header_list = std.ArrayList([]const u8).init(allocator);

    // From
    try header_list.append(try std.fmt.allocPrint(allocator, "From: {s} <{s}>", .{ "Dmitrii Vasilev", config.sender_email }));

    // To
    try header_list.append(try std.fmt.allocPrint(allocator, "To: {s} <{s}>", .{ msg.to_name, msg.to }));

    // Subject
    try header_list.append(try std.fmt.allocPrint(allocator, "Subject: {s}", .{msg.subject}));

    // Message-ID
    try header_list.append(try std.fmt.allocPrint(allocator, "Message-ID: <{s}@t27.ai>", .{msg.message_id}));

    // Date
    const datetime = getDateTime(allocator);
    defer allocator.free(datetime);
    try header_list.append(try std.fmt.allocPrint(allocator, "Date: {s}", .{datetime}));

    // Reply-To
    try header_list.append(try std.fmt.allocPrint(allocator, "Reply-To: {s}", .{config.sender_email}));

    // List-Unsubscribe (RFC 8058)
    try header_list.append(try std.fmt.allocPrint(allocator, "List-Unsubscribe: <{s}>", .{msg.unsubscribe_url}));

    // List-Unsubscribe-Post (One-Click)
    try header_list.append("List-Unsubscribe-Post: List-Unsubscribe=One-Click");

    // In-Reply-To (for follow-ups)
    if (msg.in_reply_to_message_id) |in_reply_to| {
        try header_list.append(try std.fmt.allocPrint(allocator, "In-Reply-To: <{s}>", .{in_reply_to}));

        try header_list.append(try std.fmt.allocPrint(allocator, "References: <{s}>", .{in_reply_to}));
    }

    // MIME headers
    try header_list.append("MIME-Version: 1.0");
    try header_list.append("Content-Type: text/plain; charset=UTF-8");
    try header_list.append("Content-Transfer-Encoding: 8bit");

    // X-Entity-Ref (for tracking)
    try header_list.append(try std.fmt.allocPrint(allocator, "X-Entity-Ref: {s}", .{msg.message_id}));

    return header_list.toOwnedSlice();
}

/// Get current datetime in RFC 5322 format
fn getDateTime(allocator: std.mem.Allocator) ![]const u8 {
    const timestamp = std.time.timestamp();

    // Convert to RFC 5322 date format
    // Example: Tue, 28 Mar 2026 12:34:56 +0000
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(timestamp) };
    const day = epoch.getDayOfWeek();

    const days = [_][]const u8{ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
    const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

    const datetime = try std.fmt.allocPrint(allocator, "{s}, {d:02} {s} {d:04} {d:02}:{d:02}:{d:02} +0000", .{
        days[@intCast(day)],
        epoch.getDay(),
        months[epoch.getMonth() - 1],
        epoch.getYear(),
        epoch.getHours(),
        epoch.getMinutes(),
        epoch.getSeconds(),
    });

    return datetime;
}

/// Verify email compliance before sending
pub fn verifyCompliance(msg: types.EmailMessage) !ComplianceResult {
    var result = ComplianceResult{
        .compliant = true,
        .issues = std.ArrayList([]const u8).init(std.heap.page_allocator),
    };

    // Check unsubscribe URL
    if (msg.unsubscribe_url.len == 0) {
        result.compliant = false;
        try result.issues.append("Missing unsubscribe URL (CAN-SPAM violation)");
    }

    // Check subject length
    if (msg.subject.len > 78) {
        // Not fatal, but may trigger spam filters
        try result.issues.append("Subject line exceeds 78 characters");
    }

    // Check body_text length
    if (msg.body_text.len < 50) {
        result.compliant = false;
        try result.issues.append("Email body too short (looks like spam)");
    }

    // Check for spam keywords
    const spam_keywords = [_][]const u8{
        "buy now",
        "click here",
        "free money",
        "urgent",
        "act now",
    };

    const body_lower = std.ascii.allocLowerString(std.heap.page_allocator, msg.body_text) catch "";
    defer std.heap.page_allocator.free(body_lower);

    for (spam_keywords) |keyword| {
        if (std.mem.indexOf(u8, body_lower, keyword)) |_| {
            try result.issues.append("Spam keyword detected");
        }
    }

    return result;
}

pub const ComplianceResult = struct {
    compliant: bool,
    issues: std.ArrayList([]const u8),

    pub fn deinit(self: *ComplianceResult) void {
        for (self.issues.items) |issue| {
            self.issues.allocator.free(issue);
        }
        self.issues.deinit();
    }
};

test "generateListUnsubscribeHeaders" {
    const std = @import("std");
    const allocator = std.testing.allocator;

    const url = "https://t27.ai/unsubscribe?id=test123";
    const headers = try generateListUnsubscribeHeaders(allocator, url);
    defer allocator.free(headers);

    try std.testing.expectEqual(@as(usize, 2), headers.len);
    try std.testing.expectEqualStrings("List-Unsubscribe", headers[0].name);
    try std.testing.expectEqualStrings("List-Unsubscribe-Post", headers[1].name);
}

test "getDateTime format" {
    const std = @import("std");
    const allocator = std.testing.allocator;

    const datetime = try getDateTime(allocator);
    defer allocator.free(datetime);

    // Should match RFC 5322 format
    try std.testing.expect(datetime.len > 20);
}
