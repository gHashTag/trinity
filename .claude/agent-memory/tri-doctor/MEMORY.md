# TRI Doctor Memory

## Session: 2026-03-19 — Doctor Scan & Heal

### Health Status
- **Score:** 71/100 (RECOVERING)
- **Files:** 372 total (267 generated, 84 manual, 21 exempt)
- **Metrics:**
  - Generated ratio: 76.1%
  - Compliance rate: 76.1%
  - Specs coverage: 42.7%
  - Tests passing: 100%

### Healing Actions
1. **Doctor scan complete** — All files classified
2. **Railway config fix** — Commented out startCommand (use Dockerfile ENTRYPOINT)
3. **Experience logged** — 4 new episodes added
4. **Queen state updated** — Rate limits reset, farm health confirmed (8/8 alive)

### Key Files
- `.doctor/scan_results.json` — File classification registry
- `.doctor/migration_queue.json` — Pending regenerations (84 manual files lack specs)
- `deploy/railway-hslm/railway.toml` — HSLM training service config (startCommand MUST be null); set this path in Railway dashboard

### Manual Files (84 pending regeneration)
These files lack .tri specs and cannot be auto-healed:
- Queen brain regions: queen_ouroboros.zig, queen_policy.zig, queen_telegram.zig, etc.
- HSLM core: model.zig, trainer.zig, tjepa.zig
- Tri API: tri-cli_parse.zig, tri_cli_types.zig
- Tools: issue_tools.zig, deploy_tools.zig, doctor_tools.zig

To heal: Create .tri specs, then run `tri pipeline run "<task>"`

### Commit History
- `d8a9b4ee8` — feat(doctor): health scan update + railway config fix
- `f8c8417f7` — chore(queen): update runtime state after doctor scan

### Next Steps
- Create .tri specs for 84 manual files
- Increase specs coverage from 42.7% to 80%+
- Target health score: 90+ (HEALTHY)
