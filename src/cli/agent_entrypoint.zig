//! Trinity Agent Entrypoint — Runs any of the 27 domain agents
//!
//! Usage: tri agent run [--domain <DOMAIN>] [--port <PORT>]
//!
//! Coptic Alphabet Domain Mapping:
//!   Ⲁⲁ alpha    — Core bootstrapping, agent lifecycle
//!   Ⲃⲃ beta     — Benchmarking, metrics collection
//!   Ⲅⲅ gamma    — Git operations, version control
//!   Ⲇⲇ delta    — Database, persistence layer
//!   Ⲉⲉ epsilon  — Error handling, recovery
//!   Ⲋⲋ zeta     — Zig compilation, VIBEE pipeline
//!   Ⲍⲍ eta      — Event orchestration, hooks
//!   Ⲏⲏ theta    — Testing, validation
//!   Ⲑⲑ iota     — I18n, localization
//!   Ⲓⲓ kappa    — Knowledge base, VSA operations
//!   Ⲕⲕ lambda   — Learning, experience persistence
//!   Ⲗⲗ mu       — Memory management, allocators
//!   Ⲙⲙ nu       — Notification systems (Telegram)
//!   Ⲛⲛ xi       — MCP server integration
//!   Ⲝⲝ omicron  — Optimization, ASHA+PBT
//!   Ⲟⲟ pi       — Pipeline orchestration
//!   Ⲡⲡ koppa    — Compression, GF16 format
//!   Ⲣⲣ rho      — Railway cloud deployment
//!   Ⲥⲥ sigma    — Swarm intelligence
//!   Ⲧⲧ tau      — Ternary VM execution
//!   Ⲩⲩ upsilon  — UI components (Queen)
//!   Ⲫⲫ phi      — Math, φ² + 1/φ² = 3
//!   Ⲭⲭ khi      — CLI commands (310+)
//!   Ⲯⲯ psi      — Privacy, PII detection
//!   Ⲱⲱ omega    — Orchestration, final assembly (Queen)
//!   Ϣⲳ sampi    — SACred intelligence, physics
//!   Ϥϥ sho      — FPGA synthesis, Verilog

const std = @import("std");

// ============================================================================
// CONSTANTS
// ============================================================================

const AGENT_REGISTRY_URL = "http://queen:8080/api/agents";
const HEARTBEAT_INTERVAL_SECONDS = 30;

// ============================================================================
// AGENT DOMAINS
// ============================================================================

const AgentDomain = enum {
    alpha,    // Ⲁⲁ — Core bootstrapping, agent lifecycle
    beta,     // Ⲃⲃ — Benchmarking, metrics collection
    gamma,    // Ⲅⲅ — Git operations, version control
    delta,    // Ⲇⲇ — Database, persistence layer
    epsilon,  // Ⲉⲉ — Error handling, recovery
    zeta,     // Ⲋⲋ — Zig compilation, VIBEE pipeline
    eta,      // Ⲍⲍ — Event orchestration, hooks
    theta,    // Ⲏⲏ — Testing, validation
    iota,     // Ⲑⲑ — I18n, localization
    kappa,    // Ⲓⲓ — Knowledge base, VSA operations
    lambda,   // Ⲕⲕ — Learning, experience persistence
    mu,       // Ⲗⲗ — Memory management, allocators
    nu,       // Ⲙⲙ — Notification systems (Telegram)
    xi,       // Ⲛⲛ — MCP server integration
    omicron,  // Ⲝⲝ — Optimization, ASHA+PBT
    pi,       // Ⲟⲟ — Pipeline orchestration
    koppa,    // Ⲡⲡ — Compression, GF16 format
    rho,      // Ⲣⲣ — Railway cloud deployment
    sigma,    // Ⲥⲥ — Swarm intelligence
    tau,      // Ⲧⲧ — Ternary VM execution
    upsilon,  // Ⲩⲩ — UI components (Queen)
    phi,      // Ⲫⲫ — Math, φ² + 1/φ² = 3
    khi,      // Ⲭⲭ — CLI commands (310+)
    psi,      // Ⲯⲯ — Privacy, PII detection
    omega,    // Ⲱⲱ — Orchestration, final assembly (Queen)
    sampi,    // Ϣⲳ — SACred intelligence, physics
    sho,      // Ϥϥ — FPGA synthesis, Verilog
};

pub const AgentDomainError = error{
    UnknownDomain,
    MissingPort,
    QueenUnavailable,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse args early to check for --health flag
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Check for --health flag (Docker healthcheck)
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--health")) {
            // Get port from env or --port flag
            var port_str = std.process.getEnvVar("AGENT_PORT") orelse null;
            if (port_str == null) {
                var i: usize = 1;
                while (i < args.len) : (i += 1) {
                    if (std.mem.eql(u8, args[i], "--port") and i + 1 < args.len) {
                        port_str = args[i + 1];
                        break;
                    }
                }
            }

            if (port_str == null) {
                std.debug.print("Error: --health requires AGENT_PORT env or --port flag\n", .{});
                std.process.exit(1);
            }

            const port = try std.fmt.parseInt(u16, port_str.?, 10);

            // Perform health check
            if (checkHealth(allocator, port)) {
                std.process.exit(0); // Healthy
            } else {
                std.process.exit(1); // Unhealthy
            }
        }
    }

    // Get agent domain from environment variable or args
    const domain_str = std.process.getEnvVar("AGENT_DOMAIN") orelse {
        // Parse from command line args
        if (args.len < 2) {
            std.debug.print("Usage: tri agent run --domain <DOMAIN> [--port <PORT>]\n", .{});
            std.debug.print("       tri agent run --health [--port <PORT>]\n", .{});
            std.debug.print("Domains: alpha, beta, gamma, delta, epsilon, zeta, eta, theta, iota,\n", .{});
            std.debug.print("          kappa, lambda, mu, nu, xi, omicron, pi, koppa, rho,\n", .{});
            std.debug.print("          sigma, tau, upsilon, phi, khi, psi, omega, sampi, sho\n", .{});
            return;
        }

        // Parse --domain <value>
        if (!std.mem.eql(u8, args[1], "--domain")) {
            std.debug.print("Error: Expected --domain flag\n", .{});
            return error.InvalidArgs;
        }

        args[2]
    };

    // Check for standalone --health mode (for Docker healthcheck)
    fn checkHealth(allocator: std.mem.Allocator, port: u16) bool {
        // Try to connect to localhost and GET /health
        const host = "127.0.0.1";
        const url = try std.fmt.allocPrint(allocator, "http://{s}:{d}/health", .{host, port});

        var client = std.http.Client{ .allocator = allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url) catch |err| {
            std.debug.print("Health check URL parse failed: {}\n", .{err});
            return false;
        };

        var req = try client.open(.GET, uri, .{}) catch |err| {
            std.debug.print("Health check request failed: {}\n", .{err});
            return false;
        };
        defer req.deinit();

        // Set timeout to 2 seconds
        req.timeout = 2_000_000_000;

        // Send request
        req.send() catch |err| {
            std.debug.print("Health check send failed: {}\n", .{err});
            return false;
        };

        // Wait for response
        req.wait() catch |err| {
            std.debug.print("Health check wait failed: {}\n", .{err});
            return false;
        };

        // Check response status
        if (req.status == .ok) {
            std.debug.print("✅ Health check passed\n", .{});
            return true;
        } else {
            std.debug.print("❌ Health check failed: status {}\n", .{@intFromEnum(req.status)});
            return false;
        }
    }

    // Get port from env or args
    var port_str = std.process.getEnvVar("AGENT_PORT") orelse null;
    if (port_str == null) {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);

        // Parse --port <value> if present
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--port") and i + 1 < args.len) {
                port_str = args[i + 1];
                break;
            }
        }
    }

    const port = if (port_str) |p|
        try std.fmt.parseInt(u16, p.*, 10)
    else
        return error.MissingPort;

    const queen_url = std.process.getEnvVar("QUEEN_URL") orelse "http://queen:8080";

    // Parse domain enum
    const domain = std.meta.stringToEnum(AgentDomain, domain_str) orelse {
        std.debug.print("❌ Unknown domain: {s}\n", .{domain_str});
        return error.UnknownDomain;
    };

    std.debug.print("🤖 Agent {s} starting on port {d}\n", .{ @tagName(domain), port });
    std.debug.print("   Queen URL: {s}\n", .{queen_url });

    // Run agent
    try runAgent(allocator, domain, port, queen_url);
}

fn runAgent(
    allocator: std.mem.Allocator,
    domain: AgentDomain,
    port: u16,
    queen_url: []const u8,
) !void {
    // Register with Queen
    try registerWithQueen(allocator, domain, port, queen_url);

    // Start HTTP server for this agent
    const address = try std.net.Address.parseIp("0.0.0.0", port);
    var server = try address.listen(.{ .reuse_address = true });

    std.debug.print("✅ Agent {s} listening on port {d}\n", .{ @tagName(domain), port });
    std.debug.print("   Ready to accept connections\n\n", .{});

    // Start heartbeat thread
    const heartbeat_handle = try std.Thread.spawn(.{}, heartbeatThread, .{
        .allocator = allocator,
        .domain = domain,
        .port = port,
        .queen_url = queen_url,
    });
    defer heartbeat_handle.join();

    // Main agent loop
    while (true) {
        const connection = server.accept() catch |err| {
            std.debug.print("⚠️  Accept failed: {}\n", .{err});
            continue;
        };

        // Handle connection (delegated to domain-specific handler)
        handleAgentConnection(allocator, connection.stream, domain) catch |err| {
            std.debug.print("⚠️  Connection error: {}\n", .{err});
        };
    }
}

fn heartbeatThread(args: struct {
    allocator: std.mem.Allocator,
    domain: AgentDomain,
    port: u16,
    queen_url: []const u8,
}) !void {
    const domain_name = @tagName(args.domain);
    const url = try std.fmt.allocPrint(args.allocator, "{s}/heartbeat", .{args.queen_url});

    while (true) {
        std.time.sleep(HEARTBEAT_INTERVAL_SECONDS * 1_000_000_000);

        // Send heartbeat to Queen
        const heartbeat_data = try std.fmt.allocPrint(args.allocator,
            \{{"domain":"{s}","port":{d},"status":"online","timestamp":{d}}}
        , .{ domain_name, args.port, std.time.timestamp() });

        if (sendHttpRequest(args.allocator, url, heartbeat_data)) |err| {
            std.debug.print("⚠️  Heartbeat failed: {}\n", .{err});
        } else {
            std.debug.print("💓 Heartbeat sent\n", .{});
        }
    }
}

fn registerWithQueen(
    allocator: std.mem.Allocator,
    domain: AgentDomain,
    port: u16,
    queen_url: []const u8,
) !void {
    const domain_name = @tagName(domain);
    const register_url = try std.fmt.allocPrint(allocator, "{s}/register", .{queen_url});

    const register_data = try std.fmt.allocPrint(allocator,
        \{{"domain":"{s}","port":{d},"capabilities":["generic","heartbeat"]}}
    , .{ domain_name, port });

    std.debug.print("📡 Registering with Queen...\n", .{});

    if (sendHttpRequest(allocator, register_url, register_data)) |err| {
        std.debug.print("⚠️  Registration failed: {}\n", .{err});
    } else {
        std.debug.print("✅ Registered with Queen\n", .{});
    }
}

fn handleAgentConnection(
    allocator: std.mem.Allocator,
    stream: std.net.Stream,
    domain: AgentDomain,
) !void {
    const domain_name = @tagName(domain);

    var buffer: [4096]u8 = undefined;
    const request_data = stream.read(&buffer) catch |err| {
        std.debug.print("⚠️  Read failed: {}\n", .{err});
        return;
    };

    if (request_data == 0) return;

    // Parse HTTP request
    const request_text = buffer[0..request_data];
    var lines = std.mem.splitScalar(u8, request_text, '\n');

    const request_line = lines.next() orelse return;
    var parts = std.mem.splitScalar(u8, request_line, ' ');

    const method = parts.next() orelse return;
    const path = parts.next() orelse return;

    // Route request
    const response = try routeAgentRequest(allocator, method, path, domain);

    // Send response
    _ = try stream.writeAll(response);
}

fn routeAgentRequest(
    allocator: std.mem.Allocator,
    method: []const u8,
    path: []const u8,
    domain: AgentDomain,
) ![]const u8 {
    const domain_name = @tagName(domain);

    // Health check endpoint
    if (std.mem.eql(u8, path, "/health")) {
        const health_data = try std.fmt.allocPrint(allocator,
            \{{"domain":"{s}","status":"ok","timestamp":{d}}}
        , .{ domain_name, std.time.timestamp() });

        return try buildHttpResponse("application/json", health_data);
    }

    // Status endpoint
    if (std.mem.eql(u8, path, "/status")) {
        const status_data = try std.fmt.allocPrint(allocator,
            \{{"domain":"{s}","agent":"{s}","port":{d},"role":"active"}}
        , .{ domain_name, domain_name, getAgentPort(domain) });

        return try buildHttpResponse("application/json", status_data);
    }

    // Info endpoint
    if (std.mem.eql(u8, path, "/")) {
        const info_data = try std.fmt.allocPrint(allocator,
            \{{"name":"{s}","domain":"{s}","trinity":"27-agent-grid"}}
        , .{ domain_name, domain_name });

        return try buildHttpResponse("application/json", info_data);
    }

    return try buildHttpResponse("application/json", "{}");
}

fn buildHttpResponse(content_type: []const u8, body: []const u8) ![]const u8 {
    const response = try std.fmt.allocPrint(
        std.heap.page_allocator,
        "HTTP/1.1 200 OK\r\nContent-Type: {s}\r\nContent-Length: {d}\r\n\r\n{s}",
        .{ content_type, body.len, body },
    );
    return response;
}

fn sendHttpRequest(
    allocator: std.mem.Allocator,
    url: []const u8,
    body: []const u8,
) !void {
    // Parse URL to get host and path
    var url_iter = std.mem.splitScalar(u8, url, '/');
    const protocol = url_iter.next() orelse return error.InvalidUrl;
    const empty = url_iter.next() orelse return error.InvalidUrl;
    const host_port = url_iter.next() orelse return error.InvalidUrl;
    const path = url_iter.next() orelse "";

    // Parse host:port
    var host_parts = std.mem.splitScalar(u8, host_port, ':');
    const host = host_parts.next() orelse host_port;
    const port_str = host_parts.next() orelse "80";

    const port = try std.fmt.parseInt(u16, port_str, 10);

    // Connect to server
    const address = try std.net.Address.parseIp(host, port);
    var stream = try address.connect(.{});

    defer stream.close();

    // Send HTTP request
    const request = try std.fmt.allocPrint(allocator,
        "POST /{s} HTTP/1.1\r\nHost: {s}\r\nContent-Type: application/json\r\nContent-Length: {d}\r\n\r\n{s}",
        .{ path, host, body.len, body },
    );

    _ = try stream.writeAll(request);

    // Read response
    var buffer: [1024]u8 = undefined;
    _ = stream.read(&buffer) catch |err| {
        std.debug.print("Read response failed: {}\n", .{err});
        return;
    };
}

fn getAgentPort(domain: AgentDomain) u16 {
    return switch (domain) {
        inline else => |tag| {
            // Default port allocation: 9001-9026 for agents
            const domain_index = @intFromEnum(tag);
            return @intCast(domain_index + 9001);
        },
    };
}
