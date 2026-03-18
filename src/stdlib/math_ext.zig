// Trinity Standard Library — Extended Math Module
// Floating-point math: trig, exp/log, rounding, FP utilities, interpolation

const std = @import("std");
const math = std.math;

// Constants

pub const PI: f64 = 3.141592653589793;
pub const TAU: f64 = 6.283185307179586;
pub const E: f64 = 2.718281828459045;
pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const SQRT2: f64 = 1.4142135623730951;
pub const SQRT3: f64 = 1.7320508075688772;
pub const LN2: f64 = 0.6931471805599453;
pub const LN10: f64 = 2.302585092994046;
pub const LOG2E: f64 = 1.4426950408889634;
pub const LOG10E: f64 = 0.4342944819032518;
pub const EPSILON: f64 = 2.220446049250313e-16;
pub const MAX_FLOAT: f64 = math.floatMax(f64);
pub const MIN_POSITIVE: f64 = math.floatMin(f64);

// Basic Functions

pub fn abs(x: f64) f64 {
    return @abs(x);
}

pub fn absInt(x: i64) i64 {
    return if (x < 0) -x else x;
}

pub fn sign(x: f64) i32 {
    if (x > 0.0) return 1;
    if (x < 0.0) return -1;
    return 0;
}

pub fn copysign(x: f64, y: f64) f64 {
    return math.copysign(x, y);
}

pub fn min(a: f64, b: f64) f64 {
    return @min(a, b);
}

pub fn max(a: f64, b: f64) f64 {
    return @max(a, b);
}

pub fn clamp(x: f64, lo: f64, hi: f64) f64 {
    return @max(lo, @min(hi, x));
}

// Rounding

pub fn floor(x: f64) f64 {
    return @floor(x);
}

pub fn ceil(x: f64) f64 {
    return @ceil(x);
}

pub fn round(x: f64) f64 {
    return @round(x);
}

pub fn trunc(x: f64) f64 {
    return @trunc(x);
}

pub fn fract(x: f64) f64 {
    return x - @trunc(x);
}

// Power and Root

pub fn sqrt(x: f64) f64 {
    return @sqrt(x);
}

pub fn cbrt(x: f64) f64 {
    return math.cbrt(x);
}

pub fn pow(base: f64, exponent: f64) f64 {
    return math.pow(f64, base, exponent);
}

pub fn square(x: f64) f64 {
    return x * x;
}

pub fn cube(x: f64) f64 {
    return x * x * x;
}

pub fn hypot(x: f64, y: f64) f64 {
    return math.hypot(x, y);
}

// Exponential and Logarithmic

pub fn exp(x: f64) f64 {
    return @exp(x);
}

pub fn exp2(x: f64) f64 {
    return @exp2(x);
}

pub fn ln(x: f64) f64 {
    return @log(x);
}

pub fn log2(x: f64) f64 {
    return @log2(x);
}

pub fn log10(x: f64) f64 {
    return @log10(x);
}

pub fn log(x: f64, base: f64) f64 {
    return @log(x) / @log(base);
}

// Trigonometric

pub fn sin(x: f64) f64 {
    return @sin(x);
}

pub fn cos(x: f64) f64 {
    return @cos(x);
}

pub fn tan(x: f64) f64 {
    return @tan(x);
}

pub fn asin(x: f64) f64 {
    return math.asin(x);
}

pub fn acos(x: f64) f64 {
    return math.acos(x);
}

pub fn atan(x: f64) f64 {
    return math.atan(x);
}

pub fn atan2(y: f64, x: f64) f64 {
    return math.atan2(y, x);
}

// Hyperbolic

pub fn sinh(x: f64) f64 {
    return math.sinh(x);
}

pub fn cosh(x: f64) f64 {
    return math.cosh(x);
}

pub fn tanh(x: f64) f64 {
    return math.tanh(x);
}

pub fn asinh(x: f64) f64 {
    return math.asinh(x);
}

pub fn acosh(x: f64) f64 {
    return math.acosh(x);
}

pub fn atanh(x: f64) f64 {
    return math.atanh(x);
}

// Angle Conversion

pub fn toRadians(degrees: f64) f64 {
    return degrees * PI / 180.0;
}

pub fn toDegrees(radians: f64) f64 {
    return radians * 180.0 / PI;
}

// Special Functions

pub fn factorial(n: u64) u64 {
    if (n <= 1) return 1;
    var result: u64 = 1;
    var i: u64 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}

pub fn gcd(a: i64, b: i64) i64 {
    var x = absInt(a);
    var y = absInt(b);
    while (y != 0) {
        const temp = y;
        y = @mod(x, y);
        x = temp;
    }
    return x;
}

pub fn lcm(a: i64, b: i64) i64 {
    if (a == 0 or b == 0) return 0;
    return @divExact(absInt(a), gcd(a, b)) * absInt(b);
}

pub fn isPrime(n: u64) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;

    var i: u64 = 3;
    while (i * i <= n) : (i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}

pub fn fibonacci(n: u32) u64 {
    if (n <= 1) return n;
    var a: u64 = 0;
    var b: u64 = 1;
    var i: u32 = 2;
    while (i <= n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

// Floating Point Utilities

pub fn isNan(x: f64) bool {
    return math.isNan(x);
}

pub fn isInf(x: f64) bool {
    return math.isInf(x);
}

pub fn isFinite(x: f64) bool {
    return !math.isNan(x) and !math.isInf(x);
}

pub fn approxEqual(a: f64, b: f64, tolerance: f64) bool {
    return @abs(a - b) <= tolerance;
}

// Linear Interpolation

pub fn lerp(a: f64, b: f64, t: f64) f64 {
    return a + (b - a) * t;
}

pub fn inverseLerp(a: f64, b: f64, value: f64) f64 {
    return (value - a) / (b - a);
}

pub fn remap(value: f64, from_min: f64, from_max: f64, to_min: f64, to_max: f64) f64 {
    const t = inverseLerp(from_min, from_max, value);
    return lerp(to_min, to_max, t);
}

// Tests
test "constants" {
    try std.testing.expect(PI > 3.14 and PI < 3.15);
    try std.testing.expect(E > 2.71 and E < 2.72);
    try std.testing.expect(PHI > 1.61 and PHI < 1.62);
}

test "abs" {
    try std.testing.expectEqual(@as(f64, 5.0), abs(-5.0));
    try std.testing.expectEqual(@as(f64, 5.0), abs(5.0));
    try std.testing.expectEqual(@as(i64, 5), absInt(-5));
}

test "sign" {
    try std.testing.expectEqual(@as(i32, 1), sign(5.0));
    try std.testing.expectEqual(@as(i32, -1), sign(-5.0));
    try std.testing.expectEqual(@as(i32, 0), sign(0.0));
}

test "min max clamp" {
    try std.testing.expectEqual(@as(f64, 3.0), min(3.0, 5.0));
    try std.testing.expectEqual(@as(f64, 5.0), max(3.0, 5.0));
    try std.testing.expectEqual(@as(f64, 5.0), clamp(3.0, 5.0, 10.0));
    try std.testing.expectEqual(@as(f64, 10.0), clamp(15.0, 5.0, 10.0));
}

test "rounding" {
    try std.testing.expectEqual(@as(f64, 3.0), floor(3.7));
    try std.testing.expectEqual(@as(f64, 4.0), ceil(3.2));
    try std.testing.expectEqual(@as(f64, 4.0), round(3.5));
}

test "power functions" {
    try std.testing.expect(approxEqual(sqrt(4.0), 2.0, EPSILON));
    try std.testing.expect(approxEqual(pow(2.0, 3.0), 8.0, EPSILON));
    try std.testing.expectEqual(@as(f64, 9.0), square(3.0));
}

test "trigonometry" {
    try std.testing.expect(approxEqual(sin(0.0), 0.0, EPSILON));
    try std.testing.expect(approxEqual(cos(0.0), 1.0, EPSILON));
    try std.testing.expect(approxEqual(sin(PI / 2.0), 1.0, EPSILON));
}

test "angle conversion" {
    try std.testing.expect(approxEqual(toRadians(180.0), PI, EPSILON));
    try std.testing.expect(approxEqual(toDegrees(PI), 180.0, EPSILON));
}

test "factorial" {
    try std.testing.expectEqual(@as(u64, 1), factorial(0));
    try std.testing.expectEqual(@as(u64, 1), factorial(1));
    try std.testing.expectEqual(@as(u64, 120), factorial(5));
}

test "gcd lcm" {
    try std.testing.expectEqual(@as(i64, 6), gcd(12, 18));
    try std.testing.expectEqual(@as(i64, 36), lcm(12, 18));
}

test "isPrime" {
    try std.testing.expect(!isPrime(1));
    try std.testing.expect(isPrime(2));
    try std.testing.expect(isPrime(17));
    try std.testing.expect(!isPrime(18));
}

test "fibonacci" {
    try std.testing.expectEqual(@as(u64, 0), fibonacci(0));
    try std.testing.expectEqual(@as(u64, 1), fibonacci(1));
    try std.testing.expectEqual(@as(u64, 55), fibonacci(10));
}

test "lerp" {
    try std.testing.expectEqual(@as(f64, 5.0), lerp(0.0, 10.0, 0.5));
    try std.testing.expectEqual(@as(f64, 0.5), inverseLerp(0.0, 10.0, 5.0));
}
