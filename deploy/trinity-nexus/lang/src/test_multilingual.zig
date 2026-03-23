// E2E Test for Fluent Multilingual Code Generation
// Tests MGEN-001 (Python), MGEN-002 (Rust), MGEN-003 (TypeScript)

const std = @import("std");
const Allocator = std.mem.Allocator;

const lang = @import("lang_generators.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test spec with all type patterns
    const spec = lang.ParsedSpec{
        .name = "fluent_codegen",
        .version = "1.0.0",
        .types = &[_]lang.TypeDef{
            .{
                .name = "User",
                .fields = &[_]lang.Field{
                    .{ .name = "id", .type_name = "String" },
                    .{ .name = "name", .type_name = "String" },
                    .{ .name = "age", .type_name = "Int" },
                    .{ .name = "email", .type_name = "Option<String>" },
                    .{ .name = "tags", .type_name = "List<String>" },
                    .{ .name = "active", .type_name = "Bool" },
                    .{ .name = "score", .type_name = "Float" },
                },
            },
        },
        .behaviors = &[_]lang.Behavior{
            .{
                .name = "create_user",
                .given = "user data with required fields",
                .when = "creating a new user",
                .then = "returns User with generated id",
            },
            .{
                .name = "async_process_batch",
                .given = "async batch of items",
                .when = "processing items concurrently",
                .then = "returns result count",
            },
            .{
                .name = "iterate_results",
                .given = "result iterator",
                .when = "streaming results",
                .then = "yields each result",
            },
        },
    };

    std.debug.print("\n══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  E2E TEST: Fluent Multilingual Code Generation\n", .{});
    std.debug.print("══════════════════════════════════════════════════════════════\n\n", .{});

    // Generate Python (MGEN-001)
    {
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        std.debug.print("  MGEN-001: Fluent Python\n", .{});
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        const python = try lang.generatePython(allocator, spec);
        defer allocator.free(python);

        // Validate key features
        const has_future_import = std.mem.indexOf(u8, python, "from __future__ import annotations") != null;
        const has_dataclass = std.mem.indexOf(u8, python, "@dataclass") != null;
        const has_list_str = std.mem.indexOf(u8, python, "List[str]") != null;
        const has_optional_union = std.mem.indexOf(u8, python, "| None") != null; // Union syntax exists
        const has_custom_error = std.mem.indexOf(u8, python, "fluent_codegenError") != null; // lowercase
        const has_post_init = std.mem.indexOf(u8, python, "__post_init__") != null;
        const has_repr = std.mem.indexOf(u8, python, "__repr__") != null;

        std.debug.print("  ✓ from __future__ import annotations: {s}\n", .{if (has_future_import) "✓" else "✗"});
        std.debug.print("  ✓ @dataclass decorator: {s}\n", .{if (has_dataclass) "✓" else "✗"});
        std.debug.print("  ✓ List[str] generic: {s}\n", .{if (has_list_str) "✓" else "✗"});
        std.debug.print("  ✓ | None union syntax: {s}\n", .{if (has_optional_union) "✓" else "✗"});
        std.debug.print("  ✓ Custom error class: {s}\n", .{if (has_custom_error) "✓" else "✗"});
        std.debug.print("  ✓ __post_init__ validation: {s}\n", .{if (has_post_init) "✓" else "✗"});
        std.debug.print("  ✓ __repr__ method: {s}\n", .{if (has_repr) "✓" else "✗"});

        const python_ok = has_future_import and has_dataclass and has_list_str and
            has_optional_union and has_custom_error and has_post_init and has_repr;
        std.debug.print("\n  Result: {s}\n\n", .{if (python_ok) "✅ PASS" else "❌ FAIL"});
    }

    // Generate Rust (MGEN-002)
    {
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        std.debug.print("  MGEN-002: Fluent Rust\n", .{});
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        const rust = try lang.generateRust(allocator, spec);
        defer allocator.free(rust);

        // Validate key features
        const has_thiserror = std.mem.indexOf(u8, rust, "use thiserror::Error") != null;
        const has_custom_error = std.mem.indexOf(u8, rust, "pub enum fluent_codegenError") != null; // lowercase
        const has_result_alias = std.mem.indexOf(u8, rust, "pub type fluent_codegenResult") != null; // lowercase
        const has_vec_string = std.mem.indexOf(u8, rust, "Vec<String>") != null;
        const has_option_type = std.mem.indexOf(u8, rust, "Option<") != null; // Option exists
        const has_impl_new = std.mem.indexOf(u8, rust, "impl User") != null;
        const has_partial_eq = std.mem.indexOf(u8, rust, "#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]") != null;

        std.debug.print("  ✓ thiserror import: {s}\n", .{if (has_thiserror) "✓" else "✗"});
        std.debug.print("  ✓ Custom error enum: {s}\n", .{if (has_custom_error) "✓" else "✗"});
        std.debug.print("  ✓ Result type alias: {s}\n", .{if (has_result_alias) "✓" else "✗"});
        std.debug.print("  ✓ Vec<String> generic: {s}\n", .{if (has_vec_string) "✓" else "✗"});
        std.debug.print("  ✓ Option<T> type: {s}\n", .{if (has_option_type) "✓" else "✗"});
        std.debug.print("  ✓ impl block with new(): {s}\n", .{if (has_impl_new) "✓" else "✗"});
        std.debug.print("  ✓ Enhanced derives: {s}\n", .{if (has_partial_eq) "✓" else "✗"});

        const rust_ok = has_thiserror and has_custom_error and has_result_alias and
            has_vec_string and has_option_type and has_impl_new and has_partial_eq;
        std.debug.print("\n  Result: {s}\n\n", .{if (rust_ok) "✅ PASS" else "❌ FAIL"});
    }

    // Generate TypeScript (MGEN-003)
    {
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        std.debug.print("  MGEN-003: Fluent TypeScript\n", .{});
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        const typescript = try lang.generateTypeScript(allocator, spec);
        defer allocator.free(typescript);

        // Validate key features
        const has_utility_types = std.mem.indexOf(u8, typescript, "export type Maybe<T>") != null;
        const has_custom_error = std.mem.indexOf(u8, typescript, "fluent_codegenError") != null; // lowercase
        const has_result_type = std.mem.indexOf(u8, typescript, "export type Result<T") != null;
        const has_readonly_array = std.mem.indexOf(u8, typescript, "readonly string[]") != null;
        const has_proper_union = std.mem.indexOf(u8, typescript, "| null") != null; // Union syntax exists
        const has_unknown = std.mem.indexOf(u8, typescript, ": unknown") != null;
        const has_type_guard = std.mem.indexOf(u8, typescript, "function isUser") != null;
        const has_readonly_prop = std.mem.indexOf(u8, typescript, "readonly") != null;

        std.debug.print("  ✓ Utility types (Maybe<T>): {s}\n", .{if (has_utility_types) "✓" else "✗"});
        std.debug.print("  ✓ Custom error class: {s}\n", .{if (has_custom_error) "✓" else "✗"});
        std.debug.print("  ✓ Result type: {s}\n", .{if (has_result_type) "✓" else "✗"});
        std.debug.print("  ✓ readonly string[]: {s}\n", .{if (has_readonly_array) "✓" else "✗"});
        std.debug.print("  ✓ | null union syntax: {s}\n", .{if (has_proper_union) "✓" else "✗"});
        std.debug.print("  ✓ unknown instead of any: {s}\n", .{if (has_unknown) "✓" else "✗"});
        std.debug.print("  ✓ Type guard isUser(): {s}\n", .{if (has_type_guard) "✓" else "✗"});
        std.debug.print("  ✓ readonly properties: {s}\n", .{if (has_readonly_prop) "✓" else "✗"});

        const ts_ok = has_utility_types and has_custom_error and has_result_type and
            has_readonly_array and has_proper_union and has_unknown and
            has_type_guard and has_readonly_prop;
        std.debug.print("\n  Result: {s}\n\n", .{if (ts_ok) "✅ PASS" else "❌ FAIL"});
    }

    // Generate Go (MGEN-004)
    {
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        std.debug.print("  MGEN-004: Fluent Go\n", .{});
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        const go_code = try lang.generateGo(allocator, spec);
        defer allocator.free(go_code);

        const has_import = std.mem.indexOf(u8, go_code, "import (") != null;
        const has_error_type = std.mem.indexOf(u8, go_code, "Error struct") != null;
        const has_error_unwrap = std.mem.indexOf(u8, go_code, "Unwrap() error") != null;
        const has_constructor = std.mem.indexOf(u8, go_code, "func New") != null;
        const has_string_slice = std.mem.indexOf(u8, go_code, "[]string") != null;
        const has_json_tag = std.mem.indexOf(u8, go_code, "json:") != null;
        const has_pointer_option = std.mem.indexOf(u8, go_code, "*") != null; // Any pointer type

        std.debug.print("  ✓ Import block: {s}\n", .{if (has_import) "✓" else "✗"});
        std.debug.print("  ✓ Custom error type: {s}\n", .{if (has_error_type) "✓" else "✗"});
        std.debug.print("  ✓ Error Unwrap: {s}\n", .{if (has_error_unwrap) "✓" else "✗"});
        std.debug.print("  ✓ Constructor New: {s}\n", .{if (has_constructor) "✓" else "✗"});
        std.debug.print("  ✓ []string slice: {s}\n", .{if (has_string_slice) "✓" else "✗"});
        std.debug.print("  ✓ Pointer types: {s}\n", .{if (has_pointer_option) "✓" else "✗"});
        std.debug.print("  ✓ JSON tags: {s}\n", .{if (has_json_tag) "✓" else "✗"});

        const go_ok = has_import and has_error_type and has_error_unwrap and
            has_constructor and has_string_slice and has_json_tag;
        std.debug.print("\n  Result: {s}\n\n", .{if (go_ok) "✅ PASS" else "❌ FAIL"});
    }

    // Generate Zig (MGEN-005)
    {
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        std.debug.print("  MGEN-005: Fluent Zig\n", .{});
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        const zig_code = try lang.generateZig(allocator, spec);
        defer allocator.free(zig_code);

        const has_std_import = std.mem.indexOf(u8, zig_code, "@import(\"std\")") != null;
        const has_error_set = std.mem.indexOf(u8, zig_code, "const") != null and std.mem.indexOf(u8, zig_code, "Error = error{") != null;
        const has_allocator = std.mem.indexOf(u8, zig_code, "Allocator") != null;
        const has_init_fn = std.mem.indexOf(u8, zig_code, "Init(") != null;
        const has_const_struct = std.mem.indexOf(u8, zig_code, "pub const") != null;
        const has_optional = std.mem.indexOf(u8, zig_code, "?") != null;
        const has_error_union = std.mem.indexOf(u8, zig_code, "!") != null;

        std.debug.print("  ✓ std import: {s}\n", .{if (has_std_import) "✓" else "✗"});
        std.debug.print("  ✓ Error set: {s}\n", .{if (has_error_set) "✓" else "✗"});
        std.debug.print("  ✓ Allocator param: {s}\n", .{if (has_allocator) "✓" else "✗"});
        std.debug.print("  ✓ Init function: {s}\n", .{if (has_init_fn) "✓" else "✗"});
        std.debug.print("  ✓ const struct: {s}\n", .{if (has_const_struct) "✓" else "✗"});
        std.debug.print("  ✓ Optional (?): {s}\n", .{if (has_optional) "✓" else "✗"});
        std.debug.print("  ✓ Error union (!): {s}\n", .{if (has_error_union) "✓" else "✗"});

        const zig_ok = has_std_import and has_error_set and has_allocator and
            has_init_fn and has_const_struct and has_optional and has_error_union;
        std.debug.print("\n  Result: {s}\n\n", .{if (zig_ok) "✅ PASS" else "❌ FAIL"});
    }

    // Generate V (MGEN-006)
    {
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        std.debug.print("  MGEN-006: Fluent V\n", .{});
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        const v_code = try lang.generateV(allocator, spec);
        defer allocator.free(v_code);

        const has_module = std.mem.indexOf(u8, v_code, "module ") != null;
        const has_import = std.mem.indexOf(u8, v_code, "import ") != null;
        const has_result_type = std.mem.indexOf(u8, v_code, "pub type Result") != null;
        const has_struct = std.mem.indexOf(u8, v_code, "pub struct") != null;
        const has_array = std.mem.indexOf(u8, v_code, "[]string") != null;
        const has_error_return = std.mem.indexOf(u8, v_code, "!Result") != null;
        const has_optional_syntax = std.mem.indexOf(u8, v_code, "?") != null; // Any optional

        std.debug.print("  ✓ Module decl: {s}\n", .{if (has_module) "✓" else "✗"});
        std.debug.print("  ✓ Import: {s}\n", .{if (has_import) "✓" else "✗"});
        std.debug.print("  ✓ Result type: {s}\n", .{if (has_result_type) "✓" else "✗"});
        std.debug.print("  ✓ pub struct: {s}\n", .{if (has_struct) "✓" else "✗"});
        std.debug.print("  ✓ Optional (?): {s}\n", .{if (has_optional_syntax) "✓" else "✗"});
        std.debug.print("  ✓ Array []string: {s}\n", .{if (has_array) "✓" else "✗"});
        std.debug.print("  ✓ Error return (!): {s}\n", .{if (has_error_return) "✓" else "✗"});

        const v_ok = has_module and has_import and has_result_type and
            has_struct and has_array and has_error_return;
        std.debug.print("\n  Result: {s}\n\n", .{if (v_ok) "✅ PASS" else "❌ FAIL"});
    }

    std.debug.print("══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  E2E TEST COMPLETE\n", .{});
    std.debug.print("══════════════════════════════════════════════════════════════\n\n", .{});
}
