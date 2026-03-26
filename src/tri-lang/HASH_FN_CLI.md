# tri hash-fn CLI - Content-Addressed Function Verification

**Status:** ✅ Implemented (placeholder - AST parsing pending)
**Date:** 2026-03-25

---

## Overview

The `tri hash-fn` CLI provides content-addressed function hashing for verifying that manually written code matches generated/self-hosted versions. This is the first formal proof-of-equivalence tool for Tri→Zig codegen.

---

## Commands

### `tri hash-fn <module.fn>`

Show content hash for a single function.

```bash
$ tri hash-fn vsa.ops.bind
Computing hash for: vsa.ops::bind
(Full implementation requires Zig AST parsing)
Self-hosted: NO
sha256:9d148f52f347c6bb
```

### `tri hash-fn <module.*>`

Show content hashes for all functions in a module.

```bash
$ tri hash-fn "vsa.ops.*"
Scanning module: vsa.ops
(Full implementation requires Zig AST parsing)
Self-hosted: NO
```

### `tri hash-fn-compare <module.fn>`

Show comparison instructions between manual and self-hosted builds.

```bash
$ tri hash-fn-compare vsa.ops.bind
Comparing: vsa.ops.bind

Manual build hash (TRINITY_SELF_HOSTED=0):
Self-hosted build hash (TRINITY_SELF_HOSTED=1):

Shell script approach:
  #!/bin/bash
  MANUAL=$(TRINITY_SELF_HOSTED=0 tri hash-fn vsa.ops.bind | grep 'sha256:' | cut -d: -f2)
  SELF=$(TRINITY_SELF_HOSTED=1 tri hash-fn vsa.ops.bind | grep 'sha256:' | cut -d: -f2)
  if [ "$MANUAL" = "$SELF" ]; then
    echo "✓ vsa.ops.bind: OK"
  else
    echo "✗ vsa.ops.bind: MISMATCH"
    echo "  Manual:   $MANUAL"
    echo "  Self-host: $SELF"
    exit 1
  fi
```

---

## Environment Variables

- `TRINITY_SELF_HOSTED=0` - Manual build (default)
- `TRINITY_SELF_HOSTED=1` - Self-hosted build (uses gen_ops.zig)

---

## Shell Integration

Compare hashes in one line:

```bash
HASH_MANUAL=$(TRINITY_SELF_HOSTED=0 tri hash-fn vsa.ops.bind)
HASH_SELF=$(TRINITY_SELF_HOSTED=1 tri hash-fn vsa.ops.bind)
[ "$HASH_MANUAL" = "$HASH_SELF" ] && echo OK || echo MISMATCH
```

Or use the provided script:

```bash
./scripts/compare-vsa-ops.sh
```

---

## Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| CLI commands | ✅ Done | `hash-fn` and `hash-fn-compare` work |
| Module parsing | ⏳ TODO | Currently uses placeholder hash |
| AST extraction | ⏳ TODO | Requires Zig AST parsing |
| V2 binary normalization | ✅ Done | `content_hash_v2.zig` ready |
| Wyhash HashMap context | ✅ Done | Full 32-byte hash used |

---

## Next Steps

1. **AST Parsing**: Integrate Zig AST parsing to extract actual function bodies
2. **Binary Normalization**: Use `content_hash_v2.zig` for real hashing
3. **Registry Integration**: Store hashes in `ContentRegistryV2`
4. **CI Integration**: Add to CI pipeline for regression detection

---

## Files

- `src/tri/content_cli.zig` - CLI implementation
- `src/tri/main.zig` - Command registration
- `src/tri-lang/content_hash_v2.zig` - V2 binary normalization
- `src/tri-lang/content_registry_v2.zig` - V2 registry with Wyhash
- `scripts/compare-vsa-ops.sh` - Shell script for batch comparison
