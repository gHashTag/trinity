// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI ZENODO — DOI Publishing CLI
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri zenodo publish <version>  — create new version, upload, publish
//   tri zenodo status             — show current record info
//   tri zenodo draft <version>    — create draft without publishing
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const print = std.debug.print;

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";
const GOLDEN = "\x1b[38;5;220m";

const RECORD_ID = "18947017";
const API = "https://zenodo.org/api";

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runZenodoCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printHelp();
        return;
    }

    const subcmd = args[0];
    const sub_args = args[1..];

    if (std.mem.eql(u8, subcmd, "publish")) {
        const version = if (sub_args.len > 0) sub_args[0] else {
            print("{s}Usage: tri zenodo publish <version>{s}\n", .{ RED, RESET });
            print("  Example: tri zenodo publish v2.0.4\n", .{});
            return;
        };
        try runPublish(allocator, version, true);
    } else if (std.mem.eql(u8, subcmd, "draft")) {
        const version = if (sub_args.len > 0) sub_args[0] else {
            print("{s}Usage: tri zenodo draft <version>{s}\n", .{ RED, RESET });
            return;
        };
        try runPublish(allocator, version, false);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        try runStatus(allocator);
    } else {
        print("{s}Unknown subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

fn printHelp() void {
    print("\n{s}{s}🔬 TRI ZENODO — DOI Publishing{s}\n\n", .{ GOLDEN, BOLD, RESET });
    print("  tri zenodo publish <version>  Create new version, upload, publish\n", .{});
    print("  tri zenodo status             Show current record info\n", .{});
    print("  tri zenodo draft <version>    Create draft without publishing\n\n", .{});
    print("  Requires ZENODO_TOKEN in .env\n", .{});
    print("  Record: {s}\n\n", .{RECORD_ID});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN LOADING
// ═══════════════════════════════════════════════════════════════════════════════

fn loadToken(allocator: std.mem.Allocator) ![]const u8 {
    // Try env var first
    if (std.process.getEnvVarOwned(allocator, "ZENODO_TOKEN")) |token| {
        return token;
    } else |_| {}

    // Fall back to .env file
    const file = std.fs.cwd().openFile(".env", .{}) catch {
        print("{s}❌ ZENODO_TOKEN not set and .env not found{s}\n", .{ RED, RESET });
        print("   Get token: https://zenodo.org/account/settings/applications/tokens/new/\n", .{});
        return error.TokenNotFound;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 16384) catch return error.TokenNotFound;
    defer allocator.free(content);

    // Find ZENODO_TOKEN=xxx line
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.startsWith(u8, trimmed, "ZENODO_TOKEN=")) {
            const val = trimmed["ZENODO_TOKEN=".len..];
            return allocator.dupe(u8, val);
        }
    }

    print("{s}❌ ZENODO_TOKEN not found in .env{s}\n", .{ RED, RESET });
    return error.TokenNotFound;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CURL HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn curlGet(allocator: std.mem.Allocator, url: []const u8, token: []const u8) ![]u8 {
    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", url, "-H", auth },
    });
    defer allocator.free(result.stderr);
    return result.stdout;
}

fn curlPost(allocator: std.mem.Allocator, url: []const u8, token: []const u8, body: ?[]const u8) ![]u8 {
    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);

    if (body) |b| {
        const result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "curl", "-s", "-X", "POST", url, "-H", auth, "-H", "Content-Type: application/json", "-d", b },
        });
        defer allocator.free(result.stderr);
        return result.stdout;
    } else {
        const result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "curl", "-s", "-X", "POST", url, "-H", auth, "-H", "Content-Type: application/json" },
        });
        defer allocator.free(result.stderr);
        return result.stdout;
    }
}

fn curlPut(allocator: std.mem.Allocator, url: []const u8, token: []const u8, body: []const u8) ![]u8 {
    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "PUT", url, "-H", auth, "-H", "Content-Type: application/json", "-d", body },
    });
    defer allocator.free(result.stderr);
    return result.stdout;
}

fn curlUpload(allocator: std.mem.Allocator, url: []const u8, token: []const u8, filepath: []const u8) ![]u8 {
    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);

    const data_arg = try std.fmt.allocPrint(allocator, "@{s}", .{filepath});
    defer allocator.free(data_arg);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "PUT", url, "-H", auth, "-H", "Content-Type: application/octet-stream", "--data-binary", data_arg },
    });
    defer allocator.free(result.stderr);
    return result.stdout;
}

fn curlDelete(allocator: std.mem.Allocator, url: []const u8, token: []const u8) !void {
    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "DELETE", url, "-H", auth },
    });
    allocator.free(result.stdout);
    allocator.free(result.stderr);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMPLE JSON EXTRACT (no parser needed — find "key":"value")
// ═══════════════════════════════════════════════════════════════════════════════

fn jsonExtractString(json: []const u8, key: []const u8) ?[]const u8 {
    // Simple approach: find "key" then find next quoted string
    var search_key_buf: [128]u8 = undefined;
    const search_key = std.fmt.bufPrint(&search_key_buf, "\"{s}\"", .{key}) catch return null;

    const key_pos = std.mem.indexOf(u8, json, search_key) orelse return null;
    const after_key = json[key_pos + search_key.len ..];

    // Skip : and whitespace
    var i: usize = 0;
    while (i < after_key.len and (after_key[i] == ':' or after_key[i] == ' ' or after_key[i] == '\t')) : (i += 1) {}

    if (i >= after_key.len) return null;

    // Check if it's a string value
    if (after_key[i] == '"') {
        const start = i + 1;
        const end = std.mem.indexOfPos(u8, after_key, start, "\"") orelse return null;
        return after_key[start..end];
    }

    // Check if it's a number
    if (after_key[i] >= '0' and after_key[i] <= '9') {
        const start = i;
        var end = start;
        while (end < after_key.len and after_key[end] >= '0' and after_key[end] <= '9') : (end += 1) {}
        return after_key[start..end];
    }

    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn runStatus(allocator: std.mem.Allocator) !void {
    const token = try loadToken(allocator);
    defer allocator.free(token);

    print("\n{s}{s}🔬 ZENODO RECORD STATUS{s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    const url = try std.fmt.allocPrint(allocator, "{s}/records/{s}", .{ API, RECORD_ID });
    defer allocator.free(url);

    const response = try curlGet(allocator, url, token);
    defer allocator.free(response);

    const title = jsonExtractString(response, "title") orelse "unknown";
    const doi = jsonExtractString(response, "doi") orelse "unknown";
    const version = jsonExtractString(response, "version") orelse "unknown";
    const created = jsonExtractString(response, "created") orelse "unknown";

    // Extract stats
    const views = jsonExtractString(response, "views") orelse "0";
    const downloads = jsonExtractString(response, "downloads") orelse "0";

    print("\n   📄 Title:     {s}\n", .{title});
    print("   🏷️  DOI:       {s}\n", .{doi});
    print("   📦 Version:   {s}\n", .{version});
    print("   📅 Created:   {s}\n", .{created});
    print("   👁️  Views:     {s}\n", .{views});
    print("   ⬇️  Downloads: {s}\n", .{downloads});
    print("   🔗 URL:       https://doi.org/{s}\n\n", .{doi});
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLISH / DRAFT COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn runPublish(allocator: std.mem.Allocator, version: []const u8, do_publish: bool) !void {
    const token = try loadToken(allocator);
    defer allocator.free(token);

    const action_name = if (do_publish) "PUBLISH" else "DRAFT";
    print("\n{s}{s}🔬 ZENODO {s} — {s}{s}\n", .{ GOLDEN, BOLD, action_name, version, RESET });
    print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    // Step 1: Create new version draft
    print("📝 Step 1/5: Creating new version draft...\n", .{});
    const versions_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/versions", .{ API, RECORD_ID });
    defer allocator.free(versions_url);

    const draft_response = try curlPost(allocator, versions_url, token, null);
    defer allocator.free(draft_response);

    const draft_id = jsonExtractString(draft_response, "id") orelse {
        print("{s}❌ Failed to create draft. Response:{s}\n", .{ RED, RESET });
        print("{s}\n", .{draft_response});
        return error.DraftCreationFailed;
    };
    print("   ✅ Draft ID: {s}\n\n", .{draft_id});

    // Step 2: Update metadata
    print("📋 Step 2/5: Updating metadata...\n", .{});
    const draft_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/draft", .{ API, draft_id });
    defer allocator.free(draft_url);

    const metadata_json = try std.fmt.allocPrint(allocator,
        \\{{"metadata":{{"title":"gHashTag/trinity: Trinity {s} — FPGA Autoregressive Ternary LLM + Training Results","description":"HSLM: 1.95M-parameter ternary language model with zero-DSP FPGA inference. PPL=125 on TinyStories, 1,872KB model, 0 DSP48, $30 FPGA.","creators":[{{"person_or_org":{{"family_name":"Vasilev","given_name":"Dmitrii","type":"personal"}}}}],"publication_date":"{d}-{d:0>2}-{d:0>2}","version":"{s}","resource_type":{{"id":"software"}},"publisher":"Zenodo","related_identifiers":[{{"identifier":"https://github.com/gHashTag/trinity","relation_type":{{"id":"issupplementto"}},"scheme":"url"}}]}}}}
    , .{
        version,
        @as(u16, @intCast(std.time.epoch.EpochSeconds.getEpochDay(@as(std.time.epoch.EpochSeconds, .{ .secs = @intCast(std.time.timestamp()) })).calculateYearDay().year)),
        @as(u9, @intCast(std.time.epoch.EpochSeconds.getEpochDay(@as(std.time.epoch.EpochSeconds, .{ .secs = @intCast(std.time.timestamp()) })).calculateYearDay().calculateMonthDay().month.numeric())),
        @as(u5, @intCast(std.time.epoch.EpochSeconds.getEpochDay(@as(std.time.epoch.EpochSeconds, .{ .secs = @intCast(std.time.timestamp()) })).calculateYearDay().calculateMonthDay().day_index + 1)),
        version,
    });
    defer allocator.free(metadata_json);

    const meta_resp = try curlPut(allocator, draft_url, token, metadata_json);
    defer allocator.free(meta_resp);
    print("   ✅ Metadata updated\n\n", .{});

    // Step 3: Build zip archive
    print("📦 Step 3/5: Building archive...\n", .{});
    const zip_name = try std.fmt.allocPrint(allocator, "trinity-{s}-fpga-llm.zip", .{version});
    defer allocator.free(zip_name);
    const zip_path = try std.fmt.allocPrint(allocator, "/tmp/{s}", .{zip_name});
    defer allocator.free(zip_path);

    const zip_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{
            "zip",                 "-r",                     zip_path,
            "README.md",           "CLAUDE.md",              "LICENSE",
            "build.zig",           "build.zig.zon",          "src/hslm/",
            "src/vsa.zig",         "src/vm.zig",             "fpga/README.md",
            "fpga/openxc7-synth/", "fpga/tools/fpga_eye.py", "papers/",
            "specs/tri/",
        },
    });
    allocator.free(zip_result.stdout);
    allocator.free(zip_result.stderr);
    print("   ✅ Archive: {s}\n\n", .{zip_path});

    // Step 4: Upload
    print("📤 Step 4/5: Uploading...\n", .{});

    // Delete old files first
    const files_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/draft/files", .{ API, draft_id });
    defer allocator.free(files_url);

    const files_resp = try curlGet(allocator, files_url, token);
    defer allocator.free(files_resp);

    // Find and delete old files (simple: look for "key":"filename" patterns)
    var search_pos: usize = 0;
    while (std.mem.indexOfPos(u8, files_resp, search_pos, "\"key\":\"")) |pos| {
        const start = pos + 7; // length of "key":"
        const end = std.mem.indexOfPos(u8, files_resp, start, "\"") orelse break;
        const old_file = files_resp[start..end];
        const del_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/draft/files/{s}", .{ API, draft_id, old_file });
        defer allocator.free(del_url);
        curlDelete(allocator, del_url, token) catch |err| {
            std.log.warn("tri_zenodo: failed to delete old file: {}", .{err});
        };
        print("   🗑️  Deleted: {s}\n", .{old_file});
        search_pos = end + 1;
    }

    // Initiate upload
    const init_body = try std.fmt.allocPrint(allocator, "[{{\"key\":\"{s}\"}}]", .{zip_name});
    defer allocator.free(init_body);
    const init_resp = try curlPost(allocator, files_url, token, init_body);
    allocator.free(init_resp);

    // Upload content
    const upload_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/draft/files/{s}/content", .{ API, draft_id, zip_name });
    defer allocator.free(upload_url);
    const upload_resp = try curlUpload(allocator, upload_url, token, zip_path);
    allocator.free(upload_resp);

    // Commit file
    const commit_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/draft/files/{s}/commit", .{ API, draft_id, zip_name });
    defer allocator.free(commit_url);
    const commit_resp = try curlPost(allocator, commit_url, token, null);
    allocator.free(commit_resp);
    print("   ✅ Upload complete\n\n", .{});

    // Step 5: Publish (or stop at draft)
    if (do_publish) {
        print("🚀 Step 5/5: Publishing...\n", .{});
        const pub_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/draft/actions/publish", .{ API, draft_id });
        defer allocator.free(pub_url);
        const pub_resp = try curlPost(allocator, pub_url, token, null);
        defer allocator.free(pub_resp);

        const doi = jsonExtractString(pub_resp, "doi") orelse "pending";

        print("\n{s}═══════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
        print("{s}{s}✅ Published to Zenodo!{s}\n\n", .{ GREEN, BOLD, RESET });
        print("   🏷️  DOI:     {s}\n", .{doi});
        print("   🔗 URL:     https://doi.org/{s}\n", .{doi});
        print("   📦 Record:  https://zenodo.org/records/{s}\n", .{draft_id});
        print("   📎 Version: {s}\n", .{version});
        print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });
    } else {
        print("📋 Draft created (not published)\n", .{});
        print("   Draft: https://zenodo.org/records/{s}\n", .{draft_id});
        print("   Publish manually or run: tri zenodo publish {s}\n\n", .{version});
    }

    // Cleanup
    std.fs.deleteFileAbsolute(zip_path) catch |err| {
        std.log.debug("tri_zenodo: failed to cleanup zip file: {}", .{err});
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "json extract string" {
    const json =
        \\{"id":"12345","doi":"10.5281/zenodo.12345","metadata":{"title":"test"}}
    ;
    try std.testing.expectEqualStrings("12345", jsonExtractString(json, "id").?);
    try std.testing.expectEqualStrings("10.5281/zenodo.12345", jsonExtractString(json, "doi").?);
    try std.testing.expectEqualStrings("test", jsonExtractString(json, "title").?);
    try std.testing.expect(jsonExtractString(json, "missing") == null);
}

test "token load from env" {
    // Just verify it compiles and doesn't crash on missing env
    const allocator = std.testing.allocator;
    const result = loadToken(allocator);
    if (result) |token| {
        allocator.free(token);
    } else |_| {
        // Expected when no token set
    }
}
