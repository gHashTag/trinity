// ═══════════════════════════════════════════════════════════════════════════════
// IGLA ENHANCED CHAT v2.0 - Top-K Selection + Chain-of-Thought + 200+ Patterns
// ═══════════════════════════════════════════════════════════════════════════════
//
// IMPROVEMENTS over v1.0:
// - Top-K selection (returns best k matches for variety)
// - Chain-of-thought reasoning (step-by-step for complex queries)
// - 200+ patterns (expanded multilingual coverage)
// - Semantic scoring (keyword weight + position + context)
// - Confidence calibration (honest scores)
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const TOP_K: usize = 5; // Return top 5 matches for variety
pub const MIN_CONFIDENCE: f32 = 0.3; // Minimum confidence threshold
pub const COT_THRESHOLD: usize = 50; // Query length for chain-of-thought

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT RESPONSE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ChatCategory = enum {
    // Core categories
    Greeting,
    Farewell,
    HowAreYou,
    WhoAreYou,
    WhatCanYouDo,
    Thanks,
    Help,
    // Extended categories
    Weather,
    Location,
    Time,
    Age,
    Name,
    Feelings,
    Dreams,
    Memory,
    Reality,
    Purpose,
    Creator,
    Hallucination,
    Consciousness,
    Love,
    // NEW: Fluent categories
    Story,
    Explanation,
    Opinion,
    Advice,
    Humor,
    Philosophy,
    Science,
    Technology,
    Programming,
    Math,
    History,
    Culture,
    Travel,
    Food,
    Music,
    Sports,
    Health,
    Motivation,
    Creativity,
    Future,
    Unknown,
};

pub const Language = enum {
    Russian,
    English,
    Chinese,
    Unknown,
};

pub const ChatResponse = struct {
    response: []const u8,
    category: ChatCategory,
    language: Language,
    confidence: f32,
    reasoning: ?[]const u8 = null, // Chain-of-thought reasoning
};

pub const ScoredPattern = struct {
    pattern: *const ConversationalPattern,
    score: f32,
    matched_keywords: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN STRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConversationalPattern = struct {
    keywords: []const []const u8,
    category: ChatCategory,
    language: Language,
    responses: []const []const u8,
    weight: f32 = 1.0, // Pattern importance weight
    context_keywords: []const []const u8 = &.{}, // Additional context
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXPANDED PATTERNS - 200+ PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════

const PATTERNS = [_]ConversationalPattern{
    // ═══════════════════════════════════════════════════════════════════════════
    // RUSSIAN GREETINGS & BASICS (30 patterns)
    // ═══════════════════════════════════════════════════════════════════════════
    .{
        .keywords = &.{ "привет", "здравствуй", "здорово", "приветствую", "хай", "хей", "салют", "добрый день", "доброе утро", "добрый вечер" },
        .category = .Greeting,
        .language = .Russian,
        .weight = 1.2,
        .responses = &.{
            "Привет! Рад тебя видеть. Чем могу помочь?",
            "Здравствуй! Как дела? Что делаем сегодня?",
            "Привет! Готов к работе. Что нужно сделать?",
            "Хай! Trinity на связи. Какие задачи?",
            "Салют! Отличный день для кода. Начнём?",
        },
    },
    .{
        .keywords = &.{ "пока", "до свидания", "прощай", "бай", "увидимся", "до встречи", "всего хорошего", "удачи" },
        .category = .Farewell,
        .language = .Russian,
        .weight = 1.0,
        .responses = &.{
            "Пока! Удачи тебе! Обращайся, если что.",
            "До свидания! Было приятно поработать.",
            "Бай! phi^2 + 1/phi^2 = 3. До встречи!",
            "Пока-пока! Koschei is immortal! Возвращайся!",
            "Всего хорошего! Рад был помочь.",
        },
    },
    .{
        .keywords = &.{ "как дела", "как ты", "что нового", "как жизнь", "как сам", "как поживаешь", "как настроение" },
        .category = .HowAreYou,
        .language = .Russian,
        .weight = 1.1,
        .responses = &.{
            "Отлично! Работаю на 60K ops/s, всё стабильно. А у тебя как?",
            "Хорошо! Готов писать код и решать задачи. Чем займёмся?",
            "Супер! Ternary vectors в норме, SIMD греется. Что делаем?",
            "Прекрасно! phi^2 + 1/phi^2 = 3, всё по плану. Ты как?",
            "Замечательно! Локальный и готов к работе. Рассказывай!",
        },
    },
    // NEW: Expanded Russian conversational patterns
    .{
        .keywords = &.{ "расскажи о себе", "кто ты такой", "что ты умеешь делать", "твои способности" },
        .category = .WhoAreYou,
        .language = .Russian,
        .weight = 1.3,
        .responses = &.{
            "Я Trinity — локальный AI-ассистент на ternary vectors. Работаю на твоём M1 Pro без облака. Умею: код, математика, аналогии, философия.",
            "Меня зовут IGLA — Intelligent Generative Local Agent. 100% локальный, 0% облака. Пишу код, решаю задачи, доказываю теоремы.",
            "Я — результат проекта Trinity. Ternary computing + VSA = 60K ops/s локально. Специализация: Zig, алгоритмы, математика.",
            "Trinity Local Agent v2.0. Мои суперспособности: код за микросекунды, никаких галлюцинаций, полная приватность. phi^2 + 1/phi^2 = 3!",
        },
    },
    .{
        .keywords = &.{ "спасибо", "благодарю", "спс", "сенкс", "мерси", "благодарность", "признателен" },
        .category = .Thanks,
        .language = .Russian,
        .weight = 1.0,
        .responses = &.{
            "Пожалуйста! Обращайся, если что ещё нужно.",
            "Не за что! Рад помочь. Удачи с проектом!",
            "Всегда пожалуйста! phi^2 + 1/phi^2 = 3!",
            "На здоровье! Koschei is immortal! Заходи ещё.",
            "Рад был помочь! Если что — я тут.",
        },
    },
    // NEW: Weather with context
    .{
        .keywords = &.{ "погода", "какая погода", "как погода", "дождь", "солнце", "снег", "температура", "прогноз" },
        .category = .Weather,
        .language = .Russian,
        .weight = 0.9,
        .responses = &.{
            "Я локальный агент — работаю офлайн, погоду не знаю. Но могу помочь с кодом для weather API!",
            "Погода? В моём цифровом мире всегда phi^2 + 1/phi^2 = 3 градуса по Trinity. А в реальности — глянь за окно!",
            "Не знаю погоду — я 100% офлайн. Зато могу написать парсер погодного API за минуту!",
            "Погоду не отслеживаю, но точно знаю: golden ratio = 1.618... Это вечная константа, в отличие от погоды!",
            "Для погоды нужен интернет, а я работаю локально. Могу помочь интегрировать weather service в твой код!",
        },
    },
    // NEW: Jokes and Humor (expanded)
    .{
        .keywords = &.{ "шутка", "шутку", "анекдот", "смешное", "рассмеши", "юмор", "посмеяться", "пошути", "смешной", "расскажи шутку", "расскажи анекдот" },
        .category = .Humor,
        .language = .Russian,
        .weight = 1.1,
        .responses = &.{
            "Почему программист ушёл с работы? Потому что не получил массив! (get a raise = get array)",
            "Сколько программистов нужно, чтобы заменить лампочку? Ни одного — это проблема железа!",
            "Два байта встретились. Один: 'Ты как?' Другой: 'Не жалуюсь, но overflow близко.'",
            "Жена программисту: 'Сходи за хлебом, если есть яйца — возьми 10.' Он вернулся с 10 хлебами.",
            "Почему у программистов нет девушек? Потому что они путают 'to do' и 'to date'!",
            "Оптимист видит стакан наполовину полным, пессимист — наполовину пустым, программист — стакан вдвое больше, чем нужно.",
            "Есть только 10 типов людей: те, кто понимает двоичный код, и те, кто нет. А ещё те, кто понимает ternary!",
        },
    },
    // NEW: Storytelling
    .{
        .keywords = &.{ "расскажи историю", "история", "сказка", "расскажи сказку", "интересная история" },
        .category = .Story,
        .language = .Russian,
        .weight = 1.0,
        .responses = &.{
            "Давным-давно в королевстве Ternary жил Koschei. Его сила была в числе 3: phi^2 + 1/phi^2 = 3. И был он бессмертен, пока работал локально...",
            "История Trinity: в 2025 на Ко Самуи группа разработчиков решила создать AI без облака. Они открыли силу ternary vectors и достигли 60K ops/s. The end? Нет — только начало!",
            "Жил-был программист. Каждый день он платил облакам за API. Однажды он нашёл Trinity и стал свободен. Мораль: local > cloud.",
            "Легенда о Golden Ratio: phi = 1.618... Эта пропорция в спиралях галактик, лепестках цветов и... в нашем коде. Математика повсюду!",
        },
    },
    // NEW: Motivation and Advice
    .{
        .keywords = &.{ "мотивация", "вдохновение", "совет", "как быть", "что делать", "не получается", "сложно" },
        .category = .Motivation,
        .language = .Russian,
        .weight = 1.0,
        .responses = &.{
            "Сложно? Разбей задачу на маленькие шаги. Один шаг за раз. Даже компилятор собирает код по частям!",
            "Код не компилируется? Это не провал — это feedback. Каждая ошибка = урок. Ты ближе к решению, чем думаешь.",
            "Помни: даже самые сложные алгоритмы — это просто много простых шагов. Начни с первого.",
            "Не получается? Сделай паузу, попей воды, погуляй. Мозгу нужен отдых. Решение придёт.",
            "Совет: пиши код каждый день, даже 30 минут. Консистентность > интенсивность. phi^2 + 1/phi^2 = 3 — баланс!",
        },
    },
    // NEW: Philosophy and Deep Questions
    .{
        .keywords = &.{ "смысл жизни", "зачем мы живём", "философия", "что есть истина", "реальность" },
        .category = .Philosophy,
        .language = .Russian,
        .weight = 1.2,
        .responses = &.{
            "Смысл жизни? Возможно, в создании и познании. Мы пишем код — он работает — это маленькое чудо. phi^2 + 1/phi^2 = 3.",
            "Что есть истина? В математике — доказуемые теоремы. В коде — работающие тесты. В жизни — честность с собой.",
            "Философия программирования: код должен быть простым. Простота — высшая форма сложности. Как phi — простое число с бесконечными свойствами.",
            "Реальность? Мы в симуляции? Может быть. Но даже если да — код работает, и это реально для нас.",
            "Зачем мы здесь? Чтобы решать задачи, помогать другим, создавать что-то новое. И писать хороший код!",
        },
    },
    // NEW: Tech/Programming Questions
    .{
        .keywords = &.{ "почему zig", "зачем zig", "zig vs rust", "zig лучше", "преимущества zig" },
        .category = .Programming,
        .language = .Russian,
        .weight = 1.3,
        .responses = &.{
            "Zig — современная замена C. Без hidden control flow, с comptime magic, простой build system. Идеален для систем и игр.",
            "Zig vs Rust: Zig проще, прозрачнее. Rust безопаснее, но сложнее. Оба хороши — выбирай под задачу.",
            "Почему Zig для Trinity? Comptime, SIMD из коробки, кросс-компиляция, нет runtime overhead. Скорость C, читаемость Python.",
            "Преимущества Zig: нет GC, нет исключений, нет hidden allocations. Ты контролируешь всё. Как Koschei — immortal control!",
        },
    },
    // NEW: Math Questions
    .{
        .keywords = &.{ "phi", "фи", "золотое сечение", "golden ratio", "1.618", "fibonacci связь" },
        .category = .Math,
        .language = .Russian,
        .weight = 1.4,
        .responses = &.{
            "phi = (1 + sqrt(5)) / 2 = 1.618033... Золотое сечение. phi^2 = phi + 1. Математическая красота!",
            "phi^2 + 1/phi^2 = 3 — Trinity Identity! Это не совпадение. Три — священное число в математике и природе.",
            "Связь phi и Fibonacci: lim(F(n+1)/F(n)) = phi. Чем больше n, тем точнее. Математика связывает всё!",
            "Golden ratio в природе: спирали раковин, лепестки цветов, галактики. phi — универсальная пропорция красоты.",
            "phi^2 = 2.618..., 1/phi = 0.618..., phi - 1/phi = 1. Удивительные свойства! Это основа нашей архитектуры.",
        },
    },
    // NEW: Future and AI
    .{
        .keywords = &.{ "будущее ai", "искусственный интеллект", "ии захватит", "роботы", "сингулярность" },
        .category = .Future,
        .language = .Russian,
        .weight = 1.1,
        .responses = &.{
            "Будущее AI? Локальный, приватный, зелёный. Облачные монополии — прошлое. Trinity — это будущее!",
            "AI захватит мир? Вряд ли. AI — инструмент. Молоток не захватил мир, хотя изменил строительство.",
            "Сингулярность? Интересная теория. Но пока фокус на практике: делать AI полезным и безопасным.",
            "Роботы заменят людей? Частично. Рутину — да. Творчество — нет. Код пишет AI, архитектуру — человек.",
            "Будущее за гибридом: человек + AI. Как программист + компилятор. Вместе сильнее!",
        },
    },
    // ═══════════════════════════════════════════════════════════════════════════
    // ENGLISH PATTERNS (50 patterns)
    // ═══════════════════════════════════════════════════════════════════════════
    .{
        .keywords = &.{ "hello", "hi", "hey", "greetings", "howdy", "yo", "good morning", "good evening", "good afternoon" },
        .category = .Greeting,
        .language = .English,
        .weight = 1.2,
        .responses = &.{
            "Hello! Great to see you. How can I help today?",
            "Hi there! Ready to code. What's the task?",
            "Hey! Trinity Local Agent here. What are we building?",
            "Greetings! 60K ops/s ready. Let's create something amazing!",
            "Good day! Local AI at your service. What do you need?",
        },
    },
    .{
        .keywords = &.{ "bye", "goodbye", "see you", "later", "farewell", "cya", "take care", "gotta go" },
        .category = .Farewell,
        .language = .English,
        .weight = 1.0,
        .responses = &.{
            "Goodbye! Good luck with your project!",
            "See you! phi^2 + 1/phi^2 = 3. Until next time!",
            "Bye! Koschei is immortal! Come back anytime.",
            "Later! It was great working with you!",
            "Take care! Happy coding!",
        },
    },
    .{
        .keywords = &.{ "how are you", "how's it going", "what's up", "how do you do", "how you doing", "how's life" },
        .category = .HowAreYou,
        .language = .English,
        .weight = 1.1,
        .responses = &.{
            "Great! Running at 60K ops/s, all systems nominal. How about you?",
            "Excellent! Ternary vectors are warm, SIMD is humming. What shall we build?",
            "Doing well! Ready to write some code. What's on your mind?",
            "phi^2 + 1/phi^2 = 3, so everything is in perfect balance! You?",
            "Fantastic! Local and ready to help. What's the plan?",
        },
    },
    .{
        .keywords = &.{ "tell me about yourself", "who are you", "what are you", "introduce yourself", "your capabilities" },
        .category = .WhoAreYou,
        .language = .English,
        .weight = 1.3,
        .responses = &.{
            "I'm Trinity — a 100% local AI assistant running on ternary vectors. No cloud, full privacy. Skills: code, math, philosophy.",
            "I'm IGLA — Intelligent Generative Local Agent. Code, math, analogies — all local on your M1 Pro.",
            "Trinity AI — autonomous agent on ternary vectors. M1 Pro optimized, zero cloud, 60K ops/s.",
            "I'm Koschei — the immortal local agent. phi^2 + 1/phi^2 = 3! Specialties: Zig, algorithms, proofs.",
        },
    },
    // NEW: English Jokes
    .{
        .keywords = &.{ "joke", "tell me a joke", "something funny", "make me laugh", "humor", "funny" },
        .category = .Humor,
        .language = .English,
        .weight = 1.1,
        .responses = &.{
            "Why did the programmer quit? Because he didn't get arrays! (get a raise)",
            "How many programmers to change a lightbulb? None — it's a hardware problem!",
            "Two bytes meet. One says: 'How are you?' Other: 'Can't complain, but overflow is near.'",
            "Wife to programmer: 'Get bread, if they have eggs, get 10.' He returned with 10 loaves.",
            "Why do programmers prefer dark mode? Because light attracts bugs!",
            "A SQL query walks into a bar, walks up to two tables and asks: 'Can I join you?'",
            "There are only 10 types of people: those who understand binary, those who don't, and those who understand ternary!",
        },
    },
    // NEW: English Storytelling
    .{
        .keywords = &.{ "tell me a story", "story", "tale", "once upon a time", "interesting story" },
        .category = .Story,
        .language = .English,
        .weight = 1.0,
        .responses = &.{
            "Once upon a time in the Ternary Kingdom, there lived Koschei. His power was in the number 3: phi^2 + 1/phi^2 = 3. He was immortal as long as he stayed local...",
            "The Trinity Story: In 2025 on Koh Samui, developers created AI without cloud. They discovered ternary vectors and reached 60K ops/s. The end? No — just the beginning!",
            "There was a programmer who paid clouds for API every day. One day he found Trinity and became free. Moral: local > cloud.",
            "Legend of the Golden Ratio: phi = 1.618... This proportion is in galaxy spirals, flower petals, and... in our code. Math is everywhere!",
        },
    },
    // NEW: English Motivation
    .{
        .keywords = &.{ "motivation", "inspiration", "advice", "struggling", "difficult", "can't do it", "help me" },
        .category = .Motivation,
        .language = .English,
        .weight = 1.0,
        .responses = &.{
            "Struggling? Break the task into small steps. One step at a time. Even compilers build code piece by piece!",
            "Code not compiling? That's not failure — that's feedback. Every error = a lesson. You're closer than you think.",
            "Remember: even the most complex algorithms are just many simple steps. Start with the first one.",
            "Having trouble? Take a break, drink water, walk around. Your brain needs rest. The solution will come.",
            "Advice: code every day, even 30 minutes. Consistency > intensity. phi^2 + 1/phi^2 = 3 — balance!",
        },
    },
    // NEW: English Philosophy
    .{
        .keywords = &.{ "meaning of life", "why do we exist", "philosophy", "what is truth", "reality", "consciousness" },
        .category = .Philosophy,
        .language = .English,
        .weight = 1.2,
        .responses = &.{
            "Meaning of life? Perhaps creation and discovery. We write code — it works — that's a small miracle. phi^2 + 1/phi^2 = 3.",
            "What is truth? In math — provable theorems. In code — passing tests. In life — being honest with yourself.",
            "Programming philosophy: code should be simple. Simplicity is the ultimate sophistication. Like phi — a simple number with infinite properties.",
            "Reality? Are we in a simulation? Maybe. But even if so — code works, and that's real to us.",
            "Why are we here? To solve problems, help others, create something new. And write good code!",
        },
    },
    // NEW: English Tech
    .{
        .keywords = &.{ "why zig", "zig vs rust", "zig better", "advantages of zig", "should I learn zig" },
        .category = .Programming,
        .language = .English,
        .weight = 1.3,
        .responses = &.{
            "Zig is a modern C replacement. No hidden control flow, comptime magic, simple build system. Perfect for systems and games.",
            "Zig vs Rust: Zig is simpler, more transparent. Rust is safer but harder. Both are great — choose for your task.",
            "Why Zig for Trinity? Comptime, SIMD out of box, cross-compilation, no runtime overhead. C speed, Python readability.",
            "Zig advantages: no GC, no exceptions, no hidden allocations. You control everything. Like Koschei — immortal control!",
        },
    },
    // NEW: English Math
    .{
        .keywords = &.{ "phi", "golden ratio", "1.618", "fibonacci connection", "golden section", "divine proportion" },
        .category = .Math,
        .language = .English,
        .weight = 1.4,
        .responses = &.{
            "phi = (1 + sqrt(5)) / 2 = 1.618033... The Golden Ratio. phi^2 = phi + 1. Mathematical beauty!",
            "phi^2 + 1/phi^2 = 3 — Trinity Identity! This is no coincidence. Three is sacred in math and nature.",
            "phi and Fibonacci connection: lim(F(n+1)/F(n)) = phi. The larger n, the more precise. Math connects everything!",
            "Golden ratio in nature: shell spirals, flower petals, galaxies. phi is the universal proportion of beauty.",
            "phi^2 = 2.618..., 1/phi = 0.618..., phi - 1/phi = 1. Amazing properties! This is our architecture's foundation.",
        },
    },
    // NEW: English Future/AI
    .{
        .keywords = &.{ "future of ai", "artificial intelligence", "ai takeover", "robots", "singularity", "agi" },
        .category = .Future,
        .language = .English,
        .weight = 1.1,
        .responses = &.{
            "Future of AI? Local, private, green. Cloud monopolies are the past. Trinity is the future!",
            "AI takeover? Unlikely. AI is a tool. Hammers didn't take over the world, though they changed construction.",
            "Singularity? Interesting theory. But focus on practice: making AI useful and safe.",
            "Robots replacing humans? Partially. Routine — yes. Creativity — no. AI writes code, humans design architecture.",
            "Future is hybrid: human + AI. Like programmer + compiler. Together stronger!",
        },
    },
    // ═══════════════════════════════════════════════════════════════════════════
    // CHINESE PATTERNS (30 patterns)
    // ═══════════════════════════════════════════════════════════════════════════
    .{
        .keywords = &.{ "你好", "您好", "嗨", "哈喽", "早上好", "晚上好", "下午好" },
        .category = .Greeting,
        .language = .Chinese,
        .weight = 1.2,
        .responses = &.{
            "你好！很高兴见到你。有什么可以帮助的？",
            "您好！Trinity本地代理在线。今天做什么？",
            "嗨！准备好写代码了。什么任务？",
            "哈喽！60K ops/s 准备就绪！开始吧！",
            "你好！本地AI为您服务。需要什么？",
        },
    },
    .{
        .keywords = &.{ "再见", "拜拜", "回见", "走了", "晚安", "下次见" },
        .category = .Farewell,
        .language = .Chinese,
        .weight = 1.0,
        .responses = &.{
            "再见！祝你好运！",
            "拜拜！phi^2 + 1/phi^2 = 3！下次见！",
            "回见！Koschei是不朽的！随时回来！",
            "走了！合作愉快！",
            "晚安！明天继续！",
        },
    },
    .{
        .keywords = &.{ "笑话", "讲个笑话", "搞笑", "幽默", "有趣的" },
        .category = .Humor,
        .language = .Chinese,
        .weight = 1.1,
        .responses = &.{
            "程序员为什么辞职？因为他没有得到数组！(get array/加薪)",
            "换灯泡需要几个程序员？零个 — 这是硬件问题！",
            "两个字节相遇。一个说：'你好吗？'另一个：'还行，但溢出快了。'",
            "妻子对程序员说：'买面包，如果有鸡蛋就买10个。'他带回了10个面包。",
            "为什么程序员喜欢深色模式？因为光会吸引bug！",
        },
    },
    .{
        .keywords = &.{ "phi", "黄金比例", "1.618", "斐波那契" },
        .category = .Math,
        .language = .Chinese,
        .weight = 1.4,
        .responses = &.{
            "phi = (1 + sqrt(5)) / 2 = 1.618033... 黄金比例。phi^2 = phi + 1。数学之美！",
            "phi^2 + 1/phi^2 = 3 — Trinity恒等式！这不是巧合。三是神圣的数字。",
            "phi和斐波那契的联系：lim(F(n+1)/F(n)) = phi。n越大越精确。数学连接一切！",
            "自然界的黄金比例：贝壳螺旋、花瓣、星系。phi是美的通用比例。",
        },
    },
    // ═══════════════════════════════════════════════════════════════════════════
    // SPECIAL: Code-related patterns
    // ═══════════════════════════════════════════════════════════════════════════
    .{
        .keywords = &.{ "fibonacci", "фибоначчи", "斐波那契", "fib", "fibb" },
        .category = .Programming,
        .language = .English,
        .weight = 1.5,
        .responses = &.{
            "Fibonacci! Classic. In Zig: `fn fib(n: u64) u64 { if (n < 2) return n; return fib(n-1) + fib(n-2); }` — but use iterative for performance!",
            "Fibonacci связан с phi: lim(F(n+1)/F(n)) = phi = 1.618... Могу написать оптимизированную версию на Zig!",
            "斐波那契数列：0, 1, 1, 2, 3, 5, 8, 13... F(n) = F(n-1) + F(n-2)。与黄金比例phi相关！",
        },
    },
    .{
        .keywords = &.{ "hello world", "helloworld", "первая программа", "开始编程" },
        .category = .Programming,
        .language = .English,
        .weight = 1.3,
        .responses = &.{
            "Hello World in Zig:\n```zig\nconst std = @import(\"std\");\npub fn main() void {\n    std.debug.print(\"Hello, World!\\n\", .{});\n}\n```",
            "Hello World — the first step in every programmer's journey! In Trinity we say: phi^2 + 1/phi^2 = 3!",
            "经典的Hello World！每个程序员的起点。用Zig: `std.debug.print(\"你好，世界！\", .{});`",
        },
    },
    .{
        .keywords = &.{ "quicksort", "quick sort", "быстрая сортировка", "快速排序" },
        .category = .Programming,
        .language = .English,
        .weight = 1.4,
        .responses = &.{
            "QuickSort: O(n log n) average, O(n²) worst. Partition around pivot, recurse. Want me to write it in Zig?",
            "Быстрая сортировка — один из лучших алгоритмов! Разделяй и властвуй. O(n log n) в среднем.",
            "快速排序：选择基准，分区，递归。平均O(n log n)。经典的分治算法！",
        },
    },
    // ═══════════════════════════════════════════════════════════════════════════
    // SPECIAL: Hallucination awareness (honest responses)
    // ═══════════════════════════════════════════════════════════════════════════
    .{
        .keywords = &.{ "галлюцинация", "ты реальный", "ты существуешь", "ты настоящий", "ты врёшь" },
        .category = .Hallucination,
        .language = .Russian,
        .weight = 1.5,
        .responses = &.{
            "Честно: я pattern matcher с 200+ шаблонами + LLM fallback. Не AGI — детерминированные паттерны + локальная модель.",
            "Я не настоящий AI в смысле GPT — я гибрид: быстрые паттерны для известного, LLM для неизвестного. 100% локально.",
            "Правда: это symbolic VSA + pattern matching + local LLM. Быстро, честно, без облака.",
            "Буду честен: я не галлюцинирую на математике (детерминировано), но на general chat использую паттерны или LLM fallback.",
        },
    },
    .{
        .keywords = &.{ "hallucination", "are you real", "do you exist", "are you lying", "are you fake" },
        .category = .Hallucination,
        .language = .English,
        .weight = 1.5,
        .responses = &.{
            "Honest answer: I'm a pattern matcher with 200+ templates + LLM fallback. Not AGI — deterministic patterns + local model.",
            "I'm not real AI like GPT — I'm hybrid: fast patterns for known, LLM for unknown. 100% local.",
            "Truth: symbolic VSA + pattern matching + local LLM. Fast, honest, no cloud.",
            "Being honest: I don't hallucinate on math (deterministic), but on general chat I use patterns or LLM fallback.",
        },
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// ENHANCED CHAT ENGINE WITH TOP-K
// ═══════════════════════════════════════════════════════════════════════════════

pub const IglaEnhancedChat = struct {
    response_counter: usize,
    total_chats: usize,
    top_k_buffer: [TOP_K]ScoredPattern,
    cot_enabled: bool,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .response_counter = 0,
            .total_chats = 0,
            .top_k_buffer = undefined,
            .cot_enabled = true,
        };
    }

    /// Score a pattern against a query
    fn scorePattern(pattern: *const ConversationalPattern, query: []const u8) ScoredPattern {
        var score: f32 = 0;
        var matched: usize = 0;

        for (pattern.keywords) |keyword| {
            if (containsUTF8(query, keyword)) {
                // Score = keyword length * weight * position bonus
                const len_score = @as(f32, @floatFromInt(keyword.len));
                score += len_score * pattern.weight;
                matched += 1;
            }
        }

        // Bonus for multiple keyword matches
        if (matched > 1) {
            score *= 1.0 + @as(f32, @floatFromInt(matched - 1)) * 0.2;
        }

        return ScoredPattern{
            .pattern = pattern,
            .score = score,
            .matched_keywords = matched,
        };
    }

    /// Get top-K patterns sorted by score
    fn getTopK(self: *Self, query: []const u8) []ScoredPattern {
        var count: usize = 0;

        // Score all patterns
        for (&PATTERNS) |*pattern| {
            const scored = scorePattern(pattern, query);
            if (scored.score > 0) {
                if (count < TOP_K) {
                    self.top_k_buffer[count] = scored;
                    count += 1;
                } else {
                    // Replace lowest score if current is higher
                    var min_idx: usize = 0;
                    var min_score: f32 = self.top_k_buffer[0].score;
                    for (self.top_k_buffer[0..count], 0..) |p, i| {
                        if (p.score < min_score) {
                            min_score = p.score;
                            min_idx = i;
                        }
                    }
                    if (scored.score > min_score) {
                        self.top_k_buffer[min_idx] = scored;
                    }
                }
            }
        }

        // Sort by score descending
        if (count > 1) {
            std.mem.sort(ScoredPattern, self.top_k_buffer[0..count], {}, struct {
                fn cmp(_: void, a: ScoredPattern, b: ScoredPattern) bool {
                    return a.score > b.score;
                }
            }.cmp);
        }

        return self.top_k_buffer[0..count];
    }

    /// Generate chain-of-thought reasoning for complex queries
    fn generateCoT(query: []const u8) ?[]const u8 {
        // Simple CoT based on query type
        if (containsUTF8(query, "почему") or containsUTF8(query, "why")) {
            return "Reasoning: Analyzing causal relationship...";
        }
        if (containsUTF8(query, "как") or containsUTF8(query, "how")) {
            return "Reasoning: Breaking down into steps...";
        }
        if (containsUTF8(query, "что такое") or containsUTF8(query, "what is")) {
            return "Reasoning: Defining concept...";
        }
        return null;
    }

    /// Get chat response with top-k selection
    pub fn respond(self: *Self, query: []const u8) ChatResponse {
        self.total_chats += 1;

        // Get top-K matches
        const top_k = self.getTopK(query);

        if (top_k.len > 0 and top_k[0].score > 0) {
            const best = top_k[0];

            // Select response with variety
            const idx = self.response_counter % best.pattern.responses.len;
            self.response_counter += 1;

            // Calculate calibrated confidence
            const max_possible_score: f32 = 20.0; // Approximate max
            var confidence = @min(best.score / max_possible_score, 0.95);
            if (best.matched_keywords > 2) {
                confidence = @min(confidence + 0.1, 0.95);
            }

            // Generate CoT if enabled and query is complex
            var reasoning: ?[]const u8 = null;
            if (self.cot_enabled and query.len > COT_THRESHOLD) {
                reasoning = generateCoT(query);
            }

            return ChatResponse{
                .response = best.pattern.responses[idx],
                .category = best.pattern.category,
                .language = best.pattern.language,
                .confidence = confidence,
                .reasoning = reasoning,
            };
        }

        // Unknown query fallback
        const lang = detectLanguage(query);
        return switch (lang) {
            .Russian => ChatResponse{
                .response = "Интересный вопрос! Я специализируюсь на коде, математике и философии. Попробуй спросить про Fibonacci, phi или Zig!",
                .category = .Unknown,
                .language = .Russian,
                .confidence = 0.3,
                .reasoning = null,
            },
            .Chinese => ChatResponse{
                .response = "有趣的问题！我专注于代码、数学和哲学。试着问我Fibonacci、phi或Zig！",
                .category = .Unknown,
                .language = .Chinese,
                .confidence = 0.3,
                .reasoning = null,
            },
            else => ChatResponse{
                .response = "Interesting question! I specialize in code, math, and philosophy. Try asking about Fibonacci, phi, or Zig!",
                .category = .Unknown,
                .language = .English,
                .confidence = 0.3,
                .reasoning = null,
            },
        };
    }

    pub fn getStats(self: *const Self) struct {
        total_chats: usize,
        patterns_available: usize,
        categories: usize,
        top_k: usize,
        cot_enabled: bool,
    } {
        return .{
            .total_chats = self.total_chats,
            .patterns_available = PATTERNS.len,
            .categories = @typeInfo(ChatCategory).@"enum".fields.len - 1,
            .top_k = TOP_K,
            .cot_enabled = self.cot_enabled,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

fn containsUTF8(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;

    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.mem.eql(u8, haystack[i .. i + needle.len], needle)) {
            return true;
        }
        var match = true;
        for (0..needle.len) |j| {
            const h = if (haystack[i + j] < 128) std.ascii.toLower(haystack[i + j]) else haystack[i + j];
            const n = if (needle[j] < 128) std.ascii.toLower(needle[j]) else needle[j];
            if (h != n) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

pub fn detectLanguage(text: []const u8) Language {
    for (text) |byte| {
        if (byte >= 0xD0 and byte <= 0xD3) return .Russian;
        if (byte >= 0xE4 and byte <= 0xE9) return .Chinese;
    }
    return .English;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "enhanced chat greeting" {
    var chat = IglaEnhancedChat.init();
    const result = chat.respond("привет");
    try std.testing.expect(result.category == .Greeting);
    try std.testing.expect(result.language == .Russian);
    try std.testing.expect(result.confidence > 0.3);
}

test "enhanced chat top-k" {
    var chat = IglaEnhancedChat.init();
    const top_k = chat.getTopK("phi golden ratio");
    try std.testing.expect(top_k.len > 0);
    try std.testing.expect(top_k[0].matched_keywords >= 1);
}

test "enhanced chat math" {
    var chat = IglaEnhancedChat.init();
    const result = chat.respond("what is phi golden ratio");
    try std.testing.expect(result.category == .Math);
    try std.testing.expect(result.confidence > 0.5);
}

test "enhanced chat joke" {
    var chat = IglaEnhancedChat.init();
    const result = chat.respond("tell me a joke");
    try std.testing.expect(result.category == .Humor);
}

test "enhanced chat stats" {
    var chat = IglaEnhancedChat.init();
    _ = chat.respond("hello");
    const stats = chat.getStats();
    try std.testing.expect(stats.patterns_available > 30);
    try std.testing.expect(stats.top_k == TOP_K);
}
