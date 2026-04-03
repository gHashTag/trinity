// @origin(spec:copywright.tri) @regen(pending-impl)
// ═══════════════════════════════════════════════════════════════════════════════════
// AGENT T — Copywright: Technical Content Queen for Social Media
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY
// Role: Generate viral posts for Twitter/X and Reddit after agent work completion
// Personality: Professional, evidence-based, no mysticism
// ═══════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const agent_roles = @import("agent_roles.zig");

// ═════════════════════════════════════════════════════════════════════════════════════════
// TYPES
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════

pub const TwitterThread = struct {
    tweets: []Tweet,
};

pub const Tweet = struct {
    number: usize,
    content: []const u8,
    has_gif: bool = false,
    has_question: bool = false,
};

pub const RedditPost = struct {
    title: []const u8,
    hook: []const u8,
    demo_link: []const u8,
    what_built: [][]const u8,
    tech_stack: [][]const u8,
    lessons_learned: [][]const u8,
    cta: []const u8,
    tags: [][]const u8,
};

pub const PostContent = struct {
    twitter_thread: TwitterThread,
    reddit_post: RedditPost,
};

pub const Config = struct {
    target_subreddits: [][]const u8,
    optimal_times_reddit: []const u8,
    optimal_times_twitter: []const u8,
};

const DEFAULT_CONFIG = Config{
    .target_subreddits = &[_][]const u8{
        "r/programming",
        "r/rust",
        "r/coolgithubprojects",
        "r/MachineLearning",
    },
    .optimal_times_reddit = @as([]const u8, "Tue-Thu 14:00-17:00 UTC"),
    .optimal_times_twitter = @as([]const u8, "Peak audience times (depends on analytics)"),
};

const CONFIG_PATH = ".trinity/copywright/config.json";
const EVENTS_PATH = ".trinity/agent_events.jsonl";

// ═════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

/// Load configuration from file or return defaults
fn loadConfig(allocator: Allocator) !Config {
    std.fs.cwd().makePath(".trinity/copywright") catch {};

    const file = std.fs.cwd().openFile(CONFIG_PATH, .{}) catch |err| switch (err) {
        error.FileNotFound => return DEFAULT_CONFIG,
        else => return err,
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    const parsed = try std.json.parseFromSliceLeaky(Config, content);
    return parsed;
}

/// Save configuration to file
fn saveConfig(allocator: Allocator, config: Config) !void {
    std.fs.cwd().makePath(".trinity/copywright") catch {};

    const json_string = try std.json.stringifyAlloc(allocator, config, .{ .whitespace = .indent_2 });
    defer allocator.free(json_string);

    const file = try std.fs.cwd().createFile(CONFIG_PATH, .{});
    defer file.close();
    try file.writeAll(json_string);
}

/// Extract key highlights from agent output
fn analyzeContent(allocator: Allocator, agent_output: []const u8) ![][]const u8 {
    var highlights = std.ArrayList([]const u8).init(allocator);

    // Look for numbers/percentages (viral-worthy)
    if (std.mem.indexOf(u8, agent_output, "%") != null or
        std.mem.indexOf(u8, agent_output, "x") != null)
    {
        try highlights.append("📊 Metrics-based content detected");
    }

    // Look for key achievement keywords
    const achievement_keywords = [_][]const u8{
        "benchmark", "speedup",  "faster",       "improved",
        "record",    "new",      "breakthrough", "success",
        "deployed",  "released", "launched",
    };

    for (achievement_keywords) |keyword| {
        if (std.mem.indexOf(u8, agent_output, keyword) != null) {
            const keyword_phrase = try std.fmt.allocPrint(allocator, "🏆 Achievement: {s}", .{keyword});
            try highlights.append(keyword_phrase);
            allocator.free(keyword_phrase);
        }
    }

    if (highlights.items.len == 0) {
        try highlights.append("📝 Agent work completed (generic)");
    }

    return highlights.toOwnedSlice();
}

/// Generate Twitter/X thread from highlights
fn generateTwitterThread(allocator: Allocator, highlights: [][]const u8) !TwitterThread {
    var tweets = std.ArrayList(Tweet).init(allocator);

    // Tweet 1: Hook with numbers/curiosity
    const hook = if (highlights.len > 0) highlights[0] else "📝 Agent work completed";
    const hook_display = if (highlights.len > 0) highlights[0] else "";
    try tweets.append(.{
        .number = 1,
        .content = try std.fmt.allocPrint(allocator, "{s}\n\n🧵 {s}", .{ hook, hook_display }),
    });

    // Tweets 2-6: Numbered insights
    const insights_count = @min(highlights.len - 1, 5);
    for (0..insights_count) |i| {
        const insight = if (i + 1 < highlights.len) highlights[i + 1] else "";
        if (insight.len > 0) {
            try tweets.append(.{
                .number = i + 2,
                .content = try std.fmt.allocPrint(allocator, "{d}. {s}", .{ i + 1, insight }),
                .has_question = i == insights_count - 1, // Last insight is a question
            });
        }
    }

    // Tweet 7-8: CTA
    try tweets.append(.{
        .number = insights_count + 2,
        .content = try std.fmt.allocPrint(allocator, "📢 Which of these will you try first?", .{}),
        .has_question = true,
    });

    return TwitterThread{ .tweets = tweets.toOwnedSlice() };
}

/// Generate Reddit post using showcase template
fn generateRedditPost(allocator: Allocator, highlights: [][]const u8, project_name: []const u8) !RedditPost {
    const title_slice = try std.fmt.allocPrint(allocator, "[Trinity]: Agent T ready", .{});
    defer allocator.free(title_slice);

    var what_built = std.ArrayList([]const u8).init(allocator);
    var tech_stack = std.ArrayList([]const u8).init(allocator);
    var lessons_learned = std.ArrayList([]const u8).init(allocator);

    try what_built.append("📝 Generate viral posts from agent work");
    try what_built.append("👑 Twitter/X thread generation (7-8 tweets)");
    try what_built.append("📝 Reddit post generation (showcase template)");
    try what_built.append("🔍 Content analysis and highlight extraction");

    try tech_stack.append("Pure Zig (no external dependencies)");
    try tech_stack.append("VIBEE specification-driven development");

    try lessons_learned.append("Focus on numbers, metrics, and demos");
    try lessons_learned.append("Evidence-based, no speculation");

    var tags = std.ArrayList([]const u8).init(allocator);
    try tags.append("[OC]");
    try tags.append("trinity");
    try tags.append("zig");

    const hook_slice = try std.fmt.allocPrint(allocator, "Technical content queen is now ready! 📢", .{});
    defer allocator.free(hook_slice);

    const cta_slice = try std.fmt.allocPrint(allocator, "Star/fork if useful! Feedback welcome 🚀", .{});
    defer allocator.free(cta_slice);

    return RedditPost{
        .title = title_slice,
        .hook = hook_slice,
        .demo_link = "",
        .what_built = what_built.toOwnedSlice(),
        .tech_stack = tech_stack.toOwnedSlice(),
        .lessons_learned = lessons_learned.toOwnedSlice(),
        .cta = cta_slice,
        .tags = tags.toOwnedSlice(),
    };
}

// ═════════════════════════════════════════════════════════════════════════════════════════
// CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════════════════════

pub fn runCopywrightPostCommand(allocator: Allocator, args: []const []const u8) !void {
    const role_sym = agent_roles.roleSymbol(.copywright);
    std.debug.print("{s}👑 AGENT T — Technical Content Queen{s}\n", .{ role_sym, "\x1b[0m" });

    if (args.len == 0) {
        // Generate posts from latest agent work
        const events_file = try std.fs.cwd().openFile(EVENTS_PATH, .{});
        defer events_file.close();

        const events = try events_file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(events);

        // Parse last event (assume last line is the latest)
        var event_iter = std.mem.splitScalar(u8, events, '\n');
        var last_event: []const u8 = "";
        while (event_iter.next()) |line| {
            if (line.len > 0) last_event = line;
        }

        if (last_event.len == 0) {
            std.debug.print("{s}No agent events found. Run some agent work first.{s}\n", .{ "\x1b[33m", "\x1b[0m" });
            return;
        }

        const highlights = try analyzeContent(allocator, last_event);
        const twitter = try generateTwitterThread(allocator, highlights);
        const reddit = try generateRedditPost(allocator, highlights, "Trinity");

        // Output as JSON for manual review
        const content = PostContent{
            .twitter_thread = twitter,
            .reddit_post = reddit,
        };

        const json = try std.json.stringifyAlloc(allocator, content, .{ .whitespace = .indent_2 });
        defer allocator.free(json);
        std.debug.print("{s}\n{s}{s}\n", .{ json, "\x1b[0m" });
    } else {
        std.debug.print("{s}Usage: tri agent-t post{s}\n", .{ "\x1b[33m", "\x1b[0m" });
    }
}

pub fn runCopywrightReviewCommand(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;

    const role_sym = agent_roles.roleSymbol(.copywright);
    std.debug.print("{s}👑 AGENT T — Review Mode{s}\n", .{ role_sym, "\x1b[0m" });
    std.debug.print("Review generated posts before publishing.\n", .{});
}

pub fn runCopywrightConfigCommand(allocator: Allocator, args: []const []const u8) !void {
    _ = args;

    const role_sym = agent_roles.roleSymbol(.copywright);
    std.debug.print("{s}👑 AGENT T — Configuration{s}\n", .{ role_sym, "\x1b[0m" });

    const config = try loadConfig(allocator);

    std.debug.print("{s}Target subreddits:{s}\n", .{"\x1b[36m"});
    for (config.target_subreddits) |sub| {
        std.debug.print("  - {s}\n", .{sub}, .{});
    }

    std.debug.print("{s}Optimal Reddit time: {s}\n", .{ "\x1b[36m", config.optimal_times_reddit });
    std.debug.print("{s}Optimal Twitter time: {s}{s}\n", .{ "\x1b[36m", config.optimal_times_twitter });
}

// ═══════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "copywright config defaults" {
    const alloc = std.testing.allocator;

    const config = try loadConfig(alloc);
    try std.testing.expectEqual(config.target_subreddits.len, 4);
    try std.testing.expectEqual(config.optimal_times_reddit, "Tue-Thu 14:00-17:00 UTC");
}

test "copywright analyze content" {
    const alloc = std.testing.allocator;
    const output = "Benchmark improved: speed +50%, memory -90%";

    const highlights = try analyzeContent(alloc, output);
    defer {
        for (highlights) |h| alloc.free(h);
        alloc.free(highlights);
    }

    try std.testing.expect(highlights.len > 0);
}

test "copywright generate twitter thread" {
    const alloc = std.testing.allocator;

    const highlights = [_][]const u8{
        "Speed +50%",
        "Memory -90%",
        "New record",
    };

    const thread = try generateTwitterThread(alloc, &highlights);
    defer {
        for (thread.tweets) |t| alloc.free(t.content);
        alloc.free(thread.tweets);
    }

    try std.testing.expect(thread.tweets.len >= 7);
    try std.testing.expect(thread.tweets[0].number == 1);

    // Check last tweet has CTA
    const last_tweet = thread.tweets[thread.tweets.len - 1];
    try std.testing.expect(last_tweet.has_question);
}

test "copywright generate reddit post" {
    const alloc = std.testing.allocator;

    const highlights = [_][]const u8{
        "New feature",
    };

    const post = try generateRedditPost(alloc, &highlights, "Trinity");
    defer {
        for (post.what_built) |item| alloc.free(item);
        for (post.tech_stack) |item| alloc.free(item);
        for (post.lessons_learned) |item| alloc.free(item);
        for (post.tags) |item| alloc.free(item);
        alloc.free(post.what_built);
        alloc.free(post.tech_stack);
        alloc.free(post.lessons_learned);
        alloc.free(post.tags);
        alloc.free(post.title);
        alloc.free(post.hook);
        alloc.free(post.cta);
    }

    try std.testing.expect(std.mem.eql(u8, post.title, "[Trinity]: Agent T ready"));
    try std.testing.expect(post.what_built.len >= 3);
    try std.testing.expect(std.mem.indexOf(u8, post.cta, "Feedback welcome") != null);
}

test "copywright role mapping" {
    const role = agent_roles.agentToRole("copywright");
    try std.testing.expectEqual(role, .copywright);
    const sym = agent_roles.roleSymbol(.copywright);
    try std.testing.expectEqual(sym, "👑");
    const desc = agent_roles.roleDescription(.copywright);
    try std.testing.expect(std.mem.indexOf(u8, desc, "content queen") != null);
}
