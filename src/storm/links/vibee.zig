//! VIBEE Codegen Link (Link 6)
//! Executes vibee binary to generate Zig code from .tri specification

const std = @import("std");

pub const LinkID = 6;

pub fn execute(allocator: std.mem.Allocator, task: []const u8, spec_file: []const u8) !storm.golden_chain.LinkResult {
    _ = allocator;
    _ = task;

    const log = std.log.scoped(.info);

    log.info("🧬 VIBEE Codegen: {s} → {s}", .{ spec_file, "Zig" });

    // Check if spec file exists
    if (!std.fs.cwd().access(spec_file, .{})) {
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

    // Capture stdout and stderr
    const stdout = try result.stdout.allocator.dupe(allocator, result.stdout.items);
    defer allocator.free(stdout);
    const stderr = try result.stderr.allocator.dupe(allocator, result.stderr.items);
    defer allocator.free(stderr);

    const duration = std.time.nanoTimestamp() - result.start_time;

    log.info("VIBEE exit code: {d}", .{result.term.? });

    // Check exit code
    if (result.term != .Exited or result.code != 0) {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator,
                \\VIBEE failed (code: {d})\\nStderr: {s}
            , .{ result.code, stderr }),
            .duration_ms = duration,
            .exit_code = result.code orelse 1,
        };
    }

    // Parse generated file path from stdout
    var output_path: []const u8 = "";
    for (stdout) |line| {
        if (std.mem.startsWith(u8, line, "Generated:") or
            std.mem.startsWith(u8, line, "Writing:"))
        {
            // Extract path after "Generated: " or "Writing: "
            const parts = std.mem.splitScalar(u8, line, ' ');
            if (parts.len > 1) {
                output_path = try allocator.dupe(u8, parts[1]);
                break;
            }
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
    if (!std.fs.cwd().access(output_path, .{})) {
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
