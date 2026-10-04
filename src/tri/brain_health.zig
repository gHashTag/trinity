//! `tri stress --health` -- brain self-check probes.
//!
//! WHAT THE SCORE MEANS
//!
//!   Score = 100 * passed / total, over the probes in `probes` below and
//!   nothing else. There is no weighting, no baseline and no constant: a
//!   probe passes only if every assertion inside it held on this run.
//!
//!   Each probe drives real behaviour of one of the three brain regions that
//!   are linked into `tri` (see build.zig, `tri` module imports):
//!
//!     basal_ganglia        task claim registry (claim, heartbeat, complete,
//!                          abandon, TTL expiry, shard accounting, races)
//!     reticular_formation  event bus (ownership of strings, FIFO order,
//!                          `since` filter, `max_events` limit, bounded ring)
//!     locus_coeruleus      retry backoff (exponential, cap, linear, constant,
//!                          jitter bounds)
//!
//!   Probes build fresh private instances. They never touch the process-wide
//!   singletons (`getGlobal`), so the score does not depend on what else the
//!   process has done. Every probe runs on its own leak-checking allocator
//!   (`std.heap.DebugAllocator`); a probe that leaks is counted as failed even
//!   if all its assertions held.
//!
//! WHAT IT DOES NOT COVER
//!
//!   - The other regions under src/brain/ (they are not linked into `tri`, so
//!     a probe here could only test a copy, not the shipped code).
//!   - Load, soak or throughput behaviour. The one concurrent probe checks
//!     correctness of a claim race, not speed.
//!
//! OUTPUT CONTRACT (read by .github/workflows/brain-ci.yml)
//!
//!   Exactly one line starts with `Score: `, is plain ASCII with no colour
//!   codes, and has the form `Score: <n.n>/100 (<passed> of <total> probes passed)`.
//!   The last line is `Status: HEALTHY` when every probe passed and
//!   `Status: UNHEALTHY` otherwise. The process exits 1 when any probe failed.

const std = @import("std");
const basal_ganglia = @import("basal_ganglia");
const reticular_formation = @import("reticular_formation");
const locus_coeruleus = @import("locus_coeruleus");

const Registry = basal_ganglia.Registry;
const EventBus = reticular_formation.EventBus;
const BackoffPolicy = locus_coeruleus.BackoffPolicy;

const Probe = struct {
    region: []const u8,
    name: []const u8,
    /// One line: the property the probe asserts.
    claim: []const u8,
    run: *const fn (std.mem.Allocator) anyerror!void,
};

/// The complete list of probes. The score is computed over this list only.
const probes = [_]Probe{
    .{ .region = "basal_ganglia", .name = "claim-free-task", .claim = "an unclaimed task can be claimed and reads back as owned by that agent", .run = &bgClaimFreeTask },
    .{ .region = "basal_ganglia", .name = "refuse-second-claimant", .claim = "a live claim refuses a second agent and counts the conflict", .run = &bgRefuseSecondClaimant },
    .{ .region = "basal_ganglia", .name = "heartbeat-owner-only", .claim = "only the owner can heartbeat a claim; unknown tasks cannot be heartbeated", .run = &bgHeartbeatOwnerOnly },
    .{ .region = "basal_ganglia", .name = "complete-releases", .claim = "completion is owner-only and frees the task for another agent", .run = &bgCompleteReleases },
    .{ .region = "basal_ganglia", .name = "abandon-releases", .claim = "abandoning is owner-only and frees the task for another agent", .run = &bgAbandonReleases },
    .{ .region = "basal_ganglia", .name = "ttl-expiry", .claim = "a claim past its TTL is invalid and cleanupExpired removes only it", .run = &bgTtlExpiry },
    .{ .region = "basal_ganglia", .name = "shard-accounting", .claim = "64 claims are all visible via count, getShardStats and listClaims", .run = &bgShardAccounting },
    .{ .region = "basal_ganglia", .name = "one-winner-per-task", .claim = "8 threads racing for 16 tasks yield exactly one winner per task", .run = &bgOneWinnerPerTask },
    .{ .region = "reticular_formation", .name = "owns-published-strings", .claim = "an event polls back intact after the publisher's buffers are overwritten", .run = &rfOwnsPublishedStrings },
    .{ .region = "reticular_formation", .name = "fifo-order", .claim = "publish and publishBatch events poll back oldest-first in order", .run = &rfFifoOrder },
    .{ .region = "reticular_formation", .name = "since-filter", .claim = "poll(since) returns only events stamped after since", .run = &rfSinceFilter },
    .{ .region = "reticular_formation", .name = "limit-after-filter", .claim = "max_events caps the events that pass the since filter, not the events scanned", .run = &rfLimitAfterFilter },
    .{ .region = "reticular_formation", .name = "bounded-ring", .claim = "capacity+7 publishes keep capacity events, evict the 7 oldest, count them", .run = &rfBoundedRing },
    .{ .region = "locus_coeruleus", .name = "exponential-doubling", .claim = "default policy waits 1000 ms, doubles per attempt, stops at 60000 ms", .run = &lcExponentialDoubling },
    .{ .region = "locus_coeruleus", .name = "capped-and-monotone", .claim = "delays never decrease or exceed max_ms over attempts 0..63 (table and computed paths)", .run = &lcCappedAndMonotone },
    .{ .region = "locus_coeruleus", .name = "linear-and-constant", .claim = "linear adds linear_increment per attempt, constant never changes, both capped", .run = &lcLinearAndConstant },
    .{ .region = "locus_coeruleus", .name = "jitter-bounds", .claim = "uniform jitter stays in [base, 2*base); phi jitter is base*0.618 or base*1.618", .run = &lcJitterBounds },
};

const regions = [_][]const u8{ "basal_ganglia", "reticular_formation", "locus_coeruleus" };

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

var note_buf: [256]u8 = undefined;
var note: []const u8 = "";

/// Fails the current probe with a note explaining what was observed.
fn check(ok: bool, comptime fmt: []const u8, args: anytype) error{ProbeFailed}!void {
    if (ok) return;
    note = std.fmt.bufPrint(&note_buf, fmt, args) catch "(failure note too long)";
    return error.ProbeFailed;
}

const Outcome = struct {
    passed: bool,
    detail: []const u8,
};

fn runProbe(p: Probe, detail_buf: []u8) Outcome {
    note = "";
    var dbg: std.heap.DebugAllocator(.{}) = .init;
    const result = p.run(dbg.allocator());
    const leaked = dbg.deinit() == .leak;

    if (result) |_| {
        if (leaked) return .{ .passed = false, .detail = "leaked memory (see allocator report on stderr)" };
        return .{ .passed = true, .detail = "" };
    } else |err| {
        const detail = if (err == error.ProbeFailed)
            note
        else
            std.fmt.bufPrint(detail_buf, "error.{s}", .{@errorName(err)}) catch "error";
        return .{ .passed = false, .detail = detail };
    }
}

/// Runs every probe, prints the report and exits 1 if any probe failed.
pub fn run() !void {
    var out_buf: [4096]u8 = undefined;
    var file_writer = std.fs.File.stdout().writer(&out_buf);
    const out = &file_writer.interface;

    try out.print(
        \\Brain health -- tri stress --health
        \\Probes drive the brain regions linked into tri, on fresh private instances,
        \\each on its own leak-checking allocator (a leak fails the probe).
        \\The score is 100 * passed / total over the probes listed below.
        \\
        \\
    , .{});
    try out.flush();

    var passed: usize = 0;
    var region_passed = [_]usize{0} ** regions.len;
    var region_total = [_]usize{0} ** regions.len;

    for (probes) |p| {
        var detail_buf: [128]u8 = undefined;
        const outcome = runProbe(p, &detail_buf);
        if (outcome.passed) passed += 1;
        for (regions, 0..) |r, i| {
            if (std.mem.eql(u8, r, p.region)) {
                region_total[i] += 1;
                if (outcome.passed) region_passed[i] += 1;
            }
        }
        try out.print("  {s}  {s:<20} {s:<23} {s}\n", .{
            if (outcome.passed) "PASS" else "FAIL",
            p.region,
            p.name,
            p.claim,
        });
        if (!outcome.passed) try out.print("        -> {s}\n", .{outcome.detail});
        try out.flush();
    }

    const total = probes.len;
    const score = 100.0 * @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(total));

    try out.print("\nPassed: {d}/{d} probes (", .{ passed, total });
    for (regions, 0..) |r, i| {
        if (i > 0) try out.print(", ", .{});
        try out.print("{s} {d}/{d}", .{ r, region_passed[i], region_total[i] });
    }
    try out.print(")\n", .{});
    try out.print("Not covered: other src/brain regions (not linked into tri); load and soak behaviour.\n", .{});
    try out.print("Score: {d:.1}/100 ({d} of {d} probes passed)\n", .{ score, passed, total });
    try out.print("Status: {s}\n", .{if (passed == total) "HEALTHY" else "UNHEALTHY"});
    try out.flush();

    if (passed != total) std.process.exit(1);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Blocks until the millisecond clock has moved past `t`.
fn waitPastMs(t: i64) void {
    while (std.time.milliTimestamp() <= t) std.Thread.sleep(std.time.ns_per_ms / 4);
}

fn newBus(a: std.mem.Allocator) !*EventBus {
    const bus = try a.create(EventBus);
    bus.* = EventBus.init(a);
    return bus;
}

fn freeBus(a: std.mem.Allocator, bus: *EventBus) void {
    bus.deinit();
    a.destroy(bus);
}

/// True when `task_id` is listed with `agent_id` as its owner.
fn ownedBy(reg: *Registry, a: std.mem.Allocator, task_id: []const u8, agent_id: []const u8) !bool {
    const claims = try reg.listClaims(a);
    defer reg.freeClaims(a, claims);
    for (claims) |c| {
        if (std.mem.eql(u8, c.task_id, task_id)) return std.mem.eql(u8, c.agent_id, agent_id);
    }
    return false;
}

// ---------------------------------------------------------------------------
// basal_ganglia probes
// ---------------------------------------------------------------------------

fn bgClaimFreeTask(a: std.mem.Allocator) !void {
    var reg = Registry.init(a);
    defer reg.deinit();

    try check(reg.checkClaim("t1") == .not_found, "fresh registry reports t1 as {s}", .{@tagName(reg.checkClaim("t1"))});
    try check(try reg.claim(a, "t1", "agent-a", 60_000), "claim of a free task returned false", .{});
    try check(reg.checkClaim("t1") == .claimed, "after claim, t1 is {s}", .{@tagName(reg.checkClaim("t1"))});
    try check(try ownedBy(&reg, a, "t1", "agent-a"), "t1 is not listed as owned by agent-a", .{});
    try check(reg.checkClaim("t-other") == .not_found, "an unclaimed task reads as {s}", .{@tagName(reg.checkClaim("t-other"))});
}

fn bgRefuseSecondClaimant(a: std.mem.Allocator) !void {
    var reg = Registry.init(a);
    defer reg.deinit();

    try check(try reg.claim(a, "t1", "agent-a", 60_000), "first claim returned false", .{});
    try check(!(try reg.claim(a, "t1", "agent-b", 60_000)), "second agent took a live claim", .{});
    try check(try ownedBy(&reg, a, "t1", "agent-a"), "after the refused claim t1 is not owned by agent-a", .{});
    const s = reg.getStats();
    try check(s.claim_attempts == 2 and s.claim_success == 1 and s.claim_conflicts == 1, "stats attempts={d} success={d} conflicts={d}, want 2/1/1", .{ s.claim_attempts, s.claim_success, s.claim_conflicts });
}

fn bgHeartbeatOwnerOnly(a: std.mem.Allocator) !void {
    var reg = Registry.init(a);
    defer reg.deinit();

    try check(try reg.claim(a, "t1", "agent-a", 60_000), "claim returned false", .{});
    try check(!reg.heartbeat("t1", "agent-b"), "a non-owner heartbeat was accepted", .{});
    try check(reg.heartbeat("t1", "agent-a"), "the owner's heartbeat was refused", .{});
    try check(!reg.heartbeat("t-missing", "agent-a"), "a heartbeat on an unknown task was accepted", .{});
    const s = reg.getStats();
    try check(s.heartbeat_calls == 3 and s.heartbeat_success == 1, "heartbeat stats calls={d} success={d}, want 3/1", .{ s.heartbeat_calls, s.heartbeat_success });
}

fn bgCompleteReleases(a: std.mem.Allocator) !void {
    var reg = Registry.init(a);
    defer reg.deinit();

    try check(try reg.claim(a, "t1", "agent-a", 60_000), "claim returned false", .{});
    try check(!reg.complete("t1", "agent-b"), "a non-owner completed the task", .{});
    try check(reg.complete("t1", "agent-a"), "the owner could not complete the task", .{});
    try check(reg.checkClaim("t1") == .expired, "after completion t1 is {s}, want expired", .{@tagName(reg.checkClaim("t1"))});
    try check(!reg.complete("t1", "agent-a"), "a completed task was completed twice", .{});
    try check(try reg.claim(a, "t1", "agent-b", 60_000), "another agent could not claim a completed task", .{});
    try check(reg.checkClaim("t1") == .claimed, "after re-claim t1 is {s}", .{@tagName(reg.checkClaim("t1"))});
}

fn bgAbandonReleases(a: std.mem.Allocator) !void {
    var reg = Registry.init(a);
    defer reg.deinit();

    try check(try reg.claim(a, "t1", "agent-a", 60_000), "claim returned false", .{});
    try check(!reg.abandon("t1", "agent-b"), "a non-owner abandoned the task", .{});
    try check(reg.abandon("t1", "agent-a"), "the owner could not abandon the task", .{});
    try check(reg.checkClaim("t1") == .expired, "after abandon t1 is {s}, want expired", .{@tagName(reg.checkClaim("t1"))});
    try check(try reg.claim(a, "t1", "agent-b", 60_000), "another agent could not claim an abandoned task", .{});
    try check(try ownedBy(&reg, a, "t1", "agent-b"), "after re-claim t1 is not owned by agent-b", .{});
}

fn bgTtlExpiry(a: std.mem.Allocator) !void {
    var reg = Registry.init(a);
    defer reg.deinit();

    try check(try reg.claim(a, "short", "agent-a", 1), "claim with ttl 1 ms returned false", .{});
    try check(try reg.claim(a, "long", "agent-a", 60_000), "claim with ttl 60 s returned false", .{});
    const start = std.time.milliTimestamp();
    waitPastMs(start + 3);
    try check(reg.checkClaim("short") == .expired, "a claim 3 ms past a 1 ms TTL is {s}", .{@tagName(reg.checkClaim("short"))});
    try check(reg.checkClaim("long") == .claimed, "a 60 s claim is {s} after 3 ms", .{@tagName(reg.checkClaim("long"))});
    const removed = reg.cleanupExpired();
    try check(removed == 1, "cleanupExpired removed {d}, want 1", .{removed});
    try check(reg.count() == 1, "count after cleanup is {d}, want 1", .{reg.count()});
}

fn bgShardAccounting(a: std.mem.Allocator) !void {
    var reg = Registry.init(a);
    defer reg.deinit();

    const n = 64;
    var buf: [32]u8 = undefined;
    for (0..n) |i| {
        const id = try std.fmt.bufPrint(&buf, "shard-task-{d}", .{i});
        try check(try reg.claim(a, id, "agent-a", 60_000), "claim of {s} returned false", .{id});
    }
    try check(reg.count() == n, "count is {d}, want {d}", .{ reg.count(), n });

    const per_shard = reg.getShardStats();
    var sum: usize = 0;
    var used: usize = 0;
    for (per_shard) |c| {
        sum += c;
        if (c > 0) used += 1;
    }
    try check(sum == n, "shard stats sum to {d}, want {d}", .{ sum, n });
    try check(used > 1, "all {d} claims landed in one shard", .{n});

    const claims = try reg.listClaims(a);
    defer reg.freeClaims(a, claims);
    try check(claims.len == n, "listClaims returned {d}, want {d}", .{ claims.len, n });
    for (claims) |c| try check(c.is_valid, "listed claim {s} is not valid", .{c.task_id});
}

const race_threads = 8;
const race_tasks = 16;

const RaceShared = struct {
    reg: *Registry,
    alloc: std.mem.Allocator,
    go: std.atomic.Value(bool) = .init(false),
    errored: std.atomic.Value(bool) = .init(false),
    wins: [race_tasks]std.atomic.Value(u32) = [_]std.atomic.Value(u32){.init(0)} ** race_tasks,
};

fn raceWorker(shared: *RaceShared, agent_index: usize) void {
    var agent_buf: [32]u8 = undefined;
    const agent = std.fmt.bufPrint(&agent_buf, "racer-{d}", .{agent_index}) catch unreachable;
    while (!shared.go.load(.acquire)) std.atomic.spinLoopHint();
    var task_buf: [32]u8 = undefined;
    for (0..race_tasks) |k| {
        // Each racer walks the tasks from a different start, so claims collide.
        const t = (k + agent_index) % race_tasks;
        const task = std.fmt.bufPrint(&task_buf, "race-{d}", .{t}) catch unreachable;
        const won = shared.reg.claim(shared.alloc, task, agent, 60_000) catch {
            shared.errored.store(true, .release);
            return;
        };
        if (won) _ = shared.wins[t].fetchAdd(1, .acq_rel);
    }
}

fn bgOneWinnerPerTask(a: std.mem.Allocator) !void {
    var reg = Registry.init(a);
    defer reg.deinit();

    var shared = RaceShared{ .reg = &reg, .alloc = a };
    var threads: [race_threads]std.Thread = undefined;
    var spawned: usize = 0;
    defer {
        shared.go.store(true, .release);
        for (threads[0..spawned]) |th| th.join();
    }
    for (0..race_threads) |i| {
        threads[i] = try std.Thread.spawn(.{}, raceWorker, .{ &shared, i });
        spawned += 1;
    }
    shared.go.store(true, .release);
    for (threads[0..spawned]) |th| th.join();
    spawned = 0;

    try check(!shared.errored.load(.acquire), "a racer got an error from claim()", .{});
    var total: u32 = 0;
    for (&shared.wins, 0..) |*w, t| {
        const v = w.load(.acquire);
        total += v;
        try check(v == 1, "task race-{d} had {d} winners, want exactly 1", .{ t, v });
    }
    try check(total == race_tasks, "{d} wins over {d} tasks", .{ total, race_tasks });
    try check(reg.count() == race_tasks, "registry holds {d} claims, want {d}", .{ reg.count(), race_tasks });
    const s = reg.getStats();
    const attempts: u64 = race_threads * race_tasks;
    try check(s.claim_attempts == attempts and s.claim_success == race_tasks and s.claim_conflicts == attempts - race_tasks, "stats attempts={d} success={d} conflicts={d}, want {d}/{d}/{d}", .{ s.claim_attempts, s.claim_success, s.claim_conflicts, attempts, race_tasks, attempts - race_tasks });
}

// ---------------------------------------------------------------------------
// reticular_formation probes
// ---------------------------------------------------------------------------

fn rfOwnsPublishedStrings(a: std.mem.Allocator) !void {
    const bus = try newBus(a);
    defer freeBus(a, bus);

    var task_buf = "task-77".*;
    var agent_buf = "agent-a".*;
    var err_buf = "disk full".*;
    try bus.publish(.task_failed, .{ .task_failed = .{ .task_id = &task_buf, .agent_id = &agent_buf, .err_msg = &err_buf } });
    @memset(&task_buf, 'X');
    @memset(&agent_buf, 'X');
    @memset(&err_buf, 'X');

    const events = try bus.poll(0, a, 0);
    defer a.free(events);
    try check(events.len == 1, "poll returned {d} events, want 1", .{events.len});
    try check(events[0].event_type == .task_failed, "event type is {s}", .{@tagName(events[0].event_type)});
    const d = events[0].data.task_failed;
    try check(std.mem.eql(u8, d.task_id, "task-77"), "task_id reads back as '{s}'", .{d.task_id});
    try check(std.mem.eql(u8, d.agent_id, "agent-a"), "agent_id reads back as '{s}'", .{d.agent_id});
    try check(std.mem.eql(u8, d.err_msg, "disk full"), "err_msg reads back as '{s}'", .{d.err_msg});
}

fn rfFifoOrder(a: std.mem.Allocator) !void {
    const bus = try newBus(a);
    defer freeBus(a, bus);

    for (0..5) |i| try bus.publish(.agent_idle, .{ .agent_idle = .{ .agent_id = "agent-a", .idle_ms = i } });
    var batch: [3]EventBus.BatchEvent = undefined;
    for (&batch, 0..) |*b, i| b.* = .{ .event_type = .agent_idle, .data = .{ .agent_idle = .{ .agent_id = "agent-a", .idle_ms = 5 + i } } };
    try bus.publishBatch(&batch);

    const events = try bus.poll(0, a, 0);
    defer a.free(events);
    try check(events.len == 8, "poll returned {d} events, want 8", .{events.len});
    for (events, 0..) |e, i| {
        try check(e.data.agent_idle.idle_ms == i, "position {d} holds event {d}", .{ i, e.data.agent_idle.idle_ms });
    }
}

/// Publishes 3 "old" events, waits for the clock to tick, publishes 2 "new"
/// ones and returns the timestamp that separates them.
fn publishOldThenNew(bus: *EventBus) !i64 {
    for (0..3) |_| try bus.publish(.agent_spawned, .{ .agent_spawned = .{ .agent_id = "old" } });
    const boundary = std.time.milliTimestamp();
    waitPastMs(boundary);
    for (0..2) |_| try bus.publish(.agent_spawned, .{ .agent_spawned = .{ .agent_id = "new" } });
    return boundary;
}

fn rfSinceFilter(a: std.mem.Allocator) !void {
    const bus = try newBus(a);
    defer freeBus(a, bus);
    const boundary = try publishOldThenNew(bus);

    const newer = try bus.poll(boundary, a, 0);
    defer a.free(newer);
    try check(newer.len == 2, "poll(since=boundary) returned {d} events, want 2", .{newer.len});
    for (newer) |e| try check(std.mem.eql(u8, e.data.agent_spawned.agent_id, "new"), "poll(since) returned an event older than since", .{});

    const all = try bus.poll(0, a, 0);
    defer a.free(all);
    try check(all.len == 5, "poll(since=0) returned {d} events, want 5", .{all.len});

    const none = try bus.poll(std.time.milliTimestamp() + 60_000, a, 0);
    defer a.free(none);
    try check(none.len == 0, "poll(since=future) returned {d} events, want 0", .{none.len});
}

fn rfLimitAfterFilter(a: std.mem.Allocator) !void {
    const bus = try newBus(a);
    defer freeBus(a, bus);
    const boundary = try publishOldThenNew(bus);

    const first_two = try bus.poll(0, a, 2);
    defer a.free(first_two);
    try check(first_two.len == 2, "poll(since=0, max=2) returned {d} events, want 2", .{first_two.len});
    for (first_two) |e| try check(std.mem.eql(u8, e.data.agent_spawned.agent_id, "old"), "poll(max=2) did not return the two oldest events", .{});

    const one_new = try bus.poll(boundary, a, 1);
    defer a.free(one_new);
    try check(one_new.len == 1, "poll(since=boundary, max=1) returned {d} events, want 1 (2 events match)", .{one_new.len});
    try check(std.mem.eql(u8, one_new[0].data.agent_spawned.agent_id, "new"), "poll(since, max=1) returned an event older than since", .{});
}

fn rfBoundedRing(a: std.mem.Allocator) !void {
    const bus = try newBus(a);
    defer freeBus(a, bus);

    const cap = bus.buffer.len;
    const extra = 7;
    for (0..cap + extra) |i| try bus.publish(.agent_idle, .{ .agent_idle = .{ .agent_id = "agent-a", .idle_ms = i } });

    const s = bus.getStats();
    try check(s.buffered == cap, "buffered {d}, want capacity {d}", .{ s.buffered, cap });
    try check(s.published == cap + extra, "published {d}, want {d}", .{ s.published, cap + extra });
    try check(s.trim_count == extra, "trim_count {d}, want {d}", .{ s.trim_count, extra });
    try check(s.peak_buffered == cap, "peak_buffered {d}, want {d}", .{ s.peak_buffered, cap });

    const events = try bus.poll(0, a, 0);
    defer a.free(events);
    try check(events.len == cap, "poll returned {d} events, want {d}", .{ events.len, cap });
    try check(events[0].data.agent_idle.idle_ms == extra, "oldest kept event is {d}, want {d}", .{ events[0].data.agent_idle.idle_ms, extra });
    try check(events[cap - 1].data.agent_idle.idle_ms == cap + extra - 1, "newest event is {d}, want {d}", .{ events[cap - 1].data.agent_idle.idle_ms, cap + extra - 1 });
}

// ---------------------------------------------------------------------------
// locus_coeruleus probes
// ---------------------------------------------------------------------------

fn lcExponentialDoubling(a: std.mem.Allocator) !void {
    _ = a;
    const policy = BackoffPolicy.init();
    const want = [_]u64{ 1000, 2000, 4000, 8000, 16000, 32000, 60000, 60000, 60000 };
    for (want, 0..) |w, attempt| {
        const got = policy.nextDelay(@intCast(attempt));
        try check(got == w, "attempt {d}: delay {d} ms, want {d} ms", .{ attempt, got, w });
    }
}

fn expectCappedMonotone(policy: BackoffPolicy, label: []const u8) !void {
    var prev: u64 = 0;
    for (0..64) |attempt| {
        const got = policy.nextDelay(@intCast(attempt));
        try check(got <= policy.max_ms, "{s} attempt {d}: {d} ms exceeds max {d}", .{ label, attempt, got, policy.max_ms });
        try check(got >= prev, "{s} attempt {d}: {d} ms is below previous {d}", .{ label, attempt, got, prev });
        prev = got;
    }
}

fn lcCappedAndMonotone(a: std.mem.Allocator) !void {
    _ = a;
    try expectCappedMonotone(BackoffPolicy.init(), "default");

    // Non-default parameters bypass the lookup table and take the computed path.
    const custom = BackoffPolicy{ .initial_ms = 250, .multiplier = 3.0, .max_ms = 90_000 };
    try check(custom.nextDelay(0) == 250, "custom attempt 0: {d} ms, want 250", .{custom.nextDelay(0)});
    try check(custom.nextDelay(1) == 750, "custom attempt 1: {d} ms, want 750", .{custom.nextDelay(1)});
    try expectCappedMonotone(custom, "custom");
}

fn lcLinearAndConstant(a: std.mem.Allocator) !void {
    _ = a;
    const linear = BackoffPolicy{ .strategy = .linear };
    try check(linear.nextDelay(0) == 1000, "linear attempt 0: {d} ms, want 1000", .{linear.nextDelay(0)});
    try check(linear.nextDelay(4) == 5000, "linear attempt 4: {d} ms, want 5000", .{linear.nextDelay(4)});
    try check(linear.nextDelay(100) == 60000, "linear attempt 100: {d} ms, want cap 60000", .{linear.nextDelay(100)});

    const constant = BackoffPolicy{ .strategy = .constant, .initial_ms = 1500 };
    for ([_]u32{ 0, 9, 40 }) |attempt| {
        const got = constant.nextDelay(attempt);
        try check(got == 1500, "constant attempt {d}: {d} ms, want 1500", .{ attempt, got });
    }
}

fn lcJitterBounds(a: std.mem.Allocator) !void {
    _ = a;
    const uniform = BackoffPolicy{ .jitter_type = .uniform };
    const phi = BackoffPolicy{ .jitter_type = .phi_weighted };
    for (0..200) |_| {
        const u = uniform.nextDelay(0);
        try check(u >= 1000 and u < 2000, "uniform jitter on 1000 ms gave {d} ms, want [1000, 2000)", .{u});
        const p = phi.nextDelay(0);
        try check(p == 618 or p == 1618, "phi jitter on 1000 ms gave {d} ms, want 618 or 1618", .{p});
    }
    // Jitter is applied before the cap: a large base must still respect max_ms.
    const capped = uniform.nextDelay(10);
    try check(capped <= uniform.max_ms, "uniform jitter at attempt 10 gave {d} ms, above max {d}", .{ capped, uniform.max_ms });
}
