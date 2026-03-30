// @origin(spec:tri_farm.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI FARM — Railway Training Farm Management (dynamic accounts)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Native Zig replacement for Python/curl farm queries and deployments.
// Uses RailwayApi.initWithSuffix() for multi-account support.
//
// Commands:
//   tri farm status   — table of all services across all discovered accounts
//   tri farm idle     — only finished/idle services (for recycling)
//   tri farm recycle  — set training vars + redeploy all idle services
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const railway_api = @import("railway_api.zig");
const RailwayApi = railway_api.RailwayApi;
const farm_accounts_mod = @import("farm_accounts.zig");
const Account = farm_accounts_mod.Account;

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const DIM = "\x1b[2m";
const CYAN = "\x1b[36m";

pub fn runFarmCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, subcmd, "status")) {
        return runFarmStatus(allocator, false);
    } else if (std.mem.eql(u8, subcmd, "idle")) {
        return runFarmStatus(allocator, true);
    } else if (std.mem.eql(u8, subcmd, "recycle")) {
        return runFarmRecycle(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "fill")) {
        return runFarmFill(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "stats")) {
        return runFarmStatsCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "analyze")) {
        const farm_analyzer = @import("farm_analyzer_v2.zig");
        return farm_analyzer.runAnalyzeCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "evolve")) {
        const tri_farm_evolve = @import("evolution.zig");
        return tri_farm_evolve.runEvolveCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "from-issues")) {
        const farm_from_issues = @import("farm_from_issues.zig");
        return farm_from_issues.runFromIssues(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "watch-daemon")) {
        return runWatchDaemonCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "fly-init")) {
        return runFlyInit(allocator);
    } else if (std.mem.eql(u8, subcmd, "fly-deploy")) {
        const fly_wave9 = @import("fly_wave9.zig");
        return fly_wave9.deployWave9(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "fly-status")) {
        const fly_wave9 = @import("fly_wave9.zig");
        return fly_wave9.showWave9Status(allocator, &[_][]const u8{});
    } else if (std.mem.eql(u8, subcmd, "fly-recycle")) {
        // TODO: Re-enable after fixing circular import issue
        // const fly_wave9 = @import("fly_wave9.zig");
        // return fly_wave9.recycleWave9(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "wave9")) {
        const fly_wave9 = @import("fly_wave9.zig");
        return fly_wave9.deployWave9(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "local-wave9")) {
        return runLocalWave9Command(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        print("{s}Unknown farm subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

fn getJsonObject(val: std.json.Value, key: []const u8) ?std.json.Value {
    if (val != .object) return null;
    return val.object.get(key);
}

fn getJsonString(val: std.json.Value, key: []const u8) []const u8 {
    if (val != .object) return "?";
    const v = val.object.get(key) orelse return "?";
    if (v != .string) return "?";
    return v.string;
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS — show all services across 3 accounts
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runFarmStatus(allocator: Allocator, idle_only: bool) !void {
    print("\n{s}☁️  RAILWAY TRAINING FARM{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var total_services: usize = 0;
    var total_active: usize = 0;
    var total_idle: usize = 0;
    var total_crashed: usize = 0;
    var accounts_responsive: u8 = 0;

    var acct_buf: [farm_accounts_mod.MAX_ACCOUNTS]Account = undefined;
    const acct_count = farm_accounts_mod.discoverAccounts(allocator, &acct_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &acct_buf, acct_count);
    defer deinitHealthCache(allocator);
    if (acct_count == 0) {
        print("{s}⚠️  No Railway accounts found. Set RAILWAY_API_TOKEN in .env{s}\n", .{ YELLOW, RESET });
        return;
    }

    for (acct_buf[0..acct_count]) |acct| {
        print("{s}=== {s} ==={s}\n", .{ BOLD, acct.name, RESET });

        // Check health cache for dead accounts
        if (shouldSkipAccount(allocator, acct.name)) {
            const health = getHealthInfo(allocator, acct.name);
            const elapsed_min = @divTrunc(health.elapsed, @as(i64, 60));
            print("  {s}⚠️  SKIP (Not Authorized, last checked {d}m ago){s}\n\n", .{ YELLOW, elapsed_min, RESET });
            continue;
        }

        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch |err| {
            const health_info = getHealthInfo(allocator, acct.name);
            if (health_info.status == .dead) {
                const elapsed_min = @divTrunc(health_info.elapsed, @as(i64, 60));
                print("  {s}⚠️  SKIP (Not Authorized, last checked {d}m ago){s}\n\n", .{ YELLOW, elapsed_min, RESET });
            } else {
                print("  {s}⚠️  No token ({s}){s}\n\n", .{ YELLOW, @errorName(err), RESET });
                updateAccountHealth(allocator, acct.name, err) catch {};
            }
            continue;
        };
        defer api.deinit();

        const resp = api.getServiceInstances(acct.env_id) catch |err| {
            print("  {s}⚠️  API error: {s} (skipped){s}\n\n", .{ RED, @errorName(err), RESET });
            updateAccountHealth(allocator, acct.name, err) catch {};
            continue;
        };
        defer allocator.free(resp);

        // Mark account as alive on successful API call
        markAccountAlive(allocator, acct.name) catch {};
        accounts_responsive += 1;

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch {
            print("  {s}⚠️  Invalid JSON response{s}\n\n", .{ RED, RESET });
            continue;
        };
        defer parsed.deinit();

        const items = getEdgesArray(parsed.value) orelse {
            printApiError(parsed.value);
            continue;
        };

        if (!idle_only) {
            print("  {s}──────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
            print("  {s}SERVICE                   STATUS          REGION{s}\n", .{ DIM, RESET });
            print("  {s}──────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
        }

        var acct_active: usize = 0;
        var acct_idle: usize = 0;
        var acct_crashed: usize = 0;

        for (items) |edge| {
            const node = getJsonObject(edge, "node") orelse continue;
            const name = getJsonString(node, "serviceName");
            const region = getJsonString(node, "region");
            var status: []const u8 = "NONE";
            if (getJsonObject(node, "latestDeployment")) |dep| {
                const st = getJsonString(dep, "status");
                if (!std.mem.eql(u8, st, "?")) status = st;
            }

            const is_idle = isIdleStatus(status);
            const is_crashed = isCrashedStatus(status);
            const is_building = isBuildingStatus(status);
            const is_running = isRunningStatus(status);

            if (is_idle) {
                acct_idle += 1;
            } else if (is_crashed) {
                acct_crashed += 1;
            } else {
                acct_active += 1;
            }

            if (idle_only and !is_idle) continue;

            // SUCCESS = running (🟢), BUILDING/DEPLOYING = building (🔨), CRASHED = red (🔴), NONE/REMOVED = idle (💤)
            const status_icon = if (is_crashed) "🔴" else if (is_idle) "💤" else if (is_building) "🔨" else if (is_running) "🟢" else "🟢";
            const color = if (is_crashed) RED else if (is_idle) YELLOW else GREEN;

            print("  {s} {s}{s}{s}", .{ status_icon, color, name, RESET });
            padTo(name.len, 25);
            print(" {s}{s}{s}", .{ color, status, RESET });
            padTo(status.len, 15);
            print(" {s}\n", .{region});
        }

        total_services += items.len;
        total_active += acct_active;
        total_idle += acct_idle;
        total_crashed += acct_crashed;

        print("  {s}──────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
        print("  Total: {d} | {s}🟢 {d}{s} | {s}💤 {d}{s} | {s}🔴 {d}{s}\n\n", .{
            items.len,
            GREEN,
            acct_active,
            RESET,
            YELLOW,
            acct_idle,
            RESET,
            RED,
            acct_crashed,
            RESET,
        });
    }

    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}TOTAL: {d} services | 🟢 {d} active | 💤 {d} idle | 🔴 {d} crashed | {d}/{d} accounts responsive{s}\n\n", .{
        BOLD, total_services, total_active, total_idle, total_crashed, accounts_responsive, acct_count, RESET,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// RECYCLE — set training vars + redeploy idle/crashed services
// ═══════════════════════════════════════════════════════════════════════════════
//
// Usage: tri farm recycle [--lr 1e-3] [--batch 66] [--ctx 27] [--optimizer lamb]
//                         [--warmup 2000] [--wd 0.01] [--steps 100000]
//                         [--include-primary] [--force]
//
// Finds idle (REMOVED/NONE) and crashed (CRASHED/FAILED) services and redeploys.
// Use --force to also recycle SUCCESS (running) services.
//
// DEFAULTS are PROVEN config: ctx=27 (stable), LAMB 1e-3 cosine, batch=66

pub fn runFarmRecycle(allocator: Allocator, args: []const []const u8) !void {
    // Parse optional overrides - PROVEN config (R33 KING)
    var lr: []const u8 = "1e-3";
    var batch: []const u8 = "66";
    var ctx: []const u8 = "27";
    var optimizer: []const u8 = "lamb";
    var warmup: []const u8 = "2000";
    var wd: []const u8 = "0.01";
    var steps: []const u8 = "100000";
    var grad_clip: []const u8 = "1.0";
    var objective: []const u8 = "ntp";
    var lr_schedule: []const u8 = "cosine";
    var force = false;
    var fresh = false;
    var seed_start: u32 = 601;
    var skip_primary = true; // default: skip PRIMARY (old image)
    var skip_ci = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--lr") and i + 1 < args.len) {
            i += 1;
            lr = args[i];
        } else if (std.mem.eql(u8, arg, "--batch") and i + 1 < args.len) {
            i += 1;
            batch = args[i];
        } else if (std.mem.eql(u8, arg, "--ctx") and i + 1 < args.len) {
            i += 1;
            ctx = args[i];
        } else if (std.mem.eql(u8, arg, "--optimizer") and i + 1 < args.len) {
            i += 1;
            optimizer = args[i];
        } else if (std.mem.eql(u8, arg, "--warmup") and i + 1 < args.len) {
            i += 1;
            warmup = args[i];
        } else if (std.mem.eql(u8, arg, "--wd") and i + 1 < args.len) {
            i += 1;
            wd = args[i];
        } else if (std.mem.eql(u8, arg, "--steps") and i + 1 < args.len) {
            i += 1;
            steps = args[i];
        } else if (std.mem.eql(u8, arg, "--include-primary")) {
            skip_primary = false;
        } else if (std.mem.eql(u8, arg, "--grad-clip") and i + 1 < args.len) {
            i += 1;
            grad_clip = args[i];
        } else if (std.mem.eql(u8, arg, "--force")) {
            force = true;
        } else if (std.mem.eql(u8, arg, "--fresh")) {
            fresh = true;
        } else if (std.mem.eql(u8, arg, "--seed-start") and i + 1 < args.len) {
            i += 1;
            seed_start = std.fmt.parseInt(u32, args[i], 10) catch 601;
        } else if (std.mem.eql(u8, arg, "--objective") and i + 1 < args.len) {
            i += 1;
            objective = args[i];
        } else if (std.mem.eql(u8, arg, "--schedule") and i + 1 < args.len) {
            i += 1;
            lr_schedule = args[i];
        } else if (std.mem.eql(u8, arg, "--skip-ci")) {
            skip_ci = true;
        }
    }

    // CI gate: run tests before deploying
    if (skip_ci) {
        print("{s}⚠️  CI gate skipped (--skip-ci){s}\n", .{ YELLOW, RESET });
    } else {
        print("🔨 Running CI gate (zig build test)...\n", .{});
        const ci_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "zig", "build", "test" },
            .max_output_bytes = 512 * 1024,
        }) catch |err| {
            print("{s}❌ CI GATE FAILED — could not spawn zig build test: {s}{s}\n", .{ RED, @errorName(err), RESET });
            print("Use --skip-ci to bypass\n", .{});
            return;
        };
        defer allocator.free(ci_result.stdout);
        defer allocator.free(ci_result.stderr);

        const ci_exit = switch (ci_result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        };
        if (ci_exit != 0) {
            print("{s}❌ CI GATE FAILED — zig build test returned errors{s}\n", .{ RED, RESET });
            if (ci_result.stderr.len > 0) print("{s}\n", .{ci_result.stderr});
            print("Use --skip-ci to bypass\n", .{});
            return;
        }
        print("{s}✅ CI GATE PASSED — all tests OK{s}\n\n", .{ GREEN, RESET });
    }

    print("\n{s}🔄 FARM RECYCLE — Wave 6{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Config: LR={s} batch={s} ctx={s} opt={s} obj={s} sched={s}\n", .{
        lr, batch, ctx, optimizer, objective, lr_schedule,
    });
    print("  Extra: warmup={s} wd={s} steps={s} grad_clip={s}\n", .{
        warmup, wd, steps, grad_clip,
    });
    if (fresh) print("  {s}FRESH=1 (clearing checkpoints, clean start){s}\n", .{ YELLOW, RESET });
    print("  Seed start: {d}\n", .{seed_start});
    if (skip_primary) print("  {s}Skipping PRIMARY (old image){s}\n", .{ YELLOW, RESET });
    print("\n", .{});

    var deployed: usize = 0;
    var skipped: usize = 0;
    var errors: usize = 0;
    var seed_counter: u32 = seed_start;

    var acct_buf: [farm_accounts_mod.MAX_ACCOUNTS]Account = undefined;
    const acct_count = farm_accounts_mod.discoverAccounts(allocator, &acct_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &acct_buf, acct_count);
    if (acct_count == 0) {
        print("{s}⚠️  No Railway accounts found. Set RAILWAY_API_TOKEN in .env{s}\n", .{ YELLOW, RESET });
        return;
    }

    for (acct_buf[0..acct_count]) |acct| {
        if (skip_primary and std.mem.eql(u8, acct.suffix, "")) {
            print("{s}=== {s} === {s}(SKIPPED){s}\n\n", .{ BOLD, acct.name, YELLOW, RESET });
            continue;
        }

        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch |err| {
            print("{s}=== {s} === {s}No token ({s}){s}\n\n", .{ BOLD, acct.name, RED, @errorName(err), RESET });
            continue;
        };
        defer api.deinit();

        print("{s}=== {s} ==={s}\n", .{ BOLD, acct.name, RESET });

        // Get services with IDs
        const gql = "query($projectId: String!) { project(id: $projectId) { services { edges { node { id name deployments(first:1) { edges { node { status } } } } } } } }";
        const vars_json = std.fmt.allocPrint(allocator, "{{\"projectId\":\"{s}\"}}", .{acct.project_id}) catch continue;
        defer allocator.free(vars_json);

        const resp = api.query(gql, vars_json) catch |err| {
            print("  {s}⚠️  API error: {s}{s}\n\n", .{ RED, @errorName(err), RESET });
            continue;
        };
        defer allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch {
            print("  {s}⚠️  Invalid JSON{s}\n\n", .{ RED, RESET });
            continue;
        };
        defer parsed.deinit();

        // Navigate: data.project.services.edges
        const data_val = getJsonObject(parsed.value, "data") orelse {
            printApiError(parsed.value);
            continue;
        };
        const proj_val = getJsonObject(data_val, "project") orelse {
            print("  {s}⚠️  Project not found{s}\n\n", .{ RED, RESET });
            continue;
        };
        const svcs_val = getJsonObject(proj_val, "services") orelse continue;
        const edges_val = getJsonObject(svcs_val, "edges") orelse continue;
        if (edges_val != .array) continue;

        for (edges_val.array.items) |edge| {
            const node = getJsonObject(edge, "node") orelse continue;
            const svc_id = getJsonString(node, "id");
            const svc_name = getJsonString(node, "name");

            // Check deployment status
            var dep_status: []const u8 = "NONE";
            if (getJsonObject(node, "deployments")) |deps| {
                if (getJsonObject(deps, "edges")) |dep_edges| {
                    if (dep_edges == .array and dep_edges.array.items.len > 0) {
                        const dep_node = getJsonObject(dep_edges.array.items[0], "node") orelse continue;
                        dep_status = getJsonString(dep_node, "status");
                    }
                }
            }

            if (!force and !isIdleStatus(dep_status) and !isCrashedStatus(dep_status)) {
                print("  ⏭️  {s}: {s} (active, skip)\n", .{ svc_name, dep_status });
                skipped += 1;
                continue;
            }

            // Set training variables via variableCollectionUpsert
            const seed_str = std.fmt.allocPrint(allocator, "{d}", .{seed_counter}) catch continue;
            defer allocator.free(seed_str);
            seed_counter += 1;

            const set_vars_gql = "mutation($input: VariableCollectionUpsertInput!) { variableCollectionUpsert(input: $input) }";
            const fresh_val: []const u8 = if (fresh) "1" else "0";
            // TEMPORARY: Remove HSLM_OBJECTIVE and HSLM_LR_SCHEDULE until Railway cache refreshes
            // Old binaries don't support these new env vars and crash
            const set_vars_json = std.fmt.allocPrint(allocator,
                \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","variables":{{"HSLM_LR":"{s}","HSLM_BATCH":"{s}","HSLM_CONTEXT":"{s}","HSLM_SEED":"{s}","HSLM_STEPS":"{s}","HSLM_OPTIMIZER":"{s}","HSLM_FRESH":"{s}","HSLM_WARMUP":"{s}","HSLM_WD":"{s}","HSLM_CHECKPOINT_EVERY":"10000","HSLM_GRAD_ACCUM":"1","HSLM_DROPOUT":"0","HSLM_ADAPTIVE_SPARSITY":"0","HSLM_FULL_TERNARY":"0","HSLM_STE":"0","HSLM_TERNARY_SCHEDULE":"0","HSLM_TERNARY_GRADS":"0","HSLM_LABEL_SMOOTHING":"0","HSLM_GRAD_CLIP":"{s}","RAILWAY_DOCKERFILE_PATH":"Dockerfile.hslm-train"}}}}}}
            , .{
                acct.project_id, svc_id, acct.env_id,
                lr,              batch,  ctx,
                seed_str,        steps,  optimizer,
                fresh_val,       warmup, wd,
                grad_clip,
            }) catch continue;
            defer allocator.free(set_vars_json);

            const vars_resp = api.query(set_vars_gql, set_vars_json) catch {
                print("  {s}❌ {s}: vars failed{s}\n", .{ RED, svc_name, RESET });
                errors += 1;
                continue;
            };
            allocator.free(vars_resp);

            // Set builder=NIXPACKS, startCommand=null, dockerfilePath
            const builder_gql = "mutation($serviceId: String!, $environmentId: String!, $input: ServiceInstanceUpdateInput!) { serviceInstanceUpdate(serviceId: $serviceId, environmentId: $environmentId, input: $input) }";
            const builder_json = std.fmt.allocPrint(allocator,
                \\{{"serviceId":"{s}","environmentId":"{s}","input":{{"builder":"NIXPACKS","startCommand":null,"dockerfilePath":"Dockerfile.hslm-train"}}}}
            , .{ svc_id, acct.env_id }) catch continue;
            defer allocator.free(builder_json);

            if (api.query(builder_gql, builder_json)) |builder_resp| {
                allocator.free(builder_resp);
            } else |_| {
                print("  {s}⚠️  {s}: builder update failed (continuing){s}\n", .{ YELLOW, svc_name, RESET });
            }

            // Redeploy
            const deploy_resp = api.redeployService(svc_id, acct.env_id) catch {
                print("  {s}❌ {s}: redeploy failed{s}\n", .{ RED, svc_name, RESET });
                errors += 1;
                continue;
            };
            allocator.free(deploy_resp);

            print("  {s}✅ {s}{s}: LR={s} b={s} ctx={s} seed={s} opt={s} → DEPLOYING\n", .{
                GREEN, svc_name, RESET, lr, batch, ctx, seed_str, optimizer,
            });
            deployed += 1;
        }
        print("\n", .{});
    }

    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}RECYCLE DONE: ✅ {d} deployed | ⏭️ {d} skipped | ❌ {d} errors{s}\n\n", .{
        BOLD, deployed, skipped, errors, RESET,
    });

    // Experience hook (fire-and-forget)
    const exp_hooks = @import("experience_hooks.zig");
    exp_hooks.autoSaveExperience("farm recycle", "", errors == 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILL — create new services to fill empty slots up to 25/account
// ═══════════════════════════════════════════════════════════════════════════════
//
// Usage: tri farm fill [--lr 1e-3] [--batch 66] [--ctx 27] [--max N]
//                       [--include-primary] [--dry-run]
//
// Creates NEW hslm-wN services on accounts with < 25 services.
// Each service: repo=gHashTag/trinity, Dockerfile.hslm-train, cosine, NIXPACKS.

fn runFarmFill(allocator: Allocator, args: []const []const u8) !void {
    var lr: []const u8 = "1e-3";
    var batch: []const u8 = "66";
    var ctx: []const u8 = "27";
    var optimizer: []const u8 = "lamb";
    var warmup: []const u8 = "2000";
    var wd: []const u8 = "0.01";
    var steps: []const u8 = "100000";
    var grad_clip: []const u8 = "1.0";
    var force = false;
    var max_create: usize = 37; // max new services to create total
    var skip_primary = true;
    var dry_run = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--lr") and i + 1 < args.len) {
            i += 1;
            lr = args[i];
        } else if (std.mem.eql(u8, arg, "--batch") and i + 1 < args.len) {
            i += 1;
            batch = args[i];
        } else if (std.mem.eql(u8, arg, "--ctx") and i + 1 < args.len) {
            i += 1;
            ctx = args[i];
        } else if (std.mem.eql(u8, arg, "--optimizer") and i + 1 < args.len) {
            i += 1;
            optimizer = args[i];
        } else if (std.mem.eql(u8, arg, "--warmup") and i + 1 < args.len) {
            i += 1;
            warmup = args[i];
        } else if (std.mem.eql(u8, arg, "--wd") and i + 1 < args.len) {
            i += 1;
            wd = args[i];
        } else if (std.mem.eql(u8, arg, "--steps") and i + 1 < args.len) {
            i += 1;
            steps = args[i];
        } else if (std.mem.eql(u8, arg, "--max") and i + 1 < args.len) {
            i += 1;
            max_create = std.fmt.parseInt(usize, args[i], 10) catch 37;
        } else if (std.mem.eql(u8, arg, "--include-primary")) {
            skip_primary = false;
        } else if (std.mem.eql(u8, arg, "--grad-clip") and i + 1 < args.len) {
            i += 1;
            grad_clip = args[i];
        } else if (std.mem.eql(u8, arg, "--force")) {
            force = true;
        } else if (std.mem.eql(u8, arg, "--dry-run")) {
            dry_run = true;
        }
    }

    print("\n{s}🚀 FARM FILL — Create New Training Services{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Config: LR={s} batch={s} ctx={s} opt={s} warmup={s} steps={s}\n", .{
        lr, batch, ctx, optimizer, warmup, steps,
    });
    print("  Schedule: cosine (always) | Max new: {d}\n", .{max_create});
    if (dry_run) print("  {s}DRY RUN — no services will be created{s}\n", .{ YELLOW, RESET });
    print("\n", .{});

    var created: usize = 0;
    var errors: usize = 0;
    var seed_counter: u32 = 701; // W7xx seed range for fill

    var acct_buf: [farm_accounts_mod.MAX_ACCOUNTS]Account = undefined;
    const acct_count = farm_accounts_mod.discoverAccounts(allocator, &acct_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &acct_buf, acct_count);
    if (acct_count == 0) {
        print("{s}⚠️  No Railway accounts found. Set RAILWAY_API_TOKEN in .env{s}\n", .{ YELLOW, RESET });
        return;
    }

    for (acct_buf[0..acct_count]) |acct| {
        if (skip_primary and std.mem.eql(u8, acct.suffix, "")) {
            print("{s}=== {s} === {s}(SKIPPED){s}\n\n", .{ BOLD, acct.name, YELLOW, RESET });
            continue;
        }

        if (created >= max_create) break;

        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch |err| {
            print("{s}=== {s} === {s}No token ({s}){s}\n\n", .{ BOLD, acct.name, RED, @errorName(err), RESET });
            continue;
        };
        defer api.deinit();

        print("{s}=== {s} ==={s}\n", .{ BOLD, acct.name, RESET });

        // Count existing services
        const gql = "query($projectId: String!) { project(id: $projectId) { services { edges { node { id name } } } } }";
        const vars_json = std.fmt.allocPrint(allocator, "{{\"projectId\":\"{s}\"}}", .{acct.project_id}) catch continue;
        defer allocator.free(vars_json);

        const resp = api.query(gql, vars_json) catch |err| {
            print("  {s}⚠️  API error: {s}{s}\n\n", .{ RED, @errorName(err), RESET });
            continue;
        };
        defer allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch {
            print("  {s}⚠️  Invalid JSON{s}\n\n", .{ RED, RESET });
            continue;
        };
        defer parsed.deinit();

        const data_val = getJsonObject(parsed.value, "data") orelse {
            printApiError(parsed.value);
            continue;
        };
        const proj_val = getJsonObject(data_val, "project") orelse continue;
        const svcs_val = getJsonObject(proj_val, "services") orelse continue;
        const edges_val = getJsonObject(svcs_val, "edges") orelse continue;
        if (edges_val != .array) continue;

        const current_count = edges_val.array.items.len;
        const max_per_account: usize = 25;
        const free_slots = if (current_count < max_per_account) max_per_account - current_count else 0;

        print("  Current: {d}/25 | Free: {d}\n", .{ current_count, free_slots });

        if (free_slots == 0) {
            print("  {s}Account full{s}\n\n", .{ YELLOW, RESET });
            continue;
        }

        const to_create = @min(free_slots, max_create - created);
        print("  Creating: {d} new services\n\n", .{to_create});

        var j: usize = 0;
        while (j < to_create) : (j += 1) {
            if (created >= max_create) break;

            const svc_name = std.fmt.allocPrint(allocator, "hslm-w7-{d}", .{created + 1}) catch continue;
            defer allocator.free(svc_name);

            const seed_str = std.fmt.allocPrint(allocator, "{d}", .{seed_counter}) catch continue;
            defer allocator.free(seed_str);
            seed_counter += 1;

            if (dry_run) {
                print("  {s}[DRY] Would create {s} (seed={s}){s}\n", .{ CYAN, svc_name, seed_str, RESET });
                created += 1;
                continue;
            }

            // 1. Create service with repo
            const create_resp = api.createServiceWithRepo(svc_name, "gHashTag/trinity", "main") catch |err| {
                print("  {s}❌ {s}: create failed ({s}){s}\n", .{ RED, svc_name, @errorName(err), RESET });
                errors += 1;
                // If creation fails, likely hit Railway limit — stop this account
                print("  {s}⛔ Railway creation limit hit — stopping {s}{s}\n\n", .{ RED, acct.name, RESET });
                break;
            };

            // Parse service ID from response — detect creation limit errors
            const create_parsed = std.json.parseFromSlice(std.json.Value, allocator, create_resp, .{}) catch {
                print("  {s}❌ {s}: invalid JSON response{s}\n", .{ RED, svc_name, RESET });
                allocator.free(create_resp);
                errors += 1;
                continue;
            };
            // IMPORTANT: create_resp must outlive create_parsed — parsed strings reference it
            defer allocator.free(create_resp);
            defer create_parsed.deinit();

            // Check for GraphQL errors (e.g., creation limit)
            if (getJsonObject(create_parsed.value, "errors")) |err_val| {
                if (err_val == .array and err_val.array.items.len > 0) {
                    const err_msg = getJsonString(err_val.array.items[0], "message");
                    print("  {s}⛔ {s}: {s}{s}\n", .{ RED, svc_name, err_msg, RESET });
                    errors += 1;
                    // Stop trying this account if creation limit
                    if (std.mem.indexOf(u8, err_msg, "creation limit") != null) {
                        print("  {s}⛔ Creation limit — stopping {s}. Contact station.railway.com{s}\n\n", .{ RED, acct.name, RESET });
                        break;
                    }
                    continue;
                }
            }

            const create_data = getJsonObject(create_parsed.value, "data") orelse {
                printApiError(create_parsed.value);
                errors += 1;
                break;
            };
            const svc_create = getJsonObject(create_data, "serviceCreate") orelse {
                print("  {s}❌ {s}: serviceCreate missing in response{s}\n", .{ RED, svc_name, RESET });
                errors += 1;
                continue;
            };
            const new_svc_id = getJsonString(svc_create, "id");

            // 2. Set training variables
            const set_vars_gql = "mutation($input: VariableCollectionUpsertInput!) { variableCollectionUpsert(input: $input) }";
            const set_vars_json = std.fmt.allocPrint(allocator,
                \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","variables":{{"HSLM_LR":"{s}","HSLM_BATCH":"{s}","HSLM_CONTEXT":"{s}","HSLM_SEED":"{s}","HSLM_STEPS":"{s}","HSLM_OPTIMIZER":"{s}","HSLM_LR_SCHEDULE":"cosine","HSLM_FRESH":"0","HSLM_WARMUP":"{s}","HSLM_WD":"{s}","HSLM_CHECKPOINT_EVERY":"10000","HSLM_GRAD_ACCUM":"1","HSLM_DROPOUT":"0","HSLM_ADAPTIVE_SPARSITY":"0","HSLM_FULL_TERNARY":"0","HSLM_STE":"0","HSLM_TERNARY_SCHEDULE":"0","HSLM_TERNARY_GRADS":"0","HSLM_LABEL_SMOOTHING":"0","HSLM_GRAD_CLIP":"{s}","RAILWAY_DOCKERFILE_PATH":"Dockerfile.hslm-train"}}}}}}
            , .{
                acct.project_id, new_svc_id, acct.env_id,
                lr,              batch,      ctx,
                seed_str,        steps,      optimizer,
                warmup,          wd,         grad_clip,
            }) catch continue;
            defer allocator.free(set_vars_json);

            if (api.query(set_vars_gql, set_vars_json)) |vars_resp| {
                allocator.free(vars_resp);
            } else |_| {
                print("  {s}⚠️  {s}: vars failed{s}\n", .{ YELLOW, svc_name, RESET });
            }

            // 3. Set builder=NIXPACKS, startCommand=null, dockerfilePath
            const builder_gql = "mutation($serviceId: String!, $environmentId: String!, $input: ServiceInstanceUpdateInput!) { serviceInstanceUpdate(serviceId: $serviceId, environmentId: $environmentId, input: $input) }";
            const builder_json = std.fmt.allocPrint(allocator,
                \\{{"serviceId":"{s}","environmentId":"{s}","input":{{"builder":"NIXPACKS","startCommand":null,"dockerfilePath":"Dockerfile.hslm-train"}}}}
            , .{ new_svc_id, acct.env_id }) catch continue;
            defer allocator.free(builder_json);

            if (api.query(builder_gql, builder_json)) |builder_resp| {
                allocator.free(builder_resp);
            } else |_| {
                print("  {s}⚠️  {s}: builder update failed{s}\n", .{ YELLOW, svc_name, RESET });
            }

            print("  {s}✅ {s}{s} (id={s:.12}) seed={s} → AUTO-DEPLOYING\n", .{
                GREEN, svc_name, RESET, new_svc_id, seed_str,
            });
            created += 1;
        }
        print("\n", .{});
    }

    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}FILL DONE: ✅ {d} created | ❌ {d} errors{s}\n", .{ BOLD, created, errors, RESET });
    if (created > 0 and !dry_run) {
        print("Services will auto-deploy from repo. Monitor with: tri farm status\n", .{});
    }
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════

fn isIdleStatus(status: []const u8) bool {
    // SUCCESS = container running (deployment succeeded), NOT idle!
    // Only REMOVED and NONE are truly idle (no container running)
    return std.mem.eql(u8, status, "REMOVED") or
        std.mem.eql(u8, status, "NONE");
}

fn isRunningStatus(status: []const u8) bool {
    // SUCCESS in Railway = deployment succeeded, container is running
    return std.mem.eql(u8, status, "SUCCESS");
}

fn isCrashedStatus(status: []const u8) bool {
    return std.mem.eql(u8, status, "CRASHED") or
        std.mem.eql(u8, status, "FAILED");
}

fn isBuildingStatus(status: []const u8) bool {
    return std.mem.eql(u8, status, "DEPLOYING") or
        std.mem.eql(u8, status, "BUILDING") or
        std.mem.eql(u8, status, "INITIALIZING");
}

fn getEdgesArray(root: std.json.Value) ?[]std.json.Value {
    const data_val = getJsonObject(root, "data") orelse return null;
    const env_val = getJsonObject(data_val, "environment") orelse return null;
    const si_val = getJsonObject(env_val, "serviceInstances") orelse return null;
    const edges_val = getJsonObject(si_val, "edges") orelse return null;
    if (edges_val != .array) return null;
    return edges_val.array.items;
}

fn printApiError(root: std.json.Value) void {
    if (getJsonObject(root, "errors")) |errors_val| {
        if (errors_val == .array and errors_val.array.items.len > 0) {
            const msg = getJsonString(errors_val.array.items[0], "message");
            print("  {s}⚠️  {s}{s}\n\n", .{ RED, msg, RESET });
            return;
        }
    }
    print("  {s}⚠️  No data in response{s}\n\n", .{ RED, RESET });
}

fn padTo(current: usize, target: usize) void {
    if (current >= target) return;
    var pad_i: usize = 0;
    while (pad_i < target - current) : (pad_i += 1) {
        print(" ", .{});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WATCH DAEMON — 24/7 autonomous farm monitoring
// ═══════════════════════════════════════════════════════════════════════════════

const DAEMON_PID_FILE = ".trinity/farm/watch_daemon.pid";
const DAEMON_LOG_FILE = ".trinity/farm/watch_daemon.jsonl";
const DAEMON_INTERVAL_SEC: u32 = 300; // 5 minutes

// ═══════════════════════════════════════════════════════════════════════════════
// ACCOUNT HEALTH CACHE — Graceful degradation for dead accounts
// ═══════════════════════════════════════════════════════════════════════════════

const ACCOUNT_HEALTH_FILE = ".trinity/farm/account_health.json";
const DEAD_ACCOUNT_RETRY_SEC = 1800; // 30 minutes before retrying dead accounts

const AccountStatus = enum { alive, dead, unknown };

const AccountHealth = struct {
    status: AccountStatus,
    last_check: i64,
    last_error: []const u8,
};

var health_cache: std.StringHashMap(AccountHealth) = undefined;
var health_cache_initialized = false;

/// Load health cache from disk (called once on first use)
fn initHealthCache(allocator: Allocator) !void {
    if (health_cache_initialized) return;

    health_cache = std.StringHashMap(AccountHealth).init(allocator);

    const file = std.fs.cwd().openFile(ACCOUNT_HEALTH_FILE, .{}) catch |err| {
        if (err == error.FileNotFound) {
            // No cache yet — start fresh
            health_cache_initialized = true;
            return;
        }
        return err;
    };
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 64 * 1024) catch |err| {
        if (err == error.IsDir) {
            // Corrupted state — directory instead of file
            health_cache_initialized = true;
            return;
        }
        return err;
    };
    defer allocator.free(contents);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch {
        // Invalid JSON — start fresh
        health_cache_initialized = true;
        return;
    };
    defer parsed.deinit();

    if (parsed.value != .object) return;

    var iter = parsed.value.object.iterator();
    while (iter.next()) |entry| {
        const acct_name = entry.key_ptr.*;
        const val = entry.value_ptr.*;

        if (val != .object) continue;

        const status_str = getJsonString(val, "status");
        const last_check = getJsonObject(val, "last_check") orelse continue;
        if (last_check != .integer) continue;

        const last_error_str = getJsonString(val, "last_error");

        const status: AccountStatus = if (std.mem.eql(u8, status_str, "alive"))
            .alive
        else if (std.mem.eql(u8, status_str, "dead"))
            .dead
        else
            .unknown;

        // Clone strings for persistent storage
        const name_copy = allocator.dupe(u8, acct_name) catch continue;
        const err_copy = allocator.dupe(u8, last_error_str) catch {
            allocator.free(name_copy);
            continue;
        };

        try health_cache.put(name_copy, .{
            .status = status,
            .last_check = @intCast(last_check.integer),
            .last_error = err_copy,
        });
    }

    health_cache_initialized = true;
}

/// Save health cache to disk
fn saveHealthCache(allocator: Allocator) !void {
    var json_buf = try std.ArrayList(u8).initCapacity(allocator, 1024);
    defer json_buf.deinit(allocator);

    try json_buf.append(allocator, '{');

    var iter = health_cache.iterator();
    var first = true;
    while (iter.next()) |entry| {
        if (!first) try json_buf.append(allocator, ',');
        first = false;

        const acct = entry.key_ptr.*;
        const health = entry.value_ptr.*;

        const status_str = switch (health.status) {
            .alive => "alive",
            .dead => "dead",
            .unknown => "unknown",
        };

        try json_buf.writer(allocator).print(
            \\"{s}":{{"status":"{s}","last_check":{d},"last_error":"{s}"}}
        , .{ acct, status_str, health.last_check, health.last_error });
    }

    try json_buf.append(allocator, '}');

    const dir = std.fs.path.dirname(ACCOUNT_HEALTH_FILE) orelse ".";
    std.fs.cwd().makePath(dir) catch {};

    const file = try std.fs.cwd().createFile(ACCOUNT_HEALTH_FILE, .{});
    defer file.close();
    try file.writeAll(json_buf.items);
}

/// Update account health status after API call
fn updateAccountHealth(allocator: Allocator, acct_name: []const u8, err: anyerror) !void {
    try initHealthCache(allocator);

    const now = std.time.timestamp();
    const err_name = @errorName(err);

    const status: AccountStatus = if (err == error.NotAuthorized or err == error.ConnectionFailed)
        .dead
    else
        .unknown;

    // Free old value if exists
    if (health_cache.get(acct_name)) |old| {
        allocator.free(old.last_error);
    }

    // Clone strings for storage
    const name_copy = try allocator.dupe(u8, acct_name);
    const err_copy = try allocator.dupe(u8, err_name);

    try health_cache.put(name_copy, .{
        .status = status,
        .last_check = now,
        .last_error = err_copy,
    });

    try saveHealthCache(allocator);
}

/// Mark account as alive after successful API call
fn markAccountAlive(allocator: Allocator, acct_name: []const u8) !void {
    try initHealthCache(allocator);

    const now = std.time.timestamp();

    // Free old value if exists
    if (health_cache.get(acct_name)) |old| {
        allocator.free(old.last_error);
    }

    const name_copy = try allocator.dupe(u8, acct_name);
    const err_copy = try allocator.dupe(u8, "");

    try health_cache.put(name_copy, .{
        .status = .alive,
        .last_check = now,
        .last_error = err_copy,
    });

    try saveHealthCache(allocator);
}

/// Check if account should be skipped (dead + recent check)
fn shouldSkipAccount(allocator: Allocator, acct_name: []const u8) bool {
    initHealthCache(allocator) catch return false;

    const health = health_cache.get(acct_name) orelse return false;
    if (health.status != .dead) return false;

    const now = std.time.timestamp();
    const elapsed = now - health.last_check;

    // Retry dead accounts after DEAD_ACCOUNT_RETRY_SEC (30 minutes)
    return elapsed < DEAD_ACCOUNT_RETRY_SEC;
}

/// Get health info for display
fn getHealthInfo(allocator: Allocator, acct_name: []const u8) struct { status: AccountStatus, elapsed: i64 } {
    initHealthCache(allocator) catch return .{ .status = .unknown, .elapsed = 0 };

    const health = health_cache.get(acct_name) orelse return .{ .status = .unknown, .elapsed = 0 };

    const now = std.time.timestamp();
    return .{
        .status = health.status,
        .elapsed = now - health.last_check,
    };
}

/// Cleanup health cache on shutdown
fn deinitHealthCache(allocator: Allocator) void {
    if (!health_cache_initialized) return;

    var iter = health_cache.iterator();
    while (iter.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*.last_error);
    }
    health_cache.deinit();
    health_cache_initialized = false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSONL LOGGING — For "brain" integration (Mu/Queen/Scholar can read this)
// ═══════════════════════════════════════════════════════════════════════════════

fn logDaemonEvent(allocator: Allocator, event_type: []const u8, event: []const u8, data: []const u8) !void {
    _ = allocator;
    const timestamp = std.time.timestamp();
    var msg_buf: [512]u8 = undefined;
    const msg = try std.fmt.bufPrint(&msg_buf,
        \\{{"type":"{s}","event":"{s}","data":"{s}","timestamp":{d}}}
    , .{ event_type, event, data, timestamp });

    const log_file = try std.fs.cwd().createFile(DAEMON_LOG_FILE, .{ .truncate = false });
    defer log_file.close();
    try log_file.seekFromEnd(0);
    try log_file.writeAll(msg);
}

fn runWatchDaemonCommand(allocator: Allocator, args: []const []const u8) !void {
    const action = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, action, "start")) {
        return daemonStart(allocator);
    } else if (std.mem.eql(u8, action, "stop")) {
        return daemonStop();
    } else if (std.mem.eql(u8, action, "status")) {
        return daemonStatus();
    } else if (std.mem.eql(u8, action, "restart")) {
        try daemonStop();
        return daemonStart(allocator);
    } else {
        print("{s}Usage: tri farm watch-daemon <start|stop|status|restart>{s}\n", .{ YELLOW, RESET });
        print("\nCommands:\n", .{});
        print("  start    Launch background daemon (runs evolve watch every 5min)\n", .{});
        print("  stop     Shutdown running daemon\n", .{});
        print("  status   Check if daemon is running\n", .{});
        print("  restart  Stop then start daemon\n", .{});
    }
}

fn daemonStart(allocator: Allocator) !void {
    // Check if already running
    {
        const existing_pid = getExistingPid() catch null;
        if (existing_pid) |pid| {
            if (isProcessAlive(pid)) {
                print("{s}⚠️  Watch daemon already running (PID {d}){s}\n", .{ YELLOW, pid, RESET });
                print("   Run 'tri farm watch-daemon stop' first\n", .{});
                return;
            }
            // Stale lock, will be overwritten
        }
    }

    print("{s}🚀 Starting watch daemon...{s}\n", .{ GREEN, RESET });

    // Fork to background (Unix only - simplified)
    // For now, run in foreground with instructions
    print("{s}⚠️  Running in foreground. Press Ctrl+C to stop.{s}\n", .{ YELLOW, RESET });
    print("{s}   For background: nohup tri farm watch-daemon start >/dev/null 2>&1 &{s}\n", .{ DIM, RESET });
    print("\n", .{});

    const self_pid = std.c.getpid();

    // Write PID file
    {
        const new_pid_file = try std.fs.cwd().createFile(DAEMON_PID_FILE, .{});
        defer new_pid_file.close();
        const pid_str = try std.fmt.allocPrint(allocator, "{d}\n", .{self_pid});
        defer allocator.free(pid_str);
        try new_pid_file.writeAll(pid_str);
    }

    print("   {s}✅ Daemon started (PID {d}){s}\n", .{ GREEN, self_pid, RESET });
    print("   {s}→ Run: tri farm watch-daemon stop{s}\n", .{ DIM, RESET });
    print("   {s}→ Interval: {d} seconds{s}\n", .{ DIM, DAEMON_INTERVAL_SEC, RESET });
    print("\n", .{});

    // Main daemon loop
    const tri_farm_evolve = @import("evolution.zig");
    var sweep_count: u32 = 0;

    while (true) {
        sweep_count += 1;
        const sweep_start = std.time.nanoTimestamp();

        print("{s}🔄 Sweep #{d}{s}\n", .{ DIM, sweep_count, RESET });

        // Run evolve watch with --once flag + Telegram notifications
        // Wrap in catch to prevent crash on any error
        const watch_args = &[_][]const u8{ "--once", "--sacred", "--objective", "ntp", "--notify" };
        tri_farm_evolve.runEvolveCommand(allocator, watch_args) catch |err| {
            // Log error to JSONL
            const err_msg = std.fmt.allocPrint(allocator, "{s}", .{@errorName(err)}) catch "unknown";
            logDaemonEvent(allocator, "error", "sweep_failed", err_msg) catch {};

            print("   {s}⚠️  Sweep failed: {s}{s}\n", .{ YELLOW, @errorName(err), RESET });

            // Continue to next sweep — DON'T crash
        };

        const elapsed_ms = @as(u64, @intCast(@divTrunc(@as(i128, std.time.nanoTimestamp() - sweep_start), 1_000_000)));
        print("   {s}Sweep done in {d}ms{s}\n", .{ DIM, elapsed_ms, RESET });

        // Log sweep event to JSONL for "brain" integration
        logDaemonEvent(allocator, "sweep", "sweep_completed", std.fmt.allocPrint(allocator, "sweep_{d}_ms_{d}", .{ sweep_count, elapsed_ms }) catch "") catch {};

        print("   Sleeping {d}s...\n\n", .{DAEMON_INTERVAL_SEC});
        std.Thread.sleep(@as(u64, DAEMON_INTERVAL_SEC) * std.time.ns_per_s);
    }
}

fn daemonStop() !void {
    const pid_file = std.fs.cwd().openFile(DAEMON_PID_FILE, .{}) catch |err| {
        if (err == error.FileNotFound) {
            print("{s}⚠️  Watch daemon not running (no PID file){s}\n", .{ YELLOW, RESET });
            return;
        }
        return err;
    };
    defer pid_file.close();

    var pid_buf: [32]u8 = undefined;
    const pid_bytes = try pid_file.readAll(&pid_buf);
    const pid_str = pid_buf[0..pid_bytes];
    const pid = try std.fmt.parseInt(u32, std.mem.trim(u8, pid_str, &std.ascii.whitespace), 10);

    if (!isProcessAlive(pid)) {
        print("{s}⚠️  Daemon PID {d} not alive (stale lock){s}\n", .{ YELLOW, pid, RESET });
        std.fs.cwd().deleteFile(DAEMON_PID_FILE) catch {};
        return;
    }

    print("{s}🛑 Stopping watch daemon (PID {d})...{s}\n", .{ YELLOW, pid, RESET });

    // Send SIGTERM
    std.posix.kill(@intCast(pid), std.posix.SIG.TERM) catch |err| {
        print("{s}⚠️  Failed to send SIGTERM: {}{s}\n", .{ YELLOW, err, RESET });
    };

    // Wait a bit for graceful shutdown
    std.Thread.sleep(2 * std.time.ns_per_s);

    // Force kill if still alive
    if (isProcessAlive(pid)) {
        print("   Force killing...", .{});
        std.posix.kill(@intCast(pid), std.posix.SIG.KILL) catch {};
    }

    std.fs.cwd().deleteFile(DAEMON_PID_FILE) catch {};
    print("{s}✅ Daemon stopped{s}\n", .{ GREEN, RESET });
}

fn daemonStatus() !void {
    const pid = getExistingPid() catch {
        print("{s}⚠️  Watch daemon not running{s}\n", .{ YELLOW, RESET });
        return;
    };

    if (isProcessAlive(pid)) {
        print("{s}✅ Watch daemon running (PID {d}){s}\n", .{ GREEN, pid, RESET });
        print("   Stop with: tri farm watch-daemon stop\n", .{});
    } else {
        print("{s}⚠️  PID file exists but process {d} not alive (stale lock){s}\n", .{ YELLOW, pid, RESET });
        print("   Clean with: tri farm watch-daemon stop\n", .{});
    }
}

fn getExistingPid() !u32 {
    const pid_file = try std.fs.cwd().openFile(DAEMON_PID_FILE, .{});
    defer pid_file.close();

    var pid_buf: [32]u8 = undefined;
    const pid_bytes = try pid_file.readAll(&pid_buf);
    const pid_str = pid_buf[0..pid_bytes];
    return try std.fmt.parseInt(u32, std.mem.trimRight(u8, pid_str, "\n"), 10);
}

fn isProcessAlive(pid: u32) bool {
    // Send signal 0 to check if process exists
    std.posix.kill(@intCast(pid), 0) catch |err| {
        if (err == error.ProcessNotFound) return false;
        // Other errors might mean process exists
        return true;
    };
    return true;
}

// ═════════════════════════════════════════════════════════════════════════

fn runFarmStatsCommand(allocator: Allocator, args: []const []const u8) !void {
    _ = args; // Mark as used
    print("{s}=== FARM STATISTICS ==={s}\n\n", .{ BOLD, RESET });

    const file = std.fs.cwd().openFile(".trinity/farm/w7v2_snapshot.json", .{}) catch |err| {
        print("{s}Error loading snapshot: {s}\n", .{ RED, @errorName(err) });
        return;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1_000_000);
    defer allocator.free(content);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
    defer parsed.deinit();

    var worker_count: usize = 0;
    var total_ppl: f64 = 0;
    var min_ppl: f64 = std.math.floatMax(f64);
    var max_ppl: f64 = 0;

    for (parsed.value.array.items) |worker_val| {
        if (worker_val.object.get("ppl")) |ppl| {
            if (ppl == .float) {
                total_ppl += ppl.float;
                min_ppl = @min(min_ppl, ppl.float);
                max_ppl = @max(max_ppl, ppl.float);
                worker_count += 1;
            }
        }
    }

    if (worker_count > 0) {
        print("Workers: {d}\n", .{worker_count});
        print("Avg PPL: {s}{d:.2}{s}\n", .{ GREEN, total_ppl / @as(f64, @floatFromInt(worker_count)), RESET });
        print("Min PPL: {d:.2}\n", .{min_ppl});
        print("Max PPL: {d:.2}\n", .{max_ppl});
    } else {
        print("{s}No workers found in snapshot{s}\n", .{ YELLOW, RESET });
    }
}

// ═════════════════════════════════════════════════════════════════════
// TELEGRAM ALERTS — Send notifications to Telegram group
// ═════════════════════════════════════════════════════════════════════════════════

fn sendTelegramAlert(allocator: Allocator, comptime fmt: []const u8, args: anytype) !void {
    const msg = std.fmt.allocPrint(allocator, fmt, args) catch return;
    defer allocator.free(msg);

    const token = std.process.getEnvVarOwned(allocator, "TELEGRAM_BOT_TOKEN") catch return;
    defer allocator.free(token);

    const chat_id = std.process.getEnvVarOwned(allocator, "TELEGRAM_CHAT_ID") catch {
        allocator.free(token);
        return;
    };
    defer allocator.free(chat_id);

    // URL-encode the message
    var encoded_msg = try std.ArrayList(u8).initCapacity(allocator, msg.len * 2);
    defer encoded_msg.deinit();

    for (msg) |c| {
        switch (c) {
            ' ' => try encoded_msg.appendSlice("%20"),
            '#' => try encoded_msg.appendSlice("%23"),
            '&' => try encoded_msg.appendSlice("%26"),
            '=' => try encoded_msg.appendSlice("%3D"),
            '\n' => try encoded_msg.appendSlice("%0A"),
            else => try encoded_msg.append(c),
        }
    }

    const url_str = try std.fmt.allocPrint(allocator, "https://api.telegram.org/bot{s}/sendMessage?chat_id={s}&text={s}", .{ token, chat_id, encoded_msg.items });
    defer allocator.free(url_str);

    // HTTP client with 3-second connection timeout for Telegram API
    var client = std.http.Client{
        .allocator = allocator,
        .http_connect_timeout = 3000, // 3 seconds in milliseconds
    };
    defer client.deinit();

    const uri = std.Uri.parse(url_str) catch return;
    var req = client.request(.GET, uri, .{
        .redirect_behavior = .unhandled,
    }) catch return;
    defer req.deinit();

    // Receive response, ignore errors (best-effort notification)
    var redirect_buf: [0]u8 = .{};
    _ = req.receiveHead(&redirect_buf) catch {};
    _ = req.finish() catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOCAL WAVE 9 — Local Docker-based training
// ═══════════════════════════════════════════════════════════════════════════════
//
// Usage: tri farm local-wave9 <action> [options]
//
// Actions:
//   init           Initialize local farm (generate compose file, create directories)
//   start          Start workers (default: 4, --workers N for more)
//   stop           Stop all workers
//   status         Show worker status
//   restart        Restart workers
//   logs <worker>  Show logs for worker (e.g., w9-1)
//   recycle        Recycle crashed workers
//   clean          Remove all containers and volumes

fn runLocalWave9Command(allocator: Allocator, args: []const []const u8) !void {
    const action = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, action, "init")) {
        return localWave9Init(allocator);
    } else if (std.mem.eql(u8, action, "start")) {
        return localWave9Start(allocator, args[1..]);
    } else if (std.mem.eql(u8, action, "stop")) {
        return localWave9Stop(allocator, args[1..]);
    } else if (std.mem.eql(u8, action, "status")) {
        return localWave9Status(allocator);
    } else if (std.mem.eql(u8, action, "restart")) {
        return localWave9Restart(allocator, args[1..]);
    } else if (std.mem.eql(u8, action, "logs")) {
        return localWave9Logs(allocator, args[1..]);
    } else if (std.mem.eql(u8, action, "recycle")) {
        return localWave9Recycle(allocator, args[1..]);
    } else if (std.mem.eql(u8, action, "clean")) {
        return localWave9Clean(allocator);
    } else if (std.mem.eql(u8, action, "help") or std.mem.eql(u8, action, "--help")) {
        printLocalWave9Help();
    } else {
        print("{s}Unknown local-wave9 action: {s}{s}\n", .{ RED, action, RESET });
        printLocalWave9Help();
    }
}

fn localWave9Init(allocator: Allocator) !void {
    print("\n{s}🏠 LOCAL WAVE 9 — INITIALIZATION{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    const wave9_gen = @import("wave9_generator.zig");

    // Generate compose file with 48 workers
    const compose_file = "deploy/docker/docker-compose.wave9.yml";
    const compose = try wave9_gen.generateCompose(allocator, 48);
    defer allocator.free(compose);

    // Ensure directory exists
    const compose_dir = std.fs.path.dirname(compose_file) orelse ".";
    std.fs.cwd().makeDir(compose_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    // Write compose file
    const file = try std.fs.cwd().createFile(compose_file, .{});
    defer file.close();
    try file.writeAll(compose);

    print("  {s}✅{s} Generated compose file: {s}\n", .{ GREEN, RESET, compose_file });

    // Create data directories
    const wave9_dir = "data/wave9";
    std.fs.cwd().makeDir(wave9_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    for (1..49) |i| {
        const worker_dir = try std.fmt.allocPrint(allocator, "{s}/worker-{d}", .{ wave9_dir, i });
        defer allocator.free(worker_dir);
        std.fs.cwd().makeDir(worker_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }

    print("  {s}✅{s} Created worker directories: {s}\n", .{ GREEN, RESET, wave9_dir });

    // Initialize local farm state
    const local_farm_mod = @import("local_farm.zig");
    var farm = try local_farm_mod.LocalFarm.init(allocator);
    defer farm.deinit(allocator);

    // Add 48 workers
    for (1..49) |i| {
        try farm.addWorker(allocator, i, @as(u32, @intCast(1000 + i)));
    }

    try farm.save(allocator);
    print("  {s}✅{s} Initialized farm state: .trinity/local_farm.json\n", .{ GREEN, RESET });

    print("\n{s}✅ Local Wave 9 initialized!{s}\n", .{ GREEN, RESET });
    print("   Next: tri farm local-wave9 start --workers 4\n", .{});
}

fn localWave9Start(allocator: Allocator, args: []const []const u8) !void {
    var workers: usize = 4;
    var dry_run = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--workers") and i + 1 < args.len) {
            i += 1;
            workers = std.fmt.parseInt(usize, args[i], 10) catch 4;
        } else if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        }
    }

    if (workers > 48) {
        print("{s}⚠️  Max workers is 48, using 48{s}\n", .{ YELLOW, RESET });
        workers = 48;
    }

    print("\n{s}🚀 LOCAL WAVE 9 — STARTING {d} WORKERS{s}\n", .{ BOLD, workers, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    if (dry_run) {
        print("{s}DRY RUN — would start {d} workers{s}\n", .{ YELLOW, workers, RESET });
        print("   Workers: ", .{});
        for (1..@min(workers, 10) + 1) |j| {
            print("w9-{d} ", .{j});
        }
        if (workers > 10) print("...\n", .{});
        print("\n", .{});
        return;
    }

    const local_farm_mod = @import("local_farm.zig");
    const compose_file = "deploy/docker/docker-compose.wave9.yml";

    // Build workers to start
    var workers_to_start = try std.ArrayListUnmanaged([]const u8).initCapacity(allocator, workers);
    defer {
        for (workers_to_start.items) |w| allocator.free(w);
        workers_to_start.deinit(allocator);
    }

    for (1..workers + 1) |j| {
        const worker_name = try std.fmt.allocPrint(allocator, "w9-{d}", .{j});
        try workers_to_start.append(allocator, worker_name);
    }

    const result = try local_farm_mod.composeUp(allocator, compose_file, null);
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.exit_code != 0) {
        print("{s}❌ Failed to start workers{s}\n", .{ RED, RESET });
        print("  stdout: {s}\n", .{result.stdout});
        print("  stderr: {s}\n", .{result.stderr});
        return error.ComposeUpFailed;
    }

    // Update farm state
    var farm = local_farm_mod.LocalFarm.load(allocator) catch try local_farm_mod.LocalFarm.init(allocator);
    defer farm.deinit(allocator);

    const BASE_SEED: u32 = 1000;
    for (1..workers + 1) |j| {
        const seed = BASE_SEED + @as(u32, @intCast(j));
        if (farm.getWorker(j) == null) {
            try farm.addWorker(allocator, j, seed);
        }
        try farm.updateWorkerStatus(j, .starting);
    }
    try farm.save(allocator);

    print("  {s}✅{s} Started {d} workers\n", .{ GREEN, RESET, workers });
    print("   Monitor: tri farm local-wave9 status\n", .{});
    print("   Logs: tri farm local-wave9 logs w9-1\n", .{});
}

fn localWave9Stop(allocator: Allocator, args: []const []const u8) !void {
    _ = args;

    print("\n{s}🛑 LOCAL WAVE 9 — STOPPING WORKERS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    const local_farm_mod = @import("local_farm.zig");
    const compose_file = "deploy/docker/docker-compose.wave9.yml";

    const result = try local_farm_mod.composeStop(allocator, compose_file, null);
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.exit_code != 0) {
        print("{s}⚠️  Some workers may not have stopped{s}\n", .{ YELLOW, RESET });
        print("  stderr: {s}\n", .{result.stderr});
    }

    // Update farm state
    var farm = local_farm_mod.LocalFarm.load(allocator) catch try local_farm_mod.LocalFarm.init(allocator);
    defer farm.deinit(allocator);

    for (farm.workers.items) |*w| {
        w.status = .stopped;
    }
    try farm.save(allocator);

    print("  {s}✅{s} Workers stopped\n", .{ GREEN, RESET });
}

fn localWave9Status(allocator: Allocator) !void {
    const local_farm_mod = @import("local_farm.zig");

    print(">>> localWave9Status: loading farm...\n", .{});
    var farm = local_farm_mod.LocalFarm.load(allocator) catch |err| {
        print("{s}⚠️  Load failed: {s} - using empty farm{s}\n", .{ YELLOW, @errorName(err), RESET });
        const empty = try local_farm_mod.LocalFarm.init(allocator);
        empty.displayStatus();
        return;
    };
    defer farm.deinit(allocator);
    print(">>> localWave9Status: loaded farm, displaying...\n", .{});

    farm.displayStatus();
}

fn localWave9Restart(allocator: Allocator, args: []const []const u8) !void {
    _ = args;

    print("\n{s}🔄 LOCAL WAVE 9 — RESTARTING{s}\n", .{ BOLD, RESET });
    try localWave9Stop(allocator, &[_][]const u8{});
    std.Thread.sleep(2 * std.time.ns_per_s);
    try localWave9Start(allocator, &[_][]const u8{});
}

fn localWave9Logs(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        print("{s}Usage: tri farm local-wave9 logs <worker-name>{s}\n", .{ YELLOW, RESET });
        print("   Example: tri farm local-wave9 logs w9-1\n", .{});
        return;
    }

    const worker_name = args[0];
    print("\n{s}📋 LOGS — {s}{s}\n", .{ BOLD, worker_name, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Press Ctrl+C to exit\n\n", .{});

    const local_farm_mod = @import("local_farm.zig");
    const compose_file = "deploy/docker/docker-compose.wave9.yml";

    // Follow logs (blocks until Ctrl+C)
    const result = try local_farm_mod.composeLogs(allocator, compose_file, worker_name, true);
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.stdout.len > 0) print("{s}", .{result.stdout});
    if (result.stderr.len > 0) print("{s}", .{result.stderr});
}

fn localWave9Recycle(allocator: Allocator, args: []const []const u8) !void {
    _ = args;

    print("\n{s}♻️  LOCAL WAVE 9 — RECYCLING CRASHED{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    const local_farm_mod = @import("local_farm.zig");

    var farm = local_farm_mod.LocalFarm.load(allocator) catch try local_farm_mod.LocalFarm.init(allocator);
    defer farm.deinit(allocator);

    const compose_file = "deploy/docker/docker-compose.wave9.yml";

    var recycled: usize = 0;
    for (farm.workers.items) |*w| {
        if (w.status == .crashed) {
            const worker_name = try std.fmt.allocPrint(allocator, "w9-{d}", .{w.id});
            defer allocator.free(worker_name);

            print("  Recycling {s}...", .{worker_name});

            // Stop the worker
            _ = local_farm_mod.composeStop(allocator, compose_file, worker_name) catch {};

            // Start the worker
            const result = local_farm_mod.composeUp(allocator, compose_file, worker_name);
            if (result) |_| {
                w.status = .starting;
                w.crash_count += 1;
                recycled += 1;
                print(" {s}✅{s}\n", .{ GREEN, RESET });
            } else |err| {
                print(" {s}❌ {s}{s}\n", .{ RED, @errorName(err), RESET });
            }
        }
    }

    try farm.save(allocator);

    print("\n  {s}Recycled {d} crashed workers{s}\n", .{ BOLD, recycled, RESET });
}

fn localWave9Clean(allocator: Allocator) !void {
    print("\n{s}🧹 LOCAL WAVE 9 — CLEANUP{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    const local_farm_mod = @import("local_farm.zig");
    const compose_file = "deploy/docker/docker-compose.wave9.yml";

    const args = [_][]const u8{ "-f", compose_file, "down", "-v" };
    const result = try local_farm_mod.runDockerCompose(allocator, &args);
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.exit_code != 0) {
        print("  stdout: {s}\n", .{result.stdout});
        print("  stderr: {s}\n", .{result.stderr});
    }

    print("  {s}✅{s} Removed all containers and volumes\n", .{ GREEN, RESET });
}

fn printLocalWave9Help() void {
    print(
        \\
        \\Usage: tri farm local-wave9 <action> [options]
        \\
        \\Actions:
        \\  init              Initialize local farm (generate compose, create dirs)
        \\  start [--workers N] Start N workers (default: 4, max: 48)
        \\  stop              Stop all workers
        \\  status            Show worker status and metrics
        \\  restart           Restart all workers
        \\  logs <worker>     Show logs for worker (e.g., w9-1)
        \\  recycle           Recycle crashed workers
        \\  clean             Remove all containers and volumes
        \\
        \\Configuration:
        \\  S3 MultiObj profile:
        \\    NTP weight: 0.50, JEPA weight: 0.25, NCA weight: 0.25
        \\    Context length: 81, LR: 1e-3, Schedule: cosine
        \\    Optimizer: lamb, Batch: 66, Steps: 100K
        \\
        \\Data:
        \\  Checkpoints: data/wave9/worker-N/
        \\  Dataset: data/tinystories/ (TinyStories)
        \\
        \\Examples:
        \\  tri farm local-wave9 init
        \\  tri farm local-wave9 start --workers 8
        \\  tri farm local-wave9 status
        \\  tri farm local-wave9 logs w9-1
        \\
    , .{});
}

fn printHelp() void {
    print(
        \\
        \\Usage: tri farm <command> [options]
        \\
        \\Railway Commands:
        \\  status           Show all services across all Railway accounts (default)
        \\  idle             Show only finished/idle services (for recycling)
        \\  recycle          Set training vars + redeploy all idle services
        \\  fill             Create NEW services to fill empty slots (up to 25/account)
        \\  evolve           ASHA+PBT evolution (init/status/step/watch/history)
        \\  watch-daemon     24/7 autonomous monitoring (start/stop/status)
        \\  from-issues      Execute farm tasks from GitHub Issues (farm-task label)
        \\  stats            Farm statistics & simulation comparison (--farm only, --export csv, --scenario S1|S3|...)
        \\  analyze           Logs-based sacred worker analysis (uses Railway API)
        \\
        \\Fly.io Commands (Wave 9 Migration):
        \\  fly-init         Initialize Fly.io farm (discover accounts)
        \\  fly-deploy      Deploy Wave 9 to Fly.io (48 services, S3 MultiObj)
        \\  fly-status       Show all Wave 9 Fly.io training services
        \\  fly-recycle      Recycle crashed Wave 9 services with S3 MultiObj
        \\  wave9            Alias for fly-deploy
        \\
        \\Local Docker Commands (Wave 9):
        \\  local-wave9      Local Docker-based training (init/start/stop/status/logs/recycle/clean)
        \\
        \\Common options:
        \\  --lr <value>           Learning rate (default: 1e-3)
        \\  --batch <value>        Batch size (default: 66)
        \\  --ctx <value>          Context length (default: 27)
        \\  --optimizer <value>    Optimizer: lamb/adamw/adam (default: lamb)
        \\  --warmup <value>       Warmup steps (default: 2000)
        \\  --wd <value>           Weight decay (default: 0.01)
        \\  --steps <value>        Total steps (default: 100000)
        \\  --include-primary      Also include PRIMARY (default: skip)
        \\  --skip-ci              Skip CI gate (zig build test) before deploy
        \\
        \\Fill options:
        \\  --max <N>              Max new services to create (default: 37)
        \\  --dry-run              Show what would be created without doing it
        \\
        \\Fly.io options:
        \\  --dry-run              Show what would be deployed without doing it
        \\  --skip-existing         Skip apps that already exist
        \\  --seed-start <N>       Starting seed number (default: 901)
        \\  --region <region>      Primary region (default: iad)
        \\
        \\Schedule is ALWAYS cosine (hardcoded, never flat).
        \\Railway accounts: auto-discovered from env (RAILWAY_API_TOKEN[_N], N=2..8)
        \\Fly.io accounts: auto-discovered from env (FLY_API_TOKEN[_N], N=1..4)
        \\
    , .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// FLY-INIT — Initialize Fly.io farm
// ═══════════════════════════════════════════════════════════════════════════════

fn runFlyInit(allocator: Allocator) !void {
    print("\n{s}✈️  FLY.IO FARM INITIALIZATION{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    // Check flyctl
    const flyctl_wrapper = @import("flyctl_wrapper.zig");
    try flyctl_wrapper.checkPrerequisites(allocator);

    // Initialize farm
    const fly_farm_mod = @import("fly_farm.zig");
    var farm = fly_farm_mod.FlyFarm.init();
    const capacity = farm.totalCapacity();

    print("{s}Farm Status:{s}\n", .{ BOLD, RESET });
    print("  Accounts discovered: {d}\n", .{farm.account_count});
    print("  Active apps: {d}\n", .{capacity.total_active});
    print("  Available slots: {d}\n", .{capacity.total_slots});
    print("  Daily creates remaining: {d}\n", .{capacity.total_daily_remaining});
    print("\n", .{});

    // List each account
    for (farm.accounts[0..farm.account_count]) |*acct| {
        print("  {s}Account {d}: {s}{s}\n", .{ CYAN, acct.id, acct.getAlias(), RESET });
        print("    Suffix: {s}\n", .{acct.getSuffix()});
        print("    Active apps: {d}/{d}\n", .{ acct.active_apps, acct.max_concurrent });
        print("    Daily creates: {d}/{d}\n", .{ acct.daily_creates, acct.max_daily_creates });
        print("    Available slots: {d}\n", .{acct.availableSlots()});
        print("\n", .{});
    }

    print("{s}✅ Fly.io farm initialized{s}\n", .{ GREEN, RESET });
    print("   Next: tri farm fly-deploy  (or 'tri farm wave9')\n", .{});
}

test "farm command help" {
    printHelp();
}
