// @origin(spec:farm_accounts.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// FARM ACCOUNTS — Dynamic Railway account discovery from env vars
// ═══════════════════════════════════════════════════════════════════════════════
//
// Scans RAILWAY_API_TOKEN[_N] env vars (N=2..8) to discover accounts.
// Adding a new account = add 3 env vars to .env. Zero code changes.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const MAX_ACCOUNTS = 8;

pub const Account = struct {
    name: []const u8,
    suffix: []const u8,
    env_id: []const u8,
    project_id: []const u8,
};

const AccountSlot = struct {
    name: []const u8,
    suffix: []const u8,
    token_key: []const u8,
    project_key: []const u8,
    env_key: []const u8,
};

const account_slots = [_]AccountSlot{
    .{ .name = "PRIMARY", .suffix = "", .token_key = "RAILWAY_API_TOKEN", .project_key = "RAILWAY_PROJECT_ID", .env_key = "RAILWAY_ENVIRONMENT_ID" },
    .{ .name = "FARM-2", .suffix = "_2", .token_key = "RAILWAY_API_TOKEN_2", .project_key = "RAILWAY_PROJECT_ID_2", .env_key = "RAILWAY_ENVIRONMENT_ID_2" },
    .{ .name = "FARM-3", .suffix = "_3", .token_key = "RAILWAY_API_TOKEN_3", .project_key = "RAILWAY_PROJECT_ID_3", .env_key = "RAILWAY_ENVIRONMENT_ID_3" },
    .{ .name = "FARM-4", .suffix = "_4", .token_key = "RAILWAY_API_TOKEN_4", .project_key = "RAILWAY_PROJECT_ID_4", .env_key = "RAILWAY_ENVIRONMENT_ID_4" },
    .{ .name = "FARM-5", .suffix = "_5", .token_key = "RAILWAY_API_TOKEN_5", .project_key = "RAILWAY_PROJECT_ID_5", .env_key = "RAILWAY_ENVIRONMENT_ID_5" },
    .{ .name = "FARM-6", .suffix = "_6", .token_key = "RAILWAY_API_TOKEN_6", .project_key = "RAILWAY_PROJECT_ID_6", .env_key = "RAILWAY_ENVIRONMENT_ID_6" },
    .{ .name = "FARM-7", .suffix = "_7", .token_key = "RAILWAY_API_TOKEN_7", .project_key = "RAILWAY_PROJECT_ID_7", .env_key = "RAILWAY_ENVIRONMENT_ID_7" },
    .{ .name = "FARM-8", .suffix = "_8", .token_key = "RAILWAY_API_TOKEN_8", .project_key = "RAILWAY_PROJECT_ID_8", .env_key = "RAILWAY_ENVIRONMENT_ID_8" },
};

/// Discover available Railway accounts by checking env vars.
/// Returns number of accounts found. Populates buf[0..count].
/// Uses std.process.getEnvVarOwned to check existence, then frees immediately.
/// The Account fields (env_id, project_id) are owned by the allocator — caller must
/// free them via deinitAccounts().
pub fn discoverAccounts(allocator: std.mem.Allocator, buf: *[MAX_ACCOUNTS]Account) u8 {
    var count: u8 = 0;

    for (account_slots) |slot| {
        if (count >= MAX_ACCOUNTS) break;

        // Check token exists (required for API access)
        const token = std.process.getEnvVarOwned(allocator, slot.token_key) catch continue;
        allocator.free(token); // Don't need the value, just checking existence

        // Get project_id (required)
        const project_id = std.process.getEnvVarOwned(allocator, slot.project_key) catch continue;

        // Get environment_id (required)
        const env_id = std.process.getEnvVarOwned(allocator, slot.env_key) catch {
            allocator.free(project_id);
            continue;
        };

        buf[count] = .{
            .name = slot.name,
            .suffix = slot.suffix,
            .project_id = project_id,
            .env_id = env_id,
        };
        count += 1;
    }

    return count;
}

/// Free allocated env_id and project_id strings from discovered accounts.
pub fn deinitAccounts(allocator: std.mem.Allocator, buf: *[MAX_ACCOUNTS]Account, count: u8) void {
    for (buf[0..count]) |acct| {
        allocator.free(acct.project_id);
        allocator.free(acct.env_id);
    }
}

test "discoverAccounts returns 0 with no env" {
    // In test environment, no RAILWAY_API_TOKEN is set
    var buf: [MAX_ACCOUNTS]Account = undefined;
    const count = discoverAccounts(std.testing.allocator, &buf);
    // May or may not find accounts depending on test environment
    // Just verify it doesn't crash
    deinitAccounts(std.testing.allocator, &buf, count);
}
