// ═══════════════════════════════════════════════════════════════════════════════
// SACRED BIOLOGY v14.0 — CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════
// DNA, RNA, and protein analysis with sacred mathematics
// φ² + 1/φ² = 3 = TRINITY | DNA is a double golden spiral (34 Å pitch)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const sacred_formula = @import("math/formula.zig");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const WHITE = colors.WHITE;
const GRAY = colors.GRAY;
const RED = colors.RED;
const CYAN = colors.CYAN;
const MAGENTA = colors.MAGENTA;
const RESET = colors.RESET;

// Sacred constants
const PHI = 1.6180339887498948482;
const PHI_SQ = PHI * PHI;

// Fibonacci numbers
const FIBONACCI = [_]usize{ 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377 };

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBioCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try showBioHelp();
        return;
    }

    const subcommand = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcommand, "dna")) {
        try cmdDna(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "rna")) {
        try cmdRna(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "protein")) {
        try cmdProtein(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "phi-genome")) {
        try cmdPhiGenome(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "codon")) {
        try cmdCodon(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "abiogenesis") or std.mem.eql(u8, subcommand, "origin")) {
        try cmdAbiogenesis(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "baryogenesis") or std.mem.eql(u8, subcommand, "baryo")) {
        try cmdBaryogenesis(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "pyramid") or std.mem.eql(u8, subcommand, "reality")) {
        try cmdPyramid(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try showBioHelp();
    } else {
        std.debug.print("{s}Unknown biology command: {s}{s}\n\n", .{ RED, subcommand, RESET });
        try showBioHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DNA ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdDna(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri bio dna <sequence>{s}\n", .{ RED, RESET });
        std.debug.print("  Analyze DNA sequence with sacred mathematics\n", .{});
        return;
    }

    const sequence = args[0];
    const cleaned = try cleanSequence(allocator, sequence, .dna);
    defer allocator.free(cleaned);

    if (cleaned.len == 0) {
        std.debug.print("{s}Error: Invalid DNA sequence '{s}'{s}\n", .{ RED, sequence, RESET });
        return;
    }

    const len = cleaned.len;
    const complement = try complementStrand(allocator, cleaned);
    defer allocator.free(complement);

    const rna = try transcribeToRna(allocator, cleaned);
    defer allocator.free(rna);

    const gc = countGC(cleaned);
    const mw = dnaMolecularWeight(cleaned);
    const ternary = ternarySignature(cleaned);

    // Sacred formula fit
    const fit = sacred_formula.fitSacredFormula(@floatFromInt(len));

    // Print results
    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED BIOLOGY v14.0 — DNA ANALYSIS{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    // Sequence info
    std.debug.print("{s}SEQUENCE INFO{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}5' → 3' :{s} {s}{s}{s}\n", .{ GRAY, RESET, GREEN, cleaned, RESET });
    std.debug.print("  {s}3' → 5' :{s} {s}{s}{s}\n", .{ GRAY, RESET, CYAN, complement, RESET });
    std.debug.print("  {s}RNA     :{s} {s}{s}{s}\n", .{ GRAY, RESET, MAGENTA, rna, RESET });
    std.debug.print("  {s}Length  :{s} {s}{d}{s} bp\n", .{ GRAY, RESET, GOLDEN, len, RESET });

    // GC content
    const gc_pct = if (gc.total > 0) @as(f64, @floatFromInt(gc.count)) / @as(f64, @floatFromInt(gc.total)) * 100.0 else 0.0;
    const gc_ratio = if (gc.at > 0) @as(f64, @floatFromInt(gc.count)) / @as(f64, @floatFromInt(gc.at)) else 0.0;
    std.debug.print("\n{s}GC CONTENT{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}GC Count   :{s} {d} / {d} ({d:.1}%)\n", .{ GRAY, RESET, gc.count, gc.total, gc_pct });
    std.debug.print("  {s}GC Ratio   :{s} {d:.3}", .{ GRAY, RESET, gc_ratio });

    // Check if GC ratio is close to φ
    if (@abs(gc_ratio - PHI) < 0.15) {
        std.debug.print(" {s}≈ φ (SACRED!){s}", .{ GOLDEN, RESET });
    }
    std.debug.print("{s}\n{s}", .{ "", "" });

    // Molecular weight
    std.debug.print("\n{s}MOLECULAR WEIGHT{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}Weight     :{s} {d:.2} g/mol\n", .{ GRAY, RESET, mw });

    // Sacred formula fit
    std.debug.print("\n{s}SACRED FORMULA FIT{s}\n", .{ WHITE, RESET });
    var buf: [128]u8 = undefined;
    const formula = sacred_formula.formatFormulaString(&buf, fit);
    std.debug.print("  {s}V = {s}{s}{s}\n", .{ GRAY, GOLDEN, formula, RESET });
    std.debug.print("  {s}Computed   :{s} {d:.2}\n", .{ GRAY, RESET, fit.computed });
    std.debug.print("  {s}Target     :{s} {d:.0}\n", .{ GRAY, RESET, @as(f64, @floatFromInt(len)) });
    const err_color = if (fit.error_pct < 1.0) GREEN else if (fit.error_pct < 5.0) GOLDEN else RED;
    std.debug.print("  {s}Error      :{s} {s}{d:.3}%{s}\n", .{ GRAY, RESET, err_color, fit.error_pct, RESET });

    // Fibonacci check
    std.debug.print("\n{s}SACRED PROPERTIES{s}\n", .{ WHITE, RESET });
    const is_fib = isFibonacci(len);
    if (is_fib) {
        std.debug.print("  {s}✓ Fibonacci length!{s} {d} is in the sequence)\n", .{ GOLDEN, RESET, len });
    } else {
        std.debug.print("  {s}✗ Not Fibonacci length{s}\n", .{ GRAY, RESET });
    }

    // Ternary signature
    std.debug.print("  {s}Ternary    :{s} Purines={} Pyrimidines={} Balance={d}\n", .{
        GRAY, RESET, ternary.purines, ternary.pyrimidines, ternary.balance
    });

    // Protein translation
    const protein = try translateToProtein(allocator, cleaned);
    defer allocator.free(protein);
    if (protein.len > 0) {
        std.debug.print("\n{s}PROTEIN TRANSLATION{s}\n", .{ WHITE, RESET });
        std.debug.print("  {s}Sequence   :{s} {s}{s}{s}\n", .{ GRAY, RESET, GREEN, protein, RESET });
        std.debug.print("  {s}Length     :{s} {d} aa\n", .{ GRAY, RESET, protein.len });
    }

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// RNA ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdRna(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri bio rna <sequence>{s}\n", .{ RED, RESET });
        std.debug.print("  Analyze RNA sequence with sacred mathematics\n", .{});
        return;
    }

    const sequence = args[0];
    // Convert T to U, keep only valid bases
    var cleaned_list = std.array_list.Managed(u8).init(allocator);
    defer cleaned_list.deinit();

    for (sequence) |c| {
        const upper = std.ascii.toUpper(c);
        if (upper == 'A' or upper == 'U' or upper == 'G' or upper == 'C') {
            try cleaned_list.append(if (upper == 'T') 'U' else upper);
        }
    }

    const cleaned = cleaned_list.items;
    if (cleaned.len == 0) {
        std.debug.print("{s}Error: Invalid RNA sequence '{s}'{s}\n", .{ RED, sequence, RESET });
        return;
    }

    const len = cleaned.len;
    const dna = try rnaToDna(allocator, cleaned);
    defer allocator.free(dna);

    // Sacred formula fit
    const fit = sacred_formula.fitSacredFormula(@floatFromInt(len));

    // Print results
    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED BIOLOGY v14.0 — RNA ANALYSIS{s}\n", .{ MAGENTA, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("{s}SEQUENCE INFO{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}RNA  :{s} {s}{s}{s}\n", .{ GRAY, RESET, MAGENTA, cleaned, RESET });
    std.debug.print("  {s}DNA  :{s} {s}{s}{s}\n", .{ GRAY, RESET, GREEN, dna, RESET });
    std.debug.print("  {s}Length:{s} {s}{d}{s} nt\n\n", .{ GRAY, RESET, GOLDEN, len, RESET });

    std.debug.print("{s}SACRED FORMULA FIT{s}\n", .{ WHITE, RESET });
    var buf: [128]u8 = undefined;
    const formula = sacred_formula.formatFormulaString(&buf, fit);
    std.debug.print("  {s}V = {s}{s}{s}\n", .{ GRAY, GOLDEN, formula, RESET });
    std.debug.print("  {s}Error: {d:.3}%{s}\n\n", .{ GRAY, fit.error_pct, RESET });

    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROTEIN ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdProtein(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri bio protein <sequence>{s}\n", .{ RED, RESET });
        std.debug.print("  Analyze protein sequence (1-letter codes) with sacred mathematics\n", .{});
        return;
    }

    const sequence = args[0];
    var cleaned_list = std.array_list.Managed(u8).init(allocator);
    defer cleaned_list.deinit();

    const valid_aa = "ACDEFGHIKLMNPQRSTVWY";
    for (sequence) |c| {
        const upper = std.ascii.toUpper(c);
        for (valid_aa) |aa| {
            if (upper == aa) {
                try cleaned_list.append(upper);
                break;
            }
        }
    }

    const cleaned = cleaned_list.items;
    if (cleaned.len == 0) {
        std.debug.print("{s}Error: Invalid protein sequence '{s}'{s}\n", .{ RED, sequence, RESET });
        return;
    }

    const len = cleaned.len;
    const mw = proteinMolecularWeight(cleaned);

    // Sacred formula fit
    const fit = sacred_formula.fitSacredFormula(@floatFromInt(len));

    // Print results
    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED BIOLOGY v14.0 — PROTEIN ANALYSIS{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("{s}SEQUENCE INFO{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}Protein :{s} {s}{s}{s}\n", .{ GRAY, RESET, GREEN, cleaned, RESET });
    std.debug.print("  {s}Length  :{s} {s}{d}{s} aa\n", .{ GRAY, RESET, GOLDEN, len, RESET });
    std.debug.print("  {s}Weight  :{s} {d:.2} Da\n\n", .{ GRAY, RESET, mw });

    std.debug.print("{s}SACRED FORMULA FIT{s}\n", .{ WHITE, RESET });
    var buf: [128]u8 = undefined;
    const formula = sacred_formula.formatFormulaString(&buf, fit);
    std.debug.print("  {s}V = {s}{s}{s}\n", .{ GRAY, GOLDEN, formula, RESET });
    std.debug.print("  {s}Error: {d:.3}%{s}\n\n", .{ GRAY, fit.error_pct, RESET });

    const is_fib = isFibonacci(len);
    if (is_fib) {
        std.debug.print("  {s}✓ Fibonacci length!{s} ({d} aa)\n\n", .{ GOLDEN, RESET, len });
    }

    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// PHI-GENOME SEARCH
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdPhiGenome(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED BIOLOGY v14.0 — PHI-GENOME SEARCH{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("{s}Sacred genome patterns:{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}•{s} DNA helix pitch: 34 {s}Å{s} {s}(≈ φ⁴){s}\n", .{ GRAY, RESET, GOLDEN, RESET, GOLDEN, RESET });
    std.debug.print("  {s}•{s} Bases per turn: 10 {s}(sacred number){s}\n", .{ GRAY, RESET, GOLDEN, RESET });
    std.debug.print("  {s}•{s} Rise per bp: 3.4 {s}Å{s} {s}(≈ φ + 2){s}\n", .{ GRAY, RESET, GOLDEN, RESET, GOLDEN, RESET });
    std.debug.print("  {s}•{s} A-T: 2 H-bonds, G-C: 3 H-bonds {s}(ternary ±1){s}\n\n", .{ GRAY, RESET, GOLDEN, RESET });

    std.debug.print("{s}Fibonacci genome positions:{s}\n", .{ WHITE, RESET });
    for (FIBONACCI[0..12]) |f| {
        const marker = if (f <= 34) "✓" else " ";
        std.debug.print("  {s}  {s}F{d:<3} = {d}{s}\n", .{ GRAY, marker, f, f, RESET });
    }

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CODON LOOKUP
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdCodon(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri bio codon <codon>{s}\n", .{ RED, RESET });
        std.debug.print("  Look up codon (RNA: U, DNA: T)\n", .{});
        return;
    }

    const codon = args[0];
    const upper = try std.ascii.allocUpperString(allocator, codon);
    defer allocator.free(upper);

    // Convert T to U for lookup
    var rna_codon: [3]u8 = undefined;
    for (0..3) |i| {
        if (i >= upper.len) break;
        rna_codon[i] = if (upper[i] == 'T') 'U' else upper[i];
    }

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED BIOLOGY v14.0 — CODON LOOKUP{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("{s}RNA Codon  : {s}{s}{s}\n", .{ WHITE, MAGENTA, rna_codon, RESET });
    const aa = getCodonAminoAcid(&rna_codon);
    const name = getCodonAminoAcidName(&rna_codon);

    if (std.mem.eql(u8, &rna_codon, "AUG")) {
        std.debug.print("  {s}Amino Acid : {s}M (Methionine) {s}[START]{s}\n", .{ WHITE, GREEN, GOLDEN, RESET });
    } else if (std.mem.eql(u8, &rna_codon, "UAA") or std.mem.eql(u8, &rna_codon, "UAG") or std.mem.eql(u8, &rna_codon, "UGA")) {
        std.debug.print("  {s}Amino Acid : {s}* {s}[STOP]{s}\n", .{ WHITE, RED, GOLDEN, RESET });
    } else {
        std.debug.print("  {s}Amino Acid : {s}{c}{s} ({s}){s}\n", .{ WHITE, GREEN, aa, RESET, name, RESET });
    }

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// ORIGIN OF LIFE — ABIOMNESIS v12.1
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdAbiogenesis(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;

    const PHI_CU = PHI * PHI * PHI;
    const PHI_QU = PHI_CU * PHI;
    const PHI_INV = 1.0 / PHI;
    const GAMMA = 1.0 / PHI_CU;
    const PI = 3.14159265358979323846;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED ORIGIN OF LIFE v12.1 — ABIOMNESIS FROM φ{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n{s}Core Discovery: Life emerges when φ-organization > φ⁻¹ = 0.618{s}\n\n", .{ WHITE, RESET });

    std.debug.print("{s}CRITICAL THRESHOLDS{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}Abiogenesis threshold{s} : φ⁻¹ = {d:.3}\n", .{ WHITE, RESET, PHI_INV });
    std.debug.print("  {s}RNA world threshold{s}   : φ³ = {d:.3} nt\n", .{ WHITE, RESET, PHI_CU });
    std.debug.print("  {s}Chirality selection{s}    : φ⁻² - 0.5 = {d:.3} (L-excess)\n\n", .{ WHITE, RESET, PHI_INV * PHI_INV - 0.5 });

    std.debug.print("{s}SACRED FORMULAS (121-140){s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}121. Amino acid stability{s}  : τ = φ³ × 100 Myr = {d:.0} Myr\n", .{ WHITE, RESET, PHI_CU * 100.0 });
    std.debug.print("  {s}122. RNA half-life{s}        : t₁/₂ = φ⁴ × γ × 1 yr = {d:.2} yr\n", .{ WHITE, RESET, PHI_QU * GAMMA });
    std.debug.print("  {s}123. Chirality bias{s}       : ΔL = φ⁻² - 0.5 = {d:.3} (11.8% L)\n", .{ WHITE, RESET, PHI_INV * PHI_INV - 0.5 });
    std.debug.print("  {s}124. Peptide bond energy{s}  : E = γ × π × 10 = {d:.2} kJ/mol\n", .{ WHITE, RESET, GAMMA * PI * 10.0 });
    std.debug.print("  {s}125. Minimal genome{s}       : N_min = φ⁴ × 10² = {d:.0} genes\n", .{ WHITE, RESET, PHI_QU * 100.0 });
    std.debug.print("  {s}126. LUCA complexity{s}      : C_LUCA = φ⁵ × 100 = {d:.0} proteins\n", .{ WHITE, RESET, PHI_QU * PHI * 100.0 });
    std.debug.print("  {s}127. First cell radius{s}    : R_min = φ² × 100 nm = {d:.0} nm\n", .{ WHITE, RESET, PHI_SQ * 100.0 });
    std.debug.print("  {s}128. Metabolic efficiency{s}  : η = φ⁻¹ = {d:.1}%\n", .{ WHITE, RESET, PHI_INV * 100 });
    std.debug.print("  {s}129. ATP hydrolysis energy{s} : E_ATP = γ × π × 27.5 = {d:.1} kJ/mol\n", .{ WHITE, RESET, GAMMA * PI * 27.5 });
    std.debug.print("  {s}130. Ribosome precision{s}    : ε = γ/π = {d:.1}% (framework)\n", .{ WHITE, RESET, GAMMA / PI * 100 });
    std.debug.print("  {s}131. Codon binding energy{s}  : ΔG = φ kT = {d:.3} kT\n", .{ WHITE, RESET, PHI });
    std.debug.print("  {s}132. tRNA anticodon loop{s}   : L = φ × 7 = {d:.1} nt\n", .{ WHITE, RESET, PHI * 7.0 });
    std.debug.print("  {s}133. Genetic code optimality{s}: O = φ⁴ × 2 / π = {d:.2}\n", .{ WHITE, RESET, PHI_QU * 2.0 / PI });
    std.debug.print("  {s}134. Prebiotic concentration{s}: C = γ = {d:.3} M\n", .{ WHITE, RESET, GAMMA });
    std.debug.print("  {s}135. Lipid bilayer thickness{s}: d = φ × 2 = {d:.2} nm\n", .{ WHITE, RESET, PHI * 2.0 });
    std.debug.print("  {s}136. Membrane potential{s}     : V = γ × 100 mV = {d:.1} mV\n", .{ WHITE, RESET, GAMMA * 100.0 });
    std.debug.print("  {s}137. Protein folding speed{s}  : v = γ = {d:.3} Å/μs\n", .{ WHITE, RESET, GAMMA });
    std.debug.print("  {s}138. Enzyme enhancement{s}     : k_cat/k_uncat = φ⁶ = {d:.1}×\n", .{ WHITE, RESET, PHI * PHI * PHI * PHI * PHI * PHI });
    std.debug.print("  {s}139. Replication fidelity{s}   : F = 1 - γ⁴ = {d:.3}\n", .{ WHITE, RESET, 1.0 - GAMMA * GAMMA * GAMMA * GAMMA });
    std.debug.print("  {s}140. Origin temperature{s}     : T₀ = φ × 273 K = {d:.0} K (168°C)\n\n", .{ WHITE, RESET, PHI * 273.0 });

    std.debug.print("{s}BRIDGES TO EXISTING SACRED BIOLOGY{s}\n", .{ CYAN, RESET });
    std.debug.print("  • DNA pitch (v11.1): φ⁴ × 5 = 34.005 Å {s}[SMOKING GUN #1]{s}{s}\n", .{ GREEN, GOLDEN, RESET });
    std.debug.print("  • Alpha helix (v11.1): φ² = 3.618 residues/turn {s}[SMOKING GUN #2]{s}{s}\n", .{ GREEN, GOLDEN, RESET });
    std.debug.print("  • Neural gamma (v11.3): φ³ × π / γ = 56 Hz{s}{s}\n\n", .{ GREEN, RESET });

    std.debug.print("{s}All 20 formulas connected via φ and γ = φ⁻³{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}φ² + 1/φ² = 3 | TRINITY v12.1 | γ = 0.236{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED BARYOGENESIS v13.0 — MATTER-ANTIMATTER ASYMMETRY
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdBaryogenesis(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;

    const PHI_CU = PHI * PHI * PHI;
    const GAMMA = 1.0 / PHI_CU;
    const PI = 3.14159265358979323846;
    const E = 2.718281828459045;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED BARYOGENESIS v13.0 — ORIGIN OF MATTER{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n{s}Core Discovery: Matter dominates when η = 7γ¹³/(φ⁵e²) ≈ 6×10⁻¹⁰{s}\n\n", .{ WHITE, RESET });

    // Calculate key values
    const gamma_13 = std.math.pow(f64, GAMMA, 13);
    const phi_5 = std.math.pow(f64, PHI, 5);
    const phi_4 = std.math.pow(f64, PHI, 4);
    const phi_6 = std.math.pow(f64, PHI, 6);
    const e_sq = E * E;
    const eta = 7.0 * gamma_13 / (phi_5 * e_sq);
    const j_ckm = 21.0 * std.math.pow(f64, GAMMA, 5) / (PI * PI * phi_4 * e_sq);

    std.debug.print("{s}THE BARYON ASYMMETRY (η = 6.09±0.06×10⁻¹⁰ from Planck 2018){s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}Formula{s}: η = 7 × γ¹³ / (φ⁵ × e²)\n", .{ WHITE, RESET });
    std.debug.print("  {s}Prediction{s}: η = {d:.3}×10⁻¹⁰ ({d:.1}% error){s}\n", .{ WHITE, RESET, eta * 1e10, @abs(eta - 6.09e-10) / 6.09e-10 * 100.0, GREEN });
    std.debug.print("            {s}[SMOKING GUN: 0.8% accuracy!]{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("{s}SACRED FORMULAS (141-160){s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}141. Baryon asymmetry η{s}     : 7γ¹³/(φ⁵e²) = {d:.3}×10⁻¹⁰\n", .{ WHITE, RESET, eta * 1e10 });
    std.debug.print("  {s}142. Leptogenesis η_L{s}       : γ¹³/π = {d:.2}×10⁻¹⁰\n", .{ WHITE, RESET, gamma_13 / PI * 1e10 });
    std.debug.print("  {s}143. Sakharov factor S{s}      : γπ/φ = {d:.3}\n", .{ WHITE, RESET, GAMMA * PI / PHI });
    std.debug.print("  {s}144. Sphaleron rate Γ_s{s}     : γ²⁶×T⁴/(π²e²) @ 100 GeV\n", .{ WHITE, RESET });
    std.debug.print("  {s}145. Baryon number Y_B{s}      : φ⁶/(2π²)×10⁻¹⁰ = {d:.2}×10⁻¹⁰\n", .{ WHITE, RESET, phi_6 / (2.0 * PI * PI) * 1e10 });
    std.debug.print("  {s}146. Neutron/proton ratio{s}   : γ/φ = {d:.3} (≈1:7)\n", .{ WHITE, RESET, GAMMA / PHI });
    std.debug.print("  {s}147. Deuteron binding{s}      : γπ×2.2 = {d:.2} MeV\n", .{ WHITE, RESET, GAMMA * PI * 2.2 });
    std.debug.print("  {s}148. He-4 binding{s}          : 4πγ×10 = {d:.1} MeV\n", .{ WHITE, RESET, 4.0 * PI * GAMMA * 10.0 });
    std.debug.print("  {s}149. Li-7 problem{s}          : γ⁻²×10⁻¹¹ = {d:.2}×10⁻¹⁰\n", .{ WHITE, RESET, (1.0 / (GAMMA * GAMMA)) * 1e-10 });
    std.debug.print("  {s}150. Matter/antimatter ratio{s}: 10⁹⁰/(γπ) ≈ 10⁸⁹\n\n", .{ WHITE, RESET });

    std.debug.print("{s}NUCLEOSYNTHESIS FORMULAS (156-160){s}\n", .{ CYAN, RESET });
    const phi_inv_cubed = 1.0 / std.math.pow(f64, PHI, 3);
    std.debug.print("  {s}156. D/H ratio{s}             : φ⁻³×10⁻⁴ = {d:.3}×10⁻⁵\n", .{ WHITE, RESET, phi_inv_cubed * 1e-5 });
    std.debug.print("  {s}157. He³/He⁴ ratio{s}         : γ×0.08 = {d:.3}\n", .{ WHITE, RESET, GAMMA * 0.08 });
    std.debug.print("  {s}158. CNO enhancement{s}        : φ⁴×10⁻³ = {d:.4}\n", .{ WHITE, RESET, phi_4 * 1e-3 });
    std.debug.print("  {s}159. Iron peak mass{s}       : φ⁶ M_⊙ = {d:.1} M_⊙\n", .{ WHITE, RESET, phi_6 });
    std.debug.print("  {s}160. White dwarf cooling{s}   : γ×T⁴/t\n\n", .{ WHITE, RESET });

    std.debug.print("{s}BRIDGES TO EXISTING PHYSICS{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}• Jarlskog J (CP violation): 21γ⁵/(π²φ⁴e²) = {d:.3}×10⁻⁵{s}\n", .{ GREEN, j_ckm * 1e5, RESET });
    std.debug.print("  {s}• Strong CP θ (axion): γ⁻²/π ≈ 5.7 μeV{s}\n", .{ GREEN, RESET });
    std.debug.print("  {s}• CKM mixing angles: All via γ³π, γ²/φ, etc.{s}\n\n", .{ GREEN, RESET });

    std.debug.print("{s}All 20 formulas connected via φ and γ = φ⁻³{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}φ² + 1/φ² = 3 | TRINITY v13.0 | η = 6×10⁻¹⁰{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// FULL MODEL OF REALITY v12.2 — PYRAMID
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdPyramid(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    // Import full model from build system module
    const full_model = @import("reality");

    // Check for compact mode
    const compact = if (args.len > 0)
        std.mem.eql(u8, args[0], "compact") or std.mem.eql(u8, args[0], "-c")
    else
        false;

    // Get all levels
    const levels = comptime std.meta.tags(full_model.RealityLevel);

    if (compact) {
        // Compact view
        std.debug.print(
            \\TRINITY v12.2 FULL MODEL — 14 Levels, 140 Formulas
            \\════════════════════════════════════════════════════════
            \\
        , .{});
        for (levels, 1..) |level, i| {
            const lvl: full_model.RealityLevel = level;
            std.debug.print("{d:2}. {s} {s} [{} formulas]\n", .{
                i, lvl.emoji(), lvl.displayName(), lvl.formulaCount(),
            });
        }
        std.debug.print("\nφ² + 1/φ² = 3 | γ = φ⁻³ | C_thr = φ⁻¹ = 0.618\n\n", .{});
    } else {
        // Full pyramid view
        std.debug.print(
            \\
            \\╔══════════════════════════════════════════════════════════════════════╗
            \\║     TRINITY v12.2 — FULL MODEL OF REALITY                           ║
            \\║     140 Sacred Formulas from Mathematics to Consciousness           ║
            \\╠══════════════════════════════════════════════════════════════════════╣
            \\║     φ² + 1/φ² = 3 | γ = φ⁻³ | Consciousness: φ⁻¹ = 0.618            ║
            \\╚══════════════════════════════════════════════════════════════════════╝
            \\
            \\                    THE 14 LEVELS OF REALITY
            \\
        , .{});

        // Display pyramid from top (consciousness) to bottom (mathematics)
        std.debug.print("\n                        🧠 CONSCIOUSNESS (Level 14)\n", .{});
        std.debug.print("                              ↑ 20 formulas\n", .{});

        inline for (levels) |lvl| {
            const level: full_model.RealityLevel = lvl;
            if (level == .consciousness_qualia) continue;

            std.debug.print("      {s: >4} {s} [{} formulas]\n", .{
                level.emoji(),
                level.displayName(),
                level.formulaCount(),
            });

            if (@intFromEnum(level) < 12) {
                std.debug.print("      ↑\n", .{});
            }
        }

        std.debug.print(
            \\
            \\╔══════════════════════════════════════════════════════════════════════╗
            \\║  KEY INSIGHTS                                                        ║
            \\╠══════════════════════════════════════════════════════════════════════╣
            \\║  • All levels connected via φ-scaling: Level(N+1) = Level(N) × φ^k   ║
            \\║  • Consciousness emerges at level 14 when organization > φ⁻¹ = 0.618 ║
            \\║  • Barbero-Immirzi γ = φ⁻³ = 0.236... appears at quantum gravity      ║
            \\║  • DNA pitch (34 Å) = φ⁴ × 5 emerges at biology level                 ║
            \\║  • Neural gamma (56 Hz) = φ³ × π / γ emerges at consciousness        ║
            \\╚══════════════════════════════════════════════════════════════════════╝
            \\
        , .{});
    }

    // Show key formulas
    std.debug.print("{s}KEY SACRED FORMULAS{s}\n", .{ CYAN, RESET });
    std.debug.print("  φ² + φ⁻² = 3 (TRINITY identity)\n", .{});
    std.debug.print("  γ = φ⁻³ = {d:.3} (Barbero-Immirzi)\n", .{full_model.GAMMA});
    std.debug.print("  f_γ = φ³ × π / γ = {d:.0} Hz (Neural gamma)\n", .{full_model.Level14Formulas.neuralGammaFrequency()});
    std.debug.print("  C_thr = φ⁻¹ = {d:.3} (Consciousness threshold)\n", .{full_model.Level14Formulas.consciousnessThreshold()});
    std.debug.print("  t_present = φ⁻² = {d:.3} s (Specious present)\n\n", .{full_model.Level14Formulas.speciousPresent()});
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

const SeqType = enum { dna, rna, protein };

fn cleanSequence(allocator: std.mem.Allocator, seq: []const u8, comptime seq_type: SeqType) ![]u8 {
    var result = std.array_list.Managed(u8).init(allocator);
    defer result.deinit();

    const valid = switch (seq_type) {
        .dna => "ATGC",
        .rna => "AUGC",
        .protein => "ACDEFGHIKLMNPQRSTVWY",
    };

    for (seq) |c| {
        const upper = std.ascii.toUpper(c);
        for (valid) |v| {
            if (upper == v) {
                try result.append(upper);
                break;
            }
        }
    }

    return result.toOwnedSlice();
}

fn complementStrand(allocator: std.mem.Allocator, seq: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, seq.len);
    for (seq, 0..) |base, i| {
        result[i] = switch (base) {
            'A' => 'T',
            'T' => 'A',
            'G' => 'C',
            'C' => 'G',
            else => 'N',
        };
    }
    return result;
}

fn transcribeToRna(allocator: std.mem.Allocator, dna: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, dna.len);
    for (dna, 0..) |base, i| {
        result[i] = if (base == 'T') 'U' else base;
    }
    return result;
}

fn rnaToDna(allocator: std.mem.Allocator, rna: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, rna.len);
    for (rna, 0..) |base, i| {
        result[i] = if (base == 'U') 'T' else base;
    }
    return result;
}

const GcResult = struct { count: usize, total: usize, at: usize };

fn countGC(seq: []const u8) GcResult {
    var gc: usize = 0;
    var at: usize = 0;
    for (seq) |base| {
        switch (base) {
            'G', 'C' => gc += 1,
            'A', 'T' => at += 1,
            else => {},
        }
    }
    return .{ .count = gc, .total = gc + at, .at = at };
}

fn dnaMolecularWeight(seq: []const u8) f64 {
    const weights = [_]f64{ 331.2, 322.2, 347.2, 307.2 }; // A, T, G, C
    var mw: f64 = 0.0;
    for (seq) |base| {
        const w = switch (base) {
            'A' => @as(usize, 0),
            'T' => @as(usize, 1),
            'G' => @as(usize, 2),
            'C' => @as(usize, 3),
            else => continue,
        };
        mw += weights[w];
    }
    // Subtract water for phosphodiester bonds
    if (seq.len > 0) {
        mw -= @as(f64, @floatFromInt(seq.len - 1)) * 18.015;
    }
    return mw;
}

fn proteinMolecularWeight(seq: []const u8) f64 {
    // Average amino acid weights
    const weights = std.StaticStringMap(f64).initComptime(.{
        .{"A", 89.09},  .{"C", 121.16}, .{"D", 133.10}, .{"E", 147.13},
        .{"F", 165.19}, .{"G", 75.07},  .{"H", 155.16}, .{"I", 131.17},
        .{"K", 146.19}, .{"L", 131.17}, .{"M", 149.21}, .{"N", 132.12},
        .{"P", 115.13}, .{"Q", 146.15}, .{"R", 174.20}, .{"S", 105.09},
        .{"T", 119.12}, .{"V", 117.15}, .{"W", 204.23}, .{"Y", 181.19},
    });

    var mw: f64 = 0.0;
    for (seq) |aa| {
        const key = [_]u8{aa};
        if (weights.get(&key)) |w| {
            mw += w;
        }
    }
    // Subtract water for peptide bonds
    if (seq.len > 0) {
        mw -= @as(f64, @floatFromInt(seq.len - 1)) * 18.015;
    }
    return mw;
}

const TernaryResult = struct { purines: usize, pyrimidines: usize, balance: isize };

fn ternarySignature(seq: []const u8) TernaryResult {
    var purines: usize = 0;
    var pyrimidines: usize = 0;
    for (seq) |base| {
        if (base == 'A' or base == 'G') {
            purines += 1;
        } else if (base == 'T' or base == 'C') {
            pyrimidines += 1;
        }
    }
    const balance: isize = @as(isize, @intCast(purines)) - @as(isize, @intCast(pyrimidines));
    return .{ .purines = purines, .pyrimidines = pyrimidines, .balance = balance };
}

fn isFibonacci(n: usize) bool {
    for (FIBONACCI) |f| {
        if (f == n) return true;
    }
    return false;
}

fn translateToProtein(allocator: std.mem.Allocator, dna: []const u8) ![]u8 {
    var result = std.array_list.Managed(u8).init(allocator);

    const rna = try transcribeToRna(allocator, dna);
    defer allocator.free(rna);

    for (0..rna.len / 3) |i| {
        const start = i * 3;
        if (start + 3 > rna.len) break;
        const codon = rna[start..start+3];
        const aa = getCodonAminoAcid(codon);
        if (aa == '*') break; // STOP
        if (aa != 0 and aa != 'X') {
            try result.append(aa);
        }
    }

    return result.toOwnedSlice();
}

fn getCodonAminoAcid(codon: []const u8) u8 {
    if (codon.len < 3) return 0;
    const c = codon[0..3];
    // RNA codon table (simplified)
    if (c[0] == 'U') {
        if (c[1] == 'U') {
            if (c[2] == 'U' or c[2] == 'C') return 'F';
            if (c[2] == 'A' or c[2] == 'G') return 'L';
        } else if (c[1] == 'C') {
            return 'S';
        } else if (c[1] == 'A') {
            if (c[2] == 'U' or c[2] == 'C') return 'Y';
            if (c[2] == 'A' or c[2] == 'G') return '*';
        } else if (c[1] == 'G') {
            if (c[2] == 'U' or c[2] == 'C') return 'C';
            if (c[2] == 'A') return '*';
            if (c[2] == 'G') return 'W';
        }
    } else if (c[0] == 'C') {
        if (c[1] == 'U') {
            return 'L';
        } else if (c[1] == 'C') {
            return 'P';
        } else if (c[1] == 'A') {
            return 'H';
        } else if (c[1] == 'G') {
            return 'R';
        }
    } else if (c[0] == 'A') {
        if (c[1] == 'U') {
            if (c[2] == 'U' or c[2] == 'C' or c[2] == 'A') return 'I';
            if (c[2] == 'G') return 'M';
        } else if (c[1] == 'C') {
            return 'T';
        } else if (c[1] == 'A') {
            if (c[2] == 'U' or c[2] == 'C') return 'N';
            if (c[2] == 'A' or c[2] == 'G') return 'K';
        } else if (c[1] == 'G') {
            if (c[2] == 'U' or c[2] == 'C') return 'S';
            if (c[2] == 'A' or c[2] == 'G') return 'R';
        }
    } else if (c[0] == 'G') {
        if (c[1] == 'U') {
            return 'V';
        } else if (c[1] == 'C') {
            return 'A';
        } else if (c[1] == 'A') {
            if (c[2] == 'U' or c[2] == 'C') return 'D';
            if (c[2] == 'A' or c[2] == 'G') return 'E';
        } else if (c[1] == 'G') return 'G';
    }
    return 'X';
}

fn getCodonAminoAcidName(codon: *const [3]u8) []const u8 {
    const aa = getCodonAminoAcid(codon);
    return switch (aa) {
        'A' => "Alanine",
        'C' => "Cysteine",
        'D' => "Aspartic acid",
        'E' => "Glutamic acid",
        'F' => "Phenylalanine",
        'G' => "Glycine",
        'H' => "Histidine",
        'I' => "Isoleucine",
        'K' => "Lysine",
        'L' => "Leucine",
        'M' => "Methionine",
        'N' => "Asparagine",
        'P' => "Proline",
        'Q' => "Glutamine",
        'R' => "Arginine",
        'S' => "Serine",
        'T' => "Threonine",
        'V' => "Valine",
        'W' => "Tryptophan",
        'Y' => "Tyrosine",
        '*' => "STOP",
        else => "Unknown",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELP
// ═══════════════════════════════════════════════════════════════════════════════

fn showBioHelp() !void {
    std.debug.print("\n{s}╔══════════════════════════════════════════════════════════════════╗{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}║              {s}SACRED BIOLOGY v14.0{s}                         ║{s}\n", .{ GOLDEN, CYAN, RESET, RESET });
    std.debug.print("{s}║         {s}DNA is a double golden spiral (34 Å pitch){s}            ║{s}\n", .{ GOLDEN, WHITE, RESET, RESET });
    std.debug.print("{s}║              {s}φ² + 1/φ² = 3 = TRINITY{s}                           ║{s}\n", .{ GOLDEN, GOLDEN, RESET, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════════════╝{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("{s}SUBCOMMANDS{s}\n", .{ WHITE, RESET });
    std.debug.print("{s}─────────────────────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}tri bio dna <sequence>{s}       DNA analysis with sacred mathematics\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri bio rna <sequence>{s}       RNA analysis with sacred mathematics\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri bio protein <sequence>{s}   Protein analysis (1-letter codes)\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri bio phi-genome{s}          Show sacred genome patterns\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri bio codon <codon>{s}       Look up codon → amino acid\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri bio abiogenesis{s}         Show origin of life formulas (v12.1)\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri bio baryogenesis{s}        Show matter-antimatter asymmetry (v13.0, 20 formulas)\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri bio pyramid{s}             Show full reality pyramid (v12.2, 140 formulas)\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri bio help{s}                Show this help message\n", .{ GREEN, RESET });

    std.debug.print("\n{s}EXAMPLES{s}\n", .{ WHITE, RESET });
    std.debug.print("{s}─────────────────────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}tri bio dna ATGCGTAA{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}tri bio rna AUGCCAUAA{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}tri bio protein MVHLTPEEKSAVTALWGKVNVDEVGGEALGRLLVVYPWTQRFFESFGDLS{s}\n", .{ GRAY, RESET });
    std.debug.print("                      {s}TPVHPNA\xedHLDKATFAVTHSDLGAD...{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}tri bio codon AUG{s}\n\n", .{ GRAY, RESET });

    std.debug.print("{s}SACRED BIOLOGY INSIGHTS{s}\n", .{ WHITE, RESET });
    std.debug.print("{s}─────────────────────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}• DNA helix pitch: 34 {s}Å{s} {s}(≈ φ⁴){s}\n", .{ GRAY, GOLDEN, RESET, GOLDEN, RESET });
    std.debug.print("  {s}• Bases per turn: 10 {s}(sacred number){s}\n", .{ GRAY, GOLDEN, RESET });
    std.debug.print("  {s}• A-T: 2 H-bonds, G-C: 3 H-bonds {s}(ternary ±1){s}\n", .{ GRAY, GOLDEN, RESET });
    std.debug.print("  {s}• 64 codons → 20 amino acids = 3⁴ {s}(sacred){s}\n", .{ GRAY, GOLDEN, RESET });
    std.debug.print("  {s}• GC ratio close to φ indicates sacred genome{s}\n\n", .{ GRAY, RESET });

    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}
