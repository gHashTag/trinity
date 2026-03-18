const std = @import("std");
const engine = @import("src/tri/self_improver_engine.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Test quality mode and parse JSON
    const json = try engine.selfImproverToJson(allocator, "quality");
    defer allocator.free(json);

    var parser = std.json.Parser.init(allocator, .alloc_always);
    defer parser.deinit();

    var tree = try parser.parse(json);
    defer tree.deinit();

    const root = tree.root.object;

    std.debug.print("✓ JSON is valid!\n", .{});
    std.debug.print("✓ mode: {s}\n", .{root.get("mode").?.string});
    std.debug.print("✓ version: {s}\n", .{root.get("version").?.string});
    std.debug.print("✓ engine: {s}\n", .{root.get("engine").?.string});
    std.debug.print("✓ trinity_check: {d:.6}\n", .{root.get("trinity_check").?.float});
    std.debug.print("✓ quality_metrics count: {d}\n", .{root.get("quality_metrics").?.array.items.len});
}
