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

const print = std.debug.print;

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

            print("  {s} {s}{s}{s}", .{ icon, color, name, RESET });
            padTo(name.len, 25);
            print(" #{s}", .{issue_str});
            padTo(issue_str.len + 1, 8);
            print(" coder      {s}{s}{s}\n", .{ color, dep_status, RESET });
        }

        total_agents += acct_agents;

        if (acct_agents == 0) {
            print("  {s}(no dev agents){s}\n", .{ DIM, RESET });
        }
        print("\n", .{});
    }

    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}TOTAL: {d} agents | 🟢 {d} running | 💤 {d} idle | 🔴 {d} crashed{s}\n\n", .{
        BOLD, total_agents, total_running, total_idle, total_crashed, RESET,
    });
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
    print("  Issue: #{d}\n", .{issue_num});
    print("  Role: {s}\n", .{role.toString()});
    print("  Model: {s}\n", .{model});
    print("  Links: {s}\n\n", .{links});

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

    const create_gql = "mutation($input: ServiceCreateInput!) { serviceCreate(input: $input) { id name } }";
    const create_json = std.fmt.allocPrint(allocator,
        \\{{"input":{{"projectId":"{s}","name":"{s}","source":{{"repo":"gHashTag/trinity"}}}}}}
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

    // Set env vars for SWE agent
    const issue_str = std.fmt.allocPrint(allocator, "{d}", .{issue_num}) catch return;
    defer allocator.free(issue_str);

    const set_vars_gql = "mutation($input: VariableCollectionUpsertInput!) { variableCollectionUpsert(input: $input) }";
    const set_vars_json = std.fmt.allocPrint(allocator,
        \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","variables":{{"ISSUE_NUMBER":"{s}","AGENT_ROLE":"{s}","TRINITY_MODEL_CODER":"{s}","PIPELINE_LINKS":"{s}","GITHUB_TOKEN":"${{AGENT_GH_TOKEN}}","RAILWAY_DOCKERFILE_PATH":"Dockerfile.swe-agent"}}}}}}
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

    print("\n  {s}✅ Agent spawned: {s} → issue #{d}{s}\n", .{ GREEN, svc_name, issue_num, RESET });
    print("  {s}Deploying with Dockerfile.swe-agent...{s}\n\n", .{ DIM, RESET });
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

fn runDevFill(allocator: Allocator, _: []const []const u8) !void {
    print("\n{s}📦 DEV FARM FILL{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}Fetching issues labeled 'agent:dev'...{s}\n\n", .{ DIM, RESET });

    // Use gh CLI to get issues
    const result = runProcess(allocator, &.{ "gh", "issue", "list", "--label", "agent:dev", "--state", "open", "--json", "number,title", "--limit", "25" });
    if (result) |output| {
        defer allocator.free(output);
        print("  Issues found:\n{s}\n", .{output});
        print("  {s}Use `tri dev spawn <N>` to spawn individual agents{s}\n\n", .{ DIM, RESET });
    } else |_| {
        print("  {s}Failed to fetch issues (gh CLI not available?){s}\n\n", .{ RED, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// METRICS — aggregate fitness metrics
// ═══════════════════════════════════════════════════════════════════════════════

fn runDevMetrics(allocator: Allocator) !void {
    _ = allocator;
    print("\n{s}📊 DEV AGENT METRICS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}No completed agent runs yet.{s}\n", .{ DIM, RESET });
    print("  {s}Metrics will appear after agents complete pipeline runs.{s}\n\n", .{ DIM, RESET });
    print("  Fitness formula: {s}0.4*test_pass + 0.3*spec_compliance + 0.2*(1/time) + 0.1*pr_merged{s}\n\n", .{ CYAN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEADERBOARD — rank agents by fitness score
// ═══════════════════════════════════════════════════════════════════════════════

fn runDevLeaderboard(allocator: Allocator) !void {
    _ = allocator;
    print("\n{s}🏆 DEV AGENT LEADERBOARD{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}RANK  ISSUE   ROLE       FITNESS  TEST  SPEC  TIME    PR{s}\n", .{ DIM, RESET });
    print("  {s}────────────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
    print("  {s}No completed runs yet. Spawn agents to populate leaderboard.{s}\n\n", .{ DIM, RESET });
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

fn padTo(current: usize, target: usize) void {
    if (current < target) {
        var j: usize = 0;
        while (j < target - current) : (j += 1) {
            print(" ", .{});
        }
    }
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
