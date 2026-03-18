# Trinity Project Structure

**Last Updated:** 2026-02-18
**Version:** 2.0 (Reorganized)

---

## 📁 Directory Structure

```
trinity/
├── 📂 src/                    # Main source code
│   ├── core/                  # Core VM & runtime
│   ├── lang/                  # VIBEE compiler
│   ├── symb/                  # Symbolic AI (VSA, KG)
│   ├── network/               # P2P, DHT, consensus
│   ├── canvas/                # UI & visualization
│   ├── tools/                 # CLI & utilities
│   ├── vibeec/                # Code generators
│   ├── economy/               # $TRI rewards system
│   └── phi-engine/            # Φ-optimizations
│
├── 📂 trinity-nexus/          # Modular workspace (NEW)
│   ├── core/                  # Core module
│   ├── lang/                  # Language module
│   ├── symb/                  # Symbolic module
│   ├── network/               # Network module
│   ├── canvas/                # Canvas module
│   ├── tools/                 # Tools module
│   ├── docs/                  # Documentation
│   │   ├── book/              # Trinity Book
│   │   └── plans/             # Development plans
│   ├── extensions/            # Browser & VS Code extensions
│   ├── benchmarks/            # Performance benchmarks
│   ├── contracts/             # Smart contracts
│   ├── deploy/                # Deployment configs
│   └── tests/                 # Test suites
│
├── 📂 models/                 # ALL models in one place
│   ├── bitnet/                # BitNet models
│   ├── mistral/               # Mistral models
│   ├── qwen/                  # Qwen models
│   ├── tinyllama/             # TinyLLaMA models
│   ├── test/                  # Test models (*.tri)
│   ├── vocab/                 # Vocabulary files
│   └── embeddings/            # Embedding models
│
├── 📂 specs/                  # .vibee specifications
│   └── tri/                   # Trinity specs
│
├── 📂 generated/              # Generated code from specs
│
├── 📂 examples/               # Working examples
│   └── *.tri                  # Trinity programs
│
├── 📂 docs/                   # Documentation
│   ├── api/                   # API documentation
│   ├── architecture/          # Architecture docs
│   └── guides/                # User guides
│
├── 📂 docsite/                # Docusaurus documentation site (ACTIVE)
├── 📂 website/                # Main Trinity website (ACTIVE)
│
├── 📂 deploy/                 # Deployment
│   ├── docker/                # Docker configs
│   └── kubernetes/            # K8s configs
│
├── 📂 scripts/                # Utility scripts
│
├── 📂 libs/                   # External libraries
│
├── 📂 config/                 # Configuration files
│
├── 📂 .ralph/                 # Ralph autonomous agent
│   ├── golden_chain/          # Golden Chain docs
│   ├── internal/              # Internal state
│   └── scripts/               # Ralph scripts
│
├── 📂 archive/                # Archived code
│   ├── frontend/              # Old frontend projects
│   └── old/                   # Legacy code
│
├── 📄 build.zig               # Build system
├── 📄 README.md               # This file
└── 📄 LICENSE                 # MIT License

```

---

## 🎯 Key Principles

### 1. One Place for Models
ALL models (`.tri`, `.safetensors`, `config.json`) are in `models/`

### 2. Modular Architecture
`trinity-nexus/` contains clean, modular workspace

### 3. Spec-Driven Development
- Specs in `specs/`
- Generated code in `generated/`
- **NO direct .zig editing**

### 4. Clear Separation
- **Source:** `src/` and `trinity-nexus/`
- **Models:** `models/`
- **Docs:** `docs/` and `trinity-nexus/docs/`
- **Archive:** `archive/`

---

## 🚀 Quick Start

### Build
```bash
zig build
```

### Test
```bash
zig build test
```

### Run
```bash
zig build run -- --help
```

---

## 📊 Project Stats

| Category | Count |
|----------|-------|
| Source Files | ~500 |
| Specs | ~100 |
| Models | ~20 |
| Tests | ~200 |
| Examples | ~10 |

---

## 📝 See Also

- **Tech Tree:** `.ralph/TECH_TREE.md`
- **Cleanup Plan:** `.ralph/PROJECT_CLEANUP_PLAN.md`
- **Golden Chain:** `.ralph/golden_chain/`
- **Architecture:** `trinity-nexus/docs/`

---

**Reorganized:** 2026-02-18
**Previous Structure:** 40+ top-level directories
**Current Structure:** 15 top-level directories
**Improvement:** 62.5% reduction in clutter
