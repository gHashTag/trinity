// B2T CLI - Binary-to-Ternary Converter
// Command line interface for converting binaries to ternary code
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const b2t_loader = @import("b2t_loader.zig");
const b2t_disasm = @import("b2t_disasm.zig");
const b2t_lifter = @import("b2t_lifter.zig");
const b2t_codegen = @import("b2t_codegen.zig");

const VERSION = "0.1.0";

const BANNER =
    \\
    \\  ╔══════════════════════════════════════════════════════════════╗
    \\  ║     B2T - Binary-to-Ternary Converter v{s}                  ║
    \\  ║     φ² + 1/φ² = 3 = TRINITY                                  ║
    \\  ╚══════════════════════════════════════════════════════════════╝
    \\
;

const HELP =
    \\Usage: b2t <command> [options] <input>
    \\
    \\Commands:
    \\  convert    Convert binary to ternary (.trit)
    \\  disasm     Disassemble binary
    \\  info       Show binary information
    \\  run        Run ternary code (coming soon)
    \\
    \\Options:
    \\  -o, --output <file>    Output file path
    \\  -v, --verbose          Verbose output
    \\  -h, --help             Show this help
    \\  --version              Show version
    \\
    \\Examples:
    \\  b2t convert program.wasm -o program.trit
    \\  b2t disasm program.wasm
    \\  b2t info program.exe
    \\
    \\Supported formats:
    \\  .wasm    WebAssembly (MVP)
    \\  .elf     Linux ELF64 (Phase 2)
    \\  .exe     Windows PE64 (Phase 2)
    \\
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printBanner();
        std.debug.print("{s}\n", .{HELP});
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "-h") or std.mem.eql(u8, command, "--help")) {
        printBanner();
        std.debug.print("{s}\n", .{HELP});
        return;
    }

    if (std.mem.eql(u8, command, "--version")) {
        std.debug.print("b2t version {s}\n", .{VERSION});
        return;
    }

    if (std.mem.eql(u8, command, "convert")) {
        try cmdConvert(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "disasm")) {
        try cmdDisasm(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "info")) {
        try cmdInfo(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "run")) {
        std.debug.print("Run command coming soon!\n", .{});
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        std.debug.print("{s}\n", .{HELP});
    }
}

fn printBanner() void {
    std.debug.print(BANNER, .{VERSION});
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERT COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdConvert(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var input_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    var verbose = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            i += 1;
            if (i < args.len) {
                output_path = args[i];
            }
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else if (arg[0] != '-') {
            input_path = arg;
        }
    }

    if (input_path == null) {
        std.debug.print("Error: No input file specified\n", .{});
        return;
    }

    const input = input_path.?;
    const output = output_path orelse blk: {
        // Generate output path by replacing extension with .trit
        const dot_pos = std.mem.lastIndexOf(u8, input, ".") orelse input.len;
        const base = input[0..dot_pos];
        const out = try std.fmt.allocPrint(allocator, "{s}.trit", .{base});
        break :blk out;
    };

    std.debug.print("Converting: {s} -> {s}\n", .{ input, output });

    // Step 1: Load binary
    if (verbose) std.debug.print("  [1/4] Loading binary...\n", .{});
    var binary = b2t_loader.load(allocator, input) catch |err| {
        std.debug.print("Error loading binary: {}\n", .{err});
        return;
    };
    defer binary.deinit();

    std.debug.print("  Format: {s}\n", .{@tagName(binary.format)});
    std.debug.print("  Architecture: {s}\n", .{@tagName(binary.architecture)});
    std.debug.print("  Sections: {}\n", .{binary.sections.items.len});

    // Step 2: Disassemble
    if (verbose) std.debug.print("  [2/4] Disassembling...\n", .{});
    var disasm = b2t_disasm.disassemble(allocator, &binary) catch |err| {
        std.debug.print("Error disassembling: {}\n", .{err});
        return;
    };
    defer disasm.deinit();

    std.debug.print("  Functions: {}\n", .{disasm.functions.items.len});

    var total_instructions: usize = 0;
    for (disasm.functions.items) |func| {
        total_instructions += func.instructions.items.len;
    }
    std.debug.print("  Instructions: {}\n", .{total_instructions});

    // Step 3: Lift to TVC IR
    if (verbose) std.debug.print("  [3/4] Lifting to TVC IR...\n", .{});
    var lifter = b2t_lifter.Lifter.init(allocator);
    defer lifter.deinit();

    const module = lifter.lift(&disasm) catch |err| {
        std.debug.print("Error lifting: {}\n", .{err});
        return;
    };

    var total_tvc_instructions: usize = 0;
    for (module.functions.items) |func| {
        for (func.blocks.items) |block| {
            total_tvc_instructions += block.instructions.items.len;
        }
    }
    std.debug.print("  TVC Instructions: {}\n", .{total_tvc_instructions});

    // Step 4: Generate ternary code
    if (verbose) std.debug.print("  [4/4] Generating ternary code...\n", .{});
    var codegen = b2t_codegen.Codegen.init(allocator);
    defer codegen.deinit();

    const trit_code = codegen.generate(module) catch |err| {
        std.debug.print("Error generating code: {}\n", .{err});
        return;
    };

    // Write output
    const file = std.fs.cwd().createFile(output, .{}) catch |err| {
        std.debug.print("Error creating output file: {}\n", .{err});
        return;
    };
    defer file.close();

    file.writeAll(trit_code) catch |err| {
        std.debug.print("Error writing output: {}\n", .{err});
        return;
    };

    std.debug.print("\n✅ Conversion complete!\n", .{});
    std.debug.print("  Output: {s}\n", .{output});
    std.debug.print("  Size: {} bytes\n", .{trit_code.len});
    std.debug.print("\n  φ² + 1/φ² = 3 = TRINITY\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISASM COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdDisasm(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Error: No input file specified\n", .{});
        return;
    }

    const input = args[0];

    // Check if it's a .trit file
    if (std.mem.endsWith(u8, input, ".trit")) {
        try disasmTrit(allocator, input);
        return;
    }

    // Load and disassemble binary
    var binary = b2t_loader.load(allocator, input) catch |err| {
        std.debug.print("Error loading binary: {}\n", .{err});
        return;
    };
    defer binary.deinit();

    var disasm = b2t_disasm.disassemble(allocator, &binary) catch |err| {
        std.debug.print("Error disassembling: {}\n", .{err});
        return;
    };
    defer disasm.deinit();

    std.debug.print("\nDisassembly of {s}\n", .{input});
    std.debug.print("Format: {s}, Architecture: {s}\n\n", .{ @tagName(binary.format), @tagName(binary.architecture) });

    for (disasm.functions.items, 0..) |func, func_idx| {
        std.debug.print("Function {}:\n", .{func_idx});

        for (func.instructions.items) |inst| {
            std.debug.print("  {x:08}: {s}", .{ inst.address, inst.mnemonic });

            var op_idx: u8 = 0;
            while (op_idx < inst.operand_count) : (op_idx += 1) {
                const op = inst.operands[op_idx];
                switch (op.op_type) {
                    .immediate => std.debug.print(" {}", .{op.value}),
                    .local => std.debug.print(" local.{}", .{op.value}),
                    .global => std.debug.print(" global.{}", .{op.value}),
                    .func_idx => std.debug.print(" func.{}", .{op.value}),
                    .label => std.debug.print(" label.{}", .{op.value}),
                    else => std.debug.print(" ?{}", .{op.value}),
                }
            }

            std.debug.print("\n", .{});
        }

        std.debug.print("\n", .{});
    }
}

fn disasmTrit(allocator: std.mem.Allocator, path: []const u8) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("Error opening file: {}\n", .{err});
        return;
    };
    defer file.close();

    const stat = try file.stat();
    const data = try allocator.alloc(u8, stat.size);
    defer allocator.free(data);

    _ = try file.readAll(data);

    const trit_file = b2t_codegen.TritFile.parse(data) catch |err| {
        std.debug.print("Error parsing .trit file: {}\n", .{err});
        return;
    };

    std.debug.print("\nTRIT File: {s}\n", .{path});
    std.debug.print("Version: {}\n", .{trit_file.version});
    std.debug.print("Entry Point: {}\n", .{trit_file.entry_point});
    std.debug.print("Functions: {}\n", .{trit_file.num_functions});
    std.debug.print("Globals: {}\n\n", .{trit_file.num_globals});

    const disasm_output = b2t_codegen.disassembleTrit(allocator, trit_file.code) catch |err| {
        std.debug.print("Error disassembling: {}\n", .{err});
        return;
    };
    defer allocator.free(disasm_output);

    std.debug.print("Code:\n{s}\n", .{disasm_output});
}

// ═══════════════════════════════════════════════════════════════════════════════
// INFO COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdInfo(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Error: No input file specified\n", .{});
        return;
    }

    const input = args[0];

    var binary = b2t_loader.load(allocator, input) catch |err| {
        std.debug.print("Error loading binary: {}\n", .{err});
        return;
    };
    defer binary.deinit();

    std.debug.print("\nBinary Information: {s}\n", .{input});
    std.debug.print("═══════════════════════════════════════════════════════\n", .{});
    std.debug.print("Format:       {s}\n", .{@tagName(binary.format)});
    std.debug.print("Architecture: {s}\n", .{@tagName(binary.architecture)});
    std.debug.print("Entry Point:  0x{x}\n", .{binary.entry_point});
    std.debug.print("Sections:     {}\n", .{binary.sections.items.len});
    std.debug.print("\nSections:\n", .{});

    for (binary.sections.items) |section| {
        std.debug.print("  {s:16} addr=0x{x:08} size={:8} ", .{
            section.name,
            section.virtual_address,
            section.virtual_size,
        });

        if (section.is_executable) std.debug.print("EXEC ", .{});
        if (section.is_writable) std.debug.print("WRITE ", .{});
        std.debug.print("\n", .{});
    }

    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "cli help" {
    // Just verify it compiles
    printBanner();
}
