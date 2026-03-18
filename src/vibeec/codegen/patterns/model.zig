// ═══════════════════════════════════════════════════════════════════════════════
// MODEL PATTERNS - Model loading, saving, inference
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("../types.zig");
const builder_mod = @import("../builder.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const Behavior = types.Behavior;

/// Match model operation patterns
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    const when_text = b.when;

    // Pattern: load_model* -> load model from file
    if (std.mem.startsWith(u8, b.name, "load_model") or
        (std.mem.indexOf(u8, when_text, "load") != null and std.mem.indexOf(u8, when_text, "model") != null))
    {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, path: []const u8) !Model {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Load model from file (simple binary format)");
        try builder.writeLine("const file = try std.fs.cwd().openFile(path, .{});");
        try builder.writeLine("defer file.close();");
        try builder.writeLine("");
        try builder.writeLine("// Read header: magic, version, num_layers");
        try builder.writeLine("var header_buf: [12]u8 = undefined;");
        try builder.writeLine("const bytes_read = try file.readAll(&header_buf);");
        try builder.writeLine("if (bytes_read < 12) return error.InvalidHeader;");
        try builder.writeLine("");
        try builder.writeLine("const magic = std.mem.readInt(u32, header_buf[0..4], .little);");
        try builder.writeLine("if (magic != 0x4D4F444C) return error.InvalidMagic; // 'MODL'");
        try builder.writeLine("");
        try builder.writeLine("const version = std.mem.readInt(u32, header_buf[4..8], .little);");
        try builder.writeLine("const num_layers = std.mem.readInt(u32, header_buf[8..12], .little);");
        try builder.writeLine("");
        try builder.writeLine("// Allocate layers array");
        try builder.writeLine("const layers = try allocator.alloc(Layer, num_layers);");
        try builder.writeLine("errdefer allocator.free(layers);");
        try builder.writeLine("");
        try builder.writeLine("// Load each layer");
        try builder.writeLine("for (0..num_layers) |i| {");
        builder.incIndent();
        try builder.writeLine("// Read layer dimensions");
        try builder.writeLine("var dim_buf: [8]u8 = undefined;");
        try builder.writeLine("_ = try file.readAll(&dim_buf);");
        try builder.writeLine("const input_size = std.mem.readInt(u32, dim_buf[0..4], .little);");
        try builder.writeLine("const output_size = std.mem.readInt(u32, dim_buf[4..8], .little);");
        try builder.writeLine("");
        try builder.writeLine("// Read weights");
        try builder.writeLine("const weights_size = input_size * output_size * @sizeOf(f32);");
        try builder.writeLine("const weights = try allocator.alloc(f32, input_size * output_size);");
        try builder.writeLine("_ = try file.readAll(std.mem.sliceAsBytes(weights));");
        try builder.writeLine("");
        try builder.writeLine("// Read biases");
        try builder.writeLine("const biases = try allocator.alloc(f32, output_size);");
        try builder.writeLine("_ = try file.readAll(std.mem.sliceAsBytes(biases));");
        try builder.writeLine("");
        try builder.writeLine("layers[i] = Layer{");
        try builder.writeLine("    .weights = weights,");
        try builder.writeLine("    .biases = biases,");
        try builder.writeLine("    .input_size = input_size,");
        try builder.writeLine("    .output_size = output_size,");
        try builder.writeLine("};");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return Model{");
        try builder.writeLine("    .allocator = allocator,");
        try builder.writeLine("    .layers = layers,");
        try builder.writeLine("    .num_layers = num_layers,");
        try builder.writeLine("    .version = version,");
        try builder.writeLine("};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: save_model* -> save model to file
    if (std.mem.startsWith(u8, b.name, "save_model") or
        (std.mem.indexOf(u8, when_text, "save") != null and std.mem.indexOf(u8, when_text, "model") != null))
    {
        try builder.writeFmt("pub fn {s}(model: *const Model, path: []const u8) !void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Save model to file (simple binary format)");
        try builder.writeLine("const file = try std.fs.cwd().createFile(path, .{});");
        try builder.writeLine("defer file.close();");
        try builder.writeLine("");
        try builder.writeLine("// Write header");
        try builder.writeLine("var header_buf: [12]u8 = undefined;");
        try builder.writeLine("std.mem.writeInt(u32, header_buf[0..4], 0x4D4F444C, .little); // 'MODL'");
        try builder.writeLine("std.mem.writeInt(u32, header_buf[4..8], model.version, .little);");
        try builder.writeLine("std.mem.writeInt(u32, header_buf[8..12], model.num_layers, .little);");
        try builder.writeLine("try file.writeAll(&header_buf);");
        try builder.writeLine("");
        try builder.writeLine("// Write each layer");
        try builder.writeLine("for (model.layers) |layer| {");
        builder.incIndent();
        try builder.writeLine("// Write dimensions");
        try builder.writeLine("var dim_buf: [8]u8 = undefined;");
        try builder.writeLine("std.mem.writeInt(u32, dim_buf[0..4], @intCast(layer.input_size), .little);");
        try builder.writeLine("std.mem.writeInt(u32, dim_buf[4..8], @intCast(layer.output_size), .little);");
        try builder.writeLine("try file.writeAll(&dim_buf);");
        try builder.writeLine("");
        try builder.writeLine("// Write weights");
        try builder.writeLine("try file.writeAll(std.mem.sliceAsBytes(layer.weights));");
        try builder.writeLine("// Write biases");
        try builder.writeLine("try file.writeAll(std.mem.sliceAsBytes(layer.biases));");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: predict* -> run inference on input
    if (std.mem.startsWith(u8, b.name, "predict") or
        (std.mem.indexOf(u8, when_text, "predict") != null or std.mem.indexOf(u8, when_text, "inference") != null))
    {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, model: *const Model, input: []const f32) ![]f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Run single forward pass prediction");
        try builder.writeLine("var activations = try allocator.dupe(f32, input);");
        try builder.writeLine("defer allocator.free(activations);");
        try builder.writeLine("");
        try builder.writeLine("for (model.layers) |layer| {");
        builder.incIndent();
        try builder.writeLine("const next_size = layer.output_size;");
        try builder.writeLine("const next = try allocator.alloc(f32, next_size);");
        try builder.writeLine("");
        try builder.writeLine("// Dense layer: y = activation(Wx + b)");
        try builder.writeLine("for (0..next_size) |j| {");
        builder.incIndent();
        try builder.writeLine("var sum: f32 = layer.biases[j];");
        try builder.writeLine("for (0..activations.len) |i| {");
        builder.incIndent();
        try builder.writeLine("sum += activations[i] * layer.weights[i * next_size + j];");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("// ReLU activation");
        try builder.writeLine("next[j] = if (sum > 0) sum else 0;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("allocator.free(activations);");
        try builder.writeLine("activations = next;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return allocator.dupe(f32, activations);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: sample_token* -> sample token from logits
    if (std.mem.startsWith(u8, b.name, "sample_token") or
        (std.mem.indexOf(u8, when_text, "sample") != null and std.mem.indexOf(u8, when_text, "token") != null))
    {
        try builder.writeFmt("pub fn {s}(logits: []const f32, temperature: f32, top_k: usize, rng: *std.Random.DefaultPrng) usize {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Sample token using temperature + top-k sampling");
        try builder.writeLine("const vocab_size = logits.len;");
        try builder.writeLine("");
        try builder.writeLine("// Apply temperature");
        try builder.writeLine("const scaled = try rng.allocator.allocator.alloc(f32, vocab_size);");
        try builder.writeLine("defer rng.allocator.allocator.free(scaled);");
        try builder.writeLine("for (logits, 0..) |logit, i| {");
        builder.incIndent();
        try builder.writeLine("scaled[i] = logit / temperature;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("// Top-k filtering");
        try builder.writeLine("const k = @min(top_k, vocab_size);");
        try builder.writeLine("");
        try builder.writeLine("// Sort indices by logit value (descending)");
        try builder.writeLine("var indices = try rng.allocator.allocator.alloc(usize, vocab_size);");
        try builder.writeLine("defer rng.allocator.allocator.free(indices);");
        try builder.writeLine("for (0..vocab_size) |i| indices[i] = i;");
        try builder.writeLine("");
        try builder.writeLine("std.sort.sort(usize, indices, logits, struct {");
        try builder.writeLine("    fn lessThan(_: void, a: usize, b_logit: f32) bool {");
        try builder.writeLine("        _ = _;");
        try builder.writeLine("        return scaled[a] > b_logit;");
        try builder.writeLine("    }");
        try builder.writeLine("}.lessThan);");
        try builder.writeLine("");
        try builder.writeLine("// Keep only top-k, set rest to -inf");
        try builder.writeLine("for (k..vocab_size) |i| {");
        builder.incIndent();
        try builder.writeLine("scaled[indices[i]] = -std.math.inf(f32);");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("// Apply softmax to top-k");
        try builder.writeLine("var max_val = scaled[indices[0]];");
        try builder.writeLine("for (scaled) |val| { if (val > max_val) max_val = val; }");
        try builder.writeLine("");
        try builder.writeLine("var exp_sum: f32 = 0;");
        try builder.writeLine("for (scaled) |*val| {");
        builder.incIndent();
        try builder.writeLine("val.* = @exp(val.* - max_val);");
        try builder.writeLine("exp_sum += val.*;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("// Sample from categorical distribution");
        try builder.writeLine("var rand_val = rng.random().float(f32) * exp_sum;");
        try builder.writeLine("for (0..vocab_size) |i| {");
        builder.incIndent();
        try builder.writeLine("rand_val -= scaled[i];");
        try builder.writeLine("if (rand_val <= 0) return i;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return vocab_size - 1; // fallback");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL TYPE DEFINITION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Model = struct {
    allocator: std.mem.Allocator,
    layers: []const Layer,
    num_layers: usize,
    version: u32,

    pub fn deinit(self: *const Model) void {
        for (self.layers) |layer| {
            self.allocator.free(layer.weights);
            self.allocator.free(layer.biases);
        }
        self.allocator.free(self.layers);
    }
};

pub const Layer = struct {
    weights: []const f32,
    biases: []const f32,
    input_size: usize,
    output_size: usize,
};
