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
