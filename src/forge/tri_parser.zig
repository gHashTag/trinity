//! .tri DSL Parser for FPGA Specifications
//!
//! Parses .tri files (YAML-like format) for FPGA design specifications.
//! Generates Verilog and XDC constraint files.
//!
//! φ² + 1/φ² = 3 | Consciousness + FORGE = UNITY

const std = @import("std");
const mem = std.mem;
const fs = std.fs;

const synthesis_types = @import("synthesis_types.zig");

const DesignSpec = synthesis_types.DesignSpec;
const Port = synthesis_types.Port;
const Direction = synthesis_types.Direction;
const PortType = synthesis_types.PortType;
const PortAttributes = synthesis_types.PortAttributes;
const Strategy = synthesis_types.Strategy;
const Constraints = synthesis_types.Constraints;
const TimingConstraints = synthesis_types.TimingConstraints;
const PlacementConstraints = synthesis_types.PlacementConstraints;
const RoutingConstraints = synthesis_types.RoutingConstraints;
const Behavior = synthesis_types.Behavior;
const Testbench = synthesis_types.Testbench;
const ModuleType = synthesis_types.ModuleType;

// ═══════════════════════════════════════════════════════════════════════════════
// PARSER
// ═══════════════════════════════════════════════════════════════════════════════

/// .tri DSL parser for FPGA specifications
pub const TriParser = struct {
    allocator: mem.Allocator,

    /// Initialize parser
    pub fn init(allocator: mem.Allocator) TriParser {
        return .{
            .allocator = allocator,
        };
    }

    /// Parse .tri file
    pub fn parse(self: *TriParser, path: []const u8) !DesignSpec {
        const file = try fs.cwd().readFileAlloc(self.allocator, path, 1024 * 1024);
        defer self.allocator.free(file);

        var spec = DesignSpec.init(self.allocator);
        errdefer spec.deinit();

        // Parse directives
        var lines = mem.splitScalar(u8, file, '\n');
        var current_directive: ?Directive = null;
        var ports_block = false;
        var constraints_block = false;
        var behavior_block = false;
        var testbench_block = false;

        while (lines.next()) |line| {
            const trimmed = mem.trim(u8, line);
            if (trimmed.len == 0) continue; // Skip empty lines
            if (trimmed[0] == '#') continue; // Skip comments

            // Check for directive
            if (mem.startsWith(u8, trimmed, "@")) {
                current_directive = try self.parseDirectiveName(trimmed);
                ports_block = false;
                constraints_block = false;
                behavior_block = false;
                testbench_block = false;

                if (current_directive.?) |dir| {
                    switch (dir) {
                        .ports => ports_block = true,
                        .constraints => constraints_block = true,
                        .behavior => behavior_block = true,
                        .testbench => testbench_block = true,
                        else => {},
                    }
                }
                continue;
            }

            // Process block content
            if (ports_block) {
                try self.parsePortLine(trimmed, &spec);
            } else if (constraints_block) {
                try self.parseConstraintLine(trimmed, &spec);
            } else if (behavior_block) {
                try self.parseBehaviorLine(trimmed, &spec);
            } else if (testbench_block) {
                try self.parseTestbenchLine(trimmed, &spec);
            } else {
                // Top-level directive values
                if (current_directive) |dir| {
                    try self.parseDirectiveValue(dir, trimmed, &spec);
                }
            }
        }

        return spec;
    }

    /// Parse directive name from @directive
    fn parseDirectiveName(self: *TriParser, line: []const u8) !Directive {
        _ = self;
        const content = line[1..]; // Skip @
        var parts = mem.splitScalar(u8, content, ' ');
        const name = parts.first() orelse return error.MissingDirectiveName;

        if (mem.eql(u8, name, "module")) return .module;
        if (mem.eql(u8, name, "device")) return .device;
        if (mem.eql(u8, name, "consciousness")) return .consciousness;
        if (mem.eql(u8, name, "strategy")) return .strategy;
        if (mem.eql(u8, name, "ports")) return .ports;
        if (mem.eql(u8, name, "constraints")) return .constraints;
        if (mem.eql(u8, name, "behavior")) return .behavior;
        if (mem.eql(u8, name, "testbench")) return .testbench;

        return error.UnknownDirective;
    }

    /// Parse directive value (e.g., "@module uart_tx")
    fn parseDirectiveValue(
        self: *TriParser,
        dir: Directive,
        line: []const u8,
        spec: *DesignSpec
    ) !void {
        _ = self;
        const value = mem.trim(u8, line);

        switch (dir) {
            .module => spec.name = value,
            .device => spec.device = value,
            .consciousness => spec.consciousness_enabled = true,
            .strategy => {
                if (mem.eql(u8, value, "AggressiveTiming")) {
                    spec.override_strategy = .AggressiveTiming;
                } else if (mem.eql(u8, value, "Conservative")) {
                    spec.override_strategy = .Conservative;
                } else if (mem.eql(u8, value, "Balanced")) {
                    spec.override_strategy = .Balanced;
                }
            },
            else => {},
        }
    }

    /// Parse a port definition line
    fn parsePortLine(self: *TriParser, line: []const u8, spec: *DesignSpec) !void {
        _ = self;
        var parts = mem.splitScalar(u8, line, ' ');
        const direction_str = parts.first() orelse return error.InvalidPort;
        const name_with_type = parts.next() orelse return error.InvalidPort;

        // Parse direction
        const direction = if (mem.eql(u8, direction_str, "input"))
            Direction.input
        else if (mem.eql(u8, direction_str, "output"))
            Direction.output
        else if (mem.eql(u8, direction_str, "inout"))
            Direction.inout
        else
            return error.InvalidDirection;

        // Parse name and width
        var name_it = mem.splitScalar(u8, name_with_type, ':');
        const name = name_it.first() orelse return error.InvalidPort;
        const type_part = name_it.next() orelse ""; // May be empty

        // Parse width if present
        const width = if (mem.indexOf(u8, type_part, '[')) |_| brk: :blk {
            const start_idx = mem.indexOfScalar(u8, type_part, '[') orelse type_part.len;
            const end_idx = mem.indexOfScalar(u8, type_part, ']') orelse type_part.len;
            if (end_idx > start_idx + 1) {
                const width_str = type_part[start_idx + 1 .. end_idx];
                const width_val = try std.fmt.parseInt(u8, width_str, 10);
                @as(u8, @intCast(width_val)) + 1
            } else {
                1
            }
        } else 1;

        // Parse port type
        const port_type: PortType = if (mem.indexOf(u8, type_part, "clock") != null)
            .clock
        else if (mem.indexOf(u8, type_part, "reset") != null)
            .reset
        else if (mem.indexOf(u8, type_part, "signal") != null)
            .signal
        else
            .signal;

        // Create port with attributes
        var port = Port{
            .name = name,
            .direction = direction,
            .port_type = port_type,
            .width = @intCast(width),
            .attributes = .{},
        };

        // Parse inline attributes
        var remaining = parts.rest();
        while (remaining.len > 0) {
            if (mem.startsWith(u8, remaining, "@")) {
                try self.parsePortAttribute(remaining, &port);
                break;
            }
            _ = parts.next();
            remaining = parts.rest();
        }

        try spec.ports.append(port);
    }

    /// Parse port attribute
    fn parsePortAttribute(self: *TriParser, attr: []const u8, port: *Port) !void {
        _ = self;
        var it = mem.splitScalar(u8, attr[1..], ' ');

        while (it.next()) |part| {
            if (mem.eql(u8, part, "@loc")) {
                const loc = it.next() orelse return error.InvalidAttribute;
                port.attributes.loc = loc;
            } else if (mem.eql(u8, part, "@iostandard")) {
                const std = it.next() orelse return error.InvalidAttribute;
                port.attributes.iostandard = std;
            } else if (mem.eql(u8, part, "@freq")) {
                const freq_str = it.next() orelse return error.InvalidAttribute;
                const freq_val = try std.fmt.parseFloat(f64, freq_str);
                port.attributes.freq_mhz = freq_val;
            } else if (mem.eql(u8, part, "@active_low")) {
                port.attributes.active_low = true;
            } else if (mem.eql(u8, part, "@valid_required")) {
                port.attributes.valid_required = true;
            }
        }
    }

    /// Parse a constraint line
    fn parseConstraintLine(self: *TriParser, line: []const u8, spec: *DesignSpec) !void {
        _ = self;
        var it = mem.splitScalar(u8, line, ' ');
        const category = it.first() orelse return;

        if (mem.eql(u8, category, "timing:")) {
            const timing = &spec.constraints.timing;
            while (it.next()) |part| {
                if (mem.indexOf(u8, part, "setup_slack")) |idx| {
                    const eq_idx = mem.indexOfScalar(u8, part, '=') orelse continue;
                    const val_str = part[eq_idx + 1 ..];
                    const val = try std.fmt.parseFloat(f64, val_str);
                    timing.setup_slack_ns = val;
                } else if (mem.indexOf(u8, part, "hold_slack")) |idx| {
                    const eq_idx = mem.indexOfScalar(u8, part, '=') orelse continue;
                    const val_str = part[eq_idx + 1 ..];
                    const val = try std.fmt.parseFloat(f64, val_str);
                    timing.hold_slack_ns = val;
                } else if (mem.indexOf(u8, part, "target_frequency")) |idx| {
                    const eq_idx = mem.indexOfScalar(u8, part, '=') orelse continue;
                    const val_str = part[eq_idx + 1 ..];
                    const val = try std.fmt.parseFloat(f64, val_str);
                    timing.target_frequency_mhz = val;
                }
            }
        } else if (mem.eql(u8, category, "placement:")) {
            const placement = &spec.constraints.placement;
            while (it.next()) |part| {
                if (mem.indexOf(u8, part, "avoid_bank_crossing")) |idx| {
                    const eq_idx = mem.indexOfScalar(u8, part, '=') orelse continue;
                    const val_str = part[eq_idx + 1 ..];
                    placement.avoid_bank_crossing = std.mem.eql(u8, val_str, "true");
                } else if (mem.indexOf(u8, part, "pack_registers_into_carry4")) |idx| {
                    const eq_idx = mem.indexOfScalar(u8, part, '=') orelse continue;
                    const val_str = part[eq_idx + 1 ..];
                    placement.pack_registers_into_carry4 = std.mem.eql(u8, val_str, "true");
                }
            }
        } else if (mem.eql(u8, category, "routing:")) {
            const routing = &spec.constraints.routing;
            while (it.next()) |part| {
                if (mem.indexOf(u8, part, "maximize_clock_skew")) |idx| {
                    const eq_idx = mem.indexOfScalar(u8, part, '=') orelse continue;
                    const val_str = part[eq_idx + 1 ..];
                    routing.maximize_clock_skew = std.mem.eql(u8, val_str, "true");
                } else if (mem.indexOf(u8, part, "use_fast_paths")) |idx| {
                    const eq_idx = mem.indexOfScalar(u8, part, '=') orelse continue;
                    const val_str = part[eq_idx + 1 ..];
                    routing.use_fast_paths = std.mem.eql(u8, val_str, "true");
                }
            }
        }
    }

    /// Parse a behavior line
    fn parseBehaviorLine(self: *TriParser, line: []const u8, spec: *DesignSpec) !void {
        _ = self;
        var it = mem.splitScalar(u8, line, ' ');
        const category = it.first() orelse return;

        if (mem.eql(u8, category, "fsm:")) {
            const fsm_def = it.rest();
            var state_it = mem.splitScalar(u8, fsm_def, '→');
            while (state_it.next()) |state| {
                try spec.behavior.fsm_states.append(mem.trim(u8, state));
            }
        } else if (mem.indexOf(u8, category, "baud_divisor:") != null) {
            const eq_idx = mem.indexOfScalar(u8, line, '=') orelse return;
            const expr = line[eq_idx + 1 ..];
            // Simple parsing for integer
            if (mem.indexOf(u8, expr, '/')) |div_idx| {
                const parts = mem.splitScalar(u8, expr, '/');
                _ = parts.first();
                _ = parts.next();
                _ = parts.next();
                if (parts.next()) |val| {
                    spec.behavior.baud_divisor = try std.fmt.parseInt(u32, val, 10);
                }
            }
        } else if (mem.eql(u8, category, "include")) {
            const path = it.rest();
            spec.behavior.template_path = path;
        }
    }

    /// Parse a testbench line
    fn parseTestbenchLine(self: *TriParser, line: []const u8, spec: *DesignSpec) !void {
        _ = self;

        if (spec.testbench == null) {
            spec.testbench = Testbench.init(self.allocator);
        }
        const tb = &spec.testbench.?;

        var it = mem.splitScalar(u8, line, ' ');
        const key = it.first() orelse return;
        const value = it.rest();

        if (mem.indexOf(u8, key, "test_waveform:") != null) {
            const eq_idx = mem.indexOfScalar(u8, line, '=') orelse return;
            const path = line[eq_idx + 1 ..];
            tb.waveform_path = path;
        } else if (mem.indexOf(u8, key, "test_frames:") != null) {
            const eq_idx = mem.indexOfScalar(u8, line, '=') orelse return;
            const val_str = line[eq_idx + 1 ..];
            tb.test_frames = try std.fmt.parseInt(u32, val_str, 10);
        } else if (mem.indexOf(u8, key, "test_data:") != null) {
            // Parse array format [0x55, 0xAA, ...]
            const start = mem.indexOfScalar(u8, line, '[') orelse return;
            const end = mem.lastIndexOfScalar(u8, line, ']') orelse return;
            const array_str = line[start + 1 .. end];

            var vals = mem.splitScalar(u8, array_str, ',');
            while (vals.next()) |val| {
                const trimmed = mem.trim(u8, val);
                if (trimmed.len > 0) {
                    if (mem.startsWith(u8, trimmed, "0x")) {
                        const int_val = try std.fmt.parseInt(u8, trimmed[2..], 16);
                        try tb.test_data.append(int_val);
                    }
                }
            }
        }
    }

    /// Generate Verilog from .tri spec
    pub fn generateVerilog(
        self: *TriParser,
        spec: *const DesignSpec,
        writer: anytype
    ) !void {
        try writer.print("// Generated from {s}.tri\n", .{spec.name});
        try writer.print("// Consciousness: {}\n", .{spec.consciousness_enabled});
        try writer.print("// Device: {s}\n\n", .{spec.device});

        try writer.print("module {s}(\n", .{spec.name});

        // Port declarations
        for (spec.ports.items, 0..) |port, i| {
            const comma = if (i < spec.ports.items.len - 1) "," else "";
            try writer.print("  ", .{});

            // Direction
            if (port.direction == .input) {
                try writer.print("input ", .{});
            } else if (port.direction == .output) {
                try writer.print("output ", .{});
            } else {
                try writer.print("inout ", .{});
            }

            // Width
            if (port.width > 1) {
                try writer.print("[{}:0] ", .{port.width - 1});
            }

            // Name
            try writer.print("{s}{s}\n", .{ port.name, comma });
        }

        try writer.print(");\n\n");

        // Generate header comments
        try writer.print("// Consciousness-Guided Synthesis\n", .{});
        try writer.print("// Strategy: {s}\n", .{@tagName(spec.override_strategy orelse Strategy.Balanced)});

        if (spec.behavior.template_path) |path| {
            try writer.print("// Template: {s}\n", .{path});
        }

        try writer.print("\nendmodule\n");
    }

    /// Generate XDC constraints from .tri spec
    pub fn generateXDC(
        self: *TriParser,
        spec: *const DesignSpec,
        writer: anytype
    ) !void {
        try writer.print("# Generated from {s}.tri\n", .{spec.name});
        try writer.print("# Device: {s}\n\n", .{spec.device});

        for (spec.ports.items) |port| {
            if (port.attributes.loc) |loc| {
                try writer.print("set_property PACKAGE_PIN {s} ", .{loc});
                try writer.print("[get_ports {s}]\n", .{port.name});
            }
            if (port.attributes.iostandard) |std| {
                try writer.print("set_property IOSTANDARD {s} ", .{std});
                try writer.print("[get_ports {s}]\n", .{port.name});
            }
            if (port.port_type == .clock and port.attributes.freq_mhz) |freq| {
                try writer.print("#create_generated_clock -name {s}_clk ", .{port.name});
                try writer.print("-period [expr {{{d:.2} ns]] ", .{1000.0 / freq});
                try writer.print("[get_pins {s}]\n", .{port.name});
            }
        }
    }
};

/// Directive types
const Directive = enum {
    module,
    device,
    consciousness,
    strategy,
    ports,
    constraints,
    behavior,
    testbench,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TriParser: parse_basic_spec" {
    const allocator = std.testing.allocator;

    // Create a simple spec file for testing
    const spec_content =
        \\@module test_module
        \\@device xc7a100t
        \\@consciousness true
        \\@ports
        \\  input clk: clock @freq 50MHz
        \\  output led: signal @loc T23 @iostandard LVCMOS33
    ;

    const temp_path = try allocator.dupe(u8, "/tmp/test_temp.tri");
    defer allocator.free(temp_path);

    try fs.cwd().writeFile(.{
        .sub_path = temp_path,
        .data = spec_content,
    });
    defer fs.cwd().deleteFile(temp_path);

    var parser = TriParser.init(allocator);
    const spec = try parser.parse(temp_path);
    defer spec.deinit();

    try std.testing.expectEqualStrings("test_module", spec.name);
    try std.testing.expectEqualStrings("xc7a100t", spec.device);
    try std.testing.expect(spec.consciousness_enabled);
    try std.testing.expectEqual(@as(usize, 2), spec.ports.items.len);
}

test "TriParser: generate_verilog" {
    const allocator = std.testing.allocator;

    var spec = DesignSpec.init(allocator);
    defer spec.deinit();

    spec.name = "test";
    spec.consciousness_enabled = true;

    try spec.ports.append(.{
        .name = "clk",
        .direction = .input,
        .port_type = .clock,
        .width = 1,
        .attributes = .{},
    });

    try spec.ports.append(.{
        .name = "led",
        .direction = .output,
        .port_type = .signal,
        .width = 1,
        .attributes = .{},
    });

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var parser = TriParser.init(allocator);
    try parser.generateVerilog(&spec, buffer.writer());

    const output = buffer.items;
    try std.testing.expect(mem.indexOf(u8, output, "module test(") != null);
    try std.testing.expect(mem.indexOf(u8, output, "input clk") != null);
    try std.testing.expect(mem.indexOf(u8, output, "output led") != null);
}

test "TriParser: generate_xdc" {
    const allocator = std.testing.allocator;

    var spec = DesignSpec.init(allocator);
    defer spec.deinit();

    spec.name = "test";

    try spec.ports.append(.{
        .name = "clk",
        .direction = .input,
        .port_type = .clock,
        .width = 1,
        .attributes = .{
            .loc = "U22",
            .iostandard = "LVCMOS33",
            .freq_mhz = 50.0,
        },
    });

    try spec.ports.append(.{
        .name = "led",
        .direction = .output,
        .port_type = .signal,
        .width = 1,
        .attributes = .{
            .loc = "T23",
            .iostandard = "LVCMOS33",
        },
    });

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var parser = TriParser.init(allocator);
    try parser.generateXDC(&spec, buffer.writer());

    const output = buffer.items;
    try std.testing.expect(mem.indexOf(u8, output, "PACKAGE_PIN U22") != null);
    try std.testing.expect(mem.indexOf(u8, output, "PACKAGE_PIN T23") != null);
    try std.testing.expect(mem.indexOf(u8, output, "IOSTANDARD LVCMOS33") != null);
}
