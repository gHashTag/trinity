// B2T Benchmark - Binary vs Ternary Performance Comparison
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const trit = @import("trit.zig");
const tekum = @import("tekum.zig");
const tnn = @import("tnn.zig");
const jit = @import("jit.zig");
const b2t_vm = @import("b2t_vm.zig");
const b2t_codegen = @import("b2t_codegen.zig");
const TritOpcode = b2t_codegen.TritOpcode;

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

const WARMUP_ITERATIONS: usize = 1000;
const BENCHMARK_ITERATIONS: usize = 100_000;

// ═══════════════════════════════════════════════════════════════════════════════
// TIMING UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

const BenchmarkResult = struct {
    name: []const u8,
    iterations: usize,
    total_ns: u64,
    min_ns: u64,
    max_ns: u64,
    avg_ns: u64,
    ops_per_sec: u64,

    pub fn print(self: BenchmarkResult) void {
        std.debug.print("  {s}:\n", .{self.name});
        std.debug.print("    Iterations: {d}\n", .{self.iterations});
        std.debug.print("    Total time: {d:.3} ms\n", .{@as(f64, @floatFromInt(self.total_ns)) / 1_000_000.0});
        std.debug.print("    Avg per op: {d} ns\n", .{self.avg_ns});
        std.debug.print("    Min/Max:    {d}/{d} ns\n", .{ self.min_ns, self.max_ns });
        std.debug.print("    Throughput: {d} ops/sec\n", .{self.ops_per_sec});
    }
};

fn runBenchmark(name: []const u8, comptime func: anytype, iterations: usize) BenchmarkResult {
    var timer = std.time.Timer.start() catch unreachable;

    // Warmup
    var i: usize = 0;
    while (i < WARMUP_ITERATIONS) : (i += 1) {
        _ = func();
    }

    // Benchmark
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;
    var total_ns: u64 = 0;

    i = 0;
    while (i < iterations) : (i += 1) {
        timer.reset();
        _ = func();
        const elapsed = timer.read();

        total_ns += elapsed;
        if (elapsed < min_ns) min_ns = elapsed;
        if (elapsed > max_ns) max_ns = elapsed;
    }

    const avg_ns = total_ns / iterations;
    const ops_per_sec = if (avg_ns > 0) 1_000_000_000 / avg_ns else 0;

    return BenchmarkResult{
        .name = name,
        .iterations = iterations,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
        .avg_ns = avg_ns,
        .ops_per_sec = ops_per_sec,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BINARY ARITHMETIC BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

var binary_a: i32 = 12345;
var binary_b: i32 = 6789;

fn binaryAdd() i32 {
    return binary_a +% binary_b;
}

fn binaryMul() i32 {
    return binary_a *% binary_b;
}

fn binaryDiv() i32 {
    return @divTrunc(binary_a, binary_b);
}

fn binarySub() i32 {
    return binary_a -% binary_b;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY ARITHMETIC BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

var ternary_a: trit.Trit27 = trit.Trit27.fromInt(12345);
var ternary_b: trit.Trit27 = trit.Trit27.fromInt(6789);

fn ternaryAdd() trit.Trit27 {
    return ternary_a.add(ternary_b);
}

fn ternaryMul() trit.Trit27 {
    return ternary_a.mul(ternary_b);
}

fn ternaryDiv() trit.Trit27 {
    return ternary_a.div(ternary_b);
}

fn ternarySub() trit.Trit27 {
    return ternary_a.sub(ternary_b);
}

// Native Karatsuba vs Binary conversion comparison
fn ternaryMulKaratsuba() trit.Trit27 {
    return trit.Trit27.mul(ternary_a, ternary_b); // Uses Karatsuba
}

fn ternaryMulBinary() trit.Trit27 {
    return trit.Trit27.mulBinary(ternary_a, ternary_b); // Uses binary conversion
}

fn ternaryMulNative() trit.Trit27 {
    return trit.Trit27.mulNative(ternary_a, ternary_b); // Uses O(n²) native
}

fn ternaryNeg() trit.Trit27 {
    return ternary_a.neg();
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMULATED VM EXECUTION BENCHMARKS
// (Simulates VM overhead without full VM initialization)
// ═══════════════════════════════════════════════════════════════════════════════

// Simulated VM stack operations
var vm_stack: [16]i32 = undefined;
var vm_sp: usize = 0;

fn vmPush(val: i32) void {
    vm_stack[vm_sp] = val;
    vm_sp += 1;
}

fn vmPop() i32 {
    vm_sp -= 1;
    return vm_stack[vm_sp];
}

fn vmAddBenchmark() i32 {
    vm_sp = 0;
    vmPush(12345);
    vmPush(6789);
    const b = vmPop();
    const a = vmPop();
    vmPush(a +% b);
    return vmPop();
}

fn vmMulBenchmark() i32 {
    vm_sp = 0;
    vmPush(123);
    vmPush(456);
    const b = vmPop();
    const a = vmPop();
    vmPush(a *% b);
    return vmPop();
}

fn vmTernaryAddBenchmark() i32 {
    vm_sp = 0;
    vmPush(12345);
    vmPush(6789);
    const b = vmPop();
    const a = vmPop();
    // Ternary add via Trit27
    const ta = trit.Trit27.fromInt(a);
    const tb = trit.Trit27.fromInt(b);
    const result = ta.add(tb);
    vmPush(@intCast(result.toInt()));
    return vmPop();
}

fn vmTernaryMulBenchmark() i32 {
    vm_sp = 0;
    vmPush(123);
    vmPush(456);
    const b = vmPop();
    const a = vmPop();
    // Ternary mul via Trit27
    const ta = trit.Trit27.fromInt(a);
    const tb = trit.Trit27.fromInt(b);
    const result = ta.mul(tb);
    vmPush(@intCast(result.toInt()));
    return vmPop();
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOOP BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

fn loopBinarySum() i32 {
    var sum: i32 = 0;
    var i: i32 = 0;
    while (i < 100) : (i += 1) {
        sum +%= i;
    }
    return sum;
}

fn loopTernarySum() i32 {
    var sum = trit.Trit27.fromInt(0);
    var i: i32 = 0;
    while (i < 100) : (i += 1) {
        sum = sum.add(trit.Trit27.fromInt(i));
    }
    return @intCast(sum.toInt());
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERSION BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

fn binaryToTernaryConversion() trit.Trit27 {
    return trit.Trit27.fromInt(binary_a);
}

fn ternaryToBinaryConversion() i32 {
    return @intCast(ternary_a.toInt());
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEKUM FLOATING-POINT BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

var float_a: f64 = 123.456;
var float_b: f64 = 78.901;
var tekum_a: tekum.Tekum27 = tekum.Tekum27.fromFloat(123.456);
var tekum_b: tekum.Tekum27 = tekum.Tekum27.fromFloat(78.901);

fn floatAdd() f64 {
    return float_a + float_b;
}

fn floatMul() f64 {
    return float_a * float_b;
}

fn floatDiv() f64 {
    return float_a / float_b;
}

fn tekumAdd() tekum.Tekum27 {
    return tekum_a.add(tekum_b);
}

fn tekumMul() tekum.Tekum27 {
    return tekum_a.mul(tekum_b);
}

fn tekumDiv() tekum.Tekum27 {
    return tekum_a.div(tekum_b);
}

fn floatToTekum() tekum.Tekum27 {
    return tekum.Tekum27.fromFloat(float_a);
}

fn tekumToFloat() f64 {
    return tekum_a.toFloat();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TNN (TERNARY NEURAL NETWORK) BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

// Float32 matrix multiplication (for comparison)
const MATRIX_SIZE: usize = 64;
var float_matrix: [MATRIX_SIZE * MATRIX_SIZE]f32 = undefined;
var float_input: [MATRIX_SIZE]f32 = undefined;
var float_output: [MATRIX_SIZE]f32 = undefined;

fn initFloatMatrix() void {
    for (0..MATRIX_SIZE * MATRIX_SIZE) |i| {
        float_matrix[i] = @as(f32, @floatFromInt(i % 3)) - 1.0; // -1, 0, 1 pattern
    }
    for (0..MATRIX_SIZE) |i| {
        float_input[i] = @as(f32, @floatFromInt(i)) / @as(f32, MATRIX_SIZE);
    }
}

fn floatMatmul() f32 {
    for (0..MATRIX_SIZE) |i| {
        var sum: f32 = 0.0;
        for (0..MATRIX_SIZE) |j| {
            sum += float_matrix[i * MATRIX_SIZE + j] * float_input[j];
        }
        float_output[i] = sum;
    }
    return float_output[0];
}

// TNN matrix (initialized once)
var tnn_matrix_initialized = false;
var tnn_matrix: tnn.TernaryMatrix = undefined;

fn initTnnMatrix() void {
    if (tnn_matrix_initialized) return;
    tnn_matrix = tnn.TernaryMatrix.init(std.heap.page_allocator, MATRIX_SIZE, MATRIX_SIZE) catch return;
    // Set ternary weights: -1, 0, 1 pattern
    for (0..MATRIX_SIZE * MATRIX_SIZE) |i| {
        const v = i % 3;
        tnn_matrix.weights[i] = switch (v) {
            0 => .N,
            1 => .Z,
            2 => .P,
            else => .Z,
        };
    }
    tnn_matrix_initialized = true;
}

fn tnnMatmul() f32 {
    initTnnMatrix();
    tnn_matrix.matmul(&float_input, &float_output);
    return float_output[0];
}

// ═══════════════════════════════════════════════════════════════════════════════
// JIT COMPILER BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

// TIR bytecode for: (10 + 5) * 3 - 3 = 42
const JIT_TEST_TIR = [_]u8{
    @intFromEnum(TritOpcode.T_CONST), 0x0A, 0x00, 0x00, 0x00, // push 10
    @intFromEnum(TritOpcode.T_CONST), 0x05, 0x00, 0x00, 0x00, // push 5
    @intFromEnum(TritOpcode.T_ADD), // 15
    @intFromEnum(TritOpcode.T_CONST), 0x03, 0x00, 0x00, 0x00, // push 3
    @intFromEnum(TritOpcode.T_MUL), // 45
    @intFromEnum(TritOpcode.T_CONST), 0x03, 0x00, 0x00, 0x00, // push 3
    @intFromEnum(TritOpcode.T_SUB), // 42
    @intFromEnum(TritOpcode.T_RET),
};

var jit_compiler: ?jit.JitCompiler = null;
var jit_initialized = false;

fn initJit() void {
    if (jit_initialized) return;
    jit_compiler = jit.JitCompiler.init(std.heap.page_allocator) catch return;
    jit_compiler.?.compile(&JIT_TEST_TIR) catch return;
    jit_initialized = true;
}

fn jitExecute() i32 {
    initJit();
    if (jit_compiler) |*j| {
        return j.executeNoArgs();
    }
    return 0;
}

// Interpreter version (simulated)
fn interpreterExecute() i32 {
    // Simulate interpreter overhead
    var stack: [16]i32 = undefined;
    var sp: usize = 0;

    // push 10
    stack[sp] = 10;
    sp += 1;
    // push 5
    stack[sp] = 5;
    sp += 1;
    // add
    sp -= 1;
    const b1 = stack[sp];
    sp -= 1;
    const a1 = stack[sp];
    stack[sp] = a1 + b1;
    sp += 1;
    // push 3
    stack[sp] = 3;
    sp += 1;
    // mul
    sp -= 1;
    const b2 = stack[sp];
    sp -= 1;
    const a2 = stack[sp];
    stack[sp] = a2 * b2;
    sp += 1;
    // push 3
    stack[sp] = 3;
    sp += 1;
    // sub
    sp -= 1;
    const b3 = stack[sp];
    sp -= 1;
    const a3 = stack[sp];
    stack[sp] = a3 - b3;
    sp += 1;
    // ret
    sp -= 1;
    return stack[sp];
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     B2T Performance Benchmark                                ║\n", .{});
    std.debug.print("║     Binary vs Ternary Arithmetic                             ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("Configuration:\n", .{});
    std.debug.print("  Warmup iterations:    {d}\n", .{WARMUP_ITERATIONS});
    std.debug.print("  Benchmark iterations: {d}\n", .{BENCHMARK_ITERATIONS});
    std.debug.print("\n", .{});

    // Binary arithmetic
    std.debug.print("═══ BINARY ARITHMETIC (native i32) ═══\n", .{});
    const bin_add = runBenchmark("Binary Add", binaryAdd, BENCHMARK_ITERATIONS);
    bin_add.print();
    const bin_mul = runBenchmark("Binary Mul", binaryMul, BENCHMARK_ITERATIONS);
    bin_mul.print();
    const bin_div = runBenchmark("Binary Div", binaryDiv, BENCHMARK_ITERATIONS);
    bin_div.print();
    const bin_sub = runBenchmark("Binary Sub", binarySub, BENCHMARK_ITERATIONS);
    bin_sub.print();
    std.debug.print("\n", .{});

    // Ternary arithmetic
    std.debug.print("═══ TERNARY ARITHMETIC (Trit27) ═══\n", .{});
    const ter_add = runBenchmark("Ternary Add", ternaryAdd, BENCHMARK_ITERATIONS);
    ter_add.print();
    const ter_mul = runBenchmark("Ternary Mul", ternaryMul, BENCHMARK_ITERATIONS);
    ter_mul.print();
    const ter_div = runBenchmark("Ternary Div", ternaryDiv, BENCHMARK_ITERATIONS);
    ter_div.print();
    const ter_sub = runBenchmark("Ternary Sub", ternarySub, BENCHMARK_ITERATIONS);
    ter_sub.print();
    const ter_neg = runBenchmark("Ternary Neg", ternaryNeg, BENCHMARK_ITERATIONS);
    ter_neg.print();
    std.debug.print("\n", .{});

    // Karatsuba vs Binary comparison
    std.debug.print("═══ KARATSUBA vs BINARY MULTIPLICATION ═══\n", .{});
    const kar_mul = runBenchmark("Karatsuba Mul", ternaryMulKaratsuba, BENCHMARK_ITERATIONS);
    kar_mul.print();
    const bin_conv_mul = runBenchmark("Binary Conv Mul", ternaryMulBinary, BENCHMARK_ITERATIONS);
    bin_conv_mul.print();
    const nat_mul = runBenchmark("Native O(n²) Mul", ternaryMulNative, BENCHMARK_ITERATIONS);
    nat_mul.print();
    std.debug.print("\n", .{});

    // VM execution
    std.debug.print("═══ VM EXECUTION ═══\n", .{});
    const vm_add = runBenchmark("VM Binary Add", vmAddBenchmark, BENCHMARK_ITERATIONS / 10);
    vm_add.print();
    const vm_mul = runBenchmark("VM Binary Mul", vmMulBenchmark, BENCHMARK_ITERATIONS / 10);
    vm_mul.print();
    const vm_tadd = runBenchmark("VM Ternary Add", vmTernaryAddBenchmark, BENCHMARK_ITERATIONS / 10);
    vm_tadd.print();
    const vm_tmul = runBenchmark("VM Ternary Mul", vmTernaryMulBenchmark, BENCHMARK_ITERATIONS / 10);
    vm_tmul.print();
    std.debug.print("\n", .{});

    // Loop benchmarks
    std.debug.print("═══ LOOP BENCHMARKS (sum 0..99) ═══\n", .{});
    const loop_bin = runBenchmark("Binary Loop Sum", loopBinarySum, BENCHMARK_ITERATIONS / 100);
    loop_bin.print();
    const loop_ter = runBenchmark("Ternary Loop Sum", loopTernarySum, BENCHMARK_ITERATIONS / 100);
    loop_ter.print();
    std.debug.print("\n", .{});

    // Conversion benchmarks
    std.debug.print("═══ CONVERSION BENCHMARKS ═══\n", .{});
    const conv_b2t = runBenchmark("Binary->Ternary", binaryToTernaryConversion, BENCHMARK_ITERATIONS);
    conv_b2t.print();
    const conv_t2b = runBenchmark("Ternary->Binary", ternaryToBinaryConversion, BENCHMARK_ITERATIONS);
    conv_t2b.print();
    std.debug.print("\n", .{});

    // Tekum floating-point benchmarks
    std.debug.print("═══ TEKUM FLOATING-POINT (vs IEEE 754) ═══\n", .{});
    const flt_add = runBenchmark("IEEE 754 Add", floatAdd, BENCHMARK_ITERATIONS);
    flt_add.print();
    const flt_mul = runBenchmark("IEEE 754 Mul", floatMul, BENCHMARK_ITERATIONS);
    flt_mul.print();
    const flt_div = runBenchmark("IEEE 754 Div", floatDiv, BENCHMARK_ITERATIONS);
    flt_div.print();
    const tek_add = runBenchmark("Tekum Add", tekumAdd, BENCHMARK_ITERATIONS);
    tek_add.print();
    const tek_mul = runBenchmark("Tekum Mul", tekumMul, BENCHMARK_ITERATIONS);
    tek_mul.print();
    const tek_div = runBenchmark("Tekum Div", tekumDiv, BENCHMARK_ITERATIONS);
    tek_div.print();
    const conv_f2t = runBenchmark("Float->Tekum", floatToTekum, BENCHMARK_ITERATIONS);
    conv_f2t.print();
    const conv_t2f = runBenchmark("Tekum->Float", tekumToFloat, BENCHMARK_ITERATIONS);
    conv_t2f.print();
    std.debug.print("\n", .{});

    // TNN benchmarks
    std.debug.print("═══ TNN (TERNARY NEURAL NETWORK) ═══\n", .{});
    std.debug.print("  Matrix size: {d}x{d}\n", .{ MATRIX_SIZE, MATRIX_SIZE });
    initFloatMatrix();
    const flt_mm = runBenchmark("Float32 Matmul", floatMatmul, BENCHMARK_ITERATIONS / 100);
    flt_mm.print();
    const tnn_mm = runBenchmark("TNN Matmul", tnnMatmul, BENCHMARK_ITERATIONS / 100);
    tnn_mm.print();
    std.debug.print("\n", .{});

    // JIT benchmarks
    std.debug.print("═══ JIT COMPILER ═══\n", .{});
    const interp = runBenchmark("Interpreter", interpreterExecute, BENCHMARK_ITERATIONS);
    interp.print();
    const jit_bench = runBenchmark("JIT Native", jitExecute, BENCHMARK_ITERATIONS);
    jit_bench.print();
    std.debug.print("\n", .{});

    // Summary comparison
    std.debug.print("═══ PERFORMANCE COMPARISON ═══\n", .{});
    std.debug.print("\n", .{});

    const add_ratio = @as(f64, @floatFromInt(ter_add.avg_ns)) / @as(f64, @floatFromInt(@max(bin_add.avg_ns, 1)));
    const mul_ratio = @as(f64, @floatFromInt(ter_mul.avg_ns)) / @as(f64, @floatFromInt(@max(bin_mul.avg_ns, 1)));
    const div_ratio = @as(f64, @floatFromInt(ter_div.avg_ns)) / @as(f64, @floatFromInt(@max(bin_div.avg_ns, 1)));
    const loop_ratio = @as(f64, @floatFromInt(loop_ter.avg_ns)) / @as(f64, @floatFromInt(@max(loop_bin.avg_ns, 1)));

    std.debug.print("  Operation      Binary    Ternary   Ratio\n", .{});
    std.debug.print("  ─────────────────────────────────────────\n", .{});
    std.debug.print("  Add            {d:>6} ns  {d:>6} ns  {d:.2}x\n", .{ bin_add.avg_ns, ter_add.avg_ns, add_ratio });
    std.debug.print("  Mul            {d:>6} ns  {d:>6} ns  {d:.2}x\n", .{ bin_mul.avg_ns, ter_mul.avg_ns, mul_ratio });
    std.debug.print("  Div            {d:>6} ns  {d:>6} ns  {d:.2}x\n", .{ bin_div.avg_ns, ter_div.avg_ns, div_ratio });
    std.debug.print("  Loop (100)     {d:>6} ns  {d:>6} ns  {d:.2}x\n", .{ loop_bin.avg_ns, loop_ter.avg_ns, loop_ratio });
    std.debug.print("\n", .{});

    const vm_add_ratio = @as(f64, @floatFromInt(vm_tadd.avg_ns)) / @as(f64, @floatFromInt(@max(vm_add.avg_ns, 1)));
    const vm_mul_ratio = @as(f64, @floatFromInt(vm_tmul.avg_ns)) / @as(f64, @floatFromInt(@max(vm_mul.avg_ns, 1)));

    std.debug.print("  VM Operation   Binary    Ternary   Ratio\n", .{});
    std.debug.print("  ─────────────────────────────────────────\n", .{});
    std.debug.print("  VM Add         {d:>6} ns  {d:>6} ns  {d:.2}x\n", .{ vm_add.avg_ns, vm_tadd.avg_ns, vm_add_ratio });
    std.debug.print("  VM Mul         {d:>6} ns  {d:>6} ns  {d:.2}x\n", .{ vm_mul.avg_ns, vm_tmul.avg_ns, vm_mul_ratio });
    std.debug.print("\n", .{});

    // Tekum vs IEEE 754 comparison
    const fadd_ratio = @as(f64, @floatFromInt(tek_add.avg_ns)) / @as(f64, @floatFromInt(@max(flt_add.avg_ns, 1)));
    const fmul_ratio = @as(f64, @floatFromInt(tek_mul.avg_ns)) / @as(f64, @floatFromInt(@max(flt_mul.avg_ns, 1)));
    const fdiv_ratio = @as(f64, @floatFromInt(tek_div.avg_ns)) / @as(f64, @floatFromInt(@max(flt_div.avg_ns, 1)));

    std.debug.print("  Float Op       IEEE754   Tekum     Ratio\n", .{});
    std.debug.print("  ─────────────────────────────────────────\n", .{});
    std.debug.print("  Float Add      {d:>6} ns  {d:>6} ns  {d:.2}x\n", .{ flt_add.avg_ns, tek_add.avg_ns, fadd_ratio });
    std.debug.print("  Float Mul      {d:>6} ns  {d:>6} ns  {d:.2}x\n", .{ flt_mul.avg_ns, tek_mul.avg_ns, fmul_ratio });
    std.debug.print("  Float Div      {d:>6} ns  {d:>6} ns  {d:.2}x\n", .{ flt_div.avg_ns, tek_div.avg_ns, fdiv_ratio });
    std.debug.print("\n", .{});

    // TNN comparison
    const tnn_ratio = @as(f64, @floatFromInt(tnn_mm.avg_ns)) / @as(f64, @floatFromInt(@max(flt_mm.avg_ns, 1)));

    std.debug.print("  TNN Matmul     Float32   TNN       Ratio\n", .{});
    std.debug.print("  ─────────────────────────────────────────\n", .{});
    std.debug.print("  64x64 Matmul   {d:>6} ns  {d:>6} ns  {d:.2}x\n", .{ flt_mm.avg_ns, tnn_mm.avg_ns, tnn_ratio });
    std.debug.print("\n", .{});

    // JIT comparison
    const jit_speedup = @as(f64, @floatFromInt(interp.avg_ns)) / @as(f64, @floatFromInt(@max(jit_bench.avg_ns, 1)));

    std.debug.print("  JIT Compiler   Interp    JIT       Speedup\n", .{});
    std.debug.print("  ─────────────────────────────────────────\n", .{});
    std.debug.print("  Expression     {d:>6} ns  {d:>6} ns  {d:.1}x\n", .{ interp.avg_ns, jit_bench.avg_ns, jit_speedup });
    std.debug.print("\n", .{});

    // Karatsuba comparison
    const kar_vs_binconv = @as(f64, @floatFromInt(kar_mul.avg_ns)) / @as(f64, @floatFromInt(@max(bin_conv_mul.avg_ns, 1)));
    const nat_vs_binconv = @as(f64, @floatFromInt(nat_mul.avg_ns)) / @as(f64, @floatFromInt(@max(bin_conv_mul.avg_ns, 1)));

    std.debug.print("  Multiplication Karatsuba Binary    Native\n", .{});
    std.debug.print("  ─────────────────────────────────────────\n", .{});
    std.debug.print("  Time (ns)      {d:>6}     {d:>6}    {d:>6}\n", .{ kar_mul.avg_ns, bin_conv_mul.avg_ns, nat_mul.avg_ns });
    std.debug.print("  vs Binary      {d:.2}x      1.00x     {d:.2}x\n", .{ kar_vs_binconv, nat_vs_binconv });
    std.debug.print("\n", .{});

    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  Note: Ternary operations are emulated on binary hardware.   ║\n", .{});
    std.debug.print("║  Native ternary hardware would eliminate conversion overhead.║\n", .{});
    std.debug.print("║  Tekum provides balanced ternary floating-point arithmetic.  ║\n", .{});
    std.debug.print("║  TNN uses only add/sub (no multiply) for matrix operations.  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "benchmark binary add correctness" {
    const result = binaryAdd();
    try std.testing.expectEqual(@as(i32, 12345 + 6789), result);
}

test "benchmark ternary add correctness" {
    const result = ternaryAdd();
    try std.testing.expectEqual(@as(i32, 12345 + 6789), result.toInt());
}

test "benchmark loop binary sum correctness" {
    const result = loopBinarySum();
    // Sum of 0..99 = 99*100/2 = 4950
    try std.testing.expectEqual(@as(i32, 4950), result);
}

test "benchmark loop ternary sum correctness" {
    const result = loopTernarySum();
    try std.testing.expectEqual(@as(i32, 4950), result);
}

test "benchmark tekum add correctness" {
    const result = tekumAdd();
    const expected: f64 = 123.456 + 78.901;
    const actual = result.toFloat();
    try std.testing.expect(@abs(actual - expected) < 10.0);
}

test "benchmark tekum mul correctness" {
    const result = tekumMul();
    const expected: f64 = 123.456 * 78.901;
    const actual = result.toFloat();
    // Allow larger error for multiplication
    try std.testing.expect(@abs(actual - expected) < 500.0);
}

test "benchmark tnn matmul correctness" {
    initFloatMatrix();
    const result = tnnMatmul();
    // Just verify it runs without error
    try std.testing.expect(!std.math.isNan(result));
}

test "benchmark jit correctness" {
    const result = jitExecute();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "benchmark interpreter correctness" {
    const result = interpreterExecute();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "benchmark vm add correctness" {
    const result = vmAddBenchmark();
    try std.testing.expectEqual(@as(i32, 12345 + 6789), result);
}

test "benchmark vm ternary add correctness" {
    const result = vmTernaryAddBenchmark();
    try std.testing.expectEqual(@as(i32, 12345 + 6789), result);
}
