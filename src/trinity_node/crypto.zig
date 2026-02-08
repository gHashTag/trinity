// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE CRYPTO - ed25519 Signing & AES Encryption
// Secure wallet storage and job result signing
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;
const Sha256 = std.crypto.hash.sha2.Sha256;
const Aes256Gcm = std.crypto.aead.aes_gcm.Aes256Gcm;

// ═══════════════════════════════════════════════════════════════════════════════
// ED25519 KEY PAIR
// ═══════════════════════════════════════════════════════════════════════════════

pub const KeyPair = struct {
    secret_key: [64]u8, // Ed25519 secret key (seed + public)
    public_key: [32]u8,

    /// Generate new random keypair
    pub fn generate() KeyPair {
        var seed: [32]u8 = undefined;
        std.crypto.random.bytes(&seed);
        return fromSeed(seed);
    }

    /// Create keypair from seed (deterministic)
    pub fn fromSeed(seed: [32]u8) KeyPair {
        const kp = Ed25519.KeyPair.generateDeterministic(seed) catch unreachable;
        return KeyPair{
            .secret_key = kp.secret_key.toBytes(),
            .public_key = kp.public_key.toBytes(),
        };
    }

    /// Sign a message
    pub fn sign(self: *const KeyPair, message: []const u8) [64]u8 {
        const secret_key = Ed25519.SecretKey.fromBytes(self.secret_key) catch unreachable;
        const kp = Ed25519.KeyPair.fromSecretKey(secret_key) catch unreachable;
        const sig = kp.sign(message, null) catch unreachable;
        return sig.toBytes();
    }

    /// Verify a signature
    pub fn verify(public_key: [32]u8, message: []const u8, signature: [64]u8) bool {
        const pub_key = Ed25519.PublicKey.fromBytes(public_key) catch return false;
        const sig = Ed25519.Signature.fromBytes(signature);
        sig.verify(message, pub_key) catch return false;
        return true;
    }

    /// Get node ID (first 32 bytes of SHA256 of public key)
    pub fn getNodeId(self: *const KeyPair) [32]u8 {
        var out: [32]u8 = undefined;
        Sha256.hash(&self.public_key, &out, .{});
        return out;
    }

    /// Get wallet address (first 20 bytes of SHA256 of public key)
    pub fn getAddress(self: *const KeyPair) [20]u8 {
        var hash: [32]u8 = undefined;
        Sha256.hash(&self.public_key, &hash, .{});
        return hash[0..20].*;
    }

    /// Get address as hex string
    pub fn getAddressHex(self: *const KeyPair) [42]u8 {
        const addr = self.getAddress();
        var hex: [42]u8 = undefined;
        hex[0] = '0';
        hex[1] = 'x';
        for (addr, 0..) |byte, i| {
            const high = byte >> 4;
            const low = byte & 0x0F;
            hex[2 + i * 2] = if (high < 10) '0' + high else 'a' + high - 10;
            hex[3 + i * 2] = if (low < 10) '0' + low else 'a' + low - 10;
        }
        return hex;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// AES-256-GCM ENCRYPTION (for wallet storage)
// ═══════════════════════════════════════════════════════════════════════════════

pub const EncryptedData = struct {
    nonce: [12]u8,
    ciphertext: []const u8,
    tag: [16]u8,
};

/// Derive AES key from password using PBKDF2-like hash iterations
pub fn deriveKey(password: []const u8, salt: [16]u8) [32]u8 {
    // Simple key derivation: SHA256(password || salt) repeated
    var key: [32]u8 = undefined;
    var hasher = Sha256.init(.{});
    hasher.update(password);
    hasher.update(&salt);
    key = hasher.finalResult();

    // Additional iterations for security
    for (0..10000) |_| {
        var h = Sha256.init(.{});
        h.update(&key);
        h.update(&salt);
        key = h.finalResult();
    }

    return key;
}

/// Encrypt data with AES-256-GCM
pub fn encrypt(allocator: std.mem.Allocator, plaintext: []const u8, key: [32]u8) !EncryptedData {
    var nonce: [12]u8 = undefined;
    std.crypto.random.bytes(&nonce);

    const ciphertext = try allocator.alloc(u8, plaintext.len);
    var tag: [16]u8 = undefined;

    Aes256Gcm.encrypt(ciphertext, &tag, plaintext, "", nonce, key);

    return EncryptedData{
        .nonce = nonce,
        .ciphertext = ciphertext,
        .tag = tag,
    };
}

/// Decrypt data with AES-256-GCM
pub fn decrypt(allocator: std.mem.Allocator, encrypted: EncryptedData, key: [32]u8) ![]u8 {
    const plaintext = try allocator.alloc(u8, encrypted.ciphertext.len);

    Aes256Gcm.decrypt(plaintext, encrypted.ciphertext, encrypted.tag, "", encrypted.nonce, key) catch {
        allocator.free(plaintext);
        return error.DecryptionFailed;
    };

    return plaintext;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WALLET FILE FORMAT
// ═══════════════════════════════════════════════════════════════════════════════

pub const WalletFile = struct {
    magic: [4]u8 = .{ 'T', 'R', 'I', 'W' }, // Trinity Wallet
    version: u8 = 1,
    salt: [16]u8,
    nonce: [12]u8,
    tag: [16]u8,
    encrypted_secret_key: [64]u8, // Encrypted ed25519 secret key

    pub const SIZE: usize = 4 + 1 + 16 + 12 + 16 + 64; // 113 bytes

    /// Serialize wallet file to bytes
    pub fn serialize(self: *const WalletFile) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..4], &self.magic);
        i += 4;
        buf[i] = self.version;
        i += 1;
        @memcpy(buf[i..][0..16], &self.salt);
        i += 16;
        @memcpy(buf[i..][0..12], &self.nonce);
        i += 12;
        @memcpy(buf[i..][0..16], &self.tag);
        i += 16;
        @memcpy(buf[i..][0..64], &self.encrypted_secret_key);

        return buf;
    }

    /// Deserialize wallet file from bytes
    pub fn deserialize(data: []const u8) !WalletFile {
        if (data.len < SIZE) return error.InvalidWalletFile;

        var wf: WalletFile = undefined;
        var i: usize = 0;

        @memcpy(&wf.magic, data[i..][0..4]);
        i += 4;

        // Validate magic
        if (!std.mem.eql(u8, &wf.magic, &.{ 'T', 'R', 'I', 'W' })) {
            return error.InvalidMagic;
        }

        wf.version = data[i];
        i += 1;

        if (wf.version != 1) return error.UnsupportedVersion;

        @memcpy(&wf.salt, data[i..][0..16]);
        i += 16;
        @memcpy(&wf.nonce, data[i..][0..12]);
        i += 12;
        @memcpy(&wf.tag, data[i..][0..16]);
        i += 16;
        @memcpy(&wf.encrypted_secret_key, data[i..][0..64]);

        return wf;
    }
};

/// Create encrypted wallet file from keypair
pub fn createWalletFile(keypair: *const KeyPair, password: []const u8) WalletFile {
    var wf: WalletFile = .{
        .salt = undefined,
        .nonce = undefined,
        .tag = undefined,
        .encrypted_secret_key = undefined,
    };

    // Generate random salt and nonce
    std.crypto.random.bytes(&wf.salt);
    std.crypto.random.bytes(&wf.nonce);

    // Derive key from password
    const key = deriveKey(password, wf.salt);

    // Encrypt secret key
    Aes256Gcm.encrypt(&wf.encrypted_secret_key, &wf.tag, &keypair.secret_key, "", wf.nonce, key);

    return wf;
}

/// Decrypt wallet file to get keypair
pub fn decryptWalletFile(wf: *const WalletFile, password: []const u8) !KeyPair {
    // Derive key from password
    const key = deriveKey(password, wf.salt);

    // Decrypt secret key
    var secret_key: [64]u8 = undefined;
    Aes256Gcm.decrypt(&secret_key, &wf.encrypted_secret_key, wf.tag, "", wf.nonce, key) catch {
        return error.WrongPassword;
    };

    // Extract public key from secret key (last 32 bytes)
    return KeyPair{
        .secret_key = secret_key,
        .public_key = secret_key[32..64].*,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// HASH UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// SHA256 hash
pub fn sha256(data: []const u8) [32]u8 {
    var out: [32]u8 = undefined;
    Sha256.hash(data, &out, .{});
    return out;
}

/// Hash job result for signing (job_id || response_hash)
pub fn hashJobResult(job_id: [16]u8, response: []const u8) [32]u8 {
    var response_hash: [32]u8 = undefined;
    Sha256.hash(response, &response_hash, .{});

    var hasher = Sha256.init(.{});
    hasher.update(&job_id);
    hasher.update(&response_hash);
    return hasher.finalResult();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "keypair generation and signing" {
    const kp = KeyPair.generate();
    const message = "Hello, Trinity Network!";

    const signature = kp.sign(message);
    try std.testing.expect(KeyPair.verify(kp.public_key, message, signature));

    // Wrong message should fail
    try std.testing.expect(!KeyPair.verify(kp.public_key, "Wrong message", signature));
}

test "keypair from seed is deterministic" {
    const seed = [_]u8{0x42} ** 32;
    const kp1 = KeyPair.fromSeed(seed);
    const kp2 = KeyPair.fromSeed(seed);

    try std.testing.expectEqualSlices(u8, &kp1.public_key, &kp2.public_key);
    try std.testing.expectEqualSlices(u8, &kp1.secret_key, &kp2.secret_key);
}

test "address generation" {
    const kp = KeyPair.generate();
    const addr_hex = kp.getAddressHex();

    try std.testing.expectEqual(@as(u8, '0'), addr_hex[0]);
    try std.testing.expectEqual(@as(u8, 'x'), addr_hex[1]);
}

test "wallet file encrypt/decrypt" {
    const kp = KeyPair.generate();
    const password = "test_password_123";

    const wf = createWalletFile(&kp, password);
    const decrypted = try decryptWalletFile(&wf, password);

    try std.testing.expectEqualSlices(u8, &kp.public_key, &decrypted.public_key);

    // Wrong password should fail
    const result = decryptWalletFile(&wf, "wrong_password");
    try std.testing.expectError(error.WrongPassword, result);
}

test "wallet file serialize/deserialize" {
    const kp = KeyPair.generate();
    const wf = createWalletFile(&kp, "password");

    const bytes = wf.serialize();
    const parsed = try WalletFile.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &wf.salt, &parsed.salt);
    try std.testing.expectEqualSlices(u8, &wf.nonce, &parsed.nonce);
}

test "encryption roundtrip" {
    const allocator = std.testing.allocator;
    const plaintext = "Secret data to encrypt!";
    const key = [_]u8{0x42} ** 32;

    const encrypted = try encrypt(allocator, plaintext, key);
    defer allocator.free(encrypted.ciphertext);

    const decrypted = try decrypt(allocator, encrypted, key);
    defer allocator.free(decrypted);

    try std.testing.expectEqualStrings(plaintext, decrypted);
}
