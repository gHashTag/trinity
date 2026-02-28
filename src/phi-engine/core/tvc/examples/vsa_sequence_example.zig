// VSA Sequence Encoding Example
// [CYR:[EN]]with[CYR:[EN]]and[EN] to[EN]and[EN]in[EN]and[EN] bywith[EN]beforein[CYR:[EN]]with[CYR:[EN]] with by[CYR:[EN]] permute
//
// [CYR:[EN]]withto: zig run vsa_sequence_example.zig

const std = @import("std");
const tvc_vsa = @import("../tvc_vsa.zig");
const HybridBigInt = tvc_vsa.HybridBigInt;

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         VSA Sequence Encoding Example                        ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 1. [CYR:[EN]]yes[EN] with[EN]in[CYR:[EN]] with[EN]in
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("1. [CYR:[EN]]yes[EN]and[EN] with[EN]in[CYR:[EN]] with[EN]in...\n", .{});

    var the = tvc_vsa.randomVector(256, 100);
    var cat = tvc_vsa.randomVector(256, 101);
    var sat = tvc_vsa.randomVector(256, 102);
    var on = tvc_vsa.randomVector(256, 103);
    var mat = tvc_vsa.randomVector(256, 104);
    var dog = tvc_vsa.randomVector(256, 105);
    var ran = tvc_vsa.randomVector(256, 106);

    std.debug.print("   [CYR:[EN]]in[EN]: the, cat, sat, on, mat, dog, ran\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 2. Encode [CYR:[EN]]and[EN] "the cat sat"
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("2. [CYR:[EN]]and[EN]in[EN]and[EN] [CYR:[EN]]and[EN] 'the cat sat'...\n", .{});
    std.debug.print("   [CYR:[EN]]: sentence = word[0] + permute(word[1], 1) + permute(word[2], 2)\n\n", .{});

    // [CYR:[EN]] encoding for demo[EN]with[CYR:[EN]]andand
    var p0 = the; // permute(the, 0) = the
    var p1 = tvc_vsa.permute(&cat, 1);
    var p2 = tvc_vsa.permute(&sat, 2);

    var temp = p0.add(&p1);
    var sentence1 = temp.add(&p2);

    std.debug.print("   sentence1 = the + permute(cat, 1) + permute(sat, 2)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. Check by[EN]and[EN]andand with[EN]in in [CYR:[EN]]andand
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("3. [CYR:[EN]]in[EN]to[EN] by[EN]and[EN]and[EN] with[EN]in in 'the cat sat'...\n\n", .{});

    // Check "the" on [CYR:[EN]] by[EN]and[EN]and[EN]
    std.debug.print("   [CYR:[EN]]in[EN] 'the':\n", .{});
    for (0..5) |pos| {
        const sim = tvc_vsa.probeSequence(&sentence1, &the, pos);
        const marker = if (pos == 0) " <-- [CYR:[EN]]inand[EN]on[EN] by[EN]and[EN]and[EN]" else "";
        std.debug.print("     by[EN]and[EN]and[EN] {}: {d:.4}{s}\n", .{ pos, sim, marker });
    }

    std.debug.print("\n   [CYR:[EN]]in[EN] 'cat':\n", .{});
    for (0..5) |pos| {
        const sim = tvc_vsa.probeSequence(&sentence1, &cat, pos);
        const marker = if (pos == 1) " <-- [CYR:[EN]]inand[EN]on[EN] by[EN]and[EN]and[EN]" else "";
        std.debug.print("     by[EN]and[EN]and[EN] {}: {d:.4}{s}\n", .{ pos, sim, marker });
    }

    std.debug.print("\n   [CYR:[EN]]in[EN] 'sat':\n", .{});
    for (0..5) |pos| {
        const sim = tvc_vsa.probeSequence(&sentence1, &sat, pos);
        const marker = if (pos == 2) " <-- [CYR:[EN]]inand[EN]on[EN] by[EN]and[EN]and[EN]" else "";
        std.debug.print("     by[EN]and[EN]and[EN] {}: {d:.4}{s}\n", .{ pos, sim, marker });
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. Encode in[CYR:[EN]] [CYR:[EN]]and[EN] "the dog ran"
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("\n4. [CYR:[EN]]and[EN]in[EN]and[EN] [CYR:[EN]]and[EN] 'the dog ran'...\n", .{});

    var items2 = [_]HybridBigInt{ the, dog, ran };
    var sentence2 = tvc_vsa.encodeSequence(&items2);

    std.debug.print("   sentence2 = encodeSequence([the, dog, ran])\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 5. Compare [CYR:[EN]]and[EN]
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("5. [CYR:[EN]]innot[EN]and[EN] [CYR:[EN]]and[EN]...\n", .{});

    const sim_sentences = tvc_vsa.cosineSimilarity(&sentence1, &sentence2);
    std.debug.print("   [CYR:[EN]]with[EN]in[EN] 'the cat sat' and 'the dog ran': {d:.4}\n", .{sim_sentences});
    std.debug.print("   ([CYR:[EN]] on[EN]andon[EN]with[EN] with 'the', bythis[EN] [EN]with[EN] nottofrom[CYR:[EN]] with[CYR:[EN]]with[EN]in[EN])\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 6. [CYR:[EN]]with[CYR:[EN]]and[EN] permute/inverse_permute
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("6. [CYR:[EN]]with[CYR:[EN]]and[EN] permute/inverse_permute...\n", .{});

    var original = tvc_vsa.randomVector(256, 999);
    var shifted = tvc_vsa.permute(&original, 7);
    var recovered = tvc_vsa.inversePermute(&shifted, 7);

    const sim_original = tvc_vsa.cosineSimilarity(&original, &recovered);
    std.debug.print("   original -> permute(7) -> inverse_permute(7) -> recovered\n", .{});
    std.debug.print("   [CYR:[EN]]with[EN]in[EN] original and recovered: {d:.4}\n", .{sim_original});
    std.debug.print("   ([CYR:[EN]] [CYR:[EN]] ~1.0, [EN].to. inverse_permute from[CYR:[EN]] permute)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 7. [EN]thaton[CYR:[EN]]with[EN] permuted in[EN]to[CYR:[EN]]in
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("7. [EN]thaton[CYR:[EN]]with[EN] permuted in[EN]to[CYR:[EN]]in...\n", .{});

    var v = tvc_vsa.randomVector(256, 12345);
    var v_p1 = tvc_vsa.permute(&v, 1);
    var v_p10 = tvc_vsa.permute(&v, 10);
    var v_p50 = tvc_vsa.permute(&v, 50);

    std.debug.print("   [CYR:[EN]]with[EN]in[EN] v and permute(v, 1):  {d:.4}\n", .{tvc_vsa.cosineSimilarity(&v, &v_p1)});
    std.debug.print("   [CYR:[EN]]with[EN]in[EN] v and permute(v, 10): {d:.4}\n", .{tvc_vsa.cosineSimilarity(&v, &v_p10)});
    std.debug.print("   [CYR:[EN]]with[EN]in[EN] v and permute(v, 50): {d:.4}\n", .{tvc_vsa.cosineSimilarity(&v, &v_p50)});
    std.debug.print("   (Permuted in[EN]to[CYR:[EN]] by[EN]and [EN]thaton[CYR:[EN]] [EN]and[EN]andon[EN])\n\n", .{});

    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    [EN]and[CYR:[EN]] [EN]in[CYR:[EN]]                           ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}
