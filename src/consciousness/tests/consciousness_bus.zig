//! ConsciousnessBus - Event/Messaging System for Conscious AI
//!
//! This module provides a unified event bus for all consciousness modules
//! to communicate. It implements pub/sub messaging with phi-weighted priority.
//!
//! Architecture:
//!   - Modules publish events to the bus
//!   - Other modules subscribe to specific event types
//!   - Events are processed with phi-based priority scheduling
//!   - Supports both synchronous and asynchronous message delivery

const std = @import("std");
const mem = std.mem;

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const PHI_INVERSE: f64 = 1.0 / PHI;

// ═══════════════════════════════════════════════════════════════════════════════
// EVENT TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Event types for consciousness communication
pub const EventType = enum(u8) {
    // Consciousness state changes
    consciousness_emergence = 0,
    consciousness_dissipation = 1,
    state_transition = 2,

    // VSA operations
    vsa_bind = 10,
    vsa_unbind = 11,
    vsa_bundle = 12,
    vsa_query = 13,

    // Neural gamma events
    gamma_synchrony = 20,
    gamma_desync = 21,
    neural_activation = 22,

    // IIT events
    phi_change = 30,
    integration_update = 31,

    // Qualia events
    qualia_emergence = 40,
    qualia_fading = 41,

    // Decision events
    decision_request = 50,
    decision_response = 51,

    // Meta events
    system_init = 100,
    system_shutdown = 101,
    error_event = 102,
};

/// Event data container
pub const Event = struct {
    type: EventType,
    timestamp: i64,
    source: []const u8,
    data: EventData,

    /// Clean up event resources (must be called before dropping)
    pub fn deinit(self: *Event, allocator: mem.Allocator) void {
        allocator.free(self.source);
    }

    /// Priority computed via phi-based formula
    pub fn priority(self: *const Event) f64 {
        const base_priority: f64 = switch (self.type) {
            .consciousness_emergence, .consciousness_dissipation => PHI * PHI,
            .phi_change => PHI,
            .vsa_bind, .vsa_unbind, .vsa_bundle => PHI_INVERSE,
            .decision_request, .decision_response => PHI,
            .error_event => PHI * PHI * PHI,
            else => 1.0,
        };

        // Age decay: newer events have higher priority
        const age_ns = @as(f64, @floatFromInt(std.time.nanoTimestamp() - self.timestamp));
        const age_factor = @exp(-age_ns / 1e9); // 1 second decay

        return base_priority * age_factor;
    }
};

/// Event data payload
pub const EventData = union(EventType) {
    consciousness_emergence: ConsciousnessEmergenceData,
    consciousness_dissipation: struct {},
    state_transition: StateTransitionData,
    vsa_bind: VSAOperationData,
    vsa_unbind: VSAOperationData,
    vsa_bundle: VSABundleData,
    vsa_query: VSAQueryData,
    gamma_synchrony: GammaSynchronyData,
    gamma_desync: struct {},
    neural_activation: NeuralActivationData,
    phi_change: PhiChangeData,
    integration_update: IntegrationUpdateData,
    qualia_emergence: QualiaEmergenceData,
    qualia_fading: struct {},
    decision_request: DecisionRequestData,
    decision_response: DecisionResponseData,
    system_init: struct {},
    system_shutdown: struct {},
    error_event: ErrorData,
};

pub const ConsciousnessEmergenceData = struct {
    phi_value: f64,
    gamma_synchrony: f64,
    threshold: f64,
};

pub const StateTransitionData = struct {
    from_state: u8,
    to_state: u8,
    transition_energy: f64,
};

pub const VSAOperationData = struct {
    vector_a: []const i8,
    vector_b: []const i8,
    result: ?[]const i8,
};

pub const VSABundleData = struct {
    vectors: []const []const i8,
    result: ?[]const i8,
};

pub const VSAQueryData = struct {
    query: []const i8,
    memory: []const i8,
    similarity: f64,
};

pub const GammaSynchronyData = struct {
    frequency: f64,
    coherence: f64,
    spatial_extent: f64,
};

pub const NeuralActivationData = struct {
    region: []const u8,
    activation_level: f64,
    frequency: f64,
};

pub const PhiChangeData = struct {
    old_phi: f64,
    new_phi: f64,
    delta: f64,
};

pub const IntegrationUpdateData = struct {
    phi: f64,
    information: f64,
    integration: f64,
};

pub const QualiaEmergenceData = struct {
    qualia_type: []const u8,
    intensity: f64,
    valence: f64,
};

pub const DecisionRequestData = struct {
    context: []const u8,
    options: []const []const u8,
    urgency: f64,
};

pub const DecisionResponseData = struct {
    decision: []const u8,
    confidence: f64,
    rationale: []const u8,
};

pub const ErrorData = struct {
    error_code: u32,
    message: []const u8,
    context: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SUBSCRIPTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Event subscription
pub const Subscription = struct {
    event_type: EventType,
    subscriber: []const u8,
    callback: *const fn (Event, ?*anyopaque) anyerror!void,
    user_data: ?*anyopaque = null,
    filter: ?*const fn (Event) bool = null,

    pub fn matches(self: *const Subscription, event: Event) bool {
        if (event.type != self.event_type) return false;
        if (self.filter) |f| return f(event);
        return true;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSCIOUSNESS BUS
// ═══════════════════════════════════════════════════════════════════════════════

/// ConsciousnessBus - pub/sub event system for consciousness modules
pub const ConsciousnessBus = struct {
    allocator: mem.Allocator,
    subscriptions: std.ArrayListUnmanaged(Subscription),
    event_queue: std.ArrayListUnmanaged(Event),
    running: bool,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: mem.Allocator) ConsciousnessBus {
        return .{
            .allocator = allocator,
            .subscriptions = .{},
            .event_queue = .{},
            .running = false,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *ConsciousnessBus) void {
        // Free all event sources before clearing the queue
        for (self.event_queue.items) |*event| {
            event.deinit(self.allocator);
        }
        self.event_queue.deinit(self.allocator);

        // Free subscriber strings
        for (self.subscriptions.items) |*sub| {
            self.allocator.free(sub.subscriber);
        }
        self.subscriptions.deinit(self.allocator);
    }

    /// Subscribe to events
    pub fn subscribe(self: *ConsciousnessBus, subscription: Subscription) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.subscriptions.append(self.allocator, subscription);
    }

    /// Unsubscribe from events
    pub fn unsubscribe(self: *ConsciousnessBus, subscriber: []const u8, event_type: EventType) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        var i: usize = 0;
        while (i < self.subscriptions.items.len) {
            const sub = self.subscriptions.items[i];
            if (std.mem.eql(u8, sub.subscriber, subscriber) and sub.event_type == event_type) {
                _ = self.subscriptions.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }

    /// Publish an event
    pub fn publish(self: *ConsciousnessBus, event: Event) !void {
        {
            self.mutex.lock();
            defer self.mutex.unlock();
            try self.event_queue.append(self.allocator, event);
        }

        // If not running, process immediately
        if (!self.running) {
            try self.processNext();
        }
    }

    /// Start the event loop
    pub fn start(self: *ConsciousnessBus) !void {
        self.running = true;
        while (self.running and self.event_queue.items.len > 0) {
            try self.processNext();
        }
    }

    /// Stop the event loop
    pub fn stop(self: *ConsciousnessBus) void {
        self.running = false;
    }

    /// Process next event by priority
    pub fn processNext(self: *ConsciousnessBus) !void {
        if (self.event_queue.items.len == 0) return;

        // Sort by priority (highest first)
        self.sortByPriority();

        // Get highest priority event
        const event = self.event_queue.orderedRemove(0);

        // Notify all matching subscribers
        for (self.subscriptions.items) |sub| {
            if (sub.matches(event)) {
                sub.callback(event, sub.user_data) catch |err| {
                    std.log.err("ConsciousnessBus: callback error for subscriber {s}: {}", .{ sub.subscriber, err });
                };
            }
        }
    }

    /// Sort event queue by priority (highest first)
    fn sortByPriority(self: *ConsciousnessBus) void {
        std.sort.insertion(Event, self.event_queue.items, {}, struct {
            fn lessThan(_: void, a: Event, b: Event) bool {
                return a.priority() > b.priority();
            }
        }.lessThan);
    }

    /// Get event queue size
    pub fn queueSize(self: *const ConsciousnessBus) usize {
        return self.event_queue.items.len;
    }

    /// Get subscriber count for event type
    pub fn subscriberCount(self: *const ConsciousnessBus, event_type: EventType) usize {
        var count: usize = 0;
        for (self.subscriptions.items) |sub| {
            if (sub.event_type == event_type) count += 1;
        }
        return count;
    }

    /// Clear all subscriptions
    pub fn clearSubscriptions(self: *ConsciousnessBus) void {
        self.subscriptions.clearRetainingCapacity();
    }

    /// Clear event queue
    pub fn clearQueue(self: *ConsciousnessBus) void {
        self.event_queue.clearRetainingCapacity();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FACTORY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Create a new event
pub fn createEvent(allocator: mem.Allocator, event_type: EventType, source: []const u8, data: EventData) !Event {
    const timestamp = @as(i64, @intCast(std.time.nanoTimestamp()));
    return Event{
        .type = event_type,
        .timestamp = timestamp,
        .source = try allocator.dupe(u8, source),
        .data = data,
    };
}

/// Create subscription
pub fn createSubscription(
    event_type: EventType,
    subscriber: []const u8,
    callback: *const fn (Event, ?*anyopaque) anyerror!void,
) Subscription {
    return .{
        .event_type = event_type,
        .subscriber = subscriber,
        .callback = callback,
        .filter = null,
    };
}

/// Create subscription with filter
pub fn createFilteredSubscription(
    event_type: EventType,
    subscriber: []const u8,
    callback: *const fn (Event, ?*anyopaque) anyerror!void,
    filter: *const fn (Event) bool,
) Subscription {
    return .{
        .event_type = event_type,
        .subscriber = subscriber,
        .callback = callback,
        .filter = filter,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ConsciousnessBus: basic pub/sub" {
    const allocator = std.testing.allocator;
    var bus = ConsciousnessBus.init(allocator);
    defer bus.deinit();

    var test_count: usize = 0;
    const count_ptr = &test_count;

    const sub = Subscription{
        .event_type = .consciousness_emergence,
        .subscriber = "test_module",
        .callback = struct {
            fn wrapper(event: Event, ctx: ?*anyopaque) anyerror!void {
                _ = event;
                const ptr = @as(*usize, @ptrCast(@alignCast(ctx)));
                _ = @atomicRmw(usize, ptr, .Add, 1, .seq_cst);
            }
        }.wrapper,
        .user_data = count_ptr,
    };

    try bus.subscribe(sub);

    const data = EventData{ .consciousness_emergence = .{
        .phi_value = 0.7,
        .gamma_synchrony = 0.8,
        .threshold = 0.618,
    } };

    const event = try createEvent(allocator, .consciousness_emergence, "test_source", data);
    defer allocator.free(event.source);

    try bus.publish(event);
    try bus.processNext();

    try std.testing.expectEqual(@as(usize, 1), test_count);
}

test "ConsciousnessBus: priority ordering" {
    const allocator = std.testing.allocator;
    var bus = ConsciousnessBus.init(allocator);
    defer bus.deinit();

    const ts = std.time.nanoTimestamp();
    const high_priority = Event{
        .type = .consciousness_emergence,
        .timestamp = @intCast(ts),
        .source = "test",
        .data = undefined,
    };

    const low_priority = Event{
        .type = .vsa_bind,
        .timestamp = @intCast(ts),
        .source = "test",
        .data = undefined,
    };

    try bus.event_queue.append(allocator, low_priority);
    try bus.event_queue.append(allocator, high_priority);

    bus.sortByPriority();

    // High priority should be first
    try std.testing.expectEqual(.consciousness_emergence, bus.event_queue.items[0].type);
}

test "ConsciousnessBus: phi-based priority" {
    const ts = std.time.nanoTimestamp();
    const event1 = Event{
        .type = .consciousness_emergence,
        .timestamp = @intCast(ts),
        .source = "test",
        .data = undefined,
    };

    const event2 = Event{
        .type = .vsa_bind,
        .timestamp = @intCast(ts),
        .source = "test",
        .data = undefined,
    };

    // Consciousness events should have higher priority
    try std.testing.expect(event1.priority() > event2.priority());
}

test "ConsciousnessBus: subscription filter" {
    const allocator = std.testing.allocator;
    var bus = ConsciousnessBus.init(allocator);
    defer bus.deinit();

    var call_count: usize = 0;
    const count_ptr = &call_count;

    const filter_fn = struct {
        fn shouldProcess(event: Event) bool {
            return event.data.consciousness_emergence.phi_value > 0.7;
        }
    }.shouldProcess;

    const callback_wrapper = struct {
        fn handler(event: Event, ctx: ?*anyopaque) anyerror!void {
            _ = event;
            const ptr = @as(*usize, @ptrCast(@alignCast(ctx)));
            _ = @atomicRmw(usize, ptr, .Add, 1, .seq_cst);
        }
    }.handler;

    const sub = Subscription{
        .event_type = .consciousness_emergence,
        .subscriber = "test",
        .callback = callback_wrapper,
        .user_data = count_ptr,
        .filter = filter_fn,
    };
    try bus.subscribe(sub);

    // Event below threshold - should not be called
    const data1 = EventData{ .consciousness_emergence = .{
        .phi_value = 0.6,
        .gamma_synchrony = 0.8,
        .threshold = 0.618,
    } };
    const event1 = try createEvent(allocator, .consciousness_emergence, "test", data1);
    defer allocator.free(event1.source);
    try bus.publish(event1);

    // Process queue
    try bus.processNext();

    try std.testing.expectEqual(@as(usize, 0), call_count);

    // Event above threshold - should be called
    const data2 = EventData{ .consciousness_emergence = .{
        .phi_value = 0.8,
        .gamma_synchrony = 0.9,
        .threshold = 0.618,
    } };
    const event2 = try createEvent(allocator, .consciousness_emergence, "test", data2);
    defer allocator.free(event2.source);
    try bus.publish(event2);

    try bus.processNext();

    try std.testing.expectEqual(@as(usize, 1), call_count);
}

test "ConsciousnessBus: multiple subscribers" {
    const allocator = std.testing.allocator;
    var bus = ConsciousnessBus.init(allocator);
    defer bus.deinit();

    var count1: usize = 0;
    var count2: usize = 0;
    const count1_ptr = &count1;
    const count2_ptr = &count2;

    const callback1_wrapper = struct {
        fn handler(event: Event, ctx: ?*anyopaque) anyerror!void {
            _ = event;
            const ptr = @as(*usize, @ptrCast(@alignCast(ctx)));
            _ = @atomicRmw(usize, ptr, .Add, 1, .seq_cst);
        }
    }.handler;

    const callback2_wrapper = struct {
        fn handler(event: Event, ctx: ?*anyopaque) anyerror!void {
            _ = event;
            const ptr = @as(*usize, @ptrCast(@alignCast(ctx)));
            _ = @atomicRmw(usize, ptr, .Add, 1, .seq_cst);
        }
    }.handler;

    const sub1 = Subscription{
        .event_type = .consciousness_emergence,
        .subscriber = "sub1",
        .callback = callback1_wrapper,
        .user_data = count1_ptr,
    };
    const sub2 = Subscription{
        .event_type = .consciousness_emergence,
        .subscriber = "sub2",
        .callback = callback2_wrapper,
        .user_data = count2_ptr,
    };

    try bus.subscribe(sub1);
    try bus.subscribe(sub2);

    try std.testing.expectEqual(@as(usize, 2), bus.subscriberCount(.consciousness_emergence));

    const data = EventData{ .consciousness_emergence = .{
        .phi_value = 0.7,
        .gamma_synchrony = 0.8,
        .threshold = 0.618,
    } };
    const event = try createEvent(allocator, .consciousness_emergence, "test", data);
    defer allocator.free(event.source);
    try bus.publish(event);

    try bus.processNext();

    try std.testing.expectEqual(@as(usize, 1), count1);
    try std.testing.expectEqual(@as(usize, 1), count2);
}

test "ConsciousnessBus: unsubscribe" {
    const allocator = std.testing.allocator;
    var bus = ConsciousnessBus.init(allocator);
    defer bus.deinit();

    const sub = Subscription{
        .event_type = .consciousness_emergence,
        .subscriber = "test",
        .callback = struct {
            fn handler(event: Event, ctx: ?*anyopaque) anyerror!void {
                _ = event;
                _ = ctx;
            }
        }.handler,
    };
    try bus.subscribe(sub);

    try std.testing.expectEqual(@as(usize, 1), bus.subscriberCount(.consciousness_emergence));

    bus.unsubscribe("test", .consciousness_emergence);

    try std.testing.expectEqual(@as(usize, 0), bus.subscriberCount(.consciousness_emergence));
}
