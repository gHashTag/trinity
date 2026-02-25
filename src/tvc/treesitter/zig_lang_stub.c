/* Stub for tree_sitter_zig() when the grammar is not available.
 * Returns NULL, causing loadZigLanguage() to return error.LanguageNotFound.
 * Replace with real tree-sitter-zig grammar when available.
 */
typedef struct TSLanguage TSLanguage;
const TSLanguage *tree_sitter_zig(void) { return (void*)0; }
