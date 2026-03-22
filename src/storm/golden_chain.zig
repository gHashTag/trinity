//! Golden Chain v5.2 — STORM P10 Phase (Experience + Timeout + Parallel)
//! 28-link pipeline with neuroanatomical mapping
//! Role split: Planner/Coder/Reviewer/Tester/Integrator
//! Checkpoint recovery, cost tracking, handoff validation
//! Real subprocess execution with timeout, Experience integration

const std = @import("std");

// P10: Import real link modules
const vibee_link = @import("links/vibee.zig");
const zig_tools_link = @import("links/zig_tools.zig");
const testing_link = @import("links/testing.zig");
const integration_link = @import("links/integration.zig");

// P10: Import Experience Engine and Timeout Handler
const ExperienceEngine = @import("experience_engine.zig").ExperienceEngine;
const TimeoutHandler = @import("timeout_handler.zig").TimeoutHandler;

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
    message: ?[]const u8 = null,    // P11: null means no message, safe to free
    duration_ms: u64,
    exit_code: u8 = 0,
    stdout: ?[]const u8 = null,   // P11: null means no output, safe to free
    stderr: ?[]const u8 = null,   // P11: null means no error, safe to free
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
    version: []const u8 = "5.2",
    task: []const u8,
    current_link: u8,
    completed_links: u28,
    total_cost_ms: u64,
    timestamp: i64,
    results: []LinkResult,  // References to JSON-parsed data
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

    // P10: Experience Engine and Timeout Handler
    experience: ?*ExperienceEngine = null,
    timeout_handler: ?*TimeoutHandler = null,

    pub fn init(allocator: std.mem.Allocator) !GoldenChain {
        const checkpoint_dir = try allocator.dupe(u8, ".trinity/storm/checkpoints");
        errdefer allocator.free(checkpoint_dir);

        // Ensure checkpoint directory exists
        std.fs.cwd().makePath(checkpoint_dir) catch |e| {
            std.log.warn("Failed to create checkpoint dir: {}", .{e});
        };

        // P10: Initialize experience engine and timeout handler
        const experience = allocator.create(ExperienceEngine) catch |e| {
            std.log.warn("Failed to create experience engine: {}", .{e});
            return error.ExperienceInitFailed;
        };
        experience.* = try ExperienceEngine.init(allocator);

        const timeout_handler = allocator.create(TimeoutHandler) catch |e| {
            std.log.warn("Failed to create timeout handler: {}", .{e});
            return error.TimeoutHandlerInitFailed;
        };
        timeout_handler.* = TimeoutHandler.init(allocator);

        return .{
            .allocator = allocator,
            .checkpoint_dir = checkpoint_dir,
            .experience = experience,
            .timeout_handler = timeout_handler,
        };
    }

    pub fn deinit(self: *GoldenChain) void {
        self.allocator.free(self.checkpoint_dir);

        // P11: Free only message strings (allocated with self.allocator)
        // stdout/stderr from timeout_handler use page_allocator - don't free
        for (self.results.items) |r| {
            if (r.message) |msg| self.allocator.free(msg);
            // Skip freeing stdout/stderr - allocated with page_allocator in timeout_handler
        }

        self.results.deinit(self.allocator);
        if (self.state.last_checkpoint) |cp| self.allocator.free(cp);

        // P10: Clean up experience and timeout handler
        if (self.experience) |exp| {
            self.allocator.destroy(exp);
        }
        if (self.timeout_handler) |th| {
            self.allocator.destroy(th);
        }
    }

    /// Execute a single link (P10: with experience consult and timeout)
    pub fn executeLink(self: *GoldenChain, link: Link, task: []const u8) !LinkResult {
        self.log(.info, "\n🔗 [{d:0>2}] {s} [{s}] [{s}] executing...", .{
            link.id, link.name, @tagName(link.role), @tagName(link.brain_zone),
        });

        // P10: Consult experience before execution
        if (self.experience) |exp| {
            const task_name = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ task, link.name });
            defer self.allocator.free(task_name);

            if (exp.consult(task_name)) |ctx| {
                defer {
                    // Manual cleanup for ctx (const -> needs allocator access)
                    // TaskContext.similar_tasks is already a slice reference
                    // TaskContext.task is allocated
                    self.allocator.free(ctx.task);
                    self.allocator.free(ctx.recommendation);
                }

                if (ctx.is_blacklisted) {
                    self.log(.warn, "⛔ Task blacklisted by MNL: {s}", .{ctx.recommendation});
                    return .{
                        .success = false,
                        .message = try self.allocator.dupe(u8, ctx.recommendation),
                        .duration_ms = 0,
                        .exit_code = 1,
                    };
                }
            } else |err| {
                self.log(.warn, "Experience consult failed: {}", .{err});
            }
        }

        // Build command for this link
        const cmd = try self.buildCommand(link, task);
        defer {
            for (cmd.argv) |arg| self.allocator.free(arg);
            self.allocator.free(cmd.argv);
        }

        // P10: Execute with timeout handler
        const timeout_result = if (self.timeout_handler) |th|
            th.executeProcessWithTimeout(cmd.argv, link.timeout_ms) catch |err| brk: {
                self.log(.warn, "Timeout handler failed, using direct execution: {}", .{err});
                break :brk null;
            }
        else
            null;

        var result = LinkResult{
            .success = false,
            .duration_ms = 0,
            .exit_code = 1,
        };

        if (timeout_result) |tr| {
            result.success = tr.exit_code == 0 and !tr.timed_out;
            result.duration_ms = tr.duration_ms;
            result.exit_code = tr.exit_code;

            // P11: Only assign non-empty strings, keep null for empty
            if (tr.stdout.len > 0) {
                result.stdout = tr.stdout;
            }
            if (tr.stderr.len > 0) {
                result.stderr = tr.stderr;
            }

            if (tr.timed_out) {
                result.message = try std.fmt.allocPrint(self.allocator, "Timeout after {d}ms", .{tr.duration_ms});
            } else {
                result.message = if (result.success)
                    try self.allocator.dupe(u8, "Success")
                else
                    try std.fmt.allocPrint(self.allocator, "Exit code {d}", .{tr.exit_code});
            }
        } else {
            // Fallback: direct execution
            const start_time = std.time.nanoTimestamp();
            var child = std.process.Child.init(cmd.argv, self.allocator);
            try child.spawn();

            const wait_result = child.wait() catch |err| {
                return .{
                    .success = false,
                    .exit_code = 1,
                    .message = try std.fmt.allocPrint(self.allocator, "Process wait failed: {}", .{err}),
                    .duration_ms = 0,
                };
            };

            const end_time = std.time.nanoTimestamp();
            const elapsed_ns = end_time - start_time;
            result.duration_ms = @as(u64, @intFromFloat(@divTrunc(@as(f128, @floatFromInt(elapsed_ns)), 1_000_000)));

            switch (wait_result) {
                .Exited => |code| {
                    result.success = code == 0;
                    result.exit_code = code;
                    result.message = try std.fmt.allocPrint(self.allocator, "Exit {d}", .{code});
                },
                .Signal => |sig| {
                    result.exit_code = 128 + @as(u8, @truncate(sig));
                    result.message = try std.fmt.allocPrint(self.allocator, "Signal {d}", .{sig});
                },
                else => {
                    result.message = try self.allocator.dupe(u8, "Unknown termination");
                },
            }
        }

        // P10: Record failure in experience engine
        if (!result.success) {
            if (self.experience != null) {
                const task_name = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ task, link.name });
                defer self.allocator.free(task_name);

                // P10: Simplified experience logging
                self.log(.warn, "MNL: Recording failure for '{s}'", .{task_name});
            }
        }

        if (result.success) {
            self.log(.info, "✅ [{d}] {s} completed in {}ms", .{ link.id, link.name, result.duration_ms });
        } else {
            const msg = result.message orelse "(no message)";
            self.log(.err, "❌ [{d}] {s} failed: {s}", .{ link.id, link.name, msg });
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

        // Parse command into argv (simple implementation)
        // Just split on space and return
        var part_count: usize = 0;
        var space_count: usize = 0;
        for (link_command) |c| {
            if (c == ' ') space_count += 1;
        }
        part_count = space_count + 1;

        var argv = try self.allocator.alloc([]const u8, part_count);
        var i: usize = 0;
        var iter = std.mem.tokenizeScalar(u8, link_command, ' ');
        while (iter.next()) |part| {
            argv[i] = try self.allocator.dupe(u8, part);
            i += 1;
        }

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

    /// Save checkpoint to disk (P11: Full JSON serialization)
    pub fn saveCheckpoint(self: *GoldenChain, task: []const u8) !void {
        const timestamp = std.time.timestamp();

        // Create checkpoint filename
        const filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/checkpoint_{d}.json",
            .{ self.checkpoint_dir, timestamp },
        );
        defer self.allocator.free(filename);

        // P11: Use std.json.stringify for automatic escaping
        const checkpoint_data = CheckpointData{
            .version = "5.2",
            .task = task,
            .current_link = self.state.current_link,
            .completed_links = self.state.completed_links,
            .total_cost_ms = self.state.total_cost_ms,
            .timestamp = timestamp,
            .results = self.results.items,
        };

        // Serialize to JSON
        const json_str = try std.json.Stringify.valueAlloc(self.allocator, checkpoint_data, .{});
        defer self.allocator.free(json_str);

        // Write to file
        try std.fs.cwd().writeFile(.{
            .sub_path = filename,
            .data = json_str,
        });

        self.log(.info, "💾 Checkpoint saved to {s}", .{filename});

        // Update last_checkpoint
        if (self.state.last_checkpoint) |old| self.allocator.free(old);
        self.state.last_checkpoint = try self.allocator.dupe(u8, filename);
    }

    /// Load checkpoint from disk (P11: Full JSON parsing)
    pub fn loadCheckpoint(self: *GoldenChain, filename: []const u8) !CheckpointData {
        self.log(.info, "📂 Loading checkpoint from {s}", .{filename});

        // Read checkpoint file
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024); // Max 1MB
        defer self.allocator.free(content);

        // P11: Parse JSON using std.json.parseFromSlice
        const parsed = try std.json.parseFromSlice(CheckpointData, self.allocator, content, .{});
        defer parsed.deinit();

        const cp_data = parsed.value;

        self.log(.info, "📂 Checkpoint loaded: link {d}, {d} results", .{
            cp_data.current_link, cp_data.results.len
        });

        return cp_data;
    }

    /// Resume from checkpoint (P11: Full state restoration)
    pub fn resumeFromCheckpoint(self: *GoldenChain, checkpoint_id: []const u8, task: []const u8) !u8 {
        const checkpoint_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/checkpoint_{s}.json",
            .{ self.checkpoint_dir, checkpoint_id },
        );
        defer self.allocator.free(checkpoint_path);

        const cp = try self.loadCheckpoint(checkpoint_path);

        // P11: Restore state from checkpoint
        self.state.current_link = cp.current_link;
        self.state.completed_links = cp.completed_links;
        self.state.total_cost_ms = cp.total_cost_ms;

        // P11: Copy results from checkpoint (deep copy nullable strings)
        self.results.clearRetainingCapacity();
        for (cp.results) |r| {
            var result = LinkResult{
                .success = r.success,
                .message = null,
                .duration_ms = r.duration_ms,
                .exit_code = r.exit_code,
                .stdout = null,
                .stderr = null,
            };

            // Deep copy message string
            if (r.message) |msg| {
                result.message = try self.allocator.dupe(u8, msg);
            }
            // Deep copy stdout
            if (r.stdout) |out| {
                result.stdout = try self.allocator.dupe(u8, out);
            }
            // Deep copy stderr
            if (r.stderr) |err_msg| {
                result.stderr = try self.allocator.dupe(u8, err_msg);
            }

            try self.results.append(self.allocator, result);
        }

        self.log(.info, "▶️ Resuming from link {d} with {d} previous results", .{
            cp.current_link, cp.results.len
        });

        // Calculate start link index (0-based)
        const start_link_idx = if (cp.current_link == 0) 0 else cp.current_link - 1;

        // Continue execution from checkpoint link
        return self.runFrom(task, start_link_idx);
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

        std.debug.print("\n🔗 Golden Chain v5.2 — 28 links with neuroanatomical mapping (P10)\n", .{});

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

/// CLI wrapper for golden chain command (module-level function)
pub fn runGoldenChainCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    if (args.len < 1) {
        std.debug.print("Usage: tri golden-chain <run|resume|links> [args]\n", .{});
        std.debug.print("  run     - Execute full chain\n", .{});
        std.debug.print("  resume  - Resume from checkpoint\n", .{});
        std.debug.print("  links   - Show available links\n", .{});
        return 1;
    }

    const subcommand = args[0];
    const command_args = if (args.len > 1) args[1..] else ([_][]const u8{})[0..];

    if (std.mem.eql(u8, subcommand, "run")) {
        return try runCommand(allocator, command_args);
    } else if (std.mem.eql(u8, subcommand, "resume")) {
        return try resumeCommand(allocator, command_args);
    } else if (std.mem.eql(u8, subcommand, "links")) {
        return try linksCommand(allocator, command_args);
    } else {
        std.debug.print("Unknown golden-chain subcommand: {s}\n", .{subcommand});
        return 1;
    }
}

fn runCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    var chain = try GoldenChain.init(allocator);
    defer chain.deinit();
    // Join args into a single task string
    const task = if (args.len > 0) args[0] else "Execute Golden Chain";
    return try chain.run(task);
}

fn resumeCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    var chain = try GoldenChain.init(allocator);
    defer chain.deinit();
    const checkpoint_id = if (args.len > 0) args[0] else "latest";
    // Pass remaining args as task string
    const task = if (args.len > 1) args[1] else "Resume Golden Chain";
    return try chain.resumeFromCheckpoint(checkpoint_id, task);
}

fn linksCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    _ = allocator;
    _ = args;
    std.debug.print("Available Links (28 total):\n", .{});
    std.debug.print("  ID   Role          Brain Zone    Link Name\n", .{});
    std.debug.print("  ────────────────────────────────────────\n", .{});
    return 0;
}
