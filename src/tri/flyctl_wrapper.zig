// @origin(spec:flyctl_wrapper.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// FLYCTL WRAPPER — Zig wrapper for flyctl CLI
// ═══════════════════════════════════════════════════════════════════════════════
//
// Wraps flyctl commands with proper token authentication.
// Each account uses its own FLY_API_TOKEN_N env var.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const FlyResult = struct {
    stdout: []const u8,
    stderr: []const u8,
    exit_code: u32,

    pub fn success(self: *const FlyResult) bool {
        return self.exit_code == 0;
    }

    pub fn deinit(self: *const FlyResult, allocator: Allocator) void {
        allocator.free(self.stdout);
        allocator.free(self.stderr);
    }
};

/// Context for flyctl operations with specific token
pub const FlyContext = struct {
    allocator: Allocator,
    account_id: u8,
    token_suffix: [8]u8 = [_]u8{0} ** 8,
    token_suffix_len: usize = 0,

    pub fn init(allocator: Allocator, account_id: u8) FlyContext {
        var ctx = FlyContext{
            .allocator = allocator,
            .account_id = account_id,
        };

        // Build suffix for this account
        if (account_id == 1) {
            // No suffix for primary
        } else {
            const suffix = std.fmt.bufPrint(&ctx.token_suffix, "_{d}", .{account_id}) catch "";
            ctx.token_suffix_len = suffix.len;
        }

        return ctx;
    }
};

/// Run flyctl with given arguments
pub fn run(ctx: *const FlyContext, args: []const []const u8) !FlyResult {
    // Get env map and set token inline
    var env = try std.process.getEnvMap(ctx.allocator);
    defer env.deinit();

    // Set correct FLY_API_TOKEN for this account
    var key_buf: [32]u8 = undefined;
    const key = if (ctx.token_suffix_len == 0)
        "FLY_API_TOKEN"
    else blk: {
        @memcpy(key_buf[0..13], "FLY_API_TOKEN");
        @memcpy(key_buf[13 .. 13 + ctx.token_suffix_len], ctx.token_suffix[0..ctx.token_suffix_len]);
        break :blk key_buf[0 .. 13 + ctx.token_suffix_len];
    };

    const token = try std.process.getEnvVarOwned(ctx.allocator, key);
    defer ctx.allocator.free(token);

    try env.put("FLY_API_TOKEN", token);

    var argv = try ctx.allocator.alloc([]const u8, args.len + 1);
    defer ctx.allocator.free(argv);
    argv[0] = "flyctl";
    @memcpy(argv[1..], args);

    const result = std.process.Child.run(.{
        .allocator = ctx.allocator,
        .argv = argv,
        .env_map = &env,
    }) catch {
        return error.RunFailed;
    };

    return .{
        .stdout = result.stdout,
        .stderr = result.stderr,
        .exit_code = switch (result.term) {
            .Exited => |code| code,
            else => 1,
        },
    };
}

/// Create a new Fly.io app
pub fn createApp(ctx: *const FlyContext, app_name: []const u8, org: ?[]const u8, region: []const u8) !FlyResult {
    var args = std.ArrayList([]const u8).init(ctx.allocator);
    defer args.deinit();

    try args.appendSlice(&[_][]const u8{ "apps", "create", "--name", app_name });

    if (org) |o| {
        try args.appendSlice(&[_][]const u8{ "--org", o });
    }

    try args.appendSlice(&[_][]const u8{ "--regions", region, "--yes" });

    return run(ctx, args.items);
}

/// Deploy an app
pub fn deploy(ctx: *const FlyContext, app_name: []const u8, config_file: []const u8) !FlyResult {
    const args = &[_][]const u8{ "deploy", "--config", config_file, "--app", app_name };
    return run(ctx, args);
}

/// Set secrets for an app
pub fn setSecrets(ctx: *const FlyContext, app_name: []const u8, secrets: []const []const u8) !FlyResult {
    var args = std.ArrayList([]const u8).init(ctx.allocator);
    defer args.deinit();

    try args.append("secrets");
    try args.append("--app");
    try args.append(app_name);
    try args.appendSlice(secrets);

    return run(ctx, args);
}

/// Get app info (JSON format)
pub fn getAppInfo(ctx: *const FlyContext, app_name: []const u8) !FlyResult {
    const args = &[_][]const u8{ "info", "--app", app_name, "--json" };
    return run(ctx, args);
}

/// List all apps (JSON format)
pub fn listApps(ctx: *const FlyContext) !FlyResult {
    const args = &[_][]const u8{ "apps", "list", "--json" };
    return run(ctx, args);
}

/// Get app status
pub fn getAppStatus(ctx: *const FlyContext, app_name: []const u8) !FlyResult {
    const args = &[_][]const u8{ "status", "--app", app_name, "--json" };
    return run(ctx, args);
}

/// Scale app (set VM size)
pub fn scaleApp(ctx: *const FlyContext, app_name: []const u8, cpus: u8, memory_mb: u16) !FlyResult {
    const mem_str = try std.fmt.allocPrint(ctx.allocator, "{d}mb", .{memory_mb});
    defer ctx.allocator.free(mem_str);

    const cpus_str = try std.fmt.allocPrint(ctx.allocator, "shared-cpu-{d}x", .{cpus});
    defer ctx.allocator.free(cpus_str);

    const args = &[_][]const u8{ "scale", "vm", "--app", app_name, cpus_str, mem_str };
    return run(ctx, args);
}

/// Stop app
pub fn stopApp(ctx: *const FlyContext, app_name: []const u8) !FlyResult {
    const args = &[_][]const u8{ "apps", "stop", "--app", app_name };
    return run(ctx, args);
}

/// Delete app
pub fn deleteApp(ctx: *const FlyContext, app_name: []const u8) !FlyResult {
    const args = &[_][]const u8{ "apps", "destroy", "--app", app_name, "--yes" };
    return run(ctx, args);
}

/// Restart app
pub fn restartApp(ctx: *const FlyContext, app_name: []const u8) !FlyResult {
    const args = &[_][]const u8{ "apps", "restart", "--app", app_name };
    return run(ctx, args);
}

/// Check if flyctl is installed and working
pub fn checkPrerequisites(allocator: Allocator) !void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "flyctl", "--version" },
    }) catch {
        std.debug.print("Error: flyctl not found. Install from: https://fly.io/docs/hands-on/install/\n", .{});
        return error.FlyctlNotInstalled;
    };
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.term != .Exited or result.term.Exited != 0) {
        return error.FlyctlNotInstalled;
    }
}

/// Verify token is valid
pub fn verifyToken(allocator: Allocator, token: []const u8) !void {
    // Temporarily set token and verify
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    try env.put("FLY_API_TOKEN", token);

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "flyctl", "auth", "token" },
        .env_map = &env,
    }) catch {
        return error.TokenInvalid;
    };
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.term != .Exited or result.term.Exited != 0) {
        return error.TokenInvalid;
    }

    const token_check = std.mem.trim(u8, result.stdout, &std.ascii.whitespace);
    if (token_check.len == 0) {
        return error.TokenInvalid;
    }
}
