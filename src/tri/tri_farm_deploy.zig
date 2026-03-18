// @origin(manual) @regen(pending)
// Trinity Farm Deploy — tri farm deploy
// Migrated from scripts/railway_deploy_experiment.sh
//
// Railway GraphQL deployment: experiment templates, env var upsert, redeploy

const std = @import("std");

// Experiment configurations (from R4-R7 templates)
pub const ExperimentConfig = struct {
    name: []const u8,
    optimizer: []const u8 = "LAMB",
    lr: f64 = 1e-3,
    lr_schedule: []const u8 = "cosine",
    batch_size: u32 = 66,
    context_length: u32 = 81,
    grad_clip: f32 = 1.0,
    label_smoothing: f32 = 0.0,
    batch_accum: u32 = 1,
    service_id: []const u8,
};

// Predefined experiment templates
pub const EXPERIMENTS = [_]ExperimentConfig{
    .{
        .name = "r4",
        .optimizer = "AdamW",
        .lr = 3e-4,
        .context_length = 81,
        .label_smoothing = 0.1,
        .service_id = "hslm-train",
    },
    .{
        .name = "r5",
        .optimizer = "LAMB",
        .lr = 1e-3,
        .context_length = 27,
        .service_id = "hslm-train",
    },
    .{
        .name = "r6",
        .optimizer = "AdamW",
        .lr = 3e-4,
        .lr_schedule = "cosine-restarts",
        .service_id = "hslm-v11",
    },
    .{
        .name = "r7",
        .optimizer = "LAMB",
        .lr = 1e-3,
        .batch_accum = 8,
        .service_id = "hslm-v11",
    },
};

/// Find experiment config by name
pub fn findExperiment(name: []const u8) ?ExperimentConfig {
    for (&EXPERIMENTS) |exp| {
        if (std.mem.eql(u8, exp.name, name)) return exp;
    }
    return null;
}

/// Format env var upsert mutation for Railway GraphQL
pub fn formatEnvVarMutation(
    buf: []u8,
    service_id: []const u8,
    env_id: []const u8,
    key: []const u8,
    value: []const u8,
) ![]const u8 {
    return std.fmt.bufPrint(buf,
        \\mutation {{ variableUpsert(input: {{
        \\  serviceId: "{s}", environmentId: "{s}",
        \\  name: "{s}", value: "{s}"
        \\}}) }}
    , .{ service_id, env_id, key, value });
}

/// Format redeploy mutation for Railway GraphQL
pub fn formatRedeployMutation(
    buf: []u8,
    deployment_id: []const u8,
) ![]const u8 {
    return std.fmt.bufPrint(buf,
        \\mutation {{ deploymentRedeploy(id: "{s}", usePreviousImageTag: true) {{ id status }} }}
    , .{deployment_id});
}

/// Validate experiment config against safeguards
pub fn validateConfig(config: ExperimentConfig) !void {
    // SAFEGUARD: Never use flat LR schedule
    if (std.mem.eql(u8, config.lr_schedule, "flat")) {
        return error.FlatScheduleForbidden;
    }

    // SAFEGUARD: Context must be >= 27
    if (config.context_length < 27) {
        return error.ContextTooSmall;
    }

    // SAFEGUARD: LR must be positive
    if (config.lr <= 0) {
        return error.InvalidLearningRate;
    }
}

// Tests
test "find experiment" {
    const r4 = findExperiment("r4");
    try std.testing.expect(r4 != null);
    try std.testing.expectEqualStrings("AdamW", r4.?.optimizer);

    const r5 = findExperiment("r5");
    try std.testing.expect(r5 != null);
    try std.testing.expectEqualStrings("LAMB", r5.?.optimizer);

    try std.testing.expect(findExperiment("r99") == null);
}

test "validate config - safe" {
    const config = ExperimentConfig{
        .name = "test",
        .optimizer = "LAMB",
        .lr = 1e-3,
        .lr_schedule = "cosine",
        .service_id = "test",
    };
    try validateConfig(config);
}

test "validate config - flat forbidden" {
    const config = ExperimentConfig{
        .name = "test",
        .lr_schedule = "flat",
        .service_id = "test",
    };
    try std.testing.expectError(error.FlatScheduleForbidden, validateConfig(config));
}

test "format env var mutation" {
    var buf: [1024]u8 = undefined;
    const result = try formatEnvVarMutation(&buf, "svc-1", "env-1", "HSLM_LR", "0.001");
    try std.testing.expect(result.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, result, "variableUpsert") != null);
}
