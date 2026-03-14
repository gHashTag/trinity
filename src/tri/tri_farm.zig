// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI FARM — Railway Training Farm Management (3 accounts)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Native Zig replacement for Python/curl farm queries and deployments.
// Uses RailwayApi.initWithSuffix() for multi-account support.
//
// Commands:
//   tri farm status   — table of all services across 3 accounts
//   tri farm idle     — only finished/idle services (for recycling)
//   tri farm recycle  — set training vars + redeploy all idle services
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const railway_api = @import("railway_api.zig");
const RailwayApi = railway_api.RailwayApi;

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const DIM = "\x1b[2m";
const CYAN = "\x1b[36m";

const Account = struct {
    name: []const u8,
    suffix: []const u8,
    env_id: []const u8,
    project_id: []const u8,
};

const farm_accounts = [_]Account{
    .{ .name = "PRIMARY", .suffix = "", .env_id = "6748f1ad-9c2f-4b71-9a90-67f40ce34dc9", .project_id = "aa0efa7f-95e6-4466-8de6-43945a031365" },
    .{ .name = "FARM-2", .suffix = "_2", .env_id = "d8602284-9bba-48bc-94f5-470f9d1fff48", .project_id = "ca4303d2-4a09-4143-b725-9a3f3977118f" },
    .{ .name = "FARM-3", .suffix = "_3", .env_id = "912e9084-e1ad-4bf1-aaea-0a77f9b2a158", .project_id = "292e8862-11ce-4542-aff8-35a41e6b3217" },
};

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
    } else if (std.mem.eql(u8, subcmd, "evolve")) {
        const tri_farm_evolve = @import("tri_farm_evolve.zig");
        return tri_farm_evolve.runEvolveCommand(allocator, args[1..]);
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

    for (farm_accounts) |acct| {
        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch |err| {
            print("{s}=== {s} ==={s}\n", .{ BOLD, acct.name, RESET });
            print("  {s}⚠️  No token ({s} error){s}\n\n", .{ YELLOW, @errorName(err), RESET });
            continue;
        };
        defer api.deinit();

        print("{s}=== {s} ==={s}\n", .{ BOLD, acct.name, RESET });

        const resp = api.getServiceInstances(acct.env_id) catch |err| {
            print("  {s}⚠️  API error: {s}{s}\n\n", .{ RED, @errorName(err), RESET });
            continue;
        };
        defer allocator.free(resp);

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
    print("{s}TOTAL: {d} services | 🟢 {d} active | 💤 {d} idle | 🔴 {d} crashed{s}\n\n", .{
        BOLD, total_services, total_active, total_idle, total_crashed, RESET,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// RECYCLE — set training vars + redeploy idle/crashed services
// ═══════════════════════════════════════════════════════════════════════════════
//
// Usage: tri farm recycle [--lr 3e-4] [--batch 128] [--ctx 81] [--optimizer lamb]
//                         [--warmup 2000] [--wd 0.01] [--steps 100000]
//                         [--include-primary] [--force]
//
// Finds idle (REMOVED/NONE) and crashed (CRASHED/FAILED) services and redeploys.
// Use --force to also recycle SUCCESS (running) services.

pub fn runFarmRecycle(allocator: Allocator, args: []const []const u8) !void {
    // Parse optional overrides
    var lr: []const u8 = "3e-4";
    var batch: []const u8 = "128";
    var ctx: []const u8 = "81";
    var optimizer: []const u8 = "lamb";
    var warmup: []const u8 = "2000";
    var wd: []const u8 = "0.01";
    var steps: []const u8 = "100000";
    var skip_primary = true; // default: skip PRIMARY (old image)

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
        }
    }

    print("\n{s}🔄 FARM RECYCLE — Wave 6{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Config: LR={s} batch={s} ctx={s} opt={s} warmup={s} wd={s} steps={s}\n", .{
        lr, batch, ctx, optimizer, warmup, wd, steps,
    });
    print("  Schedule: cosine (always)\n", .{});
    if (skip_primary) print("  {s}Skipping PRIMARY (old image){s}\n", .{ YELLOW, RESET });
    print("\n", .{});

    var deployed: usize = 0;
    var skipped: usize = 0;
    var errors: usize = 0;
    var seed_counter: u32 = 601;

    for (farm_accounts) |acct| {
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

            if (!isIdleStatus(dep_status) and !isCrashedStatus(dep_status)) {
                print("  ⏭️  {s}: {s} (active, skip)\n", .{ svc_name, dep_status });
                skipped += 1;
                continue;
            }

            // Set training variables via variableCollectionUpsert
            const seed_str = std.fmt.allocPrint(allocator, "{d}", .{seed_counter}) catch continue;
            defer allocator.free(seed_str);
            seed_counter += 1;

            const set_vars_gql = "mutation($input: VariableCollectionUpsertInput!) { variableCollectionUpsert(input: $input) }";
            const set_vars_json = std.fmt.allocPrint(allocator,
                \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","variables":{{"HSLM_LR":"{s}","HSLM_BATCH":"{s}","HSLM_CONTEXT":"{s}","HSLM_SEED":"{s}","HSLM_STEPS":"{s}","HSLM_OPTIMIZER":"{s}","HSLM_LR_SCHEDULE":"cosine","HSLM_FRESH":"1","HSLM_WARMUP":"{s}","HSLM_WD":"{s}","HSLM_CHECKPOINT_EVERY":"10000","HSLM_GRAD_ACCUM":"1","HSLM_DROPOUT":"0","HSLM_ADAPTIVE_SPARSITY":"0","HSLM_FULL_TERNARY":"0","HSLM_STE":"0","HSLM_TERNARY_SCHEDULE":"0","HSLM_TERNARY_GRADS":"0","HSLM_LABEL_SMOOTHING":"0","RAILWAY_DOCKERFILE_PATH":"Dockerfile.hslm-train"}}}}}}
            , .{
                acct.project_id, svc_id, acct.env_id,
                lr,              batch,  ctx,
                seed_str,        steps,  optimizer,
                warmup,          wd,
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

    for (farm_accounts) |acct| {
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
                \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","variables":{{"HSLM_LR":"{s}","HSLM_BATCH":"{s}","HSLM_CONTEXT":"{s}","HSLM_SEED":"{s}","HSLM_STEPS":"{s}","HSLM_OPTIMIZER":"{s}","HSLM_LR_SCHEDULE":"cosine","HSLM_FRESH":"1","HSLM_WARMUP":"{s}","HSLM_WD":"{s}","HSLM_CHECKPOINT_EVERY":"10000","HSLM_GRAD_ACCUM":"1","HSLM_DROPOUT":"0","HSLM_ADAPTIVE_SPARSITY":"0","HSLM_FULL_TERNARY":"0","HSLM_STE":"0","HSLM_TERNARY_SCHEDULE":"0","HSLM_TERNARY_GRADS":"0","HSLM_LABEL_SMOOTHING":"0","RAILWAY_DOCKERFILE_PATH":"Dockerfile.hslm-train"}}}}}}
            , .{
                acct.project_id, new_svc_id, acct.env_id,
                lr,              batch,      ctx,
                seed_str,        steps,      optimizer,
                warmup,          wd,
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

fn printHelp() void {
    print(
        \\
        \\Usage: tri farm <command> [options]
        \\
        \\Commands:
        \\  status           Show all services across 3 Railway accounts (default)
        \\  idle             Show only finished/idle services (for recycling)
        \\  recycle          Set training vars + redeploy all idle services
        \\  fill             Create NEW services to fill empty slots (up to 25/account)
        \\  help             Show this help
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
        \\
        \\Fill options:
        \\  --max <N>              Max new services to create (default: 37)
        \\  --dry-run              Show what would be created without doing it
        \\
        \\Schedule is ALWAYS cosine (hardcoded, never flat).
        \\Accounts: PRIMARY (RAILWAY_API_TOKEN), FARM-2 (_2), FARM-3 (_3)
        \\
    , .{});
}

test "farm command help" {
    printHelp();
}
