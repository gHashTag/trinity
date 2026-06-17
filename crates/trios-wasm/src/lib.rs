//! TRIOS WASM — WebAssembly Runtime FFI
//!
//! This crate provides FFI bindings for TRIOS WebAssembly operations including
//! module loading, instantiation, execution, memory management, and
//! import/export bridging for the Trinity system.
//!
//! ## Features
//!
//! - **Module Loading**: Parse and validate WASM binaries
//! - **Instantiation**: Create instances with configured imports
//! - **Execution**: Call exported functions with typed arguments
//! - **Memory Management**: Linear memory access, grow/shrink
//! - **Import/Export**: Bridge between host and WASM modules
//! - **Trinity Extensions**: Custom opcodes for ternary/VSA operations
//!
//! ## Symbol: `⚡`

use std::os::raw::{c_char, c_long, c_ulong};

// ─── Constants ────────────────────────────────────────────────────────

/// WASM page size (64 KB)
pub const WASM_PAGE_SIZE: usize = 65536;

/// Maximum number of imported functions
pub const MAX_IMPORTS: usize = 64;

/// Maximum number of exported functions
pub const MAX_EXPORTS: usize = 64;

/// Maximum number of memory pages
pub const MAX_MEMORY_PAGES: usize = 256;

/// Maximum function name length
pub const MAX_FUNC_NAME_LEN: usize = 128;

/// Maximum module name length
pub const MAX_MODULE_NAME_LEN: usize = 128;

/// Maximum number of function arguments
pub const MAX_FUNC_ARGS: usize = 16;

/// Trinity custom opcode base
pub const TRINITY_OPCODE_BASE: u32 = 0xF000;

// ─── Enums ────────────────────────────────────────────────────────────

/// WASM value type
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WasmValueType {
    /// 32-bit integer
    I32 = 0,
    /// 64-bit integer
    I64 = 1,
    /// 32-bit float
    F32 = 2,
    /// 64-bit float
    F64 = 3,
    /// Reference (funcref or externref)
    Ref = 4,
    /// Trinity trit value (-1, 0, +1)
    Trit = 5,
}

/// WASM execution result
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WasmResult {
    /// Execution succeeded
    Ok = 0,
    /// Module compilation failed
    CompileError = 1,
    /// Link error (missing imports)
    LinkError = 2,
    /// Runtime trap
    Trap = 3,
    /// Out of memory
    OutOfMemory = 4,
    /// Invalid argument
    InvalidArg = 5,
    /// Module not found
    ModuleNotFound = 6,
    /// Function not found
    FuncNotFound = 7,
    /// Memory access violation
    MemoryAccessViolation = 8,
    /// Timeout
    Timeout = 9,
    /// Stack overflow
    StackOverflow = 10,
}

/// Module state
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ModuleState {
    /// Module loaded but not compiled
    Loaded = 0,
    /// Module compiled and ready
    Compiled = 1,
    /// Module instantiated and running
    Instantiated = 2,
    /// Module errored
    Errored = 3,
    /// Module unloaded
    Unloaded = 4,
}

/// Import/Export kind
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ExternalKind {
    /// Function
    Function = 0,
    /// Table
    Table = 1,
    /// Memory
    Memory = 2,
    /// Global
    Global = 3,
}

// ─── Structs ──────────────────────────────────────────────────────────

/// WASM value (tagged union)
#[repr(C)]
#[derive(Clone, Copy)]
pub struct WasmValue {
    /// Value type tag
    pub value_type: WasmValueType,
    /// Value data
    pub data: WasmValueData,
}

impl std::fmt::Debug for WasmValue {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("WasmValue")
            .field("value_type", &self.value_type)
            .finish()
    }
}

/// WASM value data (union)
#[repr(C)]
#[derive(Clone, Copy)]
pub union WasmValueData {
    /// i32 value
    pub i32_val: i32,
    /// i64 value
    pub i64_val: i64,
    /// f32 value
    pub f32_val: f32,
    /// f64 value
    pub f64_val: f64,
    /// Trit value (-1, 0, +1)
    pub trit_val: i8,
}

/// Function signature
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct FuncSignature {
    /// Parameter types
    pub params: [WasmValueType; MAX_FUNC_ARGS],
    /// Number of parameters
    pub param_count: usize,
    /// Return types
    pub results: [WasmValueType; MAX_FUNC_ARGS],
    /// Number of return values
    pub result_count: usize,
}

/// Import descriptor
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ImportDescriptor {
    /// Module name (null-terminated)
    pub module_name: [c_char; MAX_MODULE_NAME_LEN],
    /// Function name (null-terminated)
    pub func_name: [c_char; MAX_FUNC_NAME_LEN],
    /// External kind
    pub kind: ExternalKind,
    /// Expected signature (for functions)
    pub signature: FuncSignature,
}

/// Export descriptor
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ExportDescriptor {
    /// Function name (null-terminated)
    pub name: [c_char; MAX_FUNC_NAME_LEN],
    /// External kind
    pub kind: ExternalKind,
    /// Function signature (for functions)
    pub signature: FuncSignature,
    /// Index in the module
    pub index: usize,
}

/// WASM module handle
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct WasmModule {
    /// Module name (null-terminated)
    pub name: [c_char; MAX_MODULE_NAME_LEN],
    /// Module state
    pub state: ModuleState,
    /// Binary size in bytes
    pub binary_size: usize,
    /// Number of imported functions
    pub import_count: usize,
    /// Number of exported functions
    pub export_count: usize,
    /// Initial memory pages
    pub initial_pages: usize,
    /// Maximum memory pages
    pub max_pages: usize,
    /// Whether the module uses Trinity extensions
    pub trinity_extensions: bool,
}

/// WASM instance configuration
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct InstanceConfig {
    /// Initial memory pages
    pub initial_pages: usize,
    /// Maximum memory pages
    pub max_pages: usize,
    /// Stack size in bytes
    pub stack_size: usize,
    /// Execution timeout in ms (0 = no timeout)
    pub timeout_ms: c_long,
    /// Whether to enable Trinity opcodes
    pub trinity_opcodes: bool,
    /// Fuel for metering (0 = unlimited)
    pub fuel: c_ulong,
    /// Whether to enable debug info
    pub debug: bool,
}

/// WASM memory view
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct WasmMemoryView {
    /// Base pointer
    pub data: *mut u8,
    /// Current size in bytes
    pub size: usize,
    /// Number of pages
    pub pages: usize,
    /// Maximum pages
    pub max_pages: usize,
}

/// WASM execution context
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ExecutionContext {
    /// Module being executed
    pub module: WasmModule,
    /// Memory view
    pub memory: WasmMemoryView,
    /// Call depth
    pub call_depth: usize,
    /// Fuel consumed
    pub fuel_consumed: c_ulong,
    /// Execution result
    pub result: WasmResult,
    /// Whether a trap occurred
    pub trapped: bool,
}

// ─── Value Construction ───────────────────────────────────────────────

/// Create an i32 WASM value
#[no_mangle]
pub extern "C" fn trios_wasm_value_i32(val: i32) -> WasmValue {
    WasmValue {
        value_type: WasmValueType::I32,
        data: WasmValueData { i32_val: val },
    }
}

/// Create an i64 WASM value
#[no_mangle]
pub extern "C" fn trios_wasm_value_i64(val: i64) -> WasmValue {
    WasmValue {
        value_type: WasmValueType::I64,
        data: WasmValueData { i64_val: val },
    }
}

/// Create an f32 WASM value
#[no_mangle]
pub extern "C" fn trios_wasm_value_f32(val: f32) -> WasmValue {
    WasmValue {
        value_type: WasmValueType::F32,
        data: WasmValueData { f32_val: val },
    }
}

/// Create an f64 WASM value
#[no_mangle]
pub extern "C" fn trios_wasm_value_f64(val: f64) -> WasmValue {
    WasmValue {
        value_type: WasmValueType::F64,
        data: WasmValueData { f64_val: val },
    }
}

/// Create a Trit WASM value
#[no_mangle]
pub extern "C" fn trios_wasm_value_trit(val: i8) -> WasmValue {
    WasmValue {
        value_type: WasmValueType::Trit,
        data: WasmValueData { trit_val: val.clamp(-1, 1) },
    }
}

/// Read i32 from a WASM value (returns 0 if type mismatch)
#[no_mangle]
pub extern "C" fn trios_wasm_value_as_i32(val: WasmValue) -> i32 {
    if val.value_type == WasmValueType::I32 {
        unsafe { val.data.i32_val }
    } else {
        0
    }
}

/// Read f64 from a WASM value (returns 0.0 if type mismatch)
#[no_mangle]
pub extern "C" fn trios_wasm_value_as_f64(val: WasmValue) -> f64 {
    if val.value_type == WasmValueType::F64 {
        unsafe { val.data.f64_val }
    } else {
        0.0
    }
}

/// Read trit from a WASM value (returns 0 if type mismatch)
#[no_mangle]
pub extern "C" fn trios_wasm_value_as_trit(val: WasmValue) -> i8 {
    if val.value_type == WasmValueType::Trit {
        unsafe { val.data.trit_val }
    } else {
        0
    }
}

// ─── Module Construction ──────────────────────────────────────────────

/// Create a new WASM module descriptor
#[no_mangle]
pub extern "C" fn trios_wasm_module_new(
    name: *const c_char,
    binary_size: usize,
    initial_pages: usize,
    max_pages: usize,
) -> WasmModule {
    let mut module: WasmModule = unsafe { std::mem::zeroed() };
    module.state = ModuleState::Loaded;
    module.binary_size = binary_size;
    module.initial_pages = initial_pages;
    module.max_pages = max_pages.min(MAX_MEMORY_PAGES);
    module.trinity_extensions = false;

    if !name.is_null() {
        let cstr = unsafe { std::ffi::CStr::from_ptr(name) };
        let bytes = cstr.to_bytes();
        let len = bytes.len().min(MAX_MODULE_NAME_LEN - 1);
        module.name[..len].copy_from_slice(unsafe { std::mem::transmute::<&[u8], &[c_char]>(&bytes[..len]) });
        module.name[len] = 0;
    }

    module
}

/// Check if a module uses Trinity extensions
#[no_mangle]
pub extern "C" fn trios_wasm_module_has_trinity_ext(module: *const WasmModule) -> bool {
    if module.is_null() {
        return false;
    }
    unsafe { (*module).trinity_extensions }
}

// ─── Instance Configuration ───────────────────────────────────────────

/// Create default instance configuration
#[no_mangle]
pub extern "C" fn trios_wasm_instance_config_default() -> InstanceConfig {
    InstanceConfig {
        initial_pages: 1,
        max_pages: MAX_MEMORY_PAGES,
        stack_size: 64 * 1024, // 64 KB
        timeout_ms: 0,
        trinity_opcodes: false,
        fuel: 0,
        debug: false,
    }
}

/// Create Trinity-optimized instance configuration
#[no_mangle]
pub extern "C" fn trios_wasm_instance_config_trinity() -> InstanceConfig {
    InstanceConfig {
        initial_pages: 4,
        max_pages: MAX_MEMORY_PAGES,
        stack_size: 128 * 1024, // 128 KB
        timeout_ms: 30_000,
        trinity_opcodes: true,
        fuel: 1_000_000,
        debug: false,
    }
}

// ─── Memory Operations ────────────────────────────────────────────────

/// Create a memory view
#[no_mangle]
pub extern "C" fn trios_wasm_memory_view(
    data: *mut u8,
    size: usize,
    max_pages: usize,
) -> WasmMemoryView {
    WasmMemoryView {
        data,
        size,
        pages: size / WASM_PAGE_SIZE,
        max_pages,
    }
}

/// Calculate byte offset for a given page and offset
#[no_mangle]
pub extern "C" fn trios_wasm_memory_offset(page: usize, offset: usize) -> usize {
    page * WASM_PAGE_SIZE + offset
}

/// Calculate number of pages needed for a given byte size
#[no_mangle]
pub extern "C" fn trios_wasm_pages_needed(byte_size: usize) -> usize {
    (byte_size + WASM_PAGE_SIZE - 1) / WASM_PAGE_SIZE
}

// ─── Function Signature ──────────────────────────────────────────────

/// Create an empty function signature
#[no_mangle]
pub extern "C" fn trios_wasm_func_signature_new() -> FuncSignature {
    FuncSignature {
        params: [WasmValueType::I32; MAX_FUNC_ARGS],
        param_count: 0,
        results: [WasmValueType::I32; MAX_FUNC_ARGS],
        result_count: 0,
    }
}

/// Add a parameter to a function signature
#[no_mangle]
pub extern "C" fn trios_wasm_func_signature_add_param(
    sig: *mut FuncSignature,
    param_type: WasmValueType,
) -> bool {
    if sig.is_null() {
        return false;
    }
    unsafe {
        if (*sig).param_count >= MAX_FUNC_ARGS {
            return false;
        }
        (*sig).params[(*sig).param_count] = param_type;
        (*sig).param_count += 1;
        true
    }
}

/// Add a result type to a function signature
#[no_mangle]
pub extern "C" fn trios_wasm_func_signature_add_result(
    sig: *mut FuncSignature,
    result_type: WasmValueType,
) -> bool {
    if sig.is_null() {
        return false;
    }
    unsafe {
        if (*sig).result_count >= MAX_FUNC_ARGS {
            return false;
        }
        (*sig).results[(*sig).result_count] = result_type;
        (*sig).result_count += 1;
        true
    }
}

// ─── Execution Context ────────────────────────────────────────────────

/// Create an execution context
#[no_mangle]
pub extern "C" fn trios_wasm_exec_context_new(
    module: WasmModule,
    memory: WasmMemoryView,
) -> ExecutionContext {
    ExecutionContext {
        module,
        memory,
        call_depth: 0,
        fuel_consumed: 0,
        result: WasmResult::Ok,
        trapped: false,
    }
}

/// Check if execution context is in a valid state
#[no_mangle]
pub extern "C" fn trios_wasm_exec_context_ok(ctx: *const ExecutionContext) -> bool {
    if ctx.is_null() {
        return false;
    }
    unsafe { !(*ctx).trapped && (*ctx).result == WasmResult::Ok }
}

/// Get Trinity custom opcode for a given operation index
#[no_mangle]
pub extern "C" fn trios_wasm_trinity_opcode(op_index: u32) -> u32 {
    TRINITY_OPCODE_BASE + op_index
}

/// Check if an opcode is a Trinity extension
#[no_mangle]
pub extern "C" fn trios_wasm_is_trinity_opcode(opcode: u32) -> bool {
    opcode >= TRINITY_OPCODE_BASE && opcode < TRINITY_OPCODE_BASE + 256
}

// ─── Unit Tests ───────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_value_i32() {
        let val = trios_wasm_value_i32(42);
        assert_eq!(val.value_type, WasmValueType::I32);
        assert_eq!(trios_wasm_value_as_i32(val), 42);
    }

    #[test]
    fn test_value_f64() {
        let val = trios_wasm_value_f64(3.14);
        assert_eq!(val.value_type, WasmValueType::F64);
        assert!((trios_wasm_value_as_f64(val) - 3.14).abs() < 1e-10);
    }

    #[test]
    fn test_value_trit() {
        let val = trios_wasm_value_trit(1);
        assert_eq!(val.value_type, WasmValueType::Trit);
        assert_eq!(trios_wasm_value_as_trit(val), 1);

        let clamped = trios_wasm_value_trit(5);
        assert_eq!(trios_wasm_value_as_trit(clamped), 1);
    }

    #[test]
    fn test_value_type_mismatch() {
        let val = trios_wasm_value_i32(42);
        assert_eq!(trios_wasm_value_as_f64(val), 0.0);
        assert_eq!(trios_wasm_value_as_trit(val), 0);
    }

    #[test]
    fn test_module_new() {
        let module = trios_wasm_module_new(
            b"test_module\0".as_ptr() as *const c_char,
            1024,
            1,
            16,
        );
        assert_eq!(module.state, ModuleState::Loaded);
        assert_eq!(module.binary_size, 1024);
        assert_eq!(module.initial_pages, 1);
        assert_eq!(module.max_pages, 16);
    }

    #[test]
    fn test_instance_config_default() {
        let config = trios_wasm_instance_config_default();
        assert_eq!(config.initial_pages, 1);
        assert!(!config.trinity_opcodes);
        assert!(!config.debug);
    }

    #[test]
    fn test_instance_config_trinity() {
        let config = trios_wasm_instance_config_trinity();
        assert_eq!(config.initial_pages, 4);
        assert!(config.trinity_opcodes);
        assert_eq!(config.fuel, 1_000_000);
    }

    #[test]
    fn test_memory_offset() {
        assert_eq!(trios_wasm_memory_offset(0, 0), 0);
        assert_eq!(trios_wasm_memory_offset(1, 0), WASM_PAGE_SIZE);
        assert_eq!(trios_wasm_memory_offset(2, 100), 2 * WASM_PAGE_SIZE + 100);
    }

    #[test]
    fn test_pages_needed() {
        assert_eq!(trios_wasm_pages_needed(0), 0);
        assert_eq!(trios_wasm_pages_needed(1), 1);
        assert_eq!(trios_wasm_pages_needed(WASM_PAGE_SIZE), 1);
        assert_eq!(trios_wasm_pages_needed(WASM_PAGE_SIZE + 1), 2);
    }

    #[test]
    fn test_func_signature() {
        let mut sig = trios_wasm_func_signature_new();
        assert_eq!(sig.param_count, 0);

        assert!(trios_wasm_func_signature_add_param(&mut sig, WasmValueType::I32));
        assert!(trios_wasm_func_signature_add_param(&mut sig, WasmValueType::F64));
        assert!(trios_wasm_func_signature_add_result(&mut sig, WasmValueType::I32));
        assert_eq!(sig.param_count, 2);
        assert_eq!(sig.result_count, 1);
    }

    #[test]
    fn test_trinity_opcodes() {
        let op = trios_wasm_trinity_opcode(0);
        assert_eq!(op, TRINITY_OPCODE_BASE);
        assert!(trios_wasm_is_trinity_opcode(TRINITY_OPCODE_BASE));
        assert!(trios_wasm_is_trinity_opcode(TRINITY_OPCODE_BASE + 100));
        assert!(!trios_wasm_is_trinity_opcode(0));
        assert!(!trios_wasm_is_trinity_opcode(0xEF00));
    }

    #[test]
    fn test_exec_context() {
        let module = trios_wasm_module_new(
            b"test\0".as_ptr() as *const c_char,
            512,
            1,
            4,
        );
        let memory = trios_wasm_memory_view(std::ptr::null_mut(), WASM_PAGE_SIZE, 4);
        let ctx = trios_wasm_exec_context_new(module, memory);
        assert!(trios_wasm_exec_context_ok(&ctx));
        assert_eq!(ctx.call_depth, 0);
    }
}
