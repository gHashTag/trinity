// Sacred Synthesis CLI Tool
// Synthesizes Verilog modules for XC7A100T FPGA
//
// Usage: tri sacred-synth [modules...]
//   Default: synthesizes all Sacred ALU modules
//   Options: gf16_add, gf16_mul, gf16_alu, tf3_add, tf3_dot, sacred_alu
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

const stdout = std.io.getStdOut();
const stderr = std.io.getStdErr();

// Module definitions
const Module = struct {
    name: []const u8,
    top: []const u8,
};

const MODULES = [_]Module{
    .{ .name = "gf16_add.v", .top = "gf16_add" },
    .{ .name = "gf16_mul.v", .top = "gf16_mul" },
    .{ .name = "gf16_alu.v", .top = "gf16_alu" },
    .{ .name = "tf3_add.v", .top = "tf3_add" },
    .{ .name = "tf3_dot.v", .top = "tf3_dot" },
    .{ .name = "sacred_alu.v", .top = "sacred_alu" },
};

// Colors
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const NC = "\x1b[0m";

pub fn main() !u8 {
    const gpa = std.heap.raw_c_allocator;

    // Parse command line arguments
    const args = try std.process.argsAlloc(gpa);
    defer gpa.deinit(args);

    if (args.len < 2) {
        // No modules specified, synthesize all
        try stdout.print("{s}════════════════════════════════════════════════════{s}\n", .{GREEN});
        try stdout.print("Sacred GF16/TF3-9 ALU Synthesis for XC7A100T\n");
        try stdout.print("{s}════════════════════════════════════════════════════{s}\n\n", .{GREEN});

        for (MODULES) |mod| {
            try synthesizeModule(mod);
        }
    } else {
        // Synthesize specific modules
        try stdout.print("{s}══════════════════════════════════════════════════{s}\n", .{GREEN});
        try stdout.print("Synthesizing selected modules\n");
        try stdout.print("{s}══════════════════════════════════════════════════{s}\n\n", .{GREEN});

        var found_any = false;
        for (args[1..]) |arg| {
            for (MODULES) |mod| {
                if (std.mem.eql(u8, arg, mod.name)) {
                    found_any = true;
                    try synthesizeModule(mod);
                }
            }
        }

        if (!found_any) {
            try stderr.print("{s}ERROR: No matching modules found{t}\n", .{RED});
            try stderr.print("Available modules:\n");
            for (MODULES) |mod| {
                try stderr.print("  {s}\n", .{mod.name});
            }
            return 1;
        }
    }

    return 0;
}

fn synthesizeModule(mod: Module) !void {
    try stdout.print("{s}─────────────────────────────────────{t}\n", .{GREEN});
    try stdout.print("Synthesizing: {s} - top: {s}\n", .{mod.name}, .{mod.top});
    try stdout.print("{s}─────────────────────────────────────{t}\n", .{GREEN});

    // Build yosys command
    const yosys_argv = &[_][]const u8{
        "yosys", "-p", mod.top, mod.name, "-o", "build/mod", ".json", "-g", "cells,ports,attributes"
    };

    // Execute yosys
    const result = try std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = yosys_argv,
    });

    if (result.term.Exited == 0) {
        try stdout.print("{s}✅ {s} synthesis complete{t}\n", .{GREEN, .{mod.name}});
    } else {
        try stdout.print("{s}❌ {s} synthesis failed (exit code {d}){t}\n", .{RED, .{mod.name}, result.term.Exited});
        return error.SynthesisFailed;
    }
}

const SynthesisError = error{
    SynthesisFailed,
};
