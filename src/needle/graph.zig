// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 2 — Graph Multi-File Refactoring
// ═══════════════════════════════════════════════════════════════════════════════
//
// Call graph construction + safe multi-file edits with dependency tracking
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Symbol kind in Zig source
pub const SymbolKind = enum {
    function,
    struct_type,
    enum_type,
    constant,
    variable,
    type_def,
    pub_function,
    pub_struct_type,
    pub_enum_type,
    pub_constant,

    pub fn isExported(self: SymbolKind) bool {
        return switch (self) {
            .pub_function, .pub_struct_type, .pub_enum_type, .pub_constant => true,
            else => false,
        };
    }

    pub fn baseKind(self: SymbolKind) SymbolKind {
        return switch (self) {
            .pub_function => .function,
            .pub_struct_type => .struct_type,
            .pub_enum_type => .enum_type,
            .pub_constant => .constant,
            else => self,
        };
    }
};

/// Symbol definition
pub const Symbol = struct {
    name: []const u8,
    kind: SymbolKind,
    file: []const u8,
    line: u32,
    column: u32,
    signature: []const u8,

    pub fn format(self: Symbol, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}:{d}:{d} {s} {s}", .{
            self.file,
            self.line,
            self.column,
            @tagName(self.kind),
            self.name,
        });
    }
};

/// Edge type in call graph
pub const EdgeType = enum {
    calls, // Function calls another function
    imports, // File imports another file
    defines, // Symbol defines another symbol (e.g., struct field)
    inherits, // Type inherits from another
};

/// Dependency edge
pub const Edge = struct {
    from: []const u8, // Symbol or file name
    to: []const u8,
    edge_type: EdgeType,
    line: u32,

    pub fn init(from: []const u8, to: []const u8, edge_type: EdgeType, line: u32) Edge {
        return .{
            .from = from,
            .to = to,
            .edge_type = edge_type,
            .line = line,
        };
    }
};

/// Graph node representing a file
pub const GraphNode = struct {
    file: []const u8,
    file_hash: []const u8,
    symbols: std.StringArrayHashMap(Symbol),
    imports: std.StringArrayHashMap(void), // Direct imports
    imported_by: std.StringArrayHashMap(void), // Files that import this file
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, file: []const u8) GraphNode {
        return .{
            .file = file,
            .file_hash = "",
            .symbols = std.StringArrayHashMap(Symbol).init(allocator),
            .imports = std.StringArrayHashMap(void).init(allocator),
            .imported_by = std.StringArrayHashMap(void).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *GraphNode) void {
        self.symbols.deinit();
        self.imports.deinit();
        self.imported_by.deinit();
    }

    pub fn addSymbol(self: *GraphNode, symbol: Symbol) !void {
        try self.symbols.put(symbol.name, symbol);
    }

    pub fn addImport(self: *GraphNode, imported_file: []const u8) !void {
        try self.imports.put(imported_file, {});
    }

    pub fn addImportedBy(self: *GraphNode, importer: []const u8) !void {
        try self.imported_by.put(importer, {});
    }

    pub fn getDependencies(self: *GraphNode, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
        var deps = std.ArrayList([]const u8).init(allocator);
        var iter = self.imports.iterator();
        while (iter.next()) |entry| {
            try deps.append(entry.key_ptr.*);
        }
        return deps;
    }

    pub fn getDependents(self: *GraphNode, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
        var dependents = std.ArrayList([]const u8).init(allocator);
        var iter = self.imported_by.iterator();
        while (iter.next()) |entry| {
            try dependents.append(entry.key_ptr.*);
        }
        return dependents;
    }
};

/// Complete call graph
pub const CallGraph = struct {
    nodes: std.StringArrayHashMap(GraphNode),
    symbol_table: std.StringArrayHashMap(Symbol),
    call_edges: std.ArrayList(Edge),
    import_edges: std.ArrayList(Edge),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CallGraph {
        return .{
            .nodes = std.StringArrayHashMap(GraphNode).init(allocator),
            .symbol_table = std.StringArrayHashMap(Symbol).init(allocator),
            .call_edges = std.ArrayList(Edge).init(allocator),
            .import_edges = std.ArrayList(Edge).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CallGraph) void {
        var node_iter = self.nodes.valueIterator();
        while (node_iter.next()) |node| {
            node.deinit();
        }
        self.nodes.deinit();
        self.symbol_table.deinit();
        self.call_edges.deinit();
        self.import_edges.deinit();
    }

    /// Get or create node for file
    pub fn getOrCreateNode(self: *CallGraph, file: []const u8) !*GraphNode {
        const gop = try self.nodes.getOrPut(file);
        if (!gop.found_existing) {
            gop.value_ptr.* = GraphNode.init(self.allocator, file);
        }
        return gop.value_ptr;
    }

    /// Add symbol to graph
    pub fn addSymbol(self: *CallGraph, symbol: Symbol) !void {
        // Add to symbol table
        try self.symbol_table.put(symbol.name, symbol);

        // Add to file node
        const node = try self.getOrCreateNode(symbol.file);
        try node.addSymbol(symbol);
    }

    /// Add import edge
    pub fn addImport(self: *CallGraph, from_file: []const u8, to_file: []const u8) !void {
        // Add to from_node's imports
        const from_node = try self.getOrCreateNode(from_file);
        try from_node.addImport(to_file);

        // Add to to_node's imported_by
        const to_node = try self.getOrCreateNode(to_file);
        try to_node.addImportedBy(from_file);

        // Add edge list
        try self.import_edges.append(Edge.init(from_file, to_file, .imports, 0));
    }

    /// Add call edge
    pub fn addCall(self: *CallGraph, from_symbol: []const u8, to_symbol: []const u8, line: u32) !void {
        try self.call_edges.append(Edge.init(from_symbol, to_symbol, .calls, line));
    }

    /// Find all usages of a symbol
    pub fn findUsages(self: *CallGraph, symbol_name: []const u8, allocator: std.mem.Allocator) !UsageList {
        var usages = UsageList.init(allocator);
        errdefer usages.deinit();

        // Check all call edges
        for (self.call_edges.items) |edge| {
            if (std.mem.eql(u8, edge.to, symbol_name)) {
                // Find the file containing this call site
                if (self.symbol_table.get(edge.from)) |symbol| {
                    try usages.append(.{
                        .file = symbol.file,
                        .line = symbol.line,
                        .column = symbol.column,
                        .symbol = edge.from,
                        .usage_type = .call,
                    });
                }
            }
        }

        // Check symbol table for definition
        if (self.symbol_table.get(symbol_name)) |symbol| {
            try usages.append(.{
                .file = symbol.file,
                .line = symbol.line,
                .column = symbol.column,
                .symbol = symbol_name,
                .usage_type = .definition,
            });
        }

        return usages;
    }

    /// Get files affected by symbol change
    pub fn getAffectedFiles(self: *CallGraph, symbol_name: []const u8, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
        var files = std.ArrayList([]const u8).init(allocator);

        // Get definition file
        if (self.symbol_table.get(symbol_name)) |symbol| {
            try files.append(symbol.file);
        }

        // Get all files that use this symbol
        for (self.call_edges.items) |edge| {
            if (std.mem.eql(u8, edge.to, symbol_name)) {
                if (self.symbol_table.get(edge.from)) |symbol| {
                    // Avoid duplicates
                    const already_exists = for (files.items) |f| {
                        if (std.mem.eql(u8, f, symbol.file)) break true;
                    } else false;

                    if (!already_exists) {
                        try files.append(symbol.file);
                    }
                }
            }
        }

        return files;
    }
};

/// Usage location
pub const UsageLocation = struct {
    file: []const u8,
    line: u32,
    column: u32,
    symbol: []const u8,
    usage_type: UsageType,
};

pub const UsageType = enum {
    definition,
    call,
    import,
    reference,
};

pub const UsageList = struct {
    items: std.ArrayList(UsageLocation),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) UsageList {
        return .{
            .items = std.ArrayList(UsageLocation).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *UsageList) void {
        self.items.deinit();
    }

    pub fn append(self: *UsageList, item: UsageLocation) !void {
        try self.items.append(item);
    }

    pub fn len(self: *UsageList) usize {
        return self.items.items.len;
    }

    pub fn isEmpty(self: *UsageList) bool {
        return self.items.items.len == 0;
    }
};

/// Multi-file edit plan
pub const EditPlan = struct {
    target_symbol: []const u8,
    files_to_edit: std.ArrayList([]const u8),
    edit_order: std.ArrayList([]const u8), // Topological order
    rollback_points: std.StringHashMap([]const u8), // file -> backup
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, target_symbol: []const u8) EditPlan {
        return .{
            .target_symbol = target_symbol,
            .files_to_edit = std.ArrayList([]const u8).init(allocator),
            .edit_order = std.ArrayList([]const u8).init(allocator),
            .rollback_points = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EditPlan) void {
        self.files_to_edit.deinit();
        self.edit_order.deinit();

        var iter = self.rollback_points.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.rollback_points.deinit();
    }

    pub fn addFile(self: *EditPlan, file: []const u8) !void {
        try self.files_to_edit.append(file);
    }

    pub fn setEditOrder(self: *EditPlan, files: []const []const u8) !void {
        self.edit_order.clearRetainingCapacity();
        for (files) |file| {
            try self.edit_order.append(file);
        }
    }
};

/// Multi-file edit result
pub const MultiFileEditResult = struct {
    success: bool,
    files_modified: usize,
    total_changes: usize,
    errors: std.ArrayList([]const u8),
    preview: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MultiFileEditResult {
        return .{
            .success = true,
            .files_modified = 0,
            .total_changes = 0,
            .errors = std.ArrayList([]const u8).init(allocator),
            .preview = "",
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MultiFileEditResult) void {
        self.errors.deinit();
        if (self.preview.len > 0) {
            self.allocator.free(self.preview);
        }
    }

    pub fn addError(self: *MultiFileEditResult, msg: []const u8) !void {
        try self.errors.append(msg);
        self.success = false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ALGORITHMS
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute topological order for safe multi-file edits
/// Files with no dependents are edited first
pub fn computeEditOrder(graph: *CallGraph, files: []const []const u8, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    // Build dependency map for affected files
    var dep_map = std.StringHashMap(std.ArrayList([]const u8)).init(allocator);
    defer {
        var dep_iter = dep_map.iterator();
        while (dep_iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        dep_map.deinit();
    }

    // Collect dependencies for each file
    for (files) |file| {
        var deps = std.ArrayList([]const u8).init(allocator);
        if (graph.nodes.get(file)) |node| {
            var import_iter = node.imports.iterator();
            while (import_iter.next()) |entry| {
                // Only include dependencies that are also in our edit set
                for (files) |f| {
                    if (std.mem.eql(u8, f, entry.key_ptr.*)) {
                        try deps.append(entry.key_ptr.*);
                        break;
                    }
                }
            }
        }
        try dep_map.put(file, deps);
    }

    // Kahn's algorithm
    var result = std.ArrayList([]const u8).init(allocator);
    var in_degree = std.StringHashMap(usize).init(allocator);
    defer in_degree.deinit();

    // Compute in-degrees
    for (files) |file| {
        var degree: usize = 0;
        if (dep_map.get(file)) |deps| {
            degree = deps.items.len;
        }
        try in_degree.put(file, degree);
    }

    // Start with zero in-degree files
    var queue = std.ArrayList([]const u8).init(allocator);
    for (files) |file| {
        const degree = in_degree.get(file) orelse 0;
        if (degree == 0) {
            try queue.append(file);
        }
    }

    // Process queue
    while (queue.items.len > 0) {
        const current = queue.orderedRemove(0);
        try result.append(current);

        // Find files that depend on current
        for (files) |file| {
            if (dep_map.get(file)) |deps| {
                for (deps.items) |dep| {
                    if (std.mem.eql(u8, dep, current)) {
                        // Decrement in-degree
                        const degree_ptr = in_degree.getPtr(file) orelse continue;
                        degree_ptr.* -= 1;
                        if (degree_ptr.* == 0) {
                            try queue.append(file);
                        }
                        break;
                    }
                }
            }
        }
    }

    // Check for cycles
    if (result.items.len != files.len) {
        // Cycle detected - return original order as fallback
        result.clearRetainingCapacity();
        for (files) |file| {
            try result.append(file);
        }
    }

    return result;
}

/// Detect cycles in dependency graph
pub fn detectCycles(graph: *CallGraph, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var cycle = std.ArrayList([]const u8).init(allocator);

    // Three-color DFS for cycle detection
    const Color = enum { white, gray, black };
    var colors = std.StringHashMap(Color).init(allocator);
    defer colors.deinit();

    var node_iter = graph.nodes.iterator();
    while (node_iter.next()) |entry| {
        try colors.put(entry.key_ptr.*, .white);
    }

    // DFS function (recursive simulation)
    for (graph.nodes.keys()) |file| {
        if (colors.get(file) orelse .white == .white) {
            if (dfsDetectCycle(graph, file, &colors, &cycle)) {
                return cycle;
            }
        }
    }

    cycle.deinit();
    return std.ArrayList([]const u8).init(allocator);
}

fn dfsDetectCycle(
    graph: *CallGraph,
    file: []const u8,
    colors: *std.StringHashMap(enum { white, gray, black }),
    path: *std.ArrayList([]const u8),
) bool {
    const color = colors.get(file) orelse return false;

    if (color == .gray) {
        // Back edge found - cycle!
        try path.append(file);
        return true;
    }

    if (color == .black) {
        return false; // Already processed
    }

    // Mark as visiting
    try colors.put(file, .gray);

    // Check all dependencies
    if (graph.nodes.get(file)) |node| {
        var import_iter = node.imports.iterator();
        while (import_iter.next()) |entry| {
            if (dfsDetectCycle(graph, entry.key_ptr.*, colors, path)) {
                try path.append(file);
                return true;
            }
        }
    }

    // Mark as visited
    try colors.put(file, .black);
    return false;
}

/// Compute transitive closure - all files affected by a symbol
pub fn computeImpactZone(graph: *CallGraph, symbol: []const u8, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var visited = std.StringHashMap(void).init(allocator);
    defer visited.deinit();
    var result = std.ArrayList([]const u8).init(allocator);

    // Start with direct usages
    var affected_files = try graph.getAffectedFiles(symbol, allocator);
    defer {
        for (affected_files.items) |f| {
            allocator.free(f);
        }
        affected_files.deinit();
    }

    // BFS to find all transitive dependencies
    for (affected_files.items) |file| {
        if (!visited.contains(file)) {
            try visited.put(file, {});
            try result.append(try allocator.dupe(u8, file));

            // Find all files that import this file
            if (graph.nodes.get(file)) |node| {
                var dep_iter = node.imported_by.iterator();
                while (dep_iter.next()) |entry| {
                    if (!visited.contains(entry.key_ptr.*)) {
                        try visited.put(entry.key_ptr.*, {});
                        try result.append(try allocator.dupe(u8, entry.key_ptr.*));
                    }
                }
            }
        }
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREVIEW
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate preview of multi-file refactor
pub fn previewMultiFileEdit(
    graph: *CallGraph,
    symbol: []const u8,
    new_name: []const u8,
    allocator: std.mem.Allocator,
) !MultiFileEditResult {
    var result = MultiFileEditResult.init(allocator);
    errdefer result.deinit();

    // Find all usages
    var usages = try graph.findUsages(symbol, allocator);
    defer usages.deinit();

    // Group by file
    var file_usages = std.StringHashMap(usize).init(allocator);
    defer {
        var iter = file_usages.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        file_usages.deinit();
    }

    for (usages.items.items) |usage| {
        const count = file_usages.get(usage.file) orelse 0;
        try file_usages.put(try allocator.dupe(u8, usage.file), count + 1);
    }

    // Generate preview text
    var preview_list = std.ArrayList([]const u8).init(allocator);
    defer {
        for (preview_list.items) |p| {
            allocator.free(p);
        }
        preview_list.deinit();
    }

    try preview_list.append(try allocator.dupe(u8, "Multi-file Refactor Preview"));
    try preview_list.append(try allocator.dupe(u8, "=========================="));
    try preview_list.append(try std.fmt.allocPrint(allocator, "Symbol: '{s}' -> '{s}'", .{ symbol, new_name }));
    try preview_list.append(try std.fmt.allocPrint(allocator, "Files affected: {d}", .{file_usages.count()}));
    try preview_list.append(try allocator.dupe(u8, ""));

    var file_iter = file_usages.iterator();
    while (file_iter.next()) |entry| {
        try preview_list.append(try std.fmt.allocPrint(allocator, "  {s}: {d} usage(s)", .{
            entry.key_ptr.*,
            entry.value_ptr.*,
        }));
    }

    // Combine preview
    var combined = std.ArrayList(u8).init(allocator);
    for (preview_list.items) |line| {
        try combined.appendSlice(line);
        try combined.append('\n');
    }
    result.preview = try combined.toOwnedSlice();

    result.total_changes = usages.len();
    result.files_modified = @intCast(file_usages.count());

    return result;
}
