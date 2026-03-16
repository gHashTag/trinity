// @origin(manual) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// ARENA BATTLE — Battle Orchestration Engine
// ═══════════════════════════════════════════════════════════════════════════════
//
// Manages battle lifecycle: create → run fighters → collect responses → judge
// Stores results to JSONL, updates ELO ratings
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("types.zig");
const elo = @import("elo.zig");
const external_api = @import("external_api.zig");
const judge_mod = @import("judge.zig");
const tasks = @import("tasks.zig");
const Allocator = std.mem.Allocator;

const RESULTS_PATH = "data/arena/arena_results.jsonl";
const LEADERBOARD_PATH = "data/arena/leaderboard.json";

/// Arena state — holds all battles and fighters
pub const Arena = struct {
    allocator: Allocator,
    fighters: [types.MAX_FIGHTERS]types.StoredFighter = [_]types.StoredFighter{.{}} ** types.MAX_FIGHTERS,
    fighter_count: usize = 0,
    next_battle_id: u64 = 1,
    total_battles: u32 = 0,

    pub fn init(allocator: Allocator) Arena {
        var arena = Arena{ .allocator = allocator };
        // Register default fighters
        arena.registerFighter("trinity-hslm", .trinity, "hslm-1.95M", null);
        arena.registerFighter("echo", .echo, null, null);
        return arena;
    }

    /// Register a new fighter
    pub fn registerFighter(
        self: *Arena,
        name: []const u8,
        kind: types.FighterKind,
        model: ?[]const u8,
        _: ?[]const u8,
    ) void {
        if (self.fighter_count >= types.MAX_FIGHTERS) return;

        // Check for duplicate
        for (self.fighters[0..self.fighter_count]) |*f| {
            if (f.active and std.mem.eql(u8, f.getName(), name)) return;
        }

        var fighter = &self.fighters[self.fighter_count];
        fighter.setName(name);
        fighter.kind = kind;
        if (model) |m| fighter.setModel(m);
        fighter.active = true;
        fighter.elo = 1000.0;
        self.fighter_count += 1;
    }

    /// Find a fighter by name
    pub fn findFighter(self: *Arena, name: []const u8) ?*types.StoredFighter {
        for (self.fighters[0..self.fighter_count]) |*f| {
            if (f.active and std.mem.eql(u8, f.getName(), name)) return f;
        }
        return null;
    }

    /// Create and run a battle
    pub fn runBattle(
        self: *Arena,
        task: types.Task,
        fighter_a_name: []const u8,
        fighter_b_name: []const u8,
        auto_judge: bool,
    ) !types.Battle {
        const fighter_a = self.findFighter(fighter_a_name) orelse return error.FighterNotFound;
        const fighter_b = self.findFighter(fighter_b_name) orelse return error.FighterNotFound;

        var battle = types.Battle{
            .id = self.next_battle_id,
            .task = task,
            .fighter_a = fighter_a_name,
            .fighter_b = fighter_b_name,
            .status = .running,
            .created_at = std.time.timestamp(),
        };
        self.next_battle_id += 1;

        // Run fighter A
        const result_a = external_api.complete(
            self.allocator,
            fighter_a.kind,
            fighter_a.getModel(),
            fighter_a.getEndpoint(),
            task.prompt,
        ) catch {
            battle.response_a = "(error)";
            battle.latency_a_ms = 0;
            battle.status = .complete;
            return battle;
        };
        battle.response_a = result_a.response;
        battle.latency_a_ms = result_a.latency_ms;

        // Run fighter B
        const result_b = external_api.complete(
            self.allocator,
            fighter_b.kind,
            fighter_b.getModel(),
            fighter_b.getEndpoint(),
            task.prompt,
        ) catch {
            battle.response_b = "(error)";
            battle.latency_b_ms = 0;
            battle.status = .complete;
            return battle;
        };
        battle.response_b = result_b.response;
        battle.latency_b_ms = result_b.latency_ms;

        battle.status = .complete;
        battle.completed_at = std.time.timestamp();

        // Auto-judge if requested
        if (auto_judge) {
            if (battle.response_a != null and battle.response_b != null) {
                const judge_result = judge_mod.judgeBattle(
                    self.allocator,
                    task.prompt,
                    battle.response_a.?,
                    battle.response_b.?,
                    .anthropic, // default judge
                    "claude-sonnet-4-20250514",
                ) catch {
                    return battle;
                };

                battle.judge_verdict = judge_result.verdict;
                battle.judge_reasoning = judge_result.reasoning;
                battle.status = .judged;

                // Update ELO
                self.applyVerdict(fighter_a_name, fighter_b_name, judge_result.verdict);
            }
        }

        // Save result
        self.appendResult(battle) catch {};
        self.total_battles += 1;

        // Log to GitHub Issue (Rainbow Bridge)
        self.logToGitHub(battle) catch {};

        return battle;
    }

    /// Apply a manual vote
    pub fn applyVote(self: *Arena, battle: *types.Battle, verdict: types.Verdict) void {
        battle.judge_verdict = verdict;
        battle.status = .judged;
        self.applyVerdict(battle.fighter_a, battle.fighter_b, verdict);
        self.appendResult(battle.*) catch {};
    }

    /// Update ELO ratings based on verdict
    fn applyVerdict(self: *Arena, fighter_a_name: []const u8, fighter_b_name: []const u8, verdict: types.Verdict) void {
        const fa = self.findFighter(fighter_a_name) orelse return;
        const fb = self.findFighter(fighter_b_name) orelse return;

        const new_ratings = elo.updateRatings(fa.elo, fb.elo, verdict);
        fa.elo = new_ratings[0];
        fb.elo = new_ratings[1];

        switch (verdict) {
            .a_wins => {
                fa.wins += 1;
                fb.losses += 1;
            },
            .b_wins => {
                fb.wins += 1;
                fa.losses += 1;
            },
            .tie => {
                fa.ties += 1;
                fb.ties += 1;
            },
        }
    }

    /// Append battle result to JSONL file
    fn appendResult(self: *Arena, battle: types.Battle) !void {
        _ = self;

        // Ensure data/arena/ directory exists
        std.fs.cwd().makePath("data/arena") catch {};

        // Open in append mode or create
        const file = std.fs.cwd().openFile(RESULTS_PATH, .{ .mode = .read_write }) catch
            std.fs.cwd().createFile(RESULTS_PATH, .{}) catch return;
        defer file.close();

        // Seek to end
        const stat = file.stat() catch return;
        file.seekTo(stat.size) catch {};

        var buf: [4096]u8 = undefined;
        const line = std.fmt.bufPrint(&buf,
            \\{{"id":{d},"fighter_a":"{s}","fighter_b":"{s}","task_id":"{s}","category":"{s}","status":"{s}","verdict":"{s}","latency_a_ms":{d},"latency_b_ms":{d},"timestamp":{d}}}
        , .{
            battle.id,
            battle.fighter_a,
            battle.fighter_b,
            battle.task.id,
            battle.task.category.toString(),
            battle.status.toString(),
            if (battle.judge_verdict) |v| v.toString() else "none",
            battle.latency_a_ms,
            battle.latency_b_ms,
            battle.created_at,
        }) catch return;

        file.writeAll(line) catch {};
        file.writeAll("\n") catch {};
    }

    /// Log battle result to GitHub Issue (Rainbow Bridge protocol)
    /// Uses `gh issue comment` to append structured battle summary
    fn logToGitHub(self: *Arena, battle: types.Battle) !void {
        // Only log judged battles
        if (battle.status != .judged) return;

        const verdict_str = if (battle.judge_verdict) |v| v.toString() else "none";
        const verdict_emoji: []const u8 = if (battle.judge_verdict) |v| switch (v) {
            .a_wins => "\xf0\x9f\x8f\x86",
            .b_wins => "\xf0\x9f\x8f\x86",
            .tie => "\xf0\x9f\xa4\x9d",
        } else "\xe2\x9d\x93";

        // Build comment body
        var buf: [2048]u8 = undefined;
        const comment = std.fmt.bufPrint(&buf,
            \\{s} **Arena Battle #{d}**
            \\
            \\| Field | Value |
            \\|-------|-------|
            \\| Fighter A | `{s}` |
            \\| Fighter B | `{s}` |
            \\| Task | {s} ({s}) |
            \\| Verdict | **{s}** |
            \\| Latency A | {d}ms |
            \\| Latency B | {d}ms |
            \\
            \\---
            \\*Logged by Trinity Arena 2.0*
        , .{
            verdict_emoji,
            battle.id,
            battle.fighter_a,
            battle.fighter_b,
            battle.task.id,
            battle.task.category.toString(),
            verdict_str,
            battle.latency_a_ms,
            battle.latency_b_ms,
        }) catch return;

        // Write to temp file for gh
        const tmp_path = "/tmp/arena_battle_comment.md";
        const tmp_file = std.fs.cwd().createFile(tmp_path, .{}) catch return;
        tmp_file.writeAll(comment) catch {
            tmp_file.close();
            return;
        };
        tmp_file.close();

        // Post to Arena log issue (create if needed)
        // Use issue #357 (Training Farm tracker) or a dedicated arena log issue
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{ "gh", "issue", "comment", "357", "--repo", "gHashTag/trinity", "-F", tmp_path },
            .max_output_bytes = 4096,
        }) catch return;
        self.allocator.free(result.stdout);
        self.allocator.free(result.stderr);
    }

    /// Write leaderboard to JSON
    pub fn writeLeaderboard(self: *Arena) !void {
        std.fs.cwd().makePath("data/arena") catch {};

        // Build JSON in a buffer
        var buf: [4096]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        const writer = fbs.writer();

        writer.writeAll("{\"fighters\":[") catch return;

        var first = true;
        for (self.fighters[0..self.fighter_count]) |*f| {
            if (!f.active) continue;
            if (!first) writer.writeAll(",") catch return;
            first = false;

            var elo_buf: [16]u8 = undefined;
            const elo_str = elo.formatElo(f.elo, &elo_buf);

            std.fmt.format(writer,
                \\{{"name":"{s}","elo":{s},"wins":{d},"losses":{d},"ties":{d}}}
            , .{
                f.getName(),
                elo_str,
                f.wins,
                f.losses,
                f.ties,
            }) catch continue;
        }

        std.fmt.format(writer,
            \\],"total_battles":{d}}}
        , .{self.total_battles}) catch return;

        const file = std.fs.cwd().createFile(LEADERBOARD_PATH, .{}) catch return;
        defer file.close();
        file.writeAll(fbs.getWritten()) catch {};
    }

    /// Print leaderboard to stdout
    pub fn printLeaderboard(self: *Arena) void {
        const print = std.debug.print;
        const RESET = "\x1b[0m";
        const BOLD = "\x1b[1m";
        const GOLDEN = "\x1b[38;5;220m";
        const CYAN = "\x1b[36m";
        const GREEN = "\x1b[32m";
        const DIM = "\x1b[2m";

        print("\n{s}{s}\xe2\x9a\x94 TRINITY ARENA LEADERBOARD{s}\n", .{ BOLD, GOLDEN, RESET });
        print("{s}=================================================={s}\n", .{ DIM, RESET });
        print("{s}{s:<20} {s:>6} {s:>5} {s:>5} {s:>5} {s:>6}{s}\n", .{
            BOLD, "Fighter", "ELO", "W", "L", "T", "Total", RESET,
        });
        print("{s}--------------------------------------------------{s}\n", .{ DIM, RESET });

        // Sort by ELO (simple bubble sort, max 32 fighters)
        var indices: [types.MAX_FIGHTERS]usize = undefined;
        var count: usize = 0;
        for (0..self.fighter_count) |i| {
            if (self.fighters[i].active) {
                indices[count] = i;
                count += 1;
            }
        }

        // Bubble sort descending by ELO
        if (count > 1) {
            for (0..count - 1) |i| {
                for (i + 1..count) |j| {
                    if (self.fighters[indices[i]].elo < self.fighters[indices[j]].elo) {
                        const tmp = indices[i];
                        indices[i] = indices[j];
                        indices[j] = tmp;
                    }
                }
            }
        }

        for (0..count) |rank| {
            const f = &self.fighters[indices[rank]];
            var elo_buf: [16]u8 = undefined;
            const elo_str = elo.formatElo(f.elo, &elo_buf);
            const total = f.wins + f.losses + f.ties;

            const color = if (rank == 0) GOLDEN else if (rank < 3) CYAN else GREEN;
            const medal: []const u8 = if (rank == 0) "\xf0\x9f\xa5\x87" else if (rank == 1) "\xf0\x9f\xa5\x88" else if (rank == 2) "\xf0\x9f\xa5\x89" else "  ";

            print("{s} {s}{s:<18}{s} {s:>6} {d:>5} {d:>5} {d:>5} {d:>6}\n", .{
                medal, color, f.getName(), RESET, elo_str, f.wins, f.losses, f.ties, total,
            });
        }

        print("{s}--------------------------------------------------{s}\n", .{ DIM, RESET });
        print("{s}Total battles: {d}{s}\n\n", .{ DIM, self.total_battles, RESET });
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

test "arena init has default fighters" {
    var arena = Arena.init(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), arena.fighter_count);
    try std.testing.expect(arena.findFighter("trinity-hslm") != null);
    try std.testing.expect(arena.findFighter("echo") != null);
}

test "register fighter" {
    var arena = Arena.init(std.testing.allocator);
    arena.registerFighter("gpt-4o", .openai, "gpt-4o", null);
    try std.testing.expectEqual(@as(usize, 3), arena.fighter_count);
    const f = arena.findFighter("gpt-4o");
    try std.testing.expect(f != null);
    try std.testing.expectEqual(types.FighterKind.openai, f.?.kind);
}

test "no duplicate fighters" {
    var arena = Arena.init(std.testing.allocator);
    arena.registerFighter("echo", .echo, null, null); // duplicate
    try std.testing.expectEqual(@as(usize, 2), arena.fighter_count);
}

test "find fighter returns null for unknown" {
    var arena = Arena.init(std.testing.allocator);
    try std.testing.expect(arena.findFighter("nonexistent") == null);
}

test "apply verdict updates elo" {
    var arena = Arena.init(std.testing.allocator);
    arena.applyVerdict("trinity-hslm", "echo", .a_wins);

    const a = arena.findFighter("trinity-hslm").?;
    const b = arena.findFighter("echo").?;

    try std.testing.expect(a.elo > 1000.0);
    try std.testing.expect(b.elo < 1000.0);
    try std.testing.expectEqual(@as(u32, 1), a.wins);
    try std.testing.expectEqual(@as(u32, 1), b.losses);
}
