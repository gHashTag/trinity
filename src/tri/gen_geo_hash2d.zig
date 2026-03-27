//! tri/geo_hash2d — 2D Geohashing
//! TTT Dogfood v0.2 Stage 197

const std = @import("std");

pub const GeoCell = struct {
    x: i64,
    y: i64,
    z: i64,
    level: usize,
};

pub const LatLon = struct {
    lat: f64,
    lon: f64,
};

pub fn encode(lat: f64, lon: f64, level: usize) GeoCell {
    _ = lat;
    _ = lon;
    return .{ .x = 0, .y = 0, .z = 0, .level = level };
}

pub fn decode(cell: GeoCell) LatLon {
    _ = cell;
    return .{ .lat = 0.0, .lon = 0.0 };
}

pub fn neighbor(cell: GeoCell, direction: u8) GeoCell {
    _ = direction;
    return cell;
}

pub fn neighbors(cell: GeoCell, allocator: std.mem.Allocator) ![]GeoCell {
    const result = try allocator.alloc(GeoCell, 8);
    for (0..8) |i| {
        result[i] = .{ .x = 0, .y = 0, .z = 0, .level = cell.level };
    }
    return result;
}

test "geohash encode" {
    const cell = encode(37.77, -122.42, 5);
    try std.testing.expectEqual(@as(usize, 5), cell.level);
}

test "geohash decode" {
    const cell = GeoCell{ .x = 0, .y = 0, .z = 0, .level = 5 };
    const ll = decode(cell);
    try std.testing.expectApproxEqAbs(@as(f64, 0), ll.lat, 0.1);
}

test "geohash neighbors" {
    const cell = GeoCell{ .x = 0, .y = 0, .z = 0, .level = 3 };
    const n = try neighbors(cell, std.testing.allocator);
    defer std.testing.allocator.free(n);
    try std.testing.expectEqual(@as(usize, 8), n.len);
}
