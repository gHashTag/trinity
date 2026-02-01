// B2T Test - End-to-end test for Binary-to-Ternary Converter
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const b2t_loader = @import("b2t_loader.zig");
const b2t_disasm = @import("b2t_disasm.zig");
const b2t_lifter = @import("b2t_lifter.zig");
const b2t_codegen = @import("b2t_codegen.zig");
const b2t_vm = @import("b2t_vm.zig");
const b2t_optimizer = @import("b2t_optimizer.zig");

// WASM module: add(i32, i32) -> i32
const TEST_WASM_ADD = [_]u8{
    0x00, 0x61, 0x73, 0x6D, // magic
    0x01, 0x00, 0x00, 0x00, // version
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7F, 0x7F, 0x01, 0x7F, // type section
    0x03, 0x02, 0x01, 0x00, // function section
    0x07, 0x07, 0x01, 0x03, 'a', 'd', 'd', 0x00, 0x00, // export section
    0x0A, 0x09, 0x01, 0x07, 0x00, // code section header
    0x20, 0x00, // local.get 0
    0x20, 0x01, // local.get 1
    0x6A, // i32.add
    0x0B, // end
};

// WASM module: sub(i32, i32) -> i32
const TEST_WASM_SUB = [_]u8{
    0x00, 0x61, 0x73, 0x6D, // magic
    0x01, 0x00, 0x00, 0x00, // version
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7F, 0x7F, 0x01, 0x7F, // type section
    0x03, 0x02, 0x01, 0x00, // function section
    0x07, 0x07, 0x01, 0x03, 's', 'u', 'b', 0x00, 0x00, // export section
    0x0A, 0x09, 0x01, 0x07, 0x00, // code section header
    0x20, 0x00, // local.get 0
    0x20, 0x01, // local.get 1
    0x6B, // i32.sub
    0x0B, // end
};

// WASM module: mul(i32, i32) -> i32
const TEST_WASM_MUL = [_]u8{
    0x00, 0x61, 0x73, 0x6D, // magic
    0x01, 0x00, 0x00, 0x00, // version
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7F, 0x7F, 0x01, 0x7F, // type section
    0x03, 0x02, 0x01, 0x00, // function section
    0x07, 0x07, 0x01, 0x03, 'm', 'u', 'l', 0x00, 0x00, // export section
    0x0A, 0x09, 0x01, 0x07, 0x00, // code section header
    0x20, 0x00, // local.get 0
    0x20, 0x01, // local.get 1
    0x6C, // i32.mul
    0x0B, // end
};

// WASM module: div(i32, i32) -> i32
const TEST_WASM_DIV = [_]u8{
    0x00, 0x61, 0x73, 0x6D, // magic
    0x01, 0x00, 0x00, 0x00, // version
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7F, 0x7F, 0x01, 0x7F, // type section
    0x03, 0x02, 0x01, 0x00, // function section
    0x07, 0x07, 0x01, 0x03, 'd', 'i', 'v', 0x00, 0x00, // export section
    0x0A, 0x09, 0x01, 0x07, 0x00, // code section header
    0x20, 0x00, // local.get 0
    0x20, 0x01, // local.get 1
    0x6D, // i32.div_s
    0x0B, // end
};

// WASM module: max(i32, i32) -> i32 using comparison and select
// (func $max (param i32 i32) (result i32)
//   local.get 0
//   local.get 1
//   local.get 0
//   local.get 1
//   i32.gt_s
//   select)
const TEST_WASM_MAX = [_]u8{
    0x00, 0x61, 0x73, 0x6D, // magic
    0x01, 0x00, 0x00, 0x00, // version
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7F, 0x7F, 0x01, 0x7F, // type section
    0x03, 0x02, 0x01, 0x00, // function section
    0x07, 0x07, 0x01, 0x03, 'm', 'a', 'x', 0x00, 0x00, // export section
    0x0A, 0x0D, 0x01, 0x0B, 0x00, // code section header
    0x20, 0x00, // local.get 0
    0x20, 0x01, // local.get 1
    0x20, 0x00, // local.get 0
    0x20, 0x01, // local.get 1
    0x4A, // i32.gt_s
    0x1B, // select
    0x0B, // end
};

// WASM module: min(i32, i32) -> i32 using comparison and select
const TEST_WASM_MIN = [_]u8{
    0x00, 0x61, 0x73, 0x6D, // magic
    0x01, 0x00, 0x00, 0x00, // version
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7F, 0x7F, 0x01, 0x7F, // type section
    0x03, 0x02, 0x01, 0x00, // function section
    0x07, 0x07, 0x01, 0x03, 'm', 'i', 'n', 0x00, 0x00, // export section
    0x0A, 0x0D, 0x01, 0x0B, 0x00, // code section header
    0x20, 0x00, // local.get 0
    0x20, 0x01, // local.get 1
    0x20, 0x00, // local.get 0
    0x20, 0x01, // local.get 1
    0x48, // i32.lt_s
    0x1B, // select
    0x0B, // end
};

// WASM module: abs(i32) -> i32 using comparison
// select takes [val1, val2, cond] and returns val1 if cond != 0, else val2
// abs(x) = (x >= 0) ? x : (0 - x)
const TEST_WASM_ABS = [_]u8{
    0x00, 0x61, 0x73, 0x6D, // magic
    0x01, 0x00, 0x00, 0x00, // version
    0x01, 0x06, 0x01, 0x60, 0x01, 0x7F, 0x01, 0x7F, // type: (i32) -> i32
    0x03, 0x02, 0x01, 0x00, // function section
    0x07, 0x07, 0x01, 0x03, 'a', 'b', 's', 0x00, 0x00, // export section
    0x0A, 0x10, 0x01, 0x0E, 0x00, // code section header
    0x20, 0x00, // local.get 0 (x) - val1 (returned if cond true)
    0x41, 0x00, // i32.const 0
    0x20, 0x00, // local.get 0 (x)
    0x6B, // i32.sub (0 - x = -x) - val2 (returned if cond false)
    0x20, 0x00, // local.get 0 (x)
    0x41, 0x00, // i32.const 0
    0x4E, // i32.ge_s (x >= 0) - cond
    0x1B, // select: (x >= 0) ? x : -x
    0x0B, // end
};

// WASM module: store_load(value, addr) -> value
// Stores value at addr, then loads it back
// Code: local.get 1, local.get 0, i32.store, local.get 1, i32.load
const TEST_WASM_STORE_LOAD = [_]u8{
    0x00, 0x61, 0x73, 0x6D, // magic (4)
    0x01, 0x00, 0x00, 0x00, // version (4)
    // Type section (id=1)
    0x01, // section id
    0x07, // section size = 7
    0x01, // num types = 1
    0x60, // func type
    0x02, 0x7F, 0x7F, // 2 params: i32, i32
    0x01, 0x7F, // 1 result: i32
    // Function section (id=3)
    0x03, // section id
    0x02, // section size = 2
    0x01, // num functions = 1
    0x00, // type index = 0
    // Export section (id=7)
    0x07, // section id
    0x07, // section size = 7
    0x01, // num exports = 1
    0x03, // name length = 3
    's', 't', 'l', // name
    0x00, // export kind = func
    0x00, // func index = 0
    // Code section (id=10)
    0x0A, // section id
    0x0F, // section size = 15
    0x01, // num functions = 1
    0x0D, // func body size = 13
    0x00, // num locals = 0
    // Code: 12 bytes
    0x20, 0x01, // local.get 1 (addr)
    0x20, 0x00, // local.get 0 (value)
    0x36, 0x02, 0x00, // i32.store align=4 offset=0
    0x20, 0x01, // local.get 1 (addr)
    0x28, 0x02, 0x00, // i32.load align=4 offset=0
    0x0B, // end
};

// WASM module with two functions:
// func $double (param i32) (result i32) = x * 2
// func $main (param i32) (result i32) = call $double
const TEST_WASM_TWO_FUNCS = [_]u8{
    0x00, 0x61, 0x73, 0x6D, // magic (4 bytes)
    0x01, 0x00, 0x00, 0x00, // version (4 bytes)
    // Type section (id=1)
    0x01, // section id
    0x06, // section size = 6
    0x01, // num types = 1
    0x60, // func type
    0x01, 0x7F, // 1 param: i32
    0x01, 0x7F, // 1 result: i32
    // Function section (id=3)
    0x03, // section id
    0x03, // section size = 3
    0x02, // num functions = 2
    0x00, // func 0: type 0
    0x00, // func 1: type 0
    // Export section (id=7)
    0x07, // section id
    0x08, // section size = 8
    0x01, // num exports = 1
    0x04, // name length = 4
    'm', 'a', 'i', 'n', // name
    0x00, // export kind = func
    0x01, // func index = 1 (main)
    // Code section (id=10)
    0x0A, // section id
    0x10, // section size = 16 (1 + 8 + 7)
    0x02, // num functions = 2
    // Function 0: double(x) = x * 2 (body=8: 1+2+2+1+1+1)
    0x07, // func body size = 7
    0x00, // num locals = 0
    0x20, 0x00, // local.get 0
    0x41, 0x02, // i32.const 2
    0x6C, // i32.mul
    0x0B, // end
    // Function 1: main(x) = double(x) (body=6: 1+2+2+1)
    0x06, // func body size = 6
    0x00, // num locals = 0
    0x20, 0x00, // local.get 0
    0x10, 0x00, // call 0 (double)
    0x0B, // end
};

// WASM module with loop: count down from n to 0, return count
// Simpler version: just count iterations
const TEST_WASM_LOOP = [_]u8{
    0x00, 0x61, 0x73, 0x6D, // magic (4)
    0x01, 0x00, 0x00, 0x00, // version (4)
    // Type section (id=1, size=6)
    0x01, 0x06,
    0x01, // 1 type
    0x60, 0x01, 0x7F, 0x01, 0x7F, // (i32) -> i32
    // Function section (id=3, size=2)
    0x03, 0x02,
    0x01, 0x00, // 1 func, type 0
    // Export section (id=7, size=8)
    0x07, 0x08,
    0x01, // 1 export
    0x04, 'l', 'o', 'o', 'p', // name
    0x00, 0x00, // func 0
    // Code section (id=10)
    0x0A, 0x27, // size = 39 (1 + 1 + 37)
    0x01, // 1 function
    0x25, // body size = 37
    0x01, 0x01, 0x7F, // 1 local: i32 (count)
    // count = 0
    0x41, 0x00, // i32.const 0
    0x21, 0x01, // local.set 1 (count)
    // block $exit
    0x02, 0x40,
    // loop $loop
    0x03, 0x40,
    // if n == 0, exit
    0x20, 0x00, // local.get 0 (n)
    0x45, // i32.eqz
    0x0D, 0x01, // br_if 1 (exit block)
    // count++
    0x20, 0x01, // local.get 1
    0x41, 0x01, // i32.const 1
    0x6A, // i32.add
    0x21, 0x01, // local.set 1
    // n--
    0x20, 0x00, // local.get 0
    0x41, 0x01, // i32.const 1
    0x6B, // i32.sub
    0x21, 0x00, // local.set 0
    // continue loop
    0x0C, 0x00, // br 0 (loop)
    0x0B, // end loop
    0x0B, // end block
    // return count
    0x20, 0x01, // local.get 1
    0x0B, // end func
};

// WASM module with loop: sum 1 to N
// sum(n) = 1 + 2 + ... + n
// Body: 37 bytes, Code section: 39 bytes
const TEST_WASM_SUM = [_]u8{
    0x00, 0x61, 0x73, 0x6D, // magic
    0x01, 0x00, 0x00, 0x00, // version
    // Type section (id=1, size=6)
    0x01, 0x06,
    0x01, 0x60, 0x01, 0x7F, 0x01, 0x7F, // (i32) -> i32
    // Function section (id=3, size=2)
    0x03, 0x02,
    0x01, 0x00, // 1 func, type 0
    // Export section (id=7, size=7)
    0x07, 0x07,
    0x01, 0x03, 's', 'u', 'm', 0x00, 0x00,
    // Code section (id=10, size=39)
    0x0A, 0x27,
    0x01, // 1 function
    0x25, // body size = 37
    0x01, 0x01, 0x7F, // 1 local: i32 (sum)
    // sum = 0
    0x41, 0x00, // i32.const 0
    0x21, 0x01, // local.set 1
    // block $exit
    0x02, 0x40,
    // loop $loop
    0x03, 0x40,
    // if n == 0, exit
    0x20, 0x00, // local.get 0 (n)
    0x45, // i32.eqz
    0x0D, 0x01, // br_if 1
    // sum += n
    0x20, 0x01, // local.get 1
    0x20, 0x00, // local.get 0
    0x6A, // i32.add
    0x21, 0x01, // local.set 1
    // n--
    0x20, 0x00, // local.get 0
    0x41, 0x01, // i32.const 1
    0x6B, // i32.sub
    0x21, 0x00, // local.set 0
    // continue loop
    0x0C, 0x00, // br 0
    0x0B, // end loop
    0x0B, // end block
    // return sum
    0x20, 0x01, // local.get 1
    0x0B, // end func
};

// Alias for backward compatibility
const TEST_WASM = TEST_WASM_ADD;

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

    // Step 5: Execute on Ternary VM
    std.debug.print("\nStep 5: Executing on Ternary VM...\n", .{});
    const vm = try b2t_vm.VM.init(allocator);
    defer vm.deinit();

    try vm.load(trit_code);
    // Set arguments: add(3, 4)
    vm.setArgs(&[_]i32{ 3, 4 });
    const result = try vm.run();

    std.debug.print("  ✅ VM executed successfully\n", .{});
    std.debug.print("  ✅ add(3, 4) = {}\n", .{result});

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  ✅ B2T FULL PIPELINE TEST PASSED!                           ║\n", .{});
    std.debug.print("║                                                              ║\n", .{});
    std.debug.print("║  WASM -> Disasm -> TVC IR -> .trit -> VM Execution           ║\n", .{});
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

    // Execute on VM with arguments: add(3, 4) = 7
    const vm = try b2t_vm.VM.init(allocator);
    defer vm.deinit();
    try vm.load(trit_code);
    vm.setArgs(&[_]i32{ 3, 4 }); // Set arguments
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, 7), result);
}

// Helper function to run full pipeline
fn runPipeline(allocator: std.mem.Allocator, wasm: []const u8, args: []const i32) !i32 {
    return runPipelineOpt(allocator, wasm, args, .O0);
}

// Helper function to run pipeline with optimization
fn runPipelineOpt(allocator: std.mem.Allocator, wasm: []const u8, args: []const i32, opt_level: b2t_optimizer.OptLevel) !i32 {
    var binary = try b2t_loader.loadFromMemory(allocator, wasm);
    defer binary.deinit();

    var disasm = try b2t_disasm.disassemble(allocator, &binary);
    defer disasm.deinit();

    var lifter = b2t_lifter.Lifter.init(allocator);
    defer lifter.deinit();
    const module = try lifter.lift(&disasm);

    // Apply optimization pass
    var optimizer = b2t_optimizer.Optimizer.init(allocator, opt_level);
    optimizer.optimize(module);

    var codegen = b2t_codegen.Codegen.init(allocator);
    defer codegen.deinit();
    const trit_code = try codegen.generate(module);

    const vm = try b2t_vm.VM.init(allocator);
    defer vm.deinit();
    try vm.load(trit_code);
    vm.setArgs(args);
    return try vm.run();
}

test "pipeline add(3, 4) = 7" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_ADD, &[_]i32{ 3, 4 });
    try std.testing.expectEqual(@as(i32, 7), result);
}

test "pipeline sub(10, 3) = 7" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_SUB, &[_]i32{ 10, 3 });
    try std.testing.expectEqual(@as(i32, 7), result);
}

test "pipeline mul(6, 7) = 42" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_MUL, &[_]i32{ 6, 7 });
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "pipeline div(84, 2) = 42" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_DIV, &[_]i32{ 84, 2 });
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "pipeline add with large numbers" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_ADD, &[_]i32{ 1000000, 234567 });
    try std.testing.expectEqual(@as(i32, 1234567), result);
}

test "pipeline sub with negative result" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_SUB, &[_]i32{ 5, 10 });
    try std.testing.expectEqual(@as(i32, -5), result);
}

test "pipeline mul with zero" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_MUL, &[_]i32{ 42, 0 });
    try std.testing.expectEqual(@as(i32, 0), result);
}

test "pipeline max(5, 10) = 10" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_MAX, &[_]i32{ 5, 10 });
    try std.testing.expectEqual(@as(i32, 10), result);
}

test "pipeline max(10, 5) = 10" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_MAX, &[_]i32{ 10, 5 });
    try std.testing.expectEqual(@as(i32, 10), result);
}

test "pipeline min(5, 10) = 5" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_MIN, &[_]i32{ 5, 10 });
    try std.testing.expectEqual(@as(i32, 5), result);
}

test "pipeline min(10, 5) = 5" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_MIN, &[_]i32{ 10, 5 });
    try std.testing.expectEqual(@as(i32, 5), result);
}

test "pipeline abs(5) = 5" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_ABS, &[_]i32{5});
    try std.testing.expectEqual(@as(i32, 5), result);
}

test "pipeline abs(-5) = 5" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_ABS, &[_]i32{-5});
    try std.testing.expectEqual(@as(i32, 5), result);
}

test "pipeline store_load(42, 0) = 42" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_STORE_LOAD, &[_]i32{ 42, 0 });
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "pipeline store_load(123, 100) = 123" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_STORE_LOAD, &[_]i32{ 123, 100 });
    try std.testing.expectEqual(@as(i32, 123), result);
}

test "pipeline store_load negative value" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_STORE_LOAD, &[_]i32{ -999, 200 });
    try std.testing.expectEqual(@as(i32, -999), result);
}

test "pipeline two functions: double(21) = 42" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_TWO_FUNCS, &[_]i32{21});
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "pipeline two functions: double(5) = 10" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_TWO_FUNCS, &[_]i32{5});
    try std.testing.expectEqual(@as(i32, 10), result);
}

test "pipeline two functions: double(0) = 0" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_TWO_FUNCS, &[_]i32{0});
    try std.testing.expectEqual(@as(i32, 0), result);
}

// Optimized pipeline tests (O1 - native ternary)
test "optimized add(3, 4) = 7" {
    const result = try runPipelineOpt(std.testing.allocator, &TEST_WASM_ADD, &[_]i32{ 3, 4 }, .O1);
    try std.testing.expectEqual(@as(i32, 7), result);
}

test "optimized mul(6, 7) = 42" {
    const result = try runPipelineOpt(std.testing.allocator, &TEST_WASM_MUL, &[_]i32{ 6, 7 }, .O1);
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "optimized sub(100, 58) = 42" {
    const result = try runPipelineOpt(std.testing.allocator, &TEST_WASM_SUB, &[_]i32{ 100, 58 }, .O1);
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "optimized div(126, 3) = 42" {
    const result = try runPipelineOpt(std.testing.allocator, &TEST_WASM_DIV, &[_]i32{ 126, 3 }, .O1);
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "optimized large numbers" {
    const result = try runPipelineOpt(std.testing.allocator, &TEST_WASM_ADD, &[_]i32{ 1000000, 234567 }, .O1);
    try std.testing.expectEqual(@as(i32, 1234567), result);
}

test "optimized negative numbers" {
    const result = try runPipelineOpt(std.testing.allocator, &TEST_WASM_SUB, &[_]i32{ 5, 10 }, .O1);
    try std.testing.expectEqual(@as(i32, -5), result);
}

test "loop countdown(5) = 5" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_LOOP, &[_]i32{5});
    try std.testing.expectEqual(@as(i32, 5), result);
}

test "loop countdown(0) = 0" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_LOOP, &[_]i32{0});
    try std.testing.expectEqual(@as(i32, 0), result);
}

test "loop countdown(10) = 10" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_LOOP, &[_]i32{10});
    try std.testing.expectEqual(@as(i32, 10), result);
}

test "loop sum(5) = 15" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_SUM, &[_]i32{5});
    try std.testing.expectEqual(@as(i32, 15), result);
}

test "loop sum(10) = 55" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_SUM, &[_]i32{10});
    try std.testing.expectEqual(@as(i32, 55), result);
}

test "loop sum(0) = 0" {
    const result = try runPipeline(std.testing.allocator, &TEST_WASM_SUM, &[_]i32{0});
    try std.testing.expectEqual(@as(i32, 0), result);
}
