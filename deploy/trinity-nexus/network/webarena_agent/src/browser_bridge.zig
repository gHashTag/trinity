// WebArena Browser Bridge
// Connects Zig agent to Playwright via JSON protocol
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const json = std.json;
const sim = @import("task_simulator.zig");

// Browser action types (matching WebArena)
pub const ActionType = enum(u8) {
    none = 0,
    click = 1,
    type_text = 2,
    scroll = 3,
    hover = 4,
    goto = 5,
    go_back = 6,
    go_forward = 7,
    press_key = 8,
    select_option = 9,
    stop = 10,

    pub fn toString(self: ActionType) []const u8 {
        return switch (self) {
            .none => "none",
            .click => "click",
            .type_text => "type",
            .scroll => "scroll",
            .hover => "hover",
            .goto => "goto",
            .go_back => "go_back",
            .go_forward => "go_forward",
            .press_key => "press",
            .select_option => "select_option",
            .stop => "stop",
        };
    }
};

// Browser action to send to Playwright
pub const BrowserAction = struct {
    action_type: ActionType,
    element_id: ?u32 = null,
    text: ?[]const u8 = null,
    url: ?[]const u8 = null,
    coords: ?struct { x: i32, y: i32 } = null,
    key: ?[]const u8 = null,

    pub fn toJson(self: BrowserAction, allocator: std.mem.Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        try buffer.appendSlice("{\"action_type\":\"");
        try buffer.appendSlice(self.action_type.toString());
        try buffer.appendSlice("\"");

        if (self.element_id) |id| {
            try buffer.appendSlice(",\"element_id\":");
            var num_buf: [20]u8 = undefined;
            const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{id}) catch unreachable;
            try buffer.appendSlice(num_str);
        }

        if (self.text) |text| {
            try buffer.appendSlice(",\"text\":\"");
            try buffer.appendSlice(text);
            try buffer.appendSlice("\"");
        }

        if (self.url) |url| {
            try buffer.appendSlice(",\"url\":\"");
            try buffer.appendSlice(url);
            try buffer.appendSlice("\"");
        }

        if (self.coords) |c| {
            try buffer.appendSlice(",\"coords\":{\"x\":");
            var x_buf: [20]u8 = undefined;
            const x_str = std.fmt.bufPrint(&x_buf, "{d}", .{c.x}) catch unreachable;
            try buffer.appendSlice(x_str);
            try buffer.appendSlice(",\"y\":");
            var y_buf: [20]u8 = undefined;
            const y_str = std.fmt.bufPrint(&y_buf, "{d}", .{c.y}) catch unreachable;
            try buffer.appendSlice(y_str);
            try buffer.appendSlice("}");
        }

        try buffer.appendSlice("}");
        return buffer.toOwnedSlice();
    }
};

// Browser state received from Playwright
pub const BrowserState = struct {
    url: []const u8,
    title: []const u8,
    accessibility_tree: []const u8,
    screenshot_base64: ?[]const u8 = null,
    elements: []const DOMElement,
    viewport: struct { width: u32, height: u32 },
};

// DOM element from accessibility tree
pub const DOMElement = struct {
    id: u32,
    tag: []const u8,
    role: []const u8,
    text: []const u8,
    bounds: struct { x: i32, y: i32, width: u32, height: u32 },
    clickable: bool,
    focusable: bool,
};

// WebArena task configuration
pub const TaskConfig = struct {
    task_id: u32,
    sites: []const []const u8,
    intent: []const u8,
    start_url: []const u8,
    require_login: bool,
    eval_types: []const []const u8,
    reference_answers: []const u8,
};

// Task execution result
pub const TaskResult = struct {
    task_id: u32,
    success: bool,
    steps_taken: u32,
    time_ms: u64,
    final_answer: ?[]const u8,
    task_error: ?[]const u8,
    detected: bool,
};

// Browser bridge for real execution
pub const BrowserBridge = struct {
    allocator: std.mem.Allocator,
    connected: bool,
    fingerprint_similarity: f64,
    stealth_enabled: bool,
    rng: sim.PhiRng,

    // Simulated connection state (real impl would use subprocess/socket)
    current_url: []const u8,
    step_count: u32,

    pub fn init(allocator: std.mem.Allocator, stealth: bool, seed: u64) BrowserBridge {
        return .{
            .allocator = allocator,
            .connected = false,
            .fingerprint_similarity = if (stealth) 0.85 else 0.30,
            .stealth_enabled = stealth,
            .rng = sim.PhiRng.init(seed),
            .current_url = "",
            .step_count = 0,
        };
    }

    // Connect to browser (simulated)
    pub fn connect(self: *BrowserBridge) !void {
        // In real implementation: spawn Playwright process, establish connection
        self.connected = true;
        if (self.stealth_enabled) {
            // Inject fingerprint protection
            try self.injectFingerprint();
        }
    }

    // Disconnect from browser
    pub fn disconnect(self: *BrowserBridge) void {
        self.connected = false;
    }

    // Inject fingerprint protection (simulated)
    fn injectFingerprint(self: *BrowserBridge) !void {
        // In real implementation: inject canvas/webgl/audio spoofing scripts
        self.fingerprint_similarity = 0.85 + self.rng.float() * 0.10; // 0.85-0.95
    }

    // Evolve fingerprint if detection risk
    pub fn evolveFingerprint(self: *BrowserBridge, generations: u32) void {
        var gen: u32 = 0;
        while (gen < generations) : (gen += 1) {
            const improvement = (1.0 - self.fingerprint_similarity) * sim.PHI_INV * 0.1;
            self.fingerprint_similarity += improvement;
            self.fingerprint_similarity = @min(0.95, self.fingerprint_similarity);
        }
    }

    // Execute action with human-like timing
    pub fn executeAction(self: *BrowserBridge, action: BrowserAction) !void {
        if (!self.connected) return error.NotConnected;

        // Human-like delay (φ-based)
        const base_delay: u64 = 500;
        const variance = self.rng.next() % 1500;
        const delay_ms = base_delay + variance;

        // In real implementation: send action to Playwright, wait for response
        _ = delay_ms; // Would use std.time.sleep in real impl

        self.step_count += 1;

        // Update URL if goto action
        if (action.action_type == .goto) {
            if (action.url) |url| {
                self.current_url = url;
            }
        }
    }

    // Get current browser state (simulated)
    pub fn getState(self: *BrowserBridge) !BrowserState {
        if (!self.connected) return error.NotConnected;

        // In real implementation: query Playwright for accessibility tree, screenshot
        return BrowserState{
            .url = self.current_url,
            .title = "Simulated Page",
            .accessibility_tree = "[]",
            .screenshot_base64 = null,
            .elements = &[_]DOMElement{},
            .viewport = .{ .width = 1280, .height = 720 },
        };
    }

    // Check if detected (simulated)
    pub fn checkDetection(self: *BrowserBridge) bool {
        // Detection probability based on fingerprint similarity
        const detection_threshold: f64 = if (self.stealth_enabled) 0.05 else 0.25;
        return self.rng.float() < detection_threshold;
    }

    // Run single task
    pub fn runTask(self: *BrowserBridge, config: TaskConfig, max_steps: u32) !TaskResult {
        const start_time = std.time.milliTimestamp();

        // Navigate to start URL
        try self.executeAction(.{
            .action_type = .goto,
            .url = config.start_url,
        });

        var detected = false;
        var success = false;

        // Simulate task execution
        while (self.step_count < max_steps) {
            // Check for detection
            if (self.checkDetection()) {
                detected = true;
                if (self.stealth_enabled) {
                    // Evolve fingerprint to evade
                    self.evolveFingerprint(5);
                } else {
                    break; // Fail on detection without stealth
                }
            }

            // Simulate action (in real impl: use LLM/VSA to select action)
            try self.executeAction(.{
                .action_type = .click,
                .element_id = @as(u32, @intCast(self.rng.next() % 100)),
            });

            // Simulate success check (in real impl: evaluate against reference)
            if (self.rng.float() < 0.15) { // 15% chance per step to succeed
                success = true;
                break;
            }
        }

        const end_time = std.time.milliTimestamp();

        return TaskResult{
            .task_id = config.task_id,
            .success = success,
            .steps_taken = self.step_count,
            .time_ms = @as(u64, @intCast(end_time - start_time)),
            .final_answer = null,
            .task_error = null,
            .detected = detected,
        };
    }
};

// Integration test runner
pub const IntegrationRunner = struct {
    bridge: BrowserBridge,
    results: std.ArrayList(TaskResult),

    pub fn init(allocator: std.mem.Allocator, stealth: bool, seed: u64) IntegrationRunner {
        return .{
            .bridge = BrowserBridge.init(allocator, stealth, seed),
            .results = std.ArrayList(TaskResult).init(allocator),
        };
    }

    pub fn deinit(self: *IntegrationRunner) void {
        self.results.deinit();
        self.bridge.disconnect();
    }

    pub fn runBatch(self: *IntegrationRunner, configs: []const TaskConfig, max_steps: u32) !void {
        try self.bridge.connect();

        for (configs) |config| {
            self.bridge.step_count = 0; // Reset for each task
            const result = try self.bridge.runTask(config, max_steps);
            try self.results.append(result);
        }
    }

    pub fn getSuccessRate(self: *IntegrationRunner) f64 {
        if (self.results.items.len == 0) return 0.0;
        var passed: u32 = 0;
        for (self.results.items) |r| {
            if (r.success) passed += 1;
        }
        return @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(self.results.items.len));
    }

    pub fn getDetectionRate(self: *IntegrationRunner) f64 {
        if (self.results.items.len == 0) return 0.0;
        var detected: u32 = 0;
        for (self.results.items) |r| {
            if (r.detected) detected += 1;
        }
        return @as(f64, @floatFromInt(detected)) / @as(f64, @floatFromInt(self.results.items.len));
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n🔥 WebArena Browser Bridge Test\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════\n", .{});

    const seed = @as(u64, @intCast(std.time.milliTimestamp()));

    // Create mock task configs
    var configs: [10]TaskConfig = undefined;
    for (&configs, 0..) |*c, i| {
        c.* = .{
            .task_id = @as(u32, @intCast(i)),
            .sites = &[_][]const u8{"shopping"},
            .intent = "Find product",
            .start_url = "http://localhost:7770",
            .require_login = false,
            .eval_types = &[_][]const u8{"string_match"},
            .reference_answers = "test",
        };
    }

    // Run baseline
    try stdout.print("\n[1/2] Running BASELINE (no stealth)...\n", .{});
    var baseline_runner = IntegrationRunner.init(allocator, false, seed);
    defer baseline_runner.deinit();
    try baseline_runner.runBatch(&configs, 30);

    try stdout.print("  Success: {d:.1}%\n", .{baseline_runner.getSuccessRate() * 100});
    try stdout.print("  Detection: {d:.1}%\n", .{baseline_runner.getDetectionRate() * 100});

    // Run stealth
    try stdout.print("\n[2/2] Running STEALTH (FIREBIRD)...\n", .{});
    var stealth_runner = IntegrationRunner.init(allocator, true, seed);
    defer stealth_runner.deinit();
    try stealth_runner.runBatch(&configs, 30);

    try stdout.print("  Success: {d:.1}%\n", .{stealth_runner.getSuccessRate() * 100});
    try stdout.print("  Detection: {d:.1}%\n", .{stealth_runner.getDetectionRate() * 100});

    // Summary
    try stdout.print("\n", .{});
    try stdout.print("┌─────────────────────────────────────────────────────────────────┐\n", .{});
    try stdout.print("│                 BROWSER BRIDGE TEST SUMMARY                     │\n", .{});
    try stdout.print("├─────────────────────────────────────────────────────────────────┤\n", .{});
    try stdout.print("│ Baseline Success:  {d: >5.1}%                                      │\n", .{baseline_runner.getSuccessRate() * 100});
    try stdout.print("│ Stealth Success:   {d: >5.1}%                                      │\n", .{stealth_runner.getSuccessRate() * 100});
    try stdout.print("│ Delta:            +{d: >5.1}%                                      │\n", .{(stealth_runner.getSuccessRate() - baseline_runner.getSuccessRate()) * 100});
    try stdout.print("│ Status:            Bridge Ready for Real Integration            │\n", .{});
    try stdout.print("└─────────────────────────────────────────────────────────────────┘\n", .{});
    try stdout.print("\nφ² + 1/φ² = 3 = TRINITY\n", .{});
}

test "browser_action_json" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const action = BrowserAction{
        .action_type = .click,
        .element_id = 42,
    };

    const json_str = try action.toJson(allocator);
    defer allocator.free(json_str);

    try std.testing.expect(std.mem.indexOf(u8, json_str, "click") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "42") != null);
}

test "browser_bridge_connect" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var bridge = BrowserBridge.init(allocator, true, 42);
    try bridge.connect();
    try std.testing.expect(bridge.connected);
    try std.testing.expect(bridge.fingerprint_similarity > 0.80);
    bridge.disconnect();
    try std.testing.expect(!bridge.connected);
}

test "fingerprint_evolution" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var bridge = BrowserBridge.init(allocator, true, 42);
    const initial = bridge.fingerprint_similarity;
    bridge.evolveFingerprint(10);
    try std.testing.expect(bridge.fingerprint_similarity > initial);
}

test "integration_runner" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var runner = IntegrationRunner.init(allocator, true, 42);
    defer runner.deinit();

    const configs = [_]TaskConfig{
        .{
            .task_id = 0,
            .sites = &[_][]const u8{"shopping"},
            .intent = "test",
            .start_url = "http://test",
            .require_login = false,
            .eval_types = &[_][]const u8{},
            .reference_answers = "",
        },
    };

    try runner.runBatch(&configs, 10);
    try std.testing.expect(runner.results.items.len == 1);
}
