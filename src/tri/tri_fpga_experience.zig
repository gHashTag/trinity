// @origin(spec:tri_fpga_experience.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI FPGA EXPERIENCE — Hardware debugging experience log & blocker system
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri fpga experience              — list all experience entries
//   tri fpga experience add ...      — add a new entry
//   tri fpga experience search <q>   — keyword search in entries
//   tri fpga experience state        — show hardware state + blockers
//   tri fpga experience check <test> — check if test is blocked
//
// Storage:
//   .trinity/fpga/experience.json
//   .trinity/fpga/hardware_state.json
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";
const MAGENTA = "\x1b[35m";

const EXPERIENCE_PATH = ".trinity/fpga/experience.json";
const HARDWARE_STATE_PATH = ".trinity/fpga/hardware_state.json";

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runFpgaExperienceCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        return cmdList(allocator);
    }

    const sub = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, sub, "add")) {
        return cmdAdd(allocator, sub_args);
    } else if (std.mem.eql(u8, sub, "search")) {
        if (sub_args.len == 0) {
            print("{s}Usage:{s} tri fpga experience search <query>\n", .{ YELLOW, RESET });
            return;
        }
        return cmdSearch(allocator, sub_args[0]);
    } else if (std.mem.eql(u8, sub, "state")) {
        return cmdProbeState(allocator);
    } else if (std.mem.eql(u8, sub, "check")) {
        if (sub_args.len == 0) {
            print("{s}Usage:{s} tri fpga experience check <test_name>\n", .{ YELLOW, RESET });
            return;
        }
        return cmdCheckBlockers(allocator, sub_args[0]);
    } else {
        print("{s}Unknown subcommand:{s} {s}\n", .{ RED, RESET, sub });
        print("Usage: tri fpga experience [add|search|state|check]\n", .{});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdList(allocator: Allocator) !void {
    const data = readFile(allocator, EXPERIENCE_PATH) orelse {
        print("{s}No experience log found.{s} Create one with: tri fpga experience add ...\n", .{ DIM, RESET });
        return;
    };
    defer allocator.free(data);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, data, .{}) catch {
        print("{s}Error:{s} Failed to parse experience.json\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const entries = parsed.value.array.items;

    print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ BOLD, RESET });
    print("{s} FPGA EXPERIENCE LOG — {d} entries{s}\n", .{ BOLD, entries.len, RESET });
    print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ BOLD, RESET });

    for (entries) |entry| {
        printEntry(entry);
    }
}

fn cmdAdd(allocator: Allocator, args: []const []const u8) !void {
    // Parse --key value pairs
    var id: []const u8 = "";
    var category: []const u8 = "JTAG";
    var action: []const u8 = "";
    var result_str: []const u8 = "FAIL";
    var symptom: []const u8 = "";
    var root_cause: []const u8 = "";
    var lesson: []const u8 = "";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (i + 1 >= args.len) break;
        const val = args[i + 1];

        if (std.mem.eql(u8, arg, "--id")) {
            id = val;
            i += 1;
        } else if (std.mem.eql(u8, arg, "--category")) {
            category = val;
            i += 1;
        } else if (std.mem.eql(u8, arg, "--action")) {
            action = val;
            i += 1;
        } else if (std.mem.eql(u8, arg, "--result")) {
            result_str = val;
            i += 1;
        } else if (std.mem.eql(u8, arg, "--symptom")) {
            symptom = val;
            i += 1;
        } else if (std.mem.eql(u8, arg, "--root-cause")) {
            root_cause = val;
            i += 1;
        } else if (std.mem.eql(u8, arg, "--lesson")) {
            lesson = val;
            i += 1;
        }
    }

    if (id.len == 0 or action.len == 0) {
        print("{s}Required:{s} --id FPGA-NNN --action \"description\"\n", .{ RED, RESET });
        print("Optional: --category JTAG|UART|TOOLS|HARDWARE --result FAIL|SUCCESS|DIAGNOSED --lesson \"...\" --symptom \"...\" --root-cause \"...\"\n", .{});
        return;
    }

    // Read existing entries
    var entries_json = try std.ArrayList(u8).initCapacity(allocator, 1024);
    defer entries_json.deinit(allocator);

    const existing = readFile(allocator, EXPERIENCE_PATH);
    if (existing) |data| {
        defer allocator.free(data);
        // Find last ']' and replace with ','
        if (std.mem.lastIndexOfScalar(u8, data, ']')) |last_bracket| {
            // Check if there are existing entries (not just empty array)
            const trimmed = std.mem.trimRight(u8, data[0..last_bracket], " \n\r\t");
            try entries_json.appendSlice(allocator, trimmed);
            if (trimmed.len > 1) { // More than just '['
                try entries_json.appendSlice(allocator, ",\n  ");
            } else {
                try entries_json.appendSlice(allocator, "\n  ");
            }
        }
    } else {
        try entries_json.appendSlice(allocator, "[\n  ");
    }

    // Append new entry
    const writer = entries_json.writer(allocator);
    try writer.print(
        \\{{
        \\    "id": "{s}",
        \\    "date": "2026-03-14",
        \\    "category": "{s}",
        \\    "action": "{s}",
        \\    "result": "{s}",
        \\    "symptom": "{s}",
        \\    "root_cause": "{s}",
        \\    "lesson": "{s}",
        \\    "tags": [],
        \\    "data": {{}}
        \\  }}
    , .{ id, category, action, result_str, symptom, root_cause, lesson });
    try entries_json.appendSlice(allocator, "\n]\n");

    // Write back
    const cwd = std.fs.cwd();
    const file = cwd.createFile(EXPERIENCE_PATH, .{}) catch {
        print("{s}Error:{s} Cannot write {s}\n", .{ RED, RESET, EXPERIENCE_PATH });
        return;
    };
    defer file.close();
    file.writeAll(entries_json.items) catch {
        print("{s}Error:{s} Write failed\n", .{ RED, RESET });
        return;
    };

    print("{s}✓{s} Added {s}{s}{s} to experience log\n", .{ GREEN, RESET, BOLD, id, RESET });
}

fn cmdSearch(allocator: Allocator, query: []const u8) !void {
    const data = readFile(allocator, EXPERIENCE_PATH) orelse {
        print("{s}No experience log found.{s}\n", .{ DIM, RESET });
        return;
    };
    defer allocator.free(data);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, data, .{}) catch {
        print("{s}Error:{s} Failed to parse experience.json\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const entries = parsed.value.array.items;
    const query_lower = try std.ascii.allocLowerString(allocator, query);
    defer allocator.free(query_lower);

    var matches: u32 = 0;

    print("\n{s}Search: \"{s}\"{s}\n\n", .{ CYAN, query, RESET });

    for (entries) |entry| {
        if (entryMatchesQuery(allocator, entry, query_lower)) {
            printEntry(entry);
            matches += 1;
        }
    }

    if (matches == 0) {
        print("{s}No matches found for \"{s}\"{s}\n", .{ DIM, query, RESET });
    } else {
        print("{s}Found {d} matching entries{s}\n", .{ GREEN, matches, RESET });
    }
}

fn cmdProbeState(allocator: Allocator) !void {
    const data = readFile(allocator, HARDWARE_STATE_PATH) orelse {
        print("{s}No hardware state found.{s}\n", .{ DIM, RESET });
        return;
    };
    defer allocator.free(data);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, data, .{}) catch {
        print("{s}Error:{s} Failed to parse hardware_state.json\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const root = parsed.value.object;

    print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ BOLD, RESET });
    print("{s} FPGA HARDWARE STATE{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ BOLD, RESET });

    // Last probe
    if (root.get("last_probe")) |lp| {
        print("  {s}Last Probe:{s} {s}\n\n", .{ DIM, RESET, jsonStr(lp) });
    }

    // Cable
    if (root.get("cable")) |cable_val| {
        const cable = cable_val.object;
        print("  {s}CABLE{s}\n", .{ BOLD, RESET });
        print("  ├── Type:     {s}\n", .{jsonStr(cable.get("type") orelse .null)});
        print("  ├── FX2 FW:   {s}\n", .{jsonStr(cable.get("fx2_firmware") orelse .null)});
        const cpld_ver = jsonStr(cable.get("cpld_version") orelse .null);
        const cpld_healthy = if (cable.get("cpld_healthy")) |h| h.bool else false;
        if (cpld_healthy) {
            print("  ├── CPLD:     {s}{s} ✓{s}\n", .{ GREEN, cpld_ver, RESET });
        } else {
            print("  ├── CPLD:     {s}{s} ✗ DEAD{s}\n", .{ RED, cpld_ver, RESET });
        }
        print("  ├── TDI Path: {s}\n", .{jsonStr(cable.get("tdi_path") orelse .null)});
        const tdo = jsonStr(cable.get("tdo_path") orelse .null);
        if (std.mem.eql(u8, tdo, "DEAD")) {
            print("  └── TDO Path: {s}{s} ✗{s}\n", .{ RED, tdo, RESET });
        } else {
            print("  └── TDO Path: {s}{s} ✓{s}\n", .{ GREEN, tdo, RESET });
        }
    }

    // FPGA
    if (root.get("fpga")) |fpga_val| {
        const fpga_obj = fpga_val.object;
        print("\n  {s}FPGA{s}\n", .{ BOLD, RESET });
        print("  ├── Board:    {s}\n", .{jsonStr(fpga_obj.get("board") orelse .null)});
        print("  ├── IDCODE:   {s}\n", .{jsonStr(fpga_obj.get("expected_idcode") orelse .null)});
        print("  └── Bitstream:{s}\n", .{jsonStr(fpga_obj.get("last_bitstream") orelse .null)});
    }

    // UART
    if (root.get("uart")) |uart_val| {
        const uart = uart_val.object;
        print("\n  {s}UART{s}\n", .{ BOLD, RESET });
        print("  ├── Port:       {s}\n", .{jsonStr(uart.get("ftdi_port") orelse .null)});
        print("  ├── Connection: {s}\n", .{jsonStr(uart.get("connection") orelse .null)});
        print("  └── Echo Test:  {s}\n", .{jsonStr(uart.get("last_echo_test") orelse .null)});
    }

    // Blockers
    if (root.get("blockers")) |blockers_val| {
        const blockers = blockers_val.array.items;
        if (blockers.len > 0) {
            print("\n  {s}{s}BLOCKERS ({d}){s}\n", .{ RED, BOLD, blockers.len, RESET });
            for (blockers) |blocker| {
                const blk = blocker.object;
                const status = jsonStr(blk.get("status") orelse .null);
                const is_open = std.mem.eql(u8, status, "OPEN");
                print("  ├── {s}{s}{s} [{s}] {s}\n", .{
                    if (is_open) RED else GREEN,
                    jsonStr(blk.get("id") orelse .null),
                    RESET,
                    status,
                    jsonStr(blk.get("issue") orelse .null),
                });
                if (blk.get("affects")) |affects| {
                    print("  │   Affects: ", .{});
                    for (affects.array.items, 0..) |item, idx| {
                        if (idx > 0) print(", ", .{});
                        print("{s}", .{jsonStr(item)});
                    }
                    print("\n", .{});
                }
            }
        }
    }

    print("\n", .{});
}

fn cmdCheckBlockers(allocator: Allocator, test_name: []const u8) !void {
    const data = readFile(allocator, HARDWARE_STATE_PATH) orelse {
        print("{s}OK{s} — No hardware state file, no known blockers\n", .{ GREEN, RESET });
        return;
    };
    defer allocator.free(data);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, data, .{}) catch {
        print("{s}OK{s} — Cannot parse state, assuming no blockers\n", .{ GREEN, RESET });
        return;
    };
    defer parsed.deinit();

    const root = parsed.value.object;
    const test_lower = std.ascii.allocLowerString(allocator, test_name) catch {
        print("{s}OK{s} — No blockers (alloc error)\n", .{ GREEN, RESET });
        return;
    };
    defer allocator.free(test_lower);

    if (root.get("blockers")) |blockers_val| {
        for (blockers_val.array.items) |blocker| {
            const blk = blocker.object;
            const status = jsonStr(blk.get("status") orelse .null);
            if (!std.mem.eql(u8, status, "OPEN")) continue;

            // Check "affects" array
            if (blk.get("affects")) |affects| {
                for (affects.array.items) |item| {
                    const affected = jsonStr(item);
                    const affected_lower = std.ascii.allocLowerString(allocator, affected) catch continue;
                    defer allocator.free(affected_lower);

                    if (std.mem.eql(u8, affected_lower, test_lower)) {
                        print("{s}BLOCKED{s} — Test \"{s}\" is blocked by {s}: {s}\n", .{
                            RED,
                            RESET,
                            test_name,
                            jsonStr(blk.get("id") orelse .null),
                            jsonStr(blk.get("issue") orelse .null),
                        });
                        return;
                    }
                }
            }

            // Check "does_not_affect" — if listed there, it's OK
            if (blk.get("does_not_affect")) |dna| {
                for (dna.array.items) |item| {
                    const safe = jsonStr(item);
                    const safe_lower = std.ascii.allocLowerString(allocator, safe) catch continue;
                    defer allocator.free(safe_lower);

                    if (std.mem.eql(u8, safe_lower, test_lower)) {
                        print("{s}OK{s} — Test \"{s}\" is explicitly unaffected by {s}\n", .{
                            GREEN,
                            RESET,
                            test_name,
                            jsonStr(blk.get("id") orelse .null),
                        });
                        return;
                    }
                }
            }
        }
    }

    print("{s}OK{s} — No blockers for test \"{s}\"\n", .{ GREEN, RESET, test_name });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn readFile(allocator: Allocator, path: []const u8) ?[]u8 {
    const cwd = std.fs.cwd();
    const file = cwd.openFile(path, .{}) catch return null;
    defer file.close();
    return file.readToEndAlloc(allocator, 1024 * 1024) catch null;
}

fn jsonStr(val: std.json.Value) []const u8 {
    return switch (val) {
        .string => |s| s,
        else => "?",
    };
}

fn printEntry(entry: std.json.Value) void {
    const obj = entry.object;

    const id = jsonStr(obj.get("id") orelse .null);
    const category = jsonStr(obj.get("category") orelse .null);
    const action = jsonStr(obj.get("action") orelse .null);
    const result_str = jsonStr(obj.get("result") orelse .null);
    const lesson = jsonStr(obj.get("lesson") orelse .null);
    const symptom = jsonStr(obj.get("symptom") orelse .null);

    // Color based on result
    const result_color = if (std.mem.eql(u8, result_str, "SUCCESS"))
        GREEN
    else if (std.mem.eql(u8, result_str, "FAIL"))
        RED
    else if (std.mem.eql(u8, result_str, "DIAGNOSED"))
        YELLOW
    else if (std.mem.eql(u8, result_str, "BLOCKED"))
        RED
    else if (std.mem.eql(u8, result_str, "PENDING"))
        MAGENTA
    else
        DIM;

    print("  {s}{s}{s} [{s}] {s}{s}{s}\n", .{ CYAN, id, RESET, category, result_color, result_str, RESET });
    print("    Action:  {s}\n", .{action});
    if (symptom.len > 1) print("    Symptom: {s}{s}{s}\n", .{ DIM, symptom, RESET });
    if (lesson.len > 1) print("    Lesson:  {s}{s}{s}\n", .{ GREEN, lesson, RESET });
    print("\n", .{});
}

fn entryMatchesQuery(allocator: Allocator, entry: std.json.Value, query_lower: []const u8) bool {
    const fields = [_][]const u8{ "id", "action", "symptom", "root_cause", "lesson", "category" };

    for (fields) |field| {
        if (entry.object.get(field)) |val| {
            const s = jsonStr(val);
            const s_lower = std.ascii.allocLowerString(allocator, s) catch continue;
            defer allocator.free(s_lower);
            if (std.mem.indexOf(u8, s_lower, query_lower) != null) return true;
        }
    }

    // Check tags array
    if (entry.object.get("tags")) |tags| {
        for (tags.array.items) |tag| {
            const t = jsonStr(tag);
            const t_lower = std.ascii.allocLowerString(allocator, t) catch continue;
            defer allocator.free(t_lower);
            if (std.mem.indexOf(u8, t_lower, query_lower) != null) return true;
        }
    }

    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "jsonStr returns string value" {
    const val = std.json.Value{ .string = "hello" };
    try std.testing.expectEqualStrings("hello", jsonStr(val));
}

test "jsonStr returns ? for non-string" {
    const val = std.json.Value{ .null = {} };
    try std.testing.expectEqualStrings("?", jsonStr(val));
}
