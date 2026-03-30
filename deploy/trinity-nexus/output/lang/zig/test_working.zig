// @origin(generated) @regen(done)
const std = @import("std");
const contract = @import("contract_test.zig");

// Test what actually WORKS in the generated code

test "1. Config type instantiation" {
    const config = contract.Config{
        .enabled = true,
        .max_workers = 4,
        .timeout_seconds = 30,
    };
    
    try std.testing.expectEqual(true, config.enabled);
    try std.testing.expectEqual(@as(u32, 4), config.max_workers);
    try std.testing.expectEqual(@as(u32, 30), config.timeout_seconds);
}

test "2. StateSnapshot type instantiation" {
    const data = "test data";
    const state = contract.StateSnapshot{
        .version = 1,
        .timestamp = 1234567890,
        .data = data,
    };
    
    try std.testing.expectEqual(@as(u32, 1), state.version);
    try std.testing.expectEqual(@as(i64, 1234567890), state.timestamp);
    try std.testing.expectEqual(data, state.data);
}

test "3. StateSnapshot serialize works" {
    const allocator = std.testing.allocator;
    const data = "test data";
    const state = contract.StateSnapshot{
        .version = 1,
        .timestamp = 1234567890,
        .data = data,
    };
    
    const serialized = try state.serialize(allocator);
    defer allocator.free(serialized);
    
    // Should produce JSON output
    try std.testing.expect(serialized.len > 0);
}

test "4. StateSnapshot deserialize works" {
    const allocator = std.testing.allocator;
    const json = "{\"version\":1,\"timestamp\":1234567890,\"data\":\"test\"}";
    
    const state = try contract.StateSnapshot.deserialize(json, allocator);
    
    try std.testing.expectEqual(@as(u32, 1), state.version);
    try std.testing.expectEqual(@as(i64, 1234567890), state.timestamp);
}

test "5. BatchProcessor JobStatus enum exists" {
    const Status = contract.BatchProcessor.JobStatus;
    _ = Status.pending;
    _ = Status.running;
    _ = Status.completed;
    _ = Status.failed;
}

test "6. BatchProcessor Job type exists" {
    const Job = contract.BatchProcessor.Job;
    var job = Job{
        .id = 1,
        .status = .pending,
        .data = null,
    };
    
    try std.testing.expectEqual(@as(u32, 1), job.id);
    try std.testing.expectEqual(contract.BatchProcessor.JobStatus.pending, job.status);
}

test "7. Sacred constants exist" {
    try std.testing.expectApproxEqAbs(1.618033988749895, contract.PHI, 0.001);
    try std.testing.expectApproxEqAbs(0.6180339887498949, contract.PHI_INV, 0.001);
    try std.testing.expectApproxEqAbs(3.0, contract.TRINITY, 0.001);
}
