// CLUTRR Benchmark CLI — Independent executable
// Usage: clutrr_bench <csv_file>

const std = @import("std");
const clutrr = @import("clutrr.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Get args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print(
            \\CLUTRR Benchmark — Compositional Language Understanding & Textual Relational Reasoning
            \\
            \\Usage: clutrr_bench <csv_file>
            \\
            \\Arguments:
            \\  csv_file    Path to CLUTRR dataset CSV file
            \\
            \\Output:
            \\  Overall accuracy and per-depth breakdown (k=1 to k=10)
            \\
        , .{});
        return;
    }

    const csv_path = args[1];
    std.debug.print("🔬 CLUTRR Benchmark\n", .{});
    std.debug.print("📂 Dataset: {s}\n\n", .{csv_path});

    // Parse CSV
    std.debug.print("⏳ Parsing CSV...\n", .{});
    var parser = clutrr.ClutrrParser.init(allocator, csv_path);
    const examples = try parser.parse();
    defer {
        for (examples) |ex| {
            allocator.free(ex.id);
            allocator.free(ex.story);
            allocator.free(ex.query);
            allocator.free(ex.target);
            allocator.free(ex.proof_state);
            allocator.free(ex.proof_line);
            allocator.free(ex.proof_type);
            allocator.free(ex.answer);
            allocator.free(ex.proof_type_short);
            allocator.free(ex.proof_type_long);
            for (ex.facts) |*f| {
                allocator.free(f.subject);
                allocator.free(f.object);
            }
        }
        allocator.free(examples);
    }

    std.debug.print("✅ Loaded {} examples\n\n", .{examples.len});

    if (examples.len == 0) {
        std.debug.print("⚠️  No examples found in CSV\n", .{});
        return;
    }

    // Run evaluation
    std.debug.print("🧠 Running Datalog reasoning...\n", .{});
    var evaluator = clutrr.ClutrrEvaluator.init(allocator, examples);
    try evaluator.evaluate();

    // Print results
    const accuracy = evaluator.accuracy();
    std.debug.print(
        \\
        \\═══════════════════════════════════════════════════════════════
        \\📊 RESULTS
        \\═══════════════════════════════════════════════════════════════
        \\Overall Accuracy: {d:.2}% ({d}/{d} correct)
        \\
    , .{ accuracy * 100.0, evaluator.correct, evaluator.total });

    // Per-depth breakdown
    std.debug.print("\nDepth (k) Breakdown:\n", .{});
    std.debug.print("───────────────────────────────────────────────────────\n", .{});
    std.debug.print("{s} | {s} | {s} | {s}\n", .{ "Depth", "Total", "Correct", "Accuracy" });
    std.debug.print("───────────────────────────────────────────────────────\n", .{});

    var total_by_depth: usize = 0;
    var correct_by_depth: usize = 0;

    for (evaluator.by_depth, 0..) |count, depth| {
        if (count == 0) continue;
        total_by_depth += count;
        const correct = evaluator.by_depth_correct[depth];
        correct_by_depth += correct;
        const depth_acc: f32 = if (count > 0)
            @as(f32, @floatFromInt(correct)) / @as(f32, @floatFromInt(count))
        else
            0.0;

        std.debug.print("{d:>4} | {d:>6} | {d:>7} | {d:>4}%\n", .{
            depth + 1,
            count,
            correct,
            @as(usize, @intFromFloat(depth_acc * 100.0)),
        });
    }

    std.debug.print("───────────────────────────────────────────────────────\n", .{});
    if (total_by_depth > 0) {
        const overall_acc: f32 = @as(f32, @floatFromInt(correct_by_depth)) / @as(f32, @floatFromInt(total_by_depth));
        std.debug.print("{s:>4} | {d:>6} | {d:>7} | {d:>4}%\n", .{
            "ALL",
            total_by_depth,
            correct_by_depth,
            @as(usize, @intFromFloat(overall_acc * 100.0)),
        });
    }

    // Relation distribution
    std.debug.print(
        \\═══════════════════════════════════════════════════════════════
        \\🎯 Relation Distribution
        \\═══════════════════════════════════════════════════════════════
    , .{});

    var relation_counts = std.AutoHashMap(clutrr.Relation, usize).init(allocator);
    defer relation_counts.deinit();

    for (examples) |ex| {
        const entry = try relation_counts.getOrPut(ex.relation);
        if (!entry.found_existing) {
            entry.value_ptr.* = 0;
        }
        entry.value_ptr.* += 1;
    }

    // Sort relations by count
    var relations = std.ArrayList(struct { relation: clutrr.Relation, count: usize }).initCapacity(allocator, 0) catch @panic("OOM");
    defer relations.deinit(allocator);

    var iter = relation_counts.iterator();
    while (iter.next()) |entry| {
        try relations.append(allocator, .{ .relation = entry.key_ptr.*, .count = entry.value_ptr.* });
    }

    // Simple bubble sort (good enough for small lists)
    for (0..relations.items.len) |i| {
        for (i + 1..relations.items.len) |j| {
            if (relations.items[j].count > relations.items[i].count) {
                const temp = relations.items[i];
                relations.items[i] = relations.items[j];
                relations.items[j] = temp;
            }
        }
    }

    for (relations.items) |r| {
        std.debug.print("{s:>20}: {d}\n", .{ @tagName(r.relation), r.count });
    }
}

// φ² + 1/φ² = 3 | TRINITY
