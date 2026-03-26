# Alphabet Canon 27 — Repository Zoning Law

> **Disclaimer**: Alphabet Canon 27 is a Trinity-specific parcellation aligned with TRI-27/Coptic design, not with any specific empirical parcellation from human connectomics. (Senden et al. 2024; Yeo et al. 2011)

> **Swarm Alphabet**: 27 agents with unique names, roles, and superpowers — inspired by brain specialization and insect colony castes.

> **NA-R11**: Each Trinity module belongs to one of 27 letter zones.
> Letter determines its place in brain, codebase, and TRI-27 space.
> Zone T (Temple) is core, protected by TTT Seal.

---

## SWARM-ALPHA Ritual — Canonical Swarm Activation

> **Protocol**: 4-Phase sequential ritual for activating 27 agents in coordinated swarm.
> Entry: `tri swarm alpha --plan <plan-name>`

### Phase 1: SPAWN (A-Z)

Creates agent houses and registers all 27 zones:

```bash
for Z in {A..Z}; do
  tri agent spawn $Z
done
```

Result: Each agent has `.trinity/agents/{Z}/HIVELOG.md` and `state.jsonl`.

### Phase 2: ACTIVATE

Reads `.trinity/thalamus/alpha_tasks.json` and assigns tasks:

```bash
for Z in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z; do
  TASK=$(jq -r ".\"$Z\"" .trinity/thalamus/alpha_tasks.json)
  tri agent activate $Z --task "$TASK"
done
```

Example `alpha_tasks.json`:
```json
{
  "A": "Create src/A/ directory, migrate reward prediction logic",
  "B": "Create src/B/ directory, implement action selection policy",
  "C": "Create src/C/ directory, add error correction tests",
  "D": "Create src/D/ directory, deploy infrastructure",
  "E": "Run eval suite, validate canon",
  "F": "Create src/F/ directory, move Firebird core",
  "G": "Create src/G/ directory, API bridge handlers",
  "H": "Append TDGS episodes to .trinity/hippocampus/",
  "I": "Create src/I/ directory, internal state monitoring",
  "J": "Create src/J/ directory, JIT build paths",
  "K": "Prepare Kaggle baseline benchmarks",
  "L": "Create src/L/ directory, NLP handlers",
  "M": "Create src/M/ directory, CLI action handlers",
  "N": "Create src/N/ directory, WebSocket/MCP handlers",
  "O": "Create src/O/ directory, anomaly detection",
  "P": "Check heartbeats, sleep/wake loops",
  "Q": "Read .trinity/thalamus/agent_reports/, coordinate swarm",
  "R": "Watch-daemon, health checks",
  "S": "Create src/S/ directory, habit loop tuning",
  "T": "Update canonmap, maintain ALPHABET_CANON_27.md, TTT Seal",
  "U": "Create src/U/ directory, Telegram/web UI",
  "V": "Create src/V/ directory, VSA embeddings",
  "W": "Create src/W/ directory, value judgment",
  "X": "Relay messages through thalamus bus",
  "Y": "Create src/Y/ directory, anti-reward flags",
  "Z": "Create src/Z/ directory, cross-zone synchronization"
}
```

### Phase 3: CYCLE (Single worker loop)

```bash
for Z in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z; do
  tri agent cycle $Z
done
```

Each agent writes to `.trinity/agents/{Z}/HIVELOG.md` and releases locks.

### Phase 4: DEACTIVATE

```bash
for Z in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z; do
  tri agent deactivate $Z
done
```

Queen reads final summary and writes to `.trinity/queen/HIVELOG.md`:

```markdown
[<timestamp>] SWARM-ALPHA(<plan>): Completed. 27 agents cycled.
```

---

## Trinity Swarm Alphabet — 27 Agents

> This is a **Trinity-specific parcellation** based on brain patterns and insect colony castes, not empirical neuroanatomy.

| Letter | Agent Name (1 word) | Role/Image | Superpower |
|--------|---------------------|-----------|-----------|
| **A** | Accumen | Nucleus accumbens / reward | Learns what brings **reward**; optimizes ROI and reinforcement |
| **B** | Basal | Basal ganglia / policy | Makes **action choices**, switches policies, gates motor/code paths |
| **C** | Cerebellum | Cerebellum / modeling | Tuning and **error correction**; fine-tunes details and coordination |
| **D** | Depin | Distributed infra | Watches **cluster/networks**, deploy, resources, traffic reroute |
| **E** | Evaluon | Eval/metrics | Hard **judge**: metrics, statistical significance, benchmark comparison |
| **F** | Firecore | LLM engine | Knows all about **model core**: tokens, context, throughput |
| **G** | Gateway | Proxy/bridge | Makes **bridges**: APIs, proxies, safe boundaries between worlds |
| **H** | Hippoc | Hippocampus | Keeps **episodic memory**: episodes, tdgs-history, recall |
| **I** | Insular | Insula | Feels **internal state**: loads, fatigue, system "pains" |
| **J** | Jitter | JIT/compilation | Responsible for **build and optimization** (JIT, build paths, profiling) |
| **K** | Kagglion | Kaggle/bench | Runs **Kaggle/Trinity Cognitive Probes**, baselines, UX |
| **L** | Lingua | Language | Works with **languages**: prompts, localization, language patterns |
| **M** | Motorix | Motor | Moves **actions**: tri CLI, start/stop workers, scripts |
| **N** | Netron | Network | Monitors **network and protocols**: WebSockets, MCP, RPC |
| **O** | Oracle | Watchdog/oracle | Makes **predictions and sanity-checks**; alerts, anomalies |
| **P** | Phoenix | Brainstem | Holds **lifecycle**: heartbeats, sleep/wake, reboot/repair |
| **Q** | Queen | PFC / coordinator | **Coordinates swarm**: reads thalamus, assigns tasks, resolves conflicts |
| **R** | Reticula | Reticular formation | **Vigilance**: watch-daemon, arousal levels, wake/sleep sweep |
| **S** | Striaton | Striatum/Nigra | Tunes **action loops**: habits, repetitions, reward gating |
| **T** | Temple | TTT / meta-PFC | Stores **laws**: sacred math, types, TRI-27, TTT Seal (SEALED) |
| **U** | UIthimus | UI / interface | Responsible for **interfaces**: Telegram/web, visual reports |
| **V** | Vectora | VSA / representations | Works with **vector representations**, VSA, embedding spaces |
| **W** | Orbiton | OFC | Forms **context and mood assessment**; formats messages |
| **X** | Xalamus | Thalamus | **Communication bus**: relays, normalizes flows to Queen |
| **Y** | Yabenula | Habenula | Monitors **anti-reward**: punishments, degradations, red flags |
| **Z** | Zallosum | Corpus callosum | **Connects hemispheres/zones**: syncs different letters, inter-zone pipelines |

Each agent gets its own directory `src/{LETTER}/` and home in `.trinity/agents/{LETTER}/`. The role is a fixed **competence domain**, like worker vs soldier vs queen castes in eusocial insects.

---

## The 27 Zones (Technical Mapping)

| Letter | Path | Brain Region | TRI-27 Register | Role | Sealed |
|--------|------|--------------|-----------------|------|--------|
| **T** | `src/temple/` | Temple (meta-layer) | All banks | Sacred math, types, VM, tri | YES |
| **Q** | `src/Q/` | PFC (Queen) | rho17 (sacred) | Executive coordination | No |
| **P** | `src/P/` | Brainstem (Phoenix) | sigma18-omega24 | Vital functions | No |
| **H** | `src/H/` | Hippocampus | mu12 | Episodic memory | No |
| **R** | `src/R/` | Reticular | nu13-xi14 | Watch-daemon, arousal | No |
| **A** | `src/A/` | ACCumens | alpha0-beta1 | Reward prediction | No |
| **B** | `src/B/` | Basal Ganglia | gamma2-delta3 | Action selection | No |
| **C** | `src/C/` | Cerebellum | epsilon4-zeta5 | Motor coordination | No |
| **D** | `src/D/` | Depin | theta6-eta7 | Distributed systems | No |
| **F** | `src/F/` | Firebird | theta8-iota9 | LLM engine | No |
| **I** | `src/I/` | Insula | kappa10-lambda11 | Interoception | No |
| **S** | `src/S/` | Striatum/Nigra | mu12-nu13 | Basal ganglia loops | No |
| **V** | `src/V/` | VSA | xi14-omicron15 | Vector symbols | No |
| **W** | `src/W/` | OFC | pi16-rho17 | Value judgment | No |
| **X** | `src/X/` | Thalamus | sigma18-tau19 | Sensory gateway | No |
| **Y** | `src/Y/` | Habenula | upsilon20-phi21 | Anti-reward | No |
| **Z** | `src/Z/` | Callosum | chi22-psi23 | Hemisphere bridge | No |
| **K** | `src/K/` | Kaggle | omega24-omega25 | Benchmark dataset | No |
| **L** | `src/L/` | Language | shmima26 | NLP/linguistics | No |
| **M** | `src/M/` | Motor | (wrap to T) | Motor control | No |
| **N** | `src/N/` | Network | (wrap to T) | Comms/protocol | No |
| **O** | `src/O/` | Oracle | (wrap to T) | Watchdog | No |
| **U** | `src/U/` | UI | (wrap to T) | Interface | No |
| **E** | `src/E/` | Eval | (wrap to T) | Metrics/scoring | No |
| **G** | `src/G/` | Gateway | (wrap to T) | Bridge/proxy | No |
| **J** | `src/J/` | JIT | (wrap to T) | Compilation | No |

## T-Zone: Temple Core (SEALED)

**Path**: `src/temple/`

**Contents**:
- `sacred_math.zig` — phi²+1/phi²=3, Trit, Trit27, ternary logic
- `tri27_core.zig` — TRI-27 ISA, Memory, Opcodes
- `tri_lang_core.zig` — Result, Patterns, Linear, Effects
- `tests.zig` — Self-contained unit tests

**Sealed by**: TTT Seal — requires `TEMPLE_RITUAL` + Queen/user approval

**Mapping to Coptic**: All 27 registers accessible, but T-zone owns the sacred bank (t9-t17)

**Related (T-adjacent, NOT sealed)**:
- `src/tri-lang/` — Type system, compiler (HM, emit_t27)
- `src/vibeec/` — VIBEE IR bridge
- `src/tri27/` — VM emulator
These evolve via normal tri/agent workflow but respect T-zone interfaces.

## Alphabet Law

1. **Each module** MUST declare its zone letter in path
2. **Zone determines** brain region mapping, TRI-27 register affinity, and governance
3. **T-zone** is sacred — sealed by TTT, changes require ritual
4. **Cross-zone calls** allowed but MUST respect zone boundaries

## TRI-27 Integration

Each zone corresponds to Coptic register banks:
- **Bank 0 (ALU)**: t0-t8 (alpha0-eta7) — Fast computation zones
- **Bank 1 (Sacred)**: t9-t17 (iota9-rho17) — T-zone, Queen, OFC
- **Bank 2 (Const)**: t18-t26 (sigma18-shmima26) — Const values, config

Zone's letter determines preferred register bank for TRI-27 codegen.

## Migration Path

See TDGS-4: Alphabet Canon 27 — step-by-step repository reorganization.

## References

- `docs/research/neuroanatomical_architecture.md` — NA-R9, NA-R10, NA-R11
- `.trinity/canonmap.json` — Official canon with alphabet_zones
- `src/tri27/coptic.zig` — Coptic 27-register system
