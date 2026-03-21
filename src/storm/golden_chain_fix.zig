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

        // Manual JSON serialization for Zig 0.15
        var json_buf = std.ArrayList(u8).init(self.allocator);
        defer json_buf.deinit(self.allocator);

        // Build JSON manually
        try json_buf.writer(self.allocator).print(
            \\{{"version":"5.2","task":"{s}","current_link":{d},"completed_links":{d},"total_cost_ms":{d},"timestamp":{d},"results":[
        , .{ task, self.state.current_link, self.state.completed_links, self.state.total_cost_ms, timestamp });

        for (self.results.items, 0..) |r, i| {
            if (i > 0) try json_buf.writer(self.allocator).writeAll(",");
            try json_buf.writer(self.allocator).print(
                \\{{"success":{},"message":{s},"duration_ms":{d},"exit_code":{d},"stdout":{s},"stderr":{s}}}
            , .{
                r.success,
                if (r.message) |m| std.json.fmtEscaped(m) else "(null)",
                r.duration_ms,
                r.exit_code,
                if (r.stdout) |o| std.json.fmtEscaped(o) else "(null)",
                if (r.stderr) |e| std.json.fmtEscaped(e) else "(null)",
            });
        }

        try json_buf.writer(self.allocator).writeAll("]}");

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
