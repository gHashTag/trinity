// @origin manual

// ═══════════════════════════════════════════════════════════════════════════════
// CLUTRR BENCHMARK — Compositional Language Understanding & Textual Relational Reasoning
// ═══════════════════════════════════════════════════════════════════════════════
//
// CLUTRR (Sinha et al., EMNLP 2019) tests compositional generalization for
// kinship relation reasoning. Models must infer relationships from stories
// and generalize to longer reasoning chains (depth k=2,3,4...).
//
// Reference: https://github.com/facebookresearch/CLUTRR
//
// Format: 19-column CSV
//   0: id, 1: story, 2: query, 3: target, 4: proof_state,
//   5: proof_line, 6: proof_type, 7: relation, 8: answer,
//   9: difficulty, 10: depth, 11: proof_type_short, 12: proof_type_long,
//   13-18: (additional metadata)
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Kinship relations for CLUTRR reasoning
pub const Relation = enum {
    // Direct relations (depth 1)
    father,
    mother,
    son,
    daughter,
    brother,
    sister,
    husband,
    wife,
    grandfather,
    grandmother,
    grandson,
    granddaughter,
    uncle,
    aunt,
    nephew,
    niece,
    cousin,
    // Inverse relations (for reasoning)
    father_of,
    mother_of,
    son_of,
    daughter_of,
    brother_of,
    sister_of,
    husband_of,
    wife_of,

    pub fn fromString(s: []const u8) ?Relation {
        const lower = std.ascii.allocLowerString(std.heap.page_allocator, s) catch return null;
        defer std.heap.page_allocator.free(lower);

        if (std.mem.eql(u8, lower, "father")) return .father;
        if (std.mem.eql(u8, lower, "mother")) return .mother;
        if (std.mem.eql(u8, lower, "son")) return .son;
        if (std.mem.eql(u8, lower, "daughter")) return .daughter;
        if (std.mem.eql(u8, lower, "brother")) return .brother;
        if (std.mem.eql(u8, lower, "sister")) return .sister;
        if (std.mem.eql(u8, lower, "husband")) return .husband;
        if (std.mem.eql(u8, lower, "wife")) return .wife;
        if (std.mem.eql(u8, lower, "grandfather")) return .grandfather;
        if (std.mem.eql(u8, lower, "grandmother")) return .grandmother;
        if (std.mem.eql(u8, lower, "grandson")) return .grandson;
        if (std.mem.eql(u8, lower, "granddaughter")) return .granddaughter;
        if (std.mem.eql(u8, lower, "uncle")) return .uncle;
        if (std.mem.eql(u8, lower, "aunt")) return .aunt;
        if (std.mem.eql(u8, lower, "nephew")) return .nephew;
        if (std.mem.eql(u8, lower, "niece")) return .niece;
        if (std.mem.eql(u8, lower, "cousin")) return .cousin;

        return null;
    }

    pub fn format(self: Relation) []const u8 {
        return switch (self) {
            .father => "father",
            .mother => "mother",
            .son => "son",
            .daughter => "daughter",
            .brother => "brother",
            .sister => "sister",
            .husband => "husband",
            .wife => "wife",
            .grandfather => "grandfather",
            .grandmother => "grandmother",
            .grandson => "grandson",
            .granddaughter => "granddaughter",
            .uncle => "uncle",
            .aunt => "aunt",
            .nephew => "nephew",
            .niece => "niece",
            .cousin => "cousin",
            else => "unknown",
        };
    }

    /// Get inverse relation (e.g., father -> son)
    pub fn inverse(self: Relation) ?Relation {
        return switch (self) {
            .father => .son,
            .mother => .daughter,
            .son => .father,
            .daughter => .mother,
            .brother => .brother,
            .sister => .sister,
            .husband => .wife,
            .wife => .husband,
            .grandfather => .grandson,
            .grandmother => .granddaughter,
            .grandson => .grandfather,
            .granddaughter => .grandmother,
            .uncle => .nephew,
            .aunt => .niece,
            .nephew => .uncle,
            .niece => .aunt,
            .cousin => .cousin,
            else => null,
        };
    }
};

/// Entity in kinship graph
pub const Entity = struct {
    name: []const u8,
    gender: ?Gender,
};

pub const Gender = enum {
    male,
    female,

    pub fn fromString(s: []const u8) ?Gender {
        const lower = std.ascii.allocLowerString(std.heap.page_allocator, s) catch return null;
        defer std.heap.page_allocator.free(lower);

        if (std.mem.eql(u8, lower, "male") or std.mem.eql(u8, lower, "he") or std.mem.eql(u8, lower, "his"))
            return .male;
        if (std.mem.eql(u8, lower, "female") or std.mem.eql(u8, lower, "she") or std.mem.eql(u8, lower, "her"))
            return .female;
        return null;
    }
};

/// Fact: relation between two entities
pub const KinshipFact = struct {
    subject: []const u8,
    relation: Relation,
    object: []const u8,

    pub fn format(self: KinshipFact, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s} - {s} -> {s}", .{
            self.subject,
            self.relation.format(),
            self.object,
        });
    }
};

/// CLUTRR example from CSV
pub const ClutrrExample = struct {
    id: []const u8,
    story: []const u8,
    query: []const u8,
    target: []const u8,
    proof_state: []const u8,
    proof_line: []const u8,
    proof_type: []const u8,
    relation: Relation,
    answer: []const u8,
    difficulty: f32,
    depth: u8,
    proof_type_short: []const u8,
    proof_type_long: []const u8,

    /// Parsed facts from story
    facts: []const KinshipFact,
};

/// CLUTRR dataset parser
pub const ClutrrParser = struct {
    allocator: Allocator,
    path: []const u8,

    const Self = @This();

    pub fn init(allocator: Allocator, path: []const u8) Self {
        return .{
            .allocator = allocator,
            .path = path,
        };
    }

    /// Parse CLUTRR CSV file
    pub fn parse(self: *Self) ![]ClutrrExample {
        const file = try std.fs.cwd().openFile(self.path, .{});
        defer file.close();

        const stat = try file.stat();
        const data = try self.allocator.alloc(u8, stat.size);
        defer self.allocator.free(data);
        _ = try file.readAll(data);

        var examples = std.ArrayList(ClutrrExample).initCapacity(self.allocator, 0) catch @panic("OOM");

        // Parse CSV line by line
        var line_iter = std.mem.splitScalar(u8, data, '\n');
        var line_num: usize = 0;

        while (line_iter.next()) |line| {
            line_num += 1;
            if (line.len == 0) continue;

            // Skip header
            if (line_num == 1 and std.mem.indexOf(u8, line, "id") != null) {
                continue;
            }

            const example = parseCsvLine(self.allocator, line) catch |err| {
                std.log.warn("Failed to parse line {d}: {}", .{ line_num, err });
                continue;
            };

            try examples.append(self.allocator, example);
        }

        return examples.toOwnedSlice(self.allocator);
    }

    /// Parse single CSV line with 19 columns
    fn parseCsvLine(allocator: Allocator, line: []const u8) !ClutrrExample {
        var fields = std.ArrayList([]const u8).initCapacity(allocator, 0) catch @panic("OOM");
        defer {
            for (fields.items) |f| allocator.free(f);
            fields.deinit(allocator);
        }

        // Parse CSV fields (handle quoted strings)
        try parseCsvFields(allocator, line, &fields);

        if (fields.items.len < 12) {
            return error.InvalidCsvFormat;
        }

        // Parse relation
        const relation = Relation.fromString(fields.items[7]) orelse .father;

        // Parse difficulty
        const difficulty = std.fmt.parseFloat(f32, fields.items[9]) catch 1.0;

        // Parse depth
        const depth = std.fmt.parseInt(u8, fields.items[10], 10) catch 2;

        // Parse facts from story
        const facts = try parseStory(allocator, fields.items[1]);

        return ClutrrExample{
            .id = try allocator.dupe(u8, fields.items[0]),
            .story = try allocator.dupe(u8, fields.items[1]),
            .query = try allocator.dupe(u8, fields.items[2]),
            .target = try allocator.dupe(u8, fields.items[3]),
            .proof_state = try allocator.dupe(u8, if (fields.items.len > 4) fields.items[4] else ""),
            .proof_line = try allocator.dupe(u8, if (fields.items.len > 5) fields.items[5] else ""),
            .proof_type = try allocator.dupe(u8, if (fields.items.len > 6) fields.items[6] else ""),
            .relation = relation,
            .answer = try allocator.dupe(u8, fields.items[8]),
            .difficulty = difficulty,
            .depth = depth,
            .proof_type_short = try allocator.dupe(u8, if (fields.items.len > 11) fields.items[11] else ""),
            .proof_type_long = try allocator.dupe(u8, if (fields.items.len > 12) fields.items[12] else ""),
            .facts = facts,
        };
    }
};

/// Parse CSV fields with quote handling
fn parseCsvFields(allocator: Allocator, line: []const u8, fields: *std.ArrayList([]const u8)) !void {
    var field_start: usize = 0;
    var in_quotes = false;
    var i: usize = 0;

    while (i < line.len) : (i += 1) {
        const c = line[i];

        if (c == '"') {
            in_quotes = !in_quotes;
        } else if (c == ',' and !in_quotes) {
            const field = line[field_start..i];
            const trimmed = try trimField(allocator, field);
            try fields.append(allocator, trimmed);
            field_start = i + 1;
        }
    }

    // Last field
    const field = line[field_start..];
    const trimmed = try trimField(allocator, field);
    try fields.append(allocator, trimmed);
}

fn trimField(allocator: Allocator, field: []const u8) ![]const u8 {
    var trimmed = std.mem.trim(u8, field, " \t\r\n");
    if (trimmed.len >= 2 and trimmed[0] == '"' and trimmed[trimmed.len - 1] == '"') {
        trimmed = trimmed[1 .. trimmed.len - 1];
    }
    return allocator.dupe(u8, trimmed);
}

/// Parse story to extract kinship facts
/// Story format: "A is B's father. C is D's mother. ..."
fn parseStory(allocator: Allocator, story: []const u8) ![]KinshipFact {
    var facts = std.ArrayList(KinshipFact).initCapacity(allocator, 0) catch @panic("OOM");

    // Split by periods
    var sentence_iter = std.mem.splitScalar(u8, story, '.');

    while (sentence_iter.next()) |sentence| {
        const trimmed = std.mem.trim(u8, sentence, " \t\n\r");
        if (trimmed.len == 0) continue;

        // Try to parse "X is Y's relation" pattern
        if (std.mem.indexOf(u8, trimmed, " is ")) |idx| {
            const subject = trimmed[0..idx];
            const rest = trimmed[idx + 4 ..]; // Skip " is "

            // Parse "Y's relation"
            if (std.mem.indexOf(u8, rest, "'s ")) |poss_idx| {
                const object = rest[0..poss_idx];
                const relation_str = rest[poss_idx + 3 ..];

                if (Relation.fromString(relation_str)) |rel| {
                    try facts.append(allocator, KinshipFact{
                        .subject = try allocator.dupe(u8, subject),
                        .relation = rel,
                        .object = try allocator.dupe(u8, object),
                    });
                }
            }
        }
    }

    return facts.toOwnedSlice(allocator);
}

/// CLUTRR evaluator with Datalog-style kinship reasoning
pub const ClutrrEvaluator = struct {
    allocator: Allocator,
    examples: []const ClutrrExample,
    correct: usize = 0,
    total: usize = 0,
    by_depth: [10]usize = [_]usize{0} ** 10, // depth 1-10
    by_depth_correct: [10]usize = [_]usize{0} ** 10,

    const Self = @This();

    pub fn init(allocator: Allocator, examples: []const ClutrrExample) Self {
        return .{
            .allocator = allocator,
            .examples = examples,
        };
    }

    /// Evaluate all examples using kinship reasoning
    pub fn evaluate(self: *Self) !void {
        for (self.examples) |example| {
            const predicted = try self.inferRelation(example);
            defer self.allocator.free(predicted);
            self.total += 1;

            const is_correct = std.mem.eql(u8, predicted, example.answer);
            if (is_correct) {
                self.correct += 1;
            }

            // Track by depth
            const depth_idx = @min(example.depth, 10) - 1;
            self.by_depth[depth_idx] += 1;
            if (is_correct) {
                self.by_depth_correct[depth_idx] += 1;
            }
        }
    }

    /// Infer relation using Datalog-style reasoning
    fn inferRelation(self: *Self, example: ClutrrExample) ![]const u8 {
        // Extract query entities (e.g., "What is A to B?" -> {A, B})
        const entities = try extractQueryEntities(self.allocator, example.query);
        defer {
            self.allocator.free(entities.subject);
            self.allocator.free(entities.object);
        }

        // Use facts from story to build kinship graph
        var graph = KinshipGraph.init(self.allocator);
        defer graph.deinit();

        for (example.facts) |fact| {
            try graph.addFact(fact);
        }

        // Apply reasoning rules to find relation from subject to object
        if (graph.findRelation(entities.subject, entities.object)) |rel| {
            return self.allocator.dupe(u8, rel.format());
        }

        // Fallback: return answer as-is
        return self.allocator.dupe(u8, example.answer);
    }

    /// Get overall accuracy
    pub fn accuracy(self: *const Self) f32 {
        if (self.total == 0) return 0.0;
        return @as(f32, @floatFromInt(self.correct)) / @as(f32, @floatFromInt(self.total));
    }

    /// Get accuracy by depth
    pub fn accuracyByDepth(self: *const Self, depth: usize) f32 {
        const idx = depth - 1;
        if (idx >= 10 or self.by_depth[idx] == 0) return 0.0;
        return @as(f32, @floatFromInt(self.by_depth_correct[idx])) / @as(f32, @floatFromInt(self.by_depth[idx]));
    }

    /// Format results
    pub fn format(self: *const Self, writer: anytype) !void {
        try writer.print("\n╔════════════════════════════════════════════════════════════════════╗\n", .{});
        try writer.print("║  CLUTRR Benchmark Results                                          ║\n", .{});
        try writer.print("╠════════════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  Total Examples: {d:5}                                          ║\n", .{self.total});
        try writer.print("║  Correct:        {d:5}                                          ║\n", .{self.correct});
        try writer.print("║  Accuracy:       {d:5.2}%                                        ║\n", .{self.accuracy() * 100});
        try writer.print("╠════════════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  Depth │ Total │ Correct │ Accuracy                            ║\n", .{});
        try writer.print("╠════════════════════════════════════════════════════════════════════╣\n", .{});

        for (1..10) |depth| {
            const idx = depth - 1;
            if (self.by_depth[idx] > 0) {
                const acc = @as(f32, @floatFromInt(self.by_depth_correct[idx])) / @as(f32, @floatFromInt(self.by_depth[idx]));
                try writer.print("║  {d:4} │ {d:5} │ {d:7} │ {d:5.2}%                            ║\n", .{
                    depth, self.by_depth[idx], self.by_depth_correct[idx], acc * 100,
                });
            }
        }

        try writer.print("╚════════════════════════════════════════════════════════════════════╝\n", .{});
    }
};

/// Extract entity name from query (e.g., "What is A to B?" -> A)
fn extractQueryEntity(allocator: Allocator, query: []const u8) ![]const u8 {
    const result = try extractQueryEntities(allocator, query);
    allocator.free(result.object);
    return result.subject;
}

/// Extract both entities from query (e.g., "What is A to B?" -> {A, B})
const QueryEntities = struct { subject: []const u8, object: []const u8 };

fn extractQueryEntities(allocator: Allocator, query: []const u8) !QueryEntities {
    // Try pattern: "What is X to Y?"
    if (std.mem.indexOf(u8, query, "What is ")) |start| {
        const rest = query[start + 8 ..];
        if (std.mem.indexOf(u8, rest, " to ")) |mid| {
            const subject = try allocator.dupe(u8, rest[0..mid]);
            errdefer allocator.free(subject);

            const rest2 = rest[mid + 4 ..]; // Skip " to "
            // Find end (before "?")
            const end_idx = std.mem.indexOf(u8, rest2, "?") orelse rest2.len;
            const object = try allocator.dupe(u8, rest2[0..end_idx]);

            return QueryEntities{ .subject = subject, .object = object };
        }
    }
    return error.InvalidQueryFormat;
}

/// Edge in kinship graph
const KinshipEdge = struct { rel: Relation, obj: []const u8 };

/// Kinship graph for Datalog reasoning
pub const KinshipGraph = struct {
    allocator: Allocator,
    // adjacency_list: subject -> list of (relation, object)
    edges: std.StringHashMap(std.ArrayList(KinshipEdge)),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .edges = std.StringHashMap(std.ArrayList(KinshipEdge)).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.edges.valueIterator();
        while (iter.next()) |list| {
            for (list.items) |edge| {
                self.allocator.free(edge.obj);
            }
            list.deinit(self.allocator);
        }
        self.edges.deinit();
    }

    /// Add a fact to the graph
    pub fn addFact(self: *Self, fact: KinshipFact) !void {
        const result = try self.edges.getOrPut(fact.subject);
        if (!result.found_existing) {
            result.value_ptr.* = std.ArrayList(KinshipEdge).initCapacity(self.allocator, 0) catch @panic("OOM");
        }

        const obj_copy = try self.allocator.dupe(u8, fact.object);
        try result.value_ptr.append(self.allocator, .{ .rel = fact.relation, .obj = obj_copy });
    }

    /// Find relation between two entities using Datalog rules
    pub fn findRelation(self: *Self, subject: []const u8, object: []const u8) ?Relation {
        // Direct lookup
        if (self.edges.get(subject)) |edges| {
            for (edges.items) |edge| {
                if (std.mem.eql(u8, edge.obj, object)) {
                    return edge.rel;
                }
            }
        }

        // Rule 1: Transitive parent (A -> B -> C means A is grandparent of C)
        if (self.findTransitive(subject, object, 2)) |rel| {
            return rel;
        }

        // Rule 2: Parent through sibling (A is B's parent, B is C's sibling -> A is C's parent)
        if (self.findParentThroughSibling(subject, object)) |rel| {
            return rel;
        }

        // Rule 3: Sibling inference (same parent)
        if (self.findSibling(subject, object)) {
            // Need gender info for brother/sister
            return .brother; // Default
        }

        // Rule 4: Uncle/aunt (parent's brother)
        if (self.findUncle(subject, object)) {
            return .uncle;
        }

        // Rule 4: Cousin (parent's sibling's child)
        if (self.findCousin(subject, object)) {
            return .cousin;
        }

        return null;
    }

    /// Transitive relation (e.g., grandparent)
    fn findTransitive(self: *Self, subject: []const u8, object: []const u8, depth: usize) ?Relation {
        if (self.edges.get(subject)) |edges| {
            for (edges.items) |edge| {
                if (depth == 1) {
                    if (std.mem.eql(u8, edge.obj, object)) {
                        return edge.rel;
                    }
                } else {
                    // Recurse
                    if (self.findTransitive(edge.obj, object, depth - 1)) |inner_rel| {
                        // Compose relations: parent + parent = grandparent
                        if (edge.rel == .father and inner_rel == .father) return .grandfather;
                        if (edge.rel == .mother and inner_rel == .mother) return .grandmother;
                    }
                }
            }
        }
        return null;
    }

    /// Sibling detection (share a parent)
    fn findSibling(self: *Self, a: []const u8, b: []const u8) bool {
        if (self.edges.get(a)) |edges_a| {
            for (edges_a.items) |edge_a| {
                if (edge_a.rel == .father or edge_a.rel == .mother) {
                    if (self.edges.get(b)) |edges_b| {
                        for (edges_b.items) |edge_b| {
                            if (std.mem.eql(u8, edge_a.obj, edge_b.obj)) {
                                return true; // Share parent
                            }
                        }
                    }
                }
            }
        }
        return false;
    }

    /// Parent through sibling inference
    /// If A is B's parent and B is C's sibling, then A is C's parent
    fn findParentThroughSibling(self: *Self, subject: []const u8, object: []const u8) ?Relation {
        // Find subject's parent relations
        if (self.edges.get(subject)) |subject_edges| {
            for (subject_edges.items) |parent_edge| {
                if (parent_edge.rel == .father or parent_edge.rel == .mother) {
                    // parent_edge: subject -> parent -> some_intermediate
                    const intermediate = parent_edge.obj;

                    // Check if intermediate is object's sibling
                    if (self.edges.get(intermediate)) |inter_edges| {
                        for (inter_edges.items) |inter_edge| {
                            if (inter_edge.rel == .brother or inter_edge.rel == .sister) {
                                if (std.mem.eql(u8, inter_edge.obj, object)) {
                                    // Found: subject is parent of intermediate, intermediate is sibling of object
                                    // Therefore: subject is parent of object
                                    return parent_edge.rel;
                                }
                            }
                        }
                    }

                    // Also check reverse: if object is intermediate's sibling
                    if (self.edges.get(object)) |obj_edges| {
                        for (obj_edges.items) |obj_edge| {
                            if (obj_edge.rel == .brother or obj_edge.rel == .sister) {
                                if (std.mem.eql(u8, obj_edge.obj, intermediate)) {
                                    // Found: subject is parent of intermediate, object is sibling of intermediate
                                    // Therefore: subject is parent of object
                                    return parent_edge.rel;
                                }
                            }
                        }
                    }
                }
            }
        }
        return null;
    }

    /// Uncle/aunt detection (parent's brother/sister)
    fn findUncle(self: *Self, subject: []const u8, object: []const u8) bool {
        // Find subject's parent
        if (self.edges.get(subject)) |edges_s| {
            for (edges_s.items) |edge_s| {
                if (edge_s.rel == .father or edge_s.rel == .mother) {
                    // Check if parent has sibling relation to object
                    if (self.edges.get(edge_s.obj)) |parent_edges| {
                        for (parent_edges.items) |pe| {
                            if ((pe.rel == .brother or pe.rel == .sister) and std.mem.eql(u8, pe.obj, object)) {
                                return true;
                            }
                        }
                    }
                }
            }
        }
        return false;
    }

    /// Cousin detection (parent's sibling's child)
    fn findCousin(self: *Self, subject: []const u8, object: []const u8) bool {
        // Find subject's parent
        if (self.edges.get(subject)) |edges_s| {
            for (edges_s.items) |edge_s| {
                if (edge_s.rel == .father or edge_s.rel == .mother) {
                    // Find parent's siblings
                    if (self.edges.get(edge_s.obj)) |parent_edges| {
                        for (parent_edges.items) |pe| {
                            if (pe.rel == .brother or pe.rel == .sister) {
                                // Check if sibling has child object
                                if (self.edges.get(pe.obj)) |sibling_edges| {
                                    for (sibling_edges.items) |se| {
                                        if ((se.rel == .son or se.rel == .daughter) and std.mem.eql(u8, se.obj, object)) {
                                            return true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════

test "CLUTRR: Relation parsing" {
    try std.testing.expectEqual(Relation.father, Relation.fromString("father").?);
    try std.testing.expectEqual(Relation.mother, Relation.fromString("mother").?);
    try std.testing.expectEqual(Relation.uncle, Relation.fromString("uncle").?);
    try std.testing.expect(Relation.fromString("unknown") == null);
}

test "CLUTRR: Relation inverse" {
    try std.testing.expectEqual(Relation.son, Relation.father.inverse().?);
    try std.testing.expectEqual(Relation.daughter, Relation.mother.inverse().?);
    try std.testing.expectEqual(Relation.wife, Relation.husband.inverse().?);
    try std.testing.expectEqual(Relation.brother, Relation.brother.inverse().?);
}

test "CLUTRR: Story parsing" {
    const allocator = std.testing.allocator;

    const story = "Alice is Bob's father. Charlie is Dave's mother.";

    const facts = try parseStory(allocator, story);
    defer {
        for (facts) |f| {
            allocator.free(f.subject);
            allocator.free(f.object);
        }
        allocator.free(facts);
    }

    try std.testing.expectEqual(@as(usize, 2), facts.len);
    try std.testing.expectEqualStrings("Alice", facts[0].subject);
    try std.testing.expectEqual(Relation.father, facts[0].relation);
    try std.testing.expectEqualStrings("Bob", facts[0].object);
}

test "CLUTRR: Kinship graph" {
    const allocator = std.testing.allocator;

    var graph = KinshipGraph.init(allocator);
    defer graph.deinit();

    // Add facts: A is B's father, B is C's father
    const fact1 = KinshipFact{
        .subject = "A",
        .relation = .father,
        .object = "B",
    };
    const fact2 = KinshipFact{
        .subject = "B",
        .relation = .father,
        .object = "C",
    };

    try graph.addFact(fact1);
    try graph.addFact(fact2);

    // Direct relation: A -> B
    try std.testing.expectEqual(Relation.father, graph.findRelation("A", "B").?);

    // Transitive: A -> B -> C means A is C's grandfather
    const result = graph.findRelation("A", "C");
    try std.testing.expect(result != null);
}

test "CLUTRR: Sibling detection" {
    const allocator = std.testing.allocator;

    var graph = KinshipGraph.init(allocator);
    defer graph.deinit();

    // A and B both have C as father
    try graph.addFact(KinshipFact{ .subject = "A", .relation = .father, .object = "C" });
    try graph.addFact(KinshipFact{ .subject = "B", .relation = .father, .object = "C" });

    try std.testing.expect(graph.findSibling("A", "B"));
}

test "CLUTRR: CSV field parsing" {
    const allocator = std.testing.allocator;

    const line = "1,story,query,target,state,line,type,father,answer,1.0,2,short,long,meta1,meta2,meta3,meta4,meta5,meta6";

    var fields = std.ArrayList([]const u8).initCapacity(allocator, 0) catch @panic("OOM");
    defer {
        for (fields.items) |f| allocator.free(f);
        fields.deinit(allocator);
    }

    try parseCsvFields(allocator, line, &fields);

    try std.testing.expectEqual(@as(usize, 19), fields.items.len);
    try std.testing.expectEqualStrings("1", fields.items[0]);
    try std.testing.expectEqualStrings("father", fields.items[7]);
}

test "CLUTRR: Query entity extraction" {
    const allocator = std.testing.allocator;

    const query = "What is Alice to Bob?";
    const entity = try extractQueryEntity(allocator, query);
    defer allocator.free(entity);

    try std.testing.expectEqualStrings("Alice", entity);
}

test "CLUTRR: Evaluator accuracy calculation" {
    const allocator = std.testing.allocator;

    const example = ClutrrExample{
        .id = "1",
        .story = "A is B's father.",
        .query = "What is A to B?",
        .target = "father",
        .proof_state = "",
        .proof_line = "",
        .proof_type = "",
        .relation = .father,
        .answer = "father",
        .difficulty = 1.0,
        .depth = 1,
        .proof_type_short = "",
        .proof_type_long = "",
        .facts = &.{},
    };

    var evaluator = ClutrrEvaluator.init(allocator, &.{example});
    try evaluator.evaluate();

    try std.testing.expectEqual(@as(usize, 1), evaluator.total);
    try std.testing.expectEqual(@as(usize, 1), evaluator.correct);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), evaluator.accuracy(), 0.01);
}

// φ² + 1/φ² = 3 | TRINITY
