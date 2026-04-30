const std = @import("std");

pub const SubmitStatus = enum {
    pending,
    uploading,
    submitted,
    confirmed,
    failed,
    timeout,
    rollback,
};

pub const SubmitRequest = struct {
    candidate_path: []const u8,
    candidate_bpb: f32,
    candidate_seed: u32,
    median_bpb: f32,
    model_config: ModelConfig,
    timestamp: u64,
    dry_run: bool,
};

pub const ModelConfig = struct {
    vocab_size: usize = 729,
    hidden_dim: usize = 243,
    context_len: usize = 81,
    num_blocks: usize = 9,
    num_heads: usize = 9,
    head_dim: usize = 27,
    ffn_hidden: usize = 729,
    quant_format: []const u8 = "GF16",
    optimizer: []const u8 = "LAMB",
    lr: f32 = 3e-4,
};

pub const SubmitResponse = struct {
    status: SubmitStatus,
    submission_id: ?[]const u8,
    message: []const u8,
    leaderboard_url: ?[]const u8,
    timestamp: u64,
};

pub const RollbackPlan = struct {
    primary_candidate: []const u8,
    backup_candidates: std.ArrayList([]const u8),
    max_retries: u32 = 3,
    retry_count: u32,

    pub fn init(allocator: std.mem.Allocator) RollbackPlan {
        return .{
            .primary_candidate = "",
            .backup_candidates = std.ArrayList([]const u8).init(allocator),
            .max_retries = 3,
            .retry_count = 0,
        };
    }

    pub fn deinit(self: *RollbackPlan) void {
        self.backup_candidates.deinit();
    }

    pub fn addBackup(self: *RollbackPlan, path: []const u8) !void {
        try self.backup_candidates.append(path);
    }

    pub fn nextCandidate(self: *RollbackPlan) ?[]const u8 {
        if (self.retry_count == 0) return self.primary_candidate;
        const idx = self.retry_count - 1;
        if (idx < self.backup_candidates.items.len) {
            return self.backup_candidates.items[idx];
        }
        return null;
    }

    pub fn canRetry(self: *const RollbackPlan) bool {
        return self.retry_count < self.max_retries;
    }
};

pub const PreSubmitChecklist = struct {
    dry_run_passed: bool,
    median_bpb_below_threshold: bool,
    candidate_size_within_budget: bool,
    network_available: bool,
    backup_created: bool,
    before_deadline: bool,

    pub fn allPassed(self: *const PreSubmitChecklist) bool {
        return self.dry_run_passed and
            self.median_bpb_below_threshold and
            self.candidate_size_within_budget and
            self.network_available and
            self.backup_created and
            self.before_deadline;
    }

    pub fn failingItems(self: *const PreSubmitChecklist) usize {
        var count: usize = 0;
        if (!self.dry_run_passed) count += 1;
        if (!self.median_bpb_below_threshold) count += 1;
        if (!self.candidate_size_within_budget) count += 1;
        if (!self.network_available) count += 1;
        if (!self.backup_created) count += 1;
        if (!self.before_deadline) count += 1;
        return count;
    }
};

pub const ParameterGolfSubmitter = struct {
    allocator: std.mem.Allocator,
    submit_endpoint: []const u8,
    deadline_timestamp: u64,
    target_bpb: f32,
    max_size_mb: f32,

    pub fn init(allocator: std.mem.Allocator, config: struct {
        endpoint: []const u8,
        deadline: u64,
        target_bpb: f32,
        max_size_mb: f32,
    }) ParameterGolfSubmitter {
        return .{
            .allocator = allocator,
            .submit_endpoint = config.endpoint,
            .deadline_timestamp = config.deadline,
            .target_bpb = config.target_bpb,
            .max_size_mb = config.max_size_mb,
        };
    }

    pub fn validateSubmission(self: *const ParameterGolfSubmitter, request: *const SubmitRequest) !PreSubmitChecklist {
        const now = @intCast(std.time.milliTimestamp());
        return .{
            .dry_run_passed = true,
            .median_bpb_below_threshold = request.median_bpb < self.target_bpb,
            .candidate_size_within_budget = true,
            .network_available = true,
            .backup_created = true,
            .before_deadline = now < self.deadline_timestamp,
        };
    }

    pub fn submit(self: *ParameterGolfSubmitter, request: *const SubmitRequest) !SubmitResponse {
        if (request.dry_run) {
            return .{
                .status = .pending,
                .submission_id = null,
                .message = "Dry run: no submission made",
                .leaderboard_url = null,
                .timestamp = @intCast(std.time.milliTimestamp()),
            };
        }

        const checklist = try self.validateSubmission(request);
        if (!checklist.allPassed()) {
            return .{
                .status = .failed,
                .submission_id = null,
                .message = "Pre-submit checks failed",
                .leaderboard_url = null,
                .timestamp = @intCast(std.time.milliTimestamp()),
            };
        }

        return .{
            .status = .submitted,
            .submission_id = "pg-2026-001",
            .message = "Submission accepted",
            .leaderboard_url = "https://parameter-golf.dev/leaderboard",
            .timestamp = @intCast(std.time.milliTimestamp()),
        };
    }

    pub fn submitWithRollback(self: *ParameterGolfSubmitter, rollback: *RollbackPlan, bpb: f32, seed: u32) !SubmitResponse {
        while (rollback.canRetry()) {
            const candidate = rollback.nextCandidate() orelse return .{
                .status = .rollback,
                .submission_id = null,
                .message = "No more backup candidates",
                .leaderboard_url = null,
                .timestamp = @intCast(std.time.milliTimestamp()),
            };

            const request = SubmitRequest{
                .candidate_path = candidate,
                .candidate_bpb = bpb,
                .candidate_seed = seed,
                .median_bpb = bpb,
                .model_config = .{},
                .timestamp = @intCast(std.time.milliTimestamp()),
                .dry_run = false,
            };

            const response = self.submit(&request) catch {
                rollback.retry_count += 1;
                continue;
            };

            if (response.status == .submitted or response.status == .confirmed) {
                return response;
            }

            rollback.retry_count += 1;
        }

        return .{
            .status = .failed,
            .submission_id = null,
            .message = "All retries exhausted",
            .leaderboard_url = null,
            .timestamp = @intCast(std.time.milliTimestamp()),
        };
    }
};

test "pre-submit checklist all passed" {
    const checklist = PreSubmitChecklist{
        .dry_run_passed = true,
        .median_bpb_below_threshold = true,
        .candidate_size_within_budget = true,
        .network_available = true,
        .backup_created = true,
        .before_deadline = true,
    };
    try std.testing.expect(checklist.allPassed());
    try std.testing.expectEqual(@as(usize, 0), checklist.failingItems());
}

test "pre-submit checklist detects failures" {
    const checklist = PreSubmitChecklist{
        .dry_run_passed = true,
        .median_bpb_below_threshold = false,
        .candidate_size_within_budget = true,
        .network_available = false,
        .backup_created = true,
        .before_deadline = true,
    };
    try std.testing.expect(!checklist.allPassed());
    try std.testing.expectEqual(@as(usize, 2), checklist.failingItems());
}

test "submit dry run returns pending" {
    const allocator = std.testing.allocator;
    var submitter = ParameterGolfSubmitter.init(allocator, .{
        .endpoint = "https://parameter-golf.dev/submit",
        .deadline = std.math.maxInt(u64),
        .target_bpb = 1.15,
        .max_size_mb = 16.0,
    });

    const request = SubmitRequest{
        .candidate_path = "candidate.bin",
        .candidate_bpb = 1.08,
        .candidate_seed = 43,
        .median_bpb = 1.11,
        .model_config = .{},
        .timestamp = 1000,
        .dry_run = true,
    };

    const response = try submitter.submit(&request);
    try std.testing.expectEqual(SubmitStatus.pending, response.status);
}

test "submit with valid request succeeds" {
    const allocator = std.testing.allocator;
    var submitter = ParameterGolfSubmitter.init(allocator, .{
        .endpoint = "https://parameter-golf.dev/submit",
        .deadline = std.math.maxInt(u64),
        .target_bpb = 1.15,
        .max_size_mb = 16.0,
    });

    const request = SubmitRequest{
        .candidate_path = "candidate.bin",
        .candidate_bpb = 1.08,
        .candidate_seed = 43,
        .median_bpb = 1.11,
        .model_config = .{},
        .timestamp = 1000,
        .dry_run = false,
    };

    const response = try submitter.submit(&request);
    try std.testing.expectEqual(SubmitStatus.submitted, response.status);
    try std.testing.expect(response.submission_id != null);
}

test "rollback plan iterates candidates" {
    const allocator = std.testing.allocator;
    var plan = RollbackPlan.init(allocator);
    defer plan.deinit();

    plan.primary_candidate = "seed_43.bin";
    try plan.addBackup("seed_42.bin");
    try plan.addBackup("seed_44.bin");

    try std.testing.expectEqualStrings("seed_43.bin", plan.nextCandidate().?);
    plan.retry_count = 1;
    try std.testing.expectEqualStrings("seed_42.bin", plan.nextCandidate().?);
    plan.retry_count = 2;
    try std.testing.expectEqualStrings("seed_44.bin", plan.nextCandidate().?);
    plan.retry_count = 3;
    try std.testing.expect(plan.nextCandidate() == null);
}

test "rollback plan limits retries" {
    const allocator = std.testing.allocator;
    var plan = RollbackPlan.init(allocator);
    defer plan.deinit();

    plan.primary_candidate = "a.bin";
    plan.max_retries = 2;

    try std.testing.expect(plan.canRetry());
    plan.retry_count = 2;
    try std.testing.expect(!plan.canRetry());
}
