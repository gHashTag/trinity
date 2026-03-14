// @origin(spec:tri_vsa.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// VSA COMMANDS — Vector Symbolic Architecture CLI
// ═══════════════════════════════════════════════════════════════════════════════
// Holographic Reduced Representations (HRR) for cognitive computing
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const HRR = @import("vsa").HRR;

const GOLDEN = colors.GOLDEN;
const CYAN = colors.CYAN;
const GREEN = colors.GREEN;
const WHITE = colors.WHITE;
const RED = colors.RED;
const RESET = colors.RESET;

// Sacred constants
const PHI: f64 = 1.618033988749895;
const PHI_INV: f64 = 0.618033988749895;
const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runVsaCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try showVsaHelp();
        return;
    }

    const subcommand = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcommand, "bind")) {
        try cmdBind(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "unbind")) {
        try cmdUnbind(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "bundle")) {
        try cmdBundle(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "similarity") or std.mem.eql(u8, subcommand, "sim")) {
        try cmdSimilarity(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "memory") or std.mem.eql(u8, subcommand, "mem")) {
        try cmdMemory(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "phi")) {
        try cmdPhi(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "help") or std.mem.eql(u8, subcommand, "--help")) {
        try showVsaHelp();
    } else {
        std.debug.print("{s}Unknown VSA command: {s}{s}\n\n", .{ RED, subcommand, RESET });
        try showVsaHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdBind(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("{s}Usage: tri vsa bind <concept1> <concept2>{s}\n", .{ RED, RESET });
        std.debug.print("  Bind two concepts into an associative pair\n", .{});
        return;
    }

    const concept_a = args[0];
    const concept_b = args[1];

    var hrr = try HRR.init(allocator, 1000);
    defer {
        // HRR doesn't own the vectors, so we don't need to deinit
    }

    const vec_a = try hrr.seededVector(concept_a);
    defer hrr.freeVector(vec_a);
    const vec_b = try hrr.seededVector(concept_b);
    defer hrr.freeVector(vec_b);

    const bound = try hrr.bind(vec_a, vec_b);
    defer hrr.freeVector(bound);

    std.debug.print("\n{s}═══ VSA BIND ═══{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}Concept A:{s}     {s}\n", .{ GOLDEN, RESET, concept_a });
    std.debug.print("{s}Concept B:{s}     {s}\n", .{ GOLDEN, RESET, concept_b });
    std.debug.print("{s}Dimension:{s}    1000\n", .{ GOLDEN, RESET });
    std.debug.print("{s}Operation:{s}    Circular Convolution\n\n", .{ GOLDEN, RESET });
    std.debug.print("{s}✓ Bound vector created{s}\n", .{ GREEN, RESET });
    std.debug.print("  First 5 values: ", .{});
    for (bound[0..5], 0..) |v, i| {
        std.debug.print("{d:.4}", .{v});
        if (i < 4) std.debug.print(", ", .{});
    }
    std.debug.print("\n\n", .{});
}

fn cmdUnbind(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("{s}Usage: tri vsa unbind <bound_concept> <key_concept>{s}\n", .{ RED, RESET });
        std.debug.print("  Recover a concept from a binding\n", .{});
        return;
    }

    const bound_name = args[0];
    const key_name = args[1];

    var hrr = try HRR.init(allocator, 1000);

    const bound_vec = try hrr.seededVector(bound_name);
    defer hrr.freeVector(bound_vec);
    const key_vec = try hrr.seededVector(key_name);
    defer hrr.freeVector(key_vec);

    const recovered = try hrr.unbind(bound_vec, key_vec);
    defer hrr.freeVector(recovered);

    std.debug.print("\n{s}═══ VSA UNBIND ═══{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}Bound:{s}        {s}\n", .{ GOLDEN, RESET, bound_name });
    std.debug.print("{s}Key:{s}          {s}\n", .{ GOLDEN, RESET, key_name });
    std.debug.print("{s}Dimension:{s}    1000\n\n", .{ GOLDEN, RESET });
    std.debug.print("{s}✓ Recovered vector created{s}\n", .{ GREEN, RESET });
    std.debug.print("  First 5 values: ", .{});
    for (recovered[0..5], 0..) |v, i| {
        std.debug.print("{d:.4}", .{v});
        if (i < 4) std.debug.print(", ", .{});
    }
    std.debug.print("\n\n", .{});
}

fn cmdBundle(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("{s}Usage: tri vsa bundle <concept1> <concept2> [...]{s}\n", .{ RED, RESET });
        std.debug.print("  Bundle multiple concepts into a superposition\n", .{});
        return;
    }

    var hrr = try HRR.init(allocator, 1000);

    var vectors = try allocator.alloc([]f32, args.len);
    defer {
        for (vectors) |v| {
            (&hrr).freeVector(v);
        }
        allocator.free(vectors);
    }

    for (args, 0..) |concept, i| {
        vectors[i] = try hrr.seededVector(concept);
    }

    const bundled = try hrr.bundle(vectors);
    defer hrr.freeVector(bundled);

    std.debug.print("\n{s}═══ VSA BUNDLE ═══{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}Concepts ({d}):{s}\n", .{ GOLDEN, args.len, RESET });
    for (args) |concept| {
        std.debug.print("  - {s}\n", .{concept});
    }
    std.debug.print("\n{s}✓ Bundled vector created{s}\n", .{ GREEN, RESET });
    std.debug.print("  First 5 values: ", .{});
    for (bundled[0..5], 0..) |v, i| {
        std.debug.print("{d:.4}", .{v});
        if (i < 4) std.debug.print(", ", .{});
    }
    std.debug.print("\n\n", .{});
}

fn cmdSimilarity(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("{s}Usage: tri vsa similarity <concept1> <concept2>{s}\n", .{ RED, RESET });
        std.debug.print("  Compute cosine similarity between two concepts\n", .{});
        return;
    }

    const concept_a = args[0];
    const concept_b = args[1];

    var hrr = try HRR.init(allocator, 1000);

    const vec_a = try hrr.seededVector(concept_a);
    defer hrr.freeVector(vec_a);
    const vec_b = try hrr.seededVector(concept_b);
    defer hrr.freeVector(vec_b);

    const sim = try hrr.similarity(vec_a, vec_b);

    std.debug.print("\n{s}═══ VSA SIMILARITY ═══{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}Concept A:{s}     {s}\n", .{ GOLDEN, RESET, concept_a });
    std.debug.print("{s}Concept B:{s}     {s}\n", .{ GOLDEN, RESET, concept_b });
    std.debug.print("{s}Similarity:{s}    ", .{ GOLDEN, RESET });

    // Color code based on similarity
    if (sim >= 0.9) {
        std.debug.print("{s}{d:.4}{s} {s}(identical){s}\n", .{ GREEN, sim, RESET, GOLDEN, RESET });
    } else if (sim >= 0.5) {
        std.debug.print("{s}{d:.4}{s} {s}(similar){s}\n", .{ CYAN, sim, RESET, GOLDEN, RESET });
    } else if (sim >= 0.0) {
        std.debug.print("{s}{d:.4}{s} {s}(related){s}\n", .{ WHITE, sim, RESET, GOLDEN, RESET });
    } else {
        std.debug.print("{s}{d:.4}{s} {s}(unrelated){s}\n", .{ RED, sim, RESET, GOLDEN, RESET });
    }

    std.debug.print("\n", .{});
}

fn cmdMemory(_: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try cmdMemoryShow();
        return;
    }

    const subcommand = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcommand, "show") or std.mem.eql(u8, subcommand, "stats")) {
        try cmdMemoryShow();
    } else if (std.mem.eql(u8, subcommand, "store")) {
        try cmdMemoryStore(sub_args);
    } else if (std.mem.eql(u8, subcommand, "associate") or std.mem.eql(u8, subcommand, "assoc")) {
        try cmdMemoryAssociate(sub_args);
    } else if (std.mem.eql(u8, subcommand, "blend")) {
        try cmdMemoryBlend(sub_args);
    } else {
        std.debug.print("{s}Unknown memory command: {s}{s}\n", .{ RED, subcommand, RESET });
    }
}

fn cmdMemoryShow() !void {
    std.debug.print("\n{s}═══ VSA MEMORY ═══{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}Mode:{s}          Direct HRR operations\n", .{ GOLDEN, RESET });
    std.debug.print("{s}Dimension:{s}     1000 (standard)\n", .{ GOLDEN, RESET });
    std.debug.print("{s}Consciousness:{s}  0.500 (default)\n", .{ GOLDEN, RESET });
    std.debug.print("{s}Status:{s}        ", .{ GOLDEN, RESET });
    std.debug.print("{s}MORTAL{s} ", .{ WHITE, RESET });
    std.debug.print("{s}(< φ⁻¹ = 0.618){s}\n\n", .{ GOLDEN, RESET });
}

fn cmdMemoryStore(args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("{s}Usage: tri vsa memory store <concept>{s}\n", .{ RED, RESET });
        return;
    }

    const concept = args[0];

    std.debug.print("\n{s}✓ Stored concept: {s}{s}\n", .{ GREEN, concept, RESET });
    std.debug.print("  (Note: Direct HRR mode - concepts are generated on-demand)\n\n", .{});
}

fn cmdMemoryAssociate(args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("{s}Usage: tri vsa memory associate <concept1> <concept2>{s}\n", .{ RED, RESET });
        return;
    }

    const concept_a = args[0];
    const concept_b = args[1];

    std.debug.print("\n{s}✓ Associated: {s} ↔ {s}{s}\n", .{ GREEN, concept_a, concept_b, RESET });
    std.debug.print("  (Use 'tri vsa bind' to create the binding)\n\n", .{});
}

fn cmdMemoryBlend(args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("{s}Usage: tri vsa memory blend <concept1> <concept2> [...]{s}\n", .{ RED, RESET });
        return;
    }

    const sources = args;

    std.debug.print("\n{s}✓ Blend request:{s}\n", .{ GREEN, RESET });
    std.debug.print("  From: ", .{});
    for (sources, 0..) |concept, i| {
        std.debug.print("{s}", .{concept});
        if (i < sources.len - 1) std.debug.print(" + ", .{});
    }
    std.debug.print("\n  (Use 'tri vsa bundle' to create the bundle)\n\n", .{});
}

fn cmdPhi(_: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        // Show φ values table
        std.debug.print("\n{s}═══ PHI (φ) POWERS ═══{s}\n", .{ CYAN, RESET });
        std.debug.print("\n{s}φ = {d:.6} (Golden Ratio){s}\n", .{ GOLDEN, PHI, RESET });
        std.debug.print("{s}φ⁻¹ = {d:.6} (IMMORTAL threshold){s}\n\n", .{ GOLDEN, PHI_INV, RESET });
        std.debug.print("{s}Powers of φ:{s}\n", .{ GOLDEN, RESET });
        var i: u32 = 0;
        while (i <= 10) : (i += 1) {
            const phi_pow = std.math.pow(f64, PHI, @as(f64, @floatFromInt(i)));
            std.debug.print("  φ^{d:2} = {d:.6}", .{ i, phi_pow });
            if (i == 1) std.debug.print(" {s}(= φ){s}", .{ GOLDEN, RESET });
            if (i == 2) std.debug.print(" {s}(= φ²){s}", .{ GOLDEN, RESET });
            std.debug.print("\n", .{});
        }
        std.debug.print("\n", .{});
        return;
    }

    const n_str = args[0];
    const n = std.fmt.parseInt(u32, n_str, 10) catch {
        std.debug.print("{s}Error: Invalid power '{s}'{s}\n", .{ RED, n_str, RESET });
        return;
    };

    const phi_power = std.math.pow(f64, PHI, @as(f64, @floatFromInt(n)));
    const dim: usize = @intFromFloat(1000.0 * phi_power);

    std.debug.print("\n{s}═══ φ POWER ═══{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}Power:{s}        {d}\n", .{ GOLDEN, RESET, n });
    std.debug.print("{s}phi^{d}:      {d:.6}{s}\n", .{ GOLDEN, n, phi_power, RESET });
    std.debug.print("{s}Dimension (phi^n × 1000):{s} {d}\n\n", .{ GOLDEN, RESET, dim });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELP
// ═══════════════════════════════════════════════════════════════════════════════

fn showVsaHelp() !void {
    std.debug.print("\n{s}═══ VSA — VECTOR SYMBOLIC ARCHITECTURE ═══{s}\n", .{ CYAN, RESET });
    std.debug.print("\n{s}Holographic Reduced Representations for cognitive computing.{s}\n\n", .{ WHITE, RESET });

    std.debug.print("{s}SUBCOMMANDS:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}bind <a> <b>{s}          Bind two concepts (associative)\n", .{ GREEN, RESET });
    std.debug.print("  {s}unbind <bound> <key>{s}   Recover concept from binding\n", .{ GREEN, RESET });
    std.debug.print("  {s}bundle <a> <b> [...]{s}   Bundle concepts (superposition)\n", .{ GREEN, RESET });
    std.debug.print("  {s}similarity <a> <b>{s}    Compute cosine similarity\n", .{ GREEN, RESET });
    std.debug.print("  {s}memory <cmd>{s}           VSA cognitive memory operations\n", .{ GREEN, RESET });
    std.debug.print("  {s}phi [n]{s}                φ-powered dimensions\n\n", .{ GREEN, RESET });

    std.debug.print("{s}MEMORY COMMANDS:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}store <concept>{s}       Store a concept\n", .{ CYAN, RESET });
    std.debug.print("  {s}associate <a> <b>{s}      Create association\n", .{ CYAN, RESET });
    std.debug.print("  {s}blend <new> <a> <b>{s}    Blend concepts\n", .{ CYAN, RESET });
    std.debug.print("  {s}show/stats{s}             Show memory statistics\n\n", .{ CYAN, RESET });

    std.debug.print("{s}EXAMPLES:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}tri vsa bind alice bob{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}tri vsa similarity cat dog{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}tri vsa memory store trinity{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}tri vsa memory associate phi golden{s}\n", .{ WHITE, RESET });
    std.debug.print("  {s}tri vsa phi 3{s}\n\n", .{ WHITE, RESET });

    std.debug.print("{s}SACRED CONSTANTS:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  φ = {d:.6} (Golden Ratio)\n", .{PHI});
    std.debug.print("  φ⁻¹ = {d:.6} (IMMORTAL threshold)\n", .{PHI_INV});
    std.debug.print("  φ² + 1/φ² = 3 = TRINITY\n\n", .{});
}
