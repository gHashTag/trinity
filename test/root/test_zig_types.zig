const std = @import("std");
const yaml = @import("yaml");

pub fn main() !void {
    const yaml_content =
        \\types:
        \\  ShardNetwork:
        \\    fields:
        \\      root_buf: "\"[256]u8\""
    ;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var docs = try yaml.parse(allocator, yaml_content);
    defer docs.deinit();

    // Navigate to root_buf field
    const types = docs.value.map.get("types").?.map;
    const shard_network = types.get("ShardNetwork").?.map;
    const fields = shard_network.get("fields").?.map;
    const root_buf = fields.get("root_buf").?.string;

    std.debug.print("root_buf value bytes: ", .{});
    for (root_buf) |c| {
        std.debug.print("{x} ", .{c});
    }
    std.debug.print("\n", .{});
    std.debug.print("root_buf value: '{s}'\n", .{root_buf});
    std.debug.print("root_buf len: {d}\n", .{root_buf.len});
    std.debug.print("root_buf[0]: '{c}' ({x})\n", .{root_buf[0], root_buf[0]});
    std.debug.print("root_buf[1]: '{c}' ({x})\n", .{root_buf[1], root_buf[1]});
}
