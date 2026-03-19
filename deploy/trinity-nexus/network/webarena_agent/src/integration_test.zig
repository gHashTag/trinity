// WebArena Integration Test
// Tests browser bridge with mock responses
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const sim = @import("task_simulator.zig");
const bridge = @import("browser_bridge.zig");
const loader = @import("task_loader.zig");
const full_sim = @import("full_simulation.zig");

// Mock browser response for testing
pub const MockResponse = struct {
    success: bool,
    url: []const u8,
    title: []const u8,
    elements_count: u32,
    detected: bool,
};

// Mock browser for integration testing
pub const MockBrowser = struct {
    responses: std.ArrayList(MockResponse),
    current_index: usize,
    rng: sim.PhiRng,

    pub fn init(allocator: std.mem.Allocator, seed: u64) MockBrowser {
        return .{
            .responses = std.ArrayList(MockResponse).init(allocator),
            .current_index = 0,
            .rng = sim.PhiRng.init(seed),
        };
    }

    pub fn deinit(self: *MockBrowser) void {
        self.responses.deinit();
    }

    pub fn addResponse(self: *MockBrowser, response: MockResponse) !void {
        try self.responses.append(response);
    }

    pub fn getNextResponse(self: *MockBrowser) ?MockResponse {
        if (self.current_index < self.responses.items.len) {
            const resp = self.responses.items[self.current_index];
            self.current_index += 1;
            return resp;
        }
        // Generate random response if no more mocked
        return MockResponse{
            .success = self.rng.float() < 0.5,
            .url = "http://mock",
            .title = "Mock Page",
            .elements_count = @as(u32, @intCast(self.rng.next() % 100)),
            .detected = self.rng.float() < 0.2,
        };
    }

    pub fn reset(self: *MockBrowser) void {
        self.current_index = 0;
    }
};

// Integration test suite
pub const IntegrationTestSuite = struct {
    allocator: std.mem.Allocator,
    mock_browser: MockBrowser,
    test_results: std.ArrayList(TestResult),

    pub const TestResult = struct {
        name: []const u8,
        passed: bool,
        message: []const u8,
        duration_ms: u64,
    };

    pub fn init(allocator: std.mem.Allocator, seed: u64) IntegrationTestSuite {
        return .{
            .allocator = allocator,
            .mock_browser = MockBrowser.init(allocator, seed),
            .test_results = std.ArrayList(TestResult).init(allocator),
        };
    }

    pub fn deinit(self: *IntegrationTestSuite) void {
        self.mock_browser.deinit();
        self.test_results.deinit();
    }

    // Test: Bridge connection
    pub fn testBridgeConnection(self: *IntegrationTestSuite) !void {
        const start = std.time.milliTimestamp();

        var test_bridge = bridge.BrowserBridge.init(self.allocator, true, 42);
        try test_bridge.connect();

        const passed = test_bridge.connected and test_bridge.fingerprint_similarity > 0.80;

        test_bridge.disconnect();

        try self.test_results.append(.{
            .name = "bridge_connection",
            .passed = passed,
            .message = if (passed) "Bridge connected with stealth" else "Connection failed",
            .duration_ms = @as(u64, @intCast(std.time.milliTimestamp() - start)),
        });
    }

    // Test: Fingerprint evolution
    pub fn testFingerprintEvolution(self: *IntegrationTestSuite) !void {
        const start = std.time.milliTimestamp();

        var test_bridge = bridge.BrowserBridge.init(self.allocator, true, 42);
        const initial = test_bridge.fingerprint_similarity;
        test_bridge.evolveFingerprint(20);
        const final = test_bridge.fingerprint_similarity;

        const passed = final > initial and final > 0.90;

        try self.test_results.append(.{
            .name = "fingerprint_evolution",
            .passed = passed,
            .message = if (passed) "Evolution improved similarity" else "Evolution failed",
            .duration_ms = @as(u64, @intCast(std.time.milliTimestamp() - start)),
        });
    }

    // Test: Task loader
    pub fn testTaskLoader(self: *IntegrationTestSuite) !void {
        const start = std.time.milliTimestamp();

        const sample_json =
            \\[{"task_id": 0, "sites": ["shopping"], "intent": "test", "start_url": "http://test", "require_login": false, "require_reset": false}]
        ;

        var task_loader = loader.TaskLoader.init(self.allocator);
        defer task_loader.deinit();

        task_loader.loadFromString(sample_json) catch {
            try self.test_results.append(.{
                .name = "task_loader",
                .passed = false,
                .message = "Failed to parse JSON",
                .duration_ms = @as(u64, @intCast(std.time.milliTimestamp() - start)),
            });
            return;
        };

        const passed = task_loader.count() == 1;

        try self.test_results.append(.{
            .name = "task_loader",
            .passed = passed,
            .message = if (passed) "Loaded 1 task" else "Wrong task count",
            .duration_ms = @as(u64, @intCast(std.time.milliTimestamp() - start)),
        });
    }

    // Test: Full simulation consistency
    pub fn testSimulationConsistency(self: *IntegrationTestSuite) !void {
        const start = std.time.milliTimestamp();

        // Run same simulation twice with same seed
        const result1 = full_sim.runFullSimulation(true, 42);
        const result2 = full_sim.runFullSimulation(true, 42);

        const passed = result1.overall_success == result2.overall_success and
            result1.total_passed == result2.total_passed;

        try self.test_results.append(.{
            .name = "simulation_consistency",
            .passed = passed,
            .message = if (passed) "Deterministic with same seed" else "Non-deterministic results",
            .duration_ms = @as(u64, @intCast(std.time.milliTimestamp() - start)),
        });
    }

    // Test: Stealth advantage
    pub fn testStealthAdvantage(self: *IntegrationTestSuite) !void {
        const start = std.time.milliTimestamp();

        const baseline = full_sim.runFullSimulation(false, 42);
        const stealth = full_sim.runFullSimulation(true, 42);

        const passed = stealth.overall_success > baseline.overall_success and
            stealth.overall_detection < baseline.overall_detection;

        try self.test_results.append(.{
            .name = "stealth_advantage",
            .passed = passed,
            .message = if (passed) "Stealth improves success" else "No stealth advantage",
            .duration_ms = @as(u64, @intCast(std.time.milliTimestamp() - start)),
        });
    }

    // Test: Category distribution
    pub fn testCategoryDistribution(self: *IntegrationTestSuite) !void {
        const start = std.time.milliTimestamp();

        const dist = full_sim.TaskDistribution;
        const sum = dist.SHOPPING + dist.SHOPPING_ADMIN + dist.GITLAB +
            dist.REDDIT + dist.MAP + dist.WIKIPEDIA + dist.CROSS_SITE;

        const passed = sum == 812;

        try self.test_results.append(.{
            .name = "category_distribution",
            .passed = passed,
            .message = if (passed) "Distribution sums to 812" else "Wrong distribution",
            .duration_ms = @as(u64, @intCast(std.time.milliTimestamp() - start)),
        });
    }

    // Run all tests
    pub fn runAll(self: *IntegrationTestSuite) !void {
        try self.testBridgeConnection();
        try self.testFingerprintEvolution();
        try self.testTaskLoader();
        try self.testSimulationConsistency();
        try self.testStealthAdvantage();
        try self.testCategoryDistribution();
    }

    // Print results
    pub fn printResults(self: *const IntegrationTestSuite) void {
        const stdout = std.io.getStdOut().writer();

        stdout.print("\n", .{}) catch {};
        stdout.print("╔══════════════════════════════════════════════════════════════════╗\n", .{}) catch {};
        stdout.print("║              WEBARENA INTEGRATION TEST RESULTS                   ║\n", .{}) catch {};
        stdout.print("╠══════════════════════════════════════════════════════════════════╣\n", .{}) catch {};

        var passed: u32 = 0;
        var failed: u32 = 0;

        for (self.test_results.items) |result| {
            const status = if (result.passed) "✅ PASS" else "❌ FAIL";
            if (result.passed) {
                passed += 1;
            } else {
                failed += 1;
            }
            stdout.print("║ {s} │ {s: <25} │ {d}ms          ║\n", .{
                status,
                result.name,
                result.duration_ms,
            }) catch {};
        }

        stdout.print("╠══════════════════════════════════════════════════════════════════╣\n", .{}) catch {};
        stdout.print("║ TOTAL: {d} passed, {d} failed                                     ║\n", .{ passed, failed }) catch {};

        if (failed == 0) {
            stdout.print("║ STATUS: ✅ ALL TESTS PASSED                                      ║\n", .{}) catch {};
        } else {
            stdout.print("║ STATUS: ❌ SOME TESTS FAILED                                     ║\n", .{}) catch {};
        }

        stdout.print("╚══════════════════════════════════════════════════════════════════╝\n", .{}) catch {};
    }

    // Get pass rate
    pub fn getPassRate(self: *const IntegrationTestSuite) f64 {
        if (self.test_results.items.len == 0) return 0.0;
        var passed: u32 = 0;
        for (self.test_results.items) |r| {
            if (r.passed) passed += 1;
        }
        return @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(self.test_results.items.len));
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n🔥 WebArena Integration Test Suite\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════\n", .{});

    const seed = @as(u64, @intCast(std.time.milliTimestamp()));

    var suite = IntegrationTestSuite.init(allocator, seed);
    defer suite.deinit();

    try stdout.print("\nRunning integration tests...\n", .{});
    try suite.runAll();

    suite.printResults();

    const pass_rate = suite.getPassRate();
    try stdout.print("\nPass Rate: {d:.1}%\n", .{pass_rate * 100});

    if (pass_rate == 1.0) {
        try stdout.print("\n✅ Integration ready for real browser testing\n", .{});
    } else {
        try stdout.print("\n⚠️  Some tests failed - review before real testing\n", .{});
    }

    try stdout.print("\nφ² + 1/φ² = 3 = TRINITY\n", .{});
}

test "mock_browser" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var mock = MockBrowser.init(allocator, 42);
    defer mock.deinit();

    try mock.addResponse(.{
        .success = true,
        .url = "http://test",
        .title = "Test",
        .elements_count = 10,
        .detected = false,
    });

    const resp = mock.getNextResponse();
    try std.testing.expect(resp != null);
    try std.testing.expect(resp.?.success);
}

test "integration_suite" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var suite = IntegrationTestSuite.init(allocator, 42);
    defer suite.deinit();

    try suite.testBridgeConnection();
    try std.testing.expect(suite.test_results.items.len == 1);
}
