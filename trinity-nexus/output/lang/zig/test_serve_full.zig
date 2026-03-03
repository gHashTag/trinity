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
