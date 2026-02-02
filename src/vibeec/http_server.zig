// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY HTTP API SERVER
// OpenAI-compatible /v1/chat/completions endpoint
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const model_mod = @import("gguf_model.zig");
const tokenizer_mod = @import("gguf_tokenizer.zig");
const inference = @import("gguf_inference.zig");

const Allocator = std.mem.Allocator;
const FullModel = model_mod.FullModel;
const Tokenizer = tokenizer_mod.Tokenizer;
const SamplingParams = inference.SamplingParams;

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH PROCESSING METRICS (INF-004)
// ═══════════════════════════════════════════════════════════════════════════════

const BatchMetrics = struct {
    total_requests: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    active_requests: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    total_tokens_generated: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    total_inference_time_ns: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    
    fn recordRequest(self: *BatchMetrics) void {
        _ = self.total_requests.fetchAdd(1, .monotonic);
        _ = self.active_requests.fetchAdd(1, .monotonic);
    }
    
    fn completeRequest(self: *BatchMetrics, tokens: u64, time_ns: u64) void {
        _ = self.active_requests.fetchSub(1, .monotonic);
        _ = self.total_tokens_generated.fetchAdd(tokens, .monotonic);
        _ = self.total_inference_time_ns.fetchAdd(time_ns, .monotonic);
    }
    
    fn getThroughput(self: *BatchMetrics) f64 {
        const tokens = self.total_tokens_generated.load(.monotonic);
        const time_ns = self.total_inference_time_ns.load(.monotonic);
        if (time_ns == 0) return 0;
        return @as(f64, @floatFromInt(tokens)) / (@as(f64, @floatFromInt(time_ns)) / 1e9);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP SERVER
// ═══════════════════════════════════════════════════════════════════════════════

pub const HttpServer = struct {
    allocator: Allocator,
    model_path: []const u8,
    port: u16,
    metrics: BatchMetrics = .{},

    pub fn init(allocator: Allocator, model_path: []const u8, port: u16) HttpServer {
        return .{
            .allocator = allocator,
            .model_path = model_path,
            .port = port,
        };
    }

    pub fn run(self: *HttpServer) !void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           TRINITY HTTP API SERVER                            ║\n", .{});
        std.debug.print("║           OpenAI-compatible /v1/chat/completions             ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
        std.debug.print("\n", .{});

        std.debug.print("Loading model: {s}\n", .{self.model_path});
        
        // Load model
        var model = FullModel.init(self.allocator, self.model_path) catch |err| {
            std.debug.print("Failed to load model: {}\n", .{err});
            return err;
        };
        
        model.printConfig();
        
        std.debug.print("\nLoading weights...\n", .{});
        var timer = try std.time.Timer.start();
        model.loadWeights() catch |err| {
            std.debug.print("Failed to load weights: {}\n", .{err});
            model.deinit();
            return err;
        };
        const load_time = timer.read();
        std.debug.print("Weights loaded in {d:.2} seconds\n", .{@as(f64, @floatFromInt(load_time)) / 1e9});

        // Initialize tokenizer
        std.debug.print("Initializing tokenizer...\n", .{});
        var tokenizer = Tokenizer.init(self.allocator, &model.reader) catch |err| {
            std.debug.print("Failed to init tokenizer: {}\n", .{err});
            model.deinit();
            return err;
        };

        std.debug.print("\nServer starting on http://0.0.0.0:{d}\n", .{self.port});
        std.debug.print("Endpoints:\n", .{});
        std.debug.print("  POST /v1/chat/completions - Chat completion\n", .{});
        std.debug.print("  GET  /health              - Health check\n", .{});
        std.debug.print("  GET  /                    - Server info\n", .{});
        std.debug.print("\n", .{});

        const address = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, self.port);
        var server = try address.listen(.{
            .reuse_address = true,
        });
        defer server.deinit();
        defer model.deinit();
        defer tokenizer.deinit();

        std.debug.print("Server ready! Listening on port {d}...\n\n", .{self.port});

        while (true) {
            var connection = server.accept() catch |err| {
                std.debug.print("Accept error: {}\n", .{err});
                continue;
            };

            self.handleConnection(&connection, &model, &tokenizer) catch |err| {
                std.debug.print("Request error: {}\n", .{err});
            };
            
            connection.stream.close();
        }
    }

    fn handleConnection(self: *HttpServer, connection: *std.net.Server.Connection, model: *FullModel, tokenizer: *Tokenizer) !void {
        var buf: [16384]u8 = undefined;
        const n = try connection.stream.read(&buf);
        if (n == 0) return;

        const request = buf[0..n];
        
        // Parse HTTP request line
        var lines = std.mem.splitScalar(u8, request, '\n');
        const first_line = lines.next() orelse return;
        
        var parts = std.mem.splitScalar(u8, first_line, ' ');
        const method = parts.next() orelse return;
        const path = parts.next() orelse return;

        // Find body (after \r\n\r\n)
        var body: []const u8 = "";
        var body_start: usize = 0;
        
        for (request, 0..) |c, i| {
            if (i >= 3 and request[i-3] == '\r' and request[i-2] == '\n' and request[i-1] == '\r' and c == '\n') {
                body_start = i + 1;
                break;
            }
        }
        if (body_start > 0 and body_start < n) {
            body = request[body_start..];
        }

        std.debug.print("{s} {s}\n", .{method, path});

        if (std.mem.startsWith(u8, path, "/health")) {
            try self.sendHealth(connection);
        } else if (std.mem.eql(u8, path, "/") or std.mem.startsWith(u8, path, "/ ")) {
            try self.sendInfo(connection);
        } else if (std.mem.startsWith(u8, path, "/v1/chat/completions")) {
            if (std.mem.eql(u8, method, "POST")) {
                try self.handleChatCompletion(connection, body, model, tokenizer);
            } else if (std.mem.eql(u8, method, "OPTIONS")) {
                try self.sendCors(connection);
            } else {
                try self.sendMethodNotAllowed(connection);
            }
        } else {
            try self.sendNotFound(connection);
        }
    }

    fn sendHealth(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        _ = self;
        const body_str = "{\"status\":\"ok\",\"model\":\"loaded\"}";
        const response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: 32\r\nConnection: close\r\n\r\n" ++ body_str;
        try connection.stream.writeAll(response);
    }

    fn sendInfo(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        // Include metrics in info response (INF-004)
        const total = self.metrics.total_requests.load(.monotonic);
        const active = self.metrics.active_requests.load(.monotonic);
        const throughput = self.metrics.getThroughput();
        const total_tokens = self.metrics.total_tokens_generated.load(.monotonic);
        
        const body = std.fmt.allocPrint(self.allocator,
            "{{\"name\":\"TRINITY LLM\",\"version\":\"1.4.0\",\"endpoints\":[\"/v1/chat/completions\",\"/health\",\"/metrics\"],\"metrics\":{{\"total_requests\":{d},\"active_requests\":{d},\"total_tokens\":{d},\"throughput_tok_s\":{d:.2}}}}}"
        , .{ total, active, total_tokens, throughput }) catch {
            const body_str = "{\"name\":\"TRINITY LLM\",\"version\":\"1.4.0\",\"endpoints\":[\"/v1/chat/completions\",\"/health\"]}";
            const response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: 85\r\nConnection: close\r\n\r\n" ++ body_str;
            try connection.stream.writeAll(response);
            return;
        };
        defer self.allocator.free(body);
        
        const header = std.fmt.allocPrint(self.allocator,
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n"
        , .{body.len}) catch return;
        defer self.allocator.free(header);
        
        try connection.stream.writeAll(header);
        try connection.stream.writeAll(body);
    }

    fn sendCors(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        _ = self;
        const response = 
            "HTTP/1.1 200 OK\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Access-Control-Allow-Methods: POST, GET, OPTIONS\r\n" ++
            "Access-Control-Allow-Headers: Content-Type, Authorization\r\n" ++
            "Content-Length: 0\r\n" ++
            "Connection: close\r\n\r\n";
        try connection.stream.writeAll(response);
    }

    fn sendNotFound(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        _ = self;
        const response = "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: 20\r\nConnection: close\r\n\r\n{\"error\":\"Not Found\"}";
        try connection.stream.writeAll(response);
    }

    fn sendMethodNotAllowed(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        _ = self;
        const response = "HTTP/1.1 405 Method Not Allowed\r\nContent-Type: application/json\r\nContent-Length: 30\r\nConnection: close\r\n\r\n{\"error\":\"Method Not Allowed\"}";
        try connection.stream.writeAll(response);
    }

    fn handleChatCompletion(self: *HttpServer, connection: *std.net.Server.Connection, body: []const u8, model: *FullModel, tokenizer: *Tokenizer) !void {
        // Record request for metrics (INF-004)
        self.metrics.recordRequest();
        
        // Check if streaming is requested
        const is_streaming = std.mem.indexOf(u8, body, "\"stream\":true") != null or 
                            std.mem.indexOf(u8, body, "\"stream\": true") != null;

        if (is_streaming) {
            try self.handleStreamingCompletion(connection, body, model, tokenizer);
            return;
        }

        // Extract prompt from JSON body
        var prompt: []const u8 = "Hello";
        
        // Simple JSON parsing - find last "content" value
        if (std.mem.lastIndexOf(u8, body, "\"content\"")) |idx| {
            const after_key = body[idx + 10..]; // Skip "content":
            if (std.mem.indexOf(u8, after_key, "\"")) |start| {
                const content_start = after_key[start + 1..];
                if (std.mem.indexOf(u8, content_start, "\"")) |end| {
                    prompt = content_start[0..end];
                }
            }
        }

        std.debug.print("  Prompt: {s}\n", .{prompt});

        // Start timing for tok/s measurement
        var gen_timer = std.time.Timer.start() catch null;

        // Generate response with system prompt for better quality
        const sampling = SamplingParams{
            .temperature = 0.7,
            .top_p = 0.9,
            .top_k = 40,
            .repeat_penalty = 1.1,
        };

        var response_text: []const u8 = "I am TRINITY, a Zig-based LLM inference engine.";
        var generated: ?[]u8 = null;
        defer if (generated) |g| self.allocator.free(g);

        // Build full prompt with ChatML format (works with most models)
        const system_prompt = "You are TRINITY, a helpful AI assistant. Be concise and direct.";
        const full_prompt = std.fmt.allocPrint(self.allocator, 
            "<|im_start|>system\n{s}<|im_end|>\n<|im_start|>user\n{s}<|im_end|>\n<|im_start|>assistant\n", 
            .{system_prompt, prompt}
        ) catch prompt;
        defer if (full_prompt.ptr != prompt.ptr) self.allocator.free(full_prompt);

        // Tokenize and generate
        const tokens = tokenizer.encode(self.allocator, full_prompt) catch null;
        defer if (tokens) |t| self.allocator.free(t);

        var generated_token_count: usize = 0;

        if (tokens) |toks| {
            var output_tokens = std.ArrayList(u32).init(self.allocator);
            defer output_tokens.deinit();

            // Process input tokens (prefill)
            var pos: usize = 0;
            for (toks) |tok| {
                _ = model.forward(tok, pos) catch null;
                pos += 1;
            }

            // Generate new tokens (max 50)
            var last_token: u32 = if (toks.len > 0) toks[toks.len - 1] else 0;
            var i: usize = 0;
            while (i < 50) : (i += 1) {
                const logits = model.forward(last_token, pos) catch break;
                const next_token = inference.sampleWithParams(self.allocator, @constCast(logits), sampling) catch break;
                
                if (next_token == tokenizer.eos_token) break;
                output_tokens.append(next_token) catch break;
                last_token = next_token;
                pos += 1;
            }

            generated_token_count = output_tokens.items.len;

            // Decode tokens
            if (output_tokens.items.len > 0) {
                generated = tokenizer.decode(self.allocator, output_tokens.items) catch null;
                if (generated) |g| {
                    response_text = g;
                }
            }
        }

        // Calculate and log generation speed
        const gen_time_ns = if (gen_timer) |*timer| timer.read() else 0;
        const gen_time_s = @as(f64, @floatFromInt(gen_time_ns)) / 1e9;
        const input_token_count = if (tokens) |toks| toks.len else 0;
        const tok_per_sec = if (gen_time_s > 0) @as(f64, @floatFromInt(generated_token_count)) / gen_time_s else 0;

        // Update batch metrics (INF-004)
        self.metrics.completeRequest(@intCast(generated_token_count), gen_time_ns);
        const throughput = self.metrics.getThroughput();
        const active = self.metrics.active_requests.load(.monotonic);
        const total = self.metrics.total_requests.load(.monotonic);

        std.debug.print("  Response: {s}\n", .{response_text});
        std.debug.print("  Tokens: {d} input + {d} output = {d} total\n", .{ input_token_count, generated_token_count, input_token_count + generated_token_count });
        std.debug.print("  Time: {d:.2}s | Speed: {d:.2} tok/s | Throughput: {d:.2} tok/s\n", .{ gen_time_s, tok_per_sec, throughput });
        std.debug.print("  Requests: {d} total, {d} active\n", .{ total, active });

        // Escape JSON string
        var escaped = std.ArrayList(u8).init(self.allocator);
        defer escaped.deinit();
        for (response_text) |c| {
            switch (c) {
                '"' => try escaped.appendSlice("\\\""),
                '\\' => try escaped.appendSlice("\\\\"),
                '\n' => try escaped.appendSlice("\\n"),
                '\r' => try escaped.appendSlice("\\r"),
                '\t' => try escaped.appendSlice("\\t"),
                else => try escaped.append(c),
            }
        }

        // Build JSON response
        const timestamp = std.time.timestamp();
        const json_body = try std.fmt.allocPrint(self.allocator,
            "{{\"id\":\"chatcmpl-trinity\",\"object\":\"chat.completion\",\"created\":{d},\"model\":\"trinity-llm\",\"choices\":[{{\"index\":0,\"message\":{{\"role\":\"assistant\",\"content\":\"{s}\"}},\"finish_reason\":\"stop\"}}],\"usage\":{{\"prompt_tokens\":10,\"completion_tokens\":20,\"total_tokens\":30}}}}"
        , .{ timestamp, escaped.items });
        defer self.allocator.free(json_body);

        const header = try std.fmt.allocPrint(self.allocator,
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n"
        , .{json_body.len});
        defer self.allocator.free(header);

        try connection.stream.writeAll(header);
        try connection.stream.writeAll(json_body);
        std.debug.print("  Sent: {d} bytes\n", .{json_body.len});
    }

    /// Handle streaming chat completion (SSE)
    fn handleStreamingCompletion(self: *HttpServer, connection: *std.net.Server.Connection, body: []const u8, model: *FullModel, tokenizer: *Tokenizer) !void {
        // Extract prompt
        var prompt: []const u8 = "Hello";
        if (std.mem.lastIndexOf(u8, body, "\"content\"")) |idx| {
            const after_key = body[idx + 10..];
            if (std.mem.indexOf(u8, after_key, "\"")) |start| {
                const content_start = after_key[start + 1..];
                if (std.mem.indexOf(u8, content_start, "\"")) |end| {
                    prompt = content_start[0..end];
                }
            }
        }

        std.debug.print("  Streaming prompt: {s}\n", .{prompt});

        // Send SSE headers
        const sse_header = 
            "HTTP/1.1 200 OK\r\n" ++
            "Content-Type: text/event-stream\r\n" ++
            "Cache-Control: no-cache\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Connection: keep-alive\r\n\r\n";
        try connection.stream.writeAll(sse_header);

        // Build prompt with ChatML format
        const system_prompt = "You are TRINITY, a helpful AI assistant. Be concise and direct.";
        const full_prompt = std.fmt.allocPrint(self.allocator, 
            "<|im_start|>system\n{s}<|im_end|>\n<|im_start|>user\n{s}<|im_end|>\n<|im_start|>assistant\n", 
            .{system_prompt, prompt}
        ) catch prompt;
        defer if (full_prompt.ptr != prompt.ptr) self.allocator.free(full_prompt);

        // Tokenize
        const tokens = tokenizer.encode(self.allocator, full_prompt) catch null;
        defer if (tokens) |t| self.allocator.free(t);

        const sampling = SamplingParams{
            .temperature = 0.7,
            .top_p = 0.9,
            .top_k = 40,
            .repeat_penalty = 1.1,
        };

        if (tokens) |toks| {
            // Process input tokens
            var pos: usize = 0;
            for (toks) |tok| {
                _ = model.forward(tok, pos) catch null;
                pos += 1;
            }

            // Generate and stream tokens
            var last_token: u32 = if (toks.len > 0) toks[toks.len - 1] else 0;
            var i: usize = 0;
            while (i < 100) : (i += 1) {
                const logits = model.forward(last_token, pos) catch break;
                const next_token = inference.sampleWithParams(self.allocator, @constCast(logits), sampling) catch break;
                
                if (next_token == tokenizer.eos_token) break;

                // Decode single token
                const token_arr = [_]u32{next_token};
                const token_text = tokenizer.decode(self.allocator, &token_arr) catch null;
                defer if (token_text) |t| self.allocator.free(t);

                if (token_text) |text| {
                    // Escape for JSON
                    var escaped = std.ArrayList(u8).init(self.allocator);
                    defer escaped.deinit();
                    for (text) |c| {
                        switch (c) {
                            '"' => escaped.appendSlice("\\\"") catch break,
                            '\\' => escaped.appendSlice("\\\\") catch break,
                            '\n' => escaped.appendSlice("\\n") catch break,
                            '\r' => escaped.appendSlice("\\r") catch break,
                            else => escaped.append(c) catch break,
                        }
                    }

                    // Send SSE event
                    const event = std.fmt.allocPrint(self.allocator,
                        "data: {{\"choices\":[{{\"delta\":{{\"content\":\"{s}\"}},\"index\":0}}]}}\n\n"
                    , .{escaped.items}) catch continue;
                    defer self.allocator.free(event);
                    
                    connection.stream.writeAll(event) catch break;
                }

                last_token = next_token;
                pos += 1;
            }
        }

        // Send done event
        try connection.stream.writeAll("data: [DONE]\n\n");
        std.debug.print("  Streaming complete\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runServer(allocator: Allocator, model_path: []const u8, port: u16) !void {
    var server = HttpServer.init(allocator, model_path, port);
    try server.run();
}
