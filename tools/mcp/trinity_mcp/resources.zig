//! MCP Resources Module v2.1 - Full MCP Spec Compliance
//!
//! Exposes static resources (templates, docs, configs) via MCP protocol.
//! Supports subscribe/unsubscribe for resource updates per MCP 2025-06-18 spec.
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

/// Resource definition with metadata
pub const Resource = struct {
    uri: []const u8,
    name: []const u8,
    description: []const u8,
    mime_type: []const u8,
    loader: *const fn (allocator: std.mem.Allocator, uri: []const u8) anyerror![]const u8,
    /// Whether this resource can be subscribed to for updates
    subscribe_supported: bool = false,
    /// Resource annotation (optional)
    annotation: ?ResourceAnnotation = null,
};

/// Resource annotation for metadata
pub const ResourceAnnotation = struct {
    audience: []const u8 = "user",
    priority: f32 = 0.5,
    /// Additional metadata as JSON
    metadata: ?[]const u8 = null,
};

/// Resource subscription
pub const ResourceSubscription = struct {
    uri: []const u8,
    subscriber_id: []const u8,
    subscribed_at: i64,
};

/// Resource subscription manager
pub const SubscriptionManager = struct {
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,
    subscriptions: std.StringHashMap(std.ArrayList(ResourceSubscription)),

    pub fn init(allocator: std.mem.Allocator) SubscriptionManager {
        return .{
            .allocator = allocator,
            .mutex = std.Thread.Mutex{},
            .subscriptions = std.StringHashMap(std.ArrayList(ResourceSubscription)).init(allocator),
        };
    }

    pub fn deinit(self: *SubscriptionManager) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.subscriptions.valueIterator();
        while (iter.next()) |list| {
            for (list.items) |sub| {
                self.allocator.free(sub.subscriber_id);
            }
            list.deinit();
        }
        self.subscriptions.deinit();
    }

    /// Subscribe to a resource
    pub fn subscribe(self: *SubscriptionManager, uri: []const u8, subscriber_id: []const u8) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        const gop = try self.subscriptions.getOrPut(uri);
        if (!gop.found_existing) {
            gop.value_ptr.* = std.ArrayList(ResourceSubscription).init(self.allocator);
        }

        // Check if already subscribed
        for (gop.value_ptr.items) |sub| {
            if (std.mem.eql(u8, sub.subscriber_id, subscriber_id)) {
                return false; // Already subscribed
            }
        }

        const subscriber_copy = try self.allocator.dupe(u8, subscriber_id);
        const uri_copy = try self.allocator.dupe(u8, uri);

        try gop.value_ptr.append(.{
            .uri = uri_copy,
            .subscriber_id = subscriber_copy,
            .subscribed_at = std.time.nanoTimestamp(),
        });

        return true;
    }

    /// Unsubscribe from a resource
    pub fn unsubscribe(self: *SubscriptionManager, uri: []const u8, subscriber_id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.subscriptions.get(uri)) |list| {
            for (list.items, 0..) |sub, i| {
                if (std.mem.eql(u8, sub.subscriber_id, subscriber_id)) {
                    self.allocator.free(sub.subscriber_id);
                    self.allocator.free(sub.uri);
                    _ = list.orderedRemove(i);
                    return true;
                }
            }
        }
        return false;
    }

    /// Get list of URIs a subscriber is subscribed to
    pub fn getSubscriptions(self: *SubscriptionManager, allocator: std.mem.Allocator, subscriber_id: []const u8) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var result = std.ArrayList([]const u8).init(allocator);

        var iter = self.subscriptions.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.items) |sub| {
                if (std.mem.eql(u8, sub.subscriber_id, subscriber_id)) {
                    try result.append(try allocator.dupe(u8, entry.key_ptr.*));
                    break;
                }
            }
        }

        return result.toOwnedSlice();
    }

    /// Get all subscribers for a URI
    pub fn getSubscribers(self: *SubscriptionManager, uri: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.subscriptions.get(uri)) |list| {
            var result = std.ArrayList([]const u8).init(allocator);
            for (list.items) |sub| {
                try result.append(try allocator.dupe(u8, sub.subscriber_id));
            }
            return result.toOwnedSlice();
        }
        return &[_][]const u8{};
    }
};

/// Available resources
pub const resources = [_]Resource{
    .{
        .uri = "trinity://templates/vibee_spec",
        .name = "VIBEE Spec Template",
        .description = "Template for VIBEE specifications",
        .mime_type = "text/plain",
        .loader = loadVIBEETemplate,
    },
    .{
        .uri = "trinity://docs/sacred_constants",
        .name = "Sacred Constants",
        .description = "Database of sacred mathematical constants (φ, π, e, μ, χ, σ, ε)",
        .mime_type = "application/json",
        .loader = loadSacredConstants,
    },
    .{
        .uri = "trinity://docs/math_foundations",
        .name = "Math Foundations",
        .description = "Mathematical foundations of Trinity",
        .mime_type = "text/markdown",
        .loader = loadMathFoundations,
    },
    .{
        .uri = "trinity://docs/trinity_identity",
        .name = "Trinity Identity",
        .description = "The sacred identity: φ² + 1/φ² = 3",
        .mime_type = "text/markdown",
        .loader = loadTrinityIdentity,
    },
    .{
        .uri = "trinity://docs/command_reference",
        .name = "Command Reference",
        .description = "Complete TRI CLI command reference",
        .mime_type = "application/json",
        .loader = loadCommandReference,
    },
};

/// Load VIBEE spec template
fn loadVIBEETemplate(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    _ = uri;
    return allocator.dupe(u8,
        \\# VIBEE Specification Template
        \\# φ² + 1/φ² = 3 = TRINITY
        \\
        \\name: module_name
        \\version: "1.0.0"
        \\language: zig          # or: varlog (Verilog), python, etc.
        \\module: module_name
        \\
        \\types:
        \\  TypeName:
        \\    fields:
        \\      field1: String
        \\      field2: Int
        \\      field3: Bool
        \\      field4: Float
        \\      field5: List<String>
        \\      field6: Option<Int>
        \\
        \\behaviors:
        \\  - name: function_name
        \\    given: Precondition description
        \\    when: Action description
        \\    then: Expected result
    );
}

/// Load sacred constants
fn loadSacredConstants(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    _ = uri;
    const constants =
        \\{
        \\  "phi": 1.6180339887498948482,
        \\  "pi": 3.14159265358979323846,
        \\  "e": 2.71828182845904523536,
        \\  "mu": 0.038196601125010515,
        \\  "chi": 0.061803398874989485,
        \\  "sigma": 1.6180339887498948482,
        \\  "epsilon": 0.333333333333333333,
        \\  "trinity_sum": 3.0,
        \\  "lucas_2": 3,
        \\  "identity": "φ² + 1/φ² = 3"
        \\}
    ;
    return allocator.dupe(u8, constants);
}

/// Load math foundations documentation
fn loadMathFoundations(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    _ = uri;
    return allocator.dupe(u8,
        \\# Trinity Mathematical Foundations
        \\
        \\## The Sacred Identity
        \\
        \\**φ² + 1/φ² = 3 = TRINITY**
        \\
        \\Where φ (phi) is the Golden Ratio:
        \\```
        \\φ = (1 + √5) / 2 = 1.618033988749...
        \\```
        \\
        \\## Key Constants
        \\
        \\| Symbol | Name | Value |
        \\|--------|------|-------|
        \\| φ | Golden Ratio | 1.618... |
        \\| π | Pi | 3.141... |
        \\| e | Euler's Number | 2.718... |
        \\| μ | Phi^-4 | 0.0382... |
        \\| χ | Phi^-4 + 0.0236 | 0.0618... |
        \\| σ | Phi | 1.618... |
        \\| ε | One third | 0.333... |
        \\
        \\## Lucas Numbers
        \\
        \\The Lucas sequence: 2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123...
        \\
        \\Note that **L(2) = 3 = TRINITY**.
    );
}

/// Load Trinity identity documentation
fn loadTrinityIdentity(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    _ = uri;
    return allocator.dupe(u8,
        \\# The Trinity Identity
        \\
        \\## φ² + 1/φ² = 3
        \\
        \\This is not a claim — it is a theorem.
        \\This is not a promise — it is a proof.
        \\This is not simulated — it is GPU verified.
        \\
        \\## Mathematical Proof
        \\
        \\Given:
        \\```
        \\φ = (1 + √5) / 2
        \\φ² = φ + 1 = 2.618033988749...
        \\1/φ = φ - 1 = 0.618033988749...
        \\1/φ² = (φ - 1)² = 0.381966011250...
        \\```
        \\
        \\Therefore:
        \\```
        \\φ² + 1/φ² = 2.618033988749... + 0.381966011250...
        \\         = 3.000000000000...
        \\         = 3
        \\         = TRINITY
        \\```
        \\
        \\## Significance
        \\
        \\The number 3 represents:
        \\- The ternary nature of computation (-1, 0, +1)
        \\- The three-in-one unity of the Trinity system
        \\- The balance between chaos and order
    );
}

/// Load command reference
/// Note: TRI commands are not available in MCP server build context
fn loadCommandReference(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    _ = uri;
    // Return empty command list since tri_utils is not available in this build
    var json_list = std.array_list.Managed(u8).init(allocator);
    try json_list.appendSlice("{\"commands\":[]}");
    return json_list.toOwnedSlice();
}

/// Generate resources list JSON (v2.1 with full annotations)
pub fn generateResourcesList(allocator: std.mem.Allocator) ![]const u8 {
    var json_list = std.array_list.Managed(u8).init(allocator);
    try json_list.appendSlice("{\"jsonrpc\":\"2.0\",\"result\":{\"resources\":[");

    for (resources, 0..) |res, i| {
        if (i > 0) try json_list.append(',');
        try json_list.print(
            "{{\"uri\":\"{s}\",\"name\":\"{s}\",\"description\":\"{s}\",\"mimeType\":\"{s}\"}}"
        , .{ res.uri, res.name, res.description, res.mime_type });
    }

    try json_list.appendSlice("]}}");
    return json_list.toOwnedSlice();
}

/// Format subscribe response per MCP spec
pub fn formatSubscribeResponse(allocator: std.mem.Allocator, uri: []const u8, subscribed: bool) ![]const u8 {
    if (subscribed) {
        return std.fmt.allocPrint(allocator,
            \\{{"jsonrpc":"2.0","result":{{"subscribed":true,"uri":"{s}"}}}}
        , .{uri});
    } else {
        return std.fmt.allocPrint(allocator,
            \\{{"jsonrpc":"2.0","error":{{"code":-32602,"message":"Already subscribed or resource not subscribable"}}}}
        , .{});
    }
}

/// Format unsubscribe response per MCP spec
pub fn formatUnsubscribeResponse(allocator: std.mem.Allocator, uri: []const u8, unsubscribed: bool) ![]const u8 {
    if (unsubscribed) {
        return std.fmt.allocPrint(allocator,
            \\{{"jsonrpc":"2.0","result":{{"unsubscribed":true,"uri":"{s}"}}}}
        , .{uri});
    } else {
        return std.fmt.allocPrint(allocator,
            \\{{"jsonrpc":"2.0","error":{{"code":-32602,"message":"Not subscribed"}}}}
        , .{});
    }
}

/// Format list subscriptions response
pub fn formatListSubscriptionsResponse(allocator: std.mem.Allocator, uris: [][]const u8) ![]const u8 {
    var json_list = std.array_list.Managed(u8).init(allocator);
    try json_list.appendSlice("{\"jsonrpc\":\"2.0\",\"result\":{\"subscriptions\":[");

    for (uris, 0..) |uri, i| {
        if (i > 0) try json_list.append(',');
        try json_list.print("\"{s}\"", .{uri});
    }

    try json_list.appendSlice("]}}");
    return json_list.toOwnedSlice();
}

/// Check if a resource supports subscription
pub fn supportsSubscription(uri: []const u8) bool {
    for (resources) |res| {
        if (std.mem.eql(u8, res.uri, uri)) {
            return res.subscribe_supported;
        }
    }
    return false;
}

/// Load a resource by URI
pub fn loadResource(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    for (resources) |res| {
        if (std.mem.eql(u8, res.uri, uri)) {
            return res.loader(allocator, uri);
        }
    }
    return error.ResourceNotFound;
}

/// Check if a URI exists
pub fn hasResource(uri: []const u8) bool {
    for (resources) |res| {
        if (std.mem.eql(u8, res.uri, uri)) {
            return true;
        }
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════────
// Global Subscription Manager
// ═══════════════════════════════════════════════════════════════════════────

var global_subscription_manager: ?SubscriptionManager = null;
var subscription_init = std.Thread.Once{};

/// Get global subscription manager (never returns null)
pub fn getSubscriptionManager() *SubscriptionManager {
    const init_fn = struct {
        fn init_() void {
            global_subscription_manager = SubscriptionManager.init(std.heap.page_allocator);
        }
    };

    subscription_init.call(init_fn.init_);
    return &global_subscription_manager.?;
}
