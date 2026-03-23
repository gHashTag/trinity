// @origin(spec:patent.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// tri patent — IP protection commands
// ═══════════════════════════════════════════════════════════════════════════════
//
// tri patent status     — show DOIs + filing status
// tri patent analysis   — full patent portfolio analysis (7 inventions)
// tri patent claims     — show USPTO-format claims per invention
// tri patent strategy   — filing timeline and budget
// tri patent snapshot   — git tag + CHANGELOG + zenodo DOI
// tri patent draft      — generate provisional template
// tri patent zenodo     — trigger DOI via release tag
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const RED = colors.RED;
const CYAN = colors.CYAN;
const GRAY = colors.GRAY;
const RESET = colors.RESET;
const YELLOW = "\x1b[33m";
const WHITE = "\x1b[97m";
const BOLD = "\x1b[1m";

const print = std.debug.print;

const STATUS_PATH = ".trinity/patent/status.json";

pub fn runPatentCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    const sub = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, sub, "status")) {
        showStatus();
    } else if (std.mem.eql(u8, sub, "analysis")) {
        showAnalysis();
    } else if (std.mem.eql(u8, sub, "claims")) {
        const name = if (args.len > 1) args[1] else "all";
        showClaims(name);
    } else if (std.mem.eql(u8, sub, "strategy")) {
        showStrategy();
    } else if (std.mem.eql(u8, sub, "snapshot")) {
        const name = if (args.len > 2 and std.mem.eql(u8, args[1], "--discovery"))
            args[2]
        else
            "all";
        showSnapshot(name);
    } else if (std.mem.eql(u8, sub, "draft")) {
        const name = if (args.len > 2 and std.mem.eql(u8, args[1], "--discovery"))
            args[2]
        else
            "ternary-resonance-law";
        showDraft(name);
    } else if (std.mem.eql(u8, sub, "zenodo")) {
        showZenodo();
    } else {
        printHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS — DOIs + filing overview
// ═══════════════════════════════════════════════════════════════════════════════

fn showStatus() void {
    print("\n{s}{s}PATENT & IP PROTECTION STATUS{s}\n", .{ BOLD, GOLDEN, RESET });
    print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    // Zenodo records
    print("  {s}ZENODO PRIOR ART{s}\n", .{ GOLDEN, RESET });
    print("  {s}────────────────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });
    print("  {s}18939352{s}  10.5281/zenodo.18939352  v2.0.1  FPGA Autoregressive LLM\n", .{ CYAN, RESET });
    print("  {s}18947017{s}  10.5281/zenodo.18947017  concept All versions (concept DOI)\n", .{ CYAN, RESET });
    print("  {s}18950696{s}  10.5281/zenodo.18950696  v2.0.3  Latest version\n", .{ CYAN, RESET });
    print("  {s}Date{s}: 2026-03-10 | {s}Author{s}: Vasilev Dmitrii | {s}License{s}: MIT\n\n", .{ GOLDEN, RESET, GOLDEN, RESET, GOLDEN, RESET });

    // Patent portfolio
    print("  {s}PATENT PORTFOLIO (7 inventions){s}\n", .{ GOLDEN, RESET });
    print("  {s}────────────────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });

    const Entry = struct { name: []const u8, strength: []const u8, icon: []const u8, priority: []const u8 };
    const patents = [_]Entry{
        .{ .name = "Ternary Resonance Law (3^k dims)", .strength = "HIGH", .icon = "P1", .priority = "#1" },
        .{ .name = "Square Attention (ctx=head_dim)", .strength = "HIGH", .icon = "P1", .priority = "#1" },
        .{ .name = "Zero-DSP FPGA Inference", .strength = "HIGH", .icon = "P2", .priority = "#2" },
        .{ .name = "Self-Evolving Ouroboros", .strength = "MED+", .icon = "P3", .priority = "#3" },
        .{ .name = "VSA Balanced Ternary + SIMD", .strength = "MED", .icon = "P4", .priority = "#4" },
        .{ .name = "phi-RoPE Positional Encoding", .strength = "MED", .icon = "P5", .priority = "#5" },
        .{ .name = "Sparse Ternary MatMul (9.2x)", .strength = "MED", .icon = "P6", .priority = "#6" },
    };

    for (patents) |p| {
        const clr: []const u8 = if (std.mem.eql(u8, p.strength, "HIGH")) GREEN else YELLOW;
        print("  {s}{s:<4}{s} {s}{s:<36}{s} {s}{s:<5}{s} Priority {s}\n", .{
            CYAN,       p.icon,     RESET,
            WHITE,      p.name,     RESET,
            clr,        p.strength, RESET,
            p.priority,
        });
    }

    print("\n  {s}Next{s}: tri patent analysis | tri patent claims | tri patent strategy\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANALYSIS — Full patent portfolio technical analysis
// ═══════════════════════════════════════════════════════════════════════════════

fn showAnalysis() void {
    print("\n{s}{s}PATENT PORTFOLIO ANALYSIS{s}\n", .{ BOLD, GOLDEN, RESET });
    print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    // P1: Ternary Resonance
    print("  {s}P1: TERNARY RESONANCE LAW (3^k DIMENSIONS){s}\n", .{ GREEN, RESET });
    print("  {s}────────────────────────────────────────────{s}\n", .{ GRAY, RESET });
    print("  All dimensions MUST be powers of 3. Violation = 2x PPL degradation.\n\n", .{});
    print("  {s}Evidence:{s}\n", .{ GOLDEN, RESET });
    print("    ctx=18 (2x3^2) -> PPL 5.50  OFF resonance\n", .{});
    print("    ctx=27 (3^3)   -> PPL 2.96  ON resonance\n", .{});
    print("    ctx=54 (2x3^3) -> PPL 6.05  OFF resonance (WORSE with 2x context!)\n\n", .{});
    print("  {s}Non-obvious{s}: Contradicts Kaplan/Chinchilla scaling laws\n", .{ CYAN, RESET });
    print("  {s}Files{s}: src/hslm/constants.zig, docs/lab/papers/hslm/training-review-mar10-14.md\n\n", .{ GRAY, RESET });

    // P1b: Square Attention
    print("  {s}P1b: SQUARE ATTENTION THEOREM (ctx = head_dim){s}\n", .{ GREEN, RESET });
    print("  {s}──────────────────────────────────────────────{s}\n", .{ GRAY, RESET });
    print("  ctx = head_dim -> Q*K^T is square -> full rank -> max info capacity\n", .{});
    print("  ctx > head_dim -> rank-deficient -> positions collapse\n\n", .{});
    print("  Sacred scale: 1/(d^(phi^-3)) = 0.354 (vs Vaswani 0.111, 3.2x larger)\n", .{});
    print("  {s}Files{s}: src/hslm/sacred_attention.zig\n\n", .{ GRAY, RESET });

    // P2: Zero-DSP FPGA
    print("  {s}P2: ZERO-DSP FPGA TERNARY INFERENCE{s}\n", .{ GREEN, RESET });
    print("  {s}─────────────────────────────────────{s}\n", .{ GRAY, RESET });
    print("  Complete transformer on FPGA. Zero DSP48 blocks. LUT + BRAM only.\n\n", .{});
    print("  {s}Resources (Artix-7 XC7A100T, $30):{s}\n", .{ GOLDEN, RESET });
    print("    DSP48: 0/240 (0%%)   BRAM36-eq: 135/135 (100%%)\n", .{});
    print("    LUT: 4,267/63,400 (6.7%%)   FF: 2,449/126,800 (1.9%%)\n\n", .{});
    print("  {s}vs TerEffic (2025){s}: 0 DSP vs 3,041 DSP | $30 vs $5,000 | Yosys vs Vivado\n", .{ CYAN, RESET });
    print("  {s}Zenodo{s}: 63 tok/s @ 92 MHz, ~1W, 16 tokens autoregressive (seed=42)\n", .{ CYAN, RESET });
    print("  {s}Files{s}: fpga/openxc7-synth/hslm_ternary_mac.v, docs/lab/papers/trinity-fpga/draft.md\n\n", .{ GRAY, RESET });

    // P3: Ouroboros
    print("  {s}P3: SELF-EVOLVING OUROBOROS SYSTEM{s}\n", .{ YELLOW, RESET });
    print("  {s}──────────────────────────────────{s}\n", .{ GRAY, RESET });
    print("  6-phase: DIAGNOSE -> PLAN -> ACT -> VERIFY -> MEASURE -> PERSIST\n", .{});
    print("  12-dim toxic verdict (BUILD/TEST 50%%, QUALITY 30%%, EFFICIENCY 20%%)\n", .{});
    print("  Strategy rotation on stagnation (priority -> weakest -> random)\n", .{});
    print("  Self-referential Link #22: pipeline improves itself\n", .{});
    print("  {s}Risk{s}: Section 101 (abstract idea). Mitigate with concrete metrics.\n", .{ RED, RESET });
    print("  {s}Files{s}: src/tri/tri_ouroboros.zig, src/tri/toxic_verdict.zig\n\n", .{ GRAY, RESET });

    // Additional
    print("  {s}ADDITIONAL INVENTIONS{s}\n", .{ GOLDEN, RESET });
    print("  {s}─────────────────────{s}\n", .{ GRAY, RESET });
    print("  P4: VSA balanced ternary + SIMD (src/vsa.zig)\n", .{});
    print("  P5: phi-RoPE: theta_i = phi^(-2i/d) (src/hslm/sacred_attention.zig)\n", .{});
    print("  P6: Branchless ternary matmul 9.2x (src/hslm/sparse_ternary.zig)\n\n", .{});

    print("  {s}Full analysis{s}: docs/lab/papers/patent-strategy/full-analysis.md\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLAIMS — USPTO-format patent claims
// ═══════════════════════════════════════════════════════════════════════════════

fn showClaims(filter: []const u8) void {
    print("\n{s}{s}USPTO-FORMAT PATENT CLAIMS{s}\n", .{ BOLD, GOLDEN, RESET });
    print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    const show_all = std.mem.eql(u8, filter, "all");

    if (show_all or std.mem.eql(u8, filter, "P1") or std.mem.eql(u8, filter, "resonance")) {
        print("  {s}P1: TERNARY RESONANCE + SQUARE ATTENTION{s}\n", .{ GREEN, RESET });
        print("  {s}──────────────────────────────────────────{s}\n\n", .{ GRAY, RESET });
        print("  Claim 1 (Method): A method for configuring neural network dimensions\n", .{});
        print("    as powers of 3 to achieve resonant performance in ternary weight\n", .{});
        print("    networks, wherein all layer dimensions d satisfy d = 3^k for k >= 1.\n\n", .{});
        print("  Claim 2 (System): A ternary neural network exhibiting non-monotonic\n", .{});
        print("    scaling where performance peaks at d = 3^k and degrades at non-power-\n", .{});
        print("    of-3 dimensions, contrary to classical neural scaling laws.\n\n", .{});
        print("  Claim 3 (Method): An attention mechanism wherein context length equals\n", .{});
        print("    head dimension, producing full-rank square Q*K^T matrices.\n\n", .{});
        print("  Claim 4 (Composition): Attention scaling factor 1/(d^(phi^-3)) where\n", .{});
        print("    phi is the golden ratio, for ternary attention layers.\n\n", .{});
    }

    if (show_all or std.mem.eql(u8, filter, "P2") or std.mem.eql(u8, filter, "fpga")) {
        print("  {s}P2: ZERO-DSP FPGA INFERENCE{s}\n", .{ GREEN, RESET });
        print("  {s}───────────────────────────{s}\n\n", .{ GRAY, RESET });
        print("  Claim 1 (Apparatus): Ternary MAC unit using LUT-only logic, wherein\n", .{});
        print("    weights {{-1,0,+1}} encoded as 2-bit codes: sign-extension for +1,\n", .{});
        print("    two's complement for -1, zero-output for 0, without DSP48.\n\n", .{});
        print("  Claim 2 (Method): Shift-based RMSNorm via priority encoder + barrel\n", .{});
        print("    shifter, eliminating DSP-based division.\n\n", .{});
        print("  Claim 3 (System): Multi-layer ternary transformer on FPGA with:\n", .{});
        print("    (a) LUT-only MAC, (b) BRAM with power-of-2 depth padding,\n", .{});
        print("    (c) shift-RMSNorm, (d) sequential blocks, zero DSP48 utilized.\n\n", .{});
        print("  Claim 4 (Method): BRAM address decode with power-of-2 overflow zeroing\n", .{});
        print("    for non-power-of-2 weight matrices.\n\n", .{});
        print("  Claim 5 (Apparatus): LFSR-driven hardware self-test with LED pass/fail.\n\n", .{});
    }

    if (show_all or std.mem.eql(u8, filter, "P3") or std.mem.eql(u8, filter, "ouroboros")) {
        print("  {s}P3: SELF-EVOLVING OUROBOROS{s}\n", .{ YELLOW, RESET });
        print("  {s}──────────────────────────{s}\n\n", .{ GRAY, RESET });
        print("  Claim 1 (Method): Autonomous code improvement with 6-phase cycle\n", .{});
        print("    (diagnose/plan/act/verify/measure/persist) and mandatory verification\n", .{});
        print("    gates with automatic rollback on failure.\n\n", .{});
        print("  Claim 2 (System): 12-dimensional weighted code health scoring with\n", .{});
        print("    automatic strategy rotation on stagnation detection.\n\n", .{});
        print("  Claim 3 (Method): Self-referential pipeline where a designated link\n", .{});
        print("    analyzes and modifies the pipeline's own configuration.\n\n", .{});
        print("  Claim 4 (Method): Golden-ratio-based quality gating where improvement\n", .{});
        print("    rate > phi^(-1) classifies as sustained improvement.\n\n", .{});
    }

    print("  {s}Full claims with evidence{s}: docs/lab/papers/patent-strategy/full-analysis.md\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// STRATEGY — Filing timeline, budget, defense
// ═══════════════════════════════════════════════════════════════════════════════

fn showStrategy() void {
    print("\n{s}{s}PATENT & DEFENSIVE PUBLICATION STRATEGY{s}\n", .{ BOLD, GOLDEN, RESET });
    print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    print("  {s}DEFENSIVE PUBLICATIONS (ACTIVE){s}\n", .{ GREEN, RESET });
    print("  {s}──────────────────────────────────{s}\n", .{ GRAY, RESET });
    print("  All 7 discoveries published as rich defensive publications on Zenodo.\n", .{});
    print("  Each includes: Problem + Technical Disclosure + Evidence + Prior Art\n", .{});
    print("  + Picket Fence extensions + CPC codes + cross-references.\n", .{});
    print("  {s}Run: tri zenodo update [D001-D007]{s}\n\n", .{ CYAN, RESET });

    print("  {s}CPC CLASSIFICATIONS{s}\n", .{ GOLDEN, RESET });
    print("  {s}───────────────────{s}\n", .{ GRAY, RESET });
    print("  D001-D003: H03K19/20, G06F30/34, G06N3/04, G06F7/544\n", .{});
    print("  D004:      G06F8/65, G06N20/00, G06F11/36\n", .{});
    print("  D005:      G06F7/72, G06N3/04, G06F17/16\n", .{});
    print("  D006:      G06N3/0455, G06F17/14, G06N3/084\n", .{});
    print("  D007:      G06F7/544, G06F7/72, G06F17/16\n\n", .{});

    print("  {s}PHASE 1: PROVISIONAL (OPTIONAL){s}\n", .{ YELLOW, RESET });
    print("  {s}──────────────────────────────────{s}\n", .{ GRAY, RESET });
    print("  P1  Resonance + Square Attention  CRITICAL  $2,000-3,000\n", .{});
    print("  P2  Zero-DSP FPGA Inference       CRITICAL  $2,000-3,000\n", .{});
    print("  P3  Self-Evolving Ouroboros        HIGH      $1,500-2,500\n", .{});
    print("  {s}Provisionals give 12 months priority date.{s}\n\n", .{ CYAN, RESET });

    print("  {s}TOTAL BUDGET{s}\n", .{ GOLDEN, RESET });
    print("  {s}────────────{s}\n", .{ GRAY, RESET });
    print("  Phase 1 (provisionals):   $5,500 - $8,500\n", .{});
    print("  Phase 2 (full utility):   $15,000 - $25,000\n", .{});
    print("  Phase 3 (PCT):            $30,000 - $50,000\n", .{});
    print("  {s}3-year total:             $50,000 - $83,000{s}\n\n", .{ WHITE, RESET });

    print("  {s}DEFENSE STRENGTHS{s}\n", .{ GREEN, RESET });
    print("  {s}─────────────────{s}\n", .{ GRAY, RESET });
    print("  1. 7 Zenodo DOIs with rich defensive publication descriptions\n", .{});
    print("  2. CPC-classified for patent examiner discoverability\n", .{});
    print("  3. Cross-referenced DOI graph (all 5 records linked)\n", .{});
    print("  4. Picket fence extensions block trivial variations\n", .{});
    print("  5. 42 Railway services — reproducible experiments\n", .{});
    print("  6. Open-source Yosys toolchain — FPGA results reproducible\n", .{});
    print("  7. Full git history — every experiment documented\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// SNAPSHOT — git tag instructions
// ═══════════════════════════════════════════════════════════════════════════════

fn showSnapshot(name: []const u8) void {
    print("\n{s}PATENT SNAPSHOT{s}\n", .{ GOLDEN, RESET });
    print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    print("  Discovery: {s}{s}{s}\n", .{ CYAN, name, RESET });
    print("  Action:    git tag -a patent-{s}-2026-03-14\n", .{name});
    print("  Zenodo:    Push tag -> GitHub Release -> Zenodo webhook\n\n", .{});

    print("  {s}Commands to run:{s}\n", .{ GOLDEN, RESET });
    print("    git tag -a patent-{s}-2026-03-14 -m \"Patent snapshot: {s}\"\n", .{ name, name });
    print("    git push origin patent-{s}-2026-03-14\n", .{name});
    print("    gh release create patent-{s}-2026-03-14 --title \"Patent: {s}\"\n\n", .{ name, name });
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRAFT — provisional patent template
// ═══════════════════════════════════════════════════════════════════════════════

fn showDraft(name: []const u8) void {
    print("\n{s}PROVISIONAL PATENT DRAFT TEMPLATE{s}\n", .{ GOLDEN, RESET });
    print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    print("  Discovery: {s}{s}{s}\n\n", .{ CYAN, name, RESET });

    print("  Output:    patents/{s}/draft.md\n\n", .{name});

    print("  {s}USPTO Provisional Application Structure:{s}\n", .{ GOLDEN, RESET });
    print("    1. TITLE OF INVENTION\n", .{});
    print("    2. CROSS-REFERENCE TO RELATED APPLICATIONS\n", .{});
    print("    3. FIELD OF THE INVENTION\n", .{});
    print("    4. BACKGROUND OF THE INVENTION\n", .{});
    print("    5. SUMMARY OF THE INVENTION\n", .{});
    print("    6. BRIEF DESCRIPTION OF THE DRAWINGS\n", .{});
    print("    7. DETAILED DESCRIPTION OF PREFERRED EMBODIMENTS\n", .{});
    print("    8. CLAIMS\n", .{});
    print("    9. ABSTRACT OF THE DISCLOSURE\n\n", .{});

    print("  {s}Prior art references:{s}\n", .{ GOLDEN, RESET });
    print("    DOI:  10.5281/zenodo.18939352 (v2.0.1, FPGA autoregressive)\n", .{});
    print("    DOI:  10.5281/zenodo.18950696 (v2.0.3, latest)\n", .{});
    print("    Date: 2026-03-10\n", .{});
    print("    Repo: github.com/gHashTag/trinity\n\n", .{});

    print("  {s}Entity status:{s} Micro entity ($320 filing fee)\n", .{ GOLDEN, RESET });
    print("  {s}Validity:{s} 12 months from filing date\n\n", .{ GOLDEN, RESET });

    print("  {s}Full analysis:{s} docs/lab/papers/patent-strategy/full-analysis.md\n", .{ GOLDEN, RESET });
    print("  {s}View claims:{s}   tri patent claims {s}\n\n", .{ GOLDEN, RESET, name });
}

// ═══════════════════════════════════════════════════════════════════════════════
// ZENODO — DOI records and trigger instructions
// ═══════════════════════════════════════════════════════════════════════════════

fn showZenodo() void {
    print("\n{s}ZENODO DOI RECORDS{s}\n", .{ GOLDEN, RESET });
    print("{s}━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    print("  {s}Published Records:{s}\n", .{ GOLDEN, RESET });
    print("  {s}18939352{s}  10.5281/zenodo.18939352  v2.0.1  FPGA Autoregressive LLM\n", .{ CYAN, RESET });
    print("  {s}18947017{s}  10.5281/zenodo.18947017  —       Concept DOI (all versions)\n", .{ CYAN, RESET });
    print("  {s}18950696{s}  10.5281/zenodo.18950696  v2.0.3  Latest version\n\n", .{ CYAN, RESET });

    print("  {s}Key Record (18939352):{s}\n", .{ GOLDEN, RESET });
    print("    Title:    Trinity v2.0.1 — FPGA Autoregressive Ternary LLM\n", .{});
    print("    Author:   Vasilev Dmitrii (Trinity)\n", .{});
    print("    Date:     2026-03-10\n", .{});
    print("    License:  MIT\n", .{});
    print("    Device:   QMTech XC7A100T ($30)\n", .{});
    print("    Speed:    63 tok/s @ 92 MHz, ~1W\n", .{});
    print("    Result:   16 tokens autoregressive (seed=42)\n", .{});
    print("    Toolchain: openXC7 (yosys + nextpnr-xilinx)\n\n", .{});

    print("  {s}To create new DOI version:{s}\n", .{ GOLDEN, RESET });
    print("    1. Create GitHub Release with version tag\n", .{});
    print("    2. Zenodo auto-creates new DOI version\n", .{});
    print("    3. Update .trinity/patent/status.json\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELP
// ═══════════════════════════════════════════════════════════════════════════════

fn printHelp() void {
    print("\n{s}tri patent{s} — IP protection commands\n\n", .{ GOLDEN, RESET });
    print("  status               DOIs + filing status overview\n", .{});
    print("  analysis             Full patent portfolio analysis\n", .{});
    print("  claims [P1|P2|P3]    USPTO-format claims per invention\n", .{});
    print("  strategy             Filing timeline, budget, defense\n", .{});
    print("  snapshot [--discovery name]  Git tag + zenodo instructions\n", .{});
    print("  draft [--discovery name]     Provisional patent template\n", .{});
    print("  zenodo               Zenodo DOI records + trigger instructions\n\n", .{});
    print("  {s}Full analysis:{s} docs/lab/papers/patent-strategy/full-analysis.md\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "patent_help_does_not_crash" {
    printHelp();
}

test "patent_analysis_does_not_crash" {
    showAnalysis();
}

test "patent_claims_does_not_crash" {
    showClaims("all");
}

test "patent_strategy_does_not_crash" {
    showStrategy();
}

test "patent_zenodo_does_not_crash" {
    showZenodo();
}
