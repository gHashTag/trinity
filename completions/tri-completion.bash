#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRI CLI — Bash Completion
# ═══════════════════════════════════════════════════════════════════════════════
#
# Bash completion for TRI CLI command
# Install: source completions/tri-completion.bash from ~/.bashrc
# Or: cp completions/tri-completion.bash /etc/bash_completion.d/tri
#
# φ² + 1/φ² = 3 = TRINITY
# ═══════════════════════════════════════════════════════════════════════════════

_tri_completions() {
    local cur prev words cword
    _init_completion -s || return

    # Main commands
    local commands="help version info phi fib lucas spiral gematria gem formula constants sacred"
    commands="$commands chem bio cosmos neuro"
    commands="$commands gen fix explain test doc refactor reason convert"
    commands="$commands serve bench evolve"
    commands="$commands commit diff status log"
    commands="$commands pipeline decompose plan verify verdict"
    commands="$commands spec-create spec_create loop-decide loop_decide"
    commands="$commands tvc-demo agents-demo context-demo rag-demo"
    commands="$commands clean fmt stats doctor dr igla"
    commands="$commands analyze search context ctx"
    commands="$commands time install build deck fpga"
    commands="$commands quantum release"
    commands="$commands identity swarm govern dashboard dash omega math-agent mathagent"
    commands="$commands distributed multi-cluster mc intelligence intel"
    commands="$commands orchestrator orch flow mm-orch mmo"
    commands="$commands auto-commit ac ml-optimize mlopt"
    commands="$commands deploy-dashboard deploy self-host safeguards sg"

    # Chemistry subcommands
    local chem_subcommands="periodic element mass formula balance moles atoms ideal-gas ph redox"

    # Biology subcommands
    local bio_subcommands="dna rna protein codon genome sequence"

    # Cosmology subcommands
    local cosmos_subcommands="hubble dark predict expand big-bang"

    # Neuroscience subcommands
    local neuro_subcommands="waves consciousness regions network synapse neurons"

    # Math subcommands
    local math_subcommands="transcendental fibonacci golden prime sacred constants"

    # Gematria options
    local gematria_formats="english hebrew greek isopsophy full-reduction kv"

    # Global flags
    local global_flags="--verbose --dry-run --yes --output -v -h --help"

    # Command-specific flags
    local gen_flags="--chat --model --serve --port"
    local serve_flags="--port --grpc-port --protocols --daemon --verbose -p -d"
    local fix_flags="--file --line --all -f -l"
    local phi_flags="--inverse --powers --fibonacci"

    # Parse current command
    local cmd="${words[1]}"

    case "$cmd" in
        chem)
            case "${prev}" in
                chem)
                    COMPREPLY=($(compgen -W "$chem_subcommands" -- "$cur"))
                    ;;
                element)
                    # Provide element symbols
                    local elements="H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co Ni Cu Zn Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba Hf Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn Fr Ra"
                    COMPREPLY=($(compgen -W "$elements" -- "$cur"))
                    ;;
                mass|formula|balance|moles|atoms|ideal-gas|ph|redox)
                    # No completion for arguments (free-form)
                    ;;
            esac
            ;;

        bio)
            if [[ "$prev" == "bio" ]]; then
                COMPREPLY=($(compgen -W "$bio_subcommands" -- "$cur"))
            fi
            ;;

        cosmos)
            if [[ "$prev" == "cosmos" ]]; then
                COMPREPLY=($(compgen -W "$cosmos_subcommands" -- "$cur"))
            fi
            ;;

        neuro)
            if [[ "$prev" == "neuro" ]]; then
                COMPREPLY=($(compgen -W "$neuro_subcommands" -- "$cur"))
            fi
            ;;

        gem|gematria)
            if [[ "$prev" == "gem" || "$prev" == "gematria" ]]; then
                COMPREPLY=($(compgen -W "$gematria_formats" -- "$cur"))
            fi
            ;;

        math)
            if [[ "$prev" == "math" ]]; then
                COMPREPLY=($(compgen -W "$math_subcommands" -- "$cur"))
            fi
            ;;

        gen)
            COMPREPLY=($(compgen -W "$gen_flags" -- "$cur"))
            COMPREPLY+=($(compgen -f -X "*.vibee" -- "$cur"))
            COMPREPLY+=($(compgen -f -X "*.tri" -- "$cur"))
            ;;

        serve)
            COMPREPLY=($(compgen -W "$serve_flags" -- "$cur"))
            ;;

        fix)
            COMPREPLY=($(compgen -W "$fix_flags" -- "$cur"))
            COMPREPLY+=($(compgen -f -- "$cur"))
            ;;

        phi)
            COMPREPLY=($(compgen -W "$phi_flags" -- "$cur"))
            ;;

        *)
            # Default: offer main commands and global flags
            COMPREPLY=($(compgen -W "$commands $global_flags" -- "$cur"))
            ;;
    esac
}

complete -F _tri_completions tri

# Also complete with tri- prefix if linked
complete -F _tri_completions tri-
