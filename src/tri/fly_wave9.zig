// @origin(spec:fly_wave9.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// FLY WAVE 9 — S3 MultiObj Training Deployment
// ═══════════════════════════════════════════════════════════════════════════════
//
// Deploy 48 HSLM training services across 4 Fly.io accounts (12 per account).
// All services use S3 MultiObj configuration:
//   - HSLM_PROFILE = s3-multiobj
//   - HSLM_CTX = 81
//   - HSLM_NTP_WEIGHT = 0.50
//   - HSLM_JEPA_WEIGHT = 0.25
//   - HSLM_NCA_WEIGHT = 0.25
//   - HSLM_CRASH_TOLERANCE = 0.05
//   - HSLM_WAVE = 9
//
// App naming: hslm-w9-N (N = 1..48)
// Account distribution:
//   FLY_API_TOKEN_1:  hslm-w9-1   through hslm-w9-12
//   FLY_API_TOKEN_2:  hslm-w9-13  through hslm-w9-24
//   FLY_API_TOKEN_3:  hslm-w9-25  through hslm-w9-36
//   FLY_API_TOKEN_4:  hslm-w9-37  through hslm-w9-48
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const fly_farm = @import("fly_farm.zig");
const flyctl = @import("flyctl_wrapper.zig");

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";

const TOTAL_SERVICES: usize = 48;
const SERVICES_PER_ACCOUNT: usize = 12;
const ACCOUNT_COUNT: usize = 4;

pub const Wave9Config = struct {
    profile: []const u8 = "s3-multiobj",
    ctx: []const u8 = "81",
    ntp_weight: []const u8 = "0.50",
    jepa_weight: []const u8 = "0.25",
    nca_weight: []const u8 = "0.25",
    crash_tolerance: []const u8 = "0.05",
    wave: []const u8 = "9",
    lr: []const u8 = "1e-3",
    lr_schedule: []const u8 = "cosine",
    optimizer: []const u8 = "lamb",
    batch: []const u8 = "66",
    steps: []const u8 = "100000",
    warmup: []const u8 = "2000",
    wd: []const u8 = "0.01",
    grad_clip: []const u8 = "1.0",
    fresh: []const u8 = "0",
    seed_start: u32 = 901, // Wave 9 seed range
    region: []const u8 = "iad", // Virginia (US East)

    /// Build S3 MultiObj secrets array
    pub fn getSecrets(self: *const Wave9Config, allocator: Allocator, seed: u32) ![][]const u8 {
        const seed_str = try std.fmt.allocPrint(allocator, "{d}", .{seed});
        defer allocator.free(seed_str);

        // Build secrets list
        var secrets = std.ArrayList([]const u8).initCapacity(allocator, 20);
        defer secrets.deinit();

        try secrets.appendSlice(&[_][]const u8{
            "HSLM_PROFILE=",
            "HSLM_CTX=",
            "HSLM_NTP_WEIGHT=",
            "HSLM_JEPA_WEIGHT=",
            "HSLM_NCA_WEIGHT=",
            "HSLM_CRASH_TOLERANCE=",
            "HSLM_WAVE=",
            "HSLM_LR=",
            "HSLM_LR_SCHEDULE=",
            "HSLM_OPTIMIZER=",
            "HSLM_BATCH=",
            "HSLM_STEPS=",
            "HSLM_WARMUP=",
            "HSLM_WD=",
            "HSLM_GRAD_CLIP=",
            "HSLM_FRESH=",
            "HSLM_SEED=",
        });

        try secrets.appendSlice(&[_][]const u8{ self.profile });
        try secrets.appendSlice(&[_][]const u8{ self.ctx });
        try secrets.appendSlice(&[_][]const u8{ self.ntp_weight });
        try secrets.appendSlice(&[_][]const u8{ self.jepa_weight });
        try secrets.appendSlice(&[_][]const u8{ self.nca_weight });
        try secrets.appendSlice(&[_][]const u8{ self.crash_tolerance });
        try secrets.appendSlice(&[_][]const u8{ self.wave });
        try secrets.appendSlice(&[_][]const u8{ self.lr });
        try secrets.appendSlice(&[_][]const u8{ self.lr_schedule });
        try secrets.appendSlice(&[_][]const u8{ self.optimizer });
        try secrets.appendSlice(&[_][]const u8{ self.batch });
        try secrets.appendSlice(&[_][]const u8{ self.steps });
        try secrets.appendSlice(&[_][]const u8{ self.warmup });
        try secrets.appendSlice(&[_][]const u8{ self.wd });
        try secrets.appendSlice(&[_][]const u8{ self.grad_clip });
        try secrets.appendSlice(&[_][]const u8{ self.fresh });
        try secrets.appendSlice(&[_][]const u8{ seed_str });

        return secrets.toOwnedSlice();
    }
};

/// Deploy Wave 9 to Fly.io
pub fn deployWave9(allocator: Allocator, args: []const []const u8) !void {
    var dry_run = false;
    var skip_existing = false;
    var seed_start: u32 = 901;
    var region: []const u8 = "iad";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--dry-run")) {
            dry_run = true;
        } else if (std.mem.eql(u8, arg, "--skip-existing")) {
            skip_existing = true;
        } else if (std.mem.eql(u8, arg, "--seed-start") and i + 1 < args.len) {
            i += 1;
            seed_start = std.fmt.parseInt(u32, args[i], 10) catch 901;
        } else if (std.mem.eql(u8, arg, "--region") and i + 1 < args.len) {
            i += 1;
            region = args[i];
        }
    }

    print("\n{s}🌊 WAVE 9 — FLY.IO FARM DEPLOYMENT{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Target: {d} services across {d} Fly.io accounts\n", .{ TOTAL_SERVICES, ACCOUNT_COUNT });
    print("  Profile: S3 MultiObj (NTP 50%, JEPA 25%, NCA 25%)\n", .{});
    print("  Config: ctx={s} lr={s} opt={s} batch={s}\n", .{ "81", "1e-3", "lamb", "66" });
    print("  Region: {s}\n", .{region});
    print("  Seed start: {d}\n", .{seed_start});
    if (dry_run) print("  {s}DRY RUN — no actual deployments{s}\n", .{ YELLOW, RESET });
    print("\n", .{});

    // Check flyctl
    try flyctl.checkPrerequisites(allocator);

    // Initialize farm
    var farm = fly_farm.FlyFarm.init();
    const capacity = farm.totalCapacity();

    print("{s}Farm Capacity:{s}\n", .{ BOLD, RESET });
    print("  Accounts: {d}/{d}\n", .{ farm.account_count, ACCOUNT_COUNT });
    print("  Total slots: {d}\n", .{capacity.total_slots});
    print("  Active apps: {d}\n", .{capacity.total_active});
    print("\n", .{});

    if (farm.account_count < ACCOUNT_COUNT) {
        print("{s}⚠️  Only {d} accounts found, need {d}{s}\n", .{ YELLOW, farm.account_count, ACCOUNT_COUNT, RESET });
        print("   Set FLY_API_TOKEN_1 through FLY_API_TOKEN_4 in .env\n", .{});
    }

    var deployed: usize = 0;
    var skipped: usize = 0;
    var errors: usize = 0;
    var seed_counter: u32 = seed_start;

    // Deploy services across accounts
    var acct_idx: usize = 1;
    while (acct_idx <= ACCOUNT_COUNT) : (acct_idx += 1) {
        const start_idx = (acct_idx - 1) * SERVICES_PER_ACCOUNT + 1;
        const end_idx = start_idx + SERVICES_PER_ACCOUNT;

        const account_name = try std.fmt.allocPrint(allocator, "fly-acct-{d}", .{acct_idx});
        defer allocator.free(account_name);

        print("{s}=== {s} (apps {d}-{d}) ==={s}\n", .{ BOLD, account_name, start_idx, end_idx - 1, RESET });

        // Get existing apps for this account
        var ctx = flyctl.FlyContext.init(allocator, @intCast(acct_idx));
        const list_result = try flyctl.listApps(&ctx);
        defer list_result.deinit(allocator);

        var existing_apps = std.StringHashMap(void).init(allocator);
        defer existing_apps.deinit();

        if (list_result.success()) {
            // Parse JSON to extract app names
            const options = std.json.ParseOptions{
                .ignore_unknown_fields = true,
                .allow_comments = true,
                .allow_trailing_commas = true,
                .allow_inf = true,
                .allow_nan = true,
                .allow_float = false,
                .allow_control_characters_in_strings = false,
                .allocate = .alloc_always,
                .max_value_len = std.json.default_max_value_len,
                .duplicate_field_behavior = .error,
                .error_on_trailing_comma = false,
                .error_on_duplicate_keys = false,
                .error_on_duplicate_object_field_names = false,
                .rejection_error_handling_mode = .return_all_errors,
                .error_on_missing_explicit_type = false,
                .rejection_error_handling_mode = .return_all_errors,
                .rejection_error_handling_mode = .return_all_errors,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_handling_mode = .init,
                .rejection_error_error_handling_mode = .init,
                .parsing_mode = .strict,
                .match_floats = false,
            };
            const parsed = std.json.parseFromSlice(std.json.Value, allocator, list_result.stdout, options) catch {
            defer if (parsed) |*p| p.deinit();

            if (parsed) |*p| {
                if (p == .array) {
                    for (p.array.items) |app_val| {
                        if (app_val != .object) continue;
                        if (app_val.object.get("Name")) |name| {
                            if (name == .string) {
                                try existing_apps.put(allocator.dupe(u8, name.string), {});
                            }
                        }
                    }
                }
            }
        }

        var svc_idx: usize = start_idx;
        while (svc_idx < end_idx) : (svc_idx += 1) {
            const app_name = try std.fmt.allocPrint(allocator, "hslm-w9-{d}", .{svc_idx});
            defer allocator.free(app_name);

            const already_exists = existing_apps.contains(app_name);

            if (skip_existing and already_exists) {
                print("  {s}⏭️  {s}: already exists (skip){s}\n", .{ YELLOW, app_name, RESET });
                skipped += 1;
                continue;
            }

            if (dry_run) {
                print("  {s}[DRY] Would deploy {s} (seed={d}){s}\n", .{ CYAN, app_name, seed_counter, RESET });
                deployed += 1;
                seed_counter += 1;
                continue;
            }

            // Get account reference
            var acct_ref: ?*fly_farm.FlyAccount = null;
            for (farm.accounts[0..farm.account_count]) |*a| {
                if (a.id == @as(u8, @intCast(acct_idx))) {
                    acct_ref = a;
                    break;
                }
            }

            if (acct_ref == null or !acct_ref.?.canSpawn()) {
                print("  {s}⚠️  {s}: no available slots (skip){s}\n", .{ YELLOW, app_name, RESET });
                errors += 1;
                continue;
            }

            // Deploy this app
            const deploy_result = deployApp(allocator, &ctx, app_name, seed_counter, region) catch |err| {
                print("  {s}❌ {s}: {s}{s}\n", .{ RED, app_name, @errorName(err), RESET });
                errors += 1;
                seed_counter += 1;
                continue;
            };

            if (deploy_result) |*r| {
                if (r.success()) {
                    print("  {s}✅ {s}{s}: seed={d} → DEPLOYING\n", .{ GREEN, app_name, RESET, seed_counter });
                    farm.recordApp(app_name, @intCast(acct_idx));
                    farm.incrementAppCount(@intCast(acct_idx));
                    deployed += 1;
                } else {
                    print("  {s}❌ {s}: {s}{s}\n", .{ RED, app_name, r.stderr, RESET });
                    errors += 1;
                }
                r.deinit(allocator);
            }

            seed_counter += 1;

            // Small delay between deployments
            std.Thread.sleep(1_000_000_000); // 1 second
        }
        print("\n", .{});
    }

    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}WAVE 9 DONE: ✅ {d} deployed | ⏭️ {d} skipped | ❌ {d} errors{s}\n", .{
        BOLD, deployed, skipped, errors, RESET,
    });
    print("\n", .{});
}

fn deployApp(allocator: Allocator, ctx: *const flyctl.FlyContext, app_name: []const u8, seed: u32, region: []const u8) !?flyctl.FlyResult {
    const config = Wave9Config{};
    const secrets = try config.getSecrets(allocator, seed);
    defer {
        for (secrets) |s| allocator.free(s);
        allocator.free(secrets);
    }

    // Create app (may fail if already exists)
    var create_result = try flyctl.createApp(ctx, app_name, null, region);
    defer create_result.deinit(allocator);

    if (!create_result.success()) {
        // Check if app already exists (likely "Error the app name is already taken")
        if (std.mem.indexOf(u8, create_result.stderr, "already taken") != null or
            std.mem.indexOf(u8, create_result.stderr, "already exists") != null)
        {
            // App exists, set secrets and deploy
            const secrets_result = try flyctl.setSecrets(ctx, app_name, secrets);
            defer secrets_result.deinit(allocator);

            if (!secrets_result.success()) {
                return secrets_result;
            }

            const deploy_result = try flyctl.deploy(ctx, app_name, "fly.train.toml");
            return deploy_result;
        }
        return create_result;
    }

    // App created successfully, now set secrets and deploy
    const secrets_result = try flyctl.setSecrets(ctx, app_name, secrets);
    defer secrets_result.deinit(allocator);

    if (!secrets_result.success()) {
        return secrets_result;
    }

    // Set VM size
    const scale_result = try flyctl.scaleApp(ctx, app_name, 2, 4096);
    defer scale_result.deinit(allocator);

    if (!scale_result.success()) {
        // Scale may fail initially, but continue with deploy
    }

    const deploy_result = try flyctl.deploy(ctx, app_name, "fly.train.toml");
    return deploy_result;
}

/// Show status of all Wave 9 apps
pub fn showWave9Status(allocator: Allocator) !void {
    print("\n{s}WAVE 9 -- STATUS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    try flyctl.checkPrerequisites(allocator);

    var farm = fly_farm.FlyFarm.init();
    var total_apps: usize = 0;
    var running: usize = 0;
    var stopped: usize = 0;
    var failed: usize = 0;

    for (farm.accounts[0..farm.account_count]) |*acct| {
        print("{s}=== {s} ==={s}\n", .{ BOLD, acct.getAlias(), RESET });

        var ctx = flyctl.FlyContext.init(allocator, acct.id);
        const list_result = try flyctl.listApps(&ctx);
        defer list_result.deinit(allocator);

        if (!list_result.success()) {
            print("  {s}⚠️  API error: {s}{s}\n\n", .{ RED, @errorName(error.ApiError), RESET });
            continue;
        }

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, list_result.stdout, .{}) catch {
            print("  {s}⚠️  Invalid JSON{s}\n\n", .{ RED, RESET });
            continue;
        };
        defer parsed.deinit();

        if (parsed.value != .array) continue;

        var wave9_count: usize = 0;

        for (parsed.value.array.items) |app_val| {
            if (app_val != .object) continue;

            const name = if (app_val.object.get("Name")) |n| blk: {
                if (n == .string) break :blk n.string else break :blk "";
            } else "";

            // Only show Wave 9 apps (hslm-w9-*)
            if (!std.mem.startsWith(u8, name, "hslm-w9-")) continue;

            wave9_count += 1;

            const status = if (app_val.object.get("Status")) |s| blk: {
                if (s == .string) break :blk s.string else break :blk "?";
            } else "?";

            // Parse status and count
            if (std.mem.eql(u8, status, "running")) {
                running += 1;
                print("  {s}🟢 {s}{s}\n", .{ GREEN, name, RESET });
            } else if (std.mem.eql(u8, status, "stopped")) {
                stopped += 1;
                print("  {s}⏸️  {s}{s}\n", .{ YELLOW, name, RESET });
            } else if (std.mem.eql(u8, status, "failed")) {
                failed += 1;
                print("  {s}🔴 {s}{s}\n", .{ RED, name, RESET });
            } else {
                print("  {s}🔵 {s}: {s}{s}\n", .{ DIM, name, status, RESET });
            }
        }

        total_apps += wave9_count;
        print("  Wave 9 apps: {d}\n\n", .{wave9_count});
    }

    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}TOTAL: {d} Wave 9 apps | 🟢 {d} running | ⏸️ {d} stopped | 🔴 {d} failed{s}\n\n", .{
        BOLD, total_apps, running, stopped, failed, RESET,
    });
}

/// Recycle crashed Wave 9 apps
pub fn recycleWave9(allocator: Allocator, args: []const []const u8) !void {
    var dry_run = false;
    var new_seed_start: u32 = 1001; // New seed range for recycled apps

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--dry-run")) {
            dry_run = true;
        } else if (std.mem.eql(u8, arg, "--seed-start") and i + 1 < args.len) {
            i += 1;
            new_seed_start = std.fmt.parseInt(u32, args[i], 10) catch 1001;
        }
    }

    print("\n{s}🔄 WAVE 9 RECYCLE{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Finding crashed/stopped Wave 9 apps...\n", .{});
    if (dry_run) print("  {s}DRY RUN — no actual operations{s}\n", .{ YELLOW, RESET });
    print("\n", .{});

    try flyctl.checkPrerequisites(allocator);

    var farm = fly_farm.FlyFarm.init();
    var restarted: usize = 0;
    var skipped: usize = 0;
    var seed_counter: u32 = new_seed_start;
    var total_crashed: usize = 0;

    for (farm.accounts[0..farm.account_count]) |*acct| {
        var ctx = flyctl.FlyContext.init(allocator, acct.id);
        const list_result = try flyctl.listApps(&ctx);
        defer list_result.deinit(allocator);

        if (!list_result.success()) continue;

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, list_result.stdout, .&.{}) catch continue;
        defer parsed.deinit();

        if (parsed.value != .array) continue;

        for (parsed.value.array.items) |app_val| {
            if (app_val != .object) continue;

            const name = if (app_val.object.get("Name")) |n| blk: {
                if (n == .string) break :blk n.string else break :blk "";
            } else "";

            if (!std.mem.startsWith(u8, name, "hslm-w9-")) continue;

            const status = if (app_val.object.get("Status")) |s| blk: {
                if (s == .string) break :blk s.string else break :blk "?";
            } else "?";

            const is_crashed = std.mem.eql(u8, status, "stopped") or
                std.mem.eql(u8, status, "failed") or
                std.mem.eql(u8, status, "pending");

            if (is_crashed) {
                total_crashed += 1;
                print("  {s}🔄 {s}: status={s} → restarting{sn", .{ YELLOW, name, status, RESET });

                if (dry_run) {
                    restarted += 1;
                    seed_counter += 1;
                    continue;
                }

                // Update secret with new seed
                const config = Wave9Config{};
                const secrets = try config.getSecrets(allocator, seed_counter);
                defer {
                    for (secrets) |s| allocator.free(s);
                    allocator.free(secrets);
                }

                _ = try flyctl.setSecrets(&ctx, name, secrets);

                // Restart app
                const restart_result = try flyctl.restartApp(&ctx, name);
                defer restart_result.deinit(allocator);

                if (restart_result.success()) {
                    print("    {s}✅ Restarted (seed={d}){sn", .{ GREEN, seed_counter, RESET });
                    restarted += 1;
                } else {
                    print("    {s}❌ Failed: {sn", .{ RED, restart_result.stderr, RESET });
                    skipped += 1;
                }
                seed_counter += 1;
            }
        }
    }

    print("\n{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}RECYCLE DONE: 🔄 {d} restarted | ⏭️ {d} skipped | Total crashed: {d}{s}\n\n", .{
        BOLD, restarted, skipped, total_crashed, RESET,
    });
}
