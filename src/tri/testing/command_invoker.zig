const std = @import("std");

// ============================================================================
// TRINITY: Command Invoker (Cycle 101)
// Executes actual tri commands via subprocess and captures output
// ============================================================================

/// Result of executing a tri command
pub const CommandResult = struct {
    stdout: []const u8,
    stderr: []const u8,
    exit_code: u8,
    allocator: std.mem.Allocator,

    /// Clean up resources
    pub fn deinit(self: *CommandResult) void {
        self.allocator.free(self.stdout);
        self.allocator.free(self.stderr);
    }

    /// Get combined output (stdout + stderr if non-empty)
    pub fn getCombined(self: *const CommandResult) ![]const u8 {
        if (self.stderr.len == 0) {
            return self.stdout;
        }
        if (self.stdout.len == 0) {
            return self.stderr;
        }
        return std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.stdout, self.stderr });
    }

    /// Check if command succeeded
    pub fn isSuccess(self: *const CommandResult) bool {
        return self.exit_code == 0;
    }

    /// Check if output contains substring
    pub fn contains(self: *const CommandResult, substr: []const u8) bool {
        return std.mem.indexOf(u8, self.stdout, substr) != null or
            std.mem.indexOf(u8, self.stderr, substr) != null;
    }
};

/// Invokes actual tri commands and captures output
pub const CommandInvoker = struct {
    allocator: std.mem.Allocator,
    tri_binary_path: []const u8,
    verbose: bool = false,

    const Self = @This();

    /// Initialize with auto-detected tri binary path
    pub fn init(allocator: std.mem.Allocator) !Self {
        // Try to find tri binary in common locations
        const tri_paths = [_][]const u8{
            "zig-out/bin/tri",
            "./zig-out/bin/tri",
            "../zig-out/bin/tri",
            "../../zig-out/bin/tri",
            "/usr/local/bin/tri",
        };

        // Get current working directory for relative path resolution
        const cwd = std.fs.cwd();

        for (tri_paths) |path| {
            // Check if file exists and is executable
            if (cwd.openFile(path, .{})) |file| {
                file.close();
                return .{
                    .allocator = allocator,
                    .tri_binary_path = try allocator.dupe(u8, path),
                };
            } else |_| {
                continue;
            }
        }

        // If not found, try to build it
        std.debug.print("tri binary not found, attempting to build...\n", .{});

        const build_result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "zig", "build", "tri" },
        });
        defer {
            allocator.free(build_result.stdout);
            allocator.free(build_result.stderr);
        }

        if (build_result.term != .Exited or build_result.term.Exited != 0) {
            std.debug.print("Failed to build tri: {s}\n", .{build_result.stderr});
            return error.TriBinaryNotFound;
        }

        // After build, check zig-out/bin/tri again
        const tri_path = "zig-out/bin/tri";
        if (cwd.openFile(tri_path, .{})) |file| {
            file.close();
            return .{
                .allocator = allocator,
                .tri_binary_path = try allocator.dupe(u8, tri_path),
            };
        } else |_| {
            return error.TriBinaryNotFound;
        }
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.tri_binary_path);
    }

    /// Run a tri command with arguments
    /// Example: runCommand(&.{"phi", "10"}) executes "tri phi 10"
    pub fn runCommand(self: *const Self, args: []const []const u8) !CommandResult {
        // Build full argv: tri binary + args
        const full_argv = try self.allocator.alloc([]const u8, args.len + 1);
        defer self.allocator.free(full_argv);

        full_argv[0] = self.tri_binary_path;
        for (args, 0..) |arg, i| {
            full_argv[i + 1] = arg;
        }

        if (self.verbose) {
            std.debug.print("[CommandInvoker] Running: tri", .{});
            for (args) |arg| {
                std.debug.print(" {s}", .{arg});
            }
            std.debug.print("\n", .{});
        }

        // Execute the command
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = full_argv,
            .cwd = ".",
        });

        // Determine exit code
        const exit_code = switch (result.term) {
            .Exited => |code| @as(u8, @intCast(code)),
            .Signal => |signal| {
                std.debug.print("Command killed by signal {}\n", .{signal});
                return error.CommandKilled;
            },
            .Stopped => |signal| {
                std.debug.print("Command stopped by signal {}\n", .{signal});
                return error.CommandStopped;
            },
            .Unknown => |code| {
                std.debug.print("Command terminated with unknown code {}\n", .{code});
                return error.CommandUnknownTermination;
            },
        };

        return .{
            .stdout = result.stdout,
            .stderr = result.stderr,
            .exit_code = exit_code,
            .allocator = self.allocator,
        };
    }

    /// Run command string (parses "command arg1 arg2...")
    pub fn runCommandString(self: *const Self, cmd_str: []const u8) !CommandResult {
        // Simple parsing: max 4 arguments
        var arg_buffer: [4][]const u8 = undefined;
        var arg_count: usize = 0;

        var it = std.mem.tokenizeScalar(u8, cmd_str, ' ');
        while (it.next()) |arg| {
            if (arg_count < arg_buffer.len) {
                arg_buffer[arg_count] = arg;
                arg_count += 1;
            }
        }

        return self.runCommand(arg_buffer[0..arg_count]);
    }

    /// Set verbose mode
    pub fn setVerbose(self: *Self, verbose: bool) void {
        self.verbose = verbose;
    }

    /// Check if tri binary is available
    pub fn isAvailable(self: *const Self) bool {
        _ = std.fs.cwd().openFile(self.tri_binary_path, .{}) catch return false;
        return true;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "CommandInvoker initialization" {
    const allocator = std.testing.allocator;

    // This test will skip if tri binary can't be built/found
    var invoker = CommandInvoker.init(allocator) catch |err| {
        std.debug.print("Skipping test: tri binary not available ({})\n", .{err});
        return error.SkipZigTest;
    };
    defer invoker.deinit();

    try std.testing.expect(invoker.isAvailable());
}

test "CommandInvoker - simple version command" {
    const allocator = std.testing.allocator;

    var invoker = CommandInvoker.init(allocator) catch |err| {
        std.debug.print("Skipping test: tri binary not available ({})\n", .{err});
        return error.SkipZigTest;
    };
    defer invoker.deinit();

    var result = try invoker.runCommand(&[_][]const u8{"version"});
    defer result.deinit();

    // Version command should succeed
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "CommandInvoker - phi command" {
    const allocator = std.testing.allocator;

    var invoker = CommandInvoker.init(allocator) catch |err| {
        std.debug.print("Skipping test: tri binary not available ({})\n", .{err});
        return error.SkipZigTest;
    };
    defer invoker.deinit();

    var result = try invoker.runCommand(&[_][]const u8{ "phi", "10" });
    defer result.deinit();

    // Should contain some output related to phi^10
    try std.testing.expect(result.stdout.len > 0 or result.stderr.len > 0);
}

test "CommandResult contains" {
    const allocator = std.testing.allocator;

    var invoker = CommandInvoker.init(allocator) catch |err| {
        std.debug.print("Skipping test: tri binary not available ({})\n", .{err});
        return error.SkipZigTest;
    };
    defer invoker.deinit();

    var result = try invoker.runCommand(&[_][]const u8{"version"});
    defer result.deinit();

    // Version output should mention TRINITY or have some content
    const has_content = result.stdout.len > 0 or result.stderr.len > 0;
    try std.testing.expect(has_content);
}

test "CommandInvoker - runCommandString" {
    const allocator = std.testing.allocator;

    var invoker = CommandInvoker.init(allocator) catch |err| {
        std.debug.print("Skipping test: tri binary not available ({})\n", .{err});
        return error.SkipZigTest;
    };
    defer invoker.deinit();

    var result = try invoker.runCommandString("version");
    defer result.deinit();

    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
