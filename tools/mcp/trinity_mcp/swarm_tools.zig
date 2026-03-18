// @origin(spec:swarm_tools.tri) @regen(manual-impl)
//! SWARM TOOLS — Ralph Agent Swarm Orchestrator (MCP Tool Module)
//! Implements swarm_orchestrator.tri, swarm_github.tri, swarm_circuit_breaker.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! In-memory state: agents, tasks, file_locks
//! Persisted to .trinity/swarm_state.json on mutations
//! Exposed as 11 MCP tools prefixed "swarm_"
// @origin(manual) @regen(pending)

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES (from swarm_orchestrator.tri)
// ═══════════════════════════════════════════════════════════════════════════════

const MAX_AGENTS = 50;
const MAX_TASKS = 200;
const MAX_LOCKS = 500;
const MAX_STR = 256;
const HEARTBEAT_TIMEOUT_MS: u64 = 120_000;
const CIRCUIT_BREAKER_THRESHOLD: u32 = 5;

pub const Agent = struct {
    id: [MAX_STR]u8 = [_]u8{0} ** MAX_STR,
    id_len: usize = 0,
    hostname: [MAX_STR]u8 = [_]u8{0} ** MAX_STR,
    hostname_len: usize = 0,
    status: [32]u8 = [_]u8{0} ** 32,
    status_len: usize = 0,
    paused: bool = false,
    current_task_id: [MAX_STR]u8 = [_]u8{0} ** MAX_STR,
    current_task_id_len: usize = 0,
    current_branch: [MAX_STR]u8 = [_]u8{0} ** MAX_STR,
    current_branch_len: usize = 0,
    last_heartbeat_ms: u64 = 0,
    registered_at_ms: u64 = 0,
    tasks_completed: u32 = 0,
    tasks_failed: u32 = 0,
    no_progress_count: u32 = 0,
    last_commit_sha: [64]u8 = [_]u8{0} ** 64,
    last_commit_sha_len: usize = 0,
    active: bool = false,

    pub fn getId(self: *const Agent) []const u8 {
        return self.id[0..self.id_len];
    }

    pub fn getStatus(self: *const Agent) []const u8 {
        return self.status[0..self.status_len];
    }

    pub fn getBranch(self: *const Agent) []const u8 {
        return self.current_branch[0..self.current_branch_len];
    }

    pub fn getTaskId(self: *const Agent) []const u8 {
        return self.current_task_id[0..self.current_task_id_len];
    }

    pub fn getLastSha(self: *const Agent) []const u8 {
        return self.last_commit_sha[0..self.last_commit_sha_len];
    }

    fn setStr(dest: []u8, dest_len: *usize, src: []const u8) void {
        const copy_len = @min(src.len, dest.len);
        @memcpy(dest[0..copy_len], src[0..copy_len]);
        dest_len.* = copy_len;
    }

    pub fn isHealthy(self: *const Agent) bool {
        if (self.last_heartbeat_ms == 0) return false;
        const now = currentTimeMs();
        return (now - self.last_heartbeat_ms) < HEARTBEAT_TIMEOUT_MS;
    }

    pub fn isAvailable(self: *const Agent) bool {
        const s = self.getStatus();
        return !self.paused and (std.mem.eql(u8, s, "idle") or std.mem.eql(u8, s, "polling"));
    }

    pub fn statusEmoji(self: *const Agent) []const u8 {
        const s = self.getStatus();
        if (std.mem.eql(u8, s, "working")) return "🔷";
        if (std.mem.eql(u8, s, "idle") or std.mem.eql(u8, s, "polling")) return "🟢";
        if (std.mem.eql(u8, s, "error")) return "🔴";
        if (std.mem.eql(u8, s, "offline") or std.mem.eql(u8, s, "shutdown")) return "⚫";
        return "⬜";
    }
};

pub const Task = struct {
    id: [MAX_STR]u8 = [_]u8{0} ** MAX_STR,
    id_len: usize = 0,
    slug: [MAX_STR]u8 = [_]u8{0} ** MAX_STR,
    slug_len: usize = 0,
    description: [1024]u8 = [_]u8{0} ** 1024,
    description_len: usize = 0,
    priority: [4]u8 = [_]u8{0} ** 4,
    priority_len: usize = 0,
    status: [32]u8 = [_]u8{0} ** 32,
    status_len: usize = 0,
    assigned_to: [MAX_STR]u8 = [_]u8{0} ** MAX_STR,
    assigned_to_len: usize = 0,
    branch: [MAX_STR]u8 = [_]u8{0} ** MAX_STR,
    branch_len: usize = 0,
    created_at_ms: u64 = 0,
    assigned_at_ms: u64 = 0,
    completed_at_ms: u64 = 0,
    active: bool = false,

    pub fn getId(self: *const Task) []const u8 {
        return self.id[0..self.id_len];
    }
    pub fn getSlug(self: *const Task) []const u8 {
        return self.slug[0..self.slug_len];
    }
    pub fn getDesc(self: *const Task) []const u8 {
        return self.description[0..self.description_len];
    }
    pub fn getPriority(self: *const Task) []const u8 {
        return self.priority[0..self.priority_len];
    }
    pub fn getStatus(self: *const Task) []const u8 {
        return self.status[0..self.status_len];
    }
    pub fn getAssignedTo(self: *const Task) []const u8 {
        return self.assigned_to[0..self.assigned_to_len];
    }

    fn priorityWeight(self: *const Task) u8 {
        const p = self.getPriority();
        if (std.mem.eql(u8, p, "P0")) return 0;
        if (std.mem.eql(u8, p, "P1")) return 1;
        if (std.mem.eql(u8, p, "P2")) return 2;
        if (std.mem.eql(u8, p, "P3")) return 3;
        return 1; // default P1
    }

    fn setStr(dest: []u8, dest_len: *usize, src: []const u8) void {
        const copy_len = @min(src.len, dest.len);
        @memcpy(dest[0..copy_len], src[0..copy_len]);
        dest_len.* = copy_len;
    }
};

const FileLock = struct {
    path: [MAX_STR]u8 = [_]u8{0} ** MAX_STR,
    path_len: usize = 0,
    agent_id: [MAX_STR]u8 = [_]u8{0} ** MAX_STR,
    agent_id_len: usize = 0,
    active: bool = false,
};

// ═══════════════════════════════════════════════════════════════════════════════
// STATE (static, lives for process lifetime)
// ═══════════════════════════════════════════════════════════════════════════════

var agents: [MAX_AGENTS]Agent = [_]Agent{.{}} ** MAX_AGENTS;
var tasks: [MAX_TASKS]Task = [_]Task{.{}} ** MAX_TASKS;
var file_locks: [MAX_LOCKS]FileLock = [_]FileLock{.{}} ** MAX_LOCKS;
var id_counter: u64 = 0;

fn currentTimeMs() u64 {
    const ts = std.time.milliTimestamp();
    return @intCast(if (ts < 0) 0 else ts);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC READ-ONLY ACCESSORS (for oracle_watchdog.zig thread)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn getAgentsPtr() *const [MAX_AGENTS]Agent {
    ensureLoaded();
    return &agents;
}

pub fn getTasksPtr() *const [MAX_TASKS]Task {
    ensureLoaded();
    return &tasks;
}

// ═══════════════════════════════════════════════════════════════════════════════
// AGENT MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════════

fn findAgent(agent_id: []const u8) ?*Agent {
    for (&agents) |*a| {
        if (a.active and std.mem.eql(u8, a.getId(), agent_id)) return a;
    }
    return null;
}

fn findFreeAgent() ?*Agent {
    for (&agents) |*a| {
        if (!a.active) return a;
    }
    return null;
}

fn registerAgent(agent_id: []const u8, hostname: []const u8) bool {
    // Update existing
    if (findAgent(agent_id)) |a| {
        Agent.setStr(&a.hostname, &a.hostname_len, hostname);
        Agent.setStr(&a.status, &a.status_len, "idle");
        a.last_heartbeat_ms = currentTimeMs();
        return true;
    }
    // New agent
    const a = findFreeAgent() orelse return false;
    a.* = .{};
    a.active = true;
    Agent.setStr(&a.id, &a.id_len, agent_id);
    Agent.setStr(&a.hostname, &a.hostname_len, hostname);
    Agent.setStr(&a.status, &a.status_len, "idle");
    a.registered_at_ms = currentTimeMs();
    a.last_heartbeat_ms = currentTimeMs();
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TASK MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════════

fn findTask(task_id: []const u8) ?*Task {
    for (&tasks) |*t| {
        if (t.active and std.mem.eql(u8, t.getId(), task_id)) return t;
    }
    return null;
}

fn findFreeTask() ?*Task {
    for (&tasks) |*t| {
        if (!t.active) return t;
    }
    return null;
}

fn addTask(slug: []const u8, description: []const u8, priority: []const u8) ?[]const u8 {
    const t = findFreeTask() orelse return null;
    t.* = .{};
    t.active = true;

    // Generate ID
    id_counter += 1;
    var id_buf: [32]u8 = undefined;
    const id_str = std.fmt.bufPrint(&id_buf, "task-{d}", .{id_counter}) catch return null;
    Task.setStr(&t.id, &t.id_len, id_str);
    Task.setStr(&t.slug, &t.slug_len, slug);
    Task.setStr(&t.description, &t.description_len, description);
    Task.setStr(&t.priority, &t.priority_len, if (priority.len == 0) "P1" else priority);
    Task.setStr(&t.status, &t.status_len, "pending");
    t.created_at_ms = currentTimeMs();

    return t.getId();
}

fn addTaskWithId(id: []const u8, slug: []const u8, description: []const u8, priority: []const u8) bool {
    // Check if already exists
    if (findTask(id) != null) return false;

    const t = findFreeTask() orelse return false;
    t.* = .{};
    t.active = true;
    Task.setStr(&t.id, &t.id_len, id);
    Task.setStr(&t.slug, &t.slug_len, slug);
    Task.setStr(&t.description, &t.description_len, description);
    Task.setStr(&t.priority, &t.priority_len, if (priority.len == 0) "P1" else priority);
    Task.setStr(&t.status, &t.status_len, "pending");
    t.created_at_ms = currentTimeMs();
    return true;
}

fn nextPendingTask(exclude_agent_id: []const u8) ?*Task {
    // Find highest priority pending task (P0 > P1 > P2 > P3)
    // Skip tasks whose files are locked by other agents
    var best: ?*Task = null;
    var best_weight: u8 = 255;
    var best_time: u64 = std.math.maxInt(u64);

    for (&tasks) |*t| {
        if (!t.active) continue;
        if (!std.mem.eql(u8, t.getStatus(), "pending")) continue;

        // Check file affinity: skip task if its files are locked by another agent
        if (exclude_agent_id.len > 0 and isLockedByOther(t.getId(), exclude_agent_id)) continue;

        const w = t.priorityWeight();
        if (w < best_weight or (w == best_weight and t.created_at_ms < best_time)) {
            best = t;
            best_weight = w;
            best_time = t.created_at_ms;
        }
    }
    return best;
}

fn cancelTask(task_id: []const u8) bool {
    const t = findTask(task_id) orelse return false;
    t.active = false;
    releaseLocksByTask(task_id);
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILE LOCKING
// ═══════════════════════════════════════════════════════════════════════════════

fn releaseLocksByAgent(agent_id: []const u8) void {
    for (&file_locks) |*fl| {
        if (fl.active and std.mem.eql(u8, fl.agent_id[0..fl.agent_id_len], agent_id)) {
            fl.active = false;
        }
    }
}

fn releaseLocksByTask(task_id: []const u8) void {
    // Find which agent owns this task, then release that agent's locks
    for (&agents) |*a| {
        if (!a.active) continue;
        if (std.mem.eql(u8, a.getTaskId(), task_id)) {
            releaseLocksByAgent(a.getId());
            return;
        }
    }
}

fn isLockedByOther(task_id: []const u8, requesting_agent_id: []const u8) bool {
    // Check if any file locks related to this task's slug are held by another agent
    const task = findTask(task_id) orelse return false;
    const slug = task.getSlug();
    if (slug.len == 0) return false;

    for (&file_locks) |*fl| {
        if (!fl.active) continue;
        const lock_agent = fl.agent_id[0..fl.agent_id_len];
        // Skip locks owned by the requesting agent (they can take their own tasks)
        if (std.mem.eql(u8, lock_agent, requesting_agent_id)) continue;
        // Check if lock path contains the task slug (file affinity match)
        const lock_path = fl.path[0..fl.path_len];
        if (std.mem.indexOf(u8, lock_path, slug) != null) return true;
    }
    return false;
}

fn acquireLock(path: []const u8, agent_id: []const u8) bool {
    // Check if already locked by another agent
    for (&file_locks) |*fl| {
        if (!fl.active) continue;
        if (std.mem.eql(u8, fl.path[0..fl.path_len], path)) {
            // Already locked — check if by same agent (re-entrant) or different
            return std.mem.eql(u8, fl.agent_id[0..fl.agent_id_len], agent_id);
        }
    }
    // Find free slot and acquire
    for (&file_locks) |*fl| {
        if (!fl.active) {
            fl.* = .{};
            fl.active = true;
            const plen = @min(path.len, fl.path.len);
            @memcpy(fl.path[0..plen], path[0..plen]);
            fl.path_len = plen;
            const alen = @min(agent_id.len, fl.agent_id.len);
            @memcpy(fl.agent_id[0..alen], agent_id[0..alen]);
            fl.agent_id_len = alen;
            return true;
        }
    }
    return false; // no free slots
}

// ═══════════════════════════════════════════════════════════════════════════════
// CIRCUIT BREAKER (from swarm_circuit_breaker.tri)
// ═══════════════════════════════════════════════════════════════════════════════

fn checkProgress(agent: *Agent, commit_sha: []const u8) void {
    if (commit_sha.len == 0 or std.mem.eql(u8, commit_sha, "none")) {
        agent.no_progress_count += 1;
        return;
    }

    const prev_sha = agent.getLastSha();
    if (std.mem.eql(u8, prev_sha, commit_sha)) {
        agent.no_progress_count += 1;
    } else {
        agent.no_progress_count = 0;
        Agent.setStr(&agent.last_commit_sha, &agent.last_commit_sha_len, commit_sha);
    }
}

fn isTripped(agent: *const Agent) bool {
    return agent.no_progress_count >= CIRCUIT_BREAKER_THRESHOLD;
}

fn tripAgent(agent: *Agent) void {
    agent.paused = true;
    Agent.setStr(&agent.status, &agent.status_len, "error");
}

fn resetCircuitBreaker(agent: *Agent) void {
    agent.no_progress_count = 0;
    agent.last_commit_sha_len = 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEARTBEAT (core behavior from swarm_orchestrator.tri)
// ═══════════════════════════════════════════════════════════════════════════════

const HeartbeatResult = struct {
    ok: bool = false,
    circuit_tripped: bool = false,
    task_completed: bool = false,
    task_failed: bool = false,
    message: [256]u8 = [_]u8{0} ** 256,
    message_len: usize = 0,
};

fn heartbeat(agent_id: []const u8, status: []const u8, branch: []const u8, task_id: []const u8, commit_sha: []const u8) HeartbeatResult {
    var result = HeartbeatResult{};

    // Auto-register unknown agents
    if (findAgent(agent_id) == null) {
        if (!registerAgent(agent_id, "")) {
            return result;
        }
    }

    const agent = findAgent(agent_id) orelse return result;
    result.ok = true;

    // Save previous task_id before overwriting (needed for completion check)
    var prev_task_id: [MAX_STR]u8 = undefined;
    const prev_task_id_len = agent.current_task_id_len;
    @memcpy(prev_task_id[0..prev_task_id_len], agent.current_task_id[0..prev_task_id_len]);

    // Update basic state
    Agent.setStr(&agent.status, &agent.status_len, status);
    Agent.setStr(&agent.current_branch, &agent.current_branch_len, branch);
    if (task_id.len > 0) {
        Agent.setStr(&agent.current_task_id, &agent.current_task_id_len, task_id);
    }
    agent.last_heartbeat_ms = currentTimeMs();

    // Handle working state — circuit breaker
    if (std.mem.eql(u8, status, "working")) {
        checkProgress(agent, commit_sha);
        if (isTripped(agent)) {
            tripAgent(agent);
            result.circuit_tripped = true;
            const msg = std.fmt.bufPrint(&result.message, "CIRCUIT BREAKER: Agent {s} paused after {d} no-progress heartbeats", .{ agent_id, agent.no_progress_count }) catch "";
            result.message_len = msg.len;

            // Mark current task as failed
            if (task_id.len > 0) {
                if (findTask(task_id)) |task| {
                    Task.setStr(&task.status, &task.status_len, "failed");
                    agent.tasks_failed += 1;
                }
            }
        }
    }

    // Handle completion (use prev task_id — heartbeat may send empty task_id on completion)
    if (std.mem.eql(u8, status, "completed") or std.mem.eql(u8, status, "idle")) {
        if (prev_task_id_len > 0) {
            const tid = prev_task_id[0..prev_task_id_len];
            if (findTask(tid)) |task| {
                if (std.mem.eql(u8, task.getStatus(), "assigned") or std.mem.eql(u8, task.getStatus(), "running")) {
                    Task.setStr(&task.status, &task.status_len, "completed");
                    task.completed_at_ms = currentTimeMs();
                    agent.tasks_completed += 1;
                    result.task_completed = true;
                }
            }
        }
        releaseLocksByAgent(agent_id);
        resetCircuitBreaker(agent);
    }

    // Handle error
    if (std.mem.eql(u8, status, "error")) {
        if (prev_task_id_len > 0) {
            const tid = prev_task_id[0..prev_task_id_len];
            if (findTask(tid)) |task| {
                Task.setStr(&task.status, &task.status_len, "failed");
                agent.tasks_failed += 1;
                result.task_failed = true;
            }
        }
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ASSIGN TASK
// ═══════════════════════════════════════════════════════════════════════════════

fn assignTask(agent_id: []const u8) ?*Task {
    const agent = findAgent(agent_id) orelse return null;
    if (agent.paused) return null;

    const task = nextPendingTask(agent_id) orelse return null;

    Task.setStr(&task.status, &task.status_len, "assigned");
    Task.setStr(&task.assigned_to, &task.assigned_to_len, agent_id);
    task.assigned_at_ms = currentTimeMs();

    Agent.setStr(&agent.current_task_id, &agent.current_task_id_len, task.getId());

    return task;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GITHUB HELPERS (from swarm_github.tri)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn slugify(buf: []u8, title: []const u8) []const u8 {
    var idx: usize = 0;
    var prev_dash = false;

    for (title) |c| {
        if (idx >= buf.len - 1 or idx >= 50) break;
        if (c >= 'A' and c <= 'Z') {
            buf[idx] = c + 32; // lowercase
            idx += 1;
            prev_dash = false;
        } else if ((c >= 'a' and c <= 'z') or (c >= '0' and c <= '9')) {
            buf[idx] = c;
            idx += 1;
            prev_dash = false;
        } else if (c == ' ' or c == '_' or c == '-') {
            if (!prev_dash and idx > 0) {
                buf[idx] = '-';
                idx += 1;
                prev_dash = true;
            }
        }
        // else: skip special chars
    }

    // Trim trailing dash
    if (idx > 0 and buf[idx - 1] == '-') idx -= 1;

    return buf[0..idx];
}

pub fn parseIssueNumber(task_id: []const u8) ?u32 {
    if (task_id.len < 4) return null;
    if (!std.mem.startsWith(u8, task_id, "gh-")) return null;
    return std.fmt.parseInt(u32, task_id[3..], 10) catch null;
}

pub fn extractPriority(labels_csv: []const u8) []const u8 {
    if (std.mem.indexOf(u8, labels_csv, "priority:P0") != null) return "P0";
    if (std.mem.indexOf(u8, labels_csv, "priority:P1") != null) return "P1";
    if (std.mem.indexOf(u8, labels_csv, "priority:P2") != null) return "P2";
    if (std.mem.indexOf(u8, labels_csv, "priority:P3") != null) return "P3";
    return "P1"; // default
}

// ═══════════════════════════════════════════════════════════════════════════════
// GITHUB WRITE-THROUGH — create issues directly via GitHub API
// ═══════════════════════════════════════════════════════════════════════════════

/// Create a GitHub issue via REST API. Returns issue number or null.
/// Graceful degradation: returns null if GH_TOKEN not set.
pub fn createGitHubIssue(allocator: std.mem.Allocator, title: []const u8, body_text: []const u8, priority: []const u8) ?u32 {
    const gh_token = std.posix.getenv("GH_TOKEN") orelse
        std.posix.getenv("GITHUB_TOKEN") orelse return null;
    const owner = std.posix.getenv("GITHUB_OWNER") orelse "gHashTag";
    const repo = std.posix.getenv("GITHUB_REPO") orelse "trinity";

    // URL
    var url_buf: [256]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.github.com/repos/{s}/{s}/issues", .{ owner, repo }) catch return null;

    // Auth header
    var auth_buf: [300]u8 = undefined;
    const auth_val = std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{gh_token}) catch return null;

    // Build JSON body with escaped title and body
    var payload_buf: [4096]u8 = undefined;
    var pi: usize = 0;
    pi = bufAppend(&payload_buf, pi, "{\"title\":\"");
    pi += bufJsonEscape(payload_buf[pi..], title);
    pi = bufAppend(&payload_buf, pi, "\",\"body\":\"");
    pi += bufJsonEscape(payload_buf[pi..], body_text);
    pi = bufAppend(&payload_buf, pi, "\",\"labels\":[\"assign:ralph\",\"status:pending\"");
    if (priority.len > 0) {
        pi = bufAppend(&payload_buf, pi, ",\"priority:");
        pi = bufAppend(&payload_buf, pi, priority);
        pi = bufAppend(&payload_buf, pi, "\"");
    }
    pi = bufAppend(&payload_buf, pi, "]}");

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // Capture response to extract issue number
    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const result = client.fetch(.{
        .location = .{ .url = url },
        .method = .POST,
        .payload = payload_buf[0..pi],
        .extra_headers = &.{
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
            .{ .name = "User-Agent", .value = "trinity-swarm/1.0" },
            .{ .name = "Content-Type", .value = "application/json" },
        },
        .response_writer = &aw.writer,
    }) catch return null;

    if (result.status != .created) return null;

    // Extract "number": N from response
    const resp = aw.written();
    const needle = "\"number\":";
    const pos = std.mem.indexOf(u8, resp, needle) orelse return null;
    var num_start = pos + needle.len;
    while (num_start < resp.len and resp[num_start] == ' ') num_start += 1;
    var num_end = num_start;
    while (num_end < resp.len and resp[num_end] >= '0' and resp[num_end] <= '9') num_end += 1;
    if (num_end == num_start) return null;
    return std.fmt.parseInt(u32, resp[num_start..num_end], 10) catch null;
}

/// Link an issue as sub-issue of the swarm parent via GraphQL.
/// Best-effort: failure = no link, issue still exists standalone.
pub fn linkAsSubIssue(allocator: std.mem.Allocator, child_number: u32) void {
    const gh_token = std.posix.getenv("GH_TOKEN") orelse
        std.posix.getenv("GITHUB_TOKEN") orelse return;
    const owner = std.posix.getenv("GITHUB_OWNER") orelse "gHashTag";
    const repo = std.posix.getenv("GITHUB_REPO") orelse "trinity";
    const parent_num_str = std.posix.getenv("SWARM_PARENT_ISSUE") orelse "38";
    const parent_num = std.fmt.parseInt(u32, parent_num_str, 10) catch return;

    // Step 1: Get parent and child node IDs via GraphQL
    var query_buf: [1024]u8 = undefined;
    const query = std.fmt.bufPrint(&query_buf,
        \\{{"query":"{{ repository(owner:\\\"{s}\\\", name:\\\"{s}\\\") {{ parent: issue(number:{d}) {{ id }} child: issue(number:{d}) {{ id }} }} }}"}}
    , .{ owner, repo, parent_num, child_number }) catch return;

    var auth_buf: [300]u8 = undefined;
    const auth_val = std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{gh_token}) catch return;

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const result = client.fetch(.{
        .location = .{ .url = "https://api.github.com/graphql" },
        .method = .POST,
        .payload = query,
        .extra_headers = &.{
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "Content-Type", .value = "application/json" },
            .{ .name = "User-Agent", .value = "trinity-swarm/1.0" },
        },
        .response_writer = &aw.writer,
    }) catch return;

    if (result.status != .ok) return;

    // Extract parent and child IDs from response
    const resp = aw.written();
    const parent_id = extractNodeId(resp, "parent") orelse return;
    const child_id = extractNodeId(resp, "child") orelse return;

    // Step 2: Mutation to link
    var mut_buf: [1024]u8 = undefined;
    const mutation = std.fmt.bufPrint(&mut_buf,
        \\{{"query":"mutation {{ addSubIssue(input: {{ issueId: \\\"{s}\\\", subIssueId: \\\"{s}\\\" }}) {{ issue {{ id }} }} }}"}}
    , .{ parent_id, child_id }) catch return;

    var aw2: std.Io.Writer.Allocating = .init(allocator);
    defer aw2.deinit();

    _ = client.fetch(.{
        .location = .{ .url = "https://api.github.com/graphql" },
        .method = .POST,
        .payload = mutation,
        .extra_headers = &.{
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "Content-Type", .value = "application/json" },
            .{ .name = "User-Agent", .value = "trinity-swarm/1.0" },
        },
        .response_writer = &aw2.writer,
    }) catch return;
}

/// Extract GraphQL node ID from response like "parent":{"id":"I_kwDO..."}
fn extractNodeId(resp: []const u8, alias: []const u8) ?[]const u8 {
    // Find "alias":{"id":"..."}
    var search_buf: [64]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":{{\"id\":\"", .{alias}) catch return null;
    const start = std.mem.indexOf(u8, resp, search) orelse return null;
    const id_start = start + search.len;
    const id_end = std.mem.indexOfPos(u8, resp, id_start, "\"") orelse return null;
    return resp[id_start..id_end];
}

const GitHubCounts = struct {
    open: u32 = 0,
    pending: u32 = 0,
    in_progress: u32 = 0,
    fetch_ok: bool = false,
};

/// Collect GitHub issue counts (for swarmStatus display)
fn collectGitHubCounts(allocator: std.mem.Allocator) GitHubCounts {
    var result = GitHubCounts{};

    const gh_token = std.posix.getenv("GH_TOKEN") orelse
        std.posix.getenv("GITHUB_TOKEN") orelse return result;
    const owner = std.posix.getenv("GITHUB_OWNER") orelse "gHashTag";
    const repo = std.posix.getenv("GITHUB_REPO") orelse "trinity";

    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.github.com/repos/{s}/{s}/issues?labels=assign:ralph&state=open&per_page=100", .{ owner, repo }) catch return result;

    var auth_buf: [300]u8 = undefined;
    const auth_val = std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{gh_token}) catch return result;

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const fetch_result = client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .extra_headers = &.{
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
            .{ .name = "User-Agent", .value = "trinity-swarm/1.0" },
        },
        .response_writer = &aw.writer,
    }) catch return result;

    if (fetch_result.status != .ok) return result;

    result.fetch_ok = true;
    const body = aw.written();
    result.open = countLabelOccurrences(body, "\"state\":\"open\"");
    result.pending = countLabelOccurrences(body, "\"status:pending\"");
    result.in_progress = countLabelOccurrences(body, "\"status:in-progress\"");
    return result;
}

fn countLabelOccurrences(haystack: []const u8, needle: []const u8) u32 {
    if (needle.len == 0 or haystack.len < needle.len) return 0;
    var count: u32 = 0;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) {
        if (std.mem.eql(u8, haystack[i..][0..needle.len], needle)) {
            count += 1;
            i += needle.len;
        } else {
            i += 1;
        }
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GITHUB INTEGRATION MCP TOOLS (from swarm_github.tri)
// Return JSON instructions for Go proxy to execute against GitHub API
// ═══════════════════════════════════════════════════════════════════════════════

/// swarm_github_sync — Convert a GitHub issue to a swarm task.
/// Go proxy calls this after polling GitHub Issues API.
/// Returns JSON: task_id, slug, priority, labels_to_add, labels_to_remove.
pub fn swarmGithubSync(buf: []u8, issue_number: []const u8, title: []const u8, labels_csv: []const u8) []const u8 {
    ensureLoaded();
    defer saveState();

    // Build task ID: gh-{number}
    var id_buf: [64]u8 = undefined;
    const id = std.fmt.bufPrint(&id_buf, "gh-{s}", .{issue_number}) catch return "Error: id format";

    // Slugify the title
    var slug_buf: [64]u8 = undefined;
    const slug = slugify(&slug_buf, title);

    // Extract priority from labels
    const priority = extractPriority(labels_csv);

    // Check if task already exists
    if (findTask(id) != null) {
        var i: usize = 0;
        i += (std.fmt.bufPrint(buf[i..], "{{\"exists\":true,\"task_id\":\"{s}\",\"slug\":\"{s}\"", .{ id, slug }) catch return "Error: fmt").len;
        i = bufAppend(buf, i, "}");
        return buf[0..i];
    }

    // Add task to queue
    const task_id = addTask(slug, title, priority);
    if (task_id) |tid| {
        // Override the auto-generated ID with gh-{number}
        if (findTask(tid)) |t| {
            Task.setStr(&t.id, &t.id_len, id);
        }
    }

    var i: usize = 0;
    i += (std.fmt.bufPrint(buf[i..], "{{\"created\":true,\"task_id\":\"{s}\",\"slug\":\"{s}\",\"priority\":\"{s}\"", .{ id, slug, priority }) catch return "Error: fmt").len;
    i = bufAppend(buf, i, ",\"labels_add\":[\"status:pending\"],\"labels_remove\":[\"assign:ralph\"]");
    i = bufAppend(buf, i, "}");
    return buf[0..i];
}

/// swarm_github_on_start — Agent started working on a GitHub-sourced task.
/// Returns JSON instructions: labels to swap, comment to post.
pub fn swarmGithubOnStart(buf: []u8, task_id: []const u8, agent_id: []const u8, branch: []const u8) []const u8 {
    ensureLoaded();

    const issue_num = parseIssueNumber(task_id) orelse {
        var i: usize = 0;
        i = bufAppend(buf, i, "{\"skip\":true,\"reason\":\"not a github task\"}");
        return buf[0..i];
    };

    var i: usize = 0;
    i += (std.fmt.bufPrint(buf[i..], "{{\"issue\":{d},\"labels_add\":[\"status:in-progress\"],\"labels_remove\":[\"status:pending\"]", .{issue_num}) catch return "Error: fmt").len;
    i = bufAppend(buf, i, ",\"comment\":\"");
    i += (std.fmt.bufPrint(buf[i..], "🔷 Agent `{s}` started working\\nBranch: `{s}`", .{ agent_id, branch }) catch return "Error: fmt").len;
    i = bufAppend(buf, i, "\"}");
    return buf[0..i];
}

/// swarm_github_on_complete — Task completed successfully.
/// Returns JSON: labels to swap, comment, close_issue=true.
pub fn swarmGithubOnComplete(buf: []u8, task_id: []const u8, agent_id: []const u8, result_summary: []const u8) []const u8 {
    ensureLoaded();

    const issue_num = parseIssueNumber(task_id) orelse {
        var i: usize = 0;
        i = bufAppend(buf, i, "{\"skip\":true,\"reason\":\"not a github task\"}");
        return buf[0..i];
    };

    var i: usize = 0;
    i += (std.fmt.bufPrint(buf[i..], "{{\"issue\":{d},\"labels_add\":[\"status:completed\"],\"labels_remove\":[\"status:in-progress\"]", .{issue_num}) catch return "Error: fmt").len;
    i = bufAppend(buf, i, ",\"close_issue\":true,\"comment\":\"");
    i += (std.fmt.bufPrint(buf[i..], "✅ Completed by `{s}`\\n", .{agent_id}) catch return "Error: fmt").len;
    i += bufJsonEscape(buf[i..], result_summary);
    i = bufAppend(buf, i, "\"}");
    return buf[0..i];
}

/// swarm_github_on_fail — Task failed.
/// Returns JSON: labels to swap, comment with error.
pub fn swarmGithubOnFail(buf: []u8, task_id: []const u8, agent_id: []const u8, error_msg: []const u8) []const u8 {
    ensureLoaded();

    const issue_num = parseIssueNumber(task_id) orelse {
        var i: usize = 0;
        i = bufAppend(buf, i, "{\"skip\":true,\"reason\":\"not a github task\"}");
        return buf[0..i];
    };

    var i: usize = 0;
    i += (std.fmt.bufPrint(buf[i..], "{{\"issue\":{d},\"labels_add\":[\"status:failed\"],\"labels_remove\":[\"status:in-progress\"]", .{issue_num}) catch return "Error: fmt").len;
    i = bufAppend(buf, i, ",\"comment\":\"");
    i += (std.fmt.bufPrint(buf[i..], "❌ Failed on `{s}`\\n", .{agent_id}) catch return "Error: fmt").len;
    i += bufJsonEscape(buf[i..], error_msg);
    i = bufAppend(buf, i, "\"}");
    return buf[0..i];
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERSISTENCE — save/load state to .trinity/swarm_state.json
// ═══════════════════════════════════════════════════════════════════════════════

const STATE_FILE = ".trinity/swarm_state.json";
var state_loaded: bool = false;

pub fn ensureLoaded() void {
    if (state_loaded) return;
    state_loaded = true;
    loadState();

    // Auto-register MU Doctor as built-in agent
    if (findAgent("mu-doctor") == null) {
        _ = registerAgent("mu-doctor", "localhost");
        if (findAgent("mu-doctor")) |mu| {
            Agent.setStr(&mu.status, &mu.status_len, "idle");
        }
    }
}

/// Append JSON-escaped string to buffer (handles ", \, newlines, control chars)
fn bufJsonEscape(dest: []u8, src: []const u8) usize {
    var idx: usize = 0;
    for (src) |c| {
        switch (c) {
            '"' => {
                if (idx + 2 > dest.len) return idx;
                dest[idx] = '\\';
                dest[idx + 1] = '"';
                idx += 2;
            },
            '\\' => {
                if (idx + 2 > dest.len) return idx;
                dest[idx] = '\\';
                dest[idx + 1] = '\\';
                idx += 2;
            },
            '\n' => {
                if (idx + 2 > dest.len) return idx;
                dest[idx] = '\\';
                dest[idx + 1] = 'n';
                idx += 2;
            },
            '\r' => {
                if (idx + 2 > dest.len) return idx;
                dest[idx] = '\\';
                dest[idx + 1] = 'r';
                idx += 2;
            },
            '\t' => {
                if (idx + 2 > dest.len) return idx;
                dest[idx] = '\\';
                dest[idx + 1] = 't';
                idx += 2;
            },
            else => {
                if (c >= 0x20) {
                    if (idx >= dest.len) return idx;
                    dest[idx] = c;
                    idx += 1;
                }
                // skip other control chars
            },
        }
    }
    return idx;
}

/// Append raw string to buffer, return new index
fn bufAppend(buf: []u8, pos: usize, s: []const u8) usize {
    if (pos + s.len > buf.len) return pos;
    @memcpy(buf[pos..][0..s.len], s);
    return pos + s.len;
}

fn saveState() void {
    std.fs.cwd().makeDir(".trinity") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return,
    };

    var buf: [384 * 1024]u8 = undefined;
    var i: usize = 0;

    i += (std.fmt.bufPrint(buf[i..], "{{\"id_counter\":{d},\"agents\":[", .{id_counter}) catch return).len;

    var first_a = true;
    for (&agents) |*a| {
        if (!a.active) continue;
        if (!first_a) {
            if (i >= buf.len) return;
            buf[i] = ',';
            i += 1;
        }
        first_a = false;

        i = bufAppend(&buf, i, "{\"id\":\"");
        i = bufAppend(&buf, i, a.getId());
        i = bufAppend(&buf, i, "\",\"hostname\":\"");
        i = bufAppend(&buf, i, a.hostname[0..a.hostname_len]);
        i = bufAppend(&buf, i, "\",\"status\":\"");
        i = bufAppend(&buf, i, a.getStatus());
        i = bufAppend(&buf, i, "\",\"paused\":");
        i = bufAppend(&buf, i, if (a.paused) "true" else "false");
        i = bufAppend(&buf, i, ",\"task_id\":\"");
        i = bufAppend(&buf, i, a.getTaskId());
        i = bufAppend(&buf, i, "\",\"branch\":\"");
        i = bufAppend(&buf, i, a.getBranch());
        i += (std.fmt.bufPrint(buf[i..], "\",\"hb_ms\":{d},\"reg_ms\":{d},\"tasks_done\":{d},\"tasks_failed\":{d},\"no_progress\":{d},\"sha\":\"", .{
            a.last_heartbeat_ms, a.registered_at_ms,
            a.tasks_completed,   a.tasks_failed,
            a.no_progress_count,
        }) catch return).len;
        i = bufAppend(&buf, i, a.getLastSha());
        i = bufAppend(&buf, i, "\"}");
    }

    i = bufAppend(&buf, i, "],\"tasks\":[");

    var first_t = true;
    for (&tasks) |*t| {
        if (!t.active) continue;
        if (!first_t) {
            if (i >= buf.len) return;
            buf[i] = ',';
            i += 1;
        }
        first_t = false;

        i = bufAppend(&buf, i, "{\"id\":\"");
        i = bufAppend(&buf, i, t.getId());
        i = bufAppend(&buf, i, "\",\"slug\":\"");
        i = bufAppend(&buf, i, t.getSlug());
        i = bufAppend(&buf, i, "\",\"desc\":\"");
        i += bufJsonEscape(buf[i..], t.getDesc());
        i = bufAppend(&buf, i, "\",\"priority\":\"");
        i = bufAppend(&buf, i, t.getPriority());
        i = bufAppend(&buf, i, "\",\"status\":\"");
        i = bufAppend(&buf, i, t.getStatus());
        i = bufAppend(&buf, i, "\",\"assigned\":\"");
        i = bufAppend(&buf, i, t.getAssignedTo());
        i = bufAppend(&buf, i, "\",\"branch\":\"");
        i = bufAppend(&buf, i, t.branch[0..t.branch_len]);
        i += (std.fmt.bufPrint(buf[i..], "\",\"created_ms\":{d},\"assigned_ms\":{d},\"completed_ms\":{d}}}", .{
            t.created_at_ms, t.assigned_at_ms, t.completed_at_ms,
        }) catch return).len;
    }

    i = bufAppend(&buf, i, "],\"locks\":[");

    var first_l = true;
    for (&file_locks) |*fl| {
        if (!fl.active) continue;
        if (!first_l) {
            if (i >= buf.len) return;
            buf[i] = ',';
            i += 1;
        }
        first_l = false;

        i = bufAppend(&buf, i, "{\"path\":\"");
        i = bufAppend(&buf, i, fl.path[0..fl.path_len]);
        i = bufAppend(&buf, i, "\",\"agent_id\":\"");
        i = bufAppend(&buf, i, fl.agent_id[0..fl.agent_id_len]);
        i = bufAppend(&buf, i, "\"}");
    }

    i = bufAppend(&buf, i, "]}");

    // Write to file in one shot
    const file = std.fs.cwd().createFile(STATE_FILE, .{}) catch return;
    defer file.close();
    file.writeAll(buf[0..i]) catch return;
}

fn loadState() void {
    const file = std.fs.cwd().openFile(STATE_FILE, .{}) catch return;
    defer file.close();

    var buf: [512 * 1024]u8 = undefined;
    var total: usize = 0;
    while (total < buf.len) {
        const n = file.read(buf[total..]) catch break;
        if (n == 0) break;
        total += n;
    }
    if (total == 0) return;
    const json = buf[0..total];

    // Parse id_counter
    id_counter = jExtU64(json, "id_counter");

    // Parse agents
    if (jFindArray(json, "agents")) |range| {
        const arr = json[range.start..range.end];
        var pos: usize = 0;
        var slot: usize = 0;
        while (slot < MAX_AGENTS) {
            const obj_start = std.mem.indexOfPos(u8, arr, pos, "{") orelse break;
            const obj_end = jFindObjEnd(arr, obj_start) orelse break;
            const obj = arr[obj_start .. obj_end + 1];

            var a = &agents[slot];
            a.* = .{};
            a.active = true;
            a.id_len = jExtStr(obj, "id", &a.id);
            a.hostname_len = jExtStr(obj, "hostname", &a.hostname);
            a.status_len = jExtStr(obj, "status", &a.status);
            a.paused = jExtBool(obj, "paused");
            a.current_task_id_len = jExtStr(obj, "task_id", &a.current_task_id);
            a.current_branch_len = jExtStr(obj, "branch", &a.current_branch);
            a.last_heartbeat_ms = jExtU64(obj, "hb_ms");
            a.registered_at_ms = jExtU64(obj, "reg_ms");
            a.tasks_completed = jExtU32(obj, "tasks_done");
            a.tasks_failed = jExtU32(obj, "tasks_failed");
            a.no_progress_count = jExtU32(obj, "no_progress");
            a.last_commit_sha_len = jExtStr(obj, "sha", &a.last_commit_sha);

            if (a.id_len == 0) {
                a.active = false;
            } else {
                slot += 1;
            }
            pos = obj_end + 1;
        }
    }

    // Parse tasks
    if (jFindArray(json, "tasks")) |range| {
        const arr = json[range.start..range.end];
        var pos: usize = 0;
        var slot: usize = 0;
        while (slot < MAX_TASKS) {
            const obj_start = std.mem.indexOfPos(u8, arr, pos, "{") orelse break;
            const obj_end = jFindObjEnd(arr, obj_start) orelse break;
            const obj = arr[obj_start .. obj_end + 1];

            var t = &tasks[slot];
            t.* = .{};
            t.active = true;
            t.id_len = jExtStr(obj, "id", &t.id);
            t.slug_len = jExtStr(obj, "slug", &t.slug);
            t.description_len = jExtStr(obj, "desc", &t.description);
            t.priority_len = jExtStr(obj, "priority", &t.priority);
            t.status_len = jExtStr(obj, "status", &t.status);
            t.assigned_to_len = jExtStr(obj, "assigned", &t.assigned_to);
            t.branch_len = jExtStr(obj, "branch", &t.branch);
            t.created_at_ms = jExtU64(obj, "created_ms");
            t.assigned_at_ms = jExtU64(obj, "assigned_ms");
            t.completed_at_ms = jExtU64(obj, "completed_ms");

            if (t.id_len == 0) {
                t.active = false;
            } else {
                slot += 1;
            }
            pos = obj_end + 1;
        }
    }

    // Parse locks
    if (jFindArray(json, "locks")) |range| {
        const arr = json[range.start..range.end];
        var pos: usize = 0;
        var slot: usize = 0;
        while (slot < MAX_LOCKS) {
            const obj_start = std.mem.indexOfPos(u8, arr, pos, "{") orelse break;
            const obj_end = jFindObjEnd(arr, obj_start) orelse break;
            const obj = arr[obj_start .. obj_end + 1];

            var fl = &file_locks[slot];
            fl.* = .{};
            fl.active = true;
            fl.path_len = jExtStr(obj, "path", &fl.path);
            fl.agent_id_len = jExtStr(obj, "agent_id", &fl.agent_id);

            if (fl.path_len == 0) {
                fl.active = false;
            } else {
                slot += 1;
            }
            pos = obj_end + 1;
        }
    }
}

// --- JSON extraction helpers ---

const JRange = struct { start: usize, end: usize };

fn jFindArray(json: []const u8, key: []const u8) ?JRange {
    var search_buf: [64]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":[", .{key}) catch return null;
    const key_pos = std.mem.indexOf(u8, json, search) orelse return null;
    const bracket_pos = key_pos + search.len - 1;
    const arr_end = jFindBracket(json, bracket_pos, '[', ']') orelse return null;
    return JRange{ .start = bracket_pos + 1, .end = arr_end };
}

fn jFindObjEnd(json: []const u8, start: usize) ?usize {
    return jFindBracket(json, start, '{', '}');
}

fn jFindBracket(json: []const u8, start: usize, open: u8, close: u8) ?usize {
    if (start >= json.len or json[start] != open) return null;
    var pos = start + 1;
    var depth: usize = 1;
    var in_string = false;
    var escaped = false;

    while (pos < json.len) : (pos += 1) {
        if (escaped) {
            escaped = false;
            continue;
        }
        const c = json[pos];
        if (c == '\\' and in_string) {
            escaped = true;
            continue;
        }
        if (c == '"') {
            in_string = !in_string;
            continue;
        }
        if (!in_string) {
            if (c == open) depth += 1;
            if (c == close) {
                depth -= 1;
                if (depth == 0) return pos;
            }
        }
    }
    return null;
}

fn jExtStr(obj: []const u8, key: []const u8, out: []u8) usize {
    var search_buf: [64]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":\"", .{key}) catch return 0;
    const start = std.mem.indexOf(u8, obj, search) orelse return 0;
    var pos = start + search.len;
    var idx: usize = 0;

    while (pos < obj.len and idx < out.len) {
        if (obj[pos] == '"') break;
        if (obj[pos] == '\\' and pos + 1 < obj.len) {
            pos += 1;
            switch (obj[pos]) {
                '"' => {
                    out[idx] = '"';
                    idx += 1;
                },
                '\\' => {
                    out[idx] = '\\';
                    idx += 1;
                },
                'n' => {
                    out[idx] = '\n';
                    idx += 1;
                },
                'r' => {
                    out[idx] = '\r';
                    idx += 1;
                },
                't' => {
                    out[idx] = '\t';
                    idx += 1;
                },
                else => {
                    out[idx] = obj[pos];
                    idx += 1;
                },
            }
        } else {
            out[idx] = obj[pos];
            idx += 1;
        }
        pos += 1;
    }
    return idx;
}

fn jExtU64(obj: []const u8, key: []const u8) u64 {
    var search_buf: [64]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":", .{key}) catch return 0;
    const start = std.mem.indexOf(u8, obj, search) orelse return 0;
    var pos = start + search.len;
    while (pos < obj.len and obj[pos] == ' ') pos += 1;
    var end = pos;
    while (end < obj.len and obj[end] >= '0' and obj[end] <= '9') end += 1;
    if (end == pos) return 0;
    return std.fmt.parseInt(u64, obj[pos..end], 10) catch 0;
}

fn jExtU32(obj: []const u8, key: []const u8) u32 {
    const v = jExtU64(obj, key);
    return if (v > std.math.maxInt(u32)) 0 else @intCast(v);
}

fn jExtBool(obj: []const u8, key: []const u8) bool {
    var search_buf: [64]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":", .{key}) catch return false;
    const start = std.mem.indexOf(u8, obj, search) orelse return false;
    const pos = start + search.len;
    if (pos + 4 <= obj.len) {
        return std.mem.eql(u8, obj[pos .. pos + 4], "true");
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MCP TOOL HANDLERS — called from server.zig
// ═══════════════════════════════════════════════════════════════════════════════

/// Format swarm status summary into buffer
pub fn swarmStatus(buf: []u8) []const u8 {
    ensureLoaded();
    var total: u32 = 0;
    var idle: u32 = 0;
    var working: u32 = 0;
    var offline: u32 = 0;
    var err_count: u32 = 0;

    for (&agents) |*a| {
        if (!a.active) continue;
        total += 1;
        const s = a.getStatus();
        if (std.mem.eql(u8, s, "idle") or std.mem.eql(u8, s, "polling")) idle += 1;
        if (std.mem.eql(u8, s, "working")) working += 1;
        if (std.mem.eql(u8, s, "offline") or std.mem.eql(u8, s, "shutdown")) offline += 1;
        if (std.mem.eql(u8, s, "error")) err_count += 1;
    }

    var total_tasks: u32 = 0;
    var pending: u32 = 0;
    for (&tasks) |*t| {
        if (!t.active) continue;
        total_tasks += 1;
        if (std.mem.eql(u8, t.getStatus(), "pending")) pending += 1;
    }

    var offset: usize = 0;
    const swarm_msg = std.fmt.bufPrint(buf,
        \\RALPH SWARM STATUS
        \\
        \\Agents: {d} total ({d} working, {d} idle, {d} offline, {d} error)
        \\Tasks: {d} total ({d} pending)
    , .{ total, working, idle, offline, err_count, total_tasks, pending }) catch return buf[0..0];
    offset = swarm_msg.len;

    // Append GitHub section (graceful: skipped if no token)
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gh = collectGitHubCounts(gpa.allocator());
    if (gh.fetch_ok) {
        const gh_msg = std.fmt.bufPrint(buf[offset..],
            \\
            \\GitHub: {d} open | {d} pending | {d} in-progress
        , .{ gh.open, gh.pending, gh.in_progress }) catch buf[offset..offset];
        offset += gh_msg.len;
    }

    const footer = std.fmt.bufPrint(buf[offset..],
        \\
        \\
        \\phi^2 + 1/phi^2 = 3
    , .{}) catch "";
    offset += footer.len;

    return buf[0..offset];
}

/// Format all agents list
pub fn swarmAgents(buf: []u8) []const u8 {
    ensureLoaded();
    var idx: usize = 0;
    const header = "AGENTS:\n";
    if (idx + header.len < buf.len) {
        @memcpy(buf[idx..][0..header.len], header);
        idx += header.len;
    }

    var count: u32 = 0;
    for (&agents) |*a| {
        if (!a.active) continue;
        count += 1;
        const line = std.fmt.bufPrint(buf[idx..],
            \\{s} {s} [{s}]{s}{s}
            \\
        , .{
            a.statusEmoji(),
            a.getId(),
            a.getStatus(),
            if (a.current_branch_len > 0) " -> " else "",
            if (a.current_branch_len > 0) a.getBranch() else "",
        }) catch break;
        idx += line.len;
    }

    if (count == 0) {
        const none = "No agents registered.\n";
        if (idx + none.len < buf.len) {
            @memcpy(buf[idx..][0..none.len], none);
            idx += none.len;
        }
    }

    return buf[0..idx];
}

/// Register agent from MCP tool call
pub fn swarmRegister(buf: []u8, agent_id: []const u8, hostname: []const u8) []const u8 {
    ensureLoaded();
    defer saveState();
    if (registerAgent(agent_id, hostname)) {
        return std.fmt.bufPrint(buf, "Registered agent: {s}", .{agent_id}) catch buf[0..0];
    }
    return std.fmt.bufPrint(buf, "Error: max agents ({d}) reached", .{MAX_AGENTS}) catch buf[0..0];
}

/// Process heartbeat from MCP tool call
pub fn swarmHeartbeat(buf: []u8, agent_id: []const u8, status: []const u8, branch: []const u8, task_id: []const u8, commit_sha: []const u8) []const u8 {
    ensureLoaded();
    defer saveState();
    const result = heartbeat(agent_id, status, branch, task_id, commit_sha);

    if (!result.ok) {
        return std.fmt.bufPrint(buf, "Error: agent {s} not found and could not register", .{agent_id}) catch buf[0..0];
    }

    if (result.circuit_tripped) {
        return std.fmt.bufPrint(buf, "CIRCUIT_BREAKER_TRIPPED: agent={s} count={d}", .{ agent_id, CIRCUIT_BREAKER_THRESHOLD }) catch buf[0..0];
    }

    if (result.task_completed) {
        return std.fmt.bufPrint(buf, "ok: agent={s} task_completed=true", .{agent_id}) catch buf[0..0];
    }

    if (result.task_failed) {
        return std.fmt.bufPrint(buf, "ok: agent={s} task_failed=true", .{agent_id}) catch buf[0..0];
    }

    return std.fmt.bufPrint(buf, "ok: agent={s} status={s}", .{ agent_id, status }) catch buf[0..0];
}

/// Get next task for agent
pub fn swarmTaskGet(buf: []u8, agent_id: []const u8) []const u8 {
    ensureLoaded();
    defer saveState();
    const task = assignTask(agent_id) orelse {
        return std.fmt.bufPrint(buf, "null", .{}) catch buf[0..0];
    };

    // Build JSON manually — description needs escaping (may contain quotes)
    var idx: usize = 0;
    idx = bufAppend(buf, idx, "{\"id\":\"");
    idx = bufAppend(buf, idx, task.getId());
    idx = bufAppend(buf, idx, "\",\"slug\":\"");
    idx = bufAppend(buf, idx, task.getSlug());
    idx = bufAppend(buf, idx, "\",\"description\":\"");
    idx += bufJsonEscape(buf[idx..], task.getDesc());
    idx = bufAppend(buf, idx, "\",\"priority\":\"");
    idx = bufAppend(buf, idx, task.getPriority());
    idx = bufAppend(buf, idx, "\",\"status\":\"assigned\"}");
    return buf[0..idx];
}

/// Add new task (with GitHub write-through)
pub fn swarmTaskAdd(buf: []u8, id: []const u8, slug_str: []const u8, description: []const u8, priority: []const u8) []const u8 {
    ensureLoaded();
    defer saveState();
    if (id.len > 0) {
        // Task with explicit ID (e.g. gh-27)
        if (addTaskWithId(id, slug_str, description, priority)) {
            return std.fmt.bufPrint(buf, "Task added: id={s} slug={s} priority={s}", .{ id, slug_str, priority }) catch buf[0..0];
        }
        return std.fmt.bufPrint(buf, "Error: task {s} already exists or queue full", .{id}) catch buf[0..0];
    }

    // Auto-generate ID
    if (addTask(slug_str, description, priority)) |tid| {
        // Write-through to GitHub (best-effort, non-blocking on failure)
        // Skip if this is already a gh- task (came from GitHub)
        if (!std.mem.startsWith(u8, tid, "gh-")) {
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            const allocator = gpa.allocator();

            if (createGitHubIssue(allocator, description, slug_str, priority)) |issue_num| {
                // Override task ID to gh-{number} for traceability
                if (findTask(tid)) |t| {
                    var gh_id_buf: [32]u8 = undefined;
                    const gh_id = std.fmt.bufPrint(&gh_id_buf, "gh-{d}", .{issue_num}) catch tid;
                    Task.setStr(&t.id, &t.id_len, gh_id);

                    // Best-effort sub-issue linking
                    linkAsSubIssue(allocator, issue_num);

                    return std.fmt.bufPrint(buf, "Task added: id={s} slug={s} priority={s} (GitHub #{d})", .{ gh_id, slug_str, priority, issue_num }) catch buf[0..0];
                }
            }
        }

        return std.fmt.bufPrint(buf, "Task added: id={s} slug={s} priority={s}", .{ tid, slug_str, priority }) catch buf[0..0];
    }
    return std.fmt.bufPrint(buf, "Error: task queue full (max {d})", .{MAX_TASKS}) catch buf[0..0];
}

/// Cancel task
pub fn swarmTaskCancel(buf: []u8, task_id: []const u8) []const u8 {
    ensureLoaded();
    defer saveState();
    if (cancelTask(task_id)) {
        return std.fmt.bufPrint(buf, "Task cancelled: {s}", .{task_id}) catch buf[0..0];
    }
    return std.fmt.bufPrint(buf, "Error: task {s} not found", .{task_id}) catch buf[0..0];
}

/// List all tasks
pub fn swarmTasks(buf: []u8) []const u8 {
    ensureLoaded();
    var idx: usize = 0;
    const header = "TASKS:\n";
    if (idx + header.len < buf.len) {
        @memcpy(buf[idx..][0..header.len], header);
        idx += header.len;
    }

    var count: u32 = 0;
    for (&tasks) |*t| {
        if (!t.active) continue;
        count += 1;

        // Emoji by status
        const emoji: []const u8 = blk: {
            const s = t.getStatus();
            if (std.mem.eql(u8, s, "pending")) break :blk "🔹";
            if (std.mem.eql(u8, s, "assigned") or std.mem.eql(u8, s, "running")) break :blk "🔷";
            if (std.mem.eql(u8, s, "completed")) break :blk "✅";
            if (std.mem.eql(u8, s, "failed")) break :blk "❌";
            if (std.mem.eql(u8, s, "blocked")) break :blk "🚫";
            break :blk "⬜";
        };

        const line = std.fmt.bufPrint(buf[idx..], "{s} [{s}] {s}: {s}{s}{s}\n", .{
            emoji,
            t.getPriority(),
            t.getSlug(),
            t.getDesc(),
            if (t.assigned_to_len > 0) " -> " else "",
            if (t.assigned_to_len > 0) t.getAssignedTo() else "",
        }) catch break;
        idx += line.len;
    }

    if (count == 0) {
        const none = "Task queue is empty.\n";
        if (idx + none.len < buf.len) {
            @memcpy(buf[idx..][0..none.len], none);
            idx += none.len;
        }
    }

    return buf[0..idx];
}

/// Pause all agents
pub fn swarmPause(buf: []u8) []const u8 {
    ensureLoaded();
    defer saveState();
    var count: u32 = 0;
    for (&agents) |*a| {
        if (!a.active) continue;
        const s = a.getStatus();
        if (std.mem.eql(u8, s, "offline") or std.mem.eql(u8, s, "shutdown")) continue;
        if (!a.paused) {
            a.paused = true;
            count += 1;
        }
    }
    return std.fmt.bufPrint(buf, "Paused {d} agents. Current tasks will finish, no new tasks assigned.", .{count}) catch buf[0..0];
}

/// Resume all agents
pub fn swarmResume(buf: []u8) []const u8 {
    ensureLoaded();
    defer saveState();
    var count: u32 = 0;
    for (&agents) |*a| {
        if (!a.active) continue;
        if (a.paused) {
            a.paused = false;
            resetCircuitBreaker(a);
            count += 1;
        }
    }
    return std.fmt.bufPrint(buf, "Resumed {d} agents.", .{count}) catch buf[0..0];
}

/// Assign task to specific agent (from /assign command)
pub fn swarmAssign(buf: []u8, agent_id: []const u8, description: []const u8) []const u8 {
    ensureLoaded();
    defer saveState();
    // Check agent exists
    if (findAgent(agent_id) == null) {
        return std.fmt.bufPrint(buf, "Error: agent {s} not found", .{agent_id}) catch buf[0..0];
    }

    // Create slug from description
    var slug_buf: [64]u8 = undefined;
    const slug_str = slugify(&slug_buf, description);

    // Add task
    const task_id = addTask(slug_str, description, "P1") orelse {
        return std.fmt.bufPrint(buf, "Error: task queue full", .{}) catch buf[0..0];
    };

    return std.fmt.bufPrint(buf, "Task assigned: agent={s} task={s} slug={s}", .{ agent_id, task_id, slug_str }) catch buf[0..0];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "register and find agent" {
    // Reset state
    agents = [_]Agent{.{}} ** MAX_AGENTS;
    try std.testing.expect(registerAgent("agent-w1", "host-w1"));
    const a = findAgent("agent-w1");
    try std.testing.expect(a != null);
    try std.testing.expectEqualStrings("idle", a.?.getStatus());
}

test "add and find task" {
    tasks = [_]Task{.{}} ** MAX_TASKS;
    id_counter = 0;
    const tid = addTask("fix-bug", "Fix the bug", "P1");
    try std.testing.expect(tid != null);
    const t = findTask(tid.?);
    try std.testing.expect(t != null);
    try std.testing.expectEqualStrings("pending", t.?.getStatus());
}

test "task priority ordering" {
    tasks = [_]Task{.{}} ** MAX_TASKS;
    id_counter = 0;
    _ = addTask("low-task", "Low priority", "P3");
    _ = addTask("critical-task", "Critical", "P0");
    _ = addTask("medium-task", "Medium", "P2");

    const best = nextPendingTask("");
    try std.testing.expect(best != null);
    try std.testing.expectEqualStrings("P0", best.?.getPriority());
}

test "circuit breaker trips at threshold" {
    agents = [_]Agent{.{}} ** MAX_AGENTS;
    try std.testing.expect(registerAgent("agent-cb", ""));
    const a = findAgent("agent-cb").?;
    Agent.setStr(&a.status, &a.status_len, "working");

    // First call sets SHA (no increment), then THRESHOLD more calls increment
    checkProgress(a, "abc123"); // sets SHA, count=0
    var i: u32 = 0;
    while (i < CIRCUIT_BREAKER_THRESHOLD) : (i += 1) {
        checkProgress(a, "abc123"); // same SHA → increment
    }
    try std.testing.expect(isTripped(a));
}

test "circuit breaker resets on new sha" {
    agents = [_]Agent{.{}} ** MAX_AGENTS;
    try std.testing.expect(registerAgent("agent-cr", ""));
    const a = findAgent("agent-cr").?;

    checkProgress(a, "sha1");
    checkProgress(a, "sha1");
    checkProgress(a, "sha1");
    try std.testing.expectEqual(@as(u32, 2), a.no_progress_count); // second+third are no-progress

    checkProgress(a, "sha2"); // new SHA → reset
    try std.testing.expectEqual(@as(u32, 0), a.no_progress_count);
}

test "slugify basic" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("fix-bsd-curves", slugify(&buf, "Fix BSD Curves"));
}

test "slugify special chars" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("fix-the-bsd-curves-verify", slugify(&buf, "Fix: the [BSD] curves & verify!"));
}

test "parse issue number" {
    try std.testing.expectEqual(@as(?u32, 27), parseIssueNumber("gh-27"));
    try std.testing.expectEqual(@as(?u32, null), parseIssueNumber("task-123"));
    try std.testing.expectEqual(@as(?u32, null), parseIssueNumber("gh"));
}

test "extract priority" {
    try std.testing.expectEqualStrings("P0", extractPriority("priority:P0,bug"));
    try std.testing.expectEqualStrings("P2", extractPriority("enhancement,priority:P2"));
    try std.testing.expectEqualStrings("P1", extractPriority("enhancement,agent-system"));
}

test "heartbeat with completion" {
    agents = [_]Agent{.{}} ** MAX_AGENTS;
    tasks = [_]Task{.{}} ** MAX_TASKS;
    id_counter = 0;

    try std.testing.expect(registerAgent("agent-hb", ""));
    const tid = addTask("test-task", "Test task", "P1").?;

    // Assign task
    const a = findAgent("agent-hb").?;
    const t = findTask(tid).?;
    Task.setStr(&t.status, &t.status_len, "assigned");
    Agent.setStr(&a.current_task_id, &a.current_task_id_len, tid);

    // Complete via heartbeat
    const result = heartbeat("agent-hb", "completed", "", "", "");
    try std.testing.expect(result.ok);
    try std.testing.expect(result.task_completed);
    try std.testing.expectEqualStrings("completed", t.getStatus());
}

test "github sync creates task" {
    agents = [_]Agent{.{}} ** MAX_AGENTS;
    tasks = [_]Task{.{}} ** MAX_TASKS;
    file_locks = [_]FileLock{.{}} ** MAX_LOCKS;
    id_counter = 0;
    state_loaded = true;

    var buf: [4096]u8 = undefined;
    const result = swarmGithubSync(&buf, "42", "Fix BSD curves verification", "assign:ralph,priority:P0,bug");
    try std.testing.expect(std.mem.indexOf(u8, result, "\"created\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "gh-42") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "\"priority\":\"P0\"") != null);

    // Task should exist with gh-42 ID
    try std.testing.expect(findTask("gh-42") != null);
}

test "github sync existing task" {
    agents = [_]Agent{.{}} ** MAX_AGENTS;
    tasks = [_]Task{.{}} ** MAX_TASKS;
    file_locks = [_]FileLock{.{}} ** MAX_LOCKS;
    id_counter = 0;
    state_loaded = true;

    var buf: [4096]u8 = undefined;
    _ = swarmGithubSync(&buf, "99", "Some task", "assign:ralph");
    // Second sync of same issue should return exists=true
    const result2 = swarmGithubSync(&buf, "99", "Some task", "assign:ralph");
    try std.testing.expect(std.mem.indexOf(u8, result2, "\"exists\":true") != null);
}

test "github on_start returns instructions" {
    var buf: [4096]u8 = undefined;
    const result = swarmGithubOnStart(&buf, "gh-27", "agent-w1", "ralph/fix-bsd");
    try std.testing.expect(std.mem.indexOf(u8, result, "\"issue\":27") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "status:in-progress") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "agent-w1") != null);
}

test "github on_start skips non-gh task" {
    var buf: [4096]u8 = undefined;
    const result = swarmGithubOnStart(&buf, "task-123", "agent-w1", "branch");
    try std.testing.expect(std.mem.indexOf(u8, result, "\"skip\":true") != null);
}

test "github on_complete returns close instruction" {
    var buf: [4096]u8 = undefined;
    const result = swarmGithubOnComplete(&buf, "gh-15", "agent-w2", "All tests pass, PR merged");
    try std.testing.expect(std.mem.indexOf(u8, result, "\"issue\":15") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "\"close_issue\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "status:completed") != null);
}

test "github on_fail returns error comment" {
    var buf: [4096]u8 = undefined;
    const result = swarmGithubOnFail(&buf, "gh-8", "agent-w1", "Build failed: 3 errors");
    try std.testing.expect(std.mem.indexOf(u8, result, "\"issue\":8") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "status:failed") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Build failed") != null);
}

test "createGitHubIssue returns null without token" {
    // No GH_TOKEN in test env → returns null
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const result = createGitHubIssue(gpa.allocator(), "test title", "test body", "P1");
    try std.testing.expectEqual(@as(?u32, null), result);
}

test "swarmTaskAdd still works without GitHub" {
    agents = [_]Agent{.{}} ** MAX_AGENTS;
    tasks = [_]Task{.{}} ** MAX_TASKS;
    file_locks = [_]FileLock{.{}} ** MAX_LOCKS;
    id_counter = 0;
    state_loaded = true;

    var buf: [4096]u8 = undefined;
    const result = swarmTaskAdd(&buf, "", "test-slug", "Test description", "P2");
    // Should succeed in-memory even without GitHub
    try std.testing.expect(std.mem.indexOf(u8, result, "Task added") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "P2") != null);
}

test "countLabelOccurrences" {
    const body = "\"status:pending\" foo \"status:pending\" bar";
    try std.testing.expectEqual(@as(u32, 2), countLabelOccurrences(body, "\"status:pending\""));
    try std.testing.expectEqual(@as(u32, 0), countLabelOccurrences(body, "\"status:failed\""));
}

test "extractNodeId" {
    const resp =
        \\{"data":{"repository":{"parent":{"id":"I_abc123"},"child":{"id":"I_def456"}}}}
    ;
    const parent_id = extractNodeId(resp, "parent");
    try std.testing.expect(parent_id != null);
    try std.testing.expectEqualStrings("I_abc123", parent_id.?);

    const child_id = extractNodeId(resp, "child");
    try std.testing.expect(child_id != null);
    try std.testing.expectEqualStrings("I_def456", child_id.?);

    const missing = extractNodeId(resp, "other");
    try std.testing.expectEqual(@as(?[]const u8, null), missing);
}

test "assign task to agent" {
    agents = [_]Agent{.{}} ** MAX_AGENTS;
    tasks = [_]Task{.{}} ** MAX_TASKS;
    id_counter = 0;

    try std.testing.expect(registerAgent("agent-at", ""));
    _ = addTask("test-assign", "Test assignment", "P1");

    const task = assignTask("agent-at");
    try std.testing.expect(task != null);
    try std.testing.expectEqualStrings("assigned", task.?.getStatus());
}
