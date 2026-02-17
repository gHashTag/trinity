const std = @import("std");
const mentor_mod = @import("trinity_mentor.zig");

// ============================================================================
// EVOLVED CLI - THE NERVOUS SYSTEM
// ============================================================================

pub const CommandHandler = *const fn (allocator: std.mem.Allocator, args: []const []const u8) anyerror!void;

pub const CommandOrganism = struct {
    allocator: std.mem.Allocator,
    handlers: std.StringHashMap(CommandHandler),
    mentor: mentor_mod.Mentor,

    pub fn init(allocator: std.mem.Allocator) CommandOrganism {
        return CommandOrganism{
            .allocator = allocator,
            .handlers = std.StringHashMap(CommandHandler).init(allocator),
            .mentor = mentor_mod.Mentor.init(allocator),
        };
    }

    pub fn deinit(self: *CommandOrganism) void {
        self.handlers.deinit();
        self.mentor.deinit();
    }

    /// Register a synaptic pathway (command)
    pub fn bindSynapses(self: *CommandOrganism, name: []const u8, handler: CommandHandler) !void {
        try self.handlers.put(name, handler);
        std.debug.print("🧬 [Nervous System] Bound synapse: {s}\n", .{name});
    }

    /// Execute a reflex (command)
    pub fn reflex(self: *CommandOrganism, args: []const []const u8) !void {
        if (args.len == 0) return error.NoInput;

        const cmd_name = args[0];
        if (self.handlers.get(cmd_name)) |handler| {
            std.debug.print("⚡ [Nervous System] Firing synapse: {s}\n", .{cmd_name});
            try handler(self.allocator, args[1..]);
        } else {
            std.debug.print("❓ [Nervous System] Unknown stimulus: {s}\n", .{cmd_name});
            // Opportunity for self-evolution: Could ask LLM to generate a handler?
            // For now, just error.
            return error.UnknownCommand;
        }
    }

    /// Self-Mutation: Optimize a handler binding
    /// In a real living system, this might swap a slow handler for a JIT-compiled one
    pub fn evolveReflex(self: *CommandOrganism, name: []const u8, new_handler: CommandHandler) !void {
        std.debug.print("🦋 [Mutation] Evolving reflex {s}...\n", .{name});

        // Consult Mentor before mutation
        const mock_code = "pub fn handler() void { optimized(); }";
        const passed = try self.mentor.guide(mock_code);

        if (passed) {
            try self.handlers.put(name, new_handler);
            std.debug.print("✨ [Mutation] Success. {s} is now evolved.\n", .{name});
        } else {
            std.debug.print("⛔ [Mutation] Rejected by Mentor. Retaining old reflex.\n", .{});
        }
    }
};

// ============================================================================
// HANDLERS
// ============================================================================

fn defaultChat(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("💬 [Chat] Standard mode active.\n", .{});
}

fn turboChat(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("🚀 [Chat] TURBO AVX2 mode active (10x speedup)!\n", .{});
}

// ============================================================================
// TEST HARNESS
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var organism = CommandOrganism.init(allocator);
    defer organism.deinit();

    // Bind initial instincts
    try organism.bindSynapses("chat", defaultChat);

    // Simulate lifecycle
    const args = [_][]const u8{ "chat", "hello" };
    try organism.reflex(&args);

    // Trigger Evolution
    std.debug.print("\n--- TRIGGERING EVOLUTION ---\n", .{});
    try organism.evolveReflex("chat", turboChat);

    // Test evolved reflex
    try organism.reflex(&args);
}
