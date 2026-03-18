#include "tree_sitter/parser.h"

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
#endif

#define LANGUAGE_VERSION 14
#define STATE_COUNT 51
#define LARGE_STATE_COUNT 21
#define SYMBOL_COUNT 134
#define ALIAS_COUNT 0
#define TOKEN_COUNT 110
#define EXTERNAL_TOKEN_COUNT 0
#define FIELD_COUNT 3
#define MAX_ALIAS_SEQUENCE_LENGTH 5
#define PRODUCTION_ID_COUNT 4

enum ts_symbol_identifiers {
  sym_plain_identifier = 1,
  anon_sym_COLON = 2,
  anon_sym_name = 3,
  anon_sym_version = 4,
  anon_sym_language = 5,
  anon_sym_module = 6,
  anon_sym_description = 7,
  anon_sym_author = 8,
  anon_sym_license = 9,
  anon_sym_constants = 10,
  anon_sym_types = 11,
  anon_sym_behaviors = 12,
  anon_sym_algorithms = 13,
  anon_sym_imports = 14,
  anon_sym_creation_patterns = 15,
  anon_sym_wasm_exports = 16,
  anon_sym_pas_predictions = 17,
  anon_sym_signals = 18,
  anon_sym_fsm = 19,
  anon_sym_reset = 20,
  anon_sym_test_cases = 21,
  anon_sym_tests = 22,
  anon_sym_cli = 23,
  anon_sym_theorems = 24,
  anon_sym_targets = 25,
  anon_sym_fpga_target = 26,
  anon_sym_pipeline = 27,
  anon_sym_target_frequency = 28,
  anon_sym_fields = 29,
  anon_sym_enum = 30,
  anon_sym_constraints = 31,
  anon_sym_base = 32,
  anon_sym_generic = 33,
  anon_sym_functions = 34,
  anon_sym_memory = 35,
  anon_sym_states = 36,
  anon_sym_transitions = 37,
  anon_sym_outputs = 38,
  anon_sym_timers = 39,
  anon_sym_flags = 40,
  anon_sym_given = 41,
  anon_sym_when = 42,
  anon_sym_then = 43,
  anon_sym_implementation = 44,
  anon_sym_input = 45,
  anon_sym_expected = 46,
  anon_sym_tolerance = 47,
  anon_sym_complexity = 48,
  anon_sym_pattern = 49,
  anon_sym_steps = 50,
  anon_sym_formula = 51,
  anon_sym_source = 52,
  anon_sym_transformer = 53,
  anon_sym_result = 54,
  anon_sym_target = 55,
  anon_sym_current = 56,
  anon_sym_predicted = 57,
  anon_sym_confidence = 58,
  anon_sym_status = 59,
  anon_sym_timeline = 60,
  anon_sym_width = 61,
  anon_sym_direction = 62,
  anon_sym_signed = 63,
  anon_sym_default = 64,
  anon_sym_initial = 65,
  anon_sym_encoding = 66,
  anon_sym_from = 67,
  anon_sym_to = 68,
  anon_sym_type = 69,
  anon_sym_level = 70,
  anon_sym_short = 71,
  anon_sym_category = 72,
  anon_sym_id = 73,
  anon_sym_statement = 74,
  anon_sym_significance = 75,
  anon_sym_size = 76,
  anon_sym_alignment = 77,
  anon_sym_scope = 78,
  anon_sym_timeout_constant = 79,
  anon_sym_timeout_value = 80,
  anon_sym_DASH = 81,
  anon_sym_LT = 82,
  anon_sym_COMMA = 83,
  anon_sym_GT = 84,
  anon_sym_List = 85,
  anon_sym_Set = 86,
  anon_sym_Map = 87,
  anon_sym_Option = 88,
  anon_sym_Array = 89,
  anon_sym_Dict = 90,
  anon_sym_Tuple = 91,
  anon_sym_LBRACK = 92,
  anon_sym_RBRACK = 93,
  anon_sym_DQUOTE = 94,
  sym_string_content = 95,
  sym_escape_sequence = 96,
  anon_sym_DOLLAR_LBRACE = 97,
  anon_sym_RBRACE = 98,
  anon_sym_PIPE = 99,
  aux_sym_multiline_string_token1 = 100,
  sym_float_number = 101,
  sym_number = 102,
  anon_sym_true = 103,
  anon_sym_false = 104,
  anon_sym_null = 105,
  anon_sym_nil = 106,
  anon_sym_none = 107,
  sym_dotted_identifier = 108,
  sym_comment = 109,
  sym_source_file = 110,
  sym__entry = 111,
  sym_pair = 112,
  sym__key = 113,
  sym_section_keyword = 114,
  sym_type_keyword = 115,
  sym_behavior_keyword = 116,
  sym__value = 117,
  sym_list_item = 118,
  sym_type_expression = 119,
  sym_generic_type_name = 120,
  sym_type_argument = 121,
  sym_flow_sequence = 122,
  sym__flow_value = 123,
  sym_quoted_string = 124,
  sym_interpolation = 125,
  sym_multiline_string = 126,
  sym_boolean = 127,
  sym_null_value = 128,
  sym_identifier = 129,
  aux_sym_source_file_repeat1 = 130,
  aux_sym_type_expression_repeat1 = 131,
  aux_sym_flow_sequence_repeat1 = 132,
  aux_sym_quoted_string_repeat1 = 133,
};

static const char * const ts_symbol_names[] = {
  [ts_builtin_sym_end] = "end",
  [sym_plain_identifier] = "plain_identifier",
  [anon_sym_COLON] = ":",
  [anon_sym_name] = "name",
  [anon_sym_version] = "version",
  [anon_sym_language] = "language",
  [anon_sym_module] = "module",
  [anon_sym_description] = "description",
  [anon_sym_author] = "author",
  [anon_sym_license] = "license",
  [anon_sym_constants] = "constants",
  [anon_sym_types] = "types",
  [anon_sym_behaviors] = "behaviors",
  [anon_sym_algorithms] = "algorithms",
  [anon_sym_imports] = "imports",
  [anon_sym_creation_patterns] = "creation_patterns",
  [anon_sym_wasm_exports] = "wasm_exports",
  [anon_sym_pas_predictions] = "pas_predictions",
  [anon_sym_signals] = "signals",
  [anon_sym_fsm] = "fsm",
  [anon_sym_reset] = "reset",
  [anon_sym_test_cases] = "test_cases",
  [anon_sym_tests] = "tests",
  [anon_sym_cli] = "cli",
  [anon_sym_theorems] = "theorems",
  [anon_sym_targets] = "targets",
  [anon_sym_fpga_target] = "fpga_target",
  [anon_sym_pipeline] = "pipeline",
  [anon_sym_target_frequency] = "target_frequency",
  [anon_sym_fields] = "fields",
  [anon_sym_enum] = "enum",
  [anon_sym_constraints] = "constraints",
  [anon_sym_base] = "base",
  [anon_sym_generic] = "generic",
  [anon_sym_functions] = "functions",
  [anon_sym_memory] = "memory",
  [anon_sym_states] = "states",
  [anon_sym_transitions] = "transitions",
  [anon_sym_outputs] = "outputs",
  [anon_sym_timers] = "timers",
  [anon_sym_flags] = "flags",
  [anon_sym_given] = "given",
  [anon_sym_when] = "when",
  [anon_sym_then] = "then",
  [anon_sym_implementation] = "implementation",
  [anon_sym_input] = "input",
  [anon_sym_expected] = "expected",
  [anon_sym_tolerance] = "tolerance",
  [anon_sym_complexity] = "complexity",
  [anon_sym_pattern] = "pattern",
  [anon_sym_steps] = "steps",
  [anon_sym_formula] = "formula",
  [anon_sym_source] = "source",
  [anon_sym_transformer] = "transformer",
  [anon_sym_result] = "result",
  [anon_sym_target] = "target",
  [anon_sym_current] = "current",
  [anon_sym_predicted] = "predicted",
  [anon_sym_confidence] = "confidence",
  [anon_sym_status] = "status",
  [anon_sym_timeline] = "timeline",
  [anon_sym_width] = "width",
  [anon_sym_direction] = "direction",
  [anon_sym_signed] = "signed",
  [anon_sym_default] = "default",
  [anon_sym_initial] = "initial",
  [anon_sym_encoding] = "encoding",
  [anon_sym_from] = "from",
  [anon_sym_to] = "to",
  [anon_sym_type] = "type",
  [anon_sym_level] = "level",
  [anon_sym_short] = "short",
  [anon_sym_category] = "category",
  [anon_sym_id] = "id",
  [anon_sym_statement] = "statement",
  [anon_sym_significance] = "significance",
  [anon_sym_size] = "size",
  [anon_sym_alignment] = "alignment",
  [anon_sym_scope] = "scope",
  [anon_sym_timeout_constant] = "timeout_constant",
  [anon_sym_timeout_value] = "timeout_value",
  [anon_sym_DASH] = "-",
  [anon_sym_LT] = "<",
  [anon_sym_COMMA] = ",",
  [anon_sym_GT] = ">",
  [anon_sym_List] = "List",
  [anon_sym_Set] = "Set",
  [anon_sym_Map] = "Map",
  [anon_sym_Option] = "Option",
  [anon_sym_Array] = "Array",
  [anon_sym_Dict] = "Dict",
  [anon_sym_Tuple] = "Tuple",
  [anon_sym_LBRACK] = "[",
  [anon_sym_RBRACK] = "]",
  [anon_sym_DQUOTE] = "\"",
  [sym_string_content] = "string_content",
  [sym_escape_sequence] = "escape_sequence",
  [anon_sym_DOLLAR_LBRACE] = "${",
  [anon_sym_RBRACE] = "}",
  [anon_sym_PIPE] = "|",
  [aux_sym_multiline_string_token1] = "multiline_string_token1",
  [sym_float_number] = "float_number",
  [sym_number] = "number",
  [anon_sym_true] = "true",
  [anon_sym_false] = "false",
  [anon_sym_null] = "null",
  [anon_sym_nil] = "nil",
  [anon_sym_none] = "none",
  [sym_dotted_identifier] = "dotted_identifier",
  [sym_comment] = "comment",
  [sym_source_file] = "source_file",
  [sym__entry] = "_entry",
  [sym_pair] = "pair",
  [sym__key] = "_key",
  [sym_section_keyword] = "section_keyword",
  [sym_type_keyword] = "type_keyword",
  [sym_behavior_keyword] = "behavior_keyword",
  [sym__value] = "_value",
  [sym_list_item] = "list_item",
  [sym_type_expression] = "type_expression",
  [sym_generic_type_name] = "generic_type_name",
  [sym_type_argument] = "type_argument",
  [sym_flow_sequence] = "flow_sequence",
  [sym__flow_value] = "_flow_value",
  [sym_quoted_string] = "quoted_string",
  [sym_interpolation] = "interpolation",
  [sym_multiline_string] = "multiline_string",
  [sym_boolean] = "boolean",
  [sym_null_value] = "null_value",
  [sym_identifier] = "identifier",
  [aux_sym_source_file_repeat1] = "source_file_repeat1",
  [aux_sym_type_expression_repeat1] = "type_expression_repeat1",
  [aux_sym_flow_sequence_repeat1] = "flow_sequence_repeat1",
  [aux_sym_quoted_string_repeat1] = "quoted_string_repeat1",
};

static const TSSymbol ts_symbol_map[] = {
  [ts_builtin_sym_end] = ts_builtin_sym_end,
  [sym_plain_identifier] = sym_plain_identifier,
  [anon_sym_COLON] = anon_sym_COLON,
  [anon_sym_name] = anon_sym_name,
  [anon_sym_version] = anon_sym_version,
  [anon_sym_language] = anon_sym_language,
  [anon_sym_module] = anon_sym_module,
  [anon_sym_description] = anon_sym_description,
  [anon_sym_author] = anon_sym_author,
  [anon_sym_license] = anon_sym_license,
  [anon_sym_constants] = anon_sym_constants,
  [anon_sym_types] = anon_sym_types,
  [anon_sym_behaviors] = anon_sym_behaviors,
  [anon_sym_algorithms] = anon_sym_algorithms,
  [anon_sym_imports] = anon_sym_imports,
  [anon_sym_creation_patterns] = anon_sym_creation_patterns,
  [anon_sym_wasm_exports] = anon_sym_wasm_exports,
  [anon_sym_pas_predictions] = anon_sym_pas_predictions,
  [anon_sym_signals] = anon_sym_signals,
  [anon_sym_fsm] = anon_sym_fsm,
  [anon_sym_reset] = anon_sym_reset,
  [anon_sym_test_cases] = anon_sym_test_cases,
  [anon_sym_tests] = anon_sym_tests,
  [anon_sym_cli] = anon_sym_cli,
  [anon_sym_theorems] = anon_sym_theorems,
  [anon_sym_targets] = anon_sym_targets,
  [anon_sym_fpga_target] = anon_sym_fpga_target,
  [anon_sym_pipeline] = anon_sym_pipeline,
  [anon_sym_target_frequency] = anon_sym_target_frequency,
  [anon_sym_fields] = anon_sym_fields,
  [anon_sym_enum] = anon_sym_enum,
  [anon_sym_constraints] = anon_sym_constraints,
  [anon_sym_base] = anon_sym_base,
  [anon_sym_generic] = anon_sym_generic,
  [anon_sym_functions] = anon_sym_functions,
  [anon_sym_memory] = anon_sym_memory,
  [anon_sym_states] = anon_sym_states,
  [anon_sym_transitions] = anon_sym_transitions,
  [anon_sym_outputs] = anon_sym_outputs,
  [anon_sym_timers] = anon_sym_timers,
  [anon_sym_flags] = anon_sym_flags,
  [anon_sym_given] = anon_sym_given,
  [anon_sym_when] = anon_sym_when,
  [anon_sym_then] = anon_sym_then,
  [anon_sym_implementation] = anon_sym_implementation,
  [anon_sym_input] = anon_sym_input,
  [anon_sym_expected] = anon_sym_expected,
  [anon_sym_tolerance] = anon_sym_tolerance,
  [anon_sym_complexity] = anon_sym_complexity,
  [anon_sym_pattern] = anon_sym_pattern,
  [anon_sym_steps] = anon_sym_steps,
  [anon_sym_formula] = anon_sym_formula,
  [anon_sym_source] = anon_sym_source,
  [anon_sym_transformer] = anon_sym_transformer,
  [anon_sym_result] = anon_sym_result,
  [anon_sym_target] = anon_sym_target,
  [anon_sym_current] = anon_sym_current,
  [anon_sym_predicted] = anon_sym_predicted,
  [anon_sym_confidence] = anon_sym_confidence,
  [anon_sym_status] = anon_sym_status,
  [anon_sym_timeline] = anon_sym_timeline,
  [anon_sym_width] = anon_sym_width,
  [anon_sym_direction] = anon_sym_direction,
  [anon_sym_signed] = anon_sym_signed,
  [anon_sym_default] = anon_sym_default,
  [anon_sym_initial] = anon_sym_initial,
  [anon_sym_encoding] = anon_sym_encoding,
  [anon_sym_from] = anon_sym_from,
  [anon_sym_to] = anon_sym_to,
  [anon_sym_type] = anon_sym_type,
  [anon_sym_level] = anon_sym_level,
  [anon_sym_short] = anon_sym_short,
  [anon_sym_category] = anon_sym_category,
  [anon_sym_id] = anon_sym_id,
  [anon_sym_statement] = anon_sym_statement,
  [anon_sym_significance] = anon_sym_significance,
  [anon_sym_size] = anon_sym_size,
  [anon_sym_alignment] = anon_sym_alignment,
  [anon_sym_scope] = anon_sym_scope,
  [anon_sym_timeout_constant] = anon_sym_timeout_constant,
  [anon_sym_timeout_value] = anon_sym_timeout_value,
  [anon_sym_DASH] = anon_sym_DASH,
  [anon_sym_LT] = anon_sym_LT,
  [anon_sym_COMMA] = anon_sym_COMMA,
  [anon_sym_GT] = anon_sym_GT,
  [anon_sym_List] = anon_sym_List,
  [anon_sym_Set] = anon_sym_Set,
  [anon_sym_Map] = anon_sym_Map,
  [anon_sym_Option] = anon_sym_Option,
  [anon_sym_Array] = anon_sym_Array,
  [anon_sym_Dict] = anon_sym_Dict,
  [anon_sym_Tuple] = anon_sym_Tuple,
  [anon_sym_LBRACK] = anon_sym_LBRACK,
  [anon_sym_RBRACK] = anon_sym_RBRACK,
  [anon_sym_DQUOTE] = anon_sym_DQUOTE,
  [sym_string_content] = sym_string_content,
  [sym_escape_sequence] = sym_escape_sequence,
  [anon_sym_DOLLAR_LBRACE] = anon_sym_DOLLAR_LBRACE,
  [anon_sym_RBRACE] = anon_sym_RBRACE,
  [anon_sym_PIPE] = anon_sym_PIPE,
  [aux_sym_multiline_string_token1] = aux_sym_multiline_string_token1,
  [sym_float_number] = sym_float_number,
  [sym_number] = sym_number,
  [anon_sym_true] = anon_sym_true,
  [anon_sym_false] = anon_sym_false,
  [anon_sym_null] = anon_sym_null,
  [anon_sym_nil] = anon_sym_nil,
  [anon_sym_none] = anon_sym_none,
  [sym_dotted_identifier] = sym_dotted_identifier,
  [sym_comment] = sym_comment,
  [sym_source_file] = sym_source_file,
  [sym__entry] = sym__entry,
  [sym_pair] = sym_pair,
  [sym__key] = sym__key,
  [sym_section_keyword] = sym_section_keyword,
  [sym_type_keyword] = sym_type_keyword,
  [sym_behavior_keyword] = sym_behavior_keyword,
  [sym__value] = sym__value,
  [sym_list_item] = sym_list_item,
  [sym_type_expression] = sym_type_expression,
  [sym_generic_type_name] = sym_generic_type_name,
  [sym_type_argument] = sym_type_argument,
  [sym_flow_sequence] = sym_flow_sequence,
  [sym__flow_value] = sym__flow_value,
  [sym_quoted_string] = sym_quoted_string,
  [sym_interpolation] = sym_interpolation,
  [sym_multiline_string] = sym_multiline_string,
  [sym_boolean] = sym_boolean,
  [sym_null_value] = sym_null_value,
  [sym_identifier] = sym_identifier,
  [aux_sym_source_file_repeat1] = aux_sym_source_file_repeat1,
  [aux_sym_type_expression_repeat1] = aux_sym_type_expression_repeat1,
  [aux_sym_flow_sequence_repeat1] = aux_sym_flow_sequence_repeat1,
  [aux_sym_quoted_string_repeat1] = aux_sym_quoted_string_repeat1,
};

static const TSSymbolMetadata ts_symbol_metadata[] = {
  [ts_builtin_sym_end] = {
    .visible = false,
    .named = true,
  },
  [sym_plain_identifier] = {
    .visible = true,
    .named = true,
  },
  [anon_sym_COLON] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_name] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_version] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_language] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_module] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_description] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_author] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_license] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_constants] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_types] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_behaviors] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_algorithms] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_imports] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_creation_patterns] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_wasm_exports] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_pas_predictions] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_signals] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_fsm] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_reset] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_test_cases] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_tests] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_cli] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_theorems] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_targets] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_fpga_target] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_pipeline] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_target_frequency] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_fields] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_enum] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_constraints] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_base] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_generic] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_functions] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_memory] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_states] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_transitions] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_outputs] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_timers] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_flags] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_given] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_when] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_then] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_implementation] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_input] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_expected] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_tolerance] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_complexity] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_pattern] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_steps] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_formula] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_source] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_transformer] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_result] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_target] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_current] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_predicted] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_confidence] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_status] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_timeline] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_width] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_direction] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_signed] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_default] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_initial] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_encoding] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_from] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_to] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_type] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_level] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_short] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_category] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_id] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_statement] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_significance] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_size] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_alignment] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_scope] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_timeout_constant] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_timeout_value] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_DASH] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_LT] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_COMMA] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_GT] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_List] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_Set] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_Map] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_Option] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_Array] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_Dict] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_Tuple] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_LBRACK] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_RBRACK] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_DQUOTE] = {
    .visible = true,
    .named = false,
  },
  [sym_string_content] = {
    .visible = true,
    .named = true,
  },
  [sym_escape_sequence] = {
    .visible = true,
    .named = true,
  },
  [anon_sym_DOLLAR_LBRACE] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_RBRACE] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_PIPE] = {
    .visible = true,
    .named = false,
  },
  [aux_sym_multiline_string_token1] = {
    .visible = false,
    .named = false,
  },
  [sym_float_number] = {
    .visible = true,
    .named = true,
  },
  [sym_number] = {
    .visible = true,
    .named = true,
  },
  [anon_sym_true] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_false] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_null] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_nil] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_none] = {
    .visible = true,
    .named = false,
  },
  [sym_dotted_identifier] = {
    .visible = true,
    .named = true,
  },
  [sym_comment] = {
    .visible = true,
    .named = true,
  },
  [sym_source_file] = {
    .visible = true,
    .named = true,
  },
  [sym__entry] = {
    .visible = false,
    .named = true,
  },
  [sym_pair] = {
    .visible = true,
    .named = true,
  },
  [sym__key] = {
    .visible = false,
    .named = true,
  },
  [sym_section_keyword] = {
    .visible = true,
    .named = true,
  },
  [sym_type_keyword] = {
    .visible = true,
    .named = true,
  },
  [sym_behavior_keyword] = {
    .visible = true,
    .named = true,
  },
  [sym__value] = {
    .visible = false,
    .named = true,
  },
  [sym_list_item] = {
    .visible = true,
    .named = true,
  },
  [sym_type_expression] = {
    .visible = true,
    .named = true,
  },
  [sym_generic_type_name] = {
    .visible = true,
    .named = true,
  },
  [sym_type_argument] = {
    .visible = true,
    .named = true,
  },
  [sym_flow_sequence] = {
    .visible = true,
    .named = true,
  },
  [sym__flow_value] = {
    .visible = false,
    .named = true,
  },
  [sym_quoted_string] = {
    .visible = true,
    .named = true,
  },
  [sym_interpolation] = {
    .visible = true,
    .named = true,
  },
  [sym_multiline_string] = {
    .visible = true,
    .named = true,
  },
  [sym_boolean] = {
    .visible = true,
    .named = true,
  },
  [sym_null_value] = {
    .visible = true,
    .named = true,
  },
  [sym_identifier] = {
    .visible = true,
    .named = true,
  },
  [aux_sym_source_file_repeat1] = {
    .visible = false,
    .named = false,
  },
  [aux_sym_type_expression_repeat1] = {
    .visible = false,
    .named = false,
  },
  [aux_sym_flow_sequence_repeat1] = {
    .visible = false,
    .named = false,
  },
  [aux_sym_quoted_string_repeat1] = {
    .visible = false,
    .named = false,
  },
};

enum ts_field_identifiers {
  field_key = 1,
  field_name = 2,
  field_value = 3,
};

static const char * const ts_field_names[] = {
  [0] = NULL,
  [field_key] = "key",
  [field_name] = "name",
  [field_value] = "value",
};

static const TSFieldMapSlice ts_field_map_slices[PRODUCTION_ID_COUNT] = {
  [1] = {.index = 0, .length = 1},
  [2] = {.index = 1, .length = 2},
  [3] = {.index = 3, .length = 1},
};

static const TSFieldMapEntry ts_field_map_entries[] = {
  [0] =
    {field_key, 0},
  [1] =
    {field_key, 0},
    {field_value, 2},
  [3] =
    {field_name, 0},
};

static const TSSymbol ts_alias_sequences[PRODUCTION_ID_COUNT][MAX_ALIAS_SEQUENCE_LENGTH] = {
  [0] = {0},
};

static const uint16_t ts_non_terminal_alias_map[] = {
  0,
};

static const TSStateId ts_primary_state_ids[STATE_COUNT] = {
  [0] = 0,
  [1] = 1,
  [2] = 2,
  [3] = 3,
  [4] = 4,
  [5] = 5,
  [6] = 6,
  [7] = 7,
  [8] = 8,
  [9] = 9,
  [10] = 10,
  [11] = 11,
  [12] = 12,
  [13] = 13,
  [14] = 14,
  [15] = 15,
  [16] = 16,
  [17] = 17,
  [18] = 18,
  [19] = 19,
  [20] = 20,
  [21] = 21,
  [22] = 22,
  [23] = 23,
  [24] = 24,
  [25] = 25,
  [26] = 26,
  [27] = 27,
  [28] = 28,
  [29] = 29,
  [30] = 30,
  [31] = 31,
  [32] = 32,
  [33] = 33,
  [34] = 34,
  [35] = 35,
  [36] = 36,
  [37] = 37,
  [38] = 38,
  [39] = 39,
  [40] = 40,
  [41] = 41,
  [42] = 42,
  [43] = 43,
  [44] = 44,
  [45] = 45,
  [46] = 46,
  [47] = 47,
  [48] = 48,
  [49] = 49,
  [50] = 50,
};

static bool ts_lex(TSLexer *lexer, TSStateId state) {
  START_LEXER();
  eof = lexer->eof(lexer);
  switch (state) {
    case 0:
      if (eof) ADVANCE(16);
      ADVANCE_MAP(
        '"', 24,
        '#', 39,
        '$', 3,
        ',', 20,
        '-', 18,
        ':', 17,
        '<', 19,
        '>', 21,
        '[', 22,
        '\\', 2,
        ']', 23,
        '|', 32,
        '}', 31,
      );
      if (('\t' <= lookahead && lookahead <= '\r') ||
          lookahead == ' ') SKIP(15);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(36);
      if (('A' <= lookahead && lookahead <= 'Z') ||
          lookahead == '_' ||
          ('a' <= lookahead && lookahead <= 'z')) ADVANCE(37);
      END_STATE();
    case 1:
      if (lookahead == '"') ADVANCE(24);
      if (lookahead == '#') ADVANCE(26);
      if (lookahead == '$') ADVANCE(4);
      if (lookahead == '\\') ADVANCE(2);
      if (('\t' <= lookahead && lookahead <= '\r') ||
          lookahead == ' ') ADVANCE(27);
      if (lookahead != 0) ADVANCE(28);
      END_STATE();
    case 2:
      ADVANCE_MAP(
        'U', 13,
        'u', 9,
        'x', 7,
        '"', 29,
        '\'', 29,
        '/', 29,
        '0', 29,
        '\\', 29,
        'a', 29,
        'b', 29,
        'f', 29,
        'n', 29,
        'r', 29,
        't', 29,
        'v', 29,
      );
      END_STATE();
    case 3:
      if (lookahead == '{') ADVANCE(30);
      END_STATE();
    case 4:
      if (lookahead == '{') ADVANCE(30);
      if (lookahead != 0 &&
          lookahead != '"') ADVANCE(25);
      END_STATE();
    case 5:
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(35);
      END_STATE();
    case 6:
      if (('0' <= lookahead && lookahead <= '9') ||
          ('A' <= lookahead && lookahead <= 'F') ||
          ('a' <= lookahead && lookahead <= 'f')) ADVANCE(29);
      END_STATE();
    case 7:
      if (('0' <= lookahead && lookahead <= '9') ||
          ('A' <= lookahead && lookahead <= 'F') ||
          ('a' <= lookahead && lookahead <= 'f')) ADVANCE(6);
      END_STATE();
    case 8:
      if (('0' <= lookahead && lookahead <= '9') ||
          ('A' <= lookahead && lookahead <= 'F') ||
          ('a' <= lookahead && lookahead <= 'f')) ADVANCE(7);
      END_STATE();
    case 9:
      if (('0' <= lookahead && lookahead <= '9') ||
          ('A' <= lookahead && lookahead <= 'F') ||
          ('a' <= lookahead && lookahead <= 'f')) ADVANCE(8);
      END_STATE();
    case 10:
      if (('0' <= lookahead && lookahead <= '9') ||
          ('A' <= lookahead && lookahead <= 'F') ||
          ('a' <= lookahead && lookahead <= 'f')) ADVANCE(9);
      END_STATE();
    case 11:
      if (('0' <= lookahead && lookahead <= '9') ||
          ('A' <= lookahead && lookahead <= 'F') ||
          ('a' <= lookahead && lookahead <= 'f')) ADVANCE(10);
      END_STATE();
    case 12:
      if (('0' <= lookahead && lookahead <= '9') ||
          ('A' <= lookahead && lookahead <= 'F') ||
          ('a' <= lookahead && lookahead <= 'f')) ADVANCE(11);
      END_STATE();
    case 13:
      if (('0' <= lookahead && lookahead <= '9') ||
          ('A' <= lookahead && lookahead <= 'F') ||
          ('a' <= lookahead && lookahead <= 'f')) ADVANCE(12);
      END_STATE();
    case 14:
      if (('A' <= lookahead && lookahead <= 'Z') ||
          lookahead == '_' ||
          ('a' <= lookahead && lookahead <= 'z')) ADVANCE(38);
      END_STATE();
    case 15:
      if (eof) ADVANCE(16);
      ADVANCE_MAP(
        '"', 24,
        '#', 39,
        ',', 20,
        '-', 18,
        ':', 17,
        '<', 19,
        '>', 21,
        '[', 22,
        ']', 23,
        '|', 32,
        '}', 31,
      );
      if (('\t' <= lookahead && lookahead <= '\r') ||
          lookahead == ' ') SKIP(15);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(36);
      if (('A' <= lookahead && lookahead <= 'Z') ||
          lookahead == '_' ||
          ('a' <= lookahead && lookahead <= 'z')) ADVANCE(37);
      END_STATE();
    case 16:
      ACCEPT_TOKEN(ts_builtin_sym_end);
      END_STATE();
    case 17:
      ACCEPT_TOKEN(anon_sym_COLON);
      END_STATE();
    case 18:
      ACCEPT_TOKEN(anon_sym_DASH);
      END_STATE();
    case 19:
      ACCEPT_TOKEN(anon_sym_LT);
      END_STATE();
    case 20:
      ACCEPT_TOKEN(anon_sym_COMMA);
      END_STATE();
    case 21:
      ACCEPT_TOKEN(anon_sym_GT);
      END_STATE();
    case 22:
      ACCEPT_TOKEN(anon_sym_LBRACK);
      END_STATE();
    case 23:
      ACCEPT_TOKEN(anon_sym_RBRACK);
      END_STATE();
    case 24:
      ACCEPT_TOKEN(anon_sym_DQUOTE);
      END_STATE();
    case 25:
      ACCEPT_TOKEN(sym_string_content);
      END_STATE();
    case 26:
      ACCEPT_TOKEN(sym_string_content);
      if (lookahead == '\n') ADVANCE(28);
      if (lookahead == '"' ||
          lookahead == '$' ||
          lookahead == '\\') ADVANCE(39);
      if (lookahead != 0) ADVANCE(26);
      END_STATE();
    case 27:
      ACCEPT_TOKEN(sym_string_content);
      if (lookahead == '#') ADVANCE(26);
      if (('\t' <= lookahead && lookahead <= '\r') ||
          lookahead == ' ') ADVANCE(27);
      if (lookahead != 0 &&
          (lookahead < '"' || '$' < lookahead) &&
          lookahead != '\\') ADVANCE(28);
      END_STATE();
    case 28:
      ACCEPT_TOKEN(sym_string_content);
      if (lookahead != 0 &&
          lookahead != '"' &&
          lookahead != '$' &&
          lookahead != '\\') ADVANCE(28);
      END_STATE();
    case 29:
      ACCEPT_TOKEN(sym_escape_sequence);
      END_STATE();
    case 30:
      ACCEPT_TOKEN(anon_sym_DOLLAR_LBRACE);
      END_STATE();
    case 31:
      ACCEPT_TOKEN(anon_sym_RBRACE);
      END_STATE();
    case 32:
      ACCEPT_TOKEN(anon_sym_PIPE);
      END_STATE();
    case 33:
      ACCEPT_TOKEN(aux_sym_multiline_string_token1);
      if (lookahead == '#') ADVANCE(34);
      if (lookahead == '\t' ||
          (0x0b <= lookahead && lookahead <= '\r') ||
          lookahead == ' ') ADVANCE(33);
      if (lookahead != 0 &&
          (lookahead < '\t' || '\r' < lookahead)) ADVANCE(34);
      END_STATE();
    case 34:
      ACCEPT_TOKEN(aux_sym_multiline_string_token1);
      if (lookahead != 0 &&
          lookahead != '\n') ADVANCE(34);
      END_STATE();
    case 35:
      ACCEPT_TOKEN(sym_float_number);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(35);
      END_STATE();
    case 36:
      ACCEPT_TOKEN(sym_number);
      if (lookahead == '.') ADVANCE(5);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(36);
      END_STATE();
    case 37:
      ACCEPT_TOKEN(sym_plain_identifier);
      if (lookahead == '.') ADVANCE(14);
      if (('0' <= lookahead && lookahead <= '9') ||
          ('A' <= lookahead && lookahead <= 'Z') ||
          lookahead == '_' ||
          ('a' <= lookahead && lookahead <= 'z')) ADVANCE(37);
      END_STATE();
    case 38:
      ACCEPT_TOKEN(sym_dotted_identifier);
      if (lookahead == '.') ADVANCE(14);
      if (('0' <= lookahead && lookahead <= '9') ||
          ('A' <= lookahead && lookahead <= 'Z') ||
          lookahead == '_' ||
          ('a' <= lookahead && lookahead <= 'z')) ADVANCE(38);
      END_STATE();
    case 39:
      ACCEPT_TOKEN(sym_comment);
      if (lookahead != 0 &&
          lookahead != '\n') ADVANCE(39);
      END_STATE();
    default:
      return false;
  }
}

static bool ts_lex_keywords(TSLexer *lexer, TSStateId state) {
  START_LEXER();
  eof = lexer->eof(lexer);
  switch (state) {
    case 0:
      ADVANCE_MAP(
        'A', 1,
        'D', 2,
        'L', 3,
        'M', 4,
        'O', 5,
        'S', 6,
        'T', 7,
        'a', 8,
        'b', 9,
        'c', 10,
        'd', 11,
        'e', 12,
        'f', 13,
        'g', 14,
        'i', 15,
        'l', 16,
        'm', 17,
        'n', 18,
        'o', 19,
        'p', 20,
        'r', 21,
        's', 22,
        't', 23,
        'v', 24,
        'w', 25,
      );
      if (('\t' <= lookahead && lookahead <= '\r') ||
          lookahead == ' ') SKIP(0);
      END_STATE();
    case 1:
      if (lookahead == 'r') ADVANCE(26);
      END_STATE();
    case 2:
      if (lookahead == 'i') ADVANCE(27);
      END_STATE();
    case 3:
      if (lookahead == 'i') ADVANCE(28);
      END_STATE();
    case 4:
      if (lookahead == 'a') ADVANCE(29);
      END_STATE();
    case 5:
      if (lookahead == 'p') ADVANCE(30);
      END_STATE();
    case 6:
      if (lookahead == 'e') ADVANCE(31);
      END_STATE();
    case 7:
      if (lookahead == 'u') ADVANCE(32);
      END_STATE();
    case 8:
      if (lookahead == 'l') ADVANCE(33);
      if (lookahead == 'u') ADVANCE(34);
      END_STATE();
    case 9:
      if (lookahead == 'a') ADVANCE(35);
      if (lookahead == 'e') ADVANCE(36);
      END_STATE();
    case 10:
      if (lookahead == 'a') ADVANCE(37);
      if (lookahead == 'l') ADVANCE(38);
      if (lookahead == 'o') ADVANCE(39);
      if (lookahead == 'r') ADVANCE(40);
      if (lookahead == 'u') ADVANCE(41);
      END_STATE();
    case 11:
      if (lookahead == 'e') ADVANCE(42);
      if (lookahead == 'i') ADVANCE(43);
      END_STATE();
    case 12:
      if (lookahead == 'n') ADVANCE(44);
      if (lookahead == 'x') ADVANCE(45);
      END_STATE();
    case 13:
      ADVANCE_MAP(
        'a', 46,
        'i', 47,
        'l', 48,
        'o', 49,
        'p', 50,
        'r', 51,
        's', 52,
        'u', 53,
      );
      END_STATE();
    case 14:
      if (lookahead == 'e') ADVANCE(54);
      if (lookahead == 'i') ADVANCE(55);
      END_STATE();
    case 15:
      if (lookahead == 'd') ADVANCE(56);
      if (lookahead == 'm') ADVANCE(57);
      if (lookahead == 'n') ADVANCE(58);
      END_STATE();
    case 16:
      if (lookahead == 'a') ADVANCE(59);
      if (lookahead == 'e') ADVANCE(60);
      if (lookahead == 'i') ADVANCE(61);
      END_STATE();
    case 17:
      if (lookahead == 'e') ADVANCE(62);
      if (lookahead == 'o') ADVANCE(63);
      END_STATE();
    case 18:
      if (lookahead == 'a') ADVANCE(64);
      if (lookahead == 'i') ADVANCE(65);
      if (lookahead == 'o') ADVANCE(66);
      if (lookahead == 'u') ADVANCE(67);
      END_STATE();
    case 19:
      if (lookahead == 'u') ADVANCE(68);
      END_STATE();
    case 20:
      if (lookahead == 'a') ADVANCE(69);
      if (lookahead == 'i') ADVANCE(70);
      if (lookahead == 'r') ADVANCE(71);
      END_STATE();
    case 21:
      if (lookahead == 'e') ADVANCE(72);
      END_STATE();
    case 22:
      if (lookahead == 'c') ADVANCE(73);
      if (lookahead == 'h') ADVANCE(74);
      if (lookahead == 'i') ADVANCE(75);
      if (lookahead == 'o') ADVANCE(76);
      if (lookahead == 't') ADVANCE(77);
      END_STATE();
    case 23:
      if (lookahead == 'a') ADVANCE(78);
      if (lookahead == 'e') ADVANCE(79);
      if (lookahead == 'h') ADVANCE(80);
      if (lookahead == 'i') ADVANCE(81);
      if (lookahead == 'o') ADVANCE(82);
      if (lookahead == 'r') ADVANCE(83);
      if (lookahead == 'y') ADVANCE(84);
      END_STATE();
    case 24:
      if (lookahead == 'e') ADVANCE(85);
      END_STATE();
    case 25:
      if (lookahead == 'a') ADVANCE(86);
      if (lookahead == 'h') ADVANCE(87);
      if (lookahead == 'i') ADVANCE(88);
      END_STATE();
    case 26:
      if (lookahead == 'r') ADVANCE(89);
      END_STATE();
    case 27:
      if (lookahead == 'c') ADVANCE(90);
      END_STATE();
    case 28:
      if (lookahead == 's') ADVANCE(91);
      END_STATE();
    case 29:
      if (lookahead == 'p') ADVANCE(92);
      END_STATE();
    case 30:
      if (lookahead == 't') ADVANCE(93);
      END_STATE();
    case 31:
      if (lookahead == 't') ADVANCE(94);
      END_STATE();
    case 32:
      if (lookahead == 'p') ADVANCE(95);
      END_STATE();
    case 33:
      if (lookahead == 'g') ADVANCE(96);
      if (lookahead == 'i') ADVANCE(97);
      END_STATE();
    case 34:
      if (lookahead == 't') ADVANCE(98);
      END_STATE();
    case 35:
      if (lookahead == 's') ADVANCE(99);
      END_STATE();
    case 36:
      if (lookahead == 'h') ADVANCE(100);
      END_STATE();
    case 37:
      if (lookahead == 't') ADVANCE(101);
      END_STATE();
    case 38:
      if (lookahead == 'i') ADVANCE(102);
      END_STATE();
    case 39:
      if (lookahead == 'm') ADVANCE(103);
      if (lookahead == 'n') ADVANCE(104);
      END_STATE();
    case 40:
      if (lookahead == 'e') ADVANCE(105);
      END_STATE();
    case 41:
      if (lookahead == 'r') ADVANCE(106);
      END_STATE();
    case 42:
      if (lookahead == 'f') ADVANCE(107);
      if (lookahead == 's') ADVANCE(108);
      END_STATE();
    case 43:
      if (lookahead == 'r') ADVANCE(109);
      END_STATE();
    case 44:
      if (lookahead == 'c') ADVANCE(110);
      if (lookahead == 'u') ADVANCE(111);
      END_STATE();
    case 45:
      if (lookahead == 'p') ADVANCE(112);
      END_STATE();
    case 46:
      if (lookahead == 'l') ADVANCE(113);
      END_STATE();
    case 47:
      if (lookahead == 'e') ADVANCE(114);
      END_STATE();
    case 48:
      if (lookahead == 'a') ADVANCE(115);
      END_STATE();
    case 49:
      if (lookahead == 'r') ADVANCE(116);
      END_STATE();
    case 50:
      if (lookahead == 'g') ADVANCE(117);
      END_STATE();
    case 51:
      if (lookahead == 'o') ADVANCE(118);
      END_STATE();
    case 52:
      if (lookahead == 'm') ADVANCE(119);
      END_STATE();
    case 53:
      if (lookahead == 'n') ADVANCE(120);
      END_STATE();
    case 54:
      if (lookahead == 'n') ADVANCE(121);
      END_STATE();
    case 55:
      if (lookahead == 'v') ADVANCE(122);
      END_STATE();
    case 56:
      ACCEPT_TOKEN(anon_sym_id);
      END_STATE();
    case 57:
      if (lookahead == 'p') ADVANCE(123);
      END_STATE();
    case 58:
      if (lookahead == 'i') ADVANCE(124);
      if (lookahead == 'p') ADVANCE(125);
      END_STATE();
    case 59:
      if (lookahead == 'n') ADVANCE(126);
      END_STATE();
    case 60:
      if (lookahead == 'v') ADVANCE(127);
      END_STATE();
    case 61:
      if (lookahead == 'c') ADVANCE(128);
      END_STATE();
    case 62:
      if (lookahead == 'm') ADVANCE(129);
      END_STATE();
    case 63:
      if (lookahead == 'd') ADVANCE(130);
      END_STATE();
    case 64:
      if (lookahead == 'm') ADVANCE(131);
      END_STATE();
    case 65:
      if (lookahead == 'l') ADVANCE(132);
      END_STATE();
    case 66:
      if (lookahead == 'n') ADVANCE(133);
      END_STATE();
    case 67:
      if (lookahead == 'l') ADVANCE(134);
      END_STATE();
    case 68:
      if (lookahead == 't') ADVANCE(135);
      END_STATE();
    case 69:
      if (lookahead == 's') ADVANCE(136);
      if (lookahead == 't') ADVANCE(137);
      END_STATE();
    case 70:
      if (lookahead == 'p') ADVANCE(138);
      END_STATE();
    case 71:
      if (lookahead == 'e') ADVANCE(139);
      END_STATE();
    case 72:
      if (lookahead == 's') ADVANCE(140);
      END_STATE();
    case 73:
      if (lookahead == 'o') ADVANCE(141);
      END_STATE();
    case 74:
      if (lookahead == 'o') ADVANCE(142);
      END_STATE();
    case 75:
      if (lookahead == 'g') ADVANCE(143);
      if (lookahead == 'z') ADVANCE(144);
      END_STATE();
    case 76:
      if (lookahead == 'u') ADVANCE(145);
      END_STATE();
    case 77:
      if (lookahead == 'a') ADVANCE(146);
      if (lookahead == 'e') ADVANCE(147);
      END_STATE();
    case 78:
      if (lookahead == 'r') ADVANCE(148);
      END_STATE();
    case 79:
      if (lookahead == 's') ADVANCE(149);
      END_STATE();
    case 80:
      if (lookahead == 'e') ADVANCE(150);
      END_STATE();
    case 81:
      if (lookahead == 'm') ADVANCE(151);
      END_STATE();
    case 82:
      ACCEPT_TOKEN(anon_sym_to);
      if (lookahead == 'l') ADVANCE(152);
      END_STATE();
    case 83:
      if (lookahead == 'a') ADVANCE(153);
      if (lookahead == 'u') ADVANCE(154);
      END_STATE();
    case 84:
      if (lookahead == 'p') ADVANCE(155);
      END_STATE();
    case 85:
      if (lookahead == 'r') ADVANCE(156);
      END_STATE();
    case 86:
      if (lookahead == 's') ADVANCE(157);
      END_STATE();
    case 87:
      if (lookahead == 'e') ADVANCE(158);
      END_STATE();
    case 88:
      if (lookahead == 'd') ADVANCE(159);
      END_STATE();
    case 89:
      if (lookahead == 'a') ADVANCE(160);
      END_STATE();
    case 90:
      if (lookahead == 't') ADVANCE(161);
      END_STATE();
    case 91:
      if (lookahead == 't') ADVANCE(162);
      END_STATE();
    case 92:
      ACCEPT_TOKEN(anon_sym_Map);
      END_STATE();
    case 93:
      if (lookahead == 'i') ADVANCE(163);
      END_STATE();
    case 94:
      ACCEPT_TOKEN(anon_sym_Set);
      END_STATE();
    case 95:
      if (lookahead == 'l') ADVANCE(164);
      END_STATE();
    case 96:
      if (lookahead == 'o') ADVANCE(165);
      END_STATE();
    case 97:
      if (lookahead == 'g') ADVANCE(166);
      END_STATE();
    case 98:
      if (lookahead == 'h') ADVANCE(167);
      END_STATE();
    case 99:
      if (lookahead == 'e') ADVANCE(168);
      END_STATE();
    case 100:
      if (lookahead == 'a') ADVANCE(169);
      END_STATE();
    case 101:
      if (lookahead == 'e') ADVANCE(170);
      END_STATE();
    case 102:
      ACCEPT_TOKEN(anon_sym_cli);
      END_STATE();
    case 103:
      if (lookahead == 'p') ADVANCE(171);
      END_STATE();
    case 104:
      if (lookahead == 'f') ADVANCE(172);
      if (lookahead == 's') ADVANCE(173);
      END_STATE();
    case 105:
      if (lookahead == 'a') ADVANCE(174);
      END_STATE();
    case 106:
      if (lookahead == 'r') ADVANCE(175);
      END_STATE();
    case 107:
      if (lookahead == 'a') ADVANCE(176);
      END_STATE();
    case 108:
      if (lookahead == 'c') ADVANCE(177);
      END_STATE();
    case 109:
      if (lookahead == 'e') ADVANCE(178);
      END_STATE();
    case 110:
      if (lookahead == 'o') ADVANCE(179);
      END_STATE();
    case 111:
      if (lookahead == 'm') ADVANCE(180);
      END_STATE();
    case 112:
      if (lookahead == 'e') ADVANCE(181);
      END_STATE();
    case 113:
      if (lookahead == 's') ADVANCE(182);
      END_STATE();
    case 114:
      if (lookahead == 'l') ADVANCE(183);
      END_STATE();
    case 115:
      if (lookahead == 'g') ADVANCE(184);
      END_STATE();
    case 116:
      if (lookahead == 'm') ADVANCE(185);
      END_STATE();
    case 117:
      if (lookahead == 'a') ADVANCE(186);
      END_STATE();
    case 118:
      if (lookahead == 'm') ADVANCE(187);
      END_STATE();
    case 119:
      ACCEPT_TOKEN(anon_sym_fsm);
      END_STATE();
    case 120:
      if (lookahead == 'c') ADVANCE(188);
      END_STATE();
    case 121:
      if (lookahead == 'e') ADVANCE(189);
      END_STATE();
    case 122:
      if (lookahead == 'e') ADVANCE(190);
      END_STATE();
    case 123:
      if (lookahead == 'l') ADVANCE(191);
      if (lookahead == 'o') ADVANCE(192);
      END_STATE();
    case 124:
      if (lookahead == 't') ADVANCE(193);
      END_STATE();
    case 125:
      if (lookahead == 'u') ADVANCE(194);
      END_STATE();
    case 126:
      if (lookahead == 'g') ADVANCE(195);
      END_STATE();
    case 127:
      if (lookahead == 'e') ADVANCE(196);
      END_STATE();
    case 128:
      if (lookahead == 'e') ADVANCE(197);
      END_STATE();
    case 129:
      if (lookahead == 'o') ADVANCE(198);
      END_STATE();
    case 130:
      if (lookahead == 'u') ADVANCE(199);
      END_STATE();
    case 131:
      if (lookahead == 'e') ADVANCE(200);
      END_STATE();
    case 132:
      ACCEPT_TOKEN(anon_sym_nil);
      END_STATE();
    case 133:
      if (lookahead == 'e') ADVANCE(201);
      END_STATE();
    case 134:
      if (lookahead == 'l') ADVANCE(202);
      END_STATE();
    case 135:
      if (lookahead == 'p') ADVANCE(203);
      END_STATE();
    case 136:
      if (lookahead == '_') ADVANCE(204);
      END_STATE();
    case 137:
      if (lookahead == 't') ADVANCE(205);
      END_STATE();
    case 138:
      if (lookahead == 'e') ADVANCE(206);
      END_STATE();
    case 139:
      if (lookahead == 'd') ADVANCE(207);
      END_STATE();
    case 140:
      if (lookahead == 'e') ADVANCE(208);
      if (lookahead == 'u') ADVANCE(209);
      END_STATE();
    case 141:
      if (lookahead == 'p') ADVANCE(210);
      END_STATE();
    case 142:
      if (lookahead == 'r') ADVANCE(211);
      END_STATE();
    case 143:
      if (lookahead == 'n') ADVANCE(212);
      END_STATE();
    case 144:
      if (lookahead == 'e') ADVANCE(213);
      END_STATE();
    case 145:
      if (lookahead == 'r') ADVANCE(214);
      END_STATE();
    case 146:
      if (lookahead == 't') ADVANCE(215);
      END_STATE();
    case 147:
      if (lookahead == 'p') ADVANCE(216);
      END_STATE();
    case 148:
      if (lookahead == 'g') ADVANCE(217);
      END_STATE();
    case 149:
      if (lookahead == 't') ADVANCE(218);
      END_STATE();
    case 150:
      if (lookahead == 'n') ADVANCE(219);
      if (lookahead == 'o') ADVANCE(220);
      END_STATE();
    case 151:
      if (lookahead == 'e') ADVANCE(221);
      END_STATE();
    case 152:
      if (lookahead == 'e') ADVANCE(222);
      END_STATE();
    case 153:
      if (lookahead == 'n') ADVANCE(223);
      END_STATE();
    case 154:
      if (lookahead == 'e') ADVANCE(224);
      END_STATE();
    case 155:
      if (lookahead == 'e') ADVANCE(225);
      END_STATE();
    case 156:
      if (lookahead == 's') ADVANCE(226);
      END_STATE();
    case 157:
      if (lookahead == 'm') ADVANCE(227);
      END_STATE();
    case 158:
      if (lookahead == 'n') ADVANCE(228);
      END_STATE();
    case 159:
      if (lookahead == 't') ADVANCE(229);
      END_STATE();
    case 160:
      if (lookahead == 'y') ADVANCE(230);
      END_STATE();
    case 161:
      ACCEPT_TOKEN(anon_sym_Dict);
      END_STATE();
    case 162:
      ACCEPT_TOKEN(anon_sym_List);
      END_STATE();
    case 163:
      if (lookahead == 'o') ADVANCE(231);
      END_STATE();
    case 164:
      if (lookahead == 'e') ADVANCE(232);
      END_STATE();
    case 165:
      if (lookahead == 'r') ADVANCE(233);
      END_STATE();
    case 166:
      if (lookahead == 'n') ADVANCE(234);
      END_STATE();
    case 167:
      if (lookahead == 'o') ADVANCE(235);
      END_STATE();
    case 168:
      ACCEPT_TOKEN(anon_sym_base);
      END_STATE();
    case 169:
      if (lookahead == 'v') ADVANCE(236);
      END_STATE();
    case 170:
      if (lookahead == 'g') ADVANCE(237);
      END_STATE();
    case 171:
      if (lookahead == 'l') ADVANCE(238);
      END_STATE();
    case 172:
      if (lookahead == 'i') ADVANCE(239);
      END_STATE();
    case 173:
      if (lookahead == 't') ADVANCE(240);
      END_STATE();
    case 174:
      if (lookahead == 't') ADVANCE(241);
      END_STATE();
    case 175:
      if (lookahead == 'e') ADVANCE(242);
      END_STATE();
    case 176:
      if (lookahead == 'u') ADVANCE(243);
      END_STATE();
    case 177:
      if (lookahead == 'r') ADVANCE(244);
      END_STATE();
    case 178:
      if (lookahead == 'c') ADVANCE(245);
      END_STATE();
    case 179:
      if (lookahead == 'd') ADVANCE(246);
      END_STATE();
    case 180:
      ACCEPT_TOKEN(anon_sym_enum);
      END_STATE();
    case 181:
      if (lookahead == 'c') ADVANCE(247);
      END_STATE();
    case 182:
      if (lookahead == 'e') ADVANCE(248);
      END_STATE();
    case 183:
      if (lookahead == 'd') ADVANCE(249);
      END_STATE();
    case 184:
      if (lookahead == 's') ADVANCE(250);
      END_STATE();
    case 185:
      if (lookahead == 'u') ADVANCE(251);
      END_STATE();
    case 186:
      if (lookahead == '_') ADVANCE(252);
      END_STATE();
    case 187:
      ACCEPT_TOKEN(anon_sym_from);
      END_STATE();
    case 188:
      if (lookahead == 't') ADVANCE(253);
      END_STATE();
    case 189:
      if (lookahead == 'r') ADVANCE(254);
      END_STATE();
    case 190:
      if (lookahead == 'n') ADVANCE(255);
      END_STATE();
    case 191:
      if (lookahead == 'e') ADVANCE(256);
      END_STATE();
    case 192:
      if (lookahead == 'r') ADVANCE(257);
      END_STATE();
    case 193:
      if (lookahead == 'i') ADVANCE(258);
      END_STATE();
    case 194:
      if (lookahead == 't') ADVANCE(259);
      END_STATE();
    case 195:
      if (lookahead == 'u') ADVANCE(260);
      END_STATE();
    case 196:
      if (lookahead == 'l') ADVANCE(261);
      END_STATE();
    case 197:
      if (lookahead == 'n') ADVANCE(262);
      END_STATE();
    case 198:
      if (lookahead == 'r') ADVANCE(263);
      END_STATE();
    case 199:
      if (lookahead == 'l') ADVANCE(264);
      END_STATE();
    case 200:
      ACCEPT_TOKEN(anon_sym_name);
      END_STATE();
    case 201:
      ACCEPT_TOKEN(anon_sym_none);
      END_STATE();
    case 202:
      ACCEPT_TOKEN(anon_sym_null);
      END_STATE();
    case 203:
      if (lookahead == 'u') ADVANCE(265);
      END_STATE();
    case 204:
      if (lookahead == 'p') ADVANCE(266);
      END_STATE();
    case 205:
      if (lookahead == 'e') ADVANCE(267);
      END_STATE();
    case 206:
      if (lookahead == 'l') ADVANCE(268);
      END_STATE();
    case 207:
      if (lookahead == 'i') ADVANCE(269);
      END_STATE();
    case 208:
      if (lookahead == 't') ADVANCE(270);
      END_STATE();
    case 209:
      if (lookahead == 'l') ADVANCE(271);
      END_STATE();
    case 210:
      if (lookahead == 'e') ADVANCE(272);
      END_STATE();
    case 211:
      if (lookahead == 't') ADVANCE(273);
      END_STATE();
    case 212:
      if (lookahead == 'a') ADVANCE(274);
      if (lookahead == 'e') ADVANCE(275);
      if (lookahead == 'i') ADVANCE(276);
      END_STATE();
    case 213:
      ACCEPT_TOKEN(anon_sym_size);
      END_STATE();
    case 214:
      if (lookahead == 'c') ADVANCE(277);
      END_STATE();
    case 215:
      if (lookahead == 'e') ADVANCE(278);
      if (lookahead == 'u') ADVANCE(279);
      END_STATE();
    case 216:
      if (lookahead == 's') ADVANCE(280);
      END_STATE();
    case 217:
      if (lookahead == 'e') ADVANCE(281);
      END_STATE();
    case 218:
      if (lookahead == '_') ADVANCE(282);
      if (lookahead == 's') ADVANCE(283);
      END_STATE();
    case 219:
      ACCEPT_TOKEN(anon_sym_then);
      END_STATE();
    case 220:
      if (lookahead == 'r') ADVANCE(284);
      END_STATE();
    case 221:
      if (lookahead == 'l') ADVANCE(285);
      if (lookahead == 'o') ADVANCE(286);
      if (lookahead == 'r') ADVANCE(287);
      END_STATE();
    case 222:
      if (lookahead == 'r') ADVANCE(288);
      END_STATE();
    case 223:
      if (lookahead == 's') ADVANCE(289);
      END_STATE();
    case 224:
      ACCEPT_TOKEN(anon_sym_true);
      END_STATE();
    case 225:
      ACCEPT_TOKEN(anon_sym_type);
      if (lookahead == 's') ADVANCE(290);
      END_STATE();
    case 226:
      if (lookahead == 'i') ADVANCE(291);
      END_STATE();
    case 227:
      if (lookahead == '_') ADVANCE(292);
      END_STATE();
    case 228:
      ACCEPT_TOKEN(anon_sym_when);
      END_STATE();
    case 229:
      if (lookahead == 'h') ADVANCE(293);
      END_STATE();
    case 230:
      ACCEPT_TOKEN(anon_sym_Array);
      END_STATE();
    case 231:
      if (lookahead == 'n') ADVANCE(294);
      END_STATE();
    case 232:
      ACCEPT_TOKEN(anon_sym_Tuple);
      END_STATE();
    case 233:
      if (lookahead == 'i') ADVANCE(295);
      END_STATE();
    case 234:
      if (lookahead == 'm') ADVANCE(296);
      END_STATE();
    case 235:
      if (lookahead == 'r') ADVANCE(297);
      END_STATE();
    case 236:
      if (lookahead == 'i') ADVANCE(298);
      END_STATE();
    case 237:
      if (lookahead == 'o') ADVANCE(299);
      END_STATE();
    case 238:
      if (lookahead == 'e') ADVANCE(300);
      END_STATE();
    case 239:
      if (lookahead == 'd') ADVANCE(301);
      END_STATE();
    case 240:
      if (lookahead == 'a') ADVANCE(302);
      if (lookahead == 'r') ADVANCE(303);
      END_STATE();
    case 241:
      if (lookahead == 'i') ADVANCE(304);
      END_STATE();
    case 242:
      if (lookahead == 'n') ADVANCE(305);
      END_STATE();
    case 243:
      if (lookahead == 'l') ADVANCE(306);
      END_STATE();
    case 244:
      if (lookahead == 'i') ADVANCE(307);
      END_STATE();
    case 245:
      if (lookahead == 't') ADVANCE(308);
      END_STATE();
    case 246:
      if (lookahead == 'i') ADVANCE(309);
      END_STATE();
    case 247:
      if (lookahead == 't') ADVANCE(310);
      END_STATE();
    case 248:
      ACCEPT_TOKEN(anon_sym_false);
      END_STATE();
    case 249:
      if (lookahead == 's') ADVANCE(311);
      END_STATE();
    case 250:
      ACCEPT_TOKEN(anon_sym_flags);
      END_STATE();
    case 251:
      if (lookahead == 'l') ADVANCE(312);
      END_STATE();
    case 252:
      if (lookahead == 't') ADVANCE(313);
      END_STATE();
    case 253:
      if (lookahead == 'i') ADVANCE(314);
      END_STATE();
    case 254:
      if (lookahead == 'i') ADVANCE(315);
      END_STATE();
    case 255:
      ACCEPT_TOKEN(anon_sym_given);
      END_STATE();
    case 256:
      if (lookahead == 'm') ADVANCE(316);
      END_STATE();
    case 257:
      if (lookahead == 't') ADVANCE(317);
      END_STATE();
    case 258:
      if (lookahead == 'a') ADVANCE(318);
      END_STATE();
    case 259:
      ACCEPT_TOKEN(anon_sym_input);
      END_STATE();
    case 260:
      if (lookahead == 'a') ADVANCE(319);
      END_STATE();
    case 261:
      ACCEPT_TOKEN(anon_sym_level);
      END_STATE();
    case 262:
      if (lookahead == 's') ADVANCE(320);
      END_STATE();
    case 263:
      if (lookahead == 'y') ADVANCE(321);
      END_STATE();
    case 264:
      if (lookahead == 'e') ADVANCE(322);
      END_STATE();
    case 265:
      if (lookahead == 't') ADVANCE(323);
      END_STATE();
    case 266:
      if (lookahead == 'r') ADVANCE(324);
      END_STATE();
    case 267:
      if (lookahead == 'r') ADVANCE(325);
      END_STATE();
    case 268:
      if (lookahead == 'i') ADVANCE(326);
      END_STATE();
    case 269:
      if (lookahead == 'c') ADVANCE(327);
      END_STATE();
    case 270:
      ACCEPT_TOKEN(anon_sym_reset);
      END_STATE();
    case 271:
      if (lookahead == 't') ADVANCE(328);
      END_STATE();
    case 272:
      ACCEPT_TOKEN(anon_sym_scope);
      END_STATE();
    case 273:
      ACCEPT_TOKEN(anon_sym_short);
      END_STATE();
    case 274:
      if (lookahead == 'l') ADVANCE(329);
      END_STATE();
    case 275:
      if (lookahead == 'd') ADVANCE(330);
      END_STATE();
    case 276:
      if (lookahead == 'f') ADVANCE(331);
      END_STATE();
    case 277:
      if (lookahead == 'e') ADVANCE(332);
      END_STATE();
    case 278:
      if (lookahead == 'm') ADVANCE(333);
      if (lookahead == 's') ADVANCE(334);
      END_STATE();
    case 279:
      if (lookahead == 's') ADVANCE(335);
      END_STATE();
    case 280:
      ACCEPT_TOKEN(anon_sym_steps);
      END_STATE();
    case 281:
      if (lookahead == 't') ADVANCE(336);
      END_STATE();
    case 282:
      if (lookahead == 'c') ADVANCE(337);
      END_STATE();
    case 283:
      ACCEPT_TOKEN(anon_sym_tests);
      END_STATE();
    case 284:
      if (lookahead == 'e') ADVANCE(338);
      END_STATE();
    case 285:
      if (lookahead == 'i') ADVANCE(339);
      END_STATE();
    case 286:
      if (lookahead == 'u') ADVANCE(340);
      END_STATE();
    case 287:
      if (lookahead == 's') ADVANCE(341);
      END_STATE();
    case 288:
      if (lookahead == 'a') ADVANCE(342);
      END_STATE();
    case 289:
      if (lookahead == 'f') ADVANCE(343);
      if (lookahead == 'i') ADVANCE(344);
      END_STATE();
    case 290:
      ACCEPT_TOKEN(anon_sym_types);
      END_STATE();
    case 291:
      if (lookahead == 'o') ADVANCE(345);
      END_STATE();
    case 292:
      if (lookahead == 'e') ADVANCE(346);
      END_STATE();
    case 293:
      ACCEPT_TOKEN(anon_sym_width);
      END_STATE();
    case 294:
      ACCEPT_TOKEN(anon_sym_Option);
      END_STATE();
    case 295:
      if (lookahead == 't') ADVANCE(347);
      END_STATE();
    case 296:
      if (lookahead == 'e') ADVANCE(348);
      END_STATE();
    case 297:
      ACCEPT_TOKEN(anon_sym_author);
      END_STATE();
    case 298:
      if (lookahead == 'o') ADVANCE(349);
      END_STATE();
    case 299:
      if (lookahead == 'r') ADVANCE(350);
      END_STATE();
    case 300:
      if (lookahead == 'x') ADVANCE(351);
      END_STATE();
    case 301:
      if (lookahead == 'e') ADVANCE(352);
      END_STATE();
    case 302:
      if (lookahead == 'n') ADVANCE(353);
      END_STATE();
    case 303:
      if (lookahead == 'a') ADVANCE(354);
      END_STATE();
    case 304:
      if (lookahead == 'o') ADVANCE(355);
      END_STATE();
    case 305:
      if (lookahead == 't') ADVANCE(356);
      END_STATE();
    case 306:
      if (lookahead == 't') ADVANCE(357);
      END_STATE();
    case 307:
      if (lookahead == 'p') ADVANCE(358);
      END_STATE();
    case 308:
      if (lookahead == 'i') ADVANCE(359);
      END_STATE();
    case 309:
      if (lookahead == 'n') ADVANCE(360);
      END_STATE();
    case 310:
      if (lookahead == 'e') ADVANCE(361);
      END_STATE();
    case 311:
      ACCEPT_TOKEN(anon_sym_fields);
      END_STATE();
    case 312:
      if (lookahead == 'a') ADVANCE(362);
      END_STATE();
    case 313:
      if (lookahead == 'a') ADVANCE(363);
      END_STATE();
    case 314:
      if (lookahead == 'o') ADVANCE(364);
      END_STATE();
    case 315:
      if (lookahead == 'c') ADVANCE(365);
      END_STATE();
    case 316:
      if (lookahead == 'e') ADVANCE(366);
      END_STATE();
    case 317:
      if (lookahead == 's') ADVANCE(367);
      END_STATE();
    case 318:
      if (lookahead == 'l') ADVANCE(368);
      END_STATE();
    case 319:
      if (lookahead == 'g') ADVANCE(369);
      END_STATE();
    case 320:
      if (lookahead == 'e') ADVANCE(370);
      END_STATE();
    case 321:
      ACCEPT_TOKEN(anon_sym_memory);
      END_STATE();
    case 322:
      ACCEPT_TOKEN(anon_sym_module);
      END_STATE();
    case 323:
      if (lookahead == 's') ADVANCE(371);
      END_STATE();
    case 324:
      if (lookahead == 'e') ADVANCE(372);
      END_STATE();
    case 325:
      if (lookahead == 'n') ADVANCE(373);
      END_STATE();
    case 326:
      if (lookahead == 'n') ADVANCE(374);
      END_STATE();
    case 327:
      if (lookahead == 't') ADVANCE(375);
      END_STATE();
    case 328:
      ACCEPT_TOKEN(anon_sym_result);
      END_STATE();
    case 329:
      if (lookahead == 's') ADVANCE(376);
      END_STATE();
    case 330:
      ACCEPT_TOKEN(anon_sym_signed);
      END_STATE();
    case 331:
      if (lookahead == 'i') ADVANCE(377);
      END_STATE();
    case 332:
      ACCEPT_TOKEN(anon_sym_source);
      END_STATE();
    case 333:
      if (lookahead == 'e') ADVANCE(378);
      END_STATE();
    case 334:
      ACCEPT_TOKEN(anon_sym_states);
      END_STATE();
    case 335:
      ACCEPT_TOKEN(anon_sym_status);
      END_STATE();
    case 336:
      ACCEPT_TOKEN(anon_sym_target);
      if (lookahead == '_') ADVANCE(379);
      if (lookahead == 's') ADVANCE(380);
      END_STATE();
    case 337:
      if (lookahead == 'a') ADVANCE(381);
      END_STATE();
    case 338:
      if (lookahead == 'm') ADVANCE(382);
      END_STATE();
    case 339:
      if (lookahead == 'n') ADVANCE(383);
      END_STATE();
    case 340:
      if (lookahead == 't') ADVANCE(384);
      END_STATE();
    case 341:
      ACCEPT_TOKEN(anon_sym_timers);
      END_STATE();
    case 342:
      if (lookahead == 'n') ADVANCE(385);
      END_STATE();
    case 343:
      if (lookahead == 'o') ADVANCE(386);
      END_STATE();
    case 344:
      if (lookahead == 't') ADVANCE(387);
      END_STATE();
    case 345:
      if (lookahead == 'n') ADVANCE(388);
      END_STATE();
    case 346:
      if (lookahead == 'x') ADVANCE(389);
      END_STATE();
    case 347:
      if (lookahead == 'h') ADVANCE(390);
      END_STATE();
    case 348:
      if (lookahead == 'n') ADVANCE(391);
      END_STATE();
    case 349:
      if (lookahead == 'r') ADVANCE(392);
      END_STATE();
    case 350:
      if (lookahead == 'y') ADVANCE(393);
      END_STATE();
    case 351:
      if (lookahead == 'i') ADVANCE(394);
      END_STATE();
    case 352:
      if (lookahead == 'n') ADVANCE(395);
      END_STATE();
    case 353:
      if (lookahead == 't') ADVANCE(396);
      END_STATE();
    case 354:
      if (lookahead == 'i') ADVANCE(397);
      END_STATE();
    case 355:
      if (lookahead == 'n') ADVANCE(398);
      END_STATE();
    case 356:
      ACCEPT_TOKEN(anon_sym_current);
      END_STATE();
    case 357:
      ACCEPT_TOKEN(anon_sym_default);
      END_STATE();
    case 358:
      if (lookahead == 't') ADVANCE(399);
      END_STATE();
    case 359:
      if (lookahead == 'o') ADVANCE(400);
      END_STATE();
    case 360:
      if (lookahead == 'g') ADVANCE(401);
      END_STATE();
    case 361:
      if (lookahead == 'd') ADVANCE(402);
      END_STATE();
    case 362:
      ACCEPT_TOKEN(anon_sym_formula);
      END_STATE();
    case 363:
      if (lookahead == 'r') ADVANCE(403);
      END_STATE();
    case 364:
      if (lookahead == 'n') ADVANCE(404);
      END_STATE();
    case 365:
      ACCEPT_TOKEN(anon_sym_generic);
      END_STATE();
    case 366:
      if (lookahead == 'n') ADVANCE(405);
      END_STATE();
    case 367:
      ACCEPT_TOKEN(anon_sym_imports);
      END_STATE();
    case 368:
      ACCEPT_TOKEN(anon_sym_initial);
      END_STATE();
    case 369:
      if (lookahead == 'e') ADVANCE(406);
      END_STATE();
    case 370:
      ACCEPT_TOKEN(anon_sym_license);
      END_STATE();
    case 371:
      ACCEPT_TOKEN(anon_sym_outputs);
      END_STATE();
    case 372:
      if (lookahead == 'd') ADVANCE(407);
      END_STATE();
    case 373:
      ACCEPT_TOKEN(anon_sym_pattern);
      END_STATE();
    case 374:
      if (lookahead == 'e') ADVANCE(408);
      END_STATE();
    case 375:
      if (lookahead == 'e') ADVANCE(409);
      END_STATE();
    case 376:
      ACCEPT_TOKEN(anon_sym_signals);
      END_STATE();
    case 377:
      if (lookahead == 'c') ADVANCE(410);
      END_STATE();
    case 378:
      if (lookahead == 'n') ADVANCE(411);
      END_STATE();
    case 379:
      if (lookahead == 'f') ADVANCE(412);
      END_STATE();
    case 380:
      ACCEPT_TOKEN(anon_sym_targets);
      END_STATE();
    case 381:
      if (lookahead == 's') ADVANCE(413);
      END_STATE();
    case 382:
      if (lookahead == 's') ADVANCE(414);
      END_STATE();
    case 383:
      if (lookahead == 'e') ADVANCE(415);
      END_STATE();
    case 384:
      if (lookahead == '_') ADVANCE(416);
      END_STATE();
    case 385:
      if (lookahead == 'c') ADVANCE(417);
      END_STATE();
    case 386:
      if (lookahead == 'r') ADVANCE(418);
      END_STATE();
    case 387:
      if (lookahead == 'i') ADVANCE(419);
      END_STATE();
    case 388:
      ACCEPT_TOKEN(anon_sym_version);
      END_STATE();
    case 389:
      if (lookahead == 'p') ADVANCE(420);
      END_STATE();
    case 390:
      if (lookahead == 'm') ADVANCE(421);
      END_STATE();
    case 391:
      if (lookahead == 't') ADVANCE(422);
      END_STATE();
    case 392:
      if (lookahead == 's') ADVANCE(423);
      END_STATE();
    case 393:
      ACCEPT_TOKEN(anon_sym_category);
      END_STATE();
    case 394:
      if (lookahead == 't') ADVANCE(424);
      END_STATE();
    case 395:
      if (lookahead == 'c') ADVANCE(425);
      END_STATE();
    case 396:
      if (lookahead == 's') ADVANCE(426);
      END_STATE();
    case 397:
      if (lookahead == 'n') ADVANCE(427);
      END_STATE();
    case 398:
      if (lookahead == '_') ADVANCE(428);
      END_STATE();
    case 399:
      if (lookahead == 'i') ADVANCE(429);
      END_STATE();
    case 400:
      if (lookahead == 'n') ADVANCE(430);
      END_STATE();
    case 401:
      ACCEPT_TOKEN(anon_sym_encoding);
      END_STATE();
    case 402:
      ACCEPT_TOKEN(anon_sym_expected);
      END_STATE();
    case 403:
      if (lookahead == 'g') ADVANCE(431);
      END_STATE();
    case 404:
      if (lookahead == 's') ADVANCE(432);
      END_STATE();
    case 405:
      if (lookahead == 't') ADVANCE(433);
      END_STATE();
    case 406:
      ACCEPT_TOKEN(anon_sym_language);
      END_STATE();
    case 407:
      if (lookahead == 'i') ADVANCE(434);
      END_STATE();
    case 408:
      ACCEPT_TOKEN(anon_sym_pipeline);
      END_STATE();
    case 409:
      if (lookahead == 'd') ADVANCE(435);
      END_STATE();
    case 410:
      if (lookahead == 'a') ADVANCE(436);
      END_STATE();
    case 411:
      if (lookahead == 't') ADVANCE(437);
      END_STATE();
    case 412:
      if (lookahead == 'r') ADVANCE(438);
      END_STATE();
    case 413:
      if (lookahead == 'e') ADVANCE(439);
      END_STATE();
    case 414:
      ACCEPT_TOKEN(anon_sym_theorems);
      END_STATE();
    case 415:
      ACCEPT_TOKEN(anon_sym_timeline);
      END_STATE();
    case 416:
      if (lookahead == 'c') ADVANCE(440);
      if (lookahead == 'v') ADVANCE(441);
      END_STATE();
    case 417:
      if (lookahead == 'e') ADVANCE(442);
      END_STATE();
    case 418:
      if (lookahead == 'm') ADVANCE(443);
      END_STATE();
    case 419:
      if (lookahead == 'o') ADVANCE(444);
      END_STATE();
    case 420:
      if (lookahead == 'o') ADVANCE(445);
      END_STATE();
    case 421:
      if (lookahead == 's') ADVANCE(446);
      END_STATE();
    case 422:
      ACCEPT_TOKEN(anon_sym_alignment);
      END_STATE();
    case 423:
      ACCEPT_TOKEN(anon_sym_behaviors);
      END_STATE();
    case 424:
      if (lookahead == 'y') ADVANCE(447);
      END_STATE();
    case 425:
      if (lookahead == 'e') ADVANCE(448);
      END_STATE();
    case 426:
      ACCEPT_TOKEN(anon_sym_constants);
      END_STATE();
    case 427:
      if (lookahead == 't') ADVANCE(449);
      END_STATE();
    case 428:
      if (lookahead == 'p') ADVANCE(450);
      END_STATE();
    case 429:
      if (lookahead == 'o') ADVANCE(451);
      END_STATE();
    case 430:
      ACCEPT_TOKEN(anon_sym_direction);
      END_STATE();
    case 431:
      if (lookahead == 'e') ADVANCE(452);
      END_STATE();
    case 432:
      ACCEPT_TOKEN(anon_sym_functions);
      END_STATE();
    case 433:
      if (lookahead == 'a') ADVANCE(453);
      END_STATE();
    case 434:
      if (lookahead == 'c') ADVANCE(454);
      END_STATE();
    case 435:
      ACCEPT_TOKEN(anon_sym_predicted);
      END_STATE();
    case 436:
      if (lookahead == 'n') ADVANCE(455);
      END_STATE();
    case 437:
      ACCEPT_TOKEN(anon_sym_statement);
      END_STATE();
    case 438:
      if (lookahead == 'e') ADVANCE(456);
      END_STATE();
    case 439:
      if (lookahead == 's') ADVANCE(457);
      END_STATE();
    case 440:
      if (lookahead == 'o') ADVANCE(458);
      END_STATE();
    case 441:
      if (lookahead == 'a') ADVANCE(459);
      END_STATE();
    case 442:
      ACCEPT_TOKEN(anon_sym_tolerance);
      END_STATE();
    case 443:
      if (lookahead == 'e') ADVANCE(460);
      END_STATE();
    case 444:
      if (lookahead == 'n') ADVANCE(461);
      END_STATE();
    case 445:
      if (lookahead == 'r') ADVANCE(462);
      END_STATE();
    case 446:
      ACCEPT_TOKEN(anon_sym_algorithms);
      END_STATE();
    case 447:
      ACCEPT_TOKEN(anon_sym_complexity);
      END_STATE();
    case 448:
      ACCEPT_TOKEN(anon_sym_confidence);
      END_STATE();
    case 449:
      if (lookahead == 's') ADVANCE(463);
      END_STATE();
    case 450:
      if (lookahead == 'a') ADVANCE(464);
      END_STATE();
    case 451:
      if (lookahead == 'n') ADVANCE(465);
      END_STATE();
    case 452:
      if (lookahead == 't') ADVANCE(466);
      END_STATE();
    case 453:
      if (lookahead == 't') ADVANCE(467);
      END_STATE();
    case 454:
      if (lookahead == 't') ADVANCE(468);
      END_STATE();
    case 455:
      if (lookahead == 'c') ADVANCE(469);
      END_STATE();
    case 456:
      if (lookahead == 'q') ADVANCE(470);
      END_STATE();
    case 457:
      ACCEPT_TOKEN(anon_sym_test_cases);
      END_STATE();
    case 458:
      if (lookahead == 'n') ADVANCE(471);
      END_STATE();
    case 459:
      if (lookahead == 'l') ADVANCE(472);
      END_STATE();
    case 460:
      if (lookahead == 'r') ADVANCE(473);
      END_STATE();
    case 461:
      if (lookahead == 's') ADVANCE(474);
      END_STATE();
    case 462:
      if (lookahead == 't') ADVANCE(475);
      END_STATE();
    case 463:
      ACCEPT_TOKEN(anon_sym_constraints);
      END_STATE();
    case 464:
      if (lookahead == 't') ADVANCE(476);
      END_STATE();
    case 465:
      ACCEPT_TOKEN(anon_sym_description);
      END_STATE();
    case 466:
      ACCEPT_TOKEN(anon_sym_fpga_target);
      END_STATE();
    case 467:
      if (lookahead == 'i') ADVANCE(477);
      END_STATE();
    case 468:
      if (lookahead == 'i') ADVANCE(478);
      END_STATE();
    case 469:
      if (lookahead == 'e') ADVANCE(479);
      END_STATE();
    case 470:
      if (lookahead == 'u') ADVANCE(480);
      END_STATE();
    case 471:
      if (lookahead == 's') ADVANCE(481);
      END_STATE();
    case 472:
      if (lookahead == 'u') ADVANCE(482);
      END_STATE();
    case 473:
      ACCEPT_TOKEN(anon_sym_transformer);
      END_STATE();
    case 474:
      ACCEPT_TOKEN(anon_sym_transitions);
      END_STATE();
    case 475:
      if (lookahead == 's') ADVANCE(483);
      END_STATE();
    case 476:
      if (lookahead == 't') ADVANCE(484);
      END_STATE();
    case 477:
      if (lookahead == 'o') ADVANCE(485);
      END_STATE();
    case 478:
      if (lookahead == 'o') ADVANCE(486);
      END_STATE();
    case 479:
      ACCEPT_TOKEN(anon_sym_significance);
      END_STATE();
    case 480:
      if (lookahead == 'e') ADVANCE(487);
      END_STATE();
    case 481:
      if (lookahead == 't') ADVANCE(488);
      END_STATE();
    case 482:
      if (lookahead == 'e') ADVANCE(489);
      END_STATE();
    case 483:
      ACCEPT_TOKEN(anon_sym_wasm_exports);
      END_STATE();
    case 484:
      if (lookahead == 'e') ADVANCE(490);
      END_STATE();
    case 485:
      if (lookahead == 'n') ADVANCE(491);
      END_STATE();
    case 486:
      if (lookahead == 'n') ADVANCE(492);
      END_STATE();
    case 487:
      if (lookahead == 'n') ADVANCE(493);
      END_STATE();
    case 488:
      if (lookahead == 'a') ADVANCE(494);
      END_STATE();
    case 489:
      ACCEPT_TOKEN(anon_sym_timeout_value);
      END_STATE();
    case 490:
      if (lookahead == 'r') ADVANCE(495);
      END_STATE();
    case 491:
      ACCEPT_TOKEN(anon_sym_implementation);
      END_STATE();
    case 492:
      if (lookahead == 's') ADVANCE(496);
      END_STATE();
    case 493:
      if (lookahead == 'c') ADVANCE(497);
      END_STATE();
    case 494:
      if (lookahead == 'n') ADVANCE(498);
      END_STATE();
    case 495:
      if (lookahead == 'n') ADVANCE(499);
      END_STATE();
    case 496:
      ACCEPT_TOKEN(anon_sym_pas_predictions);
      END_STATE();
    case 497:
      if (lookahead == 'y') ADVANCE(500);
      END_STATE();
    case 498:
      if (lookahead == 't') ADVANCE(501);
      END_STATE();
    case 499:
      if (lookahead == 's') ADVANCE(502);
      END_STATE();
    case 500:
      ACCEPT_TOKEN(anon_sym_target_frequency);
      END_STATE();
    case 501:
      ACCEPT_TOKEN(anon_sym_timeout_constant);
      END_STATE();
    case 502:
      ACCEPT_TOKEN(anon_sym_creation_patterns);
      END_STATE();
    default:
      return false;
  }
}

static const TSLexMode ts_lex_modes[STATE_COUNT] = {
  [0] = {.lex_state = 0},
  [1] = {.lex_state = 0},
  [2] = {.lex_state = 0},
  [3] = {.lex_state = 0},
  [4] = {.lex_state = 0},
  [5] = {.lex_state = 0},
  [6] = {.lex_state = 0},
  [7] = {.lex_state = 0},
  [8] = {.lex_state = 0},
  [9] = {.lex_state = 0},
  [10] = {.lex_state = 0},
  [11] = {.lex_state = 0},
  [12] = {.lex_state = 0},
  [13] = {.lex_state = 0},
  [14] = {.lex_state = 0},
  [15] = {.lex_state = 0},
  [16] = {.lex_state = 0},
  [17] = {.lex_state = 0},
  [18] = {.lex_state = 0},
  [19] = {.lex_state = 0},
  [20] = {.lex_state = 0},
  [21] = {.lex_state = 0},
  [22] = {.lex_state = 0},
  [23] = {.lex_state = 0},
  [24] = {.lex_state = 0},
  [25] = {.lex_state = 0},
  [26] = {.lex_state = 0},
  [27] = {.lex_state = 1},
  [28] = {.lex_state = 1},
  [29] = {.lex_state = 1},
  [30] = {.lex_state = 1},
  [31] = {.lex_state = 0},
  [32] = {.lex_state = 0},
  [33] = {.lex_state = 0},
  [34] = {.lex_state = 0},
  [35] = {.lex_state = 0},
  [36] = {.lex_state = 0},
  [37] = {.lex_state = 0},
  [38] = {.lex_state = 0},
  [39] = {.lex_state = 0},
  [40] = {.lex_state = 0},
  [41] = {.lex_state = 0},
  [42] = {.lex_state = 0},
  [43] = {.lex_state = 33},
  [44] = {.lex_state = 0},
  [45] = {.lex_state = 0},
  [46] = {.lex_state = 0},
  [47] = {.lex_state = 0},
  [48] = {.lex_state = 0},
  [49] = {.lex_state = 0},
  [50] = {.lex_state = 0},
};

static const uint16_t ts_parse_table[LARGE_STATE_COUNT][SYMBOL_COUNT] = {
  [0] = {
    [ts_builtin_sym_end] = ACTIONS(1),
    [sym_plain_identifier] = ACTIONS(1),
    [anon_sym_COLON] = ACTIONS(1),
    [anon_sym_name] = ACTIONS(1),
    [anon_sym_version] = ACTIONS(1),
    [anon_sym_language] = ACTIONS(1),
    [anon_sym_module] = ACTIONS(1),
    [anon_sym_description] = ACTIONS(1),
    [anon_sym_author] = ACTIONS(1),
    [anon_sym_license] = ACTIONS(1),
    [anon_sym_constants] = ACTIONS(1),
    [anon_sym_types] = ACTIONS(1),
    [anon_sym_behaviors] = ACTIONS(1),
    [anon_sym_algorithms] = ACTIONS(1),
    [anon_sym_imports] = ACTIONS(1),
    [anon_sym_creation_patterns] = ACTIONS(1),
    [anon_sym_wasm_exports] = ACTIONS(1),
    [anon_sym_pas_predictions] = ACTIONS(1),
    [anon_sym_signals] = ACTIONS(1),
    [anon_sym_fsm] = ACTIONS(1),
    [anon_sym_reset] = ACTIONS(1),
    [anon_sym_test_cases] = ACTIONS(1),
    [anon_sym_tests] = ACTIONS(1),
    [anon_sym_cli] = ACTIONS(1),
    [anon_sym_theorems] = ACTIONS(1),
    [anon_sym_targets] = ACTIONS(1),
    [anon_sym_fpga_target] = ACTIONS(1),
    [anon_sym_pipeline] = ACTIONS(1),
    [anon_sym_target_frequency] = ACTIONS(1),
    [anon_sym_fields] = ACTIONS(1),
    [anon_sym_enum] = ACTIONS(1),
    [anon_sym_constraints] = ACTIONS(1),
    [anon_sym_base] = ACTIONS(1),
    [anon_sym_generic] = ACTIONS(1),
    [anon_sym_functions] = ACTIONS(1),
    [anon_sym_memory] = ACTIONS(1),
    [anon_sym_states] = ACTIONS(1),
    [anon_sym_transitions] = ACTIONS(1),
    [anon_sym_outputs] = ACTIONS(1),
    [anon_sym_timers] = ACTIONS(1),
    [anon_sym_flags] = ACTIONS(1),
    [anon_sym_given] = ACTIONS(1),
    [anon_sym_when] = ACTIONS(1),
    [anon_sym_then] = ACTIONS(1),
    [anon_sym_implementation] = ACTIONS(1),
    [anon_sym_input] = ACTIONS(1),
    [anon_sym_expected] = ACTIONS(1),
    [anon_sym_tolerance] = ACTIONS(1),
    [anon_sym_complexity] = ACTIONS(1),
    [anon_sym_pattern] = ACTIONS(1),
    [anon_sym_steps] = ACTIONS(1),
    [anon_sym_formula] = ACTIONS(1),
    [anon_sym_source] = ACTIONS(1),
    [anon_sym_transformer] = ACTIONS(1),
    [anon_sym_result] = ACTIONS(1),
    [anon_sym_target] = ACTIONS(1),
    [anon_sym_current] = ACTIONS(1),
    [anon_sym_predicted] = ACTIONS(1),
    [anon_sym_confidence] = ACTIONS(1),
    [anon_sym_status] = ACTIONS(1),
    [anon_sym_timeline] = ACTIONS(1),
    [anon_sym_width] = ACTIONS(1),
    [anon_sym_direction] = ACTIONS(1),
    [anon_sym_signed] = ACTIONS(1),
    [anon_sym_default] = ACTIONS(1),
    [anon_sym_initial] = ACTIONS(1),
    [anon_sym_encoding] = ACTIONS(1),
    [anon_sym_from] = ACTIONS(1),
    [anon_sym_to] = ACTIONS(1),
    [anon_sym_type] = ACTIONS(1),
    [anon_sym_level] = ACTIONS(1),
    [anon_sym_short] = ACTIONS(1),
    [anon_sym_category] = ACTIONS(1),
    [anon_sym_id] = ACTIONS(1),
    [anon_sym_statement] = ACTIONS(1),
    [anon_sym_significance] = ACTIONS(1),
    [anon_sym_size] = ACTIONS(1),
    [anon_sym_alignment] = ACTIONS(1),
    [anon_sym_scope] = ACTIONS(1),
    [anon_sym_timeout_constant] = ACTIONS(1),
    [anon_sym_timeout_value] = ACTIONS(1),
    [anon_sym_DASH] = ACTIONS(1),
    [anon_sym_LT] = ACTIONS(1),
    [anon_sym_COMMA] = ACTIONS(1),
    [anon_sym_GT] = ACTIONS(1),
    [anon_sym_List] = ACTIONS(1),
    [anon_sym_Set] = ACTIONS(1),
    [anon_sym_Map] = ACTIONS(1),
    [anon_sym_Option] = ACTIONS(1),
    [anon_sym_Array] = ACTIONS(1),
    [anon_sym_Dict] = ACTIONS(1),
    [anon_sym_Tuple] = ACTIONS(1),
    [anon_sym_LBRACK] = ACTIONS(1),
    [anon_sym_RBRACK] = ACTIONS(1),
    [anon_sym_DQUOTE] = ACTIONS(1),
    [sym_escape_sequence] = ACTIONS(1),
    [anon_sym_DOLLAR_LBRACE] = ACTIONS(1),
    [anon_sym_RBRACE] = ACTIONS(1),
    [anon_sym_PIPE] = ACTIONS(1),
    [sym_float_number] = ACTIONS(1),
    [sym_number] = ACTIONS(1),
    [anon_sym_true] = ACTIONS(1),
    [anon_sym_false] = ACTIONS(1),
    [anon_sym_null] = ACTIONS(1),
    [anon_sym_nil] = ACTIONS(1),
    [anon_sym_none] = ACTIONS(1),
    [sym_dotted_identifier] = ACTIONS(1),
    [sym_comment] = ACTIONS(3),
  },
  [1] = {
    [sym_source_file] = STATE(49),
    [sym__entry] = STATE(4),
    [sym_pair] = STATE(4),
    [sym__key] = STATE(46),
    [sym_section_keyword] = STATE(46),
    [sym_type_keyword] = STATE(46),
    [sym_behavior_keyword] = STATE(46),
    [sym_list_item] = STATE(4),
    [sym_quoted_string] = STATE(46),
    [sym_identifier] = STATE(46),
    [aux_sym_source_file_repeat1] = STATE(4),
    [ts_builtin_sym_end] = ACTIONS(5),
    [sym_plain_identifier] = ACTIONS(7),
    [anon_sym_name] = ACTIONS(9),
    [anon_sym_version] = ACTIONS(9),
    [anon_sym_language] = ACTIONS(9),
    [anon_sym_module] = ACTIONS(9),
    [anon_sym_description] = ACTIONS(9),
    [anon_sym_author] = ACTIONS(9),
    [anon_sym_license] = ACTIONS(9),
    [anon_sym_constants] = ACTIONS(9),
    [anon_sym_types] = ACTIONS(9),
    [anon_sym_behaviors] = ACTIONS(9),
    [anon_sym_algorithms] = ACTIONS(9),
    [anon_sym_imports] = ACTIONS(9),
    [anon_sym_creation_patterns] = ACTIONS(9),
    [anon_sym_wasm_exports] = ACTIONS(9),
    [anon_sym_pas_predictions] = ACTIONS(9),
    [anon_sym_signals] = ACTIONS(9),
    [anon_sym_fsm] = ACTIONS(9),
    [anon_sym_reset] = ACTIONS(9),
    [anon_sym_test_cases] = ACTIONS(9),
    [anon_sym_tests] = ACTIONS(9),
    [anon_sym_cli] = ACTIONS(9),
    [anon_sym_theorems] = ACTIONS(9),
    [anon_sym_targets] = ACTIONS(9),
    [anon_sym_fpga_target] = ACTIONS(9),
    [anon_sym_pipeline] = ACTIONS(9),
    [anon_sym_target_frequency] = ACTIONS(9),
    [anon_sym_fields] = ACTIONS(11),
    [anon_sym_enum] = ACTIONS(11),
    [anon_sym_constraints] = ACTIONS(11),
    [anon_sym_base] = ACTIONS(11),
    [anon_sym_generic] = ACTIONS(11),
    [anon_sym_functions] = ACTIONS(11),
    [anon_sym_memory] = ACTIONS(11),
    [anon_sym_states] = ACTIONS(11),
    [anon_sym_transitions] = ACTIONS(11),
    [anon_sym_outputs] = ACTIONS(11),
    [anon_sym_timers] = ACTIONS(11),
    [anon_sym_flags] = ACTIONS(11),
    [anon_sym_given] = ACTIONS(13),
    [anon_sym_when] = ACTIONS(13),
    [anon_sym_then] = ACTIONS(13),
    [anon_sym_implementation] = ACTIONS(13),
    [anon_sym_input] = ACTIONS(13),
    [anon_sym_expected] = ACTIONS(13),
    [anon_sym_tolerance] = ACTIONS(13),
    [anon_sym_complexity] = ACTIONS(13),
    [anon_sym_pattern] = ACTIONS(13),
    [anon_sym_steps] = ACTIONS(13),
    [anon_sym_formula] = ACTIONS(13),
    [anon_sym_source] = ACTIONS(13),
    [anon_sym_transformer] = ACTIONS(13),
    [anon_sym_result] = ACTIONS(13),
    [anon_sym_target] = ACTIONS(13),
    [anon_sym_current] = ACTIONS(13),
    [anon_sym_predicted] = ACTIONS(13),
    [anon_sym_confidence] = ACTIONS(13),
    [anon_sym_status] = ACTIONS(13),
    [anon_sym_timeline] = ACTIONS(13),
    [anon_sym_width] = ACTIONS(13),
    [anon_sym_direction] = ACTIONS(13),
    [anon_sym_signed] = ACTIONS(13),
    [anon_sym_default] = ACTIONS(13),
    [anon_sym_initial] = ACTIONS(13),
    [anon_sym_encoding] = ACTIONS(13),
    [anon_sym_from] = ACTIONS(13),
    [anon_sym_to] = ACTIONS(13),
    [anon_sym_type] = ACTIONS(13),
    [anon_sym_level] = ACTIONS(13),
    [anon_sym_short] = ACTIONS(13),
    [anon_sym_category] = ACTIONS(13),
    [anon_sym_id] = ACTIONS(13),
    [anon_sym_statement] = ACTIONS(13),
    [anon_sym_significance] = ACTIONS(13),
    [anon_sym_size] = ACTIONS(13),
    [anon_sym_alignment] = ACTIONS(13),
    [anon_sym_scope] = ACTIONS(13),
    [anon_sym_timeout_constant] = ACTIONS(13),
    [anon_sym_timeout_value] = ACTIONS(13),
    [anon_sym_DASH] = ACTIONS(15),
    [anon_sym_DQUOTE] = ACTIONS(17),
    [sym_dotted_identifier] = ACTIONS(19),
    [sym_comment] = ACTIONS(3),
  },
  [2] = {
    [sym_pair] = STATE(14),
    [sym__key] = STATE(46),
    [sym_section_keyword] = STATE(46),
    [sym_type_keyword] = STATE(46),
    [sym_behavior_keyword] = STATE(46),
    [sym__value] = STATE(14),
    [sym_type_expression] = STATE(14),
    [sym_generic_type_name] = STATE(45),
    [sym_flow_sequence] = STATE(14),
    [sym_quoted_string] = STATE(13),
    [sym_multiline_string] = STATE(14),
    [sym_boolean] = STATE(14),
    [sym_null_value] = STATE(14),
    [sym_identifier] = STATE(13),
    [sym_plain_identifier] = ACTIONS(7),
    [anon_sym_name] = ACTIONS(9),
    [anon_sym_version] = ACTIONS(9),
    [anon_sym_language] = ACTIONS(9),
    [anon_sym_module] = ACTIONS(9),
    [anon_sym_description] = ACTIONS(9),
    [anon_sym_author] = ACTIONS(9),
    [anon_sym_license] = ACTIONS(9),
    [anon_sym_constants] = ACTIONS(9),
    [anon_sym_types] = ACTIONS(9),
    [anon_sym_behaviors] = ACTIONS(9),
    [anon_sym_algorithms] = ACTIONS(9),
    [anon_sym_imports] = ACTIONS(9),
    [anon_sym_creation_patterns] = ACTIONS(9),
    [anon_sym_wasm_exports] = ACTIONS(9),
    [anon_sym_pas_predictions] = ACTIONS(9),
    [anon_sym_signals] = ACTIONS(9),
    [anon_sym_fsm] = ACTIONS(9),
    [anon_sym_reset] = ACTIONS(9),
    [anon_sym_test_cases] = ACTIONS(9),
    [anon_sym_tests] = ACTIONS(9),
    [anon_sym_cli] = ACTIONS(9),
    [anon_sym_theorems] = ACTIONS(9),
    [anon_sym_targets] = ACTIONS(9),
    [anon_sym_fpga_target] = ACTIONS(9),
    [anon_sym_pipeline] = ACTIONS(9),
    [anon_sym_target_frequency] = ACTIONS(9),
    [anon_sym_fields] = ACTIONS(11),
    [anon_sym_enum] = ACTIONS(11),
    [anon_sym_constraints] = ACTIONS(11),
    [anon_sym_base] = ACTIONS(11),
    [anon_sym_generic] = ACTIONS(11),
    [anon_sym_functions] = ACTIONS(11),
    [anon_sym_memory] = ACTIONS(11),
    [anon_sym_states] = ACTIONS(11),
    [anon_sym_transitions] = ACTIONS(11),
    [anon_sym_outputs] = ACTIONS(11),
    [anon_sym_timers] = ACTIONS(11),
    [anon_sym_flags] = ACTIONS(11),
    [anon_sym_given] = ACTIONS(13),
    [anon_sym_when] = ACTIONS(13),
    [anon_sym_then] = ACTIONS(13),
    [anon_sym_implementation] = ACTIONS(13),
    [anon_sym_input] = ACTIONS(13),
    [anon_sym_expected] = ACTIONS(13),
    [anon_sym_tolerance] = ACTIONS(13),
    [anon_sym_complexity] = ACTIONS(13),
    [anon_sym_pattern] = ACTIONS(13),
    [anon_sym_steps] = ACTIONS(13),
    [anon_sym_formula] = ACTIONS(13),
    [anon_sym_source] = ACTIONS(13),
    [anon_sym_transformer] = ACTIONS(13),
    [anon_sym_result] = ACTIONS(13),
    [anon_sym_target] = ACTIONS(13),
    [anon_sym_current] = ACTIONS(13),
    [anon_sym_predicted] = ACTIONS(13),
    [anon_sym_confidence] = ACTIONS(13),
    [anon_sym_status] = ACTIONS(13),
    [anon_sym_timeline] = ACTIONS(13),
    [anon_sym_width] = ACTIONS(13),
    [anon_sym_direction] = ACTIONS(13),
    [anon_sym_signed] = ACTIONS(13),
    [anon_sym_default] = ACTIONS(13),
    [anon_sym_initial] = ACTIONS(13),
    [anon_sym_encoding] = ACTIONS(13),
    [anon_sym_from] = ACTIONS(13),
    [anon_sym_to] = ACTIONS(13),
    [anon_sym_type] = ACTIONS(13),
    [anon_sym_level] = ACTIONS(13),
    [anon_sym_short] = ACTIONS(13),
    [anon_sym_category] = ACTIONS(13),
    [anon_sym_id] = ACTIONS(13),
    [anon_sym_statement] = ACTIONS(13),
    [anon_sym_significance] = ACTIONS(13),
    [anon_sym_size] = ACTIONS(13),
    [anon_sym_alignment] = ACTIONS(13),
    [anon_sym_scope] = ACTIONS(13),
    [anon_sym_timeout_constant] = ACTIONS(13),
    [anon_sym_timeout_value] = ACTIONS(13),
    [anon_sym_List] = ACTIONS(21),
    [anon_sym_Set] = ACTIONS(21),
    [anon_sym_Map] = ACTIONS(21),
    [anon_sym_Option] = ACTIONS(21),
    [anon_sym_Array] = ACTIONS(21),
    [anon_sym_Dict] = ACTIONS(21),
    [anon_sym_Tuple] = ACTIONS(21),
    [anon_sym_LBRACK] = ACTIONS(23),
    [anon_sym_DQUOTE] = ACTIONS(17),
    [anon_sym_PIPE] = ACTIONS(25),
    [sym_float_number] = ACTIONS(27),
    [sym_number] = ACTIONS(29),
    [anon_sym_true] = ACTIONS(31),
    [anon_sym_false] = ACTIONS(31),
    [anon_sym_null] = ACTIONS(33),
    [anon_sym_nil] = ACTIONS(33),
    [anon_sym_none] = ACTIONS(33),
    [sym_dotted_identifier] = ACTIONS(19),
    [sym_comment] = ACTIONS(3),
  },
  [3] = {
    [sym__value] = STATE(17),
    [sym_type_expression] = STATE(17),
    [sym_generic_type_name] = STATE(45),
    [sym_flow_sequence] = STATE(17),
    [sym_quoted_string] = STATE(17),
    [sym_multiline_string] = STATE(17),
    [sym_boolean] = STATE(17),
    [sym_null_value] = STATE(17),
    [sym_identifier] = STATE(17),
    [ts_builtin_sym_end] = ACTIONS(35),
    [sym_plain_identifier] = ACTIONS(37),
    [anon_sym_name] = ACTIONS(40),
    [anon_sym_version] = ACTIONS(40),
    [anon_sym_language] = ACTIONS(40),
    [anon_sym_module] = ACTIONS(40),
    [anon_sym_description] = ACTIONS(40),
    [anon_sym_author] = ACTIONS(40),
    [anon_sym_license] = ACTIONS(40),
    [anon_sym_constants] = ACTIONS(40),
    [anon_sym_types] = ACTIONS(40),
    [anon_sym_behaviors] = ACTIONS(40),
    [anon_sym_algorithms] = ACTIONS(40),
    [anon_sym_imports] = ACTIONS(40),
    [anon_sym_creation_patterns] = ACTIONS(40),
    [anon_sym_wasm_exports] = ACTIONS(40),
    [anon_sym_pas_predictions] = ACTIONS(40),
    [anon_sym_signals] = ACTIONS(40),
    [anon_sym_fsm] = ACTIONS(40),
    [anon_sym_reset] = ACTIONS(40),
    [anon_sym_test_cases] = ACTIONS(40),
    [anon_sym_tests] = ACTIONS(40),
    [anon_sym_cli] = ACTIONS(40),
    [anon_sym_theorems] = ACTIONS(40),
    [anon_sym_targets] = ACTIONS(40),
    [anon_sym_fpga_target] = ACTIONS(40),
    [anon_sym_pipeline] = ACTIONS(40),
    [anon_sym_target_frequency] = ACTIONS(40),
    [anon_sym_fields] = ACTIONS(40),
    [anon_sym_enum] = ACTIONS(40),
    [anon_sym_constraints] = ACTIONS(40),
    [anon_sym_base] = ACTIONS(40),
    [anon_sym_generic] = ACTIONS(40),
    [anon_sym_functions] = ACTIONS(40),
    [anon_sym_memory] = ACTIONS(40),
    [anon_sym_states] = ACTIONS(40),
    [anon_sym_transitions] = ACTIONS(40),
    [anon_sym_outputs] = ACTIONS(40),
    [anon_sym_timers] = ACTIONS(40),
    [anon_sym_flags] = ACTIONS(40),
    [anon_sym_given] = ACTIONS(40),
    [anon_sym_when] = ACTIONS(40),
    [anon_sym_then] = ACTIONS(40),
    [anon_sym_implementation] = ACTIONS(40),
    [anon_sym_input] = ACTIONS(40),
    [anon_sym_expected] = ACTIONS(40),
    [anon_sym_tolerance] = ACTIONS(40),
    [anon_sym_complexity] = ACTIONS(40),
    [anon_sym_pattern] = ACTIONS(40),
    [anon_sym_steps] = ACTIONS(40),
    [anon_sym_formula] = ACTIONS(40),
    [anon_sym_source] = ACTIONS(40),
    [anon_sym_transformer] = ACTIONS(40),
    [anon_sym_result] = ACTIONS(40),
    [anon_sym_target] = ACTIONS(40),
    [anon_sym_current] = ACTIONS(40),
    [anon_sym_predicted] = ACTIONS(40),
    [anon_sym_confidence] = ACTIONS(40),
    [anon_sym_status] = ACTIONS(40),
    [anon_sym_timeline] = ACTIONS(40),
    [anon_sym_width] = ACTIONS(40),
    [anon_sym_direction] = ACTIONS(40),
    [anon_sym_signed] = ACTIONS(40),
    [anon_sym_default] = ACTIONS(40),
    [anon_sym_initial] = ACTIONS(40),
    [anon_sym_encoding] = ACTIONS(40),
    [anon_sym_from] = ACTIONS(40),
    [anon_sym_to] = ACTIONS(40),
    [anon_sym_type] = ACTIONS(40),
    [anon_sym_level] = ACTIONS(40),
    [anon_sym_short] = ACTIONS(40),
    [anon_sym_category] = ACTIONS(40),
    [anon_sym_id] = ACTIONS(40),
    [anon_sym_statement] = ACTIONS(40),
    [anon_sym_significance] = ACTIONS(40),
    [anon_sym_size] = ACTIONS(40),
    [anon_sym_alignment] = ACTIONS(40),
    [anon_sym_scope] = ACTIONS(40),
    [anon_sym_timeout_constant] = ACTIONS(40),
    [anon_sym_timeout_value] = ACTIONS(40),
    [anon_sym_DASH] = ACTIONS(35),
    [anon_sym_List] = ACTIONS(21),
    [anon_sym_Set] = ACTIONS(21),
    [anon_sym_Map] = ACTIONS(21),
    [anon_sym_Option] = ACTIONS(21),
    [anon_sym_Array] = ACTIONS(21),
    [anon_sym_Dict] = ACTIONS(21),
    [anon_sym_Tuple] = ACTIONS(21),
    [anon_sym_LBRACK] = ACTIONS(23),
    [anon_sym_DQUOTE] = ACTIONS(42),
    [anon_sym_PIPE] = ACTIONS(25),
    [sym_float_number] = ACTIONS(45),
    [sym_number] = ACTIONS(47),
    [anon_sym_true] = ACTIONS(31),
    [anon_sym_false] = ACTIONS(31),
    [anon_sym_null] = ACTIONS(33),
    [anon_sym_nil] = ACTIONS(33),
    [anon_sym_none] = ACTIONS(33),
    [sym_dotted_identifier] = ACTIONS(49),
    [sym_comment] = ACTIONS(3),
  },
  [4] = {
    [sym__entry] = STATE(5),
    [sym_pair] = STATE(5),
    [sym__key] = STATE(46),
    [sym_section_keyword] = STATE(46),
    [sym_type_keyword] = STATE(46),
    [sym_behavior_keyword] = STATE(46),
    [sym_list_item] = STATE(5),
    [sym_quoted_string] = STATE(46),
    [sym_identifier] = STATE(46),
    [aux_sym_source_file_repeat1] = STATE(5),
    [ts_builtin_sym_end] = ACTIONS(52),
    [sym_plain_identifier] = ACTIONS(7),
    [anon_sym_name] = ACTIONS(9),
    [anon_sym_version] = ACTIONS(9),
    [anon_sym_language] = ACTIONS(9),
    [anon_sym_module] = ACTIONS(9),
    [anon_sym_description] = ACTIONS(9),
    [anon_sym_author] = ACTIONS(9),
    [anon_sym_license] = ACTIONS(9),
    [anon_sym_constants] = ACTIONS(9),
    [anon_sym_types] = ACTIONS(9),
    [anon_sym_behaviors] = ACTIONS(9),
    [anon_sym_algorithms] = ACTIONS(9),
    [anon_sym_imports] = ACTIONS(9),
    [anon_sym_creation_patterns] = ACTIONS(9),
    [anon_sym_wasm_exports] = ACTIONS(9),
    [anon_sym_pas_predictions] = ACTIONS(9),
    [anon_sym_signals] = ACTIONS(9),
    [anon_sym_fsm] = ACTIONS(9),
    [anon_sym_reset] = ACTIONS(9),
    [anon_sym_test_cases] = ACTIONS(9),
    [anon_sym_tests] = ACTIONS(9),
    [anon_sym_cli] = ACTIONS(9),
    [anon_sym_theorems] = ACTIONS(9),
    [anon_sym_targets] = ACTIONS(9),
    [anon_sym_fpga_target] = ACTIONS(9),
    [anon_sym_pipeline] = ACTIONS(9),
    [anon_sym_target_frequency] = ACTIONS(9),
    [anon_sym_fields] = ACTIONS(11),
    [anon_sym_enum] = ACTIONS(11),
    [anon_sym_constraints] = ACTIONS(11),
    [anon_sym_base] = ACTIONS(11),
    [anon_sym_generic] = ACTIONS(11),
    [anon_sym_functions] = ACTIONS(11),
    [anon_sym_memory] = ACTIONS(11),
    [anon_sym_states] = ACTIONS(11),
    [anon_sym_transitions] = ACTIONS(11),
    [anon_sym_outputs] = ACTIONS(11),
    [anon_sym_timers] = ACTIONS(11),
    [anon_sym_flags] = ACTIONS(11),
    [anon_sym_given] = ACTIONS(13),
    [anon_sym_when] = ACTIONS(13),
    [anon_sym_then] = ACTIONS(13),
    [anon_sym_implementation] = ACTIONS(13),
    [anon_sym_input] = ACTIONS(13),
    [anon_sym_expected] = ACTIONS(13),
    [anon_sym_tolerance] = ACTIONS(13),
    [anon_sym_complexity] = ACTIONS(13),
    [anon_sym_pattern] = ACTIONS(13),
    [anon_sym_steps] = ACTIONS(13),
    [anon_sym_formula] = ACTIONS(13),
    [anon_sym_source] = ACTIONS(13),
    [anon_sym_transformer] = ACTIONS(13),
    [anon_sym_result] = ACTIONS(13),
    [anon_sym_target] = ACTIONS(13),
    [anon_sym_current] = ACTIONS(13),
    [anon_sym_predicted] = ACTIONS(13),
    [anon_sym_confidence] = ACTIONS(13),
    [anon_sym_status] = ACTIONS(13),
    [anon_sym_timeline] = ACTIONS(13),
    [anon_sym_width] = ACTIONS(13),
    [anon_sym_direction] = ACTIONS(13),
    [anon_sym_signed] = ACTIONS(13),
    [anon_sym_default] = ACTIONS(13),
    [anon_sym_initial] = ACTIONS(13),
    [anon_sym_encoding] = ACTIONS(13),
    [anon_sym_from] = ACTIONS(13),
    [anon_sym_to] = ACTIONS(13),
    [anon_sym_type] = ACTIONS(13),
    [anon_sym_level] = ACTIONS(13),
    [anon_sym_short] = ACTIONS(13),
    [anon_sym_category] = ACTIONS(13),
    [anon_sym_id] = ACTIONS(13),
    [anon_sym_statement] = ACTIONS(13),
    [anon_sym_significance] = ACTIONS(13),
    [anon_sym_size] = ACTIONS(13),
    [anon_sym_alignment] = ACTIONS(13),
    [anon_sym_scope] = ACTIONS(13),
    [anon_sym_timeout_constant] = ACTIONS(13),
    [anon_sym_timeout_value] = ACTIONS(13),
    [anon_sym_DASH] = ACTIONS(15),
    [anon_sym_DQUOTE] = ACTIONS(17),
    [sym_dotted_identifier] = ACTIONS(19),
    [sym_comment] = ACTIONS(3),
  },
  [5] = {
    [sym__entry] = STATE(5),
    [sym_pair] = STATE(5),
    [sym__key] = STATE(46),
    [sym_section_keyword] = STATE(46),
    [sym_type_keyword] = STATE(46),
    [sym_behavior_keyword] = STATE(46),
    [sym_list_item] = STATE(5),
    [sym_quoted_string] = STATE(46),
    [sym_identifier] = STATE(46),
    [aux_sym_source_file_repeat1] = STATE(5),
    [ts_builtin_sym_end] = ACTIONS(54),
    [sym_plain_identifier] = ACTIONS(56),
    [anon_sym_name] = ACTIONS(59),
    [anon_sym_version] = ACTIONS(59),
    [anon_sym_language] = ACTIONS(59),
    [anon_sym_module] = ACTIONS(59),
    [anon_sym_description] = ACTIONS(59),
    [anon_sym_author] = ACTIONS(59),
    [anon_sym_license] = ACTIONS(59),
    [anon_sym_constants] = ACTIONS(59),
    [anon_sym_types] = ACTIONS(59),
    [anon_sym_behaviors] = ACTIONS(59),
    [anon_sym_algorithms] = ACTIONS(59),
    [anon_sym_imports] = ACTIONS(59),
    [anon_sym_creation_patterns] = ACTIONS(59),
    [anon_sym_wasm_exports] = ACTIONS(59),
    [anon_sym_pas_predictions] = ACTIONS(59),
    [anon_sym_signals] = ACTIONS(59),
    [anon_sym_fsm] = ACTIONS(59),
    [anon_sym_reset] = ACTIONS(59),
    [anon_sym_test_cases] = ACTIONS(59),
    [anon_sym_tests] = ACTIONS(59),
    [anon_sym_cli] = ACTIONS(59),
    [anon_sym_theorems] = ACTIONS(59),
    [anon_sym_targets] = ACTIONS(59),
    [anon_sym_fpga_target] = ACTIONS(59),
    [anon_sym_pipeline] = ACTIONS(59),
    [anon_sym_target_frequency] = ACTIONS(59),
    [anon_sym_fields] = ACTIONS(62),
    [anon_sym_enum] = ACTIONS(62),
    [anon_sym_constraints] = ACTIONS(62),
    [anon_sym_base] = ACTIONS(62),
    [anon_sym_generic] = ACTIONS(62),
    [anon_sym_functions] = ACTIONS(62),
    [anon_sym_memory] = ACTIONS(62),
    [anon_sym_states] = ACTIONS(62),
    [anon_sym_transitions] = ACTIONS(62),
    [anon_sym_outputs] = ACTIONS(62),
    [anon_sym_timers] = ACTIONS(62),
    [anon_sym_flags] = ACTIONS(62),
    [anon_sym_given] = ACTIONS(65),
    [anon_sym_when] = ACTIONS(65),
    [anon_sym_then] = ACTIONS(65),
    [anon_sym_implementation] = ACTIONS(65),
    [anon_sym_input] = ACTIONS(65),
    [anon_sym_expected] = ACTIONS(65),
    [anon_sym_tolerance] = ACTIONS(65),
    [anon_sym_complexity] = ACTIONS(65),
    [anon_sym_pattern] = ACTIONS(65),
    [anon_sym_steps] = ACTIONS(65),
    [anon_sym_formula] = ACTIONS(65),
    [anon_sym_source] = ACTIONS(65),
    [anon_sym_transformer] = ACTIONS(65),
    [anon_sym_result] = ACTIONS(65),
    [anon_sym_target] = ACTIONS(65),
    [anon_sym_current] = ACTIONS(65),
    [anon_sym_predicted] = ACTIONS(65),
    [anon_sym_confidence] = ACTIONS(65),
    [anon_sym_status] = ACTIONS(65),
    [anon_sym_timeline] = ACTIONS(65),
    [anon_sym_width] = ACTIONS(65),
    [anon_sym_direction] = ACTIONS(65),
    [anon_sym_signed] = ACTIONS(65),
    [anon_sym_default] = ACTIONS(65),
    [anon_sym_initial] = ACTIONS(65),
    [anon_sym_encoding] = ACTIONS(65),
    [anon_sym_from] = ACTIONS(65),
    [anon_sym_to] = ACTIONS(65),
    [anon_sym_type] = ACTIONS(65),
    [anon_sym_level] = ACTIONS(65),
    [anon_sym_short] = ACTIONS(65),
    [anon_sym_category] = ACTIONS(65),
    [anon_sym_id] = ACTIONS(65),
    [anon_sym_statement] = ACTIONS(65),
    [anon_sym_significance] = ACTIONS(65),
    [anon_sym_size] = ACTIONS(65),
    [anon_sym_alignment] = ACTIONS(65),
    [anon_sym_scope] = ACTIONS(65),
    [anon_sym_timeout_constant] = ACTIONS(65),
    [anon_sym_timeout_value] = ACTIONS(65),
    [anon_sym_DASH] = ACTIONS(68),
    [anon_sym_DQUOTE] = ACTIONS(71),
    [sym_dotted_identifier] = ACTIONS(74),
    [sym_comment] = ACTIONS(3),
  },
  [6] = {
    [ts_builtin_sym_end] = ACTIONS(77),
    [sym_plain_identifier] = ACTIONS(79),
    [anon_sym_COLON] = ACTIONS(77),
    [anon_sym_name] = ACTIONS(79),
    [anon_sym_version] = ACTIONS(79),
    [anon_sym_language] = ACTIONS(79),
    [anon_sym_module] = ACTIONS(79),
    [anon_sym_description] = ACTIONS(79),
    [anon_sym_author] = ACTIONS(79),
    [anon_sym_license] = ACTIONS(79),
    [anon_sym_constants] = ACTIONS(79),
    [anon_sym_types] = ACTIONS(79),
    [anon_sym_behaviors] = ACTIONS(79),
    [anon_sym_algorithms] = ACTIONS(79),
    [anon_sym_imports] = ACTIONS(79),
    [anon_sym_creation_patterns] = ACTIONS(79),
    [anon_sym_wasm_exports] = ACTIONS(79),
    [anon_sym_pas_predictions] = ACTIONS(79),
    [anon_sym_signals] = ACTIONS(79),
    [anon_sym_fsm] = ACTIONS(79),
    [anon_sym_reset] = ACTIONS(79),
    [anon_sym_test_cases] = ACTIONS(79),
    [anon_sym_tests] = ACTIONS(79),
    [anon_sym_cli] = ACTIONS(79),
    [anon_sym_theorems] = ACTIONS(79),
    [anon_sym_targets] = ACTIONS(79),
    [anon_sym_fpga_target] = ACTIONS(79),
    [anon_sym_pipeline] = ACTIONS(79),
    [anon_sym_target_frequency] = ACTIONS(79),
    [anon_sym_fields] = ACTIONS(79),
    [anon_sym_enum] = ACTIONS(79),
    [anon_sym_constraints] = ACTIONS(79),
    [anon_sym_base] = ACTIONS(79),
    [anon_sym_generic] = ACTIONS(79),
    [anon_sym_functions] = ACTIONS(79),
    [anon_sym_memory] = ACTIONS(79),
    [anon_sym_states] = ACTIONS(79),
    [anon_sym_transitions] = ACTIONS(79),
    [anon_sym_outputs] = ACTIONS(79),
    [anon_sym_timers] = ACTIONS(79),
    [anon_sym_flags] = ACTIONS(79),
    [anon_sym_given] = ACTIONS(79),
    [anon_sym_when] = ACTIONS(79),
    [anon_sym_then] = ACTIONS(79),
    [anon_sym_implementation] = ACTIONS(79),
    [anon_sym_input] = ACTIONS(79),
    [anon_sym_expected] = ACTIONS(79),
    [anon_sym_tolerance] = ACTIONS(79),
    [anon_sym_complexity] = ACTIONS(79),
    [anon_sym_pattern] = ACTIONS(79),
    [anon_sym_steps] = ACTIONS(79),
    [anon_sym_formula] = ACTIONS(79),
    [anon_sym_source] = ACTIONS(79),
    [anon_sym_transformer] = ACTIONS(79),
    [anon_sym_result] = ACTIONS(79),
    [anon_sym_target] = ACTIONS(79),
    [anon_sym_current] = ACTIONS(79),
    [anon_sym_predicted] = ACTIONS(79),
    [anon_sym_confidence] = ACTIONS(79),
    [anon_sym_status] = ACTIONS(79),
    [anon_sym_timeline] = ACTIONS(79),
    [anon_sym_width] = ACTIONS(79),
    [anon_sym_direction] = ACTIONS(79),
    [anon_sym_signed] = ACTIONS(79),
    [anon_sym_default] = ACTIONS(79),
    [anon_sym_initial] = ACTIONS(79),
    [anon_sym_encoding] = ACTIONS(79),
    [anon_sym_from] = ACTIONS(79),
    [anon_sym_to] = ACTIONS(79),
    [anon_sym_type] = ACTIONS(79),
    [anon_sym_level] = ACTIONS(79),
    [anon_sym_short] = ACTIONS(79),
    [anon_sym_category] = ACTIONS(79),
    [anon_sym_id] = ACTIONS(79),
    [anon_sym_statement] = ACTIONS(79),
    [anon_sym_significance] = ACTIONS(79),
    [anon_sym_size] = ACTIONS(79),
    [anon_sym_alignment] = ACTIONS(79),
    [anon_sym_scope] = ACTIONS(79),
    [anon_sym_timeout_constant] = ACTIONS(79),
    [anon_sym_timeout_value] = ACTIONS(79),
    [anon_sym_DASH] = ACTIONS(77),
    [anon_sym_COMMA] = ACTIONS(77),
    [anon_sym_GT] = ACTIONS(77),
    [anon_sym_RBRACK] = ACTIONS(77),
    [anon_sym_DQUOTE] = ACTIONS(77),
    [anon_sym_RBRACE] = ACTIONS(77),
    [sym_dotted_identifier] = ACTIONS(77),
    [sym_comment] = ACTIONS(3),
  },
  [7] = {
    [ts_builtin_sym_end] = ACTIONS(81),
    [sym_plain_identifier] = ACTIONS(83),
    [anon_sym_COLON] = ACTIONS(81),
    [anon_sym_name] = ACTIONS(83),
    [anon_sym_version] = ACTIONS(83),
    [anon_sym_language] = ACTIONS(83),
    [anon_sym_module] = ACTIONS(83),
    [anon_sym_description] = ACTIONS(83),
    [anon_sym_author] = ACTIONS(83),
    [anon_sym_license] = ACTIONS(83),
    [anon_sym_constants] = ACTIONS(83),
    [anon_sym_types] = ACTIONS(83),
    [anon_sym_behaviors] = ACTIONS(83),
    [anon_sym_algorithms] = ACTIONS(83),
    [anon_sym_imports] = ACTIONS(83),
    [anon_sym_creation_patterns] = ACTIONS(83),
    [anon_sym_wasm_exports] = ACTIONS(83),
    [anon_sym_pas_predictions] = ACTIONS(83),
    [anon_sym_signals] = ACTIONS(83),
    [anon_sym_fsm] = ACTIONS(83),
    [anon_sym_reset] = ACTIONS(83),
    [anon_sym_test_cases] = ACTIONS(83),
    [anon_sym_tests] = ACTIONS(83),
    [anon_sym_cli] = ACTIONS(83),
    [anon_sym_theorems] = ACTIONS(83),
    [anon_sym_targets] = ACTIONS(83),
    [anon_sym_fpga_target] = ACTIONS(83),
    [anon_sym_pipeline] = ACTIONS(83),
    [anon_sym_target_frequency] = ACTIONS(83),
    [anon_sym_fields] = ACTIONS(83),
    [anon_sym_enum] = ACTIONS(83),
    [anon_sym_constraints] = ACTIONS(83),
    [anon_sym_base] = ACTIONS(83),
    [anon_sym_generic] = ACTIONS(83),
    [anon_sym_functions] = ACTIONS(83),
    [anon_sym_memory] = ACTIONS(83),
    [anon_sym_states] = ACTIONS(83),
    [anon_sym_transitions] = ACTIONS(83),
    [anon_sym_outputs] = ACTIONS(83),
    [anon_sym_timers] = ACTIONS(83),
    [anon_sym_flags] = ACTIONS(83),
    [anon_sym_given] = ACTIONS(83),
    [anon_sym_when] = ACTIONS(83),
    [anon_sym_then] = ACTIONS(83),
    [anon_sym_implementation] = ACTIONS(83),
    [anon_sym_input] = ACTIONS(83),
    [anon_sym_expected] = ACTIONS(83),
    [anon_sym_tolerance] = ACTIONS(83),
    [anon_sym_complexity] = ACTIONS(83),
    [anon_sym_pattern] = ACTIONS(83),
    [anon_sym_steps] = ACTIONS(83),
    [anon_sym_formula] = ACTIONS(83),
    [anon_sym_source] = ACTIONS(83),
    [anon_sym_transformer] = ACTIONS(83),
    [anon_sym_result] = ACTIONS(83),
    [anon_sym_target] = ACTIONS(83),
    [anon_sym_current] = ACTIONS(83),
    [anon_sym_predicted] = ACTIONS(83),
    [anon_sym_confidence] = ACTIONS(83),
    [anon_sym_status] = ACTIONS(83),
    [anon_sym_timeline] = ACTIONS(83),
    [anon_sym_width] = ACTIONS(83),
    [anon_sym_direction] = ACTIONS(83),
    [anon_sym_signed] = ACTIONS(83),
    [anon_sym_default] = ACTIONS(83),
    [anon_sym_initial] = ACTIONS(83),
    [anon_sym_encoding] = ACTIONS(83),
    [anon_sym_from] = ACTIONS(83),
    [anon_sym_to] = ACTIONS(83),
    [anon_sym_type] = ACTIONS(83),
    [anon_sym_level] = ACTIONS(83),
    [anon_sym_short] = ACTIONS(83),
    [anon_sym_category] = ACTIONS(83),
    [anon_sym_id] = ACTIONS(83),
    [anon_sym_statement] = ACTIONS(83),
    [anon_sym_significance] = ACTIONS(83),
    [anon_sym_size] = ACTIONS(83),
    [anon_sym_alignment] = ACTIONS(83),
    [anon_sym_scope] = ACTIONS(83),
    [anon_sym_timeout_constant] = ACTIONS(83),
    [anon_sym_timeout_value] = ACTIONS(83),
    [anon_sym_DASH] = ACTIONS(81),
    [anon_sym_COMMA] = ACTIONS(81),
    [anon_sym_RBRACK] = ACTIONS(81),
    [anon_sym_DQUOTE] = ACTIONS(81),
    [sym_dotted_identifier] = ACTIONS(81),
    [sym_comment] = ACTIONS(3),
  },
  [8] = {
    [ts_builtin_sym_end] = ACTIONS(85),
    [sym_plain_identifier] = ACTIONS(87),
    [anon_sym_COLON] = ACTIONS(85),
    [anon_sym_name] = ACTIONS(87),
    [anon_sym_version] = ACTIONS(87),
    [anon_sym_language] = ACTIONS(87),
    [anon_sym_module] = ACTIONS(87),
    [anon_sym_description] = ACTIONS(87),
    [anon_sym_author] = ACTIONS(87),
    [anon_sym_license] = ACTIONS(87),
    [anon_sym_constants] = ACTIONS(87),
    [anon_sym_types] = ACTIONS(87),
    [anon_sym_behaviors] = ACTIONS(87),
    [anon_sym_algorithms] = ACTIONS(87),
    [anon_sym_imports] = ACTIONS(87),
    [anon_sym_creation_patterns] = ACTIONS(87),
    [anon_sym_wasm_exports] = ACTIONS(87),
    [anon_sym_pas_predictions] = ACTIONS(87),
    [anon_sym_signals] = ACTIONS(87),
    [anon_sym_fsm] = ACTIONS(87),
    [anon_sym_reset] = ACTIONS(87),
    [anon_sym_test_cases] = ACTIONS(87),
    [anon_sym_tests] = ACTIONS(87),
    [anon_sym_cli] = ACTIONS(87),
    [anon_sym_theorems] = ACTIONS(87),
    [anon_sym_targets] = ACTIONS(87),
    [anon_sym_fpga_target] = ACTIONS(87),
    [anon_sym_pipeline] = ACTIONS(87),
    [anon_sym_target_frequency] = ACTIONS(87),
    [anon_sym_fields] = ACTIONS(87),
    [anon_sym_enum] = ACTIONS(87),
    [anon_sym_constraints] = ACTIONS(87),
    [anon_sym_base] = ACTIONS(87),
    [anon_sym_generic] = ACTIONS(87),
    [anon_sym_functions] = ACTIONS(87),
    [anon_sym_memory] = ACTIONS(87),
    [anon_sym_states] = ACTIONS(87),
    [anon_sym_transitions] = ACTIONS(87),
    [anon_sym_outputs] = ACTIONS(87),
    [anon_sym_timers] = ACTIONS(87),
    [anon_sym_flags] = ACTIONS(87),
    [anon_sym_given] = ACTIONS(87),
    [anon_sym_when] = ACTIONS(87),
    [anon_sym_then] = ACTIONS(87),
    [anon_sym_implementation] = ACTIONS(87),
    [anon_sym_input] = ACTIONS(87),
    [anon_sym_expected] = ACTIONS(87),
    [anon_sym_tolerance] = ACTIONS(87),
    [anon_sym_complexity] = ACTIONS(87),
    [anon_sym_pattern] = ACTIONS(87),
    [anon_sym_steps] = ACTIONS(87),
    [anon_sym_formula] = ACTIONS(87),
    [anon_sym_source] = ACTIONS(87),
    [anon_sym_transformer] = ACTIONS(87),
    [anon_sym_result] = ACTIONS(87),
    [anon_sym_target] = ACTIONS(87),
    [anon_sym_current] = ACTIONS(87),
    [anon_sym_predicted] = ACTIONS(87),
    [anon_sym_confidence] = ACTIONS(87),
    [anon_sym_status] = ACTIONS(87),
    [anon_sym_timeline] = ACTIONS(87),
    [anon_sym_width] = ACTIONS(87),
    [anon_sym_direction] = ACTIONS(87),
    [anon_sym_signed] = ACTIONS(87),
    [anon_sym_default] = ACTIONS(87),
    [anon_sym_initial] = ACTIONS(87),
    [anon_sym_encoding] = ACTIONS(87),
    [anon_sym_from] = ACTIONS(87),
    [anon_sym_to] = ACTIONS(87),
    [anon_sym_type] = ACTIONS(87),
    [anon_sym_level] = ACTIONS(87),
    [anon_sym_short] = ACTIONS(87),
    [anon_sym_category] = ACTIONS(87),
    [anon_sym_id] = ACTIONS(87),
    [anon_sym_statement] = ACTIONS(87),
    [anon_sym_significance] = ACTIONS(87),
    [anon_sym_size] = ACTIONS(87),
    [anon_sym_alignment] = ACTIONS(87),
    [anon_sym_scope] = ACTIONS(87),
    [anon_sym_timeout_constant] = ACTIONS(87),
    [anon_sym_timeout_value] = ACTIONS(87),
    [anon_sym_DASH] = ACTIONS(85),
    [anon_sym_COMMA] = ACTIONS(85),
    [anon_sym_RBRACK] = ACTIONS(85),
    [anon_sym_DQUOTE] = ACTIONS(85),
    [sym_dotted_identifier] = ACTIONS(85),
    [sym_comment] = ACTIONS(3),
  },
  [9] = {
    [ts_builtin_sym_end] = ACTIONS(89),
    [sym_plain_identifier] = ACTIONS(91),
    [anon_sym_name] = ACTIONS(91),
    [anon_sym_version] = ACTIONS(91),
    [anon_sym_language] = ACTIONS(91),
    [anon_sym_module] = ACTIONS(91),
    [anon_sym_description] = ACTIONS(91),
    [anon_sym_author] = ACTIONS(91),
    [anon_sym_license] = ACTIONS(91),
    [anon_sym_constants] = ACTIONS(91),
    [anon_sym_types] = ACTIONS(91),
    [anon_sym_behaviors] = ACTIONS(91),
    [anon_sym_algorithms] = ACTIONS(91),
    [anon_sym_imports] = ACTIONS(91),
    [anon_sym_creation_patterns] = ACTIONS(91),
    [anon_sym_wasm_exports] = ACTIONS(91),
    [anon_sym_pas_predictions] = ACTIONS(91),
    [anon_sym_signals] = ACTIONS(91),
    [anon_sym_fsm] = ACTIONS(91),
    [anon_sym_reset] = ACTIONS(91),
    [anon_sym_test_cases] = ACTIONS(91),
    [anon_sym_tests] = ACTIONS(91),
    [anon_sym_cli] = ACTIONS(91),
    [anon_sym_theorems] = ACTIONS(91),
    [anon_sym_targets] = ACTIONS(91),
    [anon_sym_fpga_target] = ACTIONS(91),
    [anon_sym_pipeline] = ACTIONS(91),
    [anon_sym_target_frequency] = ACTIONS(91),
    [anon_sym_fields] = ACTIONS(91),
    [anon_sym_enum] = ACTIONS(91),
    [anon_sym_constraints] = ACTIONS(91),
    [anon_sym_base] = ACTIONS(91),
    [anon_sym_generic] = ACTIONS(91),
    [anon_sym_functions] = ACTIONS(91),
    [anon_sym_memory] = ACTIONS(91),
    [anon_sym_states] = ACTIONS(91),
    [anon_sym_transitions] = ACTIONS(91),
    [anon_sym_outputs] = ACTIONS(91),
    [anon_sym_timers] = ACTIONS(91),
    [anon_sym_flags] = ACTIONS(91),
    [anon_sym_given] = ACTIONS(91),
    [anon_sym_when] = ACTIONS(91),
    [anon_sym_then] = ACTIONS(91),
    [anon_sym_implementation] = ACTIONS(91),
    [anon_sym_input] = ACTIONS(91),
    [anon_sym_expected] = ACTIONS(91),
    [anon_sym_tolerance] = ACTIONS(91),
    [anon_sym_complexity] = ACTIONS(91),
    [anon_sym_pattern] = ACTIONS(91),
    [anon_sym_steps] = ACTIONS(91),
    [anon_sym_formula] = ACTIONS(91),
    [anon_sym_source] = ACTIONS(91),
    [anon_sym_transformer] = ACTIONS(91),
    [anon_sym_result] = ACTIONS(91),
    [anon_sym_target] = ACTIONS(91),
    [anon_sym_current] = ACTIONS(91),
    [anon_sym_predicted] = ACTIONS(91),
    [anon_sym_confidence] = ACTIONS(91),
    [anon_sym_status] = ACTIONS(91),
    [anon_sym_timeline] = ACTIONS(91),
    [anon_sym_width] = ACTIONS(91),
    [anon_sym_direction] = ACTIONS(91),
    [anon_sym_signed] = ACTIONS(91),
    [anon_sym_default] = ACTIONS(91),
    [anon_sym_initial] = ACTIONS(91),
    [anon_sym_encoding] = ACTIONS(91),
    [anon_sym_from] = ACTIONS(91),
    [anon_sym_to] = ACTIONS(91),
    [anon_sym_type] = ACTIONS(91),
    [anon_sym_level] = ACTIONS(91),
    [anon_sym_short] = ACTIONS(91),
    [anon_sym_category] = ACTIONS(91),
    [anon_sym_id] = ACTIONS(91),
    [anon_sym_statement] = ACTIONS(91),
    [anon_sym_significance] = ACTIONS(91),
    [anon_sym_size] = ACTIONS(91),
    [anon_sym_alignment] = ACTIONS(91),
    [anon_sym_scope] = ACTIONS(91),
    [anon_sym_timeout_constant] = ACTIONS(91),
    [anon_sym_timeout_value] = ACTIONS(91),
    [anon_sym_DASH] = ACTIONS(89),
    [anon_sym_COMMA] = ACTIONS(89),
    [anon_sym_RBRACK] = ACTIONS(89),
    [anon_sym_DQUOTE] = ACTIONS(89),
    [sym_dotted_identifier] = ACTIONS(89),
    [sym_comment] = ACTIONS(3),
  },
  [10] = {
    [ts_builtin_sym_end] = ACTIONS(93),
    [sym_plain_identifier] = ACTIONS(95),
    [anon_sym_name] = ACTIONS(95),
    [anon_sym_version] = ACTIONS(95),
    [anon_sym_language] = ACTIONS(95),
    [anon_sym_module] = ACTIONS(95),
    [anon_sym_description] = ACTIONS(95),
    [anon_sym_author] = ACTIONS(95),
    [anon_sym_license] = ACTIONS(95),
    [anon_sym_constants] = ACTIONS(95),
    [anon_sym_types] = ACTIONS(95),
    [anon_sym_behaviors] = ACTIONS(95),
    [anon_sym_algorithms] = ACTIONS(95),
    [anon_sym_imports] = ACTIONS(95),
    [anon_sym_creation_patterns] = ACTIONS(95),
    [anon_sym_wasm_exports] = ACTIONS(95),
    [anon_sym_pas_predictions] = ACTIONS(95),
    [anon_sym_signals] = ACTIONS(95),
    [anon_sym_fsm] = ACTIONS(95),
    [anon_sym_reset] = ACTIONS(95),
    [anon_sym_test_cases] = ACTIONS(95),
    [anon_sym_tests] = ACTIONS(95),
    [anon_sym_cli] = ACTIONS(95),
    [anon_sym_theorems] = ACTIONS(95),
    [anon_sym_targets] = ACTIONS(95),
    [anon_sym_fpga_target] = ACTIONS(95),
    [anon_sym_pipeline] = ACTIONS(95),
    [anon_sym_target_frequency] = ACTIONS(95),
    [anon_sym_fields] = ACTIONS(95),
    [anon_sym_enum] = ACTIONS(95),
    [anon_sym_constraints] = ACTIONS(95),
    [anon_sym_base] = ACTIONS(95),
    [anon_sym_generic] = ACTIONS(95),
    [anon_sym_functions] = ACTIONS(95),
    [anon_sym_memory] = ACTIONS(95),
    [anon_sym_states] = ACTIONS(95),
    [anon_sym_transitions] = ACTIONS(95),
    [anon_sym_outputs] = ACTIONS(95),
    [anon_sym_timers] = ACTIONS(95),
    [anon_sym_flags] = ACTIONS(95),
    [anon_sym_given] = ACTIONS(95),
    [anon_sym_when] = ACTIONS(95),
    [anon_sym_then] = ACTIONS(95),
    [anon_sym_implementation] = ACTIONS(95),
    [anon_sym_input] = ACTIONS(95),
    [anon_sym_expected] = ACTIONS(95),
    [anon_sym_tolerance] = ACTIONS(95),
    [anon_sym_complexity] = ACTIONS(95),
    [anon_sym_pattern] = ACTIONS(95),
    [anon_sym_steps] = ACTIONS(95),
    [anon_sym_formula] = ACTIONS(95),
    [anon_sym_source] = ACTIONS(95),
    [anon_sym_transformer] = ACTIONS(95),
    [anon_sym_result] = ACTIONS(95),
    [anon_sym_target] = ACTIONS(95),
    [anon_sym_current] = ACTIONS(95),
    [anon_sym_predicted] = ACTIONS(95),
    [anon_sym_confidence] = ACTIONS(95),
    [anon_sym_status] = ACTIONS(95),
    [anon_sym_timeline] = ACTIONS(95),
    [anon_sym_width] = ACTIONS(95),
    [anon_sym_direction] = ACTIONS(95),
    [anon_sym_signed] = ACTIONS(95),
    [anon_sym_default] = ACTIONS(95),
    [anon_sym_initial] = ACTIONS(95),
    [anon_sym_encoding] = ACTIONS(95),
    [anon_sym_from] = ACTIONS(95),
    [anon_sym_to] = ACTIONS(95),
    [anon_sym_type] = ACTIONS(95),
    [anon_sym_level] = ACTIONS(95),
    [anon_sym_short] = ACTIONS(95),
    [anon_sym_category] = ACTIONS(95),
    [anon_sym_id] = ACTIONS(95),
    [anon_sym_statement] = ACTIONS(95),
    [anon_sym_significance] = ACTIONS(95),
    [anon_sym_size] = ACTIONS(95),
    [anon_sym_alignment] = ACTIONS(95),
    [anon_sym_scope] = ACTIONS(95),
    [anon_sym_timeout_constant] = ACTIONS(95),
    [anon_sym_timeout_value] = ACTIONS(95),
    [anon_sym_DASH] = ACTIONS(93),
    [anon_sym_COMMA] = ACTIONS(93),
    [anon_sym_RBRACK] = ACTIONS(93),
    [anon_sym_DQUOTE] = ACTIONS(93),
    [sym_dotted_identifier] = ACTIONS(93),
    [sym_comment] = ACTIONS(3),
  },
  [11] = {
    [ts_builtin_sym_end] = ACTIONS(97),
    [sym_plain_identifier] = ACTIONS(99),
    [anon_sym_name] = ACTIONS(99),
    [anon_sym_version] = ACTIONS(99),
    [anon_sym_language] = ACTIONS(99),
    [anon_sym_module] = ACTIONS(99),
    [anon_sym_description] = ACTIONS(99),
    [anon_sym_author] = ACTIONS(99),
    [anon_sym_license] = ACTIONS(99),
    [anon_sym_constants] = ACTIONS(99),
    [anon_sym_types] = ACTIONS(99),
    [anon_sym_behaviors] = ACTIONS(99),
    [anon_sym_algorithms] = ACTIONS(99),
    [anon_sym_imports] = ACTIONS(99),
    [anon_sym_creation_patterns] = ACTIONS(99),
    [anon_sym_wasm_exports] = ACTIONS(99),
    [anon_sym_pas_predictions] = ACTIONS(99),
    [anon_sym_signals] = ACTIONS(99),
    [anon_sym_fsm] = ACTIONS(99),
    [anon_sym_reset] = ACTIONS(99),
    [anon_sym_test_cases] = ACTIONS(99),
    [anon_sym_tests] = ACTIONS(99),
    [anon_sym_cli] = ACTIONS(99),
    [anon_sym_theorems] = ACTIONS(99),
    [anon_sym_targets] = ACTIONS(99),
    [anon_sym_fpga_target] = ACTIONS(99),
    [anon_sym_pipeline] = ACTIONS(99),
    [anon_sym_target_frequency] = ACTIONS(99),
    [anon_sym_fields] = ACTIONS(99),
    [anon_sym_enum] = ACTIONS(99),
    [anon_sym_constraints] = ACTIONS(99),
    [anon_sym_base] = ACTIONS(99),
    [anon_sym_generic] = ACTIONS(99),
    [anon_sym_functions] = ACTIONS(99),
    [anon_sym_memory] = ACTIONS(99),
    [anon_sym_states] = ACTIONS(99),
    [anon_sym_transitions] = ACTIONS(99),
    [anon_sym_outputs] = ACTIONS(99),
    [anon_sym_timers] = ACTIONS(99),
    [anon_sym_flags] = ACTIONS(99),
    [anon_sym_given] = ACTIONS(99),
    [anon_sym_when] = ACTIONS(99),
    [anon_sym_then] = ACTIONS(99),
    [anon_sym_implementation] = ACTIONS(99),
    [anon_sym_input] = ACTIONS(99),
    [anon_sym_expected] = ACTIONS(99),
    [anon_sym_tolerance] = ACTIONS(99),
    [anon_sym_complexity] = ACTIONS(99),
    [anon_sym_pattern] = ACTIONS(99),
    [anon_sym_steps] = ACTIONS(99),
    [anon_sym_formula] = ACTIONS(99),
    [anon_sym_source] = ACTIONS(99),
    [anon_sym_transformer] = ACTIONS(99),
    [anon_sym_result] = ACTIONS(99),
    [anon_sym_target] = ACTIONS(99),
    [anon_sym_current] = ACTIONS(99),
    [anon_sym_predicted] = ACTIONS(99),
    [anon_sym_confidence] = ACTIONS(99),
    [anon_sym_status] = ACTIONS(99),
    [anon_sym_timeline] = ACTIONS(99),
    [anon_sym_width] = ACTIONS(99),
    [anon_sym_direction] = ACTIONS(99),
    [anon_sym_signed] = ACTIONS(99),
    [anon_sym_default] = ACTIONS(99),
    [anon_sym_initial] = ACTIONS(99),
    [anon_sym_encoding] = ACTIONS(99),
    [anon_sym_from] = ACTIONS(99),
    [anon_sym_to] = ACTIONS(99),
    [anon_sym_type] = ACTIONS(99),
    [anon_sym_level] = ACTIONS(99),
    [anon_sym_short] = ACTIONS(99),
    [anon_sym_category] = ACTIONS(99),
    [anon_sym_id] = ACTIONS(99),
    [anon_sym_statement] = ACTIONS(99),
    [anon_sym_significance] = ACTIONS(99),
    [anon_sym_size] = ACTIONS(99),
    [anon_sym_alignment] = ACTIONS(99),
    [anon_sym_scope] = ACTIONS(99),
    [anon_sym_timeout_constant] = ACTIONS(99),
    [anon_sym_timeout_value] = ACTIONS(99),
    [anon_sym_DASH] = ACTIONS(97),
    [anon_sym_COMMA] = ACTIONS(97),
    [anon_sym_GT] = ACTIONS(97),
    [anon_sym_DQUOTE] = ACTIONS(97),
    [sym_dotted_identifier] = ACTIONS(97),
    [sym_comment] = ACTIONS(3),
  },
  [12] = {
    [ts_builtin_sym_end] = ACTIONS(101),
    [sym_plain_identifier] = ACTIONS(103),
    [anon_sym_name] = ACTIONS(103),
    [anon_sym_version] = ACTIONS(103),
    [anon_sym_language] = ACTIONS(103),
    [anon_sym_module] = ACTIONS(103),
    [anon_sym_description] = ACTIONS(103),
    [anon_sym_author] = ACTIONS(103),
    [anon_sym_license] = ACTIONS(103),
    [anon_sym_constants] = ACTIONS(103),
    [anon_sym_types] = ACTIONS(103),
    [anon_sym_behaviors] = ACTIONS(103),
    [anon_sym_algorithms] = ACTIONS(103),
    [anon_sym_imports] = ACTIONS(103),
    [anon_sym_creation_patterns] = ACTIONS(103),
    [anon_sym_wasm_exports] = ACTIONS(103),
    [anon_sym_pas_predictions] = ACTIONS(103),
    [anon_sym_signals] = ACTIONS(103),
    [anon_sym_fsm] = ACTIONS(103),
    [anon_sym_reset] = ACTIONS(103),
    [anon_sym_test_cases] = ACTIONS(103),
    [anon_sym_tests] = ACTIONS(103),
    [anon_sym_cli] = ACTIONS(103),
    [anon_sym_theorems] = ACTIONS(103),
    [anon_sym_targets] = ACTIONS(103),
    [anon_sym_fpga_target] = ACTIONS(103),
    [anon_sym_pipeline] = ACTIONS(103),
    [anon_sym_target_frequency] = ACTIONS(103),
    [anon_sym_fields] = ACTIONS(103),
    [anon_sym_enum] = ACTIONS(103),
    [anon_sym_constraints] = ACTIONS(103),
    [anon_sym_base] = ACTIONS(103),
    [anon_sym_generic] = ACTIONS(103),
    [anon_sym_functions] = ACTIONS(103),
    [anon_sym_memory] = ACTIONS(103),
    [anon_sym_states] = ACTIONS(103),
    [anon_sym_transitions] = ACTIONS(103),
    [anon_sym_outputs] = ACTIONS(103),
    [anon_sym_timers] = ACTIONS(103),
    [anon_sym_flags] = ACTIONS(103),
    [anon_sym_given] = ACTIONS(103),
    [anon_sym_when] = ACTIONS(103),
    [anon_sym_then] = ACTIONS(103),
    [anon_sym_implementation] = ACTIONS(103),
    [anon_sym_input] = ACTIONS(103),
    [anon_sym_expected] = ACTIONS(103),
    [anon_sym_tolerance] = ACTIONS(103),
    [anon_sym_complexity] = ACTIONS(103),
    [anon_sym_pattern] = ACTIONS(103),
    [anon_sym_steps] = ACTIONS(103),
    [anon_sym_formula] = ACTIONS(103),
    [anon_sym_source] = ACTIONS(103),
    [anon_sym_transformer] = ACTIONS(103),
    [anon_sym_result] = ACTIONS(103),
    [anon_sym_target] = ACTIONS(103),
    [anon_sym_current] = ACTIONS(103),
    [anon_sym_predicted] = ACTIONS(103),
    [anon_sym_confidence] = ACTIONS(103),
    [anon_sym_status] = ACTIONS(103),
    [anon_sym_timeline] = ACTIONS(103),
    [anon_sym_width] = ACTIONS(103),
    [anon_sym_direction] = ACTIONS(103),
    [anon_sym_signed] = ACTIONS(103),
    [anon_sym_default] = ACTIONS(103),
    [anon_sym_initial] = ACTIONS(103),
    [anon_sym_encoding] = ACTIONS(103),
    [anon_sym_from] = ACTIONS(103),
    [anon_sym_to] = ACTIONS(103),
    [anon_sym_type] = ACTIONS(103),
    [anon_sym_level] = ACTIONS(103),
    [anon_sym_short] = ACTIONS(103),
    [anon_sym_category] = ACTIONS(103),
    [anon_sym_id] = ACTIONS(103),
    [anon_sym_statement] = ACTIONS(103),
    [anon_sym_significance] = ACTIONS(103),
    [anon_sym_size] = ACTIONS(103),
    [anon_sym_alignment] = ACTIONS(103),
    [anon_sym_scope] = ACTIONS(103),
    [anon_sym_timeout_constant] = ACTIONS(103),
    [anon_sym_timeout_value] = ACTIONS(103),
    [anon_sym_DASH] = ACTIONS(101),
    [anon_sym_COMMA] = ACTIONS(101),
    [anon_sym_GT] = ACTIONS(101),
    [anon_sym_DQUOTE] = ACTIONS(101),
    [sym_dotted_identifier] = ACTIONS(101),
    [sym_comment] = ACTIONS(3),
  },
  [13] = {
    [ts_builtin_sym_end] = ACTIONS(105),
    [sym_plain_identifier] = ACTIONS(107),
    [anon_sym_COLON] = ACTIONS(109),
    [anon_sym_name] = ACTIONS(107),
    [anon_sym_version] = ACTIONS(107),
    [anon_sym_language] = ACTIONS(107),
    [anon_sym_module] = ACTIONS(107),
    [anon_sym_description] = ACTIONS(107),
    [anon_sym_author] = ACTIONS(107),
    [anon_sym_license] = ACTIONS(107),
    [anon_sym_constants] = ACTIONS(107),
    [anon_sym_types] = ACTIONS(107),
    [anon_sym_behaviors] = ACTIONS(107),
    [anon_sym_algorithms] = ACTIONS(107),
    [anon_sym_imports] = ACTIONS(107),
    [anon_sym_creation_patterns] = ACTIONS(107),
    [anon_sym_wasm_exports] = ACTIONS(107),
    [anon_sym_pas_predictions] = ACTIONS(107),
    [anon_sym_signals] = ACTIONS(107),
    [anon_sym_fsm] = ACTIONS(107),
    [anon_sym_reset] = ACTIONS(107),
    [anon_sym_test_cases] = ACTIONS(107),
    [anon_sym_tests] = ACTIONS(107),
    [anon_sym_cli] = ACTIONS(107),
    [anon_sym_theorems] = ACTIONS(107),
    [anon_sym_targets] = ACTIONS(107),
    [anon_sym_fpga_target] = ACTIONS(107),
    [anon_sym_pipeline] = ACTIONS(107),
    [anon_sym_target_frequency] = ACTIONS(107),
    [anon_sym_fields] = ACTIONS(107),
    [anon_sym_enum] = ACTIONS(107),
    [anon_sym_constraints] = ACTIONS(107),
    [anon_sym_base] = ACTIONS(107),
    [anon_sym_generic] = ACTIONS(107),
    [anon_sym_functions] = ACTIONS(107),
    [anon_sym_memory] = ACTIONS(107),
    [anon_sym_states] = ACTIONS(107),
    [anon_sym_transitions] = ACTIONS(107),
    [anon_sym_outputs] = ACTIONS(107),
    [anon_sym_timers] = ACTIONS(107),
    [anon_sym_flags] = ACTIONS(107),
    [anon_sym_given] = ACTIONS(107),
    [anon_sym_when] = ACTIONS(107),
    [anon_sym_then] = ACTIONS(107),
    [anon_sym_implementation] = ACTIONS(107),
    [anon_sym_input] = ACTIONS(107),
    [anon_sym_expected] = ACTIONS(107),
    [anon_sym_tolerance] = ACTIONS(107),
    [anon_sym_complexity] = ACTIONS(107),
    [anon_sym_pattern] = ACTIONS(107),
    [anon_sym_steps] = ACTIONS(107),
    [anon_sym_formula] = ACTIONS(107),
    [anon_sym_source] = ACTIONS(107),
    [anon_sym_transformer] = ACTIONS(107),
    [anon_sym_result] = ACTIONS(107),
    [anon_sym_target] = ACTIONS(107),
    [anon_sym_current] = ACTIONS(107),
    [anon_sym_predicted] = ACTIONS(107),
    [anon_sym_confidence] = ACTIONS(107),
    [anon_sym_status] = ACTIONS(107),
    [anon_sym_timeline] = ACTIONS(107),
    [anon_sym_width] = ACTIONS(107),
    [anon_sym_direction] = ACTIONS(107),
    [anon_sym_signed] = ACTIONS(107),
    [anon_sym_default] = ACTIONS(107),
    [anon_sym_initial] = ACTIONS(107),
    [anon_sym_encoding] = ACTIONS(107),
    [anon_sym_from] = ACTIONS(107),
    [anon_sym_to] = ACTIONS(107),
    [anon_sym_type] = ACTIONS(107),
    [anon_sym_level] = ACTIONS(107),
    [anon_sym_short] = ACTIONS(107),
    [anon_sym_category] = ACTIONS(107),
    [anon_sym_id] = ACTIONS(107),
    [anon_sym_statement] = ACTIONS(107),
    [anon_sym_significance] = ACTIONS(107),
    [anon_sym_size] = ACTIONS(107),
    [anon_sym_alignment] = ACTIONS(107),
    [anon_sym_scope] = ACTIONS(107),
    [anon_sym_timeout_constant] = ACTIONS(107),
    [anon_sym_timeout_value] = ACTIONS(107),
    [anon_sym_DASH] = ACTIONS(105),
    [anon_sym_DQUOTE] = ACTIONS(105),
    [sym_dotted_identifier] = ACTIONS(105),
    [sym_comment] = ACTIONS(3),
  },
  [14] = {
    [ts_builtin_sym_end] = ACTIONS(111),
    [sym_plain_identifier] = ACTIONS(113),
    [anon_sym_name] = ACTIONS(113),
    [anon_sym_version] = ACTIONS(113),
    [anon_sym_language] = ACTIONS(113),
    [anon_sym_module] = ACTIONS(113),
    [anon_sym_description] = ACTIONS(113),
    [anon_sym_author] = ACTIONS(113),
    [anon_sym_license] = ACTIONS(113),
    [anon_sym_constants] = ACTIONS(113),
    [anon_sym_types] = ACTIONS(113),
    [anon_sym_behaviors] = ACTIONS(113),
    [anon_sym_algorithms] = ACTIONS(113),
    [anon_sym_imports] = ACTIONS(113),
    [anon_sym_creation_patterns] = ACTIONS(113),
    [anon_sym_wasm_exports] = ACTIONS(113),
    [anon_sym_pas_predictions] = ACTIONS(113),
    [anon_sym_signals] = ACTIONS(113),
    [anon_sym_fsm] = ACTIONS(113),
    [anon_sym_reset] = ACTIONS(113),
    [anon_sym_test_cases] = ACTIONS(113),
    [anon_sym_tests] = ACTIONS(113),
    [anon_sym_cli] = ACTIONS(113),
    [anon_sym_theorems] = ACTIONS(113),
    [anon_sym_targets] = ACTIONS(113),
    [anon_sym_fpga_target] = ACTIONS(113),
    [anon_sym_pipeline] = ACTIONS(113),
    [anon_sym_target_frequency] = ACTIONS(113),
    [anon_sym_fields] = ACTIONS(113),
    [anon_sym_enum] = ACTIONS(113),
    [anon_sym_constraints] = ACTIONS(113),
    [anon_sym_base] = ACTIONS(113),
    [anon_sym_generic] = ACTIONS(113),
    [anon_sym_functions] = ACTIONS(113),
    [anon_sym_memory] = ACTIONS(113),
    [anon_sym_states] = ACTIONS(113),
    [anon_sym_transitions] = ACTIONS(113),
    [anon_sym_outputs] = ACTIONS(113),
    [anon_sym_timers] = ACTIONS(113),
    [anon_sym_flags] = ACTIONS(113),
    [anon_sym_given] = ACTIONS(113),
    [anon_sym_when] = ACTIONS(113),
    [anon_sym_then] = ACTIONS(113),
    [anon_sym_implementation] = ACTIONS(113),
    [anon_sym_input] = ACTIONS(113),
    [anon_sym_expected] = ACTIONS(113),
    [anon_sym_tolerance] = ACTIONS(113),
    [anon_sym_complexity] = ACTIONS(113),
    [anon_sym_pattern] = ACTIONS(113),
    [anon_sym_steps] = ACTIONS(113),
    [anon_sym_formula] = ACTIONS(113),
    [anon_sym_source] = ACTIONS(113),
    [anon_sym_transformer] = ACTIONS(113),
    [anon_sym_result] = ACTIONS(113),
    [anon_sym_target] = ACTIONS(113),
    [anon_sym_current] = ACTIONS(113),
    [anon_sym_predicted] = ACTIONS(113),
    [anon_sym_confidence] = ACTIONS(113),
    [anon_sym_status] = ACTIONS(113),
    [anon_sym_timeline] = ACTIONS(113),
    [anon_sym_width] = ACTIONS(113),
    [anon_sym_direction] = ACTIONS(113),
    [anon_sym_signed] = ACTIONS(113),
    [anon_sym_default] = ACTIONS(113),
    [anon_sym_initial] = ACTIONS(113),
    [anon_sym_encoding] = ACTIONS(113),
    [anon_sym_from] = ACTIONS(113),
    [anon_sym_to] = ACTIONS(113),
    [anon_sym_type] = ACTIONS(113),
    [anon_sym_level] = ACTIONS(113),
    [anon_sym_short] = ACTIONS(113),
    [anon_sym_category] = ACTIONS(113),
    [anon_sym_id] = ACTIONS(113),
    [anon_sym_statement] = ACTIONS(113),
    [anon_sym_significance] = ACTIONS(113),
    [anon_sym_size] = ACTIONS(113),
    [anon_sym_alignment] = ACTIONS(113),
    [anon_sym_scope] = ACTIONS(113),
    [anon_sym_timeout_constant] = ACTIONS(113),
    [anon_sym_timeout_value] = ACTIONS(113),
    [anon_sym_DASH] = ACTIONS(111),
    [anon_sym_DQUOTE] = ACTIONS(111),
    [sym_dotted_identifier] = ACTIONS(111),
    [sym_comment] = ACTIONS(3),
  },
  [15] = {
    [ts_builtin_sym_end] = ACTIONS(115),
    [sym_plain_identifier] = ACTIONS(117),
    [anon_sym_name] = ACTIONS(117),
    [anon_sym_version] = ACTIONS(117),
    [anon_sym_language] = ACTIONS(117),
    [anon_sym_module] = ACTIONS(117),
    [anon_sym_description] = ACTIONS(117),
    [anon_sym_author] = ACTIONS(117),
    [anon_sym_license] = ACTIONS(117),
    [anon_sym_constants] = ACTIONS(117),
    [anon_sym_types] = ACTIONS(117),
    [anon_sym_behaviors] = ACTIONS(117),
    [anon_sym_algorithms] = ACTIONS(117),
    [anon_sym_imports] = ACTIONS(117),
    [anon_sym_creation_patterns] = ACTIONS(117),
    [anon_sym_wasm_exports] = ACTIONS(117),
    [anon_sym_pas_predictions] = ACTIONS(117),
    [anon_sym_signals] = ACTIONS(117),
    [anon_sym_fsm] = ACTIONS(117),
    [anon_sym_reset] = ACTIONS(117),
    [anon_sym_test_cases] = ACTIONS(117),
    [anon_sym_tests] = ACTIONS(117),
    [anon_sym_cli] = ACTIONS(117),
    [anon_sym_theorems] = ACTIONS(117),
    [anon_sym_targets] = ACTIONS(117),
    [anon_sym_fpga_target] = ACTIONS(117),
    [anon_sym_pipeline] = ACTIONS(117),
    [anon_sym_target_frequency] = ACTIONS(117),
    [anon_sym_fields] = ACTIONS(117),
    [anon_sym_enum] = ACTIONS(117),
    [anon_sym_constraints] = ACTIONS(117),
    [anon_sym_base] = ACTIONS(117),
    [anon_sym_generic] = ACTIONS(117),
    [anon_sym_functions] = ACTIONS(117),
    [anon_sym_memory] = ACTIONS(117),
    [anon_sym_states] = ACTIONS(117),
    [anon_sym_transitions] = ACTIONS(117),
    [anon_sym_outputs] = ACTIONS(117),
    [anon_sym_timers] = ACTIONS(117),
    [anon_sym_flags] = ACTIONS(117),
    [anon_sym_given] = ACTIONS(117),
    [anon_sym_when] = ACTIONS(117),
    [anon_sym_then] = ACTIONS(117),
    [anon_sym_implementation] = ACTIONS(117),
    [anon_sym_input] = ACTIONS(117),
    [anon_sym_expected] = ACTIONS(117),
    [anon_sym_tolerance] = ACTIONS(117),
    [anon_sym_complexity] = ACTIONS(117),
    [anon_sym_pattern] = ACTIONS(117),
    [anon_sym_steps] = ACTIONS(117),
    [anon_sym_formula] = ACTIONS(117),
    [anon_sym_source] = ACTIONS(117),
    [anon_sym_transformer] = ACTIONS(117),
    [anon_sym_result] = ACTIONS(117),
    [anon_sym_target] = ACTIONS(117),
    [anon_sym_current] = ACTIONS(117),
    [anon_sym_predicted] = ACTIONS(117),
    [anon_sym_confidence] = ACTIONS(117),
    [anon_sym_status] = ACTIONS(117),
    [anon_sym_timeline] = ACTIONS(117),
    [anon_sym_width] = ACTIONS(117),
    [anon_sym_direction] = ACTIONS(117),
    [anon_sym_signed] = ACTIONS(117),
    [anon_sym_default] = ACTIONS(117),
    [anon_sym_initial] = ACTIONS(117),
    [anon_sym_encoding] = ACTIONS(117),
    [anon_sym_from] = ACTIONS(117),
    [anon_sym_to] = ACTIONS(117),
    [anon_sym_type] = ACTIONS(117),
    [anon_sym_level] = ACTIONS(117),
    [anon_sym_short] = ACTIONS(117),
    [anon_sym_category] = ACTIONS(117),
    [anon_sym_id] = ACTIONS(117),
    [anon_sym_statement] = ACTIONS(117),
    [anon_sym_significance] = ACTIONS(117),
    [anon_sym_size] = ACTIONS(117),
    [anon_sym_alignment] = ACTIONS(117),
    [anon_sym_scope] = ACTIONS(117),
    [anon_sym_timeout_constant] = ACTIONS(117),
    [anon_sym_timeout_value] = ACTIONS(117),
    [anon_sym_DASH] = ACTIONS(115),
    [anon_sym_DQUOTE] = ACTIONS(115),
    [sym_dotted_identifier] = ACTIONS(115),
    [sym_comment] = ACTIONS(3),
  },
  [16] = {
    [ts_builtin_sym_end] = ACTIONS(119),
    [sym_plain_identifier] = ACTIONS(121),
    [anon_sym_name] = ACTIONS(121),
    [anon_sym_version] = ACTIONS(121),
    [anon_sym_language] = ACTIONS(121),
    [anon_sym_module] = ACTIONS(121),
    [anon_sym_description] = ACTIONS(121),
    [anon_sym_author] = ACTIONS(121),
    [anon_sym_license] = ACTIONS(121),
    [anon_sym_constants] = ACTIONS(121),
    [anon_sym_types] = ACTIONS(121),
    [anon_sym_behaviors] = ACTIONS(121),
    [anon_sym_algorithms] = ACTIONS(121),
    [anon_sym_imports] = ACTIONS(121),
    [anon_sym_creation_patterns] = ACTIONS(121),
    [anon_sym_wasm_exports] = ACTIONS(121),
    [anon_sym_pas_predictions] = ACTIONS(121),
    [anon_sym_signals] = ACTIONS(121),
    [anon_sym_fsm] = ACTIONS(121),
    [anon_sym_reset] = ACTIONS(121),
    [anon_sym_test_cases] = ACTIONS(121),
    [anon_sym_tests] = ACTIONS(121),
    [anon_sym_cli] = ACTIONS(121),
    [anon_sym_theorems] = ACTIONS(121),
    [anon_sym_targets] = ACTIONS(121),
    [anon_sym_fpga_target] = ACTIONS(121),
    [anon_sym_pipeline] = ACTIONS(121),
    [anon_sym_target_frequency] = ACTIONS(121),
    [anon_sym_fields] = ACTIONS(121),
    [anon_sym_enum] = ACTIONS(121),
    [anon_sym_constraints] = ACTIONS(121),
    [anon_sym_base] = ACTIONS(121),
    [anon_sym_generic] = ACTIONS(121),
    [anon_sym_functions] = ACTIONS(121),
    [anon_sym_memory] = ACTIONS(121),
    [anon_sym_states] = ACTIONS(121),
    [anon_sym_transitions] = ACTIONS(121),
    [anon_sym_outputs] = ACTIONS(121),
    [anon_sym_timers] = ACTIONS(121),
    [anon_sym_flags] = ACTIONS(121),
    [anon_sym_given] = ACTIONS(121),
    [anon_sym_when] = ACTIONS(121),
    [anon_sym_then] = ACTIONS(121),
    [anon_sym_implementation] = ACTIONS(121),
    [anon_sym_input] = ACTIONS(121),
    [anon_sym_expected] = ACTIONS(121),
    [anon_sym_tolerance] = ACTIONS(121),
    [anon_sym_complexity] = ACTIONS(121),
    [anon_sym_pattern] = ACTIONS(121),
    [anon_sym_steps] = ACTIONS(121),
    [anon_sym_formula] = ACTIONS(121),
    [anon_sym_source] = ACTIONS(121),
    [anon_sym_transformer] = ACTIONS(121),
    [anon_sym_result] = ACTIONS(121),
    [anon_sym_target] = ACTIONS(121),
    [anon_sym_current] = ACTIONS(121),
    [anon_sym_predicted] = ACTIONS(121),
    [anon_sym_confidence] = ACTIONS(121),
    [anon_sym_status] = ACTIONS(121),
    [anon_sym_timeline] = ACTIONS(121),
    [anon_sym_width] = ACTIONS(121),
    [anon_sym_direction] = ACTIONS(121),
    [anon_sym_signed] = ACTIONS(121),
    [anon_sym_default] = ACTIONS(121),
    [anon_sym_initial] = ACTIONS(121),
    [anon_sym_encoding] = ACTIONS(121),
    [anon_sym_from] = ACTIONS(121),
    [anon_sym_to] = ACTIONS(121),
    [anon_sym_type] = ACTIONS(121),
    [anon_sym_level] = ACTIONS(121),
    [anon_sym_short] = ACTIONS(121),
    [anon_sym_category] = ACTIONS(121),
    [anon_sym_id] = ACTIONS(121),
    [anon_sym_statement] = ACTIONS(121),
    [anon_sym_significance] = ACTIONS(121),
    [anon_sym_size] = ACTIONS(121),
    [anon_sym_alignment] = ACTIONS(121),
    [anon_sym_scope] = ACTIONS(121),
    [anon_sym_timeout_constant] = ACTIONS(121),
    [anon_sym_timeout_value] = ACTIONS(121),
    [anon_sym_DASH] = ACTIONS(119),
    [anon_sym_DQUOTE] = ACTIONS(119),
    [sym_dotted_identifier] = ACTIONS(119),
    [sym_comment] = ACTIONS(3),
  },
  [17] = {
    [ts_builtin_sym_end] = ACTIONS(123),
    [sym_plain_identifier] = ACTIONS(125),
    [anon_sym_name] = ACTIONS(125),
    [anon_sym_version] = ACTIONS(125),
    [anon_sym_language] = ACTIONS(125),
    [anon_sym_module] = ACTIONS(125),
    [anon_sym_description] = ACTIONS(125),
    [anon_sym_author] = ACTIONS(125),
    [anon_sym_license] = ACTIONS(125),
    [anon_sym_constants] = ACTIONS(125),
    [anon_sym_types] = ACTIONS(125),
    [anon_sym_behaviors] = ACTIONS(125),
    [anon_sym_algorithms] = ACTIONS(125),
    [anon_sym_imports] = ACTIONS(125),
    [anon_sym_creation_patterns] = ACTIONS(125),
    [anon_sym_wasm_exports] = ACTIONS(125),
    [anon_sym_pas_predictions] = ACTIONS(125),
    [anon_sym_signals] = ACTIONS(125),
    [anon_sym_fsm] = ACTIONS(125),
    [anon_sym_reset] = ACTIONS(125),
    [anon_sym_test_cases] = ACTIONS(125),
    [anon_sym_tests] = ACTIONS(125),
    [anon_sym_cli] = ACTIONS(125),
    [anon_sym_theorems] = ACTIONS(125),
    [anon_sym_targets] = ACTIONS(125),
    [anon_sym_fpga_target] = ACTIONS(125),
    [anon_sym_pipeline] = ACTIONS(125),
    [anon_sym_target_frequency] = ACTIONS(125),
    [anon_sym_fields] = ACTIONS(125),
    [anon_sym_enum] = ACTIONS(125),
    [anon_sym_constraints] = ACTIONS(125),
    [anon_sym_base] = ACTIONS(125),
    [anon_sym_generic] = ACTIONS(125),
    [anon_sym_functions] = ACTIONS(125),
    [anon_sym_memory] = ACTIONS(125),
    [anon_sym_states] = ACTIONS(125),
    [anon_sym_transitions] = ACTIONS(125),
    [anon_sym_outputs] = ACTIONS(125),
    [anon_sym_timers] = ACTIONS(125),
    [anon_sym_flags] = ACTIONS(125),
    [anon_sym_given] = ACTIONS(125),
    [anon_sym_when] = ACTIONS(125),
    [anon_sym_then] = ACTIONS(125),
    [anon_sym_implementation] = ACTIONS(125),
    [anon_sym_input] = ACTIONS(125),
    [anon_sym_expected] = ACTIONS(125),
    [anon_sym_tolerance] = ACTIONS(125),
    [anon_sym_complexity] = ACTIONS(125),
    [anon_sym_pattern] = ACTIONS(125),
    [anon_sym_steps] = ACTIONS(125),
    [anon_sym_formula] = ACTIONS(125),
    [anon_sym_source] = ACTIONS(125),
    [anon_sym_transformer] = ACTIONS(125),
    [anon_sym_result] = ACTIONS(125),
    [anon_sym_target] = ACTIONS(125),
    [anon_sym_current] = ACTIONS(125),
    [anon_sym_predicted] = ACTIONS(125),
    [anon_sym_confidence] = ACTIONS(125),
    [anon_sym_status] = ACTIONS(125),
    [anon_sym_timeline] = ACTIONS(125),
    [anon_sym_width] = ACTIONS(125),
    [anon_sym_direction] = ACTIONS(125),
    [anon_sym_signed] = ACTIONS(125),
    [anon_sym_default] = ACTIONS(125),
    [anon_sym_initial] = ACTIONS(125),
    [anon_sym_encoding] = ACTIONS(125),
    [anon_sym_from] = ACTIONS(125),
    [anon_sym_to] = ACTIONS(125),
    [anon_sym_type] = ACTIONS(125),
    [anon_sym_level] = ACTIONS(125),
    [anon_sym_short] = ACTIONS(125),
    [anon_sym_category] = ACTIONS(125),
    [anon_sym_id] = ACTIONS(125),
    [anon_sym_statement] = ACTIONS(125),
    [anon_sym_significance] = ACTIONS(125),
    [anon_sym_size] = ACTIONS(125),
    [anon_sym_alignment] = ACTIONS(125),
    [anon_sym_scope] = ACTIONS(125),
    [anon_sym_timeout_constant] = ACTIONS(125),
    [anon_sym_timeout_value] = ACTIONS(125),
    [anon_sym_DASH] = ACTIONS(123),
    [anon_sym_DQUOTE] = ACTIONS(123),
    [sym_dotted_identifier] = ACTIONS(123),
    [sym_comment] = ACTIONS(3),
  },
  [18] = {
    [ts_builtin_sym_end] = ACTIONS(127),
    [sym_plain_identifier] = ACTIONS(129),
    [anon_sym_name] = ACTIONS(129),
    [anon_sym_version] = ACTIONS(129),
    [anon_sym_language] = ACTIONS(129),
    [anon_sym_module] = ACTIONS(129),
    [anon_sym_description] = ACTIONS(129),
    [anon_sym_author] = ACTIONS(129),
    [anon_sym_license] = ACTIONS(129),
    [anon_sym_constants] = ACTIONS(129),
    [anon_sym_types] = ACTIONS(129),
    [anon_sym_behaviors] = ACTIONS(129),
    [anon_sym_algorithms] = ACTIONS(129),
    [anon_sym_imports] = ACTIONS(129),
    [anon_sym_creation_patterns] = ACTIONS(129),
    [anon_sym_wasm_exports] = ACTIONS(129),
    [anon_sym_pas_predictions] = ACTIONS(129),
    [anon_sym_signals] = ACTIONS(129),
    [anon_sym_fsm] = ACTIONS(129),
    [anon_sym_reset] = ACTIONS(129),
    [anon_sym_test_cases] = ACTIONS(129),
    [anon_sym_tests] = ACTIONS(129),
    [anon_sym_cli] = ACTIONS(129),
    [anon_sym_theorems] = ACTIONS(129),
    [anon_sym_targets] = ACTIONS(129),
    [anon_sym_fpga_target] = ACTIONS(129),
    [anon_sym_pipeline] = ACTIONS(129),
    [anon_sym_target_frequency] = ACTIONS(129),
    [anon_sym_fields] = ACTIONS(129),
    [anon_sym_enum] = ACTIONS(129),
    [anon_sym_constraints] = ACTIONS(129),
    [anon_sym_base] = ACTIONS(129),
    [anon_sym_generic] = ACTIONS(129),
    [anon_sym_functions] = ACTIONS(129),
    [anon_sym_memory] = ACTIONS(129),
    [anon_sym_states] = ACTIONS(129),
    [anon_sym_transitions] = ACTIONS(129),
    [anon_sym_outputs] = ACTIONS(129),
    [anon_sym_timers] = ACTIONS(129),
    [anon_sym_flags] = ACTIONS(129),
    [anon_sym_given] = ACTIONS(129),
    [anon_sym_when] = ACTIONS(129),
    [anon_sym_then] = ACTIONS(129),
    [anon_sym_implementation] = ACTIONS(129),
    [anon_sym_input] = ACTIONS(129),
    [anon_sym_expected] = ACTIONS(129),
    [anon_sym_tolerance] = ACTIONS(129),
    [anon_sym_complexity] = ACTIONS(129),
    [anon_sym_pattern] = ACTIONS(129),
    [anon_sym_steps] = ACTIONS(129),
    [anon_sym_formula] = ACTIONS(129),
    [anon_sym_source] = ACTIONS(129),
    [anon_sym_transformer] = ACTIONS(129),
    [anon_sym_result] = ACTIONS(129),
    [anon_sym_target] = ACTIONS(129),
    [anon_sym_current] = ACTIONS(129),
    [anon_sym_predicted] = ACTIONS(129),
    [anon_sym_confidence] = ACTIONS(129),
    [anon_sym_status] = ACTIONS(129),
    [anon_sym_timeline] = ACTIONS(129),
    [anon_sym_width] = ACTIONS(129),
    [anon_sym_direction] = ACTIONS(129),
    [anon_sym_signed] = ACTIONS(129),
    [anon_sym_default] = ACTIONS(129),
    [anon_sym_initial] = ACTIONS(129),
    [anon_sym_encoding] = ACTIONS(129),
    [anon_sym_from] = ACTIONS(129),
    [anon_sym_to] = ACTIONS(129),
    [anon_sym_type] = ACTIONS(129),
    [anon_sym_level] = ACTIONS(129),
    [anon_sym_short] = ACTIONS(129),
    [anon_sym_category] = ACTIONS(129),
    [anon_sym_id] = ACTIONS(129),
    [anon_sym_statement] = ACTIONS(129),
    [anon_sym_significance] = ACTIONS(129),
    [anon_sym_size] = ACTIONS(129),
    [anon_sym_alignment] = ACTIONS(129),
    [anon_sym_scope] = ACTIONS(129),
    [anon_sym_timeout_constant] = ACTIONS(129),
    [anon_sym_timeout_value] = ACTIONS(129),
    [anon_sym_DASH] = ACTIONS(127),
    [anon_sym_DQUOTE] = ACTIONS(127),
    [sym_dotted_identifier] = ACTIONS(127),
    [sym_comment] = ACTIONS(3),
  },
  [19] = {
    [ts_builtin_sym_end] = ACTIONS(131),
    [sym_plain_identifier] = ACTIONS(133),
    [anon_sym_name] = ACTIONS(133),
    [anon_sym_version] = ACTIONS(133),
    [anon_sym_language] = ACTIONS(133),
    [anon_sym_module] = ACTIONS(133),
    [anon_sym_description] = ACTIONS(133),
    [anon_sym_author] = ACTIONS(133),
    [anon_sym_license] = ACTIONS(133),
    [anon_sym_constants] = ACTIONS(133),
    [anon_sym_types] = ACTIONS(133),
    [anon_sym_behaviors] = ACTIONS(133),
    [anon_sym_algorithms] = ACTIONS(133),
    [anon_sym_imports] = ACTIONS(133),
    [anon_sym_creation_patterns] = ACTIONS(133),
    [anon_sym_wasm_exports] = ACTIONS(133),
    [anon_sym_pas_predictions] = ACTIONS(133),
    [anon_sym_signals] = ACTIONS(133),
    [anon_sym_fsm] = ACTIONS(133),
    [anon_sym_reset] = ACTIONS(133),
    [anon_sym_test_cases] = ACTIONS(133),
    [anon_sym_tests] = ACTIONS(133),
    [anon_sym_cli] = ACTIONS(133),
    [anon_sym_theorems] = ACTIONS(133),
    [anon_sym_targets] = ACTIONS(133),
    [anon_sym_fpga_target] = ACTIONS(133),
    [anon_sym_pipeline] = ACTIONS(133),
    [anon_sym_target_frequency] = ACTIONS(133),
    [anon_sym_fields] = ACTIONS(133),
    [anon_sym_enum] = ACTIONS(133),
    [anon_sym_constraints] = ACTIONS(133),
    [anon_sym_base] = ACTIONS(133),
    [anon_sym_generic] = ACTIONS(133),
    [anon_sym_functions] = ACTIONS(133),
    [anon_sym_memory] = ACTIONS(133),
    [anon_sym_states] = ACTIONS(133),
    [anon_sym_transitions] = ACTIONS(133),
    [anon_sym_outputs] = ACTIONS(133),
    [anon_sym_timers] = ACTIONS(133),
    [anon_sym_flags] = ACTIONS(133),
    [anon_sym_given] = ACTIONS(133),
    [anon_sym_when] = ACTIONS(133),
    [anon_sym_then] = ACTIONS(133),
    [anon_sym_implementation] = ACTIONS(133),
    [anon_sym_input] = ACTIONS(133),
    [anon_sym_expected] = ACTIONS(133),
    [anon_sym_tolerance] = ACTIONS(133),
    [anon_sym_complexity] = ACTIONS(133),
    [anon_sym_pattern] = ACTIONS(133),
    [anon_sym_steps] = ACTIONS(133),
    [anon_sym_formula] = ACTIONS(133),
    [anon_sym_source] = ACTIONS(133),
    [anon_sym_transformer] = ACTIONS(133),
    [anon_sym_result] = ACTIONS(133),
    [anon_sym_target] = ACTIONS(133),
    [anon_sym_current] = ACTIONS(133),
    [anon_sym_predicted] = ACTIONS(133),
    [anon_sym_confidence] = ACTIONS(133),
    [anon_sym_status] = ACTIONS(133),
    [anon_sym_timeline] = ACTIONS(133),
    [anon_sym_width] = ACTIONS(133),
    [anon_sym_direction] = ACTIONS(133),
    [anon_sym_signed] = ACTIONS(133),
    [anon_sym_default] = ACTIONS(133),
    [anon_sym_initial] = ACTIONS(133),
    [anon_sym_encoding] = ACTIONS(133),
    [anon_sym_from] = ACTIONS(133),
    [anon_sym_to] = ACTIONS(133),
    [anon_sym_type] = ACTIONS(133),
    [anon_sym_level] = ACTIONS(133),
    [anon_sym_short] = ACTIONS(133),
    [anon_sym_category] = ACTIONS(133),
    [anon_sym_id] = ACTIONS(133),
    [anon_sym_statement] = ACTIONS(133),
    [anon_sym_significance] = ACTIONS(133),
    [anon_sym_size] = ACTIONS(133),
    [anon_sym_alignment] = ACTIONS(133),
    [anon_sym_scope] = ACTIONS(133),
    [anon_sym_timeout_constant] = ACTIONS(133),
    [anon_sym_timeout_value] = ACTIONS(133),
    [anon_sym_DASH] = ACTIONS(131),
    [anon_sym_DQUOTE] = ACTIONS(131),
    [sym_dotted_identifier] = ACTIONS(131),
    [sym_comment] = ACTIONS(3),
  },
  [20] = {
    [ts_builtin_sym_end] = ACTIONS(135),
    [sym_plain_identifier] = ACTIONS(137),
    [anon_sym_name] = ACTIONS(137),
    [anon_sym_version] = ACTIONS(137),
    [anon_sym_language] = ACTIONS(137),
    [anon_sym_module] = ACTIONS(137),
    [anon_sym_description] = ACTIONS(137),
    [anon_sym_author] = ACTIONS(137),
    [anon_sym_license] = ACTIONS(137),
    [anon_sym_constants] = ACTIONS(137),
    [anon_sym_types] = ACTIONS(137),
    [anon_sym_behaviors] = ACTIONS(137),
    [anon_sym_algorithms] = ACTIONS(137),
    [anon_sym_imports] = ACTIONS(137),
    [anon_sym_creation_patterns] = ACTIONS(137),
    [anon_sym_wasm_exports] = ACTIONS(137),
    [anon_sym_pas_predictions] = ACTIONS(137),
    [anon_sym_signals] = ACTIONS(137),
    [anon_sym_fsm] = ACTIONS(137),
    [anon_sym_reset] = ACTIONS(137),
    [anon_sym_test_cases] = ACTIONS(137),
    [anon_sym_tests] = ACTIONS(137),
    [anon_sym_cli] = ACTIONS(137),
    [anon_sym_theorems] = ACTIONS(137),
    [anon_sym_targets] = ACTIONS(137),
    [anon_sym_fpga_target] = ACTIONS(137),
    [anon_sym_pipeline] = ACTIONS(137),
    [anon_sym_target_frequency] = ACTIONS(137),
    [anon_sym_fields] = ACTIONS(137),
    [anon_sym_enum] = ACTIONS(137),
    [anon_sym_constraints] = ACTIONS(137),
    [anon_sym_base] = ACTIONS(137),
    [anon_sym_generic] = ACTIONS(137),
    [anon_sym_functions] = ACTIONS(137),
    [anon_sym_memory] = ACTIONS(137),
    [anon_sym_states] = ACTIONS(137),
    [anon_sym_transitions] = ACTIONS(137),
    [anon_sym_outputs] = ACTIONS(137),
    [anon_sym_timers] = ACTIONS(137),
    [anon_sym_flags] = ACTIONS(137),
    [anon_sym_given] = ACTIONS(137),
    [anon_sym_when] = ACTIONS(137),
    [anon_sym_then] = ACTIONS(137),
    [anon_sym_implementation] = ACTIONS(137),
    [anon_sym_input] = ACTIONS(137),
    [anon_sym_expected] = ACTIONS(137),
    [anon_sym_tolerance] = ACTIONS(137),
    [anon_sym_complexity] = ACTIONS(137),
    [anon_sym_pattern] = ACTIONS(137),
    [anon_sym_steps] = ACTIONS(137),
    [anon_sym_formula] = ACTIONS(137),
    [anon_sym_source] = ACTIONS(137),
    [anon_sym_transformer] = ACTIONS(137),
    [anon_sym_result] = ACTIONS(137),
    [anon_sym_target] = ACTIONS(137),
    [anon_sym_current] = ACTIONS(137),
    [anon_sym_predicted] = ACTIONS(137),
    [anon_sym_confidence] = ACTIONS(137),
    [anon_sym_status] = ACTIONS(137),
    [anon_sym_timeline] = ACTIONS(137),
    [anon_sym_width] = ACTIONS(137),
    [anon_sym_direction] = ACTIONS(137),
    [anon_sym_signed] = ACTIONS(137),
    [anon_sym_default] = ACTIONS(137),
    [anon_sym_initial] = ACTIONS(137),
    [anon_sym_encoding] = ACTIONS(137),
    [anon_sym_from] = ACTIONS(137),
    [anon_sym_to] = ACTIONS(137),
    [anon_sym_type] = ACTIONS(137),
    [anon_sym_level] = ACTIONS(137),
    [anon_sym_short] = ACTIONS(137),
    [anon_sym_category] = ACTIONS(137),
    [anon_sym_id] = ACTIONS(137),
    [anon_sym_statement] = ACTIONS(137),
    [anon_sym_significance] = ACTIONS(137),
    [anon_sym_size] = ACTIONS(137),
    [anon_sym_alignment] = ACTIONS(137),
    [anon_sym_scope] = ACTIONS(137),
    [anon_sym_timeout_constant] = ACTIONS(137),
    [anon_sym_timeout_value] = ACTIONS(137),
    [anon_sym_DASH] = ACTIONS(135),
    [anon_sym_DQUOTE] = ACTIONS(135),
    [sym_dotted_identifier] = ACTIONS(135),
    [sym_comment] = ACTIONS(3),
  },
};

static const uint16_t ts_small_parse_table[] = {
  [0] = 11,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(7), 1,
      sym_plain_identifier,
    ACTIONS(17), 1,
      anon_sym_DQUOTE,
    ACTIONS(19), 1,
      sym_dotted_identifier,
    ACTIONS(139), 1,
      anon_sym_COMMA,
    ACTIONS(141), 1,
      anon_sym_RBRACK,
    ACTIONS(143), 1,
      sym_float_number,
    ACTIONS(145), 1,
      sym_number,
    ACTIONS(31), 2,
      anon_sym_true,
      anon_sym_false,
    ACTIONS(33), 3,
      anon_sym_null,
      anon_sym_nil,
      anon_sym_none,
    STATE(36), 5,
      sym__flow_value,
      sym_quoted_string,
      sym_boolean,
      sym_null_value,
      sym_identifier,
  [41] = 10,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(7), 1,
      sym_plain_identifier,
    ACTIONS(17), 1,
      anon_sym_DQUOTE,
    ACTIONS(19), 1,
      sym_dotted_identifier,
    ACTIONS(147), 1,
      anon_sym_RBRACK,
    ACTIONS(149), 1,
      sym_float_number,
    ACTIONS(151), 1,
      sym_number,
    ACTIONS(31), 2,
      anon_sym_true,
      anon_sym_false,
    ACTIONS(33), 3,
      anon_sym_null,
      anon_sym_nil,
      anon_sym_none,
    STATE(38), 5,
      sym__flow_value,
      sym_quoted_string,
      sym_boolean,
      sym_null_value,
      sym_identifier,
  [79] = 10,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(7), 1,
      sym_plain_identifier,
    ACTIONS(17), 1,
      anon_sym_DQUOTE,
    ACTIONS(19), 1,
      sym_dotted_identifier,
    ACTIONS(149), 1,
      sym_float_number,
    ACTIONS(151), 1,
      sym_number,
    ACTIONS(153), 1,
      anon_sym_RBRACK,
    ACTIONS(31), 2,
      anon_sym_true,
      anon_sym_false,
    ACTIONS(33), 3,
      anon_sym_null,
      anon_sym_nil,
      anon_sym_none,
    STATE(38), 5,
      sym__flow_value,
      sym_quoted_string,
      sym_boolean,
      sym_null_value,
      sym_identifier,
  [117] = 9,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(7), 1,
      sym_plain_identifier,
    ACTIONS(17), 1,
      anon_sym_DQUOTE,
    ACTIONS(19), 1,
      sym_dotted_identifier,
    ACTIONS(149), 1,
      sym_float_number,
    ACTIONS(151), 1,
      sym_number,
    ACTIONS(31), 2,
      anon_sym_true,
      anon_sym_false,
    ACTIONS(33), 3,
      anon_sym_null,
      anon_sym_nil,
      anon_sym_none,
    STATE(38), 5,
      sym__flow_value,
      sym_quoted_string,
      sym_boolean,
      sym_null_value,
      sym_identifier,
  [152] = 7,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(7), 1,
      sym_plain_identifier,
    ACTIONS(19), 1,
      sym_dotted_identifier,
    STATE(34), 1,
      sym_type_argument,
    STATE(45), 1,
      sym_generic_type_name,
    STATE(39), 2,
      sym_type_expression,
      sym_identifier,
    ACTIONS(21), 7,
      anon_sym_List,
      anon_sym_Set,
      anon_sym_Map,
      anon_sym_Option,
      anon_sym_Array,
      anon_sym_Dict,
      anon_sym_Tuple,
  [181] = 7,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(7), 1,
      sym_plain_identifier,
    ACTIONS(19), 1,
      sym_dotted_identifier,
    STATE(40), 1,
      sym_type_argument,
    STATE(45), 1,
      sym_generic_type_name,
    STATE(39), 2,
      sym_type_expression,
      sym_identifier,
    ACTIONS(21), 7,
      anon_sym_List,
      anon_sym_Set,
      anon_sym_Map,
      anon_sym_Option,
      anon_sym_Array,
      anon_sym_Dict,
      anon_sym_Tuple,
  [210] = 6,
    ACTIONS(155), 1,
      anon_sym_DQUOTE,
    ACTIONS(157), 1,
      sym_string_content,
    ACTIONS(159), 1,
      sym_escape_sequence,
    ACTIONS(161), 1,
      anon_sym_DOLLAR_LBRACE,
    ACTIONS(163), 1,
      sym_comment,
    STATE(28), 2,
      sym_interpolation,
      aux_sym_quoted_string_repeat1,
  [230] = 6,
    ACTIONS(161), 1,
      anon_sym_DOLLAR_LBRACE,
    ACTIONS(163), 1,
      sym_comment,
    ACTIONS(165), 1,
      anon_sym_DQUOTE,
    ACTIONS(167), 1,
      sym_string_content,
    ACTIONS(169), 1,
      sym_escape_sequence,
    STATE(29), 2,
      sym_interpolation,
      aux_sym_quoted_string_repeat1,
  [250] = 6,
    ACTIONS(163), 1,
      sym_comment,
    ACTIONS(171), 1,
      anon_sym_DQUOTE,
    ACTIONS(173), 1,
      sym_string_content,
    ACTIONS(176), 1,
      sym_escape_sequence,
    ACTIONS(179), 1,
      anon_sym_DOLLAR_LBRACE,
    STATE(29), 2,
      sym_interpolation,
      aux_sym_quoted_string_repeat1,
  [270] = 3,
    ACTIONS(163), 1,
      sym_comment,
    ACTIONS(182), 2,
      anon_sym_DQUOTE,
      sym_string_content,
    ACTIONS(184), 2,
      sym_escape_sequence,
      anon_sym_DOLLAR_LBRACE,
  [282] = 4,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(186), 1,
      anon_sym_COMMA,
    ACTIONS(189), 1,
      anon_sym_RBRACK,
    STATE(31), 1,
      aux_sym_flow_sequence_repeat1,
  [295] = 4,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(7), 1,
      sym_plain_identifier,
    ACTIONS(19), 1,
      sym_dotted_identifier,
    STATE(47), 1,
      sym_identifier,
  [308] = 4,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(147), 1,
      anon_sym_RBRACK,
    ACTIONS(191), 1,
      anon_sym_COMMA,
    STATE(31), 1,
      aux_sym_flow_sequence_repeat1,
  [321] = 4,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(193), 1,
      anon_sym_COMMA,
    ACTIONS(195), 1,
      anon_sym_GT,
    STATE(35), 1,
      aux_sym_type_expression_repeat1,
  [334] = 4,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(193), 1,
      anon_sym_COMMA,
    ACTIONS(197), 1,
      anon_sym_GT,
    STATE(37), 1,
      aux_sym_type_expression_repeat1,
  [347] = 4,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(199), 1,
      anon_sym_COMMA,
    ACTIONS(201), 1,
      anon_sym_RBRACK,
    STATE(33), 1,
      aux_sym_flow_sequence_repeat1,
  [360] = 4,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(203), 1,
      anon_sym_COMMA,
    ACTIONS(206), 1,
      anon_sym_GT,
    STATE(37), 1,
      aux_sym_type_expression_repeat1,
  [373] = 2,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(189), 2,
      anon_sym_COMMA,
      anon_sym_RBRACK,
  [381] = 2,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(208), 2,
      anon_sym_COMMA,
      anon_sym_GT,
  [389] = 2,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(206), 2,
      anon_sym_COMMA,
      anon_sym_GT,
  [397] = 2,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(210), 1,
      anon_sym_COLON,
  [404] = 2,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(212), 1,
      anon_sym_COLON,
  [411] = 2,
    ACTIONS(163), 1,
      sym_comment,
    ACTIONS(214), 1,
      aux_sym_multiline_string_token1,
  [418] = 2,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(201), 1,
      anon_sym_RBRACK,
  [425] = 2,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(216), 1,
      anon_sym_LT,
  [432] = 2,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(218), 1,
      anon_sym_COLON,
  [439] = 2,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(220), 1,
      anon_sym_RBRACE,
  [446] = 2,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(222), 1,
      anon_sym_COLON,
  [453] = 2,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(224), 1,
      ts_builtin_sym_end,
  [460] = 2,
    ACTIONS(3), 1,
      sym_comment,
    ACTIONS(226), 1,
      anon_sym_LT,
};

static const uint32_t ts_small_parse_table_map[] = {
  [SMALL_STATE(21)] = 0,
  [SMALL_STATE(22)] = 41,
  [SMALL_STATE(23)] = 79,
  [SMALL_STATE(24)] = 117,
  [SMALL_STATE(25)] = 152,
  [SMALL_STATE(26)] = 181,
  [SMALL_STATE(27)] = 210,
  [SMALL_STATE(28)] = 230,
  [SMALL_STATE(29)] = 250,
  [SMALL_STATE(30)] = 270,
  [SMALL_STATE(31)] = 282,
  [SMALL_STATE(32)] = 295,
  [SMALL_STATE(33)] = 308,
  [SMALL_STATE(34)] = 321,
  [SMALL_STATE(35)] = 334,
  [SMALL_STATE(36)] = 347,
  [SMALL_STATE(37)] = 360,
  [SMALL_STATE(38)] = 373,
  [SMALL_STATE(39)] = 381,
  [SMALL_STATE(40)] = 389,
  [SMALL_STATE(41)] = 397,
  [SMALL_STATE(42)] = 404,
  [SMALL_STATE(43)] = 411,
  [SMALL_STATE(44)] = 418,
  [SMALL_STATE(45)] = 425,
  [SMALL_STATE(46)] = 432,
  [SMALL_STATE(47)] = 439,
  [SMALL_STATE(48)] = 446,
  [SMALL_STATE(49)] = 453,
  [SMALL_STATE(50)] = 460,
};

static const TSParseActionEntry ts_parse_actions[] = {
  [0] = {.entry = {.count = 0, .reusable = false}},
  [1] = {.entry = {.count = 1, .reusable = false}}, RECOVER(),
  [3] = {.entry = {.count = 1, .reusable = true}}, SHIFT_EXTRA(),
  [5] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_source_file, 0, 0, 0),
  [7] = {.entry = {.count = 1, .reusable = false}}, SHIFT(6),
  [9] = {.entry = {.count = 1, .reusable = false}}, SHIFT(48),
  [11] = {.entry = {.count = 1, .reusable = false}}, SHIFT(41),
  [13] = {.entry = {.count = 1, .reusable = false}}, SHIFT(42),
  [15] = {.entry = {.count = 1, .reusable = true}}, SHIFT(2),
  [17] = {.entry = {.count = 1, .reusable = true}}, SHIFT(27),
  [19] = {.entry = {.count = 1, .reusable = true}}, SHIFT(6),
  [21] = {.entry = {.count = 1, .reusable = false}}, SHIFT(50),
  [23] = {.entry = {.count = 1, .reusable = true}}, SHIFT(21),
  [25] = {.entry = {.count = 1, .reusable = true}}, SHIFT(43),
  [27] = {.entry = {.count = 1, .reusable = true}}, SHIFT(14),
  [29] = {.entry = {.count = 1, .reusable = false}}, SHIFT(14),
  [31] = {.entry = {.count = 1, .reusable = false}}, SHIFT(9),
  [33] = {.entry = {.count = 1, .reusable = false}}, SHIFT(10),
  [35] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_pair, 2, 0, 1),
  [37] = {.entry = {.count = 2, .reusable = false}}, REDUCE(sym_pair, 2, 0, 1), SHIFT(6),
  [40] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_pair, 2, 0, 1),
  [42] = {.entry = {.count = 2, .reusable = true}}, REDUCE(sym_pair, 2, 0, 1), SHIFT(27),
  [45] = {.entry = {.count = 1, .reusable = true}}, SHIFT(17),
  [47] = {.entry = {.count = 1, .reusable = false}}, SHIFT(17),
  [49] = {.entry = {.count = 2, .reusable = true}}, REDUCE(sym_pair, 2, 0, 1), SHIFT(6),
  [52] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_source_file, 1, 0, 0),
  [54] = {.entry = {.count = 1, .reusable = true}}, REDUCE(aux_sym_source_file_repeat1, 2, 0, 0),
  [56] = {.entry = {.count = 2, .reusable = false}}, REDUCE(aux_sym_source_file_repeat1, 2, 0, 0), SHIFT_REPEAT(6),
  [59] = {.entry = {.count = 2, .reusable = false}}, REDUCE(aux_sym_source_file_repeat1, 2, 0, 0), SHIFT_REPEAT(48),
  [62] = {.entry = {.count = 2, .reusable = false}}, REDUCE(aux_sym_source_file_repeat1, 2, 0, 0), SHIFT_REPEAT(41),
  [65] = {.entry = {.count = 2, .reusable = false}}, REDUCE(aux_sym_source_file_repeat1, 2, 0, 0), SHIFT_REPEAT(42),
  [68] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_source_file_repeat1, 2, 0, 0), SHIFT_REPEAT(2),
  [71] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_source_file_repeat1, 2, 0, 0), SHIFT_REPEAT(27),
  [74] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_source_file_repeat1, 2, 0, 0), SHIFT_REPEAT(6),
  [77] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_identifier, 1, 0, 0),
  [79] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_identifier, 1, 0, 0),
  [81] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_quoted_string, 2, 0, 0),
  [83] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_quoted_string, 2, 0, 0),
  [85] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_quoted_string, 3, 0, 0),
  [87] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_quoted_string, 3, 0, 0),
  [89] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_boolean, 1, 0, 0),
  [91] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_boolean, 1, 0, 0),
  [93] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_null_value, 1, 0, 0),
  [95] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_null_value, 1, 0, 0),
  [97] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_type_expression, 4, 0, 3),
  [99] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_type_expression, 4, 0, 3),
  [101] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_type_expression, 5, 0, 3),
  [103] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_type_expression, 5, 0, 3),
  [105] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym__value, 1, 0, 0),
  [107] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym__value, 1, 0, 0),
  [109] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym__key, 1, 0, 0),
  [111] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_list_item, 2, 0, 0),
  [113] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_list_item, 2, 0, 0),
  [115] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_flow_sequence, 2, 0, 0),
  [117] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_flow_sequence, 2, 0, 0),
  [119] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_flow_sequence, 4, 0, 0),
  [121] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_flow_sequence, 4, 0, 0),
  [123] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_pair, 3, 0, 2),
  [125] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_pair, 3, 0, 2),
  [127] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_flow_sequence, 3, 0, 0),
  [129] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_flow_sequence, 3, 0, 0),
  [131] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_multiline_string, 2, 0, 0),
  [133] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_multiline_string, 2, 0, 0),
  [135] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_flow_sequence, 5, 0, 0),
  [137] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_flow_sequence, 5, 0, 0),
  [139] = {.entry = {.count = 1, .reusable = true}}, SHIFT(44),
  [141] = {.entry = {.count = 1, .reusable = true}}, SHIFT(15),
  [143] = {.entry = {.count = 1, .reusable = true}}, SHIFT(36),
  [145] = {.entry = {.count = 1, .reusable = false}}, SHIFT(36),
  [147] = {.entry = {.count = 1, .reusable = true}}, SHIFT(16),
  [149] = {.entry = {.count = 1, .reusable = true}}, SHIFT(38),
  [151] = {.entry = {.count = 1, .reusable = false}}, SHIFT(38),
  [153] = {.entry = {.count = 1, .reusable = true}}, SHIFT(20),
  [155] = {.entry = {.count = 1, .reusable = false}}, SHIFT(7),
  [157] = {.entry = {.count = 1, .reusable = false}}, SHIFT(28),
  [159] = {.entry = {.count = 1, .reusable = true}}, SHIFT(28),
  [161] = {.entry = {.count = 1, .reusable = true}}, SHIFT(32),
  [163] = {.entry = {.count = 1, .reusable = false}}, SHIFT_EXTRA(),
  [165] = {.entry = {.count = 1, .reusable = false}}, SHIFT(8),
  [167] = {.entry = {.count = 1, .reusable = false}}, SHIFT(29),
  [169] = {.entry = {.count = 1, .reusable = true}}, SHIFT(29),
  [171] = {.entry = {.count = 1, .reusable = false}}, REDUCE(aux_sym_quoted_string_repeat1, 2, 0, 0),
  [173] = {.entry = {.count = 2, .reusable = false}}, REDUCE(aux_sym_quoted_string_repeat1, 2, 0, 0), SHIFT_REPEAT(29),
  [176] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_quoted_string_repeat1, 2, 0, 0), SHIFT_REPEAT(29),
  [179] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_quoted_string_repeat1, 2, 0, 0), SHIFT_REPEAT(32),
  [182] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_interpolation, 3, 0, 0),
  [184] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_interpolation, 3, 0, 0),
  [186] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_flow_sequence_repeat1, 2, 0, 0), SHIFT_REPEAT(24),
  [189] = {.entry = {.count = 1, .reusable = true}}, REDUCE(aux_sym_flow_sequence_repeat1, 2, 0, 0),
  [191] = {.entry = {.count = 1, .reusable = true}}, SHIFT(23),
  [193] = {.entry = {.count = 1, .reusable = true}}, SHIFT(26),
  [195] = {.entry = {.count = 1, .reusable = true}}, SHIFT(11),
  [197] = {.entry = {.count = 1, .reusable = true}}, SHIFT(12),
  [199] = {.entry = {.count = 1, .reusable = true}}, SHIFT(22),
  [201] = {.entry = {.count = 1, .reusable = true}}, SHIFT(18),
  [203] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_type_expression_repeat1, 2, 0, 0), SHIFT_REPEAT(26),
  [206] = {.entry = {.count = 1, .reusable = true}}, REDUCE(aux_sym_type_expression_repeat1, 2, 0, 0),
  [208] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_type_argument, 1, 0, 0),
  [210] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_type_keyword, 1, 0, 0),
  [212] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_behavior_keyword, 1, 0, 0),
  [214] = {.entry = {.count = 1, .reusable = true}}, SHIFT(19),
  [216] = {.entry = {.count = 1, .reusable = true}}, SHIFT(25),
  [218] = {.entry = {.count = 1, .reusable = true}}, SHIFT(3),
  [220] = {.entry = {.count = 1, .reusable = true}}, SHIFT(30),
  [222] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_section_keyword, 1, 0, 0),
  [224] = {.entry = {.count = 1, .reusable = true}},  ACCEPT_INPUT(),
  [226] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_generic_type_name, 1, 0, 0),
};

#ifdef __cplusplus
extern "C" {
#endif
#ifdef TREE_SITTER_HIDE_SYMBOLS
#define TS_PUBLIC
#elif defined(_WIN32)
#define TS_PUBLIC __declspec(dllexport)
#else
#define TS_PUBLIC __attribute__((visibility("default")))
#endif

TS_PUBLIC const TSLanguage *tree_sitter_vibee(void) {
  static const TSLanguage language = {
    .version = LANGUAGE_VERSION,
    .symbol_count = SYMBOL_COUNT,
    .alias_count = ALIAS_COUNT,
    .token_count = TOKEN_COUNT,
    .external_token_count = EXTERNAL_TOKEN_COUNT,
    .state_count = STATE_COUNT,
    .large_state_count = LARGE_STATE_COUNT,
    .production_id_count = PRODUCTION_ID_COUNT,
    .field_count = FIELD_COUNT,
    .max_alias_sequence_length = MAX_ALIAS_SEQUENCE_LENGTH,
    .parse_table = &ts_parse_table[0][0],
    .small_parse_table = ts_small_parse_table,
    .small_parse_table_map = ts_small_parse_table_map,
    .parse_actions = ts_parse_actions,
    .symbol_names = ts_symbol_names,
    .field_names = ts_field_names,
    .field_map_slices = ts_field_map_slices,
    .field_map_entries = ts_field_map_entries,
    .symbol_metadata = ts_symbol_metadata,
    .public_symbol_map = ts_symbol_map,
    .alias_map = ts_non_terminal_alias_map,
    .alias_sequences = &ts_alias_sequences[0][0],
    .lex_modes = ts_lex_modes,
    .lex_fn = ts_lex,
    .keyword_lex_fn = ts_lex_keywords,
    .keyword_capture_token = sym_plain_identifier,
    .primary_state_ids = ts_primary_state_ids,
  };
  return &language;
}
#ifdef __cplusplus
}
#endif
