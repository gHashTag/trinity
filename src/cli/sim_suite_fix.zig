        // ═══════════════════════════════════════════════════════════════════════
        // CSV EXPORT SECTION — Replacement for sim_suite.zig
        // ═══════════════════════════════════════════════════════════════════════════════════
        //
        // This replaces the CSV export section in src/cli/sim_suite.zig
        // starting from "// Write CSV if output directory specified"
        //
        // To apply: replace the entire CSV section in sim_suite.zig with this content
        // from "Write CSV if output directory specified" line to "print("...CSV written to..."
        //

    // Write CSV if output directory specified
    if (output_dir) |dir| {
        const csv_path = try std.fmt.allocPrint(allocator, "{s}/simulation_results.csv", .{dir});
        const csv_file = try std.fs.cwd().createFile(csv_path, .{});
        defer csv_file.close();
        defer allocator.free(csv_path);

        // Enhanced CSV format for visualization and analysis
        try csv_file.writeAll("step,scenario_id,ppl,diversity,alive,culled,byzantine,converged,energy_cost,seed_rate,kill_rate,ntp_weight,jepa_weight,nca_weight\n");

        // Write data from all scenarios
        const s1_converged: u8 = if (s1.convergence_step != null) 1 else 0;
        for (s1.timeline) |entry| {
            const line = try std.fmt.allocPrint(allocator, "{d},{s},{d:.3},{d:.3},{d},{d},{d},{d},{d},{d},{d:.1},{d},{d},{d},{d}\n", .{
                entry.step,          "S1",              entry.avg_ppl, entry.diversity,
                entry.alive_workers, s1.workers_culled, 0,             s1_converged,
                s1.energy_cost,      0.0,                 0.0,
                1.0,                 0.0,                 0.0,
                0.0,
            });
            try csv_file.writeAll(line);
            allocator.free(line);
        }

        print("{s}CSV written to {s}{s}\n", .{ CYAN, RESET, csv_path });
    }
