// VSA Sequence Encoding Example
// [CYR:Демон]with[CYR:трац]andя toодandроinанandя bywithлеbeforein[CYR:ательно]with[CYR:тей] with by[CYR:мощью] permute
//
// [CYR:Запу]withto: zig run vsa_sequence_example.zig

const std = @import("std");
const tvc_vsa = @import("../tvc_vsa.zig");
const HybridBigInt = tvc_vsa.HybridBigInt;

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         VSA Sequence Encoding Example                        ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 1. [CYR:Соз]yesём withлоin[CYR:арь] withлоin
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("1. [CYR:Соз]yesнandе withлоin[CYR:аря] withлоin...\n", .{});

    var the = tvc_vsa.randomVector(256, 100);
    var cat = tvc_vsa.randomVector(256, 101);
    var sat = tvc_vsa.randomVector(256, 102);
    var on = tvc_vsa.randomVector(256, 103);
    var mat = tvc_vsa.randomVector(256, 104);
    var dog = tvc_vsa.randomVector(256, 105);
    var ran = tvc_vsa.randomVector(256, 106);

    std.debug.print("   [CYR:Сло]inа: the, cat, sat, on, mat, dog, ran\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 2. Encode [CYR:предложен]andе "the cat sat"
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("2. [CYR:Код]andроinанandе [CYR:предложен]andя 'the cat sat'...\n", .{});
    std.debug.print("   [CYR:Формула]: sentence = word[0] + permute(word[1], 1) + permute(word[2], 2)\n\n", .{});

    // [CYR:Ручное] encoding for demoнwith[CYR:трац]andand
    var p0 = the; // permute(the, 0) = the
    var p1 = tvc_vsa.permute(&cat, 1);
    var p2 = tvc_vsa.permute(&sat, 2);

    var temp = p0.add(&p1);
    var sentence1 = temp.add(&p2);

    std.debug.print("   sentence1 = the + permute(cat, 1) + permute(sat, 2)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. Check byзandцandand withлоin in [CYR:предложен]andand
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("3. [CYR:Про]inерtoа byзandцandй withлоin in 'the cat sat'...\n\n", .{});

    // Check "the" on [CYR:разных] byзandцandях
    std.debug.print("   [CYR:Сло]inо 'the':\n", .{});
    for (0..5) |pos| {
        const sim = tvc_vsa.probeSequence(&sentence1, &the, pos);
        const marker = if (pos == 0) " <-- [CYR:пра]inandльonя byзandцandя" else "";
        std.debug.print("     byзandцandя {}: {d:.4}{s}\n", .{ pos, sim, marker });
    }

    std.debug.print("\n   [CYR:Сло]inо 'cat':\n", .{});
    for (0..5) |pos| {
        const sim = tvc_vsa.probeSequence(&sentence1, &cat, pos);
        const marker = if (pos == 1) " <-- [CYR:пра]inandльonя byзandцandя" else "";
        std.debug.print("     byзandцandя {}: {d:.4}{s}\n", .{ pos, sim, marker });
    }

    std.debug.print("\n   [CYR:Сло]inо 'sat':\n", .{});
    for (0..5) |pos| {
        const sim = tvc_vsa.probeSequence(&sentence1, &sat, pos);
        const marker = if (pos == 2) " <-- [CYR:пра]inandльonя byзandцandя" else "";
        std.debug.print("     byзandцandя {}: {d:.4}{s}\n", .{ pos, sim, marker });
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. Encode in[CYR:торое] [CYR:предложен]andе "the dog ran"
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("\n4. [CYR:Код]andроinанandе [CYR:предложен]andя 'the dog ran'...\n", .{});

    var items2 = [_]HybridBigInt{ the, dog, ran };
    var sentence2 = tvc_vsa.encodeSequence(&items2);

    std.debug.print("   sentence2 = encodeSequence([the, dog, ran])\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 5. Compare [CYR:предложен]andя
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("5. [CYR:Сра]innotнandе [CYR:предложен]andй...\n", .{});

    const sim_sentences = tvc_vsa.cosineSimilarity(&sentence1, &sentence2);
    std.debug.print("   [CYR:Сход]withтinо 'the cat sat' and 'the dog ran': {d:.4}\n", .{sim_sentences});
    std.debug.print("   ([CYR:Оба] onчandonютwithя with 'the', bythisму еwithть nottofrom[CYR:орое] with[CYR:ход]withтinо)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 6. [CYR:Демон]with[CYR:трац]andя permute/inverse_permute
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("6. [CYR:Демон]with[CYR:трац]andя permute/inverse_permute...\n", .{});

    var original = tvc_vsa.randomVector(256, 999);
    var shifted = tvc_vsa.permute(&original, 7);
    var recovered = tvc_vsa.inversePermute(&shifted, 7);

    const sim_original = tvc_vsa.cosineSimilarity(&original, &recovered);
    std.debug.print("   original -> permute(7) -> inverse_permute(7) -> recovered\n", .{});
    std.debug.print("   [CYR:Сход]withтinо original and recovered: {d:.4}\n", .{sim_original});
    std.debug.print("   ([CYR:Должно] [CYR:быть] ~1.0, т.to. inverse_permute from[CYR:меняет] permute)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 7. Орthaton[CYR:льно]withть permuted inеto[CYR:торо]in
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("7. Орthaton[CYR:льно]withть permuted inеto[CYR:торо]in...\n", .{});

    var v = tvc_vsa.randomVector(256, 12345);
    var v_p1 = tvc_vsa.permute(&v, 1);
    var v_p10 = tvc_vsa.permute(&v, 10);
    var v_p50 = tvc_vsa.permute(&v, 50);

    std.debug.print("   [CYR:Сход]withтinо v and permute(v, 1):  {d:.4}\n", .{tvc_vsa.cosineSimilarity(&v, &v_p1)});
    std.debug.print("   [CYR:Сход]withтinо v and permute(v, 10): {d:.4}\n", .{tvc_vsa.cosineSimilarity(&v, &v_p10)});
    std.debug.print("   [CYR:Сход]withтinо v and permute(v, 50): {d:.4}\n", .{tvc_vsa.cosineSimilarity(&v, &v_p50)});
    std.debug.print("   (Permuted inеto[CYR:торы] byчтand орthaton[CYR:льны] орandгandonлу)\n\n", .{});

    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    Прand[CYR:мер] заin[CYR:ершён]                           ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}
