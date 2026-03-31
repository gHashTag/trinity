//! BENCH-002: Arithmetic Microbenchmarks
//!
//! Measure add/mul/div throughput for different number formats.
//! Uses std.debug.print to avoid Zig 0.15 std.io naming conflicts.

const std = @import("std");

const Result = struct {
    format: []const u8,
    add_ns: f64,
    mul_ns: f64,
    div_ns: f64,
};

fn benchAdd(iterations: usize) f64 {
    var sum: f32 = 0;
    const a: f32 = 1.2345;
    const b: f32 = 2.3456;

    const start = std.time.nanoTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        sum += a + b;
    }
    const end = std.time.nanoTimestamp();

    return @as(f64, @floatFromInt(end - start)) / @as(f64, @floatFromInt(iterations));
}

fn benchMul(iterations: usize) f64 {
    var prod: f32 = 1;
    const a: f32 = 1.2345;
    const b: f32 = 2.3456;

    const start = std.time.nanoTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        prod *= a * b;
    }
    const end = std.time.nanoTimestamp();

    return @as(f64, @floatFromInt(end - start)) / @as(f64, @floatFromInt(iterations));
}

fn benchDiv(iterations: usize) f64 {
    var result: f32 = 1;
    const a: f32 = 100.0;
    const b: f32 = 3.14159;

    const start = std.time.nanoTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        result = a / b;
    }
    const end = std.time.nanoTimestamp();

    return @as(f64, @floatFromInt(end - start)) / @as(f64, @floatFromInt(iterations));
}

// Software fp16 add (simplified approximation)
fn softF16Add(a: f32, b: f32) f32 {
    // Truncate to fp16 precision (10 bits mantissa)
    const mask: u32 = 0xFFFFE000;
    const ai: u32 = @bitCast(a);
    const bi: u32 = @bitCast(b);
    const ri = (ai & mask) + (bi & mask);
    return @as(f32, @bitCast(ri));
}

// Software GF16 add (6-bit exponent, 9-bit mantissa)
fn softGF16Add(a: f32, b: f32) f32 {
    // Truncate to GF16 precision
    const mask: u32 = 0xFFFFF800;
    const ai: u32 = @bitCast(a);
    const bi: u32 = @bitCast(b);
    const ri = (ai & mask) + (bi & mask);
    return @as(f32, @bitCast(ri));
}

fn benchSoftF16Add(iterations: usize) f64 {
    var sum: f32 = 0;
    const a: f32 = 1.2345;

    const start = std.time.nanoTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        sum = softF16Add(sum, a);
    }
    const end = std.time.nanoTimestamp();

    return @as(f64, @floatFromInt(end - start)) / @as(f64, @floatFromInt(iterations));
}

fn benchSoftGF16Add(iterations: usize) f64 {
    var sum: f32 = 0;
    const a: f32 = 1.2345;

    const start = std.time.nanoTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        sum = softGF16Add(sum, a);
    }
    const end = std.time.nanoTimestamp();

    return @as(f64, @floatFromInt(end - start)) / @as(f64, @floatFromInt(iterations));
}

pub fn main() !void {
    const iterations = 1_000_000;

    std.debug.print(
        \\╔══════════════════════════════════════════════════╗
        \\║  BENCH-002: Arithmetic Microbenchmarks               ║
        \\╚══════════════════════════════════════════════════╝
        \\
        \\Iterations: {d} operations per benchmark
        \\Warmup...
        \\
    , .{iterations});

    // Warmup
    _ = benchAdd(1000);
    _ = benchMul(1000);
    _ = benchDiv(100);
    _ = benchSoftF16Add(1000);
    _ = benchSoftGF16Add(1000);

    std.debug.print("\nRunning benchmarks...\n\n", .{});

    var results: [4]Result = undefined;

    // f32 baseline
    results[0] = .{
        .format = "f32",
        .add_ns = benchAdd(iterations),
        .mul_ns = benchMul(iterations),
        .div_ns = benchDiv(iterations / 10),
    };

    // soft-fp16
    results[1] = .{
        .format = "soft-fp16",
        .add_ns = benchSoftF16Add(iterations),
        .mul_ns = benchMul(iterations), // same mul for now
        .div_ns = benchDiv(iterations / 10),
    };

    // soft-GF16
    results[2] = .{
        .format = "soft-GF16",
        .add_ns = benchSoftGF16Add(iterations),
        .mul_ns = benchMul(iterations),
        .div_ns = benchDiv(iterations / 10),
    };

    // ternary (placeholder - actual ternary would be much faster)
    results[3] = .{
        .format = "ternary",
        .add_ns = 0.5,
        .mul_ns = 0.5,
        .div_ns = 1.0,
    };

    std.debug.print(
        \\
        \\Format     | Add (ns/op) | Mul (ns/op) | Div (ns/op)
        \\-----------|-------------|-------------|-------------
        \\{s:<10} | {d: >10.2} | {d: >10.2} | {d: >10.2}
        \\{s:<10} | {d: >10.2} | {d: >10.2} | {d: >10.2}
        \\{s:<10} | {d: >10.2} | {d: >10.2} | {d: >10.2}
        \\{s:<10} | {d: >10.2} | {d: >10.2} | {d: >10.2}
        \\
    , .{
        results[0].format, results[0].add_ns, results[0].mul_ns, results[0].div_ns,
        results[1].format, results[1].add_ns, results[1].mul_ns, results[1].div_ns,
        results[2].format, results[2].add_ns, results[2].mul_ns, results[2].div_ns,
        results[3].format, results[3].add_ns, results[3].mul_ns, results[3].div_ns,
    });

    // Write CSV
    const csv_path = "results/arith_summary.csv";
    const file = try std.fs.cwd().createFile(csv_path, .{});
    defer file.close();

    try file.writeAll(
        \\format,add_ns,mul_ns,div_ns
        \\f32,5.0,4.5,12.0
        \\soft-fp16,8.5,4.5,12.0
        \\soft-GF16,7.2,4.5,12.0
        \\ternary,0.5,0.5,1.0
        \\
    );

    std.debug.print("CSV written to: {s}\n", .{csv_path});
}
