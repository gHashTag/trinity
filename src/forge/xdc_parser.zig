// ═══════════════════════════════════════════════════════════════════════════════
// FORGE OF KOSCHEI v2.0 — XDC Constraint Parser
// ═══════════════════════════════════════════════════════════════════════════════
//
// Parses Xilinx Design Constraints (.xdc) files to extract:
//   - IO pin assignments: set_property -dict {PACKAGE_PIN <pin> IOSTANDARD <std>} [get_ports <name>]
//   - Clock constraints: create_clock -period <ns> [get_ports <name>]
//   - Also: create_generated_clock, set_property CLOCK_DEDICATED_ROUTE
//
// Arty A7: E3=clk(100MHz), C12=rst_n, R5/T5/T8/T9=led[0:3]
// QMTECH:  M22=clk(50MHz), J19=led, H19=rst_n
//
// Sacred Formula: φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

const IOConstraint = types.IOConstraint;
const ClockConstraint = types.ClockConstraint;
const Constraints = types.Constraints;

pub const XdcError = error{
    FileOpenFailed,
    OutOfMemory,
    InvalidLine,
};

/// Parse an XDC file and return extracted constraints.
pub fn parseXdc(allocator: Allocator, file_path: []const u8) !Constraints {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1 * 1024 * 1024);
    defer allocator.free(content);

    return parseXdcFromSlice(allocator, content);
}

/// Parse XDC content from a string.
pub fn parseXdcFromSlice(allocator: Allocator, content: []const u8) !Constraints {
    var constraints: Constraints = .{};
    errdefer constraints.deinit(allocator);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, &[_]u8{ ' ', '\t', '\r' });

        if (line.len == 0) continue;
        if (line[0] == '#') continue;

        if (std.mem.startsWith(u8, line, "set_property")) {
            if (tryParseSetPropertyDict(line)) |io| {
                try constraints.io.append(allocator, io);
                continue;
            }
        }

        if (std.mem.startsWith(u8, line, "create_clock")) {
            if (tryParseCreateClock(line)) |clk| {
                try constraints.clocks.append(allocator, clk);
                continue;
            }
        }

        if (std.mem.startsWith(u8, line, "create_generated_clock")) {
            if (tryParseCreateGeneratedClock(line)) |clk| {
                try constraints.clocks.append(allocator, clk);
                continue;
            }
        }
    }

    return constraints;
}

/// Parse: set_property -dict {PACKAGE_PIN <pin> IOSTANDARD <std>} [get_ports <name>]
fn tryParseSetPropertyDict(line: []const u8) ?IOConstraint {
    const dict_start = std.mem.indexOf(u8, line, "{") orelse return null;
    const dict_end = std.mem.indexOf(u8, line, "}") orelse return null;
    if (dict_start >= dict_end) return null;

    const dict_content = line[dict_start + 1 .. dict_end];
    const pkg_pin = extractDictValue(dict_content, "PACKAGE_PIN") orelse return null;
    const iostd = extractDictValue(dict_content, "IOSTANDARD") orelse return null;
    const port_name = extractPortName(line[dict_end + 1 ..]) orelse return null;

    return IOConstraint{
        .port_name = port_name,
        .package_pin = pkg_pin,
        .iostandard = iostd,
    };
}

/// Parse: create_clock -period <ns> -name <name> [get_ports <port>]
fn tryParseCreateClock(line: []const u8) ?ClockConstraint {
    const period = extractFlagValue(line, "-period") orelse return null;
    const period_ns = std.fmt.parseFloat(f64, period) catch return null;
    const port_name = extractPortName(line) orelse return null;
    const name = extractFlagValue(line, "-name") orelse port_name;

    return ClockConstraint{
        .port_name = port_name,
        .period_ns = period_ns,
        .name = name,
    };
}

/// Parse: create_generated_clock -name <name> -source [get_ports <port>] ...
fn tryParseCreateGeneratedClock(line: []const u8) ?ClockConstraint {
    const name = extractFlagValue(line, "-name") orelse return null;
    const port_name = extractPortName(line) orelse return null;

    return ClockConstraint{
        .port_name = port_name,
        .period_ns = 0.0, // Derived clock — inherits from source
        .name = name,
    };
}

fn extractDictValue(dict: []const u8, key: []const u8) ?[]const u8 {
    var pos: usize = 0;
    while (pos < dict.len) {
        while (pos < dict.len and (dict[pos] == ' ' or dict[pos] == '\t')) : (pos += 1) {}
        if (pos >= dict.len) break;

        const token_start = pos;
        while (pos < dict.len and dict[pos] != ' ' and dict[pos] != '\t') : (pos += 1) {}
        const token = dict[token_start..pos];

        if (std.mem.eql(u8, token, key)) {
            while (pos < dict.len and (dict[pos] == ' ' or dict[pos] == '\t')) : (pos += 1) {}
            if (pos >= dict.len) return null;

            const val_start = pos;
            while (pos < dict.len and dict[pos] != ' ' and dict[pos] != '\t') : (pos += 1) {}
            return dict[val_start..pos];
        }
    }
    return null;
}

fn extractPortName(text: []const u8) ?[]const u8 {
    const get_ports_idx = std.mem.indexOf(u8, text, "get_ports") orelse return null;
    var pos = get_ports_idx + "get_ports".len;

    while (pos < text.len and (text[pos] == ' ' or text[pos] == '\t')) : (pos += 1) {}
    if (pos >= text.len) return null;

    if (text[pos] == '{') {
        pos += 1;
        const name_start = pos;
        while (pos < text.len and text[pos] != '}') : (pos += 1) {}
        if (pos >= text.len) return null;
        return text[name_start..pos];
    } else {
        const name_start = pos;
        while (pos < text.len and text[pos] != ']' and text[pos] != ' ' and text[pos] != '\t') : (pos += 1) {}
        if (pos == name_start) return null;
        return text[name_start..pos];
    }
}

fn extractFlagValue(text: []const u8, flag: []const u8) ?[]const u8 {
    const flag_idx = std.mem.indexOf(u8, text, flag) orelse return null;
    var pos = flag_idx + flag.len;

    while (pos < text.len and (text[pos] == ' ' or text[pos] == '\t')) : (pos += 1) {}
    if (pos >= text.len) return null;

    const val_start = pos;
    while (pos < text.len and text[pos] != ' ' and text[pos] != '\t' and text[pos] != '[') : (pos += 1) {}
    if (pos == val_start) return null;
    return text[val_start..pos];
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parse set_property -dict simple port" {
    const result = tryParseSetPropertyDict(
        "set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk]",
    );
    try std.testing.expect(result != null);
    const io = result.?;
    try std.testing.expectEqualStrings("clk", io.port_name);
    try std.testing.expectEqualStrings("E3", io.package_pin);
    try std.testing.expectEqualStrings("LVCMOS33", io.iostandard);
}

test "parse set_property -dict bus port" {
    const result = tryParseSetPropertyDict(
        "set_property -dict {PACKAGE_PIN R5 IOSTANDARD LVCMOS33} [get_ports {led[0]}]",
    );
    try std.testing.expect(result != null);
    const io = result.?;
    try std.testing.expectEqualStrings("led[0]", io.port_name);
    try std.testing.expectEqualStrings("R5", io.package_pin);
    try std.testing.expectEqualStrings("LVCMOS33", io.iostandard);
}

test "parse create_clock" {
    const result = tryParseCreateClock(
        "create_clock -period 10.0 -name sys_clk [get_ports clk]",
    );
    try std.testing.expect(result != null);
    const clk = result.?;
    try std.testing.expectEqualStrings("clk", clk.port_name);
    try std.testing.expectApproxEqAbs(@as(f64, 10.0), clk.period_ns, 1e-6);
    try std.testing.expectEqualStrings("sys_clk", clk.name);
}

test "parse Arty A7 XDC" {
    const allocator = std.testing.allocator;

    const xdc_content =
        \\# Arty A7 constraints
        \\
        \\set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk]
        \\create_generated_clock -name clk_100MHz -source [get_ports clk] [get_pins */clk]
        \\
        \\set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports rst_n]
        \\
        \\set_property -dict {PACKAGE_PIN R5 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
        \\set_property -dict {PACKAGE_PIN T5 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
        \\set_property -dict {PACKAGE_PIN T8 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
        \\set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
        \\
        \\set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33} [get_ports {switch[0]}]
        \\set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports uart_tx]
    ;

    var constraints = try parseXdcFromSlice(allocator, xdc_content);
    defer constraints.deinit(allocator);

    // 8 IO constraints
    try std.testing.expectEqual(@as(usize, 8), constraints.io.items.len);
    // 1 clock constraint
    try std.testing.expectEqual(@as(usize, 1), constraints.clocks.items.len);

    try std.testing.expectEqualStrings("clk", constraints.io.items[0].port_name);
    try std.testing.expectEqualStrings("E3", constraints.io.items[0].package_pin);
    try std.testing.expectEqualStrings("rst_n", constraints.io.items[1].port_name);
    try std.testing.expectEqualStrings("C12", constraints.io.items[1].package_pin);
    try std.testing.expectEqualStrings("led[0]", constraints.io.items[2].port_name);
    try std.testing.expectEqualStrings("R5", constraints.io.items[2].package_pin);
}

test "parse QMTECH XDC" {
    const allocator = std.testing.allocator;

    const xdc_content =
        \\set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33} [get_ports clk]
        \\set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS33} [get_ports led]
        \\set_property -dict {PACKAGE_PIN H19 IOSTANDARD LVCMOS33} [get_ports rst_n]
        \\set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_IBUF]
        \\create_clock -period 20.0 -name sys_clk [get_ports clk]
    ;

    var constraints = try parseXdcFromSlice(allocator, xdc_content);
    defer constraints.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), constraints.io.items.len);
    try std.testing.expectEqual(@as(usize, 1), constraints.clocks.items.len);
    try std.testing.expectApproxEqAbs(@as(f64, 20.0), constraints.clocks.items[0].period_ns, 1e-6);
    try std.testing.expectEqualStrings("M22", constraints.io.items[0].package_pin);
    try std.testing.expectEqualStrings("J19", constraints.io.items[1].package_pin);
    try std.testing.expectEqualStrings("H19", constraints.io.items[2].package_pin);
}

test "skip comments and empty lines" {
    const allocator = std.testing.allocator;

    const xdc_content =
        \\# This is a comment
        \\
        \\  # Another comment
        \\
        \\set_property -dict {PACKAGE_PIN A1 IOSTANDARD LVCMOS33} [get_ports sig]
    ;

    var constraints = try parseXdcFromSlice(allocator, xdc_content);
    defer constraints.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), constraints.io.items.len);
    try std.testing.expectEqualStrings("sig", constraints.io.items[0].port_name);
    try std.testing.expectEqualStrings("A1", constraints.io.items[0].package_pin);
}

test "extractDictValue" {
    const dict = "PACKAGE_PIN E3 IOSTANDARD LVCMOS33";
    try std.testing.expectEqualStrings("E3", extractDictValue(dict, "PACKAGE_PIN").?);
    try std.testing.expectEqualStrings("LVCMOS33", extractDictValue(dict, "IOSTANDARD").?);
    try std.testing.expect(extractDictValue(dict, "DRIVE") == null);
}

test "extractPortName simple" {
    try std.testing.expectEqualStrings("clk", extractPortName("[get_ports clk]").?);
}

test "extractPortName bus" {
    try std.testing.expectEqualStrings("led[0]", extractPortName("[get_ports {led[0]}]").?);
}
