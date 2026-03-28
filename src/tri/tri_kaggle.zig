// @origin(manual) @regen(pending)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI KAGGLE — Unified CLI for Kaggle operations
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri kaggle auth        — Check ~/.kaggle/kaggle.json
//   tri kaggle meta        — Generate kernel-metadata.json for all notebooks
//   tri kaggle push <track> — Push notebooks to Kaggle
//   tri kaggle status      — Check kernel status
//   tri kaggle validate    — Validate submission format
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

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

    if (std.mem.eql(u8, subcmd, "auth")) {
        return runAuthCommand(allocator);
    } else if (std.mem.eql(u8, subcmd, "meta")) {
        return runMetaCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "push")) {
        return runPushCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        return runStatusCommand(allocator);
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

        // Debug output
        print("[DEBUG] filter='{s}', track.id='{s}', filter_prefix='{s}', prefix_len={d}, matches_shorthand={}\n",
              .{track_filter, track.id, filter_prefix, filter_prefix_len, matches_shorthand});

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
    print("\n{s}📊 KAGGLE KERNEL STATUS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    // Run: kaggle kernels list --user
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "kaggle", "kernels", "list", "--user" },
        .max_output_bytes = 1024 * 1024,
    }) catch |err| {
        print("{s}❌ Failed to list kernels: {}{s}\n", .{ RED, err, RESET });
        return err;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) {
        print("{s}", .{result.stdout});
    }

    if (result.stderr.len > 0) {
        print("{s}Errors:{s}\n{s}", .{ RED, RESET, result.stderr });
    }

    print("\n", .{});
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
        \\Commands:
        \\  auth              Check Kaggle authentication (~/.kaggle/kaggle.json)
        \\  meta [track]      Generate kernel-metadata.json for all notebooks (or specific track)
        \\  push <track>      Push notebooks to Kaggle (track: track1/track2/track3/track4/track5/all)
        \\  status            List pushed kernels
        \\  validate          Validate submission format
        \\  help              Show this help
        \\
        \\Tracks:
        \\  track1_learning      — 10 notebooks (THLP dataset)
        \\  track2_metacognition — 2 notebooks (TMP dataset) ← PILOT
        \\  track3_attention     — 10 notebooks (TAGP dataset)
        \\  track4_executive     — 10 notebooks (TEFB dataset)
        \\  track5_social        — 8 notebooks (TSCP dataset)
        \\
        \\Examples:
        \\  tri kaggle auth
        \\  tri kaggle meta track2
        \\  tri kaggle push track2    # Pilot: Track 2 Metacognition
        \\  tri kaggle push all
        \\  tri kaggle status
        \\  tri kaggle validate
        \\
        \\Pilot Workflow:
        \\  1. tri kaggle auth        # Check authentication
        \\  2. tri kaggle meta track2  # Generate metadata for Track 2
        \\  3. tri kaggle push track2  # Push 2 notebooks to Kaggle
        \\  4. tri kaggle status       # Check kernel status
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
