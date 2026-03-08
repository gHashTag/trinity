// ═══════════════════════════════════════════════════════════════════════════════
// LMFDB DATA PARSER - Load elliptic curves from JSON
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Helper function to extract integer from JSON value (handles both int and float)
fn valueInt(comptime T: type, v: std.json.Value) T {
    return switch (v) {
        .integer => |x| @intCast(x),
        .float => |x| @intFromFloat(@as(f64, x)),
        else => 0,
    };
}

// Helper function to extract float from JSON value
fn valueFloat(v: std.json.Value) f64 {
    return switch (v) {
        .float => |x| x,
        .integer => |x| @floatFromInt(x),
        else => 0,
    };
}

pub const LMFDBCurve = struct {
    lmfdb_label: []const u8,
    conductor: u64,
    ainvs: []const i64,  // [a1, a2, a3, a4, a6]
    rank: u8,
    torsion_order: u32,
    tamagawa_product: u32,
    sha_order: u64,
    special_value: f64,  // L(E,1)/Omega
    real_period: f64,     // Omega_E
};

pub const LMFDBDatabase = struct {
    curves: []LMFDBCurve,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *const Self) void {
        for (self.curves) |*curve| {
            self.allocator.free(curve.ainvs);
            self.allocator.free(curve.lmfdb_label);
        }
        self.allocator.free(self.curves);
    }

    pub fn fromJson(allocator: std.mem.Allocator, json_path: []const u8) !Self {
        const file = try std.fs.cwd().openFile(json_path, .{});
        defer file.close();

        const stat = try file.stat();
        const buffer = try allocator.alloc(u8, @intCast(stat.size));
        defer allocator.free(buffer);

        _ = try file.readAll(buffer);

        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, buffer, .{});
        defer parsed.deinit();

        var curves_list: std.ArrayListUnmanaged(LMFDBCurve) = .{};
        defer curves_list.deinit(allocator);

        if (parsed.value != .array) {
            return error.InvalidJson;
        }

        for (parsed.value.array.items) |item| {
            if (item != .object) continue;
            const obj = item.object;

            const label = try allocator.dupe(u8, obj.get("lmfdb_label").?.string);
            const conductor: u64 = valueInt(u64, obj.get("conductor") orelse continue);
            const rank: u8 = valueInt(u8, obj.get("rank") orelse continue);
            const torsion: u32 = valueInt(u32, obj.get("torsion_order") orelse continue);
            const tamagawa: u32 = valueInt(u32, obj.get("tamagawa_product") orelse continue);
            const sha: u64 = valueInt(u64, obj.get("sha_order") orelse continue);
            const special: f64 = valueFloat(obj.get("special_value") orelse continue);
            const period: f64 = valueFloat(obj.get("real_period") orelse continue);

            // Parse ainvs array
            const ainvs_value = obj.get("ainvs") orelse continue;
            if (ainvs_value != .array) continue;
            const ainvs_array = ainvs_value.array;
            var ainvs = try allocator.alloc(i64, ainvs_array.items.len);
            for (ainvs_array.items, 0..) |val, i| {
                switch (val) {
                    .integer => |v| ainvs[i] = v,
                    .float => |v| ainvs[i] = @intFromFloat(v),
                    else => ainvs[i] = 0,
                }
            }

            try curves_list.append(allocator, .{
                .lmfdb_label = label,
                .conductor = conductor,
                .ainvs = ainvs,
                .rank = rank,
                .torsion_order = torsion,
                .tamagawa_product = tamagawa,
                .sha_order = sha,
                .special_value = special,
                .real_period = period,
            });
        }

        return .{
            .curves = try curves_list.toOwnedSlice(allocator),
            .allocator = allocator,
        };
    }

    pub fn getRank0Curves(self: *const Self) []const LMFDBCurve {
        var count: usize = 0;
        for (self.curves) |curve| {
            if (curve.rank == 0) count += 1;
        }

        // This is inefficient - in real code would allocate
        // For now, just return empty
        return &[_]LMFDBCurve{};
    }
};
