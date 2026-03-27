//! Zenodo V19: ORCID Integration
//! Placeholder for future implementation

const std = @import("std");

pub const OrcidAuthor = struct {
    given_name: []const u8,
    family_name: []const u8,
    orcid: []const u8, // "0000-0000-0000-0000"

    pub fn format(self: OrcidAuthor, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s} {s} (ORCID: {s})", .{
            self.given_name, self.family_name, self.orcid
        });
    }

    pub fn orcidUrl(self: OrcidAuthor, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "https://orcid.org/{s}", .{self.orcid});
    }
};

test "v19 orcid placeholder" {
    const author = OrcidAuthor{
        .given_name = "Jane",
        .family_name = "Doe",
        .orcid = "0000-0000-0000-0001",
    };
    const url = try author.orcidUrl(std.testing.allocator);
    defer std.testing.allocator.free(url);
    try std.testing.expectEqualStrings("https://orcid.org/0000-0000-0000-0001", url);
}
