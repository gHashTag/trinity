//! TRINITY v9.3 E8-VSA UNIFIED THEORY — Lisi-Style Particle Assignment
//!
//! This module implements the mapping between E8 Lie Group roots and
//! Standard Model particles using Vector Symbolic Architecture (VSA).
//!
//! Mathematical foundation:
//! - E8 has 240 roots in 8 dimensions
//! - Standard Model has 61 particles (quarks, leptons, bosons, Higgs)
//! - Hypervectors: 1024-dimensional ternary vectors {-1, 0, +1}
//! - Similarity search finds optimal E8→particle assignments
//!
//! Algorithm:
//! 1. Encode all 240 E8 roots as hypervectors
//! 2. Encode all 61 SM particles as hypervectors
//! 3. Find best matches using cosine similarity
//! 4. Predict unknown particles from remaining E8 roots

const std = @import("std");
const sacred_formula = @import("sacred_formula");

//==============================================================================
// Imports from related modules
//==============================================================================

const E8Root = struct {
    components: [8]f64,

    pub fn init(components: [8]f64) E8Root {
        return .{ .components = components };
    }

    pub fn normSquared(self: E8Root) f64 {
        var sum: f64 = 0;
        for (self.components) |c| {
            sum += c * c;
        }
        return sum;
    }

    /// Generate all 240 E8 roots
    /// Returns array of 240 8D vectors with norm² = 2
    pub fn generate(allocator: std.mem.Allocator) ![]E8Root {
        const num_roots = 240;
        var roots = try allocator.alloc(E8Root, num_roots);
        errdefer allocator.free(roots);

        var idx: usize = 0;

        // 112 roots: (±1, ±1, 0, 0, 0, 0, 0, 0) and permutations
        // Choose 2 positions out of 8 for ±1
        for (0..8) |i| {
            for (i + 1..8) |j| {
                // All sign combinations
                const signs = [4][2]i8{
                    .{ 1, 1 },
                    .{ 1, -1 },
                    .{ -1, 1 },
                    .{ -1, -1 },
                };

                for (signs) |s| {
                    if (idx >= num_roots) break;

                    var components = [_]f64{0} ** 8;
                    components[i] = @floatFromInt(s[0]);
                    components[j] = @floatFromInt(s[1]);

                    roots[idx] = E8Root{ .components = components };
                    idx += 1;
                }
            }
        }

        // 128 roots: (±½, ±½, ±½, ±½, ±½, ±½, ±½, ±½)
        // with even number of minus signs
        for (0..128) |k| {
            if (idx >= num_roots) break;

            var components = [_]f64{0.5} ** 8;
            var minus_count: usize = 0;

            // Use bits of k to determine signs (but enforce even number of -)
            var temp = k;
            for (0..8) |i| {
                if (temp & 1 == 1) {
                    components[i] = -0.5;
                    minus_count += 1;
                }
                temp >>= 1;
            }

            // Ensure even number of minus signs
            if (minus_count % 2 == 0) {
                roots[idx] = E8Root{ .components = components };
                idx += 1;
            }
        }

        return roots;
    }
};

const vsa_bridge = @import("vsa_quantum_bridge");
const Hypervector = vsa_bridge.Hypervector;
const SacredParams = vsa_bridge.SacredParams;

//==============================================================================
// Constants
//==============================================================================

pub const E8_NUM_ROOTS: usize = 240;
pub const SM_NUM_PARTICLES: usize = 61;
pub const SIMILARITY_THRESHOLD: f64 = 0.0; // No threshold for proof-of-concept
pub const MIN_CONFIDENCE: f64 = 0.5;

// Golden ratio for mass encoding
const PHI: f64 = sacred_formula.PHI;
const PI: f64 = std.math.pi;
const E: f64 = std.math.e;

//==============================================================================
// Particle Types
//==============================================================================

/// Standard Model particle classification
pub const ParticleType = enum(u3) {
    quark,
    lepton,
    gauge_boson,
    higgs,
    unknown,

    pub fn toString(pt: ParticleType) []const u8 {
        return switch (pt) {
            .quark => "quark",
            .lepton => "lepton",
            .gauge_boson => "gauge_boson",
            .higgs => "higgs",
            .unknown => "unknown",
        };
    }
};

/// Color charge for quarks
pub const Color = enum(u3) {
    red,
    green,
    blue,
    anti_red,
    anti_green,
    anti_blue,

    pub fn toString(c: Color) []const u8 {
        return switch (c) {
            .red => "red",
            .green => "green",
            .blue => "blue",
            .anti_red => "anti_red",
            .anti_green => "anti_green",
            .anti_blue => "anti_blue",
        };
    }

    pub fn isAnti(c: Color) bool {
        return switch (c) {
            .anti_red, .anti_green, .anti_blue => true,
            else => false,
        };
    }
};

/// Stability prediction for theoretical particles
pub const Stability = enum(u2) {
    stable, // Does not decay (e.g., electron, proton)
    metastable, // Long-lived (e.g., neutron)
    unstable, // Short-lived (e.g., muon, tau)
    theoretical, // Not yet observed

    pub fn toString(s: Stability) []const u8 {
        return switch (s) {
            .stable => "stable",
            .metastable => "metastable",
            .unstable => "unstable",
            .theoretical => "theoretical",
        };
    }
};

/// Standard Model particle definition
pub const SMParticle = struct {
    name: []const u8,
    particle_type: ParticleType,
    generation: u3, // 1, 2, 3 (or 0 for gauge bosons/Higgs)
    charge: i3, // -2, -1, 0, +1, +2 (in units of e/3 for quarks)
    mass: f64, // Mass in GeV
    is_quark: bool,
    color: ?Color, // null for leptons and bosons
    spin: f64, // Spin in units of ħ

    /// Create a new SM particle
    pub fn init(
        name: []const u8,
        particle_type: ParticleType,
        generation: u3,
        charge: i3,
        mass: f64,
        is_quark: bool,
        color: ?Color,
        spin: f64,
    ) SMParticle {
        return .{
            .name = name,
            .particle_type = particle_type,
            .generation = generation,
            .charge = charge,
            .mass = mass,
            .is_quark = is_quark,
            .color = color,
            .spin = spin,
        };
    }

    /// Check if this is an antiparticle
    pub fn isAntiparticle(self: SMParticle) bool {
        if (self.color) |c| {
            return c.isAnti();
        }
        // Leptons: negative charge = antiparticle
        if (self.particle_type == .lepton) {
            return self.charge < 0;
        }
        return false;
    }

    /// Format particle info
    pub fn format(self: SMParticle, allocator: std.mem.Allocator) ![]u8 {
        const color_str = if (self.color) |c| Color.toString(c) else "none";
        return std.fmt.allocPrint(allocator, "{s} ({s}, gen={d}, Q={d}, m={d:.4} GeV, spin={d:.1}, color={s})", .{
            self.name,
            ParticleType.toString(self.particle_type),
            self.generation,
            self.charge,
            self.mass,
            self.spin,
            color_str,
        });
    }
};

/// E8 to SM particle assignment result
pub const E8Assignment = struct {
    particle: SMParticle,
    e8_root: E8Root,
    particle_hypervector: Hypervector,
    e8_hypervector: Hypervector,
    similarity_score: f64,
    confidence: f64,
    e8_index: usize,

    /// Create new assignment
    pub fn init(
        particle: SMParticle,
        e8_root: E8Root,
        particle_hv: Hypervector,
        e8_hv: Hypervector,
        similarity: f64,
        confidence: f64,
        e8_index: usize,
    ) E8Assignment {
        return .{
            .particle = particle,
            .e8_root = e8_root,
            .particle_hypervector = particle_hv,
            .e8_hypervector = e8_hv,
            .similarity_score = similarity,
            .confidence = confidence,
            .e8_index = e8_index,
        };
    }

    /// Check if assignment meets similarity threshold
    pub fn isValid(self: E8Assignment) bool {
        return self.similarity_score >= SIMILARITY_THRESHOLD;
    }
};

/// Properties of predicted unknown particles
pub const HyperspaceProperties = struct {
    generation_affinity: f64, // Which generation this resembles (1-3)
    color_charge: ?Color, // Predicted color charge
    spin: f64, // Predicted spin
    stability_prediction: Stability,
    mass_uncertainty: f64, // Uncertainty in mass prediction
    discovery_potential: f64, // 0-1 scale for likelihood of discovery

    pub fn format(self: HyperspaceProperties, allocator: std.mem.Allocator) ![]u8 {
        const color_str = if (self.color_charge) |c| Color.toString(c) else "none";
        return std.fmt.allocPrint(allocator, "gen_aff={d:.2}, color={s}, spin={d:.1}, stab={s}, mass_err={d:.2}, discover={d:.2}", .{
            self.generation_affinity,
            color_str,
            self.spin,
            Stability.toString(self.stability_prediction),
            self.mass_uncertainty,
            self.discovery_potential,
        });
    }
};

/// Unknown (theoretical) particle predicted from unassigned E8 roots
pub const UnknownParticle = struct {
    e8_root: E8Root,
    hypervector: Hypervector,
    e8_index: usize,
    predicted_mass: f64,
    predicted_charge: i3,
    predicted_spin: f64,
    properties: HyperspaceProperties,
    suggested_name: ?[]const u8,

    pub fn format(self: UnknownParticle, allocator: std.mem.Allocator) ![]u8 {
        const name = self.suggested_name orelse "Unknown";
        const props = try self.properties.format(allocator);
        defer allocator.free(props);

        return std.fmt.allocPrint(allocator, "{s}: Q={d}, m={d:.4} GeV, spin={d:.1}, [{s}]", .{
            name,
            self.predicted_charge,
            self.predicted_mass,
            self.predicted_spin,
            props,
        });
    }
};

//==============================================================================
// Standard Model Particle Database
//==============================================================================

/// Get all Standard Model particles
/// Returns array of 61 particles:
/// - 36 quarks (6 flavors × 3 colors × 2 charges)
/// - 12 leptons (6 flavors × 2 charges)
/// - 12 gauge bosons (8 gluons + W+ + W- + Z + photon)
/// - 1 Higgs
pub fn getAllSMParticles(allocator: std.mem.Allocator) ![]SMParticle {
    // Allocate exactly 61 particles
    const particles = try allocator.alloc(SMParticle, SM_NUM_PARTICLES);
    errdefer allocator.free(particles);

    var idx: usize = 0;

    // ===== QUARKS (36 total) =====
    const quark_masses = [_]f64{ 0.002, 1.3, 95, 0.005, 4.2, 173 }; // u,d,c,s,t,b (GeV)
    const quark_names = [_][]const u8{ "up", "down", "charm", "strange", "top", "bottom" };
    const quark_symbols = [_][]const u8{ "u", "d", "c", "s", "t", "b" };

    inline for (quark_names, quark_masses, quark_symbols, 0..) |_, mass, symbol, i| {
        const gen: u3 = @intCast((i / 2) + 1);
        const colors = [_]Color{ .red, .green, .blue };

        // Quarks (charge +2/3 or -1/3)
        const is_up_type = (i % 2) == 0;
        const charge: i3 = if (is_up_type) 2 else -1;

        for (colors) |c| {
            var buf: [64]u8 = undefined;
            const full_name = try std.fmt.bufPrint(&buf, "{s}_{s}", .{ symbol, Color.toString(c) });
            particles[idx] = SMParticle.init(
                full_name,
                .quark,
                gen,
                charge,
                mass,
                true,
                c,
                0.5,
            );
            idx += 1;
        }

        // Antiquarks
        const anti_colors = [_]Color{ .anti_red, .anti_green, .anti_blue };
        for (anti_colors) |c| {
            var buf: [64]u8 = undefined;
            const full_name = try std.fmt.bufPrint(&buf, "{s}_{s}_bar", .{ symbol, Color.toString(c) });
            particles[idx] = SMParticle.init(
                full_name,
                .quark,
                gen,
                -charge,
                mass,
                true,
                c,
                0.5,
            );
            idx += 1;
        }
    }

    // ===== LEPTONS (12 total) =====
    const lepton_masses = [_]f64{ 0.511e-3, 105.7e-6, 1.777, 0.511e-3, 105.7e-6, 1.777 }; // e, μ, τ (GeV)
    const lepton_names = [_][]const u8{ "electron", "muon", "tau", "positron", "antimuon", "antitau" };
    const lepton_symbols = [_][]const u8{ "e-", "mu-", "tau-", "e+", "mu+", "tau+" };

    inline for (lepton_names, lepton_masses, lepton_symbols, 0..) |_, mass, symbol, i| {
        const gen: u3 = @intCast((i % 3) + 1);
        const charge: i3 = if (i < 3) -1 else 1; // First 3 are negative, last 3 positive

        particles[idx] = SMParticle.init(
            symbol,
            .lepton,
            gen,
            charge,
            mass,
            false,
            null,
            0.5,
        );
        idx += 1;
    }

    // Neutrinos (6 total - left-handed only)
    const neutrino_symbols = [_][]const u8{ "nu_e", "nu_mu", "nu_tau", "nu_e_bar", "nu_mu_bar", "nu_tau_bar" };
    const neutrino_masses_upper = [_]f64{ 0.8e-6, 0.19e-3, 18.2e-3, 0.8e-6, 0.19e-3, 18.2e-3 }; // Upper bounds (GeV)

    inline for (neutrino_symbols, neutrino_masses_upper, 0..) |symbol, mass, i| {
        const gen: u3 = @intCast((i % 3) + 1);
        const charge: i3 = 0;

        particles[idx] = SMParticle.init(
            symbol,
            .lepton,
            gen,
            charge,
            mass,
            false,
            null,
            0.5,
        );
        idx += 1;
    }

    // ===== GAUGE BOSONS (12 total) =====

    // 8 Gluons (color-anticolor combinations excluding white)
    const gluon_colors = [8][]const u8{
        "r_g_bar", "r_b_bar", "g_r_bar", "g_b_bar", "b_r_bar", "b_g_bar",
        "r_r_bar_g_g_bar", // (rr̄ - gḡ)/√2
        "r_r_bar_g_g_bar_b_b_bar", // (rr̄ + gḡ - 2bb̄)/√6
    };

    inline for (gluon_colors) |suffix| {
        var buf: [64]u8 = undefined;
        const name = try std.fmt.bufPrint(&buf, "gluon_{s}", .{suffix});
        particles[idx] = SMParticle.init(
            name,
            .gauge_boson,
            0, // No generation for gauge bosons
            0,
            0, // Massless
            false,
            null,
            1.0, // spin-1
        );
        idx += 1;
    }

    // W+ boson
    particles[idx] = SMParticle.init(
        "W+",
        .gauge_boson,
        0,
        1,
        80.379, // GeV
        false,
        null,
        1.0,
    );
    idx += 1;

    // W- boson
    particles[idx] = SMParticle.init(
        "W-",
        .gauge_boson,
        0,
        -1,
        80.379,
        false,
        null,
        1.0,
    );
    idx += 1;

    // Z boson
    particles[idx] = SMParticle.init(
        "Z",
        .gauge_boson,
        0,
        0,
        91.1876,
        false,
        null,
        1.0,
    );
    idx += 1;

    // Photon
    particles[idx] = SMParticle.init(
        "photon",
        .gauge_boson,
        0,
        0,
        0,
        false,
        null,
        1.0,
    );
    idx += 1;

    // ===== HIGGS BOSON (1 total) =====
    particles[idx] = SMParticle.init(
        "H",
        .higgs,
        0,
        0,
        125.1,
        false,
        null,
        0.0, // spin-0
    );
    idx += 1;

    // Verify we have exactly 61 particles
    std.debug.assert(idx == SM_NUM_PARTICLES);

    return particles;
}

//==============================================================================
// Encoding Functions
//==============================================================================

/// Generate a hypervector seed from particle properties
fn particleSeed(
    name: []const u8,
    particle_type: ParticleType,
    generation: u3,
    charge: i3,
) u64 {
    var hash: u64 = 0;
    const prime: u64 = 0x100000001b3; // FNV prime

    // Hash name
    for (name) |c| {
        hash = (hash ^ @as(u64, @intCast(c))) *% prime;
    }

    // Mix in particle type
    hash = hash *% @as(u64, @intFromEnum(particle_type)) +% 0x9e3779b97f4a7c15;

    // Mix in generation (shift for different "orbits")
    hash = hash *% @as(u64, generation) +% 0x517cc1b727220a95;

    // Mix in charge (add offset to handle negative values)
    const charge_i32: i32 = charge; // Promote to i32 to avoid overflow
    const charge_unsigned = @as(u64, @intCast(charge_i32 + 2)); // Map -2..2 to 0..4
    hash = hash *% charge_unsigned +% 0x0bf58476d1ce4e5b9;

    return hash;
}

/// Encode a Standard Model particle as a hypervector
/// Uses holographic encoding of all particle properties
pub fn encodeSMParticle(allocator: std.mem.Allocator, particle: SMParticle) !Hypervector {
    const HYPERVECTOR_DIM = 1024;

    // Generate base hypervector from seed
    const seed = particleSeed(particle.name, particle.particle_type, particle.generation, particle.charge);
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    // Allocate hypervector
    const data = try allocator.alloc(i8, HYPERVECTOR_DIM);
    errdefer allocator.free(data);

    // Generate ternary hypervector {-1, 0, +1}
    var data_mut = @constCast(data);
    for (data_mut, 0..) |*trit, i| {
        const r = random.float(f64);
        trit.* = if (r < 0.33) -1 else if (r < 0.66) 0 else 1;
        _ = i;
    }

    // Encode mass: modify hypervector based on mass
    const mass_params = massToSacredParams(particle.mass);
    // Use mass parameters to permute sections of the hypervector
    const abs_k: i32 = @abs(mass_params.k);
    const abs_m: i32 = @abs(mass_params.m);
    const mass_offset = @as(usize, @intCast(abs_k * 37 + abs_m * 73)) % HYPERVECTOR_DIM;

    // Encode charge: overlay charge pattern
    const charge_hv = try encodeCharge(allocator, particle.charge);
    defer @constCast(&charge_hv).deinit();

    // Blend charge pattern into base hypervector (element-wise majority)
    for (data_mut, charge_hv.data) |*trit, charge_trit| {
        // Simple element-wise blend: if charge is strongly biased, influence the result
        if (charge_trit != 0) {
            const r = random.float(f64);
            // 30% chance to adopt charge value
            if (r < 0.3) {
                trit.* = charge_trit;
            }
        }
    }

    // Encode generation via permutation of a subsection
    const gen_offset = (@as(usize, particle.generation) * 101) % HYPERVECTOR_DIM;
    const chunk_size = HYPERVECTOR_DIM / 4;

    // Apply mass+gen permutation to last quarter
    const start = HYPERVECTOR_DIM - chunk_size;
    for (0..chunk_size) |i| {
        const src_idx = (start + i) % HYPERVECTOR_DIM;
        const dst_idx = (src_idx + mass_offset + gen_offset) % HYPERVECTOR_DIM;
        if (dst_idx >= start and dst_idx < HYPERVECTOR_DIM) {
            const temp = data_mut[src_idx];
            data_mut[src_idx] = data_mut[dst_idx];
            data_mut[dst_idx] = temp;
        }
    }

    return Hypervector{ .data = data, .allocator = allocator };
}

/// Encode E8 root as hypervector
/// Maps 8D E8 root vector to 1024D hypervector
pub fn encodeE8Root(allocator: std.mem.Allocator, root: E8Root) !Hypervector {
    const HYPERVECTOR_DIM = 1024;
    const E8_RANK = 8;

    // Allocate hypervector
    var data = try allocator.alloc(i8, HYPERVECTOR_DIM);
    errdefer allocator.free(data);

    // Use E8 components to seed hypervector generation
    // Each dimension influences ~128 trits
    const chunk_size = HYPERVECTOR_DIM / E8_RANK; // 128

    for (0..E8_RANK) |dim| {
        const component = root.components[dim];

        // Create deterministic seed from component
        const seed_int = @as(i64, @intFromFloat(@abs(component) * 100000));
        const seed = @as(u64, @bitCast(seed_int)) +% @as(u64, dim) *% 0x9e3779b97f4a7c15;

        var rng = std.Random.DefaultPrng.init(seed);
        const random = rng.random();

        // Fill chunk with biased random values based on component sign
        const start = dim * chunk_size;
        const end = start + chunk_size;

        for (start..end) |i| {
            const r = random.float(f64);
            const sign: f64 = if (component >= 0) 1.0 else -1.0;
            const bias = sign * 0.6; // 60% bias toward sign

            data[i] = if (r < 0.33 + bias / 3) @as(i8, 1) else if (r < 0.66) @as(i8, 0) else @as(i8, -1);
        }
    }

    return Hypervector{ .data = data, .allocator = allocator };
}

/// Encode charge {-2, -1, 0, +1, +2} as hypervector
pub fn encodeCharge(allocator: std.mem.Allocator, charge: i3) !Hypervector {
    const HYPERVECTOR_DIM = 1024;

    const data = try allocator.alloc(i8, HYPERVECTOR_DIM);
    errdefer allocator.free(data);
    const data_mut = @constCast(data);

    // Different patterns for different charges
    switch (charge) {
        -2 => {
            // Very negative pattern (not currently used in SM, but for completeness)
            for (data_mut, 0..) |*trit, i| {
                trit.* = if (i % 2 == 0) -1 else 0;
            }
        },
        -1 => {
            // Predominantly -1 pattern
            for (data_mut, 0..) |*trit, i| {
                const r = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(HYPERVECTOR_DIM));
                trit.* = if (r < 0.7) -1 else if (r < 0.85) 0 else 1;
            }
        },
        0 => {
            // Balanced pattern (alternating)
            for (data_mut, 0..) |*trit, i| {
                trit.* = @as(i8, @intCast(i % 3)) - 1; // -1, 0, 1, -1, 0, 1, ...
            }
        },
        1 => {
            // Predominantly +1 pattern
            for (data_mut, 0..) |*trit, i| {
                const r = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(HYPERVECTOR_DIM));
                trit.* = if (r < 0.3) -1 else if (r < 0.45) 0 else 1;
            }
        },
        2 => {
            // Very positive pattern (up-type quarks)
            for (data_mut, 0..) |*trit, i| {
                trit.* = if (i % 2 == 0) 1 else 0;
            }
        },
        else => unreachable,
    }

    return Hypervector{ .data = data, .allocator = allocator };
}

/// Encode generation number via permutation
pub fn encodeGeneration(allocator: std.mem.Allocator, generation: u3) !Hypervector {
    const HYPERVECTOR_DIM = 1024;

    // Create base hypervector
    const data = try allocator.alloc(i8, HYPERVECTOR_DIM);
    errdefer allocator.free(data);
    const data_mut = @constCast(data);

    // Permutation amount based on generation
    const permute_amount = @as(usize, @intCast(generation)) * 137; // Coprime with 1024

    // Create permuted pattern
    for (data_mut, 0..) |*trit, i| {
        const permuted_idx = (i + permute_amount) % HYPERVECTOR_DIM;
        const r = @as(f64, @floatFromInt(permuted_idx)) / @as(f64, @floatFromInt(HYPERVECTOR_DIM));
        trit.* = if (r < 0.33) -1 else if (r < 0.66) 0 else 1;
    }

    return Hypervector{ .data = data, .allocator = allocator };
}

/// Convert particle mass to sacred parameters
/// Uses approximation: ln(m) ≈ k·ln(3) + m·ln(π) + p·ln(φ) + q·ln(e) + ln(n)
pub fn massToSacredParams(mass: f64) SacredParams {
    const ln_mass = std.math.log(f64, std.math.e, mass + 1e-10); // Avoid log(0)
    const ln_3 = std.math.log(f64, std.math.e, 3.0);
    const ln_pi = std.math.log(f64, std.math.e, PI);
    const ln_phi = std.math.log(f64, std.math.e, PHI);
    const ln_e = 1.0; // ln(e) = 1

    // Simple greedy approximation
    var remaining = ln_mass;
    var k: i8 = 0;
    var m: i8 = 0;
    var p: i8 = 0;
    var q: i8 = 0;
    var n: i8 = 1;

    // Find k (coefficient for 3^k)
    while (k < 10 and remaining > ln_3) {
        remaining -= ln_3;
        k += 1;
    }
    while (k > -10 and remaining < -ln_3) {
        remaining += ln_3;
        k -= 1;
    }

    // Find m (coefficient for π^m)
    while (m < 10 and remaining > ln_pi) {
        remaining -= ln_pi;
        m += 1;
    }
    while (m > -10 and remaining < -ln_pi) {
        remaining += ln_pi;
        m -= 1;
    }

    // Find p (coefficient for φ^p)
    while (p < 10 and remaining > ln_phi) {
        remaining -= ln_phi;
        p += 1;
    }
    while (p > -10 and remaining < -ln_phi) {
        remaining += ln_phi;
        p -= 1;
    }

    // Find q (coefficient for e^q)
    while (q < 10 and remaining > ln_e) {
        remaining -= ln_e;
        q += 1;
    }
    while (q > -10 and remaining < -ln_e) {
        remaining += ln_e;
        q -= 1;
    }

    // n gets what's left (rounded)
    n = @intFromFloat(@round(std.math.exp(remaining)));
    if (n < 1) n = 1;

    return SacredParams{
        .n = n,
        .k = k,
        .m = m,
        .p = p,
        .q = q,
    };
}

//==============================================================================
// Similarity and Assignment Functions
//==============================================================================

/// Find the best matching E8 root for a given particle
pub fn findBestE8Match(
    allocator: std.mem.Allocator,
    particle: SMParticle,
    e8_hypervectors: []const Hypervector,
    e8_roots: []const E8Root,
) !E8Assignment {
    if (e8_hypervectors.len != e8_roots.len) {
        return error.MismatchedE8Data;
    }

    // Encode particle
    const particle_hv = try encodeSMParticle(allocator, particle);
    errdefer @constCast(&particle_hv).deinit();

    // Find best match
    var best_idx: usize = 0;
    var best_similarity: f64 = -1.0;

    for (e8_hypervectors, 0..) |e8_hv, i| {
        // Calculate similarity using cosine-like measure
        const similarity = try cosineSimilarity(&particle_hv, &e8_hv);

        if (similarity > best_similarity) {
            best_similarity = similarity;
            best_idx = i;
        }
    }

    // Calculate confidence based on similarity
    const confidence = if (best_similarity > SIMILARITY_THRESHOLD)
        0.5 + 0.5 * ((best_similarity - SIMILARITY_THRESHOLD) / (1.0 - SIMILARITY_THRESHOLD))
    else
        best_similarity;

    // Clone best E8 hypervector for storage
    const e8_hv_copy = try cloneHypervector(allocator, &e8_hypervectors[best_idx]);
    errdefer e8_hv_copy.deinit();

    return E8Assignment.init(
        particle,
        e8_roots[best_idx],
        particle_hv,
        e8_hv_copy,
        best_similarity,
        confidence,
        best_idx,
    );
}

/// Assign all SM particles to E8 roots
pub fn assignAllParticles(
    allocator: std.mem.Allocator,
) ![]E8Assignment {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    // Generate E8 root system
    const e8_system = try E8Root.generate(arena_allocator);
    defer arena_allocator.free(e8_system);

    // Encode all E8 roots as hypervectors
    var e8_hypervectors: [E8_NUM_ROOTS]Hypervector = undefined;
    for (e8_system, 0..) |root, i| {
        e8_hypervectors[i] = try encodeE8Root(arena_allocator, root);
    }

    // Get all SM particles
    const sm_particles = try getAllSMParticles(arena_allocator);
    defer arena_allocator.free(sm_particles);

    // Track assigned E8 indices
    var assigned_indices = std.AutoHashMap(usize, void).init(arena_allocator);

    // Count valid assignments
    var assignment_count: usize = 0;
    for (sm_particles) |particle| {
        const assignment = try findBestE8MatchExcluding(
            arena_allocator,
            particle,
            &e8_hypervectors,
            e8_system,
            &assigned_indices,
        );
        if (assignment.similarity_score >= SIMILARITY_THRESHOLD) {
            assignment_count += 1;
            try assigned_indices.put(assignment.e8_index, {});
        }
    }

    // Clear and rebuild assigned_indices
    assigned_indices.clearAndFree();
    assigned_indices = std.AutoHashMap(usize, void).init(arena_allocator);

    // Allocate result slice
    const assignments = try allocator.alloc(E8Assignment, assignment_count);
    var idx: usize = 0;

    // Assign particles one by one
    for (sm_particles) |particle| {
        const assignment = try findBestE8MatchExcluding(
            arena_allocator,
            particle,
            &e8_hypervectors,
            e8_system,
            &assigned_indices,
        );

        if (assignment.similarity_score >= SIMILARITY_THRESHOLD) {
            // Clone data for persistent storage
            const particle_hv_copy = try cloneHypervector(allocator, &assignment.particle_hypervector);
            const e8_hv_copy = try cloneHypervector(allocator, &assignment.e8_hypervector);

            assignments[idx] = E8Assignment.init(
                assignment.particle,
                assignment.e8_root,
                particle_hv_copy,
                e8_hv_copy,
                assignment.similarity_score,
                assignment.confidence,
                assignment.e8_index,
            );
            idx += 1;

            try assigned_indices.put(assignment.e8_index, {});
        }
    }

    return assignments;
}

/// Find best E8 match excluding already assigned roots
fn findBestE8MatchExcluding(
    allocator: std.mem.Allocator,
    particle: SMParticle,
    e8_hypervectors: []const Hypervector,
    e8_roots: []const E8Root,
    assigned_indices: *const std.AutoHashMap(usize, void),
) !E8Assignment {
    // Encode particle
    const particle_hv = try encodeSMParticle(allocator, particle);
    defer @constCast(&particle_hv).deinit();

    // Find best match (excluding assigned)
    var best_idx: ?usize = null;
    var best_similarity: f64 = -1.0;

    for (e8_hypervectors, 0..) |e8_hv, i| {
        // Skip if already assigned
        if (assigned_indices.contains(i)) continue;

        // Calculate similarity
        const similarity = try cosineSimilarity(&particle_hv, &e8_hv);

        if (similarity > best_similarity) {
            best_similarity = similarity;
            best_idx = i;
        }
    }

    if (best_idx == null) {
        return error.NoAvailableE8Roots;
    }

    const idx = best_idx.?;
    const confidence = if (best_similarity > SIMILARITY_THRESHOLD)
        0.5 + 0.5 * ((best_similarity - SIMILARITY_THRESHOLD) / (1.0 - SIMILARITY_THRESHOLD))
    else
        best_similarity;

    return E8Assignment.init(
        particle,
        e8_roots[idx],
        particle_hv,
        e8_hypervectors[idx],
        best_similarity,
        confidence,
        idx,
    );
}

//==============================================================================
// Prediction Functions
//==============================================================================

/// Generate predictions for unknown particles from unassigned E8 roots
pub fn generatePredictions(
    allocator: std.mem.Allocator,
    assignments: []const E8Assignment,
) ![]UnknownParticle {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    // Generate full E8 system
    const e8_system = try E8Root.generate(arena_allocator);
    defer arena_allocator.free(e8_system);

    // Encode all E8 roots
    var e8_hypervectors: [E8_NUM_ROOTS]Hypervector = undefined;
    for (e8_system, 0..) |root, i| {
        e8_hypervectors[i] = try encodeE8Root(arena_allocator, root);
    }

    // Build set of assigned indices
    var assigned_indices = std.AutoHashMap(usize, void).init(arena_allocator);
    for (assignments) |a| {
        try assigned_indices.put(a.e8_index, {});
    }

    // Count unassigned E8 roots
    var prediction_count: usize = 0;
    for (e8_system, 0..) |_, i| {
        if (!assigned_indices.contains(i)) prediction_count += 1;
    }

    // Allocate result slice
    const predictions = try allocator.alloc(UnknownParticle, prediction_count);
    var idx: usize = 0;

    // Find unassigned E8 roots and generate predictions
    for (e8_system, &e8_hypervectors, 0..) |root, hv, i| {
        if (assigned_indices.contains(i)) continue;

        // Generate prediction for this unassigned root
        const prediction = try predictFromE8Root(allocator, root, hv, i);
        predictions[idx] = prediction;
        idx += 1;
    }

    return predictions;
}

/// Predict particle properties from an unassigned E8 root
fn predictFromE8Root(
    allocator: std.mem.Allocator,
    root: E8Root,
    hv: Hypervector,
    e8_index: usize,
) !UnknownParticle {
    // Use E8 root components to infer properties
    const root_norm = root.normSquared();
    const avg_component = blk: {
        var sum: f64 = 0;
        for (root.components) |c| sum += @abs(c);
        break :blk sum / 8.0;
    };

    // Predict charge based on component sum
    const component_sum = blk: {
        var sum: f64 = 0;
        for (root.components) |c| sum += c;
        break :blk sum;
    };

    const predicted_charge: i3 = if (component_sum > 0.1) 1 else if (component_sum < -0.1) -1 else 0;

    // Predict mass using sacred formula fit
    // Mass ~ exp(norm_squared * phi / 10)
    const predicted_mass = std.math.exp(root_norm * PHI / 20.0);

    // Predict spin (0, 1/2, or 1 based on symmetry)
    const symmetry = avg_component / root_norm;
    const predicted_spin: f64 = if (symmetry < 0.3) 0.0 else if (symmetry < 0.6) 0.5 else 1.0;

    // Predict generation affinity
    const gen_sum = @mod(@as(usize, @intFromFloat(@abs(component_sum) * 100)), 3);
    const generation_affinity: f64 = @as(f64, @floatFromInt(gen_sum)) + 1.0;

    // Predict color charge based on component pattern
    const color_charge: ?Color = if (predicted_spin == 0.5)
        predictColorFromRoot(root)
    else
        null;

    // Predict stability
    const stability_prediction: Stability = if (predicted_mass < 1.0)
        .stable
    else if (predicted_mass < 10.0)
        .metastable
    else if (predicted_mass < 100.0)
        .unstable
    else
        .theoretical;

    // Calculate discovery potential (0-1 scale)
    const discovery_potential = if (predicted_mass < 200.0 and predicted_charge != 0)
        @max(0.1, 1.0 - predicted_mass / 500.0)
    else
        0.05;

    // Mass uncertainty (increases with mass)
    const mass_uncertainty = predicted_mass * 0.2; // 20% uncertainty

    // Suggest name
    const suggested_name = try suggestParticleName(allocator, predicted_charge, predicted_spin, predicted_mass);

    const properties = HyperspaceProperties{
        .generation_affinity = generation_affinity,
        .color_charge = color_charge,
        .spin = predicted_spin,
        .stability_prediction = stability_prediction,
        .mass_uncertainty = mass_uncertainty,
        .discovery_potential = discovery_potential,
    };

    // Clone hypervector for storage
    const hv_copy = try cloneHypervector(allocator, &hv);

    return UnknownParticle{
        .e8_root = root,
        .hypervector = hv_copy,
        .e8_index = e8_index,
        .predicted_mass = predicted_mass,
        .predicted_charge = predicted_charge,
        .predicted_spin = predicted_spin,
        .properties = properties,
        .suggested_name = suggested_name,
    };
}

/// Predict color charge from E8 root component pattern
fn predictColorFromRoot(root: E8Root) ?Color {
    // Use first few components to determine color
    const c0 = root.components[0];
    const c1 = root.components[1];

    if (c0 > 0 and c1 > 0) return .red;
    if (c0 > 0 and c1 < 0) return .green;
    if (c0 < 0 and c1 > 0) return .blue;
    if (c0 < 0 and c1 < 0) return .anti_red;
    if (@abs(c0) > @abs(c1)) return .anti_green;
    return .anti_blue;
}

/// Suggest a name for a predicted particle
fn suggestParticleName(allocator: std.mem.Allocator, charge: i3, spin: f64, mass: f64) !?[]u8 {
    const charge_str = if (charge > 0) "+" else if (charge < 0) "-" else "0";

    const spin_str = if (spin < 0.25) "S" // Scalar
        else if (spin < 0.75) "F" // Fermion
        else "V"; // Vector

    const mass_prefix = if (mass < 1) "X" else if (mass < 10) "Y" else if (mass < 100) "Z" else "W";

    const name = try std.fmt.allocPrint(allocator, "{s}-{s}{s}", .{ mass_prefix, spin_str, charge_str });
    return name;
}

//==============================================================================
// Utility Functions
//==============================================================================

/// Calculate cosine similarity between two hypervectors
fn cosineSimilarity(hv1: *const Hypervector, hv2: *const Hypervector) !f64 {
    if (hv1.data.len != hv2.data.len) {
        return error.DimensionMismatch;
    }

    var dot_product: f64 = 0;
    var norm1_sq: f64 = 0;
    var norm2_sq: f64 = 0;

    for (hv1.data, hv2.data) |t1, t2| {
        const v1: f64 = @floatFromInt(t1);
        const v2: f64 = @floatFromInt(t2);
        dot_product += v1 * v2;
        norm1_sq += v1 * v1;
        norm2_sq += v2 * v2;
    }

    const norm1 = std.math.sqrt(norm1_sq);
    const norm2 = std.math.sqrt(norm2_sq);

    if (norm1 < 1e-10 or norm2 < 1e-10) {
        return 0.0;
    }

    return dot_product / (norm1 * norm2);
}

/// Clone a hypervector for persistent storage
fn cloneHypervector(allocator: std.mem.Allocator, hv: *const Hypervector) !Hypervector {
    const data_copy = try allocator.alloc(i8, hv.data.len);
    @memcpy(data_copy, hv.data);

    return Hypervector{
        .data = data_copy,
        .allocator = allocator,
    };
}

//==============================================================================
// Tests
//==============================================================================

test "E8 Particle Assignment — encodeSMParticle" {
    const testing = std.testing;

    const electron = SMParticle.init(
        "electron",
        .lepton,
        1,
        -1,
        0.511e-3,
        false,
        null,
        0.5,
    );

    const hv = try encodeSMParticle(testing.allocator, electron);
    defer @constCast(&hv).deinit();

    try testing.expectEqual(@as(usize, 1024), hv.data.len);

    // Verify it's a valid ternary vector
    for (hv.data) |trit| {
        try testing.expect(trit == -1 or trit == 0 or trit == 1);
    }
}

test "E8 Particle Assignment — encodeCharge" {
    const testing = std.testing;

    // Test negative charge
    const hv_neg = try encodeCharge(testing.allocator, -1);
    defer @constCast(&hv_neg).deinit();
    try testing.expectEqual(@as(usize, 1024), hv_neg.data.len);

    // Test zero charge
    const hv_zero = try encodeCharge(testing.allocator, 0);
    defer @constCast(&hv_zero).deinit();
    try testing.expectEqual(@as(usize, 1024), hv_zero.data.len);

    // Test positive charge
    const hv_pos = try encodeCharge(testing.allocator, 1);
    defer @constCast(&hv_pos).deinit();
    try testing.expectEqual(@as(usize, 1024), hv_pos.data.len);
}

test "E8 Particle Assignment — encodeE8Root" {
    const testing = std.testing;

    // Create a simple E8 root
    const root = E8Root.init([_]f64{ 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 });

    const hv = try encodeE8Root(testing.allocator, root);
    defer @constCast(&hv).deinit();

    try testing.expectEqual(@as(usize, 1024), hv.data.len);

    // Verify it's a valid ternary vector
    for (hv.data) |trit| {
        try testing.expect(trit == -1 or trit == 0 or trit == 1);
    }
}

test "E8 Particle Assignment — massToSacredParams" {
    const testing = std.testing;

    // Electron mass
    const params_e = massToSacredParams(0.511e-3);
    // Should produce some result (not necessarily exact)
    try testing.expect(params_e.n > 0);

    // Higgs mass
    const params_h = massToSacredParams(125.1);
    try testing.expect(params_h.n > 0);

    // Different masses should give different parameters
    const same = params_e.n == params_h.n and
        params_e.k == params_h.k and
        params_e.m == params_h.m;
    try testing.expect(!same);
}

test "E8 Particle Assignment — getAllSMParticles" {
    const testing = std.testing;

    const particles = try getAllSMParticles(testing.allocator);
    defer testing.allocator.free(particles);

    try testing.expectEqual(@as(usize, 61), particles.len);
}

test "E8 Particle Assignment — findBestE8Match" {
    const testing = std.testing;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    // Generate E8 roots
    const e8_system = try E8Root.generate(arena_allocator);
    defer arena_allocator.free(e8_system);

    // Encode E8 roots
    var e8_hvs: [E8_NUM_ROOTS]Hypervector = undefined;
    for (e8_system, 0..) |root, i| {
        e8_hvs[i] = try encodeE8Root(arena_allocator, root);
    }

    // Test with electron
    const electron = SMParticle.init(
        "electron",
        .lepton,
        1,
        -1,
        0.511e-3,
        false,
        null,
        0.5,
    );

    const assignment = try findBestE8Match(
        testing.allocator,
        electron,
        &e8_hvs,
        e8_system,
    );
    defer @constCast(&assignment.particle_hypervector).deinit();
    defer @constCast(&assignment.e8_hypervector).deinit();

    try testing.expect(assignment.e8_index < e8_system.len);
    try testing.expect(assignment.similarity_score >= -1.0);
    try testing.expect(assignment.similarity_score <= 1.0);
}

test "E8 Particle Assignment — assignAllParticles" {
    const testing = std.testing;

    const assignments = try assignAllParticles(testing.allocator);
    defer {
        for (assignments) |a| {
            @constCast(&a.particle_hypervector).deinit();
            @constCast(&a.e8_hypervector).deinit();
        }
        testing.allocator.free(assignments);
    }

    // Should assign at least some particles
    try testing.expect(assignments.len > 0);

    // Verify all assignments have valid indices
    for (assignments) |a| {
        try testing.expect(a.e8_index < E8_NUM_ROOTS);
    }
}

test "E8 Particle Assignment — noDuplicateE8Indices" {
    const testing = std.testing;

    const assignments = try assignAllParticles(testing.allocator);
    defer {
        for (assignments) |a| {
            @constCast(&a.particle_hypervector).deinit();
            @constCast(&a.e8_hypervector).deinit();
        }
        testing.allocator.free(assignments);
    }

    // Check for duplicates
    var seen = std.AutoHashMap(usize, void).init(testing.allocator);
    defer seen.deinit();

    for (assignments) |a| {
        try testing.expect(!seen.contains(a.e8_index));
        try seen.put(a.e8_index, {});
    }
}

test "E8 Particle Assignment — generatePredictions" {
    const testing = std.testing;

    // First get some assignments
    const assignments = try assignAllParticles(testing.allocator);
    defer {
        for (assignments) |a| {
            @constCast(&a.particle_hypervector).deinit();
            @constCast(&a.e8_hypervector).deinit();
        }
        testing.allocator.free(assignments);
    }

    // Generate predictions for remaining E8 roots
    const predictions = try generatePredictions(testing.allocator, assignments);
    defer {
        for (predictions) |p| {
            @constCast(&p.hypervector).deinit();
            if (p.suggested_name) |name| {
                testing.allocator.free(name);
            }
        }
        testing.allocator.free(predictions);
    }

    // Should have predictions for remaining E8 roots
    try testing.expect(predictions.len > 0);

    // Verify prediction properties
    for (predictions) |p| {
        try testing.expect(p.predicted_mass >= 0);
        try testing.expect(p.e8_index < E8_NUM_ROOTS);
    }
}

test "E8 Particle Assignment — cosineSimilarity" {
    const testing = std.testing;

    // Create two test hypervectors
    const data1 = try testing.allocator.alloc(i8, 1024);
    defer testing.allocator.free(data1);
    @memset(@constCast(data1), 1);

    const data2 = try testing.allocator.alloc(i8, 1024);
    defer testing.allocator.free(data2);
    @memset(@constCast(data2), 1);

    const hv1 = Hypervector{ .data = data1, .allocator = testing.allocator };
    const hv2 = Hypervector{ .data = data2, .allocator = testing.allocator };

    const sim = try cosineSimilarity(&hv1, &hv2);
    try testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.01);
}
