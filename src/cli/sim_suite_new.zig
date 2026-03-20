        // Write CSV if output directory specified
    if (output_dir) |dir| {
        const csv_path = try std.fmt.allocPrint(allocator, "{s}/simulation_results.csv", .{dir});
        const csv_file = try std.fs.cwd().createFile(csv_path, .{});
        defer csv_file.close();
        defer allocator.free(csv_path);

        // Enhanced CSV format for visualization and analysis
        try csv_file.writeAll("step,scenario_id,ppl,diversity,alive,culled,byzantine,converged,energy_cost,seed_rate,kill_rate,ntp_weight,jepa_weight,nca_weight\n");

        // Write data from all scenarios (S1-S15)
        const s1_converged: u8 = if (s1.convergence_step != null) 1 else 0;
        for (s1.timeline) |entry| {
            const line = try std.fmt.allocPrint(allocator, "{d},{s},{d:.3},{d:.3},{d},{d},{d},{d},{d:.1},{d},{d},{d}\n", .{
                entry.step,          "S1",              entry.avg_ppl, entry.diversity,
                entry.alive_workers, s1.workers_culled, 0,             s1_converged,
                0,                   0.0,                 0.0,                 0.0,
                1.0,                 0.0,                 0.0,
            });
            try csv_file.writeAll(line);
            allocator.free(line);
        }

        const s2_status = if (s2.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s2.final_ppl});
        for (s2.timeline) |entry| {
            const line = try std.fmt.allocPrint(allocator, "{d},{s},{d:.3},{d:.3},{d},{d},{d},{d},{d},{d:.1},{d},{d},{d}\n", .{
                entry.step,          "S2",              entry.avg_ppl, entry.diversity,
                entry.alive_workers, s2.workers_culled, 0,             0,
                s2.energy_cost,      0.0,                 0.90,
                1.0,                 0.0,                 0.0,
            });
            try csv_file.writeAll(line);
            allocator.free(line);
        }

        const s3_converged: u8 = if (s3.convergence_step != null) 1 else 0;
        for (s3.timeline) |entry| {
            const line = try std.fmt.allocPrint(allocator, "{d},{s},{d:.3},{d:.3},{d},{d},{d},{d},{d},{d:.1},{d},{d},{d}\n", .{
                entry.step,          "S3",              entry.avg_ppl, entry.diversity,
                entry.alive_workers, s3.workers_culled, 0,             s3_converged,
                0,                   0.0,                 0.0,
            });
            try csv_file.writeAll(line);
            allocator.free(line);
        }

        for (s4.timeline) |entry| {
            const line = try std.fmt.allocPrint(allocator, "{d},{s},{d:.3},{d:.3},{d},{d},{d},{d},{d}:{d:.1},{d},{d}\n", .{
                entry.step,          "S4",              entry.avg_ppl,         entry.diversity,
                entry.alive_workers, s4.workers_culled, s4.byzantine_detected, 0,
                s4.energy_cost,      0.0,                 0.15,
                0.15,                0.15,
            });
            try csv_file.writeAll(line);
            allocator.free(line);
        }

        for (s5.timeline) |entry| {
            const line = try std.fmt.allocPrint(allocator, "{d},{s},{d:.3},{d:.3},{d},{d},{d},{d}:{d:.1},{d},{d}\n", .{
                entry.step,          "S5",              entry.avg_ppl,         entry.diversity,
                entry.alive_workers, s5.workers_culled, s5.byzantine_detected, 0,
                s5.energy_cost,      0.0,                 0.15,
                0.15,                0.15,
            });
            try csv_file.writeAll(line);
            allocator.free(line);
        }

        print("{s}CSV written to {s}{s}\n", .{ CYAN, RESET, csv_path });
    }
