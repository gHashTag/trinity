# TRI CLI — Bash completion
# φ² + 1/φ² = 3 = TRINITY

_tri_completion() {
    local cur prev commands subcommands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Main commands
    commands="chat code gen decompose plan spec-create verify fix explain test doc refactor reason pipeline status diff log commit tvc-demo tvc-stats agents-demo agents-bench context-demo context-bench rag-demo rag-bench voice-demo voice-bench sandbox-demo sandbox-bench stream-demo stream-bench vision-demo vision-bench finetune-demo finetune-bench multimodal-demo multimodal-bench tooluse-demo tooluse-bench unified-demo unified-bench auto-demo auto-bench orch-demo orch-bench mmo-demo mmo-bench memory-demo memory-bench persist-demo persist-bench spawn-demo spawn-bench cluster-demo cluster-bench worksteal-demo worksteal-bench plugin-demo plugin-bench comms-demo comms-bench observe-demo observe-bench consensus-demo consensus-bench specexec-demo specexec-bench governor-demo governor-bench fedlearn-demo fedlearn-bench eventsrc-demo eventsrc-bench capsec-demo capsec-bench dtxn-demo dtxn-bench cache-demo cache-bench contract-demo contract-bench workflow-demo workflow-bench math constants phi fib lucas spiral loop-decide info version help"

    # Subcommands with arguments
    case "${prev}" in
        tri)
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            return 0
            ;;
        chat|code|explain|fix|test|doc|refactor|reason|decompose|plan)
            # Free-form arguments
            return 0
            ;;
        gen|spec-create)
            # File completion
            COMPREPLY=($(compgen -f -- "${cur}"))
            return 0
            ;;
        --model|-m)
            # Model names
            COMPREPLY=($(compgen -W "ollama llama2 llama3 mistral" -- "${cur}"))
            return 0
            ;;
        --output|-o)
            # File completion
            COMPREPLY=($(compgen -f -- "${cur}"))
            return 0
            ;;
        *)
            ;;
    esac

    # Option flags
    if [[ "${cur}" == -* ]]; then
        opts="--help --version --stream --model --output"
        COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
        return 0
    fi
}

complete -F _tri_completion tri
