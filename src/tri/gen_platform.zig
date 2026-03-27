//! TRI Platform — Generated from specs/tri/tri_platform.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const builtin = @import("builtin");

pub const Os = enum(u8) {
    linux,
    windows,
    macos,
    bsd,
    unknown,
};

pub const Arch = enum(u8) {
    x86_64,
    aarch64,
    arm,
    riscv,
    unknown,
};

pub const Platform = struct {
    os: Os,
    arch: Arch,
};

pub fn getPlatform() Platform {
    return .{
        .os = getOs(),
        .arch = getArch(),
    };
}

fn getOs() Os {
    return switch (builtin.os.tag) {
        .linux => .linux,
        .windows => .windows,
        .macos => .macos,
        .freebsd, .openbsd, .netbsd => .bsd,
        else => .unknown,
    };
}

fn getArch() Arch {
    return switch (builtin.cpu.arch) {
        .x86_64 => .x86_64,
        .aarch64 => .aarch64,
        .arm, .armeb => .arm,
        .riscv64 => .riscv,
        else => .unknown,
    };
}

pub fn isLinux() bool {
    return builtin.os.tag == .linux;
}

pub fn isWindows() bool {
    return builtin.os.tag == .windows;
}

pub fn isMac() bool {
    return builtin.os.tag == .macos;
}

pub fn is64Bit() bool {
    return builtin.target.ptrBitWidth() == 64;
}

pub fn pathSeparator() u8 {
    return if (builtin.os.tag == .windows) '\\' else '/';
}

test "Platform: getPlatform" {
    const p = getPlatform();
    try std.testing.expect(p.os != .unknown or p.arch != .unknown);
}
