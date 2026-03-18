# tri cell — Honeycomb Module Management

Complete guide to Trinity's cell (Honeycomb) system — modular architecture, dependency management, health scoring, and automated regeneration.

## Quick Start

```bash
# See all cells
tri cell list

# Create a new cell
tri cell init my-module --template library

# Check cell health
tri cell health

# View dependencies
tri cell deps my-module --tree

# Generate dependency graph
tri cell graph > deps.mmd
```

## What is a Cell?

A **cell** is Trinity's fundamental unit of modularity. Each cell is defined by a `cell.tri` manifest that declares:

- **Metadata**: ID, name, version, description
- **Source**: File patterns that belong to the cell
- **Contributes**: Commands it provides to `tri`, exports for other cells
- **Dependencies**: Other cells it requires
- **Permissions**: Security level (L0-L4), filesystem/network access
- **Contracts**: Input/output invariants for verification

### Example cell.tri

```toml
[cell]
id = "trinity.myagent"
name = "My Agent"
version = "1.0.0"
kind = "virtual-sub"
path = "src/myagent"
parent = "trinity.tri"
status = "stable"
description = "Does something cool"
capabilities = ["agent", "tools"]
tests = 5
owner = "agent:ralph"

[tags]
scope = "brain"
type = "agent"

[source]
file_patterns = ["myagent*.zig"]

[contributes]
commands = ["my-agent run", "my-agent status"]
exports = ["runAgent", "getStatus"]

[dependencies]
"trinity.memory" = ">=1.0.0"
"trinity.vsa" = "^2.5.0"

[permissions]
level = "L1"
filesystem = "read"
network = "none"
process = "none"
ffi = "none"
concurrency = "none"

[security]
signed = true
signature = "sha256:..."
```

## Command Reference

### Discovery & Listing

| Command | Description |
|---------|-------------|
| `tri cell` | Alias for `tri cell status` |
| `tri cell list` | List all cells with status |
| `tri cell list --group` | Group cells by tags.scope |
| `tri cell list --commands` | Show contributes.commands per cell |
| `tri cell list --health` | Show health score per cell |
| `tri cell list --scope <X>` | Filter by tags.scope (infra, brain, research, eng) |
| `tri cell list --type <Y>` | Filter by tags.type (agent, library, tool) |
| `tri cell list --tag <X>:<Y>` | Filter by any tag combination |
| `tri cell info <id>` | Show cell details (tags, deps, health) |
| `tri cell search <query>` | Fuzzy search by name/id/description |
| `tri cell find --capability <X>` | Find cells with specific capability |
| `tri cell orphans` | Find .zig files not claimed by any cell |

### Creating Cells

| Command | Description |
|---------|-------------|
| `tri cell init <id>` | Scaffold new cell (cell.tri + src + test) |
| `tri cell init <id> --with-test` | Also create `<name>.test.zig` |
| `tri cell init <id> --template <name>` | Use template (agent, tool, library, virtual) |
| `tri cell create <path>` | Smart-scaffold cell.tri from existing code |
| `tri cell create-all` | Auto-create cell.tri for all unwrapped modules |
| `tri cell create-all --dry-run` | Preview without writing |
| `tri cell templates` | List available cell templates |

#### Templates

Built-in templates for `tri cell init --template`:

| Template | Description |
|----------|-------------|
| `agent` | Autonomous agent with tools, context, and isolation |
| `tool` | CLI utility with commands and exports |
| `library` | Reusable library with exports and tests |
| `virtual` | Virtual sub-cell for modular organization |

Custom templates can be placed in `~/.tri/templates/`.

### Dependencies

| Command | Description |
|---------|-------------|
| `tri cell deps <id>` | Show dependency tree |
| `tri cell deps <id> --tree` | Recursive dependency tree |
| `tri cell deps --auto-detect` | Scan @imports, find missing deps |
| `tri cell deps --auto-detect --write` | Auto-detect + update cell.tri |
| `tri cell graph` | Output Mermaid dependency diagram |

### Health & Integrity

| Command | Description |
|---------|-------------|
| `tri cell health` | Per-cell health score breakdown |
| `tri cell health --json` | Export health snapshot as JSON |
| `tri cell score` | Unified health+security score per cell |
| `tri cell status` | One-shot integrity dashboard |
| `tri cell watch` | Live health dashboard (5s refresh) |
| `tri cell watch --interval <N>` | Custom refresh interval |
| `tri cell verify` | Check content hashes (integrity) |
| `tri cell contracts` | Verify cell exports match source code |
| `tri cell version` | Show cell versions and content hashes |
| `tri cell outdated` | List cells with modified content (needs regen) |

### Validation & Repair

| Command | Description |
|---------|-------------|
| `tri cell check` | Validate all manifests (dynamic discovery) |
| `tri cell check --sync` | Validate + regenerate registry.json |
| `tri cell check --dry-run` | Show sync changes without writing |
| `tri cell check --auto-register` | Detect and register new cells |
| `tri cell check --auto-register --yes` | Auto-register without prompt |
| `tri cell lint` | Check @import isolation + permission violations |
| `tri cell audit` | CVE-informed security audit (9 checks) |
| `tri cell audit --strict` | Treat warnings as errors |
| `tri cell doctor` | Full heal cycle: fixsignauditlintsyncstatus |

### Repair Commands (`tri cell fix`)

| Command | Description |
|---------|-------------|
| `tri cell fix --perms` | Re-infer permissions from code, update cell.tri |
| `tri cell fix --deps` | Auto-declare dependencies from @imports |
| `tri cell fix --ids` | Deduplicate cell IDs |
| `tri cell fix --scope` | Re-classify scope assignments |
| `tri cell fix --counts` | Re-count files and tests from source |
| `tri cell fix --all` | All of the above |
| `tri cell fix --dry-run` | Preview changes without writing |

### Management

| Command | Description |
|---------|-------------|
| `tri cell enable <id>` | Enable a cell in registry |
| `tri cell disable <id>` | Disable a cell in registry |
| `tri cell sign [<id>|--all]` | Sign L2 cells (sha256 hash) |
| `tri cell regenerate --outdated` | Regenerate all outdated cells |

### Biological Systems

| Command | Description |
|---------|-------------|
| `tri cell bio` | Biological systems map (DNA/Brain/Immune/Regen/Body) |
| `tri cell fix-bio [--all]` | Fix missing [biology] sections |
| `tri cell map` | Binary cell mapping, find orphan binaries |

### MCP Integration

| Command | Description |
|---------|-------------|
| `tri cell mcp-gen` | Generate MCP tools JSON from cell contributes |
| `tri cell commands` | List all cell-contributed tri subcommands |

### Git Hooks

| Command | Description |
|---------|-------------|
| `tri cell install-hooks` | Install Git hooks for auto-registration |

### Coverage

| Command | Description |
|---------|-------------|
| `tri cell coverage` | Test coverage report (fail if <70%) |
| `tri cell coverage --threshold <N>` | Custom threshold percentage |
| `tri cell coverage --verbose` | Detailed per-cell breakdown |
| `tri cell coverage --fix` | Auto-add test stubs for uncovered functions |

### Boundaries

| Command | Description |
|---------|-------------|
| `tri cell check-boundaries` | Validate tag boundary rules |
| `tri cell explain <id>` | Show WHY a cell has its permission level |

## Recipes

### Adding a New Cell

```bash
# 1. Scaffold from template
tri cell init trinity.mymodule --template library

# 2. Edit the generated cell.tri
# vi src/mymodule/cell.tri

# 3. Verify it's registered
tri cell list | grep mymodule

# 4. Check health
tri cell health mymodule

# 5. Run tests
zig build test
```

### Wrapping Existing Code

```bash
# Auto-create cell.tri for unwrapped modules
tri cell create-all --dry-run  # Preview first
tri cell create-all            # Create all

# Or single path
tri cell create src/mymodule
```

### Fixing Broken Cells

```bash
# Full heal cycle (recommended)
tri cell doctor

# Or manual steps:
tri cell fix --all --dry-run    # Preview changes
tri cell fix --all              # Apply fixes
tri cell lint                   # Verify isolation
tri cell check --sync           # Sync registry
tri cell status                 # Verify integrity
```

### Monitoring Health

```bash
# One-time check
tri cell health

# Live dashboard
tri cell watch

# JSON export for tools
tri cell health --json > health.json
```

### Generating Dependency Graph

```bash
# Mermaid diagram
tri cell graph > deps.mmd

# View with Mermaid Live Editor: https://mermaid.live
```

### Finding Orphan Code

```bash
# Zig files not in any cell
tri cell orphans

# Binaries without cell mapping
tri cell map
```

### Audit Security

```bash
# Standard audit
tri cell audit

# Strict mode (CI friendly)
tri cell audit --strict
```

### Auto-Detect Dependencies

```bash
# Preview missing deps
tri cell deps --auto-detect

# Write to cell.tri
tri cell deps --auto-detect --write
```

## Cell Anatomy

### Manifest Structure

```toml
[cell]
id = "trinity.module.name"        # Dot-notation ID
name = "Display Name"             # Human-readable
version = "1.0.0"                 # SemVer
kind = "virtual-sub"              # virtual-sub or virtual
path = "src/module"               # Filesystem path
parent = "trinity.tri"            # Parent cell
status = "stable"                 # stable, experimental, deprecated
description = "What it does"
capabilities = ["cap1", "cap2"]   # Feature list
tests = 5                         # Number of tests
owner = "agent:name"              # Owner agent

[tags]
scope = "brain"                   # Scope: infra, brain, research, eng
type = "agent"                    # Type: agent, library, tool

[source]
file_patterns = ["*.zig"]         # Glob patterns

[contributes]
commands = ["tri subcommand"]     # CLI commands
exports = ["functionName"]        # Public exports

[dependencies]
"trinity.other" = ">=1.0.0"       # Version constraints

[permissions]
level = "L0"                      # L0-L4 security
filesystem = "read"               # read, write, none
network = "none"                  # none, local, external
process = "none"                  # none, spawn
ffi = "none"                      # none, native
concurrency = "none"              # none, yes

[biology]                         # Biological mapping
system = "dna"
organ = "ribosome"

[security]
signed = true
signature = "sha256:..."          # Content hash
```

### Version Constraints

- `=1.0.0` — Exact version
- `>=1.0.0` — Minimum version
- `^1.0.0` — Compatible with 1.x.x
- `~1.0.0` — Patch updates only (1.0.x)

### Permission Levels

| Level | Filesystem | Network | Process | FFI | Use Case |
|-------|-----------|---------|---------|-----|----------|
| L0 | read | none | none | none | Pure functions |
| L1 | read | none | none | none | Utilities |
| L2 | read | local | none | none | Local services |
| L3 | write | local | spawn | none | Tools |
| L4 | write | external | spawn | native | Agents |

## Health Scoring

Health = 100  (0.4  generated_ratio
              + 0.3  compliance_rate
              + 0.2  specs_coverage
              + 0.1  tests_passing)

- **90-100**: HEALTHY
- **70-89**: RECOVERING
- **50-69**: INFECTED
- **0-49**: CRITICAL

Run `tri cell health` for breakdown.

## Registry

The cell registry lives at `.trinity/cells/registry.json`. It's auto-generated from all `cell.tri` manifests.

Run `tri cell check --sync` to regenerate.

## Git Hooks

Auto-register cells on commit:

```bash
tri cell install-hooks
```

Hooks run `tri cell check --auto-register --yes` before commits.

## See Also

- `src/tri/cytoplasm.zig` — Cell management implementation
- `src/tri/ribosome.zig` — Manifest parser
- `src/tri/templates/README.md` — Template reference
