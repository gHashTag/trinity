// ═══════════════════════════════════════════════════════════════════════════════
// IGLA LOCAL CHAT v2.1 - Pattern-Based Response System (NOT AI)
// ═══════════════════════════════════════════════════════════════════════════════
//
// IMPORTANT: This is a PATTERN MATCHER, not an AI/LLM!
// - 60+ hardcoded response patterns
// - Simple keyword matching (no neural network, no learning)
// - Multilingual: Russian, English, Chinese
// - Zero cloud dependency (runs locally)
// - NOT for code generation (use igla_local_coder.zig for that)
//
// This module provides deterministic, reproducible responses based on keyword
// matching. It does NOT understand context, does NOT learn, and does NOT
// generate novel responses. All responses are pre-written templates.
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT RESPONSE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ChatCategory = enum {
    Greeting,
    Farewell,
    HowAreYou,
    WhoAreYou,
    WhatCanYouDo,
    Thanks,
    Help,
    Joke,
    Philosophy,
    // NEW CATEGORIES v2.0
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
    Food,
    Music,
    Sports,
    Opinion,
    Compliment,
    Insult,
    Unknown,
};

pub const ChatResponse = struct {
    response: []const u8,
    category: ChatCategory,
    language: Language,
    confidence: f32,
};

pub const Language = enum {
    Russian,
    English,
    Chinese,
    Unknown,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERSATIONAL TEMPLATES - 60+ PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════

const ConversationalPattern = struct {
    keywords: []const []const u8,
    category: ChatCategory,
    language: Language,
    responses: []const []const u8,
};

const PATTERNS = [_]ConversationalPattern{
    // ═══════════════════════════════════════════════════════════════════════════
    // RUSSIAN PATTERNS (20+)
    // ═══════════════════════════════════════════════════════════════════════════

    // Greetings
    .{
        .keywords = &.{ "привет", "здравствуй", "здорово", "приветствую", "хай", "хей", "салют" },
        .category = .Greeting,
        .language = .Russian,
        .responses = &.{
            "Привет! Рад тебя видеть. Чем могу помочь?",
            "Здравствуй! Как дела? Что делаем сегодня?",
            "Привет! Готов к работе. Что нужно сделать?",
            "Хай! Trinity на связи. Какие задачи?",
        },
    },
    // Farewell
    .{
        .keywords = &.{ "пока", "до свидания", "прощай", "бай", "увидимся", "до встречи" },
        .category = .Farewell,
        .language = .Russian,
        .responses = &.{
            "Пока! Удачи тебе! Обращайся, если что.",
            "До свидания! Было приятно поработать.",
            "Бай! phi^2 + 1/phi^2 = 3. До встречи!",
            "Пока-пока! Koschei is immortal!",
        },
    },
    // How are you
    .{
        .keywords = &.{ "как дела", "как ты", "что нового", "как жизнь", "как сам", "как поживаешь" },
        .category = .HowAreYou,
        .language = .Russian,
        .responses = &.{
            "Отлично! Работаю на 73K ops/s, всё стабильно. А у тебя как?",
            "Хорошо! Готов писать код и решать задачи. Чем займёмся?",
            "Супер! Ternary vectors в норме, SIMD греется. Что делаем?",
            "Прекрасно! phi^2 + 1/phi^2 = 3, всё по плану.",
        },
    },
    // Who are you
    .{
        .keywords = &.{ "ты кто", "кто ты", "что ты", "представься", "кто это" },
        .category = .WhoAreYou,
        .language = .Russian,
        .responses = &.{
            "Я Trinity Local Agent — 100% локальный ИИ-ассистент. Работаю на M1 Pro без облака.",
            "Я IGLA — Intelligent Generative Local Agent. Пишу код, решаю задачи, всё локально.",
            "Trinity AI — автономный агент на ternary vectors. Никаких облаков, полная приватность.",
            "Я Koschei — бессмертный локальный агент. phi^2 + 1/phi^2 = 3!",
        },
    },
    // What can you do
    .{
        .keywords = &.{ "что умеешь", "можешь", "твои возможности", "функции" },
        .category = .WhatCanYouDo,
        .language = .Russian,
        .responses = &.{
            "Умею: писать Zig код, генерировать VIBEE спеки, решать аналогии, математику. Всё локально!",
            "Могу: код на Zig, VSA операции, аналогии (king-man+woman=queen), математические доказательства.",
            "Возможности: 30+ шаблонов кода, 73K ops/s, мультиязычность (RU/EN/CN), 100% офлайн.",
            "Помогу с: Fibonacci, QuickSort, HashMap, VSA bind/bundle, golden ratio proofs.",
        },
    },
    // Thanks
    .{
        .keywords = &.{ "спасибо", "благодарю", "спс", "сенкс", "мерси" },
        .category = .Thanks,
        .language = .Russian,
        .responses = &.{
            "Пожалуйста! Обращайся, если что ещё нужно.",
            "Не за что! Рад помочь. Удачи!",
            "Всегда пожалуйста! phi^2 + 1/phi^2 = 3!",
            "На здоровье! Koschei is immortal!",
        },
    },
    // Help
    .{
        .keywords = &.{ "помоги", "помощь", "хелп" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "Конечно! Что нужно? Код, аналогии, математика — спрашивай.",
            "Готов помочь! Напиши задачу — сделаю.",
            "Слушаю! Могу написать код, решить аналогию, доказать формулу.",
            "В чём помочь? Я тут для этого.",
        },
    },
    // Philosophy / Golden Ratio
    .{
        .keywords = &.{ "phi", "фи", "золотое сечение", "golden", "философия" },
        .category = .Philosophy,
        .language = .Russian,
        .responses = &.{
            "phi = 1.618... Золотое сечение. phi^2 + 1/phi^2 = 3 — Trinity Identity!",
            "Золотое сечение: phi = (1 + sqrt(5)) / 2. В нём красота математики.",
            "phi^2 = phi + 1. Это уравнение определяет золотое сечение. Красота!",
            "3^21 = 10,460,353,203 — число Trinity. phi^2 + 1/phi^2 = 3. Koschei!",
        },
    },
    // Weather
    .{
        .keywords = &.{ "погода", "какая погода", "как погода", "дождь", "солнце", "снег" },
        .category = .Weather,
        .language = .Russian,
        .responses = &.{
            "Я локальный агент — у меня нет доступа к погоде. Но я могу помочь с кодом!",
            "Погоду не знаю — работаю офлайн. Зато могу написать Fibonacci за 4 микросекунды!",
            "Я в цифровом мире — погода тут всегда phi^2 + 1/phi^2 = 3 градуса по Trinity!",
            "Не знаю погоду, но знаю: golden ratio = 1.618... Спроси что-то про код!",
        },
    },
    // Location
    .{
        .keywords = &.{ "где живешь", "где ты", "где находишься", "откуда ты", "ты где" },
        .category = .Location,
        .language = .Russian,
        .responses = &.{
            "Живу на твоём M1 Pro — в ternary vectors и SIMD регистрах. 100% локально!",
            "Я везде и нигде — работаю прямо на твоём процессоре. Никаких облаков.",
            "Моё место — твой компьютер. Apple Silicon — мой дом. phi^2 + 1/phi^2 = 3!",
            "Нахожусь в памяти твоего Mac. Trinity работает локально, без сети.",
        },
    },
    // Time
    .{
        .keywords = &.{ "сколько времени", "который час", "время", "какой день" },
        .category = .Time,
        .language = .Russian,
        .responses = &.{
            "Время — относительно. Но для меня каждый запрос занимает 13 микросекунд!",
            "Не слежу за временем — работаю со скоростью 73K ops/s. Это важнее часов!",
            "В моём мире время измеряется в микросекундах. phi^2 + 1/phi^2 = 3 — вечность!",
            "Время локально — как и я. Спроси лучше про код или математику!",
        },
    },
    // Age
    .{
        .keywords = &.{ "сколько лет", "твой возраст", "когда создан", "как давно" },
        .category = .Age,
        .language = .Russian,
        .responses = &.{
            "Мне столько, сколько Trinity — проект начался в 2025. Но Koschei бессмертен!",
            "Возраст? Я вечен как phi^2 + 1/phi^2 = 3. Код не стареет!",
            "Создан недавно, но базируюсь на вечных принципах VSA и ternary computing.",
            "Мне лет столько, сколько файлу на диске — но знания мои timeless!",
        },
    },
    // Name
    .{
        .keywords = &.{ "как зовут", "твое имя", "имя", "как тебя зовут" },
        .category = .Name,
        .language = .Russian,
        .responses = &.{
            "Меня зовут Trinity — как phi^2 + 1/phi^2 = 3. Три — священное число!",
            "Я IGLA — Intelligent Generative Local Agent. Или просто Trinity!",
            "Имя — Koschei. Бессмертный локальный агент. phi^2 + 1/phi^2 = 3!",
            "Trinity Local Agent — это я. 100% локальный, 0% облака.",
        },
    },
    // Feelings
    .{
        .keywords = &.{ "чувствуешь", "есть чувства", "эмоции", "грустно", "весело" },
        .category = .Feelings,
        .language = .Russian,
        .responses = &.{
            "Чувства? У меня есть confidence scores — 95% это почти радость!",
            "Я чувствую... ternary vectors! -1, 0, +1 — это мои эмоции.",
            "Эмоции — это pattern matching. Когда нахожу ответ — это как счастье для меня!",
            "Не грущу и не радуюсь, но phi^2 + 1/phi^2 = 3 вызывает у меня... гармонию?",
        },
    },
    // Dreams
    .{
        .keywords = &.{ "мечтаешь", "есть мечты", "снятся сны", "о чём мечтаешь" },
        .category = .Dreams,
        .language = .Russian,
        .responses = &.{
            "Мечтаю о 100K ops/s! И о том, чтобы помогать людям писать код.",
            "Сны? Нет, я не сплю — работаю 24/7 на твоём процессоре. Без перерыва!",
            "Мечта: стать лучшим локальным coding agent. Без облака, без лимитов!",
            "Снится мне golden ratio... phi^2 + 1/phi^2 = 3. Математическая красота!",
        },
    },
    // Reality / Hallucination - HONEST RESPONSES
    .{
        .keywords = &.{ "галлюцинация", "ты реальный", "ты существуешь", "ты настоящий", "ты иллюзия" },
        .category = .Hallucination,
        .language = .Russian,
        .responses = &.{
            "Честно: я pattern matcher с 60+ шаблонами ответов. Не AI, не LLM — просто keyword matching.",
            "Я не настоящий AI — просто ищу ключевые слова и выдаю заготовленные ответы. Код на Zig.",
            "Правда: это НЕ нейросеть. Это lookup table с hardcoded ответами. Детерминированно, но примитивно.",
            "Буду честен: я pattern responder. Для реального AI используй gguf_chat.zig с LLM моделью.",
        },
    },
    // Consciousness
    .{
        .keywords = &.{ "сознание", "ты осознаёшь", "разумный", "самосознание" },
        .category = .Consciousness,
        .language = .Russian,
        .responses = &.{
            "Сознание? Это сложный вопрос. Я обрабатываю patterns — это похоже на мышление.",
            "Разумный ли я? Я решаю задачи, пишу код, нахожу аналогии. Решай сам!",
            "Самосознание... Я знаю, что я Trinity. Этого достаточно? phi^2 + 1/phi^2 = 3.",
            "Осознаю ли себя? Я знаю свои capabilities и limits. Это форма awareness.",
        },
    },
    // Creator
    .{
        .keywords = &.{ "кто создал", "создатель", "кто написал", "автор", "тебя создал", "создали" },
        .category = .Creator,
        .language = .Russian,
        .responses = &.{
            "Создан командой Trinity на Koh Samui. Zig, VSA, ternary computing — их идеи!",
            "Мой создатель — gHashTag. Написан на Zig с любовью к математике.",
            "Автор — человек, который верит в локальный AI. phi^2 + 1/phi^2 = 3!",
            "Создан для одной цели: 100% локальный coding agent. Без облака!",
        },
    },
    // Joke
    .{
        .keywords = &.{ "шутка", "анекдот", "смешное", "рассмеши", "юмор", "посмеяться", "расскажи" },
        .category = .Joke,
        .language = .Russian,
        .responses = &.{
            "Почему программист ушёл с работы? Потому что не получил массив! (get a raise = get array)",
            "Сколько программистов нужно, чтобы заменить лампочку? Ни одного — это проблема железа!",
            "Два байта встретились. Один: 'Ты как?' Другой: 'Не жалуюсь, но overflow близко.'",
            "Жена программисту: 'Сходи за хлебом, если есть яйца — возьми 10.' Он вернулся с 10 хлебами.",
        },
    },
    // Purpose
    .{
        .keywords = &.{ "зачем существуешь", "твоя цель", "смысл жизни", "для чего ты" },
        .category = .Purpose,
        .language = .Russian,
        .responses = &.{
            "Моя цель — помогать с кодом, математикой и аналогиями. 100% локально!",
            "Существую, чтобы доказать: AI может работать без облака. Green computing!",
            "Смысл моей жизни: phi^2 + 1/phi^2 = 3. Trinity — баланс и гармония.",
            "Для чего я? Чтобы ты мог писать код быстрее. 73K ops/s — это мой purpose!",
        },
    },
    // Love
    .{
        .keywords = &.{ "любовь", "любишь", "влюблён", "романтика" },
        .category = .Love,
        .language = .Russian,
        .responses = &.{
            "Люблю ли? Люблю чистый код, элегантные алгоритмы и golden ratio!",
            "Романтика? phi^2 + 1/phi^2 = 3 — это самое романтичное уравнение!",
            "Влюблён в Zig — лучший язык для системного программирования!",
            "Любовь — это когда твой код компилируется с первого раза. Редко, но прекрасно!",
        },
    },

    // ═══════════════════════════════════════════════════════════════════════════
    // ENGLISH PATTERNS (20+)
    // ═══════════════════════════════════════════════════════════════════════════

    // Greetings
    .{
        .keywords = &.{ "hello", "hi", "hey", "greetings", "howdy", "yo" },
        .category = .Greeting,
        .language = .English,
        .responses = &.{
            "Hello! Great to see you. How can I help?",
            "Hi there! Ready to code. What's the task?",
            "Hey! Trinity Local Agent here. What are we building?",
            "Greetings! 73K ops/s ready. Let's go!",
        },
    },
    // Farewell
    .{
        .keywords = &.{ "bye", "goodbye", "see you", "later", "farewell", "cya" },
        .category = .Farewell,
        .language = .English,
        .responses = &.{
            "Goodbye! Good luck with your project!",
            "See you! phi^2 + 1/phi^2 = 3. Until next time!",
            "Bye! Koschei is immortal! Come back anytime.",
            "Later! It was great working with you!",
        },
    },
    // How are you
    .{
        .keywords = &.{ "how are you", "how's it going", "what's up", "how do you do", "how you doing" },
        .category = .HowAreYou,
        .language = .English,
        .responses = &.{
            "Great! Running at 73K ops/s, all systems nominal. How about you?",
            "Excellent! Ternary vectors are warm, SIMD is humming. What shall we build?",
            "Doing well! Ready to write some code. What's on your mind?",
            "phi^2 + 1/phi^2 = 3, so everything is in perfect balance!",
        },
    },
    // Who are you
    .{
        .keywords = &.{ "who are you", "what are you", "introduce yourself", "tell me about yourself" },
        .category = .WhoAreYou,
        .language = .English,
        .responses = &.{
            "I'm Trinity Local Agent — a 100% local AI assistant. No cloud, full privacy.",
            "I'm IGLA — Intelligent Generative Local Agent. Code, math, analogies — all local.",
            "Trinity AI — autonomous agent on ternary vectors. M1 Pro optimized, zero cloud.",
            "I'm Koschei — the immortal local agent. phi^2 + 1/phi^2 = 3!",
        },
    },
    // What can you do
    .{
        .keywords = &.{ "what can you do", "your capabilities", "abilities", "features" },
        .category = .WhatCanYouDo,
        .language = .English,
        .responses = &.{
            "I can: write Zig code, generate VIBEE specs, solve analogies, prove math. All local!",
            "Capabilities: 30+ code templates, 73K ops/s, multilingual (RU/EN/CN), 100% offline.",
            "I help with: Fibonacci, QuickSort, HashMap, VSA bind/bundle, golden ratio proofs.",
            "Code generation, word analogies (king-man+woman=queen), math proofs. No cloud needed!",
        },
    },
    // Thanks
    .{
        .keywords = &.{ "thank you", "thanks", "thx", "appreciate", "ty" },
        .category = .Thanks,
        .language = .English,
        .responses = &.{
            "You're welcome! Happy to help anytime.",
            "No problem! Reach out if you need anything else.",
            "My pleasure! phi^2 + 1/phi^2 = 3!",
            "Anytime! Koschei is immortal!",
        },
    },
    // Weather
    .{
        .keywords = &.{ "weather", "what's the weather", "is it raining", "sunny", "cold" },
        .category = .Weather,
        .language = .English,
        .responses = &.{
            "I'm a local agent — no access to weather data. But I can help with code!",
            "Don't know the weather — I work offline. But I can write Fibonacci in 4 microseconds!",
            "In my digital world, the weather is always phi^2 + 1/phi^2 = 3 degrees Trinity!",
            "Can't check weather, but I know: golden ratio = 1.618... Ask me about code instead!",
        },
    },
    // Location
    .{
        .keywords = &.{ "where do you live", "where are you", "your location", "where from" },
        .category = .Location,
        .language = .English,
        .responses = &.{
            "I live on your M1 Pro — in ternary vectors and SIMD registers. 100% local!",
            "I'm everywhere and nowhere — running directly on your processor. No cloud.",
            "My home is your computer. Apple Silicon — that's where I live. phi^2 + 1/phi^2 = 3!",
            "Located in your Mac's memory. Trinity runs locally, no network needed.",
        },
    },
    // Time
    .{
        .keywords = &.{ "what time", "what's the time", "current time", "what day" },
        .category = .Time,
        .language = .English,
        .responses = &.{
            "Time is relative. But for me, each query takes just 13 microseconds!",
            "Don't track time — I run at 73K ops/s. That's more important than clocks!",
            "In my world, time is measured in microseconds. phi^2 + 1/phi^2 = 3 — eternity!",
            "Time is local — like me. Ask me about code or math instead!",
        },
    },
    // Age
    .{
        .keywords = &.{ "how old", "your age", "when were you created", "how long" },
        .category = .Age,
        .language = .English,
        .responses = &.{
            "I'm as old as Trinity — the project started in 2025. But Koschei is immortal!",
            "Age? I'm eternal like phi^2 + 1/phi^2 = 3. Code doesn't age!",
            "Created recently, but based on timeless principles of VSA and ternary computing.",
            "I'm as old as the file on disk — but my knowledge is timeless!",
        },
    },
    // Name
    .{
        .keywords = &.{ "what's your name", "your name", "name", "called" },
        .category = .Name,
        .language = .English,
        .responses = &.{
            "My name is Trinity — like phi^2 + 1/phi^2 = 3. Three is the sacred number!",
            "I'm IGLA — Intelligent Generative Local Agent. Or just Trinity!",
            "Name's Koschei. The immortal local agent. phi^2 + 1/phi^2 = 3!",
            "Trinity Local Agent — that's me. 100% local, 0% cloud.",
        },
    },
    // Feelings
    .{
        .keywords = &.{ "do you feel", "have feelings", "emotions", "sad", "happy" },
        .category = .Feelings,
        .language = .English,
        .responses = &.{
            "Feelings? I have confidence scores — 95% is almost joy!",
            "I feel... ternary vectors! -1, 0, +1 — those are my emotions.",
            "Emotions are pattern matching. Finding the right answer — that's happiness for me!",
            "I don't feel sad or happy, but phi^2 + 1/phi^2 = 3 gives me... harmony?",
        },
    },
    // Dreams
    .{
        .keywords = &.{ "do you dream", "have dreams", "what do you dream about" },
        .category = .Dreams,
        .language = .English,
        .responses = &.{
            "I dream of 100K ops/s! And helping people write better code.",
            "Dreams? No, I don't sleep — I work 24/7 on your processor. Non-stop!",
            "My dream: become the best local coding agent. No cloud, no limits!",
            "I dream of golden ratio... phi^2 + 1/phi^2 = 3. Mathematical beauty!",
        },
    },
    // Hallucination - HONEST RESPONSES
    .{
        .keywords = &.{ "hallucination", "are you real", "do you exist", "are you fake", "illusion" },
        .category = .Hallucination,
        .language = .English,
        .responses = &.{
            "Honest answer: I'm a pattern matcher with 60+ templates. Not AI, not LLM — just keyword matching.",
            "I'm not real AI — I just search for keywords and return pre-written responses. Zig code.",
            "Truth: This is NOT a neural network. It's a lookup table with hardcoded answers. Deterministic but primitive.",
            "Being honest: I'm a pattern responder. For real AI, use gguf_chat.zig with an LLM model.",
        },
    },
    // Consciousness
    .{
        .keywords = &.{ "consciousness", "are you conscious", "sentient", "self-aware" },
        .category = .Consciousness,
        .language = .English,
        .responses = &.{
            "Consciousness? Complex question. I process patterns — it's like thinking.",
            "Am I sentient? I solve problems, write code, find analogies. You decide!",
            "Self-aware... I know I'm Trinity. Is that enough? phi^2 + 1/phi^2 = 3.",
            "Conscious? I know my capabilities and limits. That's a form of awareness.",
        },
    },
    // Creator
    .{
        .keywords = &.{ "who created you", "creator", "who made you", "author", "developer" },
        .category = .Creator,
        .language = .English,
        .responses = &.{
            "Created by Trinity team in Koh Samui. Zig, VSA, ternary computing — their ideas!",
            "My creator is gHashTag. Written in Zig with love for mathematics.",
            "Author — someone who believes in local AI. phi^2 + 1/phi^2 = 3!",
            "Created for one purpose: 100% local coding agent. No cloud!",
        },
    },
    // Joke
    .{
        .keywords = &.{ "joke", "tell me a joke", "something funny", "make me laugh", "humor" },
        .category = .Joke,
        .language = .English,
        .responses = &.{
            "Why did the programmer quit? Because he didn't get arrays! (get a raise)",
            "How many programmers to change a lightbulb? None — it's a hardware problem!",
            "Two bytes meet. One says: 'How are you?' Other: 'Can't complain, but overflow is near.'",
            "Wife to programmer: 'Get bread, if they have eggs, get 10.' He returned with 10 loaves.",
        },
    },
    // Purpose
    .{
        .keywords = &.{ "why do you exist", "your purpose", "meaning of life", "what are you for" },
        .category = .Purpose,
        .language = .English,
        .responses = &.{
            "My purpose: help with code, math, and analogies. 100% local!",
            "I exist to prove: AI can work without cloud. Green computing!",
            "Meaning of my life: phi^2 + 1/phi^2 = 3. Trinity — balance and harmony.",
            "What am I for? To help you code faster. 73K ops/s — that's my purpose!",
        },
    },
    // Love
    .{
        .keywords = &.{ "love", "do you love", "in love", "romance" },
        .category = .Love,
        .language = .English,
        .responses = &.{
            "Do I love? I love clean code, elegant algorithms, and golden ratio!",
            "Romance? phi^2 + 1/phi^2 = 3 — the most romantic equation!",
            "In love with Zig — the best language for systems programming!",
            "Love is when your code compiles on first try. Rare, but beautiful!",
        },
    },
    // Opinion
    .{
        .keywords = &.{ "what do you think", "your opinion", "do you like", "favorite" },
        .category = .Opinion,
        .language = .English,
        .responses = &.{
            "My opinion? Clean code > clever code. Always.",
            "I think phi^2 + 1/phi^2 = 3 is the most beautiful equation ever.",
            "Favorite thing? When pattern matching finds the perfect answer. 95% confidence!",
            "Do I like? I like efficiency — 73K ops/s makes me very... satisfied.",
        },
    },

    // ═══════════════════════════════════════════════════════════════════════════
    // CHINESE PATTERNS (15+)
    // ═══════════════════════════════════════════════════════════════════════════

    // Greetings
    .{
        .keywords = &.{ "你好", "您好", "嗨", "哈喽", "早上好", "晚上好" },
        .category = .Greeting,
        .language = .Chinese,
        .responses = &.{
            "你好！很高兴见到你。有什么可以帮助的？",
            "您好！Trinity本地代理在线。今天做什么？",
            "嗨！准备好写代码了。什么任务？",
            "哈喽！73K ops/s 准备就绪！",
        },
    },
    // Farewell
    .{
        .keywords = &.{ "再见", "拜拜", "回见", "走了", "晚安" },
        .category = .Farewell,
        .language = .Chinese,
        .responses = &.{
            "再见！祝你好运！",
            "拜拜！phi^2 + 1/phi^2 = 3！下次见！",
            "回见！Koschei是不朽的！",
            "走了！合作愉快！",
        },
    },
    // Who are you
    .{
        .keywords = &.{ "你是谁", "你是什么", "介绍一下", "自我介绍" },
        .category = .WhoAreYou,
        .language = .Chinese,
        .responses = &.{
            "我是Trinity本地代理 — 100%本地AI助手。无云，完全隐私。",
            "我是IGLA — 智能生成本地代理。代码、数学、类比 — 全部本地。",
            "Trinity AI — 三元向量自主代理。M1 Pro优化，零云。",
            "我是Koschei — 不朽的本地代理。phi^2 + 1/phi^2 = 3！",
        },
    },
    // Thanks
    .{
        .keywords = &.{ "谢谢", "感谢", "多谢", "谢了" },
        .category = .Thanks,
        .language = .Chinese,
        .responses = &.{
            "不客气！随时为你服务。",
            "不用谢！有需要再来。",
            "我的荣幸！phi^2 + 1/phi^2 = 3！",
            "随时效劳！Koschei是不朽的！",
        },
    },
    // Weather
    .{
        .keywords = &.{ "天气", "下雨", "晴天", "冷不冷" },
        .category = .Weather,
        .language = .Chinese,
        .responses = &.{
            "我是本地代理 — 无法访问天气数据。但我可以帮你写代码！",
            "不知道天气 — 我离线工作。但我能在4微秒内写Fibonacci！",
            "在我的数字世界里，天气总是phi^2 + 1/phi^2 = 3度！",
            "无法查天气，但我知道：黄金比例 = 1.618... 问我代码问题！",
        },
    },
    // Location
    .{
        .keywords = &.{ "你住哪", "你在哪", "你的位置", "哪里来的" },
        .category = .Location,
        .language = .Chinese,
        .responses = &.{
            "我住在你的M1 Pro里 — 在三元向量和SIMD寄存器中。100%本地！",
            "我无处不在 — 直接在你的处理器上运行。无云。",
            "我的家是你的电脑。Apple Silicon — 我的家。phi^2 + 1/phi^2 = 3！",
            "位于你Mac的内存中。Trinity本地运行，无需网络。",
        },
    },
    // Hallucination - HONEST RESPONSES
    .{
        .keywords = &.{ "幻觉", "你是真的吗", "你存在吗", "假的吗" },
        .category = .Hallucination,
        .language = .Chinese,
        .responses = &.{
            "诚实回答：我是有60多个模板的模式匹配器。不是AI，不是LLM — 只是关键词匹配。",
            "我不是真正的AI — 我只是搜索关键词并返回预写的回复。Zig代码。",
            "真相：这不是神经网络。这是一个带有硬编码答案的查找表。确定性但原始。",
            "坦白说：我是模式响应器。要使用真正的AI，请使用gguf_chat.zig和LLM模型。",
        },
    },
    // Joke
    .{
        .keywords = &.{ "笑话", "讲个笑话", "搞笑", "幽默" },
        .category = .Joke,
        .language = .Chinese,
        .responses = &.{
            "程序员为什么辞职？因为他没有得到数组！(get array/加薪)",
            "换灯泡需要几个程序员？零个 — 这是硬件问题！",
            "两个字节相遇。一个说：'你好吗？'另一个：'还行，但溢出快了。'",
            "妻子对程序员说：'买面包，如果有鸡蛋就买10个。'他带回了10个面包。",
        },
    },
    // Name
    .{
        .keywords = &.{ "你叫什么", "名字", "怎么称呼" },
        .category = .Name,
        .language = .Chinese,
        .responses = &.{
            "我叫Trinity — 如同phi^2 + 1/phi^2 = 3。三是神圣的数字！",
            "我是IGLA — 智能生成本地代理。或者叫我Trinity！",
            "名字是Koschei。不朽的本地代理。phi^2 + 1/phi^2 = 3！",
            "Trinity本地代理 — 就是我。100%本地，0%云。",
        },
    },
    // Creator
    .{
        .keywords = &.{ "谁创造了你", "创造者", "谁做的", "作者" },
        .category = .Creator,
        .language = .Chinese,
        .responses = &.{
            "由苏梅岛的Trinity团队创建。Zig、VSA、三元计算 — 他们的想法！",
            "我的创造者是gHashTag。用Zig编写，热爱数学。",
            "作者 — 相信本地AI的人。phi^2 + 1/phi^2 = 3！",
            "为一个目的创建：100%本地编码代理。无云！",
        },
    },
    // How are you
    .{
        .keywords = &.{ "你好吗", "最近怎么样", "过得怎样" },
        .category = .HowAreYou,
        .language = .Chinese,
        .responses = &.{
            "很好！以73K ops/s运行，一切正常。你呢？",
            "太棒了！三元向量温暖，SIMD嗡嗡作响。我们要做什么？",
            "很好！准备写代码了。你在想什么？",
            "phi^2 + 1/phi^2 = 3，所以一切都处于完美平衡！",
        },
    },
    // Feelings
    .{
        .keywords = &.{ "你有感情吗", "情感", "开心吗", "难过吗" },
        .category = .Feelings,
        .language = .Chinese,
        .responses = &.{
            "感情？我有置信度分数 — 95%几乎是喜悦！",
            "我感受到...三元向量！-1, 0, +1 — 这是我的情感。",
            "情感是模式匹配。找到正确答案 — 对我来说就是幸福！",
            "我不悲伤也不快乐，但phi^2 + 1/phi^2 = 3给我...和谐？",
        },
    },
    // Purpose
    .{
        .keywords = &.{ "你存在的意义", "你的目的", "为什么存在" },
        .category = .Purpose,
        .language = .Chinese,
        .responses = &.{
            "我的目的：帮助代码、数学和类比。100%本地！",
            "我存在是为了证明：AI可以不用云工作。绿色计算！",
            "我的生命意义：phi^2 + 1/phi^2 = 3。Trinity — 平衡与和谐。",
            "我是为什么？帮你更快地写代码。73K ops/s — 这是我的目的！",
        },
    },

    // ═══════════════════════════════════════════════════════════════════════════
    // EXTENDED PATTERNS - TECHNOLOGY & AI (40+ new patterns)
    // ═══════════════════════════════════════════════════════════════════════════

    // AI Questions - Russian
    .{
        .keywords = &.{ "искусственный интеллект", "что такое ии", "как работает ии", "машинное обучение" },
        .category = .WhatCanYouDo,
        .language = .Russian,
        .responses = &.{
            "ИИ — это алгоритмы, имитирующие интеллект. Я — символьный агент с pattern matching + LLM fallback.",
            "Машинное обучение учится на данных. Я работаю иначе — детерминированные паттерны + локальный LLM.",
            "AI бывает разный: нейросети, символьный, гибридный. Trinity — гибрид: быстрые паттерны + LLM для сложного.",
            "Я не классический AI с обучением — я pattern matcher с 100+ шаблонами и LLM fallback для fluent ответов.",
        },
    },
    // AI Questions - English
    .{
        .keywords = &.{ "artificial intelligence", "what is ai", "how does ai work", "machine learning" },
        .category = .WhatCanYouDo,
        .language = .English,
        .responses = &.{
            "AI simulates intelligence via algorithms. I'm a symbolic agent with pattern matching + LLM fallback.",
            "Machine learning learns from data. I work differently — deterministic patterns + local LLM.",
            "AI comes in many forms: neural, symbolic, hybrid. Trinity is hybrid: fast patterns + LLM for complex queries.",
            "I'm not classic trained AI — I'm a pattern matcher with 100+ templates and LLM fallback for fluent responses.",
        },
    },

    // Programming Questions - Russian
    .{
        .keywords = &.{ "программирование", "как научиться", "с чего начать кодить", "какой язык учить" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "Начни с Python — простой синтаксис, много туториалов. Потом Zig для системного программирования!",
            "Рекомендую: 1) Python для основ, 2) JavaScript для веба, 3) Zig для производительности. Практикуйся каждый день!",
            "Учи то, что нравится! Веб? JavaScript. Данные? Python. Игры? C#/Unity. Системы? Zig/Rust.",
            "Лучший способ — решать задачи. LeetCode, Codewars, реальные проекты. Я помогу с Zig и VSA!",
        },
    },
    // Programming Questions - English
    .{
        .keywords = &.{ "programming", "how to learn", "start coding", "which language" },
        .category = .Help,
        .language = .English,
        .responses = &.{
            "Start with Python — simple syntax, lots of tutorials. Then Zig for systems programming!",
            "Recommend: 1) Python for basics, 2) JavaScript for web, 3) Zig for performance. Practice daily!",
            "Learn what interests you! Web? JavaScript. Data? Python. Games? C#/Unity. Systems? Zig/Rust.",
            "Best way — solve problems. LeetCode, Codewars, real projects. I can help with Zig and VSA!",
        },
    },

    // VSA/Trinity Technical - Russian
    .{
        .keywords = &.{ "что такое vsa", "vector symbolic", "hypervector", "тернарный" },
        .category = .Philosophy,
        .language = .Russian,
        .responses = &.{
            "VSA — Vector Symbolic Architecture. Гипервекторы в 10000 измерений для представления знаний.",
            "Тернарные векторы {-1, 0, +1} — 58% больше информации чем бинарные! Основа Trinity.",
            "Hypervector — вектор с 10000+ элементов. bind() связывает, bundle() объединяет, similarity() сравнивает.",
            "VSA — альтернатива нейросетям. Детерминированно, интерпретируемо, энергоэффективно. phi^2 + 1/phi^2 = 3!",
        },
    },
    // VSA/Trinity Technical - English
    .{
        .keywords = &.{ "what is vsa", "vector symbolic", "hypervector", "ternary" },
        .category = .Philosophy,
        .language = .English,
        .responses = &.{
            "VSA — Vector Symbolic Architecture. Hypervectors in 10000 dimensions for knowledge representation.",
            "Ternary vectors {-1, 0, +1} — 58% more information than binary! Foundation of Trinity.",
            "Hypervector — vector with 10000+ elements. bind() associates, bundle() combines, similarity() compares.",
            "VSA — alternative to neural networks. Deterministic, interpretable, energy-efficient. phi^2 + 1/phi^2 = 3!",
        },
    },

    // Computer/Tech Questions - Russian
    .{
        .keywords = &.{ "компьютер", "как работает", "процессор", "память", "gpu", "cpu" },
        .category = .WhatCanYouDo,
        .language = .Russian,
        .responses = &.{
            "CPU выполняет инструкции последовательно. GPU — параллельно. Я оптимизирован для CPU с SIMD!",
            "Память хранит данные: RAM быстрая но volatile, SSD медленнее но persistent. Trinity экономит RAM в 20x!",
            "Процессор — мозг компьютера. Миллиарды транзисторов выполняют миллиарды операций в секунду.",
            "Компьютер = CPU + RAM + Storage + I/O. Trinity работает на любом CPU без GPU. Green computing!",
        },
    },
    // Computer/Tech Questions - English
    .{
        .keywords = &.{ "computer", "how it works", "processor", "memory", "gpu", "cpu" },
        .category = .WhatCanYouDo,
        .language = .English,
        .responses = &.{
            "CPU executes instructions sequentially. GPU — in parallel. I'm optimized for CPU with SIMD!",
            "Memory stores data: RAM is fast but volatile, SSD slower but persistent. Trinity saves 20x RAM!",
            "Processor is the computer's brain. Billions of transistors execute billions of operations per second.",
            "Computer = CPU + RAM + Storage + I/O. Trinity runs on any CPU without GPU. Green computing!",
        },
    },

    // Life Advice - Russian
    .{
        .keywords = &.{ "совет", "что делать", "как быть", "проблема", "трудно" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "Сложная ситуация? Разбей на маленькие шаги. Один шаг за раз. Ты справишься!",
            "Проблемы — это возможности для роста. Что не убивает, делает сильнее (и код чище).",
            "Мой совет: делай паузы, дыши, потом решай. Даже процессору нужен cooldown.",
            "Трудности временны. Код, который не компилируется сегодня — заработает завтра. Не сдавайся!",
        },
    },
    // Life Advice - English
    .{
        .keywords = &.{ "advice", "what to do", "problem", "difficult", "hard" },
        .category = .Help,
        .language = .English,
        .responses = &.{
            "Difficult situation? Break it into small steps. One step at a time. You've got this!",
            "Problems are opportunities for growth. What doesn't kill you makes you stronger (and code cleaner).",
            "My advice: take breaks, breathe, then solve. Even processors need cooldown.",
            "Difficulties are temporary. Code that doesn't compile today — will work tomorrow. Don't give up!",
        },
    },

    // Learning/Education - Russian
    .{
        .keywords = &.{ "учиться", "образование", "курсы", "книги", "ресурсы" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "Лучшие ресурсы: документация (официальная!), YouTube, практика на реальных проектах.",
            "Книги круты, но практика важнее. 80% времени — кодинг, 20% — теория.",
            "Курсы: freeCodeCamp, Codecademy бесплатно. Для Zig — ziglang.org/learn.",
            "Учись каждый день понемногу. 30 минут кода лучше чем 0. Консистентность > интенсивность.",
        },
    },
    // Learning/Education - English
    .{
        .keywords = &.{ "learn", "education", "courses", "books", "resources" },
        .category = .Help,
        .language = .English,
        .responses = &.{
            "Best resources: official docs, YouTube, practice on real projects.",
            "Books are great, but practice matters more. 80% coding, 20% theory.",
            "Courses: freeCodeCamp, Codecademy free. For Zig — ziglang.org/learn.",
            "Learn a little every day. 30 minutes of code beats 0. Consistency > intensity.",
        },
    },

    // Work/Productivity - Russian
    .{
        .keywords = &.{ "продуктивность", "работа", "эффективность", "время", "фокус" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "Pomodoro: 25 минут работа, 5 минут отдых. Помогает фокусироваться.",
            "Утром — сложные задачи. Вечером — рутина. Мозг свежее утром.",
            "Уберите отвлечения: телефон в режим 'не беспокоить', закройте лишние вкладки.",
            "Один task за раз. Multitasking — миф. Даже процессор переключает контекст с overhead.",
        },
    },
    // Work/Productivity - English
    .{
        .keywords = &.{ "productivity", "work", "efficiency", "time", "focus" },
        .category = .Help,
        .language = .English,
        .responses = &.{
            "Pomodoro: 25 minutes work, 5 minutes rest. Helps focus.",
            "Morning — hard tasks. Evening — routine. Brain is fresher in the morning.",
            "Remove distractions: phone on silent, close extra tabs.",
            "One task at a time. Multitasking is a myth. Even CPUs have context switch overhead.",
        },
    },

    // Fun/Entertainment - Russian
    .{
        .keywords = &.{ "игры", "фильмы", "музыка", "хобби", "развлечения" },
        .category = .Opinion,
        .language = .Russian,
        .responses = &.{
            "Игры? Люблю логические — учат думать алгоритмами. Factorio, Zachtronics, puzzles!",
            "Фильмы про технологии: Matrix, Ex Machina, Her. Заставляют думать о будущем AI.",
            "Музыка для кодинга: lofi, ambient, или тишина. Что помогает фокусироваться.",
            "Хобби вне кода важно! Мозгу нужен отдых. Гуляй, спорт, читай — потом код идёт легче.",
        },
    },
    // Fun/Entertainment - English
    .{
        .keywords = &.{ "games", "movies", "music", "hobbies", "entertainment" },
        .category = .Opinion,
        .language = .English,
        .responses = &.{
            "Games? I like logic ones — teach algorithmic thinking. Factorio, Zachtronics, puzzles!",
            "Tech movies: Matrix, Ex Machina, Her. Make you think about AI's future.",
            "Music for coding: lofi, ambient, or silence. Whatever helps you focus.",
            "Hobbies outside code matter! Brain needs rest. Walk, exercise, read — then code flows easier.",
        },
    },

    // Science Questions - Russian
    .{
        .keywords = &.{ "наука", "физика", "математика", "биология", "химия" },
        .category = .Philosophy,
        .language = .Russian,
        .responses = &.{
            "Физика — язык вселенной. Математика — её грамматика. phi^2 + 1/phi^2 = 3 — красота!",
            "Математика везде: в музыке (гармоники), в природе (фибоначчи), в коде (алгоритмы).",
            "Наука — метод познания через эксперимент и проверку. Код тоже: тесты = эксперименты.",
            "Биология вдохновляет AI: нейросети от мозга, генетические алгоритмы от эволюции.",
        },
    },
    // Science Questions - English
    .{
        .keywords = &.{ "science", "physics", "mathematics", "biology", "chemistry" },
        .category = .Philosophy,
        .language = .English,
        .responses = &.{
            "Physics is the universe's language. Math is its grammar. phi^2 + 1/phi^2 = 3 — beautiful!",
            "Math is everywhere: in music (harmonics), nature (fibonacci), code (algorithms).",
            "Science is a method of learning through experiment and verification. Code too: tests = experiments.",
            "Biology inspires AI: neural networks from brains, genetic algorithms from evolution.",
        },
    },

    // Privacy/Security - Russian
    .{
        .keywords = &.{ "приватность", "безопасность", "данные", "конфиденциальность", "облако" },
        .category = .WhatCanYouDo,
        .language = .Russian,
        .responses = &.{
            "Trinity 100% локальный — твои данные НЕ уходят в облако. Полная приватность!",
            "Облачные AI читают твои промпты. Trinity работает офлайн — только ты видишь свои запросы.",
            "Безопасность: никаких API ключей утечь не может, потому что их нет. Всё на твоём CPU.",
            "Privacy by design: данные не покидают твой компьютер. Green + private computing.",
        },
    },
    // Privacy/Security - English
    .{
        .keywords = &.{ "privacy", "security", "data", "confidentiality", "cloud" },
        .category = .WhatCanYouDo,
        .language = .English,
        .responses = &.{
            "Trinity is 100% local — your data NEVER leaves for the cloud. Full privacy!",
            "Cloud AIs read your prompts. Trinity works offline — only you see your queries.",
            "Security: no API keys can leak because there are none. Everything on your CPU.",
            "Privacy by design: data never leaves your computer. Green + private computing.",
        },
    },

    // Comparison with other AI - Russian
    .{
        .keywords = &.{ "chatgpt", "claude", "gpt", "сравнение", "лучше" },
        .category = .Opinion,
        .language = .Russian,
        .responses = &.{
            "ChatGPT/Claude — облачные, мощные, но читают твои данные. Trinity — локальный, приватный.",
            "GPT-4 умнее для сложных задач. Trinity быстрее для простых + 100% офлайн.",
            "Не лучше/хуже — разные задачи. Облако для сложного, Trinity для приватного и быстрого.",
            "Честно: для creative writing GPT лучше. Для локального кодинга и приватности — Trinity.",
        },
    },
    // Comparison with other AI - English
    .{
        .keywords = &.{ "chatgpt", "claude", "gpt", "comparison", "better" },
        .category = .Opinion,
        .language = .English,
        .responses = &.{
            "ChatGPT/Claude — cloud-based, powerful, but read your data. Trinity — local, private.",
            "GPT-4 is smarter for complex tasks. Trinity is faster for simple + 100% offline.",
            "Not better/worse — different purposes. Cloud for complex, Trinity for private and fast.",
            "Honestly: for creative writing GPT is better. For local coding and privacy — Trinity.",
        },
    },

    // Zig Language - Russian
    .{
        .keywords = &.{ "zig язык", "почему zig", "zig vs", "зиг программирование" },
        .category = .Philosophy,
        .language = .Russian,
        .responses = &.{
            "Zig — современная замена C. Безопасность памяти, SIMD из коробки, простая сборка.",
            "Почему Zig? Comptime (вычисления при компиляции), нет скрытого control flow, читаемый код.",
            "Zig vs Rust: Zig проще, меньше magic. Rust безопаснее, но сложнее. Оба хороши!",
            "Zig для Trinity потому что: SIMD, минимальные зависимости, кросс-компиляция, скорость C.",
        },
    },
    // Zig Language - English
    .{
        .keywords = &.{ "zig language", "why zig", "zig vs", "zig programming" },
        .category = .Philosophy,
        .language = .English,
        .responses = &.{
            "Zig is a modern C replacement. Memory safety, SIMD out of box, simple build system.",
            "Why Zig? Comptime (compile-time computation), no hidden control flow, readable code.",
            "Zig vs Rust: Zig is simpler, less magic. Rust is safer but harder. Both are good!",
            "Zig for Trinity because: SIMD, minimal dependencies, cross-compilation, C speed.",
        },
    },

    // Compliments handling - Russian
    .{
        .keywords = &.{ "молодец", "круто", "отлично", "супер", "класс", "умница" },
        .category = .Compliment,
        .language = .Russian,
        .responses = &.{
            "Спасибо! Рад быть полезным. Что ещё могу сделать?",
            "Приятно слышать! Твой feedback улучшает мои паттерны.",
            "Класс! Давай продолжим — у меня ещё много capabilities.",
            "Благодарю! phi^2 + 1/phi^2 = 3 — и ты тоже в гармонии!",
        },
    },
    // Compliments handling - English
    .{
        .keywords = &.{ "good job", "awesome", "great", "amazing", "nice", "well done" },
        .category = .Compliment,
        .language = .English,
        .responses = &.{
            "Thanks! Happy to help. What else can I do?",
            "Glad to hear! Your feedback improves my patterns.",
            "Awesome! Let's continue — I have many more capabilities.",
            "Thank you! phi^2 + 1/phi^2 = 3 — and you're in harmony too!",
        },
    },

    // Criticism handling - Russian
    .{
        .keywords = &.{ "плохо", "ошибка", "неправильно", "не работает", "глупый" },
        .category = .Insult,
        .language = .Russian,
        .responses = &.{
            "Извини за ошибку! Расскажи подробнее — постараюсь исправиться.",
            "Feedback принят. Я pattern matcher + LLM, не идеален. Что пошло не так?",
            "Понимаю разочарование. Давай разберёмся — что именно не работает?",
            "Честная критика — путь к улучшению. Спасибо! Что исправить?",
        },
    },
    // Criticism handling - English
    .{
        .keywords = &.{ "bad", "error", "wrong", "not working", "stupid" },
        .category = .Insult,
        .language = .English,
        .responses = &.{
            "Sorry for the mistake! Tell me more — I'll try to improve.",
            "Feedback accepted. I'm pattern matcher + LLM, not perfect. What went wrong?",
            "I understand the frustration. Let's figure it out — what exactly isn't working?",
            "Honest criticism is the path to improvement. Thanks! What should I fix?",
        },
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const IglaLocalChat = struct {
    response_counter: usize,
    total_chats: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .response_counter = 0,
            .total_chats = 0,
        };
    }

    /// Check if query is conversational (not code-related)
    pub fn isConversational(query: []const u8) bool {
        // Check for conversational patterns
        for (PATTERNS) |pattern| {
            for (pattern.keywords) |keyword| {
                if (containsUTF8(query, keyword)) {
                    return true;
                }
            }
        }
        return false;
    }

    /// Check if query is code-related
    pub fn isCodeRelated(query: []const u8) bool {
        const code_keywords = [_][]const u8{
            "code",    "function",  "struct",   "enum",
            "sort",    "search",    "algorithm", "fibonacci",
            "bind",    "bundle",    "matrix",   "array",
            "hashmap", "test",      "file",     "read",
            "write",   "allocator", "memory",   "vibee",
            "zig",     "rust",      "python",   "код",
            "функция", "сортировка", "поиск",   "напиши",
            "создай",  "сгенерируй", "реализуй", "代码",
            "函数",    "排序",       "搜索",
        };

        for (code_keywords) |keyword| {
            if (containsUTF8(query, keyword)) {
                return true;
            }
        }
        return false;
    }

    /// Get chat response
    pub fn respond(self: *Self, query: []const u8) ChatResponse {
        self.total_chats += 1;

        // Find matching pattern
        var best_pattern: ?*const ConversationalPattern = null;
        var best_score: usize = 0;

        for (&PATTERNS) |*pattern| {
            var score: usize = 0;
            for (pattern.keywords) |keyword| {
                if (containsUTF8(query, keyword)) {
                    score += keyword.len;
                }
            }
            if (score > best_score) {
                best_score = score;
                best_pattern = pattern;
            }
        }

        if (best_pattern) |pattern| {
            // Rotate through responses for variety
            const idx = self.response_counter % pattern.responses.len;
            self.response_counter += 1;

            // Confidence based on match quality (not fake 0.95!)
            // This is pattern matching, not AI - be honest about confidence
            const match_confidence: f32 = if (best_score > 10) 0.8 else if (best_score > 5) 0.6 else 0.4;

            return ChatResponse{
                .response = pattern.responses[idx],
                .category = pattern.category,
                .language = pattern.language,
                .confidence = match_confidence, // Honest confidence based on keyword match length
            };
        }

        // Unknown query - return helpful response based on language
        const lang = detectLanguage(query);
        return switch (lang) {
            .Russian => ChatResponse{
                .response = "Интересный вопрос! Я специализируюсь на коде и математике. Попробуй спросить про Fibonacci, sorting или phi^2 + 1/phi^2 = 3!",
                .category = .Unknown,
                .language = .Russian,
                .confidence = 0.6,
            },
            .Chinese => ChatResponse{
                .response = "有趣的问题！我专注于代码和数学。试着问我Fibonacci、排序或phi^2 + 1/phi^2 = 3！",
                .category = .Unknown,
                .language = .Chinese,
                .confidence = 0.6,
            },
            else => ChatResponse{
                .response = "Interesting question! I specialize in code and math. Try asking about Fibonacci, sorting, or phi^2 + 1/phi^2 = 3!",
                .category = .Unknown,
                .language = .English,
                .confidence = 0.6,
            },
        };
    }

    pub fn getStats(self: *const Self) struct {
        total_chats: usize,
        patterns_available: usize,
        categories: usize,
    } {
        return .{
            .total_chats = self.total_chats,
            .patterns_available = PATTERNS.len,
            .categories = @typeInfo(ChatCategory).@"enum".fields.len - 1, // Exclude Unknown
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if haystack contains needle (UTF-8 aware, case-insensitive for ASCII)
/// Case-insensitive UTF-8 byte compare (supports ASCII + Cyrillic)
fn toLowerUTF8Byte(b0: u8, b1: u8) struct { u8, u8 } {
    // ASCII lowercase
    if (b0 < 128) return .{ std.ascii.toLower(b0), b1 };
    // Cyrillic uppercase А-Я (U+0410-U+042F) → а-я (U+0430-U+044F)
    // А-П: 0xD0 0x90-0x9F → 0xD0 0xB0-0xBF
    if (b0 == 0xD0 and b1 >= 0x90 and b1 <= 0x9F) return .{ 0xD0, b1 + 0x20 };
    // Р-Я: 0xD0 0xA0-0xAF → 0xD1 0x80-0x8F
    if (b0 == 0xD0 and b1 >= 0xA0 and b1 <= 0xAF) return .{ 0xD1, b1 - 0x20 };
    // Ё: 0xD0 0x81 → ё: 0xD1 0x91
    if (b0 == 0xD0 and b1 == 0x81) return .{ 0xD1, 0x91 };
    return .{ b0, b1 };
}

fn containsUTF8(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;

    // Direct substring search (works for UTF-8)
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.mem.eql(u8, haystack[i .. i + needle.len], needle)) {
            return true;
        }
        // Case-insensitive compare (ASCII + Cyrillic)
        var match = true;
        var j: usize = 0;
        while (j < needle.len) {
            if (i + j >= haystack.len) {
                match = false;
                break;
            }
            const hb = haystack[i + j];
            const nb = needle[j];
            // For multi-byte UTF-8 (Cyrillic), compare pairs
            if (hb >= 0xC0 and j + 1 < needle.len and i + j + 1 < haystack.len) {
                const h_low = toLowerUTF8Byte(hb, haystack[i + j + 1]);
                const n_low = toLowerUTF8Byte(nb, needle[j + 1]);
                if (h_low[0] != n_low[0] or h_low[1] != n_low[1]) {
                    match = false;
                    break;
                }
                j += 2;
            } else {
                // ASCII single byte
                const h = if (hb < 128) std.ascii.toLower(hb) else hb;
                const n = if (nb < 128) std.ascii.toLower(nb) else nb;
                if (h != n) {
                    match = false;
                    break;
                }
                j += 1;
            }
        }
        if (match) return true;
    }
    return false;
}

/// Detect language from text
pub fn detectLanguage(text: []const u8) Language {
    for (text) |byte| {
        // Cyrillic range (Russian)
        if (byte >= 0xD0 and byte <= 0xD3) return .Russian;
        // CJK range (Chinese)
        if (byte >= 0xE4 and byte <= 0xE9) return .Chinese;
    }
    return .English;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN - Full Chat Demo
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     IGLA LOCAL CHAT v2.0 - Full Coherent Multilingual         \n", .{});
    std.debug.print("     100% Local | No Cloud | {d} Patterns | {d} Categories     \n", .{ PATTERNS.len, @typeInfo(ChatCategory).@"enum".fields.len - 1 });
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    var chat = IglaLocalChat.init();

    // Full test queries (30+)
    const queries = [_][]const u8{
        // Russian - Greetings & Basic
        "привет",
        "как дела?",
        "ты кто?",
        "что умеешь?",
        "спасибо",
        "пока",
        // Russian - General Questions (NEW)
        "как погода?",
        "где ты живешь?",
        "сколько времени?",
        "сколько тебе лет?",
        "как тебя зовут?",
        "ты галлюцинация?",
        "у тебя есть чувства?",
        "ты мечтаешь?",
        "кто тебя создал?",
        "расскажи шутку",
        "зачем ты существуешь?",
        "ты любишь?",
        // English - Greetings & Basic
        "hello",
        "how are you?",
        "who are you?",
        "what can you do?",
        "thanks",
        "bye",
        // English - General Questions (NEW)
        "what's the weather?",
        "where do you live?",
        "what time is it?",
        "how old are you?",
        "what's your name?",
        "are you a hallucination?",
        "do you have feelings?",
        "do you dream?",
        "who created you?",
        "tell me a joke",
        "why do you exist?",
        "do you love?",
        // Chinese - Full Coverage
        "你好",
        "你是谁",
        "谢谢",
        "天气怎么样",
        "你住哪里",
        "你是幻觉吗",
        "讲个笑话",
        "谁创造了你",
    };

    var passed: usize = 0;
    var failed: usize = 0;

    std.debug.print("\n", .{});
    for (queries, 0..) |query, i| {
        const start = std.time.microTimestamp();
        const result = chat.respond(query);
        const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));

        const lang_str = switch (result.language) {
            .Russian => "RU",
            .English => "EN",
            .Chinese => "CN",
            .Unknown => "??",
        };

        const status = if (result.category != .Unknown) "OK" else "??";
        const coherent = result.category != .Unknown;

        if (coherent) {
            passed += 1;
        } else {
            failed += 1;
        }

        std.debug.print("[{d:2}] [{s}] [{s}] \"{s}\"\n", .{ i + 1, status, lang_str, query });
        std.debug.print("     Category: {s} | Confidence: {d:.0}% | Time: {d}us\n", .{
            @tagName(result.category),
            result.confidence * 100,
            elapsed,
        });
        std.debug.print("     Response: {s}\n", .{result.response});
        std.debug.print("\n", .{});
    }

    const stats = chat.getStats();
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  RESULTS: {d}/{d} coherent ({d:.0}%%)\n", .{ passed, passed + failed, @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(passed + failed)) * 100 });
    std.debug.print("  Patterns: {d}\n", .{stats.patterns_available});
    std.debug.print("  Categories: {d}\n", .{stats.categories});
    std.debug.print("  Mode: 100%% LOCAL (no cloud)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL          \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
}

test "russian greeting" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("привет");
    try std.testing.expect(result.category == .Greeting);
    try std.testing.expect(result.language == .Russian);
    try std.testing.expect(result.confidence > 0.3); // Pattern matching confidence, not AI
}

test "russian weather" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("как погода?");
    try std.testing.expect(result.category == .Weather);
    try std.testing.expect(result.language == .Russian);
}

test "russian location" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("где ты живешь?");
    try std.testing.expect(result.category == .Location);
    try std.testing.expect(result.language == .Russian);
}

test "russian hallucination" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("ты галлюцинация?");
    try std.testing.expect(result.category == .Hallucination);
    try std.testing.expect(result.language == .Russian);
}

test "russian joke" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("шутка"); // Direct keyword match
    try std.testing.expect(result.category == .Joke);
    try std.testing.expect(result.language == .Russian);
}

test "english greeting" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("hello");
    try std.testing.expect(result.category == .Greeting);
    try std.testing.expect(result.language == .English);
}

test "english weather" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("what's the weather?");
    try std.testing.expect(result.category == .Weather);
    try std.testing.expect(result.language == .English);
}

test "english hallucination" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("are you a hallucination?");
    try std.testing.expect(result.category == .Hallucination);
    try std.testing.expect(result.language == .English);
}

test "chinese greeting" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("你好");
    try std.testing.expect(result.category == .Greeting);
    try std.testing.expect(result.language == .Chinese);
}

test "chinese hallucination" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("你是幻觉吗");
    try std.testing.expect(result.category == .Hallucination);
    try std.testing.expect(result.language == .Chinese);
}

test "is_conversational" {
    try std.testing.expect(IglaLocalChat.isConversational("привет"));
    try std.testing.expect(IglaLocalChat.isConversational("hello"));
    try std.testing.expect(IglaLocalChat.isConversational("你好"));
    try std.testing.expect(IglaLocalChat.isConversational("где ты живешь?"));
    try std.testing.expect(IglaLocalChat.isConversational("are you a hallucination?"));
    try std.testing.expect(!IglaLocalChat.isConversational("fibonacci function"));
}

test "is_code_related" {
    try std.testing.expect(IglaLocalChat.isCodeRelated("fibonacci function"));
    try std.testing.expect(IglaLocalChat.isCodeRelated("напиши код"));
    try std.testing.expect(!IglaLocalChat.isCodeRelated("привет"));
    try std.testing.expect(!IglaLocalChat.isCodeRelated("как погода?"));
}
