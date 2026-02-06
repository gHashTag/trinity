// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE GEN - Minimal Code Generator (Zig 0.15 compatible)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Generates Zig/Verilog code from .vibee specifications
// Single source of truth: .vibee specs -> generated code
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vibee_parser = @import("vibee_parser.zig");
const zig_codegen = @import("zig_codegen.zig");
const verilog_codegen = @import("verilog_codegen.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "gen")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing input file\n", .{});
            printUsage();
            return;
        }

        const input_path = args[2];
        const language = detectLanguage(allocator, input_path) catch "zig";

        var derived_path: ?[]const u8 = null;
        defer if (derived_path) |p| allocator.free(p);

        const output_path = if (args.len > 3) args[3] else blk: {
            derived_path = deriveOutputPath(allocator, input_path, language) catch {
                std.debug.print("Error: Could not derive output path\n", .{});
                return;
            };
            break :blk derived_path.?;
        };

        try generateCode(allocator, input_path, output_path);
    } else if (std.mem.eql(u8, command, "koschei")) {
        printKoscheiCycle();
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print(
        \\
        \\╔══════════════════════════════════════════════════════════════╗
        \\║           VIBEE GEN - Code Generator                         ║
        \\║           Single Source of Truth: .vibee -> Code             ║
        \\╚══════════════════════════════════════════════════════════════╝
        \\
        \\Usage:
        \\  vibee_gen gen <spec.vibee> [output]   Generate code from spec
        \\  vibee_gen koschei                      Show 16-step cycle
        \\  vibee_gen help                         Show this help
        \\
        \\Examples:
        \\  vibee_gen gen specs/tri/trinity_cli.vibee
        \\  vibee_gen gen specs/tri/agent.vibee trinity/output/agent.zig
        \\
        \\Supported languages in .vibee:
        \\  language: zig       -> Generates .zig file
        \\  language: varlog    -> Generates .v (Verilog) file
        \\  language: python    -> Generates .py file (planned)
        \\
        \\φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
        \\
    , .{});
}

fn printKoscheiCycle() void {
    std.debug.print(
        \\
        \\╔══════════════════════════════════════════════════════════════╗
        \\║           KOSCHEI 16-STEP DEVELOPMENT CYCLE                  ║
        \\║           Mandatory Process for All Changes                  ║
        \\╚══════════════════════════════════════════════════════════════╝
        \\
        \\SPECIFICATION (Steps 1-4):
        \\  1. Create .vibee specification (SINGLE SOURCE OF TRUTH)
        \\  2. Define types (data structures)
        \\  3. Define behaviors (functions)
        \\  4. Add algorithms if needed
        \\
        \\GENERATION (Steps 5-8):
        \\  5. Run: vibee_gen gen <spec.vibee>
        \\  6. Review generated code
        \\  7. Run tests: zig build test
        \\  8. Fix any issues in SPEC (not generated code!)
        \\
        \\VALIDATION (Steps 9-12):
        \\  9. Run benchmarks
        \\  10. Write critical assessment (honest self-criticism)
        \\  11. Document achievements
        \\  12. Update technology tree
        \\
        \\DEPLOYMENT (Steps 13-16):
        \\  13. Git add & commit
        \\  14. Push to remote
        \\  15. Propose 3 tech tree options for next iteration
        \\  16. Loop back to step 1
        \\
        \\RULES:
        \\  - NEVER edit generated code directly
        \\  - ALL changes go through .vibee specs
        \\  - One source of truth = no duplication
        \\
        \\φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
        \\
    , .{});
}

fn detectLanguage(allocator: std.mem.Allocator, input_path: []const u8) ![]const u8 {
    // Read first part of file to detect language field
    const file = try std.fs.cwd().openFile(input_path, .{});
    defer file.close();

    var buf: [4096]u8 = undefined;
    const bytes_read = try file.read(&buf);
    const content = buf[0..bytes_read];

    // Look for "language:" field
    if (std.mem.indexOf(u8, content, "language:")) |idx| {
        var end_idx = idx + 9;
        // Skip whitespace
        while (end_idx < content.len and (content[end_idx] == ' ' or content[end_idx] == '\t' or content[end_idx] == '"')) {
            end_idx += 1;
        }
        const start = end_idx;
        // Find end of value
        while (end_idx < content.len and content[end_idx] != '\n' and content[end_idx] != '"' and content[end_idx] != ' ') {
            end_idx += 1;
        }
        if (end_idx > start) {
            return try allocator.dupe(u8, content[start..end_idx]);
        }
    }

    return "zig"; // Default
}

fn deriveOutputPath(allocator: std.mem.Allocator, input_path: []const u8, language: []const u8) ![]const u8 {
    // Get base name without extension
    const base = std.fs.path.basename(input_path);
    const name_end = std.mem.lastIndexOf(u8, base, ".") orelse base.len;
    const name = base[0..name_end];

    // Determine extension based on language
    const ext = if (std.mem.eql(u8, language, "varlog") or std.mem.eql(u8, language, "verilog"))
        ".v"
    else if (std.mem.eql(u8, language, "python"))
        ".py"
    else
        ".zig";

    // Build output path: trinity/output/<name><ext>
    return try std.fmt.allocPrint(allocator, "trinity/output/{s}{s}", .{ name, ext });
}

fn generateCode(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8) !void {
    std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  VIBEE CODE GENERATION                                       ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("Input:  {s}\n", .{input_path});
    std.debug.print("Output: {s}\n\n", .{output_path});

    // Read source file
    const file = std.fs.cwd().openFile(input_path, .{}) catch |err| {
        std.debug.print("Error opening file: {}\n", .{err});
        return;
    };
    defer file.close();

    const stat = file.stat() catch |err| {
        std.debug.print("Error getting file size: {}\n", .{err});
        return;
    };

    const source = allocator.alloc(u8, stat.size) catch |err| {
        std.debug.print("Error allocating memory: {}\n", .{err});
        return;
    };
    defer allocator.free(source);

    _ = file.readAll(source) catch |err| {
        std.debug.print("Error reading file: {}\n", .{err});
        return;
    };

    // Parse specification
    std.debug.print("Parsing specification...\n", .{});
    var parser = vibee_parser.VibeeParser.init(allocator, source);

    var spec = parser.parse() catch |err| {
        std.debug.print("Error parsing spec: {}\n", .{err});
        return;
    };
    defer spec.deinit();

    std.debug.print("  Name: {s}\n", .{spec.name});
    std.debug.print("  Version: {s}\n", .{spec.version});
    std.debug.print("  Language: {s}\n", .{spec.language});
    std.debug.print("  Types: {d}\n", .{spec.types.items.len});
    std.debug.print("  Behaviors: {d}\n", .{spec.behaviors.items.len});

    // Ensure output directory exists
    const dir_path = std.fs.path.dirname(output_path) orelse ".";
    std.fs.cwd().makePath(dir_path) catch {};

    // Generate code based on language
    var generated_code: []const u8 = undefined;

    if (std.mem.eql(u8, spec.language, "varlog") or std.mem.eql(u8, spec.language, "verilog")) {
        std.debug.print("\nGenerating Verilog...\n", .{});
        var codegen = verilog_codegen.VerilogCodeGen.init(allocator);
        defer codegen.deinit();
        generated_code = try codegen.generate(&spec);
    } else {
        std.debug.print("\nGenerating Zig...\n", .{});
        var codegen = zig_codegen.ZigCodeGen.init(allocator);
        defer codegen.deinit();
        generated_code = try codegen.generate(&spec);
    }

    // Write to output file
    const output_file = std.fs.cwd().createFile(output_path, .{}) catch |err| {
        std.debug.print("Error creating output file: {}\n", .{err});
        return;
    };
    defer output_file.close();

    output_file.writeAll(generated_code) catch |err| {
        std.debug.print("Error writing output: {}\n", .{err});
        return;
    };

    std.debug.print("\n✓ Code generated successfully!\n", .{});
    std.debug.print("  Output: {s}\n", .{output_path});
    std.debug.print("\nφ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL\n\n", .{});
}
