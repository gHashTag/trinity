// ═══════════════════════════════════════════════════════════════════════════════
// HARDWARE NODE — Real Hardware Detection + $TRI Rewards
// ═══════════════════════════════════════════════════════════════════════════════
//
// Purpose: Hardware node for Trinity DePIN with live rewards
// Platforms: Raspberry Pi, macOS, Linux
// Discovery: UDP port 9333
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Platform = enum {
    raspberry_pi,
    macos,
    linux,
    unknown,
};

pub const HardwareInfo = struct {
    platform: Platform,
    arch: Arch,
    cpu_cores: u32,
    memory_mb: u32,
    hostname: []const u8,
    node_id: []const u8,
};

pub const Arch = enum {
    arm64,
    x86_64,
    unknown,
};

pub const RewardState = struct {
    node_id: []const u8,
    uptime_seconds: u64,
    tri_earned: f64,
    tri_claimed: f64,
    last_claim_ts: u64,
};

pub const NodeCapabilities = struct {
    compute: bool,
    storage: bool,
    network: bool,
    gpu: bool,
    bandwidth_mbps: u32,
};

// Detect hardware platform
pub fn detectPlatform(allocator: Allocator) !Platform {
    _ = allocator;

    // Try Raspberry Pi first
    if (std.fs.path.exists("/proc/cpuinfo")) {
        const cpuinfo = try std.fs.cwd().readFileAlloc(allocator, "/proc/cpuinfo", 4096);
        defer allocator.free(cpuinfo);
        if (std.mem.indexOf(u8, cpuinfo, "Raspberry Pi") != null) {
            return .raspberry_pi;
        }
    }

    // Check for macOS
    if (std.fs.path.exists("/System/Library/CoreServices/SystemVersion.plist") or
        std.process.getEnvVar(allocator, "SW_VERS")) |_|
    {
        return .macos;
    }

    // Default to Linux
    return .linux;
}

// Detect system architecture
pub fn detectArch(allocator: Allocator) !Arch {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "uname", "-m" },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    const arch = std.mem.trim(u8, result.stdout, "\n\r ");
    if (std.mem.eql(u8, arch, "aarch64") or std.mem.eql(u8, arch, "arm64")) {
        return .arm64;
    }
    if (std.mem.eql(u8, arch, "x86_64")) {
        return .x86_64;
    }
    return .unknown;
}

// Get CPU core count
pub fn detectCPUCores(allocator: Allocator) !u32 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sysctl", "-n", "hw.ncpu" },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    const cores_str = std.mem.trim(u8, result.stdout, "\n\r ");
    return std.fmt.parseInt(u32, cores_str, 10) catch 4;
}

// Get system memory in MB
pub fn detectMemoryMB(allocator: Allocator) !u32 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sysctl", "-n", "hw.memsize" },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    const bytes_str = std.mem.trim(u8, result.stdout, "\n\r ");
    const bytes = try std.fmt.parseInt(u64, bytes_str, 10);
    return @intCast(bytes / 1024 / 1024);
}

// Calculate $TRI rewards based on uptime and role
pub fn calculateRewards(uptime_seconds: u64, role: []const u8) f64 {
    const base_rate = 0.001; // $TRI per second
    const role_mult = getRoleMultiplier(role);
    return @as(f64, @floatFromInt(uptime_seconds)) * base_rate * role_mult;
}

fn getRoleMultiplier(role: []const u8) f64 {
    if (std.mem.eql(u8, role, "primary")) return 1.5;
    if (std.mem.eql(u8, role, "secondary")) return 1.2;
    return 1.0;
}

// Generate node ID from hardware signature
pub fn generateNodeID(allocator: Allocator, info: HardwareInfo) ![]const u8 {
    const signature = try std.fmt.allocPrint(allocator, "{s}-{s}-{}-{}", .{ @tagName(info.platform), @tagName(info.arch), info.cpu_cores, info.memory_mb });
    // DEFERRED: Hash signature to create proper UUID (use std.crypto.hash.sha3 or similar)
    return signature;
}

// Full hardware probe
pub fn probeHardware(allocator: Allocator) !HardwareInfo {
    const platform = try detectPlatform(allocator);
    const arch = try detectArch(allocator);
    const cpu_cores = try detectCPUCores(allocator);
    const memory_mb = try detectMemoryMB(allocator);

    // Get hostname
    const hostname = try std.process.getEnvVar(allocator, "HOSTNAME") orelse "trinity-node";

    const info = HardwareInfo{
        .platform = platform,
        .arch = arch,
        .cpu_cores = cpu_cores,
        .memory_mb = memory_mb,
        .hostname = hostname,
        .node_id = "", // Will be filled by generateNodeID
    };

    const node_id = try generateNodeID(allocator, info);

    return HardwareInfo{
        .platform = platform,
        .arch = arch,
        .cpu_cores = cpu_cores,
        .memory_mb = memory_mb,
        .hostname = hostname,
        .node_id = node_id,
    };
}

// Format hardware info for display
pub fn formatHardwareInfo(writer: anytype, info: HardwareInfo) !void {
    try writer.print("Platform: {s}\n", .{@tagName(info.platform)});
    try writer.print("Architecture: {s}\n", .{@tagName(info.arch)});
    try writer.print("CPU Cores: {d}\n", .{info.cpu_cores});
    try writer.print("Memory: {d} MB\n", .{info.memory_mb});
    try writer.print("Hostname: {s}\n", .{info.hostname});
    try writer.print("Node ID: {s}\n", .{info.node_id});
}
