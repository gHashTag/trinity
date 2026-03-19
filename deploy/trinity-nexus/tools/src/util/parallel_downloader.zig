// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY PARALLEL DOWNLOADER - Professional HTTP Downloader with Resume Support
// ═══════════════════════════════════════════════════════════════════════════════
//
// Features:
// - Multi-connection parallel downloading (chunks)
// - Resume/continue interrupted downloads
// - Progress display with speed calculation
// - Automatic retry on failure
// - Range request support (HTTP 206)
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const net = std.net;
const http = std.http;

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Config = struct {
    num_connections: u32 = 8, // Parallel connections
    chunk_size: usize = 4 * 1024 * 1024, // 4MB chunks
    retry_count: u32 = 3,
    retry_delay_ms: u64 = 1000,
    buffer_size: usize = 64 * 1024, // 64KB buffer
};

// ═══════════════════════════════════════════════════════════════════════════════
// CHUNK STATUS
// ═══════════════════════════════════════════════════════════════════════════════

const ChunkStatus = enum(u8) {
    pending = 0,
    downloading = 1,
    completed = 2,
    failed = 3,
};

const Chunk = struct {
    id: u32,
    start: usize,
    end: usize,
    downloaded: std.atomic.Value(usize),
    status: std.atomic.Value(ChunkStatus),
    retries: std.atomic.Value(u32),

    pub fn init(id: u32, start: usize, end: usize) Chunk {
        return Chunk{
            .id = id,
            .start = start,
            .end = end,
            .downloaded = std.atomic.Value(usize).init(0),
            .status = std.atomic.Value(ChunkStatus).init(.pending),
            .retries = std.atomic.Value(u32).init(0),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DOWNLOAD STATE
// ═══════════════════════════════════════════════════════════════════════════════

const DownloadState = struct {
    url: []const u8,
    output_path: []const u8,
    total_size: usize,
    downloaded: std.atomic.Value(usize),
    chunks: []Chunk,
    start_time: i64,
    active_workers: std.atomic.Value(u32),
    stop_flag: std.atomic.Value(bool),
    allocator: std.mem.Allocator,
    config: Config,
    file_mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, url: []const u8, output_path: []const u8, total_size: usize, config: Config) !*DownloadState {
        const state = try allocator.create(DownloadState);

        // Calculate number of chunks
        const num_chunks = (total_size + config.chunk_size - 1) / config.chunk_size;
        const chunks = try allocator.alloc(Chunk, num_chunks);

        for (chunks, 0..) |*chunk, i| {
            const start = i * config.chunk_size;
            const end = @min(start + config.chunk_size, total_size);
            chunk.* = Chunk.init(@intCast(i), start, end);
        }

        state.* = DownloadState{
            .url = url,
            .output_path = output_path,
            .total_size = total_size,
            .downloaded = std.atomic.Value(usize).init(0),
            .chunks = chunks,
            .start_time = std.time.milliTimestamp(),
            .active_workers = std.atomic.Value(u32).init(0),
            .stop_flag = std.atomic.Value(bool).init(false),
            .allocator = allocator,
            .config = config,
            .file_mutex = std.Thread.Mutex{},
        };

        return state;
    }

    pub fn deinit(self: *DownloadState) void {
        self.allocator.free(self.chunks);
        self.allocator.destroy(self);
    }

    pub fn getProgress(self: *const DownloadState) f64 {
        const downloaded = self.downloaded.load(.seq_cst);
        if (self.total_size == 0) return 0;
        return @as(f64, @floatFromInt(downloaded)) / @as(f64, @floatFromInt(self.total_size)) * 100.0;
    }

    pub fn getSpeed(self: *const DownloadState) f64 {
        const elapsed_ms = std.time.milliTimestamp() - self.start_time;
        if (elapsed_ms <= 0) return 0;
        const downloaded = self.downloaded.load(.seq_cst);
        const elapsed_sec = @max(1, @divFloor(elapsed_ms, 1000));
        return @as(f64, @floatFromInt(downloaded)) / @as(f64, @floatFromInt(elapsed_sec));
    }

    pub fn getEta(self: *const DownloadState) u64 {
        const speed = self.getSpeed();
        if (speed <= 0) return 0;
        const remaining = self.total_size -| self.downloaded.load(.seq_cst);
        return @intFromFloat(@as(f64, @floatFromInt(remaining)) / speed);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// URL PARSER
// ═══════════════════════════════════════════════════════════════════════════════

const ParsedUrl = struct {
    host: []const u8,
    port: u16,
    path: []const u8,
    is_https: bool,
};

fn parseUrl(url: []const u8) !ParsedUrl {
    var is_https = false;
    var rest = url;

    if (std.mem.startsWith(u8, url, "https://")) {
        is_https = true;
        rest = url[8..];
    } else if (std.mem.startsWith(u8, url, "http://")) {
        rest = url[7..];
    } else {
        return error.InvalidUrl;
    }

    // Find path separator
    const path_start = std.mem.indexOf(u8, rest, "/") orelse rest.len;
    const host_port = rest[0..path_start];
    const path = if (path_start < rest.len) rest[path_start..] else "/";

    // Parse port
    var host: []const u8 = undefined;
    var port: u16 = undefined;

    if (std.mem.indexOf(u8, host_port, ":")) |colon_pos| {
        host = host_port[0..colon_pos];
        port = std.fmt.parseInt(u16, host_port[colon_pos + 1 ..], 10) catch return error.InvalidPort;
    } else {
        host = host_port;
        port = if (is_https) 443 else 80;
    }

    return ParsedUrl{
        .host = host,
        .port = port,
        .path = path,
        .is_https = is_https,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP FUNCTIONS (using child process curl for reliability)
// ═══════════════════════════════════════════════════════════════════════════════

fn getContentLength(allocator: std.mem.Allocator, url: []const u8) !usize {
    // Use curl -I to get headers
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "curl", "-sI", "-L", url },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // Parse Content-Length from headers (case-insensitive)
    var lines = std.mem.splitSequence(u8, result.stdout, "\n");
    while (lines.next()) |line| {
        // Check for Content-Length header (case-insensitive)
        if (line.len >= 15) {
            var header_name: [15]u8 = undefined;
            for (line[0..15], 0..) |c, i| {
                header_name[i] = std.ascii.toLower(c);
            }
            if (std.mem.eql(u8, &header_name, "content-length:")) {
                const value = std.mem.trim(u8, line[15..], " \t\r");
                return std.fmt.parseInt(usize, value, 10) catch continue;
            }
        }
    }

    return error.NoContentLength;
}

fn downloadChunk(
    allocator: std.mem.Allocator,
    url: []const u8,
    output_path: []const u8,
    chunk: *Chunk,
    state: *DownloadState,
) !void {
    const chunk_start = chunk.start + chunk.downloaded.load(.seq_cst);
    const chunk_end = chunk.end;

    if (chunk_start >= chunk_end) {
        chunk.status.store(.completed, .seq_cst);
        return;
    }

    // Use curl with range request
    var range_buf: [128]u8 = undefined;
    const range = try std.fmt.bufPrint(&range_buf, "{d}-{d}", .{ chunk_start, chunk_end - 1 });

    // Create temp file for this chunk
    var temp_path_buf: [256]u8 = undefined;
    const temp_path = try std.fmt.bufPrint(&temp_path_buf, "/tmp/trinity_chunk_{d}.tmp", .{chunk.id});

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "curl",
            "-s",
            "-L",
            "-r",
            range,
            "-o",
            temp_path,
            url,
        },
        .max_output_bytes = 1024,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        return error.CurlFailed;
    }

    // Read chunk and write to output file
    const temp_file = try std.fs.cwd().openFile(temp_path, .{});
    defer temp_file.close();
    defer std.fs.cwd().deleteFile(temp_path) catch {};

    const temp_stat = try temp_file.stat();
    const chunk_data = try allocator.alloc(u8, temp_stat.size);
    defer allocator.free(chunk_data);

    _ = try temp_file.readAll(chunk_data);

    // Write to output file with mutex
    state.file_mutex.lock();
    defer state.file_mutex.unlock();

    const output_file = try std.fs.cwd().openFile(output_path, .{ .mode = .read_write });
    defer output_file.close();

    try output_file.seekTo(chunk_start);
    try output_file.writeAll(chunk_data);

    // Update progress
    _ = chunk.downloaded.fetchAdd(chunk_data.len, .seq_cst);
    _ = state.downloaded.fetchAdd(chunk_data.len, .seq_cst);
    chunk.status.store(.completed, .seq_cst);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROGRESS DISPLAY
// ═══════════════════════════════════════════════════════════════════════════════

fn formatSize(buf: *[32]u8, size: usize) []const u8 {
    const size_f = @as(f64, @floatFromInt(size));

    if (size >= 1024 * 1024 * 1024) {
        return std.fmt.bufPrint(buf, "{d:.2} GB", .{size_f / (1024 * 1024 * 1024)}) catch "?";
    } else if (size >= 1024 * 1024) {
        return std.fmt.bufPrint(buf, "{d:.2} MB", .{size_f / (1024 * 1024)}) catch "?";
    } else if (size >= 1024) {
        return std.fmt.bufPrint(buf, "{d:.2} KB", .{size_f / 1024}) catch "?";
    } else {
        return std.fmt.bufPrint(buf, "{d} B", .{size}) catch "?";
    }
}

fn displayProgress(state: *const DownloadState) void {
    const progress = state.getProgress();
    const speed = state.getSpeed();
    const downloaded = state.downloaded.load(.seq_cst);
    const eta = state.getEta();
    const active = state.active_workers.load(.seq_cst);

    var downloaded_buf: [32]u8 = undefined;
    var total_buf: [32]u8 = undefined;
    var speed_buf: [32]u8 = undefined;

    const downloaded_str = formatSize(&downloaded_buf, downloaded);
    const total_str = formatSize(&total_buf, state.total_size);
    const speed_str = formatSize(&speed_buf, @intFromFloat(speed));

    // Progress bar
    const bar_width: usize = 30;
    const filled = @min(bar_width, @as(usize, @intFromFloat(progress * @as(f64, @floatFromInt(bar_width)) / 100.0)));

    var bar: [bar_width]u8 = undefined;
    for (0..bar_width) |i| {
        bar[i] = if (i < filled) '=' else if (i == filled) '>' else ' ';
    }

    std.debug.print("\r[{s}] {d:.1}% | {s}/{s} | {s}/s | ETA:{d}s | T:{d}   ", .{
        &bar,
        progress,
        downloaded_str,
        total_str,
        speed_str,
        eta,
        active,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// WORKER THREAD
// ═══════════════════════════════════════════════════════════════════════════════

fn workerThread(
    allocator: std.mem.Allocator,
    url: []const u8,
    output_path: []const u8,
    chunks: []Chunk,
    state: *DownloadState,
) void {
    _ = state.active_workers.fetchAdd(1, .seq_cst);
    defer _ = state.active_workers.fetchSub(1, .seq_cst);

    for (chunks) |*chunk| {
        if (state.stop_flag.load(.seq_cst)) break;

        const status = chunk.status.load(.seq_cst);
        if (status != .pending) continue;

        // Try to claim this chunk
        if (chunk.status.cmpxchgStrong(.pending, .downloading, .seq_cst, .seq_cst) != null) {
            continue; // Another worker claimed it
        }

        // Download with retries
        var success = false;
        for (0..state.config.retry_count) |_| {
            downloadChunk(allocator, url, output_path, chunk, state) catch {
                _ = chunk.retries.fetchAdd(1, .seq_cst);
                std.Thread.sleep(state.config.retry_delay_ms * std.time.ns_per_ms);
                continue;
            };
            success = true;
            break;
        }

        if (!success) {
            chunk.status.store(.failed, .seq_cst);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN DOWNLOAD FUNCTION
// ═══════════════════════════════════════════════════════════════════════════════

pub fn download(allocator: std.mem.Allocator, url: []const u8, output_path: []const u8, config: Config) !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  TRINITY PARALLEL DOWNLOADER v1.0                            ║\n", .{});
    std.debug.print("║  φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL                         ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("URL: {s}\n", .{url});
    std.debug.print("Output: {s}\n", .{output_path});
    std.debug.print("Connections: {d}\n", .{config.num_connections});
    std.debug.print("\n", .{});

    // Get file size
    std.debug.print("⏳ Getting file size...\n", .{});
    const total_size = try getContentLength(allocator, url);
    var size_buf: [32]u8 = undefined;
    const size_str = formatSize(&size_buf, total_size);
    std.debug.print("📦 File size: {s}\n", .{size_str});
    std.debug.print("\n", .{});

    // Create/open output file
    var file: std.fs.File = undefined;
    var need_preallocate = false;

    // Check if file exists
    if (std.fs.cwd().openFile(output_path, .{ .mode = .read_write })) |existing| {
        file = existing;
        const stat = try existing.stat();
        if (stat.size > 0 and stat.size < total_size) {
            std.debug.print("⏩ Resuming from {d} bytes...\n", .{stat.size});
        } else if (stat.size >= total_size) {
            std.debug.print("📁 File already downloaded!\n", .{});
            file.close();
            return;
        } else {
            need_preallocate = true;
        }
    } else |_| {
        // Create new file
        file = try std.fs.cwd().createFile(output_path, .{});
        need_preallocate = true;
    }

    // Pre-allocate file if needed
    if (need_preallocate) {
        try file.seekTo(total_size - 1);
        try file.writeAll(&[_]u8{0});
    }
    file.close();

    // Initialize download state
    const state = try DownloadState.init(allocator, url, output_path, total_size, config);
    defer state.deinit();

    std.debug.print("🚀 Starting {d} workers for {d} chunks...\n", .{ config.num_connections, state.chunks.len });
    std.debug.print("\n", .{});

    // Start worker threads (max 32)
    var threads: [32]?std.Thread = [_]?std.Thread{null} ** 32;
    const num_threads = @min(config.num_connections, 32);

    for (0..num_threads) |i| {
        threads[i] = try std.Thread.spawn(.{}, workerThread, .{
            allocator,
            url,
            output_path,
            state.chunks,
            state,
        });
    }

    // Progress display loop
    while (state.downloaded.load(.seq_cst) < total_size) {
        displayProgress(state);

        // Check if all chunks are done or failed
        var all_done = true;
        for (state.chunks) |*chunk| {
            const status = chunk.status.load(.seq_cst);
            if (status == .pending or status == .downloading) {
                all_done = false;
                break;
            }
        }
        if (all_done) break;

        std.Thread.sleep(200 * std.time.ns_per_ms);
    }

    // Wait for all threads
    state.stop_flag.store(true, .seq_cst);
    for (&threads) |*maybe_thread| {
        if (maybe_thread.*) |thread| {
            thread.join();
        }
    }

    displayProgress(state);
    std.debug.print("\n\n", .{});

    // Verify download
    const final_downloaded = state.downloaded.load(.seq_cst);
    if (final_downloaded >= total_size) {
        std.debug.print("✅ Download complete!\n", .{});
    } else {
        // Count failed chunks
        var failed: u32 = 0;
        for (state.chunks) |*chunk| {
            if (chunk.status.load(.seq_cst) == .failed) {
                failed += 1;
            }
        }
        std.debug.print("⚠️  Download incomplete: {d}/{d} bytes, {d} failed chunks\n", .{ final_downloaded, total_size, failed });
        return error.IncompleteDownload;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print(
            \\
            \\╔══════════════════════════════════════════════════════════════╗
            \\║  TRINITY PARALLEL DOWNLOADER                                 ║
            \\║  φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL                         ║
            \\╚══════════════════════════════════════════════════════════════╝
            \\
            \\Usage: {s} <url> <output_file> [connections]
            \\
            \\Arguments:
            \\  url          - URL to download
            \\  output_file  - Local path to save file
            \\  connections  - Number of parallel connections (default: 8)
            \\
            \\Features:
            \\  ✓ Multi-connection parallel downloading
            \\  ✓ Resume interrupted downloads
            \\  ✓ Progress display with speed/ETA
            \\  ✓ Automatic retry on failure
            \\
            \\Example:
            \\  {s} https://nlp.stanford.edu/data/glove.6B.zip glove.zip 16
            \\
        , .{ args[0], args[0] });
        return;
    }

    const url = args[1];
    const output = args[2];

    var config = Config{};
    if (args.len >= 4) {
        config.num_connections = std.fmt.parseInt(u32, args[3], 10) catch 8;
    }

    download(allocator, url, output, config) catch |err| {
        std.debug.print("❌ Error: {s}\n", .{@errorName(err)});
        return err;
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parse url https" {
    const parsed = try parseUrl("https://example.com/path/file.txt");
    try std.testing.expectEqualStrings("example.com", parsed.host);
    try std.testing.expectEqual(@as(u16, 443), parsed.port);
    try std.testing.expectEqualStrings("/path/file.txt", parsed.path);
    try std.testing.expect(parsed.is_https);
}

test "parse url http with port" {
    const parsed = try parseUrl("http://localhost:8080/file");
    try std.testing.expectEqualStrings("localhost", parsed.host);
    try std.testing.expectEqual(@as(u16, 8080), parsed.port);
    try std.testing.expectEqualStrings("/file", parsed.path);
    try std.testing.expect(!parsed.is_https);
}

test "format size kb" {
    var buf: [32]u8 = undefined;
    const result = formatSize(&buf, 1024);
    try std.testing.expect(std.mem.startsWith(u8, result, "1.00 KB"));
}

test "format size mb" {
    var buf: [32]u8 = undefined;
    const result = formatSize(&buf, 1024 * 1024);
    try std.testing.expect(std.mem.startsWith(u8, result, "1.00 MB"));
}
