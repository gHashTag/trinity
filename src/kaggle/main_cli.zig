// TRI-KAGGLE — Standalone Kaggle CLI (bypasses broken tri modules)
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const CsvParser = @import("csv_parser.zig").CsvParser;
const McGenerator = @import("mc_generator.zig").McGenerator;
const Matcher = @import("matcher.zig").Matcher;
const Evaluator = @import("evaluator.zig").Evaluator;
const Exporter = @import("export.zig").Exporter;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const cmd = args[1];
    const cmd_args = if (args.len > 2) args[2..] else &[_][]const u8{};

    if (std.mem.eql(u8, cmd, "parse")) {
        try runParse(allocator, cmd_args);
    } else if (std.mem.eql(u8, cmd, "test")) {
        try runTest(allocator);
    } else if (std.mem.eql(u8, cmd, "eval")) {
        try runEval(allocator, cmd_args);
    } else if (std.mem.eql(u8, cmd, "status")) {
        try runStatus(allocator);
    } else if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "-h") or std.mem.eql(u8, cmd, "--help")) {
        printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n\n", .{cmd});
        printUsage();
    }
}

fn runParse(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: tri-kaggle parse <file.csv>\n", .{});
        return;
    }

    const file_path = args[0];
    const parser = CsvParser.init(allocator, file_path);
    const result = try parser.parse();

    std.debug.print("Parsed {d} rows from {s}\n", .{ result.rows.len, file_path });
    std.debug.print("Tasks: ", .{});

    var tasks = std.StringHashMap(usize).init(allocator);
    defer tasks.deinit();  // Keys point to CsvRow data, freed separately

    for (result.rows) |row| {
        const count = tasks.get(row.task) orelse 0;
        try tasks.put(row.task, count + 1);
    }

    var task_iter = tasks.iterator();
    while (task_iter.next()) |e| {
        std.debug.print("{s}={d} ", .{ e.key_ptr.*, e.value_ptr.* });
    }
    std.debug.print("\n", .{});

    // Cleanup
    for (result.rows) |r| {
        allocator.free(r.id);
        allocator.free(r.task);
        allocator.free(r.question);
        allocator.free(r.answer);
        if (r.brain_zone.len > 0) allocator.free(r.brain_zone);
        if (r.neural_analog.len > 0) allocator.free(r.neural_analog);
    }
    allocator.free(result.rows);
}

fn runTest(allocator: std.mem.Allocator) !void {
    const matcher = Matcher.init(allocator);

    // Test basic matching
    const tests = [_]struct { response: []const u8, expected: []const u8, should_match: bool }{
        .{ .response = "Tashkent", .expected = "Tashkent", .should_match = true },
        .{ .response = "tashkent", .expected = "TASHKENT", .should_match = true },
        .{ .response = "A", .expected = "A", .should_match = true },
        .{ .response = "The capital is Tashkent", .expected = "Tashkent", .should_match = true },
        .{ .response = "Wrong", .expected = "Tashkent", .should_match = false },
    };

    var passed: usize = 0;
    for (tests) |t| {
        const result = matcher.match(t.response, t.expected);
        if (result.matched == t.should_match) {
            passed += 1;
            std.debug.print("✅ ", .{});
        } else {
            std.debug.print("❌ ", .{});
        }
        std.debug.print("{s} vs {s} -> matched={any}\n", .{ t.response, t.expected, result.matched });
    }

    std.debug.print("\nMatcher tests: {d}/{d} passed\n", .{ passed, tests.len });
}

fn runEval(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: tri-kaggle eval <file.csv>\n", .{});
        return;
    }

    const file_path = args[0];
    const parser = CsvParser.init(allocator, file_path);
    const parse_result = try parser.parse();
    defer {
        for (parse_result.rows) |r| {
            allocator.free(r.id);
            allocator.free(r.task);
            allocator.free(r.question);
            allocator.free(r.answer);
            if (r.brain_zone.len > 0) allocator.free(r.brain_zone);
            if (r.neural_analog.len > 0) allocator.free(r.neural_analog);
        }
        allocator.free(parse_result.rows);
    }

    const evaluator = Evaluator.init(allocator);

    // Generate mock responses (70% correct)
    var responses = try std.ArrayList([]const u8).initCapacity(allocator, parse_result.rows.len);
    defer {
        for (responses.items) |r| allocator.free(r);
        responses.deinit(allocator);
    }

    const ts64 = std.time.nanoTimestamp();
    const ts_int: i64 = @intCast(ts64);
    const seed: u64 = @intCast(@abs(ts_int));
    var rng = std.Random.DefaultPrng.init(seed);
    for (parse_result.rows) |row| {
        if (rng.random().float(f64) < 0.7) {
            try responses.append(allocator, try allocator.dupe(u8, row.answer));
        } else {
            try responses.append(allocator, try allocator.dupe(u8, "incorrect"));
        }
    }

    var eval_result = try evaluator.evaluate(parse_result.rows, responses.items);
    evaluator.printReport(eval_result);

    // Cleanup eval_result
    eval_result.deinit(allocator);
}

fn runStatus(allocator: std.mem.Allocator) !void {
    const data_dir = "kaggle/data";
    var dir = std.fs.cwd().openDir(data_dir, .{}) catch {
        std.debug.print("Data directory not found: {s}\n", .{data_dir});
        return;
    };
    defer dir.close();

    std.debug.print("Kaggle data directory: {s}\n\n", .{data_dir});

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".csv")) {
            const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ data_dir, entry.name });
            defer allocator.free(file_path);

            // Get file size
            const file = std.fs.cwd().openFile(file_path, .{}) catch continue;
            const stat = file.stat() catch {
                file.close();
                continue;
            };
            file.close();

            std.debug.print("  {s}: {d} bytes\n", .{ entry.name, stat.size });
        }
    }
}

fn printUsage() void {
    std.debug.print(
        \\TRI-KAGGLE — Cognitive Benchmark Evaluation CLI
        \\
        \\Usage: tri-kaggle <command> [args]
        \\
        \\Commands:
        \\  parse <file>        Parse and analyze CSV benchmark file
        \\  test               Run matcher tests
        \\  eval <file>        Evaluate with mock responses
        \\  status             Show data directory status
        \\  help               Show this help
        \\
        \\Examples:
        \\  tri-kaggle parse kaggle/data/tmp_metacognition.csv
        \\  tri-kaggle test
        \\  tri-kaggle eval kaggle/data/tmp_metacognition.csv
        \\  tri-kaggle status
        \\
    , .{});
}
