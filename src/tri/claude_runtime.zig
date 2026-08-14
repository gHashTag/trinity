// @origin(spec:claude_runtime.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// CLAUDE RUNTIME — Claude Code Lifecycle Management for Railway
// ═══════════════════════════════════════════════════════════════════════════════
//
// Checks installation, version, login status, and Channels support.
// Uses Railway SSH for remote command execution.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const railway_ssh = @import("railway_ssh.zig");

const CYAN = "\x1b[0;36m";
const GREEN = "\x1b[0;32m";
const YELLOW = "\x1b[0;33m";
const RED = "\x1b[0;31m";
const RESET = "\x1b[0m";

pub const LoginStatus = enum {
    LoggedOut,
    LoggedIn,
    NotInstalled,
    Unknown,
};

pub const ClaudeInstallError = error{
    SSHExecFailed,
    CommandNotFound,
    ParseFailed,
};

const Self = @This();

/// Check if Claude Code is installed on the Railway server
/// Returns true if 'which claude' succeeds
pub fn checkInstallation(allocator: Allocator) !bool {
    var ssh = railway_ssh.RailwaySSH.initDefault();
    const output = ssh.exec(allocator, "which claude") catch return false;
    defer allocator.free(output);

    // 'which' returns path on success, empty on not found
    return output.len > 0 and !std.mem.eql(u8, std.mem.trimRight(u8, output, "\n\r"), "");
}

/// Get the installed Claude Code version
/// Returns owned version string (caller must free)
pub fn getInstalledVersion(allocator: Allocator) ![]const u8 {
    var ssh = railway_ssh.RailwaySSH.initDefault();
    const output = ssh.exec(allocator, "claude --version") catch {
        return error.CommandNotFound;
    };
    defer allocator.free(output);

    // Parse version from output like "claude 2.1.80 (abc123)"
    const trimmed = std.mem.trim(u8, output, "\n\r ");
    var iter = std.mem.splitScalar(u8, trimmed, ' ');
    const first = iter.next() orelse return error.ParseFailed;
    _ = first; // "claude"
    const version = iter.next() orelse return error.ParseFailed;

    return allocator.dupe(u8, version);
}

/// Check Claude Code login status
/// Returns LoginStatus enum based on 'claude auth status' output
pub fn checkLoginStatus(allocator: Allocator) !LoginStatus {
    // First check if Claude is installed
    if (!try checkInstallation(allocator)) {
        return .NotInstalled;
    }

    var ssh = railway_ssh.RailwaySSH.initDefault();
    const output = ssh.exec(allocator, "claude auth status") catch return .Unknown;
    defer allocator.free(output);

    const lower_output = try std.ascii.allocLowerString(allocator, output);
    defer allocator.free(lower_output);

    if (std.mem.indexOf(u8, lower_output, "logged in as")) |_| {
        return .LoggedIn;
    } else if (std.mem.indexOf(u8, lower_output, "not logged in")) |_| {
        return .LoggedOut;
    }

    return .Unknown;
}

/// Check if Claude Channels is supported
/// Returns true if --channels flag is available
pub fn probeChannelsSupport(allocator: Allocator) !bool {
    if (!try checkInstallation(allocator)) {
        return false;
    }

    var ssh = railway_ssh.RailwaySSH.initDefault();
    const output = ssh.exec(allocator, "claude --channels 2>&1 || true") catch return false;
    defer allocator.free(output);

    // Check if output indicates unknown flag or channels help
    const lower_output = try std.ascii.allocLowerString(allocator, output);
    defer allocator.free(lower_output);

    // If "unknown flag" or "invalid option", channels not supported
    if (std.mem.indexOf(u8, lower_output, "unknown")) |_| return false;
    if (std.mem.indexOf(u8, lower_output, "invalid")) |_| return false;
    if (std.mem.indexOf(u8, lower_output, "unrecognized")) |_| return false;

    // Assume supported if no error indicators
    return true;
}

/// Get environment variables related to Claude/Telegram
/// Returns owned stdout slice with matching variables
pub fn getEnvironmentVariables(allocator: Allocator, pattern: []const u8) ![]const u8 {
    var ssh = railway_ssh.RailwaySSH.initDefault();

    // Build env command with grep
    var cmd_buf: [256]u8 = undefined;
    const cmd = if (pattern.len == 0)
        "env | grep -E 'CLAUDE|TELEGRAM'"
    else
        std.fmt.bufPrint(&cmd_buf, "env | grep -E '{s}'", .{pattern}) catch
            return error.BufferOverflow;

    return ssh.exec(allocator, cmd);
}

/// Format LoginStatus for display
pub fn formatLoginStatus(status: LoginStatus) []const u8 {
    return switch (status) {
        .LoggedIn => "✓ Logged in",
        .LoggedOut => "✗ Not logged in",
        .NotInstalled => "✗ Claude not installed",
        .Unknown => "? Unknown status",
    };
}

/// Run Claude runtime command — dispatches to subcommands
pub fn runClaudeCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        return showClaudeHelp();
    }

    const subcommand = args[0];
    const sub_args = args[1..];

    if (std.mem.eql(u8, subcommand, "install") or std.mem.eql(u8, subcommand, "check")) {
        return runInstallCheck(allocator);
    } else if (std.mem.eql(u8, subcommand, "version") or std.mem.eql(u8, subcommand, "ver")) {
        return runVersionCheck(allocator);
    } else if (std.mem.eql(u8, subcommand, "login-status") or std.mem.eql(u8, subcommand, "status")) {
        return runLoginStatusCheck(allocator);
    } else if (std.mem.eql(u8, subcommand, "env")) {
        return runEnvCheck(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "help") or std.mem.eql(u8, subcommand, "-h") or std.mem.eql(u8, subcommand, "--help")) {
        return showClaudeHelp();
    } else {
        std.debug.print("{s}Unknown claude subcommand: {s}{s}\n", .{ RED, subcommand, RESET });
        return showClaudeHelp();
    }
}

fn showClaudeHelp() !void {
    std.debug.print(
        \\
        \\{s}CLAUDE RUNTIME COMMANDS:{s}
        \\
        \\  {s}tri railway claude install{s}     Check Claude installation
        \\  {s}tri railway claude version{s}     Show Claude version
        \\  {s}tri railway claude login-status{s} Check login status
        \\  {s}tri railway claude env{s}         Show environment variables
        \\
        \\{s}TELEGRAM CHANNELS:{s}
        \\  {s}tri railway telegram init{s}      Initialize Telegram bot
        \\  {s}tri railway telegram start{s}     Start Claude with Telegram
        \\  {s}tri railway telegram pair <code>{s} Complete pairing
        \\  {s}tri railway telegram status{s}    Show channel status
        \\  {s}tri railway telegram logs{s}      Show Claude logs
        \\  {s}tri railway telegram restart{s}   Restart Claude session
        \\  {s}tri railway telegram doctor{s}    Diagnose issues
        \\
    , .{ CYAN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, YELLOW, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, YELLOW, RESET });
}

fn runInstallCheck(allocator: Allocator) !void {
    std.debug.print("{s}Checking Claude Code installation...{s}\n", .{ CYAN, RESET });

    const installed = try checkInstallation(allocator);
    if (installed) {
        const version = getInstalledVersion(allocator) catch "unknown";
        defer allocator.free(version);

        const channels_supported = probeChannelsSupport(allocator) catch false;

        std.debug.print("{s}✓ Claude Code is installed{s}\n", .{ GREEN, RESET });
        std.debug.print("  Version: {s}\n", .{version});
        std.debug.print("  Channels: {s}\n", .{if (channels_supported) "✓ Supported" else "✗ Not supported"});
    } else {
        std.debug.print("{s}✗ Claude Code is not installed{s}\n", .{ RED, RESET });
        std.debug.print("  Install via: curl -fsSL https://claude.ai/install | sh\n", .{});
    }
}

fn runVersionCheck(allocator: Allocator) !void {
    const version = getInstalledVersion(allocator) catch {
        std.debug.print("{s}✗ Failed to get Claude version (not installed?){s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(version);

    std.debug.print("{s}Claude Code version: {s}{s}\n", .{ GREEN, version, RESET });

    // Check minimum version for Channels (2.1.80+)
    const min_version_str = "2.1.80";
    const meets_min = try compareVersions(allocator, version, min_version_str);
    if (!meets_min) {
        // Было `{m}` — недопустимый спецификатор для строки, компиляция падала.
        std.debug.print("{s}⚠ Channels requires Claude {s} or later{s}\n", .{ YELLOW, min_version_str, RESET });
    }
}

fn runLoginStatusCheck(allocator: Allocator) !void {
    std.debug.print("{s}Checking Claude login status...{s}\n", .{ CYAN, RESET });

    const status = try checkLoginStatus(allocator);
    const status_str = formatLoginStatus(status);
    const color = switch (status) {
        .LoggedIn => GREEN,
        .LoggedOut, .NotInstalled => RED,
        .Unknown => YELLOW,
    };

    std.debug.print("{s}{s}{s}\n", .{ color, status_str, RESET });

    if (status == .LoggedOut) {
        std.debug.print("  Login via: claude login\n", .{});
    }
}

fn runEnvCheck(allocator: Allocator, args: []const []const u8) !void {
    const pattern = if (args.len > 0) args[0] else "";
    const sep: u8 = if (pattern.len > 0) ' ' else ':';
    std.debug.print("{s}Environment variables{c}{s}\n", .{ CYAN, sep, pattern });

    const output = getEnvironmentVariables(allocator, pattern) catch {
        std.debug.print("{s}✗ Failed to fetch environment variables{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(output);

    if (output.len == 0) {
        std.debug.print("  No matching environment variables found\n", .{});
    } else {
        std.debug.print("{s}", .{output});
    }
}

/// Simple version comparison (major.minor.patch)
/// Returns true if v1 >= v2
pub fn compareVersions(allocator: Allocator, v1: []const u8, v2: []const u8) !bool {
    const v1_parts = try parseVersionParts(allocator, v1);
    defer allocator.free(v1_parts);

    const v2_parts = try parseVersionParts(allocator, v2);
    defer allocator.free(v2_parts);

    const min_len = @min(v1_parts.len, v2_parts.len);
    for (0..min_len) |i| {
        if (v1_parts[i] > v2_parts[i]) return true;
        if (v1_parts[i] < v2_parts[i]) return false;
    }

    // Equal up to min_len, longer version is newer
    return v1_parts.len >= v2_parts.len;
}

fn parseVersionParts(allocator: Allocator, version: []const u8) ![]u32 {
    var parts = std.ArrayList(u32).empty;
    defer parts.deinit(allocator);

    var iter = std.mem.splitScalar(u8, version, '.');
    while (iter.next()) |part| {
        const num = std.fmt.parseInt(u32, part, 10) catch continue;
        try parts.append(allocator, num);
    }

    return try parts.toOwnedSlice(allocator);
}

test "LoginStatus has all variants" {
    // Zig 0.15: @typeInfo enum field access
    const type_info = @typeInfo(LoginStatus);
    if (@typeInfo(LoginStatus) == .@"enum") {
        try std.testing.expectEqual(@as(usize, 4), type_info.@"enum".fields.len);
    } else {
        // Fallback for older Zig versions
        try std.testing.expect(true);
    }
}

test "formatLoginStatus returns valid strings" {
    const statuses = [_]LoginStatus{ .LoggedIn, .LoggedOut, .NotInstalled, .Unknown };
    for (statuses) |s| {
        const fmt = formatLoginStatus(s);
        try std.testing.expect(fmt.len > 0);
    }
}

test "parseVersionParts handles standard versions" {
    const allocator = std.testing.allocator;
    const parts = try parseVersionParts(allocator, "2.1.80");
    defer allocator.free(parts);

    try std.testing.expectEqual(@as(usize, 3), parts.len);
    try std.testing.expectEqual(@as(u32, 2), parts[0]);
    try std.testing.expectEqual(@as(u32, 1), parts[1]);
    try std.testing.expectEqual(@as(u32, 80), parts[2]);
}

test "compareVersions works correctly" {
    const allocator = std.testing.allocator;

    try std.testing.expect(try compareVersions(allocator, "2.1.80", "2.1.79"));
    try std.testing.expect(try compareVersions(allocator, "2.2.0", "2.1.80"));
    try std.testing.expect(try compareVersions(allocator, "3.0.0", "2.1.80"));
    try std.testing.expect(try compareVersions(allocator, "2.1.80", "2.1.80"));
    try std.testing.expect(!try compareVersions(allocator, "2.1.79", "2.1.80"));
}
