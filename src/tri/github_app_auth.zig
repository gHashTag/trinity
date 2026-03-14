// @origin(manual)
// ═══════════════════════════════════════════════════════════════════════════════
// GitHub App Auth — JWT + Installation Token for elevated API access
// ═══════════════════════════════════════════════════════════════════════════════
//
// Enables GitHub App authentication for Trinity:
// - Rate limit: 12,500/hr (vs 5,000 for PAT)
// - Check Runs without special PAT scopes
// - Installation-scoped tokens (least privilege)
//
// Priority chain: App auth → PAT (GITHUB_TOKEN/GH_TOKEN) → gh CLI fallback
//
// JWT signing uses openssl subprocess (RS256 not in Zig std).
// This is pragmatic — openssl is ubiquitous on macOS/Linux.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const GitHubAppAuth = struct {
    app_id: []const u8,
    private_key_path: []const u8,
    installation_id: []const u8,
    cached_token: ?[]const u8,
    token_expires_at: i64,
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Initialize from environment variables:
    /// GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY_PATH, GITHUB_APP_INSTALLATION_ID
    pub fn init(allocator: std.mem.Allocator) !Self {
        const app_id = std.process.getEnvVarOwned(allocator, "GITHUB_APP_ID") catch
            return error.AppIdNotSet;
        const key_path = std.process.getEnvVarOwned(allocator, "GITHUB_APP_PRIVATE_KEY_PATH") catch {
            allocator.free(app_id);
            return error.PrivateKeyPathNotSet;
        };
        const install_id = std.process.getEnvVarOwned(allocator, "GITHUB_APP_INSTALLATION_ID") catch {
            allocator.free(app_id);
            allocator.free(key_path);
            return error.InstallationIdNotSet;
        };

        return Self{
            .app_id = app_id,
            .private_key_path = key_path,
            .installation_id = install_id,
            .cached_token = null,
            .token_expires_at = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.app_id);
        self.allocator.free(self.private_key_path);
        self.allocator.free(self.installation_id);
        if (self.cached_token) |t| self.allocator.free(t);
    }

    /// Get a valid installation token (cached or refreshed)
    pub fn getToken(self: *Self) ![]const u8 {
        const now = std.time.timestamp();
        // Refresh if expired or within 60s of expiry
        if (self.cached_token != null and now < self.token_expires_at - 60) {
            return self.cached_token.?;
        }

        const jwt = try self.generateJwt();
        defer self.allocator.free(jwt);

        const token = try self.exchangeForInstallationToken(jwt);
        if (self.cached_token) |old| self.allocator.free(old);
        self.cached_token = token;
        // Installation tokens expire in 1 hour
        self.token_expires_at = now + 3600;
        return token;
    }

    /// Check if GitHub App auth is available (env vars set)
    pub fn isAvailable() bool {
        const app_id = std.process.getEnvVarOwned(std.heap.page_allocator, "GITHUB_APP_ID") catch return false;
        std.heap.page_allocator.free(app_id);
        return true;
    }

    /// Generate a JWT signed with RS256 using openssl
    fn generateJwt(self: *Self) ![]const u8 {
        const now = std.time.timestamp();
        const iat = now - 60; // Allow clock drift
        const exp = now + (10 * 60); // 10 min max for GitHub

        // JWT header (RS256)
        const header = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9"; // base64url({"alg":"RS256","typ":"JWT"})

        // JWT payload
        var payload_buf: [512]u8 = undefined;
        const payload_json = std.fmt.bufPrint(&payload_buf, "{{\"iat\":{d},\"exp\":{d},\"iss\":\"{s}\"}}", .{ iat, exp, self.app_id }) catch
            return error.BufferOverflow;

        // Base64url encode payload
        const payload_b64 = try base64UrlEncode(self.allocator, payload_json);
        defer self.allocator.free(payload_b64);

        // Signing input: header.payload
        const signing_input = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ header, payload_b64 });
        defer self.allocator.free(signing_input);

        // Sign with openssl
        const signature = try self.signWithOpenssl(signing_input);
        defer self.allocator.free(signature);

        // Full JWT: header.payload.signature
        return std.fmt.allocPrint(self.allocator, "{s}.{s}.{s}", .{ header, payload_b64, signature });
    }

    /// Sign data using openssl dgst -sha256 -sign <key.pem>
    fn signWithOpenssl(self: *Self, data: []const u8) ![]const u8 {
        // Write data to temp file, sign it, read signature
        const tmp_path = "/tmp/trinity_jwt_payload";
        const sig_path = "/tmp/trinity_jwt_sig";

        // Write payload
        {
            var file = try std.fs.createFileAbsolute(tmp_path, .{});
            defer file.close();
            try file.writeAll(data);
        }

        // Sign with openssl
        const sign_result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{
                "openssl", "dgst", "-sha256", "-sign", self.private_key_path, "-out", sig_path, tmp_path,
            },
            .max_output_bytes = 4096,
        });
        defer self.allocator.free(sign_result.stdout);
        defer self.allocator.free(sign_result.stderr);

        const exit_code = switch (sign_result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        };
        if (exit_code != 0) {
            std.debug.print("openssl sign failed: {s}\n", .{sign_result.stderr});
            return error.OpensslSignFailed;
        }

        // Read signature binary
        var sig_file = try std.fs.openFileAbsolute(sig_path, .{});
        defer sig_file.close();
        const sig_bytes = try sig_file.readToEndAlloc(self.allocator, 8192);
        defer self.allocator.free(sig_bytes);

        // Base64url encode signature
        return base64UrlEncode(self.allocator, sig_bytes);
    }

    /// Exchange JWT for installation access token
    fn exchangeForInstallationToken(self: *Self, jwt: []const u8) ![]const u8 {
        const url = try std.fmt.allocPrint(self.allocator, "https://api.github.com/app/installations/{s}/access_tokens", .{self.installation_id});
        defer self.allocator.free(url);

        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = std.Uri.parse(url) catch return error.InvalidUrl;

        var auth_buf: [2048]u8 = undefined;
        const auth_val = std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{jwt}) catch return error.BufferOverflow;

        var headers = [_]std.http.Header{
            .{ .name = "User-Agent", .value = "trinity-cli/1.0" },
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "Authorization", .value = auth_val },
        };

        var req = client.request(.POST, uri, .{
            .extra_headers = &headers,
            .redirect_behavior = .unhandled,
        }) catch return error.ConnectionFailed;
        defer req.deinit();

        // POST with empty body
        req.transfer_encoding = .{ .content_length = 2 };
        var body_writer = req.sendBodyUnflushed(&.{}) catch return error.RequestFailed;
        body_writer.writer.writeAll("{}") catch return error.RequestFailed;
        body_writer.end() catch return error.RequestFailed;
        if (req.connection) |conn| conn.flush() catch return error.RequestFailed;

        var redirect_buf: [0]u8 = .{};
        var response = req.receiveHead(&redirect_buf) catch return error.RequestFailed;

        const status_code = @intFromEnum(response.head.status);
        if (status_code != 201) {
            std.debug.print("GitHub App token exchange failed: {d}\n", .{status_code});
            return error.TokenExchangeFailed;
        }

        var transfer_buffer: [4096]u8 = undefined;
        var reader = response.reader(&transfer_buffer);
        const body = reader.allocRemaining(self.allocator, std.Io.Limit.limited(64 * 1024)) catch
            return error.OutOfMemory;
        defer self.allocator.free(body);

        // Extract "token" from response JSON
        const github_client = @import("github_client.zig");
        const token = github_client.extractJsonString(body, "token") orelse return error.TokenNotFound;
        return self.allocator.dupe(u8, token);
    }
};

/// Base64url encode (no padding, URL-safe alphabet)
fn base64UrlEncode(allocator: std.mem.Allocator, data: []const u8) ![]const u8 {
    const encoder = std.base64.url_safe_no_pad;
    const encoded_len = encoder.Encoder.calcSize(data.len);
    const buf = try allocator.alloc(u8, encoded_len);
    _ = encoder.Encoder.encode(buf, data);
    return buf;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "base64UrlEncode" {
    const allocator = std.testing.allocator;
    const result = try base64UrlEncode(allocator, "hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("aGVsbG8", result);
}

test "GitHubAppAuth.isAvailable without env" {
    // Should return false when GITHUB_APP_ID is not set
    try std.testing.expect(!GitHubAppAuth.isAvailable());
}
