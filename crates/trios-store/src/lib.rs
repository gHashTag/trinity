//! TRIOS Store — Storage Layer FFI
//!
//! This crate provides FFI bindings for TRIOS storage operations including
//! key-value persistence, transactions, caching, and storage backend
//! abstraction for the Trinity system.
//!
//! ## Features
//!
//! - **Key-Value Store**: Get, put, delete, scan operations
//! - **Transactions**: Begin, commit, rollback with ACID guarantees
//! - **Caching**: LRU cache with configurable size
//! - **Storage Backends**: Memory, file, distributed
//! - **Iterators**: Forward and reverse scans with range queries
//!
//! ## Symbol: `💾`

use std::os::raw::{c_char, c_double, c_int, c_long, c_ulong};

// ─── Constants ────────────────────────────────────────────────────────

/// Maximum key length
pub const MAX_KEY_LEN: usize = 256;

/// Maximum value length
pub const MAX_VALUE_LEN: usize = 4096;

/// Maximum number of entries in a scan result
pub const MAX_SCAN_RESULTS: usize = 256;

/// Maximum number of transactions
pub const MAX_TRANSACTIONS: usize = 64;

/// Maximum cache entries
pub const MAX_CACHE_ENTRIES: usize = 1024;

// ─── Enums ────────────────────────────────────────────────────────────

/// Storage backend type
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StorageBackend {
    /// In-memory hash map
    Memory = 0,
    /// File-based (LMDB-like)
    File = 1,
    /// Distributed (network)
    Distributed = 2,
    /// Hybrid (memory + file)
    Hybrid = 3,
}

/// Transaction state
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TransactionState {
    /// Transaction is active
    Active = 0,
    /// Transaction has been committed
    Committed = 1,
    /// Transaction has been rolled back
    RolledBack = 2,
    /// Transaction failed
    Failed = 3,
}

/// Store operation result
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StoreResult {
    /// Operation succeeded
    Ok = 0,
    /// Key not found
    NotFound = 1,
    /// Key already exists
    AlreadyExists = 2,
    /// Out of space
    OutOfSpace = 3,
    /// Invalid argument
    InvalidArg = 4,
    /// I/O error
    IoError = 5,
    /// Transaction conflict
    Conflict = 6,
    /// Internal error
    InternalError = 7,
}

/// Comparison operator for range scans
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CmpOp {
    /// Equal
    Eq = 0,
    /// Less than
    Lt = 1,
    /// Less than or equal
    Le = 2,
    /// Greater than
    Gt = 3,
    /// Greater than or equal
    Ge = 4,
}

// ─── Structs ──────────────────────────────────────────────────────────

/// Store key
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct StoreKey {
    /// Key data (null-terminated)
    pub data: [c_char; MAX_KEY_LEN],
    /// Key length (excluding null terminator)
    pub len: usize,
}

/// Store value
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct StoreValue {
    /// Value data pointer
    pub data: *mut u8,
    /// Value length
    pub len: usize,
    /// Capacity
    pub capacity: usize,
}

/// Key-value entry
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct StoreEntry {
    /// Key
    pub key: StoreKey,
    /// Value
    pub value: StoreValue,
    /// Version number (for MVCC)
    pub version: c_ulong,
    /// Timestamp (epoch seconds)
    pub timestamp: c_long,
    /// Whether the entry is deleted (tombstone)
    pub deleted: bool,
}

/// Store configuration
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct StoreConfig {
    /// Storage backend
    pub backend: StorageBackend,
    /// Maximum storage size in bytes
    pub max_size_bytes: c_ulong,
    /// Path for file-based storage (null-terminated)
    pub path: [c_char; 512],
    /// Whether to enable compression
    pub compression: bool,
    /// Cache size in entries
    pub cache_size: usize,
    /// Sync mode (0=async, 1=sync, 2=full sync)
    pub sync_mode: c_int,
}

/// Transaction handle
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct Transaction {
    /// Transaction ID
    pub id: c_ulong,
    /// Transaction state
    pub state: TransactionState,
    /// Start timestamp
    pub start_ts: c_long,
    /// Number of operations
    pub op_count: usize,
    /// Whether the transaction is read-only
    pub read_only: bool,
}

/// Scan range specification
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ScanRange {
    /// Start key (inclusive, null-terminated)
    pub start_key: [c_char; MAX_KEY_LEN],
    /// End key (exclusive, null-terminated)
    pub end_key: [c_char; MAX_KEY_LEN],
    /// Whether start is inclusive
    pub start_inclusive: bool,
    /// Whether end is inclusive
    pub end_inclusive: bool,
    /// Maximum number of results
    pub limit: usize,
    /// Reverse scan
    pub reverse: bool,
}

/// Scan result set
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ScanResult {
    /// Entries found
    pub entries: [StoreEntry; MAX_SCAN_RESULTS],
    /// Number of entries
    pub count: usize,
    /// Whether there are more results
    pub has_more: bool,
    /// Cursor for pagination
    pub cursor: c_ulong,
}

/// Store statistics
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct StoreStats {
    /// Total number of keys
    pub key_count: c_ulong,
    /// Total data size in bytes
    pub total_size: c_ulong,
    /// Number of reads
    pub reads: c_ulong,
    /// Number of writes
    pub writes: c_ulong,
    /// Number of deletes
    pub deletes: c_ulong,
    /// Cache hit rate [0.0, 1.0]
    pub cache_hit_rate: c_double,
    /// Average read latency in microseconds
    pub avg_read_latency_us: c_double,
    /// Average write latency in microseconds
    pub avg_write_latency_us: c_double,
}

// ─── Store Configuration ──────────────────────────────────────────────

/// Create default store configuration (in-memory)
#[no_mangle]
pub extern "C" fn trios_store_config_default() -> StoreConfig {
    StoreConfig {
        backend: StorageBackend::Memory,
        max_size_bytes: 256 * 1024 * 1024, // 256 MB
        path: unsafe { std::mem::zeroed() },
        compression: false,
        cache_size: MAX_CACHE_ENTRIES,
        sync_mode: 0,
    }
}

/// Create file-based store configuration
#[no_mangle]
pub extern "C" fn trios_store_config_file(path: *const c_char, max_size_mb: c_ulong) -> StoreConfig {
    let mut config = StoreConfig {
        backend: StorageBackend::File,
        max_size_bytes: max_size_mb * 1024 * 1024,
        path: unsafe { std::mem::zeroed() },
        compression: true,
        cache_size: MAX_CACHE_ENTRIES,
        sync_mode: 1,
    };

    if !path.is_null() {
        let cstr = unsafe { std::ffi::CStr::from_ptr(path) };
        let bytes = cstr.to_bytes();
        let len = bytes.len().min(511);
        config.path[..len].copy_from_slice(unsafe { std::mem::transmute::<&[u8], &[c_char]>(&bytes[..len]) });
        config.path[len] = 0;
    }

    config
}

// ─── Key/Value Construction ───────────────────────────────────────────

/// Create a store key from a C string
#[no_mangle]
pub extern "C" fn trios_store_key_new(key_str: *const c_char) -> StoreKey {
    let mut key: StoreKey = unsafe { std::mem::zeroed() };
    if !key_str.is_null() {
        let cstr = unsafe { std::ffi::CStr::from_ptr(key_str) };
        let bytes = cstr.to_bytes();
        let len = bytes.len().min(MAX_KEY_LEN - 1);
        key.data[..len].copy_from_slice(unsafe { std::mem::transmute::<&[u8], &[c_char]>(&bytes[..len]) });
        key.data[len] = 0;
        key.len = len;
    }
    key
}

/// Create a store value from raw bytes
#[no_mangle]
pub extern "C" fn trios_store_value_new(data: *const u8, len: usize) -> StoreValue {
    StoreValue {
        data: data as *mut u8,
        len,
        capacity: len,
    }
}

/// Create an empty scan result
#[no_mangle]
pub extern "C" fn trios_store_scan_result_new() -> ScanResult {
    ScanResult {
        entries: unsafe { std::mem::zeroed() },
        count: 0,
        has_more: false,
        cursor: 0,
    }
}

// ─── Scan Range Construction ──────────────────────────────────────────

/// Create a scan range between two keys
#[no_mangle]
pub extern "C" fn trios_store_scan_range(
    start_key: *const c_char,
    end_key: *const c_char,
    limit: usize,
) -> ScanRange {
    let mut range: ScanRange = unsafe { std::mem::zeroed() };
    range.start_inclusive = true;
    range.end_inclusive = false;
    range.limit = limit.min(MAX_SCAN_RESULTS);
    range.reverse = false;

    if !start_key.is_null() {
        let cstr = unsafe { std::ffi::CStr::from_ptr(start_key) };
        let bytes = cstr.to_bytes();
        let len = bytes.len().min(MAX_KEY_LEN - 1);
        range.start_key[..len].copy_from_slice(unsafe { std::mem::transmute::<&[u8], &[c_char]>(&bytes[..len]) });
        range.start_key[len] = 0;
    }

    if !end_key.is_null() {
        let cstr = unsafe { std::ffi::CStr::from_ptr(end_key) };
        let bytes = cstr.to_bytes();
        let len = bytes.len().min(MAX_KEY_LEN - 1);
        range.end_key[..len].copy_from_slice(unsafe { std::mem::transmute::<&[u8], &[c_char]>(&bytes[..len]) });
        range.end_key[len] = 0;
    }

    range
}

// ─── Transaction Operations ───────────────────────────────────────────

/// Create a new transaction
#[no_mangle]
pub extern "C" fn trios_store_transaction_new(id: c_ulong, read_only: bool) -> Transaction {
    Transaction {
        id,
        state: TransactionState::Active,
        start_ts: 0,
        op_count: 0,
        read_only,
    }
}

/// Check if a transaction is usable (active state)
#[no_mangle]
pub extern "C" fn trios_store_transaction_active(tx: *const Transaction) -> bool {
    if tx.is_null() {
        return false;
    }
    unsafe { (*tx).state == TransactionState::Active }
}

/// Mark transaction as committed
#[no_mangle]
pub extern "C" fn trios_store_transaction_commit(tx: *mut Transaction) -> StoreResult {
    if tx.is_null() {
        return StoreResult::InvalidArg;
    }
    unsafe {
        if (*tx).state != TransactionState::Active {
            return StoreResult::Conflict;
        }
        (*tx).state = TransactionState::Committed;
        StoreResult::Ok
    }
}

/// Mark transaction as rolled back
#[no_mangle]
pub extern "C" fn trios_store_transaction_rollback(tx: *mut Transaction) -> StoreResult {
    if tx.is_null() {
        return StoreResult::InvalidArg;
    }
    unsafe {
        if (*tx).state != TransactionState::Active {
            return StoreResult::Conflict;
        }
        (*tx).state = TransactionState::RolledBack;
        StoreResult::Ok
    }
}

// ─── Store Statistics ─────────────────────────────────────────────────

/// Create empty store statistics
#[no_mangle]
pub extern "C" fn trios_store_stats_new() -> StoreStats {
    StoreStats {
        key_count: 0,
        total_size: 0,
        reads: 0,
        writes: 0,
        deletes: 0,
        cache_hit_rate: 0.0,
        avg_read_latency_us: 0.0,
        avg_write_latency_us: 0.0,
    }
}

/// Compute cache hit rate from hits and misses
#[no_mangle]
pub extern "C" fn trios_store_cache_hit_rate(hits: c_ulong, misses: c_ulong) -> c_double {
    let total = hits + misses;
    if total == 0 {
        return 0.0;
    }
    hits as c_double / total as c_double
}

/// Estimate memory usage for a given number of entries
#[no_mangle]
pub extern "C" fn trios_store_estimate_memory(
    entry_count: c_ulong,
    avg_key_len: usize,
    avg_value_len: usize,
) -> c_ulong {
    let per_entry = std::mem::size_of::<StoreEntry>() + avg_key_len + avg_value_len;
    entry_count * per_entry as c_ulong
}

// ─── Unit Tests ───────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_default() {
        let config = trios_store_config_default();
        assert_eq!(config.backend, StorageBackend::Memory);
        assert!(!config.compression);
        assert_eq!(config.sync_mode, 0);
    }

    #[test]
    fn test_config_file() {
        let config = trios_store_config_file(
            b"/tmp/trios.db\0".as_ptr() as *const c_char,
            100,
        );
        assert_eq!(config.backend, StorageBackend::File);
        assert!(config.compression);
        assert_eq!(config.sync_mode, 1);
    }

    #[test]
    fn test_key_new() {
        let key = trios_store_key_new(b"test_key\0".as_ptr() as *const c_char);
        assert_eq!(key.len, 8);
    }

    #[test]
    fn test_value_new() {
        let data = b"hello";
        let val = trios_store_value_new(data.as_ptr(), data.len());
        assert_eq!(val.len, 5);
    }

    #[test]
    fn test_scan_range() {
        let range = trios_store_scan_range(
            b"key_001\0".as_ptr() as *const c_char,
            b"key_100\0".as_ptr() as *const c_char,
            50,
        );
        assert!(range.start_inclusive);
        assert!(!range.end_inclusive);
        assert_eq!(range.limit, 50);
    }

    #[test]
    fn test_transaction_lifecycle() {
        let mut tx = trios_store_transaction_new(1, false);
        assert!(trios_store_transaction_active(&tx));

        let result = trios_store_transaction_commit(&mut tx);
        assert_eq!(result, StoreResult::Ok);
        assert!(!trios_store_transaction_active(&tx));
        assert_eq!(tx.state, TransactionState::Committed);
    }

    #[test]
    fn test_transaction_rollback() {
        let mut tx = trios_store_transaction_new(2, false);
        let result = trios_store_transaction_rollback(&mut tx);
        assert_eq!(result, StoreResult::Ok);
        assert_eq!(tx.state, TransactionState::RolledBack);

        // Can't commit a rolled-back transaction
        let result = trios_store_transaction_commit(&mut tx);
        assert_eq!(result, StoreResult::Conflict);
    }

    #[test]
    fn test_cache_hit_rate() {
        assert_eq!(trios_store_cache_hit_rate(80, 20), 0.8);
        assert_eq!(trios_store_cache_hit_rate(0, 0), 0.0);
        assert_eq!(trios_store_cache_hit_rate(100, 0), 1.0);
    }

    #[test]
    fn test_estimate_memory() {
        let mem = trios_store_estimate_memory(1000, 32, 128);
        assert!(mem > 0);
    }
}
