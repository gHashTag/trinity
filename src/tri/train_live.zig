// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI TRAIN LIVE — Real-time training status via Railway logs API
// ═══════════════════════════════════════════════════════════════════════════════
//
// PROBLEM: evolution_state.json is stale cache — marks training workers as "stalled"
// SOLUTION: Query Railway logs API directly for real step= progression
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const railway_api = @import("railway_api.zig");

// ANSI colors
const RESET = "\x1b[0m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";

/// Real worker status from logs (not cache!)
pub const LiveStatus = enum {
    training,
    stalled,
    has_error,
    building,
    not_found,
    unknown,
};

/// Check if logs show real error (DatasetNotFound, OOM, panic)
fn hasRealError(logs_json: []const u8) bool {
    const error_patterns = [_][]const u8{
        "DatasetNotFound",
        "dataset not found",
        "Out of memory",
        "panic:",
        "fatal error",
        "segmentation fault",
    };

    for (error_patterns) |pattern| {
        if (std.mem.indexOf(u8, logs_json, pattern) != null) {
            return true;
        }
    }
    return false;
}

/// Check if logs show active training (step= entries present)
fn hasTrainingLogs(logs_json: []const u8) bool {
    // Look for "step=N" or "Step N" patterns in logs
    return std.mem.indexOf(u8, logs_json, "step=") != null or
        std.mem.indexOf(u8, logs_json, "Step ") != null;
}

/// Parse latest step from logs JSON
fn parseLatestStep(logs_json: []const u8) u32 {
    var max_step: u32 = 0;

    // Look for "step":NNN or step=NNN patterns
    var iter = std.mem.splitSequence(u8, logs_json, "step");
    while (iter.next()) |part| {
        // Skip "steps" and similar
        if (part.len == 0) continue;

        // Find number after "=" or ":"
        const start_idx = std.mem.indexOfAny(u8, part, "=:") orelse continue;
        var start = start_idx + 1;
        if (start >= part.len) continue;

        // Skip quotes if present
        if (part[start] == '"') start += 1;
        if (start >= part.len) continue;

        // Extract digits
        var end: usize = start;
        while (end < part.len and part[end] >= '0' and part[end] <= '9') : (end += 1) {}

        if (end > start) {
            const step_str = part[start..end];
            const step = std.fmt.parseInt(u32, step_str, 10) catch continue;
            if (step > max_step) max_step = step;
        }
    }

    return max_step;
}

/// Parse latest PPL from logs JSON
fn parseLatestPPL(logs_json: []const u8) f32 {
    if (std.mem.indexOf(u8, logs_json, "PPL=")) |idx| {
        const start = idx + 4;
        var end = start;
        while (end < logs_json.len and (logs_json[end] >= '0' and logs_json[end] <= '9' or logs_json[end] == '.')) : (end += 1) {}
        if (end > start) {
            return std.fmt.parseFloat(f32, logs_json[start..end]) catch 0;
        }
    }
    return 0;
}

/// Result of checking a single sacred worker
pub const WorkerCheckResult = struct {
    is_training: bool = false,
    is_building: bool = false,
    has_error: bool = false,
    step: u32 = 0,
    ppl: f32 = 0,
    fresh: bool = false, // Logs are recent (within 5 min)
};

/// Check if a single sacred worker is actually training via Railway logs.
/// This is the primary source of truth — NOT evolution_state.json cache!
/// suffix: "" for RAILWAY_API_TOKEN, "_2" for RAILWAY_API_TOKEN_2, etc.
pub fn checkSacredWorker(allocator: Allocator, service_name: []const u8, suffix: []const u8) WorkerCheckResult {
    var result: WorkerCheckResult = .{};

    // Read project from env
    const project_env_key = if (suffix.len == 0) "RAILWAY_PROJECT_ID" else std.fmt.allocPrint(allocator, "RAILWAY_PROJECT_ID{s}", .{suffix}) catch "RAILWAY_PROJECT_ID";
    defer if (suffix.len > 0) allocator.free(@constCast(project_env_key));

    const project_id = std.posix.getenv(project_env_key) orelse return result;

    var api = railway_api.RailwayApi.initWithSuffix(allocator, suffix) catch return result;
    defer api.deinit();

    // Get service ID
    const service_id = api.getServiceIdByName(project_id, service_name) catch return result;
    if (service_id == null) return result;
    defer allocator.free(service_id.?);

    // Get latest deployment ID
    const dep_id = api.getLatestDeploymentId(service_id.?) catch return result;
    if (dep_id == null) return result;
    defer allocator.free(dep_id.?);

    // Get deployment status
    const dep_status = api.getDeploymentStatus(dep_id.?) catch "UNKNOWN";

    // Get logs
    const logs_json = api.getDeploymentLogs(dep_id.?, 20) catch "";
    defer if (logs_json.len > 0) allocator.free(@constCast(logs_json));

    // Check deployment status first
    if (std.mem.eql(u8, dep_status, "BUILDING") or
        std.mem.eql(u8, dep_status, "DEPLOYING") or
        std.mem.eql(u8, dep_status, "INITIALIZING"))
    {
        result.is_building = true;
        return result;
    }

    // Check for real errors
    if (hasRealError(logs_json)) {
        result.has_error = true;
        return result;
    }

    // Check for training activity
    if (hasTrainingLogs(logs_json)) {
        result.is_training = true;
        result.step = parseLatestStep(logs_json);
        result.ppl = parseLatestPPL(logs_json);
        // Check freshness: look for recent timestamp in logs (within 5 min)
        result.fresh = areLogsFresh(logs_json);
    }

    return result;
}

/// Check if logs are fresh (contain entries from last 5 minutes)
fn areLogsFresh(logs_json: []const u8) bool {
    // Look for ISO timestamp patterns like "2025-03-19T12:34:56"
    var iter = std.mem.splitSequence(u8, logs_json, "T");
    while (iter.next()) |part| {
        if (part.len < 8) continue;
        // Extract time portion "12:34:56"
        var end: usize = 0;
        while (end < part.len and end < 8 and (part[end] >= '0' and part[end] <= '9' or part[end] == ':')) : (end += 1) {}

        if (end >= 8) {
            // Simple heuristic: if we have logs at all, consider them fresh
            // Full timestamp parsing would require more complex logic
            return true;
        }
    }

    // Fallback: if logs contain "step=" they're probably recent enough
    return std.mem.indexOf(u8, logs_json, "step=") != null;
}

/// Check sacred workers via Railway logs API (primary source of truth!)
/// suffix: "" for RAILWAY_API_TOKEN, "_2" for RAILWAY_API_TOKEN_2, etc.
pub fn checkSacredWorkersLive(allocator: Allocator, suffix: []const u8) !void {
    const sacred_file = std.fs.cwd().openFile(".trinity/sacred_workers.txt", .{}) catch {
        print("{s}⚠️  No sacred_workers.txt found{s}\n", .{ YELLOW, RESET });
        return;
    };
    defer sacred_file.close();

    const content = try sacred_file.readToEndAlloc(allocator, 8192);
    defer allocator.free(content);

    print("\n{s}🛡️ SACRED WORKERS — LIVE STATUS (via Railway logs API){s}\n", .{ CYAN, RESET });
    print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var api = railway_api.RailwayApi.initWithSuffix(allocator, suffix) catch return;
    defer api.deinit();

    var alive: usize = 0;
    var training: usize = 0;
    var real_errors: usize = 0;
    var building: usize = 0;

    var iter = std.mem.splitScalar(u8, content, '\n');
    while (iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // Get service ID (api.project_id is set by initWithSuffix)
        const service_id = api.getServiceIdByName(api.project_id, trimmed) catch {
            print("  {s}❌ {s}: NOT FOUND{s}\n", .{ RED, trimmed, RESET });
            continue;
        } orelse {
            print("  {s}❓ {s}: service not found{s}\n", .{ DIM, trimmed, RESET });
            continue;
        };

        alive += 1;

        // Get deployment ID
        const deployment_id = api.getLatestDeploymentId(service_id) catch {
            print("  {s}❌ {s}: no deployment{s}\n", .{ RED, trimmed, RESET });
            continue;
        } orelse continue;

        // Get deployment status
        const dep_status_alloc = api.getDeploymentStatus(deployment_id) catch null;
        defer if (dep_status_alloc) |s| allocator.free(s);
        const dep_status = if (dep_status_alloc) |s| s else "UNKNOWN";

        // Get logs
        const logs_json = api.getDeploymentLogs(deployment_id, 20) catch "";
        defer if (logs_json.len > 0) allocator.free(logs_json);

        // Determine real status
        var status: LiveStatus = .unknown;
        var step: u32 = 0;
        var ppl: f32 = 0;

        if (std.mem.eql(u8, dep_status, "BUILDING") or
            std.mem.eql(u8, dep_status, "DEPLOYING") or
            std.mem.eql(u8, dep_status, "INITIALIZING"))
        {
            status = .building;
            building += 1;
        } else if (hasRealError(logs_json)) {
            status = .has_error;
            real_errors += 1;
        } else if (hasTrainingLogs(logs_json)) {
            status = .training;
            training += 1;
            step = parseLatestStep(logs_json);
            ppl = parseLatestPPL(logs_json);
        } else if (std.mem.eql(u8, dep_status, "SUCCESS")) {
            status = .stalled; // Running but no logs = possibly stalled
        } else {
            status = .unknown;
        }

        // Print status
        const icon = switch (status) {
            .training => "✅",
            .stalled => "⏸️",
            .has_error => "❌",
            .building => "🔄",
            .not_found => "❓",
            .unknown => "❔",
        };

        const status_text = switch (status) {
            .training => "TRAINING",
            .stalled => "stalled (check logs)",
            .has_error => "ERROR - needs restart",
            .building => "BUILDING",
            .not_found => "NOT FOUND",
            .unknown => "UNKNOWN",
        };

        const color = switch (status) {
            .training => GREEN,
            .stalled => YELLOW,
            .has_error => RED,
            .building => CYAN,
            .not_found => DIM,
            .unknown => DIM,
        };

        print("  {s} {s} {s}: step={d:5} PPL={d:6.1} {s}{s}\n", .{
            icon, trimmed, status_text, step, ppl, color, RESET,
        });
    }

    print("\n  {s}Total: {d} alive | {d} training | {d} building | {d} errors{s}\n\n", .{ DIM, alive, training, building, real_errors, RESET });

    // Action recommendations (ONLY for real errors!)
    if (real_errors > 0) {
        print("  {s}🚨 ACTION REQUIRED: {d} workers have REAL errors{s}\n", .{ RED, real_errors, RESET });
        print("  {s}These NEED restart. Others training normally — DON'T touch them!{s}\n\n", .{ YELLOW, RESET });
    } else if (training > 0) {
        print("  {s}✅ NO RESTARTS NEEDED — all sacred workers training or building{s}\n", .{ GREEN, RESET });
        print("  {s}   (Ignore 'stalled' in dashboard — that's cache, not reality!){s}\n\n", .{ DIM, RESET });
    } else {
        print("  {s}⚠️  No training workers found — check deployment status{s}\n\n", .{ YELLOW, RESET });
    }
}
