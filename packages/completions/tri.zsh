#comp tri
# TRI CLI — Zsh completion
# φ² + 1/φ² = 3 = TRINITY

_tri() {
    local -a commands
    commands=(
        'chat:Interactive chat with AI'
        'code:Generate code with typing effect'
        'gen:Compile VIBEE spec to Zig/Verilog'
        'decompose:Break task into sub-tasks'
        'plan:Generate implementation plan'
        'spec-create:Create .vibee spec template'
        'verify:Run tests and benchmarks'
        'fix:Detect and fix bugs'
        'explain:Explain code or concept'
        'test:Generate tests'
        'doc:Generate documentation'
        'refactor:Suggest refactoring'
        'reason:Chain-of-thought reasoning'
        'pipeline:Execute 17-link Golden Chain'
        'loop-decide:Loop decision: CONTINUE/EXIT'
        'status:Git status --short'
        'diff:Git diff'
        'log:Git log --oneline -10'
        'commit:Git add -A && commit'
        'tvc-demo:Run TVC chat demo'
        'tvc-stats:Show TVC corpus statistics'
        'agents-demo:Multi-agent coordination demo'
        'agents-bench:Multi-agent coordination benchmark'
        'context-demo:Long context window demo'
        'context-bench:Long context window benchmark'
        'rag-demo:Retrieval-augmented generation demo'
        'rag-bench:Retrieval-augmented generation benchmark'
        'voice-demo:Voice I/O demo'
        'voice-bench:Voice I/O benchmark'
        'sandbox-demo:Code sandbox demo'
        'sandbox-bench:Code sandbox benchmark'
        'stream-demo:Multi-modal streaming demo'
        'stream-bench:Multi-modal streaming benchmark'
        'vision-demo:Vision demo'
        'vision-bench:Vision benchmark'
        'finetune-demo:Model fine-tuning demo'
        'finetune-bench:Model fine-tuning benchmark'
        'multimodal-demo:Multi-modal demo'
        'multimodal-bench:Multi-modal benchmark'
        'tooluse-demo:Tool use demo'
        'tooluse-bench:Tool use benchmark'
        'unified-demo:Unified agent demo'
        'unified-bench:Unified agent benchmark'
        'auto-demo:Autonomous agent demo'
        'auto-bench:Autonomous agent benchmark'
        'orch-demo:Orchestration demo'
        'orch-bench:Orchestration benchmark'
        'mmo-demo:Multi-modal orchestration demo'
        'mmo-bench:Multi-modal orchestration benchmark'
        'memory-demo:Cross-modal memory demo'
        'memory-bench:Cross-modal memory benchmark'
        'persist-demo:Persistent storage demo'
        'persist-bench:Persistent storage benchmark'
        'spawn-demo:Dynamic agent spawning demo'
        'spawn-bench:Dynamic agent spawning benchmark'
        'cluster-demo:Multi-node cluster demo'
        'cluster-bench:Multi-node cluster benchmark'
        'worksteal-demo:Work-stealing scheduler demo'
        'worksteal-bench:Work-stealing scheduler benchmark'
        'plugin-demo:Plugin system demo'
        'plugin-bench:Plugin system benchmark'
        'comms-demo:Communication protocol demo'
        'comms-bench:Communication protocol benchmark'
        'observe-demo:Observability demo'
        'observe-bench:Observability benchmark'
        'consensus-demo:Consensus coordination demo'
        'consensus-bench:Consensus coordination benchmark'
        'specexec-demo:Speculative execution demo'
        'specexec-bench:Speculative execution benchmark'
        'governor-demo:Resource governor demo'
        'governor-bench:Resource governor benchmark'
        'fedlearn-demo:Federated learning demo'
        'fedlearn-bench:Federated learning benchmark'
        'eventsrc-demo:Event sourcing demo'
        'eventsrc-bench:Event sourcing benchmark'
        'capsec-demo:Capability security demo'
        'capsec-bench:Capability security benchmark'
        'dtxn-demo:Distributed transaction demo'
        'dtxn-bench:Distributed transaction benchmark'
        'cache-demo:Adaptive caching demo'
        'cache-bench:Adaptive caching benchmark'
        'contract-demo:Agent negotiation demo'
        'contract-bench:Agent negotiation benchmark'
        'workflow-demo:Temporal workflow demo'
        'workflow-bench:Temporal workflow benchmark'
        'math:Sacred mathematics dispatcher'
        'constants:Show sacred constants'
        'phi:Compute φⁿ'
        'fib:Compute Fibonacci'
        'lucas:Compute Lucas numbers'
        'spiral:φ-spiral coordinates'
        'info:System information'
        'version:Show version'
        'help:Show help message'
    )

    if (( CURRENT == 2 )); then
        _describe 'command' commands
    else
        case $words[2] in
            gen|spec-create)
                _files
                ;;
            --model|-m)
                _values 'model' ollama llama2 llama3 mistral
                ;;
            --output|-o)
                _files
                ;;
        esac
    fi
}

_tri "$@"
