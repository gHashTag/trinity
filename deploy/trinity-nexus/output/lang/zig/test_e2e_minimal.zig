// @origin(generated) @regen(done)
const std = @import("std");
const contract = @import("contract_test.zig");

test "config exists and has correct fields" {
    var config = contract.Config{
        .enabled = true,
        .max_workers = 4,
        .timeout_seconds = 30,
    };
    
    try std.testing.expectEqual(true, config.enabled);
    try std.testing.expectEqual(@as(u32, 4), config.max_workers);
    try std.testing.expectEqual(@as(u32, 30), config.timeout_seconds);
}

test "state exists and has correct fields" {
    const data = "test data";
    var state = contract.StateSnapshot{
        .version = 1,
        .timestamp = 1234567890,
        .data = data,
    };
    
    try std.testing.expectEqual(@as(u32, 1), state.version);
    try std.testing.expectEqual(@as(i64, 1234567890), state.timestamp);
}

test "batch processor types exist" {
    _ = contract.BatchProcessor;
    _ = contract.BatchProcessor.JobStatus;
    _ = contract.BatchProcessor.Job;
    _ = contract.BatchProcessor.BatchStatus;
}

test "batch processor job status enum" {
    const JobStatus = contract.BatchProcessor.JobStatus;
    _ = JobStatus.pending;
    _ = JobStatus.running;
    _ = JobStatus.completed;
    _ = JobStatus.failed;
}
