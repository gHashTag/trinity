//! tri fpga deploy-fly — Deploy FPGA synthesis service to Fly.io
//!
//! Uses regymm/openxc7 Docker image with Yosys + nextpnr-xilinx
//! for Artix-7 XC7A100T bitstream generation.

const std = @import("std");
const print = std.debug.print;

pub fn runFpgaDeployFlyCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    // Get Fly.io token from environment (try TOKEN_1, fallback to TOKEN)
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    const fly_token = blk: {
        if (env_map.get("FLY_API_TOKEN_1")) |token1| {
            break :blk try allocator.dupe(u8, token1);
        }
        if (env_map.get("FLY_API_TOKEN")) |token2| {
            break :blk try allocator.dupe(u8, token2);
        }
        print("❌ FLY_API_TOKEN not found in .env\n", .{});
        print("Add: FLY_API_TOKEN_1=your_token to .env\n", .{});
        return error.FlyTokenNotFound;
    };
    defer allocator.free(fly_token);

    // Get repo root
    const repo_root = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(repo_root);
    const fpga_dir = try std.fs.path.resolve(allocator, &.{ repo_root, "..", "fpga", "openxc7-synth" });

    // Note: In Zig 0.15, setting environment variables for child processes
    // is done via the Child process env_map, not via std.process.setEnvVar

    print("🚀 Deploying trinity-fpga-synth to Fly.io...\n", .{});

    // Deploy command (VM size configured in fly.toml)
    const deploy_argv = &[_][]const u8{
        "flyctl",
        "deploy",
        "--dockerfile",
        "Dockerfile.fly",
    };

    // Set up environment for flyctl with FLY_API_TOKEN
    var flyctl_env = try std.process.getEnvMap(allocator);
    defer flyctl_env.deinit();
    try flyctl_env.put("FLY_API_TOKEN", fly_token);

    const deploy_result = try std.process.Child.run(.{
        .allocator = allocator,
        .cwd = fpga_dir,
        .argv = deploy_argv,
        .env_map = &flyctl_env,
    });

    if (deploy_result.term.Exited != 0) {
        print("Deploy stdout:\n{s}\n", .{deploy_result.stdout});
        print("Deploy stderr:\n{s}\n", .{deploy_result.stderr});
        return error.DeployFailed;
    }

    // Write deploy output to stdout
    print("{s}\n", .{deploy_result.stdout});

    // Health check
    print("\n⏳ Waiting for service to be ready...\n", .{});
    std.posix.nanosleep(10, 0);

    const status_argv = &[_][]const u8{ "flyctl", "status", "--app", "trinity-fpga-synth" };
    const status_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = status_argv,
        .env_map = &flyctl_env,
    });

    print("🔍 Service status:\n{s}\n", .{status_result.stdout});

    // Test endpoint via curl
    const app_url = "https://trinity-fpga-synth.fly.dev";
    print("\n🌐 Testing {s}...\n", .{app_url});

    const curl_argv = &[_][]const u8{ "curl", "-s", app_url };
    const curl_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = curl_argv,
    });

    print("{s}\n", .{curl_result.stdout});

    print("\n✅ Deployment complete!\n", .{});
    print("API: {s}/synthesize\n", .{app_url});
    print("\nExample:\n", .{});
    print("  curl -X POST {s}/synthesize \\\n", .{app_url});
    print("    -H 'Content-Type: application/json' \\\n", .{});
    print("    -d '{{\"verilog\": \"module top...\", \"top\": \"uart_bridge_top\"}}'\n", .{});
}
