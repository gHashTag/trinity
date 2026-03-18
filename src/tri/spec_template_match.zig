// @origin(spec) @regen(done)
// ═══════════════════════════════════════════════════════════════════════════════
// SPEC TEMPLATE MATCH — Find Best Template Spec for Issue (Link 6 Core)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Given an issue title+body, find the most similar existing .tri spec via
// keyword overlap (Jaccard similarity). Clone its structure as starting template.
//
// Generated from: specs/tri/spec_template_match.tri
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

const MAX_TOKENS = 128;
const MAX_CANDIDATES = 128;
const SPEC_DIR = "specs/tri";
const MIN_SCORE_THRESHOLD: f32 = 0.05;

pub const TokenSet = struct {
    tokens: [MAX_TOKENS][32]u8 = undefined,
    lengths: [MAX_TOKENS]usize = [_]usize{0} ** MAX_TOKENS,
    count: usize = 0,

    pub fn get(self: *const TokenSet, i: usize) []const u8 {
        return self.tokens[i][0..self.lengths[i]];
    }

    pub fn contains(self: *const TokenSet, token: []const u8) bool {
        for (0..self.count) |i| {
            if (std.mem.eql(u8, self.get(i), token)) return true;
        }
        return false;
    }

    fn addUnique(self: *TokenSet, token: []const u8) void {
        if (token.len < 2 or token.len > 31 or self.count >= MAX_TOKENS) return;
        if (self.contains(token)) return;
        @memcpy(self.tokens[self.count][0..token.len], token);
        self.lengths[self.count] = token.len;
        self.count += 1;
    }
};

pub const SpecCandidate = struct {
    path: [128]u8 = [_]u8{0} ** 128,
    path_len: usize = 0,
    name: [64]u8 = [_]u8{0} ** 64,
    name_len: usize = 0,
    score: f32 = 0.0,
    tokens: TokenSet = .{},

    pub fn pathStr(self: *const SpecCandidate) []const u8 {
        return self.path[0..self.path_len];
    }

    pub fn nameStr(self: *const SpecCandidate) []const u8 {
        return self.name[0..self.name_len];
    }
};

pub const MatchResult = struct {
    best_index: ?usize = null,
    best_score: f32 = 0.0,
    candidates_checked: u32 = 0,
    issue_token_count: u32 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TOKENIZER
// ═══════════════════════════════════════════════════════════════════════════════

/// Tokenize text: lowercase, split on non-alphanumeric, filter len < 2, dedupe.
pub fn tokenize(text: []const u8) TokenSet {
    var set = TokenSet{};
    var word_start: ?usize = null;

    for (text, 0..) |c, i| {
        const is_alnum = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9');
        if (is_alnum) {
            if (word_start == null) word_start = i;
        } else {
            if (word_start) |ws| {
                addLowered(&set, text[ws..i]);
                word_start = null;
            }
        }
    }
    // Trailing word
    if (word_start) |ws| {
        addLowered(&set, text[ws..text.len]);
    }
    return set;
}

fn addLowered(set: *TokenSet, word: []const u8) void {
    if (word.len < 2 or word.len > 31) return;
    var buf: [32]u8 = undefined;
    for (word, 0..) |c, i| {
        buf[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    set.addUnique(buf[0..word.len]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// JACCARD SIMILARITY
// ═══════════════════════════════════════════════════════════════════════════════

/// Jaccard similarity = |intersection| / |union|
pub fn jaccardSimilarity(a: *const TokenSet, b: *const TokenSet) f32 {
    if (a.count == 0 and b.count == 0) return 0.0;

    var intersection: u32 = 0;
    for (0..a.count) |i| {
        if (b.contains(a.get(i))) intersection += 1;
    }

    // |union| = |A| + |B| - |intersection|
    const union_size = a.count + b.count - intersection;
    if (union_size == 0) return 0.0;

    return @as(f32, @floatFromInt(intersection)) / @as(f32, @floatFromInt(union_size));
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPEC SCANNER
// ═══════════════════════════════════════════════════════════════════════════════

/// Scan specs/tri/*.tri directory for template candidates.
/// Reads filename + first 10 lines of each .tri file for keyword extraction.
pub fn scanSpecs(_: Allocator, candidates: []SpecCandidate) usize {
    var dir = std.fs.cwd().openDir(SPEC_DIR, .{ .iterate = true }) catch return 0;
    defer dir.close();

    var count: usize = 0;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (count >= candidates.len) break;
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".tri")) continue;

        var cand = &candidates[count];

        // Set path
        const path_str = std.fmt.bufPrint(&cand.path, "{s}/{s}", .{ SPEC_DIR, entry.name }) catch continue;
        cand.path_len = path_str.len;

        // Set name (strip .tri extension)
        const name_end = entry.name.len - 4; // ".tri" = 4
        if (name_end > cand.name.len) continue;
        @memcpy(cand.name[0..name_end], entry.name[0..name_end]);
        cand.name_len = name_end;

        // Tokenize name (underscores → separate words)
        cand.tokens = tokenize(entry.name[0..name_end]);

        // Read first 10 lines for more keywords
        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();

        var buf: [4096]u8 = undefined;
        const bytes_read = file.read(&buf) catch continue;
        const content = buf[0..bytes_read];

        // Extract keyword tokens from header lines
        var lines_seen: usize = 0;
        var line_iter = std.mem.splitScalar(u8, content, '\n');
        while (line_iter.next()) |line| {
            if (lines_seen >= 10) break;
            lines_seen += 1;

            // Skip comment markers and metadata
            const trimmed = std.mem.trimLeft(u8, line, "# ");
            if (trimmed.len < 3) continue;

            // Tokenize and add to candidate
            const line_tokens = tokenize(trimmed);
            for (0..line_tokens.count) |ti| {
                cand.tokens.addUnique(line_tokens.get(ti));
            }
        }

        // Also read file content for `name:` and `types:` lines (within first 4K)
        if (std.mem.indexOf(u8, content, "name: ")) |pos| {
            const after_name = content[pos + 6 ..];
            const end = std.mem.indexOfScalar(u8, after_name, '\n') orelse after_name.len;
            const name_val = tokenize(after_name[0..end]);
            for (0..name_val.count) |ti| {
                cand.tokens.addUnique(name_val.get(ti));
            }
        }

        count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIND BEST TEMPLATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Find the best matching template spec for the given issue text.
pub fn findBestTemplate(allocator: Allocator, issue_text: []const u8, candidates: []SpecCandidate, candidate_count: usize) MatchResult {
    _ = allocator;
    const issue_tokens = tokenize(issue_text);

    var result = MatchResult{
        .candidates_checked = @intCast(candidate_count),
        .issue_token_count = @intCast(issue_tokens.count),
    };

    for (candidates[0..candidate_count], 0..) |*cand, i| {
        cand.score = jaccardSimilarity(&issue_tokens, &cand.tokens);

        if (cand.score > result.best_score) {
            result.best_score = cand.score;
            result.best_index = i;
        }
    }

    // Threshold check
    if (result.best_score < MIN_SCORE_THRESHOLD) {
        result.best_index = null;
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLONE TEMPLATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Clone a template spec file, replacing name/module fields with new_name.
/// Returns the output path, or null on failure.
pub fn cloneTemplate(allocator: Allocator, template_path: []const u8, new_name: []const u8) ?[]const u8 {
    // Read template
    const file = std.fs.cwd().openFile(template_path, .{}) catch return null;
    defer file.close();

    const content = file.readToEndAlloc(allocator, 256 * 1024) catch return null;
    defer allocator.free(content);

    // Build output path
    var out_path_buf: [256]u8 = undefined;
    const out_path = std.fmt.bufPrint(&out_path_buf, "specs/tri/{s}.tri", .{new_name}) catch return null;

    // Check if already exists
    if (std.fs.cwd().access(out_path, .{})) |_| {
        print("  {s}Spec already exists: {s}{s}\n", .{ YELLOW, out_path, RESET });
        return null;
    } else |_| {}

    // Write new file with replaced name/module
    const out_file = std.fs.cwd().createFile(out_path, .{}) catch return null;
    defer out_file.close();

    var line_iter = std.mem.splitScalar(u8, content, '\n');
    while (line_iter.next()) |line| {
        if (std.mem.startsWith(u8, line, "name: ")) {
            out_file.writeAll("name: ") catch return null;
            out_file.writeAll(new_name) catch return null;
            out_file.writeAll("\n") catch return null;
        } else if (std.mem.startsWith(u8, line, "module: ")) {
            out_file.writeAll("module: ") catch return null;
            out_file.writeAll(new_name) catch return null;
            out_file.writeAll("\n") catch return null;
        } else {
            out_file.writeAll(line) catch return null;
            out_file.writeAll("\n") catch return null;
        }
    }

    return out_path;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMAND: tri spec-match "<issue text>"
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runSpecMatchCommand(allocator: Allocator, args: []const []const u8) void {
    if (args.len == 0) {
        print("\n{s}Usage: tri spec-match \"<issue title or text>\"{s}\n\n", .{ YELLOW, RESET });
        return;
    }

    // Join all args as issue text
    var text_buf: [2048]u8 = undefined;
    var text_len: usize = 0;
    for (args) |arg| {
        if (text_len > 0 and text_len < text_buf.len - 1) {
            text_buf[text_len] = ' ';
            text_len += 1;
        }
        const to_copy = @min(arg.len, text_buf.len - text_len);
        @memcpy(text_buf[text_len..][0..to_copy], arg[0..to_copy]);
        text_len += to_copy;
    }
    const issue_text = text_buf[0..text_len];

    print("\n{s}🔍 SPEC TEMPLATE MATCH — Link 6{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Issue: \"{s}\"\n\n", .{issue_text});

    // Tokenize issue
    const issue_tokens = tokenize(issue_text);
    print("  Tokens ({d}): ", .{issue_tokens.count});
    for (0..issue_tokens.count) |i| {
        if (i > 0) print(", ", .{});
        print("{s}", .{issue_tokens.get(i)});
    }
    print("\n\n", .{});

    // Scan specs
    var candidates: [MAX_CANDIDATES]SpecCandidate = undefined;
    for (&candidates) |*c| c.* = SpecCandidate{};
    const count = scanSpecs(allocator, &candidates);

    print("  Scanned: {d} spec files\n\n", .{count});

    if (count == 0) {
        print("  {s}No .tri specs found in {s}/{s}\n\n", .{ RED, SPEC_DIR, RESET });
        return;
    }

    // Find best match
    const result = findBestTemplate(allocator, issue_text, &candidates, count);

    // Show top 5
    print("  {s}RANK  SCORE   SPEC{s}\n", .{ DIM, RESET });
    print("  {s}──────────────────────────────────────────{s}\n", .{ DIM, RESET });

    // Sort candidates by score (simple selection sort, top 5 only)
    var sorted_indices: [MAX_CANDIDATES]usize = undefined;
    for (0..count) |i| sorted_indices[i] = i;
    for (0..@min(count, 5)) |i| {
        var max_j = i;
        for (i + 1..count) |j| {
            if (candidates[sorted_indices[j]].score > candidates[sorted_indices[max_j]].score) {
                max_j = j;
            }
        }
        const tmp = sorted_indices[i];
        sorted_indices[i] = sorted_indices[max_j];
        sorted_indices[max_j] = tmp;
    }

    for (0..@min(count, 5)) |rank| {
        const idx = sorted_indices[rank];
        const cand = &candidates[idx];
        const color = if (rank == 0 and cand.score >= MIN_SCORE_THRESHOLD) GREEN else if (cand.score >= MIN_SCORE_THRESHOLD) CYAN else DIM;
        print("  {s}#{d}    {d:.3}   {s}{s}\n", .{ color, rank + 1, cand.score, cand.nameStr(), RESET });
    }

    print("\n", .{});

    if (result.best_index) |best_idx| {
        const best = &candidates[best_idx];
        print("  {s}Best match: {s} (score={d:.3}){s}\n", .{ GREEN, best.nameStr(), best.score, RESET });
        print("  {s}Template: {s}{s}\n", .{ DIM, best.pathStr(), RESET });
        print("  {s}Clone with: tri spec-match --clone \"{s}\" <new-name>{s}\n\n", .{ DIM, issue_text, RESET });
    } else {
        print("  {s}No match above threshold ({d:.2}). Try broader keywords.{s}\n\n", .{ YELLOW, MIN_SCORE_THRESHOLD, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "tokenize simple" {
    const tokens = tokenize("Fix compile error in build system");
    try std.testing.expectEqual(@as(usize, 6), tokens.count);
    try std.testing.expect(tokens.contains("fix"));
    try std.testing.expect(tokens.contains("compile"));
    try std.testing.expect(tokens.contains("error"));
    try std.testing.expect(tokens.contains("build"));
    try std.testing.expect(tokens.contains("system"));
    try std.testing.expect(tokens.contains("in"));
}

test "tokenize dedupes" {
    const tokens = tokenize("build build build");
    try std.testing.expectEqual(@as(usize, 1), tokens.count);
    try std.testing.expect(tokens.contains("build"));
}

test "tokenize skips short" {
    const tokens = tokenize("a b cd ef");
    try std.testing.expectEqual(@as(usize, 2), tokens.count);
    try std.testing.expect(tokens.contains("cd"));
    try std.testing.expect(tokens.contains("ef"));
    try std.testing.expect(!tokens.contains("a"));
}

test "tokenize lowercase" {
    const tokens = tokenize("AddDarkMode FEATURE");
    try std.testing.expect(tokens.contains("adddarkmode"));
    try std.testing.expect(tokens.contains("feature"));
}

test "tokenize underscores" {
    const tokens = tokenize("dev_farm_evolve");
    try std.testing.expect(tokens.contains("dev"));
    try std.testing.expect(tokens.contains("farm"));
    try std.testing.expect(tokens.contains("evolve"));
}

test "jaccard identical" {
    var a = TokenSet{};
    a.addUnique("fix");
    a.addUnique("build");
    var b = TokenSet{};
    b.addUnique("fix");
    b.addUnique("build");
    try std.testing.expect(jaccardSimilarity(&a, &b) == 1.0);
}

test "jaccard disjoint" {
    var a = TokenSet{};
    a.addUnique("fix");
    a.addUnique("build");
    var b = TokenSet{};
    b.addUnique("add");
    b.addUnique("dark");
    try std.testing.expect(jaccardSimilarity(&a, &b) == 0.0);
}

test "jaccard partial" {
    var a = TokenSet{};
    a.addUnique("fix");
    a.addUnique("build");
    a.addUnique("error");
    var b = TokenSet{};
    b.addUnique("build");
    b.addUnique("error");
    b.addUnique("log");
    // intersection = {build, error} = 2, union = {fix, build, error, log} = 4
    try std.testing.expect(jaccardSimilarity(&a, &b) == 0.5);
}

test "jaccard empty" {
    const a = TokenSet{};
    const b = TokenSet{};
    try std.testing.expect(jaccardSimilarity(&a, &b) == 0.0);
}

test "scanSpecs finds specs" {
    const allocator = std.testing.allocator;
    var candidates: [MAX_CANDIDATES]SpecCandidate = undefined;
    for (&candidates) |*c| c.* = SpecCandidate{};
    const count = scanSpecs(allocator, &candidates);
    // We know specs/tri/ has many .tri files
    try std.testing.expect(count > 0);
    // First candidate should have a name
    try std.testing.expect(candidates[0].name_len > 0);
    // First candidate should have tokens
    try std.testing.expect(candidates[0].tokens.count > 0);
}

test "findBestTemplate picks highest" {
    const allocator = std.testing.allocator;

    var candidates: [3]SpecCandidate = undefined;
    for (&candidates) |*c| c.* = SpecCandidate{};

    // Candidate 0: "dev farm evolve"
    candidates[0].tokens.addUnique("dev");
    candidates[0].tokens.addUnique("farm");
    candidates[0].tokens.addUnique("evolve");

    // Candidate 1: "swe arena benchmark"
    candidates[1].tokens.addUnique("swe");
    candidates[1].tokens.addUnique("arena");
    candidates[1].tokens.addUnique("benchmark");

    // Candidate 2: "dev pipeline config"
    candidates[2].tokens.addUnique("dev");
    candidates[2].tokens.addUnique("pipeline");
    candidates[2].tokens.addUnique("config");

    // Issue: "dev farm status dashboard"
    const result = findBestTemplate(allocator, "dev farm status dashboard", &candidates, 3);

    // Candidate 0 should win (shares "dev", "farm")
    try std.testing.expect(result.best_index != null);
    try std.testing.expectEqual(@as(usize, 0), result.best_index.?);
    try std.testing.expect(result.best_score > 0.2);
}

test "findBestTemplate returns null below threshold" {
    const allocator = std.testing.allocator;

    var candidates: [1]SpecCandidate = undefined;
    candidates[0] = SpecCandidate{};
    candidates[0].tokens.addUnique("quantum");
    candidates[0].tokens.addUnique("entanglement");

    const result = findBestTemplate(allocator, "fix zig compile warning unused var", &candidates, 1);
    // Completely disjoint → score = 0.0 → null
    try std.testing.expect(result.best_index == null);
}

test "end-to-end scan and match" {
    const allocator = std.testing.allocator;

    var candidates: [MAX_CANDIDATES]SpecCandidate = undefined;
    for (&candidates) |*c| c.* = SpecCandidate{};
    const count = scanSpecs(allocator, &candidates);

    if (count == 0) return; // skip if no specs dir

    // Search for "dev farm evolve" — should match dev_farm or dev_evolve specs
    const result = findBestTemplate(allocator, "dev farm evolve fitness metrics", &candidates, count);
    try std.testing.expect(result.candidates_checked > 0);
    // Should find at least something
    if (result.best_index) |idx| {
        try std.testing.expect(candidates[idx].score > 0.0);
    }
}
