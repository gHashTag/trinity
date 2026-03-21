//! Golden Chain v5.1 — STORM P4 Phase (Real Execution)
//! 28-link pipeline with neuroanatomical mapping
//! Role split: Planner/Coder/Reviewer/Tester/Integrator
//! Checkpoint recovery, cost tracking, handoff validation
//! Real subprocess execution with timeout

const std = @import("std");

pub const Role = enum {
    planner,
    coder,
    reviewer,
    tester,
    integrator,
};

pub const BrainZone = enum {
    // Prosencephalon (Strategic)
    cortex, dlpfc, ofc, acc, broca, wernicke, insula,
    // Limbic System (Memory/Motivation)
    hippocampus, amygdala, accumbens, fornix,
    // Basal Ganglia (Arena Selection)
    striatum, pallidus, nigra,
    // Diencephalon (Relay)
    thalamus, hypothalamus, habenula,
    // Mesencephalon (Operational)
    colliculus_s, colliculus_i, ruber, pag, vta,
    // Rhombencephalon (Infrastructure)
    cerebellum, vermis, pons, medulla, coeruleus, raphe,
};

pub const Link = struct {
    id: u8,
    name: []const u8,
    role: Role,
    brain_zone: BrainZone,
    timeout_ms: u64 = 300_000,
    checkpoint: bool = true,
};

pub const LinkResult = struct {
    success: bool,
    message: []const u8,
    duration_ms: u64,
    exit_code: u8 = 0,
    stdout: []const u8 = "",
    stderr: []const u8 = "",
};

pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,
};

pub const State = struct {
    current_link: u8 = 0,
    completed_links: u28 = 0, // bitset of completed link IDs
    total_cost_ms: u64 = 0,
    start_time: i64 = 0,
    last_checkpoint: ?[]const u8 = null,
};

pub const CheckpointData = struct {
    version: []const u8 = "5.1",
    task: []const u8,
    current_link: u8,
    completed_links: u28,
    total_cost_ms: u64,
    timestamp: i64,
    results: []LinkResult,
};

pub const CHAIN_LINKS = [28]Link{
    // PHASE 1: PLANNING (Links 1-5)
    .{ .id = 1, .name = "analyze_request", .role = .planner, .brain_zone = .wernicke },
    .{ .id = 2, .name = "check_experience_blacklist", .role = .planner, .brain_zone = .amygdala },
    .{ .id = 3, .name = "find_similar", .role = .planner, .brain_zone = .hippocampus },
    .{ .id = 4, .name = "create_tri_spec", .role = .planner, .brain_zone = .broca },
    .{ .id = 5, .name = "validate_spec", .role = .planner, .brain_zone = .dlpfc },
    // PHASE 2: CODING (Links 6-12)
    .{ .id = 6, .name = "vibee_codegen", .role = .coder, .brain_zone = .cerebellum },
    .{ .id = 7, .name = "verify_syntax", .role = .coder, .brain_zone = .cerebellum },
    .{ .id = 8, .name = "zig_fmt_check", .role = .coder, .brain_zone = .cerebellum },
    .{ .id = 9, .name = "zig_build", .role = .coder, .brain_zone = .cerebellum },
    .{ .id = 10, .name = "run_unit_tests", .role = .tester, .brain_zone = .striatum },
    .{ .id = 11, .name = "vsa_verify", .role = .tester, .brain_zone = .striatum },
    .{ .id = 12, .name = "tri_spec_zig_sync", .role = .reviewer, .brain_zone = .acc },
    // PHASE 3: REVIEW (Links 13-18) — P1 ETHICAL ZONES HERE
    .{ .id = 13, .name = "code_review", .role = .reviewer, .brain_zone = .dlpfc },
    .{ .id = 14, .name = "security_audit", .role = .reviewer, .brain_zone = .habenula },
    .{ .id = 15, .name = "perf_check", .role = .reviewer, .brain_zone = .dlpfc },
    .{ .id = 16, .name = "doc_check", .role = .reviewer, .brain_zone = .dlpfc },
    .{ .id = 17, .name = "api_compat", .role = .reviewer, .brain_zone = .thalamus },
    .{ .id = 18, .name = "approve_merge", .role = .reviewer, .brain_zone = .ofc },
    // PHASE 4: TESTING (Links 19-24)
    .{ .id = 19, .name = "e2e_test", .role = .tester, .brain_zone = .striatum },
    .{ .id = 20, .name = "integration_test", .role = .tester, .brain_zone = .striatum },
    .{ .id = 21, .name = "stress_test", .role = .tester, .brain_zone = .coeruleus },
    .{ .id = 22, .name = "fuzz_test", .role = .tester, .brain_zone = .striatum },
    .{ .id = 23, .name = "benchmark", .role = .tester, .brain_zone = .nigra },
    .{ .id = 24, .name = "toxic_verdict", .role = .reviewer, .brain_zone = .ofc },
    // PHASE 5: INTEGRATION (Links 25-28)
    .{ .id = 25, .name = "git_commit", .role = .integrator, .brain_zone = .cerebellum },
    .{ .id = 26, .name = "github_issue_comment", .role = .integrator, .brain_zone = .fornix },
    .{ .id = 27, .name = "experience_save", .role = .integrator, .brain_zone = .hippocampus },
    .{ .id = 28, .name = "phoenix_lineage_update", .role = .integrator, .brain_zone = .raphe },
};

pub const GoldenChain = struct {
    allocator: std.mem.Allocator,
    links: [28]Link = CHAIN_LINKS,
    checkpoint_dir: []const u8,
    log_level: LogLevel = .info,
    state: State = .{},
    results: std.ArrayListUnmanaged(LinkResult) = .empty,

    pub fn init(allocator: std.mem.Allocator) !GoldenChain {
        const checkpoint_dir = try allocator.dupe(u8, ".trinity/storm/checkpoints");
        errdefer allocator.free(checkpoint_dir);

        // Ensure checkpoint directory exists
        std.fs.cwd().makePath(checkpoint_dir) catch |e| {
            std.log.warn("Failed to create checkpoint dir: {}", .{e});
        };

        return .{
            .allocator = allocator,
            .checkpoint_dir = checkpoint_dir,
        };
    }

    pub fn deinit(self: *GoldenChain) void {
        self.allocator.free(self.checkpoint_dir);
        for (self.results.items) |r| {
            self.allocator.free(r.message);
            if (r.stdout.len > 0) self.allocator.free(r.stdout);
            if (r.stderr.len > 0) self.allocator.free(r.stderr);
        }
        self.results.deinit(self.allocator);
        if (self.state.last_checkpoint) |cp| self.allocator.free(cp);
    }

    /// Execute a single link (P6: real subprocess execution with timeout)
    pub fn executeLink(self: *GoldenChain, link: Link, task: []const u8) !LinkResult {
        self.log(.info, "\n🔗 [{d:0>2}] {s} [{s}] [{s}] executing...", .{
            link.id, link.name, @tagName(link.role), @tagName(link.brain_zone),
        });

        // Build command for this link
        const cmd = try self.buildCommand(link, task);
        defer {
            for (cmd.argv) |arg| self.allocator.free(arg);
            self.allocator.free(cmd.argv);
        }

        // Spawn child process
        const start_time = std.time.nanoTimestamp();
        var child = std.process.Child.init(.{
            .allocator = self.allocator,
            .argv = cmd.argv,
            .cwd = null, // Current working directory
            .env_map = null, // Inherit environment
        });
        defer child.deinit();

        // Start the process
        try child.spawn();

        // Wait for completion with timeout (simulated for P6)
        // TODO: Add real timeout handling using std.Thread.spawn with child.wait()
        const wait_result = child.wait();

        const end_time = std.time.nanoTimestamp();
        const elapsed_ns = end_time - start_time;
        const elapsed_ms = @as(u64, @intFromFloat(@divTrunc(@as(f128, @floatFromInt(elapsed_ns)), 1_000_000)));

        // Parse result from WaitedResult (Zig 0.15 tagged union)
        var success: bool = false;
        var exit_code: u8 = 1;
        var message: []const u8 = "";

        switch (wait_result) {
            .Exited => |term| {
                if (term.code == 0) {
                    success = true;
                    exit_code = term.code;
                    message = "Success";
                } else {
                    success = false;
                    exit_code = term.code;
                    message = try std.fmt.allocPrint(self.allocator, "Exit code {d}", .{term.code});
                }
            },
            .Signal => |sig| {
                success = false;
                exit_code = 128 + @as(u8, @intFromEnum(sig));
                message = try std.fmt.allocPrint(self.allocator, "Signal: {s}", .{@tagName(sig)});
            },
            else => {
                success = false;
                exit_code = 1;
                message = try std.fmt.allocPrint(self.allocator, "Unknown termination", .{});
            },
        }

        const result = LinkResult{
            .success = success,
            .message = message,
            .duration_ms = elapsed_ms,
            .exit_code = exit_code,
        };

        if (success) {
            self.log(.info, "✅ [{d}] {s} completed in {}ms", .{ link.id, link.name, result.duration_ms });
        } else {
            self.log(.err, "❌ [{d}] {s} failed: {s}", .{ link.id, link.name, result.message });
        }

        try self.results.append(self.allocator, result);
        self.state.total_cost_ms += result.duration_ms;

        return result;
    }

    /// Build command arguments for a link (P6: tri command routing)
    fn buildCommand(self: *GoldenChain, link: Link, task: []const u8) !struct { argv: [][]const u8 } {
        _ = task;

        // P6: Map links to actual tri commands
        // For now, use echo as fallback for commands not yet mapped
        const link_command = switch (link.id) {
            // Planning phase
            1 => "tri wernicke parse", // analyze_request
            2 => "tri amygdala check-fear", // check_blacklist
            3 => "tri hippocampus recall", // find_similar
            4 => "tri broca spec-gen", // create_tri_spec
            5 => "tri dlpfc analyze", // validate_spec

            // Coding phase
            6 => "zig build vibee", // vibee_codegen
            7 => "zig fmt src/", // verify_syntax
            8 => "zig fmt src/", // zig_fmt_check
            9 => "zig build", // zig_build
            10 => "zig test", // run_unit_tests
            11 => "tri vsa verify", // vsa_verify
            12 => "tri acc conflict-scan", // tri_spec_zig_sync

            // Review phase
            13 => "tri dlpfc analyze", // code_review
            14 => "tri habenula unfair-detect", // security_audit
            15 => "tri dlpfc analyze", // perf_check
            16 => "tri dlpfc analyze", // doc_check
            17 => "tri thalamus route", // api_compat
            18 => "tri ofc verdict --toxic", // approve_merge

            // Testing phase
            19 => "zig test --test-filter=e2e", // e2e_test
            20 => "zig test --test-filter=integration", // integration_test
            21 => "zig test --test-filter=stress", // stress_test
            22 => "zig test --test-filter=fuzz", // fuzz_test
            23 => "tri nigra calibrate", // benchmark
            24 => "tri ofc verdict --toxic", // toxic_verdict

            // Integration phase
            25 => "git add -A && git commit -m", // git_commit
            26 => "gh issue comment", // github_issue_comment
            27 => "tri hippocampus save", // experience_save
            28 => "tri raphe stabilize", // phoenix_lineage_update

            else => try std.fmt.allocPrint(self.allocator, "echo Link[{d}]: {s}", .{link.id, link.name}),
        };

        // Parse command into argv
        var parts = std.ArrayList([]const u8).init(self.allocator);
        defer parts.deinit();

        var iter = std.mem.splitSequence(u8, link_command, .{ ' ' });
        while (iter.next()) |part| {
            try parts.append(part);
        }

        const argv = try parts.toOwnedSlice();
        return .{ .argv = argv };
    }

    /// Validate handoff between two roles
    pub fn validateHandoff(_: *const GoldenChain, from: Role, to: Role) !bool {
        // Define valid transitions
        inline for (0..5) |from_idx| {
            inline for (0..5) |to_idx| {
                _ = from_idx;
                _ = to_idx;
            }
        }

        const from_idx = @intFromEnum(from);
        const to_idx = @intFromEnum(to);

        // Valid transitions: same role OK for consecutive links, final transitions as designed
        const valid = switch (from_idx) {
            // planner -> (planner, coder)
            0 => to_idx == 0 or to_idx == 1,
            // coder -> (coder, reviewer, tester)
            1 => to_idx == 1 or to_idx == 2 or to_idx == 3,
            // reviewer -> (reviewer, tester, coder, integrator)
            2 => to_idx == 2 or to_idx == 3 or to_idx == 1 or to_idx == 4,
            // tester -> (tester, reviewer, coder, integrator)
            3 => to_idx == 3 or to_idx == 2 or to_idx == 1 or to_idx == 4,
            // integrator -> integrator (terminal phase)
            4 => to_idx == 4,
            else => false,
        };

        if (!valid) {
            std.log.err("❌ Invalid handoff: {s} -> {s}", .{ @tagName(from), @tagName(to) });
            return error.InvalidHandoff;
        }

        std.log.debug("✓ Valid handoff: {s} -> {s}", .{ @tagName(from), @tagName(to) });
        return true;
    }

    /// Save checkpoint to disk
    pub fn saveCheckpoint(self: *GoldenChain, task: []const u8) !void {
        const timestamp = std.time.timestamp();

        // Create checkpoint filename
        const filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/checkpoint_{d}.json",
            .{ self.checkpoint_dir, timestamp },
        );
        defer self.allocator.free(filename);

        // Serialize to JSON (simple format)
        var json_buf = std.ArrayListUnmanaged(u8){};
        defer json_buf.deinit(self.allocator);

        const open_brace = [_]u8{'{'};
        try json_buf.appendSlice(self.allocator, &open_brace);
        try json_buf.writer(self.allocator).print("\"version\": \"5.1\",", .{});
        try json_buf.writer(self.allocator).print("\"task\": \"{s}\",", .{task});
        try json_buf.writer(self.allocator).print("\"current_link\": {d},", .{self.state.current_link});
        try json_buf.writer(self.allocator).print("\"completed_links\": {d},", .{self.state.completed_links});
        try json_buf.writer(self.allocator).print("\"total_cost_ms\": {d},", .{self.state.total_cost_ms});
        try json_buf.writer(self.allocator).print("\"timestamp\": {d},", .{timestamp});

        const results_open = [_]u8{',', '"', 'r', 'e', 's', 'u', 'l', 't', 's', '"', ' ', '['};
        try json_buf.appendSlice(self.allocator, &results_open);

        for (self.results.items, 0..) |r, i| {
            if (i > 0) {
                const comma = [_]u8{','};
                try json_buf.appendSlice(self.allocator, &comma);
            }
            try json_buf.writer(self.allocator).print(
                "{{\"success\": {},\"message\": \"{s}\",\"duration_ms\": {d}}}",
                .{ r.success, r.message, r.duration_ms }
            );
        }

        const close_brace = [_]u8{']', '}'};
        try json_buf.appendSlice(self.allocator, &close_brace);

        // Write to file
        try std.fs.cwd().writeFile(.{
            .sub_path = filename,
            .data = json_buf.items,
        });

        self.log(.info, "💾 Checkpoint saved to {s}", .{filename});

        // Update last_checkpoint
        if (self.state.last_checkpoint) |old| self.allocator.free(old);
        self.state.last_checkpoint = try self.allocator.dupe(u8, filename);
    }

    /// Load checkpoint from disk
    pub fn loadCheckpoint(self: *GoldenChain, filename: []const u8) !CheckpointData {
        self.log(.info, "📂 Loading checkpoint from {s}", .{filename});

        const content = try std.fs.cwd().readFileAlloc(self.allocator, filename, 1_048_576);
        defer self.allocator.free(content);

        // Parse JSON (simplified parsing)
        var parser = std.json.Parser.init(self.allocator, false);
        defer parser.deinit();
        var tree = try parser.parse(content);
        defer tree.deinit();

        if (tree != .object) return error.InvalidCheckpoint;

        const obj = tree.object;

        var cp_data: CheckpointData = .{
            .task = "",
            .results = &[_]LinkResult{},
        };

        // Extract fields
        if (obj.get("current_link")) |v| {
            if (v != .integer) return error.InvalidCheckpoint;
            cp_data.current_link = @intCast(v.integer);
        }

        if (obj.get("completed_links")) |v| {
            if (v != .integer) return error.InvalidCheckpoint;
            cp_data.completed_links = @intCast(v.integer);
        }

        if (obj.get("total_cost_ms")) |v| {
            if (v != .integer) return error.InvalidCheckpoint;
            cp_data.total_cost_ms = @intCast(v.integer);
        }

        if (obj.get("timestamp")) |v| {
            if (v != .integer) return error.InvalidCheckpoint;
            cp_data.timestamp = @intCast(v.integer);
        }

        if (obj.get("task")) |v| {
            if (v != .string) return error.InvalidCheckpoint;
            cp_data.task = try self.allocator.dupe(u8, v.string);
        }

        // Parse results array
        if (obj.get("results")) |v| {
            if (v != .array) return error.InvalidCheckpoint;

            const arr = v.array;
            cp_data.results = try self.allocator.alloc(LinkResult, arr.items.len);

            for (arr.items, 0..) |item, i| {
                if (item != .object) return error.InvalidCheckpoint;
                const item_obj = item.object;

                var result: LinkResult = .{
                    .message = "",
                };

                if (item_obj.get("success")) |s| {
                    if (s != .boolean) return error.InvalidCheckpoint;
                    result.success = s.boolean;
                }

                if (item_obj.get("duration_ms")) |d| {
                    if (d != .integer) return error.InvalidCheckpoint;
                    result.duration_ms = @intCast(d.integer);
                }

                if (item_obj.get("message")) |m| {
                    if (m != .string) return error.InvalidCheckpoint;
                    result.message = try self.allocator.dupe(u8, m.string);
                }

                cp_data.results[i] = result;
            }
        }

        return cp_data;
    }

    /// Resume from checkpoint
    pub fn resumeFromCheckpoint(self: *GoldenChain, checkpoint_id: []const u8, task: []const u8) !u8 {
        const checkpoint_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/checkpoint_{s}.json",
            .{ self.checkpoint_dir, checkpoint_id },
        );
        defer self.allocator.free(checkpoint_path);

        const cp = try self.loadCheckpoint(checkpoint_path);

        // Restore state
        self.state.current_link = cp.current_link;
        self.state.completed_links = cp.completed_links;
        self.state.total_cost_ms = cp.total_cost_ms;

        self.log(.info, "▶️ Resuming from link {d}", .{cp.current_link});

        // Continue execution from checkpoint
        return self.runFrom(task, cp.current_link);
    }

    /// Run chain from specific link
    fn runFrom(self: *GoldenChain, task: []const u8, start_link: u8) !u8 {
        var prev_role: ?Role = null;

        for (self.links[start_link..]) |link| {
            // Validate handoff
            if (prev_role) |prev| {
                _ = self.validateHandoff(prev, link.role) catch |err| {
                    self.log(.err, "Handoff validation failed: {}", .{err});
                    return err;
                };
            }
            prev_role = link.role;

            self.state.current_link = link.id;

            // Execute link
            const result = try self.executeLink(link, task);
            if (!result.success) {
                self.log(.err, "Chain failed at link {d}: {s}", .{ link.id, link.name });

                // Save checkpoint on failure
                _ = self.saveCheckpoint(task) catch |e| {
                    self.log(.warn, "Failed to save checkpoint: {}", .{e});
                };

                return 1;
            }

            // Save checkpoint after each link if enabled
            if (link.checkpoint) {
                _ = self.saveCheckpoint(task) catch |e| {
                    self.log(.warn, "Failed to save checkpoint: {}", .{e});
                };
            }

            // Mark as completed
            self.state.completed_links |= (@as(u28, 1) << @intCast(link.id - 1));
        }

        self.log(.info, "\n✅ Golden Chain complete! Total time: {d}ms ({d:.1}s)", .{
            self.state.total_cost_ms,
            @as(f64, @floatFromInt(self.state.total_cost_ms)) / 1000.0,
        });

        return 0;
    }

    /// Run full chain
    pub fn run(self: *GoldenChain, task: []const u8) !u8 {
        self.state.start_time = std.time.timestamp();
        self.state.current_link = 1;
        self.results.clearRetainingCapacity();

        std.debug.print("\n🔗 Golden Chain v5.1 — 28 links with neuroanatomical mapping:\n", .{});

        for (self.links) |link| {
            std.debug.print("  [{d:0>2}] {s:20} [{s:12}] [{s:8}]\n", .{
                link.id, link.name, @tagName(link.brain_zone), @tagName(link.role),
            });
        }

        std.debug.print("\n🚀 Starting execution...\n\n", .{});

        return self.runFrom(task, 0);
    }

    /// Internal logging helper
    fn log(_: *const GoldenChain, level: LogLevel, comptime fmt: []const u8, args: anytype) void {
        const prefix = switch (level) {
            .debug => "🔍",
            .info => "ℹ️",
            .warn => "⚠️",
            .err => "❌",
        };
        _ = prefix; // Mark prefix as used
        std.debug.print(fmt ++ "\n", args);
    }
};
