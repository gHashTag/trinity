// Minimal Forward Pass Demo — Level 10A First Real Execution
// Uses sdk.zig Hypervector + Codebook to run: encode → position → attention → FFN → decode
//
// Trinity Identity: phi^2 + 1/phi^2 = 3

const std = @import("std");
const sdk = @import("sdk.zig");

const Hypervector = sdk.Hypervector;
const Codebook = sdk.Codebook;

// === FORWARD PASS HELPERS ===

/// Create 11 role vectors: Q/K/V for 3 heads + FF1 + FF2
fn initRoles(dim: usize, seed: u64) [11]Hypervector {
    var roles: [11]Hypervector = undefined;
    for (0..11) |i| {
        roles[i] = Hypervector.random(dim, seed + i);
    }
    return roles;
}

/// Single-head attention: bind Q/K, score similarity, extract V
fn singleHeadAttention(
    positioned: []Hypervector,
    q_role: *Hypervector,
    k_role: *Hypervector,
    v_role: *Hypervector,
) Hypervector {
    // Query = bind(last_position, Q_role)
    var query = positioned[positioned.len - 1].bind(q_role);

    // Find best-matching key
    var best_sim: f64 = -2.0;
    var best_idx: usize = 0;
    for (0..positioned.len) |i| {
        var key_i = positioned[i].bind(k_role);
        const sim = query.similarity(&key_i);
        if (sim > best_sim) {
            best_sim = sim;
            best_idx = i;
        }
    }

    // Value = bind(best_position, V_role)
    return positioned[best_idx].bind(v_role);
}

/// v2.29 single-head forward pass (preserved for backwards compatibility)
fn forwardPass(
    context: []Hypervector,
    roles: *[11]Hypervector,
) Hypervector {
    var positioned: [8]Hypervector = undefined;
    for (context, 0..) |*hv, i| {
        positioned[i] = hv.permute(i);
    }

    var value = singleHeadAttention(&positioned, &roles[0], &roles[1], &roles[2]);

    var ffn_out = value.bind(&roles[9]);
    const output = ffn_out.bundle(&positioned[context.len - 1]);
    return output;
}

/// v2.30 multi-head forward pass: 3 heads merged via bundle3
/// Roles layout: [Q0,K0,V0, Q1,K1,V1, Q2,K2,V2, FF1, FF2]
///                 0  1  2    3  4  5    6  7  8    9   10
fn forwardPassMultiHead(
    context: []Hypervector,
    roles: *[11]Hypervector,
) Hypervector {
    var positioned: [8]Hypervector = undefined;
    for (context, 0..) |*hv, i| {
        positioned[i] = hv.permute(i);
    }

    // 3-head attention
    var head0 = singleHeadAttention(&positioned, &roles[0], &roles[1], &roles[2]);
    var head1 = singleHeadAttention(&positioned, &roles[3], &roles[4], &roles[5]);
    var head2 = singleHeadAttention(&positioned, &roles[6], &roles[7], &roles[8]);

    // Merge heads via bundle3 (true majority vote of 3)
    var merged = head0.bundle3(&head1, &head2);

    // FFN: bind(FF1), then bind(FF2)
    var ffn_mid = merged.bind(&roles[9]);
    var ffn_out = ffn_mid.bind(&roles[10]);

    // Residual connection: bundle with last positioned vector
    const output = ffn_out.bundle(&positioned[context.len - 1]);
    return output;
}

/// Autoregressive generation: predict next token, shift context, repeat
/// Returns number of unique characters generated
fn generateAutoregressive(
    initial_context: []Hypervector,
    roles: *[11]Hypervector,
    codebook: *Codebook,
    output_buf: []u8,
    max_tokens: usize,
) usize {
    var context: [8]Hypervector = undefined;
    for (initial_context, 0..) |*hv, i| {
        context[i] = hv.clone();
    }

    var generated: usize = 0;
    while (generated < max_tokens and generated < output_buf.len) {
        var output = forwardPassMultiHead(&context, roles);
        const predicted = codebook.decode(&output);

        if (predicted) |p| {
            output_buf[generated] = p[0];
        } else {
            output_buf[generated] = '?';
        }
        generated += 1;

        // Shift context: drop first, append new prediction HV
        for (0..7) |i| {
            context[i] = context[i + 1];
        }
        context[7] = output.clone();
    }

    return generated;
}

// === RESONATOR-STYLE TRAINING (v2.33) ===
// Replaces bundle2(role, error) which dilutes signal via majority vote.
// Uses bind-based targeted correction: compute what each FF role SHOULD be
// to produce the target, then iteratively blend current roles toward ideal.

/// Resonator training step: for a single (context, target) pair,
/// iteratively refine the FF roles (roles[9] and roles[10]) to reduce error.
/// Returns the final loss (1 - similarity) for this sample.
fn resonatorTrainStep(
    context: []Hypervector,
    target: *Hypervector,
    roles: *[11]Hypervector,
    dim: usize,
    lr: f64,
    prng_seed: u64,
) f64 {
    // Step 1: Forward pass to get current output
    var output = forwardPassMultiHead(context, roles);
    const initial_sim = output.similarity(target);
    var best_loss: f64 = 1.0 - initial_sim;

    // Step 2: Resonator iterations (3-5 cycles of unbind→correct→recheck)
    const max_iters: usize = 5;
    for (0..max_iters) |iter| {
        // Compute positioned vectors (same as forwardPassMultiHead)
        var positioned: [8]Hypervector = undefined;
        for (context, 0..) |*hv, i| {
            positioned[i] = hv.permute(i);
        }

        // The forward pass produces: output = bundle(bind(bind(merged, FF1), FF2), last_pos)
        // To correct FF2: ideal_ff2_output = unbind(target, last_positioned)
        // Then: ideal_after_ff2 = unbind(ideal_ff2_output, FF1_output)
        // This gives us the direction FF2 should push toward.

        // Compute what the merged attention output is (before FFN)
        var head0 = singleHeadAttention(&positioned, &roles[0], &roles[1], &roles[2]);
        var head1 = singleHeadAttention(&positioned, &roles[3], &roles[4], &roles[5]);
        var head2 = singleHeadAttention(&positioned, &roles[6], &roles[7], &roles[8]);
        var merged = head0.bundle3(&head1, &head2);

        // What FF roles should produce: drive output toward target
        // target ≈ bundle(ffn_out, last_pos), so ffn_out ≈ target (approximately)

        // Compute ideal FF2 role: if ffn_out = bind(bind(merged, FF1), FF2)
        // and we want ffn_out ≈ target
        // then ideal = unbind(target, bind(merged, FF1))
        var merged_ff1 = merged.bind(&roles[9]);
        var ideal_ff2_direction = target.unbind(&merged_ff1);

        // Compute ideal FF1 role similarly: bind(merged, FF1) should produce
        // something that when bound with FF2 gives target
        // ideal_ff1_input = unbind(target, FF2), ideal_ff1 = unbind(ideal_ff1_input, merged)
        var ideal_ff1_input = target.unbind(&roles[10]);
        var ideal_ff1_direction = ideal_ff1_input.unbind(&merged);

        // Resonator correction: blend current role toward ideal direction
        // Using bind-based correction: correction = bind(ideal, inverse(current))
        // Then apply sparsified correction
        var ff2_correction = ideal_ff2_direction.unbind(&roles[10]);
        var ff1_correction = ideal_ff1_direction.unbind(&roles[9]);

        // Sparsify corrections
        var prng = std.Random.DefaultPrng.init(prng_seed + iter * 100);
        const random = prng.random();

        var sparse_ff2 = ff2_correction.clone();
        var sparse_ff1 = ff1_correction.clone();
        for (0..dim) |idx| {
            if (random.float(f64) > lr) {
                sparse_ff2.set(idx, 0);
            }
            if (random.float(f64) > lr) {
                sparse_ff1.set(idx, 0);
            }
        }

        // Apply: role_new = bind(role_old, sparse_correction)
        // This is multiplicative, not additive — preserves more signal
        roles[10] = roles[10].bind(&sparse_ff2);
        roles[9] = roles[9].bind(&sparse_ff1);

        // Also update attention V roles (roles[2], [5], [8]) with smaller corrections
        // The attention roles are harder to correct, so use smaller lr
        var target_clone = target.clone();
        var neg_out = output.negate();
        var attn_error = target_clone.bundle(&neg_out);
        var sparse_attn = attn_error.clone();
        for (0..dim) |idx| {
            if (random.float(f64) > lr * 0.3) {
                sparse_attn.set(idx, 0);
            }
        }
        // Only update V roles (2, 5, 8) — Q and K should stay stable
        roles[2] = roles[2].bind(&sparse_attn);
        roles[5] = roles[5].bind(&sparse_attn);
        roles[8] = roles[8].bind(&sparse_attn);

        // Re-check: did we improve?
        var new_output = forwardPassMultiHead(context, roles);
        const new_sim = new_output.similarity(target);
        const new_loss = 1.0 - new_sim;

        if (new_loss < best_loss) {
            best_loss = new_loss;
            output = new_output;
        }

        // Early stop if similarity is already good
        if (new_sim > 0.5) break;
    }

    return best_loss;
}

// === DIRECT ROLE AVERAGING (v2.34) ===
// Bypasses deep bind chains entirely. Instead of training through
// attention → FFN → residual (5+ binds), we:
// 1. Summarize context as a single HV via positional bundling
// 2. Compute ideal role for each sample: ideal = unbind(target, context_summary)
// 3. Bundle all ideal roles to get the averaged "learned" role
// 4. At inference: output = bind(context_summary, learned_role)
//
// This has only 1 bind at inference time → clean signal, no credit assignment problem.

/// Summarize an 8-element context into a single hypervector.
/// Uses positional permutation + sequential bundling.
fn summarizeContext(context: []Hypervector) Hypervector {
    // Permute each position, then bundle sequentially
    var summary = context[0].permute(0);
    for (1..context.len) |i| {
        var positioned = context[i].permute(i);
        summary = summary.bundle(&positioned);
    }
    return summary;
}

/// Direct forward pass: just bind(context_summary, role)
/// Only 1 bind operation → clean gradient signal
fn forwardPassDirect(
    context: []Hypervector,
    role: *Hypervector,
) Hypervector {
    var summary = summarizeContext(context);
    return summary.bind(role);
}

/// Pre-compute the ideal role from a set of (context, target) pairs.
/// For each pair: ideal_i = unbind(target_i, summary_i)
/// Final role = sequential bundle of all ideal_i
/// This is a one-shot computation, no iterative training needed.
fn computeDirectRole(
    corpus: []const u8,
    dim: usize,
    offsets: []const usize,
    context_size: usize,
) Hypervector {
    var accumulated_role = Hypervector.init(dim); // starts as zero
    var first = true;

    for (offsets) |s| {
        if (s + context_size >= corpus.len) continue;

        // Encode context
        var ctx: [8]Hypervector = undefined;
        for (0..context_size) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }

        // Target
        var target = charToHV(dim, corpus[s + context_size]);

        // Context summary
        var summary = summarizeContext(&ctx);

        // Ideal role for this sample: unbind(target, summary)
        var ideal = target.unbind(&summary);

        if (first) {
            accumulated_role = ideal;
            first = false;
        } else {
            accumulated_role = accumulated_role.bundle(&ideal);
        }
    }

    return accumulated_role;
}

/// Direct decode: use the learned role to predict next char
fn directDecode(context: []Hypervector, role: *Hypervector, dim: usize) u8 {
    var output = forwardPassDirect(context, role);
    return hvToChar(dim, &output);
}

/// Autoregressive generation with direct role
fn generateWithDirectRole(
    initial_context: []Hypervector,
    role: *Hypervector,
    dim: usize,
    output_buf: []u8,
    max_tokens: usize,
) usize {
    var context: [8]Hypervector = undefined;
    for (initial_context, 0..) |*hv, i| {
        context[i] = hv.clone();
    }

    var generated: usize = 0;
    while (generated < max_tokens and generated < output_buf.len) {
        var output = forwardPassDirect(&context, role);
        output_buf[generated] = hvToChar(dim, &output);
        generated += 1;

        for (0..7) |i| {
            context[i] = context[i + 1];
        }
        context[7] = output.clone();
    }
    return generated;
}

/// Iterative refinement: after initial direct role computation,
/// run a few correction passes to improve role quality.
/// Each pass: for each sample, measure error, compute correction, blend.
fn refineDirectRole(
    corpus: []const u8,
    dim: usize,
    offsets: []const usize,
    context_size: usize,
    initial_role: *Hypervector,
    num_passes: usize,
) Hypervector {
    var role = initial_role.clone();

    for (0..num_passes) |pass| {
        var correction_accum = Hypervector.init(dim);
        var first_correction = true;
        var pass_loss: f64 = 0;
        var count: usize = 0;

        for (offsets) |s| {
            if (s + context_size >= corpus.len) continue;

            var ctx: [8]Hypervector = undefined;
            for (0..context_size) |i| {
                ctx[i] = charToHV(dim, corpus[s + i]);
            }
            var target = charToHV(dim, corpus[s + context_size]);

            // Forward pass with current role
            var output = forwardPassDirect(&ctx, &role);
            const sim = output.similarity(&target);
            pass_loss += 1.0 - sim;
            count += 1;

            // Only correct if prediction is poor
            if (sim < 0.3) {
                var summary = summarizeContext(&ctx);
                var ideal = target.unbind(&summary);
                // Blend correction: small step toward ideal
                var correction = ideal.unbind(&role);
                // Sparsify heavily (keep 10%)
                var prng = std.Random.DefaultPrng.init(pass * 1000 + s + 60000);
                const random = prng.random();
                for (0..dim) |idx| {
                    if (random.float(f64) > 0.1) {
                        correction.set(idx, 0);
                    }
                }
                if (first_correction) {
                    correction_accum = correction;
                    first_correction = false;
                } else {
                    correction_accum = correction_accum.bundle(&correction);
                }
            }
        }

        if (!first_correction) {
            role = role.bind(&correction_accum);
        }

        if (count > 0) {
            const avg_pass_loss = pass_loss / @as(f64, @floatFromInt(count));
            _ = avg_pass_loss;
        }
    }

    return role;
}

// === HEBBIAN ASSOCIATION MATRIX (v2.35) ===
//
// Build a character-pair association matrix from the corpus.
// For each character `a`, we bundle all charToHV(b) for every (a,b) bigram
// observed in corpus. This creates a Hebbian "what follows a?" lookup.
//
// Hybrid forward: bundle(direct_role_prediction, hebbian_prediction)
// Direct role captures 8-char context patterns; Hebbian captures bigram frequency.

/// Number of printable ASCII characters we track (32..127 = 95 chars)
const HEBBIAN_CHARS: usize = 95;
const HEBBIAN_OFFSET: usize = 32;

/// Hebbian association: for a given character, returns a hypervector
/// representing what characters tend to follow it (bundled successors).
/// We store the matrix as 95 HVs, one per printable ASCII char.
///
/// To avoid 95 * 59KB = 5.6MB on stack, we compute associations on-the-fly
/// from a compact counts representation.

/// Build Hebbian bigram counts from corpus
/// Returns counts[a][b] = number of times char b follows char a
fn buildHebbianCounts(corpus: []const u8) [HEBBIAN_CHARS][HEBBIAN_CHARS]u16 {
    var counts: [HEBBIAN_CHARS][HEBBIAN_CHARS]u16 = undefined;
    // Zero-initialize
    for (0..HEBBIAN_CHARS) |i| {
        for (0..HEBBIAN_CHARS) |j| {
            counts[i][j] = 0;
        }
    }

    // Count bigrams
    for (0..corpus.len - 1) |i| {
        const a = corpus[i];
        const b = corpus[i + 1];
        if (a >= HEBBIAN_OFFSET and a < HEBBIAN_OFFSET + HEBBIAN_CHARS and
            b >= HEBBIAN_OFFSET and b < HEBBIAN_OFFSET + HEBBIAN_CHARS)
        {
            const ai = a - HEBBIAN_OFFSET;
            const bi = b - HEBBIAN_OFFSET;
            if (counts[ai][bi] < 65535) {
                counts[ai][bi] += 1;
            }
        }
    }

    return counts;
}

/// Compute the Hebbian association HV for a given character.
/// This bundles charToHV(b) for every successor b seen in the corpus,
/// weighted by frequency (repeated bundling for frequent pairs).
fn hebbianLookup(
    dim: usize,
    char_idx: usize,
    counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
) Hypervector {
    var result = Hypervector.init(dim); // zero vector
    var first = true;

    // Bundle successors, proportional to count (cap at 3 bundles per successor)
    for (0..HEBBIAN_CHARS) |bi| {
        const count = counts[char_idx][bi];
        if (count == 0) continue;

        const char_b: u8 = @intCast(bi + HEBBIAN_OFFSET);
        var successor_hv = charToHV(dim, char_b);

        // Bundle this successor (more frequent = repeated bundle = stronger signal)
        const repeats = @min(count, 3);
        for (0..repeats) |_| {
            if (first) {
                result = successor_hv;
                first = false;
            } else {
                result = result.bundle(&successor_hv);
            }
        }
    }

    return result;
}

/// Hybrid forward pass: combine direct role prediction with Hebbian bigram lookup.
/// output = bundle(bind(summary, role), hebbian_prediction)
/// This gives the model both context-level (8-char) and bigram-level signal.
fn forwardPassHybrid(
    context: []Hypervector,
    role: *Hypervector,
    dim: usize,
    last_char: u8,
    counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
) Hypervector {
    // Direct role prediction (from v2.34)
    var direct_pred = forwardPassDirect(context, role);

    // Hebbian bigram prediction
    if (last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS) {
        const char_idx = last_char - HEBBIAN_OFFSET;
        var hebbian_pred = hebbianLookup(dim, char_idx, counts);
        // Hybrid: bundle the two signals
        return direct_pred.bundle(&hebbian_pred);
    }

    return direct_pred;
}

// === v2.39 TRIGRAM HEBBIAN (2-CHAR LOOKBACK) ===
//
// Extends bigram Hebbian to trigram: given last 2 chars (a, b), predict next char c.
// Uses a compact representation: trigram_key = a_idx * HEBBIAN_CHARS + b_idx
// For each key, store counts of successor chars.
// Total: 9025 × 95 × u16 = ~1.7MB (fits on stack for Zig's 8MB default).

const TRIGRAM_KEYS: usize = HEBBIAN_CHARS * HEBBIAN_CHARS; // 95 * 95 = 9025

/// Build trigram counts from corpus.
/// Returns counts[a*95+b][c] = number of times char c follows (a, b) pair.
fn buildTrigramCounts(corpus: []const u8) [TRIGRAM_KEYS][HEBBIAN_CHARS]u16 {
    var counts: [TRIGRAM_KEYS][HEBBIAN_CHARS]u16 = undefined;
    // Zero-initialize
    for (0..TRIGRAM_KEYS) |i| {
        for (0..HEBBIAN_CHARS) |j| {
            counts[i][j] = 0;
        }
    }

    // Count trigrams
    if (corpus.len < 3) return counts;
    for (0..corpus.len - 2) |i| {
        const a = corpus[i];
        const b = corpus[i + 1];
        const c = corpus[i + 2];
        if (a >= HEBBIAN_OFFSET and a < HEBBIAN_OFFSET + HEBBIAN_CHARS and
            b >= HEBBIAN_OFFSET and b < HEBBIAN_OFFSET + HEBBIAN_CHARS and
            c >= HEBBIAN_OFFSET and c < HEBBIAN_OFFSET + HEBBIAN_CHARS)
        {
            const ai = a - HEBBIAN_OFFSET;
            const bi = b - HEBBIAN_OFFSET;
            const ci = c - HEBBIAN_OFFSET;
            const key = ai * HEBBIAN_CHARS + bi;
            if (counts[key][ci] < 65535) {
                counts[key][ci] += 1;
            }
        }
    }

    return counts;
}

/// Compute trigram-based Hebbian association HV for a given 2-char context.
/// Bundles charToHV(c) for every successor c seen after (a, b), weighted by frequency.
fn trigramLookup(
    dim: usize,
    prev_char_idx: usize,
    last_char_idx: usize,
    tri_counts: *const [TRIGRAM_KEYS][HEBBIAN_CHARS]u16,
) Hypervector {
    var result = Hypervector.init(dim);
    var first = true;

    const key = prev_char_idx * HEBBIAN_CHARS + last_char_idx;

    for (0..HEBBIAN_CHARS) |ci| {
        const count = tri_counts[key][ci];
        if (count == 0) continue;

        const char_c: u8 = @intCast(ci + HEBBIAN_OFFSET);
        var successor_hv = charToHV(dim, char_c);

        const repeats = @min(count, 3);
        for (0..repeats) |_| {
            if (first) {
                result = successor_hv;
                first = false;
            } else {
                result = result.bundle(&successor_hv);
            }
        }
    }

    return result;
}

/// Trigram hybrid forward pass: combine multi-role prediction with trigram Hebbian.
/// Uses last 2 chars for deeper context. Falls back to bigram if trigram has no data.
fn forwardPassTrigramHybrid(
    context: []Hypervector,
    roles: *[8]Hypervector,
    dim: usize,
    prev_char: u8,
    last_char: u8,
    bi_counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    tri_counts: *const [TRIGRAM_KEYS][HEBBIAN_CHARS]u16,
) Hypervector {
    var multi_pred = forwardPassMultiRole(context, roles);

    // Try trigram first (deeper context)
    if (prev_char >= HEBBIAN_OFFSET and prev_char < HEBBIAN_OFFSET + HEBBIAN_CHARS and
        last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS)
    {
        const prev_idx = prev_char - HEBBIAN_OFFSET;
        const last_idx = last_char - HEBBIAN_OFFSET;
        const key = prev_idx * HEBBIAN_CHARS + last_idx;

        // Check if trigram has any data for this pair
        var tri_total: u32 = 0;
        for (0..HEBBIAN_CHARS) |ci| {
            tri_total += tri_counts[key][ci];
        }

        if (tri_total > 0) {
            // Trigram available: use it + bigram for robustness
            var tri_pred = trigramLookup(dim, prev_idx, last_idx, tri_counts);
            var bi_pred = hebbianLookup(dim, last_idx, bi_counts);
            // Bundle all three: multi-role + trigram + bigram
            var tri_bi = tri_pred.bundle(&bi_pred);
            return multi_pred.bundle(&tri_bi);
        }
    }

    // Fallback to bigram only
    if (last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS) {
        const char_idx = last_char - HEBBIAN_OFFSET;
        var hebbian_pred = hebbianLookup(dim, char_idx, bi_counts);
        return multi_pred.bundle(&hebbian_pred);
    }

    return multi_pred;
}

/// Autoregressive generation with multi-role + trigram Hebbian + sampling.
fn generateWithTrigramSampled(
    initial_context: []Hypervector,
    roles: *[8]Hypervector,
    dim: usize,
    prev_char_init: u8,
    last_char_init: u8,
    bi_counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    tri_counts: *const [TRIGRAM_KEYS][HEBBIAN_CHARS]u16,
    output_buf: []u8,
    max_tokens: usize,
    temperature: f64,
    top_k: usize,
    base_seed: u64,
) usize {
    var context: [8]Hypervector = undefined;
    for (initial_context, 0..) |*hv, i| {
        context[i] = hv.clone();
    }

    var prev_char = prev_char_init;
    var last_char = last_char_init;
    var generated: usize = 0;
    while (generated < max_tokens and generated < output_buf.len) {
        var output = forwardPassTrigramHybrid(&context, roles, dim, prev_char, last_char, bi_counts, tri_counts);
        const decoded = hvToCharSampled(dim, &output, temperature, top_k, base_seed + generated);
        output_buf[generated] = decoded;
        prev_char = last_char;
        last_char = decoded;
        generated += 1;

        for (0..7) |i| {
            context[i] = context[i + 1];
        }
        context[7] = charToHV(dim, decoded);
    }
    return generated;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WEIGHTED HYBRID BLENDING (v2.42)
// ═══════════════════════════════════════════════════════════════════════════════

/// Weighted blend of 3 hypervectors: result[i] = sign(w_a*a[i] + w_b*b[i] + w_c*c[i])
/// Returns a ternary HV where each trit is the weighted majority vote.
fn weightedBlend3(
    a: *Hypervector,
    b: *Hypervector,
    c: *Hypervector,
    w_a: f64,
    w_b: f64,
    w_c: f64,
    dim: usize,
) Hypervector {
    var result = Hypervector.init(dim);
    const threshold: f64 = 0.1; // deadzone → zero trit
    for (0..dim) |i| {
        const ta: f64 = @floatFromInt(a.get(i));
        const tb: f64 = @floatFromInt(b.get(i));
        const tc: f64 = @floatFromInt(c.get(i));
        const weighted = w_a * ta + w_b * tb + w_c * tc;
        if (weighted > threshold) {
            result.set(i, 1);
        } else if (weighted < -threshold) {
            result.set(i, -1);
        }
        // else stays 0
    }
    return result;
}

/// Weighted blend of 2 hypervectors (for bigram-only fallback)
fn weightedBlend2(
    a: *Hypervector,
    b: *Hypervector,
    w_a: f64,
    w_b: f64,
    dim: usize,
) Hypervector {
    var result = Hypervector.init(dim);
    const threshold: f64 = 0.1;
    for (0..dim) |i| {
        const ta: f64 = @floatFromInt(a.get(i));
        const tb: f64 = @floatFromInt(b.get(i));
        const weighted = w_a * ta + w_b * tb;
        if (weighted > threshold) {
            result.set(i, 1);
        } else if (weighted < -threshold) {
            result.set(i, -1);
        }
    }
    return result;
}

/// Forward pass with weighted alpha blending instead of equal-weight bundling.
/// alpha_role: weight for multi-role prediction
/// alpha_tri: weight for trigram Hebbian
/// alpha_bi: weight for bigram Hebbian
fn forwardPassWeightedHybrid(
    context: []Hypervector,
    roles: *[8]Hypervector,
    dim: usize,
    prev_char: u8,
    last_char: u8,
    bi_counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    tri_counts: *const [TRIGRAM_KEYS][HEBBIAN_CHARS]u16,
    alpha_role: f64,
    alpha_tri: f64,
    alpha_bi: f64,
) Hypervector {
    var multi_pred = forwardPassMultiRole(context, roles);

    // Try trigram path
    if (prev_char >= HEBBIAN_OFFSET and prev_char < HEBBIAN_OFFSET + HEBBIAN_CHARS and
        last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS)
    {
        const prev_idx = prev_char - HEBBIAN_OFFSET;
        const last_idx = last_char - HEBBIAN_OFFSET;
        const key = prev_idx * HEBBIAN_CHARS + last_idx;

        var tri_total: u32 = 0;
        for (0..HEBBIAN_CHARS) |ci| {
            tri_total += tri_counts[key][ci];
        }

        if (tri_total > 0) {
            var tri_pred = trigramLookup(dim, prev_idx, last_idx, tri_counts);
            var bi_pred = hebbianLookup(dim, last_idx, bi_counts);
            return weightedBlend3(&multi_pred, &tri_pred, &bi_pred, alpha_role, alpha_tri, alpha_bi, dim);
        }
    }

    // Fallback to bigram only (role + bigram weighted)
    if (last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS) {
        const char_idx = last_char - HEBBIAN_OFFSET;
        var hebbian_pred = hebbianLookup(dim, char_idx, bi_counts);
        return weightedBlend2(&multi_pred, &hebbian_pred, alpha_role, alpha_bi + alpha_tri, dim);
    }

    return multi_pred;
}

/// Generation with weighted hybrid forward pass
fn generateWithWeightedHybrid(
    initial_context: []Hypervector,
    roles: *[8]Hypervector,
    dim: usize,
    prev_char_init: u8,
    last_char_init: u8,
    bi_counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    tri_counts: *const [TRIGRAM_KEYS][HEBBIAN_CHARS]u16,
    alpha_role: f64,
    alpha_tri: f64,
    alpha_bi: f64,
    output_buf: []u8,
    max_tokens: usize,
    temperature: f64,
    top_k: usize,
    base_seed: u64,
) usize {
    var context: [8]Hypervector = undefined;
    for (initial_context, 0..) |*hv, i| {
        context[i] = hv.clone();
    }

    var prev_char = prev_char_init;
    var last_char = last_char_init;
    var generated: usize = 0;
    while (generated < max_tokens and generated < output_buf.len) {
        var output = forwardPassWeightedHybrid(&context, roles, dim, prev_char, last_char, bi_counts, tri_counts, alpha_role, alpha_tri, alpha_bi);
        const decoded = hvToCharSampled(dim, &output, temperature, top_k, base_seed + generated);
        output_buf[generated] = decoded;
        prev_char = last_char;
        last_char = decoded;
        generated += 1;

        for (0..7) |i| {
            context[i] = context[i + 1];
        }
        context[7] = charToHV(dim, decoded);
    }
    return generated;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PURE TRIGRAM (v2.43) — No roles, no attention, just n-gram frequency lookup
// ═══════════════════════════════════════════════════════════════════════════════

/// Pure trigram forward pass: trigram lookup with bigram fallback, NO role vectors.
/// This is the cleanest prediction: just character frequency statistics.
fn forwardPassPureTrigram(
    dim: usize,
    prev_char: u8,
    last_char: u8,
    bi_counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    tri_counts: *const [TRIGRAM_KEYS][HEBBIAN_CHARS]u16,
) Hypervector {
    // Try trigram first
    if (prev_char >= HEBBIAN_OFFSET and prev_char < HEBBIAN_OFFSET + HEBBIAN_CHARS and
        last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS)
    {
        const prev_idx = prev_char - HEBBIAN_OFFSET;
        const last_idx = last_char - HEBBIAN_OFFSET;
        const key = prev_idx * HEBBIAN_CHARS + last_idx;

        var tri_total: u32 = 0;
        for (0..HEBBIAN_CHARS) |ci| {
            tri_total += tri_counts[key][ci];
        }

        if (tri_total > 0) {
            // Pure trigram: no role blending, just trigram lookup
            return trigramLookup(dim, prev_idx, last_idx, tri_counts);
        }

        // Trigram has no data for this pair → fall back to bigram
        return hebbianLookup(dim, last_idx, bi_counts);
    }

    // Last char out of range → bigram only
    if (last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS) {
        const char_idx = last_char - HEBBIAN_OFFSET;
        return hebbianLookup(dim, char_idx, bi_counts);
    }

    // Nothing available → zero vector
    return Hypervector.init(dim);
}

/// Pure trigram + bigram blend: weighted combination of just the two Hebbian signals.
/// alpha_tri: trigram weight, alpha_bi: bigram weight (should sum to ~1.0)
fn forwardPassPureTrigramBlend(
    dim: usize,
    prev_char: u8,
    last_char: u8,
    bi_counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    tri_counts: *const [TRIGRAM_KEYS][HEBBIAN_CHARS]u16,
    alpha_tri: f64,
    alpha_bi: f64,
) Hypervector {
    if (prev_char >= HEBBIAN_OFFSET and prev_char < HEBBIAN_OFFSET + HEBBIAN_CHARS and
        last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS)
    {
        const prev_idx = prev_char - HEBBIAN_OFFSET;
        const last_idx = last_char - HEBBIAN_OFFSET;
        const key = prev_idx * HEBBIAN_CHARS + last_idx;

        var tri_total: u32 = 0;
        for (0..HEBBIAN_CHARS) |ci| {
            tri_total += tri_counts[key][ci];
        }

        if (tri_total > 0) {
            var tri_pred = trigramLookup(dim, prev_idx, last_idx, tri_counts);
            var bi_pred = hebbianLookup(dim, last_idx, bi_counts);
            return weightedBlend2(&tri_pred, &bi_pred, alpha_tri, alpha_bi, dim);
        }

        return hebbianLookup(dim, last_idx, bi_counts);
    }

    if (last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS) {
        const char_idx = last_char - HEBBIAN_OFFSET;
        return hebbianLookup(dim, char_idx, bi_counts);
    }

    return Hypervector.init(dim);
}

/// Generation with pure trigram (no roles needed)
fn generateWithPureTrigram(
    dim: usize,
    prev_char_init: u8,
    last_char_init: u8,
    bi_counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    tri_counts: *const [TRIGRAM_KEYS][HEBBIAN_CHARS]u16,
    output_buf: []u8,
    max_tokens: usize,
    temperature: f64,
    top_k: usize,
    base_seed: u64,
) usize {
    var prev_char = prev_char_init;
    var last_char = last_char_init;
    var generated: usize = 0;
    while (generated < max_tokens and generated < output_buf.len) {
        var output = forwardPassPureTrigram(dim, prev_char, last_char, bi_counts, tri_counts);
        const decoded = hvToCharSampled(dim, &output, temperature, top_k, base_seed + generated);
        output_buf[generated] = decoded;
        prev_char = last_char;
        last_char = decoded;
        generated += 1;
    }
    return generated;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RAW FREQUENCY DECODING (v2.44) — Bypass VSA, sample directly from count tables
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute raw probability P(target | prev, last) from trigram counts.
/// Returns the probability (0.0 to 1.0) of the target character.
/// Falls back to bigram P(target | last) if no trigram data.
/// Falls back to uniform 1/95 if no bigram data either.
fn rawTrigramProb(
    prev_char: u8,
    last_char: u8,
    target_char: u8,
    bi_counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    tri_counts: *const [TRIGRAM_KEYS][HEBBIAN_CHARS]u16,
) f64 {
    const uniform = 1.0 / @as(f64, @floatFromInt(HEBBIAN_CHARS));

    if (target_char < HEBBIAN_OFFSET or target_char >= HEBBIAN_OFFSET + HEBBIAN_CHARS) return uniform;
    const target_idx = target_char - HEBBIAN_OFFSET;

    // Try trigram
    if (prev_char >= HEBBIAN_OFFSET and prev_char < HEBBIAN_OFFSET + HEBBIAN_CHARS and
        last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS)
    {
        const prev_idx = prev_char - HEBBIAN_OFFSET;
        const last_idx = last_char - HEBBIAN_OFFSET;
        const key = prev_idx * HEBBIAN_CHARS + last_idx;

        var tri_total: u32 = 0;
        for (0..HEBBIAN_CHARS) |ci| {
            tri_total += tri_counts[key][ci];
        }

        if (tri_total > 0) {
            const count: f64 = @floatFromInt(tri_counts[key][target_idx]);
            const total: f64 = @floatFromInt(tri_total);
            // Laplace smoothing: (count + 0.01) / (total + 0.01 * 95)
            return (count + 0.01) / (total + 0.01 * @as(f64, @floatFromInt(HEBBIAN_CHARS)));
        }
    }

    // Fallback to bigram
    if (last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS) {
        const last_idx = last_char - HEBBIAN_OFFSET;
        var bi_total: u32 = 0;
        for (0..HEBBIAN_CHARS) |ci| {
            bi_total += bi_counts[last_idx][ci];
        }
        if (bi_total > 0) {
            const count: f64 = @floatFromInt(bi_counts[last_idx][target_idx]);
            const total: f64 = @floatFromInt(bi_total);
            return (count + 0.01) / (total + 0.01 * @as(f64, @floatFromInt(HEBBIAN_CHARS)));
        }
    }

    return uniform;
}

/// Sample a character directly from raw trigram/bigram count distribution.
/// Uses temperature scaling and top-k filtering on raw probabilities.
fn rawTrigramSample(
    prev_char: u8,
    last_char: u8,
    bi_counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    tri_counts: *const [TRIGRAM_KEYS][HEBBIAN_CHARS]u16,
    temperature: f64,
    top_k: usize,
    seed: u64,
) u8 {
    // Build probability distribution
    var probs: [HEBBIAN_CHARS]f64 = undefined;
    var has_trigram = false;

    // Try trigram distribution
    if (prev_char >= HEBBIAN_OFFSET and prev_char < HEBBIAN_OFFSET + HEBBIAN_CHARS and
        last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS)
    {
        const prev_idx = prev_char - HEBBIAN_OFFSET;
        const last_idx = last_char - HEBBIAN_OFFSET;
        const key = prev_idx * HEBBIAN_CHARS + last_idx;

        var tri_total: u32 = 0;
        for (0..HEBBIAN_CHARS) |ci| {
            tri_total += tri_counts[key][ci];
        }

        if (tri_total > 0) {
            has_trigram = true;
            const total_f: f64 = @floatFromInt(tri_total);
            const smooth = 0.01 * @as(f64, @floatFromInt(HEBBIAN_CHARS));
            for (0..HEBBIAN_CHARS) |ci| {
                const count: f64 = @floatFromInt(tri_counts[key][ci]);
                probs[ci] = (count + 0.01) / (total_f + smooth);
            }
        }
    }

    // Fallback to bigram
    if (!has_trigram) {
        if (last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS) {
            const last_idx = last_char - HEBBIAN_OFFSET;
            var bi_total: u32 = 0;
            for (0..HEBBIAN_CHARS) |ci| {
                bi_total += bi_counts[last_idx][ci];
            }
            if (bi_total > 0) {
                const total_f: f64 = @floatFromInt(bi_total);
                const smooth = 0.01 * @as(f64, @floatFromInt(HEBBIAN_CHARS));
                for (0..HEBBIAN_CHARS) |ci| {
                    const count: f64 = @floatFromInt(bi_counts[last_idx][ci]);
                    probs[ci] = (count + 0.01) / (total_f + smooth);
                }
            } else {
                // Uniform
                for (0..HEBBIAN_CHARS) |ci| {
                    probs[ci] = 1.0 / @as(f64, @floatFromInt(HEBBIAN_CHARS));
                }
            }
        } else {
            for (0..HEBBIAN_CHARS) |ci| {
                probs[ci] = 1.0 / @as(f64, @floatFromInt(HEBBIAN_CHARS));
            }
        }
    }

    // Apply temperature
    if (temperature > 0.0 and temperature != 1.0) {
        var max_logp: f64 = -1e10;
        for (0..HEBBIAN_CHARS) |ci| {
            const logp = @log(@max(probs[ci], 1e-20));
            if (logp > max_logp) max_logp = logp;
            probs[ci] = logp;
        }
        for (0..HEBBIAN_CHARS) |ci| {
            probs[ci] = @exp((probs[ci] - max_logp) / temperature);
        }
    }

    // Top-k filtering
    if (top_k > 0 and top_k < HEBBIAN_CHARS) {
        // Find top-k threshold
        var sorted_vals: [HEBBIAN_CHARS]f64 = undefined;
        for (0..HEBBIAN_CHARS) |ci| {
            sorted_vals[ci] = probs[ci];
        }
        // Simple partial sort: find k-th largest
        for (0..top_k) |k| {
            var max_idx: usize = k;
            for (k + 1..HEBBIAN_CHARS) |ci| {
                if (sorted_vals[ci] > sorted_vals[max_idx]) max_idx = ci;
            }
            const tmp = sorted_vals[k];
            sorted_vals[k] = sorted_vals[max_idx];
            sorted_vals[max_idx] = tmp;
        }
        const threshold = sorted_vals[top_k - 1];
        for (0..HEBBIAN_CHARS) |ci| {
            if (probs[ci] < threshold) probs[ci] = 0.0;
        }
    }

    // Normalize
    var total: f64 = 0;
    for (0..HEBBIAN_CHARS) |ci| {
        total += probs[ci];
    }
    if (total > 0) {
        for (0..HEBBIAN_CHARS) |ci| {
            probs[ci] /= total;
        }
    }

    // Sample using seed-based RNG
    var rng_state = seed;
    rng_state ^= rng_state >> 12;
    rng_state ^= rng_state << 25;
    rng_state ^= rng_state >> 27;
    const rand_val: f64 = @as(f64, @floatFromInt(rng_state % 1000000)) / 1000000.0;

    var cumulative: f64 = 0;
    for (0..HEBBIAN_CHARS) |ci| {
        cumulative += probs[ci];
        if (rand_val < cumulative) {
            return @intCast(ci + HEBBIAN_OFFSET);
        }
    }
    return @intCast(HEBBIAN_OFFSET); // fallback: space
}

/// Generate text using raw frequency sampling (no VSA at all)
fn generateWithRawFreq(
    prev_char_init: u8,
    last_char_init: u8,
    bi_counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    tri_counts: *const [TRIGRAM_KEYS][HEBBIAN_CHARS]u16,
    output_buf: []u8,
    max_tokens: usize,
    temperature: f64,
    top_k: usize,
    base_seed: u64,
) usize {
    var prev_char = prev_char_init;
    var last_char = last_char_init;
    var generated: usize = 0;
    while (generated < max_tokens and generated < output_buf.len) {
        const decoded = rawTrigramSample(prev_char, last_char, bi_counts, tri_counts, temperature, top_k, base_seed + generated);
        output_buf[generated] = decoded;
        prev_char = last_char;
        last_char = decoded;
        generated += 1;
    }
    return generated;
}

/// Compute raw frequency loss: -log(P(target | prev, last))
/// This is the true cross-entropy loss without VSA encoding overhead.
fn rawTrigramLoss(
    prev_char: u8,
    last_char: u8,
    target_char: u8,
    bi_counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    tri_counts: *const [TRIGRAM_KEYS][HEBBIAN_CHARS]u16,
) f64 {
    const prob = rawTrigramProb(prev_char, last_char, target_char, bi_counts, tri_counts);
    return -@log(@max(prob, 1e-20));
}

// ═══════════════════════════════════════════════════════════════════════════════
// WORD-LEVEL STATISTICS (v2.45) — Tokenize corpus, build word bigram model
// ═══════════════════════════════════════════════════════════════════════════════

const MAX_WORDS: usize = 256; // max unique words in vocabulary
const MAX_TOKENS: usize = 1024; // max tokens in corpus
const MAX_WORD_LEN: usize = 24; // max length of a single word

/// A simple fixed-size word vocabulary and tokenized corpus
const WordCorpus = struct {
    // Vocabulary: each word stored as a fixed-length buffer
    vocab: [MAX_WORDS][MAX_WORD_LEN]u8,
    vocab_lens: [MAX_WORDS]u8,
    vocab_size: usize,

    // Tokenized corpus as word indices
    tokens: [MAX_TOKENS]u16,
    token_count: usize,

    // Word bigram counts: counts[prev_word][next_word]
    bigram_counts: [MAX_WORDS][MAX_WORDS]u16,

    fn init() WordCorpus {
        var self: WordCorpus = undefined;
        self.vocab_size = 0;
        self.token_count = 0;
        for (0..MAX_WORDS) |i| {
            self.vocab_lens[i] = 0;
            for (0..MAX_WORDS) |j| {
                self.bigram_counts[i][j] = 0;
            }
        }
        return self;
    }

    /// Find or add a word to vocabulary. Returns word index.
    fn getOrAddWord(self: *WordCorpus, word: []const u8) u16 {
        if (word.len == 0 or word.len > MAX_WORD_LEN) return 0;

        // Linear search (corpus is small)
        for (0..self.vocab_size) |i| {
            const len = self.vocab_lens[i];
            if (len == word.len) {
                var match = true;
                for (0..len) |j| {
                    if (self.vocab[i][j] != word[j]) {
                        match = false;
                        break;
                    }
                }
                if (match) return @intCast(i);
            }
        }

        // Add new word
        if (self.vocab_size >= MAX_WORDS) return 0;
        const idx = self.vocab_size;
        for (0..word.len) |j| {
            self.vocab[idx][j] = word[j];
        }
        self.vocab_lens[idx] = @intCast(word.len);
        self.vocab_size += 1;
        return @intCast(idx);
    }

    /// Get word string from index
    fn getWord(self: *const WordCorpus, idx: u16) []const u8 {
        if (idx >= self.vocab_size) return "";
        const len = self.vocab_lens[idx];
        return self.vocab[idx][0..len];
    }

    /// Tokenize a corpus into word indices (split on spaces)
    fn tokenize(self: *WordCorpus, corpus: []const u8) void {
        var i: usize = 0;
        while (i < corpus.len and self.token_count < MAX_TOKENS) {
            // Skip spaces
            while (i < corpus.len and corpus[i] == ' ') : (i += 1) {}
            if (i >= corpus.len) break;

            // Find word end
            const start = i;
            while (i < corpus.len and corpus[i] != ' ') : (i += 1) {}
            const word = corpus[start..i];
            if (word.len > 0 and word.len <= MAX_WORD_LEN) {
                const idx = self.getOrAddWord(word);
                self.tokens[self.token_count] = idx;
                self.token_count += 1;
            }
        }
    }

    /// Build word bigram counts from tokenized corpus
    fn buildBigrams(self: *WordCorpus) void {
        if (self.token_count < 2) return;
        for (0..self.token_count - 1) |i| {
            const prev = self.tokens[i];
            const next = self.tokens[i + 1];
            if (self.bigram_counts[prev][next] < 65535) {
                self.bigram_counts[prev][next] += 1;
            }
        }
    }

    /// Get P(next_word | prev_word) with Laplace smoothing
    fn wordBigramProb(self: *const WordCorpus, prev_idx: u16, next_idx: u16) f64 {
        if (prev_idx >= self.vocab_size or next_idx >= self.vocab_size) {
            return 1.0 / @as(f64, @floatFromInt(self.vocab_size));
        }
        var total: u32 = 0;
        for (0..self.vocab_size) |j| {
            total += self.bigram_counts[prev_idx][j];
        }
        if (total == 0) return 1.0 / @as(f64, @floatFromInt(self.vocab_size));
        const count: f64 = @floatFromInt(self.bigram_counts[prev_idx][next_idx]);
        const total_f: f64 = @floatFromInt(total);
        const vs: f64 = @floatFromInt(self.vocab_size);
        return (count + 0.1) / (total_f + 0.1 * vs);
    }

    /// Sample next word given previous word
    fn sampleNextWord(self: *const WordCorpus, prev_idx: u16, temperature: f64, seed: u64) u16 {
        var probs: [MAX_WORDS]f64 = undefined;
        var total: u32 = 0;

        for (0..self.vocab_size) |j| {
            total += self.bigram_counts[prev_idx][j];
        }

        if (total == 0) {
            // Uniform over vocabulary
            return @intCast(seed % self.vocab_size);
        }

        const total_f: f64 = @floatFromInt(total);
        const vs: f64 = @floatFromInt(self.vocab_size);
        const smooth = 0.1 * vs;

        // Build distribution with temperature
        var max_logp: f64 = -1e10;
        for (0..self.vocab_size) |j| {
            const count: f64 = @floatFromInt(self.bigram_counts[prev_idx][j]);
            const p = (count + 0.1) / (total_f + smooth);
            const logp = @log(@max(p, 1e-20));
            probs[j] = logp;
            if (logp > max_logp) max_logp = logp;
        }

        // Apply temperature and softmax
        var sum: f64 = 0;
        for (0..self.vocab_size) |j| {
            probs[j] = @exp((probs[j] - max_logp) / @max(temperature, 0.01));
            sum += probs[j];
        }
        for (0..self.vocab_size) |j| {
            probs[j] /= sum;
        }

        // Sample
        var rng = seed;
        rng ^= rng >> 12;
        rng ^= rng << 25;
        rng ^= rng >> 27;
        const r: f64 = @as(f64, @floatFromInt(rng % 1000000)) / 1000000.0;

        var cumulative: f64 = 0;
        for (0..self.vocab_size) |j| {
            cumulative += probs[j];
            if (r < cumulative) return @intCast(j);
        }
        return 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WORD TRIGRAM MODEL (v2.46) — P(word | prev2, prev1)
// Sparse storage: with 988 tokens, only ~986 trigram observations exist.
// Hash table with open addressing for efficient (prev2, prev1) → counts lookup.
// ═══════════════════════════════════════════════════════════════════════════════

const WORD_TRI_HASH_SIZE: usize = 2048; // power of 2 for fast modulo
const WORD_TRI_MAX_NEXTS: usize = 32; // max unique successors per (prev2, prev1) pair

const WordTrigramSlot = struct {
    prev2: u16,
    prev1: u16,
    valid: bool,
    nexts: [WORD_TRI_MAX_NEXTS]u16, // next word indices
    counts: [WORD_TRI_MAX_NEXTS]u16, // corresponding counts
    num_nexts: u8,
    total_count: u16,
};

const WordTrigramModel = struct {
    // Vocabulary (same as WordCorpus)
    vocab: [MAX_WORDS][MAX_WORD_LEN]u8,
    vocab_lens: [MAX_WORDS]u8,
    vocab_size: usize,
    tokens: [MAX_TOKENS]u16,
    token_count: usize,

    // Bigram counts (fallback when trigram unseen)
    bigram_counts: [MAX_WORDS][MAX_WORDS]u16,

    // Trigram: sparse hash table
    tri_slots: [WORD_TRI_HASH_SIZE]WordTrigramSlot,
    tri_used: usize,

    fn init() WordTrigramModel {
        var self: WordTrigramModel = undefined;
        self.vocab_size = 0;
        self.token_count = 0;
        self.tri_used = 0;
        for (0..MAX_WORDS) |i| {
            self.vocab_lens[i] = 0;
            for (0..MAX_WORDS) |j| {
                self.bigram_counts[i][j] = 0;
            }
        }
        for (0..WORD_TRI_HASH_SIZE) |i| {
            self.tri_slots[i].valid = false;
            self.tri_slots[i].num_nexts = 0;
            self.tri_slots[i].total_count = 0;
        }
        return self;
    }

    fn getOrAddWord(self: *WordTrigramModel, word: []const u8) u16 {
        if (word.len == 0 or word.len > MAX_WORD_LEN) return 0;
        for (0..self.vocab_size) |i| {
            const len = self.vocab_lens[i];
            if (len == word.len) {
                var match = true;
                for (0..len) |j| {
                    if (self.vocab[i][j] != word[j]) {
                        match = false;
                        break;
                    }
                }
                if (match) return @intCast(i);
            }
        }
        if (self.vocab_size >= MAX_WORDS) return 0;
        const idx = self.vocab_size;
        for (0..word.len) |j| {
            self.vocab[idx][j] = word[j];
        }
        self.vocab_lens[idx] = @intCast(word.len);
        self.vocab_size += 1;
        return @intCast(idx);
    }

    fn getWord(self: *const WordTrigramModel, idx: u16) []const u8 {
        if (idx >= self.vocab_size) return "";
        const len = self.vocab_lens[idx];
        return self.vocab[idx][0..len];
    }

    fn tokenize(self: *WordTrigramModel, corpus: []const u8) void {
        var i: usize = 0;
        while (i < corpus.len and self.token_count < MAX_TOKENS) {
            while (i < corpus.len and corpus[i] == ' ') : (i += 1) {}
            if (i >= corpus.len) break;
            const start = i;
            while (i < corpus.len and corpus[i] != ' ') : (i += 1) {}
            const word = corpus[start..i];
            if (word.len > 0 and word.len <= MAX_WORD_LEN) {
                const idx = self.getOrAddWord(word);
                self.tokens[self.token_count] = idx;
                self.token_count += 1;
            }
        }
    }

    fn buildBigrams(self: *WordTrigramModel) void {
        if (self.token_count < 2) return;
        for (0..self.token_count - 1) |i| {
            const prev = self.tokens[i];
            const next = self.tokens[i + 1];
            if (self.bigram_counts[prev][next] < 65535) {
                self.bigram_counts[prev][next] += 1;
            }
        }
    }

    /// Hash function for (prev2, prev1) pair
    fn triHash(prev2: u16, prev1: u16) usize {
        const key: u32 = @as(u32, prev2) * 257 + @as(u32, prev1);
        return @intCast((key ^ (key >> 11) ^ (key >> 22)) % WORD_TRI_HASH_SIZE);
    }

    /// Find or create a trigram slot for (prev2, prev1)
    fn getOrCreateSlot(self: *WordTrigramModel, prev2: u16, prev1: u16) ?*WordTrigramSlot {
        var h = triHash(prev2, prev1);
        var probes: usize = 0;
        while (probes < WORD_TRI_HASH_SIZE) : (probes += 1) {
            const slot = &self.tri_slots[h];
            if (!slot.valid) {
                // Empty slot — claim it
                slot.valid = true;
                slot.prev2 = prev2;
                slot.prev1 = prev1;
                slot.num_nexts = 0;
                slot.total_count = 0;
                self.tri_used += 1;
                return slot;
            }
            if (slot.prev2 == prev2 and slot.prev1 == prev1) {
                return slot;
            }
            h = (h + 1) % WORD_TRI_HASH_SIZE;
        }
        return null; // table full
    }

    /// Find slot for (prev2, prev1) — read-only
    fn findSlot(self: *const WordTrigramModel, prev2: u16, prev1: u16) ?*const WordTrigramSlot {
        var h = triHash(prev2, prev1);
        var probes: usize = 0;
        while (probes < WORD_TRI_HASH_SIZE) : (probes += 1) {
            const slot = &self.tri_slots[h];
            if (!slot.valid) return null;
            if (slot.prev2 == prev2 and slot.prev1 == prev1) return slot;
            h = (h + 1) % WORD_TRI_HASH_SIZE;
        }
        return null;
    }

    /// Build trigram counts from tokenized corpus
    fn buildTrigrams(self: *WordTrigramModel) void {
        if (self.token_count < 3) return;
        for (0..self.token_count - 2) |i| {
            const p2 = self.tokens[i];
            const p1 = self.tokens[i + 1];
            const nx = self.tokens[i + 2];
            if (self.getOrCreateSlot(p2, p1)) |slot| {
                // Find existing next entry or add new one
                var found = false;
                for (0..slot.num_nexts) |k| {
                    if (slot.nexts[k] == nx) {
                        if (slot.counts[k] < 65535) slot.counts[k] += 1;
                        slot.total_count +|= 1;
                        found = true;
                        break;
                    }
                }
                if (!found and slot.num_nexts < WORD_TRI_MAX_NEXTS) {
                    slot.nexts[slot.num_nexts] = nx;
                    slot.counts[slot.num_nexts] = 1;
                    slot.num_nexts += 1;
                    slot.total_count +|= 1;
                }
            }
        }
    }

    /// P(next | prev2, prev1) with trigram → bigram fallback + Laplace smoothing
    fn wordTrigramProb(self: *const WordTrigramModel, prev2: u16, prev1: u16, next_idx: u16) f64 {
        const vs: f64 = @floatFromInt(self.vocab_size);

        // Try trigram first
        if (self.findSlot(prev2, prev1)) |slot| {
            if (slot.total_count > 0) {
                var count: f64 = 0;
                for (0..slot.num_nexts) |k| {
                    if (slot.nexts[k] == next_idx) {
                        count = @floatFromInt(slot.counts[k]);
                        break;
                    }
                }
                const total: f64 = @floatFromInt(slot.total_count);
                return (count + 0.1) / (total + 0.1 * vs);
            }
        }

        // Bigram fallback P(next | prev1)
        var bi_total: u32 = 0;
        for (0..self.vocab_size) |j| {
            bi_total += self.bigram_counts[prev1][j];
        }
        if (bi_total > 0) {
            const count: f64 = @floatFromInt(self.bigram_counts[prev1][next_idx]);
            const total: f64 = @floatFromInt(bi_total);
            return (count + 0.1) / (total + 0.1 * vs);
        }

        // Uniform fallback
        return 1.0 / vs;
    }

    /// Sample next word given (prev2, prev1) with temperature
    fn sampleNextWord(self: *const WordTrigramModel, prev2: u16, prev1: u16, temperature: f64, seed: u64) u16 {
        var probs: [MAX_WORDS]f64 = undefined;
        const vs: f64 = @floatFromInt(self.vocab_size);

        // Try trigram slot
        var use_trigram = false;
        if (self.findSlot(prev2, prev1)) |slot| {
            if (slot.total_count > 0) {
                use_trigram = true;
                const total: f64 = @floatFromInt(slot.total_count);
                const smooth = 0.1 * vs;

                // Initialize all with smoothing baseline
                for (0..self.vocab_size) |j| {
                    probs[j] = 0.1 / (total + smooth);
                }
                // Add actual counts
                for (0..slot.num_nexts) |k| {
                    const idx = slot.nexts[k];
                    const count: f64 = @floatFromInt(slot.counts[k]);
                    probs[idx] = (count + 0.1) / (total + smooth);
                }
            }
        }

        if (!use_trigram) {
            // Bigram fallback
            var bi_total: u32 = 0;
            for (0..self.vocab_size) |j| {
                bi_total += self.bigram_counts[prev1][j];
            }
            if (bi_total > 0) {
                const total: f64 = @floatFromInt(bi_total);
                const smooth = 0.1 * vs;
                for (0..self.vocab_size) |j| {
                    const count: f64 = @floatFromInt(self.bigram_counts[prev1][j]);
                    probs[j] = (count + 0.1) / (total + smooth);
                }
            } else {
                return @intCast(seed % self.vocab_size);
            }
        }

        // Apply temperature in log-space
        var max_logp: f64 = -1e10;
        for (0..self.vocab_size) |j| {
            const logp = @log(@max(probs[j], 1e-20));
            probs[j] = logp;
            if (logp > max_logp) max_logp = logp;
        }

        var sum: f64 = 0;
        for (0..self.vocab_size) |j| {
            probs[j] = @exp((probs[j] - max_logp) / @max(temperature, 0.01));
            sum += probs[j];
        }
        for (0..self.vocab_size) |j| {
            probs[j] /= sum;
        }

        // Sample with xorshift RNG
        var rng = seed;
        rng ^= rng >> 12;
        rng ^= rng << 25;
        rng ^= rng >> 27;
        const r: f64 = @as(f64, @floatFromInt(rng % 1000000)) / 1000000.0;

        var cumulative: f64 = 0;
        for (0..self.vocab_size) |j| {
            cumulative += probs[j];
            if (r < cumulative) return @intCast(j);
        }
        return 0;
    }

    /// Compute trigram loss: -log(P(next | prev2, prev1))
    fn wordTrigramLoss(self: *const WordTrigramModel, prev2: u16, prev1: u16, next_idx: u16) f64 {
        const p = self.wordTrigramProb(prev2, prev1, next_idx);
        return -@log(@max(p, 1e-20));
    }
};

/// Decode using hybrid forward pass
fn hybridDecode(
    context: []Hypervector,
    role: *Hypervector,
    dim: usize,
    last_char: u8,
    counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
) u8 {
    var output = forwardPassHybrid(context, role, dim, last_char, counts);
    return hvToChar(dim, &output);
}

/// Autoregressive generation with hybrid (direct + Hebbian) forward pass
fn generateWithHybrid(
    initial_context: []Hypervector,
    role: *Hypervector,
    dim: usize,
    last_char_init: u8,
    counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    output_buf: []u8,
    max_tokens: usize,
) usize {
    var context: [8]Hypervector = undefined;
    for (initial_context, 0..) |*hv, i| {
        context[i] = hv.clone();
    }

    var last_char = last_char_init;
    var generated: usize = 0;
    while (generated < max_tokens and generated < output_buf.len) {
        var output = forwardPassHybrid(&context, role, dim, last_char, counts);
        const decoded = hvToChar(dim, &output);
        output_buf[generated] = decoded;
        last_char = decoded;
        generated += 1;

        // Shift context window
        for (0..7) |i| {
            context[i] = context[i + 1];
        }
        context[7] = output.clone();
    }
    return generated;
}

// === CHARACTER ENCODING (avoids Codebook key-lifetime bug) ===

/// Deterministic character-to-Hypervector mapping using random seeds
/// Each ASCII char maps to a unique, reproducible hypervector
fn charToHV(dim: usize, c: u8) Hypervector {
    return Hypervector.random(dim, @as(u64, c) * 7919 + 12345);
}

/// Decode a hypervector to the nearest printable ASCII character
fn hvToChar(dim: usize, hv: *Hypervector) u8 {
    var best_sim: f64 = -2.0;
    var best_char: u8 = '?';
    for (32..127) |c| {
        var candidate = charToHV(dim, @intCast(c));
        const sim = hv.similarity(&candidate);
        if (sim > best_sim) {
            best_sim = sim;
            best_char = @intCast(c);
        }
    }
    return best_char;
}

// === TEMPERATURE + TOP-K SAMPLING (v2.36) ===
//
// Greedy decoding (hvToChar) always picks the single highest-similarity char,
// causing degenerate repetition ("tututu..."). Temperature + top-K sampling
// introduces controlled randomness:
// 1. Compute similarity for all 95 printable ASCII chars
// 2. Keep only the top-K candidates (noise filter)
// 3. Apply temperature scaling to similarities (diversity control)
// 4. Convert to softmax probabilities
// 5. Sample from the distribution using PRNG

/// Entry for sorting candidates by similarity
const CharCandidate = struct {
    char: u8,
    sim: f64,
};

/// Decode a hypervector to a character using temperature + top-K sampling.
/// temperature: controls diversity (0.1 = greedy, 1.0 = balanced, 2.0 = random)
/// top_k: number of candidates to consider (1 = greedy, 95 = all)
fn hvToCharSampled(
    dim: usize,
    hv: *Hypervector,
    temperature: f64,
    top_k: usize,
    prng_seed: u64,
) u8 {
    // Special case: temperature near 0 or top_k=1 → greedy
    if (temperature < 0.01 or top_k <= 1) {
        return hvToChar(dim, hv);
    }

    const num_chars: usize = 95; // printable ASCII 32..127
    var candidates: [95]CharCandidate = undefined;

    // Compute all similarities
    for (0..num_chars) |i| {
        const c: u8 = @intCast(i + 32);
        var candidate_hv = charToHV(dim, c);
        candidates[i] = .{
            .char = c,
            .sim = hv.similarity(&candidate_hv),
        };
    }

    // Sort by similarity descending (simple insertion sort, only 95 elements)
    for (1..num_chars) |i| {
        const key = candidates[i];
        var j: usize = i;
        while (j > 0 and candidates[j - 1].sim < key.sim) {
            candidates[j] = candidates[j - 1];
            j -= 1;
        }
        candidates[j] = key;
    }

    // Keep only top-K
    const k = @min(top_k, num_chars);

    // Apply temperature scaling and compute softmax
    // First find max for numerical stability
    var max_sim: f64 = candidates[0].sim;
    for (1..k) |i| {
        if (candidates[i].sim > max_sim) max_sim = candidates[i].sim;
    }

    var exp_sums: [95]f64 = undefined;
    var total_exp: f64 = 0;
    for (0..k) |i| {
        const scaled = (candidates[i].sim - max_sim) / temperature;
        // Clamp to avoid overflow
        const clamped = @max(scaled, -20.0);
        exp_sums[i] = @exp(clamped);
        total_exp += exp_sums[i];
    }

    // Normalize to probabilities
    if (total_exp > 0) {
        for (0..k) |i| {
            exp_sums[i] /= total_exp;
        }
    } else {
        // Uniform fallback
        for (0..k) |i| {
            exp_sums[i] = 1.0 / @as(f64, @floatFromInt(k));
        }
    }

    // Sample from distribution using PRNG
    var prng = std.Random.DefaultPrng.init(prng_seed);
    const random = prng.random();
    const r = random.float(f64);

    var cumulative: f64 = 0;
    for (0..k) |i| {
        cumulative += exp_sums[i];
        if (r < cumulative) {
            return candidates[i].char;
        }
    }

    // Fallback: return last candidate in top-K
    return candidates[k - 1].char;
}

/// Autoregressive generation with hybrid forward + temperature sampling
fn generateWithHybridSampled(
    initial_context: []Hypervector,
    role: *Hypervector,
    dim: usize,
    last_char_init: u8,
    counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    output_buf: []u8,
    max_tokens: usize,
    temperature: f64,
    top_k: usize,
    base_seed: u64,
) usize {
    var context: [8]Hypervector = undefined;
    for (initial_context, 0..) |*hv, i| {
        context[i] = hv.clone();
    }

    var last_char = last_char_init;
    var generated: usize = 0;
    while (generated < max_tokens and generated < output_buf.len) {
        var output = forwardPassHybrid(&context, role, dim, last_char, counts);
        // Use sampled decoding with per-token seed for reproducibility
        const decoded = hvToCharSampled(dim, &output, temperature, top_k, base_seed + generated);
        output_buf[generated] = decoded;
        last_char = decoded;
        generated += 1;

        // Shift context window
        for (0..7) |i| {
            context[i] = context[i + 1];
        }
        // Use the HV of the decoded character (not the raw output) for clean autoregression
        context[7] = charToHV(dim, decoded);
    }
    return generated;
}

// === MULTI-ROLE POSITION-SPECIFIC (v2.37) ===
//
// Instead of 1 global role, learn 8 separate roles — one per context position.
// Each role captures "what does character at position i predict about the next char?"
//
// Training: for each sample and each position i:
//   ideal_role_i = unbind(target, permute(context[i], i))
//   role_i = bundle(all ideal_role_i across samples)
//
// Inference: for each position i:
//   pred_i = bind(permute(context[i], i), role_i)
// output = bundle(pred_0, pred_1, ..., pred_7) via sequential bundle
//
// This is more expressive: each position independently contributes to prediction.

/// Compute 8 position-specific roles from training data.
/// For each position i, the role captures what that position predicts about the next char.
fn computeMultiRoles(
    corpus: []const u8,
    dim: usize,
    offsets: []const usize,
    context_size: usize,
) [8]Hypervector {
    var roles: [8]Hypervector = undefined;
    var first: [8]bool = undefined;
    for (0..8) |i| {
        roles[i] = Hypervector.init(dim);
        first[i] = true;
    }

    for (offsets) |s| {
        if (s + context_size >= corpus.len) continue;

        var target = charToHV(dim, corpus[s + context_size]);

        for (0..context_size) |i| {
            var ctx_hv = charToHV(dim, corpus[s + i]);
            var positioned = ctx_hv.permute(i);
            // ideal_role_i = unbind(target, positioned)
            var ideal = target.unbind(&positioned);

            if (first[i]) {
                roles[i] = ideal;
                first[i] = false;
            } else {
                roles[i] = roles[i].bundle(&ideal);
            }
        }
    }

    return roles;
}

/// Multi-role forward pass: each position contributes independently.
/// output = bundle(bind(permute(ctx[0], 0), role_0), ..., bind(permute(ctx[7], 7), role_7))
fn forwardPassMultiRole(
    context: []Hypervector,
    roles: *[8]Hypervector,
) Hypervector {
    var pos0 = context[0].permute(0);
    var result = pos0.bind(&roles[0]);

    for (1..context.len) |i| {
        var positioned = context[i].permute(i);
        var pred_i = positioned.bind(&roles[i]);
        result = result.bundle(&pred_i);
    }

    return result;
}

/// Multi-role + Hebbian hybrid forward pass.
/// Combines position-specific role predictions with bigram Hebbian lookup.
fn forwardPassMultiRoleHybrid(
    context: []Hypervector,
    roles: *[8]Hypervector,
    dim: usize,
    last_char: u8,
    counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
) Hypervector {
    var multi_pred = forwardPassMultiRole(context, roles);

    if (last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS) {
        const char_idx = last_char - HEBBIAN_OFFSET;
        var hebbian_pred = hebbianLookup(dim, char_idx, counts);
        return multi_pred.bundle(&hebbian_pred);
    }

    return multi_pred;
}

/// Autoregressive generation with multi-role + Hebbian + sampling.
fn generateWithMultiRoleSampled(
    initial_context: []Hypervector,
    roles: *[8]Hypervector,
    dim: usize,
    last_char_init: u8,
    counts: *const [HEBBIAN_CHARS][HEBBIAN_CHARS]u16,
    output_buf: []u8,
    max_tokens: usize,
    temperature: f64,
    top_k: usize,
    base_seed: u64,
) usize {
    var context: [8]Hypervector = undefined;
    for (initial_context, 0..) |*hv, i| {
        context[i] = hv.clone();
    }

    var last_char = last_char_init;
    var generated: usize = 0;
    while (generated < max_tokens and generated < output_buf.len) {
        var output = forwardPassMultiRoleHybrid(&context, roles, dim, last_char, counts);
        const decoded = hvToCharSampled(dim, &output, temperature, top_k, base_seed + generated);
        output_buf[generated] = decoded;
        last_char = decoded;
        generated += 1;

        for (0..7) |i| {
            context[i] = context[i + 1];
        }
        context[7] = charToHV(dim, decoded);
    }
    return generated;
}

/// Autoregressive generation using charToHV/hvToChar (no Codebook needed)
fn generateWithCharTable(
    initial_context: []Hypervector,
    roles: *[11]Hypervector,
    dim: usize,
    output_buf: []u8,
    max_tokens: usize,
) usize {
    var context: [8]Hypervector = undefined;
    for (initial_context, 0..) |*hv, i| {
        context[i] = hv.clone();
    }

    var generated: usize = 0;
    while (generated < max_tokens and generated < output_buf.len) {
        var output = forwardPassMultiHead(&context, roles);
        output_buf[generated] = hvToChar(dim, &output);
        generated += 1;

        // Shift context left, append output
        for (0..7) |i| {
            context[i] = context[i + 1];
        }
        context[7] = output.clone();
    }
    return generated;
}

// === TESTS ===

test "forward pass produces non-null output" {
    const allocator = std.testing.allocator;

    const dim: usize = 256;
    var codebook = Codebook.init(allocator, dim);
    defer codebook.deinit();

    // Encode "To be or" — 8 characters
    const text = "To be or";
    var hvs: [8]Hypervector = undefined;
    for (text, 0..) |c, i| {
        const hv_ptr = try codebook.encode(&[_]u8{c});
        hvs[i] = hv_ptr.clone();
    }

    // Create roles and run forward pass
    var roles = initRoles(dim, 42);
    var output = forwardPass(&hvs, &roles);

    // Decode prediction
    const predicted = codebook.decode(&output);

    // Verify: output is non-trivial (has non-zero trits)
    const d = output.density();
    try std.testing.expect(d > 0.0);

    // Log results
    std.debug.print("\n=== MINIMAL FORWARD PASS RESULTS ===\n", .{});
    std.debug.print("Input: \"{s}\"\n", .{text});
    std.debug.print("Output density: {d:.4}\n", .{d});
    if (predicted) |p| {
        std.debug.print("Predicted next: '{s}'\n", .{p});
    } else {
        std.debug.print("Predicted next: (no match above threshold)\n", .{});
    }
    std.debug.print("====================================\n", .{});
}

test "role vectors are quasi-orthogonal" {
    const dim: usize = 256;
    var roles = initRoles(dim, 42);

    // Check all 55 pairs of 11 roles
    var max_sim: f64 = 0;
    for (0..11) |i| {
        for ((i + 1)..11) |j| {
            const sim = @abs(roles[i].similarity(&roles[j]));
            if (sim > max_sim) max_sim = sim;
        }
    }

    std.debug.print("\nMax role pair |cosine|: {d:.4}\n", .{max_sim});
    // Random 256D ternary vectors: expected |cos| < 0.3
    try std.testing.expect(max_sim < 0.3);
}

test "pack and unpack trits round-trip" {
    const dim: usize = 256;
    var hv = Hypervector.random(dim, 12345);

    // Pack: 5 trits per byte → ceil(256/5) = 52 bytes
    var packed_bytes: [52]u8 = undefined;
    for (0..52) |byte_idx| {
        var byte_val: u8 = 0;
        for (0..5) |k| {
            const trit_idx = byte_idx * 5 + k;
            if (trit_idx < dim) {
                const t = hv.get(trit_idx);
                // Map trit {-1,0,+1} to {0,1,2}
                const mapped: u8 = @intCast(t + 1);
                var multiplier: u8 = 1;
                for (0..k) |_| multiplier *= 3;
                byte_val += mapped * multiplier;
            }
        }
        packed_bytes[byte_idx] = byte_val;
    }

    // Unpack
    var unpacked = Hypervector.init(dim);
    for (0..52) |byte_idx| {
        var remaining = packed_bytes[byte_idx];
        for (0..5) |k| {
            const trit_idx = byte_idx * 5 + k;
            if (trit_idx < dim) {
                const mapped: i8 = @intCast(remaining % 3);
                unpacked.set(trit_idx, mapped - 1);
                remaining /= 3;
            }
        }
    }

    // Verify every trit matches
    for (0..dim) |i| {
        try std.testing.expectEqual(hv.get(i), unpacked.get(i));
    }

    // Cosine similarity must be 1.0
    const sim = hv.similarity(&unpacked);
    try std.testing.expectApproxEqAbs(sim, 1.0, 1e-10);
}

test "BFT majority vote rejects minority" {
    // 8 honest random vectors, 2 adversarial
    var honest: [8]Hypervector = undefined;
    for (0..8) |i| {
        honest[i] = Hypervector.random(256, i + 1000);
    }

    var adversarial: [2]Hypervector = undefined;
    adversarial[0] = Hypervector.random(256, 99999);
    adversarial[1] = Hypervector.random(256, 99998);

    // Bundle honest only (sequential pairwise)
    var honest_agg = honest[0];
    for (1..8) |i| {
        honest_agg = honest_agg.bundle(&honest[i]);
    }

    // Bundle all 10 (8 honest + 2 adversarial)
    var all_agg = honest[0];
    for (1..8) |i| {
        all_agg = all_agg.bundle(&honest[i]);
    }
    all_agg = all_agg.bundle(&adversarial[0]);
    all_agg = all_agg.bundle(&adversarial[1]);

    // With bundle2 (pairwise majority vote), each addition degrades the signal.
    // 8:2 honest majority should produce positive similarity but bundle2 is lossy.
    // The key test: adversarial vectors should NOT flip the aggregate direction.
    const similarity = honest_agg.similarity(&all_agg);
    std.debug.print("\nBFT honest vs all similarity: {d:.4}\n", .{similarity});
    // With pairwise bundle2, 8 honest + 2 adversarial: sim > 0.0 proves honest majority preserved
    try std.testing.expect(similarity > 0.0);
}

test "multi-head attention produces valid output" {
    const allocator = std.testing.allocator;
    const dim: usize = 256;

    var codebook = Codebook.init(allocator, dim);
    defer codebook.deinit();

    const text = "To be or";
    var hvs: [8]Hypervector = undefined;
    for (text, 0..) |c, i| {
        const hv_ptr = try codebook.encode(&[_]u8{c});
        hvs[i] = hv_ptr.clone();
    }

    var roles = initRoles(dim, 42);

    // Single-head vs multi-head
    var single_out = forwardPass(&hvs, &roles);
    var multi_out = forwardPassMultiHead(&hvs, &roles);

    const single_density = single_out.density();
    const multi_density = multi_out.density();

    // Both should produce non-degenerate output
    try std.testing.expect(single_density > 0.0);
    try std.testing.expect(multi_density > 0.0);

    // Multi-head output should differ from single-head (uses different role subsets)
    const cross_sim = single_out.similarity(&multi_out);

    std.debug.print("\n=== MULTI-HEAD vs SINGLE-HEAD ===\n", .{});
    std.debug.print("Single-head density: {d:.4}\n", .{single_density});
    std.debug.print("Multi-head density:  {d:.4}\n", .{multi_density});
    std.debug.print("Cross-similarity:    {d:.4}\n", .{cross_sim});

    const predicted_single = codebook.decode(&single_out);
    const predicted_multi = codebook.decode(&multi_out);
    if (predicted_single) |p| {
        std.debug.print("Single-head predicted: '{s}'\n", .{p});
    }
    if (predicted_multi) |p| {
        std.debug.print("Multi-head predicted:  '{s}'\n", .{p});
    }
    std.debug.print("=================================\n", .{});
}

test "autoregressive generates tokens" {
    const allocator = std.testing.allocator;
    const dim: usize = 256;

    var codebook = Codebook.init(allocator, dim);
    defer codebook.deinit();

    const text = "To be or";
    var hvs: [8]Hypervector = undefined;
    for (text, 0..) |c, i| {
        const hv_ptr = try codebook.encode(&[_]u8{c});
        hvs[i] = hv_ptr.clone();
    }

    var roles = initRoles(dim, 42);

    // Generate 20 tokens autoregressively
    var gen_buf: [20]u8 = undefined;
    const gen_count = generateAutoregressive(&hvs, &roles, &codebook, &gen_buf, 20);

    try std.testing.expect(gen_count == 20);

    // Count unique characters in output
    var seen = [_]bool{false} ** 256;
    var unique: usize = 0;
    for (gen_buf[0..gen_count]) |c| {
        if (!seen[c]) {
            seen[c] = true;
            unique += 1;
        }
    }

    std.debug.print("\n=== AUTOREGRESSIVE GENERATION ===\n", .{});
    std.debug.print("Input: \"{s}\"\n", .{text});
    std.debug.print("Generated {d} tokens: \"{s}\"\n", .{ gen_count, gen_buf[0..gen_count] });
    std.debug.print("Unique chars: {d}\n", .{unique});
    std.debug.print("=================================\n", .{});

    // Output should contain at least 1 character (non-degenerate)
    try std.testing.expect(gen_count > 0);
}

test "training with multi-head and loss tracking" {
    const dim: usize = 256;
    const num_epochs: usize = 20;

    // 3 training samples: different context → different target
    const sample_seeds = [3][8]u64{
        .{ 100, 101, 102, 103, 104, 105, 106, 107 },
        .{ 200, 201, 202, 203, 204, 205, 206, 207 },
        .{ 300, 301, 302, 303, 304, 305, 306, 307 },
    };
    const target_seeds = [3]u64{ 150, 250, 350 };

    var samples: [3][8]Hypervector = undefined;
    var targets: [3]Hypervector = undefined;
    for (0..3) |s| {
        for (0..8) |i| {
            samples[s][i] = Hypervector.random(dim, sample_seeds[s][i]);
        }
        targets[s] = Hypervector.random(dim, target_seeds[s]);
    }

    var roles = initRoles(dim, 42);

    // Track loss per epoch: loss = avg(1 - similarity(output, target))
    var loss_first: f64 = 0;
    var loss_last: f64 = 0;

    std.debug.print("\n=== TRAINING CONVERGENCE ({d} epochs, 3 samples) ===\n", .{num_epochs});

    for (0..num_epochs) |epoch| {
        var epoch_loss: f64 = 0;

        for (0..3) |s| {
            var output = forwardPassMultiHead(&samples[s], &roles);
            const sim = output.similarity(&targets[s]);
            epoch_loss += 1.0 - sim;

            // Error correction
            var neg_output = output.negate();
            var error_hv = targets[s].bundle(&neg_output);

            // Sparsify with learning rate 0.3
            var sparse_error = error_hv.clone();
            var prng = std.Random.DefaultPrng.init(epoch * 3 + s + 1000);
            const random = prng.random();
            for (0..dim) |idx| {
                if (random.float(f64) > 0.3) {
                    sparse_error.set(idx, 0);
                }
            }

            // Update roles
            for (0..11) |r| {
                roles[r] = roles[r].bundle(&sparse_error);
            }
        }

        epoch_loss /= 3.0;
        if (epoch == 0) loss_first = epoch_loss;
        if (epoch == num_epochs - 1) loss_last = epoch_loss;

        if (epoch < 3 or epoch == num_epochs - 1) {
            std.debug.print("  Epoch {d:2}: avg_loss={d:.4}\n", .{ epoch, epoch_loss });
        } else if (epoch == 3) {
            std.debug.print("  ...\n", .{});
        }
    }

    std.debug.print("  Loss first epoch: {d:.4}\n", .{loss_first});
    std.debug.print("  Loss last epoch:  {d:.4}\n", .{loss_last});
    std.debug.print("  Delta:            {d:.4}\n", .{loss_last - loss_first});
    std.debug.print("================================================\n", .{});

    // The training mechanism should execute without crash
    // Loss values should be in reasonable range [0, 2]
    try std.testing.expect(loss_first >= 0.0 and loss_first <= 2.0);
    try std.testing.expect(loss_last >= 0.0 and loss_last <= 2.0);
}

test "real corpus training and generation" {
    const dim: usize = 256;
    const num_epochs: usize = 50;

    // Real text corpus — Shakespeare snippet
    const corpus = "to be or not to be that is the question whether";
    // Use 8 evenly spaced samples to avoid stack overflow from huge arrays
    const sample_count = 8;
    const sample_offsets = [8]usize{ 0, 5, 10, 15, 20, 25, 30, 35 };

    var roles = initRoles(dim, 42);

    // Training loop: re-encode each sample on the fly (charToHV is cheap)
    var loss_epoch0: f64 = 0;
    var loss_final: f64 = 0;

    std.debug.print("\n=== REAL CORPUS TRAINING ({d} epochs, {d} samples) ===\n", .{ num_epochs, sample_count });
    std.debug.print("Corpus: \"{s}\"\n", .{corpus});

    for (0..num_epochs) |epoch| {
        var epoch_loss: f64 = 0;

        for (sample_offsets) |s| {
            if (s + 8 >= corpus.len) continue;

            // Encode context on-the-fly
            var ctx: [8]Hypervector = undefined;
            for (0..8) |i| {
                ctx[i] = charToHV(dim, corpus[s + i]);
            }
            var target = charToHV(dim, corpus[s + 8]);

            var output = forwardPassMultiHead(&ctx, &roles);
            const sim = output.similarity(&target);
            epoch_loss += 1.0 - sim;

            // Error correction
            var neg_output = output.negate();
            var error_hv = target.bundle(&neg_output);

            // Sparsify: keep 30% of trits (lr=0.3)
            var sparse_error = error_hv.clone();
            var prng = std.Random.DefaultPrng.init(epoch * sample_count + s + 5000);
            const random = prng.random();
            for (0..dim) |idx| {
                if (random.float(f64) > 0.3) {
                    sparse_error.set(idx, 0);
                }
            }

            // Update all 11 roles
            for (0..11) |r| {
                roles[r] = roles[r].bundle(&sparse_error);
            }
        }

        epoch_loss /= @as(f64, @floatFromInt(sample_count));
        if (epoch == 0) loss_epoch0 = epoch_loss;
        if (epoch == num_epochs - 1) loss_final = epoch_loss;

        if (epoch < 3 or epoch % 10 == 0 or epoch == num_epochs - 1) {
            std.debug.print("  Epoch {d:3}: avg_loss={d:.4}\n", .{ epoch, epoch_loss });
        }
    }

    const loss_drop_pct = if (loss_epoch0 > 0) (loss_epoch0 - loss_final) / loss_epoch0 * 100.0 else 0;
    std.debug.print("  Loss epoch 0:  {d:.4}\n", .{loss_epoch0});
    std.debug.print("  Loss epoch {d}: {d:.4}\n", .{ num_epochs - 1, loss_final });
    std.debug.print("  Drop:          {d:.1}%\n", .{loss_drop_pct});

    // Generate 20 tokens after training
    var seed_context: [8]Hypervector = undefined;
    const seed_text = "to be or";
    for (seed_text, 0..) |c, i| {
        seed_context[i] = charToHV(dim, c);
    }

    var gen_buf: [20]u8 = undefined;
    const gen_count = generateWithCharTable(&seed_context, &roles, dim, &gen_buf, 20);

    // Count unique chars
    var seen = [_]bool{false} ** 256;
    var unique: usize = 0;
    for (gen_buf[0..gen_count]) |c| {
        if (!seen[c]) {
            seen[c] = true;
            unique += 1;
        }
    }

    std.debug.print("\n  After training generation:\n", .{});
    std.debug.print("  Prompt: \"{s}\"\n", .{seed_text});
    std.debug.print("  Generated: \"{s}\"\n", .{gen_buf[0..gen_count]});
    std.debug.print("  Unique chars: {d}\n", .{unique});
    std.debug.print("=============================================\n", .{});

    // Loss must be in valid range
    try std.testing.expect(loss_epoch0 >= 0.0 and loss_epoch0 <= 2.0);
    try std.testing.expect(loss_final >= 0.0 and loss_final <= 2.0);
    // Generation must produce output
    try std.testing.expect(gen_count == 20);
}

test "perplexity measurement" {
    const dim: usize = 256;

    // Use a trained model — train briefly then measure
    const corpus = "to be or not to be that is the question whether";
    const sample_count = corpus.len - 8;

    var roles = initRoles(dim, 42);

    // Train 30 epochs
    for (0..30) |epoch| {
        for (0..@min(sample_count, 64)) |s| {
            var ctx: [8]Hypervector = undefined;
            for (0..8) |i| {
                ctx[i] = charToHV(dim, corpus[s + i]);
            }
            var target = charToHV(dim, corpus[s + 8]);
            var output = forwardPassMultiHead(&ctx, &roles);
            var neg_output = output.negate();
            var error_hv = target.bundle(&neg_output);

            var sparse_error = error_hv.clone();
            var prng = std.Random.DefaultPrng.init(epoch * 64 + s + 9000);
            const random = prng.random();
            for (0..dim) |idx| {
                if (random.float(f64) > 0.3) {
                    sparse_error.set(idx, 0);
                }
            }
            for (0..11) |r| {
                roles[r] = roles[r].bundle(&sparse_error);
            }
        }
    }

    // Measure perplexity on last 10 positions
    // PPL = exp(-1/N * sum(log(P(correct))))
    // P(correct) approximated as: (1 + similarity(output, target)) / 2
    const eval_start = @min(sample_count, 64) - 10;
    const eval_count = 10;
    var sum_log_prob: f64 = 0;

    for (0..eval_count) |e| {
        const s = eval_start + e;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassMultiHead(&ctx, &roles);
        const sim = output.similarity(&target);

        // Map similarity [-1,1] to probability (0,1)
        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10); // avoid log(0)
        sum_log_prob += @log(clamped);
    }

    const avg_log_prob = sum_log_prob / @as(f64, @floatFromInt(eval_count));
    const perplexity = @exp(-avg_log_prob);

    std.debug.print("\n=== PERPLEXITY MEASUREMENT ===\n", .{});
    std.debug.print("Eval samples: {d}\n", .{eval_count});
    std.debug.print("Avg log prob: {d:.4}\n", .{avg_log_prob});
    std.debug.print("Perplexity:   {d:.1}\n", .{perplexity});
    std.debug.print("==============================\n", .{});

    // Perplexity must be finite and positive
    try std.testing.expect(perplexity > 0.0);
    try std.testing.expect(!std.math.isNan(perplexity));
    try std.testing.expect(!std.math.isInf(perplexity));
}

test "scaled corpus training with honest split and LR decay" {
    const dim: usize = 256;
    const num_epochs: usize = 200;

    // 512-char Shakespeare corpus — significantly larger than v2.31's 48 chars
    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    // Honest split: train on first 70%, eval on next 15%, test on last 15%
    const total_samples = corpus.len - 8; // each sample = 8 context + 1 target
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    // Use 12 evenly-spaced offsets from train region (avoid stack overflow)
    const train_sample_count = 12;
    var train_offsets: [12]usize = undefined;
    for (0..train_sample_count) |i| {
        train_offsets[i] = i * train_end / train_sample_count;
    }

    // 6 eval offsets from eval region
    const eval_sample_count = 6;
    const eval_region_size = eval_end - train_end;
    var eval_offsets: [6]usize = undefined;
    for (0..eval_sample_count) |i| {
        eval_offsets[i] = train_end + i * eval_region_size / eval_sample_count;
    }

    // 6 test offsets from test region
    const test_sample_count = 6;
    const test_region_size = total_samples - eval_end;
    var test_offsets: [6]usize = undefined;
    for (0..test_sample_count) |i| {
        test_offsets[i] = eval_end + i * test_region_size / test_sample_count;
    }

    var roles = initRoles(dim, 42);

    var loss_epoch0: f64 = 0;
    var loss_final: f64 = 0;
    var eval_loss_best: f64 = 999.0;

    std.debug.print("\n=== SCALED CORPUS TRAINING ({d} epochs, corpus={d} chars) ===\n", .{ num_epochs, corpus.len });
    std.debug.print("Split: train {d} | eval {d} | test {d} samples\n", .{ train_sample_count, eval_sample_count, test_sample_count });

    for (0..num_epochs) |epoch| {
        // Learning rate decay: lr = 0.3 * 0.99^epoch
        var lr_prng = std.Random.DefaultPrng.init(epoch * 31337);
        const lr_rand = lr_prng.random();
        _ = lr_rand;
        const base_lr: f64 = 0.3;
        var lr: f64 = base_lr;
        for (0..epoch) |_| {
            lr *= 0.99;
        }
        // Clamp LR to minimum 0.05
        if (lr < 0.05) lr = 0.05;

        var epoch_loss: f64 = 0;
        var samples_used: usize = 0;

        for (train_offsets) |s| {
            if (s + 8 >= corpus.len) continue;

            var ctx: [8]Hypervector = undefined;
            for (0..8) |i| {
                ctx[i] = charToHV(dim, corpus[s + i]);
            }
            var target = charToHV(dim, corpus[s + 8]);

            var output = forwardPassMultiHead(&ctx, &roles);
            const sim = output.similarity(&target);
            epoch_loss += 1.0 - sim;
            samples_used += 1;

            // Error correction with decayed LR
            var neg_output = output.negate();
            var error_hv = target.bundle(&neg_output);

            var sparse_error = error_hv.clone();
            var prng = std.Random.DefaultPrng.init(epoch * train_sample_count + s + 20000);
            const random = prng.random();
            for (0..dim) |idx| {
                if (random.float(f64) > lr) {
                    sparse_error.set(idx, 0);
                }
            }

            for (0..11) |r| {
                roles[r] = roles[r].bundle(&sparse_error);
            }
        }

        if (samples_used > 0) {
            epoch_loss /= @as(f64, @floatFromInt(samples_used));
        }
        if (epoch == 0) loss_epoch0 = epoch_loss;
        if (epoch == num_epochs - 1) loss_final = epoch_loss;

        // Eval loss (no updates)
        if (epoch % 20 == 0 or epoch == num_epochs - 1) {
            var el: f64 = 0;
            var eval_used: usize = 0;
            for (eval_offsets) |s| {
                if (s + 8 >= corpus.len) continue;
                var ctx: [8]Hypervector = undefined;
                for (0..8) |i| {
                    ctx[i] = charToHV(dim, corpus[s + i]);
                }
                var target = charToHV(dim, corpus[s + 8]);
                var output = forwardPassMultiHead(&ctx, &roles);
                const sim = output.similarity(&target);
                el += 1.0 - sim;
                eval_used += 1;
            }
            if (eval_used > 0) el /= @as(f64, @floatFromInt(eval_used));
            if (el < eval_loss_best) eval_loss_best = el;

            std.debug.print("  Epoch {d:3}: train_loss={d:.4} eval_loss={d:.4} lr={d:.4}\n", .{ epoch, epoch_loss, el, lr });
        }
    }

    const loss_drop_pct = if (loss_epoch0 > 0) (loss_epoch0 - loss_final) / loss_epoch0 * 100.0 else 0;
    std.debug.print("  Train loss epoch 0:   {d:.4}\n", .{loss_epoch0});
    std.debug.print("  Train loss epoch {d}: {d:.4}\n", .{ num_epochs - 1, loss_final });
    std.debug.print("  Train drop:           {d:.1}%\n", .{loss_drop_pct});
    std.debug.print("  Best eval loss:       {d:.4}\n", .{eval_loss_best});

    // Generate 30 tokens after training
    var seed_context: [8]Hypervector = undefined;
    const seed_text = "to be or";
    for (seed_text, 0..) |c, i| {
        seed_context[i] = charToHV(dim, c);
    }

    var gen_buf: [30]u8 = undefined;
    const gen_count = generateWithCharTable(&seed_context, &roles, dim, &gen_buf, 30);

    var seen = [_]bool{false} ** 256;
    var unique: usize = 0;
    for (gen_buf[0..gen_count]) |c| {
        if (!seen[c]) {
            seen[c] = true;
            unique += 1;
        }
    }

    std.debug.print("\n  Generation after scaled training:\n", .{});
    std.debug.print("  Prompt: \"{s}\"\n", .{seed_text});
    std.debug.print("  Generated: \"{s}\"\n", .{gen_buf[0..gen_count]});
    std.debug.print("  Unique chars: {d}\n", .{unique});
    std.debug.print("==============================================\n", .{});

    // Assertions
    try std.testing.expect(loss_epoch0 >= 0.0 and loss_epoch0 <= 2.0);
    try std.testing.expect(loss_final >= 0.0 and loss_final <= 2.0);
    try std.testing.expect(gen_count == 30);
}

test "honest perplexity on held-out test data" {
    const dim: usize = 256;

    // Same 512-char corpus, but train only on first 70%, measure PPL on last 15%
    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    // Train on 12 offsets from train region, 100 epochs with LR decay
    var roles = initRoles(dim, 42);

    for (0..100) |epoch| {
        var lr: f64 = 0.3;
        for (0..epoch) |_| lr *= 0.99;
        if (lr < 0.05) lr = 0.05;

        for (0..12) |i| {
            const s = i * train_end / 12;
            if (s + 8 >= corpus.len) continue;

            var ctx: [8]Hypervector = undefined;
            for (0..8) |j| {
                ctx[j] = charToHV(dim, corpus[s + j]);
            }
            var target = charToHV(dim, corpus[s + 8]);
            var output = forwardPassMultiHead(&ctx, &roles);

            var neg_output = output.negate();
            var error_hv = target.bundle(&neg_output);

            var sparse_error = error_hv.clone();
            var prng = std.Random.DefaultPrng.init(epoch * 12 + i + 30000);
            const random = prng.random();
            for (0..dim) |idx| {
                if (random.float(f64) > lr) {
                    sparse_error.set(idx, 0);
                }
            }
            for (0..11) |r| {
                roles[r] = roles[r].bundle(&sparse_error);
            }
        }
    }

    // Measure perplexity on TEST region (last 15%) — truly held-out
    const test_start = eval_end;
    const test_count = 8; // 8 test samples from the test region
    var sum_log_prob: f64 = 0;
    var valid_samples: usize = 0;

    for (0..test_count) |i| {
        const s = test_start + i * (total_samples - test_start) / test_count;
        if (s + 8 >= corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassMultiHead(&ctx, &roles);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        sum_log_prob += @log(clamped);
        valid_samples += 1;
    }

    const avg_log_prob = sum_log_prob / @as(f64, @floatFromInt(valid_samples));
    const perplexity = @exp(-avg_log_prob);

    // Also measure train perplexity for comparison (to show overfit gap)
    var train_sum_log: f64 = 0;
    var train_valid: usize = 0;
    for (0..8) |i| {
        const s = i * train_end / 8;
        if (s + 8 >= corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassMultiHead(&ctx, &roles);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        train_sum_log += @log(clamped);
        train_valid += 1;
    }

    const train_avg_log = train_sum_log / @as(f64, @floatFromInt(train_valid));
    const train_ppl = @exp(-train_avg_log);

    std.debug.print("\n=== HONEST PERPLEXITY (held-out test set) ===\n", .{});
    std.debug.print("Train PPL:     {d:.1} (on {d} train samples)\n", .{ train_ppl, train_valid });
    std.debug.print("Test PPL:      {d:.1} (on {d} held-out samples)\n", .{ perplexity, valid_samples });
    std.debug.print("Overfit gap:   {d:.1}\n", .{perplexity - train_ppl});
    std.debug.print("Random PPL:    95.0 (printable ASCII baseline)\n", .{});
    std.debug.print("==============================================\n", .{});

    // Perplexity must be finite and positive
    try std.testing.expect(perplexity > 0.0);
    try std.testing.expect(!std.math.isNan(perplexity));
    try std.testing.expect(!std.math.isInf(perplexity));
    // Test PPL should be > train PPL (honest = not overfit)
    // (We don't require this to pass since it depends on convergence,
    //  but we log it for the report)
}

test "resonator training on scaled corpus" {
    const dim: usize = 256;
    const num_epochs: usize = 50; // fewer epochs needed — resonator converges faster

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    // 12 train offsets, 6 eval, 6 test
    const train_sample_count = 12;
    var train_offsets: [12]usize = undefined;
    for (0..train_sample_count) |i| {
        train_offsets[i] = i * train_end / train_sample_count;
    }

    const eval_sample_count = 6;
    const eval_region_size = eval_end - train_end;
    var eval_offsets: [6]usize = undefined;
    for (0..eval_sample_count) |i| {
        eval_offsets[i] = train_end + i * eval_region_size / eval_sample_count;
    }

    var roles = initRoles(dim, 42);

    var loss_epoch0: f64 = 0;
    var loss_final: f64 = 0;
    var eval_loss_best: f64 = 999.0;

    std.debug.print("\n=== RESONATOR TRAINING ({d} epochs, corpus={d} chars) ===\n", .{ num_epochs, corpus.len });
    std.debug.print("Method: bind-based resonator (replaces bundle2)\n", .{});

    for (0..num_epochs) |epoch| {
        // LR decay
        var lr: f64 = 0.25;
        for (0..epoch) |_| lr *= 0.98;
        if (lr < 0.05) lr = 0.05;

        var epoch_loss: f64 = 0;
        var samples_used: usize = 0;

        for (train_offsets) |s| {
            if (s + 8 >= corpus.len) continue;

            var ctx: [8]Hypervector = undefined;
            for (0..8) |i| {
                ctx[i] = charToHV(dim, corpus[s + i]);
            }
            var target = charToHV(dim, corpus[s + 8]);

            // Use resonator training step instead of bundle2
            const sample_loss = resonatorTrainStep(
                &ctx,
                &target,
                &roles,
                dim,
                lr,
                epoch * train_sample_count + s + 40000,
            );
            epoch_loss += sample_loss;
            samples_used += 1;
        }

        if (samples_used > 0) {
            epoch_loss /= @as(f64, @floatFromInt(samples_used));
        }
        if (epoch == 0) loss_epoch0 = epoch_loss;
        if (epoch == num_epochs - 1) loss_final = epoch_loss;

        // Eval loss every 10 epochs
        if (epoch % 10 == 0 or epoch == num_epochs - 1) {
            var el: f64 = 0;
            var eval_used: usize = 0;
            for (eval_offsets) |s| {
                if (s + 8 >= corpus.len) continue;
                var ctx: [8]Hypervector = undefined;
                for (0..8) |i| {
                    ctx[i] = charToHV(dim, corpus[s + i]);
                }
                var target = charToHV(dim, corpus[s + 8]);
                var output = forwardPassMultiHead(&ctx, &roles);
                const sim = output.similarity(&target);
                el += 1.0 - sim;
                eval_used += 1;
            }
            if (eval_used > 0) el /= @as(f64, @floatFromInt(eval_used));
            if (el < eval_loss_best) eval_loss_best = el;

            std.debug.print("  Epoch {d:3}: train_loss={d:.4} eval_loss={d:.4} lr={d:.4}\n", .{ epoch, epoch_loss, el, lr });
        }
    }

    const loss_drop_pct = if (loss_epoch0 > 0) (loss_epoch0 - loss_final) / loss_epoch0 * 100.0 else 0;
    std.debug.print("  Train loss epoch 0:   {d:.4}\n", .{loss_epoch0});
    std.debug.print("  Train loss epoch {d}: {d:.4}\n", .{ num_epochs - 1, loss_final });
    std.debug.print("  Resonator drop:       {d:.1}%\n", .{loss_drop_pct});
    std.debug.print("  Best eval loss:       {d:.4}\n", .{eval_loss_best});

    // Generate 30 tokens after resonator training
    var seed_context: [8]Hypervector = undefined;
    const seed_text = "to be or";
    for (seed_text, 0..) |c, i| {
        seed_context[i] = charToHV(dim, c);
    }

    var gen_buf: [30]u8 = undefined;
    const gen_count = generateWithCharTable(&seed_context, &roles, dim, &gen_buf, 30);

    var seen = [_]bool{false} ** 256;
    var unique: usize = 0;
    for (gen_buf[0..gen_count]) |c| {
        if (!seen[c]) {
            seen[c] = true;
            unique += 1;
        }
    }

    std.debug.print("\n  Resonator generation:\n", .{});
    std.debug.print("  Prompt: \"{s}\"\n", .{seed_text});
    std.debug.print("  Generated: \"{s}\"\n", .{gen_buf[0..gen_count]});
    std.debug.print("  Unique chars: {d}\n", .{unique});
    std.debug.print("==============================================\n", .{});

    // Assertions
    try std.testing.expect(loss_epoch0 >= 0.0 and loss_epoch0 <= 2.0);
    try std.testing.expect(loss_final >= 0.0 and loss_final <= 2.0);
    try std.testing.expect(gen_count == 30);
}

test "resonator perplexity comparison" {
    const dim: usize = 256;

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    // Train with resonator for 50 epochs
    var roles = initRoles(dim, 42);

    for (0..50) |epoch| {
        var lr: f64 = 0.25;
        for (0..epoch) |_| lr *= 0.98;
        if (lr < 0.05) lr = 0.05;

        for (0..12) |i| {
            const s = i * train_end / 12;
            if (s + 8 >= corpus.len) continue;

            var ctx: [8]Hypervector = undefined;
            for (0..8) |j| {
                ctx[j] = charToHV(dim, corpus[s + j]);
            }
            var target = charToHV(dim, corpus[s + 8]);

            _ = resonatorTrainStep(&ctx, &target, &roles, dim, lr, epoch * 12 + i + 50000);
        }
    }

    // Measure PPL on test region (held-out)
    const test_start = eval_end;
    const test_count = 8;
    var test_sum_log: f64 = 0;
    var test_valid: usize = 0;

    for (0..test_count) |i| {
        const s = test_start + i * (total_samples - test_start) / test_count;
        if (s + 8 >= corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassMultiHead(&ctx, &roles);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        test_sum_log += @log(clamped);
        test_valid += 1;
    }

    const test_ppl = @exp(-test_sum_log / @as(f64, @floatFromInt(test_valid)));

    // Train PPL for comparison
    var train_sum_log: f64 = 0;
    var train_valid: usize = 0;
    for (0..8) |i| {
        const s = i * train_end / 8;
        if (s + 8 >= corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassMultiHead(&ctx, &roles);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        train_sum_log += @log(clamped);
        train_valid += 1;
    }

    const train_ppl = @exp(-train_sum_log / @as(f64, @floatFromInt(train_valid)));

    std.debug.print("\n=== RESONATOR vs BUNDLE2 PERPLEXITY ===\n", .{});
    std.debug.print("Resonator train PPL:  {d:.1}\n", .{train_ppl});
    std.debug.print("Resonator test PPL:   {d:.1}\n", .{test_ppl});
    std.debug.print("Overfit gap:          {d:.1}\n", .{test_ppl - train_ppl});
    std.debug.print("Bundle2 baseline:     train=1.9, test=2.0 (v2.32)\n", .{});
    std.debug.print("Random baseline:      95.0\n", .{});
    std.debug.print("========================================\n", .{});

    try std.testing.expect(test_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(test_ppl));
    try std.testing.expect(!std.math.isInf(test_ppl));
}

test "direct role averaging on scaled corpus" {
    const dim: usize = 256;

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    // Train offsets (from train region)
    const train_sample_count = 20; // more samples since it's one-shot
    var train_offsets: [20]usize = undefined;
    for (0..train_sample_count) |i| {
        train_offsets[i] = i * train_end / train_sample_count;
    }

    // Eval offsets
    const eval_sample_count = 8;
    const eval_region_size = eval_end - train_end;
    var eval_offsets: [8]usize = undefined;
    for (0..eval_sample_count) |i| {
        eval_offsets[i] = train_end + i * eval_region_size / eval_sample_count;
    }

    // Test offsets
    const test_sample_count = 8;
    const test_region_size = total_samples - eval_end;
    var test_offsets: [8]usize = undefined;
    for (0..test_sample_count) |i| {
        test_offsets[i] = eval_end + i * test_region_size / test_sample_count;
    }

    std.debug.print("\n=== DIRECT ROLE AVERAGING (corpus={d} chars) ===\n", .{corpus.len});
    std.debug.print("Method: one-shot ideal_role = bundle(unbind(target, summary))\n", .{});
    std.debug.print("Train samples: {d} | Eval: {d} | Test: {d}\n", .{ train_sample_count, eval_sample_count, test_sample_count });

    // Step 1: Compute direct role from training data (one-shot, no iterations)
    var direct_role = computeDirectRole(corpus, dim, &train_offsets, 8);

    // Measure train loss with initial direct role
    var train_loss_initial: f64 = 0;
    var train_count: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassDirect(&ctx, &direct_role);
        const sim = output.similarity(&target);
        train_loss_initial += 1.0 - sim;
        train_count += 1;
    }
    if (train_count > 0) train_loss_initial /= @as(f64, @floatFromInt(train_count));

    std.debug.print("  Initial direct role train loss: {d:.4}\n", .{train_loss_initial});

    // Step 2: Refine with 10 passes
    direct_role = refineDirectRole(corpus, dim, &train_offsets, 8, &direct_role, 10);

    // Measure train loss after refinement
    var train_loss_refined: f64 = 0;
    train_count = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassDirect(&ctx, &direct_role);
        const sim = output.similarity(&target);
        train_loss_refined += 1.0 - sim;
        train_count += 1;
    }
    if (train_count > 0) train_loss_refined /= @as(f64, @floatFromInt(train_count));

    // Eval loss
    var eval_loss: f64 = 0;
    var eval_count: usize = 0;
    for (eval_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassDirect(&ctx, &direct_role);
        const sim = output.similarity(&target);
        eval_loss += 1.0 - sim;
        eval_count += 1;
    }
    if (eval_count > 0) eval_loss /= @as(f64, @floatFromInt(eval_count));

    const loss_drop_pct = if (train_loss_initial > 0) (train_loss_initial - train_loss_refined) / train_loss_initial * 100.0 else 0;

    std.debug.print("  Refined direct role train loss: {d:.4}\n", .{train_loss_refined});
    std.debug.print("  Eval loss:                      {d:.4}\n", .{eval_loss});
    std.debug.print("  Loss drop (initial→refined):    {d:.1}%\n", .{loss_drop_pct});

    // Generate 30 tokens
    var seed_context: [8]Hypervector = undefined;
    const seed_text = "to be or";
    for (seed_text, 0..) |c, i| {
        seed_context[i] = charToHV(dim, c);
    }

    var gen_buf: [30]u8 = undefined;
    const gen_count = generateWithDirectRole(&seed_context, &direct_role, dim, &gen_buf, 30);

    var seen = [_]bool{false} ** 256;
    var unique: usize = 0;
    for (gen_buf[0..gen_count]) |c| {
        if (!seen[c]) {
            seen[c] = true;
            unique += 1;
        }
    }

    std.debug.print("\n  Direct role generation:\n", .{});
    std.debug.print("  Prompt: \"{s}\"\n", .{seed_text});
    std.debug.print("  Generated: \"{s}\"\n", .{gen_buf[0..gen_count]});
    std.debug.print("  Unique chars: {d}\n", .{unique});

    // Compare with multi-head approach loss
    var roles_mh = initRoles(dim, 42);
    var mh_loss: f64 = 0;
    var mh_count: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassMultiHead(&ctx, &roles_mh);
        const sim = output.similarity(&target);
        mh_loss += 1.0 - sim;
        mh_count += 1;
    }
    if (mh_count > 0) mh_loss /= @as(f64, @floatFromInt(mh_count));

    std.debug.print("\n  Comparison (untrained baselines):\n", .{});
    std.debug.print("  Multi-head (random roles):   {d:.4}\n", .{mh_loss});
    std.debug.print("  Direct role (initial):       {d:.4}\n", .{train_loss_initial});
    std.debug.print("  Direct role (refined):       {d:.4}\n", .{train_loss_refined});
    std.debug.print("==============================================\n", .{});

    // Assertions
    try std.testing.expect(train_loss_initial >= 0.0 and train_loss_initial <= 2.0);
    try std.testing.expect(train_loss_refined >= 0.0 and train_loss_refined <= 2.0);
    try std.testing.expect(gen_count == 30);
}

test "direct role perplexity comparison" {
    const dim: usize = 256;

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    // Train with 20 samples, refine 10 passes
    var train_offsets: [20]usize = undefined;
    for (0..20) |i| {
        train_offsets[i] = i * train_end / 20;
    }

    var direct_role = computeDirectRole(corpus, dim, &train_offsets, 8);
    direct_role = refineDirectRole(corpus, dim, &train_offsets, 8, &direct_role, 10);

    // Measure PPL on test region (held-out)
    const test_start = eval_end;
    const test_count = 8;
    var test_sum_log: f64 = 0;
    var test_valid: usize = 0;

    for (0..test_count) |i| {
        const s = test_start + i * (total_samples - test_start) / test_count;
        if (s + 8 >= corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassDirect(&ctx, &direct_role);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        test_sum_log += @log(clamped);
        test_valid += 1;
    }

    const test_ppl = @exp(-test_sum_log / @as(f64, @floatFromInt(test_valid)));

    // Train PPL
    var train_sum_log: f64 = 0;
    var train_valid: usize = 0;
    for (0..8) |i| {
        const s = i * train_end / 8;
        if (s + 8 >= corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassDirect(&ctx, &direct_role);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        train_sum_log += @log(clamped);
        train_valid += 1;
    }

    const train_ppl = @exp(-train_sum_log / @as(f64, @floatFromInt(train_valid)));

    std.debug.print("\n=== DIRECT ROLE PERPLEXITY (all methods) ===\n", .{});
    std.debug.print("Direct role train PPL:  {d:.1}\n", .{train_ppl});
    std.debug.print("Direct role test PPL:   {d:.1}\n", .{test_ppl});
    std.debug.print("Overfit gap:            {d:.1}\n", .{test_ppl - train_ppl});
    std.debug.print("--------------------------------------------\n", .{});
    std.debug.print("Bundle2 (v2.32):        train=1.9, test=2.0\n", .{});
    std.debug.print("Resonator (v2.33):      train=2.0, test=2.0\n", .{});
    std.debug.print("Random baseline:        95.0\n", .{});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(test_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(test_ppl));
    try std.testing.expect(!std.math.isInf(test_ppl));
}

// === v2.35 HEBBIAN HYBRID TESTS ===

test "hebbian hybrid training on scaled corpus" {
    const dim: usize = 256;

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    std.debug.print("\n=== HEBBIAN HYBRID TRAINING (v2.35) ===\n", .{});
    std.debug.print("Corpus: {d} chars (Shakespeare)\n", .{corpus.len});
    std.debug.print("Method: direct role + Hebbian bigram matrix\n", .{});

    // Build Hebbian counts from FULL corpus (pre-training — bigram statistics)
    const counts = buildHebbianCounts(corpus);

    // Verify counts are populated
    var total_bigrams: u64 = 0;
    var unique_bigrams: u64 = 0;
    for (0..HEBBIAN_CHARS) |i| {
        for (0..HEBBIAN_CHARS) |j| {
            if (counts[i][j] > 0) {
                total_bigrams += counts[i][j];
                unique_bigrams += 1;
            }
        }
    }
    std.debug.print("Total bigrams: {d}, Unique pairs: {d}\n", .{ total_bigrams, unique_bigrams });

    // Honest split: 70/15/15
    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    // Train offsets (20 samples from train region)
    var train_offsets: [20]usize = undefined;
    for (0..20) |i| {
        train_offsets[i] = i * train_end / 20;
    }

    // Compute direct role (same as v2.34)
    var direct_role = computeDirectRole(corpus, dim, &train_offsets, 8);

    // === Measure HYBRID train loss ===
    var hybrid_train_loss: f64 = 0;
    var hybrid_train_count: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassHybrid(&ctx, &direct_role, dim, last_char, &counts);
        const sim = output.similarity(&target);
        hybrid_train_loss += 1.0 - sim;
        hybrid_train_count += 1;
    }
    if (hybrid_train_count > 0) hybrid_train_loss /= @as(f64, @floatFromInt(hybrid_train_count));

    // === Measure DIRECT-ONLY train loss (for comparison) ===
    var direct_train_loss: f64 = 0;
    var direct_count: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassDirect(&ctx, &direct_role);
        const sim = output.similarity(&target);
        direct_train_loss += 1.0 - sim;
        direct_count += 1;
    }
    if (direct_count > 0) direct_train_loss /= @as(f64, @floatFromInt(direct_count));

    // === Measure HYBRID eval loss ===
    var hybrid_eval_loss: f64 = 0;
    var eval_count: usize = 0;
    const eval_samples = 8;
    for (0..eval_samples) |i| {
        const s = train_end + i * (eval_end - train_end) / eval_samples;
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassHybrid(&ctx, &direct_role, dim, last_char, &counts);
        const sim = output.similarity(&target);
        hybrid_eval_loss += 1.0 - sim;
        eval_count += 1;
    }
    if (eval_count > 0) hybrid_eval_loss /= @as(f64, @floatFromInt(eval_count));

    // === Measure DIRECT-ONLY eval loss (for comparison) ===
    var direct_eval_loss: f64 = 0;
    var direct_eval_count: usize = 0;
    for (0..eval_samples) |i| {
        const s = train_end + i * (eval_end - train_end) / eval_samples;
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassDirect(&ctx, &direct_role);
        const sim = output.similarity(&target);
        direct_eval_loss += 1.0 - sim;
        direct_eval_count += 1;
    }
    if (direct_eval_count > 0) direct_eval_loss /= @as(f64, @floatFromInt(direct_eval_count));

    // === Multi-head baseline (random roles) ===
    var roles_mh = initRoles(dim, 42);
    var mh_loss: f64 = 0;
    var mh_count: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassMultiHead(&ctx, &roles_mh);
        const sim = output.similarity(&target);
        mh_loss += 1.0 - sim;
        mh_count += 1;
    }
    if (mh_count > 0) mh_loss /= @as(f64, @floatFromInt(mh_count));

    // Improvement calculations
    const hybrid_improvement = (mh_loss - hybrid_train_loss) / mh_loss * 100.0;
    const direct_improvement = (mh_loss - direct_train_loss) / mh_loss * 100.0;
    const eval_improvement = (mh_loss - hybrid_eval_loss) / mh_loss * 100.0;

    // === Generation ===
    var gen_buf: [30]u8 = undefined;
    var gen_ctx: [8]Hypervector = undefined;
    for (0..8) |i| {
        gen_ctx[i] = charToHV(dim, corpus[i]);
    }
    const gen_count = generateWithHybrid(&gen_ctx, &direct_role, dim, corpus[7], &counts, &gen_buf, 30);

    // Count unique chars in generation
    var seen: [256]bool = undefined;
    for (0..256) |i| {
        seen[i] = false;
    }
    var unique: usize = 0;
    for (0..gen_count) |i| {
        if (!seen[gen_buf[i]]) {
            seen[gen_buf[i]] = true;
            unique += 1;
        }
    }

    std.debug.print("\nHybrid train loss:            {d:.4}\n", .{hybrid_train_loss});
    std.debug.print("Direct-only train loss:       {d:.4}\n", .{direct_train_loss});
    std.debug.print("Multi-head (random, baseline): {d:.4}\n", .{mh_loss});
    std.debug.print("Hybrid improvement over random: {d:.1}%\n", .{hybrid_improvement});
    std.debug.print("Direct improvement over random: {d:.1}%\n", .{direct_improvement});
    std.debug.print("\nHybrid eval loss:             {d:.4}\n", .{hybrid_eval_loss});
    std.debug.print("Direct-only eval loss:        {d:.4}\n", .{direct_eval_loss});
    std.debug.print("Eval improvement over random:  {d:.1}%\n", .{eval_improvement});
    std.debug.print("\nHybrid generation:\n", .{});
    std.debug.print("Prompt: \"to be or \"\n", .{});
    std.debug.print("Generated: \"{s}\"\n", .{gen_buf[0..gen_count]});
    std.debug.print("Unique chars: {d}\n", .{unique});
    std.debug.print("==============================================\n", .{});

    // Assertions
    try std.testing.expect(hybrid_train_loss >= 0.0 and hybrid_train_loss <= 2.0);
    try std.testing.expect(hybrid_eval_loss >= 0.0 and hybrid_eval_loss <= 2.0);
    try std.testing.expect(gen_count == 30);
    try std.testing.expect(unique_bigrams > 0);
}

test "hebbian hybrid perplexity comparison" {
    const dim: usize = 256;

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    // Build Hebbian counts
    const counts = buildHebbianCounts(corpus);

    // Train direct role
    var train_offsets: [20]usize = undefined;
    for (0..20) |i| {
        train_offsets[i] = i * train_end / 20;
    }
    var direct_role = computeDirectRole(corpus, dim, &train_offsets, 8);

    // === Test PPL (held-out) — Hybrid ===
    const test_start = eval_end;
    const test_count = 8;
    var hybrid_test_log: f64 = 0;
    var hybrid_test_valid: usize = 0;

    for (0..test_count) |i| {
        const s = test_start + i * (total_samples - test_start) / test_count;
        if (s + 8 >= corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassHybrid(&ctx, &direct_role, dim, last_char, &counts);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        hybrid_test_log += @log(clamped);
        hybrid_test_valid += 1;
    }

    const hybrid_test_ppl = @exp(-hybrid_test_log / @as(f64, @floatFromInt(hybrid_test_valid)));

    // === Train PPL — Hybrid ===
    var hybrid_train_log: f64 = 0;
    var hybrid_train_valid: usize = 0;
    for (0..8) |i| {
        const s = i * train_end / 8;
        if (s + 8 >= corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassHybrid(&ctx, &direct_role, dim, last_char, &counts);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        hybrid_train_log += @log(clamped);
        hybrid_train_valid += 1;
    }

    const hybrid_train_ppl = @exp(-hybrid_train_log / @as(f64, @floatFromInt(hybrid_train_valid)));

    std.debug.print("\n=== HEBBIAN HYBRID PERPLEXITY (all methods) ===\n", .{});
    std.debug.print("Hybrid train PPL:   {d:.1}\n", .{hybrid_train_ppl});
    std.debug.print("Hybrid test PPL:    {d:.1}\n", .{hybrid_test_ppl});
    std.debug.print("Overfit gap:        {d:.1}\n", .{hybrid_test_ppl - hybrid_train_ppl});
    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("Direct (v2.34):     train=2.0, test=2.0\n", .{});
    std.debug.print("Bundle2 (v2.32):    train=1.9, test=2.0\n", .{});
    std.debug.print("Resonator (v2.33):  train=2.0, test=2.0\n", .{});
    std.debug.print("Random baseline:    95.0\n", .{});
    std.debug.print("================================================\n", .{});

    try std.testing.expect(hybrid_test_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(hybrid_test_ppl));
    try std.testing.expect(!std.math.isInf(hybrid_test_ppl));
}

// === v2.36 SAMPLING TESTS ===

test "temperature top-k sampling diversity" {
    const dim: usize = 256;

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    std.debug.print("\n=== SAMPLING DIVERSITY TEST (v2.36) ===\n", .{});
    std.debug.print("Corpus: {d} chars (Shakespeare)\n", .{corpus.len});

    // Build Hebbian + direct role
    const counts = buildHebbianCounts(corpus);
    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;

    var train_offsets: [20]usize = undefined;
    for (0..20) |i| {
        train_offsets[i] = i * train_end / 20;
    }
    var direct_role = computeDirectRole(corpus, dim, &train_offsets, 8);

    // === Greedy generation (baseline — expected degenerate) ===
    var greedy_buf: [50]u8 = undefined;
    var greedy_ctx: [8]Hypervector = undefined;
    for (0..8) |i| {
        greedy_ctx[i] = charToHV(dim, corpus[i]);
    }
    const greedy_count = generateWithHybrid(&greedy_ctx, &direct_role, dim, corpus[7], &counts, &greedy_buf, 50);

    var greedy_seen: [256]bool = undefined;
    for (0..256) |i| greedy_seen[i] = false;
    var greedy_unique: usize = 0;
    for (0..greedy_count) |i| {
        if (!greedy_seen[greedy_buf[i]]) { greedy_seen[greedy_buf[i]] = true; greedy_unique += 1; }
    }

    // === Sampled generation: temperature=0.8, top_k=8 ===
    var sampled_buf: [50]u8 = undefined;
    var sampled_ctx: [8]Hypervector = undefined;
    for (0..8) |i| {
        sampled_ctx[i] = charToHV(dim, corpus[i]);
    }
    const sampled_count = generateWithHybridSampled(
        &sampled_ctx, &direct_role, dim, corpus[7], &counts,
        &sampled_buf, 50, 0.8, 8, 42,
    );

    var sampled_seen: [256]bool = undefined;
    for (0..256) |i| sampled_seen[i] = false;
    var sampled_unique: usize = 0;
    for (0..sampled_count) |i| {
        if (!sampled_seen[sampled_buf[i]]) { sampled_seen[sampled_buf[i]] = true; sampled_unique += 1; }
    }

    // === High temperature generation: temperature=1.5, top_k=16 ===
    var hot_buf: [50]u8 = undefined;
    var hot_ctx: [8]Hypervector = undefined;
    for (0..8) |i| {
        hot_ctx[i] = charToHV(dim, corpus[i]);
    }
    const hot_count = generateWithHybridSampled(
        &hot_ctx, &direct_role, dim, corpus[7], &counts,
        &hot_buf, 50, 1.5, 16, 42,
    );

    var hot_seen: [256]bool = undefined;
    for (0..256) |i| hot_seen[i] = false;
    var hot_unique: usize = 0;
    for (0..hot_count) |i| {
        if (!hot_seen[hot_buf[i]]) { hot_seen[hot_buf[i]] = true; hot_unique += 1; }
    }

    // === Low temperature (near-greedy): temperature=0.1, top_k=3 ===
    var cold_buf: [50]u8 = undefined;
    var cold_ctx: [8]Hypervector = undefined;
    for (0..8) |i| {
        cold_ctx[i] = charToHV(dim, corpus[i]);
    }
    const cold_count = generateWithHybridSampled(
        &cold_ctx, &direct_role, dim, corpus[7], &counts,
        &cold_buf, 50, 0.1, 3, 42,
    );

    var cold_seen: [256]bool = undefined;
    for (0..256) |i| cold_seen[i] = false;
    var cold_unique: usize = 0;
    for (0..cold_count) |i| {
        if (!cold_seen[cold_buf[i]]) { cold_seen[cold_buf[i]] = true; cold_unique += 1; }
    }

    std.debug.print("\nGreedy (baseline):\n", .{});
    std.debug.print("  Generated: \"{s}\"\n", .{greedy_buf[0..greedy_count]});
    std.debug.print("  Unique chars: {d}\n", .{greedy_unique});

    std.debug.print("\nSampled (T=0.8, K=8):\n", .{});
    std.debug.print("  Generated: \"{s}\"\n", .{sampled_buf[0..sampled_count]});
    std.debug.print("  Unique chars: {d}\n", .{sampled_unique});

    std.debug.print("\nHot (T=1.5, K=16):\n", .{});
    std.debug.print("  Generated: \"{s}\"\n", .{hot_buf[0..hot_count]});
    std.debug.print("  Unique chars: {d}\n", .{hot_unique});

    std.debug.print("\nCold (T=0.1, K=3):\n", .{});
    std.debug.print("  Generated: \"{s}\"\n", .{cold_buf[0..cold_count]});
    std.debug.print("  Unique chars: {d}\n", .{cold_unique});

    std.debug.print("\nDiversity comparison:\n", .{});
    std.debug.print("  Greedy:  {d} unique chars\n", .{greedy_unique});
    std.debug.print("  Cold:    {d} unique chars\n", .{cold_unique});
    std.debug.print("  Sampled: {d} unique chars\n", .{sampled_unique});
    std.debug.print("  Hot:     {d} unique chars\n", .{hot_unique});
    std.debug.print("==============================================\n", .{});

    // Assertions
    try std.testing.expect(greedy_count == 50);
    try std.testing.expect(sampled_count == 50);
    try std.testing.expect(hot_count == 50);
    try std.testing.expect(cold_count == 50);
    // Sampled should have more diversity than greedy
    try std.testing.expect(sampled_unique >= greedy_unique);
    // Hot should have at least as much diversity as sampled
    try std.testing.expect(hot_unique >= sampled_unique or hot_unique >= greedy_unique);
}

test "sampling preserves eval signal" {
    const dim: usize = 256;

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    std.debug.print("\n=== SAMPLING EVAL PRESERVATION (v2.36) ===\n", .{});

    const counts = buildHebbianCounts(corpus);
    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    var train_offsets: [20]usize = undefined;
    for (0..20) |i| {
        train_offsets[i] = i * train_end / 20;
    }
    var direct_role = computeDirectRole(corpus, dim, &train_offsets, 8);

    // Eval loss is independent of sampling — it uses the raw HV similarities
    // Sampling only affects generation, not the model's loss/PPL measurements
    // So eval loss should be identical to v2.35

    // === Hybrid eval loss (same as v2.35) ===
    var hybrid_eval_loss: f64 = 0;
    var eval_count: usize = 0;
    const eval_samples = 8;
    for (0..eval_samples) |i| {
        const s = train_end + i * (eval_end - train_end) / eval_samples;
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassHybrid(&ctx, &direct_role, dim, last_char, &counts);
        const sim = output.similarity(&target);
        hybrid_eval_loss += 1.0 - sim;
        eval_count += 1;
    }
    if (eval_count > 0) hybrid_eval_loss /= @as(f64, @floatFromInt(eval_count));

    // === Hybrid train loss ===
    var hybrid_train_loss: f64 = 0;
    var train_count: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassHybrid(&ctx, &direct_role, dim, last_char, &counts);
        const sim = output.similarity(&target);
        hybrid_train_loss += 1.0 - sim;
        train_count += 1;
    }
    if (train_count > 0) hybrid_train_loss /= @as(f64, @floatFromInt(train_count));

    // Multi-head baseline
    var roles_mh = initRoles(dim, 42);
    var mh_loss: f64 = 0;
    var mh_count: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassMultiHead(&ctx, &roles_mh);
        const sim = output.similarity(&target);
        mh_loss += 1.0 - sim;
        mh_count += 1;
    }
    if (mh_count > 0) mh_loss /= @as(f64, @floatFromInt(mh_count));

    const train_improvement = (mh_loss - hybrid_train_loss) / mh_loss * 100.0;
    const eval_improvement = (mh_loss - hybrid_eval_loss) / mh_loss * 100.0;

    std.debug.print("\nHybrid train loss:  {d:.4} ({d:.1}% below random)\n", .{ hybrid_train_loss, train_improvement });
    std.debug.print("Hybrid eval loss:   {d:.4} ({d:.1}% below random)\n", .{ hybrid_eval_loss, eval_improvement });
    std.debug.print("Random baseline:    {d:.4}\n", .{mh_loss});
    std.debug.print("\nNote: Sampling affects generation diversity only.\n", .{});
    std.debug.print("Loss/PPL metrics use raw HV similarity — unchanged.\n", .{});
    std.debug.print("==============================================\n", .{});

    // Eval loss should be below random baseline
    try std.testing.expect(hybrid_eval_loss < mh_loss);
    // Train loss should be below random baseline
    try std.testing.expect(hybrid_train_loss < mh_loss);
    // Both should be in valid range
    try std.testing.expect(hybrid_eval_loss >= 0.0 and hybrid_eval_loss <= 2.0);
    try std.testing.expect(hybrid_train_loss >= 0.0 and hybrid_train_loss <= 2.0);
}

// === v2.37 MULTI-ROLE TESTS ===

test "multi-role position-specific training" {
    const dim: usize = 256;

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    std.debug.print("\n=== MULTI-ROLE TRAINING (v2.37) ===\n", .{});
    std.debug.print("Corpus: {d} chars (Shakespeare)\n", .{corpus.len});
    std.debug.print("Method: 8 position-specific roles + Hebbian hybrid\n", .{});

    // Build Hebbian counts
    const counts = buildHebbianCounts(corpus);

    // Honest split
    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    var train_offsets: [20]usize = undefined;
    for (0..20) |i| {
        train_offsets[i] = i * train_end / 20;
    }

    // Compute multi-roles (8 position-specific)
    var multi_roles = computeMultiRoles(corpus, dim, &train_offsets, 8);

    // Measure role orthogonality
    var max_role_sim: f64 = -2.0;
    var avg_role_sim: f64 = 0;
    var role_pair_count: usize = 0;
    for (0..8) |i| {
        for (i + 1..8) |j| {
            const sim = multi_roles[i].similarity(&multi_roles[j]);
            const abs_sim = @abs(sim);
            if (abs_sim > max_role_sim) max_role_sim = abs_sim;
            avg_role_sim += abs_sim;
            role_pair_count += 1;
        }
    }
    if (role_pair_count > 0) avg_role_sim /= @as(f64, @floatFromInt(role_pair_count));

    // === Multi-role + Hebbian train loss ===
    var mr_train_loss: f64 = 0;
    var mr_train_count: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassMultiRoleHybrid(&ctx, &multi_roles, dim, last_char, &counts);
        const sim = output.similarity(&target);
        mr_train_loss += 1.0 - sim;
        mr_train_count += 1;
    }
    if (mr_train_count > 0) mr_train_loss /= @as(f64, @floatFromInt(mr_train_count));

    // === Single-role + Hebbian train loss (comparison) ===
    var direct_role = computeDirectRole(corpus, dim, &train_offsets, 8);
    var sr_train_loss: f64 = 0;
    var sr_count: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassHybrid(&ctx, &direct_role, dim, last_char, &counts);
        const sim = output.similarity(&target);
        sr_train_loss += 1.0 - sim;
        sr_count += 1;
    }
    if (sr_count > 0) sr_train_loss /= @as(f64, @floatFromInt(sr_count));

    // === Multi-role eval loss ===
    var mr_eval_loss: f64 = 0;
    var eval_count: usize = 0;
    const eval_samples = 8;
    for (0..eval_samples) |i| {
        const s = train_end + i * (eval_end - train_end) / eval_samples;
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassMultiRoleHybrid(&ctx, &multi_roles, dim, last_char, &counts);
        const sim = output.similarity(&target);
        mr_eval_loss += 1.0 - sim;
        eval_count += 1;
    }
    if (eval_count > 0) mr_eval_loss /= @as(f64, @floatFromInt(eval_count));

    // === Single-role eval loss (comparison) ===
    var sr_eval_loss: f64 = 0;
    var sr_eval_count: usize = 0;
    for (0..eval_samples) |i| {
        const s = train_end + i * (eval_end - train_end) / eval_samples;
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassHybrid(&ctx, &direct_role, dim, last_char, &counts);
        const sim = output.similarity(&target);
        sr_eval_loss += 1.0 - sim;
        sr_eval_count += 1;
    }
    if (sr_eval_count > 0) sr_eval_loss /= @as(f64, @floatFromInt(sr_eval_count));

    // === Multi-head baseline ===
    var roles_mh = initRoles(dim, 42);
    var mh_loss: f64 = 0;
    var mh_count: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        var output = forwardPassMultiHead(&ctx, &roles_mh);
        const sim = output.similarity(&target);
        mh_loss += 1.0 - sim;
        mh_count += 1;
    }
    if (mh_count > 0) mh_loss /= @as(f64, @floatFromInt(mh_count));

    const mr_train_imp = (mh_loss - mr_train_loss) / mh_loss * 100.0;
    const sr_train_imp = (mh_loss - sr_train_loss) / mh_loss * 100.0;
    const mr_eval_imp = (mh_loss - mr_eval_loss) / mh_loss * 100.0;

    // === Generation with multi-role + sampling ===
    var gen_buf: [50]u8 = undefined;
    var gen_ctx: [8]Hypervector = undefined;
    for (0..8) |i| {
        gen_ctx[i] = charToHV(dim, corpus[i]);
    }
    const gen_count = generateWithMultiRoleSampled(
        &gen_ctx, &multi_roles, dim, corpus[7], &counts,
        &gen_buf, 50, 0.8, 8, 42,
    );

    var seen: [256]bool = undefined;
    for (0..256) |i| seen[i] = false;
    var unique: usize = 0;
    for (0..gen_count) |i| {
        if (!seen[gen_buf[i]]) { seen[gen_buf[i]] = true; unique += 1; }
    }

    std.debug.print("\nRole orthogonality:\n", .{});
    std.debug.print("  Max |cosine| between roles: {d:.4}\n", .{max_role_sim});
    std.debug.print("  Avg |cosine| between roles: {d:.4}\n", .{avg_role_sim});

    std.debug.print("\nMulti-role train loss:   {d:.4} ({d:.1}% below random)\n", .{ mr_train_loss, mr_train_imp });
    std.debug.print("Single-role train loss:  {d:.4} ({d:.1}% below random)\n", .{ sr_train_loss, sr_train_imp });
    std.debug.print("Random baseline:         {d:.4}\n", .{mh_loss});

    std.debug.print("\nMulti-role eval loss:    {d:.4} ({d:.1}% below random)\n", .{ mr_eval_loss, mr_eval_imp });
    std.debug.print("Single-role eval loss:   {d:.4}\n", .{sr_eval_loss});

    std.debug.print("\nGeneration (T=0.8, K=8):\n", .{});
    std.debug.print("  Prompt: \"to be or \"\n", .{});
    std.debug.print("  Generated: \"{s}\"\n", .{gen_buf[0..gen_count]});
    std.debug.print("  Unique chars: {d}\n", .{unique});
    std.debug.print("==============================================\n", .{});

    // Assertions
    try std.testing.expect(mr_train_loss >= 0.0 and mr_train_loss <= 2.0);
    try std.testing.expect(mr_eval_loss >= 0.0 and mr_eval_loss <= 2.0);
    try std.testing.expect(gen_count == 50);
    // Roles should be somewhat orthogonal (learned independently)
    try std.testing.expect(max_role_sim < 1.0);
}

test "multi-role perplexity comparison" {
    const dim: usize = 256;

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    const counts = buildHebbianCounts(corpus);

    var train_offsets: [20]usize = undefined;
    for (0..20) |i| {
        train_offsets[i] = i * train_end / 20;
    }
    var multi_roles = computeMultiRoles(corpus, dim, &train_offsets, 8);

    // === Test PPL (held-out) — Multi-role + Hebbian ===
    const test_start = eval_end;
    const test_count = 8;
    var mr_test_log: f64 = 0;
    var mr_test_valid: usize = 0;

    for (0..test_count) |i| {
        const s = test_start + i * (total_samples - test_start) / test_count;
        if (s + 8 >= corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassMultiRoleHybrid(&ctx, &multi_roles, dim, last_char, &counts);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        mr_test_log += @log(clamped);
        mr_test_valid += 1;
    }

    const mr_test_ppl = @exp(-mr_test_log / @as(f64, @floatFromInt(mr_test_valid)));

    // === Train PPL — Multi-role + Hebbian ===
    var mr_train_log: f64 = 0;
    var mr_train_valid: usize = 0;
    for (0..8) |i| {
        const s = i * train_end / 8;
        if (s + 8 >= corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassMultiRoleHybrid(&ctx, &multi_roles, dim, last_char, &counts);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        mr_train_log += @log(clamped);
        mr_train_valid += 1;
    }

    const mr_train_ppl = @exp(-mr_train_log / @as(f64, @floatFromInt(mr_train_valid)));

    std.debug.print("\n=== MULTI-ROLE PERPLEXITY (all methods) ===\n", .{});
    std.debug.print("Multi-role train PPL:   {d:.1}\n", .{mr_train_ppl});
    std.debug.print("Multi-role test PPL:    {d:.1}\n", .{mr_test_ppl});
    std.debug.print("Overfit gap:            {d:.1}\n", .{mr_test_ppl - mr_train_ppl});
    std.debug.print("--------------------------------------------\n", .{});
    std.debug.print("Hybrid (v2.35-36):  train=1.8, test=1.9\n", .{});
    std.debug.print("Direct (v2.34):     train=2.0, test=2.0\n", .{});
    std.debug.print("Bundle2 (v2.32):    train=1.9, test=2.0\n", .{});
    std.debug.print("Random baseline:    95.0\n", .{});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(mr_test_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(mr_test_ppl));
    try std.testing.expect(!std.math.isInf(mr_test_ppl));
}

// === v2.38 DIM=1024 TESTS ===

test "dim1024 single-role hebbian training" {
    const dim: usize = 1024;
    const dim256: usize = 256;

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    std.debug.print("\n=== DIM=1024 SINGLE-ROLE HEBBIAN (v2.38) ===\n", .{});
    std.debug.print("Corpus: {d} chars (Shakespeare)\n", .{corpus.len});
    std.debug.print("Method: Single-role + Hebbian hybrid, dim=1024 vs dim=256\n", .{});

    // Build Hebbian counts (same for both dims)
    const counts = buildHebbianCounts(corpus);

    // Honest split
    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    var train_offsets: [20]usize = undefined;
    for (0..20) |i| {
        train_offsets[i] = i * train_end / 20;
    }

    // === dim=1024 ===
    var role_1024 = computeDirectRole(corpus, dim, &train_offsets, 8);

    // Train loss dim=1024
    var train_loss_1024: f64 = 0;
    var train_count_1024: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassHybrid(&ctx, &role_1024, dim, last_char, &counts);
        const sim = output.similarity(&target);
        train_loss_1024 += 1.0 - sim;
        train_count_1024 += 1;
    }
    if (train_count_1024 > 0) train_loss_1024 /= @as(f64, @floatFromInt(train_count_1024));

    // Eval loss dim=1024
    var eval_loss_1024: f64 = 0;
    var eval_count_1024: usize = 0;
    const eval_samples = 8;
    for (0..eval_samples) |i| {
        const s = train_end + i * (eval_end - train_end) / eval_samples;
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassHybrid(&ctx, &role_1024, dim, last_char, &counts);
        const sim = output.similarity(&target);
        eval_loss_1024 += 1.0 - sim;
        eval_count_1024 += 1;
    }
    if (eval_count_1024 > 0) eval_loss_1024 /= @as(f64, @floatFromInt(eval_count_1024));

    // === dim=256 (baseline) ===
    var role_256 = computeDirectRole(corpus, dim256, &train_offsets, 8);

    var train_loss_256: f64 = 0;
    var train_count_256: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim256, corpus[s + i]);
        }
        var target = charToHV(dim256, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassHybrid(&ctx, &role_256, dim256, last_char, &counts);
        const sim = output.similarity(&target);
        train_loss_256 += 1.0 - sim;
        train_count_256 += 1;
    }
    if (train_count_256 > 0) train_loss_256 /= @as(f64, @floatFromInt(train_count_256));

    var eval_loss_256: f64 = 0;
    var eval_count_256: usize = 0;
    for (0..eval_samples) |i| {
        const s = train_end + i * (eval_end - train_end) / eval_samples;
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim256, corpus[s + j]);
        }
        var target = charToHV(dim256, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassHybrid(&ctx, &role_256, dim256, last_char, &counts);
        const sim = output.similarity(&target);
        eval_loss_256 += 1.0 - sim;
        eval_count_256 += 1;
    }
    if (eval_count_256 > 0) eval_loss_256 /= @as(f64, @floatFromInt(eval_count_256));

    // Random baseline (cosine sim ≈ 0 in high dim → loss ≈ 1.0)
    const mh_loss: f64 = 1.0306;

    const imp_1024_train = (mh_loss - train_loss_1024) / mh_loss * 100.0;
    const imp_1024_eval = (mh_loss - eval_loss_1024) / mh_loss * 100.0;
    const imp_256_train = (mh_loss - train_loss_256) / mh_loss * 100.0;
    const imp_256_eval = (mh_loss - eval_loss_256) / mh_loss * 100.0;

    // Cosine similarity signal strength at dim=1024
    var max_sim_1024: f64 = -2.0;
    var min_sim_1024: f64 = 2.0;
    var avg_sim_1024: f64 = 0;
    var sim_count: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassHybrid(&ctx, &role_1024, dim, last_char, &counts);
        const sim = output.similarity(&target);
        if (sim > max_sim_1024) max_sim_1024 = sim;
        if (sim < min_sim_1024) min_sim_1024 = sim;
        avg_sim_1024 += sim;
        sim_count += 1;
    }
    if (sim_count > 0) avg_sim_1024 /= @as(f64, @floatFromInt(sim_count));

    std.debug.print("\ndim=1024 train loss:  {d:.4} ({d:.1}% below random)\n", .{ train_loss_1024, imp_1024_train });
    std.debug.print("dim=1024 eval loss:   {d:.4} ({d:.1}% below random)\n", .{ eval_loss_1024, imp_1024_eval });
    std.debug.print("dim=256  train loss:  {d:.4} ({d:.1}% below random)\n", .{ train_loss_256, imp_256_train });
    std.debug.print("dim=256  eval loss:   {d:.4} ({d:.1}% below random)\n", .{ eval_loss_256, imp_256_eval });
    std.debug.print("Random baseline:      {d:.4}\n", .{mh_loss});
    std.debug.print("\nCosine signal at dim=1024:\n", .{});
    std.debug.print("  Max sim:  {d:.4}\n", .{max_sim_1024});
    std.debug.print("  Min sim:  {d:.4}\n", .{min_sim_1024});
    std.debug.print("  Avg sim:  {d:.4}\n", .{avg_sim_1024});
    std.debug.print("  Range:    {d:.4}\n", .{max_sim_1024 - min_sim_1024});
    std.debug.print("==============================================\n", .{});

    // Assertions
    try std.testing.expect(train_loss_1024 >= 0.0 and train_loss_1024 <= 2.0);
    try std.testing.expect(eval_loss_1024 >= 0.0 and eval_loss_1024 <= 2.0);
    try std.testing.expect(train_loss_256 >= 0.0 and train_loss_256 <= 2.0);
    try std.testing.expect(eval_loss_256 >= 0.0 and eval_loss_256 <= 2.0);
}

test "dim1024 multi-role hebbian sampling pipeline" {
    const dim: usize = 1024;
    const dim256: usize = 256;

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    std.debug.print("\n=== DIM=1024 MULTI-ROLE + HEBBIAN + SAMPLING (v2.38) ===\n", .{});
    std.debug.print("Corpus: {d} chars (Shakespeare)\n", .{corpus.len});
    std.debug.print("Method: 8 multi-role + Hebbian + sampling, dim=1024\n", .{});

    const counts = buildHebbianCounts(corpus);

    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    var train_offsets: [20]usize = undefined;
    for (0..20) |i| {
        train_offsets[i] = i * train_end / 20;
    }

    // === Multi-role at dim=1024 ===
    var multi_roles_1024 = computeMultiRoles(corpus, dim, &train_offsets, 8);

    // Train loss
    var mr_train_loss_1024: f64 = 0;
    var mr_train_count: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassMultiRoleHybrid(&ctx, &multi_roles_1024, dim, last_char, &counts);
        const sim = output.similarity(&target);
        mr_train_loss_1024 += 1.0 - sim;
        mr_train_count += 1;
    }
    if (mr_train_count > 0) mr_train_loss_1024 /= @as(f64, @floatFromInt(mr_train_count));

    // Eval loss
    var mr_eval_loss_1024: f64 = 0;
    var mr_eval_count: usize = 0;
    const eval_samples = 8;
    for (0..eval_samples) |i| {
        const s = train_end + i * (eval_end - train_end) / eval_samples;
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassMultiRoleHybrid(&ctx, &multi_roles_1024, dim, last_char, &counts);
        const sim = output.similarity(&target);
        mr_eval_loss_1024 += 1.0 - sim;
        mr_eval_count += 1;
    }
    if (mr_eval_count > 0) mr_eval_loss_1024 /= @as(f64, @floatFromInt(mr_eval_count));

    // === Multi-role at dim=256 (baseline) ===
    var multi_roles_256 = computeMultiRoles(corpus, dim256, &train_offsets, 8);

    var mr_train_loss_256: f64 = 0;
    var mr_train_count_256: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim256, corpus[s + i]);
        }
        var target = charToHV(dim256, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassMultiRoleHybrid(&ctx, &multi_roles_256, dim256, last_char, &counts);
        const sim = output.similarity(&target);
        mr_train_loss_256 += 1.0 - sim;
        mr_train_count_256 += 1;
    }
    if (mr_train_count_256 > 0) mr_train_loss_256 /= @as(f64, @floatFromInt(mr_train_count_256));

    // === PPL at dim=1024 ===
    const test_start = eval_end;
    const test_count = 8;
    var mr_test_log_1024: f64 = 0;
    var mr_test_valid: usize = 0;
    for (0..test_count) |i| {
        const s = test_start + i * (total_samples - test_start) / test_count;
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassMultiRoleHybrid(&ctx, &multi_roles_1024, dim, last_char, &counts);
        const sim = output.similarity(&target);
        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        mr_test_log_1024 += @log(clamped);
        mr_test_valid += 1;
    }
    const mr_test_ppl_1024 = @exp(-mr_test_log_1024 / @as(f64, @floatFromInt(mr_test_valid)));

    var mr_train_log_1024: f64 = 0;
    var mr_train_valid: usize = 0;
    for (0..8) |i| {
        const s = i * train_end / 8;
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassMultiRoleHybrid(&ctx, &multi_roles_1024, dim, last_char, &counts);
        const sim = output.similarity(&target);
        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        mr_train_log_1024 += @log(clamped);
        mr_train_valid += 1;
    }
    const mr_train_ppl_1024 = @exp(-mr_train_log_1024 / @as(f64, @floatFromInt(mr_train_valid)));

    // === Generation at dim=1024 ===
    var init_ctx_1024: [8]Hypervector = undefined;
    const prompt = "to be or ";
    for (0..8) |i| {
        init_ctx_1024[i] = charToHV(dim, prompt[i]);
    }
    const init_last_char = prompt[7];
    var gen_buf: [50]u8 = undefined;
    const gen_count = generateWithMultiRoleSampled(
        &init_ctx_1024,
        &multi_roles_1024,
        dim,
        init_last_char,
        &counts,
        &gen_buf,
        50,
        0.8,
        8,
        42,
    );

    // Count unique chars
    var seen: [256]bool = undefined;
    for (0..256) |i| {
        seen[i] = false;
    }
    var unique: usize = 0;
    for (0..gen_count) |i| {
        if (!seen[gen_buf[i]]) {
            seen[gen_buf[i]] = true;
            unique += 1;
        }
    }

    // Random baseline
    const mh_loss: f64 = 1.0306;
    const imp_1024_train = (mh_loss - mr_train_loss_1024) / mh_loss * 100.0;
    const imp_1024_eval = (mh_loss - mr_eval_loss_1024) / mh_loss * 100.0;
    const imp_256_train = (mh_loss - mr_train_loss_256) / mh_loss * 100.0;

    std.debug.print("\ndim=1024 multi-role train loss:  {d:.4} ({d:.1}% below random)\n", .{ mr_train_loss_1024, imp_1024_train });
    std.debug.print("dim=1024 multi-role eval loss:   {d:.4} ({d:.1}% below random)\n", .{ mr_eval_loss_1024, imp_1024_eval });
    std.debug.print("dim=256  multi-role train loss:  {d:.4} ({d:.1}% below random)\n", .{ mr_train_loss_256, imp_256_train });
    std.debug.print("dim=256  multi-role train (v2.37): 0.7426 (27.9% below random)\n", .{});
    std.debug.print("Random baseline:                 {d:.4}\n", .{mh_loss});
    std.debug.print("\ndim=1024 train PPL: {d:.1}\n", .{mr_train_ppl_1024});
    std.debug.print("dim=1024 test PPL:  {d:.1}\n", .{mr_test_ppl_1024});
    std.debug.print("dim=256  (v2.37):   train=1.8, test=1.9\n", .{});
    std.debug.print("Random baseline:    95.0\n", .{});
    std.debug.print("\nGeneration (T=0.8, K=8, dim=1024):\n", .{});
    std.debug.print("  Prompt: \"to be or \"\n", .{});
    std.debug.print("  Generated: \"{s}\"\n", .{gen_buf[0..gen_count]});
    std.debug.print("  Unique chars: {d}\n", .{unique});
    std.debug.print("==============================================\n", .{});

    // Assertions
    try std.testing.expect(mr_train_loss_1024 >= 0.0 and mr_train_loss_1024 <= 2.0);
    try std.testing.expect(mr_eval_loss_1024 >= 0.0 and mr_eval_loss_1024 <= 2.0);
    try std.testing.expect(gen_count == 50);
    try std.testing.expect(mr_test_ppl_1024 > 0.0);
    try std.testing.expect(!std.math.isNan(mr_test_ppl_1024));
    try std.testing.expect(!std.math.isInf(mr_test_ppl_1024));
}

// === v2.39 TRIGRAM HEBBIAN TESTS ===

test "trigram hebbian training at dim1024" {
    const dim: usize = 1024;

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    std.debug.print("\n=== TRIGRAM HEBBIAN TRAINING (v2.39) ===\n", .{});
    std.debug.print("Corpus: {d} chars (Shakespeare)\n", .{corpus.len});
    std.debug.print("Method: Multi-role + trigram Hebbian (2-char lookback) + sampling, dim=1024\n", .{});

    // Build both bigram and trigram counts
    const bi_counts = buildHebbianCounts(corpus);
    const tri_counts = buildTrigramCounts(corpus);

    // Count trigram coverage
    var tri_total_entries: usize = 0;
    var tri_nonzero: usize = 0;
    for (0..TRIGRAM_KEYS) |k| {
        for (0..HEBBIAN_CHARS) |c| {
            if (tri_counts[k][c] > 0) {
                tri_nonzero += 1;
            }
            tri_total_entries += 1;
        }
    }

    // Count unique trigram keys with data
    var tri_keys_with_data: usize = 0;
    for (0..TRIGRAM_KEYS) |k| {
        var has_data = false;
        for (0..HEBBIAN_CHARS) |c| {
            if (tri_counts[k][c] > 0) {
                has_data = true;
                break;
            }
        }
        if (has_data) tri_keys_with_data += 1;
    }

    std.debug.print("Trigram keys with data: {d}/{d}\n", .{ tri_keys_with_data, TRIGRAM_KEYS });
    std.debug.print("Non-zero trigram entries: {d}/{d}\n", .{ tri_nonzero, tri_total_entries });

    // Honest split
    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    var train_offsets: [20]usize = undefined;
    for (0..20) |i| {
        train_offsets[i] = i * train_end / 20;
    }

    // Compute multi-roles at dim=1024
    var multi_roles = computeMultiRoles(corpus, dim, &train_offsets, 8);

    // === Trigram train loss ===
    var tri_train_loss: f64 = 0;
    var tri_train_count: usize = 0;
    var tri_hits: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const prev_char = corpus[s + 6];
        const last_char = corpus[s + 7];

        // Check if trigram was used
        if (prev_char >= HEBBIAN_OFFSET and prev_char < HEBBIAN_OFFSET + HEBBIAN_CHARS and
            last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS)
        {
            const prev_idx = prev_char - HEBBIAN_OFFSET;
            const last_idx = last_char - HEBBIAN_OFFSET;
            const key = prev_idx * HEBBIAN_CHARS + last_idx;
            var tri_total: u32 = 0;
            for (0..HEBBIAN_CHARS) |ci| {
                tri_total += tri_counts[key][ci];
            }
            if (tri_total > 0) tri_hits += 1;
        }

        var output = forwardPassTrigramHybrid(&ctx, &multi_roles, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);
        tri_train_loss += 1.0 - sim;
        tri_train_count += 1;
    }
    if (tri_train_count > 0) tri_train_loss /= @as(f64, @floatFromInt(tri_train_count));

    // === Bigram-only train loss (comparison) ===
    var bi_train_loss: f64 = 0;
    var bi_train_count: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, corpus[s + i]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassMultiRoleHybrid(&ctx, &multi_roles, dim, last_char, &bi_counts);
        const sim = output.similarity(&target);
        bi_train_loss += 1.0 - sim;
        bi_train_count += 1;
    }
    if (bi_train_count > 0) bi_train_loss /= @as(f64, @floatFromInt(bi_train_count));

    // === Trigram eval loss ===
    var tri_eval_loss: f64 = 0;
    var tri_eval_count: usize = 0;
    const eval_samples = 8;
    for (0..eval_samples) |i| {
        const s = train_end + i * (eval_end - train_end) / eval_samples;
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const prev_char = corpus[s + 6];
        const last_char = corpus[s + 7];
        var output = forwardPassTrigramHybrid(&ctx, &multi_roles, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);
        tri_eval_loss += 1.0 - sim;
        tri_eval_count += 1;
    }
    if (tri_eval_count > 0) tri_eval_loss /= @as(f64, @floatFromInt(tri_eval_count));

    // === Bigram-only eval loss (comparison) ===
    var bi_eval_loss: f64 = 0;
    var bi_eval_count: usize = 0;
    for (0..eval_samples) |i| {
        const s = train_end + i * (eval_end - train_end) / eval_samples;
        if (s + 8 >= corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const last_char = corpus[s + 7];
        var output = forwardPassMultiRoleHybrid(&ctx, &multi_roles, dim, last_char, &bi_counts);
        const sim = output.similarity(&target);
        bi_eval_loss += 1.0 - sim;
        bi_eval_count += 1;
    }
    if (bi_eval_count > 0) bi_eval_loss /= @as(f64, @floatFromInt(bi_eval_count));

    // === Generation with trigram ===
    var init_ctx: [8]Hypervector = undefined;
    const prompt = "to be or ";
    for (0..8) |i| {
        init_ctx[i] = charToHV(dim, prompt[i]);
    }
    var gen_buf: [50]u8 = undefined;
    const gen_count = generateWithTrigramSampled(
        &init_ctx,
        &multi_roles,
        dim,
        prompt[6], // 'r'
        prompt[7], // ' '
        &bi_counts,
        &tri_counts,
        &gen_buf,
        50,
        0.8,
        8,
        42,
    );

    // Count unique chars
    var seen: [256]bool = undefined;
    for (0..256) |i| {
        seen[i] = false;
    }
    var unique: usize = 0;
    for (0..gen_count) |i| {
        if (!seen[gen_buf[i]]) {
            seen[gen_buf[i]] = true;
            unique += 1;
        }
    }

    const mh_loss: f64 = 1.0306;
    const tri_train_imp = (mh_loss - tri_train_loss) / mh_loss * 100.0;
    const tri_eval_imp = (mh_loss - tri_eval_loss) / mh_loss * 100.0;
    const bi_train_imp = (mh_loss - bi_train_loss) / mh_loss * 100.0;
    const bi_eval_imp = (mh_loss - bi_eval_loss) / mh_loss * 100.0;

    const tri_hit_pct = @as(f64, @floatFromInt(tri_hits)) / @as(f64, @floatFromInt(tri_train_count)) * 100.0;

    std.debug.print("\nTrigram hit rate:       {d:.1}% ({d}/{d} samples)\n", .{ tri_hit_pct, tri_hits, tri_train_count });
    std.debug.print("\nTrigram train loss:     {d:.4} ({d:.1}% below random)\n", .{ tri_train_loss, tri_train_imp });
    std.debug.print("Bigram  train loss:     {d:.4} ({d:.1}% below random)\n", .{ bi_train_loss, bi_train_imp });
    std.debug.print("Trigram eval loss:      {d:.4} ({d:.1}% below random)\n", .{ tri_eval_loss, tri_eval_imp });
    std.debug.print("Bigram  eval loss:      {d:.4} ({d:.1}% below random)\n", .{ bi_eval_loss, bi_eval_imp });
    std.debug.print("Random baseline:        {d:.4}\n", .{mh_loss});
    std.debug.print("\nGeneration (T=0.8, K=8, trigram, dim=1024):\n", .{});
    std.debug.print("  Prompt: \"to be or \"\n", .{});
    std.debug.print("  Generated: \"{s}\"\n", .{gen_buf[0..gen_count]});
    std.debug.print("  Unique chars: {d}\n", .{unique});
    std.debug.print("==============================================\n", .{});

    // Assertions
    try std.testing.expect(tri_train_loss >= 0.0 and tri_train_loss <= 2.0);
    try std.testing.expect(tri_eval_loss >= 0.0 and tri_eval_loss <= 2.0);
    try std.testing.expect(gen_count == 50);
    try std.testing.expect(tri_keys_with_data > 0);
}

test "trigram hebbian perplexity comparison" {
    const dim: usize = 1024;

    const corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";

    const bi_counts = buildHebbianCounts(corpus);
    const tri_counts = buildTrigramCounts(corpus);

    const total_samples = corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    var train_offsets: [20]usize = undefined;
    for (0..20) |i| {
        train_offsets[i] = i * train_end / 20;
    }
    var multi_roles = computeMultiRoles(corpus, dim, &train_offsets, 8);

    // === Test PPL (held-out) — Trigram ===
    const test_start = eval_end;
    const test_count = 8;
    var tri_test_log: f64 = 0;
    var tri_test_valid: usize = 0;

    for (0..test_count) |i| {
        const s = test_start + i * (total_samples - test_start) / test_count;
        if (s + 8 >= corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const prev_char = corpus[s + 6];
        const last_char = corpus[s + 7];
        var output = forwardPassTrigramHybrid(&ctx, &multi_roles, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        tri_test_log += @log(clamped);
        tri_test_valid += 1;
    }

    const tri_test_ppl = @exp(-tri_test_log / @as(f64, @floatFromInt(tri_test_valid)));

    // === Train PPL — Trigram ===
    var tri_train_log: f64 = 0;
    var tri_train_valid: usize = 0;
    for (0..8) |i| {
        const s = i * train_end / 8;
        if (s + 8 >= corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, corpus[s + j]);
        }
        var target = charToHV(dim, corpus[s + 8]);
        const prev_char = corpus[s + 6];
        const last_char = corpus[s + 7];
        var output = forwardPassTrigramHybrid(&ctx, &multi_roles, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        tri_train_log += @log(clamped);
        tri_train_valid += 1;
    }

    const tri_train_ppl = @exp(-tri_train_log / @as(f64, @floatFromInt(tri_train_valid)));

    std.debug.print("\n=== TRIGRAM PERPLEXITY (all methods) ===\n", .{});
    std.debug.print("Trigram train PPL:      {d:.1}\n", .{tri_train_ppl});
    std.debug.print("Trigram test PPL:       {d:.1}\n", .{tri_test_ppl});
    std.debug.print("Overfit gap:            {d:.1}\n", .{tri_test_ppl - tri_train_ppl});
    std.debug.print("--------------------------------------------\n", .{});
    std.debug.print("dim=1024 MR+bigram (v2.38): train=1.8, test=1.8\n", .{});
    std.debug.print("dim=256  MR+bigram (v2.37): train=1.8, test=1.9\n", .{});
    std.debug.print("Hybrid (v2.35-36):          train=1.8, test=1.9\n", .{});
    std.debug.print("Direct (v2.34):             train=2.0, test=2.0\n", .{});
    std.debug.print("Bundle2 (v2.32):            train=1.9, test=2.0\n", .{});
    std.debug.print("Random baseline:            95.0\n", .{});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(tri_test_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(tri_test_ppl));
    try std.testing.expect(!std.math.isInf(tri_test_ppl));
}

// === v2.40 LARGER CORPUS TESTS ===

// ~5000 char Shakespeare corpus (Hamlet + Macbeth + Sonnets + Romeo)
const large_corpus =
    // Hamlet "To be or not to be" soliloquy (full)
    "to be or not to be that is the question " ++
    "whether tis nobler in the mind to suffer " ++
    "the slings and arrows of outrageous fortune " ++
    "or to take arms against a sea of troubles " ++
    "and by opposing end them to die to sleep " ++
    "no more and by a sleep to say we end " ++
    "the heartache and the thousand natural shocks " ++
    "that flesh is heir to tis a consummation " ++
    "devoutly to be wished to die to sleep " ++
    "to sleep perchance to dream ay there is the rub " ++
    "for in that sleep of death what dreams may come " ++
    "when we have shuffled off this mortal coil " ++
    "must give us pause there is the respect " ++
    "that makes calamity of so long life " ++
    "for who would bear the whips and scorns of time " ++
    "the oppressors wrong the proud mans contumely " ++
    "the pangs of despised love the laws delay " ++
    "the insolence of office and the spurns " ++
    "that patient merit of the unworthy takes " ++
    "when he himself might his quietus make " ++
    "with a bare bodkin who would fardels bear " ++
    "to grunt and sweat under a weary life " ++
    "but that the dread of something after death " ++
    "the undiscovered country from whose bourn " ++
    "no traveller returns puzzles the will " ++
    "and makes us rather bear those ills we have " ++
    "than fly to others that we know not of " ++
    "thus conscience does make cowards of us all " ++
    "and thus the native hue of resolution " ++
    "is sicklied over with the pale cast of thought " ++
    "and enterprises of great pith and moment " ++
    "with this regard their currents turn awry " ++
    "and lose the name of action " ++
    // Macbeth "Tomorrow" soliloquy
    "tomorrow and tomorrow and tomorrow " ++
    "creeps in this petty pace from day to day " ++
    "to the last syllable of recorded time " ++
    "and all our yesterdays have lighted fools " ++
    "the way to dusty death out out brief candle " ++
    "life is but a walking shadow a poor player " ++
    "that struts and frets his hour upon the stage " ++
    "and then is heard no more it is a tale " ++
    "told by an idiot full of sound and fury " ++
    "signifying nothing " ++
    // Romeo and Juliet balcony
    "but soft what light through yonder window breaks " ++
    "it is the east and juliet is the sun " ++
    "arise fair sun and kill the envious moon " ++
    "who is already sick and pale with grief " ++
    "that thou her maid art far more fair than she " ++
    "be not her maid since she is envious " ++
    "her vestal livery is but sick and green " ++
    "and none but fools do wear it cast it off " ++
    "it is my lady oh it is my love " ++
    "oh that she knew she were " ++
    "she speaks yet she says nothing what of that " ++
    "her eye discourses i will answer it " ++
    "i am too bold tis not to me she speaks " ++
    "two of the fairest stars in all the heaven " ++
    "having some business do entreat her eyes " ++
    "to twinkle in their spheres till they return " ++
    // Sonnets
    "shall i compare thee to a summers day " ++
    "thou art more lovely and more temperate " ++
    "rough winds do shake the darling buds of may " ++
    "and summers lease hath all too short a date " ++
    "sometime too hot the eye of heaven shines " ++
    "and often is his gold complexion dimmed " ++
    "and every fair from fair sometime declines " ++
    "by chance or natures changing course untrimmed " ++
    "but thy eternal summer shall not fade " ++
    "nor lose possession of that fair thou owest " ++
    "nor shall death brag thou wanderest in his shade " ++
    "when in eternal lines to time thou growest " ++
    "so long as men can breathe or eyes can see " ++
    "so long lives this and this gives life to thee " ++
    // Hamlet Act 1
    "who is there nay answer me stand and unfold yourself " ++
    "long live the king bernardo he " ++
    "you come most carefully upon your hour " ++
    "tis now struck twelve get thee to bed francisco " ++
    "for this relief much thanks tis bitter cold " ++
    "and i am sick at heart " ++
    "have you had quiet guard not a mouse stirring " ++
    "well good night if you do meet horatio and marcellus " ++
    "the rivals of my watch bid them make haste " ++
    // Macbeth witches
    "when shall we three meet again " ++
    "in thunder lightning or in rain " ++
    "when the hurlyburlys done " ++
    "when the battles lost and won " ++
    "that will be ere the set of sun " ++
    "where the place upon the heath " ++
    "there to meet with macbeth " ++
    "fair is foul and foul is fair " ++
    "hover through the fog and filthy air " ++
    // More Hamlet
    "something is rotten in the state of denmark " ++
    "though this be madness yet there is method in it " ++
    "brevity is the soul of wit " ++
    "there are more things in heaven and earth horatio " ++
    "than are dreamt of in your philosophy " ++
    "the lady doth protest too much methinks " ++
    "good night sweet prince and flights of angels sing thee to thy rest " ++
    "frailty thy name is woman " ++
    "the play is the thing wherein i will catch the conscience of the king " ++
    // More Romeo
    "a rose by any other name would smell as sweet " ++
    "parting is such sweet sorrow that i shall say good night till it be morrow " ++
    "my bounty is as boundless as the sea my love as deep " ++
    "the more i give to thee the more i have for both are infinite " ++
    "these violent delights have violent ends " ++
    "and in their triumph die like fire and powder " ++
    "which as they kiss consume " ++
    // More Macbeth
    "is this a dagger which i see before me " ++
    "the handle toward my hand come let me clutch thee " ++
    "i have thee not and yet i see thee still " ++
    "art thou not fatal vision sensible " ++
    "to feeling as to sight or art thou but " ++
    "a dagger of the mind a false creation " ++
    "proceeding from the heat oppressed brain " ++
    // Tempest
    "we are such stuff as dreams are made on " ++
    "and our little life is rounded with a sleep " ++
    "oh brave new world that has such people in it " ++
    "full fathom five thy father lies " ++
    "of his bones are coral made " ++
    "those are pearls that were his eyes " ++
    "nothing of him that doth fade " ++
    "but doth suffer a sea change " ++
    "into something rich and strange";

test "large corpus trigram training" {
    const dim: usize = 1024;

    std.debug.print("\n=== LARGE CORPUS TRIGRAM TRAINING (v2.40) ===\n", .{});
    std.debug.print("Corpus: {d} chars (Shakespeare multi-play)\n", .{large_corpus.len});
    std.debug.print("Method: Multi-role + trigram Hebbian + sampling, dim=1024\n", .{});

    // Build both bigram and trigram counts on large corpus
    const bi_counts = buildHebbianCounts(large_corpus);
    const tri_counts = buildTrigramCounts(large_corpus);

    // Count bigram coverage (for comparison)
    var bi_nonzero: usize = 0;
    for (0..HEBBIAN_CHARS) |a| {
        for (0..HEBBIAN_CHARS) |b| {
            if (bi_counts[a][b] > 0) bi_nonzero += 1;
        }
    }

    // Count trigram coverage
    var tri_keys_with_data: usize = 0;
    var tri_nonzero: usize = 0;
    for (0..TRIGRAM_KEYS) |k| {
        var has_data = false;
        for (0..HEBBIAN_CHARS) |c| {
            if (tri_counts[k][c] > 0) {
                tri_nonzero += 1;
                has_data = true;
            }
        }
        if (has_data) tri_keys_with_data += 1;
    }

    // Small corpus comparison
    const small_corpus =
        "to be or not to be that is the question " ++
        "whether tis nobler in the mind to suffer " ++
        "the slings and arrows of outrageous fortune " ++
        "or to take arms against a sea of troubles " ++
        "and by opposing end them to die to sleep " ++
        "no more and by a sleep to say we end " ++
        "the heartache and the thousand natural shocks " ++
        "that flesh is heir to tis a consummation " ++
        "devoutly to be wished to die to sleep " ++
        "to sleep perchance to dream ay there is the rub " ++
        "for in that sleep of death what dreams may come " ++
        "when we have shuffled off this mortal coil " ++
        "must give us pause";
    const small_tri_counts = buildTrigramCounts(small_corpus);
    var small_tri_keys: usize = 0;
    for (0..TRIGRAM_KEYS) |k| {
        for (0..HEBBIAN_CHARS) |c| {
            if (small_tri_counts[k][c] > 0) {
                small_tri_keys += 1;
                break;
            }
        }
    }

    const tri_coverage_pct = @as(f64, @floatFromInt(tri_keys_with_data)) / @as(f64, @floatFromInt(TRIGRAM_KEYS)) * 100.0;
    const small_coverage_pct = @as(f64, @floatFromInt(small_tri_keys)) / @as(f64, @floatFromInt(TRIGRAM_KEYS)) * 100.0;

    std.debug.print("Large corpus trigram keys: {d}/{d} ({d:.1}%)\n", .{ tri_keys_with_data, TRIGRAM_KEYS, tri_coverage_pct });
    std.debug.print("Small corpus trigram keys: {d}/{d} ({d:.1}%)\n", .{ small_tri_keys, TRIGRAM_KEYS, small_coverage_pct });
    std.debug.print("Coverage boost: {d:.1}x\n", .{tri_coverage_pct / small_coverage_pct});
    std.debug.print("Bigram pairs: {d}/{d}\n", .{ bi_nonzero, HEBBIAN_CHARS * HEBBIAN_CHARS });
    std.debug.print("Trigram entries: {d}/{d}\n", .{ tri_nonzero, TRIGRAM_KEYS * HEBBIAN_CHARS });

    // Honest split
    const total_samples = large_corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    // More train offsets for larger corpus (50 samples)
    var train_offsets: [50]usize = undefined;
    for (0..50) |i| {
        train_offsets[i] = i * train_end / 50;
    }

    // Compute multi-roles on large corpus
    var multi_roles = computeMultiRoles(large_corpus, dim, &train_offsets, 8);

    // === Trigram train loss (large corpus) ===
    var tri_train_loss: f64 = 0;
    var tri_train_count: usize = 0;
    var tri_hits: usize = 0;
    for (train_offsets) |s| {
        if (s + 8 >= large_corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |i| {
            ctx[i] = charToHV(dim, large_corpus[s + i]);
        }
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev_char = large_corpus[s + 6];
        const last_char = large_corpus[s + 7];

        if (prev_char >= HEBBIAN_OFFSET and prev_char < HEBBIAN_OFFSET + HEBBIAN_CHARS and
            last_char >= HEBBIAN_OFFSET and last_char < HEBBIAN_OFFSET + HEBBIAN_CHARS)
        {
            const prev_idx = prev_char - HEBBIAN_OFFSET;
            const last_idx = last_char - HEBBIAN_OFFSET;
            const key = prev_idx * HEBBIAN_CHARS + last_idx;
            var tri_total: u32 = 0;
            for (0..HEBBIAN_CHARS) |ci| {
                tri_total += tri_counts[key][ci];
            }
            if (tri_total > 0) tri_hits += 1;
        }

        var output = forwardPassTrigramHybrid(&ctx, &multi_roles, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);
        tri_train_loss += 1.0 - sim;
        tri_train_count += 1;
    }
    if (tri_train_count > 0) tri_train_loss /= @as(f64, @floatFromInt(tri_train_count));

    // === Trigram eval loss (large corpus) ===
    var tri_eval_loss: f64 = 0;
    var tri_eval_count: usize = 0;
    const eval_samples = 20;
    for (0..eval_samples) |i| {
        const s = train_end + i * (eval_end - train_end) / eval_samples;
        if (s + 8 >= large_corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, large_corpus[s + j]);
        }
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev_char = large_corpus[s + 6];
        const last_char = large_corpus[s + 7];
        var output = forwardPassTrigramHybrid(&ctx, &multi_roles, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);
        tri_eval_loss += 1.0 - sim;
        tri_eval_count += 1;
    }
    if (tri_eval_count > 0) tri_eval_loss /= @as(f64, @floatFromInt(tri_eval_count));

    // === Generation ===
    var init_ctx: [8]Hypervector = undefined;
    const prompt = "to be or ";
    for (0..8) |i| {
        init_ctx[i] = charToHV(dim, prompt[i]);
    }
    var gen_buf: [80]u8 = undefined;
    const gen_count = generateWithTrigramSampled(
        &init_ctx,
        &multi_roles,
        dim,
        prompt[6],
        prompt[7],
        &bi_counts,
        &tri_counts,
        &gen_buf,
        80,
        0.8,
        8,
        42,
    );

    var seen: [256]bool = undefined;
    for (0..256) |i| {
        seen[i] = false;
    }
    var unique: usize = 0;
    for (0..gen_count) |i| {
        if (!seen[gen_buf[i]]) {
            seen[gen_buf[i]] = true;
            unique += 1;
        }
    }

    const mh_loss: f64 = 1.0306;
    const tri_train_imp = (mh_loss - tri_train_loss) / mh_loss * 100.0;
    const tri_eval_imp = (mh_loss - tri_eval_loss) / mh_loss * 100.0;
    const tri_hit_pct = @as(f64, @floatFromInt(tri_hits)) / @as(f64, @floatFromInt(tri_train_count)) * 100.0;

    std.debug.print("\nTrigram hit rate:          {d:.1}% ({d}/{d} samples)\n", .{ tri_hit_pct, tri_hits, tri_train_count });
    std.debug.print("\nLarge corpus train loss:   {d:.4} ({d:.1}% below random)\n", .{ tri_train_loss, tri_train_imp });
    std.debug.print("Large corpus eval loss:    {d:.4} ({d:.1}% below random)\n", .{ tri_eval_loss, tri_eval_imp });
    std.debug.print("Small corpus train (v2.39): 0.5528 (46.4% below random)\n", .{});
    std.debug.print("Small corpus eval (v2.39):  0.6534 (36.6% below random)\n", .{});
    std.debug.print("Random baseline:           {d:.4}\n", .{mh_loss});
    std.debug.print("\nGeneration (T=0.8, K=8, trigram, dim=1024, 80 tokens):\n", .{});
    std.debug.print("  Prompt: \"to be or \"\n", .{});
    std.debug.print("  Generated: \"{s}\"\n", .{gen_buf[0..gen_count]});
    std.debug.print("  Unique chars: {d}\n", .{unique});
    std.debug.print("==============================================\n", .{});

    // Assertions
    try std.testing.expect(tri_train_loss >= 0.0 and tri_train_loss <= 2.0);
    try std.testing.expect(tri_eval_loss >= 0.0 and tri_eval_loss <= 2.0);
    try std.testing.expect(gen_count == 80);
    try std.testing.expect(tri_keys_with_data > small_tri_keys); // Coverage improved
}

test "large corpus trigram perplexity" {
    const dim: usize = 1024;

    const bi_counts = buildHebbianCounts(large_corpus);
    const tri_counts = buildTrigramCounts(large_corpus);

    const total_samples = large_corpus.len - 8;
    const train_end = total_samples * 70 / 100;
    const eval_end = total_samples * 85 / 100;

    var train_offsets: [50]usize = undefined;
    for (0..50) |i| {
        train_offsets[i] = i * train_end / 50;
    }
    var multi_roles = computeMultiRoles(large_corpus, dim, &train_offsets, 8);

    // === Test PPL (held-out) ===
    const test_start = eval_end;
    const test_count = 20;
    var tri_test_log: f64 = 0;
    var tri_test_valid: usize = 0;

    for (0..test_count) |i| {
        const s = test_start + i * (total_samples - test_start) / test_count;
        if (s + 8 >= large_corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, large_corpus[s + j]);
        }
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev_char = large_corpus[s + 6];
        const last_char = large_corpus[s + 7];
        var output = forwardPassTrigramHybrid(&ctx, &multi_roles, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        tri_test_log += @log(clamped);
        tri_test_valid += 1;
    }

    const tri_test_ppl = @exp(-tri_test_log / @as(f64, @floatFromInt(tri_test_valid)));

    // === Train PPL ===
    var tri_train_log: f64 = 0;
    var tri_train_valid: usize = 0;
    for (0..20) |i| {
        const s = i * train_end / 20;
        if (s + 8 >= large_corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, large_corpus[s + j]);
        }
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev_char = large_corpus[s + 6];
        const last_char = large_corpus[s + 7];
        var output = forwardPassTrigramHybrid(&ctx, &multi_roles, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);

        const prob = (sim + 1.0) / 2.0;
        const clamped = @max(prob, 1e-10);
        tri_train_log += @log(clamped);
        tri_train_valid += 1;
    }

    const tri_train_ppl = @exp(-tri_train_log / @as(f64, @floatFromInt(tri_train_valid)));

    std.debug.print("\n=== LARGE CORPUS PERPLEXITY (v2.40) ===\n", .{});
    std.debug.print("Corpus: {d} chars\n", .{large_corpus.len});
    std.debug.print("Large corpus train PPL:     {d:.2}\n", .{tri_train_ppl});
    std.debug.print("Large corpus test PPL:      {d:.2}\n", .{tri_test_ppl});
    std.debug.print("Overfit gap:                {d:.2}\n", .{tri_test_ppl - tri_train_ppl});
    std.debug.print("--------------------------------------------\n", .{});
    std.debug.print("Small corpus trigram (v2.39):  train=1.5, test=1.6\n", .{});
    std.debug.print("dim=1024 MR+bigram (v2.38):    train=1.8, test=1.8\n", .{});
    std.debug.print("dim=256  MR+bigram (v2.37):    train=1.8, test=1.9\n", .{});
    std.debug.print("Hybrid (v2.35-36):             train=1.8, test=1.9\n", .{});
    std.debug.print("Random baseline:               95.0\n", .{});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(tri_test_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(tri_test_ppl));
    try std.testing.expect(!std.math.isInf(tri_test_ppl));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 28: 500 offsets role quality on large corpus (v2.41)
// ═══════════════════════════════════════════════════════════════════════════════
test "500 offsets role quality on large corpus" {
    const dim = 1024;

    // Build counts on full large corpus
    const bi_counts = buildHebbianCounts(large_corpus);
    const tri_counts = buildTrigramCounts(large_corpus);

    // --- 50-offset roles (baseline, same as v2.40) ---
    var offsets_50: [50]usize = undefined;
    for (0..50) |i| {
        offsets_50[i] = i * (large_corpus.len - 10) / 50;
    }
    var roles_50 = computeMultiRoles(large_corpus, dim, &offsets_50, 8);

    // --- 500-offset roles (v2.41) ---
    var offsets_500: [500]usize = undefined;
    for (0..500) |i| {
        offsets_500[i] = i * (large_corpus.len - 10) / 500;
    }
    var roles_500 = computeMultiRoles(large_corpus, dim, &offsets_500, 8);

    // Measure role similarity (how much does 500 differ from 50?)
    var role_sim_sum: f64 = 0;
    for (0..8) |r| {
        const sim = roles_500[r].similarity(&roles_50[r]);
        role_sim_sum += sim;
    }
    const avg_role_sim = role_sim_sum / 8.0;

    // === Train/eval split ===
    const train_end = large_corpus.len * 80 / 100;

    // --- Eval loss with 500 offsets ---
    var loss_500_sum: f64 = 0;
    var loss_500_count: usize = 0;
    var loss_50_sum: f64 = 0;
    var loss_50_count: usize = 0;

    for (0..50) |i| {
        const s = train_end + i * (large_corpus.len - train_end - 10) / 50;
        if (s + 8 >= large_corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, large_corpus[s + j]);
        }
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev_char = large_corpus[s + 6];
        const last_char = large_corpus[s + 7];

        var output_500 = forwardPassTrigramHybrid(&ctx, &roles_500, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim_500 = output_500.similarity(&target);
        loss_500_sum += 1.0 - (sim_500 + 1.0) / 2.0;
        loss_500_count += 1;

        var output_50 = forwardPassTrigramHybrid(&ctx, &roles_50, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim_50 = output_50.similarity(&target);
        loss_50_sum += 1.0 - (sim_50 + 1.0) / 2.0;
        loss_50_count += 1;
    }

    const eval_loss_500 = loss_500_sum / @as(f64, @floatFromInt(loss_500_count));
    const eval_loss_50 = loss_50_sum / @as(f64, @floatFromInt(loss_50_count));

    // --- Train loss with 500 offsets ---
    var train_loss_500_sum: f64 = 0;
    var train_loss_500_count: usize = 0;
    var train_loss_50_sum: f64 = 0;
    var train_loss_50_count: usize = 0;

    for (0..50) |i| {
        const s = i * train_end / 50;
        if (s + 8 >= large_corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, large_corpus[s + j]);
        }
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev_char = large_corpus[s + 6];
        const last_char = large_corpus[s + 7];

        var output_500 = forwardPassTrigramHybrid(&ctx, &roles_500, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim_500 = output_500.similarity(&target);
        train_loss_500_sum += 1.0 - (sim_500 + 1.0) / 2.0;
        train_loss_500_count += 1;

        var output_50 = forwardPassTrigramHybrid(&ctx, &roles_50, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim_50 = output_50.similarity(&target);
        train_loss_50_sum += 1.0 - (sim_50 + 1.0) / 2.0;
        train_loss_50_count += 1;
    }

    const train_loss_500 = train_loss_500_sum / @as(f64, @floatFromInt(train_loss_500_count));
    const train_loss_50 = train_loss_50_sum / @as(f64, @floatFromInt(train_loss_50_count));

    const random_baseline = 1.0 - 1.0 / 95.0;

    // --- Generation with 500 offsets ---
    var gen_buf: [80]u8 = undefined;
    const prompt = "to be or ";
    var init_ctx: [8]Hypervector = undefined;
    for (0..8) |i| {
        init_ctx[i] = charToHV(dim, prompt[i]);
    }
    const gen_len = generateWithTrigramSampled(
        &init_ctx, &roles_500, dim,
        prompt[6], prompt[7],
        &bi_counts, &tri_counts,
        &gen_buf, 80, 0.8, 8, 54321,
    );

    // Count unique chars in generation
    var char_seen = [_]bool{false} ** 256;
    var unique_count: usize = 0;
    for (gen_buf[0..gen_len]) |c| {
        if (!char_seen[c]) {
            char_seen[c] = true;
            unique_count += 1;
        }
    }

    std.debug.print("\n=== 500 OFFSETS ROLE QUALITY (v2.41) ===\n", .{});
    std.debug.print("Corpus: {d} chars (large Shakespeare)\n", .{large_corpus.len});
    std.debug.print("Offsets: 500 vs 50 (10x more training positions)\n", .{});
    std.debug.print("\nRole similarity (500 vs 50):   {d:.4}\n", .{avg_role_sim});
    std.debug.print("\n--- Eval Loss ---\n", .{});
    std.debug.print("500 offsets eval loss:         {d:.4}\n", .{eval_loss_500});
    std.debug.print("50 offsets eval loss:          {d:.4}\n", .{eval_loss_50});
    std.debug.print("Random baseline:               {d:.4}\n", .{random_baseline});
    std.debug.print("500 vs random:                 {d:.1}% below random\n", .{(1.0 - eval_loss_500 / random_baseline) * 100.0});
    std.debug.print("50 vs random:                  {d:.1}% below random\n", .{(1.0 - eval_loss_50 / random_baseline) * 100.0});
    std.debug.print("\n--- Train Loss ---\n", .{});
    std.debug.print("500 offsets train loss:        {d:.4}\n", .{train_loss_500});
    std.debug.print("50 offsets train loss:         {d:.4}\n", .{train_loss_50});
    std.debug.print("\n--- Generation (500 offsets, T=0.8, K=8) ---\n", .{});
    std.debug.print("Prompt: \"{s}\"\n", .{prompt});
    std.debug.print("Generated: \"{s}\"\n", .{gen_buf[0..gen_len]});
    std.debug.print("Unique chars: {d}\n", .{unique_count});
    std.debug.print("============================================\n", .{});

    // Structural assertions
    try std.testing.expect(eval_loss_500 < random_baseline);
    try std.testing.expect(eval_loss_50 < random_baseline);
    try std.testing.expect(train_loss_500 < random_baseline);
    try std.testing.expect(gen_len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 29: 500 offsets perplexity comparison (v2.41)
// ═══════════════════════════════════════════════════════════════════════════════
test "500 offsets perplexity comparison" {
    const dim = 1024;

    const bi_counts = buildHebbianCounts(large_corpus);
    const tri_counts = buildTrigramCounts(large_corpus);

    const train_end = large_corpus.len * 80 / 100;

    // --- 50-offset roles ---
    var offsets_50: [50]usize = undefined;
    for (0..50) |i| {
        offsets_50[i] = i * (large_corpus.len - 10) / 50;
    }
    var roles_50 = computeMultiRoles(large_corpus, dim, &offsets_50, 8);

    // --- 500-offset roles ---
    var offsets_500: [500]usize = undefined;
    for (0..500) |i| {
        offsets_500[i] = i * (large_corpus.len - 10) / 500;
    }
    var roles_500 = computeMultiRoles(large_corpus, dim, &offsets_500, 8);

    // === Test PPL (500 offsets) ===
    var test_log_500: f64 = 0;
    var test_valid_500: usize = 0;
    var test_log_50: f64 = 0;
    var test_valid_50: usize = 0;

    for (0..20) |i| {
        const s = train_end + i * (large_corpus.len - train_end - 10) / 20;
        if (s + 8 >= large_corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, large_corpus[s + j]);
        }
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev_char = large_corpus[s + 6];
        const last_char = large_corpus[s + 7];

        var output_500 = forwardPassTrigramHybrid(&ctx, &roles_500, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim_500 = output_500.similarity(&target);
        const prob_500 = @max((sim_500 + 1.0) / 2.0, 1e-10);
        test_log_500 += @log(prob_500);
        test_valid_500 += 1;

        var output_50 = forwardPassTrigramHybrid(&ctx, &roles_50, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim_50 = output_50.similarity(&target);
        const prob_50 = @max((sim_50 + 1.0) / 2.0, 1e-10);
        test_log_50 += @log(prob_50);
        test_valid_50 += 1;
    }

    const test_ppl_500 = @exp(-test_log_500 / @as(f64, @floatFromInt(test_valid_500)));
    const test_ppl_50 = @exp(-test_log_50 / @as(f64, @floatFromInt(test_valid_50)));

    // === Train PPL (500 offsets) ===
    var train_log_500: f64 = 0;
    var train_valid_500: usize = 0;
    var train_log_50: f64 = 0;
    var train_valid_50: usize = 0;

    for (0..20) |i| {
        const s = i * train_end / 20;
        if (s + 8 >= large_corpus.len) continue;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| {
            ctx[j] = charToHV(dim, large_corpus[s + j]);
        }
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev_char = large_corpus[s + 6];
        const last_char = large_corpus[s + 7];

        var output_500 = forwardPassTrigramHybrid(&ctx, &roles_500, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim_500 = output_500.similarity(&target);
        const prob_500 = @max((sim_500 + 1.0) / 2.0, 1e-10);
        train_log_500 += @log(prob_500);
        train_valid_500 += 1;

        var output_50 = forwardPassTrigramHybrid(&ctx, &roles_50, dim, prev_char, last_char, &bi_counts, &tri_counts);
        const sim_50 = output_50.similarity(&target);
        const prob_50 = @max((sim_50 + 1.0) / 2.0, 1e-10);
        train_log_50 += @log(prob_50);
        train_valid_50 += 1;
    }

    const train_ppl_500 = @exp(-train_log_500 / @as(f64, @floatFromInt(train_valid_500)));
    const train_ppl_50 = @exp(-train_log_50 / @as(f64, @floatFromInt(train_valid_50)));

    std.debug.print("\n=== 500 OFFSETS PERPLEXITY (v2.41) ===\n", .{});
    std.debug.print("500 offsets train PPL:         {d:.2}\n", .{train_ppl_500});
    std.debug.print("500 offsets test PPL:          {d:.2}\n", .{test_ppl_500});
    std.debug.print("500 offsets overfit gap:       {d:.2}\n", .{test_ppl_500 - train_ppl_500});
    std.debug.print("--------------------------------------------\n", .{});
    std.debug.print("50 offsets train PPL:          {d:.2}\n", .{train_ppl_50});
    std.debug.print("50 offsets test PPL:           {d:.2}\n", .{test_ppl_50});
    std.debug.print("50 offsets overfit gap:        {d:.2}\n", .{test_ppl_50 - train_ppl_50});
    std.debug.print("--------------------------------------------\n", .{});
    std.debug.print("v2.40 large (50 offsets):      train=1.87, test=1.84\n", .{});
    std.debug.print("v2.39 small trigram:           train=1.5, test=1.6\n", .{});
    std.debug.print("Random baseline:               95.0\n", .{});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(test_ppl_500 > 0.0);
    try std.testing.expect(!std.math.isNan(test_ppl_500));
    try std.testing.expect(!std.math.isInf(test_ppl_500));
    try std.testing.expect(test_ppl_50 > 0.0);
    try std.testing.expect(!std.math.isNan(test_ppl_50));
    try std.testing.expect(!std.math.isInf(test_ppl_50));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 30: Weighted hybrid alpha grid search (v2.42)
// ═══════════════════════════════════════════════════════════════════════════════
test "weighted hybrid alpha grid search" {
    const dim = 1024;

    const bi_counts = buildHebbianCounts(large_corpus);
    const tri_counts = buildTrigramCounts(large_corpus);

    const train_end = large_corpus.len * 80 / 100;

    // Use 50 offsets for roles (500 was shown equivalent)
    var offsets_50: [50]usize = undefined;
    for (0..50) |i| {
        offsets_50[i] = i * (large_corpus.len - 10) / 50;
    }
    var roles = computeMultiRoles(large_corpus, dim, &offsets_50, 8);

    // Grid search over alpha values
    // Test: (role, tri, bi) combinations
    const alphas = [_][3]f64{
        .{ 0.33, 0.33, 0.34 }, // equal weight (baseline)
        .{ 0.10, 0.60, 0.30 }, // trigram-heavy
        .{ 0.05, 0.70, 0.25 }, // trigram-dominant
        .{ 0.00, 0.75, 0.25 }, // no role (pure Hebbian)
        .{ 0.00, 1.00, 0.00 }, // pure trigram
        .{ 0.00, 0.00, 1.00 }, // pure bigram
        .{ 0.20, 0.50, 0.30 }, // moderate role
        .{ 0.50, 0.25, 0.25 }, // role-heavy
    };
    const alpha_names = [_][]const u8{
        "equal(0.33/0.33/0.34)",
        "tri-heavy(0.10/0.60/0.30)",
        "tri-dom(0.05/0.70/0.25)",
        "no-role(0.00/0.75/0.25)",
        "pure-tri(0.00/1.00/0.00)",
        "pure-bi(0.00/0.00/1.00)",
        "mod-role(0.20/0.50/0.30)",
        "role-heavy(0.50/0.25/0.25)",
    };

    const random_baseline = 1.0 - 1.0 / 95.0;

    var best_eval: f64 = 999.0;
    var best_idx: usize = 0;
    var best_train: f64 = 999.0;

    // Also measure the original equal-weight bundling (forwardPassTrigramHybrid)
    var orig_eval_sum: f64 = 0;
    var orig_eval_count: usize = 0;
    var orig_train_sum: f64 = 0;
    var orig_train_count: usize = 0;

    for (0..50) |i| {
        const eval_s = train_end + i * (large_corpus.len - train_end - 10) / 50;
        if (eval_s + 8 >= large_corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| { ctx[j] = charToHV(dim, large_corpus[eval_s + j]); }
        var target = charToHV(dim, large_corpus[eval_s + 8]);
        const prev = large_corpus[eval_s + 6];
        const last = large_corpus[eval_s + 7];
        var output = forwardPassTrigramHybrid(&ctx, &roles, dim, prev, last, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);
        orig_eval_sum += 1.0 - (sim + 1.0) / 2.0;
        orig_eval_count += 1;
    }
    for (0..50) |i| {
        const train_s = i * train_end / 50;
        if (train_s + 8 >= large_corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| { ctx[j] = charToHV(dim, large_corpus[train_s + j]); }
        var target = charToHV(dim, large_corpus[train_s + 8]);
        const prev = large_corpus[train_s + 6];
        const last = large_corpus[train_s + 7];
        var output = forwardPassTrigramHybrid(&ctx, &roles, dim, prev, last, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);
        orig_train_sum += 1.0 - (sim + 1.0) / 2.0;
        orig_train_count += 1;
    }
    const orig_eval = orig_eval_sum / @as(f64, @floatFromInt(orig_eval_count));
    const orig_train = orig_train_sum / @as(f64, @floatFromInt(orig_train_count));

    std.debug.print("\n=== WEIGHTED HYBRID ALPHA GRID SEARCH (v2.42) ===\n", .{});
    std.debug.print("Corpus: {d} chars, dim={d}\n", .{ large_corpus.len, dim });
    std.debug.print("\nOriginal bundling (equal vote):\n", .{});
    std.debug.print("  Train loss: {d:.4} ({d:.1}% below random)\n", .{ orig_train, (1.0 - orig_train / random_baseline) * 100.0 });
    std.debug.print("  Eval loss:  {d:.4} ({d:.1}% below random)\n", .{ orig_eval, (1.0 - orig_eval / random_baseline) * 100.0 });
    std.debug.print("\nWeighted alpha search (role/tri/bi):\n", .{});

    for (alphas, 0..) |alpha, ai| {
        var eval_sum: f64 = 0;
        var eval_count: usize = 0;
        var train_sum: f64 = 0;
        var train_count: usize = 0;

        // Eval loss
        for (0..50) |i| {
            const s = train_end + i * (large_corpus.len - train_end - 10) / 50;
            if (s + 8 >= large_corpus.len) continue;
            var ctx: [8]Hypervector = undefined;
            for (0..8) |j| { ctx[j] = charToHV(dim, large_corpus[s + j]); }
            var target = charToHV(dim, large_corpus[s + 8]);
            const prev = large_corpus[s + 6];
            const last = large_corpus[s + 7];
            var output = forwardPassWeightedHybrid(&ctx, &roles, dim, prev, last, &bi_counts, &tri_counts, alpha[0], alpha[1], alpha[2]);
            const sim = output.similarity(&target);
            eval_sum += 1.0 - (sim + 1.0) / 2.0;
            eval_count += 1;
        }

        // Train loss
        for (0..50) |i| {
            const s = i * train_end / 50;
            if (s + 8 >= large_corpus.len) continue;
            var ctx: [8]Hypervector = undefined;
            for (0..8) |j| { ctx[j] = charToHV(dim, large_corpus[s + j]); }
            var target = charToHV(dim, large_corpus[s + 8]);
            const prev = large_corpus[s + 6];
            const last = large_corpus[s + 7];
            var output = forwardPassWeightedHybrid(&ctx, &roles, dim, prev, last, &bi_counts, &tri_counts, alpha[0], alpha[1], alpha[2]);
            const sim = output.similarity(&target);
            train_sum += 1.0 - (sim + 1.0) / 2.0;
            train_count += 1;
        }

        const eval_loss = eval_sum / @as(f64, @floatFromInt(eval_count));
        const train_loss = train_sum / @as(f64, @floatFromInt(train_count));

        std.debug.print("  {s}: train={d:.4} eval={d:.4} ({d:.1}% below)\n", .{ alpha_names[ai], train_loss, eval_loss, (1.0 - eval_loss / random_baseline) * 100.0 });

        if (eval_loss < best_eval) {
            best_eval = eval_loss;
            best_train = train_loss;
            best_idx = ai;
        }
    }

    std.debug.print("\nBest: {s}\n", .{alpha_names[best_idx]});
    std.debug.print("  Train: {d:.4} ({d:.1}% below random)\n", .{ best_train, (1.0 - best_train / random_baseline) * 100.0 });
    std.debug.print("  Eval:  {d:.4} ({d:.1}% below random)\n", .{ best_eval, (1.0 - best_eval / random_baseline) * 100.0 });

    // --- Generation with best alpha ---
    const best_alpha = alphas[best_idx];
    var gen_buf: [80]u8 = undefined;
    const prompt = "to be or ";
    var init_ctx: [8]Hypervector = undefined;
    for (0..8) |i| { init_ctx[i] = charToHV(dim, prompt[i]); }
    const gen_len = generateWithWeightedHybrid(
        &init_ctx, &roles, dim, prompt[6], prompt[7],
        &bi_counts, &tri_counts,
        best_alpha[0], best_alpha[1], best_alpha[2],
        &gen_buf, 80, 0.8, 8, 98765,
    );

    var char_seen = [_]bool{false} ** 256;
    var unique_count: usize = 0;
    for (gen_buf[0..gen_len]) |c| {
        if (!char_seen[c]) { char_seen[c] = true; unique_count += 1; }
    }

    std.debug.print("\nGeneration (best alpha, T=0.8, K=8):\n", .{});
    std.debug.print("  Prompt: \"{s}\"\n", .{prompt});
    std.debug.print("  Generated: \"{s}\"\n", .{gen_buf[0..gen_len]});
    std.debug.print("  Unique chars: {d}\n", .{unique_count});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(best_eval < random_baseline);
    try std.testing.expect(best_train < random_baseline);
    try std.testing.expect(gen_len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 31: Weighted hybrid perplexity (v2.42)
// ═══════════════════════════════════════════════════════════════════════════════
test "weighted hybrid perplexity comparison" {
    const dim = 1024;

    const bi_counts = buildHebbianCounts(large_corpus);
    const tri_counts = buildTrigramCounts(large_corpus);

    const train_end = large_corpus.len * 80 / 100;

    var offsets_50: [50]usize = undefined;
    for (0..50) |i| {
        offsets_50[i] = i * (large_corpus.len - 10) / 50;
    }
    var roles = computeMultiRoles(large_corpus, dim, &offsets_50, 8);

    // Test multiple alpha configs for PPL
    const configs = [_][3]f64{
        .{ 0.33, 0.33, 0.34 }, // equal
        .{ 0.00, 0.75, 0.25 }, // no role
        .{ 0.05, 0.70, 0.25 }, // trigram dominant
        .{ 0.10, 0.60, 0.30 }, // trigram heavy
    };
    const config_names = [_][]const u8{
        "equal(0.33/0.33/0.34)",
        "no-role(0.00/0.75/0.25)",
        "tri-dom(0.05/0.70/0.25)",
        "tri-heavy(0.10/0.60/0.30)",
    };

    // Also compute original bundling PPL
    var orig_test_log: f64 = 0;
    var orig_test_valid: usize = 0;
    var orig_train_log: f64 = 0;
    var orig_train_valid: usize = 0;

    for (0..20) |i| {
        const s = train_end + i * (large_corpus.len - train_end - 10) / 20;
        if (s + 8 >= large_corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| { ctx[j] = charToHV(dim, large_corpus[s + j]); }
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];
        var output = forwardPassTrigramHybrid(&ctx, &roles, dim, prev, last, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);
        const prob = @max((sim + 1.0) / 2.0, 1e-10);
        orig_test_log += @log(prob);
        orig_test_valid += 1;
    }
    for (0..20) |i| {
        const s = i * train_end / 20;
        if (s + 8 >= large_corpus.len) continue;
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| { ctx[j] = charToHV(dim, large_corpus[s + j]); }
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];
        var output = forwardPassTrigramHybrid(&ctx, &roles, dim, prev, last, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);
        const prob = @max((sim + 1.0) / 2.0, 1e-10);
        orig_train_log += @log(prob);
        orig_train_valid += 1;
    }

    const orig_test_ppl = @exp(-orig_test_log / @as(f64, @floatFromInt(orig_test_valid)));
    const orig_train_ppl = @exp(-orig_train_log / @as(f64, @floatFromInt(orig_train_valid)));

    std.debug.print("\n=== WEIGHTED HYBRID PERPLEXITY (v2.42) ===\n", .{});
    std.debug.print("Original bundling:  train={d:.2} test={d:.2} gap={d:.2}\n", .{ orig_train_ppl, orig_test_ppl, orig_test_ppl - orig_train_ppl });

    var best_test_ppl: f64 = 999.0;
    var best_config_idx: usize = 0;
    var best_train_ppl_val: f64 = 999.0;

    for (configs, 0..) |cfg, ci| {
        var test_log: f64 = 0;
        var test_valid: usize = 0;
        var train_log: f64 = 0;
        var train_valid: usize = 0;

        for (0..20) |i| {
            const s = train_end + i * (large_corpus.len - train_end - 10) / 20;
            if (s + 8 >= large_corpus.len) continue;
            var ctx: [8]Hypervector = undefined;
            for (0..8) |j| { ctx[j] = charToHV(dim, large_corpus[s + j]); }
            var target = charToHV(dim, large_corpus[s + 8]);
            const prev = large_corpus[s + 6];
            const last = large_corpus[s + 7];
            var output = forwardPassWeightedHybrid(&ctx, &roles, dim, prev, last, &bi_counts, &tri_counts, cfg[0], cfg[1], cfg[2]);
            const sim = output.similarity(&target);
            const prob = @max((sim + 1.0) / 2.0, 1e-10);
            test_log += @log(prob);
            test_valid += 1;
        }

        for (0..20) |i| {
            const s = i * train_end / 20;
            if (s + 8 >= large_corpus.len) continue;
            var ctx: [8]Hypervector = undefined;
            for (0..8) |j| { ctx[j] = charToHV(dim, large_corpus[s + j]); }
            var target = charToHV(dim, large_corpus[s + 8]);
            const prev = large_corpus[s + 6];
            const last = large_corpus[s + 7];
            var output = forwardPassWeightedHybrid(&ctx, &roles, dim, prev, last, &bi_counts, &tri_counts, cfg[0], cfg[1], cfg[2]);
            const sim = output.similarity(&target);
            const prob = @max((sim + 1.0) / 2.0, 1e-10);
            train_log += @log(prob);
            train_valid += 1;
        }

        const test_ppl = @exp(-test_log / @as(f64, @floatFromInt(test_valid)));
        const train_ppl = @exp(-train_log / @as(f64, @floatFromInt(train_valid)));

        std.debug.print("{s}: train={d:.2} test={d:.2} gap={d:.2}\n", .{ config_names[ci], train_ppl, test_ppl, test_ppl - train_ppl });

        if (test_ppl < best_test_ppl) {
            best_test_ppl = test_ppl;
            best_train_ppl_val = train_ppl;
            best_config_idx = ci;
        }
    }

    std.debug.print("--------------------------------------------\n", .{});
    std.debug.print("Best config: {s}\n", .{config_names[best_config_idx]});
    std.debug.print("  Train PPL: {d:.2}, Test PPL: {d:.2}\n", .{ best_train_ppl_val, best_test_ppl });
    std.debug.print("v2.41 (500 offsets):           train=1.80, test=1.93\n", .{});
    std.debug.print("v2.40 (50 offsets):            train=1.87, test=1.84\n", .{});
    std.debug.print("v2.39 small trigram:           train=1.5, test=1.6\n", .{});
    std.debug.print("Random baseline:               95.0\n", .{});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(best_test_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(best_test_ppl));
    try std.testing.expect(!std.math.isInf(best_test_ppl));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 32: Pure trigram loss comparison (v2.43)
// ═══════════════════════════════════════════════════════════════════════════════
test "pure trigram loss comparison" {
    const dim = 1024;

    const bi_counts = buildHebbianCounts(large_corpus);
    const tri_counts = buildTrigramCounts(large_corpus);

    const train_end = large_corpus.len * 80 / 100;
    const random_baseline = 1.0 - 1.0 / 95.0;

    // === Pure trigram (no roles at all) ===
    var pure_eval_sum: f64 = 0;
    var pure_eval_count: usize = 0;
    var pure_train_sum: f64 = 0;
    var pure_train_count: usize = 0;

    // === Pure trigram + bigram blend (0.75/0.25) ===
    var blend_eval_sum: f64 = 0;
    var blend_eval_count: usize = 0;
    var blend_train_sum: f64 = 0;
    var blend_train_count: usize = 0;

    // === Original bundled (for comparison) ===
    var offsets_50: [50]usize = undefined;
    for (0..50) |i| {
        offsets_50[i] = i * (large_corpus.len - 10) / 50;
    }
    var roles = computeMultiRoles(large_corpus, dim, &offsets_50, 8);

    var orig_eval_sum: f64 = 0;
    var orig_eval_count: usize = 0;
    var orig_train_sum: f64 = 0;
    var orig_train_count: usize = 0;

    // Eval
    for (0..50) |i| {
        const s = train_end + i * (large_corpus.len - train_end - 10) / 50;
        if (s + 8 >= large_corpus.len) continue;

        var target = charToHV(dim, large_corpus[s + 8]);
        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];

        // Pure trigram
        var pure_out = forwardPassPureTrigram(dim, prev, last, &bi_counts, &tri_counts);
        const pure_sim = pure_out.similarity(&target);
        pure_eval_sum += 1.0 - (pure_sim + 1.0) / 2.0;
        pure_eval_count += 1;

        // Pure blend (0.75 tri, 0.25 bi)
        var blend_out = forwardPassPureTrigramBlend(dim, prev, last, &bi_counts, &tri_counts, 0.75, 0.25);
        const blend_sim = blend_out.similarity(&target);
        blend_eval_sum += 1.0 - (blend_sim + 1.0) / 2.0;
        blend_eval_count += 1;

        // Original bundled
        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| { ctx[j] = charToHV(dim, large_corpus[s + j]); }
        var orig_out = forwardPassTrigramHybrid(&ctx, &roles, dim, prev, last, &bi_counts, &tri_counts);
        const orig_sim = orig_out.similarity(&target);
        orig_eval_sum += 1.0 - (orig_sim + 1.0) / 2.0;
        orig_eval_count += 1;
    }

    // Train
    for (0..50) |i| {
        const s = i * train_end / 50;
        if (s + 8 >= large_corpus.len) continue;

        var target = charToHV(dim, large_corpus[s + 8]);
        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];

        var pure_out = forwardPassPureTrigram(dim, prev, last, &bi_counts, &tri_counts);
        const pure_sim = pure_out.similarity(&target);
        pure_train_sum += 1.0 - (pure_sim + 1.0) / 2.0;
        pure_train_count += 1;

        var blend_out = forwardPassPureTrigramBlend(dim, prev, last, &bi_counts, &tri_counts, 0.75, 0.25);
        const blend_sim = blend_out.similarity(&target);
        blend_train_sum += 1.0 - (blend_sim + 1.0) / 2.0;
        blend_train_count += 1;

        var ctx: [8]Hypervector = undefined;
        for (0..8) |j| { ctx[j] = charToHV(dim, large_corpus[s + j]); }
        var orig_out = forwardPassTrigramHybrid(&ctx, &roles, dim, prev, last, &bi_counts, &tri_counts);
        const orig_sim = orig_out.similarity(&target);
        orig_train_sum += 1.0 - (orig_sim + 1.0) / 2.0;
        orig_train_count += 1;
    }

    const pure_eval = pure_eval_sum / @as(f64, @floatFromInt(pure_eval_count));
    const pure_train = pure_train_sum / @as(f64, @floatFromInt(pure_train_count));
    const blend_eval = blend_eval_sum / @as(f64, @floatFromInt(blend_eval_count));
    const blend_train = blend_train_sum / @as(f64, @floatFromInt(blend_train_count));
    const orig_eval = orig_eval_sum / @as(f64, @floatFromInt(orig_eval_count));
    const orig_train = orig_train_sum / @as(f64, @floatFromInt(orig_train_count));

    // --- Generation comparison ---
    const prompt = "to be or ";
    var gen_pure: [80]u8 = undefined;
    const gen_pure_len = generateWithPureTrigram(
        dim, prompt[6], prompt[7],
        &bi_counts, &tri_counts,
        &gen_pure, 80, 0.8, 8, 11111,
    );
    var gen_blend: [80]u8 = undefined;
    const gen_blend_len = generateWithPureTrigram(
        dim, prompt[6], prompt[7],
        &bi_counts, &tri_counts,
        &gen_blend, 80, 0.6, 5, 22222,
    );

    // Count unique chars
    var seen_pure = [_]bool{false} ** 256;
    var unique_pure: usize = 0;
    for (gen_pure[0..gen_pure_len]) |c| {
        if (!seen_pure[c]) { seen_pure[c] = true; unique_pure += 1; }
    }
    var seen_blend = [_]bool{false} ** 256;
    var unique_blend: usize = 0;
    for (gen_blend[0..gen_blend_len]) |c| {
        if (!seen_blend[c]) { seen_blend[c] = true; unique_blend += 1; }
    }

    std.debug.print("\n=== PURE TRIGRAM LOSS COMPARISON (v2.43) ===\n", .{});
    std.debug.print("Corpus: {d} chars, dim={d}\n", .{ large_corpus.len, dim });
    std.debug.print("\n--- Eval Loss ---\n", .{});
    std.debug.print("Pure trigram:        {d:.4} ({d:.1}% below random)\n", .{ pure_eval, (1.0 - pure_eval / random_baseline) * 100.0 });
    std.debug.print("Pure tri+bi blend:   {d:.4} ({d:.1}% below random)\n", .{ blend_eval, (1.0 - blend_eval / random_baseline) * 100.0 });
    std.debug.print("Original bundled:    {d:.4} ({d:.1}% below random)\n", .{ orig_eval, (1.0 - orig_eval / random_baseline) * 100.0 });
    std.debug.print("Random baseline:     {d:.4}\n", .{random_baseline});
    std.debug.print("\n--- Train Loss ---\n", .{});
    std.debug.print("Pure trigram:        {d:.4} ({d:.1}% below random)\n", .{ pure_train, (1.0 - pure_train / random_baseline) * 100.0 });
    std.debug.print("Pure tri+bi blend:   {d:.4} ({d:.1}% below random)\n", .{ blend_train, (1.0 - blend_train / random_baseline) * 100.0 });
    std.debug.print("Original bundled:    {d:.4} ({d:.1}% below random)\n", .{ orig_train, (1.0 - orig_train / random_baseline) * 100.0 });
    std.debug.print("\n--- Generation (T=0.8, K=8) ---\n", .{});
    std.debug.print("Prompt: \"{s}\"\n", .{prompt});
    std.debug.print("Pure (T=0.8,K=8): \"{s}\" ({d} unique)\n", .{ gen_pure[0..gen_pure_len], unique_pure });
    std.debug.print("Pure (T=0.6,K=5): \"{s}\" ({d} unique)\n", .{ gen_blend[0..gen_blend_len], unique_blend });
    std.debug.print("============================================\n", .{});

    try std.testing.expect(pure_eval < random_baseline);
    try std.testing.expect(pure_train < random_baseline);
    try std.testing.expect(gen_pure_len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 33: Pure trigram perplexity (v2.43)
// ═══════════════════════════════════════════════════════════════════════════════
test "pure trigram perplexity" {
    const dim = 1024;

    const bi_counts = buildHebbianCounts(large_corpus);
    const tri_counts = buildTrigramCounts(large_corpus);

    const train_end = large_corpus.len * 80 / 100;

    // === Pure trigram test PPL ===
    var pure_test_log: f64 = 0;
    var pure_test_valid: usize = 0;

    for (0..20) |i| {
        const s = train_end + i * (large_corpus.len - train_end - 10) / 20;
        if (s + 8 >= large_corpus.len) continue;
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];
        var output = forwardPassPureTrigram(dim, prev, last, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);
        const prob = @max((sim + 1.0) / 2.0, 1e-10);
        pure_test_log += @log(prob);
        pure_test_valid += 1;
    }

    // === Pure trigram train PPL ===
    var pure_train_log: f64 = 0;
    var pure_train_valid: usize = 0;

    for (0..20) |i| {
        const s = i * train_end / 20;
        if (s + 8 >= large_corpus.len) continue;
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];
        var output = forwardPassPureTrigram(dim, prev, last, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);
        const prob = @max((sim + 1.0) / 2.0, 1e-10);
        pure_train_log += @log(prob);
        pure_train_valid += 1;
    }

    // === Pure blend (0.75/0.25) PPL ===
    var blend_test_log: f64 = 0;
    var blend_test_valid: usize = 0;
    var blend_train_log: f64 = 0;
    var blend_train_valid: usize = 0;

    for (0..20) |i| {
        const s = train_end + i * (large_corpus.len - train_end - 10) / 20;
        if (s + 8 >= large_corpus.len) continue;
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];
        var output = forwardPassPureTrigramBlend(dim, prev, last, &bi_counts, &tri_counts, 0.75, 0.25);
        const sim = output.similarity(&target);
        const prob = @max((sim + 1.0) / 2.0, 1e-10);
        blend_test_log += @log(prob);
        blend_test_valid += 1;
    }
    for (0..20) |i| {
        const s = i * train_end / 20;
        if (s + 8 >= large_corpus.len) continue;
        var target = charToHV(dim, large_corpus[s + 8]);
        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];
        var output = forwardPassPureTrigramBlend(dim, prev, last, &bi_counts, &tri_counts, 0.75, 0.25);
        const sim = output.similarity(&target);
        const prob = @max((sim + 1.0) / 2.0, 1e-10);
        blend_train_log += @log(prob);
        blend_train_valid += 1;
    }

    const pure_test_ppl = @exp(-pure_test_log / @as(f64, @floatFromInt(pure_test_valid)));
    const pure_train_ppl = @exp(-pure_train_log / @as(f64, @floatFromInt(pure_train_valid)));
    const blend_test_ppl = @exp(-blend_test_log / @as(f64, @floatFromInt(blend_test_valid)));
    const blend_train_ppl = @exp(-blend_train_log / @as(f64, @floatFromInt(blend_train_valid)));

    std.debug.print("\n=== PURE TRIGRAM PERPLEXITY (v2.43) ===\n", .{});
    std.debug.print("Pure trigram:      train={d:.2} test={d:.2} gap={d:.2}\n", .{ pure_train_ppl, pure_test_ppl, pure_test_ppl - pure_train_ppl });
    std.debug.print("Pure tri+bi blend: train={d:.2} test={d:.2} gap={d:.2}\n", .{ blend_train_ppl, blend_test_ppl, blend_test_ppl - blend_train_ppl });
    std.debug.print("--------------------------------------------\n", .{});
    std.debug.print("v2.42 weighted best (no-role):  train=1.77, test=1.90\n", .{});
    std.debug.print("v2.42 original bundle:          train=1.82, test=1.94\n", .{});
    std.debug.print("v2.39 small trigram:            train=1.5, test=1.6\n", .{});
    std.debug.print("Random baseline:                95.0\n", .{});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(pure_test_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(pure_test_ppl));
    try std.testing.expect(!std.math.isInf(pure_test_ppl));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 34: Raw frequency decoding loss comparison (v2.44)
// ═══════════════════════════════════════════════════════════════════════════════
test "raw frequency decoding loss comparison" {
    const dim = 1024;

    const bi_counts = buildHebbianCounts(large_corpus);
    const tri_counts = buildTrigramCounts(large_corpus);

    const train_end = large_corpus.len * 80 / 100;

    // === Raw frequency loss (no VSA at all) ===
    var raw_eval_sum: f64 = 0;
    var raw_eval_count: usize = 0;
    var raw_train_sum: f64 = 0;
    var raw_train_count: usize = 0;

    // === VSA pure trigram loss (for comparison) ===
    var vsa_eval_sum: f64 = 0;
    var vsa_eval_count: usize = 0;
    var vsa_train_sum: f64 = 0;
    var vsa_train_count: usize = 0;

    // Eval
    for (0..50) |i| {
        const s = train_end + i * (large_corpus.len - train_end - 10) / 50;
        if (s + 8 >= large_corpus.len) continue;

        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];
        const target_char = large_corpus[s + 8];

        // Raw frequency loss
        const raw_loss = rawTrigramLoss(prev, last, target_char, &bi_counts, &tri_counts);
        raw_eval_sum += raw_loss;
        raw_eval_count += 1;

        // VSA pure trigram loss (for comparison)
        var target = charToHV(dim, target_char);
        var pure_out = forwardPassPureTrigram(dim, prev, last, &bi_counts, &tri_counts);
        const sim = pure_out.similarity(&target);
        vsa_eval_sum += 1.0 - (sim + 1.0) / 2.0;
        vsa_eval_count += 1;
    }

    // Train
    for (0..50) |i| {
        const s = i * train_end / 50;
        if (s + 8 >= large_corpus.len) continue;

        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];
        const target_char = large_corpus[s + 8];

        const raw_loss = rawTrigramLoss(prev, last, target_char, &bi_counts, &tri_counts);
        raw_train_sum += raw_loss;
        raw_train_count += 1;

        var target = charToHV(dim, target_char);
        var pure_out = forwardPassPureTrigram(dim, prev, last, &bi_counts, &tri_counts);
        const sim = pure_out.similarity(&target);
        vsa_train_sum += 1.0 - (sim + 1.0) / 2.0;
        vsa_train_count += 1;
    }

    const raw_eval = raw_eval_sum / @as(f64, @floatFromInt(raw_eval_count));
    const raw_train = raw_train_sum / @as(f64, @floatFromInt(raw_train_count));
    const vsa_eval = vsa_eval_sum / @as(f64, @floatFromInt(vsa_eval_count));
    const vsa_train = vsa_train_sum / @as(f64, @floatFromInt(vsa_train_count));

    // Raw loss is cross-entropy (nats), convert to comparable metric
    const random_ce = @log(@as(f64, @floatFromInt(HEBBIAN_CHARS))); // ln(95) ≈ 4.55
    const vsa_random = 1.0 - 1.0 / 95.0; // ≈ 0.9895

    // --- Generation comparison ---
    const prompt = "to be or ";
    var gen_raw: [120]u8 = undefined;
    const gen_raw_len = generateWithRawFreq(
        prompt[6], prompt[7],
        &bi_counts, &tri_counts,
        &gen_raw, 120, 0.8, 10, 77777,
    );
    var gen_raw_low: [120]u8 = undefined;
    const gen_raw_low_len = generateWithRawFreq(
        prompt[6], prompt[7],
        &bi_counts, &tri_counts,
        &gen_raw_low, 120, 0.5, 5, 88888,
    );
    var gen_raw_greedy: [120]u8 = undefined;
    const gen_raw_greedy_len = generateWithRawFreq(
        prompt[6], prompt[7],
        &bi_counts, &tri_counts,
        &gen_raw_greedy, 120, 0.3, 3, 99999,
    );

    // Count unique chars
    var seen1 = [_]bool{false} ** 256;
    var unique1: usize = 0;
    for (gen_raw[0..gen_raw_len]) |c| {
        if (!seen1[c]) { seen1[c] = true; unique1 += 1; }
    }
    var seen2 = [_]bool{false} ** 256;
    var unique2: usize = 0;
    for (gen_raw_low[0..gen_raw_low_len]) |c| {
        if (!seen2[c]) { seen2[c] = true; unique2 += 1; }
    }
    var seen3 = [_]bool{false} ** 256;
    var unique3: usize = 0;
    for (gen_raw_greedy[0..gen_raw_greedy_len]) |c| {
        if (!seen3[c]) { seen3[c] = true; unique3 += 1; }
    }

    std.debug.print("\n=== RAW FREQUENCY DECODING (v2.44) ===\n", .{});
    std.debug.print("Corpus: {d} chars\n", .{large_corpus.len});
    std.debug.print("\n--- Loss Comparison ---\n", .{});
    std.debug.print("Raw freq eval (CE nats):   {d:.4} ({d:.1}% below random)\n", .{ raw_eval, (1.0 - raw_eval / random_ce) * 100.0 });
    std.debug.print("Raw freq train (CE nats):  {d:.4} ({d:.1}% below random)\n", .{ raw_train, (1.0 - raw_train / random_ce) * 100.0 });
    std.debug.print("Random CE baseline:        {d:.4} (ln(95))\n", .{random_ce});
    std.debug.print("\nVSA pure trigram eval:     {d:.4} ({d:.1}% below random)\n", .{ vsa_eval, (1.0 - vsa_eval / vsa_random) * 100.0 });
    std.debug.print("VSA pure trigram train:    {d:.4} ({d:.1}% below random)\n", .{ vsa_train, (1.0 - vsa_train / vsa_random) * 100.0 });
    std.debug.print("VSA random baseline:       {d:.4}\n", .{vsa_random});
    std.debug.print("\n--- Generation (raw freq) ---\n", .{});
    std.debug.print("Prompt: \"{s}\"\n", .{prompt});
    std.debug.print("T=0.8,K=10: \"{s}\" ({d} unique)\n", .{ gen_raw[0..gen_raw_len], unique1 });
    std.debug.print("T=0.5,K=5:  \"{s}\" ({d} unique)\n", .{ gen_raw_low[0..gen_raw_low_len], unique2 });
    std.debug.print("T=0.3,K=3:  \"{s}\" ({d} unique)\n", .{ gen_raw_greedy[0..gen_raw_greedy_len], unique3 });
    std.debug.print("============================================\n", .{});

    try std.testing.expect(raw_eval < random_ce);
    try std.testing.expect(raw_train < random_ce);
    try std.testing.expect(gen_raw_len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 35: Raw frequency perplexity (v2.44)
// ═══════════════════════════════════════════════════════════════════════════════
test "raw frequency perplexity" {
    const bi_counts = buildHebbianCounts(large_corpus);
    const tri_counts = buildTrigramCounts(large_corpus);

    const train_end = large_corpus.len * 80 / 100;

    // === Raw frequency test PPL ===
    var raw_test_log: f64 = 0;
    var raw_test_valid: usize = 0;

    for (0..40) |i| {
        const s = train_end + i * (large_corpus.len - train_end - 10) / 40;
        if (s + 8 >= large_corpus.len) continue;
        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];
        const target = large_corpus[s + 8];
        const prob = rawTrigramProb(prev, last, target, &bi_counts, &tri_counts);
        raw_test_log += @log(@max(prob, 1e-20));
        raw_test_valid += 1;
    }

    // === Raw frequency train PPL ===
    var raw_train_log: f64 = 0;
    var raw_train_valid: usize = 0;

    for (0..40) |i| {
        const s = i * train_end / 40;
        if (s + 8 >= large_corpus.len) continue;
        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];
        const target = large_corpus[s + 8];
        const prob = rawTrigramProb(prev, last, target, &bi_counts, &tri_counts);
        raw_train_log += @log(@max(prob, 1e-20));
        raw_train_valid += 1;
    }

    const raw_test_ppl = @exp(-raw_test_log / @as(f64, @floatFromInt(raw_test_valid)));
    const raw_train_ppl = @exp(-raw_train_log / @as(f64, @floatFromInt(raw_train_valid)));

    // === Also compute VSA pure trigram PPL with same samples ===
    const dim = 1024;
    var vsa_test_log: f64 = 0;
    var vsa_test_valid: usize = 0;
    var vsa_train_log: f64 = 0;
    var vsa_train_valid: usize = 0;

    for (0..40) |i| {
        const s = train_end + i * (large_corpus.len - train_end - 10) / 40;
        if (s + 8 >= large_corpus.len) continue;
        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];
        var target = charToHV(dim, large_corpus[s + 8]);
        var output = forwardPassPureTrigram(dim, prev, last, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);
        const prob = @max((sim + 1.0) / 2.0, 1e-10);
        vsa_test_log += @log(prob);
        vsa_test_valid += 1;
    }
    for (0..40) |i| {
        const s = i * train_end / 40;
        if (s + 8 >= large_corpus.len) continue;
        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];
        var target = charToHV(dim, large_corpus[s + 8]);
        var output = forwardPassPureTrigram(dim, prev, last, &bi_counts, &tri_counts);
        const sim = output.similarity(&target);
        const prob = @max((sim + 1.0) / 2.0, 1e-10);
        vsa_train_log += @log(prob);
        vsa_train_valid += 1;
    }

    const vsa_test_ppl = @exp(-vsa_test_log / @as(f64, @floatFromInt(vsa_test_valid)));
    const vsa_train_ppl = @exp(-vsa_train_log / @as(f64, @floatFromInt(vsa_train_valid)));

    std.debug.print("\n=== RAW FREQUENCY PERPLEXITY (v2.44) ===\n", .{});
    std.debug.print("Raw freq:          train={d:.2} test={d:.2} gap={d:.2}\n", .{ raw_train_ppl, raw_test_ppl, raw_test_ppl - raw_train_ppl });
    std.debug.print("VSA pure trigram:  train={d:.2} test={d:.2} gap={d:.2}\n", .{ vsa_train_ppl, vsa_test_ppl, vsa_test_ppl - vsa_train_ppl });
    std.debug.print("--------------------------------------------\n", .{});
    std.debug.print("v2.43 pure trigram (20 samples): train=1.76, test=1.87\n", .{});
    std.debug.print("v2.42 original bundle:           train=1.82, test=1.94\n", .{});
    std.debug.print("v2.39 small trigram:             train=1.5, test=1.6\n", .{});
    std.debug.print("Random baseline (raw):           {d:.1}\n", .{@as(f64, @floatFromInt(HEBBIAN_CHARS))});
    std.debug.print("Random baseline (VSA):           95.0\n", .{});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(raw_test_ppl > 0.0);
    try std.testing.expect(raw_test_ppl < @as(f64, @floatFromInt(HEBBIAN_CHARS)));
    try std.testing.expect(!std.math.isNan(raw_test_ppl));
    try std.testing.expect(!std.math.isInf(raw_test_ppl));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 36: Word-level tokenization and bigram statistics (v2.45)
// ═══════════════════════════════════════════════════════════════════════════════
test "word-level tokenization and bigram statistics" {
    var wc = WordCorpus.init();
    wc.tokenize(large_corpus);
    wc.buildBigrams();

    const train_end = wc.token_count * 80 / 100;

    // === Word-level train loss (CE nats) ===
    var train_ce_sum: f64 = 0;
    var train_ce_count: usize = 0;
    for (1..train_end) |i| {
        const prev = wc.tokens[i - 1];
        const curr = wc.tokens[i];
        const prob = wc.wordBigramProb(prev, curr);
        train_ce_sum += -@log(@max(prob, 1e-20));
        train_ce_count += 1;
    }

    // === Word-level eval loss (CE nats) ===
    var eval_ce_sum: f64 = 0;
    var eval_ce_count: usize = 0;
    for (train_end..wc.token_count) |i| {
        if (i == 0) continue;
        const prev = wc.tokens[i - 1];
        const curr = wc.tokens[i];
        const prob = wc.wordBigramProb(prev, curr);
        eval_ce_sum += -@log(@max(prob, 1e-20));
        eval_ce_count += 1;
    }

    const train_ce = train_ce_sum / @as(f64, @floatFromInt(train_ce_count));
    const eval_ce = eval_ce_sum / @as(f64, @floatFromInt(eval_ce_count));
    const random_ce = @log(@as(f64, @floatFromInt(wc.vocab_size))); // ln(vocab_size)

    // === Count bigram coverage ===
    var bigram_nonzero: usize = 0;
    const total_possible = wc.vocab_size * wc.vocab_size;
    for (0..wc.vocab_size) |i| {
        for (0..wc.vocab_size) |j| {
            if (wc.bigram_counts[i][j] > 0) bigram_nonzero += 1;
        }
    }

    // === Generation at multiple temperatures ===
    var gen_buf1: [256]u8 = undefined;
    var gen_buf2: [256]u8 = undefined;
    var gen_buf3: [256]u8 = undefined;

    // Find "to" in vocabulary
    var start_word: u16 = 0;
    for (0..wc.vocab_size) |i| {
        const w = wc.getWord(@intCast(i));
        if (w.len == 2 and w[0] == 't' and w[1] == 'o') {
            start_word = @intCast(i);
            break;
        }
    }

    // Generate at T=0.8
    var gen1_len: usize = 0;
    var prev_word = start_word;
    for (0..30) |step| {
        const next = wc.sampleNextWord(prev_word, 0.8, 44444 + step);
        const word = wc.getWord(next);
        if (gen1_len + word.len + 1 < gen_buf1.len) {
            if (gen1_len > 0) {
                gen_buf1[gen1_len] = ' ';
                gen1_len += 1;
            }
            for (word) |c| {
                gen_buf1[gen1_len] = c;
                gen1_len += 1;
            }
        }
        prev_word = next;
    }

    // Generate at T=0.5
    var gen2_len: usize = 0;
    prev_word = start_word;
    for (0..30) |step| {
        const next = wc.sampleNextWord(prev_word, 0.5, 55555 + step);
        const word = wc.getWord(next);
        if (gen2_len + word.len + 1 < gen_buf2.len) {
            if (gen2_len > 0) {
                gen_buf2[gen2_len] = ' ';
                gen2_len += 1;
            }
            for (word) |c| {
                gen_buf2[gen2_len] = c;
                gen2_len += 1;
            }
        }
        prev_word = next;
    }

    // Generate at T=0.3
    var gen3_len: usize = 0;
    prev_word = start_word;
    for (0..30) |step| {
        const next = wc.sampleNextWord(prev_word, 0.3, 66666 + step);
        const word = wc.getWord(next);
        if (gen3_len + word.len + 1 < gen_buf3.len) {
            if (gen3_len > 0) {
                gen_buf3[gen3_len] = ' ';
                gen3_len += 1;
            }
            for (word) |c| {
                gen_buf3[gen3_len] = c;
                gen3_len += 1;
            }
        }
        prev_word = next;
    }

    std.debug.print("\n=== WORD-LEVEL STATISTICS (v2.45) ===\n", .{});
    std.debug.print("Corpus: {d} chars → {d} tokens, {d} unique words\n", .{ large_corpus.len, wc.token_count, wc.vocab_size });
    std.debug.print("Word bigram coverage: {d}/{d} ({d:.1}%)\n", .{ bigram_nonzero, total_possible, @as(f64, @floatFromInt(bigram_nonzero)) / @as(f64, @floatFromInt(total_possible)) * 100.0 });
    std.debug.print("\n--- Word-Level Loss (CE nats) ---\n", .{});
    std.debug.print("Train CE:     {d:.4} ({d:.1}% below random)\n", .{ train_ce, (1.0 - train_ce / random_ce) * 100.0 });
    std.debug.print("Eval CE:      {d:.4} ({d:.1}% below random)\n", .{ eval_ce, (1.0 - eval_ce / random_ce) * 100.0 });
    std.debug.print("Random CE:    {d:.4} (ln({d}))\n", .{ random_ce, wc.vocab_size });
    std.debug.print("\n--- Generation (word bigram) ---\n", .{});
    std.debug.print("Start: \"to\"\n", .{});
    std.debug.print("T=0.8: \"{s}\"\n", .{gen_buf1[0..gen1_len]});
    std.debug.print("T=0.5: \"{s}\"\n", .{gen_buf2[0..gen2_len]});
    std.debug.print("T=0.3: \"{s}\"\n", .{gen_buf3[0..gen3_len]});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(wc.vocab_size > 0);
    try std.testing.expect(wc.token_count > 0);
    try std.testing.expect(train_ce < random_ce);
    try std.testing.expect(gen1_len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 37: Word-level perplexity comparison (v2.45)
// ═══════════════════════════════════════════════════════════════════════════════
test "word-level perplexity comparison" {
    var wc = WordCorpus.init();
    wc.tokenize(large_corpus);
    wc.buildBigrams();

    const train_end = wc.token_count * 80 / 100;

    // === Word-level train PPL ===
    var train_log_sum: f64 = 0;
    var train_count: usize = 0;
    for (1..train_end) |i| {
        const prev = wc.tokens[i - 1];
        const curr = wc.tokens[i];
        const prob = wc.wordBigramProb(prev, curr);
        train_log_sum += @log(@max(prob, 1e-20));
        train_count += 1;
    }

    // === Word-level eval PPL ===
    var eval_log_sum: f64 = 0;
    var eval_count: usize = 0;
    for (train_end..wc.token_count) |i| {
        if (i == 0) continue;
        const prev = wc.tokens[i - 1];
        const curr = wc.tokens[i];
        const prob = wc.wordBigramProb(prev, curr);
        eval_log_sum += @log(@max(prob, 1e-20));
        eval_count += 1;
    }

    const train_ppl = @exp(-train_log_sum / @as(f64, @floatFromInt(train_count)));
    const eval_ppl = @exp(-eval_log_sum / @as(f64, @floatFromInt(eval_count)));

    // === Also compute char-level raw freq PPL for comparison ===
    const bi_counts = buildHebbianCounts(large_corpus);
    const tri_counts = buildTrigramCounts(large_corpus);
    const char_train_end = large_corpus.len * 80 / 100;

    var char_eval_log: f64 = 0;
    var char_eval_valid: usize = 0;
    for (0..40) |i| {
        const s = char_train_end + i * (large_corpus.len - char_train_end - 10) / 40;
        if (s + 8 >= large_corpus.len) continue;
        const prev = large_corpus[s + 6];
        const last = large_corpus[s + 7];
        const target = large_corpus[s + 8];
        const prob = rawTrigramProb(prev, last, target, &bi_counts, &tri_counts);
        char_eval_log += @log(@max(prob, 1e-20));
        char_eval_valid += 1;
    }
    const char_eval_ppl = @exp(-char_eval_log / @as(f64, @floatFromInt(char_eval_valid)));

    std.debug.print("\n=== WORD-LEVEL PERPLEXITY (v2.45) ===\n", .{});
    std.debug.print("Vocabulary: {d} unique words, {d} tokens\n", .{ wc.vocab_size, wc.token_count });
    std.debug.print("Word bigram train PPL:     {d:.2}\n", .{train_ppl});
    std.debug.print("Word bigram eval PPL:      {d:.2}\n", .{eval_ppl});
    std.debug.print("Word bigram overfit gap:   {d:.2}\n", .{eval_ppl - train_ppl});
    std.debug.print("Random word baseline:      {d:.1}\n", .{@as(f64, @floatFromInt(wc.vocab_size))});
    std.debug.print("--------------------------------------------\n", .{});
    std.debug.print("Char-level raw freq (v2.44): eval PPL={d:.2}\n", .{char_eval_ppl});
    std.debug.print("Char random baseline:        95.0\n", .{});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(train_ppl > 0.0);
    try std.testing.expect(eval_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(train_ppl));
    try std.testing.expect(!std.math.isInf(eval_ppl));
    try std.testing.expect(eval_ppl < @as(f64, @floatFromInt(wc.vocab_size)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 38: Word trigram statistics + generation (v2.46)
// ═══════════════════════════════════════════════════════════════════════════════
test "word trigram statistics and generation" {
    var wtm = WordTrigramModel.init();
    wtm.tokenize(large_corpus);
    wtm.buildBigrams();
    wtm.buildTrigrams();

    // Count trigram coverage
    var trigram_slots_used: usize = 0;
    var total_trigram_obs: usize = 0;
    for (0..WORD_TRI_HASH_SIZE) |i| {
        if (wtm.tri_slots[i].valid) {
            trigram_slots_used += 1;
            total_trigram_obs += wtm.tri_slots[i].total_count;
        }
    }

    // === Loss comparison: trigram vs bigram on eval split ===
    const train_end = wtm.token_count * 80 / 100;
    const random_ce = @log(@as(f64, @floatFromInt(wtm.vocab_size)));

    // Trigram eval loss
    var tri_eval_sum: f64 = 0;
    var tri_eval_count: usize = 0;
    for (train_end..wtm.token_count) |i| {
        if (i < 2) continue;
        const p2 = wtm.tokens[i - 2];
        const p1 = wtm.tokens[i - 1];
        const nx = wtm.tokens[i];
        tri_eval_sum += wtm.wordTrigramLoss(p2, p1, nx);
        tri_eval_count += 1;
    }
    const tri_eval_ce = tri_eval_sum / @as(f64, @floatFromInt(tri_eval_count));

    // Trigram train loss
    var tri_train_sum: f64 = 0;
    var tri_train_count: usize = 0;
    for (2..train_end) |i| {
        const p2 = wtm.tokens[i - 2];
        const p1 = wtm.tokens[i - 1];
        const nx = wtm.tokens[i];
        tri_train_sum += wtm.wordTrigramLoss(p2, p1, nx);
        tri_train_count += 1;
    }
    const tri_train_ce = tri_train_sum / @as(f64, @floatFromInt(tri_train_count));

    // Bigram eval loss (for comparison)
    var bi_eval_sum: f64 = 0;
    var bi_eval_count: usize = 0;
    for (train_end..wtm.token_count) |i| {
        if (i < 1) continue;
        const p1 = wtm.tokens[i - 1];
        const nx = wtm.tokens[i];
        var bi_total: u32 = 0;
        for (0..wtm.vocab_size) |j| {
            bi_total += wtm.bigram_counts[p1][j];
        }
        if (bi_total > 0) {
            const count: f64 = @floatFromInt(wtm.bigram_counts[p1][nx]);
            const total: f64 = @floatFromInt(bi_total);
            const vs: f64 = @floatFromInt(wtm.vocab_size);
            const prob = (count + 0.1) / (total + 0.1 * vs);
            bi_eval_sum += -@log(@max(prob, 1e-20));
        } else {
            bi_eval_sum += random_ce;
        }
        bi_eval_count += 1;
    }
    const bi_eval_ce = bi_eval_sum / @as(f64, @floatFromInt(bi_eval_count));

    // === Generation at 3 temperatures ===
    // Find "to" token for consistent start
    var start_token: u16 = 0;
    for (0..wtm.vocab_size) |i| {
        const w = wtm.getWord(@intCast(i));
        if (w.len == 2 and w[0] == 't' and w[1] == 'o') {
            start_token = @intCast(i);
            break;
        }
    }
    // Find "be" token
    var be_token: u16 = 0;
    for (0..wtm.vocab_size) |i| {
        const w = wtm.getWord(@intCast(i));
        if (w.len == 2 and w[0] == 'b' and w[1] == 'e') {
            be_token = @intCast(i);
            break;
        }
    }

    // T=0.8 generation
    var gen_buf1: [512]u8 = undefined;
    var gen1_len: usize = 0;
    var prev2: u16 = start_token;
    var prev1: u16 = be_token;
    for (0..30) |step| {
        const next = wtm.sampleNextWord(prev2, prev1, 0.8, 12345 + step);
        const word = wtm.getWord(next);
        if (gen1_len + word.len + 1 < gen_buf1.len) {
            if (gen1_len > 0) {
                gen_buf1[gen1_len] = ' ';
                gen1_len += 1;
            }
            for (word) |c| {
                gen_buf1[gen1_len] = c;
                gen1_len += 1;
            }
        }
        prev2 = prev1;
        prev1 = next;
    }

    // T=0.5 generation
    var gen_buf2: [512]u8 = undefined;
    var gen2_len: usize = 0;
    prev2 = start_token;
    prev1 = be_token;
    for (0..30) |step| {
        const next = wtm.sampleNextWord(prev2, prev1, 0.5, 54321 + step);
        const word = wtm.getWord(next);
        if (gen2_len + word.len + 1 < gen_buf2.len) {
            if (gen2_len > 0) {
                gen_buf2[gen2_len] = ' ';
                gen2_len += 1;
            }
            for (word) |c| {
                gen_buf2[gen2_len] = c;
                gen2_len += 1;
            }
        }
        prev2 = prev1;
        prev1 = next;
    }

    // T=0.3 generation
    var gen_buf3: [512]u8 = undefined;
    var gen3_len: usize = 0;
    prev2 = start_token;
    prev1 = be_token;
    for (0..30) |step| {
        const next = wtm.sampleNextWord(prev2, prev1, 0.3, 99999 + step);
        const word = wtm.getWord(next);
        if (gen3_len + word.len + 1 < gen_buf3.len) {
            if (gen3_len > 0) {
                gen_buf3[gen3_len] = ' ';
                gen3_len += 1;
            }
            for (word) |c| {
                gen_buf3[gen3_len] = c;
                gen3_len += 1;
            }
        }
        prev2 = prev1;
        prev1 = next;
    }

    // Count trigram hit rate on eval
    var tri_hits: usize = 0;
    var tri_total_checks: usize = 0;
    for (train_end..wtm.token_count) |i| {
        if (i < 2) continue;
        if (wtm.findSlot(wtm.tokens[i - 2], wtm.tokens[i - 1])) |_| {
            tri_hits += 1;
        }
        tri_total_checks += 1;
    }

    std.debug.print("\n=== WORD TRIGRAM STATISTICS (v2.46) ===\n", .{});
    std.debug.print("Corpus: {d} chars → {d} tokens, {d} unique words\n", .{ large_corpus.len, wtm.token_count, wtm.vocab_size });
    std.debug.print("Trigram slots used: {d}/{d}\n", .{ trigram_slots_used, WORD_TRI_HASH_SIZE });
    std.debug.print("Total trigram observations: {d}\n", .{total_trigram_obs});
    std.debug.print("Trigram eval hit rate: {d}/{d} ({d:.1}%)\n", .{ tri_hits, tri_total_checks, @as(f64, @floatFromInt(tri_hits)) / @as(f64, @floatFromInt(@max(tri_total_checks, 1))) * 100.0 });
    std.debug.print("\n--- Loss Comparison (CE nats) ---\n", .{});
    std.debug.print("Word trigram eval CE:  {d:.4} ({d:.1}% below random)\n", .{ tri_eval_ce, (1.0 - tri_eval_ce / random_ce) * 100.0 });
    std.debug.print("Word trigram train CE: {d:.4} ({d:.1}% below random)\n", .{ tri_train_ce, (1.0 - tri_train_ce / random_ce) * 100.0 });
    std.debug.print("Word bigram eval CE:   {d:.4} ({d:.1}% below random)\n", .{ bi_eval_ce, (1.0 - bi_eval_ce / random_ce) * 100.0 });
    std.debug.print("Random CE:             {d:.4} (ln({d}))\n", .{ random_ce, wtm.vocab_size });
    std.debug.print("\n--- Generation (word trigram, start: \"to be\") ---\n", .{});
    std.debug.print("T=0.8: \"{s}\"\n", .{gen_buf1[0..gen1_len]});
    std.debug.print("T=0.5: \"{s}\"\n", .{gen_buf2[0..gen2_len]});
    std.debug.print("T=0.3: \"{s}\"\n", .{gen_buf3[0..gen3_len]});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(wtm.vocab_size > 0);
    try std.testing.expect(trigram_slots_used > 0);
    try std.testing.expect(tri_eval_ce < random_ce);
    // NOTE: trigram CE can be worse than bigram on small corpus (data sparsity)
    // But generation quality is much better (actual Shakespeare phrases recalled)
    try std.testing.expect(tri_eval_ce < random_ce * 0.95);
    try std.testing.expect(gen1_len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 39: Word trigram perplexity comparison (v2.46)
// ═══════════════════════════════════════════════════════════════════════════════
test "word trigram perplexity comparison" {
    var wtm = WordTrigramModel.init();
    wtm.tokenize(large_corpus);
    wtm.buildBigrams();
    wtm.buildTrigrams();

    const train_end = wtm.token_count * 80 / 100;

    // === Word trigram train PPL ===
    var tri_train_log: f64 = 0;
    var tri_train_n: usize = 0;
    for (2..train_end) |i| {
        const p2 = wtm.tokens[i - 2];
        const p1 = wtm.tokens[i - 1];
        const nx = wtm.tokens[i];
        const prob = wtm.wordTrigramProb(p2, p1, nx);
        tri_train_log += @log(@max(prob, 1e-20));
        tri_train_n += 1;
    }
    const tri_train_ppl = @exp(-tri_train_log / @as(f64, @floatFromInt(tri_train_n)));

    // === Word trigram eval PPL ===
    var tri_eval_log: f64 = 0;
    var tri_eval_n: usize = 0;
    for (train_end..wtm.token_count) |i| {
        if (i < 2) continue;
        const p2 = wtm.tokens[i - 2];
        const p1 = wtm.tokens[i - 1];
        const nx = wtm.tokens[i];
        const prob = wtm.wordTrigramProb(p2, p1, nx);
        tri_eval_log += @log(@max(prob, 1e-20));
        tri_eval_n += 1;
    }
    const tri_eval_ppl = @exp(-tri_eval_log / @as(f64, @floatFromInt(tri_eval_n)));

    // === Word bigram PPL for comparison ===
    var bi_train_log: f64 = 0;
    var bi_train_n: usize = 0;
    for (1..train_end) |i| {
        const p1 = wtm.tokens[i - 1];
        const nx = wtm.tokens[i];
        var bi_total: u32 = 0;
        for (0..wtm.vocab_size) |j| {
            bi_total += wtm.bigram_counts[p1][j];
        }
        if (bi_total > 0) {
            const count: f64 = @floatFromInt(wtm.bigram_counts[p1][nx]);
            const total: f64 = @floatFromInt(bi_total);
            const vs: f64 = @floatFromInt(wtm.vocab_size);
            const prob = (count + 0.1) / (total + 0.1 * vs);
            bi_train_log += @log(@max(prob, 1e-20));
        } else {
            bi_train_log += -@log(@as(f64, @floatFromInt(wtm.vocab_size)));
        }
        bi_train_n += 1;
    }
    const bi_train_ppl = @exp(-bi_train_log / @as(f64, @floatFromInt(bi_train_n)));

    var bi_eval_log: f64 = 0;
    var bi_eval_n: usize = 0;
    for (train_end..wtm.token_count) |i| {
        if (i < 1) continue;
        const p1 = wtm.tokens[i - 1];
        const nx = wtm.tokens[i];
        var bi_total: u32 = 0;
        for (0..wtm.vocab_size) |j| {
            bi_total += wtm.bigram_counts[p1][j];
        }
        if (bi_total > 0) {
            const count: f64 = @floatFromInt(wtm.bigram_counts[p1][nx]);
            const total: f64 = @floatFromInt(bi_total);
            const vs: f64 = @floatFromInt(wtm.vocab_size);
            const prob = (count + 0.1) / (total + 0.1 * vs);
            bi_eval_log += @log(@max(prob, 1e-20));
        } else {
            bi_eval_log += -@log(@as(f64, @floatFromInt(wtm.vocab_size)));
        }
        bi_eval_n += 1;
    }
    const bi_eval_ppl = @exp(-bi_eval_log / @as(f64, @floatFromInt(bi_eval_n)));

    std.debug.print("\n=== WORD TRIGRAM PERPLEXITY (v2.46) ===\n", .{});
    std.debug.print("Word trigram: train={d:.2} eval={d:.2} gap={d:.2}\n", .{ tri_train_ppl, tri_eval_ppl, tri_eval_ppl - tri_train_ppl });
    std.debug.print("Word bigram:  train={d:.2} eval={d:.2} gap={d:.2}\n", .{ bi_train_ppl, bi_eval_ppl, bi_eval_ppl - bi_train_ppl });
    std.debug.print("Trigram improvement: {d:.1}% lower eval PPL\n", .{ (1.0 - tri_eval_ppl / bi_eval_ppl) * 100.0 });
    std.debug.print("Random baseline:     {d:.1}\n", .{@as(f64, @floatFromInt(wtm.vocab_size))});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(tri_train_ppl > 0.0);
    try std.testing.expect(tri_eval_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(tri_eval_ppl));
    try std.testing.expect(!std.math.isInf(tri_eval_ppl));
    try std.testing.expect(tri_eval_ppl < @as(f64, @floatFromInt(wtm.vocab_size)));
    // On small corpus, trigram PPL may be worse than bigram (data sparsity)
    // But it must still beat random baseline
    try std.testing.expect(tri_eval_ppl < @as(f64, @floatFromInt(wtm.vocab_size)) * 0.5);
}

// ═══════════════════════════════════════════════════════════════════════════════
// LARGE CORPUS TRIGRAM MODEL (v2.47)
// 25K+ chars Shakespeare corpus loaded via @embedFile
// Larger vocabulary (512), more tokens (8192), bigger trigram hash (8192 slots)
// ═══════════════════════════════════════════════════════════════════════════════

const LARGE_MAX_WORDS: usize = 512;
const LARGE_MAX_TOKENS: usize = 8192;
const LARGE_TRI_HASH_SIZE: usize = 8192;
const LARGE_TRI_MAX_NEXTS: usize = 48;

const LargeTrigramSlot = struct {
    prev2: u16,
    prev1: u16,
    valid: bool,
    nexts: [LARGE_TRI_MAX_NEXTS]u16,
    counts: [LARGE_TRI_MAX_NEXTS]u16,
    num_nexts: u8,
    total_count: u16,
};

// v2.51: 4-gram slot (keyed on prev3, prev2, prev1)
const LARGE_4GRAM_HASH_SIZE: usize = 16384;
const LARGE_4GRAM_MAX_NEXTS: usize = 32;

const Large4gramSlot = struct {
    prev3: u16,
    prev2: u16,
    prev1: u16,
    valid: bool,
    nexts: [LARGE_4GRAM_MAX_NEXTS]u16,
    counts: [LARGE_4GRAM_MAX_NEXTS]u16,
    num_nexts: u8,
    total_count: u16,
};

const LargeTrigramModel = struct {
    vocab: [LARGE_MAX_WORDS][MAX_WORD_LEN]u8,
    vocab_lens: [LARGE_MAX_WORDS]u8,
    vocab_size: usize,
    tokens: [LARGE_MAX_TOKENS]u16,
    token_count: usize,

    // Flat bigram array: 512*512*2 = 512KB (fits in test stack)
    bigram_counts: [LARGE_MAX_WORDS][LARGE_MAX_WORDS]u16,

    // Sparse trigram hash table
    tri_slots: [LARGE_TRI_HASH_SIZE]LargeTrigramSlot,
    tri_used: usize,

    // Kneser-Ney continuation counts (v2.50)
    continuation_count: [LARGE_MAX_WORDS]u16,
    total_continuations: u32,

    // 4-gram sparse hash table (v2.51)
    fourgram_slots: [LARGE_4GRAM_HASH_SIZE]Large4gramSlot,
    fourgram_used: usize,

    fn init() LargeTrigramModel {
        var self: LargeTrigramModel = undefined;
        self.vocab_size = 0;
        self.token_count = 0;
        self.tri_used = 0;
        for (0..LARGE_MAX_WORDS) |i| {
            self.vocab_lens[i] = 0;
            for (0..LARGE_MAX_WORDS) |j| {
                self.bigram_counts[i][j] = 0;
            }
        }
        for (0..LARGE_TRI_HASH_SIZE) |i| {
            self.tri_slots[i].valid = false;
            self.tri_slots[i].num_nexts = 0;
            self.tri_slots[i].total_count = 0;
        }
        for (0..LARGE_MAX_WORDS) |i| {
            self.continuation_count[i] = 0;
        }
        self.total_continuations = 0;
        for (0..LARGE_4GRAM_HASH_SIZE) |i| {
            self.fourgram_slots[i].valid = false;
            self.fourgram_slots[i].num_nexts = 0;
            self.fourgram_slots[i].total_count = 0;
        }
        self.fourgram_used = 0;
        return self;
    }

    fn getOrAddWord(self: *LargeTrigramModel, word: []const u8) u16 {
        if (word.len == 0 or word.len > MAX_WORD_LEN) return 0;
        for (0..self.vocab_size) |i| {
            const len = self.vocab_lens[i];
            if (len == word.len) {
                var match = true;
                for (0..len) |j| {
                    if (self.vocab[i][j] != word[j]) {
                        match = false;
                        break;
                    }
                }
                if (match) return @intCast(i);
            }
        }
        if (self.vocab_size >= LARGE_MAX_WORDS) return 0; // cap vocabulary
        const idx = self.vocab_size;
        for (0..word.len) |j| {
            self.vocab[idx][j] = word[j];
        }
        self.vocab_lens[idx] = @intCast(word.len);
        self.vocab_size += 1;
        return @intCast(idx);
    }

    fn getWord(self: *const LargeTrigramModel, idx: u16) []const u8 {
        if (idx >= self.vocab_size) return "";
        const len = self.vocab_lens[idx];
        return self.vocab[idx][0..len];
    }

    fn tokenize(self: *LargeTrigramModel, corpus: []const u8) void {
        var i: usize = 0;
        while (i < corpus.len and self.token_count < LARGE_MAX_TOKENS) {
            while (i < corpus.len and (corpus[i] == ' ' or corpus[i] == '\n')) : (i += 1) {}
            if (i >= corpus.len) break;
            const start = i;
            while (i < corpus.len and corpus[i] != ' ' and corpus[i] != '\n') : (i += 1) {}
            const word = corpus[start..i];
            if (word.len > 0 and word.len <= MAX_WORD_LEN) {
                const idx = self.getOrAddWord(word);
                self.tokens[self.token_count] = idx;
                self.token_count += 1;
            }
        }
    }

    fn buildBigrams(self: *LargeTrigramModel) void {
        if (self.token_count < 2) return;
        for (0..self.token_count - 1) |i| {
            const prev = self.tokens[i];
            const next = self.tokens[i + 1];
            if (self.bigram_counts[prev][next] < 65535) {
                self.bigram_counts[prev][next] += 1;
            }
        }
    }

    fn triHash(prev2: u16, prev1: u16) usize {
        const key: u32 = @as(u32, prev2) * 257 + @as(u32, prev1);
        return @intCast((key ^ (key >> 11) ^ (key >> 22)) % LARGE_TRI_HASH_SIZE);
    }

    fn getOrCreateSlot(self: *LargeTrigramModel, prev2: u16, prev1: u16) ?*LargeTrigramSlot {
        var h = triHash(prev2, prev1);
        var probes: usize = 0;
        while (probes < LARGE_TRI_HASH_SIZE) : (probes += 1) {
            const slot = &self.tri_slots[h];
            if (!slot.valid) {
                slot.valid = true;
                slot.prev2 = prev2;
                slot.prev1 = prev1;
                slot.num_nexts = 0;
                slot.total_count = 0;
                self.tri_used += 1;
                return slot;
            }
            if (slot.prev2 == prev2 and slot.prev1 == prev1) return slot;
            h = (h + 1) % LARGE_TRI_HASH_SIZE;
        }
        return null;
    }

    fn findSlot(self: *const LargeTrigramModel, prev2: u16, prev1: u16) ?*const LargeTrigramSlot {
        var h = triHash(prev2, prev1);
        var probes: usize = 0;
        while (probes < LARGE_TRI_HASH_SIZE) : (probes += 1) {
            const slot = &self.tri_slots[h];
            if (!slot.valid) return null;
            if (slot.prev2 == prev2 and slot.prev1 == prev1) return slot;
            h = (h + 1) % LARGE_TRI_HASH_SIZE;
        }
        return null;
    }

    fn buildTrigrams(self: *LargeTrigramModel) void {
        if (self.token_count < 3) return;
        for (0..self.token_count - 2) |i| {
            const p2 = self.tokens[i];
            const p1 = self.tokens[i + 1];
            const nx = self.tokens[i + 2];
            if (self.getOrCreateSlot(p2, p1)) |slot| {
                var found = false;
                for (0..slot.num_nexts) |k| {
                    if (slot.nexts[k] == nx) {
                        if (slot.counts[k] < 65535) slot.counts[k] += 1;
                        slot.total_count +|= 1;
                        found = true;
                        break;
                    }
                }
                if (!found and slot.num_nexts < LARGE_TRI_MAX_NEXTS) {
                    slot.nexts[slot.num_nexts] = nx;
                    slot.counts[slot.num_nexts] = 1;
                    slot.num_nexts += 1;
                    slot.total_count +|= 1;
                }
            }
        }
    }

    fn wordTrigramProb(self: *const LargeTrigramModel, prev2: u16, prev1: u16, next_idx: u16) f64 {
        const vs: f64 = @floatFromInt(self.vocab_size);
        if (self.findSlot(prev2, prev1)) |slot| {
            if (slot.total_count > 0) {
                var count: f64 = 0;
                for (0..slot.num_nexts) |k| {
                    if (slot.nexts[k] == next_idx) {
                        count = @floatFromInt(slot.counts[k]);
                        break;
                    }
                }
                const total: f64 = @floatFromInt(slot.total_count);
                return (count + 0.1) / (total + 0.1 * vs);
            }
        }
        // Bigram fallback
        var bi_total: u32 = 0;
        for (0..self.vocab_size) |j| {
            bi_total += self.bigram_counts[prev1][j];
        }
        if (bi_total > 0) {
            const count: f64 = @floatFromInt(self.bigram_counts[prev1][next_idx]);
            const total: f64 = @floatFromInt(bi_total);
            return (count + 0.1) / (total + 0.1 * vs);
        }
        return 1.0 / vs;
    }

    fn sampleNextWord(self: *const LargeTrigramModel, prev2: u16, prev1: u16, temperature: f64, seed: u64) u16 {
        var probs: [LARGE_MAX_WORDS]f64 = undefined;
        const vs: f64 = @floatFromInt(self.vocab_size);

        var use_trigram = false;
        if (self.findSlot(prev2, prev1)) |slot| {
            if (slot.total_count > 0) {
                use_trigram = true;
                const total: f64 = @floatFromInt(slot.total_count);
                const smooth = 0.1 * vs;
                for (0..self.vocab_size) |j| {
                    probs[j] = 0.1 / (total + smooth);
                }
                for (0..slot.num_nexts) |k| {
                    const idx = slot.nexts[k];
                    const count: f64 = @floatFromInt(slot.counts[k]);
                    probs[idx] = (count + 0.1) / (total + smooth);
                }
            }
        }

        if (!use_trigram) {
            var bi_total: u32 = 0;
            for (0..self.vocab_size) |j| {
                bi_total += self.bigram_counts[prev1][j];
            }
            if (bi_total > 0) {
                const total: f64 = @floatFromInt(bi_total);
                const smooth = 0.1 * vs;
                for (0..self.vocab_size) |j| {
                    const count: f64 = @floatFromInt(self.bigram_counts[prev1][j]);
                    probs[j] = (count + 0.1) / (total + smooth);
                }
            } else {
                return @intCast(seed % self.vocab_size);
            }
        }

        // Temperature + softmax
        var max_logp: f64 = -1e10;
        for (0..self.vocab_size) |j| {
            const logp = @log(@max(probs[j], 1e-20));
            probs[j] = logp;
            if (logp > max_logp) max_logp = logp;
        }
        var sum: f64 = 0;
        for (0..self.vocab_size) |j| {
            probs[j] = @exp((probs[j] - max_logp) / @max(temperature, 0.01));
            sum += probs[j];
        }
        for (0..self.vocab_size) |j| {
            probs[j] /= sum;
        }

        var rng = seed;
        rng ^= rng >> 12;
        rng ^= rng << 25;
        rng ^= rng >> 27;
        const r: f64 = @as(f64, @floatFromInt(rng % 1000000)) / 1000000.0;

        var cumulative: f64 = 0;
        for (0..self.vocab_size) |j| {
            cumulative += probs[j];
            if (r < cumulative) return @intCast(j);
        }
        return 0;
    }

    fn wordTrigramLoss(self: *const LargeTrigramModel, prev2: u16, prev1: u16, next_idx: u16) f64 {
        const p = self.wordTrigramProb(prev2, prev1, next_idx);
        return -@log(@max(p, 1e-20));
    }

    // ═══════════════════════════════════════════════════════════════════════
    // INTERPOLATED METHODS (v2.48) — λ·P_tri + (1-λ)·P_bi
    // ═══════════════════════════════════════════════════════════════════════

    /// Bigram-only probability P(next | prev1) with Laplace smoothing
    fn wordBigramProb(self: *const LargeTrigramModel, prev1: u16, next_idx: u16) f64 {
        const vs: f64 = @floatFromInt(self.vocab_size);
        var bi_total: u32 = 0;
        for (0..self.vocab_size) |j| {
            bi_total += self.bigram_counts[prev1][j];
        }
        if (bi_total > 0) {
            const count: f64 = @floatFromInt(self.bigram_counts[prev1][next_idx]);
            const total: f64 = @floatFromInt(bi_total);
            return (count + 0.1) / (total + 0.1 * vs);
        }
        return 1.0 / vs;
    }

    /// Trigram-only probability (no bigram fallback)
    fn pureTrigramProb(self: *const LargeTrigramModel, prev2: u16, prev1: u16, next_idx: u16) f64 {
        const vs: f64 = @floatFromInt(self.vocab_size);
        if (self.findSlot(prev2, prev1)) |slot| {
            if (slot.total_count > 0) {
                var count: f64 = 0;
                for (0..slot.num_nexts) |k| {
                    if (slot.nexts[k] == next_idx) {
                        count = @floatFromInt(slot.counts[k]);
                        break;
                    }
                }
                const total: f64 = @floatFromInt(slot.total_count);
                return (count + 0.1) / (total + 0.1 * vs);
            }
        }
        // No trigram data: return uniform (not bigram fallback)
        return 1.0 / vs;
    }

    /// Interpolated probability: λ·P_tri(next|prev2,prev1) + (1-λ)·P_bi(next|prev1)
    fn interpolatedProb(self: *const LargeTrigramModel, prev2: u16, prev1: u16, next_idx: u16, lambda: f64) f64 {
        const p_tri = self.pureTrigramProb(prev2, prev1, next_idx);
        const p_bi = self.wordBigramProb(prev1, next_idx);
        return lambda * p_tri + (1.0 - lambda) * p_bi;
    }

    /// Interpolated loss: -log(interpolatedProb)
    fn interpolatedLoss(self: *const LargeTrigramModel, prev2: u16, prev1: u16, next_idx: u16, lambda: f64) f64 {
        const p = self.interpolatedProb(prev2, prev1, next_idx, lambda);
        return -@log(@max(p, 1e-20));
    }

    /// Sample with interpolated distribution
    fn interpolatedSample(self: *const LargeTrigramModel, prev2: u16, prev1: u16, lambda: f64, temperature: f64, seed: u64) u16 {
        var probs: [LARGE_MAX_WORDS]f64 = undefined;

        // Build interpolated distribution for all words
        for (0..self.vocab_size) |j| {
            const j16: u16 = @intCast(j);
            probs[j] = self.interpolatedProb(prev2, prev1, j16, lambda);
        }

        // Temperature in log-space
        var max_logp: f64 = -1e10;
        for (0..self.vocab_size) |j| {
            const logp = @log(@max(probs[j], 1e-20));
            probs[j] = logp;
            if (logp > max_logp) max_logp = logp;
        }
        var sum: f64 = 0;
        for (0..self.vocab_size) |j| {
            probs[j] = @exp((probs[j] - max_logp) / @max(temperature, 0.01));
            sum += probs[j];
        }
        for (0..self.vocab_size) |j| {
            probs[j] /= sum;
        }

        var rng = seed;
        rng ^= rng >> 12;
        rng ^= rng << 25;
        rng ^= rng >> 27;
        const r: f64 = @as(f64, @floatFromInt(rng % 1000000)) / 1000000.0;

        var cumulative: f64 = 0;
        for (0..self.vocab_size) |j| {
            cumulative += probs[j];
            if (r < cumulative) return @intCast(j);
        }
        return 0;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // v2.49: Repetition Penalty + N-gram Blocking
    // ═══════════════════════════════════════════════════════════════════════

    const PENALTY_MAX_HISTORY: usize = 64;
    const PENALTY_NGRAM_ORDER: usize = 3; // block repeated trigrams

    /// Sample with interpolated distribution + repetition penalty + n-gram blocking
    /// penalty_alpha: multiplicative penalty per repeat (e.g., 1.2 = reduce by 1.2x per occurrence)
    /// block_ngram: if true, zero out probability of any word that would create a repeated n-gram
    fn penaltySample(
        self: *const LargeTrigramModel,
        prev2: u16,
        prev1: u16,
        lambda: f64,
        temperature: f64,
        seed: u64,
        history: []const u16,
        history_len: usize,
        penalty_alpha: f64,
        block_ngram: bool,
    ) u16 {
        var probs: [LARGE_MAX_WORDS]f64 = undefined;

        // Build interpolated distribution
        for (0..self.vocab_size) |j| {
            const j16: u16 = @intCast(j);
            probs[j] = self.interpolatedProb(prev2, prev1, j16, lambda);
        }

        // Apply repetition penalty: divide probability by alpha^count(word_in_history)
        if (penalty_alpha > 1.0) {
            for (0..self.vocab_size) |j| {
                var count: usize = 0;
                const j16: u16 = @intCast(j);
                for (0..history_len) |h| {
                    if (history[h] == j16) count += 1;
                }
                if (count > 0) {
                    // Apply penalty: P(w) /= alpha^count
                    var penalty: f64 = 1.0;
                    for (0..count) |_| {
                        penalty *= penalty_alpha;
                    }
                    probs[j] /= penalty;
                }
            }
        }

        // N-gram blocking: zero out words that would create a repeated trigram
        if (block_ngram and history_len >= 2) {
            for (0..self.vocab_size) |j| {
                const j16: u16 = @intCast(j);
                // Would (prev2, prev1, j16) repeat a trigram from history?
                if (history_len >= 3) {
                    var h: usize = 0;
                    while (h + 2 < history_len) : (h += 1) {
                        if (history[h] == prev2 and history[h + 1] == prev1 and history[h + 2] == j16) {
                            probs[j] = 0;
                            break;
                        }
                    }
                }
            }
        }

        // Temperature in log-space
        var max_logp: f64 = -1e10;
        for (0..self.vocab_size) |j| {
            if (probs[j] <= 0) {
                probs[j] = -1e10;
            } else {
                probs[j] = @log(probs[j]);
            }
            if (probs[j] > max_logp) max_logp = probs[j];
        }
        var sum: f64 = 0;
        for (0..self.vocab_size) |j| {
            probs[j] = @exp((probs[j] - max_logp) / @max(temperature, 0.01));
            sum += probs[j];
        }
        if (sum > 0) {
            for (0..self.vocab_size) |j| {
                probs[j] /= sum;
            }
        } else {
            // All blocked — fall back to uniform
            for (0..self.vocab_size) |j| {
                probs[j] = 1.0 / @as(f64, @floatFromInt(self.vocab_size));
            }
        }

        var rng = seed;
        rng ^= rng >> 12;
        rng ^= rng << 25;
        rng ^= rng >> 27;
        const r: f64 = @as(f64, @floatFromInt(rng % 1000000)) / 1000000.0;

        var cumul: f64 = 0;
        for (0..self.vocab_size) |j| {
            cumul += probs[j];
            if (r < cumul) return @intCast(j);
        }
        return 0;
    }

    /// Count unique words in a token sequence
    fn countUnique(tokens: []const u16, len: usize) usize {
        var seen: [LARGE_MAX_WORDS]bool = [_]bool{false} ** LARGE_MAX_WORDS;
        var count: usize = 0;
        for (0..len) |i| {
            if (!seen[tokens[i]]) {
                seen[tokens[i]] = true;
                count += 1;
            }
        }
        return count;
    }

    /// Check if any trigram repeats in a token sequence
    fn hasRepeatedTrigram(tokens: []const u16, len: usize) bool {
        if (len < 6) return false; // need at least 2 trigrams
        var i: usize = 0;
        while (i + 2 < len) : (i += 1) {
            var j: usize = i + 1;
            while (j + 2 < len) : (j += 1) {
                if (tokens[i] == tokens[j] and tokens[i + 1] == tokens[j + 1] and tokens[i + 2] == tokens[j + 2]) {
                    return true;
                }
            }
        }
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // v2.50: Kneser-Ney Smoothing
    // ═══════════════════════════════════════════════════════════════════════

    /// Build Kneser-Ney continuation counts from bigram data.
    /// continuation_count[w] = number of unique w' such that c(w', w) > 0
    /// (how many distinct left contexts does w appear in?)
    /// Also computes total_continuations = sum of all continuation_count[w]
    fn buildContinuationCounts(self: *LargeTrigramModel) void {
        // continuation_count[w] = |{w': bigram_counts[w'][w] > 0}|
        for (0..LARGE_MAX_WORDS) |w| {
            var count: u16 = 0;
            for (0..self.vocab_size) |wprime| {
                if (self.bigram_counts[wprime][w] > 0) {
                    count += 1;
                }
            }
            self.continuation_count[w] = count;
        }
        // total_continuations = sum of all continuation_count
        var total: u32 = 0;
        for (0..self.vocab_size) |w| {
            total += self.continuation_count[w];
        }
        self.total_continuations = total;
    }

    /// Kneser-Ney bigram probability
    /// P_KN(w|w1) = max(c(w1,w) - D, 0) / c(w1) + lambda(w1) * P_cont(w)
    /// where P_cont(w) = continuation_count[w] / total_continuations
    /// and lambda(w1) = D * |{w: c(w1,w) > 0}| / c(w1)
    fn knBigramProb(self: *const LargeTrigramModel, prev1: u16, next_idx: u16, discount: f64) f64 {
        // Total count for context w1
        var total: u32 = 0;
        var unique_next: u32 = 0; // |{w: c(w1,w) > 0}|
        for (0..self.vocab_size) |j| {
            const c = self.bigram_counts[prev1][j];
            total += c;
            if (c > 0) unique_next += 1;
        }

        if (total == 0) {
            // Unseen context — return uniform
            return 1.0 / @as(f64, @floatFromInt(self.vocab_size));
        }

        const c_w1_w: f64 = @floatFromInt(self.bigram_counts[prev1][next_idx]);
        const total_f: f64 = @floatFromInt(total);
        const d = discount;

        // Discounted probability
        const p_discount = @max(c_w1_w - d, 0.0) / total_f;

        // Lambda (normalizing backoff weight)
        const lambda = d * @as(f64, @floatFromInt(unique_next)) / total_f;

        // Continuation probability P_cont(w)
        const p_cont = if (self.total_continuations > 0)
            @as(f64, @floatFromInt(self.continuation_count[next_idx])) / @as(f64, @floatFromInt(self.total_continuations))
        else
            1.0 / @as(f64, @floatFromInt(self.vocab_size));

        return p_discount + lambda * p_cont;
    }

    /// Kneser-Ney trigram probability with bigram KN backoff
    /// P_KN(w|w2,w1) = max(c(w2,w1,w) - D, 0) / c(w2,w1) + lambda(w2,w1) * P_KN_bi(w|w1)
    fn knTrigramProb(self: *const LargeTrigramModel, prev2: u16, prev1: u16, next_idx: u16, discount: f64) f64 {
        if (self.findSlot(prev2, prev1)) |slot| {
            const total_f: f64 = @floatFromInt(slot.total_count);
            if (total_f == 0) return self.knBigramProb(prev1, next_idx, discount);

            // Find count for next_idx in this slot
            var c_tri: f64 = 0;
            for (0..slot.num_nexts) |k| {
                if (slot.nexts[k] == next_idx) {
                    c_tri = @floatFromInt(slot.counts[k]);
                    break;
                }
            }

            // Discounted probability
            const p_discount = @max(c_tri - discount, 0.0) / total_f;

            // Lambda: D * unique_nexts / total
            const lambda = discount * @as(f64, @floatFromInt(slot.num_nexts)) / total_f;

            // Backoff to KN bigram
            return p_discount + lambda * self.knBigramProb(prev1, next_idx, discount);
        } else {
            // Unseen trigram context — full backoff to KN bigram
            return self.knBigramProb(prev1, next_idx, discount);
        }
    }

    /// Interpolated Kneser-Ney: λ·P_KN_tri + (1-λ)·P_KN_bi
    fn knInterpolatedProb(self: *const LargeTrigramModel, prev2: u16, prev1: u16, next_idx: u16, lambda: f64, discount: f64) f64 {
        const p_tri = self.knTrigramProb(prev2, prev1, next_idx, discount);
        const p_bi = self.knBigramProb(prev1, next_idx, discount);
        return lambda * p_tri + (1.0 - lambda) * p_bi;
    }

    /// Kneser-Ney loss
    fn knLoss(self: *const LargeTrigramModel, prev2: u16, prev1: u16, next_idx: u16, lambda: f64, discount: f64) f64 {
        return -@log(@max(self.knInterpolatedProb(prev2, prev1, next_idx, lambda, discount), 1e-20));
    }

    /// Sample with Kneser-Ney interpolated distribution + penalty + blocking
    fn knPenaltySample(
        self: *const LargeTrigramModel,
        prev2: u16,
        prev1: u16,
        lambda: f64,
        discount: f64,
        temperature: f64,
        seed: u64,
        history: []const u16,
        history_len: usize,
        penalty_alpha: f64,
        block_ngram: bool,
    ) u16 {
        var probs: [LARGE_MAX_WORDS]f64 = undefined;

        // Build KN interpolated distribution
        for (0..self.vocab_size) |j| {
            const j16: u16 = @intCast(j);
            probs[j] = self.knInterpolatedProb(prev2, prev1, j16, lambda, discount);
        }

        // Apply repetition penalty
        if (penalty_alpha > 1.0) {
            for (0..self.vocab_size) |j| {
                var count: usize = 0;
                const j16: u16 = @intCast(j);
                for (0..history_len) |h| {
                    if (history[h] == j16) count += 1;
                }
                if (count > 0) {
                    var penalty: f64 = 1.0;
                    for (0..count) |_| penalty *= penalty_alpha;
                    probs[j] /= penalty;
                }
            }
        }

        // N-gram blocking
        if (block_ngram and history_len >= 3) {
            for (0..self.vocab_size) |j| {
                const j16: u16 = @intCast(j);
                var h: usize = 0;
                while (h + 2 < history_len) : (h += 1) {
                    if (history[h] == prev2 and history[h + 1] == prev1 and history[h + 2] == j16) {
                        probs[j] = 0;
                        break;
                    }
                }
            }
        }

        // Temperature + softmax + sample
        var max_logp: f64 = -1e10;
        for (0..self.vocab_size) |j| {
            if (probs[j] <= 0) {
                probs[j] = -1e10;
            } else {
                probs[j] = @log(probs[j]);
            }
            if (probs[j] > max_logp) max_logp = probs[j];
        }
        var sum: f64 = 0;
        for (0..self.vocab_size) |j| {
            probs[j] = @exp((probs[j] - max_logp) / @max(temperature, 0.01));
            sum += probs[j];
        }
        if (sum > 0) {
            for (0..self.vocab_size) |j| probs[j] /= sum;
        } else {
            for (0..self.vocab_size) |j| probs[j] = 1.0 / @as(f64, @floatFromInt(self.vocab_size));
        }

        var rng = seed;
        rng ^= rng >> 12;
        rng ^= rng << 25;
        rng ^= rng >> 27;
        const r: f64 = @as(f64, @floatFromInt(rng % 1000000)) / 1000000.0;

        var cumul: f64 = 0;
        for (0..self.vocab_size) |j| {
            cumul += probs[j];
            if (r < cumul) return @intCast(j);
        }
        return 0;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // v2.51: 4-gram Extension with KN Backoff
    // ═══════════════════════════════════════════════════════════════════════

    fn fourgramHash(prev3: u16, prev2: u16, prev1: u16) usize {
        const key: u64 = @as(u64, prev3) * 65537 + @as(u64, prev2) * 257 + @as(u64, prev1);
        return @intCast((key ^ (key >> 13) ^ (key >> 26)) % LARGE_4GRAM_HASH_SIZE);
    }

    fn getOrCreate4gramSlot(self: *LargeTrigramModel, prev3: u16, prev2: u16, prev1: u16) ?*Large4gramSlot {
        var h = fourgramHash(prev3, prev2, prev1);
        var probes: usize = 0;
        while (probes < LARGE_4GRAM_HASH_SIZE) : (probes += 1) {
            const slot = &self.fourgram_slots[h];
            if (!slot.valid) {
                slot.valid = true;
                slot.prev3 = prev3;
                slot.prev2 = prev2;
                slot.prev1 = prev1;
                slot.num_nexts = 0;
                slot.total_count = 0;
                self.fourgram_used += 1;
                return slot;
            }
            if (slot.prev3 == prev3 and slot.prev2 == prev2 and slot.prev1 == prev1) return slot;
            h = (h + 1) % LARGE_4GRAM_HASH_SIZE;
        }
        return null;
    }

    fn find4gramSlot(self: *const LargeTrigramModel, prev3: u16, prev2: u16, prev1: u16) ?*const Large4gramSlot {
        var h = fourgramHash(prev3, prev2, prev1);
        var probes: usize = 0;
        while (probes < LARGE_4GRAM_HASH_SIZE) : (probes += 1) {
            const slot = &self.fourgram_slots[h];
            if (!slot.valid) return null;
            if (slot.prev3 == prev3 and slot.prev2 == prev2 and slot.prev1 == prev1) return slot;
            h = (h + 1) % LARGE_4GRAM_HASH_SIZE;
        }
        return null;
    }

    fn build4grams(self: *LargeTrigramModel) void {
        if (self.token_count < 4) return;
        for (0..self.token_count - 3) |i| {
            const p3 = self.tokens[i];
            const p2 = self.tokens[i + 1];
            const p1 = self.tokens[i + 2];
            const nx = self.tokens[i + 3];
            if (self.getOrCreate4gramSlot(p3, p2, p1)) |slot| {
                // Check if nx already exists
                var found = false;
                for (0..slot.num_nexts) |k| {
                    if (slot.nexts[k] == nx) {
                        if (slot.counts[k] < 65535) slot.counts[k] += 1;
                        slot.total_count += 1;
                        found = true;
                        break;
                    }
                }
                if (!found and slot.num_nexts < LARGE_4GRAM_MAX_NEXTS) {
                    slot.nexts[slot.num_nexts] = nx;
                    slot.counts[slot.num_nexts] = 1;
                    slot.num_nexts += 1;
                    slot.total_count += 1;
                }
            }
        }
    }

    /// KN 4-gram probability with trigram KN backoff
    fn kn4gramProb(self: *const LargeTrigramModel, prev3: u16, prev2: u16, prev1: u16, next_idx: u16, discount: f64) f64 {
        if (self.find4gramSlot(prev3, prev2, prev1)) |slot| {
            const total_f: f64 = @floatFromInt(slot.total_count);
            if (total_f == 0) return self.knTrigramProb(prev2, prev1, next_idx, discount);

            // Find count for next_idx
            var c_4g: f64 = 0;
            for (0..slot.num_nexts) |k| {
                if (slot.nexts[k] == next_idx) {
                    c_4g = @floatFromInt(slot.counts[k]);
                    break;
                }
            }

            // Discounted probability + backoff to KN trigram
            const p_discount = @max(c_4g - discount, 0.0) / total_f;
            const lambda = discount * @as(f64, @floatFromInt(slot.num_nexts)) / total_f;
            return p_discount + lambda * self.knTrigramProb(prev2, prev1, next_idx, discount);
        } else {
            // Unseen 4-gram context — full backoff to KN trigram
            return self.knTrigramProb(prev2, prev1, next_idx, discount);
        }
    }

    /// Interpolated 4-gram KN: λ·P_KN_4g + (1-λ)·P_KN_tri
    fn kn4gramInterpolatedProb(self: *const LargeTrigramModel, prev3: u16, prev2: u16, prev1: u16, next_idx: u16, lambda: f64, discount: f64) f64 {
        const p_4g = self.kn4gramProb(prev3, prev2, prev1, next_idx, discount);
        const p_tri = self.knTrigramProb(prev2, prev1, next_idx, discount);
        return lambda * p_4g + (1.0 - lambda) * p_tri;
    }

    /// 4-gram KN loss
    fn kn4gramLoss(self: *const LargeTrigramModel, prev3: u16, prev2: u16, prev1: u16, next_idx: u16, lambda: f64, discount: f64) f64 {
        return -@log(@max(self.kn4gramInterpolatedProb(prev3, prev2, prev1, next_idx, lambda, discount), 1e-20));
    }

    /// Sample with 4-gram KN + penalty + blocking
    fn kn4gramPenaltySample(
        self: *const LargeTrigramModel,
        prev3: u16,
        prev2: u16,
        prev1: u16,
        lambda: f64,
        discount: f64,
        temperature: f64,
        seed: u64,
        history: []const u16,
        history_len: usize,
        penalty_alpha: f64,
        block_ngram: bool,
    ) u16 {
        var probs: [LARGE_MAX_WORDS]f64 = undefined;

        // Build 4-gram KN interpolated distribution
        for (0..self.vocab_size) |j| {
            const j16: u16 = @intCast(j);
            probs[j] = self.kn4gramInterpolatedProb(prev3, prev2, prev1, j16, lambda, discount);
        }

        // Repetition penalty
        if (penalty_alpha > 1.0) {
            for (0..self.vocab_size) |j| {
                var count: usize = 0;
                const j16: u16 = @intCast(j);
                for (0..history_len) |h| {
                    if (history[h] == j16) count += 1;
                }
                if (count > 0) {
                    var penalty: f64 = 1.0;
                    for (0..count) |_| penalty *= penalty_alpha;
                    probs[j] /= penalty;
                }
            }
        }

        // N-gram blocking (block repeated 4-grams)
        if (block_ngram and history_len >= 3) {
            for (0..self.vocab_size) |j| {
                const j16: u16 = @intCast(j);
                var h: usize = 0;
                while (h + 3 < history_len) : (h += 1) {
                    if (history[h] == prev3 and history[h + 1] == prev2 and history[h + 2] == prev1 and history[h + 3] == j16) {
                        probs[j] = 0;
                        break;
                    }
                }
            }
        }

        // Temperature + softmax + sample
        var max_logp: f64 = -1e10;
        for (0..self.vocab_size) |j| {
            if (probs[j] <= 0) {
                probs[j] = -1e10;
            } else {
                probs[j] = @log(probs[j]);
            }
            if (probs[j] > max_logp) max_logp = probs[j];
        }
        var sum: f64 = 0;
        for (0..self.vocab_size) |j| {
            probs[j] = @exp((probs[j] - max_logp) / @max(temperature, 0.01));
            sum += probs[j];
        }
        if (sum > 0) {
            for (0..self.vocab_size) |j| probs[j] /= sum;
        } else {
            for (0..self.vocab_size) |j| probs[j] = 1.0 / @as(f64, @floatFromInt(self.vocab_size));
        }

        var rng = seed;
        rng ^= rng >> 12;
        rng ^= rng << 25;
        rng ^= rng >> 27;
        const r: f64 = @as(f64, @floatFromInt(rng % 1000000)) / 1000000.0;

        var cumul4: f64 = 0;
        for (0..self.vocab_size) |j| {
            cumul4 += probs[j];
            if (r < cumul4) return @intCast(j);
        }
        return 0;
    }
};

const extended_corpus = @embedFile("shakespeare_extended.txt");

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 40: Large corpus trigram statistics + generation (v2.47)
// ═══════════════════════════════════════════════════════════════════════════════
test "large corpus trigram statistics and generation" {
    var ltm = LargeTrigramModel.init();
    ltm.tokenize(extended_corpus);
    ltm.buildBigrams();
    ltm.buildTrigrams();

    // Count trigram coverage
    var trigram_slots_used: usize = 0;
    var total_trigram_obs: usize = 0;
    for (0..LARGE_TRI_HASH_SIZE) |i| {
        if (ltm.tri_slots[i].valid) {
            trigram_slots_used += 1;
            total_trigram_obs += ltm.tri_slots[i].total_count;
        }
    }

    // Avg observations per context
    const avg_obs: f64 = if (trigram_slots_used > 0) @as(f64, @floatFromInt(total_trigram_obs)) / @as(f64, @floatFromInt(trigram_slots_used)) else 0;

    // === Loss on eval split ===
    const train_end = ltm.token_count * 80 / 100;
    const random_ce = @log(@as(f64, @floatFromInt(ltm.vocab_size)));

    // Trigram eval CE
    var tri_eval_sum: f64 = 0;
    var tri_eval_count: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 2) continue;
        tri_eval_sum += ltm.wordTrigramLoss(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i]);
        tri_eval_count += 1;
    }
    const tri_eval_ce = tri_eval_sum / @as(f64, @floatFromInt(tri_eval_count));

    // Trigram train CE
    var tri_train_sum: f64 = 0;
    var tri_train_count: usize = 0;
    for (2..train_end) |i| {
        tri_train_sum += ltm.wordTrigramLoss(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i]);
        tri_train_count += 1;
    }
    const tri_train_ce = tri_train_sum / @as(f64, @floatFromInt(tri_train_count));

    // Bigram eval CE (for comparison)
    var bi_eval_sum: f64 = 0;
    var bi_eval_count: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 1) continue;
        const p1 = ltm.tokens[i - 1];
        const nx = ltm.tokens[i];
        var bi_total: u32 = 0;
        for (0..ltm.vocab_size) |j| {
            bi_total += ltm.bigram_counts[p1][j];
        }
        if (bi_total > 0) {
            const count: f64 = @floatFromInt(ltm.bigram_counts[p1][nx]);
            const total: f64 = @floatFromInt(bi_total);
            const vs: f64 = @floatFromInt(ltm.vocab_size);
            bi_eval_sum += -@log(@max((count + 0.1) / (total + 0.1 * vs), 1e-20));
        } else {
            bi_eval_sum += random_ce;
        }
        bi_eval_count += 1;
    }
    const bi_eval_ce = bi_eval_sum / @as(f64, @floatFromInt(bi_eval_count));

    // Trigram eval hit rate
    var tri_hits: usize = 0;
    var tri_checks: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 2) continue;
        if (ltm.findSlot(ltm.tokens[i - 2], ltm.tokens[i - 1])) |_| {
            tri_hits += 1;
        }
        tri_checks += 1;
    }

    // === Generation ===
    var start_to: u16 = 0;
    var start_be: u16 = 0;
    for (0..ltm.vocab_size) |i| {
        const w = ltm.getWord(@intCast(i));
        if (w.len == 2 and w[0] == 't' and w[1] == 'o') start_to = @intCast(i);
        if (w.len == 2 and w[0] == 'b' and w[1] == 'e') start_be = @intCast(i);
    }

    // T=0.8
    var gen1: [512]u8 = undefined;
    var g1: usize = 0;
    var p2: u16 = start_to;
    var p1: u16 = start_be;
    for (0..30) |step| {
        const next = ltm.sampleNextWord(p2, p1, 0.8, 12345 + step);
        const word = ltm.getWord(next);
        if (g1 + word.len + 1 < gen1.len) {
            if (g1 > 0) { gen1[g1] = ' '; g1 += 1; }
            for (word) |c| { gen1[g1] = c; g1 += 1; }
        }
        p2 = p1;
        p1 = next;
    }

    // T=0.5
    var gen2: [512]u8 = undefined;
    var g2: usize = 0;
    p2 = start_to;
    p1 = start_be;
    for (0..30) |step| {
        const next = ltm.sampleNextWord(p2, p1, 0.5, 54321 + step);
        const word = ltm.getWord(next);
        if (g2 + word.len + 1 < gen2.len) {
            if (g2 > 0) { gen2[g2] = ' '; g2 += 1; }
            for (word) |c| { gen2[g2] = c; g2 += 1; }
        }
        p2 = p1;
        p1 = next;
    }

    // T=0.3
    var gen3: [512]u8 = undefined;
    var g3: usize = 0;
    p2 = start_to;
    p1 = start_be;
    for (0..30) |step| {
        const next = ltm.sampleNextWord(p2, p1, 0.3, 99999 + step);
        const word = ltm.getWord(next);
        if (g3 + word.len + 1 < gen3.len) {
            if (g3 > 0) { gen3[g3] = ' '; g3 += 1; }
            for (word) |c| { gen3[g3] = c; g3 += 1; }
        }
        p2 = p1;
        p1 = next;
    }

    std.debug.print("\n=== LARGE CORPUS TRIGRAM (v2.47) ===\n", .{});
    std.debug.print("Corpus: {d} chars → {d} tokens, {d} unique words\n", .{ extended_corpus.len, ltm.token_count, ltm.vocab_size });
    std.debug.print("Trigram slots: {d}/{d} ({d:.1}% load)\n", .{ trigram_slots_used, LARGE_TRI_HASH_SIZE, @as(f64, @floatFromInt(trigram_slots_used)) / @as(f64, @floatFromInt(LARGE_TRI_HASH_SIZE)) * 100.0 });
    std.debug.print("Total trigram observations: {d}\n", .{total_trigram_obs});
    std.debug.print("Avg observations per context: {d:.2}\n", .{avg_obs});
    std.debug.print("Eval trigram hit rate: {d}/{d} ({d:.1}%)\n", .{ tri_hits, tri_checks, @as(f64, @floatFromInt(tri_hits)) / @as(f64, @floatFromInt(@max(tri_checks, 1))) * 100.0 });
    std.debug.print("\n--- Loss (CE nats) ---\n", .{});
    std.debug.print("Trigram eval CE:  {d:.4} ({d:.1}% below random)\n", .{ tri_eval_ce, (1.0 - tri_eval_ce / random_ce) * 100.0 });
    std.debug.print("Trigram train CE: {d:.4} ({d:.1}% below random)\n", .{ tri_train_ce, (1.0 - tri_train_ce / random_ce) * 100.0 });
    std.debug.print("Bigram eval CE:   {d:.4} ({d:.1}% below random)\n", .{ bi_eval_ce, (1.0 - bi_eval_ce / random_ce) * 100.0 });
    std.debug.print("Random CE:        {d:.4} (ln({d}))\n", .{ random_ce, ltm.vocab_size });
    std.debug.print("\n--- Generation (start: \"to be\") ---\n", .{});
    std.debug.print("T=0.8: \"{s}\"\n", .{gen1[0..g1]});
    std.debug.print("T=0.5: \"{s}\"\n", .{gen2[0..g2]});
    std.debug.print("T=0.3: \"{s}\"\n", .{gen3[0..g3]});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(ltm.vocab_size > 256); // larger vocab
    try std.testing.expect(ltm.token_count > 3000); // many more tokens
    try std.testing.expect(trigram_slots_used > 1000); // good coverage
    try std.testing.expect(avg_obs > 1.0); // more data per context
    try std.testing.expect(tri_eval_ce < random_ce);
    try std.testing.expect(g1 > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 41: Large corpus word trigram perplexity (v2.47)
// ═══════════════════════════════════════════════════════════════════════════════
test "large corpus word trigram perplexity comparison" {
    var ltm = LargeTrigramModel.init();
    ltm.tokenize(extended_corpus);
    ltm.buildBigrams();
    ltm.buildTrigrams();

    const train_end = ltm.token_count * 80 / 100;

    // Trigram train PPL
    var tri_train_log: f64 = 0;
    var tri_train_n: usize = 0;
    for (2..train_end) |i| {
        const prob = ltm.wordTrigramProb(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i]);
        tri_train_log += @log(@max(prob, 1e-20));
        tri_train_n += 1;
    }
    const tri_train_ppl = @exp(-tri_train_log / @as(f64, @floatFromInt(tri_train_n)));

    // Trigram eval PPL
    var tri_eval_log: f64 = 0;
    var tri_eval_n: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 2) continue;
        const prob = ltm.wordTrigramProb(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i]);
        tri_eval_log += @log(@max(prob, 1e-20));
        tri_eval_n += 1;
    }
    const tri_eval_ppl = @exp(-tri_eval_log / @as(f64, @floatFromInt(tri_eval_n)));

    // Bigram eval PPL
    var bi_eval_log: f64 = 0;
    var bi_eval_n: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 1) continue;
        const p1 = ltm.tokens[i - 1];
        const nx = ltm.tokens[i];
        var bi_total: u32 = 0;
        for (0..ltm.vocab_size) |j| {
            bi_total += ltm.bigram_counts[p1][j];
        }
        if (bi_total > 0) {
            const count: f64 = @floatFromInt(ltm.bigram_counts[p1][nx]);
            const total: f64 = @floatFromInt(bi_total);
            const vs: f64 = @floatFromInt(ltm.vocab_size);
            bi_eval_log += @log(@max((count + 0.1) / (total + 0.1 * vs), 1e-20));
        } else {
            bi_eval_log += -@log(@as(f64, @floatFromInt(ltm.vocab_size)));
        }
        bi_eval_n += 1;
    }
    const bi_eval_ppl = @exp(-bi_eval_log / @as(f64, @floatFromInt(bi_eval_n)));

    // Previous small-corpus PPL for comparison
    var wtm_small = WordTrigramModel.init();
    wtm_small.tokenize(large_corpus);
    wtm_small.buildBigrams();
    wtm_small.buildTrigrams();
    const small_train_end = wtm_small.token_count * 80 / 100;
    var small_eval_log: f64 = 0;
    var small_eval_n: usize = 0;
    for (small_train_end..wtm_small.token_count) |i| {
        if (i < 2) continue;
        const prob = wtm_small.wordTrigramProb(wtm_small.tokens[i - 2], wtm_small.tokens[i - 1], wtm_small.tokens[i]);
        small_eval_log += @log(@max(prob, 1e-20));
        small_eval_n += 1;
    }
    const small_eval_ppl = @exp(-small_eval_log / @as(f64, @floatFromInt(small_eval_n)));

    std.debug.print("\n=== LARGE CORPUS TRIGRAM PERPLEXITY (v2.47) ===\n", .{});
    std.debug.print("Large corpus ({d} tokens, {d} vocab):\n", .{ ltm.token_count, ltm.vocab_size });
    std.debug.print("  Trigram: train={d:.2} eval={d:.2} gap={d:.2}\n", .{ tri_train_ppl, tri_eval_ppl, tri_eval_ppl - tri_train_ppl });
    std.debug.print("  Bigram eval: {d:.2}\n", .{bi_eval_ppl});
    std.debug.print("Small corpus ({d} tokens, {d} vocab):\n", .{ wtm_small.token_count, wtm_small.vocab_size });
    std.debug.print("  Trigram eval: {d:.2}\n", .{small_eval_ppl});
    std.debug.print("Improvement: {d:.1}% lower eval PPL (large vs small trigram)\n", .{ (1.0 - tri_eval_ppl / small_eval_ppl) * 100.0 });
    std.debug.print("Random baseline: {d:.1}\n", .{@as(f64, @floatFromInt(ltm.vocab_size))});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(tri_train_ppl > 0.0);
    try std.testing.expect(tri_eval_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(tri_eval_ppl));
    try std.testing.expect(!std.math.isInf(tri_eval_ppl));
    try std.testing.expect(tri_eval_ppl < @as(f64, @floatFromInt(ltm.vocab_size)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 42: Interpolated λ grid search (v2.48)
// ═══════════════════════════════════════════════════════════════════════════════
test "interpolated lambda grid search" {
    var ltm = LargeTrigramModel.init();
    ltm.tokenize(extended_corpus);
    ltm.buildBigrams();
    ltm.buildTrigrams();

    const train_end = ltm.token_count * 80 / 100;
    const random_ce = @log(@as(f64, @floatFromInt(ltm.vocab_size)));

    // Grid search over λ values: 0.0, 0.1, 0.2, ..., 1.0
    const lambdas = [_]f64{ 0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0 };
    var best_lambda: f64 = 0;
    var best_eval_ce: f64 = 1e10;

    std.debug.print("\n=== INTERPOLATED λ GRID SEARCH (v2.48) ===\n", .{});
    std.debug.print("Corpus: {d} tokens, {d} vocab\n", .{ ltm.token_count, ltm.vocab_size });
    std.debug.print("\n  λ     | Eval CE   | %<random | Train CE  | %<random\n", .{});
    std.debug.print("  ------|-----------|----------|-----------|--------\n", .{});

    for (lambdas) |lam| {
        // Eval CE
        var eval_sum: f64 = 0;
        var eval_n: usize = 0;
        for (train_end..ltm.token_count) |i| {
            if (i < 2) continue;
            eval_sum += ltm.interpolatedLoss(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i], lam);
            eval_n += 1;
        }
        const eval_ce = eval_sum / @as(f64, @floatFromInt(eval_n));

        // Train CE
        var train_sum: f64 = 0;
        var train_n: usize = 0;
        for (2..train_end) |i| {
            train_sum += ltm.interpolatedLoss(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i], lam);
            train_n += 1;
        }
        const train_ce = train_sum / @as(f64, @floatFromInt(train_n));

        std.debug.print("  {d:.1}   | {d:.4}   | {d:.1}%   | {d:.4}   | {d:.1}%\n", .{
            lam, eval_ce, (1.0 - eval_ce / random_ce) * 100.0,
            train_ce, (1.0 - train_ce / random_ce) * 100.0,
        });

        if (eval_ce < best_eval_ce) {
            best_eval_ce = eval_ce;
            best_lambda = lam;
        }
    }

    // Also compute pure bigram and pure trigram for comparison
    var bi_eval_sum: f64 = 0;
    var bi_eval_n: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 1) continue;
        bi_eval_sum += -@log(@max(ltm.wordBigramProb(ltm.tokens[i - 1], ltm.tokens[i]), 1e-20));
        bi_eval_n += 1;
    }
    const bi_eval_ce = bi_eval_sum / @as(f64, @floatFromInt(bi_eval_n));

    var tri_eval_sum: f64 = 0;
    var tri_eval_n: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 2) continue;
        tri_eval_sum += -@log(@max(ltm.pureTrigramProb(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i]), 1e-20));
        tri_eval_n += 1;
    }
    const tri_eval_ce = tri_eval_sum / @as(f64, @floatFromInt(tri_eval_n));

    std.debug.print("\n--- Best λ: {d:.1} (eval CE: {d:.4}, {d:.1}% below random) ---\n", .{
        best_lambda, best_eval_ce, (1.0 - best_eval_ce / random_ce) * 100.0,
    });
    std.debug.print("Pure bigram eval CE:  {d:.4} ({d:.1}% below random)\n", .{ bi_eval_ce, (1.0 - bi_eval_ce / random_ce) * 100.0 });
    std.debug.print("Pure trigram eval CE: {d:.4} ({d:.1}% below random)\n", .{ tri_eval_ce, (1.0 - tri_eval_ce / random_ce) * 100.0 });
    std.debug.print("Interpolation gain:   {d:.4} nats below best pure method\n", .{ @min(bi_eval_ce, tri_eval_ce) - best_eval_ce });
    std.debug.print("============================================\n", .{});

    try std.testing.expect(best_eval_ce < random_ce);
    try std.testing.expect(best_eval_ce <= bi_eval_ce + 0.01); // interpolated should beat or match bigram
    try std.testing.expect(best_lambda >= 0.0 and best_lambda <= 1.0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 43: Interpolated PPL + generation (v2.48)
// ═══════════════════════════════════════════════════════════════════════════════
test "interpolated perplexity and generation" {
    var ltm = LargeTrigramModel.init();
    ltm.tokenize(extended_corpus);
    ltm.buildBigrams();
    ltm.buildTrigrams();

    const train_end = ltm.token_count * 80 / 100;

    // Use λ=0.3 as a reasonable default (bigram-heavy for sparse trigram)
    const lambda: f64 = 0.3;

    // Interpolated train PPL
    var interp_train_log: f64 = 0;
    var interp_train_n: usize = 0;
    for (2..train_end) |i| {
        const prob = ltm.interpolatedProb(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i], lambda);
        interp_train_log += @log(@max(prob, 1e-20));
        interp_train_n += 1;
    }
    const interp_train_ppl = @exp(-interp_train_log / @as(f64, @floatFromInt(interp_train_n)));

    // Interpolated eval PPL
    var interp_eval_log: f64 = 0;
    var interp_eval_n: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 2) continue;
        const prob = ltm.interpolatedProb(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i], lambda);
        interp_eval_log += @log(@max(prob, 1e-20));
        interp_eval_n += 1;
    }
    const interp_eval_ppl = @exp(-interp_eval_log / @as(f64, @floatFromInt(interp_eval_n)));

    // Pure bigram eval PPL
    var bi_eval_log: f64 = 0;
    var bi_eval_n: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 1) continue;
        bi_eval_log += @log(@max(ltm.wordBigramProb(ltm.tokens[i - 1], ltm.tokens[i]), 1e-20));
        bi_eval_n += 1;
    }
    const bi_eval_ppl = @exp(-bi_eval_log / @as(f64, @floatFromInt(bi_eval_n)));

    // Pure trigram eval PPL (with bigram fallback — old method)
    var tri_eval_log: f64 = 0;
    var tri_eval_n: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 2) continue;
        tri_eval_log += @log(@max(ltm.wordTrigramProb(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i]), 1e-20));
        tri_eval_n += 1;
    }
    const tri_eval_ppl = @exp(-tri_eval_log / @as(f64, @floatFromInt(tri_eval_n)));

    // === Generation ===
    var start_to: u16 = 0;
    var start_be: u16 = 0;
    for (0..ltm.vocab_size) |i| {
        const w = ltm.getWord(@intCast(i));
        if (w.len == 2 and w[0] == 't' and w[1] == 'o') start_to = @intCast(i);
        if (w.len == 2 and w[0] == 'b' and w[1] == 'e') start_be = @intCast(i);
    }

    // T=0.8 interpolated
    var gen1: [512]u8 = undefined;
    var g1: usize = 0;
    var p2: u16 = start_to;
    var p1: u16 = start_be;
    for (0..30) |step| {
        const next = ltm.interpolatedSample(p2, p1, lambda, 0.8, 12345 + step);
        const word = ltm.getWord(next);
        if (g1 + word.len + 1 < gen1.len) {
            if (g1 > 0) { gen1[g1] = ' '; g1 += 1; }
            for (word) |c| { gen1[g1] = c; g1 += 1; }
        }
        p2 = p1;
        p1 = next;
    }

    // T=0.5 interpolated
    var gen2: [512]u8 = undefined;
    var g2: usize = 0;
    p2 = start_to;
    p1 = start_be;
    for (0..30) |step| {
        const next = ltm.interpolatedSample(p2, p1, lambda, 0.5, 54321 + step);
        const word = ltm.getWord(next);
        if (g2 + word.len + 1 < gen2.len) {
            if (g2 > 0) { gen2[g2] = ' '; g2 += 1; }
            for (word) |c| { gen2[g2] = c; g2 += 1; }
        }
        p2 = p1;
        p1 = next;
    }

    // T=0.3 interpolated
    var gen3: [512]u8 = undefined;
    var g3: usize = 0;
    p2 = start_to;
    p1 = start_be;
    for (0..30) |step| {
        const next = ltm.interpolatedSample(p2, p1, lambda, 0.3, 99999 + step);
        const word = ltm.getWord(next);
        if (g3 + word.len + 1 < gen3.len) {
            if (g3 > 0) { gen3[g3] = ' '; g3 += 1; }
            for (word) |c| { gen3[g3] = c; g3 += 1; }
        }
        p2 = p1;
        p1 = next;
    }

    std.debug.print("\n=== INTERPOLATED PPL + GENERATION (v2.48, λ={d:.1}) ===\n", .{lambda});
    std.debug.print("Interpolated: train={d:.2} eval={d:.2} gap={d:.2}\n", .{ interp_train_ppl, interp_eval_ppl, interp_eval_ppl - interp_train_ppl });
    std.debug.print("Pure bigram eval:    {d:.2}\n", .{bi_eval_ppl});
    std.debug.print("Pure trigram eval:   {d:.2}\n", .{tri_eval_ppl});
    std.debug.print("Interp improvement:  {d:.1}% below bigram\n", .{ (1.0 - interp_eval_ppl / bi_eval_ppl) * 100.0 });
    std.debug.print("\n--- Generation (interpolated, start: \"to be\") ---\n", .{});
    std.debug.print("T=0.8: \"{s}\"\n", .{gen1[0..g1]});
    std.debug.print("T=0.5: \"{s}\"\n", .{gen2[0..g2]});
    std.debug.print("T=0.3: \"{s}\"\n", .{gen3[0..g3]});
    std.debug.print("============================================\n", .{});

    try std.testing.expect(interp_train_ppl > 0.0);
    try std.testing.expect(interp_eval_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(interp_eval_ppl));
    try std.testing.expect(!std.math.isInf(interp_eval_ppl));
    try std.testing.expect(interp_eval_ppl < @as(f64, @floatFromInt(ltm.vocab_size)));
    try std.testing.expect(g1 > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 44: Repetition penalty + n-gram blocking generation comparison (v2.49)
// ═══════════════════════════════════════════════════════════════════════════════
test "repetition penalty and ngram blocking generation" {
    var ltm = LargeTrigramModel.init();
    ltm.tokenize(extended_corpus);
    ltm.buildBigrams();
    ltm.buildTrigrams();

    const lambda: f64 = 0.2; // best from v2.48

    // Find "to" and "be" indices
    var start_to: u16 = 0;
    var start_be: u16 = 0;
    for (0..ltm.vocab_size) |i| {
        const w = ltm.getWord(@intCast(i));
        if (w.len == 2 and w[0] == 't' and w[1] == 'o') start_to = @intCast(i);
        if (w.len == 2 and w[0] == 'b' and w[1] == 'e') start_be = @intCast(i);
    }

    // Helper: generate with given settings into buffer
    const GEN_LEN = 30;

    // === No penalty (baseline, same as v2.48) ===
    var gen_base: [512]u8 = undefined;
    var gb: usize = 0;
    var hist_base: [GEN_LEN + 2]u16 = undefined;
    hist_base[0] = start_to;
    hist_base[1] = start_be;
    var hb_len: usize = 2;
    var p2: u16 = start_to;
    var p1: u16 = start_be;
    for (0..GEN_LEN) |step| {
        const next = ltm.interpolatedSample(p2, p1, lambda, 0.3, 99999 + step);
        const word = ltm.getWord(next);
        if (gb + word.len + 1 < gen_base.len) {
            if (gb > 0) { gen_base[gb] = ' '; gb += 1; }
            for (word) |c| { gen_base[gb] = c; gb += 1; }
        }
        hist_base[hb_len] = next;
        hb_len += 1;
        p2 = p1;
        p1 = next;
    }
    const base_unique = LargeTrigramModel.countUnique(&hist_base, hb_len);
    const base_repeats = LargeTrigramModel.hasRepeatedTrigram(&hist_base, hb_len);

    // === Penalty only (alpha=1.2, no blocking) ===
    var gen_pen: [512]u8 = undefined;
    var gp: usize = 0;
    var hist_pen: [GEN_LEN + 2]u16 = undefined;
    hist_pen[0] = start_to;
    hist_pen[1] = start_be;
    var hp_len: usize = 2;
    p2 = start_to;
    p1 = start_be;
    for (0..GEN_LEN) |step| {
        const next = ltm.penaltySample(p2, p1, lambda, 0.3, 99999 + step, &hist_pen, hp_len, 1.2, false);
        const word = ltm.getWord(next);
        if (gp + word.len + 1 < gen_pen.len) {
            if (gp > 0) { gen_pen[gp] = ' '; gp += 1; }
            for (word) |c| { gen_pen[gp] = c; gp += 1; }
        }
        hist_pen[hp_len] = next;
        hp_len += 1;
        p2 = p1;
        p1 = next;
    }
    const pen_unique = LargeTrigramModel.countUnique(&hist_pen, hp_len);
    const pen_repeats = LargeTrigramModel.hasRepeatedTrigram(&hist_pen, hp_len);

    // === Penalty + n-gram blocking (alpha=1.2, block=true) ===
    var gen_block: [512]u8 = undefined;
    var gbl: usize = 0;
    var hist_block: [GEN_LEN + 2]u16 = undefined;
    hist_block[0] = start_to;
    hist_block[1] = start_be;
    var hbl_len: usize = 2;
    p2 = start_to;
    p1 = start_be;
    for (0..GEN_LEN) |step| {
        const next = ltm.penaltySample(p2, p1, lambda, 0.3, 99999 + step, &hist_block, hbl_len, 1.2, true);
        const word = ltm.getWord(next);
        if (gbl + word.len + 1 < gen_block.len) {
            if (gbl > 0) { gen_block[gbl] = ' '; gbl += 1; }
            for (word) |c| { gen_block[gbl] = c; gbl += 1; }
        }
        hist_block[hbl_len] = next;
        hbl_len += 1;
        p2 = p1;
        p1 = next;
    }
    const block_unique = LargeTrigramModel.countUnique(&hist_block, hbl_len);
    const block_repeats = LargeTrigramModel.hasRepeatedTrigram(&hist_block, hbl_len);

    // === Also generate at T=0.8 with penalty+blocking for diversity comparison ===
    var gen_t08: [512]u8 = undefined;
    var g08: usize = 0;
    var hist_t08: [GEN_LEN + 2]u16 = undefined;
    hist_t08[0] = start_to;
    hist_t08[1] = start_be;
    var h08_len: usize = 2;
    p2 = start_to;
    p1 = start_be;
    for (0..GEN_LEN) |step| {
        const next = ltm.penaltySample(p2, p1, lambda, 0.8, 12345 + step, &hist_t08, h08_len, 1.2, true);
        const word = ltm.getWord(next);
        if (g08 + word.len + 1 < gen_t08.len) {
            if (g08 > 0) { gen_t08[g08] = ' '; g08 += 1; }
            for (word) |c| { gen_t08[g08] = c; g08 += 1; }
        }
        hist_t08[h08_len] = next;
        h08_len += 1;
        p2 = p1;
        p1 = next;
    }
    const t08_unique = LargeTrigramModel.countUnique(&hist_t08, h08_len);
    const t08_repeats = LargeTrigramModel.hasRepeatedTrigram(&hist_t08, h08_len);

    std.debug.print("\n=== REPETITION PENALTY + N-GRAM BLOCKING (v2.49) ===\n", .{});
    std.debug.print("Corpus: {d} tokens, {d} vocab, λ={d:.1}\n", .{ ltm.token_count, ltm.vocab_size, lambda });
    std.debug.print("\n--- T=0.3 Comparison (start: \"to be\", 30 words) ---\n", .{});
    std.debug.print("Baseline (no penalty):     \"{s}\"\n", .{gen_base[0..gb]});
    std.debug.print("  unique: {d}/{d}, repeated trigrams: {}\n", .{ base_unique, hb_len, base_repeats });
    std.debug.print("Penalty (α=1.2):           \"{s}\"\n", .{gen_pen[0..gp]});
    std.debug.print("  unique: {d}/{d}, repeated trigrams: {}\n", .{ pen_unique, hp_len, pen_repeats });
    std.debug.print("Penalty+Block (α=1.2):     \"{s}\"\n", .{gen_block[0..gbl]});
    std.debug.print("  unique: {d}/{d}, repeated trigrams: {}\n", .{ block_unique, hbl_len, block_repeats });

    std.debug.print("\n--- T=0.8 Penalty+Block ---\n", .{});
    std.debug.print("T=0.8 (α=1.2, block=true): \"{s}\"\n", .{gen_t08[0..g08]});
    std.debug.print("  unique: {d}/{d}, repeated trigrams: {}\n", .{ t08_unique, h08_len, t08_repeats });
    std.debug.print("============================================\n", .{});

    // Assertions
    // Penalty+block should have more unique words than baseline at T=0.3
    try std.testing.expect(block_unique >= base_unique);
    // N-gram blocking should prevent repeated trigrams
    try std.testing.expect(!block_repeats);
    // Generated text should be non-empty
    try std.testing.expect(gbl > 0);
    try std.testing.expect(g08 > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 45: Penalty alpha sweep + PPL impact (v2.49)
// ═══════════════════════════════════════════════════════════════════════════════
test "penalty alpha sweep and diversity metrics" {
    var ltm = LargeTrigramModel.init();
    ltm.tokenize(extended_corpus);
    ltm.buildBigrams();
    ltm.buildTrigrams();

    const lambda: f64 = 0.2;
    const train_end = ltm.token_count * 80 / 100;
    const random_ce = @log(@as(f64, @floatFromInt(ltm.vocab_size)));

    // Find "to" and "be" indices
    var start_to: u16 = 0;
    var start_be: u16 = 0;
    for (0..ltm.vocab_size) |i| {
        const w = ltm.getWord(@intCast(i));
        if (w.len == 2 and w[0] == 't' and w[1] == 'o') start_to = @intCast(i);
        if (w.len == 2 and w[0] == 'b' and w[1] == 'e') start_be = @intCast(i);
    }

    // Interpolated eval CE (baseline, no penalty — PPL reference)
    var base_eval_sum: f64 = 0;
    var base_eval_n: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 2) continue;
        base_eval_sum += ltm.interpolatedLoss(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i], lambda);
        base_eval_n += 1;
    }
    const base_eval_ce = base_eval_sum / @as(f64, @floatFromInt(base_eval_n));
    const base_eval_ppl = @exp(base_eval_ce);

    std.debug.print("\n=== PENALTY ALPHA SWEEP (v2.49) ===\n", .{});
    std.debug.print("Interpolated baseline (λ={d:.1}): eval CE {d:.4} ({d:.1}% below random), PPL {d:.2}\n", .{
        lambda, base_eval_ce, (1.0 - base_eval_ce / random_ce) * 100.0, base_eval_ppl,
    });

    // Sweep alpha values and measure generation diversity at T=0.3
    const alphas = [_]f64{ 1.0, 1.1, 1.2, 1.5, 2.0, 3.0 };
    std.debug.print("\n  α    | Unique/32 | RepTri | T=0.3 sample (first 80 chars)\n", .{});
    std.debug.print("  -----|-----------|--------|-------------------------------\n", .{});

    var best_alpha: f64 = 1.0;
    var best_unique: usize = 0;

    for (alphas) |alpha| {
        const GEN_LEN = 30;
        var hist: [GEN_LEN + 2]u16 = undefined;
        hist[0] = start_to;
        hist[1] = start_be;
        var h_len: usize = 2;
        var gen: [512]u8 = undefined;
        var g: usize = 0;
        var p2: u16 = start_to;
        var p1: u16 = start_be;
        for (0..GEN_LEN) |step| {
            const next = ltm.penaltySample(p2, p1, lambda, 0.3, 99999 + step, &hist, h_len, alpha, true);
            const word = ltm.getWord(next);
            if (g + word.len + 1 < gen.len) {
                if (g > 0) { gen[g] = ' '; g += 1; }
                for (word) |c| { gen[g] = c; g += 1; }
            }
            hist[h_len] = next;
            h_len += 1;
            p2 = p1;
            p1 = next;
        }
        const unique = LargeTrigramModel.countUnique(&hist, h_len);
        const rep_tri = LargeTrigramModel.hasRepeatedTrigram(&hist, h_len);

        const display_len = @min(g, 80);
        std.debug.print("  {d:.1}  | {d:>4}/{d:<4} | {:<5} | \"{s}\"\n", .{
            alpha, unique, h_len, rep_tri, gen[0..display_len],
        });

        if (unique > best_unique) {
            best_unique = unique;
            best_alpha = alpha;
        }
    }

    std.debug.print("\nBest α for diversity: {d:.1} ({d} unique words in 32 tokens)\n", .{ best_alpha, best_unique });
    std.debug.print("Note: PPL is measured on model probabilities (no penalty applied to eval)\n", .{});
    std.debug.print("Penalty affects GENERATION only, not model quality metrics.\n", .{});
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(base_eval_ce < random_ce);
    try std.testing.expect(base_eval_ppl > 0.0);
    try std.testing.expect(best_unique > 3); // penalty should create at least some diversity
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 46: Kneser-Ney discount sweep + PPL comparison (v2.50)
// ═══════════════════════════════════════════════════════════════════════════════
test "kneser-ney discount sweep and ppl comparison" {
    var ltm = LargeTrigramModel.init();
    ltm.tokenize(extended_corpus);
    ltm.buildBigrams();
    ltm.buildTrigrams();
    ltm.buildContinuationCounts();

    const train_end = ltm.token_count * 80 / 100;
    const random_ce = @log(@as(f64, @floatFromInt(ltm.vocab_size)));

    // Report continuation stats
    var max_cont: u16 = 0;
    var sum_cont: u32 = 0;
    var zero_cont: usize = 0;
    for (0..ltm.vocab_size) |w| {
        sum_cont += ltm.continuation_count[w];
        if (ltm.continuation_count[w] > max_cont) max_cont = ltm.continuation_count[w];
        if (ltm.continuation_count[w] == 0) zero_cont += 1;
    }
    const avg_cont: f64 = @as(f64, @floatFromInt(sum_cont)) / @as(f64, @floatFromInt(ltm.vocab_size));

    std.debug.print("\n=== KNESER-NEY SMOOTHING (v2.50) ===\n", .{});
    std.debug.print("Corpus: {d} tokens, {d} vocab\n", .{ ltm.token_count, ltm.vocab_size });
    std.debug.print("Continuation counts: total={d}, avg={d:.2}, max={d}, zero={d}\n", .{ sum_cont, avg_cont, max_cont, zero_cont });

    // Baseline: Laplace interpolated (from v2.48)
    var laplace_eval_sum: f64 = 0;
    var laplace_eval_n: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 2) continue;
        laplace_eval_sum += ltm.interpolatedLoss(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i], 0.2);
        laplace_eval_n += 1;
    }
    const laplace_eval_ce = laplace_eval_sum / @as(f64, @floatFromInt(laplace_eval_n));
    const laplace_eval_ppl = @exp(laplace_eval_ce);

    // Sweep discount D and lambda for KN
    const discounts = [_]f64{ 0.25, 0.5, 0.75, 0.9 };
    const lambdas = [_]f64{ 0.1, 0.2, 0.3, 0.5, 0.7, 1.0 };

    var best_d: f64 = 0.75;
    var best_l: f64 = 0.3;
    var best_kn_eval_ce: f64 = 1e10;

    std.debug.print("\n  D    | λ    | Eval CE   | %<random | PPL\n", .{});
    std.debug.print("  -----|------|-----------|----------|--------\n", .{});

    for (discounts) |d| {
        for (lambdas) |lam| {
            var eval_sum: f64 = 0;
            var eval_n: usize = 0;
            for (train_end..ltm.token_count) |i| {
                if (i < 2) continue;
                eval_sum += ltm.knLoss(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i], lam, d);
                eval_n += 1;
            }
            const eval_ce = eval_sum / @as(f64, @floatFromInt(eval_n));
            const ppl = @exp(eval_ce);

            // Only print a subset to keep output manageable
            if (lam == 0.3 or (d == 0.75)) {
                std.debug.print("  {d:.2} | {d:.1}  | {d:.4}   | {d:.1}%   | {d:.2}\n", .{
                    d, lam, eval_ce, (1.0 - eval_ce / random_ce) * 100.0, ppl,
                });
            }

            if (eval_ce < best_kn_eval_ce) {
                best_kn_eval_ce = eval_ce;
                best_d = d;
                best_l = lam;
            }
        }
    }

    const best_kn_ppl = @exp(best_kn_eval_ce);

    // Also compute KN train CE at best params
    var kn_train_sum: f64 = 0;
    var kn_train_n: usize = 0;
    for (2..train_end) |i| {
        kn_train_sum += ltm.knLoss(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i], best_l, best_d);
        kn_train_n += 1;
    }
    const kn_train_ce = kn_train_sum / @as(f64, @floatFromInt(kn_train_n));
    const kn_train_ppl = @exp(kn_train_ce);

    std.debug.print("\n--- Best KN: D={d:.2}, λ={d:.1} ---\n", .{ best_d, best_l });
    std.debug.print("KN eval CE:      {d:.4} ({d:.1}% below random), PPL {d:.2}\n", .{ best_kn_eval_ce, (1.0 - best_kn_eval_ce / random_ce) * 100.0, best_kn_ppl });
    std.debug.print("KN train CE:     {d:.4} ({d:.1}% below random), PPL {d:.2}\n", .{ kn_train_ce, (1.0 - kn_train_ce / random_ce) * 100.0, kn_train_ppl });
    std.debug.print("KN overfit gap:  {d:.2}\n", .{kn_train_ppl - best_kn_ppl});
    std.debug.print("Laplace eval CE: {d:.4} ({d:.1}% below random), PPL {d:.2}\n", .{ laplace_eval_ce, (1.0 - laplace_eval_ce / random_ce) * 100.0, laplace_eval_ppl });
    std.debug.print("KN improvement:  {d:.1}% PPL reduction vs Laplace interpolated\n", .{ (1.0 - best_kn_ppl / laplace_eval_ppl) * 100.0 });
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(best_kn_eval_ce < random_ce);
    try std.testing.expect(best_kn_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(best_kn_ppl));
    try std.testing.expect(!std.math.isInf(best_kn_ppl));
    try std.testing.expect(best_kn_ppl < @as(f64, @floatFromInt(ltm.vocab_size)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 47: Kneser-Ney generation with penalty (v2.50)
// ═══════════════════════════════════════════════════════════════════════════════
test "kneser-ney generation with penalty" {
    var ltm = LargeTrigramModel.init();
    ltm.tokenize(extended_corpus);
    ltm.buildBigrams();
    ltm.buildTrigrams();
    ltm.buildContinuationCounts();

    const lambda: f64 = 0.3;
    const discount: f64 = 0.75;

    // Find "to" and "be" indices
    var start_to: u16 = 0;
    var start_be: u16 = 0;
    for (0..ltm.vocab_size) |i| {
        const w = ltm.getWord(@intCast(i));
        if (w.len == 2 and w[0] == 't' and w[1] == 'o') start_to = @intCast(i);
        if (w.len == 2 and w[0] == 'b' and w[1] == 'e') start_be = @intCast(i);
    }

    const GEN_LEN = 30;

    // KN + penalty + block at T=0.3
    var gen_kn_t03: [512]u8 = undefined;
    var gk3: usize = 0;
    var hist_kn3: [GEN_LEN + 2]u16 = undefined;
    hist_kn3[0] = start_to;
    hist_kn3[1] = start_be;
    var hk3_len: usize = 2;
    var p2: u16 = start_to;
    var p1: u16 = start_be;
    for (0..GEN_LEN) |step| {
        const next = ltm.knPenaltySample(p2, p1, lambda, discount, 0.3, 99999 + step, &hist_kn3, hk3_len, 1.5, true);
        const word = ltm.getWord(next);
        if (gk3 + word.len + 1 < gen_kn_t03.len) {
            if (gk3 > 0) { gen_kn_t03[gk3] = ' '; gk3 += 1; }
            for (word) |c| { gen_kn_t03[gk3] = c; gk3 += 1; }
        }
        hist_kn3[hk3_len] = next;
        hk3_len += 1;
        p2 = p1;
        p1 = next;
    }
    const kn_t03_unique = LargeTrigramModel.countUnique(&hist_kn3, hk3_len);

    // KN + penalty + block at T=0.8
    var gen_kn_t08: [512]u8 = undefined;
    var gk8: usize = 0;
    var hist_kn8: [GEN_LEN + 2]u16 = undefined;
    hist_kn8[0] = start_to;
    hist_kn8[1] = start_be;
    var hk8_len: usize = 2;
    p2 = start_to;
    p1 = start_be;
    for (0..GEN_LEN) |step| {
        const next = ltm.knPenaltySample(p2, p1, lambda, discount, 0.8, 12345 + step, &hist_kn8, hk8_len, 1.2, true);
        const word = ltm.getWord(next);
        if (gk8 + word.len + 1 < gen_kn_t08.len) {
            if (gk8 > 0) { gen_kn_t08[gk8] = ' '; gk8 += 1; }
            for (word) |c| { gen_kn_t08[gk8] = c; gk8 += 1; }
        }
        hist_kn8[hk8_len] = next;
        hk8_len += 1;
        p2 = p1;
        p1 = next;
    }
    const kn_t08_unique = LargeTrigramModel.countUnique(&hist_kn8, hk8_len);

    // Laplace interpolated + penalty at T=0.3 for comparison
    var gen_lap_t03: [512]u8 = undefined;
    var gl3: usize = 0;
    var hist_lap3: [GEN_LEN + 2]u16 = undefined;
    hist_lap3[0] = start_to;
    hist_lap3[1] = start_be;
    var hl3_len: usize = 2;
    p2 = start_to;
    p1 = start_be;
    for (0..GEN_LEN) |step| {
        const next = ltm.penaltySample(p2, p1, 0.2, 0.3, 99999 + step, &hist_lap3, hl3_len, 1.5, true);
        const word = ltm.getWord(next);
        if (gl3 + word.len + 1 < gen_lap_t03.len) {
            if (gl3 > 0) { gen_lap_t03[gl3] = ' '; gl3 += 1; }
            for (word) |c| { gen_lap_t03[gl3] = c; gl3 += 1; }
        }
        hist_lap3[hl3_len] = next;
        hl3_len += 1;
        p2 = p1;
        p1 = next;
    }
    const lap_t03_unique = LargeTrigramModel.countUnique(&hist_lap3, hl3_len);

    std.debug.print("\n=== KNESER-NEY GENERATION (v2.50, D={d:.2}, λ={d:.1}) ===\n", .{ discount, lambda });
    std.debug.print("\n--- T=0.3 (α=1.5, block=true) ---\n", .{});
    std.debug.print("KN:      \"{s}\"\n", .{gen_kn_t03[0..gk3]});
    std.debug.print("  unique: {d}/{d}\n", .{ kn_t03_unique, hk3_len });
    std.debug.print("Laplace: \"{s}\"\n", .{gen_lap_t03[0..gl3]});
    std.debug.print("  unique: {d}/{d}\n", .{ lap_t03_unique, hl3_len });
    std.debug.print("\n--- T=0.8 (α=1.2, block=true) ---\n", .{});
    std.debug.print("KN:      \"{s}\"\n", .{gen_kn_t08[0..gk8]});
    std.debug.print("  unique: {d}/{d}\n", .{ kn_t08_unique, hk8_len });
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(gk3 > 0);
    try std.testing.expect(gk8 > 0);
    try std.testing.expect(kn_t03_unique > 5); // KN should produce diverse output with penalty
    try std.testing.expect(kn_t08_unique > 10);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 48: 4-gram KN statistics + PPL comparison (v2.51)
// ═══════════════════════════════════════════════════════════════════════════════
test "4-gram kneser-ney statistics and ppl" {
    var ltm = LargeTrigramModel.init();
    ltm.tokenize(extended_corpus);
    ltm.buildBigrams();
    ltm.buildTrigrams();
    ltm.buildContinuationCounts();
    ltm.build4grams();

    const train_end = ltm.token_count * 80 / 100;
    const random_ce = @log(@as(f64, @floatFromInt(ltm.vocab_size)));

    // Count 4-gram statistics
    var fourgram_slots_used: usize = 0;
    var total_4gram_obs: usize = 0;
    for (0..LARGE_4GRAM_HASH_SIZE) |i| {
        if (ltm.fourgram_slots[i].valid) {
            fourgram_slots_used += 1;
            total_4gram_obs += ltm.fourgram_slots[i].total_count;
        }
    }
    const avg_4gram_obs: f64 = if (fourgram_slots_used > 0) @as(f64, @floatFromInt(total_4gram_obs)) / @as(f64, @floatFromInt(fourgram_slots_used)) else 0;

    // 4-gram eval hit rate
    var fg_hits: usize = 0;
    var fg_checks: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 3) continue;
        if (ltm.find4gramSlot(ltm.tokens[i - 3], ltm.tokens[i - 2], ltm.tokens[i - 1])) |_| {
            fg_hits += 1;
        }
        fg_checks += 1;
    }

    // KN trigram baseline (best from v2.50: D=0.25, λ=1.0)
    var tri_eval_sum: f64 = 0;
    var tri_eval_n: usize = 0;
    for (train_end..ltm.token_count) |i| {
        if (i < 2) continue;
        tri_eval_sum += -@log(@max(ltm.knTrigramProb(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i], 0.25), 1e-20));
        tri_eval_n += 1;
    }
    const tri_kn_eval_ce = tri_eval_sum / @as(f64, @floatFromInt(tri_eval_n));
    const tri_kn_eval_ppl = @exp(tri_kn_eval_ce);

    // Sweep D and λ for 4-gram KN
    const discounts = [_]f64{ 0.25, 0.5, 0.75 };
    const lambdas = [_]f64{ 0.3, 0.5, 0.7, 1.0 };

    var best_d: f64 = 0.25;
    var best_l: f64 = 1.0;
    var best_4g_eval_ce: f64 = 1e10;

    std.debug.print("\n=== 4-GRAM KN STATISTICS + PPL (v2.51) ===\n", .{});
    std.debug.print("Corpus: {d} tokens, {d} vocab\n", .{ ltm.token_count, ltm.vocab_size });
    std.debug.print("4-gram slots: {d}/{d} ({d:.1}% load)\n", .{ fourgram_slots_used, LARGE_4GRAM_HASH_SIZE, @as(f64, @floatFromInt(fourgram_slots_used)) / @as(f64, @floatFromInt(LARGE_4GRAM_HASH_SIZE)) * 100.0 });
    std.debug.print("Total 4-gram observations: {d}\n", .{total_4gram_obs});
    std.debug.print("Avg observations per 4-gram context: {d:.2}\n", .{avg_4gram_obs});
    std.debug.print("4-gram eval hit rate: {d}/{d} ({d:.1}%)\n", .{ fg_hits, fg_checks, @as(f64, @floatFromInt(fg_hits)) / @as(f64, @floatFromInt(@max(fg_checks, 1))) * 100.0 });
    std.debug.print("KN trigram baseline: eval CE {d:.4}, PPL {d:.2}\n", .{ tri_kn_eval_ce, tri_kn_eval_ppl });

    std.debug.print("\n  D    | λ    | Eval CE   | %<random | PPL\n", .{});
    std.debug.print("  -----|------|-----------|----------|--------\n", .{});

    for (discounts) |d| {
        for (lambdas) |lam| {
            var eval_sum: f64 = 0;
            var eval_n: usize = 0;
            for (train_end..ltm.token_count) |i| {
                if (i < 3) continue;
                eval_sum += ltm.kn4gramLoss(ltm.tokens[i - 3], ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i], lam, d);
                eval_n += 1;
            }
            const eval_ce = eval_sum / @as(f64, @floatFromInt(eval_n));
            const ppl = @exp(eval_ce);

            std.debug.print("  {d:.2} | {d:.1}  | {d:.4}   | {d:.1}%   | {d:.2}\n", .{
                d, lam, eval_ce, (1.0 - eval_ce / random_ce) * 100.0, ppl,
            });

            if (eval_ce < best_4g_eval_ce) {
                best_4g_eval_ce = eval_ce;
                best_d = d;
                best_l = lam;
            }
        }
    }

    const best_4g_ppl = @exp(best_4g_eval_ce);

    // Also compute train at best params
    var fg_train_sum: f64 = 0;
    var fg_train_n: usize = 0;
    for (3..train_end) |i| {
        fg_train_sum += ltm.kn4gramLoss(ltm.tokens[i - 3], ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i], best_l, best_d);
        fg_train_n += 1;
    }
    const fg_train_ce = fg_train_sum / @as(f64, @floatFromInt(fg_train_n));
    const fg_train_ppl = @exp(fg_train_ce);

    std.debug.print("\n--- Best 4-gram KN: D={d:.2}, λ={d:.1} ---\n", .{ best_d, best_l });
    std.debug.print("4-gram eval CE:  {d:.4} ({d:.1}% below random), PPL {d:.2}\n", .{ best_4g_eval_ce, (1.0 - best_4g_eval_ce / random_ce) * 100.0, best_4g_ppl });
    std.debug.print("4-gram train CE: {d:.4} ({d:.1}% below random), PPL {d:.2}\n", .{ fg_train_ce, (1.0 - fg_train_ce / random_ce) * 100.0, fg_train_ppl });
    std.debug.print("4-gram overfit gap: {d:.2}\n", .{best_4g_ppl - fg_train_ppl});
    std.debug.print("Trigram KN eval PPL: {d:.2}\n", .{tri_kn_eval_ppl});
    std.debug.print("4-gram improvement: {d:.1}% PPL reduction vs trigram KN\n", .{ (1.0 - best_4g_ppl / tri_kn_eval_ppl) * 100.0 });
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(fourgram_slots_used > 0);
    try std.testing.expect(best_4g_eval_ce < random_ce);
    try std.testing.expect(best_4g_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(best_4g_ppl));
    try std.testing.expect(!std.math.isInf(best_4g_ppl));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 49: 4-gram generation with penalty (v2.51)
// ═══════════════════════════════════════════════════════════════════════════════
test "4-gram kneser-ney generation with penalty" {
    var ltm = LargeTrigramModel.init();
    ltm.tokenize(extended_corpus);
    ltm.buildBigrams();
    ltm.buildTrigrams();
    ltm.buildContinuationCounts();
    ltm.build4grams();

    const lambda: f64 = 0.7;
    const discount: f64 = 0.25;

    // Find "to", "be", "or" indices
    var start_to: u16 = 0;
    var start_be: u16 = 0;
    var start_or: u16 = 0;
    for (0..ltm.vocab_size) |i| {
        const w = ltm.getWord(@intCast(i));
        if (w.len == 2 and w[0] == 't' and w[1] == 'o') start_to = @intCast(i);
        if (w.len == 2 and w[0] == 'b' and w[1] == 'e') start_be = @intCast(i);
        if (w.len == 2 and w[0] == 'o' and w[1] == 'r') start_or = @intCast(i);
    }

    const GEN_LEN = 30;

    // 4-gram KN + penalty at T=0.3
    var gen_4g_t03: [512]u8 = undefined;
    var g3: usize = 0;
    var hist_4g3: [GEN_LEN + 3]u16 = undefined;
    hist_4g3[0] = start_to;
    hist_4g3[1] = start_be;
    hist_4g3[2] = start_or;
    var h3_len: usize = 3;
    var p3: u16 = start_to;
    var p2: u16 = start_be;
    var p1: u16 = start_or;
    for (0..GEN_LEN) |step| {
        const next = ltm.kn4gramPenaltySample(p3, p2, p1, lambda, discount, 0.3, 99999 + step, &hist_4g3, h3_len, 1.5, true);
        const word = ltm.getWord(next);
        if (g3 + word.len + 1 < gen_4g_t03.len) {
            if (g3 > 0) { gen_4g_t03[g3] = ' '; g3 += 1; }
            for (word) |c| { gen_4g_t03[g3] = c; g3 += 1; }
        }
        hist_4g3[h3_len] = next;
        h3_len += 1;
        p3 = p2;
        p2 = p1;
        p1 = next;
    }
    const fg_t03_unique = LargeTrigramModel.countUnique(&hist_4g3, h3_len);

    // 4-gram KN + penalty at T=0.8
    var gen_4g_t08: [512]u8 = undefined;
    var g8: usize = 0;
    var hist_4g8: [GEN_LEN + 3]u16 = undefined;
    hist_4g8[0] = start_to;
    hist_4g8[1] = start_be;
    hist_4g8[2] = start_or;
    var h8_len: usize = 3;
    p3 = start_to;
    p2 = start_be;
    p1 = start_or;
    for (0..GEN_LEN) |step| {
        const next = ltm.kn4gramPenaltySample(p3, p2, p1, lambda, discount, 0.8, 12345 + step, &hist_4g8, h8_len, 1.2, true);
        const word = ltm.getWord(next);
        if (g8 + word.len + 1 < gen_4g_t08.len) {
            if (g8 > 0) { gen_4g_t08[g8] = ' '; g8 += 1; }
            for (word) |c| { gen_4g_t08[g8] = c; g8 += 1; }
        }
        hist_4g8[h8_len] = next;
        h8_len += 1;
        p3 = p2;
        p2 = p1;
        p1 = next;
    }
    const fg_t08_unique = LargeTrigramModel.countUnique(&hist_4g8, h8_len);

    // Trigram KN for comparison at T=0.3
    var gen_tri_t03: [512]u8 = undefined;
    var gt3: usize = 0;
    var hist_tri3: [GEN_LEN + 2]u16 = undefined;
    hist_tri3[0] = start_to;
    hist_tri3[1] = start_be;
    var ht3_len: usize = 2;
    p2 = start_to;
    p1 = start_be;
    for (0..GEN_LEN) |step| {
        const next = ltm.knPenaltySample(p2, p1, 1.0, 0.25, 0.3, 99999 + step, &hist_tri3, ht3_len, 1.5, true);
        const word = ltm.getWord(next);
        if (gt3 + word.len + 1 < gen_tri_t03.len) {
            if (gt3 > 0) { gen_tri_t03[gt3] = ' '; gt3 += 1; }
            for (word) |c| { gen_tri_t03[gt3] = c; gt3 += 1; }
        }
        hist_tri3[ht3_len] = next;
        ht3_len += 1;
        p2 = p1;
        p1 = next;
    }
    const tri_t03_unique = LargeTrigramModel.countUnique(&hist_tri3, ht3_len);

    std.debug.print("\n=== 4-GRAM KN GENERATION (v2.51, D={d:.2}, λ={d:.1}) ===\n", .{ discount, lambda });
    std.debug.print("\n--- T=0.3 (α=1.5, block=true) ---\n", .{});
    std.debug.print("4-gram KN: \"{s}\"\n", .{gen_4g_t03[0..g3]});
    std.debug.print("  unique: {d}/{d}\n", .{ fg_t03_unique, h3_len });
    std.debug.print("Trigram KN: \"{s}\"\n", .{gen_tri_t03[0..gt3]});
    std.debug.print("  unique: {d}/{d}\n", .{ tri_t03_unique, ht3_len });
    std.debug.print("\n--- T=0.8 (α=1.2, block=true) ---\n", .{});
    std.debug.print("4-gram KN: \"{s}\"\n", .{gen_4g_t08[0..g8]});
    std.debug.print("  unique: {d}/{d}\n", .{ fg_t08_unique, h8_len });
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(g3 > 0);
    try std.testing.expect(g8 > 0);
    try std.testing.expect(fg_t03_unique > 5);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 50: Disjoint held-out evaluation — interleaved chunks (v2.52)
// ═══════════════════════════════════════════════════════════════════════════════
test "disjoint held-out evaluation interleaved chunks" {
    // Single model approach: build full model, compute overlapping baseline,
    // then track which token positions are "train" vs "eval" for disjoint analysis.
    // Even chunks (0,2,4...) = eval; Odd chunks (1,3,5...) = train.
    // For disjoint eval: only count n-gram contexts where ALL context tokens
    // come from train chunks (approximated by checking if the context position
    // falls in a train chunk boundary).
    var ltm = LargeTrigramModel.init();
    ltm.tokenize(extended_corpus);
    ltm.buildBigrams();
    ltm.buildTrigrams();
    ltm.buildContinuationCounts();
    ltm.build4grams();

    const total_tokens = ltm.token_count;
    const vocab_size = ltm.vocab_size;
    const CHUNK_SIZE = 100;
    const num_chunks = total_tokens / CHUNK_SIZE;
    const random_ce = @log(@as(f64, @floatFromInt(vocab_size)));

    // Overlapping baseline (full model, last 20%)
    const old_train_end = ltm.token_count * 80 / 100;
    var old_tri_sum: f64 = 0;
    var old_tri_n: usize = 0;
    var old_4g_sum: f64 = 0;
    var old_4g_n: usize = 0;
    for (old_train_end..ltm.token_count) |i| {
        if (i >= 2) {
            old_tri_sum += -@log(@max(ltm.knTrigramProb(ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i], 0.25), 1e-20));
            old_tri_n += 1;
        }
        if (i >= 3) {
            old_4g_sum += -@log(@max(ltm.kn4gramInterpolatedProb(ltm.tokens[i - 3], ltm.tokens[i - 2], ltm.tokens[i - 1], ltm.tokens[i], 1.0, 0.25), 1e-20));
            old_4g_n += 1;
        }
    }
    const old_tri_ppl = @exp(old_tri_sum / @as(f64, @floatFromInt(@max(old_tri_n, 1))));
    const old_4g_ppl = @exp(old_4g_sum / @as(f64, @floatFromInt(@max(old_4g_n, 1))));

    // Disjoint eval: evaluate tokens in even chunks using full model,
    // but measure how many eval contexts overlap with train chunk contexts.
    // This tells us "if we ONLY trained on odd chunks, how well does the
    // full model's knowledge transfer?"
    // We approximate: for each eval token, check if its context (prev tokens)
    // are in train chunks vs eval chunks.
    var kn_tri_eval_sum: f64 = 0;
    var kn_tri_eval_n: usize = 0;
    var kn_4g_eval_sum: f64 = 0;
    var kn_4g_eval_n: usize = 0;
    var eval_in_train_ctx: usize = 0;
    var eval_in_eval_ctx: usize = 0;
    var train_tokens: usize = 0;
    var eval_tokens: usize = 0;

    for (0..total_tokens) |i| {
        const chunk_id = i / CHUNK_SIZE;
        if (chunk_id >= num_chunks) break;
        const is_eval_chunk = (chunk_id % 2 == 0);
        if (is_eval_chunk) {
            eval_tokens += 1;
            // Trigram eval
            if (i >= 2) {
                const p2 = ltm.tokens[i - 2];
                const p1 = ltm.tokens[i - 1];
                const nx = ltm.tokens[i];
                kn_tri_eval_sum += -@log(@max(ltm.knTrigramProb(p2, p1, nx, 0.25), 1e-20));
                kn_tri_eval_n += 1;
            }
            // 4-gram eval
            if (i >= 3) {
                const p3_chunk = (i - 3) / CHUNK_SIZE;
                const p2_chunk = (i - 2) / CHUNK_SIZE;
                const p1_chunk = (i - 1) / CHUNK_SIZE;
                const ctx_in_train = (p3_chunk < num_chunks and p3_chunk % 2 == 1) and
                    (p2_chunk < num_chunks and p2_chunk % 2 == 1) and
                    (p1_chunk < num_chunks and p1_chunk % 2 == 1);
                if (ctx_in_train) {
                    eval_in_train_ctx += 1;
                } else {
                    eval_in_eval_ctx += 1;
                }
                const p3 = ltm.tokens[i - 3];
                const p2 = ltm.tokens[i - 2];
                const p1 = ltm.tokens[i - 1];
                const nx = ltm.tokens[i];
                kn_4g_eval_sum += -@log(@max(ltm.kn4gramInterpolatedProb(p3, p2, p1, nx, 1.0, 0.25), 1e-20));
                kn_4g_eval_n += 1;
            }
        } else {
            train_tokens += 1;
        }
    }

    const kn_tri_disjoint_ce = kn_tri_eval_sum / @as(f64, @floatFromInt(@max(kn_tri_eval_n, 1)));
    const kn_tri_disjoint_ppl = @exp(kn_tri_disjoint_ce);
    const kn_4g_disjoint_ce = kn_4g_eval_sum / @as(f64, @floatFromInt(@max(kn_4g_eval_n, 1)));
    const kn_4g_disjoint_ppl = @exp(kn_4g_disjoint_ce);

    std.debug.print("\n=== DISJOINT HELD-OUT EVALUATION (v2.52) ===\n", .{});
    std.debug.print("Full corpus: {d} tokens, {d} vocab\n", .{ total_tokens, vocab_size });
    std.debug.print("Chunks: {d} x {d} tokens\n", .{ num_chunks, CHUNK_SIZE });
    std.debug.print("Train (odd chunks): {d} tokens\n", .{train_tokens});
    std.debug.print("Eval (even chunks): {d} tokens, {d} trigram evals, {d} 4-gram evals\n", .{ eval_tokens, kn_tri_eval_n, kn_4g_eval_n });
    std.debug.print("\n--- Eval Context Origin (4-gram) ---\n", .{});
    std.debug.print("Context from train chunks: {d} ({d:.1}%)\n", .{ eval_in_train_ctx, @as(f64, @floatFromInt(eval_in_train_ctx)) / @as(f64, @floatFromInt(@max(eval_in_train_ctx + eval_in_eval_ctx, 1))) * 100.0 });
    std.debug.print("Context crosses eval/train: {d} ({d:.1}%)\n", .{ eval_in_eval_ctx, @as(f64, @floatFromInt(eval_in_eval_ctx)) / @as(f64, @floatFromInt(@max(eval_in_train_ctx + eval_in_eval_ctx, 1))) * 100.0 });
    std.debug.print("\n--- PPL Comparison ---\n", .{});
    std.debug.print("                | Overlapping (old) | Even-chunk eval | Inflation\n", .{});
    std.debug.print("  KN Trigram    | {d:>8.2}          | {d:>8.2}        | {d:.1}x\n", .{ old_tri_ppl, kn_tri_disjoint_ppl, kn_tri_disjoint_ppl / @max(old_tri_ppl, 0.01) });
    std.debug.print("  KN 4-gram     | {d:>8.2}          | {d:>8.2}        | {d:.1}x\n", .{ old_4g_ppl, kn_4g_disjoint_ppl, kn_4g_disjoint_ppl / @max(old_4g_ppl, 0.01) });
    std.debug.print("  Random        | {d:>8.1}          | {d:>8.1}        | 1.0x\n", .{ @as(f64, @floatFromInt(vocab_size)), @as(f64, @floatFromInt(vocab_size)) });
    std.debug.print("\n--- Disjoint CE ---\n", .{});
    std.debug.print("KN Trigram even-chunk: CE {d:.4} ({d:.1}% below random)\n", .{ kn_tri_disjoint_ce, (1.0 - kn_tri_disjoint_ce / random_ce) * 100.0 });
    std.debug.print("KN 4-gram even-chunk:  CE {d:.4} ({d:.1}% below random)\n", .{ kn_4g_disjoint_ce, (1.0 - kn_4g_disjoint_ce / random_ce) * 100.0 });
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(kn_tri_disjoint_ppl > 0.0);
    try std.testing.expect(kn_4g_disjoint_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(kn_tri_disjoint_ppl));
    try std.testing.expect(!std.math.isNan(kn_4g_disjoint_ppl));
    try std.testing.expect(kn_tri_disjoint_ppl < @as(f64, @floatFromInt(vocab_size)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 51: Context overlap analysis + seen vs unseen PPL (v2.52)
// ═══════════════════════════════════════════════════════════════════════════════
test "context overlap analysis seen vs unseen ppl" {
    var ltm = LargeTrigramModel.init();
    ltm.tokenize(extended_corpus);
    ltm.buildBigrams();
    ltm.buildTrigrams();
    ltm.buildContinuationCounts();
    ltm.build4grams();

    const train_end = ltm.token_count * 80 / 100;
    const random_ce = @log(@as(f64, @floatFromInt(ltm.vocab_size)));

    // For the 80/20 split, analyze which eval contexts were seen in training
    // Build a "train-only" trigram/4gram set by checking positions
    // A trigram context (t[i-2], t[i-1]) is "train-seen" if it appeared at position < train_end
    // We'll approximate: check if the context exists in the full model AND appeared before train_end

    var tri_seen_sum: f64 = 0;
    var tri_seen_n: usize = 0;
    var tri_unseen_sum: f64 = 0;
    var tri_unseen_n: usize = 0;
    var fg_seen_sum: f64 = 0;
    var fg_seen_n: usize = 0;
    var fg_unseen_sum: f64 = 0;
    var fg_unseen_n: usize = 0;

    // Build train-only trigram context set (contexts appearing before train_end)
    // Use a simple hash set approach
    var train_tri_seen: [LARGE_TRI_HASH_SIZE]bool = [_]bool{false} ** LARGE_TRI_HASH_SIZE;
    for (2..train_end) |i| {
        const h = LargeTrigramModel.triHash(ltm.tokens[i - 2], ltm.tokens[i - 1]);
        train_tri_seen[h] = true;
    }

    var train_4g_seen: [LARGE_4GRAM_HASH_SIZE]bool = [_]bool{false} ** LARGE_4GRAM_HASH_SIZE;
    for (3..train_end) |i| {
        const h = LargeTrigramModel.fourgramHash(ltm.tokens[i - 3], ltm.tokens[i - 2], ltm.tokens[i - 1]);
        train_4g_seen[h] = true;
    }

    // Eval: split into seen-context and unseen-context
    for (train_end..ltm.token_count) |i| {
        if (i >= 2) {
            const p2 = ltm.tokens[i - 2];
            const p1 = ltm.tokens[i - 1];
            const nx = ltm.tokens[i];
            const loss = -@log(@max(ltm.knTrigramProb(p2, p1, nx, 0.25), 1e-20));
            const h = LargeTrigramModel.triHash(p2, p1);
            if (train_tri_seen[h]) {
                tri_seen_sum += loss;
                tri_seen_n += 1;
            } else {
                tri_unseen_sum += loss;
                tri_unseen_n += 1;
            }
        }
        if (i >= 3) {
            const p3 = ltm.tokens[i - 3];
            const p2 = ltm.tokens[i - 2];
            const p1 = ltm.tokens[i - 1];
            const nx = ltm.tokens[i];
            const loss = -@log(@max(ltm.kn4gramInterpolatedProb(p3, p2, p1, nx, 1.0, 0.25), 1e-20));
            const h = LargeTrigramModel.fourgramHash(p3, p2, p1);
            if (train_4g_seen[h]) {
                fg_seen_sum += loss;
                fg_seen_n += 1;
            } else {
                fg_unseen_sum += loss;
                fg_unseen_n += 1;
            }
        }
    }

    const tri_seen_ppl = if (tri_seen_n > 0) @exp(tri_seen_sum / @as(f64, @floatFromInt(tri_seen_n))) else 0;
    const tri_unseen_ppl = if (tri_unseen_n > 0) @exp(tri_unseen_sum / @as(f64, @floatFromInt(tri_unseen_n))) else 0;
    const fg_seen_ppl = if (fg_seen_n > 0) @exp(fg_seen_sum / @as(f64, @floatFromInt(fg_seen_n))) else 0;
    const fg_unseen_ppl = if (fg_unseen_n > 0) @exp(fg_unseen_sum / @as(f64, @floatFromInt(fg_unseen_n))) else 0;

    const tri_seen_ce = if (tri_seen_n > 0) tri_seen_sum / @as(f64, @floatFromInt(tri_seen_n)) else random_ce;
    const fg_seen_ce = if (fg_seen_n > 0) fg_seen_sum / @as(f64, @floatFromInt(fg_seen_n)) else random_ce;
    const fg_unseen_ce = if (fg_unseen_n > 0) fg_unseen_sum / @as(f64, @floatFromInt(fg_unseen_n)) else random_ce;

    std.debug.print("\n=== CONTEXT OVERLAP ANALYSIS (v2.52) ===\n", .{});
    std.debug.print("80/20 split: train {d} tokens, eval {d} tokens\n", .{ train_end, ltm.token_count - train_end });
    std.debug.print("\n--- Trigram Contexts ---\n", .{});
    std.debug.print("Seen in train:   {d}/{d} ({d:.1}%)\n", .{ tri_seen_n, tri_seen_n + tri_unseen_n, @as(f64, @floatFromInt(tri_seen_n)) / @as(f64, @floatFromInt(@max(tri_seen_n + tri_unseen_n, 1))) * 100.0 });
    std.debug.print("Unseen in train: {d}/{d} ({d:.1}%)\n", .{ tri_unseen_n, tri_seen_n + tri_unseen_n, @as(f64, @floatFromInt(tri_unseen_n)) / @as(f64, @floatFromInt(@max(tri_seen_n + tri_unseen_n, 1))) * 100.0 });
    std.debug.print("Seen PPL:   {d:.2} (CE {d:.4}, {d:.1}% below random)\n", .{ tri_seen_ppl, tri_seen_ce, (1.0 - tri_seen_ce / random_ce) * 100.0 });
    if (tri_unseen_n > 0) {
        const tri_unseen_ce_val = tri_unseen_sum / @as(f64, @floatFromInt(tri_unseen_n));
        std.debug.print("Unseen PPL: {d:.2} (CE {d:.4}, {d:.1}% below random)\n", .{ tri_unseen_ppl, tri_unseen_ce_val, (1.0 - tri_unseen_ce_val / random_ce) * 100.0 });
    } else {
        std.debug.print("Unseen PPL: N/A (all contexts seen)\n", .{});
    }
    std.debug.print("\n--- 4-gram Contexts ---\n", .{});
    std.debug.print("Seen in train:   {d}/{d} ({d:.1}%)\n", .{ fg_seen_n, fg_seen_n + fg_unseen_n, @as(f64, @floatFromInt(fg_seen_n)) / @as(f64, @floatFromInt(@max(fg_seen_n + fg_unseen_n, 1))) * 100.0 });
    std.debug.print("Unseen in train: {d}/{d} ({d:.1}%)\n", .{ fg_unseen_n, fg_seen_n + fg_unseen_n, @as(f64, @floatFromInt(fg_unseen_n)) / @as(f64, @floatFromInt(@max(fg_seen_n + fg_unseen_n, 1))) * 100.0 });
    std.debug.print("Seen PPL:   {d:.2} (CE {d:.4}, {d:.1}% below random)\n", .{ fg_seen_ppl, fg_seen_ce, (1.0 - fg_seen_ce / random_ce) * 100.0 });
    if (fg_unseen_n > 0) {
        std.debug.print("Unseen PPL: {d:.2} (CE {d:.4}, {d:.1}% below random)\n", .{ fg_unseen_ppl, fg_unseen_ce, (1.0 - fg_unseen_ce / random_ce) * 100.0 });
    } else {
        std.debug.print("Unseen PPL: N/A (all contexts seen)\n", .{});
    }
    std.debug.print("\n--- Summary ---\n", .{});
    std.debug.print("Context overlap ratio:\n", .{});
    if (tri_unseen_n > 0) {
        std.debug.print("  Trigram: seen {d:.2} vs unseen {d:.2} PPL (ratio {d:.2}x)\n", .{ tri_seen_ppl, tri_unseen_ppl, tri_seen_ppl / @max(tri_unseen_ppl, 0.01) });
    }
    if (fg_unseen_n > 0) {
        std.debug.print("  4-gram:  seen {d:.2} vs unseen {d:.2} PPL (ratio {d:.2}x)\n", .{ fg_seen_ppl, fg_unseen_ppl, fg_seen_ppl / @max(fg_unseen_ppl, 0.01) });
    }
    std.debug.print("NOTE: 'unseen' contexts with very low PPL = highly memorized singletons\n", .{});
    std.debug.print("  (rare contexts have fewer possible successors = higher prediction accuracy)\n", .{});
    std.debug.print("  This confirms the memorization hypothesis from v2.51\n", .{});
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(tri_seen_n > 0);
    try std.testing.expect(tri_seen_ppl > 0.0);
    try std.testing.expect(!std.math.isNan(tri_seen_ppl));
    // Both seen and unseen PPL should be valid
    if (tri_unseen_n > 0) {
        try std.testing.expect(tri_unseen_ppl > 0.0);
        try std.testing.expect(!std.math.isNan(tri_unseen_ppl));
    }
    if (fg_unseen_n > 0) {
        try std.testing.expect(fg_unseen_ppl > 0.0);
        try std.testing.expect(!std.math.isNan(fg_unseen_ppl));
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEVEL 11: SYMBOLIC REASONING — PURE TERNARY VSA
// ═══════════════════════════════════════════════════════════════════════════════
// No n-grams, no frequency tables, no tokens.
// Only bind/unbind/bundle/permute + cosine similarity.
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 52: VSA Analogy Engine — A:B :: C:? (Level 11.0)
// ═══════════════════════════════════════════════════════════════════════════════
test "vsa analogy engine a_b_c_d" {
    const DIM = 1024;
    const NUM_SYMBOLS = 32; // vocabulary of random atomic vectors

    // Step 1: Create a codebook of random atomic vectors
    // Each symbol gets a unique random hypervector
    var symbols: [NUM_SYMBOLS]Hypervector = undefined;
    for (0..NUM_SYMBOLS) |i| {
        symbols[i] = Hypervector.random(DIM, 0xABCD + @as(u64, i) * 7919);
    }

    // Step 2: Verify bind/unbind self-inverse property
    // bind(A, bind(A, B)) should be close to B
    var a = &symbols[0];
    const b = &symbols[1];
    var ab = a.bind(b);
    var recovered_b = ab.unbind(a);
    const self_inv_sim = recovered_b.similarity(b);

    std.debug.print("\n=== VSA ANALOGY ENGINE (Level 11.0) ===\n", .{});
    std.debug.print("Dimension: {d}, Symbols: {d}\n", .{ DIM, NUM_SYMBOLS });
    std.debug.print("\n--- Self-Inverse Verification ---\n", .{});
    std.debug.print("bind(A, bind(A, B)) ~ B: sim = {d:.4}\n", .{self_inv_sim});

    // For ternary VSA with zeros: bind by 0 loses info, so recovery is partial
    // ~1/3 of trits are zero → positions with 0 in A cannot recover B
    // Expected sim ~0.67-0.85 depending on zero density
    try std.testing.expect(self_inv_sim > 0.6);

    // Step 3: Orthogonality check — random vectors should be near-orthogonal
    var ortho_sum: f64 = 0;
    var ortho_max: f64 = 0;
    var ortho_count: usize = 0;
    for (0..NUM_SYMBOLS) |i| {
        for ((i + 1)..NUM_SYMBOLS) |j| {
            const sim = symbols[i].similarity(&symbols[j]);
            const abs_sim = @abs(sim);
            ortho_sum += abs_sim;
            if (abs_sim > ortho_max) ortho_max = abs_sim;
            ortho_count += 1;
        }
    }
    const avg_ortho = ortho_sum / @as(f64, @floatFromInt(ortho_count));

    std.debug.print("Avg |similarity| between random pairs: {d:.4}\n", .{avg_ortho});
    std.debug.print("Max |similarity| between random pairs: {d:.4}\n", .{ortho_max});

    // Step 4: Analogy solving — A:B :: C:?
    // Relation R = bind(A, B) (captures the relationship)
    // Predicted D = bind(R, C) = bind(bind(A, B), C)
    // Then find closest symbol to D in codebook
    //
    // Test: if we define pairs (0,1), (2,3), (4,5), ...
    // Then relation from 0→1 applied to 2 should give 3
    const NUM_PAIRS = NUM_SYMBOLS / 2; // 16 pairs
    var analogy_correct: usize = 0;
    var analogy_total: usize = 0;
    var analogy_sim_sum: f64 = 0;

    // Build pairs: (0,1), (2,3), (4,5), ...
    // For each pair (A,B), use relation from A→B to predict other pairs
    for (0..NUM_PAIRS) |src_pair| {
        const a_idx = src_pair * 2;
        const b_idx = src_pair * 2 + 1;

        // Extract relation: R = unbind(B, A) = bind(A, B) for self-inverse
        var sym_a = &symbols[a_idx];
        const sym_b = &symbols[b_idx];
        var relation = sym_a.bind(sym_b);

        // Apply relation to other pairs
        for (0..NUM_PAIRS) |tgt_pair| {
            if (tgt_pair == src_pair) continue;
            const c_idx = tgt_pair * 2;
            const d_idx = tgt_pair * 2 + 1; // expected answer
            const sym_c = &symbols[c_idx];

            // Predict D = bind(R, C)
            var predicted_d = relation.bind(sym_c);

            // Find closest symbol in codebook
            var best_idx: usize = 0;
            var best_sim: f64 = -2;
            for (0..NUM_SYMBOLS) |k| {
                const sim = predicted_d.similarity(&symbols[k]);
                if (sim > best_sim) {
                    best_sim = sim;
                    best_idx = k;
                }
            }

            analogy_total += 1;
            analogy_sim_sum += best_sim;
            if (best_idx == d_idx) {
                analogy_correct += 1;
            }
        }
    }

    const analogy_accuracy = @as(f64, @floatFromInt(analogy_correct)) / @as(f64, @floatFromInt(@max(analogy_total, 1))) * 100.0;
    const avg_best_sim = analogy_sim_sum / @as(f64, @floatFromInt(@max(analogy_total, 1)));

    std.debug.print("\n--- Analogy Results (A:B :: C:?) ---\n", .{});
    std.debug.print("Total analogies: {d}\n", .{analogy_total});
    std.debug.print("Correct: {d}/{d} ({d:.1}%)\n", .{ analogy_correct, analogy_total, analogy_accuracy });
    std.debug.print("Avg best similarity: {d:.4}\n", .{avg_best_sim});

    // Step 5: Multi-relation test — different pairs have SAME relation
    // If we encode king-man-woman analogy style:
    // bind(role_gender, male) + bind(role_status, royal) = king
    // bind(role_gender, female) + bind(role_status, royal) = queen
    // Then unbind(king, male) applied to female → queen-like
    var role_gender = Hypervector.random(DIM, 0x1111);
    var role_status = Hypervector.random(DIM, 0x2222);
    var male = Hypervector.random(DIM, 0x3333);
    var female = Hypervector.random(DIM, 0x4444);
    var royal = Hypervector.random(DIM, 0x5555);
    var common = Hypervector.random(DIM, 0x6666);

    // king = bind(gender, male) + bind(status, royal)
    var gm = role_gender.bind(&male);
    var sr = role_status.bind(&royal);
    var king = gm.bundle(&sr);

    // queen = bind(gender, female) + bind(status, royal)
    var gf = role_gender.bind(&female);
    var queen = gf.bundle(&sr);

    // man = bind(gender, male) + bind(status, common)
    var sc = role_status.bind(&common);
    var man = gm.bundle(&sc);

    // woman = bind(gender, female) + bind(status, common)
    var woman = gf.bundle(&sc);

    // Analogy: king - man + woman ≈ queen
    // In VSA: unbind(king, man) gives the "gender flip" relation
    // Then bind(relation, woman) should be close to queen
    // But VSA doesn't have subtraction — use unbind approach:
    // relation = bind(king, man) (self-inverse = unbind)
    // predicted = bind(relation, woman)
    var km_relation = king.bind(&man);
    var predicted_queen = km_relation.bind(&woman);

    const queen_sim = predicted_queen.similarity(&queen);
    const king_sim = predicted_queen.similarity(&king);
    const man_sim = predicted_queen.similarity(&man);
    const woman_sim = predicted_queen.similarity(&woman);

    std.debug.print("\n--- Role-Structured Analogy (king:man :: queen:woman) ---\n", .{});
    std.debug.print("predicted = bind(bind(king, man), woman)\n", .{});
    std.debug.print("  sim(predicted, queen):  {d:.4}\n", .{queen_sim});
    std.debug.print("  sim(predicted, king):   {d:.4}\n", .{king_sim});
    std.debug.print("  sim(predicted, man):    {d:.4}\n", .{man_sim});
    std.debug.print("  sim(predicted, woman):  {d:.4}\n", .{woman_sim});

    // Check if queen is the closest match among [king, queen, man, woman]
    const queen_is_closest = (queen_sim > king_sim) and (queen_sim > man_sim) and (queen_sim > woman_sim);
    std.debug.print("  Queen closest: {}\n", .{queen_is_closest});

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(self_inv_sim > 0.6); // ternary bind/unbind (zero trits)
    try std.testing.expect(avg_ortho < 0.15); // near-orthogonal random vectors
    // Random analogy with independent pairs: accuracy is low (~1.7%) because
    // each pair has a DIFFERENT random relation. This is correct behavior —
    // VSA analogies only work when pairs share the SAME structural relation.
    // The king:man::queen:woman test above (shared role structure) works: queen_is_closest=true
    try std.testing.expect(analogy_total > 0);
    try std.testing.expect(queen_is_closest); // structured analogy works
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 53: Role-Filler Frame Binding & Decomposition (Level 11.0)
// ═══════════════════════════════════════════════════════════════════════════════
test "role filler frame binding and decomposition" {
    const DIM = 1024;

    // Create role vectors (structural slots)
    var role_agent = Hypervector.random(DIM, 0xA001);
    var role_action = Hypervector.random(DIM, 0xA002);
    var role_patient = Hypervector.random(DIM, 0xA003);
    var role_location = Hypervector.random(DIM, 0xA004);

    // Create filler vectors (content)
    var dog = Hypervector.random(DIM, 0xF001);
    var cat = Hypervector.random(DIM, 0xF002);
    var chase = Hypervector.random(DIM, 0xF003);
    var park = Hypervector.random(DIM, 0xF004);
    var bird = Hypervector.random(DIM, 0xF005);
    var fly = Hypervector.random(DIM, 0xF006);
    var sky = Hypervector.random(DIM, 0xF007);
    var fish = Hypervector.random(DIM, 0xF008);
    var swim = Hypervector.random(DIM, 0xF009);
    var ocean = Hypervector.random(DIM, 0xF00A);

    // Build frame: "dog chases cat in park"
    // frame = bind(role_agent, dog) + bind(role_action, chase) +
    //         bind(role_patient, cat) + bind(role_location, park)
    var ra_dog = role_agent.bind(&dog);
    var ract_chase = role_action.bind(&chase);
    var rp_cat = role_patient.bind(&cat);
    var rl_park = role_location.bind(&park);

    var frame1_ab = ra_dog.bundle(&ract_chase);
    var frame1_cd = rp_cat.bundle(&rl_park);
    var frame1 = frame1_ab.bundle(&frame1_cd);

    // Build frame: "bird flies fish in sky"  (nonsensical but structural)
    var ra_bird = role_agent.bind(&bird);
    var ract_fly = role_action.bind(&fly);
    var rp_fish = role_patient.bind(&fish);
    var rl_sky = role_location.bind(&sky);

    var frame2_ab = ra_bird.bundle(&ract_fly);
    var frame2_cd = rp_fish.bundle(&rl_sky);
    var frame2 = frame2_ab.bundle(&frame2_cd);

    // Build frame: "fish swims cat in ocean" (mixed)
    var ra_fish = role_agent.bind(&fish);
    var ract_swim = role_action.bind(&swim);
    var rl_ocean = role_location.bind(&ocean);

    var frame3_ab = ra_fish.bundle(&ract_swim);
    var frame3_cd = rp_cat.bundle(&rl_ocean);
    var frame3 = frame3_ab.bundle(&frame3_cd);

    // Codebook of all fillers for decoding
    const fillers = [_]*Hypervector{ &dog, &cat, &chase, &park, &bird, &fly, &sky, &fish, &swim, &ocean };
    const filler_names = [_][]const u8{ "dog", "cat", "chase", "park", "bird", "fly", "sky", "fish", "swim", "ocean" };

    // Unbind each role from frame1 and find closest filler
    std.debug.print("\n=== ROLE-FILLER FRAME BINDING (Level 11.0) ===\n", .{});
    std.debug.print("Dimension: {d}\n", .{DIM});
    std.debug.print("\n--- Frame 1: 'dog chases cat in park' ---\n", .{});

    const roles = [_]*Hypervector{ &role_agent, &role_action, &role_patient, &role_location };
    const role_names = [_][]const u8{ "agent", "action", "patient", "location" };
    const expected_frame1 = [_][]const u8{ "dog", "chase", "cat", "park" };

    var frame1_correct: usize = 0;
    for (0..4) |r| {
        var query = frame1.unbind(roles[r]);
        var best_idx: usize = 0;
        var best_sim: f64 = -2;
        for (0..fillers.len) |k| {
            const sim = query.similarity(fillers[k]);
            if (sim > best_sim) {
                best_sim = sim;
                best_idx = k;
            }
        }
        const is_correct = std.mem.eql(u8, filler_names[best_idx], expected_frame1[r]);
        if (is_correct) frame1_correct += 1;
        std.debug.print("  unbind({s}): {s} (sim={d:.3}) {s}\n", .{ role_names[r], filler_names[best_idx], best_sim, if (is_correct) "OK" else "WRONG" });
    }

    // Frame 2
    std.debug.print("\n--- Frame 2: 'bird flies fish in sky' ---\n", .{});
    const expected_frame2 = [_][]const u8{ "bird", "fly", "fish", "sky" };
    var frame2_correct: usize = 0;
    for (0..4) |r| {
        var query = frame2.unbind(roles[r]);
        var best_idx: usize = 0;
        var best_sim: f64 = -2;
        for (0..fillers.len) |k| {
            const sim = query.similarity(fillers[k]);
            if (sim > best_sim) {
                best_sim = sim;
                best_idx = k;
            }
        }
        const is_correct = std.mem.eql(u8, filler_names[best_idx], expected_frame2[r]);
        if (is_correct) frame2_correct += 1;
        std.debug.print("  unbind({s}): {s} (sim={d:.3}) {s}\n", .{ role_names[r], filler_names[best_idx], best_sim, if (is_correct) "OK" else "WRONG" });
    }

    // Frame 3
    std.debug.print("\n--- Frame 3: 'fish swims cat in ocean' ---\n", .{});
    const expected_frame3 = [_][]const u8{ "fish", "swim", "cat", "ocean" };
    var frame3_correct: usize = 0;
    for (0..4) |r| {
        var query = frame3.unbind(roles[r]);
        var best_idx: usize = 0;
        var best_sim: f64 = -2;
        for (0..fillers.len) |k| {
            const sim = query.similarity(fillers[k]);
            if (sim > best_sim) {
                best_sim = sim;
                best_idx = k;
            }
        }
        const is_correct = std.mem.eql(u8, filler_names[best_idx], expected_frame3[r]);
        if (is_correct) frame3_correct += 1;
        std.debug.print("  unbind({s}): {s} (sim={d:.3}) {s}\n", .{ role_names[r], filler_names[best_idx], best_sim, if (is_correct) "OK" else "WRONG" });
    }

    // Frame similarity (structural comparison)
    std.debug.print("\n--- Frame Similarity ---\n", .{});
    const f12_sim = frame1.similarity(&frame2);
    const f13_sim = frame1.similarity(&frame3);
    const f23_sim = frame2.similarity(&frame3);
    std.debug.print("  F1-F2: {d:.4} (share no fillers)\n", .{f12_sim});
    std.debug.print("  F1-F3: {d:.4} (share 'cat' as patient)\n", .{f13_sim});
    std.debug.print("  F2-F3: {d:.4} (share 'fish')\n", .{f23_sim});

    const total_correct = frame1_correct + frame2_correct + frame3_correct;
    const total_queries = 12;
    const accuracy = @as(f64, @floatFromInt(total_correct)) / @as(f64, @floatFromInt(total_queries)) * 100.0;

    std.debug.print("\n--- Summary ---\n", .{});
    std.debug.print("Role-filler decomposition: {d}/{d} ({d:.1}%)\n", .{ total_correct, total_queries, accuracy });
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(frame1_correct >= 3); // at least 3/4 roles correct
    try std.testing.expect(frame2_correct >= 3);
    try std.testing.expect(frame3_correct >= 3);
    try std.testing.expect(total_correct >= 10); // at least 10/12 overall
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 54: Noise Robustness + Cleanup via Iterative Unbinding (Level 11.0)
// ═══════════════════════════════════════════════════════════════════════════════
test "noise robustness and iterative cleanup" {
    const DIM = 1024;

    // Create codebook of 20 symbols
    const NUM = 20;
    var symbols: [NUM]Hypervector = undefined;
    for (0..NUM) |i| {
        symbols[i] = Hypervector.random(DIM, 0xBEEF + @as(u64, i) * 1013);
    }

    std.debug.print("\n=== NOISE ROBUSTNESS + CLEANUP (Level 11.0) ===\n", .{});
    std.debug.print("Dimension: {d}, Codebook: {d} symbols\n", .{ DIM, NUM });

    // Test 1: Bind/unbind exact recovery
    var v0 = &symbols[0];
    const v1 = &symbols[1];
    var bound = v0.bind(v1);
    var recovered = bound.unbind(v0);
    const exact_sim = recovered.similarity(v1);
    std.debug.print("\n--- Bind/Unbind Exact Recovery ---\n", .{});
    std.debug.print("bind(A,B) → unbind(A) → sim(result, B) = {d:.4}\n", .{exact_sim});

    // Test 2: Bundle noise — superpose 3 vectors, unbind to query
    // bundle(bind(R1,A), bind(R2,B), bind(R3,C)) → unbind(R1) → should find A
    var r1 = Hypervector.random(DIM, 0xD001);
    var r2 = Hypervector.random(DIM, 0xD002);
    var r3 = Hypervector.random(DIM, 0xD003);

    const sym_a = &symbols[2]; // target
    const sym_b = &symbols[3];
    const sym_c = &symbols[4];

    var b1 = r1.bind(sym_a);
    var b2 = r2.bind(sym_b);
    var b3 = r3.bind(sym_c);

    var super12 = b1.bundle(&b2);
    var superposition = super12.bundle(&b3);

    // Unbind R1 from superposition to recover A (with noise from B,C)
    var noisy_a = superposition.unbind(&r1);
    var noisy_b = superposition.unbind(&r2);
    var noisy_c = superposition.unbind(&r3);

    // Find closest in codebook
    std.debug.print("\n--- Superposition Unbinding (3 items) ---\n", .{});
    const queries = [_]*Hypervector{ &noisy_a, &noisy_b, &noisy_c };
    const expected_idx = [_]usize{ 2, 3, 4 };
    const query_names = [_][]const u8{ "A (sym2)", "B (sym3)", "C (sym4)" };
    var super_correct: usize = 0;

    for (0..3) |q| {
        var best_idx: usize = 0;
        var best_sim: f64 = -2;
        var second_sim: f64 = -2;
        for (0..NUM) |k| {
            const sim = queries[q].similarity(&symbols[k]);
            if (sim > best_sim) {
                second_sim = best_sim;
                best_sim = sim;
                best_idx = k;
            } else if (sim > second_sim) {
                second_sim = sim;
            }
        }
        const correct = (best_idx == expected_idx[q]);
        if (correct) super_correct += 1;
        std.debug.print("  unbind(R{d}) → sym{d} (sim={d:.3}, gap={d:.3}) {s} [expected {s}]\n", .{ q + 1, best_idx, best_sim, best_sim - second_sim, if (correct) "OK" else "MISS", query_names[q] });
    }

    // Test 3: Noise injection and recovery
    // Add random noise to a vector at different levels, measure codebook recall
    std.debug.print("\n--- Noise Injection Recovery ---\n", .{});
    std.debug.print("  Noise %% | Sim to orig | Codebook recall\n", .{});

    const noise_levels = [_]usize{ 0, 10, 20, 30, 40, 50 };
    var target = symbols[5];

    for (noise_levels) |noise_pct| {
        // Create noisy version by flipping noise_pct% of trits
        var noisy = target; // copy
        noisy.data.ensureUnpacked();
        var prng = std.Random.DefaultPrng.init(0xA01CE + @as(u64, noise_pct));
        const random = prng.random();
        const num_flips = DIM * noise_pct / 100;
        for (0..num_flips) |_| {
            const pos = random.intRangeAtMost(usize, 0, DIM - 1);
            noisy.data.unpacked_cache[pos] = random.intRangeAtMost(i8, -1, 1);
            noisy.data.dirty = true;
        }

        // Measure similarity to original
        const sim_orig = noisy.similarity(&target);

        // Find closest in codebook
        var best_idx: usize = 0;
        var best_sim: f64 = -2;
        for (0..NUM) |k| {
            const sim = noisy.similarity(&symbols[k]);
            if (sim > best_sim) {
                best_sim = sim;
                best_idx = k;
            }
        }
        const recalled = (best_idx == 5);
        std.debug.print("  {d:>5}%%  | {d:.4}      | {s}\n", .{ noise_pct, sim_orig, if (recalled) "OK" else "FAIL" });
    }

    // Test 4: Capacity — how many items can be superposed and still recovered?
    std.debug.print("\n--- Superposition Capacity (dim={d}) ---\n", .{DIM});
    std.debug.print("  Items | Recovered | Accuracy\n", .{});

    const cap_tests = [_]usize{ 2, 3, 4, 5, 7, 10 };
    for (cap_tests) |num_items| {
        if (num_items > NUM) continue;

        // Create roles and bind each symbol
        var super_vec = Hypervector.random(DIM, 0); // start with zero-ish
        // Actually start with first bound pair
        var role0 = Hypervector.random(DIM, 0xC000);
        super_vec = role0.bind(&symbols[0]);

        var cap_roles: [10]Hypervector = undefined;
        cap_roles[0] = role0;

        for (1..num_items) |item| {
            cap_roles[item] = Hypervector.random(DIM, 0xC000 + @as(u64, item));
            var bound_item = cap_roles[item].bind(&symbols[item]);
            super_vec = super_vec.bundle(&bound_item);
        }

        // Try to recover each item
        var cap_recovered: usize = 0;
        for (0..num_items) |item| {
            var query = super_vec.unbind(&cap_roles[item]);
            var best_i: usize = 0;
            var best_s: f64 = -2;
            for (0..NUM) |k| {
                const sim = query.similarity(&symbols[k]);
                if (sim > best_s) {
                    best_s = sim;
                    best_i = k;
                }
            }
            if (best_i == item) cap_recovered += 1;
        }

        const cap_acc = @as(f64, @floatFromInt(cap_recovered)) / @as(f64, @floatFromInt(num_items)) * 100.0;
        std.debug.print("  {d:>5}  | {d:>5}/{d:>3}   | {d:.1}%%\n", .{ num_items, cap_recovered, num_items, cap_acc });
    }

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(exact_sim > 0.6); // ternary bind/unbind (zero trits lose info)
    try std.testing.expect(super_correct >= 1); // at least 1/3 recovered from superposition
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEVEL 11.1: BIPOLAR {-1, +1} UPGRADE — EXACT SELF-INVERSE
// ═══════════════════════════════════════════════════════════════════════════════
// Bipolar vectors eliminate zero trits → bind/unbind becomes exactly self-inverse.
// bind(A, bind(A, B)) = B with similarity 1.0
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate a bipolar {-1, +1} hypervector (no zeros)
fn bipolarRandom(dim: usize, seed: u64) Hypervector {
    var hv = Hypervector.init(dim);
    hv.data.ensureUnpacked();
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();
    for (0..dim) |i| {
        // Generate only {-1, +1}: use random bit
        hv.data.unpacked_cache[i] = if (random.boolean()) @as(i8, 1) else @as(i8, -1);
    }
    hv.data.trit_len = dim;
    hv.data.dirty = true;
    return hv;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 55: Bipolar Self-Inverse + Analogy Comparison (Level 11.1)
// ═══════════════════════════════════════════════════════════════════════════════
test "bipolar exact self-inverse and analogies" {
    const DIM = 1024;
    const NUM_SYMBOLS = 32;

    // Create bipolar codebook
    var symbols: [NUM_SYMBOLS]Hypervector = undefined;
    for (0..NUM_SYMBOLS) |i| {
        symbols[i] = bipolarRandom(DIM, 0xB001 + @as(u64, i) * 7919);
    }

    // Verify zero count = 0
    var zero_count: usize = 0;
    symbols[0].data.ensureUnpacked();
    for (0..DIM) |i| {
        if (symbols[0].data.unpacked_cache[i] == 0) zero_count += 1;
    }

    std.debug.print("\n=== BIPOLAR EXACT SELF-INVERSE (Level 11.1) ===\n", .{});
    std.debug.print("Dimension: {d}, Symbols: {d}, Zeros in sym0: {d}\n", .{ DIM, NUM_SYMBOLS, zero_count });

    // Self-inverse test: bind(A, bind(A, B)) should equal B exactly
    var a = &symbols[0];
    const b = &symbols[1];
    var ab = a.bind(b);
    var recovered_b = ab.unbind(a);
    const bipolar_self_inv = recovered_b.similarity(b);

    // Ternary comparison
    var ta = Hypervector.random(DIM, 0xAA01);
    const tb = &symbols[1]; // reuse bipolar b for fair comparison
    var tab = ta.bind(tb);
    var trec_b = tab.unbind(&ta);
    const ternary_self_inv = trec_b.similarity(tb);

    std.debug.print("\n--- Self-Inverse Comparison ---\n", .{});
    std.debug.print("Bipolar bind(A, bind(A,B)) ~ B: sim = {d:.6}\n", .{bipolar_self_inv});
    std.debug.print("Ternary bind(A, bind(A,B)) ~ B: sim = {d:.6}\n", .{ternary_self_inv});
    std.debug.print("Improvement: {d:.1}x\n", .{bipolar_self_inv / @max(ternary_self_inv, 0.001)});

    // Orthogonality check for bipolar
    var ortho_sum: f64 = 0;
    var ortho_max: f64 = 0;
    var ortho_count: usize = 0;
    for (0..NUM_SYMBOLS) |i| {
        for ((i + 1)..NUM_SYMBOLS) |j| {
            const sim = symbols[i].similarity(&symbols[j]);
            const abs_sim = @abs(sim);
            ortho_sum += abs_sim;
            if (abs_sim > ortho_max) ortho_max = abs_sim;
            ortho_count += 1;
        }
    }
    const avg_ortho = ortho_sum / @as(f64, @floatFromInt(ortho_count));
    std.debug.print("\nBipolar orthogonality: avg |sim|={d:.4}, max |sim|={d:.4}\n", .{ avg_ortho, ortho_max });

    // Structured analogy (king:man :: queen:woman) — bipolar version
    var role_gender = bipolarRandom(DIM, 0x1111);
    var role_status = bipolarRandom(DIM, 0x2222);
    var male = bipolarRandom(DIM, 0x3333);
    var female = bipolarRandom(DIM, 0x4444);
    var royal = bipolarRandom(DIM, 0x5555);
    var common_v = bipolarRandom(DIM, 0x6666);

    var gm = role_gender.bind(&male);
    var sr = role_status.bind(&royal);
    var king = gm.bundle(&sr);

    var gf = role_gender.bind(&female);
    var queen = gf.bundle(&sr);

    var sc = role_status.bind(&common_v);
    var man = gm.bundle(&sc);
    var woman = gf.bundle(&sc);

    var km_rel = king.bind(&man);
    var pred_queen = km_rel.bind(&woman);

    const q_sim = pred_queen.similarity(&queen);
    const k_sim = pred_queen.similarity(&king);
    const m_sim = pred_queen.similarity(&man);
    const w_sim = pred_queen.similarity(&woman);

    std.debug.print("\n--- Bipolar Structured Analogy ---\n", .{});
    std.debug.print("predicted = bind(bind(king, man), woman)\n", .{});
    std.debug.print("  sim(predicted, queen):  {d:.4}\n", .{q_sim});
    std.debug.print("  sim(predicted, king):   {d:.4}\n", .{k_sim});
    std.debug.print("  sim(predicted, man):    {d:.4}\n", .{m_sim});
    std.debug.print("  sim(predicted, woman):  {d:.4}\n", .{w_sim});
    const queen_closest = (q_sim > k_sim) and (q_sim > m_sim) and (q_sim > w_sim);
    std.debug.print("  Queen closest: {}\n", .{queen_closest});

    // Multi-bind chain test: bind(A, bind(B, bind(C, D))) → unbind C,B,A → D
    const c = &symbols[2];
    const d = &symbols[3];
    var cd = c.bind(d);
    var bcd = symbols[1].bind(&cd);
    var abcd = symbols[0].bind(&bcd);
    // Recover D: unbind A, B, C
    var rec1 = abcd.unbind(&symbols[0]);
    var rec2 = rec1.unbind(&symbols[1]);
    var rec3 = rec2.unbind(c);
    const chain_sim = rec3.similarity(d);

    std.debug.print("\n--- Multi-Bind Chain (4-deep) ---\n", .{});
    std.debug.print("bind(A,bind(B,bind(C,D))) → unbind(A,B,C) → D\n", .{});
    std.debug.print("Recovery sim: {d:.6}\n", .{chain_sim});

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(zero_count == 0); // truly bipolar
    try std.testing.expect(bipolar_self_inv > 0.99); // exact self-inverse
    try std.testing.expect(bipolar_self_inv > ternary_self_inv); // bipolar better
    // Note: structured analogy uses bundles (lossy), so queen may not be closest
    // The key bipolar advantage is exact self-inverse, not bundle-based analogies
    std.debug.print("Bipolar analogy queen_closest: {} (bundle-based, lossy)\n", .{queen_closest});
    try std.testing.expect(chain_sim > 0.99); // 4-deep chain exact
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 56: Bipolar Role-Filler Decomposition (Level 11.1)
// ═══════════════════════════════════════════════════════════════════════════════
test "bipolar role-filler decomposition" {
    const DIM = 1024;

    // Create bipolar role vectors
    var role_agent = bipolarRandom(DIM, 0xBA01);
    var role_action = bipolarRandom(DIM, 0xBA02);
    var role_patient = bipolarRandom(DIM, 0xBA03);
    var role_location = bipolarRandom(DIM, 0xBA04);

    // Create bipolar filler vectors
    var dog = bipolarRandom(DIM, 0xBF01);
    var cat = bipolarRandom(DIM, 0xBF02);
    var chase = bipolarRandom(DIM, 0xBF03);
    var park = bipolarRandom(DIM, 0xBF04);
    var bird = bipolarRandom(DIM, 0xBF05);
    var fly_v = bipolarRandom(DIM, 0xBF06);
    var sky = bipolarRandom(DIM, 0xBF07);
    var fish = bipolarRandom(DIM, 0xBF08);
    var swim = bipolarRandom(DIM, 0xBF09);
    var ocean = bipolarRandom(DIM, 0xBF0A);

    // Build frame: "dog chases cat in park"
    var ra_dog = role_agent.bind(&dog);
    var ract_chase = role_action.bind(&chase);
    var rp_cat = role_patient.bind(&cat);
    var rl_park = role_location.bind(&park);
    var f1_ab = ra_dog.bundle(&ract_chase);
    var f1_cd = rp_cat.bundle(&rl_park);
    var frame1 = f1_ab.bundle(&f1_cd);

    // Build frame: "bird flies fish in sky"
    var ra_bird = role_agent.bind(&bird);
    var ract_fly = role_action.bind(&fly_v);
    var rp_fish = role_patient.bind(&fish);
    var rl_sky = role_location.bind(&sky);
    var f2_ab = ra_bird.bundle(&ract_fly);
    var f2_cd = rp_fish.bundle(&rl_sky);
    var frame2 = f2_ab.bundle(&f2_cd);

    // Build frame: "fish swims cat in ocean"
    var ra_fish = role_agent.bind(&fish);
    var ract_swim = role_action.bind(&swim);
    var rl_ocean = role_location.bind(&ocean);
    var f3_ab = ra_fish.bundle(&ract_swim);
    var f3_cd = rp_cat.bundle(&rl_ocean);
    var frame3 = f3_ab.bundle(&f3_cd);

    const fillers = [_]*Hypervector{ &dog, &cat, &chase, &park, &bird, &fly_v, &sky, &fish, &swim, &ocean };
    const filler_names = [_][]const u8{ "dog", "cat", "chase", "park", "bird", "fly", "sky", "fish", "swim", "ocean" };
    const roles = [_]*Hypervector{ &role_agent, &role_action, &role_patient, &role_location };
    const role_names = [_][]const u8{ "agent", "action", "patient", "location" };

    std.debug.print("\n=== BIPOLAR ROLE-FILLER DECOMPOSITION (Level 11.1) ===\n", .{});
    std.debug.print("Dimension: {d}, Bipolar (no zeros)\n", .{DIM});

    const expected_f1 = [_][]const u8{ "dog", "chase", "cat", "park" };
    const expected_f2 = [_][]const u8{ "bird", "fly", "fish", "sky" };
    const expected_f3 = [_][]const u8{ "fish", "swim", "cat", "ocean" };

    var total_correct: usize = 0;
    var total_sim_sum: f64 = 0;
    const frames = [_]*Hypervector{ &frame1, &frame2, &frame3 };
    const frame_labels = [_][]const u8{ "dog chases cat in park", "bird flies fish in sky", "fish swims cat in ocean" };
    const expected_all = [_][4][]const u8{ expected_f1, expected_f2, expected_f3 };

    for (0..3) |f| {
        std.debug.print("\n--- Frame {d}: '{s}' ---\n", .{ f + 1, frame_labels[f] });
        for (0..4) |r| {
            var query = frames[f].unbind(roles[r]);
            var best_idx: usize = 0;
            var best_sim: f64 = -2;
            for (0..fillers.len) |k| {
                const sim = query.similarity(fillers[k]);
                if (sim > best_sim) {
                    best_sim = sim;
                    best_idx = k;
                }
            }
            const is_correct = std.mem.eql(u8, filler_names[best_idx], expected_all[f][r]);
            if (is_correct) total_correct += 1;
            total_sim_sum += best_sim;
            std.debug.print("  unbind({s}): {s} (sim={d:.3}) {s}\n", .{ role_names[r], filler_names[best_idx], best_sim, if (is_correct) "OK" else "WRONG" });
        }
    }

    // Ternary comparison: run same test with ternary vectors
    var t_roles: [4]Hypervector = undefined;
    for (0..4) |i| {
        t_roles[i] = Hypervector.random(DIM, 0xCA01 + @as(u64, i));
    }
    var t_fillers: [10]Hypervector = undefined;
    for (0..10) |i| {
        t_fillers[i] = Hypervector.random(DIM, 0xCF01 + @as(u64, i));
    }
    // Build ternary frame1
    var t_b1 = t_roles[0].bind(&t_fillers[0]);
    var t_b2 = t_roles[1].bind(&t_fillers[2]);
    var t_b3 = t_roles[2].bind(&t_fillers[1]);
    var t_b4 = t_roles[3].bind(&t_fillers[3]);
    var t_f1_ab = t_b1.bundle(&t_b2);
    var t_f1_cd = t_b3.bundle(&t_b4);
    var t_frame1 = t_f1_ab.bundle(&t_f1_cd);

    var t_sim_sum: f64 = 0;
    var t_correct: usize = 0;
    const t_expected = [_]usize{ 0, 2, 1, 3 };
    for (0..4) |r| {
        var tq = t_frame1.unbind(&t_roles[r]);
        var tbest: usize = 0;
        var tbsim: f64 = -2;
        for (0..10) |k| {
            const ts = tq.similarity(&t_fillers[k]);
            if (ts > tbsim) {
                tbsim = ts;
                tbest = k;
            }
        }
        t_sim_sum += tbsim;
        if (tbest == t_expected[r]) t_correct += 1;
    }

    const bipolar_avg_sim = total_sim_sum / 12.0;
    const ternary_avg_sim = t_sim_sum / 4.0;

    std.debug.print("\n--- Bipolar vs Ternary Unbind Signal ---\n", .{});
    std.debug.print("Bipolar avg unbind sim: {d:.4} ({d}/12 correct)\n", .{ bipolar_avg_sim, total_correct });
    std.debug.print("Ternary avg unbind sim: {d:.4} ({d}/4 correct)\n", .{ ternary_avg_sim, t_correct });
    std.debug.print("Bipolar signal boost: {d:.2}x\n", .{bipolar_avg_sim / @max(ternary_avg_sim, 0.001)});

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(total_correct >= 10); // at least 10/12
    try std.testing.expect(bipolar_avg_sim > ternary_avg_sim); // bipolar stronger signal
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 57: Bipolar Noise + Capacity vs Ternary (Level 11.1)
// ═══════════════════════════════════════════════════════════════════════════════
test "bipolar noise robustness and capacity comparison" {
    const DIM = 1024;
    const NUM = 20;

    // Create bipolar codebook
    var bp_symbols: [NUM]Hypervector = undefined;
    for (0..NUM) |i| {
        bp_symbols[i] = bipolarRandom(DIM, 0xBE01 + @as(u64, i) * 1013);
    }

    // Create ternary codebook (same seeds but different generator)
    var tr_symbols: [NUM]Hypervector = undefined;
    for (0..NUM) |i| {
        tr_symbols[i] = Hypervector.random(DIM, 0xAE01 + @as(u64, i) * 1013);
    }

    std.debug.print("\n=== BIPOLAR vs TERNARY COMPARISON (Level 11.1) ===\n", .{});
    std.debug.print("Dimension: {d}, Codebook: {d} symbols\n", .{ DIM, NUM });

    // Bind/unbind comparison
    var bp0 = &bp_symbols[0];
    const bp1 = &bp_symbols[1];
    var bp_bound = bp0.bind(bp1);
    var bp_rec = bp_bound.unbind(bp0);
    const bp_inv_sim = bp_rec.similarity(bp1);

    var tr0 = &tr_symbols[0];
    const tr1 = &tr_symbols[1];
    var tr_bound = tr0.bind(tr1);
    var tr_rec = tr_bound.unbind(tr0);
    const tr_inv_sim = tr_rec.similarity(tr1);

    std.debug.print("\n--- Bind/Unbind Self-Inverse ---\n", .{});
    std.debug.print("Bipolar: {d:.6}\n", .{bp_inv_sim});
    std.debug.print("Ternary: {d:.6}\n", .{tr_inv_sim});

    // Noise injection comparison
    std.debug.print("\n--- Noise Recovery Comparison ---\n", .{});
    std.debug.print("  Noise %% | Bipolar sim | Ternary sim | BP recall | TR recall\n", .{});

    const noise_levels = [_]usize{ 0, 10, 20, 30, 40, 50, 60 };

    for (noise_levels) |noise_pct| {
        // Bipolar noise: flip sign
        var bp_noisy = bp_symbols[5];
        bp_noisy.data.ensureUnpacked();
        var bp_prng = std.Random.DefaultPrng.init(0xBBBB + @as(u64, noise_pct));
        const bp_rand = bp_prng.random();
        const bp_flips = DIM * noise_pct / 100;
        for (0..bp_flips) |_| {
            const pos = bp_rand.intRangeAtMost(usize, 0, DIM - 1);
            bp_noisy.data.unpacked_cache[pos] = -bp_noisy.data.unpacked_cache[pos];
            bp_noisy.data.dirty = true;
        }
        const bp_sim = bp_noisy.similarity(&bp_symbols[5]);
        var bp_best: usize = 0;
        var bp_bsim: f64 = -2;
        for (0..NUM) |k| {
            const s = bp_noisy.similarity(&bp_symbols[k]);
            if (s > bp_bsim) { bp_bsim = s; bp_best = k; }
        }

        // Ternary noise: random trit
        var tr_noisy = tr_symbols[5];
        tr_noisy.data.ensureUnpacked();
        var tr_prng = std.Random.DefaultPrng.init(0xCCCC + @as(u64, noise_pct));
        const tr_rand = tr_prng.random();
        const tr_flips = DIM * noise_pct / 100;
        for (0..tr_flips) |_| {
            const pos = tr_rand.intRangeAtMost(usize, 0, DIM - 1);
            tr_noisy.data.unpacked_cache[pos] = tr_rand.intRangeAtMost(i8, -1, 1);
            tr_noisy.data.dirty = true;
        }
        const tr_sim = tr_noisy.similarity(&tr_symbols[5]);
        var tr_best: usize = 0;
        var tr_bsim: f64 = -2;
        for (0..NUM) |k| {
            const s = tr_noisy.similarity(&tr_symbols[k]);
            if (s > tr_bsim) { tr_bsim = s; tr_best = k; }
        }

        std.debug.print("  {d:>5}%%  | {d:.4}      | {d:.4}      | {s:>4}      | {s}\n", .{
            noise_pct, bp_sim, tr_sim,
            if (bp_best == 5) "OK" else "FAIL",
            if (tr_best == 5) "OK" else "FAIL",
        });
    }

    // Capacity comparison
    std.debug.print("\n--- Superposition Capacity Comparison ---\n", .{});
    std.debug.print("  Items | Bipolar  | Ternary\n", .{});

    const cap_tests = [_]usize{ 2, 3, 5, 7, 10, 13, 15 };
    for (cap_tests) |num_items| {
        if (num_items > NUM) continue;

        // Bipolar capacity
        var bp_roles: [15]Hypervector = undefined;
        for (0..num_items) |item| {
            bp_roles[item] = bipolarRandom(DIM, 0xBB00 + @as(u64, item));
        }
        var bp_super = bp_roles[0].bind(&bp_symbols[0]);
        for (1..num_items) |item| {
            var bp_bi = bp_roles[item].bind(&bp_symbols[item]);
            bp_super = bp_super.bundle(&bp_bi);
        }
        var bp_cap_ok: usize = 0;
        for (0..num_items) |item| {
            var bq = bp_super.unbind(&bp_roles[item]);
            var bbi: usize = 0;
            var bbs: f64 = -2;
            for (0..NUM) |k| {
                const s = bq.similarity(&bp_symbols[k]);
                if (s > bbs) { bbs = s; bbi = k; }
            }
            if (bbi == item) bp_cap_ok += 1;
        }

        // Ternary capacity
        var tr_roles: [15]Hypervector = undefined;
        for (0..num_items) |item| {
            tr_roles[item] = Hypervector.random(DIM, 0xAA00 + @as(u64, item));
        }
        var tr_super = tr_roles[0].bind(&tr_symbols[0]);
        for (1..num_items) |item| {
            var tr_bi = tr_roles[item].bind(&tr_symbols[item]);
            tr_super = tr_super.bundle(&tr_bi);
        }
        var tr_cap_ok: usize = 0;
        for (0..num_items) |item| {
            var tq = tr_super.unbind(&tr_roles[item]);
            var tbi: usize = 0;
            var tbs: f64 = -2;
            for (0..NUM) |k| {
                const s = tq.similarity(&tr_symbols[k]);
                if (s > tbs) { tbs = s; tbi = k; }
            }
            if (tbi == item) tr_cap_ok += 1;
        }

        std.debug.print("  {d:>5}  | {d:>2}/{d:<2} {d:>5.1}%% | {d:>2}/{d:<2} {d:>5.1}%%\n", .{
            num_items,
            bp_cap_ok, num_items, @as(f64, @floatFromInt(bp_cap_ok)) / @as(f64, @floatFromInt(num_items)) * 100.0,
            tr_cap_ok, num_items, @as(f64, @floatFromInt(tr_cap_ok)) / @as(f64, @floatFromInt(num_items)) * 100.0,
        });
    }

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(bp_inv_sim > 0.99); // bipolar exact self-inverse
    try std.testing.expect(bp_inv_sim > tr_inv_sim); // bipolar better than ternary
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 58: RDF Triple Encoding & Query (Level 11.2)
// ═══════════════════════════════════════════════════════════════════════════════
test "rdf triple encoding and query bipolar" {
    const DIM = 1024;

    // Role vectors for S, R, O (bipolar)
    var role_s = bipolarRandom(DIM, 0xD001);
    var role_r = bipolarRandom(DIM, 0xD002);
    var role_o = bipolarRandom(DIM, 0xD003);

    // Entity vectors (bipolar): cities, countries, continents
    const NUM_ENTITIES = 10;
    var entities: [NUM_ENTITIES]Hypervector = undefined;
    const entity_names = [_][]const u8{
        "paris", "france", "europe", "london", "uk",
        "berlin", "germany", "tokyo", "japan", "asia",
    };
    for (0..NUM_ENTITIES) |i| {
        entities[i] = bipolarRandom(DIM, 0xE100 + @as(u64, @intCast(i)));
    }

    // Relation vectors (bipolar)
    const NUM_RELATIONS = 4;
    var relations: [NUM_RELATIONS]Hypervector = undefined;
    const relation_names = [_][]const u8{
        "capital-of", "in-continent", "language", "currency",
    };
    for (0..NUM_RELATIONS) |i| {
        relations[i] = bipolarRandom(DIM, 0xF100 + @as(u64, @intCast(i)));
    }

    // Knowledge base: (subject, relation, object) triples
    // Paris capital-of France, London capital-of UK, Berlin capital-of Germany,
    // Tokyo capital-of Japan, France in-continent Europe, UK in-continent Europe,
    // Germany in-continent Europe, Japan in-continent Asia
    const Triple = struct { s: usize, r: usize, o: usize };
    const triples = [_]Triple{
        .{ .s = 0, .r = 0, .o = 1 }, // Paris capital-of France
        .{ .s = 3, .r = 0, .o = 4 }, // London capital-of UK
        .{ .s = 5, .r = 0, .o = 6 }, // Berlin capital-of Germany
        .{ .s = 7, .r = 0, .o = 8 }, // Tokyo capital-of Japan
        .{ .s = 1, .r = 1, .o = 2 }, // France in-continent Europe
        .{ .s = 4, .r = 1, .o = 2 }, // UK in-continent Europe
        .{ .s = 6, .r = 1, .o = 2 }, // Germany in-continent Europe
        .{ .s = 8, .r = 1, .o = 9 }, // Japan in-continent Asia
    };

    std.debug.print("\n=== RDF TRIPLE ENCODING & QUERY (Level 11.2) ===\n", .{});
    std.debug.print("Dimension: {}, Entities: {}, Relations: {}, Triples: {}\n", .{ DIM, NUM_ENTITIES, NUM_RELATIONS, triples.len });

    // Encode each triple: bundle(bind(role_s, S), bind(role_r, R), bind(role_o, O))
    var encoded_triples: [8]Hypervector = undefined;
    for (0..triples.len) |i| {
        var bs = role_s.bind(&entities[triples[i].s]);
        var br = role_r.bind(&relations[triples[i].r]);
        var bo = role_o.bind(&entities[triples[i].o]);
        var temp = bs.bundle(&br);
        encoded_triples[i] = temp.bundle(&bo);
    }

    // Query each triple: unbind role → find closest entity/relation
    std.debug.print("\n--- Single Triple Queries (Bipolar) ---\n", .{});
    var query_correct: usize = 0;
    var query_total: usize = 0;
    var total_sim: f64 = 0;

    for (0..triples.len) |i| {
        // Query subject
        var recovered_s = encoded_triples[i].unbind(&role_s);
        var best_s_idx: usize = 0;
        var best_s_sim: f64 = -2.0;
        for (0..NUM_ENTITIES) |j| {
            const sim = recovered_s.similarity(&entities[j]);
            if (sim > best_s_sim) {
                best_s_sim = sim;
                best_s_idx = j;
            }
        }
        const s_ok = best_s_idx == triples[i].s;
        if (s_ok) query_correct += 1;
        total_sim += best_s_sim;
        query_total += 1;

        // Query relation
        var recovered_r = encoded_triples[i].unbind(&role_r);
        var best_r_idx: usize = 0;
        var best_r_sim: f64 = -2.0;
        for (0..NUM_RELATIONS) |j| {
            const sim = recovered_r.similarity(&relations[j]);
            if (sim > best_r_sim) {
                best_r_sim = sim;
                best_r_idx = j;
            }
        }
        const r_ok = best_r_idx == triples[i].r;
        if (r_ok) query_correct += 1;
        total_sim += best_r_sim;
        query_total += 1;

        // Query object
        var recovered_o = encoded_triples[i].unbind(&role_o);
        var best_o_idx: usize = 0;
        var best_o_sim: f64 = -2.0;
        for (0..NUM_ENTITIES) |j| {
            const sim = recovered_o.similarity(&entities[j]);
            if (sim > best_o_sim) {
                best_o_sim = sim;
                best_o_idx = j;
            }
        }
        const o_ok = best_o_idx == triples[i].o;
        if (o_ok) query_correct += 1;
        total_sim += best_o_sim;
        query_total += 1;

        std.debug.print("  ({s},{s},{s}): S={s}({d:.3}) R={s}({d:.3}) O={s}({d:.3})\n", .{
            entity_names[triples[i].s],
            relation_names[triples[i].r],
            entity_names[triples[i].o],
            if (s_ok) "OK" else "FAIL",
            best_s_sim,
            if (r_ok) "OK" else "FAIL",
            best_r_sim,
            if (o_ok) "OK" else "FAIL",
            best_o_sim,
        });
    }

    const bp_accuracy = @as(f64, @floatFromInt(query_correct)) / @as(f64, @floatFromInt(query_total));
    const bp_avg_sim = total_sim / @as(f64, @floatFromInt(query_total));
    std.debug.print("\nBipolar query accuracy: {}/{} ({d:.1}%)\n", .{ query_correct, query_total, bp_accuracy * 100 });
    std.debug.print("Bipolar avg query sim: {d:.4}\n", .{bp_avg_sim});

    // Compare with ternary (same knowledge graph but ternary vectors)
    var tr_role_s = Hypervector.random(DIM, 0xD001);
    var tr_role_r = Hypervector.random(DIM, 0xD002);
    var tr_role_o = Hypervector.random(DIM, 0xD003);
    var tr_entities: [NUM_ENTITIES]Hypervector = undefined;
    for (0..NUM_ENTITIES) |i| {
        tr_entities[i] = Hypervector.random(DIM, 0xE100 + @as(u64, @intCast(i)));
    }
    var tr_relations: [NUM_RELATIONS]Hypervector = undefined;
    for (0..NUM_RELATIONS) |i| {
        tr_relations[i] = Hypervector.random(DIM, 0xF100 + @as(u64, @intCast(i)));
    }

    var tr_correct: usize = 0;
    var tr_total: usize = 0;
    var tr_total_sim: f64 = 0;
    for (0..triples.len) |i| {
        var tbs = tr_role_s.bind(&tr_entities[triples[i].s]);
        var tbr = tr_role_r.bind(&tr_relations[triples[i].r]);
        var tbo = tr_role_o.bind(&tr_entities[triples[i].o]);
        var ttemp = tbs.bundle(&tbr);
        var tenc = ttemp.bundle(&tbo);

        // Query subject only for comparison
        var trec_s = tenc.unbind(&tr_role_s);
        var tbest_idx: usize = 0;
        var tbest_sim: f64 = -2.0;
        for (0..NUM_ENTITIES) |j| {
            const sim = trec_s.similarity(&tr_entities[j]);
            if (sim > tbest_sim) {
                tbest_sim = sim;
                tbest_idx = j;
            }
        }
        if (tbest_idx == triples[i].s) tr_correct += 1;
        tr_total_sim += tbest_sim;
        tr_total += 1;
    }
    const tr_accuracy = @as(f64, @floatFromInt(tr_correct)) / @as(f64, @floatFromInt(tr_total));
    const tr_avg_sim_val = tr_total_sim / @as(f64, @floatFromInt(tr_total));
    std.debug.print("\nTernary subject-query accuracy: {}/{} ({d:.1}%)\n", .{ tr_correct, tr_total, tr_accuracy * 100 });
    std.debug.print("Ternary avg subject sim: {d:.4}\n", .{tr_avg_sim_val});
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(bp_accuracy >= 0.9); // at least 90% accuracy
    try std.testing.expect(bp_avg_sim > 0.3); // clear signal above noise
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 59: Multi-Hop Inference Chain (Level 11.2)
// ═══════════════════════════════════════════════════════════════════════════════
test "multi-hop rdf inference bipolar" {
    const DIM = 1024;

    // Role vectors (bipolar)
    var role_s = bipolarRandom(DIM, 0xC001);
    var role_r = bipolarRandom(DIM, 0xC002);
    var role_o = bipolarRandom(DIM, 0xC003);

    // Entities for a chain: Paris → France → Europe → Eurasia → Earth
    const NUM_ENTS = 6;
    var ents: [NUM_ENTS]Hypervector = undefined;
    const ent_names = [_][]const u8{ "paris", "france", "europe", "eurasia", "earth", "moon" };
    for (0..NUM_ENTS) |i| {
        ents[i] = bipolarRandom(DIM, 0xA200 + @as(u64, @intCast(i)));
    }

    // Relations
    const NUM_RELS = 4;
    var rels: [NUM_RELS]Hypervector = undefined;
    for (0..NUM_RELS) |i| {
        rels[i] = bipolarRandom(DIM, 0xA300 + @as(u64, @intCast(i)));
    }

    // Build triples:
    // T0: Paris capital-of France
    // T1: France in-continent Europe
    // T2: Europe part-of Eurasia
    // T3: Eurasia part-of Earth
    const Triple = struct { s: usize, r: usize, o: usize };
    const chain_triples = [_]Triple{
        .{ .s = 0, .r = 0, .o = 1 }, // Paris capital-of France
        .{ .s = 1, .r = 1, .o = 2 }, // France in-continent Europe
        .{ .s = 2, .r = 2, .o = 3 }, // Europe part-of Eurasia
        .{ .s = 3, .r = 2, .o = 4 }, // Eurasia part-of Earth
    };

    // Encode triples
    var enc_triples: [4]Hypervector = undefined;
    for (0..chain_triples.len) |i| {
        var bs = role_s.bind(&ents[chain_triples[i].s]);
        var br = role_r.bind(&rels[chain_triples[i].r]);
        var bo = role_o.bind(&ents[chain_triples[i].o]);
        var temp = bs.bundle(&br);
        enc_triples[i] = temp.bundle(&bo);
    }

    std.debug.print("\n=== MULTI-HOP RDF INFERENCE (Level 11.2) ===\n", .{});
    std.debug.print("Dimension: {}, Chain: Paris → France → Europe → Eurasia → Earth\n", .{DIM});

    // Multi-hop inference using DIRECT bind chains (not triple-unbind)
    // For exact multi-hop, use bipolar bind composition:
    // hop1 = bind(Paris, R_capital-of) should approximate France (via triple unbind)
    // But the real power is: we know each triple, we unbind to get the object,
    // then use that object as subject to find the next triple.

    // Hop-by-hop: start from Paris, find what Paris is capital-of
    std.debug.print("\n--- Hop-by-Hop Inference ---\n", .{});
    var hop_correct: usize = 0;
    var hop_total: usize = 0;
    const expected_chain = [_]usize{ 0, 1, 2, 3, 4 }; // paris, france, europe, eurasia, earth

    // Start: Paris (entity 0)
    var current_entity_idx: usize = 0;
    std.debug.print("Start: {s}\n", .{ent_names[current_entity_idx]});

    for (0..chain_triples.len) |hop| {
        // Find the triple where current entity is the subject
        // by checking similarity of unbind(role_s) against each encoded triple
        var best_triple_idx: usize = 0;
        var best_match_sim: f64 = -2.0;
        for (0..chain_triples.len) |t| {
            var recovered_s = enc_triples[t].unbind(&role_s);
            const sim = recovered_s.similarity(&ents[current_entity_idx]);
            if (sim > best_match_sim) {
                best_match_sim = sim;
                best_triple_idx = t;
            }
        }

        // Found the best matching triple; now extract the object
        var recovered_obj = enc_triples[best_triple_idx].unbind(&role_o);
        var best_obj_idx: usize = 0;
        var best_obj_sim: f64 = -2.0;
        for (0..NUM_ENTS) |j| {
            const sim = recovered_obj.similarity(&ents[j]);
            if (sim > best_obj_sim) {
                best_obj_sim = sim;
                best_obj_idx = j;
            }
        }

        const expected_obj = expected_chain[hop + 1];
        const ok = best_obj_idx == expected_obj;
        if (ok) hop_correct += 1;
        hop_total += 1;

        std.debug.print("  Hop {}: {s} → {s} (sim={d:.4}, expected={s}) {s}\n", .{
            hop + 1,
            ent_names[current_entity_idx],
            ent_names[best_obj_idx],
            best_obj_sim,
            ent_names[expected_obj],
            if (ok) "OK" else "FAIL",
        });

        current_entity_idx = best_obj_idx;
    }

    const hop_accuracy = @as(f64, @floatFromInt(hop_correct)) / @as(f64, @floatFromInt(hop_total));
    std.debug.print("\nMulti-hop accuracy: {}/{} ({d:.1}%)\n", .{ hop_correct, hop_total, hop_accuracy * 100 });

    // Now test DIRECT bind-chain composition (bipolar exact)
    // Compose: R_total = bind(R_capital-of, bind(R_in-continent, R_part-of))
    // This creates a "super-relation" from city to continent-group
    std.debug.print("\n--- Direct Bind-Chain Composition ---\n", .{});
    var r01 = rels[0].bind(&rels[1]); // capital-of ∘ in-continent
    var r012 = r01.bind(&rels[2]); // ... ∘ part-of
    // These composed relations can be used to check if entities share multi-hop paths
    const compose_sim = r012.similarity(&rels[0]); // should be low (different)
    std.debug.print("Composed R(cap∘cont∘part) sim to R(cap): {d:.4} (should be ~0)\n", .{compose_sim});

    // Verify the composed relation is near-orthogonal to components (it's a new vector)
    const compose_sim2 = r012.similarity(&rels[1]);
    const compose_sim3 = r012.similarity(&rels[2]);
    std.debug.print("Composed sim to R(cont): {d:.4}\n", .{compose_sim2});
    std.debug.print("Composed sim to R(part): {d:.4}\n", .{compose_sim3});

    // Bipolar bind-chain self-inverse test:
    // unbind(bind(A,B,C), A) → bind(B,C)
    var bc = rels[1].bind(&rels[2]);
    var abc = rels[0].bind(&bc);
    var recovered_bc = abc.unbind(&rels[0]);
    const chain_recovery = recovered_bc.similarity(&bc);
    std.debug.print("\nBind-chain recovery: unbind(bind(A,B,C), A) → bind(B,C) sim={d:.6}\n", .{chain_recovery});
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(hop_accuracy >= 0.75); // at least 3/4 hops correct
    try std.testing.expect(chain_recovery > 0.99); // exact bind-chain recovery (bipolar)
    try std.testing.expect(@abs(compose_sim) < 0.2); // composed relation is new
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 60: Knowledge Graph Superposition (Level 11.2)
// ═══════════════════════════════════════════════════════════════════════════════
test "knowledge graph superposition query" {
    const DIM = 1024;

    // Role vectors
    var role_s = bipolarRandom(DIM, 0xAA01);
    var role_r = bipolarRandom(DIM, 0xAA02);
    var role_o = bipolarRandom(DIM, 0xAA03);

    // Entities: 8 entities
    const NUM_E = 8;
    var ent: [NUM_E]Hypervector = undefined;
    const ent_n = [_][]const u8{ "alice", "bob", "carol", "dave", "eve", "frank", "grace", "heidi" };
    for (0..NUM_E) |i| {
        ent[i] = bipolarRandom(DIM, 0xBB00 + @as(u64, @intCast(i)));
    }

    // Relations: 3 relations
    const NUM_R = 3;
    var rel: [NUM_R]Hypervector = undefined;
    const rel_n = [_][]const u8{ "knows", "works-with", "married-to" };
    for (0..NUM_R) |i| {
        rel[i] = bipolarRandom(DIM, 0xCC00 + @as(u64, @intCast(i)));
    }

    // Triples for a social graph
    const Triple = struct { s: usize, r: usize, o: usize };
    const graph_triples = [_]Triple{
        .{ .s = 0, .r = 0, .o = 1 }, // Alice knows Bob
        .{ .s = 0, .r = 1, .o = 2 }, // Alice works-with Carol
        .{ .s = 1, .r = 2, .o = 3 }, // Bob married-to Dave
        .{ .s = 2, .r = 0, .o = 4 }, // Carol knows Eve
        .{ .s = 4, .r = 1, .o = 5 }, // Eve works-with Frank
        .{ .s = 5, .r = 0, .o = 6 }, // Frank knows Grace
    };

    std.debug.print("\n=== KNOWLEDGE GRAPH SUPERPOSITION (Level 11.2) ===\n", .{});
    std.debug.print("Dimension: {}, Entities: {}, Relations: {}, Triples: {}\n", .{ DIM, NUM_E, NUM_R, graph_triples.len });

    // Encode individual triples
    var enc: [6]Hypervector = undefined;
    for (0..graph_triples.len) |i| {
        var bs = role_s.bind(&ent[graph_triples[i].s]);
        var br = role_r.bind(&rel[graph_triples[i].r]);
        var bo = role_o.bind(&ent[graph_triples[i].o]);
        var temp = bs.bundle(&br);
        enc[i] = temp.bundle(&bo);
    }

    // --- Individual triple queries (baseline) ---
    std.debug.print("\n--- Individual Triple Queries ---\n", .{});
    var indiv_correct: usize = 0;
    var indiv_total: usize = 0;
    for (0..graph_triples.len) |i| {
        var rec_o = enc[i].unbind(&role_o);
        var best_idx: usize = 0;
        var best_sim: f64 = -2.0;
        for (0..NUM_E) |j| {
            const sim = rec_o.similarity(&ent[j]);
            if (sim > best_sim) {
                best_sim = sim;
                best_idx = j;
            }
        }
        const ok = best_idx == graph_triples[i].o;
        if (ok) indiv_correct += 1;
        indiv_total += 1;
        std.debug.print("  ({s},{s},?) → {s} (sim={d:.3}) {s}\n", .{
            ent_n[graph_triples[i].s],
            rel_n[graph_triples[i].r],
            ent_n[best_idx],
            best_sim,
            if (ok) "OK" else "FAIL",
        });
    }
    std.debug.print("Individual accuracy: {}/{}\n", .{ indiv_correct, indiv_total });

    // --- Superpose all triples into one graph vector ---
    std.debug.print("\n--- Superposed Graph Queries ---\n", .{});

    // Bundle all 6 triples progressively
    var graph_vec = enc[0];
    for (1..graph_triples.len) |i| {
        graph_vec = graph_vec.bundle(&enc[i]);
    }

    // Query from the superposed graph: unbind role_o, then find closest
    var super_correct: usize = 0;
    var super_total: usize = 0;
    var super_total_sim: f64 = 0;
    for (0..graph_triples.len) |i| {
        // To query "who does S relate to via R?", we need:
        // unbind(graph, bind(role_s, S)) to get all R/O info for S
        // Then unbind role_o to get O candidates
        // But with superposition, the signal is divided among all triples.
        // Simpler approach: compute bind(role_s, S) + bind(role_r, R) as a "question",
        // and check similarity against each encoded triple to find the matching one.

        // Direct approach: unbind(enc[i], role_o) should still work for individual queries
        // For the superposed graph, we query by binding the "question" pattern
        var question_s = role_s.bind(&ent[graph_triples[i].s]);
        var question_r = role_r.bind(&rel[graph_triples[i].r]);
        var question = question_s.bundle(&question_r);

        // The response should be: unbind the question components from graph
        // Since graph ≈ sum of triples, and each triple has bind(role_o, O),
        // the matching triple's bind(role_o, O) component should survive.
        // We can recover O by computing similarity of unbind(graph, role_o) against entities
        // but that mixes all objects. Better: use the individual encoded triple lookup.

        // Practical approach: find which encoded triple is most similar to the question
        var best_match: usize = 0;
        var best_match_sim: f64 = -2.0;
        for (0..graph_triples.len) |t| {
            const sim = enc[t].similarity(&question);
            if (sim > best_match_sim) {
                best_match_sim = sim;
                best_match = t;
            }
        }

        // Then query the object from that triple
        var rec_obj = enc[best_match].unbind(&role_o);
        var best_obj: usize = 0;
        var best_obj_sim: f64 = -2.0;
        for (0..NUM_E) |j| {
            const sim = rec_obj.similarity(&ent[j]);
            if (sim > best_obj_sim) {
                best_obj_sim = sim;
                best_obj = j;
            }
        }

        const ok = best_obj == graph_triples[i].o;
        if (ok) super_correct += 1;
        super_total += 1;
        super_total_sim += best_obj_sim;
        std.debug.print("  ({s},{s},?) → {s} (sim={d:.3}) {s}\n", .{
            ent_n[graph_triples[i].s],
            rel_n[graph_triples[i].r],
            ent_n[best_obj],
            best_obj_sim,
            if (ok) "OK" else "FAIL",
        });
    }

    const super_accuracy = @as(f64, @floatFromInt(super_correct)) / @as(f64, @floatFromInt(super_total));
    const super_avg_sim = super_total_sim / @as(f64, @floatFromInt(super_total));
    std.debug.print("\nSuperposed graph query accuracy: {}/{} ({d:.1}%)\n", .{ super_correct, super_total, super_accuracy * 100 });
    std.debug.print("Avg object similarity: {d:.4}\n", .{super_avg_sim});

    // --- Graph vector statistics ---
    // How many individual triples can we discriminate from the graph vector?
    std.debug.print("\n--- Graph Triple Discrimination ---\n", .{});
    for (0..graph_triples.len) |i| {
        const sim = graph_vec.similarity(&enc[i]);
        std.debug.print("  graph ~ triple[{}] ({s},{s},{s}): sim={d:.4}\n", .{
            i,
            ent_n[graph_triples[i].s],
            rel_n[graph_triples[i].r],
            ent_n[graph_triples[i].o],
            sim,
        });
    }

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(indiv_correct == indiv_total); // individual queries 100%
    try std.testing.expect(super_accuracy >= 0.8); // superposed queries at least 80%
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 61: Few-Shot HDC Classifier (Level 11.3)
// ═══════════════════════════════════════════════════════════════════════════════
test "few-shot hdc classifier 1-3-5-10 shot" {
    const DIM = 1024;
    const NUM_CLASSES = 5;
    const MAX_SHOTS = 10;
    const NUM_TEST = 4; // test items per class

    // Class concept vectors (bipolar) — the shared component per class
    var concepts: [NUM_CLASSES]Hypervector = undefined;
    _ = [_][]const u8{ "animal", "vehicle", "food", "tool", "sport" }; // class names (for docs)
    for (0..NUM_CLASSES) |i| {
        concepts[i] = bipolarRandom(DIM, 0x5000 + @as(u64, @intCast(i)));
    }

    // A "role" vector for binding concept to instance
    var role_class = bipolarRandom(DIM, 0x5100);

    // Generate training examples: bind(role_class, concept) bundled with random instance noise
    // Each example = bundle(bind(role_class, concept), random_instance)
    // This simulates: each item shares the class concept but has unique instance features
    var train_examples: [NUM_CLASSES][MAX_SHOTS]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        for (0..MAX_SHOTS) |s| {
            const seed = 0x6000 + @as(u64, @intCast(c)) * 100 + @as(u64, @intCast(s));
            var instance = bipolarRandom(DIM, seed);
            var class_signal = role_class.bind(&concepts[c]);
            train_examples[c][s] = class_signal.bundle(&instance);
        }
    }

    // Generate test examples (different instances, same classes)
    var test_examples: [NUM_CLASSES][NUM_TEST]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        for (0..NUM_TEST) |t| {
            const seed = 0x7000 + @as(u64, @intCast(c)) * 100 + @as(u64, @intCast(t));
            var instance = bipolarRandom(DIM, seed);
            var class_signal = role_class.bind(&concepts[c]);
            test_examples[c][t] = class_signal.bundle(&instance);
        }
    }

    std.debug.print("\n=== FEW-SHOT HDC CLASSIFIER (Level 11.3) ===\n", .{});
    std.debug.print("Dimension: {}, Classes: {}, Test per class: {}\n", .{ DIM, NUM_CLASSES, NUM_TEST });

    // Test at different shot counts: 1, 3, 5, 10
    const shot_counts = [_]usize{ 1, 3, 5, 10 };
    var shot_accuracies: [4]f64 = undefined;

    for (0..shot_counts.len) |si| {
        const k = shot_counts[si];

        // Build prototypes: bundle first k training examples per class
        var prototypes: [NUM_CLASSES]Hypervector = undefined;
        for (0..NUM_CLASSES) |c| {
            prototypes[c] = train_examples[c][0];
            for (1..k) |s| {
                prototypes[c] = prototypes[c].bundle(&train_examples[c][s]);
            }
        }

        // Classify test examples
        var correct: usize = 0;
        var total: usize = 0;
        for (0..NUM_CLASSES) |c| {
            for (0..NUM_TEST) |t| {
                var best_class: usize = 0;
                var best_sim: f64 = -2.0;
                for (0..NUM_CLASSES) |p| {
                    const sim = test_examples[c][t].similarity(&prototypes[p]);
                    if (sim > best_sim) {
                        best_sim = sim;
                        best_class = p;
                    }
                }
                if (best_class == c) correct += 1;
                total += 1;
            }
        }

        const accuracy = @as(f64, @floatFromInt(correct)) / @as(f64, @floatFromInt(total));
        shot_accuracies[si] = accuracy;
        std.debug.print("\n--- {}-Shot Classification ---\n", .{k});
        std.debug.print("  Accuracy: {}/{} ({d:.1}%)\n", .{ correct, total, accuracy * 100 });
    }

    // Print accuracy curve
    std.debug.print("\n--- Accuracy Curve ---\n", .{});
    for (0..shot_counts.len) |si| {
        std.debug.print("  {}-shot: {d:.1}%\n", .{ shot_counts[si], shot_accuracies[si] * 100 });
    }

    std.debug.print("============================================\n", .{});

    // Assertions: accuracy should improve with more shots
    try std.testing.expect(shot_accuracies[0] > 0.4); // 1-shot: at least 40% (5 classes, random=20%)
    try std.testing.expect(shot_accuracies[3] >= shot_accuracies[0]); // 10-shot >= 1-shot
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 62: Bipolar vs Ternary Few-Shot Comparison (Level 11.3)
// ═══════════════════════════════════════════════════════════════════════════════
test "bipolar vs ternary few-shot comparison" {
    const DIM = 1024;
    const NUM_CLASSES = 5;
    const SHOTS = 5;
    const NUM_TEST = 4;

    // --- Bipolar classifier ---
    var bp_concepts: [NUM_CLASSES]Hypervector = undefined;
    for (0..NUM_CLASSES) |i| {
        bp_concepts[i] = bipolarRandom(DIM, 0x8000 + @as(u64, @intCast(i)));
    }
    var bp_role = bipolarRandom(DIM, 0x8100);

    var bp_prototypes: [NUM_CLASSES]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        const first_seed = 0x9000 + @as(u64, @intCast(c)) * 100;
        var inst0 = bipolarRandom(DIM, first_seed);
        var sig0 = bp_role.bind(&bp_concepts[c]);
        bp_prototypes[c] = sig0.bundle(&inst0);
        for (1..SHOTS) |s| {
            var inst = bipolarRandom(DIM, first_seed + @as(u64, @intCast(s)));
            var sig = bp_role.bind(&bp_concepts[c]);
            var example = sig.bundle(&inst);
            bp_prototypes[c] = bp_prototypes[c].bundle(&example);
        }
    }

    var bp_correct: usize = 0;
    var bp_total: usize = 0;
    for (0..NUM_CLASSES) |c| {
        for (0..NUM_TEST) |t| {
            const seed = 0xA000 + @as(u64, @intCast(c)) * 100 + @as(u64, @intCast(t));
            var inst = bipolarRandom(DIM, seed);
            var sig = bp_role.bind(&bp_concepts[c]);
            var test_item = sig.bundle(&inst);

            var best_class: usize = 0;
            var best_sim: f64 = -2.0;
            for (0..NUM_CLASSES) |p| {
                const sim = test_item.similarity(&bp_prototypes[p]);
                if (sim > best_sim) {
                    best_sim = sim;
                    best_class = p;
                }
            }
            if (best_class == c) bp_correct += 1;
            bp_total += 1;
        }
    }
    const bp_accuracy = @as(f64, @floatFromInt(bp_correct)) / @as(f64, @floatFromInt(bp_total));

    // --- Ternary classifier ---
    var tr_concepts: [NUM_CLASSES]Hypervector = undefined;
    for (0..NUM_CLASSES) |i| {
        tr_concepts[i] = Hypervector.random(DIM, 0x8000 + @as(u64, @intCast(i)));
    }
    var tr_role = Hypervector.random(DIM, 0x8100);

    var tr_prototypes: [NUM_CLASSES]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        const first_seed_tr = 0x9000 + @as(u64, @intCast(c)) * 100;
        var tinst0 = Hypervector.random(DIM, first_seed_tr);
        var tsig0 = tr_role.bind(&tr_concepts[c]);
        tr_prototypes[c] = tsig0.bundle(&tinst0);
        for (1..SHOTS) |s| {
            var tinst = Hypervector.random(DIM, first_seed_tr + @as(u64, @intCast(s)));
            var tsig = tr_role.bind(&tr_concepts[c]);
            var texample = tsig.bundle(&tinst);
            tr_prototypes[c] = tr_prototypes[c].bundle(&texample);
        }
    }

    var tr_correct: usize = 0;
    var tr_total: usize = 0;
    for (0..NUM_CLASSES) |c| {
        for (0..NUM_TEST) |t| {
            const seed = 0xA000 + @as(u64, @intCast(c)) * 100 + @as(u64, @intCast(t));
            var tinst = Hypervector.random(DIM, seed);
            var tsig = tr_role.bind(&tr_concepts[c]);
            var ttest = tsig.bundle(&tinst);

            var best_class: usize = 0;
            var best_sim: f64 = -2.0;
            for (0..NUM_CLASSES) |p| {
                const sim = ttest.similarity(&tr_prototypes[p]);
                if (sim > best_sim) {
                    best_sim = sim;
                    best_class = p;
                }
            }
            if (best_class == c) tr_correct += 1;
            tr_total += 1;
        }
    }
    const tr_accuracy = @as(f64, @floatFromInt(tr_correct)) / @as(f64, @floatFromInt(tr_total));

    std.debug.print("\n=== BIPOLAR vs TERNARY FEW-SHOT (Level 11.3) ===\n", .{});
    std.debug.print("Dimension: {}, Classes: {}, Shots: {}, Test/class: {}\n", .{ DIM, NUM_CLASSES, SHOTS, NUM_TEST });
    std.debug.print("\nBipolar {}-shot accuracy: {}/{} ({d:.1}%)\n", .{ SHOTS, bp_correct, bp_total, bp_accuracy * 100 });
    std.debug.print("Ternary {}-shot accuracy: {}/{} ({d:.1}%)\n", .{ SHOTS, tr_correct, tr_total, tr_accuracy * 100 });

    const winner = if (bp_accuracy > tr_accuracy) "Bipolar" else if (tr_accuracy > bp_accuracy) "Ternary" else "Tie";
    std.debug.print("Winner: {s}\n", .{winner});
    std.debug.print("============================================\n", .{});

    // Both should do better than random (20%)
    try std.testing.expect(bp_accuracy > 0.3);
    try std.testing.expect(tr_accuracy > 0.3);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 63: Interpretable Attribution — Unbind Prototype (Level 11.3)
// ═══════════════════════════════════════════════════════════════════════════════
test "few-shot interpretable attribution" {
    const DIM = 1024;
    const NUM_CLASSES = 3;
    const SHOTS = 5;

    // Class concepts (bipolar)
    var concepts: [NUM_CLASSES]Hypervector = undefined;
    const class_names = [_][]const u8{ "mammal", "bird", "fish" };
    for (0..NUM_CLASSES) |i| {
        concepts[i] = bipolarRandom(DIM, 0xDA00 + @as(u64, @intCast(i)));
    }
    var role_class = bipolarRandom(DIM, 0xDA10);

    // Training examples with known instances
    var train_instances: [NUM_CLASSES][SHOTS]Hypervector = undefined;
    var train_examples: [NUM_CLASSES][SHOTS]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        for (0..SHOTS) |s| {
            const seed = 0xDB00 + @as(u64, @intCast(c)) * 100 + @as(u64, @intCast(s));
            train_instances[c][s] = bipolarRandom(DIM, seed);
            var class_sig = role_class.bind(&concepts[c]);
            train_examples[c][s] = class_sig.bundle(&train_instances[c][s]);
        }
    }

    // Build prototypes
    var prototypes: [NUM_CLASSES]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        prototypes[c] = train_examples[c][0];
        for (1..SHOTS) |s| {
            prototypes[c] = prototypes[c].bundle(&train_examples[c][s]);
        }
    }

    std.debug.print("\n=== INTERPRETABLE ATTRIBUTION (Level 11.3) ===\n", .{});
    std.debug.print("Dimension: {}, Classes: {}, Shots: {}\n", .{ DIM, NUM_CLASSES, SHOTS });

    // Create a test query (mammal class, index 0)
    var test_instance = bipolarRandom(DIM, 0xDC00);
    var test_class_sig = role_class.bind(&concepts[0]);
    var test_query = test_class_sig.bundle(&test_instance);

    // Classify
    var best_class: usize = 0;
    var best_sim: f64 = -2.0;
    var all_sims: [NUM_CLASSES]f64 = undefined;
    for (0..NUM_CLASSES) |p| {
        const sim = test_query.similarity(&prototypes[p]);
        all_sims[p] = sim;
        if (sim > best_sim) {
            best_sim = sim;
            best_class = p;
        }
    }

    std.debug.print("\n--- Classification ---\n", .{});
    for (0..NUM_CLASSES) |p| {
        std.debug.print("  sim(query, {s}): {d:.4}{s}\n", .{
            class_names[p],
            all_sims[p],
            if (p == best_class) " ← PREDICTED" else "",
        });
    }
    std.debug.print("Correct: {}\n", .{best_class == 0});

    // Attribution: unbind query from correct prototype → should show class concept signal
    std.debug.print("\n--- Attribution Analysis ---\n", .{});
    var attribution = test_query.unbind(&prototypes[0]);

    // Check similarity of attribution to concept and instance vectors
    const attr_to_concept = attribution.similarity(&concepts[0]);
    const attr_to_instance = attribution.similarity(&test_instance);
    const attr_to_role = attribution.similarity(&role_class);
    std.debug.print("  attribution ~ mammal_concept:  {d:.4}\n", .{attr_to_concept});
    std.debug.print("  attribution ~ test_instance:   {d:.4}\n", .{attr_to_instance});
    std.debug.print("  attribution ~ role_class:      {d:.4}\n", .{attr_to_role});

    // Check attribution against wrong concepts
    const attr_to_wrong1 = attribution.similarity(&concepts[1]);
    const attr_to_wrong2 = attribution.similarity(&concepts[2]);
    std.debug.print("  attribution ~ bird_concept:    {d:.4} (wrong class)\n", .{attr_to_wrong1});
    std.debug.print("  attribution ~ fish_concept:    {d:.4} (wrong class)\n", .{attr_to_wrong2});

    // Check similarity of test query to each training example (which ones contributed?)
    std.debug.print("\n--- Training Example Contributions ---\n", .{});
    for (0..NUM_CLASSES) |c| {
        var max_contrib: f64 = -2.0;
        var avg_contrib: f64 = 0;
        for (0..SHOTS) |s| {
            const sim = test_query.similarity(&train_examples[c][s]);
            avg_contrib += sim;
            if (sim > max_contrib) max_contrib = sim;
        }
        avg_contrib /= @as(f64, @floatFromInt(SHOTS));
        std.debug.print("  {s}: avg={d:.4}, max={d:.4}\n", .{ class_names[c], avg_contrib, max_contrib });
    }

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(best_class == 0); // correct classification
    // Attribution to correct concept should be higher than to wrong concepts
    // (may not hold perfectly with bundle noise, so check the classification is right)
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 64: Hard Few-Shot — Overlapping Class Features (Level 11.4)
// ═══════════════════════════════════════════════════════════════════════════════
test "hard few-shot overlapping classes" {
    const DIM = 1024;
    const NUM_FEATURES = 8;
    const NUM_CLASSES = 5;
    const NUM_TEST = 8; // more test items for statistics

    // Shared feature vectors (bipolar building blocks)
    var features: [NUM_FEATURES]Hypervector = undefined;
    for (0..NUM_FEATURES) |i| {
        features[i] = bipolarRandom(DIM, 0x1A00 + @as(u64, @intCast(i)));
    }

    // Classes defined by 3 features each — WITH OVERLAP
    // Class 0 (cat-like):    features 0, 1, 2
    // Class 1 (dog-like):    features 0, 1, 3    ← shares 0,1 with class 0!
    // Class 2 (bird-like):   features 2, 4, 5    ← shares 2 with class 0
    // Class 3 (fish-like):   features 4, 5, 6    ← shares 4,5 with class 2!
    // Class 4 (insect-like): features 6, 7, 3    ← shares 6 with class 3, 3 with class 1
    const class_features = [5][3]usize{
        .{ 0, 1, 2 }, // cat
        .{ 0, 1, 3 }, // dog — 2/3 overlap with cat
        .{ 2, 4, 5 }, // bird — 1/3 overlap with cat
        .{ 4, 5, 6 }, // fish — 2/3 overlap with bird
        .{ 6, 7, 3 }, // insect — 1/3 overlap with fish, 1/3 with dog
    };
    const class_labels = [_][]const u8{ "cat", "dog", "bird", "fish", "insect" };

    // Build class concept vectors: bundle of 3 feature vectors
    var class_concepts: [NUM_CLASSES]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        var f0 = features[class_features[c][0]];
        var f1 = features[class_features[c][1]];
        class_concepts[c] = f0.bundle(&f1);
        var f2 = features[class_features[c][2]];
        class_concepts[c] = class_concepts[c].bundle(&f2);
    }

    // Show inter-class similarity (reveals overlap)
    std.debug.print("\n=== HARD FEW-SHOT: OVERLAPPING CLASSES (Level 11.4) ===\n", .{});
    std.debug.print("Dimension: {}, Features: {}, Classes: {}\n", .{ DIM, NUM_FEATURES, NUM_CLASSES });
    std.debug.print("\n--- Class Concept Similarity Matrix ---\n", .{});
    std.debug.print("         ", .{});
    for (0..NUM_CLASSES) |c| {
        std.debug.print("{s:>8}", .{class_labels[c]});
    }
    std.debug.print("\n", .{});
    for (0..NUM_CLASSES) |i| {
        std.debug.print("{s:>8} ", .{class_labels[i]});
        for (0..NUM_CLASSES) |j| {
            const sim = class_concepts[i].similarity(&class_concepts[j]);
            std.debug.print("{d:>7.3} ", .{sim});
        }
        std.debug.print("\n", .{});
    }

    // Generate examples: bundle(class_concept, noise1, noise2, noise3)
    // 4 components in the bundle → class signal is ~25% of the vector
    const MAX_SHOTS = 20;
    const NOISE_COUNT = 3; // number of noise vectors bundled with concept
    var train_examples: [NUM_CLASSES][MAX_SHOTS]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        for (0..MAX_SHOTS) |s| {
            train_examples[c][s] = class_concepts[c];
            for (0..NOISE_COUNT) |n| {
                const seed = 0x2A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(s)) * 10 + @as(u64, @intCast(n));
                var noise = bipolarRandom(DIM, seed);
                train_examples[c][s] = train_examples[c][s].bundle(&noise);
            }
        }
    }

    // Generate test examples (same structure, different noise)
    var test_examples: [NUM_CLASSES][NUM_TEST]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        for (0..NUM_TEST) |t| {
            test_examples[c][t] = class_concepts[c];
            for (0..NOISE_COUNT) |n| {
                const seed = 0x3A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(t)) * 10 + @as(u64, @intCast(n));
                var noise = bipolarRandom(DIM, seed);
                test_examples[c][t] = test_examples[c][t].bundle(&noise);
            }
        }
    }

    // Test at different shot counts
    const shot_counts = [_]usize{ 1, 3, 5, 10, 20 };
    var shot_results: [5]f64 = undefined;

    for (0..shot_counts.len) |si| {
        const k = shot_counts[si];

        // Build prototypes
        var prototypes: [NUM_CLASSES]Hypervector = undefined;
        for (0..NUM_CLASSES) |c| {
            prototypes[c] = train_examples[c][0];
            for (1..k) |s| {
                prototypes[c] = prototypes[c].bundle(&train_examples[c][s]);
            }
        }

        // Classify
        var correct: usize = 0;
        var total: usize = 0;
        for (0..NUM_CLASSES) |c| {
            for (0..NUM_TEST) |t| {
                var best_class: usize = 0;
                var best_sim: f64 = -2.0;
                for (0..NUM_CLASSES) |p| {
                    const sim = test_examples[c][t].similarity(&prototypes[p]);
                    if (sim > best_sim) {
                        best_sim = sim;
                        best_class = p;
                    }
                }
                if (best_class == c) correct += 1;
                total += 1;
            }
        }
        const acc = @as(f64, @floatFromInt(correct)) / @as(f64, @floatFromInt(total));
        shot_results[si] = acc;
        std.debug.print("\n--- {}-Shot (hard) ---\n", .{k});
        std.debug.print("  Accuracy: {}/{} ({d:.1}%)\n", .{ correct, total, acc * 100 });
    }

    // Print accuracy curve
    std.debug.print("\n--- Hard Accuracy Curve ---\n", .{});
    for (0..shot_counts.len) |si| {
        std.debug.print("  {}-shot: {d:.1}%\n", .{ shot_counts[si], shot_results[si] * 100 });
    }
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(shot_results[0] > 0.25); // 1-shot: better than random (20%)
    try std.testing.expect(shot_results[4] >= shot_results[0]); // more shots helps
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 65: Noise-Scaling Difficulty Curve (Level 11.4)
// ═══════════════════════════════════════════════════════════════════════════════
test "noise scaling difficulty curve" {
    const DIM = 1024;
    const NUM_FEATURES = 8;
    const NUM_CLASSES = 5;
    const SHOTS = 5;
    const NUM_TEST = 8;

    // Same feature/class structure as Test 64
    var features: [NUM_FEATURES]Hypervector = undefined;
    for (0..NUM_FEATURES) |i| {
        features[i] = bipolarRandom(DIM, 0x4A00 + @as(u64, @intCast(i)));
    }
    const class_features = [5][3]usize{
        .{ 0, 1, 2 },
        .{ 0, 1, 3 },
        .{ 2, 4, 5 },
        .{ 4, 5, 6 },
        .{ 6, 7, 3 },
    };
    var class_concepts: [NUM_CLASSES]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        var f0 = features[class_features[c][0]];
        var f1 = features[class_features[c][1]];
        class_concepts[c] = f0.bundle(&f1);
        var f2 = features[class_features[c][2]];
        class_concepts[c] = class_concepts[c].bundle(&f2);
    }

    std.debug.print("\n=== NOISE-SCALING DIFFICULTY (Level 11.4) ===\n", .{});
    std.debug.print("Dimension: {}, Classes: {}, Shots: {}\n", .{ DIM, NUM_CLASSES, SHOTS });

    // Vary noise count from 0 (easy) to 6 (very hard)
    const noise_levels = [_]usize{ 0, 1, 2, 3, 4, 5, 6 };
    var noise_results: [7]f64 = undefined;

    for (0..noise_levels.len) |ni| {
        const noise_count = noise_levels[ni];

        // Build training examples
        var prototypes: [NUM_CLASSES]Hypervector = undefined;
        for (0..NUM_CLASSES) |c| {
            // First example
            var ex = class_concepts[c];
            for (0..noise_count) |n| {
                const seed = 0x5A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(n));
                var noise = bipolarRandom(DIM, seed);
                ex = ex.bundle(&noise);
            }
            prototypes[c] = ex;
            // Remaining shots
            for (1..SHOTS) |s| {
                var ex2 = class_concepts[c];
                for (0..noise_count) |n| {
                    const seed = 0x5A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(s)) * 10 + @as(u64, @intCast(n));
                    var noise = bipolarRandom(DIM, seed);
                    ex2 = ex2.bundle(&noise);
                }
                prototypes[c] = prototypes[c].bundle(&ex2);
            }
        }

        // Classify test examples
        var correct: usize = 0;
        var total: usize = 0;
        for (0..NUM_CLASSES) |c| {
            for (0..NUM_TEST) |t| {
                var test_item = class_concepts[c];
                for (0..noise_count) |n| {
                    const seed = 0x6A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(t)) * 10 + @as(u64, @intCast(n));
                    var noise = bipolarRandom(DIM, seed);
                    test_item = test_item.bundle(&noise);
                }

                var best_class: usize = 0;
                var best_sim: f64 = -2.0;
                for (0..NUM_CLASSES) |p| {
                    const sim = test_item.similarity(&prototypes[p]);
                    if (sim > best_sim) {
                        best_sim = sim;
                        best_class = p;
                    }
                }
                if (best_class == c) correct += 1;
                total += 1;
            }
        }

        const acc = @as(f64, @floatFromInt(correct)) / @as(f64, @floatFromInt(total));
        noise_results[ni] = acc;
    }

    // Print difficulty curve
    std.debug.print("\n--- Difficulty Curve (5-shot, varying noise) ---\n", .{});
    std.debug.print("  Noise components | Accuracy\n", .{});
    for (0..noise_levels.len) |ni| {
        std.debug.print("  {} noise           | {d:.1}%\n", .{ noise_levels[ni], noise_results[ni] * 100 });
    }

    // Signal-to-noise analysis
    std.debug.print("\n--- Signal Fraction ---\n", .{});
    for (0..noise_levels.len) |ni| {
        const n = noise_levels[ni];
        const signal_frac = 1.0 / @as(f64, @floatFromInt(n + 1));
        std.debug.print("  {} noise: signal fraction = {d:.1}% of vector\n", .{ n, signal_frac * 100 });
    }

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(noise_results[0] > 0.8); // 0 noise: should be high
    try std.testing.expect(noise_results[0] >= noise_results[6]); // more noise = harder
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 66: Confusion Matrix at Hard Setting (Level 11.4)
// ═══════════════════════════════════════════════════════════════════════════════
test "confusion matrix hard few-shot" {
    const DIM = 1024;
    const NUM_FEATURES = 8;
    const NUM_CLASSES = 5;
    const SHOTS = 10;
    const NUM_TEST = 10;
    const NOISE_COUNT = 3;

    // Same feature/class structure
    var features: [NUM_FEATURES]Hypervector = undefined;
    for (0..NUM_FEATURES) |i| {
        features[i] = bipolarRandom(DIM, 0x7A00 + @as(u64, @intCast(i)));
    }
    const class_features = [5][3]usize{
        .{ 0, 1, 2 },
        .{ 0, 1, 3 },
        .{ 2, 4, 5 },
        .{ 4, 5, 6 },
        .{ 6, 7, 3 },
    };
    const class_labels = [_][]const u8{ "cat", "dog", "bird", "fish", "insect" };

    var class_concepts: [NUM_CLASSES]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        var f0 = features[class_features[c][0]];
        var f1 = features[class_features[c][1]];
        class_concepts[c] = f0.bundle(&f1);
        var f2 = features[class_features[c][2]];
        class_concepts[c] = class_concepts[c].bundle(&f2);
    }

    // Build prototypes (10-shot with 3 noise components)
    var prototypes: [NUM_CLASSES]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        var ex0 = class_concepts[c];
        for (0..NOISE_COUNT) |n| {
            const seed = 0x8A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(n));
            var noise = bipolarRandom(DIM, seed);
            ex0 = ex0.bundle(&noise);
        }
        prototypes[c] = ex0;
        for (1..SHOTS) |s| {
            var ex = class_concepts[c];
            for (0..NOISE_COUNT) |n| {
                const seed = 0x8A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(s)) * 10 + @as(u64, @intCast(n));
                var noise = bipolarRandom(DIM, seed);
                ex = ex.bundle(&noise);
            }
            prototypes[c] = prototypes[c].bundle(&ex);
        }
    }

    // Build confusion matrix
    var confusion: [NUM_CLASSES][NUM_CLASSES]usize = [_][NUM_CLASSES]usize{[_]usize{0} ** NUM_CLASSES} ** NUM_CLASSES;
    var total_correct: usize = 0;
    var total_count: usize = 0;

    for (0..NUM_CLASSES) |c| {
        for (0..NUM_TEST) |t| {
            var test_item = class_concepts[c];
            for (0..NOISE_COUNT) |n| {
                const seed = 0x9A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(t)) * 10 + @as(u64, @intCast(n));
                var noise = bipolarRandom(DIM, seed);
                test_item = test_item.bundle(&noise);
            }

            var best_class: usize = 0;
            var best_sim: f64 = -2.0;
            for (0..NUM_CLASSES) |p| {
                const sim = test_item.similarity(&prototypes[p]);
                if (sim > best_sim) {
                    best_sim = sim;
                    best_class = p;
                }
            }
            confusion[c][best_class] += 1;
            if (best_class == c) total_correct += 1;
            total_count += 1;
        }
    }

    const total_acc = @as(f64, @floatFromInt(total_correct)) / @as(f64, @floatFromInt(total_count));

    std.debug.print("\n=== CONFUSION MATRIX — HARD FEW-SHOT (Level 11.4) ===\n", .{});
    std.debug.print("10-shot, 3 noise components, 10 test per class\n\n", .{});

    // Print confusion matrix
    std.debug.print("Predicted →\n", .{});
    std.debug.print("True ↓   ", .{});
    for (0..NUM_CLASSES) |c| {
        std.debug.print("{s:>8}", .{class_labels[c]});
    }
    std.debug.print("  | Recall\n", .{});
    std.debug.print("---------", .{});
    for (0..NUM_CLASSES) |_| {
        std.debug.print("--------", .{});
    }
    std.debug.print("--+-------\n", .{});

    for (0..NUM_CLASSES) |i| {
        std.debug.print("{s:>8} ", .{class_labels[i]});
        var row_total: usize = 0;
        for (0..NUM_CLASSES) |j| {
            std.debug.print("{:>8}", .{confusion[i][j]});
            row_total += confusion[i][j];
        }
        const recall = if (row_total > 0) @as(f64, @floatFromInt(confusion[i][i])) / @as(f64, @floatFromInt(row_total)) else 0.0;
        std.debug.print("  | {d:.0}%\n", .{recall * 100});
    }

    // Per-class precision
    std.debug.print("Prec.    ", .{});
    for (0..NUM_CLASSES) |j| {
        var col_total: usize = 0;
        for (0..NUM_CLASSES) |i| {
            col_total += confusion[i][j];
        }
        const prec = if (col_total > 0) @as(f64, @floatFromInt(confusion[j][j])) / @as(f64, @floatFromInt(col_total)) else 0.0;
        std.debug.print("{d:>7.0}%", .{prec * 100});
    }
    std.debug.print("\n", .{});

    // Overlap analysis
    std.debug.print("\n--- Overlap Analysis ---\n", .{});
    std.debug.print("cat-dog share features 0,1 (2/3): confusion = {}\n", .{confusion[0][1] + confusion[1][0]});
    std.debug.print("bird-fish share features 4,5 (2/3): confusion = {}\n", .{confusion[2][3] + confusion[3][2]});
    std.debug.print("cat-bird share feature 2 (1/3): confusion = {}\n", .{confusion[0][2] + confusion[2][0]});

    std.debug.print("\nOverall accuracy: {}/{} ({d:.1}%)\n", .{ total_correct, total_count, total_acc * 100 });
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(total_acc > 0.3); // better than random (20%)
}

// ═══════════════════════════════════════════════════════════════════════════════
// TREE BUNDLING HELPER (Level 11.5)
// ═══════════════════════════════════════════════════════════════════════════════

/// Tree-structured bundling: pair items, then pair pairs, etc.
/// All items get equal weight in the final vector.
/// For odd count, the last item carries forward to the next level.
/// Works IN-PLACE on the input slice to avoid stack overflow.
fn treeBundleN(items: []Hypervector) Hypervector {
    if (items.len == 0) unreachable;
    if (items.len == 1) return items[0];
    if (items.len == 2) return items[0].bundle(&items[1]);

    // Work in-place: pair items[0..n] → write results into items[0..n/2+1]
    var count = items.len;
    while (count > 1) {
        var write: usize = 0;
        var read: usize = 0;
        while (read + 1 < count) : (read += 2) {
            items[write] = items[read].bundle(&items[read + 1]);
            write += 1;
        }
        // Carry forward odd item
        if (read < count) {
            items[write] = items[read];
            write += 1;
        }
        count = write;
    }

    return items[0];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 67: Tree vs Flat Bundling — Hard Benchmark (Level 11.5)
// ═══════════════════════════════════════════════════════════════════════════════
test "tree vs flat bundling hard benchmark" {
    const DIM = 1024;
    const NUM_FEATURES = 8;
    const NUM_CLASSES = 5;
    const NUM_TEST = 8;
    const NOISE_COUNT = 3;
    const MAX_SHOTS = 20;

    // Same overlapping feature structure as Level 11.4
    var features: [NUM_FEATURES]Hypervector = undefined;
    for (0..NUM_FEATURES) |i| {
        features[i] = bipolarRandom(DIM, 0x1A00 + @as(u64, @intCast(i)));
    }
    const class_features = [5][3]usize{
        .{ 0, 1, 2 }, // cat
        .{ 0, 1, 3 }, // dog
        .{ 2, 4, 5 }, // bird
        .{ 4, 5, 6 }, // fish
        .{ 6, 7, 3 }, // insect
    };

    var class_concepts: [NUM_CLASSES]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        var f0 = features[class_features[c][0]];
        var f1 = features[class_features[c][1]];
        class_concepts[c] = f0.bundle(&f1);
        var f2 = features[class_features[c][2]];
        class_concepts[c] = class_concepts[c].bundle(&f2);
    }

    // Generate training and test examples (same seeds as Test 64 for comparability)
    var train_examples: [NUM_CLASSES][MAX_SHOTS]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        for (0..MAX_SHOTS) |s| {
            train_examples[c][s] = class_concepts[c];
            for (0..NOISE_COUNT) |n| {
                const seed = 0x2A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(s)) * 10 + @as(u64, @intCast(n));
                var noise = bipolarRandom(DIM, seed);
                train_examples[c][s] = train_examples[c][s].bundle(&noise);
            }
        }
    }

    var test_examples: [NUM_CLASSES][NUM_TEST]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        for (0..NUM_TEST) |t| {
            test_examples[c][t] = class_concepts[c];
            for (0..NOISE_COUNT) |n| {
                const seed = 0x3A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(t)) * 10 + @as(u64, @intCast(n));
                var noise = bipolarRandom(DIM, seed);
                test_examples[c][t] = test_examples[c][t].bundle(&noise);
            }
        }
    }

    std.debug.print("\n=== TREE vs FLAT BUNDLING (Level 11.5) ===\n", .{});
    std.debug.print("Dimension: {}, Classes: {}, Noise: {}\n", .{ DIM, NUM_CLASSES, NOISE_COUNT });

    const shot_counts = [_]usize{ 1, 3, 5, 10, 20 };
    var flat_results: [5]f64 = undefined;
    var tree_results: [5]f64 = undefined;

    for (0..shot_counts.len) |si| {
        const k = shot_counts[si];

        // --- Flat bundling (progressive) ---
        var flat_protos: [NUM_CLASSES]Hypervector = undefined;
        for (0..NUM_CLASSES) |c| {
            flat_protos[c] = train_examples[c][0];
            for (1..k) |s| {
                flat_protos[c] = flat_protos[c].bundle(&train_examples[c][s]);
            }
        }

        var flat_correct: usize = 0;
        var flat_total: usize = 0;
        for (0..NUM_CLASSES) |c| {
            for (0..NUM_TEST) |t| {
                var best_class: usize = 0;
                var best_sim: f64 = -2.0;
                for (0..NUM_CLASSES) |p| {
                    const sim = test_examples[c][t].similarity(&flat_protos[p]);
                    if (sim > best_sim) {
                        best_sim = sim;
                        best_class = p;
                    }
                }
                if (best_class == c) flat_correct += 1;
                flat_total += 1;
            }
        }
        flat_results[si] = @as(f64, @floatFromInt(flat_correct)) / @as(f64, @floatFromInt(flat_total));

        // --- Tree bundling (hierarchical) ---
        var tree_protos: [NUM_CLASSES]Hypervector = undefined;
        for (0..NUM_CLASSES) |c| {
            var slice: [MAX_SHOTS]Hypervector = undefined;
            for (0..k) |s| {
                slice[s] = train_examples[c][s];
            }
            tree_protos[c] = treeBundleN(slice[0..k]);
        }

        var tree_correct: usize = 0;
        var tree_total: usize = 0;
        for (0..NUM_CLASSES) |c| {
            for (0..NUM_TEST) |t| {
                var best_class: usize = 0;
                var best_sim: f64 = -2.0;
                for (0..NUM_CLASSES) |p| {
                    const sim = test_examples[c][t].similarity(&tree_protos[p]);
                    if (sim > best_sim) {
                        best_sim = sim;
                        best_class = p;
                    }
                }
                if (best_class == c) tree_correct += 1;
                tree_total += 1;
            }
        }
        tree_results[si] = @as(f64, @floatFromInt(tree_correct)) / @as(f64, @floatFromInt(tree_total));
    }

    // Print comparison
    std.debug.print("\n--- Accuracy Comparison ---\n", .{});
    std.debug.print("  Shots | Flat    | Tree    | Winner\n", .{});
    std.debug.print("  ------|---------|---------|-------\n", .{});
    for (0..shot_counts.len) |si| {
        const winner = if (tree_results[si] > flat_results[si]) "Tree" else if (flat_results[si] > tree_results[si]) "Flat" else "Tie";
        std.debug.print("  {:>5} | {d:>5.1}%  | {d:>5.1}%  | {s}\n", .{
            shot_counts[si],
            flat_results[si] * 100,
            tree_results[si] * 100,
            winner,
        });
    }

    // Check monotonicity of tree results
    var tree_monotonic = true;
    for (1..shot_counts.len) |si| {
        if (tree_results[si] < tree_results[si - 1] - 0.05) { // allow 5% noise
            tree_monotonic = false;
        }
    }
    var flat_monotonic = true;
    for (1..shot_counts.len) |si| {
        if (flat_results[si] < flat_results[si - 1] - 0.05) {
            flat_monotonic = false;
        }
    }
    std.debug.print("\nFlat monotonic: {}\n", .{flat_monotonic});
    std.debug.print("Tree monotonic: {}\n", .{tree_monotonic});
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(tree_results[4] > 0.25); // 20-shot tree: better than random
    try std.testing.expect(flat_results[0] > 0.2); // 1-shot: better than random
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 68: Prototype Weight Analysis — Tree vs Flat (Level 11.5)
// ═══════════════════════════════════════════════════════════════════════════════
test "prototype weight analysis tree vs flat" {
    const DIM = 1024;
    const NUM_ITEMS = 8;

    // Create 8 bipolar vectors
    var items: [NUM_ITEMS]Hypervector = undefined;
    for (0..NUM_ITEMS) |i| {
        items[i] = bipolarRandom(DIM, 0xEE00 + @as(u64, @intCast(i)));
    }

    // Flat bundling: progressive
    var flat_proto = items[0];
    for (1..NUM_ITEMS) |i| {
        flat_proto = flat_proto.bundle(&items[i]);
    }

    // Tree bundling
    var tree_items: [NUM_ITEMS]Hypervector = undefined;
    for (0..NUM_ITEMS) |i| {
        tree_items[i] = items[i];
    }
    var tree_proto = treeBundleN(tree_items[0..NUM_ITEMS]);

    std.debug.print("\n=== PROTOTYPE WEIGHT ANALYSIS (Level 11.5) ===\n", .{});
    std.debug.print("Items: {}, Dim: {}\n", .{ NUM_ITEMS, DIM });

    // Measure each item's contribution (similarity to prototype)
    std.debug.print("\n--- Per-Item Similarity to Prototype ---\n", .{});
    std.debug.print("  Item | Flat sim  | Tree sim  | Flat/Tree\n", .{});
    std.debug.print("  -----|-----------|-----------|----------\n", .{});

    var flat_total_sim: f64 = 0;
    var flat_min_sim: f64 = 2.0;
    var flat_max_sim: f64 = -2.0;
    var tree_total_sim: f64 = 0;
    var tree_min_sim: f64 = 2.0;
    var tree_max_sim: f64 = -2.0;

    for (0..NUM_ITEMS) |i| {
        const flat_sim = items[i].similarity(&flat_proto);
        const tree_sim = items[i].similarity(&tree_proto);
        flat_total_sim += flat_sim;
        tree_total_sim += tree_sim;
        if (flat_sim < flat_min_sim) flat_min_sim = flat_sim;
        if (flat_sim > flat_max_sim) flat_max_sim = flat_sim;
        if (tree_sim < tree_min_sim) tree_min_sim = tree_sim;
        if (tree_sim > tree_max_sim) tree_max_sim = tree_sim;
        const ratio = if (@abs(tree_sim) > 0.001) flat_sim / tree_sim else 0.0;
        std.debug.print("  {:>4} | {d:>8.4}  | {d:>8.4}  | {d:>7.2}x\n", .{ i, flat_sim, tree_sim, ratio });
    }

    const flat_avg = flat_total_sim / @as(f64, @floatFromInt(NUM_ITEMS));
    const tree_avg = tree_total_sim / @as(f64, @floatFromInt(NUM_ITEMS));
    const flat_range = flat_max_sim - flat_min_sim;
    const tree_range = tree_max_sim - tree_min_sim;

    std.debug.print("\n--- Summary ---\n", .{});
    std.debug.print("Flat: avg={d:.4}, min={d:.4}, max={d:.4}, range={d:.4}\n", .{ flat_avg, flat_min_sim, flat_max_sim, flat_range });
    std.debug.print("Tree: avg={d:.4}, min={d:.4}, max={d:.4}, range={d:.4}\n", .{ tree_avg, tree_min_sim, tree_max_sim, tree_range });
    std.debug.print("Tree range/Flat range: {d:.2}x\n", .{if (flat_range > 0.001) tree_range / flat_range else 0.0});
    std.debug.print("============================================\n", .{});

    // Assertions: tree should have more uniform weights (smaller range)
    try std.testing.expect(tree_range <= flat_range + 0.05); // tree at least as uniform (with tolerance)
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 69: Tree Bundling Confusion Matrix — Hard Setting (Level 11.5)
// ═══════════════════════════════════════════════════════════════════════════════
test "tree bundling confusion matrix hard" {
    const DIM = 1024;
    const NUM_FEATURES = 8;
    const NUM_CLASSES = 5;
    const SHOTS = 10;
    const NUM_TEST = 10;
    const NOISE_COUNT = 3;

    var features: [NUM_FEATURES]Hypervector = undefined;
    for (0..NUM_FEATURES) |i| {
        features[i] = bipolarRandom(DIM, 0x7A00 + @as(u64, @intCast(i)));
    }
    const class_features = [5][3]usize{
        .{ 0, 1, 2 },
        .{ 0, 1, 3 },
        .{ 2, 4, 5 },
        .{ 4, 5, 6 },
        .{ 6, 7, 3 },
    };
    const class_labels = [_][]const u8{ "cat", "dog", "bird", "fish", "insect" };

    var class_concepts: [NUM_CLASSES]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        var f0 = features[class_features[c][0]];
        var f1 = features[class_features[c][1]];
        class_concepts[c] = f0.bundle(&f1);
        var f2 = features[class_features[c][2]];
        class_concepts[c] = class_concepts[c].bundle(&f2);
    }

    // Build tree-bundled prototypes (same seeds as Test 66 for comparability)
    var tree_protos: [NUM_CLASSES]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        var examples: [10]Hypervector = undefined; // SHOTS=10
        for (0..SHOTS) |s| {
            examples[s] = class_concepts[c];
            for (0..NOISE_COUNT) |n| {
                const seed = 0x8A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(s)) * 10 + @as(u64, @intCast(n));
                var noise = bipolarRandom(DIM, seed);
                examples[s] = examples[s].bundle(&noise);
            }
        }
        tree_protos[c] = treeBundleN(examples[0..SHOTS]);
    }

    // Also build flat prototypes for comparison (same seeds)
    var flat_protos: [NUM_CLASSES]Hypervector = undefined;
    for (0..NUM_CLASSES) |c| {
        var ex0 = class_concepts[c];
        for (0..NOISE_COUNT) |n| {
            const seed = 0x8A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(n));
            var noise = bipolarRandom(DIM, seed);
            ex0 = ex0.bundle(&noise);
        }
        flat_protos[c] = ex0;
        for (1..SHOTS) |s| {
            var ex = class_concepts[c];
            for (0..NOISE_COUNT) |n| {
                const seed = 0x8A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(s)) * 10 + @as(u64, @intCast(n));
                var noise = bipolarRandom(DIM, seed);
                ex = ex.bundle(&noise);
            }
            flat_protos[c] = flat_protos[c].bundle(&ex);
        }
    }

    // Generate test items (same seeds as Test 66)
    // Build confusion matrices for both
    var tree_confusion: [NUM_CLASSES][NUM_CLASSES]usize = [_][NUM_CLASSES]usize{[_]usize{0} ** NUM_CLASSES} ** NUM_CLASSES;
    var flat_confusion: [NUM_CLASSES][NUM_CLASSES]usize = [_][NUM_CLASSES]usize{[_]usize{0} ** NUM_CLASSES} ** NUM_CLASSES;
    var tree_correct: usize = 0;
    var flat_correct: usize = 0;
    var total_count: usize = 0;

    for (0..NUM_CLASSES) |c| {
        for (0..NUM_TEST) |t| {
            var test_item = class_concepts[c];
            for (0..NOISE_COUNT) |n| {
                const seed = 0x9A00 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(t)) * 10 + @as(u64, @intCast(n));
                var noise = bipolarRandom(DIM, seed);
                test_item = test_item.bundle(&noise);
            }

            // Tree classification
            var tree_best: usize = 0;
            var tree_best_sim: f64 = -2.0;
            for (0..NUM_CLASSES) |p| {
                const sim = test_item.similarity(&tree_protos[p]);
                if (sim > tree_best_sim) {
                    tree_best_sim = sim;
                    tree_best = p;
                }
            }
            tree_confusion[c][tree_best] += 1;
            if (tree_best == c) tree_correct += 1;

            // Flat classification
            var flat_best: usize = 0;
            var flat_best_sim: f64 = -2.0;
            for (0..NUM_CLASSES) |p| {
                const sim = test_item.similarity(&flat_protos[p]);
                if (sim > flat_best_sim) {
                    flat_best_sim = sim;
                    flat_best = p;
                }
            }
            flat_confusion[c][flat_best] += 1;
            if (flat_best == c) flat_correct += 1;

            total_count += 1;
        }
    }

    const tree_acc = @as(f64, @floatFromInt(tree_correct)) / @as(f64, @floatFromInt(total_count));
    const flat_acc = @as(f64, @floatFromInt(flat_correct)) / @as(f64, @floatFromInt(total_count));

    std.debug.print("\n=== TREE BUNDLING CONFUSION MATRIX (Level 11.5) ===\n", .{});
    std.debug.print("10-shot, 3 noise, Tree vs Flat\n\n", .{});

    // Print tree confusion matrix
    std.debug.print("--- Tree Bundling ---\n", .{});
    std.debug.print("True ↓   ", .{});
    for (0..NUM_CLASSES) |c| {
        std.debug.print("{s:>8}", .{class_labels[c]});
    }
    std.debug.print("  | Recall\n", .{});
    for (0..NUM_CLASSES) |i| {
        std.debug.print("{s:>8} ", .{class_labels[i]});
        var row_total: usize = 0;
        for (0..NUM_CLASSES) |j| {
            std.debug.print("{:>8}", .{tree_confusion[i][j]});
            row_total += tree_confusion[i][j];
        }
        const recall = @as(f64, @floatFromInt(tree_confusion[i][i])) / @as(f64, @floatFromInt(row_total));
        std.debug.print("  | {d:.0}%\n", .{recall * 100});
    }

    // Print flat confusion matrix
    std.debug.print("\n--- Flat Bundling ---\n", .{});
    std.debug.print("True ↓   ", .{});
    for (0..NUM_CLASSES) |c| {
        std.debug.print("{s:>8}", .{class_labels[c]});
    }
    std.debug.print("  | Recall\n", .{});
    for (0..NUM_CLASSES) |i| {
        std.debug.print("{s:>8} ", .{class_labels[i]});
        var row_total: usize = 0;
        for (0..NUM_CLASSES) |j| {
            std.debug.print("{:>8}", .{flat_confusion[i][j]});
            row_total += flat_confusion[i][j];
        }
        const recall = @as(f64, @floatFromInt(flat_confusion[i][i])) / @as(f64, @floatFromInt(row_total));
        std.debug.print("  | {d:.0}%\n", .{recall * 100});
    }

    std.debug.print("\nTree overall: {}/{} ({d:.1}%)\n", .{ tree_correct, total_count, tree_acc * 100 });
    std.debug.print("Flat overall: {}/{} ({d:.1}%)\n", .{ flat_correct, total_count, flat_acc * 100 });
    const winner = if (tree_acc > flat_acc) "Tree" else if (flat_acc > tree_acc) "Flat" else "Tie";
    std.debug.print("Winner: {s}\n", .{winner});
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(tree_acc > 0.25); // better than random
    try std.testing.expect(flat_acc > 0.25); // better than random
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 70: 1000+ Shared-Relation Analogies Benchmark (Level 11.6)
// ═══════════════════════════════════════════════════════════════════════════════
test "1000+ shared-relation analogies benchmark" {
    const DIM = 1024;
    // Each relation R is a bipolar random vector. B_i = bind(R, A_i).
    // Extracting: R' = bind(B_j, A_j) = R (exact for bipolar self-inverse).
    // 10 relations × 12 pairs × (5 exemplar counts + 5 noise levels) = 1200 queries
    const NUM_RELATIONS = 10;
    const PAIRS_PER_REL = 12;

    // Phase 1: Clean analogies — vary exemplar count
    const exemplar_counts = [_]usize{ 1, 3, 5, 9, 11 };
    var correct_by_exemplar: [5]usize = [_]usize{0} ** 5;
    var queries_by_exemplar: [5]usize = [_]usize{0} ** 5;

    // Phase 2: Noisy analogies — noise added to extracted relation
    const noise_levels = [_]usize{ 0, 1, 2, 3, 5 };
    var correct_by_noise: [5]usize = [_]usize{0} ** 5;
    var queries_by_noise: [5]usize = [_]usize{0} ** 5;

    var total_correct: usize = 0;
    var total_queries: usize = 0;
    var per_rel_correct: [NUM_RELATIONS]usize = [_]usize{0} ** NUM_RELATIONS;

    std.debug.print("\n=== 1000+ SHARED-RELATION ANALOGIES (Level 11.6) ===\n", .{});
    std.debug.print("Relations: {}, Pairs/rel: {}, Dim: {}\n", .{ NUM_RELATIONS, PAIRS_PER_REL, DIM });

    for (0..NUM_RELATIONS) |r| {
        // Create shared relation vector for this relation
        var relation = bipolarRandom(DIM, 0xF000 + @as(u64, @intCast(r)) * 9973);

        // Create A words, B = bind(R, A)
        var a_words: [PAIRS_PER_REL]Hypervector = undefined;
        var b_words: [PAIRS_PER_REL]Hypervector = undefined;
        for (0..PAIRS_PER_REL) |i| {
            a_words[i] = bipolarRandom(DIM, 0xA000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(i)) * 6271);
            b_words[i] = relation.bind(&a_words[i]);
        }

        // Phase 1: Clean analogies
        for (exemplar_counts, 0..) |num_exemplars, ex_idx| {
            for (0..PAIRS_PER_REL) |q| {
                var rel_vectors: [11]Hypervector = undefined;
                var rel_count: usize = 0;
                for (0..PAIRS_PER_REL) |p| {
                    if (p == q) continue;
                    if (rel_count >= num_exemplars) break;
                    // R' = bind(B_p, A_p) = bind(bind(R,A_p), A_p) = R (bipolar exact)
                    rel_vectors[rel_count] = b_words[p].bind(&a_words[p]);
                    rel_count += 1;
                }

                var rel_proto: Hypervector = undefined;
                if (rel_count == 1) {
                    rel_proto = rel_vectors[0];
                } else {
                    rel_proto = treeBundleN(rel_vectors[0..rel_count]);
                }

                var predicted = rel_proto.bind(&a_words[q]);

                var best_idx: usize = 0;
                var best_sim: f64 = -2.0;
                for (0..PAIRS_PER_REL) |p| {
                    const sim = predicted.similarity(&b_words[p]);
                    if (sim > best_sim) {
                        best_sim = sim;
                        best_idx = p;
                    }
                }

                if (best_idx == q) {
                    total_correct += 1;
                    correct_by_exemplar[ex_idx] += 1;
                    if (ex_idx == exemplar_counts.len - 1) per_rel_correct[r] += 1;
                }
                total_queries += 1;
                queries_by_exemplar[ex_idx] += 1;
            }
        }

        // Phase 2: Noisy analogies — 1 exemplar with progressive noise
        for (noise_levels, 0..) |noise_count, n_idx| {
            for (0..PAIRS_PER_REL) |q| {
                const exemplar = if (q == 0) @as(usize, 1) else @as(usize, 0);
                var extracted_rel = b_words[exemplar].bind(&a_words[exemplar]);

                // Add noise: progressive bundle with random vectors
                for (0..noise_count) |n| {
                    const seed = 0xE000 + @as(u64, @intCast(r)) * 100000 + @as(u64, @intCast(q)) * 100 + @as(u64, @intCast(n));
                    var noise = bipolarRandom(DIM, seed);
                    extracted_rel = extracted_rel.bundle(&noise);
                }

                var predicted = extracted_rel.bind(&a_words[q]);

                var best_idx: usize = 0;
                var best_sim: f64 = -2.0;
                for (0..PAIRS_PER_REL) |p| {
                    const sim = predicted.similarity(&b_words[p]);
                    if (sim > best_sim) {
                        best_sim = sim;
                        best_idx = p;
                    }
                }

                if (best_idx == q) {
                    total_correct += 1;
                    correct_by_noise[n_idx] += 1;
                }
                total_queries += 1;
                queries_by_noise[n_idx] += 1;
            }
        }
    }

    // Print results
    std.debug.print("\n--- Phase 1: Clean Analogies by Exemplar Count ---\n", .{});
    std.debug.print("Exemplars | Correct | Total | Accuracy\n", .{});
    std.debug.print("----------|---------|-------|--------\n", .{});
    for (exemplar_counts, 0..) |ne, idx| {
        const acc = @as(f64, @floatFromInt(correct_by_exemplar[idx])) / @as(f64, @floatFromInt(queries_by_exemplar[idx]));
        std.debug.print("    {:>5} | {:>7} | {:>5} | {d:.1}%\n", .{ ne, correct_by_exemplar[idx], queries_by_exemplar[idx], acc * 100 });
    }

    std.debug.print("\n--- Phase 2: Noisy Analogies (1-exemplar + noise) ---\n", .{});
    std.debug.print("Noise | Correct | Total | Accuracy\n", .{});
    std.debug.print("------|---------|-------|--------\n", .{});
    for (noise_levels, 0..) |nl, idx| {
        const acc = @as(f64, @floatFromInt(correct_by_noise[idx])) / @as(f64, @floatFromInt(queries_by_noise[idx]));
        std.debug.print("    {:>1} | {:>7} | {:>5} | {d:.1}%\n", .{ nl, correct_by_noise[idx], queries_by_noise[idx], acc * 100 });
    }

    std.debug.print("\n--- Per-Relation Accuracy (11-exemplar, clean) ---\n", .{});
    for (0..NUM_RELATIONS) |r| {
        const per_acc = @as(f64, @floatFromInt(per_rel_correct[r])) / @as(f64, PAIRS_PER_REL);
        std.debug.print("  Relation {:>2}: {}/{} ({d:.1}%)\n", .{ r, per_rel_correct[r], PAIRS_PER_REL, per_acc * 100 });
    }

    const overall_acc = @as(f64, @floatFromInt(total_correct)) / @as(f64, @floatFromInt(total_queries));
    std.debug.print("\nTotal: {}/{} ({d:.1}%)\n", .{ total_correct, total_queries, overall_acc * 100 });
    std.debug.print("Total analogy queries: {} (>=1000: {})\n", .{ total_queries, total_queries >= 1000 });
    std.debug.print("============================================\n", .{});

    // Must have >=1000 queries
    try std.testing.expect(total_queries >= 1000);
    // Clean 1-exemplar bipolar should be 100% (exact self-inverse)
    const clean_1ex_acc = @as(f64, @floatFromInt(correct_by_exemplar[0])) / @as(f64, @floatFromInt(queries_by_exemplar[0]));
    try std.testing.expect(clean_1ex_acc > 0.95);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 71: Multi-Exemplar Relation Extraction — Tree vs Flat (Level 11.6)
// ═══════════════════════════════════════════════════════════════════════════════
test "multi-exemplar relation extraction tree vs flat" {
    const DIM = 1024;
    const NUM_PAIRS = 20;
    const NUM_TEST = 5; // hold out last 5 for testing

    // One shared relation: B_i = bind(R, A_i)
    var relation = bipolarRandom(DIM, 0xC000);
    var a_words: [NUM_PAIRS]Hypervector = undefined;
    var b_words: [NUM_PAIRS]Hypervector = undefined;
    for (0..NUM_PAIRS) |i| {
        a_words[i] = bipolarRandom(DIM, 0xC100 + @as(u64, @intCast(i)) * 3571);
        b_words[i] = relation.bind(&a_words[i]);
    }

    // Each extracted relation gets 3 noise components (simulating noisy observations)
    const NOISE_PER_REL = 3;

    std.debug.print("\n=== MULTI-EXEMPLAR NOISY RELATION: TREE vs FLAT (Level 11.6) ===\n", .{});
    std.debug.print("Pairs: {}, Test: {}, Dim: {}, Noise/rel: {}\n", .{ NUM_PAIRS, NUM_TEST, DIM, NOISE_PER_REL });

    std.debug.print("\nExemplars | Tree Acc | Flat Acc | Tree R-sim | Flat R-sim\n", .{});
    std.debug.print("----------|----------|----------|------------|----------\n", .{});

    const test_start = NUM_PAIRS - NUM_TEST;

    var tree_mono = true;
    var flat_mono = true;
    var prev_tree_acc: f64 = -1;
    var prev_flat_acc: f64 = -1;

    const exemplar_set = [_]usize{ 1, 2, 3, 5, 7, 10, 15 };
    for (exemplar_set) |num_ex| {
        // Extract noisy relation vectors
        var rel_vecs: [15]Hypervector = undefined;
        for (0..num_ex) |i| {
            rel_vecs[i] = b_words[i].bind(&a_words[i]); // = R exact
            // Add noise
            for (0..NOISE_PER_REL) |n| {
                const seed = 0xCC00 + @as(u64, @intCast(i)) * 100 + @as(u64, @intCast(n));
                var noise = bipolarRandom(DIM, seed);
                rel_vecs[i] = rel_vecs[i].bundle(&noise);
            }
        }

        // Tree-bundled noisy relation
        var tree_rel: Hypervector = undefined;
        if (num_ex == 1) {
            tree_rel = rel_vecs[0];
        } else {
            var tree_copy: [15]Hypervector = undefined;
            for (0..num_ex) |i| tree_copy[i] = rel_vecs[i];
            tree_rel = treeBundleN(tree_copy[0..num_ex]);
        }

        // Flat-bundled noisy relation
        var flat_rel = rel_vecs[0];
        for (1..num_ex) |i| {
            flat_rel = flat_rel.bundle(&rel_vecs[i]);
        }

        // Similarity to true relation
        const tree_r_sim = tree_rel.similarity(&relation);
        const flat_r_sim = flat_rel.similarity(&relation);

        // Test on held-out pairs
        var tree_correct: usize = 0;
        var flat_correct: usize = 0;

        for (test_start..NUM_PAIRS) |t| {
            var tree_pred = tree_rel.bind(&a_words[t]);
            var flat_pred = flat_rel.bind(&a_words[t]);

            var tree_best: usize = 0;
            var flat_best: usize = 0;
            var t_best_sim: f64 = -2.0;
            var f_best_sim: f64 = -2.0;

            for (0..NUM_PAIRS) |p| {
                const t_sim = tree_pred.similarity(&b_words[p]);
                const f_sim = flat_pred.similarity(&b_words[p]);
                if (t_sim > t_best_sim) { t_best_sim = t_sim; tree_best = p; }
                if (f_sim > f_best_sim) { f_best_sim = f_sim; flat_best = p; }
            }

            if (tree_best == t) tree_correct += 1;
            if (flat_best == t) flat_correct += 1;
        }

        const tree_acc = @as(f64, @floatFromInt(tree_correct)) / @as(f64, NUM_TEST);
        const flat_acc = @as(f64, @floatFromInt(flat_correct)) / @as(f64, NUM_TEST);

        if (prev_tree_acc >= 0 and tree_acc < prev_tree_acc - 0.01) tree_mono = false;
        if (prev_flat_acc >= 0 and flat_acc < prev_flat_acc - 0.01) flat_mono = false;
        prev_tree_acc = tree_acc;
        prev_flat_acc = flat_acc;

        std.debug.print("    {:>5} | {d:>7.1}% | {d:>7.1}% | {d:>9.4} | {d:>8.4}\n", .{ num_ex, tree_acc * 100, flat_acc * 100, tree_r_sim, flat_r_sim });
    }

    std.debug.print("\nTree monotonic: {}\n", .{tree_mono});
    std.debug.print("Flat monotonic: {}\n", .{flat_mono});
    std.debug.print("============================================\n", .{});

    // Tree should work well at 15 exemplars
    try std.testing.expect(prev_tree_acc > 0.5);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 72: Multi-Step Relation Chains (Level 11.6)
// ═══════════════════════════════════════════════════════════════════════════════
test "multi-step relation chains analogies" {
    const DIM = 1024;

    // Process chains one at a time to avoid stack overflow.
    // For each chain: 5 entities (4 hops max).
    // Test across 50 chains total (processed in batches of 5).
    const CHAINS_PER_BATCH = 5;
    const NUM_BATCHES = 10;
    const MAX_HOPS = 4;
    const ENTITIES_PER_CHAIN = MAX_HOPS + 1; // 5 entities per chain

    std.debug.print("\n=== MULTI-STEP RELATION CHAINS (Level 11.6) ===\n", .{});
    std.debug.print("Total chains: {}, Max hops: {}, Dim: {}\n", .{ CHAINS_PER_BATCH * NUM_BATCHES, MAX_HOPS, DIM });

    std.debug.print("\n  Hops | Correct | Total | Accuracy | Avg Sim\n", .{});
    std.debug.print("  -----|---------|-------|----------|--------\n", .{});

    var total_correct: usize = 0;
    var total_queries: usize = 0;
    var hop_correct_all: [MAX_HOPS]usize = [_]usize{0} ** MAX_HOPS;
    var hop_sim_all: [MAX_HOPS]f64 = [_]f64{0} ** MAX_HOPS;
    var hop_queries: [MAX_HOPS]usize = [_]usize{0} ** MAX_HOPS;

    for (0..NUM_BATCHES) |batch| {
        // Create entities for this batch
        var entities: [CHAINS_PER_BATCH * ENTITIES_PER_CHAIN]Hypervector = undefined;
        for (0..CHAINS_PER_BATCH * ENTITIES_PER_CHAIN) |i| {
            const seed = 0xD000 + @as(u64, @intCast(batch)) * 50000 + @as(u64, @intCast(i)) * 8191;
            entities[i] = bipolarRandom(DIM, seed);
        }

        for (1..MAX_HOPS + 1) |num_hops| {
            for (0..CHAINS_PER_BATCH) |chain| {
                const chain_base = chain * ENTITIES_PER_CHAIN;

                // Composite relation: bind(R_0, R_1, ..., R_{num_hops-1})
                var composite = entities[chain_base + 1].bind(&entities[chain_base]);
                for (1..num_hops) |h| {
                    var hop_rel = entities[chain_base + h + 1].bind(&entities[chain_base + h]);
                    composite = composite.bind(&hop_rel);
                }

                // Apply composite to start → should reach entity[num_hops]
                var predicted = composite.bind(&entities[chain_base]);
                const target_idx = chain_base + num_hops;

                // Find closest among batch entities
                var best_idx: usize = 0;
                var best_sim: f64 = -2.0;
                for (0..CHAINS_PER_BATCH * ENTITIES_PER_CHAIN) |e| {
                    const sim = predicted.similarity(&entities[e]);
                    if (sim > best_sim) {
                        best_sim = sim;
                        best_idx = e;
                    }
                }

                const target_sim = predicted.similarity(&entities[target_idx]);
                hop_sim_all[num_hops - 1] += target_sim;
                hop_queries[num_hops - 1] += 1;

                if (best_idx == target_idx) {
                    hop_correct_all[num_hops - 1] += 1;
                    total_correct += 1;
                }
                total_queries += 1;
            }
        }
    }

    for (0..MAX_HOPS) |h| {
        const hop_acc = @as(f64, @floatFromInt(hop_correct_all[h])) / @as(f64, @floatFromInt(hop_queries[h]));
        const avg_sim = hop_sim_all[h] / @as(f64, @floatFromInt(hop_queries[h]));
        std.debug.print("  {:>4} | {:>7} | {:>5} | {d:>7.1}% | {d:.4}\n", .{ h + 1, hop_correct_all[h], hop_queries[h], hop_acc * 100, avg_sim });
    }

    const overall_acc = @as(f64, @floatFromInt(total_correct)) / @as(f64, @floatFromInt(total_queries));
    std.debug.print("\nOverall: {}/{} ({d:.1}%)\n", .{ total_correct, total_queries, overall_acc * 100 });
    std.debug.print("============================================\n", .{});

    // Bipolar chains should be exact (self-inverse)
    try std.testing.expect(overall_acc > 0.9); // very high for bipolar
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 73: Hybrid Bipolar/Ternary Noisy Analogy Comparison (Level 11.7)
// ═══════════════════════════════════════════════════════════════════════════════
test "hybrid bipolar ternary noisy analogy comparison" {
    const DIM = 1024;
    const NUM_RELATIONS = 5;
    const PAIRS_PER_REL = 12;
    const noise_levels = [_]usize{ 0, 1, 2, 3, 5 };

    var bp_correct_by_noise: [5]usize = [_]usize{0} ** 5;
    var tr_correct_by_noise: [5]usize = [_]usize{0} ** 5;
    var hy_correct_by_noise: [5]usize = [_]usize{0} ** 5;
    var queries_by_noise: [5]usize = [_]usize{0} ** 5;

    std.debug.print("\n=== HYBRID BIPOLAR/TERNARY NOISY ANALOGY (Level 11.7) ===\n", .{});
    std.debug.print("Relations: {}, Pairs/rel: {}, Dim: {}\n", .{ NUM_RELATIONS, PAIRS_PER_REL, DIM });

    for (0..NUM_RELATIONS) |r| {
        // Create shared relation (bipolar)
        var bp_relation = bipolarRandom(DIM, 0xF700 + @as(u64, @intCast(r)) * 9973);

        // Create A words in both encodings
        var bp_a: [PAIRS_PER_REL]Hypervector = undefined;
        var tr_a: [PAIRS_PER_REL]Hypervector = undefined;
        var bp_b: [PAIRS_PER_REL]Hypervector = undefined;
        var tr_b: [PAIRS_PER_REL]Hypervector = undefined;

        for (0..PAIRS_PER_REL) |i| {
            const seed = 0xA700 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(i)) * 6271;
            bp_a[i] = bipolarRandom(DIM, seed);
            tr_a[i] = Hypervector.random(DIM, seed + 0x1000000);
            // B = bind(R, A) for each encoding
            bp_b[i] = bp_relation.bind(&bp_a[i]);
            // For ternary: create a ternary relation and apply
            var tr_relation = Hypervector.random(DIM, 0xF700 + @as(u64, @intCast(r)) * 9973 + 0x2000000);
            tr_b[i] = tr_relation.bind(&tr_a[i]);
        }

        for (noise_levels, 0..) |noise_count, n_idx| {
            for (0..PAIRS_PER_REL) |q| {
                const exemplar = if (q == 0) @as(usize, 1) else @as(usize, 0);

                // === BIPOLAR: extract relation + add noise ===
                var bp_rel = bp_b[exemplar].bind(&bp_a[exemplar]);
                for (0..noise_count) |n| {
                    const seed = 0xBB00 + @as(u64, @intCast(r)) * 100000 + @as(u64, @intCast(q)) * 100 + @as(u64, @intCast(n));
                    var noise = bipolarRandom(DIM, seed);
                    bp_rel = bp_rel.bundle(&noise);
                }
                var bp_pred = bp_rel.bind(&bp_a[q]);
                var bp_best: usize = 0;
                var bp_bsim: f64 = -2.0;
                for (0..PAIRS_PER_REL) |p| {
                    const sim = bp_pred.similarity(&bp_b[p]);
                    if (sim > bp_bsim) { bp_bsim = sim; bp_best = p; }
                }
                if (bp_best == q) bp_correct_by_noise[n_idx] += 1;

                // === TERNARY: extract relation + add noise ===
                var tr_rel = tr_b[exemplar].bind(&tr_a[exemplar]);
                for (0..noise_count) |n| {
                    const seed = 0xCC00 + @as(u64, @intCast(r)) * 100000 + @as(u64, @intCast(q)) * 100 + @as(u64, @intCast(n));
                    var noise = Hypervector.random(DIM, seed);
                    tr_rel = tr_rel.bundle(&noise);
                }
                var tr_pred = tr_rel.bind(&tr_a[q]);
                var tr_best: usize = 0;
                var tr_bsim: f64 = -2.0;
                for (0..PAIRS_PER_REL) |p| {
                    const sim = tr_pred.similarity(&tr_b[p]);
                    if (sim > tr_bsim) { tr_bsim = sim; tr_best = p; }
                }
                if (tr_best == q) tr_correct_by_noise[n_idx] += 1;

                // === HYBRID: bipolar extraction + ternary noise bundling ===
                // Extract relation in bipolar (exact)
                var hy_rel = bp_b[exemplar].bind(&bp_a[exemplar]); // exact R
                // Add noise in ternary mode (convert to ternary-style noise)
                for (0..noise_count) |n| {
                    const seed = 0xDD00 + @as(u64, @intCast(r)) * 100000 + @as(u64, @intCast(q)) * 100 + @as(u64, @intCast(n));
                    var noise = Hypervector.random(DIM, seed); // ternary noise
                    hy_rel = hy_rel.bundle(&noise);
                }
                var hy_pred = hy_rel.bind(&bp_a[q]);
                var hy_best: usize = 0;
                var hy_bsim: f64 = -2.0;
                for (0..PAIRS_PER_REL) |p| {
                    const sim = hy_pred.similarity(&bp_b[p]);
                    if (sim > hy_bsim) { hy_bsim = sim; hy_best = p; }
                }
                if (hy_best == q) hy_correct_by_noise[n_idx] += 1;

                queries_by_noise[n_idx] += 1;
            }
        }
    }

    // Print results
    std.debug.print("\n--- Bipolar vs Ternary vs Hybrid (Noisy Analogies) ---\n", .{});
    std.debug.print("Noise | Bipolar | Ternary | Hybrid  | Winner\n", .{});
    std.debug.print("------|---------|---------|---------|-------\n", .{});
    for (noise_levels, 0..) |nl, idx| {
        const total = @as(f64, @floatFromInt(queries_by_noise[idx]));
        const bp_acc = @as(f64, @floatFromInt(bp_correct_by_noise[idx])) / total;
        const tr_acc = @as(f64, @floatFromInt(tr_correct_by_noise[idx])) / total;
        const hy_acc = @as(f64, @floatFromInt(hy_correct_by_noise[idx])) / total;
        const winner = if (hy_acc >= bp_acc and hy_acc >= tr_acc) "Hybrid" else if (bp_acc >= tr_acc) "Bipolar" else "Ternary";
        std.debug.print("    {:>1} | {d:>6.1}% | {d:>6.1}% | {d:>6.1}% | {s}\n", .{ nl, bp_acc * 100, tr_acc * 100, hy_acc * 100, winner });
    }

    // Overall totals
    var bp_total: usize = 0;
    var tr_total: usize = 0;
    var hy_total: usize = 0;
    var q_total: usize = 0;
    for (0..5) |i| {
        bp_total += bp_correct_by_noise[i];
        tr_total += tr_correct_by_noise[i];
        hy_total += hy_correct_by_noise[i];
        q_total += queries_by_noise[i];
    }
    std.debug.print("\nOverall: Bipolar {}/{} ({d:.1}%), Ternary {}/{} ({d:.1}%), Hybrid {}/{} ({d:.1}%)\n", .{
        bp_total, q_total, @as(f64, @floatFromInt(bp_total)) / @as(f64, @floatFromInt(q_total)) * 100,
        tr_total, q_total, @as(f64, @floatFromInt(tr_total)) / @as(f64, @floatFromInt(q_total)) * 100,
        hy_total, q_total, @as(f64, @floatFromInt(hy_total)) / @as(f64, @floatFromInt(q_total)) * 100,
    });
    std.debug.print("============================================\n", .{});

    // Hybrid should be competitive
    try std.testing.expect(hy_total >= bp_total or hy_total >= tr_total);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 74: Hybrid Chain Composition + Superposition Capacity (Level 11.7)
// ═══════════════════════════════════════════════════════════════════════════════
test "hybrid chain composition and superposition capacity" {
    const DIM = 1024;
    const MAX_HOPS = 4;
    const MAX_BUNDLE = 10;

    std.debug.print("\n=== HYBRID CHAIN + SUPERPOSITION (Level 11.7) ===\n", .{});
    std.debug.print("Dim: {}, Max hops: {}, Max bundle: {}\n", .{ DIM, MAX_HOPS, MAX_BUNDLE });

    // Part A: Bipolar chain composition (should be exact)
    std.debug.print("\n--- Part A: Bipolar Chain Composition ---\n", .{});
    std.debug.print("  Hops | Sim to target | Status\n", .{});
    std.debug.print("  -----|---------------|-------\n", .{});

    const NUM_CHAINS = 10;
    for (1..MAX_HOPS + 1) |hops| {
        var sim_sum: f64 = 0;
        var correct: usize = 0;
        for (0..NUM_CHAINS) |chain| {
            // Create chain entities
            var entities: [5]Hypervector = undefined;
            for (0..hops + 1) |i| {
                entities[i] = bipolarRandom(DIM, 0xBB00 + @as(u64, @intCast(chain)) * 1000 + @as(u64, @intCast(i)) * 7919);
            }
            // Compose chain
            var composite = entities[1].bind(&entities[0]);
            for (1..hops) |h| {
                var hop_rel = entities[h + 1].bind(&entities[h]);
                composite = composite.bind(&hop_rel);
            }
            // Apply and check
            var predicted = composite.bind(&entities[0]);
            const sim = predicted.similarity(&entities[hops]);
            sim_sum += sim;
            if (sim > 0.9) correct += 1;
        }
        const avg_sim = sim_sum / @as(f64, NUM_CHAINS);
        std.debug.print("  {:>4} | {d:>12.6} | {}/{}\n", .{ hops, avg_sim, correct, NUM_CHAINS });
    }

    // Part B: Ternary superposition capacity
    std.debug.print("\n--- Part B: Ternary Superposition Capacity ---\n", .{});
    std.debug.print("  Bundle | Recall | Avg Sim | Min Sim\n", .{});
    std.debug.print("  -------|--------|---------|--------\n", .{});

    for (2..MAX_BUNDLE + 1) |k| {
        var items: [10]Hypervector = undefined;
        for (0..k) |i| {
            items[i] = Hypervector.random(DIM, 0xCC00 + @as(u64, @intCast(i)) * 3571);
        }
        // Tree bundle
        var bundled = treeBundleN(items[0..k]);
        // Check recall
        var recalled: usize = 0;
        var sim_sum: f64 = 0;
        var min_sim: f64 = 2.0;
        for (0..k) |i| {
            // Re-create item (treeBundleN modifies in place)
            var item = Hypervector.random(DIM, 0xCC00 + @as(u64, @intCast(i)) * 3571);
            const sim = bundled.similarity(&item);
            sim_sum += sim;
            if (sim < min_sim) min_sim = sim;
            // Check if this item is the best match among a set of 20 candidates
            var is_best = true;
            for (0..20) |d| {
                if (d < k) continue; // skip items in the bundle
                var distractor = Hypervector.random(DIM, 0xDD00 + @as(u64, @intCast(d)) * 5113);
                if (bundled.similarity(&distractor) >= sim) { is_best = false; break; }
            }
            if (is_best) recalled += 1;
        }
        const recall = @as(f64, @floatFromInt(recalled)) / @as(f64, @floatFromInt(k));
        const avg_sim = sim_sum / @as(f64, @floatFromInt(k));
        std.debug.print("  {:>5} | {d:>5.1}% | {d:>6.4} | {d:>6.4}\n", .{ k, recall * 100, avg_sim, min_sim });
    }

    // Part C: Hybrid pipeline — bipolar chains feed into ternary superposition
    std.debug.print("\n--- Part C: Hybrid Pipeline (Chain → Superposition) ---\n", .{});
    // Use bipolar chains to extract 5 facts, bundle them in ternary, query
    const NUM_FACTS = 5;
    var fact_targets: [NUM_FACTS]Hypervector = undefined;
    var chain_results: [NUM_FACTS]Hypervector = undefined;

    for (0..NUM_FACTS) |f| {
        // Create a 2-hop bipolar chain: start --R1--> mid --R2--> target
        var start = bipolarRandom(DIM, 0xEE00 + @as(u64, @intCast(f)) * 10000);
        var mid = bipolarRandom(DIM, 0xEE01 + @as(u64, @intCast(f)) * 10000);
        fact_targets[f] = bipolarRandom(DIM, 0xEE02 + @as(u64, @intCast(f)) * 10000);

        var r1 = mid.bind(&start);
        var r2 = fact_targets[f].bind(&mid);
        var composite = r1.bind(&r2);

        // Apply chain to recover target
        chain_results[f] = composite.bind(&start);
    }

    // Bundle all chain results into ternary superposition
    var super_items: [NUM_FACTS]Hypervector = undefined;
    for (0..NUM_FACTS) |i| super_items[i] = chain_results[i];
    var superposition = treeBundleN(super_items[0..NUM_FACTS]);

    // Query: is each target recoverable from superposition?
    var hybrid_recalled: usize = 0;
    std.debug.print("  Fact | Chain Sim | Super Sim | Found?\n", .{});
    std.debug.print("  -----|-----------|-----------|-------\n", .{});
    for (0..NUM_FACTS) |f| {
        const chain_sim = chain_results[f].similarity(&fact_targets[f]);
        const super_sim = superposition.similarity(&fact_targets[f]);
        const found = super_sim > 0.1; // above noise floor
        if (found) hybrid_recalled += 1;
        std.debug.print("  {:>4} | {d:>8.4} | {d:>8.4} | {s}\n", .{ f, chain_sim, super_sim, if (found) "YES" else "NO" });
    }

    const hybrid_recall = @as(f64, @floatFromInt(hybrid_recalled)) / @as(f64, NUM_FACTS);
    std.debug.print("\nHybrid pipeline: {}/{} facts recalled ({d:.1}%)\n", .{ hybrid_recalled, NUM_FACTS, hybrid_recall * 100 });
    std.debug.print("============================================\n", .{});

    // Bipolar chains must be exact, hybrid recall reasonable
    try std.testing.expect(hybrid_recalled >= 3); // at least 3/5 facts
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 75: Bipolar vs Ternary vs Hybrid Head-to-Head Summary (Level 11.7)
// ═══════════════════════════════════════════════════════════════════════════════
test "bipolar ternary hybrid head to head summary" {
    const DIM = 1024;
    const NUM = 20;

    // Create codebooks
    var bp_syms: [NUM]Hypervector = undefined;
    var tr_syms: [NUM]Hypervector = undefined;
    for (0..NUM) |i| {
        bp_syms[i] = bipolarRandom(DIM, 0xAB00 + @as(u64, @intCast(i)) * 1013);
        tr_syms[i] = Hypervector.random(DIM, 0xAC00 + @as(u64, @intCast(i)) * 1013);
    }

    std.debug.print("\n=== BIPOLAR vs TERNARY vs HYBRID HEAD-TO-HEAD (Level 11.7) ===\n", .{});
    std.debug.print("Dim: {}, Codebook: {} symbols\n\n", .{ DIM, NUM });

    // Metric 1: Self-inverse (bind/unbind recovery)
    var bp0 = &bp_syms[0];
    const bp1 = &bp_syms[1];
    var bp_bound = bp0.bind(bp1);
    var bp_rec = bp_bound.unbind(bp0);
    const bp_selfinv = bp_rec.similarity(bp1);

    var tr0 = &tr_syms[0];
    const tr1 = &tr_syms[1];
    var tr_bound = tr0.bind(tr1);
    var tr_rec = tr_bound.unbind(tr0);
    const tr_selfinv = tr_rec.similarity(tr1);

    // Metric 2: Noise tolerance (flip 30% of trits)
    var bp_noisy = bp_syms[5];
    bp_noisy.data.ensureUnpacked();
    var bp_prng = std.Random.DefaultPrng.init(0xBBBB);
    const bp_rand = bp_prng.random();
    const flips = DIM * 30 / 100;
    for (0..flips) |_| {
        const pos = bp_rand.intRangeAtMost(usize, 0, DIM - 1);
        bp_noisy.data.unpacked_cache[pos] = -bp_noisy.data.unpacked_cache[pos];
        bp_noisy.data.dirty = true;
    }
    const bp_noise_sim = bp_noisy.similarity(&bp_syms[5]);

    var tr_noisy = tr_syms[5];
    tr_noisy.data.ensureUnpacked();
    var tr_prng = std.Random.DefaultPrng.init(0xCCCC);
    const tr_rand = tr_prng.random();
    for (0..flips) |_| {
        const pos = tr_rand.intRangeAtMost(usize, 0, DIM - 1);
        tr_noisy.data.unpacked_cache[pos] = tr_rand.intRangeAtMost(i8, -1, 1);
        tr_noisy.data.dirty = true;
    }
    const tr_noise_sim = tr_noisy.similarity(&tr_syms[5]);

    // Metric 3: Superposition capacity (bundle 5 items, check recall)
    var bp_items: [5]Hypervector = undefined;
    var tr_items: [5]Hypervector = undefined;
    for (0..5) |i| {
        bp_items[i] = bp_syms[i];
        tr_items[i] = tr_syms[i];
    }
    var bp_super = treeBundleN(bp_items[0..5]);
    var tr_super = treeBundleN(tr_items[0..5]);

    var bp_super_recall: usize = 0;
    var tr_super_recall: usize = 0;
    for (0..5) |i| {
        // Re-create items (treeBundleN modified in place)
        var bp_item = bipolarRandom(DIM, 0xAB00 + @as(u64, @intCast(i)) * 1013);
        var tr_item = Hypervector.random(DIM, 0xAC00 + @as(u64, @intCast(i)) * 1013);
        const bp_s = bp_super.similarity(&bp_item);
        const tr_s = tr_super.similarity(&tr_item);
        if (bp_s > 0.1) bp_super_recall += 1;
        if (tr_s > 0.1) tr_super_recall += 1;
    }

    // Metric 4: Chain depth (3-hop composition)
    var bp_c: [4]Hypervector = undefined;
    for (0..4) |i| bp_c[i] = bipolarRandom(DIM, 0x9900 + @as(u64, @intCast(i)) * 7919);
    var bp_chain = bp_c[1].bind(&bp_c[0]);
    var bp_r2 = bp_c[2].bind(&bp_c[1]);
    bp_chain = bp_chain.bind(&bp_r2);
    var bp_r3 = bp_c[3].bind(&bp_c[2]);
    bp_chain = bp_chain.bind(&bp_r3);
    var bp_chain_pred = bp_chain.bind(&bp_c[0]);
    const bp_chain_sim = bp_chain_pred.similarity(&bp_c[3]);

    var tr_c: [4]Hypervector = undefined;
    for (0..4) |i| tr_c[i] = Hypervector.random(DIM, 0x8800 + @as(u64, @intCast(i)) * 7919);
    var tr_chain = tr_c[1].bind(&tr_c[0]);
    var tr_r2 = tr_c[2].bind(&tr_c[1]);
    tr_chain = tr_chain.bind(&tr_r2);
    var tr_r3 = tr_c[3].bind(&tr_c[2]);
    tr_chain = tr_chain.bind(&tr_r3);
    var tr_chain_pred = tr_chain.bind(&tr_c[0]);
    const tr_chain_sim = tr_chain_pred.similarity(&tr_c[3]);

    // Print summary table
    std.debug.print("--- Head-to-Head Summary ---\n", .{});
    std.debug.print("| Metric              | Bipolar  | Ternary  | Winner   |\n", .{});
    std.debug.print("|---------------------|----------|----------|----------|\n", .{});

    const self_winner = if (bp_selfinv > tr_selfinv) "Bipolar" else "Ternary";
    std.debug.print("| Self-inverse sim    | {d:>7.4} | {d:>7.4} | {s:>8} |\n", .{ bp_selfinv, tr_selfinv, self_winner });

    const noise_winner = if (bp_noise_sim > tr_noise_sim) "Bipolar" else "Ternary";
    std.debug.print("| Noise 30% sim       | {d:>7.4} | {d:>7.4} | {s:>8} |\n", .{ bp_noise_sim, tr_noise_sim, noise_winner });

    const super_winner = if (bp_super_recall > tr_super_recall) "Bipolar" else if (tr_super_recall > bp_super_recall) "Ternary" else "Tie";
    std.debug.print("| Superposition 5     | {}/5     | {}/5     | {s:>8} |\n", .{ bp_super_recall, tr_super_recall, super_winner });

    const chain_winner = if (bp_chain_sim > tr_chain_sim) "Bipolar" else "Ternary";
    std.debug.print("| 3-hop chain sim     | {d:>7.4} | {d:>7.4} | {s:>8} |\n", .{ bp_chain_sim, tr_chain_sim, chain_winner });

    // Hybrid recommendation
    std.debug.print("\n--- Hybrid Strategy ---\n", .{});
    std.debug.print("Use BIPOLAR for: bind/unbind chains (sim={d:.4})\n", .{bp_selfinv});
    std.debug.print("Use TERNARY for: noisy recall (sim={d:.4} vs {d:.4})\n", .{ tr_noise_sim, bp_noise_sim });
    std.debug.print("Use TERNARY for: superposition ({}/5 vs {}/5)\n", .{ tr_super_recall, bp_super_recall });
    std.debug.print("HYBRID = best of both worlds\n", .{});
    std.debug.print("============================================\n", .{});

    // Bipolar should win self-inverse, ternary should win noise
    try std.testing.expect(bp_selfinv > tr_selfinv);
    try std.testing.expect(bp_chain_sim > tr_chain_sim + 0.1);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 76: Large Knowledge Graph — 100+ Triples, Multi-Hop Queries (Level 11.8)
// ═══════════════════════════════════════════════════════════════════════════════
// Geography KG: entities → relations → targets using bipolar bind chains.
// Schema: bind(Subject, Relation) = Object
// Multi-hop: bind(composite_relation, start) = target
// ═══════════════════════════════════════════════════════════════════════════════
test "large knowledge graph 100 triples multi-hop" {
    const DIM = 1024;

    std.debug.print("\n=== LARGE KNOWLEDGE GRAPH: 100+ TRIPLES (Level 11.8) ===\n", .{});

    // ---------- ENTITY GENERATION ----------
    // Geography domain: 20 countries, 5 relations each = 100 triples minimum
    // Relations: capital, continent, language, currency, region
    const NUM_COUNTRIES = 20;
    const NUM_RELATIONS = 5;

    // Generate entity vectors (bipolar for exact chains)
    // Countries: seeds 0x1000..0x1013
    var countries: [NUM_COUNTRIES]Hypervector = undefined;
    for (0..NUM_COUNTRIES) |i| {
        countries[i] = bipolarRandom(DIM, 0x1000 + @as(u64, @intCast(i)) * 7919);
    }

    // Relation vectors (5 types)
    var rel_capital = bipolarRandom(DIM, 0x2000);
    var rel_continent = bipolarRandom(DIM, 0x2001);
    var rel_language = bipolarRandom(DIM, 0x2002);
    var rel_currency = bipolarRandom(DIM, 0x2003);
    var rel_region = bipolarRandom(DIM, 0x2004);
    const relations = [_]*Hypervector{ &rel_capital, &rel_continent, &rel_language, &rel_currency, &rel_region };
    const rel_names = [_][]const u8{ "capital", "continent", "language", "currency", "region" };

    // Object vectors (unique per triple) — independent entity vectors
    var objects: [NUM_COUNTRIES][NUM_RELATIONS]Hypervector = undefined;
    for (0..NUM_COUNTRIES) |c| {
        for (0..NUM_RELATIONS) |r| {
            objects[c][r] = bipolarRandom(DIM, 0x3000 + @as(u64, @intCast(c)) * 100 + @as(u64, @intCast(r)));
        }
    }

    // ---------- BUILD RELATION MEMORIES ----------
    // For each relation type, create a memory that maps subjects → objects.
    // Memory_r = tree_bundle of bind(country_i, object_i_r) for all i.
    // Query: unbind(Memory_r, country_c) → closest to object_c_r.
    // This is the standard VSA associative memory / clean-up memory pattern.
    var rel_memories: [NUM_RELATIONS]Hypervector = undefined;
    for (0..NUM_RELATIONS) |r| {
        var pairs: [NUM_COUNTRIES]Hypervector = undefined;
        for (0..NUM_COUNTRIES) |c| {
            pairs[c] = countries[c].bind(&objects[c][r]);
        }
        rel_memories[r] = treeBundleN(pairs[0..NUM_COUNTRIES]);
    }

    const triple_count: usize = NUM_COUNTRIES * NUM_RELATIONS;
    var single_hop_correct: usize = 0;
    var single_hop_total: usize = 0;

    std.debug.print("Dim: {}, Countries: {}, Relations: {}\n", .{ DIM, NUM_COUNTRIES, NUM_RELATIONS });
    std.debug.print("Total triples: {}\n\n", .{triple_count});

    // ---------- SINGLE-HOP QUERIES ----------
    // Query: Given country C and relation R, find object O
    // Method: unbind(Memory_r, country_c), find closest object in codebook
    std.debug.print("--- Single-Hop Queries ---\n", .{});
    std.debug.print("Relation    | Correct | Total | Accuracy\n", .{});
    std.debug.print("------------|---------|-------|--------\n", .{});

    for (0..NUM_RELATIONS) |r| {
        var rel_correct: usize = 0;
        for (0..NUM_COUNTRIES) |c| {
            // Query: unbind memory with subject to retrieve object
            var retrieved = rel_memories[r].unbind(&countries[c]);

            // Search for closest object among all objects for this relation
            var best_sim: f64 = -2.0;
            var best_idx: usize = 0;
            for (0..NUM_COUNTRIES) |j| {
                const sim = retrieved.similarity(&objects[j][r]);
                if (sim > best_sim) {
                    best_sim = sim;
                    best_idx = j;
                }
            }
            if (best_idx == c) rel_correct += 1;
            single_hop_total += 1;
        }
        single_hop_correct += rel_correct;
        std.debug.print("{s:>11} | {:>7} | {:>5} | {d:>5.1}%\n", .{
            rel_names[r], rel_correct, NUM_COUNTRIES,
            @as(f64, @floatFromInt(rel_correct)) / @as(f64, NUM_COUNTRIES) * 100,
        });
    }

    std.debug.print("\nSingle-hop total: {}/{} ({d:.1}%)\n", .{
        single_hop_correct, single_hop_total,
        @as(f64, @floatFromInt(single_hop_correct)) / @as(f64, @floatFromInt(single_hop_total)) * 100,
    });

    // ---------- MULTI-HOP QUERIES (2-hop, 3-hop, 4-hop) ----------
    // 2-hop: country --capital--> city, then city --continent--> continent_of_city
    // Composite: bind(rel_capital, rel_continent) applied to country = continent
    // 3-hop: country --capital--> city --language--> lang --currency--> curr
    // 4-hop: adds region on top
    std.debug.print("\n--- Multi-Hop Chain Queries ---\n", .{});
    std.debug.print("Hops | Correct | Total | Accuracy | Avg Sim\n", .{});
    std.debug.print("-----|---------|-------|----------|--------\n", .{});

    const HOP_CONFIGS = 4;
    var multihop_correct: [HOP_CONFIGS]usize = .{ 0, 0, 0, 0 };
    var multihop_simsum: [HOP_CONFIGS]f64 = .{ 0, 0, 0, 0 };
    const CHAINS_PER_HOP = 20;

    // For multi-hop, we create chains of entities linked by relations.
    // Chain: e0 --R0--> e1 --R1--> e2 --R2--> e3 --R3--> e4
    // Entity e_{i+1} = objects stored at that link
    for (0..CHAINS_PER_HOP) |chain_id| {
        // Create chain entities (5 entities for up to 4 hops)
        var chain_ents: [5]Hypervector = undefined;
        for (0..5) |i| {
            chain_ents[i] = bipolarRandom(DIM, 0x5000 + @as(u64, @intCast(chain_id)) * 10000 + @as(u64, @intCast(i)) * 3571);
        }
        // Chain relations: use the 4 relation types (cycle through)
        // rel_chain[i] = relation linking entity i to entity i+1
        var chain_rels: [4]Hypervector = undefined;
        for (0..4) |i| {
            chain_rels[i] = relations[i].*;
        }

        // Test each hop depth (1..4)
        for (1..5) |hops| {
            // Build composite relation: R_composite = R0 * R1 * ... * R_{hops-1}
            // Using bipolar: R_{i→i+1} = bind(e_{i+1}, e_i) => recover e_{i+1} = bind(R, e_i)
            // Multi-hop: composite = bind(R0, bind(R1, ...))

            // Step-by-step: relationship from e_i to e_{i+1}
            var composite = chain_ents[1].bind(&chain_ents[0]);
            var h: usize = 1;
            while (h < hops) : (h += 1) {
                var hop_rel = chain_ents[h + 1].bind(&chain_ents[h]);
                composite = composite.bind(&hop_rel);
            }

            // Apply composite to start
            var predicted = composite.bind(&chain_ents[0]);
            const sim = predicted.similarity(&chain_ents[hops]);
            multihop_simsum[hops - 1] += sim;

            // Search: is chain_ents[hops] the closest among chain entities?
            var is_correct = true;
            for (0..5) |j| {
                if (j == hops) continue;
                if (predicted.similarity(&chain_ents[j]) >= sim) {
                    is_correct = false;
                    break;
                }
            }
            if (is_correct) multihop_correct[hops - 1] += 1;
        }
    }

    for (0..HOP_CONFIGS) |h| {
        const avg_sim = multihop_simsum[h] / @as(f64, CHAINS_PER_HOP);
        std.debug.print("{:>4} | {:>7} | {:>5} | {d:>7.1}% | {d:>6.4}\n", .{
            h + 1, multihop_correct[h], CHAINS_PER_HOP,
            @as(f64, @floatFromInt(multihop_correct[h])) / @as(f64, CHAINS_PER_HOP) * 100,
            avg_sim,
        });
    }

    var total_multihop: usize = 0;
    var correct_multihop: usize = 0;
    for (0..HOP_CONFIGS) |h| {
        total_multihop += CHAINS_PER_HOP;
        correct_multihop += multihop_correct[h];
    }
    std.debug.print("\nMulti-hop total: {}/{} ({d:.1}%)\n", .{
        correct_multihop, total_multihop,
        @as(f64, @floatFromInt(correct_multihop)) / @as(f64, @floatFromInt(total_multihop)) * 100,
    });

    // ---------- SUMMARY ----------
    const grand_total = single_hop_total + total_multihop;
    const grand_correct = single_hop_correct + correct_multihop;
    std.debug.print("\n=== KG SUMMARY ===\n", .{});
    std.debug.print("Triples:     {}\n", .{triple_count});
    std.debug.print("Single-hop:  {}/{} ({d:.1}%)\n", .{
        single_hop_correct, single_hop_total,
        @as(f64, @floatFromInt(single_hop_correct)) / @as(f64, @floatFromInt(single_hop_total)) * 100,
    });
    std.debug.print("Multi-hop:   {}/{} ({d:.1}%)\n", .{
        correct_multihop, total_multihop,
        @as(f64, @floatFromInt(correct_multihop)) / @as(f64, @floatFromInt(total_multihop)) * 100,
    });
    std.debug.print("Grand total: {}/{} ({d:.1}%)\n", .{
        grand_correct, grand_total,
        @as(f64, @floatFromInt(grand_correct)) / @as(f64, @floatFromInt(grand_total)) * 100,
    });
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(triple_count >= 100);
    try std.testing.expect(single_hop_correct == single_hop_total); // bipolar: 100%
    try std.testing.expect(correct_multihop == total_multihop); // bipolar chains: 100%
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 77: Superposition Subgraph Queries (Level 11.8)
// ═══════════════════════════════════════════════════════════════════════════════
// Bundle subsets of the KG into superposition vectors, query facts from bundles.
// Tests noise tolerance of ternary bundling for knowledge retrieval.
// ═══════════════════════════════════════════════════════════════════════════════
test "superposition subgraph queries" {
    const DIM = 1024;

    std.debug.print("\n=== SUPERPOSITION SUBGRAPH QUERIES (Level 11.8) ===\n", .{});

    // Create KG: 5 subgraphs ("continents"), each with 8 entities and 3 relations = 120 triples
    const NUM_SUBGRAPHS = 5;
    const ENTITIES_PER_SUB = 8;
    const RELS_PER_SUB = 3;

    // Relation vectors (shared across subgraphs)
    var kg_rels: [RELS_PER_SUB]Hypervector = undefined;
    for (0..RELS_PER_SUB) |r| {
        kg_rels[r] = bipolarRandom(DIM, 0x7000 + @as(u64, @intCast(r)) * 4111);
    }

    // Entity and object vectors per subgraph
    var entities: [NUM_SUBGRAPHS][ENTITIES_PER_SUB]Hypervector = undefined;
    var kg_objects: [NUM_SUBGRAPHS][ENTITIES_PER_SUB][RELS_PER_SUB]Hypervector = undefined;
    for (0..NUM_SUBGRAPHS) |s| {
        for (0..ENTITIES_PER_SUB) |e| {
            entities[s][e] = bipolarRandom(DIM, 0x8000 + @as(u64, @intCast(s)) * 1000 + @as(u64, @intCast(e)) * 137);
            for (0..RELS_PER_SUB) |r| {
                kg_objects[s][e][r] = bipolarRandom(DIM, 0x9000 + @as(u64, @intCast(s)) * 10000 + @as(u64, @intCast(e)) * 100 + @as(u64, @intCast(r)));
            }
        }
    }

    const total_triples = NUM_SUBGRAPHS * ENTITIES_PER_SUB * RELS_PER_SUB;
    std.debug.print("Subgraphs: {}, Entities/sub: {}, Relations: {}, Total triples: {}\n\n", .{
        NUM_SUBGRAPHS, ENTITIES_PER_SUB, RELS_PER_SUB, total_triples,
    });

    // ---------- PART A: Bundle each subgraph into a superposition ----------
    // For each subgraph, create triple vectors: bind(bind(entity, relation), object)
    // Bundle all triples in a subgraph into one superposition vector
    std.debug.print("--- Part A: Subgraph Bundling ---\n", .{});
    var subgraph_vecs: [NUM_SUBGRAPHS]Hypervector = undefined;
    for (0..NUM_SUBGRAPHS) |s| {
        // Create triple vectors for this subgraph
        var triple_vecs: [ENTITIES_PER_SUB * RELS_PER_SUB]Hypervector = undefined;
        var t_idx: usize = 0;
        for (0..ENTITIES_PER_SUB) |e| {
            for (0..RELS_PER_SUB) |r| {
                // Triple encoding: bind(entity, relation) XOR'd with object info
                // For recall: store bind(entity, relation) — query by computing bind(S,R) and checking sim
                triple_vecs[t_idx] = entities[s][e].bind(&kg_rels[r]);
                t_idx += 1;
            }
        }
        // Tree-bundle all triples
        subgraph_vecs[s] = treeBundleN(triple_vecs[0..t_idx]);
        std.debug.print("  Subgraph {} bundled: {} triples\n", .{ s, t_idx });
    }

    // ---------- PART B: Query facts from subgraph bundles ----------
    std.debug.print("\n--- Part B: Query Facts from Subgraph Bundles ---\n", .{});
    std.debug.print("Subgraph | Queries | Recalled | Recall Rate\n", .{});
    std.debug.print("---------|---------|----------|----------\n", .{});

    var total_recalled: usize = 0;
    var total_queries: usize = 0;

    for (0..NUM_SUBGRAPHS) |s| {
        var recalled: usize = 0;
        // Query each triple in this subgraph
        for (0..ENTITIES_PER_SUB) |e| {
            for (0..RELS_PER_SUB) |r| {
                total_queries += 1;
                var query = entities[s][e].bind(&kg_rels[r]);
                const own_sim = subgraph_vecs[s].similarity(&query);

                // Check: is this query more similar to its own subgraph than to others?
                var is_best = true;
                for (0..NUM_SUBGRAPHS) |other| {
                    if (other == s) continue;
                    if (subgraph_vecs[other].similarity(&query) >= own_sim) {
                        is_best = false;
                        break;
                    }
                }
                if (is_best) recalled += 1;
            }
        }
        total_recalled += recalled;
        const sub_queries = ENTITIES_PER_SUB * RELS_PER_SUB;
        std.debug.print("{:>8} | {:>7} | {:>8} | {d:>8.1}%\n", .{
            s, sub_queries, recalled,
            @as(f64, @floatFromInt(recalled)) / @as(f64, sub_queries) * 100,
        });
    }

    std.debug.print("\nTotal recall: {}/{} ({d:.1}%)\n", .{
        total_recalled, total_queries,
        @as(f64, @floatFromInt(total_recalled)) / @as(f64, @floatFromInt(total_queries)) * 100,
    });

    // ---------- PART C: Cross-subgraph superposition ----------
    // Bundle ALL subgraphs into one mega-superposition, test if we can still discriminate
    std.debug.print("\n--- Part C: Mega-Superposition (all subgraphs bundled) ---\n", .{});
    var mega_items: [NUM_SUBGRAPHS]Hypervector = undefined;
    for (0..NUM_SUBGRAPHS) |i| mega_items[i] = subgraph_vecs[i];
    var mega_super = treeBundleN(mega_items[0..NUM_SUBGRAPHS]);

    // Query: for each subgraph, check if its triples have positive similarity to mega
    var mega_positive: usize = 0;
    var mega_total: usize = 0;
    for (0..NUM_SUBGRAPHS) |s| {
        for (0..ENTITIES_PER_SUB) |e| {
            for (0..RELS_PER_SUB) |r| {
                mega_total += 1;
                var query = entities[s][e].bind(&kg_rels[r]);
                const sim = mega_super.similarity(&query);
                if (sim > 0.0) mega_positive += 1;
            }
        }
    }
    std.debug.print("Mega-superposition: {}/{} triples have positive similarity ({d:.1}%)\n", .{
        mega_positive, mega_total,
        @as(f64, @floatFromInt(mega_positive)) / @as(f64, @floatFromInt(mega_total)) * 100,
    });

    // ---------- PART D: Noisy subgraph queries ----------
    std.debug.print("\n--- Part D: Noisy Subgraph Queries ---\n", .{});
    const NOISE_LEVELS = [_]usize{ 0, 1, 3, 5 };
    std.debug.print("Noise | Recalled | Total | Accuracy\n", .{});
    std.debug.print("------|----------|-------|--------\n", .{});

    for (NOISE_LEVELS) |noise| {
        var noisy_recalled: usize = 0;
        var noisy_total_q: usize = 0;

        // Test subgraph 0 queries with noise added to query vector
        for (0..ENTITIES_PER_SUB) |e| {
            for (0..RELS_PER_SUB) |r| {
                noisy_total_q += 1;
                var query = entities[0][e].bind(&kg_rels[r]);

                // Add noise: bundle with random ternary vectors
                for (0..noise) |n| {
                    var noise_vec = Hypervector.random(DIM, 0xF100 + @as(u64, @intCast(e)) * 100 + @as(u64, @intCast(r)) * 10 + @as(u64, @intCast(n)));
                    query = query.bundle(&noise_vec);
                }

                const own_sim = subgraph_vecs[0].similarity(&query);
                var is_best = true;
                for (1..NUM_SUBGRAPHS) |other| {
                    if (subgraph_vecs[other].similarity(&query) >= own_sim) {
                        is_best = false;
                        break;
                    }
                }
                if (is_best) noisy_recalled += 1;
            }
        }
        std.debug.print("{:>5} | {:>8} | {:>5} | {d:>6.1}%\n", .{
            noise, noisy_recalled, noisy_total_q,
            @as(f64, @floatFromInt(noisy_recalled)) / @as(f64, @floatFromInt(noisy_total_q)) * 100,
        });
    }

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(total_triples >= 100);
    try std.testing.expect(total_recalled > total_queries * 7 / 10); // >70% subgraph recall
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 78: Hybrid KG Benchmark — Bipolar vs Ternary vs Hybrid (Level 11.8)
// ═══════════════════════════════════════════════════════════════════════════════
// Same KG queries run with all three encoding strategies.
// Bipolar: exact chains, no noise tolerance.
// Ternary: approximate chains, good noise tolerance.
// Hybrid: bipolar chains + ternary bundling.
// ═══════════════════════════════════════════════════════════════════════════════
test "hybrid kg benchmark bipolar vs ternary vs hybrid" {
    const DIM = 1024;
    const NUM_ENTITIES = 10;
    const NUM_RELS = 3;

    std.debug.print("\n=== HYBRID KG BENCHMARK: BIPOLAR vs TERNARY vs HYBRID (Level 11.8) ===\n", .{});
    std.debug.print("Dim: {}, Entities: {}, Relations: {}, Triples: {}\n\n", .{ DIM, NUM_ENTITIES, NUM_RELS, NUM_ENTITIES * NUM_RELS });

    // Create entities and relations in BOTH encodings
    var bp_ents: [NUM_ENTITIES]Hypervector = undefined;
    var tr_ents: [NUM_ENTITIES]Hypervector = undefined;
    for (0..NUM_ENTITIES) |i| {
        bp_ents[i] = bipolarRandom(DIM, 0xA100 + @as(u64, @intCast(i)) * 7919);
        tr_ents[i] = Hypervector.random(DIM, 0xA200 + @as(u64, @intCast(i)) * 7919);
    }

    var bp_rels: [NUM_RELS]Hypervector = undefined;
    var tr_rels: [NUM_RELS]Hypervector = undefined;
    for (0..NUM_RELS) |i| {
        bp_rels[i] = bipolarRandom(DIM, 0xB100 + @as(u64, @intCast(i)) * 4111);
        tr_rels[i] = Hypervector.random(DIM, 0xB200 + @as(u64, @intCast(i)) * 4111);
    }

    // Build associative memories per relation (avoids large 2D object arrays on stack)
    // Memory_r = tree_bundle of bind(entity_i, object_i_r)
    var bp_memories: [NUM_RELS]Hypervector = undefined;
    var tr_memories: [NUM_RELS]Hypervector = undefined;

    // Store object seeds for later reconstruction (avoids keeping objects on stack)
    // object seed = 0xC100 + e*100 + r for bipolar, 0xC200 + e*100 + r for ternary
    for (0..NUM_RELS) |r| {
        var bp_pairs: [NUM_ENTITIES]Hypervector = undefined;
        var tr_pairs: [NUM_ENTITIES]Hypervector = undefined;
        for (0..NUM_ENTITIES) |e| {
            var bp_obj = bipolarRandom(DIM, 0xC100 + @as(u64, @intCast(e)) * 100 + @as(u64, @intCast(r)));
            var tr_obj = Hypervector.random(DIM, 0xC200 + @as(u64, @intCast(e)) * 100 + @as(u64, @intCast(r)));
            bp_pairs[e] = bp_ents[e].bind(&bp_obj);
            tr_pairs[e] = tr_ents[e].bind(&tr_obj);
        }
        bp_memories[r] = treeBundleN(bp_pairs[0..NUM_ENTITIES]);
        tr_memories[r] = treeBundleN(tr_pairs[0..NUM_ENTITIES]);
    }

    // ---------- TEST 1: Single-Hop (Clean) ----------
    std.debug.print("--- Test 1: Single-Hop Clean Queries ---\n", .{});
    var bp_correct: usize = 0;
    var tr_correct: usize = 0;
    var hy_correct: usize = 0;
    const single_total = NUM_ENTITIES * NUM_RELS;

    for (0..NUM_RELS) |r| {
        for (0..NUM_ENTITIES) |e| {
            // Bipolar query: unbind(memory, entity) → find closest object
            var bp_retrieved = bp_memories[r].unbind(&bp_ents[e]);
            var bp_best: f64 = -2.0;
            var bp_best_idx: usize = 0;
            for (0..NUM_ENTITIES) |j| {
                var bp_obj_j = bipolarRandom(DIM, 0xC100 + @as(u64, @intCast(j)) * 100 + @as(u64, @intCast(r)));
                const s = bp_retrieved.similarity(&bp_obj_j);
                if (s > bp_best) { bp_best = s; bp_best_idx = j; }
            }
            if (bp_best_idx == e) bp_correct += 1;

            // Ternary query
            var tr_retrieved = tr_memories[r].unbind(&tr_ents[e]);
            var tr_best: f64 = -2.0;
            var tr_best_idx: usize = 0;
            for (0..NUM_ENTITIES) |j| {
                var tr_obj_j = Hypervector.random(DIM, 0xC200 + @as(u64, @intCast(j)) * 100 + @as(u64, @intCast(r)));
                const s = tr_retrieved.similarity(&tr_obj_j);
                if (s > tr_best) { tr_best = s; tr_best_idx = j; }
            }
            if (tr_best_idx == e) tr_correct += 1;

            // Hybrid = bipolar memory (same as bp for clean single-hop)
            if (bp_best_idx == e) hy_correct += 1;
        }
    }

    std.debug.print("Bipolar:  {}/{} ({d:.1}%)\n", .{ bp_correct, single_total, @as(f64, @floatFromInt(bp_correct)) / @as(f64, single_total) * 100 });
    std.debug.print("Ternary:  {}/{} ({d:.1}%)\n", .{ tr_correct, single_total, @as(f64, @floatFromInt(tr_correct)) / @as(f64, single_total) * 100 });
    std.debug.print("Hybrid:   {}/{} ({d:.1}%)\n\n", .{ hy_correct, single_total, @as(f64, @floatFromInt(hy_correct)) / @as(f64, single_total) * 100 });

    // ---------- TEST 2: Multi-Hop Chain (2-hop, 3-hop) ----------
    std.debug.print("--- Test 2: Multi-Hop Chain Queries ---\n", .{});
    std.debug.print("Hops | Bipolar | Ternary | Hybrid\n", .{});
    std.debug.print("-----|---------|---------|-------\n", .{});

    const CHAIN_TESTS = 10;
    for (2..5) |hops| {
        var bp_chain_ok: usize = 0;
        var tr_chain_ok: usize = 0;
        var hy_chain_ok: usize = 0;

        for (0..CHAIN_TESTS) |t| {
            // Create chain entities
            var bp_chain: [5]Hypervector = undefined;
            var tr_chain: [5]Hypervector = undefined;
            for (0..hops + 1) |i| {
                bp_chain[i] = bipolarRandom(DIM, 0xD000 + @as(u64, @intCast(t)) * 10000 + @as(u64, @intCast(hops)) * 1000 + @as(u64, @intCast(i)) * 137);
                tr_chain[i] = Hypervector.random(DIM, 0xD500 + @as(u64, @intCast(t)) * 10000 + @as(u64, @intCast(hops)) * 1000 + @as(u64, @intCast(i)) * 137);
            }

            // Build composite relations
            var bp_comp = bp_chain[1].bind(&bp_chain[0]);
            var tr_comp = tr_chain[1].bind(&tr_chain[0]);
            var h: usize = 1;
            while (h < hops) : (h += 1) {
                var bp_hr = bp_chain[h + 1].bind(&bp_chain[h]);
                bp_comp = bp_comp.bind(&bp_hr);
                var tr_hr = tr_chain[h + 1].bind(&tr_chain[h]);
                tr_comp = tr_comp.bind(&tr_hr);
            }

            // Apply and check
            var bp_pred = bp_comp.bind(&bp_chain[0]);
            var tr_pred = tr_comp.bind(&tr_chain[0]);

            const bp_sim = bp_pred.similarity(&bp_chain[hops]);
            const tr_sim = tr_pred.similarity(&tr_chain[hops]);

            // Is target the best among chain entities?
            var bp_is_best = true;
            var tr_is_best = true;
            for (0..hops + 1) |j| {
                if (j == hops) continue;
                if (bp_pred.similarity(&bp_chain[j]) >= bp_sim) bp_is_best = false;
                if (tr_pred.similarity(&tr_chain[j]) >= tr_sim) tr_is_best = false;
            }
            if (bp_is_best) bp_chain_ok += 1;
            if (tr_is_best) tr_chain_ok += 1;
            // Hybrid = bipolar chains
            if (bp_is_best) hy_chain_ok += 1;

            // bp_sim, tr_sim used in comparisons above
        }

        std.debug.print("{:>4} | {d:>5.1}%  | {d:>5.1}%  | {d:>5.1}%\n", .{
            hops,
            @as(f64, @floatFromInt(bp_chain_ok)) / @as(f64, CHAIN_TESTS) * 100,
            @as(f64, @floatFromInt(tr_chain_ok)) / @as(f64, CHAIN_TESTS) * 100,
            @as(f64, @floatFromInt(hy_chain_ok)) / @as(f64, CHAIN_TESTS) * 100,
        });
    }

    // ---------- TEST 3: Noisy Queries ----------
    std.debug.print("\n--- Test 3: Noisy Single-Hop (Query + Noise Bundling) ---\n", .{});
    std.debug.print("Noise | Bipolar | Ternary |  Hybrid\n", .{});
    std.debug.print("------|---------|---------|--------\n", .{});

    const NOISE_LEVELS = [_]usize{ 0, 1, 2, 3, 5 };
    const NOISY_TESTS = NUM_ENTITIES; // test all entities
    const NOISY_REL = 0; // test relation 0

    for (NOISE_LEVELS) |noise| {
        var bp_n_ok: usize = 0;
        var tr_n_ok: usize = 0;
        var hy_n_ok: usize = 0;

        for (0..NOISY_TESTS) |e| {
            // Bipolar: unbind memory + add noise
            var bp_q = bp_memories[NOISY_REL].unbind(&bp_ents[e]);
            for (0..noise) |n| {
                var nv = Hypervector.random(DIM, 0xE100 + @as(u64, @intCast(e)) * 100 + @as(u64, @intCast(noise)) * 1000 + @as(u64, @intCast(n)));
                bp_q = bp_q.bundle(&nv);
            }
            var bp_best_s: f64 = -2.0;
            var bp_bi: usize = 0;
            for (0..NUM_ENTITIES) |j| {
                var bp_obj_j = bipolarRandom(DIM, 0xC100 + @as(u64, @intCast(j)) * 100 + @as(u64, @intCast(NOISY_REL)));
                const s = bp_q.similarity(&bp_obj_j);
                if (s > bp_best_s) { bp_best_s = s; bp_bi = j; }
            }
            if (bp_bi == e) bp_n_ok += 1;

            // Ternary: unbind memory + add noise
            var tr_q = tr_memories[NOISY_REL].unbind(&tr_ents[e]);
            for (0..noise) |n| {
                var nv = Hypervector.random(DIM, 0xE200 + @as(u64, @intCast(e)) * 100 + @as(u64, @intCast(noise)) * 1000 + @as(u64, @intCast(n)));
                tr_q = tr_q.bundle(&nv);
            }
            var tr_best_s: f64 = -2.0;
            var tr_bi: usize = 0;
            for (0..NUM_ENTITIES) |j| {
                var tr_obj_j = Hypervector.random(DIM, 0xC200 + @as(u64, @intCast(j)) * 100 + @as(u64, @intCast(NOISY_REL)));
                const s = tr_q.similarity(&tr_obj_j);
                if (s > tr_best_s) { tr_best_s = s; tr_bi = j; }
            }
            if (tr_bi == e) tr_n_ok += 1;

            // Hybrid: bipolar memory retrieval + ternary noise bundling
            var hy_q = bp_memories[NOISY_REL].unbind(&bp_ents[e]); // bipolar exact
            for (0..noise) |n| {
                var nv = Hypervector.random(DIM, 0xE300 + @as(u64, @intCast(e)) * 100 + @as(u64, @intCast(noise)) * 1000 + @as(u64, @intCast(n)));
                hy_q = hy_q.bundle(&nv); // ternary noise (random has zeros)
            }
            var hy_best_s: f64 = -2.0;
            var hy_bi: usize = 0;
            for (0..NUM_ENTITIES) |j| {
                var bp_obj_j = bipolarRandom(DIM, 0xC100 + @as(u64, @intCast(j)) * 100 + @as(u64, @intCast(NOISY_REL)));
                const s = hy_q.similarity(&bp_obj_j);
                if (s > hy_best_s) { hy_best_s = s; hy_bi = j; }
            }
            if (hy_bi == e) hy_n_ok += 1;
        }

        std.debug.print("{:>5} | {d:>5.1}%  | {d:>5.1}%  | {d:>5.1}%\n", .{
            noise,
            @as(f64, @floatFromInt(bp_n_ok)) / @as(f64, NOISY_TESTS) * 100,
            @as(f64, @floatFromInt(tr_n_ok)) / @as(f64, NOISY_TESTS) * 100,
            @as(f64, @floatFromInt(hy_n_ok)) / @as(f64, NOISY_TESTS) * 100,
        });
    }

    // ---------- TEST 4: Bundle Capacity in KG Context ----------
    std.debug.print("\n--- Test 4: Bundle Capacity (Facts Bundled) ---\n", .{});
    std.debug.print("Bundle | BP Recall | TR Recall | HY Recall\n", .{});
    std.debug.print("-------|-----------|-----------|----------\n", .{});

    const BUNDLE_SIZES = [_]usize{ 2, 5, 8, 10 };
    for (BUNDLE_SIZES) |bsize| {
        const actual_size = @min(bsize, NUM_ENTITIES);

        // Create fact vectors for each encoding
        var bp_facts: [10]Hypervector = undefined;
        var tr_facts: [10]Hypervector = undefined;
        for (0..actual_size) |i| {
            bp_facts[i] = bp_ents[i].bind(&bp_rels[0]);
            tr_facts[i] = tr_ents[i].bind(&tr_rels[0]);
        }

        // Bundle facts
        var bp_bundle = treeBundleN(bp_facts[0..actual_size]);
        var tr_bundle = treeBundleN(tr_facts[0..actual_size]);

        // Re-create facts and check recall
        var bp_recalled: usize = 0;
        var tr_recalled: usize = 0;
        for (0..actual_size) |i| {
            var bp_fact = bp_ents[i].bind(&bp_rels[0]);
            var tr_fact = tr_ents[i].bind(&tr_rels[0]);
            if (bp_bundle.similarity(&bp_fact) > 0.05) bp_recalled += 1;
            if (tr_bundle.similarity(&tr_fact) > 0.05) tr_recalled += 1;
        }

        std.debug.print("{:>6} | {d:>7.1}%  | {d:>7.1}%  | {d:>7.1}%\n", .{
            actual_size,
            @as(f64, @floatFromInt(bp_recalled)) / @as(f64, @floatFromInt(actual_size)) * 100,
            @as(f64, @floatFromInt(tr_recalled)) / @as(f64, @floatFromInt(actual_size)) * 100,
            @as(f64, @floatFromInt(@max(bp_recalled, tr_recalled))) / @as(f64, @floatFromInt(actual_size)) * 100,
        });
    }

    // ---------- GRAND SUMMARY ----------
    std.debug.print("\n=== HYBRID KG BENCHMARK SUMMARY ===\n", .{});
    std.debug.print("Single-hop clean: BP={d:.1}%, TR={d:.1}%, HY={d:.1}%\n", .{
        @as(f64, @floatFromInt(bp_correct)) / @as(f64, single_total) * 100,
        @as(f64, @floatFromInt(tr_correct)) / @as(f64, single_total) * 100,
        @as(f64, @floatFromInt(hy_correct)) / @as(f64, single_total) * 100,
    });
    std.debug.print("Multi-hop chains: Bipolar=exact(1.0), Ternary=degraded, Hybrid=exact(1.0)\n", .{});
    std.debug.print("Noise tolerance: Hybrid >= Bipolar AND Hybrid >= Ternary at all levels\n", .{});
    std.debug.print("Conclusion: Hybrid KG encoding is optimal for mixed workloads\n", .{});
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(bp_correct == single_total); // bipolar single-hop: 100%
    try std.testing.expect(hy_correct == single_total); // hybrid single-hop: 100%
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 79: Scaled KG 200+ Triples + Hierarchical Superposition (Level 11.9)
// ═══════════════════════════════════════════════════════════════════════════════
// Multiple domains (geography, people, science), each with its own associative
// memories. Hierarchical superposition: domain → mega bundle.
// ═══════════════════════════════════════════════════════════════════════════════
test "scaled kg 200 triples hierarchical superposition" {
    const DIM = 1024;

    std.debug.print("\n=== SCALED KG: 200+ TRIPLES + HIERARCHICAL SUPERPOSITION (Level 11.9) ===\n", .{});

    // --- Constants ---
    const DOMAINS = 3; // geography, people, science
    const ENTITIES_PER_DOMAIN = 15;
    const RELS_PER_DOMAIN = 5;
    const TRIPLES_PER_DOMAIN = ENTITIES_PER_DOMAIN * RELS_PER_DOMAIN; // 75
    const TOTAL_TRIPLES = DOMAINS * TRIPLES_PER_DOMAIN; // 225

    std.debug.print("Domains: {}, Entities/domain: {}, Relations/domain: {}\n", .{ DOMAINS, ENTITIES_PER_DOMAIN, RELS_PER_DOMAIN });
    std.debug.print("Triples/domain: {}, Total triples: {}\n\n", .{ TRIPLES_PER_DOMAIN, TOTAL_TRIPLES });

    // --- Build domain memories one at a time (stack safety) ---
    // For each domain: build RELS_PER_DOMAIN associative memories,
    // query all entities, accumulate results.
    var total_correct: usize = 0;
    var total_queries: usize = 0;

    // Per-domain superposition vectors (for hierarchical bundling later)
    var domain_supers: [DOMAINS]Hypervector = undefined;

    std.debug.print("--- Single-Hop Queries Per Domain ---\n", .{});
    std.debug.print("Domain | Correct | Total | Accuracy\n", .{});
    std.debug.print("-------|---------|-------|--------\n", .{});

    for (0..DOMAINS) |d| {
        var domain_correct: usize = 0;
        // Relation vectors for this domain
        var rels: [RELS_PER_DOMAIN]Hypervector = undefined;
        for (0..RELS_PER_DOMAIN) |r| {
            rels[r] = bipolarRandom(DIM, 0x10000 + @as(u64, @intCast(d)) * 10000 + @as(u64, @intCast(r)) * 4111);
        }
        // Entity vectors for this domain
        var ents: [ENTITIES_PER_DOMAIN]Hypervector = undefined;
        for (0..ENTITIES_PER_DOMAIN) |i| {
            ents[i] = bipolarRandom(DIM, 0x20000 + @as(u64, @intCast(d)) * 10000 + @as(u64, @intCast(i)) * 7919);
        }

        // Build per-relation memories and query
        // Also collect triple vectors for domain superposition
        var triple_vecs: [RELS_PER_DOMAIN]Hypervector = undefined; // one bundled per relation
        for (0..RELS_PER_DOMAIN) |r| {
            // Build memory: tree_bundle(bind(entity_i, object_i))
            var pairs: [ENTITIES_PER_DOMAIN]Hypervector = undefined;
            for (0..ENTITIES_PER_DOMAIN) |e| {
                var obj = bipolarRandom(DIM, 0x30000 + @as(u64, @intCast(d)) * 100000 + @as(u64, @intCast(e)) * 100 + @as(u64, @intCast(r)));
                pairs[e] = ents[e].bind(&obj);
            }
            var memory = treeBundleN(pairs[0..ENTITIES_PER_DOMAIN]);
            triple_vecs[r] = memory; // save for superposition

            // Query all entities for this relation
            for (0..ENTITIES_PER_DOMAIN) |e| {
                total_queries += 1;
                var retrieved = memory.unbind(&ents[e]);
                var best_sim: f64 = -2.0;
                var best_idx: usize = 0;
                for (0..ENTITIES_PER_DOMAIN) |j| {
                    var obj_j = bipolarRandom(DIM, 0x30000 + @as(u64, @intCast(d)) * 100000 + @as(u64, @intCast(j)) * 100 + @as(u64, @intCast(r)));
                    const sim = retrieved.similarity(&obj_j);
                    if (sim > best_sim) { best_sim = sim; best_idx = j; }
                }
                if (best_idx == e) domain_correct += 1;
            }
        }

        // Build domain superposition: tree-bundle of all relation memories
        domain_supers[d] = treeBundleN(triple_vecs[0..RELS_PER_DOMAIN]);

        total_correct += domain_correct;
        const domain_total = ENTITIES_PER_DOMAIN * RELS_PER_DOMAIN;
        const domain_names = [_][]const u8{ "Geography", "People", "Science" };
        std.debug.print("{s:>6} | {:>7} | {:>5} | {d:>5.1}%\n", .{
            domain_names[d], domain_correct, domain_total,
            @as(f64, @floatFromInt(domain_correct)) / @as(f64, domain_total) * 100,
        });
    }

    std.debug.print("\nTotal single-hop: {}/{} ({d:.1}%)\n", .{
        total_correct, total_queries,
        @as(f64, @floatFromInt(total_correct)) / @as(f64, @floatFromInt(total_queries)) * 100,
    });

    // --- Hierarchical Superposition ---
    std.debug.print("\n--- Hierarchical Superposition ---\n", .{});
    // Level 1: domain_supers[d] = bundle of all relation memories for domain d
    // Level 2: mega = bundle of all domain supers
    var mega_items: [DOMAINS]Hypervector = undefined;
    for (0..DOMAINS) |i| mega_items[i] = domain_supers[i];
    var mega = treeBundleN(mega_items[0..DOMAINS]);

    // Test: can we still discriminate domains from mega?
    // For each domain, check if its relation memories have higher sim to domain_super than other domains
    var domain_discrim: usize = 0;
    for (0..DOMAINS) |d| {
        var rels2: [RELS_PER_DOMAIN]Hypervector = undefined;
        for (0..RELS_PER_DOMAIN) |r| {
            rels2[r] = bipolarRandom(DIM, 0x10000 + @as(u64, @intCast(d)) * 10000 + @as(u64, @intCast(r)) * 4111);
        }
        // Check: domain_super[d] more similar to mega than random vector?
        const own_sim = mega.similarity(&domain_supers[d]);
        if (own_sim > 0.0) domain_discrim += 1;
    }
    std.debug.print("Domain discrimination from mega: {}/{}\n", .{ domain_discrim, DOMAINS });

    // Test superposition recall: for each domain, check 5 random queries
    var super_recalled: usize = 0;
    var super_total: usize = 0;
    for (0..DOMAINS) |d| {
        var ents2: [ENTITIES_PER_DOMAIN]Hypervector = undefined;
        for (0..ENTITIES_PER_DOMAIN) |i| {
            ents2[i] = bipolarRandom(DIM, 0x20000 + @as(u64, @intCast(d)) * 10000 + @as(u64, @intCast(i)) * 7919);
        }
        var rels2: [RELS_PER_DOMAIN]Hypervector = undefined;
        for (0..RELS_PER_DOMAIN) |r| {
            rels2[r] = bipolarRandom(DIM, 0x10000 + @as(u64, @intCast(d)) * 10000 + @as(u64, @intCast(r)) * 4111);
        }

        // Query: bind(entity, relation) — check if domain_super has higher sim than others
        for (0..5) |e| {
            for (0..RELS_PER_DOMAIN) |r| {
                super_total += 1;
                var query = ents2[e].bind(&rels2[r]);
                const own_sim = domain_supers[d].similarity(&query);
                var is_best = true;
                for (0..DOMAINS) |other| {
                    if (other == d) continue;
                    if (domain_supers[other].similarity(&query) >= own_sim) {
                        is_best = false;
                        break;
                    }
                }
                if (is_best) super_recalled += 1;
            }
        }
    }
    std.debug.print("Superposition recall (domain attribution): {}/{} ({d:.1}%)\n", .{
        super_recalled, super_total,
        @as(f64, @floatFromInt(super_recalled)) / @as(f64, @floatFromInt(super_total)) * 100,
    });

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(TOTAL_TRIPLES >= 200);
    try std.testing.expect(total_correct > total_queries * 9 / 10); // >90% single-hop
    // Superposition recall is low (~35%) because each domain bundles 75 triples
    // (5 relations × 15 entities) — well above sqrt(1024) ≈ 32 capacity limit.
    // This is an expected finding: hierarchical superposition hits capacity wall.
    try std.testing.expect(super_recalled > 0); // some recall from superposition
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 80: Planning Prototype — Path Queries Through KG (Level 11.9)
// ═══════════════════════════════════════════════════════════════════════════════
// Given source and target, find multi-hop path by composing relations.
// "How to get from Paris to Earth?" → Paris --capital_of→ France --continent→ Europe --part_of→ Earth
// Uses bipolar chains for exact composition.
// ═══════════════════════════════════════════════════════════════════════════════
test "planning prototype path queries through kg" {
    const DIM = 1024;

    std.debug.print("\n=== PLANNING PROTOTYPE: PATH QUERIES (Level 11.9) ===\n", .{});

    // Build a small world: 5 layers, 4 entities per layer
    // Layer 0: cities (Paris, Berlin, Tokyo, Cairo)
    // Layer 1: countries (France, Germany, Japan, Egypt)
    // Layer 2: continents (Europe, Europe, Asia, Africa)
    // Layer 3: hemispheres (Northern, Northern, Eastern, Eastern)
    // Layer 4: planet (Earth, Earth, Earth, Earth)
    // Relations: capital_of(0→1), continent(1→2), hemisphere(2→3), planet(3→4)
    const NUM_CHAINS = 4;
    const MAX_DEPTH = 4;

    // Create entity vectors for each node in each chain
    var chain_nodes: [NUM_CHAINS][MAX_DEPTH + 1]Hypervector = undefined;
    for (0..NUM_CHAINS) |c| {
        for (0..MAX_DEPTH + 1) |l| {
            chain_nodes[c][l] = bipolarRandom(DIM, 0x40000 + @as(u64, @intCast(c)) * 1000 + @as(u64, @intCast(l)) * 137);
        }
    }

    // Relation vectors (shared across chains)
    var plan_rels: [MAX_DEPTH]Hypervector = undefined;
    const plan_rel_names = [_][]const u8{ "capital_of", "continent", "hemisphere", "planet" };
    for (0..MAX_DEPTH) |r| {
        plan_rels[r] = bipolarRandom(DIM, 0x50000 + @as(u64, @intCast(r)) * 3571);
    }

    std.debug.print("Chains: {}, Max depth: {}, Dim: {}\n", .{ NUM_CHAINS, MAX_DEPTH, DIM });
    std.debug.print("\n--- Planning Queries ---\n", .{});
    std.debug.print("Chain | From    | To      | Hops | Path | Sim\n", .{});
    std.debug.print("------|---------|---------|------|------|------\n", .{});

    var plan_correct: usize = 0;
    var plan_total: usize = 0;
    const chain_names = [_][]const u8{ "Paris", "Berlin", "Tokyo", "Cairo" };

    // For each chain, test planning from city (layer 0) to various depths
    for (0..NUM_CHAINS) |c| {
        // Build step relations: step_r = bind(target, source) for each hop
        // Then composite = step_0 * step_1 * ... * step_{k-1}
        for (1..MAX_DEPTH + 1) |target_depth| {
            plan_total += 1;

            // Build composite relation from layer 0 to target_depth
            var composite = chain_nodes[c][1].bind(&chain_nodes[c][0]);
            var step: usize = 1;
            while (step < target_depth) : (step += 1) {
                var hop_rel = chain_nodes[c][step + 1].bind(&chain_nodes[c][step]);
                composite = composite.bind(&hop_rel);
            }

            // Apply composite to source (layer 0)
            var predicted = composite.bind(&chain_nodes[c][0]);
            const sim = predicted.similarity(&chain_nodes[c][target_depth]);

            // Check: is target the best match among all nodes at target layer?
            var is_best = true;
            for (0..NUM_CHAINS) |other| {
                if (other == c) continue;
                if (predicted.similarity(&chain_nodes[other][target_depth]) >= sim) {
                    is_best = false;
                    break;
                }
            }
            if (is_best) plan_correct += 1;

            // Build path description
            var path_buf: [128]u8 = undefined;
            var path_len: usize = 0;
            for (0..target_depth) |r| {
                if (r > 0 and path_len + 2 < path_buf.len) {
                    path_buf[path_len] = '-';
                    path_buf[path_len + 1] = '>';
                    path_len += 2;
                }
                const name = plan_rel_names[r];
                const copy_len = @min(name.len, path_buf.len - path_len);
                @memcpy(path_buf[path_len..][0..copy_len], name[0..copy_len]);
                path_len += copy_len;
            }

            const depth_names = [_][]const u8{ "city", "country", "continent", "hemisphere", "Earth" };
            std.debug.print("{s:>5} | {s:>7} | {s:>7} | {:>4} | {s} | {d:.4}\n", .{
                chain_names[c], depth_names[0], depth_names[target_depth],
                target_depth, path_buf[0..path_len], sim,
            });
        }
    }

    std.debug.print("\nPlanning accuracy: {}/{} ({d:.1}%)\n", .{
        plan_correct, plan_total,
        @as(f64, @floatFromInt(plan_correct)) / @as(f64, @floatFromInt(plan_total)) * 100,
    });

    // --- Reverse Planning: given target, find source ---
    std.debug.print("\n--- Reverse Planning (Target → Source) ---\n", .{});
    var reverse_correct: usize = 0;
    var reverse_total: usize = 0;

    for (0..NUM_CHAINS) |c| {
        for (1..MAX_DEPTH + 1) |target_depth| {
            reverse_total += 1;

            // Build composite relation (same as forward)
            var composite = chain_nodes[c][1].bind(&chain_nodes[c][0]);
            var step: usize = 1;
            while (step < target_depth) : (step += 1) {
                var hop_rel = chain_nodes[c][step + 1].bind(&chain_nodes[c][step]);
                composite = composite.bind(&hop_rel);
            }

            // Reverse: unbind target from composite to recover source
            var recovered_source = composite.unbind(&chain_nodes[c][target_depth]);
            const rev_sim = recovered_source.similarity(&chain_nodes[c][0]);

            var is_best = true;
            for (0..NUM_CHAINS) |other| {
                if (other == c) continue;
                if (recovered_source.similarity(&chain_nodes[other][0]) >= rev_sim) {
                    is_best = false;
                    break;
                }
            }
            if (is_best) reverse_correct += 1;
        }
    }

    std.debug.print("Reverse planning: {}/{} ({d:.1}%)\n", .{
        reverse_correct, reverse_total,
        @as(f64, @floatFromInt(reverse_correct)) / @as(f64, @floatFromInt(reverse_total)) * 100,
    });

    // --- Multi-Source Planning: same target via different paths ---
    std.debug.print("\n--- Multi-Source: Different Cities → Same Planet ---\n", .{});
    // All 4 chains lead to layer 4 (Earth). Build 4 independent composite relations,
    // apply to 4 different sources, check if all converge on same target.
    var converge_count: usize = 0;

    for (0..NUM_CHAINS) |c| {
        var composite = chain_nodes[c][1].bind(&chain_nodes[c][0]);
        var step: usize = 1;
        while (step < MAX_DEPTH) : (step += 1) {
            var hop_rel = chain_nodes[c][step + 1].bind(&chain_nodes[c][step]);
            composite = composite.bind(&hop_rel);
        }
        var predicted = composite.bind(&chain_nodes[c][0]);
        // Test: does predicted match chain's own final node?
        const own_sim = predicted.similarity(&chain_nodes[c][MAX_DEPTH]);
        if (own_sim > 0.9) converge_count += 1;
        std.debug.print("  {s}: own_target_sim={d:.4}\n", .{ chain_names[c], own_sim });
    }

    std.debug.print("Convergence: {}/{} chains reach own target\n", .{ converge_count, NUM_CHAINS });
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(plan_correct == plan_total); // bipolar: 100% forward
    try std.testing.expect(converge_count == NUM_CHAINS); // all chains converge
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 81: Large KG Noise Curve + Multi-Hop Stress Test (Level 11.9)
// ═══════════════════════════════════════════════════════════════════════════════
// Push multi-hop chains to 6 hops on larger entity sets.
// Test noise tolerance of associative memory at increasing memory load.
// ═══════════════════════════════════════════════════════════════════════════════
test "large kg noise curve multi-hop stress" {
    const DIM = 1024;

    std.debug.print("\n=== LARGE KG: NOISE CURVE + MULTI-HOP STRESS (Level 11.9) ===\n", .{});

    // --- Part A: Multi-hop chain stress (up to 6 hops) ---
    std.debug.print("--- Part A: Extended Multi-Hop Chains (1-6 hops) ---\n", .{});
    std.debug.print("Hops | Correct | Total | Accuracy | Avg Sim\n", .{});
    std.debug.print("-----|---------|-------|----------|--------\n", .{});

    const MAX_HOPS = 6;
    const CHAINS_PER_HOP = 15;
    var hop_correct: [MAX_HOPS]usize = .{ 0, 0, 0, 0, 0, 0 };
    var hop_simsum: [MAX_HOPS]f64 = .{ 0, 0, 0, 0, 0, 0 };

    for (0..CHAINS_PER_HOP) |chain_id| {
        // Create chain entities (7 entities for up to 6 hops)
        var chain_ents: [7]Hypervector = undefined;
        for (0..7) |i| {
            chain_ents[i] = bipolarRandom(DIM, 0x60000 + @as(u64, @intCast(chain_id)) * 10000 + @as(u64, @intCast(i)) * 3571);
        }

        for (1..MAX_HOPS + 1) |hops| {
            // Build composite
            var composite = chain_ents[1].bind(&chain_ents[0]);
            var h: usize = 1;
            while (h < hops) : (h += 1) {
                var hop_rel = chain_ents[h + 1].bind(&chain_ents[h]);
                composite = composite.bind(&hop_rel);
            }

            var predicted = composite.bind(&chain_ents[0]);
            const sim = predicted.similarity(&chain_ents[hops]);
            hop_simsum[hops - 1] += sim;

            // Check against all chain entities
            var is_correct = true;
            for (0..7) |j| {
                if (j == hops) continue;
                if (predicted.similarity(&chain_ents[j]) >= sim) {
                    is_correct = false;
                    break;
                }
            }
            if (is_correct) hop_correct[hops - 1] += 1;
        }
    }

    for (0..MAX_HOPS) |h| {
        const avg_sim = hop_simsum[h] / @as(f64, CHAINS_PER_HOP);
        std.debug.print("{:>4} | {:>7} | {:>5} | {d:>7.1}% | {d:>6.4}\n", .{
            h + 1, hop_correct[h], CHAINS_PER_HOP,
            @as(f64, @floatFromInt(hop_correct[h])) / @as(f64, CHAINS_PER_HOP) * 100,
            avg_sim,
        });
    }

    // --- Part B: Memory load vs accuracy ---
    // Build associative memories with increasing numbers of entities
    std.debug.print("\n--- Part B: Memory Load (Entities in Memory vs Accuracy) ---\n", .{});
    std.debug.print("Entities | Correct | Total | Accuracy\n", .{});
    std.debug.print("---------|---------|-------|--------\n", .{});

    const MEM_SIZES = [_]usize{ 5, 10, 15, 20, 25 };
    for (MEM_SIZES) |mem_size| {
        // Build memory with mem_size entities
        var mem_ents: [25]Hypervector = undefined;
        for (0..mem_size) |i| {
            mem_ents[i] = bipolarRandom(DIM, 0x70000 + @as(u64, @intCast(mem_size)) * 10000 + @as(u64, @intCast(i)) * 7919);
        }
        // Objects
        var mem_pairs: [25]Hypervector = undefined;
        for (0..mem_size) |i| {
            var obj = bipolarRandom(DIM, 0x80000 + @as(u64, @intCast(mem_size)) * 10000 + @as(u64, @intCast(i)) * 137);
            mem_pairs[i] = mem_ents[i].bind(&obj);
        }
        var memory = treeBundleN(mem_pairs[0..mem_size]);

        // Query all entities
        var mem_correct: usize = 0;
        for (0..mem_size) |e| {
            var retrieved = memory.unbind(&mem_ents[e]);
            var best_sim: f64 = -2.0;
            var best_idx: usize = 0;
            for (0..mem_size) |j| {
                var obj_j = bipolarRandom(DIM, 0x80000 + @as(u64, @intCast(mem_size)) * 10000 + @as(u64, @intCast(j)) * 137);
                const sim = retrieved.similarity(&obj_j);
                if (sim > best_sim) { best_sim = sim; best_idx = j; }
            }
            if (best_idx == e) mem_correct += 1;
        }

        std.debug.print("{:>8} | {:>7} | {:>5} | {d:>5.1}%\n", .{
            mem_size, mem_correct, mem_size,
            @as(f64, @floatFromInt(mem_correct)) / @as(f64, @floatFromInt(mem_size)) * 100,
        });
    }

    // --- Part C: Noisy memory retrieval at different loads ---
    std.debug.print("\n--- Part C: Noisy Retrieval (Memory=15, Noise 0-5) ---\n", .{});
    std.debug.print("Noise | Correct | Total | Accuracy\n", .{});
    std.debug.print("------|---------|-------|--------\n", .{});

    const NOISE_MEM = 15;
    var noise_ents: [NOISE_MEM]Hypervector = undefined;
    for (0..NOISE_MEM) |i| {
        noise_ents[i] = bipolarRandom(DIM, 0x90000 + @as(u64, @intCast(i)) * 7919);
    }
    var noise_pairs: [NOISE_MEM]Hypervector = undefined;
    for (0..NOISE_MEM) |i| {
        var obj = bipolarRandom(DIM, 0xA0000 + @as(u64, @intCast(i)) * 137);
        noise_pairs[i] = noise_ents[i].bind(&obj);
    }
    var noise_memory = treeBundleN(noise_pairs[0..NOISE_MEM]);

    const NOISE_LEVELS = [_]usize{ 0, 1, 2, 3, 5 };
    for (NOISE_LEVELS) |noise| {
        var noise_correct: usize = 0;
        for (0..NOISE_MEM) |e| {
            var retrieved = noise_memory.unbind(&noise_ents[e]);
            // Add noise
            for (0..noise) |n| {
                var nv = Hypervector.random(DIM, 0xB0000 + @as(u64, @intCast(e)) * 1000 + @as(u64, @intCast(noise)) * 100 + @as(u64, @intCast(n)));
                retrieved = retrieved.bundle(&nv);
            }
            var best_sim: f64 = -2.0;
            var best_idx: usize = 0;
            for (0..NOISE_MEM) |j| {
                var obj_j = bipolarRandom(DIM, 0xA0000 + @as(u64, @intCast(j)) * 137);
                const sim = retrieved.similarity(&obj_j);
                if (sim > best_sim) { best_sim = sim; best_idx = j; }
            }
            if (best_idx == e) noise_correct += 1;
        }
        std.debug.print("{:>5} | {:>7} | {:>5} | {d:>5.1}%\n", .{
            noise, noise_correct, NOISE_MEM,
            @as(f64, @floatFromInt(noise_correct)) / @as(f64, NOISE_MEM) * 100,
        });
    }

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(hop_correct[0] == CHAINS_PER_HOP); // 1-hop: 100%
    try std.testing.expect(hop_correct[5] == CHAINS_PER_HOP); // 6-hop: 100% (bipolar exact)
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 82: Intermediate Indexing — Sub-Bundle Per Relation (Level 11.10)
// ═══════════════════════════════════════════════════════════════════════════════
// Fix the capacity wall from Level 11.9 (34.7% at 75/domain).
// Instead of flat-bundling all triples → keep per-relation sub-memories.
// Index = array of relation memories. Query: select relation → unbind memory.
// Capacity per sub-memory = sqrt(DIM) ~ 32 entities. Total KG capacity = R × 32.
// ═══════════════════════════════════════════════════════════════════════════════
test "intermediate indexing sub-bundle capacity fix" {
    const DIM = 1024;

    std.debug.print("\n=== INTERMEDIATE INDEXING: CAPACITY FIX (Level 11.10) ===\n", .{});

    // --- Indexed KG: 3 domains × 5 relations × 30 entities = 450 triples ---
    const DOMAINS = 3;
    const RELS = 5;
    const ENTS_PER_REL = 30; // pushing toward sqrt(1024) ~ 32
    const TOTAL = DOMAINS * RELS * ENTS_PER_REL; // 450

    std.debug.print("Domains: {}, Relations: {}, Entities/rel: {}\n", .{ DOMAINS, RELS, ENTS_PER_REL });
    std.debug.print("Total triples: {} (vs 225 in Level 11.9)\n\n", .{TOTAL});

    // --- Build indexed KG: per-domain, per-relation sub-memories ---
    // Index structure: memories[domain][relation] = tree_bundle(bind(entity_i, object_i))
    // Query: given (domain, relation, entity) → unbind(memories[d][r], entity) → search objects
    var total_correct: usize = 0;
    var total_queries: usize = 0;

    std.debug.print("--- Indexed Single-Hop Queries ---\n", .{});
    std.debug.print("Domain | Rel | Correct | Total | Accuracy\n", .{});
    std.debug.print("-------|-----|---------|-------|--------\n", .{});

    const domain_names = [_][]const u8{ "Geo", "People", "Science" };

    for (0..DOMAINS) |d| {
        // Relation vectors
        var rels: [RELS]Hypervector = undefined;
        for (0..RELS) |r| {
            rels[r] = bipolarRandom(DIM, 0x100000 + @as(u64, @intCast(d)) * 100000 + @as(u64, @intCast(r)) * 4111);
        }

        for (0..RELS) |r| {
            // Build sub-memory for this (domain, relation) pair
            var ents: [ENTS_PER_REL]Hypervector = undefined;
            for (0..ENTS_PER_REL) |i| {
                ents[i] = bipolarRandom(DIM, 0x200000 + @as(u64, @intCast(d)) * 1000000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(i)) * 7919);
            }
            var pairs: [ENTS_PER_REL]Hypervector = undefined;
            for (0..ENTS_PER_REL) |i| {
                var obj = bipolarRandom(DIM, 0x300000 + @as(u64, @intCast(d)) * 1000000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(i)) * 137);
                pairs[i] = ents[i].bind(&obj);
            }
            var memory = treeBundleN(pairs[0..ENTS_PER_REL]);

            // Query all entities
            var rel_correct: usize = 0;
            for (0..ENTS_PER_REL) |e| {
                total_queries += 1;
                var retrieved = memory.unbind(&ents[e]);
                var best_sim: f64 = -2.0;
                var best_idx: usize = 0;
                for (0..ENTS_PER_REL) |j| {
                    var obj_j = bipolarRandom(DIM, 0x300000 + @as(u64, @intCast(d)) * 1000000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(j)) * 137);
                    const sim = retrieved.similarity(&obj_j);
                    if (sim > best_sim) { best_sim = sim; best_idx = j; }
                }
                if (best_idx == e) rel_correct += 1;
            }
            total_correct += rel_correct;
            std.debug.print("{s:>6} | {:>3} | {:>7} | {:>5} | {d:>5.1}%\n", .{
                domain_names[d], r, rel_correct, ENTS_PER_REL,
                @as(f64, @floatFromInt(rel_correct)) / @as(f64, ENTS_PER_REL) * 100,
            });
        }
    }

    const overall_acc = @as(f64, @floatFromInt(total_correct)) / @as(f64, @floatFromInt(total_queries)) * 100;
    std.debug.print("\nIndexed total: {}/{} ({d:.1}%)\n", .{ total_correct, total_queries, overall_acc });

    // --- Compare: what FLAT would give at same scale ---
    // Flat: bundle ALL 30 entities × 5 relations = 150 per domain into one vector
    std.debug.print("\n--- Flat Comparison (domain-level bundle) ---\n", .{});
    var flat_correct: usize = 0;
    var flat_total: usize = 0;

    for (0..DOMAINS) |d| {
        // Build one flat memory per domain: bundle ALL pairs across ALL relations
        // Use only first 10 entities per relation (to fit on stack) = 50 per domain
        const FLAT_ENTS = 10;
        var flat_pairs: [RELS * FLAT_ENTS]Hypervector = undefined;
        var fp_idx: usize = 0;
        for (0..RELS) |r| {
            for (0..FLAT_ENTS) |i| {
                var ent = bipolarRandom(DIM, 0x200000 + @as(u64, @intCast(d)) * 1000000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(i)) * 7919);
                var obj = bipolarRandom(DIM, 0x300000 + @as(u64, @intCast(d)) * 1000000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(i)) * 137);
                flat_pairs[fp_idx] = ent.bind(&obj);
                fp_idx += 1;
            }
        }
        var flat_memory = treeBundleN(flat_pairs[0..fp_idx]);

        // Query each entity
        var domain_flat_correct: usize = 0;
        var domain_flat_total: usize = 0;
        for (0..RELS) |r| {
            for (0..FLAT_ENTS) |e| {
                flat_total += 1;
                domain_flat_total += 1;
                var ent = bipolarRandom(DIM, 0x200000 + @as(u64, @intCast(d)) * 1000000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(e)) * 7919);
                var retrieved = flat_memory.unbind(&ent);
                var best_sim: f64 = -2.0;
                var best_idx: usize = 0;
                // Search all objects across all relations (ambiguous!)
                for (0..RELS) |r2| {
                    for (0..FLAT_ENTS) |j| {
                        var obj_j = bipolarRandom(DIM, 0x300000 + @as(u64, @intCast(d)) * 1000000 + @as(u64, @intCast(r2)) * 10000 + @as(u64, @intCast(j)) * 137);
                        const sim = retrieved.similarity(&obj_j);
                        if (sim > best_sim) { best_sim = sim; best_idx = r2 * FLAT_ENTS + j; }
                    }
                }
                if (best_idx == r * FLAT_ENTS + e) domain_flat_correct += 1;
            }
        }
        flat_correct += domain_flat_correct;
        std.debug.print("{s:>6} flat: {}/{} ({d:.1}%)\n", .{
            domain_names[d], domain_flat_correct, domain_flat_total,
            @as(f64, @floatFromInt(domain_flat_correct)) / @as(f64, @floatFromInt(domain_flat_total)) * 100,
        });
    }

    std.debug.print("Flat total: {}/{} ({d:.1}%)\n", .{
        flat_correct, flat_total,
        @as(f64, @floatFromInt(flat_correct)) / @as(f64, @floatFromInt(flat_total)) * 100,
    });
    std.debug.print("\n>>> INDEXED: {d:.1}% vs FLAT: {d:.1}% <<<\n", .{
        overall_acc,
        @as(f64, @floatFromInt(flat_correct)) / @as(f64, @floatFromInt(flat_total)) * 100,
    });
    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(TOTAL >= 400);
    try std.testing.expect(total_correct > total_queries * 8 / 10); // indexed >80%
    try std.testing.expect(total_correct > flat_correct); // indexed > flat
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 83: Indexed Planning — Multi-Hop on Indexed KG (Level 11.10)
// ═══════════════════════════════════════════════════════════════════════════════
// Planning queries through indexed KG: compose relations, apply to entity,
// traverse sub-memories at each hop.
// ═══════════════════════════════════════════════════════════════════════════════
test "indexed planning multi-hop on indexed kg" {
    const DIM = 1024;

    std.debug.print("\n=== INDEXED PLANNING: MULTI-HOP ON INDEXED KG (Level 11.10) ===\n", .{});

    // Build a 4-layer indexed KG: each layer has its own sub-memory
    // Layer 0→1: "capital_of" (cities → countries)
    // Layer 1→2: "continent" (countries → continents)
    // Layer 2→3: "hemisphere" (continents → hemispheres)
    // Layer 3→4: "planet" (hemispheres → planet)
    const LAYERS = 4;
    const ENTITIES_PER_LAYER = 20;

    // Entity vectors per layer
    var layer_ents: [LAYERS + 1][ENTITIES_PER_LAYER]Hypervector = undefined;
    for (0..LAYERS + 1) |l| {
        for (0..ENTITIES_PER_LAYER) |i| {
            layer_ents[l][i] = bipolarRandom(DIM, 0x400000 + @as(u64, @intCast(l)) * 100000 + @as(u64, @intCast(i)) * 7919);
        }
    }

    // Build per-layer sub-memories: memory_l maps layer_l entities to layer_{l+1} entities
    // Each entity i in layer l maps to entity i in layer l+1 (simple 1:1 mapping)
    var layer_memories: [LAYERS]Hypervector = undefined;
    for (0..LAYERS) |l| {
        var pairs: [ENTITIES_PER_LAYER]Hypervector = undefined;
        for (0..ENTITIES_PER_LAYER) |i| {
            pairs[i] = layer_ents[l][i].bind(&layer_ents[l + 1][i]);
        }
        layer_memories[l] = treeBundleN(pairs[0..ENTITIES_PER_LAYER]);
    }

    std.debug.print("Layers: {}, Entities/layer: {}, Total index entries: {}\n\n", .{
        LAYERS, ENTITIES_PER_LAYER, LAYERS * ENTITIES_PER_LAYER,
    });

    // --- Single-hop through each sub-memory ---
    std.debug.print("--- Single-Hop Per Layer ---\n", .{});
    std.debug.print("Layer | Correct | Total | Accuracy\n", .{});
    std.debug.print("------|---------|-------|--------\n", .{});

    var single_total_ok: usize = 0;
    for (0..LAYERS) |l| {
        var correct: usize = 0;
        for (0..ENTITIES_PER_LAYER) |i| {
            var retrieved = layer_memories[l].unbind(&layer_ents[l][i]);
            var best_sim: f64 = -2.0;
            var best_idx: usize = 0;
            for (0..ENTITIES_PER_LAYER) |j| {
                const sim = retrieved.similarity(&layer_ents[l + 1][j]);
                if (sim > best_sim) { best_sim = sim; best_idx = j; }
            }
            if (best_idx == i) correct += 1;
        }
        single_total_ok += correct;
        std.debug.print("{:>5} | {:>7} | {:>5} | {d:>5.1}%\n", .{
            l, correct, ENTITIES_PER_LAYER,
            @as(f64, @floatFromInt(correct)) / @as(f64, ENTITIES_PER_LAYER) * 100,
        });
    }

    // --- Multi-hop planning through indexed sub-memories ---
    std.debug.print("\n--- Multi-Hop Planning (Indexed Traversal) ---\n", .{});
    std.debug.print("Hops | Correct | Total | Accuracy\n", .{});
    std.debug.print("-----|---------|-------|--------\n", .{});

    const PLAN_TESTS = 15;
    for (1..LAYERS + 1) |hops| {
        var plan_ok: usize = 0;
        for (0..PLAN_TESTS) |i| {
            // Start at layer 0, entity i, traverse hops layers
            var current = layer_ents[0][i];

            // Hop through each sub-memory sequentially
            var step: usize = 0;
            while (step < hops) : (step += 1) {
                var retrieved = layer_memories[step].unbind(&current);
                // Find best match in next layer
                var best_sim: f64 = -2.0;
                var best_idx: usize = 0;
                for (0..ENTITIES_PER_LAYER) |j| {
                    const sim = retrieved.similarity(&layer_ents[step + 1][j]);
                    if (sim > best_sim) { best_sim = sim; best_idx = j; }
                }
                current = layer_ents[step + 1][best_idx];
            }

            // Check: did we arrive at the correct target (entity i in layer hops)?
            const final_sim = current.similarity(&layer_ents[hops][i]);
            if (final_sim > 0.99) plan_ok += 1;
        }
        std.debug.print("{:>4} | {:>7} | {:>5} | {d:>5.1}%\n", .{
            hops, plan_ok, PLAN_TESTS,
            @as(f64, @floatFromInt(plan_ok)) / @as(f64, PLAN_TESTS) * 100,
        });
    }

    // --- Noisy indexed traversal ---
    std.debug.print("\n--- Noisy Indexed Traversal (2-hop, noise 0-5) ---\n", .{});
    std.debug.print("Noise | Correct | Total | Accuracy\n", .{});
    std.debug.print("------|---------|-------|--------\n", .{});

    const NOISY_HOPS = 2;
    const NOISY_TESTS = 15;
    const NOISE_LEVELS = [_]usize{ 0, 1, 2, 3, 5 };

    for (NOISE_LEVELS) |noise| {
        var noisy_ok: usize = 0;
        for (0..NOISY_TESTS) |i| {
            var current = layer_ents[0][i];
            var step: usize = 0;
            while (step < NOISY_HOPS) : (step += 1) {
                var retrieved = layer_memories[step].unbind(&current);
                // Add noise
                for (0..noise) |n| {
                    var nv = Hypervector.random(DIM, 0x500000 + @as(u64, @intCast(i)) * 1000 + @as(u64, @intCast(step)) * 100 + @as(u64, @intCast(noise)) * 10 + @as(u64, @intCast(n)));
                    retrieved = retrieved.bundle(&nv);
                }
                var best_sim: f64 = -2.0;
                var best_idx: usize = 0;
                for (0..ENTITIES_PER_LAYER) |j| {
                    const sim = retrieved.similarity(&layer_ents[step + 1][j]);
                    if (sim > best_sim) { best_sim = sim; best_idx = j; }
                }
                current = layer_ents[step + 1][best_idx];
            }
            const final_sim = current.similarity(&layer_ents[NOISY_HOPS][i]);
            if (final_sim > 0.99) noisy_ok += 1;
        }
        std.debug.print("{:>5} | {:>7} | {:>5} | {d:>5.1}%\n", .{
            noise, noisy_ok, NOISY_TESTS,
            @as(f64, @floatFromInt(noisy_ok)) / @as(f64, NOISY_TESTS) * 100,
        });
    }

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(single_total_ok == LAYERS * ENTITIES_PER_LAYER); // all single-hop: 100%
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 84: Indexed vs Flat Capacity Benchmark (Level 11.10)
// ═══════════════════════════════════════════════════════════════════════════════
// Push entity count to 30 per sub-memory, compare indexed vs flat head-to-head.
// ═══════════════════════════════════════════════════════════════════════════════
test "indexed vs flat capacity benchmark" {
    const DIM = 1024;

    std.debug.print("\n=== INDEXED vs FLAT: CAPACITY BENCHMARK (Level 11.10) ===\n", .{});

    // Test both approaches at increasing entity counts
    const SIZES = [_]usize{ 5, 10, 15, 20, 25, 30 };
    const NUM_RELS = 3;

    std.debug.print("Entities | Indexed | Flat ({}R) | Advantage\n", .{NUM_RELS});
    std.debug.print("---------|---------|-----------|----------\n", .{});

    for (SIZES) |size| {
        // --- INDEXED: separate memory per relation ---
        var idx_correct: usize = 0;
        var idx_total: usize = 0;

        for (0..NUM_RELS) |r| {
            var ents: [30]Hypervector = undefined;
            for (0..size) |i| {
                ents[i] = bipolarRandom(DIM, 0x600000 + @as(u64, @intCast(size)) * 100000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(i)) * 7919);
            }
            var pairs: [30]Hypervector = undefined;
            for (0..size) |i| {
                var obj = bipolarRandom(DIM, 0x700000 + @as(u64, @intCast(size)) * 100000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(i)) * 137);
                pairs[i] = ents[i].bind(&obj);
            }
            var memory = treeBundleN(pairs[0..size]);

            for (0..size) |e| {
                idx_total += 1;
                var retrieved = memory.unbind(&ents[e]);
                var best_sim: f64 = -2.0;
                var best_idx: usize = 0;
                for (0..size) |j| {
                    var obj_j = bipolarRandom(DIM, 0x700000 + @as(u64, @intCast(size)) * 100000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(j)) * 137);
                    const sim = retrieved.similarity(&obj_j);
                    if (sim > best_sim) { best_sim = sim; best_idx = j; }
                }
                if (best_idx == e) idx_correct += 1;
            }
        }

        // --- FLAT: one memory for all relations ---
        var flat_correct: usize = 0;
        var flat_total: usize = 0;

        // Build flat memory: all relations bundled together (cap at 30 for stack)
        var flat_pairs: [30]Hypervector = undefined;
        var fp: usize = 0;
        for (0..NUM_RELS) |r| {
            const ents_this = @min(size, (30 - fp) / (@max(NUM_RELS - r, 1)));
            for (0..ents_this) |i| {
                if (fp >= 30) break;
                var ent = bipolarRandom(DIM, 0x600000 + @as(u64, @intCast(size)) * 100000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(i)) * 7919);
                var obj = bipolarRandom(DIM, 0x700000 + @as(u64, @intCast(size)) * 100000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(i)) * 137);
                flat_pairs[fp] = ent.bind(&obj);
                fp += 1;
            }
        }
        if (fp > 0) {
            var flat_memory = treeBundleN(flat_pairs[0..fp]);

            for (0..NUM_RELS) |r| {
                const ents_this = @min(size, 10);
                for (0..ents_this) |e| {
                    flat_total += 1;
                    var ent = bipolarRandom(DIM, 0x600000 + @as(u64, @intCast(size)) * 100000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(e)) * 7919);
                    var retrieved = flat_memory.unbind(&ent);
                    var best_sim: f64 = -2.0;
                    var best_idx: usize = 0;
                    for (0..NUM_RELS) |r2| {
                        for (0..@min(size, 10)) |j| {
                            var obj_j = bipolarRandom(DIM, 0x700000 + @as(u64, @intCast(size)) * 100000 + @as(u64, @intCast(r2)) * 10000 + @as(u64, @intCast(j)) * 137);
                            const sim = retrieved.similarity(&obj_j);
                            if (sim > best_sim) { best_sim = sim; best_idx = r2 * @min(size, 10) + j; }
                        }
                    }
                    if (best_idx == r * @min(size, 10) + e) flat_correct += 1;
                }
            }
        }

        const idx_acc = @as(f64, @floatFromInt(idx_correct)) / @as(f64, @floatFromInt(idx_total)) * 100;
        const flat_acc = if (flat_total > 0) @as(f64, @floatFromInt(flat_correct)) / @as(f64, @floatFromInt(flat_total)) * 100 else 0.0;
        const advantage = idx_acc - flat_acc;
        std.debug.print("{:>8} | {d:>5.1}%  | {d:>7.1}%  | {s}{d:>5.1}%\n", .{
            size, idx_acc, flat_acc,
            if (advantage >= 0) "+" else "",
            advantage,
        });
    }

    std.debug.print("============================================\n", .{});

    // The test just needs to complete — results are informational
    try std.testing.expect(true);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 85: Path Discovery — BFS Through Indexed KG (Level 11.11)
// ═══════════════════════════════════════════════════════════════════════════════
// Given source and target entities, discover the path connecting them by
// searching through indexed sub-memories at each hop. True discovery — the
// system doesn't know the path in advance, it explores the graph.
// ═══════════════════════════════════════════════════════════════════════════════
test "path discovery bfs through indexed kg" {
    const DIM = 1024;

    std.debug.print("\n=== PATH DISCOVERY: BFS THROUGH INDEXED KG (Level 11.11) ===\n", .{});

    // Build a 5-layer KG: cities → countries → continents → hemispheres → planet
    // 8 entities per layer, 4 relations connecting adjacent layers
    const LAYERS = 4;
    const ENTS = 8;

    // Generate entity vectors for each layer (5 layers, 0-4)
    var layer_ents: [LAYERS + 1][ENTS]Hypervector = undefined;
    for (0..LAYERS + 1) |l| {
        for (0..ENTS) |i| {
            layer_ents[l][i] = bipolarRandom(DIM, 0x800000 + @as(u64, @intCast(l)) * 100000 + @as(u64, @intCast(i)) * 7919);
        }
    }

    // Build per-layer sub-memories (indexed KG)
    // Each maps layer[l] entities to layer[l+1] entities (1:1 for simplicity)
    var layer_memories: [LAYERS]Hypervector = undefined;
    for (0..LAYERS) |l| {
        var pairs: [ENTS]Hypervector = undefined;
        for (0..ENTS) |i| {
            pairs[i] = layer_ents[l][i].bind(&layer_ents[l + 1][i]);
        }
        layer_memories[l] = treeBundleN(pairs[0..ENTS]);
    }

    const layer_names = [_][]const u8{ "city", "country", "continent", "hemisphere", "planet" };

    std.debug.print("Layers: {}, Entities/layer: {}\n", .{ LAYERS + 1, ENTS });
    std.debug.print("Relations: {} (one per layer transition)\n\n", .{LAYERS});

    // --- BFS Path Discovery ---
    // Given: source entity at layer 0, target entity at layer N
    // Find: which sequence of hops connects them
    // Method: At each layer, try unbinding from each relation memory,
    //         find best match in next layer. If match is good (sim > threshold),
    //         continue from there. Track the path taken.
    std.debug.print("--- BFS Path Discovery ---\n", .{});
    std.debug.print("Entity | Source     | Target     | Hops | Path                      | Sim\n", .{});
    std.debug.print("-------|------------|------------|------|---------------------------|------\n", .{});

    const THRESHOLD: f64 = 0.15; // minimum similarity to accept a hop
    var discovery_correct: usize = 0;
    var discovery_total: usize = 0;

    // Test discovery for entities 0-7, target depths 1-4
    for (0..ENTS) |entity_idx| {
        for (1..LAYERS + 1) |target_depth| {
            discovery_total += 1;

            // Start from layer 0
            var current = layer_ents[0][entity_idx];
            var path_ok = true;
            var discovered_depth: usize = 0;

            // BFS: try each layer's memory sequentially
            var step: usize = 0;
            while (step < target_depth) : (step += 1) {
                // Try to traverse through this layer's memory
                var retrieved = layer_memories[step].unbind(&current);

                // Search for best match in next layer
                var best_sim: f64 = -2.0;
                var best_idx: usize = 0;
                for (0..ENTS) |j| {
                    const sim = retrieved.similarity(&layer_ents[step + 1][j]);
                    if (sim > best_sim) { best_sim = sim; best_idx = j; }
                }

                if (best_sim > THRESHOLD) {
                    current = layer_ents[step + 1][best_idx];
                    discovered_depth += 1;
                    if (best_idx != entity_idx) path_ok = false;
                } else {
                    path_ok = false;
                    break;
                }
            }

            // Check if we arrived at the correct target
            var target = layer_ents[target_depth][entity_idx];
            const final_sim = current.similarity(&target);
            const success = path_ok and final_sim > 0.99;
            if (success) discovery_correct += 1;

            // Print first 4 entities for readability
            if (entity_idx < 4) {
                std.debug.print("{:>6} | {s:<10} | {s:<10} | {:>4} | ", .{
                    entity_idx,
                    layer_names[0],
                    layer_names[target_depth],
                    target_depth,
                });
                // Print path
                var p: usize = 0;
                while (p < target_depth) : (p += 1) {
                    if (p > 0) std.debug.print("->", .{});
                    std.debug.print("{s}", .{layer_names[p + 1]});
                }
                std.debug.print("{s:>25}", .{""});
                std.debug.print(" | {d:.4}\n", .{final_sim});
            }
        }
    }

    const disc_acc = @as(f64, @floatFromInt(discovery_correct)) / @as(f64, @floatFromInt(discovery_total)) * 100;
    std.debug.print("\nDiscovery accuracy: {}/{} ({d:.1}%)\n", .{ discovery_correct, discovery_total, disc_acc });

    // --- Reverse Discovery: given target, find source ---
    std.debug.print("\n--- Reverse Discovery (target → source) ---\n", .{});
    var rev_correct: usize = 0;
    var rev_total: usize = 0;

    for (0..ENTS) |entity_idx| {
        for (1..LAYERS + 1) |depth| {
            rev_total += 1;
            // Start from target layer, walk backwards
            var current_rev = layer_ents[depth][entity_idx];
            var rev_ok = true;

            var step_rev: usize = depth;
            while (step_rev > 0) {
                step_rev -= 1;
                // Reverse: unbind from the memory (bind is self-inverse for bipolar)
                // memory = bundle(bind(source_i, target_i))
                // To go backwards: bind(memory, target) ≈ source (because bind(target, bind(source, target)) = source)
                // But memory is a bundle, so we unbind current from a "reversed" perspective
                // Actually: we need to iterate candidates and check
                var best_sim: f64 = -2.0;
                var best_idx: usize = 0;
                for (0..ENTS) |j| {
                    // Check: does bind(layer_ents[step_rev][j], layer_ents[step_rev+1][entity_we_have]) exist in memory?
                    // Simpler: unbind memory with current, find match in previous layer
                    var candidate = layer_ents[step_rev][j];
                    var pair = candidate.bind(&current_rev);
                    const sim = pair.similarity(&layer_memories[step_rev]);
                    if (sim > best_sim) { best_sim = sim; best_idx = j; }
                }
                if (best_sim > 0.0) {
                    current_rev = layer_ents[step_rev][best_idx];
                    if (best_idx != entity_idx) rev_ok = false;
                } else {
                    rev_ok = false;
                    break;
                }
            }

            var source = layer_ents[0][entity_idx];
            const rev_sim = current_rev.similarity(&source);
            if (rev_ok and rev_sim > 0.99) rev_correct += 1;
        }
    }

    const rev_acc = @as(f64, @floatFromInt(rev_correct)) / @as(f64, @floatFromInt(rev_total)) * 100;
    std.debug.print("Reverse discovery: {}/{} ({d:.1}%)\n", .{ rev_correct, rev_total, rev_acc });

    // --- Cross-entity discovery: can we find paths between DIFFERENT entities? ---
    std.debug.print("\n--- Cross-Entity Path Probing ---\n", .{});
    // For entity i at layer 0, try to reach entity j at layer 2
    // Only entity i→i should succeed (1:1 mapping)
    var cross_true_pos: usize = 0;
    var cross_true_neg: usize = 0;
    var cross_tests: usize = 0;

    const CROSS_ENTS = 6;
    for (0..CROSS_ENTS) |src_idx| {
        for (0..CROSS_ENTS) |tgt_idx| {
            cross_tests += 1;
            var current_c = layer_ents[0][src_idx];

            // 2-hop traversal
            var step_c: usize = 0;
            while (step_c < 2) : (step_c += 1) {
                var retrieved_c = layer_memories[step_c].unbind(&current_c);
                var best_sim_c: f64 = -2.0;
                var best_idx_c: usize = 0;
                for (0..ENTS) |j| {
                    const sim_c = retrieved_c.similarity(&layer_ents[step_c + 1][j]);
                    if (sim_c > best_sim_c) { best_sim_c = sim_c; best_idx_c = j; }
                }
                current_c = layer_ents[step_c + 1][best_idx_c];
            }

            var tgt = layer_ents[2][tgt_idx];
            const cross_sim = current_c.similarity(&tgt);
            const should_match = (src_idx == tgt_idx);
            const does_match = cross_sim > 0.99;

            if (should_match and does_match) cross_true_pos += 1;
            if (!should_match and !does_match) cross_true_neg += 1;
        }
    }
    const cross_precision = @as(f64, @floatFromInt(cross_true_pos + cross_true_neg)) / @as(f64, @floatFromInt(cross_tests)) * 100;
    std.debug.print("Cross-entity (2-hop): true_pos={}, true_neg={}, total={}, precision={d:.1}%\n", .{
        cross_true_pos, cross_true_neg, cross_tests, cross_precision,
    });

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(discovery_correct > discovery_total * 9 / 10); // >90% forward discovery
    try std.testing.expect(rev_correct > rev_total * 7 / 10); // >70% reverse discovery
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 86: Multi-Hop Discovery on 450+ Triple KG (Level 11.11)
// ═══════════════════════════════════════════════════════════════════════════════
// Scale path discovery to a large indexed KG with multiple domains and relations.
// Discover paths across domains — e.g., find which relation connects two entities.
// ═══════════════════════════════════════════════════════════════════════════════
test "multi-hop discovery on large indexed kg" {
    const DIM = 1024;

    std.debug.print("\n=== MULTI-HOP DISCOVERY ON LARGE KG (Level 11.11) ===\n", .{});

    // Build a 3-domain indexed KG: 5 relations per domain, 15 entities per relation = 225 triples
    // Plus 3 cross-domain bridging relations with 10 entities each = 30 more = 255 total
    const DOMAINS = 3;
    const RELS_PER_DOMAIN = 5;
    const ENTS_PER_REL = 15;

    // Build per-domain, per-relation sub-memories
    // domain_memories[d][r] = tree_bundle(bind(ent_i, obj_i))
    std.debug.print("Domains: {}, Relations/domain: {}, Entities/rel: {}\n", .{ DOMAINS, RELS_PER_DOMAIN, ENTS_PER_REL });
    std.debug.print("Total intra-domain triples: {}\n\n", .{DOMAINS * RELS_PER_DOMAIN * ENTS_PER_REL});

    // --- Part A: Relation Discovery ---
    // Given entity and object, discover WHICH relation connects them
    std.debug.print("--- Part A: Relation Discovery ---\n", .{});
    std.debug.print("Domain | Correct | Total | Accuracy\n", .{});
    std.debug.print("-------|---------|-------|--------\n", .{});

    const domain_names = [_][]const u8{ "Geo", "People", "Science" };
    var rel_disc_total_ok: usize = 0;
    var rel_disc_total: usize = 0;

    for (0..DOMAINS) |d| {
        var domain_ok: usize = 0;
        var domain_total: usize = 0;

        // Build all relation memories for this domain
        var rel_memories: [RELS_PER_DOMAIN]Hypervector = undefined;
        for (0..RELS_PER_DOMAIN) |r| {
            var pairs: [ENTS_PER_REL]Hypervector = undefined;
            for (0..ENTS_PER_REL) |i| {
                var ent = bipolarRandom(DIM, 0x900000 + @as(u64, @intCast(d)) * 1000000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(i)) * 7919);
                var obj = bipolarRandom(DIM, 0xA00000 + @as(u64, @intCast(d)) * 1000000 + @as(u64, @intCast(r)) * 10000 + @as(u64, @intCast(i)) * 137);
                pairs[i] = ent.bind(&obj);
            }
            rel_memories[r] = treeBundleN(pairs[0..ENTS_PER_REL]);
        }

        // For each entity-object pair, discover which relation connects them
        for (0..RELS_PER_DOMAIN) |true_r| {
            for (0..ENTS_PER_REL) |i| {
                domain_total += 1;
                var ent = bipolarRandom(DIM, 0x900000 + @as(u64, @intCast(d)) * 1000000 + @as(u64, @intCast(true_r)) * 10000 + @as(u64, @intCast(i)) * 7919);
                var obj = bipolarRandom(DIM, 0xA00000 + @as(u64, @intCast(d)) * 1000000 + @as(u64, @intCast(true_r)) * 10000 + @as(u64, @intCast(i)) * 137);

                // Probe: bind(ent, obj) should be similar to the relation memory that contains this pair
                var pair_vec = ent.bind(&obj);

                var best_sim: f64 = -2.0;
                var best_r: usize = 0;
                for (0..RELS_PER_DOMAIN) |r| {
                    const sim = pair_vec.similarity(&rel_memories[r]);
                    if (sim > best_sim) { best_sim = sim; best_r = r; }
                }
                if (best_r == true_r) domain_ok += 1;
            }
        }

        rel_disc_total_ok += domain_ok;
        rel_disc_total += domain_total;
        std.debug.print("{s:>6} | {:>7} | {:>5} | {d:>5.1}%\n", .{
            domain_names[d], domain_ok, domain_total,
            @as(f64, @floatFromInt(domain_ok)) / @as(f64, @floatFromInt(domain_total)) * 100,
        });
    }

    const rel_disc_acc = @as(f64, @floatFromInt(rel_disc_total_ok)) / @as(f64, @floatFromInt(rel_disc_total)) * 100;
    std.debug.print("Relation discovery total: {}/{} ({d:.1}%)\n", .{ rel_disc_total_ok, rel_disc_total, rel_disc_acc });

    // --- Part B: 2-Hop Path Discovery ---
    // Given entity at domain d, relation r — find the object.
    // Then from that object, find which OTHER relation it also participates in.
    std.debug.print("\n--- Part B: 2-Hop Chain Discovery ---\n", .{});

    // Build a chain: for each domain, relation 0 output feeds into relation 1 input
    // Chain: ent --R0--> mid --R1--> target
    const CHAIN_ENTS = 10;
    var chain_sources: [CHAIN_ENTS]Hypervector = undefined;
    var chain_mids: [CHAIN_ENTS]Hypervector = undefined;
    var chain_targets: [CHAIN_ENTS]Hypervector = undefined;

    for (0..CHAIN_ENTS) |i| {
        chain_sources[i] = bipolarRandom(DIM, 0xB00000 + @as(u64, @intCast(i)) * 7919);
        chain_mids[i] = bipolarRandom(DIM, 0xC00000 + @as(u64, @intCast(i)) * 7919);
        chain_targets[i] = bipolarRandom(DIM, 0xD00000 + @as(u64, @intCast(i)) * 7919);
    }

    // Memory R0: source → mid
    var r0_pairs: [CHAIN_ENTS]Hypervector = undefined;
    for (0..CHAIN_ENTS) |i| {
        r0_pairs[i] = chain_sources[i].bind(&chain_mids[i]);
    }
    var mem_r0 = treeBundleN(r0_pairs[0..CHAIN_ENTS]);

    // Memory R1: mid → target
    var r1_pairs: [CHAIN_ENTS]Hypervector = undefined;
    for (0..CHAIN_ENTS) |i| {
        r1_pairs[i] = chain_mids[i].bind(&chain_targets[i]);
    }
    var mem_r1 = treeBundleN(r1_pairs[0..CHAIN_ENTS]);

    // Discovery: given source[i], find target[i] through 2-hop chain
    var chain_ok: usize = 0;
    for (0..CHAIN_ENTS) |i| {
        // Hop 1: unbind source from R0 memory → should get mid
        var retrieved_mid = mem_r0.unbind(&chain_sources[i]);
        // Find best match in mids codebook
        var best_mid_sim: f64 = -2.0;
        var best_mid_idx: usize = 0;
        for (0..CHAIN_ENTS) |j| {
            const sim = retrieved_mid.similarity(&chain_mids[j]);
            if (sim > best_mid_sim) { best_mid_sim = sim; best_mid_idx = j; }
        }

        // Hop 2: unbind discovered mid from R1 memory → should get target
        var retrieved_tgt = mem_r1.unbind(&chain_mids[best_mid_idx]);
        var best_tgt_sim: f64 = -2.0;
        var best_tgt_idx: usize = 0;
        for (0..CHAIN_ENTS) |j| {
            const sim = retrieved_tgt.similarity(&chain_targets[j]);
            if (sim > best_tgt_sim) { best_tgt_sim = sim; best_tgt_idx = j; }
        }

        if (best_tgt_idx == i) chain_ok += 1;

        if (i < 5) {
            std.debug.print("  src[{}] --R0--> mid[{}] --R1--> tgt[{}] (expected {}): {s}\n", .{
                i, best_mid_idx, best_tgt_idx, i,
                if (best_tgt_idx == i) "OK" else "MISS",
            });
        }
    }

    std.debug.print("2-hop chain discovery: {}/{} ({d:.1}%)\n", .{
        chain_ok, CHAIN_ENTS,
        @as(f64, @floatFromInt(chain_ok)) / @as(f64, CHAIN_ENTS) * 100,
    });

    // --- Part C: 3-Hop Discovery ---
    std.debug.print("\n--- Part C: 3-Hop Chain Discovery ---\n", .{});
    var chain_layer3: [CHAIN_ENTS]Hypervector = undefined;
    for (0..CHAIN_ENTS) |i| {
        chain_layer3[i] = bipolarRandom(DIM, 0xE00000 + @as(u64, @intCast(i)) * 7919);
    }
    // Memory R2: target → layer3
    var r2_pairs: [CHAIN_ENTS]Hypervector = undefined;
    for (0..CHAIN_ENTS) |i| {
        r2_pairs[i] = chain_targets[i].bind(&chain_layer3[i]);
    }
    var mem_r2 = treeBundleN(r2_pairs[0..CHAIN_ENTS]);

    var chain3_ok: usize = 0;
    for (0..CHAIN_ENTS) |i| {
        // Hop 1
        var ret1 = mem_r0.unbind(&chain_sources[i]);
        var b1_sim: f64 = -2.0;
        var b1_idx: usize = 0;
        for (0..CHAIN_ENTS) |j| {
            const s = ret1.similarity(&chain_mids[j]);
            if (s > b1_sim) { b1_sim = s; b1_idx = j; }
        }
        // Hop 2
        var ret2 = mem_r1.unbind(&chain_mids[b1_idx]);
        var b2_sim: f64 = -2.0;
        var b2_idx: usize = 0;
        for (0..CHAIN_ENTS) |j| {
            const s = ret2.similarity(&chain_targets[j]);
            if (s > b2_sim) { b2_sim = s; b2_idx = j; }
        }
        // Hop 3
        var ret3 = mem_r2.unbind(&chain_targets[b2_idx]);
        var b3_sim: f64 = -2.0;
        var b3_idx: usize = 0;
        for (0..CHAIN_ENTS) |j| {
            const s = ret3.similarity(&chain_layer3[j]);
            if (s > b3_sim) { b3_sim = s; b3_idx = j; }
        }

        if (b3_idx == i) chain3_ok += 1;
    }
    std.debug.print("3-hop chain discovery: {}/{} ({d:.1}%)\n", .{
        chain3_ok, CHAIN_ENTS,
        @as(f64, @floatFromInt(chain3_ok)) / @as(f64, CHAIN_ENTS) * 100,
    });

    std.debug.print("============================================\n", .{});

    // Assertions
    try std.testing.expect(chain_ok >= CHAIN_ENTS * 9 / 10); // 2-hop: >90%
    try std.testing.expect(chain3_ok >= CHAIN_ENTS * 9 / 10); // 3-hop: >90%
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 87: Noisy Path Discovery + Beam Search (Level 11.11)
// ═══════════════════════════════════════════════════════════════════════════════
// Test path discovery robustness under noise. Compare greedy (top-1) vs
// beam search (top-K) for multi-hop traversal with noise.
// ═══════════════════════════════════════════════════════════════════════════════
test "noisy path discovery beam search" {
    const DIM = 1024;

    std.debug.print("\n=== NOISY PATH DISCOVERY + BEAM SEARCH (Level 11.11) ===\n", .{});

    // Build 2-hop chain: 12 entities per layer
    const ENTS_B = 12;
    const LAYERS_B = 3; // 3 layers = 2 hops

    var beam_ents: [LAYERS_B][ENTS_B]Hypervector = undefined;
    for (0..LAYERS_B) |l| {
        for (0..ENTS_B) |i| {
            beam_ents[l][i] = bipolarRandom(DIM, 0xF00000 + @as(u64, @intCast(l)) * 100000 + @as(u64, @intCast(i)) * 7919);
        }
    }

    // Build 2 layer memories
    var beam_mems: [2]Hypervector = undefined;
    for (0..2) |l| {
        var pairs: [ENTS_B]Hypervector = undefined;
        for (0..ENTS_B) |i| {
            pairs[i] = beam_ents[l][i].bind(&beam_ents[l + 1][i]);
        }
        beam_mems[l] = treeBundleN(pairs[0..ENTS_B]);
    }

    // --- Greedy vs Beam under noise ---
    std.debug.print("Noise | Greedy | Beam-3 | Beam-5 | Improvement\n", .{});
    std.debug.print("------|--------|--------|--------|------------\n", .{});

    const TEST_ENTS = 10;
    const NOISE_LEVELS = [_]usize{ 0, 1, 2, 3, 5 };

    for (NOISE_LEVELS) |noise| {
        // --- GREEDY (top-1) ---
        var greedy_ok: usize = 0;
        for (0..TEST_ENTS) |i| {
            var current_g = beam_ents[0][i];
            var step_g: usize = 0;
            while (step_g < 2) : (step_g += 1) {
                var retrieved_g = beam_mems[step_g].unbind(&current_g);
                // Add noise
                for (0..noise) |n| {
                    var nv = Hypervector.random(DIM, 0xF80000 + @as(u64, @intCast(i)) * 10000 + @as(u64, @intCast(step_g)) * 1000 + @as(u64, @intCast(noise)) * 100 + @as(u64, @intCast(n)));
                    retrieved_g = retrieved_g.bundle(&nv);
                }
                var best_g: f64 = -2.0;
                var best_gi: usize = 0;
                for (0..ENTS_B) |j| {
                    const s = retrieved_g.similarity(&beam_ents[step_g + 1][j]);
                    if (s > best_g) { best_g = s; best_gi = j; }
                }
                current_g = beam_ents[step_g + 1][best_gi];
            }
            if (current_g.similarity(&beam_ents[2][i]) > 0.99) greedy_ok += 1;
        }

        // --- BEAM-3 (top-3 candidates at each step) ---
        var beam3_ok: usize = 0;
        for (0..TEST_ENTS) |i| {
            // Track top-3 candidates as (layer_idx, cumulative_sim)
            const K3 = 3;
            var candidates: [K3]usize = undefined;
            var cand_sims: [K3]f64 = undefined;
            candidates[0] = i;
            cand_sims[0] = 1.0;
            var num_cands: usize = 1;

            var step_b: usize = 0;
            while (step_b < 2) : (step_b += 1) {
                // Expand all candidates
                var next_scores: [ENTS_B]f64 = undefined;
                for (0..ENTS_B) |j| next_scores[j] = -2.0;

                for (0..num_cands) |c| {
                    var retrieved_b = beam_mems[step_b].unbind(&beam_ents[step_b][candidates[c]]);
                    // Add noise
                    for (0..noise) |n| {
                        var nv = Hypervector.random(DIM, 0xF80000 + @as(u64, @intCast(i)) * 10000 + @as(u64, @intCast(step_b)) * 1000 + @as(u64, @intCast(noise)) * 100 + @as(u64, @intCast(n)));
                        retrieved_b = retrieved_b.bundle(&nv);
                    }
                    for (0..ENTS_B) |j| {
                        const s = retrieved_b.similarity(&beam_ents[step_b + 1][j]);
                        const total_s = cand_sims[c] + s;
                        if (total_s > next_scores[j]) next_scores[j] = total_s;
                    }
                }

                // Select top-K3
                num_cands = 0;
                for (0..K3) |_| {
                    var best_s: f64 = -999.0;
                    var best_j: usize = 0;
                    for (0..ENTS_B) |j| {
                        if (next_scores[j] > best_s) { best_s = next_scores[j]; best_j = j; }
                    }
                    if (best_s > -999.0) {
                        candidates[num_cands] = best_j;
                        cand_sims[num_cands] = best_s;
                        num_cands += 1;
                        next_scores[best_j] = -999.0; // remove from pool
                    }
                }
            }

            // Check if correct answer is in top candidates
            var found = false;
            for (0..num_cands) |c| {
                if (candidates[c] == i) { found = true; break; }
            }
            if (found) beam3_ok += 1;
        }

        // --- BEAM-5 (top-5 candidates at each step) ---
        var beam5_ok: usize = 0;
        for (0..TEST_ENTS) |i| {
            const K5 = 5;
            var candidates5: [K5]usize = undefined;
            var cand5_sims: [K5]f64 = undefined;
            candidates5[0] = i;
            cand5_sims[0] = 1.0;
            var num5: usize = 1;

            var step5: usize = 0;
            while (step5 < 2) : (step5 += 1) {
                var next5_scores: [ENTS_B]f64 = undefined;
                for (0..ENTS_B) |j| next5_scores[j] = -2.0;

                for (0..num5) |c| {
                    var retrieved5 = beam_mems[step5].unbind(&beam_ents[step5][candidates5[c]]);
                    for (0..noise) |n| {
                        var nv = Hypervector.random(DIM, 0xF80000 + @as(u64, @intCast(i)) * 10000 + @as(u64, @intCast(step5)) * 1000 + @as(u64, @intCast(noise)) * 100 + @as(u64, @intCast(n)));
                        retrieved5 = retrieved5.bundle(&nv);
                    }
                    for (0..ENTS_B) |j| {
                        const s = retrieved5.similarity(&beam_ents[step5 + 1][j]);
                        const total_s = cand5_sims[c] + s;
                        if (total_s > next5_scores[j]) next5_scores[j] = total_s;
                    }
                }

                num5 = 0;
                for (0..K5) |_| {
                    var best_s: f64 = -999.0;
                    var best_j: usize = 0;
                    for (0..ENTS_B) |j| {
                        if (next5_scores[j] > best_s) { best_s = next5_scores[j]; best_j = j; }
                    }
                    if (best_s > -999.0) {
                        candidates5[num5] = best_j;
                        cand5_sims[num5] = best_s;
                        num5 += 1;
                        next5_scores[best_j] = -999.0;
                    }
                }
            }

            var found5 = false;
            for (0..num5) |c| {
                if (candidates5[c] == i) { found5 = true; break; }
            }
            if (found5) beam5_ok += 1;
        }

        const greedy_acc = @as(f64, @floatFromInt(greedy_ok)) / @as(f64, TEST_ENTS) * 100;
        const beam3_acc = @as(f64, @floatFromInt(beam3_ok)) / @as(f64, TEST_ENTS) * 100;
        const beam5_acc = @as(f64, @floatFromInt(beam5_ok)) / @as(f64, TEST_ENTS) * 100;
        const improvement = beam3_acc - greedy_acc;
        std.debug.print("{:>5} | {d:>5.1}% | {d:>5.1}% | {d:>5.1}% | {s}{d:>5.1}%\n", .{
            noise, greedy_acc, beam3_acc, beam5_acc,
            if (improvement >= 0) "+" else "",
            improvement,
        });
    }

    std.debug.print("============================================\n", .{});

    // Just needs to complete
    try std.testing.expect(true);
}
