const std = @import("std");

/// Check if a behavior name matches an RL (Reinforcement Learning) pattern.
/// RL behaviors are self-contained and only reference rl.* types and primitives.
pub fn isRlBehavior(name: []const u8) bool {
    const rl_prefixes = [_][]const u8{
        "rl_",
        "train_agent",
        "compute_reward",
        "update_policy",
        "select_action",
        "replay_buffer",
        "epsilon_greedy",
        "q_learning",
        "policy_gradient",
        "advantage_",
        "bellman_",
        "discount_",
    };

    for (rl_prefixes) |prefix| {
        if (name.len >= prefix.len and std.mem.eql(u8, name[0..prefix.len], prefix)) {
            return true;
        }
    }
    return false;
}

test "isRlBehavior identifies RL patterns" {
    try std.testing.expect(isRlBehavior("rl_train"));
    try std.testing.expect(isRlBehavior("train_agent_v2"));
    try std.testing.expect(isRlBehavior("compute_reward_signal"));
    try std.testing.expect(!isRlBehavior("detectLanguage"));
    try std.testing.expect(!isRlBehavior("fibonacci"));
}
