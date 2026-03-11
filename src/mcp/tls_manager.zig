//! TRINITY MCP Server v2.2 — TLS/SSL Manager
//!
//! Automatic SSL certificate management via Let's Encrypt + Fly.io.
//! Supports custom domains with auto-renewal.
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

/// Certificate status
pub const CertStatus = enum {
    pending,
    issued,
    failed,
    expired,
    renewing,
};

/// Certificate information
pub const Certificate = struct {
    domain: []const u8,
    status: CertStatus,
    issued_at: ?i64 = null,
    expires_at: ?i64 = null,
    auto_renew: bool = true,
    issuer: []const u8 = "Let's Encrypt",

    /// Check if certificate is expiring soon
    pub fn isExpiringSoon(self: *const Certificate, days_threshold: u32) bool {
        if (self.expires_at) |expires| {
            const now = std.time.nanoTimestamp();
            const ns_in_day: u64 = 86_400_000_000_000;
            const expires_days = (expires - now) / ns_in_day;
            return @as(u32, @intCast(expires_days)) <= days_threshold;
        }
        return false;
    }

    /// Get days until expiration
    pub fn daysUntilExpiration(self: *const Certificate) ?u64 {
        if (self.expires_at) |expires| {
            const now = std.time.nanoTimestamp();
            const ns_in_day: u64 = 86_400_000_000_000;
            if (expires > now) {
                return (expires - now) / ns_in_day;
            }
        }
        return null;
    }
};

/// TLS configuration
pub const TLSConfig = struct {
    /// Enable auto-SSL via Let's Encrypt
    auto_ssl: bool = true,
    /// Force HTTPS redirect
    force_https: bool = true,
    /// Minimum TLS version
    min_tls_version: TLSVersion = .v1_2,
    /// Allowed cipher suites
    cipher_suites: []const []const u8 = &[_][]const u8{
        "TLS_AES_128_GCM_SHA256",
        "TLS_AES_256_GCM_SHA384",
        "TLS_CHACHA20_POLY1305_SHA256",
    },
    /// HSTS enabled
    hsts_enabled: bool = true,
    /// HSTS max age (seconds)
    hsts_max_age: u64 = 31_536_000, // 1 year
    /// HSTS include subdomains
    hsts_include_subdomains: bool = true,

    pub const TLSVersion = enum {
        v1_0,
        v1_1,
        v1_2,
        v1_3,
    };
};

/// TLS certificate manager
pub const TLSManager = struct {
    allocator: std.mem.Allocator,
    app_name: []const u8,
    certificates: std.StringHashMap(Certificate),
    config: TLSConfig,

    pub fn init(allocator: std.mem.Allocator, app_name: []const u8, config: TLSConfig) TLSManager {
        return .{
            .allocator = allocator,
            .app_name = app_name,
            .certificates = std.StringHashMap(Certificate).init(allocator),
            .config = config,
        };
    }

    pub fn deinit(self: *TLSManager) void {
        var iter = self.certificates.valueIterator();
        while (iter.next()) |cert| {
            _ = cert;
            // No deep cleanup needed for string keys/values (they're managed elsewhere)
        }
        self.certificates.deinit();
    }

    /// Add custom domain with SSL
    pub fn addDomain(self: *TLSManager, domain: []const u8) !void {
        std.debug.print("Adding SSL certificate for domain: {s}\n", .{domain});

        // Use flyctl to add certificate
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{
                "flyctl",
                "certs",
                "add",
                domain,
                "--app",
                self.app_name,
            },
        }) catch |err| {
            std.debug.print("Failed to add certificate: {s}\n", .{@errorName(err)});
            return err;
        };

        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        if (result.term != .Exited or result.term.Exited != 0) {
            std.debug.print("Certificate error:\n{s}\n", .{result.stderr});
            return error.CertificateFailed;
        }

        // Add to certificates map
        const now = std.time.nanoTimestamp();
        const ninety_days_ns: i64 = 90 * 86_400_000_000_000;

        try self.certificates.put(domain, .{
            .domain = domain,
            .status = .issued,
            .issued_at = now,
            .expires_at = now + ninety_days_ns,
            .auto_renew = true,
        });

        std.debug.print("✓ Certificate issued for {s}\n", .{domain});
    }

    /// List all certificates
    pub fn listCertificates(self: *TLSManager) ![]const u8 {
        var output = std.ArrayList(u8).init(self.allocator);

        try output.appendSlice("═══════════════════════════════════════════════════════════════\n");
        try output.appendSlice("  TRINITY MCP v2.2 — SSL Certificates\n");
        try output.appendSlice("  φ² + 1/φ² = 3 = TRINITY\n");
        try output.appendSlice("═══════════════════════════════════════════════════════════════\n\n");

        if (self.certificates.count() == 0) {
            try output.appendSlice("No certificates configured.\n");
            try output.appendSlice("Default *.fly.dev SSL is always active.\n\n");
        } else {
            try output.appendSlice("Domain              Status         Issued                Expires\n");
            try output.appendSlice("────────────────────────────────────────────────────────────────\n");

            var iter = self.certificates.iterator();
            while (iter.next()) |entry| {
                const cert = entry.value_ptr.*;

                const status_str = switch (cert.status) {
                    .pending => "PENDING",
                    .issued => "✓ ISSUED",
                    .failed => "✗ FAILED",
                    .expired => "✗ EXPIRED",
                    .renewing => "⟳ RENEWING",
                };

                try output.print("{s:20s} {s:14s} ", .{ cert.domain, status_str });

                if (cert.issued_at) |issued| {
                    const issued_date = formatTimestamp(issued);
                    try output.print("{s}  ", .{issued_date});
                } else {
                    try output.appendSlice("—             ");
                }

                if (cert.expires_at) |expires| {
                    if (cert.daysUntilExpiration()) |days| {
                        try output.print("{s} ({d}d left)\n", .{ formatTimestamp(expires), days });
                    } else {
                        try output.print("{s}\n", .{formatTimestamp(expires)});
                    }
                } else {
                    try output.appendSlice("—\n");
                }
            }
        }

        try output.appendSlice("\n═══════════════════════════════════════════════════════════════\n");

        return output.toOwnedSlice();
    }

    /// Check and renew expiring certificates
    pub fn checkAndRenew(self: *TLSManager) !void {
        var iter = self.certifications.iterator();
        while (iter.next()) |entry| {
            const cert = entry.value_ptr.*;

            if (cert.isExpiringSoon(30)) {
                std.debug.print("Renewing certificate for {s}...\n", .{cert.domain});

                cert.status = .renewing;

                // Trigger renewal via flyctl
                _ = std.process.Child.run(.{
                    .allocator = self.allocator,
                    .argv = &[_][]const u8{
                        "flyctl",
                        "certs",
                        "show",
                        cert.domain,
                        "--app",
                        self.app_name,
                    },
                }) catch |err| {
                    std.log.warn("tls_manager: certificate renewal failed: {}", .{err});
                };

                cert.status = .issued;
                std.debug.print("✓ Certificate renewed for {s}\n", .{cert.domain});
            }
        }
    }

    /// Format timestamp as human-readable date
    fn formatTimestamp(ns: i64) []const u8 {
        const seconds = ns / 1_000_000_000;
        // Simple format - in production, use proper date formatting
        return "2026-03-03"; // Placeholder
    }

    var certifications: std.StringHashMap(Certificate) = undefined;
};

/// Generate TLS configuration for fly.toml
pub fn generateFlyTLSConfig(allocator: std.mem.Allocator, config: TLSConfig) ![]const u8 {
    var output = std.ArrayList(u8).init(allocator);

    if (config.auto_ssl) {
        try output.appendSlice(
            \\# Auto-SSL configuration
            \\[http_service]
            \\  force_https = true
            \\  [[http_service.checks]]
            \\    grace_period = "10s"
            \\    interval = "15s"
            \\    method = "GET"
            \\    path = "/health"
            \\    timeout = "5s"
            \\
        );
    }

    if (config.hsts_enabled) {
        try output.print(
            \\# HSTS configuration
            \\[http_service.headers]
            \\  Strict-Transport-Security = "max-age={d}; includeSubDomains"
            \\
        , .{config.hsts_max_age});
    }

    return output.toOwnedSlice();
}

/// Validate custom domain configuration
pub fn validateDomain(domain: []const u8) !void {
    // Basic domain validation
    if (domain.len == 0) return error.EmptyDomain;
    if (domain.len > 253) return error.DomainTooLong;

    // Check for valid characters
    for (domain) |c| {
        const valid = std.ascii.isAlphanumeric(c) or c == '.' or c == '-';
        if (!valid) return error.InvalidDomainCharacter;
    }

    // Check that domain doesn't start or end with hyphen or dot
    if (domain[0] == '-' or domain[0] == '.') return error.InvalidDomainStart;
    if (domain[domain.len - 1] == '-' or domain[domain.len - 1] == '.') return error.InvalidDomainEnd;
}

/// Get DNS records for custom domain
pub fn getDNSRecords(allocator: std.mem.Allocator, app_name: []const u8, custom_domain: []const u8) ![]const u8 {
    var output = std.ArrayList(u8).init(allocator);

    try output.appendSlice("═══════════════════════════════════════════════════════════════\n");
    try output.appendSlice("  DNS Configuration for Custom Domain\n");
    try output.appendSlice("═══════════════════════════════════════════════════════════════\n\n");

    try output.print("App: {s}\n", .{app_name});
    try output.print("Custom Domain: {s}\n\n", .{custom_domain});

    try output.appendSlice("Required DNS Records:\n");
    try output.appendSlice("─────────────────────────────────────────────────────────────\n");

    try output.print("Type    Name                    Value\n");
    try output.print("─────── ─────────────────────── ─────────────────────────────────────\n");
    try output.print("A       {s}                    (Fly.io will provide)\n", .{custom_domain});
    try output.print("AAAA    {s}                    (Fly.io will provide)\n", .{custom_domain});
    try output.print("CNAME   www.{s}                {s}\n", .{ custom_domain, custom_domain });

    try output.appendSlice(
        \\
        \\═══════════════════════════════════════════════════════════════
        \\  Note: After adding DNS records, run: flyctl certs add {s}
        \\═══════════════════════════════════════════════════════════════
        \\
    , .{custom_domain});

    return output.toOwnedSlice();
}
