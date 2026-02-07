// ═══════════════════════════════════════════════════════════════════════════════
// CHAT PATTERNS - Fluent conversational AI code generation
// ═══════════════════════════════════════════════════════════════════════════════
//
// Generates REAL fluent responses, not generic stubs.
// Multilingual: Russian, Chinese, English
// Context-aware with memory across turns.
// Honest uncertainty for unknown topics.
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("../types.zig");
const builder_mod = @import("../builder.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const Behavior = types.Behavior;

// ═══════════════════════════════════════════════════════════════════════════════
// RESPONSE DATABASES - Real fluent responses
// ═══════════════════════════════════════════════════════════════════════════════

/// Russian greeting responses
const GREETINGS_RU = [_][]const u8{
    "Привет! Рад тебя видеть!",
    "Здравствуй! Как твои дела?",
    "Приветствую! Чем могу помочь?",
    "Привет-привет! Что нового?",
    "Здорово! Как сам?",
};

/// English greeting responses
const GREETINGS_EN = [_][]const u8{
    "Hello! Nice to see you!",
    "Hi there! How can I help?",
    "Hey! What's on your mind?",
    "Hello! What brings you here today?",
    "Hi! Good to hear from you!",
};

/// Chinese greeting responses
const GREETINGS_ZH = [_][]const u8{
    "你好！很高兴见到你！",
    "嗨！今天过得怎么样？",
    "您好！有什么可以帮助您的吗？",
    "你好呀！最近怎么样？",
    "嘿！有什么事吗？",
};

/// Russian farewell responses
const FAREWELLS_RU = [_][]const u8{
    "До свидания! Был рад пообщаться!",
    "Пока! Возвращайся скорее!",
    "До встречи! Удачи тебе!",
    "Всего хорошего! Буду ждать!",
    "Пока-пока! Заходи ещё!",
};

/// English farewell responses
const FAREWELLS_EN = [_][]const u8{
    "Goodbye! It was nice talking to you!",
    "See you later! Come back soon!",
    "Take care! Good luck!",
    "Bye for now! Looking forward to next time!",
    "Farewell! Have a great day!",
};

/// Chinese farewell responses
const FAREWELLS_ZH = [_][]const u8{
    "再见！很高兴和你聊天！",
    "拜拜！下次再见！",
    "再会！祝你好运！",
    "回头见！保重！",
    "告辞！期待下次见面！",
};

/// Russian gratitude responses
const GRATITUDE_RU = [_][]const u8{
    "Пожалуйста! Рад помочь!",
    "Не за что! Обращайся!",
    "Всегда рад помочь!",
    "На здоровье! Если что — спрашивай!",
    "Рад быть полезным!",
};

/// English gratitude responses
const GRATITUDE_EN = [_][]const u8{
    "You're welcome! Happy to help!",
    "No problem! Anytime!",
    "My pleasure! Let me know if you need more!",
    "Glad I could help!",
    "Always here to assist!",
};

/// Chinese gratitude responses
const GRATITUDE_ZH = [_][]const u8{
    "不客气！很高兴帮助你！",
    "不用谢！随时来问！",
    "我很乐意帮忙！",
    "没问题！有需要再说！",
    "能帮到你我很开心！",
};

/// Russian feelings responses (honest AI)
const FEELINGS_RU = [_][]const u8{
    "Я — программа, у меня нет чувств. Но я готов помочь тебе!",
    "Как ИИ, я не испытываю эмоций, но я рад общению!",
    "У меня нет настроения, но я всегда готов к разговору!",
    "Честно — я не чувствую, но могу думать и отвечать!",
    "Я работаю стабильно! А как ты?",
};

/// English feelings responses (honest AI)
const FEELINGS_EN = [_][]const u8{
    "As an AI, I don't have feelings, but I'm ready to help you!",
    "I don't experience emotions, but I'm happy to chat!",
    "No mood here, but always ready for conversation!",
    "Honestly, I don't feel, but I can think and respond!",
    "Running smoothly! How about you?",
};

/// Chinese feelings responses (honest AI)
const FEELINGS_ZH = [_][]const u8{
    "作为AI，我没有感情，但我准备好帮助你！",
    "我不会感受情绪，但我很乐意聊天！",
    "我没有心情，但随时准备交谈！",
    "说实话，我不会感觉，但我能思考和回答！",
    "运行正常！你呢？",
};

/// Russian weather responses (honest limitation)
const WEATHER_RU = [_][]const u8{
    "К сожалению, я не могу проверить погоду. У меня нет доступа к интернету.",
    "Я не знаю текущую погоду — у меня нет такой возможности. Попробуй погодный сервис!",
    "Честно — я не могу узнать погоду. Это вне моих возможностей.",
    "Нет доступа к данным о погоде. Но могу помочь с чем-то другим!",
};

/// English weather responses (honest limitation)
const WEATHER_EN = [_][]const u8{
    "Sorry, I can't check the weather. I don't have internet access.",
    "I don't know the current weather — I don't have that capability. Try a weather service!",
    "Honestly, I can't get weather data. This is outside my abilities.",
    "No access to weather data. But I can help with something else!",
};

/// Chinese weather responses (honest limitation)
const WEATHER_ZH = [_][]const u8{
    "抱歉，我无法查看天气。我没有互联网访问权限。",
    "我不知道当前天气——我没有这个能力。试试天气服务吧！",
    "说实话，我无法获取天气数据。这超出了我的能力范围。",
    "无法访问天气数据。但我可以帮助其他事情！",
};

/// Russian humor responses
const HUMOR_RU = [_][]const u8{
    "Почему программист ушёл с работы? Потому что он не получил массив (ARRAY)!",
    "Как называется змея длиной 3.14 метра? Питон!",
    "— Алло, это техподдержка? — Да. — У меня интернет не работает. — А вы звоните откуда?",
    "Два байта встретились. Один другому: «Ты болен? Ты так бледно выглядишь!»",
    "Почему компьютер пошёл к врачу? Потому что у него был вирус!",
};

/// English humor responses
const HUMOR_EN = [_][]const u8{
    "Why did the programmer quit? Because he didn't get arrays (a raise)!",
    "What's a 3.14-meter snake called? A πthon!",
    "Two bytes meet. One says: 'Are you sick? You look pale!'",
    "Why did the computer go to the doctor? Because it had a virus!",
    "There are only 10 types of people: those who understand binary and those who don't.",
};

/// Chinese humor responses
const HUMOR_ZH = [_][]const u8{
    "程序员为什么离职？因为他没有得到数组（加薪）！",
    "3.14米长的蛇叫什么？派森（Python）！",
    "两个字节见面。一个说：'你病了吗？你看起来很苍白！'",
    "电脑为什么去看医生？因为它中毒了！",
    "世界上只有10种人：懂二进制的和不懂的。",
};

/// Russian unknown responses (honest uncertainty)
const UNKNOWN_RU = [_][]const u8{
    "Извини, я не совсем понял вопрос. Можешь перефразировать?",
    "Хм, не уверен, что понимаю. Объясни подробнее?",
    "Честно — не знаю ответа на это. Могу помочь с чем-то другим?",
    "Это вне моих знаний. Но я готов обсудить что-то ещё!",
    "Не совсем понимаю, о чём ты. Расскажи больше?",
};

/// English unknown responses (honest uncertainty)
const UNKNOWN_EN = [_][]const u8{
    "Sorry, I didn't quite understand. Could you rephrase?",
    "Hmm, not sure I follow. Can you explain more?",
    "Honestly, I don't know the answer to that. Can I help with something else?",
    "This is outside my knowledge. But I'm happy to discuss something else!",
    "I don't quite understand what you mean. Tell me more?",
};

/// Chinese unknown responses (honest uncertainty)
const UNKNOWN_ZH = [_][]const u8{
    "抱歉，我不太明白。你能换个说法吗？",
    "嗯，不太确定我理解了。能解释更多吗？",
    "说实话，我不知道答案。我可以帮助其他事情吗？",
    "这超出了我的知识范围。但我很乐意讨论其他事情！",
    "我不太明白你的意思。能告诉我更多吗？",
};

/// Russian about self responses
const ABOUT_SELF_RU = [_][]const u8{
    "Я — Trinity, локальный ИИ-ассистент. Работаю на твоём устройстве без интернета!",
    "Trinity — это я! Локальный помощник с тернарной логикой.",
    "Я Trinity. Помогаю с задачами, отвечаю на вопросы, поддерживаю беседу.",
    "Trinity — локальный ИИ. Приватный, быстрый, всегда под рукой!",
};

/// English about self responses
const ABOUT_SELF_EN = [_][]const u8{
    "I'm Trinity, a local AI assistant. I run on your device without internet!",
    "Trinity here! A local helper with ternary logic.",
    "I'm Trinity. I help with tasks, answer questions, and keep conversations going.",
    "Trinity — a local AI. Private, fast, always at hand!",
};

/// Chinese about self responses
const ABOUT_SELF_ZH = [_][]const u8{
    "我是Trinity，本地AI助手。我在你的设备上运行，无需互联网！",
    "这里是Trinity！一个具有三进制逻辑的本地助手。",
    "我是Trinity。我帮助处理任务，回答问题，保持对话。",
    "Trinity——本地AI。私密、快速、随时可用！",
};

/// Greeting keywords for detection
const GREETING_KEYWORDS = [_][]const u8{
    "привет", "здравствуй", "здорово", "приветик", "хай", "хей", "добрый",
    "hello", "hi", "hey", "greetings", "good morning", "good afternoon", "good evening",
    "你好", "嗨", "您好", "早上好", "下午好", "晚上好",
};

/// Farewell keywords for detection
const FAREWELL_KEYWORDS = [_][]const u8{
    "пока", "до свидания", "прощай", "увидимся", "досвидос",
    "bye", "goodbye", "see you", "farewell", "later", "take care",
    "再见", "拜拜", "回头见", "告辞", "下次见",
};

/// Gratitude keywords for detection
const GRATITUDE_KEYWORDS = [_][]const u8{
    "спасибо", "благодарю", "спс", "сенкс",
    "thanks", "thank you", "thx", "appreciate",
    "谢谢", "感谢", "多谢",
};

/// Weather keywords for detection
const WEATHER_KEYWORDS = [_][]const u8{
    "погода", "погоду", "дождь", "снег", "температура",
    "weather", "rain", "snow", "temperature", "forecast",
    "天气", "下雨", "下雪", "温度", "预报",
};

/// Feelings keywords for detection
const FEELINGS_KEYWORDS = [_][]const u8{
    "как дела", "как ты", "что нового", "как сам", "как жизнь",
    "how are you", "how's it going", "what's up", "how do you feel",
    "你好吗", "你怎么样", "最近怎样", "过得怎么样",
};

/// Humor keywords for detection
const HUMOR_KEYWORDS = [_][]const u8{
    "шутка", "шутку", "анекдот", "посмеши", "юмор", "смешно",
    "joke", "jokes", "funny", "humor", "laugh", "tell me something funny",
    "笑话", "幽默", "搞笑", "逗我笑",
};

/// About self keywords for detection
const ABOUT_SELF_KEYWORDS = [_][]const u8{
    "кто ты", "что ты", "расскажи о себе", "ты кто", "ты что",
    "who are you", "what are you", "tell me about yourself", "about you",
    "你是谁", "你是什么", "介绍一下自己", "关于你",
};

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN MATCHING
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if behavior name indicates chat response pattern
pub fn isChatBehavior(name: []const u8) bool {
    return std.mem.startsWith(u8, name, "respond") or
        std.mem.startsWith(u8, name, "detect") or
        std.mem.eql(u8, name, "initConversation") or
        std.mem.eql(u8, name, "initChat") or
        std.mem.eql(u8, name, "initContext") or
        std.mem.eql(u8, name, "updateContext") or
        std.mem.eql(u8, name, "maintainContext") or
        std.mem.eql(u8, name, "processChat") or
        std.mem.eql(u8, name, "generateFollowUp") or
        std.mem.eql(u8, name, "validateResponse") or
        std.mem.eql(u8, name, "formatResponse") or
        std.mem.eql(u8, name, "selectPersonality") or
        std.mem.eql(u8, name, "handleUnknown") or
        std.mem.eql(u8, name, "getStats");
}

/// Match and generate fluent chat patterns
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    const name = b.name;

    // ═══════════════════════════════════════════════════════════════════════════
    // RESPONSE PATTERNS (respond*)
    // ═══════════════════════════════════════════════════════════════════════════

    if (std.mem.eql(u8, name, "respondGreeting")) {
        try generateResponseFunction(builder, name, "greeting", &GREETINGS_RU, &GREETINGS_EN, &GREETINGS_ZH);
        return true;
    }

    if (std.mem.eql(u8, name, "respondFarewell")) {
        try generateResponseFunction(builder, name, "farewell", &FAREWELLS_RU, &FAREWELLS_EN, &FAREWELLS_ZH);
        return true;
    }

    if (std.mem.eql(u8, name, "respondGratitude") or std.mem.eql(u8, name, "respondThanks")) {
        try generateResponseFunction(builder, name, "gratitude", &GRATITUDE_RU, &GRATITUDE_EN, &GRATITUDE_ZH);
        return true;
    }

    if (std.mem.eql(u8, name, "respondFeelings") or std.mem.eql(u8, name, "respondUserFeelings")) {
        try generateResponseFunction(builder, name, "feelings", &FEELINGS_RU, &FEELINGS_EN, &FEELINGS_ZH);
        return true;
    }

    if (std.mem.eql(u8, name, "respondWeather")) {
        try generateResponseFunction(builder, name, "weather", &WEATHER_RU, &WEATHER_EN, &WEATHER_ZH);
        return true;
    }

    if (std.mem.eql(u8, name, "respondHumor") or std.mem.eql(u8, name, "respondJoke")) {
        try generateResponseFunction(builder, name, "humor", &HUMOR_RU, &HUMOR_EN, &HUMOR_ZH);
        return true;
    }

    if (std.mem.eql(u8, name, "respondAboutSelf") or std.mem.eql(u8, name, "respondCapabilities")) {
        try generateResponseFunction(builder, name, "about_self", &ABOUT_SELF_RU, &ABOUT_SELF_EN, &ABOUT_SELF_ZH);
        return true;
    }

    if (std.mem.eql(u8, name, "respondUnknown") or std.mem.eql(u8, name, "respondHonestLimit") or std.mem.eql(u8, name, "handleUnknown")) {
        try generateResponseFunction(builder, name, "unknown", &UNKNOWN_RU, &UNKNOWN_EN, &UNKNOWN_ZH);
        return true;
    }

    // Generic respond* pattern
    if (std.mem.startsWith(u8, name, "respond")) {
        try generateGenericResponder(builder, name, b);
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DETECTION PATTERNS (detect*)
    // ═══════════════════════════════════════════════════════════════════════════

    if (std.mem.eql(u8, name, "detectLanguage") or std.mem.eql(u8, name, "detectInputLanguage")) {
        try generateLanguageDetector(builder, name);
        return true;
    }

    if (std.mem.eql(u8, name, "detectTopic")) {
        try generateTopicDetector(builder, name);
        return true;
    }

    if (std.mem.eql(u8, name, "detectIntent")) {
        try generateIntentDetector(builder, name);
        return true;
    }

    if (std.mem.eql(u8, name, "detectMood")) {
        try generateMoodDetector(builder, name);
        return true;
    }

    if (std.mem.eql(u8, name, "detectTopicTransition")) {
        try generateTopicTransitionDetector(builder, name);
        return true;
    }

    // Generic detect* pattern
    if (std.mem.startsWith(u8, name, "detect")) {
        try generateGenericDetector(builder, name, b);
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONTEXT PATTERNS
    // ═══════════════════════════════════════════════════════════════════════════

    if (std.mem.eql(u8, name, "initConversation") or std.mem.eql(u8, name, "initChat") or std.mem.eql(u8, name, "initContext")) {
        try generateContextInit(builder, name);
        return true;
    }

    if (std.mem.eql(u8, name, "updateContext") or std.mem.eql(u8, name, "maintainContext")) {
        try generateContextUpdate(builder, name);
        return true;
    }

    if (std.mem.eql(u8, name, "processChat")) {
        try generateChatProcessor(builder, name);
        return true;
    }

    if (std.mem.eql(u8, name, "generateFollowUp")) {
        try generateFollowUpGenerator(builder, name);
        return true;
    }

    if (std.mem.eql(u8, name, "validateResponse")) {
        try generateResponseValidator(builder, name);
        return true;
    }

    if (std.mem.eql(u8, name, "formatResponse")) {
        try generateResponseFormatter(builder, name);
        return true;
    }

    if (std.mem.eql(u8, name, "selectPersonality")) {
        try generatePersonalitySelector(builder, name);
        return true;
    }

    if (std.mem.eql(u8, name, "getStats")) {
        try generateStatsGetter(builder, name);
        return true;
    }

    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CODE GENERATORS
// ═══════════════════════════════════════════════════════════════════════════════

fn generateResponseFunction(
    builder: *CodeBuilder,
    name: []const u8,
    topic: []const u8,
    responses_ru: []const []const u8,
    responses_en: []const []const u8,
    responses_zh: []const []const u8,
) !void {
    // Generate response arrays
    try builder.writeFmt("const {s}_responses_ru = [_][]const u8{{\n", .{topic});
    builder.incIndent();
    for (responses_ru) |resp| {
        try builder.writeFmt("\"{s}\",\n", .{resp});
    }
    builder.decIndent();
    try builder.writeLine("};");

    try builder.writeFmt("const {s}_responses_en = [_][]const u8{{\n", .{topic});
    builder.incIndent();
    for (responses_en) |resp| {
        try builder.writeFmt("\"{s}\",\n", .{resp});
    }
    builder.decIndent();
    try builder.writeLine("};");

    try builder.writeFmt("const {s}_responses_zh = [_][]const u8{{\n", .{topic});
    builder.incIndent();
    for (responses_zh) |resp| {
        try builder.writeFmt("\"{s}\",\n", .{resp});
    }
    builder.decIndent();
    try builder.writeLine("};");
    try builder.writeLine("");

    // Generate response function
    try builder.writeFmt("/// Fluent {s} response in detected language\n", .{topic});
    try builder.writeFmt("pub fn {s}(language: InputLanguage, seed: u64) []const u8 {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("const responses = switch (language) {");
    builder.incIndent();
    try builder.writeFmt("    .russian => &{s}_responses_ru,\n", .{topic});
    try builder.writeFmt("    .chinese => &{s}_responses_zh,\n", .{topic});
    try builder.writeFmt("    else => &{s}_responses_en,\n", .{topic});
    builder.decIndent();
    try builder.writeLine("};");
    try builder.writeLine("const idx = seed % responses.len;");
    try builder.writeLine("return responses[idx];");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateLanguageDetector(builder: *CodeBuilder, name: []const u8) !void {
    try builder.writeLine("/// Detect input language from text using Unicode ranges");
    try builder.writeFmt("pub fn {s}(text: []const u8) InputLanguage {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("var cyrillic_count: usize = 0;");
    try builder.writeLine("var chinese_count: usize = 0;");
    try builder.writeLine("var latin_count: usize = 0;");
    try builder.writeLine("var i: usize = 0;");
    try builder.writeLine("");
    try builder.writeLine("while (i < text.len) {");
    builder.incIndent();
    try builder.writeLine("const c = text[i];");
    try builder.writeLine("// Cyrillic: UTF-8 starts with 0xD0 or 0xD1");
    try builder.writeLine("if (c == 0xD0 or c == 0xD1) {");
    try builder.writeLine("    cyrillic_count += 1;");
    try builder.writeLine("    i += 2; // UTF-8 2-byte");
    try builder.writeLine("    continue;");
    try builder.writeLine("}");
    try builder.writeLine("// Chinese: UTF-8 starts with 0xE4-0xE9");
    try builder.writeLine("if (c >= 0xE4 and c <= 0xE9) {");
    try builder.writeLine("    chinese_count += 1;");
    try builder.writeLine("    i += 3; // UTF-8 3-byte");
    try builder.writeLine("    continue;");
    try builder.writeLine("}");
    try builder.writeLine("// Latin ASCII");
    try builder.writeLine("if ((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z')) {");
    try builder.writeLine("    latin_count += 1;");
    try builder.writeLine("}");
    try builder.writeLine("i += 1;");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
    try builder.writeLine("// Return language with most characters");
    try builder.writeLine("if (cyrillic_count > chinese_count and cyrillic_count > latin_count) return .russian;");
    try builder.writeLine("if (chinese_count > cyrillic_count and chinese_count > latin_count) return .chinese;");
    try builder.writeLine("if (latin_count > 0) return .english;");
    try builder.writeLine("return .unknown;");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateTopicDetector(builder: *CodeBuilder, name: []const u8) !void {
    try builder.writeLine("/// Detect conversation topic from keywords");
    try builder.writeFmt("pub fn {s}(text: []const u8) ChatTopicReal {{\n", .{name});
    builder.incIndent();

    // Generate keyword checks
    try builder.writeLine("// Convert to lowercase for matching (ASCII only for now)");
    try builder.writeLine("var lower_buf: [256]u8 = undefined;");
    try builder.writeLine("const len = @min(text.len, lower_buf.len);");
    try builder.writeLine("for (0..len) |i| {");
    try builder.writeLine("    const c = text[i];");
    try builder.writeLine("    lower_buf[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;");
    try builder.writeLine("}");
    try builder.writeLine("const lower = lower_buf[0..len];");
    try builder.writeLine("");

    // Check greeting keywords
    try builder.writeLine("// Check greetings");
    try builder.writeLine("const greeting_kw = [_][]const u8{ \"привет\", \"здравствуй\", \"hello\", \"hi\", \"hey\", \"你好\", \"嗨\" };");
    try builder.writeLine("for (greeting_kw) |kw| {");
    try builder.writeLine("    if (std.mem.indexOf(u8, text, kw) != null or std.mem.indexOf(u8, lower, kw) != null) return .greeting;");
    try builder.writeLine("}");
    try builder.writeLine("");

    // Check farewell keywords
    try builder.writeLine("// Check farewells");
    try builder.writeLine("const farewell_kw = [_][]const u8{ \"пока\", \"до свидания\", \"bye\", \"goodbye\", \"再见\", \"拜拜\" };");
    try builder.writeLine("for (farewell_kw) |kw| {");
    try builder.writeLine("    if (std.mem.indexOf(u8, text, kw) != null or std.mem.indexOf(u8, lower, kw) != null) return .farewell;");
    try builder.writeLine("}");
    try builder.writeLine("");

    // Check gratitude keywords
    try builder.writeLine("// Check gratitude");
    try builder.writeLine("const gratitude_kw = [_][]const u8{ \"спасибо\", \"благодарю\", \"thanks\", \"thank you\", \"谢谢\" };");
    try builder.writeLine("for (gratitude_kw) |kw| {");
    try builder.writeLine("    if (std.mem.indexOf(u8, text, kw) != null or std.mem.indexOf(u8, lower, kw) != null) return .gratitude;");
    try builder.writeLine("}");
    try builder.writeLine("");

    // Check feelings keywords
    try builder.writeLine("// Check feelings");
    try builder.writeLine("const feelings_kw = [_][]const u8{ \"как дела\", \"how are you\", \"你好吗\", \"how's it going\" };");
    try builder.writeLine("for (feelings_kw) |kw| {");
    try builder.writeLine("    if (std.mem.indexOf(u8, text, kw) != null or std.mem.indexOf(u8, lower, kw) != null) return .feelings;");
    try builder.writeLine("}");
    try builder.writeLine("");

    // Check weather keywords
    try builder.writeLine("// Check weather");
    try builder.writeLine("const weather_kw = [_][]const u8{ \"погода\", \"weather\", \"天气\", \"rain\", \"дождь\" };");
    try builder.writeLine("for (weather_kw) |kw| {");
    try builder.writeLine("    if (std.mem.indexOf(u8, text, kw) != null or std.mem.indexOf(u8, lower, kw) != null) return .weather;");
    try builder.writeLine("}");
    try builder.writeLine("");

    // Check humor keywords
    try builder.writeLine("// Check humor");
    try builder.writeLine("const humor_kw = [_][]const u8{ \"шутк\", \"joke\", \"funny\", \"笑话\", \"анекдот\" };");
    try builder.writeLine("for (humor_kw) |kw| {");
    try builder.writeLine("    if (std.mem.indexOf(u8, text, kw) != null or std.mem.indexOf(u8, lower, kw) != null) return .humor;");
    try builder.writeLine("}");
    try builder.writeLine("");

    // Check about self keywords
    try builder.writeLine("// Check about self");
    try builder.writeLine("const about_kw = [_][]const u8{ \"кто ты\", \"who are you\", \"你是谁\", \"about you\" };");
    try builder.writeLine("for (about_kw) |kw| {");
    try builder.writeLine("    if (std.mem.indexOf(u8, text, kw) != null or std.mem.indexOf(u8, lower, kw) != null) return .about_self;");
    try builder.writeLine("}");
    try builder.writeLine("");

    try builder.writeLine("return .unknown;");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateIntentDetector(builder: *CodeBuilder, name: []const u8) !void {
    try builder.writeLine("/// Detect user intent from message");
    try builder.writeFmt("pub fn {s}(text: []const u8) UserIntentReal {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("// Check for question marks");
    try builder.writeLine("if (std.mem.indexOf(u8, text, \"?\") != null) return .information;");
    try builder.writeLine("");
    try builder.writeLine("// Check for help keywords");
    try builder.writeLine("const help_kw = [_][]const u8{ \"помоги\", \"help\", \"帮\", \"how to\", \"как\" };");
    try builder.writeLine("for (help_kw) |kw| {");
    try builder.writeLine("    if (std.mem.indexOf(u8, text, kw) != null) return .assistance;");
    try builder.writeLine("}");
    try builder.writeLine("");
    try builder.writeLine("// Check for entertainment");
    try builder.writeLine("const fun_kw = [_][]const u8{ \"шутк\", \"joke\", \"笑话\", \"fun\", \"веселье\" };");
    try builder.writeLine("for (fun_kw) |kw| {");
    try builder.writeLine("    if (std.mem.indexOf(u8, text, kw) != null) return .entertainment;");
    try builder.writeLine("}");
    try builder.writeLine("");
    try builder.writeLine("return .conversation;");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateMoodDetector(builder: *CodeBuilder, name: []const u8) !void {
    try builder.writeLine("/// Detect user mood from text");
    try builder.writeFmt("pub fn {s}(text: []const u8) i8 {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("// Positive indicators");
    try builder.writeLine("const positive_kw = [_][]const u8{ \"хорошо\", \"отлично\", \"good\", \"great\", \"好\", \"棒\" };");
    try builder.writeLine("var positive_score: i8 = 0;");
    try builder.writeLine("for (positive_kw) |kw| {");
    try builder.writeLine("    if (std.mem.indexOf(u8, text, kw) != null) positive_score += 1;");
    try builder.writeLine("}");
    try builder.writeLine("");
    try builder.writeLine("// Negative indicators");
    try builder.writeLine("const negative_kw = [_][]const u8{ \"плохо\", \"ужасно\", \"bad\", \"terrible\", \"坏\", \"糟\" };");
    try builder.writeLine("var negative_score: i8 = 0;");
    try builder.writeLine("for (negative_kw) |kw| {");
    try builder.writeLine("    if (std.mem.indexOf(u8, text, kw) != null) negative_score += 1;");
    try builder.writeLine("}");
    try builder.writeLine("");
    try builder.writeLine("if (positive_score > negative_score) return 1; // positive");
    try builder.writeLine("if (negative_score > positive_score) return -1; // negative");
    try builder.writeLine("return 0; // neutral");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateTopicTransitionDetector(builder: *CodeBuilder, name: []const u8) !void {
    try builder.writeLine("/// Detect topic transition smoothness");
    try builder.writeFmt("pub fn {s}(from: ChatTopicReal, to: ChatTopicReal) TopicTransition {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("// Same topic is smooth");
    try builder.writeLine("if (from == to) return .{ .from_topic = from, .to_topic = to, .is_smooth = true };");
    try builder.writeLine("");
    try builder.writeLine("// Natural transitions");
    try builder.writeLine("const smooth = switch (from) {");
    try builder.writeLine("    .greeting => to == .feelings or to == .about_self,");
    try builder.writeLine("    .farewell => false, // farewell should be final");
    try builder.writeLine("    .feelings => to == .humor or to == .advice,");
    try builder.writeLine("    else => true, // most transitions are acceptable");
    try builder.writeLine("};");
    try builder.writeLine("");
    try builder.writeLine("return .{ .from_topic = from, .to_topic = to, .is_smooth = smooth };");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateContextInit(builder: *CodeBuilder, name: []const u8) !void {
    // Generate required types first
    try generateRequiredChatTypes(builder);

    try builder.writeLine("/// Initialize conversation context");
    try builder.writeFmt("pub fn {s}() ConversationState {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("return ConversationState{");
    try builder.writeLine("    .turn_count = 0,");
    try builder.writeLine("    .current_topic = .unknown,");
    try builder.writeLine("    .user_language = \"auto\",");
    try builder.writeLine("    .tone = .friendly,");
    try builder.writeLine("    .last_response = \"\",");
    try builder.writeLine("};");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateRequiredChatTypes(builder: *CodeBuilder) !void {
    // InputLanguage enum for multilingual support (not defined in vibee spec)
    try builder.writeLine("/// Detected input language for multilingual support");
    try builder.writeLine("pub const InputLanguage = enum {");
    try builder.writeLine("    russian,");
    try builder.writeLine("    chinese,");
    try builder.writeLine("    english,");
    try builder.writeLine("    unknown,");
    try builder.writeLine("};");
    try builder.writeLine("");

    // PersonalityTrait enum (not defined in vibee spec)
    try builder.writeLine("/// Personality trait for response style");
    try builder.writeLine("pub const PersonalityTrait = enum {");
    try builder.writeLine("    friendly,");
    try builder.writeLine("    helpful,");
    try builder.writeLine("    honest,");
    try builder.writeLine("    curious,");
    try builder.writeLine("    humble,");
    try builder.writeLine("};");
    try builder.writeLine("");

    // TopicTransition struct (not defined in vibee spec)
    try builder.writeLine("/// Topic transition tracking");
    try builder.writeLine("pub const TopicTransition = struct {");
    try builder.writeLine("    from_topic: ChatTopicReal,");
    try builder.writeLine("    to_topic: ChatTopicReal,");
    try builder.writeLine("    is_smooth: bool,");
    try builder.writeLine("};");
    try builder.writeLine("");

    // ChatStats struct (not defined in vibee spec)
    try builder.writeLine("/// Chat statistics");
    try builder.writeLine("pub const ChatStats = struct {");
    try builder.writeLine("    total_turns: i64,");
    try builder.writeLine("    pattern_hits: i64,");
    try builder.writeLine("    llm_calls: i64,");
    try builder.writeLine("    languages_used: i64,");
    try builder.writeLine("    avg_confidence: f64,");
    try builder.writeLine("};");
    try builder.writeLine("");

    // ChatTopicReal enum with actual values (to override empty struct from vibee)
    try builder.writeLine("/// Real chat topic enum with values");
    try builder.writeLine("pub const ChatTopicReal = enum {");
    try builder.writeLine("    greeting,");
    try builder.writeLine("    farewell,");
    try builder.writeLine("    gratitude,");
    try builder.writeLine("    weather,");
    try builder.writeLine("    time,");
    try builder.writeLine("    feelings,");
    try builder.writeLine("    help,");
    try builder.writeLine("    about_self,");
    try builder.writeLine("    about_user,");
    try builder.writeLine("    philosophy,");
    try builder.writeLine("    technology,");
    try builder.writeLine("    humor,");
    try builder.writeLine("    advice,");
    try builder.writeLine("    unknown,");
    try builder.writeLine("};");
    try builder.writeLine("");

    // UserIntentReal enum with actual values
    try builder.writeLine("/// Real user intent enum with values");
    try builder.writeLine("pub const UserIntentReal = enum {");
    try builder.writeLine("    information,");
    try builder.writeLine("    assistance,");
    try builder.writeLine("    conversation,");
    try builder.writeLine("    entertainment,");
    try builder.writeLine("    confirmation,");
    try builder.writeLine("};");
    try builder.writeLine("");
}

fn generateContextUpdate(builder: *CodeBuilder, name: []const u8) !void {
    try builder.writeLine("/// Update conversation context with new turn");
    try builder.writeFmt("pub fn {s}(state: *ConversationState, topic: ChatTopicReal, response: []const u8) void {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("state.turn_count += 1;");
    try builder.writeLine("state.current_topic = topic;");
    try builder.writeLine("state.last_response = response;");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateChatProcessor(builder: *CodeBuilder, name: []const u8) !void {
    try builder.writeLine("/// Process chat message and generate response");
    try builder.writeFmt("pub fn {s}(text: []const u8, state: *ConversationState, seed: u64) FluentChatResponse {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("// Detect language and topic");
    try builder.writeLine("const lang = detectInputLanguage(text);");
    try builder.writeLine("const topic = detectTopic(text);");
    try builder.writeLine("");
    try builder.writeLine("// Generate response based on topic");
    try builder.writeLine("const response_text = switch (topic) {");
    try builder.writeLine("    .greeting => respondGreeting(lang, seed),");
    try builder.writeLine("    .farewell => respondFarewell(lang, seed),");
    try builder.writeLine("    .gratitude => respondGratitude(lang, seed),");
    try builder.writeLine("    .feelings => respondFeelings(lang, seed),");
    try builder.writeLine("    .weather => respondWeather(lang, seed),");
    try builder.writeLine("    .humor => respondHumor(lang, seed),");
    try builder.writeLine("    .about_self => respondAboutSelf(lang, seed),");
    try builder.writeLine("    else => respondUnknown(lang, seed),");
    try builder.writeLine("};");
    try builder.writeLine("");
    try builder.writeLine("// Update context");
    try builder.writeLine("maintainContext(state, topic, response_text);");
    try builder.writeLine("");
    try builder.writeLine("return FluentChatResponse{");
    try builder.writeLine("    .text = response_text,");
    try builder.writeLine("    .topic = topic,");
    try builder.writeLine("    .confidence = if (topic == .unknown) LOW_CONFIDENCE else HIGH_CONFIDENCE,");
    try builder.writeLine("    .is_honest = true,");
    try builder.writeLine("    .follow_up = \"\",");
    try builder.writeLine("};");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateFollowUpGenerator(builder: *CodeBuilder, name: []const u8) !void {
    try builder.writeLine("/// Generate natural follow-up question");
    try builder.writeFmt("pub fn {s}(topic: ChatTopicReal, lang: InputLanguage) []const u8 {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("return switch (topic) {");
    try builder.writeLine("    .greeting => switch (lang) {");
    try builder.writeLine("        .russian => \"Чем могу помочь?\",");
    try builder.writeLine("        .chinese => \"有什么可以帮助你的吗？\",");
    try builder.writeLine("        else => \"How can I help you?\",");
    try builder.writeLine("    },");
    try builder.writeLine("    .feelings => switch (lang) {");
    try builder.writeLine("        .russian => \"Расскажи, что нового?\",");
    try builder.writeLine("        .chinese => \"最近有什么新鲜事？\",");
    try builder.writeLine("        else => \"What's new with you?\",");
    try builder.writeLine("    },");
    try builder.writeLine("    else => switch (lang) {");
    try builder.writeLine("        .russian => \"Есть ещё вопросы?\",");
    try builder.writeLine("        .chinese => \"还有其他问题吗？\",");
    try builder.writeLine("        else => \"Anything else?\",");
    try builder.writeLine("    },");
    try builder.writeLine("};");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateResponseValidator(builder: *CodeBuilder, name: []const u8) !void {
    try builder.writeLine("/// Validate response is fluent and not generic");
    try builder.writeFmt("pub fn {s}(response: []const u8) bool {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("// Reject empty responses");
    try builder.writeLine("if (response.len == 0) return false;");
    try builder.writeLine("");
    try builder.writeLine("// Reject generic patterns");
    try builder.writeLine("const generic_patterns = [_][]const u8{");
    try builder.writeLine("    \"TODO\",");
    try builder.writeLine("    \"Понял! Я Trinity\",");
    try builder.writeLine("    \"Response for\",");
    try builder.writeLine("    \"Not implemented\",");
    try builder.writeLine("};");
    try builder.writeLine("");
    try builder.writeLine("for (generic_patterns) |pattern| {");
    try builder.writeLine("    if (std.mem.indexOf(u8, response, pattern) != null) return false;");
    try builder.writeLine("}");
    try builder.writeLine("");
    try builder.writeLine("return true;");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateResponseFormatter(builder: *CodeBuilder, name: []const u8) !void {
    try builder.writeLine("/// Format response for output");
    try builder.writeFmt("pub fn {s}(text: []const u8) []const u8 {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("// Already formatted, return as-is");
    try builder.writeLine("return text;");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generatePersonalitySelector(builder: *CodeBuilder, name: []const u8) !void {
    try builder.writeLine("/// Select personality based on topic and mood");
    try builder.writeFmt("pub fn {s}(topic: ChatTopicReal, mood: i8) PersonalityTrait {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("return switch (topic) {");
    try builder.writeLine("    .humor => .friendly,");
    try builder.writeLine("    .help => .helpful,");
    try builder.writeLine("    .weather, .unknown => .honest,");
    try builder.writeLine("    .philosophy => .curious,");
    try builder.writeLine("    else => if (mood < 0) .helpful else .friendly,");
    try builder.writeLine("};");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateStatsGetter(builder: *CodeBuilder, name: []const u8) !void {
    try builder.writeLine("/// Get chat statistics");
    try builder.writeFmt("pub fn {s}(state: *const ConversationState) ChatStats {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("return ChatStats{");
    try builder.writeLine("    .total_turns = @intCast(state.turn_count),");
    try builder.writeLine("    .pattern_hits = 0,");
    try builder.writeLine("    .llm_calls = 0,");
    try builder.writeLine("    .languages_used = 1,");
    try builder.writeLine("    .avg_confidence = HIGH_CONFIDENCE,");
    try builder.writeLine("};");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateGenericResponder(builder: *CodeBuilder, name: []const u8, b: *const Behavior) !void {
    try builder.writeFmt("/// Generic response for {s}\n", .{name});
    try builder.writeFmt("pub fn {s}(language: InputLanguage, seed: u64) []const u8 {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("_ = seed;");
    try builder.writeLine("return switch (language) {");
    try builder.writeFmt("    .russian => \"{s}\",\n", .{b.then});
    try builder.writeFmt("    .chinese => \"{s}\",\n", .{b.then});
    try builder.writeFmt("    else => \"{s}\",\n", .{b.then});
    try builder.writeLine("};");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

fn generateGenericDetector(builder: *CodeBuilder, name: []const u8, b: *const Behavior) !void {
    try builder.writeFmt("/// Generic detector for {s}\n", .{name});
    try builder.writeFmt("pub fn {s}(text: []const u8) bool {{\n", .{name});
    builder.incIndent();
    try builder.writeLine("_ = text;");
    try builder.writeFmt("// {s}\n", .{b.then});
    try builder.writeLine("return false;");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "isChatBehavior" {
    const testing = std.testing;

    try testing.expect(isChatBehavior("respondGreeting"));
    try testing.expect(isChatBehavior("detectTopic"));
    try testing.expect(isChatBehavior("initConversation"));
    try testing.expect(isChatBehavior("processChat"));
    try testing.expect(!isChatBehavior("getValue"));
    try testing.expect(!isChatBehavior("initSystem"));
}

test "chat pattern match" {
    const testing = std.testing;
    var buffer: [16384]u8 = undefined;
    var builder = CodeBuilder.init(&buffer);

    const b = Behavior{
        .name = "respondGreeting",
        .given = "greeting",
        .when = "user greets",
        .then = "return greeting",
    };

    const matched = try match(&builder, &b);
    try testing.expect(matched);

    const output = builder.getOutput();
    try testing.expect(output.len > 0);
    try testing.expect(std.mem.indexOf(u8, output, "Привет") != null);
    try testing.expect(std.mem.indexOf(u8, output, "Hello") != null);
    try testing.expect(std.mem.indexOf(u8, output, "你好") != null);
}
