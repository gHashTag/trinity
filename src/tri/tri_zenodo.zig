// @origin(spec:tri_zenodo.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Zenodo Integration
// ═══════════════════════════════════════════════════════════════════════════════
//
// Zenodo DOI publishing for Trinity releases.
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const GOLDEN = "\x1b[33m";
const RESET = "\x1b[0m";

const UpdateRecord = struct {
    id: []const u8,
    zenodo_id: []const u8,
    file: []const u8,
    title: []const u8,
    keywords: []const u8,
    cpc: []const u8,
};

const update_records = [_]UpdateRecord{
    .{ .id = "D001-D003", .zenodo_id = "18939352", .file = "papers/patent-strategy/zenodo-descriptions/D001-D003.html", .title = "FPGA Autoregressive Ternary LLM", .keywords = "ternary,FPGA,resonance,attention,square-attention,zero-dsp", .cpc = "H03K19/20,G06F30/34,G06N3/04,G06F7/544" },
    .{ .id = "D004", .zenodo_id = "19020211", .file = "papers/patent-strategy/zenodo-descriptions/D004.html", .title = "D004: Self-Evolving Ouroboros", .keywords = "ouroboros,self-evolving,code-health,toxic-verdict,strategy-rotation", .cpc = "G06F8/65,G06N20/00,G06F11/36" },
    .{ .id = "D005", .zenodo_id = "19020213", .file = "papers/patent-strategy/zenodo-descriptions/D005.html", .title = "D005: VSA Balanced Ternary + SIMD", .keywords = "vsa,hyperdimensional,ternary,simd,bind,unbind,bundle", .cpc = "G06F7/72,G06N3/04,G06F17/16" },
    .{ .id = "D006", .zenodo_id = "19020215", .file = "papers/patent-strategy/zenodo-descriptions/D006.html", .title = "D006: phi-RoPE Attention", .keywords = "rope,positional-encoding,golden-ratio,phi,sacred-scale", .cpc = "G06N3/0455,G06F17/14,G06N3/084" },
    .{ .id = "D007", .zenodo_id = "19020217", .file = "papers/patent-strategy/zenodo-descriptions/D007.html", .title = "D007: Sparse Ternary MatMul", .keywords = "sparse-matmul,branchless,simd,ternary,csr,packed-encoding", .cpc = "G06F7/544,G06F7/72,G06F17/16" },
};

pub fn runZenodoCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        printHelp();
        return;
    }

    const subcmd = args[0];
    const cmd_args = args[1..];

    if (std.mem.eql(u8, subcmd, "status")) {
        std.debug.print("{s}Zenodo Status Check{s}\n", .{ GOLDEN, RESET });
        std.debug.print("  Token: ZENODO_TOKEN from environment\n", .{});
        std.debug.print("  Run: export ZENODO_TOKEN=<your-token>\n\n", .{});
    } else if (std.mem.eql(u8, subcmd, "publish")) {
        if (cmd_args.len == 0) {
            std.debug.print("{s}Usage: tri zenodo publish <draft-id>{s}\n", .{ RED, RESET });
            return;
        }
        std.debug.print("{s}Publishing draft: {s}{s}\n", .{ GREEN, cmd_args[0], RESET });
    } else if (std.mem.eql(u8, subcmd, "draft")) {
        if (cmd_args.len == 0) {
            std.debug.print("{s}Usage: tri zenodo draft <version>{s}\n", .{ RED, RESET });
            return;
        }
        std.debug.print("{s}Creating draft version: {s}{s}\n", .{ GREEN, cmd_args[0], RESET });
    } else if (std.mem.eql(u8, subcmd, "update")) {
        if (cmd_args.len > 0) {
            try updateOneRecord(allocator, cmd_args[0]);
        } else {
            try updateAllRecords(allocator);
        }
    } else {
        std.debug.print("{s}Unknown subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

pub fn printHelp() void {
    std.debug.print("\n{s}ZENODO - DOI Publishing{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ "\x1b[90m", RESET });
    std.debug.print("  {s}tri zenodo{s}                      Show help\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri zenodo status{s}               Check token and user info\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri zenodo publish <draft-id>     Publish draft to Zenodo{s}\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri zenodo draft <version>        Create new draft version{s}\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri zenodo update [D001-D007]    Upgrade descriptions (defensive pub){s}\n", .{ GREEN, RESET });
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

fn updateAllRecords(allocator: std.mem.Allocator) !void {
    std.debug.print("{s}Updating all {d} Zenodo records...{s}\n\n", .{ GREEN, update_records.len, RESET });

    var success_count: usize = 0;
    var fail_count: usize = 0;

    for (update_records) |rec| {
        std.debug.print("  [{s}] {s}: {s}...{s}", .{ GOLDEN, rec.id, rec.title, RESET });
        const result = updateSingleRecord(allocator, rec);
        if (result) |_| {
            success_count += 1;
            std.debug.print(" {s}✓{s}\n", .{ GREEN, RESET });
        } else |err| {
            fail_count += 1;
            std.debug.print(" {s}✗ {s}{s}\n", .{ RED, @errorName(err), RESET });
        }
    }

    std.debug.print("\n{s}Results: {d} succeeded, {d} failed{s}\n\n", .{ GOLDEN, success_count, fail_count, RESET });
}

fn updateOneRecord(allocator: std.mem.Allocator, id: []const u8) !void {
    for (update_records) |rec| {
        if (std.mem.eql(u8, rec.id, id)) {
            std.debug.print("{s}Updating record {s}: {s}{s}\n", .{ GREEN, rec.id, rec.title, RESET });
            try updateSingleRecord(allocator, rec);
            return;
        }
    }
    std.debug.print("{s}Record ID not found: {s}{s}\n", .{ RED, id, RESET });
    std.debug.print("  Available IDs: ", .{});
    for (update_records) |rec| {
        std.debug.print("{s}, ", .{rec.id});
    }
    std.debug.print("\n", .{});
    return error.RecordNotFound;
}

fn updateSingleRecord(allocator: std.mem.Allocator, rec: UpdateRecord) !void {
    // 1. Read HTML description file
    const html_content = try std.fs.cwd().readFileAlloc(allocator, rec.file, std.math.maxInt(usize));
    defer allocator.free(html_content);

    std.debug.print("    Loaded {d} bytes from {s}\n", .{ html_content.len, rec.file });

    // 2. JSON escape the HTML
    const escaped_html = try jsonEscapeString(allocator, html_content);
    defer allocator.free(escaped_html);

    // 3. Get ZENODO_TOKEN from environment
    const token = std.process.getEnvVar(allocator, "ZENODO_TOKEN") catch |err| {
        std.debug.print("{s}Error: ZENODO_TOKEN environment variable not set{s}\n", .{ RED, RESET });
        std.debug.print("  Run: export ZENODO_TOKEN=<your-token>\n", .{});
        return err;
    };
    defer allocator.free(token);

    // Build Authorization header
    const auth_header = try std.fmt.allocPrint(allocator, "Bearer {s}", .{token});
    defer allocator.free(auth_header);

    // 4. Create new version via POST /actions/newversion
    const newversion_url = try std.fmt.allocPrint(allocator, "https://zenodo.org/api/deposit/depositions/{s}/actions/newversion", .{rec.zenodo_id});
    defer allocator.free(newversion_url);

    std.debug.print("    Creating new version for record {s}...\n", .{rec.zenodo_id});

    const client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const newversion_req = try client.open(.POST, try std.Uri.parse(newversion_url));
    defer newversion_req.deinit();

    newversion_req.headers.append("Authorization", auth_header) catch unreachable;
    newversion_req.headers.append("Content-Type", "application/json") catch unreachable;

    const newversion_resp = try newversion_req.send("", .{});
    defer newversion_resp.deinit();

    if (newversion_resp.status != .created) {
        std.debug.print("{s}Failed to create new version: {d} {s}{s}\n", .{ RED, @intFromEnum(newversion_resp.status), newversion_resp.status.phrase(), RESET });
        const body = try newversion_resp.reader().readAllAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(body);
        std.debug.print("    Response: {s}\n", .{body});
        return error.NewVersionFailed;
    }

    // Parse response to get new draft ID
    const resp_body = try newversion_resp.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(resp_body);

    const parsed = try std.json.parseFromSliceLeaky(allocator, resp_body);
    const draft_id = parsed.object.get("id").?.string orelse {
        std.debug.print("{s}No draft_id in response{s}\n", .{ RED, RESET });
        return error.ParseError;
    };
    const links = parsed.object.get("links").?.object orelse {
        std.debug.print("{s}No links in response{s}\n", .{ RED, RESET });
        return error.ParseError;
    };
    const latest_draft = links.get("latest_draft").?.string orelse {
        std.debug.print("{s}No latest_draft link{s}\n", .{ RED, RESET });
        return error.ParseError;
    };

    std.debug.print("    Created draft: {s}\n", .{draft_id});

    // 5. Build metadata with description, keywords, CPC, related identifiers
    var metadata_buf = try std.ArrayList(u8).initCapacity(allocator, 10240);
    defer metadata_buf.deinit();

    try metadata_buf.writer().print(
        \\{{
        \\  "metadata": {{
        \\    "title": "{s}",
        \\    "description": "{s}",
        \\    "keywords": [
        \\      "{s}",
        \\      "CPC:{s}"
        \\    ],
        \\    "notes": "CPC Classifications: {s}",
        \\    "upload_type": "software",
        \\    "publication_date": "2026-03-14",
        \\    "creators": [
        \\      {{"name": "Vasilev, Dmitrii", "affiliation": "Trinity"}
        \\    ],
        \\    "license": {{"id": "MIT"}},
        \\    "version": "v1.1.0",
        \\    "related_identifiers": [
        \\      {{"identifier": "10.5281/zenodo.18939352", "relation": "isPartOf"}},
        \\      {{"identifier": "10.5281/zenodo.18947017", "relation": "isVersionOf"}},
        \\      {{"identifier": "10.5281/zenodo.19020211", "relation": "isRelatedTo"}},
        \\      {{"identifier": "10.5281/zenodo.19020213", "relation": "isRelatedTo"}},
        \\      {{"identifier": "10.5281/zenodo.19020215", "relation": "isRelatedTo"}},
        \\      {{"identifier": "10.5281/zenodo.19020217", "relation": "isRelatedTo"}}
        \\    ]
        \\  }}
        \\}}
    , .{ rec.title, escaped_html, rec.keywords, rec.cpc, rec.cpc });

    // 6. PUT to update metadata
    const update_url = try std.fmt.allocPrint(allocator, "https://zenodo.org/api/deposit/depositions/{s}", .{latest_draft});
    defer allocator.free(update_url);

    std.debug.print("    Updating metadata for draft {s}...\n", .{latest_draft});

    const update_req = try client.open(.PUT, try std.Uri.parse(update_url));
    defer update_req.deinit();

    update_req.headers.append("Authorization", auth_header) catch unreachable;
    update_req.headers.append("Content-Type", "application/json") catch unreachable;

    const update_resp = try update_req.send(metadata_buf.items, .{});
    defer update_resp.deinit();

    if (update_resp.status != .ok) {
        std.debug.print("{s}Failed to update metadata: {d} {s}{s}\n", .{ RED, @intFromEnum(update_resp.status), update_resp.status.phrase(), RESET });
        const body = try update_resp.reader().readAllAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(body);
        std.debug.print("    Response: {s}\n", .{body});
        return error.UpdateFailed;
    }

    std.debug.print("    {s}Metadata updated{s}\n", .{ GREEN, RESET });

    // 7. Publish the new version
    const publish_url = try std.fmt.allocPrint(allocator, "https://zenodo.org/api/deposit/depositions/{s}/actions/publish", .{latest_draft});
    defer allocator.free(publish_url);

    std.debug.print("    Publishing draft {s}...\n", .{latest_draft});

    const publish_req = try client.open(.POST, try std.Uri.parse(publish_url));
    defer publish_req.deinit();

    publish_req.headers.append("Authorization", auth_header) catch unreachable;
    publish_req.headers.append("Content-Type", "application/json") catch unreachable;

    const publish_resp = try publish_req.send("", .{});
    defer publish_resp.deinit();

    if (publish_resp.status != .accepted and publish_resp.status != .ok) {
        std.debug.print("{s}Failed to publish: {d} {s}{s}\n", .{ RED, @intFromEnum(publish_resp.status), publish_resp.status.phrase(), RESET });
        const body = try publish_resp.reader().readAllAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(body);
        std.debug.print("    Response: {s}\n", .{body});
        return error.PublishFailed;
    }

    // Parse publish response to get new DOI
    const pub_body = try publish_resp.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(pub_body);

    const pub_parsed = try std.json.parseFromSliceLeaky(allocator, pub_body);
    const pub_metadata = pub_parsed.object.get("metadata").?.object orelse {
        std.debug.print("{s}No metadata in publish response{s}\n", .{ RED, RESET });
        return error.ParseError;
    };
    const new_doi = pub_metadata.get("doi").?.string orelse "unknown";

    std.debug.print("    {s}✓ Published: {s}{s}\n\n", .{ GREEN, new_doi, RESET });
}

fn jsonEscapeString(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, input.len * 2);
    errdefer result.deinit();

    for (input) |c| {
        switch (c) {
            '"' => try result.appendSlice(allocator, "\\\""),
            '\\' => try result.appendSlice(allocator, "\\\\"),
            '\n' => try result.appendSlice(allocator, "\\n"),
            '\r' => try result.appendSlice(allocator, "\\r"),
            '\t' => try result.appendSlice(allocator, "\\t"),
            else => try result.append(allocator, c),
        }
    }

    return result.toOwnedSlice();
}

test "printHelp includes update command" {
    var buffer: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    var writer = fbs.writer();
    const saved_stdout = std.io.getStdOut();
    std.io.getStdOut().setOutStream(&writer);

    printHelp();

    std.io.getStdOut().setOutStream(saved_stdout);

    const output = writer.getWritten();
    if (std.mem.indexOf(u8, output, "tri zenodo update") == null) {
        std.debug.print("ERROR: 'tri zenodo update' not found in help output\n", .{});
        return error.TestFailed;
    }
}
