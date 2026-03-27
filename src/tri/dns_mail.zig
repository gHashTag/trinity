// ═════════════════════════════════════════════════════════════════════════════════
// DNS MAIL — Corporate Email DNS Records Generator
// ═════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
pub const Allocator = std.mem.Allocator;

/// Supported mail providers
pub const MailProvider = enum {
    zoho,
    gmail,
    proton,
    migadu,
    outlook,
    custom,

    pub fn displayName(self: MailProvider) []const u8 {
        return switch (self) {
            .zoho => "Zoho Mail",
            .gmail => "Google Workspace (Gmail)",
            .proton => "Proton Mail",
            .migadu => "Migadu",
            .outlook => "Microsoft 365 (Outlook)",
            .custom => "Custom",
        };
    }

    pub fn signupUrl(self: MailProvider) []const u8 {
        return switch (self) {
            .zoho => "https://www.zoho.com/mail/",
            .gmail => "https://workspace.google.com/",
            .proton => "https://proton.me/mail/",
            .migadu => "https://dashboard.migadu.com/",
            .outlook => "https://www.microsoft.com/en-us/microsoft-365",
            .custom => "https://your-provider.com",
        };
    }

    pub fn freeTierLimit(self: MailProvider) ?[]const u8 {
        return switch (self) {
            .zoho => "5 mailboxes",
            .proton => "1 mailbox",
            else => null,
        };
    }

    pub fn fromString(s: []const u8) ?MailProvider {
        if (std.mem.eql(u8, s, "zoho")) return .zoho;
        if (std.mem.eql(u8, s, "gmail")) return .gmail;
        if (std.mem.eql(u8, s, "google")) return .gmail;
        if (std.mem.eql(u8, s, "gsuite")) return .gmail;
        if (std.mem.eql(u8, s, "proton")) return .proton;
        if (std.mem.eql(u8, s, "migadu")) return .migadu;
        if (std.mem.eql(u8, s, "outlook")) return .outlook;
        if (std.mem.eql(u8, s, "microsoft")) return .outlook;
        if (std.mem.eql(u8, s, "office365")) return .outlook;
        return .custom;
    }
};

/// List all supported providers (for direct use, not from tri cloud)
pub fn listProviders() void {
    const BOLD = "\x1b[1m";
    const RESET = "\x1b[0m";
    const CYAN = "\x1b[36m";
    const GRAY = "\x1b[90m";

    std.debug.print("\n{s}📧 Supported Mail Providers{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}═════════════════════════════════════════════════════{s}\n\n", .{ "\x1b[38;2;100;100;100", RESET });

    const providers = &[_]MailProvider{ .zoho, .gmail, .proton, .migadu, .outlook, .custom };

    for (providers) |p| {
        std.debug.print("  {s}{s}{s}", .{ CYAN, p.displayName(), RESET });
        if (p.freeTierLimit()) |limit| {
            std.debug.print(" ({s} free)", .{limit});
        }
        std.debug.print("\n", .{});
        std.debug.print("    {s}tri cloud mail-setup {s} <domain>{s}\n\n", .{
            GRAY, @tagName(p), RESET,
        });
    }
}

// φ² + 1/φ² = 3 | TRINITY
