// TRI CLI - Unified Trinity Command Line Interface
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL

const std = @import("std");

// Decomposed modules
const utils = @import("tri_utils.zig");
const tri_config = @import("tri_config.zig");
const commands = @import("tri_commands.zig");
const pipeline = @import("tri_pipeline.zig");
const demos = @import("tri_demos.zig");
const tri_context = @import("tri_context.zig");
const orchestrator = @import("hypothalamus.zig");
const tri_job = @import("tri_job.zig");
const tri_register = @import("tri_register.zig");
const sacred_fpga = @import("tri_sacred_fpga.zig");
const tri_train = @import("metabolism.zig");
const tri_zenodo = @import("tri_zenodo.zig");
const tri_cloud = @import("tri_cloud.zig");
const tri_farm = @import("tri_farm.zig");
const tri_dev = @import("tri_dev.zig");
const swe_arena = @import("swe_arena.zig");
const code_arena = @import("code_arena.zig");
const spec_template_match = @import("spec_template_match.zig");
const tri_loop = @import("heartbeat.zig");
const tri_experience = @import("tri_experience.zig");
// P2.9: Namespace-aware command parsing
const tri_namespace = @import("tri_namespace.zig");
const tri_mcp = @import("tri_mcp.zig");
const tri_list = @import("tri_cmd_list.zig");
const tri_swarm = @import("tri_swarm.zig");
const tri_research = @import("tri_research.zig");
const tri_experiment = @import("tri_experiment.zig");
const mu_agent = @import("mu_agent.zig");
const github_commands = @import("github_commands.zig");
const faculty_board = @import("cortex.zig");
// P2.10: Observability layer
const observability = @import("observability.zig");
const structured_log = @import("structured_log.zig");
const env_loader = @import("env_loader.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    // Use page_allocator to avoid leak-check spam from GGUF reader metadata strings
    const allocator = std.heap.page_allocator;

    // P2.10: Initialize structured logging
    try structured_log.initGlobalLogger(allocator, .info);
    defer structured_log.deinitGlobalLogger();

    // Auto-load .env into process environment (process env wins over .env)
    env_loader.loadDotEnv(allocator);

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var state = try utils.CLIState.init(allocator);
    defer state.deinit();

    // No arguments = interactive mode
    if (args.len < 2) {
        try utils.runInteractiveMode(&state);
        return;
    }

    // Parse global flags (before command)
    var arg_idx: usize = 1;
    // P0.3: Track if we're running in job context (spawned by job system)
    var is_internal_job_exec = false;
    while (arg_idx < args.len) : (arg_idx += 1) {
        const arg = args[arg_idx];

        // Stop at first non-flag argument (the command)
        if (arg[0] != '-') break;

        // Global flags
        if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            state.verbose = true;
        } else if (std.mem.eql(u8, arg, "--dry-run")) {
            state.dry_run = true;
            std.debug.print("{s}DRY RUN MODE: No actual changes will be made{s}\n", .{ "\x1b[38;2;255;215;0m", "\x1b[0m" });
        } else if (std.mem.eql(u8, arg, "--yes") or std.mem.eql(u8, arg, "-y")) {
            state.yes = true;
        } else if (std.mem.eql(u8, arg, "--json")) {
            // P0.2: Convenience flag for JSON output
            state.output_format = .json;
            tri_config.setJsonOutput(true);
        } else if (std.mem.eql(u8, arg, "--output")) {
            if (arg_idx + 1 < args.len) {
                const fmt = args[arg_idx + 1];
                if (std.mem.eql(u8, fmt, "json")) {
                    state.output_format = .json;
                    tri_config.setJsonOutput(true); // P0.2: Set global JSON mode
                } else if (std.mem.eql(u8, fmt, "yaml")) {
                    state.output_format = .yaml;
                } else {
                    state.output_format = .text;
                }
                arg_idx += 1; // Skip the format argument
            }
        } else if (std.mem.eql(u8, arg, "--_internal-job-exec")) {
            // P0.3: Internal flag - running in job context, don't spawn another job
            is_internal_job_exec = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            // Global help - show all commands
            utils.printHelp();
            return;
        } else if (arg[0] == '-') {
            // Unknown flag, might be command-specific - pass through
            break;
        }
    }

    // Check if we have a command after flags
    if (arg_idx >= args.len) {
        // No command after flags
        try utils.runInteractiveMode(&state);
        return;
    }

    // Special handling for "test" command — route subcommands
    if (arg_idx < args.len and std.mem.eql(u8, args[arg_idx], "test")) {
        const sub = if (arg_idx + 1 < args.len) args[arg_idx + 1] else "";
        // tri test / tri test spec / tri test report → runTestCommand
        if (sub.len == 0 or
            std.mem.eql(u8, sub, "spec") or
            std.mem.eql(u8, sub, "report"))
        {
            const test_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            try commands.runTestCommand(allocator, test_args);
            return;
        }
        // tri test e2e → E2E toxic test suite
        if (std.mem.eql(u8, sub, "e2e")) {
            const e2e_args = if (arg_idx + 2 < args.len) args[arg_idx + 2 ..] else &[_][]const u8{};
            const e2e_test = @import("e2e_toxic_test.zig");
            e2e_test.runE2ECommand(allocator, e2e_args);
            return;
        }
        // Handle REPL test flags
        if (std.mem.eql(u8, sub, "--repl") or
            std.mem.eql(u8, sub, "-r") or
            std.mem.eql(u8, sub, "--generate") or
            std.mem.eql(u8, sub, "-g") or
            std.mem.eql(u8, sub, "--coverage") or
            std.mem.eql(u8, sub, "--full") or
            std.mem.eql(u8, sub, "-f") or
            std.mem.eql(u8, sub, "--category") or
            std.mem.eql(u8, sub, "-c") or
            std.mem.eql(u8, sub, "--verbose") or
            std.mem.eql(u8, sub, "-v") or
            std.mem.eql(u8, sub, "--help") or
            std.mem.eql(u8, sub, "-h"))
        {
            const cmd_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            try commands.runReplTestCommand(allocator, cmd_args);
            return;
        }
    }

    // P0.3: Special handling for "job <subcommand>" commands
    if (arg_idx < args.len and std.mem.eql(u8, args[arg_idx], "job")) {
        const subcommand = if (arg_idx + 1 < args.len) args[arg_idx + 1] else "";
        const job_cmd: utils.Command = if (std.mem.eql(u8, subcommand, "start"))
            .job_start
        else if (std.mem.eql(u8, subcommand, "status"))
            .job_status
        else if (std.mem.eql(u8, subcommand, "logs"))
            .job_logs
        else if (std.mem.eql(u8, subcommand, "artifacts"))
            .job_artifacts
        else if (std.mem.eql(u8, subcommand, "cancel"))
            .job_cancel
        else if (std.mem.eql(u8, subcommand, "list"))
            .job_list
        else if (subcommand.len == 0)
            .job_start // "job" alone defaults to job_start
        else
            .job_start; // Default for unknown subcommand

        const cmd_args = if (arg_idx + 2 < args.len) args[arg_idx + 2 ..] else &[_][]const u8{};

        switch (job_cmd) {
            .job_start => try tri_job.runJobStart(allocator, cmd_args),
            .job_status => try tri_job.runJobStatus(allocator, cmd_args),
            .job_logs => try tri_job.runJobLogs(allocator, cmd_args),
            .job_artifacts => try tri_job.runJobArtifacts(allocator, cmd_args),
            .job_cancel => try tri_job.runJobCancel(allocator, cmd_args),
            .job_list => try tri_job.runJobList(allocator, cmd_args),
            else => unreachable,
        }
        return;
    }

    // GitHub Integration: route `tri issue/board/protocol` to github_commands
    if (arg_idx < args.len) {
        const first_arg = args[arg_idx];
        if (std.mem.eql(u8, first_arg, "issue") or std.mem.eql(u8, first_arg, "board") or
            std.mem.eql(u8, first_arg, "agent") or std.mem.eql(u8, first_arg, "protocol") or
            std.mem.eql(u8, first_arg, "pr") or std.mem.eql(u8, first_arg, "check") or
            std.mem.eql(u8, first_arg, "dispatch") or std.mem.eql(u8, first_arg, "graphql") or
            std.mem.eql(u8, first_arg, "github"))
        {
            // Intercept `tri agent run <N>` → flagship chimera
            if (std.mem.eql(u8, first_arg, "agent") and arg_idx + 1 < args.len and
                std.mem.eql(u8, args[arg_idx + 1], "run"))
            {
                const run_args = if (arg_idx + 2 < args.len) args[arg_idx + 2 ..] else &[_][]const u8{};
                logAgentCommand(args[arg_idx..]);
                const tri_agent_run = @import("tri_agent_run.zig");
                try tri_agent_run.runAgentRunCommand(allocator, run_args);
                return;
            }
            const gh_args = args[arg_idx..];
            logAgentCommand(gh_args);
            try github_commands.runGithubCommand(allocator, gh_args, state.dry_run);
            return;
        }
        // Git namespace: route `tri git <action> [args]` to runGitCommand
        if (std.mem.eql(u8, first_arg, "git")) {
            const git_sub = if (arg_idx + 1 < args.len) args[arg_idx + 1] else {
                commands.printGitHelp();
                return;
            };
            const git_args = if (arg_idx + 2 < args.len) args[arg_idx + 2 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            try commands.runGitCommand(allocator, git_sub, git_args);
            return;
        }
        // ═══════════════════════════════════════════════════════════════════
        // INTERNAL HANDLER REGISTRY (Honeycomb v8+v9)
        // ═══════════════════════════════════════════════════════════════════
        // Comptime map of CLI strings → demo functions (SimpleHandler)
        // + full handlers with allocator+args (FullHandler) for math/bio/cosmos/neuro/chem
        {
            const cell_dispatch = @import("tri_cell_dispatch.zig");
            if (cell_dispatch.executeInternalCommand(first_arg)) {
                logAgentCommand(args[arg_idx..]);
                return;
            }
            const extra_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            if (cell_dispatch.executeFullCommand(first_arg, allocator, extra_args)) {
                logAgentCommand(args[arg_idx..]);
                return;
            }
        }

        // ═══════════════════════════════════════════════════════════════════
        // CELL-FIRST DISPATCH (Honeycomb v7)
        // ═══════════════════════════════════════════════════════════════════
        // Cell dispatch runs BEFORE hardcoded if-chains. New cells auto-register
        // commands via contributes.tri_subcommands without touching main.zig.
        // Reserved commands (below) fall through to their hardcoded handlers.
        if (!isReservedCommand(first_arg)) {
            const cell_dispatch = @import("tri_cell_dispatch.zig");
            // Try two-word command first ("arena battle"), then single ("arena")
            const full_cmd = if (arg_idx + 1 < args.len)
                std.fmt.allocPrint(allocator, "{s} {s}", .{ first_arg, args[arg_idx + 1] }) catch null
            else
                null;
            const found = if (full_cmd) |fc|
                cell_dispatch.findCellCommand(allocator, fc)
            else
                null;
            const cell_cmd = found orelse cell_dispatch.findCellCommand(allocator, first_arg);
            if (full_cmd) |fc| allocator.free(fc);
            if (cell_cmd) |cc| {
                logAgentCommand(args[arg_idx..]);
                const extra_args = if (found != null and arg_idx + 2 < args.len)
                    args[arg_idx + 2 ..]
                else if (arg_idx + 1 < args.len)
                    args[arg_idx + 1 ..]
                else
                    &[_][]const u8{};
                try cell_dispatch.executeCellCommand(allocator, cc, extra_args);
                return;
            }
        }

        // Phoenix namespace: route `tri phoenix <subcommand>` to tri_phoenix
        if (std.mem.eql(u8, first_arg, "phoenix")) {
            const phoenix_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            const tri_phoenix = @import("tri_phoenix.zig");
            try tri_phoenix.runPhoenixCommand(allocator, phoenix_args);
            return;
        }
        // Deploy namespace: route `tri deploy <action>` to runDeployCommand
        if (std.mem.eql(u8, first_arg, "deploy")) {
            const deploy_sub = if (arg_idx + 1 < args.len) args[arg_idx + 1] else "status";
            const deploy_args = if (arg_idx + 2 < args.len) args[arg_idx + 2 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            try commands.runDeployCommand(allocator, deploy_sub, deploy_args);
            return;
        }
        // Spec namespace: route `tri spec create <name>` to spec_create, bare `tri spec` → specexec demo
        if (std.mem.eql(u8, first_arg, "spec")) {
            const spec_sub = if (arg_idx + 1 < args.len) args[arg_idx + 1] else "";
            if (std.mem.eql(u8, spec_sub, "create")) {
                const spec_args = if (arg_idx + 2 < args.len) args[arg_idx + 2 ..] else &[_][]const u8{};
                logAgentCommand(args[arg_idx..]);
                pipeline.runSpecCreateCommand(allocator, spec_args);
                return;
            }
            // bare `tri spec` → specexec demo (existing behavior)
            logAgentCommand(args[arg_idx..]);
            demos.runSpecExecDemo();
            return;
        }
        // Bench namespace: route `tri bench compare/record/history` to perf_benchmark
        if (std.mem.eql(u8, first_arg, "bench")) {
            const bench_sub = if (arg_idx + 1 < args.len) args[arg_idx + 1] else "";
            if (std.mem.eql(u8, bench_sub, "compare") or std.mem.eql(u8, bench_sub, "record") or
                std.mem.eql(u8, bench_sub, "history"))
            {
                const bench_args = args[arg_idx + 1 ..];
                logAgentCommand(args[arg_idx..]);
                const perf_benchmark = @import("perf_benchmark.zig");
                perf_benchmark.runBenchCommand(allocator, bench_args);
                return;
            }
            // bare `tri bench` → old math benchmark (existing behavior)
        }
        // Notify: route `tri notify [--chat <id>] [--pin] [--edit <msg_id>] "<msg>"` to sendNotification
        if (std.mem.eql(u8, first_arg, "notify")) {
            var chat_id_override: ?[]const u8 = null;
            var pin_after_send: bool = false;
            var edit_message_id: ?[]const u8 = null;
            var msg_idx = arg_idx + 1;

            // Parse optional flags
            while (msg_idx < args.len) {
                if (std.mem.eql(u8, args[msg_idx], "--chat")) {
                    msg_idx += 1;
                    if (msg_idx < args.len) {
                        chat_id_override = args[msg_idx];
                        msg_idx += 1;
                    } else {
                        std.debug.print("Usage: tri notify --chat <chat_id> \"<message>\"\n", .{});
                        return;
                    }
                } else if (std.mem.eql(u8, args[msg_idx], "--pin")) {
                    pin_after_send = true;
                    msg_idx += 1;
                } else if (std.mem.eql(u8, args[msg_idx], "--edit")) {
                    msg_idx += 1;
                    if (msg_idx < args.len) {
                        edit_message_id = args[msg_idx];
                        msg_idx += 1;
                    } else {
                        std.debug.print("Usage: tri notify --edit <message_id> \"<message>\"\n", .{});
                        return;
                    }
                } else {
                    break; // remaining arg is the message
                }
            }

            const msg = if (msg_idx < args.len) args[msg_idx] else {
                std.debug.print("Usage: tri notify [--chat <id>] [--pin] [--edit <msg_id>] \"<message>\"\n", .{});
                return;
            };
            logAgentCommand(args[arg_idx..]);
            try commands.runNotifyCommand(allocator, msg, chat_id_override, pin_after_send, edit_message_id);
            return;
        }
        // Chimera: route `tri chimera <name>` to fused multi-step commands
        if (std.mem.eql(u8, first_arg, "chimera")) {
            const chimera_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            const tri_chimera = @import("tri_chimera.zig");
            try tri_chimera.runChimeraCommand(allocator, chimera_args);
            return;
        }
        // Queen: autonomous daemon (monitor + alerts + Telegram)
        if (std.mem.eql(u8, first_arg, "queen")) {
            const queen_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            const queen = @import("queen.zig");
            try queen.runQueenCommand(allocator, queen_args);
            return;
        }
        // Ouroboros: self-evolving recursive improvement loop
        if (std.mem.eql(u8, first_arg, "ouroboros")) {
            const ouro_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            const tri_ouroboros = @import("autophagy.zig");
            try tri_ouroboros.runOuroborosCommand(allocator, ouro_args);
            return;
        }
        // Patent: route `tri patent <command>` to IP protection
        if (std.mem.eql(u8, first_arg, "patent")) {
            const patent_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            const tri_patent = @import("tri_patent.zig");
            try tri_patent.runPatentCommand(allocator, patent_args);
            return;
        }
        // DePIN: route `tri depin <command>` to DePIN node protocol
        if (std.mem.eql(u8, first_arg, "depin")) {
            const depin_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            const tri_depin = @import("tri_depin.zig");
            try tri_depin.runDepinCommand(allocator, depin_args);
            return;
        }
        // Self: route `tri self <test|health|benchmark>` to tri_self
        if (std.mem.eql(u8, first_arg, "self")) {
            const self_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            const tri_self = @import("tri_self.zig");
            try tri_self.runSelfCommand(allocator, self_args);
            return;
        }
        // Memory: route `tri memory <list|read|write|search|gc|stats>` to tri_memory
        if (std.mem.eql(u8, first_arg, "memory")) {
            const mem_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            const tri_memory = @import("hippocampus.zig");
            try tri_memory.runMemoryCommand(allocator, mem_args);
            return;
        }
        // Experience: route `tri experience <save|recall|mistakes>` to tri_experience
        if (std.mem.eql(u8, first_arg, "experience")) {
            const exp_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            try tri_experience.runExperienceCommand(allocator, exp_args);
            return;
        }
        // UI: route `tri ui [build|kill]` to Queen UI launcher
        if (std.mem.eql(u8, first_arg, "ui")) {
            const ui_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            try commands.runUiCommand(allocator, ui_args);
            return;
        }
        // Cell: route `tri cell <command>` to Honeycomb module management
        if (std.mem.eql(u8, first_arg, "cell")) {
            const cell_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            const tri_cell = @import("cytoplasm.zig");
            try tri_cell.runCellCommand(allocator, cell_args);
            return;
        }
        // Plugin: route `tri plugin <command>` to plugin CLI
        if (std.mem.eql(u8, first_arg, "plugin")) {
            const plugin_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            const tri_plugin = @import("tri_plugin.zig");
            try tri_plugin.runPluginCommand(allocator, plugin_args);
            return;
        }
        // Events: route `tri events [list|emit|status]` to event bus
        if (std.mem.eql(u8, first_arg, "events")) {
            const events_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            const tri_events = @import("tri_events.zig");
            try tri_events.runEventsCommand(allocator, events_args);
            return;
        }
        // Init: route `tri init [--cell <name>]` to scaffolding
        if (std.mem.eql(u8, first_arg, "init")) {
            const init_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            logAgentCommand(args[arg_idx..]);
            const tri_init = @import("tri_init.zig");
            try tri_init.runInitCommand(allocator, init_args);
            return;
        }
        // Version: `tri version`
        if (std.mem.eql(u8, first_arg, "version") or std.mem.eql(u8, first_arg, "--version") or std.mem.eql(u8, first_arg, "-v")) {
            printVersion(allocator);
            return;
        }
        // Autocomplete: `tri autocomplete --print|--install|--uninstall`
        if (std.mem.eql(u8, first_arg, "autocomplete")) {
            const autocomplete_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            const tri_autocomplete = @import("tri_autocomplete.zig");
            try tri_autocomplete.runAutocompleteCommand(allocator, autocomplete_args);
            return;
        }
    }

    // P2.9: Namespace-aware command dispatch
    // Check for `tri <namespace> <command>` syntax
    const remaining_args = if (arg_idx < args.len) args[arg_idx..] else &[_][]const u8{};
    const parsed = tri_namespace.parseCommand(remaining_args);

    switch (parsed) {
        .help => {
            utils.printHelp();
            return;
        },
        .namespaced => |ns_cmd| {
            // Namespace-based invocation: `tri dev bench`
            const ns = ns_cmd.namespace;
            const cmd_name = ns_cmd.command;

            // Handle empty command as namespace help
            if (cmd_name.len == 0) {
                try printNamespaceHelp(allocator, ns);
                return;
            }

            // Check for help within namespace
            if (std.mem.eql(u8, cmd_name, "help") or
                std.mem.eql(u8, cmd_name, "--help") or
                std.mem.eql(u8, cmd_name, "-h"))
            {
                try printNamespaceHelp(allocator, ns);
                return;
            }

            // Namespace-specific command dispatch
            const ns_cmd_args = if (arg_idx + 2 < args.len) args[arg_idx + 2 ..] else &[_][]const u8{};

            logAgentCommand(remaining_args);
            try dispatchNamespacedCommand(allocator, &state, ns, cmd_name, ns_cmd_args, is_internal_job_exec);
            return;
        },
        .flat => {
            // Fall through to existing flat dispatch (backward compatible)
        },
    }

    const cmd = utils.parseCommand(args[arg_idx]);
    const cmd_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};

    // Log agent command if AGENT_NAME is set (daemon tracing)
    logAgentCommand(args[arg_idx..]);

    // Handle --help after command (except for serve, which has its own help)
    if (cmd_args.len > 0 and (std.mem.eql(u8, cmd_args[0], "--help") or std.mem.eql(u8, cmd_args[0], "-h"))) {
        // serve command handles its own help via full-serve-v1 module
        if (cmd == .serve) {
            // Fall through to runServeCommand with --help flag
        } else {
            utils.printCommandHelp(cmd);
            return;
        }
    }

    switch (cmd) {
        .none => {
            // Treat as chat message
            utils.runChatCommand(&state, args[1..]);
        },
        .chat => utils.runChatCommand(&state, cmd_args),
        .code => {
            // tri code arena → code arena subcommands
            if (cmd_args.len > 0 and std.mem.eql(u8, cmd_args[0], "arena")) {
                try code_arena.runCodeArenaCommand(allocator, cmd_args[1..]);
            } else {
                utils.runCodeCommand(&state, cmd_args);
            }
        },
        .fix => utils.runSWECommand(&state, .BugFix, cmd_args),
        .explain => utils.runSWECommand(&state, .Explain, cmd_args),
        .test_cmd => try commands.runTestCommand(allocator, cmd_args),
        .doc => utils.runSWECommand(&state, .Document, cmd_args),
        .refactor => utils.runSWECommand(&state, .Refactor, cmd_args),
        .reason => utils.runSWECommand(&state, .Reason, cmd_args),
        .gen => try commands.runGenCommand(allocator, cmd_args),
        .convert => try commands.runConvertCommand(cmd_args),
        .serve => try commands.runServeCommand(allocator, cmd_args),
        .bench => if (is_internal_job_exec)
            try commands.runBenchCommandInternal(allocator)
        else
            try commands.runBenchCommandAsync(allocator, cmd_args),
        .evolve => try commands.runEvolveCommand(cmd_args),
        // Git commands
        .commit => try commands.runGitCommand(allocator, "commit", cmd_args),
        .diff => try commands.runGitCommand(allocator, "diff", cmd_args),
        .status => try commands.runGitCommand(allocator, "status", cmd_args),
        .log => try commands.runGitCommand(allocator, "log", cmd_args),
        // Golden Chain Pipeline
        .pipeline => pipeline.runPipelineCommand(allocator, cmd_args),
        .chain => pipeline.runChainCommand(allocator, cmd_args),
        .decompose => pipeline.runDecomposeCommand(allocator, cmd_args),
        .plan => pipeline.runPlanCommand(allocator, cmd_args),
        .multi_cluster => try commands.runMultiClusterCommand(allocator, cmd_args),
        .verify => pipeline.runVerifyCommand(allocator),
        .verdict => pipeline.runVerdictCommandEx(allocator, cmd_args),
        // Test REPL (Cycle 101)
        .test_repl => try commands.runReplTestCommand(allocator, cmd_args),
        // Spec & Loop (v8.27)
        .spec_create => pipeline.runSpecCreateCommand(allocator, cmd_args),
        .loop_decide => pipeline.runLoopDecideCommand(allocator, cmd_args),
        // Distributed Inference
        .distributed => try commands.runDistributedCommand(allocator, cmd_args),
        // Intelligence System
        .intelligence => tri_context.runIntelligenceCommand(allocator, &state, cmd_args) catch |err| {
            std.debug.print("Intelligence error: {}\n", .{err});
        },
        // Dev Utilities
        .doctor => try commands.runDoctorCommand(allocator, cmd_args),
        .regen => {
            const regen_mod = @import("regen.zig");
            try regen_mod.runRegenCLI(allocator, cmd_args);
        },
        .clean => try commands.runCleanCommand(allocator),
        .fmt_cmd => try commands.runFmtCommand(allocator),
        .stats_cmd => try commands.runStatsCommand(allocator),
        .igla => try commands.runIglaCommand(allocator),
        // Cycle 98: Sacred Intelligence
        .identity => {
            std.debug.print(
                \\🔱 TRINITY IDENTITY
                \\  φ² + 1/φ² = 3 (Golden Ratio Trinity)
                \\  Ternary: {{-1, 0, +1}} — 1.58 bits/trit
                \\  Repository: github.com/gHashTag/trinity
                \\  Version: tri version
                \\
            , .{});
        },
        .swarm => try tri_swarm.runSwarmCommand(allocator, cmd_args),
        .research => try tri_research.runResearchCommand(allocator, cmd_args),
        .mu => {
            var mu = mu_agent.MuAgent.init(allocator, ".trinity/mu/patterns.jsonl");
            defer mu.deinit();
            try mu.load();

            const subcmd = if (cmd_args.len > 0) cmd_args[0] else "status";
            if (std.mem.eql(u8, subcmd, "status")) {
                const report = mu.stats();
                std.debug.print(
                    \\🧠 AGENT TRI STATUS REPORT
                    \\═══════════════════════════════════════
                    \\  Total patterns:  {d}
                    \\  Unresolved:      {d}
                    \\  Auto-fixable:    {d}
                    \\
                    \\  By category:
                    \\    ast_fail:      {d}
                    \\    gen_fail:      {d}
                    \\    format_fail:   {d}
                    \\    type_mismatch: {d}
                    \\    import_fail:   {d}
                    \\    unknown:       {d}
                    \\
                , .{
                    report.total_patterns, report.unresolved,     report.auto_fixable,
                    report.by_category[0], report.by_category[1], report.by_category[2],
                    report.by_category[3], report.by_category[4], report.by_category[5],
                });
                for (mu.patterns.items) |p| {
                    std.debug.print("  [{s}] {s} — count:{d} {s}\n", .{
                        p.category.toString(),                    p.spec_file, p.count,
                        if (p.auto_fixable) "auto" else "manual",
                    });
                }
            } else if (std.mem.eql(u8, subcmd, "patterns")) {
                const report = mu.stats();
                std.debug.print("🧠 AGENT TRI: {d} patterns ({d} unresolved, {d} auto-fixable)\n", .{
                    report.total_patterns, report.unresolved, report.auto_fixable,
                });
                for (mu.patterns.items) |p| {
                    std.debug.print("  [{s}] {s} — count:{d} {s}\n", .{
                        p.category.toString(),                  p.spec_file, p.count,
                        if (p.resolved) "RESOLVED" else "OPEN",
                    });
                }
            } else if (std.mem.eql(u8, subcmd, "errors")) {
                const mu_proto = @import("mu_error_protocol.zig");
                const sub_args = if (cmd_args.len > 1) cmd_args[1..] else &[_][]const u8{};
                try mu_proto.runMuErrorsCommand(allocator, sub_args);
            } else if (std.mem.eql(u8, subcmd, "stats")) {
                const mu_proto = @import("mu_error_protocol.zig");
                try mu_proto.runMuStatsCommand(allocator);
            } else if (std.mem.eql(u8, subcmd, "verify")) {
                const mu_verify = @import("mu_verify_failures.zig");
                try mu_verify.runMuVerifyCommand(allocator);
            } else if (std.mem.eql(u8, subcmd, "report")) {
                const mu_proto = @import("mu_error_protocol.zig");
                try mu_proto.runMuReportCommand(allocator);
            } else if (std.mem.eql(u8, subcmd, "learn")) {
                std.debug.print("\x1b[33mtri mu learn: deprecated — use hippocampus write directly\x1b[0m\n", .{});
            } else if (std.mem.eql(u8, subcmd, "fix")) {
                std.debug.print("\x1b[33mtri mu fix: deprecated — use hippocampus read/write directly\x1b[0m\n", .{});
            } else if (std.mem.eql(u8, subcmd, "start")) {
                const result = std.process.Child.run(.{
                    .allocator = allocator,
                    .argv = &.{ "launchctl", "load", "-w", "deploy/com.trinity.mu-agent.plist" },
                }) catch |err| {
                    std.debug.print("[mu] Failed to start: {}\n", .{err});
                    return;
                };
                allocator.free(result.stdout);
                allocator.free(result.stderr);
                std.debug.print("Agent TRI started (launchctl load)\n", .{});
            } else if (std.mem.eql(u8, subcmd, "stop")) {
                const result = std.process.Child.run(.{
                    .allocator = allocator,
                    .argv = &.{ "launchctl", "unload", "deploy/com.trinity.mu-agent.plist" },
                }) catch |err| {
                    std.debug.print("[mu] Failed to stop: {}\n", .{err});
                    return;
                };
                allocator.free(result.stdout);
                allocator.free(result.stderr);
                std.debug.print("Agent TRI stopped (launchctl unload)\n", .{});
            } else {
                std.debug.print(
                    \\🧠 AGENT TRI — Memory Unit
                    \\Usage: tri mu <command>
                    \\  status    Show patterns + stats
                    \\  patterns  List all known patterns
                    \\  errors    Query logged errors (--category, --limit)
                    \\  stats     Error statistics by category
                    \\  verify    Run MU against known failures (MU-5)
                    \\  report    Aggregate report — category × severity matrix (v2)
                    \\  learn     Scan error logs → build auto-fix pattern DB
                    \\  fix       Apply auto-fix rules: tri mu fix <file> | --all
                    \\  start     Start MU daemon (launchctl)
                    \\  stop      Stop MU daemon (launchctl)
                    \\  help      Show this help
                    \\
                , .{});
            }
        },
        .govern => {
            std.debug.print(
                \\⚖️  TRINITY GOVERNANCE
                \\  Usage: tri govern <subcommand>
                \\    status   — Show governance rules and compliance
                \\    audit    — Audit recent actions against policy
                \\  Note: Governance enforced via pre-commit hooks + CI
                \\
            , .{});
        },
        .dashboard => {
            runDashboard(allocator);
        },
        .omega => {
            std.debug.print(
                \\Ω OMEGA PHASE
                \\  Usage: tri omega <subcommand>
                \\  See also: tri omega-phase, tri omega-evolve
                \\
            , .{});
        },
        .math_agent => {
            std.debug.print(
                \\🧮 MATH AGENT
                \\  Usage: tri math <subcommand>
                \\    verify   — Verify VSA math proofs
                \\    sacred   — Sacred constants (φ, π, e)
                \\    bench    — Run math benchmarks
                \\  See also: tri sacred-const, tri vsa-verify
                \\
            , .{});
        },
        // Codebase Context (Cycle 92)
        .analyze => tri_context.runAnalyzeCommand(&state),
        .search_cmd => tri_context.runSearchCommand(&state, cmd_args),
        .context_info => tri_context.runContextInfoCommand(&state),
        // Temporal Engine v1.2-v1.3 (Orders #030-031)
        .time => commands.runTimeCommand(allocator, cmd_args),
        .install => commands.runInstallCommand(allocator),
        .build_cmd => commands.runBuildCommand(allocator),
        .deck_generate => commands.runDeckCommand(allocator),
        .fpga_demo => commands.runFpgaDemoCommand(allocator, cmd_args),
        .fpga => try tri_register.runFpgaCommand(allocator, cmd_args),
        .train => try tri_train.runTrainCommand(allocator, cmd_args),
        .infer => {
            const tri_infer = @import("tri_infer.zig");
            try tri_infer.runInferCommand(allocator, cmd_args);
        },
        .zenodo => try tri_zenodo.runZenodoCommand(allocator, cmd_args),
        .cloud => try tri_cloud.runCloudCommand(allocator, cmd_args),
        .farm => try tri_farm.runFarmCommand(allocator, cmd_args),
        .loop => try tri_loop.runLoopCommand(allocator, cmd_args),
        .experience => try tri_experience.runExperienceCommand(allocator, cmd_args),
        .sacred_const => try sacred_fpga.runSacredConstCommand(allocator, cmd_args),
        .sacred_full_cycle => commands.runSacredFullCycleCommand(allocator),
        // Quantum Trinity v1.4 (Order #032)
        .quantum => commands.runQuantumCommand(allocator, cmd_args),
        .release_cosmic => commands.runReleaseCosmicCommand(allocator),
        // Omega Phase v2.0 (Order #033)
        .omega_cmd => commands.runOmegaPhaseCommand(allocator, cmd_args),
        .all_cmd => commands.runAllCommand(allocator, cmd_args),
        .holo_cmd => commands.runHoloCommand(allocator, cmd_args),
        .release_absolute => commands.runReleaseAbsoluteCommand(allocator),
        .omega_evolve => commands.runOmegaEvolveCommand(allocator),
        // TRINITY OS v1.0 (Order #034)
        .launch => commands.runLaunchCommand(allocator, cmd_args),
        // NEEDLE - Structural Editor Core
        // P0.3: Job Runtime (Async Long-Running Commands) - handled before general switch
        .job_start => try tri_job.runJobStart(allocator, cmd_args),
        .job_status => try tri_job.runJobStatus(allocator, cmd_args),
        .job_logs => try tri_job.runJobLogs(allocator, cmd_args),
        .job_artifacts => try tri_job.runJobArtifacts(allocator, cmd_args),
        .job_cancel => try tri_job.runJobCancel(allocator, cmd_args),
        .job_list => try tri_job.runJobList(allocator, cmd_args),
        .needle => try commands.runNeedleCommand(allocator, cmd_args),
        .needle_search => try commands.runNeedleSearchCommand(allocator, cmd_args),
        .needle_check => try commands.runNeedleCheckCommand(allocator, cmd_args),
        .deps => utils.printInfo(),
        .info => utils.printInfo(),
        .version => utils.printVersion(),
        .help => utils.printHelp(),
        // P1.6: CLI Tools
        .commands => try tri_register.runCommand(allocator, "commands", cmd_args),
        .mcp => try tri_register.runCommand(allocator, "mcp", cmd_args),
        // Spec Linter (Issue #68)
        .lint => try commands.runLintCommand(allocator, cmd_args),
        // Spec Enricher (Issue #69)
        .enrich => {
            const spec_enricher = @import("tri_spec_enricher.zig");
            try spec_enricher.runEnrichCommand(allocator, cmd_args);
        },
        // Spec ↔ Code Sync Checker (Issue #71)
        .sync_check => {
            const sc = @import("sync_checker.zig");
            const exit_code = try sc.runSyncCheckCommand(allocator, cmd_args);
            if (exit_code != 0) std.process.exit(exit_code);
        },
        // GitHub Integration (Protocol v2)
        .github => try github_commands.runGithubCommand(allocator, cmd_args, false),
        // Faculty Board (A2A Dashboard)
        .faculty => try faculty_board.runFacultyCommand(allocator, cmd_args),
        .experiment => try tri_experiment.runExperimentCommand(allocator, cmd_args),
        // Observatory v5.2
        .trace => {
            const tracer_mod = @import("tracer.zig");
            tracer_mod.runTraceCommand(allocator, cmd_args);
        },
        .eval => {
            const eval_mod = @import("eval_harness.zig");
            eval_mod.runEvalCommand(allocator, cmd_args);
        },
        .metrics => {
            const metrics_mod = @import("metrics_aggregator.zig");
            metrics_mod.runMetricsCommand(allocator, cmd_args);
        },
        .context_load => {
            const ctx_loader = @import("context_loader.zig");
            ctx_loader.runContextCommand(allocator, cmd_args);
        },
    }
}

// =============================================================================
// RESERVED COMMANDS — these have hardcoded handlers with complex parsing,
// cell dispatch must NOT override them. Everything else is cell-first.
// =============================================================================

fn isReservedCommand(cmd: []const u8) bool {
    // Commands with complex multi-word parsing or special flag handling
    const reserved = std.StaticStringMap(void).initComptime(.{
        // Already handled before cell dispatch (test, job, github, git)
        .{ "test", {} },
        .{ "job", {} },
        .{ "issue", {} },
        .{ "board", {} },
        .{ "agent", {} },
        .{ "protocol", {} },
        .{ "pr", {} },
        .{ "check", {} },
        .{ "dispatch", {} },
        .{ "graphql", {} },
        .{ "github", {} },
        .{ "git", {} },
        // Meta commands about the cell/plugin system itself
        .{ "cell", {} },
        .{ "plugin", {} },
        .{ "events", {} },
        .{ "init", {} },
        // Core infrastructure with special parsing
        .{ "farm", {} },
        .{ "train", {} },
        .{ "cloud", {} },
        .{ "deploy", {} },
        .{ "notify", {} },
        .{ "spec", {} },
        .{ "bench", {} },
        // System commands
        .{ "version", {} },
        .{ "--version", {} },
        .{ "-v", {} },
        .{ "--help", {} },
        .{ "-h", {} },
        .{ "help", {} },
    });
    return reserved.has(cmd);
}

// =============================================================================
// AGENT COMMAND LOGGING — env AGENT_NAME → .trinity/agent_commands.log
// =============================================================================

const AGENT_CMD_LOG = ".trinity/agent_commands.log";
const AGENT_CMD_MAX_LINES = 1000;
const AGENT_CMD_KEEP_LINES = 500;

/// Dashboard: one-screen overview from live snapshot data
fn runDashboard(allocator: std.mem.Allocator) void {
    const snapshot = faculty_board.collectSnapshot(allocator) catch {
        std.debug.print("\x1b[31mFailed to collect snapshot\x1b[0m\n", .{});
        return;
    };

    const rate = snapshot.compile_rate;
    const rate_icon: []const u8 = if (rate >= 80) "💎" else if (rate >= 50) "🟡" else "💀";
    const build_icon: []const u8 = if (snapshot.build_ok) "🟢" else "🔴";
    const active = snapshot.activeFaculty();

    std.debug.print("\n\x1b[36m╔═══════════════════════════════════════╗\x1b[0m\n", .{});
    std.debug.print("\x1b[36m║\x1b[0m  📊 \x1b[1mTRINITY DASHBOARD\x1b[0m               \x1b[36m║\x1b[0m\n", .{});
    std.debug.print("\x1b[36m╠═══════════════════════════════════════╣\x1b[0m\n", .{});

    std.debug.print("\x1b[36m║\x1b[0m  Build:    {s} {d}/9 binaries\n", .{ build_icon, snapshot.binaries });
    std.debug.print("\x1b[36m║\x1b[0m  Compile:  {s} {d}/{d} = {d}%\n", .{ rate_icon, snapshot.compile_pass, snapshot.compile_total, rate });
    std.debug.print("\x1b[36m║\x1b[0m  Faculty:  {d}/6 active\n", .{active});
    std.debug.print("\x1b[36m║\x1b[0m  Dirty:    {d} files\n", .{snapshot.dirty_files});
    std.debug.print("\x1b[36m║\x1b[0m  Issues:   {d} open\n", .{snapshot.open_issues});
    std.debug.print("\x1b[36m║\x1b[0m  Branch:   {s}\n", .{snapshot.git_branch});

    // V-number with zone color
    const zone_color = snapshot.v_zone.color();
    std.debug.print("\x1b[36m║\x1b[0m  V:        {s}{d:.3} {s}\x1b[0m\n", .{ zone_color, snapshot.v_number, snapshot.v_zone.label() });

    // Agent roster
    std.debug.print("\x1b[36m╠═══════════════════════════════════════╣\x1b[0m\n", .{});
    for (snapshot.agents) |a| {
        const status_color = a.status.color();
        std.debug.print("\x1b[36m║\x1b[0m  {s} {s}: {s}{s}\x1b[0m\n", .{ a.agent.emoji(), a.agent.name(), status_color, a.status.label() });
    }

    std.debug.print("\x1b[36m╚═══════════════════════════════════════╝\x1b[0m\n", .{});
    std.debug.print("\n  \x1b[90mtri faculty\x1b[0m — full agent board\n  \x1b[90mtri stats\x1b[0m   — codebase metrics\n  \x1b[90mtri cloud\x1b[0m   — training farm\n\n", .{});
}

/// If AGENT_NAME env var is set, append "timestamp agent_name tri args..." to log.
fn logAgentCommand(cmd_args: []const []const u8) void {
    const agent_name = std.posix.getenv("AGENT_NAME") orelse return;
    if (agent_name.len == 0) return;

    // Build log line: "TIMESTAMP EMOJI tri arg1 arg2..."
    var line_buf: [512]u8 = undefined;
    var stream = std.io.fixedBufferStream(&line_buf);
    const w = stream.writer();

    const ts = std.time.timestamp();
    // HH:MM from unix timestamp (rough — offset not critical for log)
    const day_secs: u64 = @intCast(@mod(ts, 86400));
    const hh = day_secs / 3600;
    const mm = (day_secs % 3600) / 60;

    const emoji: []const u8 = if (std.mem.eql(u8, agent_name, "mu"))
        "\xf0\x9f\xa7\xa0"
    else if (std.mem.eql(u8, agent_name, "ralph") or std.mem.eql(u8, agent_name, "phoenix"))
        "\xf0\x9f\xa4\x96"
    else if (std.mem.eql(u8, agent_name, "oracle"))
        "\xf0\x9f\x94\xae"
    else if (std.mem.eql(u8, agent_name, "linter"))
        "\xf0\x9f\x94\x8d"
    else
        "\xf0\x9f\x90\x9d"; // bee for others

    w.print("{d:0>2}:{d:0>2} {s} tri", .{ hh, mm, emoji }) catch return;
    for (cmd_args) |arg| {
        w.print(" {s}", .{arg}) catch break;
    }
    w.print("\n", .{}) catch return;

    const line = stream.getWritten();

    // Append to log file
    const file = std.fs.cwd().openFile(AGENT_CMD_LOG, .{ .mode = .write_only }) catch blk: {
        // Create .trinity/ dir if needed, then create file
        std.fs.cwd().makePath(".trinity") catch return;
        break :blk std.fs.cwd().createFile(AGENT_CMD_LOG, .{}) catch return;
    };
    defer file.close();
    file.seekFromEnd(0) catch return;
    file.writeAll(line) catch |err| {
        std.log.debug("main: write history line failed: {}", .{err});
    };

    // Fire-and-forget Telegram notification
    sendAgentTelegram(line);

    // Rotate if too large (check size, not line count — cheaper)
    const stat = file.stat() catch return;
    if (stat.size > AGENT_CMD_MAX_LINES * 80) { // ~80 bytes per line estimate
        rotateAgentLog();
    }
}

/// Send agent command log line to Telegram. Fire-and-forget — never crash.
fn sendAgentTelegram(line: []const u8) void {
    const bot_token = std.posix.getenv("TELEGRAM_BOT_TOKEN") orelse return;
    const chat_id = std.posix.getenv("TELEGRAM_CHAT_ID") orelse return;

    // Trim trailing newline for cleaner message
    const msg = std.mem.trimRight(u8, line, "\n\r ");
    if (msg.len == 0) return;

    // Build URL
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/sendMessage", .{bot_token}) catch return;

    // Build JSON body with escaping
    var body_buf: [2048]u8 = undefined;
    var i: usize = 0;

    const prefix = "{\"chat_id\":\"";
    @memcpy(body_buf[i..][0..prefix.len], prefix);
    i += prefix.len;
    @memcpy(body_buf[i..][0..chat_id.len], chat_id);
    i += chat_id.len;

    const mid = "\",\"text\":\"";
    @memcpy(body_buf[i..][0..mid.len], mid);
    i += mid.len;

    // JSON-escape message
    for (msg) |c| {
        if (i + 2 >= body_buf.len - 30) break;
        switch (c) {
            '"' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = '"';
                i += 2;
            },
            '\\' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = '\\';
                i += 2;
            },
            '\n' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = 'n';
                i += 2;
            },
            else => {
                body_buf[i] = c;
                i += 1;
            },
        }
    }

    const suffix = "\"}";
    if (i + suffix.len <= body_buf.len) {
        @memcpy(body_buf[i..][0..suffix.len], suffix);
        i += suffix.len;
    }

    const body = body_buf[0..i];

    // Fire-and-forget HTTP POST
    var client = std.http.Client{ .allocator = std.heap.page_allocator };
    defer client.deinit();

    _ = client.fetch(.{
        .location = .{ .url = url },
        .method = .POST,
        .payload = body,
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
    }) catch |err| {
        std.log.debug("main: telegram notification failed: {}", .{err});
    };
}

/// Keep last AGENT_CMD_KEEP_LINES lines when log exceeds max.
fn rotateAgentLog() void {
    const content = std.fs.cwd().readFileAlloc(std.heap.page_allocator, AGENT_CMD_LOG, 256 * 1024) catch return;
    defer std.heap.page_allocator.free(content);

    // Count lines from the end, find offset to keep last N
    var count: usize = 0;
    var i: usize = content.len;
    while (i > 0) : (i -= 1) {
        if (content[i - 1] == '\n') {
            count += 1;
            if (count >= AGENT_CMD_KEEP_LINES) break;
        }
    }

    if (count < AGENT_CMD_KEEP_LINES) return; // not enough lines to rotate

    const trimmed = content[i..];
    const file = std.fs.cwd().createFile(AGENT_CMD_LOG, .{}) catch return;
    defer file.close();
    file.writeAll(trimmed) catch |err| {
        std.log.debug("tri/main: failed to write agent command log: {}", .{err});
    };
}

// =============================================================================
// P2.9: Namespace-Aware Command Dispatch
// =============================================================================

/// Print version info — `tri version` (#369)
fn printVersion(allocator: std.mem.Allocator) void {
    const builtin = @import("builtin");
    const zig_ver = std.fmt.comptimePrint("{d}.{d}.{d}", .{
        builtin.zig_version.major,
        builtin.zig_version.minor,
        builtin.zig_version.patch,
    });

    // Get git hash at runtime
    var git_hash: []const u8 = "unknown";
    const git_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "rev-parse", "--short", "HEAD" },
        .max_output_bytes = 64,
    }) catch null;
    defer if (git_result) |r| {
        allocator.free(r.stdout);
        allocator.free(r.stderr);
    };
    if (git_result) |r| {
        if (r.stdout.len > 0) {
            // Strip trailing newline
            git_hash = if (r.stdout[r.stdout.len - 1] == '\n')
                r.stdout[0 .. r.stdout.len - 1]
            else
                r.stdout;
        }
    }

    std.debug.print(
        \\
        \\  Trinity v5.1.0 ({s})
        \\  Zig: {s}
        \\  Binaries: 6
        \\  Identity: phi^2 + 1/phi^2 = 3
        \\
        \\
    , .{ git_hash, zig_ver });
}

/// Print help for a specific namespace
fn printNamespaceHelp(allocator: std.mem.Allocator, ns: tri_namespace.Namespace) !void {
    const ns_str = ns.toString();
    const desc = tri_namespace.namespaceDescription(ns);

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ "\x1b[38;2;255;215;0m", "\x1b[0m" });
    std.debug.print("{s}TRI {s} - {s}{s}\n", .{ "\x1b[38;2;0;229;153m", ns_str, desc, "\x1b[0m" });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ "\x1b[38;2;255;215;0m", "\x1b[0m" });

    std.debug.print("{s}Usage:{s} tri {s} <command>\n\n", .{ "\x1b[38;2;0;255;255m", "\x1b[0m", ns_str });

    std.debug.print("{s}Available commands:{s}\n", .{ "\x1b[38;2;0;255;255m", "\x1b[0m" });

    // Show example commands for this namespace
    const examples = try tri_namespace.namespaceExamples(allocator, ns);
    defer {
        for (examples) |ex| allocator.free(ex);
        allocator.free(examples);
    }

    for (examples) |ex| {
        std.debug.print("  {s}{s}{s}\n", .{ "\x1b[38;2;0;229;153m", ex, "\x1b[0m" });
    }

    std.debug.print("\n{s}Note:{s} Many commands work without the namespace prefix too.\n", .{ "\x1b[38;2;0;255;255m", "\x1b[0m" });
    std.debug.print("  Example: {s}tri bench{s} is equivalent to {s}tri dev bench{s}\n\n", .{ "\x1b[38;2;0;229;153m", "\x1b[0m", "\x1b[38;2;0;229;153m", "\x1b[0m" });
}

// =============================================================================
// P2.10: Observability Layer
// =============================================================================

/// Execute command with full observability tracking
fn executeWithObservability(
    allocator: std.mem.Allocator,
    command: []const u8,
    args: []const []const u8,
    comptime handlerFn: anytype,
    handlerArgs: anytype,
) !observability.ExitCode {
    // Create operation context
    var ctx = try observability.OperationContext.init(allocator, command, args);
    defer ctx.deinit();

    // Log command start
    if (structured_log.getGlobalLogger()) |logger| {
        try logger.withContext(.info, "Command started", .{
            .command = command,
            .args_len = args.len,
            .request_id = ctx.request_id.str(),
        });
    }

    // Execute command
    const result = handlerFn(handlerArgs);

    // Complete context
    const exit_code = if (result) |_| observability.ExitCode.success else |err| exitCodeFromError(err);
    try ctx.complete(exit_code);

    // Log result
    if (structured_log.getGlobalLogger()) |logger| {
        try logger.withContext(.info, "Command completed", .{
            .command = command,
            .duration_ms = ctx.duration.elapsedMs(),
            .exit_code = exit_code.toInt(),
            .request_id = ctx.request_id.str(),
        });
    }

    // Print summary for long-running commands
    if (ctx.duration.elapsedMs() > 1000) {
        std.debug.print("\n{s}Completed in {d:.1}s (request_id: {s}){s}\n", .{
            "\x1b[38;2;156;156;160m",
            ctx.duration.elapsedSeconds(),
            ctx.request_id.str(),
            "\x1b[0m",
        });
    }

    return exit_code;
}

/// Convert Zig error to ExitCode
fn exitCodeFromError(err: anyerror) observability.ExitCode {
    return switch (err) {
        error.FileNotFound => .no_input,
        error.AccessDenied => .no_perm,
        error.OutOfMemory => .os_err,
        error.InvalidArgument => .usage,
        error.NotOpen => .io_error,
        error.PipeFail => .io_error,
        else => .err, // ExitCode.err = 1
    };
}

/// Dispatch a namespace-based command
fn dispatchNamespacedCommand(
    allocator: std.mem.Allocator,
    state: *utils.CLIState,
    ns: tri_namespace.Namespace,
    cmd_name: []const u8,
    cmd_args: []const []const u8,
    is_internal_job_exec: bool,
) !void {
    // Map namespace+command to the appropriate handler
    // This maintains backward compatibility while enabling namespace syntax

    // For now, delegate to the existing flat command parsing
    // The namespace-aware routing will be expanded as commands are migrated

    // Convert namespace+command back to flat command for dispatch
    // This allows gradual migration - new commands can be namespace-only

    // DEV namespace commands
    if (ns == .dev) {
        // SWE Agent Dev Farm commands: status, spawn, kill, recycle, fill, metrics, leaderboard, evolve
        if (std.mem.eql(u8, cmd_name, "status") or std.mem.eql(u8, cmd_name, "spawn") or
            std.mem.eql(u8, cmd_name, "kill") or std.mem.eql(u8, cmd_name, "recycle") or
            std.mem.eql(u8, cmd_name, "fill") or std.mem.eql(u8, cmd_name, "metrics") or
            std.mem.eql(u8, cmd_name, "leaderboard") or std.mem.eql(u8, cmd_name, "evolve") or
            std.mem.eql(u8, cmd_name, "scan") or std.mem.eql(u8, cmd_name, "pick") or
            std.mem.eql(u8, cmd_name, "loop"))
        {
            var dev_args = try std.ArrayList([]const u8).initCapacity(allocator, cmd_args.len + 1);
            defer dev_args.deinit(allocator);
            try dev_args.append(allocator, cmd_name);
            try dev_args.appendSlice(allocator, cmd_args);
            try tri_dev.runDevCommand(allocator, dev_args.items);
            return;
        }
        // Arena commands: tri dev arena list|run|compare
        if (std.mem.eql(u8, cmd_name, "arena")) {
            try swe_arena.runArenaCommand(allocator, cmd_args);
            return;
        }
        // Code Arena: tri dev code-arena battle|leaderboard|tasks|history
        if (std.mem.eql(u8, cmd_name, "code-arena")) {
            try code_arena.runCodeArenaCommand(allocator, cmd_args);
            return;
        }
        // LLM Battle Arena: tri battle serve|battle|leaderboard|bench|tasks
        if (std.mem.eql(u8, cmd_name, "battle")) {
            const tri_battle = @import("tri_battle.zig");
            try tri_battle.runBattleCommand(allocator, cmd_args);
            return;
        }
        // Spec template matching: tri spec-match "<issue text>"
        if (std.mem.eql(u8, cmd_name, "spec-match") or std.mem.eql(u8, cmd_name, "spec_match")) {
            spec_template_match.runSpecMatchCommand(allocator, cmd_args);
            return;
        }
        if (std.mem.eql(u8, cmd_name, "bench")) {
            const perf_benchmark = @import("perf_benchmark.zig");
            perf_benchmark.runBenchCommand(allocator, cmd_args);
            return;
        }
        if (std.mem.eql(u8, cmd_name, "test") or
            std.mem.eql(u8, cmd_name, "build") or std.mem.eql(u8, cmd_name, "fmt") or
            std.mem.eql(u8, cmd_name, "gen"))
        {
            // Dispatch to existing command handlers
            const cmd = utils.parseCommand(cmd_name);
            return dispatchCommand(allocator, state, cmd, cmd_args, is_internal_job_exec);
        }
    }

    // MCP namespace commands
    if (ns == .mcp) {
        if (std.mem.eql(u8, cmd_name, "export")) {
            // Build args: "export" + cmd_args
            var all_args = try std.ArrayList([]const u8).initCapacity(allocator, cmd_args.len + 1);
            defer all_args.deinit(allocator);
            try all_args.append(allocator, "export");
            try all_args.appendSlice(allocator, cmd_args);
            try tri_mcp.runMcpCommand(allocator, all_args.items);
            return;
        }
        if (std.mem.eql(u8, cmd_name, "doctor")) {
            const doctor_args = &[_][]const u8{"doctor"};
            try tri_mcp.runMcpCommand(allocator, doctor_args);
            return;
        }
        if (std.mem.eql(u8, cmd_name, "tools")) {
            const tools_args = &[_][]const u8{"tools"};
            try tri_mcp.runMcpCommand(allocator, tools_args);
            return;
        }
        // Pass through to mcp command handler
        try tri_mcp.runMcpCommand(allocator, cmd_args);
        return;
    }

    // AGENT namespace: route issue/board/protocol to github_commands
    if (ns == .agent) {
        if (std.mem.eql(u8, cmd_name, "issue") or std.mem.eql(u8, cmd_name, "board") or
            std.mem.eql(u8, cmd_name, "agent") or std.mem.eql(u8, cmd_name, "protocol") or
            std.mem.eql(u8, cmd_name, "pr") or std.mem.eql(u8, cmd_name, "check") or
            std.mem.eql(u8, cmd_name, "dispatch") or std.mem.eql(u8, cmd_name, "graphql"))
        {
            var gh_args = try std.ArrayList([]const u8).initCapacity(allocator, cmd_args.len + 1);
            defer gh_args.deinit(allocator);
            try gh_args.append(allocator, cmd_name);
            try gh_args.appendSlice(allocator, cmd_args);
            try github_commands.runGithubCommand(allocator, gh_args.items, state.dry_run);
            return;
        }
    }

    // SYSTEM namespace commands
    if (ns == .system) {
        if (std.mem.eql(u8, cmd_name, "doctor")) {
            try commands.runDoctorCommand(allocator, cmd_args);
            return;
        }
        if (std.mem.eql(u8, cmd_name, "clean")) {
            try commands.runCleanCommand(allocator);
            return;
        }
        if (std.mem.eql(u8, cmd_name, "info")) {
            try commands.runInfoCommand(allocator);
            return;
        }
    }

    // FORGE namespace commands - fall through to flat dispatch
    // (fpga commands handled by existing Command enum)

    // Fall back to flat command parsing for backward compatibility
    const cmd = utils.parseCommand(cmd_name);
    if (cmd == .none) {
        std.debug.print("{s}Unknown command: tri {s} {s}{s}\n", .{ "\x1b[38;2;255;100m", ns.toString(), cmd_name, "\x1b[0m" });
        std.debug.print("Use {s}tri help{s} or {s}tri {s} help{s} for available commands.\n", .{ "\x1b[38;2;0;229;153m", "\x1b[0m", "\x1b[38;2;0;229;153m", ns.toString(), "\x1b[0m" });
        return;
    }

    try dispatchCommand(allocator, state, cmd, cmd_args, is_internal_job_exec);
}

/// Helper to dispatch a Command enum to its handler
fn dispatchCommand(
    allocator: std.mem.Allocator,
    state: *utils.CLIState,
    cmd: utils.Command,
    cmd_args: []const []const u8,
    is_internal_job_exec: bool,
) !void {
    return switch (cmd) {
        .chat => utils.runChatCommand(state, cmd_args),
        .code => {
            // tri code arena → code arena subcommands
            if (cmd_args.len > 0 and std.mem.eql(u8, cmd_args[0], "arena")) {
                try code_arena.runCodeArenaCommand(allocator, cmd_args[1..]);
            } else {
                utils.runCodeCommand(state, cmd_args);
            }
        },
        .gen => commands.runGenCommand(allocator, cmd_args),
        .convert => commands.runConvertCommand(cmd_args),
        .serve => commands.runServeCommand(allocator, cmd_args),
        .bench => if (is_internal_job_exec)
            commands.runBenchCommandInternal(allocator)
        else
            commands.runBenchCommandAsync(allocator, cmd_args),
        .commit => commands.runGitCommand(allocator, "commit", cmd_args),
        .diff => commands.runGitCommand(allocator, "diff", cmd_args),
        .status => commands.runGitCommand(allocator, "status", cmd_args),
        .log => commands.runGitCommand(allocator, "log", cmd_args),
        .pipeline => pipeline.runPipelineCommand(allocator, cmd_args),
        .chain => pipeline.runChainCommand(allocator, cmd_args),
        .decompose => pipeline.runDecomposeCommand(allocator, cmd_args),
        .plan => pipeline.runPlanCommand(allocator, cmd_args),
        .verify => pipeline.runVerifyCommand(allocator),
        .verdict => pipeline.runVerdictCommandEx(allocator, cmd_args),
        .doctor => commands.runDoctorCommand(allocator, cmd_args),
        .regen => {
            const regen_mod = @import("regen.zig");
            try regen_mod.runRegenCLI(allocator, cmd_args);
        },
        .commands => tri_list.runCommandsList(allocator, cmd_args),
        .mcp => tri_mcp.runMcpCommand(allocator, cmd_args),
        // SWE Agent commands (agent namespace)
        .fix => utils.runSWECommand(state, .BugFix, cmd_args),
        .explain => utils.runSWECommand(state, .Explain, cmd_args),
        .test_cmd => utils.runSWECommand(state, .Test, cmd_args),
        .doc => utils.runSWECommand(state, .Document, cmd_args),
        .refactor => utils.runSWECommand(state, .Refactor, cmd_args),
        .reason => utils.runSWECommand(state, .Reason, cmd_args),
        // FPGA commands (forge namespace)
        .fpga => try tri_register.runFpgaCommand(allocator, cmd_args),
        .sacred_const => try sacred_fpga.runSacredConstCommand(allocator, cmd_args),
        // Spec Linter (dev namespace)
        .lint => commands.runLintCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Lint error: {}\n", .{err});
        },
        // Spec Enricher (Issue #69)
        .enrich => {
            const spec_enricher = @import("tri_spec_enricher.zig");
            spec_enricher.runEnrichCommand(allocator, cmd_args) catch |err| {
                std.debug.print("Enrich error: {}\n", .{err});
            };
        },
        // Spec ↔ Code Sync Checker (Issue #71)
        .sync_check => {
            const sc = @import("sync_checker.zig");
            _ = sc.runSyncCheckCommand(allocator, cmd_args) catch |err| {
                std.debug.print("Sync check error: {}\n", .{err});
            };
        },
        // GitHub Integration (Protocol v2)
        .github => github_commands.runGithubCommand(allocator, cmd_args, state.dry_run) catch |err| {
            std.debug.print("GitHub error: {}\n", .{err});
        },
        .faculty => faculty_board.runFacultyCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Faculty error: {}\n", .{err});
        },
        .experiment => tri_experiment.runExperimentCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Experiment error: {}\n", .{err});
        },
        // Observatory v5.2
        .trace => {
            const tracer_mod = @import("tracer.zig");
            tracer_mod.runTraceCommand(allocator, cmd_args);
        },
        .eval => {
            const eval_mod = @import("eval_harness.zig");
            eval_mod.runEvalCommand(allocator, cmd_args);
        },
        .metrics => {
            const metrics_mod = @import("metrics_aggregator.zig");
            metrics_mod.runMetricsCommand(allocator, cmd_args);
        },
        .context_load => {
            const ctx_loader = @import("context_loader.zig");
            ctx_loader.runContextCommand(allocator, cmd_args);
        },
        else => |c| {
            std.debug.print("{s}Command not yet accessible via namespace: {s}{s}\n", .{ "\x1b[38;2;255;100m", @tagName(c), "\x1b[0m" });
            std.debug.print("Use the flat command name for now (e.g., {s}tri {s}{s} instead of {s}tri <namespace> {s}{s})\n", .{ "\x1b[38;2;0;229;153m", @tagName(c), "\x1b[0m", "\x1b[38;2;0;229;153m", @tagName(c), "\x1b[0m" });
        },
    };
}

test "main module compiles" {
    // Verify main module imports are resolved
    try std.testing.expect(true);
}
