// WASM stub for auto_shard — replaces OS-dependent memory detection
// Returns fake 8GB system memory

pub const SystemMemory = struct {
    total_bytes: u64,
    available_bytes: u64,
};

pub fn getSystemMemory() !SystemMemory {
    // In WASM environment, return sensible defaults (8GB total, 4GB available)
    return SystemMemory{
        .total_bytes = 8 * 1024 * 1024 * 1024,
        .available_bytes = 4 * 1024 * 1024 * 1024,
    };
}
