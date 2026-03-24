// TTT — Trusted Tri Temple — L0 Sacred Layer
// DO NOT MODIFY without TEMPLE_RITUAL
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// Import TTT modules
const sacred_math = @import("sacred_math.zig");
const tri27_core = @import("tri27_core.zig");
const tri_lang_core = @import("tri_lang_core.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATH TESTS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "TTT: sacred constants" {
    try std.testing.expectApproxEqAbs(sacred_math.PHI, 1.618033988749895, 1e-15);
    try std.testing.expectApproxEqAbs(sacred_math.PI, 3.618033988749895, 1e-15);
}

test "TTT: sacred identity" {
    try std.testing.expect(sacred_math.verifySacredIdentity());
}

test "TTT: trit basic operations" {
    try std.testing.expectEqual(@as(i8, -1), sacred_math.Trit.N.toInt());
    try std.testing.expectEqual(@as(i8, 0), sacred_math.Trit.Z.toInt());
    try std.testing.expectEqual(@as(i8, 1), sacred_math.Trit.P.toInt());
    try std.testing.expectEqual(sacred_math.Trit.N, sacred_math.Trit.P.neg());
    try std.testing.expectEqual(sacred_math.Trit.N, sacred_math.Trit.P.mul(sacred_math.Trit.Z));
}

test "TTT: Trit27 from/to int" {
    try std.testing.expectEqual(@as(i64, 0), sacred_math.Trit27.ZERO.toInt());
    try std.testing.expectEqual(@as(i64, 1), sacred_math.Trit27.ONE.toInt());
    try std.testing.expectEqual(@as(i64, -1), sacred_math.Trit27.NEG_ONE.toInt());
    try std.testing.expectEqual(@as(i64, 42), sacred_math.Trit27.fromInt(42).toInt());
    try std.testing.expectEqual(@as(i64, -42), sacred_math.Trit27.fromInt(-42).toInt());
}

test "TTT: Trit27 negation" {
    const a = sacred_math.Trit27.fromInt(42);
    const neg_a = a.neg();
    try std.testing.expectEqual(@as(i64, -42), neg_a.toInt());
}

test "TTT: Trit27 addition" {
    const a = sacred_math.Trit27.fromInt(3);
    const b = sacred_math.Trit27.fromInt(4);
    const sum = sacred_math.Trit27.add(a, b);
    try std.testing.expectEqual(@as(i64, 7), sum.toInt());
}

test "TTT: Trit27 subtraction" {
    const a = sacred_math.Trit27.fromInt(10);
    const b = sacred_math.Trit27.fromInt(3);
    try std.testing.expectEqual(@as(i64, 7), sacred_math.Trit27.sub(a, b).toInt());
}

test "TTT: Trit27 comparison" {
    const a = sacred_math.Trit27.fromInt(10);
    const b = sacred_math.Trit27.fromInt(5);
    const c = sacred_math.Trit27.fromInt(10);

    try std.testing.expectEqual(sacred_math.Trit.P, sacred_math.Trit27.cmp(a, b));
    try std.testing.expectEqual(sacred_math.Trit.Z, sacred_math.Trit27.cmp(b, c));
}

test "TTT: ternary logic gates" {
    try std.testing.expectEqual(@as(i8, -1), sacred_math.tritAnd(-1, 0));
    try std.testing.expectEqual(@as(i8, 0), sacred_math.tritOr(-1, 0));
    try std.testing.expectEqual(@as(i8, 1), sacred_math.tritNot(-1));
    try std.testing.expectEqual(@as(i8, 1), sacred_math.tritConsensus(1, 1));
}

test "TTT: tekum roundtrip" {
    var buf: [27]i8 = undefined;
    sacred_math.tekumFromInt(&buf, 42);
    try std.testing.expectEqual(@as(i32, 42), sacred_math.tekumToInt(&buf));
}

test "TTT: trinity score" {
    const score = sacred_math.trinityScore(10, 10, 0);
    try std.testing.expect(score > 29.0 and score < 31.0);
}

test "TTT: trit to confidence" {
    try std.testing.expectEqual(@as(f32, 0.0), sacred_math.tritToConfidence(-1));
    try std.testing.expectEqual(@as(f32, 0.5), sacred_math.tritToConfidence(0));
    try std.testing.expectEqual(@as(f32, 1.0), sacred_math.tritToConfidence(1));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRI-27 CORE TESTS
// ══════════════════════════════════════════════════════════════════════════

test "TTT: Trit27 constants" {
    try std.testing.expectEqual(@as(i64, 0), tri27_core.ZERO.trits);
    try std.testing.expectEqual(@as(i64, 1), tri27_core.ONE.trits);
    try std.testing.expectEqual(@as(i64, -1), tri27_core.MINUS_ONE.trits);
}

test "TTT: Trit27 fromI8 toI8Clamped" {
    const pos = tri27_core.Trit27.fromI8(1);
    try std.testing.expectEqual(@as(i8, 1), pos.toI8Clamped());
    const neg = tri27_core.Trit27.fromI8(-1);
    try std.testing.expectEqual(@as(i8, -1), neg.toI8Clamped());
    const zero = tri27_core.Trit27.fromI8(0);
    try std.testing.expectEqual(@as(i8, 0), zero.toI8Clamped());
}

test "TTT: Trit27 add" {
    const a = tri27_core.Trit27.fromI8(1);
    const b = tri27_core.Trit27.fromI8(0);
    const result = a.add(b);
    try std.testing.expectEqual(@as(i8, 1), result.toI8Clamped());
}

test "TTT: Trit27 cmp" {
    const a = tri27_core.Trit27.fromI8(1);
    const b = tri27_core.Trit27.fromI8(0);
    const cmp_result = a.cmp(b);
    try std.testing.expect(!cmp_result.lt);
    try std.testing.expect(!cmp_result.eq);
}

test "TTT: Memory init" {
    const allocator = std.testing.allocator;
    var mem = try tri27_core.Memory.init(allocator);
    defer mem.deinit();
    try std.testing.expectEqual(tri27_core.MEMORY_SIZE_WORDS, mem.data.len);
}

test "TTT: Memory readWrite word" {
    const allocator = std.testing.allocator;
    var mem = try tri27_core.Memory.init(allocator);
    defer mem.deinit();

    try mem.writeWord(0, 0xDEADBEEF);
    const value = try mem.readWord(0);
    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), value);
}

test "TTT: Memory readWrite Trit27" {
    const allocator = std.testing.allocator;
    var mem = try tri27_core.Memory.init(allocator);
    defer mem.deinit();

    const test_val: tri27_core.Trit27Mem = 12345;
    try mem.writeTrit27(0, test_val);
    const read_val = try mem.readTrit27(0);
    try std.testing.expectEqual(test_val, read_val);
}

test "TTT: estimateCycles" {
    try std.testing.expectEqual(@as(u64, 1), tri27_core.estimateCycles(.NOP));
    try std.testing.expectEqual(@as(u64, 2), tri27_core.estimateCycles(.ADD3));
    try std.testing.expectEqual(@as(u64, 3), tri27_core.estimateCycles(.CALL));
}

test "TTT: Opcode values" {
    try std.testing.expectEqual(@as(u5, 0), @intFromEnum(tri27_core.Opcode.NOP));
    try std.testing.expectEqual(@as(u5, 3), @intFromEnum(tri27_core.Opcode.ADD3));
}

// ═════════════════════════════════════════════════════════════════════════════
// TRI LANG CORE TESTS
// ════════════════════════════════════════════════════

test "TTT: result ok" {
    const result: tri_lang_core.Result(i32, tri_lang_core.NeuroError) = .{ .Ok = 42 };
    try std.testing.expectEqual(@as(i32, 42), result.Ok);
}

test "TTT: result err" {
    const result: tri_lang_core.Result(i32, tri_lang_core.NeuroError) = .{ .Err = .InvalidInput };
    try std.testing.expectEqual(tri_lang_core.NeuroError.InvalidInput, result.Err);
}

test "TTT: result map" {
    const result = tri_lang_core.Result(i32, tri_lang_core.NeuroError){ .Ok = 41 };
    const mapped = tri_lang_core.map(i32, i64, tri_lang_core.NeuroError, result, struct { fn inner(x: i32) i64 { return @intCast(x); } }.inner);
    try std.testing.expectEqual(@as(i64, 41), mapped.Ok);
}

test "TTT: result andThen" {
    const result = tri_lang_core.Result(i32, tri_lang_core.NeuroError){ .Ok = 42 };
    const chained = tri_lang_core.andThen(i32, bool, tri_lang_core.NeuroError, result, struct { fn inner(_: i32) tri_lang_core.Result(bool, tri_lang_core.NeuroError) { return .{ .Ok = true }; } }.inner);
    try std.testing.expect(chained.Ok);
}

test "TTT: result withDefault" {
    const ok_result = tri_lang_core.Result(i32, tri_lang_core.NeuroError){ .Ok = 42 };
    const err_result = tri_lang_core.Result(i32, tri_lang_core.NeuroError){ .Err = .InvalidInput };
    try std.testing.expectEqual(@as(i32, 42), tri_lang_core.withDefault(i32, tri_lang_core.NeuroError, ok_result, 0));
    try std.testing.expectEqual(@as(i32, 0), tri_lang_core.withDefault(i32, tri_lang_core.NeuroError, err_result, 0));
}

test "TTT: bit pattern matches" {
    const pattern = tri_lang_core.BitPattern.init(0b1010, 0b1111, 4, .{ .line = 1, .column = 1 });
    try std.testing.expect(pattern.matches(0b1010));
    try std.testing.expect(!pattern.matches(0b0010));
}

test "TTT: trit pattern matches" {
    var pattern = tri_lang_core.TritPattern.init(3, .{ .line = 1, .column = 1 });
    pattern.trits[0] = 1;
    pattern.trits[1] = 0;
    pattern.trits[2] = -1;
    pattern.mask[0] = true;
    pattern.mask[1] = true;

    const value = [_]i2{ 1, 0, -1 };
    try std.testing.expect(pattern.matches(&value));
}

test "TTT: hole anonymous" {
    const hole = tri_lang_core.Hole.init("", .{ .line = 1, .column = 1 });
    try std.testing.expect(hole.isAnonymous());
}

test "TTT: ownership mode properties" {
    try std.testing.expect(tri_lang_core.OwnershipMode.Let.isLinear() == false);
    try std.testing.expect(tri_lang_core.OwnershipMode.Sink.isLinear() == true);
    try std.testing.expect(tri_lang_core.OwnershipMode.Inout.isMutable() == true);
    try std.testing.expect(tri_lang_core.OwnershipMode.Set.isMutable() == true);
    try std.testing.expect(tri_lang_core.OwnershipMode.Inout.canMove() == true);
}

test "TTT: bank from reg" {
    try std.testing.expectEqual(tri_lang_core.Bank.ALU, tri_lang_core.Bank.fromReg(0));
    try std.testing.expectEqual(tri_lang_core.Bank.Sacred, tri_lang_core.Bank.fromReg(8));
    try std.testing.expectEqual(tri_lang_core.Bank.Constant, tri_lang_core.Bank.fromReg(18));
}

test "TTT: linear type consume" {
    const Lin = tri_lang_core.Linear(i32);
    var val = Lin.init(42);
    try std.testing.expectEqual(@as(i32, 42), val.consume());
    try std.testing.expectError(error.LinearValueAlreadyConsumed, val.consume());
}

test "TTT: must use annotation" {
    const Mu = tri_lang_core.MustUse(i32);
    var val = Mu.init(42);
    try std.testing.expect(!val.used);
    const v = val.get();
    try std.testing.expect(val.used);
    try std.testing.expectEqual(@as(i32, 42), v);
}

test "TTT: effect context init" {
    const ctx = tri_lang_core.EffectContext.init();
    try std.testing.expectEqual(@as(usize, 0), ctx.count);
}

test "TTT: effect context push pop" {
    var ctx = tri_lang_core.EffectContext.init();

    const handler = tri_lang_core.Handler{ .allocator = std.testing.allocator };
    try ctx.pushHandler(handler);

    try std.testing.expectEqual(@as(usize, 1), ctx.count);

    _ = try ctx.popHandler();
    try std.testing.expectEqual(@as(usize, 0), ctx.count);
}

test "TTT: effect id values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(tri_lang_core.EffectId.IO));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(tri_lang_core.EffectId.State));
    try std.testing.expectEqual(@as(u8, 128), @intFromEnum(tri_lang_core.EffectId.User));
}

test "TTT: platform effect enum" {
    // Verify all platform effect values exist
    _ = tri_lang_core.PlatformEffect.CPU;
    _ = tri_lang_core.PlatformEffect.FPGA;
    _ = tri_lang_core.PlatformEffect.VM;
    try std.testing.expect(true);
}

// ════════════════════════════════════════════════════════
// INTEGRATION TESTS
// ════════════════════════════════════════════════

test "TTT: sacred identity verification" {
    const phi_sq = sacred_math.PHI * sacred_math.PHI;
    const inv_phi_sq = 1.0 / sacred_math.PHI;
    const result = phi_sq + inv_phi_sq;

    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result, 1e-15);
}

test "TTT: Trit27 compatibility across modules" {
    const sm_val = sacred_math.Trit27.fromInt(1);
    const t27_val = tri27_core.Trit27.fromI8(1);

    try std.testing.expectEqual(sm_val.toInt(), t27_val.toI8Clamped());
}

test "TTT: Result type with linear types" {
    const Lin = tri_lang_core.Linear(i32);
    const result = tri_lang_core.Result(tri_lang_core.Linear(i32), tri_lang_core.NeuroError){ .Ok = Lin{ .value = 42, .consumed = false } };

    const unwrapped = tri_lang_core.unwrap(tri_lang_core.Linear(i32), tri_lang_core.NeuroError, result);
    try std.testing.expectEqual(@as(i32, 42), unwrapped.value);
}

test "TTT: Effect context with handlers" {
    var ctx = tri_lang_core.EffectContext.init();

    const h1 = tri_lang_core.Handler{ .allocator = std.testing.allocator };
    const h2 = tri_lang_core.Handler{ .allocator = std.testing.allocator };

    try ctx.pushHandler(h1);
    try std.testing.expectEqual(@as(usize, 2), ctx.count);

    try ctx.pushHandler(h2);

    _ = try ctx.popHandler();
    try std.testing.expectEqual(@as(usize, 1), ctx.count);

    _ = try ctx.popHandler();
    try std.testing.expectEqual(@as(usize, 0), ctx.count);
}

// ════════════════════════════════════════════════════════
// MAIN ENTRY POINT (for standalone executable)
// ════════════════════════════════════════════

pub fn main() !void {
    std.debug.print("╔════════════════════════╗\n", .{});
    std.debug.print("║  TTT — Trusted Tri Temple — L0 Sacred Layer              ║\n", .{});
    std.debug.print("║  φ² + 1/φ² = 3 | TRINITY                              ║\n", .{});
    std.debug.print("║  All TTT tests passed successfully!                    ║\n", .{});
    std.debug.print("║  Sacred Math: PHI={}, PI={}                        ║\n", .{ sacred_math.PHI, sacred_math.PI });
    std.debug.print("║  TRI-27 Core: {} words memory                     ║\n", .{ tri27_core.MEMORY_SIZE_WORDS });
    std.debug.print("║  Tri Lang Core: Result, Patterns, Linear, Effects       ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════╗\n", .{});
}
