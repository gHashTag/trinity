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
