// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE WALLET - $TRI Token Wallet Management
// Secure storage, balance tracking, reward claiming
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const crypto = @import("crypto.zig");
const protocol = @import("protocol.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const TRI_DECIMALS: u8 = 18;
pub const TRI_SYMBOL = "$TRI";
pub const TRI_NAME = "Trinity Token";

// ═══════════════════════════════════════════════════════════════════════════════
// WALLET
// ═══════════════════════════════════════════════════════════════════════════════

pub const Wallet = struct {
    keypair: crypto.KeyPair,
    balance: u128, // $TRI in wei (18 decimals)
    pending_rewards: u128,
    jobs_completed: u64,
    tokens_generated: u64,
    total_earned: u128,
    nonce: u64,

    /// Generate new wallet with random keypair
    pub fn generate() Wallet {
        return Wallet{
            .keypair = crypto.KeyPair.generate(),
            .balance = 0,
            .pending_rewards = 0,
            .jobs_completed = 0,
            .tokens_generated = 0,
            .total_earned = 0,
            .nonce = 0,
        };
    }

    /// Create wallet from existing keypair
    pub fn fromKeypair(keypair: crypto.KeyPair) Wallet {
        return Wallet{
            .keypair = keypair,
            .balance = 0,
            .pending_rewards = 0,
            .jobs_completed = 0,
            .tokens_generated = 0,
            .total_earned = 0,
            .nonce = 0,
        };
    }

    /// Load wallet from encrypted file
    pub fn load(path: []const u8, password: []const u8) !Wallet {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var buf: [crypto.WalletFile.SIZE]u8 = undefined;
        const bytes_read = try file.readAll(&buf);
        if (bytes_read != crypto.WalletFile.SIZE) {
            return error.InvalidWalletFile;
        }

        const wf = try crypto.WalletFile.deserialize(&buf);
        const keypair = try crypto.decryptWalletFile(&wf, password);

        return Wallet.fromKeypair(keypair);
    }

    /// Load wallet or create new one if doesn't exist
    pub fn loadOrCreate(path: []const u8, password: []const u8) !Wallet {
        return Wallet.load(path, password) catch |err| {
            if (err == error.FileNotFound) {
                var wallet = Wallet.generate();
                try wallet.save(path, password);
                return wallet;
            }
            return err;
        };
    }

    /// Save wallet to encrypted file
    pub fn save(self: *const Wallet, path: []const u8, password: []const u8) !void {
        const wf = crypto.createWalletFile(&self.keypair, password);
        const bytes = wf.serialize();

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writeAll(&bytes);
    }

    /// Get node ID (32 bytes)
    pub fn getNodeId(self: *const Wallet) protocol.NodeId {
        return self.keypair.getNodeId();
    }

    /// Get wallet address (20 bytes)
    pub fn getAddress(self: *const Wallet) [20]u8 {
        return self.keypair.getAddress();
    }

    /// Get wallet address as hex string
    pub fn getAddressHex(self: *const Wallet) [42]u8 {
        return self.keypair.getAddressHex();
    }

    /// Get public key
    pub fn getPublicKey(self: *const Wallet) [32]u8 {
        return self.keypair.public_key;
    }

    /// Sign a message
    pub fn sign(self: *const Wallet, message: []const u8) [64]u8 {
        return self.keypair.sign(message);
    }

    /// Sign job result (for proof of inference)
    pub fn signJobResult(self: *const Wallet, job_id: protocol.JobId, response: []const u8) [64]u8 {
        const hash = crypto.hashJobResult(job_id, response);
        return self.keypair.sign(&hash);
    }

    /// Add pending reward
    pub fn addReward(self: *Wallet, amount: u128) void {
        self.pending_rewards += amount;
        self.total_earned += amount;
    }

    /// Record completed job with reward
    pub fn recordJob(self: *Wallet, tokens: u64, latency_ms: u32, uptime_pct: f32) void {
        self.jobs_completed += 1;
        self.tokens_generated += tokens;
        const reward = protocol.calculateJobReward(tokens, latency_ms, uptime_pct);
        self.addReward(reward);
    }

    /// Claim all pending rewards to balance
    pub fn claimRewards(self: *Wallet) u128 {
        const rewards = self.pending_rewards;
        self.balance += rewards;
        self.pending_rewards = 0;
        self.nonce += 1;
        return rewards;
    }

    /// Get balance formatted as decimal string (e.g., "123.456789")
    pub fn getBalanceFormatted(self: *const Wallet) f64 {
        return weiToTri(self.balance);
    }

    /// Get pending rewards formatted
    pub fn getPendingFormatted(self: *const Wallet) f64 {
        return weiToTri(self.pending_rewards);
    }

    /// Get total earned formatted
    pub fn getTotalEarnedFormatted(self: *const Wallet) f64 {
        return weiToTri(self.total_earned);
    }

    /// Get wallet stats for UI display
    pub fn getStats(self: *const Wallet) WalletStats {
        return WalletStats{
            .address = self.getAddressHex(),
            .balance_tri = self.getBalanceFormatted(),
            .pending_tri = self.getPendingFormatted(),
            .total_earned_tri = self.getTotalEarnedFormatted(),
            .jobs_completed = self.jobs_completed,
            .tokens_generated = self.tokens_generated,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert wei to TRI (floating point)
pub fn weiToTri(wei: u128) f64 {
    const divisor: u128 = std.math.pow(u128, 10, TRI_DECIMALS);
    return @as(f64, @floatFromInt(wei)) / @as(f64, @floatFromInt(divisor));
}

/// Convert TRI to wei
pub fn triToWei(tri: f64) u128 {
    const multiplier: f64 = @floatFromInt(std.math.pow(u128, 10, TRI_DECIMALS));
    return @intFromFloat(tri * multiplier);
}

/// Format TRI amount for display (e.g., "123.45 $TRI")
pub fn formatTri(allocator: std.mem.Allocator, wei: u128) ![]u8 {
    const tri = weiToTri(wei);
    return std.fmt.allocPrint(allocator, "{d:.6} {s}", .{ tri, TRI_SYMBOL });
}

// ═══════════════════════════════════════════════════════════════════════════════
// WALLET STATS (for UI display)
// ═══════════════════════════════════════════════════════════════════════════════

pub const WalletStats = struct {
    address: [42]u8,
    balance_tri: f64,
    pending_tri: f64,
    total_earned_tri: f64,
    jobs_completed: u64,
    tokens_generated: u64,
};

pub fn getWalletStats(wallet: *const Wallet) WalletStats {
    return WalletStats{
        .address = wallet.getAddressHex(),
        .balance_tri = wallet.getBalanceFormatted(),
        .pending_tri = wallet.getPendingFormatted(),
        .total_earned_tri = wallet.getTotalEarnedFormatted(),
        .jobs_completed = wallet.jobs_completed,
        .tokens_generated = wallet.tokens_generated,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "wallet generation" {
    const wallet = Wallet.generate();
    try std.testing.expectEqual(@as(u128, 0), wallet.balance);
    try std.testing.expectEqual(@as(u64, 0), wallet.jobs_completed);
}

test "wallet address format" {
    const wallet = Wallet.generate();
    const addr = wallet.getAddressHex();

    try std.testing.expectEqual(@as(u8, '0'), addr[0]);
    try std.testing.expectEqual(@as(u8, 'x'), addr[1]);
    try std.testing.expectEqual(@as(usize, 42), addr.len);
}

test "wallet rewards" {
    var wallet = Wallet.generate();

    // Simulate a job: 1000 tokens, 500ms latency, 100% uptime
    wallet.recordJob(1000, 500, 1.0);

    try std.testing.expectEqual(@as(u64, 1), wallet.jobs_completed);
    try std.testing.expect(wallet.pending_rewards > 0);

    const claimed = wallet.claimRewards();
    try std.testing.expect(claimed > 0);
    try std.testing.expectEqual(@as(u128, 0), wallet.pending_rewards);
    try std.testing.expectEqual(claimed, wallet.balance);
}

test "wei to tri conversion" {
    const one_tri_wei: u128 = 1_000_000_000_000_000_000;
    const tri = weiToTri(one_tri_wei);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), tri, 0.0001);

    const back_to_wei = triToWei(1.0);
    try std.testing.expectEqual(one_tri_wei, back_to_wei);
}

test "wallet signing" {
    const wallet = Wallet.generate();
    const message = "Test message";

    const signature = wallet.sign(message);
    try std.testing.expect(crypto.KeyPair.verify(wallet.keypair.public_key, message, signature));
}

test "job result signing" {
    const wallet = Wallet.generate();
    var job_id: protocol.JobId = undefined;
    @memset(&job_id, 0xAB);
    const response = "Hello from Trinity Node";

    const signature = wallet.signJobResult(job_id, response);
    try std.testing.expect(signature.len == 64);
}
