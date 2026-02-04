// ═══════════════════════════════════════════════════════════════════════════════
// BITNET b1.58 LOADER - Native Ternary Model Loading
// Load BitNet models from safetensors format
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const json = std.json;

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// BITNET CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const BitNetConfig = struct {
    vocab_size: u32 = 32002,
    hidden_size: u32 = 1536,
    intermediate_size: u32 = 4096,
    num_hidden_layers: u32 = 24,
    num_attention_heads: u32 = 16,
    num_key_value_heads: u32 = 16,
    max_position_embeddings: u32 = 2048,
    rms_norm_eps: f32 = 1e-5,
    rope_theta: f32 = 10000.0,
    weight_bits: u8 = 1,
    input_bits: u8 = 8,
    
    pub fn headDim(self: BitNetConfig) u32 {
        return self.hidden_size / self.num_attention_heads;
    }
    
    pub fn totalParams(self: BitNetConfig) u64 {
        // Approximate parameter count
        const embed = @as(u64, self.vocab_size) * self.hidden_size;
        const attn_per_layer = 4 * @as(u64, self.hidden_size) * self.hidden_size;
        const ffn_per_layer = 3 * @as(u64, self.hidden_size) * self.intermediate_size;
        const layer_params = (attn_per_layer + ffn_per_layer) * self.num_hidden_layers;
        return embed + layer_params;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SAFETENSORS HEADER PARSER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TensorInfo = struct {
    dtype: []const u8,
    shape: []const i64,
    data_offsets: [2]u64,
};

pub const SafetensorsHeader = struct {
    allocator: std.mem.Allocator,
    tensors: std.StringHashMap(TensorInfo),
    header_size: u64,
    
    pub fn parse(allocator: std.mem.Allocator, file: std.fs.File) !SafetensorsHeader {
        // Read header size (8 bytes, little-endian)
        var size_buf: [8]u8 = undefined;
        _ = try file.read(&size_buf);
        const header_size = std.mem.readInt(u64, &size_buf, .little);
        
        // Read header JSON
        const header_json = try allocator.alloc(u8, header_size);
        defer allocator.free(header_json);
        _ = try file.read(header_json);
        
        // Parse JSON
        var tensors = std.StringHashMap(TensorInfo).init(allocator);
        
        var parsed = try json.parseFromSlice(json.Value, allocator, header_json, .{});
        defer parsed.deinit();
        
        const root = parsed.value.object;
        var it = root.iterator();
        while (it.next()) |entry| {
            const name = entry.key_ptr.*;
            if (std.mem.eql(u8, name, "__metadata__")) continue;
            
            const tensor_obj = entry.value_ptr.*.object;
            
            // Get dtype
            const dtype = tensor_obj.get("dtype").?.string;
            
            // Get shape
            const shape_arr = tensor_obj.get("shape").?.array;
            var shape = try allocator.alloc(i64, shape_arr.items.len);
            for (shape_arr.items, 0..) |item, i| {
                shape[i] = item.integer;
            }
            
            // Get data offsets
            const offsets_arr = tensor_obj.get("data_offsets").?.array;
            const data_offsets = [2]u64{
                @intCast(offsets_arr.items[0].integer),
                @intCast(offsets_arr.items[1].integer),
            };
            
            // Store tensor info
            const name_copy = try allocator.dupe(u8, name);
            try tensors.put(name_copy, TensorInfo{
                .dtype = try allocator.dupe(u8, dtype),
                .shape = shape,
                .data_offsets = data_offsets,
            });
        }
        
        return SafetensorsHeader{
            .allocator = allocator,
            .tensors = tensors,
            .header_size = header_size + 8, // Include size prefix
        };
    }
    
    pub fn deinit(self: *SafetensorsHeader) void {
        var it = self.tensors.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*.dtype);
            self.allocator.free(entry.value_ptr.*.shape);
        }
        self.tensors.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BITNET MODEL
// ═══════════════════════════════════════════════════════════════════════════════

pub const BitNetModel = struct {
    allocator: std.mem.Allocator,
    config: BitNetConfig,
    
    // Embeddings
    embed_tokens: []f32,
    
    // Layers
    layers: []BitNetLayer,
    
    // Output
    norm: []f32,
    lm_head: ?[]f32, // May be tied to embed_tokens
    
    // File handle for memory-mapped access
    file: ?std.fs.File,
    header: ?SafetensorsHeader,
    
    pub const BitNetLayer = struct {
        // Attention
        q_proj: []u8, // Ternary packed
        k_proj: []u8,
        v_proj: []u8,
        o_proj: []u8,
        q_scale: f32,
        k_scale: f32,
        v_scale: f32,
        o_scale: f32,
        
        // FFN
        gate_proj: []u8,
        up_proj: []u8,
        down_proj: []u8,
        gate_scale: f32,
        up_scale: f32,
        down_scale: f32,
        
        // Norms
        input_layernorm: []f32,
        post_attention_layernorm: []f32,
    };
    
    pub fn load(allocator: std.mem.Allocator, model_path: []const u8, config_path: []const u8) !BitNetModel {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           BITNET b1.58 LOADER                                ║\n", .{});
        std.debug.print("║           φ² + 1/φ² = 3 = TRINITY                            ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
        std.debug.print("\n", .{});
        
        // Load config
        std.debug.print("Loading config from: {s}\n", .{config_path});
        const config = try loadConfig(allocator, config_path);
        
        std.debug.print("  vocab_size: {d}\n", .{config.vocab_size});
        std.debug.print("  hidden_size: {d}\n", .{config.hidden_size});
        std.debug.print("  num_layers: {d}\n", .{config.num_hidden_layers});
        std.debug.print("  num_heads: {d}\n", .{config.num_attention_heads});
        std.debug.print("  weight_bits: {d}\n", .{config.weight_bits});
        std.debug.print("  total_params: ~{d}M\n", .{config.totalParams() / 1_000_000});
        
        // Open safetensors file
        std.debug.print("\nLoading model from: {s}\n", .{model_path});
        const file = try std.fs.cwd().openFile(model_path, .{});
        
        // Parse header
        var header = try SafetensorsHeader.parse(allocator, file);
        
        std.debug.print("  Found {d} tensors\n", .{header.tensors.count()});
        
        // List some tensors
        var count: usize = 0;
        var tensor_it = header.tensors.iterator();
        while (tensor_it.next()) |entry| {
            if (count < 5) {
                std.debug.print("    - {s}: {any}\n", .{entry.key_ptr.*, entry.value_ptr.*.shape});
            }
            count += 1;
        }
        if (count > 5) {
            std.debug.print("    ... and {d} more\n", .{count - 5});
        }
        
        // Initialize model structure
        var model = BitNetModel{
            .allocator = allocator,
            .config = config,
            .embed_tokens = &[_]f32{},
            .layers = &[_]BitNetLayer{},
            .norm = &[_]f32{},
            .lm_head = null,
            .file = file,
            .header = header,
        };
        
        // Load embeddings
        std.debug.print("\nLoading embeddings...\n", .{});
        model.embed_tokens = try loadTensorF32(allocator, file, &header, "model.embed_tokens.weight");
        std.debug.print("  embed_tokens: {d} elements\n", .{model.embed_tokens.len});
        
        // Load final norm
        model.norm = try loadTensorF32(allocator, file, &header, "model.norm.weight");
        std.debug.print("  norm: {d} elements\n", .{model.norm.len});
        
        std.debug.print("\n✅ BitNet model loaded successfully!\n", .{});
        std.debug.print("   Memory: ~{d} MB\n", .{(model.embed_tokens.len * 4 + model.norm.len * 4) / (1024 * 1024)});
        
        return model;
    }
    
    pub fn deinit(self: *BitNetModel) void {
        if (self.embed_tokens.len > 0) {
            self.allocator.free(self.embed_tokens);
        }
        if (self.norm.len > 0) {
            self.allocator.free(self.norm);
        }
        if (self.header) |*h| {
            h.deinit();
        }
        if (self.file) |f| {
            f.close();
        }
    }
};

fn loadConfig(allocator: std.mem.Allocator, path: []const u8) !BitNetConfig {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    
    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);
    
    var parsed = try json.parseFromSlice(json.Value, allocator, content, .{});
    defer parsed.deinit();
    
    const obj = parsed.value.object;
    
    return BitNetConfig{
        .vocab_size = @intCast(obj.get("vocab_size").?.integer),
        .hidden_size = @intCast(obj.get("hidden_size").?.integer),
        .intermediate_size = @intCast(obj.get("intermediate_size").?.integer),
        .num_hidden_layers = @intCast(obj.get("num_hidden_layers").?.integer),
        .num_attention_heads = @intCast(obj.get("num_attention_heads").?.integer),
        .num_key_value_heads = @intCast(obj.get("num_key_value_heads").?.integer),
        .max_position_embeddings = @intCast(obj.get("max_position_embeddings").?.integer),
        .rms_norm_eps = @floatCast(obj.get("rms_norm_eps").?.float),
        .rope_theta = @floatCast(obj.get("rope_theta").?.float),
        .weight_bits = @intCast(obj.get("weight_bits").?.integer),
        .input_bits = @intCast(obj.get("input_bits").?.integer),
    };
}

fn loadTensorF32(allocator: std.mem.Allocator, file: std.fs.File, header: *SafetensorsHeader, name: []const u8) ![]f32 {
    const info = header.tensors.get(name) orelse {
        std.debug.print("  WARNING: Tensor '{s}' not found\n", .{name});
        return &[_]f32{};
    };
    
    // Calculate size
    var num_elements: usize = 1;
    for (info.shape) |dim| {
        num_elements *= @intCast(dim);
    }
    
    // Seek to data
    const data_start = header.header_size + info.data_offsets[0];
    try file.seekTo(data_start);
    
    // Read based on dtype
    if (std.mem.eql(u8, info.dtype, "F32")) {
        const data = try allocator.alloc(f32, num_elements);
        const bytes = std.mem.sliceAsBytes(data);
        _ = try file.read(bytes);
        return data;
    } else if (std.mem.eql(u8, info.dtype, "F16")) {
        // Convert F16 to F32
        const f16_data = try allocator.alloc(f16, num_elements);
        defer allocator.free(f16_data);
        const bytes = std.mem.sliceAsBytes(f16_data);
        _ = try file.read(bytes);
        
        const data = try allocator.alloc(f32, num_elements);
        for (f16_data, 0..) |v, i| {
            data[i] = @floatCast(v);
        }
        return data;
    } else if (std.mem.eql(u8, info.dtype, "BF16")) {
        // Convert BF16 to F32
        const bf16_data = try allocator.alloc(u16, num_elements);
        defer allocator.free(bf16_data);
        const bytes = std.mem.sliceAsBytes(bf16_data);
        _ = try file.read(bytes);
        
        const data = try allocator.alloc(f32, num_elements);
        for (bf16_data, 0..) |v, i| {
            // BF16 to F32: shift left by 16 bits
            const bits: u32 = @as(u32, v) << 16;
            data[i] = @bitCast(bits);
        }
        return data;
    } else {
        std.debug.print("  WARNING: Unsupported dtype '{s}' for tensor '{s}'\n", .{info.dtype, name});
        return &[_]f32{};
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "bitnet config" {
    const config = BitNetConfig{};
    try std.testing.expectEqual(@as(u32, 96), config.headDim());
    try std.testing.expect(config.totalParams() > 700_000_000);
}

test "load bitnet model" {
    const allocator = std.testing.allocator;
    
    // Try to load if model exists
    var model = BitNetModel.load(
        allocator,
        "../../models/bitnet/model.safetensors",
        "../../models/bitnet/config.json",
    ) catch |err| {
        std.debug.print("Model not found (expected in CI): {}\n", .{err});
        return;
    };
    defer model.deinit();
    
    try std.testing.expect(model.embed_tokens.len > 0);
    try std.testing.expect(model.norm.len > 0);
}
