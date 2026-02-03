// ═══════════════════════════════════════════════════════════════════════════════
// FIREBIRD EXTENSION WASM - WebAssembly module for browser extension
// Ternary VSA operations compiled to WASM for browser integration
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa = @import("vsa.zig");
const vsa_simd = @import("vsa_simd.zig");
const b2t = @import("b2t_integration.zig");
const depin = @import("depin.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - Functions callable from JavaScript
// ═══════════════════════════════════════════════════════════════════════════════

// Global allocator for WASM
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Global state
var current_profile: ?FingerprintProfile = null;
var navigation_state: ?b2t.NavigationState = null;
var depin_node: ?depin.DePINNode = null;

// ═══════════════════════════════════════════════════════════════════════════════
// FINGERPRINT PROFILE
// ═══════════════════════════════════════════════════════════════════════════════

pub const FingerprintProfile = struct {
    id: u64,
    trit_vec: vsa.TritVec,
    similarity: f64,
    canvas_seed: u64,
    webgl_seed: u64,
    audio_seed: u64,

    pub fn init(seed: u64, dim: usize) !FingerprintProfile {
        return FingerprintProfile{
            .id = seed,
            .trit_vec = try vsa.TritVec.random(allocator, dim, seed),
            .similarity = 0.0,
            .canvas_seed = seed *% 31337,
            .webgl_seed = seed *% 65537,
            .audio_seed = seed *% 131071,
        };
    }

    pub fn deinit(self: *FingerprintProfile) void {
        self.trit_vec.deinit();
    }

    pub fn getCanvasHash(self: *const FingerprintProfile) u64 {
        // Generate deterministic canvas hash from seed
        var hash: u64 = self.canvas_seed;
        for (0..100) |i| {
            hash = hash *% 6364136223846793005 +% 1442695040888963407;
            hash ^= @as(u64, @intCast(@as(i8, self.trit_vec.data[i % self.trit_vec.len]) + 1));
        }
        return hash;
    }

    pub fn getWebGLHash(self: *const FingerprintProfile) u64 {
        var hash: u64 = self.webgl_seed;
        for (0..100) |i| {
            hash = hash *% 6364136223846793005 +% 1442695040888963407;
            hash ^= @as(u64, @intCast(@as(i8, self.trit_vec.data[(i + 100) % self.trit_vec.len]) + 1));
        }
        return hash;
    }

    pub fn getAudioHash(self: *const FingerprintProfile) u64 {
        var hash: u64 = self.audio_seed;
        for (0..100) |i| {
            hash = hash *% 6364136223846793005 +% 1442695040888963407;
            hash ^= @as(u64, @intCast(@as(i8, self.trit_vec.data[(i + 200) % self.trit_vec.len]) + 1));
        }
        return hash;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTED FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Initialize the extension WASM module
export fn wasm_init(seed: u64) i32 {
    // Initialize DePIN node
    depin_node = depin.DePINNode.init(seed);
    if (depin_node) |*node| {
        node.start();
    }
    return 0; // Success
}

/// Create a new fingerprint profile
export fn wasm_create_profile(seed: u64, dim: u32) i32 {
    if (current_profile) |*profile| {
        profile.deinit();
    }

    current_profile = FingerprintProfile.init(seed, dim) catch return -1;
    return 0;
}

/// Get current profile similarity
export fn wasm_get_similarity() f64 {
    if (current_profile) |profile| {
        return profile.similarity;
    }
    return 0.0;
}

/// Get canvas hash for current profile
export fn wasm_get_canvas_hash() u64 {
    if (current_profile) |profile| {
        return profile.getCanvasHash();
    }
    return 0;
}

/// Get WebGL hash for current profile
export fn wasm_get_webgl_hash() u64 {
    if (current_profile) |profile| {
        return profile.getWebGLHash();
    }
    return 0;
}

/// Get audio hash for current profile
export fn wasm_get_audio_hash() u64 {
    if (current_profile) |profile| {
        return profile.getAudioHash();
    }
    return 0;
}

/// Initialize navigation with a target module
export fn wasm_init_navigation(dim: u32, seed: u64) i32 {
    // Create a sample module for navigation
    var module = b2t.createSampleModule(allocator) catch return -1;

    if (navigation_state) |*state| {
        state.deinit();
    }

    navigation_state = b2t.NavigationState.init(allocator, &module, dim, seed) catch {
        module.deinit();
        return -2;
    };

    // Don't deinit module - it's owned by navigation_state now
    return 0;
}

/// Perform one navigation step
export fn wasm_navigate_step(strength: f64) f64 {
    if (navigation_state) |*state| {
        state.navigateTowardsModule(strength) catch return -1.0;

        // Record DePIN operation
        if (depin_node) |*node| {
            node.recordOperation(.navigation);
        }

        // Update profile similarity if exists
        if (current_profile) |*profile| {
            profile.similarity = state.getModuleSimilarity();
        }

        return state.getModuleSimilarity();
    }
    return -1.0;
}

/// Get navigation step count
export fn wasm_get_nav_steps() u32 {
    if (navigation_state) |state| {
        return @intCast(state.step);
    }
    return 0;
}

/// Get pending $TRI rewards
export fn wasm_get_pending_tri() f64 {
    if (depin_node) |node| {
        return node.wallet.getPendingFormatted();
    }
    return 0.0;
}

/// Get total earned $TRI
export fn wasm_get_total_tri() f64 {
    if (depin_node) |node| {
        return depin.RewardCalculator.formatTRI(node.total_earned);
    }
    return 0.0;
}

/// Claim pending rewards
export fn wasm_claim_rewards() f64 {
    if (depin_node) |*node| {
        const claimed = node.wallet.claimRewards();
        return depin.RewardCalculator.formatTRI(claimed);
    }
    return 0.0;
}

/// Record an evasion operation (for DePIN rewards)
export fn wasm_record_evasion() void {
    if (depin_node) |*node| {
        node.recordOperation(.evolution);
    }
}

/// Get node status (0=offline, 1=syncing, 2=online, 3=earning)
export fn wasm_get_node_status() i32 {
    if (depin_node) |node| {
        return @intFromEnum(node.status);
    }
    return 0;
}

/// Cleanup and free resources
export fn wasm_cleanup() void {
    if (current_profile) |*profile| {
        profile.deinit();
        current_profile = null;
    }

    if (navigation_state) |*state| {
        state.deinit();
        navigation_state = null;
    }

    if (depin_node) |*node| {
        node.stop();
        depin_node = null;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVASION HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate screen resolution based on profile
export fn wasm_get_screen_width() u32 {
    if (current_profile) |profile| {
        const resolutions = [_]u32{ 1920, 1366, 1536, 1440, 1280, 2560 };
        const idx = profile.canvas_seed % resolutions.len;
        return resolutions[idx];
    }
    return 1920;
}

export fn wasm_get_screen_height() u32 {
    if (current_profile) |profile| {
        const resolutions = [_]u32{ 1080, 768, 864, 900, 720, 1440 };
        const idx = profile.canvas_seed % resolutions.len;
        return resolutions[idx];
    }
    return 1080;
}

/// Generate timezone offset based on profile
export fn wasm_get_timezone_offset() i32 {
    if (current_profile) |profile| {
        const offsets = [_]i32{ -480, -420, -360, -300, -240, 0, 60, 120, 180, 330, 480, 540 };
        const idx = profile.webgl_seed % offsets.len;
        return offsets[idx];
    }
    return 0;
}

/// Generate language code index based on profile
export fn wasm_get_language_index() u32 {
    if (current_profile) |profile| {
        // Returns index into language array: en-US, en-GB, de-DE, fr-FR, es-ES, etc.
        return @intCast(profile.audio_seed % 10);
    }
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "fingerprint profile creation" {
    const test_allocator = std.testing.allocator;
    _ = test_allocator;

    var profile = try FingerprintProfile.init(12345, 1000);
    defer profile.deinit();

    try std.testing.expect(profile.trit_vec.len == 1000);
    try std.testing.expect(profile.getCanvasHash() != 0);
    try std.testing.expect(profile.getWebGLHash() != 0);
    try std.testing.expect(profile.getAudioHash() != 0);
}

test "fingerprint hashes are deterministic" {
    var profile1 = try FingerprintProfile.init(12345, 1000);
    defer profile1.deinit();

    var profile2 = try FingerprintProfile.init(12345, 1000);
    defer profile2.deinit();

    try std.testing.expectEqual(profile1.getCanvasHash(), profile2.getCanvasHash());
    try std.testing.expectEqual(profile1.getWebGLHash(), profile2.getWebGLHash());
}

test "different seeds produce different hashes" {
    var profile1 = try FingerprintProfile.init(12345, 1000);
    defer profile1.deinit();

    var profile2 = try FingerprintProfile.init(67890, 1000);
    defer profile2.deinit();

    try std.testing.expect(profile1.getCanvasHash() != profile2.getCanvasHash());
}
