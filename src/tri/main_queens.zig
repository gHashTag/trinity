// ═════════════════════════════════════════════════════════════════════════════════════
// L1: QUEENS (Supervisors)
// ═════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const doctor = @import("doctor/doctor_cli.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try doctor.runDoctorCommand(allocator, &.{});
        return;
    }

    // Route L1 commands
    const cmd = args[1];
    const cmd_args = args[2..];

    if (std.mem.eql(u8, cmd, "doctor")) {
        try doctor.runDoctorCommand(allocator, cmd_args);
    } else {
        std.debug.print("Unknown L1 command: {s}\n", .{cmd});
        std.debug.print("Available: doctor\n", .{});
    }
}
