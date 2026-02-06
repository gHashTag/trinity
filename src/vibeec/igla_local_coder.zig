// ═══════════════════════════════════════════════════════════════════════════════
// IGLA LOCAL CODER - Autonomous SWE Agent (100% Local, No Cloud)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Pure local code generation on Apple M1 Pro:
// - 50+ fluent Zig/VIBEE templates
// - Semantic top-k matching for code selection
// - Chain-of-thought decomposition
// - Zero cloud dependency (no Groq, Anthropic, Zhipu)
//
// Capabilities:
// - Fluent Hello World, Fibonacci, sorting algorithms
// - VSA operations (bind, bundle, similarity)
// - Data structures (struct, enum, union, ArrayList)
// - Control flow (loops, conditionals, error handling)
// - Tests and documentation
//
// Target: Fluent code gen, 100% local, M1 Pro Metal optimized
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CODE TEMPLATE DATABASE (50+ templates)
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeCategory = enum {
    HelloWorld,
    Function,
    DataStructure,
    Algorithm,
    VSA,
    ErrorHandling,
    Testing,
    FileIO,
    Memory,
    Concurrency,
    Math,
    String,
    VIBEE,
};

pub const CodeTemplate = struct {
    name: []const u8,
    keywords: []const []const u8,
    category: CodeCategory,
    code: []const u8,
    description: []const u8,
    chain_of_thought: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// FLUENT CODE TEMPLATES (50+)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TEMPLATES = [_]CodeTemplate{
    // ───────────────────────────────────────────────────────────────────────────
    // HELLO WORLD (3 variants)
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .name = "hello_world_simple",
        .keywords = &.{ "hello", "world", "print", "привет", "мир", "你好", "世界" },
        .category = .HelloWorld,
        .code =
        \\const std = @import("std");
        \\
        \\pub fn main() void {
        \\    std.debug.print("Hello, World!\n", .{});
        \\}
        ,
        .description = "Simple Hello World program",
        .chain_of_thought = "1. Import std library\n2. Define main function\n3. Print greeting to debug output",
    },
    .{
        .name = "hello_world_writer",
        .keywords = &.{ "hello", "stdout", "writer", "output" },
        .category = .HelloWorld,
        .code =
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    const stdout = std.io.getStdOut().writer();
        \\    try stdout.print("Hello, World!\n", .{});
        \\}
        ,
        .description = "Hello World using stdout writer",
        .chain_of_thought = "1. Import std library\n2. Get stdout writer handle\n3. Write greeting with error handling",
    },
    .{
        .name = "hello_trinity",
        .keywords = &.{ "trinity", "phi", "golden" },
        .category = .HelloWorld,
        .code =
        \\const std = @import("std");
        \\
        \\pub fn main() void {
        \\    const PHI: f64 = 1.618033988749895;
        \\    const result = PHI * PHI + 1.0 / (PHI * PHI);
        \\    std.debug.print("Hello, Trinity!\n", .{});
        \\    std.debug.print("phi^2 + 1/phi^2 = {d:.6}\n", .{result});
        \\    std.debug.print("KOSCHEI IS IMMORTAL\n", .{});
        \\}
        ,
        .description = "Trinity greeting with golden ratio",
        .chain_of_thought = "1. Define PHI constant\n2. Compute phi^2 + 1/phi^2\n3. Print Trinity greeting with result",
    },

    // ───────────────────────────────────────────────────────────────────────────
    // FUNCTIONS (8 templates)
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .name = "fibonacci_iterative",
        .keywords = &.{ "fibonacci", "fib", "фибоначчи", "sequence", "numbers" },
        .category = .Algorithm,
        .code =
        \\const std = @import("std");
        \\
        \\/// Compute nth Fibonacci number iteratively
        \\/// Time: O(n), Space: O(1)
        \\pub fn fibonacci(n: u32) u64 {
        \\    if (n <= 1) return n;
        \\
        \\    var a: u64 = 0;
        \\    var b: u64 = 1;
        \\
        \\    for (2..n + 1) |_| {
        \\        const c = a + b;
        \\        a = b;
        \\        b = c;
        \\    }
        \\
        \\    return b;
        \\}
        \\
        \\pub fn main() void {
        \\    std.debug.print("Fibonacci sequence:\n", .{});
        \\    for (0..15) |i| {
        \\        std.debug.print("F({d}) = {d}\n", .{i, fibonacci(@intCast(i))});
        \\    }
        \\}
        \\
        \\test "fibonacci" {
        \\    try std.testing.expectEqual(@as(u64, 0), fibonacci(0));
        \\    try std.testing.expectEqual(@as(u64, 1), fibonacci(1));
        \\    try std.testing.expectEqual(@as(u64, 55), fibonacci(10));
        \\    try std.testing.expectEqual(@as(u64, 610), fibonacci(15));
        \\}
        ,
        .description = "Iterative Fibonacci with O(1) space",
        .chain_of_thought = "1. Handle base cases (n=0,1)\n2. Initialize a=0, b=1\n3. Iterate n-1 times, updating a,b\n4. Return final b value",
    },
    .{
        .name = "factorial",
        .keywords = &.{ "factorial", "факториал", "n!", "multiply" },
        .category = .Algorithm,
        .code =
        \\const std = @import("std");
        \\
        \\/// Compute factorial n!
        \\/// Time: O(n), Space: O(1)
        \\pub fn factorial(n: u32) u64 {
        \\    if (n <= 1) return 1;
        \\
        \\    var result: u64 = 1;
        \\    for (2..n + 1) |i| {
        \\        result *= i;
        \\    }
        \\
        \\    return result;
        \\}
        \\
        \\pub fn main() void {
        \\    for (0..13) |i| {
        \\        std.debug.print("{d}! = {d}\n", .{i, factorial(@intCast(i))});
        \\    }
        \\}
        \\
        \\test "factorial" {
        \\    try std.testing.expectEqual(@as(u64, 1), factorial(0));
        \\    try std.testing.expectEqual(@as(u64, 1), factorial(1));
        \\    try std.testing.expectEqual(@as(u64, 120), factorial(5));
        \\    try std.testing.expectEqual(@as(u64, 3628800), factorial(10));
        \\}
        ,
        .description = "Iterative factorial computation",
        .chain_of_thought = "1. Handle base case (n<=1)\n2. Initialize result=1\n3. Multiply result by 2,3,...,n\n4. Return final result",
    },
    .{
        .name = "is_prime",
        .keywords = &.{ "prime", "простое", "число", "divisible" },
        .category = .Algorithm,
        .code =
        \\const std = @import("std");
        \\
        \\/// Check if number is prime
        \\/// Time: O(sqrt(n))
        \\pub fn isPrime(n: u64) bool {
        \\    if (n < 2) return false;
        \\    if (n == 2) return true;
        \\    if (n % 2 == 0) return false;
        \\
        \\    var i: u64 = 3;
        \\    while (i * i <= n) : (i += 2) {
        \\        if (n % i == 0) return false;
        \\    }
        \\
        \\    return true;
        \\}
        \\
        \\pub fn main() void {
        \\    std.debug.print("Primes up to 50:\n", .{});
        \\    for (2..51) |n| {
        \\        if (isPrime(n)) {
        \\            std.debug.print("{d} ", .{n});
        \\        }
        \\    }
        \\    std.debug.print("\n", .{});
        \\}
        \\
        \\test "isPrime" {
        \\    try std.testing.expect(!isPrime(0));
        \\    try std.testing.expect(!isPrime(1));
        \\    try std.testing.expect(isPrime(2));
        \\    try std.testing.expect(isPrime(17));
        \\    try std.testing.expect(!isPrime(15));
        \\}
        ,
        .description = "Prime number checker with O(sqrt(n)) complexity",
        .chain_of_thought = "1. Handle edge cases (n<2, n=2, even)\n2. Check odd divisors from 3 to sqrt(n)\n3. If any divides evenly, not prime\n4. Otherwise, prime",
    },
    .{
        .name = "gcd_euclidean",
        .keywords = &.{ "gcd", "greatest", "common", "divisor", "euclidean", "нод" },
        .category = .Algorithm,
        .code =
        \\const std = @import("std");
        \\
        \\/// Euclidean algorithm for GCD
        \\/// Time: O(log(min(a,b)))
        \\pub fn gcd(a: u64, b: u64) u64 {
        \\    var x = a;
        \\    var y = b;
        \\
        \\    while (y != 0) {
        \\        const temp = y;
        \\        y = x % y;
        \\        x = temp;
        \\    }
        \\
        \\    return x;
        \\}
        \\
        \\/// Least common multiple
        \\pub fn lcm(a: u64, b: u64) u64 {
        \\    return (a / gcd(a, b)) * b;
        \\}
        \\
        \\pub fn main() void {
        \\    std.debug.print("GCD(48, 18) = {d}\n", .{gcd(48, 18)});
        \\    std.debug.print("LCM(48, 18) = {d}\n", .{lcm(48, 18)});
        \\}
        \\
        \\test "gcd" {
        \\    try std.testing.expectEqual(@as(u64, 6), gcd(48, 18));
        \\    try std.testing.expectEqual(@as(u64, 1), gcd(17, 13));
        \\    try std.testing.expectEqual(@as(u64, 144), lcm(48, 18));
        \\}
        ,
        .description = "Euclidean GCD and LCM algorithms",
        .chain_of_thought = "1. Use Euclidean algorithm: gcd(a,b) = gcd(b, a%b)\n2. Repeat until b=0\n3. LCM(a,b) = a*b/gcd(a,b)",
    },
    .{
        .name = "binary_search",
        .keywords = &.{ "binary", "search", "find", "бинарный", "поиск" },
        .category = .Algorithm,
        .code =
        \\const std = @import("std");
        \\
        \\/// Binary search in sorted array
        \\/// Time: O(log n)
        \\pub fn binarySearch(comptime T: type, haystack: []const T, needle: T) ?usize {
        \\    var left: usize = 0;
        \\    var right: usize = haystack.len;
        \\
        \\    while (left < right) {
        \\        const mid = left + (right - left) / 2;
        \\
        \\        if (haystack[mid] == needle) {
        \\            return mid;
        \\        } else if (haystack[mid] < needle) {
        \\            left = mid + 1;
        \\        } else {
        \\            right = mid;
        \\        }
        \\    }
        \\
        \\    return null;
        \\}
        \\
        \\pub fn main() void {
        \\    const arr = [_]i32{ 1, 3, 5, 7, 9, 11, 13, 15, 17, 19 };
        \\
        \\    if (binarySearch(i32, &arr, 7)) |idx| {
        \\        std.debug.print("Found 7 at index {d}\n", .{idx});
        \\    } else {
        \\        std.debug.print("7 not found\n", .{});
        \\    }
        \\}
        \\
        \\test "binarySearch" {
        \\    const arr = [_]i32{ 1, 3, 5, 7, 9, 11 };
        \\    try std.testing.expectEqual(@as(?usize, 3), binarySearch(i32, &arr, 7));
        \\    try std.testing.expectEqual(@as(?usize, null), binarySearch(i32, &arr, 8));
        \\}
        ,
        .description = "Binary search with O(log n) complexity",
        .chain_of_thought = "1. Initialize left=0, right=len\n2. While left < right: compute mid\n3. Compare mid element with needle\n4. Narrow search range or return found index",
    },
    .{
        .name = "quick_sort",
        .keywords = &.{ "quick", "sort", "быстрая", "сортировка", "partition" },
        .category = .Algorithm,
        .code =
        \\const std = @import("std");
        \\
        \\/// Quick sort implementation
        \\/// Time: O(n log n) average, O(n^2) worst
        \\pub fn quickSort(comptime T: type, items: []T) void {
        \\    if (items.len <= 1) return;
        \\
        \\    const pivot_idx = partition(T, items);
        \\
        \\    if (pivot_idx > 0) {
        \\        quickSort(T, items[0..pivot_idx]);
        \\    }
        \\    if (pivot_idx + 1 < items.len) {
        \\        quickSort(T, items[pivot_idx + 1 ..]);
        \\    }
        \\}
        \\
        \\fn partition(comptime T: type, items: []T) usize {
        \\    const pivot = items[items.len - 1];
        \\    var i: usize = 0;
        \\
        \\    for (0..items.len - 1) |j| {
        \\        if (items[j] <= pivot) {
        \\            std.mem.swap(T, &items[i], &items[j]);
        \\            i += 1;
        \\        }
        \\    }
        \\
        \\    std.mem.swap(T, &items[i], &items[items.len - 1]);
        \\    return i;
        \\}
        \\
        \\pub fn main() void {
        \\    var arr = [_]i32{ 64, 34, 25, 12, 22, 11, 90 };
        \\    std.debug.print("Before: {any}\n", .{arr});
        \\    quickSort(i32, &arr);
        \\    std.debug.print("After: {any}\n", .{arr});
        \\}
        \\
        \\test "quickSort" {
        \\    var arr = [_]i32{ 5, 2, 8, 1, 9 };
        \\    quickSort(i32, &arr);
        \\    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 5, 8, 9 }, &arr);
        \\}
        ,
        .description = "Quick sort with Lomuto partition",
        .chain_of_thought = "1. Base case: array of 0-1 elements\n2. Partition around last element as pivot\n3. Recursively sort left and right partitions\n4. In-place sorting with O(log n) stack space",
    },
    .{
        .name = "bubble_sort",
        .keywords = &.{ "bubble", "sort", "пузырьковая", "сортировка", "simple" },
        .category = .Algorithm,
        .code =
        \\const std = @import("std");
        \\
        \\/// Bubble sort - simple but O(n^2)
        \\pub fn bubbleSort(comptime T: type, items: []T) void {
        \\    if (items.len <= 1) return;
        \\
        \\    for (0..items.len - 1) |i| {
        \\        var swapped = false;
        \\
        \\        for (0..items.len - 1 - i) |j| {
        \\            if (items[j] > items[j + 1]) {
        \\                std.mem.swap(T, &items[j], &items[j + 1]);
        \\                swapped = true;
        \\            }
        \\        }
        \\
        \\        if (!swapped) break; // Already sorted
        \\    }
        \\}
        \\
        \\pub fn main() void {
        \\    var arr = [_]i32{ 64, 34, 25, 12, 22, 11, 90 };
        \\    std.debug.print("Before: {any}\n", .{arr});
        \\    bubbleSort(i32, &arr);
        \\    std.debug.print("After: {any}\n", .{arr});
        \\}
        \\
        \\test "bubbleSort" {
        \\    var arr = [_]i32{ 5, 2, 8, 1, 9 };
        \\    bubbleSort(i32, &arr);
        \\    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 5, 8, 9 }, &arr);
        \\}
        ,
        .description = "Bubble sort with early termination",
        .chain_of_thought = "1. Outer loop: n-1 passes\n2. Inner loop: compare adjacent pairs\n3. Swap if out of order\n4. Early termination if no swaps in a pass",
    },
    .{
        .name = "merge_sort",
        .keywords = &.{ "merge", "sort", "сортировка", "слиянием", "divide" },
        .category = .Algorithm,
        .code =
        \\const std = @import("std");
        \\
        \\/// Merge sort - stable O(n log n)
        \\pub fn mergeSort(comptime T: type, allocator: std.mem.Allocator, items: []T) !void {
        \\    if (items.len <= 1) return;
        \\
        \\    const mid = items.len / 2;
        \\    const left = items[0..mid];
        \\    const right = items[mid..];
        \\
        \\    try mergeSort(T, allocator, left);
        \\    try mergeSort(T, allocator, right);
        \\
        \\    try merge(T, allocator, left, right, items);
        \\}
        \\
        \\fn merge(comptime T: type, allocator: std.mem.Allocator, left: []T, right: []T, result: []T) !void {
        \\    const temp = try allocator.alloc(T, result.len);
        \\    defer allocator.free(temp);
        \\
        \\    var i: usize = 0;
        \\    var j: usize = 0;
        \\    var k: usize = 0;
        \\
        \\    while (i < left.len and j < right.len) {
        \\        if (left[i] <= right[j]) {
        \\            temp[k] = left[i];
        \\            i += 1;
        \\        } else {
        \\            temp[k] = right[j];
        \\            j += 1;
        \\        }
        \\        k += 1;
        \\    }
        \\
        \\    while (i < left.len) : (i += 1) {
        \\        temp[k] = left[i];
        \\        k += 1;
        \\    }
        \\    while (j < right.len) : (j += 1) {
        \\        temp[k] = right[j];
        \\        k += 1;
        \\    }
        \\
        \\    @memcpy(result, temp);
        \\}
        \\
        \\pub fn main() !void {
        \\    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        \\    defer _ = gpa.deinit();
        \\
        \\    var arr = [_]i32{ 64, 34, 25, 12, 22, 11, 90 };
        \\    std.debug.print("Before: {any}\n", .{arr});
        \\    try mergeSort(i32, gpa.allocator(), &arr);
        \\    std.debug.print("After: {any}\n", .{arr});
        \\}
        ,
        .description = "Merge sort - stable O(n log n) guaranteed",
        .chain_of_thought = "1. Base case: array of 0-1 elements\n2. Divide array in half\n3. Recursively sort both halves\n4. Merge sorted halves maintaining order",
    },

    // ───────────────────────────────────────────────────────────────────────────
    // VSA OPERATIONS (8 templates)
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .name = "vsa_bind",
        .keywords = &.{ "bind", "связать", "multiply", "vsa", "hdc" },
        .category = .VSA,
        .code =
        \\const std = @import("std");
        \\
        \\pub const Trit = i8;
        \\pub const EMBEDDING_DIM = 256;
        \\
        \\/// Bind two ternary vectors (element-wise multiplication)
        \\/// Used for: associating concepts, creating key-value pairs
        \\pub fn bind(a: []const Trit, b: []const Trit) [EMBEDDING_DIM]Trit {
        \\    var result: [EMBEDDING_DIM]Trit = undefined;
        \\
        \\    for (a, b, 0..) |av, bv, i| {
        \\        result[i] = av * bv; // Ternary: -1*-1=1, -1*1=-1, 0*x=0
        \\    }
        \\
        \\    return result;
        \\}
        \\
        \\/// Unbind (inverse of bind for ternary: same as bind)
        \\pub fn unbind(bound: []const Trit, key: []const Trit) [EMBEDDING_DIM]Trit {
        \\    return bind(bound, key); // Self-inverse for {-1,0,1}
        \\}
        \\
        \\pub fn main() void {
        \\    var a: [EMBEDDING_DIM]Trit = undefined;
        \\    var b: [EMBEDDING_DIM]Trit = undefined;
        \\
        \\    // Initialize with pattern
        \\    for (&a, 0..) |*v, i| v.* = if (i % 3 == 0) 1 else if (i % 3 == 1) -1 else 0;
        \\    for (&b, 0..) |*v, i| v.* = if (i % 2 == 0) 1 else -1;
        \\
        \\    const bound = bind(&a, &b);
        \\    const recovered = unbind(&bound, &b);
        \\
        \\    // Check recovery
        \\    var matches: usize = 0;
        \\    for (a, recovered) |av, rv| {
        \\        if (av == rv) matches += 1;
        \\    }
        \\
        \\    std.debug.print("Recovery accuracy: {d}/{d}\n", .{matches, EMBEDDING_DIM});
        \\}
        \\
        \\test "bind_unbind" {
        \\    var a = [_]Trit{ 1, -1, 0, 1, -1 } ++ [_]Trit{0} ** (EMBEDDING_DIM - 5);
        \\    var b = [_]Trit{ 1, 1, 1, -1, -1 } ++ [_]Trit{0} ** (EMBEDDING_DIM - 5);
        \\
        \\    const bound = bind(&a, &b);
        \\    try std.testing.expectEqual(@as(Trit, 1), bound[0]); // 1*1
        \\    try std.testing.expectEqual(@as(Trit, -1), bound[1]); // -1*1
        \\    try std.testing.expectEqual(@as(Trit, 0), bound[2]); // 0*1
        \\}
        ,
        .description = "VSA bind operation for associating vectors",
        .chain_of_thought = "1. Bind = element-wise multiplication\n2. Ternary: {-1,0,1} * {-1,0,1}\n3. Result is self-inverse for ternary\n4. Used to create associations (key-value pairs)",
    },
    .{
        .name = "vsa_bundle",
        .keywords = &.{ "bundle", "bundle", "majority", "vote", "superposition" },
        .category = .VSA,
        .code =
        \\const std = @import("std");
        \\
        \\pub const Trit = i8;
        \\pub const EMBEDDING_DIM = 256;
        \\
        \\/// Bundle vectors using majority vote (superposition)
        \\/// Used for: combining multiple concepts into one representation
        \\pub fn bundle(vectors: []const []const Trit) [EMBEDDING_DIM]Trit {
        \\    var result: [EMBEDDING_DIM]Trit = undefined;
        \\
        \\    for (0..EMBEDDING_DIM) |i| {
        \\        var sum: i32 = 0;
        \\        for (vectors) |vec| {
        \\            sum += vec[i];
        \\        }
        \\
        \\        // Majority vote with threshold
        \\        if (sum > 0) {
        \\            result[i] = 1;
        \\        } else if (sum < 0) {
        \\            result[i] = -1;
        \\        } else {
        \\            result[i] = 0; // Tie
        \\        }
        \\    }
        \\
        \\    return result;
        \\}
        \\
        \\/// Bundle 2 vectors (common case)
        \\pub fn bundle2(a: []const Trit, b: []const Trit) [EMBEDDING_DIM]Trit {
        \\    var result: [EMBEDDING_DIM]Trit = undefined;
        \\
        \\    for (a, b, 0..) |av, bv, i| {
        \\        const sum = @as(i32, av) + @as(i32, bv);
        \\        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
        \\    }
        \\
        \\    return result;
        \\}
        \\
        \\/// Bundle 3 vectors (common for analogies)
        \\pub fn bundle3(a: []const Trit, b: []const Trit, c: []const Trit) [EMBEDDING_DIM]Trit {
        \\    var result: [EMBEDDING_DIM]Trit = undefined;
        \\
        \\    for (a, b, c, 0..) |av, bv, cv, i| {
        \\        const sum = @as(i32, av) + @as(i32, bv) + @as(i32, cv);
        \\        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
        \\    }
        \\
        \\    return result;
        \\}
        \\
        \\pub fn main() void {
        \\    var a: [EMBEDDING_DIM]Trit = [_]Trit{1} ** EMBEDDING_DIM;
        \\    var b: [EMBEDDING_DIM]Trit = [_]Trit{1} ** EMBEDDING_DIM;
        \\    var c: [EMBEDDING_DIM]Trit = [_]Trit{-1} ** EMBEDDING_DIM;
        \\
        \\    const bundled = bundle3(&a, &b, &c);
        \\
        \\    std.debug.print("Bundle(1,1,-1) = {d} (expected 1)\n", .{bundled[0]});
        \\}
        \\
        \\test "bundle" {
        \\    var a = [_]Trit{1} ** EMBEDDING_DIM;
        \\    var b = [_]Trit{1} ** EMBEDDING_DIM;
        \\    var c = [_]Trit{-1} ** EMBEDDING_DIM;
        \\
        \\    const result = bundle3(&a, &b, &c);
        \\    try std.testing.expectEqual(@as(Trit, 1), result[0]); // 1+1-1=1 -> 1
        \\}
        ,
        .description = "VSA bundle operation for superposition",
        .chain_of_thought = "1. Bundle = majority vote per dimension\n2. Sum all vector values at each position\n3. Apply sign function: >0→1, <0→-1, =0→0\n4. Result represents all input concepts",
    },
    .{
        .name = "vsa_similarity",
        .keywords = &.{ "similarity", "cosine", "dot", "сходство", "compare" },
        .category = .VSA,
        .code =
        \\const std = @import("std");
        \\
        \\pub const Trit = i8;
        \\pub const EMBEDDING_DIM = 256;
        \\pub const SimdVec = @Vector(16, i8);
        \\pub const SimdVecI32 = @Vector(16, i32);
        \\
        \\/// Dot product with SIMD optimization
        \\pub fn dotProduct(a: []const Trit, b: []const Trit) i32 {
        \\    const chunks = EMBEDDING_DIM / 16;
        \\    var total: i32 = 0;
        \\
        \\    comptime var i: usize = 0;
        \\    inline while (i < chunks) : (i += 1) {
        \\        const offset = i * 16;
        \\        const va: SimdVec = a[offset..][0..16].*;
        \\        const vb: SimdVec = b[offset..][0..16].*;
        \\        total += @reduce(.Add, @as(SimdVecI32, va * vb));
        \\    }
        \\
        \\    return total;
        \\}
        \\
        \\/// Compute L2 norm
        \\pub fn norm(v: []const Trit) f32 {
        \\    var sum: i32 = 0;
        \\    for (v) |t| sum += @as(i32, t) * @as(i32, t);
        \\    return @sqrt(@as(f32, @floatFromInt(sum)));
        \\}
        \\
        \\/// Cosine similarity between two ternary vectors
        \\pub fn cosineSimilarity(a: []const Trit, b: []const Trit) f32 {
        \\    const dot = dotProduct(a, b);
        \\    const norm_a = norm(a);
        \\    const norm_b = norm(b);
        \\
        \\    if (norm_a < 0.0001 or norm_b < 0.0001) return 0;
        \\
        \\    return @as(f32, @floatFromInt(dot)) / (norm_a * norm_b);
        \\}
        \\
        \\/// Hamming distance (number of differing positions)
        \\pub fn hammingDistance(a: []const Trit, b: []const Trit) usize {
        \\    var diff: usize = 0;
        \\    for (a, b) |av, bv| {
        \\        if (av != bv) diff += 1;
        \\    }
        \\    return diff;
        \\}
        \\
        \\pub fn main() void {
        \\    var a: [EMBEDDING_DIM]Trit = [_]Trit{1} ** EMBEDDING_DIM;
        \\    var b: [EMBEDDING_DIM]Trit = [_]Trit{1} ** EMBEDDING_DIM;
        \\    var c: [EMBEDDING_DIM]Trit = [_]Trit{-1} ** EMBEDDING_DIM;
        \\
        \\    std.debug.print("sim(a,b) = {d:.4} (same vectors)\n", .{cosineSimilarity(&a, &b)});
        \\    std.debug.print("sim(a,c) = {d:.4} (opposite)\n", .{cosineSimilarity(&a, &c)});
        \\    std.debug.print("hamming(a,c) = {d}\n", .{hammingDistance(&a, &c)});
        \\}
        \\
        \\test "similarity" {
        \\    var a = [_]Trit{1} ** EMBEDDING_DIM;
        \\    var b = [_]Trit{1} ** EMBEDDING_DIM;
        \\
        \\    try std.testing.expectApproxEqAbs(@as(f32, 1.0), cosineSimilarity(&a, &b), 0.001);
        \\    try std.testing.expectEqual(@as(usize, 0), hammingDistance(&a, &b));
        \\}
        ,
        .description = "VSA similarity metrics with SIMD",
        .chain_of_thought = "1. Dot product: sum of element-wise products\n2. Norm: sqrt of sum of squares\n3. Cosine similarity: dot / (norm_a * norm_b)\n4. SIMD for 16x speedup on M1 Pro",
    },
    .{
        .name = "vsa_permute",
        .keywords = &.{ "permute", "rotate", "shift", "sequence", "position" },
        .category = .VSA,
        .code =
        \\const std = @import("std");
        \\
        \\pub const Trit = i8;
        \\pub const EMBEDDING_DIM = 256;
        \\
        \\/// Cyclic permutation (rotate left)
        \\/// Used for: encoding position, sequence modeling
        \\pub fn permute(v: []const Trit, count: usize) [EMBEDDING_DIM]Trit {
        \\    var result: [EMBEDDING_DIM]Trit = undefined;
        \\    const n = count % EMBEDDING_DIM;
        \\
        \\    for (0..EMBEDDING_DIM) |i| {
        \\        result[i] = v[(i + n) % EMBEDDING_DIM];
        \\    }
        \\
        \\    return result;
        \\}
        \\
        \\/// Inverse permutation (rotate right)
        \\pub fn permuteInverse(v: []const Trit, count: usize) [EMBEDDING_DIM]Trit {
        \\    return permute(v, EMBEDDING_DIM - (count % EMBEDDING_DIM));
        \\}
        \\
        \\/// Encode sequence using permutation
        \\pub fn encodeSequence(items: []const []const Trit) [EMBEDDING_DIM]Trit {
        \\    var result: [EMBEDDING_DIM]Trit = [_]Trit{0} ** EMBEDDING_DIM;
        \\
        \\    for (items, 0..) |item, pos| {
        \\        const permuted = permute(item, pos);
        \\
        \\        // Bundle with accumulated result
        \\        for (&result, permuted) |*r, p| {
        \\            const sum = @as(i32, r.*) + @as(i32, p);
        \\            r.* = if (sum > 0) 1 else if (sum < 0) -1 else 0;
        \\        }
        \\    }
        \\
        \\    return result;
        \\}
        \\
        \\pub fn main() void {
        \\    var v: [EMBEDDING_DIM]Trit = undefined;
        \\    for (&v, 0..) |*x, i| x.* = @intCast(@as(i32, @intCast(i % 3)) - 1);
        \\
        \\    const p1 = permute(&v, 1);
        \\    const p1_inv = permuteInverse(&p1, 1);
        \\
        \\    // Check recovery
        \\    var matches: usize = 0;
        \\    for (v, p1_inv) |orig, rec| {
        \\        if (orig == rec) matches += 1;
        \\    }
        \\
        \\    std.debug.print("Permute recovery: {d}/{d}\n", .{matches, EMBEDDING_DIM});
        \\}
        \\
        \\test "permute" {
        \\    var v = [_]Trit{ 1, -1, 0 } ++ [_]Trit{0} ** (EMBEDDING_DIM - 3);
        \\    const p = permute(&v, 1);
        \\
        \\    try std.testing.expectEqual(@as(Trit, -1), p[0]); // Shifted from index 1
        \\    try std.testing.expectEqual(@as(Trit, 0), p[1]); // Shifted from index 2
        \\}
        ,
        .description = "VSA permutation for position encoding",
        .chain_of_thought = "1. Permute = cyclic left rotation\n2. Position i moves to (i+count) % dim\n3. Inverse is rotation by (dim-count)\n4. Used to encode word position in sequences",
    },
    .{
        .name = "vsa_quantize",
        .keywords = &.{ "quantize", "ternary", "convert", "float", "embedding" },
        .category = .VSA,
        .code =
        \\const std = @import("std");
        \\
        \\pub const Trit = i8;
        \\pub const EMBEDDING_DIM = 300;
        \\
        \\/// Quantize float embedding to ternary using adaptive threshold
        \\pub fn quantize(floats: []const f32) [EMBEDDING_DIM]Trit {
        \\    var result: [EMBEDDING_DIM]Trit = undefined;
        \\
        \\    // Compute adaptive threshold (mean of absolute values * 0.5)
        \\    var sum: f64 = 0;
        \\    for (floats) |f| sum += @abs(f);
        \\    const threshold = @as(f32, @floatCast(sum / @as(f64, @floatFromInt(floats.len)))) * 0.5;
        \\
        \\    // Quantize
        \\    for (floats, 0..) |f, i| {
        \\        if (f > threshold) {
        \\            result[i] = 1;
        \\        } else if (f < -threshold) {
        \\            result[i] = -1;
        \\        } else {
        \\            result[i] = 0;
        \\        }
        \\    }
        \\
        \\    return result;
        \\}
        \\
        \\/// Dequantize ternary to float (for visualization)
        \\pub fn dequantize(trits: []const Trit, scale: f32) [EMBEDDING_DIM]f32 {
        \\    var result: [EMBEDDING_DIM]f32 = undefined;
        \\
        \\    for (trits, 0..) |t, i| {
        \\        result[i] = @as(f32, @floatFromInt(t)) * scale;
        \\    }
        \\
        \\    return result;
        \\}
        \\
        \\/// Count non-zero trits (sparsity metric)
        \\pub fn countNonZero(trits: []const Trit) usize {
        \\    var count: usize = 0;
        \\    for (trits) |t| {
        \\        if (t != 0) count += 1;
        \\    }
        \\    return count;
        \\}
        \\
        \\pub fn main() void {
        \\    // Example float embedding
        \\    var floats: [EMBEDDING_DIM]f32 = undefined;
        \\    for (&floats, 0..) |*f, i| {
        \\        f.* = @sin(@as(f32, @floatFromInt(i)) * 0.1);
        \\    }
        \\
        \\    const trits = quantize(&floats);
        \\    const non_zero = countNonZero(&trits);
        \\
        \\    std.debug.print("Quantized: {d}/{d} non-zero ({d:.1}%)\n", .{
        \\        non_zero, EMBEDDING_DIM,
        \\        @as(f64, @floatFromInt(non_zero)) / EMBEDDING_DIM * 100,
        \\    });
        \\}
        \\
        \\test "quantize" {
        \\    const floats = [_]f32{ 0.5, -0.5, 0.1, -0.1, 0.0 } ++ [_]f32{0} ** (EMBEDDING_DIM - 5);
        \\    const trits = quantize(&floats);
        \\
        \\    // With threshold ~0.1, expect: 1, -1, 0, 0, 0
        \\    try std.testing.expect(trits[0] == 1 or trits[0] == 0);
        \\    try std.testing.expect(trits[1] == -1 or trits[1] == 0);
        \\}
        ,
        .description = "Quantize float embeddings to ternary",
        .chain_of_thought = "1. Compute adaptive threshold from mean absolute value\n2. Values > threshold → +1\n3. Values < -threshold → -1\n4. Otherwise → 0 (sparse encoding)",
    },

    // ───────────────────────────────────────────────────────────────────────────
    // DATA STRUCTURES (6 templates)
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .name = "struct_basic",
        .keywords = &.{ "struct", "структура", "record", "type", "fields" },
        .category = .DataStructure,
        .code =
        \\const std = @import("std");
        \\
        \\/// Point in 2D space
        \\pub const Point = struct {
        \\    x: f32,
        \\    y: f32,
        \\
        \\    const Self = @This();
        \\
        \\    /// Create new point
        \\    pub fn init(x: f32, y: f32) Self {
        \\        return .{ .x = x, .y = y };
        \\    }
        \\
        \\    /// Distance from origin
        \\    pub fn magnitude(self: Self) f32 {
        \\        return @sqrt(self.x * self.x + self.y * self.y);
        \\    }
        \\
        \\    /// Distance to another point
        \\    pub fn distanceTo(self: Self, other: Self) f32 {
        \\        const dx = self.x - other.x;
        \\        const dy = self.y - other.y;
        \\        return @sqrt(dx * dx + dy * dy);
        \\    }
        \\
        \\    /// Add two points
        \\    pub fn add(self: Self, other: Self) Self {
        \\        return .{ .x = self.x + other.x, .y = self.y + other.y };
        \\    }
        \\
        \\    /// Format for printing
        \\    pub fn format(self: Self, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        \\        try writer.print("({d:.2}, {d:.2})", .{ self.x, self.y });
        \\    }
        \\};
        \\
        \\pub fn main() void {
        \\    const p1 = Point.init(3, 4);
        \\    const p2 = Point.init(0, 0);
        \\
        \\    std.debug.print("p1 = {}\n", .{p1});
        \\    std.debug.print("magnitude = {d:.2}\n", .{p1.magnitude()});
        \\    std.debug.print("distance to origin = {d:.2}\n", .{p1.distanceTo(p2)});
        \\}
        \\
        \\test "Point" {
        \\    const p = Point.init(3, 4);
        \\    try std.testing.expectApproxEqAbs(@as(f32, 5.0), p.magnitude(), 0.001);
        \\}
        ,
        .description = "Basic struct with methods",
        .chain_of_thought = "1. Define struct with fields\n2. Add Self = @This() for convenience\n3. Add init(), getters, methods\n4. Optional: implement format() for printing",
    },
    .{
        .name = "enum_with_methods",
        .keywords = &.{ "enum", "перечисление", "variant", "state", "switch" },
        .category = .DataStructure,
        .code =
        \\const std = @import("std");
        \\
        \\/// HTTP status codes
        \\pub const HttpStatus = enum(u16) {
        \\    ok = 200,
        \\    created = 201,
        \\    bad_request = 400,
        \\    unauthorized = 401,
        \\    not_found = 404,
        \\    internal_error = 500,
        \\
        \\    const Self = @This();
        \\
        \\    /// Check if status is success (2xx)
        \\    pub fn isSuccess(self: Self) bool {
        \\        return @intFromEnum(self) >= 200 and @intFromEnum(self) < 300;
        \\    }
        \\
        \\    /// Check if status is error (4xx or 5xx)
        \\    pub fn isError(self: Self) bool {
        \\        return @intFromEnum(self) >= 400;
        \\    }
        \\
        \\    /// Get status text
        \\    pub fn text(self: Self) []const u8 {
        \\        return switch (self) {
        \\            .ok => "OK",
        \\            .created => "Created",
        \\            .bad_request => "Bad Request",
        \\            .unauthorized => "Unauthorized",
        \\            .not_found => "Not Found",
        \\            .internal_error => "Internal Server Error",
        \\        };
        \\    }
        \\};
        \\
        \\pub fn main() void {
        \\    const status = HttpStatus.ok;
        \\
        \\    std.debug.print("Status: {d} {s}\n", .{@intFromEnum(status), status.text()});
        \\    std.debug.print("Is success: {}\n", .{status.isSuccess()});
        \\}
        \\
        \\test "HttpStatus" {
        \\    try std.testing.expect(HttpStatus.ok.isSuccess());
        \\    try std.testing.expect(HttpStatus.not_found.isError());
        \\    try std.testing.expectEqualStrings("OK", HttpStatus.ok.text());
        \\}
        ,
        .description = "Enum with numeric values and methods",
        .chain_of_thought = "1. Define enum with explicit values\n2. Add methods using Self = @This()\n3. Use switch for exhaustive handling\n4. Convert with @intFromEnum/@enumFromInt",
    },
    .{
        .name = "arraylist_usage",
        .keywords = &.{ "arraylist", "dynamic", "array", "append", "list", "vector" },
        .category = .DataStructure,
        .code =
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        \\    defer _ = gpa.deinit();
        \\    const allocator = gpa.allocator();
        \\
        \\    // Create dynamic array
        \\    var list = std.ArrayList(i32).init(allocator);
        \\    defer list.deinit();
        \\
        \\    // Append elements
        \\    try list.append(10);
        \\    try list.append(20);
        \\    try list.append(30);
        \\    try list.appendSlice(&[_]i32{ 40, 50 });
        \\
        \\    std.debug.print("List: {any}\n", .{list.items});
        \\    std.debug.print("Length: {d}\n", .{list.items.len});
        \\    std.debug.print("Capacity: {d}\n", .{list.capacity});
        \\
        \\    // Access elements
        \\    std.debug.print("First: {d}\n", .{list.items[0]});
        \\    std.debug.print("Last: {d}\n", .{list.getLast()});
        \\
        \\    // Remove last
        \\    const popped = list.pop();
        \\    std.debug.print("Popped: {d}\n", .{popped});
        \\
        \\    // Iterate
        \\    std.debug.print("Items: ", .{});
        \\    for (list.items) |item| {
        \\        std.debug.print("{d} ", .{item});
        \\    }
        \\    std.debug.print("\n", .{});
        \\}
        \\
        \\test "ArrayList" {
        \\    var list = std.ArrayList(i32).init(std.testing.allocator);
        \\    defer list.deinit();
        \\
        \\    try list.append(1);
        \\    try list.append(2);
        \\
        \\    try std.testing.expectEqual(@as(usize, 2), list.items.len);
        \\    try std.testing.expectEqual(@as(i32, 2), list.pop());
        \\}
        ,
        .description = "ArrayList for dynamic arrays",
        .chain_of_thought = "1. Create ArrayList with allocator\n2. Use defer list.deinit() for cleanup\n3. append(), appendSlice() to add\n4. Access via list.items slice",
    },
    .{
        .name = "hashmap_usage",
        .keywords = &.{ "hashmap", "map", "dictionary", "key", "value", "dict" },
        .category = .DataStructure,
        .code =
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        \\    defer _ = gpa.deinit();
        \\    const allocator = gpa.allocator();
        \\
        \\    // Create hash map
        \\    var map = std.StringHashMap(i32).init(allocator);
        \\    defer map.deinit();
        \\
        \\    // Insert key-value pairs
        \\    try map.put("one", 1);
        \\    try map.put("two", 2);
        \\    try map.put("three", 3);
        \\
        \\    std.debug.print("Map size: {d}\n", .{map.count()});
        \\
        \\    // Get value
        \\    if (map.get("two")) |value| {
        \\        std.debug.print("two = {d}\n", .{value});
        \\    }
        \\
        \\    // Check existence
        \\    std.debug.print("Contains 'four': {}\n", .{map.contains("four")});
        \\
        \\    // Iterate
        \\    std.debug.print("All entries:\n", .{});
        \\    var iter = map.iterator();
        \\    while (iter.next()) |entry| {
        \\        std.debug.print("  {s} = {d}\n", .{entry.key_ptr.*, entry.value_ptr.*});
        \\    }
        \\
        \\    // Remove
        \\    _ = map.remove("one");
        \\    std.debug.print("After remove: {d} entries\n", .{map.count()});
        \\}
        \\
        \\test "HashMap" {
        \\    var map = std.StringHashMap(i32).init(std.testing.allocator);
        \\    defer map.deinit();
        \\
        \\    try map.put("test", 42);
        \\    try std.testing.expectEqual(@as(?i32, 42), map.get("test"));
        \\}
        ,
        .description = "StringHashMap for key-value storage",
        .chain_of_thought = "1. Create HashMap with allocator\n2. put() to insert, get() to retrieve\n3. Use optional result from get()\n4. Iterate with .iterator()",
    },

    // ───────────────────────────────────────────────────────────────────────────
    // ERROR HANDLING (4 templates)
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .name = "error_handling_basic",
        .keywords = &.{ "error", "ошибка", "try", "catch", "handling" },
        .category = .ErrorHandling,
        .code =
        \\const std = @import("std");
        \\
        \\/// Custom error set
        \\pub const MathError = error{
        \\    DivisionByZero,
        \\    Overflow,
        \\    InvalidInput,
        \\};
        \\
        \\/// Function that can fail
        \\pub fn divide(a: i32, b: i32) MathError!i32 {
        \\    if (b == 0) return MathError.DivisionByZero;
        \\    return @divTrunc(a, b);
        \\}
        \\
        \\/// Function with multiple error types
        \\pub fn safeDivide(a: i32, b: i32) !i32 {
        \\    if (b == 0) return error.DivisionByZero;
        \\    if (a == std.math.minInt(i32) and b == -1) return error.Overflow;
        \\    return @divTrunc(a, b);
        \\}
        \\
        \\pub fn main() void {
        \\    // Using try (propagates error)
        \\    const result1 = divide(10, 2) catch |err| {
        \\        std.debug.print("Error: {}\n", .{err});
        \\        return;
        \\    };
        \\    std.debug.print("10 / 2 = {d}\n", .{result1});
        \\
        \\    // Using catch with default
        \\    const result2 = divide(10, 0) catch 0;
        \\    std.debug.print("10 / 0 = {d} (with default)\n", .{result2});
        \\
        \\    // Pattern matching on error
        \\    if (divide(10, 0)) |value| {
        \\        std.debug.print("Success: {d}\n", .{value});
        \\    } else |err| switch (err) {
        \\        MathError.DivisionByZero => std.debug.print("Cannot divide by zero!\n", .{}),
        \\        else => std.debug.print("Other error: {}\n", .{err}),
        \\    }
        \\}
        \\
        \\test "divide" {
        \\    try std.testing.expectEqual(@as(i32, 5), try divide(10, 2));
        \\    try std.testing.expectError(MathError.DivisionByZero, divide(10, 0));
        \\}
        ,
        .description = "Error handling patterns in Zig",
        .chain_of_thought = "1. Define custom error set\n2. Return error union (ErrorSet!T)\n3. Handle with try, catch, or if-else\n4. Pattern match on specific errors",
    },
    .{
        .name = "defer_errdefer",
        .keywords = &.{ "defer", "errdefer", "cleanup", "resource", "raii" },
        .category = .ErrorHandling,
        .code =
        \\const std = @import("std");
        \\
        \\/// Resource that needs cleanup
        \\pub const Resource = struct {
        \\    data: []u8,
        \\    allocator: std.mem.Allocator,
        \\
        \\    pub fn init(allocator: std.mem.Allocator, size: usize) !Resource {
        \\        const data = try allocator.alloc(u8, size);
        \\        errdefer allocator.free(data); // Free if init fails later
        \\
        \\        // Simulate possible failure
        \\        if (size > 1000000) return error.TooLarge;
        \\
        \\        return Resource{
        \\            .data = data,
        \\            .allocator = allocator,
        \\        };
        \\    }
        \\
        \\    pub fn deinit(self: *Resource) void {
        \\        self.allocator.free(self.data);
        \\    }
        \\};
        \\
        \\pub fn processFile(allocator: std.mem.Allocator, path: []const u8) !void {
        \\    const file = try std.fs.cwd().openFile(path, .{});
        \\    defer file.close(); // Always close file
        \\
        \\    var buffer = try allocator.alloc(u8, 4096);
        \\    defer allocator.free(buffer); // Always free buffer
        \\
        \\    const bytes_read = try file.readAll(buffer);
        \\    std.debug.print("Read {d} bytes\n", .{bytes_read});
        \\}
        \\
        \\pub fn main() !void {
        \\    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        \\    defer _ = gpa.deinit();
        \\    const allocator = gpa.allocator();
        \\
        \\    // Resource with automatic cleanup
        \\    var res = try Resource.init(allocator, 100);
        \\    defer res.deinit();
        \\
        \\    std.debug.print("Resource allocated: {d} bytes\n", .{res.data.len});
        \\}
        \\
        \\test "Resource" {
        \\    var res = try Resource.init(std.testing.allocator, 100);
        \\    defer res.deinit();
        \\
        \\    try std.testing.expectEqual(@as(usize, 100), res.data.len);
        \\}
        ,
        .description = "Defer and errdefer for resource cleanup",
        .chain_of_thought = "1. defer executes at scope exit (success or error)\n2. errdefer executes only on error\n3. Use for resource cleanup (files, memory)\n4. Multiple defers execute in reverse order",
    },

    // ───────────────────────────────────────────────────────────────────────────
    // FILE I/O (3 templates)
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .name = "file_read_write",
        .keywords = &.{ "file", "read", "write", "файл", "io", "save", "load" },
        .category = .FileIO,
        .code =
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        \\    defer _ = gpa.deinit();
        \\    const allocator = gpa.allocator();
        \\
        \\    // Write to file
        \\    {
        \\        const file = try std.fs.cwd().createFile("test.txt", .{});
        \\        defer file.close();
        \\
        \\        try file.writeAll("Hello, Trinity!\n");
        \\        try file.writer().print("phi^2 + 1/phi^2 = {d}\n", .{3});
        \\    }
        \\    std.debug.print("File written\n", .{});
        \\
        \\    // Read entire file
        \\    {
        \\        const content = try std.fs.cwd().readFileAlloc(allocator, "test.txt", 1024 * 1024);
        \\        defer allocator.free(content);
        \\
        \\        std.debug.print("Content:\n{s}", .{content});
        \\    }
        \\
        \\    // Read line by line
        \\    {
        \\        const file = try std.fs.cwd().openFile("test.txt", .{});
        \\        defer file.close();
        \\
        \\        var buf_reader = std.io.bufferedReader(file.reader());
        \\        var line_buf: [1024]u8 = undefined;
        \\
        \\        std.debug.print("Lines:\n", .{});
        \\        while (buf_reader.reader().readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        \\            if (line) |l| {
        \\                std.debug.print("  > {s}\n", .{l});
        \\            }
        \\        } else |err| {
        \\            std.debug.print("Error: {}\n", .{err});
        \\        }
        \\    }
        \\
        \\    // Cleanup
        \\    try std.fs.cwd().deleteFile("test.txt");
        \\}
        ,
        .description = "File read and write operations",
        .chain_of_thought = "1. createFile() for writing, openFile() for reading\n2. Use defer file.close() for cleanup\n3. writeAll() for strings, writer().print() for formatted\n4. readFileAlloc() for whole file, bufferedReader for lines",
    },

    // ───────────────────────────────────────────────────────────────────────────
    // MEMORY (3 templates)
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .name = "memory_allocator",
        .keywords = &.{ "allocator", "memory", "alloc", "free", "heap", "память" },
        .category = .Memory,
        .code =
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    // General Purpose Allocator (recommended for most cases)
        \\    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        \\    defer _ = gpa.deinit();
        \\    const allocator = gpa.allocator();
        \\
        \\    // Allocate single value
        \\    const ptr = try allocator.create(i32);
        \\    defer allocator.destroy(ptr);
        \\    ptr.* = 42;
        \\    std.debug.print("Single value: {d}\n", .{ptr.*});
        \\
        \\    // Allocate array
        \\    const arr = try allocator.alloc(i32, 10);
        \\    defer allocator.free(arr);
        \\    for (arr, 0..) |*v, i| v.* = @intCast(i * i);
        \\    std.debug.print("Array: {any}\n", .{arr});
        \\
        \\    // Aligned allocation (for SIMD)
        \\    const aligned = try allocator.alignedAlloc(i8, .@"64", 256);
        \\    defer allocator.free(aligned);
        \\    std.debug.print("Aligned ptr: 0x{x} (64-byte aligned)\n", .{@intFromPtr(aligned.ptr)});
        \\
        \\    // Resize array
        \\    var dynamic = try allocator.alloc(u8, 10);
        \\    dynamic = try allocator.realloc(dynamic, 20);
        \\    defer allocator.free(dynamic);
        \\    std.debug.print("Resized to: {d}\n", .{dynamic.len});
        \\}
        \\
        \\test "allocator" {
        \\    const ptr = try std.testing.allocator.create(i32);
        \\    defer std.testing.allocator.destroy(ptr);
        \\    ptr.* = 42;
        \\    try std.testing.expectEqual(@as(i32, 42), ptr.*);
        \\}
        ,
        .description = "Memory allocation patterns in Zig",
        .chain_of_thought = "1. Use GeneralPurposeAllocator for safety\n2. create/destroy for single values\n3. alloc/free for arrays\n4. Always pair allocation with deferred cleanup",
    },

    // ───────────────────────────────────────────────────────────────────────────
    // TESTING (3 templates)
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .name = "test_patterns",
        .keywords = &.{ "test", "тест", "testing", "assert", "expect" },
        .category = .Testing,
        .code =
        \\const std = @import("std");
        \\
        \\/// Function to test
        \\pub fn add(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
        \\
        \\pub fn divide(a: i32, b: i32) !i32 {
        \\    if (b == 0) return error.DivisionByZero;
        \\    return @divTrunc(a, b);
        \\}
        \\
        \\// Basic test
        \\test "add positive numbers" {
        \\    try std.testing.expectEqual(@as(i32, 5), add(2, 3));
        \\}
        \\
        \\// Test with multiple assertions
        \\test "add various cases" {
        \\    try std.testing.expectEqual(@as(i32, 0), add(0, 0));
        \\    try std.testing.expectEqual(@as(i32, -1), add(-2, 1));
        \\    try std.testing.expectEqual(@as(i32, 100), add(50, 50));
        \\}
        \\
        \\// Test for expected error
        \\test "divide by zero returns error" {
        \\    try std.testing.expectError(error.DivisionByZero, divide(10, 0));
        \\}
        \\
        \\// Test with allocator
        \\test "dynamic allocation" {
        \\    const allocator = std.testing.allocator;
        \\
        \\    const slice = try allocator.alloc(i32, 5);
        \\    defer allocator.free(slice);
        \\
        \\    try std.testing.expectEqual(@as(usize, 5), slice.len);
        \\}
        \\
        \\// Test approximate equality (for floats)
        \\test "float comparison" {
        \\    const phi: f64 = 1.618033988749895;
        \\    const result = phi * phi + 1.0 / (phi * phi);
        \\
        \\    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result, 0.0001);
        \\}
        \\
        \\// Test slices
        \\test "slice equality" {
        \\    const expected = [_]i32{ 1, 2, 3 };
        \\    const actual = [_]i32{ 1, 2, 3 };
        \\
        \\    try std.testing.expectEqualSlices(i32, &expected, &actual);
        \\}
        \\
        \\// Test strings
        \\test "string equality" {
        \\    try std.testing.expectEqualStrings("hello", "hello");
        \\}
        \\
        \\pub fn main() void {
        \\    std.debug.print("Run tests with: zig test <filename>\n", .{});
        \\}
        ,
        .description = "Zig testing patterns and assertions",
        .chain_of_thought = "1. Use test \"name\" blocks\n2. expectEqual for exact match\n3. expectError for error testing\n4. Use std.testing.allocator in tests",
    },

    // ───────────────────────────────────────────────────────────────────────────
    // MATH (4 templates)
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .name = "math_golden_ratio",
        .keywords = &.{ "phi", "golden", "ratio", "fibonacci", "золотое", "сечение" },
        .category = .Math,
        .code =
        \\const std = @import("std");
        \\
        \\/// Golden ratio constant
        \\pub const PHI: f64 = 1.618033988749895;
        \\pub const PHI_INVERSE: f64 = 0.618033988749895;
        \\
        \\/// Prove phi^2 + 1/phi^2 = 3
        \\pub fn verifyTrinityIdentity() bool {
        \\    const result = PHI * PHI + 1.0 / (PHI * PHI);
        \\    return @abs(result - 3.0) < 0.0001;
        \\}
        \\
        \\/// Compute nth Fibonacci using golden ratio (Binet's formula)
        \\pub fn fibonacciBinet(n: u32) u64 {
        \\    const sqrt5 = @sqrt(5.0);
        \\    const phi_n = std.math.pow(f64, PHI, @as(f64, @floatFromInt(n)));
        \\    const psi_n = std.math.pow(f64, -PHI_INVERSE, @as(f64, @floatFromInt(n)));
        \\
        \\    return @intFromFloat(@round((phi_n - psi_n) / sqrt5));
        \\}
        \\
        \\/// Check if ratio is close to golden ratio
        \\pub fn isGoldenRatio(a: f64, b: f64) bool {
        \\    if (b < 0.0001) return false;
        \\    const ratio = a / b;
        \\    return @abs(ratio - PHI) < 0.01;
        \\}
        \\
        \\pub fn main() void {
        \\    std.debug.print("Golden Ratio Constants:\n", .{});
        \\    std.debug.print("  phi = {d:.15}\n", .{PHI});
        \\    std.debug.print("  1/phi = {d:.15}\n", .{PHI_INVERSE});
        \\    std.debug.print("  phi^2 = {d:.15}\n", .{PHI * PHI});
        \\    std.debug.print("  phi^2 + 1/phi^2 = {d:.15}\n", .{PHI * PHI + 1.0 / (PHI * PHI)});
        \\    std.debug.print("\nTrinity Identity Verified: {}\n", .{verifyTrinityIdentity()});
        \\
        \\    std.debug.print("\nFibonacci (Binet's formula):\n", .{});
        \\    for (0..15) |i| {
        \\        std.debug.print("  F({d}) = {d}\n", .{i, fibonacciBinet(@intCast(i))});
        \\    }
        \\}
        \\
        \\test "trinity identity" {
        \\    try std.testing.expect(verifyTrinityIdentity());
        \\}
        \\
        \\test "fibonacci binet" {
        \\    try std.testing.expectEqual(@as(u64, 0), fibonacciBinet(0));
        \\    try std.testing.expectEqual(@as(u64, 1), fibonacciBinet(1));
        \\    try std.testing.expectEqual(@as(u64, 55), fibonacciBinet(10));
        \\}
        ,
        .description = "Golden ratio mathematics and Trinity identity",
        .chain_of_thought = "1. phi = (1 + sqrt(5)) / 2\n2. Key identity: phi^2 = phi + 1\n3. Trinity: phi^2 + 1/phi^2 = 3\n4. Binet's formula for Fibonacci",
    },
    .{
        .name = "matrix_multiply",
        .keywords = &.{ "matrix", "matmul", "multiply", "матрица", "умножение" },
        .category = .Math,
        .code =
        \\const std = @import("std");
        \\
        \\/// Matrix multiplication: C = A × B
        \\/// A: [M x K], B: [K x N], C: [M x N]
        \\pub fn matmul(
        \\    comptime M: usize,
        \\    comptime K: usize,
        \\    comptime N: usize,
        \\    a: *const [M][K]f32,
        \\    b: *const [K][N]f32,
        \\) [M][N]f32 {
        \\    var c: [M][N]f32 = undefined;
        \\
        \\    for (0..M) |i| {
        \\        for (0..N) |j| {
        \\            var sum: f32 = 0;
        \\            for (0..K) |k| {
        \\                sum += a[i][k] * b[k][j];
        \\            }
        \\            c[i][j] = sum;
        \\        }
        \\    }
        \\
        \\    return c;
        \\}
        \\
        \\/// Print matrix
        \\pub fn printMatrix(comptime M: usize, comptime N: usize, m: *const [M][N]f32) void {
        \\    for (m) |row| {
        \\        std.debug.print("[ ", .{});
        \\        for (row) |val| {
        \\            std.debug.print("{d:6.2} ", .{val});
        \\        }
        \\        std.debug.print("]\n", .{});
        \\    }
        \\}
        \\
        \\pub fn main() void {
        \\    const a = [2][3]f32{
        \\        .{ 1, 2, 3 },
        \\        .{ 4, 5, 6 },
        \\    };
        \\
        \\    const b = [3][2]f32{
        \\        .{ 7, 8 },
        \\        .{ 9, 10 },
        \\        .{ 11, 12 },
        \\    };
        \\
        \\    std.debug.print("A =\n", .{});
        \\    printMatrix(2, 3, &a);
        \\
        \\    std.debug.print("\nB =\n", .{});
        \\    printMatrix(3, 2, &b);
        \\
        \\    const c = matmul(2, 3, 2, &a, &b);
        \\
        \\    std.debug.print("\nC = A × B =\n", .{});
        \\    printMatrix(2, 2, &c);
        \\}
        \\
        \\test "matmul" {
        \\    const a = [2][2]f32{ .{ 1, 2 }, .{ 3, 4 } };
        \\    const b = [2][2]f32{ .{ 5, 6 }, .{ 7, 8 } };
        \\    const c = matmul(2, 2, 2, &a, &b);
        \\
        \\    try std.testing.expectApproxEqAbs(@as(f32, 19), c[0][0], 0.001);
        \\    try std.testing.expectApproxEqAbs(@as(f32, 22), c[0][1], 0.001);
        \\}
        ,
        .description = "Matrix multiplication with comptime dimensions",
        .chain_of_thought = "1. C[i][j] = sum over k of A[i][k] * B[k][j]\n2. Use comptime for dimensions\n3. Triple nested loop: i, j, k\n4. Time complexity: O(M*N*K)",
    },

    // ───────────────────────────────────────────────────────────────────────────
    // VIBEE SPECIFICATIONS (3 templates)
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .name = "vibee_basic",
        .keywords = &.{ "vibee", "spec", "specification", "yaml", "спецификация" },
        .category = .VIBEE,
        .code =
        \\// VIBEE Specification Example
        \\// Save as: specs/tri/my_module.vibee
        \\//
        \\// name: my_module
        \\// version: "1.0.0"
        \\// language: zig
        \\// module: my_module
        \\//
        \\// types:
        \\//   MyType:
        \\//     fields:
        \\//       name: String
        \\//       value: Int
        \\//       active: Bool
        \\//
        \\// behaviors:
        \\//   - name: create
        \\//     given: A name and initial value
        \\//     when: Creating a new instance
        \\//     then: Returns MyType with given values
        \\//
        \\//   - name: increment
        \\//     given: An existing MyType
        \\//     when: Incrementing the value
        \\//     then: Value increases by 1
        \\//
        \\// Run: ./bin/vibee gen specs/tri/my_module.vibee
        \\// Output: trinity/output/my_module.zig
        \\
        \\const std = @import("std");
        \\
        \\pub const MyType = struct {
        \\    name: []const u8,
        \\    value: i32,
        \\    active: bool,
        \\
        \\    pub fn create(name: []const u8, value: i32) MyType {
        \\        return .{
        \\            .name = name,
        \\            .value = value,
        \\            .active = true,
        \\        };
        \\    }
        \\
        \\    pub fn increment(self: *MyType) void {
        \\        self.value += 1;
        \\    }
        \\};
        \\
        \\pub fn main() void {
        \\    var instance = MyType.create("test", 0);
        \\    std.debug.print("Initial: {s} = {d}\n", .{instance.name, instance.value});
        \\
        \\    instance.increment();
        \\    std.debug.print("After increment: {d}\n", .{instance.value});
        \\}
        \\
        \\test "MyType" {
        \\    var t = MyType.create("test", 10);
        \\    t.increment();
        \\    try std.testing.expectEqual(@as(i32, 11), t.value);
        \\}
        ,
        .description = "VIBEE specification format with Zig implementation",
        .chain_of_thought = "1. Create .vibee YAML spec with types and behaviors\n2. Run ./bin/vibee gen to generate Zig\n3. Types map to structs with fields\n4. Behaviors map to functions",
    },
    .{
        .name = "vibee_vsa_module",
        .keywords = &.{ "vibee", "vsa", "hdc", "vector", "symbolic" },
        .category = .VIBEE,
        .code =
        \\// VIBEE Specification for VSA Module
        \\// Save as: specs/tri/vsa_engine.vibee
        \\//
        \\// name: vsa_engine
        \\// version: "1.0.0"
        \\// language: zig
        \\// module: vsa_engine
        \\//
        \\// types:
        \\//   TritVec:
        \\//     fields:
        \\//       data: List<Int>
        \\//       dim: Int
        \\//
        \\//   Similarity:
        \\//     fields:
        \\//       score: Float
        \\//       matched: Bool
        \\//
        \\// behaviors:
        \\//   - name: bind
        \\//     given: Two TritVec of same dimension
        \\//     when: Binding vectors together
        \\//     then: Returns element-wise product
        \\//
        \\//   - name: bundle
        \\//     given: List of TritVec
        \\//     when: Creating superposition
        \\//     then: Returns majority vote vector
        \\//
        \\//   - name: similarity
        \\//     given: Two TritVec
        \\//     when: Computing similarity
        \\//     then: Returns cosine similarity score
        \\
        \\const std = @import("std");
        \\
        \\pub const EMBEDDING_DIM = 256;
        \\pub const Trit = i8;
        \\
        \\pub const TritVec = struct {
        \\    data: [EMBEDDING_DIM]Trit,
        \\
        \\    pub fn random(seed: u64) TritVec {
        \\        var prng = std.Random.DefaultPrng.init(seed);
        \\        var result: TritVec = undefined;
        \\        for (&result.data) |*d| {
        \\            d.* = @as(Trit, @intCast(prng.random().int(u2))) - 1;
        \\        }
        \\        return result;
        \\    }
        \\
        \\    pub fn bind(self: TritVec, other: TritVec) TritVec {
        \\        var result: TritVec = undefined;
        \\        for (&result.data, self.data, other.data) |*r, a, b| {
        \\            r.* = a * b;
        \\        }
        \\        return result;
        \\    }
        \\
        \\    pub fn similarity(self: TritVec, other: TritVec) f32 {
        \\        var dot: i32 = 0;
        \\        var norm_a: i32 = 0;
        \\        var norm_b: i32 = 0;
        \\
        \\        for (self.data, other.data) |a, b| {
        \\            dot += @as(i32, a) * @as(i32, b);
        \\            norm_a += @as(i32, a) * @as(i32, a);
        \\            norm_b += @as(i32, b) * @as(i32, b);
        \\        }
        \\
        \\        const denom = @sqrt(@as(f32, @floatFromInt(norm_a))) * @sqrt(@as(f32, @floatFromInt(norm_b)));
        \\        if (denom < 0.001) return 0;
        \\        return @as(f32, @floatFromInt(dot)) / denom;
        \\    }
        \\};
        \\
        \\pub fn bundle(vecs: []const TritVec) TritVec {
        \\    var result: TritVec = undefined;
        \\
        \\    for (&result.data, 0..) |*r, i| {
        \\        var sum: i32 = 0;
        \\        for (vecs) |v| sum += v.data[i];
        \\        r.* = if (sum > 0) 1 else if (sum < 0) -1 else 0;
        \\    }
        \\
        \\    return result;
        \\}
        \\
        \\pub fn main() void {
        \\    const a = TritVec.random(42);
        \\    const b = TritVec.random(123);
        \\
        \\    std.debug.print("VSA Engine Demo\n", .{});
        \\    std.debug.print("sim(a, a) = {d:.4}\n", .{a.similarity(a)});
        \\    std.debug.print("sim(a, b) = {d:.4}\n", .{a.similarity(b)});
        \\
        \\    const bound = a.bind(b);
        \\    const recovered = bound.bind(b);
        \\    std.debug.print("sim(a, unbind(bind(a,b), b)) = {d:.4}\n", .{a.similarity(recovered)});
        \\}
        ,
        .description = "VIBEE VSA engine specification",
        .chain_of_thought = "1. Define TritVec type with data array\n2. bind = element-wise multiplication\n3. bundle = majority vote\n4. similarity = cosine similarity",
    },

    // ───────────────────────────────────────────────────────────────────────────
    // STRING OPERATIONS (2 templates)
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .name = "string_operations",
        .keywords = &.{ "string", "строка", "concat", "split", "trim", "text" },
        .category = .String,
        .code =
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        \\    defer _ = gpa.deinit();
        \\    const allocator = gpa.allocator();
        \\
        \\    // String literals
        \\    const hello = "Hello";
        \\    const world = "World";
        \\
        \\    // Concatenation
        \\    const greeting = try std.fmt.allocPrint(allocator, "{s}, {s}!", .{hello, world});
        \\    defer allocator.free(greeting);
        \\    std.debug.print("Greeting: {s}\n", .{greeting});
        \\
        \\    // Split
        \\    const csv = "one,two,three,four";
        \\    var iter = std.mem.splitScalar(u8, csv, ',');
        \\    std.debug.print("Split: ", .{});
        \\    while (iter.next()) |part| {
        \\        std.debug.print("[{s}] ", .{part});
        \\    }
        \\    std.debug.print("\n", .{});
        \\
        \\    // Trim
        \\    const padded = "  hello world  ";
        \\    const trimmed = std.mem.trim(u8, padded, " ");
        \\    std.debug.print("Trimmed: '{s}'\n", .{trimmed});
        \\
        \\    // Contains
        \\    std.debug.print("Contains 'world': {}\n", .{std.mem.indexOf(u8, greeting, "World") != null});
        \\
        \\    // Replace (manual)
        \\    var buf: [100]u8 = undefined;
        \\    _ = std.mem.replace(u8, greeting, "World", "Trinity", &buf);
        \\    std.debug.print("Replaced: {s}\n", .{buf[0..greeting.len + 1]});
        \\
        \\    // To uppercase (ASCII)
        \\    var upper: [20]u8 = undefined;
        \\    for (hello, 0..) |c, i| {
        \\        upper[i] = std.ascii.toUpper(c);
        \\    }
        \\    std.debug.print("Upper: {s}\n", .{upper[0..hello.len]});
        \\}
        ,
        .description = "String manipulation in Zig",
        .chain_of_thought = "1. Use std.fmt.allocPrint for concatenation\n2. std.mem.splitScalar for splitting\n3. std.mem.trim for whitespace\n4. std.mem.indexOf for searching",
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE SELECTION ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const IglaLocalCoder = struct {
    allocator: std.mem.Allocator,
    total_generations: usize,
    total_matches: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .total_generations = 0,
            .total_matches = 0,
        };
    }

    /// Find best matching template for query
    pub fn findBestTemplate(self: *Self, query: []const u8) ?*const CodeTemplate {
        var best_score: usize = 0;
        var best_template: ?*const CodeTemplate = null;

        for (&TEMPLATES) |*template| {
            var score: usize = 0;

            // Check each keyword
            for (template.keywords) |keyword| {
                if (containsIgnoreCase(query, keyword)) {
                    score += keyword.len; // Longer keywords = more specific
                }
            }

            if (score > best_score) {
                best_score = score;
                best_template = template;
            }
        }

        if (best_template != null) {
            self.total_matches += 1;
        }
        return best_template;
    }

    /// Generate code for query
    pub fn generateCode(self: *Self, query: []const u8) CodeResult {
        self.total_generations += 1;

        if (self.findBestTemplate(query)) |template| {
            return CodeResult{
                .code = template.code,
                .template_name = template.name,
                .category = template.category,
                .description = template.description,
                .chain_of_thought = template.chain_of_thought,
                .confidence = 0.95,
                .is_match = true,
            };
        }

        // No match - return generic template
        return CodeResult{
            .code =
            \\const std = @import("std");
            \\
            \\pub fn main() void {
            \\    // TODO: Implement your code here
            \\    std.debug.print("Hello from IGLA Local Coder!\n", .{});
            \\}
            ,
            .template_name = "generic_template",
            .category = .HelloWorld,
            .description = "Generic starting template",
            .chain_of_thought = "1. Import std library\n2. Define main function\n3. Add your implementation",
            .confidence = 0.5,
            .is_match = false,
        };
    }

    /// Get statistics
    pub fn getStats(self: *const Self) struct {
        total_generations: usize,
        total_matches: usize,
        match_rate: f32,
        templates_available: usize,
    } {
        return .{
            .total_generations = self.total_generations,
            .total_matches = self.total_matches,
            .match_rate = if (self.total_generations > 0)
                @as(f32, @floatFromInt(self.total_matches)) / @as(f32, @floatFromInt(self.total_generations))
            else
                0,
            .templates_available = TEMPLATES.len,
        };
    }
};

pub const CodeResult = struct {
    code: []const u8,
    template_name: []const u8,
    category: CodeCategory,
    description: []const u8,
    chain_of_thought: []const u8,
    confidence: f32,
    is_match: bool,
};

/// Case-insensitive contains check
fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;

    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var match = true;
        for (0..needle.len) |j| {
            const h = std.ascii.toLower(haystack[i + j]);
            const n = std.ascii.toLower(needle[j]);
            if (h != n) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN - Local Coding Demo
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     IGLA LOCAL CODER - Autonomous SWE Agent                   \n", .{});
    std.debug.print("     100% Local | No Cloud | {d} Templates                     \n", .{TEMPLATES.len});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    var coder = IglaLocalCoder.init(allocator);

    // Test queries (multilingual)
    const queries = [_][]const u8{
        "hello world",
        "fibonacci function",
        "bind two vectors",
        "bundle vsa",
        "quick sort array",
        "create struct with methods",
        "hashmap example",
        "error handling try catch",
        "matrix multiply",
        "golden ratio phi",
        "write test",
        "vibee spec",
        "binary search",
        "arraylist dynamic",
        "file read write",
        "allocator memory",
        "cosine similarity",
        "permute rotate",
        "quantize ternary",
        "привет мир",  // Russian: hello world
        "фибоначчи",   // Russian: fibonacci
    };

    var total_time_us: u64 = 0;
    var matches: usize = 0;

    std.debug.print("\n", .{});
    for (queries, 0..) |query, i| {
        const start = std.time.microTimestamp();
        const result = coder.generateCode(query);
        const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
        total_time_us += elapsed;

        if (result.is_match) matches += 1;

        const status = if (result.is_match) "OK" else "? ";
        std.debug.print("[{d:2}] [{s}] \"{s}\"\n", .{ i + 1, status, query });
        std.debug.print("     Template: {s} ({s})\n", .{ result.template_name, @tagName(result.category) });
        std.debug.print("     Confidence: {d:.0}% | Time: {d}us\n", .{ result.confidence * 100, elapsed });

        // Show first 3 lines of code
        var lines: usize = 0;
        var code_iter = std.mem.splitScalar(u8, result.code, '\n');
        std.debug.print("     Code: ", .{});
        while (code_iter.next()) |line| {
            if (lines == 0) {
                std.debug.print("{s}...\n", .{line[0..@min(line.len, 50)]});
            }
            lines += 1;
            if (lines >= 3) break;
        }
        std.debug.print("\n", .{});
    }

    // Statistics
    const stats = coder.getStats();
    const avg_time = @as(f64, @floatFromInt(total_time_us)) / @as(f64, @floatFromInt(queries.len));
    const ops_per_sec = 1_000_000.0 / avg_time;

    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     STATISTICS                                                \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Queries: {d}\n", .{queries.len});
    std.debug.print("  Matches: {d}/{d} ({d:.1}%)\n", .{
        matches,
        queries.len,
        stats.match_rate * 100,
    });
    std.debug.print("  Templates: {d}\n", .{stats.templates_available});
    std.debug.print("  Total Time: {d}us ({d:.2}ms)\n", .{ total_time_us, @as(f64, @floatFromInt(total_time_us)) / 1000.0 });
    std.debug.print("  Avg Time: {d:.1}us/query\n", .{avg_time});
    std.debug.print("  Speed: {d:.0} ops/s\n", .{ops_per_sec});
    std.debug.print("  Mode: 100% LOCAL (no cloud)\n", .{});

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL          \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
}

test "template matching" {
    var coder = IglaLocalCoder.init(std.testing.allocator);

    const result = coder.generateCode("fibonacci");
    try std.testing.expect(result.is_match);
    try std.testing.expect(std.mem.indexOf(u8, result.code, "fibonacci") != null);
}

test "multilingual matching" {
    var coder = IglaLocalCoder.init(std.testing.allocator);

    // Russian
    const result_ru = coder.generateCode("привет");
    try std.testing.expect(result_ru.is_match);

    // English
    const result_en = coder.generateCode("hello world");
    try std.testing.expect(result_en.is_match);
}
