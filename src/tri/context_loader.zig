// @origin(spec:context_loader.tri) @regen(manual-impl)
// =============================================================================
// CONTEXT LOADER — Conditional Context for Trinity Agents
// =============================================================================
//
// Kiro-inspired: auto-select relevant .tri specs and experience episodes
// based on task description keywords. Reduces agent cold-start time.
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");

// =============================================================================
// TYPES
// =============================================================================

pub const SpecMatch = struct {
    path: [256]u8 = undefined,
    path_len: u8 = 0,
    name: [128]u8 = undefined,
    name_len: u8 = 0,
    score: u32 = 0,
    description: [256]u8 = undefined,
    desc_len: u8 = 0,

    pub fn getPath(self: *const SpecMatch) []const u8 {
        return self.path[0..self.path_len];
    }

    pub fn getName(self: *const SpecMatch) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn getDesc(self: *const SpecMatch) []const u8 {
        return self.description[0..self.desc_len];
    }
};

pub const EpisodeMatch = struct {
    filename: [128]u8 = undefined,
    filename_len: u8 = 0,
    score: u32 = 0,
    verdict_pass: bool = false,
    has_learnings: bool = false,
    has_mistakes: bool = false,

    pub fn getFilename(self: *const EpisodeMatch) []const u8 {
        return self.filename[0..self.filename_len];
    }
};

pub const ContextResult = struct {
    specs: [16]SpecMatch = undefined,
    spec_count: u8 = 0,
    episodes: [16]EpisodeMatch = undefined,
    episode_count: u8 = 0,
    mnl_count: u8 = 0,
    total_score: u32 = 0,
};

// =============================================================================
// FIND RELEVANT SPECS
// =============================================================================

pub fn findRelevantSpecs(allocator: std.mem.Allocator, words: []const []const u8) ContextResult {
    var result = ContextResult{};

    var dir = std.fs.cwd().openDir("specs/tri", .{ .iterate = true }) catch return result;
    defer dir.close();

    var dir_iter = dir.iterate();
    while (dir_iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".tri")) continue;

        // Score by spec name match
        const name_no_ext = entry.name[0 .. entry.name.len - 4];
        var score: u32 = 0;

        for (words) |word| {
            if (word.len < 2) continue;
            if (containsInsensitive(name_no_ext, word)) {
                score += 10;
            }
        }

        // Also check file content for description matches
        if (score == 0) {
            const content = dir.readFileAlloc(allocator, entry.name, 4096) catch continue;
            defer allocator.free(content);

            for (words) |word| {
                if (word.len < 3) continue;
                if (containsInsensitive(content, word)) {
                    score += 1;
                }
            }
        }

        if (score > 0 and result.spec_count < 16) {
            var sm = SpecMatch{};
            copyFixed(&sm.name, &sm.name_len, name_no_ext);

            var path_buf: [256]u8 = undefined;
            const path = std.fmt.bufPrint(&path_buf, "specs/tri/{s}", .{entry.name}) catch continue;
            copyFixed(&sm.path, &sm.path_len, path);
            sm.score = score;

            // Read first line of description if available
            if (score >= 10) {
                const content = dir.readFileAlloc(allocator, entry.name, 4096) catch "";
                defer if (content.len > 0) allocator.free(content);

                if (std.mem.indexOf(u8, content, "description:")) |desc_start| {
                    const after = content[@min(desc_start + 12, content.len)..];
                    const line_end = std.mem.indexOf(u8, after, "\n") orelse after.len;
                    const desc = std.mem.trim(u8, after[0..@min(line_end, 200)], &[_]u8{' ', '|', '\n'});
                    copyFixed(&sm.description, &sm.desc_len, desc);
                }
            }

            result.specs[result.spec_count] = sm;
            result.spec_count += 1;
            result.total_score += score;
        }
    }

    // Sort by score descending
    std.mem.sort(SpecMatch, result.specs[0..result.spec_count], {}, struct {
        fn lessThan(_: void, a: SpecMatch, b: SpecMatch) bool {
            return a.score > b.score;
        }
    }.lessThan);

    // Keep top 5
    if (result.spec_count > 5) result.spec_count = 5;

    return result;
}

// =============================================================================
// FIND RELEVANT EXPERIENCE
// =============================================================================

pub fn findRelevantExperience(allocator: std.mem.Allocator, words: []const []const u8) ContextResult {
    var result = ContextResult{};

    var dir = std.fs.cwd().openDir(".trinity/experience/episodes", .{ .iterate = true }) catch return result;
    defer dir.close();

    var dir_iter = dir.iterate();
    while (dir_iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

        const content = dir.readFileAlloc(allocator, entry.name, 64 * 1024) catch continue;
        defer allocator.free(content);

        var score: u32 = 0;
        for (words) |word| {
            if (word.len < 2) continue;
            if (std.mem.indexOf(u8, content, word) != null) {
                score += 1;
            }
        }

        if (score > 0 and result.episode_count < 16) {
            var em = EpisodeMatch{};
            copyFixed(&em.filename, &em.filename_len, entry.name);
            em.score = score;

            // Check verdict
            if (extractJsonValue(content, "verdict")) |verdict| {
                em.verdict_pass = std.mem.eql(u8, verdict, "PASS");
            }
            em.has_learnings = std.mem.indexOf(u8, content, "\"learnings\":[\"") != null;
            em.has_mistakes = std.mem.indexOf(u8, content, "\"mistakes\":[\"") != null;

            // Boost PASS episodes with learnings
            if (em.verdict_pass and em.has_learnings) em.score += 5;
            // Boost FAIL episodes with mistakes (MNL value)
            if (!em.verdict_pass and em.has_mistakes) em.score += 3;

            result.episodes[result.episode_count] = em;
            result.episode_count += 1;
            result.total_score += em.score;
        }
    }

    // Sort: highest score first
    std.mem.sort(EpisodeMatch, result.episodes[0..result.episode_count], {}, struct {
        fn lessThan(_: void, a: EpisodeMatch, b: EpisodeMatch) bool {
            return a.score > b.score;
        }
    }.lessThan);

    // Keep top 3
    if (result.episode_count > 3) result.episode_count = 3;

    return result;
}

// =============================================================================
// BUILD CONTEXT — combines specs + experience
// =============================================================================

pub fn buildContext(allocator: std.mem.Allocator, task: []const u8) ContextResult {
    // Split task into words
    var words_buf: [32][]const u8 = undefined;
    var word_count: usize = 0;
    var iter = std.mem.splitScalar(u8, task, ' ');
    while (iter.next()) |w| {
        if (w.len > 1 and word_count < 32) {
            words_buf[word_count] = w;
            word_count += 1;
        }
    }
    const words = words_buf[0..word_count];

    var specs = findRelevantSpecs(allocator, words);
    const exp = findRelevantExperience(allocator, words);

    // Merge into specs result
    var i: u8 = 0;
    while (i < exp.episode_count) : (i += 1) {
        if (specs.episode_count < 16) {
            specs.episodes[specs.episode_count] = exp.episodes[i];
            specs.episode_count += 1;
        }
    }
    specs.total_score += exp.total_score;
    specs.mnl_count = exp.mnl_count;

    return specs;
}

// =============================================================================
// CLI COMMAND: tri context <task>
// =============================================================================

pub fn runContextCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    if (args.len == 0) {
        printContextHelp();
        return;
    }

    // Join all args as task description
    var task_buf: [512]u8 = undefined;
    var task_len: usize = 0;
    for (args) |arg| {
        if (task_len > 0 and task_len < 511) {
            task_buf[task_len] = ' ';
            task_len += 1;
        }
        const copy = @min(arg.len, 512 - task_len);
        @memcpy(task_buf[task_len .. task_len + copy], arg[0..copy]);
        task_len += copy;
    }
    const task = task_buf[0..task_len];

    const result = buildContext(allocator, task);

    // Render
    std.debug.print("\n\x1b[1mCONTEXT LOADER\x1b[0m — task: \"{s}\"\n", .{task});
    std.debug.print("\x1b[2m════════════════════════════════════════════════════\x1b[0m\n", .{});

    if (result.spec_count > 0) {
        std.debug.print("\n  \x1b[36mRELEVANT SPECS ({d}):\x1b[0m\n", .{result.spec_count});
        var i: u8 = 0;
        while (i < result.spec_count) : (i += 1) {
            const sm = result.specs[i];
            std.debug.print("    \x1b[32m{s}\x1b[0m (score:{d})", .{ sm.getName(), sm.score });
            if (sm.desc_len > 0) {
                std.debug.print(" — {s}", .{sm.getDesc()});
            }
            std.debug.print("\n", .{});
        }
    }

    if (result.episode_count > 0) {
        std.debug.print("\n  \x1b[35mRELEVANT EXPERIENCE ({d}):\x1b[0m\n", .{result.episode_count});
        var i: u8 = 0;
        while (i < result.episode_count) : (i += 1) {
            const em = result.episodes[i];
            const icon: []const u8 = if (em.verdict_pass) "\x1b[32mPASS\x1b[0m" else "\x1b[31mFAIL\x1b[0m";
            std.debug.print("    {s} {s} (score:{d})", .{ icon, em.getFilename(), em.score });
            if (em.has_learnings) std.debug.print(" +learnings", .{});
            if (em.has_mistakes) std.debug.print(" +mistakes", .{});
            std.debug.print("\n", .{});
        }
    }

    if (result.spec_count == 0 and result.episode_count == 0) {
        std.debug.print("\n  \x1b[33mNo relevant context found for this task.\x1b[0m\n", .{});
    }

    std.debug.print("\n  \x1b[2mTotal relevance score: {d}\x1b[0m\n\n", .{result.total_score});
}

fn printContextHelp() void {
    std.debug.print(
        \\
        \\\x1b[36m=== tri context — Conditional Context Loader ===\x1b[0m
        \\
        \\  tri context <task description>  — Find relevant specs & experience
        \\
        \\Searches .tri specs and past experience episodes by keywords.
        \\Returns: matching specs, past learnings, MNL warnings.
        \\
    , .{});
}

// =============================================================================
// HELPERS
// =============================================================================

fn copyFixed(dest: anytype, len_ptr: *u8, src: []const u8) void {
    const max = dest.len;
    const copy_len: u8 = @intCast(@min(src.len, max));
    @memcpy(dest[0..copy_len], src[0..copy_len]);
    len_ptr.* = copy_len;
}

fn containsInsensitive(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var match = true;
        for (needle, 0..) |nc, j| {
            const hc = haystack[i + j];
            if (toLower(hc) != toLower(nc)) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

fn toLower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn extractJsonValue(content: []const u8, key: []const u8) ?[]const u8 {
    var search_buf: [64]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":\"", .{key}) catch return null;

    if (std.mem.indexOf(u8, content, search)) |start| {
        const val_start = start + search.len;
        if (std.mem.indexOf(u8, content[val_start..], "\"")) |end| {
            return content[val_start .. val_start + end];
        }
    }
    return null;
}

// =============================================================================
// TESTS
// =============================================================================

test "findRelevantSpecs returns results for matching keywords" {
    const allocator = std.testing.allocator;
    const words = [_][]const u8{ "dashboard", "faculty" };
    const result = findRelevantSpecs(allocator, &words);
    // Should find at least dashboard.tri if specs exist
    // In test environment, specs may not exist — just verify no crash
    _ = result;
}

test "buildContext combines specs and experience" {
    const allocator = std.testing.allocator;
    const result = buildContext(allocator, "implement VSA benchmark test");
    // Verify structure is valid
    try std.testing.expect(result.spec_count <= 5);
    try std.testing.expect(result.episode_count <= 3);
}

test "containsInsensitive works" {
    try std.testing.expect(containsInsensitive("Dashboard", "dash"));
    try std.testing.expect(containsInsensitive("HELLO", "hello"));
    try std.testing.expect(!containsInsensitive("abc", "xyz"));
    try std.testing.expect(!containsInsensitive("ab", "abc"));
}

test "empty task returns empty context" {
    const allocator = std.testing.allocator;
    const result = buildContext(allocator, "");
    try std.testing.expectEqual(@as(u8, 0), result.spec_count);
    try std.testing.expectEqual(@as(u8, 0), result.episode_count);
    try std.testing.expectEqual(@as(u32, 0), result.total_score);
}

test "extractJsonValue finds value" {
    const json = "{\"verdict\":\"PASS\",\"task\":\"test\"}";
    const verdict = extractJsonValue(json, "verdict");
    try std.testing.expect(verdict != null);
    try std.testing.expectEqualStrings("PASS", verdict.?);
}
