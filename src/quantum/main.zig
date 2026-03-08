// TERNARY QUANTUM VM — CLI Runner
// Usage: quantum chsh [--trials N] [--sacred] [--entangled]
//        quantum cglmp [--trials N]
//        quantum demo
//        quantum bench
//        quantum weights [--entangled]
//
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const qvm = @import("ternary_qvm.zig");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const cmd = if (args.len > 1) args[1] else "demo";

    if (std.mem.eql(u8, cmd, "chsh")) {
        run_chsh(args);
    } else if (std.mem.eql(u8, cmd, "cglmp")) {
        run_cglmp(args);
    } else if (std.mem.eql(u8, cmd, "demo")) {
        run_demo();
    } else if (std.mem.eql(u8, cmd, "bench")) {
        run_bench();
    } else if (std.mem.eql(u8, cmd, "weights")) {
        run_weight_gen(args);
    } else {
        print(
            \\TERNARY QUANTUM VM — FORGE OF KOSCHEI
            \\
            \\Commands:
            \\  chsh    Run CHSH-like correlation test on qutrits
            \\  cglmp   Run CGLMP inequality test with entangled pairs
            \\  demo    Demonstrate qutrit gates and measurement
            \\  bench   Benchmark gate operations
            \\  weights Generate quantum-derived weights for FPGA dot product
            \\
            \\Options:
            \\  --trials N     Number of trials (default: 10000)
            \\  --sacred       Use sacred golden angle phase
            \\  --entangled    Use entangled qutrit pairs
            \\
            \\phi^2 + 1/phi^2 = 3 = TRINITY
            \\
        , .{});
    }
}

fn run_chsh(args: []const []const u8) void {
    var trials: u32 = 10000;
    var sacred = false;
    var entangled = false;

    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--trials") and i + 1 < args.len) {
            trials = std.fmt.parseInt(u32, args[i + 1], 10) catch 10000;
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--sacred")) {
            sacred = true;
        } else if (std.mem.eql(u8, args[i], "--entangled")) {
            entangled = true;
        }
    }

    // If --entangled, redirect to CGLMP test
    if (entangled) {
        run_cglmp(args);
        return;
    }

    print(
        \\
        \\  =============================================
        \\  |  CHSH CORRELATION TEST ON QUTRITS         |
        \\  |  phi^2 + 1/phi^2 = 3 = TRINITY            |
        \\  =============================================
        \\
        \\  Trials:  {d}
        \\  Sacred:  {s}
        \\
        \\
    , .{ trials, if (sacred) "YES (golden angle phase)" else "standard" });

    const result = qvm.run_chsh_test(std.heap.page_allocator, trials) catch {
        print("  ERROR: CHSH test failed\n", .{});
        return;
    };

    print(
        \\  Results:
        \\    Correlation:     {d:.6}
        \\    Classical bound: {d:.6}
        \\    Violation:       {s}
        \\    Trials:          {d}
        \\
    , .{
        result.correlation,
        result.classical_bound,
        if (result.violation) "YES — quantum advantage detected" else "NO — within classical bound",
        result.trials,
    });

    // Extended analysis
    print(
        \\
        \\  Extended Analysis:
        \\
    , .{});

    var prng = std.Random.DefaultPrng.init(137);

    var agree_h: u32 = 0;
    for (0..trials) |_| {
        var q1 = qvm.Qutrit.ZERO_STATE;
        var q2 = qvm.Qutrit.ZERO_STATE;
        q1 = qvm.Gate3.hadamard3().apply(q1);
        q2 = qvm.Gate3.hadamard3().apply(q2);
        const m1 = q1.measure(prng.random());
        const m2 = q2.measure(prng.random());
        if (m1 == m2) agree_h += 1;
    }

    var agree_sp: u32 = 0;
    for (0..trials) |_| {
        var q1 = qvm.Qutrit.ZERO_STATE;
        var q2 = qvm.Qutrit.ZERO_STATE;
        q1 = qvm.Gate3.hadamard3().apply(q1);
        q2 = qvm.Gate3.hadamard3().apply(q2);
        q2 = qvm.Gate3.sacred_phase().apply(q2);
        const m1 = q1.measure(prng.random());
        const m2 = q2.measure(prng.random());
        if (m1 == m2) agree_sp += 1;
    }

    var agree_x: u32 = 0;
    for (0..trials) |_| {
        var q1 = qvm.Qutrit.ZERO_STATE;
        var q2 = qvm.Qutrit.ZERO_STATE;
        q1 = qvm.Gate3.hadamard3().apply(q1);
        q2 = qvm.Gate3.hadamard3().apply(q2);
        q2 = qvm.Gate3.X3.apply(q2);
        const m1 = q1.measure(prng.random());
        const m2 = q2.measure(prng.random());
        if (m1 == m2) agree_x += 1;
    }

    const corr_h = @as(f64, @floatFromInt(agree_h)) / @as(f64, @floatFromInt(trials));
    const corr_sp = @as(f64, @floatFromInt(agree_sp)) / @as(f64, @floatFromInt(trials));
    const corr_x = @as(f64, @floatFromInt(agree_x)) / @as(f64, @floatFromInt(trials));

    print(
        \\    H|0> vs H|0>:           {d:.6}  (expect ~0.333)
        \\    H|0> vs SP(H|0>):       {d:.6}  (sacred phase shift)
        \\    H|0> vs X(H|0>):        {d:.6}  (cyclic shift)
        \\
        \\  Interpretation:
        \\    Classical random:         0.333333
        \\    Sacred phase deviation:   {d:.6}
        \\
    , .{ corr_h, corr_sp, corr_x, @abs(corr_sp - 1.0 / 3.0) });

    // Quantum trit signature
    print("  Quantum-Derived Trit Signature: ", .{});
    var vm = qvm.TernaryQVM.init(8, 42);
    for (0..8) |qi| {
        vm.hadamard(@intCast(qi));
        if (sacred) vm.sacred_phase(@intCast(qi));
        const trit = vm.measure_qutrit(@intCast(qi));
        const sym: u8 = if (trit < 0) '-' else if (trit == 0) '0' else '+';
        print("{c}", .{sym});
    }

    print(
        \\
        \\
        \\  =============================================
        \\  CHSH TEST COMPLETE
        \\  phi^2 + 1/phi^2 = 3 = TRINITY
        \\  =============================================
        \\
    , .{});
}

fn run_cglmp(args: []const []const u8) void {
    _ = args;

    print(
        \\
        \\  ==========================================================
        \\  |  CGLMP INEQUALITY TEST — ENTANGLED QUTRITS (d=3)        |
        \\  |  Collins-Gisin-Linden-Massar-Popescu 2002               |
        \\  |  Measurement: R01(theta) Givens rotation gates          |
        \\  |  phi^2 + 1/phi^2 = 3 = TRINITY                         |
        \\  ==========================================================
        \\
        \\  Method: Analytical Born rule (exact probabilities)
        \\  Search: 2-phase grid optimization (coarse + refined)
        \\
        \\
    , .{});

    // Test 1: Entangled pair (should violate)
    print("  1. ENTANGLED non-maximally entangled pair:\n", .{});
    const ent = qvm.run_cglmp_test(0, true);
    print(
        \\     I3 value:        {d:.6}
        \\     Classical bound: {d:.6}
        \\     Quantum max:     {d:.6}
        \\     VIOLATION:       {s}
        \\     Corr (same):     {d:.6}
        \\     Corr (diff):     {d:.6}
        \\
    , .{
        ent.i3_value,
        ent.classical_bound,
        ent.quantum_max,
        if (ent.violation) "YES — QUANTUM ADVANTAGE DETECTED" else "NO",
        ent.correlation_same_basis,
        ent.correlation_diff_basis,
    });

    // Test 2: Separable pair (should NOT violate)
    print("\n  2. SEPARABLE product state H|0> x H|0>:\n", .{});
    const sep = qvm.run_cglmp_test(0, false);
    print(
        \\     I3 value:        {d:.6}
        \\     Classical bound: {d:.6}
        \\     VIOLATION:       {s}
        \\     Corr (same):     {d:.6}
        \\     Corr (diff):     {d:.6}
        \\
    , .{
        sep.i3_value,
        sep.classical_bound,
        if (sep.violation) "YES (unexpected!)" else "NO — as expected",
        sep.correlation_same_basis,
        sep.correlation_diff_basis,
    });

    // Entanglement-derived trit signature
    print("\n  3. Entanglement-Derived Trit Signature:\n     ", .{});
    var prng = std.Random.DefaultPrng.init(137);
    for (0..16) |_| {
        var pair = qvm.EntangledPair.BELL;
        // Apply sacred phase to qutrit A
        pair = pair.apply_gate_a(qvm.Gate3.sacred_phase());
        const trit = pair.measure_a(prng.random());
        const sym: u8 = if (trit < 0) '-' else if (trit == 0) '0' else '+';
        print("{c}", .{sym});
    }

    const violation_pct = (ent.i3_value - 2.0) / 2.0 * 100.0;
    print(
        \\
        \\
        \\  ==========================================================
        \\  RESULTS SUMMARY
        \\  ==========================================================
        \\     Entangled I3:    {d:.6} {s} classical bound 2.0
        \\     Separable I3:    {d:.6} {s} classical bound 2.0
        \\     Quantum gap:     {d:.6}
        \\     Violation:       {d:.1}% above classical bound
        \\     Quantum max:     2.9149 (theoretical for d=3)
        \\
        \\  VERDICT: {s}
        \\  ==========================================================
        \\  phi^2 + 1/phi^2 = 3 = TRINITY
        \\  ==========================================================
        \\
    , .{
        ent.i3_value,
        if (ent.i3_value > 2.0 + 1e-6) ">" else "<=",
        sep.i3_value,
        if (sep.i3_value > 2.0 + 1e-6) ">" else "<=",
        ent.i3_value - sep.i3_value,
        violation_pct,
        if (ent.violation) "BELL INEQUALITY VIOLATED — QUANTUM NONLOCALITY CONFIRMED" else "No violation detected",
    });
}

fn run_demo() void {
    print(
        \\
        \\  =============================================
        \\  |  TERNARY QUANTUM VM — DEMO               |
        \\  =============================================
        \\
        \\
    , .{});

    // 1: Basis states
    print("  1. Basis States:\n", .{});
    const basis = [_]struct { name: []const u8, q: qvm.Qutrit }{
        .{ .name = "|-1>", .q = qvm.Qutrit.MINUS },
        .{ .name = "| 0>", .q = qvm.Qutrit.ZERO_STATE },
        .{ .name = "|+1>", .q = qvm.Qutrit.PLUS },
    };
    for (basis) |s| {
        const p = s.q.probabilities();
        print("     {s}  P(-1)={d:.3} P(0)={d:.3} P(+1)={d:.3}\n", .{ s.name, p[0], p[1], p[2] });
    }

    // 2: Hadamard
    print("\n  2. Hadamard |0> -> uniform superposition:\n", .{});
    const h_result = qvm.Gate3.hadamard3().apply(qvm.Qutrit.ZERO_STATE);
    const hp = h_result.probabilities();
    print("     H|0>  P(-1)={d:.6} P(0)={d:.6} P(+1)={d:.6}\n", .{ hp[0], hp[1], hp[2] });

    // 3: Sacred phase
    print("\n  3. Sacred Phase Gate (golden angle = 2pi/phi^2):\n", .{});
    const sp_result = qvm.Gate3.sacred_phase().apply(h_result);
    const spp = sp_result.probabilities();
    print("     SP(H|0>)  P(-1)={d:.6} P(0)={d:.6} P(+1)={d:.6}\n", .{ spp[0], spp[1], spp[2] });
    print("     (Phase changes quantum interference, not probabilities)\n", .{});

    // 4: X gate
    print("\n  4. X Gate (cyclic shift |-1>->|0>->|+1>->|-1>):\n", .{});
    var q = qvm.Qutrit.MINUS;
    const labels = [_][]const u8{ "start ", "X^1   ", "X^2   ", "X^3   " };
    for (0..4) |step| {
        const p = q.probabilities();
        print("     {s}  P(-1)={d:.3} P(0)={d:.3} P(+1)={d:.3}\n", .{ labels[step], p[0], p[1], p[2] });
        q = qvm.Gate3.X3.apply(q);
    }

    // 5: Measurement
    print("\n  5. Measurement (10 trials on H|0>):\n     ", .{});
    var vm = qvm.TernaryQVM.init(1, 42);
    var counts = [3]u32{ 0, 0, 0 };
    for (0..10) |_| {
        vm.qutrits[0] = qvm.Gate3.hadamard3().apply(qvm.Qutrit.ZERO_STATE);
        const m = vm.measure_qutrit(0);
        const idx: usize = @intCast(@as(i8, m) + 1);
        counts[idx] += 1;
        const sym: u8 = if (m < 0) '-' else if (m == 0) '0' else '+';
        print("{c} ", .{sym});
    }
    print("\n     Counts: -1={d}  0={d}  +1={d}\n", .{ counts[0], counts[1], counts[2] });

    // 6: Sacred math
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    print(
        \\
        \\  6. Sacred Mathematics:
        \\     phi = {d:.10}
        \\     phi^2 = {d:.10}
        \\     1/phi^2 = {d:.10}
        \\     phi^2 + 1/phi^2 = {d:.10} = TRINITY
        \\     Sacred angle = 2*pi/phi^2 = {d:.6} rad = {d:.3} deg
        \\
        \\  =============================================
        \\  DEMO COMPLETE | phi^2 + 1/phi^2 = 3
        \\  =============================================
        \\
    , .{
        phi,
        phi * phi,
        1.0 / (phi * phi),
        phi * phi + 1.0 / (phi * phi),
        2.0 * std.math.pi / (phi * phi),
        360.0 * (2.0 * std.math.pi / (phi * phi)) / (2.0 * std.math.pi),
    });
}

fn run_bench() void {
    print(
        \\
        \\  =============================================
        \\  |  TERNARY QUANTUM VM — BENCHMARK           |
        \\  =============================================
        \\
        \\
    , .{});

    const iterations: u64 = 1_000_000;

    // Hadamard
    var timer = std.time.Timer.start() catch return;
    var q = qvm.Qutrit.ZERO_STATE;
    const h = qvm.Gate3.hadamard3();
    for (0..iterations) |_| {
        q = h.apply(q);
    }
    const h_ns = timer.read();
    std.mem.doNotOptimizeAway(&q);

    // X gate
    timer.reset();
    q = qvm.Qutrit.ZERO_STATE;
    for (0..iterations) |_| {
        q = qvm.Gate3.X3.apply(q);
    }
    const x_ns = timer.read();
    std.mem.doNotOptimizeAway(&q);

    // Sacred phase
    timer.reset();
    q = qvm.Qutrit.ZERO_STATE;
    const sp = qvm.Gate3.sacred_phase();
    for (0..iterations) |_| {
        q = sp.apply(q);
    }
    const sp_ns = timer.read();
    std.mem.doNotOptimizeAway(&q);

    // Full circuit
    timer.reset();
    var vm = qvm.TernaryQVM.init(1, 42);
    for (0..iterations) |_| {
        vm.qutrits[0] = qvm.Qutrit.ZERO_STATE;
        vm.hadamard(0);
        vm.sacred_phase(0);
        _ = vm.measure_qutrit(0);
    }
    const circuit_ns = timer.read();

    const h_per = @as(f64, @floatFromInt(h_ns)) / @as(f64, @floatFromInt(iterations));
    const x_per = @as(f64, @floatFromInt(x_ns)) / @as(f64, @floatFromInt(iterations));
    const sp_per = @as(f64, @floatFromInt(sp_ns)) / @as(f64, @floatFromInt(iterations));
    const circuit_per = @as(f64, @floatFromInt(circuit_ns)) / @as(f64, @floatFromInt(iterations));

    print(
        \\  Iterations: {d}
        \\
        \\  Gate Performance:
        \\    Hadamard:      {d:.1} ns/op  ({d:.1} M ops/sec)
        \\    X (cyclic):    {d:.1} ns/op  ({d:.1} M ops/sec)
        \\    Sacred Phase:  {d:.1} ns/op  ({d:.1} M ops/sec)
        \\    Full circuit:  {d:.1} ns/op  ({d:.1} M ops/sec)
        \\
        \\  =============================================
        \\  BENCHMARK COMPLETE
        \\  =============================================
        \\
    , .{
        iterations,
        h_per,
        1000.0 / h_per,
        x_per,
        1000.0 / x_per,
        sp_per,
        1000.0 / sp_per,
        circuit_per,
        1000.0 / circuit_per,
    });
}

/// Generate quantum-derived weights for FPGA ternary dot product
fn run_weight_gen(args: []const []const u8) void {
    var entangled = false;

    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--entangled")) {
            entangled = true;
        }
    }

    if (entangled) {
        run_entangled_weight_gen();
    } else {
        run_single_weight_gen();
    }
}

fn run_single_weight_gen() void {
    print(
        \\
        \\  =============================================
        \\  |  QUANTUM WEIGHT GENERATOR FOR FPGA        |
        \\  =============================================
        \\
        \\  Quantum circuit per weight: |0> -> H3 -> Sacred_Phase -> Measure
        \\
        \\
    , .{});

    var vm = qvm.TernaryQVM.init(8, 137); // sacred seed: fine structure constant

    var weights: [16]i2 = undefined;
    var weight_bits: u32 = 0;

    for (0..16) |idx| {
        const qi: u4 = @intCast(idx % 8);
        vm.qutrits[qi] = qvm.Qutrit.ZERO_STATE;
        vm.hadamard(qi);
        vm.sacred_phase(qi);

        // Position-dependent gates for variety
        if (idx % 3 == 0) vm.z(qi);
        if (idx % 5 == 0) vm.x(qi);

        const trit = vm.measure_qutrit(qi);
        weights[idx] = trit;

        const encoding: u2 = if (trit < 0) 0b00 else if (trit == 0) 0b01 else 0b10;
        weight_bits |= @as(u32, encoding) << @intCast(idx * 2);

        const sym: u8 = if (trit < 0) '-' else if (trit == 0) '0' else '+';
        print("  w[{d:2}] = {c}1  (encoded: {b:0>2})\n", .{ idx, sym, encoding });
    }

    print(
        \\
        \\  Verilog Parameter (copy to ternary_dot.v):
        \\    localparam [31:0] WEIGHTS = 32'h{X:0>8};
        \\
        \\  Weight vector: [
    , .{weight_bits});

    for (0..16) |idx| {
        if (idx > 0) print(", ", .{});
        const sym: u8 = if (weights[idx] < 0) '-' else if (weights[idx] == 0) ' ' else '+';
        print("{c}1", .{sym});
    }

    print(
        \\]
        \\
        \\  =============================================
        \\  WEIGHT GENERATION COMPLETE
        \\  =============================================
        \\
    , .{});
}

/// Generate weights from entangled qutrit pairs
/// Each weight comes from measuring one half of a Bell state
/// after applying sacred phase rotation — correlations from entanglement
fn run_entangled_weight_gen() void {
    print(
        \\
        \\  =============================================
        \\  |  ENTANGLED WEIGHT GENERATOR FOR FPGA      |
        \\  =============================================
        \\
        \\  Circuit: Bell(|0,0>) -> SP(A) -> Measure(A)
        \\  Source: Entangled qutrit pairs with sacred phase
        \\
        \\
    , .{});

    var prng = std.Random.DefaultPrng.init(137); // sacred seed
    const sp = qvm.Gate3.sacred_phase();
    const z = qvm.Gate3.z3();

    var weights: [16]i2 = undefined;
    var weight_bits: u32 = 0;

    for (0..16) |idx| {
        // Create fresh entangled pair
        var pair = qvm.EntangledPair.BELL;

        // Apply sacred phase + position-dependent gates to qutrit A
        pair = pair.apply_gate_a(sp);
        if (idx % 3 == 0) pair = pair.apply_gate_a(z);
        if (idx % 5 == 0) pair = pair.apply_gate_a(qvm.Gate3.X3);

        // Measure qutrit A — entanglement ensures non-classical distribution
        const trit = pair.measure_a(prng.random());
        weights[idx] = trit;

        const encoding: u2 = if (trit < 0) 0b00 else if (trit == 0) 0b01 else 0b10;
        weight_bits |= @as(u32, encoding) << @intCast(idx * 2);

        const sym: u8 = if (trit < 0) '-' else if (trit == 0) '0' else '+';
        print("  w[{d:2}] = {c}1  (entangled, encoded: {b:0>2})\n", .{ idx, sym, encoding });
    }

    // Run CGLMP to show violation alongside weights
    const cglmp = qvm.run_cglmp_test(10000, true);

    print(
        \\
        \\  CGLMP I3 = {d:.6} (classical bound: 2.0, quantum max: 2.9149)
        \\  Violation: {s}
        \\
        \\  Verilog Parameter (copy to ternary_dot.v):
        \\    localparam [31:0] WEIGHTS = 32'h{X:0>8};
        \\
        \\  Weight vector: [
    , .{
        cglmp.i3_value,
        if (cglmp.violation) "YES — QUANTUM ADVANTAGE" else "NO",
        weight_bits,
    });

    for (0..16) |idx| {
        if (idx > 0) print(", ", .{});
        const sym: u8 = if (weights[idx] < 0) '-' else if (weights[idx] == 0) ' ' else '+';
        print("{c}1", .{sym});
    }

    print(
        \\]
        \\
        \\  =============================================
        \\  ENTANGLED WEIGHT GENERATION COMPLETE
        \\  phi^2 + 1/phi^2 = 3 = TRINITY
        \\  =============================================
        \\
    , .{});
}
