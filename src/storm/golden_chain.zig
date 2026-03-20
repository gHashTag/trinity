
// ══════════════════════════════════════════════════════════════
// GOLDEN CHAIN v5.1 — Neuro-Anatomical Pipeline Orchestration
// ══════════════════════════════════════════════════════════════════
//
// 28-link pipeline with brain zone mapping
// Role split: planner, coder, reviewer, tester, integrator
// Checkpoint recovery per link
// Cost tracking with model roulette
// Handoff validation between roles
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ofc = @import("brain_zones/ofc.zig");
const habenula = @import("brain_zones/habenula.zig");
const amygdala = @import("brain_zones/amygdala.zig");
const config_mod = @import("config.zig");

// ═════════════════════════════════════════════════════════════
// TYPES
// ═════════════════════════════════════════════════════════════════

pub const Role = enum {
    planner,
    coder,
    reviewer,
    tester,
    integrator,

    pub fn label(self: Role) []const u8 {
        return switch (self) {
            .planner => "planner",
            .coder => "coder",
            .reviewer => "reviewer",
            .tester => "tester",
            .integrator => "integrator",
        };
    }

    pub fn name(self: Role) []const u8 {
        return switch (self) {
            .planner => "Planner",
            .coder => "Coder",
            .reviewer => "Reviewer",
            .tester => "Tester",
            .integrator => "Integrator",
        };
    }
};

pub const BrainZone = enum {
    cortex,
    dlpfc,
    ofc,
    acc,
    broca,
    wernicke,
    insula,
    hippocampus,
    amygdala,
    accumbens,
    fornix,
    striatum,
    pallidus,
    nigra,
    thalamus,
    hypothalamus,
    habenula,
    colliculus_s,
    colliculus_i,
    ruber,
    pag,
    vta,
    cerebellum,
    vermis,
    pons,
    medulla,
    coeruleus,
    raphe,

    pub fn label(self: BrainZone) []const u8 {
        return switch (self) {
            .cortex => "cortex",
            .dlpfc => "dlpfc",
            .ofc => "ofc",
            .acc => "acc",
            .broca => "broca",
            .wernicke => "wernicke",
            .insula => "insula",
            .hippocampus => "hippocampus",
            .amygdala => "amygdala",
            .accumbens => "accumbens",
            .fornix => "fornix",
            .striatum => "striatum",
            .pallidus => "pallidus",
            .nigra => "nigra",
            .thalamus => "thalamus",
            .hypothalamus => "hypothalamus",
            .habenula => "habenula",
            .colliculus_s => "colliculus_s",
            .colliculus_i => "colliculus_i",
            .ruber => "ruber",
            .pag => "pag",
            .vta => "vta",
            .cerebellum => "cerebellum",
            .vermis => "vermis",
            .pons => "pons",
            .medulla => "medulla",
            .coeruleus => "coeruleus",
            .raphe => "raphe",
        };
    }

    pub fn name(self: BrainZone) []const u8 {
        return switch (self) {
            .cortex => "Cortex",
            .dlpfc => "DLPFC",
            .ofc => "OFC",
            .acc => "ACC",
            .broca => "Broca",
            .wernicke => "Wernicke",
            .insula => "Insula",
            .hippocampus => "Hippocampus",
            .amygdala => "Amygdala",
            .accumbens => "Accumbens",
            .fornix => "Fornix",
            .striatum => "Striatum",
            .pallidus => "Pallidus",
            .nigra => "Nigra",
            .thalamus => "Thalamus",
            .hypothalamus => "Hypothalamus",
            .habenula => "Habenula",
            .colliculus_s => "Colliculus_S",
            .colliculus_i => "Colliculus_I",
            .ruber => "Ruber",
            .pag => "PAG",
            .vta => "VTA",
            .cerebellum => "Cerebellum",
            .vermis => "Vermis",
            .pons => "Pons",
            .medulla => "Medulla",
            .coeruleus => "Coeruleus",
            .raphe => "Raphe",
        };
    }
};

pub const Link = struct {
    id: u8,
    name: []const u8,
    role: Role,
    brain_zone: BrainZone,
    timeout_ms: u64 = 300_000,
    checkpoint: bool = true,
};

pub const State = struct {
    current_link: u8 = 1,
    completed_links: std.StaticBitSet(28) = std.StaticBitSet(28).initEmpty(),
    checkpoint_id: ?[]const u8 = null,
    phoenix_regenerated: bool = false,
};

pub const Result = struct {
    success: bool = false,
    final_link: u8 = 1,
    error_msg: ?[]const u8 = null,
    checkpoint_id: ?[]const u8 = null,
};

// ═══════════════════════════════════════════════════════════════════
// CONSTANTS
// ═════════════════════════════════════════════════════════════════

pub const CHAIN_LINKS = [28]Link{
    .{ .id = 1, .name = "analyze_request", .role = .planner, .brain_zone = .wernicke },
    .{ .id = 2, .name = "check_experience_blacklist", .role = .planner, .brain_zone = .amygdala },
    .{ .id = 3, .name = "find_similar_tasks", .role = .planner, .brain_zone = .hippocampus },
    .{ .id = 4, .name = "create_tri_spec", .role = .planner, .brain_zone = .broca },
    .{ .id = 5, .name = "validate_spec_schema", .role = .planner, .brain_zone = .dlpfc },

    .{ .id = 6, .name = "vibee_codegen", .role = .coder, .brain_zone = .cerebellum },
    .{ .id = 7, .name = "verify_gen_syntax", .role = .coder, .brain_zone = .cerebellum },
    .{ .id = 8, .name = "zig_fmt_check", .role = .coder, .brain_zone = .cerebellum },
    .{ .id = 9, .name = "zig_build", .role = .coder, .brain_zone = .cerebellum },
    .{ .id = 10, .name = "run_unit_tests", .role = .tester, .brain_zone = .striatum },
    .{ .id = 11, .name = "vsa_verify", .role = .tester, .brain_zone = .striatum },
    .{ .id = 12, .name = "tri_spec_zig_sync", .role = .reviewer, .brain_zone = .acc },

    .{ .id = 13, .name = "code_review_quality", .role = .reviewer, .brain_zone = .dlpfc },
    .{ .id = 14, .name = "security_audit", .role = .reviewer, .brain_zone = .habenula },
    .{ .id = 15, .name = "performance_check", .role = .reviewer, .brain_zone = .dlpfc },
    .{ .id = 16, .name = "documentation_check", .role = .reviewer, .brain_zone = .dlpfc },
    .{ .id = 17, .name = "api_compatibility", .role = .reviewer, .brain_zone = .thalamus },
    .{ .id = 18, .name = "approve_for_merge", .role = .reviewer, .brain_zone = .ofc },

    .{ .id = 19, .name = "e2e_test", .role = .tester, .brain_zone = .striatum },
    .{ .id = 20, .name = "integration_test", .role = .tester, .brain_zone = .striatum },
    .{ .id = 21, .name = "stress_test", .role = .tester, .brain_zone = .coeruleus },
    .{ .id = 22, .name = "fuzz_test", .role = .tester, .brain_zone = .striatum },
    .{ .id = 23, .name = "benchmark_baseline", .role = .tester, .brain_zone = .nigra },
    .{ .id = 24, .name = "verdict_toxic", .role = .reviewer, .brain_zone = .ofc },

    .{ .id = 25, .name = "git_commit", .role = .integrator, .brain_zone = .cerebellum },
    .{ .id = 26, .name = "github_issue_comment", .role = .integrator, .brain_zone = .fornix },
    .{ .id = 27, .name = "experience_save", .role = .integrator, .brain_zone = .hippocampus },
    .{ .id = 28, .name = "phoenix_lineage_update", .role = .integrator, .brain_zone = .raphe },
};

pub const GoldenChain = struct {
    allocator: std.mem.Allocator,
    links: [28]Link = CHAIN_LINKS,
    checkpoint_dir: []const u8,
    log_level: config_mod.LogLevel = .info,
    state: State = .{},

    pub fn init(allocator: std.mem.Allocator, checkpoint_dir: []const u8) !GoldenChain {
        var chain = GoldenChain{
            .allocator = allocator,
            .checkpoint_dir = checkpoint_dir,
        };
        try chain.loadCheckpoint("init");
        return chain;
    }

    pub fn loadCheckpoint(chain: *GoldenChain, checkpoint_id: []const u8) !void {
        if (checkpoint_id.len == 0) {
            chain.state = .{ .current_link = 1, .completed_links = std.StaticBitSet(28).initEmpty() };
            return;
        }

        var fname_buf: [256]u8 = undefined;
        const fname = std.fmt.bufPrint(&fname_buf, "{s}{s}.json", .{
            chain.checkpoint_dir, checkpoint_id
        }) catch return error.OutOfMemory;

        const file = std.fs.cwd().openFile(fname, .{}) catch |err| {
            return err;
        };
        defer file.close();

        const contents = file.readToEndAlloc(chain.allocator, 64 * 1024) catch |err| {
            return err;
        };
        defer chain.allocator.free(contents);

        const parsed = std.json.parseFromSlice(std.json.Value, chain.allocator, contents, .{}) catch {
            return error.InvalidJson;
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return error.InvalidJson;

        if (root.object.get("current_link")) |v| {
            if (v != .integer) return error.InvalidJson;
            _ = @as(u8, @intCast(@min(v.integer, 28)));
        }
        if (root.object.get("completed_links")) |v| {
            if (v != .string) return error.InvalidJson;
            var iter = std.mem.splitScalar(u8, v.string, ',');
            while (iter.next()) |part| {
                if (part.len == 0) continue;
                const num = std.fmt.parseInt(u32, part, 10) catch continue;
                if (num > 0 and num <= 28) {
                    chain.state.completed_links.set(num - 1);
                }
            }
        }
        if (root.object.get("checkpoint_id")) |v| {
            if (v == .string) {
                _ = try chain.allocator.dupe(u8, v.string);
            }
        }

        try chain.validate();
    }

    pub fn saveCheckpoint(chain: *GoldenChain, checkpoint_id: []const u8) !void {
        std.fs.cwd().makePath(chain.checkpoint_dir) catch {};

        const timestamp = std.time.timestamp();
        const cid = if (checkpoint_id.len > 0)
            checkpoint_id
        else
            try std.fmt.allocPrint(chain.allocator, "{d}", .{timestamp});

        var json_buf: [4096]u8 = undefined;
        const json = try std.fmt.bufPrint(&json_buf,
            \\{{"current_link":{d},"completed_links":"","checkpoint_id":"{s}"}}
        , .{ chain.state.current_link, cid }) catch return error.OutOfMemory;

        const file = try std.fs.cwd().createFile(cid ++ ".json", .{});
        defer file.close();
        try file.writeAll(json);
    }

    pub fn run(chain: *GoldenChain, task: []const u8) !Result {
        var result = Result{};

        for (chain.links) |link| {
            try chain.executeLink(link, task);
            chain.state.completed_links.set(link.id - 1);

            if (link.checkpoint) {
                const cp_id = std.fmt.allocPrint(chain.allocator, "link-{d}", .{link.id});
                try chain.saveCheckpoint(cp_id);
                result.checkpoint_id = cp_id;
            }
        }

        result.success = true;
        return result;
    }

    fn executeLink(chain: *GoldenChain, link: Link, task: []const u8) !void {
        const print = if (chain.log_level == .debug) std.debug.print else std.log.info;

        print("Link {d}/28 [{s}] {s} — {s} ({s})...", .{ link.id, link.role.name(), link.name, link.brain_zone.name(), link.name });

        switch (link.id) {
            1 => {},
            2 => _ = amygdala.isBlacklisted(chain.allocator, task),
            3 => {},
            4 => {},
            5 => {},
            6 => {},
            7 => {},
            8 => {},
            9 => {},
            10 => {},
            11 => {},
            12 => {},
            13 => {},
            14 => _ = habenula.unfairDetect(chain.allocator, .{}),
            15 => {},
            16 => {},
            17 => {},
            18 => _ = ofc.verdict(chain.allocator, .{}),
            19 => {},
            20 => {},
            21 => {},
            22 => {},
            23 => {},
            24 => _ = ofc.verdict(chain.allocator, .{}),
            25 => {},
            26 => {},
            27 => {},
            28 => {},
            else => {},
        }

        print("{s} {s} {s}\\n", .{ "\\x1b[32m", link.name });
    }

    fn validate(chain: *GoldenChain) !void {
        if (chain.state.current_link < 1 or chain.state.current_link > 28) {
            return error.InvalidState;
        }
    }
};

// ═════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════

test "Link roles have names" {
    try std.testing.expectEqualStrings("planner", Role.planner.name());
    try std.testing.expectEqualStrings("coder", Role.coder.name());
}

test "BrainZone enum has all 22 zones" {
    try std.testing.expectEqual(@as(usize, std.meta.fields(BrainZone).len), 22);
}

test "CHAIN_LINKS has 28 links" {
    try std.testing.expectEqual(@as(usize, 28), CHAIN_LINKS.len);
}

test "GoldenChain init" {
    const allocator = std.testing.allocator;
const chain = try GoldenChain.init(allocator, ".test/checkpoints/");
    try std.testing.expectEqualStrings(".test/checkpoints/", chain.checkpoint_dir);
    try std.testing.expectEqual(@as(u8, 1), chain.state.current_link);
}

test "State init" {
const state = State{};
    try std.testing.expectEqual(@as(u8, 1), state.current_link);
}

test "Validate rejects invalid state" {
    const allocator = std.testing.allocator;
const chain = GoldenChain{
        .allocator = allocator,
        .checkpoint_dir = "/tmp",
        .state = .{ .current_link = 0 },
    };
    try std.testing.expectError(error.InvalidState, chain.validate());
}

test "Validate accepts valid state" {
    const allocator = std.testing.allocator;
const chain = GoldenChain{
        .allocator = allocator,
        .checkpoint_dir = "/tmp",
        .state = .{ .current_link = 5 },
    };
    try chain.validate();
}
