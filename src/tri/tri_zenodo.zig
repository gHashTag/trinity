// @origin(spec:tri_zenodo.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI ZENODO — DOI Publishing CLI
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri zenodo publish <version>  — create new version, upload, publish
//   tri zenodo status             — show current record info
//   tri zenodo draft <version>    — create draft without publishing
//   tri zenodo update [D004-D007] — upgrade descriptions to defensive publications
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
    } else if (std.mem.eql(u8, subcmd, "discovery")) {
        if (sub_args.len > 0) {
            try publishDiscovery(allocator, sub_args[0]);
        } else {
            try publishAllDiscoveries(allocator);
        }
    } else if (std.mem.eql(u8, subcmd, "update")) {
        if (sub_args.len > 0) {
            try updateOneRecord(allocator, sub_args[0]);
        } else {
            try updateAllRecords(allocator);
        }
    } else {
        print("{s}Unknown subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

const Discovery = struct {
    id: []const u8,
    title: []const u8,
    description: []const u8,
    keywords: []const u8,
    files: []const []const u8,
};

const disc_table = [_]Discovery{
    .{
        .id = "D004",
        .title = "Trinity D004: Self-Evolving Ouroboros — Autonomous 6-Phase Code Improvement System",
        .description = "Autonomous 6-phase code improvement: DIAGNOSE-PLAN-ACT-VERIFY-MEASURE-PERSIST. 12-dimensional Toxic Verdict scoring (BUILD/TEST 50%%, QUALITY 30%%, EFFICIENCY 20%%). Strategy rotation on stagnation. Self-referential pipeline Link #22. Golden-ratio quality gating. 643+1800+939 LOC pure Zig.",
        .keywords = "ouroboros,self-evolving,autonomous-code-improvement,toxic-verdict,golden-chain,zig",
        .files = &.{ "src/tri/tri_ouroboros.zig", "src/tri/toxic_verdict.zig", "src/tri/golden_chain.zig" },
    },
    .{
        .id = "D005",
        .title = "Trinity D005: VSA Balanced Ternary with SIMD — Vector Symbolic Architecture",
        .description = "Vector Symbolic Architecture using balanced ternary with SIMD acceleration. bind/unbind/bundle/permute. 32 trits per SIMD iteration. 20x memory compression vs float32. Extends Kanerva 2009 to balanced ternary with hardware-friendly SIMD.",
        .keywords = "vsa,vector-symbolic-architecture,ternary,simd,hyperdimensional-computing,zig",
        .files = &.{"src/vsa.zig"},
    },
    .{
        .id = "D006",
        .title = "Trinity D006: phi-RoPE — Golden Ratio Rotary Position Encoding for Ternary Attention",
        .description = "Novel rotary position encoding: theta_i = phi^(-2i/HEAD_DIM) instead of standard 10000^(-2i/d). Sacred Attention Scale: 1/(d^(phi^-3)) = 0.354 vs standard 0.111. Aligned with ternary resonance at 3^k dimensions. PPL 2.96 validated.",
        .keywords = "rope,positional-encoding,golden-ratio,attention,ternary,transformer,zig",
        .files = &.{"src/hslm/sacred_attention.zig"},
    },
    .{
        .id = "D007",
        .title = "Trinity D007: Sparse Ternary MatMul — 4-Variant Branchless Multiplication",
        .description = "Four matrix-vector multiply variants for ternary weights: (1) Packed 2-bit 16 weights/u32, (2) Branchless bit-manipulation 9.2x speedup, (3) Sparse CSR, (4) SIMD f16/f32 4-33x speedup. Zero multiplications. 2 bits/param. 1200+ LOC pure Zig.",
        .keywords = "sparse-matmul,ternary,branchless,simd,matrix-multiplication,zig",
        .files = &.{"src/hslm/sparse_ternary.zig"},
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// UPDATE — Upgrade descriptions to defensive publications
// ═══════════════════════════════════════════════════════════════════════════════

const UpdateRecord = struct {
    id: []const u8,
    zenodo_id: []const u8,
    file: []const u8,
    title: []const u8,
    keywords: []const u8,
    cpc: []const u8,
};

const update_records = [_]UpdateRecord{
    .{
        .id = "D001-D003",
        .zenodo_id = "18939352",
        .file = "docs/lab/papers/patent-strategy/zenodo-descriptions/D001-D003.html",
        .title = "Trinity D001-D003: Ternary Resonance Law, Square Attention, Zero-DSP FPGA Inference",
        .keywords = "ternary,FPGA,resonance,attention,zero-DSP,3^k-dimensions,defensive-publication",
        .cpc = "H03K19/20,G06F30/34,G06N3/04,G06F7/544",
    },
    .{
        .id = "D004",
        .zenodo_id = "19020211",
        .file = "docs/lab/papers/patent-strategy/zenodo-descriptions/D004.html",
        .title = "Trinity D004: Self-Evolving Ouroboros — Autonomous 6-Phase Code Improvement System",
        .keywords = "ouroboros,self-evolving,autonomous-code-improvement,toxic-verdict,defensive-publication",
        .cpc = "G06F8/65,G06N20/00,G06F11/36",
    },
    .{
        .id = "D005",
        .zenodo_id = "19020213",
        .file = "docs/lab/papers/patent-strategy/zenodo-descriptions/D005.html",
        .title = "Trinity D005: VSA Balanced Ternary with SIMD — Vector Symbolic Architecture",
        .keywords = "vsa,hyperdimensional,ternary,simd,vector-symbolic-architecture,defensive-publication",
        .cpc = "G06F7/72,G06N3/04,G06F17/16",
    },
    .{
        .id = "D006",
        .zenodo_id = "19020215",
        .file = "docs/lab/papers/patent-strategy/zenodo-descriptions/D006.html",
        .title = "Trinity D006: phi-RoPE — Golden Ratio Rotary Position Encoding for Ternary Attention",
        .keywords = "rope,positional-encoding,golden-ratio,attention,ternary,defensive-publication",
        .cpc = "G06N3/0455,G06F17/14,G06N3/084",
    },
    .{
        .id = "D007",
        .zenodo_id = "19020217",
        .file = "docs/lab/papers/patent-strategy/zenodo-descriptions/D007.html",
        .title = "Trinity D007: Sparse Ternary MatMul — 4-Variant Branchless Multiplication",
        .keywords = "sparse-matmul,branchless,simd,ternary,defensive-publication",
        .cpc = "G06F7/544,G06F7/72,G06F17/16",
    },
};

fn updateAllRecords(allocator: std.mem.Allocator) !void {
    print("\n{s}{s}ZENODO DEFENSIVE PUBLICATION UPDATE{s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    var success: usize = 0;
    var fail: usize = 0;
    for (update_records) |rec| {
        updateSingleRecord(allocator, rec) catch |err| {
            print("{s}  FAILED {s}: {}{s}\n", .{ RED, rec.id, err, RESET });
            fail += 1;
            continue;
        };
        success += 1;
    }

    print("\n{s}Results: {d} updated, {d} failed{s}\n\n", .{ GREEN, success, fail, RESET });
}

fn updateOneRecord(allocator: std.mem.Allocator, record_id: []const u8) !void {
    for (update_records) |rec| {
        if (std.mem.eql(u8, rec.id, record_id)) {
            try updateSingleRecord(allocator, rec);
            return;
        }
    }
    print("{s}Unknown record: {s}. Valid: D001-D003, D004, D005, D006, D007{s}\n", .{ RED, record_id, RESET });
}

fn updateSingleRecord(allocator: std.mem.Allocator, rec: UpdateRecord) !void {
    const token = try loadToken(allocator);
    defer allocator.free(token);

    print("{s}[{s}]{s} Updating Zenodo #{s}...\n", .{ CYAN, rec.id, RESET, rec.zenodo_id });

    // Step 1: Read HTML description from file
    print("  1/4 Reading description from {s}...\n", .{rec.file});
    const desc_file = std.fs.cwd().openFile(rec.file, .{}) catch {
        print("  {s}File not found: {s}{s}\n", .{ RED, rec.file, RESET });
        return error.FileNotFound;
    };
    defer desc_file.close();
    const raw_desc = desc_file.readToEndAlloc(allocator, 65536) catch return error.ReadFailed;
    defer allocator.free(raw_desc);

    // Escape description for JSON embedding
    const description = try jsonEscapeString(allocator, raw_desc);
    defer allocator.free(description);

    // Step 2: Create new version draft
    print("  2/4 Creating new version draft...\n", .{});
    const newver_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/actions/newversion", .{ API, rec.zenodo_id });
    defer allocator.free(newver_url);
    const newver_resp = try curlPost(allocator, newver_url, token, null);
    defer allocator.free(newver_resp);

    // Get the draft ID from response
    const draft_id = jsonExtractString(newver_resp, "id") orelse {
        const resp_preview = newver_resp[0..@min(200, newver_resp.len)];
        print("  {s}Failed to create new version. Response: {s}{s}\n", .{ RED, resp_preview, RESET });
        return error.NewVersionFailed;
    };

    // Step 3: Update metadata with rich description
    print("  3/4 Updating metadata (draft {s})...\n", .{draft_id});

    // Build keywords JSON: human keywords + CPC codes
    var kw_buf: [2048]u8 = undefined;
    var kw_pos: usize = 0;
    kw_buf[kw_pos] = '[';
    kw_pos += 1;

    var kw_iter = std.mem.splitScalar(u8, rec.keywords, ',');
    var first_kw = true;
    while (kw_iter.next()) |kw| {
        if (!first_kw) {
            kw_buf[kw_pos] = ',';
            kw_pos += 1;
        }
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        @memcpy(kw_buf[kw_pos .. kw_pos + kw.len], kw);
        kw_pos += kw.len;
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        first_kw = false;
    }

    // Add CPC codes as keywords
    var cpc_iter = std.mem.splitScalar(u8, rec.cpc, ',');
    while (cpc_iter.next()) |cpc| {
        kw_buf[kw_pos] = ',';
        kw_pos += 1;
        const prefix = "\"CPC:";
        @memcpy(kw_buf[kw_pos .. kw_pos + prefix.len], prefix);
        kw_pos += prefix.len;
        @memcpy(kw_buf[kw_pos .. kw_pos + cpc.len], cpc);
        kw_pos += cpc.len;
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
    }
    kw_buf[kw_pos] = ']';
    kw_pos += 1;

    const related_ids =
        \\[{"identifier":"10.5281/zenodo.18939352","relation":"isPartOf","resource_type":"software"},{"identifier":"10.5281/zenodo.19020211","relation":"isRelatedTo","resource_type":"software"},{"identifier":"10.5281/zenodo.19020213","relation":"isRelatedTo","resource_type":"software"},{"identifier":"10.5281/zenodo.19020215","relation":"isRelatedTo","resource_type":"software"},{"identifier":"10.5281/zenodo.19020217","relation":"isRelatedTo","resource_type":"software"}]
    ;

    const meta_body = try std.fmt.allocPrint(allocator,
        \\{{"metadata":{{"title":"{s}","description":"{s}","keywords":{s},"notes":"CPC Classifications: {s}. Defensive publication.","upload_type":"software","publication_date":"2026-03-14","creators":[{{"name":"Vasilev, Dmitrii","affiliation":"Trinity"}}],"license":{{"id":"MIT"}},"version":"v1.1.0","related_identifiers":{s}}}}}
    , .{ rec.title, description, kw_buf[0..kw_pos], rec.cpc, related_ids });
    defer allocator.free(meta_body);

    const draft_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}", .{ API, draft_id });
    defer allocator.free(draft_url);
    const meta_resp = try curlPut(allocator, draft_url, token, meta_body);
    defer allocator.free(meta_resp);

    if (std.mem.indexOf(u8, meta_resp, "\"status\": 4") != null or std.mem.indexOf(u8, meta_resp, "\"status\":4") != null) {
        print("  {s}Metadata update failed{s}\n", .{ RED, RESET });
        return error.MetadataUpdateFailed;
    }

    // Step 4: Publish the new version
    print("  4/4 Publishing...\n", .{});
    const pub_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/actions/publish", .{ API, draft_id });
    defer allocator.free(pub_url);
    const pub_resp = try curlPost(allocator, pub_url, token, null);
    defer allocator.free(pub_resp);

    const doi = jsonExtractString(pub_resp, "doi") orelse "pending";
    print("  {s}[{s}] Updated! DOI: {s}{s}\n\n", .{ GREEN, rec.id, doi, RESET });
}

fn jsonEscapeString(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var size: usize = 0;
    for (input) |c| {
        size += switch (c) {
            '"', '\\' => 2,
            '\n' => 2,
            '\r' => 2,
            '\t' => 2,
            else => 1,
        };
    }

    const result = try allocator.alloc(u8, size);
    var i: usize = 0;
    for (input) |c| {
        switch (c) {
            '"' => {
                result[i] = '\\';
                result[i + 1] = '"';
                i += 2;
            },
            '\\' => {
                result[i] = '\\';
                result[i + 1] = '\\';
                i += 2;
            },
            '\n' => {
                result[i] = '\\';
                result[i + 1] = 'n';
                i += 2;
            },
            '\r' => {
                result[i] = '\\';
                result[i + 1] = 'r';
                i += 2;
            },
            '\t' => {
                result[i] = '\\';
                result[i + 1] = 't';
                i += 2;
            },
            else => {
                result[i] = c;
                i += 1;
            },
        }
    }
    return result;
}

fn publishDiscovery(allocator: std.mem.Allocator, discovery_id: []const u8) !void {
    for (disc_table) |d| {
        if (std.mem.eql(u8, d.id, discovery_id)) {
            try publishOneDiscovery(allocator, d);
            return;
        }
    }
    print("{s}Unknown discovery: {s}. Valid: D004, D005, D006, D007{s}\n", .{ RED, discovery_id, RESET });
}

fn publishAllDiscoveries(allocator: std.mem.Allocator) !void {
    print("\n{s}{s}ZENODO DISCOVERY DOI — Publishing 4 records{s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    for (disc_table) |d| {
        publishOneDiscovery(allocator, d) catch |err| {
            print("{s}Failed {s}: {}{s}\n", .{ RED, d.id, err, RESET });
            continue;
        };
    }

    print("\n{s}All discoveries published. Run 'tri zenodo status' to verify.{s}\n\n", .{ GREEN, RESET });
}

fn publishOneDiscovery(allocator: std.mem.Allocator, d: Discovery) !void {
    const token = try loadToken(allocator);
    defer allocator.free(token);

    print("{s}[{s}]{s} {s}\n", .{ CYAN, d.id, RESET, d.title });

    // Step 1: Create new deposition
    print("  1/4 Creating record...\n", .{});

    // Build keywords JSON array from comma-separated string
    var kw_buf: [1024]u8 = undefined;
    var kw_pos: usize = 0;
    kw_buf[kw_pos] = '[';
    kw_pos += 1;
    var kw_iter = std.mem.splitScalar(u8, d.keywords, ',');
    var first = true;
    while (kw_iter.next()) |kw| {
        if (!first) {
            kw_buf[kw_pos] = ',';
            kw_pos += 1;
        }
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        @memcpy(kw_buf[kw_pos .. kw_pos + kw.len], kw);
        kw_pos += kw.len;
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        first = false;
    }
    kw_buf[kw_pos] = ']';
    kw_pos += 1;

    const body = try std.fmt.allocPrint(allocator,
        \\{{"metadata":{{"title":"{s}","upload_type":"software","publication_date":"2026-03-14","description":"{s}","creators":[{{"name":"Vasilev, Dmitrii","affiliation":"Trinity"}}],"keywords":{s},"license":{{"id":"MIT"}},"version":"v1.0.0","related_identifiers":[{{"identifier":"10.5281/zenodo.18939352","relation":"isPartOf","resource_type":"software"}}]}}}}
    , .{ d.title, d.description, kw_buf[0..kw_pos] });
    defer allocator.free(body);

    const create_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions", .{API});
    defer allocator.free(create_url);

    const resp = try curlPost(allocator, create_url, token, body);
    defer allocator.free(resp);

    const dep_id = jsonExtractString(resp, "id") orelse {
        print("  {s}Failed to create record{s}\n", .{ RED, RESET });
        return error.CreateFailed;
    };

    print("  2/4 Record ID: {s}\n", .{dep_id});

    // Step 2: Create zip of discovery files
    print("  3/4 Uploading files...\n", .{});
    const zip_name = try std.fmt.allocPrint(allocator, "trinity-{s}.zip", .{d.id});
    defer allocator.free(zip_name);
    const zip_path = try std.fmt.allocPrint(allocator, "/tmp/{s}", .{zip_name});
    defer allocator.free(zip_path);

    // Build argv: zip -r /tmp/trinity-D00X.zip file1 file2 ...
    var argv_buf: [16][]const u8 = undefined;
    argv_buf[0] = "zip";
    argv_buf[1] = "-j";
    argv_buf[2] = zip_path;
    var argc: usize = 3;
    for (d.files) |f| {
        if (argc < argv_buf.len) {
            argv_buf[argc] = f;
            argc += 1;
        }
    }

    const zip_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv_buf[0..argc],
    }) catch |err| {
        print("  {s}Zip failed: {}{s}\n", .{ RED, err, RESET });
        return err;
    };
    allocator.free(zip_result.stdout);
    allocator.free(zip_result.stderr);

    // Upload via files endpoint (old API, more reliable)
    const files_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/files", .{ API, dep_id });
    defer allocator.free(files_url);

    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);
    const file_arg = try std.fmt.allocPrint(allocator, "file=@{s}", .{zip_path});
    defer allocator.free(file_arg);
    const name_arg = try std.fmt.allocPrint(allocator, "name={s}", .{zip_name});
    defer allocator.free(name_arg);

    const upload_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "POST", files_url, "-H", auth, "-F", file_arg, "-F", name_arg },
    });
    allocator.free(upload_result.stdout);
    allocator.free(upload_result.stderr);

    // Step 3: Publish
    print("  4/4 Publishing...\n", .{});
    const pub_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/actions/publish", .{ API, dep_id });
    defer allocator.free(pub_url);
    const pub_resp = try curlPost(allocator, pub_url, token, null);
    defer allocator.free(pub_resp);

    const doi = jsonExtractString(pub_resp, "doi") orelse "pending";
    print("  {s}[{s}] DOI: {s}{s}\n\n", .{ GREEN, d.id, doi, RESET });

    // Cleanup
    std.fs.deleteFileAbsolute(zip_path) catch {};
}

fn printHelp() void {
    print("\n{s}{s}TRI ZENODO — DOI Publishing{s}\n\n", .{ GOLDEN, BOLD, RESET });
    print("  tri zenodo publish <version>    Create new version, upload, publish\n", .{});
    print("  tri zenodo status               Show current record info\n", .{});
    print("  tri zenodo draft <version>      Create draft without publishing\n", .{});
    print("  tri zenodo discovery [D004-D007] Publish discovery DOI (or all)\n", .{});
    print("  tri zenodo update [D001-D007]    Upgrade descriptions (defensive pub)\n\n", .{});
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
            "fpga/openxc7-synth/", "fpga/tools/fpga_eye.py", "docs/lab/papers/",
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

test "json_escape_string" {
    const allocator = std.testing.allocator;
    const escaped = try jsonEscapeString(allocator, "hello \"world\"\nnew line");
    defer allocator.free(escaped);
    try std.testing.expectEqualStrings("hello \\\"world\\\"\\nnew line", escaped);
}

test "update_records_table_valid" {
    for (update_records) |rec| {
        try std.testing.expect(rec.id.len > 0);
        try std.testing.expect(rec.zenodo_id.len > 0);
        try std.testing.expect(rec.file.len > 0);
    }
    try std.testing.expectEqual(@as(usize, 5), update_records.len);
}
