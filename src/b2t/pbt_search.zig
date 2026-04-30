const std = @import("std");

pub const HyperParams = struct {
    lr: f32,
    batch_size: usize,
    label_smoothing: f32,
    tau_init: f32,
    weight_decay: f32,
    grad_clip: f32,

    pub fn randomize(rng: std.Random, base: HyperParams) HyperParams {
        return .{
            .lr = base.lr * rng.float(f32) * 2.0,
            .batch_size = base.batch_size,
            .label_smoothing = rng.float(f32) * 0.2,
            .tau_init = 1.0 + rng.float(f32) * 9.0,
            .weight_decay = rng.float(f32) * 0.1,
            .grad_clip = 0.5 + rng.float(f32) * 2.0,
        };
    }

    pub fn crossover(rng: std.Random, a: HyperParams, b: HyperParams) HyperParams {
        return .{
            .lr = if (rng.boolean()) a.lr else b.lr,
            .batch_size = if (rng.boolean()) a.batch_size else b.batch_size,
            .label_smoothing = if (rng.boolean()) a.label_smoothing else b.label_smoothing,
            .tau_init = if (rng.boolean()) a.tau_init else b.tau_init,
            .weight_decay = if (rng.boolean()) a.weight_decay else b.weight_decay,
            .grad_clip = if (rng.boolean()) a.grad_clip else b.grad_clip,
        };
    }

    pub fn mutate(self: HyperParams, rng: std.Random, strength: f32) HyperParams {
        var m = self;
        if (rng.boolean()) m.lr *= 1.0 + (rng.float(f32) - 0.5) * strength;
        if (rng.boolean()) m.label_smoothing = std.math.clamp(m.label_smoothing + (rng.float(f32) - 0.5) * 0.05 * strength, 0, 0.3);
        if (rng.boolean()) m.tau_init = std.math.clamp(m.tau_init + (rng.float(f32) - 0.5) * strength, 0.1, 10.0);
        if (rng.boolean()) m.weight_decay = std.math.clamp(m.weight_decay + (rng.float(f32) - 0.5) * 0.01 * strength, 0, 0.2);
        if (rng.boolean()) m.grad_clip = std.math.clamp(m.grad_clip + (rng.float(f32) - 0.5) * strength, 0.1, 5.0);
        return m;
    }
};

pub const PBTMember = struct {
    id: usize,
    params: HyperParams,
    fitness: f32,
    steps: u32,
    best_fitness: f32,
    generation: u32,

    pub fn betterThan(self: *const PBTMember, other: *const PBTMember) bool {
        return self.fitness > other.fitness;
    }
};

pub const PBTConfig = struct {
    population_size: usize = 5,
    eval_interval: u32 = 1000,
    exploit_fraction: f32 = 0.4,
    explore_strength: f32 = 0.3,
    max_generations: u32 = 20,
};

pub const PBTTracker = struct {
    allocator: std.mem.Allocator,
    config: PBTConfig,
    population: std.ArrayList(PBTMember),
    generation: u32,
    best_ever: ?PBTMember,
    rng: std.Random.DefaultPrng,

    pub fn init(allocator: std.mem.Allocator, config: PBTConfig) PBTTracker {
        return .{
            .allocator = allocator,
            .config = config,
            .population = std.ArrayList(PBTMember).init(allocator),
            .generation = 0,
            .best_ever = null,
            .rng = std.Random.DefaultPrng.init(42),
        };
    }

    pub fn deinit(self: *PBTTracker) void {
        self.population.deinit();
    }

    pub fn initPopulation(self: *PBTTracker, base_params: HyperParams) !void {
        const random = self.rng.random();
        for (0..self.config.population_size) |i| {
            const params = if (i == 0) base_params else HyperParams.randomize(random, base_params);
            try self.population.append(.{
                .id = i,
                .params = params,
                .fitness = -std.math.inf(f32),
                .steps = 0,
                .best_fitness = -std.math.inf(f32),
                .generation = 0,
            });
        }
    }

    pub fn updateFitness(self: *PBTTracker, member_id: usize, fitness: f32) void {
        if (member_id >= self.population.items.len) return;
        const member = &self.population.items[member_id];
        member.fitness = fitness;
        if (fitness > member.best_fitness) {
            member.best_fitness = fitness;
        }
        if (self.best_ever == null or fitness > self.best_ever.?.fitness) {
            self.best_ever = member.*;
        }
    }

    pub fn exploitAndExplore(self: *PBTTracker) void {
        self.generation += 1;
        const random = self.rng.random();
        const n = self.population.items.len;
        if (n < 2) return;

        var sorted_indices = std.ArrayList(usize).initCapacity(self.allocator, n) catch return;
        defer sorted_indices.deinit();
        for (0..n) |i| sorted_indices.appendAssumeCapacity(i);

        std.mem.sort(usize, sorted_indices.items, self, struct {
            pub fn lessThan(ctx: *PBTTracker, a: usize, b: usize) bool {
                return ctx.population.items[a].fitness > ctx.population.items[b].fitness;
            }
        }.lessThan);

        const truncate = @as(usize, @intFromFloat(
            @as(f32, @floatFromInt(n)) * self.config.exploit_fraction,
        ));
        const top_count = @max(truncate, 1);

        for (0..top_count) |bottom_idx| {
            const bottom = sorted_indices.items[n - 1 - bottom_idx];
            const top = sorted_indices.items[bottom_idx % top_count];

            self.population.items[bottom].params = HyperParams.crossover(
                random,
                self.population.items[top].params,
                self.population.items[bottom].params,
            );
            self.population.items[bottom].params = self.population.items[bottom].params.mutate(
                random,
                self.config.explore_strength,
            );
            self.population.items[bottom].generation = self.generation;
            self.population.items[bottom].fitness = -std.math.inf(f32);
        }
    }

    pub fn bestParams(self: *const PBTTracker) ?HyperParams {
        if (self.best_ever == null) return null;
        return self.best_ever.?.params;
    }

    pub fn bestFitness(self: *const PBTTracker) f32 {
        if (self.best_ever == null) return -std.math.inf(f32);
        return self.best_ever.?.fitness;
    }

    pub fn printPopulation(self: *const PBTTracker, writer: anytype) !void {
        try writer.print("\n  PBT Generation {d} (best: {d:.4})\n", .{ self.generation, self.bestFitness() });
        try writer.print("  {s}\n", .{"-" * 60});
        for (self.population.items) |m| {
            const marker = if (m.fitness == self.bestFitness()) " *" else "";
            try writer.print("  #{d}: fitness={d:.4} lr={d:.1e} ls={d:.3} gen={d}{s}\n", .{
                m.id, m.fitness, m.params.lr, m.params.label_smoothing, m.generation, marker,
            });
        }
        try writer.print("\n", .{});
    }
};

test "PBT init population" {
    const allocator = std.testing.allocator;
    var pbt = PBTTracker.init(allocator, .{ .population_size = 5 });
    defer pbt.deinit();

    try pbt.initPopulation(.{
        .lr = 3e-4,
        .batch_size = 66,
        .label_smoothing = 0.1,
        .tau_init = 5.0,
        .weight_decay = 0.01,
        .grad_clip = 1.0,
    });

    try std.testing.expectEqual(@as(usize, 5), pbt.population.items.len);
    try std.testing.expectEqual(@as(f32, 3e-4), pbt.population.items[0].params.lr);
}

test "PBT update fitness tracks best" {
    const allocator = std.testing.allocator;
    var pbt = PBTTracker.init(allocator, .{ .population_size = 3 });
    defer pbt.deinit();

    try pbt.initPopulation(.{
        .lr = 3e-4, .batch_size = 66, .label_smoothing = 0.1,
        .tau_init = 5.0, .weight_decay = 0.01, .grad_clip = 1.0,
    });

    pbt.updateFitness(0, 0.85);
    pbt.updateFitness(1, 0.92);
    pbt.updateFitness(2, 0.78);

    try std.testing.expect(pbt.best_ever != null);
    try std.testing.expect(pbt.bestFitness() > 0.9);
}

test "PBT exploit and explore" {
    const allocator = std.testing.allocator;
    var pbt = PBTTracker.init(allocator, .{
        .population_size = 5,
        .exploit_fraction = 0.4,
        .explore_strength = 0.3,
    });
    defer pbt.deinit();

    try pbt.initPopulation(.{
        .lr = 3e-4, .batch_size = 66, .label_smoothing = 0.1,
        .tau_init = 5.0, .weight_decay = 0.01, .grad_clip = 1.0,
    });

    for (0..5) |i| {
        pbt.updateFitness(i, @as(f32, @floatFromInt(i)) * 0.1);
    }

    const gen_before = pbt.generation;
    pbt.exploitAndExplore();

    try std.testing.expect(pbt.generation > gen_before);
}

test "hyper params crossover" {
    var rng = std.Random.DefaultPrng.init(42);
    const a = HyperParams{ .lr = 1e-3, .batch_size = 66, .label_smoothing = 0.1, .tau_init = 5.0, .weight_decay = 0.01, .grad_clip = 1.0 };
    const b = HyperParams{ .lr = 3e-4, .batch_size = 128, .label_smoothing = 0.05, .tau_init = 3.0, .weight_decay = 0.05, .grad_clip = 2.0 };

    const child = HyperParams.crossover(rng.random(), a, b);
    try std.testing.expect(child.lr == a.lr or child.lr == b.lr);
}

test "hyper params mutation" {
    var rng = std.Random.DefaultPrng.init(123);
    const base = HyperParams{ .lr = 3e-4, .batch_size = 66, .label_smoothing = 0.1, .tau_init = 5.0, .weight_decay = 0.01, .grad_clip = 1.0 };
    const mutated = base.mutate(rng.random(), 0.5);

    try std.testing.expect(mutated.lr > 0);
    try std.testing.expect(mutated.label_smoothing >= 0);
}
