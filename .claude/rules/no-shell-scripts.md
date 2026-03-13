# No Shell Scripts

## Rule
**NEVER create, edit, or reference .sh/.bash files.** Trinity is pure Zig — zero bash, zero Python.

## What to do instead
- Need a CLI tool? → Add a `tri` subcommand in Zig
- Need a deploy entrypoint? → Zig binary (see `src/cli/entrypoint_train.zig`)
- Need a build step? → `build.zig` step
- Need a CI action? → Zig binary called from GitHub Actions YAML
- Need data prep? → Zig tool in `src/cli/` or `tools/`

## Existing .sh files
Legacy scripts in `scripts/`, `deploy/`, `.ralph/scripts/`, `fpga/` are marked for deletion.
Do NOT use them. Do NOT reference them. Do NOT copy patterns from them.

## Dockerfile rules
- Runtime stage: NO `bash`, NO `python3`, NO `sh` in RUN commands
- Entrypoints: ONLY Zig binaries (`ENTRYPOINT ["/usr/local/bin/some-zig-binary"]`)
- Build stage: minimal `sh` allowed ONLY for `apt-get` and `tar` (unavoidable in Docker)

## Enforcement
PreToolUse hook blocks creation of .sh files.
