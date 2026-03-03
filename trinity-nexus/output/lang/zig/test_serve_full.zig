const serve = @import("serve_full.zig");
const std = @import("std");

test "parseServeFlags: --help" {
    const args = [_][]const u8{"--help"};
    const flags = serve.parseServeFlags(&args);
    try std.testing.expect(flags.help == true);
    try std.testing.expect(flags.port == 8080);
    try std.testing.expect(flags.daemon == false);
}

test "parseServeFlags: --port 9090" {
    const args = [_][]const u8{ "--port", "9090" };
    const flags = serve.parseServeFlags(&args);
    try std.testing.expect(flags.port == 9090);
    try std.testing.expect(flags.help == false);
}

test "parseServeFlags: bare number 3000" {
    const args = [_][]const u8{"3000"};
    const flags = serve.parseServeFlags(&args);
    try std.testing.expect(flags.port == 3000);
}

test "parseServeFlags: combined flags" {
    const args = [_][]const u8{ "--port", "4000", "--daemon", "--verbose" };
    const flags = serve.parseServeFlags(&args);
    try std.testing.expect(flags.port == 4000);
    try std.testing.expect(flags.daemon == true);
    try std.testing.expect(flags.verbose == true);
    try std.testing.expect(flags.help == false);
}

test "parseServeFlags: -h shorthand" {
    const args = [_][]const u8{"-h"};
    const flags = serve.parseServeFlags(&args);
    try std.testing.expect(flags.help == true);
}

test "parseServeFlags: -p shorthand" {
    const args = [_][]const u8{ "-p", "5555" };
    const flags = serve.parseServeFlags(&args);
    try std.testing.expect(flags.port == 5555);
}

test "parseServeFlags: --host flag" {
    const args = [_][]const u8{ "--host", "127.0.0.1" };
    const flags = serve.parseServeFlags(&args);
    try std.testing.expectEqualStrings("127.0.0.1", flags.host);
}

test "parseServeFlags: empty args defaults" {
    const args = [_][]const u8{};
    const flags = serve.parseServeFlags(&args);
    try std.testing.expect(flags.port == 8080);
    try std.testing.expectEqualStrings("0.0.0.0", flags.host);
    try std.testing.expect(flags.daemon == false);
    try std.testing.expect(flags.help == false);
    try std.testing.expect(flags.verbose == false);
}

test "validatePort: valid ports" {
    try std.testing.expect(serve.validatePort(8080) == true);
    try std.testing.expect(serve.validatePort(1) == true);
    try std.testing.expect(serve.validatePort(65535) == true);
    try std.testing.expect(serve.validatePort(443) == true);
}

test "validatePort: zero is invalid" {
    try std.testing.expect(serve.validatePort(0) == false);
}

test "parseContentLengthHeader: present" {
    const headers = "GET / HTTP/1.1\r\nContent-Length: 1234\r\n\r\n";
    const cl = serve.parseContentLengthHeader(headers);
    try std.testing.expect(cl != null);
    try std.testing.expect(cl.? == 1234);
}

test "parseContentLengthHeader: missing" {
    const headers = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const cl = serve.parseContentLengthHeader(headers);
    try std.testing.expect(cl == null);
}

test "parseContentLengthHeader: case insensitive" {
    const headers = "GET / HTTP/1.1\r\ncontent-length: 5678\r\n\r\n";
    const cl = serve.parseContentLengthHeader(headers);
    try std.testing.expect(cl != null);
    try std.testing.expect(cl.? == 5678);
}

test "parseContentLengthHeader: too short" {
    const cl = serve.parseContentLengthHeader("short");
    try std.testing.expect(cl == null);
}

test "printServeHelp: compiles and runs" {
    // Just verify it doesn't panic
    serve.printServeHelp();
}

test "formatServerBanner: compiles and runs" {
    serve.formatServerBanner(8080, "0.0.0.0", false);
    serve.formatServerBanner(9090, "127.0.0.1", true);
}

test "removePidFile: no crash on missing file" {
    serve.removePidFile();
}

// ═══════════════════════════════════════════════════════════════════════════════
// STRESS TESTS — 64KB POST + daemon mode (Cycle #107)
// ═══════════════════════════════════════════════════════════════════════════════

test "stress: parseContentLengthHeader with 64KB value" {
    const headers = "POST /chat HTTP/1.1\r\nContent-Length: 65536\r\nHost: localhost\r\n\r\n";
    const cl = serve.parseContentLengthHeader(headers);
    try std.testing.expect(cl != null);
    try std.testing.expect(cl.? == 65536);
}

test "stress: parseContentLengthHeader with exact max" {
    const headers = "POST /api/compile HTTP/1.1\r\nContent-Length: 65536\r\nContent-Type: application/json\r\n\r\n";
    const cl = serve.parseContentLengthHeader(headers);
    try std.testing.expect(cl.? == 65536);
}

test "stress: parseContentLengthHeader with over-max (100KB)" {
    const headers = "POST /chat HTTP/1.1\r\nContent-Length: 102400\r\n\r\n";
    const cl = serve.parseContentLengthHeader(headers);
    try std.testing.expect(cl != null);
    try std.testing.expect(cl.? == 102400); // Parsing succeeds; server rejects with 413
}

test "stress: parseContentLengthHeader with zero" {
    const headers = "POST /chat HTTP/1.1\r\nContent-Length: 0\r\n\r\n";
    const cl = serve.parseContentLengthHeader(headers);
    try std.testing.expect(cl != null);
    try std.testing.expect(cl.? == 0);
}

test "stress: parseContentLengthHeader with many headers" {
    const headers = "POST /chat HTTP/1.1\r\nHost: example.com\r\nAccept: */*\r\nAuthorization: Bearer token123\r\nX-Custom: value\r\nContent-Type: application/json\r\nContent-Length: 32768\r\nConnection: keep-alive\r\n\r\n";
    const cl = serve.parseContentLengthHeader(headers);
    try std.testing.expect(cl != null);
    try std.testing.expect(cl.? == 32768);
}

test "stress: daemon mode PID file lifecycle" {
    // Write PID file
    const wrote = serve.writePidFile();
    try std.testing.expect(wrote == true);

    // Verify file exists
    const file = std.fs.cwd().openFile(".tri-serve.pid", .{}) catch |err| {
        std.debug.print("PID file not found: {}\n", .{err});
        return error.TestFailed;
    };
    var buf: [64]u8 = undefined;
    const n = file.readAll(&buf) catch 0;
    file.close();
    try std.testing.expect(n > 0); // PID was written

    // Remove PID file
    serve.removePidFile();

    // Verify file is gone
    _ = std.fs.cwd().openFile(".tri-serve.pid", .{}) catch {
        return; // Expected: file deleted
    };
    return error.TestFailed; // File should not exist
}

test "stress: validatePort boundary values" {
    try std.testing.expect(serve.validatePort(1) == true);
    try std.testing.expect(serve.validatePort(80) == true);
    try std.testing.expect(serve.validatePort(443) == true);
    try std.testing.expect(serve.validatePort(8080) == true);
    try std.testing.expect(serve.validatePort(9090) == true);
    try std.testing.expect(serve.validatePort(65535) == true);
    try std.testing.expect(serve.validatePort(0) == false);
}

test "stress: parseServeFlags all combinations" {
    // Port + daemon + verbose + host
    const args1 = [_][]const u8{ "--port", "3000", "--daemon", "--verbose", "--host", "192.168.1.1" };
    const f1 = serve.parseServeFlags(&args1);
    try std.testing.expect(f1.port == 3000);
    try std.testing.expect(f1.daemon == true);
    try std.testing.expect(f1.verbose == true);
    try std.testing.expectEqualStrings("192.168.1.1", f1.host);

    // Short flags
    const args2 = [_][]const u8{ "-p", "4000", "-h" };
    const f2 = serve.parseServeFlags(&args2);
    try std.testing.expect(f2.port == 4000);
    try std.testing.expect(f2.help == true);

    // Invalid port (non-numeric)
    const args3 = [_][]const u8{ "--port", "abc" };
    const f3 = serve.parseServeFlags(&args3);
    try std.testing.expect(f3.port == 8080); // Default on parse failure
}

test "stress: constants have correct values" {
    try std.testing.expect(serve.DEFAULT_PORT == 8080);
    try std.testing.expect(serve.MAX_PORT == 65535);
    try std.testing.expect(serve.MIN_PORT == 1);
    try std.testing.expect(serve.MAX_POST_BODY == 65536);
    try std.testing.expect(serve.MAX_READ_RETRIES == 100);
    try std.testing.expect(serve.READ_SLEEP_NS == 1000000);
    try std.testing.expect(serve.ROUTES_COUNT == 16);
}
