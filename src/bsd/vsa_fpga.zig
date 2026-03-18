// ═══════════════════════════════════════════════════════════════════════════════
// BSD-VSA FPGA PIPELINE — Elliptic Curve Similarity Search via FPGA
// ═══════════════════════════════════════════════════════════════════════════════
//
// Architecture:
//   Cremona DB (5113 curves)
//       ↓ BSDHypervector.encode()
//   1024-dim ternary hypervectors
//       ↓ serializeToUart()
//   UART → FPGA (vsa_uart_phi_top.bit)
//       ↓ SIMILARITY_QUERY command (0x10)
//   FPGA returns top-K similarity scores
//       ↓ Classification
//
// UART Protocol:
//   Command 0x10: SIMILARITY_QUERY
//     Request:  [0xAA][0x10][0x01][k][CRC16]              # Set K value
//               [0xAA][0x10][0x100][query_hv...][CRC16]    # Send query vector
//     Response: [0x10][count][sim1_hi][sim1_lo][idx1_hi][idx1_lo]...
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const cremona = @import("cremona_parser.zig");

// Re-export the proper BSDHypervector from cremona_parser
pub const BSDHypervector = cremona.BSDHypervector;

// ═══════════════════════════════════════════════════════════════════════════════
// UART PROTOCOL — Frame format and CRC
// ═══════════════════════════════════════════════════════════════════════════════

const SYNC_BYTE: u8 = 0xAA;
const CMD_SIMILARITY_QUERY: u8 = 0x10;

pub const UartFrame = struct {
    sync: u8 = SYNC_BYTE,
    cmd: u8,
    len: u8,
    payload: []const u8,
    crc16: u16,

    pub fn serialize(self: *const UartFrame, allocator: std.mem.Allocator) ![]u8 {
        const total_len = 1 + 1 + 1 + self.payload.len + 2;
        const buffer = try allocator.alloc(u8, total_len);
        errdefer allocator.free(buffer);

        var offset: usize = 0;
        buffer[offset] = self.sync;
        offset += 1;
        buffer[offset] = self.cmd;
        offset += 1;
        buffer[offset] = @intCast(self.payload.len);
        offset += 1;
        @memcpy(buffer[offset .. offset + self.payload.len], self.payload);
        offset += self.payload.len;

        // Calculate CRC-16/CCITT
        var crc: u16 = 0xFFFF;
        crc = crc16Ccitt(self.cmd, crc);
        crc = crc16Ccitt(@intCast(self.payload.len), crc);
        for (self.payload) |byte| {
            crc = crc16Ccitt(byte, crc);
        }

        buffer[offset] = @intCast((crc >> 8) & 0xFF);
        offset += 1;
        buffer[offset] = @intCast(crc & 0xFF);

        return buffer;
    }

    pub fn deserialize(buffer: []const u8) !UartFrame {
        if (buffer.len < 4) return error.FrameTooShort;
        if (buffer[0] != SYNC_BYTE) return error.InvalidSync;

        const cmd = buffer[1];
        const len = buffer[2];
        if (buffer.len < 3 + @as(usize, len) + 2) return error.FrameTooShort;

        const payload = buffer[3 .. 3 + len];
        const recv_crc = (@as(u16, buffer[3 + len]) << 8) | buffer[3 + len + 1];

        // Verify CRC
        var calc_crc: u16 = 0xFFFF;
        calc_crc = crc16Ccitt(cmd, calc_crc);
        calc_crc = crc16Ccitt(len, calc_crc);
        for (payload) |byte| {
            calc_crc = crc16Ccitt(byte, calc_crc);
        }

        if (calc_crc != recv_crc) return error.CrcMismatch;

        return .{
            .cmd = cmd,
            .len = len,
            .payload = payload,
            .crc16 = recv_crc,
        };
    }
};

fn crc16Ccitt(byte: u8, crc: u16) u16 {
    var new_crc = crc ^ (@as(u16, byte) << 8);
    var i: u4 = 0;
    while (i < 8) : (i += 1) {
        if (new_crc & 0x8000 != 0) {
            new_crc = (new_crc << 1) ^ 0x1021;
        } else {
            new_crc = new_crc << 1;
        }
    }
    return new_crc;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FPGA SIMILARITY SEARCH — Query FPGA via UART
// ═══════════════════════════════════════════════════════════════════════════════

pub const FPGASimilaritySearch = struct {
    uart_port: []const u8,
    allocator: std.mem.Allocator,
    k_value: u8 = 10, // Default top-K

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, uart_port: []const u8) Self {
        return .{
            .uart_port = uart_port,
            .allocator = allocator,
        };
    }

    /// Set top-K value for similarity search
    pub fn setK(self: *Self, k: u8) void {
        self.k_value = @min(k, 16); // Max K=16
    }

    /// Send SIMILARITY_QUERY command to FPGA
    pub fn sendQuery(self: *const Self, query_hv: *const BSDHypervector) !void {
        _ = self;

        // Serialize hypervector (256 bytes for 1024 trits)
        const serialized = query_hv.serialize();

        // Build frame: [0xAA][0x10][0x100][256 bytes][CRC16]
        const frame = UartFrame{
            .cmd = CMD_SIMILARITY_QUERY,
            .len = 0x100, // 256 bytes
            .payload = &serialized,
            .crc16 = 0, // Will be calculated in serialize()
        };

        // TODO: Implement actual UART send
        // For now, this is a placeholder
        _ = frame;

        std.debug.print("TODO: Send query to FPGA via {s}\n", .{self.uart_port});
    }

    /// Query FPGA for similarity between two hypervectors
    pub fn querySimilarity(
        self: *const Self,
        vec_a: *const BSDHypervector,
        vec_b: *const BSDHypervector,
    ) !f32 {
        _ = self;
        _ = vec_a;
        _ = vec_b;

        // TODO: Implement UART communication
        // 1. Serialize both hypervectors
        // 2. Build SIMILARITY command frame
        // 3. Send via UART
        // 4. Parse response
        // 5. Return similarity score

        return 0.0; // Placeholder
    }

    /// Find top-K most similar curves to query via FPGA
    pub fn findTopK(
        self: *const Self,
        query: *const BSDHypervector,
        database: []const BSDHypervector,
        k: usize,
    ) ![]struct { index: usize, similarity: f32 } {
        _ = self;
        _ = query;
        _ = database;
        _ = k;

        // TODO: Implement top-K search
        // 1. Send query vector to FPGA via UART
        // 2. FPGA streams back top-K results
        // 3. Parse response and return sorted list

        return &[_]struct { index: usize, similarity: f32 }{};
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CREMONA CURVE DATABASE — 5113 curves from Cremona database
// ═══════════════════════════════════════════════════════════════════════════════

pub const CremonaDatabase = struct {
    curves: []CurveEntry,
    hypervectors: []BSDHypervector,
    allocator: std.mem.Allocator,

    const CurveEntry = struct {
        label: []const u8,
        conductor: u64,
        rank: u32,
        hypervector_idx: usize,
    };

    const Self = @This();

    /// Load Cremona database
    pub fn load(allocator: std.mem.Allocator) !Self {
        // TODO: Load from data/ecdata/
        // 5113 curves with conductor ≤ 1000
        // For now, use empty database - actual loading done via cremona.CremonaDatabase

        return Self{
            .curves = &[_]CurveEntry{},
            .hypervectors = &[_]BSDHypervector{},
            .allocator = allocator,
        };
    }

    /// Encode all curves as hypervectors
    pub fn encodeAll(self: *Self) !void {
        _ = self;
        // Encoding is done on-demand via BSDHypervector.encode()
    }

    /// Search for similar curves
    pub fn search(
        self: *const Self,
        query_label: []const u8,
        fpga: *FPGASimilaritySearch,
        k: usize,
    ) ![]struct { label: []const u8, similarity: f32 } {
        _ = self;
        _ = query_label;
        _ = fpga;
        _ = k;

        // TODO: Implement search
        // 1. Find query curve
        // 2. Encode as hypervector
        // 3. Query FPGA for similarities
        // 4. Return top-K matches

        return &[_]struct { label: []const u8, similarity: f32 }{};
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TEST FUNCTION — Verify FPGA vs software similarity
// ═══════════════════════════════════════════════════════════════════════════════

pub fn testFpgaVsSoftware(allocator: std.mem.Allocator) !void {
    // TODO: Implement test comparing:
    // 1. Software VSA similarity (vsa.zig)
    // 2. FPGA VSA similarity (via UART)
    // 3. Verify results match

    _ = allocator;

    std.debug.print("BSD-VSA FPGA Pipeline Test\n", .{});
    std.debug.print("==========================\n", .{});
    std.debug.print("Status: PENDING FPGA CONNECTION\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Connect USB-UART or ESP32 to FPGA:\n", .{});
    std.debug.print("  FPGA L20 (RX) <- USB-UART TX\n", .{});
    std.debug.print("  FPGA K20 (TX) -> USB-UART RX\n", .{});
    std.debug.print("  FPGA GND       <- USB-UART GND\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("φ² + 1/φ² = 3 = TRINITY\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI INTEGRATION — tri math bsd fpga-search <conductor>
// ═══════════════════════════════════════════════════════════════════════════════

pub const FpgaSearchCommand = struct {
    pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
        if (args.len < 1) {
            std.debug.print("Usage: tri math bsd fpga-search <conductor> [k]\n", .{});
            std.debug.print("Example: tri math bsd fpga-search 37 10\n", .{});
            return;
        }

        const conductor_str = args[0];
        const conductor = std.fmt.parseInt(u64, conductor_str, 10) catch {
            std.debug.print("Invalid conductor: {s}\n", .{conductor_str});
            return error.InvalidConductor;
        };

        const k: usize = if (args.len >= 2)
            std.fmt.parseInt(usize, args[1], 10) catch 10
        else
            10;

        std.debug.print("\n╔════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║     BSD-VSA SIMILARITY SEARCH                            ║\n", .{});
        std.debug.print("╚════════════════════════════════════════════════════════════╝\n\n", .{});

        // Load Cremona database
        const db_path = "/Users/playra/trinity-w1/data/ecdata/allbsd/allbsd.00000-09999";
        std.debug.print("Loading database from {s}...\n", .{db_path});
        const db = try cremona.CremonaDatabase.loadFromFile(allocator, db_path);
        defer allocator.free(db.entries);

        const stats = db.stats();
        std.debug.print("Loaded {d} curves\n", .{stats.total_curves});
        std.debug.print("Rank distribution: R0={d}, R1={d}, R2={d}, R3={d}\n", .{
            stats.rank_counts[0], stats.rank_counts[1], stats.rank_counts[2], stats.rank_counts[3],
        });
        std.debug.print("\n", .{});

        // Count matching curves first
        var match_count: usize = 0;
        for (db.entries) |*entry| {
            if (entry.conductor == conductor) match_count += 1;
        }

        if (match_count == 0) {
            std.debug.print("No curves found with conductor {d}\n", .{conductor});
            return;
        }

        // Allocate array for matching indices
        const query_indices = try allocator.alloc(usize, match_count);
        defer allocator.free(query_indices);

        var idx: usize = 0;
        for (db.entries, 0..) |*entry, i| {
            if (entry.conductor == conductor) {
                query_indices[idx] = i;
                idx += 1;
            }
        }

        std.debug.print("Found {d} curves with conductor {d}:\n\n", .{ match_count, conductor });

        // Encode each query curve and find top-K similar curves
        for (query_indices, 0..) |query_idx, qi| {
            const query_entry = &db.entries[query_idx];
            const label = try query_entry.label(allocator);
            defer allocator.free(label);

            std.debug.print("Query {d}: {s} (rank {d})\n", .{ qi + 1, label, query_entry.rank });

            // Encode query curve
            const query_hv = BSDHypervector.encode(query_entry);

            // Allocate results array
            const ResultType = struct {
                label: []const u8,
                similarity: f32,
                entry_idx: usize,
            };
            const results = try allocator.alloc(ResultType, db.entries.len);

            for (db.entries, 0..) |*entry, ei| {
                const hv = BSDHypervector.encode(entry);
                const sim = hv.similarity(&query_hv);

                const result_label = try entry.label(allocator);
                results[ei] = .{
                    .label = result_label,
                    .similarity = sim,
                    .entry_idx = ei,
                };
            }

            // Sort by similarity (descending)
            const SortContext = struct {
                fn lessThan(_: void, a: ResultType, b: ResultType) bool {
                    return a.similarity > b.similarity;
                }
            };
            std.sort.heap(ResultType, results, {}, SortContext.lessThan);

            // Print top-K results (excluding query itself)
            std.debug.print("\nTop {d} most similar curves:\n", .{@min(k, results.len)});
            std.debug.print("{s:12} {s:6} {s:12} {s:10}\n", .{ "Label", "Rank", "Conductor", "Similarity" });
            std.debug.print("{s:12} {s:6} {s:12} {s:10}\n", .{ "-" ** 12, "-" ** 6, "-" ** 12, "-" ** 10 });

            var count: usize = 0;
            for (results) |r| {
                if (count >= k) break;
                const entry = &db.entries[r.entry_idx];
                // Skip exact matches (same curve)
                if (entry.conductor == query_entry.conductor and
                    std.mem.eql(u8, entry.iso_class, query_entry.iso_class) and
                    entry.curve_number == query_entry.curve_number)
                {
                    continue;
                }

                std.debug.print("{s:12} {d:6} {d:12} {d:.6}\n", .{
                    r.label, entry.rank, entry.conductor, r.similarity,
                });
                count += 1;
            }

            // Free result labels
            for (results) |r| {
                allocator.free(r.label);
            }
            allocator.free(results);

            if (qi < query_indices.len - 1) {
                std.debug.print("\n", .{});
            }
        }

        std.debug.print("\n✅ Search complete!\n", .{});
        std.debug.print("\nφ² + 1/φ² = 3 = TRINITY\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TEST MAIN — Quick test of BSD-VSA similarity search
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test similarity search for conductor 37
    const args = &[_][]const u8{ "37", "5" };
    try FpgaSearchCommand.run(allocator, args);
}

// ═══════════════════════════════════════════════════════════════════════════════
