// Stub header for tree-sitter API when library is not installed
// Provides minimal type definitions to allow compilation

#ifndef TREE_SITTER_API_H
#define TREE_SITTER_API_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations
typedef struct TSLanguage TSLanguage;
typedef struct TSParser TSParser;
typedef struct TSTree TSTree;
typedef struct TSNode TSNode;
typedef struct TSPoint TSPoint;
typedef struct TSQuery TSQuery;
typedef struct TSQueryCursor TSQueryCursor;
typedef struct TSQueryMatch TSQueryMatch;
typedef struct TSQueryCapture TSQueryCapture;
typedef enum TSQueryError TSQueryError;
typedef enum TSSymbol TSSymbol;

// TSNode structure definition (needs to be complete)
struct TSNode {
    void* _dummy1;
    void* _dummy2;
    void* _dummy3;
    void* _dummy4;
};

// TSPoint structure definition
struct TSPoint {
    unsigned int row;
    unsigned int column;
};

// TSQueryCapture structure definition
struct TSQueryCapture {
    TSNode node;
    unsigned int index;
};

// TSQueryMatch structure definition (uses TSQueryCapture)
struct TSQueryMatch {
    unsigned int id;
    unsigned short pattern_index;
    unsigned short capture_count;
    TSQueryCapture* captures;
};

// Enum definitions
enum TSQueryError { None = 0 };
enum TSSymbol { Symbol = 0 };

// Stub functions that return NULL/0
static inline TSParser* ts_parser_new(void) { return (void*)0; }
static inline void ts_parser_delete(TSParser* parser) { (void)parser; }
static inline bool ts_parser_set_language(TSParser* parser, const TSLanguage* language) { (void)parser; (void)language; return false; }
static inline TSTree* ts_parser_parse_string(TSParser* parser, const TSTree* old_tree, const char* str, unsigned int len) { (void)parser; (void)old_tree; (void)str; (void)len; return (void*)0; }
static inline void ts_tree_delete(TSTree* tree) { (void)tree; }
static inline TSNode ts_tree_root_node(const TSTree* tree) { TSNode n = {0}; (void)tree; return n; }
static inline bool ts_node_is_null(TSNode node) { (void)node; return true; }
static inline const char* ts_node_type(TSNode node) { (void)node; return ""; }
static inline TSSymbol ts_node_symbol(TSNode node) { (void)node; return 0; }
static inline unsigned int ts_node_start_byte(TSNode node) { (void)node; return 0; }
static inline unsigned int ts_node_end_byte(TSNode node) { (void)node; return 0; }
static inline TSPoint ts_node_start_point(TSNode node) { TSPoint p = {0}; (void)node; return p; }
static inline TSPoint ts_node_end_point(TSNode node) { TSPoint p = {0}; (void)node; return p; }
static inline unsigned int ts_node_child_count(TSNode node) { (void)node; return 0; }
static inline unsigned int ts_node_named_child_count(TSNode node) { (void)node; return 0; }
static inline TSNode ts_node_child(TSNode node, unsigned int index) { TSNode n = {0}; (void)node; (void)index; return n; }
static inline TSNode ts_node_named_child(TSNode node, unsigned int index) { TSNode n = {0}; (void)node; (void)index; return n; }
static inline TSNode ts_node_child_by_field_name(TSNode node, const char* name, unsigned int name_len) { TSNode n = {0}; (void)node; (void)name; (void)name_len; return n; }
static inline TSNode ts_node_parent(TSNode node) { TSNode n = {0}; (void)node; return n; }
static inline TSNode ts_node_next_sibling(TSNode node) { TSNode n = {0}; (void)node; return n; }
static inline TSNode ts_node_prev_sibling(TSNode node) { TSNode n = {0}; (void)node; return n; }
static inline bool ts_node_is_named(TSNode node) { (void)node; return false; }
static inline bool ts_node_is_extra(TSNode node) { (void)node; return false; }
static inline bool ts_node_has_error(TSNode node) { (void)node; return false; }
static inline TSQuery* ts_query_new(const TSLanguage* language, const char* source, unsigned int len, unsigned int* error_offset, TSQueryError* error_type) { (void)language; (void)source; (void)len; (void)error_offset; (void)error_type; return (void*)0; }
static inline void ts_query_delete(TSQuery* query) { (void)query; }
static inline TSQueryCursor* ts_query_cursor_new(void) { return (void*)0; }
static inline void ts_query_cursor_delete(TSQueryCursor* cursor) { (void)cursor; }
static inline void ts_query_cursor_exec(TSQueryCursor* cursor, const TSQuery* query, TSNode node) { (void)cursor; (void)query; (void)node; }
static inline bool ts_query_cursor_next_capture(TSQueryCursor* cursor, TSQueryMatch* match, unsigned int* capture_index) { (void)cursor; (void)match; (void)capture_index; return false; }

#ifdef __cplusplus
}
#endif

#endif // TREE_SITTER_API_H
