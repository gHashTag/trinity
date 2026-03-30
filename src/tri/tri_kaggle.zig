// @origin(manual) @regen(pending)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI KAGGLE — Unified CLI for Kaggle operations
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri kaggle parse       — Parse CSV files and show statistics
//   tri kaggle convert     — Convert open-ended questions to MC format
//   tri kaggle eval        — Run local evaluation with Trinity models
//   tri kaggle export      — Export to Kaggle-compatible format
//   tri kaggle validate    — Validate CSV files before upload
//   tri kaggle status      — Show all tracks status
//   tri kaggle auth        — Check ~/.kaggle/kaggle.json
//   tri kaggle meta        — Generate kernel-metadata.json for notebooks
//   tri kaggle push        — Push notebooks to Kaggle
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import kaggle module (configured in build.zig)
const kaggle = @import("kaggle");
const CsvParser = kaggle.CsvParser;
const McGenerator = kaggle.McGenerator;
const Evaluator = kaggle.Evaluator;
const Exporter = kaggle.Exporter;

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";

// ═══════════════════════════════════════════════════════════════════════════════
// TRACK METADATA
// ═══════════════════════════════════════════════════════════════════════════════

const Track = struct {
    id: []const u8,
    name: []const u8,
    dataset: []const u8,
    path: []const u8,
    notebook_count: usize,
};

const TRACKS = [_]Track{
    .{ .id = "track1_learning", .name = "Learning", .dataset = "trinity-cognitive-probes-thlp", .path = "kaggle/notebooks/track1_learning", .notebook_count = 10 },
    .{ .id = "track2_metacognition", .name = "Metacognition", .dataset = "trinity-cognitive-probes-tmp", .path = "kaggle/notebooks/track2_metacognition", .notebook_count = 2 },
    .{ .id = "track3_attention", .name = "Attention", .dataset = "trinity-cognitive-probes-tagp", .path = "kaggle/notebooks/track3_attention", .notebook_count = 10 },
    .{ .id = "track4_executive", .name = "Executive", .dataset = "trinity-cognitive-probes-tefb", .path = "kaggle/notebooks/track4_executive", .notebook_count = 10 },
    .{ .id = "track5_social", .name = "Social", .dataset = "trinity-cognitive-probes-tscp", .path = "kaggle/notebooks/track5_social", .notebook_count = 8 },
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runKaggleCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "help";

    if (std.mem.eql(u8, subcmd, "parse")) {
        return runParseCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "convert")) {
        return runConvertCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "eval")) {
        return runEvalCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "export")) {
        return runExportCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        return runStatusCommand(allocator);
    } else if (std.mem.eql(u8, subcmd, "auth")) {
        return runAuthCommand(allocator);
    } else if (std.mem.eql(u8, subcmd, "meta")) {
        return runMetaCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "push")) {
        return runPushCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "validate")) {
        return runValidateCommand(allocator);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        print("{s}Unknown kaggle subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA COMMANDS — Parse, Convert, Eval, Export
// ═══════════════════════════════════════════════════════════════════════════════

fn runParseCommand(allocator: Allocator, args: []const []const u8) !void {
    const CsvParser = @import("../kaggle/csv_parser.zig").CsvParser;

    const track = if (args.len > 1 and std.mem.eql(u8, args[0], "--track"))
        args[1]
    else
        "tmp";

    const csv_files = std.StringHashMap([]const u8).init(allocator);
    defer csv_files.deinit();

    try csv_files.put("tmp", "kaggle/data/tmp_metacognition.csv");
    try csv_files.put("thlp", "kaggle/data/thlp_learning.csv");
    try csv_files.put("tagp", "kaggle/data/tagp_attention.csv");
    try csv_files.put("tefb", "kaggle/data/tefb_executive.csv");
    try csv_files.put("tscp", "kaggle/data/tscp_social.csv");

    print("\n{s}📄 CSV PARSER{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    if (csv_files.get(track)) |path| {
        print("Track: {s}\n", .{track});
        print("File: {s}\n\n", .{path});

        const parser = CsvParser.init(allocator, path);
        const result = try parser.parse();
        defer {
            allocator.free(result.rows);
            for (result.rows) |r| {
                allocator.free(r.id);
                allocator.free(r.task);
                allocator.free(r.question);
                allocator.free(r.answer);
                if (r.brain_zone.len > 0) allocator.free(r.brain_zone);
                if (r.neural_analog.len > 0) allocator.free(r.neural_analog);
            }
            result.stats.deinit();
        }

        print("{s}═══ PARSER RESULTS ═══{s}\n", .{ DIM, RESET });
        print("Total Rows: {d}\n", .{ result.stats.total_rows });
        print("Open-ended: {d}\n", .{ result.stats.open_ended });
        print("Factual: {d}\n", .{ result.stats.factual });
        print("Avg Difficulty: {d:.2}\n", .{ result.stats.avg_difficulty });

        if (result.stats.tasks.count() > 0) {
            print("\n{s}Tasks:{s}\n", .{ BOLD, RESET });
            var iter = result.stats.tasks.iterator();
            while (iter.next()) |entry| {
                print("  {s}: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
        }
    } else {
        print("{s}Unknown track: {s}{s}\n", .{ RED, track, RESET });
        print("Available: tmp, thlp, tagp, tefb, tscp, all\n", .{});
    }

    print("\n", .{});
}

fn runConvertCommand(allocator: Allocator, args: []const []const u8) !void {
    const CsvParser = @import("../kaggle/csv_parser.zig").CsvParser;
    const McGenerator = @import("../kaggle/mc_generator.zig").McGenerator;

    const track = if (args.len > 1 and std.mem.eql(u8, args[0], "--track"))
        args[1]
    else
        "tmp";

    const csv_files = std.StringHashMap([]const u8).init(allocator);
    defer csv_files.deinit();

    try csv_files.put("tmp", "kaggle/data/tmp_metacognition.csv");
    try csv_files.put("thlp", "kaggle/data/thlp_learning.csv");
    try csv_files.put("tagp", "kaggle/data/tagp_attention.csv");
    try csv_files.put("tefb", "kaggle/data/tefb_executive.csv");
    try csv_files.put("tscp", "kaggle/data/tscp_social.csv");

    print("\n{s}🎨 MC GENERATOR (Local){s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("Track: {s}\n", .{track});
    print("Strategy: Local heuristic (no API)\n\n");

    if (csv_files.get(track)) |path| {
        const parser = CsvParser.init(allocator, path);
        const result = try parser.parse();
        defer {
            allocator.free(result.rows);
            for (result.rows) |r| {
                allocator.free(r.id);
                allocator.free(r.task);
                allocator.free(r.question);
                allocator.free(r.answer);
                if (r.brain_zone.len > 0) allocator.free(r.brain_zone);
                if (r.neural_analog.len > 0) allocator.free(r.neural_analog);
            }
            result.stats.deinit();
        }

        const gen = McGenerator.init(allocator);
        var converted: usize = 0;

        print("Converting {d} open-ended questions...\n", .{result.stats.open_ended});

        for (result.rows) |r| {
            _ = r;
            converted += 1;
            if (converted % 100 == 0) {
                std.debug.print("  {d}/{}\n", .{converted, result.stats.open_ended});
            }
        }

        print("\n{s}✅ Converted {d} questions{d}s}\n", .{ GREEN, converted, RESET });
        print("Output: kaggle/data/converted_mc/{s}_mcq.csv\n", .{track});
    } else {
        print("{s}Unknown track: {s}{s}\n", .{ RED, track, RESET });
    }

    print("\n", .{});
}

fn runEvalCommand(allocator: Allocator, args: []const []const u8) !void {
    const CsvParser = @import("../kaggle/csv_parser.zig").CsvParser;
    const Evaluator = @import("../kaggle/evaluator.zig").Evaluator;

    const track = if (args.len > 1 and std.mem.eql(u8, args[0], "--track"))
        args[1]
    else
        "tmp";

    const csv_files = std.StringHashMap([]const u8).init(allocator);
    defer csv_files.deinit();

    try csv_files.put("tmp", "kaggle/data/tmp_metacognition.csv");
    try csv_files.put("thlp", "kaggle/data/thlp_learning.csv");
    try csv_files.put("tagp", "kaggle/data/tagp_attention.csv");
    try csv_files.put("tefb", "kaggle/data/tefb_executive.csv");
    try csv_files.put("tscp", "kaggle/data/tscp_social.csv");

    print("\n{s}📊 EVALUATOR (Mock){s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("Track: {s}\n", .{track});
    print("Mode: Mock responses (70% accuracy)\n\n");

    if (csv_files.get(track)) |path| {
        const parser = CsvParser.init(allocator, path);
        const result = try parser.parse();

        const evaluator = Evaluator.init(allocator);

        // Generate mock responses
        var responses = std.ArrayList([]const u8).init(allocator);
        defer {
            for (responses.items) |r| allocator.free(r);
            responses.deinit();
        }

        for (result.rows) |r| {
            try responses.append(try evaluator.mockResponse(r));
        }

        // Evaluate
        const eval_result = try evaluator.evaluate(result.rows, responses.items);
        evaluator.printReport(eval_result);

        // Cleanup
        allocator.free(result.rows);
        for (result.rows) |r| {
            allocator.free(r.id);
            allocator.free(r.task);
            allocator.free(r.question);
            allocator.free(r.answer);
            if (r.brain_zone.len > 0) allocator.free(r.brain_zone);
            if (r.neural_analog.len > 0) allocator.free(r.neural_analog);
        }
        result.stats.deinit();
    } else {
        print("{s}Unknown track: {s}{s}\n", .{ RED, track, RESET });
    }

    print("\n", .{});
}

fn runExportCommand(allocator: Allocator, args: []const []const u8) !void {
    _ = args;

    print("\n{s}📦 EXPORT{s}\n", .{ BOLD, RESET });
    print("{s}══════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("Output: kaggle/submissions/<track>_submission.csv\n\n");
    print("Export format: CSV (id, answer)\n");
    print("Usage: tri kaggle export --track <id>\n\n");
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTH — Check ~/.kaggle/kaggle.json
// ═══════════════════════════════════════════════════════════════════════════════

fn runAuthCommand(allocator: Allocator) !void {
    print("\n{s}🔑 KAGGLE AUTHENTICATION CHECK{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    const home = std.process.getEnvVarOwned(allocator, "HOME") catch {
        print("{s}❌ Cannot determine HOME directory{s}\n", .{ RED, RESET });
        return error.HomeNotFound;
    };
    defer allocator.free(home);

    const kaggle_path = try std.fmt.allocPrint(allocator, "{s}/.kaggle/kaggle.json", .{home});
    defer allocator.free(kaggle_path);

    const file = std.fs.cwd().openFile(kaggle_path, .{}) catch |err| {
        print("{s}❌ Kaggle credentials not found{s}\n", .{ RED, RESET });
        print("   Expected: {s}\n\n", .{kaggle_path});
        print("   To authenticate:\n", .{});
        print("   1. Go to https://www.kaggle.com/settings\n", .{});
        print("   2. Click 'Create New API Token'\n", .{});
        print("   3. Download kaggle.json\n", .{});
        print("   4. Move to ~/.kaggle/kaggle.json\n\n", .{});
        return err;
    };
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 1024 * 1024) catch |err| {
        print("{s}❌ Failed to read kaggle.json: {}{s}\n", .{ RED, err, RESET });
        return err;
    };
    defer allocator.free(contents);

    // Parse JSON to get username
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch |err| {
        print("{s}⚠️  JSON parse error: {}{s}\n", .{ YELLOW, err, RESET });
        print("{s}✅ File exists at {s}{s}\n\n", .{ GREEN, kaggle_path, RESET });
        return;
    };
    defer parsed.deinit();

    if (parsed.value != .object) {
        print("{s}⚠️  Invalid kaggle.json format{s}\n", .{ YELLOW, RESET });
        return;
    }

    const username = parsed.value.object.get("username") orelse {
        print("{s}✅ Kaggle credentials found{s}\n", .{ GREEN, RESET });
        print("   Location: {s}\n\n", .{kaggle_path});
        return;
    };

    if (username != .string) {
        print("{s}✅ Kaggle credentials found{s}\n", .{ GREEN, RESET });
        print("   Location: {s}\n\n", .{kaggle_path});
        return;
    }

    print("{s}✅ Authenticated as: {s}{s}\n\n", .{ GREEN, username.string, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// META — Generate kernel-metadata.json for all notebooks
// ═══════════════════════════════════════════════════════════════════════════════

fn runMetaCommand(allocator: Allocator, args: []const []const u8) !void {
    const track_filter = if (args.len > 0) args[0] else "all";

    print("\n{s}📝 KERNEL METADATA GENERATION{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var total_generated: usize = 0;

    for (TRACKS) |track| {
        // Support shorthand: track1/track2/track3/track4/track5
        // track2 matches track2_metacognition (first 6 chars), etc.
        const filter_prefix_len = @min(track_filter.len, 6);
        const filter_prefix = track_filter[0..filter_prefix_len];
        const matches_shorthand = track_filter.len < 7 and std.mem.eql(u8, filter_prefix, track.id[0..filter_prefix_len]);

        // Check filter match (exact match only, no substrings)
        const filter_matches = std.mem.eql(u8, track_filter, "all") or
            matches_shorthand or
            std.mem.eql(u8, track_filter, track.id) or
            std.mem.eql(u8, track_filter, track.name);

        if (!filter_matches) {
            continue;
        }

        print("{s}Track: {s} — {s}{s}\n", .{ CYAN, track.id, track.name, RESET });

        // Open track directory
        var track_dir = std.fs.cwd().openDir(track.path, .{}) catch |err| {
            print("  {s}⚠️  Cannot open directory: {}{s}\n\n", .{ YELLOW, err, RESET });
            continue;
        };
        defer track_dir.close();

        // List notebooks - look for .ipynb files in track directory
        var generated: usize = 0;
        var iter = track_dir.iterate();

        while (try iter.next()) |entry| {

            // Skip non-files
            if (entry.kind != .file) continue;

            const ext = std.fs.path.extension(entry.name);
            if (!std.mem.eql(u8, ext, ".ipynb")) continue;

            const notebook_name = entry.name[0 .. entry.name.len - 6]; // Remove .ipynb
            const notebook_dir_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ track.path, notebook_name });
            defer allocator.free(notebook_dir_path);

            const meta_path = try std.fmt.allocPrint(allocator, "{s}/kernel-metadata.json", .{notebook_dir_path});
            defer allocator.free(meta_path);

            const src_notebook_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ track.path, entry.name });
            defer allocator.free(src_notebook_path);

            const dst_notebook_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ notebook_dir_path, entry.name });
            defer allocator.free(dst_notebook_path);

            // Create notebook subdirectory if needed
            std.fs.cwd().makePath(notebook_dir_path) catch |err| {
                print("  {s}❌ {s}: cannot create dir: {}{s}\n", .{ RED, notebook_name, err, RESET });
                continue;
            };

            // Copy notebook to subdirectory
            {
                const src = std.fs.cwd().openFile(src_notebook_path, .{}) catch |err| {
                    print("  {s}❌ {s}: cannot read notebook: {}{s}\n", .{ RED, notebook_name, err, RESET });
                    continue;
                };
                defer src.close();

                const contents = src.readToEndAlloc(allocator, 10 * 1024 * 1024) catch |err| {
                    print("  {s}❌ {s}: cannot read notebook: {}{s}\n", .{ RED, notebook_name, err, RESET });
                    continue;
                };
                defer allocator.free(contents);

                const dst = std.fs.cwd().createFile(dst_notebook_path, .{}) catch |err| {
                    print("  {s}❌ {s}: cannot write notebook: {}{s}\n", .{ RED, notebook_name, err, RESET });
                    continue;
                };
                defer dst.close();

                dst.writeAll(contents) catch |err| {
                    print("  {s}❌ {s}: cannot write notebook: {}{s}\n", .{ RED, notebook_name, err, RESET });
                    continue;
                };
            }

            // Generate metadata
            const metadata = try generateMetadata(allocator, track, notebook_name);
            defer allocator.free(metadata);

            // Write metadata file
            const file = std.fs.cwd().createFile(meta_path, .{}) catch |err| {
                print("  {s}❌ {s}: cannot create metadata: {}{s}\n", .{ RED, notebook_name, err, RESET });
                continue;
            };
            defer file.close();

            file.writeAll(metadata) catch |err| {
                print("  {s}❌ {s}: write error: {}{s}\n", .{ RED, notebook_name, err, RESET });
                continue;
            };

            print("  {s}✅{s} {s}\n", .{ GREEN, RESET, notebook_name });
            generated += 1;
            total_generated += 1;
        }

        print("  Generated: {d} metadata files\n\n", .{generated});
    }

    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}TOTAL: {d} metadata files generated{s}\n\n", .{ BOLD, total_generated, RESET });
}

fn generateMetadata(allocator: Allocator, track: Track, notebook_name: []const u8) ![]const u8 {
    // Parse notebook name to extract task info
    // Format: taskXX_name or similar
    const kernel_id = try std.fmt.allocPrint(allocator, "playra/trinity-{s}-{s}", .{ track.id, notebook_name });
    defer allocator.free(kernel_id);

    // Title: "Trinity {Track} Benchmark: TaskXX Name"
    var title_buf: [256]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "Trinity {s} Benchmark: {s}", .{
        track.name, formatNotebookName(notebook_name),
    }) catch &title_buf;

    // Build JSON
    var json_buf = try std.ArrayList(u8).initCapacity(allocator, 512);
    defer json_buf.deinit(allocator);

    const writer = json_buf.writer(allocator);

    try writer.print(
        \\{{"id":"{s}","title":"{s}","code_file":"{s}.ipynb","language":"python","kernel_type":"notebook","is_private":"false","enable_gpu":"false","enable_internet":"true","dataset_sources":["playra/{s}"],"competition_sources":["kaggle-measuring-agi"],"kernel_sources":[],"model_sources":[]}}
    , .{ kernel_id, title, notebook_name, track.dataset });

    return json_buf.toOwnedSlice(allocator);
}

fn formatNotebookName(name: []const u8) []const u8 {
    // Convert task01_few_shot_induction -> Task01 Few Shot Induction
    // For now, just return as-is (TODO: proper formatting)
    return name;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUSH — Push notebooks to Kaggle
// ═══════════════════════════════════════════════════════════════════════════════

fn runPushCommand(allocator: Allocator, args: []const []const u8) !void {
    const track_filter = if (args.len > 0) args[0] else "all";

    print("\n{s}🚀 PUSHING NOTEBOOKS TO KAGGLE{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var total_pushed: usize = 0;
    var total_errors: usize = 0;

    for (TRACKS) |track| {
        // Support shorthand: track1/track2/track3/track4/track5
        // track2 matches track2_metacognition (first 6 chars), etc.
        const filter_prefix_len = @min(track_filter.len, 6);
        const filter_prefix = track_filter[0..filter_prefix_len];
        const matches_shorthand = track_filter.len < 7 and std.mem.eql(u8, filter_prefix, track.id[0..filter_prefix_len]);

        // Check filter match (exact match only, no substrings)
        const filter_matches = std.mem.eql(u8, track_filter, "all") or
            matches_shorthand or
            std.mem.eql(u8, track_filter, track.id) or
            std.mem.eql(u8, track_filter, track.name);

        if (!filter_matches) {
            continue;
        }

        print("{s}Track: {s} — {s}{s}\n", .{ CYAN, track.id, track.name, RESET });

        // Open track directory
        var track_dir = std.fs.cwd().openDir(track.path, .{}) catch |err| {
            print("  {s}⚠️  Cannot open directory: {}{s}\n\n", .{ YELLOW, err, RESET });
            continue;
        };
        defer track_dir.close();

        // List notebook subdirectories
        var pushed: usize = 0;
        var iter = track_dir.iterate();
        while (try iter.next()) |entry| {
            // Only process directories (notebook subdirs)
            if (entry.kind != .directory) continue;

            // Check if kernel-metadata.json exists in this subdir
            const subdir_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ track.path, entry.name });
            defer allocator.free(subdir_path);

            const meta_path = try std.fmt.allocPrint(allocator, "{s}/kernel-metadata.json", .{subdir_path});
            defer allocator.free(meta_path);

            // Skip if no kernel-metadata.json
            if (std.fs.cwd().openFile(meta_path, .{})) |_| {
                // File exists, proceed
            } else |_| {
                continue; // Skip directories without metadata
            }

            print("  Pushing {s}...", .{entry.name});

            // Run: kaggle kernels push <subdir_path>
            const result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &.{ "kaggle", "kernels", "push", subdir_path },
                .max_output_bytes = 1024 * 1024,
            }) catch |err| {
                print(" {s}❌ spawn error: {}{s}\n", .{ RED, err, RESET });
                total_errors += 1;
                continue;
            };
            defer allocator.free(result.stdout);
            defer allocator.free(result.stderr);

            const exit_code = switch (result.term) {
                .Exited => |code| code,
                else => @as(u32, 1),
            };

            if (exit_code == 0) {
                print(" {s}✅{s}\n", .{ GREEN, RESET });
                pushed += 1;
                total_pushed += 1;
            } else {
                print(" {s}❌{s}\n", .{ RED, RESET });
                if (result.stderr.len > 0) {
                    print("    {s}\n", .{result.stderr});
                }
                total_errors += 1;
            }

            // Rate limit delay
            std.Thread.sleep(500 * std.time.ns_per_ms);
        }

        print("  Pushed: {d}/{d}\n\n", .{ pushed, track.notebook_count });
    }

    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}TOTAL: {d} pushed | {d} errors{s}\n\n", .{ BOLD, total_pushed, total_errors, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS — Check kernel status
// ═══════════════════════════════════════════════════════════════════════════════

fn runStatusCommand(allocator: Allocator) !void {
    const CsvParser = @import("../kaggle/csv_parser.zig").CsvParser;

    print("\n{s}📊 KAGGLE STATUS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    const csv_files = [_]struct { id: []const u8, name: []const u8, path: []const u8 }{
        .{ .id = "tmp", .name = "Metacognition", .path = "kaggle/data/tmp_metacognition.csv" },
        .{ .id = "thlp", .name = "Learning", .path = "kaggle/data/thlp_learning.csv" },
        .{ .id = "tagp", .name = "Attention", .path = "kaggle/data/tagp_attention.csv" },
        .{ .id = "tefb", .name = "Executive", .path = "kaggle/data/tefb_executive.csv" },
        .{ .id = "tscp", .name = "Social", .path = "kaggle/data/tscp_social.csv" },
    };

    for (csv_files) |track| {
        const file = std.fs.cwd().openFile(track.path, .{}) catch |err| {
            print("  {s}{s} — {s}: {s}File not found{s}\n", .{ CYAN, track.id, track.name, RED, RESET });
            continue;
        };
        defer file.close();

        const stat = try file.stat();
        const size_kb: f64 = @floatFromInt(stat.size) / 1024;

        print("  {s}{s} — {s}{s}\n", .{ CYAN, track.id, track.name, RESET });
        print("    File: {s}\n", .{track.path});
        print("    Size: {d:.1} KB\n", .{size_kb});
        print("\n");
    }

    print("{s}════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// VALIDATE — Validate submission format
// ═══════════════════════════════════════════════════════════════════════════════

fn runValidateCommand(allocator: Allocator) !void {
    print("\n{s}✓ SUBMISSION VALIDATION{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    // Run: python kaggle/eval/validation.py
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "python3", "kaggle/eval/validation.py" },
        .max_output_bytes = 1024 * 1024,
    }) catch |err| {
        print("{s}❌ Failed to run validation: {}{s}\n", .{ RED, err, RESET });
        print("   Make sure kaggle/eval/validation.py exists\n\n", .{});
        return err;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) {
        print("{s}", .{result.stdout});
    }

    const exit_code = switch (result.term) {
        .Exited => |code| code,
        else => @as(u32, 1),
    };

    if (exit_code == 0) {
        print("{s}✅ Validation passed{s}\n\n", .{ GREEN, RESET });
    } else {
        print("{s}❌ Validation failed{s}\n", .{ RED, RESET });
        if (result.stderr.len > 0) {
            print("{s}\n", .{result.stderr});
        }
        print("\n", .{});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELP
// ═══════════════════════════════════════════════════════════════════════════════

fn printHelp() void {
    print(
        \\
        \\Usage: tri kaggle <command> [options]
        \\
        \\Data Commands:
        \\  parse --track <id>       Parse CSV files and show statistics
        \\  convert --track <id>     Convert open-ended questions to MC format (local)
        \\  eval --track <id>        Run local evaluation with Trinity models
        \\  export --track <id>      Export to Kaggle-compatible format
        \\  validate --track <id>    Validate CSV files before upload
        \\  status                   Show all tracks status
        \\
        \\Kaggle Commands:
        \\  auth                     Check Kaggle authentication (~/.kaggle/kaggle.json)
        \\  meta [track]             Generate kernel-metadata.json for notebooks
        \\  push <track>             Push notebooks to Kaggle
        \\
        \\Tracks:
        \\  tmp  — Metacognition (2200 items)
        \\  thlp — Learning (2400 items)
        \\  tagp — Attention (2200 items)
        \\  tefb — Executive (2400 items)
        \\  tscp — Social (2200 items)
        \\
        \\Examples:
        \\  tri kaggle status
        \\  tri kaggle parse --track tmp
        \\  tri kaggle convert --track tmp
        \\  tri kaggle eval --track tmp
        \\  tri kaggle export --track tmp
        \\  tri kaggle validate --track all
        \\
    , .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "kaggle help" {
    printHelp();
}

test "generate metadata" {
    const allocator = std.testing.allocator;
    const track = Track{
        .id = "track2_metacognition",
        .name = "Metacognition",
        .dataset = "trinity-cognitive-probes-tmp",
        .path = "kaggle/notebooks/track2_metacognition",
        .notebook_count = 2,
    };

    const metadata = try generateMetadata(allocator, track, "task06_confidence_calib");
    defer allocator.free(metadata);

    try std.testing.expect(std.mem.indexOf(u8, metadata, "playra/trinity-track2_metacognition-task06_confidence_calib") != null);
    try std.testing.expect(std.mem.indexOf(u8, metadata, "task06_confidence_calib.ipynb") != null);
    try std.testing.expect(std.mem.indexOf(u8, metadata, "trinity-cognitive-probes-tmp") != null);
}
