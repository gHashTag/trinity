// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Shell Completion Generator v2.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Generate bash/zsh/fish completion scripts
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const CommandRegistry = @import("tri_command_registry.zig").CommandRegistry;
const CommandMetadata = @import("tri_command_registry.zig").CommandMetadata;
const tri_colors = @import("tri_colors.zig");

pub const CompletionGenerator = struct {
    registry: *const CommandRegistry,
    tri_path: []const u8,

    pub fn generateBash(_: *const CompletionGenerator, writer: anytype) !void {
        try writer.print(
            \\# TRI Bash Completion
            \\_tri_completion() {
            \\    local cur prev words cword
            \\    cur="${COMP_WORDS[COMP_CWORD]}"
            \\    prev="${COMP_WORDS[COMP_CWORD-1]}"
            \\    words=("${COMP_WORDS[@]}")
            \\    cword="${COMP_CWORD}"
            \\
            \\    case "${prev}" in
            \\        tri)
            \\            COMPREPLY=($(compgen -W "{{Commands}}"))
            \\            ;;
            \\        bio)
            \\            COMPREPLY=($(compgen -W "dna rna protein codon"))
            \\            ;;
            \\        cosmos)
            \\            COMPREPLY=($(compgen -W "hubble dark expand big-bang"))
            \\            ;;
            \\        neuro)
            \\            COMPREPLY=($(compgen -W "waves consciousness regions network synapse neurons"))
            \\            ;;
            \\        *)
            \\            COMPREPLY=()
            \\            ;;
            \\    esac
            \\}
            \\
            \\complete -F _tri_completion tri
        , .{});
    }

    pub fn generateZsh(_: *const CompletionGenerator, writer: anytype) !void {
        try writer.print(
            \\#compdef tri
            \\
            \\_tri() {
            \\    local -a commands
            \\    commands=({Commands})
            \\
            \\    if [[ CURRENT -eq 2 ]]; then
            \\        _describe 'command' 'tri command'
            \\        compadd "$commands[@]"
            \\    elif [[ CURRENT -eq 3 ]]; then
            \\        case "$words[2]" in
            \\            bio)
            \\                _describe 'bio subcommand' 'Biology subcommand'
            \\                compadd dna rna protein codon
            \\                ;;
            \\            cosmos)
            \\                compadd hubble dark expand big-bang
            \\                ;;
            \\            neuro)
            \\                compadd waves consciousness regions network synapse neurons
            \\                ;;
            \\        esac
            \\    fi
            \\}
        , .{});
    }

    pub fn generateFish(_: *const CompletionGenerator, writer: anytype) !void {
        try writer.print(
            \\# TRI Fish Completion
            \\
            \\complete -c tri -f
            \\
            \\complete -c tri -n __fish_use_subcommand -a -f -k __fish_tri_subcommands
            \\
            \\function __fish_tri_subcommands
            \\    switch __fish_prev_argument
            \\        case bio
            \\            echo -e "dna\nrna\nprotein\ncodon"
            \\            ;;
            \\        case cosmos
            \\            echo -e "hubble\ndark\nexpand\nbig-bang"
            \\            ;;
            \\        case neuro
            \\            echo -e "waves\nconsciousness\nregions\nnetwork\nsynapse\nneurons"
            \\            ;;
            \\    end
            \\end
        , .{});
    }

    /// Get all command names as comma-separated string
    pub fn getCommandsList(self: *const CompletionGenerator) ![]const u8 {
        var list = std.ArrayList(u8).init(std.heap.page_allocator);
        defer list.deinit();

        var first = true;
        for (self.registry.metadata_storage.items) |metadata| {
            if (!first) try list.appendSlice(" ");
            try list.appendSlice(metadata.name);
            first = false;
        }

        return list.toOwnedSlice();
    }

    /// Print completion scripts to stdout
    pub fn printCompletions(self: *const CompletionGenerator, shell: []const u8) !void {
        const file = std.io.getStdOut();
        const writer = file.writer();

        if (std.mem.eql(u8, shell, "bash")) {
            try self.generateBash(writer);
        } else if (std.mem.eql(u8, shell, "zsh")) {
            try self.generateZsh(writer);
        } else if (std.mem.eql(u8, shell, "fish")) {
            try self.generateFish(writer);
        } else {
            tri_colors.printRed("Unknown shell: {s}\n", .{shell});
            tri_colors.printGray("Supported: bash, zsh, fish\n", .{});
        }
    }

    /// Display installation instructions
    pub fn printInstallHelp(_: *const CompletionGenerator) !void {
        tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
        tri_colors.printGold("║              Shell Completion Installation                     ║\n", .{});
        tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

        tri_colors.printCyan("Bash:\n", .{});
        tri_colors.printWhite("  tri completion --bash > ~/.local/share/bash-completion/completions/tri\n", .{});
        tri_colors.printWhite("  source ~/.local/share/bash-completion/completions/tri\n\n", .{});

        tri_colors.printCyan("Zsh:\n", .{});
        tri_colors.printWhite("  tri completion --zsh > ~/.zfunc/_tri\n", .{});
        tri_colors.printWhite("  compinit # (add to ~/.zshrc if not present)\n\n", .{});

        tri_colors.printCyan("Fish:\n", .{});
        tri_colors.printWhite("  tri completion --fish > ~/.config/fish/completions/tri.fish\n\n", .{});

        tri_colors.printGold("Or use: tri completion --install\n\n", .{});
    }

    /// Install completion scripts to appropriate directories
    pub fn installCompletions(_: *const CompletionGenerator) !void {
        tri_colors.printGold("\nInstalling completion scripts...\n\n", .{});

        // Create directories if they don't exist
        const home = std.posix.getenv("HOME") orelse {
            tri_colors.printRed("Error: HOME environment variable not set\n", .{});
            return;
        };

        // Bash
        const bash_dir = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/.local/share/bash-completion/completions", .{home});
        std.fs.cwd().makePath(bash_dir) catch |err| {
            std.log.debug("tri_completion: failed to create bash completion dir: {}", .{err});
        };
        defer std.heap.page_allocator.free(bash_dir);

        const bash_file = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/tri", .{bash_dir});
        defer std.heap.page_allocator.free(bash_file);

        const bash_out = try std.fs.cwd().createFile(bash_file, .{});
        {
            const script =
                \\# TRI Bash Completion
                \\_tri_completion() {
                \\    local cur prev words cword
                \\    cur="${COMP_WORDS[COMP_CWORD]}"
                \\    prev="${COMP_WORDS[COMP_CWORD-1]}"
                \\    words=("${COMP_WORDS[@]}")
                \\    cword="${COMP_CWORD}"
                \\
                \\    case "${prev}" in
                \\        tri)
                \\            COMPREPLY=($(compgen -W "bio cosmos neuro math help completion chat code fix explain test doc refactor reason"))
                \\            ;;
                \\        bio)
                \\            COMPREPLY=($(compgen -W "dna rna protein codon"))
                \\            ;;
                \\        cosmos)
                \\            COMPREPLY=($(compgen -W "hubble dark expand big-bang"))
                \\            ;;
                \\        neuro)
                \\            COMPREPLY=($(compgen -W "waves consciousness regions network synapse neurons"))
                \\            ;;
                \\        *)
                \\            COMPREPLY=()
                \\            ;;
                \\    esac
                \\}
                \\
                \\complete -F _tri_completion tri
                \\
            ;
            try bash_out.writeAll(script);
        }
        bash_out.close();
        tri_colors.printGreen("✓ Bash completion installed to {s}\n", .{bash_file});

        // Zsh
        const zsh_file = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/.zfunc/_tri", .{home});
        defer std.heap.page_allocator.free(zsh_file);

        {
            const zfunc_dir = std.fmt.allocPrint(std.heap.page_allocator, "{s}/.zfunc", .{home}) catch {
                std.log.debug("tri_completion: failed to allocate zfunc dir path", .{});
                return;
            };
            defer std.heap.page_allocator.free(zfunc_dir);
            std.fs.cwd().makePath(zfunc_dir) catch |err| {
                std.log.debug("tri_completion: failed to create zfunc dir: {}", .{err});
            };
        }
        const zsh_out = try std.fs.cwd().createFile(zsh_file, .{});
        {
            const script =
                \\#compdef tri
                \\
                \\_tri() {
                \\    local -a commands
                \\    commands=(bio cosmos neuro math help completion chat code fix explain test doc refactor reason)
                \\
                \\    if [[ CURRENT -eq 2 ]]; then
                \\        _describe 'command' 'tri command'
                \\        compadd "$commands[@]"
                \\    elif [[ CURRENT -eq 3 ]]; then
                \\        case "$words[2]" in
                \\            bio)
                \\                compadd dna rna protein codon
                \\                ;;
                \\            cosmos)
                \\                compadd hubble dark expand big-bang
                \\                ;;
                \\            neuro)
                \\                compadd waves consciousness regions network synapse neurons
                \\                ;;
                \\        esac
                \\    fi
                \\}
                \\
            ;
            try zsh_out.writeAll(script);
        }
        zsh_out.close();
        tri_colors.printGreen("✓ Zsh completion installed to {s}\n", .{zsh_file});

        // Fish
        const fish_dir = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/.config/fish/completions", .{home});
        std.fs.cwd().makePath(fish_dir) catch |err| {
            std.log.debug("tri_completion: failed to create fish completion dir: {}", .{err});
        };
        defer std.heap.page_allocator.free(fish_dir);

        const fish_file = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/tri.fish", .{fish_dir});
        defer std.heap.page_allocator.free(fish_file);

        const fish_out = try std.fs.cwd().createFile(fish_file, .{});
        {
            const script =
                \\# TRI Fish Completion
                \\
                \\complete -c tri -f
                \\
                \\function __fish_tri_subcommands
                \\    switch __fish_prev_argument
                \\        case bio
                \\            echo "dna\\nrna\\nprotein\\ncodon"
                \\            ;;
                \\        case cosmos
                \\            echo "hubble\\ndark\\nexpand\\nbig-bang"
                \\            ;;
                \\        case neuro
                \\            echo "waves\\nconsciousness\\nregions\\nnetwork\\nsynapse\\nneurons"
                \\            ;;
                \\    end
                \\end
                \\
            ;
            try fish_out.writeAll(script);
        }
        fish_out.close();
        tri_colors.printGreen("✓ Fish completion installed to {s}\n\n", .{fish_file});

        tri_colors.printCyan("Restart your shell or run: source ~/.zfunc/_tri (zsh)\n\n", .{});
    }
};
