# Railway — HSLM training service

Config-as-code for the **training** image (`deploy/Dockerfile.hslm-train`).

## Dashboard

In Railway → Service → **Settings**:

- **Config file path** (repo root): `deploy/railway-hslm/railway.toml` (or `railway.json` for JSON workflow)
- **Root directory**: repository root (so Docker `COPY deploy/prebuilt/...` resolves)

`dockerfilePath` inside these files is **`deploy/Dockerfile.hslm-train`** relative to the repo root.

## MCP / other services

MCP uses separate files under `deploy/` (`railway.toml` / `railway.json` next to `Dockerfile.railway`).
