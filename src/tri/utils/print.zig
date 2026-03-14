// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Print Functions
// ═══════════════════════════════════════════════════════════════════════════════
//
// Banner, help, info, version, and stats display functions.
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("../tri_colors.zig");
const trinity_swe = @import("../trinity_swe");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const WHITE = colors.WHITE;
const GRAY = colors.GRAY;
const RED = colors.RED;
const CYAN = colors.CYAN;
const RESET = colors.RESET;
const VERSION = colors.VERSION;

pub fn printBanner() void {
    std.debug.print("\n", .{});
    std.debug.print("{s}TRINITY v{s}{s}\n", .{ GOLDEN, VERSION, RESET });
    std.debug.print("100% Local AI | Code | Chat | SWE Agent\n", .{});
    std.debug.print("\n", .{});
}

pub fn printHelp() void {
    std.debug.print("\n{s}TRI CLI - Trinity Unified Command Line{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    std.debug.print("{s}USAGE:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri                         Interactive REPL (default)\n", .{});
    std.debug.print("  tri <command> [args.]     Run specific command\n\n", .{});

    std.debug.print("{s}COMMANDS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}chat{s} [--stream] [--image <path>] [--voice <path>] <msg>\n", .{ GREEN, RESET });
    std.debug.print("         Interactive chat (v2.1: vision + voice + tools)\n", .{});
    std.debug.print("  {s}code{s} [--stream] <prompt>    Generate code (--stream for typing effect)\n", .{ GREEN, RESET });
    std.debug.print("  {s}gen{s} <spec.tri>            Compile VIBEE spec to Zig/Verilog\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}SWE AGENT:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}fix{s} <file>                  Detect and fix bugs\n", .{ GREEN, RESET });
    std.debug.print("  {s}explain{s} <file|prompt>       Explain code or concept\n", .{ GREEN, RESET });
    std.debug.print("  {s}test{s} <file>                 Generate tests\n", .{ GREEN, RESET });
    std.debug.print("  {s}doc{s} <file>                  Generate documentation\n", .{ GREEN, RESET });
    std.debug.print("  {s}refactor{s} <file>             Suggest refactoring\n", .{ GREEN, RESET });
    std.debug.print("  {s}reason{s} <prompt>             Chain-of-thought reasoning\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}TOOLS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}gen{s} <spec.tri>            VIBEE → Zig/Verilog compiler\n", .{ GREEN, RESET });
    std.debug.print("  {s}convert{s} <file>              Convert WASM/Binary → Ternary\n", .{ GREEN, RESET });
    std.debug.print("  {s}serve{s} --model <path>        Start HTTP API server\n", .{ GREEN, RESET });
    std.debug.print("  {s}bench{s}                       Run performance benchmarks\n", .{ GREEN, RESET });
    std.debug.print("  {s}evolve{s} [--dim N]            Evolve fingerprint (Firebird)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}GIT:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}status{s}                      Git status --short\n", .{ GREEN, RESET });
    std.debug.print("  {s}diff{s}                        Git diff\n", .{ GREEN, RESET });
    std.debug.print("  {s}log{s}                         Git log --oneline -10\n", .{ GREEN, RESET });
    std.debug.print("  {s}commit{s} <message>            Git add -A && commit\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}GOLDEN CHAIN:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}pipeline run{s} <task>         Execute 17-link development cycle (incl TVC)\n", .{ GREEN, RESET });
    std.debug.print("  {s}pipeline status{s}             Show pipeline state\n", .{ GREEN, RESET });
    std.debug.print("  {s}decompose{s} <task>            Break task into sub-tasks\n", .{ GREEN, RESET });
    std.debug.print("  {s}verify{s}                      Run tests + benchmarks (Links 7-11)\n", .{ GREEN, RESET });
    std.debug.print("  {s}verdict{s}                     Generate toxic verdict (Link 14)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}TVC (DISTRIBUTED):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}tvc-demo{s}                    Run TVC chat demo (distributed learning)\n", .{ GREEN, RESET });
    std.debug.print("  {s}tvc-stats{s}                   Show TVC corpus statistics\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}MULTI-AGENT:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}agents-demo{s}                 Run multi-agent coordination demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}agents-bench{s}                Run multi-agent benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}LONG CONTEXT:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}context-demo{s}                Run long context demo (sliding window)\n", .{ GREEN, RESET });
    std.debug.print("  {s}context-bench{s}               Run context benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}RAG (RETRIEVAL):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}rag-demo{s}                    Run RAG demo (local retrieval)\n", .{ GREEN, RESET });
    std.debug.print("  {s}rag-bench{s}                   Run RAG benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}VOICE I/O MULTI-MODAL (Cycle 29):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}voice-demo{s}                  Run voice I/O multi-modal demo (STT+TTS+cross-modal)\n", .{ GREEN, RESET });
    std.debug.print("  {s}voice-bench{s}                 Run voice I/O benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}CODE SANDBOX:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}sandbox-demo{s}                Run code sandbox demo (safe execution)\n", .{ GREEN, RESET });
    std.debug.print("  {s}sandbox-bench{s}               Run sandbox benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}STREAMING MULTI-MODAL PIPELINE (Cycle 38):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}stream-demo, pipeline{s}       Run streaming multi-modal pipeline demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}stream-bench{s}                Run streaming pipeline benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}VISION UNDERSTANDING (Cycle 28):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}vision-demo{s}                 Run vision understanding demo (image analysis)\n", .{ GREEN, RESET });
    std.debug.print("  {s}vision-bench{s}                Run vision understanding benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}FINE-TUNING:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}finetune-demo{s}               Run fine-tuning demo (custom model adaptation)\n", .{ GREEN, RESET });
    std.debug.print("  {s}finetune-bench{s}              Run fine-tuning benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}MULTI-MODAL UNIFIED (Cycle 26):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}multimodal-demo{s}             Run multi-modal unified demo (text+vision+voice+code)\n", .{ GREEN, RESET });
    std.debug.print("  {s}multimodal-bench{s}            Run multi-modal benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}MULTI-MODAL TOOL USE (Cycle 27):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}tooluse-demo{s}               Run tool use demo (file/code/system from any modality)\n", .{ GREEN, RESET });
    std.debug.print("  {s}tooluse-bench{s}              Run tool use benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}UNIFIED MULTI-MODAL AGENT (Cycle 30):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}unified-demo{s}               Run unified agent demo (text+vision+voice+code+tools)\n", .{ GREEN, RESET });
    std.debug.print("  {s}unified-bench{s}              Run unified agent benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}AUTONOMOUS AGENT (Cycle 31):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}auto-demo{s}                  Run autonomous agent demo (self-directed task execution)\n", .{ GREEN, RESET });
    std.debug.print("  {s}auto-bench{s}                 Run autonomous agent benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}MULTI-AGENT ORCHESTRATION (Cycle 32):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}orch-demo{s}                  Run multi-agent orchestration demo (coordinator+specialists)\n", .{ GREEN, RESET });
    std.debug.print("  {s}orch-bench{s}                 Run multi-agent orchestration benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}MM MULTI-AGENT ORCHESTRATION (Cycle 33):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}mmo-demo{s}                   Run multi-modal multi-agent demo (all modalities+agents)\n", .{ GREEN, RESET });
    std.debug.print("  {s}mmo-bench{s}                  Run multi-modal multi-agent benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}AGENT MEMORY & CROSS-MODAL LEARNING (Cycle 34):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}memory-demo{s}                 Run agent memory & learning demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}memory-bench{s}                Run agent memory benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}PERSISTENT MEMORY & DISK SERIALIZATION (Cycle 35):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}persist-demo{s}                Run persistent memory demo (save/load TRMM)\n", .{ GREEN, RESET });
    std.debug.print("  {s}persist-bench{s}               Run persistent memory benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}DYNAMIC AGENT SPAWNING & LOAD BALANCING (Cycle 36):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}spawn-demo{s}                  Run dynamic agent spawning demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}spawn-bench{s}                 Run dynamic spawning benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}DISTRIBUTED MULTI-NODE AGENTS (Cycle 37):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}cluster-demo{s}                Run distributed multi-node agents demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}cluster-bench{s}               Run distributed agents benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}ADAPTIVE WORK-STEALING SCHEDULER (Cycle 39):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}worksteal-demo, steal{s}       Run adaptive work-stealing scheduler demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}worksteal-bench{s}             Run work-stealing benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}PLUGIN & EXTENSION SYSTEM (Cycle 40):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}plugin-demo, plugin, ext{s}    Run plugin & extension system demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}plugin-bench{s}                Run plugin system benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}AGENT COMMUNICATION PROTOCOL (Cycle 41):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}comms-demo, comms, msg{s}      Run agent communication protocol demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}comms-bench{s}                 Run communication benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}OBSERVABILITY & TRACING SYSTEM (Cycle 42):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}observe-demo, observe, otel{s}  Run observability & tracing demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}observe-bench{s}                Run observability benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}CONSENSUS & COORDINATION PROTOCOL (Cycle 43):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}consensus-demo, consensus, raft{s} Run consensus & coordination demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}consensus-bench{s}              Run consensus benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}SPECULATIVE EXECUTION ENGINE (Cycle 44):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}specexec-demo, specexec, spec{s} Run speculative execution demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}specexec-bench{s}               Run speculative execution benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}ADAPTIVE RESOURCE GOVERNOR (Cycle 45):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}governor-demo, governor, gov{s}  Run adaptive resource governor demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}governor-bench{s}               Run resource governor benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}FEDERATED LEARNING PROTOCOL (Cycle 46):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}fedlearn-demo, fedlearn, fl{s}  Run federated learning demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}fedlearn-bench{s}               Run federated learning benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}EVENT SOURCING & CQRS ENGINE (Cycle 47):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}eventsrc-demo, eventsrc, es{s}  Run event sourcing & CQRS demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}eventsrc-bench{s}               Run event sourcing benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}CAPABILITY-BASED SECURITY MODEL (Cycle 48):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}capsec-demo, capsec, sec{s}     Run capability security demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}capsec-bench{s}                 Run capability security benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}DISTRIBUTED TRANSACTION COORDINATOR (Cycle 49):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}dtxn-demo, dtxn, txn{s}         Run distributed transaction demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}dtxn-bench{s}                   Run distributed transaction benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}ADAPTIVE CACHING & MEMOIZATION (Cycle 50):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}cache-demo, cache, memo{s}       Run adaptive caching demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}cache-bench{s}                   Run adaptive caching benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}CONTRACT-BASED AGENT NEGOTIATION (Cycle 51):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}contract-demo, contract, sla{s}  Run contract negotiation demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}contract-bench{s}                Run contract negotiation benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}TEMPORAL WORKFLOW ENGINE (Cycle 52):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}workflow-demo, workflow, wf{s}    Run temporal workflow demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}workflow-bench{s}                 Run temporal workflow benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}SACRED MATHEMATICS (v3.6):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}math{s}                        Sacred math dispatcher\n", .{ GREEN, RESET });
    std.debug.print("  {s}constants{s}                    Show all sacred constants\n", .{ GREEN, RESET });
    std.debug.print("  {s}phi{s} <n>                      Compute phi^n\n", .{ GREEN, RESET });
    std.debug.print("  {s}fib{s} <n>                      Fibonacci F(n) with BigInt\n", .{ GREEN, RESET });
    std.debug.print("  {s}lucas{s} <n>                    Lucas L(n)\n", .{ GREEN, RESET });
    std.debug.print("  {s}spiral{s} <n>                   phi-spiral coordinates\n", .{ GREEN, RESET });
    std.debug.print("  {s}gematria{s} <number|text>       Coptic gematria + sacred formula\n", .{ GREEN, RESET });
    std.debug.print("  {s}formula{s} <value>              Sacred formula decomposition\n", .{ GREEN, RESET });
    std.debug.print("  {s}sacred{s}                      32 constants + 9 predictions table\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}SACRED BIOLOGY (v14.0):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}bio{s} dna <sequence>           DNA analysis with sacred mathematics\n", .{ GREEN, RESET });
    std.debug.print("  {s}bio{s} rna <sequence>           RNA analysis with sacred mathematics\n", .{ GREEN, RESET });
    std.debug.print("  {s}bio{s} protein <sequence>       Protein analysis (1-letter codes)\n", .{ GREEN, RESET });
    std.debug.print("  {s}bio{s} phi-genome               Sacred genome patterns\n", .{ GREEN, RESET });
    std.debug.print("  {s}bio{s} codon <codon>            Codon → amino acid lookup\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}SACRED COSMOLOGY (v15.0):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}cosmos{s} hubble                Resolve Hubble tension via Sacred Formula\n", .{ GREEN, RESET });
    std.debug.print("  {s}cosmos{s} dark                  Dark energy/matter as φ-patterns\n", .{ GREEN, RESET });
    std.debug.print("  {s}cosmos{s} predict               Predict new constants and stability islands\n", .{ GREEN, RESET });
    std.debug.print("  {s}cosmos{s} expand                Universe expansion timeline\n", .{ GREEN, RESET });
    std.debug.print("  {s}cosmos{s} big-bang              Big Bang through sacred lens\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}SACRED NEUROSCIENCE (v16.0):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}neuro{s} waves [freq]           Brain waves (φ-patterned frequencies)\n", .{ GREEN, RESET });
    std.debug.print("  {s}neuro{s} consciousness [C t E]  Compute consciousness level Ψ\n", .{ GREEN, RESET });
    std.debug.print("  {s}neuro{s} regions                Sacred brain regions (φ-index)\n", .{ GREEN, RESET });
    std.debug.print("  {s}neuro{s} network [layers...]    Analyze neural network sacredness\n", .{ GREEN, RESET });
    std.debug.print("  {s}neuro{s} synapse                Synaptic transmission timing\n", .{ GREEN, RESET });
    std.debug.print("  {s}neuro{s} neurons                Brain statistics & sacred constants\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}SACRED INTELLIGENCE:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}intelligence{s} [<symbol>.]   Sacred formula + gematria analysis\n", .{ GREEN, RESET });
    std.debug.print("  {s}intel{s} [<symbol>.]          Alias for intelligence\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}SACRED AGENTS (Cycle 98):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}identity{s}                   Show Sacred Intelligence identity\n", .{ GREEN, RESET });
    std.debug.print("  {s}swarm{s}                      Multi-agent Sacred Swarm status\n", .{ GREEN, RESET });
    std.debug.print("  {s}govern{s}                     Sacred Governance rules (φ-Rules)\n", .{ GREEN, RESET });
    std.debug.print("  {s}dashboard{s} [--stream]       3-column Sacred Dashboard (RAZUM/MATERIYA/DUKH)\n", .{ GREEN, RESET });
    std.debug.print("  {s}omega{s} [status|validate]    Master coordinator - all agents\n", .{ GREEN, RESET });
    std.debug.print("  {s}math-agent{s} [phi|fib|...]   Sacred Math Agent - self-aware\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}AUTONOMOUS EVOLUTION (Cycle 97):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}auto-commit{s} [--dry-run] [--approve] [--max N]\n", .{ GREEN, RESET });
    std.debug.print("         Autonomous sacred patch commits (φ-guided)\n", .{});
    std.debug.print("  {s}ml-optimize{s} <file>           ML-based patch optimization\n", .{ GREEN, RESET });
    std.debug.print("  {s}deploy-dashboard{s} [--target]  Deploy production dashboard\n", .{ GREEN, RESET });
    std.debug.print("  {s}self-host{s}                   Self-hosting loop (IMPROVE YOURSELF!)\n", .{ GREEN, RESET });
    std.debug.print("  {s}safeguards{s} show             Show safeguard status\n", .{ GREEN, RESET });
    std.debug.print("  {s}safeguards-disable{s} <feature> Disable a safeguard\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}DEV UTILITIES:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}doctor{s} [sub]                  Codebase health (scan/mark/report/plan/heal/enforce/status)\n", .{ GREEN, RESET });
    std.debug.print("  {s}clean{s}                       Clean build artifacts (.zig-cache, zig-out)\n", .{ GREEN, RESET });
    std.debug.print("  {s}fmt{s}                         Format Zig source (zig fmt src/)\n", .{ GREEN, RESET });
    std.debug.print("  {s}stats{s}                       Project statistics (files, LOC, specs, tests)\n", .{ GREEN, RESET });
    std.debug.print("  {s}igla{s}                        IGLA initiative status (parser coverage)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}INFO:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}info{s}                        System information\n", .{ GREEN, RESET });
    std.debug.print("  {s}version{s}                     Show version\n", .{ GREEN, RESET });
    std.debug.print("  {s}help{s}                        This help message\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}TESTING (Cycle 100):{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}test --repl{s}                  Run REPL test suite\n", .{ GREEN, RESET });
    std.debug.print("  {s}test -r{s}                      Short form\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}REPL COMMANDS:{s} (in interactive mode)\n", .{ CYAN, RESET });
    std.debug.print("  /chat /code /fix /explain /test /doc /reason\n", .{});
    std.debug.print("  /zig /python /rust /js    Set language\n", .{});
    std.debug.print("  /stats /verbose /help /quit\n", .{});
    std.debug.print("\n{s}MULTILINGUAL:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Auto-detects: Russian, Chinese, English\n", .{});
    std.debug.print("  Examples:\n", .{});
    std.debug.print("    tri code \"optimize fibonacci function\"    [RU]\n", .{});
    std.debug.print("    tri code \"写一个斐波那契函数\"           [ZH]\n", .{});
    std.debug.print("    tri code \"write fibonacci function\"   \n", .{});
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

pub fn printVersion() void {
    std.debug.print("{s}TRI CLI{s} v{s}\n", .{ GREEN, RESET, VERSION });
    std.debug.print("Trinity Unified Command Line Interface\n", .{});
    std.debug.print("phi^2 + 1/phi^2 = 3 = TRINITY\n", .{});
}

pub fn printInfo() void {
    std.debug.print("\n{s}═══ System Information ═══{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  TRI CLI Version: {s}\n", .{VERSION});
    std.debug.print("  Platform: {s}\n", .{@tagName(@import("builtin").os.tag)});
    std.debug.print("  Architecture: {s}\n", .{@tagName(@import("builtin").cpu.arch)});
    std.debug.print("  Mode: 100%% LOCAL\n", .{});
    std.debug.print("  Vocabulary: 50000 words\n", .{});
    std.debug.print("  Code Templates: 50+\n", .{});
    std.debug.print("  Chat Patterns: 60+\n", .{});
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

pub fn printREPLHelp() void {
    std.debug.print("\n{s}REPL Commands:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}/chat{s}     - Chat mode\n", .{ GREEN, RESET });
    std.debug.print("  {s}/code{s}     - Code generation\n", .{ GREEN, RESET });
    std.debug.print("  {s}/fix{s}      - Bug fixing\n", .{ GREEN, RESET });
    std.debug.print("  {s}/explain{s}  - Explain code\n", .{ GREEN, RESET });
    std.debug.print("  {s}/test{s}     - Generate tests\n", .{ GREEN, RESET });
    std.debug.print("  {s}/doc{s}      - Generate docs\n", .{ GREEN, RESET });
    std.debug.print("  {s}/refactor{s} - Refactoring\n", .{ GREEN, RESET });
    std.debug.print("  {s}/reason{s}   - Chain-of-thought\n", .{ GREEN, RESET });
    std.debug.print("  {s}/zig{s}      - Zig language\n", .{ GREEN, RESET });
    std.debug.print("  {s}/python{s}   - Python language\n", .{ GREEN, RESET });
    std.debug.print("  {s}/rust{s}     - Rust language\n", .{ GREEN, RESET });
    std.debug.print("  {s}/js{s}       - JavaScript\n", .{ GREEN, RESET });
    std.debug.print("  {s}/stats{s}    - Statistics\n", .{ GREEN, RESET });
    std.debug.print("  {s}/verbose{s}  - Toggle verbose\n", .{ GREEN, RESET });
    std.debug.print("  {s}/quit{s}     - Exit\n", .{ GREEN, RESET });
    std.debug.print("\n{s}Just type to send a message!{s}\n\n", .{ GRAY, RESET });
}

pub fn printStats(state: anytype) void {
    const swe_stats = state.agent.getStats();
    const chat_stats = state.chat_agent.getStats();

    std.debug.print("\n{s}═══ Statistics ═══{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  SWE Requests: {d}\n", .{swe_stats.total_requests});
    std.debug.print("  SWE Time: {d}μs ({d:.2}ms)\n", .{ swe_stats.total_time_us, @as(f64, @floatFromInt(swe_stats.total_time_us)) / 1000.0 });
    if (swe_stats.total_time_us > 0) {
        const ops_per_sec = @as(f64, @floatFromInt(swe_stats.total_requests)) / (@as(f64, @floatFromInt(swe_stats.total_time_us)) / 1_000_000.0);
        std.debug.print("  Speed: {s}{d:.1} ops/s{s}\n", .{ GREEN, ops_per_sec, RESET });
    }

    std.debug.print("\n{s}═══ Chat v2.3 (Context + Multi-Modal + Tools) ═══{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Total Queries: {d}\n", .{chat_stats.total_queries});
    std.debug.print("  Symbolic Hits: {d} ({d:.1}%%)\n", .{ chat_stats.symbolic_hits, chat_stats.symbolic_hit_rate * 100.0 });
    std.debug.print("  Tool Hits: {d}\n", .{chat_stats.tool_hits});
    if (chat_stats.tvc_enabled) {
        std.debug.print("  {s}TVC Cache:{s} ON (corpus: {d} entries)\n", .{ GREEN, RESET, chat_stats.tvc_corpus_size });
        std.debug.print("  TVC Hits: {d} ({d:.1}%%)\n", .{ chat_stats.tvc_hits, chat_stats.tvc_hit_rate * 100.0 });
    } else {
        std.debug.print("  TVC Cache: OFF\n", .{});
    }
    std.debug.print("  Cache Hit Rate: {s}{d:.1}%%{s}\n", .{ GREEN, chat_stats.cache_hit_rate * 100.0, RESET });
    std.debug.print("  LLM Calls: {d} (local: {d}, groq: {d}, claude: {d})\n", .{
        chat_stats.llm_calls,
        chat_stats.llm_calls -| (chat_stats.groq_calls + chat_stats.claude_calls),
        chat_stats.groq_calls,
        chat_stats.claude_calls,
    });
    std.debug.print("  Vision Calls: {d}\n", .{chat_stats.vision_calls});
    std.debug.print("  Whisper STT: {d}\n", .{chat_stats.whisper_calls});
    std.debug.print("  {s}Energy Saved: {d:.4} Wh{s}\n", .{ GREEN, chat_stats.energy_saved_wh, RESET });
    std.debug.print("  LLM Loaded: {s}\n", .{if (chat_stats.llm_loaded) "Yes" else "No"});

    // v2.3: Context stats
    std.debug.print("\n{s}═══ Context (v2.3) ═══{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Context: {s}\n", .{if (chat_stats.context_enabled) "ON" else "OFF"});
    std.debug.print("  Total Messages: {d}\n", .{chat_stats.context_total_messages});
    std.debug.print("  Window Messages: {d}/20\n", .{chat_stats.context_window_messages});
    std.debug.print("  Summarized: {d}\n", .{chat_stats.context_summarized_messages});
    std.debug.print("  Key Facts: {d}\n", .{chat_stats.context_key_facts});

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS ENERGY IMMORTAL{s}\n\n", .{ GOLDEN, RESET });
}

// Forward declare Command type - will be imported from tri_utils.zig
pub const Command = enum {
    none,
    chat,
    code,
    gen,
    fix,
    explain,
    test_cmd,
    doc,
    refactor,
    reason,
    convert,
    serve,
    bench,
    evolve,
    commit,
    diff,
    status,
    log,
    pipeline,
    decompose,
    plan,
    verify,
    verdict,
    test_repl,
    spec_create,
    loop_decide,
    tvc_demo,
    tvc_stats,
    agents_demo,
    agents_bench,
    context_demo,
    context_bench,
    rag_demo,
    rag_bench,
    voice_demo,
    voice_bench,
    sandbox_demo,
    sandbox_bench,
    stream_demo,
    stream_bench,
    vision_demo,
    vision_bench,
    finetune_demo,
    finetune_bench,
    batched_demo,
    batched_bench,
    priority_demo,
    priority_bench,
    deadline_demo,
    deadline_bench,
    multimodal_demo,
    multimodal_bench,
    tooluse_demo,
    tooluse_bench,
    unified_demo,
    unified_bench,
    autonomous_demo,
    autonomous_bench,
    orchestration_demo,
    orchestration_bench,
    mm_orch_demo,
    mm_orch_bench,
    memory_demo,
    memory_bench,
    persist_demo,
    persist_bench,
    spawn_demo,
    spawn_bench,
    cluster_demo,
    cluster_bench,
    worksteal_demo,
    worksteal_bench,
    plugin_demo,
    plugin_bench,
    comms_demo,
    comms_bench,
    observe_demo,
    observe_bench,
    consensus_demo,
    consensus_bench,
    specexec_demo,
    specexec_bench,
    governor_demo,
    governor_bench,
    fedlearn_demo,
    fedlearn_bench,
    eventsrc_demo,
    eventsrc_bench,
    capsec_demo,
    capsec_bench,
    dtxn_demo,
    dtxn_bench,
    cache_demo,
    cache_bench,
    contract_demo,
    contract_bench,
    workflow_demo,
    workflow_bench,
    distributed,
    multi_cluster,
    math,
    constants_cmd,
    phi,
    fib,
    lucas,
    spiral,
    gematria,
    formula_cmd,
    sacred,
    bio,
    cosmos,
    neuro,
    chem,
    intelligence,
    doctor,
    clean,
    fmt_cmd,
    stats_cmd,
    igla,
    identity,
    swarm,
    mu,
    govern,
    dashboard,
    omega,
    math_agent,
    analyze,
    search_cmd,
    deps,
    context_info,
    time,
    install,
    build_cmd,
    deck_generate,
    fpga_demo,
    fpga,
    train,
    cloud,
    farm,
    sacred_const,
    sacred_full_cycle,
    quantum,
    release_cosmic,
    omega_cmd,
    all_cmd,
    holo_cmd,
    release_absolute,
    omega_evolve,
    launch,
    job_start,
    job_status,
    job_logs,
    job_artifacts,
    job_cancel,
    job_list,
    info,
    version,
    help,
    needle,
    needle_search,
    needle_check,
    commands,
    mcp,
    lint,
    enrich,
    sync_check,
    github,
    zenodo,
    loop,
    experience,
    faculty,
    research,
    experiment,
    chain,
    trace,
    eval,
    metrics,
    context_load,
};

pub fn printCommandHelp(cmd: Command) void {
    std.debug.print("\n", .{});
    switch (cmd) {
        .chat => {
            std.debug.print("{s}CHAT - Interactive LLM Chat{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri chat [--stream] [--image <path>] [--voice <path>] \"<message>\"\n", .{});
            std.debug.print("\n");
            std.debug.print("  {s}FLAGS:{s}\n", .{ CYAN, RESET });
            std.debug.print("    --stream     Enable streaming output (typing effect)\n", .{});
            std.debug.print("    --image      Path to image file for vision analysis\n", .{});
            std.debug.print("    --voice      Path to audio file for voice input (Whisper STT)\n", .{});
        },
        .code => {
            std.debug.print("{s}CODE - Code Generation{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri code [--stream] \"<prompt>\"\n", .{});
            std.debug.print("\n");
            std.debug.print("  {s}FLAGS:{s}\n", .{ CYAN, RESET });
            std.debug.print("    --stream     Enable streaming output (typing effect)\n", .{});
        },
        .gen => {
            std.debug.print("{s}GEN - VIBEE Spec Compiler{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri gen <spec.tri>\n", .{});
            std.debug.print("\n");
            std.debug.print("  {s}DESCRIPTION:{s}\n", .{ CYAN, RESET });
            std.debug.print("    Compile .tri specification to Zig or Verilog source code.\n", .{});
            std.debug.print("    Supports: VIBEE v8.27 syntax with spec ↔ code sync.\n", .{});
        },
        .fix => {
            std.debug.print("{s}FIX - Bug Detection & Fix{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri fix <file> [--test] [--verbose]\n", .{});
            std.debug.print("\n");
            std.debug.print("  {s}FLAGS:{s}\n", .{ CYAN, RESET });
            std.debug.print("    --test       Run tests after fixing\n", .{});
            std.debug.print("    --verbose    Show detailed analysis\n", .{});
        },
        .explain => {
            std.debug.print("{s}EXPLAIN - Code & Concept Explanation{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri explain <file> | \"<prompt>\"\n", .{});
            std.debug.print("\n");
            std.debug.print("  {s}DESCRIPTION:{s}\n", .{ CYAN, RESET });
            std.debug.print("    Explain Zig code or general concepts.\n", .{});
        },
        .test_cmd => {
            std.debug.print("{s}TEST - Test Generation{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri test <file> [--verbose]\n", .{});
        },
        .doc => {
            std.debug.print("{s}DOC - Documentation Generation{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri doc <file> [--verbose]\n", .{});
        },
        .refactor => {
            std.debug.print("{s}REFACTOR - Code Refactoring Suggestions{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri refactor <file> [--verbose]\n", .{});
        },
        .reason => {
            std.debug.print("{s}REASON - Chain-of-Thought Reasoning{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri reason \"<prompt>\"\n", .{});
        },
        .convert => {
            std.debug.print("{s}CONVERT - WASM/Binary → Ternary{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri convert <input_file> [--output <output_file>]\n", .{});
        },
        .serve => {
            std.debug.print("{s}SERVE - HTTP API Server{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri serve --model <model_path> [--port <port>]\n", .{});
            std.debug.print("\n");
            std.debug.print("  {s}FLAGS:{s}\n", .{ CYAN, RESET });
            std.debug.print("    --model      Path to GGUF model file\n", .{});
            std.debug.print("    --port       HTTP port (default: 8080)\n", .{});
        },
        .bench => {
            std.debug.print("{s}BENCH - Performance Benchmarks{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri bench [--module <name>] [--iter <n>]\n", .{});
        },
        .evolve => {
            std.debug.print("{s}EVOLVE - Fingerprint Evolution (Firebird){s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri evolve [--dim <n>] [--steps <n>]\n", .{});
            std.debug.print("\n");
            std.debug.print("  {s}FLAGS:{s}\n", .{ CYAN, RESET });
            std.debug.print("    --dim        Target dimensionality (default: 128)\n", .{});
            std.debug.print("    --steps      Evolution steps (default: 1000)\n", .{});
        },
        .pipeline => {
            std.debug.print("{s}PIPELINE - Golden Chain Development Cycle{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri pipeline run <task>           Execute full cycle\n", .{});
            std.debug.print("    tri pipeline status               Show pipeline state\n", .{});
            std.debug.print("\n");
            std.debug.print("  {s}DESCRIPTION:{s}\n", .{ CYAN, RESET });
            std.debug.print("    17-link automated development cycle: Spec → Plan → Code → Test → Verify.\n", .{});
            std.debug.print("    Integrates TVC distributed learning for self-improvement.\n", .{});
        },
        .decompose => {
            std.debug.print("{s}DECOMPOSE - Task Breakdown{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri decompose \"<task>\"\n", .{});
        },
        .verify => {
            std.debug.print("{s}VERIFY - Tests + Benchmarks (Links 7-11){s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri verify\n", .{});
        },
        .verdict => {
            std.debug.print("{s}VERDICT - Toxic Code Analysis (Link 14){s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri verdict [--explain]\n", .{});
            std.debug.print("\n");
            std.debug.print("  {s}FLAGS:{s}\n", .{ CYAN, RESET });
            std.debug.print("    --explain    Show detailed analysis\n", .{});
        },
        .intelligence => {
            std.debug.print("{s}INTELLIGENCE - Sacred Intelligence Analysis{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}USAGE:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri intelligence [<symbol>.] [--verbose]\n", .{});
            std.debug.print("    tri intel [<symbol>.]        Alias\n", .{});
            std.debug.print("\n");
            std.debug.print("  {s}DESCRIPTION:{s}\n", .{ CYAN, RESET });
            std.debug.print("    Sacred formula + gematria analysis of symbols.\n", .{});
            std.debug.print("    Uses Sacred Intelligence Engine (Cycle 98).\n", .{});
            std.debug.print("\n");
            std.debug.print("  {s}EXAMPLES:{s}\n", .{ CYAN, RESET });
            std.debug.print("    tri intelligence \"AI.\"          Analyze AI sacredness\n", .{});
            std.debug.print("    tri intelligence \"PHI.\"         Analyze PHI sacredness\n", .{});
            std.debug.print("    tri intel \"TRINITY.\"          Alias for intelligence\n", .{});
        },
        else => {
            std.debug.print("{s}No help available for this command.{s}\n", .{ RED, RESET });
            std.debug.print("  Run 'tri help' for all commands.\n", .{});
        }
    }
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

pub fn printIntelligenceHelp() void {
    std.debug.print("\n{s}SACRED INTELLIGENCE HELP{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    std.debug.print("{s}USAGE:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri intelligence [<symbol>.] [--verbose]\n", .{});
    std.debug.print("  tri intel [<symbol>.]               Alias\n", .{});
    std.debug.print("\n");

    std.debug.print("{s}DESCRIPTION:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Sacred Intelligence Engine (Cycle 98) analyzes symbols using:\n", .{});
    std.debug.print("  - Sacred Formula (phi^2 + 1/phi^2 = 3)\n", .{});
    std.debug.print("  - Coptic Gematria (numeric → sacred mapping)\n", .{});
    std.debug.print("  - Pattern detection (trinity, phi, sacred ratios)\n", .{});
    std.debug.print("\n");

    std.debug.print("{s}FLAGS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  --verbose    Show detailed step-by-step analysis\n", .{});
    std.debug.print("\n");

    std.debug.print("{s}EXAMPLES:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}Symbol Analysis:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    tri intelligence \"AI.\"\n", .{});
    std.debug.print("    → Analyzes AI through sacred lens (φ-index, gematria)\n", .{});
    std.debug.print("\n");
    std.debug.print("  {s}PHI Analysis:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    tri intelligence \"PHI.\"\n", .{});
    std.debug.print("    → Sacred formula: φ^2 + 1/φ^2 = 3 = TRINITY\n", .{});
    std.debug.print("\n");
    std.debug.print("  {s}TRINITY Analysis:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    tri intelligence \"TRINITY.\"\n", .{});
    std.debug.print("    → Full sacred breakdown (3 aspects, φ patterns)\n", .{});
    std.debug.print("\n");

    std.debug.print("{s}COMMAND ALIASES:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}intel{s}               Alias for intelligence (shorter)\n", .{ GREEN, RESET });
    std.debug.print("  {s}intelligence{s}        Full command name\n", .{ GREEN, RESET });
    std.debug.print("\n");

    std.debug.print("{s}OUTPUT:{s}\n", .{ CYAN, RESET });
    std.debug.print("  The engine returns:\n", .{});
    std.debug.print("  - φ-Index (0-1 sacredness score)\n", .{});
    std.debug.print("  - Gematria Value (numeric sacred mapping)\n", .{});
    std.debug.print("  - Sacred Formula Decomposition\n", .{});
    std.debug.print("  - Pattern Matches (trinity, phi, sacred ratios)\n", .{});
    std.debug.print("  - Detailed Analysis (if --verbose)\n", .{});
    std.debug.print("\n");

    std.debug.print("{s}TIPS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  - End symbol with '.' for gematria analysis\n", .{});
    std.debug.print("  - Use ALL CAPS for word gematria\n", .{});
    std.debug.print("  - Multi-word: \"HOLY GRAIL.\" (space = 7 in gematria)\n", .{});
    std.debug.print("  - Numbers: tri intelligence \"123.\"\n", .{});
    std.debug.print("\n");

    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY | SACRED INTELLIGENCE ACTIVE{s}\n\n", .{ GOLDEN, RESET });
}
