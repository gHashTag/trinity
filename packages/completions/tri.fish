# TRI CLI — Fish shell completion
# φ² + 1/φ² = 3 = TRINITY

function __tri_subcommands
    echo chat\t'Interactive chat with AI'
    echo code\t'Generate code'
    echo gen\t'Compile VIBEE spec'
    echo decompose\t'Break task into sub-tasks'
    echo plan\t'Generate implementation plan'
    echo spec-create\t'Create .vibee spec template'
    echo verify\t'Run tests'
    echo fix\t'Detect and fix bugs'
    echo explain\t'Explain code'
    echo test\t'Generate tests'
    echo doc\t'Generate documentation'
    echo refactor\t'Suggest refactoring'
    echo reason\t'Chain-of-thought reasoning'
    echo pipeline\t'Execute Golden Chain'
    echo loop-decide\t'Loop decision'
    echo status\t'Git status'
    echo diff\t'Git diff'
    echo log\t'Git log'
    echo commit\t'Git commit'
    echo tvc-demo\t'TVC chat demo'
    echo tvc-stats\t'TVC statistics'
    echo agents-demo\t'Multi-agent demo'
    echo agents-bench\t'Multi-agent benchmark'
    echo context-demo\t'Long context demo'
    echo context-bench\t'Long context benchmark'
    echo rag-demo\t'RAG demo'
    echo rag-bench\t'RAG benchmark'
    echo voice-demo\t'Voice I/O demo'
    echo voice-bench\t'Voice I/O benchmark'
    echo sandbox-demo\t'Code sandbox demo'
    echo sandbox-bench\t'Code sandbox benchmark'
    echo stream-demo\t'Streaming demo'
    echo stream-bench\t'Streaming benchmark'
    echo vision-demo\t'Vision demo'
    echo vision-bench\t'Vision benchmark'
    echo finetune-demo\t'Fine-tuning demo'
    echo finetune-bench\t'Fine-tuning benchmark'
    echo multimodal-demo\t'Multi-modal demo'
    echo multimodal-bench\t'Multi-modal benchmark'
    echo tooluse-demo\t'Tool use demo'
    echo tooluse-bench\t'Tool use benchmark'
    echo unified-demo\t'Unified agent demo'
    echo unified-bench\t'Unified agent benchmark'
    echo auto-demo\t'Autonomous demo'
    echo auto-bench\t'Autonomous benchmark'
    echo orch-demo\t'Orchestration demo'
    echo orch-bench\t'Orchestration benchmark'
    echo mmo-demo\t'Multi-modal orchestration demo'
    echo mmo-bench\t'Multi-modal orchestration benchmark'
    echo memory-demo\t'Memory demo'
    echo memory-bench\t'Memory benchmark'
    echo persist-demo\t'Persistence demo'
    echo persist-bench\t'Persistence benchmark'
    echo spawn-demo\t'Spawn demo'
    echo spawn-bench\t'Spawn benchmark'
    echo cluster-demo\t'Cluster demo'
    echo cluster-bench\t'Cluster benchmark'
    echo worksteal-demo\t'Work-stealing demo'
    echo worksteal-bench\t'Work-stealing benchmark'
    echo plugin-demo\t'Plugin demo'
    echo plugin-bench\t'Plugin benchmark'
    echo comms-demo\t'Comms demo'
    echo comms-bench\t'Comms benchmark'
    echo observe-demo\t'Observe demo'
    echo observe-bench\t'Observe benchmark'
    echo consensus-demo\t'Consensus demo'
    echo consensus-bench\t'Consensus benchmark'
    echo specexec-demo\t'Spec exec demo'
    echo specexec-bench\t'Spec exec benchmark'
    echo governor-demo\t'Governor demo'
    echo governor-bench\t'Governor benchmark'
    echo fedlearn-demo\t'Federated learning demo'
    echo fedlearn-bench\t'Federated learning benchmark'
    echo eventsrc-demo\t'Event sourcing demo'
    echo eventsrc-bench\t'Event sourcing benchmark'
    echo capsec-demo\t'Capability security demo'
    echo capsec-bench\t'Capability security benchmark'
    echo dtxn-demo\t'Distributed txn demo'
    echo dtxn-bench\t'Distributed txn benchmark'
    echo cache-demo\t'Cache demo'
    echo cache-bench\t'Cache benchmark'
    echo contract-demo\t'Contract demo'
    echo contract-bench\t'Contract benchmark'
    echo workflow-demo\t'Workflow demo'
    echo workflow-bench\t'Workflow benchmark'
    echo math\t'Sacred mathematics'
    echo constants\t'Show sacred constants'
    echo phi\t'Compute φⁿ'
    echo fib\t'Compute Fibonacci'
    echo lucas\t'Compute Lucas'
    echo spiral\t'φ-spiral coordinates'
    echo info\t'System information'
    echo version\t'Show version'
    echo help\t'Show help'
end

function __tri_using_command
    set -l cmd (commandline -opc)
    if [ (count $cmd) -gt 1 ]
        echo $cmd[2]
    end
end

function __tri_needs_command
    set -l cmd (commandline -opc)
    return [ (count $cmd) -eq 1 ]
end

complete -c tri -f -n __tri_needs_command -a "(__tri_subcommands)"

complete -c tri -f -n "__tri_using_command = gen" -a "(__fish_complete_suffix .vibee)"
complete -c tri -f -n "__tri_using_command = spec-create" -a "(__fish_complete_suffix .vibee)"
complete -c tri -f -n "__tri_using_command = code" -k
complete -c tri -f -n "__tri_using_command = chat" -k
complete -c tri -f -n "__tri_using_command = explain" -k
complete -c tri -f -n "__tri_using_command = fix" -a "(__fish_complete_suffix .zig)"
complete -c tri -f -n "__tri_using_command = test" -a "(__fish_complete_suffix .zig)"
complete -c tri -f -n "__tri_using_command = doc" -a "(__fish_complete_suffix .zig)"
complete -c tri -f -n "__tri_using_command = refactor" -a "(__fish_complete_suffix .zig)"

complete -c tri -s h -l help -d 'Show help'
complete -c tri -s v -l version -d 'Show version'
complete -c tri -s m -l model -d 'Model name' -xa "ollama llama2 llama3 mistral"
complete -c tri -s o -l output -d 'Output file' -r
complete -c tri -l stream -d 'Enable streaming'
