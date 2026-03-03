//! MCP Security Module
//!
//! Input validation and sanitization for MCP server.
//! Prevents command injection, path traversal, and DoS attacks.
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

/// Dangerous patterns that could indicate command injection
const DANGEROUS_PATTERNS = [_][]const u8{
    ";",     // Command separator
    "&",     // Background operator
    "|",     // Pipe operator
    "$(",    // Command substitution
    "`",     // Backtick command substitution
    "\n",    // Newline injection
    "\r",    // Carriage return injection
    "\\x",   // Hex escape
    "\\u",   // Unicode escape
    "..",    // Directory traversal
    "~/",    // Home directory access
    "/etc/", // System directory access
    "/proc/",// Process filesystem access
    "/dev/", // Device filesystem access
};

/// Security configuration
pub const SecurityConfig = struct {
    max_input_size: usize = 1_000_000,      // 1MB max input
    max_output_size: usize = 10_000_000,    // 10MB max output
    timeout_ms: u64 = 5000,                 // 5 second timeout
    enable_sanitization: bool = true,
    enable_rate_limit: bool = true,
};

/// Security validation result
pub const ValidationResult = struct {
    is_valid: bool,
    error_message: ?[]const u8 = null,
    error_code: ?SecurityErrorCode = null,
};

/// Security error codes
pub const SecurityErrorCode = enum(u16) {
    input_too_large = 1001,
    dangerous_pattern = 1002,
    path_traversal = 1003,
    invalid_characters = 1004,
    rate_limit_exceeded = 1005,
};

/// Validate tool input against security rules
pub fn validateToolInput(allocator: std.mem.Allocator, tool_name: []const u8, args: []const u8) !ValidationResult {
    _ = &allocator;

    // 1. Check input size
    if (args.len > 1_000_000) {
        return .{
            .is_valid = false,
            .error_message = "Input too large (max 1MB)",
            .error_code = .input_too_large,
        };
    }

    // 2. Check for dangerous patterns
    for (DANGEROUS_PATTERNS) |pattern| {
        if (std.mem.indexOf(u8, args, pattern) != null) {
            const msg = try std.fmt.allocPrint(allocator, "Dangerous pattern detected: '{s}'", .{pattern});
            return .{
                .is_valid = false,
                .error_message = msg,
                .error_code = .dangerous_pattern,
            };
        }
    }

    // 3. Validate file paths for file-related tools
    if (isFileRelatedTool(tool_name)) {
        if (std.mem.indexOf(u8, args, "..") != null) {
            return .{
                .is_valid = false,
                .error_message = "Path traversal detected (.. not allowed)",
                .error_code = .path_traversal,
            };
        }

        // Check for absolute paths
        if (std.mem.startsWith(u8, args, "/") or std.mem.startsWith(u8, args, "~/")) {
            return .{
                .is_valid = false,
                .error_message = "Absolute paths not allowed",
                .error_code = .path_traversal,
            };
        }
    }

    return .{ .is_valid = true };
}

/// Check if tool is file-related
fn isFileRelatedTool(tool_name: []const u8) bool {
    const file_tools = [_][]const u8{
        "read",      "write",     "file",      "open",
        "create",    "delete",    "modify",    "upload",
        "download",  "save",      "load",      "import",
    };

    for (file_tools) |file_tool| {
        if (std.mem.indexOf(u8, tool_name, file_tool) != null) {
            return true;
        }
    }
    return false;
}

/// Sanitize string input
pub fn sanitizeString(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);

    for (input) |c| {
        // Allow alphanumeric, common punctuation, and spaces
        if ((c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            (c >= '0' and c <= '9') or
            c == '-' or c == '_' or c == '.' or c == ',' or
            c == ' ' or c == ':' or c == '/' or c == '(' or c == ')')
        {
            try result.append(c);
        } else {
            // Replace with underscore
            try result.append('_');
        }
    }

    return result.toOwnedSlice();
}

/// Validate JSON parameter string
pub fn validateJson(json: []const u8) !void {
    // Check for basic JSON structure
    var depth: usize = 0;
    var in_string = false;
    var escape_next = false;

    for (json) |c| {
        if (escape_next) {
            escape_next = false;
            continue;
        }

        switch (c) {
            '\\' => {
                if (in_string) escape_next = true;
            },
            '"' => {
                in_string = !in_string;
            },
            '{', '[' => {
                if (!in_string) depth += 1;
            },
            '}', ']' => {
                if (!in_string) {
                    if (depth == 0) return error.UnbalancedBraces;
                    depth -= 1;
                }
            },
            else => {},
        }

        // Prevent overly deep nesting (DoS prevention)
        if (depth > 20) return error.JsonTooDeep;
    }

    if (depth != 0) return error.UnbalancedBraces;
}

/// Rate limiter for command execution
pub const RateLimiter = struct {
    allocator: std.mem.Allocator,
    requests: std.StringHashMap(std.ArrayList(i64)),
    max_requests_per_minute: u32 = 60,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) RateLimiter {
        return .{
            .allocator = allocator,
            .requests = std.StringHashMap(std.ArrayList(i64)).init(allocator),
            .max_requests_per_minute = 60,
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *RateLimiter) void {
        var iter = self.requests.valueIterator();
        while (iter.next()) |list| {
            list.deinit();
        }
        self.requests.deinit();
    }

    /// Check if request is allowed under rate limit
    pub fn checkLimit(self: *RateLimiter, client_id: []const u8) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.nanoTimestamp();
        const one_minute_ago = now - (60 * 1_000_000_000);

        // Get or create client request list
        const gop = try self.requests.getOrPut(client_id);
        if (!gop.found_existing) {
            gop.value_ptr.* = std.ArrayList(i64).init(self.allocator);
        }

        // Remove old requests outside the time window
        var i: usize = 0;
        while (i < gop.value_ptr.items.len) {
            if (gop.value_ptr.items[i] < one_minute_ago) {
                _ = gop.value_ptr.orderedRemove(i);
            } else {
                i += 1;
            }
        }

        // Check if limit exceeded
        if (gop.value_ptr.items.len >= self.max_requests_per_minute) {
            return false;
        }

        // Add current request
        try gop.value_ptr.append(now);
        return true;
    }
};

/// Resource limits for subprocess execution
pub const ResourceLimits = struct {
    max_memory_mb: u64 = 1024,
    timeout_ms: u64 = 5000,
    max_output_size: usize = 10_000_000,

    pub fn applyToChild(self: ResourceLimits, child: *std.process.Child) !void {
        _ = self;
        _ = child;
        // TODO: Apply platform-specific resource limits
        // - Set memory limit (setrlimit on Unix)
        // - Set timeout with monitoring thread
        // - Limit output size with pipe buffering
    }
};
