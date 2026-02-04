// Trinity Plugin CLI Commands
// Generated from: specs/tri/plugin/plugin_cli.vibee
// Sacred Formula: V = n x 3^k x pi^m x phi^p x e^q
// Golden Identity: phi^2 + 1/phi^2 = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const interface = @import("plugin_interface.zig");
const registry_mod = @import("plugin_registry.zig");
const loader_mod = @import("plugin_loader.zig");
const manifest_mod = @import("plugin_manifest.zig");

const Plugin = interface.Plugin;
const PluginKind = interface.PluginKind;
const PluginRegistry = registry_mod.PluginRegistry;
const PluginLoader = loader_mod.PluginLoader;
const Version = manifest_mod.Version;

// ============================================================================
// CONSTANTS
// ============================================================================

pub const DEFAULT_REGISTRY_URL = "https://registry.trinity-network.dev";
pub const CACHE_DIR = "~/.trinity/cache/plugins";
pub const MAX_SEARCH_RESULTS: usize = 50;

// ============================================================================
// TYPES
// ============================================================================

/// Plugin management subcommands
pub const PluginSubcommand = enum {
    list,
    info,
    search,
    install,
    uninstall,
    update,
    init,
    build,
    publish,
    enable,
    disable,
    help,

    pub fn fromString(str: []const u8) ?PluginSubcommand {
        const map = std.StaticStringMap(PluginSubcommand).initComptime(.{
            .{ "list", .list },
            .{ "ls", .list },
            .{ "info", .info },
            .{ "show", .info },
            .{ "search", .search },
            .{ "find", .search },
            .{ "install", .install },
            .{ "add", .install },
            .{ "i", .install },
            .{ "uninstall", .uninstall },
            .{ "remove", .uninstall },
            .{ "rm", .uninstall },
            .{ "update", .update },
            .{ "upgrade", .update },
            .{ "init", .init },
            .{ "new", .init },
            .{ "build", .build },
            .{ "publish", .publish },
            .{ "enable", .enable },
            .{ "disable", .disable },
            .{ "help", .help },
            .{ "-h", .help },
            .{ "--help", .help },
        });
        return map.get(str);
    }
};

/// Output format
pub const OutputFormat = enum {
    table,
    json,
    minimal,
};

/// Options for list command
pub const ListOptions = struct {
    kind: ?PluginKind = null,
    show_disabled: bool = false,
    format: OutputFormat = .table,
};

/// Options for install command
pub const InstallOptions = struct {
    plugin_spec: []const u8,
    force: bool = false,
    dev: bool = false,
};

/// Options for init command
pub const InitOptions = struct {
    name: []const u8,
    kind: PluginKind = .codegen,
    directory: ?[]const u8 = null,
};

/// Result of CLI command execution
pub const CommandResult = struct {
    success: bool,
    message: []const u8,
    exit_code: u8,

    pub fn ok(message: []const u8) CommandResult {
        return .{ .success = true, .message = message, .exit_code = 0 };
    }

    pub fn err(message: []const u8) CommandResult {
        return .{ .success = false, .message = message, .exit_code = 1 };
    }
};

// ============================================================================
// CLI HANDLER
// ============================================================================

/// Plugin CLI handler
pub const PluginCLI = struct {
    allocator: Allocator,
    registry: *PluginRegistry,
    loader: *PluginLoader,
    stdout: std.fs.File.Writer,
    stderr: std.fs.File.Writer,

    const Self = @This();

    pub fn init(allocator: Allocator, registry: *PluginRegistry, loader: *PluginLoader) Self {
        return .{
            .allocator = allocator,
            .registry = registry,
            .loader = loader,
            .stdout = std.io.getStdOut().any(),
            .stderr = std.io.getStdErr().any(),
        };
    }

    /// Execute plugin command
    pub fn execute(self: *Self, args: []const []const u8) !CommandResult {
        if (args.len == 0) {
            return self.cmdHelp();
        }

        const subcmd = PluginSubcommand.fromString(args[0]) orelse {
            try self.stderr.print("Unknown plugin command: {s}\n", .{args[0]});
            try self.stderr.print("Run 'vibee plugin help' for usage\n", .{});
            return CommandResult.err("Unknown command");
        };

        const subcmd_args = if (args.len > 1) args[1..] else &[_][]const u8{};

        return switch (subcmd) {
            .list => self.cmdList(subcmd_args),
            .info => self.cmdInfo(subcmd_args),
            .search => self.cmdSearch(subcmd_args),
            .install => self.cmdInstall(subcmd_args),
            .uninstall => self.cmdUninstall(subcmd_args),
            .update => self.cmdUpdate(subcmd_args),
            .init => self.cmdInit(subcmd_args),
            .build => self.cmdBuild(subcmd_args),
            .publish => self.cmdPublish(subcmd_args),
            .enable => self.cmdEnable(subcmd_args),
            .disable => self.cmdDisable(subcmd_args),
            .help => self.cmdHelp(),
        };
    }

    // ========================================================================
    // COMMANDS
    // ========================================================================

    /// List installed plugins
    fn cmdList(self: *Self, args: []const []const u8) !CommandResult {
        var opts = ListOptions{};

        // Parse args
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, arg, "--kind") or std.mem.eql(u8, arg, "-k")) {
                if (i + 1 < args.len) {
                    i += 1;
                    opts.kind = parseKind(args[i]);
                }
            } else if (std.mem.eql(u8, arg, "--all") or std.mem.eql(u8, arg, "-a")) {
                opts.show_disabled = true;
            } else if (std.mem.eql(u8, arg, "--json")) {
                opts.format = .json;
            }
        }

        // Get plugins
        const query = registry_mod.PluginQuery{
            .kind = opts.kind,
            .enabled_only = !opts.show_disabled,
        };
        const plugins = try self.registry.query(query);
        defer self.allocator.free(plugins);

        if (plugins.len == 0) {
            try self.stdout.print("No plugins installed\n", .{});
            return CommandResult.ok("No plugins");
        }

        // Print header
        try self.stdout.print("\n", .{});
        try self.stdout.print("{s:<30} {s:<10} {s:<12} {s:<8}\n", .{ "ID", "VERSION", "KIND", "STATUS" });
        try self.stdout.print("{s:->30} {s:->10} {s:->12} {s:->8}\n", .{ "", "", "", "" });

        // Print plugins
        for (plugins) |entry| {
            const status: []const u8 = if (entry.enabled) "enabled" else "disabled";
            try self.stdout.print("{s:<30} {s:<10} {s:<12} {s:<8}\n", .{
                entry.plugin.metadata.id,
                entry.plugin.metadata.version,
                entry.plugin.metadata.kind.toString(),
                status,
            });
        }

        try self.stdout.print("\nTotal: {} plugin(s)\n", .{plugins.len});
        return CommandResult.ok("Listed plugins");
    }

    /// Show plugin info
    fn cmdInfo(self: *Self, args: []const []const u8) !CommandResult {
        if (args.len == 0) {
            try self.stderr.print("Usage: vibee plugin info <plugin-id>\n", .{});
            return CommandResult.err("Missing plugin ID");
        }

        const plugin_id = args[0];
        const entry = self.registry.get(plugin_id) orelse {
            try self.stderr.print("Plugin not found: {s}\n", .{plugin_id});
            return CommandResult.err("Plugin not found");
        };

        const p = entry.plugin;
        try self.stdout.print("\n", .{});
        try self.stdout.print("Plugin: {s}\n", .{p.metadata.name});
        try self.stdout.print("ID:     {s}\n", .{p.metadata.id});
        try self.stdout.print("Version: {s}\n", .{p.metadata.version});
        try self.stdout.print("Author: {s}\n", .{p.metadata.author});
        try self.stdout.print("Kind:   {s}\n", .{p.metadata.kind.toString()});
        try self.stdout.print("Status: {s}\n", .{if (entry.enabled) "enabled" else "disabled"});
        try self.stdout.print("Source: {s}\n", .{@tagName(entry.source)});

        if (p.metadata.capabilities.len > 0) {
            try self.stdout.print("\nCapabilities:\n", .{});
            for (p.metadata.capabilities) |cap| {
                try self.stdout.print("  - {s} ({s})\n", .{ cap.name, cap.version });
            }
        }

        return CommandResult.ok("Showed info");
    }

    /// Search remote registry
    fn cmdSearch(self: *Self, args: []const []const u8) !CommandResult {
        if (args.len == 0) {
            try self.stderr.print("Usage: vibee plugin search <query>\n", .{});
            return CommandResult.err("Missing search query");
        }

        const query = args[0];
        try self.stdout.print("Searching for '{s}'...\n", .{query});
        try self.stdout.print("\n(Remote registry not yet implemented)\n", .{});
        try self.stdout.print("Registry URL: {s}\n", .{DEFAULT_REGISTRY_URL});

        return CommandResult.ok("Search complete");
    }

    /// Install plugin
    fn cmdInstall(self: *Self, args: []const []const u8) !CommandResult {
        if (args.len == 0) {
            try self.stderr.print("Usage: vibee plugin install <plugin-spec>\n", .{});
            try self.stderr.print("       vibee plugin install ./path/to/plugin.wasm\n", .{});
            return CommandResult.err("Missing plugin spec");
        }

        const spec = args[0];

        // Check if local file
        if (std.mem.endsWith(u8, spec, ".wasm") or std.mem.endsWith(u8, spec, ".zig")) {
            try self.stdout.print("Installing from local file: {s}\n", .{spec});
            const result = try self.loader.loadFromPath(spec);
            if (result.success) {
                try self.stdout.print("Successfully installed plugin\n", .{});
                return CommandResult.ok("Installed");
            } else {
                try self.stderr.print("Failed to install: {s}\n", .{result.@"error" orelse "unknown error"});
                return CommandResult.err("Installation failed");
            }
        }

        // Remote install
        try self.stdout.print("Installing {s} from registry...\n", .{spec});
        try self.stdout.print("\n(Remote installation not yet implemented)\n", .{});

        return CommandResult.ok("Install initiated");
    }

    /// Uninstall plugin
    fn cmdUninstall(self: *Self, args: []const []const u8) !CommandResult {
        if (args.len == 0) {
            try self.stderr.print("Usage: vibee plugin uninstall <plugin-id>\n", .{});
            return CommandResult.err("Missing plugin ID");
        }

        const plugin_id = args[0];
        self.registry.unregister(plugin_id) catch |e| {
            try self.stderr.print("Failed to uninstall {s}: {}\n", .{ plugin_id, e });
            return CommandResult.err("Uninstall failed");
        };

        try self.stdout.print("Uninstalled: {s}\n", .{plugin_id});
        return CommandResult.ok("Uninstalled");
    }

    /// Update plugins
    fn cmdUpdate(self: *Self, args: []const []const u8) !CommandResult {
        _ = args;
        try self.stdout.print("Checking for updates...\n", .{});
        try self.stdout.print("\n(Update functionality not yet implemented)\n", .{});
        return CommandResult.ok("Update check complete");
    }

    /// Initialize new plugin project
    fn cmdInit(self: *Self, args: []const []const u8) !CommandResult {
        if (args.len == 0) {
            try self.stderr.print("Usage: vibee plugin init <name> [--kind <kind>]\n", .{});
            return CommandResult.err("Missing plugin name");
        }

        const name = args[0];
        var kind: PluginKind = .codegen;

        // Parse --kind
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--kind") or std.mem.eql(u8, args[i], "-k")) {
                if (i + 1 < args.len) {
                    i += 1;
                    kind = parseKind(args[i]) orelse .codegen;
                }
            }
        }

        try self.stdout.print("Creating new plugin: {s}\n", .{name});
        try self.stdout.print("Kind: {s}\n", .{kind.toString()});

        // Create directory
        std.fs.cwd().makeDir(name) catch |e| {
            if (e != error.PathAlreadyExists) {
                try self.stderr.print("Failed to create directory: {}\n", .{e});
                return CommandResult.err("Failed to create directory");
            }
        };

        // Create plugin.vibee manifest
        const manifest_content = try std.fmt.allocPrint(self.allocator,
            \\# Trinity Plugin Manifest
            \\# phi^2 + 1/phi^2 = 3
            \\
            \\name: {s}
            \\id: "trinity.{s}.{s}"
            \\version: "0.1.0"
            \\description: "A Trinity plugin"
            \\author: "Your Name"
            \\license: "MIT"
            \\kind: {s}
            \\
            \\entry_point: "plugin.wasm"
            \\
            \\dependencies:
            \\  trinity-core: "^1.0.0"
            \\
            \\sandbox:
            \\  type: wasm
            \\  memory_limit_mb: 256
            \\
        , .{ name, kind.toString(), name, kind.toString() });
        defer self.allocator.free(manifest_content);

        const manifest_path = try std.fmt.allocPrint(self.allocator, "{s}/plugin.vibee", .{name});
        defer self.allocator.free(manifest_path);

        const file = std.fs.cwd().createFile(manifest_path, .{}) catch |e| {
            try self.stderr.print("Failed to create manifest: {}\n", .{e});
            return CommandResult.err("Failed to create manifest");
        };
        defer file.close();
        try file.writeAll(manifest_content);

        try self.stdout.print("\nCreated:\n", .{});
        try self.stdout.print("  {s}/\n", .{name});
        try self.stdout.print("  {s}/plugin.vibee\n", .{name});
        try self.stdout.print("\nNext steps:\n", .{});
        try self.stdout.print("  1. cd {s}\n", .{name});
        try self.stdout.print("  2. Edit plugin.vibee\n", .{});
        try self.stdout.print("  3. vibee plugin build\n", .{});

        return CommandResult.ok("Plugin initialized");
    }

    /// Build plugin
    fn cmdBuild(self: *Self, args: []const []const u8) !CommandResult {
        _ = args;
        try self.stdout.print("Building plugin...\n", .{});
        try self.stdout.print("\n(Build functionality not yet implemented)\n", .{});
        return CommandResult.ok("Build complete");
    }

    /// Publish plugin
    fn cmdPublish(self: *Self, args: []const []const u8) !CommandResult {
        _ = args;
        try self.stdout.print("Publishing plugin to {s}...\n", .{DEFAULT_REGISTRY_URL});
        try self.stdout.print("\n(Publish functionality not yet implemented)\n", .{});
        return CommandResult.ok("Publish initiated");
    }

    /// Enable plugin
    fn cmdEnable(self: *Self, args: []const []const u8) !CommandResult {
        if (args.len == 0) {
            try self.stderr.print("Usage: vibee plugin enable <plugin-id>\n", .{});
            return CommandResult.err("Missing plugin ID");
        }

        const plugin_id = args[0];
        self.registry.enable(plugin_id) catch |e| {
            try self.stderr.print("Failed to enable {s}: {}\n", .{ plugin_id, e });
            return CommandResult.err("Enable failed");
        };

        try self.stdout.print("Enabled: {s}\n", .{plugin_id});
        return CommandResult.ok("Enabled");
    }

    /// Disable plugin
    fn cmdDisable(self: *Self, args: []const []const u8) !CommandResult {
        if (args.len == 0) {
            try self.stderr.print("Usage: vibee plugin disable <plugin-id>\n", .{});
            return CommandResult.err("Missing plugin ID");
        }

        const plugin_id = args[0];
        self.registry.disable(plugin_id) catch |e| {
            try self.stderr.print("Failed to disable {s}: {}\n", .{ plugin_id, e });
            return CommandResult.err("Disable failed");
        };

        try self.stdout.print("Disabled: {s}\n", .{plugin_id});
        return CommandResult.ok("Disabled");
    }

    /// Show help
    fn cmdHelp(self: *Self) !CommandResult {
        try self.stdout.print(
            \\
            \\Trinity Plugin Manager
            \\phi^2 + 1/phi^2 = 3
            \\
            \\USAGE:
            \\  vibee plugin <command> [options]
            \\
            \\COMMANDS:
            \\  list, ls              List installed plugins
            \\  info, show <id>       Show plugin details
            \\  search, find <query>  Search remote registry
            \\  install, add <spec>   Install plugin
            \\  uninstall, rm <id>    Remove plugin
            \\  update [id|--all]     Update plugins
            \\  init <name>           Create new plugin project
            \\  build                 Build plugin to WASM
            \\  publish               Publish to registry
            \\  enable <id>           Enable plugin
            \\  disable <id>          Disable plugin
            \\  help                  Show this help
            \\
            \\OPTIONS:
            \\  --kind, -k <kind>     Filter by kind (codegen, validator, vsa_op, etc.)
            \\  --all, -a             Include disabled plugins
            \\  --json                Output as JSON
            \\
            \\EXAMPLES:
            \\  vibee plugin list
            \\  vibee plugin list --kind codegen
            \\  vibee plugin install trinity.codegen.rust
            \\  vibee plugin install ./my-plugin.wasm
            \\  vibee plugin init my-plugin --kind codegen
            \\
        , .{});
        return CommandResult.ok("Help displayed");
    }
};

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

fn parseKind(str: []const u8) ?PluginKind {
    const map = std.StaticStringMap(PluginKind).initComptime(.{
        .{ "codegen", .codegen },
        .{ "validator", .validator },
        .{ "vsa_op", .vsa_op },
        .{ "vsa", .vsa_op },
        .{ "firebird_ext", .firebird_ext },
        .{ "firebird", .firebird_ext },
        .{ "optimizer", .optimizer },
        .{ "backend", .backend },
    });
    return map.get(str);
}

/// Main entry point for plugin CLI
pub fn runPluginCommand(allocator: Allocator, args: []const []const u8) !u8 {
    var registry = try PluginRegistry.init(allocator);
    defer registry.deinit();

    var loader = PluginLoader.init(allocator, &registry, .{});
    defer loader.deinit();

    var cli = PluginCLI.init(allocator, &registry, &loader);
    const result = try cli.execute(args);

    return result.exit_code;
}

// ============================================================================
// TESTS
// ============================================================================

test "subcommand from string" {
    try std.testing.expectEqual(PluginSubcommand.list, PluginSubcommand.fromString("list").?);
    try std.testing.expectEqual(PluginSubcommand.list, PluginSubcommand.fromString("ls").?);
    try std.testing.expectEqual(PluginSubcommand.install, PluginSubcommand.fromString("install").?);
    try std.testing.expectEqual(PluginSubcommand.install, PluginSubcommand.fromString("add").?);
    try std.testing.expectEqual(PluginSubcommand.install, PluginSubcommand.fromString("i").?);
    try std.testing.expect(PluginSubcommand.fromString("invalid") == null);
}

test "parse kind" {
    try std.testing.expectEqual(PluginKind.codegen, parseKind("codegen").?);
    try std.testing.expectEqual(PluginKind.validator, parseKind("validator").?);
    try std.testing.expectEqual(PluginKind.vsa_op, parseKind("vsa").?);
    try std.testing.expect(parseKind("invalid") == null);
}

test "command result" {
    const ok = CommandResult.ok("success");
    try std.testing.expect(ok.success);
    try std.testing.expectEqual(@as(u8, 0), ok.exit_code);

    const err = CommandResult.err("failure");
    try std.testing.expect(!err.success);
    try std.testing.expectEqual(@as(u8, 1), err.exit_code);
}

test "plugin cli init" {
    const allocator = std.testing.allocator;

    var registry = try PluginRegistry.init(allocator);
    defer registry.deinit();

    var loader = PluginLoader.init(allocator, &registry, .{});
    defer loader.deinit();

    var cli = PluginCLI.init(allocator, &registry, &loader);
    _ = cli;
}
