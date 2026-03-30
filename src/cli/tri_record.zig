//! tri-record — Terminal recording wrapper for `tri` commands
//!
//! Usage: tri-record <command>
//!   Records any `tri *` command to GIF via asciinema + agg
//!
//! Environment:
//!   TRI_REC_COLS     - Terminal width (default: 120)
//!   TRI_REC_ROWS     - Terminal height (default: 40)
//!   TRI_REC_IDLE_MAX - Max idle seconds before cut (default: 3)
//!   TRI_REC_OVERWRITE - Skip existing files (default: false)

const std = @import("std");
const builtin = @import("builtin");

const allocator = std.heap.page_allocator;

const Config = struct {
    cols: u16 = 120,
    rows: u16 = 40,
    idle_max: u16 = 3,
    overwrite: bool = false,
    output_dir: []const u8 = "recordings",
};

pub fn main() !u8 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print(
            \\Usage: tri-record <tri-command>
            \\
            \\Examples:
            \\  tri-record benchmark
            \\  tri-record test
            \\  tri-record "math demo"
            \\
            \\Environment:
            \\  TRI_REC_COLS=120       Terminal width
            \\  TRI_REC_ROWS=40        Terminal height
            \\  TRI_REC_IDLE_MAX=3    Max idle seconds before cut
            \\  TRI_REC_OVERWRITE=1   Overwrite existing files
            \\
        , .{});
        return 1;
    }

    const command = args[1];

    // Load config from environment
    var config = Config{};
    if (std.process.getEnvVarOwned(allocator, "TRI_REC_COLS")) |cols| {
        config.cols = std.fmt.parseInt(u16, cols, 10) catch config.cols;
    } else |_| {}
    if (std.process.getEnvVarOwned(allocator, "TRI_REC_ROWS")) |rows| {
        config.rows = std.fmt.parseInt(u16, rows, 10) catch config.rows;
    } else |_| {}
    if (std.process.getEnvVarOwned(allocator, "TRI_REC_IDLE_MAX")) |idle| {
        config.idle_max = std.fmt.parseInt(u16, idle, 10) catch config.idle_max;
    } else |_| {}
    if (std.process.getEnvVarOwned(allocator, "TRI_REC_OVERWRITE")) |_| {
        config.overwrite = true;
    } else |_| {}

    // Create output directory
    std.fs.cwd().makePath(config.output_dir) catch |e| {
        std.debug.print("Error creating output directory: {}\n", .{e});
        return 1;
    };

    // Generate output filename
    const basename = if (std.mem.indexOf(u8, command, " ")) |idx|
        command[0..idx]
    else
        command;

    const output_dir_path = if (builtin.os.tag == .windows)
        try std.fs.path.resolveZ(allocator, &[_][]const u8{config.output_dir})
    else
        config.output_dir;

    const gif_path = try std.fmt.allocPrint(
        allocator,
        "{s}/tri-{s}.gif",
        .{ output_dir_path, basename },
    );
    defer allocator.free(gif_path);

    // Check if file exists
    if (!config.overwrite) {
        if (std.fs.cwd().access(gif_path, .{})) |_| {
            std.debug.print("GIF already exists: {s}\nUse TRI_REC_OVERWRITE=1 to overwrite\n", .{gif_path});
            return 1;
        } else |_| {}
    }

    // Temporary cast file
    const cast_path = try std.fmt.allocPrint(
        allocator,
        "/tmp/tri-record-{x}.cast",
        .{std.time.nanoTimestamp()},
    );
    defer allocator.free(cast_path);
    std.fs.cwd().deleteFile(cast_path) catch {};

    // Build asciinema command
    const asciinema_cmd = try std.fmt.allocPrint(
        allocator,
        "asciinema rec --cols={} --rows={} --idle-time-limit={} --overwrite {s} -- tri {s}",
        .{ config.cols, config.rows, config.idle_max, cast_path, command },
    );
    defer allocator.free(asciinema_cmd);

    std.debug.print("Recording: tri {s}\n", .{command});
    std.debug.print("Output: {s}\n", .{gif_path});

    // Run asciinema
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", asciinema_cmd },
    });

    if (result.term != .Exited or result.term.Exited != 0) {
        std.debug.print("asciinema failed: {s}\n", .{result.stderr});
        return 1;
    }

    // Convert to GIF using agg
    const agg_cmd = try std.fmt.allocPrint(
        allocator,
        "agg --fps 30 {s} {s}",
        .{ cast_path, gif_path },
    );
    defer allocator.free(agg_cmd);

    const agg_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", agg_cmd },
    });

    if (agg_result.term != .Exited or agg_result.term.Exited != 0) {
        std.debug.print("agg failed: {s}\n", .{agg_result.stderr});
        return 1;
    }

    // Cleanup cast file
    std.fs.cwd().deleteFile(cast_path) catch {};

    // Show file size
    if (std.fs.cwd().statFile(gif_path)) |stat| {
        const kb = stat.size / 1024;
        std.debug.print("Created: {s} ({d} KB)\n", .{ gif_path, kb });
    } else |_| {}

    return 0;
}
