//! JTAG Flasher — Pure Zig wrapper for FPGA bitstream programming
//! Simple wrapper until full libusb JTAG implementation (Phase 8.1)

const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse args
    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 2) {
        std.debug.print(
            \\Usage: jtag_flasher <bitstream.bit>\n
            \\Flash bitstream to FPGA via JTAG.\n
            \\
        , .{}
        );
        std.process.exit(1);
    }

    const bitstream = args[1];

    // Flash via jtag_program
    std.debug.print("═══════════════════════════════════════════════\n", .{});
    std.debug.print(" JTAG FLASHER — Pure Zig\n", .{});
    std.debug.print(" Bitstream: {s}\n", .{bitstream});
    std.debug.print("═══════════════════════════════════════════════\n\n", .{});

    // Check if jtag_program exists
    const jtag_prog = "/Users/playra/trinity-w1/fpga/tools/jtag_program";

    // Run fxload first (PID 0x0013 -> 0x0008)
    std.debug.print("[1/2] fxload: switching cable to JTAG mode...\n", .{});
    const fxload_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "/Users/playra/trinity-w1/fpga/tools/fxload",
            "-t", "xilinx",
            "-d", "03fd:0013",
            "-i", "/Users/playra/trinity-w1/fpga/tools/xusb_xp2.hex",
        },
    }).wait;

    if (fxload_result.term != .Exited) {
        std.debug.print("✗ fxload failed\n", .{});
        return error.FxloadFailed;
    }

    // Wait for cable to stabilize
    std.time.sleep(5 * std.time.ns_per_s);

    // Flash bitstream
    std.debug.print("[2/2] Flashing bitstream...\n", .{});
    const flash_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ jtag_prog, bitstream },
    }).wait;

    const success = (flash_result.term == .Exited) and (flash_result.exit_code == 0);

    std.debug.print("\n═══════════════════════════════════════════════\n", .{});
    if (success) {
        std.debug.print(" ✅ FLASH COMPLETE\n", .{});
        std.debug.print("═══════════════════════════════════════════════\n", .{});
    } else {
        std.debug.print(" ✗ FLASH FAILED (exit code {d})\n", .{flash_result.exit_code});
        std.debug.print("═══════════════════════════════════════════════\n", .{});
        return error.FlashFailed;
    }
}
