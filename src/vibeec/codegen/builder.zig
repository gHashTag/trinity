// ═══════════════════════════════════════════════════════════════════════════════
// CODE BUILDER - Buffer management and output generation
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const CodeBuilder = struct {
    allocator: Allocator,
    buffer: std.ArrayListUnmanaged(u8),
    indent: u32,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .buffer = .{},
            .indent = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn write(self: *Self, str: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, str);
    }

    pub fn writeLine(self: *Self, str: []const u8) !void {
        try self.writeIndent();
        try self.buffer.appendSlice(self.allocator, str);
        try self.buffer.append(self.allocator, '\n');
    }

    pub fn writeIndent(self: *Self) !void {
        var i: u32 = 0;
        while (i < self.indent) : (i += 1) {
            try self.buffer.appendSlice(self.allocator, "    ");
        }
    }

    pub fn writeFmt(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        const writer = self.buffer.writer(self.allocator);
        try writer.print(fmt, args);
    }

    pub fn newline(self: *Self) !void {
        try self.buffer.append(self.allocator, '\n');
    }

    pub fn incIndent(self: *Self) void {
        self.indent += 1;
    }

    pub fn decIndent(self: *Self) void {
        if (self.indent > 0) self.indent -= 1;
    }

    pub fn getOutput(self: *Self) []const u8 {
        return self.buffer.items;
    }
};
