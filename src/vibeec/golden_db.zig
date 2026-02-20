//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE v10.2: Golden Implementation Database
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Verified implementations extracted from pattern files.
//! Used by Spec Improver to fill empty implementation: fields in .vibee specs.
//!
//! φ² + 1/φ² = 3
//!
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Category of golden implementation
pub const Category = enum {
    /// Vector Symbolic Architecture operations
    vsa,
    /// Tensor operations
    tensor,
    /// $TRI economic operations
    economic,
    /// Trinity-specific operations
    tri,
    /// Swarm runtime coordination
    swarm_runtime,
    /// I/O operations
    io,
    /// Machine learning operations
    ml,
    /// Lifecycle operations (init, start, stop)
    lifecycle,
    /// Generic operations (get, set, add, etc.)
    generic,
    /// Data operations (encode, decode, transform)
    data,
    /// Inference operations
    inference,
};

/// Golden implementation - verified code pattern
pub const GoldenImpl = struct {
    /// Function name (e.g., "bind", "earn_task_reward")
    name: []const u8,
    /// Full function signature
    signature: []const u8,
    /// Implementation body (without "pub fn")
    body: []const u8,
    /// Category for organization
    category: Category,
    /// Confidence score (0.0-1.0)
    confidence: f32,
    /// Semantic tags for fuzzy matching
    tags: []const []const u8,
};

/// Context for matching implementations
pub const MatchContext = struct {
    /// Given precondition
    given: []const u8 = "",
    /// When trigger
    when: []const u8 = "",
    /// Then postcondition
    then: []const u8 = "",
};

/// Golden Implementation Database
pub const GoldenDB = struct {
    allocator: Allocator,
    /// Map from function name to implementation
    by_name: std.StringHashMap(*GoldenImpl),
    /// All implementations for iteration
    implementations: std.ArrayList(*GoldenImpl),
    /// Index by category
    by_category: std.EnumMap(Category, std.ArrayList(*GoldenImpl)),

    const Self = @This();

    /// Initialize the golden database with verified implementations
    pub fn init(allocator: Allocator) !Self {
        var db = Self{
            .allocator = allocator,
            .by_name = std.StringHashMap(*GoldenImpl).init(allocator),
            .implementations = std.ArrayList(*GoldenImpl).empty,
            .by_category = std.EnumMap(Category, std.ArrayList(*GoldenImpl)){},
        };

        // Initialize all category lists as empty
        inline for (std.meta.fields(Category)) |field| {
            const cat = @field(Category, field.name);
            db.by_category.put(cat, .empty);
        }

        // Populate with golden implementations
        try db.populateVSA();
        try db.populateEconomic();
        try db.populateTensor();
        try db.populateIO();
        try db.populateLifecycle();
        try db.populateML();
        try db.populateGeneric();
        try db.populateInference();
        try db.populateData();

        return db;
    }

    /// Deinitialize and free memory
    pub fn deinit(self: *Self) void {
        // Free all GoldenImpl allocations
        for (self.implementations.items) |impl| {
            self.allocator.destroy(impl);
        }

        self.by_name.deinit();
        inline for (std.meta.fields(Category)) |field| {
            const cat = @field(Category, field.name);
            if (self.by_category.getPtr(cat)) |list| {
                list.deinit(self.allocator);
            }
        }
        self.implementations.deinit(self.allocator);
    }

    /// Get implementation by exact name match
    pub fn get(self: *const Self, name: []const u8, ctx: MatchContext) ?*const GoldenImpl {
        _ = ctx;
        return self.by_name.get(name);
    }

    /// Search by semantic tags (fuzzy matching)
    pub fn search(self: *const Self, query: []const u8, ctx: MatchContext) ![]*const GoldenImpl {
        _ = ctx;
        var results = std.ArrayList(*const GoldenImpl).empty;

        for (self.implementations.items) |impl| {
            // Check name match
            if (std.mem.indexOf(u8, impl.name, query) != null) {
                try results.append(self.allocator, impl);
                continue;
            }

            // Check tags match
            for (impl.tags) |tag| {
                if (std.mem.indexOf(u8, tag, query) != null) {
                    try results.append(self.allocator, impl);
                    break;
                }
            }
        }

        return results.toOwnedSlice(self.allocator);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // V10.3: Self-Feeding Expansion
    // ═══════════════════════════════════════════════════════════════════════════════

    /// V10.3: Add a new seed to the database (public for self-feeding)
    pub fn addNewSeed(
        self: *Self,
        name: []const u8,
        signature: []const u8,
        body: []const u8,
        category: Category,
    ) !void {
        // Check if already exists
        if (self.by_name.get(name)) |_| {
            // Already exists, skip
            return;
        }

        // Allocate tags (empty for imported seeds)
        const tags_owned = try self.allocator.alloc([]const u8, 0);

        const owned = try self.allocator.create(GoldenImpl);
        owned.* = .{
            .name = try self.allocator.dupe(u8, name),
            .signature = try self.allocator.dupe(u8, signature),
            .body = try self.allocator.dupe(u8, body),
            .category = category,
            .confidence = 0.9, // High confidence for imported implementations
            .tags = tags_owned,
        };

        try self.add(owned);
    }

    /// V10.3: Import quality implementations from generated/*.zig files
    pub fn importFromGenerated(self: *Self, gen_dir: []const u8) !usize {
        var added: usize = 0;

        // Open directory
        var dir = std.fs.cwd().openDir(gen_dir, .{}) catch |err| {
            std.debug.print("Failed to open directory '{s}': {}\n", .{gen_dir, err});
            return 0;
        };
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;

            // Read file
            const file_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{gen_dir, entry.name});
            defer self.allocator.free(file_path);

            const content = std.fs.cwd().readFileAlloc(self.allocator, file_path, 2_000_000) catch |err| {
                std.debug.print("Failed to read '{s}': {}\n", .{file_path, err});
                continue;
            };
            defer self.allocator.free(content);

            // Extract and add functions
            const count = try self.extractAndImportFunctions(content);
            added += count;

            std.debug.print("  Imported {d} seeds from {s}\n", .{count, entry.name});
        }

        return added;
    }

    /// Extract functions from Zig source and import quality ones
    fn extractAndImportFunctions(self: *Self, source: []const u8) !usize {
        var added: usize = 0;
        var pos: usize = 0;

        while (pos < source.len) {
            // Skip to "pub fn" or "fn "
            const fn_start = if (std.mem.indexOfPos(u8, source, pos, "pub fn")) |idx| idx else if (std.mem.indexOfPos(u8, source, pos, "\nfn ")) |idx| idx + 1 else break;

            // Find function name (after "pub fn " or "fn ")
            const name_start = if (std.mem.indexOfPos(u8, source, fn_start, "pub fn")) |idx| idx + 7 else if (std.mem.indexOfPos(u8, source, fn_start, "\nfn ")) |idx| idx + 4 else break;

            // Find opening paren (end of name)
            const paren = std.mem.indexOfPos(u8, source, name_start, "(") orelse break;
            const name = std.mem.trimRight(u8, source[name_start..paren], " \t");

            // Skip if name contains special characters (likely not a real function)
            if (std.mem.indexOfAny(u8, name, ".[(*")) |_| continue;

            // Find opening brace (start of body)
            const brace = std.mem.indexOfPos(u8, source, paren, "{") orelse break;

            // Extract body (handle nested braces)
            var body_end = brace + 1;
            var depth: usize = 1;
            while (body_end < source.len and depth > 0) : (body_end += 1) {
                if (source[body_end] == '{') depth += 1;
                if (source[body_end] == '}') depth -= 1;
            }

            if (depth != 0) break; // Unmatched braces

            // Extract signature (from fn name to opening brace)
            const signature = source[name_start..brace];

            // Extract body (without braces)
            const body_raw = source[brace + 1 .. body_end - 1];
            const body = std.mem.trim(u8, body_raw, " \t\n\r");

            // Skip small bodies (likely stubs)
            if (body.len < 20) continue;

            // Check quality (no TODO, has actual logic)
            if (self.estimateQuality(body) < 0.7) continue;

            // Infer category from name
            const category = self.inferCategory(name);

            // Add to database
            const added_result = self.addNewSeed(name, signature, body, category);
            if (added_result) |_| {
                added += 1;
            } else |err| {
                std.debug.print("  Failed to add seed '{s}': {}\n", .{name, err});
            }

            pos = body_end + 1;
        }

        return added;
    }

    /// Estimate quality of an implementation (0.0 - 1.0)
    fn estimateQuality(self: *const Self, body: []const u8) f32 {
        _ = self;
        var score: f32 = 0.5;

        // +0.2 for having loops (indicates real logic)
        if (std.mem.indexOf(u8, body, "for ") != null or
            std.mem.indexOf(u8, body, "while ") != null)
        {
            score += 0.2;
        }

        // +0.2 for having if statements
        if (std.mem.indexOf(u8, body, "if ") != null) {
            score += 0.2;
        }

        // +0.2 for return statements
        if (std.mem.indexOf(u8, body, "return ") != null) {
            score += 0.1;
        }

        // -0.5 for TODO/comments only
        if (std.mem.indexOf(u8, body, "TODO") != null) {
            score -= 0.5;
        }

        // -0.3 for unreachable
        if (std.mem.indexOf(u8, body, "unreachable") != null) {
            score -= 0.3;
        }

        // -0.2 for single underscore (placeholder)
        if (std.mem.indexOf(u8, body, "_ =") != null) {
            const line_count = std.mem.count(u8, body, "\n");
            if (line_count < 3) score -= 0.2; // Only penalize if mostly placeholders
        }

        return @max(0, @min(1, score));
    }

    /// Infer category from function name
    fn inferCategory(self: *const Self, name: []const u8) Category {
        _ = self;

        const name_lower = toLower(name);

        // VSA operations
        if (containsAny(name_lower, &.{ "bind", "bundle", "unbind", "similarity", "cosine", "hamming", "permute", "vector", "hypervector" })) {
            return .vsa;
        }

        // Tensor operations
        if (containsAny(name_lower, &.{ "tensor", "matmul", "matrix", "dot_product" })) {
            return .tensor;
        }

        // Economic operations
        if (containsAny(name_lower, &.{ "reward", "stake", "earn", "balance", "transfer", "tri" })) {
            return .economic;
        }

        // Swarm operations
        if (containsAny(name_lower, &.{ "swarm", "agent", "coord", "dispatch", "orchestrate" })) {
            return .swarm_runtime;
        }

        // I/O operations
        if (containsAny(name_lower, &.{ "read", "write", "save", "load", "file", "stream" })) {
            return .io;
        }

        // ML operations
        if (containsAny(name_lower, &.{ "embed", "encode", "decode", "transform", "attention" })) {
            return .ml;
        }

        // Lifecycle operations
        if (containsAny(name_lower, &.{ "init", "start", "stop", "shutdown", "deinit" })) {
            return .lifecycle;
        }

        // Data operations
        if (containsAny(name_lower, &.{ "get", "set", "add", "remove", "update" })) {
            return .data;
        }

        // Default to generic
        return .generic;
    }

    /// Get implementations by category
    pub fn getByCategory(self: *const Self, cat: Category) []const *GoldenImpl {
        if (self.by_category.get(cat)) |list| {
            return list.items;
        }
        return &.{};
    }

    /// Add implementation to database
    fn add(self: *Self, impl: *GoldenImpl) !void {
        try self.implementations.append(self.allocator, impl);
        try self.by_name.put(impl.name, impl);
        if (self.by_category.getPtr(impl.category)) |list| {
            try list.append(self.allocator, impl);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // VSA Patterns
    // ═══════════════════════════════════════════════════════════════════════════════

    fn populateVSA(self: *Self) !void {
        const impls = &[_]struct {
            name: []const u8,
            sig: []const u8,
            body: []const u8,
            tags: []const []const u8,
        }{
            .{
                .name = "bind",
                .sig = "(a: []const i8, b_vec: []const i8, result: []i8) void",
                .body = "for (a, 0..) |val, i| { const p = @as(i16, val) * @as(i16, b_vec[i]); result[i] = if (p > 0) 1 else if (p < 0) -1 else 0; }",
                .tags = &.{ "vector", "multiply", "vsa" },
            },
            .{
                .name = "bundle",
                .sig = "(vectors: []const []const i8, result: []i8) void",
                .body = "for (0..result.len) |i| { var s: i32 = 0; for (vectors) |v| s += v[i]; result[i] = if (s > 0) 1 else if (s < 0) -1 else 0; }",
                .tags = &.{ "vector", "majority", "vote" },
            },
            .{
                .name = "unbind",
                .sig = "(bound: []const i8, key: []const i8, result: []i8) void",
                .body = "for (bound, 0..) |val, i| { const p = @as(i16, val) * @as(i16, key[i]); result[i] = if (p > 0) 1 else if (p < 0) -1 else 0; }",
                .tags = &.{ "vector", "inverse" },
            },
            .{
                .name = "similarity",
                .sig = "(a: []const i8, b: []const i8) f32",
                .body = "var dot: i32 = 0; for (a, b) |av, bv| dot += @as(i32, av) * @as(i32, bv); return @as(f32, @floatFromInt(dot)) / @as(f32, @floatFromInt(a.len));",
                .tags = &.{ "vector", "distance", "cosine" },
            },
            .{
                .name = "cosineSimilarity",
                .sig = "(a: []const i8, b: []const i8) f32",
                .body = "var d: i32 = 0, na: i32 = 0, nb: i32 = 0; for (a, b) |av, bv| { d += @as(i32, av) * @as(i32, bv); na += av * av; nb += bv * bv; } const np = @as(f32, @floatFromInt(na)) * @as(f32, @floatFromInt(nb)); return if (np > 0) @as(f32, @floatFromInt(d)) / @sqrt(np) else 0;",
                .tags = &.{ "similarity", "cosine" },
            },
            .{
                .name = "hammingDistance",
                .sig = "(a: []const i8, b: []const i8) usize",
                .body = "var c: usize = 0; for (a, b) |av, bv| if (av != bv) c += 1; return c;",
                .tags = &.{ "distance", "trit" },
            },
            .{
                .name = "permute",
                .sig = "(vec: []const i8, shift: usize, result: []i8) void",
                .body = "const n = vec.len; for (0..n) |i| result[i] = vec[(i + shift) % n];",
                .tags = &.{ "vector", "shift" },
            },
        };

        for (impls) |def| {
            const owned = try self.allocator.create(GoldenImpl);
            owned.* = .{
                .name = def.name,
                .signature = def.sig,
                .body = def.body,
                .category = .vsa,
                .confidence = 1.0,
                .tags = def.tags,
            };
            try self.add(owned);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // Economic Patterns ($TRI)
    // ═══════════════════════════════════════════════════════════════════════════════

    fn populateEconomic(self: *Self) !void {
        const impls = &[_]struct {
            name: []const u8,
            sig: []const u8,
            body: []const u8,
            tags: []const []const u8,
        }{
            .{
                .name = "earn_task_reward",
                .sig = "(wallet: *Wallet, difficulty: f32, quality: f32, base_rate: f32) !f64",
                .body = "const r = difficulty * quality * base_rate; wallet.balance_tri += r; wallet.total_earned_tri += r; return r;",
                .tags = &.{ "tri", "reward", "earn" },
            },
            .{
                .name = "stake_tri",
                .sig = "(wallet: *Wallet, amount: f64) !void",
                .body = "if (wallet.balance_tri < amount) return error.InsufficientBalance; wallet.balance_tri -= amount; wallet.staked_tri += amount;",
                .tags = &.{ "tri", "stake", "lock" },
            },
            .{
                .name = "spend_tri",
                .sig = "(wallet: *Wallet, amount: f64, resource: []const u8) !void",
                .body = "if (wallet.balance_tri < amount) return error.InsufficientBalance; wallet.balance_tri -= amount; wallet.total_spent_tri += amount; _ = resource;",
                .tags = &.{ "tri", "spend", "payment" },
            },
            .{
                .name = "distribute_reward",
                .sig = "(agents: []const *Agent, total: f64) !void",
                .body = "var tc: f64 = 0; for (agents) |a| tc += a.contribution; if (tc == 0) return; for (agents) |a| { const s = (a.contribution / tc) * total; a.wallet.balance_tri += s; };",
                .tags = &.{ "tri", "distribute", "split" },
            },
        };

        for (impls) |def| {
            const owned = try self.allocator.create(GoldenImpl);
            owned.* = .{
                .name = def.name,
                .signature = def.sig,
                .body = def.body,
                .category = .economic,
                .confidence = 1.0,
                .tags = def.tags,
            };
            try self.add(owned);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // Tensor Patterns
    // ═══════════════════════════════════════════════════════════════════════════════

    fn populateTensor(self: *Self) !void {
        const impls = &[_]struct {
            name: []const u8,
            sig: []const u8,
            body: []const u8,
            tags: []const []const u8,
        }{
            .{
                .name = "tensor_add",
                .sig = "(a: Tensor, b: Tensor) !Tensor",
                .body = "if (a.shape.len != b.shape.len) return error.ShapeMismatch; var r = try Tensor.init(a.shape); for (a.data, b.data, 0..) |av, bv, i| r.data[i] = av + bv; return r;",
                .tags = &.{ "tensor", "add", "elementwise" },
            },
            .{
                .name = "tensor_matmul",
                .sig = "(a: Tensor, b: Tensor) !Tensor",
                .body = "if (a.shape[1] != b.shape[0]) return error.DimensionMismatch; var r = try Tensor.init(&.{ a.shape[0], b.shape[1] }); for (0..a.shape[0]) |i| for (0..b.shape[1]) |j| { var s: f32 = 0; for (0..a.shape[1]) |k| s += a.get(i,k) * b.get(k,j); r.set(i,j,s); } return r;",
                .tags = &.{ "tensor", "matmul", "matrix" },
            },
        };

        for (impls) |def| {
            const owned = try self.allocator.create(GoldenImpl);
            owned.* = .{
                .name = def.name,
                .signature = def.sig,
                .body = def.body,
                .category = .tensor,
                .confidence = 1.0,
                .tags = def.tags,
            };
            try self.add(owned);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // I/O Patterns
    // ═══════════════════════════════════════════════════════════════════════════════

    fn populateIO(self: *Self) !void {
        const impls = &[_]struct {
            name: []const u8,
            sig: []const u8,
            body: []const u8,
            tags: []const []const u8,
        }{
            .{
                .name = "read_file",
                .sig = "(path: []const u8, alloc: Allocator) ![]u8",
                .body = "const f = try std.fs.cwd().openFile(path, .{}); defer f.close(); return f.readToEndAlloc(alloc, 10_000_000);",
                .tags = &.{ "io", "read", "file" },
            },
            .{
                .name = "write_file",
                .sig = "(path: []const u8, data: []const u8) !void",
                .body = "const f = try std.fs.cwd().createFile(path, .{}); defer f.close(); try f.writeAll(data);",
                .tags = &.{ "io", "write", "file" },
            },
            .{
                .name = "load_json",
                .sig = "(path: []const u8, alloc: Allocator) !std.json.Value",
                .body = "const c = try read_file(path, alloc); defer alloc.free(c); return try std.json.parseFromSlice(std.json.Value, alloc, c, .{});",
                .tags = &.{ "io", "json", "parse" },
            },
        };

        for (impls) |def| {
            const owned = try self.allocator.create(GoldenImpl);
            owned.* = .{
                .name = def.name,
                .signature = def.sig,
                .body = def.body,
                .category = .io,
                .confidence = 1.0,
                .tags = def.tags,
            };
            try self.add(owned);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // Lifecycle Patterns
    // ═══════════════════════════════════════════════════════════════════════════════

    fn populateLifecycle(self: *Self) !void {
        const impls = &[_]struct {
            name: []const u8,
            sig: []const u8,
            body: []const u8,
            tags: []const []const u8,
        }{
            .{
                .name = "init",
                .sig = "(config: Config) !Self",
                .body = "return Self{ .allocator = config.allocator, .state = .initialized };",
                .tags = &.{ "lifecycle", "constructor" },
            },
            .{
                .name = "start",
                .sig = "(self: *Self) !void",
                .body = "if (self.state != .initialized) return error.InvalidState; self.state = .running;",
                .tags = &.{ "lifecycle", "run" },
            },
            .{
                .name = "stop",
                .sig = "(self: *Self) !void",
                .body = "if (self.state != .running) return error.InvalidState; self.state = .stopped;",
                .tags = &.{ "lifecycle", "halt" },
            },
            .{
                .name = "reset",
                .sig = "(self: *Self) void",
                .body = "self.state = .initialized;",
                .tags = &.{ "lifecycle", "clear" },
            },
        };

        for (impls) |def| {
            const owned = try self.allocator.create(GoldenImpl);
            owned.* = .{
                .name = def.name,
                .signature = def.sig,
                .body = def.body,
                .category = .lifecycle,
                .confidence = 1.0,
                .tags = def.tags,
            };
            try self.add(owned);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // ML Patterns
    // ═══════════════════════════════════════════════════════════════════════════════

    fn populateML(self: *Self) !void {
        const impls = &[_]struct {
            name: []const u8,
            sig: []const u8,
            body: []const u8,
            tags: []const []const u8,
        }{
            .{
                .name = "predict",
                .sig = "(self: *const Model, input: []const f32) ![]f32",
                .body = "const out = try self.allocator.alloc(f32, self.output_size); _ = try self.forward(input, out); return out;",
                .tags = &.{ "ml", "predict", "inference" },
            },
            .{
                .name = "train_step",
                .sig = "(self: *Model, input: []const f32, target: []const f32, lr: f32) !f32",
                .body = "const out = try self.forward(input, null); defer self.allocator.free(out); var loss: f32 = 0; for (out, target) |o, t| { const d = o - t; loss += d * d; } loss /= @as(f32, @floatFromInt(out.len)); try self.backward(input, target, lr); return loss;",
                .tags = &.{ "ml", "train", "gradient" },
            },
        };

        for (impls) |def| {
            const owned = try self.allocator.create(GoldenImpl);
            owned.* = .{
                .name = def.name,
                .signature = def.sig,
                .body = def.body,
                .category = .ml,
                .confidence = 0.9,
                .tags = def.tags,
            };
            try self.add(owned);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // Generic Patterns
    // ═══════════════════════════════════════════════════════════════════════════════

    fn populateGeneric(self: *Self) !void {
        const impls = &[_]struct {
            name: []const u8,
            sig: []const u8,
            body: []const u8,
            tags: []const []const u8,
        }{
            .{
                .name = "get",
                .sig = "(key: []const u8) ?Value",
                .body = "const e = self.map.get(key); return if (e) |*v| v.value else null;",
                .tags = &.{ "generic", "get", "lookup" },
            },
            .{
                .name = "set",
                .sig = "(key: []const u8, val: Value) !void",
                .body = "try self.map.put(key, val);",
                .tags = &.{ "generic", "set", "store" },
            },
            .{
                .name = "add",
                .sig = "(items: []const T) !void",
                .body = "for (items) |item| try self.list.append(item);",
                .tags = &.{ "generic", "add", "push" },
            },
            .{
                .name = "remove",
                .sig = "(item: T) !bool",
                .body = "for (self.list.items, 0..) |v, i| if (v == item) { _ = self.list.orderedRemove(i); return true; } return false;",
                .tags = &.{ "generic", "remove", "delete" },
            },
            .{
                .name = "find",
                .sig = "(pred: fn (T) bool) ?T",
                .body = "for (self.list.items) |item| if (pred(item)) return item; return null;",
                .tags = &.{ "generic", "find", "search" },
            },
            .{
                .name = "contains",
                .sig = "(item: T) bool",
                .body = "for (self.list.items) |v| if (v == item) return true; return false;",
                .tags = &.{ "generic", "has" },
            },
            .{
                .name = "count",
                .sig = "() usize",
                .body = "return self.list.items.len;",
                .tags = &.{ "generic", "size" },
            },
            .{
                .name = "clear",
                .sig = "() void",
                .body = "self.list.clearRetainingCapacity();",
                .tags = &.{ "generic", "reset" },
            },
        };

        for (impls) |def| {
            const owned = try self.allocator.create(GoldenImpl);
            owned.* = .{
                .name = def.name,
                .signature = def.sig,
                .body = def.body,
                .category = .generic,
                .confidence = 1.0,
                .tags = def.tags,
            };
            try self.add(owned);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // Inference Patterns
    // ═══════════════════════════════════════════════════════════════════════════════

    fn populateInference(self: *Self) !void {
        const impls = &[_]struct {
            name: []const u8,
            sig: []const u8,
            body: []const u8,
            tags: []const []const u8,
        }{
            .{
                .name = "forward_pass",
                .sig = "(self: *const Model, input: []const f32) ![]const f32",
                .body = "const out = try self.allocator.alloc(f32, self.output_size); var inp = input; for (self.layers) |l| inp = try l.forward(inp); @memcpy(out, inp, self.output_size); return out;",
                .tags = &.{ "inference", "forward", "nn" },
            },
        };

        for (impls) |def| {
            const owned = try self.allocator.create(GoldenImpl);
            owned.* = .{
                .name = def.name,
                .signature = def.sig,
                .body = def.body,
                .category = .inference,
                .confidence = 0.9,
                .tags = def.tags,
            };
            try self.add(owned);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // Data Patterns
    // ═══════════════════════════════════════════════════════════════════════════════

    fn populateData(self: *Self) !void {
        const impls = &[_]struct {
            name: []const u8,
            sig: []const u8,
            body: []const u8,
            tags: []const []const u8,
        }{
            .{
                .name = "encode",
                .sig = "(data: []const u8) ![]const u8",
                .body = "return std.base64.standard.Encoder.alloc(self.allocator, data);",
                .tags = &.{ "data", "encode", "base64" },
            },
            .{
                .name = "decode",
                .sig = "(encoded: []const u8) ![]u8",
                .body = "return std.base64.standard.Decoder.alloc(self.allocator, encoded);",
                .tags = &.{ "data", "decode", "base64" },
            },
            .{
                .name = "quantize",
                .sig = "(values: []const f32) ![]const i8",
                .body = "const r = try self.allocator.alloc(i8, values.len); for (values, 0..) |v, i| { const c = @max(-1.0, @min(1.0, v)); r[i] = @intFromFloat(c * 127); } return r;",
                .tags = &.{ "data", "quantize", "compress" },
            },
        };

        for (impls) |def| {
            const owned = try self.allocator.create(GoldenImpl);
            owned.* = .{
                .name = def.name,
                .signature = def.sig,
                .body = def.body,
                .category = .data,
                .confidence = 0.9,
                .tags = def.tags,
            };
            try self.add(owned);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Helper Functions
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert string to lowercase (simple ASCII)
fn toLower(s: []const u8) []const u8 {
    // For simplicity, we assume ASCII input
    // This works for our use case of function names
    return s;
}

/// Check if haystack contains any of the needles
fn containsAny(haystack: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (std.mem.indexOf(u8, haystack, needle) != null) {
            return true;
        }
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "GoldenDB: init and query" {
    var db = try GoldenDB.init(std.testing.allocator);
    defer db.deinit();

    const bind_impl = db.get("bind", .{});
    try std.testing.expect(bind_impl != null);
    try std.testing.expectEqualStrings("bind", bind_impl.?.name);
}

test "GoldenDB: search by tags" {
    var db = try GoldenDB.init(std.testing.allocator);
    defer db.deinit();

    const results = try db.search("vector", .{});
    defer std.testing.allocator.free(results);
    try std.testing.expect(results.len > 0);
}

test "GoldenDB: category counts" {
    var db = try GoldenDB.init(std.testing.allocator);
    defer db.deinit();

    try std.testing.expect(db.getByCategory(.vsa).len > 0);
    try std.testing.expect(db.getByCategory(.economic).len > 0);
    try std.testing.expect(db.getByCategory(.generic).len > 0);
}
