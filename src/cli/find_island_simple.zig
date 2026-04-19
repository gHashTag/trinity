// TRI CLI — Cryptic Finding Island (Simplified)
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ANSI Colors
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";
const RESET = "\x1b[0m";

// Storage paths
const ISLANDS_FILE = ".trinity/data/islands.json";
const DISCOVERIES_FILE = ".trinity/data/discoveries.json";

pub const Island = struct {
    id: []const u8,
    name: []const u8,
    domain: []const u8,
    riddle: []const u8,
    answer: []const u8,
    knowledge: []const u8,
    difficulty: u8,
    discovered: bool,
    discovery_date: ?[]const u8,
    clues_count: u8,
};

// Predefined Islands
const PREDEFINED_ISLANDS = [_]Island{
    .{
        .id = "island_phi_wisdom",
        .name = "Phi Wisdom Island",
        .domain = "sacred_formula",
        .riddle = "What ratio equals phi squared plus 1 over phi squared?",
        .answer = "phi^2 + 1/phi^2",
        .knowledge = "The golden ratio phi^2 + 1/phi^2 = 3. This sacred relationship governs the emergence of consciousness from mathematical perfection into biological manifestation. phi ≈ 1.61803398875.",
        .difficulty = 4,
        .clues_count = 3,
    },
    .{
        .id = "island_vsa_horizon",
        .name = "Vector Horizon Island",
        .domain = "vsa",
        .riddle = "I bind vectors, you bundle them, then what remains unbound?",
        .answer = "Zero - the essence of void, preserved through unbind operation.",
        .knowledge = "VSA bind/unbind operations: bind(v1, v2) -> Creates a new vector association, bundle(v1, v2, v3) -> Creates a composite vector from 3 source vectors, unbundle(v) -> Frees a vector (no longer bound to anything), Similarity: dot(v1, v2) -> Cosine angle (how aligned two vectors are). All VSA operations are associative and preserve the Trinity principle: combining two concepts never destroys information.",
        .difficulty = 3,
        .clues_count = 2,
    },
    .{
        .id = "island_ternary_trinity",
        .name = "Ternary Trinity Island",
        .domain = "tri",
        .riddle = "In the sacred trinity of values {-1, 0, +1}, what is perfect balance?",
        .answer = "Zero - perfect equilibrium between negative and positive, the origin point of all transformation.",
        .knowledge = "The sacred trinity principle: Trinity of {-1, 0, +1} represents perfect balance. All ternary operations must preserve this sacred invariant. Ternary negation: -(-x) = x, Ternary multiplication: (-x) * (-y) = x, Ternary addition: (-x) + (-y) = z, Ternary shift: rotate(x) -> cyclic shift preserving trit values.",
        .difficulty = 5,
        .clues_count = 2,
    },
    .{
        .id = "island_blind_spot_realm",
        .name = "Blind Spot Realm",
        .domain = "blind_spots",
        .riddle = "I see everything, yet I perceive nothing. What am I missing?",
        .answer = "Knowledge Gaps - The blind spots are the dark matter of understanding. 90+ new formulas across 8 domains. The sacred prediction confidence is 0.42. What do we truly know?",
        .knowledge = "Blind spots are gaps between VERIFIED, PREDICTED, and BLIND knowledge. Each represents an opportunity for discovery. High-sacred-weight predictions from KOSCHEI EYE v2.0 suggest new physics beyond Standard Model.",
        .difficulty = 4,
        .clues_count = 3,
    },
    .{
        .id = "island_sacred_constants",
        .name = "Sacred Constants Archive",
        .domain = "sacred_constants",
        .riddle = "The constants phi, pi, and e are sacred. But what patterns connect them?",
        .answer = "The Golden Chain: phi^2 + 1/phi^2 = 3, phi = sqrt(3)/2, pi = 4*sqrt(3)/2, e = 2.718. The Golden Chain: 1/phi + 1/phi^2 = 3. The Golden Chain connects all sacred constants through proportion.",
        .knowledge = "Golden Chain Mathematics: phi ≈ 1.618, pi ≈ 3.142, e ≈ 2.718. Recursive formula: 1/phi + 1/phi^2 = 3.",
        .difficulty = 3,
        .clues_count = 2,
    },
    .{
        .id = "island_agent_mu",
        .name = "Mu Agent Archives",
        .domain = "agent_mu",
        .riddle = "The Mu agent learns from experience. What algorithm did it converge on?",
        .answer = "Hyperparameter Search - The Mu agent explores hyperparameter space using Bayesian optimization. It converged on: learning_rate=0.01 with momentum=0.9.",
        .knowledge = "Mu Agent Algorithms: Learning Rate: 0.01, Momentum: 0.9, Best model: Mu-7B-Llama2-7B (7B parameters, L layers).",
        .difficulty = 4,
        .clues_count = 2,
    },
    .{
        .id = "island_quantum_criticality",
        .name = "Quantum Criticality Island",
        .domain = "quantum",
        .riddle = "In quantum mechanics, critical exponents describe decay rates. What is the criticality of the universe?",
        .answer = "KOSCHEI Exponent - The KOSCHEI criticality exponent kappa describes how the universe expands: d/dt ≈ (t/t_0)^kappa. Currently measured as kappa ≈ 1.67 (universe expanding at 67% of speed of light).",
        .knowledge = "Quantum Criticality: kappa ≈ 1.67, CMB (Cosmic Microwave Background): 2.725 K, Lambda_CDM (Cold Dark Matter): 0.30.",
        .difficulty = 5,
        .clues_count = 2,
    },
};

// Find island by ID
fn findIslandById(allocator: std.mem.Allocator, island_id: []const u8) ?Island {
    inline for (PREDEFINED_ISLANDS) |predefined| {
        if (std.mem.eql(u8, predefined.id, island_id)) return predefined;
    }
    return null;
}

// Format island summary
fn formatIslandSummary(allocator: std.mem.Allocator, island: Island) ![]const u8 {
    const difficulty_indicator = switch (island.difficulty) {
        1 => "{s}●{s}",
        2 => "{s}●●{s}",
        3 => "{s}●●●{s}",
        4 => "{s}●●●●{s}",
        5 => "{s}●●●●●{s}",
        _ => "{s}●●●●●●{s}",
    };

    const status = if (island.discovered)
        "{s}{GREEN} Discovered{s}"
    else
        "{s}{CYAN} Undiscovered{s}";

    return try std.fmt.allocPrintZ(allocator,
        "\\n{name}: {s}\\n{domain}: {s}\\n{difficulty}: {s}\\n{status}: {s}\\n\\n{s}\\n",
        .{ island.name, island.domain, difficulty_indicator, status }
    );
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        print("{s}🏝️ Cryptic Finding Island{s}\\n", .{MAGENTA});
        print("{s}Usage: tri find island <command> [options]{s}\\n", .{CYAN});
        print("{s}Commands:{s}\\n", .{RESET});
        print("  --list               List all islands");
        print("  --domain <name>      Filter by domain");
        print("  --clues <id>        Show clues for an island");
        print("  --solve <id> <ans>   Submit answer to riddle");
        print("  --hint <id> [1-3]   Get a hint");
        print();
        print("{s}Predefined Islands:{s}\\n", .{MAGENTA});
        inline for (PREDEFINED_ISLANDS) |predef| {
            print("  {s}{c}•{s} {s}\\n", .{GREEN, predef.id, "--", predef.name});
        }
        return;
    }

    const command = args[1];
    const island_arg = if (args.len > 1) args[2] else "";

    // List all islands
    if (std.mem.eql(u8, command, "--list")) {
        print("{s}🏝️ Cryptic Finding Islands{s}\\n", .{MAGENTA});
        inline for (PREDEFINED_ISLANDS) |predef| {
            const summary = try formatIslandSummary(allocator, predef);
            defer allocator.free(summary);
            print("{s}", summary);
        }
        return;
    }

    // Show clues for an island
    if (std.mem.eql(u8, command, "--clues") and island_arg.len > 0) {
        const island = findIslandById(allocator, island_arg);
        if (island == null) {
            print("{s}❌ Island not found: {s}\\n", .{RED}, island_arg);
            return;
        }
        if (island.clues_count == 0) {
            print("{s}No clues available for this island.\\n", .{YELLOW});
            return;
        }
        print("{s}📜 Clues for '{s}': {s}\\n", .{CYAN}, island.name);
        print("{s}Clue count: {d}\\n", .{MAGENTA}, island.clues_count);
        print();
        return;
    }

    // Submit answer to solve riddle
    if (std.mem.eql(u8, command, "--solve") and args.len > 2) {
        const island_id = args[2];
        const answer = args[3];

        const island = findIslandById(allocator, island_id);
        if (island == null) {
            print("{s}❌ Island not found: {s}\\n", .{RED}, island_id);
            return;
        }

        const answer_lower = try std.ascii.lowerStringAlloc(allocator, answer);
        defer allocator.free(answer_lower);
        const correct_answer_lower = try std.ascii.lowerStringAlloc(allocator, island.answer);
        defer allocator.free(correct_answer_lower);

        const is_correct = std.mem.eql(u8, answer_lower, correct_answer_lower);

        if (is_correct) {
            print("{s}✅ Correct!{s}\\n", .{GREEN});
            print("{s}{s}You discovered: {s}\\n", .{CYAN}, island.name);
            print("{s}{s}Knowledge revealed:{s}\\n", .{RESET}, island.knowledge);
        } else {
            print("{s}❌ Incorrect. Try again!{s}\\n", .{RED});
            print("{s}{s}The answer is: {s}\\n", .{YELLOW}, island.answer);
            print("{s}{s}Hint: {s}\\n", .{RESET}, island.riddle);
        }
        return;
    }

    // Get hint
    if (std.mem.eql(u8, command, "--hint") and args.len > 1) {
        const island_id = args[2];
        const hint_level: if (args.len > 2) std.fmt.parseInt(u8, args[3], 10) catch |_| 1 else 1;

        if (hint_level < 1 or hint_level > 3) {
            print("{s}❌ Invalid hint level: {d}. Use 1 (subtle), 2 (clear), or 3 (strong).{s}\\n", .{RED});
            return;
        }

        const island = findIslandById(allocator, island_id);
        if (island == null) {
            print("{s}❌ Island not found: {s}\\n", .{RED}, island_id);
            return;
        }

        if (island.clues_count == 0) {
            print("{s}No clues available for this island.\\n", .{YELLOW});
            return;
        }

        const hint_names = [_]const u8{ "subtle hint", "clear hint", "strong hint" };
        const actual_hint = if (hint_level <= @as(island.clues_count, @as(u32, hint_names[hint_level - 1]))) hint_names[hint_level - 1] else "no more hints";

        print("{s}💡 Hint for '{s}': {s}\\n", .{CYAN}, island.name);
        print("{s}{s}{s}\\n", .{RESET}, actual_hint);
        return;
    }

    // Search by query or domain
    if (island_arg.len > 0 and !std.mem.eql(u8, command[0], "--")) {
        const query = island_arg;
        var found_any = false;

        print("{s}🏝️ Searching for: '{s}'{s}\\n", .{CYAN}, query);
        print();

        inline for (PREDEFINED_ISLANDS) |predef| {
            const matches_query = std.mem.indexOfScalar(u8, query, predef.id) != null or std.mem.indexOfScalar(u8, query, predef.name) != null or std.mem.indexOfScalar(u8, query, predef.domain) != null or std.mem.indexOfScalar(u8, query, predef.riddle) != null;
            const matches_domain = std.mem.eql(u8, query, predef.domain);

            if (matches_query or matches_domain) {
                found_any = true;
                const summary = try formatIslandSummary(allocator, predef);
                defer allocator.free(summary);
                print("{s}", summary);
            }
        }

        if (!found_any) {
            print("{s}❌ No islands matching: '{s}'{s}\\n", .{RED}, query);
        }
        return;
    }

    print("{s}❌ Unknown command: {s}\\n", .{RED}, command);
    print("{s}Use --list to see all islands, or search by name or domain.\\n", .{YELLOW});
}
