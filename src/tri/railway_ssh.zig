// @origin(spec:railway_ssh.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// RAILWAY SSH — Remote Command Execution via SSH
// ═══════════════════════════════════════════════════════════════════════════════
//
// Wraps std.process.Child to execute commands on Railway cloud server.
// Connection: interchange.proxy.rlwy.net:34920
// Disables ssh-agent (SSH_AUTH_SOCK="") to avoid "Too many authentication failures".
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const RESET = "\x1b[0m";
const RED = "\x1b[31m";

pub const SSHError = error{
    SSHExecFailed,
    SSHCommandFailed,
    BufferOverflow,
    OutOfMemory,
};

pub const RailwaySSH = struct {
    host: []const u8,
    port: u16,
    user: []const u8,
    key_path: []const u8,

    const Self = @This();

    /// Default Railway SSH connection from SKILL.md.
    pub fn initDefault() RailwaySSH {
        return .{
            .host = "interchange.proxy.rlwy.net",
            .port = 34920,
            .user = "user",
            .key_path = "~/.ssh/id_ed25519",
        };
    }

    /// Execute a command on the Railway server via SSH.
    /// Uses: SSH_AUTH_SOCK="" ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=no ...
    /// Returns stdout on success. Caller owns returned memory.
    pub fn exec(self: *const Self, allocator: Allocator, command: []const u8) ![]const u8 {
        var port_buf: [8]u8 = undefined;
        const port_str = std.fmt.bufPrint(&port_buf, "{d}", .{self.port}) catch return error.BufferOverflow;

        const target = try std.fmt.allocPrint(allocator, "{s}@{s}", .{ self.user, self.host });
        defer allocator.free(target);

        // We use env to clear SSH_AUTH_SOCK and then call ssh
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{
                "env",
                "SSH_AUTH_SOCK=",
                "ssh",
                "-o",
                "IdentitiesOnly=yes",
                "-o",
                "StrictHostKeyChecking=no",
                "-o",
                "ConnectTimeout=30",
                "-i",
                self.key_path,
                target,
                "-p",
                port_str,
                command,
            },
            .max_output_bytes = 1 * 1024 * 1024,
        }) catch return error.SSHExecFailed;
        defer allocator.free(result.stderr);

        const ssh_exit = switch (result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        };
        if (ssh_exit != 0) {
            if (result.stderr.len > 0) {
                std.debug.print("{s}SSH error (exit {d}): {s}{s}\n", .{ RED, ssh_exit, result.stderr, RESET });
            }
            allocator.free(result.stdout);
            return error.SSHCommandFailed;
        }

        return result.stdout;
    }

    /// Execute with retry and exponential backoff (1s, 2s, 4s).
    pub fn execWithRetry(self: *const Self, allocator: Allocator, command: []const u8) ![]const u8 {
        var attempt: u8 = 0;
        while (attempt < 3) : (attempt += 1) {
            return self.exec(allocator, command) catch |err| {
                if (attempt == 2) return err;
                std.debug.print("SSH attempt {d}/3 failed: {}, retrying...\n", .{ attempt + 1, err });
                std.Thread.sleep(std.time.ns_per_s * (@as(u64, 1) << @intCast(attempt)));
                continue;
            };
        }
        return error.SSHExecFailed;
    }

    /// Capture tmux pane output from a remote session.
    pub fn tmuxCapture(self: *const Self, allocator: Allocator, session: []const u8, lines: u32) ![]const u8 {
        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "tmux capture-pane -t {s} -p -S -{d}", .{ session, lines }) catch
            return error.BufferOverflow;
        return self.exec(allocator, cmd);
    }

    /// Send keys to a remote tmux session.
    pub fn tmuxSendKeys(self: *const Self, allocator: Allocator, session: []const u8, keys: []const u8) !void {
        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "tmux send-keys -t {s} '{s}' C-m", .{ session, keys }) catch
            return error.BufferOverflow;
        const output = try self.exec(allocator, cmd);
        allocator.free(output);
    }

    /// Create a new detached tmux session running a command.
    pub fn tmuxNewSession(self: *const Self, allocator: Allocator, session: []const u8, command: []const u8) !void {
        var cmd_buf: [1024]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "tmux kill-session -t {s} 2>/dev/null; tmux new-session -d -s {s} '{s}'", .{
            session, session, command,
        }) catch return error.BufferOverflow;
        const output = try self.exec(allocator, cmd);
        allocator.free(output);
    }

    /// Get server status (tmux sessions, git branch, oracle status).
    pub fn getStatus(self: *const Self, allocator: Allocator) ![]const u8 {
        return self.exec(allocator,
            \\echo "=== TMUX ==="; tmux list-sessions 2>/dev/null; echo "=== BRANCH ==="; cd /data/trinity && git branch --show-current; echo "=== HEAD ==="; git log --oneline -3; echo "=== ORACLE ==="; tmux list-panes -t oracle 2>/dev/null || echo "not running"
        );
    }

    /// Pull latest code on Railway.
    pub fn pullCode(self: *const Self, allocator: Allocator) ![]const u8 {
        return self.exec(allocator,
            \\cd /data/trinity && git fetch origin && git pull --ff-only && echo "---DONE---"
        );
    }
};

test "RailwaySSH initDefault" {
    const ssh = RailwaySSH.initDefault();
    try std.testing.expectEqual(@as(u16, 34920), ssh.port);
    try std.testing.expectEqualStrings("interchange.proxy.rlwy.net", ssh.host);
    try std.testing.expectEqualStrings("user", ssh.user);
}

test "SSHError has error values" {
    try std.testing.expectError(error.SSHExecFailed);
    try std.testing.expectError(error.SSHCommandFailed);
}

test "RailwaySSH struct size" {
    try std.testing.expectEqual(@sizeOf([3]u8), @sizeOf(RailwaySSH));
}
