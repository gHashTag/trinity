#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Maximum key length
 */
#define MAX_KEY_LEN 256

/**
 * Maximum value length
 */
#define MAX_VALUE_LEN 4096

/**
 * Maximum number of entries in a scan result
 */
#define MAX_SCAN_RESULTS 256

/**
 * Maximum number of transactions
 */
#define MAX_TRANSACTIONS 64

/**
 * Maximum cache entries
 */
#define MAX_CACHE_ENTRIES 1024

/**
 * Storage backend type
 */
typedef enum StorageBackend {
  /**
   * In-memory hash map
   */
  Memory = 0,
  /**
   * File-based (LMDB-like)
   */
  File = 1,
  /**
   * Distributed (network)
   */
  Distributed = 2,
  /**
   * Hybrid (memory + file)
   */
  Hybrid = 3,
} StorageBackend;

/**
 * Store operation result
 */
typedef enum StoreResult {
  /**
   * Operation succeeded
   */
  Ok = 0,
  /**
   * Key not found
   */
  NotFound = 1,
  /**
   * Key already exists
   */
  AlreadyExists = 2,
  /**
   * Out of space
   */
  OutOfSpace = 3,
  /**
   * Invalid argument
   */
  InvalidArg = 4,
  /**
   * I/O error
   */
  IoError = 5,
  /**
   * Transaction conflict
   */
  Conflict = 6,
  /**
   * Internal error
   */
  InternalError = 7,
} StoreResult;

/**
 * Transaction state
 */
typedef enum TransactionState {
  /**
   * Transaction is active
   */
  Active = 0,
  /**
   * Transaction has been committed
   */
  Committed = 1,
  /**
   * Transaction has been rolled back
   */
  RolledBack = 2,
  /**
   * Transaction failed
   */
  Failed = 3,
} TransactionState;

/**
 * Store configuration
 */
typedef struct StoreConfig {
  /**
   * Storage backend
   */
  enum StorageBackend backend;
  /**
   * Maximum storage size in bytes
   */
  unsigned long max_size_bytes;
  /**
   * Path for file-based storage (null-terminated)
   */
  char path[512];
  /**
   * Whether to enable compression
   */
  bool compression;
  /**
   * Cache size in entries
   */
  uintptr_t cache_size;
  /**
   * Sync mode (0=async, 1=sync, 2=full sync)
   */
  int sync_mode;
} StoreConfig;

/**
 * Store key
 */
typedef struct StoreKey {
  /**
   * Key data (null-terminated)
   */
  char data[MAX_KEY_LEN];
  /**
   * Key length (excluding null terminator)
   */
  uintptr_t len;
} StoreKey;

/**
 * Store value
 */
typedef struct StoreValue {
  /**
   * Value data pointer
   */
  uint8_t *data;
  /**
   * Value length
   */
  uintptr_t len;
  /**
   * Capacity
   */
  uintptr_t capacity;
} StoreValue;

/**
 * Key-value entry
 */
typedef struct StoreEntry {
  /**
   * Key
   */
  struct StoreKey key;
  /**
   * Value
   */
  struct StoreValue value;
  /**
   * Version number (for MVCC)
   */
  unsigned long version;
  /**
   * Timestamp (epoch seconds)
   */
  long timestamp;
  /**
   * Whether the entry is deleted (tombstone)
   */
  bool deleted;
} StoreEntry;

/**
 * Scan result set
 */
typedef struct ScanResult {
  /**
   * Entries found
   */
  struct StoreEntry entries[MAX_SCAN_RESULTS];
  /**
   * Number of entries
   */
  uintptr_t count;
  /**
   * Whether there are more results
   */
  bool has_more;
  /**
   * Cursor for pagination
   */
  unsigned long cursor;
} ScanResult;

/**
 * Scan range specification
 */
typedef struct ScanRange {
  /**
   * Start key (inclusive, null-terminated)
   */
  char start_key[MAX_KEY_LEN];
  /**
   * End key (exclusive, null-terminated)
   */
  char end_key[MAX_KEY_LEN];
  /**
   * Whether start is inclusive
   */
  bool start_inclusive;
  /**
   * Whether end is inclusive
   */
  bool end_inclusive;
  /**
   * Maximum number of results
   */
  uintptr_t limit;
  /**
   * Reverse scan
   */
  bool reverse;
} ScanRange;

/**
 * Transaction handle
 */
typedef struct Transaction {
  /**
   * Transaction ID
   */
  unsigned long id;
  /**
   * Transaction state
   */
  enum TransactionState state;
  /**
   * Start timestamp
   */
  long start_ts;
  /**
   * Number of operations
   */
  uintptr_t op_count;
  /**
   * Whether the transaction is read-only
   */
  bool read_only;
} Transaction;

/**
 * Store statistics
 */
typedef struct StoreStats {
  /**
   * Total number of keys
   */
  unsigned long key_count;
  /**
   * Total data size in bytes
   */
  unsigned long total_size;
  /**
   * Number of reads
   */
  unsigned long reads;
  /**
   * Number of writes
   */
  unsigned long writes;
  /**
   * Number of deletes
   */
  unsigned long deletes;
  /**
   * Cache hit rate [0.0, 1.0]
   */
  double cache_hit_rate;
  /**
   * Average read latency in microseconds
   */
  double avg_read_latency_us;
  /**
   * Average write latency in microseconds
   */
  double avg_write_latency_us;
} StoreStats;

/**
 * Create default store configuration (in-memory)
 */
struct StoreConfig trios_store_config_default(void);

/**
 * Create file-based store configuration
 */
struct StoreConfig trios_store_config_file(const char *path, unsigned long max_size_mb);

/**
 * Create a store key from a C string
 */
struct StoreKey trios_store_key_new(const char *key_str);

/**
 * Create a store value from raw bytes
 */
struct StoreValue trios_store_value_new(const uint8_t *data, uintptr_t len);

/**
 * Create an empty scan result
 */
struct ScanResult trios_store_scan_result_new(void);

/**
 * Create a scan range between two keys
 */
struct ScanRange trios_store_scan_range(const char *start_key,
                                        const char *end_key,
                                        uintptr_t limit);

/**
 * Create a new transaction
 */
struct Transaction trios_store_transaction_new(unsigned long id, bool read_only);

/**
 * Check if a transaction is usable (active state)
 */
bool trios_store_transaction_active(const struct Transaction *tx);

/**
 * Mark transaction as committed
 */
enum StoreResult trios_store_transaction_commit(struct Transaction *tx);

/**
 * Mark transaction as rolled back
 */
enum StoreResult trios_store_transaction_rollback(struct Transaction *tx);

/**
 * Create empty store statistics
 */
struct StoreStats trios_store_stats_new(void);

/**
 * Compute cache hit rate from hits and misses
 */
double trios_store_cache_hit_rate(unsigned long hits, unsigned long misses);

/**
 * Estimate memory usage for a given number of entries
 */
unsigned long trios_store_estimate_memory(unsigned long entry_count,
                                          uintptr_t avg_key_len,
                                          uintptr_t avg_value_len);
