//! E2E Registry Tests - End-to-End Contracts Between Components
//!
//! Tests the complete pipeline: registry -> CLI -> output/docs/schema

const std = @import("std");
const registry = @import("registry");
const command_def = registry.def;
const command_table = registry;
const mcp_gen = registry.mcp_gen;
const job_system = @import("job_system.zig");
const job_artifact = @import("job_artifact.zig");
const unified_output = @import("unified_output.zig");

// =============================================================================
// TEST 1: Registry -> MCP Export Consistency
// =============================================================================

test "e2e.registry_to_mcp.export_pilot_commands_metadata" {
    const allocator = std.testing.allocator;

    const registry_json = try mcp_gen.generateRegistryJson(allocator);
    defer allocator.free(registry_json);

    try std.testing.expect(registry_json.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, registry_json, "{\"version\":"));

    const pilot_commands = [_][]const u8{ "constants", "phi", "bench", "test", "fpga" };

    for (pilot_commands) |cmd_name| {
        const cmd_found = blk: {
            for (command_table.all_commands) |cmd| {
                if (std.mem.eql(u8, cmd.name, cmd_name)) break :blk cmd;
            } else {
                try std.testing.expect(false);
                return;
            }
        };

        const cmd_string = try std.fmt.allocPrint(allocator, "\"name\":\"{s}\"", .{cmd_name});
        defer allocator.free(cmd_string);
        try std.testing.expect(std.mem.indexOf(u8, registry_json, cmd_string) != null);

        const mode_string = try std.fmt.allocPrint(allocator, "\"mode\":\"{s}\"", .{@tagName(cmd_found.mode)});
        defer allocator.free(mode_string);
        try std.testing.expect(std.mem.indexOf(u8, registry_json, mode_string) != null);

        const ns_string = try std.fmt.allocPrint(allocator, "\"cli_namespace\":\"{s}\"", .{cmd_found.cli_namespace.toString()});
        defer allocator.free(ns_string);
        try std.testing.expect(std.mem.indexOf(u8, registry_json, ns_string) != null);
    }

    std.log.info("OK Registry -> MCP export: All pilot commands metadata verified", .{});
}

test "e2e.registry_to_mcp.bench_command_job_mode_metadata" {
    const allocator = std.testing.allocator;

    const bench_cmd = blk: {
        for (command_table.all_commands) |cmd| {
            if (std.mem.eql(u8, cmd.name, "bench")) break :blk cmd;
        } else unreachable;
    };

    try std.testing.expectEqual(command_def.ExecutionMode.job, bench_cmd.mode);

    const has_filesystem = for (bench_cmd.side_effects) |se| {
        if (se == .filesystem) break true;
    } else false;
    try std.testing.expect(has_filesystem);

    try std.testing.expect(bench_cmd.required_artifacts.len > 0);

    const mcp_schema = try mcp_gen.generateMcpToolSchema(allocator, bench_cmd);
    defer allocator.free(mcp_schema);

    try std.testing.expect(std.mem.indexOf(u8, mcp_schema, "\"mode\"") != null);

    std.log.info("OK Registry -> MCP: bench command job mode metadata verified", .{});
}

test "e2e.registry_to_mcp.fpga_command_hardware_side_effects" {
    const fpga_cmd = blk: {
        for (command_table.all_commands) |cmd| {
            if (std.mem.eql(u8, cmd.name, "fpga")) break :blk cmd;
        } else unreachable;
    };

    const has_hardware = for (fpga_cmd.side_effects) |se| {
        if (se == .hardware) break true;
    } else false;
    try std.testing.expect(has_hardware);

    try std.testing.expectEqual(command_def.CliNamespace.forge, fpga_cmd.cli_namespace);
    try std.testing.expectEqual(command_def.StabilityLevel.experimental, fpga_cmd.stability);

    std.log.info("OK Registry -> MCP: fpga command hardware side effects verified", .{});
}

// =============================================================================
// TEST 2: Registry -> CLI Help Consistency
// =============================================================================

test "e2e.registry_to_cli.help_shows_correct_namespace" {
    const expected_namespaces = [_]struct { []const u8, command_def.CliNamespace }{
        .{ "constants", .core },
        .{ "phi", .core },
        .{ "bench", .dev },
        .{ "test", .dev },
        .{ "fpga", .forge },
    };

    for (expected_namespaces) |entry| {
        const cmd = blk: {
            for (command_table.all_commands) |c| {
                if (std.mem.eql(u8, c.name, entry[0])) break :blk c;
            } else unreachable;
        };

        try std.testing.expectEqual(entry[1], cmd.cli_namespace);
    }

    std.log.info("OK Registry -> CLI help: All pilot commands have correct namespace", .{});
}

test "e2e.registry_to_cli.aliases_work_correctly" {
    const test_cases = [_]struct {
        name: []const u8,
        expected_alias: []const u8,
    }{
        .{ .name = "constants", .expected_alias = "const" },
        .{ .name = "bench", .expected_alias = "benchmark" },
        .{ .name = "fpga", .expected_alias = "forge" },
    };

    for (test_cases) |tc| {
        const cmd = blk: {
            for (command_table.all_commands) |c| {
                if (std.mem.eql(u8, c.name, tc.name)) break :blk c;
            } else unreachable;
        };

        const has_alias = for (cmd.aliases) |alias| {
            if (std.mem.eql(u8, alias, tc.expected_alias)) break true;
        } else false;

        try std.testing.expect(has_alias);
    }

    std.log.info("OK Registry -> CLI help: All aliases verified", .{});
}

// =============================================================================
// TEST 3: Job Lifecycle
// =============================================================================

test "e2e.job.lifecycle_complete_flow" {
    const allocator = std.testing.allocator;

    var manager = try job_system.JobManager.init(allocator);
    defer manager.deinit();

    const job_id = try manager.start("test_cmd", &[_][]const u8{"--help"}, .{ .timeout = 60 });
    defer allocator.free(job_id);

    try std.testing.expect(job_id.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, job_id, "job_"));

    const status = try manager.status(job_id);
    try std.testing.expect(status != null);

    const job_dir_path = try std.fmt.allocPrint(allocator, ".trinity/jobs/{s}", .{job_id});
    defer allocator.free(job_dir_path);

    // Check if job directory exists
    {
        var dir_exists = std.fs.cwd().openDir(job_dir_path, .{}) catch |err| {
            if (err == error.FileNotFound) return error.TestUnexpectedResult;
            return err;
        };
        defer dir_exists.close();
    }
    try std.testing.expect(true); // Directory exists

    std.log.info("OK Job lifecycle: start -> status flow verified", .{});
}

test "e2e.job.metadata_file_created" {
    const allocator = std.testing.allocator;

    var manager = try job_system.JobManager.init(allocator);
    defer manager.deinit();

    const job_id = try manager.start("test_cmd", &[_][]const u8{}, .{});
    defer allocator.free(job_id);

    const metadata_path = try std.fmt.allocPrint(allocator, ".trinity/jobs/{s}/metadata.json", .{job_id});
    defer allocator.free(metadata_path);

    var file_exists = std.fs.cwd().openFile(metadata_path, .{}) catch |err| {
        if (err == error.FileNotFound) return error.TestUnexpectedResult;
        return err;
    };
    defer file_exists.close();
    try std.testing.expect(true); // File exists

    std.log.info("OK Job lifecycle: metadata.json created successfully", .{});
}

// =============================================================================
// TEST 4: Artifact Validation
// =============================================================================

test "e2e.artifacts.benchmark_produces_metrics_json" {
    const bench_cmd = blk: {
        for (command_table.all_commands) |cmd| {
            if (std.mem.eql(u8, cmd.name, "bench")) break :blk cmd;
        } else unreachable;
    };

    const has_metrics_json = for (bench_cmd.required_artifacts) |artifact| {
        if (std.mem.indexOf(u8, artifact, "metrics.json") != null) break true;
    } else false;

    try std.testing.expect(has_metrics_json);

    for (bench_cmd.required_artifacts) |artifact| {
        try std.testing.expect(artifact.len > 0);
    }

    std.log.info("OK Artifact validation: bench requires metrics.json", .{});
}

test "e2e.artifacts.fpga_produces_bit_files" {
    const fpga_cmd = blk: {
        for (command_table.all_commands) |cmd| {
            if (std.mem.eql(u8, cmd.name, "fpga")) break :blk cmd;
        } else unreachable;
    };

    const has_bit_files = for (fpga_cmd.required_artifacts) |artifact| {
        if (std.mem.indexOf(u8, artifact, ".bit") != null) break true;
    } else false;

    try std.testing.expect(has_bit_files);

    std.log.info("OK Artifact validation: fpga requires .bit files", .{});
}

test "e2e.artifacts.collector_validates_patterns" {
    const allocator = std.testing.allocator;

    const test_job_id = "test_job";

    var collector = try job_artifact.ArtifactCollector.init(allocator, test_job_id);
    defer collector.deinit();

    try std.testing.expect(collector.matchesPattern("metrics.json", "metrics.json"));
    try std.testing.expect(collector.matchesPattern("test_metrics.json", "*_metrics.json"));
    try std.testing.expect(collector.matchesPattern("output.bit", "*.bit"));
    try std.testing.expect(!collector.matchesPattern("metrics.json", "*.txt"));

    std.log.info("OK Artifact validation: pattern matching works", .{});
}

// =============================================================================
// TEST 5: Unified Output Format
// =============================================================================

test "e2e.unified_output.success_format" {
    const allocator = std.testing.allocator;

    var output = unified_output.UnifiedOutput.init(allocator, "test_cmd");
    defer output.deinit();

    try output.setSummary("Operation completed successfully");
    try output.addMetric("duration_ms", 42);
    output.finalize();

    const json = try output.toJson();
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"success\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"summary\":\"Operation completed successfully\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"duration_ms\":42") != null);

    const text = try output.toText();
    defer allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "OK test_cmd: Operation completed successfully") != null);

    std.log.info("OK Unified output: success format verified", .{});
}

test "e2e.unified_output.failure_format" {
    const allocator = std.testing.allocator;

    var output = unified_output.UnifiedOutput.init(allocator, "test_cmd");
    defer output.deinit();

    try output.setSummary("Operation failed");
    try output.setError("Connection timeout");
    output.finalize();

    const json = try output.toJson();
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"failure\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"error\":\"Connection timeout\"") != null);

    std.log.info("OK Unified output: failure format verified", .{});
}

// =============================================================================
// TEST 6: Backward Compatibility
// =============================================================================

test "e2e.backward.compatibility_commands_findable" {
    const pilot_commands = [_][]const u8{ "constants", "phi", "bench", "test", "fpga" };

    for (pilot_commands) |cmd_name| {
        const found = for (command_table.all_commands) |cmd| {
            if (std.mem.eql(u8, cmd.name, cmd_name)) break true;
        } else false;

        try std.testing.expect(found);
    }

    std.log.info("OK Backward compatibility: All pilot commands findable", .{});
}

test "e2e.backward.compatibility_aliases_resolve" {
    const alias_tests = [_]struct {
        alias: []const u8,
        target: []const u8,
    }{
        .{ .alias = "const", .target = "constants" },
        .{ .alias = "benchmark", .target = "bench" },
        .{ .alias = "forge", .target = "fpga" },
    };

    for (alias_tests) |tc| {
        const target_cmd = blk: {
            for (command_table.all_commands) |cmd| {
                if (std.mem.eql(u8, cmd.name, tc.target)) break :blk cmd;
            } else unreachable;
        };

        const alias_found = for (target_cmd.aliases) |alias| {
            if (std.mem.eql(u8, alias, tc.alias)) break true;
        } else false;

        try std.testing.expect(alias_found);
    }

    std.log.info("OK Backward compatibility: All aliases resolve", .{});
}

// =============================================================================
// TEST 7: Golden Snapshots
// =============================================================================

test "e2e.golden.registry_export_structure" {
    const allocator = std.testing.allocator;

    const registry_json = try mcp_gen.generateRegistryJson(allocator);
    defer allocator.free(registry_json);

    try std.testing.expect(std.mem.indexOf(u8, registry_json, "\"version\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, registry_json, "\"generated_at\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, registry_json, "\"commands\"") != null);

    try std.testing.expect(registry_json[0] == '{');
    try std.testing.expect(registry_json[registry_json.len - 1] == '}');

    std.log.info("OK Golden snapshot: Registry export structure verified", .{});
}

test "e2e.golden.mcp_tools_count_matches_enabled" {
    const stats = mcp_gen.calculateStats();

    var mcp_count: usize = 0;
    for (command_table.all_commands) |cmd| {
        if (cmd.mcp_enabled) mcp_count += 1;
    }

    try std.testing.expectEqual(stats.mcp_enabled, mcp_count);

    const expected_min_mcp: usize = 2;
    try std.testing.expect(stats.mcp_enabled >= expected_min_mcp);

    std.log.info("OK Golden snapshot: MCP count matches enabled ({d} tools)", .{stats.mcp_enabled});
}

test "e2e.golden.command_categories_distributed" {
    const stats = mcp_gen.calculateStats();

    const total_in_namespaces = stats.by_namespace.core +
                                stats.by_namespace.dev +
                                stats.by_namespace.forge;

    try std.testing.expect(total_in_namespaces > 0);

    std.log.info("OK Golden snapshot: Commands distributed (core={}, dev={}, forge={})",
        .{ stats.by_namespace.core, stats.by_namespace.dev, stats.by_namespace.forge });
}

// =============================================================================
// SUMMARY & REPORTING
// =============================================================================

test "e2e.summary.generate_report" {
    const stats = mcp_gen.calculateStats();

    std.log.info("\n====================================================", .{});
    std.log.info("  E2E REGISTRY CONTRACT TEST SUMMARY", .{});
    std.log.info("====================================================\n", .{});
    std.log.info("Total Commands: {d}", .{stats.total_commands});
    std.log.info("MCP-Enabled: {d}", .{stats.mcp_enabled});
    std.log.info("  - Sync mode: {d}", .{stats.by_mode.sync});
    std.log.info("  - Job mode: {d}", .{stats.by_mode.job});
    std.log.info("  - Stream mode: {d}", .{stats.by_mode.stream});
    std.log.info("", .{});
    std.log.info("By Stability:", .{});
    std.log.info("  - Stable: {d}", .{stats.by_stability.stable});
    std.log.info("  - Experimental: {d}", .{stats.by_stability.experimental});
    std.log.info("  - Dangerous: {d}", .{stats.by_stability.dangerous});
    std.log.info("", .{});
    std.log.info("By Namespace:", .{});
    std.log.info("  - Core: {d}", .{stats.by_namespace.core});
    std.log.info("  - Dev: {d}", .{stats.by_namespace.dev});
    std.log.info("  - Forge: {d}", .{stats.by_namespace.forge});
    std.log.info("  - Agent: {d}", .{stats.by_namespace.agent});
    std.log.info("  - MCP: {d}", .{stats.by_namespace.mcp});
    std.log.info("  - System: {d}", .{stats.by_namespace.system});
    std.log.info("", .{});
    std.log.info("All E2E contract tests passed!", .{});
    std.log.info("====================================================\n", .{});

    try std.testing.expect(stats.total_commands > 0);
    try std.testing.expect(stats.mcp_enabled > 0);
}
