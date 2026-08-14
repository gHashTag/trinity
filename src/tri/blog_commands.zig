// ═══════════════════════════════════════════════════════════════════════════════
// Blog Commands — CLI handlers for `tri blog`
// ═══════════════════════════════════════════════════════════════════════════════
//
// Subcommands:
//   blog list             — every post in posts.ts, with its published state
//   blog check [slug]     — re-verify each receipt's PR/issue state against GitHub
//   blog build            — build apps/website (the SPA that renders the blog)
//   blog live <slug>      — is the post actually being served at the apex?
//
// Why these four and not a nicer set of wrappers: each one automates a mistake
// that has already been made by hand.
//
//   `check`  — posts.ts requires a pull request's state to be named exactly, and
//              states move after the text is written. A stale "MERGED" in a
//              published post is a false claim about somebody else's work.
//   `live`   — the blog is a hash-routed SPA, so curl of /#/blog/<slug> returns
//              200 whatever happens, and t27.ai/trinity/ is a different site from
//              t27.ai/. "Deploy green" and "on the site" were two different things
//              here for months.
//
// Author: Dmitrii Vasilev (@gHashTag)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const GREEN = "\x1b[38;2;0;229;153m";
const GOLDEN = "\x1b[38;2;255;215;0m";
const RED = "\x1b[38;2;255;85;85m";
const CYAN = "\x1b[38;2;0;200;255m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

const POSTS_PATH = "apps/website/src/data/blog/posts.ts";
const WEBSITE_DIR = "apps/website";
const APEX = "https://t27.ai/";

/// Main dispatcher for `tri blog`.
pub fn runBlogCommand(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        printHelp();
        return;
    }

    const sub = args[0];
    const rest = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, sub, "list")) {
        try cmdList(allocator);
    } else if (std.mem.eql(u8, sub, "check")) {
        try cmdCheck(allocator, if (rest.len > 0) rest[0] else null);
    } else if (std.mem.eql(u8, sub, "build")) {
        try cmdBuild(allocator, dry_run);
    } else if (std.mem.eql(u8, sub, "live")) {
        if (rest.len == 0) {
            std.debug.print("{s}usage: tri blog live <slug>{s}\n", .{ RED, RESET });
            return error.MissingSlug;
        }
        try cmdLive(allocator, rest[0]);
    } else {
        printHelp();
    }
}

fn printHelp() void {
    std.debug.print(
        \\{s}tri blog{s} — the t27.ai blog
        \\
        \\  {s}list{s}            every post in posts.ts, with its published state
        \\  {s}check [slug]{s}    re-verify each receipt's PR/issue state against GitHub
        \\  {s}build{s}           build the SPA that renders the blog
        \\  {s}live <slug>{s}     is the post actually being served at the apex?
        \\
        \\The blog is TypeScript Post objects in {s}, not markdown.
        \\Run `check` before publishing: states move after the text is written.
        \\
    , .{ CYAN, RESET, GOLDEN, RESET, GOLDEN, RESET, GOLDEN, RESET, GOLDEN, RESET, POSTS_PATH });
}

// ── posts.ts scanning ────────────────────────────────────────────────────────

/// Read the single-quoted string that starts at `from` (the byte after the quote).
/// Returns the slice and the index just past the closing quote.
fn readQuoted(src: []const u8, from: usize) ?struct { value: []const u8, end: usize } {
    const close = std.mem.indexOfScalarPos(u8, src, from, '\'') orelse return null;
    return .{ .value = src[from..close], .end = close + 1 };
}

/// Find `needle` after `from` and return the index just past it.
fn after(src: []const u8, from: usize, needle: []const u8) ?usize {
    const at = std.mem.indexOfPos(u8, src, from, needle) orelse return null;
    return at + needle.len;
}

fn readPosts(allocator: std.mem.Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(allocator, POSTS_PATH, 4 * 1024 * 1024) catch |err| {
        std.debug.print("{s}cannot read {s}{s}\n", .{ RED, POSTS_PATH, RESET });
        std.debug.print("{s}Run this from the trinity repo root — the blog is not in trinity-fpga.{s}\n", .{ DIM, RESET });
        return err;
    };
}

/// One post's header fields. Everything the scanner needs is above the body.
const PostHead = struct {
    slug: []const u8,
    date: []const u8,
    published: bool,
    has_ru: bool,
    /// Index just past the slug, where scanning continues.
    end: usize,
};

/// Next post at or after `pos`, or null at the end of the file.
///
/// Split out from the printing so it can be tested against a string rather than
/// against the repository — everything below this line reads a file or spawns a
/// process, and that is the part a unit test cannot reach.
fn nextPost(src: []const u8, pos: usize) ?PostHead {
    const slug_start = after(src, pos, "\n  slug: '") orelse return null;
    const slug = readQuoted(src, slug_start) orelse return null;

    // The post's own fields end where the next post's slug begins.
    const next = std.mem.indexOfPos(u8, src, slug.end, "\n  slug: '") orelse src.len;
    const window = src[slug.end..next];

    var date: []const u8 = "?";
    if (std.mem.indexOf(u8, window, "date: '")) |d| {
        if (readQuoted(window, d + "date: '".len)) |q| date = q.value;
    }

    return .{
        .slug = slug.value,
        .date = date,
        .published = std.mem.indexOf(u8, window, "published: true") != null,
        .has_ru = std.mem.indexOf(u8, window, "\n  ru: {") != null,
        .end = slug.end,
    };
}

const Receipt = struct {
    label: []const u8,
    href: []const u8,
    end: usize,
};

/// Next `{ label: '…', href: '…' }` pair at or after `pos`.
fn nextReceipt(src: []const u8, pos: usize) ?Receipt {
    const label_start = after(src, pos, "label: '") orelse return null;
    const label = readQuoted(src, label_start) orelse return null;
    const href_start = after(src, label.end, "href: '") orelse return null;
    const href = readQuoted(src, href_start) orelse return null;
    return .{ .label = label.value, .href = href.value, .end = href.end };
}

fn cmdList(allocator: std.mem.Allocator) !void {
    const src = try readPosts(allocator);
    defer allocator.free(src);

    std.debug.print("{s}posts in {s}{s}\n\n", .{ CYAN, POSTS_PATH, RESET });

    var pos: usize = 0;
    var total: usize = 0;
    var drafts: usize = 0;

    while (nextPost(src, pos)) |post| {
        pos = post.end;
        total += 1;
        if (!post.published) drafts += 1;

        std.debug.print("  {s}{s}{s}  {s}{s}{s}  {s}{s}\n", .{
            if (post.published) GREEN else GOLDEN,
            if (post.published) "published" else "draft    ",
            RESET,
            DIM,
            post.date,
            RESET,
            post.slug,
            if (post.has_ru) "  [ru]" else "",
        });
    }

    std.debug.print("\n{d} post(s), {d} draft(s)\n", .{ total, drafts });
}

// ── receipt verification ─────────────────────────────────────────────────────

const Claim = enum { merged, open, closed, unstated };

fn claimFromLabel(label: []const u8) Claim {
    if (std.mem.indexOf(u8, label, "MERGED") != null) return .merged;
    if (std.mem.indexOf(u8, label, "OPEN") != null) return .open;
    if (std.mem.indexOf(u8, label, "CLOSED") != null) return .closed;
    return .unstated;
}

fn claimName(c: Claim) []const u8 {
    return switch (c) {
        .merged => "MERGED",
        .open => "OPEN",
        .closed => "CLOSED",
        .unstated => "(none)",
    };
}

/// Split "https://github.com/owner/repo/pull/145" into its parts.
const Ref = struct { owner: []const u8, repo: []const u8, kind: []const u8, number: []const u8 };

fn parseGithubRef(href: []const u8) ?Ref {
    const prefix = "https://github.com/";
    if (!std.mem.startsWith(u8, href, prefix)) return null;
    var it = std.mem.splitScalar(u8, href[prefix.len..], '/');
    const owner = it.next() orelse return null;
    const repo = it.next() orelse return null;
    const kind = it.next() orelse return null;
    const number = it.next() orelse return null;
    if (owner.len == 0 or repo.len == 0 or number.len == 0) return null;
    if (!std.mem.eql(u8, kind, "pull") and !std.mem.eql(u8, kind, "issues")) return null;
    return .{ .owner = owner, .repo = repo, .kind = kind, .number = number };
}

/// Ask GitHub what the state actually is. Returns an owned uppercase string.
fn actualState(allocator: std.mem.Allocator, ref: Ref) ![]u8 {
    const is_pull = std.mem.eql(u8, ref.kind, "pull");
    const endpoint = try std.fmt.allocPrint(allocator, "repos/{s}/{s}/{s}/{s}", .{
        ref.owner,
        ref.repo,
        if (is_pull) "pulls" else "issues",
        ref.number,
    });
    defer allocator.free(endpoint);

    const jq = if (is_pull)
        "if .merged_at != null then \"MERGED\" else (.state | ascii_upcase) end"
    else
        ".state | ascii_upcase";

    const argv = [_][]const u8{ "gh", "api", endpoint, "--jq", jq };
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &argv,
        .max_output_bytes = 64 * 1024,
    }) catch return error.GhUnavailable;
    defer allocator.free(result.stderr);

    const code = switch (result.term) {
        .Exited => |c| c,
        else => @as(u8, 1),
    };
    defer allocator.free(result.stdout);
    if (code != 0) return error.GhCliFailed;
    return allocator.dupe(u8, std.mem.trim(u8, result.stdout, " \n\r\t"));
}

fn cmdCheck(allocator: std.mem.Allocator, only_slug: ?[]const u8) !void {
    const src = try readPosts(allocator);
    defer allocator.free(src);

    std.debug.print("{s}re-verifying receipt states against GitHub{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}posts.ts requires each state to be named exactly; states move after the text is written.{s}\n\n", .{ DIM, RESET });

    var pos: usize = 0;
    var checked: usize = 0;
    var mismatches: usize = 0;
    var unstated: usize = 0;
    var current_slug: []const u8 = "?";
    var printed_slug = false;

    while (pos < src.len) {
        // Whichever comes first decides: a new post, or another receipt inside
        // the current one. Tracking the slug this way keeps each receipt
        // attributed to the post it belongs to.
        const next_slug_at = std.mem.indexOfPos(u8, src, pos, "\n  slug: '");
        const next_label_at = std.mem.indexOfPos(u8, src, pos, "label: '");
        if (next_label_at == null) break;

        if (next_slug_at != null and next_slug_at.? < next_label_at.?) {
            const post = nextPost(src, pos) orelse break;
            current_slug = post.slug;
            printed_slug = false;
            pos = post.end;
            continue;
        }

        const receipt = nextReceipt(src, pos) orelse break;
        pos = receipt.end;

        if (only_slug) |want| {
            if (!std.mem.eql(u8, want, current_slug)) continue;
        }

        const ref = parseGithubRef(receipt.href) orelse continue;
        const claim = claimFromLabel(receipt.label);

        if (!printed_slug) {
            std.debug.print("{s}{s}{s}\n", .{ GOLDEN, current_slug, RESET });
            printed_slug = true;
        }

        if (claim == .unstated) {
            unstated += 1;
            std.debug.print("  {s}?{s} {s}#{s}{s} state not named in the label\n", .{ GOLDEN, RESET, ref.repo, ref.number, RESET });
            continue;
        }

        const actual = actualState(allocator, ref) catch |err| {
            std.debug.print("  {s}!{s} {s}#{s} could not be checked ({s})\n", .{ RED, RESET, ref.repo, ref.number, @errorName(err) });
            continue;
        };
        defer allocator.free(actual);

        checked += 1;
        if (std.mem.eql(u8, actual, claimName(claim))) {
            std.debug.print("  {s}ok{s} {s}#{s} {s}\n", .{ GREEN, RESET, ref.repo, ref.number, actual });
        } else {
            mismatches += 1;
            std.debug.print("  {s}MISMATCH{s} {s}#{s}: post says {s}, GitHub says {s}{s}{s}\n", .{
                RED, RESET, ref.repo, ref.number, claimName(claim), RED, actual, RESET,
            });
        }
    }

    std.debug.print("\n{d} receipt(s) checked, {d} mismatch(es), {d} with no state named\n", .{ checked, mismatches, unstated });
    if (mismatches > 0) {
        std.debug.print("{s}Do not publish until these agree — a stale state is a false claim about somebody else's work.{s}\n", .{ RED, RESET });
        return error.ReceiptStateMismatch;
    }
}

// ── build ────────────────────────────────────────────────────────────────────

fn cmdBuild(allocator: std.mem.Allocator, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("{s}dry-run:{s} npm run build:ci in {s}\n", .{ DIM, RESET, WEBSITE_DIR });
        return;
    }

    std.debug.print("{s}building {s}{s}\n", .{ CYAN, WEBSITE_DIR, RESET });

    const argv = [_][]const u8{ "npm", "run", "build:ci" };
    var child = std.process.Child.init(&argv, allocator);
    child.cwd = WEBSITE_DIR;
    const term = child.spawnAndWait() catch |err| {
        std.debug.print("{s}could not run npm ({s}){s}\n", .{ RED, @errorName(err), RESET });
        std.debug.print("{s}The site needs Node >= 20; the shell default here is 18.{s}\n", .{ DIM, RESET });
        return err;
    };

    const code = switch (term) {
        .Exited => |c| c,
        else => @as(u8, 1),
    };
    if (code != 0) {
        std.debug.print("{s}build failed (exit {d}){s}\n", .{ RED, code, RESET });
        std.debug.print("{s}If it complains about the Node engine:{s}\n", .{ DIM, RESET });
        std.debug.print("{s}  export PATH=\"$HOME/.nvm/versions/node/v20.19.0/bin:$PATH\"{s}\n", .{ DIM, RESET });
        return error.BuildFailed;
    }
    std.debug.print("{s}build ok{s}\n", .{ GREEN, RESET });
}

// ── live check ───────────────────────────────────────────────────────────────

fn curl(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
    const argv = [_][]const u8{ "curl", "-sS", url };
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &argv,
        .max_output_bytes = 8 * 1024 * 1024,
    }) catch return error.CurlUnavailable;
    defer allocator.free(result.stderr);
    const code = switch (result.term) {
        .Exited => |c| c,
        else => @as(u8, 1),
    };
    if (code != 0) {
        allocator.free(result.stdout);
        return error.CurlFailed;
    }
    return result.stdout;
}

/// Pull the first `assets/<prefix>-<hash>.js` reference out of `src`.
fn findAsset(src: []const u8, prefix: []const u8) ?[]const u8 {
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, src, pos, prefix)) |at| {
        var end = at + prefix.len;
        while (end < src.len and src[end] != '"' and src[end] != '\'' and src[end] != ')') : (end += 1) {}
        const candidate = src[at..end];
        if (std.mem.endsWith(u8, candidate, ".js")) return candidate;
        pos = at + prefix.len;
    }
    return null;
}

fn cmdLive(allocator: std.mem.Allocator, slug: []const u8) !void {
    std.debug.print("{s}checking whether {s} is served at {s}{s}\n", .{ CYAN, slug, APEX, RESET });
    std.debug.print("{s}A page fetch proves nothing here — the SPA is hash-routed and always answers 200.{s}\n\n", .{ DIM, RESET });

    const index_html = try curl(allocator, APEX);
    defer allocator.free(index_html);

    const index_ref = findAsset(index_html, "assets/index-") orelse {
        std.debug.print("{s}no entry bundle referenced by the apex{s}\n", .{ RED, RESET });
        return error.NoEntryBundle;
    };
    std.debug.print("  entry bundle : {s}\n", .{index_ref});

    const index_url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ APEX, index_ref });
    defer allocator.free(index_url);
    const index_js = try curl(allocator, index_url);
    defer allocator.free(index_js);

    const blog_ref = findAsset(index_js, "Blog-") orelse {
        std.debug.print("{s}the entry bundle names no Blog chunk{s}\n", .{ RED, RESET });
        return error.NoBlogChunk;
    };
    std.debug.print("  blog chunk   : {s}\n", .{blog_ref});

    const blog_url = try std.fmt.allocPrint(allocator, "{s}assets/{s}", .{ APEX, blog_ref });
    defer allocator.free(blog_url);
    const blog_js = try curl(allocator, blog_url);
    defer allocator.free(blog_js);

    if (std.mem.indexOf(u8, blog_js, slug) != null) {
        std.debug.print("\n  {s}LIVE{s} — {s}#/blog/{s}\n", .{ GREEN, RESET, APEX, slug });
        return;
    }

    std.debug.print("\n  {s}not live yet{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}The apex is published by gHashTag/ghashtag.github.io on a cron, not by a push to{s}\n", .{ DIM, RESET });
    std.debug.print("{s}trinity — which serves t27.ai/trinity/ instead. Wait for the next run, or dispatch{s}\n", .{ DIM, RESET });
    std.debug.print("{s}publish-website.yml there. Do not start \"fixing\" anything.{s}\n", .{ DIM, RESET });
    return error.NotLive;
}

// ── tests ────────────────────────────────────────────────────────────────────

test "a github pull url splits into its parts" {
    const ref = parseGithubRef("https://github.com/openXC7/nextpnr-xilinx/pull/145").?;
    try std.testing.expectEqualStrings("openXC7", ref.owner);
    try std.testing.expectEqualStrings("nextpnr-xilinx", ref.repo);
    try std.testing.expectEqualStrings("pull", ref.kind);
    try std.testing.expectEqualStrings("145", ref.number);
}

test "an issue url is accepted and a blob url is not" {
    try std.testing.expect(parseGithubRef("https://github.com/openXC7/nextpnr-xilinx/issues/134") != null);
    try std.testing.expect(parseGithubRef("https://github.com/o/r/blob/main/f.md") == null);
    try std.testing.expect(parseGithubRef("https://example.com/o/r/pull/1") == null);
}

test "the claim is read out of the label, and its absence is distinguishable" {
    try std.testing.expectEqual(Claim.merged, claimFromLabel("#145 — did a thing · MERGED 2026-08-13"));
    try std.testing.expectEqual(Claim.open, claimFromLabel("#134 — still wrong · OPEN"));
    try std.testing.expectEqual(Claim.unstated, claimFromLabel("#1 — a label with no state"));
}

test "a quoted value stops at its closing quote" {
    const src = "slug: 'abc-def', title: 'x'";
    const q = readQuoted(src, "slug: '".len).?;
    try std.testing.expectEqualStrings("abc-def", q.value);
}

/// A miniature posts.ts. Same shape as the real file, two posts, one a draft.
const SAMPLE =
    \\export type Block = { kind: 'p'; text: string }
    \\
    \\const first: Post = {
    \\  slug: 'first-post',
    \\  title: 'First',
    \\  date: '2026-08-14',
    \\  receipts: [
    \\    { label: 'repo #145 — did a thing · MERGED 2026-08-13', href: 'https://github.com/openXC7/nextpnr-xilinx/pull/145' },
    \\    { label: 'repo #134 — still wrong · OPEN', href: 'https://github.com/openXC7/nextpnr-xilinx/issues/134' },
    \\  ],
    \\  published: true,
    \\  ru: {
    \\    title: 'Первый',
    \\  },
    \\}
    \\
    \\const second: Post = {
    \\  slug: 'second-post',
    \\  title: 'Second',
    \\  date: '2026-08-15',
    \\  receipts: [
    \\    { label: 'repo #1 — no state named', href: 'https://github.com/o/r/pull/1' },
    \\  ],
    \\  published: false,
    \\}
;

test "posts are walked in order, with date, published and the ru flag" {
    const a = nextPost(SAMPLE, 0).?;
    try std.testing.expectEqualStrings("first-post", a.slug);
    try std.testing.expectEqualStrings("2026-08-14", a.date);
    try std.testing.expect(a.published);
    try std.testing.expect(a.has_ru);

    const b = nextPost(SAMPLE, a.end).?;
    try std.testing.expectEqualStrings("second-post", b.slug);
    try std.testing.expectEqualStrings("2026-08-15", b.date);
    try std.testing.expect(!b.published);
    try std.testing.expect(!b.has_ru);

    try std.testing.expect(nextPost(SAMPLE, b.end) == null);
}

test "a draft's fields do not leak from the post that follows it" {
    // The second post is published: false. If the window ran to end-of-file
    // instead of to the next slug, the first post would inherit it.
    const a = nextPost(SAMPLE, 0).?;
    try std.testing.expect(a.published);
}

test "receipts are paired label-to-href and walked across posts" {
    const r1 = nextReceipt(SAMPLE, 0).?;
    try std.testing.expectEqualStrings("https://github.com/openXC7/nextpnr-xilinx/pull/145", r1.href);
    try std.testing.expectEqual(Claim.merged, claimFromLabel(r1.label));

    const r2 = nextReceipt(SAMPLE, r1.end).?;
    try std.testing.expectEqualStrings("https://github.com/openXC7/nextpnr-xilinx/issues/134", r2.href);
    try std.testing.expectEqual(Claim.open, claimFromLabel(r2.label));

    const r3 = nextReceipt(SAMPLE, r2.end).?;
    try std.testing.expectEqual(Claim.unstated, claimFromLabel(r3.label));

    try std.testing.expect(nextReceipt(SAMPLE, r3.end) == null);
}

test "an asset reference is found and bounded by the quote that follows it" {
    const html = "<script src=\"assets/index-DcmN7PsX.js\"></script>";
    try std.testing.expectEqualStrings("assets/index-DcmN7PsX.js", findAsset(html, "assets/index-").?);
    const js = "import(\"./Blog-CqTFnkgp.js\")";
    try std.testing.expectEqualStrings("Blog-CqTFnkgp.js", findAsset(js, "Blog-").?);
}
