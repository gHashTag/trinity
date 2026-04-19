const std = @import("std");

pub const VSALength = 2560;
const LIMB_COUNT = VSALength / 64;

pub const HRRVector = struct {
    limbs: [LIMB_COUNT]u64,

    pub fn init(allocator: std.mem.Allocator, len: usize) !HRRVector {
        _ = allocator;
        _ = len;
        return HRRVector{ .limbs = [_]u64{0} ** LIMB_COUNT };
    }

    pub fn deinit(self: *HRRVector) void {
        _ = self;
    }
};

pub const VSARegister = struct {
    vec: HRRVector,

    pub fn init(allocator: std.mem.Allocator) !VSARegister {
        return VSARegister{
            .vec = try HRRVector.init(allocator, VSALength),
        };
    }

    pub fn deinit(self: *VSARegister) void {
        self.vec.deinit();
    }
};

pub const VSARegFile = struct {
    regs: [16]?*VSARegister,
    allocator: std.mem.Allocator,
    initialized: [16]bool,

    pub fn init(allocator: std.mem.Allocator) VSARegFile {
        return VSARegFile{
            .regs = [_]?*VSARegister{null} ** 16,
            .allocator = allocator,
            .initialized = [_]bool{false} ** 16,
        };
    }

    pub fn deinit(self: *VSARegFile) void {
        for (self.regs, 0..) |opt_reg, i| {
            if (opt_reg) |reg| {
                reg.deinit();
                self.allocator.destroy(reg);
                self.regs[i] = null;
                self.initialized[i] = false;
            }
        }
    }

    pub fn allocReg(self: *VSARegFile, idx: usize) !void {
        if (idx >= 16) return error.InvalidRegister;
        if (self.regs[idx] == null) {
            const reg = try self.allocator.create(VSARegister);
            reg.* = try VSARegister.init(self.allocator);
            self.regs[idx] = reg;
            self.initialized[idx] = true;
        }
    }

    pub fn get(self: *const VSARegFile, idx: usize) *const VSARegister {
        if (idx >= 16) return error.InvalidRegister;
        return if (self.regs[idx]) |reg| reg else &static_zero_register;
    }

    const static_zero_register = VSARegister{
        .vec = HRRVector{ .limbs = [_]u64{0} ** LIMB_COUNT },
    };

    pub fn bind(self: *const VSARegFile, dst: usize, src1: usize, src2: usize) !void {
        if (dst >= 16 or src1 >= 16 or src2 >= 16) return error.InvalidRegister;
        const a = self.get(src1);
        const b = self.get(src2);
        const dst_reg = self.get(dst);

        for (0..LIMB_COUNT) |i| {
            dst_reg.vec.limbs[i] = a.vec.limbs[i] ^ b.vec.limbs[i];
        }
    }

    pub fn unbind(self: *const VSARegFile, dst: usize, bound: usize, key: usize) !void {
        if (dst >= 16 or bound >= 16 or key >= 16) return error.InvalidRegister;
        const b = self.get(bound);
        const k = self.get(key);
        const dst_reg = self.get(dst);

        for (0..LIMB_COUNT) |i| {
            dst_reg.vec.limbs[i] = b.vec.limbs[i] ^ k.vec.limbs[i];
        }
    }

    pub fn bundle2(self: *const VSARegFile, dst: usize, src1: usize, src2: usize) !void {
        if (dst >= 16 or src1 >= 16 or src2 >= 16) return error.InvalidRegister;
        const a = self.get(src1);
        const b = self.get(src2);
        const dst_reg = self.get(dst);

        for (0..LIMB_COUNT) |i| {
            dst_reg.vec.limbs[i] = a.vec.limbs[i] +% b.vec.limbs[i];
        }
    }

    pub fn bundle3(self: *const VSARegFile, dst: usize, src1: usize, src2: usize, src3: usize) !void {
        if (dst >= 16 or src1 >= 16 or src2 >= 16 or src3 >= 16) return error.InvalidRegister;
        const a = self.get(src1);
        const b = self.get(src2);
        const c = self.get(src3);
        const dst_reg = self.get(dst);

        for (0..LIMB_COUNT) |i| {
            dst_reg.vec.limbs[i] = a.vec.limbs[i] +% b.vec.limbs[i] +% c.vec.limbs[i];
        }
    }

    pub fn similarity(self: *const VSARegFile, src1: usize, src2: usize) f64 {
        if (src1 >= 16 or src2 >= 16) return error.InvalidRegister;
        const a = self.get(src1);
        const b = self.get(src2);

        var dot: u128 = 0;
        var norm_a: u128 = 0;
        var norm_b: u128 = 0;

        for (0..LIMB_COUNT) |i| {
            const al = a.vec.limbs[i];
            const bl = b.vec.limbs[i];

            dot += @as(u128, al) * @as(u128, bl);
            norm_a += @as(u128, al) * @as(u128, al);
            norm_b += @as(u128, bl) * @as(u128, bl);
        }

        if (norm_a == 0 or norm_b == 0) return 0.0;

        const sim: f64 = @floatFromInt(dot) / @sqrt(@floatFromInt(norm_a) * @floatFromInt(norm_b));
        return std.math.clamp(sim, -1.0, 1.0);
    }

    pub fn initRandom(self: *VSARegFile, seed: u64) !void {
        var rng = std.Random.DefaultPrng.init(seed);
        for (0..16) |i| {
            try self.allocReg(i);
            const reg = self.get(i);

            var all_zero = true;
            for (0..LIMB_COUNT) |j| {
                const limb = rng.next() | 1;
                reg.vec.limbs[j] = limb;
                if (limb != 0) all_zero = false;
            }

            if (all_zero) {
                reg.vec.limbs[0] = 1;
            }
        }
    }
};
