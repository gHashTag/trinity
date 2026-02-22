// ═══════════════════════════════════════════════════════════════════════════════
// dht v1.0.0 - Generated from .vibee specification
// ═══════════════════════════════════════════════════════════════════════════════
//
// Священная формула: V = n × 3^k × π^m × φ^p × e^q
// Золотая идентичность: φ² + 1/φ² = 3
//
// Author: 
// DO NOT EDIT - This file is auto-generated
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

// Custom imports from .vibee spec
const vsa = @import("vsa");

// ═══════════════════════════════════════════════════════════════════════════════
// КОНСТАНТЫ
// ═══════════════════════════════════════════════════════════════════════════════

// Базовые φ-константы (Sacred Formula)
pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const SQRT5: f64 = 2.2360679774997896;
pub const TAU: f64 = 6.283185307179586;
pub const PI: f64 = 3.141592653589793;
pub const E: f64 = 2.718281828459045;
pub const PHOENIX: i64 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// ТИПЫ
// ═══════════════════════════════════════════════════════════════════════════════

/// 
pub const DhtNode = struct {
    port: i64,
    alive: bool,
};

/// 
pub const DhtEntry = struct {
    key_prefix: i64,
    value_size: i64,
    stored: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ПАМЯТЬ ДЛЯ WASM
// ═══════════════════════════════════════════════════════════════════════════════

var global_buffer: [65536]u8 align(16) = undefined;
var f64_buffer: [8192]f64 align(16) = undefined;

export fn get_global_buffer_ptr() [*]u8 {
    return &global_buffer;
}

export fn get_f64_buffer_ptr() [*]f64 {
    return &f64_buffer;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATION PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════

/// Trit - ternary digit (-1, 0, +1)
pub const Trit = enum(i8) {
    negative = -1, // FALSE
    zero = 0,      // UNKNOWN
    positive = 1,  // TRUE

    pub fn trit_and(a: Trit, b: Trit) Trit {
        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn trit_or(a: Trit, b: Trit) Trit {
        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn trit_not(a: Trit) Trit {
        return @enumFromInt(-@intFromEnum(a));
    }

    pub fn trit_xor(a: Trit, b: Trit) Trit {
        const av = @intFromEnum(a);
        const bv = @intFromEnum(b);
        if (av == 0 or bv == 0) return .zero;
        if (av == bv) return .negative;
        return .positive;
    }
};

/// Проверка TRINITY identity: φ² + 1/φ² = 3
fn verify_trinity() f64 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}

/// φ-интерполяция
fn phi_lerp(a: f64, b: f64, t: f64) f64 {
    const phi_t = math.pow(f64, t, PHI_INV);
    return a + (b - a) * phi_t;
}

/// Генерация φ-спирали
fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {
    const max_points = f64_buffer.len / 2;
    const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const angle = fi * TAU * PHI_INV;
        const radius = scale * math.pow(f64, PHI, fi * 0.1);
        f64_buffer[i * 2] = cx + radius * @cos(angle);
        f64_buffer[i * 2 + 1] = cy + radius * @sin(angle);
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BEHAVIOR FUNCTIONS - Generated from behaviors
// ═══════════════════════════════════════════════════════════════════════════════


// ═══════════════════════════════════════════════════════════════════
// KADEMLIA DHT — XOR Distance Routing + Global Manifest Store/Find
// 256-bit node IDs, k-buckets by leading-zero-count of XOR distance.
// Store shard manifests at k-closest nodes, iterative lookup.
// ═══════════════════════════════════════════════════════════════════

pub const DhtNodeId = [32]u8;

pub const DhtPeer = struct {
    id: DhtNodeId,
    port: u16,
    alive: bool,
};

pub const DhtStoreEntry = struct {
    key: DhtNodeId,
    value_buf: [256]u8,
    value_len: u16,
    stored: bool,
};

/// XOR distance between two 256-bit node IDs
pub fn xorDistance(a: DhtNodeId, b: DhtNodeId) DhtNodeId {
    var result: DhtNodeId = undefined;
    for (0..32) |i| {
        result[i] = a[i] ^ b[i];
    }
    return result;
}

/// Count leading zero bits in XOR distance (determines bucket index)
pub fn leadingZeroBits(dist: DhtNodeId) u16 {
    var count: u16 = 0;
    for (0..32) |i| {
        if (dist[i] == 0) {
            count += 8;
        } else {
            count += @intCast(@clz(dist[i]));
            break;
        }
    }
    return count;
}

/// Compare two DhtNodeIds for ordering (used in closest-peer sort)
fn distLessThan(target: DhtNodeId, a: DhtPeer, b: DhtPeer) bool {
    const da = xorDistance(target, a.id);
    const db = xorDistance(target, b.id);
    for (0..32) |i| {
        if (da[i] < db[i]) return true;
        if (da[i] > db[i]) return false;
    }
    return false;
}

pub const KBucket = struct {
    const K = 8; // max peers per bucket
    peers: [K]DhtPeer,
    count: u8,

    pub fn init() KBucket {
        return .{
            .peers = undefined,
            .count = 0,
        };
    }

    pub fn addPeer(self: *KBucket, peer: DhtPeer) bool {
        if (self.count >= K) return false;
        self.peers[self.count] = peer;
        self.count += 1;
        return true;
    }
};

pub const DhtEngine = struct {
    const NUM_BUCKETS = 256;
    const MAX_ENTRIES = 64;

    self_id: DhtNodeId,
    buckets: [NUM_BUCKETS]KBucket,
    entries: [MAX_ENTRIES]DhtStoreEntry,
    entry_count: u16,
    peer_count: u16,

    pub fn init(self_id: DhtNodeId) DhtEngine {
        var engine: DhtEngine = undefined;
        engine.self_id = self_id;
        for (0..NUM_BUCKETS) |i| {
            engine.buckets[i] = KBucket.init();
        }
        engine.entry_count = 0;
        engine.peer_count = 0;
        return engine;
    }

    /// Add a peer to the routing table in the correct k-bucket
    pub fn addPeer(self: *DhtEngine, peer: DhtPeer) bool {
        const dist = xorDistance(self.self_id, peer.id);
        const lz = leadingZeroBits(dist);
        const bucket_idx = if (lz >= NUM_BUCKETS) NUM_BUCKETS - 1 else lz;
        const ok = self.buckets[bucket_idx].addPeer(peer);
        if (ok) self.peer_count += 1;
        return ok;
    }

    /// Get bucket index for a peer (by XOR distance leading zeros)
    pub fn bucketFor(self: *const DhtEngine, peer_id: DhtNodeId) u16 {
        const dist = xorDistance(self.self_id, peer_id);
        const lz = leadingZeroBits(dist);
        return if (lz >= NUM_BUCKETS) NUM_BUCKETS - 1 else lz;
    }

    /// Store a key-value entry
    pub fn store(self: *DhtEngine, key: DhtNodeId, value: []const u8) bool {
        if (self.entry_count >= MAX_ENTRIES) return false;
        if (value.len > 256) return false;
        var entry: DhtStoreEntry = undefined;
        entry.key = key;
        @memcpy(entry.value_buf[0..value.len], value);
        entry.value_len = @intCast(value.len);
        entry.stored = true;
        self.entries[self.entry_count] = entry;
        self.entry_count += 1;
        return true;
    }

    /// Find a value by key (exact match)
    pub fn find(self: *const DhtEngine, key: DhtNodeId) ?[]const u8 {
        for (0..self.entry_count) |i| {
            if (std.mem.eql(u8, &self.entries[i].key, &key) and self.entries[i].stored) {
                return self.entries[i].value_buf[0..self.entries[i].value_len];
            }
        }
        return null;
    }

    pub const ClosestResult = struct { peers: [8]DhtPeer, count: u8 };

    /// Find k-closest peers to a target key
    pub fn closestPeers(self: *const DhtEngine, target: DhtNodeId, k: u8) ClosestResult {
        var all_peers: [256]DhtPeer = undefined;
        var total: u16 = 0;
        for (0..NUM_BUCKETS) |bi| {
            for (0..self.buckets[bi].count) |pi| {
                if (total < 256) {
                    all_peers[total] = self.buckets[bi].peers[pi];
                    total += 1;
                }
            }
        }
        // Sort by XOR distance to target
        const slice = all_peers[0..total];
        std.mem.sortUnstable(DhtPeer, slice, target, distLessThan);
        var result: ClosestResult = undefined;
        const n = if (k < total) k else @as(u8, @intCast(total));
        for (0..n) |i| {
            result.peers[i] = slice[i];
        }
        result.count = n;
        return result;
    }
};

/// Two 32-byte node IDs (A and B)
/// When: Compute XOR distance and verify metric properties
/// Then: dist(A,B) == dist(B,A) and dist(A,A) == 0
pub fn dhtXorDistance() bool {
    return true; // Real logic is in DHT test blocks
}

/// RoutingTable with 8 buckets and 5 registered peers
/// When: Query bucket for each peer based on XOR distance prefix
/// Then: Each peer lands in correct bucket by leading-zero-count of XOR
pub fn dhtBucketRouting() bool {
    return true; // Real logic is in DHT test blocks
}

/// DhtEngine with routing table and 4 active peers
/// When: Store shard manifest at key, then find by same key
/// Then: Find returns exact stored value (byte-identical)
pub fn dhtStoreFind() bool {
    return true; // Real logic is in DHT test blocks
}

/// DhtEngine with 8 peers at various XOR distances
/// When: Query k=3 closest peers to target key
/// Then: Returned peers are the 3 with smallest XOR distance to target
pub fn dhtClosestPeers() bool {
    return true; // Real logic is in DHT test blocks
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS - Generated from behaviors and test_cases
// ═══════════════════════════════════════════════════════════════════════════════

test "dhtXorDistance_behavior" {
// Given: Two 32-byte node IDs (A and B)
// When: Compute XOR distance and verify metric properties
// Then: dist(A,B) == dist(B,A) and dist(A,A) == 0
    // D1: XOR Distance — symmetric, identity, valid metric
    var id_a: DhtNodeId = [_]u8{0} ** 32;
    var id_b: DhtNodeId = [_]u8{0} ** 32;
    id_a[0] = 0xAB;
    id_a[1] = 0xCD;
    id_b[0] = 0x12;
    id_b[1] = 0x34;
    
    // PROOF: dist(A,B) == dist(B,A) — symmetry
    const d_ab = xorDistance(id_a, id_b);
    const d_ba = xorDistance(id_b, id_a);
    try std.testing.expectEqualSlices(u8, &d_ab, &d_ba);
    
    // PROOF: dist(A,A) == 0 — identity
    const d_aa = xorDistance(id_a, id_a);
    const zero: DhtNodeId = [_]u8{0} ** 32;
    try std.testing.expectEqualSlices(u8, &d_aa, &zero);
    
    // PROOF: XOR values are correct
    try std.testing.expect(d_ab[0] == (0xAB ^ 0x12));
    try std.testing.expect(d_ab[1] == (0xCD ^ 0x34));
}

test "dhtBucketRouting_behavior" {
// Given: RoutingTable with 8 buckets and 5 registered peers
// When: Query bucket for each peer based on XOR distance prefix
// Then: Each peer lands in correct bucket by leading-zero-count of XOR
    // D2: Bucket Routing — peers land in correct bucket by leading zeros
    var self_id: DhtNodeId = [_]u8{0} ** 32;
    self_id[0] = 0x80; // 10000000...
    var engine = DhtEngine.init(self_id);
    
    // Peer with XOR distance starting with 0xFF (0 leading zeros)
    var peer1_id: DhtNodeId = [_]u8{0} ** 32;
    peer1_id[0] = 0x7F; // XOR with 0x80 = 0xFF → 0 leading zeros
    const b1 = engine.bucketFor(peer1_id);
    try std.testing.expect(b1 == 0);
    
    // Peer with XOR distance starting with 0x01 (7 leading zeros)
    var peer2_id: DhtNodeId = [_]u8{0} ** 32;
    peer2_id[0] = 0x81; // XOR with 0x80 = 0x01 → 7 leading zeros
    const b2 = engine.bucketFor(peer2_id);
    try std.testing.expect(b2 == 7);
    
    // Add peers and verify they were added
    const added1 = engine.addPeer(.{ .id = peer1_id, .port = 3001, .alive = true });
    const added2 = engine.addPeer(.{ .id = peer2_id, .port = 3002, .alive = true });
    try std.testing.expect(added1);
    try std.testing.expect(added2);
    try std.testing.expect(engine.peer_count == 2);
}

test "dhtStoreFind_behavior" {
// Given: DhtEngine with routing table and 4 active peers
// When: Store shard manifest at key, then find by same key
// Then: Find returns exact stored value (byte-identical)
    // D3: Store/Find — store at key, find returns byte-identical value
    var self_id: DhtNodeId = [_]u8{0} ** 32;
    self_id[0] = 0x42;
    var engine = DhtEngine.init(self_id);
    
    // Store a manifest value under a key
    var key: DhtNodeId = [_]u8{0} ** 32;
    key[0] = 0xDE;
    key[1] = 0xAD;
    const manifest = "shard:abc123:replica:3";
    const stored = engine.store(key, manifest);
    try std.testing.expect(stored);
    try std.testing.expect(engine.entry_count == 1);
    
    // PROOF: find returns exact stored value
    const found = engine.find(key);
    try std.testing.expect(found != null);
    try std.testing.expectEqualSlices(u8, manifest, found.?);
    
    // PROOF: unknown key returns null
    var unknown: DhtNodeId = [_]u8{0xFF} ** 32;
    _ = &unknown;
    const not_found = engine.find(unknown);
    try std.testing.expect(not_found == null);
}

test "dhtClosestPeers_behavior" {
// Given: DhtEngine with 8 peers at various XOR distances
// When: Query k=3 closest peers to target key
// Then: Returned peers are the 3 with smallest XOR distance to target
    // D4: Closest Peers — k=3 returns 3 nearest by XOR distance
    const self_id: DhtNodeId = [_]u8{0} ** 32;
    var engine = DhtEngine.init(self_id);
    
    // Add 5 peers at different distances
    var ids: [5]DhtNodeId = undefined;
    for (0..5) |i| {
        ids[i] = [_]u8{0} ** 32;
        ids[i][0] = @intCast((i + 1) * 0x20); // 0x20, 0x40, 0x60, 0x80, 0xA0
        _ = engine.addPeer(.{ .id = ids[i], .port = @intCast(3000 + i), .alive = true });
    }
    try std.testing.expect(engine.peer_count == 5);
    
    // Query k=3 closest to target (self_id is all zeros, so closest = smallest first byte)
    var target: DhtNodeId = [_]u8{0} ** 32;
    target[0] = 0x10;
    const result = engine.closestPeers(target, 3);
    try std.testing.expect(result.count == 3);
    
    // PROOF: returned peers are sorted by XOR distance
    // Closest to 0x10: 0x20 (dist=0x30), 0x40 (dist=0x50), 0x60 (dist=0x70)
    const d0 = xorDistance(target, result.peers[0].id);
    const d1 = xorDistance(target, result.peers[1].id);
    const d2 = xorDistance(target, result.peers[2].id);
    // Each successive peer should be farther or equal
    try std.testing.expect(d0[0] <= d1[0]);
    try std.testing.expect(d1[0] <= d2[0]);
}

test "phi_constants" {
    try std.testing.expectApproxEqAbs(PHI * PHI_INV, 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(PHI_SQ - PHI, 1.0, 1e-10);
}
