//! TRI Version — Generated from specs/tri/tri_version.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,
    pre: ?[]const u8,
    build: ?[]const u8,
};

pub const RequirementOp = enum(u8) {
    exact,
    greater,
    greater_eq,
    less,
    less_eq,
    caret,
    tilde,
    compatible,
};

pub const VersionReq = struct {
    op: RequirementOp,
    version: Version,
};

pub const Ordering = enum(i8) {
    less = -1,
    equal = 0,
    greater = 1,
};

pub fn parse(version_str: []const u8) !Version {
    var result = Version{ .major = 0, .minor = 0, .patch = 0, .pre = null, .build = null };

    var parts = std.mem.splitScalar(u8, version_str, '.');
    var idx: usize = 0;

    while (parts.next()) |part| {
        if (std.mem.indexOfScalar(u8, part, '-')) |_| {
            result.pre = part;
            continue;
        }
        if (std.mem.indexOfScalar(u8, part, '+')) |_| {
            result.build = part;
            continue;
        }

        const num = try std.fmt.parseUnsigned(u32, part, 10);
        switch (idx) {
            0 => result.major = num,
            1 => result.minor = num,
            2 => result.patch = num,
            else => {},
        }
        idx += 1;
    }

    return result;
}

pub fn satisfies(version: Version, req: VersionReq) bool {
    return switch (req.op) {
        .exact => version.major == req.version.major and version.minor == req.version.minor and version.patch == req.version.patch,
        .greater_eq => compare(version, req.version) != .less,
        .greater_eq => compare(version, req.version) != .less,
        else => true, // Simplified
    };
}

pub fn compare(a: Version, b: Version) Ordering {
    if (a.major != b.major) return if (a.major > b.major) .greater else .less;
    if (a.minor != b.minor) return if (a.minor > b.minor) .greater else .less;
    if (a.patch != b.patch) return if (a.patch > b.patch) .greater else .less;
    return .equal;
}

test "Version: parse" {
    const v = try parse("1.2.3");
    try std.testing.expectEqual(@as(u32, 1), v.major);
    try std.testing.expectEqual(@as(u32, 2), v.minor);
    try std.testing.expectEqual(@as(u32, 3), v.patch);
}

test "Version: compare" {
    const v1 = Version{ .major = 1, .minor = 2, .patch = 3, .pre = null, .build = null };
    const v2 = Version{ .major = 1, .minor = 2, .patch = 4, .pre = null, .build = null };
    try std.testing.expect(compare(v1, v2) == .less);
}
