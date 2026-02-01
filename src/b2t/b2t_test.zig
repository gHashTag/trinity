// B2T Test - End-to-end test for Binary-to-Ternary Converter
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const b2t_loader = @import("b2t_loader.zig");
const b2t_disasm = @import("b2t_disasm.zig");
const b2t_lifter = @import("b2t_lifter.zig");
const b2t_codegen = @import("b2t_codegen.zig");

// Minimal WASM module with add function
// (module
//   (func $add (param i32 i32) (result i32)
//     local.get 0
//     local.get 1
//     i32.add)
//   (export "add" (func $add)))
const TEST_WASM = [_]u8{
    // Magic number
    0x00, 0x61, 0x73, 0x6D,
    // Version
    0x01, 0x00, 0x00, 0x00,

    // Type section (1)
    0x01, // section id
    0x07, // section size
    0x01, // num types
    0x60, // func type
    0x02, // num params
    0x7F, // i32
    0x7F, // i32
    0x01, // num results
    0x7F, // i32

    // Function section (3)
    0x03, // section id
    0x02, // section size
    0x01, // num functions
    0x00, // type index 0

    // Export section (7)
    0x07, // section id
    0x07, // section size
    0x01, // num exports
    0x03, // name length
    'a', 'd', 'd', // name
    0x00, // export kind (func)
    0x00, // func index

    // Code section (10)
    0x0A, // section id
    0x09, // section size
    0x01, // num functions
    0x07, // func body size
    0x00, // num locals
    0x20, 0x00, // local.get 0
    0x20, 0x01, // local.get 1
    0x6A, // i32.add
    0x0B, // end
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     B2T End-to-End Test                                      ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // Step 1: Load WASM
    std.debug.print("Step 1: Loading WASM binary...\n", .{});
    var binary = try b2t_loader.loadFromMemory(allocator, &TEST_WASM);
    defer binary.deinit();

    std.debug.print("  ✅ Format: {s}\n", .{@tagName(binary.format)});
    std.debug.print("  ✅ Architecture: {s}\n", .{@tagName(binary.architecture)});
    std.debug.print("  ✅ Sections: {}\n", .{binary.sections.items.len});

    for (binary.sections.items) |section| {
        std.debug.print("     - {s} (size: {})\n", .{ section.name, section.virtual_size });
    }

    // Step 2: Disassemble
    std.debug.print("\nStep 2: Disassembling...\n", .{});
    var disasm = try b2t_disasm.disassemble(allocator, &binary);
    defer disasm.deinit();

    std.debug.print("  ✅ Functions: {}\n", .{disasm.functions.items.len});

    for (disasm.functions.items, 0..) |func, i| {
        std.debug.print("     Function {}: {} instructions\n", .{ i, func.instructions.items.len });
        for (func.instructions.items) |inst| {
            std.debug.print("       {s}", .{inst.mnemonic});
            if (inst.operand_count > 0) {
                std.debug.print(" {}", .{inst.operands[0].value});
            }
            std.debug.print("\n", .{});
        }
    }

    // Step 3: Lift to TVC IR
    std.debug.print("\nStep 3: Lifting to TVC IR...\n", .{});
    var lifter = b2t_lifter.Lifter.init(allocator);
    defer lifter.deinit();

    const module = try lifter.lift(&disasm);

    std.debug.print("  ✅ TVC Functions: {}\n", .{module.functions.items.len});

    for (module.functions.items, 0..) |func, i| {
        var inst_count: usize = 0;
        for (func.blocks.items) |block| {
            inst_count += block.instructions.items.len;
        }
        std.debug.print("     Function {}: {} TVC instructions\n", .{ i, inst_count });

        for (func.blocks.items) |block| {
            for (block.instructions.items) |inst| {
                std.debug.print("       {s}", .{@tagName(inst.opcode)});
                if (inst.dest) |d| {
                    std.debug.print(" v{}", .{d});
                }
                std.debug.print("\n", .{});
            }
        }
    }

    // Step 4: Generate ternary code
    std.debug.print("\nStep 4: Generating ternary code...\n", .{});
    var codegen = b2t_codegen.Codegen.init(allocator);
    defer codegen.deinit();

    const trit_code = try codegen.generate(module);

    std.debug.print("  ✅ Generated {} bytes of ternary code\n", .{trit_code.len});

    // Verify magic
    const trit_file = try b2t_codegen.TritFile.parse(trit_code);
    std.debug.print("  ✅ Magic: 0x{X} (TRIT)\n", .{trit_file.magic});
    std.debug.print("  ✅ Version: {}\n", .{trit_file.version});
    std.debug.print("  ✅ Functions: {}\n", .{trit_file.num_functions});

    // Disassemble generated code
    std.debug.print("\nGenerated Ternary Code:\n", .{});
    std.debug.print("─────────────────────────────────────────\n", .{});

    const disasm_output = try b2t_codegen.disassembleTrit(allocator, trit_file.code);
    defer allocator.free(disasm_output);
    std.debug.print("{s}", .{disasm_output});

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  ✅ B2T MVP TEST PASSED!                                     ║\n", .{});
    std.debug.print("║                                                              ║\n", .{});
    std.debug.print("║  WASM binary successfully converted to ternary code!         ║\n", .{});
    std.debug.print("║                                                              ║\n", .{});
    std.debug.print("║  φ² + 1/φ² = 3 = TRINITY                                     ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}

test "full pipeline" {
    const allocator = std.testing.allocator;

    // Load
    var binary = try b2t_loader.loadFromMemory(allocator, &TEST_WASM);
    defer binary.deinit();
    try std.testing.expectEqual(b2t_loader.BinaryFormat.wasm, binary.format);

    // Disassemble
    var disasm = try b2t_disasm.disassemble(allocator, &binary);
    defer disasm.deinit();
    try std.testing.expect(disasm.functions.items.len > 0);

    // Lift
    var lifter = b2t_lifter.Lifter.init(allocator);
    defer lifter.deinit();
    const module = try lifter.lift(&disasm);
    try std.testing.expect(module.functions.items.len > 0);

    // Generate
    var codegen = b2t_codegen.Codegen.init(allocator);
    defer codegen.deinit();
    const trit_code = try codegen.generate(module);
    try std.testing.expect(trit_code.len > 0);

    // Verify
    const trit_file = try b2t_codegen.TritFile.parse(trit_code);
    try std.testing.expectEqual(b2t_codegen.TRIT_MAGIC, trit_file.magic);
}
