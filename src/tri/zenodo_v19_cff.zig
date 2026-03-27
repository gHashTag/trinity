//! Zenodo V19: CFF (Citation File Format) Integration
//! Placeholder for future implementation

const std = @import("std");

pub const CffMetadata = struct {
    title: []const u8,
    version: []const u8,
    doi: []const u8,
    authors: []const Author,
    date_released: []const u8,

    pub const Author = struct {
        given_names: ?[]const u8,
        family_name: []const u8,
        orcid: ?[]const u8,
        affiliation: ?[]const u8,
    };

    pub fn toYaml(self: CffMetadata, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        try buffer.appendSlice("cff-version: 1.2.0\n");
        try buffer.appendSlice("message: \"If you use this software, please cite it as below.\"\n");
        try buffer.appendSlice("title: \"");
        try buffer.appendSlice(self.title);
        try buffer.appendSlice("\"\n");
        try buffer.appendSlice("version: \"");
        try buffer.appendSlice(self.version);
        try buffer.appendSlice("\"\n");
        try buffer.appendSlice("doi: ");
        try buffer.appendSlice(self.doi);
        try buffer.appendSlice("\n");
        try buffer.appendSlice("date-released: ");
        try buffer.appendSlice(self.date_released);
        try buffer.appendSlice("\n");

        return buffer.toOwnedSlice();
    }
};

test "v19 cff placeholder" {
    const cff = CffMetadata{
        .title = "Test Software",
        .version = "1.0.0",
        .doi = "10.5281/zenodo.1234567",
        .authors = &.{},
        .date_released = "2026-03-28",
    };
    const yaml = try cff.toYaml(std.testing.allocator);
    defer std.testing.allocator.free(yaml);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "cff-version") != null);
}
