// @origin(spec:tri_autocomplete.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI AUTOCOMPLETE — Shell completion for bash and zsh
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri autocomplete --print    Output completion script to stdout
//   tri autocomplete --install  Install to ~/.bashrc or ~/.zshrc
//   tri autocomplete --uninstall Remove from shell config
//
// Supports:
//   - All major tri subcommands (cell, farm, cloud, git, etc.)
//   - Subcommand options and flags (--json, --help, etc.)
//   - Alias system (tri c = tri cell, stored in ~/.tri/config.json)
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const Allocator = std.mem.Allocator;

// ANSI colors
const RESET = "\x1b[0m";
const GREEN = "\x1b[32m";
const CYAN = "\x1b[36m";
const YELLOW = "\x1b[33m";
const GOLDEN = "\x1b[38;5;220m";
const BOLD = "\x1b[1m";

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIG & ALIASES
// ═══════════════════════════════════════════════════════════════════════════════

const TRI_CONFIG_DIR = ".tri";
const TRI_CONFIG_FILE = "config.json";

const Config = struct {
    aliases: std.StringHashMap([]const u8),

    fn init(allocator: Allocator) Config {
        return .{
            .aliases = std.StringHashMap([]const u8).init(allocator),
        };
    }

    fn deinit(self: *Config) void {
        var iter = self.aliases.iterator();
        while (iter.next()) |entry| {
            self.aliases.allocator.free(entry.key_ptr.*) catch {};
            self.aliases.allocator.free(entry.value_ptr.*) catch {};
        }
        self.aliases.deinit();
    }

    fn getDefaultAliases(allocator: Allocator) !std.StringHashMap([]const u8) {
        var aliases = std.StringHashMap([]const u8).init(allocator);
        try aliases.put(try allocator.dupe(u8, "c"), try allocator.dupe(u8, "cell"));
        try aliases.put(try allocator.dupe(u8, "f"), try allocator.dupe(u8, "farm"));
        try aliases.put(try allocator.dupe(u8, "g"), try allocator.dupe(u8, "git"));
        try aliases.put(try allocator.dupe(u8, "i"), try allocator.dupe(u8, "issue"));
        try aliases.put(try allocator.dupe(u8, "a"), try allocator.dupe(u8, "agent"));
        try aliases.put(try allocator.dupe(u8, "p"), try allocator.dupe(u8, "pipeline"));
        try aliases.put(try allocator.dupe(u8, "d"), try allocator.dupe(u8, "deploy"));
        try aliases.put(try allocator.dupe(u8, "s"), try allocator.dupe(u8, "status"));
        try aliases.put(try allocator.dupe(u8, "t"), try allocator.dupe(u8, "test"));
        try aliases.put(try allocator.dupe(u8, "cs"), try allocator.dupe(u8, "cell status"));
        try aliases.put(try allocator.dupe(u8, "fs"), try allocator.dupe(u8, "farm status"));
        try aliases.put(try allocator.dupe(u8, "cl"), try allocator.dupe(u8, "cloud"));
        return aliases;
    }
};

fn getConfigPath(allocator: Allocator) ![]const u8 {
    const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch return error.HomeNotFound;
    defer allocator.free(home_dir);
    return std.fs.path.join(allocator, &.{ home_dir, TRI_CONFIG_DIR, TRI_CONFIG_FILE });
}

fn loadConfig(allocator: Allocator) !?Config {
    const config_path = try getConfigPath(allocator);
    defer allocator.free(config_path);

    const file = std.fs.openFileAbsolute(config_path, .{}) catch |err| {
        if (err == error.FileNotFound) return null;
        return err;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 1024 * 1024) catch return error.ReadFailed;
    defer allocator.free(content);

    var config = Config.init(allocator);
    errdefer config.deinit();

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    if (parsed.value != .object) return null;

    const aliases_obj = parsed.value.object.get("aliases") orelse return config;
    if (aliases_obj != .object) return config;

    var iter = aliases_obj.object.iterator();
    while (iter.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;
        if (value != .string) continue;

        const key_copy = try allocator.dupe(u8, key);
        const value_copy = try allocator.dupe(u8, value.string);
        try config.aliases.put(key_copy, value_copy);
    }

    return config;
}

fn saveConfig(allocator: Allocator, config: *const Config) !void {
    const config_path = try getConfigPath(allocator);
    defer allocator.free(config_path);

    const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch return error.HomeNotFound;
    defer allocator.free(home_dir);

    const config_dir = try std.fs.path.join(allocator, &.{ home_dir, TRI_CONFIG_DIR });
    defer allocator.free(config_dir);

    try std.fs.cwd().makePath(config_dir);

    const aliases_obj = try std.json.ObjectMap.initCapacity(allocator, @intCast(config.aliases.count()));
    defer aliases_obj.deinit(allocator);

    var iter = config.aliases.iterator();
    while (iter.next()) |entry| {
        try aliases_obj.put(allocator, entry.key_ptr.*, std.json.Value{ .string = entry.value_ptr.* });
    }

    const root = std.json.Value{ .object = std.json.ObjectMap.initCapacity(allocator, 1) };
    try root.object.put("aliases", std.json.Value{ .object = aliases_obj });

    const options = std.json.StringifyOptions{
        .whitespace = .{ .indent = .{ .space = 2 } },
    };

    const stringified = try std.json.allocPrintZ(allocator, root, options);
    defer allocator.free(stringified);

    const file = try std.fs.createFileAbsolute(config_path, .{ .read = true });
    defer file.close();
    try file.writeAll(stringified);
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DATA
// ═══════════════════════════════════════════════════════════════════════════════

const CommandInfo = struct {
    name: []const u8,
    description: []const u8,
    subcommands: []const []const u8,
    flags: []const []const u8,
};

fn getCommands() []const CommandInfo {
    return &[_]CommandInfo{
        .{
            .name = "cell",
            .description = "Honeycomb module management",
            .subcommands = &[_][]const u8{
                "list", "info", "init", "check", "deps", "graph",
                "health", "enable", "disable", "verify", "check-boundaries",
            },
            .flags = &[_][]const u8{ "--json", "--help" },
        },
        .{
            .name = "farm",
            .description = "Railway training farm management",
            .subcommands = &[_][]const u8{
                "status", "idle", "recycle", "fill", "evolve",
                "from-issues", "watch-daemon", "arena",
            },
            .flags = &[_][]const u8{ "--json", "--help" },
        },
        .{
            .name = "cloud",
            .description = "Railway cloud operations",
            .subcommands = &[_][]const u8{
                "status", "logs", "vars", "deploy", "exec", "pull",
                "ssh-status", "spawn", "spawn-all", "kill", "agents",
                "cleanup", "sync", "history", "pipeline", "verify",
                "merge", "api-check", "redeploy", "diagnose", "issue-create",
                "metrics", "record-metrics", "monitor", "restart",
            },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "git",
            .description = "Git operations",
            .subcommands = &[_][]const u8{
                "status", "commit", "diff", "log", "push", "pull",
            },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "issue",
            .description = "GitHub issue management",
            .subcommands = &[_][]const u8{
                "create", "comment", "close", "decompose", "list", "view", "assign",
            },
            .flags = &[_][]const u8{
                "--body", "--labels", "--agent", "--parent", "--help",
            },
        },
        .{
            .name = "agent",
            .description = "Agent operations",
            .subcommands = &[_][]const u8{ "run", "list", "spawn" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "board",
            .description = "Project board management",
            .subcommands = &[_][]const u8{ "sync", "list" },
            .flags = &[_][]const u8{ "--issue", "--column", "--help" },
        },
        .{
            .name = "pr",
            .description = "Pull request management",
            .subcommands = &[_][]const u8{ "create", "list", "merge", "review" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "phoenix",
            .description = "Phoenix cell regeneration system",
            .subcommands = &[_][]const u8{ "scan", "regen", "lineage", "biopsy" },
            .flags = &[_][]const u8{ "--all", "--help" },
        },
        .{
            .name = "chimera",
            .description = "Fused multi-step commands",
            .subcommands = &[_][]const u8{
                "farm-cycle", "train-cycle", "deploy-full",
                "doctor-full", "research-deep",
            },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "queen",
            .description = "Queen daemon",
            .subcommands = &[_][]const u8{ "start", "stop", "status", "logs" },
            .flags = &[_][]const u8{ "--daemon", "--help" },
        },
        .{
            .name = "ouroboros",
            .description = "Self-evolving recursive improvement",
            .subcommands = &[_][]const u8{ "run", "status", "reset" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "patent",
            .description = "Patent management",
            .subcommands = &[_][]const u8{
                "status", "analysis", "claims", "strategy", "snapshot", "draft", "zenodo",
            },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "depin",
            .description = "DePIN node protocol",
            .subcommands = &[_][]const u8{ "status", "nodes", "fitness" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "memory",
            .description = "Memory operations",
            .subcommands = &[_][]const u8{ "list", "read", "write", "search", "gc", "stats" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "experience",
            .description = "Experience episode storage",
            .subcommands = &[_][]const u8{ "save", "recall", "mistakes" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "ui",
            .description = "Queen UI launcher",
            .subcommands = &[_][]const u8{ "build", "kill", "launch" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "plugin",
            .description = "Plugin management",
            .subcommands = &[_][]const u8{ "list", "install", "uninstall", "info" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "events",
            .description = "Event bus operations",
            .subcommands = &[_][]const u8{ "list", "emit", "status", "subscribe" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "init",
            .description = "Initialize new project or cell",
            .subcommands = &[_][]const u8{},
            .flags = &[_][]const u8{ "--cell", "--help" },
        },
        .{
            .name = "test",
            .description = "Run tests",
            .subcommands = &[_][]const u8{ "spec", "report", "e2e", "--repl", "--coverage" },
            .flags = &[_][]const u8{
                "--repl", "-r", "--generate", "-g", "--coverage",
                "--full", "-f", "--category", "-c", "--verbose", "-v",
            },
        },
        .{
            .name = "notify",
            .description = "Send Telegram notification",
            .subcommands = &[_][]const u8{},
            .flags = &[_][]const u8{ "--chat", "--pin", "--edit" },
        },
        .{
            .name = "spec",
            .description = "Specification operations",
            .subcommands = &[_][]const u8{ "create" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "bench",
            .description = "Benchmark operations",
            .subcommands = &[_][]const u8{ "compare", "record", "history" },
            .flags = &[_][]const u8{ "--filter", "--help" },
        },
        .{
            .name = "pipeline",
            .description = "Golden Chain pipeline",
            .subcommands = &[_][]const u8{},
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "chain",
            .description = "Golden Chain individual links",
            .subcommands = &[_][]const u8{},
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "deploy",
            .description = "Deployment operations",
            .subcommands = &[_][]const u8{ "status" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "job",
            .description = "Job runtime",
            .subcommands = &[_][]const u8{ "start", "status", "logs", "artifacts", "cancel", "list" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "doctor",
            .description = "Doctor system health check",
            .subcommands = &[_][]const u8{ "init", "scan", "mark", "report", "plan", "heal" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "self",
            .description = "Self operations",
            .subcommands = &[_][]const u8{ "test", "health", "benchmark" },
            .flags = &[_][]const u8{ "--help" },
        },
        .{
            .name = "version",
            .description = "Show version",
            .subcommands = &[_][]const u8{},
            .flags = &[_][]const u8{},
        },
        .{
            .name = "autocomplete",
            .description = "Shell completion",
            .subcommands = &[_][]const u8{},
            .flags = &[_][]const u8{ "--print", "--install", "--uninstall" },
        },
    };
}

fn getAllTopLevelCommands(allocator: Allocator) ![][]const u8 {
    const commands = getCommands();
    var list = try std.ArrayList([]const u8).initCapacity(allocator, commands.len + 20);
    for (commands) |cmd| {
        try list.append(try allocator.dupe(u8, cmd.name));
    }
    // Add flat commands
    const flat_commands = &[_][]const u8{
        "chat", "code", "gen", "fix", "explain", "doc", "refactor",
        "reason", "convert", "serve", "evolve", "commit", "diff",
        "status", "log", "decompose", "plan", "verify", "verdict",
        "distributed", "multi-cluster", "intelligence", "regen",
        "clean", "fmt", "stats", "igla", "identity", "swarm", "mu",
        "govern", "dashboard", "omega", "math-agent", "analyze",
        "search", "deps", "context-info", "time", "install", "build",
        "deck-generate", "fpga-demo", "fpga", "train", "sacred-const",
        "sacred-full-cycle", "quantum", "release-cosmic", "omega-cmd",
        "all-cmd", "holo-cmd", "release-absolute", "omega-evolve",
        "launch", "info", "help", "needle", "needle-search",
        "needle-check", "commands", "mcp", "lint", "enrich",
        "sync-check", "github", "zenodo", "loop", "faculty", "research",
        "experiment", "trace", "eval", "metrics", "context-load", "infer",
    };
    for (flat_commands) |cmd| {
        try list.append(try allocator.dupe(u8, cmd));
    }
    return list.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BASH COMPLETION GENERATION
// ═══════════════════════════════════════════════════════════════════════════════

fn generateBashCompletion(allocator: Allocator, writer: anytype) !void {
    try writer.writeAll(
        \\# tri bash completion
        \\# Generated by Trinity - DO NOT EDIT DIRECTLY
        \\# φ² + 1/φ² = 3 = TRINITY
        \\
    );

    // Main completion function
    try writer.print(
        \\_tri_completion() {{
        \\    local cur prev words cword
        \\    _init_completion || return
        \\
        \\    # Handle aliases
        \\    case "$prev" in
        \\        c) COMPREPLY=($(compgen -W "list info init check deps graph health enable disable verify check-boundaries" -- "$cur")); return ;;
        \\        f) COMPREPLY=($(compgen -W "status idle recycle fill evolve from-issues watch-daemon arena" -- "$cur")); return ;;
        \\        g) COMPREPLY=($(compgen -W "status commit diff log push pull" -- "$cur")); return ;;
        \\        i) COMPREPLY=($(compgen -W "create comment close decompose list view assign" -- "$cur")); return ;;
        \\        a) COMPREPLY=($(compgen -W "run list spawn" -- "$cur")); return ;;
        \\        p) COMPREPLY=($(compgen -W "run chain decompose plan verify verdict" -- "$cur")); return ;;
        \\        d) COMPREPLY=($(compgen -W "status" -- "$cur")); return ;;
        \\        s) COMPREPLY=($(compgen -W "status" -- "$cur")); return ;;
        \\        t) COMPREPLY=($(compgen -W "spec report e2e --repl --coverage" -- "$cur")); return ;;
        \\    esac
        \\
        \\    # Top-level commands
        \\    if [[ $cword -eq 1 ]]; then
        \\        COMPREPLY=($(compgen -W "{s}" -- "$cur"))
        \\        return
        \\    fi
        \\
        \\    # Subcommands
        \\    local cmd="${{words[1]}}"
        \\    case "$cmd" in
        \\        cell)
        \\            COMPREPLY=($(compgen -W "list info init check deps graph health enable disable verify check-boundaries --json --help" -- "$cur"))
        \\            ;;
        \\        farm)
        \\            COMPREPLY=($(compgen -W "status idle recycle fill evolve from-issues watch-daemon arena --json --help" -- "$cur"))
        \\            ;;
        \\        cloud)
        \\            COMPREPLY=($(compgen -W "status logs vars deploy exec pull ssh-status spawn spawn-all kill agents cleanup sync history pipeline verify merge api-check redeploy diagnose issue-create metrics record-metrics monitor restart --help" -- "$cur"))
        \\            ;;
        \\        git)
        \\            COMPREPLY=($(compgen -W "status commit diff log push pull --help" -- "$cur"))
        \\            ;;
        \\        issue)
        \\            COMPREPLY=($(compgen -W "create comment close decompose list view assign --body --labels --agent --parent --help" -- "$cur"))
        \\            ;;
        \\        agent)
        \\            COMPREPLY=($(compgen -W "run list spawn --help" -- "$cur"))
        \\            ;;
        \\        board)
        \\            COMPREPLY=($(compgen -W "sync list --issue --column --help" -- "$cur"))
        \\            ;;
        \\        pr)
        \\            COMPREPLY=($(compgen -W "create list merge review --help" -- "$cur"))
        \\            ;;
        \\        phoenix)
        \\            COMPREPLY=($(compgen -W "scan regen lineage biopsy --all --help" -- "$cur"))
        \\            ;;
        \\        chimera)
        \\            COMPREPLY=($(compgen -W "farm-cycle train-cycle deploy-full doctor-full research-deep --help" -- "$cur"))
        \\            ;;
        \\        queen)
        \\            COMPREPLY=($(compgen -W "start stop status logs --daemon --help" -- "$cur"))
        \\            ;;
        \\        ouroboros)
        \\            COMPREPLY=($(compgen -W "run status reset --help" -- "$cur"))
        \\            ;;
        \\        patent)
        \\            COMPREPLY=($(compgen -W "status analysis claims strategy snapshot draft zenodo --help" -- "$cur"))
        \\            ;;
        \\        depin)
        \\            COMPREPLY=($(compgen -W "status nodes fitness --help" -- "$cur"))
        \\            ;;
        \\        memory)
        \\            COMPREPLY=($(compgen -W "list read write search gc stats --help" -- "$cur"))
        \\            ;;
        \\        experience)
        \\            COMPREPLY=($(compgen -W "save recall mistakes --help" -- "$cur"))
        \\            ;;
        \\        ui)
        \\            COMPREPLY=($(compgen -W "build kill launch --help" -- "$cur"))
        \\            ;;
        \\        plugin)
        \\            COMPREPLY=($(compgen -W "list install uninstall info --help" -- "$cur"))
        \\            ;;
        \\        events)
        \\            COMPREPLY=($(compgen -W "list emit status subscribe --help" -- "$cur"))
        \\            ;;
        \\        init)
        \\            COMPREPLY=($(compgen -W "--cell --help" -- "$cur"))
        \\            ;;
        \\        test)
        \\            COMPREPLY=($(compgen -W "spec report e2e --repl -r --generate -g --coverage --full -f --category -c --verbose -v --help -h" -- "$cur"))
        \\            ;;
        \\        notify)
        \\            COMPREPLY=($(compgen -W "--chat --pin --edit" -- "$cur"))
        \\            ;;
        \\        spec)
        \\            COMPREPLY=($(compgen -W "create --help" -- "$cur"))
        \\            ;;
        \\        bench)
        \\            COMPREPLY=($(compgen -W "compare record history --filter --help" -- "$cur"))
        \\            ;;
        \\        deploy)
        \\            COMPREPLY=($(compgen -W "status --help" -- "$cur"))
        \\            ;;
        \\        job)
        \\            COMPREPLY=($(compgen -W "start status logs artifacts cancel list --help" -- "$cur"))
        \\            ;;
        \\        doctor)
        \\            COMPREPLY=($(compgen -W "init scan mark report plan heal --help" -- "$cur"))
        \\            ;;
        \\        self)
        \\            COMPREPLY=($(compgen -W "test health benchmark --help" -- "$cur"))
        \\            ;;
        \\        autocomplete)
        \\            COMPREPLY=($(compgen -W "--print --install --uninstall" -- "$cur"))
        \\            ;;
        \\        *)
        \\            # Default to file completion
        \\            COMPREPLY=($(compgen -f -- "$cur"))
        \\            ;;
        \\    esac
        \\}}
        \\
        \\complete -F _tri_completion tri
        \\
    , .{try getCommandsList(allocator)});
}

fn getCommandsList(allocator: Allocator) ![]const u8 {
    const commands = getCommands();
    var list = try std.ArrayList(u8).initCapacity(allocator, 4096);
    const writer = list.writer(allocator);

    for (commands, 0..) |cmd, i| {
        if (i > 0) try writer.writeAll(" ");
        try writer.writeAll(cmd.name);
    }

    // Add flat commands
    const flat_commands = &[_][]const u8{
        "chat", "code", "gen", "fix", "explain", "doc", "refactor",
        "reason", "convert", "serve", "evolve", "commit", "diff",
        "log", "decompose", "plan", "verify", "verdict", "status",
        "distributed", "intelligence", "regen", "clean", "fmt",
        "stats", "igla", "identity", "swarm", "mu", "govern",
        "dashboard", "omega", "analyze", "search", "deps",
        "context-info", "time", "install", "build", "fpga",
        "train", "sacred-const", "quantum", "launch", "info",
        "help", "version", "needle", "commands", "mcp", "lint",
        "enrich", "sync-check", "github", "zenodo", "loop",
        "faculty", "research", "experiment", "trace", "eval",
        "metrics", "context-load", "infer", "self", "events",
        "init", "plugin", "ui", "bench", "spec", "notify",
        "job", "doctor", "autocomplete",
    };
    for (flat_commands) |cmd| {
        try writer.writeAll(" ");
        try writer.writeAll(cmd);
    }

    return list.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ZSH COMPLETION GENERATION
// ═══════════════════════════════════════════════════════════════════════════════

fn generateZshCompletion(allocator: Allocator, writer: anytype) !void {
    try writer.print(
        \\#compdef tri
        \\# tri zsh completion
        \\# Generated by Trinity - DO NOT EDIT DIRECTLY
        \\# φ² + 1/φ² = 3 = TRINITY
        \\
        \\_tri() {{
        \\    local -a commands
        \\
    , .{});

    // Define subcommand functions
    const commands = getCommands();
    for (commands) |cmd| {
        try writer.print("    (( $+functions{_tri_{s}} )) || _tri_{s}() {{\n", .{cmd.name});
        try writer.print("        _arguments -s \\\n", .{});
        for (cmd.flags) |flag| {
            try writer.print("            \"{s}\" \\\n", .{flag});
        }
        if (cmd.subcommands.len > 0) {
            try writer.print("            \"1: :({s})\" \\\n", .{try joinStrings(allocator, cmd.subcommands, " ")});
            try writer.print("            \"*::arg:->args\"\n", .{});
            try writer.print("        case $words[2] in\n", .{});
            for (cmd.subcommands) |sub| {
                try writer.print("            {s}) _arguments -s \"*:: :_files\" ;;\n", .{sub});
            }
            try writer.print("        esac\n", .{});
        }
        try writer.print("    }}\n\n", .{});
    }

    try writer.print(
        \\    commands=(
        \\        'cell:Honeycomb module management'
        \\        'farm:Railway training farm'
        \\        'cloud:Railway cloud operations'
        \\        'git:Git operations'
        \\        'issue:GitHub issues'
        \\        'agent:Agent operations'
        \\        'board:Project board'
        \\        'pr:Pull requests'
        \\        'phoenix:Cell regeneration'
        \\        'chimera:Fused commands'
        \\        'queen:Queen daemon'
        \\        'ouroboros:Self-evolution'
        \\        'patent:Patent management'
        \\        'depin:DePIN protocol'
        \\        'memory:Memory ops'
        \\        'experience:Experience storage'
        \\        'ui:Queen UI'
        \\        'plugin:Plugins'
        \\        'events:Event bus'
        \\        'init:Initialize'
        \\        'test:Run tests'
        \\        'notify:Telegram notify'
        \\        'spec:Specifications'
        \\        'bench:Benchmarks'
        \\        'pipeline:Golden Chain'
        \\        'chain:Chain links'
        \\        'deploy:Deploy'
        \\        'job:Jobs'
        \\        'doctor:Health check'
        \\        'self:Self ops'
        \\        'autocomplete:Shell completion'
        \\        'version:Show version'
        \\        'help:Show help'
        \\    )
        \\
        \\    if [[ $CURRENT -gt 1 ]]; then
        \\        local cmd=$words[2]
        \\        curcontext="${{curcontext%:*:*}}:tri-$cmd"
        \\        _call_function ret _tri_$cmd
        \\    else
        \\        _describe -V command commands
        \\    fi
        \\}}
        \\
    , .{});
}

fn joinStrings(allocator: Allocator, strings: []const []const u8, sep: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).initCapacity(allocator, 1024);
    for (strings, 0..) |s, i| {
        if (i > 0) try result.appendSlice(sep);
        try result.appendSlice(s);
    }
    return result.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// INSTALL / UNINSTALL
// ═══════════════════════════════════════════════════════════════════════════════

const Shell = enum {
    bash,
    zsh,
    auto,

    fn detect() Shell {
        const shell_env = std.process.getEnvVarOwned(std.heap.page_allocator, "SHELL") catch return .auto;
        defer std.heap.page_allocator.free(shell_env);

        if (std.mem.indexOf(u8, shell_env, "zsh") != null) return .zsh;
        if (std.mem.indexOf(u8, shell_env, "bash") != null) return .bash;
        return .auto;
    }

    fn getConfigFile(shell: Shell) ![]const u8 {
        const home = try std.process.getEnvVarOwned(std.heap.page_allocator, "HOME");
        defer std.heap.page_allocator.free(home);

        return switch (shell) {
            .bash => std.fs.path.join(std.heap.page_allocator, &.{ home, ".bashrc" }),
            .zsh => std.fs.path.join(std.heap.page_allocator, &.{ home, ".zshrc" }),
            .auto => {
                // Try to detect from SHELL env
                const detected = detect();
                return detected.getConfigFile();
            },
        };
    }
};

fn installCompletion(shell: Shell) !void {
    const config_file = try shell.getConfigFile();
    defer std.heap.page_allocator.free(config_file);

    const marker = "# >>> tri autocomplete >>>";
    const marker_end = "# <<< tri autocomplete <<<";

    // Generate completion script
    var script_buffer = std.ArrayList(u8).initCapacity(std.heap.page_allocator, 1024);
    const writer = script_buffer.writer(std.heap.page_allocator);

    try writer.writeAll("\n");
    try writer.writeAll(marker);
    try writer.writeAll("\n");

    switch (shell) {
        .bash => try generateBashCompletion(std.heap.page_allocator, writer),
        .zsh => try generateZshCompletion(std.heap.page_allocator, writer),
        .auto => {
            const detected = Shell.detect();
            switch (detected) {
                .bash => try generateBashCompletion(std.heap.page_allocator, writer),
                .zsh => try generateZshCompletion(std.heap.page_allocator, writer),
                .auto => try generateBashCompletion(std.heap.page_allocator, writer),
            }
        },
    }

    try writer.writeAll(marker_end);
    try writer.writeAll("\n");

    const script = script_buffer.toOwnedSlice(std.heap.page_allocator);
    defer std.heap.page_allocator.free(script);

    // Check if already installed
    const file = std.fs.openFileAbsolute(config_file, .{}) catch |err| {
        if (err == error.FileNotFound) {
            // Create new file
            const new_file = try std.fs.createFileAbsolute(config_file, .{ .read = true });
            defer new_file.close();
            try new_file.writeAll(script);
            std.debug.print("{s}Installed tri autocomplete to {s}{s}\n", .{ GREEN, config_file, RESET });
            std.debug.print("{s}Run 'source {s}' to activate{s}\n", .{ YELLOW, config_file, RESET });
            return;
        }
        return err;
    };
    defer file.close();

    const content = file.readToEndAlloc(std.heap.page_allocator, 1024 * 1024) catch return error.ReadFailed;
    defer std.heap.page_allocator.free(content);

    if (std.mem.indexOf(u8, content, marker) != null) {
        std.debug.print("{s}tri autocomplete is already installed in {s}{s}\n", .{ YELLOW, config_file, RESET });
        return;
    }

    // Append to file
    try file.seekFromEnd(0);
    try file.writeAll(script);

    std.debug.print("{s}Installed tri autocomplete to {s}{s}\n", .{ GREEN, config_file, RESET });
    std.debug.print("{s}Run 'source {s}' to activate{s}\n", .{ YELLOW, config_file, RESET });
}

fn uninstallCompletion(shell: Shell) !void {
    const config_file = try shell.getConfigFile();
    defer std.heap.page_allocator.free(config_file);

    const marker = "# >>> tri autocomplete >>>";
    const marker_end = "# <<< tri autocomplete <<<";

    const file = std.fs.openFileAbsolute(config_file, .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("{s}No shell config file found: {s}{s}\n", .{ YELLOW, config_file, RESET });
            return;
        }
        return err;
    };
    defer file.close();

    const content = file.readToEndAlloc(std.heap.page_allocator, 1024 * 1024) catch return error.ReadFailed;
    defer std.heap.page_allocator.free(content);

    const start_idx = std.mem.indexOf(u8, content, marker) orelse {
        std.debug.print("{s}tri autocomplete is not installed in {s}{s}\n", .{ YELLOW, config_file, RESET });
        return;
    };

    const end_idx = std.mem.indexOf(u8, content[start_idx..], marker_end) orelse return error.MalformedConfig;
    const actual_end = start_idx + end_idx + marker_end.len;

    // Find newline before and after for clean removal
    var content_start = start_idx;
    while (content_start > 0 and content[content_start - 1] != '\n') : (content_start -= 1) {}

    var content_end = actual_end;
    while (content_end < content.len and content[content_end] != '\n') : (content_end += 1) {}
    if (content_end < content.len) content_end += 1;

    // Build new content
    var new_content = try std.ArrayList(u8).initCapacity(std.heap.page_allocator, content.len);
    try new_content.appendSlice(content[0..content_start]);
    try new_content.appendSlice(content[content_end..]);

    // Rewrite file
    try file.setEndPos(0);
    try file.pwriteAll(new_content.items, 0);

    std.debug.print("{s}Uninstalled tri autocomplete from {s}{s}\n", .{ GREEN, config_file, RESET });
    std.debug.print("{s}Run 'source {s}' to apply changes{s}\n", .{ YELLOW, config_file, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN COMMAND HANDLER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runAutocompleteCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri autocomplete [--print|--install|--uninstall]{s}\n", .{ GOLDEN, RESET });
        std.debug.print("\n", .{});
        std.debug.print("Options:\n", .{});
        std.debug.print("  {s}--print{s}     Output completion script to stdout\n", .{ CYAN, RESET });
        std.debug.print("  {s}--install{s}   Install to ~/.bashrc or ~/.zshrc\n", .{ CYAN, RESET });
        std.debug.print("  {s}--uninstall{s} Remove from shell config\n", .{ CYAN, RESET });
        std.debug.print("  {s}--bash{s}      Force bash completion (with --install/--uninstall)\n", .{ CYAN, RESET });
        std.debug.print("  {s}--zsh{s}       Force zsh completion (with --install/--uninstall)\n", .{ CYAN, RESET });
        std.debug.print("\n", .{});
        std.debug.print("Examples:\n", .{});
        std.debug.print("  tri autocomplete --print      > /tmp/tri-comp.sh && source /tmp/tri-comp.sh\n", .{});
        std.debug.print("  tri autocomplete --install    # Add to shell config\n", .{});
        std.debug.print("  tri autocomplete --uninstall  # Remove from shell config\n", .{});
        return;
    }

    var action: enum { print, install, uninstall } = .print;
    var shell: Shell = .auto;

    // Parse args
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--print")) {
            action = .print;
        } else if (std.mem.eql(u8, arg, "--install")) {
            action = .install;
        } else if (std.mem.eql(u8, arg, "--uninstall")) {
            action = .uninstall;
        } else if (std.mem.eql(u8, arg, "--bash")) {
            shell = .bash;
        } else if (std.mem.eql(u8, arg, "--zsh")) {
            shell = .zsh;
        } else if (std.mem.eql(u8, arg, "--help")) {
            try runAutocompleteCommand(allocator, &.{});
            return;
        }
    }

    switch (action) {
        .print => {
            const stdout_file = std.fs.File.stdout();
            var buffer: [8192]u8 = undefined;
            var stdout_buf = std.io.bufferedWriter(stdout_file, &buffer);
            const stdout = stdout_buf.writer();
            const detected = if (shell == .auto) Shell.detect() else shell;
            switch (detected) {
                .bash => try generateBashCompletion(allocator, stdout),
                .zsh => try generateZshCompletion(allocator, stdout),
                .auto => try generateBashCompletion(allocator, stdout),
            }
            try stdout_buf.flush();
        },
        .install => try installCompletion(shell),
        .uninstall => try uninstallCompletion(shell),
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "getCommands returns valid data" {
    const commands = getCommands();
    try std.testing.expect(commands.len > 0);
    for (commands) |cmd| {
        try std.testing.expect(cmd.name.len > 0);
        try std.testing.expect(cmd.description.len > 0);
    }
}

test "Config default aliases" {
    const allocator = std.testing.allocator;
    var aliases = try Config.getDefaultAliases(allocator);
    defer {
        var iter = aliases.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*) catch {};
            allocator.free(entry.value_ptr.*) catch {};
        }
        aliases.deinit();
    }

    try std.testing.expect(aliases.get("c") != null);
    try std.testing.expectEqualStrings("cell", aliases.get("c").?);
}
