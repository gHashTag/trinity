---
sidebar_position: 2
---

# Security Best Practices

Secure your Trinity applications with comprehensive input validation, memory safety, and security best practices.

## Overview

Trinity provides several security advantages out of the box:

| Feature | Security Benefit | Trinity Advantage |
|---------|-----------------|-------------------|
| **Memory Safety** | No buffer overflows | Zig's bounds checking |
| **Type Safety** | No type confusion | Strong ternary type system |
| **No Undefined Behavior** | Predictable execution | Zig's compile-time guarantees |
| **Ternary Encoding** | Obfuscation resistance | Non-standard representation |

## Input Validation

### Validating Ternary Vectors

Always validate that inputs contain valid trits (-1, 0, +1):

```zig
const std = @import("std");
const vsa = @import("trinity/vsa");

const ValidationError = error{
    InvalidTritValue,
    EmptyVector,
    VectorTooLarge,
};

fn validateTritVector(data: []const i2) ValidationError!void {
    // Check empty
    if (data.len == 0) return ValidationError.EmptyVector;

    // Check size limits
    if (data.len > 1_000_000) return ValidationError.VectorTooLarge;

    // Validate each trit
    for (data) |trit| {
        if (trit < -1 or trit > 1) {
            return ValidationError.InvalidTritValue;
        }
    }
}

// Usage example
fn processUserInput(allocator: std.mem.Allocator, input: []const i2) !void {
    // Validate before processing
    try validateTritVector(input);

    // Safe to process
    var vec = try vsa.HybridBigInt.fromSlice(allocator, input);
    defer vec.deinit(allocator);

    // ... continue processing
}
```

### Safe Integer Conversion

Prevent integer overflow and underflow:

```zig
fn safeTritToInt(value: i2) !i32 {
    return std.math.cast(i32, value) orelse error.Overflow;
}

fn safeIntToTrit(value: i32) !i2 {
    if (value < -1 or value > 1) {
        return error.InvalidTrit;
    }
    return @intCast(value);
}

// Batch validation
fn validateIntSlice(values: []const i32) ![]i2 {
    const result = try allocator.alloc(i2, values.len);

    for (values, 0..) |val, i| {
        result[i] = try safeIntToTrit(val);
    }

    return result;
}
```

### String to Vector Validation

When parsing strings from external sources:

```zig
fn parseTernaryVector(allocator: std.mem.Allocator, input: []const u8) ![]i2 {
    var trits = std.ArrayList(i2).init(allocator);

    var iter = std.mem.splitScalar(u8, input, ',');
    while (iter.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " \t\r\n");

        if (trimmed.len == 0) continue;

        const trit = std.fmt.parseInt(i2, trimmed, 10) catch |err| {
            std.log.err("Invalid trit value: '{s}'", .{trimmed});
            return error.InvalidTritFormat;
        };

        if (trit < -1 or trit > 1) {
            std.log.err("Trit out of range: {}", .{trit});
            return error.TritOutOfRange;
        }

        try trits.append(trit);
    }

    if (trits.items.len == 0) {
        return error.EmptyVector;
    }

    return trits.toOwnedSlice();
}
```

## Memory Safety

### Preventing Buffer Overflows

Zig provides bounds checking by default. Never disable it without careful consideration:

```zig
// BAD: Disables bounds checking
fn unsafeOperation(data: []i2, index: usize) i2 {
    @setRuntimeSafety(false);  // DANGEROUS!
    return data[index];  // Could crash or read arbitrary memory
}

// GOOD: Let Zig check bounds
fn safeOperation(data: []i2, index: usize) !i2 {
    if (index >= data.len) {
        return error.IndexOutOfBounds;
    }
    return data[index];
}

// BETTER: Use checked arithmetic
fn safeAccess(data: []i2, base: usize, offset: usize) !i2 {
    const index = std.math.add(usize, base, offset) catch |err| {
        return error.Overflow;
    };

    if (index >= data.len) {
        return error.IndexOutOfBounds;
    }

    return data[index];
}
```

### Safe Memory Allocation

Always check allocation results and clean up properly:

```zig
fn safeVectorClone(allocator: std.mem.Allocator, vec: *const vsa.HybridBigInt) !vsa.HybridBigInt {
    // Allocation can fail
    var result = try vsa.HybridBigInt.init(allocator, vec.len);
    errdefer result.deinit(allocator);  // Cleanup on error

    // Copy data (bounds checked)
    for (0..vec.len) |i| {
        result.set(i, vec.get(i));
    }

    return result;
}

// Using defer for guaranteed cleanup
fn processMultipleVectors(allocator: std.mem.Allocator) !void {
    var vec1 = try vsa.HybridBigInt.random(allocator, 1000);
    defer vec1.deinit(allocator);

    var vec2 = try vsa.HybridBigInt.random(allocator, 1000);
    defer vec2.deinit(allocator);

    var result = try vsa.HybridBigInt.init(allocator, 1000);
    defer result.deinit(allocator);

    // All vectors cleaned up even if error occurs
    _ = try vsa.bind(&vec1, &vec2, &result);
}
```

### Preventing Memory Leaks

```zig
// Memory leak detection
fn testNoLeaks(allocator: std.mem.Allocator) !void {
    // Get initial heap usage
    const before = allocator.query();

    {
        var vec = try vsa.HybridBigInt.random(allocator, 10000);
        defer vec.deinit(allocator);

        // ... operations ...
    }

    // Check heap is back to original size
    const after = allocator.query();
    if (after.bytes_used != before.bytes_used) {
        std.log.err("Memory leak detected: {} bytes", .{after.bytes_used - before.bytes_used});
        return error.MemoryLeak;
    }
}
```

### Use Arena Allocators for Temporary Data

```zig
fn processTemporaryData(allocator: std.mem.Allocator) !void {
    // Arena for temporary allocations
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    // Allocate temporary data
    var temp_vec = try vsa.HybridBigInt.random(arena_allocator, 100000);
    var temp_result = try vsa.HybridBigInt.init(arena_allocator, 100000);

    // All freed at once when arena.deinit() is called
    _ = try vsa.bind(&temp_vec, &temp_vec, &temp_result);
}
```

## Security Considerations

### Protecting Against Timing Attacks

```zig
// Constant-time comparison
fn constantTimeCompare(a: []const i2, b: []const i2) bool {
    if (a.len != b.len) return false;

    var result: u8 = 0;
    for (a, 0..) |trit_a, i| {
        result |= @as(u8, @bitCast(trit_a != b[i]));
    }

    return result == 0;
}

// Constant-time similarity search
fn constantTimeSimilarity(query: []const i2, candidates: [][]i2) !usize {
    var best_idx: usize = 0;
    var best_score: i64 = 0;

    for (candidates, 0..) |candidate, idx| {
        // Always compute full similarity (no early exit)
        const score = try computeSimilarity(query, candidate);

        // Branchless comparison
        const better = @as(i64, @intFromBool(score > best_score));
        best_idx = best_idx * (1 - better) + idx * better;
        best_score = best_score * (1 - better) + score * better;
    }

    return best_idx;
}
```

### Sanitizing Logs and Error Messages

```zig
fn logSecure(context: []const u8, data: []const i2) void {
    // Truncate sensitive data
    const max_log_len = 16;
    const truncated = if (data.len > max_log_len)
        data[0..max_log_len]
    else
        data;

    // Sanitize: convert to hex, not raw values
    std.log.debug(
        "{s}: [{d} trits] [{X}...]",
        .{ context, data.len, truncated }
    );
}

// DON'T log sensitive data
// BAD: std.log.info("API key: {s}", .{api_key});

// DO log only metadata
// GOOD: std.log.info("API key: len={}, valid={}", .{api_key.len, isValid});
```

### Rate Limiting

```zig
const RateLimiter = struct {
    const Window = struct {
        count: usize,
        reset_time: i64,
    };

    windows: std.AutoHashMap(u64, Window),
    max_requests: usize,
    window_ms: i64,

    fn init(allocator: std.mem.Allocator, max_requests: usize, window_ms: i64) RateLimiter {
        return .{
            .windows = std.AutoHashMap(u64, Window).init(allocator),
            .max_requests = max_requests,
            .window_ms = window_ms,
        };
    }

    fn check(limiter: *RateLimiter, user_id: u64, now_ms: i64) !bool {
        const entry = try limiter.windows.getOrPut(user_id);

        if (!entry.found_existing) {
            entry.value_ptr.* = .{ .count = 1, .reset_time = now_ms + limiter.window_ms };
            return true;
        }

        if (now_ms >= entry.value_ptr.reset_time) {
            // Window expired, reset
            entry.value_ptr.* = .{ .count = 1, .reset_time = now_ms + limiter.window_ms };
            return true;
        }

        if (entry.value_ptr.count >= limiter.max_requests) {
            return error.RateLimitExceeded;
        }

        entry.value_ptr.count += 1;
        return true;
    }
};
```

### Secure Random Generation

```zig
fn secureRandomTrits(allocator: std.mem.Allocator, len: usize) ![]i2 {
    const random_bytes = try allocator.alloc(u8, len);
    defer allocator.free(random_bytes);

    // Use cryptographically secure random
    std.crypto.random.bytes(random_bytes);

    const trits = try allocator.alloc(i2, len);
    for (random_bytes, 0..) |byte, i| {
        // Map byte to trit: [-1, 0, +1]
        const mod3 = @mod(byte, 3);
        trits[i] = @as(i2, @intCast(mod3)) - 1;
    }

    return trits;
}
```

## Best Practices

### 1. Validate All External Input

```zig
fn handleExternalRequest(
    allocator: std.mem.Allocator,
    user_id: u64,
    data: []const i2
) !void {
    // Validate user ID
    if (user_id == 0) return error.InvalidUserId;

    // Validate data
    try validateTritVector(data);

    // Check rate limit
    if (!try rate_limiter.check(user_id, now_ms())) {
        return error.RateLimitExceeded;
    }

    // Process
    return processRequest(allocator, data);
}
```

### 2. Use Error Handling Properly

```zig
// DON'T ignore errors
// BAD: const result = bind(a, b) catch undefined;

// DO handle errors explicitly
const result = bind(a, b) catch |err| {
    std.log.err("Bind failed: {}", .{err});
    return err;
};

// Or use try for propagation
const result = try bind(a, b);
```

### 3. Principle of Least Privilege

```zig
// Capability-based security
const Capability = struct {
    can_bind: bool = false,
    can_unbind: bool = false,
    can_bundle: bool = false,
    can_similar: bool = false,
};

fn executeWithCapability(
    op: Operation,
    cap: Capability,
    args: Args
) !Result {
    return switch (op) {
        .bind => if (cap.can_bind) doBind(args) else error.Unauthorized,
        .unbind => if (cap.can_unbind) doUnbind(args) else error.Unauthorized,
        .bundle => if (cap.can_bundle) doBundle(args) else error.Unauthorized,
        .similar => if (cap.can_similar) doSimilar(args) else error.Unauthorized,
    };
}
```

### 4. Secure Defaults

```zig
const SecureConfig = struct {
    // Secure by default
    validate_input: bool = true,
    check_bounds: bool = true,
    rate_limit: bool = true,
    log_sensitive_data: bool = false,

    // Explicit opt-out for unsafe features
    unsafe_skip_validation: bool = false,
    unsafe_disable_bounds_check: bool = false,
};

fn applyConfig(config: SecureConfig) void {
    if (config.unsafe_skip_validation) {
        std.log.warn("SECURITY: Input validation disabled!", .{});
    }

    if (config.unsafe_disable_bounds_check) {
        std.log.warn("SECURITY: Bounds checking disabled!", .{});
    }
}
```

## Security Checklist

Before deploying to production:

- [ ] All external inputs are validated
- [ ] No buffer overflows (bounds checking enabled)
- [ ] Memory leaks tested (arena allocator pattern)
- [ ] Rate limiting implemented
- [ ] Error messages don't leak sensitive info
- [ ] Cryptographic operations use secure random
- [ ] Logs are sanitized
- [ ] Dependencies are audited
- [ ] Secret credentials are not in code
- [ ] Timing attacks considered (constant-time ops)

## Common Vulnerabilities

### 1. Integer Overflow

```zig
// BAD
fn badAllocate(size: u32, count: u32) ![]u8 {
    const total = size * count;  // Can overflow
    return allocator.alloc(u8, total);
}

// GOOD
fn goodAllocate(size: u32, count: u32) ![]u8 {
    const total = try std.math.mul(u32, size, count);  // Checked
    return allocator.alloc(u8, total);
}
```

### 2. Use-After-Free

```zig
// BAD
const vec = try vsa.HybridBigInt.init(allocator, 100);
vec.deinit(allocator);
// ... use vec here (BUG!) ...

// GOOD
{
    var vec = try vsa.HybridBigInt.init(allocator, 100);
    // ... use vec ...
    vec.deinit(allocator);
}
// vec no longer accessible
```

### 3. Double-Free

```zig
// BAD
var vec = try vsa.HybridBigInt.init(allocator, 100);
vec.deinit(allocator);
vec.deinit(allocator);  // Crash!

// GOOD - use defer
var vec = try vsa.HybridBigInt.init(allocator, 100);
defer vec.deinit(allocator);
// ... only one deinit() called
```

## Further Reading

- [Security Research Report](/research/cycle48-capability-security-report) — Capability security model
- [API Reference](/api/) — Safe API usage
- [Testing Guide](/guides/testing) — Security testing practices
- [Community Guidelines](/community/guidelines) — Responsible disclosure

---

**Found a security issue?** Please report it privately via [GitHub Security Advisory](https://github.com/gHashTag/trinity/security/advisories).
