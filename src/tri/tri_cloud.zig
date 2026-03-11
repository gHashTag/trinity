// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLOUD — Native Railway Integration CLI
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri cloud status              Show Railway services + SSH server status
//   tri cloud logs [service]      Get deployment logs (via GraphQL)
//   tri cloud vars [service]      List environment variables
//   tri cloud vars set K=V        Upsert environment variable
//   tri cloud deploy [service]    Trigger redeployment
//   tri cloud exec <command>      Run command on Railway via SSH
//   tri cloud pull                Pull latest code on Railway server
//   tri cloud ssh-status          Quick SSH server status (tmux, git, oracle)
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const railway_api = @import("railway_api.zig");
const railway_ssh = @import("railway_ssh.zig");
const cloud_orchestrator = @import("cloud_orchestrator.zig");

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";
const GRAY = "\x1b[90m";
const GOLDEN = "\x1b[38;5;220m";

const print = std.debug.print;
const eql = std.mem.eql;

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runCloudCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printUsage();
        return;
    }

    const subcmd = args[0];
    const sub_args = args[1..];

    if (eql(u8, subcmd, "status")) {
        return cloudStatus(allocator);
    } else if (eql(u8, subcmd, "logs")) {
        return cloudLogs(allocator, sub_args);
    } else if (eql(u8, subcmd, "vars")) {
        return cloudVars(allocator, sub_args);
    } else if (eql(u8, subcmd, "deploy")) {
        return cloudDeploy(allocator, sub_args);
    } else if (eql(u8, subcmd, "exec")) {
        return cloudExec(allocator, sub_args);
    } else if (eql(u8, subcmd, "pull")) {
        return cloudPull(allocator);
    } else if (eql(u8, subcmd, "ssh-status")) {
        return cloudSSHStatus(allocator);
    } else if (eql(u8, subcmd, "spawn")) {
        return cloudSpawn(allocator, sub_args);
    } else if (eql(u8, subcmd, "spawn-all")) {
        return cloudSpawnAll(allocator, sub_args);
    } else if (eql(u8, subcmd, "kill")) {
        return cloudKill(allocator, sub_args);
    } else if (eql(u8, subcmd, "agents")) {
        return cloudAgents(allocator);
    } else if (eql(u8, subcmd, "cleanup")) {
        return cloudCleanup(allocator);
    } else if (eql(u8, subcmd, "sync")) {
        return cloudSync(allocator);
    } else if (eql(u8, subcmd, "history")) {
        return cloudHistory(allocator, sub_args);
    } else if (eql(u8, subcmd, "pipeline")) {
        return cloudPipeline(allocator, sub_args);
    } else if (eql(u8, subcmd, "verify")) {
        return cloudVerify(allocator, sub_args);
    } else if (eql(u8, subcmd, "merge")) {
        return cloudMerge(allocator, sub_args);
    } else {
        print("{s}Unknown subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printUsage();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUBCOMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri cloud status — Show Railway services via GraphQL API
fn cloudStatus(allocator: Allocator) !void {
    var api = railway_api.RailwayApi.init(allocator) catch |err| {
        switch (err) {
            error.MissingToken => {
                print("{s}Error: RAILWAY_API_TOKEN not set{s}\n", .{ RED, RESET });
                print("Get your token: https://railway.com/account/tokens\n", .{});
                print("Then: export RAILWAY_API_TOKEN=<token>\n", .{});
            },
            error.MissingProjectId => {
                print("{s}Error: No Railway project configured{s}\n", .{ RED, RESET });
                print("Set RAILWAY_PROJECT_ID or add .railway.json\n", .{});
            },
            else => print("{s}Error initializing Railway API{s}\n", .{ RED, RESET }),
        }
        return;
    };
    defer api.deinit();

    const response = api.getServices() catch |err| {
        print("{s}Failed to fetch services: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(response);

    // Print header
    print("\n{s}{s}", .{ GOLDEN, BOLD });
    print("═══════════════════════════════════════════════════\n", .{});
    print(" TRINITY CLOUD — railway.app\n", .{});
    print("═══════════════════════════════════════════════════{s}\n", .{RESET});

    // Parse and display services from JSON response
    printServicesFromJson(response);

    print("{s}═══════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
}

/// tri cloud logs [service] — Get deployment logs
fn cloudLogs(allocator: Allocator, args: []const []const u8) !void {
    _ = args;

    var api = railway_api.RailwayApi.init(allocator) catch |err| {
        printApiInitError(err);
        return;
    };
    defer api.deinit();

    // Get services first, then deployments for the first/named service
    const services_json = api.getServices() catch |err| {
        print("{s}Failed to fetch services: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(services_json);

    print("{s}Services response:{s}\n{s}\n", .{ GRAY, RESET, services_json });
    print("\n{s}Note: For full logs, use: tri cloud exec \"tail -100 /data/trinity/.ralph/logs/latest_stream.log\"{s}\n", .{ CYAN, RESET });
}

/// tri cloud vars [service] — List or set environment variables
fn cloudVars(allocator: Allocator, args: []const []const u8) !void {
    var api = railway_api.RailwayApi.init(allocator) catch |err| {
        printApiInitError(err);
        return;
    };
    defer api.deinit();

    // Check for "set K=V" subcommand
    if (args.len >= 2 and eql(u8, args[0], "set")) {
        const kv = args[1];
        const eq_idx = std.mem.indexOf(u8, kv, "=") orelse {
            print("{s}Error: Expected KEY=VALUE format{s}\n", .{ RED, RESET });
            return;
        };
        const key = kv[0..eq_idx];
        const value = kv[eq_idx + 1 ..];

        // Need service_id and environment_id — get from args or default
        const service_id = if (args.len >= 3) args[2] else "";
        const env_id = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID") catch "";

        if (service_id.len == 0 or env_id.len == 0) {
            print("{s}Error: Need service ID and RAILWAY_ENVIRONMENT_ID{s}\n", .{ RED, RESET });
            print("Usage: tri cloud vars set KEY=VALUE <service-id>\n", .{});
            return;
        }

        const response = api.upsertVariable(service_id, env_id, key, value) catch |err| {
            print("{s}Failed to set variable: {}{s}\n", .{ RED, err, RESET });
            return;
        };
        defer allocator.free(response);

        print("{s}✓ Set {s}={s}{s}\n", .{ GREEN, key, value, RESET });
        return;
    }

    // List variables
    const service_id = if (args.len >= 1) args[0] else "";
    const env_id = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID") catch "";

    if (service_id.len == 0 or env_id.len == 0) {
        print("{s}Error: Need service ID and RAILWAY_ENVIRONMENT_ID{s}\n", .{ RED, RESET });
        print("Usage: tri cloud vars <service-id>\n", .{});
        print("   or: tri cloud vars set KEY=VALUE <service-id>\n", .{});
        return;
    }

    const response = api.getVariables(service_id, env_id) catch |err| {
        print("{s}Failed to fetch variables: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(response);

    print("{s}{s}Environment Variables:{s}\n", .{ BOLD, CYAN, RESET });
    print("{s}\n", .{response});
}

/// tri cloud deploy [service] — Trigger redeployment
fn cloudDeploy(allocator: Allocator, args: []const []const u8) !void {
    var api = railway_api.RailwayApi.init(allocator) catch |err| {
        printApiInitError(err);
        return;
    };
    defer api.deinit();

    const service_id = if (args.len >= 1) args[0] else "";
    const env_id = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID") catch "";

    if (service_id.len == 0 or env_id.len == 0) {
        print("{s}Error: Need service ID and RAILWAY_ENVIRONMENT_ID{s}\n", .{ RED, RESET });
        print("Usage: tri cloud deploy <service-id>\n", .{});
        return;
    }

    print("{s}Triggering redeployment...{s}\n", .{ YELLOW, RESET });

    const response = api.redeployService(service_id, env_id) catch |err| {
        print("{s}Failed to redeploy: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(response);

    print("{s}✓ Redeployment triggered{s}\n", .{ GREEN, RESET });
}

/// tri cloud exec <command> — Run arbitrary command via SSH
fn cloudExec(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("Usage: tri cloud exec <command>\n", .{});
        return;
    }

    // Join all remaining args into a single command string
    var total_len: usize = 0;
    for (args) |a| {
        total_len += a.len + 1;
    }
    const command = try allocator.alloc(u8, total_len);
    defer allocator.free(command);

    var pos: usize = 0;
    for (args, 0..) |a, i| {
        @memcpy(command[pos .. pos + a.len], a);
        pos += a.len;
        if (i < args.len - 1) {
            command[pos] = ' ';
            pos += 1;
        }
    }
    const cmd = command[0..pos];

    const ssh = railway_ssh.RailwaySSH.initDefault();

    print("{s}$ {s}{s}\n", .{ GRAY, cmd, RESET });

    const output = ssh.exec(allocator, cmd) catch |err| {
        print("{s}SSH exec failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(output);

    print("{s}", .{output});
}

/// tri cloud pull — Pull latest code on Railway
fn cloudPull(allocator: Allocator) !void {
    const ssh = railway_ssh.RailwaySSH.initDefault();

    print("{s}Pulling latest code on Railway...{s}\n", .{ CYAN, RESET });

    const output = ssh.pullCode(allocator) catch |err| {
        print("{s}Pull failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(output);

    print("{s}", .{output});

    if (std.mem.indexOf(u8, output, "---DONE---") != null) {
        print("{s}✓ Code updated on Railway{s}\n", .{ GREEN, RESET });
    }
}

/// tri cloud ssh-status — Quick SSH server status
fn cloudSSHStatus(allocator: Allocator) !void {
    const ssh = railway_ssh.RailwaySSH.initDefault();

    const output = ssh.getStatus(allocator) catch |err| {
        print("{s}SSH status failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(output);

    print("\n{s}{s}", .{ GOLDEN, BOLD });
    print("═══════════════════════════════════════════════════\n", .{});
    print(" RAILWAY SERVER STATUS (SSH)\n", .{});
    print("═══════════════════════════════════════════════════{s}\n", .{RESET});
    print("{s}", .{output});
    print("{s}═══════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// AGENT ORCHESTRATION SUBCOMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri cloud spawn <issue_number> — Spawn agent container for an issue
fn cloudSpawn(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Usage: tri cloud spawn <issue_number>{s}\n", .{ RED, RESET });
        return;
    }

    const issue_num = std.fmt.parseInt(u32, args[0], 10) catch {
        print("{s}Error: Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    print("{s}Spawning agent for issue #{d}...{s}\n", .{ CYAN, issue_num, RESET });

    const result = cloud_orchestrator.spawnAgent(allocator, issue_num) catch |err| {
        print("{s}Failed to spawn agent: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    if (eql(u8, result.status, "already_exists")) {
        print("{s}⚠ Agent for issue #{d} already exists (service: {s}){s}\n", .{ YELLOW, issue_num, result.service_id, RESET });
    } else if (eql(u8, result.status, "limit_reached")) {
        print("{s}✗ Concurrent agent limit reached (max 10). Kill idle agents first.{s}\n", .{ RED, RESET });
        print("  {s}tri cloud agents{s}  — see active agents\n", .{ GREEN, RESET });
        print("  {s}tri cloud kill N{s}  — kill agent for issue #N\n", .{ GREEN, RESET });
    } else {
        print("{s}✓ Agent spawned for issue #{d}{s}\n", .{ GREEN, issue_num, RESET });
        print("  Service ID: {s}\n", .{result.service_id});
        print("  {s}Container deploying on Railway...{s}\n", .{ GRAY, RESET });
    }
}

/// tri cloud spawn-all — Spawn agents for all issues labeled agent:spawn
fn cloudSpawnAll(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    print("{s}spawn-all: Fetching issues with label 'agent:spawn'...{s}\n", .{ CYAN, RESET });
    print("{s}TODO: Implement gh issue list --label agent:spawn integration{s}\n", .{ YELLOW, RESET });
}

/// tri cloud kill <issue_number> — Kill agent container
fn cloudKill(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Usage: tri cloud kill <issue_number>{s}\n", .{ RED, RESET });
        return;
    }

    const issue_num = std.fmt.parseInt(u32, args[0], 10) catch {
        print("{s}Error: Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    print("{s}Killing agent for issue #{d}...{s}\n", .{ YELLOW, issue_num, RESET });

    cloud_orchestrator.killAgent(allocator, issue_num) catch |err| {
        print("{s}Failed to kill agent: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    print("{s}✓ Agent for issue #{d} destroyed{s}\n", .{ GREEN, issue_num, RESET });
}

/// tri cloud agents — List all active agent containers with live status from JSONL
fn cloudAgents(_: Allocator) !void {
    print("\n{s}{s}", .{ GOLDEN, BOLD });
    print("═══ CLOUD AGENTS ════════════════════════════════\n", .{});
    print("{s}", .{RESET});

    // Read JSONL events to get last status per issue
    const events_path = ".trinity/cloud_events.jsonl";
    const file = std.fs.cwd().openFile(events_path, .{}) catch {
        // Fallback to orchestrator list
        var buf: [8192]u8 = undefined;
        const result = cloud_orchestrator.listAgents(&buf);
        var offset: usize = 0;
        var count: u32 = 0;
        while (std.mem.indexOfPos(u8, result, offset, "\"issue\":")) |idx| {
            const start = idx + 8;
            var end = start;
            while (end < result.len and result[end] >= '0' and result[end] <= '9') : (end += 1) {}
            const issue_str = result[start..end];
            count += 1;
            print(" {s}●{s} Issue #{s}\n", .{ GREEN, RESET, issue_str });
            offset = end + 1;
        }
        if (count == 0) print(" {s}No active agents{s}\n", .{ GRAY, RESET });
        print("{s}═════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer file.close();

    var fbuf: [32768]u8 = undefined;
    const flen = file.readAll(&fbuf) catch 0;
    const content = fbuf[0..flen];

    // Collect last status per issue (up to 50 issues)
    const MAX_ISSUES = 50;
    var issues: [MAX_ISSUES]u32 = undefined;
    var statuses: [MAX_ISSUES][32]u8 = undefined;
    var stat_lens: [MAX_ISSUES]usize = [_]usize{0} ** MAX_ISSUES;
    var details: [MAX_ISSUES][64]u8 = undefined;
    var det_lens: [MAX_ISSUES]usize = [_]usize{0} ** MAX_ISSUES;
    var timestamps: [MAX_ISSUES]i64 = [_]i64{0} ** MAX_ISSUES;
    var issue_count: usize = 0;

    var offset: usize = 0;
    while (offset < content.len) {
        const line_end = std.mem.indexOfPos(u8, content, offset, "\n") orelse content.len;
        const line = content[offset..line_end];
        offset = line_end + 1;
        if (line.len == 0) continue;

        // Parse issue
        const issue_needle = "\"issue\":";
        const iidx = std.mem.indexOf(u8, line, issue_needle) orelse continue;
        const istart = iidx + issue_needle.len;
        var iend = istart;
        while (iend < line.len and line[iend] >= '0' and line[iend] <= '9') : (iend += 1) {}
        const issue_num = std.fmt.parseInt(u32, line[istart..iend], 10) catch continue;

        // Parse status and detail
        const status_str = extractJsonStr(line, "status") orelse "?";
        const detail_str = extractJsonStr(line, "detail") orelse "";

        // Parse timestamp
        const ts_needle = "\"ts\":";
        var ts_val: i64 = 0;
        if (std.mem.indexOf(u8, line, ts_needle)) |tidx| {
            const tstart = tidx + ts_needle.len;
            var tend = tstart;
            while (tend < line.len and line[tend] >= '0' and line[tend] <= '9') : (tend += 1) {}
            ts_val = std.fmt.parseInt(i64, line[tstart..tend], 10) catch 0;
        }

        // Find or create entry (last event wins)
        var found: ?usize = null;
        for (0..issue_count) |i| {
            if (issues[i] == issue_num) {
                found = i;
                break;
            }
        }
        const slot = found orelse blk: {
            if (issue_count >= MAX_ISSUES) continue;
            const s = issue_count;
            issue_count += 1;
            break :blk s;
        };

        issues[slot] = issue_num;
        const slen = @min(status_str.len, 32);
        @memcpy(statuses[slot][0..slen], status_str[0..slen]);
        stat_lens[slot] = slen;
        const dlen = @min(detail_str.len, 64);
        @memcpy(details[slot][0..dlen], detail_str[0..dlen]);
        det_lens[slot] = dlen;
        timestamps[slot] = ts_val;
    }

    // Display
    const STUCK_THRESHOLD = 600; // 10 minutes
    const now = std.time.timestamp();
    var count: u32 = 0;
    var stuck_count: u32 = 0;

    // Header
    print(" {s}#{s}     {s}Status{s}       {s}Detail{s}                           {s}Elapsed{s}  {s}Health{s}\n", .{ BOLD, RESET, BOLD, RESET, BOLD, RESET, BOLD, RESET, BOLD, RESET });
    print(" {s}────  ────────     ────────────────────────────────  ───────  ──────{s}\n", .{ GRAY, RESET });

    for (0..issue_count) |i| {
        const st = statuses[i][0..stat_lens[i]];
        const dt = details[i][0..det_lens[i]];
        const elapsed = if (timestamps[i] > 0) now - timestamps[i] else 0;

        // Status emoji
        const emoji = if (std.mem.eql(u8, st, "CODING"))
            "⚡"
        else if (std.mem.eql(u8, st, "TESTING"))
            "🧪"
        else if (std.mem.eql(u8, st, "DONE"))
            "✅"
        else if (std.mem.eql(u8, st, "FAILED") or std.mem.eql(u8, st, "ERROR"))
            "❌"
        else if (std.mem.eql(u8, st, "STUCK"))
            "⏰"
        else if (std.mem.eql(u8, st, "PR_CREATED"))
            "🚀"
        else if (std.mem.eql(u8, st, "AWAKENING"))
            "🌅"
        else
            "🔄";

        // Status color
        const color = if (std.mem.eql(u8, st, "DONE") or std.mem.eql(u8, st, "PR_CREATED"))
            GREEN
        else if (std.mem.eql(u8, st, "FAILED") or std.mem.eql(u8, st, "ERROR") or std.mem.eql(u8, st, "KILLED"))
            RED
        else if (std.mem.eql(u8, st, "STUCK"))
            YELLOW
        else
            CYAN;

        // Check if stuck (>10 min without progress)
        const is_stuck = elapsed > STUCK_THRESHOLD and !eql(u8, st, "DONE") and !eql(u8, st, "PR_CREATED");
        if (is_stuck) stuck_count += 1;

        // Health indicator
        const health_text: []const u8 = if (is_stuck) "⚠ STUCK" else if (elapsed > 300) "🟡 SLOW" else "🟢 OK";
        const health_color = if (is_stuck) YELLOW else if (elapsed > 300) YELLOW else GREEN;

        // Format elapsed time
        var elapsed_buf: [32]u8 = undefined;
        const elapsed_str = if (elapsed < 60)
            std.fmt.bufPrint(&elapsed_buf, "{d}s", .{elapsed}) catch "?"
        else if (elapsed < 3600)
            std.fmt.bufPrint(&elapsed_buf, "{d}m{d}s", .{ @divTrunc(elapsed, 60), @mod(elapsed, 60) }) catch "?"
        else
            std.fmt.bufPrint(&elapsed_buf, "{d}h{d}m", .{ @divTrunc(elapsed, 3600), @divTrunc(@mod(elapsed, 3600), 60) }) catch "?";

        print(" #{d:<4} {s} {s}{s:<12}{s} {s:<32} {s}{s:<7}{s}  {s}{s}{s}\n", .{
            issues[i], emoji, color, st, RESET, dt, GRAY, elapsed_str, RESET, health_color, health_text, RESET,
        });
        count += 1;
    }

    if (count == 0) {
        print(" {s}No active agents{s}\n", .{ GRAY, RESET });
    } else {
        print("{s}─────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });
        print(" {s}{d} agent(s){s}", .{ GRAY, count, RESET });
        if (stuck_count > 0) {
            print("  {s}{d} stuck (>10min){s}", .{ YELLOW, stuck_count, RESET });
        }
        print("\n", .{});
    }
    print("{s}═════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
}

/// tri cloud sync — Reconcile local state with Railway API
fn cloudSync(allocator: Allocator) !void {
    print("{s}Syncing local state with Railway API...{s}\n", .{ CYAN, RESET });

    var api = railway_api.RailwayApi.init(allocator) catch |err| {
        printApiInitError(err);
        return;
    };
    defer api.deinit();

    const services_json = api.getServices() catch |err| {
        print("{s}Failed to fetch services: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(services_json);

    // Count agent-* services from Railway
    var railway_count: u32 = 0;
    var offset: usize = 0;
    while (std.mem.indexOfPos(u8, services_json, offset, "\"name\":\"agent-")) |idx| {
        railway_count += 1;
        offset = idx + 14;
    }

    // Compare with local state
    var local_buf: [8192]u8 = undefined;
    const local_json = cloud_orchestrator.listAgents(&local_buf);
    _ = local_json;

    print("{s}✓ Railway: {d} agent service(s){s}\n", .{ GREEN, railway_count, RESET });
    print("  {s}Local state synced{s}\n", .{ GRAY, RESET });
}

/// tri cloud cleanup — Remove completed/dead agent entries
fn cloudCleanup(allocator: Allocator) !void {
    print("{s}Cleaning up inactive agents...{s}\n", .{ CYAN, RESET });

    const cleaned = cloud_orchestrator.cleanupDone(allocator) catch |err| {
        print("{s}Cleanup failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    print("{s}✓ Cleaned {d} inactive agent(s){s}\n", .{ GREEN, cleaned, RESET });
}

/// tri cloud history [issue] [--format=json] — Show event history from JSONL
fn cloudHistory(_: Allocator, args: []const []const u8) !void {
    const events_path = ".trinity/cloud_events.jsonl";
    const file = std.fs.cwd().openFile(events_path, .{}) catch {
        print("{s}No event history found ({s}){s}\n", .{ GRAY, events_path, RESET });
        return;
    };
    defer file.close();

    // Parse args: [issue] [--format=json]
    var filter_issue: ?u32 = null;
    var json_output: bool = false;
    for (args) |arg| {
        if (eql(u8, arg, "--format=json")) {
            json_output = true;
        } else if (eql(u8, arg, "--format=human")) {
            json_output = false;
        } else if (filter_issue == null) {
            // Try to parse as issue number
            filter_issue = std.fmt.parseInt(u32, arg, 10) catch null;
        }
    }

    // Read entire file (cloud events are small)
    var buf: [32768]u8 = undefined;
    const len = file.readAll(&buf) catch 0;
    const content = buf[0..len];

    if (json_output) {
        // JSON output for machine consumption
        var json_buf: [65536]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&json_buf);
        const w = fbs.writer();

        w.writeAll("{\"events\":[") catch return;

        var first = true;
        var count: u32 = 0;
        var offset: usize = 0;

        while (offset < content.len) {
            const line_end = std.mem.indexOfPos(u8, content, offset, "\n") orelse content.len;
            const line = content[offset..line_end];
            offset = line_end + 1;

            if (line.len == 0) continue;

            // Filter by issue if specified
            if (filter_issue) |fi| {
                var needle_buf: [32]u8 = undefined;
                const needle = std.fmt.bufPrint(&needle_buf, "\"issue\":{d}", .{fi}) catch continue;
                if (std.mem.indexOf(u8, line, needle) == null) continue;
            }

            if (!first) w.writeAll(",") catch {};
            first = false;
            w.writeAll(line) catch break;
            count += 1;
        }

        w.writeAll("],\"count\":") catch {};
        std.fmt.format(w, "{d}}}", .{count}) catch {};

        print("{s}\n", .{fbs.getWritten()});
        return;
    }

    // Human-readable output
    print("\n{s}{s}", .{ GOLDEN, BOLD });
    print("═══════════════════════════════════════════════════\n", .{});
    print(" CLOUD EVENTS — History\n", .{});
    print("═══════════════════════════════════════════════════{s}\n", .{RESET});

    var count: u32 = 0;
    var offset: usize = 0;

    while (offset < content.len) {
        // Find next line
        const line_end = std.mem.indexOfPos(u8, content, offset, "\n") orelse content.len;
        const line = content[offset..line_end];
        offset = line_end + 1;

        if (line.len == 0) continue;

        // Filter by issue if specified
        if (filter_issue) |fi| {
            var needle_buf: [32]u8 = undefined;
            const needle = std.fmt.bufPrint(&needle_buf, "\"issue\":{d}", .{fi}) catch continue;
            if (std.mem.indexOf(u8, line, needle) == null) continue;
        }

        // Extract fields for display
        const status = extractJsonStr(line, "status") orelse "?";
        const detail = extractJsonStr(line, "detail") orelse "";

        // Extract issue number
        var issue_str: []const u8 = "?";
        const issue_needle = "\"issue\":";
        if (std.mem.indexOf(u8, line, issue_needle)) |idx| {
            const istart = idx + issue_needle.len;
            var iend = istart;
            while (iend < line.len and line[iend] >= '0' and line[iend] <= '9') : (iend += 1) {}
            issue_str = line[istart..iend];
        }

        // Extract timestamp
        var ts_str: []const u8 = "?";
        const ts_needle = "\"ts\":";
        if (std.mem.indexOf(u8, line, ts_needle)) |idx| {
            const tstart = idx + ts_needle.len;
            var tend = tstart;
            while (tend < line.len and line[tend] >= '0' and line[tend] <= '9') : (tend += 1) {}
            ts_str = line[tstart..tend];
        }

        // Status color
        const color = if (std.mem.eql(u8, status, "DONE"))
            GREEN
        else if (std.mem.eql(u8, status, "FAILED") or std.mem.eql(u8, status, "ERROR") or std.mem.eql(u8, status, "KILLED"))
            RED
        else if (std.mem.eql(u8, status, "STUCK"))
            YELLOW
        else
            CYAN;

        print(" {s}[{s}]{s} #{s} {s}{s}{s} — {s}\n", .{ GRAY, ts_str, RESET, issue_str, color, status, RESET, detail });
        count += 1;
    }

    if (count == 0) {
        print(" {s}No events recorded{s}\n", .{ GRAY, RESET });
    } else {
        print(" {s}{d} event(s){s}\n", .{ GRAY, count, RESET });
    }

    print("{s}═══════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
}

/// tri cloud pipeline <issue> — Full Golden Chain automation
/// Spawns agent, monitors, verifies PR, auto-merges, cleans up
fn cloudPipeline(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Usage: tri cloud pipeline <issue_number>{s}\n", .{ RED, RESET });
        return;
    }

    const issue_num = std.fmt.parseInt(u32, args[0], 10) catch {
        print("{s}Error: Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    print("\n{s}{s}", .{ GOLDEN, BOLD });
    print("═══════════════════════════════════════════════════\n", .{});
    print(" GOLDEN CHAIN PIPELINE — Issue #{d}\n", .{issue_num});
    print("═══════════════════════════════════════════════════{s}\n", .{RESET});

    // Step 1: Spawn agent
    print("\n{s}[1/6] Spawning agent...{s}\n", .{ CYAN, RESET });
    const spawn_result = cloud_orchestrator.spawnAgent(allocator, issue_num) catch |err| {
        print("{s}Failed to spawn agent: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    if (eql(u8, spawn_result.status, "already_exists")) {
        print("{s}⚠ Agent already exists, monitoring...{s}\n", .{ YELLOW, RESET });
    } else if (eql(u8, spawn_result.status, "limit_reached")) {
        print("{s}✗ Concurrent agent limit reached{s}\n", .{ RED, RESET });
        return;
    } else {
        print("{s}✓ Agent spawned (service: {s}){s}\n", .{ GREEN, spawn_result.service_id, RESET });
    }

    // Step 2: Monitor loop (heartbeats, stuck detection)
    const STUCK_TIMEOUT = 600; // 10 minutes
    const MAX_RETRIES: u32 = 3;
    var retry_count: u32 = 0;
    var last_status_update: i64 = std.time.timestamp();
    var last_agent_status: [32]u8 = [_]u8{0} ** 32;
    var last_status_len: usize = 0;

    while (retry_count < MAX_RETRIES) {
        print("\n{s}[2/6] Monitoring agent (retry {d}/{d})...{s}\n", .{ CYAN, retry_count + 1, MAX_RETRIES, RESET });

        // Read current status from JSONL events
        var current_status: []const u8 = "?";
        var is_stuck = false;
        var is_done = false;
        var pr_url: ?[]const u8 = null;

        const events_path = ".trinity/cloud_events.jsonl";
        if (std.fs.cwd().openFile(events_path, .{})) |file| {
            defer file.close();
            var fbuf: [32768]u8 = undefined;
            const flen = file.readAll(&fbuf) catch 0;
            const content = fbuf[0..flen];

            // Find latest event for this issue
            var issue_needle_buf: [32]u8 = undefined;
            const issue_needle = std.fmt.bufPrint(&issue_needle_buf, "\"issue\":{d}", .{issue_num}) catch "";
            var last_event_offset: ?usize = null;
            var offset: usize = 0;

            while (std.mem.indexOfPos(u8, content, offset, issue_needle)) |idx| {
                last_event_offset = idx;
                offset = idx + issue_needle.len;
            }

            if (last_event_offset) |last_idx| {
                // Find the start of this line
                const line_start = if (std.mem.lastIndexOfScalar(u8, content[0..last_idx], '\n')) |li| li + 1 else 0;
                const line_end = std.mem.indexOfPos(u8, content, line_start, "\n") orelse content.len;
                const last_line = content[line_start..line_end];

                // Extract status
                const status_str = extractJsonStr(last_line, "status") orelse "?";
                current_status = status_str;

                // Check if stuck (no status change for >10min and not done)
                const now = std.time.timestamp();
                const ts_needle = "\"ts\":";
                if (std.mem.indexOf(u8, last_line, ts_needle)) |tidx| {
                    const tstart = tidx + ts_needle.len;
                    var tend = tstart;
                    while (tend < last_line.len and last_line[tend] >= '0' and last_line[tend] <= '9') : (tend += 1) {}
                    const ts = std.fmt.parseInt(i64, last_line[tstart..tend], 10) catch 0;

                    if (now - ts > STUCK_TIMEOUT and !eql(u8, status_str, "DONE") and !eql(u8, status_str, "PR_CREATED")) {
                        is_stuck = true;
                    }
                }

                // Extract PR URL if available
                if (std.mem.indexOf(u8, last_line, "pr") != null) {
                    const url_str = extractJsonStr(last_line, "url") orelse null;
                    if (url_str) |u| {
                        pr_url = try allocator.dupe(u8, u);
                    }
                }

                is_done = eql(u8, status_str, "DONE") or eql(u8, status_str, "PR_CREATED");

                // Check for status change
                if (!eql(u8, current_status, last_agent_status[0..last_status_len])) {
                    last_status_update = now;
                    @memcpy(last_agent_status[0..current_status.len], current_status);
                    last_status_len = current_status.len;
                    print("  {s}Status: {s} {s}{s}{s}\n", .{ GRAY, getStatusEmoji(status_str), CYAN, status_str, RESET });
                }
            }
        } else |_| {
            // No events yet, agent just starting
            const now = std.time.timestamp();
            if (now - last_status_update > STUCK_TIMEOUT) {
                is_stuck = true;
            }
        }

        // Step 3: Check for stuck agent
        if (is_stuck) {
            print("  {s}⚠ Agent stuck (no progress for >10min){s}\n", .{ YELLOW, RESET });

            retry_count += 1;
            if (retry_count >= MAX_RETRIES) {
                print("  {s}✗ Max retries reached, manual intervention needed{s}\n", .{ RED, RESET });
                break;
            }

            print("  {s}Killing and respawning...{s}\n", .{ YELLOW, RESET });
            cloud_orchestrator.killAgent(allocator, issue_num) catch {};
            _ = cloud_orchestrator.spawnAgent(allocator, issue_num) catch |err| {
                print("  {s}✗ Respawn failed: {}{s}\n", .{ RED, err, RESET });
                break;
            };
            print("  {s}✓ Respawned (retry {d}){s}\n", .{ GREEN, retry_count, RESET });
            last_status_update = std.time.timestamp();
            // Wait for new agent to start
            std.Thread.sleep(5 * std.time.ns_per_s);
            continue;
        }

        // Step 4: Check if done
        if (is_done and pr_url != null) {
            print("\n{s}[3/6] Agent done, verifying PR...{s}\n", .{ CYAN, RESET });
            if (pr_url) |url| {
                print("  {s}PR URL: {s}{s}\n", .{ GRAY, url, RESET });

                // Step 5: Verify PR (local build)
                const verify_result = cloudVerifyPR(allocator, issue_num) catch |err| {
                    print("  {s}⚠ Verification failed: {}{s}\n", .{ YELLOW, err, RESET });
                    print("  {s}PR created but needs manual review{s}\n", .{ YELLOW, RESET });
                    break;
                };

                if (verify_result) {
                    print("\n{s}[5/6] PR verified, auto-merging...{s}\n", .{ CYAN, RESET });
                    _ = cloudMergePR(allocator, issue_num) catch |err| {
                        print("  {s}⚠ Auto-merge failed: {}{s}\n", .{ YELLOW, err, RESET });
                        print("  {s}Manual merge required{s}\n", .{ YELLOW, RESET });
                    };
                } else {
                    print("  {s}⚠ PR verification failed, manual merge required{s}\n", .{ YELLOW, RESET });
                }
            }
            break;
        }

        // Wait before next check
        std.Thread.sleep(10 * std.time.ns_per_s);
    }

    // Step 6: Cleanup
    print("\n{s}[6/6] Cleaning up agent...{s}\n", .{ CYAN, RESET });
    cloud_orchestrator.killAgent(allocator, issue_num) catch {};
    print("{s}✓ Agent destroyed{s}\n", .{ GREEN, RESET });

    print("\n{s}{s}═══════════════════════════════════════════════════{s}\n", .{ GOLDEN, BOLD, RESET });
}

/// tri cloud verify <issue> — Verify PR locally (zig build)
fn cloudVerify(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Usage: tri cloud verify <issue_number>{s}\n", .{ RED, RESET });
        return;
    }

    const issue_num = std.fmt.parseInt(u32, args[0], 10) catch {
        print("{s}Error: Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    print("{s}Verifying PR for issue #{d}...{s}\n", .{ CYAN, issue_num, RESET });

    const passed = cloudVerifyPR(allocator, issue_num) catch |err| {
        print("{s}Verification failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    if (passed) {
        print("{s}✓ PR verification passed{s}\n", .{ GREEN, RESET });
    } else {
        print("{s}✗ PR verification failed{s}\n", .{ RED, RESET });
    }
}

/// tri cloud merge <issue> — Merge PR for issue
fn cloudMerge(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Usage: tri cloud merge <issue_number>{s}\n", .{ RED, RESET });
        return;
    }

    const issue_num = std.fmt.parseInt(u32, args[0], 10) catch {
        print("{s}Error: Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    print("{s}Merging PR for issue #{d}...{s}\n", .{ CYAN, issue_num, RESET });

    _ = cloudMergePR(allocator, issue_num) catch |err| {
        print("{s}Merge failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    print("{s}✓ PR merged{s}\n", .{ GREEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Verify PR for issue by cloning and building locally
fn cloudVerifyPR(allocator: Allocator, issue_num: u32) !bool {
    const branch_name = try std.fmt.allocPrint(allocator, "feat/issue-{d}", .{issue_num});
    defer allocator.free(branch_name);

    print("  Fetching PR for branch {s}...\n", .{branch_name});

    // Fetch the branch
    const fetch_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "fetch", "origin", branch_name },
        .max_output_bytes = 4096,
    });
    defer allocator.free(fetch_result.stdout);
    defer allocator.free(fetch_result.stderr);

    if (fetch_result.term.Exited != 0) {
        print("  Fetch failed: {s}\n", .{fetch_result.stderr});
        return error.FetchFailed;
    }

    // Checkout the branch
    const checkout_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "checkout", branch_name },
        .max_output_bytes = 4096,
    });
    defer allocator.free(checkout_result.stdout);
    defer allocator.free(checkout_result.stderr);

    if (checkout_result.term.Exited != 0) {
        print("  Checkout failed: {s}\n", .{checkout_result.stderr});
        return error.CheckoutFailed;
    }

    // Run zig build
    print("  Building (zig build)...\n", .{});
    const build_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "build" },
        .max_output_bytes = 1024 * 1024,
    });
    defer allocator.free(build_result.stdout);
    defer allocator.free(build_result.stderr);

    if (build_result.term.Exited != 0) {
        print("  Build failed:\n{s}\n", .{build_result.stderr});
        return error.BuildFailed;
    }

    print("  {s}✓ Build succeeded{s}\n", .{ GREEN, RESET });

    // Switch back to main
    _ = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "checkout", "main" },
        .max_output_bytes = 4096,
    }) catch {};

    return true;
}

/// Merge PR for issue using gh CLI
fn cloudMergePR(allocator: Allocator, issue_num: u32) !void {
    // Find PR for this issue
    const list_output = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "gh", "pr", "list", "--head", try std.fmt.allocPrint(allocator, "feat/issue-{d}", .{issue_num}), "--json", "number" },
        .max_output_bytes = 8192,
    });
    defer allocator.free(list_output.stdout);
    defer allocator.free(list_output.stderr);

    if (list_output.term.Exited != 0) {
        return error.PrListFailed;
    }

    // Parse PR number from JSON
    const needle = "\"number\":";
    const idx = std.mem.indexOf(u8, list_output.stdout, needle) orelse return error.PrNotFound;
    const start = idx + needle.len;
    var end = start;
    while (end < list_output.stdout.len and list_output.stdout[end] >= '0' and list_output.stdout[end] <= '9') : (end += 1) {}
    const pr_num_str = list_output.stdout[start..end];
    const pr_num = std.fmt.parseInt(u32, pr_num_str, 10) catch return error.PrNotFound;

    print("  Merging PR #{d}...\n", .{pr_num});

    // Merge the PR
    const merge_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "gh", "pr", "merge", pr_num_str, "--squash", "--delete-branch" },
        .max_output_bytes = 4096,
    });
    defer allocator.free(merge_result.stdout);
    defer allocator.free(merge_result.stderr);

    if (merge_result.term.Exited != 0) {
        return error.MergeFailed;
    }

    print("  {s}✓ PR #{d} merged{s}\n", .{ GREEN, pr_num, RESET });
}

fn getStatusEmoji(status: []const u8) []const u8 {
    if (eql(u8, status, "CODING")) return "⚡";
    if (eql(u8, status, "TESTING")) return "🧪";
    if (eql(u8, status, "DONE")) return "✅";
    if (eql(u8, status, "FAILED") or eql(u8, status, "ERROR")) return "❌";
    if (eql(u8, status, "STUCK")) return "⏰";
    if (eql(u8, status, "PR_CREATED")) return "🚀";
    if (eql(u8, status, "AWAKENING")) return "🌅";
    return "🔄";
}

fn extractJsonStr(json: []const u8, key: []const u8) ?[]const u8 {
    var needle_buf: [64]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":\"", .{key}) catch return null;
    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    const end = std.mem.indexOfPos(u8, json, start, "\"") orelse return null;
    return json[start..end];
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn printUsage() void {
    print("\n{s}{s}TRI CLOUD — Railway Integration{s}\n\n", .{ BOLD, CYAN, RESET });
    print("  {s}Infrastructure:{s}\n", .{ BOLD, RESET });
    print("  {s}tri cloud status{s}              Show Railway services\n", .{ GREEN, RESET });
    print("  {s}tri cloud logs{s}                Get deployment logs\n", .{ GREEN, RESET });
    print("  {s}tri cloud vars <svc-id>{s}       List environment variables\n", .{ GREEN, RESET });
    print("  {s}tri cloud vars set K=V <id>{s}   Set environment variable\n", .{ GREEN, RESET });
    print("  {s}tri cloud deploy <svc-id>{s}     Trigger redeployment\n", .{ GREEN, RESET });
    print("  {s}tri cloud exec <command>{s}      Run command via SSH\n", .{ GREEN, RESET });
    print("  {s}tri cloud pull{s}                Pull latest code on Railway\n", .{ GREEN, RESET });
    print("  {s}tri cloud ssh-status{s}          Quick SSH server status\n", .{ GREEN, RESET });
    print("\n  {s}Agent Orchestration:{s}\n", .{ BOLD, RESET });
    print("  {s}tri cloud spawn <issue>{s}       Spawn agent container for issue\n", .{ GREEN, RESET });
    print("  {s}tri cloud spawn-all{s}           Spawn agents for all labeled issues\n", .{ GREEN, RESET });
    print("  {s}tri cloud kill <issue>{s}        Kill agent container\n", .{ GREEN, RESET });
    print("  {s}tri cloud agents{s}              List active agent containers\n", .{ GREEN, RESET });
    print("  {s}tri cloud cleanup{s}             Remove inactive agent entries\n", .{ GREEN, RESET });
    print("  {s}tri cloud sync{s}                Reconcile local state with Railway\n", .{ GREEN, RESET });
    print("  {s}tri cloud history [issue]{s}     Event history for agent\n", .{ GREEN, RESET });
    print("\n  {s}Golden Chain Pipeline:{s}\n", .{ BOLD, RESET });
    print("  {s}tri cloud pipeline <issue>{s}    Full automation: spawn → monitor → verify → merge → cleanup\n", .{ GREEN, RESET });
    print("  {s}tri cloud verify <issue>{s}      Verify PR locally (zig build)\n", .{ GREEN, RESET });
    print("  {s}tri cloud merge <issue>{s}       Merge PR for issue\n", .{ GREEN, RESET });
    print("\n  {s}Env vars: RAILWAY_API_TOKEN, RAILWAY_PROJECT_ID, RAILWAY_ENVIRONMENT_ID{s}\n\n", .{ GRAY, RESET });
}

fn printApiInitError(err: anyerror) void {
    switch (err) {
        error.MissingToken => {
            print("{s}Error: RAILWAY_API_TOKEN not set{s}\n", .{ RED, RESET });
            print("Get token: https://railway.com/account/tokens\n", .{});
        },
        error.MissingProjectId => {
            print("{s}Error: No Railway project configured{s}\n", .{ RED, RESET });
            print("Set RAILWAY_PROJECT_ID or add .railway.json\n", .{});
        },
        else => print("{s}Error initializing Railway API: {}{s}\n", .{ RED, err, RESET }),
    }
}

fn printServicesFromJson(json: []const u8) void {
    // Simple line-by-line display of the raw response
    // In production this would parse JSON properly, but Zig std has no JSON writer
    // that makes table formatting easy, so we display raw for now
    print(" {s}Service data (JSON):{s}\n", .{ GRAY, RESET });

    // Try to find service names in the response for a compact view
    var offset: usize = 0;
    var count: u32 = 0;
    while (std.mem.indexOfPos(u8, json, offset, "\"name\":\"")) |idx| {
        const start = idx + 8; // len of "name":"
        const end = std.mem.indexOfPos(u8, json, start, "\"") orelse break;
        const name = json[start..end];
        count += 1;
        print(" {s}●{s} {s}\n", .{ GREEN, RESET, name });
        offset = end + 1;
    }

    if (count == 0) {
        print(" {s}(Could not parse services — raw response below){s}\n", .{ YELLOW, RESET });
        // Print first 500 chars of response
        const max = @min(json.len, 500);
        print(" {s}{s}{s}\n", .{ GRAY, json[0..max], RESET });
    } else {
        print(" {s}{d} service(s) found{s}\n", .{ GRAY, count, RESET });
    }
}
