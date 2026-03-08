//! QUANTUM BRIDGE RUNNER — Real-time CGLMP → FPGA
//!
//! Runs CGLMP quantum violation tests continuously and updates FPGA LED
//! via automatic bitstream switching.
//!
//! phi^2 + 1/phi^2 = 3 = TRINITY
//!
//! Usage: zig build quantum-bridge

const std = @import("std");
const qvm = @import("ternary_qvm.zig");
const print = std.debug.print;

// Use C nanosleep directly to avoid symbol shadowing issues
const c = @cImport({
    @cDefine("_POSIX_C_SOURCE", "199309L");
    @cInclude("time.h");
});

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Print banner
    print("\n", .{});
    print("╔═══════════════════════════════════════════════════════════════╗\n", .{});
    print("║     QUANTUM BRIDGE RUNNER — Real-time CGLMP → FPGA         ║\n", .{});
    print("║     φ² + 1/φ² = 3 = TRINITY                                 ║\n", .{});
    print("╚═══════════════════════════════════════════════════════════════╝\n", .{});
    print("\n", .{});

    // Bitstream paths (mapped from quantum states)
    const bitstreams = [_][]const u8{
        "separable",   // 00 -> I₃ < 1.0
        "violation",   // 01 -> 1.0 ≤ I₃ < 2.0
        "zero",        // 10 -> 2.0 ≤ I₃ < 2.5
        "negative",    // 11 -> I₃ ≥ 2.5
    };

    // Base path for bitstreams
    const base_path = "/Users/playra/trinity-w1/fpga/openxc7-synth/quantum_bridge_";

    var iteration: u32 = 0;
    var violation_count: u32 = 0;

    while (true) : (iteration += 1) {
        // Run CGLMP test (analytical, instant)
        const result = qvm.run_cglmp_test(0, true);

        // Map I3 value to quantum state index
        const state_idx: usize = if (result.i3_value < 1.0) 0 else
                                 if (result.i3_value < 2.0) 1 else
                                 if (result.i3_value < 2.5) 2 else 3;

        const state_name = bitstreams[state_idx];

        // Count violations
        if (result.violation) violation_count += 1;

        // Display result with color
        print("[{d:4}] ", .{iteration});

        if (result.violation) {
            print("\x1b[32mVIOLATION!\x1b[0m ", .{});
        } else {
            print("separable  ", .{});
        }

        print("I₃={d:.4} | State={s} ({})", .{
            result.i3_value,
            state_name,
            result.violation
        });

        if (state_idx == 1) { // violation mode
            print(" \x1b[33m⚡ FAST (~6 Hz)\x1b[0m", .{});
        } else if (state_idx == 3) { // negative
            print(" \x1b[31m■ STEADY ON\x1b[0m", .{});
        } else if (state_idx == 2) { // zero
            print(" ~ SLOW (~0.4 Hz)", .{});
        } else { // separable
            print(" ~ MEDIUM (~3 Hz)", .{});
        }

        print("\n", .{});

        // Flash appropriate bitstream
        const bitfile = try std.fmt.allocPrint(allocator,
            "{s}{s}.bit",
            .{ base_path, state_name }
        );

        try flashBitstream(bitfile);
        allocator.free(bitfile);

        // Statistics every 10 iterations
        if (iteration % 10 == 0) {
            const violation_rate = @as(f64, @floatFromInt(violation_count)) * 100.0 / @as(f64, @floatFromInt(iteration));
            print("       └─ Violations: {d}/{d} ({d:.1}%)\n", .{
                violation_count, iteration, violation_rate
            });
        }

        // Wait before next iteration
        // Use C nanosleep directly to avoid symbol shadowing issues
        var req = c.timespec{ .tv_sec = 1, .tv_nsec = 0 };
        _ = c.nanosleep(&req, null);
    }
}

fn flashBitstream(path: []const u8) !void {
    const allocator = std.heap.page_allocator;
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "sudo",
            "/Users/playra/trinity-w1/fpga/tools/jtag_program",
            path,
        },
    }) catch |err| {
        print("Failed to spawn jtag_process: {}\n", .{err});
        return error.FlashFailed;
    };

    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.term.Exited != 0) {
        if (result.stderr.len > 0) {
            print("Flash failed: {s}\n", .{result.stderr});
        }
        return error.FlashFailed;
    }
}
