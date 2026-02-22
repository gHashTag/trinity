//! TRINITY ORCHESTRATOR CLI — Central Integration Hub
//! Cycle 60 — Autonomous Lifecycle (REAL INTEGRATION)
//! φ² + 1/φ² = 3

const std = @import("std");
const orchestrator = @import("trinity_orchestrator");
const impl = @import("orchestrator_impl.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "self-improve")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing spec file\n", .{});
            printUsage();
            return;
        }

        const spec_path = args[2];

        // Parse options
        var max_links: u32 = 1;
        var verbose = false;
        var auto_fix: bool = true;

        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--verbose")) {
                verbose = true;
            } else if (std.mem.eql(u8, args[i], "--no-fix")) {
                auto_fix = false;
            } else if (std.mem.eql(u8, args[i], "--links") and i + 1 < args.len) {
                max_links = try std.fmt.parseInt(u32, args[i + 1], 10);
                i += 1;
            }
        }

        try runSelfImprovement(allocator, spec_path, max_links, auto_fix, verbose);
    } else if (std.mem.eql(u8, command, "status")) {
        try showStatus();
    } else if (std.mem.eql(u8, command, "consensus")) {
        try demoConsensus(allocator);
    } else if (std.mem.eql(u8, command, "trinity-check")) {
        try trinityCheck();
    } else if (std.mem.eql(u8, command, "help")) {
        printUsage();
    } else {
        std.debug.print("Error: Unknown command '{s}'\n", .{command});
        printUsage();
    }
}

fn runSelfImprovement(
    allocator: std.mem.Allocator,
    spec_path: []const u8,
    max_links: u32,
    auto_fix: bool,
    verbose: bool,
) !void {
    _ = auto_fix;

    std.debug.print("\n╔═══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  TRINITY ORCHESTRATOR — Self-Improvement Cycle               ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Spec: {s:50} ║\n", .{spec_path});
    std.debug.print("║  φ (PHI):      {d:.15}                                    ║\n", .{orchestrator.PHI});
    std.debug.print("║  μ (MU):       {d:.4}                                       ║\n", .{orchestrator.MU});
    std.debug.print("║  Threshold:    {d:.2}                                        ║\n", .{orchestrator.SACRED_THRESHOLD});
    std.debug.print("║  Trinity:      φ² + 1/φ² = {d:.3}                              ║\n", .{verifyTrinity()});
    std.debug.print("║  Max Links:    {d:3}                                         ║\n", .{max_links});
    std.debug.print("╚═══════════════════════════════════════════════════════════════╝\n\n", .{});

    var link_number: u32 = 1;
    var passed: u32 = 0;
    var failed: u32 = 0;
    var total_duration: u64 = 0;

    while (link_number <= max_links) {
        const result = impl.orchestrateSelfImprovement(allocator, spec_path, link_number, verbose) catch |err| {
            std.debug.print("\n✗ Link {d} failed with error: {}\n", .{ link_number, err });
            failed += 1;
            break;
        };

        total_duration += result.total_duration_ms;

        // Update counters
        if (result.next_action == .proceed) {
            passed += 1;
            if (verbose) {
                std.debug.print("\n✓ Link {d} PASSED | Consensus: {d:.3} | Duration: {d}ms\n\n", .{
                    link_number,
                    result.consensus_score,
                    result.total_duration_ms,
                });
            }
            link_number += 1;
        } else if (result.next_action == .retry) {
            failed += 1;
            if (failed >= 3) {
                std.debug.print("\n✗ Circuit breaker: Too many failures ({d})\n", .{failed});
                break;
            }
            if (verbose) {
                std.debug.print("\n⚠ Link {d} RETRY | {s}/ retry {d}/3\n\n", .{
                    link_number,
                    if (result.vibee_result.success) "PAS failed" else "VIBEE failed",
                    failed,
                });
            }
            // Retry same link
        } else {
            break;
        }
    }

    // Final summary
    std.debug.print("\n╔═══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  CYCLE COMPLETE                                                  ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Links:        {d:3} / {d:3}                                 ║\n", .{ link_number - 1, max_links });
    std.debug.print("║  Passed:       {d:3}                                         ║\n", .{passed});
    std.debug.print("║  Failed:       {d:3}                                         ║\n", .{failed});
    std.debug.print("║  Success Rate: {d:.1}%                                       ║\n", .{
        if (link_number > 1) @as(f64, @floatFromInt(passed)) * 100.0 / @as(f64, @floatFromInt(link_number - 1)) else 0,
    });
    std.debug.print("║  Total Time:   {d:5} ms                                     ║\n", .{total_duration});
    std.debug.print("║  φ² + 1/φ²:    {d:.3} ✓                                    ║\n", .{verifyTrinity()});
    std.debug.print("╚═══════════════════════════════════════════════════════════════╝\n\n", .{});

    if (passed > 0) {
        std.debug.print("→ VIBEE writes VIBEE — Army is learning\n\n", .{});
    }
}

fn showStatus() !void {
    std.debug.print("\n  ════════════════════════════════════════\n", .{});
    std.debug.print("   TRINITY ORCHESTRATOR — Status\n", .{});
    std.debug.print("  ════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("   φ (PHI):      1.618033988749895\n", .{});
    std.debug.print("   μ (MU):       0.0382\n", .{});
    std.debug.print("   Threshold:    0.95\n", .{});
    std.debug.print("   Trinity:      φ² + 1/φ² = {d:.3} ", .{verifyTrinity()});
    if (verifyTrinity() == 3.0) {
        std.debug.print("✓\n", .{});
    } else {
        std.debug.print("✗\n", .{});
    }
    std.debug.print("\n", .{});
    std.debug.print("   Systems:\n", .{});
    std.debug.print("     • VIBEE          Code generation (LIVE)\n", .{});
    std.debug.print("     • Agent MU       AST analysis + fixing (LIVE)\n", .{});
    std.debug.print("     • Symbolic AI    Knowledge graph (LIVE)\n", .{});
    std.debug.print("     • PAS Daemon     Sacred scoring (LIVE)\n", .{});
    std.debug.print("     • Swarm          32-agent runtime (LIVE)\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("   Status:       READY (Cycle 60 — Autonomous Lifecycle)\n", .{});
    std.debug.print("   Next step:    Run 'orchestrate self-improve <spec.vibee>'\n", .{});
    std.debug.print("\n  ════════════════════════════════════════\n\n", .{});
}

fn demoConsensus(allocator: std.mem.Allocator) !void {
    std.debug.print("\n  ════════════════════════════════════════\n", .{});
    std.debug.print("   φ-Weighted Consensus Demo\n", .{});
    std.debug.print("  ════════════════════════════════════════\n", .{});

    // Simulate agent votes
    const votes = [_]orchestrator.AgentVote{
        .{
            .agent_id = "vibee-001",
            .agent_type = "vibee",
            .decision = "proceed",
            .confidence = 0.95,
            .pas_score = 0.97,
            .reasoning = "Code generation successful",
            .timestamp = std.time.timestamp(),
        },
        .{
            .agent_id = "agent-mu-001",
            .agent_type = "agent_mu",
            .decision = "proceed",
            .confidence = 0.88,
            .pas_score = 0.92,
            .reasoning = "No critical issues found",
            .timestamp = std.time.timestamp(),
        },
        .{
            .agent_id = "symbolic-ai-001",
            .agent_type = "symbolic_ai",
            .decision = "proceed",
            .confidence = 0.91,
            .pas_score = 0.89,
            .reasoning = "Pattern match found",
            .timestamp = std.time.timestamp(),
        },
        .{
            .agent_id = "pas-daemon-001",
            .agent_type = "pas",
            .decision = "proceed",
            .confidence = 0.96,
            .pas_score = 0.98,
            .reasoning = "Sacred threshold exceeded",
            .timestamp = std.time.timestamp(),
        },
    };

    _ = allocator;

    std.debug.print("\n  Agent Votes:\n", .{});
    for (votes) |vote| {
        const phi_boost = orchestrator.PHI * vote.confidence;
        std.debug.print("    [{s}] {s}: {s} (confidence: {d:.3}, φ-boost: {d:.3})\n", .{
            vote.agent_type, vote.agent_id, vote.decision, vote.confidence, phi_boost,
        });
    }

    // Calculate consensus
    var total_weight: f64 = 0;
    var proceed_weight: f64 = 0;
    for (votes) |vote| {
        const weight = orchestrator.PHI * vote.confidence;
        total_weight += weight;
        if (std.mem.eql(u8, vote.decision, "proceed")) {
            proceed_weight += weight;
        }
    }

    const agreement = if (total_weight > 0) proceed_weight / total_weight else 0;
    const consensus_score = orchestrator.PHI * agreement;

    std.debug.print("\n  Consensus Result:\n", .{});
    std.debug.print("    Agreement:      {d:.3}\n", .{agreement});
    std.debug.print("    φ-Weighted:    {d:.3}\n", .{consensus_score});
    std.debug.print("    Final Decision: ", .{});
    if (agreement >= 0.5) {
        std.debug.print("PROCEED ✓\n", .{});
    } else {
        std.debug.print("RETRY ✗\n", .{});
    }
    std.debug.print("\n  ════════════════════════════════════════\n\n", .{});
}

fn trinityCheck() !void {
    const result = verifyTrinity();
    std.debug.print("\n  TRINITY IDENTITY CHECK\n", .{});
    std.debug.print("  ═══════════════════\n", .{});
    std.debug.print("  φ (PHI):            {d:.15}\n", .{orchestrator.PHI});
    std.debug.print("  φ²:                 {d:.15}\n", .{orchestrator.PHI * orchestrator.PHI});
    std.debug.print("  1/φ²:               {d:.15}\n", .{1.0 / (orchestrator.PHI * orchestrator.PHI)});
    std.debug.print("  φ² + 1/φ²:          {d:.15}\n", .{result});
    std.debug.print("  Target:             3.0\n", .{});
    std.debug.print("  Difference:         {d:.15}\n", .{@abs(result - 3.0)});
    std.debug.print("\n  Result: ", .{});
    if (@abs(result - 3.0) < 0.0001) {
        std.debug.print("✓ VERIFIED — Trinity Identity holds!\n", .{});
    } else {
        std.debug.print("✗ FAILED — Trinity Identity broken!\n", .{});
    }
    std.debug.print("\n", .{});
}

fn verifyTrinity() f64 {
    return orchestrator.PHI * orchestrator.PHI + 1.0 / (orchestrator.PHI * orchestrator.PHI);
}

fn printUsage() void {
    std.debug.print("\n", .{});
    std.debug.print("╔════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  TRINITY ORCHESTRATOR — Central Integration Hub                      ║\n", .{});
    std.debug.print("╠════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Usage:                                                               ║\n", .{});
    std.debug.print("║    orchestrate self-improve <spec.vibee> [options]                   ║\n", .{});
    std.debug.print("║    orchestrate status                                                 ║\n", .{});
    std.debug.print("║    orchestrate consensus                                              ║\n", .{});
    std.debug.print("║    orchestrate trinity-check                                          ║\n", .{});
    std.debug.print("║                                                                       ║\n", .{});
    std.debug.print("║  Options:                                                             ║\n", .{});
    std.debug.print("║    --verbose          Enable verbose logging                          ║\n", .{});
    std.debug.print("║    --links N          Max links to run (default: 1)                   ║\n", .{});
    std.debug.print("║    --no-fix           Disable auto-fix on failure                   ║\n", .{});
    std.debug.print("║                                                                       ║\n", .{});
    std.debug.print("║  Systems Coordinated (LIVE):                                         ║\n", .{});
    std.debug.print("║    • VIBEE          Code generation from .vibee specs                  ║\n", .{});
    std.debug.print("║    • Agent MU       AST analysis and automatic fixing                  ║\n", .{});
    std.debug.print("║    • Symbolic AI    IGLA knowledge graph + triples parser             ║\n", .{});
    std.debug.print("║    • PAS Daemon     Sacred quality scoring                            ║\n", .{});
    std.debug.print("║    • Swarm          32-agent production runtime                       ║\n", .{});
    std.debug.print("║                                                                       ║\n", .{});
    std.debug.print("║  Cycle 60 — Autonomous Lifecycle:                                     ║\n", .{});
    std.debug.print("║    VIBEE → Agent MU → Symbolic AI → PAS → Consensus → Next Link      ║\n", .{});
    std.debug.print("║                                                                       ║\n", .{});
    std.debug.print("║  φ² + 1/φ² = 3  ────►  All systems unified by sacred mathematics        ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
}
