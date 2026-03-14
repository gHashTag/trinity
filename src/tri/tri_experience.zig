// ═══════════════════════════════════════════════════════════════════════════════
// TRI EXPERIENCE — Persistent Episode Storage & Mistake Pattern Tracking
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri experience save     — save an episode (issue, task, verdict, mistakes, learnings)
//   tri experience recall   — recall relevant episodes by task keywords
//   tri experience mistakes — show mistake patterns sorted by frequency
//
// Storage:
//   .trinity/experience/episodes/{issue}_{timestamp}.json
//   .trinity/experience/mistakes/{hash}_{name}.json
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const tri_dev = @import("tri_dev.zig");

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

const EPISODES_DIR = ".trinity/experience/episodes";
const MISTAKES_DIR = ".trinity/experience/mistakes";

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Episode = struct {
    issue: u32 = 0,
    task: [256]u8 = undefined,
    task_len: u8 = 0,
    iterations: u32 = 1,
    verdict: [16]u8 = undefined,
    verdict_len: u8 = 0,
    fitness: tri_dev.DevFitness = .{},
    mistakes: [8][128]u8 = undefined,
    mistake_lens: [8]u8 = .{0} ** 8,
    mistake_count: u8 = 0,
    learnings: [8][128]u8 = undefined,
    learning_lens: [8]u8 = .{0} ** 8,
    learning_count: u8 = 0,
    timestamp: i64 = 0,

    pub fn taskStr(self: *const Episode) []const u8 {
        return self.task[0..self.task_len];
    }

    pub fn verdictStr(self: *const Episode) []const u8 {
        return self.verdict[0..self.verdict_len];
    }

    pub fn getMistake(self: *const Episode, idx: usize) []const u8 {
        if (idx >= self.mistake_count) return "";
        return self.mistakes[idx][0..self.mistake_lens[idx]];
    }

    pub fn getLearning(self: *const Episode, idx: usize) []const u8 {
        if (idx >= self.learning_count) return "";
        return self.learnings[idx][0..self.learning_lens[idx]];
    }
};

pub const MistakePattern = struct {
    pattern: [128]u8 = undefined,
    pattern_len: u8 = 0,
    count: u32 = 0,
    last_issue: u32 = 0,
    fix_hint: [256]u8 = undefined,
    fix_hint_len: u8 = 0,

    pub fn patternStr(self: *const MistakePattern) []const u8 {
        return self.pattern[0..self.pattern_len];
    }

    pub fn fixHintStr(self: *const MistakePattern) []const u8 {
        return self.fix_hint[0..self.fix_hint_len];
    }
};

pub fn copyToFixed(dest: anytype, len_ptr: *u8, src: []const u8) void {
    const max = dest.len;
    const copy_len = @min(src.len, max);
    @memcpy(dest[0..copy_len], src[0..copy_len]);
    len_ptr.* = @intCast(copy_len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runExperienceCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "help";

    if (std.mem.eql(u8, subcmd, "save")) {
        return runExperienceSave(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "recall")) {
        return runExperienceRecall(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "mistakes")) {
        return runExperienceMistakes(allocator);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        print("{s}Unknown experience subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SAVE — persist an episode to disk
// ═══════════════════════════════════════════════════════════════════════════════

fn runExperienceSave(_: Allocator, args: []const []const u8) !void {
    var episode = Episode{};
    episode.timestamp = std.time.timestamp();

    // Parse flags
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--issue") and i + 1 < args.len) {
            i += 1;
            episode.issue = std.fmt.parseInt(u32, args[i], 10) catch 0;
        } else if (std.mem.eql(u8, arg, "--task") and i + 1 < args.len) {
            i += 1;
            copyToFixed(&episode.task, &episode.task_len, args[i]);
        } else if (std.mem.eql(u8, arg, "--verdict") and i + 1 < args.len) {
            i += 1;
            copyToFixed(&episode.verdict, &episode.verdict_len, args[i]);
        } else if (std.mem.eql(u8, arg, "--iterations") and i + 1 < args.len) {
            i += 1;
            episode.iterations = std.fmt.parseInt(u32, args[i], 10) catch 1;
        } else if (std.mem.eql(u8, arg, "--mistake") and i + 1 < args.len) {
            i += 1;
            if (episode.mistake_count < 8) {
                copyToFixed(&episode.mistakes[episode.mistake_count], &episode.mistake_lens[episode.mistake_count], args[i]);
                episode.mistake_count += 1;
            }
        } else if (std.mem.eql(u8, arg, "--learning") and i + 1 < args.len) {
            i += 1;
            if (episode.learning_count < 8) {
                copyToFixed(&episode.learnings[episode.learning_count], &episode.learning_lens[episode.learning_count], args[i]);
                episode.learning_count += 1;
            }
        }
    }

    if (episode.task_len == 0) {
        print("{s}Error: --task is required{s}\n", .{ RED, RESET });
        return;
    }
    if (episode.verdict_len == 0) {
        copyToFixed(&episode.verdict, &episode.verdict_len, "UNKNOWN");
    }

    try saveEpisode(episode);

    // Update mistake patterns for each mistake
    var mi: u8 = 0;
    while (mi < episode.mistake_count) : (mi += 1) {
        try updateMistakePatterns(episode.getMistake(mi), episode.issue);
    }

    print("\n{s}EXPERIENCE SAVED{s}\n", .{ BOLD, RESET });
    print("  Issue:      #{d}\n", .{episode.issue});
    print("  Task:       {s}\n", .{episode.taskStr()});
    print("  Verdict:    {s}{s}{s}\n", .{
        if (std.mem.eql(u8, episode.verdictStr(), "PASS")) GREEN else RED,
        episode.verdictStr(),
        RESET,
    });
    print("  Iterations: {d}\n", .{episode.iterations});
    print("  Mistakes:   {d}\n", .{episode.mistake_count});
    print("  Learnings:  {d}\n\n", .{episode.learning_count});
}

// ═══════════════════════════════════════════════════════════════════════════════
// RECALL — find relevant past episodes by keyword matching
// ═══════════════════════════════════════════════════════════════════════════════

fn runExperienceRecall(allocator: Allocator, args: []const []const u8) !void {
    var task_query: []const u8 = "";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--task") and i + 1 < args.len) {
            i += 1;
            task_query = args[i];
        }
    }

    if (task_query.len == 0) {
        print("{s}Error: --task \"<query>\" is required{s}\n", .{ RED, RESET });
        return;
    }

    // Split query into words
    var words_buf: [32][]const u8 = undefined;
    var word_count: usize = 0;
    var iter = std.mem.splitScalar(u8, task_query, ' ');
    while (iter.next()) |w| {
        if (w.len > 0 and word_count < 32) {
            words_buf[word_count] = w;
            word_count += 1;
        }
    }
    const words = words_buf[0..word_count];

    // Scan episodes directory
    var dir = std.fs.cwd().openDir(EPISODES_DIR, .{ .iterate = true }) catch {
        print("{s}No episodes found. Use 'tri experience save' first.{s}\n", .{ YELLOW, RESET });
        return;
    };
    defer dir.close();

    const ScoredFile = struct {
        name: [128]u8,
        name_len: u8,
        score: u32,
    };
    var scored: [256]ScoredFile = undefined;
    var scored_count: usize = 0;

    var dir_iter = dir.iterate();
    while (try dir_iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

        // Read file and score it
        const contents = dir.readFileAlloc(allocator, entry.name, 64 * 1024) catch continue;
        defer allocator.free(contents);

        const score = keywordScore(contents, words);
        if (score > 0 and scored_count < 256) {
            scored[scored_count] = .{
                .name = undefined,
                .name_len = 0,
                .score = score,
            };
            const copy_len = @min(entry.name.len, 128);
            @memcpy(scored[scored_count].name[0..copy_len], entry.name[0..copy_len]);
            scored[scored_count].name_len = @intCast(copy_len);
            scored_count += 1;
        }
    }

    if (scored_count == 0) {
        print("{s}No matching episodes found for: \"{s}\"{s}\n", .{ YELLOW, task_query, RESET });
        return;
    }

    // Sort by score descending
    std.mem.sort(ScoredFile, scored[0..scored_count], {}, struct {
        fn lessThan(_: void, a: ScoredFile, b: ScoredFile) bool {
            return a.score > b.score;
        }
    }.lessThan);

    // Print top 3
    const show = @min(scored_count, 3);
    print("\n{s}EXPERIENCE RECALL{s} — top {d} for \"{s}\"\n", .{ BOLD, RESET, show, task_query });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    for (scored[0..show]) |*sf| {
        const fname = sf.name[0..sf.name_len];
        const contents = dir.readFileAlloc(allocator, fname, 64 * 1024) catch continue;
        defer allocator.free(contents);

        print("  {s}File:{s} {s} (score: {d})\n", .{ CYAN, RESET, fname, sf.score });
        // Print first few lines of JSON content for context
        var lines: usize = 0;
        var line_iter = std.mem.splitScalar(u8, contents, '\n');
        while (line_iter.next()) |line| {
            if (lines >= 15) break;
            print("    {s}\n", .{line});
            lines += 1;
        }
        print("\n", .{});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MISTAKES — show mistake patterns sorted by frequency
// ═══════════════════════════════════════════════════════════════════════════════

fn runExperienceMistakes(allocator: Allocator) !void {
    var dir = std.fs.cwd().openDir(MISTAKES_DIR, .{ .iterate = true }) catch {
        print("{s}No mistake patterns recorded yet.{s}\n", .{ YELLOW, RESET });
        return;
    };
    defer dir.close();

    var patterns: [128]MistakePattern = undefined;
    var pattern_count: usize = 0;

    var dir_iter = dir.iterate();
    while (try dir_iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
        if (pattern_count >= 128) break;

        const contents = dir.readFileAlloc(allocator, entry.name, 16 * 1024) catch continue;
        defer allocator.free(contents);

        // Parse simple JSON fields
        var pat = MistakePattern{};
        if (extractJsonString(contents, "pattern")) |v| copyToFixed(&pat.pattern, &pat.pattern_len, v);
        if (extractJsonString(contents, "fix_hint")) |v| copyToFixed(&pat.fix_hint, &pat.fix_hint_len, v);
        if (extractJsonU32(contents, "count")) |v| pat.count = v;
        if (extractJsonU32(contents, "last_issue")) |v| pat.last_issue = v;

        if (pat.pattern_len > 0) {
            patterns[pattern_count] = pat;
            pattern_count += 1;
        }
    }

    if (pattern_count == 0) {
        print("{s}No mistake patterns recorded yet.{s}\n", .{ YELLOW, RESET });
        return;
    }

    // Sort by count descending
    std.mem.sort(MistakePattern, patterns[0..pattern_count], {}, struct {
        fn lessThan(_: void, a: MistakePattern, b: MistakePattern) bool {
            return a.count > b.count;
        }
    }.lessThan);

    print("\n{s}MISTAKE PATTERNS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}Count  Last Issue  Pattern{s}\n", .{ DIM, RESET });
    print("  {s}─────  ──────────  ─────────────────────────────────────{s}\n", .{ DIM, RESET });

    for (patterns[0..pattern_count]) |*p| {
        print("  {s}{d:>5}{s}  #{d:<9}  {s}\n", .{
            if (p.count >= 3) RED else YELLOW,
            p.count,
            RESET,
            p.last_issue,
            p.patternStr(),
        });
        if (p.fix_hint_len > 0) {
            print("  {s}       hint: {s}{s}\n", .{ DIM, p.fixHintStr(), RESET });
        }
    }
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERSISTENCE
// ═══════════════════════════════════════════════════════════════════════════════

pub fn saveEpisode(episode: Episode) !void {
    // Ensure directory exists
    std.fs.cwd().makePath(EPISODES_DIR) catch {};

    // Build filename: {issue}_{timestamp}.json
    var fname_buf: [64]u8 = undefined;
    const fname = std.fmt.bufPrint(&fname_buf, "{d}_{d}.json", .{
        episode.issue,
        episode.timestamp,
    }) catch return error.OutOfMemory;

    // Build JSON
    var buf: [8192]u8 = undefined;
    var pos: usize = 0;

    pos += (std.fmt.bufPrint(buf[pos..], "{{\"issue\":{d},\"task\":\"{s}\",\"iterations\":{d},\"verdict\":\"{s}\",\"timestamp\":{d}", .{
        episode.issue,
        episode.taskStr(),
        episode.iterations,
        episode.verdictStr(),
        episode.timestamp,
    }) catch return error.OutOfMemory).len;

    // Fitness
    pos += (std.fmt.bufPrint(buf[pos..], ",\"fitness\":{{\"test_pass_rate\":{d:.4},\"spec_compliance\":{d:.4},\"time_hours\":{d:.4},\"pr_merged\":{}}}", .{
        episode.fitness.test_pass_rate,
        episode.fitness.spec_compliance,
        episode.fitness.time_hours,
        episode.fitness.pr_merged,
    }) catch return error.OutOfMemory).len;

    // Mistakes array
    pos += (std.fmt.bufPrint(buf[pos..], ",\"mistakes\":[", .{}) catch return error.OutOfMemory).len;
    var mi: u8 = 0;
    while (mi < episode.mistake_count) : (mi += 1) {
        if (mi > 0) {
            buf[pos] = ',';
            pos += 1;
        }
        pos += (std.fmt.bufPrint(buf[pos..], "\"{s}\"", .{episode.getMistake(mi)}) catch return error.OutOfMemory).len;
    }
    buf[pos] = ']';
    pos += 1;

    // Learnings array
    pos += (std.fmt.bufPrint(buf[pos..], ",\"learnings\":[", .{}) catch return error.OutOfMemory).len;
    var li: u8 = 0;
    while (li < episode.learning_count) : (li += 1) {
        if (li > 0) {
            buf[pos] = ',';
            pos += 1;
        }
        pos += (std.fmt.bufPrint(buf[pos..], "\"{s}\"", .{episode.getLearning(li)}) catch return error.OutOfMemory).len;
    }
    buf[pos] = ']';
    pos += 1;

    buf[pos] = '}';
    pos += 1;

    // Write to file
    var dir = try std.fs.cwd().openDir(EPISODES_DIR, .{});
    defer dir.close();
    var file = try dir.createFile(fname, .{});
    defer file.close();
    try file.writeAll(buf[0..pos]);
}

fn updateMistakePatterns(mistake_text: []const u8, issue: u32) !void {
    if (mistake_text.len == 0) return;

    std.fs.cwd().makePath(MISTAKES_DIR) catch {};

    // Hash the first 32 chars as filename prefix
    var hash: u32 = 0;
    const prefix_len = @min(mistake_text.len, 32);
    for (mistake_text[0..prefix_len]) |c| {
        hash = hash *% 31 +% c;
    }

    var fname_buf: [64]u8 = undefined;
    const fname = std.fmt.bufPrint(&fname_buf, "{x:0>8}.json", .{hash}) catch return;

    var dir = std.fs.cwd().openDir(MISTAKES_DIR, .{}) catch return;
    defer dir.close();

    // Try to read existing pattern
    var existing_count: u32 = 0;
    if (dir.readFileAlloc(std.heap.page_allocator, fname, 16 * 1024)) |contents| {
        defer std.heap.page_allocator.free(contents);
        existing_count = extractJsonU32(contents, "count") orelse 0;
    } else |_| {}

    // Write updated pattern
    var buf: [2048]u8 = undefined;
    const json = std.fmt.bufPrint(&buf, "{{\"pattern\":\"{s}\",\"count\":{d},\"last_issue\":{d},\"fix_hint\":\"\"}}", .{
        mistake_text[0..@min(mistake_text.len, 128)],
        existing_count + 1,
        issue,
    }) catch return;

    var file = dir.createFile(fname, .{}) catch return;
    defer file.close();
    file.writeAll(json) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

pub fn keywordScore(haystack: []const u8, words: []const []const u8) u32 {
    var score: u32 = 0;
    for (words) |word| {
        if (word.len == 0) continue;
        // Count occurrences
        var offset: usize = 0;
        while (offset < haystack.len) {
            if (std.mem.indexOfPos(u8, haystack, offset, word)) |idx| {
                score += 1;
                offset = idx + word.len;
            } else break;
        }
    }
    return score;
}

fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    // Find "key":"value" pattern
    var search_buf: [140]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":\"", .{key}) catch return null;
    const start = (std.mem.indexOf(u8, json, search) orelse return null) + search.len;
    const end = std.mem.indexOfPos(u8, json, start, "\"") orelse return null;
    return json[start..end];
}

fn extractJsonU32(json: []const u8, key: []const u8) ?u32 {
    var search_buf: [140]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":", .{key}) catch return null;
    const start = (std.mem.indexOf(u8, json, search) orelse return null) + search.len;
    // Skip whitespace
    var pos = start;
    while (pos < json.len and json[pos] == ' ') pos += 1;
    // Read digits
    var end = pos;
    while (end < json.len and json[end] >= '0' and json[end] <= '9') end += 1;
    if (end == pos) return null;
    return std.fmt.parseInt(u32, json[pos..end], 10) catch null;
}

fn printHelp() void {
    print("\n{s}TRI EXPERIENCE{s} — ExpeL knowledge base + episode tracking\n\n", .{ BOLD, RESET });
    print("  {s}ExpeL Log (EXPERIENCE_LOG.md):{s}\n", .{ DIM, RESET });
    print("  {s}tri experience list{s}               List all log entries\n", .{ CYAN, RESET });
    print("  {s}tri experience list --recent 5{s}     Last 5 entries\n", .{ CYAN, RESET });
    print("  {s}tri experience recall checkpoint{s}   Search by keyword\n", .{ CYAN, RESET });
    print("  {s}tri experience recall --type FAILURE{s} Filter by type\n", .{ CYAN, RESET });
    print("  {s}tri experience recall --category training{s}\n", .{ CYAN, RESET });
    print("  {s}tri experience log-save SUCCESS pipeline --lesson \"...\"{s}\n", .{ CYAN, RESET });
    print("\n", .{});
    print("  {s}Episode Storage (.trinity/experience/):{s}\n", .{ DIM, RESET });
    print("  {s}tri experience save{s}      Save episode (--issue --task --verdict)\n", .{ CYAN, RESET });
    print("  {s}tri experience recall --task \"query\"{s}  Recall episodes\n", .{ CYAN, RESET });
    print("  {s}tri experience mistakes{s}  Mistake patterns by frequency\n\n", .{ CYAN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXPERIENCE_LOG.MD — Markdown Knowledge Base Operations
// ═══════════════════════════════════════════════════════════════════════════════

const EXPERIENCE_LOG_PATH = "EXPERIENCE_LOG.md";

pub const ExpType = enum {
    DISCOVERY,
    FAILURE,
    SUCCESS,
    WARNING,
    INSIGHT,

    pub fn fromStr(s: []const u8) ?ExpType {
        if (std.ascii.eqlIgnoreCase(s, "discovery")) return .DISCOVERY;
        if (std.ascii.eqlIgnoreCase(s, "failure")) return .FAILURE;
        if (std.ascii.eqlIgnoreCase(s, "success")) return .SUCCESS;
        if (std.ascii.eqlIgnoreCase(s, "warning")) return .WARNING;
        if (std.ascii.eqlIgnoreCase(s, "insight")) return .INSIGHT;
        return null;
    }

    pub fn toStr(self: ExpType) []const u8 {
        return switch (self) {
            .DISCOVERY => "DISCOVERY",
            .FAILURE => "FAILURE",
            .SUCCESS => "SUCCESS",
            .WARNING => "WARNING",
            .INSIGHT => "INSIGHT",
        };
    }

    pub fn toColor(self: ExpType) []const u8 {
        return switch (self) {
            .DISCOVERY => CYAN,
            .FAILURE => RED,
            .SUCCESS => GREEN,
            .WARNING => YELLOW,
            .INSIGHT => MAGENTA,
        };
    }
};

pub const LogEntry = struct {
    id: u32 = 0,
    exp_type: ExpType = .DISCOVERY,
    date: [16]u8 = undefined,
    date_len: usize = 0,
    category: [32]u8 = undefined,
    category_len: usize = 0,
    impact: [8]u8 = undefined,
    impact_len: usize = 0,
    lesson_start: usize = 0,
    lesson_end: usize = 0,
    context_start: usize = 0,
    context_end: usize = 0,
    outcome_start: usize = 0,
    outcome_end: usize = 0,

    pub fn dateStr(self: *const LogEntry) []const u8 {
        return self.date[0..self.date_len];
    }
    pub fn categoryStr(self: *const LogEntry) []const u8 {
        return self.category[0..self.category_len];
    }
    pub fn impactStr(self: *const LogEntry) []const u8 {
        return self.impact[0..self.impact_len];
    }
    pub fn lessonStr(self: *const LogEntry, src: []const u8) []const u8 {
        if (self.lesson_end <= self.lesson_start) return "(none)";
        return src[self.lesson_start..self.lesson_end];
    }
    pub fn contextStr2(self: *const LogEntry, src: []const u8) []const u8 {
        if (self.context_end <= self.context_start) return "(none)";
        return src[self.context_start..self.context_end];
    }
    pub fn outcomeStr(self: *const LogEntry, src: []const u8) []const u8 {
        if (self.outcome_end <= self.outcome_start) return "(none)";
        return src[self.outcome_start..self.outcome_end];
    }
};

const MAX_LOG_ENTRIES = 256;

pub fn parseExpLog(source: []const u8, entries: []LogEntry) usize {
    var count: usize = 0;
    var line_iter = std.mem.splitScalar(u8, source, '\n');

    while (line_iter.next()) |line| {
        if (count >= entries.len) break;
        if (!std.mem.startsWith(u8, line, "### EXP-")) continue;

        const after = line[8..];
        var id_end: usize = 0;
        while (id_end < after.len and after[id_end] >= '0' and after[id_end] <= '9') : (id_end += 1) {}
        if (id_end == 0) continue;
        const id = std.fmt.parseInt(u32, after[0..id_end], 10) catch continue;

        var entry = LogEntry{ .id = id };
        var rest = after[id_end..];

        // Parse " | TYPE | DATE | CATEGORY"
        if (std.mem.indexOf(u8, rest, " | ")) |s1| {
            rest = rest[s1 + 3 ..];
            if (std.mem.indexOf(u8, rest, " | ")) |s2| {
                entry.exp_type = ExpType.fromStr(rest[0..s2]) orelse .DISCOVERY;
                rest = rest[s2 + 3 ..];
                if (std.mem.indexOf(u8, rest, " | ")) |s3| {
                    const d = rest[0..s3];
                    const dl = @min(d.len, 16);
                    @memcpy(entry.date[0..dl], d[0..dl]);
                    entry.date_len = dl;
                    const c = std.mem.trimRight(u8, rest[s3 + 3 ..], " \r\n");
                    const cl = @min(c.len, 32);
                    @memcpy(entry.category[0..cl], c[0..cl]);
                    entry.category_len = cl;
                }
            }
        }

        // Scan content lines
        while (line_iter.next()) |cl| {
            if (std.mem.startsWith(u8, cl, "---") or std.mem.startsWith(u8, cl, "### EXP-")) break;
            const offset = @intFromPtr(cl.ptr) - @intFromPtr(source.ptr);
            if (std.mem.startsWith(u8, cl, "**Impact**: ")) {
                const v = std.mem.trimRight(u8, cl[12..], " \r\n");
                const vl = @min(v.len, 8);
                @memcpy(entry.impact[0..vl], v[0..vl]);
                entry.impact_len = vl;
            } else if (std.mem.startsWith(u8, cl, "**Context**: ")) {
                entry.context_start = offset + 13;
                entry.context_end = offset + cl.len;
            } else if (std.mem.startsWith(u8, cl, "**Outcome**: ")) {
                entry.outcome_start = offset + 13;
                entry.outcome_end = offset + cl.len;
            } else if (std.mem.startsWith(u8, cl, "**Lesson**: ")) {
                entry.lesson_start = offset + 12;
                entry.lesson_end = offset + cl.len;
            }
        }

        entries[count] = entry;
        count += 1;
    }
    return count;
}

pub fn findMaxLogId(entries: []const LogEntry, count: usize) u32 {
    var max: u32 = 0;
    for (entries[0..count]) |e| {
        if (e.id > max) max = e.id;
    }
    return max;
}

fn containsIC(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0 or haystack.len < needle.len) return false;
    var i: usize = 0;
    while (i <= haystack.len - needle.len) : (i += 1) {
        var ok = true;
        for (0..needle.len) |j| {
            if (std.ascii.toLower(haystack[i + j]) != std.ascii.toLower(needle[j])) {
                ok = false;
                break;
            }
        }
        if (ok) return true;
    }
    return false;
}

// ── tri experience list [--recent N] ─────────────────────────────────────────

fn runLogList(allocator: Allocator, args: []const []const u8) void {
    const content = readLogFile(allocator) orelse {
        print("{s}EXPERIENCE_LOG.md not found{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(content);

    var entries: [MAX_LOG_ENTRIES]LogEntry = undefined;
    const count = parseExpLog(content, &entries);
    if (count == 0) {
        print("{s}No experience entries found{s}\n", .{ YELLOW, RESET });
        return;
    }

    var show_count = count;
    var start: usize = 0;
    if (args.len >= 2 and std.mem.eql(u8, args[0], "--recent")) {
        const n = std.fmt.parseInt(usize, args[1], 10) catch count;
        if (n < count) {
            start = count - n;
            show_count = n;
        }
    }

    print("\n{s}EXPERIENCE LOG — ExpeL Knowledge Base{s}\n", .{ BOLD, RESET });
    print("{s}{'='[0]^72}{s}\n\n", .{ DIM, RESET });
    print("  {s}ID    | Type       | Impact | Category     | Lesson{s}\n", .{ DIM, RESET });
    print("  {s}{'-'[0]^68}{s}\n", .{ DIM, RESET });

    for (entries[start .. start + show_count]) |*e| {
        const lesson = e.lessonStr(content);
        const short = if (lesson.len > 32) lesson[0..32] else lesson;
        print("  EXP-{d:0>3} | {s}{s: <10}{s} | {s: <6} | {s: <12} | {s}\n", .{
            e.id,
            e.exp_type.toColor(), e.exp_type.toStr(), RESET,
            e.impactStr(),
            e.categoryStr(),
            short,
        });
    }
    print("\n  {s}Total: {d} entries ({d} shown){s}\n\n", .{ DIM, count, show_count, RESET });
}

// ── tri experience recall <query|--type TYPE> ────────────────────────────────

fn runLogRecall(allocator: Allocator, args: []const []const u8) void {
    if (args.len == 0) {
        print("{s}Usage: tri experience recall <query|--type TYPE|--category CAT|--impact HIGH>{s}\n", .{ YELLOW, RESET });
        return;
    }

    // If first arg is --task, delegate to episode recall (old behavior)
    if (std.mem.eql(u8, args[0], "--task")) {
        return runExperienceRecall(allocator, args);
    }

    const content = readLogFile(allocator) orelse {
        print("{s}EXPERIENCE_LOG.md not found{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(content);

    var entries: [MAX_LOG_ENTRIES]LogEntry = undefined;
    const count = parseExpLog(content, &entries);

    var matches: [MAX_LOG_ENTRIES]usize = undefined;
    var mc: usize = 0;

    if (std.mem.eql(u8, args[0], "--type") and args.len >= 2) {
        const tf = ExpType.fromStr(args[1]) orelse {
            print("{s}Unknown type: {s}{s}\n", .{ RED, args[1], RESET });
            return;
        };
        for (entries[0..count], 0..) |*e, i| {
            if (e.exp_type == tf) {
                matches[mc] = i;
                mc += 1;
            }
        }
    } else if (std.mem.eql(u8, args[0], "--category") and args.len >= 2) {
        for (entries[0..count], 0..) |*e, i| {
            if (std.ascii.eqlIgnoreCase(e.categoryStr(), args[1])) {
                matches[mc] = i;
                mc += 1;
            }
        }
    } else if (std.mem.eql(u8, args[0], "--impact") and args.len >= 2) {
        for (entries[0..count], 0..) |*e, i| {
            if (std.ascii.eqlIgnoreCase(e.impactStr(), args[1])) {
                matches[mc] = i;
                mc += 1;
            }
        }
    } else {
        // Keyword search
        const q = args[0];
        for (entries[0..count], 0..) |*e, i| {
            if (containsIC(e.lessonStr(content), q) or
                containsIC(e.contextStr2(content), q) or
                containsIC(e.outcomeStr(content), q))
            {
                matches[mc] = i;
                mc += 1;
            }
        }
    }

    if (mc == 0) {
        print("{s}No matching experiences found{s}\n", .{ YELLOW, RESET });
        return;
    }

    print("\n{s}EXPERIENCE RECALL — {d} matches{s}\n", .{ BOLD, mc, RESET });
    print("{s}{'='[0]^72}{s}\n\n", .{ DIM, RESET });

    for (matches[0..mc]) |idx| {
        const e = &entries[idx];
        print("  {s}EXP-{d:0>3}{s} | {s}{s}{s} | {s} | {s}\n", .{
            BOLD, e.id, RESET,
            e.exp_type.toColor(), e.exp_type.toStr(), RESET,
            e.dateStr(), e.categoryStr(),
        });
        print("    {s}Lesson:{s} {s}\n\n", .{ CYAN, RESET, e.lessonStr(content) });
    }
}

// ── tri experience log-save <TYPE> <CATEGORY> [--flags] ──────────────────────

fn runLogSave(allocator: Allocator, args: []const []const u8) void {
    if (args.len < 2) {
        print("{s}Usage: tri experience log-save <TYPE> <CATEGORY> [--impact H/M/L] [--lesson \"...\"] [--context \"...\"] [--outcome \"...\"] [--actions \"...\"]{s}\n", .{ YELLOW, RESET });
        return;
    }

    const exp_type = ExpType.fromStr(args[0]) orelse {
        print("{s}Unknown type: {s}. Valid: DISCOVERY, FAILURE, SUCCESS, WARNING, INSIGHT{s}\n", .{ RED, args[0], RESET });
        return;
    };
    const category = args[1];

    var impact: []const u8 = "MEDIUM";
    var context_val: []const u8 = "(pending)";
    var outcome_val: []const u8 = "(pending)";
    var lesson_val: []const u8 = "(pending)";
    var actions_val: []const u8 = "(pending)";

    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--impact") and i + 1 < args.len) {
            i += 1;
            impact = args[i];
        } else if (std.mem.eql(u8, args[i], "--context") and i + 1 < args.len) {
            i += 1;
            context_val = args[i];
        } else if (std.mem.eql(u8, args[i], "--outcome") and i + 1 < args.len) {
            i += 1;
            outcome_val = args[i];
        } else if (std.mem.eql(u8, args[i], "--lesson") and i + 1 < args.len) {
            i += 1;
            lesson_val = args[i];
        } else if (std.mem.eql(u8, args[i], "--actions") and i + 1 < args.len) {
            i += 1;
            actions_val = args[i];
        }
    }

    // Find next ID
    const existing = readLogFile(allocator);
    var log_entries: [MAX_LOG_ENTRIES]LogEntry = undefined;
    const lcount = if (existing) |e| parseExpLog(e, &log_entries) else 0;
    const next_id = findMaxLogId(&log_entries, lcount) + 1;
    if (existing) |e| allocator.free(e);

    var buf: [4096]u8 = undefined;
    const entry_text = std.fmt.bufPrint(&buf,
        \\
        \\---
        \\
        \\### EXP-{d:0>3} | {s} | 2026-03-14 | {s}
        \\**Impact**: {s}
        \\**Context**: {s}
        \\**Outcome**: {s}
        \\**Lesson**: {s}
        \\**Action items**: {s}
        \\
    , .{ next_id, exp_type.toStr(), category, impact, context_val, outcome_val, lesson_val, actions_val }) catch {
        print("{s}Entry too large{s}\n", .{ RED, RESET });
        return;
    };

    const file = std.fs.cwd().openFile(EXPERIENCE_LOG_PATH, .{ .mode = .read_write }) catch {
        print("{s}Cannot open EXPERIENCE_LOG.md{s}\n", .{ RED, RESET });
        return;
    };
    defer file.close();
    const stat = file.stat() catch return;
    file.seekTo(stat.size) catch return;
    file.writeAll(entry_text) catch {
        print("{s}Write failed{s}\n", .{ RED, RESET });
        return;
    };

    print("\n{s}Saved EXP-{d:0>3}{s} | {s}{s}{s} | {s} | {s}\n\n", .{
        BOLD, next_id, RESET,
        exp_type.toColor(), exp_type.toStr(), RESET,
        category, impact,
    });
}

fn readLogFile(allocator: Allocator) ?[]u8 {
    const file = std.fs.cwd().openFile(EXPERIENCE_LOG_PATH, .{}) catch return null;
    defer file.close();
    return file.readToEndAlloc(allocator, 1_048_576) catch null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Episode defaults" {
    const ep = Episode{};
    try std.testing.expectEqual(@as(u32, 0), ep.issue);
    try std.testing.expectEqual(@as(u8, 0), ep.task_len);
    try std.testing.expectEqual(@as(u8, 0), ep.verdict_len);
    try std.testing.expectEqual(@as(u8, 0), ep.mistake_count);
    try std.testing.expectEqual(@as(u8, 0), ep.learning_count);
    try std.testing.expectEqual(@as(u32, 1), ep.iterations);
}

test "keywordScore basic" {
    const text = "fix async merge protocol error handling";
    const words = [_][]const u8{ "async", "merge", "protocol" };
    const score = keywordScore(text, &words);
    try std.testing.expectEqual(@as(u32, 3), score);
}

test "keywordScore no match" {
    const text = "something completely different";
    const words = [_][]const u8{ "async", "merge" };
    const score = keywordScore(text, &words);
    try std.testing.expectEqual(@as(u32, 0), score);
}

test "keywordScore repeated" {
    const text = "error error error fix";
    const words = [_][]const u8{"error"};
    const score = keywordScore(text, &words);
    try std.testing.expectEqual(@as(u32, 3), score);
}

test "MistakePattern defaults" {
    const mp = MistakePattern{};
    try std.testing.expectEqual(@as(u32, 0), mp.count);
    try std.testing.expectEqual(@as(u8, 0), mp.pattern_len);
    try std.testing.expectEqual(@as(u8, 0), mp.fix_hint_len);
}

test "copyToFixed truncation" {
    var dest: [8]u8 = undefined;
    var len: u8 = 0;
    copyToFixed(&dest, &len, "hello world this is long");
    try std.testing.expectEqual(@as(u8, 8), len);
    try std.testing.expectEqualStrings("hello wo", dest[0..len]);
}

test "extractJsonU32" {
    const json = "{\"count\":42,\"other\":7}";
    try std.testing.expectEqual(@as(?u32, 42), extractJsonU32(json, "count"));
    try std.testing.expectEqual(@as(?u32, 7), extractJsonU32(json, "other"));
    try std.testing.expectEqual(@as(?u32, null), extractJsonU32(json, "missing"));
}

test "extractJsonString" {
    const json = "{\"pattern\":\"missing errdefer\",\"hint\":\"check\"}";
    try std.testing.expectEqualStrings("missing errdefer", extractJsonString(json, "pattern").?);
    try std.testing.expectEqualStrings("check", extractJsonString(json, "hint").?);
    try std.testing.expect(extractJsonString(json, "missing") == null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXPERIENCE_LOG.MD TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ExpType fromStr roundtrip" {
    const types = [_]ExpType{ .DISCOVERY, .FAILURE, .SUCCESS, .WARNING, .INSIGHT };
    for (types) |t| {
        const parsed = ExpType.fromStr(t.toStr());
        try std.testing.expectEqual(t, parsed.?);
    }
}

test "ExpType fromStr case insensitive" {
    try std.testing.expectEqual(ExpType.FAILURE, ExpType.fromStr("failure").?);
    try std.testing.expectEqual(ExpType.SUCCESS, ExpType.fromStr("Success").?);
    try std.testing.expect(ExpType.fromStr("UNKNOWN") == null);
}

test "parseExpLog header parsing" {
    const source =
        \\### EXP-001 | DISCOVERY | 2026-03-13 | architecture
        \\**Impact**: HIGH
        \\**Context**: Compared ctx=18 vs ctx=27
        \\**Outcome**: ctx=27 achieved PPL 2.96
        \\**Lesson**: Context length is the dominant hyperparameter
        \\
        \\---
        \\
        \\### EXP-002 | FAILURE | 2026-03-13 | deployment
        \\**Impact**: HIGH
        \\**Context**: Set HSLM_FRESH=1
        \\**Lesson**: NEVER set HSLM_FRESH=1 on valuable checkpoints
        \\
    ;

    var entries: [16]LogEntry = undefined;
    const count = parseExpLog(source, &entries);

    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expectEqual(@as(u32, 1), entries[0].id);
    try std.testing.expectEqual(ExpType.DISCOVERY, entries[0].exp_type);
    try std.testing.expectEqualStrings("2026-03-13", entries[0].dateStr());
    try std.testing.expectEqualStrings("architecture", entries[0].categoryStr());
    try std.testing.expectEqualStrings("HIGH", entries[0].impactStr());

    try std.testing.expectEqual(@as(u32, 2), entries[1].id);
    try std.testing.expectEqual(ExpType.FAILURE, entries[1].exp_type);
    try std.testing.expectEqualStrings("deployment", entries[1].categoryStr());
}

test "parseExpLog lesson extraction" {
    const source =
        \\### EXP-005 | WARNING | 2026-03-14 | training
        \\**Impact**: MEDIUM
        \\**Context**: Running wave 6
        \\**Outcome**: Seed variance extreme
        \\**Lesson**: Always run 5-seed sweeps
        \\
    ;

    var entries: [4]LogEntry = undefined;
    const count = parseExpLog(source, &entries);
    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expectEqualStrings("Always run 5-seed sweeps", entries[0].lessonStr(source));
    try std.testing.expectEqualStrings("Running wave 6", entries[0].contextStr2(source));
}

test "findMaxLogId" {
    var entries = [_]LogEntry{
        LogEntry{ .id = 3 },
        LogEntry{ .id = 15 },
        LogEntry{ .id = 7 },
    };
    try std.testing.expectEqual(@as(u32, 15), findMaxLogId(&entries, 3));
}

test "findMaxLogId empty" {
    var entries: [4]LogEntry = undefined;
    try std.testing.expectEqual(@as(u32, 0), findMaxLogId(&entries, 0));
}

test "containsIC" {
    try std.testing.expect(containsIC("Hello World", "world"));
    try std.testing.expect(containsIC("checkpoint wiped", "checkpoint"));
    try std.testing.expect(!containsIC("hello", "xyz"));
    try std.testing.expect(!containsIC("hi", "hello"));
    try std.testing.expect(containsIC("FAILURE mode", "failure"));
}
