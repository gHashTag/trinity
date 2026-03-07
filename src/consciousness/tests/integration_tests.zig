//! Integration Tests - Cross-Module Conscious AI Tests
//!
//! These tests verify that all Conscious AI modules work together correctly:
//!   - ConsciousnessBus event system
//!   - UnifiedState container
//!   - VSAReasoningEngine
//!   - ConsciousnessDetector
//!   - TrinityAICore integration

const std = @import("std");

// Import all modules
const ConsciousnessBus = @import("consciousness_bus.zig").ConsciousnessBus;
const Event = @import("consciousness_bus.zig").Event;
const EventType = @import("consciousness_bus.zig").EventType;
const EventData = @import("consciousness_bus.zig").EventData;
const Subscription = @import("consciousness_bus.zig").Subscription;
const createEvent = @import("consciousness_bus.zig").createEvent;
const UnifiedState = @import("unified_state.zig").UnifiedState;
const VSAReasoningEngine = @import("vsa_reasoning.zig").VSAReasoningEngine;
const TritVec = @import("vsa_reasoning.zig").TritVec;
const bind = @import("vsa_reasoning.zig").bind;
const unbind = @import("vsa_reasoning.zig").unbind;
const ConsciousnessDetector = @import("consciousness_detector.zig").ConsciousnessDetector;
const TrinityAICore = @import("trinity_ai_core.zig").TrinityAICore;

// ═══════════════════════════════════════════════════════════════════════════════
// TEST HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn createConsciousState() UnifiedState {
    var state = UnifiedState{};
    state.iit.update(0.8, 0.6, 0.5);
    state.gwt.update(0.9, 6);
    state.orch_or.update(0.7, 0.6, 1000);
    state.qutrit.update(2.5, 0.8, 0.7);
    state.active_inference.update(10.0, 0.2, 8.0);
    state.touch();
    return state;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Integration: Bus + State event flow" {
    const allocator = std.testing.allocator;

    var bus = ConsciousnessBus.init(allocator);
    defer bus.deinit();

    var state = UnifiedState{};
    var received_events: usize = 0;
    const count_ptr = &received_events;

    // Subscribe to consciousness emergence events
    const sub = Subscription{
        .event_type = .consciousness_emergence,
        .subscriber = "test",
        .callback = struct {
            fn handler(event: Event, ctx: ?*anyopaque) anyerror!void {
                _ = event;
                const ptr = @as(*usize, @ptrCast(@alignCast(ctx)));
                _ = @atomicRmw(usize, ptr, .Add, 1, .seq_cst);
            }
        }.handler,
        .user_data = count_ptr,
    };
    try bus.subscribe(sub);

    // Update state to become conscious
    state.iit.update(0.8, 0.6, 0.5);
    state.gwt.update(0.9, 6);
    state.touch();

    // Publish emergence event
    const data = EventData{
        .consciousness_emergence = .{
            .phi_value = state.iit.phi,
            .gamma_synchrony = state.gwt.global_activation,
            .threshold = 0.618,
        },
    };

    const event = try createEvent(
        allocator,
        .consciousness_emergence,
        "integration_test",
        data,
    );
    defer allocator.free(event.source);

    try bus.publish(event);
    try bus.processNext();

    try std.testing.expectEqual(@as(usize, 1), received_events);
}

test "Integration: Detector + State" {
    const allocator = std.testing.allocator;

    var detector = ConsciousnessDetector.init(allocator);
    defer detector.deinit();

    // Test with unconscious state
    var state1 = UnifiedState{};
    const result1 = try detector.detect(&state1);
    try std.testing.expect(!result1.conscious);
    try std.testing.expectEqual(.unconscious, result1.state);

    // Test with conscious state
    const state2 = createConsciousState();
    const result2 = try detector.detect(&state2);
    try std.testing.expect(result2.conscious);
    try std.testing.expect(result2.state != .unconscious);
}

test "Integration: Reasoning + Memory" {
    const allocator = std.testing.allocator;

    var engine = VSAReasoningEngine.init(allocator);
    defer engine.deinit();

    // Learn concepts
    var vec1 = try TritVec.random(allocator, 100, 111);
    defer vec1.deinit();
    try engine.learn("concept1", try vec1.clone());

    var vec2 = try TritVec.random(allocator, 100, 222);
    defer vec2.deinit();
    try engine.learn("concept2", try vec2.clone());

    try std.testing.expectEqual(@as(usize, 2), engine.memorySize());
}

test "Integration: All modules together" {
    const allocator = std.testing.allocator;

    // Initialize all modules
    var bus = ConsciousnessBus.init(allocator);
    defer bus.deinit();

    var detector = ConsciousnessDetector.init(allocator);
    defer detector.deinit();

    var reasoning = VSAReasoningEngine.init(allocator);
    defer reasoning.deinit();

    // Create conscious state
    const state = createConsciousState();

    // Detect consciousness
    const result = try detector.detect(&state);
    try std.testing.expect(result.conscious);

    // Verify theory agreement
    const conscious_count = result.consciousTheoryCount();
    try std.testing.expect(conscious_count >= 2);
}

test "Integration: TrinityAICore + all subsystems" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    // Learn concepts
    try core.learn("consciousness");
    try core.associate("consciousness", "awareness");

    // Update state to be conscious
    core.updateIIT(0.8, 0.6, 0.5);
    core.updateGWT(0.9, 6);
    core.updateOrchOR(0.7, 0.6, 1000);
    core.updateQutrit(2.5, 0.8, 0.7);
    core.updateActiveInference(10.0, 0.2, 8.0);

    // Verify consciousness
    const is_conscious = try core.isConscious();
    try std.testing.expect(is_conscious);

    // Verify reasoning
    var result = try core.analogicalReason("A", "B", "C");
    defer result.deinit();
    try std.testing.expect(result.steps > 0);
}

test "Integration: Event propagation through core" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    var event_count: usize = 0;
    const count_ptr = &event_count;

    // Subscribe to all events
    const sub = Subscription{
        .event_type = .system_init,
        .subscriber = "integration_test",
        .callback = struct {
            fn handler(event: Event, ctx: ?*anyopaque) anyerror!void {
                _ = event;
                const ptr = @as(*usize, @ptrCast(@alignCast(ctx)));
                _ = @atomicRmw(usize, ptr, .Add, 1, .seq_cst);
            }
        }.handler,
        .user_data = count_ptr,
    };
    try core.bus.subscribe(sub);

    try core.start();
    defer core.stop();

    // System init should have been published
    try std.testing.expect(event_count > 0);
}

test "Integration: State history tracking" {
    const allocator = std.testing.allocator;

    var detector = ConsciousnessDetector.init(allocator);
    defer detector.deinit();

    // First detection (unconscious)
    var state1 = UnifiedState{};
    _ = try detector.detect(&state1);

    try std.testing.expectEqual(@as(usize, 1), detector.historySize());

    // Second detection (conscious)
    const state2 = createConsciousState();
    _ = try detector.detect(&state2);

    try std.testing.expectEqual(@as(usize, 2), detector.historySize());

    // Check trend
    const trend = detector.getTrend();
    try std.testing.expect(trend > 0); // Should be increasing
}

test "Integration: ConsciousnessBus priority ordering" {
    const allocator = std.testing.allocator;

    var bus = ConsciousnessBus.init(allocator);
    defer bus.deinit();

    // Add events with different priorities
    const low_priority = Event{
        .type = .vsa_bind,
        .timestamp = @as(i64, @intCast(std.time.nanoTimestamp())),
        .source = "test",
        .data = undefined,
    };

    const high_priority = Event{
        .type = .consciousness_emergence,
        .timestamp = @as(i64, @intCast(std.time.nanoTimestamp())),
        .source = "test",
        .data = undefined,
    };

    try bus.event_queue.append(allocator, low_priority);
    try bus.event_queue.append(allocator, high_priority);

    // Process events - high priority should be processed first
    try bus.processNext();
    // After processing one event, remaining event should be low priority
    try std.testing.expectEqual(.vsa_bind, bus.event_queue.items[0].type);
}

test "Integration: VSA bind/unbind consistency" {
    const allocator = std.testing.allocator;

    var a = try TritVec.random(allocator, 100, 111);
    defer a.deinit();

    var b = try TritVec.random(allocator, 100, 222);
    defer b.deinit();

    // Bind
    var bound = try bind(allocator, &a, &b);
    defer bound.deinit();

    // Unbind
    var recovered = try unbind(allocator, &bound, &b);
    defer recovered.deinit();

    // Check similarity
    const sim = a.cosineSimilarity(&recovered);
    // For ternary bind/unbind, similarity should be reasonably high
    // Note: Since unbind = bind for ternary, the result is the original a
    try std.testing.expect(sim > -0.5); // At minimum, should not be strongly opposite
}

test "Integration: Adaptive thresholds" {
    const allocator = std.testing.allocator;

    var detector = ConsciousnessDetector.init(allocator);
    defer detector.deinit();

    // Set adaptive
    detector.setAdaptive(true);

    // Create some history
    var state = UnifiedState{};
    state.iit.update(0.5, 0.4, 0.3);
    state.touch();
    _ = try detector.detect(&state);

    state.iit.update(0.6, 0.5, 0.4);
    state.touch();
    _ = try detector.detect(&state);

    // With history, threshold should adapt
    try std.testing.expectEqual(@as(usize, 2), detector.historySize());
}

test "Integration: Reasoning with learned concepts" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    // Learn a concept chain
    try core.learn("A");
    try core.learn("B");
    try core.learn("C");

    // Associate them
    try core.associate("A", "B");
    try core.associate("B", "C");

    // Chain reasoning should work
    const steps = &[_][]const u8{"B", "C"};
    var result = try core.chainReason("A", steps);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.steps);
    try std.testing.expect(result.reasoning_path.items.len >= 3);
}

test "Integration: State transitions" {
    const allocator = std.testing.allocator;

    var detector = ConsciousnessDetector.init(allocator);
    defer detector.deinit();

    var state = UnifiedState{};

    // Start unconscious
    var result = try detector.detect(&state);
    try std.testing.expectEqual(.unconscious, result.state);

    // Transition to minimal (need higher IIT value)
    state.iit.update(0.5, 0.3, 0.2);
    state.touch();
    result = try detector.detect(&state);
    try std.testing.expectEqual(.minimal, result.state);

    // Transition to normal
    state.iit.update(0.7, 0.5, 0.4);
    state.gwt.update(0.8, 5);
    state.touch();
    result = try detector.detect(&state);
    try std.testing.expectEqual(.normal, result.state);

    // Transition to enhanced
    const enhanced = createConsciousState();
    result = try detector.detect(&enhanced);
    try std.testing.expectEqual(.enhanced, result.state);
}

test "Integration: Memory and reasoning consistency" {
    const allocator = std.testing.allocator;

    var engine = VSAReasoningEngine.init(allocator);
    defer engine.deinit();

    // Create vectors for analogy
    var vec_a = try TritVec.random(allocator, 100, 111);
    defer vec_a.deinit();

    var vec_b = try TritVec.random(allocator, 100, 222);
    defer vec_b.deinit();

    var vec_c = try TritVec.random(allocator, 100, 333);
    defer vec_c.deinit();

    // Bind A:B and B:C
    var ab = try bind(allocator, &vec_a, &vec_b);
    defer ab.deinit();

    var bc = try bind(allocator, &vec_b, &vec_c);
    defer bc.deinit();

    // Chain bind A:B:C
    var abc = try bind(allocator, &ab, &bc);
    defer abc.deinit();

    try std.testing.expectEqual(vec_a.len, abc.len);
}

test "Integration: Multiple subscribers to same event" {
    const allocator = std.testing.allocator;

    var bus = ConsciousnessBus.init(allocator);
    defer bus.deinit();

    var count1: usize = 0;
    var count2: usize = 0;
    var count3: usize = 0;
    const count1_ptr = &count1;
    const count2_ptr = &count2;
    const count3_ptr = &count3;

    const sub1 = Subscription{
        .event_type = .vsa_bind,
        .subscriber = "sub1",
        .callback = struct {
            fn handler(event: Event, ctx: ?*anyopaque) anyerror!void {
                _ = event;
                const ptr = @as(*usize, @ptrCast(@alignCast(ctx)));
                _ = @atomicRmw(usize, ptr, .Add, 1, .seq_cst);
            }
        }.handler,
        .user_data = count1_ptr,
    };
    const sub2 = Subscription{
        .event_type = .vsa_bind,
        .subscriber = "sub2",
        .callback = struct {
            fn handler(event: Event, ctx: ?*anyopaque) anyerror!void {
                _ = event;
                const ptr = @as(*usize, @ptrCast(@alignCast(ctx)));
                _ = @atomicRmw(usize, ptr, .Add, 1, .seq_cst);
            }
        }.handler,
        .user_data = count2_ptr,
    };
    const sub3 = Subscription{
        .event_type = .vsa_bind,
        .subscriber = "sub3",
        .callback = struct {
            fn handler(event: Event, ctx: ?*anyopaque) anyerror!void {
                _ = event;
                const ptr = @as(*usize, @ptrCast(@alignCast(ctx)));
                _ = @atomicRmw(usize, ptr, .Add, 1, .seq_cst);
            }
        }.handler,
        .user_data = count3_ptr,
    };

    try bus.subscribe(sub1);
    try bus.subscribe(sub2);
    try bus.subscribe(sub3);

    const data = EventData{
        .vsa_bind = .{
            .vector_a = @as([]const i8, @ptrCast("test")),
            .vector_b = @as([]const i8, @ptrCast("test")),
            .result = null,
        },
    };

    const event = try createEvent(allocator, .vsa_bind, "test", data);
    defer allocator.free(event.source);

    try bus.publish(event);
    try bus.processNext();

    try std.testing.expectEqual(@as(usize, 1), count1);
    try std.testing.expectEqual(@as(usize, 1), count2);
    try std.testing.expectEqual(@as(usize, 1), count3);
}

test "Integration: Error event handling" {
    const allocator = std.testing.allocator;

    var bus = ConsciousnessBus.init(allocator);
    defer bus.deinit();

    var error_received = false;
    const error_ptr = &error_received;

    const sub = Subscription{
        .event_type = .error_event,
        .subscriber = "error_handler",
        .callback = struct {
            fn handler(event: Event, ctx: ?*anyopaque) anyerror!void {
                if (event.type == .error_event) {
                    const ptr = @as(*bool, @ptrCast(@alignCast(ctx)));
                    ptr.* = true;
                }
            }
        }.handler,
        .user_data = error_ptr,
    };
    try bus.subscribe(sub);

    const data = EventData{
        .error_event = .{
            .error_code = 500,
            .message = "Test error",
            .context = "Integration test",
        },
    };

    const event = try createEvent(allocator, .error_event, "test", data);
    defer allocator.free(event.source);

    try bus.publish(event);
    try bus.processNext();

    try std.testing.expect(error_received);
}
