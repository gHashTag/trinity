// WASM stub for igla_local_chat — replaces system-dependent chat engine
// Provides the same public interface but returns canned responses

pub const Language = enum { Russian, English, Chinese, Unknown };
pub const ChatCategory = enum { greeting, help, unknown };

pub const ChatResponse = struct {
    response: []const u8,
    category: ChatCategory,
    language: Language,
    confidence: f32,
};

pub const IglaLocalChat = struct {
    response_counter: usize = 0,
    total_chats: usize = 0,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn isConversational(_: []const u8) bool {
        return true;
    }

    pub fn isCodeRelated(_: []const u8) bool {
        return false;
    }

    pub fn respond(self: *Self, _: []const u8) ChatResponse {
        self.response_counter += 1;
        self.total_chats += 1;
        return ChatResponse{
            .response = "WASM mode — symbolic chat unavailable",
            .category = .unknown,
            .language = .English,
            .confidence = 0.1,
        };
    }

    pub fn getStats(self: *const Self) struct { total_chats: usize, patterns_available: usize, categories: usize } {
        return .{
            .total_chats = self.total_chats,
            .patterns_available = 0,
            .categories = 0,
        };
    }
};
