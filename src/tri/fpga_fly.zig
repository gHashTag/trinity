//! tri fpga deploy-fly — Deploy FPGA synthesis service to Fly.io
//!
//! Uses regymm/openxc7 Docker image with Yosys + nextpnr-xilinx
//! for Artix-7 XC7A100T bitstream generation.

const std = @import("std");
const print = std.debug.print;

pub fn runFpgaDeployFlyCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    const env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    // Get Fly.io token from .env
    const fly_token = env.get("FLY_API_TOKEN_1") orelse env.get("FLY_API_TOKEN") orelse {
        std.debug.print("❌ FLY_API_TOKEN not found in .env\n", .{});
        std.debug.print("Add: FLY_API_TOKEN_1=your_token to .env\n", .{});
        return error.FlyTokenNotFound;
    };

    // Get repo root
    const repo_root = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(repo_root);
    const fpga_dir = try std.fs.path.resolve(allocator, &.{ repo_root, "..", "fpga", "openxc7-synth" });

    // Set FLY_API_TOKEN for flyctl
    try std.process.setEnvVar(allocator, "FLY_API_TOKEN", fly_token);

    std.debug.print("🚀 Deploying trinity-fpga-synth to Fly.io...\n", .{});

    // Deploy command (VM size configured in fly.toml)
    const deploy_argv = &[_][]const u8{
        "flyctl",
        "deploy",
        "--dockerfile",   "Dockerfile.fly",
    };

    const deploy_result = try std.process.Child.run(.{
        .allocator = allocator,
        .cwd = fpga_dir,
        .argv = deploy_argv,
    });

    if (deploy_result.term.Exited != 0 and deploy_result.term.Exited != 0) {
        std.debug.print("Deploy stdout:\n{s}\n", .{deploy_result.stdout});
        std.debug.print("Deploy stderr:\n{s}\n", .{deploy_result.stderr});
        return error.DeployFailed;
    }

    try stdout.print("{s}\n", .{deploy_result.stdout});

    // Health check
    try stdout.print("\n⏳ Waiting for service to be ready...\n", .{});
    std.time.sleep(10 * std.time.ns_per_s);

    const status_argv = &[_][]const u8{ "flyctl", "status", "--app", "trinity-fpga-synth" };
    const status_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = status_argv,
    });

    try stdout.print("🔍 Service status:\n{s}\n", .{status_result.stdout});

    // Test endpoint via curl
    const app_url = "https://trinity-fpga-synth.fly.dev";
    try stdout.print("\n🌐 Testing {s}...\n", .{app_url});

    const curl_argv = &[_][]const u8{ "curl", "-s", app_url };
    const curl_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = curl_argv,
    });

    try stdout.print("{s}\n", .{curl_result.stdout});

    try stdout.print("\n✅ Deployment complete!\n", .{});
    try stdout.print("API: {s}/synthesize\n", .{app_url});
    try stdout.print("\nExample:\n", .{});
    try stdout.print("  curl -X POST {s}/synthesize \\\n", .{app_url});
    try stdout.print("    -H 'Content-Type: application/json' \\\n", .{});
    try stdout.print("    -d '{{\"verilog\": \"module top...\", \"top\": \"uart_bridge_top\"}}'\n", .{});
}
