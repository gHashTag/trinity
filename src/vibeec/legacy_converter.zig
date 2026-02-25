// ═══════════════════════════════════════════════════════════════════════════════
// LEGACY TO VIBEE CONVERTER - Cycle 67
// ═══════════════════════════════════════════════════════════════════════════════
//
// Converts legacy format .vibee files to current VIBEE format.
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print(
            \\Legacy to VIBEE Converter - Cycle 67
            \\
            \\Usage:
            \\  {s} <input.vibee> [output_dir]
            \\  {s} --batch <input_dir> <output_dir>
            \\
        , .{ args[0], args[0] });
        return 1;
    }

    if (std.mem.eql(u8, args[1], "--batch")) {
        if (args.len < 4) {
            std.debug.print("Error: --batch requires input_dir and output_dir\n", .{});
            return 1;
        }
        const input_dir = args[2];
        const output_dir = args[3];

        try std.fs.cwd().makePath(output_dir);

        var success_count: usize = 0;
        var fail_count: usize = 0;

        var dir = try std.fs.cwd().openDir(input_dir, .{ .iterate = true });
        defer dir.close();

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (entry.kind != .file) continue;

            const ext = std.fs.path.extension(entry.name);
            if (!std.mem.eql(u8, ext, ".vibee")) continue;

            const input_path = try std.fs.path.join(allocator, &.{ input_dir, entry.name });
            defer allocator.free(input_path);

            const output_path = try std.fs.path.join(allocator, &.{ output_dir, entry.name });

            if (convertFile(allocator, input_path, output_path)) {
                std.debug.print(" {s}\n", .{output_path});
                success_count += 1;
            } else {
                std.debug.print(" X {s}\n", .{input_path});
                fail_count += 1;
            }
        }

        std.debug.print("\nConverted: {d} succeeded, {d} failed\n", .{ success_count, fail_count });
        return if (fail_count > 0) 1 else 0;
    }

    // Single file conversion
    const input_path = args[1];
    const output_dir = if (args.len > 2) args[2] else std.fs.path.dirname(input_path) orelse ".";

    const basename = std.fs.path.basename(input_path);
    const output_path = try std.fs.path.join(allocator, &.{ output_dir, basename });

    if (convertFile(allocator, input_path, output_path)) {
        std.debug.print(" Converted to {s}\n", .{output_path});
        return 0;
    } else {
        std.debug.print(" Error converting {s}\n", .{input_path});
        return 1;
    }
}

/// Convert a single file. Returns true on success.
fn convertFile(allocator: Allocator, input_path: []const u8, output_path: []const u8) bool {
    const source = std.fs.cwd().readFileAlloc(allocator, input_path, 1024 * 1024) catch return false;
    defer allocator.free(source);

    const vibee_content = convertLegacyToVibee(allocator, source) catch return false;
    defer allocator.free(vibee_content);

    std.fs.cwd().writeFile(.{
        .sub_path = output_path,
        .data = vibee_content,
    }) catch return false;

    return true;
}

/// Parse legacy format and convert to VIBEE format
fn convertLegacyToVibee(allocator: Allocator, source: []const u8) ![]const u8 {
    var buffer = std.ArrayListUnmanaged(u8){};
    defer buffer.deinit(allocator);
    try buffer.ensureTotalCapacity(allocator, 16384);

    const writer = buffer.writer(allocator);

    // Parsing state
    var name: []const u8 = "unknown";
    var version: []const u8 = "1.0.0";
    var description: []const u8 = "";
    var in_metadata = false;
    var in_types = false;
    var in_behaviors = false;
    var in_constants = false;
    var in_type_fields = false;

    // Current type/field being processed
    var current_type_name: []const u8 = "";
    var current_field_name: []const u8 = "";
    var current_field_type: []const u8 = "";
    var current_behavior_name: []const u8 = "";

    var lines = std.mem.splitScalar(u8, source, '\n');

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        if (trimmed[0] == '#') continue; // Skip comments

        const indent = countIndent(line);

        // Detect sections
        if (std.mem.eql(u8, trimmed, "metadata:")) {
            in_metadata = true;
            continue;
        }
        if (std.mem.eql(u8, trimmed, "types:")) {
            in_metadata = false; // Clear metadata flag
            in_types = true;
            try writer.writeAll("\ntypes:\n");
            continue;
        }
        if (std.mem.eql(u8, trimmed, "behaviors:")) {
            in_metadata = false;
            in_types = false;
            in_behaviors = true;
            in_type_fields = false;
            try writer.writeAll("\nbehaviors:\n");
            continue;
        }
        if (std.mem.eql(u8, trimmed, "constants:")) {
            in_metadata = false;
            in_types = false;
            in_constants = true;
            try writer.writeAll("\nconstants:\n");
            continue;
        }

        if (in_metadata) {
            if (std.mem.startsWith(u8, trimmed, "name:")) {
                name = extractValue(trimmed);
            } else if (std.mem.startsWith(u8, trimmed, "version:")) {
                version = extractValue(trimmed);
            } else if (std.mem.startsWith(u8, trimmed, "description:")) {
                description = extractValue(trimmed);
            }
        } else if (in_types) {
            // Type definition: "- name: TypeName"
            if (std.mem.startsWith(u8, trimmed, "- name:") and indent == 2) {
                // Flush any pending type
                if (current_type_name.len > 0) {
                    try writer.writeAll("\n");
                }
                // Extract type name: "- name: Model" -> "Model"
                const name_part = trimmed[8..]; // Skip "- name:"
                current_type_name = std.mem.trim(u8, name_part, " \t\r");
                try writer.print("  {s}:\n", .{current_type_name});
                in_type_fields = false;
            }
            // Type description
            else if (std.mem.startsWith(u8, trimmed, "description:") and indent == 4) {
                const desc = extractValue(trimmed);
                try writer.print("    description: {s}\n", .{desc});
            }
            // Fields section
            else if (std.mem.eql(u8, trimmed, "fields:") and indent == 4) {
                in_type_fields = true;
                try writer.writeAll("    fields:\n");
            }
            // Field definition: "- name: fieldName"
            else if (std.mem.startsWith(u8, trimmed, "- name:") and indent == 6) {
                // Flush any pending field
                if (current_field_name.len > 0 and current_field_type.len > 0) {
                    try writer.print("      {s}: {s}\n", .{ current_field_name, current_field_type });
                }
                // Extract field name: "- name: id" -> "id"
                const name_part = trimmed[8..]; // Skip "- name:"
                current_field_name = std.mem.trim(u8, name_part, " \t\r");
                current_field_type = "";
            }
            // Field type
            else if (std.mem.startsWith(u8, trimmed, "type:") and indent == 8) {
                current_field_type = extractValue(trimmed);
                if (current_field_name.len > 0) {
                    try writer.print("      {s}: {s}\n", .{ current_field_name, current_field_type });
                    // Reset for next field
                    current_field_name = "";
                    current_field_type = "";
                }
            }
            // Field description (inline)
            else if (std.mem.startsWith(u8, trimmed, "description:") and indent == 8) {
                // Skip description for now - field was already written
            }
            // Other field properties
            else if (indent == 8 and !std.mem.startsWith(u8, trimmed, "-")) {
                // Properties like required, default, etc. - skip for now
            }
        } else if (in_behaviors) {
            // Behavior: "- name: behaviorName"
            if (std.mem.startsWith(u8, trimmed, "- name:")) {
                // Extract behavior name: "- name: train" -> "train"
                const name_part = trimmed[8..]; // Skip "- name:"
                current_behavior_name = std.mem.trim(u8, name_part, " \t\r");
                try writer.print("  - name: {s}\n", .{current_behavior_name});
            }
            // given/when/then
            else if (std.mem.startsWith(u8, trimmed, "given:")) {
                const given = extractValue(trimmed);
                try writer.print("    given: {s}\n", .{given});
            } else if (std.mem.startsWith(u8, trimmed, "when:")) {
                const when = extractValue(trimmed);
                try writer.print("    when: {s}\n", .{when});
            } else if (std.mem.startsWith(u8, trimmed, "then:")) {
                const then_val = extractValue(trimmed);
                try writer.print("    then: {s}\n", .{then_val});
            }
        }
    }

    // Write header at beginning (we delayed it to get metadata first)
    var output_buffer = std.ArrayListUnmanaged(u8){};
    defer output_buffer.deinit(allocator);
    try output_buffer.ensureTotalCapacity(allocator, buffer.items.len + 256);

    const output_writer = output_buffer.writer(allocator);

    try output_writer.print("name: {s}\n", .{name});
    try output_writer.print("version: \"{s}\"\n", .{version});
    try output_writer.print("language: zig\n", .{});
    try output_writer.print("module: {s}\n", .{name});

    if (description.len > 0) {
        try output_writer.print("description: {s}\n", .{description});
    }

    try output_writer.writeAll(buffer.items);

    return output_buffer.toOwnedSlice(allocator);
}

/// Count leading spaces in a line
fn countIndent(line: []const u8) usize {
    var count: usize = 0;
    for (line) |c| {
        if (c == ' ') count += 1 else break;
    }
    return count;
}

/// Extract value from "key: value" line
fn extractValue(line: []const u8) []const u8 {
    if (std.mem.indexOf(u8, line, ":")) |colon_pos| {
        var result = line[colon_pos + 1 ..];
        result = std.mem.trim(u8, result, " \t\r");
        // Remove quotes if present
        if (result.len >= 2 and result[0] == '"' and result[result.len - 1] == '"') {
            result = result[1 .. result.len - 1];
        }
        return result;
    }
    return "";
}
