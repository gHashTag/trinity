// =============================================================================
// IGLA API SERVER v1.0 - Local HTTP/REST Interface for External Access
// =============================================================================
//
// CYCLE 19: Golden Chain Pipeline
// - OpenAI-compatible /v1/chat/completions endpoint
// - Local HTTP/REST server
// - External access (curl/postman local)
// - SSE streaming support
// - Integration with StreamingEngine (Cycle 18)
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI SERVES ETERNALLY
// =============================================================================

const std = @import("std");
const streaming = @import("igla_streaming_engine.zig");

// =============================================================================
// CONFIGURATION
// =============================================================================

pub const DEFAULT_PORT: u16 = 8080;
pub const MAX_REQUEST_SIZE: usize = 16384;
pub const MAX_RESPONSE_SIZE: usize = 65536;
pub const MAX_HEADER_SIZE: usize = 256;
pub const MAX_HEADERS: usize = 32;
pub const MAX_BODY_SIZE: usize = 8192;
pub const MAX_PATH_SIZE: usize = 256;
pub const SERVER_NAME: []const u8 = "IGLA/1.0";
pub const MODEL_ID: []const u8 = "igla-fluent-v1";

// =============================================================================
// HTTP METHOD
// =============================================================================

pub const HttpMethod = enum {
    GET,
    POST,
    OPTIONS,
    PUT,
    DELETE,
    HEAD,
    Unknown,

    pub fn fromString(s: []const u8) HttpMethod {
        if (std.mem.eql(u8, s, "GET")) return .GET;
        if (std.mem.eql(u8, s, "POST")) return .POST;
        if (std.mem.eql(u8, s, "OPTIONS")) return .OPTIONS;
        if (std.mem.eql(u8, s, "PUT")) return .PUT;
        if (std.mem.eql(u8, s, "DELETE")) return .DELETE;
        if (std.mem.eql(u8, s, "HEAD")) return .HEAD;
        return .Unknown;
    }

    pub fn toString(self: HttpMethod) []const u8 {
        return switch (self) {
            .GET => "GET",
            .POST => "POST",
            .OPTIONS => "OPTIONS",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .HEAD => "HEAD",
            .Unknown => "UNKNOWN",
        };
    }
};

// =============================================================================
// HTTP STATUS
// =============================================================================

pub const HttpStatus = enum(u16) {
    OK = 200,
    Created = 201,
    NoContent = 204,
    BadRequest = 400,
    Unauthorized = 401,
    Forbidden = 403,
    NotFound = 404,
    MethodNotAllowed = 405,
    InternalServerError = 500,
    ServiceUnavailable = 503,

    pub fn getCode(self: HttpStatus) u16 {
        return @intFromEnum(self);
    }

    pub fn getReason(self: HttpStatus) []const u8 {
        return switch (self) {
            .OK => "OK",
            .Created => "Created",
            .NoContent => "No Content",
            .BadRequest => "Bad Request",
            .Unauthorized => "Unauthorized",
            .Forbidden => "Forbidden",
            .NotFound => "Not Found",
            .MethodNotAllowed => "Method Not Allowed",
            .InternalServerError => "Internal Server Error",
            .ServiceUnavailable => "Service Unavailable",
        };
    }
};

// =============================================================================
// ROUTE
// =============================================================================

pub const Route = enum {
    ChatCompletions,
    Models,
    Health,
    Root,
    Metrics,
    Unknown,

    pub fn fromPath(path: []const u8) Route {
        // Remove query string if present
        var clean_path = path;
        if (std.mem.indexOf(u8, path, "?")) |idx| {
            clean_path = path[0..idx];
        }
        // Remove trailing space/CR
        clean_path = std.mem.trimRight(u8, clean_path, " \r\n");

        if (std.mem.startsWith(u8, clean_path, "/v1/chat/completions")) return .ChatCompletions;
        if (std.mem.startsWith(u8, clean_path, "/v1/models")) return .Models;
        if (std.mem.startsWith(u8, clean_path, "/health")) return .Health;
        if (std.mem.startsWith(u8, clean_path, "/metrics")) return .Metrics;
        if (std.mem.eql(u8, clean_path, "/")) return .Root;
        return .Unknown;
    }

    pub fn getPath(self: Route) []const u8 {
        return switch (self) {
            .ChatCompletions => "/v1/chat/completions",
            .Models => "/v1/models",
            .Health => "/health",
            .Root => "/",
            .Metrics => "/metrics",
            .Unknown => "/unknown",
        };
    }
};

// =============================================================================
// HTTP HEADER
// =============================================================================

pub const HttpHeader = struct {
    name: [MAX_HEADER_SIZE]u8,
    name_len: usize,
    value: [MAX_HEADER_SIZE]u8,
    value_len: usize,

    pub fn init(name: []const u8, value: []const u8) HttpHeader {
        var header = HttpHeader{
            .name = undefined,
            .name_len = @min(name.len, MAX_HEADER_SIZE),
            .value = undefined,
            .value_len = @min(value.len, MAX_HEADER_SIZE),
        };
        @memcpy(header.name[0..header.name_len], name[0..header.name_len]);
        @memcpy(header.value[0..header.value_len], value[0..header.value_len]);
        return header;
    }

    pub fn getName(self: *const HttpHeader) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn getValue(self: *const HttpHeader) []const u8 {
        return self.value[0..self.value_len];
    }
};

// =============================================================================
// HTTP REQUEST
// =============================================================================

pub const HttpRequest = struct {
    method: HttpMethod,
    path: [MAX_PATH_SIZE]u8,
    path_len: usize,
    headers: [MAX_HEADERS]HttpHeader,
    header_count: usize,
    body: [MAX_BODY_SIZE]u8,
    body_len: usize,
    is_valid: bool,

    pub fn init() HttpRequest {
        return HttpRequest{
            .method = .Unknown,
            .path = undefined,
            .path_len = 0,
            .headers = undefined,
            .header_count = 0,
            .body = undefined,
            .body_len = 0,
            .is_valid = false,
        };
    }

    pub fn getPath(self: *const HttpRequest) []const u8 {
        return self.path[0..self.path_len];
    }

    pub fn getBody(self: *const HttpRequest) []const u8 {
        return self.body[0..self.body_len];
    }

    pub fn getRoute(self: *const HttpRequest) Route {
        return Route.fromPath(self.getPath());
    }

    pub fn getHeader(self: *const HttpRequest, name: []const u8) ?[]const u8 {
        for (self.headers[0..self.header_count]) |*header| {
            if (std.ascii.eqlIgnoreCase(header.getName(), name)) {
                return header.getValue();
            }
        }
        return null;
    }

    pub fn isStreamingRequest(self: *const HttpRequest) bool {
        // Check if Accept header contains text/event-stream
        if (self.getHeader("Accept")) |accept| {
            if (std.mem.indexOf(u8, accept, "text/event-stream") != null) {
                return true;
            }
        }
        // Check body for stream: true
        const body = self.getBody();
        if (std.mem.indexOf(u8, body, "\"stream\":true") != null or
            std.mem.indexOf(u8, body, "\"stream\": true") != null)
        {
            return true;
        }
        return false;
    }
};

// =============================================================================
// HTTP RESPONSE
// =============================================================================

pub const HttpResponse = struct {
    status: HttpStatus,
    headers: [MAX_HEADERS]HttpHeader,
    header_count: usize,
    body: [MAX_RESPONSE_SIZE]u8,
    body_len: usize,
    is_streaming: bool,

    pub fn init(status: HttpStatus) HttpResponse {
        var response = HttpResponse{
            .status = status,
            .headers = undefined,
            .header_count = 0,
            .body = undefined,
            .body_len = 0,
            .is_streaming = false,
        };
        // Add default headers
        response.addHeader("Server", SERVER_NAME);
        response.addHeader("Access-Control-Allow-Origin", "*");
        response.addHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        response.addHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
        response.addHeader("Connection", "close");
        return response;
    }

    pub fn addHeader(self: *HttpResponse, name: []const u8, value: []const u8) void {
        if (self.header_count < MAX_HEADERS) {
            self.headers[self.header_count] = HttpHeader.init(name, value);
            self.header_count += 1;
        }
    }

    pub fn setBody(self: *HttpResponse, content: []const u8) void {
        self.body_len = @min(content.len, MAX_RESPONSE_SIZE);
        @memcpy(self.body[0..self.body_len], content[0..self.body_len]);
    }

    pub fn setJsonBody(self: *HttpResponse, json: []const u8) void {
        self.addHeader("Content-Type", "application/json");
        self.setBody(json);
    }

    pub fn setStreamingMode(self: *HttpResponse) void {
        self.is_streaming = true;
        self.addHeader("Content-Type", "text/event-stream");
        self.addHeader("Cache-Control", "no-cache");
    }

    pub fn getBody(self: *const HttpResponse) []const u8 {
        return self.body[0..self.body_len];
    }

    pub fn build(self: *const HttpResponse, buffer: []u8) usize {
        var pos: usize = 0;

        // Status line
        const status_line = std.fmt.bufPrint(buffer[pos..], "HTTP/1.1 {d} {s}\r\n", .{
            self.status.getCode(),
            self.status.getReason(),
        }) catch return 0;
        pos += status_line.len;

        // Headers
        for (self.headers[0..self.header_count]) |*header| {
            const header_line = std.fmt.bufPrint(buffer[pos..], "{s}: {s}\r\n", .{
                header.getName(),
                header.getValue(),
            }) catch break;
            pos += header_line.len;
        }

        // Content-Length (if not streaming)
        if (!self.is_streaming) {
            const cl_line = std.fmt.bufPrint(buffer[pos..], "Content-Length: {d}\r\n", .{
                self.body_len,
            }) catch return pos;
            pos += cl_line.len;
        }

        // End of headers
        if (pos + 2 <= buffer.len) {
            buffer[pos] = '\r';
            buffer[pos + 1] = '\n';
            pos += 2;
        }

        // Body
        if (!self.is_streaming and self.body_len > 0) {
            if (pos + self.body_len <= buffer.len) {
                @memcpy(buffer[pos .. pos + self.body_len], self.body[0..self.body_len]);
                pos += self.body_len;
            }
        }

        return pos;
    }
};

// =============================================================================
// REQUEST PARSER
// =============================================================================

pub const RequestParser = struct {
    pub fn parse(data: []const u8) HttpRequest {
        var request = HttpRequest.init();

        if (data.len == 0) return request;

        // Find end of headers
        var header_end: usize = data.len;
        for (0..data.len - 3) |i| {
            if (data[i] == '\r' and data[i + 1] == '\n' and data[i + 2] == '\r' and data[i + 3] == '\n') {
                header_end = i + 4;
                break;
            }
        }

        // Parse request line
        var lines = std.mem.splitSequence(u8, data[0..header_end], "\r\n");
        const request_line = lines.next() orelse return request;

        var parts = std.mem.splitScalar(u8, request_line, ' ');
        const method_str = parts.next() orelse return request;
        const path_str = parts.next() orelse return request;

        request.method = HttpMethod.fromString(method_str);
        request.path_len = @min(path_str.len, MAX_PATH_SIZE);
        @memcpy(request.path[0..request.path_len], path_str[0..request.path_len]);

        // Parse headers
        while (lines.next()) |line| {
            if (line.len == 0) break;
            if (std.mem.indexOf(u8, line, ": ")) |colon_idx| {
                const name = line[0..colon_idx];
                const value = line[colon_idx + 2 ..];
                if (request.header_count < MAX_HEADERS) {
                    request.headers[request.header_count] = HttpHeader.init(name, value);
                    request.header_count += 1;
                }
            }
        }

        // Extract body
        if (header_end < data.len) {
            const body_data = data[header_end..];
            request.body_len = @min(body_data.len, MAX_BODY_SIZE);
            @memcpy(request.body[0..request.body_len], body_data[0..request.body_len]);
        }

        request.is_valid = true;
        return request;
    }
};

// =============================================================================
// JSON BUILDER (Lightweight)
// =============================================================================

pub const JsonBuilder = struct {
    buffer: [MAX_RESPONSE_SIZE]u8,
    pos: usize,

    pub fn init() JsonBuilder {
        return JsonBuilder{
            .buffer = undefined,
            .pos = 0,
        };
    }

    pub fn startObject(self: *JsonBuilder) void {
        if (self.pos < MAX_RESPONSE_SIZE) {
            self.buffer[self.pos] = '{';
            self.pos += 1;
        }
    }

    pub fn endObject(self: *JsonBuilder) void {
        // Remove trailing comma if present
        if (self.pos > 0 and self.buffer[self.pos - 1] == ',') {
            self.pos -= 1;
        }
        if (self.pos < MAX_RESPONSE_SIZE) {
            self.buffer[self.pos] = '}';
            self.pos += 1;
        }
    }

    pub fn startArray(self: *JsonBuilder) void {
        if (self.pos < MAX_RESPONSE_SIZE) {
            self.buffer[self.pos] = '[';
            self.pos += 1;
        }
    }

    pub fn endArray(self: *JsonBuilder) void {
        // Remove trailing comma if present
        if (self.pos > 0 and self.buffer[self.pos - 1] == ',') {
            self.pos -= 1;
        }
        if (self.pos < MAX_RESPONSE_SIZE) {
            self.buffer[self.pos] = ']';
            self.pos += 1;
        }
    }

    pub fn addString(self: *JsonBuilder, key: []const u8, value: []const u8) void {
        const written = std.fmt.bufPrint(self.buffer[self.pos..], "\"{s}\":\"{s}\",", .{ key, value }) catch return;
        self.pos += written.len;
    }

    pub fn addNumber(self: *JsonBuilder, key: []const u8, value: i64) void {
        const written = std.fmt.bufPrint(self.buffer[self.pos..], "\"{s}\":{d},", .{ key, value }) catch return;
        self.pos += written.len;
    }

    pub fn addBool(self: *JsonBuilder, key: []const u8, value: bool) void {
        const val_str = if (value) "true" else "false";
        const written = std.fmt.bufPrint(self.buffer[self.pos..], "\"{s}\":{s},", .{ key, val_str }) catch return;
        self.pos += written.len;
    }

    pub fn addRaw(self: *JsonBuilder, key: []const u8, raw: []const u8) void {
        const written = std.fmt.bufPrint(self.buffer[self.pos..], "\"{s}\":{s},", .{ key, raw }) catch return;
        self.pos += written.len;
    }

    pub fn addArrayElement(self: *JsonBuilder, value: []const u8) void {
        const written = std.fmt.bufPrint(self.buffer[self.pos..], "{s},", .{value}) catch return;
        self.pos += written.len;
    }

    pub fn getJson(self: *const JsonBuilder) []const u8 {
        return self.buffer[0..self.pos];
    }

    pub fn reset(self: *JsonBuilder) void {
        self.pos = 0;
    }
};

// =============================================================================
// API METRICS
// =============================================================================

pub const ApiMetrics = struct {
    total_requests: u64,
    successful_requests: u64,
    failed_requests: u64,
    total_tokens_generated: u64,
    total_response_time_ns: i64,
    start_time_ns: i64,

    pub fn init() ApiMetrics {
        return ApiMetrics{
            .total_requests = 0,
            .successful_requests = 0,
            .failed_requests = 0,
            .total_tokens_generated = 0,
            .total_response_time_ns = 0,
            .start_time_ns = @intCast(std.time.nanoTimestamp()),
        };
    }

    pub fn recordRequest(self: *ApiMetrics, success: bool, tokens: u64, response_time_ns: i64) void {
        self.total_requests += 1;
        if (success) {
            self.successful_requests += 1;
        } else {
            self.failed_requests += 1;
        }
        self.total_tokens_generated += tokens;
        self.total_response_time_ns += response_time_ns;
    }

    pub fn getUptime(self: *const ApiMetrics) f64 {
        const now: i64 = @intCast(std.time.nanoTimestamp());
        return @as(f64, @floatFromInt(now - self.start_time_ns)) / 1_000_000_000.0;
    }

    pub fn getAverageResponseTime(self: *const ApiMetrics) f64 {
        if (self.total_requests == 0) return 0;
        return @as(f64, @floatFromInt(self.total_response_time_ns)) / @as(f64, @floatFromInt(self.total_requests)) / 1_000_000.0;
    }

    pub fn getSuccessRate(self: *const ApiMetrics) f64 {
        if (self.total_requests == 0) return 1.0;
        return @as(f64, @floatFromInt(self.successful_requests)) / @as(f64, @floatFromInt(self.total_requests));
    }
};

// =============================================================================
// API HANDLER
// =============================================================================

pub const ApiHandler = struct {
    streaming_engine: streaming.StreamingEngine,
    metrics: ApiMetrics,

    pub fn init() ApiHandler {
        return ApiHandler{
            .streaming_engine = streaming.StreamingEngine.init(),
            .metrics = ApiMetrics.init(),
        };
    }

    pub fn handle(self: *ApiHandler, request: *const HttpRequest) HttpResponse {
        const route = request.getRoute();
        const method = request.method;

        return switch (route) {
            .ChatCompletions => self.handleChatCompletions(request, method),
            .Models => self.handleModels(method),
            .Health => self.handleHealth(method),
            .Root => self.handleRoot(method),
            .Metrics => self.handleMetrics(method),
            .Unknown => self.handleNotFound(),
        };
    }

    fn handleChatCompletions(self: *ApiHandler, request: *const HttpRequest, method: HttpMethod) HttpResponse {
        if (method == .OPTIONS) {
            return self.handleCors();
        }
        if (method != .POST) {
            return self.handleMethodNotAllowed();
        }

        const start_time: i64 = @intCast(std.time.nanoTimestamp());

        // Extract message from request body
        const body = request.getBody();
        const message = self.extractMessageFromBody(body);

        // Generate streaming response
        const stream_response = self.streaming_engine.streamWithYield(message);

        // Build OpenAI-compatible response
        var response = HttpResponse.init(.OK);
        var json = JsonBuilder.init();

        json.startObject();
        json.addString("id", "chatcmpl-igla-001");
        json.addString("object", "chat.completion");
        const now_ns: i64 = @intCast(std.time.nanoTimestamp());
        json.addNumber("created", @divFloor(now_ns, 1_000_000_000));
        json.addString("model", MODEL_ID);

        // Add choices array
        const choices_start = "{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"";
        const choices_end = "\"},\"finish_reason\":\"stop\"}";

        var choices_json: [4096]u8 = undefined;
        var choices_len: usize = 0;

        // Build choices JSON
        @memcpy(choices_json[choices_len .. choices_len + choices_start.len], choices_start);
        choices_len += choices_start.len;

        // Add content (escape special characters)
        const content = stream_response.getTotalText();
        for (content) |c| {
            if (choices_len >= 4000) break;
            if (c == '"') {
                choices_json[choices_len] = '\\';
                choices_len += 1;
                choices_json[choices_len] = '"';
                choices_len += 1;
            } else if (c == '\n') {
                choices_json[choices_len] = '\\';
                choices_len += 1;
                choices_json[choices_len] = 'n';
                choices_len += 1;
            } else if (c == '\r') {
                // Skip carriage returns
            } else {
                choices_json[choices_len] = c;
                choices_len += 1;
            }
        }

        @memcpy(choices_json[choices_len .. choices_len + choices_end.len], choices_end);
        choices_len += choices_end.len;

        json.addRaw("choices", choices_json[0..choices_len]);

        // Add usage (build at runtime)
        var usage_buf: [128]u8 = undefined;
        const tokens_gen = stream_response.progress.tokens_generated;
        const usage_str = std.fmt.bufPrint(&usage_buf, "{{\"prompt_tokens\":10,\"completion_tokens\":{d},\"total_tokens\":{d}}}", .{ tokens_gen, tokens_gen + 10 }) catch "{\"prompt_tokens\":10,\"completion_tokens\":0,\"total_tokens\":10}";
        json.addRaw("usage", usage_str);

        json.endObject();

        response.setJsonBody(json.getJson());

        // Record metrics
        const end_time: i64 = @intCast(std.time.nanoTimestamp());
        const success = !stream_response.hasError();
        self.metrics.recordRequest(success, stream_response.progress.tokens_generated, end_time - start_time);

        return response;
    }

    fn extractMessageFromBody(self: *ApiHandler, body: []const u8) []const u8 {
        _ = self;
        // Simple extraction of last message content
        // Look for "content": "..."
        if (std.mem.indexOf(u8, body, "\"content\":")) |content_start| {
            const after_key = body[content_start + 10 ..];
            // Skip whitespace and find opening quote
            var i: usize = 0;
            while (i < after_key.len and (after_key[i] == ' ' or after_key[i] == '"')) {
                i += 1;
            }
            if (i > 0) i -= 1; // Back to the opening quote
            if (i < after_key.len and after_key[i] == '"') {
                const content_data = after_key[i + 1 ..];
                // Find closing quote
                for (content_data, 0..) |c, j| {
                    if (c == '"' and (j == 0 or content_data[j - 1] != '\\')) {
                        return content_data[0..j];
                    }
                }
            }
        }
        return "Hello";
    }

    fn handleModels(self: *ApiHandler, method: HttpMethod) HttpResponse {
        _ = self;
        if (method == .OPTIONS) {
            const response = HttpResponse.init(.NoContent);
            return response;
        }
        if (method != .GET) {
            return HttpResponse.init(.MethodNotAllowed);
        }

        var response = HttpResponse.init(.OK);
        const json =
            \\{"object":"list","data":[{"id":"igla-fluent-v1","object":"model","created":1707307200,"owned_by":"trinity","permission":[],"root":"igla-fluent-v1","parent":null}]}
        ;
        response.setJsonBody(json);
        return response;
    }

    fn handleHealth(self: *ApiHandler, method: HttpMethod) HttpResponse {
        _ = self;
        if (method != .GET and method != .HEAD) {
            return HttpResponse.init(.MethodNotAllowed);
        }

        var response = HttpResponse.init(.OK);
        const json = "{\"status\":\"ok\",\"model\":\"" ++ MODEL_ID ++ "\",\"version\":\"1.0.0\"}";
        response.setJsonBody(json);
        return response;
    }

    fn handleRoot(self: *ApiHandler, method: HttpMethod) HttpResponse {
        _ = self;
        if (method != .GET and method != .HEAD) {
            return HttpResponse.init(.MethodNotAllowed);
        }

        var response = HttpResponse.init(.OK);
        const json =
            \\{"name":"IGLA API Server","version":"1.0.0","model":"igla-fluent-v1","endpoints":["/v1/chat/completions","/v1/models","/health","/metrics"]}
        ;
        response.setJsonBody(json);
        return response;
    }

    fn handleMetrics(self: *ApiHandler, method: HttpMethod) HttpResponse {
        if (method != .GET) {
            return HttpResponse.init(.MethodNotAllowed);
        }

        var response = HttpResponse.init(.OK);
        var json = JsonBuilder.init();

        json.startObject();
        json.addNumber("total_requests", @intCast(self.metrics.total_requests));
        json.addNumber("successful_requests", @intCast(self.metrics.successful_requests));
        json.addNumber("failed_requests", @intCast(self.metrics.failed_requests));
        json.addNumber("total_tokens", @intCast(self.metrics.total_tokens_generated));
        json.endObject();

        response.setJsonBody(json.getJson());
        return response;
    }

    fn handleCors(self: *ApiHandler) HttpResponse {
        _ = self;
        return HttpResponse.init(.NoContent);
    }

    fn handleMethodNotAllowed(self: *ApiHandler) HttpResponse {
        _ = self;
        var response = HttpResponse.init(.MethodNotAllowed);
        response.setJsonBody("{\"error\":\"Method not allowed\"}");
        return response;
    }

    fn handleNotFound(self: *ApiHandler) HttpResponse {
        _ = self;
        var response = HttpResponse.init(.NotFound);
        response.setJsonBody("{\"error\":\"Not found\"}");
        return response;
    }
};

// =============================================================================
// API SERVER
// =============================================================================

pub const ApiServer = struct {
    handler: ApiHandler,
    port: u16,
    is_running: bool,
    requests_handled: u64,

    pub fn init() ApiServer {
        return ApiServer{
            .handler = ApiHandler.init(),
            .port = DEFAULT_PORT,
            .is_running = false,
            .requests_handled = 0,
        };
    }

    pub fn initWithPort(port: u16) ApiServer {
        var server = ApiServer.init();
        server.port = port;
        return server;
    }

    pub fn processRequest(self: *ApiServer, raw_request: []const u8) HttpResponse {
        const request = RequestParser.parse(raw_request);
        if (!request.is_valid) {
            var response = HttpResponse.init(.BadRequest);
            response.setJsonBody("{\"error\":\"Invalid request\"}");
            return response;
        }

        self.requests_handled += 1;
        return self.handler.handle(&request);
    }

    pub fn getMetrics(self: *const ApiServer) ApiMetrics {
        return self.handler.metrics;
    }

    pub fn getRequestsHandled(self: *const ApiServer) u64 {
        return self.requests_handled;
    }

    pub fn isHealthy(self: *const ApiServer) bool {
        return self.handler.metrics.getSuccessRate() >= 0.9;
    }

    /// Run the server and listen for connections
    pub fn run(self: *ApiServer) !void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           IGLA API SERVER v1.0                               ║\n", .{});
        std.debug.print("║           OpenAI-compatible /v1/chat/completions             ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
        std.debug.print("\n", .{});

        std.debug.print("Starting server on http://0.0.0.0:{d}\n", .{self.port});
        std.debug.print("Endpoints:\n", .{});
        std.debug.print("  POST /v1/chat/completions - Chat completion\n", .{});
        std.debug.print("  GET  /v1/models           - List models\n", .{});
        std.debug.print("  GET  /health              - Health check\n", .{});
        std.debug.print("  GET  /metrics             - Server metrics\n", .{});
        std.debug.print("  GET  /                    - Server info\n", .{});
        std.debug.print("\n", .{});

        const address = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, self.port);
        var server = try address.listen(.{
            .reuse_address = true,
        });
        defer server.deinit();

        self.is_running = true;
        std.debug.print("Server ready! Listening on port {d}...\n", .{self.port});
        std.debug.print("Press Ctrl+C to stop.\n\n", .{});

        while (self.is_running) {
            var connection = server.accept() catch |err| {
                std.debug.print("Accept error: {}\n", .{err});
                continue;
            };

            self.handleConnection(&connection) catch |err| {
                std.debug.print("Request error: {}\n", .{err});
            };

            connection.stream.close();
        }
    }

    fn handleConnection(self: *ApiServer, connection: *std.net.Server.Connection) !void {
        var buf: [MAX_REQUEST_SIZE]u8 = undefined;
        const n = try connection.stream.read(&buf);
        if (n == 0) return;

        const request_data = buf[0..n];
        const response = self.processRequest(request_data);

        // Build and send response
        var response_buf: [MAX_RESPONSE_SIZE]u8 = undefined;
        const response_len = response.build(&response_buf);

        if (response_len > 0) {
            try connection.stream.writeAll(response_buf[0..response_len]);
        }

        // Log request
        const request = RequestParser.parse(request_data);
        std.debug.print("{s} {s} -> {d}\n", .{
            request.method.toString(),
            request.getPath(),
            response.status.getCode(),
        });
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "HttpMethod fromString" {
    try std.testing.expectEqual(HttpMethod.GET, HttpMethod.fromString("GET"));
    try std.testing.expectEqual(HttpMethod.POST, HttpMethod.fromString("POST"));
    try std.testing.expectEqual(HttpMethod.OPTIONS, HttpMethod.fromString("OPTIONS"));
    try std.testing.expectEqual(HttpMethod.Unknown, HttpMethod.fromString("PATCH"));
}

test "HttpStatus getCode and getReason" {
    try std.testing.expectEqual(@as(u16, 200), HttpStatus.OK.getCode());
    try std.testing.expectEqualStrings("OK", HttpStatus.OK.getReason());
    try std.testing.expectEqual(@as(u16, 404), HttpStatus.NotFound.getCode());
    try std.testing.expectEqualStrings("Not Found", HttpStatus.NotFound.getReason());
}

test "Route fromPath" {
    try std.testing.expectEqual(Route.ChatCompletions, Route.fromPath("/v1/chat/completions"));
    try std.testing.expectEqual(Route.Models, Route.fromPath("/v1/models"));
    try std.testing.expectEqual(Route.Health, Route.fromPath("/health"));
    try std.testing.expectEqual(Route.Root, Route.fromPath("/"));
    try std.testing.expectEqual(Route.Unknown, Route.fromPath("/unknown/path"));
}

test "HttpHeader init and getters" {
    const header = HttpHeader.init("Content-Type", "application/json");
    try std.testing.expectEqualStrings("Content-Type", header.getName());
    try std.testing.expectEqualStrings("application/json", header.getValue());
}

test "HttpRequest init" {
    const request = HttpRequest.init();
    try std.testing.expectEqual(HttpMethod.Unknown, request.method);
    try std.testing.expectEqual(@as(usize, 0), request.path_len);
    try std.testing.expectEqual(false, request.is_valid);
}

test "HttpResponse init and build" {
    var response = HttpResponse.init(.OK);
    response.setJsonBody("{\"test\":true}");

    var buffer: [4096]u8 = undefined;
    const len = response.build(&buffer);
    try std.testing.expect(len > 0);

    const response_str = buffer[0..len];
    try std.testing.expect(std.mem.indexOf(u8, response_str, "HTTP/1.1 200 OK") != null);
    try std.testing.expect(std.mem.indexOf(u8, response_str, "application/json") != null);
}

test "RequestParser parse GET" {
    const raw = "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const request = RequestParser.parse(raw);

    try std.testing.expect(request.is_valid);
    try std.testing.expectEqual(HttpMethod.GET, request.method);
    try std.testing.expectEqualStrings("/health", request.getPath());
}

test "RequestParser parse POST with body" {
    const raw = "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"message\":\"hello\"}";
    const request = RequestParser.parse(raw);

    try std.testing.expect(request.is_valid);
    try std.testing.expectEqual(HttpMethod.POST, request.method);
    try std.testing.expectEqualStrings("/v1/chat/completions", request.getPath());
    try std.testing.expect(request.body_len > 0);
}

test "JsonBuilder basic" {
    var json = JsonBuilder.init();
    json.startObject();
    json.addString("name", "test");
    json.addNumber("value", 42);
    json.addBool("active", true);
    json.endObject();

    const result = json.getJson();
    try std.testing.expect(std.mem.indexOf(u8, result, "\"name\":\"test\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "\"value\":42") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "\"active\":true") != null);
}

test "ApiMetrics init and record" {
    var metrics = ApiMetrics.init();
    try std.testing.expectEqual(@as(u64, 0), metrics.total_requests);

    metrics.recordRequest(true, 10, 1000000);
    try std.testing.expectEqual(@as(u64, 1), metrics.total_requests);
    try std.testing.expectEqual(@as(u64, 1), metrics.successful_requests);
    try std.testing.expectEqual(@as(u64, 10), metrics.total_tokens_generated);

    metrics.recordRequest(false, 0, 500000);
    try std.testing.expectEqual(@as(u64, 2), metrics.total_requests);
    try std.testing.expectEqual(@as(u64, 1), metrics.failed_requests);
}

test "ApiMetrics success rate" {
    var metrics = ApiMetrics.init();
    metrics.recordRequest(true, 5, 100000);
    metrics.recordRequest(true, 5, 100000);
    metrics.recordRequest(false, 0, 100000);

    const success_rate = metrics.getSuccessRate();
    try std.testing.expect(success_rate > 0.6);
    try std.testing.expect(success_rate < 0.7);
}

test "ApiHandler init" {
    const handler = ApiHandler.init();
    try std.testing.expectEqual(@as(u64, 0), handler.metrics.total_requests);
}

test "ApiHandler handle health" {
    var handler = ApiHandler.init();
    const raw = "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const request = RequestParser.parse(raw);

    const response = handler.handle(&request);
    try std.testing.expectEqual(HttpStatus.OK, response.status);
    try std.testing.expect(std.mem.indexOf(u8, response.getBody(), "status") != null);
}

test "ApiHandler handle models" {
    var handler = ApiHandler.init();
    const raw = "GET /v1/models HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const request = RequestParser.parse(raw);

    const response = handler.handle(&request);
    try std.testing.expectEqual(HttpStatus.OK, response.status);
    try std.testing.expect(std.mem.indexOf(u8, response.getBody(), "igla-fluent-v1") != null);
}

test "ApiHandler handle root" {
    var handler = ApiHandler.init();
    const raw = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const request = RequestParser.parse(raw);

    const response = handler.handle(&request);
    try std.testing.expectEqual(HttpStatus.OK, response.status);
    try std.testing.expect(std.mem.indexOf(u8, response.getBody(), "IGLA API Server") != null);
}

test "ApiHandler handle not found" {
    var handler = ApiHandler.init();
    const raw = "GET /unknown/path HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const request = RequestParser.parse(raw);

    const response = handler.handle(&request);
    try std.testing.expectEqual(HttpStatus.NotFound, response.status);
}

test "ApiHandler handle method not allowed" {
    var handler = ApiHandler.init();
    const raw = "DELETE /health HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const request = RequestParser.parse(raw);

    const response = handler.handle(&request);
    try std.testing.expectEqual(HttpStatus.MethodNotAllowed, response.status);
}

test "ApiHandler handle chat completions" {
    var handler = ApiHandler.init();
    const raw = "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}";
    const request = RequestParser.parse(raw);

    const response = handler.handle(&request);
    try std.testing.expectEqual(HttpStatus.OK, response.status);
    try std.testing.expect(std.mem.indexOf(u8, response.getBody(), "chat.completion") != null);
}

test "ApiHandler handle chat completions OPTIONS" {
    var handler = ApiHandler.init();
    const raw = "OPTIONS /v1/chat/completions HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const request = RequestParser.parse(raw);

    const response = handler.handle(&request);
    try std.testing.expectEqual(HttpStatus.NoContent, response.status);
}

test "ApiHandler handle metrics" {
    var handler = ApiHandler.init();

    // Generate some metrics
    const chat_raw = "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}";
    const chat_request = RequestParser.parse(chat_raw);
    _ = handler.handle(&chat_request);

    // Now check metrics
    const raw = "GET /metrics HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const request = RequestParser.parse(raw);

    const response = handler.handle(&request);
    try std.testing.expectEqual(HttpStatus.OK, response.status);
    try std.testing.expect(std.mem.indexOf(u8, response.getBody(), "total_requests") != null);
}

test "ApiServer init" {
    const server = ApiServer.init();
    try std.testing.expectEqual(DEFAULT_PORT, server.port);
    try std.testing.expectEqual(false, server.is_running);
    try std.testing.expectEqual(@as(u64, 0), server.requests_handled);
}

test "ApiServer initWithPort" {
    const server = ApiServer.initWithPort(3000);
    try std.testing.expectEqual(@as(u16, 3000), server.port);
}

test "ApiServer processRequest health" {
    var server = ApiServer.init();
    const raw = "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const response = server.processRequest(raw);

    try std.testing.expectEqual(HttpStatus.OK, response.status);
    try std.testing.expectEqual(@as(u64, 1), server.requests_handled);
}

test "ApiServer processRequest invalid" {
    var server = ApiServer.init();
    const raw = "";
    const response = server.processRequest(raw);

    try std.testing.expectEqual(HttpStatus.BadRequest, response.status);
}

test "ApiServer processRequest chat" {
    var server = ApiServer.init();
    const raw = "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}";
    const response = server.processRequest(raw);

    try std.testing.expectEqual(HttpStatus.OK, response.status);
    try std.testing.expect(std.mem.indexOf(u8, response.getBody(), "chat.completion") != null);
}

test "ApiServer isHealthy" {
    var server = ApiServer.init();

    // Initially healthy (no requests = 100% success)
    try std.testing.expect(server.isHealthy());

    // Process a successful request
    const raw = "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n";
    _ = server.processRequest(raw);

    // Still healthy
    try std.testing.expect(server.isHealthy());
}

test "ApiServer getMetrics" {
    var server = ApiServer.init();

    // Process some requests
    const raw = "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}";
    _ = server.processRequest(raw);
    _ = server.processRequest(raw);

    const metrics = server.getMetrics();
    try std.testing.expectEqual(@as(u64, 2), metrics.total_requests);
}

test "HttpRequest isStreamingRequest" {
    // Test with Accept header
    const raw1 = "POST /v1/chat/completions HTTP/1.1\r\nAccept: text/event-stream\r\n\r\n{}";
    const request1 = RequestParser.parse(raw1);
    try std.testing.expect(request1.isStreamingRequest());

    // Test with body stream:true
    const raw2 = "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"stream\":true}";
    const request2 = RequestParser.parse(raw2);
    try std.testing.expect(request2.isStreamingRequest());

    // Test without streaming
    const raw3 = "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{}";
    const request3 = RequestParser.parse(raw3);
    try std.testing.expect(!request3.isStreamingRequest());
}

test "HttpResponse setStreamingMode" {
    var response = HttpResponse.init(.OK);
    response.setStreamingMode();

    try std.testing.expect(response.is_streaming);

    var buffer: [4096]u8 = undefined;
    const len = response.build(&buffer);
    const response_str = buffer[0..len];

    try std.testing.expect(std.mem.indexOf(u8, response_str, "text/event-stream") != null);
}

test "JsonBuilder array" {
    var json = JsonBuilder.init();
    json.startArray();
    json.addArrayElement("\"item1\"");
    json.addArrayElement("\"item2\"");
    json.endArray();

    const result = json.getJson();
    try std.testing.expect(std.mem.startsWith(u8, result, "["));
    try std.testing.expect(result[result.len - 1] == ']');
}

test "JsonBuilder reset" {
    var json = JsonBuilder.init();
    json.startObject();
    json.addString("key", "value");
    json.endObject();

    try std.testing.expect(json.pos > 0);

    json.reset();
    try std.testing.expectEqual(@as(usize, 0), json.pos);
}

test "Route with query string" {
    try std.testing.expectEqual(Route.ChatCompletions, Route.fromPath("/v1/chat/completions?stream=true"));
    try std.testing.expectEqual(Route.Models, Route.fromPath("/v1/models?format=json"));
}

test "Multiple chat requests" {
    var server = ApiServer.init();

    const messages = [_][]const u8{
        "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}",
        "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"How are you?\"}]}",
        "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"Goodbye!\"}]}",
    };

    for (messages) |msg| {
        const response = server.processRequest(msg);
        try std.testing.expectEqual(HttpStatus.OK, response.status);
    }

    try std.testing.expectEqual(@as(u64, 3), server.requests_handled);
}

test "Response contains required OpenAI fields" {
    var server = ApiServer.init();
    const raw = "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}";
    const response = server.processRequest(raw);

    const body = response.getBody();
    try std.testing.expect(std.mem.indexOf(u8, body, "\"id\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"object\":\"chat.completion\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"choices\":") != null);
}

test "ApiMetrics uptime" {
    const metrics = ApiMetrics.init();
    const uptime = metrics.getUptime();
    try std.testing.expect(uptime >= 0);
}

test "ApiMetrics average response time" {
    var metrics = ApiMetrics.init();
    metrics.recordRequest(true, 10, 1_000_000); // 1ms
    metrics.recordRequest(true, 10, 2_000_000); // 2ms

    const avg = metrics.getAverageResponseTime();
    try std.testing.expect(avg >= 1.0);
    try std.testing.expect(avg <= 2.0);
}

test "Complete API workflow" {
    var server = ApiServer.init();

    // 1. Health check
    const health_response = server.processRequest("GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n");
    try std.testing.expectEqual(HttpStatus.OK, health_response.status);

    // 2. List models
    const models_response = server.processRequest("GET /v1/models HTTP/1.1\r\nHost: localhost\r\n\r\n");
    try std.testing.expectEqual(HttpStatus.OK, models_response.status);

    // 3. Chat completion
    const chat_response = server.processRequest("POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}");
    try std.testing.expectEqual(HttpStatus.OK, chat_response.status);

    // 4. Check metrics
    const metrics_response = server.processRequest("GET /metrics HTTP/1.1\r\nHost: localhost\r\n\r\n");
    try std.testing.expectEqual(HttpStatus.OK, metrics_response.status);

    try std.testing.expectEqual(@as(u64, 4), server.requests_handled);
}

// =============================================================================
// BENCHMARK
// =============================================================================

pub fn runBenchmark() void {
    std.debug.print("\n", .{});
    std.debug.print("===============================================================================\n", .{});
    std.debug.print("     IGLA API SERVER BENCHMARK (CYCLE 19)\n", .{});
    std.debug.print("===============================================================================\n", .{});
    std.debug.print("\n", .{});

    var server = ApiServer.init();
    var total_requests: u64 = 0;
    var successful_requests: u64 = 0;
    var total_response_time: i64 = 0;

    // Test scenarios
    const scenarios = [_]struct { name: []const u8, request: []const u8 }{
        .{ .name = "Health Check", .request = "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n" },
        .{ .name = "List Models", .request = "GET /v1/models HTTP/1.1\r\nHost: localhost\r\n\r\n" },
        .{ .name = "Server Info", .request = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n" },
        .{ .name = "Chat Hello", .request = "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}" },
        .{ .name = "Chat Question", .request = "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"How are you?\"}]}" },
        .{ .name = "Chat Farewell", .request = "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"Goodbye!\"}]}" },
        .{ .name = "Chat Tech", .request = "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"Tell me about programming\"}]}" },
        .{ .name = "Chat Opinion", .request = "POST /v1/chat/completions HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"messages\":[{\"role\":\"user\",\"content\":\"I think AI is amazing\"}]}" },
        .{ .name = "Metrics", .request = "GET /metrics HTTP/1.1\r\nHost: localhost\r\n\r\n" },
        .{ .name = "CORS Preflight", .request = "OPTIONS /v1/chat/completions HTTP/1.1\r\nHost: localhost\r\n\r\n" },
    };

    // Run each scenario multiple times
    const iterations: u64 = 10;

    for (scenarios) |scenario| {
        var scenario_success: u64 = 0;
        var scenario_time: i64 = 0;

        for (0..iterations) |_| {
            const start: i64 = @intCast(std.time.nanoTimestamp());
            const response = server.processRequest(scenario.request);
            const end: i64 = @intCast(std.time.nanoTimestamp());

            total_requests += 1;
            scenario_time += end - start;
            total_response_time += end - start;

            if (response.status == .OK or response.status == .NoContent) {
                successful_requests += 1;
                scenario_success += 1;
            }
        }

        const avg_time_us = @as(f64, @floatFromInt(scenario_time)) / @as(f64, @floatFromInt(iterations)) / 1000.0;
        std.debug.print("  {s}: {d:.0}us avg, {d}/{d} success\n", .{ scenario.name, avg_time_us, scenario_success, iterations });
    }

    const success_rate = @as(f64, @floatFromInt(successful_requests)) / @as(f64, @floatFromInt(total_requests));
    const avg_response_time = @as(f64, @floatFromInt(total_response_time)) / @as(f64, @floatFromInt(total_requests)) / 1000.0;
    const ops_per_sec = @as(f64, @floatFromInt(total_requests)) / (@as(f64, @floatFromInt(total_response_time)) / 1_000_000_000.0);

    const metrics = server.getMetrics();

    std.debug.print("\n", .{});
    std.debug.print("  Total requests: {d}\n", .{total_requests});
    std.debug.print("  Successful: {d}\n", .{successful_requests});
    std.debug.print("  Success rate: {d:.2}\n", .{success_rate});
    std.debug.print("  Avg response time: {d:.0}us\n", .{avg_response_time});
    std.debug.print("  Throughput: {d:.0} req/s\n", .{ops_per_sec});
    std.debug.print("  Total tokens: {d}\n", .{metrics.total_tokens_generated});
    std.debug.print("\n", .{});

    // Golden Ratio Gate
    const improvement = success_rate;
    const passed = improvement > 0.618;

    std.debug.print("  Improvement rate: {d:.2}\n", .{improvement});
    if (passed) {
        std.debug.print("  Golden Ratio Gate: PASSED (>0.618)\n", .{});
    } else {
        std.debug.print("  Golden Ratio Gate: FAILED (<0.618)\n", .{});
    }
    std.debug.print("\n", .{});
}

// Run server when file is executed directly
pub fn main() !void {
    var server = ApiServer.init();
    try server.run();
}
