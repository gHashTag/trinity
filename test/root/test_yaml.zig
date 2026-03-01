const std = @import("std");

pub fn main() !void {
    // Simple parse to see what we get
    const line = "      root_buf: \"\\\"[256]u8\\\"\"";
    
    if (std.mem.indexOf(u8, line, "root_buf:")) |idx| {
        const value = line[idx + "root_buf:".len ..];
        const trimmed = std.mem.trim(u8, value, " \t");
        std.debug.print("Value bytes: ", .{});
        for (trimmed) |c| {
            std.debug.print("{x} ", .{c});
        }
        std.debug.print("\n", .{});
        std.debug.print("Value as string: '{s}'\n", .{trimmed});
        std.debug.print("Value len: {d}\n", .{trimmed.len});
        std.debug.print("First char: '{c}' ({d})\n", .{trimmed[0], trimmed[0]});
        std.debug.print("Last char: '{c}' ({d})\n", .{trimmed[trimmed.len-1], trimmed[trimmed.len-1]});
        
        // Test quote stripping
        const clean = if (trimmed.len >= 2 and trimmed[0] == '"' and trimmed[trimmed.len-1] == '"')
            trimmed[1..trimmed.len-1]
        else
            trimmed;
        std.debug.print("Cleaned: '{s}'\n", .{clean});
    }
}
