// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI — Configuration File Support
// ═══════════════════════════════════════════════════════════════════════════════
//
// Configuration management for TRI CLI
// Supports ~/.trirc and .trirc.local files
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const ArrayListManaged = std.array_list.Managed;

// Global JSON output flag - set from main.zig before command dispatch
var global_json_output: bool = false;

/// Set global JSON output mode (called from main.zig)
pub fn setJsonOutput(enabled: bool) void {
    global_json_output = enabled;
}

/// Check if global JSON output mode is enabled
pub fn isJsonOutput() bool {
    return global_json_output;
}

pub const Config = struct {
    allocator: std.mem.Allocator,

    // General settings
    verbose: bool = false,
    quiet: bool = false,
    dry_run: bool = false,

    // Output settings
    output_format: OutputFormat = .text,
    color_output: bool = true,

    // Server settings
    default_port: u16 = 8080,
    default_host: []const u8 = "127.0.0.1",

    // Editor settings
    editor: []const u8 = "vim",

    // Paths
    specs_dir: []const u8 = "specs/tri",
    output_dir: []const u8 = "trinity/output",

    // History
    history_size: usize = 1000,
    history_file: []const u8 = ".tri_history",

    pub const OutputFormat = enum {
        text,
        json,
        yaml,
    };

    /// Default configuration
    pub fn init(allocator: std.mem.Allocator) Config {
        return Config{
            .allocator = allocator,
        };
    }

    /// Load configuration from file (~/.trirc or .trirc.local)
    pub fn load(allocator: std.mem.Allocator) !Config {
        var config = Config.init(allocator);

        // Try global config first
        const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch |err| {
            std.debug.print("Warning: Could not get HOME directory: {}\n", .{err});
            return config;
        };
        defer allocator.free(home_dir);

        const global_config_path = try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".trirc" });
        defer allocator.free(global_config_path);

        // Try local config (overrides global)
        const local_config_path = ".trirc.local";

        // Load global if exists
        loadFromFile(&config, global_config_path) catch {};

        // Load local if exists (takes precedence)
        loadFromFile(&config, local_config_path) catch {};

        return config;
    }

    /// Load configuration from a specific file
    fn loadFromFile(self: *Config, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const contents = try file.readToEndAlloc(self.allocator, 8192);
        defer self.allocator.free(contents);

        // Simple key=value parser
        var lines = std.mem.splitScalar(u8, contents, '\n');

        while (lines.next()) |line| {
            // Skip comments and empty lines
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            // Parse key=value
            const eq_idx = std.mem.indexOfScalar(u8, trimmed, '=') orelse continue;
            const key = trimmed[0..eq_idx];
            const val = trimmed[eq_idx + 1 ..];

            const key_trimmed = std.mem.trim(u8, key, " \t");
            const val_trimmed = std.mem.trim(u8, val, " \t\"'");

            // Apply settings
            applySetting(self, key_trimmed, val_trimmed) catch {};
        }
    }

    /// Apply a single configuration setting
    fn applySetting(self: *Config, key: []const u8, value: []const u8) !void {
        if (std.mem.eql(u8, key, "verbose")) {
            if (std.mem.eql(u8, value, "true")) {
                self.verbose = true;
            } else if (std.mem.eql(u8, value, "false")) {
                self.verbose = false;
            }
        } else if (std.mem.eql(u8, key, "quiet")) {
            if (std.mem.eql(u8, value, "true")) {
                self.quiet = true;
            } else if (std.mem.eql(u8, value, "false")) {
                self.quiet = false;
            }
        } else if (std.mem.eql(u8, key, "dry_run")) {
            if (std.mem.eql(u8, value, "true")) {
                self.dry_run = true;
            } else if (std.mem.eql(u8, value, "false")) {
                self.dry_run = false;
            }
        } else if (std.mem.eql(u8, key, "color")) {
            if (std.mem.eql(u8, value, "true")) {
                self.color_output = true;
            } else if (std.mem.eql(u8, value, "false")) {
                self.color_output = false;
            }
        } else if (std.mem.eql(u8, key, "output_format")) {
            if (std.mem.eql(u8, value, "text")) {
                self.output_format = .text;
            } else if (std.mem.eql(u8, value, "json")) {
                self.output_format = .json;
            } else if (std.mem.eql(u8, value, "yaml")) {
                self.output_format = .yaml;
            }
        } else if (std.mem.eql(u8, key, "port")) {
            self.default_port = try std.fmt.parseInt(u16, value, 10);
        } else if (std.mem.eql(u8, key, "host")) {
            self.default_host = try self.allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "editor")) {
            self.editor = try self.allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "specs_dir")) {
            self.specs_dir = try self.allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "output_dir")) {
            self.output_dir = try self.allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "history_size")) {
            self.history_size = try std.fmt.parseInt(usize, value, 10);
        } else if (std.mem.eql(u8, key, "history_file")) {
            self.history_file = try self.allocator.dupe(u8, value);
        }
        // Silently ignore unknown keys
    }

    /// Save current configuration to file
    pub fn save(self: *const Config, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();

        try writer.print("# TRI CLI Configuration\n", .{});
        try writer.print("# Generated by TRI v{s}\n\n", .{"1.0.1"});

        try writer.print("# General\n", .{});
        try writer.print("verbose={}\n", .{self.verbose});
        try writer.print("quiet={}\n", .{self.quiet});
        try writer.print("dry_run={}\n", .{self.dry_run});
        try writer.print("color={}\n\n", .{self.color_output});

        try writer.print("# Output\n", .{});
        try writer.print("output_format={s}\n\n", .{@tagName(self.output_format)});

        try writer.print("# Server defaults\n", .{});
        try writer.print("port={d}\n", .{self.default_port});
        try writer.print("host={s}\n\n", .{self.default_host});

        try writer.print("# Paths\n", .{});
        try writer.print("specs_dir={s}\n", .{self.specs_dir});
        try writer.print("output_dir={s}\n", .{self.output_dir});
        try writer.print("editor={s}\n\n", .{self.editor});

        try writer.print("# History\n", .{});
        try writer.print("history_size={d}\n", .{self.history_size});
        try writer.print("history_file={s}\n", .{self.history_file});
    }

    /// Create default config file
    pub fn createDefault(path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writeAll(
            \\# TRI CLI Configuration
            \\# Generated by TRI 1.0.1
            \\
            \\# General settings
            \\verbose=false
            \\quiet=false
            \\dry_run=false
            \\color=true
            \\
            \\# Output format: text, json, yaml
            \\output_format=text
            \\
            \\# Server defaults
            \\port=8080
            \\host=127.0.0.1
            \\
            \\# Paths
            \\specs_dir=specs/tri
            \\output_dir=trinity/output
            \\editor=vim
            \\
            \\# Command history
            \\history_size=1000
            \\history_file=.tri_history
            \\
        );
    }

    /// Deallocate owned resources
    pub fn deinit(self: *Config) void {
        // Note: Only free strings that were duplicated
        _ = self;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VALIDATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const ValidationError = struct {
    field: []const u8,
    message: []const u8,
    value: []const u8,
};

pub const Validator = struct {
    errors: ArrayListManaged(ValidationError),

    pub fn init(allocator: std.mem.Allocator) Validator {
        return Validator{
            .errors = ArrayListManaged(ValidationError).init(allocator),
        };
    }

    pub fn deinit(self: *Validator) void {
        self.errors.deinit();
    }

    pub fn hasErrors(self: *const Validator) bool {
        return self.errors.items.len > 0;
    }

    pub fn addError(self: *Validator, field: []const u8, message: []const u8, value: []const u8) !void {
        try self.errors.append(ValidationError{
            .field = field,
            .message = message,
            .value = value,
        });
    }

    /// Validate a port number
    pub fn validatePort(self: *Validator, port: u16, field_name: []const u8) !void {
        if (port < 1 or port > 65535) {
            try self.addError(field_name, "Port must be between 1 and 65535", "");
        }
    }

    /// Validate a file path exists
    pub fn validateFileExists(self: *Validator, path: []const u8, field_name: []const u8) !void {
        if (std.fs.cwd().openFile(path, .{})) |file| {
            file.close();
        } else |_| {
            try self.addError(field_name, "File does not exist", path);
        }
    }

    /// Validate a file extension
    pub fn validateFileExtension(self: *Validator, path: []const u8, allowed_exts: []const []const u8, field_name: []const u8) !void {
        const ext = std.fs.path.extension(path);
        var valid = false;

        for (allowed_exts) |allowed| {
            if (std.mem.eql(u8, ext, allowed)) {
                valid = true;
                break;
            }
        }

        if (!valid) {
            try self.addError(field_name, "Invalid file extension", path);
        }
    }

    /// Validate a number is in range
    pub fn validateRange(self: *Validator, value: anytype, min: anytype, max: anytype, field_name: []const u8) !void {
        if (value < min or value > max) {
            try self.addError(field_name, "Value out of range", "");
        }
    }

    /// Print all validation errors
    pub fn printErrors(self: *const Validator) void {
        const RED = "\x1b[38;2;239;68;68m";
        const CYAN = "\x1b[38;2;0;229;153m";
        const YELLOW = "\x1b[38;2;255;215;0m";
        const RESET = "\x1b[0m";

        if (self.errors.items.len == 0) return;

        std.debug.print("{s}\nValidation Errors:{s}\n\n", .{ RED, RESET });

        for (self.errors.items, 0..) |err, i| {
            std.debug.print("{s}  {d}. {s}: {s}\n", .{ RED, i + 1, err.field, err.message, RESET });
            if (err.value.len > 0) {
                std.debug.print("{s}     Value: {s}\n", .{ YELLOW, err.value, RESET });
            }
        }

        std.debug.print("{s}\nUse --help for usage information.{s}\n\n", .{ CYAN, RESET });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Config: default initialization" {
    const allocator = std.testing.allocator;
    const config = Config.init(allocator);

    try std.testing.expectEqual(false, config.verbose);
    try std.testing.expectEqual(false, config.quiet);
    try std.testing.expectEqual(@as(u16, 8080), config.default_port);
}

test "Config: apply boolean settings" {
    const allocator = std.testing.allocator;
    var config = Config.init(allocator);

    try config.applySetting("verbose", "true");
    try std.testing.expectEqual(true, config.verbose);

    try config.applySetting("quiet", "false");
    try std.testing.expectEqual(false, config.quiet);
}

test "Config: apply numeric settings" {
    const allocator = std.testing.allocator;
    var config = Config.init(allocator);

    try config.applySetting("port", "3000");
    try std.testing.expectEqual(@as(u16, 3000), config.default_port);

    try config.applySetting("history_size", "500");
    try std.testing.expectEqual(@as(usize, 500), config.history_size);
}

test "Validator: port validation" {
    const allocator = std.testing.allocator;
    var validator = Validator.init(allocator);
    defer validator.deinit();

    try validator.validatePort(8080, "test_port");
    try validator.validatePort(0, "test_port");
    try validator.validatePort(65535, "test_port");

    try std.testing.expect(validator.hasErrors());
}

test "Validator: file extension validation" {
    const allocator = std.testing.allocator;
    var validator = Validator.init(allocator);
    defer validator.deinit();

    const allowed = &[_][]const u8{ ".tri", ".tri" };
    try validator.validateFileExtension("test.tri", allowed, "test_file");
    try validator.validateFileExtension("test.txt", allowed, "test_file");

    try std.testing.expect(validator.hasErrors());
}
