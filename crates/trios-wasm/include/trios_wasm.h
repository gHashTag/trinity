#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * WASM page size (64 KB)
 */
#define WASM_PAGE_SIZE 65536

/**
 * Maximum number of imported functions
 */
#define MAX_IMPORTS 64

/**
 * Maximum number of exported functions
 */
#define MAX_EXPORTS 64

/**
 * Maximum number of memory pages
 */
#define MAX_MEMORY_PAGES 256

/**
 * Maximum function name length
 */
#define MAX_FUNC_NAME_LEN 128

/**
 * Maximum module name length
 */
#define MAX_MODULE_NAME_LEN 128

/**
 * Maximum number of function arguments
 */
#define MAX_FUNC_ARGS 16

/**
 * Trinity custom opcode base
 */
#define TRINITY_OPCODE_BASE 61440

/**
 * Module state
 */
typedef enum ModuleState {
  /**
   * Module loaded but not compiled
   */
  Loaded = 0,
  /**
   * Module compiled and ready
   */
  Compiled = 1,
  /**
   * Module instantiated and running
   */
  Instantiated = 2,
  /**
   * Module errored
   */
  Errored = 3,
  /**
   * Module unloaded
   */
  Unloaded = 4,
} ModuleState;

/**
 * WASM execution result
 */
typedef enum WasmResult {
  /**
   * Execution succeeded
   */
  Ok = 0,
  /**
   * Module compilation failed
   */
  CompileError = 1,
  /**
   * Link error (missing imports)
   */
  LinkError = 2,
  /**
   * Runtime trap
   */
  Trap = 3,
  /**
   * Out of memory
   */
  OutOfMemory = 4,
  /**
   * Invalid argument
   */
  InvalidArg = 5,
  /**
   * Module not found
   */
  ModuleNotFound = 6,
  /**
   * Function not found
   */
  FuncNotFound = 7,
  /**
   * Memory access violation
   */
  MemoryAccessViolation = 8,
  /**
   * Timeout
   */
  Timeout = 9,
  /**
   * Stack overflow
   */
  StackOverflow = 10,
} WasmResult;

/**
 * WASM value type
 */
typedef enum WasmValueType {
  /**
   * 32-bit integer
   */
  I32 = 0,
  /**
   * 64-bit integer
   */
  I64 = 1,
  /**
   * 32-bit float
   */
  F32 = 2,
  /**
   * 64-bit float
   */
  F64 = 3,
  /**
   * Reference (funcref or externref)
   */
  Ref = 4,
  /**
   * Trinity trit value (-1, 0, +1)
   */
  Trit = 5,
} WasmValueType;

/**
 * WASM value data (union)
 */
typedef union WasmValueData {
  /**
   * i32 value
   */
  int32_t i32_val;
  /**
   * i64 value
   */
  int64_t i64_val;
  /**
   * f32 value
   */
  float f32_val;
  /**
   * f64 value
   */
  double f64_val;
  /**
   * Trit value (-1, 0, +1)
   */
  int8_t trit_val;
} WasmValueData;

/**
 * WASM value (tagged union)
 */
typedef struct WasmValue {
  /**
   * Value type tag
   */
  enum WasmValueType value_type;
  /**
   * Value data
   */
  union WasmValueData data;
} WasmValue;

/**
 * WASM module handle
 */
typedef struct WasmModule {
  /**
   * Module name (null-terminated)
   */
  char name[MAX_MODULE_NAME_LEN];
  /**
   * Module state
   */
  enum ModuleState state;
  /**
   * Binary size in bytes
   */
  uintptr_t binary_size;
  /**
   * Number of imported functions
   */
  uintptr_t import_count;
  /**
   * Number of exported functions
   */
  uintptr_t export_count;
  /**
   * Initial memory pages
   */
  uintptr_t initial_pages;
  /**
   * Maximum memory pages
   */
  uintptr_t max_pages;
  /**
   * Whether the module uses Trinity extensions
   */
  bool trinity_extensions;
} WasmModule;

/**
 * WASM instance configuration
 */
typedef struct InstanceConfig {
  /**
   * Initial memory pages
   */
  uintptr_t initial_pages;
  /**
   * Maximum memory pages
   */
  uintptr_t max_pages;
  /**
   * Stack size in bytes
   */
  uintptr_t stack_size;
  /**
   * Execution timeout in ms (0 = no timeout)
   */
  long timeout_ms;
  /**
   * Whether to enable Trinity opcodes
   */
  bool trinity_opcodes;
  /**
   * Fuel for metering (0 = unlimited)
   */
  unsigned long fuel;
  /**
   * Whether to enable debug info
   */
  bool debug;
} InstanceConfig;

/**
 * WASM memory view
 */
typedef struct WasmMemoryView {
  /**
   * Base pointer
   */
  uint8_t *data;
  /**
   * Current size in bytes
   */
  uintptr_t size;
  /**
   * Number of pages
   */
  uintptr_t pages;
  /**
   * Maximum pages
   */
  uintptr_t max_pages;
} WasmMemoryView;

/**
 * Function signature
 */
typedef struct FuncSignature {
  /**
   * Parameter types
   */
  enum WasmValueType params[MAX_FUNC_ARGS];
  /**
   * Number of parameters
   */
  uintptr_t param_count;
  /**
   * Return types
   */
  enum WasmValueType results[MAX_FUNC_ARGS];
  /**
   * Number of return values
   */
  uintptr_t result_count;
} FuncSignature;

/**
 * WASM execution context
 */
typedef struct ExecutionContext {
  /**
   * Module being executed
   */
  struct WasmModule module;
  /**
   * Memory view
   */
  struct WasmMemoryView memory;
  /**
   * Call depth
   */
  uintptr_t call_depth;
  /**
   * Fuel consumed
   */
  unsigned long fuel_consumed;
  /**
   * Execution result
   */
  enum WasmResult result;
  /**
   * Whether a trap occurred
   */
  bool trapped;
} ExecutionContext;

/**
 * Create an i32 WASM value
 */
struct WasmValue trios_wasm_value_i32(int32_t val);

/**
 * Create an i64 WASM value
 */
struct WasmValue trios_wasm_value_i64(int64_t val);

/**
 * Create an f32 WASM value
 */
struct WasmValue trios_wasm_value_f32(float val);

/**
 * Create an f64 WASM value
 */
struct WasmValue trios_wasm_value_f64(double val);

/**
 * Create a Trit WASM value
 */
struct WasmValue trios_wasm_value_trit(int8_t val);

/**
 * Read i32 from a WASM value (returns 0 if type mismatch)
 */
int32_t trios_wasm_value_as_i32(struct WasmValue val);

/**
 * Read f64 from a WASM value (returns 0.0 if type mismatch)
 */
double trios_wasm_value_as_f64(struct WasmValue val);

/**
 * Read trit from a WASM value (returns 0 if type mismatch)
 */
int8_t trios_wasm_value_as_trit(struct WasmValue val);

/**
 * Create a new WASM module descriptor
 */
struct WasmModule trios_wasm_module_new(const char *name,
                                        uintptr_t binary_size,
                                        uintptr_t initial_pages,
                                        uintptr_t max_pages);

/**
 * Check if a module uses Trinity extensions
 */
bool trios_wasm_module_has_trinity_ext(const struct WasmModule *module);

/**
 * Create default instance configuration
 */
struct InstanceConfig trios_wasm_instance_config_default(void);

/**
 * Create Trinity-optimized instance configuration
 */
struct InstanceConfig trios_wasm_instance_config_trinity(void);

/**
 * Create a memory view
 */
struct WasmMemoryView trios_wasm_memory_view(uint8_t *data, uintptr_t size, uintptr_t max_pages);

/**
 * Calculate byte offset for a given page and offset
 */
uintptr_t trios_wasm_memory_offset(uintptr_t page, uintptr_t offset);

/**
 * Calculate number of pages needed for a given byte size
 */
uintptr_t trios_wasm_pages_needed(uintptr_t byte_size);

/**
 * Create an empty function signature
 */
struct FuncSignature trios_wasm_func_signature_new(void);

/**
 * Add a parameter to a function signature
 */
bool trios_wasm_func_signature_add_param(struct FuncSignature *sig, enum WasmValueType param_type);

/**
 * Add a result type to a function signature
 */
bool trios_wasm_func_signature_add_result(struct FuncSignature *sig,
                                          enum WasmValueType result_type);

/**
 * Create an execution context
 */
struct ExecutionContext trios_wasm_exec_context_new(struct WasmModule module,
                                                    struct WasmMemoryView memory);

/**
 * Check if execution context is in a valid state
 */
bool trios_wasm_exec_context_ok(const struct ExecutionContext *ctx);

/**
 * Get Trinity custom opcode for a given operation index
 */
uint32_t trios_wasm_trinity_opcode(uint32_t op_index);

/**
 * Check if an opcode is a Trinity extension
 */
bool trios_wasm_is_trinity_opcode(uint32_t opcode);
