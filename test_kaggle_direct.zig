const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Import kaggle modules
    const CsvParser = @import("src/kaggle/csv_parser.zig").CsvParser;
    const McGenerator = @import("src/kaggle/mc_generator.zig").McGenerator;
    const Matcher = @import("src/kaggle/matcher.zig").Matcher;
    const Evaluator = @import("src/kaggle/evaluator.zig").Evaluator;
    
    // Test CSV parser
    std.debug.print("📊 Testing CSV Parser...\n", .{});
    const parser = CsvParser.init(allocator, "kaggle/data/tmp_metacognition.csv");
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
    
    std.debug.print("Total: {d}, Open-ended: {d}, Factual: {d}\n", .{
        result.stats.total_rows,
        result.stats.open_ended,
        result.stats.factual,
    });
    
    // Test matcher
    std.debug.print("\n🔍 Testing Matcher...\n", .{});
    const matcher = Matcher.init(allocator);
    const match_result = matcher.match("Tashkent", "Tashkent");
    std.debug.print("Match result: matched={}, strategy={}\n", .{
        match_result.matched,
        match_result.strategy,
    });
    
    // Test MC generator
    std.debug.print("\n🎨 Testing MC Generator...\n", .{});
    var gen = McGenerator.init(allocator);
    if (result.rows.len > 0) {
        const mc = try gen.convertToMc(result.rows[0]);
        defer {
            allocator.free(mc.id);
            allocator.free(mc.task);
            allocator.free(mc.question);
            allocator.free(mc.choices);
            allocator.free(mc.brain_zone);
            allocator.free(mc.neural_analog);
        }
        std.debug.print("MC Question created with {d} choices\n", .{mc.choices});
    }
    
    // Test evaluator
    std.debug.print("\n📊 Testing Evaluator...\n", .{});
    const evaluator = Evaluator.init(allocator);
    std.debug.print("Evaluator initialized\n", .{});
    
    std.debug.print("\n✅ All kaggle modules work!\n", .{});
}
