// @origin(spec:tri_zenodo.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI ZENODO — DOI Publishing CLI
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri zenodo publish <version>  — create new version, upload, publish
//   tri zenodo status             — show current record info
//   tri zenodo draft <version>    — create draft without publishing
//   tri zenodo update [D004-D007] — upgrade descriptions to defensive publications
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const print = std.debug.print;
const zenodo_templates = @import("zenodo_templates.zig");

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";
const GOLDEN = "\x1b[38;5;220m";

const RECORD_ID = "18947017";
const API = "https://zenodo.org/api";

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runZenodoCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printHelp();
        return;
    }

    const subcmd = args[0];
    const sub_args = args[1..];

    if (std.mem.eql(u8, subcmd, "publish")) {
        const version = if (sub_args.len > 0) sub_args[0] else {
            print("{s}Usage: tri zenodo publish <version>{s}\n", .{ RED, RESET });
            print("  Example: tri zenodo publish v2.0.4\n", .{});
            return;
        };
        try runPublish(allocator, version, true);
    } else if (std.mem.eql(u8, subcmd, "draft")) {
        const version = if (sub_args.len > 0) sub_args[0] else {
            print("{s}Usage: tri zenodo draft <version>{s}\n", .{ RED, RESET });
            return;
        };
        try runPublish(allocator, version, false);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        try runStatus(allocator);
    } else if (std.mem.eql(u8, subcmd, "discovery")) {
        if (sub_args.len > 0) {
            try publishDiscovery(allocator, sub_args[0]);
        } else {
            try publishAllDiscoveries(allocator);
        }
    } else if (std.mem.eql(u8, subcmd, "bundle")) {
        if (sub_args.len > 0) {
            try publishBundle(allocator, sub_args[0]);
        } else {
            print("{s}Usage: tri zenodo bundle <A-G>{s}\n", .{ RED, RESET });
            print("  A = Ternary Neural Networks (B001)\n", .{});
            print("  B = Zero-DSP FPGA (B002)\n", .{});
            print("  C = TRI-27 ISA (B003)\n", .{});
            print("  D = Queen Orchestration (B004)\n", .{});
            print("  E = Tri Language (B005)\n", .{});
            print("  F = Sacred Formats (B006)\n", .{});
            print("  G = VSA Operations (B007)\n", .{});
        }
    } else if (std.mem.eql(u8, subcmd, "update")) {
        if (sub_args.len > 0) {
            try updateOneRecord(allocator, sub_args[0]);
        } else {
            try updateAllRecords(allocator);
        }
    } else if (std.mem.eql(u8, subcmd, "update-v4")) {
        if (sub_args.len > 0) {
            try updateOneBundleV4(allocator, sub_args[0]);
        } else {
            try updateAllBundlesV4(allocator);
        }
    } else if (std.mem.eql(u8, subcmd, "bundle-v4")) {
        // Create new v4.0 bundle deposits
        if (sub_args.len > 0) {
            try publishBundleV4(allocator, sub_args[0]);
        } else {
            try publishAllBundlesV4(allocator);
        }
    } else if (std.mem.eql(u8, subcmd, "bundle-v5")) {
        // Create new v5.0 bundle deposits with enhanced scientific descriptions
        if (sub_args.len > 0) {
            try publishBundleV5(allocator, sub_args[0]);
        } else {
            try publishAllBundlesV5(allocator);
        }
    } else if (std.mem.eql(u8, subcmd, "bundle-v5.2")) {
        // Create new v5.2 bundle deposits with algorithm boxes, diagrams, statistical analysis
        if (sub_args.len > 0) {
            try publishBundleV5_2(allocator, sub_args[0]);
        } else {
            try publishAllBundlesV5_2(allocator);
        }
    } else if (std.mem.eql(u8, subcmd, "template")) {
        // Generate JSON metadata template from zenodo_templates library
        if (sub_args.len > 0) {
            try generateMetadataTemplate(allocator, sub_args[0]);
        } else {
            print("{s}Usage: tri zenodo template <bundle_id>{s}\n", .{ RED, RESET });
            print("  Bundle IDs: B001, B002, B003, B004, B005, B006, B007, PARENT\n", .{});
        }
    } else if (std.mem.eql(u8, subcmd, "cff")) {
        // Generate CITATION.cff from zenodo_templates library
        if (sub_args.len > 0) {
            try generateCitationCFF(allocator, sub_args[0]);
        } else {
            print("{s}Usage: tri zenodo cff <bundle_id>{s}\n", .{ RED, RESET });
            print("  Bundle IDs: B001, B002, B003, B004, B005, B006, B007, PARENT\n", .{});
        }
    } else if (std.mem.eql(u8, subcmd, "readme")) {
        // Generate README.md for Zenodo deposit from zenodo_templates library
        if (sub_args.len > 0) {
            try generateZenodoReadme(allocator, sub_args[0]);
        } else {
            print("{s}Usage: tri zenodo readme <bundle_id>{s}\n", .{ RED, RESET });
            print("  Bundle IDs: B001, B002, B003, B004, B005, B006, B007, PARENT\n", .{});
        }
    } else if (std.mem.eql(u8, subcmd, "enhanced")) {
        // Generate enhanced metadata with scientific fields (broader impact, ethics, reproducibility)
        if (sub_args.len > 0) {
            try generateEnhancedMetadata(allocator, sub_args[0]);
        } else {
            print("{s}Usage: tri zenodo enhanced <bundle_id>{s}\n", .{ RED, RESET });
            print("  Bundle IDs: B001, B002, B003, B004, B005, B006, B007, PARENT\n", .{});
        }
    } else {
        print("{s}Unknown subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

const Discovery = struct {
    id: []const u8,
    title: []const u8,
    description: []const u8,
    keywords: []const u8,
    files: []const []const u8,
};

const disc_table = [_]Discovery{
    // Original discoveries (D004-D007)
    .{
        .id = "D004",
        .title = "Trinity D004: Self-Evolving Ouroboros — Autonomous 6-Phase Code Improvement System",
        .description = "Autonomous 6-phase code improvement: DIAGNOSE-PLAN-ACT-VERIFY-MEASURE-PERSIST. 12-dimensional Toxic Verdict scoring (BUILD/TEST 50%%, QUALITY 30%%, EFFICIENCY 20%%). Strategy rotation on stagnation. Self-referential pipeline Link #22. Golden-ratio quality gating. 643+1800+939 LOC pure Zig.",
        .keywords = "ouroboros,self-evolving,autonomous-code-improvement,toxic-verdict,golden-chain,zig",
        .files = &.{ "src/tri/tri_ouroboros.zig", "src/tri/toxic_verdict.zig", "src/tri/golden_chain.zig" },
    },
    .{
        .id = "D005",
        .title = "Trinity D005: VSA Balanced Ternary with SIMD — Vector Symbolic Architecture",
        .description = "Vector Symbolic Architecture using balanced ternary with SIMD acceleration. bind/unbind/bundle/permute. 32 trits per SIMD iteration. 20x memory compression vs float32. Extends Kanerva 2009 to balanced ternary with hardware-friendly SIMD.",
        .keywords = "vsa,vector-symbolic-architecture,ternary,simd,hyperdimensional-computing,zig",
        .files = &.{"src/vsa.zig"},
    },
    .{
        .id = "D006",
        .title = "Trinity D006: phi-RoPE — Golden Ratio Rotary Position Encoding for Ternary Attention",
        .description = "Novel rotary position encoding: theta_i = phi^(-2i/HEAD_DIM) instead of standard 10000^(-2i/d). Sacred Attention Scale: 1/(d^(phi^-3)) = 0.354 vs standard 0.111. Aligned with ternary resonance at 3^k dimensions. PPL 2.96 validated.",
        .keywords = "rope,positional-encoding,golden-ratio,attention,ternary,transformer,zig",
        .files = &.{"src/hslm/sacred_attention.zig"},
    },
    .{
        .id = "D007",
        .title = "Trinity D007: Sparse Ternary MatMul — 4-Variant Branchless Multiplication",
        .description = "Four matrix-vector multiply variants for ternary weights: (1) Packed 2-bit 16 weights/u32, (2) Branchless bit-manipulation 9.2x speedup, (3) Sparse CSR, (4) SIMD f16/f32 4-33x speedup. Zero multiplications. 2 bits/param. 1200+ LOC pure Zig.",
        .keywords = "sparse-matmul,ternary,branchless,simd,matrix-multiplication,zig",
        .files = &.{"src/hslm/sparse_ternary.zig"},
    },
    // NEW: 7 Bundled Defensive Publications (66 discoveries total)
    .{
        .id = "B001",
        .title = "Trinity B001: Ternary Neural Networks — Theory to Training Farm",
        .description = "Bundle A: Complete defensive publication for 14 ternary neural network discoveries. Full documentation in TRINITY_S3AI_UNIFIED_FRAMEWORK.md (19KB) and PRIOR_ART_NETWORK.md (16KB). Includes: HSLM (1.95M ternary LLM, PPL=125), T-JEPA (ternary masked prediction), Cosine LR with phi-warmup, Gradient accumulation, Checkpoint compression (20x), Wave-based multi-account training, Ternary dot-product, Cognitive Probes v7 (Min-K%++, Full-ECE), Temperature Scaling v5, ROC/AUC Analysis, Contamination Detection. All implementations in pure Zig with reproducible artifacts.",
        .keywords = "ternary,neural-network,HSLM,T-JEPA,cosine-lr,phi-warmup,gradient,checkpoint,compression,wave-training,cognitive-probes,temperature-scaling,ROC,AUC,contamination,PPL,LLM,defensive-publication",
        .files = &.{ "docs/research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md", "docs/research/PRIOR_ART_NETWORK.md", "docs/research/DEFENSIVE_PUB_IMPLEMENTATION_SUMMARY.md", "docs/research/README.md", "docs/research/citation/bundle_a_ternary_nn.cff", "src/hslm/", "kaggle/eval/" },
    },
    .{
        .id = "B002",
        .title = "Trinity B002: Zero-DSP FPGA for Ternary Inference",
        .description = "Bundle B: Zero-DSP ternary MAC (pure LUT), DSP48E1 wrapper (70%% reduction), CORDIC continued fraction (6-stage), Streaming Argmax (<100 LUT), Ternary BRAM storage (2-bit), Embedding lookup (power-of-2), phi-weighted scheduler, ESP32 Wi-Fi JTAG, UART echo verification, OpenXC7 Docker synthesis, GF16 multiplier, VecMat DSP acceleration. Full documentation in sacred_formats_fpga.md (9.7KB) covering Sacred GF16/TF3 formats with FPGA implementation details. 13 discoveries in FPGA hardware.",
        .keywords = "zero-DSP,FPGA,LUT,inference,ternary,CORDIC,argmax,BRAM,embedding,scheduler,ESP32,JTAG,UART,Yosys,nextpnr,XC7A100T,DSP48E1,multiplier,GF16,TF3,sacred",
        .files = &.{ "docs/research/sacred_formats_fpga.md", "docs/research/PRIOR_ART_NETWORK.md", "docs/research/DEFENSIVE_PUB_IMPLEMENTATION_SUMMARY.md", "docs/research/citation/bundle_b_zero_dsp_fpga.cff", "fpga/openxc7-synth/", "fpga/esp32-xvc/", "src/hslm/f16_utils.zig" },
    },
    .{
        .id = "B003",
        .title = "Trinity B003: TRI-27 — Ternary ISA with Coptic Encoding",
        .description = "Bundle C: TRI-27 ISA (36 opcodes, 27 registers), Coptic alphabet encoding (3-bank: alpha-eta, iota-rho, sigma-sampi), 3-bank validation (cross-bank prevention), T27 binary episode format, Reticular Raphe (phi-decay rolling), Phoenix Medulla (resilience), Queen vmPFC (prefrontal orchestration). Full documentation in tri27_platform.md (12KB), ALPHABET_CANON_27.md (9.9KB), EMIT_T27_SPEC.md (5.7KB). 7 discoveries in ISA and neuro-inspired wrappers.",
        .keywords = "TRI-27,ISA,ternary,Coptic,alphabet,encoding,3-bank,registers,opcodes,episode,binary,reticular-raphe,Phoenix-medulla,vmPFC,prefrontal,neuro-inspired",
        .files = &.{ "docs/research/tri27_platform.md", "docs/research/ALPHABET_CANON_27.md", "docs/research/EMIT_T27_SPEC.md", "docs/research/EMIT_T27_TESTS.md", "docs/research/PRIOR_ART_NETWORK.md", "docs/research/citation/bundle_c_tri27_isa.cff", "src/tri27/", "src/tri27/coptic.zig", "src/tri27/emu/", "src/tri27/reticular_raphe_wrapper.zig", "src/tri27/phoenix_medulla_wrapper.zig", "src/tri27/queen_vmpfc_wrapper.zig" },
    },
    .{
        .id = "B004",
        .title = "Trinity B004: Queen Lotus Cycle — Autonomous Orchestration",
        .description = "Bundle D: Queen Lotus Cycle (6-phase: OBSERVE-ANALYZE-PLAN-EXECUTE-EVALUATE-ADAPT), Episode Jaccard similarity (recall), Quality classification (4 states: UNKNOWN/GOOD/BAD/SACRED), PolicyDelta actions (scale_up/down/out/in), Tri27Config auto-adapt (kill_threshold), Byzantine detection (crash monitoring), Service recycling, SEVO (phi-based hyperopt), ASHA+PBT hybrid (successive halving), Railway serverless ML training farm. Full documentation in queen_lotus_experiments.md (16KB) and neuroanatomical_architecture.md (4.5KB). 10 discoveries in orchestration.",
        .keywords = "Queen,self-learning,orchestration,Lotus,Cycle,episode,Jaccard,similarity,quality,classification,PolicyDelta,auto-adapt,Byzantine,fault-tolerance,recycling,SEVO,hyperopt,ASHA,PBT,Railway,serverless,neuro",
        .files = &.{ "docs/research/queen_lotus_experiments.md", "docs/research/neuroanatomical_architecture.md", "docs/research/PRIOR_ART_NETWORK.md", "docs/research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md", "docs/research/citation/bundle_d_queen_orchestration.cff", "src/tri/queen/", "src/farm/evolution.zig", "src/farm/sevo.zig", "src/farm/railway_api.zig" },
    },
    .{
        .id = "B005",
        .title = "Trinity B005: Tri Language — Linear Types, Effects, Dual-Target",
        .description = "Bundle E: Tri Language (DSL for Zig/Verilog), Linear Types + Ownership (Let/Inout/Sink/Set), Algebraic Effects + Handlers (platform-aware), Bit/Trit Pattern Matching (hardware-level), Content-Addressed Functions (SHA256 AST), Result Type (Austral-style), Array Combinators (map/filter), Pipe Operator, Ternary JSON Parser (3-valued, 100M ops/s), Coptic Code Generation (T27 bytecode), Memory-Tiered Inference (Hippocampus), VIBEE Benchmark Suite, VIBEE Spec (.tri), HNSW Core graph search. Full documentation in tri_language_adt_enum_match_pipe.md (8.5KB), trilanguage_canon.md (16KB), tri_language_roadmap.md (10KB). 13 discoveries in language and compiler.",
        .keywords = "Tri,language,DSL,codegen,Zig,Verilog,linear-types,ownership,affine,effects,handlers,pattern-matching,bit,trit,content-addressed,SHA256,AST,Result,Austral,array,combinators,pipe,JSON,parser,Coptic,bytecode,memory-tiered,hippocampus,HNSW,graph",
        .files = &.{ "docs/research/tri_language_adt_enum_match_pipe.md", "docs/research/trilanguage_canon.md", "docs/research/tri_language_roadmap.md", "docs/research/trusted_tri_core.md", "docs/research/PRIOR_ART_NETWORK.md", "docs/research/citation/bundle_e_tri_language.cff", "src/tri-lang/", "src/vibeec/", "specs/" },
    },
    .{
        .id = "B006",
        .title = "Trinity B006: Sacred GF16/TF3 — phi-Based Arithmetic",
        .description = "Bundle F: Sacred GF16/TF3 Formats (exp=6,mant=9, 37.8%% LUT reduction), TF3 ternary packing (8 weights in 16 bits), phi-distance metric (|a-b|/phi), Saturating arithmetic (FPGA clamp), Sacred constants (phi,pi,e in ternary), Episode JSONL (experience tracking), Tri27Config JSON (Queen config), PolicySnapshot (senses format). Full documentation in sacred_formats_fpga.md (9.7KB) and TRINITY_S3AI_UNIFIED_FRAMEWORK.md (19KB). 9 discoveries in formats and protocols.",
        .keywords = "sacred,GF16,TF3,floating-point,ternary,packing,phi-distance,saturating,arithmetic,constants,Episode,JSONL,Tri27Config,PolicySnapshot,format,protocol",
        .files = &.{ "docs/research/sacred_formats_fpga.md", "docs/research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md", "docs/research/PRIOR_ART_NETWORK.md", "CITATION.cff", "docs/research/citation/bundle_b_zero_dsp_fpga.cff", "src/hslm/f16_utils.zig", "src/tri/sacred.zig" },
    },
    .{
        .id = "B007",
        .title = "Trinity B007: VSA Operations for Ternary Computing",
        .description = "Bundle G: VSA bind/unbind/bundle operations (HybridBigInt SIMD), Ternary dot-product ({-1,0,+1}), Permutation encoding (cyclic), Cosine similarity (ternary vectors), Text encoding VSA (Char to Vec32i8). Vector Symbolic Architecture adapted for ternary computing with associative memory and noise resilience. Full documentation in PRIOR_ART_NETWORK.md (16KB) with complete cross-reference matrix of all 66 discoveries. 3 discoveries in VSA operations.",
        .keywords = "VSA,vector-symbolic,architecture,bind,unbind,bundle,majority-vote,ternary,dot-product,permutation,cyclic,cosine,similarity,text,encoding,associative,memory,noise-resilience",
        .files = &.{ "docs/research/PRIOR_ART_NETWORK.md", "docs/research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md", "docs/research/DEFENSIVE_PUB_IMPLEMENTATION_SUMMARY.md", "docs/research/citation/bundle_g_vsa_ternary.cff", "src/vsa/", "src/vsa_core/" },
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// UPDATE — Upgrade descriptions to defensive publications
// ═══════════════════════════════════════════════════════════════════════════════

const UpdateRecord = struct {
    id: []const u8,
    zenodo_id: []const u8,
    file: []const u8,
    title: []const u8,
    keywords: []const u8,
    cpc: []const u8,
};

const update_records = [_]UpdateRecord{
    .{
        .id = "D001-D003",
        .zenodo_id = "18939352",
        .file = "docs/lab/papers/patent-strategy/zenodo-descriptions/D001-D003.html",
        .title = "Trinity D001-D003: Ternary Resonance Law, Square Attention, Zero-DSP FPGA Inference",
        .keywords = "ternary,FPGA,resonance,attention,zero-DSP,3^k-dimensions,defensive-publication",
        .cpc = "H03K19/20,G06F30/34,G06N3/04,G06F7/544",
    },
    .{
        .id = "D004",
        .zenodo_id = "19020211",
        .file = "docs/lab/papers/patent-strategy/zenodo-descriptions/D004.html",
        .title = "Trinity D004: Self-Evolving Ouroboros — Autonomous 6-Phase Code Improvement System",
        .keywords = "ouroboros,self-evolving,autonomous-code-improvement,toxic-verdict,defensive-publication",
        .cpc = "G06F8/65,G06N20/00,G06F11/36",
    },
    .{
        .id = "D005",
        .zenodo_id = "19020213",
        .file = "docs/lab/papers/patent-strategy/zenodo-descriptions/D005.html",
        .title = "Trinity D005: VSA Balanced Ternary with SIMD — Vector Symbolic Architecture",
        .keywords = "vsa,hyperdimensional,ternary,simd,vector-symbolic-architecture,defensive-publication",
        .cpc = "G06F7/72,G06N3/04,G06F17/16",
    },
    .{
        .id = "D006",
        .zenodo_id = "19020215",
        .file = "docs/lab/papers/patent-strategy/zenodo-descriptions/D006.html",
        .title = "Trinity D006: phi-RoPE — Golden Ratio Rotary Position Encoding for Ternary Attention",
        .keywords = "rope,positional-encoding,golden-ratio,attention,ternary,defensive-publication",
        .cpc = "G06N3/0455,G06F17/14,G06N3/084",
    },
    .{
        .id = "D007",
        .zenodo_id = "19020217",
        .file = "docs/lab/papers/patent-strategy/zenodo-descriptions/D007.html",
        .title = "Trinity D007: Sparse Ternary MatMul — 4-Variant Branchless Multiplication",
        .keywords = "sparse-matmul,branchless,simd,ternary,defensive-publication",
        .cpc = "G06F7/544,G06F7/72,G06F17/16",
    },
};

// Enhanced v4.0 bundle records with markdown descriptions
const bundle_v4_records = [_]UpdateRecord{
    .{
        .id = "B001",
        .zenodo_id = "19225118",
        .file = "docs/research/zenodo_B001_enhanced_v4.md",
        .title = "Trinity B001: HSLM — Ternary Neural Networks with 1.95M Parameters v4.0",
        .keywords = "ternary,neural-network,HSLM,LLM,PPL,TinyStories,1.95M,compression,checkpoint,phi-based,sacred",
        .cpc = "G06N3/00,G06N3/0455,G06F7/52,G06F17/16",
    },
    .{
        .id = "B002",
        .zenodo_id = "19225119",
        .file = "docs/research/zenodo_B002_enhanced_v4.md",
        .title = "Trinity B002: Zero-DSP FPGA Architecture for Ternary Inference v4.0",
        .keywords = "zero-DSP,FPGA,LUT,inference,ternary,CORDIC,argmax,BRAM,Yosys,nextpnr,XC7A100T,synthesis",
        .cpc = "G06F7/52,G06F7/72,G06F17/00,H03K19/20",
    },
    .{
        .id = "B003",
        .zenodo_id = "19225120",
        .file = "docs/research/zenodo_B003_enhanced_v4.md",
        .title = "Trinity B003: TRI-27 ISA — Ternary Instruction Set with Coptic Alphabet Encoding v4.0",
        .keywords = "TRI-27,ISA,ternary,Coptic,alphabet,encoding,3-bank,registers,opcodes,episode,binary",
        .cpc = "G06F9/30,G06F9/34,G06F15/16",
    },
    .{
        .id = "B004",
        .zenodo_id = "19225123",
        .file = "docs/research/zenodo_B004_enhanced_v4.md",
        .title = "Trinity B004: Queen Lotus Cycle — Autonomous Orchestration for Self-Evolving AI v4.0",
        .keywords = "Queen,self-learning,orchestration,Lotus,Cycle,episode,Jaccard,similarity,SEVO,hyperopt,ASHA,PBT,Railway",
        .cpc = "G06N20/00,G06F3/00,G06N5/00",
    },
    .{
        .id = "B005",
        .zenodo_id = "19225121",
        .file = "docs/research/zenodo_B005_enhanced_v4.md",
        .title = "Trinity B005: Tri Language — Linear Types, Effects, Dual-Target Compilation v4.0",
        .keywords = "Tri,language,DSL,codegen,Zig,Verilog,linear-types,ownership,effects,handlers,pattern-matching,bit,trit",
        .cpc = "G06F8/30,G06F8/34,G06F8/65",
    },
    .{
        .id = "B006",
        .zenodo_id = "19225122",
        .file = "docs/research/zenodo_B006_enhanced_v4.md",
        .title = "Trinity B006: Sacred GF16/TF3 — Phi-Based Arithmetic for Ternary Computing v4.0",
        .keywords = "sacred,GF16,TF3,floating-point,ternary,phi-based,arithmetic,compression,phi-distance",
        .cpc = "G06F7/52,G06F7/54,G06F5/01",
    },
    .{
        .id = "B007",
        .zenodo_id = "19225124",
        .file = "docs/research/zenodo_B007_enhanced_v4.md",
        .title = "Trinity B007: VSA Operations for Ternary Computing v4.0",
        .keywords = "VSA,vector-symbolic,architecture,bind,unbind,bundle,ternary,dot-product,permutation,FHRR,BSD",
        .cpc = "G06F7/72,G06F17/16,G06N3/00",
    },
    .{
        .id = "PARENT",
        .zenodo_id = "18947017",
        .file = "docs/research/zenodo_parent_collection_enhanced_v4.md",
        .title = "Trinity S³AI Framework — Unified Scientific Architecture for Ternary Computing v4.0",
        .keywords = "Trinity,S3AI,ternary,computing,framework,HSLM,FPGA,TRI-27,Queen,Tri-language,GF16,TF3,VSA,phi-based,sacred,neural,network,instruction,set,orchestration,linear,types,effects,handlers,pattern,matching",
        .cpc = "G06N3/00,G06N20/00,G06F7/52,G06F9/30,G06F8/30,G06F7/72,G06F17/16",
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// V5.0 Bundle Records — Enhanced with Broader Impact, Ethics, Reproducibility
// ═══════════════════════════════════════════════════════════════════════════════

const bundle_v5_records = [_]UpdateRecord{
    .{
        .id = "B001",
        .zenodo_id = "19227733",
        .file = "docs/research/zenodo_B001_enhanced_v5.md",
        .title = "Trinity B001: Ternary Neural Networks — Complete Scientific Framework v5.0",
        .keywords = "ternary,neural-network,HSLM,LLM,PPL,TinyStories,1.95M,compression,checkpoint,phi-based,sacred,T-JEPA,consciousness-gate,cosine-lr,Docker,reproducibility,ethics,broader-impact",
        .cpc = "G06N3/00,G06N3/0455,G06F7/52,G06F17/16",
    },
    .{
        .id = "B002",
        .zenodo_id = "19227735",
        .file = "docs/research/zenodo_B002_enhanced_v5.md",
        .title = "Trinity B002: Zero-DSP FPGA Architecture for Ternary Inference v5.0",
        .keywords = "zero-DSP,FPGA,LUT,inference,ternary,CORDIC,argmax,BRAM,Yosys,nextpnr,XC7A100T,synthesis,JTAG,ESP32,UART,Docker,reproducibility,ethics,broader-impact",
        .cpc = "G06F7/52,G06F7/72,G06F17/00,H03K19/20",
    },
    .{
        .id = "B003",
        .zenodo_id = "19227737",
        .file = "docs/research/zenodo_B003_enhanced_v5.md",
        .title = "Trinity B003: TRI-27 ISA — Ternary Instruction Set with Coptic Alphabet Encoding v5.0",
        .keywords = "TRI-27,ISA,ternary,Coptic,alphabet,encoding,3-bank,registers,opcodes,episode,binary,27-registers,Docker,reproducibility,ethics,cultural-heritage",
        .cpc = "G06F9/30,G06F9/34,G06F15/16",
    },
    .{
        .id = "B004",
        .zenodo_id = "19227739",
        .file = "docs/research/zenodo_B004_enhanced_v5.md",
        .title = "Trinity B004: Queen Lotus Cycle — Autonomous Orchestration for Self-Evolving AI v5.0",
        .keywords = "Queen,self-learning,orchestration,Lotus,Cycle,episode,Jaccard,similarity,SEVO,hyperopt,ASHA,PBT,Railway,autonomous,AI,ethics,broader-impact,reproducibility",
        .cpc = "G06N20/00,G06F3/00,G06N5/00",
    },
    .{
        .id = "B005",
        .zenodo_id = "19227743",
        .file = "docs/research/zenodo_B005_enhanced_v5.md",
        .title = "Trinity B005: Tri Language — Linear Types, Effects, Dual-Target Compilation v5.0",
        .keywords = "Tri,language,DSL,codegen,Zig,Verilog,linear-types,ownership,effects,handlers,pattern-matching,bit,trit,ADT,pipe,compiler,Docker,reproducibility,ethics",
        .cpc = "G06F8/30,G06F8/34,G06F8/65",
    },
    .{
        .id = "B006",
        .zenodo_id = "19227745",
        .file = "docs/research/zenodo_B006_enhanced_v5.md",
        .title = "Trinity B006: Sacred GF16/TF3 — Phi-Based Arithmetic for Ternary Computing v5.0",
        .keywords = "sacred,GF16,TF3,floating-point,ternary,phi-based,arithmetic,compression,phi-distance,exponent,mantissa,FPGA,Docker,reproducibility,ethics",
        .cpc = "G06F7/52,G06F7/54,G06F5/01",
    },
    .{
        .id = "B007",
        .zenodo_id = "19227749",
        .file = "docs/research/zenodo_B007_enhanced_v5.md",
        .title = "Trinity B007: VSA Operations for Ternary Computing v5.0",
        .keywords = "VSA,vector-symbolic,architecture,bind,unbind,bundle,ternary,dot-product,permutation,FHRR,BSD,HybridBigInt,SIMD,cosine-similarity,Docker,reproducibility,ethics",
        .cpc = "G06F7/72,G06F17/16,G06N3/00",
    },
    .{
        .id = "PARENT",
        .zenodo_id = "19227751",
        .file = "docs/research/zenodo_parent_collection_enhanced_v5.md",
        .title = "Trinity S³AI Framework — Complete Research Collection v5.0",
        .keywords = "Trinity,S3AI,ternary,computing,framework,HSLM,FPGA,TRI-27,Queen,Tri-language,GF16,TF3,VSA,phi-based,sacred,neural,network,instruction,set,orchestration,linear,types,effects,handlers,pattern,matching,ethics,broader-impact,reproducibility",
        .cpc = "G06N3/00,G06N20/00,G06F7/52,G06F9/30,G06F8/30,G06F7/72,G06F17/16",
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// V5.2 Bundle Records — Enhanced with Algorithm Boxes, Diagrams, Statistical Analysis
// ═══════════════════════════════════════════════════════════════════════════════

const bundle_v5_2_records = [_]UpdateRecord{
    .{
        .id = "B001",
        .zenodo_id = "19227733",
        .file = "docs/research/zenodo_B001_enhanced_v5.2.md",
        .title = "Trinity B001: Ternary Neural Networks — Complete Scientific Framework v5.2",
        .keywords = "ternary,neural-network,HSLM,LLM,PPL,TinyStories,1.95M,compression,checkpoint,phi-based,sacred,T-JEPA,consciousness-gate,cosine-lr,Docker,reproducibility,ethics,broader-impact,algorithm-boxes,architecture-diagrams,statistical-analysis,hypothesis-testing,limitations,MLSys-reproducibility-card",
        .cpc = "G06N3/00,G06N3/0455,G06F7/52,G06F17/16",
    },
    .{
        .id = "B002",
        .zenodo_id = "19227735",
        .file = "docs/research/zenodo_B002_enhanced_v5.2.md",
        .title = "Trinity B002: Zero-DSP FPGA Architecture for Ternary Inference v5.2",
        .keywords = "zero-DSP,FPGA,LUT,inference,ternary,CORDIC,argmax,BRAM,Yosys,nextpnr,XC7A100T,synthesis,JTAG,ESP32,UART,Docker,reproducibility,ethics,broader-impact,algorithm-boxes,architecture-diagrams,statistical-analysis,experimental-protocol,limitations",
        .cpc = "G06F7/52,G06F7/72,G06F17/00,H03K19/20",
    },
    .{
        .id = "B003",
        .zenodo_id = "19227737",
        .file = "docs/research/zenodo_B003_enhanced_v5.2.md",
        .title = "Trinity B003: TRI-27 ISA — Ternary Instruction Set with Coptic Alphabet Encoding v5.2",
        .keywords = "TRI-27,ISA,ternary,Coptic,alphabet,encoding,3-bank,registers,opcodes,episode,binary,27-registers,Docker,reproducibility,ethics,cultural-heritage,algorithm-boxes,opcode-tables,assembly-examples,code-density,statistical-analysis,limitations",
        .cpc = "G06F9/30,G06F9/34,G06F15/16",
    },
    .{
        .id = "B004",
        .zenodo_id = "19227739",
        .file = "docs/research/zenodo_B004_enhanced_v5.2.md",
        .title = "Trinity B004: Queen Lotus Cycle — Autonomous Orchestration for Self-Evolving AI v5.2",
        .keywords = "Queen,self-learning,orchestration,Lotus,Cycle,episode,Jaccard,similarity,SEVO,hyperopt,ASHA,PBT,Railway,autonomous,AI,ethics,broader-impact,reproducibility,algorithm-boxes,architecture-diagrams,statistical-analysis,experimental-protocol,limitations,retrieval-accuracy,sample-efficiency",
        .cpc = "G06N20/00,G06F3/00,G06N5/00",
    },
    .{
        .id = "B005",
        .zenodo_id = "19227743",
        .file = "docs/research/zenodo_B005_enhanced_v5.2.md",
        .title = "Trinity B005: Tri Language — Linear Types, Effects, Dual-Target Compilation v5.2",
        .keywords = "Tri,language,DSL,codegen,Zig,Verilog,linear-types,ownership,effects,handlers,pattern-matching,bit,trit,ADT,pipe,compiler,Docker,reproducibility,ethics,algorithm-boxes,type-system-diagrams,code-examples,statistical-analysis,limitations,code-generation-quality",
        .cpc = "G06F8/30,G06F8/34,G06F8/65",
    },
    .{
        .id = "B006",
        .zenodo_id = "19227745",
        .file = "docs/research/zenodo_B006_enhanced_v5.2.md",
        .title = "Trinity B006: Sacred GF16/TF3 — Phi-Based Arithmetic for Ternary Computing v5.2",
        .keywords = "sacred,GF16,TF3,floating-point,ternary,phi-based,arithmetic,compression,phi-distance,exponent,mantissa,FPGA,Docker,reproducibility,ethics,algorithm-boxes,format-specifications,statistical-analysis,limitations,information-retention,hardware-utilization",
        .cpc = "G06F7/52,G06F7/54,G06F5/01",
    },
    .{
        .id = "B007",
        .zenodo_id = "19227749",
        .file = "docs/research/zenodo_B007_enhanced_v5.2.md",
        .title = "Trinity B007: VSA Operations for Ternary Computing v5.2",
        .keywords = "VSA,vector-symbolic,architecture,bind,unbind,bundle,ternary,dot-product,permutation,FHRR,BSD,HybridBigInt,SIMD,cosine-similarity,Docker,reproducibility,ethics,algorithm-boxes,architecture-diagrams,statistical-analysis,SIMD-speedup,noise-resilience,limitations,truth-tables",
        .cpc = "G06F7/72,G06F17/16,G06N3/00",
    },
    .{
        .id = "PARENT",
        .zenodo_id = "19227751",
        .file = "docs/research/zenodo_parent_collection_v5.2.md",
        .title = "Trinity S³AI Framework — Complete Research Collection v5.2",
        .keywords = "Trinity,S3AI,ternary,computing,framework,HSLM,FPGA,TRI-27,Queen,Tri-language,GF16,TF3,VSA,phi-based,sacred,neural,network,instruction,set,orchestration,linear,types,effects,handlers,pattern,matching,ethics,broader-impact,reproducibility,algorithm-boxes,architecture-diagrams,statistical-analysis,experimental-protocols,limitations,MLSys-reproducibility-cards",
        .cpc = "G06N3/00,G06N20/00,G06F7/52,G06F9/30,G06F8/30,G06F7/72,G06F17/16",
    },
};

fn updateAllRecords(allocator: std.mem.Allocator) !void {
    print("\n{s}{s}ZENODO DEFENSIVE PUBLICATION UPDATE{s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    var success: usize = 0;
    var fail: usize = 0;
    for (update_records) |rec| {
        updateSingleRecord(allocator, rec) catch |err| {
            print("{s}  FAILED {s}: {}{s}\n", .{ RED, rec.id, err, RESET });
            fail += 1;
            continue;
        };
        success += 1;
    }

    print("\n{s}Results: {d} updated, {d} failed{s}\n\n", .{ GREEN, success, fail, RESET });
}

fn updateOneRecord(allocator: std.mem.Allocator, record_id: []const u8) !void {
    for (update_records) |rec| {
        if (std.mem.eql(u8, rec.id, record_id)) {
            try updateSingleRecord(allocator, rec);
            return;
        }
    }
    print("{s}Unknown record: {s}. Valid: D001-D003, D004, D005, D006, D007{s}\n", .{ RED, record_id, RESET });
}

fn updateSingleRecord(allocator: std.mem.Allocator, rec: UpdateRecord) !void {
    const token = try loadToken(allocator);
    defer allocator.free(token);

    print("{s}[{s}]{s} Updating Zenodo #{s}...\n", .{ CYAN, rec.id, RESET, rec.zenodo_id });

    // Step 1: Read HTML description from file
    print("  1/4 Reading description from {s}...\n", .{rec.file});
    const desc_file = std.fs.cwd().openFile(rec.file, .{}) catch {
        print("  {s}File not found: {s}{s}\n", .{ RED, rec.file, RESET });
        return error.FileNotFound;
    };
    defer desc_file.close();
    const raw_desc = desc_file.readToEndAlloc(allocator, 65536) catch return error.ReadFailed;
    defer allocator.free(raw_desc);

    // Escape description for JSON embedding
    const description = try jsonEscapeString(allocator, raw_desc);
    defer allocator.free(description);

    // Step 2: Create new version draft
    print("  2/4 Creating new version draft...\n", .{});
    const newver_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/actions/newversion", .{ API, rec.zenodo_id });
    defer allocator.free(newver_url);
    const newver_resp = try curlPost(allocator, newver_url, token, null);
    defer allocator.free(newver_resp);

    // Get the draft ID from response
    const draft_id = jsonExtractString(newver_resp, "id") orelse {
        const resp_preview = newver_resp[0..@min(200, newver_resp.len)];
        print("  {s}Failed to create new version. Response: {s}{s}\n", .{ RED, resp_preview, RESET });
        return error.NewVersionFailed;
    };

    // Step 3: Update metadata with rich description
    print("  3/4 Updating metadata (draft {s})...\n", .{draft_id});

    // Build keywords JSON: human keywords + CPC codes
    var kw_buf: [2048]u8 = undefined;
    var kw_pos: usize = 0;
    kw_buf[kw_pos] = '[';
    kw_pos += 1;

    var kw_iter = std.mem.splitScalar(u8, rec.keywords, ',');
    var first_kw = true;
    while (kw_iter.next()) |kw| {
        if (!first_kw) {
            kw_buf[kw_pos] = ',';
            kw_pos += 1;
        }
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        @memcpy(kw_buf[kw_pos .. kw_pos + kw.len], kw);
        kw_pos += kw.len;
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        first_kw = false;
    }

    // Add CPC codes as keywords
    var cpc_iter = std.mem.splitScalar(u8, rec.cpc, ',');
    while (cpc_iter.next()) |cpc| {
        kw_buf[kw_pos] = ',';
        kw_pos += 1;
        const prefix = "\"CPC:";
        @memcpy(kw_buf[kw_pos .. kw_pos + prefix.len], prefix);
        kw_pos += prefix.len;
        @memcpy(kw_buf[kw_pos .. kw_pos + cpc.len], cpc);
        kw_pos += cpc.len;
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
    }
    kw_buf[kw_pos] = ']';
    kw_pos += 1;

    const related_ids =
        \\[{"identifier":"10.5281/zenodo.18939352","relation":"isPartOf","resource_type":"software"},{"identifier":"10.5281/zenodo.19020211","relation":"isRelatedTo","resource_type":"software"},{"identifier":"10.5281/zenodo.19020213","relation":"isRelatedTo","resource_type":"software"},{"identifier":"10.5281/zenodo.19020215","relation":"isRelatedTo","resource_type":"software"},{"identifier":"10.5281/zenodo.19020217","relation":"isRelatedTo","resource_type":"software"}]
    ;

    const meta_body = try std.fmt.allocPrint(allocator,
        \\{{"metadata":{{"title":"{s}","description":"{s}","keywords":{s},"notes":"CPC Classifications: {s}. Defensive publication.","upload_type":"software","publication_date":"2026-03-14","creators":[{{"name":"Vasilev, Dmitrii","affiliation":"Trinity"}}],"license":{{"id":"MIT"}},"version":"v1.1.0","related_identifiers":{s}}}}}
    , .{ rec.title, description, kw_buf[0..kw_pos], rec.cpc, related_ids });
    defer allocator.free(meta_body);

    const draft_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}", .{ API, draft_id });
    defer allocator.free(draft_url);
    const meta_resp = try curlPut(allocator, draft_url, token, meta_body);
    defer allocator.free(meta_resp);

    if (std.mem.indexOf(u8, meta_resp, "\"status\": 4") != null or std.mem.indexOf(u8, meta_resp, "\"status\":4") != null) {
        print("  {s}Metadata update failed{s}\n", .{ RED, RESET });
        return error.MetadataUpdateFailed;
    }

    // Step 4: Publish the new version
    print("  4/4 Publishing...\n", .{});
    const pub_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/actions/publish", .{ API, draft_id });
    defer allocator.free(pub_url);
    const pub_resp = try curlPost(allocator, pub_url, token, null);
    defer allocator.free(pub_resp);

    const doi = jsonExtractString(pub_resp, "doi") orelse "pending";
    print("  {s}[{s}] Updated! DOI: {s}{s}\n\n", .{ GREEN, rec.id, doi, RESET });
}

fn jsonEscapeString(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var size: usize = 0;
    for (input) |c| {
        size += switch (c) {
            '"', '\\' => 2,
            '\n' => 2,
            '\r' => 2,
            '\t' => 2,
            else => 1,
        };
    }

    const result = try allocator.alloc(u8, size);
    var i: usize = 0;
    for (input) |c| {
        switch (c) {
            '"' => {
                result[i] = '\\';
                result[i + 1] = '"';
                i += 2;
            },
            '\\' => {
                result[i] = '\\';
                result[i + 1] = '\\';
                i += 2;
            },
            '\n' => {
                result[i] = '\\';
                result[i + 1] = 'n';
                i += 2;
            },
            '\r' => {
                result[i] = '\\';
                result[i + 1] = 'r';
                i += 2;
            },
            '\t' => {
                result[i] = '\\';
                result[i + 1] = 't';
                i += 2;
            },
            else => {
                result[i] = c;
                i += 1;
            },
        }
    }
    return result;
}

fn publishDiscovery(allocator: std.mem.Allocator, discovery_id: []const u8) !void {
    for (disc_table) |d| {
        if (std.mem.eql(u8, d.id, discovery_id)) {
            try publishOneDiscovery(allocator, d);
            return;
        }
    }
    print("{s}Unknown discovery: {s}. Valid: D004-D007, B001-B007{s}\n", .{ RED, discovery_id, RESET });
}

// Map bundle letter A-G to B001-B007
fn publishBundle(allocator: std.mem.Allocator, bundle_letter: []const u8) !void {
    if (bundle_letter.len != 1) {
        print("{s}Invalid bundle: {s}. Use A-G{s}\n", .{ RED, bundle_letter, RESET });
        return;
    }
    const c = bundle_letter[0];
    const bundle_id = switch (c) {
        'A', 'a' => "B001",
        'B', 'b' => "B002",
        'C', 'c' => "B003",
        'D', 'd' => "B004",
        'E', 'e' => "B005",
        'F', 'f' => "B006",
        'G', 'g' => "B007",
        else => {
            print("{s}Invalid bundle: {s}. Use A-G{s}\n", .{ RED, bundle_letter, RESET });
            return;
        },
    };
    print("{s}Publishing Bundle {s} ({s})...{s}\n", .{ CYAN, bundle_letter, bundle_id, RESET });
    try publishDiscovery(allocator, bundle_id);
}

fn publishAllDiscoveries(allocator: std.mem.Allocator) !void {
    print("\n{s}{s}ZENODO DISCOVERY DOI — Publishing 4 records{s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    for (disc_table) |d| {
        publishOneDiscovery(allocator, d) catch |err| {
            print("{s}Failed {s}: {}{s}\n", .{ RED, d.id, err, RESET });
            continue;
        };
    }

    print("\n{s}All discoveries published. Run 'tri zenodo status' to verify.{s}\n\n", .{ GREEN, RESET });
}

fn publishOneDiscovery(allocator: std.mem.Allocator, d: Discovery) !void {
    const token = try loadToken(allocator);
    defer allocator.free(token);

    print("{s}[{s}]{s} {s}\n", .{ CYAN, d.id, RESET, d.title });

    // Step 1: Create new deposition
    print("  1/4 Creating record...\n", .{});

    // Build keywords JSON array from comma-separated string
    var kw_buf: [1024]u8 = undefined;
    var kw_pos: usize = 0;
    kw_buf[kw_pos] = '[';
    kw_pos += 1;
    var kw_iter = std.mem.splitScalar(u8, d.keywords, ',');
    var first = true;
    while (kw_iter.next()) |kw| {
        if (!first) {
            kw_buf[kw_pos] = ',';
            kw_pos += 1;
        }
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        @memcpy(kw_buf[kw_pos .. kw_pos + kw.len], kw);
        kw_pos += kw.len;
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        first = false;
    }
    kw_buf[kw_pos] = ']';
    kw_pos += 1;

    const body = try std.fmt.allocPrint(allocator,
        \\{{"metadata":{{"title":"{s}","upload_type":"software","publication_date":"2026-03-14","description":"{s}","creators":[{{"name":"Vasilev, Dmitrii","affiliation":"Trinity"}}],"keywords":{s},"license":{{"id":"MIT"}},"version":"v1.0.0","related_identifiers":[{{"identifier":"10.5281/zenodo.18939352","relation":"isPartOf","resource_type":"software"}}]}}}}
    , .{ d.title, d.description, kw_buf[0..kw_pos] });
    defer allocator.free(body);

    const create_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions", .{API});
    defer allocator.free(create_url);

    const resp = try curlPost(allocator, create_url, token, body);
    defer allocator.free(resp);

    const dep_id = jsonExtractString(resp, "id") orelse {
        print("  {s}Failed to create record{s}\n", .{ RED, RESET });
        return error.CreateFailed;
    };

    print("  2/4 Record ID: {s}\n", .{dep_id});

    // Step 2: Create zip of discovery files
    print("  3/4 Uploading files...\n", .{});
    const zip_name = try std.fmt.allocPrint(allocator, "trinity-{s}.zip", .{d.id});
    defer allocator.free(zip_name);
    const zip_path = try std.fmt.allocPrint(allocator, "/tmp/{s}", .{zip_name});
    defer allocator.free(zip_path);

    // Build argv: zip -r /tmp/trinity-D00X.zip file1 file2 ...
    var argv_buf: [16][]const u8 = undefined;
    argv_buf[0] = "zip";
    argv_buf[1] = "-j";
    argv_buf[2] = zip_path;
    var argc: usize = 3;
    for (d.files) |f| {
        if (argc < argv_buf.len) {
            argv_buf[argc] = f;
            argc += 1;
        }
    }

    const zip_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv_buf[0..argc],
    }) catch |err| {
        print("  {s}Zip failed: {}{s}\n", .{ RED, err, RESET });
        return err;
    };
    allocator.free(zip_result.stdout);
    allocator.free(zip_result.stderr);

    // Upload via files endpoint (old API, more reliable)
    const files_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/files", .{ API, dep_id });
    defer allocator.free(files_url);

    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);
    const file_arg = try std.fmt.allocPrint(allocator, "file=@{s}", .{zip_path});
    defer allocator.free(file_arg);
    const name_arg = try std.fmt.allocPrint(allocator, "name={s}", .{zip_name});
    defer allocator.free(name_arg);

    const upload_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "POST", files_url, "-H", auth, "-F", file_arg, "-F", name_arg },
    });
    allocator.free(upload_result.stdout);
    allocator.free(upload_result.stderr);

    // Step 3: Publish
    print("  4/4 Publishing...\n", .{});
    const pub_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/actions/publish", .{ API, dep_id });
    defer allocator.free(pub_url);
    const pub_resp = try curlPost(allocator, pub_url, token, null);
    defer allocator.free(pub_resp);

    const doi = jsonExtractString(pub_resp, "doi") orelse "pending";
    print("  {s}[{s}] DOI: {s}{s}\n\n", .{ GREEN, d.id, doi, RESET });

    // Cleanup
    std.fs.deleteFileAbsolute(zip_path) catch {};
}

fn updateAllBundlesV4(allocator: std.mem.Allocator) !void {
    print("\n{s}{s}ZENODO BUNDLE v4.0 UPDATE{s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    var success: usize = 0;
    var fail: usize = 0;
    for (bundle_v4_records) |rec| {
        updateBundleV4(allocator, rec) catch |err| {
            print("{s}  FAILED {s}: {}{s}\n", .{ RED, rec.id, err, RESET });
            fail += 1;
            continue;
        };
        success += 1;
    }

    print("\n{s}Results: {d} updated, {d} failed{s}\n\n", .{ GREEN, success, fail, RESET });
}

fn updateOneBundleV4(allocator: std.mem.Allocator, bundle_id: []const u8) !void {
    for (bundle_v4_records) |rec| {
        if (std.mem.eql(u8, rec.id, bundle_id)) {
            try updateBundleV4(allocator, rec);
            return;
        }
    }
    print("{s}Unknown bundle: {s}. Valid: B001-B007, PARENT{s}\n", .{ RED, bundle_id, RESET });
}

fn updateBundleV4(allocator: std.mem.Allocator, rec: UpdateRecord) !void {
    const token = try loadToken(allocator);
    defer allocator.free(token);

    print("{s}[{s}]{s} Updating Zenodo #{s} with v4.0 description...\n", .{ CYAN, rec.id, RESET, rec.zenodo_id });

    // Step 1: Read markdown description from file
    print("  1/4 Reading markdown from {s}...\n", .{rec.file});
    const desc_file = std.fs.cwd().openFile(rec.file, .{}) catch {
        print("  {s}File not found: {s}{s}\n", .{ RED, rec.file, RESET });
        return error.FileNotFound;
    };
    defer desc_file.close();
    const raw_desc = desc_file.readToEndAlloc(allocator, 131072) catch return error.ReadFailed;
    defer allocator.free(raw_desc);

    // Escape description for JSON embedding
    const description = try jsonEscapeString(allocator, raw_desc);
    defer allocator.free(description);

    // Step 1.5: Get existing record and delete all files (required before newversion)
    print("  1.5/5 Removing existing files...\n", .{});
    const record_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}", .{ API, rec.zenodo_id });
    defer allocator.free(record_url);
    const record_resp = try curlGet(allocator, record_url, token);
    defer allocator.free(record_resp);

    // Find and delete all existing files
    var search_pos: usize = 0;
    while (std.mem.indexOfPos(u8, record_resp, search_pos, "\"filename\":") != null) {
        const filename_start = std.mem.indexOfPos(u8, record_resp, search_pos, "\"filename\":") orelse break;
        const start = filename_start + 11; // length of "filename":
        const end = std.mem.indexOfPos(u8, record_resp, start, "\"") orelse break;
        const filename = record_resp[start..end];

        // Get file ID
        const file_id_pattern = try std.fmt.allocPrint(allocator, "\"id\":\"{s}\"", .{filename});
        defer allocator.free(file_id_pattern);
        const id_start = std.mem.indexOf(u8, record_resp, file_id_pattern) orelse continue;
        const id_value_start = id_start + file_id_pattern.len;
        const id_end = std.mem.indexOfPos(u8, record_resp, id_value_start, "\"") orelse continue;
        const file_id = record_resp[id_value_start..id_end];

        // Delete file
        const del_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/files/{s}", .{ API, rec.zenodo_id, file_id });
        defer allocator.free(del_url);
        curlDelete(allocator, del_url, token) catch |err| {
            std.log.warn("Failed to delete file {s}: {}", .{ filename, err });
        };
        print("    Deleted: {s}\n", .{filename});

        search_pos = end + 1;
    }

    // Step 2: Create new version draft
    print("  2/5 Creating new version draft...\n", .{});
    const newver_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/actions/newversion", .{ API, rec.zenodo_id });
    defer allocator.free(newver_url);
    const newver_resp = try curlPost(allocator, newver_url, token, null);
    defer allocator.free(newver_resp);

    // Get the draft ID from response
    const draft_id = jsonExtractString(newver_resp, "id") orelse {
        const resp_preview = newver_resp[0..@min(200, newver_resp.len)];
        print("  {s}Failed to create new version. Response: {s}{s}\n", .{ RED, resp_preview, RESET });
        return error.NewVersionFailed;
    };

    // Step 2.5: Delete all files from the draft (required before updating)
    print("  2.5/5 Removing files from draft {s}...\n", .{draft_id});
    const draft_files_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/files", .{ API, draft_id });
    defer allocator.free(draft_files_url);

    const draft_files_resp = try curlGet(allocator, draft_files_url, token);
    defer allocator.free(draft_files_resp);

    // Find and delete all files from draft
    var draft_search_pos: usize = 0;
    while (std.mem.indexOfPos(u8, draft_files_resp, draft_search_pos, "\"id\":") != null) {
        const id_start = std.mem.indexOfPos(u8, draft_files_resp, draft_search_pos, "\"id\":") orelse break;
        const value_start = id_start + 5;
        const value_end = std.mem.indexOfPos(u8, draft_files_resp, value_start, "\"") orelse break;
        const file_id = draft_files_resp[value_start..value_end];

        // Delete this file from draft
        const del_file_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/files/{s}", .{ API, draft_id, file_id });
        defer allocator.free(del_file_url);
        curlDelete(allocator, del_file_url, token) catch |err| {
            std.log.warn("Failed to delete draft file {s}: {}", .{ file_id, err });
        };

        draft_search_pos = value_end + 1;
    }

    // Step 4: Update metadata with markdown description
    print("  3/5 Updating metadata (draft {s})...\n", .{draft_id});

    // Build keywords JSON: human keywords + CPC codes
    var kw_buf: [2048]u8 = undefined;
    var kw_pos: usize = 0;
    kw_buf[kw_pos] = '[';
    kw_pos += 1;

    var kw_iter = std.mem.splitScalar(u8, rec.keywords, ',');
    var first_kw = true;
    while (kw_iter.next()) |kw| {
        if (!first_kw) {
            kw_buf[kw_pos] = ',';
            kw_pos += 1;
        }
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        @memcpy(kw_buf[kw_pos .. kw_pos + kw.len], kw);
        kw_pos += kw.len;
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        first_kw = false;
    }

    // Add CPC codes as keywords
    var cpc_iter = std.mem.splitScalar(u8, rec.cpc, ',');
    while (cpc_iter.next()) |cpc| {
        kw_buf[kw_pos] = ',';
        kw_pos += 1;
        const prefix = "\"CPC:";
        @memcpy(kw_buf[kw_pos .. kw_pos + prefix.len], prefix);
        kw_pos += prefix.len;
        @memcpy(kw_buf[kw_pos .. kw_pos + cpc.len], cpc);
        kw_pos += cpc.len;
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
    }
    kw_buf[kw_pos] = ']';
    kw_pos += 1;

    const related_ids =
        \\[{"identifier":"10.5281/zenodo.18947017","relation":"isPartOf","resource_type":"software"}]
    ;

    // Build metadata JSON body
    const meta_body = try std.fmt.allocPrint(allocator,
        \\{{"metadata":{{"title":"{s}","description":"{s}","keywords":{s},"notes":"Enhanced v4.0 with full scientific rigor: 5-sentence abstract, LaTeX notation, formal theorems, 95% CIs, Docker reproducibility.","upload_type":"software","publication_date":"2026-03-26","creators":[{{"person_or_org":{{"family_name":"Vasilev","given_name":"Dmitrii","type":"personal"}}}}],"license":{{"id":"cc-by-4.0"}},"version":"4.0","related_identifiers":[{s}]}}}}}}
    , .{ rec.title, description, kw_buf[0..kw_pos], related_ids });
    defer allocator.free(meta_body);

    const draft_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}", .{ API, draft_id });
    defer allocator.free(draft_url);
    const meta_resp = try curlPut(allocator, draft_url, token, meta_body);
    defer allocator.free(meta_resp);

    // Debug: print response on failure
    if (std.mem.indexOf(u8, meta_resp, "\"status\": 4") != null or std.mem.indexOf(u8, meta_resp, "\"status\":4") != null) {
        print("  {s}Metadata update failed{s}\n", .{ RED, RESET });
        print("  Response: {s}\n", .{meta_resp[0..@min(500, meta_resp.len)]});
        return error.MetadataUpdateFailed;
    }

    // Step 5: Publish the new version
    print("  4/5 Publishing...\n", .{});
    const pub_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/actions/publish", .{ API, draft_id });
    defer allocator.free(pub_url);
    const pub_resp = try curlPost(allocator, pub_url, token, null);
    defer allocator.free(pub_resp);

    const doi = jsonExtractString(pub_resp, "doi") orelse "pending";
    print("  {s}[{s}] Updated to v4.0! DOI: {s}{s}\n\n", .{ GREEN, rec.id, doi, RESET });
}

fn publishAllBundlesV4(allocator: std.mem.Allocator) !void {
    print("\n{s}{s}ZENODO BUNDLE v4.0 — Publishing 7 bundles{s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    for (bundle_v4_records) |rec| {
        publishBundleV4Single(allocator, rec) catch |err| {
            print("{s}Failed {s}: {}{s}\n", .{ RED, rec.id, err, RESET });
            continue;
        };
    }

    print("\n{s}All bundles published. Run 'tri zenodo status' to verify.{s}\n\n", .{ GREEN, RESET });
}

fn publishBundleV4(allocator: std.mem.Allocator, bundle_id: []const u8) !void {
    for (bundle_v4_records) |rec| {
        if (std.mem.eql(u8, rec.id, bundle_id)) {
            try publishBundleV4Single(allocator, rec);
            return;
        }
    }
    print("{s}Unknown bundle: {s}. Valid: B001-B007, PARENT{s}\n", .{ RED, bundle_id, RESET });
}

fn publishBundleV4Single(allocator: std.mem.Allocator, rec: UpdateRecord) !void {
    const token = try loadToken(allocator);
    defer allocator.free(token);

    print("{s}[{s}]{s} {s}\n", .{ CYAN, rec.id, RESET, rec.title });

    // Step 1: Create new deposition
    print("  1/4 Creating record...\n", .{});

    // Build keywords JSON array from comma-separated string
    var kw_buf: [1024]u8 = undefined;
    var kw_pos: usize = 0;
    kw_buf[kw_pos] = '[';
    kw_pos += 1;
    var kw_iter = std.mem.splitScalar(u8, rec.keywords, ',');
    var first = true;
    while (kw_iter.next()) |kw| {
        if (!first) {
            kw_buf[kw_pos] = ',';
            kw_pos += 1;
        }
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        @memcpy(kw_buf[kw_pos .. kw_pos + kw.len], kw);
        kw_pos += kw.len;
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        first = false;
    }
    kw_buf[kw_pos] = ']';
    kw_pos += 1;

    const body = try std.fmt.allocPrint(allocator,
        \\{{"metadata":{{"title":"{s}","upload_type":"software","publication_date":"2026-03-26","description":"Enhanced v4.0 with full scientific rigor.","creators":[{{"name":"Vasilev, Dmitrii","affiliation":"Trinity S³AI Framework"}}],"keywords":{s},"license":{{"id":"cc-by-4.0"}},"version":"4.0"}}}}
    , .{ rec.title, kw_buf[0..kw_pos] });
    defer allocator.free(body);

    const create_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions", .{API});
    defer allocator.free(create_url);

    const resp = try curlPost(allocator, create_url, token, body);
    defer allocator.free(resp);

    const dep_id = jsonExtractString(resp, "id") orelse {
        print("  {s}Failed to create record{s}\n", .{ RED, RESET });
        return error.CreateFailed;
    };

    print("  2/4 Record ID: {s}\n", .{dep_id});

    // Step 3: Upload description file
    print("  3/4 Uploading description...\n", .{});

    const files_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/files", .{ API, dep_id });
    defer allocator.free(files_url);

    // Read markdown file
    const desc_content = std.fs.cwd().readFileAlloc(allocator, rec.file, 131072) catch return error.ReadFailed;
    defer allocator.free(desc_content);

    // Write to temp file for upload
    const temp_name = try std.fmt.allocPrint(allocator, "{s}_description.md", .{rec.id});
    defer allocator.free(temp_name);
    const temp_path = try std.fmt.allocPrint(allocator, "/tmp/{s}", .{temp_name});
    defer allocator.free(temp_path);

    {
        const temp_file = try std.fs.createFileAbsolute(temp_path, .{});
        defer temp_file.close();
        try temp_file.writeAll(desc_content);
    }

    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);
    const file_arg = try std.fmt.allocPrint(allocator, "file=@{s}", .{temp_path});
    defer allocator.free(file_arg);
    const name_arg = try std.fmt.allocPrint(allocator, "name={s}_description.md", .{rec.id});
    defer allocator.free(name_arg);

    const upload_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "POST", files_url, "-H", auth, "-F", file_arg, "-F", name_arg },
    });
    allocator.free(upload_result.stdout);
    allocator.free(upload_result.stderr);

    // Step 4: Publish
    print("  4/4 Publishing...\n", .{});
    const pub_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/actions/publish", .{ API, dep_id });
    defer allocator.free(pub_url);
    const pub_resp = try curlPost(allocator, pub_url, token, null);
    defer allocator.free(pub_resp);

    const doi = jsonExtractString(pub_resp, "doi") orelse "pending";
    print("  {s}[{s}] DOI: {s}{s}\n\n", .{ GREEN, rec.id, doi, RESET });

    // Cleanup
    std.fs.deleteFileAbsolute(temp_path) catch {};
}

fn publishAllBundlesV5(allocator: std.mem.Allocator) !void {
    print("\n{s}{s}ZENODO BUNDLE v5.0 — Publishing with Enhanced Scientific Descriptions{s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    for (bundle_v5_records) |rec| {
        publishBundleV5Single(allocator, rec) catch |err| {
            print("{s}Failed {s}: {}{s}\n", .{ RED, rec.id, err, RESET });
            continue;
        };
    }

    print("\n{s}All v5.0 bundles published. Run 'tri zenodo status' to verify.{s}\n\n", .{ GREEN, RESET });
}

fn publishBundleV5(allocator: std.mem.Allocator, bundle_id: []const u8) !void {
    for (bundle_v5_records) |rec| {
        if (std.mem.eql(u8, rec.id, bundle_id)) {
            try publishBundleV5Single(allocator, rec);
            return;
        }
    }
    print("{s}Unknown bundle: {s}. Valid: B001-B007, PARENT{s}\n", .{ RED, bundle_id, RESET });
}

fn publishAllBundlesV5_2(allocator: std.mem.Allocator) !void {
    print("\n{s}{s}ZENODO BUNDLE v5.2 — Publishing with Algorithm Boxes, Diagrams, Statistical Analysis{s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });
    print("Enhanced with:\n", .{});
    print("  • Algorithm boxes (pseudocode for all key algorithms)\n", .{});
    print("  • ASCII architecture diagrams\n", .{});
    print("  • Detailed experimental protocols\n", .{});
    print("  • Statistical analysis with hypothesis testing\n", .{});
    print("  • Limitations sections\n", .{});
    print("  • MLSys reproducibility cards\n\n", .{});

    for (bundle_v5_2_records) |rec| {
        publishBundleV5_2Single(allocator, rec) catch |err| {
            print("{s}Failed {s}: {}{s}\n", .{ RED, rec.id, err, RESET });
            continue;
        };
    }

    print("\n{s}All v5.2 bundles published. Run 'tri zenodo status' to verify.{s}\n\n", .{ GREEN, RESET });
}

fn publishBundleV5_2(allocator: std.mem.Allocator, bundle_id: []const u8) !void {
    for (bundle_v5_2_records) |rec| {
        if (std.mem.eql(u8, rec.id, bundle_id)) {
            try publishBundleV5_2Single(allocator, rec);
            return;
        }
    }
    print("{s}Unknown bundle: {s}. Valid: B001-B007, PARENT{s}\n", .{ RED, bundle_id, RESET });
}

fn publishBundleV5_2Single(allocator: std.mem.Allocator, rec: UpdateRecord) !void {
    const token = try loadToken(allocator);
    defer allocator.free(token);

    print("{s}[{s}]{s} {s}\n", .{ CYAN, rec.id, RESET, rec.title });

    // Step 1: Create new deposition
    print("  1/4 Creating record...\n", .{});

    // Build keywords JSON array from comma-separated string
    var kw_buf: [4096]u8 = undefined;
    var kw_pos: usize = 0;
    kw_buf[kw_pos] = '[';
    kw_pos += 1;
    var kw_iter = std.mem.splitScalar(u8, rec.keywords, ',');
    var first = true;
    while (kw_iter.next()) |kw| {
        if (!first) {
            kw_buf[kw_pos] = ',';
            kw_pos += 1;
        }
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        @memcpy(kw_buf[kw_pos .. kw_pos + kw.len], kw);
        kw_pos += kw.len;
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        first = false;
    }
    kw_buf[kw_pos] = ']';
    kw_pos += 1;

    // Build notes with v5.2 enhancements
    const notes = "Enhanced v5.2 with Algorithm Boxes (pseudocode), ASCII Architecture Diagrams, Detailed Experimental Protocols, Statistical Analysis with Hypothesis Testing, Limitations Sections, MLSys Reproducibility Cards. NeurIPS/ICLR/MLSys 2025 compliant.";

    const body = try std.fmt.allocPrint(allocator,
        \\{{"metadata":{{"title":"{s}","upload_type":"software","publication_date":"2026-03-26","description":"{s}","creators":[{{"name":"Vasilev, Dmitrii","affiliation":"Trinity S³AI Framework"}}],"keywords":{s},"license":{{"id":"cc-by-4.0"}},"version":"5.2","notes":"{s}"}}}}
    , .{ rec.title, notes, kw_buf[0..kw_pos], notes });
    defer allocator.free(body);

    const create_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions", .{API});
    defer allocator.free(create_url);

    const resp = try curlPost(allocator, create_url, token, body);
    defer allocator.free(resp);

    const dep_id = jsonExtractString(resp, "id") orelse {
        print("  {s}Failed to create record{s}\n", .{ RED, RESET });
        return error.CreateFailed;
    };

    print("  2/4 Record ID: {s}\n", .{dep_id});

    // Step 3: Upload description file
    print("  3/4 Uploading enhanced v5.2 description...\n", .{});

    const files_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/files", .{ API, dep_id });
    defer allocator.free(files_url);

    // Read markdown file
    const desc_content = std.fs.cwd().readFileAlloc(allocator, rec.file, 524288) catch return error.ReadFailed;
    defer allocator.free(desc_content);

    // Write to temp file for upload
    const temp_name = try std.fmt.allocPrint(allocator, "{s}_v5.2_description.md", .{rec.id});
    defer allocator.free(temp_name);
    const temp_path = try std.fmt.allocPrint(allocator, "/tmp/{s}", .{temp_name});
    defer allocator.free(temp_path);

    {
        const temp_file = try std.fs.createFileAbsolute(temp_path, .{});
        defer temp_file.close();
        try temp_file.writeAll(desc_content);
    }

    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);
    const file_arg = try std.fmt.allocPrint(allocator, "file=@{s}", .{temp_path});
    defer allocator.free(file_arg);
    const name_arg = try std.fmt.allocPrint(allocator, "name={s}_v5.2_description.md", .{rec.id});
    defer allocator.free(name_arg);

    const upload_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "POST", files_url, "-H", auth, "-F", file_arg, "-F", name_arg },
    });
    allocator.free(upload_result.stdout);
    allocator.free(upload_result.stderr);

    // Step 4: Publish
    print("  4/4 Publishing...\n", .{});
    const pub_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/actions/publish", .{ API, dep_id });
    defer allocator.free(pub_url);
    const pub_resp = try curlPost(allocator, pub_url, token, null);
    defer allocator.free(pub_resp);

    const doi = jsonExtractString(pub_resp, "doi") orelse "pending";
    const conceptdoi = jsonExtractString(pub_resp, "conceptdoi") orelse "pending";
    print("  {s}[{s}] DOI: {s}{s}\n", .{ GREEN, rec.id, doi, RESET });
    print("     Concept DOI: {s}\n\n", .{conceptdoi});

    // Cleanup
    std.fs.deleteFileAbsolute(temp_path) catch {};
}

fn publishBundleV5Single(allocator: std.mem.Allocator, rec: UpdateRecord) !void {
    const token = try loadToken(allocator);
    defer allocator.free(token);

    print("{s}[{s}]{s} {s}\n", .{ CYAN, rec.id, RESET, rec.title });

    // Step 1: Create new deposition
    print("  1/4 Creating record...\n", .{});

    // Build keywords JSON array from comma-separated string
    var kw_buf: [2048]u8 = undefined;
    var kw_pos: usize = 0;
    kw_buf[kw_pos] = '[';
    kw_pos += 1;
    var kw_iter = std.mem.splitScalar(u8, rec.keywords, ',');
    var first = true;
    while (kw_iter.next()) |kw| {
        if (!first) {
            kw_buf[kw_pos] = ',';
            kw_pos += 1;
        }
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        @memcpy(kw_buf[kw_pos .. kw_pos + kw.len], kw);
        kw_pos += kw.len;
        kw_buf[kw_pos] = '"';
        kw_pos += 1;
        first = false;
    }
    kw_buf[kw_pos] = ']';
    kw_pos += 1;

    // Build notes with scientific rigor mention
    const notes = "Enhanced v5.0 with Broader Impact (NeurIPS), Ethical Considerations (ICLR), Reproducibility Checklist (MLSys). 5-sentence abstract structure, LaTeX mathematical notation, formal theorems with QED markers, 95% confidence intervals, Docker reproducibility.";

    const body = try std.fmt.allocPrint(allocator,
        \\{{"metadata":{{"title":"{s}","upload_type":"software","publication_date":"2026-03-26","description":"{s}","creators":[{{"name":"Vasilev, Dmitrii","affiliation":"Trinity S³AI Framework"}}],"keywords":{s},"license":{{"id":"cc-by-4.0"}},"version":"5.0","notes":"{s}"}}}}
    , .{ rec.title, notes, kw_buf[0..kw_pos], notes });
    defer allocator.free(body);

    const create_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions", .{API});
    defer allocator.free(create_url);

    const resp = try curlPost(allocator, create_url, token, body);
    defer allocator.free(resp);

    const dep_id = jsonExtractString(resp, "id") orelse {
        print("  {s}Failed to create record{s}\n", .{ RED, RESET });
        return error.CreateFailed;
    };

    print("  2/4 Record ID: {s}\n", .{dep_id});

    // Step 3: Upload description file
    print("  3/4 Uploading enhanced description...\n", .{});

    const files_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/files", .{ API, dep_id });
    defer allocator.free(files_url);

    // Read markdown file
    const desc_content = std.fs.cwd().readFileAlloc(allocator, rec.file, 262144) catch return error.ReadFailed;
    defer allocator.free(desc_content);

    // Write to temp file for upload
    const temp_name = try std.fmt.allocPrint(allocator, "{s}_v5_description.md", .{rec.id});
    defer allocator.free(temp_name);
    const temp_path = try std.fmt.allocPrint(allocator, "/tmp/{s}", .{temp_name});
    defer allocator.free(temp_path);

    {
        const temp_file = try std.fs.createFileAbsolute(temp_path, .{});
        defer temp_file.close();
        try temp_file.writeAll(desc_content);
    }

    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);
    const file_arg = try std.fmt.allocPrint(allocator, "file=@{s}", .{temp_path});
    defer allocator.free(file_arg);
    const name_arg = try std.fmt.allocPrint(allocator, "name={s}_v5_description.md", .{rec.id});
    defer allocator.free(name_arg);

    const upload_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "POST", files_url, "-H", auth, "-F", file_arg, "-F", name_arg },
    });
    allocator.free(upload_result.stdout);
    allocator.free(upload_result.stderr);

    // Step 4: Publish
    print("  4/4 Publishing...\n", .{});
    const pub_url = try std.fmt.allocPrint(allocator, "{s}/deposit/depositions/{s}/actions/publish", .{ API, dep_id });
    defer allocator.free(pub_url);
    const pub_resp = try curlPost(allocator, pub_url, token, null);
    defer allocator.free(pub_resp);

    const doi = jsonExtractString(pub_resp, "doi") orelse "pending";
    const conceptdoi = jsonExtractString(pub_resp, "conceptdoi") orelse "pending";
    print("  {s}[{s}] DOI: {s}{s}\n", .{ GREEN, rec.id, doi, RESET });
    print("     Concept DOI: {s}\n\n", .{conceptdoi});

    // Cleanup
    std.fs.deleteFileAbsolute(temp_path) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEMPLATE GENERATION FUNCTIONS (using zenodo_templates library)
// ═══════════════════════════════════════════════════════════════════════════════

/// Parse bundle ID string to BundleType enum
fn parseBundleType(bundle_id: []const u8) !zenodo_templates.BundleType {
    if (std.mem.eql(u8, bundle_id, "B001") or std.mem.eql(u8, bundle_id, "A")) return .ternary_nn;
    if (std.mem.eql(u8, bundle_id, "B002") or std.mem.eql(u8, bundle_id, "B")) return .zero_dsp;
    if (std.mem.eql(u8, bundle_id, "B003") or std.mem.eql(u8, bundle_id, "C")) return .tri27_isa;
    if (std.mem.eql(u8, bundle_id, "B004") or std.mem.eql(u8, bundle_id, "D")) return .queen_orchestration;
    if (std.mem.eql(u8, bundle_id, "B005") or std.mem.eql(u8, bundle_id, "E")) return .tri_language;
    if (std.mem.eql(u8, bundle_id, "B006") or std.mem.eql(u8, bundle_id, "F")) return .vsa_ternary;
    if (std.mem.eql(u8, bundle_id, "B007") or std.mem.eql(u8, bundle_id, "G")) return .vsa_ternary;
    if (std.mem.eql(u8, bundle_id, "PARENT")) return .parent;
    return error.InvalidBundleId;
}

/// Generate JSON metadata template from zenodo_templates library
fn generateMetadataTemplate(allocator: std.mem.Allocator, bundle_id: []const u8) !void {
    const bundle_type = try parseBundleType(bundle_id);
    const metadata = try zenodo_templates.createDefaultMetadata(allocator, bundle_type);
    // Note: metadata fields are static string literals, no need to free them

    const json = try metadata.toJSON(allocator);
    defer allocator.free(json);

    print("{s}[{s}]{s} Zenodo JSON Metadata\n\n", .{ CYAN, bundle_type.fileName(), RESET });
    print("{s}\n", .{json});
}

/// Generate CITATION.cff file from zenodo_templates library
fn generateCitationCFF(allocator: std.mem.Allocator, bundle_id: []const u8) !void {
    const bundle_type = try parseBundleType(bundle_id);
    const metadata = try zenodo_templates.createDefaultMetadata(allocator, bundle_type);
    // Note: metadata fields are static string literals, no need to free them

    const cff = try metadata.toCitationCFF(allocator);
    defer allocator.free(cff);

    // Write to file
    const filename = try std.fmt.allocPrint(allocator, "CITATION_{s}.cff", .{bundle_type.fileName()});
    defer allocator.free(filename);

    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    try file.writeAll(cff);

    print("{s}[{s}]{s} CITATION.cff generated\n", .{ GREEN, bundle_type.fileName(), RESET });
    print("  File: {s}\n", .{filename});
}

/// Generate README.md for Zenodo deposit from zenodo_templates library
fn generateZenodoReadme(allocator: std.mem.Allocator, bundle_id: []const u8) !void {
    const bundle_type = try parseBundleType(bundle_id);
    const metadata = try zenodo_templates.createDefaultMetadata(allocator, bundle_type);
    // Note: metadata fields are static string literals, no need to free them

    const readme = try metadata.toZenodoReadme(allocator);
    defer allocator.free(readme);

    // Write to file
    const filename = try std.fmt.allocPrint(allocator, "README_{s}.md", .{bundle_type.fileName()});
    defer allocator.free(filename);

    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    try file.writeAll(readme);

    print("{s}[{s}]{s} README.md generated\n", .{ GREEN, bundle_type.fileName(), RESET });
    print("  File: {s}\n", .{filename});
}

/// Generate enhanced metadata with NeurIPS/ICLR/MLSys 2025 compliant fields
fn generateEnhancedMetadata(allocator: std.mem.Allocator, bundle_id: []const u8) !void {
    const bundle_type = try parseBundleType(bundle_id);
    const metadata = try zenodo_templates.createEnhancedMetadata(allocator, bundle_type);
    defer {
        if (metadata.broader_impact) |s| allocator.free(s);
        if (metadata.ethics) |s| allocator.free(s);
    }

    const json = try metadata.toJSON(allocator);
    defer allocator.free(json);

    print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    print("{s}Enhanced Zenodo Metadata — {s}{s}\n", .{ BOLD, bundle_type.displayName(), RESET });
    print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    print("{s}📋 Metadata Fields:{s}\n", .{ CYAN, RESET });
    print("  • Funding: {d} reference(s)\n", .{if (metadata.funding) |f| f.len else 0});
    print("  • Broader Impact: {s}\n", .{if (metadata.broader_impact != null) "Included" else "None"});
    print("  • Ethical Considerations: {s}\n", .{if (metadata.ethics != null) "Included" else "None"});
    print("  • Reproducibility Info: {s}\n\n", .{if (metadata.reproducibility != null) "Included" else "None"});

    if (metadata.broader_impact) |impact| {
        print("{s}🌍 Broader Impact Statement:{s}\n", .{ GREEN, RESET });
        print("{s}\n\n", .{impact});
    }

    if (metadata.ethics) |eth| {
        print("{s}⚖️  Ethical Considerations:{s}\n", .{ YELLOW, RESET });
        print("{s}\n\n", .{eth});
    }

    if (metadata.reproducibility) |repro| {
        print("{s}🔬 Reproducibility Checklist:{s}\n", .{ CYAN, RESET });
        print("  Code: {s}\n", .{repro.code_url});
        print("  Commit: {s}\n", .{repro.commit_hash});
        if (repro.docker_image) |img| print("  Docker: {s}\n", .{img});
        if (repro.dataset_url) |url| print("  Dataset: {s}\n", .{url});
        print("  Hardware: {s}\n\n", .{repro.hardware});
    }

    print("{s}📄 JSON Metadata (for Zenodo upload):{s}\n", .{ BOLD, RESET });
    print("{s}\n\n", .{json});

    print("{s}✓ Enhanced metadata generated for {s}{s}\n", .{ GREEN, bundle_type.fileName(), RESET });
}

fn printHelp() void {
    print("\n{s}{s}TRI ZENODO — DOI Publishing{s}\n\n", .{ GOLDEN, BOLD, RESET });
    print("  tri zenodo publish <version>    Create new version, upload, publish\n", .{});
    print("  tri zenodo status               Show current record info\n", .{});
    print("  tri zenodo draft <version>      Create draft without publishing\n", .{});
    print("  tri zenodo discovery [D004-D007|B001-B007]  Publish discovery DOI (or all)\n", .{});
    print("  tri zenodo bundle [A-G]         Publish bundle (A=NN, B=FPGA, C=TRI-27, D=Queen, E=Tri, F=Sacred, G=VSA)\n", .{});
    print("  tri zenodo update [D001-D007]    Upgrade descriptions (defensive pub)\n", .{});
    print("  tri zenodo update-v4 [B001-B007] Update bundles to v4.0 with enhanced descriptions\n", .{});
    print("  tri zenodo bundle-v4 [B001-B007] Create new v4.0 bundle deposits\n", .{});
    print("  tri zenodo bundle-v5 [B001-B007] Create new v5.0 bundle deposits (NeurIPS/ICLR/MLSys)\n", .{});
    print("  tri zenodo bundle-v5.2 [B001-B007] Create new v5.2 bundle deposits (algorithm boxes, diagrams, stats)\n", .{});
    print("  tri zenodo template <bundle>    Generate JSON metadata template (B001-B007, PARENT)\n", .{});
    print("  tri zenodo cff <bundle>         Generate CITATION.cff file (B001-B007, PARENT)\n", .{});
    print("  tri zenodo readme <bundle>      Generate README.md for Zenodo (B001-B007, PARENT)\n", .{});
    print("  tri zenodo enhanced <bundle>   Generate enhanced metadata with scientific fields\n\n", .{});
    print("  Requires ZENODO_TOKEN in .env\n", .{});
    print("  Record: {s}\n\n", .{RECORD_ID});
    print("  Discoveries:\n", .{});
    print("    D004-D007: Original (Ouroboros, VSA, phi-RoPE, Sparse MatMul)\n", .{});
    print("    B001-B007: Enhanced Bundles (v4.0, v5.0, v5.2)\n", .{});
    print("              B001=HSLM (1.95M params, PPL 125.3)\n", .{});
    print("              B002=Zero-DSP FPGA (0% DSP, 1.2W)\n", .{});
    print("              B003=TRI-27 ISA (36 opcodes, 27 regs)\n", .{});
    print("              B004=Queen Lotus (2.36× faster)\n", .{});
    print("              B005=Tri Language (Linear types, effects)\n", .{});
    print("              B006=Sacred GF16/TF3 (φ-based arithmetic)\n", .{});
    print("              B007=VSA Operations (30% resilience)\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN LOADING
// ═══════════════════════════════════════════════════════════════════════════════

fn loadToken(allocator: std.mem.Allocator) ![]const u8 {
    // Try env var first
    if (std.process.getEnvVarOwned(allocator, "ZENODO_TOKEN")) |token| {
        return token;
    } else |_| {}

    // Fall back to .env file
    const file = std.fs.cwd().openFile(".env", .{}) catch {
        print("{s}❌ ZENODO_TOKEN not set and .env not found{s}\n", .{ RED, RESET });
        print("   Get token: https://zenodo.org/account/settings/applications/tokens/new/\n", .{});
        return error.TokenNotFound;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 16384) catch return error.TokenNotFound;
    defer allocator.free(content);

    // Find ZENODO_TOKEN=xxx line
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.startsWith(u8, trimmed, "ZENODO_TOKEN=")) {
            const val = trimmed["ZENODO_TOKEN=".len..];
            return allocator.dupe(u8, val);
        }
    }

    print("{s}❌ ZENODO_TOKEN not found in .env{s}\n", .{ RED, RESET });
    return error.TokenNotFound;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CURL HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn curlGet(allocator: std.mem.Allocator, url: []const u8, token: []const u8) ![]u8 {
    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", url, "-H", auth },
    });
    defer allocator.free(result.stderr);
    return result.stdout;
}

fn curlPost(allocator: std.mem.Allocator, url: []const u8, token: []const u8, body: ?[]const u8) ![]u8 {
    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);

    if (body) |b| {
        const result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "curl", "-s", "-X", "POST", url, "-H", auth, "-H", "Content-Type: application/json", "-d", b },
        });
        defer allocator.free(result.stderr);
        return result.stdout;
    } else {
        const result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "curl", "-s", "-X", "POST", url, "-H", auth, "-H", "Content-Type: application/json" },
        });
        defer allocator.free(result.stderr);
        return result.stdout;
    }
}

fn curlPut(allocator: std.mem.Allocator, url: []const u8, token: []const u8, body: []const u8) ![]u8 {
    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "PUT", url, "-H", auth, "-H", "Content-Type: application/json", "-d", body },
    });
    defer allocator.free(result.stderr);
    return result.stdout;
}

fn curlUpload(allocator: std.mem.Allocator, url: []const u8, token: []const u8, filepath: []const u8) ![]u8 {
    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);

    const data_arg = try std.fmt.allocPrint(allocator, "@{s}", .{filepath});
    defer allocator.free(data_arg);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "PUT", url, "-H", auth, "-H", "Content-Type: application/octet-stream", "--data-binary", data_arg },
    });
    defer allocator.free(result.stderr);
    return result.stdout;
}

fn curlDelete(allocator: std.mem.Allocator, url: []const u8, token: []const u8) !void {
    const auth = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "DELETE", url, "-H", auth },
    });
    allocator.free(result.stdout);
    allocator.free(result.stderr);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMPLE JSON EXTRACT (no parser needed — find "key":"value")
// ═══════════════════════════════════════════════════════════════════════════════

fn jsonExtractString(json: []const u8, key: []const u8) ?[]const u8 {
    // Simple approach: find "key" then find next quoted string
    var search_key_buf: [128]u8 = undefined;
    const search_key = std.fmt.bufPrint(&search_key_buf, "\"{s}\"", .{key}) catch return null;

    const key_pos = std.mem.indexOf(u8, json, search_key) orelse return null;
    const after_key = json[key_pos + search_key.len ..];

    // Skip : and whitespace
    var i: usize = 0;
    while (i < after_key.len and (after_key[i] == ':' or after_key[i] == ' ' or after_key[i] == '\t')) : (i += 1) {}

    if (i >= after_key.len) return null;

    // Check if it's a string value
    if (after_key[i] == '"') {
        const start = i + 1;
        const end = std.mem.indexOfPos(u8, after_key, start, "\"") orelse return null;
        return after_key[start..end];
    }

    // Check if it's a number
    if (after_key[i] >= '0' and after_key[i] <= '9') {
        const start = i;
        var end = start;
        while (end < after_key.len and after_key[end] >= '0' and after_key[end] <= '9') : (end += 1) {}
        return after_key[start..end];
    }

    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn runStatus(allocator: std.mem.Allocator) !void {
    const token = try loadToken(allocator);
    defer allocator.free(token);

    print("\n{s}{s}🔬 ZENODO RECORD STATUS{s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    const url = try std.fmt.allocPrint(allocator, "{s}/records/{s}", .{ API, RECORD_ID });
    defer allocator.free(url);

    const response = try curlGet(allocator, url, token);
    defer allocator.free(response);

    const title = jsonExtractString(response, "title") orelse "unknown";
    const doi = jsonExtractString(response, "doi") orelse "unknown";
    const version = jsonExtractString(response, "version") orelse "unknown";
    const created = jsonExtractString(response, "created") orelse "unknown";

    // Extract stats
    const views = jsonExtractString(response, "views") orelse "0";
    const downloads = jsonExtractString(response, "downloads") orelse "0";

    print("\n   📄 Title:     {s}\n", .{title});
    print("   🏷️  DOI:       {s}\n", .{doi});
    print("   📦 Version:   {s}\n", .{version});
    print("   📅 Created:   {s}\n", .{created});
    print("   👁️  Views:     {s}\n", .{views});
    print("   ⬇️  Downloads: {s}\n", .{downloads});
    print("   🔗 URL:       https://doi.org/{s}\n\n", .{doi});
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLISH / DRAFT COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn runPublish(allocator: std.mem.Allocator, version: []const u8, do_publish: bool) !void {
    const token = try loadToken(allocator);
    defer allocator.free(token);

    const action_name = if (do_publish) "PUBLISH" else "DRAFT";
    print("\n{s}{s}🔬 ZENODO {s} — {s}{s}\n", .{ GOLDEN, BOLD, action_name, version, RESET });
    print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    // Step 1: Create new version draft
    print("📝 Step 1/5: Creating new version draft...\n", .{});
    const versions_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/versions", .{ API, RECORD_ID });
    defer allocator.free(versions_url);

    const draft_response = try curlPost(allocator, versions_url, token, null);
    defer allocator.free(draft_response);

    const draft_id = jsonExtractString(draft_response, "id") orelse {
        print("{s}❌ Failed to create draft. Response:{s}\n", .{ RED, RESET });
        print("{s}\n", .{draft_response});
        return error.DraftCreationFailed;
    };
    print("   ✅ Draft ID: {s}\n\n", .{draft_id});

    // Step 2: Update metadata
    print("📋 Step 2/5: Updating metadata...\n", .{});
    const draft_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/draft", .{ API, draft_id });
    defer allocator.free(draft_url);

    const metadata_json = try std.fmt.allocPrint(allocator,
        \\{{"metadata":{{"title":"gHashTag/trinity: Trinity {s} — FPGA Autoregressive Ternary LLM + Training Results","description":"HSLM: 1.95M-parameter ternary language model with zero-DSP FPGA inference. PPL=125 on TinyStories, 1,872KB model, 0 DSP48, $30 FPGA.","creators":[{{"person_or_org":{{"family_name":"Vasilev","given_name":"Dmitrii","type":"personal"}}}}],"publication_date":"{d}-{d:0>2}-{d:0>2}","version":"{s}","resource_type":{{"id":"software"}},"publisher":"Zenodo","related_identifiers":[{{"identifier":"https://github.com/gHashTag/trinity","relation_type":{{"id":"issupplementto"}},"scheme":"url"}}]}}}}
    , .{
        version,
        @as(u16, @intCast(std.time.epoch.EpochSeconds.getEpochDay(@as(std.time.epoch.EpochSeconds, .{ .secs = @intCast(std.time.timestamp()) })).calculateYearDay().year)),
        @as(u9, @intCast(std.time.epoch.EpochSeconds.getEpochDay(@as(std.time.epoch.EpochSeconds, .{ .secs = @intCast(std.time.timestamp()) })).calculateYearDay().calculateMonthDay().month.numeric())),
        @as(u5, @intCast(std.time.epoch.EpochSeconds.getEpochDay(@as(std.time.epoch.EpochSeconds, .{ .secs = @intCast(std.time.timestamp()) })).calculateYearDay().calculateMonthDay().day_index + 1)),
        version,
    });
    defer allocator.free(metadata_json);

    const meta_resp = try curlPut(allocator, draft_url, token, metadata_json);
    defer allocator.free(meta_resp);
    print("   ✅ Metadata updated\n\n", .{});

    // Step 3: Build zip archive
    print("📦 Step 3/5: Building archive...\n", .{});
    const zip_name = try std.fmt.allocPrint(allocator, "trinity-{s}-fpga-llm.zip", .{version});
    defer allocator.free(zip_name);
    const zip_path = try std.fmt.allocPrint(allocator, "/tmp/{s}", .{zip_name});
    defer allocator.free(zip_path);

    const zip_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{
            "zip",                 "-r",                     zip_path,
            "README.md",           "CLAUDE.md",              "LICENSE",
            "build.zig",           "build.zig.zon",          "src/hslm/",
            "src/vsa.zig",         "src/vm.zig",             "fpga/README.md",
            "fpga/openxc7-synth/", "fpga/tools/fpga_eye.py", "docs/lab/papers/",
            "specs/tri/",
        },
    });
    allocator.free(zip_result.stdout);
    allocator.free(zip_result.stderr);
    print("   ✅ Archive: {s}\n\n", .{zip_path});

    // Step 4: Upload
    print("📤 Step 4/5: Uploading...\n", .{});

    // Delete old files first
    const files_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/draft/files", .{ API, draft_id });
    defer allocator.free(files_url);

    const files_resp = try curlGet(allocator, files_url, token);
    defer allocator.free(files_resp);

    // Find and delete old files (simple: look for "key":"filename" patterns)
    var search_pos: usize = 0;
    while (std.mem.indexOfPos(u8, files_resp, search_pos, "\"key\":\"")) |pos| {
        const start = pos + 7; // length of "key":"
        const end = std.mem.indexOfPos(u8, files_resp, start, "\"") orelse break;
        const old_file = files_resp[start..end];
        const del_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/draft/files/{s}", .{ API, draft_id, old_file });
        defer allocator.free(del_url);
        curlDelete(allocator, del_url, token) catch |err| {
            std.log.warn("tri_zenodo: failed to delete old file: {}", .{err});
        };
        print("   🗑️  Deleted: {s}\n", .{old_file});
        search_pos = end + 1;
    }

    // Initiate upload
    const init_body = try std.fmt.allocPrint(allocator, "[{{\"key\":\"{s}\"}}]", .{zip_name});
    defer allocator.free(init_body);
    const init_resp = try curlPost(allocator, files_url, token, init_body);
    allocator.free(init_resp);

    // Upload content
    const upload_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/draft/files/{s}/content", .{ API, draft_id, zip_name });
    defer allocator.free(upload_url);
    const upload_resp = try curlUpload(allocator, upload_url, token, zip_path);
    allocator.free(upload_resp);

    // Commit file
    const commit_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/draft/files/{s}/commit", .{ API, draft_id, zip_name });
    defer allocator.free(commit_url);
    const commit_resp = try curlPost(allocator, commit_url, token, null);
    allocator.free(commit_resp);
    print("   ✅ Upload complete\n\n", .{});

    // Step 5: Publish (or stop at draft)
    if (do_publish) {
        print("🚀 Step 5/5: Publishing...\n", .{});
        const pub_url = try std.fmt.allocPrint(allocator, "{s}/records/{s}/draft/actions/publish", .{ API, draft_id });
        defer allocator.free(pub_url);
        const pub_resp = try curlPost(allocator, pub_url, token, null);
        defer allocator.free(pub_resp);

        const doi = jsonExtractString(pub_resp, "doi") orelse "pending";

        print("\n{s}═══════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
        print("{s}{s}✅ Published to Zenodo!{s}\n\n", .{ GREEN, BOLD, RESET });
        print("   🏷️  DOI:     {s}\n", .{doi});
        print("   🔗 URL:     https://doi.org/{s}\n", .{doi});
        print("   📦 Record:  https://zenodo.org/records/{s}\n", .{draft_id});
        print("   📎 Version: {s}\n", .{version});
        print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });
    } else {
        print("📋 Draft created (not published)\n", .{});
        print("   Draft: https://zenodo.org/records/{s}\n", .{draft_id});
        print("   Publish manually or run: tri zenodo publish {s}\n\n", .{version});
    }

    // Cleanup
    std.fs.deleteFileAbsolute(zip_path) catch |err| {
        std.log.debug("tri_zenodo: failed to cleanup zip file: {}", .{err});
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "json extract string" {
    const json =
        \\{"id":"12345","doi":"10.5281/zenodo.12345","metadata":{"title":"test"}}
    ;
    try std.testing.expectEqualStrings("12345", jsonExtractString(json, "id").?);
    try std.testing.expectEqualStrings("10.5281/zenodo.12345", jsonExtractString(json, "doi").?);
    try std.testing.expectEqualStrings("test", jsonExtractString(json, "title").?);
    try std.testing.expect(jsonExtractString(json, "missing") == null);
}

test "token load from env" {
    // Just verify it compiles and doesn't crash on missing env
    const allocator = std.testing.allocator;
    const result = loadToken(allocator);
    if (result) |token| {
        allocator.free(token);
    } else |_| {
        // Expected when no token set
    }
}

test "json_escape_string" {
    const allocator = std.testing.allocator;
    const escaped = try jsonEscapeString(allocator, "hello \"world\"\nnew line");
    defer allocator.free(escaped);
    try std.testing.expectEqualStrings("hello \\\"world\\\"\\nnew line", escaped);
}

test "update_records_table_valid" {
    for (update_records) |rec| {
        try std.testing.expect(rec.id.len > 0);
        try std.testing.expect(rec.zenodo_id.len > 0);
        try std.testing.expect(rec.file.len > 0);
    }
    try std.testing.expectEqual(@as(usize, 5), update_records.len);
}
