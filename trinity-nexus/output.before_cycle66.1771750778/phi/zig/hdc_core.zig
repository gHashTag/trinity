// ═══════════════════════════════════════════════════════════════════════════════
// hdc_core v1.0.0 - Generated from .vibee specification
// ═══════════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Author: 
// DO NOT EDIT - This file is auto-generated
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:КОНСТАНТЫ]
// ═══════════════════════════════════════════════════════════════════════════════

pub const DEFAULT_DIM: f64 = 10240;

pub const LEARNING_RATE: f64 = 0.01;

pub const SIMILARITY_THRESHOLD: f64 = 0.7;

pub const QUANTIZE_POS: f64 = 0.5;

pub const QUANTIZE_NEG: f64 = -0.5;

pub const MAX_PROTOTYPES: f64 = 1000;

// [CYR:Базо]inые φ-toонwith[CYR:танты] (Sacred Formula)
pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const SQRT5: f64 = 2.2360679774997896;
pub const TAU: f64 = 6.283185307179586;
pub const PI: f64 = 3.141592653589793;
pub const E: f64 = 2.718281828459045;
pub const PHOENIX: i64 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:ТИПЫ]
// ═══════════════════════════════════════════════════════════════════════════════

/// [CYR:Сбалан]withandроin[CYR:анный] [CYR:тро]and[CYR:чный] [CYR:разряд]
pub const Trit = struct {
};

/// [CYR:Тро]and[CYR:чный] гand[CYR:пер]inеto[CYR:тор] for HDC
pub const HyperVector = struct {
    data: []i64,
    dim: i64,
};

/// Float аtoto[CYR:умулятор] for [CYR:онлайн] уwith[CYR:ред]notнandя
pub const FloatAccumulator = struct {
    data: []f64,
    dim: i64,
};

/// Прfromfromandп toлаwithwithа with аtoto[CYR:умулятором]
pub const Prototype = struct {
    label: []const u8,
    accumulator: FloatAccumulator,
    vector: HyperVector,
    count: i64,
};

/// [CYR:Онлайн] HDC withandwith[CYR:тема]
pub const OnlineHDC = struct {
    prototypes: std.StringHashMap([]const u8),
    dim: i64,
    learning_rate: f64,
    samples_seen: i64,
};

/// Result inычandwith[CYR:лен]andя with[CYR:ход]withтinа
pub const SimilarityResult = struct {
    similarity: f64,
    label: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:ПАМЯТЬ] [CYR:ДЛЯ] WASM
// ═══════════════════════════════════════════════════════════════════════════════

var global_buffer: [65536]u8 align(16) = undefined;
var f64_buffer: [8192]f64 align(16) = undefined;

export fn get_global_buffer_ptr() [*]u8 {
    return &global_buffer;
}

export fn get_f64_buffer_ptr() [*]f64 {
    return &f64_buffer;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATION PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════

/// Check TRINITY identity: φ² + 1/φ² = 3
fn verify_trinity() f64 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}

/// φ-and[CYR:нтер]fieldsцandя
fn phi_lerp(a: f64, b: f64, t: f64) f64 {
    const phi_t = math.pow(f64, t, PHI_INV);
    return a + (b - a) * phi_t;
}

/// Геnot[CYR:рац]andя φ-withпand[CYR:рал]and
fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {
    const max_points = f64_buffer.len / 2;
    const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const angle = fi * TAU * PHI_INV;
        const radius = scale * math.pow(f64, PHI, fi * 0.1);
        f64_buffer[i * 2] = cx + radius * @cos(angle);
        f64_buffer[i * 2 + 1] = cy + radius * @sin(angle);
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BEHAVIOR FUNCTIONS - Generated from behaviors
// ═══════════════════════════════════════════════════════════════════════════════

/// Дinа гand[CYR:пер]inеto[CYR:тора] a and b одandontoоinой [CYR:размерно]withтand
/// When: Creation аwithwithоцandацandand [CYR:через] поelement[CYR:ное] [CYR:умножен]andе
/// Then: Returns HyperVector where c[i] = a[i] * b[i]
pub fn bind() []i8 {
// TODO: implement — Returns HyperVector where c[i] = a[i] * b[i]
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// Сin[CYR:язанный] inеto[CYR:тор] and to[CYR:люч]
/// When: Изin[CYR:лечен]andе within[CYR:язанного] зon[CYR:чен]andя
/// Then: Returns bind(bound, key) т.to. [CYR:тро]and[CYR:чный] bind with[CYR:амообрат]andм
pub fn unbind() !void {
// TODO: implement — Returns bind(bound, key) т.to. [CYR:тро]and[CYR:чный] bind with[CYR:амообрат]andм
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// Спandwithоto гand[CYR:пер]inеto[CYR:торо]in
/// When: Creation with[CYR:уперпоз]andцandand [CYR:через] [CYR:мажор]and[CYR:тарное] [CYR:голо]withоinанandе
/// Then: Returns HyperVector with [CYR:мажор]and[CYR:тарным] трand[CYR:том] on to[CYR:аждой] [CYR:поз]andцandand
pub fn bundle() []i8 {
// TODO: implement — Returns HyperVector with [CYR:мажор]and[CYR:тарным] трand[CYR:том] on to[CYR:аждой] [CYR:поз]andцandand
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// Спandwithоto гand[CYR:пер]inеto[CYR:торо]in
/// When: SIMD-[CYR:опт]andмandзandроin[CYR:анное] bundling (32 трandта [CYR:параллельно])
/// Then: Returns HyperVector with andwith[CYR:пользо]inанandем Vec32i8
pub fn bundle_simd() []i8 {
// TODO: implement — Returns HyperVector with andwith[CYR:пользо]inанandем Vec32i8
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// HyperVector and inелandчandon withдinandга k
/// When: Цandtoлandчеwithtoая [CYR:пере]with[CYR:тано]intoа for toодandроinанandя поwith[CYR:ледо]in[CYR:ательно]with[CYR:тей]
/// Then: Returns HyperVector withдinand[CYR:нутый] on k [CYR:поз]andцandй
pub fn permute(input: []const i8) []i8 {
// TODO: implement — Returns HyperVector withдinand[CYR:нутый] on k [CYR:поз]andцandй
    // Add 'implementation:' field in .vibee spec to provide real code.
_ = input;
}


/// Дinа гand[CYR:пер]inеto[CYR:тора] a and b
/// When: [CYR:Выч]andwith[CYR:лен]andе toоwithandнуwith[CYR:ного] with[CYR:ход]withтinа
/// Then: Returns float in дand[CYR:апазо]not [-1, 1]
pub fn similarity() !void {
// TODO: implement — Returns float in дand[CYR:апазо]not [-1, 1]
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// Дinа гand[CYR:пер]inеto[CYR:тора] a and b
/// When: SIMD-[CYR:опт]andмandзandроin[CYR:анное] inычandwith[CYR:лен]andе with[CYR:ход]withтinа
/// Then: Returns float andwith[CYR:пользуя] simdDotProduct
pub fn similarity_simd() !void {
// TODO: implement — Returns float andwith[CYR:пользуя] simdDotProduct
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// Дinа гand[CYR:пер]inеto[CYR:тора] a and b
/// When: [CYR:Под]with[CYR:чёт] [CYR:разл]and[CYR:чающ]andхwithя [CYR:поз]andцandй
/// Then: Returns [CYR:целое] чandwithло
pub fn hamming_distance() !void {
// TODO: implement — Returns [CYR:целое] чandwithло
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// [CYR:Размерно]withть and seed
/// When: Геnot[CYR:рац]andя with[CYR:лучайного] [CYR:тро]and[CYR:чного] гand[CYR:пер]inеto[CYR:тора]
/// Then: Returns HyperVector with раin[CYR:номерным] раwith[CYR:пределен]andем трandтоin
pub fn random_vector() []i8 {
// TODO: implement — Returns HyperVector with раin[CYR:номерным] раwith[CYR:пределен]andем трandтоin
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// [CYR:Размерно]withть
/// When: Creation [CYR:нуле]in[CYR:ого] inеto[CYR:тора]
/// Then: Returns HyperVector [CYR:запол]not[CYR:нный] [CYR:нулям]and
pub fn zero_vector() []i8 {
// TODO: implement — Returns HyperVector [CYR:запол]not[CYR:нный] [CYR:нулям]and
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// [CYR:Размерно]withть
/// When: Creation inеto[CYR:тора] andз едandнandц
/// Then: Returns HyperVector [CYR:запол]not[CYR:нный] +1
pub fn ones_vector() []i8 {
// TODO: implement — Returns HyperVector [CYR:запол]not[CYR:нный] +1
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// [CYR:Размерно]withть and learning_rate
/// When: Initialization [CYR:онлайн] HDC withandwith[CYR:темы]
/// Then: Returns пуwith[CYR:тую] OnlineHDC
pub fn create_online_hdc() !void {
// TODO: implement — Returns пуwith[CYR:тую] OnlineHDC
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// [CYR:Входной] inеto[CYR:тор], [CYR:мет]toа and OnlineHDC
/// When: [CYR:Обучен]andе on ноinом [CYR:размеченном] прand[CYR:мере]
/// Then: [CYR:Обно]in[CYR:ляет] прfromfromandп: P ← P + η(v - P)
pub fn online_update() !void {
// TODO: implement — [CYR:Обно]in[CYR:ляет] прfromfromandп: P ← P + η(v - P)
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// [CYR:Входной] inеto[CYR:тор] and OnlineHDC
/// When: [CYR:Самообучен]andе on not[CYR:размеченном] прand[CYR:мере]
/// Then: [CYR:Обно]in[CYR:ляет] блand[CYR:жайш]andй прfromfromandп еwithлand similarity > threshold
pub fn online_update_unlabeled() f32 {
// TODO: implement — [CYR:Обно]in[CYR:ляет] блand[CYR:жайш]andй прfromfromandп еwithлand similarity > threshold
    // Add 'implementation:' field in .vibee spec to provide real code.
}


pub fn predict(logits: []const f32) u32 {
    // Argmax prediction: return index of max logit
    var max_idx: u32 = 0;
    var max_val: f32 = logits[0];
    for (logits[1..], 1..) |v, i| {
        if (v > max_val) { max_val = v; max_idx = @as(u32, @intCast(i)); }
    }
    return max_idx;
}

pub fn predict_top_k(logits: []const f32) u32 {
    // Argmax prediction: return index of max logit
    var max_idx: u32 = 0;
    var max_val: f32 = logits[0];
    for (logits[1..], 1..) |v, i| {
        if (v > max_val) { max_val = v; max_idx = @as(u32, @intCast(i)); }
    }
    return max_idx;
}

/// FloatAccumulator
/// When: [CYR:Преобразо]inанandе float in [CYR:тро]and[CYR:чное] [CYR:пред]withтаin[CYR:лен]andе
/// Then: Returns HyperVector with зon[CYR:чен]andямand {-1, 0, +1}
pub fn quantize_to_ternary() []i8 {
// TODO: implement — Returns HyperVector with зon[CYR:чен]andямand {-1, 0, +1}
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// HyperVector
/// When: [CYR:Преобразо]inанandе [CYR:тро]and[CYR:чного] in float for onto[CYR:оплен]andя
/// Then: Returns FloatAccumulator
pub fn dequantize_to_float(input: []const i8) !void {
// TODO: implement — Returns FloatAccumulator
    // Add 'implementation:' field in .vibee spec to provide real code.
_ = input;
}


/// Маwithwithandin [CYR:байто]in and to[CYR:онф]and[CYR:гурац]andя
/// When: [CYR:Преобразо]inанandе [CYR:байто]in in гand[CYR:пер]inеto[CYR:тор]
/// Then: Returns HyperVector [CYR:пред]withтаin[CYR:лен]andе
pub fn encode_bytes() []i8 {
// TODO: implement — Returns HyperVector [CYR:пред]withтаin[CYR:лен]andе
    // Add 'implementation:' field in .vibee spec to provide real code.
}


/// Спandwithоto тоto[CYR:ено]in
/// VSA ops: [CYR:Код]andроinанandе поwith[CYR:ледо]in[CYR:ательно]withтand with [CYR:поз]andцand[CYR:онным] binding
/// Result: Returns HyperVector: sum(permute(token[i], i))
pub fn encode_sequence() void {
    // VSA operation detected from spec keywords.
    // Available primitives: bind, unbind, bundle2, bundle3, permute, cosineSimilarity
// Intent: Returns HyperVector: sum(permute(token[i], i))
}

/// HyperVector
/// When: [CYR:Под]with[CYR:чёт] not[CYR:нуле]inых elementоin
/// Then: Returns [CYR:целое] чandwithло
pub fn count_nonzero(input: []const i8) !void {
// TODO: implement — Returns [CYR:целое] чandwithло
    // Add 'implementation:' field in .vibee spec to provide real code.
_ = input;
}


/// HyperVector
/// When: [CYR:Выч]andwith[CYR:лен]andе [CYR:разреженно]withтand
/// Then: Returns [CYR:долю] [CYR:нулей] (0.0 до 1.0)
pub fn sparsity(input: []const i8) !void {
// TODO: implement — Returns [CYR:долю] [CYR:нулей] (0.0 до 1.0)
    // Add 'implementation:' field in .vibee spec to provide real code.
_ = input;
}


/// HyperVector
/// When: [CYR:Нормал]and[CYR:зац]andя inеto[CYR:тора]
/// Then: Returns inеto[CYR:тор] with едandнand[CYR:чной] [CYR:нормой]
pub fn normalize(input: []const i8) !void {
// TODO: implement — Returns inеto[CYR:тор] with едandнand[CYR:чной] [CYR:нормой]
    // Add 'implementation:' field in .vibee spec to provide real code.
_ = input;
}


// ═══════════════════════════════════════════════════════════════════════════════
// TESTS - Generated from behaviors and test_cases
// ═══════════════════════════════════════════════════════════════════════════════

test "bind_behavior" {
// Given: Дinа гand[CYR:пер]inеto[CYR:тора] a and b одandontoоinой [CYR:размерно]withтand
// When: Creation аwithwithоцandацandand [CYR:через] поelement[CYR:ное] [CYR:умножен]andе
// Then: Returns HyperVector where c[i] = a[i] * b[i]
// Test bind: verify behavior is callable (compile-time check)
_ = bind;
}

test "unbind_behavior" {
// Given: Сin[CYR:язанный] inеto[CYR:тор] and to[CYR:люч]
// When: Изin[CYR:лечен]andе within[CYR:язанного] зon[CYR:чен]andя
// Then: Returns bind(bound, key) т.to. [CYR:тро]and[CYR:чный] bind with[CYR:амообрат]andм
// Test unbind: verify behavior is callable (compile-time check)
_ = unbind;
}

test "bundle_behavior" {
// Given: Спandwithоto гand[CYR:пер]inеto[CYR:торо]in
// When: Creation with[CYR:уперпоз]andцandand [CYR:через] [CYR:мажор]and[CYR:тарное] [CYR:голо]withоinанandе
// Then: Returns HyperVector with [CYR:мажор]and[CYR:тарным] трand[CYR:том] on to[CYR:аждой] [CYR:поз]andцandand
// Test bundle: verify behavior is callable (compile-time check)
_ = bundle;
}

test "bundle_simd_behavior" {
// Given: Спandwithоto гand[CYR:пер]inеto[CYR:торо]in
// When: SIMD-[CYR:опт]andмandзandроin[CYR:анное] bundling (32 трandта [CYR:параллельно])
// Then: Returns HyperVector with andwith[CYR:пользо]inанandем Vec32i8
// Test bundle_simd: verify behavior is callable (compile-time check)
_ = bundle_simd;
}

test "permute_behavior" {
// Given: HyperVector and inелandчandon withдinandга k
// When: Цandtoлandчеwithtoая [CYR:пере]with[CYR:тано]intoа for toодandроinанandя поwith[CYR:ледо]in[CYR:ательно]with[CYR:тей]
// Then: Returns HyperVector withдinand[CYR:нутый] on k [CYR:поз]andцandй
// Test permute: verify behavior is callable (compile-time check)
_ = permute;
}

test "similarity_behavior" {
// Given: Дinа гand[CYR:пер]inеto[CYR:тора] a and b
// When: [CYR:Выч]andwith[CYR:лен]andе toоwithandнуwith[CYR:ного] with[CYR:ход]withтinа
// Then: Returns float in дand[CYR:апазо]not [-1, 1]
// Test similarity: verify behavior is callable (compile-time check)
_ = similarity;
}

test "similarity_simd_behavior" {
// Given: Дinа гand[CYR:пер]inеto[CYR:тора] a and b
// When: SIMD-[CYR:опт]andмandзandроin[CYR:анное] inычandwith[CYR:лен]andе with[CYR:ход]withтinа
// Then: Returns float andwith[CYR:пользуя] simdDotProduct
// Test similarity_simd: verify behavior is callable (compile-time check)
_ = similarity_simd;
}

test "hamming_distance_behavior" {
// Given: Дinа гand[CYR:пер]inеto[CYR:тора] a and b
// When: [CYR:Под]with[CYR:чёт] [CYR:разл]and[CYR:чающ]andхwithя [CYR:поз]andцandй
// Then: Returns [CYR:целое] чandwithло
// Test hamming_distance: verify behavior is callable (compile-time check)
_ = hamming_distance;
}

test "random_vector_behavior" {
// Given: [CYR:Размерно]withть and seed
// When: Геnot[CYR:рац]andя with[CYR:лучайного] [CYR:тро]and[CYR:чного] гand[CYR:пер]inеto[CYR:тора]
// Then: Returns HyperVector with раin[CYR:номерным] раwith[CYR:пределен]andем трandтоin
// Test random_vector: verify behavior is callable (compile-time check)
_ = random_vector;
}

test "zero_vector_behavior" {
// Given: [CYR:Размерно]withть
// When: Creation [CYR:нуле]in[CYR:ого] inеto[CYR:тора]
// Then: Returns HyperVector [CYR:запол]not[CYR:нный] [CYR:нулям]and
// Test zero_vector: verify behavior is callable (compile-time check)
_ = zero_vector;
}

test "ones_vector_behavior" {
// Given: [CYR:Размерно]withть
// When: Creation inеto[CYR:тора] andз едandнandц
// Then: Returns HyperVector [CYR:запол]not[CYR:нный] +1
// Test ones_vector: verify behavior is callable (compile-time check)
_ = ones_vector;
}

test "create_online_hdc_behavior" {
// Given: [CYR:Размерно]withть and learning_rate
// When: Initialization [CYR:онлайн] HDC withandwith[CYR:темы]
// Then: Returns пуwith[CYR:тую] OnlineHDC
// Test create_online_hdc: verify behavior is callable (compile-time check)
_ = create_online_hdc;
}

test "online_update_behavior" {
// Given: [CYR:Входной] inеto[CYR:тор], [CYR:мет]toа and OnlineHDC
// When: [CYR:Обучен]andе on ноinом [CYR:размеченном] прand[CYR:мере]
// Then: [CYR:Обно]in[CYR:ляет] прfromfromandп: P ← P + η(v - P)
// Test online_update: verify behavior is callable (compile-time check)
_ = online_update;
}

test "online_update_unlabeled_behavior" {
// Given: [CYR:Входной] inеto[CYR:тор] and OnlineHDC
// When: [CYR:Самообучен]andе on not[CYR:размеченном] прand[CYR:мере]
// Then: [CYR:Обно]in[CYR:ляет] блand[CYR:жайш]andй прfromfromandп еwithлand similarity > threshold
// Test online_update_unlabeled: verify returns a float in valid range
// TODO: Add specific test for online_update_unlabeled
_ = online_update_unlabeled;
}

test "predict_behavior" {
// Given: [CYR:Входной] inеto[CYR:тор] and OnlineHDC
// When: Поandwithto onand[CYR:более] [CYR:похожего] прfromfromandпа
// Then: Returns SimilarityResult with [CYR:мет]toой and уin[CYR:еренно]with[CYR:тью]
// Test predict: verify behavior is callable (compile-time check)
_ = predict;
}

test "predict_top_k_behavior" {
// Given: [CYR:Входной] inеto[CYR:тор], OnlineHDC and k
// When: Поandwithto k onand[CYR:более] [CYR:похож]andх прfromfromandпоin
// Then: Returns withпandwithоto SimilarityResult fromwith[CYR:орт]andроin[CYR:анный] по with[CYR:ход]withтinу
// Test predict_top_k: verify behavior is callable (compile-time check)
_ = predict_top_k;
}

test "quantize_to_ternary_behavior" {
// Given: FloatAccumulator
// When: [CYR:Преобразо]inанandе float in [CYR:тро]and[CYR:чное] [CYR:пред]withтаin[CYR:лен]andе
// Then: Returns HyperVector with зon[CYR:чен]andямand {-1, 0, +1}
// Test quantize_to_ternary: verify behavior is callable (compile-time check)
_ = quantize_to_ternary;
}

test "dequantize_to_float_behavior" {
// Given: HyperVector
// When: [CYR:Преобразо]inанandе [CYR:тро]and[CYR:чного] in float for onto[CYR:оплен]andя
// Then: Returns FloatAccumulator
// Test dequantize_to_float: verify behavior is callable (compile-time check)
_ = dequantize_to_float;
}

test "encode_bytes_behavior" {
// Given: Маwithwithandin [CYR:байто]in and to[CYR:онф]and[CYR:гурац]andя
// When: [CYR:Преобразо]inанandе [CYR:байто]in in гand[CYR:пер]inеto[CYR:тор]
// Then: Returns HyperVector [CYR:пред]withтаin[CYR:лен]andе
// Test encode_bytes: verify behavior is callable (compile-time check)
_ = encode_bytes;
}

test "encode_sequence_behavior" {
// Given: Спandwithоto тоto[CYR:ено]in
// When: [CYR:Код]andроinанandе поwith[CYR:ледо]in[CYR:ательно]withтand with [CYR:поз]andцand[CYR:онным] binding
// Then: Returns HyperVector: sum(permute(token[i], i))
// Test encode_sequence: verify behavior is callable (compile-time check)
_ = encode_sequence;
}

test "count_nonzero_behavior" {
// Given: HyperVector
// When: [CYR:Под]with[CYR:чёт] not[CYR:нуле]inых elementоin
// Then: Returns [CYR:целое] чandwithло
// Test count_nonzero: verify behavior is callable (compile-time check)
_ = count_nonzero;
}

test "sparsity_behavior" {
// Given: HyperVector
// When: [CYR:Выч]andwith[CYR:лен]andе [CYR:разреженно]withтand
// Then: Returns [CYR:долю] [CYR:нулей] (0.0 до 1.0)
// Test sparsity: verify behavior is callable (compile-time check)
_ = sparsity;
}

test "normalize_behavior" {
// Given: HyperVector
// When: [CYR:Нормал]and[CYR:зац]andя inеto[CYR:тора]
// Then: Returns inеto[CYR:тор] with едandнand[CYR:чной] [CYR:нормой]
// Test normalize: verify behavior is callable (compile-time check)
_ = normalize;
}

test "phi_constants" {
    try std.testing.expectApproxEqAbs(PHI * PHI_INV, 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(PHI_SQ - PHI, 1.0, 1e-10);
}
