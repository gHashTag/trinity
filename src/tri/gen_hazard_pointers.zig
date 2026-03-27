//! tri/hazard_pointers — Hazard pointers for lock-free reclamation
//! TTT Dogfood v0.2 Stage 229

const std = @import("std");

const MAX_HAZARDS = 10;

pub const HazardPointer = struct {
    pointer: ?*anyopaque,
    active: bool,
};

pub const HazardRegistry = struct {
    hazards: std.ArrayList(HazardPointer),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !HazardRegistry {
        var hazards = try std.ArrayList(HazardPointer).initCapacity(allocator, MAX_HAZARDS);
        for (0..MAX_HAZARDS) |_| {
            try hazards.append(allocator, .{ .pointer = null, .active = false });
        }
        return .{
            .hazards = hazards,
            .allocator = allocator,
        };
    }

    pub fn acquire(registry: *HazardRegistry) ?*HazardPointer {
        for (registry.hazards.items) |*h| {
            if (!h.active) {
                h.active = true;
                return h;
            }
        }
        return null;
    }

    pub fn release(hazard: *HazardPointer) void {
        hazard.pointer = null;
        hazard.active = false;
    }

    pub fn deinit(registry: *HazardRegistry) void {
        registry.hazards.deinit(registry.allocator);
    }
};

test "hazard pointer acquire release" {
    var registry = try HazardRegistry.init(std.testing.allocator);
    defer registry.deinit();
    const hazard = registry.acquire();
    try std.testing.expect(hazard != null);
    if (hazard) |h| {
        h.release();
    }
}
