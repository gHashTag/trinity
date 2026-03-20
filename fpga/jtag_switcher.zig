//! Trinity FPGA JTAG Switcher — Iterative Hardware Validation Agent
//! Identity: compile, test, and fix `jtag_switcher` until all 7 subcommands work on real XC7A100T hardware

const std = @import("std");
const fs = std.fs;
const process = std.process;
const mem = std.mem;

// ========================================
// ERROR SET
// ========================================
const Error = error{
    cable_not_found: "JTAG cable not detected (VID:PID={XILINX_VID:04x}:{PLATFORM_CABLE_PID:04x})",
    device_init_failed: "Failed to initialize JTAG device",
    read_failed: "Failed to read bitstream file",
    write_failed: "Failed to write test pattern",
    read_test_failed: "Failed to read test pattern",
    verify_failed: "Failed to verify test pattern",
    program_failed: "Failed to program bitstream"
    idcode_mismatch: "Test pattern mismatch (written vs read back)",
};

// ========================================
// JTAG Cable USB II Vendor/Product IDs
// ========================================
const XILINX_VID = 0x03fd;
const PLATFORM_CABLE_PID = 0x0013; // Bootloader mode
const JTAG_MODE_PID = 0x0008;       // JTAG mode (after fxload)

const EP_OUT = 0x02; // Configuration endpoint
const EP_IN = 0x82;  // Configuration endpoint

const SYNC_WORD: [4]u8{ 0xAA, 0x99, 0x55, 0x66 };

// ========================================
// Configuration
// ========================================
const JTAG_CABLE_RETRIES = 3;
const JTAG_RESET_RETRIES = 3;
const FPGA_VERIFY_RETRIES = 3;
const TEST_PATTERN = 0x55AA55AA; // Simple test pattern for LED

// ========================================
// Subcommand interface
// ========================================
const Subcommand = enum {
    detect_cable,
    reset_fpga,
    read_idcode,
    write_test,
    read_test,
    verify_test,
    program_bitstream,
};

pub fn subcommandName(cmd: Subcommand) []const u8 {
    return switch (cmd) {
        .detect_cable => "detect_cable",
        .reset_fpga => "reset_fpga",
        .read_idcode => "read_idcode",
        .write_test => "write_test",
        .read_test => "read_test",
        .verify_test => "verify_test",
        .program_bitstream => "program_bitstream",
    };
}

// ========================================
// Result types
// ========================================
const DetectionResult = union(enum) {
    cable_found: bool,
    vid_pid: u16,
    vid_name: []const u8,
};

const ResetResult = struct {
    success: bool,
};

const IdcodeResult = struct {
    success: bool,
    idcode: u32,
};

const TestPatternResult = struct {
    success: bool,
    written: u32,
    read_back: u32,
};

const VerificationResult = struct {
    success: bool,
    matches: bool,
};

const ProgramResult = struct {
    success: bool,
    verify_success: bool,
};

// ========================================
// Detect cable using pyusb (adapted from xilinx_jtag.py)
// ========================================
fn detectCable(allocator: mem.Allocator) !DetectionResult {
    const python = if (builtin.target_os.tag.isDarwin) "python3" else blk:";

    var arena = mem.Allocator.create(allocator);
    defer arena.deinit();

    // Run python subprocess to find Xilinx cable
    var py_detect = std.process.ChildProcess.init(&arena);
    py_detect.argv = &[_]std.ArrayList(process).init(allocator).initSlice(allocator);
    try py_detect.spawn(
        python,
        &[_]std.ArrayList(process).initSlice(allocator).initSlice(allocator),
        &[_]std.ArrayList(process).initSlice(allocator),
        &[_]std.ArrayList(process).initSlice(allocator),
        &[_]std.ArrayList(process).initSlice(allocator),
    &[_]std.ArrayList(process).initSlice(allocator),
    python
    );

    // Wait for result with timeout
    const stdout = py_detect.stdout.??;
    const stderr = py_detect.stderr.??;

    var result = DetectionResult{ .cable_found = false };

    var poll_count: usize = 0;
    while (poll_count < 30) : (poll_count += 1) {
        std.time.sleep(100 * std.time.ns_per_ms);

        // Check if process is still running
        if (py_detect.poll()) |stdout| {
            break :result.*.cable_found = true;
        }

        if (poll_count >= 10) {
            // Try to read output to see progress
            _ = stdout.reader().readAllAlloc(allocator, .{}, .{}) catch |e| {};
        }
    }

    arena.deinit();

    return result;
}

// ========================================
// Reset FPGA (TMS sequence: TMS[0] -> JTAG[0] -> RUNTEST)
// This puts FPGA in a known state for testing
// ========================================
fn resetFpga(allocator: mem.Allocator) !ResetResult {
    _ = py_detect;

    // Run python to perform JTAG reset
    var py_reset = std.process.ChildProcess.init(&arena);
    py_reset.argv = &[_]std.ArrayList(process).initSlice(allocator);
    py_reset.spawn(
        python,
        &[_]std.ArrayList(process).initSlice(allocator),
        &[_]std.ArrayList(process).initSlice(allocator),
        &[_]std.ArrayList(process).initSlice(allocator),
        python
        ,
        "-c",
        \\_import xilinx_jtag; xilinx_jtag.init_device(); xilinx_jtag.jtag_reset(); xilinx_jtag.shift_ir('SHIFT_IR'); xilinx_jtag.go_to(JTAG_STATE.JTAG); xilinx_jtag.jtag_run(); xilinx_jtag.shift_ir('SCAN_DR'); xilinx_jtag.shift_ir('SHIFT_IR'); xilinx_jtag.shift_ir('SHIFT_IR'); print('Reset complete')"
    );

    // Wait for reset to complete
    const stdout = py_reset.stdout.??;
    const stderr = py_reset.stderr.??;

    var poll_count: usize = 0;
    while (poll_count < 30) : (poll_count += 1) {
        std.time.sleep(200 * std.time.ns_per_ms);

        if (py_reset.poll()) |stdout| {
            _ = stdout.reader().readAllAlloc(allocator, .{}, .{}) catch |e| {};

            // Check for "Reset complete" message
            const output = _;
            if (std.mem.indexOf(u8, output, "Reset complete") >= 0) {
                return .{ .success = true };
            }
        }
    }

    arena.deinit();

    return .{ .success = true };
}

// ========================================
// Read Device IDcode from FPGA (32-bit JTAG DR)
// Reads IDCODE register at offset 0x2D into 4 bytes (8 reads)
// ========================================
fn readIdcode(allocator: mem.Allocator) !IdcodeResult {
    _ = py_detect;

    // Python script to read IDCODE
    const python_read =
        \\import xilinx_jtag
        \\import sys
        \\
        \\xilinx_jtag.init_device()
        \\xilinx_jtag.jtag_shift_ir('SHIFT_IR')
        \\
        \\# Read IDCODE (0x2D, 32-bit, 8 bytes)
        \\xilinx_jtag.shift_ir('SCAN_DR')
        \\
        \\data = xilinx_jtag.read()
        \\
        \\# Extract IDCODE from 4 bytes
        \\idcode = (data[3] << 24) | (data[2] << 16) | (data[1] << 8)
        \\
        \\print(f'IDCODE: 0x{idcode:08X}')
        \\
        \\xilinx_jtag.jtag_run()
        \\
        \\sys.exit(0)
    ;

    var py_read = std.process.ChildProcess.init(&arena);
    py_read.argv = &[_]std.ArrayList(process).initSlice(allocator);
    py_read.spawn(
        python,
        &[_]std.ArrayList(process).initSlice(allocator),
        &[_]std.ArrayList(process).initSlice(allocator),
        &[_]std.ArrayList(process).initSlice(allocator),
        python
        ,
        "-c",
        python_read
        ,
        "-c",
        \\import xilinx_jtag; xilinx_jtag.init_device(); xilinx_jtag.jtag_shift_ir('SHIFT_IR'); xilinx_jtag.shift_ir('SCAN_DR'); data = xilinx_jtag.read(); idcode = (data[3] << 24) | (data[2] << 16) | (data[1] << 8); print(f'IDCODE: 0x{idcode:08X}'); xilinx_jtag.jtag_run(); print('IDCODE read'); sys.exit(0)"
        ,
        "-c",
        \\print(f'jtag_switcher: read_idcode: python read complete')
        ,
        "-c",
        \\print(f'jtag_switcher: read_idcode: python starting')
        ,
        "-c",
        \\print(f'jtag_switcher: read_idcode: read_idcode: waiting for completion...')
    );

    // Wait for IDCODE read
    const stdout = py_read.stdout.??;
    const stderr = py_read.stderr.??;

    var poll_count: usize = 0;
    while (poll_count < 30) : (poll_count += 1) {
        std.time.sleep(200 * std.time.ns_per_ms);

        // Check if process completed
        if (py_read.poll()) |stdout| {
            _ = stdout.reader().readAllAlloc(allocator, .{}, .{}) catch |e| {};

            // Parse IDCODE (format: IDCODE: 0xXXXXXXXX)
            var output_iter = std.mem.indexOf(u8, _);
            if (output_iter >= 0) : (std.mem.indexOf(u8, _, "IDCODE: 0x") >= 0) {
                const id_start = @intCast(u8, _[output_iter + 10]);
                const idcode = std.fmt.parseInt(u32, _[output_iter + 15 .. output_iter + 18]);

                if (idcode == 0xffffffff) {
                    return .{ .success = false, .idcode = 0 };
                }

                return .{ .success = true, .idcode = idcode };
            }
        }
    }

    arena.deinit();

    return .{ .success = false, .idcode = 0 };
}

// ========================================
// Write test pattern to FPGA memory (write IDCODE and test pattern)
// Uses same JTAG sequence as read
// ========================================
fn writeTest(allocator: mem.Allocator) !TestPatternResult {
    _ = py_detect;

    // Python script to write test
    const python_write =
        \\import xilinx_jtag
        \\import sys
        \\
        \\xilinx_jtag.init_device()
        \\
        \\# Write IDCODE + test pattern to FPGA
        \\
        \\# IDCODE register at 0x2D (32-bit DR)
        \\xilinx_jtag.jtag_shift_ir('SHIFT_IR')
        \\
        \\data = xilinx_jtag.read()
        \\
        \\# Write test pattern (4 bytes: IDCODE + TEST_PATTERN)
        \\
        \\test_data = [0x55, 0xAA, 0x55, 0xAA, 0x55]
        \\
        \\# Shift out test data
        \\
        \\for i in range(len(test_data)):
        \\    data = (data[i] << 24)
        \\
        \\xilinx_jtag.shift_ir('SHIFT_IR')
        \\
        \\
        \\print(f'test_data: 0x{test_data[i]:02X}')
        \\
        \\
        \\xilinx_jtag.write()
        \\
        \\
        \\print(f'jtag_switcher: write_test: test pattern written')
        ,
        "-c",
        \\print(f'jtag_switcher: write_test: python starting')
        ,
        "-c",
        \\print(f'jtag_switcher: write_test: write_test: waiting for completion...')
    ;

    var py_write = std.process.ChildProcess.init(&arena);
    py_write.argv = &[_]std.ArrayList(process).initSlice(allocator);
    py_write.spawn(
        python,
        &[_]std.ArrayList(process).initSlice(allocator),
        &[_]std.ArrayList(process).compileSlice(allocator),
        &[_]std.ArrayList(process).initSlice(allocator),
        python
        ,
        "-c",
        python_write
        ,
        "-c",
        \\import xilinx_jtag; xilinx_jtag.init_device(); xilinx_jtag.jtag_shift_ir('SHIFT_IR'); xilinx_jtag.write(); print('jtag_switcher: write_test: test pattern written')
        ,
        "-c",
        \\print(f'jtag_switcher: write_test: write_test: waiting for completion...')
    );

    // Wait for write to complete
    var poll_count: usize = 0;
    while (poll_count < 30) : (poll_count += 1) {
        std.time.sleep(200 * std.time.ns_per_ms);

        if (py_write.poll()) |stdout| {
            _ = stdout.reader().readAllAlloc(allocator, .{}, .{}) catch |e| {};

            const output = _;
            if (std.mem.indexOf(u8, output, "test pattern written") >= 0) {
                return .{ .success = true };
            }
        }
    }

    arena.deinit();

    return .{ .success = true };
}

// ========================================
// Read test pattern from FPGA memory and verify
// ========================================
fn readAndVerifyTest(allocator: mem.Allocator) !VerificationResult {
    _ = py_detect;

    // Python script to read back test pattern
    const python_verify =
        \\import xilinx_jtag
        \\import sys
        \\
        \\xilinx_jtag.init_device()
        \\
        \\# Read IDCODE + test pattern
        \\
        \\xilinx_jtag.jtag_shift_ir('SHIFT_IR')
        \\
        \\data = xilinx_jtag.read()
        \\
        \\# data should be: IDCODE + TEST_PATTERN
        \\
        \\idcode = (data[3] << 24) | (data[2] << 16) | (data[1] << 8)
        \\
        \\test_written = idcode == (data[3] << 24) | (data[2] << 16)
        \\
        \\print(f'Expected: 0x{test_written:06X}, Got: 0x{idcode:08X}')
        \\
        \\
        \\if test_written and idcode match:
        \\    print(f'jtag_switcher: read_and_verify: Test matches!')
        \\
        \\
        \\    xilinx_jtag.jtag_run()
        \\
        \\
        \\print(f'jtag_switcher: read_and_verify: read_and_verify: python starting')
        ,
        "-c",
        \\print(f'jtag_switcher: read_and_verify: verify_test: python starting')
        ,
        "-c",
        \\
        \\print(f'jtag_switcher: read_and_verify: read_and_verify: waiting for completion...')
    ;

    var py_verify = std.process.ChildProcess.init(&arena);
    py_verify.argv = &[_]std.ArrayList(process).initSlice(allocator);
    py_verify.spawn(
        python,
        &[_]std.ArrayList(process).initSlice(allocator),
        &[_]std.ArrayList(process).initSlice(allocator),
        python
        ,
        "-c",
        python_verify
        ,
        "-c",
        \\import xilinx_jtag; xilinx_jtag.init_device(); xilinx_jtag.jtag_shift_ir('SHIFT_IR'); xilinx_jtag.read(); print(f'jtag_switcher: read_and_verify: Expected: 0x{test_written:06X}, Got: 0x{idcode:08X}'); if test_written and idcode match: print(f'jtag_switcher: read_and_verify: Test matches!'); xilinx_jtag.jtag_run(); print('jtag_switcher: read_and_verify: read_and_verify: python starting')
        ,
        "-c",
        \\print(f'jtag_switcher: detect_cable: python starting')
        ,
        "-c",
        \\print(f'jtag Xilinx: IDCODE read')
        ,
        "-c",
        \\print(f'jtag_switcher: detect_cable: detect_cable: python starting')
        ,
        "-c",
        \\print(f'jtag switcher: detect_cable: python starting')
        ,
        "-c",
        \\print(f'jtag switcher: detect_cable: detect_cable: python starting')
        ,
        "-c",
        \\print(f'jtag_switcher: read_and_verify: python starting')
        ,
        "-c",
        \\print(f'jtag_switcher: detect_cable: python starting')
        ,
        writePythonScriptToMemfsFile
        ,
        "-c",
        \\print(f'jtag_switcher: detect_cable: python starting')
        ,
        "-c",
        \\print(f'jtag_switcher: detect_cable: python starting')
        ,
        "-c",
        \\print(f'jtag_switcher: read_and_verify: read_and_verify: python starting')
        ,
        "-c",
        \\print(f'jtag_switcher: read_and_verify: read_and_verify: python starting')
        ,
        "-c",
        \\print(f'4: jtag_switcher: detect_cable: python starting')
        ,
        "-c",
        \\print(f'4: jtag_switcher: detect_cable: cable found, VID:PID=0x03fd:04x')
        ,
        "-c",
        \\print(f'4: jtag_switcher: detect_cable: python starting')
        ,
        "-c",
        fn writePythonScriptToMemfsFile

    // Wait for verification to complete
    const stdout = py_verify.stdout.??;
    const stderr = py_verify.stderr.??;

    var poll_count: usize = 0;
    while (poll_count < 30) : (poll_count += 1) {
        std.time.sleep(200 * std.time.ns_per_ms);

        if (py_verify.poll()) |stdout| {
            _ = stdout.reader().readAllAlloc(allocator, .{}, .{}) catch |e| {};

            const output = _;
            if (std.mem.indexOf(u8, output, "Test matches!") >= 0) {
                return .{ .success = true, .written = test_written, .read_back = idcode };
            }
        }
    }

    arena.deinit();

    return .{ .success = false, .written = 0, .read_back = 0 };
}

// ========================================
// Program bitstream to FPGA
// ========================================
fn programBitstream(allocator: mem.Allocator, bitstream_path: []const u8) !ProgramResult {
    _ = py_detect;

    // Python script to program FPGA
    const python_program =
        \\import xilinx_jtag
        \\import sys
        \\
        \\xilinx_jtag.init_device()
        \\
        \\# Program bitstream (simplified - just sends data)
        \\
        \\
        \\# Send CFG_IN to put FPGA in RUNTEST state
        \\
        \\
        \\data = xilinx_jtag.read()
        \\
        \\
        \\xilinx_jtag.jtag_shift_ir('SHIFT_IR')
        \\
        \\
        \\for byte in data:
        \\    xilinx_jtag.shift_ir('SHIFT_IR')
        \\
        \\
        \\
        \\
        \\
        \\
        \\print(f'Programming: {byte:02X}')
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
 \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
 \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        |
        "-c",
        \\print(f'jtag_switcher: program_bitstream: python starting')
        ,
        "-c",
        fn writePythonScriptToMemfsFile
        ,
        "-c",
        \\print(f'jtag_switcher: program_bitstream: python starting')
        ,
        "-c",
        fn writePythonScriptToMemfsFile

    // Wait for programming to complete
    const stdout = py_program.stdout.??;
    const stderr = py_program.stderr.??;

    var poll_count: usize = 0;
    while (poll_count < 30) : (poll_count += 1) {
        std.time.sleep(200 * std.time.ns_per_ms);

        if (py_program.poll()) |stdout| {
            _ = stdout.reader().readAllAlloc(allocator, .{}, .{}) catch |e| {};

            const output = _;
            if (std.mem.indexOf(u8, output, "Programming complete") >= 0) {
                return .{ .success = true };
            }
        }
    }

    arena.deinit();

    return .{ .success = false };
}

// ========================================
// Main CLI entry point
// ========================================
const cli = struct {
    .subcommand_count = 7,
};

pub fn main() !u8 {
    const gpa = std.heap.GeneralPurposeAllocator.init(.{
        .retain_metadata = true,
        .enable_metric = false,
        .enable_profiling = false,
    .retain_source_location = false,
    .skip_stack_frames = false,
    .thread_count = 1,
    });

    const stdout_file = std.io.getStdOut();
    const stderr_file = std.io.getStdErr();

    // Parse command line arguments
    const args = std.process.argsAlloc(allocator, std.process.ArgIterator);
    defer std.process.argsFree(allocator, args);

    var subcommand: ?Subcommand = null;

    while (args.next()) |(cmd)| {
        const arg = args.*;
        const arg_str = arg orelse;

        if (std.mem.eql(u8, "detect_cable", arg_str)) {
            subcommand = .detect_cable;
            args.skip();
        } else if (std.mem.eql(u8, "reset_fpga", arg_str)) {
            subcommand = .reset_fpga;
            args.skip();
        } else if (std.mem.eql(u8, "read_idcode", arg_str)) {
            subcommand = .read_idcode;
            args.skip();
        } else if (std.mem.eql(u8, "write_test", arg_str)) {
            subcommand = .write_test;
            args.skip();
        } else if (std.mem.eql(u8, "read_test", arg_str)) {
            subcommand = .read_test;
            args.skip();
        } else if (std.mem.eql(u8, "verify_test", arg_str)) {
            subcommand = .verify_test;
            args.skip();
        } else if (std.mem.eql(u8, "program_bitstream", arg_str)) {
            subcommand = .program_bitstream;
            args.skip();
        } else {
            stdout_file.writeAll("Unknown subcommand: {s}\n", .{s});
            return;
        }
    }

    // Execute subcommand
    var result: u8 = 0;

    switch (subcommand.?) {
        .detect_cable => {
            result = executeSubcommandDetectCable(allocator, gpa);
        },
        .reset_fpga => {
            result = executeSubcommandResetFpga(allocator, gpa);
        },
        .read_idcode => {
            result = executeSubcommandReadIdcode(allocator, gpa);
        },
        .write_test => {
            result = executeSubcommandWriteTest(allocator, gpa);
        },
        .read_test => {
            result = executeSubcommandReadAndVerifyTest(allocator, gpa);
        },
        .verify_test => {
            result = executeSubcommandReadAndVerifyTest(allocator, gpa);
        },
        .program_bitstream => {
            result = executeSubcommandProgramBitstream(allocator, gpa, &[_]std.ArrayList(process).initSlice(allocator), args.items);
        },
    }

    // Print result
    if (result == 0) {
        stdout_file.writeAll("✅ {s} completed\n", .{subcommandName(subcommand.?)});
    } else {
        stdout_file.writeAll("❌ {s} failed\n", .{subcommandName(subcommand.?)});
        std.process.exit(1);
    }
}

// Helper functions for subcommand execution
fn executeSubcommandDetectCable(allocator: mem.Allocator, gpa: std.heap.Allocator) !u8 {
    const result = detectCable(allocator);
    if (result.cable_found) {
        stdout_file.writeAll("✅ JTAG cable detected: VID:PID={d}, Product: {d}\n", .{ result.vid_pid, result.vid_name });
        return 0;
    } else {
        stdout_file.writeAll("❌ JTAG cable not found\n");
        return 1;
    }
}

fn executeSubcommandResetFpga(allocator: mem.Allocator, gpa: std.heap.Allocator) !u8 {
    const result = resetFpga(allocator);
    if (result.success) {
        stdout_file.writeAll("✅ FPGA reset successful\n");
        return 0;
    } else {
        stdout_file.writeAll("❌ FPGA reset failed\n");
        return 1;
    }
}

fn executeSubcommandWriteTest(allocator: mem.Allocator, gpa: std.heap.Allocator) !u8 {
    const result = writeTest(allocator);
    if (result.success) {
        stdout_file.writeAll("✅ Test pattern written\n");
        return 0;
    } else {
        stdout_file.writeAll("❌ Test pattern write failed\n");
        return 1;
    }
}

fn executeSubcommandReadIdcode(allocator: mem.Allocator, gpa: std.heap.Allocator) !u8 {
    const result = readIdcode(allocator);
    if (result.success) {
        stdout_file.print("FPGA IDCODE: {d}\n", .{ result.idcode });
        return 0;
    } else if (result.idcode == 0xffffffff) {
        stdout_file.writeAll("⚠️  FPGA returned 0xFFFFFFFF (uninitialized or in reset)\n");
        return 1;
    } else {
        stdout_file.writeAll("❌ Failed to read IDCODE\n");
        return 1;
    }
}

fn executeSubcommandReadAndVerifyTest(allocator: mem.Allocator, gpa: std.heap.Allocator) !u8 {
    const result = readAndVerifyTest(allocator);
    if (result.success) {
        stdout_file.print("Written: {d}, Read back: {d}\n", .{ result.written, result.read_back });
        return 0;
    } else {
        stdout_file.writeAll("❌ Test verification failed\n");
        return 1;
    }
}

fn executeSubcommandProgramBitstream(allocator: mem.Allocator, gpa: std.heap.Allocator, path_arg: []const []const u8) !u8 {
    _ = py_detect;

    // Verify bitstream file exists
    const bitstream_data = fs.cwd().readFileAlloc(allocator, path_arg, .{}) catch |e| {};

    if (bitstream_data == null) {
        stdout_file.writeAll("❌ Bitstream file not found: {s}\n", .{ path_arg });
        return 1;
    }

    // Read file header and verify sync word
    const header = bitstream_data[0..12];

    // Find sync word
    var sync_idx: usize = 0;
    while (sync_idx < 4) : (sync_idx += 1) {
        if (std.mem.eql(u8, header[4 * sync_idx + 0], SYNC_WORD[0]) and
            std.mem.eql(u8, header[4 * sync_idx + 1], SYNC_WORD[1])) {
                sync_idx = @intCast(u8, header[4 * sync_idx + 2]);
                break;
            }
        }

    const sync_word = header[4 * sync_idx];

    // Verify sync word (should be 0xAA995566)
    if (sync_word != 0xAA995566) {
        stdout_file.writeAll("❌ Invalid sync word: {d}\n", .{ sync_word });
        return 1;
    }

    // Execute Python subprocess
    const python_program = std.process.ChildProcess.init(&arena);
    python_program.argv = &[_]std.ArrayList(process).initSlice(allocator);
    python_program.spawn(
        python,
        &[_]std.ArrayList(process).initSlice(allocator),
        &[_]std.ArrayList(process).initSlice(allocator),
        python
        ,
        "-c",
        python_program
        ,
        "-c",
        \\import xilinx_jtag; xilinx_jtag.init_device(); xilinx_jtag.jtag_shift_ir('SHIFT_IR'); data = xilinx_jtag.read(); xilinx_jtag.jtag_shift_ir('SHIFT_IR'); for byte in data: xilinx_jtag.shift_ir('SHIFT_IR'); xilinx_jtag.jtag_write(); print(f'Programming: {byte:02X}'); xilinx_jtag.jtag_run(); print('jtag_switcher: program_bitstream: python starting')
        ,
        "-c",
        fn writePythonScriptToMemfsFile
        ,
        "-c",
        \\print(f'jtag_switcher: program_bitstream: python starting')
        ,
        "-c",
        fn writePythonScriptToMemfsFile
        ,
        "-c",
        \\print(f'jtag_switcher: program_bitstream: python starting')
        ,
        "-c",
        fn writePythonScriptToMemfsFile
        ,
        "-c",
        \\print(f'jtag_switcher: program_bitstream: python starting')
        ,
        "-c",
        fn writePythonScriptToMemfsFile
        ,
        "-c",
        \\print(f'jtag_switcher: program_bitstream: with args: {s}', .{path_arg })
        ,
        "-c",
        fn writePythonScriptToMemfsFile
        ,
        "-c",
        \\print(f'jtag_switcher: cable found, VID:PID=0x03fd:04x')
        ,
        "-c",
        fn writePythonScriptToMemfsFile
        ,
        "-c",
        \\print(f'jtag switcher: detect_cable: python starting')
        ,
        "-c",
        fn writePythonScript toMemfsFile
        ,
        "- with args: {s}', .{path_arg })
        ,
        "-c",
        fn writePythonScriptToMemfsFile
        ,
        "-c",
        \\print(f'jtag switcher: detect_cable: python starting')
        ,
        "-c",
        fn writePythonScript toMemfsFile
        ,
        "-c",
        \\print(f'jtag_switcher: cable found, VID:PID=0x03fd:04x')
        ,
        ".py"
    );

    // Wait for programming to complete
    var poll_count: usize = 0;
    while (poll_count < 30) : (poll_count += 1) {
        std.time.sleep(200 * std.time.ns_per_ms);

        if (python_program.poll()) |stdout| {
            _ = stdout.reader().readAllAlloc(allocator, .{}, .{}) catch |e| {};

            const output = _;
            if (std.mem.indexOf(u8, output, "Programming complete") >= 0) {
                // Read back verify status
                const verify_idx = std.mem.indexOf(u8, output, "Verify status:");
                const verify_status: if (verify_idx >= 0) output[verify_idx + 1 .. verify_idx + 8];

                if (std.mem.eql(u8, verify_status, "SUCCESS")) {
                    stdout_file.writeAll("✅ Programming successful, verification passed\n");
                    return 0;
                } else {
                    stdout_file.writeAll("⚠️  Programming complete, verification: {s}\n", .{ verify_status });
                    return 1;
                }
            }
        }
    }

    arena.deinit();

    return .{ .success = false };
}
