//! tri/mime — RFC 5322 email format
//! Auto-generated from specs/tri/tri_mime.tri
//! TTT Dogfood v0.2 Stage 114

const std = @import("std");

/// Email message structure
pub const Email = struct {
    from: []const u8,
    to: std.ArrayList([]const u8),
    subject: []const u8,
    body: []const u8,

    /// Free resources
    pub fn deinit(self: Email, allocator: std.mem.Allocator) void {
        @constCast(&self.to).deinit(allocator);
    }
};

/// Parse email format (simplified RFC 5322)
pub fn parse(raw: []const u8, allocator: std.mem.Allocator) !Email {
    var email = Email{
        .from = "",
        .to = std.ArrayList([]const u8).initCapacity(allocator, 0) catch unreachable,
        .subject = "",
        .body = "",
    };
    errdefer email.to.deinit(allocator);

    var lines = std.mem.splitScalar(u8, raw, '\n');
    var in_headers = true;
    var body_started = false;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, "\r");

        if (in_headers) {
            if (trimmed.len == 0) {
                in_headers = false;
                continue;
            }

            // Parse header
            if (std.mem.indexOfScalar(u8, trimmed, ':')) |colon_idx| {
                const header_name = std.mem.trim(u8, trimmed[0..colon_idx], " ");
                const header_value = std.mem.trim(u8, trimmed[colon_idx + 1 ..], " ");

                if (std.ascii.eqlIgnoreCase(header_name, "From")) {
                    email.from = try allocator.dupe(u8, header_value);
                } else if (std.ascii.eqlIgnoreCase(header_name, "To")) {
                    // Split by comma for multiple recipients
                    var recipients = std.mem.splitScalar(u8, header_value, ',');
                    while (recipients.next()) |recipient| {
                        const trimmed_recipient = std.mem.trim(u8, recipient, " ");
                        if (trimmed_recipient.len > 0) {
                            try email.to.append(allocator, try allocator.dupe(u8, trimmed_recipient));
                        }
                    }
                } else if (std.ascii.eqlIgnoreCase(header_name, "Subject")) {
                    email.subject = try allocator.dupe(u8, header_value);
                }
            }
        } else {
            if (!body_started) {
                body_started = true;
                email.body = try allocator.dupe(u8, trimmed);
            } else {
                // Append to body with newline
                const new_body = try allocator.alloc(u8, email.body.len + trimmed.len + 1);
                @memcpy(new_body[0..email.body.len], email.body);
                new_body[email.body.len] = '\n';
                @memcpy(new_body[email.body.len + 1 ..], trimmed);
                allocator.free(email.body);
                email.body = new_body;
            }
        }
    }

    return email;
}

/// Format as RFC 5322
pub fn format(email: Email, allocator: std.mem.Allocator) ![]u8 {
    var result = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable;
    errdefer result.deinit(allocator);

    // From header
    try result.appendSlice(allocator, "From: ");
    try result.appendSlice(allocator, email.from);
    try result.appendSlice(allocator, "\r\n");

    // To header
    try result.appendSlice(allocator, "To: ");
    for (email.to.items, 0..) |recipient, i| {
        if (i > 0) try result.appendSlice(allocator, ", ");
        try result.appendSlice(allocator, recipient);
    }
    try result.appendSlice(allocator, "\r\n");

    // Subject header
    try result.appendSlice(allocator, "Subject: ");
    try result.appendSlice(allocator, email.subject);
    try result.appendSlice(allocator, "\r\n");

    // Empty line separator
    try result.appendSlice(allocator, "\r\n");

    // Body
    try result.appendSlice(allocator, email.body);

    return result.toOwnedSlice(allocator);
}

test "parse simple email" {
    const raw = "From: sender@example.com\r\n" ++
        "To: recipient@example.com\r\n" ++
        "Subject: Test\r\n" ++
        "\r\n" ++
        "Hello, World!";

    const email = try parse(raw, std.testing.allocator);
    defer email.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("sender@example.com", email.from);
    try std.testing.expectEqual(@as(usize, 1), email.to.items.len);
    try std.testing.expectEqualStrings("recipient@example.com", email.to.items[0]);
    try std.testing.expectEqualStrings("Test", email.subject);
    try std.testing.expectEqualStrings("Hello, World!", email.body);
}

test "parse multiple recipients" {
    const raw = "From: sender@example.com\r\n" ++
        "To: alice@example.com, bob@example.com\r\n" ++
        "Subject: Test\r\n" ++
        "\r\n" ++
        "Body";

    const email = try parse(raw, std.testing.allocator);
    defer email.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), email.to.items.len);
    try std.testing.expectEqualStrings("alice@example.com", email.to.items[0]);
    try std.testing.expectEqualStrings("bob@example.com", email.to.items[1]);
}

test "format email" {
    var email = Email{
        .from = "sender@example.com",
        .to = std.ArrayList([]const u8).initCapacity(std.testing.allocator, 0) catch unreachable,
        .subject = "Test",
        .body = "Hello, World!",
    };
    defer email.to.deinit(std.testing.allocator);

    try email.to.append(std.testing.allocator, "recipient@example.com");

    const formatted = try format(email, std.testing.allocator);
    defer std.testing.allocator.free(formatted);

    try std.testing.expectEqualStrings(
        "From: sender@example.com\r\n" ++
            "To: recipient@example.com\r\n" ++
            "Subject: Test\r\n" ++
            "\r\n" ++
            "Hello, World!",
        formatted,
    );
}
