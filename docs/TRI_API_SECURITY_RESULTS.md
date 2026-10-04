# tri-api configuration and MCP hardening - 2026-09-30

Base commit: afc9d38435ad01c48af6c33c311da422c38f046e.

## Changes
Permission configuration and MCP tool metadata own their strings after parsing.
Settings use structural JSON parsing; invalid/unreadable existing settings and
rule-capacity overflow fail closed. Missing settings retain existing defaults.
MCP discovery uses structured JSON; initialization is consumed and checked before
tool listing. Tool names are JSON-escaped. Invalid write requests return before
checkpoint side effects. Lexical file path validation and shell metacharacter
checks are tightened without claiming a complete execution sandbox.

## Checks actually run
Zig 0.15.2 with macOS shim sysroot:

```sh
zig test --sysroot "$SHIM" -O "$MODE" src/tri-api/tool_executor.zig
zig test --sysroot "$SHIM" -O "$MODE" src/tri-api/permissions.zig
zig test --sysroot "$SHIM" -O "$MODE" src/tri-api/mcp_client.zig
```

Debug, ReleaseSafe, ReleaseFast, ReleaseSmall all pass. Executor suite contains
24 tests including 9 permission tests, 3 MCP tests and 5 protocol tests; counts
overlap across suites. MCP handshake uses a local Python fixture, no API keys.
Final executor logs: reports/tri-api/security-2026-09-30/.

Full Debug executable also builds:

```sh
zig build-exe --sysroot "$SHIM" -O Debug --dep token_rotator \
  -Mroot=src/tri-api/main.zig -Mtoken_rotator=src/tri/token_rotator.zig
```

## Remaining scope
Local tests, not deployed production validation or full security certification.
Symlink/TOCTOU confinement, shell capability policy, grep path/argument policy,
MCP call-result parsing and request timeouts remain separate work. Provider
failure handling, usage parsing and context compaction are unchanged. Valid writes
retain the existing stash checkpoint design. S07 specification worktree untouched.
