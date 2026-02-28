//! GridWorld - [CYR:[EN]]withwithand[EN]withto[EN] with[EN]yes for testand[EN]in[EN]and[EN] RL agent[EN]in
//!
//! [CYR:[EN]]to[EN] NxN with:
//! - [CYR:[EN]]in[EN] by[EN]and[EN]and[EN] (0,0)
//! - [CYR:[EN]] (N-1, N-1) with on[CYR:[EN]]before[EN] +10
//! - [CYR:[EN]] ([CYR:[EN]]and[EN]on[CYR:[EN]])
//! - [CYR:[EN]]yes -0.1 [EN] each step
//!
//! [CYR:[EN]]with[EN]inand[EN]: UP=0, RIGHT=1, DOWN=2, LEFT=3
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════

pub const Action = enum(usize) {
    UP = 0,
    RIGHT = 1,
    DOWN = 2,
    LEFT = 3,

    pub fn toString(self: Action) []const u8 {
        return switch (self) {
            .UP => "UP",
            .RIGHT => "RIGHT",
            .DOWN => "DOWN",
            .LEFT => "LEFT",
        };
    }
};

pub const NUM_ACTIONS: usize = 4;

// ═══════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════

/// [CYR:[EN]]and[EN]and[EN] on with[EN]to[EN]
pub const Position = struct {
    x: usize,
    y: usize,

    pub fn toIndex(self: Position, width: usize) usize {
        return self.y * width + self.x;
    }

    pub fn eql(self: Position, other: Position) bool {
        return self.x == other.x and self.y == other.y;
    }
};

/// Step result
pub const StepResult = struct {
    next_state: usize,
    reward: f64,
    done: bool,
    info: []const u8,
};

/// [CYR:[EN]]and[CYR:[EN]]and[EN] GridWorld
pub const GridWorldConfig = struct {
    width: usize = 4,
    height: usize = 4,
    step_reward: f64 = -0.1,
    goal_reward: f64 = 10.0,
    wall_reward: f64 = -1.0,
    max_steps: usize = 100,
};

/// [CYR:[EN]]yes GridWorld
pub const GridWorld = struct {
    config: GridWorldConfig,
    width: usize,
    height: usize,
    agent_pos: Position,
    goal_pos: Position,
    walls: []bool,
    steps: usize,
    total_reward: f64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: GridWorldConfig) !GridWorld {
        const size = config.width * config.height;
        const walls = try allocator.alloc(bool, size);
        @memset(walls, false);

        return .{
            .config = config,
            .width = config.width,
            .height = config.height,
            .agent_pos = .{ .x = 0, .y = 0 },
            .goal_pos = .{ .x = config.width - 1, .y = config.height - 1 },
            .walls = walls,
            .steps = 0,
            .total_reward = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *GridWorld) void {
        self.allocator.free(self.walls);
    }

    /// [CYR:[EN]]withand[EN] with[CYR:[EN]]
    pub fn reset(self: *GridWorld) usize {
        self.agent_pos = .{ .x = 0, .y = 0 };
        self.steps = 0;
        self.total_reward = 0;
        return self.getState();
    }

    /// [CYR:[EN]]and[EN] [EN]to[CYR:[EN]] with[EN]with[CYR:[EN]]and[EN] (index)
    pub fn getState(self: *const GridWorld) usize {
        return self.agent_pos.toIndex(self.width);
    }

    /// [CYR:[EN]]and[EN]with[EN]in[EN] with[EN]with[CYR:[EN]]and[EN]
    pub fn numStates(self: *const GridWorld) usize {
        return self.width * self.height;
    }

    /// [EN]by[EN]and[EN] [CYR:[EN]]with[EN]inand[EN]
    pub fn step(self: *GridWorld, action: usize) StepResult {
        self.steps += 1;

        // Compute [EN]in[EN] by[EN]and[EN]and[EN]
        var new_pos = self.agent_pos;
        switch (@as(Action, @enumFromInt(action))) {
            .UP => {
                if (new_pos.y > 0) new_pos.y -= 1;
            },
            .RIGHT => {
                if (new_pos.x < self.width - 1) new_pos.x += 1;
            },
            .DOWN => {
                if (new_pos.y < self.height - 1) new_pos.y += 1;
            },
            .LEFT => {
                if (new_pos.x > 0) new_pos.x -= 1;
            },
        }

        // Check with[CYR:[EN]]
        const new_idx = new_pos.toIndex(self.width);
        var reward = self.config.step_reward;
        var info: []const u8 = "step";

        if (self.walls[new_idx]) {
            // [CYR:[EN]]andwith[EN] in with[CYR:[EN]] - [EN]with[CYR:[EN]]with[EN] on [EN]with[EN]
            reward = self.config.wall_reward;
            info = "wall";
        } else {
            self.agent_pos = new_pos;
        }

        // Check goal
        var done = false;
        if (self.agent_pos.eql(self.goal_pos)) {
            reward = self.config.goal_reward;
            done = true;
            info = "goal";
        }

        // Check [EN]and[EN]and[EN] step[EN]in
        if (self.steps >= self.config.max_steps) {
            done = true;
            info = "timeout";
        }

        self.total_reward += reward;

        return .{
            .next_state = self.getState(),
            .reward = reward,
            .done = done,
            .info = info,
        };
    }

    /// [CYR:[EN]]inand[EN] with[CYR:[EN]]
    pub fn addWall(self: *GridWorld, x: usize, y: usize) void {
        if (x < self.width and y < self.height) {
            const idx = y * self.width + x;
            self.walls[idx] = true;
        }
    }

    /// [EN]and[CYR:[EN]]and[CYR:[EN]]and[EN] in ASCII
    pub fn render(self: *const GridWorld) void {
        std.debug.print("\n", .{});
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const pos = Position{ .x = x, .y = y };
                const idx = pos.toIndex(self.width);

                if (self.agent_pos.eql(pos)) {
                    std.debug.print(" A ", .{});
                } else if (self.goal_pos.eql(pos)) {
                    std.debug.print(" G ", .{});
                } else if (self.walls[idx]) {
                    std.debug.print(" # ", .{});
                } else {
                    std.debug.print(" . ", .{});
                }
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("Steps: {d}, Reward: {d:.2}\n", .{ self.steps, self.total_reward });
    }

    /// [CYR:[EN]]and[EN] [CYR:[EN]]and[CYR:[EN]] [EN]withwith[CYR:[EN]]and[EN] before [CYR:[EN]]and (Manhattan)
    pub fn distanceToGoal(self: *const GridWorld) usize {
        const dx = if (self.agent_pos.x > self.goal_pos.x)
            self.agent_pos.x - self.goal_pos.x
        else
            self.goal_pos.x - self.agent_pos.x;

        const dy = if (self.agent_pos.y > self.goal_pos.y)
            self.agent_pos.y - self.goal_pos.y
        else
            self.goal_pos.y - self.agent_pos.y;

        return dx + dy;
    }
};

// ═══════════════════════════════════════════════════════════════
// [CYR:[EN]]
// ═══════════════════════════════════════════════════════════════

test "gridworld init" {
    const allocator = std.testing.allocator;
    var env = try GridWorld.init(allocator, .{ .width = 4, .height = 4 });
    defer env.deinit();

    try std.testing.expectEqual(@as(usize, 0), env.getState());
    try std.testing.expectEqual(@as(usize, 16), env.numStates());
}

test "gridworld step right" {
    const allocator = std.testing.allocator;
    var env = try GridWorld.init(allocator, .{ .width = 4, .height = 4 });
    defer env.deinit();

    _ = env.reset();
    const result = env.step(@intFromEnum(Action.RIGHT));

    try std.testing.expectEqual(@as(usize, 1), result.next_state);
    try std.testing.expect(!result.done);
}

test "gridworld reach goal" {
    const allocator = std.testing.allocator;
    var env = try GridWorld.init(allocator, .{ .width = 2, .height = 2 });
    defer env.deinit();

    _ = env.reset();
    // (0,0) -> RIGHT -> (1,0) -> DOWN -> (1,1) = GOAL
    _ = env.step(@intFromEnum(Action.RIGHT));
    const result = env.step(@intFromEnum(Action.DOWN));

    try std.testing.expect(result.done);
    try std.testing.expectEqual(@as(f64, 10.0), result.reward);
}

test "gridworld wall collision" {
    const allocator = std.testing.allocator;
    var env = try GridWorld.init(allocator, .{ .width = 3, .height = 3 });
    defer env.deinit();

    env.addWall(1, 0);
    _ = env.reset();

    // [CYR:[EN]]with[EN] by[EN]and in with[CYR:[EN]]
    const result = env.step(@intFromEnum(Action.RIGHT));

    try std.testing.expectEqual(@as(usize, 0), result.next_state); // [EN]with[CYR:[EN]]andwith[EN] on [EN]with[EN]
    try std.testing.expectEqual(@as(f64, -1.0), result.reward);
}

test "gridworld boundary" {
    const allocator = std.testing.allocator;
    var env = try GridWorld.init(allocator, .{ .width = 2, .height = 2 });
    defer env.deinit();

    _ = env.reset();
    // [CYR:[EN]]with[EN] in[CYR:[EN]]and [EN] [CYR:[EN]]and[EN]
    const result = env.step(@intFromEnum(Action.UP));

    try std.testing.expectEqual(@as(usize, 0), result.next_state); // [EN]with[CYR:[EN]]andwith[EN] on [EN]with[EN]
}
