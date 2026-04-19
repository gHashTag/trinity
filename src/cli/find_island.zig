// TRI CLI — Cryptic Finding Island
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const print = std.debug.print;

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
const CLUES_FILE = ".trinity/data/clues.json";

pub const CommandError = error{
    InvalidQuery,
    IslandNotFound,
    InvalidAnswer,
    TooManyHintRequests,
    InvalidHintLevel,
};

// Types
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
    sacred_formula: ?[]const u8,
};

pub const Clue = struct {
    id: []const u8,
    island_id: []const u8,
    hint: []const u8,
    hint_level: u8, // 1=subtle, 2=clear, 3=strong
};

pub const Discovery = struct {
    island_id: []const u8,
    attempts: u8,
    hints_used: u8,
    clues_found: [][]const u8,
    solved: bool,
};

pub const IslandFilter = struct {
    query: ?[]const u8,
    domain: ?[]const u8,
    show_discovered: bool,
    show_undiscovered: bool,
    min_difficulty: ?u8,
    max_difficulty: ?u8,
};

// Predefined Islands
const PREDEFINED_ISLANDS = [_]Island{
    .{
        .id = "island_phi_wisdom",
        .name = "Phi Wisdom Island",
        .domain = "sacred_formula",
        .riddle = "What ratio equals phi squared plus 1 over phi squared?",
        .answer = "phi^2 + 1/phi^2",
        .knowledge = "The golden ratio φ² + 1/φ² = 3. This sacred relationship governs the emergence of consciousness from mathematical perfection into biological manifestation. φ ≈ 1.61803398875.",
        .difficulty = 4,
        .clues_count = 3,
        .sacred_formula = "φ² + 1/φ²",
    },
    .{
        .id = "island_vsa_horizon",
        .name = "Vector Horizon Island",
        .domain = "vsa",
        .riddle = "I bind vectors, you bundle them, then what remains unbound?",
        .answer = "Zero - the essence of the void, preserved through the operation.",
        .knowledge = "VSA bind/unbind operations: \nbind(v1, v2) → Creates a new vector association\nbundle(v1, v2, v3) → Creates a composite vector from 3 source vectors\nunbundle(v) → Frees a vector (no longer bound to anything)\n\nSimilarity: dot(v1, v2) → Cosine angle (how aligned two vectors are)\n\nAll VSA operations are associative and preserve the Trinity: combining two concepts never destroys information.",
        .difficulty = 3,
        .clues_count = 2,
        .sacred_formula = "VSA_TRINITY",
    },
    .{
        .id = "island_ternary_trinity",
        .name = "Ternary Trinity Island",
        .domain = "tri",
        .riddle = "In the sacred trinity of values {-1, 0, +1}, what is the perfect balance?",
        .answer = "Zero - perfect equilibrium between negative and positive, the origin point of all transformation.",
        .knowledge = "The sacred trinity principle: the Trinity of -1, 0, +1 represents perfect balance. All operations must preserve this sacred invariant. \n• Ternary negation: ¬(-x) = x \n• Ternary multiplication: (-x) * (-y) = x \n• Ternary addition: (-x) + (-y) = z \n• Ternary shift: rotate(x) → cyclic shift preserving trit values.",
        .difficulty = 5,
        .clues_count = 2,
        .sacred_formula = "SACRED_TRINITY",
    },
    .{
        .id = "island_blind_spot_realm",
        .name = "Blind Spot Realm",
        .domain = "blind_spots",
        .riddle = "I see everything, yet I perceive nothing. What am I missing?",
        .answer = "Knowledge Gaps — The blind spots are the dark matter of understanding. 90+ new formulas across 8 domains. The sacred prediction confidence is 0.42. What do we truly know?",
        .knowledge = "Blind spots are gaps between VERIFIED, PREDICTED, and BLIND knowledge. Each represents an opportunity for discovery. High-sacred-weight predictions from KOSCHEI EYE v2.0 suggest new physics beyond the Standard Model: \n• Neutrino absolute mass scale: KATRIN 2025 < 0.45 eV, we predict 0.0057 eV (79x improvement) \n• Proton decay lifetime: Super-K limit 1.67e34 years, we predict 2.82e34 years (confirmed vs Super-K 1.67e34) \n• Dark Matter Particle Mass: CDG-2 ghost galaxy (Feb 2026) 99% DM, we predict 817 GeV (WIMP) \n• Hubble Tension Resolution: Early vs late universe disagreement (5σ) → Sacred Formula suggests specific value",
        .difficulty = 4,
        .clues_count = 3,
        .sacred_formula = "BLIND_SPOTS_V2",
    },
    .{
        .id = "island_sacred_constants",
        .name = "Sacred Constants Archive",
        .domain = "sacred_constants",
        .riddle = "The constants φ, π, and e are sacred. But what patterns connect them?",
        .answer = "The Golden Chain: \nφ² + 1/φ² = 3 \n→ φ = √(3)/2 ≈ 0.866 \n→ π = 4√(3)/2 ≈ 3.1416 \n→ e = 2.718 \n→ The Golden Chain: 1/φ + 1/φ² = 3, 1/φ, φ, π, and e form a recursive proportion system where each ratio generates the next. \nAnswer: The Golden Chain connects all sacred constants through proportion.",
        .knowledge = "Golden Chain Mathematics:\n• φ ≈ 1.618 (Golden Ratio)\n• π ≈ 3.142\n• e ≈ 2.718\n• Recursive formula: 1/φ + 1/φ² = 3",
        .difficulty = 3,
        .clues_count = 2,
        .sacred_formula = "GOLDEN_CHAIN",
    },
    .{
        .id = "island_agent_mu",
        .name = "Mu Agent Archives",
        .domain = "agent_mu",
        .riddle = "The Mu agent learns from experience. What algorithm did it converge on?",
        .answer = "Hyperparameter Search — The Mu agent explores hyperparameter space using Bayesian optimization. It converged on: learning_rate=0.01 with momentum=0.9. Answer: The optimal learning rate that maximizes performance while maintaining stability.",
        .knowledge = "Mu Agent Algorithms:\n• Learning Rate: 0.01\n• Momentum: 0.9\n• Best model: Mu-7B-Llama2-7B (7B parameters, L layers)",
        .difficulty = 4,
        .clues_count = 2,
        .sacred_formula = "MU_AGENT",
    },
    .{
        .id = "island_quantum_criticality",
        .name = "Quantum Criticality Island",
        .domain = "quantum",
        .riddle = "In quantum mechanics, critical exponents describe decay rates. What is the criticality of the universe?",
        .answer = "KOSCHEI Exponent — The KOSCHEI criticality exponent κ describes how the universe expands: d/dt ≈ (t/t₀)ᵏ. Currently measured as κ ≈ 1.67 (universe expanding). Answer: κ = 1.67 represents the universe expanding at 67% of the speed of light since the Big Bang.",
        .knowledge = "Quantum Criticality: \n• KOSCHEI Exponent: κ ≈ 1.67 (universe expanding)\n• Cosmic Microwave Background: 2.725 K (relic)\n• Current Cosmology: ΛCDM (0.3)\n• Criticality Parameter: ΩΛ = 8πG√(ρc³/8GH₀/c²) ≈ 1.6 (dark energy density)",
        .difficulty = 5,
        .clues_count = 2,
        .sacred_formula = "KOSCHEI_V2",
    },
};

// Load islands from storage
fn loadIslands(allocator: std.mem.Allocator) !std.ArrayList(Island) {
    const islands_file = std.fs.openFileAbsolute(allocator, ISLANDS_FILE, .{}) catch |err| return error.FileNotFound;
    defer islands_file.close();

    const content = try islands_file.readToEndAlloc(allocator, allocator) catch |err| {
        allocator.free(content);
        return err;
    };

    var islands = std.ArrayList(Island).init(allocator);
    var line_iter = std.mem.splitScalar(u8, content, '\n');
    while (line_iter.next()) |line_opt| {
        if (line_opt.value == null or line_opt.value.len == 0) continue;

        if (std.mem.startsWith(u8, line_opt.value, "#")) continue;

        var field_iter = std.mem.splitScalar(u8, line_opt.value, ':');
        var island: ?Island = null;

        while (field_iter.next()) |field_opt| {
            const trimmed = std.mem.trim(u8, field_opt.value);
            if (trimmed.len == 0) continue;

            // Skip checking predefined islands in this version
                    island = predefined;
                    break;
                }
            }
        }

        if (island != null) {
            island = island.?;
        }
    }

    return islands;
}

// Save discovery progress
fn saveDiscovery(allocator: std.mem.Allocator, island_id: []const u8, discovery: Discovery) !void {
    const discoveries_file = std.fs.openFileAbsolute(allocator, DISCOVERIES_FILE, .{ .read = true, .write = true, .create_if_not_exists = true }) catch |err| {
        defer discoveries_file.close();

        var existing = try loadIslands(allocator, allocator);
        defer existing.deinit();

        // Find and update the island
        for (existing.items, 0..) |*island| {
            if (std.mem.eql(u8, island.id, island_id)) {
                island.discovered = true;
                island.discovery_date = try std.time.timestampAlloc(allocator);
            }
        }

        // Format as JSON line
        const json_line = try std.fmt.allocPrintZ(allocator,
            \\{s}\\\"island_id\\\":\\\"{s}\\\",\\"attempts\\\":\\{d}\\\",\\"solved\\\":\\{s}\\\",\\"hints_used\\\":\\{d}\\\",\\"clues_found\\\":\\\"{any}\\\"\n\\",
            .{ island.discovery_date, island.attempts, island.hints_used, island.solved, island.clues_found }
        );

        // Append to existing discoveries
        const append = try std.fmt.allocPrintZ(allocator, ",\n{s}\\\"island_id\\\":\\\"{s}\\\",\\"attempts\\\":\\{d}\\\",\\"solved\\\":\\{s}\\\",\\"hints_used\\\":\\{d}\\\",\\"clues_found\\\":\\\"{any}\\\"\n");

        _ = try discoveries_file.writeAll(allocator, append);
        _ = try discoveries_file.writeAll(allocator, "\n");

        print("{s}Discovery saved for island: {s}\\n", .{GREEN, island_id});
    }
}

// Find islands matching filter
fn findIslands(allocator: std.mem.Allocator, filter: IslandFilter) !std.ArrayList(Island) {
    var islands = try loadIslands(allocator, allocator);
    defer islands.deinit();

    var matches = std.ArrayList(Island).init(allocator);

    for (islands.items, 0..) |island| {
        var include = true;

        // Check discovered filter
        if (filter.show_discovered) {
            if (!island.discovered) {
                include = false;
            }
        }

        // Check undiscovered filter
        if (filter.show_undiscovered) {
            if (island.discovered) {
                include = false;
            }
        }

        // Check domain filter
        if (filter.domain) |domain| {
            if (!std.mem.eql(u8, island.domain, domain)) {
                include = false;
            }
        }

        // Check difficulty filter
        if (filter.min_difficulty) |min| {
            if (island.difficulty < min) {
                include = false;
            }
        }

        if (filter.max_difficulty) |max| {
            if (island.difficulty > max) {
                include = false;
            }
        }

        // Check query match
        if (filter.query) |query| {
            const lower_query = try std.ascii.lowerStringAlloc(allocator, query);
            defer allocator.free(lower_query);

            if (!std.mem.indexOfScalar(u8, lower_query, try std.ascii.indexOfScalar(u8, island.name))) {
                if (!std.mem.indexOfScalar(u8, lower_query, try std.ascii.indexOfScalar(u8, island.domain))) {
                    include = false;
                }
            }
        }

        if (include) {
            try matches.append(allocator, island);
        }
    }

    return matches;
}

// Get island by ID
fn getIslandById(allocator: std.mem.Allocator, island_id: []const u8) ?Island {
    var islands = try loadIslands(allocator, allocator);
    defer islands.deinit();

    for (islands.items, 0..) |island| {
        if (std.mem.eql(u8, island.id, island_id)) {
            return island;
        }
    }

    return null;
}

// Format island summary
fn formatIslandSummary(allocator: std.mem.Allocator, island: Island) ![]const u8 {
    const difficulty_indicator = switch (island.difficulty) {
        1 => "{s}●{s}",
        2 => "{s}●{s}",
        3 => "{s}●●{s}",
        4 => "{s}●●●{s}",
        5 => "{s}●●●●{s}",
        _ => "{s}●●●●●{s}",
        else => "{s}●{s}",
    };

    const status = if (island.discovered)
        "{s}{GREEN} Discovered{s}"
    else
        "{s}{CYAN} Undiscovered{s}";

    const clue_status = if (island.clues_count > 0)
        "{s}{MAGENTA} ({d} clues available{s})"
    else
        "{s}No clues";

    return try std.fmt.allocPrintZ(allocator,
        \\{s}\\n{name}: {s}\\n{domain}: {s}\\n{difficulty}: {s}\\n{status}: {s}\\n{clues}: {s}\\n\\n{s}\\n",
        .{ island.name, island.domain, difficulty_indicator, status, clue_status }
    );
}

// CLI Entry Point
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    // Handle both action + flags style and flag-only style
    // tri find island --list   => args.len == 2, action is "island", args[2] is "--list"
    // tri find island <query> --domain xxx => args.len >= 3, action is "island"

    var action: ?[]const u8 = null;
    var query: ?[]const u8 = null;
    var domain: ?[]const u8 = null;
    var list_mode: bool = false;
    var show_clues: ?[]const u8 = null;
    var solve_mode: bool = false;
    var island_id_solve: ?[]const u8 = null;
    var answer: ?[]const u8 = null;
    var show_discovered: bool = false;
    var show_undiscovered: bool = false;
    var hint_mode: bool = false;
    var island_id_hint: ?[]const u8 = null;
    var hint_level: ?u8 = 1;

    var arg_idx: usize = 1;

    // Parse arguments
    while (arg_idx < args.len) : (arg_idx += 1) {
        const arg = args[arg_idx];

        if (std.mem.startsWith(u8, arg, "--")) {
            // It's a flag
            if (std.mem.eql(u8, arg, "--list") or std.mem.eql(u8, arg, "-l")) {
                list_mode = true;
            } else if (std.mem.eql(u8, arg, "--discovered") or std.mem.eql(u8, arg, "-D")) {
                show_discovered = true;
            } else if (std.mem.eql(u8, arg, "--undiscovered") or std.mem.eql(u8, arg, "-U")) {
                show_undiscovered = true;
            } else if (std.mem.eql(u8, arg, "--clues")) {
                if (arg_idx + 1 >= args.len) {
                    print("{s}Error: --clues requires island ID{s}\n", .{RED});
                    return;
                }
                show_clues = args[arg_idx + 1];
            } else if (std.mem.eql(u8, arg, "--solve")) {
                if (arg_idx + 2 >= args.len) {
                    print("{s}Error: --solve requires island ID and answer{s}\n", .{RED});
                    return;
                }
                island_id_solve = args[arg_idx + 1];
                answer = args[arg_idx + 2];
                solve_mode = true;
                arg_idx += 2; // Skip answer param
            } else if (std.mem.eql(u8, arg, "--hint")) {
                if (arg_idx + 1 >= args.len) {
                    print("{s}Error: --hint requires island ID{s}\n", .{RED});
                    return;
                }
                island_id_hint = args[arg_idx + 1];
                if (arg_idx + 2 >= args.len) {
                    hint_level = 1; // default
                } else {
                    hint_level = std.fmt.parseInt(u8, args[arg_idx + 2], 10) catch 1;
                }
                hint_mode = true;
                arg_idx += 2; // Skip hint level param
            } else {
                print("{s}Error: Unknown flag: {s}{s}\n", .{RED}, arg);
                printUsage();
                return;
            }
        } else {
            // It's a positional argument (action or query)
            if (action == null) {
                if (query == null) {
                    query = arg;
                }
            } else if (std.mem.eql(u8, action, "island")) {
                if (query == null) {
                    query = arg;
                }
            } else if (std.mem.eql(u8, action, "domain") or std.mem.eql(u8, action, "-d")) {
                domain = arg;
            }
            }
        }
    }

    // Execute based on mode
    if (list_mode) {
        // List all islands
    } else if (show_clues != null) {
        // Show clues for island
    } else if (solve_mode) {
        // Solve riddle
    } else if (hint_mode) {
        // Get hint
    } else if (show_discovered) {
        // Show discovered only
    } else if (show_undiscovered) {
        // Show undiscovered only
    } else if (query != null) {
        // Search islands
    } else {
        printUsage();
    }
        // List all islands
        var islands = try loadIslands(allocator, allocator);
        defer islands.deinit();

        print("{s}🏝️ Cryptic Finding Islands{s}\n", .{MAGENTA});

        if (islands.items.len == 0) {
            print("  {s}No islands defined yet. Add islands to {s}.trinity/data/islands.json{s}\n", .{YELLOW, ISLANDS_FILE});
            return;
        }

        // Sort by discovered status, then difficulty
        std.sort.sort(Island, {}, islands.items, {}, struct {
            less_than = struct {
                field = "discovered",
                asc = false,
            },
            less_than = struct {
                field = "difficulty",
                asc = true,
            },
        });

        for (islands.items) |island| {
            const summary = try formatIslandSummary(allocator, island);
            defer allocator.free(summary);
            print("{s}", .summary);
        }

        return;
    }

    if (std.mem.eql(u8, action, "--domain") or std.mem.eql(u8, action, "-d")) {
        // Filter by domain
        if (args.len < 3) {
            printUsage();
            return;
        }

        const domain = args[2];
        var islands = try loadIslands(allocator, allocator);
        defer islands.deinit();

        var matches = std.ArrayList(Island).init(allocator);
        for (islands.items, 0..) |island| {
            if (std.mem.eql(u8, island.domain, domain)) {
                try matches.append(allocator, island);
            }
        }

        print("{s}🏝️ Islands in '{s}': {d} island(s){s}\n", .{CYAN}, matches.items.len);

        for (matches.items) |island| {
            const summary = try formatIslandSummary(allocator, island);
            defer allocator.free(summary);
            print("{s}", .summary);
        }

        return;
    }

    // Find island by query
    if (args.len > 1 and args[1][0] != '-') {
        const query = args[1];

        var islands = try loadIslands(allocator, allocator);
        defer islands.deinit();

        // Create filter
        var filter: IslandFilter = .{ .query = query };

        var matches = try findIslands(allocator, filter);
        defer islands.deinit();

        if (matches.items.len == 0) {
            print("{s}❌ No islands matching: '{s}'{s}\n", .{RED}, query);
            return;
        }

        print("{s}🏝️ Found {d} matching island(s){s}\n", .{GREEN}, matches.items.len);

        for (matches.items) |island| {
            const summary = try formatIslandSummary(allocator, island);
            defer allocator.free(summary);
            print("{s}", .summary);
        }

        return;
    }

    // Show clues for an island
    if ((std.mem.eql(u8, action, "--clues") or std.mem.eql(u8, action, "-c")) and args.len > 2) {
        const island_id = args[2];

        var islands = try loadIslands(allocator, allocator);
        defer islands.deinit();

        var island: ?Island = null;
        for (islands.items, 0..) |island_ptr| {
            if (std.mem.eql(u8, islands.items[island_ptr].id, island_id)) {
                island = islands.items[island_ptr];
                break;
            }
        }

        if (island == null) {
            print("{s}❌ Island not found: {s}\n", .{RED}, island_id);
            return;
        }

        if (island.clues_count == 0) {
            print("{s}No clues available for this island.\n", .{YELLOW});
            return;
        }

        print("{s}📜 Clues for '{s}': {s}\\n", .{CYAN}, island.name);
        print("{s}Clue count: {d}\\n", .{MAGENTA}, island.clues_count);
        print();

        for (island.clues_count, 0..) |i| {
            print("  [{d}] {s}{s}", .{YELLOW}, i + 1);
            print("    {s}{s}\\n", .{RESET});
        }

        return;
    }

    // Submit answer to solve riddle
    if ((std.mem.eql(u8, action, "--solve") or std.mem.eql(u8, action, "-s")) and args.len > 2) {
        const island_id = args[2];
        const answer = args[3];

        var islands = try loadIslands(allocator, allocator);
        defer islands.deinit();

        var island: ?Island = null;
        for (islands.items, 0..) |island_ptr| {
            if (std.mem.eql(u8, islands.items[island_ptr].id, island_id)) {
                island = islands.items[island_ptr];
                break;
            }
        }

        if (island == null) {
            print("{s}❌ Island not found: {s}\n", .{RED}, island_id);
            return;
        }

        const is_correct = std.ascii.eqlIgnoreCase(answer, island.answer);

        if (is_correct) {
            // Mark as discovered if first time
            if (!island.discovered) {
                saveDiscovery(allocator, island.id, .{ .solved = true, .attempts = island.attempts + 1 });
            }

            print("{s}✅ Correct! {s}\\n", .{GREEN});
            print("{s}{s}You discovered: {s}\\n", .{CYAN}, island.name);
            print("{s}{s}Knowledge revealed:{s}\\n", .{RESET}, island.knowledge);
        } else {
            print("{s}❌ Incorrect. Try again!{s}\\n", .{RED});
            print("{s}{s}The answer is: {s}\\n", .{YELLOW}, island.answer);
            print("{s}{s}Your clue:{s}\\n", .{RESET});

            // Save the attempt
            saveDiscovery(allocator, island.id, .{ .attempts = island.attempts + 1, .solved = false });
        }

        return;
    }

    // Get hint
    if ((std.mem.eql(u8, action, "--hint") or std.mem.eql(u8, action, "-h")) and args.len > 1) {
        const island_id = args[1];
        const hint_level: if (args.len > 2) std.fmt.parseInt(u8, args[2], 10) else 1;

        if (hint_level < 1 or hint_level > 3) {
            print("{s}❌ Invalid hint level: {d}. Use 1 (subtle), 2 (clear), or 3 (strong).{s}\n", .{RED});
            return;
        }

        var islands = try loadIslands(allocator, allocator);
        defer islands.deinit();

        var island: ?Island = null;
        for (islands.items, 0..) |island_ptr| {
            if (std.mem.eql(u8, islands.items[island_ptr].id, island_id)) {
                island = islands.items[island_ptr];
                break;
            }
        }

        if (island == null) {
            print("{s}❌ Island not found: {s}\n", .{RED}, island_id);
            return;
        }

        if (island.clues_count == 0) {
            print("{s}No clues available for this island.\n", .{YELLOW});
            return;
        }

        const hint_names = [_]const u8{ "subtle hint", "clear hint", "strong hint" };
        const actual_hint = if (hint_level <= @as(island.clues_count, hint_names[hint_level - 1])) hint_names[hint_level - 1] else "no more hints";

        print("{s}💡 Hint for '{s}': {s}\\n", .{CYAN}, island.name);
        print("{s}{s}{s}\\n", .{RESET}, actual_hint);

        // Track hint usage
        saveDiscovery(allocator, island.id, .{ .hints_used = island.hints_used + 1 });
    }

    // Show discovered only
    if (std.mem.eql(u8, action, "--discovered") or std.mem.eql(u8, action, "-D")) {
        var islands = try loadIslands(allocator, allocator);
        defer islands.deinit();

        var discovered_count: usize = 0;
        for (islands.items) |island| {
            if (island.discovered) discovered_count += 1;
        }

        print("{s}📊 Discovered: {d}/{d} islands{s}\n", .{GREEN}, discovered_count, islands.items.len);
        return;
    }

    // Show undiscovered only
    if (std.mem.eql(u8, action, "--undiscovered") or std.mem.eql(u8, action, "-U")) {
        var islands = try loadIslands(allocator, allocator);
        defer islands.deinit();

        var undiscovered_count: usize = 0;
        for (islands.items) |island| {
            if (!island.discovered) undiscovered_count += 1;
        }

        print("{s}🗺️ Undiscovered: {d}/{d} islands{s}\n", .{YELLOW}, undiscovered_count, islands.items.len);
        return;
    }

    printUsage() void {
        print("{s}Usage: tri find island [options] <query>{s}\n", .{CYAN});
        print("{s}Options:{s}\n", .{RESET});
        print("  --list, -l       List all islands");
        print("  --domain <dom>  Filter by domain (sacred_formula, vsa, tri, blind_spots, agent_mu, quantum, etc.)");
        print("  --clues <id>     Show clues for an island");
        print("  --solve <id> <ans>  Submit answer to riddle");
        print("  --hint <id> [1-3]  Get a hint (1=subtle, 2=clear, 3=strong)");
        print("  --discovered       Show only discovered islands");
        print("  --undiscovered     Show only undiscovered islands");
        print();
        print("Examples:{s}\n", .{RESET});
        print("  tri find island --list");
        print("  tri find island phi");
        print("  tri find island --domain vsa");
        print("  tri find island --clues island_phi_wisdom");
        print("  tri find island --solve island_phi_wisdom \"phi^2 + 1/phi^2\"");
        print();
        print("{s}Predefined Islands:{s}\n", .{MAGENTA});
        inline for (PREDEFINED_ISLANDS) |predef| {
            print("  {s}{c}•{s} {s} {s}{c}•{s} {s}\\n", .{RESET}, predef.id, "--", predef.name);
        }
    }
}
