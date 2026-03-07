// =============================================================================
// UNIFIED COMMAND TABLE — Master Registry
// =============================================================================
//
// SINGLE SOURCE OF TRUTH for all TRI commands.
// This file contains metadata ONLY (no execute function pointers).
// Execute functions are wired in by CLI consumer (tri_register.zig).
//
// To add a new command: add an entry here. CLI, MCP, API, and docs
// will all pick it up automatically.
//
// =============================================================================

const std = @import("std");
pub const def = @import("command_def.zig");
const CommandDef = def.CommandDef;
pub const CommandCategory = def.CommandCategory;
const InputParam = def.InputParam;

/// All REST + GraphQL + gRPC + WebSocket protocols
const ALL_PROTOCOLS = &[_]def.ApiProtocol{ .REST, .GRAPHQL, .GRPC, .WEBSOCKET };
const REST_GRAPHQL = &[_]def.ApiProtocol{ .REST, .GRAPHQL };
const REST_ONLY = &[_]def.ApiProtocol{.REST};

/// Master command table — every TRI command defined once
pub const all_commands = [_]CommandDef{

    // =========================================================================
    // SACRED SCIENCE (v14-v16)
    // =========================================================================

    .{
        .name = "bio",
        .aliases = &.{"biology"},
        .description = "Biology v14.0 — DNA/RNA/Protein sacred analysis",
        .long_help = "Analyze DNA, RNA, and protein sequences with sacred mathematics.\nUses \xcf\x86-spiral encoding and Fibonacci patterns found in nature.",
        .category = .science,
        .examples = &.{ "tri bio dna ATGCGT", "tri bio rna AUGCCAUAA", "tri bio protein MVHLTPEEK", "tri bio codon ATG" },
        .has_subcommands = true,
        .subcommands = &.{
            .{ .name = "dna", .description = "Analyze DNA sequence", .example = "tri bio dna ATGCGTACGT" },
            .{ .name = "rna", .description = "Translate RNA to amino acids", .example = "tri bio rna AUGCCAUAA" },
            .{ .name = "protein", .description = "Protein \xcf\x86-spiral analysis", .example = "tri bio protein MVHLTPEEK" },
            .{ .name = "codon", .description = "Look up codon table", .example = "tri bio codon ATG" },
        },
        .mcp_enabled = true,
        .mcp_name = "tri_bio_dna",
        .mcp_display_name = "DNA Analysis",
        .input_params = &.{
            .{ .name = "sequence", .param_type = .string, .description = "DNA/RNA/Protein sequence", .required = true },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 30,
    },

    .{
        .name = "cosmos",
        .aliases = &.{"cosmology"},
        .description = "Cosmology v15.0 — Universe through \xcf\x86",
        .long_help = "Explore the universe through sacred mathematics.\nHubble tension resolution via \xcf\x86, dark energy \xcf\x80-patterns.",
        .category = .science,
        .examples = &.{ "tri cosmos hubble", "tri cosmos dark", "tri cosmos w-z", "tri cosmos lambda-z", "tri cosmos phantom", "tri cosmos consciousness-de" },
        .mcp_enabled = true,
        .mcp_name = "tri_cosmos_hubble",
        .mcp_display_name = "Hubble Tension",
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 30,
    },

    .{
        .name = "dm",
        .aliases = &.{ "dark", "dark-matter", "darkmatter" },
        .description = "Dark Matter v14.1 — \xcf\x86-\xce\xb3 based candidate beyond WIMPs",
        .long_help = "A \xcf\x86-\xce\xb3 based dark matter candidate that explains why WIMPs failed.\nParticle mass m_\xcf\x87 = \xcf\x86\xe2\x81\xb5 \xc3\x97 m_p \xe2\x89\x88 10 GeV, cross-section \xcf\x83_\xcf\x87N = \xce\xb3\xe2\x81\xb6 \xc3\x97 \xcf\x83_weak.",
        .category = .science,
        .examples = &.{ "tri dm physics", "tri dm halo", "tri dm detection", "tri dm wimp" },
        .mcp_enabled = false,
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 30,
    },

    .{
        .name = "neuro",
        .aliases = &.{"neuroscience"},
        .description = "Neuroscience v16.0 — Brain as sacred computer",
        .long_help = "The brain as a \xcf\x86-patterned sacred computer.\nBrain waves follow golden ratio patterns.",
        .category = .science,
        .examples = &.{ "tri neuro waves", "tri neuro consciousness", "tri neuro regions", "tri neuro network" },
        .mcp_enabled = false,
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 30,
    },

    .{
        .name = "gravity",
        .aliases = &.{"black-hole", "blackhole"},
        .description = "Black Hole Information Paradox v16.0 — \xcf\x86-\xce\xb3 solution",
        .long_help = "Black hole information paradox resolved via sacred mathematics.\nPage curve, ER=EPR bridges, holographic entropy, consciousness connection.",
        .category = .science,
        .examples = &.{ "tri gravity information", "tri gravity er-epr", "tri gravity holographic", "tri gravity observer" },
        .has_subcommands = true,
        .subcommands = &.{
            .{ .name = "information", .description = "Information paradox resolution", .example = "tri gravity information" },
            .{ .name = "er-epr", .description = "ER=EPR bridge conjecture", .example = "tri gravity er-epr" },
            .{ .name = "holographic", .description = "Holographic entropy bound", .example = "tri gravity holographic" },
            .{ .name = "observer", .description = "Observer effect solutions", .example = "tri gravity observer" },
        },
        .mcp_enabled = false,
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 30,
    },

    // =========================================================================
    // MATH — Sacred Mathematics
    // =========================================================================

    .{
        .name = "math",
        .aliases = &.{},
        .description = "Sacred mathematics dispatcher",
        .long_help = "Golden ratio \xcf\x86, Lucas numbers, sacred geometry.",
        .category = .math,
        .examples = &.{ "tri math", "tri constants", "tri phi 10", "tri fib 20" },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "constants",
        .aliases = &.{ "const", "c" },
        .description = "Display sacred constants (\xcf\x86, \xcf\x80, e, \xce\xbc, \xcf\x87, \xcf\x83, \xce\xb5)",
        .long_help = "Show all sacred mathematics constants used in Trinity.",
        .category = .math,
        .examples = &.{"tri constants"},
        .mcp_enabled = true,
        .mcp_name = "tri_constants",
        .mcp_display_name = "Sacred Constants",
        .api_enabled = true,
        .api_protocols = ALL_PROTOCOLS,
        .api_rate_limit = 200,
    },

    .{
        .name = "phi",
        .aliases = &.{},
        .description = "Compute \xcf\x86\xe2\x81\xbf (golden ratio power)",
        .long_help = "Calculate the nth power of the golden ratio \xcf\x86 = (1+\xe2\x88\x9a5)/2.",
        .category = .math,
        .examples = &.{ "tri phi 10", "tri phi 100" },
        .mcp_enabled = true,
        .mcp_name = "tri_phi",
        .mcp_display_name = "Phi Power",
        .input_params = &.{
            .{ .name = "n", .param_type = .integer, .description = "Power of phi", .required = true },
        },
        .api_enabled = true,
        .api_protocols = ALL_PROTOCOLS,
        .api_rate_limit = 200,
    },

    .{
        .name = "fib",
        .aliases = &.{"fibonacci"},
        .description = "Fibonacci numbers with BigInt",
        .long_help = "Calculate Fibonacci numbers F(n) using arbitrary precision.",
        .category = .math,
        .examples = &.{ "tri fib 10", "tri fib 100" },
        .mcp_enabled = true,
        .mcp_name = "tri_fib",
        .mcp_display_name = "Fibonacci",
        .input_params = &.{
            .{ .name = "n", .param_type = .integer, .description = "Fibonacci index", .required = true },
        },
        .api_enabled = true,
        .api_protocols = ALL_PROTOCOLS,
        .api_rate_limit = 200,
    },

    .{
        .name = "lucas",
        .aliases = &.{},
        .description = "Lucas numbers (L(2)=3=TRINITY)",
        .long_help = "Calculate Lucas numbers L(n). L(2)=3 represents TRINITY.",
        .category = .math,
        .examples = &.{ "tri lucas 10", "tri lucas 20" },
        .mcp_enabled = true,
        .mcp_name = "tri_lucas",
        .mcp_display_name = "Lucas Numbers",
        .input_params = &.{
            .{ .name = "n", .param_type = .integer, .description = "Lucas index", .required = true },
        },
        .api_enabled = true,
        .api_protocols = ALL_PROTOCOLS,
        .api_rate_limit = 200,
    },

    .{
        .name = "spiral",
        .aliases = &.{},
        .description = "\xcf\x86-spiral coordinates",
        .long_help = "Generate golden spiral coordinates for visualization.",
        .category = .math,
        .examples = &.{"tri spiral 10"},
        .mcp_enabled = true,
        .mcp_name = "tri_spiral",
        .mcp_display_name = "Phi Spiral",
        .input_params = &.{
            .{ .name = "points", .param_type = .integer, .description = "Number of spiral points", .required = true },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "gematria",
        .aliases = &.{},
        .description = "Gematria word value calculator",
        .long_help = "Calculate gematria values using Hebrew/English systems.",
        .category = .math,
        .examples = &.{"tri gematria hello"},
        .mcp_enabled = true,
        .mcp_name = "tri_gematria",
        .mcp_display_name = "Gematria",
        .input_params = &.{
            .{ .name = "text", .param_type = .string, .description = "Text to analyze", .required = true },
            .{ .name = "language", .param_type = .string, .description = "Language system" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "formula",
        .aliases = &.{},
        .description = "Sacred formula evaluator",
        .long_help = "Evaluate sacred mathematical formulas.",
        .category = .math,
        .examples = &.{"tri formula 'phi^2 + 1/phi^2'"},
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "particles",
        .aliases = &.{ "particle", "pdg" },
        .description = "Particle physics sacred formulas (49 constants from \xcf\x86)",
        .long_help = "Derive Standard Model constants from the golden ratio.\nAll formulas achieve sub-0.1% accuracy vs PDG 2024 data.\nCovers quarks, leptons, bosons, mixing angles, and cosmology.",
        .category = .science,
        .examples = &.{ "tri particles", "tri particles all", "tri particles tier1", "tri particles search alpha_s" },
        .has_subcommands = true,
        .subcommands = &.{
            .{ .name = "all", .description = "Show all 49 sacred particle constants", .example = "tri particles all" },
            .{ .name = "tier1", .description = "Tier 1: electron, quark masses, \xce\xb1", .example = "tri particles tier1" },
            .{ .name = "tier2", .description = "Tier 2: muon, tau, leptons", .example = "tri particles tier2" },
            .{ .name = "tier3", .description = "Tier 3: bosons, mixing angles", .example = "tri particles tier3" },
            .{ .name = "search", .description = "Search particle by name or symbol", .example = "tri particles search W_boson" },
            .{ .name = "cosmology", .description = "Cosmological constants (\xce\xa9_\xce\x9b, \xce\xa9_DM, H0)", .example = "tri particles cosmology" },
        },
        .mcp_enabled = true,
        .mcp_name = "tri_particles",
        .mcp_display_name = "Particle Physics Sacred",
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 30,
    },

    .{
        .name = "sacred",
        .aliases = &.{},
        .description = "Sacred mathematics utilities",
        .long_help = "Various sacred mathematics operations and visualizations.",
        .category = .science,
        .examples = &.{ "tri sacred", "tri sacred trinity" },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    // =========================================================================
    // MUSIC v1.0 — Sacred Acoustics
    // =========================================================================

    .{
        .name = "music",
        .aliases = &.{ "audio", "sound" },
        .description = "Sacred Music v1.0 — \xcf\x86-based acoustics",
        .long_help = "Sacred acoustics with golden ratio harmonics, Solfeggio frequencies, and resonance patterns.",
        .category = .science,
        .examples = &.{"tri music"},
        .has_subcommands = true,
        .subcommands = &.{
            .{ .name = "frequency", .description = "Calculate frequency from note", .example = "tri music frequency A4" },
            .{ .name = "scale", .description = "Display musical scale notes and frequencies", .example = "tri music scale C-major" },
            .{ .name = "chord", .description = "Analyze chord harmonics", .example = "tri music chord C-major7" },
            .{ .name = "resonance", .description = "Calculate resonance patterns", .example = "tri music resonance 432" },
            .{ .name = "waveform", .description = "Generate waveform samples", .example = "tri music waveform sine 440" },
            .{ .name = "harmony", .description = "Analyze harmonic relationship", .example = "tri music harmony A4 E5" },
            .{ .name = "phi-series", .description = "Show \xcf\x86 frequency series", .example = "tri music phi-series" },
            .{ .name = "solfeggio", .description = "Solfeggio sacred frequencies", .example = "tri music solfeggio" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "frequency",
        .aliases = &.{ "freq", "note-freq" },
        .description = "Calculate frequency from note",
        .long_help = "Convert musical note to frequency (Hz).",
        .category = .science,
        .examples = &.{ "tri frequency A4", "tri freq C5 --sacred" },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "scale",
        .aliases = &.{},
        .description = "Display musical scale notes and frequencies",
        .category = .science,
        .examples = &.{ "tri scale C major", "tri scale D phi" },
    },

    .{
        .name = "chord",
        .aliases = &.{},
        .description = "Analyze chord harmonics",
        .category = .science,
        .examples = &.{ "tri chord C major", "tri chord A phi" },
    },

    .{
        .name = "resonance",
        .aliases = &.{"res"},
        .description = "Calculate resonance patterns",
        .category = .science,
        .examples = &.{ "tri resonance 432", "tri resonance 528 10" },
    },

    .{
        .name = "waveform",
        .aliases = &.{ "wave", "osc" },
        .description = "Generate waveform samples",
        .category = .science,
        .examples = &.{ "tri waveform phi-spiral", "tri wave sine 32" },
    },

    .{
        .name = "harmony",
        .aliases = &.{},
        .description = "Analyze harmonic relationship between frequencies",
        .category = .science,
        .examples = &.{ "tri harmony 432 528" },
    },

    .{
        .name = "phi-series",
        .aliases = &.{ "phi-freq", "phi-frequencies" },
        .description = "Show \xcf\x86 frequency series",
        .category = .science,
        .examples = &.{ "tri phi-series 432", "tri phi-series 1 12" },
    },

    // =========================================================================
    // AI & CHAT
    // =========================================================================

    .{
        .name = "chat",
        .aliases = &.{"c"},
        .description = "Interactive chat (vision + voice + tools)",
        .long_help = "Full-featured chat with multimodal input, streaming output, and tool use.",
        .category = .ai,
        .examples = &.{ "tri chat 'explain zig'", "tri chat --stream", "tri chat --image path.jpg 'describe this'" },
        .api_enabled = true,
        .api_protocols = ALL_PROTOCOLS,
        .api_rate_limit = 10,
    },

    .{
        .name = "code",
        .aliases = &.{},
        .description = "Generate code with typing effect",
        .long_help = "AI code generation with typewriter animation.",
        .category = .ai,
        .examples = &.{"tri code 'create a web server'"},
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 10,
    },

    // =========================================================================
    // SWE AGENT (Software Engineering)
    // =========================================================================

    .{
        .name = "fix",
        .aliases = &.{},
        .description = "Detect and fix bugs automatically",
        .long_help =
            \\SWE agent: Analyze code, find bugs, and apply fixes.
            \\
            \\Scans the target file for:
            \\- Compilation errors
            \\- Logic bugs
            \\- Memory leaks
            \\- Race conditions
            \\- Code smells
            \\
            \\Creates backup before modifying. Use with version control.
        ,
        .category = .dev,
        .examples = &.{
            "tri fix src/main.zig",
            "tri fix src/vsa.zig --dry-run",
            "tri fix src/memory.zig --no-backup",
        },
        .input_params = &.{
            .{ .name = "file", .param_type = .string, .description = "Path to Zig file to fix", .required = true },
            .{ .name = "dry_run", .param_type = .boolean, .description = "Show changes without modifying (default: false)" },
            .{ .name = "backup", .param_type = .boolean, .description = "Create backup before fixing (default: true)" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 10,
    },

    .{
        .name = "explain",
        .aliases = &.{"exp"},
        .description = "Explain code or concept in detail",
        .long_help =
            \\SWE agent: Provide detailed explanations of code, algorithms, or concepts.
            \\
            \\Analyzes:
            \\- Code structure and patterns
            \\- Algorithm complexity
            \\- Data flow
            \\- Dependencies
            \\
            \\Can explain files, functions, or general programming concepts.
        ,
        .category = .dev,
        .examples = &.{
            "tri explain src/vsa.zig",
            "tri explain 'how does bind operation work'",
            "tri explain src/vm.zig --verbose",
        },
        .input_params = &.{
            .{ .name = "file", .param_type = .string, .description = "Path to file, or concept to explain", .required = true },
            .{ .name = "verbose", .param_type = .boolean, .description = "Show more detailed explanation" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 10,
    },

    .{
        .name = "test",
        .aliases = &.{},
        .description = "Generate comprehensive test suites",
        .long_help =
            \\SWE agent: Create comprehensive test suites from code.
            \\
            \\Generates:
            \\- Unit tests for functions
            \\- Edge case coverage
            \\- Property-based tests
            \\- Integration test stubs
            \\
            \\Output follows Zig testing conventions.
        ,
        .category = .dev,
        .examples = &.{
            "tri test src/vsa.zig",
            "tri test src/math/commands.zig --output tests/math_test.zig",
            "tri test src/crypto.zig --coverage",
        },
        .input_params = &.{
            .{ .name = "file", .param_type = .string, .description = "Path to file to test", .required = true },
            .{ .name = "output", .param_type = .string, .description = "Output test file path" },
            .{ .name = "coverage", .param_type = .boolean, .description = "Include coverage markers" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 10,
    },

    .{
        .name = "doc",
        .aliases = &.{"document"},
        .description = "Generate documentation from code",
        .long_help =
            \\SWE agent: Create documentation from code structure and comments.
            \\
            \\Generates:
            \\- Function documentation
            \\- Module overviews
            \\- Usage examples
            \\- Type descriptions
            \\
            \\Output in Markdown format suitable for docs/.
        ,
        .category = .dev,
        .examples = &.{
            "tri doc src/vsa.zig",
            "tri doc src/ --output docs/api.md",
            "tri doc src/sacred/ --full",
        },
        .input_params = &.{
            .{ .name = "file", .param_type = .string, .description = "Path to file or directory", .required = true },
            .{ .name = "output", .param_type = .string, .description = "Output documentation file" },
            .{ .name = "full", .param_type = .boolean, .description = "Generate full documentation with examples" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 10,
    },

    .{
        .name = "refactor",
        .aliases = &.{},
        .description = "Suggest and apply code refactoring",
        .long_help =
            \\SWE agent: Suggest and apply code improvements.
            \\
            \\Detects:
            \\- Code duplication
            \\- Long functions
            \\- Complex conditionals
            \\- Poor naming
            \\- Missing abstractions
            \\
            \\Shows diff before applying changes.
        ,
        .category = .dev,
        .examples = &.{
            "tri refactor src/main.zig",
            "tri refactor src/vsa.zig --aggressive",
            "tri refactor src/ --dry-run",
        },
        .input_params = &.{
            .{ .name = "file", .param_type = .string, .description = "Path to file to refactor", .required = true },
            .{ .name = "aggressive", .param_type = .boolean, .description = "Apply more aggressive refactoring" },
            .{ .name = "dry_run", .param_type = .boolean, .description = "Show suggestions without applying" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 10,
    },

    .{
        .name = "reason",
        .aliases = &.{},
        .description = "Chain-of-thought reasoning",
        .long_help =
            \\SWE agent: Step-by-step logical reasoning for complex problems.
            \\
            \\Breaks down problems into:
            \\1. Problem analysis
            \\2. Hypothesis generation
            \\3. Step-by-step derivation
            \\4. Conclusion
            \\
            \\Use for debugging, algorithm design, or learning.
        ,
        .category = .ai,
        .examples = &.{
            "tri reason 'how does VSA similarity work'",
            "tri reason 'why is my memory leak happening'",
            "tri reason 'design a hash table for 10M items'",
        },
        .input_params = &.{
            .{ .name = "prompt", .param_type = .string, .description = "Question or problem to reason about", .required = true },
            .{ .name = "depth", .param_type = .integer, .description = "Reasoning depth (1-5, default: 3)" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 10,
    },

    // =========================================================================
    // GIT COMMANDS
    // =========================================================================

    .{
        .name = "commit",
        .aliases = &.{},
        .description = "Stage all changes and create a commit",
        .long_help =
            \\Git add -A && commit with message.
            \\
            \\Stages all changes (tracked and untracked) and creates a commit.
            \\Conventional commit format recommended: "type: description"
            \\
            \\Types: feat, fix, docs, style, refactor, test, chore
        ,
        .category = .git,
        .examples = &.{
            "tri commit 'feat: add VSA semantic search'",
            "tri commit 'fix: memory leak in bind operation'",
            "tri commit 'docs: update README with examples'",
        },
        .input_params = &.{
            .{ .name = "message", .param_type = .string, .description = "Commit message", .required = true },
        },
        .api_enabled = true,
        .api_protocols = REST_ONLY,
        .api_auth_required = true,
    },

    .{
        .name = "diff",
        .aliases = &.{},
        .description = "Show unstaged changes",
        .long_help =
            \\Git diff: Show changes between working tree and index.
            \\
            \\Displays:
            \\- Modified lines (red for removed, green for added)
            \\- File paths
            \\- Line numbers
            \\
            \\Use to review changes before committing.
        ,
        .category = .git,
        .examples = &.{
            "tri diff",
            "tri diff --cached",
        },
        .input_params = &.{
            .{ .name = "cached", .param_type = .boolean, .description = "Show staged changes instead of unstaged" },
        },
        .api_enabled = true,
        .api_protocols = REST_ONLY,
    },

    .{
        .name = "status",
        .aliases = &.{"st"},
        .description = "Show working tree status",
        .long_help =
            \\Git status --short: Show repository state.
            \\
            \\Shows:
            \\- Modified files (M)
            \\- Added files (A)
            \\- Deleted files (D)
            \\- Untracked files (?)
            \\
            \\Format: XY filename (X=staged, Y=unstaged)
        ,
        .category = .git,
        .examples = &.{
            "tri status",
            "tri st",
        },
        .api_enabled = true,
        .api_protocols = REST_ONLY,
    },

    .{
        .name = "log",
        .aliases = &.{},
        .description = "Show recent commit history",
        .long_help =
            \\Git log --oneline -10: Show last 10 commits.
            \\
            \\Displays:
            \\- Commit hash (abbreviated)
            \\- Commit message
            \\
            \\Shows most recent commits first.
        ,
        .category = .git,
        .examples = &.{
            "tri log",
            "tri log --20",
        },
        .input_params = &.{
            .{ .name = "count", .param_type = .integer, .description = "Number of commits to show (default: 10)" },
        },
        .api_enabled = true,
        .api_protocols = REST_ONLY,
    },

    // =========================================================================
    // GOLDEN CHAIN PIPELINE
    // =========================================================================

    .{
        .name = "pipeline",
        .aliases = &.{},
        .description = "Execute 22-link Golden Chain v4.0",
        .long_help = "Run the full development pipeline from spec to deployment.",
        .category = .advanced,
        .examples = &.{"tri pipeline run mytask"},
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "pipeline-demo",
        .aliases = &.{},
        .description = "Pipeline demo — show Golden Chain workflow",
        .category = .demo,
    },

    .{
        .name = "decompose",
        .aliases = &.{},
        .description = "Break task into sub-tasks (Link 4)",
        .category = .advanced,
        .examples = &.{"tri decompose 'build a web server'"},
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "plan",
        .aliases = &.{},
        .description = "Generate implementation plan (Link 5)",
        .category = .advanced,
        .examples = &.{"tri plan 'add feature'"},
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "spec-create",
        .aliases = &.{"spec_create"},
        .description = "Create .vibee spec template (Link 6)",
        .category = .dev,
        .examples = &.{"tri spec-create mymodule"},
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "loop-decide",
        .aliases = &.{"loop_decide"},
        .description = "Loop decision: CONTINUE/EXIT (Link 17)",
        .category = .advanced,
        .examples = &.{ "tri loop-decide auto", "tri loop-decide" },
    },

    .{
        .name = "verify",
        .aliases = &.{},
        .description = "Run tests + benchmarks (Links 7-11)",
        .category = .dev,
        .examples = &.{"tri verify"},
        .api_enabled = true,
        .api_protocols = REST_ONLY,
    },

    .{
        .name = "toxic-verdict",
        .aliases = &.{"toxic"},
        .description = "Generate toxic verdict (Link 14)",
        .category = .advanced,
        .examples = &.{"tri toxic-verdict"},
    },

    // =========================================================================
    // VIBEE COMPILATION
    // =========================================================================

    .{
        .name = "gen",
        .aliases = &.{"generate"},
        .description = "Compile VIBEE spec to Zig/Verilog/Python",
        .long_help =
            \\VIBEE compiler: Generate code from specification files.
            \\
            \\Languages:
            \\- Zig (default)
            \\- Verilog (for FPGA)
            \\- Python
            \\- C, C++, Rust, Java, JavaScript, TypeScript, and more
            \\
            \\Output: trinity/output/{language}/{name}.{ext}
        ,
        .category = .dev,
        .examples = &.{
            "tri gen specs/tri/my_module.vibee",
            "tri gen specs/fpga/blink.vibee",
            "tri gen specs/api/server.vibee",
        },
        .input_params = &.{
            .{ .name = "spec", .param_type = .string, .description = "Path to .vibee spec file", .required = true },
            .{ .name = "output", .param_type = .string, .description = "Custom output directory" },
            .{ .name = "verbose", .param_type = .boolean, .description = "Show detailed generation info" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_rate_limit = 10,
    },

    .{
        .name = "convert",
        .aliases = &.{},
        .description = "Convert between file formats",
        .long_help =
            \\Convert models and data between formats.
            \\
            \\Supported conversions:
            \\- GGUF model conversion
            \\- Ternary <-> Binary formats
            \\- VSA <-> JSON
        ,
        .category = .dev,
        .examples = &.{
            "tri convert model.gguf --output model.ternary",
            "tri convert data.json --format vsa",
        },
        .input_params = &.{
            .{ .name = "file", .param_type = .string, .description = "File to convert", .required = true },
            .{ .name = "output", .param_type = .string, .description = "Output file path" },
            .{ .name = "format", .param_type = .string, .description = "Target format" },
        },
        .api_enabled = true,
        .api_protocols = REST_ONLY,
    },

    .{
        .name = "serve",
        .aliases = &.{"server"},
        .description = "Start HTTP API server",
        .long_help =
            \\Launch HTTP API server for remote access.
            \\
            \\Endpoints:
            \\- POST /api/chat - Chat completions
            \\- POST /api/generate - Code generation
            \\- GET /api/status - Server status
            \\
            \\Default port: 8080
        ,
        .category = .dev,
        .examples = &.{
            "tri serve",
            "tri serve --port 3000",
            "tri serve --host 0.0.0.0 --port 8080",
        },
        .input_params = &.{
            .{ .name = "port", .param_type = .integer, .description = "Server port (default: 8080)" },
            .{ .name = "host", .param_type = .string, .description = "Bind address (default: 127.0.0.1)" },
        },
        .api_enabled = true,
        .api_protocols = REST_ONLY,
    },

    .{
        .name = "bench",
        .aliases = &.{"benchmark"},
        .description = "Run performance benchmarks",
        .long_help =
            \\Execute performance benchmarks and generate reports.
            \\
            \\Categories:
            \\- VSA operations (bind, unbind, similarity)
            \\- Memory usage
            \\- Query throughput
            \\- LLM inference
        ,
        .category = .benchmark,
        .examples = &.{
            "tri bench",
            "tri bench --filter vsa",
            "tri bench --output report.json",
        },
        .input_params = &.{
            .{ .name = "filter", .param_type = .string, .description = "Filter benchmarks by pattern" },
            .{ .name = "output", .param_type = .string, .description = "Output report file" },
            .{ .name = "iterations", .param_type = .integer, .description = "Number of iterations (default: 1000)" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "evolve",
        .aliases = &.{},
        .description = "Self-improving code evolution",
        .long_help =
            \\Run autonomous self-improvement cycle.
            \\
            \\1. Analyze current codebase
            \\2. Identify optimization opportunities
            \\3. Generate improvements
            \\4. Validate with tests
            \\5. Apply changes
            \\
            \\Part of the Golden Chain Link 21: ETERNAL_SELF_EVOLUTION
        ,
        .category = .advanced,
        .examples = &.{
            "tri evolve",
            "tri evolve --iterations 5",
            "tri evolve --target src/vsa.zig",
        },
        .input_params = &.{
            .{ .name = "iterations", .param_type = .integer, .description = "Number of evolution cycles (default: 1)" },
            .{ .name = "target", .param_type = .string, .description = "Specific module to evolve" },
        },
    },

    // =========================================================================
    // TVC (Distributed Learning)
    // =========================================================================

    .{ .name = "tvc-demo", .aliases = &.{}, .description = "Run TVC chat demo", .category = .demo, .examples = &.{"tri tvc-demo"} },
    .{ .name = "tvc-stats", .aliases = &.{}, .description = "Show TVC corpus statistics", .category = .system },

    // =========================================================================
    // DEMO & BENCHMARK COMMANDS (Cycles 1-52)
    // =========================================================================

    .{ .name = "agents-demo", .aliases = &.{}, .description = "Multi-Agent coordination demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "agents-bench", .aliases = &.{}, .description = "Multi-Agent coordination benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "context-demo", .aliases = &.{}, .description = "Long context sliding window demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "context-bench", .aliases = &.{}, .description = "Long context benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "rag-demo", .aliases = &.{}, .description = "Retrieval-Augmented Generation demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "rag-bench", .aliases = &.{}, .description = "RAG benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "voice-demo", .aliases = &.{}, .description = "Voice I/O (STT+TTS) demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "voice-bench", .aliases = &.{}, .description = "Voice I/O benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "sandbox-demo", .aliases = &.{}, .description = "Code execution sandbox demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "sandbox-bench", .aliases = &.{}, .description = "Sandbox benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "stream-demo", .aliases = &.{}, .description = "Streaming multi-modal pipeline demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "stream-bench", .aliases = &.{}, .description = "Streaming benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "vision-demo", .aliases = &.{}, .description = "Local vision demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "vision-bench", .aliases = &.{}, .description = "Vision benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "finetune-demo", .aliases = &.{}, .description = "Fine-tuning engine demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "finetune-bench", .aliases = &.{}, .description = "Fine-tuning benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "batched-demo", .aliases = &.{}, .description = "Batched stealing demo", .category = .demo },
    .{ .name = "batched-bench", .aliases = &.{}, .description = "Batched stealing benchmark", .category = .benchmark },
    .{ .name = "priority-demo", .aliases = &.{}, .description = "Priority queue demo", .category = .demo },
    .{ .name = "priority-bench", .aliases = &.{}, .description = "Priority queue benchmark", .category = .benchmark },
    .{ .name = "deadline-demo", .aliases = &.{}, .description = "Deadline scheduling demo", .category = .demo },
    .{ .name = "deadline-bench", .aliases = &.{}, .description = "Deadline scheduling benchmark", .category = .benchmark },
    .{ .name = "multimodal-demo", .aliases = &.{}, .description = "Multi-modal unified demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "multimodal-bench", .aliases = &.{}, .description = "Multi-modal unified benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "tooluse-demo", .aliases = &.{}, .description = "Multi-modal tool use demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "tooluse-bench", .aliases = &.{}, .description = "Tool use benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "unified-demo", .aliases = &.{}, .description = "Unified multi-modal agent demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "unified-bench", .aliases = &.{}, .description = "Unified agent benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "autonomous-demo", .aliases = &.{}, .description = "Autonomous agent demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "autonomous-bench", .aliases = &.{}, .description = "Autonomous agent benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "orchestration-demo", .aliases = &.{}, .description = "Multi-agent orchestration demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "orchestration-bench", .aliases = &.{}, .description = "Orchestration benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "mm-orch-demo", .aliases = &.{}, .description = "MM multi-agent orchestration demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "mm-orch-bench", .aliases = &.{}, .description = "MM orchestration benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "memory-demo", .aliases = &.{}, .description = "Agent memory & cross-modal learning demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "memory-bench", .aliases = &.{}, .description = "Memory benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "persist-demo", .aliases = &.{}, .description = "Persistent memory & disk serialization demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "persist-bench", .aliases = &.{}, .description = "Persistent memory benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "spawn-demo", .aliases = &.{}, .description = "Dynamic agent spawning demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "spawn-bench", .aliases = &.{}, .description = "Spawn benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "cluster-demo", .aliases = &.{}, .description = "Distributed multi-node agents demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "cluster-bench", .aliases = &.{}, .description = "Cluster benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "worksteal-demo", .aliases = &.{}, .description = "Adaptive work-stealing scheduler demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "worksteal-bench", .aliases = &.{}, .description = "Work-stealing benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "plugin-demo", .aliases = &.{}, .description = "Plugin & extension system demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "plugin-bench", .aliases = &.{}, .description = "Plugin benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "comms-demo", .aliases = &.{}, .description = "Agent communication protocol demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "comms-bench", .aliases = &.{}, .description = "Communication benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "observe-demo", .aliases = &.{}, .description = "Observability & tracing demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "observe-bench", .aliases = &.{}, .description = "Observability benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "consensus-demo", .aliases = &.{}, .description = "Consensus & coordination demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "consensus-bench", .aliases = &.{}, .description = "Consensus benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "specexec-demo", .aliases = &.{}, .description = "Speculative execution engine demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "specexec-bench", .aliases = &.{}, .description = "Speculative execution benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "governor-demo", .aliases = &.{}, .description = "Adaptive resource governor demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "governor-bench", .aliases = &.{}, .description = "Governor benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "fedlearn-demo", .aliases = &.{}, .description = "Federated learning protocol demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "fedlearn-bench", .aliases = &.{}, .description = "Federated learning benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "eventsrc-demo", .aliases = &.{}, .description = "Event sourcing & CQRS engine demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "eventsrc-bench", .aliases = &.{}, .description = "Event sourcing benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "capsec-demo", .aliases = &.{}, .description = "Capability-based security demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "capsec-bench", .aliases = &.{}, .description = "Capability security benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "dtxn-demo", .aliases = &.{}, .description = "Distributed transaction coordinator demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "dtxn-bench", .aliases = &.{}, .description = "DTXN benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "cache-demo", .aliases = &.{}, .description = "Adaptive caching & memoization demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "cache-bench", .aliases = &.{}, .description = "Caching benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "contract-demo", .aliases = &.{}, .description = "Contract-based agent negotiation demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "contract-bench", .aliases = &.{}, .description = "Contract negotiation benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "workflow-demo", .aliases = &.{}, .description = "Temporal workflow engine demo", .category = .demo, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "workflow-bench", .aliases = &.{}, .description = "Workflow benchmark", .category = .benchmark, .api_enabled = true, .api_protocols = REST_ONLY },

    // =========================================================================
    // DISTRIBUTED INFERENCE
    // =========================================================================

    .{ .name = "distributed", .aliases = &.{}, .description = "Distributed inference", .category = .advanced, .api_enabled = true, .api_protocols = REST_GRAPHQL },
    .{ .name = "multi-cluster", .aliases = &.{"multi_cluster"}, .description = "Multi-cluster orchestration", .category = .advanced, .api_enabled = true, .api_protocols = REST_GRAPHQL },

    // =========================================================================
    // CODEBASE CONTEXT
    // =========================================================================

    .{ .name = "analyze", .aliases = &.{}, .description = "Analyze codebase structure", .category = .dev, .api_enabled = true, .api_protocols = REST_GRAPHQL },
    .{ .name = "search", .aliases = &.{"search-cmd"}, .description = "Search codebase using VSA semantic search", .long_help = "Search codebase using Vector Symbolic Architecture for semantic code search.", .category = .dev, .api_enabled = true, .api_protocols = REST_GRAPHQL },
    .{ .name = "query", .aliases = &.{"kg", "knowledge-graph"}, .description = "Query VSA Knowledge Graph", .long_help = "Query the symbolic knowledge graph using VSA operations. Supports entity-relation queries and multi-hop chains.", .category = .dev, .examples = &.{ "tri query Paris capital_of", "tri query Eiffel landmark_in", "tri query --chain Eiffel landmark_in capital_of", "tri query --list", "tri query --relations" }, .api_enabled = true, .api_protocols = REST_GRAPHQL },
    .{ .name = "context-info", .aliases = &.{"context_info"}, .description = "Show codebase context info", .category = .system },

    .{
        .name = "intelligence",
        .aliases = &.{},
        .description = "Sacred Intelligence system",
        .category = .sacred,
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    // =========================================================================
    // DEV UTILITIES
    // =========================================================================

    .{ .name = "doctor", .aliases = &.{}, .description = "Check system health", .category = .system, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "clean", .aliases = &.{}, .description = "Clean build artifacts", .category = .system },
    .{ .name = "fmt", .aliases = &.{"format"}, .description = "Format code", .category = .dev },
    .{ .name = "stats", .aliases = &.{"stats-cmd"}, .description = "Show code statistics", .category = .system },
    .{ .name = "igla", .aliases = &.{}, .description = "IGLA hybrid chat", .category = .ai },
    .{
        .name = "research",
        .aliases = &.{ "audit", "analyze-code" },
        .description = "Research: idempotency audit, duplication check",
        .long_help = "Run research audits on codebase.",
        .category = .dev,
        .examples = &.{ "tri research idempotency", "tri research duplication", "tri research sacred" },
        .has_subcommands = true,
        .subcommands = &.{
            .{ .name = "idempotency", .description = "Idempotency audit for code functions", .example = "tri research idempotency" },
            .{ .name = "duplication", .description = "Code duplication detection", .example = "tri research duplication" },
            .{ .name = "sacred", .description = "Sacred formula usage analysis", .example = "tri research sacred" },
            .{ .name = "complexity", .description = "Cyclomatic complexity analysis", .example = "tri research complexity" },
            .{ .name = "dead-code", .description = "Find unused code", .example = "tri research dead-code" },
        },
    },

    // =========================================================================
    // SACRED INTELLIGENCE
    // =========================================================================

    .{
        .name = "identity",
        .aliases = &.{},
        .description = "Sacred identity",
        .category = .sacred,
        .mcp_enabled = true,
        .mcp_name = "tri_identity",
        .mcp_display_name = "Sacred Identity",
        .input_params = &.{
            .{ .name = "subcommand", .param_type = .string, .description = "node, generate, verify, reputation" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "swarm",
        .aliases = &.{},
        .description = "Sacred swarm intelligence",
        .category = .sacred,
        .mcp_enabled = true,
        .mcp_name = "tri_swarm",
        .mcp_display_name = "Swarm Intelligence",
        .input_params = &.{
            .{ .name = "subcommand", .param_type = .string, .description = "status, coordinator, agents, tasks, converge" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "govern",
        .aliases = &.{},
        .description = "Sacred governance",
        .category = .sacred,
        .mcp_enabled = true,
        .mcp_name = "tri_govern",
        .mcp_display_name = "Governance System",
        .input_params = &.{
            .{ .name = "subcommand", .param_type = .string, .description = "proposals, vote, treasury, rewards" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{ .name = "dashboard", .aliases = &.{}, .description = "Sacred dashboard", .category = .system,
        .mcp_enabled = true,
        .mcp_name = "tri_dashboard_serve",
        .mcp_display_name = "Dashboard Server",
        .input_params = &.{
            .{ .name = "port", .param_type = .integer, .description = "Dashboard port" },
        },
    },
    .{ .name = "omega", .aliases = &.{}, .description = "Omega phase", .category = .sacred,
        .mcp_enabled = true,
        .mcp_name = "tri_omega_status",
        .mcp_display_name = "Omega Status",
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    // =========================================================================
    // DEPIN — Global Mesh + Omega Economy
    // =========================================================================

    .{
        .name = "wallet",
        .aliases = &.{},
        .description = "Wallet management — connect, balance, claim rewards",
        .long_help = "Manage your DePIN wallet.",
        .category = .depin,
        .examples = &.{ "tri wallet connect metamask", "tri wallet balance", "tri wallet claim 50.0" },
        .mcp_enabled = true,
        .mcp_name = "tri_wallet_balance",
        .mcp_display_name = "Wallet Balance",
        .input_params = &.{
            .{ .name = "address", .param_type = .string, .description = "Wallet address" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
        .api_auth_required = true,
    },

    .{
        .name = "mesh",
        .aliases = &.{},
        .description = "Global mesh management — status, topology, discovery",
        .long_help = "Manage the Global Mesh network.",
        .category = .depin,
        .examples = &.{ "tri mesh status", "tri mesh topology", "tri mesh discover" },
        .mcp_enabled = true,
        .mcp_name = "tri_mesh_status",
        .mcp_display_name = "Mesh Status",
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "reputation",
        .aliases = &.{"rep"},
        .description = "Reputation system — show node reputation, leaderboard",
        .long_help = "Check node reputation and Omega status.",
        .category = .depin,
        .examples = &.{ "tri reputation show", "tri reputation leaderboard" },
        .mcp_enabled = true,
        .mcp_name = "tri_omega_reputation",
        .mcp_display_name = "Reputation Leaderboard",
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "hardware",
        .aliases = &.{},
        .description = "Hardware deployment — deploy, status, stop nodes",
        .long_help = "Manage hardware node deployment.",
        .category = .depin,
        .examples = &.{ "tri hardware deploy", "tri hardware status" },
        .mcp_enabled = true,
        .mcp_name = "tri_hardware_info",
        .mcp_display_name = "Hardware Info",
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{ .name = "math-agent", .aliases = &.{"math_agent"}, .description = "Math agent", .category = .ai },

    // =========================================================================
    // TEMPORAL ENGINE
    // =========================================================================

    .{ .name = "time", .aliases = &.{}, .description = "Temporal engine operations",
        .long_help =
            \\Temporal engine: Time manipulation and causality tracking.
            \\
            \\Features:
            \\- Specious present calculation (φ⁻² ≈ 382ms)
            \\- Causal chain analysis
            \\- Temporal query optimization
        ,
        .category = .advanced,
        .examples = &.{
            "tri time present",
            "tri time chain --depth 3",
        },
        .input_params = &.{
            .{ .name = "subcommand", .param_type = .string, .description = "present, chain, causal" },
        },
    },
    .{ .name = "install", .aliases = &.{}, .description = "Install project dependencies",
        .long_help =
            \\Install all required dependencies for Trinity.
            \\
            \\Checks and installs:
            \\- Zig 0.15.x
            \\- Python packages (MCP server)
            \\- FPGA toolchain (optional)
            \\
            \\Run this after cloning the repository.
        ,
        .category = .system,
        .examples = &.{
            "tri install",
            "tri install --check",
            "tri install --with-fpga",
        },
        .input_params = &.{
            .{ .name = "check", .param_type = .boolean, .description = "Only check, don't install" },
            .{ .name = "with_fpga", .param_type = .boolean, .description = "Include FPGA toolchain" },
        },
    },
    .{ .name = "build", .aliases = &.{"build-cmd"}, .description = "Build project targets",
        .long_help =
            \\Build Trinity executables and libraries.
            \\
            \\Targets:
            \\- tri (default) - Main CLI
            \\- cli - Interactive agent
            \\- vibee - VIBEE compiler
            \\- firebird - LLM engine
            \\- release - Cross-platform builds
            \\
            \\Output: zig-out/bin/
        ,
        .category = .dev,
        .examples = &.{
            "tri build",
            "tri build tri",
            "tri build vibee",
            "tri build release",
        },
        .input_params = &.{
            .{ .name = "target", .param_type = .string, .description = "Build target (default: tri)" },
            .{ .name = "release", .param_type = .boolean, .description = "Build in release mode" },
        },
    },
    .{ .name = "deploy", .aliases = &.{}, .description = "Deploy to production (Fly.io)",
        .long_help =
            \\Build and deploy API server to Fly.io.
            \\
            \\Process:
            \\1. Build Docker image
            \\2. Push to container registry
            \\3. Update Fly.io deployment
            \\
            \\Requires: flyctl auth token
        ,
        .category = .dev,
        .examples = &.{
            "tri deploy",
            "tri deploy flyio",
            "tri deploy --local",
        },
        .input_params = &.{
            .{ .name = "platform", .param_type = .string, .description = "Deployment platform (default: flyio)" },
            .{ .name = "local", .param_type = .boolean, .description = "Build locally before deploying" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },
    .{ .name = "deck", .aliases = &.{"deck-generate"}, .description = "Generate flash deck for learning",
        .long_help =
            \\Generate Anki-style flash deck from codebase.
            \\
            \\Topics:
            \\- VSA operations
            \\- Sacred mathematics
            \\- Architecture patterns
            \\
            \\Output: trinity/output/deck.apkg
        ,
        .category = .dev,
        .examples = &.{
            "tri deck",
            "tri deck vsa",
            "tri deck sacred --output flashcards.apkg",
        },
        .input_params = &.{
            .{ .name = "topic", .param_type = .string, .description = "Topic for flash cards (default: all)" },
            .{ .name = "output", .param_type = .string, .description = "Output .apkg file path" },
        },
    },
    .{ .name = "fpga-demo", .aliases = &.{"fpga_demo"}, .description = "Run FPGA synthesis and flash demo",
        .long_help =
            \\FPGA demo: Synthesize Verilog and flash to hardware.
            \\
            \\Process:
            \\1. Synthesize Verilog with Yosys
            \\2. Generate bitstream with FORGE
            \\3. Flash via JTAG
            \\
            \\Hardware: QMTECH Artix-7 XC7A100T
        ,
        .category = .demo,
        .examples = &.{
            "tri fpga-demo",
            "tri fpga-demo d6_blink",
            "tri fpga-demo ternary_dot --no-flash",
        },
        .input_params = &.{
            .{ .name = "design", .param_type = .string, .description = "Design name (default: d6_blink)" },
            .{ .name = "no_flash", .param_type = .boolean, .description = "Skip JTAG flashing" },
        },
    },
    .{ .name = "sacred-full-cycle", .aliases = &.{"sacred_full_cycle"}, .description = "Run sacred mathematics full cycle demo",
        .long_help =
            \\Full demonstration of sacred mathematics in Trinity.
            \\
            \\Covers:
            \\- Golden ratio (φ) calculations
            \\- VSA operations
            \\- Sacred geometry
            \\- Consciousness modeling
        ,
        .category = .science,
        .examples = &.{
            "tri sacred-full-cycle",
            "tri sacred-full-cycle --verbose",
        },
    },

    // =========================================================================
    // QUANTUM TRINITY + OMEGA PHASE
    // =========================================================================

    .{ .name = "quantum", .aliases = &.{}, .description = "Quantum Trinity", .category = .science,
        .mcp_enabled = true,
        .mcp_name = "tri_quantum_constants",
        .mcp_display_name = "Quantum Constants",
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },
    .{ .name = "release-cosmic", .aliases = &.{"release_cosmic"}, .description = "Release cosmic energy", .category = .science },
    .{ .name = "omega-cmd", .aliases = &.{"omega_cmd"}, .description = "Omega command", .category = .science },
    .{ .name = "all-cmd", .aliases = &.{"all_cmd"}, .description = "All command", .category = .science },
    .{ .name = "holo-cmd", .aliases = &.{"holo_cmd"}, .description = "Holo command", .category = .science },
    .{ .name = "release-absolute", .aliases = &.{"release_absolute"}, .description = "Release absolute", .category = .science },
    .{ .name = "omega-evolve", .aliases = &.{"omega_evolve"}, .description = "Omega evolve", .category = .science },

    // =========================================================================
    // CONSCIOUSNESS — Unified Simulation (5 Theories)
    // =========================================================================

    .{ .name = "conscious", .aliases = &.{"consciousness"}, .description = "Consciousness awakening simulator (IIT+GWT+OrchOR+Qutrit+ActiveInf)", .category = .science,
        .mcp_enabled = true,
        .mcp_name = "tri_consciousness",
        .mcp_display_name = "Consciousness Simulator",
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    // =========================================================================
    // TRINITY OS
    // =========================================================================

    .{ .name = "launch", .aliases = &.{}, .description = "Launch TRINITY OS", .category = .advanced },

    // =========================================================================
    // NEEDLE — Structural Editor
    // =========================================================================

    .{
        .name = "needle",
        .aliases = &.{},
        .description = "Structural editor core",
        .category = .dev,
        .mcp_enabled = true,
        .mcp_name = "tri_needle",
        .mcp_display_name = "Needle Editor",
        .input_params = &.{
            .{ .name = "file", .param_type = .string, .description = "File to edit" },
            .{ .name = "query", .param_type = .string, .description = "Edit query" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "needle-search",
        .aliases = &.{"needle_search"},
        .description = "Needle search",
        .category = .dev,
        .mcp_enabled = true,
        .mcp_name = "tri_needle_search",
        .mcp_display_name = "Needle Search",
        .input_params = &.{
            .{ .name = "pattern", .param_type = .string, .description = "Search pattern", .required = true },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    .{
        .name = "needle-check",
        .aliases = &.{"needle_check"},
        .description = "Needle check",
        .category = .dev,
        .mcp_enabled = true,
        .mcp_name = "tri_needle_check",
        .mcp_display_name = "Needle Check",
        .input_params = &.{
            .{ .name = "file", .param_type = .string, .description = "File to check" },
        },
        .api_enabled = true,
        .api_protocols = REST_GRAPHQL,
    },

    // =========================================================================
    // INFO COMMANDS
    // =========================================================================

    .{ .name = "deps", .aliases = &.{}, .description = "Show dependencies", .category = .system },
    .{ .name = "info", .aliases = &.{}, .description = "System information", .category = .system, .examples = &.{"tri info"}, .api_enabled = true, .api_protocols = REST_ONLY },
    .{ .name = "version", .aliases = &.{ "v", "--version" }, .description = "Show version", .category = .system, .examples = &.{"tri version"} },
    .{
        .name = "docs-gen",
        .aliases = &.{"docs_gen", "docgen"},
        .description = "Generate CLI reference documentation",
        .long_help = "Auto-generates docs/command_registry.md from the unified command table.\nSingle source of truth: edits go to command_table.zig, not the markdown.",
        .category = .system,
        .examples = &.{ "tri docs-gen", "tri docs-gen docs/reference.md" },
    },
    .{
        .name = "registry-validate",
        .aliases = &.{"registry_validate", "regval"},
        .description = "Validate command registry and show statistics",
        .long_help = "Displays command table statistics, validates comptime rules, and shows coverage by category.",
        .category = .system,
        .examples = &.{ "tri registry-validate" },
    },

    // =========================================================================
    // COMPLETION & HELP
    // =========================================================================

    .{
        .name = "completion",
        .aliases = &.{},
        .description = "Generate shell completion scripts",
        .long_help = "Generate bash/zsh/fish completion scripts for tab completion.",
        .category = .system,
        .examples = &.{ "tri completion --bash", "tri completion --zsh", "tri completion --install" },
    },

    .{
        .name = "help",
        .aliases = &.{ "h", "?" },
        .description = "Show help information",
        .long_help = "Display help for commands.",
        .category = .system,
        .examples = &.{ "tri help", "tri help --search dna", "tri help --category science" },
    },

    .{
        .name = "test-repl",
        .aliases = &.{"test_repl"},
        .description = "Test REPL (Cycle 101)",
        .long_help = "Interactive test REPL.",
        .category = .dev,
        .examples = &.{ "tri test --repl", "tri test -r" },
    },

    // =========================================================================
    // FPGA & FORGE TOOLCHAIN (v2.0)
    // =========================================================================

    .{
        .name = "fpga",
        .aliases = &.{"forge"},
        .description = "FPGA toolchain via FORGE v2.0 (native Zig)",
        .long_help = "FORGE: 100%% native Zig FPGA synthesis for Xilinx 7-series.\nFull pipeline: Verilog -> Yosys -> JSON -> FORGE -> Bitstream -> JTAG -> FPGA.\n\nSubcommands:\n  bench    - Run regression benchmark suite\n  verdict  - Generate pass/fail verdict with toxic analysis\n  run      - Synthesize single design\n  flash    - Flash bitstream to hardware",
        .category = .dev,
        .examples = &.{ "tri fpga bench", "tri fpga verdict", "tri fpga run design.json", "tri fpga flash design.bit" },
        .has_subcommands = true,
        .subcommands = &.{
            .{ .name = "bench", .description = "Run regression benchmark suite", .example = "tri fpga bench" },
            .{ .name = "verdict", .description = "Generate pass/fail verdict with toxic analysis", .example = "tri fpga verdict" },
            .{ .name = "run", .description = "Synthesize single design (Verilog -> bitstream)", .example = "tri fpga run design.json" },
            .{ .name = "flash", .description = "Flash bitstream to hardware via JTAG", .example = "tri fpga flash design.bit" },
            .{ .name = "parse", .description = "Parse and display netlist info", .example = "tri fpga parse design.json" },
            .{ .name = "place", .description = "Run placement only", .example = "tri fpga place design.json" },
            .{ .name = "route", .description = "Run routing only", .example = "tri fpga route design.json" },
        },
    },

    .{
        .name = "bench-suite",
        .aliases = &.{"benchmark-all", "all-bench"},
        .description = "Run full benchmark suite (FORGE/VSA/VM)",
        .long_help = "Run benchmarks for specified subsystem.\nUse 'tri bench fpga' for FORGE regression suite.",
        .category = .benchmark,
        .examples = &.{ "tri bench-suite fpga", "tri bench-suite vsa", "tri bench-suite vm" },
    },

    .{
        .name = "bench-verdict",
        .aliases = &.{"toxic-bench", "review-bench"},
        .description = "Generate pass/fail verdict with toxic analysis (benchmarks)",
        .long_help = "Analyze test results and generate verdict with:\n- Pass/fail status per test\n- Root cause analysis for failures\n- Toxic verdict (Russian self-assessment)\n- Regression detection\n\nFormat: CSV/Markdown report with phi-based scoring.",
        .category = .dev,
        .examples = &.{ "tri verdict fpga", "tri verdict --format markdown", "tri forge verdict" },
    },

    .{
        .name = "forge-bench",
        .aliases = &.{"fb", "forge-benchmark", "fpga-bench"},
        .description = "FORGE regression benchmark suite",
        .long_help = "Run full FORGE regression suite:\n- Synthesize all test designs\n- Compare FORGE vs Docker toolchains\n- Generate CSV/Markdown report\n- Measure runtime (FORGE ~77ms, Docker ~30s)\n\nResults: fpga/forge-regression/results/",
        .category = .benchmark,
        .examples = &.{ "tri forge-bench", "tri fb", "tri bench fpga" },
    },

    .{
        .name = "forge-verdict",
        .aliases = &.{"fv", "forge-review", "fpga-verdict"},
        .description = "FORGE verdict with pass/fail and toxic analysis",
        .long_help = "Generate FORGE compatibility verdict:\n- Parse regression_results.csv\n- Identify failing tests and root causes\n- Toxic verdict: 'TOXIC' if <61.8%% pass rate (phi inverse)\n- Generate FORGE_COMPATIBILITY_MATRIX.md\n\nExit codes: 0=PASS, 1=FAIL, 2=TOXIC",
        .category = .dev,
        .examples = &.{ "tri forge-verdict", "tri fv", "tri verdict fpga" },
    },
};

// =============================================================================
// COMPTIME VALIDATION — catches errors at compile time, not runtime
// =============================================================================

comptime {
    @setEvalBranchQuota(1_000_000);

    // 1. Every command must have a non-empty name
    for (all_commands) |cmd| {
        if (cmd.name.len == 0) {
            @compileError("Command has empty name");
        }
    }

    // 2. Every command must have a description (len > 0)
    for (all_commands) |cmd| {
        if (cmd.description.len == 0) {
            @compileError("Command '" ++ cmd.name ++ "' has empty description");
        }
    }

    // 3. No duplicate command names
    for (all_commands, 0..) |cmd, i| {
        for (all_commands[i + 1 ..]) |other| {
            if (std.mem.eql(u8, cmd.name, other.name)) {
                @compileError("Duplicate command name: '" ++ cmd.name ++ "'");
            }
        }
    }

    // 4. MCP-enabled commands must have at least one input_param or be explicitly zero-arg
    //    (no check needed — zero input_params is valid for commands like 'verify', 'status')

    // 5. API-enabled commands must have at least one protocol
    for (all_commands) |cmd| {
        if (cmd.api_enabled and cmd.api_protocols.len == 0) {
            @compileError("API-enabled command '" ++ cmd.name ++ "' has no protocols");
        }
    }

    // 6. No alias collides with another command's name
    for (all_commands) |cmd| {
        for (cmd.aliases) |alias| {
            if (alias.len == 0) {
                @compileError("Command '" ++ cmd.name ++ "' has empty alias");
            }
            for (all_commands) |other| {
                if (!std.mem.eql(u8, cmd.name, other.name) and std.mem.eql(u8, alias, other.name)) {
                    @compileError("Alias '" ++ alias ++ "' of command '" ++ cmd.name ++ "' collides with command '" ++ other.name ++ "'");
                }
            }
        }
    }

    // 7. No duplicate MCP tool names
    for (all_commands, 0..) |cmd, i| {
        if (!cmd.mcp_enabled) continue;
        const name_a = cmd.getMcpToolName();
        for (all_commands[i + 1 ..]) |other| {
            if (!other.mcp_enabled) continue;
            const name_b = other.getMcpToolName();
            if (std.mem.eql(u8, name_a, name_b)) {
                @compileError("Duplicate MCP tool name from commands '" ++ cmd.name ++ "' and '" ++ other.name ++ "'");
            }
        }
    }
}

// =============================================================================
// QUERY HELPERS
// =============================================================================

/// Count commands with MCP enabled
pub fn countMcpTools() usize {
    var count: usize = 0;
    for (all_commands) |cmd| {
        if (cmd.mcp_enabled) count += 1;
    }
    return count;
}

/// Count commands with API enabled
pub fn countApiEndpoints() usize {
    var count: usize = 0;
    for (all_commands) |cmd| {
        if (cmd.api_enabled) count += 1;
    }
    return count;
}

/// Count total commands
pub fn countTotal() usize {
    return all_commands.len;
}

/// Find command by name (linear scan — use CommandRegistry HashMap for hot path)
pub fn findByName(name: []const u8) ?*const CommandDef {
    for (&all_commands) |*cmd| {
        if (std.mem.eql(u8, cmd.name, name)) return cmd;
        for (cmd.aliases) |alias| {
            if (std.mem.eql(u8, alias, name)) return cmd;
        }
    }
    return null;
}

/// Find command by MCP tool name
pub fn findByMcpName(mcp_name: []const u8) ?*const CommandDef {
    for (&all_commands) |*cmd| {
        if (!cmd.mcp_enabled) continue;
        if (cmd.mcp_name) |name| {
            if (std.mem.eql(u8, name, mcp_name)) return cmd;
        }
    }
    return null;
}

// =============================================================================
// TESTS
// =============================================================================

const testing = std.testing;

test "command table has expected count" {
    // Should match the number of entries above
    try testing.expect(all_commands.len > 100);
    try testing.expect(all_commands.len < 250);
}

test "countMcpTools returns nonzero" {
    const mcp_count = countMcpTools();
    try testing.expect(mcp_count > 10);
    try testing.expect(mcp_count < all_commands.len);
}

test "countApiEndpoints returns nonzero" {
    const api_count = countApiEndpoints();
    try testing.expect(api_count > 50);
    try testing.expect(api_count < all_commands.len);
}

test "findByName works" {
    const bio = findByName("bio");
    try testing.expect(bio != null);
    try testing.expectEqualStrings("bio", bio.?.name);

    // Alias lookup
    const biology = findByName("biology");
    try testing.expect(biology != null);
    try testing.expectEqualStrings("bio", biology.?.name);

    // Not found
    try testing.expect(findByName("nonexistent-command-xyz") == null);
}

test "findByMcpName works" {
    const phi = findByMcpName("tri_phi");
    try testing.expect(phi != null);
    try testing.expectEqualStrings("phi", phi.?.name);

    try testing.expect(findByMcpName("nonexistent_mcp_tool") == null);
}

test "no duplicate command names" {
    for (all_commands, 0..) |cmd, i| {
        for (all_commands[i + 1 ..]) |other| {
            if (std.mem.eql(u8, cmd.name, other.name)) {
                std.debug.print("DUPLICATE: {s}\n", .{cmd.name});
                try testing.expect(false);
            }
        }
    }
}
