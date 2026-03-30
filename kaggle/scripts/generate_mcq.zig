const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse command line args
    const args = try std.process.argsAlloc(allocator) catch |err| {
        std.debug.print("Error parsing args: {}\n", .{err});
        std.process.exit(1);
    };

    if (args.len < 3) {
        std.debug.print("Usage: ./generate_mcq <input_csv> <output_csv>\n", .{});
        std.debug.print("Example: ./generate_mcq kaggle/data/thlp_learning.csv kaggle/data/thlp_learning_mcq.csv\n", .{});
        std.process.exit(1);
    }

    const input_path = args[1];
    const output_path = args[2];

    // Read input CSV
    std.debug.print("Reading: {}\n", .{input_path});
    const input_file = try std.fs.cwd().openFile(input_path, .{}) catch |err| {
        std.debug.print("Error opening file: {}\n", .{err});
        std.process.exit(1);
    };
    defer input_file.close();

    const input_data = try input_file.readToEndAlloc(allocator) catch |err| {
        std.debug.print("Error reading file: {}\n", .{err});
        std.process.exit(1);
    };

    // Parse CSV
    var reader = std.csv.Reader.init(allocator);
    var rows = std.ArrayList(Row).init(allocator);

    {
        var line_iter = std.mem.splitScalar(u8, input_data, '\n');
        while (line_iter.next()) |line| {
            if (line.len == 0) continue;
            var field_iter = std.mem.splitScalar(u8, line, ',');
            var fields = std.ArrayList([]const u8).init(allocator);
            while (field_iter.next()) |field| {
                var f = std.mem.trim(u8, field);
                // Remove quotes if present
                if (f.len >= 2 and f[0] == '"' and f[f.len-1] == '"') {
                    f = f[1 .. f.len-1];
                }
                try fields.append(f);
            }
            if (fields.items.len >= 4) {
                try rows.append(.{
                    .id = allocator.dupe(u8, fields.items[0]),
                    .task = allocator.dupe(u8, fields.items[1]),
                    .question = allocator.dupe(u8, fields.items[2]),
                    .answer = allocator.dupe(u8, fields.items[3]),
                });
            }
        }
    }

    std.debug.print("Found {} questions to convert\n", .{rows.items.len});

    // Generate MCQ for each row
    var rng = std.Random.DefaultPrng.init(@intCast(u64, @intFromFloat(std.time.nanoTimestamp())));
    var writer = std.io.BufferedWriter(1); // stdout

    // Write header
    try writer.writeAll("id,task,question,choices,answer,difficulty,brain_zone,neural_analog\n");

    var converted: usize = 0;

    for (rows.items) |row| {
        // Check if this is an open-ended question (has 'question' field)
        if (row.question.len == 0) continue;

        const prompt = try std.fmt.allocPrint(allocator,
            \\Generate 3 plausible-but-wrong multiple choice distractors for this question.
            \\The distractors must be:
            \\1. Factually incorrect BUT semantically plausible
            \\2. Related to the topic domain
            \\3. NOT obviously wrong (e.g., not "potato", not random gibberish)
            \\4. Common misconceptions or related concepts are good distractors

            \\QUESTION: {s}
            \\CORRECT ANSWER: {s}

            \\Return ONLY a JSON array of 3 strings: ["distractor1", "distractor2", "distractor3"]
            \\NO explanation, NO markdown, ONLY the JSON array.
        , .{ row.question, row.answer });

        // TODO: Call LLM API here
        // For now, generate dummy distractors
        _ = prompt;
        _ = rng;

        try writer.writeAll(try std.fmt.allocPrint(allocator,
            "{s},{s},{s},{s},{s},{s},{s}\n",
            .{ row.id, row.task, row.question, "A) {s}\\nB) dummy1\\nC) dummy2\\nD) dummy3",
              row.answer,
              "5.0", // default difficulty
              if (std.mem.eql(u8, row.task, "Confidence Calibration")) "ofc"
              else if (std.mem.eql(u8, row.task, "Belief Update Under Correction")) "hippocampus"
              else if (std.mem.eql(u8, row.task, "Few-Shot Rule Induction")) "hippocampus"
              else if (std.mem.eql(u8, row.task, "Error-Driven Learning")) "amygdala"
              else if (std.mem.eql(u8, row.task, "Reward-Signal Learning")) "accumbens"
              else if (std.mem.eql(u8, row.task, "Strategic Adaptation")) "acc"
              else if (std.mem.eql(u8, row.task, "Knowledge Boundary")) "habenula"
              else if (std.mem.eql(u8, row.task, "Monitoring Under Load")) "insula"
              else if (std.mem.eql(u8, row.task, "Error Self-Detection")) "acc"
              else "cortex",
              if (std.mem.eql(u8, row.task, "Confidence Calibration")) "OFC value judgment requires calibrated confidence"
              else if (std.mem.eql(u8, row.task, "Belief Update Under Correction")) "Hippocampus cache invalidation triggers belief revision"
              else if (std.mem.eql(u8, row.task, "Few-Shot Rule Induction")) "Hippocampus PopulationCache stores patterns for fast retrieval and completion"
              else if (std.mem.eql(u8, row.task, "Error-Driven Learning")) "Amygdala strengthens associations on prediction errors"
              else if (std.mem.eql(u8, row.task, "Reward-Signal Learning")) "ACCumbens tracks reward stationarity for reinforcement"
              else if (std.mem.eql(u8, row.task, "Strategic Adaptation")) "ACC + Amygdala Minimum Necessary Learning"
              else if (std.mem.eql(u8, row.task, "Knowledge Boundary")) "HABENULA anti-corruption: effort must match reward"
              else if (std.mem.eql(u8, row.task, "Monitoring Under Load")) "Insula measures internal state and resource health"
              else if (std.mem.eql(u8, row.task, "Error Self-Detection")) "ACC detects stale cache vs live state conflicts"
              else "Cortex GoldenChain executes 28-link agentic pipeline with role-based coordination"
        )) catch |err| {
            std.debug.print("Error writing: {}\n", .{err});
        };

        converted += 1;
        if (converted % 10 == 0) {
            try writer.flush();
            std.debug.print("Converted: {}/{}\n", .{converted, rows.items.len});
        }
    }

    try writer.flush();
    std.debug.print("\nConverted {} questions to MCQ format\n", .{converted});
    std.debug.print("Output would be written to: {}\n", .{output_path});
}

const Row = struct {
    id: []const u8,
    task: []const u8,
    question: []const u8,
    answer: []const u8,
};
