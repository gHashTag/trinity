const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut();

    const allocator = std.heap.page_allocator;

    if (std.fs.cwd().readFileAlloc(allocator, ".trinity/farm/w7v2_snapshot.json", 1_000_000)) |content| {
        defer allocator.free(content);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, content, .{}) catch |err| {
            try stdout.print("Error loading snapshot: {s}\n", .{@errorName(err)});
            return;
        };
        defer parsed.deinit();

        const obj = parsed.value.object;
        var worker_count: usize = 0;
        var total_ppl: f64 = 0;
        var min_ppl: f64 = std.math.floatMax(f64);
        var max_ppl: f64 = 0;

        var iter = obj.iterator();
        while (iter.next()) |kv| {
            const worker = kv.value_ptr.*;
            if (worker.object.get("ppl")) |ppl| {
                total_ppl += ppl.float;
                min_ppl = @min(min_ppl, ppl.float);
                max_ppl = @max(max_ppl, ppl.float);
                worker_count += 1;
            }
        }

        if (worker_count > 0) {
            try stdout.print("Workers: {d}\n", .{worker_count});
            try stdout.print("Avg PPL: {d:.2}\n", .{total_ppl / @as(f32, @floatFromInt(worker_count))});
            try stdout.print("Min PPL: {d:.2}\n", .{min_ppl});
            try stdout.print("Max PPL: {d:.2}\n", .{max_ppl});
        }
    } else |_| {
        try stdout.print("Not found: w7v2_snapshot.json\n", .{});
    }
}
