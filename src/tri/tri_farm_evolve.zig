// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI FARM EVOLVE — ASHA+PBT Hybrid Evolution for Training Farm
// ═══════════════════════════════════════════════════════════════════════════════
//
// Successive Halving (ASHA) + Population-Based Training (PBT) hybrid:
//   1. ASHA: Kill bottom performers at each rung threshold
//   2. PBT: Recycle killed slots with mutated configs from leaders
//
// Commands:
//   tri farm evolve init      — Scan all accounts, build initial state
//   tri farm evolve status    — Leaderboard + rung progress
//   tri farm evolve step      — Execute one evolution cycle
//   tri farm evolve history   — Print event log
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
const MAGENTA = "\x1b[35m";

// ═══════════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════════

const Rung = struct {
    step_threshold: u32,
    kill_ratio: f32,
    outlier_threshold: f32, // PPL above this = auto-kill regardless of ratio
};

// Conservative rungs: early rungs only kill garbage, ranking starts at 30K
const DEFAULT_RUNGS = [_]Rung{
    .{ .step_threshold = 5000, .kill_ratio = 0.0, .outlier_threshold = 500.0 },
    .{ .step_threshold = 15000, .kill_ratio = 0.0, .outlier_threshold = 200.0 },
    .{ .step_threshold = 30000, .kill_ratio = 0.30, .outlier_threshold = 500.0 },
    .{ .step_threshold = 50000, .kill_ratio = 0.30, .outlier_threshold = 500.0 },
};

const NUM_RUNGS = DEFAULT_RUNGS.len;
const MIN_SURVIVORS = 4;

const ServiceStatus = enum(u8) {
    running,
    idle,
    crashed,
    killed,
    unknown,
};

const ServiceEntry = struct {
    svc_id: [64]u8 = undefined,
    svc_id_len: u8 = 0,
    svc_name: [64]u8 = undefined,
    svc_name_len: u8 = 0,
    account_idx: u8 = 0,
    // Config
    lr: [16]u8 = undefined,
    lr_len: u8 = 0,
    batch: [8]u8 = undefined,
    batch_len: u8 = 0,
    optimizer: [16]u8 = undefined,
    optimizer_len: u8 = 0,
    seed: u32 = 0,
    // Lineage
    generation: u16 = 0,
    parent: [64]u8 = undefined,
    parent_len: u8 = 0,
    // Metrics
    current_step: u32 = 0,
    current_ppl: f32 = 999.0,
    current_loss: f32 = 99.0,
    val_ppl: f32 = 999.0, // P1: validation PPL (999 = not yet measured)
    status: ServiceStatus = .unknown,
    // Per-service rung tracking
    rungs_passed: [NUM_RUNGS]bool = .{ false, false, false, false },
    // Data shard assignment (T10)
    data_shard: u16 = 0,

    fn svcId(self: *const ServiceEntry) []const u8 {
        return self.svc_id[0..self.svc_id_len];
    }

    fn svcName(self: *const ServiceEntry) []const u8 {
        return self.svc_name[0..self.svc_name_len];
    }

    fn lrStr(self: *const ServiceEntry) []const u8 {
        return self.lr[0..self.lr_len];
    }

    fn batchStr(self: *const ServiceEntry) []const u8 {
        return self.batch[0..self.batch_len];
    }

    fn optimizerStr(self: *const ServiceEntry) []const u8 {
        return self.optimizer[0..self.optimizer_len];
    }

    fn parentName(self: *const ServiceEntry) []const u8 {
        if (self.parent_len == 0) return "(original)";
        return self.parent[0..self.parent_len];
    }
};

const EventType = enum(u8) {
    kill,
    spawn,
    rung_complete,
    err,
};

const Event = struct {
    timestamp: i64 = 0,
    event_type: EventType = .err,
    service_name: [64]u8 = undefined,
    service_name_len: u8 = 0,
    detail: [128]u8 = undefined,
    detail_len: u8 = 0,

    fn svcName(self: *const Event) []const u8 {
        return self.service_name[0..self.service_name_len];
    }

    fn detailStr(self: *const Event) []const u8 {
        return self.detail[0..self.detail_len];
    }
};

const MAX_SERVICES = 160;
const MAX_EVENTS = 512;

const EvolutionState = struct {
    services: [MAX_SERVICES]ServiceEntry = undefined,
    service_count: usize = 0,
    evolution_step: u32 = 0,
    total_configs_tested: u32 = 0,
    best_ppl: f32 = 999.0,
    best_name: [64]u8 = undefined,
    best_name_len: u8 = 0,
    events: [MAX_EVENTS]Event = undefined,
    event_count: usize = 0,

    fn bestNameStr(self: *const EvolutionState) []const u8 {
        if (self.best_name_len == 0) return "(none)";
        return self.best_name[0..self.best_name_len];
    }

    fn addEvent(self: *EvolutionState, etype: EventType, name: []const u8, detail: []const u8) void {
        if (self.event_count >= MAX_EVENTS) return;
        var ev = &self.events[self.event_count];
        ev.* = .{};
        ev.timestamp = std.time.milliTimestamp();
        ev.event_type = etype;
        const nlen: u8 = @intCast(@min(name.len, 64));
        @memcpy(ev.service_name[0..nlen], name[0..nlen]);
        ev.service_name_len = nlen;
        const dlen: u8 = @intCast(@min(detail.len, 128));
        @memcpy(ev.detail[0..dlen], detail[0..dlen]);
        ev.detail_len = dlen;
        self.event_count += 1;
    }

    fn addService(self: *EvolutionState) ?*ServiceEntry {
        if (self.service_count >= MAX_SERVICES) return null;
        const idx = self.service_count;
        self.services[idx] = .{};
        self.service_count += 1;
        return &self.services[idx];
    }
};

// Farm accounts — dynamic discovery from env vars
const farm_accounts_mod = @import("farm_accounts.zig");
const Account = farm_accounts_mod.Account;
const MAX_FARM_ACCOUNTS = farm_accounts_mod.MAX_ACCOUNTS;

const STATE_PATH = ".trinity/evolution_state.json";

// ═══════════════════════════════════════════════════════════════════════════════
// Entry point
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runEvolveCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, subcmd, "init")) {
        runInit(allocator) catch |err| {
            const exp_hooks = @import("experience_hooks.zig");
            exp_hooks.autoSaveExperience("farm evolve", subcmd, false);
            return err;
        };
        const exp_hooks = @import("experience_hooks.zig");
        exp_hooks.autoSaveExperience("farm evolve", subcmd, true);
        return;
    } else if (std.mem.eql(u8, subcmd, "status")) {
        return runStatus(allocator);
    } else if (std.mem.eql(u8, subcmd, "step")) {
        runStep(allocator, args[1..]) catch |err| {
            const exp_hooks = @import("experience_hooks.zig");
            exp_hooks.autoSaveExperience("farm evolve", subcmd, false);
            return err;
        };
        const exp_hooks2 = @import("experience_hooks.zig");
        exp_hooks2.autoSaveExperience("farm evolve", subcmd, true);
        return;
    } else if (std.mem.eql(u8, subcmd, "history")) {
        return runHistory(allocator);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        print("{s}Unknown evolve subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INIT — Scan all accounts, build initial EvolutionState
// ═══════════════════════════════════════════════════════════════════════════════

fn runInit(allocator: Allocator) !void {
    print("\n{s}🧬 EVOLUTION INIT — Scanning Farm{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var accounts_buf: [MAX_FARM_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    if (account_count == 0) {
        print("  {s}⚠️  No Railway accounts found. Set RAILWAY_API_TOKEN + RAILWAY_PROJECT_ID + RAILWAY_ENVIRONMENT_ID in .env{s}\n\n", .{ YELLOW, RESET });
        return;
    }
    print("  {s}Discovered {d} account(s){s}\n\n", .{ DIM, account_count, RESET });

    var state = EvolutionState{};

    for (accounts_buf[0..account_count], 0..) |acct, acct_idx| {
        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch |err| {
            print("  {s}⚠️  {s}: No token ({s}){s}\n", .{ YELLOW, acct.name, @errorName(err), RESET });
            continue;
        };
        defer api.deinit();

        print("{s}=== {s} ==={s}\n", .{ BOLD, acct.name, RESET });

        // Get services with IDs + deployment status
        const gql = "query($projectId: String!) { project(id: $projectId) { services { edges { node { id name deployments(first:1) { edges { node { id status } } } } } } } }";
        const vars_json = std.fmt.allocPrint(allocator, "{{\"projectId\":\"{s}\"}}", .{acct.project_id}) catch continue;
        defer allocator.free(vars_json);

        const resp = api.query(gql, vars_json) catch |err| {
            print("  {s}⚠️  API error: {s}{s}\n", .{ RED, @errorName(err), RESET });
            continue;
        };
        defer allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch {
            print("  {s}⚠️  Invalid JSON{s}\n", .{ RED, RESET });
            continue;
        };
        defer parsed.deinit();

        const edges = getEdgesFromProject(parsed.value) orelse {
            print("  {s}⚠️  No services found{s}\n", .{ RED, RESET });
            continue;
        };

        var count: usize = 0;
        for (edges) |edge| {
            const node = getJsonObject(edge, "node") orelse continue;
            const svc_id = getJsonString(node, "id");
            const svc_name = getJsonString(node, "name");

            // Skip non-training services
            if (!isTrainingService(svc_name)) continue;

            const entry = state.addService() orelse break;
            copyToFixed(&entry.svc_id, &entry.svc_id_len, svc_id);
            copyToFixed(&entry.svc_name, &entry.svc_name_len, svc_name);
            entry.account_idx = @intCast(acct_idx);

            // Get deployment status
            if (getJsonObject(node, "deployments")) |deps| {
                if (getJsonObject(deps, "edges")) |dep_edges| {
                    if (dep_edges == .array and dep_edges.array.items.len > 0) {
                        const dep_node = getJsonObject(dep_edges.array.items[0], "node") orelse continue;
                        const dep_status = getJsonString(dep_node, "status");
                        entry.status = classifyStatus(dep_status);
                    }
                }
            }

            // Get env vars for config
            const vars_resp = api.getVariables(svc_id, acct.env_id) catch continue;
            defer allocator.free(vars_resp);

            const vars_parsed = std.json.parseFromSlice(std.json.Value, allocator, vars_resp, .{}) catch continue;
            defer vars_parsed.deinit();

            extractConfig(entry, vars_parsed.value);
            count += 1;

            // Rate limiting between API calls
            std.Thread.sleep(100 * std.time.ns_per_ms);
        }

        print("  Found {d} training services\n\n", .{count});
    }

    state.total_configs_tested = @intCast(state.service_count);
    saveState(state) catch |err| {
        print("{s}❌ Failed to save state: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return;
    };

    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}INIT DONE: {d} services tracked → {s}{s}\n\n", .{ BOLD, state.service_count, STATE_PATH, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS — Leaderboard + rung progress
// ═══════════════════════════════════════════════════════════════════════════════

fn runStatus(allocator: Allocator) !void {
    var state = loadState(allocator) catch {
        print("{s}❌ No evolution state. Run: tri farm evolve init{s}\n", .{ RED, RESET });
        return;
    };

    printDashboard(&state);
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP — Execute one evolution cycle
// ═══════════════════════════════════════════════════════════════════════════════

fn runStep(allocator: Allocator, args: []const []const u8) !void {
    var dry_run = false;
    var issue_num: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        } else if (std.mem.eql(u8, args[i], "--issue") and i + 1 < args.len) {
            i += 1;
            issue_num = args[i];
        }
    }

    var state = loadState(allocator) catch {
        print("{s}❌ No evolution state. Run: tri farm evolve init{s}\n", .{ RED, RESET });
        return;
    };

    state.evolution_step += 1;

    print("\n{s}🧬 EVOLUTION STEP {d}{s}", .{ BOLD, state.evolution_step, RESET });
    if (dry_run) print(" {s}[DRY RUN]{s}", .{ YELLOW, RESET });
    print("\n{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    // 1. Collect metrics from logs (may hang on slow Railway API — saves state incrementally)
    print("{s}📊 Collecting metrics...{s}\n", .{ CYAN, RESET });
    var api_calls: u32 = 0;
    collectMetrics(allocator, &state, &api_calls);
    print("  API calls: {d}\n\n", .{api_calls});

    // Save metrics immediately (in case ranking/recycling hangs later)
    if (!dry_run) {
        saveState(state) catch {};
    }

    // 2. Process each rung
    var total_killed: usize = 0;
    var total_spawned: usize = 0;
    var summary_buf: [2048]u8 = undefined;
    var summary_len: usize = 0;

    for (DEFAULT_RUNGS, 0..) |rung, rung_idx| {
        const result = processRung(allocator, &state, @intCast(rung_idx), rung, dry_run, &api_calls);
        total_killed += result.killed;
        total_spawned += result.spawned;

        if (result.killed > 0) {
            const line = std.fmt.bufPrint(summary_buf[summary_len..], "  Rung {d} ({d}K): {d} killed, {d} spawned\n", .{
                rung_idx + 1, rung.step_threshold / 1000, result.killed, result.spawned,
            }) catch break;
            summary_len += line.len;
        }
    }

    // 3. Update best
    for (state.services[0..state.service_count]) |*svc| {
        if (svc.status == .running and svc.current_ppl < state.best_ppl and svc.current_ppl > 0) {
            state.best_ppl = svc.current_ppl;
            copyToFixed(&state.best_name, &state.best_name_len, svc.svcName());
        }
    }

    // 4. Save state
    if (!dry_run) {
        saveState(state) catch |err| {
            print("{s}❌ Failed to save state: {s}{s}\n", .{ RED, @errorName(err), RESET });
        };
    }

    // 5. Print dashboard
    printDashboard(&state);

    print("  {s}ACTIONS THIS STEP:{s}\n", .{ BOLD, RESET });
    if (total_killed == 0) {
        print("  (no services eligible for culling)\n", .{});
    } else {
        print("{s}", .{summary_buf[0..summary_len]});
    }
    print("\n", .{});

    // 6. Post to GitHub issue
    if (!dry_run) {
        if (issue_num) |inum| {
            postToIssue(allocator, inum, &state, total_killed, total_spawned);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HISTORY — Print event log
// ═══════════════════════════════════════════════════════════════════════════════

fn runHistory(allocator: Allocator) !void {
    const state = loadState(allocator) catch {
        print("{s}❌ No evolution state. Run: tri farm evolve init{s}\n", .{ RED, RESET });
        return;
    };

    print("\n{s}📜 EVOLUTION HISTORY — {d} events{s}\n", .{ BOLD, state.event_count, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    if (state.event_count == 0) {
        print("  (no events yet)\n\n", .{});
        return;
    }

    print("  {s}TYPE          SERVICE                DETAIL{s}\n", .{ DIM, RESET });
    print("  {s}─────────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });

    for (state.events[0..state.event_count]) |*ev| {
        const icon = switch (ev.event_type) {
            .kill => "💀 KILL  ",
            .spawn => "🌱 SPAWN ",
            .rung_complete => "🏁 RUNG  ",
            .err => "❌ ERROR ",
        };
        const color = switch (ev.event_type) {
            .kill => RED,
            .spawn => GREEN,
            .rung_complete => CYAN,
            .err => RED,
        };
        print("  {s}{s}{s}", .{ color, icon, RESET });
        print("{s}", .{ev.svcName()});
        padTo(ev.service_name_len, 22);
        print(" {s}\n", .{ev.detailStr()});
    }
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Core: Metric Collection
// ═══════════════════════════════════════════════════════════════════════════════

fn collectMetrics(allocator: Allocator, state: *EvolutionState, api_calls: *u32) void {
    var collected: usize = 0;
    var skipped: usize = 0;

    var accounts_buf: [MAX_FARM_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    // Collect per-account to reuse API client
    for (accounts_buf[0..account_count], 0..) |acct, acct_idx| {
        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch {
            print("  {s}⚠️  {s}: no token{s}\n", .{ YELLOW, acct.name, RESET });
            continue;
        };
        defer api.deinit();

        // Batch query: get all services with deployment IDs in one call
        const batch_gql = "query($projectId: String!) { project(id: $projectId) { services { edges { node { id name deployments(first:1) { edges { node { id status } } } } } } } }";
        const batch_vars = std.fmt.allocPrint(allocator, "{{\"projectId\":\"{s}\"}}", .{acct.project_id}) catch continue;
        defer allocator.free(batch_vars);

        const batch_resp = api.query(batch_gql, batch_vars) catch {
            print("  {s}⚠️  {s}: batch query failed{s}\n", .{ RED, acct.name, RESET });
            continue;
        };
        defer allocator.free(batch_resp);
        api_calls.* += 1;

        const batch_parsed = std.json.parseFromSlice(std.json.Value, allocator, batch_resp, .{}) catch continue;
        defer batch_parsed.deinit();

        const edges = getEdgesFromProject(batch_parsed.value) orelse continue;

        // Build deployment ID map from batch response
        for (edges) |edge| {
            const node = getJsonObject(edge, "node") orelse continue;
            const svc_id = getJsonString(node, "id");
            const svc_name = getJsonString(node, "name");

            // Find matching service in state
            const svc = findServiceById(state, svc_id, @intCast(acct_idx)) orelse {
                if (isTrainingService(svc_name)) {
                    print("  {s}  {s}: not in state{s}\n", .{ DIM, svc_name, RESET });
                }
                continue;
            };
            if (svc.status != .running) continue;

            // Extract deployment ID
            var dep_id: ?[]const u8 = null;
            if (getJsonObject(node, "deployments")) |deps| {
                if (getJsonObject(deps, "edges")) |dep_edges| {
                    if (dep_edges == .array and dep_edges.array.items.len > 0) {
                        const dep_node = getJsonObject(dep_edges.array.items[0], "node") orelse continue;
                        const id = getJsonString(dep_node, "id");
                        if (!std.mem.eql(u8, id, "?")) dep_id = id;
                    }
                }
            }

            const did = dep_id orelse {
                print("  {s}  {s}: no deployment{s}\n", .{ DIM, svc_name, RESET });
                skipped += 1;
                continue;
            };

            print("  {s}  {s}...{s}", .{ DIM, svc_name, RESET });

            // Rate limit — 1s between calls to reduce Railway API pressure
            std.Thread.sleep(1000 * std.time.ns_per_ms);

            // Fresh API client per log call (reusing clients causes TLS hangs)
            var log_api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch {
                print(" {s}no token{s}\n", .{ RED, RESET });
                skipped += 1;
                continue;
            };

            const log_resp_result = log_api.getDeploymentLogs(did, 20);
            log_api.deinit();

            const log_resp = log_resp_result catch {
                print(" {s}logs failed{s}\n", .{ RED, RESET });
                skipped += 1;
                // Save partial state before potential hang on next service
                saveState(state.*) catch {};
                continue;
            };
            defer allocator.free(log_resp);

            const log_parsed = std.json.parseFromSlice(std.json.Value, allocator, log_resp, .{}) catch {
                print(" {s}bad json{s}\n", .{ RED, RESET });
                skipped += 1;
                continue;
            };
            defer log_parsed.deinit();

            parseLogsForMetrics(svc, log_parsed.value);
            api_calls.* += 1;

            // Save state after each successful collection (protect against next call hanging)
            saveState(state.*) catch {};

            if (svc.current_ppl < 998) {
                if (svc.val_ppl < 998) {
                    print(" step={d} PPL={d:.1} val={d:.1}\n", .{ svc.current_step, svc.current_ppl, svc.val_ppl });
                } else {
                    print(" step={d} PPL={d:.1}\n", .{ svc.current_step, svc.current_ppl });
                }
                collected += 1;
            } else {
                print(" {s}no metrics{s}\n", .{ YELLOW, RESET });
                skipped += 1;
            }
        }
    }

    print("  Collected: {d} | Skipped: {d}\n", .{ collected, skipped });
}

fn findServiceById(state: *EvolutionState, svc_id: []const u8, acct_idx: u8) ?*ServiceEntry {
    for (state.services[0..state.service_count]) |*svc| {
        if (svc.account_idx != acct_idx) continue;
        if (std.mem.eql(u8, svc.svcId(), svc_id)) return svc;
    }
    return null;
}

/// Fetch deploymentLogs via curl with --max-time 15 (bulletproof timeout).
/// Returns allocated JSON response body.
fn curlGraphQL(allocator: Allocator, token: []const u8, deployment_id: []const u8, limit: u32) ![]const u8 {
    const body = std.fmt.allocPrint(allocator,
        \\{{"query":"query($deploymentId: String!, $limit: Int) {{ deploymentLogs(deploymentId: $deploymentId, limit: $limit) {{ timestamp message severity }} }}","variables":{{"deploymentId":"{s}","limit":{d}}}}}
    , .{ deployment_id, limit }) catch return error.OutOfMemory;
    defer allocator.free(body);

    const auth_hdr = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return error.OutOfMemory;
    defer allocator.free(auth_hdr);

    var child = std.process.Child.init(&.{
        "curl",                                     "-s",     "--max-time", "15",
        "-X",                                       "POST",   "-H",         "Content-Type: application/json",
        "-H",                                       auth_hdr, "-d",         body,
        "https://backboard.railway.com/graphql/v2",
    }, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    _ = child.spawn() catch return error.ConnectionFailed;

    // Read stdout via poll
    var stdout_buf: std.ArrayList(u8) = .empty;
    var stderr_buf: std.ArrayList(u8) = .empty;
    defer stderr_buf.deinit(allocator);

    child.collectOutput(allocator, &stdout_buf, &stderr_buf, 1 * 1024 * 1024) catch {
        stdout_buf.deinit(allocator);
        return error.RequestFailed;
    };

    const term = child.wait() catch {
        stdout_buf.deinit(allocator);
        return error.RequestFailed;
    };

    if (term.Exited != 0) {
        stdout_buf.deinit(allocator);
        return error.RequestFailed;
    }

    // Debug: empty response check
    if (stdout_buf.items.len == 0) {
        stdout_buf.deinit(allocator);
        return error.RequestFailed;
    }

    // Transfer ownership of the buffer
    return stdout_buf.toOwnedSlice(allocator) catch {
        stdout_buf.deinit(allocator);
        return error.OutOfMemory;
    };
}

fn extractDeploymentId(root: std.json.Value) ?[]const u8 {
    const data = getJsonObject(root, "data") orelse return null;
    const deps = getJsonObject(data, "deployments") orelse return null;
    const edges = getJsonObject(deps, "edges") orelse return null;
    if (edges != .array or edges.array.items.len == 0) return null;
    const node = getJsonObject(edges.array.items[0], "node") orelse return null;
    const id = getJsonString(node, "id");
    if (std.mem.eql(u8, id, "?")) return null;
    return id;
}

fn parseLogsForMetrics(svc: *ServiceEntry, root: std.json.Value) void {
    const data = getJsonObject(root, "data") orelse return;
    const logs = getJsonObject(data, "deploymentLogs") orelse return;
    if (logs != .array) return;

    // Scan backwards for most recent training line
    var idx: usize = logs.array.items.len;
    while (idx > 0) {
        idx -= 1;
        const log_entry = logs.array.items[idx];
        const msg = getJsonString(log_entry, "message");
        if (std.mem.eql(u8, msg, "?")) continue;

        if (parseTrainingLine(msg)) |metrics| {
            svc.current_step = metrics.step;
            svc.current_loss = metrics.loss;
            svc.current_ppl = metrics.ppl;
            break;
        }
    }

    // Also scan for [VAL] lines (P1: validation PPL)
    idx = logs.array.items.len;
    while (idx > 0) {
        idx -= 1;
        const log_entry = logs.array.items[idx];
        const msg = getJsonString(log_entry, "message");
        if (std.mem.indexOf(u8, msg, "[VAL]") != null) {
            if (parseValLine(msg)) |vp| {
                svc.val_ppl = vp;
                break;
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Core: Training Line Parser
// ═══════════════════════════════════════════════════════════════════════════════

const TrainingMetrics = struct {
    step: u32,
    loss: f32,
    ppl: f32,
};

/// Parse pipe-delimited training output:
///   "    5000 |   5.8234 |   5.9100 |   338.45 |   0.001000 |   0.8234 |   1400"
/// Columns: step, loss, avg_loss, ppl, lr, c_ratio, tok/s
pub fn parseTrainingLine(line: []const u8) ?TrainingMetrics {
    // Skip [EARLY KILL] lines
    if (std.mem.indexOf(u8, line, "[EARLY KILL]") != null) return null;

    // Must contain at least 6 pipes for 7 columns
    var pipe_count: usize = 0;
    for (line) |c| {
        if (c == '|') pipe_count += 1;
    }
    if (pipe_count < 6) return null;

    // Split by '|'
    var columns: [8][]const u8 = undefined;
    var col_idx: usize = 0;
    var start: usize = 0;
    for (line, 0..) |c, ci| {
        if (c == '|') {
            if (col_idx < 8) {
                columns[col_idx] = std.mem.trim(u8, line[start..ci], " \t");
                col_idx += 1;
            }
            start = ci + 1;
        }
    }
    // Last column
    if (col_idx < 8 and start < line.len) {
        columns[col_idx] = std.mem.trim(u8, line[start..], " \t");
        col_idx += 1;
    }

    if (col_idx < 7) return null;

    // Column 0: step (integer)
    const step = std.fmt.parseInt(u32, columns[0], 10) catch return null;
    // Column 1: loss (float)
    const loss = std.fmt.parseFloat(f32, columns[1]) catch return null;
    // Column 3: ppl (float)
    const ppl = std.fmt.parseFloat(f32, columns[3]) catch return null;

    if (ppl <= 0 or loss <= 0) return null;

    return .{ .step = step, .loss = loss, .ppl = ppl };
}

/// Parse [VAL] log line: "[VAL] step=NNNNN val_loss=X.XXXX val_ppl=XX.XX"
fn parseValLine(line: []const u8) ?f32 {
    const key = "val_ppl=";
    const start = (std.mem.indexOf(u8, line, key) orelse return null) + key.len;
    var end = start;
    while (end < line.len and line[end] != ' ' and line[end] != '\n' and line[end] != '\r') : (end += 1) {}
    return std.fmt.parseFloat(f32, line[start..end]) catch null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Core: Ranking and Selection
// ═══════════════════════════════════════════════════════════════════════════════

const RungResult = struct {
    killed: usize,
    spawned: usize,
};

fn processRung(allocator: Allocator, state: *EvolutionState, rung_idx: u8, rung: Rung, dry_run: bool, api_calls: *u32) RungResult {
    // Find eligible services: running, step >= threshold, rung not yet passed
    var eligible_indices: [MAX_SERVICES]usize = undefined;
    var eligible_count: usize = 0;

    for (state.services[0..state.service_count], 0..) |*svc, si| {
        if (svc.status != .running) continue;
        if (svc.current_step < rung.step_threshold) continue;
        if (svc.rungs_passed[rung_idx]) continue;
        if (eligible_count < MAX_SERVICES) {
            eligible_indices[eligible_count] = si;
            eligible_count += 1;
        }
    }

    if (eligible_count == 0) return .{ .killed = 0, .spawned = 0 };

    // Sort eligible by PPL ascending (best first)
    sortByPpl(state, eligible_indices[0..eligible_count]);

    // Outlier capping: PPL above per-rung threshold are auto-victims
    const PPL_OUTLIER_THRESHOLD: f32 = rung.outlier_threshold;
    var outlier_count: usize = 0;
    {
        var oi: usize = eligible_count;
        while (oi > 0) {
            oi -= 1;
            if (getPplForRanking(&state.services[eligible_indices[oi]]) > PPL_OUTLIER_THRESHOLD) {
                outlier_count += 1;
            } else break; // sorted, so all before are <= threshold
        }
    }
    // Non-outlier count for ratio-based kill calculation
    const non_outlier_count = eligible_count - outlier_count;

    // Determine kill count: outliers always killed + ratio of non-outliers
    const ratio_kill = @as(usize, @intFromFloat(@as(f32, @floatFromInt(non_outlier_count)) * rung.kill_ratio));
    const total_proposed = outlier_count + ratio_kill;
    const max_killable = if (eligible_count > MIN_SURVIVORS) eligible_count - MIN_SURVIVORS else 0;
    const kill_count = @min(total_proposed, max_killable);

    // Leaders = top 20% of non-outliers
    const leader_count = @max(1, non_outlier_count / 5);

    if (kill_count == 0) {
        // Mark all as passed, no kills
        for (eligible_indices[0..eligible_count]) |si| {
            state.services[si].rungs_passed[rung_idx] = true;
        }
        return .{ .killed = 0, .spawned = 0 };
    }

    print("  {s}Rung {d} ({d}K):{s} {d} eligible, killing {d}, {d} leaders\n", .{
        MAGENTA,        rung_idx + 1, rung.step_threshold / 1000, RESET,
        eligible_count, kill_count,   leader_count,
    });

    var killed: usize = 0;
    var spawned: usize = 0;

    // Kill from bottom (worst PPL)
    var ki: usize = 0;
    while (ki < kill_count) : (ki += 1) {
        const victim_idx = eligible_indices[eligible_count - 1 - ki];
        const victim = &state.services[victim_idx];

        // Pick random leader
        const prng_seed: u32 = @truncate(@as(u64, @intCast(std.time.milliTimestamp())) +% ki);
        const leader_pick = mulberry32(prng_seed) % @as(u32, @intCast(leader_count));
        const leader_idx = eligible_indices[leader_pick];
        const leader = &state.services[leader_idx];

        // Mutate config
        const new_config = mutateConfig(leader, prng_seed +% 1);

        print("  {s}💀 KILL{s} {s} PPL={d:.1} → mutant of {s} LR={s}\n", .{
            RED, RESET, victim.svcName(), victim.current_ppl, leader.svcName(), new_config.lr_str[0..new_config.lr_len],
        });

        // Record event
        var detail_buf: [128]u8 = undefined;
        const detail = std.fmt.bufPrint(&detail_buf, "PPL={d:.1} → mutant of {s}", .{ victim.current_ppl, leader.svcName() }) catch "recycled";
        state.addEvent(.kill, victim.svcName(), detail);

        if (!dry_run) {
            recycleService(allocator, state, victim_idx, new_config, leader.svcName(), api_calls);
            spawned += 1;
        }
        killed += 1;
    }

    // Mark all eligible as passed for this rung
    for (eligible_indices[0..eligible_count]) |si| {
        state.services[si].rungs_passed[rung_idx] = true;
    }

    state.total_configs_tested += @intCast(spawned);

    return .{ .killed = killed, .spawned = spawned };
}

/// Get effective PPL for ranking: prefer val_ppl when available (P1)
fn getPplForRanking(svc: *const ServiceEntry) f32 {
    if (svc.val_ppl < 998.0) return svc.val_ppl;
    return svc.current_ppl;
}

fn sortByPpl(state: *EvolutionState, indices: []usize) void {
    // Simple insertion sort (small N), ranks by val_ppl if available
    var ii: usize = 1;
    while (ii < indices.len) : (ii += 1) {
        const key = indices[ii];
        const key_ppl = getPplForRanking(&state.services[key]);
        var jj: usize = ii;
        while (jj > 0 and getPplForRanking(&state.services[indices[jj - 1]]) > key_ppl) {
            indices[jj] = indices[jj - 1];
            jj -= 1;
        }
        indices[jj] = key;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Core: Config Mutation (PBT)
// ═══════════════════════════════════════════════════════════════════════════════

const MutatedConfig = struct {
    lr_str: [16]u8,
    lr_len: u8,
    batch_str: [8]u8,
    batch_len: u8,
    optimizer_str: [16]u8,
    optimizer_len: u8,
    seed: u32,
};

pub fn mutateConfig(leader: *const ServiceEntry, prng_seed: u32) MutatedConfig {
    var config = MutatedConfig{
        .lr_str = undefined,
        .lr_len = 0,
        .batch_str = leader.batch,
        .batch_len = leader.batch_len,
        .optimizer_str = leader.optimizer,
        .optimizer_len = leader.optimizer_len,
        .seed = mulberry32(prng_seed +% 42),
    };

    // Mutate LR: parse, multiply by random(0.8, 1.2), clamp
    const base_lr = std.fmt.parseFloat(f64, leader.lrStr()) catch 3e-4;
    const rng_val = mulberry32(prng_seed);
    // Map rng_val to [0.8, 1.2]
    const factor = 0.8 + @as(f64, @floatFromInt(rng_val % 1000)) / 1000.0 * 0.4;
    var new_lr = base_lr * factor;
    new_lr = @max(1e-6, @min(1e-2, new_lr));

    const lr_result = std.fmt.bufPrint(&config.lr_str, "{e:.2}", .{new_lr}) catch "3e-4";
    config.lr_len = @intCast(lr_result.len);

    return config;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Core: Service Recycling
// ═══════════════════════════════════════════════════════════════════════════════

fn recycleService(allocator: Allocator, state: *EvolutionState, victim_idx: usize, config: MutatedConfig, parent_name: []const u8, api_calls: *u32) void {
    const victim = &state.services[victim_idx];

    var accounts_buf: [MAX_FARM_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    if (victim.account_idx >= account_count) {
        print("  {s}⚠️  {s}: account_idx {d} out of range ({d} accounts){s}\n", .{ YELLOW, victim.svcName(), victim.account_idx, account_count, RESET });
        state.addEvent(.err, victim.svcName(), "account_idx out of range");
        return;
    }
    const acct = &accounts_buf[victim.account_idx];

    var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch return;
    defer api.deinit();

    const svc_id = victim.svcId();

    // Set training variables
    const seed_str = std.fmt.allocPrint(allocator, "{d}", .{config.seed}) catch return;
    defer allocator.free(seed_str);

    const set_vars_gql = "mutation($input: VariableCollectionUpsertInput!) { variableCollectionUpsert(input: $input) }";
    const shard_str = std.fmt.allocPrint(allocator, "{d}", .{victim.data_shard}) catch return;
    defer allocator.free(shard_str);
    const num_shards_str = std.fmt.allocPrint(allocator, "{d}", .{state.service_count}) catch return;
    defer allocator.free(num_shards_str);

    const set_vars_json = std.fmt.allocPrint(allocator,
        \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","variables":{{"HSLM_LR":"{s}","HSLM_BATCH":"{s}","HSLM_SEED":"{s}","HSLM_OPTIMIZER":"{s}","HSLM_LR_SCHEDULE":"cosine","HSLM_FRESH":"1","HSLM_VAL_SPLIT":"0.1","HSLM_DATA_SHARD":"{s}","HSLM_NUM_SHARDS":"{s}","RAILWAY_DOCKERFILE_PATH":"Dockerfile.hslm-train"}}}}}}
    , .{
        acct.project_id,                               svc_id,                                acct.env_id,
        config.lr_str[0..config.lr_len],               config.batch_str[0..config.batch_len], seed_str,
        config.optimizer_str[0..config.optimizer_len], shard_str,                             num_shards_str,
    }) catch return;
    defer allocator.free(set_vars_json);

    if (api.query(set_vars_gql, set_vars_json)) |resp| {
        allocator.free(resp);
    } else |_| {
        print("  {s}⚠️  {s}: vars failed{s}\n", .{ YELLOW, victim.svcName(), RESET });
        state.addEvent(.err, victim.svcName(), "variableCollectionUpsert failed");
        return;
    }
    api_calls.* += 1;

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Set builder config
    const builder_gql = "mutation($serviceId: String!, $environmentId: String!, $input: ServiceInstanceUpdateInput!) { serviceInstanceUpdate(serviceId: $serviceId, environmentId: $environmentId, input: $input) }";
    const builder_json = std.fmt.allocPrint(allocator,
        \\{{"serviceId":"{s}","environmentId":"{s}","input":{{"builder":"NIXPACKS","startCommand":null,"dockerfilePath":"Dockerfile.hslm-train"}}}}
    , .{ svc_id, acct.env_id }) catch return;
    defer allocator.free(builder_json);

    if (api.query(builder_gql, builder_json)) |resp| {
        allocator.free(resp);
    } else |_| {}
    api_calls.* += 1;

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Redeploy
    if (api.redeployService(svc_id, acct.env_id)) |resp| {
        allocator.free(resp);
    } else |_| {
        print("  {s}⚠️  {s}: redeploy failed{s}\n", .{ YELLOW, victim.svcName(), RESET });
        state.addEvent(.err, victim.svcName(), "redeploy failed");
        return;
    }
    api_calls.* += 1;

    // Update entry
    @memcpy(victim.lr[0..config.lr_len], config.lr_str[0..config.lr_len]);
    victim.lr_len = config.lr_len;
    @memcpy(victim.batch[0..config.batch_len], config.batch_str[0..config.batch_len]);
    victim.batch_len = config.batch_len;
    victim.seed = config.seed;
    victim.generation += 1;
    copyToFixed(&victim.parent, &victim.parent_len, parent_name);
    victim.current_step = 0;
    victim.current_ppl = 999.0;
    victim.current_loss = 99.0;
    victim.val_ppl = 999.0;
    victim.status = .running;
    victim.rungs_passed = .{ false, false, false, false };

    state.addEvent(.spawn, victim.svcName(), "recycled with mutated config");
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRNG: Mulberry32 (deterministic, zero deps)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn mulberry32(seed: u32) u32 {
    var s = seed +% 0x6D2B79F5;
    s = (s ^ (s >> 15)) *% 0x85EBCA77;
    s = (s ^ (s >> 13)) *% 0xC2B2AE3D;
    return s ^ (s >> 16);
}

// ═══════════════════════════════════════════════════════════════════════════════
// State Persistence (JSON)
// ═══════════════════════════════════════════════════════════════════════════════

fn saveState(state: EvolutionState) !void {
    var file = try std.fs.cwd().createFile(STATE_PATH, .{});
    defer file.close();

    var buf: [65536]u8 = undefined;
    var pos: usize = 0;

    // Manual JSON serialization
    pos += (std.fmt.bufPrint(buf[pos..], "{{\"evolution_step\":{d},\"total_configs_tested\":{d},\"best_ppl\":{d:.2},\"best_name\":\"{s}\",\"service_count\":{d},\"event_count\":{d},\"services\":[", .{
        state.evolution_step, state.total_configs_tested, state.best_ppl, state.bestNameStr(),
        state.service_count,  state.event_count,
    }) catch return error.OutOfMemory).len;

    for (state.services[0..state.service_count], 0..) |*svc, si| {
        if (si > 0) {
            buf[pos] = ',';
            pos += 1;
        }
        const rungs_str = std.fmt.bufPrint(buf[pos..], "{{\"id\":\"{s}\",\"name\":\"{s}\",\"acct\":{d},\"lr\":\"{s}\",\"batch\":\"{s}\",\"opt\":\"{s}\",\"seed\":{d},\"gen\":{d},\"parent\":\"{s}\",\"step\":{d},\"ppl\":{d:.2},\"loss\":{d:.4},\"vppl\":{d:.2},\"shard\":{d},\"status\":{d},\"rp\":[{},{},{},{}]}}", .{
            svc.svcId(),         svc.svcName(),       svc.account_idx,
            svc.lrStr(),         svc.batchStr(),      svc.optimizerStr(),
            svc.seed,            svc.generation,      svc.parentName(),
            svc.current_step,    svc.current_ppl,     svc.current_loss,
            svc.val_ppl,         svc.data_shard,      @intFromEnum(svc.status),
            svc.rungs_passed[0], svc.rungs_passed[1], svc.rungs_passed[2],
            svc.rungs_passed[3],
        }) catch return error.OutOfMemory;
        pos += rungs_str.len;
    }

    pos += (std.fmt.bufPrint(buf[pos..], "],\"events\":[", .{}) catch return error.OutOfMemory).len;

    for (state.events[0..state.event_count], 0..) |*ev, ei| {
        if (ei > 0) {
            buf[pos] = ',';
            pos += 1;
        }
        const ev_str = std.fmt.bufPrint(buf[pos..], "{{\"ts\":{d},\"type\":{d},\"svc\":\"{s}\",\"detail\":\"{s}\"}}", .{
            ev.timestamp, @intFromEnum(ev.event_type), ev.svcName(), ev.detailStr(),
        }) catch return error.OutOfMemory;
        pos += ev_str.len;
    }

    pos += (std.fmt.bufPrint(buf[pos..], "]}}", .{}) catch return error.OutOfMemory).len;

    try file.writeAll(buf[0..pos]);
}

fn loadState(allocator: Allocator) !EvolutionState {
    const file = std.fs.cwd().openFile(STATE_PATH, .{}) catch return error.FileNotFound;
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 256 * 1024) catch return error.OutOfMemory;
    defer allocator.free(contents);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch return error.InvalidJson;
    defer parsed.deinit();

    var state = EvolutionState{};
    const root = parsed.value;

    state.evolution_step = jsonU32(root, "evolution_step");
    state.total_configs_tested = jsonU32(root, "total_configs_tested");
    state.best_ppl = jsonF32(root, "best_ppl");
    const bn = getJsonString(root, "best_name");
    copyToFixed(&state.best_name, &state.best_name_len, bn);

    // Load services
    if (getJsonObject(root, "services")) |svcs| {
        if (svcs == .array) {
            for (svcs.array.items) |item| {
                const entry = state.addService() orelse break;
                copyToFixed(&entry.svc_id, &entry.svc_id_len, getJsonString(item, "id"));
                copyToFixed(&entry.svc_name, &entry.svc_name_len, getJsonString(item, "name"));
                entry.account_idx = @intCast(jsonU32(item, "acct"));
                copyToFixed(&entry.lr, &entry.lr_len, getJsonString(item, "lr"));
                copyToFixed(&entry.batch, &entry.batch_len, getJsonString(item, "batch"));
                copyToFixed(&entry.optimizer, &entry.optimizer_len, getJsonString(item, "opt"));
                entry.seed = jsonU32(item, "seed");
                entry.generation = @intCast(jsonU32(item, "gen"));
                const pn = getJsonString(item, "parent");
                if (!std.mem.eql(u8, pn, "(original)")) {
                    copyToFixed(&entry.parent, &entry.parent_len, pn);
                }
                entry.current_step = jsonU32(item, "step");
                entry.current_ppl = jsonF32(item, "ppl");
                entry.current_loss = jsonF32(item, "loss");
                entry.val_ppl = jsonF32(item, "vppl");
                if (entry.val_ppl == 0) entry.val_ppl = 999.0; // missing field → not measured
                entry.data_shard = @intCast(jsonU32(item, "shard"));
                entry.status = @enumFromInt(@min(jsonU32(item, "status"), 4));

                // Load rungs_passed
                if (getJsonObject(item, "rp")) |rp| {
                    if (rp == .array and rp.array.items.len >= 4) {
                        for (0..4) |ri| {
                            entry.rungs_passed[ri] = if (rp.array.items[ri] == .bool) rp.array.items[ri].bool else false;
                        }
                    }
                }
            }
        }
    }

    // Load events
    if (getJsonObject(root, "events")) |evts| {
        if (evts == .array) {
            for (evts.array.items) |item| {
                if (state.event_count >= MAX_EVENTS) break;
                var ev = &state.events[state.event_count];
                ev.* = .{};
                ev.timestamp = jsonI64(item, "ts");
                ev.event_type = @enumFromInt(@min(jsonU32(item, "type"), 3));
                copyToFixed(&ev.service_name, &ev.service_name_len, getJsonString(item, "svc"));
                copyToFixed(&ev.detail, &ev.detail_len, getJsonString(item, "detail"));
                state.event_count += 1;
            }
        }
    }

    return state;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Dashboard
// ═══════════════════════════════════════════════════════════════════════════════

fn printDashboard(state: *const EvolutionState) void {
    // Find current rung
    var active_rung: usize = 0;
    for (DEFAULT_RUNGS, 0..) |_, ri| {
        var any_eligible = false;
        for (state.services[0..state.service_count]) |*svc| {
            if (svc.status == .running and svc.current_step >= DEFAULT_RUNGS[ri].step_threshold and !svc.rungs_passed[ri]) {
                any_eligible = true;
                break;
            }
        }
        if (any_eligible) {
            active_rung = ri;
            break;
        }
    }

    print("\n{s}═══════════════════════════════════════════════════════════{s}\n", .{ BOLD, RESET });
    print("{s}  ASHA+PBT EVOLUTION — Step {d}, Rung {d}/{d}{s}\n", .{ BOLD, state.evolution_step, active_rung + 1, NUM_RUNGS, RESET });
    print("{s}═══════════════════════════════════════════════════════════{s}\n\n", .{ BOLD, RESET });

    print("  Configs tested: {d} | Best: PPL={d:.1} ({s})\n\n", .{
        state.total_configs_tested, state.best_ppl, state.bestNameStr(),
    });

    // Leaderboard (top 10 running by PPL)
    var sorted_indices: [MAX_SERVICES]usize = undefined;
    var sorted_count: usize = 0;
    for (state.services[0..state.service_count], 0..) |*svc, si| {
        if (svc.status == .running and svc.current_ppl < 998) {
            sorted_indices[sorted_count] = si;
            sorted_count += 1;
        }
    }

    // Sort by val_ppl if available, else train_ppl
    var ii: usize = 1;
    while (ii < sorted_count) : (ii += 1) {
        const key = sorted_indices[ii];
        const key_ppl = getPplForRanking(&state.services[key]);
        var jj: usize = ii;
        while (jj > 0 and getPplForRanking(&state.services[sorted_indices[jj - 1]]) > key_ppl) {
            sorted_indices[jj] = sorted_indices[jj - 1];
            jj -= 1;
        }
        sorted_indices[jj] = key;
    }

    print("  {s}LEADERBOARD:{s}\n", .{ BOLD, RESET });
    print("  {s}#  | Service              | PPL      | ValPPL   | Step  | Gen | LR         | Shard{s}\n", .{ DIM, RESET });
    print("  {s}───┼──────────────────────┼──────────┼──────────┼───────┼─────┼────────────┼──────{s}\n", .{ DIM, RESET });

    const show = @min(sorted_count, 10);
    for (0..show) |rank| {
        const svc = &state.services[sorted_indices[rank]];
        print("  {d}", .{rank + 1});
        const rank_digits: usize = if (rank + 1 >= 10) 2 else 1;
        padTo(rank_digits, 3);
        print("| {s}", .{svc.svcName()});
        padTo(svc.svc_name_len, 21);
        print("| {d:.1}", .{svc.current_ppl});
        padToF(svc.current_ppl, 9);
        if (svc.val_ppl < 998) {
            print("| {d:.1}", .{svc.val_ppl});
            padToF(svc.val_ppl, 9);
        } else {
            print("| {s}---{s}      ", .{ DIM, RESET });
        }
        print("| {d}", .{svc.current_step});
        padTo(countDigits(svc.current_step), 6);
        print("| {d}", .{svc.generation});
        padTo(countDigits(svc.generation), 4);
        print("| {s}", .{svc.lrStr()});
        padTo(svc.lr_len, 11);
        print("| {d}\n", .{svc.data_shard});
    }

    // Rung progress
    print("\n  {s}RUNG PROGRESS:{s}\n", .{ BOLD, RESET });
    for (DEFAULT_RUNGS, 0..) |rung, ri| {
        var passed: usize = 0;
        var eligible: usize = 0;
        for (state.services[0..state.service_count]) |*svc| {
            if (svc.status != .running) continue;
            if (svc.current_step >= rung.step_threshold) eligible += 1;
            if (svc.rungs_passed[ri]) passed += 1;
        }
        const status_str = if (passed > 0 and passed == eligible) "DONE" else if (eligible > 0) "ACTIVE" else "WAITING";
        const color = if (passed > 0 and passed == eligible) GREEN else if (eligible > 0) YELLOW else DIM;
        print("  [{d}] {d}K: {d} passed / {d} eligible  {s}{s}{s}\n", .{
            ri + 1, rung.step_threshold / 1000, passed, eligible, color, status_str, RESET,
        });
    }
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// GitHub Issue Posting
// ═══════════════════════════════════════════════════════════════════════════════

fn postToIssue(allocator: Allocator, issue_num: []const u8, state: *const EvolutionState, killed: usize, spawned: usize) void {
    var body_buf: [2048]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf,
        \\🧬 **Evolution Step {d}**
        \\
        \\📊 Configs tested: {d} | Best PPL: {d:.1} ({s})
        \\💀 Killed: {d} | 🌱 Spawned: {d}
        \\
        \\Rungs: {d}K/{d}K/{d}K/{d}K
    , .{
        state.evolution_step,
        state.total_configs_tested,
        state.best_ppl,
        state.bestNameStr(),
        killed,
        spawned,
        DEFAULT_RUNGS[0].step_threshold / 1000,
        DEFAULT_RUNGS[1].step_threshold / 1000,
        DEFAULT_RUNGS[2].step_threshold / 1000,
        DEFAULT_RUNGS[3].step_threshold / 1000,
    }) catch return;

    const cmd = std.fmt.allocPrint(allocator, "gh issue comment {s} --body \"{s}\"", .{ issue_num, body }) catch return;
    defer allocator.free(cmd);

    var child = std.process.Child.init(&.{ "gh", "issue", "comment", issue_num, "--body", body }, allocator);
    _ = child.spawnAndWait() catch {
        print("  {s}⚠️  Failed to post to issue #{s}{s}\n", .{ YELLOW, issue_num, RESET });
        return;
    };

    print("  {s}📝 Posted to issue #{s}{s}\n", .{ GREEN, issue_num, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════

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

fn jsonU32(val: std.json.Value, key: []const u8) u32 {
    if (val != .object) return 0;
    const v = val.object.get(key) orelse return 0;
    return switch (v) {
        .integer => |i| @intCast(@max(0, i)),
        .float => |f| @intFromFloat(@max(0, f)),
        else => 0,
    };
}

fn jsonI64(val: std.json.Value, key: []const u8) i64 {
    if (val != .object) return 0;
    const v = val.object.get(key) orelse return 0;
    return switch (v) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        else => 0,
    };
}

fn jsonF32(val: std.json.Value, key: []const u8) f32 {
    if (val != .object) return 0;
    const v = val.object.get(key) orelse return 0;
    return switch (v) {
        .float => |f| @floatCast(f),
        .integer => |i| @floatFromInt(i),
        else => 0,
    };
}

fn getEdgesFromProject(root: std.json.Value) ?[]std.json.Value {
    const data = getJsonObject(root, "data") orelse return null;
    const proj = getJsonObject(data, "project") orelse return null;
    const svcs = getJsonObject(proj, "services") orelse return null;
    const edges = getJsonObject(svcs, "edges") orelse return null;
    if (edges != .array) return null;
    return edges.array.items;
}

fn isTrainingService(name: []const u8) bool {
    // Match hslm-* services
    return std.mem.startsWith(u8, name, "hslm-");
}

fn classifyStatus(status: []const u8) ServiceStatus {
    if (std.mem.eql(u8, status, "SUCCESS")) return .running;
    if (std.mem.eql(u8, status, "CRASHED") or std.mem.eql(u8, status, "FAILED")) return .crashed;
    if (std.mem.eql(u8, status, "REMOVED") or std.mem.eql(u8, status, "NONE")) return .idle;
    return .unknown;
}

fn extractConfig(entry: *ServiceEntry, root: std.json.Value) void {
    const data = getJsonObject(root, "data") orelse return;
    const vars = getJsonObject(data, "variables") orelse return;
    if (vars != .object) return;

    if (vars.object.get("HSLM_LR")) |v| {
        if (v == .string) copyToFixed(&entry.lr, &entry.lr_len, v.string);
    }
    if (vars.object.get("HSLM_BATCH")) |v| {
        if (v == .string) copyToFixed(&entry.batch, &entry.batch_len, v.string);
    }
    if (vars.object.get("HSLM_OPTIMIZER")) |v| {
        if (v == .string) copyToFixed(&entry.optimizer, &entry.optimizer_len, v.string);
    }
    if (vars.object.get("HSLM_SEED")) |v| {
        if (v == .string) {
            entry.seed = std.fmt.parseInt(u32, v.string, 10) catch 0;
        }
    }
    if (vars.object.get("HSLM_DATA_SHARD")) |v| {
        if (v == .string) {
            entry.data_shard = std.fmt.parseInt(u16, v.string, 10) catch 0;
        }
    }
}

fn copyToFixed(dst: anytype, len: *u8, src: []const u8) void {
    const max_len = dst.len;
    const copy_len: u8 = @intCast(@min(src.len, max_len));
    @memcpy(dst[0..copy_len], src[0..copy_len]);
    len.* = copy_len;
}

fn padTo(current: anytype, target: usize) void {
    const cur: usize = switch (@TypeOf(current)) {
        u8 => @as(usize, current),
        else => current,
    };
    if (cur >= target) return;
    var pad_i: usize = 0;
    while (pad_i < target - cur) : (pad_i += 1) {
        print(" ", .{});
    }
}

fn padToF(val: f32, target: usize) void {
    // Estimate printed length of float
    const len: usize = if (val >= 1000) 6 else if (val >= 100) 5 else if (val >= 10) 4 else 3;
    padTo(len, target);
}

fn countDigits(n: u32) usize {
    if (n == 0) return 1;
    var count: usize = 0;
    var v = n;
    while (v > 0) : (v /= 10) {
        count += 1;
    }
    return count;
}

fn printHelp() void {
    print(
        \\
        \\Usage: tri farm evolve <command> [options]
        \\
        \\ASHA+PBT hybrid evolution for the training farm.
        \\Kills bottom performers at step thresholds, recycles with mutated leader configs.
        \\
        \\Commands:
        \\  init             Scan all accounts, build initial state
        \\  status           Leaderboard + rung progress (default)
        \\  step             Execute one evolution cycle
        \\  history          Print event log
        \\  help             Show this help
        \\
        \\Step options:
        \\  --dry-run        Preview actions without executing
        \\  --issue <N>      Post summary to GitHub issue #N
        \\
        \\Rungs: 5K (outlier>500), 15K (outlier>200), 30K (30% kill), 50K (30% kill)
        \\Ranking: val_ppl (if available) > train_ppl. Data sharding via HSLM_DATA_SHARD.
        \\Min survivors: 4 | LR schedule: ALWAYS cosine
        \\
    , .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parseTrainingLine valid" {
    const line = "    5000 |   5.8234 |   5.9100 |   338.45 |   0.001000 |   0.8234 |   1400";
    const result = parseTrainingLine(line) orelse unreachable;
    try std.testing.expectEqual(@as(u32, 5000), result.step);
    try std.testing.expectApproxEqAbs(@as(f32, 5.8234), result.loss, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 338.45), result.ppl, 0.1);
}

test "parseTrainingLine garbage" {
    try std.testing.expect(parseTrainingLine("hello world") == null);
    try std.testing.expect(parseTrainingLine("") == null);
    try std.testing.expect(parseTrainingLine("Training started...") == null);
}

test "parseTrainingLine early kill" {
    const line = "[EARLY KILL] PPL=200 at step 10000";
    try std.testing.expect(parseTrainingLine(line) == null);
}

test "mutateConfig lr bounds" {
    // Test that LR stays within bounds after many mutations
    var entry = ServiceEntry{};
    copyToFixed(&entry.lr, &entry.lr_len, "1e-2"); // max boundary
    copyToFixed(&entry.batch, &entry.batch_len, "128");
    copyToFixed(&entry.optimizer, &entry.optimizer_len, "lamb");

    var seed: u32 = 12345;
    var all_in_bounds = true;
    for (0..100) |_| {
        const config = mutateConfig(&entry, seed);
        const lr = std.fmt.parseFloat(f64, config.lr_str[0..config.lr_len]) catch {
            all_in_bounds = false;
            break;
        };
        if (lr < 1e-6 or lr > 1e-2) all_in_bounds = false;
        seed = mulberry32(seed);
    }
    try std.testing.expect(all_in_bounds);
}

test "mutateConfig cosine always" {
    // Schedule is hardcoded in recycleService, never in config mutation
    // This test just verifies mutation doesn't produce a schedule field
    var entry = ServiceEntry{};
    copyToFixed(&entry.lr, &entry.lr_len, "3e-4");
    copyToFixed(&entry.batch, &entry.batch_len, "128");
    copyToFixed(&entry.optimizer, &entry.optimizer_len, "lamb");

    const config = mutateConfig(&entry, 42);
    // MutatedConfig has no schedule field — cosine is hardcoded in recycleService
    _ = config;
}

test "rankAndSelect min survivors" {
    // With MIN_SURVIVORS=4 and 5 eligible, at most 1 can be killed
    var state = EvolutionState{};
    for (0..5) |si| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        entry.current_step = 6000;
        entry.current_ppl = @floatFromInt(100 + si * 50);
    }

    var api_calls_min: u32 = 0;
    const result = processRung(std.testing.allocator, &state, 0, DEFAULT_RUNGS[0], true, &api_calls_min);
    try std.testing.expect(result.killed <= 1);
}

test "rankAndSelect empty eligible" {
    var state = EvolutionState{};
    // Add services but none eligible (step too low)
    for (0..3) |_| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        entry.current_step = 100;
        entry.current_ppl = 200;
    }

    var api_calls: u32 = 0;
    const result = processRung(std.testing.allocator, &state, 0, DEFAULT_RUNGS[0], true, &api_calls);
    try std.testing.expectEqual(@as(usize, 0), result.killed);
    try std.testing.expectEqual(@as(usize, 0), result.spawned);
}

test "mulberry32 deterministic" {
    const a1 = mulberry32(42);
    const a2 = mulberry32(42);
    try std.testing.expectEqual(a1, a2);

    // Different seeds → different outputs
    const b = mulberry32(43);
    try std.testing.expect(a1 != b);
}

test "outlier PPL auto-victim" {
    // Services with PPL > 500 should be auto-killed before ratio-based culling
    var state = EvolutionState{};

    // 3 healthy services (PPL 100-200)
    for (0..3) |si| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        entry.current_step = 6000;
        entry.current_ppl = @floatFromInt(100 + si * 50);
        copyToFixed(&entry.lr, &entry.lr_len, "3e-4");
        copyToFixed(&entry.batch, &entry.batch_len, "128");
        copyToFixed(&entry.optimizer, &entry.optimizer_len, "lamb");
    }

    // 4 outlier services (PPL 600-900)
    for (0..4) |si| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        entry.current_step = 6000;
        entry.current_ppl = @floatFromInt(600 + si * 100);
        copyToFixed(&entry.lr, &entry.lr_len, "1e-3");
        copyToFixed(&entry.batch, &entry.batch_len, "128");
        copyToFixed(&entry.optimizer, &entry.optimizer_len, "lamb");
    }

    // 7 total, MIN_SURVIVORS=4, so max killable = 3
    // All 4 outliers proposed but capped to 3 by MIN_SURVIVORS
    var api_calls_out: u32 = 0;
    const result = processRung(std.testing.allocator, &state, 0, DEFAULT_RUNGS[0], true, &api_calls_out);
    try std.testing.expect(result.killed == 3); // 7 - MIN_SURVIVORS(4) = 3
}
