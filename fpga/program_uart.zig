#!/usr/bin/env zig run

//! FPGA Programming Utility — Programs uart_bridge_fixed.bit to FPGA
//! Requires FT232RL JTAG cable and sudo access

const std = @import("std");

const BITSTREAM_PATH = "fpga/openxc7-synth/uart_bridge_fixed.bit";
const PROGRAMMER = "sudo ./tools/jtag_program";

pub fn main() !void {
    const stdout = std.io.getStdErr();
    const stdin = std.io.getStdIn();

    try stdout.writeAll(
        \\╔══════════════════════════════════════════╗
        \\║           Trinity FPGA Programmer v1.0                  ║
        \\║    Auto-flash uart_bridge_fixed.bit                 ║
        \\╚══════════════════════════════════════════════╝
        \\
    ) catch |err| {
        stdout.print("[✗] Error: {s}\n", .{err});
        std.process.exit(1);
    };

    // Check if bitstream exists
    const bitstream = std.fs.cwd() orelse ".";
    if (!std.fs.pathExists(bitstream, bitstream)) {
        stdout.print("[!] Bitstream not found: {s}\n", .{bitstream});
        stdout.print("[*] Ensure uart_bridge_fixed.bit exists in fpga/openxc7-synth/\n");
        std.process.exit(1);
    }

    stdout.print("[+] Bitstream found: {s}\n", .{bitstream}) catch {};
    stdout.print("\n[*] Programming FPGA...\n", .{}) catch {};

    // Run jtag_program
    const result = std.process.Child.exec(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{ PROGRAMMER, BITSTREAM_PATH },
    });

    const term = result.spawn() orelse null;
    defer term.deinit();

    const status = term.wait() catch |err| {
        stdout.print("[✗] Programming failed: {s}\n", .{err}) catch {};
        std.process.exit(1);
    };

    if (status != .Exited) {
        stdout.print("[!] Program exited unexpectedly\n", .{}) catch {};
        std.process.exit(1);
    }

    if (status.Exited != 0) {
        stdout.print("[!] Programming failed with exit code: {d}\n", .{status.Exited}) catch {};
        std.process.exit(1);
    }

    stdout.print("\n", .{}) catch {};
    stdout.print("╔════════════════════════════════════════╗", .{}) catch {};
    stdout.print("║  SUCCESS                                        ║", .{}) catch {};
    stdout.print("║  FPGA should be running uart_bridge_fixed.bit          ║", .{}) catch {};
    stdout.print("║  LED should be blinking during UART activity        ║", .{}) catch {};
    stdout.print("╚══════════════════════════════════════════════╝", .{}) catch {};
    stdout.print("\n[*] Test with uart_echo_test:\n", .{}) catch {};
    stdout.print("    zig build src/tools/uart_echo_test.zig\n", .{}) catch {};
    stdout.print("    ./zig-out/bin/uart-echo-test\n", .{}) catch {};
}
