// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE - Decentralized Inference Network Node
// Desktop app for contributing compute and earning $TRI
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const builtin = @import("builtin");
const protocol = @import("protocol.zig");
const crypto = @import("crypto.zig");
const wallet_mod = @import("wallet.zig");
const network_mod = @import("network.zig");
const discovery = @import("discovery.zig");
const config_mod = @import("config.zig");
const inference_mod = @import("inference.zig");

// GUI is enabled separately via 'zig build node-gui' which links raylib
// This file is for headless mode; ui.zig has its own entry point

// ═══════════════════════════════════════════════════════════════════════════════
// VERSION
// ═══════════════════════════════════════════════════════════════════════════════

pub const VERSION = "0.1.0";
pub const PROTOCOL_VERSION: u16 = 1;

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND LINE ARGUMENTS
// ═══════════════════════════════════════════════════════════════════════════════

const Args = struct {
    headless: bool = false,
    port: u16 = network_mod.JOB_PORT,
    model_path: ?[]const u8 = null,
    wallet_password: ?[]const u8 = null,
    help: bool = false,
};

fn parseArgs() Args {
    var args = Args{};
    var arg_iter = std.process.args();
    _ = arg_iter.skip(); // Skip program name

    while (arg_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--headless") or std.mem.eql(u8, arg, "-d")) {
            args.headless = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            args.help = true;
        } else if (std.mem.startsWith(u8, arg, "--port=")) {
            args.port = std.fmt.parseInt(u16, arg[7..], 10) catch network_mod.JOB_PORT;
        } else if (std.mem.startsWith(u8, arg, "--model=")) {
            args.model_path = arg[8..];
        } else if (std.mem.startsWith(u8, arg, "--password=")) {
            args.wallet_password = arg[11..];
        }
    }

    return args;
}

fn printHelp() void {
    const help =
        \\
        \\╔══════════════════════════════════════════════════════════════════════════╗
        \\║                     TRINITY NODE v{s}                                  ║
        \\║           Decentralized Inference Network                               ║
        \\║           φ² + 1/φ² = 3 = TRINITY                                       ║
        \\╚══════════════════════════════════════════════════════════════════════════╝
        \\
        \\USAGE:
        \\  trinity-node [OPTIONS]
        \\
        \\OPTIONS:
        \\  -h, --help              Show this help message
        \\  -d, --headless          Run in headless (daemon) mode
        \\  --port=PORT             Job server port (default: 9334)
        \\  --model=PATH            Path to GGUF model file
        \\  --password=PASS         Wallet password (will prompt if not provided)
        \\
        \\EXAMPLES:
        \\  trinity-node                          # Start with GUI
        \\  trinity-node --headless               # Run as daemon
        \\  trinity-node --model=./model.gguf     # Use specific model
        \\
        \\DIRECTORIES:
        \\  ~/.trinity/wallet.enc    Encrypted wallet file
        \\  ~/.trinity/config.json   Configuration
        \\  ~/.trinity/models/       Model files
        \\
        \\NETWORK:
        \\  UDP {d}                 Peer discovery
        \\  TCP {d}                 Job server
        \\
        \\REWARDS:
        \\  Base: 0.9 $TRI per 1M tokens
        \\  Latency bonus: up to +50%
        \\  Uptime bonus: up to +20%
        \\
    ;
    std.debug.print(help, .{ VERSION, discovery.DISCOVERY_PORT, network_mod.JOB_PORT });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = parseArgs();

    if (args.help) {
        printHelp();
        return;
    }

    // Print banner
    printBanner();

    // Ensure directories exist
    try config_mod.Config.ensureDirectories(allocator);

    // Load or create wallet
    std.debug.print("Loading wallet...\n", .{});
    const wallet_path = try config_mod.Config.getWalletPath(allocator);
    defer allocator.free(wallet_path);

    const password = args.wallet_password orelse "trinity123"; // TODO: prompt for password

    var wallet = wallet_mod.Wallet.loadOrCreate(wallet_path, password) catch |err| {
        std.debug.print("Failed to load wallet: {}\n", .{err});
        return err;
    };

    std.debug.print("Wallet address: {s}\n", .{wallet.getAddressHex()});
    std.debug.print("Balance: {d:.6} $TRI\n", .{wallet.getBalanceFormatted()});

    // Initialize network
    std.debug.print("Starting network on port {d}...\n", .{args.port});
    var network = try network_mod.NetworkNode.init(allocator, &wallet, args.port);
    defer network.deinit();

    try network.start();
    std.debug.print("Network started. Status: {s}\n", .{@tagName(network.status)});

    if (args.headless) {
        // Headless mode - run daemon
        try runHeadless(allocator, network, &wallet, args.model_path);
    } else {
        // GUI mode - Raylib UI (requires linking raylib)
        // For now, just run headless with a message
        std.debug.print("\nGUI mode requires raylib. Running in headless mode.\n", .{});
        std.debug.print("Build with: zig build node-gui (when raylib is available)\n", .{});
        std.debug.print("Or use --headless flag for daemon mode.\n\n", .{});
        try runHeadless(allocator, network, &wallet, args.model_path);
    }
}

fn printBanner() void {
    const banner =
        \\
        \\  ████████╗██████╗ ██╗███╗   ██╗██╗████████╗██╗   ██╗
        \\  ╚══██╔══╝██╔══██╗██║████╗  ██║██║╚══██╔══╝╚██╗ ██╔╝
        \\     ██║   ██████╔╝██║██╔██╗ ██║██║   ██║    ╚████╔╝
        \\     ██║   ██╔══██╗██║██║╚██╗██║██║   ██║     ╚██╔╝
        \\     ██║   ██║  ██║██║██║ ╚████║██║   ██║      ██║
        \\     ╚═╝   ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝      ╚═╝
        \\
        \\              DECENTRALIZED INFERENCE NODE
        \\                    φ² + 1/φ² = 3
        \\
        \\  Version: {s}    Protocol: v{d}
        \\
    ;
    std.debug.print(banner, .{ VERSION, PROTOCOL_VERSION });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADLESS MODE
// ═══════════════════════════════════════════════════════════════════════════════

fn runHeadless(allocator: std.mem.Allocator, network: *network_mod.NetworkNode, wallet: *wallet_mod.Wallet, model_path: ?[]const u8) !void {
    std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  TRINITY NODE RUNNING (Headless Mode)                        ║\n", .{});
    std.debug.print("║  Press Ctrl+C to stop                                        ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Initialize inference engine
    const inference_config = inference_mod.InferenceConfig{
        .model_path = model_path orelse "models/tinyllama-q6k.gguf",
        .max_tokens = 256,
        .temperature = 0.7,
    };

    var inference_engine = inference_mod.InferenceEngine.init(allocator, inference_config);
    defer inference_engine.deinit();

    // Try to load model (optional - will use simulation if not available)
    var model_loaded = false;
    inference_engine.loadModel() catch |err| {
        std.debug.print("Note: Model not loaded ({s}). Using simulation mode.\n", .{@errorName(err)});
    };
    if (inference_engine.status == .ready) {
        model_loaded = true;
        std.debug.print("Model loaded successfully. Real inference enabled.\n", .{});
    }

    var last_stats_time: i64 = 0;
    const stats_interval: i64 = 10; // Print stats every 10 seconds

    // Main loop
    while (true) {
        // Poll network
        network.poll();

        // Check for pending jobs
        if (network.getNextJob()) |pending_job| {
            std.debug.print("Received job: {x}\n", .{pending_job.job.job_id});

            var tokens_generated: u64 = 50;
            var latency_ms: u32 = 1000;

            if (model_loaded) {
                // Process with real inference engine
                const result = inference_engine.processJob(pending_job.job) catch |err| {
                    std.debug.print("Inference error: {s}\n", .{@errorName(err)});
                    continue;
                };
                tokens_generated = result.tokens_generated;
                latency_ms = result.latency_ms;

                std.debug.print("Generated {d} tokens in {d}ms\n", .{ tokens_generated, latency_ms });
            } else {
                // Simulate processing
                std.Thread.sleep(1 * std.time.ns_per_s);
            }

            // Record job completion
            const uptime_pct: f32 = 1.0;
            wallet.recordJob(tokens_generated, latency_ms, uptime_pct);

            std.debug.print("Job completed. Earned: {d:.6} $TRI\n", .{
                wallet_mod.weiToTri(protocol.calculateJobReward(tokens_generated, latency_ms, uptime_pct)),
            });
        }

        // Print stats periodically
        const now = std.time.timestamp();
        if (now - last_stats_time >= stats_interval) {
            const net_stats = network.getStats();
            const inf_stats = inference_engine.getStats();
            printStats(net_stats, inf_stats, wallet);
            last_stats_time = now;
        }

        // Sleep to avoid busy loop
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
}

fn printStats(net_stats: network_mod.NetworkStats, inf_stats: inference_mod.InferenceStats, wallet: *const wallet_mod.Wallet) void {
    std.debug.print("\n── Stats ──────────────────────────────────────────────────────\n", .{});
    std.debug.print("  Status:      {s}\n", .{@tagName(net_stats.status)});
    std.debug.print("  Peers:       {d}\n", .{net_stats.peer_count});
    std.debug.print("  Jobs:        {d} received / {d} completed\n", .{ net_stats.jobs_received, net_stats.jobs_completed });
    std.debug.print("  Pending:     {d}\n", .{net_stats.pending_jobs});
    std.debug.print("  Uptime:      {d}s\n", .{net_stats.uptime_seconds});
    std.debug.print("  ── Inference ──\n", .{});
    std.debug.print("  Model:       {s}\n", .{if (inf_stats.model_loaded) "Loaded" else "Simulation"});
    std.debug.print("  Processed:   {d} jobs, {d} tokens\n", .{ inf_stats.jobs_processed, inf_stats.tokens_generated });
    std.debug.print("  Speed:       {d:.2} tok/s\n", .{inf_stats.tokens_per_second});
    std.debug.print("  ── Wallet ──\n", .{});
    std.debug.print("  Balance:     {d:.6} $TRI\n", .{wallet.getBalanceFormatted()});
    std.debug.print("  Pending:     {d:.6} $TRI\n", .{wallet.getPendingFormatted()});
    std.debug.print("  Total:       {d:.6} $TRI\n", .{wallet.getTotalEarnedFormatted()});
    std.debug.print("────────────────────────────────────────────────────────────────\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "version string" {
    try std.testing.expect(VERSION.len > 0);
}

test "args parsing" {
    // Just verify the struct can be created
    const args = Args{};
    try std.testing.expect(!args.headless);
    try std.testing.expectEqual(@as(u16, 9334), args.port);
}
