//! VIBEE Codegen Link (Link 6)
//! Executes vibee binary to generate Zig code from .tri specification

const std = @import("std");
const storm = @import("../golden_chain.zig");

pub const LinkID = 6;

pub fn execute(allocator: std.mem.Allocator, task: []const u8, spec_file: []const u8) !storm.golden_chain.LinkResult {
    _ = task;
    const log = std.log.scoped(.info);

    log.info("🧬 VIBEE Codegen: {s} → {s}", .{ spec_file, "Zig" });

    // Check if spec file exists (Zig 0.15: access() returns error, not bool)
    var exists = true;
    if (std.fs.cwd().access(spec_file, .{})) |_| {
        exists = false;
    }

    if (!exists) {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator, "Spec file not found: {s}", .{spec_file}),
            .duration_ms = 0,
            .exit_code = 1,
        };
    }

    // Execute vibee binary via std.process.Child
    const vibee_path = "zig-out/bin/vibee";

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ vibee_path, "gen", spec_file },
    }) catch |err| {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator, "Failed to spawn vibee: {}", .{err}),
            .duration_ms = 0,
            .exit_code = 1,
        };
    };
    defer result.deinit();

    // Capture stdout and stderr (Zig 0.15: dupe() returns []u8)
    const stdout = try allocator.dupe(u8, result.stdout.items);
    defer allocator.free(stdout);
    const stderr = try allocator.dupe(u8, result.stderr.items);
    defer allocator.free(stderr);

    const duration: u64 = @intCast(std.time.nanoTimestamp() - result.start_time);

    // Check exit code (Zig 0.15: term is Term enum)
    const exit_code: u32 = switch (result.term) {
        .Exited => |code| code,
        .Signal, .Stopped, .Unknown => 1,
    };

    log.info("VIBEE exit code: {d}", .{exit_code});

    if (exit_code != 0) {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator,
                \\VIBEE failed (code: {d})\\nStderr: {s}
            , .{ exit_code, stderr }),
            .duration_ms = duration,
            .exit_code = exit_code,
        };
    }

    // Parse generated file path from stdout
    var output_path: []const u8 = "";
    var lines_iter = std.mem.splitScalar(u8, stdout, '\n');
    while (lines_iter.next()) |line| {
        if (std.mem.startsWith(u8, line, "Generated:") or
            std.mem.startsWith(u8, line, "Writing:"))
        {
            // Extract path after "Generated: " or "Writing: "
            const parts = std.mem.splitScalar(u8, line, ' ');
            _ = parts.next() orelse break;
            const second_part = parts.next() orelse break;
            output_path = try allocator.dupe(u8, second_part);
            break;
        }
    }

    if (output_path.len == 0) {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator,
                \\VIBEE completed but no output file detected\\nStdout: {s}
            , .{stdout }),
            .duration_ms = duration,
            .exit_code = 0,
        };
    }

    // Verify generated file exists
    var gen_exists = true;
    if (std.fs.cwd().access(output_path, .{})) |_| {
        gen_exists = false;
    }

    if (!gen_exists) {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator,
                \\Generated file not found: {s}\\nVIBEE may have failed silently
            , .{output_path }),
            .duration_ms = duration,
            .exit_code = 1,
        };
    }

    log.info("✅ Generated: {s}", .{output_path });

    return .{
        .success = true,
        .message = try std.fmt.allocPrint(allocator, "Generated Zig: {s}", .{output_path}),
        .duration_ms = duration,
        .exit_code = 0,
        .stdout = try allocator.dupe(u8, output_path),
    };
}
