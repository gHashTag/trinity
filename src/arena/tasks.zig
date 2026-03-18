// @origin(manual) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// ARENA TASKS — Preset Task Catalog for LLM Battles
// ═══════════════════════════════════════════════════════════════════════════════
//
// 20 starter tasks: 7 math, 7 coding, 6 reasoning
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("types.zig");

const Task = types.Task;
const TaskCategory = types.TaskCategory;
const Difficulty = types.Difficulty;

/// Built-in task catalog (compile-time, no allocation)
pub const BUILTIN_TASKS = [_]Task{
    // ── Math (7) ─────────────────────────────────────────────────────────
    .{
        .id = "math-001",
        .category = .math,
        .difficulty = .easy,
        .prompt = "What is 17 * 23? Show your work step by step.",
        .reference_answer = "391",
    },
    .{
        .id = "math-002",
        .category = .math,
        .difficulty = .easy,
        .prompt = "A store sells apples for $1.25 each. If Maria buys 8 apples and pays with a $20 bill, how much change does she get?",
        .reference_answer = "$10.00",
    },
    .{
        .id = "math-003",
        .category = .math,
        .difficulty = .medium,
        .prompt = "Find all integer solutions to x^2 - 5x + 6 = 0.",
        .reference_answer = "x = 2 and x = 3",
    },
    .{
        .id = "math-004",
        .category = .math,
        .difficulty = .medium,
        .prompt = "A train travels 120 km at 60 km/h, then 80 km at 40 km/h. What is the average speed for the entire trip?",
        .reference_answer = "50 km/h",
    },
    .{
        .id = "math-005",
        .category = .math,
        .difficulty = .medium,
        .prompt = "In how many ways can you arrange the letters in the word TRINITY?",
        .reference_answer = "2520",
    },
    .{
        .id = "math-006",
        .category = .math,
        .difficulty = .hard,
        .prompt = "Prove that for any positive integer n, the sum 1^3 + 2^3 + ... + n^3 = (n(n+1)/2)^2.",
        .reference_answer = null,
    },
    .{
        .id = "math-007",
        .category = .math,
        .difficulty = .hard,
        .prompt = "Let phi = (1 + sqrt(5)) / 2. Prove that phi^2 + 1/phi^2 = 3.",
        .reference_answer = "phi^2 = phi + 1, 1/phi^2 = 2 - phi, sum = 3",
    },

    // ── Coding (7) ───────────────────────────────────────────────────────
    .{
        .id = "code-001",
        .category = .coding,
        .difficulty = .easy,
        .prompt = "Write a function that checks if a string is a palindrome. Return true/false.",
        .reference_answer = null,
    },
    .{
        .id = "code-002",
        .category = .coding,
        .difficulty = .easy,
        .prompt = "Write a function that returns the Nth Fibonacci number (0-indexed). fib(0)=0, fib(1)=1.",
        .reference_answer = null,
    },
    .{
        .id = "code-003",
        .category = .coding,
        .difficulty = .medium,
        .prompt = "Write a function that finds the longest common subsequence of two strings. Return its length.",
        .reference_answer = null,
    },
    .{
        .id = "code-004",
        .category = .coding,
        .difficulty = .medium,
        .prompt = "Implement a function that converts a Roman numeral string to an integer. Handle I, V, X, L, C, D, M.",
        .reference_answer = null,
    },
    .{
        .id = "code-005",
        .category = .coding,
        .difficulty = .medium,
        .prompt = "Write a function that determines if a given 9x9 Sudoku board is valid. Empty cells are represented by '.'.",
        .reference_answer = null,
    },
    .{
        .id = "code-006",
        .category = .coding,
        .difficulty = .hard,
        .prompt = "Implement a basic calculator that evaluates expressions with +, -, *, /, and parentheses. Handle operator precedence correctly.",
        .reference_answer = null,
    },
    .{
        .id = "code-007",
        .category = .coding,
        .difficulty = .hard,
        .prompt = "Write a ternary (base-3 using {-1, 0, 1}) matrix multiplication function. Input: two 3x3 ternary matrices. Output: their product.",
        .reference_answer = null,
    },

    // ── Reasoning (6) ────────────────────────────────────────────────────
    .{
        .id = "reason-001",
        .category = .reasoning,
        .difficulty = .easy,
        .prompt = "Alice is taller than Bob. Bob is taller than Charlie. Is Alice taller than Charlie? Explain your reasoning.",
        .reference_answer = "Yes, by transitivity.",
    },
    .{
        .id = "reason-002",
        .category = .reasoning,
        .difficulty = .easy,
        .prompt = "A farmer has 15 sheep. All but 8 die. How many are left?",
        .reference_answer = "8",
    },
    .{
        .id = "reason-003",
        .category = .reasoning,
        .difficulty = .medium,
        .prompt = "You have 8 identical-looking balls. One is heavier. Using a balance scale, what is the minimum number of weighings needed to find the heavy ball? Explain your strategy.",
        .reference_answer = "2 weighings",
    },
    .{
        .id = "reason-004",
        .category = .reasoning,
        .difficulty = .medium,
        .prompt = "Three people check into a hotel room that costs $30. They each pay $10. The manager realizes the room is only $25 and gives $5 to the bellboy to return. The bellboy keeps $2 and gives $1 back to each person. Each person paid $9 (total $27), the bellboy has $2. That's $29. Where is the missing dollar?",
        .reference_answer = "The $27 includes the bellboy's $2. There is no missing dollar — the question frames the arithmetic incorrectly.",
    },
    .{
        .id = "reason-005",
        .category = .reasoning,
        .difficulty = .hard,
        .prompt = "A bat and a ball cost $1.10 together. The bat costs $1.00 more than the ball. How much does the ball cost? Think carefully before answering.",
        .reference_answer = "$0.05",
    },
    .{
        .id = "reason-006",
        .category = .reasoning,
        .difficulty = .hard,
        .prompt = "You are in a room with two doors. One leads to freedom, the other to death. There are two guards: one always tells the truth, one always lies. You can ask one question to one guard. What question do you ask to find the door to freedom?",
        .reference_answer = "Ask either guard: 'If I asked the other guard which door leads to freedom, what would they say?' Then choose the opposite door.",
    },
};

/// Find a task by ID
pub fn findTask(id: []const u8) ?Task {
    for (&BUILTIN_TASKS) |*task| {
        if (std.mem.eql(u8, task.id, id)) {
            return task.*;
        }
    }
    return null;
}

/// Get all tasks in a category
pub fn tasksByCategory(category: TaskCategory, buf: []Task) usize {
    var count: usize = 0;
    for (&BUILTIN_TASKS) |*task| {
        if (task.category == category and count < buf.len) {
            buf[count] = task.*;
            count += 1;
        }
    }
    return count;
}

/// Get all tasks at a difficulty level
pub fn tasksByDifficulty(difficulty: Difficulty, buf: []Task) usize {
    var count: usize = 0;
    for (&BUILTIN_TASKS) |*task| {
        if (task.difficulty == difficulty and count < buf.len) {
            buf[count] = task.*;
            count += 1;
        }
    }
    return count;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

test "catalog has 20 tasks" {
    try std.testing.expectEqual(@as(usize, 20), BUILTIN_TASKS.len);
}

test "find task by id" {
    const task = findTask("math-001");
    try std.testing.expect(task != null);
    try std.testing.expectEqual(TaskCategory.math, task.?.category);
}

test "find task returns null for unknown" {
    const task = findTask("nonexistent-999");
    try std.testing.expect(task == null);
}

test "tasks by category math" {
    var buf: [20]Task = undefined;
    const count = tasksByCategory(.math, &buf);
    try std.testing.expectEqual(@as(usize, 7), count);
}

test "tasks by category coding" {
    var buf: [20]Task = undefined;
    const count = tasksByCategory(.coding, &buf);
    try std.testing.expectEqual(@as(usize, 7), count);
}

test "tasks by category reasoning" {
    var buf: [20]Task = undefined;
    const count = tasksByCategory(.reasoning, &buf);
    try std.testing.expectEqual(@as(usize, 6), count);
}
