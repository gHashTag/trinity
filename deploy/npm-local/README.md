# Root-style npm manifest (moved out of repo root)

This is the former root `package.json`: **`bin.tri` → `zig-out/bin/tri`** for developers who use npm linking from a Zig build.

```bash
zig build tri
npm install -g ./deploy/npm-local
```

The minimal **`package.json` at the repository root** only wires `postinstall` / `zig build` scripts; it does not duplicate `bin`.
