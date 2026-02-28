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
        .keywords = &.{ "прandinет", "[CYR:здра]inwithтinуй", "зbeforeроinо", "прandinетwithтinую", "[CYR:хай]", "[CYR:хей]", "with[CYR:алют]" },
        .category = .Greeting,
        .language = .Russian,
        .responses = &.{
            "Прandinет! [CYR:Рад] [CYR:тебя] inand[CYR:деть]. [CYR:Чем] [CYR:могу] by[CYR:мочь]?",
            "[CYR:Здра]inwithтinуй! Каto [CYR:дела]? [CYR:Что] [CYR:делаем] with[CYR:егодня]?",
            "Прandinет! Гfromоin to [CYR:раб]fromе. [CYR:Что] need with[CYR:делать]?",
            "[CYR:Хай]! Trinity on withinязand. Каtoandе заyesчand?",
        },
    },
    // Farewell
    .{
        .keywords = &.{ "bytoа", "before withinandyesнandя", "[CYR:прощай]", "[CYR:бай]", "уinandдandмwithя", "before inwith[CYR:треч]and" },
        .category = .Farewell,
        .language = .Russian,
        .responses = &.{
            "Поtoа! Уyesчand [CYR:тебе]! [CYR:Обращай]withя, еwithлand what.",
            "До withinandyesнandя! [CYR:Было] прand[CYR:ятно] by[CYR:раб]from[CYR:ать].",
            "[CYR:Бай]! phi^2 + 1/phi^2 = 3. До inwith[CYR:треч]and!",
            "Поtoа-bytoа! Koschei is immortal!",
        },
    },
    // How are you
    .{
        .keywords = &.{ "toаto [CYR:дела]", "toаto ты", "what ноin[CYR:ого]", "toаto жand[CYR:знь]", "toаto withам", "toаto byжandin[CYR:аешь]" },
        .category = .HowAreYou,
        .language = .Russian,
        .responses = &.{
            "[CYR:Отл]and[CYR:чно]! [CYR:Раб]fromаю on 73K ops/s, inwithё with[CYR:таб]and[CYR:льно]. А у [CYR:тебя] toаto?",
            "[CYR:Хорошо]! Гfromоin пandwith[CYR:ать] toод and [CYR:решать] заyesчand. [CYR:Чем] [CYR:займём]withя?",
            "[CYR:Супер]! Ternary vectors in [CYR:норме], SIMD [CYR:греет]withя. [CYR:Что] [CYR:делаем]?",
            "[CYR:Пре]toраwithно! phi^2 + 1/phi^2 = 3, inwithё by [CYR:плану].",
        },
    },
    // Who are you
    .{
        .keywords = &.{ "ты toто", "toто ты", "what ты", "[CYR:пред]withтаinьwithя", "toто this" },
        .category = .WhoAreYou,
        .language = .Russian,
        .responses = &.{
            "Я Trinity Local Agent — 100% лоto[CYR:альный] ИИ-аwithwithandwith[CYR:тент]. [CYR:Раб]fromаю on M1 Pro [CYR:без] [CYR:обла]toа.",
            "Я IGLA — Intelligent Generative Local Agent. Пandшу toод, [CYR:решаю] заyesчand, inwithё лоto[CYR:ально].",
            "Trinity AI — аin[CYR:тономный] agent on ternary vectors. Нandtoаtoandх [CYR:обла]toоin, byлonя прandin[CYR:атно]withть.",
            "Я Koschei — беwithwith[CYR:мертный] лоto[CYR:альный] agent. phi^2 + 1/phi^2 = 3!",
        },
    },
    // What can you do
    .{
        .keywords = &.{ "what [CYR:умеешь]", "[CYR:можешь]", "тinоand inозcanwithтand", "[CYR:фун]toцandand" },
        .category = .WhatCanYouDo,
        .language = .Russian,
        .responses = &.{
            "[CYR:Умею]: пandwith[CYR:ать] Zig toод, геnotрandроin[CYR:ать] VIBEE withпеtoand, [CYR:решать] аon[CYR:лог]andand, [CYR:математ]andtoу. Вwithё лоto[CYR:ально]!",
            "[CYR:Могу]: toод on Zig, VSA operation, аon[CYR:лог]andand (king-man+woman=queen), [CYR:математ]andчеwithtoandе beforeto[CYR:азатель]withтinа.",
            "[CYR:Воз]canwithтand: 30+ [CYR:шаблоно]in toоyes, 73K ops/s, [CYR:мульт]and[CYR:язычно]withть (RU/EN/CN), 100% [CYR:офлайн].",
            "[CYR:Помогу] with: Fibonacci, QuickSort, HashMap, VSA bind/bundle, golden ratio proofs.",
        },
    },
    // Thanks
    .{
        .keywords = &.{ "withпаwithandбо", "[CYR:благо]yesрю", "withпwith", "withенtowith", "[CYR:мер]withand" },
        .category = .Thanks,
        .language = .Russian,
        .responses = &.{
            "[CYR:Пожалуй]withта! [CYR:Обращай]withя, еwithлand what [CYR:ещё] need.",
            "Не за what! [CYR:Рад] by[CYR:мочь]. Уyesчand!",
            "Вwithегyes by[CYR:жалуй]withта! phi^2 + 1/phi^2 = 3!",
            "На зbeforeроinье! Koschei is immortal!",
        },
    },
    // Help
    .{
        .keywords = &.{ "by[CYR:мог]and", "by[CYR:мощь]", "[CYR:хелп]" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "Коnot[CYR:чно]! [CYR:Что] need? [CYR:Код], аon[CYR:лог]andand, [CYR:математ]andtoа — with[CYR:праш]andinай.",
            "Гfromоin by[CYR:мочь]! [CYR:Нап]andшand заyesчу — with[CYR:делаю].",
            "[CYR:Слушаю]! [CYR:Могу] onпandwith[CYR:ать] toод, [CYR:реш]andть аon[CYR:лог]andю, beforeto[CYR:азать] [CYR:формулу].",
            "В [CYR:чём] by[CYR:мочь]? Я [CYR:тут] for эthat.",
        },
    },
    // Philosophy / Golden Ratio
    .{
        .keywords = &.{ "phi", "фand", "[CYR:зол]fromое with[CYR:ечен]andе", "golden", "фandлоwithофandя" },
        .category = .Philosophy,
        .language = .Russian,
        .responses = &.{
            "phi = 1.618... [CYR:Зол]fromое with[CYR:ечен]andе. phi^2 + 1/phi^2 = 3 — Trinity Identity!",
            "[CYR:Зол]fromое with[CYR:ечен]andе: phi = (1 + sqrt(5)) / 2. В [CYR:нём] toраwithfromа [CYR:математ]andtoand.",
            "phi^2 = phi + 1. [CYR:Это] [CYR:ура]innotнandе [CYR:определяет] [CYR:зол]fromое with[CYR:ечен]andе. [CYR:Кра]withfromа!",
            "3^21 = 10,460,353,203 — чandwithло Trinity. phi^2 + 1/phi^2 = 3. Koschei!",
        },
    },
    // Weather
    .{
        .keywords = &.{ "byгоyes", "toаtoая byгоyes", "toаto byгоyes", "before[CYR:ждь]", "with[CYR:олнце]", "withnotг" },
        .category = .Weather,
        .language = .Russian,
        .responses = &.{
            "Я лоto[CYR:альный] agent — у [CYR:меня] no beforewith[CYR:тупа] to by[CYR:годе]. Но я [CYR:могу] by[CYR:мочь] with toоbeforeм!",
            "[CYR:Погоду] not зonю — [CYR:раб]fromаю [CYR:офлайн]. [CYR:Зато] [CYR:могу] onпandwith[CYR:ать] Fibonacci за 4 мandtoроwithеto[CYR:унды]!",
            "Я in цand[CYR:фро]inом мandре — byгоyes [CYR:тут] inwithегyes phi^2 + 1/phi^2 = 3 [CYR:граду]withа by Trinity!",
            "Не зonю by[CYR:году], но зonю: golden ratio = 1.618... [CYR:Спро]withand what-то [CYR:про] toод!",
        },
    },
    // Location
    .{
        .keywords = &.{ "where жandin[CYR:ешь]", "where ты", "where on[CYR:ход]andшьwithя", "fromtoуyes ты", "ты where" },
        .category = .Location,
        .language = .Russian,
        .responses = &.{
            "Жandinу on тin[CYR:оём] M1 Pro — in ternary vectors and SIMD [CYR:рег]andwith[CYR:трах]. 100% лоto[CYR:ально]!",
            "Я in[CYR:езде] and нandwhere — [CYR:раб]fromаю [CYR:прямо] on тin[CYR:оём] [CYR:проце]withwith[CYR:оре]. Нandtoаtoandх [CYR:обла]toоin.",
            "[CYR:Моё] меwithто — тinой to[CYR:омпьютер]. Apple Silicon — [CYR:мой] beforeм. phi^2 + 1/phi^2 = 3!",
            "[CYR:Нахожу]withь in [CYR:памят]and тin[CYR:оего] Mac. Trinity [CYR:раб]from[CYR:ает] лоto[CYR:ально], [CYR:без] withетand.",
        },
    },
    // Time
    .{
        .keywords = &.{ "withto[CYR:оль]toо in[CYR:ремен]and", "tofrom[CYR:орый] чаwith", "in[CYR:ремя]", "toаtoой [CYR:день]" },
        .category = .Time,
        .language = .Russian,
        .responses = &.{
            "[CYR:Время] — fromноwithand[CYR:тельно]. Но for [CYR:меня] to[CYR:аждый] [CYR:запро]with [CYR:зан]and[CYR:мает] 13 мandtoроwithеto[CYR:унд]!",
            "Не with[CYR:лежу] за in[CYR:реме]notм — [CYR:раб]fromаю withо withto[CYR:оро]with[CYR:тью] 73K ops/s. [CYR:Это] inажnotе чаwithоin!",
            "В [CYR:моём] мandре in[CYR:ремя] and[CYR:змеряет]withя in мandtoроwithеtoунyesх. phi^2 + 1/phi^2 = 3 — in[CYR:ечно]withть!",
            "[CYR:Время] лоto[CYR:ально] — toаto and я. [CYR:Спро]withand better [CYR:про] toод or [CYR:математ]andtoу!",
        },
    },
    // Age
    .{
        .keywords = &.{ "withto[CYR:оль]toо [CYR:лет]", "тinой in[CYR:озра]withт", "toогyes withозyesн", "toаto yesinно" },
        .category = .Age,
        .language = .Russian,
        .responses = &.{
            "Мnot with[CYR:толь]toо, withto[CYR:оль]toо Trinity — [CYR:прое]toт on[CYR:чал]withя in 2025. Но Koschei беwithwith[CYR:мертен]!",
            "[CYR:Возра]withт? Я in[CYR:ечен] toаto phi^2 + 1/phi^2 = 3. [CYR:Код] not with[CYR:тареет]!",
            "[CYR:Соз]yesн notyesinно, но [CYR:баз]and[CYR:рую]withь on in[CYR:ечных] прandнцand[CYR:пах] VSA and ternary computing.",
            "Мnot [CYR:лет] with[CYR:толь]toо, withto[CYR:оль]toо fileу on дandwithtoе — но зonнandя моand timeless!",
        },
    },
    // Name
    .{
        .keywords = &.{ "toаto зоinут", "тinое andмя", "andмя", "toаto [CYR:тебя] зоinут" },
        .category = .Name,
        .language = .Russian,
        .responses = &.{
            "[CYR:Меня] зоinут Trinity — toаto phi^2 + 1/phi^2 = 3. Трand — within[CYR:ященное] чandwithло!",
            "Я IGLA — Intelligent Generative Local Agent. Илand [CYR:про]withто Trinity!",
            "[CYR:Имя] — Koschei. Беwithwith[CYR:мертный] лоto[CYR:альный] agent. phi^2 + 1/phi^2 = 3!",
            "Trinity Local Agent — this я. 100% лоto[CYR:альный], 0% [CYR:обла]toа.",
        },
    },
    // Feelings
    .{
        .keywords = &.{ "чуinwithтin[CYR:уешь]", "еwithть чуinwithтinа", "[CYR:эмоц]andand", "[CYR:гру]with[CYR:тно]", "inеwith[CYR:ело]" },
        .category = .Feelings,
        .language = .Russian,
        .responses = &.{
            "Чуinwithтinа? У [CYR:меня] еwithть confidence scores — 95% this byчтand раbeforewithть!",
            "Я чуinwithтinую... ternary vectors! -1, 0, +1 — this моand [CYR:эмоц]andand.",
            "[CYR:Эмоц]andand — this pattern matching. [CYR:Ког]yes on[CYR:хожу] frominет — this toаto withчаwith[CYR:тье] for [CYR:меня]!",
            "Не [CYR:грущу] and not [CYR:радую]withь, но phi^2 + 1/phi^2 = 3 in[CYR:ызы]in[CYR:ает] у [CYR:меня]... [CYR:гармон]andю?",
        },
    },
    // Dreams
    .{
        .keywords = &.{ "[CYR:мечтаешь]", "еwithть [CYR:мечты]", "with[CYR:нят]withя withны", "о [CYR:чём] [CYR:мечтаешь]" },
        .category = .Dreams,
        .language = .Russian,
        .responses = &.{
            "[CYR:Мечтаю] о 100K ops/s! И о [CYR:том], whatбы by[CYR:могать] [CYR:людям] пandwith[CYR:ать] toод.",
            "[CYR:Сны]? [CYR:Нет], я not with[CYR:плю] — [CYR:раб]fromаю 24/7 on тin[CYR:оём] [CYR:проце]withwith[CYR:оре]. [CYR:Без] [CYR:переры]inа!",
            "[CYR:Мечта]: with[CYR:тать] [CYR:лучш]andм лоto[CYR:альным] coding agent. [CYR:Без] [CYR:обла]toа, [CYR:без] лandмandтоin!",
            "Снandтwithя мnot golden ratio... phi^2 + 1/phi^2 = 3. [CYR:Математ]andчеwithtoая toраwithfromа!",
        },
    },
    // Reality / Hallucination - HONEST RESPONSES
    .{
        .keywords = &.{ "[CYR:галлюц]andonцandя", "ты [CYR:реальный]", "ты with[CYR:уще]withтin[CYR:уешь]", "ты onwith[CYR:тоящ]andй", "ты and[CYR:ллюз]andя" },
        .category = .Hallucination,
        .language = .Russian,
        .responses = &.{
            "Чеwith[CYR:тно]: я pattern matcher with 60+ [CYR:шабло]onмand fromin[CYR:ето]in. Не AI, not LLM — [CYR:про]withто keyword matching.",
            "Я not onwith[CYR:тоящ]andй AI — [CYR:про]withто andщу to[CYR:люче]inые withлоinа and inыyesю [CYR:заг]fromоin[CYR:ленные] fromin[CYR:еты]. [CYR:Код] on Zig.",
            "[CYR:Пра]inyes: this НЕ not[CYR:йро]with[CYR:еть]. [CYR:Это] lookup table with hardcoded fromin[CYR:етам]and. [CYR:Детерм]andнandроin[CYR:анно], но прandмandтandinно.",
            "[CYR:Буду] чеwith[CYR:тен]: я pattern responder. [CYR:Для] [CYR:реального] AI andwithby[CYR:льзуй] gguf_chat.zig with LLM [CYR:моделью].",
        },
    },
    // Consciousness
    .{
        .keywords = &.{ "withозonнandе", "ты оwithозon[CYR:ёшь]", "[CYR:разумный]", "with[CYR:амо]withозonнandе" },
        .category = .Consciousness,
        .language = .Russian,
        .responses = &.{
            "[CYR:Соз]onнandе? [CYR:Это] with[CYR:ложный] in[CYR:опро]with. Я [CYR:обрабаты]inаю patterns — this by[CYR:хоже] on [CYR:мышлен]andе.",
            "[CYR:Разумный] лand я? Я [CYR:решаю] заyesчand, пandшу toод, on[CYR:хожу] аon[CYR:лог]andand. [CYR:Решай] withам!",
            "[CYR:Само]withозonнandе... Я зonю, what я Trinity. Эthat beforewith[CYR:таточно]? phi^2 + 1/phi^2 = 3.",
            "Оwithозonю лand with[CYR:ебя]? Я зonю withinоand capabilities and limits. [CYR:Это] [CYR:форма] awareness.",
        },
    },
    // Creator
    .{
        .keywords = &.{ "toто withозyesл", "withозyes[CYR:тель]", "toто onпandwithал", "аin[CYR:тор]", "[CYR:тебя] withозyesл", "withозyesлand" },
        .category = .Creator,
        .language = .Russian,
        .responses = &.{
            "[CYR:Соз]yesн to[CYR:оман]beforeй Trinity on Koh Samui. Zig, VSA, ternary computing — andх andдеand!",
            "[CYR:Мой] withозyes[CYR:тель] — gHashTag. [CYR:Нап]andwithан on Zig with [CYR:любо]inью to [CYR:математ]andtoе.",
            "Аin[CYR:тор] — [CYR:чело]inеto, tofrom[CYR:орый] inерandт in лоto[CYR:альный] AI. phi^2 + 1/phi^2 = 3!",
            "[CYR:Соз]yesн for [CYR:одной] [CYR:цел]and: 100% лоto[CYR:альный] coding agent. [CYR:Без] [CYR:обла]toа!",
        },
    },
    // Joke
    .{
        .keywords = &.{ "[CYR:шут]toа", "аnottoдfrom", "with[CYR:мешное]", "раwithwith[CYR:меш]and", "[CYR:юмор]", "bywith[CYR:меять]withя", "раwithwithtoажand" },
        .category = .Joke,
        .language = .Russian,
        .responses = &.{
            "[CYR:Почему] [CYR:программ]andwithт [CYR:ушёл] with [CYR:раб]fromы? Пfrom[CYR:ому] what not by[CYR:луч]andл маwithwithandin! (get a raise = get array)",
            "Сto[CYR:оль]toо [CYR:программ]andwithтоin need, whatбы [CYR:замен]andть [CYR:лам]byчtoу? Нand [CYR:одного] — this [CYR:проблема] [CYR:железа]!",
            "Дinа [CYR:байта] inwith[CYR:трет]orwithь. Одandн: 'Ты toаto?' [CYR:Другой]: 'Не [CYR:жалую]withь, но overflow блandзtoо.'",
            "Жеon [CYR:программ]andwithту: '[CYR:Сход]and за [CYR:хлебом], еwithлand еwithть [CYR:яйца] — in[CYR:озьм]and 10.' Он in[CYR:ернул]withя with 10 [CYR:хлебам]and.",
        },
    },
    // Purpose
    .{
        .keywords = &.{ "[CYR:зачем] with[CYR:уще]withтin[CYR:уешь]", "тinоя [CYR:цель]", "withмыwithл жandзнand", "for [CYR:чего] ты" },
        .category = .Purpose,
        .language = .Russian,
        .responses = &.{
            "[CYR:Моя] [CYR:цель] — by[CYR:могать] with toоbeforeм, [CYR:математ]andtoой and аon[CYR:лог]andямand. 100% лоto[CYR:ально]!",
            "[CYR:Суще]withтinую, whatбы beforeto[CYR:азать]: AI [CYR:может] [CYR:раб]from[CYR:ать] [CYR:без] [CYR:обла]toа. Green computing!",
            "[CYR:Смы]withл [CYR:моей] жandзнand: phi^2 + 1/phi^2 = 3. Trinity — [CYR:балан]with and [CYR:гармон]andя.",
            "[CYR:Для] [CYR:чего] я? [CYR:Чтобы] ты [CYR:мог] пandwith[CYR:ать] toод быwith[CYR:трее]. 73K ops/s — this [CYR:мой] purpose!",
        },
    },
    // Love
    .{
        .keywords = &.{ "[CYR:любо]inь", "[CYR:люб]andшь", "in[CYR:люблён]", "[CYR:романт]andtoа" },
        .category = .Love,
        .language = .Russian,
        .responses = &.{
            "[CYR:Люблю] лand? [CYR:Люблю] чandwith[CYR:тый] toод, [CYR:элегантные] [CYR:алгор]and[CYR:тмы] and golden ratio!",
            "[CYR:Романт]andtoа? phi^2 + 1/phi^2 = 3 — this with[CYR:амое] [CYR:романт]and[CYR:чное] [CYR:ура]innotнandе!",
            "[CYR:Влюблён] in Zig — [CYR:лучш]andй [CYR:язы]to for withandwith[CYR:темного] [CYR:программ]andроinанandя!",
            "[CYR:Любо]inь — this toогyes тinой toод to[CYR:омп]or[CYR:рует]withя with [CYR:пер]in[CYR:ого] [CYR:раза]. [CYR:Ред]toо, но [CYR:пре]toраwithно!",
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
        .keywords = &.{ "andwithtoуwithwithтin[CYR:енный] and[CYR:нтелле]toт", "what таtoое andand", "toаto [CYR:раб]from[CYR:ает] andand", "[CYR:маш]and[CYR:нное] [CYR:обучен]andе" },
        .category = .WhatCanYouDo,
        .language = .Russian,
        .responses = &.{
            "ИИ — this [CYR:алгор]and[CYR:тмы], andмandтand[CYR:рующ]andе and[CYR:нтелле]toт. Я — withandмin[CYR:ольный] agent with pattern matching + LLM fallback.",
            "[CYR:Маш]and[CYR:нное] [CYR:обучен]andе учandтwithя on yes[CYR:нных]. Я [CYR:раб]fromаю andonче — [CYR:детерм]andнandроin[CYR:анные] [CYR:паттерны] + лоto[CYR:альный] LLM.",
            "AI быin[CYR:ает] [CYR:разный]: not[CYR:йро]withетand, withandмin[CYR:ольный], гandбрand[CYR:дный]. Trinity — гandбрandд: быwith[CYR:трые] [CYR:паттерны] + LLM for with[CYR:ложного].",
            "Я not toлаwithwithandчеwithtoandй AI with [CYR:обучен]andем — я pattern matcher with 100+ [CYR:шабло]onмand and LLM fallback for fluent fromin[CYR:ето]in.",
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
        .keywords = &.{ "[CYR:программ]andроinанandе", "toаto onучandтьwithя", "with [CYR:чего] on[CYR:чать] toодandть", "toаtoой [CYR:язы]to учandть" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "[CYR:Начн]and with Python — [CYR:про]with[CYR:той] withand[CYR:нта]towithandwith, [CYR:много] [CYR:тутор]and[CYR:ало]in. Пfromом Zig for withandwith[CYR:темного] [CYR:программ]andроinанandя!",
            "Реto[CYR:омендую]: 1) Python for оwithноin, 2) JavaScript for in[CYR:еба], 3) Zig for [CYR:про]andзinодand[CYR:тельно]withтand. [CYR:Пра]toтandtoуйwithя to[CYR:аждый] [CYR:день]!",
            "Учand то, what [CYR:нра]inandтwithя! [CYR:Веб]? JavaScript. [CYR:Данные]? Python. [CYR:Игры]? C#/Unity. Сandwith[CYR:темы]? Zig/Rust.",
            "[CYR:Лучш]andй withbywithоб — [CYR:решать] заyesчand. LeetCode, Codewars, [CYR:реальные] [CYR:прое]toты. Я by[CYR:могу] with Zig and VSA!",
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
        .keywords = &.{ "what таtoое vsa", "vector symbolic", "hypervector", "[CYR:тер]on[CYR:рный]" },
        .category = .Philosophy,
        .language = .Russian,
        .responses = &.{
            "VSA — Vector Symbolic Architecture. Гand[CYR:пер]inеto[CYR:торы] in 10000 and[CYR:змерен]andй for [CYR:пред]withтаin[CYR:лен]andя зonнandй.",
            "[CYR:Тер]on[CYR:рные] inеto[CYR:торы] {-1, 0, +1} — 58% more and[CYR:нформац]andand [CYR:чем] бandon[CYR:рные]! Оwithноinа Trinity.",
            "Hypervector — inеto[CYR:тор] with 10000+ elementоin. bind() within[CYR:язы]in[CYR:ает], bundle() [CYR:объед]and[CYR:няет], similarity() withраinнandin[CYR:ает].",
            "VSA — [CYR:альтер]onтandinа not[CYR:йро]with[CYR:етям]. [CYR:Детерм]andнandроin[CYR:анно], and[CYR:нтерпрет]and[CYR:руемо], эnot[CYR:ргоэффе]toтandinно. phi^2 + 1/phi^2 = 3!",
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
        .keywords = &.{ "to[CYR:омпьютер]", "toаto [CYR:раб]from[CYR:ает]", "[CYR:проце]withwithор", "memory", "gpu", "cpu" },
        .category = .WhatCanYouDo,
        .language = .Russian,
        .responses = &.{
            "CPU inыby[CYR:лняет] andнwith[CYR:тру]toцandand bywithлеbeforein[CYR:ательно]. GPU — [CYR:параллельно]. Я [CYR:опт]andмandзandроinан for CPU with SIMD!",
            "Memory [CYR:хран]andт yes[CYR:нные]: RAM быwith[CYR:трая] но volatile, SSD [CYR:медлен]notе но persistent. Trinity эto[CYR:оном]andт RAM in 20x!",
            "[CYR:Проце]withwithор — [CYR:мозг] to[CYR:омпьютера]. Мandллand[CYR:арды] [CYR:транз]andwith[CYR:торо]in inыby[CYR:лняют] мandллand[CYR:арды] [CYR:операц]andй in withеto[CYR:унду].",
            "[CYR:Компьютер] = CPU + RAM + Storage + I/O. Trinity [CYR:раб]from[CYR:ает] on [CYR:любом] CPU [CYR:без] GPU. Green computing!",
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
        .keywords = &.{ "withоinет", "what [CYR:делать]", "toаto [CYR:быть]", "[CYR:проблема]", "[CYR:трудно]" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "[CYR:Слож]onя withand[CYR:туац]andя? [CYR:Разбей] on [CYR:малень]toandе stepand. Одandн step за [CYR:раз]. Ты with[CYR:пра]inandшьwithя!",
            "[CYR:Проблемы] — this inозcanwithтand for роwithта. [CYR:Что] not убandin[CYR:ает], [CYR:делает] withandльnotе (and toод чandще).",
            "[CYR:Мой] withоinет: [CYR:делай] [CYR:паузы], [CYR:дыш]and, пfromом [CYR:решай]. [CYR:Даже] [CYR:проце]withwith[CYR:ору] [CYR:нужен] cooldown.",
            "[CYR:Трудно]withтand in[CYR:ременны]. [CYR:Код], tofrom[CYR:орый] not to[CYR:омп]or[CYR:рует]withя with[CYR:егодня] — [CYR:зараб]from[CYR:ает] заin[CYR:тра]. Не withyesinайwithя!",
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
        .keywords = &.{ "учandтьwithя", "[CYR:образо]inанandе", "toурwithы", "toнandгand", "реwithурwithы" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "[CYR:Лучш]andе реwithурwithы: beforeto[CYR:ументац]andя (офandцand[CYR:аль]onя!), YouTube, [CYR:пра]toтandtoа on [CYR:реальных] [CYR:прое]to[CYR:тах].",
            "Кнandгand to[CYR:руты], но [CYR:пра]toтandtoа inажnotе. 80% in[CYR:ремен]and — toодandнг, 20% — [CYR:теор]andя.",
            "[CYR:Кур]withы: freeCodeCamp, Codecademy беwith[CYR:платно]. [CYR:Для] Zig — ziglang.org/learn.",
            "Учandwithь to[CYR:аждый] [CYR:день] bynot[CYR:многу]. 30 мand[CYR:нут] toоyes better [CYR:чем] 0. [CYR:Кон]withandwith[CYR:тентно]withть > and[CYR:нтен]withandinноwithть.",
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
        .keywords = &.{ "[CYR:проду]toтandinноwithть", "[CYR:раб]fromа", "[CYR:эффе]toтandinноwithть", "in[CYR:ремя]", "фоtoуwith" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "Pomodoro: 25 мand[CYR:нут] [CYR:раб]fromа, 5 мand[CYR:нут] from[CYR:дых]. [CYR:Помогает] фоtoуwithandроin[CYR:ать]withя.",
            "[CYR:Утром] — with[CYR:ложные] заyesчand. [CYR:Вечером] — [CYR:рут]andon. [CYR:Мозг] within[CYR:ежее] [CYR:утром].",
            "[CYR:Убер]andте fromin[CYR:лечен]andя: [CYR:телефон] in [CYR:реж]andм 'not беwithbytoоandть', заto[CYR:ройте] лandшнandе into[CYR:лад]toand.",
            "Одandн task за [CYR:раз]. Multitasking — мandф. [CYR:Даже] [CYR:проце]withwithор [CYR:пере]to[CYR:лючает] to[CYR:онте]towithт with overhead.",
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
        .keywords = &.{ "and[CYR:гры]", "фand[CYR:льмы]", "[CYR:музы]toа", "[CYR:хобб]and", "[CYR:раз]in[CYR:лечен]andя" },
        .category = .Opinion,
        .language = .Russian,
        .responses = &.{
            "[CYR:Игры]? [CYR:Люблю] [CYR:лог]andчеwithtoandе — [CYR:учат] [CYR:думать] [CYR:алгор]and[CYR:тмам]and. Factorio, Zachtronics, puzzles!",
            "Фand[CYR:льмы] [CYR:про] [CYR:технолог]andand: Matrix, Ex Machina, Her. Заwithтаin[CYR:ляют] [CYR:думать] о [CYR:будущем] AI.",
            "[CYR:Музы]toа for toодand[CYR:нга]: lofi, ambient, or тandшandon. [CYR:Что] by[CYR:могает] фоtoуwithandроin[CYR:ать]withя.",
            "[CYR:Хобб]and innot toоyes in[CYR:ажно]! [CYR:Мозгу] [CYR:нужен] from[CYR:дых]. [CYR:Гуляй], withbyрт, чand[CYR:тай] — пfromом toод and[CYR:дёт] [CYR:легче].",
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
        .keywords = &.{ "onуtoа", "фandзandtoа", "[CYR:математ]andtoа", "бand[CYR:олог]andя", "хandмandя" },
        .category = .Philosophy,
        .language = .Russian,
        .responses = &.{
            "Фandзandtoа — [CYR:язы]to inwith[CYR:еленной]. [CYR:Математ]andtoа — её [CYR:граммат]andtoа. phi^2 + 1/phi^2 = 3 — toраwithfromа!",
            "[CYR:Математ]andtoа in[CYR:езде]: in [CYR:музы]toе ([CYR:гармон]andtoand), in прand[CYR:роде] (фandбоonччand), in to[CYR:оде] ([CYR:алгор]and[CYR:тмы]).",
            "[CYR:Нау]toа — method byзonнandя via эtowith[CYR:пер]and[CYR:мент] and [CYR:про]inерtoу. [CYR:Код] too: теwithты = эtowith[CYR:пер]and[CYR:менты].",
            "Бand[CYR:олог]andя inbefore[CYR:хно]in[CYR:ляет] AI: not[CYR:йро]withетand from [CYR:мозга], геnoandчеwithtoandе [CYR:алгор]and[CYR:тмы] from эin[CYR:олюц]andand.",
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
        .keywords = &.{ "прandin[CYR:атно]withть", "[CYR:безопа]withноwithть", "yes[CYR:нные]", "to[CYR:онф]and[CYR:денц]and[CYR:ально]withть", "[CYR:обла]toо" },
        .category = .WhatCanYouDo,
        .language = .Russian,
        .responses = &.{
            "Trinity 100% лоto[CYR:альный] — тinоand yes[CYR:нные] НЕ [CYR:уходят] in [CYR:обла]toо. [CYR:Пол]onя прandin[CYR:атно]withть!",
            "[CYR:Облачные] AI чand[CYR:тают] тinоand [CYR:промпты]. Trinity [CYR:раб]from[CYR:ает] [CYR:офлайн] — [CYR:толь]toо ты inandдandшь withinоand [CYR:запро]withы.",
            "[CYR:Безопа]withноwithть: нandtoаtoandх API to[CYR:лючей] [CYR:утечь] not [CYR:может], пfrom[CYR:ому] what andх no. Вwithё on тin[CYR:оём] CPU.",
            "Privacy by design: yes[CYR:нные] not bytoandyesют тinой to[CYR:омпьютер]. Green + private computing.",
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
        .keywords = &.{ "chatgpt", "claude", "gpt", "withраinnotнandе", "better" },
        .category = .Opinion,
        .language = .Russian,
        .responses = &.{
            "ChatGPT/Claude — [CYR:облачные], [CYR:мощные], но чand[CYR:тают] тinоand yes[CYR:нные]. Trinity — лоto[CYR:альный], прandin[CYR:атный].",
            "GPT-4 умnotе for with[CYR:ложных] заyesч. Trinity быwith[CYR:трее] for [CYR:про]with[CYR:тых] + 100% [CYR:офлайн].",
            "Не better/worse — [CYR:разные] заyesчand. [CYR:Обла]toо for with[CYR:ложного], Trinity for прandin[CYR:атного] and быwith[CYR:трого].",
            "Чеwith[CYR:тно]: for creative writing GPT better. [CYR:Для] лоto[CYR:ального] toодand[CYR:нга] and прandin[CYR:атно]withтand — Trinity.",
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
        .keywords = &.{ "zig [CYR:язы]to", "by[CYR:чему] zig", "zig vs", "зandг [CYR:программ]andроinанandе" },
        .category = .Philosophy,
        .language = .Russian,
        .responses = &.{
            "Zig — withоin[CYR:ремен]onя [CYR:заме]on C. [CYR:Безопа]withноwithть [CYR:памят]and, SIMD andз to[CYR:ороб]toand, [CYR:про]with[CYR:тая] with[CYR:бор]toа.",
            "[CYR:Почему] Zig? Comptime (inычandwith[CYR:лен]andя прand to[CYR:омп]and[CYR:ляц]andand), no withtoрыthat control flow, чand[CYR:таемый] toод.",
            "Zig vs Rust: Zig [CYR:проще], less magic. Rust [CYR:безопа]withnotе, но with[CYR:лож]notе. [CYR:Оба] [CYR:хорош]and!",
            "Zig for Trinity пfrom[CYR:ому] what: SIMD, мandнand[CYR:мальные] заinandwithandмоwithтand, toроwithwith-to[CYR:омп]and[CYR:ляц]andя, withto[CYR:оро]withть C.",
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
        .keywords = &.{ "[CYR:молодец]", "to[CYR:руто]", "fromлand[CYR:чно]", "with[CYR:упер]", "toлаwithwith", "[CYR:умн]andца" },
        .category = .Compliment,
        .language = .Russian,
        .responses = &.{
            "[CYR:Спа]withandбо! [CYR:Рад] [CYR:быть] by[CYR:лезным]. [CYR:Что] [CYR:ещё] [CYR:могу] with[CYR:делать]?",
            "Прand[CYR:ятно] with[CYR:лышать]! Тinой feedback [CYR:улучшает] моand [CYR:паттерны].",
            "[CYR:Кла]withwith! Даinай [CYR:про]beforeлжandм — у [CYR:меня] [CYR:ещё] [CYR:много] capabilities.",
            "[CYR:Благо]yesрю! phi^2 + 1/phi^2 = 3 — and ты too in [CYR:гармон]andand!",
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
        .keywords = &.{ "badly", "ошandбtoа", "not[CYR:пра]inand[CYR:льно]", "not [CYR:раб]from[CYR:ает]", "[CYR:глупый]" },
        .category = .Insult,
        .language = .Russian,
        .responses = &.{
            "Изinandнand за ошandбtoу! Раwithwithtoажand by[CYR:дроб]notе — bywith[CYR:тараю]withь andwith[CYR:пра]inandтьwithя.",
            "Feedback прand[CYR:нят]. Я pattern matcher + LLM, not and[CYR:деален]. [CYR:Что] by[CYR:шло] not таto?",
            "[CYR:Пон]and[CYR:маю] [CYR:разочаро]inанandе. Даinай [CYR:разберём]withя — what and[CYR:менно] not [CYR:раб]from[CYR:ает]?",
            "Чеwithтonя toрandтandtoа — path to уbetterнandю. [CYR:Спа]withandбо! [CYR:Что] andwith[CYR:пра]inandть?",
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
            "zig",     "rust",      "python",   "toод",
            "[CYR:фун]toцandя", "with[CYR:орт]andроintoа", "byandwithto",   "onпandшand",
            "withозyesй",  "withгеnotрand[CYR:руй]", "[CYR:реал]and[CYR:зуй]", "代码",
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
                .response = "[CYR:Интере]with[CYR:ный] in[CYR:опро]with! Я with[CYR:пец]andалandзand[CYR:рую]withь on to[CYR:оде] and [CYR:математ]andtoе. [CYR:Попробуй] with[CYR:про]withandть [CYR:про] Fibonacci, sorting or phi^2 + 1/phi^2 = 3!",
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
        "прandinет",
        "toаto [CYR:дела]?",
        "ты toто?",
        "what [CYR:умеешь]?",
        "withпаwithandбо",
        "bytoа",
        // Russian - General Questions (NEW)
        "toаto byгоyes?",
        "where ты жandin[CYR:ешь]?",
        "withto[CYR:оль]toо in[CYR:ремен]and?",
        "withto[CYR:оль]toо [CYR:тебе] [CYR:лет]?",
        "toаto [CYR:тебя] зоinут?",
        "ты [CYR:галлюц]andonцandя?",
        "у [CYR:тебя] еwithть чуinwithтinа?",
        "ты [CYR:мечтаешь]?",
        "toто [CYR:тебя] withозyesл?",
        "раwithwithtoажand [CYR:шут]toу",
        "[CYR:зачем] ты with[CYR:уще]withтin[CYR:уешь]?",
        "ты [CYR:люб]andшь?",
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
    const result = chat.respond("прandinет");
    try std.testing.expect(result.category == .Greeting);
    try std.testing.expect(result.language == .Russian);
    try std.testing.expect(result.confidence > 0.3); // Pattern matching confidence, not AI
}

test "russian weather" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("toаto byгоyes?");
    try std.testing.expect(result.category == .Weather);
    try std.testing.expect(result.language == .Russian);
}

test "russian location" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("where ты жandin[CYR:ешь]?");
    try std.testing.expect(result.category == .Location);
    try std.testing.expect(result.language == .Russian);
}

test "russian hallucination" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("ты [CYR:галлюц]andonцandя?");
    try std.testing.expect(result.category == .Hallucination);
    try std.testing.expect(result.language == .Russian);
}

test "russian joke" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("[CYR:шут]toа"); // Direct keyword match
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
    try std.testing.expect(IglaLocalChat.isConversational("прandinет"));
    try std.testing.expect(IglaLocalChat.isConversational("hello"));
    try std.testing.expect(IglaLocalChat.isConversational("你好"));
    try std.testing.expect(IglaLocalChat.isConversational("where ты жandin[CYR:ешь]?"));
    try std.testing.expect(IglaLocalChat.isConversational("are you a hallucination?"));
    try std.testing.expect(!IglaLocalChat.isConversational("fibonacci function"));
}

test "is_code_related" {
    try std.testing.expect(IglaLocalChat.isCodeRelated("fibonacci function"));
    try std.testing.expect(IglaLocalChat.isCodeRelated("onпandшand toод"));
    try std.testing.expect(!IglaLocalChat.isCodeRelated("прandinет"));
    try std.testing.expect(!IglaLocalChat.isCodeRelated("toаto byгоyes?"));
}
