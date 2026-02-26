    // 6. Tree-sitter analysis (cycle-78)
    std.debug.print("{s}[6/6]{s} Tree-sitter:  ", .{ CYAN, RESET });
    std.debug.print("{s}C parser available{s}\\n", .{ GREEN, RESET });
    std.debug.print("  Violation types: 12 checks (AST-based)\\n", .{ GRAY, RESET });
    std.debug.print("  Unified analyzer: string + AST fallback\\n");
    std.debug.print("\\n{s}Use 'tri analyze <file>' for detailed analysis{s}\\n", .{ YELLOW, RESET });
// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Tool Command Handlers
// ═══════════════════════════════════════════════════════════════════════════════
//
// Command implementations: gen, convert, serve, bench, evolve, git.
// Extracted from main.zig for faster compilation.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const chat_server = @import("chat_server.zig");

