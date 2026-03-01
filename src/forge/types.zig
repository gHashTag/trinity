// ═══════════════════════════════════════════════════════════════════════════════
// FORGE OF KOSCHEI v2.0 — Core Types
// ═══════════════════════════════════════════════════════════════════════════════
//
// Shared data structures for the entire FORGE FPGA toolchain pipeline.
// Every module imports this file.
//
// Sacred Formula: φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// Sacred Constants
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: i64 = 999;
pub const FORGE_VERSION = "2.0.0";

// ═══════════════════════════════════════════════════════════════════════════════
// Target Devices
// ═══════════════════════════════════════════════════════════════════════════════

pub const DeviceId = enum {
    xc7a35t,
    xc7a100t,

    pub fn idcode(self: DeviceId) u32 {
        return switch (self) {
            .xc7a35t => 0x0362D093,
            .xc7a100t => 0x13631093,
        };
    }

    pub fn frameCount(self: DeviceId) u32 {
        return switch (self) {
            .xc7a35t => 16620,
            .xc7a100t => 51840,
        };
    }

    pub fn partName(self: DeviceId) []const u8 {
        return switch (self) {
            .xc7a35t => "7a35tcsg324",
            .xc7a100t => "7a100tfgg676",
        };
    }

    pub fn name(self: DeviceId) []const u8 {
        return switch (self) {
            .xc7a35t => "xc7a35t",
            .xc7a100t => "xc7a100t",
        };
    }
};

/// Frame constants for all Artix-7 devices
pub const ARTIX7_FRAME_WORDS: u32 = 101;
pub const ARTIX7_WORD_BITS: u32 = 32;

// ═══════════════════════════════════════════════════════════════════════════════
// Yosys JSON Netlist Types (pre-tech-mapping)
// ═══════════════════════════════════════════════════════════════════════════════

/// A net bit in Yosys JSON is either a signal number or a constant
pub const NetBit = union(enum) {
    signal: u32,
    constant_zero: void,
    constant_one: void,
    constant_x: void,

    pub fn isSignal(self: NetBit) bool {
        return switch (self) {
            .signal => true,
            else => false,
        };
    }

    pub fn signalId(self: NetBit) ?u32 {
        return switch (self) {
            .signal => |id| id,
            else => null,
        };
    }
};

pub const PortDir = enum {
    input,
    output,
    inout,

    pub fn fromString(s: []const u8) PortDir {
        if (std.mem.eql(u8, s, "input")) return .input;
        if (std.mem.eql(u8, s, "output")) return .output;
        if (std.mem.eql(u8, s, "inout")) return .inout;
        return .input;
    }
};

/// A port on the top-level module
pub const YosysPort = struct {
    name: []const u8,
    direction: PortDir,
    bits: []NetBit,
};

/// A cell instance from Yosys JSON
pub const YosysCell = struct {
    name: []const u8,
    cell_type: []const u8,
    hide_name: bool,
    port_directions: []PortDirEntry,
    connections: []ConnectionEntry,
    parameters: []ParamEntry,

    pub const PortDirEntry = struct {
        name: []const u8,
        dir: PortDir,
    };

    pub const ConnectionEntry = struct {
        name: []const u8,
        bits: []NetBit,
    };

    pub const ParamEntry = struct {
        name: []const u8,
        value: []const u8,
    };
};

/// The parsed top-level module from Yosys JSON
pub const YosysModule = struct {
    name: []const u8,
    ports: []YosysPort,
    cells: []YosysCell,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Post-Technology-Mapping Types
// ═══════════════════════════════════════════════════════════════════════════════

pub const CellType = enum {
    LUT1,
    LUT2,
    LUT3,
    LUT4,
    LUT5,
    LUT6,
    FDRE,
    FDSE,
    FDCE,
    FDPE,
    CARRY4,
    IBUF,
    OBUF,
    BUFG,
    BUFGCTRL,
    BUFHCE,
    INV,
    RAMB36E1,
    DSP48E1,

    pub fn fromString(s: []const u8) ?CellType {
        if (std.mem.eql(u8, s, "LUT1")) return .LUT1;
        if (std.mem.eql(u8, s, "LUT2")) return .LUT2;
        if (std.mem.eql(u8, s, "LUT3")) return .LUT3;
        if (std.mem.eql(u8, s, "LUT4")) return .LUT4;
        if (std.mem.eql(u8, s, "LUT5")) return .LUT5;
        if (std.mem.eql(u8, s, "LUT6")) return .LUT6;
        if (std.mem.eql(u8, s, "FDRE")) return .FDRE;
        if (std.mem.eql(u8, s, "FDSE")) return .FDSE;
        if (std.mem.eql(u8, s, "FDCE")) return .FDCE;
        if (std.mem.eql(u8, s, "FDPE")) return .FDPE;
        if (std.mem.eql(u8, s, "CARRY4")) return .CARRY4;
        if (std.mem.eql(u8, s, "IBUF")) return .IBUF;
        if (std.mem.eql(u8, s, "OBUF")) return .OBUF;
        if (std.mem.eql(u8, s, "BUFG")) return .BUFG;
        if (std.mem.eql(u8, s, "BUFGCTRL")) return .BUFGCTRL;
        if (std.mem.eql(u8, s, "BUFHCE")) return .BUFHCE;
        if (std.mem.eql(u8, s, "INV")) return .INV;
        if (std.mem.eql(u8, s, "RAMB36E1")) return .RAMB36E1;
        if (std.mem.eql(u8, s, "DSP48E1")) return .DSP48E1;
        return null;
    }

    pub fn isLUT(self: CellType) bool {
        return switch (self) {
            .LUT1, .LUT2, .LUT3, .LUT4, .LUT5, .LUT6 => true,
            else => false,
        };
    }

    pub fn isFF(self: CellType) bool {
        return switch (self) {
            .FDRE, .FDSE, .FDCE, .FDPE => true,
            else => false,
        };
    }

    pub fn isIO(self: CellType) bool {
        return switch (self) {
            .IBUF, .OBUF => true,
            else => false,
        };
    }

    pub fn isClock(self: CellType) bool {
        return switch (self) {
            .BUFG, .BUFGCTRL, .BUFHCE => true,
            else => false,
        };
    }
};

/// A mapped cell ready for placement
pub const MappedCell = struct {
    id: u32,
    cell_type: CellType,
    name: []const u8,

    // Placement (populated by placer)
    tile_x: ?u16 = null,
    tile_y: ?u16 = null,
    bel: ?BelId = null,
    locked: bool = false,

    // Cell-specific configuration
    lut_init: u64 = 0,
    ff_init: u1 = 0,
    ff_sync_reset: bool = true,
    carry_cyinit_const: ?u1 = null,
};

/// Unique BEL identifier within the device
pub const BelId = struct {
    tile_x: u16,
    tile_y: u16,
    bel_index: u16,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Net Types
// ═══════════════════════════════════════════════════════════════════════════════

/// A pin reference: (cell_id, pin_name)
pub const PinRef = struct {
    cell_id: u32,
    pin_name: []const u8,
};

/// A net connecting one driver to multiple sinks
pub const Net = struct {
    id: u32,
    name: []const u8,
    driver: ?PinRef = null,
    sinks: std.ArrayList(PinRef) = .{},
    is_clock: bool = false,
    is_global: bool = false,
    route_pips: std.ArrayList(RoutingPip) = .{},

    pub fn deinit(self: *Net, gpa: Allocator) void {
        self.sinks.deinit(gpa);
        self.route_pips.deinit(gpa);
    }
};

/// A routing PIP (Programmable Interconnect Point) used by a net
pub const RoutingPip = struct {
    tile_name: []const u8,
    wire_from: []const u8,
    wire_to: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Device Model Types
// ═══════════════════════════════════════════════════════════════════════════════

pub const TileType = enum {
    CLBLL_L,
    CLBLL_R,
    CLBLM_L,
    CLBLM_R,
    INT_L,
    INT_R,
    LIOB33,
    RIOB33,
    LIOI3,
    RIOI3,
    IO_INT_INTERFACE_L,
    IO_INT_INTERFACE_R,
    CLK_BUFG_BOT_R,
    CLK_BUFG_TOP_R,
    CLK_BUFG_REBUF,
    CLK_HROW_TOP_R,
    CLK_HROW_BOT_R,
    HCLK_L,
    HCLK_R,
    HCLK_CMT,
    HCLK_CMT_L,
    BRAM_L,
    BRAM_R,
    DSP_L,
    DSP_R,
    OTHER,
};

/// A tile in the FPGA device grid
pub const Tile = struct {
    x: u16,
    y: u16,
    tile_type: TileType,
    name: []const u8,
    frame_base_addr: u32,
    num_bels: u16,
};

/// A BEL slot within a tile
pub const BelSlot = struct {
    bel_type: CellType,
    name: []const u8,
    occupied_by: ?u32 = null,
};

// ═══════════════════════════════════════════════════════════════════════════════
// FASM Types
// ═══════════════════════════════════════════════════════════════════════════════

/// A FASM feature entry (e.g., CLBLL_L_X2Y148.SLICEL_X0.ALUT.INIT[63:0] = 64'b...)
pub const FasmFeature = struct {
    /// Full line text for output
    line: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Segbits Types (FASM → frame bit mapping)
// ═══════════════════════════════════════════════════════════════════════════════

/// Maps a FASM feature to a specific bit in a configuration frame
pub const SegbitEntry = struct {
    frame_offset: u8,
    bit_offset: u16,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Constraints
// ═══════════════════════════════════════════════════════════════════════════════

/// An IO constraint from XDC
pub const IOConstraint = struct {
    port_name: []const u8,
    package_pin: []const u8,
    iostandard: []const u8,
};

/// A clock constraint from XDC
pub const ClockConstraint = struct {
    port_name: []const u8,
    period_ns: f64,
    name: []const u8,
};

/// All constraints from XDC parsing
pub const Constraints = struct {
    io: std.ArrayList(IOConstraint) = .{},
    clocks: std.ArrayList(ClockConstraint) = .{},

    pub fn deinit(self: *Constraints, gpa: Allocator) void {
        self.io.deinit(gpa);
        self.clocks.deinit(gpa);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ForgeDB — Complete Pipeline State
// ═══════════════════════════════════════════════════════════════════════════════

pub const Phase = enum {
    parsed,
    mapped,
    placed,
    routed,
    bitstream_ready,
};

pub const ForgeDB = struct {
    allocator: Allocator,
    device: DeviceId,
    phase: Phase,
    cells: std.ArrayList(MappedCell) = .{},
    nets: std.ArrayList(Net) = .{},
    constraints: Constraints = .{},

    pub fn init(allocator: Allocator, device: DeviceId) ForgeDB {
        return .{
            .allocator = allocator,
            .device = device,
            .phase = .parsed,
        };
    }

    pub fn deinit(self: *ForgeDB) void {
        for (self.nets.items) |*net| {
            net.deinit(self.allocator);
        }
        self.nets.deinit(self.allocator);
        self.cells.deinit(self.allocator);
        self.constraints.deinit(self.allocator);
    }

    pub fn cellCount(self: *const ForgeDB) u32 {
        return @intCast(self.cells.items.len);
    }

    pub fn netCount(self: *const ForgeDB) u32 {
        return @intCast(self.nets.items.len);
    }

    pub fn countCellsByType(self: *const ForgeDB, cell_type: CellType) u32 {
        var count: u32 = 0;
        for (self.cells.items) |cell| {
            if (cell.cell_type == cell_type) count += 1;
        }
        return count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Xilinx Bitstream Constants
// ═══════════════════════════════════════════════════════════════════════════════

pub const XILINX_SYNC_WORD: u32 = 0xAA995566;
pub const XILINX_NOOP: u32 = 0x20000000;
pub const XILINX_BUS_WIDTH_DETECT: u32 = 0x000000BB;
pub const XILINX_BUS_WIDTH_SYNC: u32 = 0x11220044;
pub const XILINX_DUMMY: u32 = 0xFFFFFFFF;

// Frame address encoding
pub const FRAME_ADDR_BLOCK_TYPE_SHIFT: u5 = 23;
pub const FRAME_ADDR_TOP_BOT_SHIFT: u5 = 22;
pub const FRAME_ADDR_ROW_SHIFT: u5 = 17;
pub const FRAME_ADDR_COL_SHIFT: u5 = 7;
pub const FRAME_ADDR_MINOR_MASK: u32 = 0x7F;

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "DeviceId properties" {
    const dev = DeviceId.xc7a35t;
    try std.testing.expectEqual(@as(u32, 0x0362D093), dev.idcode());
    try std.testing.expectEqual(@as(u32, 16620), dev.frameCount());
    try std.testing.expectEqualStrings("7a35tcsg324", dev.partName());
}

test "NetBit from signal" {
    const nb = NetBit{ .signal = 42 };
    try std.testing.expect(nb.isSignal());
    try std.testing.expectEqual(@as(u32, 42), nb.signalId().?);
}

test "NetBit constants" {
    const zero: NetBit = .constant_zero;
    try std.testing.expect(!zero.isSignal());
    try std.testing.expectEqual(@as(?u32, null), zero.signalId());
}

test "CellType identification" {
    try std.testing.expect(CellType.LUT6.isLUT());
    try std.testing.expect(!CellType.LUT6.isFF());
    try std.testing.expect(CellType.FDRE.isFF());
    try std.testing.expect(CellType.IBUF.isIO());
    try std.testing.expect(CellType.BUFG.isClock());
    try std.testing.expect(!CellType.CARRY4.isLUT());
}

test "CellType fromString" {
    try std.testing.expectEqual(CellType.CARRY4, CellType.fromString("CARRY4").?);
    try std.testing.expectEqual(CellType.FDRE, CellType.fromString("FDRE").?);
    try std.testing.expectEqual(CellType.INV, CellType.fromString("INV").?);
    try std.testing.expectEqual(@as(?CellType, null), CellType.fromString("UNKNOWN"));
}

test "ForgeDB init/deinit" {
    const allocator = std.testing.allocator;
    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try std.testing.expectEqual(Phase.parsed, db.phase);
    try std.testing.expectEqual(@as(u32, 0), db.cellCount());
}

test "Sacred identity" {
    const result = PHI * PHI + 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqAbs(TRINITY, result, 1e-10);
}
