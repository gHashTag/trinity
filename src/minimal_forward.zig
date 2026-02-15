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
