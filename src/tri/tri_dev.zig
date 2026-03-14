// @origin(spec) @regen(done)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI DEV — SWE Agent Cloud Development Farm
// ═══════════════════════════════════════════════════════════════════════════════
//
// Manages development agents on Railway — each GitHub issue = 1 service = 1 agent.
// Generated from: specs/tri/dev_farm.tri
// Reuses: tri_farm.zig (command pattern), farm_accounts.zig, railway_api.zig
//
// Commands:
//   tri dev status      — table of all dev agents across accounts
//   tri dev spawn <N>   — spawn agent for issue N
//   tri dev kill <N>    — kill agent for issue N
//   tri dev recycle     — reassign idle agents to backlog issues
//   tri dev fill        — spawn agents for all agent:dev labeled issues
//   tri dev metrics     — aggregate fitness metrics
//   tri dev leaderboard — rank agents by fitness score
//   tri dev evolve      — ASHA+PBT evolution step
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const railway_api = @import("railway_api.zig");
const RailwayApi = railway_api.RailwayApi;
const farm_accounts_mod = @import("farm_accounts.zig");

const dev_pipeline = @import("dev_pipeline.zig");

const print = std.debug.print;

const STATE_PATH = ".trinity/dev_agents.json";
pub const MAX_DEV_AGENTS = 64;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";
const MAGENTA = "\x1b[35m";

const Account = farm_accounts_mod.Account;
const MAX_ACCOUNTS = farm_accounts_mod.MAX_ACCOUNTS;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES (from dev_farm.tri)
// ═══════════════════════════════════════════════════════════════════════════════

pub const AgentRole = enum {
    planner,
    coder,
    reviewer,
    tester,
    integrator,

    pub fn toString(self: AgentRole) []const u8 {
        return switch (self) {
            .planner => "planner",
            .coder => "coder",
            .reviewer => "reviewer",
            .tester => "tester",
            .integrator => "integrator",
        };
    }

    pub fn fromString(str: []const u8) ?AgentRole {
        if (std.mem.eql(u8, str, "planner")) return .planner;
        if (std.mem.eql(u8, str, "coder")) return .coder;
        if (std.mem.eql(u8, str, "reviewer")) return .reviewer;
        if (std.mem.eql(u8, str, "tester")) return .tester;
        if (std.mem.eql(u8, str, "integrator")) return .integrator;
        return null;
    }
};

pub const DevFitness = struct {
    test_pass_rate: f32 = 0.0,
    spec_compliance: f32 = 0.0,
    time_hours: f32 = 0.0,
    pr_merged: bool = false,

    pub fn totalScore(self: DevFitness) f32 {
        const time_score: f32 = if (self.time_hours > 0.0) @min(1.0, 1.0 / self.time_hours) else 0.0;
        const merged: f32 = if (self.pr_merged) 1.0 else 0.0;
        return 0.4 * self.test_pass_rate + 0.3 * self.spec_compliance + 0.2 * time_score + 0.1 * merged;
    }
};

pub const SpawnConfig = struct {
    issue_number: u32,
    role: AgentRole = .coder,
    model: []const u8 = "claude-sonnet-4-20250514",
    pipeline_links: []const u8 = "6,7,11,17",
    account_suffix: []const u8 = "",
};

// ═══════════════════════════════════════════════════════════════════════════════
// STATE PERSISTENCE (pattern from tri_farm_evolve.zig)
// ═══════════════════════════════════════════════════════════════════════════════

pub const DevAgentEntry = struct {
    service_name: [64]u8 = undefined,
    service_name_len: u8 = 0,
    issue_number: u32 = 0,
    role: AgentRole = .coder,
    account_name: [32]u8 = undefined,
    account_name_len: u8 = 0,
    status: [16]u8 = undefined,
    status_len: u8 = 0,
    started_at: u64 = 0,
    fitness: DevFitness = .{},
    has_fitness: bool = false,

    pub fn svcName(self: *const DevAgentEntry) []const u8 {
        return self.service_name[0..self.service_name_len];
    }

    pub fn acctName(self: *const DevAgentEntry) []const u8 {
        return self.account_name[0..self.account_name_len];
    }

    pub fn statusStr(self: *const DevAgentEntry) []const u8 {
        return self.status[0..self.status_len];
    }
};

pub const DevFarmState = struct {
    agents: [MAX_DEV_AGENTS]DevAgentEntry = undefined,
    agent_count: usize = 0,

    fn addAgent(self: *DevFarmState) ?*DevAgentEntry {
        if (self.agent_count >= MAX_DEV_AGENTS) return null;
        const entry = &self.agents[self.agent_count];
        entry.* = .{};
        self.agent_count += 1;
        return entry;
    }

    fn findByIssue(self: *DevFarmState, issue: u32) ?*DevAgentEntry {
        for (self.agents[0..self.agent_count]) |*a| {
            if (a.issue_number == issue) return a;
        }
        return null;
    }

    fn hasIssue(self: *const DevFarmState, issue: u32) bool {
        for (self.agents[0..self.agent_count]) |*a| {
            if (a.issue_number == issue) return true;
        }
        return false;
    }

    fn removeByIssue(self: *DevFarmState, issue: u32) bool {
        for (self.agents[0..self.agent_count], 0..) |*a, i| {
            if (a.issue_number == issue) {
                // Shift remaining
                const remaining = self.agent_count - i - 1;
                if (remaining > 0) {
                    const dest = self.agents[i .. i + remaining];
                    const src = self.agents[i + 1 .. i + 1 + remaining];
                    @memcpy(dest, src);
                }
                self.agent_count -= 1;
                return true;
            }
        }
        return false;
    }
};

fn copyToFixed(dest: anytype, len_ptr: *u8, src: []const u8) void {
    const max = dest.len;
    const copy_len = @min(src.len, max);
    @memcpy(dest[0..copy_len], src[0..copy_len]);
    len_ptr.* = @intCast(copy_len);
}

fn saveState(state: DevFarmState) !void {
    var file = try std.fs.cwd().createFile(STATE_PATH, .{});
    defer file.close();

    var buf: [32768]u8 = undefined;
    var pos: usize = 0;

    pos += (std.fmt.bufPrint(buf[pos..], "{{\"agent_count\":{d},\"agents\":[", .{
        state.agent_count,
    }) catch return error.OutOfMemory).len;

    for (state.agents[0..state.agent_count], 0..) |*a, ai| {
        if (ai > 0) {
            buf[pos] = ',';
            pos += 1;
        }
        pos += (std.fmt.bufPrint(buf[pos..], "{{\"name\":\"{s}\",\"issue\":{d},\"role\":{d},\"acct\":\"{s}\",\"status\":\"{s}\",\"started\":{d},\"has_fit\":{},\"tp\":{d:.4},\"sc\":{d:.4},\"th\":{d:.4},\"pm\":{}}}", .{
            a.svcName(),
            a.issue_number,
            @intFromEnum(a.role),
            a.acctName(),
            a.statusStr(),
            a.started_at,
            a.has_fitness,
            a.fitness.test_pass_rate,
            a.fitness.spec_compliance,
            a.fitness.time_hours,
            a.fitness.pr_merged,
        }) catch return error.OutOfMemory).len;
    }

    pos += (std.fmt.bufPrint(buf[pos..], "]}}", .{}) catch return error.OutOfMemory).len;

    try file.writeAll(buf[0..pos]);
}

pub fn loadState(allocator: Allocator) DevFarmState {
    const file = std.fs.cwd().openFile(STATE_PATH, .{}) catch return .{};
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 64 * 1024) catch return .{};
    defer allocator.free(contents);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch return .{};
    defer parsed.deinit();

    var state = DevFarmState{};
    const root = parsed.value;

    if (getJsonObject(root, "agents")) |agents_val| {
        if (agents_val == .array) {
            for (agents_val.array.items) |item| {
                const entry = state.addAgent() orelse break;
                copyToFixed(&entry.service_name, &entry.service_name_len, getJsonString(item, "name"));
                entry.issue_number = jsonU32(item, "issue");
                entry.role = @enumFromInt(@min(jsonU32(item, "role"), 4));
                copyToFixed(&entry.account_name, &entry.account_name_len, getJsonString(item, "acct"));
                copyToFixed(&entry.status, &entry.status_len, getJsonString(item, "status"));
                entry.started_at = jsonU64(item, "started");
                entry.has_fitness = jsonBool(item, "has_fit");
                entry.fitness.test_pass_rate = jsonF32(item, "tp");
                entry.fitness.spec_compliance = jsonF32(item, "sc");
                entry.fitness.time_hours = jsonF32(item, "th");
                entry.fitness.pr_merged = jsonBool(item, "pm");
            }
        }
    }

    return state;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDevCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, subcmd, "status")) {
        return runDevStatus(allocator);
    } else if (std.mem.eql(u8, subcmd, "spawn")) {
        return runDevSpawn(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "kill")) {
        return runDevKill(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "recycle")) {
        return runDevRecycle(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "fill")) {
        return runDevFill(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "metrics")) {
        return runDevMetrics(allocator);
    } else if (std.mem.eql(u8, subcmd, "leaderboard")) {
        return runDevLeaderboard(allocator);
    } else if (std.mem.eql(u8, subcmd, "evolve")) {
        const dev_farm_evolve = @import("dev_farm_evolve.zig");
        return dev_farm_evolve.runDevEvolveCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        print("{s}Unknown dev subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS — show all dev agents across all accounts
// ═══════════════════════════════════════════════════════════════════════════════

fn runDevStatus(allocator: Allocator) !void {
    print("\n{s}🤖 SWE AGENT DEV FARM{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    // Load persisted state for sync
    var state = loadState(allocator);
    var state_changed = false;

    var accounts_buf: [MAX_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    if (account_count == 0) {
        print("  {s}No Railway accounts found. Set RAILWAY_API_TOKEN in .env{s}\n\n", .{ YELLOW, RESET });
        return;
    }
    print("  {s}Discovered {d} account(s){s}\n\n", .{ DIM, account_count, RESET });

    var total_agents: usize = 0;
    var total_running: usize = 0;
    var total_idle: usize = 0;
    var total_crashed: usize = 0;

    for (accounts_buf[0..account_count]) |acct| {
        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch |err| {
            print("{s}=== {s} ==={s} {s}(token error: {s}){s}\n\n", .{ BOLD, acct.name, RESET, YELLOW, @errorName(err), RESET });
            continue;
        };
        defer api.deinit();

        print("{s}=== {s} ==={s}\n", .{ BOLD, acct.name, RESET });

        // Query services — look for swe-agent-* pattern
        const gql = "query($projectId: String!) { project(id: $projectId) { services { edges { node { id name deployments(first:1) { edges { node { status } } } } } } } }";
        const vars_json = std.fmt.allocPrint(allocator, "{{\"projectId\":\"{s}\"}}", .{acct.project_id}) catch continue;
        defer allocator.free(vars_json);

        const resp = api.query(gql, vars_json) catch |err| {
            print("  {s}API error: {s}{s}\n\n", .{ RED, @errorName(err), RESET });
            continue;
        };
        defer allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch {
            print("  {s}Invalid JSON response{s}\n\n", .{ RED, RESET });
            continue;
        };
        defer parsed.deinit();

        // Navigate: data.project.services.edges
        const data_val = getJsonObject(parsed.value, "data") orelse {
            printApiError(parsed.value);
            continue;
        };
        const proj_val = getJsonObject(data_val, "project") orelse continue;
        const svcs_val = getJsonObject(proj_val, "services") orelse continue;
        const edges_val = getJsonObject(svcs_val, "edges") orelse continue;
        if (edges_val != .array) continue;

        print("  {s}SERVICE                   ISSUE   ROLE       STATUS{s}\n", .{ DIM, RESET });
        print("  {s}──────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });

        var acct_agents: usize = 0;

        for (edges_val.array.items) |edge| {
            const node = getJsonObject(edge, "node") orelse continue;
            const name = getJsonString(node, "name");

            // Filter: only swe-agent-* services
            if (!std.mem.startsWith(u8, name, "swe-agent-")) continue;

            acct_agents += 1;

            var dep_status: []const u8 = "NONE";
            if (getJsonObject(node, "deployments")) |deps| {
                if (getJsonObject(deps, "edges")) |dep_edges| {
                    if (dep_edges == .array and dep_edges.array.items.len > 0) {
                        const dep_node = getJsonObject(dep_edges.array.items[0], "node") orelse continue;
                        dep_status = getJsonString(dep_node, "status");
                    }
                }
            }

            const is_idle = isIdleStatus(dep_status);
            const is_crashed = isCrashedStatus(dep_status);
            const is_running = isRunningStatus(dep_status);

            if (is_idle) total_idle += 1 else if (is_crashed) total_crashed += 1 else total_running += 1;

            const icon = if (is_crashed) "🔴" else if (is_idle) "💤" else if (is_running) "🟢" else "🔨";
            const color = if (is_crashed) RED else if (is_idle) YELLOW else GREEN;

            // Extract issue number from name: swe-agent-123 → 123
            const issue_str = if (name.len > 10) name[10..] else "?";
            const issue_num = std.fmt.parseInt(u32, issue_str, 10) catch 0;

            // Sync state: update existing or add new entry
            if (issue_num > 0) {
                if (state.findByIssue(issue_num)) |entry| {
                    // Update status from live Railway data
                    if (!std.mem.eql(u8, entry.statusStr(), dep_status)) {
                        copyToFixed(&entry.status, &entry.status_len, dep_status);
                        copyToFixed(&entry.account_name, &entry.account_name_len, acct.name);
                        state_changed = true;
                    }
                } else {
                    // New service discovered on Railway not in our state — add it
                    if (state.addAgent()) |entry| {
                        copyToFixed(&entry.service_name, &entry.service_name_len, name);
                        entry.issue_number = issue_num;
                        entry.role = .coder; // default, can't know from Railway
                        copyToFixed(&entry.account_name, &entry.account_name_len, acct.name);
                        copyToFixed(&entry.status, &entry.status_len, dep_status);
                        entry.started_at = @intCast(std.time.timestamp());
                        state_changed = true;
                    }
                }
            }

            // Display role from state if available
            const role_str = if (issue_num > 0) blk: {
                if (state.findByIssue(issue_num)) |entry| break :blk entry.role.toString();
                break :blk "coder";
            } else "coder";

            print("  {s} {s}{s}{s}", .{ icon, color, name, RESET });
            padTo(name.len, 25);
            print(" #{s}", .{issue_str});
            padTo(issue_str.len + 1, 8);
            print(" {s}", .{role_str});
            padTo(role_str.len, 11);
            print("{s}{s}{s}\n", .{ color, dep_status, RESET });
        }

        total_agents += acct_agents;

        if (acct_agents == 0) {
            print("  {s}(no dev agents){s}\n", .{ DIM, RESET });
        }
        print("\n", .{});
    }

    // Save synced state
    if (state_changed) {
        saveState(state) catch {};
        print("  {s}State synced → {s}{s}\n", .{ DIM, STATE_PATH, RESET });
    }

    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}TOTAL: {d} agents | 🟢 {d} running | 💤 {d} idle | 🔴 {d} crashed{s}\n", .{
        BOLD, total_agents, total_running, total_idle, total_crashed, RESET,
    });
    print("{s}State: {d} tracked in {s}{s}\n\n", .{ DIM, state.agent_count, STATE_PATH, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPAWN — create/reuse Railway service for a GitHub issue
// ═══════════════════════════════════════════════════════════════════════════════

fn runDevSpawn(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        print("{s}Usage: tri dev spawn <issue-number> [--role coder] [--model claude-sonnet-4-20250514]{s}\n", .{ YELLOW, RESET });
        return;
    }

    const issue_num = std.fmt.parseInt(u32, args[0], 10) catch {
        print("{s}Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    // Parse options
    var role: AgentRole = .coder;
    var model: []const u8 = "claude-sonnet-4-20250514";
    var links: []const u8 = "6,7,11,17";

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--role") and i + 1 < args.len) {
            i += 1;
            role = AgentRole.fromString(args[i]) orelse .coder;
        } else if (std.mem.eql(u8, args[i], "--model") and i + 1 < args.len) {
            i += 1;
            model = args[i];
        } else if (std.mem.eql(u8, args[i], "--links") and i + 1 < args.len) {
            i += 1;
            links = args[i];
        }
    }

    print("\n{s}🚀 SPAWN DEV AGENT{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    const est_cost = dev_pipeline.estimateCost(model, 50_000);

    print("  Issue: #{d}\n", .{issue_num});
    print("  Role: {s}\n", .{role.toString()});
    print("  Model: {s}\n", .{model});
    print("  Links: {s}\n", .{links});
    print("  Est. cost: {s}${d:.2}{s}\n\n", .{ CYAN, est_cost, RESET });

    // Find first account with capacity
    var accounts_buf: [MAX_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    if (account_count == 0) {
        print("  {s}No Railway accounts found{s}\n\n", .{ RED, RESET });
        return;
    }

    // Use first available account
    const acct = accounts_buf[0];

    var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch |err| {
        print("  {s}Token error: {s}{s}\n\n", .{ RED, @errorName(err), RESET });
        return;
    };
    defer api.deinit();

    const svc_name = std.fmt.allocPrint(allocator, "swe-agent-{d}", .{issue_num}) catch return;
    defer allocator.free(svc_name);

    // Create service
    print("  Creating service {s}{s}{s} on {s}...\n", .{ CYAN, svc_name, RESET, acct.name });

    // Create service WITHOUT source — prevents auto-deploy before config is set
    const create_gql = "mutation($input: ServiceCreateInput!) { serviceCreate(input: $input) { id name } }";
    const create_json = std.fmt.allocPrint(allocator,
        \\{{"input":{{"projectId":"{s}","name":"{s}"}}}}
    , .{ acct.project_id, svc_name }) catch return;
    defer allocator.free(create_json);

    const create_resp = api.query(create_gql, create_json) catch |err| {
        print("  {s}Create failed: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return;
    };
    defer allocator.free(create_resp);

    // Parse service ID from response
    const create_parsed = std.json.parseFromSlice(std.json.Value, allocator, create_resp, .{}) catch {
        print("  {s}Invalid create response{s}\n", .{ RED, RESET });
        return;
    };
    defer create_parsed.deinit();

    const svc_data = getJsonObject(create_parsed.value, "data") orelse {
        printApiError(create_parsed.value);
        return;
    };
    const svc_create = getJsonObject(svc_data, "serviceCreate") orelse {
        print("  {s}Service creation failed{s}\n", .{ RED, RESET });
        return;
    };
    const svc_id = getJsonString(svc_create, "id");

    print("  Service ID: {s}{s}{s}\n", .{ DIM, svc_id, RESET });

    // Wait for Railway to provision the service instance
    print("  Waiting for service provisioning...\n", .{});
    std.Thread.sleep(3 * std.time.ns_per_s);

    // Set env vars for SWE agent
    const issue_str = std.fmt.allocPrint(allocator, "{d}", .{issue_num}) catch return;
    defer allocator.free(issue_str);

    const set_vars_gql = "mutation($input: VariableCollectionUpsertInput!) { variableCollectionUpsert(input: $input) }";
    const set_vars_json = std.fmt.allocPrint(allocator,
        \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","variables":{{"ISSUE_NUMBER":"{s}","AGENT_ROLE":"{s}","TRINITY_MODEL_CODER":"{s}","PIPELINE_LINKS":"{s}","GITHUB_TOKEN":"${{AGENT_GH_TOKEN}}","ANTHROPIC_API_KEY":"${{ZAI_KEY_1}}","RAILWAY_DOCKERFILE_PATH":"Dockerfile.swe-agent"}}}}}}
    , .{
        acct.project_id, svc_id,          acct.env_id,
        issue_str,       role.toString(), model,
        links,
    }) catch return;
    defer allocator.free(set_vars_json);

    if (api.query(set_vars_gql, set_vars_json)) |vars_resp| {
        allocator.free(vars_resp);
    } else |_| {
        print("  {s}Warning: env vars may not be set{s}\n", .{ YELLOW, RESET });
    }

    // Set builder config
    const builder_gql = "mutation($serviceId: String!, $environmentId: String!, $input: ServiceInstanceUpdateInput!) { serviceInstanceUpdate(serviceId: $serviceId, environmentId: $environmentId, input: $input) }";
    const builder_json = std.fmt.allocPrint(allocator,
        \\{{"serviceId":"{s}","environmentId":"{s}","input":{{"builder":"NIXPACKS","startCommand":null,"dockerfilePath":"Dockerfile.swe-agent"}}}}
    , .{ svc_id, acct.env_id }) catch return;
    defer allocator.free(builder_json);

    if (api.query(builder_gql, builder_json)) |builder_resp| {
        allocator.free(builder_resp);
    } else |_| {
        print("  {s}Warning: builder config may not be set{s}\n", .{ YELLOW, RESET });
    }

    // Connect repo source (created without source to avoid premature auto-deploy)
    print("  Connecting repo source...\n", .{});
    const connect_gql = "mutation($id: String!, $input: ServiceUpdateInput!) { serviceUpdate(id: $id, input: $input) { id } }";
    const connect_json = std.fmt.allocPrint(allocator,
        \\{{"id":"{s}","input":{{"source":{{"repo":"gHashTag/trinity"}}}}}}
    , .{svc_id}) catch return;
    defer allocator.free(connect_json);

    if (api.query(connect_gql, connect_json)) |conn_resp| {
        allocator.free(conn_resp);
    } else |_| {
        print("  {s}Warning: repo source may not be connected{s}\n", .{ YELLOW, RESET });
    }

    // Trigger deployment explicitly
    print("  Triggering deployment...\n", .{});
    const redeploy_gql = "mutation($serviceId: String!, $environmentId: String!) { serviceInstanceRedeploy(serviceId: $serviceId, environmentId: $environmentId) }";
    const redeploy_json = std.fmt.allocPrint(allocator,
        \\{{"serviceId":"{s}","environmentId":"{s}"}}
    , .{ svc_id, acct.env_id }) catch return;
    defer allocator.free(redeploy_json);

    if (api.query(redeploy_gql, redeploy_json)) |resp| {
        allocator.free(resp);
        print("  {s}Deployment triggered{s}\n", .{ GREEN, RESET });
    } else |_| {
        print("  {s}Warning: redeploy may not have triggered{s}\n", .{ YELLOW, RESET });
    }

    print("\n  {s}✅ Agent spawned: {s} → issue #{d}{s}\n", .{ GREEN, svc_name, issue_num, RESET });
    print("  {s}Deploying with Dockerfile.swe-agent...{s}\n\n", .{ DIM, RESET });

    // Comment on GitHub issue
    var gh_body_buf: [256]u8 = undefined;
    const gh_body = std.fmt.bufPrint(&gh_body_buf, "Agent spawned: {s} | Role: {s}", .{ svc_name, role.toString() }) catch return;
    var gh_issue_buf: [16]u8 = undefined;
    const gh_issue_str = std.fmt.bufPrint(&gh_issue_buf, "{d}", .{issue_num}) catch return;
    const gh_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "gh", "issue", "comment", gh_issue_str, "--body", gh_body },
        .max_output_bytes = 65536,
    }) catch null;
    if (gh_result) |r| {
        allocator.free(r.stdout);
        allocator.free(r.stderr);
    }

    // Save to state
    var state = loadState(allocator);
    if (state.findByIssue(issue_num) == null) {
        if (state.addAgent()) |entry| {
            copyToFixed(&entry.service_name, &entry.service_name_len, svc_name);
            entry.issue_number = issue_num;
            entry.role = role;
            copyToFixed(&entry.account_name, &entry.account_name_len, acct.name);
            copyToFixed(&entry.status, &entry.status_len, "BUILDING");
            entry.started_at = @intCast(std.time.timestamp());
            saveState(state) catch {};
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KILL — remove Railway service for an issue
// ═══════════════════════════════════════════════════════════════════════════════

fn runDevKill(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        print("{s}Usage: tri dev kill <issue-number>{s}\n", .{ YELLOW, RESET });
        return;
    }

    const issue_num = std.fmt.parseInt(u32, args[0], 10) catch {
        print("{s}Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    const target_name = std.fmt.allocPrint(allocator, "swe-agent-{d}", .{issue_num}) catch return;
    defer allocator.free(target_name);

    print("\n{s}🗑️  KILL DEV AGENT{s}\n", .{ BOLD, RESET });
    print("  Target: {s}{s}{s}\n\n", .{ RED, target_name, RESET });

    var accounts_buf: [MAX_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    for (accounts_buf[0..account_count]) |acct| {
        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch continue;
        defer api.deinit();

        // Find service by name
        const gql = "query($projectId: String!) { project(id: $projectId) { services { edges { node { id name } } } } }";
        const vars_json = std.fmt.allocPrint(allocator, "{{\"projectId\":\"{s}\"}}", .{acct.project_id}) catch continue;
        defer allocator.free(vars_json);

        const resp = api.query(gql, vars_json) catch continue;
        defer allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch continue;
        defer parsed.deinit();

        const data_val = getJsonObject(parsed.value, "data") orelse continue;
        const proj_val = getJsonObject(data_val, "project") orelse continue;
        const svcs_val = getJsonObject(proj_val, "services") orelse continue;
        const edges_val = getJsonObject(svcs_val, "edges") orelse continue;
        if (edges_val != .array) continue;

        for (edges_val.array.items) |edge| {
            const node = getJsonObject(edge, "node") orelse continue;
            const name = getJsonString(node, "name");
            const svc_id = getJsonString(node, "id");

            if (std.mem.eql(u8, name, target_name)) {
                // Delete service
                const del_gql = "mutation($id: String!) { serviceDelete(id: $id) }";
                const del_json = std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\"}}", .{svc_id}) catch continue;
                defer allocator.free(del_json);

                if (api.query(del_gql, del_json)) |del_resp| {
                    allocator.free(del_resp);
                    print("  {s}✅ Deleted {s} from {s}{s}\n\n", .{ GREEN, target_name, acct.name, RESET });
                    // Update state
                    var state = loadState(allocator);
                    _ = state.removeByIssue(issue_num);
                    saveState(state) catch {};
                } else |_| {
                    print("  {s}❌ Delete failed on {s}{s}\n\n", .{ RED, acct.name, RESET });
                }
                return;
            }
        }
    }

    print("  {s}Service {s} not found on any account{s}\n\n", .{ YELLOW, target_name, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// RECYCLE — reassign idle/crashed dev agents to backlog issues
// ═══════════════════════════════════════════════════════════════════════════════

fn runDevRecycle(allocator: Allocator, _: []const []const u8) !void {
    print("\n{s}🔄 DEV AGENT RECYCLE{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}Scanning for idle/crashed swe-agent-* services...{s}\n\n", .{ DIM, RESET });

    var accounts_buf: [MAX_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    var recycled: usize = 0;

    for (accounts_buf[0..account_count]) |acct| {
        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch continue;
        defer api.deinit();

        const gql = "query($projectId: String!) { project(id: $projectId) { services { edges { node { id name deployments(first:1) { edges { node { status } } } } } } } }";
        const vars_json = std.fmt.allocPrint(allocator, "{{\"projectId\":\"{s}\"}}", .{acct.project_id}) catch continue;
        defer allocator.free(vars_json);

        const resp = api.query(gql, vars_json) catch continue;
        defer allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch continue;
        defer parsed.deinit();

        const data_val = getJsonObject(parsed.value, "data") orelse continue;
        const proj_val = getJsonObject(data_val, "project") orelse continue;
        const svcs_val = getJsonObject(proj_val, "services") orelse continue;
        const edges_val = getJsonObject(svcs_val, "edges") orelse continue;
        if (edges_val != .array) continue;

        for (edges_val.array.items) |edge| {
            const node = getJsonObject(edge, "node") orelse continue;
            const name = getJsonString(node, "name");

            if (!std.mem.startsWith(u8, name, "swe-agent-")) continue;

            var dep_status: []const u8 = "NONE";
            if (getJsonObject(node, "deployments")) |deps| {
                if (getJsonObject(deps, "edges")) |dep_edges| {
                    if (dep_edges == .array and dep_edges.array.items.len > 0) {
                        const dep_node = getJsonObject(dep_edges.array.items[0], "node") orelse continue;
                        dep_status = getJsonString(dep_node, "status");
                    }
                }
            }

            if (isIdleStatus(dep_status) or isCrashedStatus(dep_status)) {
                print("  {s}♻️  {s}{s}: {s} → available for reassignment\n", .{ CYAN, name, RESET, dep_status });
                recycled += 1;
            }
        }
    }

    print("\n  {s}{d} agent(s) available for recycling{s}\n", .{ BOLD, recycled, RESET });
    print("  {s}Use `tri dev spawn <issue> --reuse` to assign to new issues{s}\n\n", .{ DIM, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILL — spawn agents for all agent:dev labeled issues
// ═══════════════════════════════════════════════════════════════════════════════

fn runDevFill(allocator: Allocator, args: []const []const u8) !void {
    // Parse flags
    var dry_run = false;
    var max_agents: u32 = 10;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        } else if (std.mem.eql(u8, args[i], "--max") and i + 1 < args.len) {
            i += 1;
            max_agents = std.fmt.parseInt(u32, args[i], 10) catch 10;
        }
    }

    // Load state to skip already-tracked issues
    const state = loadState(allocator);

    print("\n{s}📦 DEV FARM FILL{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    if (dry_run) print("  {s}[DRY RUN]{s}\n", .{ YELLOW, RESET });
    print("  {s}Fetching issues labeled 'agent:dev'... ({d} already tracked){s}\n\n", .{ DIM, state.agent_count, RESET });

    // Fetch issues via gh CLI
    const result = runProcess(allocator, &.{ "gh", "issue", "list", "--label", "agent:dev", "--state", "open", "--json", "number,title,labels", "--limit", "25" }) catch {
        print("  {s}Failed to fetch issues (gh CLI not available?){s}\n\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(result);

    if (result.len < 3) {
        print("  {s}No issues with 'agent:dev' label found{s}\n\n", .{ DIM, RESET });
        return;
    }

    // Parse JSON array of issues
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, result, .{}) catch {
        print("  {s}Failed to parse issue JSON{s}\n\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    if (parsed.value != .array) {
        print("  {s}Unexpected JSON format (expected array){s}\n\n", .{ RED, RESET });
        return;
    }

    const issues = parsed.value.array.items;
    if (issues.len == 0) {
        print("  {s}No issues with 'agent:dev' label found{s}\n\n", .{ DIM, RESET });
        return;
    }

    // Display plan table
    print("  {s}ISSUE   TITLE                              SUBSET          EST.COST{s}\n", .{ DIM, RESET });
    print("  {s}─────────────────────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });

    var total_cost: f32 = 0.0;
    var count: u32 = 0;
    var skipped: u32 = 0;

    for (issues) |issue_val| {
        if (count >= max_agents) break;
        if (issue_val != .object) continue;

        const num = blk: {
            const n = issue_val.object.get("number") orelse break :blk @as(u32, 0);
            if (n != .integer) break :blk @as(u32, 0);
            break :blk @as(u32, @intCast(n.integer));
        };
        if (num == 0) continue;

        // Skip already-tracked issues
        if (state.hasIssue(num)) {
            skipped += 1;
            continue;
        }

        const title = blk: {
            const t = issue_val.object.get("title") orelse break :blk "?";
            if (t != .string) break :blk "?";
            break :blk t.string;
        };

        const subset = dev_pipeline.decomposeIssue(title);
        const model = dev_pipeline.modelForRole("coder");
        const cost = dev_pipeline.estimateCost(model, 50_000);
        total_cost += cost;

        // Truncate title to 35 chars
        const display_title = if (title.len > 35) title[0..35] else title;

        print("  #{d}", .{num});
        padTo(digitCount(num) + 1, 8);
        print("{s}", .{display_title});
        padTo(display_title.len, 37);
        print("{s}", .{subset.toString()});
        padTo(subset.toString().len, 16);
        print("${d:.2}\n", .{cost});

        count += 1;
    }

    print("  {s}─────────────────────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
    print("  {s}Total: {d} new issues | {d} skipped (already tracked) | Est. cost: ${d:.2}{s}\n\n", .{ BOLD, count, skipped, total_cost, RESET });

    if (dry_run) {
        print("  {s}[DRY RUN] No agents spawned. Remove --dry-run to deploy.{s}\n\n", .{ YELLOW, RESET });
        return;
    }

    if (count == 0) {
        print("  {s}No issues to spawn{s}\n\n", .{ DIM, RESET });
        return;
    }

    // Auto-spawn each issue
    print("  {s}Spawning {d} agents...{s}\n\n", .{ CYAN, count, RESET });
    var spawned: u32 = 0;
    var spawn_count: u32 = 0;

    for (issues) |issue_val| {
        if (spawn_count >= max_agents) break;
        if (issue_val != .object) continue;

        const num = blk: {
            const n = issue_val.object.get("number") orelse break :blk @as(u32, 0);
            if (n != .integer) break :blk @as(u32, 0);
            break :blk @as(u32, @intCast(n.integer));
        };
        if (num == 0) continue;

        // Skip already-tracked
        if (state.hasIssue(num)) continue;

        const num_str = std.fmt.allocPrint(allocator, "{d}", .{num}) catch continue;
        defer allocator.free(num_str);

        runDevSpawn(allocator, &.{num_str}) catch {
            print("  {s}Failed to spawn agent for #{d}{s}\n", .{ RED, num, RESET });
            spawn_count += 1;
            continue;
        };
        spawned += 1;
        spawn_count += 1;
    }

    print("\n  {s}FILL DONE: {d}/{d} agents spawned{s}\n\n", .{ BOLD, spawned, count, RESET });
}

pub fn digitCount(n: u32) usize {
    if (n == 0) return 1;
    var count: usize = 0;
    var val = n;
    while (val > 0) : (val /= 10) {
        count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// METRICS — aggregate fitness metrics
// ═══════════════════════════════════════════════════════════════════════════════

fn runDevMetrics(allocator: Allocator) !void {
    print("\n{s}📊 DEV AGENT METRICS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    const state = loadState(allocator);

    if (state.agent_count == 0) {
        print("  {s}No agents tracked. Spawn agents first.{s}\n\n", .{ DIM, RESET });
        return;
    }

    var total_fitness: f32 = 0.0;
    var fitness_count: usize = 0;
    const total_agents = state.agent_count;
    var running: usize = 0;
    var completed: usize = 0;

    for (state.agents[0..state.agent_count]) |*a| {
        if (a.has_fitness) {
            total_fitness += a.fitness.totalScore();
            fitness_count += 1;
            completed += 1;
        }
        if (std.mem.eql(u8, a.statusStr(), "RUNNING") or std.mem.eql(u8, a.statusStr(), "BUILDING")) {
            running += 1;
        }
    }

    print("  Total agents:   {s}{d}{s}\n", .{ BOLD, total_agents, RESET });
    print("  Running:        {s}{d}{s}\n", .{ GREEN, running, RESET });
    print("  With fitness:   {s}{d}{s}\n", .{ CYAN, fitness_count, RESET });

    if (fitness_count > 0) {
        const avg = total_fitness / @as(f32, @floatFromInt(fitness_count));
        print("  Avg fitness:    {s}{d:.3}{s}\n", .{ BOLD, avg, RESET });
        print("  Solve rate:     {s}{d}/{d}{s}\n", .{ CYAN, completed, total_agents, RESET });
    }

    print("\n  Formula: {s}0.4*test_pass + 0.3*spec_compliance + 0.2*(1/time) + 0.1*pr_merged{s}\n\n", .{ DIM, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEADERBOARD — rank agents by fitness score
// ═══════════════════════════════════════════════════════════════════════════════

fn runDevLeaderboard(allocator: Allocator) !void {
    print("\n{s}🏆 DEV AGENT LEADERBOARD{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    const state = loadState(allocator);

    // Collect agents with fitness
    var scored: [MAX_DEV_AGENTS]struct { idx: usize, score: f32 } = undefined;
    var scored_count: usize = 0;

    for (state.agents[0..state.agent_count], 0..) |*a, i| {
        if (a.has_fitness) {
            scored[scored_count] = .{ .idx = i, .score = a.fitness.totalScore() };
            scored_count += 1;
        }
    }

    if (scored_count == 0) {
        print("  {s}No completed runs yet. Spawn agents to populate leaderboard.{s}\n\n", .{ DIM, RESET });
        return;
    }

    // Sort by score descending (simple insertion sort)
    for (1..scored_count) |si| {
        var j = si;
        while (j > 0 and scored[j].score > scored[j - 1].score) {
            const tmp = scored[j];
            scored[j] = scored[j - 1];
            scored[j - 1] = tmp;
            j -= 1;
        }
    }

    print("  {s}RANK  ISSUE   ROLE       FITNESS  TEST  SPEC  TIME    PR{s}\n", .{ DIM, RESET });
    print("  {s}────────────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });

    for (scored[0..scored_count], 0..) |s, rank| {
        const a = &state.agents[s.idx];
        const medal = if (rank == 0) "🥇" else if (rank == 1) "🥈" else if (rank == 2) "🥉" else "  ";
        const pr_str = if (a.fitness.pr_merged) "YES" else "no";

        print("  {s} {d}", .{ medal, rank + 1 });
        padTo(digitCount(@intCast(rank + 1)), 6);
        print("#{d}", .{a.issue_number});
        padTo(digitCount(a.issue_number) + 1, 8);
        print("{s}", .{a.role.toString()});
        padTo(a.role.toString().len, 11);
        print("{s}{d:.3}{s}", .{ BOLD, s.score, RESET });
        padTo(5, 9);
        print("{d:.1}  {d:.1}  {d:.1}h   {s}\n", .{
            a.fitness.test_pass_rate,
            a.fitness.spec_compliance,
            a.fitness.time_hours,
            pr_str,
        });
    }
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELP
// ═══════════════════════════════════════════════════════════════════════════════

fn printHelp() void {
    print("\n{s}TRI DEV — SWE Agent Cloud Development Farm{s}\n\n", .{ BOLD, RESET });
    print("  {s}tri dev status{s}       Show all dev agents across accounts\n", .{ CYAN, RESET });
    print("  {s}tri dev spawn <N>{s}    Spawn agent for issue #N\n", .{ CYAN, RESET });
    print("  {s}tri dev kill <N>{s}     Kill agent for issue #N\n", .{ CYAN, RESET });
    print("  {s}tri dev recycle{s}      List idle/crashed agents for reassignment\n", .{ CYAN, RESET });
    print("  {s}tri dev fill{s}         Spawn agents for all agent:dev issues\n", .{ CYAN, RESET });
    print("  {s}tri dev metrics{s}      Show aggregate fitness metrics\n", .{ CYAN, RESET });
    print("  {s}tri dev leaderboard{s}  Rank agents by fitness score\n", .{ CYAN, RESET });
    print("  {s}tri dev evolve{s}       ASHA+PBT evolution commands\n\n", .{ CYAN, RESET });
    print("  Options for spawn:\n", .{});
    print("    {s}--role{s} <planner|coder|reviewer|tester|integrator>\n", .{ DIM, RESET });
    print("    {s}--model{s} <model-id>   (default: claude-sonnet-4-20250514)\n", .{ DIM, RESET });
    print("    {s}--links{s} <6,7,11,17>  Pipeline links to execute\n\n", .{ DIM, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS (shared with tri_farm.zig pattern)
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

fn isIdleStatus(status: []const u8) bool {
    return std.mem.eql(u8, status, "REMOVED") or std.mem.eql(u8, status, "NONE");
}

fn isCrashedStatus(status: []const u8) bool {
    return std.mem.eql(u8, status, "CRASHED") or std.mem.eql(u8, status, "FAILED");
}

fn isRunningStatus(status: []const u8) bool {
    return std.mem.eql(u8, status, "SUCCESS");
}

pub fn padTo(current: usize, target: usize) void {
    if (current < target) {
        var j: usize = 0;
        while (j < target - current) : (j += 1) {
            print(" ", .{});
        }
    }
}

fn jsonU32(val: std.json.Value, key: []const u8) u32 {
    if (val != .object) return 0;
    const v = val.object.get(key) orelse return 0;
    if (v == .integer) return @intCast(@as(i64, v.integer));
    return 0;
}

fn jsonU64(val: std.json.Value, key: []const u8) u64 {
    if (val != .object) return 0;
    const v = val.object.get(key) orelse return 0;
    if (v == .integer) return @intCast(@as(i64, v.integer));
    return 0;
}

fn jsonF32(val: std.json.Value, key: []const u8) f32 {
    if (val != .object) return 0.0;
    const v = val.object.get(key) orelse return 0.0;
    if (v == .float) return @floatCast(v.float);
    if (v == .integer) return @floatFromInt(@as(i64, v.integer));
    return 0.0;
}

fn jsonBool(val: std.json.Value, key: []const u8) bool {
    if (val != .object) return false;
    const v = val.object.get(key) orelse return false;
    if (v == .bool) return v.bool;
    return false;
}

fn printApiError(val: std.json.Value) void {
    if (getJsonObject(val, "errors")) |errs| {
        if (errs == .array and errs.array.items.len > 0) {
            const msg = getJsonString(errs.array.items[0], "message");
            print("  {s}API error: {s}{s}\n\n", .{ RED, msg, RESET });
        }
    }
}

fn runProcess(allocator: Allocator, argv: []const []const u8) ![]const u8 {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    _ = try child.spawn();

    var stdout_buf: std.ArrayList(u8) = .empty;
    var stderr_buf: std.ArrayList(u8) = .empty;
    defer stderr_buf.deinit(allocator);

    try child.collectOutput(allocator, &stdout_buf, &stderr_buf, 1 * 1024 * 1024);
    _ = try child.wait();

    return try stdout_buf.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "DevFitness.totalScore" {
    const f = DevFitness{
        .test_pass_rate = 0.8,
        .spec_compliance = 0.9,
        .time_hours = 1.5,
        .pr_merged = true,
    };
    const score = f.totalScore();
    // 0.4*0.8 + 0.3*0.9 + 0.2*(1/1.5) + 0.1*1.0 = 0.32 + 0.27 + 0.133 + 0.1 = 0.823
    try std.testing.expect(score > 0.8 and score < 0.85);
}

test "AgentRole.fromString" {
    try std.testing.expect(AgentRole.fromString("coder") == .coder);
    try std.testing.expect(AgentRole.fromString("planner") == .planner);
    try std.testing.expect(AgentRole.fromString("invalid") == null);
}

test "DevFarmState addAgent and findByIssue" {
    var state = DevFarmState{};
    const entry = state.addAgent().?;
    entry.issue_number = 42;
    entry.role = .coder;
    copyToFixed(&entry.service_name, &entry.service_name_len, "swe-agent-42");

    try std.testing.expectEqual(@as(usize, 1), state.agent_count);
    try std.testing.expect(state.findByIssue(42) != null);
    try std.testing.expect(state.findByIssue(99) == null);
}

test "DevFarmState hasIssue const" {
    var state = DevFarmState{};
    const e = state.addAgent().?;
    e.issue_number = 42;

    const const_state: *const DevFarmState = &state;
    try std.testing.expect(const_state.hasIssue(42));
    try std.testing.expect(!const_state.hasIssue(99));
}

test "DevFarmState removeByIssue" {
    var state = DevFarmState{};
    const e1 = state.addAgent().?;
    e1.issue_number = 10;
    const e2 = state.addAgent().?;
    e2.issue_number = 20;
    const e3 = state.addAgent().?;
    e3.issue_number = 30;

    try std.testing.expectEqual(@as(usize, 3), state.agent_count);
    try std.testing.expect(state.removeByIssue(20));
    try std.testing.expectEqual(@as(usize, 2), state.agent_count);
    try std.testing.expect(state.findByIssue(20) == null);
    try std.testing.expect(state.findByIssue(10) != null);
    try std.testing.expect(state.findByIssue(30) != null);
}

test "saveState and loadState roundtrip" {
    const allocator = std.testing.allocator;

    // Save
    var state = DevFarmState{};
    const e1 = state.addAgent().?;
    e1.issue_number = 100;
    e1.role = .planner;
    copyToFixed(&e1.service_name, &e1.service_name_len, "swe-agent-100");
    copyToFixed(&e1.account_name, &e1.account_name_len, "acct1");
    copyToFixed(&e1.status, &e1.status_len, "RUNNING");
    e1.started_at = 1710000000;
    e1.has_fitness = true;
    e1.fitness = .{ .test_pass_rate = 0.8, .spec_compliance = 0.9, .time_hours = 1.5, .pr_merged = true };

    const e2 = state.addAgent().?;
    e2.issue_number = 200;
    e2.role = .reviewer;
    copyToFixed(&e2.service_name, &e2.service_name_len, "swe-agent-200");
    copyToFixed(&e2.status, &e2.status_len, "IDLE");

    try saveState(state);

    // Load
    const loaded = loadState(allocator);
    try std.testing.expectEqual(@as(usize, 2), loaded.agent_count);
    try std.testing.expectEqual(@as(u32, 100), loaded.agents[0].issue_number);
    try std.testing.expectEqual(AgentRole.planner, loaded.agents[0].role);
    try std.testing.expect(loaded.agents[0].has_fitness);
    try std.testing.expect(loaded.agents[0].fitness.test_pass_rate > 0.79);
    try std.testing.expect(loaded.agents[0].fitness.pr_merged);
    try std.testing.expectEqual(@as(u32, 200), loaded.agents[1].issue_number);
    try std.testing.expect(!loaded.agents[1].has_fitness);

    // Cleanup
    std.fs.cwd().deleteFile(STATE_PATH) catch {};
}

test "loadState empty returns default" {
    const allocator = std.testing.allocator;
    // Ensure file doesn't exist
    std.fs.cwd().deleteFile(STATE_PATH) catch {};
    const state = loadState(allocator);
    try std.testing.expectEqual(@as(usize, 0), state.agent_count);
}

test "state sync updates status" {
    var state = DevFarmState{};
    const entry = state.addAgent().?;
    entry.issue_number = 42;
    copyToFixed(&entry.service_name, &entry.service_name_len, "swe-agent-42");
    copyToFixed(&entry.status, &entry.status_len, "BUILDING");

    // Simulate Railway returning SUCCESS
    const live_status = "SUCCESS";
    if (state.findByIssue(42)) |e| {
        if (!std.mem.eql(u8, e.statusStr(), live_status)) {
            copyToFixed(&e.status, &e.status_len, live_status);
        }
    }

    try std.testing.expectEqualStrings("SUCCESS", state.findByIssue(42).?.statusStr());
}

test "leaderboard sorting" {
    var state = DevFarmState{};
    const a1 = state.addAgent().?;
    a1.issue_number = 1;
    a1.has_fitness = true;
    a1.fitness = .{ .test_pass_rate = 0.5, .spec_compliance = 0.5, .time_hours = 2.0, .pr_merged = false };

    const a2 = state.addAgent().?;
    a2.issue_number = 2;
    a2.has_fitness = true;
    a2.fitness = .{ .test_pass_rate = 1.0, .spec_compliance = 1.0, .time_hours = 1.0, .pr_merged = true };

    const a3 = state.addAgent().?;
    a3.issue_number = 3;
    a3.has_fitness = true;
    a3.fitness = .{ .test_pass_rate = 0.8, .spec_compliance = 0.9, .time_hours = 1.5, .pr_merged = true };

    // Scores: a1 ~0.40, a3 ~0.82, a2 ~1.0
    try std.testing.expect(a2.fitness.totalScore() > a3.fitness.totalScore());
    try std.testing.expect(a3.fitness.totalScore() > a1.fitness.totalScore());
}

test "DevFitness.totalScore zero time" {
    const f = DevFitness{
        .test_pass_rate = 1.0,
        .spec_compliance = 1.0,
        .time_hours = 0.0,
        .pr_merged = false,
    };
    const score = f.totalScore();
    // time_hours=0 → time_score=0
    try std.testing.expect(score > 0.6 and score < 0.8);
}
