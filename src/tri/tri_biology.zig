// ═══════════════════════════════════════════════════════════════════════════════
// SACRED BIOLOGY v14.0 — CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════
// DNA, RNA, and protein analysis with sacred mathematics
// φ² + 1/φ² = 3 = TRINITY | DNA is a double golden spiral (34 Å pitch)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const sacred_formula = @import("math/sacred_formula.zig");

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
    std.debug.print("  {s}Length  :{s} {s}{}{s} bp\n", .{ GRAY, RESET, GOLDEN, len, RESET });

    // GC content
    const gc_pct = if (gc.total > 0) @as(f64, @floatFromInt(gc.count)) / @as(f64, @floatFromInt(gc.total)) * 100.0 else 0.0;
    const gc_ratio = if (gc.at > 0) @as(f64, @floatFromInt(gc.count)) / @as(f64, @floatFromInt(gc.at)) else 0.0;
    std.debug.print("\n{s}GC CONTENT{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}GC Count   :{s} {} / {} ({d:.1}%)\n", .{ GRAY, RESET, gc.count, gc.total, gc_pct });
    std.debug.print("  {s}GC Ratio   :{s} {d:.3}", .{ GRAY, RESET, gc_ratio });

    // Check if GC ratio is close to φ
    if (@abs(gc_ratio - PHI) < 0.15) {
        std.debug.print(" {s}≈ φ (SACRED!){s}", .{ GOLDEN, RESET });
    }
    std.debug.print("\n");

    // Molecular weight
    std.debug.print("\n{s}MOLECULAR WEIGHT{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}Weight     :{s} {d:.2}} g/mol\n", .{ GRAY, RESET, mw });

    // Sacred formula fit
    std.debug.print("\n{s}SACRED FORMULA FIT{s}\n", .{ WHITE, RESET });
    var buf: [128]u8 = undefined;
    const formula = sacred_formula.formatFormulaString(&buf, fit);
    std.debug.print("  {s}V = {s}{s}{s}\n", .{ GRAY, GOLDEN, formula, RESET });
    std.debug.print("  {s}Computed   :{s} {d:.2}\n", .{ GRAY, RESET, fit.computed });
    std.debug.print("  {s}Target     :{s} {d:.0}\n", .{ GRAY, RESET, @floatFromInt(len) });
    const err_color = if (fit.error_pct < 1.0) GREEN else if (fit.error_pct < 5.0) GOLDEN else RED;
    std.debug.print("  {s}Error      :{s} {s}{d:.3}%{s}\n", .{ GRAY, RESET, err_color, fit.error_pct, RESET });

    // Fibonacci check
    std.debug.print("\n{s}SACRED PROPERTIES{s}\n", .{ WHITE, RESET });
    const is_fib = isFibonacci(len);
    if (is_fib) {
        std.debug.print("  {s}✓ Fibonacci length!{s} ({} is in the sequence)\n", .{ GOLDEN, RESET, len });
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
        std.debug.print("  {s}Length     :{s} {} aa\n", .{ GRAY, RESET, protein.len });
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
    var cleaned_list = std.ArrayList(u8).init(allocator);
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
    std.debug.print("  {s}Length:{s} {s}{}{s} nt\n\n", .{ GRAY, RESET, GOLDEN, len, RESET });

    std.debug.print("{s}SACRED FORMULA FIT{s}\n", .{ WHITE, RESET });
    var buf: [128]u8 = undefined;
    const formula = sacred_formula.formatFormulaString(&buf, fit);
    std.debug.print("  {s}V = {s}{s}{s}\n", .{ GRAY, RESET, GOLDEN, formula, RESET });
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
    var cleaned_list = std.ArrayList(u8).init(allocator);
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
    std.debug.print("  {s}Length  :{s} {s}{}{s} aa\n", .{ GRAY, RESET, GOLDEN, len, RESET });
    std.debug.print("  {s}Weight  :{s} {d:.2} Da\n\n", .{ GRAY, RESET, mw });

    std.debug.print("{s}SACRED FORMULA FIT{s}\n", .{ WHITE, RESET });
    var buf: [128]u8 = undefined;
    const formula = sacred_formula.formatFormulaString(&buf, fit);
    std.debug.print("  {s}V = {s}{s}{s}\n", .{ GRAY, RESET, GOLDEN, formula, RESET });
    std.debug.print("  {s}Error: {d:.3}%{s}\n\n", .{ GRAY, fit.error_pct, RESET });

    const is_fib = isFibonacci(len);
    if (is_fib) {
        std.debug.print("  {s}✓ Fibonacci length!{s} ({} aa)\n\n", .{ GOLDEN, RESET, len });
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
        std.debug.print("  {s}  {s}F{:<3} = {}{s}\n", .{ GRAY, marker, "", f, RESET });
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

    std.debug.print("{s}RNA Codon  : {s}{s}{s}\n", .{ WHITE, RESET, MAGENTA, rna_codon });
    const aa = getCodonAminoAcid(&rna_codon);
    const name = getCodonAminoAcidName(&rna_codon);

    if (std.mem.eql(u8, &rna_codon, "AUG")) {
        std.debug.print("  {s}Amino Acid : {s}M (Methionine) {s}[START]{s}\n", .{ WHITE, RESET, GREEN, RESET, GOLDEN, RESET });
    } else if (std.mem.eql(u8, &rna_codon, "UAA") or std.mem.eql(u8, &rna_codon, "UAG") or std.mem.eql(u8, &rna_codon, "UGA")) {
        std.debug.print("  {s}Amino Acid : {s}* {s}[STOP]{s}\n", .{ WHITE, RESET, RED, RESET, GOLDEN, RESET });
    } else {
        std.debug.print("  {s}Amino Acid : {s}{c} ({s}){s}\n", .{ WHITE, RESET, GREEN, aa, name, RESET });
    }

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

const SeqType = enum { dna, rna, protein };

fn cleanSequence(allocator: std.mem.Allocator, seq: []const u8, comptime seq_type: SeqType) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
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
            'A' => 0, 'T' => 1, 'G' => 2, 'C' => 3,
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
    const weights = std.ComptimeStringMap(f64, .{
        .{"A", 89.09},  .{"C", 121.16}, .{"D", 133.10}, .{"E", 147.13},
        .{"F", 165.19}, .{"G", 75.07},  .{"H", 155.16}, .{"I", 131.17},
        .{"K", 146.19}, .{"L", 131.17}, .{"M", 149.21}, .{"N", 132.12},
        .{"P", 115.13}, .{"Q", 146.15}, .{"R", 174.20}, .{"S", 105.09},
        .{"T", 119.12}, .{"V", 117.15}, .{"W", 204.23}, .{"Y", 181.19},
    });

    var mw: f64 = 0.0;
    for (seq) |aa| {
        if (weights.get(aa[0..1])) |w| {
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
    var result = std.ArrayList(u8).init(allocator);

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

fn getCodonAminoAcid(codon: *const [3]u8) u8 {
    const c = codon.*;
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
    std.debug.print("{s}║{{s}}              {s}SACRED BIOLOGY v14.0{s}                         {s}║{{s}}\n", .{ GOLDEN, RESET, CYAN, RESET, GOLDEN, RESET });
    std.debug.print("{s}║{{s}}         DNA is a double golden spiral (34 Å pitch)            {s}║{{s}}\n", .{ GOLDEN, RESET, WHITE, GOLDEN, RESET });
    std.debug.print("{s}║{{s}}              φ² + 1/φ² = 3 = TRINITY                           {s}║{{s}}\n", .{ GOLDEN, RESET, GOLDEN, GOLDEN, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════════════╝{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("{s}SUBCOMMANDS{s}\n", .{ WHITE, RESET });
    std.debug.print("{s}─────────────────────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}tri bio dna <sequence>{{s}}       DNA analysis with sacred mathematics\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri bio rna <sequence>{{s}}       RNA analysis with sacred mathematics\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri bio protein <sequence>{{s}}   Protein analysis (1-letter codes)\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri bio phi-genome{{s}}          Show sacred genome patterns\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri bio codon <codon>{{s}}       Look up codon → amino acid\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri bio help{{s}}                Show this help message\n", .{ GREEN, RESET });

    std.debug.print("\n{s}EXAMPLES{s}\n", .{ WHITE, RESET });
    std.debug.print("{s}─────────────────────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}tri bio dna ATGCGTAA{{s}}\n", .{ GRAY, RESET });
    std.debug.print("  {s}tri bio rna AUGCCAUAA{{s}}\n", .{ GRAY, RESET });
    std.debug.print("  {s}tri bio protein MVHLTPEEKSAVTALWGKVNVDEVGGEALGRLLVVYPWTQRFFESFGDLS{{s}}\n", .{ GRAY, RESET });
    std.debug.print("                      {s}TPVHPNA\xedHLDKATFAVTHSDLGAD...{{s}}\n", .{ GRAY, RESET });
    std.debug.print("  {s}tri bio codon AUG{{s}}\n\n", .{ GRAY, RESET });

    std.debug.print("{s}SACRED BIOLOGY INSIGHTS{s}\n", .{ WHITE, RESET });
    std.debug.print("{s}─────────────────────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}•{{s}} DNA helix pitch: 34 {s}Å{{s}} {s}(≈ φ⁴){{s}}\n", .{ GRAY, RESET, GOLDEN, RESET, GOLDEN, RESET });
    std.debug.print("  {s}•{{s}} Bases per turn: 10 {s}(sacred number){{s}}\n", .{ GRAY, RESET, GOLDEN, RESET });
    std.debug.print("  {s}•{{s}} A-T: 2 H-bonds, G-C: 3 H-bonds {s}(ternary ±1){{s}}\n", .{ GRAY, RESET, GOLDEN, RESET });
    std.debug.print("  {s}•{{s}} 64 codons → 20 amino acids = 3⁴ {s}(sacred){{s}}\n", .{ GRAY, RESET, GOLDEN, RESET });
    std.debug.print("  {s}•{{s}} GC ratio close to φ indicates sacred genome\n\n", .{ GRAY, RESET });

    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}
