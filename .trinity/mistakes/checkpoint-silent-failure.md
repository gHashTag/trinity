# Checkpoint Silent Failure Bug

**Date**: 2026-03-28
**Severity**: CRITICAL (data loss risk)
**Status**: FIXED

## Problem

Checkpoint save failures were **silently ignored** while logging success messages:

```zig
// BUGGY CODE (src/hslm/cli.zig:397-400)
trainer_mod.saveCheckpoint(...) catch |err| {
    try stdout.print("[WARN] Checkpoint failed: {}\n", .{err});
};
try stdout.print("[CKPT] Saved: {s}\n", .{ckpt_path}); // <-- PRINTS EVEN ON FAILURE!
```

### Root Causes

1. **Directory not created**: `createFile()` fails if parent directory doesn't exist
2. **Success log outside try block**: `[CKPT] Saved:` printed even when checkpoint failed
3. **Silent catch**: Errors logged as warnings, training continued
4. **No pre-flight verification**: No check that checkpoint directory is writable before training starts
5. **No explicit flush**: `deprecatedWriter()` may not flush before close (Zig 0.15)

### Impact

- Training appeared to succeed but checkpoints were never saved
- Container crash (OOM, exit 137) = **total loss of all progress**
- User sees `[CKPT] Saved: ...` but files don't exist on disk
- Impossible to detect without manually checking the filesystem

## Fix Applied

### 1. `saveCheckpoint()` now ensures directory exists

```zig
// NEW: src/hslm/trainer.zig:396
pub fn saveCheckpoint(...) !void {
    // Ensure parent directory exists (critical for Docker volume mounts)
    const dirname = std.fs.path.dirname(path) orelse ".";
    try std.fs.cwd().makePath(dirname);

    const file = try std.fs.cwd().createFile(path, .{ .read = true });
    defer file.close();
    // ... write data ...

    // Explicit flush to ensure data hits disk before close
    try file.flush();
}
```

### 2. Pre-flight verification with canary file

```zig
// NEW: src/hslm/trainer.zig
pub fn verifyCheckpointDir(checkpoint_dir: []const u8) !void {
    const canary_path = "{s}/.canary_writable";
    try std.fs.cwd().makePath(checkpoint_dir);

    // Write canary with timestamp
    const file = try std.fs.cwd().createFile(canary_path, .{ .read = true });
    try writer.print("HSLM checkpoint directory verified at {d}\n", .{ts});
    try file.flush();
}
```

### 3. Fail-fast on checkpoint errors

```zig
// NEW: src/hslm/cli.zig
// Verify BEFORE training starts
try trainer_mod.verifyCheckpointDir(checkpoint_dir) catch |err| {
    try stdout.print("[FATAL] Checkpoint directory not writable: {}\n", .{err});
    return;
};

// During training - FATAL if checkpoint fails
trainer_mod.saveCheckpoint(...) catch |err| {
    try stdout.print("\n[FATAL] Checkpoint failed at step {d}: {}\n", .{step, err});
    try stdout.print("        Training CANNOT continue - data would be lost on crash.\n", .{});
    return err;
};
// Only print success AFTER successful save
try stdout.print("[CKPT] Saved: {s}\n", .{ckpt_path});
```

## Lessons Learned

1. **Never log success outside try block** - success message must only print after success
2. **MakePath before CreateFile** - volume mounts may not have directory structure
3. **Explicit flush()** - don't rely on defer close() for critical data
4. **Pre-flight verification** - fail before wasting hours of training
5. **Fatal > Warning** - checkpoint failure = data loss risk, must stop training

## Files Modified

- `src/hslm/trainer.zig`: Added `makePath()`, `flush()`, `verifyCheckpointDir()`
- `src/hslm/cli.zig`: Pre-flight verification, fatal error handling, fixed logging

## Detection

User diagnosed by:
1. Checking `docker exec wave9-w2 ls -la /data/checkpoints/` - empty despite `[CKPT] Saved:` logs
2. Finding `hslm_step_10000.bin` on host at `data/wave9/worker-2/` - volume mount working
3. Realizing `[CKPT] Saved:` logs were lying - files not created despite success message

## Related

- Issue: wave9 workers exiting with code 137 (OOM kill)
- Hardware: Mac with 3.4GB physical RAM insufficient for HSLM training (needs 16GB+)
- Performance: 7.5 tok/s due to swap thrash (267x slower than expected 2000+ tok/s)
