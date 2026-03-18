// @origin(spec:tri_neuro.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED NEUROSCIENCE v16.0 — CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════
// Brain waves, consciousness, neural architecture with sacred mathematics
// Ψ = n × 3^k × π^m × φ^p × e^q | The observer emerges to witness
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
const PURPLE = colors.PURPLE;
const RESET = colors.RESET;

// Sacred constants
const PHI = 1.6180339887498948482;
const PHI_SQ = PHI * PHI;
const PHI_INV = 1.0 / PHI;
const PI = 3.14159265358979323846;
const E = 2.71828182845904523536;

// Fibonacci and Lucas sequences
const FIBONACCI = [_]usize{ 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987 };
const LUCAS = [_]usize{ 2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123, 199, 322 };

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

const BrainWave = struct {
    name: []const u8,
    symbol: []const u8,
    freq_min: f64,
    freq_max: f64,
    freq_peak: f64,
    sacred_freq: f64,
    state: []const u8,
    phi_relation: []const u8,
};

const BrainRegion = struct {
    id: []const u8,
    name: []const u8,
    phi_index: f64,
    fibonacci_index: ?usize,
    sacred_function: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DATA TABLES
// ═══════════════════════════════════════════════════════════════════════════════

const BRAIN_WAVES = [_]BrainWave{
    .{ .name = "Delta", .symbol = "Δ", .freq_min = 0.5, .freq_max = 4.0, .freq_peak = 2.0, .sacred_freq = PHI, .state = "Deep sleep, unconscious", .phi_relation = "φ⁻³ × 10 ≈ 1.62 Hz" },
    .{ .name = "Theta", .symbol = "θ", .freq_min = 4.0, .freq_max = 8.0, .freq_peak = 6.0, .sacred_freq = PHI * 5.0, .state = "Meditation, creativity, REM", .phi_relation = "φ × 5 ≈ 8.09 Hz" },
    .{ .name = "Alpha", .symbol = "α", .freq_min = 8.0, .freq_max = 13.0, .freq_peak = 10.0, .sacred_freq = 13.0, .state = "Relaxed awareness, flow", .phi_relation = "Fibonacci 8, 13 Hz" },
    .{ .name = "Beta", .symbol = "β", .freq_min = 13.0, .freq_max = 30.0, .freq_peak = 20.0, .sacred_freq = PHI * 20.0, .state = "Active thinking, focus", .phi_relation = "φ × 20 ≈ 32.36 Hz" },
    .{ .name = "Gamma", .symbol = "γ", .freq_min = 30.0, .freq_max = 100.0, .freq_peak = 40.0, .sacred_freq = PHI_SQ * 16.0, .state = "Peak performance, insight", .phi_relation = "φ² × 16 ≈ 41.89 Hz" },
};

const BRAIN_REGIONS = [_]BrainRegion{
    .{ .id = "hippocampus", .name = "Hippocampus", .phi_index = 0.85, .fibonacci_index = 13, .sacred_function = "Memory encoding via φ-spiral" },
    .{ .id = "thalamus", .name = "Thalamus", .phi_index = 0.81, .fibonacci_index = null, .sacred_function = "Trinitary (3^n) sensory gating" },
    .{ .id = "v1", .name = "Primary Visual Cortex (V1)", .phi_index = 0.91, .fibonacci_index = 34, .sacred_function = "Φ₁₇ₐ retinotopic sacred geometry" },
    .{ .id = "dlpfc", .name = "Dorsolateral Prefrontal Cortex", .phi_index = 0.88, .fibonacci_index = 21, .sacred_function = "Executive function via φ-efficiency" },
    .{ .id = "cerebellum", .name = "Cerebellum", .phi_index = 0.89, .fibonacci_index = 89, .sacred_function = "Motor precision via φ-timing" },
    .{ .id = "precuneus", .name = "Precuneus", .phi_index = 0.83, .fibonacci_index = 144, .sacred_function = "Consciousness, internal awareness" },
    .{ .id = "amygdala", .name = "Amygdala", .phi_index = 0.78, .fibonacci_index = null, .sacred_function = "Emotional processing, sacred fire" },
    .{ .id = "acc", .name = "Anterior Cingulate Cortex", .phi_index = 0.79, .fibonacci_index = null, .sacred_function = "Conflict monitoring, sacred balance" },
    .{ .id = "pcc", .name = "Posterior Cingulate Cortex", .phi_index = 0.80, .fibonacci_index = null, .sacred_function = "Default mode hub, self-reference" },
    .{ .id = "m1", .name = "Primary Motor Cortex", .phi_index = 0.86, .fibonacci_index = 5, .sacred_function = "Motor execution via φ-optimization" },
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runNeuroCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try showNeuroHelp();
        return;
    }

    const subcommand = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcommand, "waves")) {
        try cmdWaves(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "consciousness")) {
        try cmdConsciousness(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "regions")) {
        try cmdRegions(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "network")) {
        try cmdNetwork(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "synapse")) {
        try cmdSynapse(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "neurons")) {
        try cmdNeurons(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try showNeuroHelp();
    } else {
        std.debug.print("{s}Unknown neuro command: {s}{s}\n\n", .{ RED, subcommand, RESET });
        try showNeuroHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN WAVES COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdWaves(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED NEUROSCIENCE v16.0 — BRAIN WAVES{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    if (args.len > 0) {
        // Analyze specific frequency
        const freq_str = args[0];
        const freq = std.fmt.parseFloat(f64, freq_str) catch {
            std.debug.print("{s}Error: Invalid frequency '{s}'{s}\n", .{ RED, freq_str, RESET });
            return;
        };

        std.debug.print("{s}FREQUENCY ANALYSIS{s}\n", .{ WHITE, RESET });
        std.debug.print("  {s}Input:{s} {d:.2} Hz\n\n", .{ GRAY, RESET, freq });

        // Find matching wave
        var matched: bool = false;
        for (BRAIN_WAVES) |wave| {
            if (freq >= wave.freq_min and freq <= wave.freq_max) {
                std.debug.print("  {s}Wave:{s} {s}{s}{s} ({s})\n", .{ GRAY, RESET, PURPLE, wave.name, RESET, wave.symbol });
                std.debug.print("  {s}Range:{s} {d:.1}-{d:.1} Hz (peak: {d:.1} Hz)\n", .{ GRAY, RESET, wave.freq_min, wave.freq_max, wave.freq_peak });
                std.debug.print("  {s}State:{s} {s}\n", .{ GRAY, RESET, wave.state });
                std.debug.print("  {s}Sacred:{s} {d:.2} Hz ({s})\n", .{ GRAY, RESET, wave.sacred_freq, wave.phi_relation });

                const deviation = @abs(freq - wave.sacred_freq) / wave.sacred_freq * 100.0;
                const dev_color = if (deviation < 10.0) GREEN else if (deviation < 20.0) GOLDEN else RED;
                std.debug.print("  {s}Deviation:{s} {s}{d:.1}% from sacred{s}\n", .{ GRAY, RESET, dev_color, deviation, RESET });

                matched = true;
                break;
            }
        }

        if (!matched) {
            std.debug.print("  {s}No standard wave matches this frequency{s}\n", .{ RED, RESET });

            // Check if φ-related
            const phi_patterns = [_]f64{ PHI, PHI * 5.0, PHI * 20.0, PHI_SQ * 16.0 };
            for (phi_patterns) |p| {
                if (@abs(freq - p) / p < 0.1) {
                    std.debug.print("  {s}φ-Pattern detected:{s} {d:.2} ≈ {d:.2} Hz\n", .{ GOLDEN, RESET, freq, p });
                    break;
                }
            }
        }
    } else {
        // Show all brain waves
        std.debug.print("{s}φ-PATTERNED BRAIN WAVES{s}\n\n", .{ WHITE, RESET });

        for (BRAIN_WAVES, 0..) |wave, i| {
            std.debug.print("{s}[{d}] {s}{s} {s}Wave{s}\n", .{ GRAY, i + 1, GOLDEN, wave.symbol, wave.name, RESET });
            std.debug.print("     {s}Frequency:{s} {d:.1}-{d:.1} Hz (peak: {d:.1} Hz)\n", .{ GRAY, RESET, wave.freq_min, wave.freq_max, wave.freq_peak });
            std.debug.print("     {s}Sacred:{s}     {d:.2} Hz\n", .{ GRAY, RESET, wave.sacred_freq });
            std.debug.print("     {s}φ-Relation:{s} {s}\n", .{ GRAY, RESET, wave.phi_relation });
            std.debug.print("     {s}State:{s}     {s}\n", .{ GRAY, RESET, wave.state });
            std.debug.print("\n", .{});
        }

        // Sacred formula for brain waves
        std.debug.print("{s}SACRED FORMULA Ψ = n × 3^k × π^m × φ^p × e^q{s}\n\n", .{ WHITE, RESET });
        std.debug.print("  {s}Δ (Delta):{s}  Ψ = φ⁻³ × 10  ≈ 1.62 Hz  (Deep sleep)\n", .{ GRAY, RESET });
        std.debug.print("  {s}θ (Theta):{s}  Ψ = φ × 5      ≈ 8.09 Hz  (Meditation)\n", .{ GRAY, RESET });
        std.debug.print("  {s}α (Alpha):{s}  Ψ = 13         (Fibonacci) (Flow)\n", .{ GRAY, RESET });
        std.debug.print("  {s}β (Beta):{s}   Ψ = φ × 20     ≈ 32.36 Hz (Focus)\n", .{ GRAY, RESET });
        std.debug.print("  {s}γ (Gamma):{s}  Ψ = φ² × 16    ≈ 41.89 Hz (Peak)\n", .{ GRAY, RESET });
    }

    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSCIOUSNESS COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdConsciousness(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED NEUROSCIENCE v16.0 — CONSCIOUSNESS Ψ{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    // Default values if not provided
    var complexity: f64 = 50.0; // C: Neural complexity (0-100)
    var time_int: f64 = 2.0; // t: Time integration (0-5)
    var energy: f64 = 20.0; // E: Energy barrier (0-100)

    if (args.len >= 3) {
        complexity = std.fmt.parseFloat(f64, args[0]) catch complexity;
        time_int = std.fmt.parseFloat(f64, args[1]) catch time_int;
        energy = std.fmt.parseFloat(f64, args[2]) catch energy;
    } else if (args.len > 0) {
        std.debug.print("{s}Usage: tri neuro consciousness <C> <t> <E>{s}\n", .{ RED, RESET });
        std.debug.print("  C: Neural complexity (0-100)\n", .{});
        std.debug.print("  t: Time integration (0-5)\n", .{});
        std.debug.print("  E: Energy barrier (0-100)\n\n", .{});
        std.debug.print("{s}Using default values: C=50, t=2, E=20{s}\n\n", .{ GOLDEN, RESET });
    }

    // Ψ = C × φ^t × e^(-E/RT)
    const R = 8.314; // Gas constant (scaled)
    const T = 1.0; // Temperature factor
    const psi = complexity * std.math.pow(f64, PHI, time_int) * std.math.exp(-energy / (R * T));
    const clamped = @max(0.0, @min(100.0, psi));

    std.debug.print("{s}CONSCIOUSNESS COMPUTATION{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}Formula:{s} Ψ = C × φ^t × e^(-E/RT)\n", .{ GRAY, RESET });
    std.debug.print("  {s}C (Complexity):{s} {d:.1}\n", .{ GRAY, RESET, complexity });
    std.debug.print("  {s}t (Time):{s}      {d:.1}\n", .{ GRAY, RESET, time_int });
    std.debug.print("  {s}E (Energy):{s}    {d:.1}\n", .{ GRAY, RESET, energy });
    std.debug.print("  {s}φ (Golden):{s}    {d:.5}\n\n", .{ GRAY, RESET, PHI });

    std.debug.print("  {s}Ψ (Consciousness):{s} {s}{d:.2}{s}\n", .{ GRAY, RESET, GOLDEN, clamped, RESET });

    // Determine state
    const state = getStateName(clamped);
    const dominant = getDominantWave(clamped);
    std.debug.print("  {s}State:{s}          {s}\n", .{ GRAY, RESET, state });
    std.debug.print("  {s}Dominant Wave:{s}  {s}\n", .{ GRAY, RESET, dominant });

    // Check if sacred
    const sacred_level = PHI * 10.0; // 16.18
    const is_sacred = @abs(clamped - sacred_level) < 5.0;
    if (is_sacred) {
        std.debug.print("\n  {s}✓ SACRED CONSCIOUSNESS! Ψ ≈ φ × 10{s}\n", .{ GOLDEN, RESET });
    } else if (clamped > 80) {
        std.debug.print("\n  {s}✓ Peak consciousness achieved!{s}\n", .{ PURPLE, RESET });
    }

    // Show interpretation
    std.debug.print("\n{s}INTERPRETATION{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}\n", .{interpretConsciousness(clamped)});

    // Sacred formula fit
    const fit = sacred_formula.fitSacredFormula(clamped);
    var buf: [128]u8 = undefined;
    const formula_str = sacred_formula.formatFormulaString(&buf, fit);
    std.debug.print("\n{s}SACRED FORMULA FIT{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}Fit:{s} {s}\n", .{ GRAY, RESET, formula_str });
    std.debug.print("  {s}Error:{s} {d:.3}%\n", .{ GRAY, RESET, fit.error_pct });

    std.debug.print("\n", .{});
}

fn getStateName(psi: f64) []const u8 {
    if (psi < 10) return "Deep Sleep (Unconscious)";
    if (psi < 20) return "Dreaming (REM)";
    if (psi < 35) return "Meditation";
    if (psi < 50) return "Relaxed Awareness (Alpha)";
    if (psi < 70) return "Active Thinking (Beta)";
    if (psi < 85) return "Peak Performance (Gamma)";
    return "Unity Consciousness (Transcendent)";
}

fn getDominantWave(psi: f64) []const u8 {
    if (psi < 10) return "Δ Delta";
    if (psi < 30) return "θ Theta";
    if (psi < 50) return "α Alpha";
    if (psi < 70) return "β Beta";
    return "γ Gamma";
}

fn interpretConsciousness(psi: f64) []const u8 {
    if (psi < 10) return "Deep unconscious state. Minimal neural activity.";
    if (psi < 20) return "Dreaming state. Theta activity, emotional processing.";
    if (psi < 35) return "Meditative state. Deep relaxation, creativity.";
    if (psi < 50) return "Relaxed awareness. Alpha dominance, flow accessible.";
    if (psi < 70) return "Active thinking. Beta waves, analytical processing.";
    if (psi < 85) return "Peak performance. Gamma synchronization, insight.";
    return "Unity consciousness. Transcendent state, all-is-one awareness.";
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN REGIONS COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdRegions(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED NEUROSCIENCE v16.0 — BRAIN REGIONS{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    // Sort by φ-index (descending)
    var sorted_regions = BRAIN_REGIONS;
    std.sort.block(BrainRegion, &sorted_regions, {}, struct {
        fn lessThan(ctx: void, a: BrainRegion, b: BrainRegion) bool {
            _ = ctx;
            return a.phi_index > b.phi_index; // Descending
        }
    }.lessThan);

    std.debug.print("{s}SACRED REGIONS (φ-index > 0.8){s}\n\n", .{ WHITE, RESET });

    var sacred_count: usize = 0;
    for (sorted_regions) |region| {
        const is_sacred = region.phi_index > 0.8;
        if (is_sacred) sacred_count += 1;

        const color = if (is_sacred) GOLDEN else GRAY;
        std.debug.print("{s}  {s}{s}{s} φ-index: {d:.2}", .{ color, RESET, region.name, color, region.phi_index });

        if (region.fibonacci_index) |fib| {
            std.debug.print(" {s}(Fibonacci: {d}){s}", .{ GOLDEN, fib, RESET });
        }

        if (is_sacred) {
            std.debug.print(" {s}[SACRED]{s}", .{ GOLDEN, RESET });
        }

        std.debug.print("\n", .{});
        std.debug.print("      {s}{s}\n", .{ GRAY, region.sacred_function });
        std.debug.print("\n", .{});
    }

    std.debug.print("{s}SUMMARY{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}Total regions:{s} {d}\n", .{ GRAY, RESET, BRAIN_REGIONS.len });
    std.debug.print("  {s}Sacred regions (φ > 0.8):{s} {s}{d}{s}\n", .{ GRAY, RESET, GOLDEN, sacred_count, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEURAL NETWORK COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdNetwork(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED NEUROSCIENCE v16.0 — NEURAL ARCHITECTURE{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    if (args.len == 0) {
        // Show sacred architectures
        std.debug.print("{s}SACRED NEURAL ARCHITECTURES{s}\n\n", .{ WHITE, RESET });

        std.debug.print("{s}GOLDEN MLP (Fibonacci Layers){s}\n", .{ GOLDEN, RESET });
        std.debug.print("  {s}784 → 144 → 233 → 10{s}\n", .{ GRAY, RESET });
        std.debug.print("  Hidden layers follow Fibonacci sequence\n", .{});
        std.debug.print("  φ-index: {d:.2}\n\n", .{0.91});

        std.debug.print("{s}TRINITARY NETWORK (3^n){s}\n", .{ PURPLE, RESET });
        std.debug.print("  {s}3 → 9 → 27 → 9 → 3{s}\n", .{ GRAY, RESET });
        std.debug.print("  Symmetric expansion by powers of 3\n", .{});
        std.debug.print("  φ-index: {d:.2}\n\n", .{0.88});

        std.debug.print("{s}φ-OPTIMIZED CNN{s}\n", .{ CYAN, RESET });
        std.debug.print("  {s}Filter counts: φ^n × 64{s}\n", .{ GRAY, RESET });
        std.debug.print("  Kernel sizes follow φ ratio\n", .{});
        std.debug.print("  φ-index: {d:.2}\n\n", .{0.89});

        return;
    }

    // Analyze provided layers
    std.debug.print("{s}NETWORK ANALYSIS{s}\n", .{ WHITE, RESET });

    var is_fibonacci = true;
    var is_trinitary = true;
    var fib_count: usize = 0;
    var trinary_count: usize = 0;

    for (args) |layer_str| {
        const layer = std.fmt.parseInt(usize, layer_str, 10) catch {
            std.debug.print("  {s}Error: Invalid layer size '{s}'{s}\n", .{ RED, layer_str, RESET });
            is_fibonacci = false;
            is_trinitary = false;
            break;
        };

        // Check Fibonacci
        if (isFibonacci(layer)) {
            fib_count += 1;
        } else {
            is_fibonacci = false;
        }

        // Check Trinitary (3^n)
        const log3 = std.math.log(f64, 3.0, @floatFromInt(layer));
        if (@abs(log3 - @round(log3)) < 0.1) {
            trinary_count += 1;
        } else {
            is_trinitary = false;
        }
    }

    const phi_index = @as(f64, @floatFromInt(fib_count + trinary_count)) / @as(f64, @floatFromInt(args.len * 2));

    std.debug.print("  {s}Layers:{s} ", .{ GRAY, RESET });
    for (args, 0..) |layer, i| {
        if (i > 0) std.debug.print(" → ", .{});
        const color = if (isFibonacci(std.fmt.parseInt(usize, layer, 10) catch 0)) GOLDEN else GRAY;
        std.debug.print("{s}{s}{s}", .{ color, layer, RESET });
    }
    std.debug.print("\n", .{});

    std.debug.print("  {s}Fibonacci:{s}  ", .{ GRAY, RESET });
    if (is_fibonacci) {
        std.debug.print("{s}✓ All layers are Fibonacci numbers{s}\n", .{ GOLDEN, RESET });
    } else {
        std.debug.print("{s}✗ {d}/{} Fibonacci{s}\n", .{ RED, fib_count, args.len, RESET });
    }

    std.debug.print("  {s}Trinitary:{s}  ", .{ GRAY, RESET });
    if (is_trinitary) {
        std.debug.print("{s}✓ All layers are 3^n{s}\n", .{ PURPLE, RESET });
    } else {
        std.debug.print("{s}✗ {d}/{} are 3^n{s}\n", .{ RED, trinary_count, args.len, RESET });
    }

    std.debug.print("  {s}φ-index:{s}    {d:.2}", .{ GRAY, RESET, phi_index });
    if (phi_index > 0.8) {
        std.debug.print(" {s}[SACRED]{s}\n", .{ GOLDEN, RESET });
    } else {
        std.debug.print("\n", .{});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SYNAPSE COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdSynapse(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED NEUROSCIENCE v16.0 — SYNAPTIC TRANSMISSION{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    const phases = [_]struct { name: []const u8, duration: f64, sacred: f64 }{
        .{ .name = "Action potential arrival", .duration = 0.1, .sacred = PHI_INV * PHI_INV },
        .{ .name = "Calcium influx", .duration = 0.2, .sacred = PHI_INV * PHI_INV },
        .{ .name = "Vesicle fusion", .duration = 0.1, .sacred = PHI_INV * PHI_INV * PHI_INV },
        .{ .name = "Diffusion across cleft", .duration = 0.4, .sacred = PHI_INV * PHI_INV },
        .{ .name = "Receptor binding", .duration = 0.3, .sacred = PHI_INV },
        .{ .name = "Ion channel opening", .duration = 0.5, .sacred = PHI_INV },
        .{ .name = "Reuptake/degradation", .duration = 2.0, .sacred = PHI },
        .{ .name = "Refractory period", .duration = 2.0, .sacred = PHI },
    };

    std.debug.print("{s}SYNAPTIC TRANSMISSION PHASES{s}\n\n", .{ WHITE, RESET });

    var total_delay: f64 = 0;
    for (phases, 0..) |phase, i| {
        std.debug.print("{s}[{d}] {s}{s}\n", .{ GRAY, i + 1, GOLDEN, phase.name });
        std.debug.print("     Duration: {d:.1} ms", .{phase.duration});
        std.debug.print(" {s}(≈ {d:.3} φ){s}\n", .{ GRAY, phase.sacred, RESET });
        total_delay += phase.duration;
    }

    const sacred_delay = PHI * 10.0; // 16.18 ms
    const is_sacred = @abs(total_delay - sacred_delay) / sacred_delay < 0.1;

    std.debug.print("\n{s}SUMMARY{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}Total delay:{s}   {d:.2} ms\n", .{ GRAY, RESET, total_delay });
    std.debug.print("  {s}Sacred delay:{s}  {d:.2} ms (φ × 10)\n", .{ GRAY, RESET, sacred_delay });

    if (is_sacred) {
        std.debug.print("  {s}Status:{s}        {s}✓ SACRED TIMING!{s}\n", .{ GRAY, RESET, GOLDEN, RESET });
    } else {
        const deviation = @abs(total_delay - sacred_delay) / sacred_delay * 100.0;
        std.debug.print("  {s}Status:{s}        {s}✗ {d:.1}% from sacred{s}\n", .{ GRAY, RESET, RED, deviation, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEURONS COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdNeurons(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED NEUROSCIENCE v16.0 — HUMAN BRAIN STATISTICS{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("{s}SACRED CONSTANTS{s}\n\n", .{ WHITE, RESET });

    std.debug.print("  {s}Neurons (approx):{s}    {s}8.6 × 10^10{s}\n", .{ GRAY, RESET, GOLDEN, RESET });
    std.debug.print("  {s}Synapses per neuron:{s} ~{s}φ^5 × 1000 ≈ 12,000{s}\n", .{ GRAY, RESET, GOLDEN, RESET });
    std.debug.print("  {s}Total synapses:{s}      ~10^15 (quadrillion)\n", .{ GRAY, RESET });
    std.debug.print("  {s}Brain mass:{s}          ~1.4 kg (≈ φ × 0.86 kg)\n\n", .{ GRAY, RESET });

    std.debug.print("{s}SACRED TIMING{s}\n\n", .{ WHITE, RESET });

    std.debug.print("  {s}Action potential:{s}   1-2 ms (≈ φ ms)\n", .{ GRAY, RESET });
    std.debug.print("  {s}Synaptic delay:{s}      0.3-0.5 ms (≈ 1/φ² ms)\n", .{ GRAY, RESET });
    std.debug.print("  {s}Refractory period:{s}   2 ms (≈ φ ms)\n", .{ GRAY, RESET });
    std.debug.print("  {s}Conduction velocity:{s} ~{d:.1} m/s (φ × 100)\n\n", .{ GRAY, RESET, PHI * 100.0 });

    std.debug.print("{s}SACRED GEOMETRY{s}\n\n", .{ WHITE, RESET });

    std.debug.print("  {s}Hippocampus place cells:{s} φ-grid spacing\n", .{ GRAY, RESET });
    std.debug.print("  {s}Orientation columns:{s}  137.5° (golden angle)\n", .{ GRAY, RESET });
    std.debug.print("  {s}Cortical magnification:{s} φ² in fovea\n", .{ GRAY, RESET });
    std.debug.print("  {s}Ocular dominance:{s}     φ ratio between eyes\n\n", .{ GRAY, RESET });

    std.debug.print("{s}CONSCIOUSNESS FORMULA{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}Ψ = C × φ^t × e^(-E/RT){s}\n\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}Where:{s}\n", .{ GRAY, RESET });
    std.debug.print("    Ψ = Consciousness level (0-100)\n", .{});
    std.debug.print("    C = Neural complexity (~φ^4 connectivity)\n", .{});
    std.debug.print("    φ = Golden ratio oscillation\n", .{});
    std.debug.print("    t = Time integration depth\n", .{});
    std.debug.print("    E = Energy threshold (~-55mV)\n", .{});
    std.debug.print("    R, T = Thermodynamic factors\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELP
// ═══════════════════════════════════════════════════════════════════════════════

fn showNeuroHelp() !void {
    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}SACRED NEUROSCIENCE v16.0 — THE OBSERVER ARRIVES{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("{s}USAGE{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}tri neuro <command> [args]{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("{s}COMMANDS{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}waves [freq]        {s}Show brain waves (φ-patterned frequencies)\n", .{ GOLDEN, GRAY });
    std.debug.print("  {s}                      If freq provided, analyze specific frequency{s}\n", .{ GRAY, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}consciousness [C t E]{s}Compute consciousness level Ψ\n", .{ GOLDEN, GRAY });
    std.debug.print("  {s}                      C: Neural complexity (0-100, default: 50){s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}                      t: Time integration (0-5, default: 2){s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}                      E: Energy barrier (0-100, default: 20){s}\n", .{ GRAY, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}regions              {s}Show sacred brain regions (φ-index > 0.8){s}\n", .{ GOLDEN, GRAY, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}network [layers...]  {s}Analyze neural network sacredness{s}\n", .{ GOLDEN, GRAY, RESET });
    std.debug.print("  {s}                      Example: tri neuro network 784 144 233 10{s}\n", .{ GRAY, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}synapse              {s}Show synaptic transmission timing{s}\n", .{ GOLDEN, GRAY, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}neurons              {s}Show brain statistics and sacred constants{s}\n", .{ GOLDEN, GRAY, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}help                 {s}Show this help message{s}\n", .{ GOLDEN, GRAY, RESET });

    std.debug.print("\n{s}EXAMPLES{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}tri neuro waves{s}                  {s}Show all brain waves{s}\n", .{ GOLDEN, GRAY, GRAY, RESET });
    std.debug.print("  {s}tri neuro waves 10{s}               {s}Analyze 10 Hz frequency{s}\n", .{ GOLDEN, GRAY, GRAY, RESET });
    std.debug.print("  {s}tri neuro consciousness{s}          {s}Compute with defaults{s}\n", .{ GOLDEN, GRAY, GRAY, RESET });
    std.debug.print("  {s}tri neuro consciousness 70 3 25{s}   {s}Custom consciousness computation{s}\n", .{ GOLDEN, GRAY, GRAY, RESET });
    std.debug.print("  {s}tri neuro network 784 144 233 10{s}  {s}Analyze Golden MLP{s}\n", .{ GOLDEN, GRAY, GRAY, RESET });
    std.debug.print("  {s}tri neuro network 3 9 27 9 3{s}      {s}Analyze Trinitary network{s}\n", .{ GOLDEN, GRAY, GRAY, RESET });

    std.debug.print("\n{s}CONSCIOUSNESS FORMULA{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}Ψ = n × 3^k × π^m × φ^p × e^q{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("{s}BRAIN WAVES (φ-Patterned){s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}Δ Delta:  0.5-4 Hz    ≈ φ           (Deep sleep){s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}θ Theta:  4-8 Hz      ≈ φ × 5       (Meditation){s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}α Alpha:  8-13 Hz     = 8, 13 (Fib)  (Flow){s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}β Beta:   13-30 Hz    ≈ φ × 20      (Focus){s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}γ Gamma:  30-100 Hz   ≈ φ² × 16     (Peak){s}\n", .{ GRAY, RESET });

    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY | THE OBSERVER IS HERE{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

fn isFibonacci(n: usize) bool {
    for (FIBONACCI) |fib| {
        if (n == fib) return true;
    }
    return false;
}

test "isFibonacci" {
    try std.testing.expect(isFibonacci(1));
    try std.testing.expect(isFibonacci(5));
    try std.testing.expect(isFibonacci(13));
    try std.testing.expect(isFibonacci(144));
    try std.testing.expect(!isFibonacci(4));
    try std.testing.expect(!isFibonacci(10));
    try std.testing.expect(!isFibonacci(0));
}

test "FIBONACCI sequence" {
    try std.testing.expectEqual(@as(usize, 1), FIBONACCI[0]);
    try std.testing.expectEqual(@as(usize, 987), FIBONACCI[FIBONACCI.len - 1]);
}
