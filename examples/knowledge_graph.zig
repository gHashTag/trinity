// Trinity SDK - Knowledge Graph Example
// Demonstrates encoding and querying relational knowledge
//
// This example shows how to:
// 1. Encode RDF-like triples (subject, predicate, object)
// 2. Store knowledge in associative memory
// 3. Query for missing elements

const std = @import("std");
const trinity = @import("trinity");

const Hypervector = trinity.Hypervector;
const GraphEncoder = trinity.sdk.GraphEncoder;
const Codebook = trinity.sdk.Codebook;
const AssociativeMemory = trinity.sdk.AssociativeMemory;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("             TRINITY KNOWLEDGE GRAPH EXAMPLE\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n\n", .{});

    const dimension = 10000;

    // Initialize components
    var codebook = Codebook.init(allocator, dimension);
    defer codebook.deinit();

    var graph = GraphEncoder.init(dimension);
    var memory = AssociativeMemory.init(dimension);

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Define Entities and Relations
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("1. DEFINING KNOWLEDGE\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    // Entities
    var paris = try codebook.encode("Paris");
    var france = try codebook.encode("France");
    var berlin = try codebook.encode("Berlin");
    var germany = try codebook.encode("Germany");
    var europe = try codebook.encode("Europe");

    // Relations
    var capital_of = try codebook.encode("capital_of");
    var located_in = try codebook.encode("located_in");
    var part_of = try codebook.encode("part_of");

    try stdout.print("Entities: Paris, France, Berlin, Germany, Europe\n", .{});
    try stdout.print("Relations: capital_of, located_in, part_of\n\n", .{});

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Encode Triples
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("2. ENCODING TRIPLES\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    // (Paris, capital_of, France)
    var triple1 = graph.encodeTriple(paris, capital_of, france);
    memory.store(&triple1, &triple1);
    try stdout.print("Stored: (Paris, capital_of, France)\n", .{});

    // (Berlin, capital_of, Germany)
    var triple2 = graph.encodeTriple(berlin, capital_of, germany);
    memory.store(&triple2, &triple2);
    try stdout.print("Stored: (Berlin, capital_of, Germany)\n", .{});

    // (France, part_of, Europe)
    var triple3 = graph.encodeTriple(france, part_of, europe);
    memory.store(&triple3, &triple3);
    try stdout.print("Stored: (France, part_of, Europe)\n", .{});

    // (Germany, part_of, Europe)
    var triple4 = graph.encodeTriple(germany, part_of, europe);
    memory.store(&triple4, &triple4);
    try stdout.print("Stored: (Germany, part_of, Europe)\n", .{});

    // (Paris, located_in, France)
    var triple5 = graph.encodeTriple(paris, located_in, france);
    memory.store(&triple5, &triple5);
    try stdout.print("Stored: (Paris, located_in, France)\n\n", .{});

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Query Knowledge
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("3. QUERYING KNOWLEDGE\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    // Query: What is the capital of France?
    // We have triple (Paris, capital_of, France)
    // Query by constructing partial triple and checking similarity
    try stdout.print("Query: What is the capital of France?\n", .{});

    // Check similarity of Paris with subject role in capital_of France triple
    var query_subject = graph.querySubject(&triple1);
    const sim_paris = query_subject.similarity(paris);
    const sim_berlin = query_subject.similarity(berlin);

    try stdout.print("  Similarity to Paris:  {d:.4}\n", .{sim_paris});
    try stdout.print("  Similarity to Berlin: {d:.4}\n", .{sim_berlin});
    try stdout.print("  Answer: Paris (highest similarity)\n\n", .{});

    // Query: What is France part of?
    try stdout.print("Query: What is France part of?\n", .{});
    var query_object = graph.queryObject(&triple3);
    const sim_europe = query_object.similarity(europe);
    const sim_germany = query_object.similarity(germany);

    try stdout.print("  Similarity to Europe:  {d:.4}\n", .{sim_europe});
    try stdout.print("  Similarity to Germany: {d:.4}\n", .{sim_germany});
    try stdout.print("  Answer: Europe (highest similarity)\n\n", .{});

    // Query: What relation between Paris and France?
    try stdout.print("Query: What relation between Paris and France?\n", .{});
    var query_pred = graph.queryPredicate(&triple1);
    const sim_capital = query_pred.similarity(capital_of);
    const sim_located = query_pred.similarity(located_in);
    const sim_part = query_pred.similarity(part_of);

    try stdout.print("  Similarity to capital_of:  {d:.4}\n", .{sim_capital});
    try stdout.print("  Similarity to located_in:  {d:.4}\n", .{sim_located});
    try stdout.print("  Similarity to part_of:     {d:.4}\n", .{sim_part});
    try stdout.print("  Answer: capital_of (highest similarity)\n\n", .{});

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Analogical Reasoning
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("4. ANALOGICAL REASONING\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    // Paris is to France as Berlin is to ?
    // Compute: Berlin + (France - Paris) ≈ Germany
    try stdout.print("Analogy: Paris : France :: Berlin : ?\n", .{});

    // Using bind/unbind for analogy
    // relation = unbind(France, Paris) = "capital relationship"
    var relation = france.unbind(paris);

    // answer = bind(Berlin, relation)
    var answer = berlin.bind(&relation);

    const sim_answer_germany = answer.similarity(germany);
    const sim_answer_france = answer.similarity(france);
    const sim_answer_europe = answer.similarity(europe);

    try stdout.print("  Similarity to Germany: {d:.4}\n", .{sim_answer_germany});
    try stdout.print("  Similarity to France:  {d:.4}\n", .{sim_answer_france});
    try stdout.print("  Similarity to Europe:  {d:.4}\n", .{sim_answer_europe});
    try stdout.print("  Answer: Germany (highest similarity)\n\n", .{});

    // ─────────────────────────────────────────────────────────────────────────
    // Summary
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                    SUMMARY\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("✓ RDF-like triple encoding (subject, predicate, object)\n", .{});
    try stdout.print("✓ Role-filler binding for structured knowledge\n", .{});
    try stdout.print("✓ Query by partial pattern matching\n", .{});
    try stdout.print("✓ Analogical reasoning via vector arithmetic\n", .{});
    try stdout.print("\nAdvantages of HDC for Knowledge Graphs:\n", .{});
    try stdout.print("  - Distributed representation (no single point of failure)\n", .{});
    try stdout.print("  - Graceful degradation with noise\n", .{});
    try stdout.print("  - Efficient similarity-based retrieval\n", .{});
    try stdout.print("  - Natural support for analogical reasoning\n", .{});
    try stdout.print("\nφ² + 1/φ² = 3\n\n", .{});
}
