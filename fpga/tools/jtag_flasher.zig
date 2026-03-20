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

    std.debug.print("═══════════════════════════════════════════\n", .{});
    std.debug.print(" JTAG FLASHER — Pure Zig\n", .{});
    std.debug.print(" Bitstream: {s}\n", .{bitstream});
    std.debug.print("═════════════════════════════════════════════\n\n", .{});

    // Run fxload first (PID 0x0013 -> 0x0008)
    std.debug.print("[1/2] fxload: switching cable to JTAG mode...\n", .{});

    var fxload_child = std.process.Child.init(
        &[_][]const u8{
            "/Users/playra/trinity-w1/fpga/tools/fxload",
            "-t", "fx2",
            "-d", "03fd:0013",
            "-i", "/Users/playra/trinity-w1/fpga/tools/xusb_xp2.hex",
        },
        allocator,
    );

    const fxload_term = try fxload_child.spawnAndWait();

    const fxload_ok = switch (fxload_term) {
        .Exited => |code| code == 0,
        else => false,
    };

    if (!fxload_ok) {
        std.debug.print("✗ fxload failed\n", .{});
        return error.FxloadFailed;
    }

    // Wait for cable to stabilize
    std.Thread.sleep(5 * std.time.ns_per_s);

    // Flash bitstream
    std.debug.print("[2/2] Flashing bitstream...\n", .{});

    var flash_child = std.process.Child.init(
        &[_][]const u8{ "/Users/playra/trinity-w1/fpga/tools/jtag_program", bitstream },
        allocator,
    );

    const flash_term = try flash_child.spawnAndWait();

    const flash_ok = switch (flash_term) {
        .Exited => |code| code == 0,
        else => false,
    };

    std.debug.print("\n═════════════════════════════════════════\n", .{});
    if (flash_ok) {
        std.debug.print(" ✅ FLASH COMPLETE\n", .{});
        std.debug.print("═════════════════════════════════════════════\n", .{});
    } else {
        const exit_code = switch (flash_term) {
            .Exited => |code| code,
            else => 255,
        };
        std.debug.print(" ✗ FLASH FAILED (exit code {d})\n", .{exit_code});
        std.debug.print("═════════════════════════════════════════════\n", .{});
        return error.FlashFailed;
    }
}
