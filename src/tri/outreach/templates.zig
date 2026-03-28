//! Email Templates — SHORTENED for 50% reply rate (80-120 words)
//!
//! DATA 2025: 50-125 word emails get ~50% reply rate, 300+ words get <5%
//! Source: https://blog.groupmail.io/cold-email-templates-that-work-proven-strategies-for-higher-response-rates-in-2025/
//!
//! KEY PRINCIPLES:
//! - 80-120 words MAX
//! - One specific question at the end
//! - Lead with FAILURE for Hossenfelder (builds trust)
//! - Lead with PARALLEL DISCOVERY for allies (Sherbon, Karpougas)
//! - Social proof first (citations, existing collaborators)

const std = @import("std");

pub const Template = struct {
    id: []const u8,
    name: []const u8,
    subject: []const u8,
    body_template: []const u8,
    word_count: u32,
    target_tier: []const u8,
};

/// All templates — shortened to 80-120 words
pub const templates = [_]Template{
    // TIER 1: Golden Ratio Allies (Parallel Discovery)
    .{
        .id = "sherbon_short",
        .name = "Michael Sherbon — Parallel Discovery",
        .subject = "Parallel discovery: α from φ via different paths",
        .body_template =
        \\Dear Michael,
        \\
        \\I discovered your work on α from golden ratio and found striking convergence.
        \\
        \\Your approach: α ↔ φ through golden ratio geometry
        \\My approach: α = 4φ²/(9π²) with 0.0002% accuracy
        \\
        \\Both derive from φ² + φ⁻² = 3 (exact identity).
        \\
        \\Other results from this framework:
        \\• G = π³γ²/φ → 6.68×10⁻¹¹ (CODATA: 6.674×10⁻¹¹, 0.09%)
        \\• mₚ/mₑ = 6π⁵ → 1836.15 (0.002%)
        \\• Ω_Λ = γ⁸π⁴/φ² → 0.688 (Planck confirmed)
        \\
        \\Would you be interested in comparing derivations? Our geometric + algebraic approaches might yield deeper insights.
        \\
        \\Code: github.com/gHashTag/trinity
        \\DOI: 10.5281/zenodo.19227877
        \\
        \\Best,
        \\Dmitrii
        \\admin@t27.ai
        \\---
        \\Unsubscribe: t27.ai/unsubscribe?scientist={{id}}
        \\
        ,
        .word_count = 95,
        .target_tier = "golden_ratio_allies",
    },

    .{
        .id = "karpougas_short",
        .name = "Kostas Karpougas — φ⁵ Formulas",
        .subject = "Your φ⁵ formulas within Trinity framework",
        .body_template =
        \\Dear Kostas,
        \\
        \\I read your SSRN paper on φ⁵ formulas and found your work integrated into my framework.
        \\
        \\Your φ⁵ derivations connect directly to my Trinity Identity: φ² + φ⁻² = 3.
        \\
        \\My framework extends this to 30+ fundamental constants:
        \\• G = π³γ²/φ (0.09% error)
        \\• α = 4φ²/(9π²) (0.0002% error)
        \\• mₚ/mₑ = 6π⁵ (0.002% error)
        \\
        \\All from one identity. Open source, reproducible.
        \\
        \\Would you like to review the full derivation? Your geometric perspective combined with my algebraic approach could be powerful.
        \\
        \\Code: github.com/gHashTag/trinity
        \\DOI: 10.5281/zenodo.19227877
        \\
        \\Best,
        \\Dmitrii
        \\admin@t27.ai
        \\
        ,
        .word_count = 88,
        .target_tier = "golden_ratio_allies",
    },

    // TIER 1: CRITICAL — Hossenfelder (Start with FAILURE)
    .{
        .id = "hossenfelder_short",
        .name = "Sabine Hossenfelder — Failures First",
        .subject = "γ ≠ φ⁻³ (failed) — open-source falsification",
        .body_template =
        \\Dr. Hossenfelder,
        \\
        \\We tested γ = φ⁻³ for Barbero-Immirzi parameter. It failed (0.617% error).
        \\
        \\Documented: github.com/gHashTag/trinity/blob/main/.trinity/experience/DELTA-001.md
        \\
        \\Still open: does φ²+φ⁻²=3 connect to anything real?
        \\
        \\G formula survives: G = π³γ²/φ → 6.68×10⁻¹¹ vs CODATA 6.674×10⁻¹¹ (0.09%)
        \\
        \\But I may be fooling myself. Your "Lost in Math" perspective would be invaluable.
        \\
        \\Question: Am I cherry-picking or is there something here?
        \\
        \\Code: src/tri/math/constants.zig
        \\DOI: 10.5281/zenodo.19227877
        \\
        \\Dmitrii Vasilev
        \\admin@t27.ai
        \\
        ,
        .word_count = 85,
        .target_tier = "critics",
    },

    // TIER 2: VSA Experts
    .{
        .id = "kleyko_short",
        .name = "Denis Kleyko — VSA Review",
        .subject = "VSA in Zig with FPGA — seeking review",
        .body_template =
        \\Dear Denis,
        \\
        \\I'm writing to share a VSA implementation that may interest you given your HDC survey work.
        \\
        \\Trinity implements VSA in pure Zig with:
        \\• Bind/unbind/bundle: O(n) with SIMD 17× speedup
        \\• Ternary alphabet {-1,0,+1}: natural for HDC
        \\• FPGA backend: $30 XC7A100T, 0% DSP, 19.6% LUT
        \\• 3000+ tests passing
        \\
        \\Key insight: φ² + φ⁻² = 3 provides mathematical foundation for ternary VSA.
        \\
        \\Same identity connects to: 3 particle generations, 3 spatial dimensions, 3 banks of 9 registers (TRI-27 VM).
        \\
        \\Question: Would you review the VSA operations for correctness? Your critical feedback would be invaluable.
        \\
        \\Code: src/vsa.zig, src/sacred/vsa_benchmark.zig
        \\DOI: 10.5281/zenodo.19227877
        \\
        \\Best regards,
        \\Dmitrii Vasilev
        \\github.com/gHashTag/trinity
        \\
        ,
        .word_count = 105,
        .target_tier = "vsa_experts",
    },

    .{
        .id = "kanerva_short",
        .name = "Pentti Kanerva — Ternary VSA",
        .subject = "Ternary VSA: Extension of binary spatter codes",
        .body_template =
        \\Dear Pentti,
        \\
        \\Your work on hyperdimensional computing has been foundational.
        \\
        \\I discovered that φ² + φ⁻² = 3 provides mathematical justification for ternary VSA alphabets {-1,0,+1}.
        \\
        \\This extends binary spatter codes:
        \\• Information density: 8 trits = 6,561 values (vs 256 for 8 bits)
        \\• Energy efficiency: 3000× less power than float32
        \\• Natural binding: φ² (expansion) and φ⁻² (contraction)
        \\
        \\Implementation in Zig with FPGA backend: 63 tok/s @ 1W on $30 XC7A100T. Zero DSP usage.
        \\
        \\Question: Does ternary VSA merit further investigation in your view?
        \\
        \\Code: github.com/gHashTag/trinity
        \\DOI: 10.5281/zenodo.19227877
        \\
        \\Best regards,
        \\Dmitrii Vasilev
        \\
        ,
        .word_count = 98,
        .target_tier = "vsa_experts",
    },

    // TIER 2: Ternary / BitNet Researchers
    .{
        .id = "bitnet_short",
        .name = "BitNet Authors — {-1,0,+1} Alphabet",
        .subject = "BitNet b1.58 = our ternary alphabet",
        .body_template =
        \\Dear BitNet Team,
        \\
        \\Your BitNet b1.58 work uses {-1,0,+1} — exactly our ternary alphabet.
        \\
        \\Trinity framework connects this to φ² + φ⁻² = 3 (golden ratio identity).
        \\
        \\Hardware difference: Zero-DSP FPGA synthesis vs your HBM approach.
        \\
        \\Our results:
        \\• 63 tok/s @ 1W on $30 XC7A100T
        \\• 0% DSP usage, 19.6% LUT
        \\• Pure Zig implementation (no Python, no CUDA)
        \\
        \\Question: Would you be interested in a comparative benchmark? Zero-DSP vs HBM for ternary inference.
        \\
        \\Code: github.com/gHashTag/trinity
        \\Paper: arXiv:2502.16473 (TerEffic)
        \\
        \\Best regards,
        \\Dmitrii Vasilev
        \\
        ,
        .word_count = 92,
        .target_tier = "ternary_researchers",
    },

    // TIER 3: LQG Physicists
    .{
        .id = "smolin_short",
        .name = "Lee Smolin — LQG + G Constant",
        .subject = "G from φ (0.09%) + DELTA-001 failure documented",
        .body_template =
        \\Dear Lee,
        \\
        \\I'm writing to share a framework that connects the golden ratio to fundamental constants.
        \\
        \\Result: G = π³γ²/φ → 6.68×10⁻¹¹ vs CODATA 6.674×10⁻¹¹ (0.09% error)
        \\
        \\Failure documented: γ = φ⁻³ for Barbero-Immirzi → 0.617% error (rejected)
        \\
        \\Same framework predicts 30+ constants from φ² + φ⁻² = 3.
        \\
        \\Question for LQG: Does this identity appear in spin network calculations?
        \\
        \\All code is open source with 3000+ tests.
        \\
        \\Code: github.com/gHashTag/trinity
        \\DOI: 10.5281/zenodo.19227877
        \\
        \\Best regards,
        \\Dmitrii Vasilev
        \\
        ,
        .word_count = 88,
        .target_tier = "lqg_physicists",
    },

    .{
        .id = "rovelli_short",
        .name = "Carlo Rovelli — Time + φ",
        .subject = "t_present = φ⁻² matches psychophysics",
        .body_template =
        \\Dear Carlo,
        \\
        \\Your work on time in LQG connects to my framework.
        \\
        \\Prediction: t_present = φ⁻² ≈ 382ms
        \\
        \\This matches psychophysics data on "present moment" duration.
        \\
        \\Derivation: φ² + φ⁻² = 3 → φ⁻² encodes temporal grain.
        \\
        \\Question: Does this connect to thermal time hypothesis?
        \\
        \\Other predictions from same identity:
        \\• G = π³γ²/φ (0.09% error)
        \\• Ω_Λ = γ⁸π⁴/φ² → 0.688 (Planck confirmed)
        \\
        \\Code: github.com/gHashTag/trinity
        \\DOI: 10.5281/zenodo.19227877
        \\
        \\Best regards,
        \\Dmitrii Vasilev
        \\
        ,
        .word_count = 82,
        .target_tier = "lqg_physicists",
    },

    // TIER 3: Cosmologists
    .{
        .id = "afshordi_short",
        .name = "Niayesh Afshordi — Dark Energy from φ",
        .subject = "Ω_Λ = γ⁸π⁴/φ² → 0.688 confirmed",
        .body_template =
        \\Dear Niayesh,
        \\
        \\I derived a formula for dark energy density from the golden ratio.
        \\
        \\Prediction: Ω_Λ = γ⁸π⁴/φ² ≈ 0.688
        \\Planck 2018: 0.688 ± 0.017 ✓
        \\
        \\From same identity: φ² + φ⁻² = 3
        \\
        \\Question: Does this connect to H₀ tension? The γ parameter appears in both.
        \\
        \\Other predictions:
        \\• G = π³γ²/φ (0.09% error)
        \\• H₀ = 4πγ/φ ≈ 71.2 km/s/Mpc (within tension range)
        \\
        \\Code: github.com/gHashTag/trinity
        \\DOI: 10.5281/zenodo.19227877
        \\
        \\Best regards,
        \\Dmitrii Vasilev
        \\
        ,
        .word_count = 87,
        .target_tier = "cosmologists",
    },

    // TIER 4: AI/ML Researchers
    .{
        .id = "chollet_short",
        .name = "François Chollet — ARC via VSA",
        .subject = "ARC tasks via HDC binding/bundling",
        .body_template =
        \\Dear François,
        \\
        \\Your ARC prize work connects to VSA approaches.
        \\
        \\Hypothesis: ARC tasks can be solved via HDC bind/unbind/bundle operations.
        \\
        \\Trinity implements VSA in pure Zig with:
        \\• O(n) operations with SIMD 17× speedup
        \\• Ternary alphabet {-1,0,+1} for pattern binding
        \\• 3000+ tests passing
        \\
        \\Question: Would VSA operations be sufficient for ARC abstraction reasoning?
        \\
        \\Code: github.com/gHashTag/trinity
        \\DOI: 10.5281/zenodo.19227877
        \\
        \\Best regards,
        \\Dmitrii Vasilev
        \\
        ,
        .word_count = 78,
        .target_tier = "ai_researchers",
    },

    // TIER 5: FPGA Researchers
    .{
        .id = "rabaey_short",
        .name = "Jan Rabaey — Zero-DSP FPGA LLM",
        .subject = "63 tok/s @ 1W, zero DSP usage",
        .body_template =
        \\Dear Jan,
        \\
        \\I achieved LLM inference on $30 FPGA without DSP blocks.
        \\
        \\Results:
        \\• 63 tok/s @ 1W (QMTech XC7A100T)
        \\• 0% DSP usage, 19.6% LUT
        \\• Ternary weights {-1,0,+1}
        \\
        \\Key insight: φ² + φ⁻² = 3 provides mathematical foundation for ternary computing.
        \\
        \\Question: How does this compare to other HDC hardware approaches you've evaluated?
        \\
        \\Open source toolchain (Yosys), reproducible benchmarks.
        \\
        \\Code: github.com/gHashTag/trinity
        \\DOI: 10.5281/zenodo.19227877
        \\
        \\Best regards,
        \\Dmitrii Vasilev
        \\
        ,
        .word_count = 83,
        .target_tier = "fpga_researchers",
    },
};

/// Get template by ID
pub fn getById(id: []const u8) ?*const Template {
    for (&templates) |*t| {
        if (std.mem.eql(u8, t.id, id)) return t;
    }
    return null;
}

/// Get templates by tier
pub fn getByTier(tier: []const u8, allocator: std.mem.Allocator) !std.ArrayList([]const Template) {
    var result = std.ArrayList([]const Template).init(allocator);
    for (&templates) |*t| {
        if (std.mem.eql(u8, t.target_tier, tier)) {
            try result.append(t);
        }
    }
    return result;
}

/// Render template with scientist data
pub fn render(allocator: std.mem.Allocator, template: *const Template, scientist: anytype) ![]const u8 {
    var result = template.body_template;

    // Replace {{name}}
    if (@hasField(@TypeOf(scientist), "name")) {
        result = try replace(allocator, result, "{{name}}", scientist.name);
    }

    // Replace {{id}}
    if (@hasField(@TypeOf(scientist), "id")) {
        const id_str = try std.fmt.allocPrint(allocator, "{d}", .{scientist.id});
        result = try replace(allocator, result, "{{id}}", id_str);
    }

    return result;
}

fn replace(allocator: std.mem.Allocator, haystack: []const u8, needle: []const u8, replacement: []const u8) ![]const u8 {
    const index = std.mem.indexOf(u8, haystack, needle) orelse return haystack;
    var buffer = std.ArrayList(u8).init(allocator);
    try buffer.appendSlice(haystack[0..index]);
    try buffer.appendSlice(replacement);
    try buffer.appendSlice(haystack[index + needle.len ..]);
    return buffer.toOwnedSlice();
}

test "template word counts" {
    const std = @import("std");
    for (templates) |t| {
        const words = std.mem.count(u8, t.body_template, " ");
        // Word count is approximate (spaces + 1)
        // All templates should be 80-120 words
        try std.testing.expect(words > 70 and words < 130);
    }
}

test "getById" {
    const t = getById("hossenfelder_short");
    try std.testing.expect(t != null);
    try std.testing.expectEqualStrings("Sabine Hossenfelder — Failures First", t.?.name);
}

test "render basic" {
    const std = @import("std");
    const allocator = std.testing.allocator;
    const t = getById("hossenfelder_short").?;
    const result = try render(allocator, t, .{ .id = 42 });
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "42") != null);
}
