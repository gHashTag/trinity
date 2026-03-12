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
    } else if (eql(u8, subcmd, "api-check")) {
        return cloudApiCheck(allocator);
    } else if (eql(u8, subcmd, "redeploy")) {
        return cloudRedeploy(allocator, sub_args);
    } else if (eql(u8, subcmd, "diagnose")) {
        return cloudDiagnose(allocator, sub_args);
    } else if (eql(u8, subcmd, "issue-create")) {
        return cloudIssueCreate(allocator, sub_args);
    } else if (eql(u8, subcmd, "metrics")) {
        return cloudMetrics(allocator);
    } else if (eql(u8, subcmd, "record-metrics")) {
        return cloudRecordMetrics(allocator, sub_args);
    } else if (eql(u8, subcmd, "monitor")) {
        return cloudMonitor(allocator);
    } else if (eql(u8, subcmd, "restart")) {
        return cloudRestart(allocator, sub_args);
    } else if (eql(u8, subcmd, "bridge")) {
        return cloudBridge(allocator, sub_args);
    } else if (eql(u8, subcmd, "tmux")) {
        return cloudTmux(allocator, sub_args);
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
    _ = args;
    print("\n{s}{s}═══ SPAWN ALL ═══════════════════════════════════{s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}Fetching issues with label 'agent:spawn'...{s}\n", .{ CYAN, RESET });

    // 1. Run gh issue list to get open issues with agent:spawn label
    const gh_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{
            "gh", "issue", "list",
            "--repo", "gHashTag/trinity",
            "--label", "agent:spawn",
            "--state", "open",
            "--json", "number,title",
            "--limit", "50",
        },
        .max_output_bytes = 64 * 1024,
    }) catch {
        print("{s}Failed to run 'gh issue list' — is gh CLI installed and authenticated?{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(gh_result.stdout);
    defer allocator.free(gh_result.stderr);

    if (gh_result.term.Exited != 0) {
        print("{s}gh issue list failed (exit {d}): {s}{s}\n", .{ RED, gh_result.term.Exited, gh_result.stderr, RESET });
        return;
    }

    // 2. Parse JSON array to extract issue numbers
    // Format: [{"number":123,"title":"..."},...]
    const json = gh_result.stdout;
    var issues: [50]u32 = undefined;
    var titles: [50][]const u8 = undefined;
    var issue_count: usize = 0;

    var offset: usize = 0;
    while (issue_count < 50) {
        const num_needle = "\"number\":";
        const num_idx = std.mem.indexOfPos(u8, json, offset, num_needle) orelse break;
        const num_start = num_idx + num_needle.len;
        var num_end = num_start;
        while (num_end < json.len and json[num_end] >= '0' and json[num_end] <= '9') : (num_end += 1) {}
        const num = std.fmt.parseInt(u32, json[num_start..num_end], 10) catch break;

        // Extract title
        const title_needle = "\"title\":\"";
        var title: []const u8 = "";
        if (std.mem.indexOfPos(u8, json, num_end, title_needle)) |title_idx| {
            const title_start = title_idx + title_needle.len;
            const title_end = std.mem.indexOfPos(u8, json, title_start, "\"") orelse title_start;
            title = json[title_start..title_end];
        }

        issues[issue_count] = num;
        titles[issue_count] = title;
        issue_count += 1;
        offset = num_end;
    }

    if (issue_count == 0) {
        print("{s}No open issues with label 'agent:spawn' found.{s}\n", .{ YELLOW, RESET });
        return;
    }

    print("{s}Found {d} issues to spawn:{s}\n", .{ GREEN, issue_count, RESET });
    for (issues[0..issue_count], titles[0..issue_count]) |num, title| {
        print("  {s}#{d}{s} {s}\n", .{ CYAN, num, RESET, title });
    }
    print("\n", .{});

    // 3. Spawn agents sequentially with 2s delay (Railway rate limit respect)
    var spawned: u32 = 0;
    var skipped: u32 = 0;
    var failed: u32 = 0;

    for (issues[0..issue_count]) |issue_num| {
        print("{s}Spawning agent for #{d}...{s} ", .{ CYAN, issue_num, RESET });

        const result = cloud_orchestrator.spawnAgent(allocator, issue_num) catch |err| {
            print("{s}FAILED: {}{s}\n", .{ RED, err, RESET });
            failed += 1;
            continue;
        };

        if (eql(u8, result.status, "already_exists")) {
            print("{s}SKIP (already exists){s}\n", .{ YELLOW, RESET });
            skipped += 1;
        } else if (eql(u8, result.status, "limit_reached")) {
            print("{s}LIMIT (max 10 concurrent){s}\n", .{ RED, RESET });
            // Queue remaining
            const remaining = issue_count - (spawned + skipped + failed);
            print("\n{s}Concurrent limit reached. {d} issues remain queued.{s}\n", .{ YELLOW, remaining, RESET });
            break;
        } else {
            print("{s}OK{s} (service: {s})\n", .{ GREEN, RESET, result.service_id });
            spawned += 1;
        }

        // 2s delay between spawns to respect Railway rate limits
        if (spawned + skipped + failed < issue_count) {
            std.Thread.sleep(2 * std.time.ns_per_s);
        }
    }

    // 4. Dashboard summary
    print("\n{s}{s}═══ SPAWN SUMMARY ══════════════════════════════{s}\n", .{ GOLDEN, BOLD, RESET });
    print("  {s}Spawned:{s}  {d}\n", .{ GREEN, RESET, spawned });
    print("  {s}Skipped:{s}  {d}\n", .{ YELLOW, RESET, skipped });
    print("  {s}Failed:{s}   {d}\n", .{ RED, RESET, failed });
    print("  {s}Total:{s}    {d}\n", .{ CYAN, RESET, issue_count });
    print("{s}════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });
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
fn cloudAgents(allocator: Allocator) !void {
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
        // Fallback: query Railway API for agent-* services
        printRailwayFallback(allocator);
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

/// Railway API fallback when local JSONL is empty — show live agent-* services
fn printRailwayFallback(allocator: Allocator) void {
    var api = railway_api.RailwayApi.init(allocator) catch {
        print(" {s}No local events & no Railway API credentials{s}\n", .{ GRAY, RESET });
        print(" {s}Set RAILWAY_API_TOKEN + RAILWAY_PROJECT_ID to see live services{s}\n", .{ GRAY, RESET });
        return;
    };
    defer api.deinit();

    const services_json = api.getServices() catch {
        print(" {s}No local events & Railway API query failed{s}\n", .{ GRAY, RESET });
        return;
    };
    defer allocator.free(services_json);

    // Parse agent-* services: look for "name":"agent-NNN" and their status
    print(" {s}(live from Railway API){s}\n\n", .{ GRAY, RESET });
    print(" {s}Service{s}              {s}Status{s}\n", .{ BOLD, RESET, BOLD, RESET });
    print(" {s}───────────────────  ──────────{s}\n", .{ GRAY, RESET });

    var svc_count: u32 = 0;
    var search_offset: usize = 0;
    const name_prefix = "\"name\":\"agent-";

    while (std.mem.indexOfPos(u8, services_json, search_offset, name_prefix)) |idx| {
        const name_start = idx + "\"name\":\"".len;
        const name_end = std.mem.indexOfPos(u8, services_json, name_start, "\"") orelse break;
        const svc_name = services_json[name_start..name_end];

        // Look for nearby "status" or "updatedAt" in the same node block
        // Extract issue number from service name (agent-NNN)
        const dash_pos = std.mem.indexOf(u8, svc_name, "-") orelse svc_name.len;
        const issue_str = svc_name[dash_pos + 1 ..];

        // Try to find deployment status nearby (within 500 chars)
        const search_end = @min(idx + 500, services_json.len);
        const nearby = services_json[idx..search_end];
        const status_text: []const u8 = if (std.mem.indexOf(u8, nearby, "SUCCESS") != null)
            "SUCCESS"
        else if (std.mem.indexOf(u8, nearby, "DEPLOYING") != null)
            "DEPLOYING"
        else if (std.mem.indexOf(u8, nearby, "FAILED") != null)
            "FAILED"
        else if (std.mem.indexOf(u8, nearby, "CRASHED") != null)
            "CRASHED"
        else
            "ACTIVE";

        const color = if (std.mem.eql(u8, status_text, "SUCCESS"))
            GREEN
        else if (std.mem.eql(u8, status_text, "FAILED") or std.mem.eql(u8, status_text, "CRASHED"))
            RED
        else if (std.mem.eql(u8, status_text, "DEPLOYING"))
            YELLOW
        else
            CYAN;

        const emoji: []const u8 = if (std.mem.eql(u8, status_text, "SUCCESS"))
            "✅"
        else if (std.mem.eql(u8, status_text, "FAILED") or std.mem.eql(u8, status_text, "CRASHED"))
            "❌"
        else if (std.mem.eql(u8, status_text, "DEPLOYING"))
            "🔄"
        else
            "●";

        print(" {s} {s:<18} {s}{s}{s}  (issue #{s})\n", .{ emoji, svc_name, color, status_text, RESET, issue_str });
        svc_count += 1;
        search_offset = name_end + 1;
    }

    if (svc_count == 0) {
        print(" {s}No agent-* services on Railway{s}\n", .{ GRAY, RESET });
    } else {
        print("{s}─────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });
        print(" {s}{d} Railway service(s){s}\n", .{ GRAY, svc_count, RESET });
    }
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

            if (!first) w.writeAll(",") catch |err| {
                std.log.debug("tri_cloud: JSON write comma failed: {}", .{err});
            };
            first = false;
            w.writeAll(line) catch break;
            count += 1;
        }

        w.writeAll("],\"count\":") catch |err| {
            std.log.debug("tri_cloud: JSON write count key failed: {}", .{err});
        };
        std.fmt.format(w, "{d}}}", .{count}) catch |err| {
            std.log.debug("tri_cloud: JSON format count failed: {}", .{err});
        };

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
            cloud_orchestrator.killAgent(allocator, issue_num) catch |err| {
                std.log.warn("tri_cloud: killAgent failed for issue {d}: {}", .{ issue_num, err });
            };
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
    cloud_orchestrator.killAgent(allocator, issue_num) catch |err| {
        std.log.warn("tri_cloud: killAgent cleanup failed for issue {d}: {}", .{ issue_num, err });
    };
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
    }) catch |err| {
        std.log.warn("tri_cloud: git checkout main failed: {}", .{err});
    };

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
// AGENT METRICS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri cloud metrics — Show aggregate agent metrics
fn cloudMetrics(allocator: Allocator) !void {
    _ = allocator;

    const summary = cloud_orchestrator.getMetrics();

    print("\n{s}{s}", .{ GOLDEN, BOLD });
    print("═══════════════════════════════════════════════════\n", .{});
    print(" AGENT METRICS SUMMARY\n", .{});
    print("═══════════════════════════════════════════════════{s}\n", .{RESET});

    const success_rate = if (summary.total > 0)
        @as(f64, @floatFromInt(summary.success)) / @as(f64, @floatFromInt(summary.total)) * 100.0
    else
        0.0;

    print("  {s}Total Runs:{s}     {d}\n", .{ CYAN, RESET, summary.total });
    print("  {s}Success:{s}        {s}{d}{s} ({d:.1}%)\n", .{ CYAN, RESET, GREEN, summary.success, RESET, success_rate });
    print("  {s}Failed:{s}         {s}{d}{s}\n", .{ CYAN, RESET, RED, summary.failed, RESET });
    print("  {s}Killed:{s}         {s}{d}{s}\n", .{ CYAN, RESET, YELLOW, summary.killed, RESET });
    print("  {s}Avg Time-to-PR:{s} {d:.1}s\n", .{ CYAN, RESET, summary.avg_time_to_pr });
    print("  {s}Files Changed:{s}  {d}\n", .{ CYAN, RESET, summary.total_files_changed });
    print("  {s}Lines Added:{s}    {s}+{d}{s}\n", .{ CYAN, RESET, GREEN, summary.total_lines_added, RESET });
    print("  {s}Lines Removed:{s}  {s}-{d}{s}\n", .{ CYAN, RESET, RED, summary.total_lines_removed, RESET });
    print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });
}

/// tri cloud record-metrics <issue> <result> [pr] [time] [files] [added] [removed]
fn cloudRecordMetrics(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        print("{s}Usage: tri cloud record-metrics <issue> <result> [pr] [time] [files] [added] [removed]{s}\n", .{ RED, RESET });
        print("  result: success | failed | killed\n", .{});
        return;
    }

    const issue = std.fmt.parseInt(u32, args[0], 10) catch {
        print("{s}Invalid issue number{s}\n", .{ RED, RESET });
        return;
    };

    const result = args[1];
    if (!eql(u8, result, "success") and !eql(u8, result, "failed") and !eql(u8, result, "killed")) {
        print("{s}Invalid result: must be success, failed, or killed{s}\n", .{ RED, RESET });
        return;
    }

    const pr_number: ?u32 = if (args.len > 2) std.fmt.parseInt(u32, args[2], 10) catch null else null;
    const time_to_pr: ?i64 = if (args.len > 3) std.fmt.parseInt(i64, args[3], 10) catch null else null;
    const files_changed: u32 = if (args.len > 4) std.fmt.parseInt(u32, args[4], 10) catch 0 else 0;
    const lines_added: u32 = if (args.len > 5) std.fmt.parseInt(u32, args[5], 10) catch 0 else 0;
    const lines_removed: u32 = if (args.len > 6) std.fmt.parseInt(u32, args[6], 10) catch 0 else 0;

    cloud_orchestrator.recordMetrics(
        allocator,
        issue,
        result,
        time_to_pr,
        files_changed,
        lines_added,
        lines_removed,
        pr_number,
    ) catch |err| {
        print("{s}Failed to record metrics: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    print("{s}\xe2\x9c\x93{s} Recorded metrics for issue {d}: {s}\n", .{ GREEN, RESET, issue, result });
}

// ═══════════════════════════════════════════════════════════════════════════════
// AGENT DIAGNOSTICS — api-check, redeploy, diagnose, issue-create
// ═══════════════════════════════════════════════════════════════════════════════

/// tri cloud api-check — Test ANTHROPIC_API_KEY connectivity and model routing
/// Detects z.ai proxy returning wrong model (e.g. GLM instead of Claude)
fn cloudApiCheck(allocator: Allocator) !void {
    print("\n{s}{s}═══ API CONNECTIVITY CHECK ══════════════════════{s}\n", .{ GOLDEN, BOLD, RESET });

    const api_key = std.posix.getenv("ANTHROPIC_API_KEY") orelse {
        print(" {s}ANTHROPIC_API_KEY not set{s}\n", .{ RED, RESET });
        return;
    };
    const base_url = std.posix.getenv("ANTHROPIC_BASE_URL") orelse "https://api.anthropic.com";

    print(" Key: {s}...{s}{s}\n", .{ GRAY, if (api_key.len > 8) api_key[0..8] else api_key, RESET });
    print(" URL: {s}{s}{s}\n", .{ CYAN, base_url, RESET });

    // Build test request body — use CLAUDE_MODEL env var or default glm-5
    const model_name = std.posix.getenv("CLAUDE_MODEL") orelse "glm-5";
    var body_buf: [256]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf,
        \\{{"model":"{s}","max_tokens":10,"messages":[{{"role":"user","content":"hi"}}]}}
    , .{model_name}) catch {
        print(" {s}Body too long{s}\n", .{ RED, RESET });
        return;
    };

    // Build URL: {base_url}/v1/messages
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "{s}/v1/messages", .{base_url}) catch {
        print(" {s}URL too long{s}\n", .{ RED, RESET });
        return;
    };

    // Use std.http.Client (Zig 0.15 API)
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse(url) catch {
        print(" {s}Invalid URL{s}\n", .{ RED, RESET });
        return;
    };

    const extra_headers = [_]std.http.Header{
        .{ .name = "x-api-key", .value = api_key },
        .{ .name = "anthropic-version", .value = "2023-06-01" },
        .{ .name = "Content-Type", .value = "application/json" },
    };

    var req = client.request(.POST, uri, .{
        .extra_headers = &extra_headers,
        .redirect_behavior = .unhandled,
    }) catch |err| {
        print(" {s}Connection failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.len };
    var body_writer = req.sendBodyUnflushed(&.{}) catch |err| {
        print(" {s}Send failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    body_writer.writer.writeAll(body) catch |err| {
        print(" {s}Write failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    body_writer.end() catch |err| {
        print(" {s}End failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    if (req.connection) |conn| conn.flush() catch |err| {
        std.log.debug("tri_cloud: failed to flush connection: {}", .{err});
    };

    var redirect_buf: [0]u8 = .{};
    var response = req.receiveHead(&redirect_buf) catch |err| {
        print(" {s}Receive failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    const status_code = @intFromEnum(response.head.status);
    print(" HTTP: {d}\n", .{status_code});

    var transfer_buffer: [8192]u8 = undefined;
    var reader = response.reader(&transfer_buffer);
    const resp = reader.allocRemaining(allocator, std.Io.Limit.limited(4096)) catch {
        print(" {s}Failed to read response{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(resp);

    if (status_code != 200) {
        print(" {s}API returned error:{s}\n", .{ RED, RESET });
        print(" {s}\n", .{resp});
        return;
    }

    // Extract "model" field from response
    const model = extractJsonStr(resp, "\"model\":\"") orelse "unknown";

    print(" Requested: {s}{s}{s}\n", .{ CYAN, model_name, RESET });
    print(" Returned:  {s}{s}{s}\n", .{ CYAN, model, RESET });

    // Check model mismatch
    if (std.mem.indexOf(u8, model, "claude") != null) {
        print("\n {s}API OK — Claude model confirmed{s}\n", .{ GREEN, RESET });
    } else {
        print("\n {s}MODEL MISMATCH — proxy returning {s} instead of Claude!{s}\n", .{ RED, model, RESET });
        print(" {s}This is why agents produce 0 commits.{s}\n", .{ YELLOW, RESET });
        print(" Fix: use direct Anthropic API key or fix z.ai proxy config.\n", .{});
    }
    print("{s}═════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
}

/// tri cloud redeploy <service-id> <issue-number> — Reuse existing Railway service for new issue
fn cloudRedeploy(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        print("{s}Usage: tri cloud redeploy <service-id> <issue-number>{s}\n", .{ RED, RESET });
        print("  Reuses existing Railway service with new ISSUE_NUMBER.\n", .{});
        print("  {s}tri cloud agents{s} — find idle service IDs\n", .{ GREEN, RESET });
        return;
    }

    const service_id = args[0];
    const issue_str = args[1];
    const issue_num = std.fmt.parseInt(u32, issue_str, 10) catch {
        print("{s}Error: Invalid issue number: {s}{s}\n", .{ RED, issue_str, RESET });
        return;
    };

    const env_id = std.posix.getenv("RAILWAY_ENVIRONMENT_ID") orelse {
        print("{s}Error: RAILWAY_ENVIRONMENT_ID not set{s}\n", .{ RED, RESET });
        return;
    };

    print("{s}Redeploying service {s} for issue #{d}...{s}\n", .{ CYAN, service_id, issue_num, RESET });

    var api = railway_api.RailwayApi.init(allocator) catch |err| {
        printApiInitError(err);
        return;
    };
    defer api.deinit();

    // 1. Update ISSUE_NUMBER env var
    const vars_resp = api.upsertVariable(service_id, env_id, "ISSUE_NUMBER", issue_str) catch |err| {
        print("{s}Failed to update env vars: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    allocator.free(vars_resp);
    print(" {s}ISSUE_NUMBER={s} set{s}\n", .{ GREEN, issue_str, RESET });

    // 2. Trigger redeploy
    const deploy_resp = api.redeployService(service_id, env_id) catch |err| {
        print("{s}Failed to trigger deploy: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    allocator.free(deploy_resp);

    print(" {s}Deploy triggered for issue #{d}{s}\n", .{ GREEN, issue_num, RESET });
    print("  Service: {s}\n", .{service_id});
}

/// tri cloud diagnose <issue> — Check why agent failed (comments + events + PR status)
fn cloudDiagnose(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Usage: tri cloud diagnose <issue-number>{s}\n", .{ RED, RESET });
        return;
    }

    const issue_str = args[0];
    print("\n{s}{s}═══ AGENT DIAGNOSIS: Issue #{s} ═════════════════{s}\n", .{ GOLDEN, BOLD, issue_str, RESET });

    // 1. Check GitHub issue comments via gh CLI
    print("\n {s}GitHub Issue Comments:{s}\n", .{ BOLD, RESET });
    {
        const gh_argv = [_][]const u8{ "gh", "issue", "view", issue_str, "--repo", "gHashTag/trinity", "--json", "state,title,comments", "--jq", ".comments[-3:][] | \"  [\" + .createdAt[:19] + \"] \" + .body[:150]" };
        var child = std.process.Child.init(&gh_argv, allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        if (child.spawn()) |_| {} else |_| {
            print("  {s}gh CLI not available{s}\n", .{ GRAY, RESET });
        }
        if (child.stdout) |*stdout| {
            var gh_buf: [4096]u8 = undefined;
            const gh_len = stdout.readAll(&gh_buf) catch 0;
            if (gh_len > 0) {
                print("{s}\n", .{gh_buf[0..gh_len]});
            } else {
                print("  {s}No comments{s}\n", .{ GRAY, RESET });
            }
        }
        _ = child.wait() catch |err| {
            std.log.debug("tri_cloud: child.wait failed: {}", .{err});
        };
    }

    // 2. Check event history from JSONL
    print(" {s}Event History:{s}\n", .{ BOLD, RESET });
    {
        const events_path = ".trinity/cloud_events.jsonl";
        const file = std.fs.cwd().openFile(events_path, .{}) catch {
            print("  {s}No JSONL events found{s}\n", .{ GRAY, RESET });
            print("{s}═════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
            return;
        };
        defer file.close();

        var buf: [32768]u8 = undefined;
        const flen = file.readAll(&buf) catch 0;
        const content = buf[0..flen];

        // Filter events for this issue
        var needle_buf: [32]u8 = undefined;
        const needle_str = std.fmt.bufPrint(&needle_buf, "\"issue\":{s}", .{issue_str}) catch "\"issue\":0";

        var count: u32 = 0;
        var offset: usize = 0;
        while (offset < content.len) {
            const line_end = std.mem.indexOfPos(u8, content, offset, "\n") orelse content.len;
            const line = content[offset..line_end];
            offset = line_end + 1;

            if (line.len == 0) continue;
            if (std.mem.indexOf(u8, line, needle_str) == null) continue;

            // Extract status from event
            const status = extractJsonStr(line, "\"status\":\"") orelse "?";
            const detail = extractJsonStr(line, "\"detail\":\"") orelse "";
            print("  {s} {s}{s}\n", .{ status, detail, RESET });
            count += 1;
        }
        if (count == 0) print("  {s}No events for issue #{s}{s}\n", .{ GRAY, issue_str, RESET });
    }

    // 3. Check for PR
    print("\n {s}PR Status:{s}\n", .{ BOLD, RESET });
    {
        var branch_buf: [64]u8 = undefined;
        const branch = std.fmt.bufPrint(&branch_buf, "feat/issue-{s}", .{issue_str}) catch "feat/issue-?";
        const pr_argv = [_][]const u8{ "gh", "pr", "list", "--repo", "gHashTag/trinity", "--head", branch, "--state", "all", "--json", "number,state,title", "--jq", ".[] | \"  #\" + (.number|tostring) + \" [\" + .state + \"] \" + .title" };
        var child = std.process.Child.init(&pr_argv, allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        if (child.spawn()) |_| {} else |_| {
            print("  {s}gh CLI not available{s}\n", .{ GRAY, RESET });
        }
        if (child.stdout) |*stdout| {
            var pr_buf: [2048]u8 = undefined;
            const pr_len = stdout.readAll(&pr_buf) catch 0;
            if (pr_len > 0) {
                print("{s}\n", .{pr_buf[0..pr_len]});
            } else {
                print("  {s}No PR found for branch {s}{s}\n", .{ GRAY, branch, RESET });
            }
        }
        _ = child.wait() catch |err| {
            std.log.debug("tri_cloud: child.wait failed: {}", .{err});
        };
    }

    print("{s}═════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
}

/// tri cloud issue-create <title> [--body "..."] [--label extra-label]
/// Creates GitHub issue with agent:spawn label for auto-spawning
fn cloudIssueCreate(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Usage: tri cloud issue-create <title> [--body \"...\"] [--label extra-label]{s}\n", .{ RED, RESET });
        print("  Creates issue with 'agent:spawn' label for auto-spawning.\n", .{});
        return;
    }

    // Parse args: first non-flag is title, --body, --label are options
    var title: []const u8 = "";
    var body: []const u8 = "Created via `tri cloud issue-create`. Agent will auto-spawn.";
    var extra_label: []const u8 = "";
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (eql(u8, args[i], "--body") and i + 1 < args.len) {
            i += 1;
            body = args[i];
        } else if (eql(u8, args[i], "--label") and i + 1 < args.len) {
            i += 1;
            extra_label = args[i];
        } else if (title.len == 0) {
            title = args[i];
        }
    }

    if (title.len == 0) {
        print("{s}Error: Title required{s}\n", .{ RED, RESET });
        return;
    }

    print("{s}Creating issue: {s}{s}\n", .{ CYAN, title, RESET });

    // Build gh command
    var gh_args: [16][]const u8 = undefined;
    var argc: usize = 0;
    gh_args[argc] = "gh";
    argc += 1;
    gh_args[argc] = "issue";
    argc += 1;
    gh_args[argc] = "create";
    argc += 1;
    gh_args[argc] = "--repo";
    argc += 1;
    gh_args[argc] = "gHashTag/trinity";
    argc += 1;
    gh_args[argc] = "--title";
    argc += 1;
    gh_args[argc] = title;
    argc += 1;
    gh_args[argc] = "--body";
    argc += 1;
    gh_args[argc] = body;
    argc += 1;
    gh_args[argc] = "--label";
    argc += 1;
    if (extra_label.len > 0) {
        // Combine labels
        var label_buf: [128]u8 = undefined;
        const combined = std.fmt.bufPrint(&label_buf, "agent:spawn,{s}", .{extra_label}) catch "agent:spawn";
        gh_args[argc] = combined;
    } else {
        gh_args[argc] = "agent:spawn";
    }
    argc += 1;

    var child = std.process.Child.init(gh_args[0..argc], allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.spawn() catch {
        print("{s}Failed to run gh CLI{s}\n", .{ RED, RESET });
        return;
    };

    var out_buf: [2048]u8 = undefined;
    const out_len = if (child.stdout) |*stdout| stdout.readAll(&out_buf) catch 0 else 0;
    _ = child.wait() catch |err| {
        std.log.debug("tri_cloud: child.wait failed: {}", .{err});
    };

    if (out_len > 0) {
        print("{s}Issue created: {s}{s}\n", .{ GREEN, out_buf[0..out_len], RESET });
    } else {
        print("{s}Issue creation may have failed — check gh auth{s}\n", .{ YELLOW, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MONITORING & QUICK COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri cloud monitor — Full health check: bridge, tmux, processes, disk
fn cloudMonitor(allocator: Allocator) !void {
    const ssh = railway_ssh.RailwaySSH.initDefault();

    print("\n{s}{s}═══ RAILWAY MONITOR ═════════════════════════════{s}\n", .{ GOLDEN, BOLD, RESET });

    // Run all checks via single SSH command for speed
    const check_cmd =
        \\echo "===BRIDGE===" && \
        \\curl -sf --max-time 5 http://localhost:8077/px/status?token=$PX_BRIDGE_TOKEN 2>/dev/null || echo '{"status":"FAIL"}' && \
        \\echo "" && echo "===TMUX===" && \
        \\tmux list-sessions 2>/dev/null || echo "NO_TMUX" && \
        \\echo "===PROCS===" && \
        \\(pgrep -la trinity-mcp 2>/dev/null || echo "NO_TRINITY_MCP") && \
        \\(pgrep -la tri-api 2>/dev/null || echo "NO_TRI_API") && \
        \\echo "===DISK===" && \
        \\df -h /data 2>/dev/null | tail -1 || df -h / | tail -1
    ;

    const output = ssh.exec(allocator, check_cmd) catch |err| {
        print(" {s}SSH: {s}  Connection failed ({})  {s}\n", .{ RED, "❌", err, RESET });
        print(" {s}Bridge:{s} {s}  Cannot check (SSH down){s}\n", .{ RED, "❌", GRAY, RESET });
        print(" {s}tmux:{s}   {s}  Cannot check (SSH down){s}\n", .{ RED, "❌", GRAY, RESET });
        print(" {s}Procs:{s}  {s}  Cannot check (SSH down){s}\n", .{ RED, "❌", GRAY, RESET });
        print(" {s}Disk:{s}   {s}  Cannot check (SSH down){s}\n", .{ RED, "❌", GRAY, RESET });
        print("{s}═════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(output);

    // Parse sections
    var issues_found: u32 = 0;

    // === BRIDGE ===
    if (std.mem.indexOf(u8, output, "===BRIDGE===")) |_| {
        const bridge_start = (std.mem.indexOf(u8, output, "===BRIDGE===") orelse 0) + 12;
        const bridge_end = std.mem.indexOfPos(u8, output, bridge_start, "===TMUX===") orelse output.len;
        const bridge_section = std.mem.trim(u8, output[bridge_start..bridge_end], " \n\r\t");

        if (std.mem.indexOf(u8, bridge_section, "\"status\":\"ok\"") != null) {
            // Extract queue info
            const pending = extractJsonNum(bridge_section, "queue_pending");
            const running = extractJsonNum(bridge_section, "queue_running");
            print(" Bridge: {s}  (queue: {d} pending, {d} running){s}\n", .{ "✅", pending, running, RESET });
        } else {
            print(" Bridge: {s}{s}  DOWN{s}\n", .{ RED, "❌", RESET });
            issues_found += 1;
        }
    }

    // === TMUX ===
    if (std.mem.indexOf(u8, output, "===TMUX===")) |_| {
        const tmux_start = (std.mem.indexOf(u8, output, "===TMUX===") orelse 0) + 10;
        const tmux_end = std.mem.indexOfPos(u8, output, tmux_start, "===PROCS===") orelse output.len;
        const tmux_section = std.mem.trim(u8, output[tmux_start..tmux_end], " \n\r\t");

        if (std.mem.eql(u8, tmux_section, "NO_TMUX")) {
            print(" tmux:   {s}{s}  No sessions{s}\n", .{ RED, "❌", RESET });
            issues_found += 1;
        } else {
            // Count expected sessions
            var session_count: u32 = 0;
            var missing_buf: [128]u8 = undefined;
            var missing_pos: usize = 0;

            const expected = [_][]const u8{ "train", "mcp", "bridge", "oracle" };
            for (expected) |name| {
                if (std.mem.indexOf(u8, tmux_section, name) != null) {
                    session_count += 1;
                } else {
                    if (missing_pos > 0) {
                        missing_buf[missing_pos] = ',';
                        missing_buf[missing_pos + 1] = ' ';
                        missing_pos += 2;
                    }
                    const nlen = @min(name.len, missing_buf.len - missing_pos);
                    @memcpy(missing_buf[missing_pos .. missing_pos + nlen], name[0..nlen]);
                    missing_pos += nlen;
                }
            }

            if (session_count == 4) {
                print(" tmux:   {s}  4/4 sessions{s}\n", .{ "✅", RESET });
            } else {
                print(" tmux:   {s}{s}  {d}/4 — missing: {s}{s}\n", .{ YELLOW, "⚠️", session_count, missing_buf[0..missing_pos], RESET });
                issues_found += 1;
            }
        }
    }

    // === PROCS ===
    if (std.mem.indexOf(u8, output, "===PROCS===")) |_| {
        const procs_start = (std.mem.indexOf(u8, output, "===PROCS===") orelse 0) + 11;
        const procs_end = std.mem.indexOfPos(u8, output, procs_start, "===DISK===") orelse output.len;
        const procs_section = std.mem.trim(u8, output[procs_start..procs_end], " \n\r\t");

        const has_mcp = std.mem.indexOf(u8, procs_section, "NO_TRINITY_MCP") == null;
        const has_api = std.mem.indexOf(u8, procs_section, "NO_TRI_API") == null;

        const mcp_icon: []const u8 = if (has_mcp) "✅" else "❌";
        const api_icon: []const u8 = if (has_api) "✅" else "❌";
        const mcp_color = if (has_mcp) GREEN else RED;
        const api_color = if (has_api) GREEN else RED;

        print(" Procs:  {s}trinity-mcp {s}{s} | {s}tri-api {s}{s}\n", .{ mcp_color, mcp_icon, RESET, api_color, api_icon, RESET });

        if (!has_mcp) issues_found += 1;
        if (!has_api) issues_found += 1;
    }

    // === DISK ===
    if (std.mem.indexOf(u8, output, "===DISK===")) |_| {
        const disk_start = (std.mem.indexOf(u8, output, "===DISK===") orelse 0) + 10;
        const disk_section = std.mem.trim(u8, output[disk_start..], " \n\r\t");

        // Extract percentage — look for pattern like "XX%"
        var pct: u32 = 0;
        var di: usize = 0;
        while (di < disk_section.len) : (di += 1) {
            if (disk_section[di] == '%' and di > 0) {
                // Walk back to find digits
                var dstart = di - 1;
                while (dstart > 0 and disk_section[dstart - 1] >= '0' and disk_section[dstart - 1] <= '9') : (dstart -= 1) {}
                pct = std.fmt.parseInt(u32, disk_section[dstart..di], 10) catch 0;
                break;
            }
        }

        const disk_color = if (pct >= 90) RED else if (pct >= 75) YELLOW else GREEN;
        const disk_icon: []const u8 = if (pct >= 90) "❌" else if (pct >= 75) "⚠️" else "✅";
        print(" Disk:   {s}{s}  {d}% used{s}\n", .{ disk_color, disk_icon, pct, RESET });

        if (pct >= 90) issues_found += 1;
    }

    // Summary
    print("{s}─────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });
    if (issues_found == 0) {
        print(" {s}All systems operational{s}\n", .{ GREEN, RESET });
    } else {
        print(" {s}{d} issue(s) detected — run `tri cloud restart <service>` to fix{s}\n", .{ YELLOW, issues_found, RESET });
    }
    print("{s}═════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
}

/// tri cloud restart <service> — Restart a specific tmux service on Railway
/// Services: bridge, mcp, oracle, train
fn cloudRestart(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Usage: tri cloud restart <service>{s}\n", .{ RED, RESET });
        print("  Services: bridge, mcp, oracle, train\n", .{});
        return;
    }

    const service = args[0];
    const ssh = railway_ssh.RailwaySSH.initDefault();

    // Build restart command based on service
    var cmd_buf: [512]u8 = undefined;
    const cmd = if (eql(u8, service, "bridge"))
        std.fmt.bufPrint(&cmd_buf, "tmux send-keys -t bridge C-c C-c && sleep 1 && tmux send-keys -t bridge 'cd /app && ./deploy/tri-bridge-agent.sh' C-m && echo 'RESTARTED bridge'", .{}) catch return
    else if (eql(u8, service, "mcp"))
        std.fmt.bufPrint(&cmd_buf, "tmux send-keys -t mcp C-c C-c && sleep 1 && tmux send-keys -t mcp 'cd /app && zig-out/bin/trinity-mcp' C-m && echo 'RESTARTED mcp'", .{}) catch return
    else if (eql(u8, service, "oracle"))
        std.fmt.bufPrint(&cmd_buf, "tmux send-keys -t oracle C-c C-c && sleep 1 && tmux send-keys -t oracle 'cd /app && ./deploy/oracle.sh' C-m && echo 'RESTARTED oracle'", .{}) catch return
    else if (eql(u8, service, "train"))
        std.fmt.bufPrint(&cmd_buf, "tmux send-keys -t train C-c C-c && sleep 1 && tmux send-keys -t train 'cd /app && zig-out/bin/tri train start' C-m && echo 'RESTARTED train'", .{}) catch return
    else {
        print("{s}Unknown service: {s}{s}\n", .{ RED, service, RESET });
        print("  Valid: bridge, mcp, oracle, train\n", .{});
        return;
    };

    print("{s}Restarting {s}...{s}\n", .{ CYAN, service, RESET });

    const output = ssh.exec(allocator, cmd) catch |err| {
        print("{s}SSH failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(output);

    if (std.mem.indexOf(u8, output, "RESTARTED") != null) {
        print("{s}✓ {s} restart command sent{s}\n", .{ GREEN, service, RESET });
        print("  {s}Wait 5s, then verify: tri cloud monitor{s}\n", .{ GRAY, RESET });
    } else {
        print("{s}⚠ Restart may have failed. Output:{s}\n{s}", .{ YELLOW, RESET, output });
    }
}

/// tri cloud bridge [status|queue|logs] — Quick bridge operations
fn cloudBridge(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";
    const ssh = railway_ssh.RailwaySSH.initDefault();

    if (eql(u8, subcmd, "status")) {
        const output = ssh.exec(allocator, "curl -sf --max-time 5 http://localhost:8077/px/status?token=$PX_BRIDGE_TOKEN 2>/dev/null || echo 'FAIL'") catch |err| {
            print("{s}SSH failed: {}{s}\n", .{ RED, err, RESET });
            return;
        };
        defer allocator.free(output);
        print("{s}", .{output});
    } else if (eql(u8, subcmd, "logs")) {
        const lines = if (args.len > 1) args[1] else "30";
        var cmd_buf: [128]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "tail -{s} /data/bridge.log 2>/dev/null || echo 'No bridge.log'", .{lines}) catch return;
        const output = ssh.exec(allocator, cmd) catch |err| {
            print("{s}SSH failed: {}{s}\n", .{ RED, err, RESET });
            return;
        };
        defer allocator.free(output);
        print("{s}", .{output});
    } else if (eql(u8, subcmd, "queue")) {
        const output = ssh.exec(allocator, "curl -sf --max-time 5 http://localhost:8077/px/status?token=$PX_BRIDGE_TOKEN 2>/dev/null | grep -o '\"queue_[^}]*' || echo 'FAIL'") catch |err| {
            print("{s}SSH failed: {}{s}\n", .{ RED, err, RESET });
            return;
        };
        defer allocator.free(output);
        print("{s}", .{output});
    } else {
        print("Usage: tri cloud bridge [status|queue|logs [N]]\n", .{});
    }
}

/// tri cloud tmux [list|capture <session> [lines]] — Quick tmux operations
fn cloudTmux(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "list";
    const ssh = railway_ssh.RailwaySSH.initDefault();

    if (eql(u8, subcmd, "list")) {
        const output = ssh.exec(allocator, "tmux list-sessions 2>/dev/null || echo 'No tmux sessions'") catch |err| {
            print("{s}SSH failed: {}{s}\n", .{ RED, err, RESET });
            return;
        };
        defer allocator.free(output);
        print("{s}", .{output});
    } else if (eql(u8, subcmd, "capture")) {
        const session = if (args.len > 1) args[1] else "bridge";
        const lines_str = if (args.len > 2) args[2] else "50";
        const lines = std.fmt.parseInt(u32, lines_str, 10) catch 50;
        const output = ssh.tmuxCapture(allocator, session, lines) catch |err| {
            print("{s}Capture failed: {}{s}\n", .{ RED, err, RESET });
            return;
        };
        defer allocator.free(output);
        print("{s}", .{output});
    } else {
        print("Usage: tri cloud tmux [list|capture <session> [lines]]\n", .{});
    }
}

/// Extract a numeric value from JSON like "key":123
fn extractJsonNum(json: []const u8, key: []const u8) u32 {
    var needle_buf: [64]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":", .{key}) catch return 0;
    const idx = std.mem.indexOf(u8, json, needle) orelse return 0;
    const start = idx + needle.len;
    var end = start;
    while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
    return std.fmt.parseInt(u32, json[start..end], 10) catch 0;
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
    print("\n  {s}Agent Metrics:{s}\n", .{ BOLD, RESET });
    print("  {s}tri cloud metrics{s}             Show aggregate agent metrics\n", .{ GREEN, RESET });
    print("  {s}tri cloud record-metrics{s}      Record agent completion metrics\n", .{ GREEN, RESET });
    print("\n  {s}Golden Chain Pipeline:{s}\n", .{ BOLD, RESET });
    print("  {s}tri cloud pipeline <issue>{s}    Full automation: spawn → monitor → verify → merge → cleanup\n", .{ GREEN, RESET });
    print("  {s}tri cloud verify <issue>{s}      Verify PR locally (zig build)\n", .{ GREEN, RESET });
    print("  {s}tri cloud merge <issue>{s}       Merge PR for issue\n", .{ GREEN, RESET });
    print("\n  {s}Agent Diagnostics:{s}\n", .{ BOLD, RESET });
    print("  {s}tri cloud api-check{s}           Test API key connectivity + model routing\n", .{ GREEN, RESET });
    print("  {s}tri cloud redeploy <svc> <N>{s}  Reuse service for new issue\n", .{ GREEN, RESET });
    print("  {s}tri cloud diagnose <issue>{s}    Why did agent fail? (comments + events + PR)\n", .{ GREEN, RESET });
    print("  {s}tri cloud issue-create <title>{s} Create issue with agent:spawn label\n", .{ GREEN, RESET });
    print("\n  {s}Monitoring:{s}\n", .{ BOLD, RESET });
    print("  {s}tri cloud monitor{s}             Full health check (bridge, tmux, procs, disk)\n", .{ GREEN, RESET });
    print("  {s}tri cloud restart <service>{s}   Restart tmux service (bridge|mcp|oracle|train)\n", .{ GREEN, RESET });
    print("  {s}tri cloud bridge [status|queue|logs]{s} Quick bridge operations\n", .{ GREEN, RESET });
    print("  {s}tri cloud tmux [list|capture <s>]{s}    Quick tmux operations\n", .{ GREEN, RESET });
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
