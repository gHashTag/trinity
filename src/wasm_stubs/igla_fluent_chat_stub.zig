// WASM stub for igla_fluent_chat — replaces system-dependent fluent chat
// Provides the same public interface but returns canned responses

pub const MAX_TOPICS = 16;

pub const Language = enum {
    English, Russian, Chinese, Spanish, French, German, Japanese, Unknown,

    pub fn getName(self: Language) []const u8 {
        return switch (self) {
            .English => "English",
            .Russian => "Russian",
            .Chinese => "Chinese",
            .Spanish => "Spanish",
            .French => "French",
            .German => "German",
            .Japanese => "Japanese",
            .Unknown => "Unknown",
        };
    }
};

pub const Intent = enum {
    Greeting, Farewell, Question, Statement, Request, Opinion,
    Clarification, Acknowledgment, Emotion, Unknown,

    pub fn getName(self: Intent) []const u8 {
        return switch (self) {
            .Greeting => "Greeting",
            .Farewell => "Farewell",
            .Question => "Question",
            .Statement => "Statement",
            .Request => "Request",
            .Opinion => "Opinion",
            .Clarification => "Clarification",
            .Acknowledgment => "Acknowledgment",
            .Emotion => "Emotion",
            .Unknown => "Unknown",
        };
    }
};

pub const Topic = enum {
    Technology, Science, Art, Music, Sports, Health, Food, Travel,
    Work, Education, Entertainment, Philosophy, Nature, Social, Personal, General,

    pub fn getName(self: Topic) []const u8 {
        return switch (self) {
            .Technology => "Technology",
            .Science => "Science",
            .Art => "Art",
            .Music => "Music",
            .Sports => "Sports",
            .Health => "Health",
            .Food => "Food",
            .Travel => "Travel",
            .Work => "Work",
            .Education => "Education",
            .Entertainment => "Entertainment",
            .Philosophy => "Philosophy",
            .Nature => "Nature",
            .Social => "Social",
            .Personal => "Personal",
            .General => "General",
        };
    }
};

pub const ChatResponse = struct {
    text: [256]u8 = [_]u8{0} ** 256,
    text_len: usize = 0,
    quality: f32 = 0.5,
    intent: Intent = .Statement,
    topic: Topic = .Technology,
    language: Language = .English,
    is_fluent: bool = true,
    memory_used: bool = false,
    turn_number: u32 = 0,
    execution_time_ns: i64 = 1000,

    pub fn getText(self: *const ChatResponse) []const u8 {
        return self.text[0..self.text_len];
    }

    pub fn isHighQuality(self: *const ChatResponse) bool {
        return self.quality > 0.7;
    }
};

pub const FluentResponse = struct {
    text: [256]u8 = [_]u8{0} ** 256,
    text_len: usize = 0,
};

pub const EngineStats = struct {
    total_turns: usize = 0,
    fluent_responses: usize = 0,
    high_quality_count: usize = 0,
    fluent_rate: f32 = 0.0,
    quality_rate: f32 = 0.0,
    current_topic: Topic = .Technology,
    current_language: Language = .English,
    sentiment: f32 = 0.0,
    engagement: f32 = 0.0,
};

pub const LightMessage = struct {
    content: [256]u8 = [_]u8{0} ** 256,
    content_len: usize = 0,
    is_user: bool = false,
};

pub const LightMessageStore = struct {
    messages: [20]LightMessage = [_]LightMessage{LightMessage{}} ** 20,
    message_count: usize = 0,
    conversation_id: u32 = 0,

    pub fn init() LightMessageStore {
        return LightMessageStore{};
    }

    pub fn addMessage(self: *LightMessageStore, content: []const u8, is_user: bool) bool {
        if (self.message_count >= 20) return false;
        var msg = &self.messages[self.message_count];
        const len = @min(content.len, 256);
        @memcpy(msg.content[0..len], content[0..len]);
        msg.content_len = len;
        msg.is_user = is_user;
        self.message_count += 1;
        return true;
    }

    pub fn startConversation(self: *LightMessageStore, _: []const u8) u32 {
        self.conversation_id += 1;
        return self.conversation_id;
    }
};

pub const ConversationContext = struct {
    current_topic: Topic = .General,
    current_language: Language = .English,
    turn_count: u32 = 0,
    user_name: [32]u8 = [_]u8{0} ** 32,
    user_name_len: usize = 0,
    last_intent: Intent = .Unknown,
    topics_discussed: [MAX_TOPICS]Topic = [_]Topic{.General} ** MAX_TOPICS,
    topic_count: usize = 0,
    sentiment: f32 = 0.0,
    engagement_level: f32 = 0.0,

    pub fn init() ConversationContext {
        return ConversationContext{};
    }

    pub fn update(self: *ConversationContext, _: []const u8) void {
        self.turn_count += 1;
    }

    pub fn setUserName(self: *ConversationContext, name: []const u8) void {
        const len = @min(name.len, 32);
        @memcpy(self.user_name[0..len], name[0..len]);
        self.user_name_len = len;
    }

    pub fn getUserName(self: *const ConversationContext) []const u8 {
        return self.user_name[0..self.user_name_len];
    }

    pub fn hasUserName(self: *const ConversationContext) bool {
        return self.user_name_len > 0;
    }
};

pub const ResponseGenerator = struct {
    context: *ConversationContext,

    pub fn init(context: *ConversationContext) ResponseGenerator {
        return ResponseGenerator{ .context = context };
    }

    pub fn generate(self: *ResponseGenerator, _: []const u8) FluentResponse {
        _ = self;
        var resp = FluentResponse{};
        const msg = "WASM mode active. Trinity Canvas running in browser.";
        @memcpy(resp.text[0..msg.len], msg);
        resp.text_len = msg.len;
        return resp;
    }
};

pub const FluentChatEngine = struct {
    message_store: LightMessageStore = LightMessageStore.init(),
    context: ConversationContext = ConversationContext.init(),
    generator: ResponseGenerator = undefined,
    fluent_enabled: bool = true,
    total_turns: usize = 0,
    fluent_responses: usize = 0,
    high_quality_count: usize = 0,

    pub fn init() FluentChatEngine {
        var e = FluentChatEngine{};
        e.generator = ResponseGenerator.init(&e.context);
        return e;
    }

    pub fn startConversation(self: *FluentChatEngine, title: []const u8) ?u32 {
        return self.message_store.startConversation(title);
    }

    pub fn respond(self: *FluentChatEngine, _: []const u8) ChatResponse {
        self.total_turns += 1;
        self.fluent_responses += 1;
        var resp = ChatResponse{};
        const msg = "WASM mode — Trinity Canvas running in browser via WebGL.";
        @memcpy(resp.text[0..msg.len], msg);
        resp.text_len = msg.len;
        resp.quality = 0.8;
        resp.is_fluent = true;
        resp.turn_number = @intCast(self.total_turns);
        return resp;
    }

    pub fn setUserName(self: *FluentChatEngine, name: []const u8) void {
        self.context.setUserName(name);
    }

    pub fn getStats(self: *const FluentChatEngine) EngineStats {
        return EngineStats{
            .total_turns = self.total_turns,
            .fluent_responses = self.fluent_responses,
            .high_quality_count = self.high_quality_count,
            .fluent_rate = if (self.total_turns > 0) @as(f32, @floatFromInt(self.fluent_responses)) / @as(f32, @floatFromInt(self.total_turns)) else 0,
            .quality_rate = 0.8,
            .current_topic = self.context.current_topic,
            .current_language = self.context.current_language,
            .sentiment = self.context.sentiment,
            .engagement = self.context.engagement_level,
        };
    }
};
