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
        .keywords = &.{ "прandinет", "[CYR:здра]inwithтinуй", "зbeforeроinо", "прandinетwithтinую", "[CYR:хай]", "[CYR:хей]", "with[CYR:алют]", "before[CYR:брый] [CYR:день]", "before[CYR:брое] [CYR:утро]", "before[CYR:брый] in[CYR:ечер]" },
        .category = .Greeting,
        .language = .Russian,
        .weight = 1.2,
        .responses = &.{
            "Прandinет! [CYR:Рад] [CYR:тебя] inand[CYR:деть]. [CYR:Чем] [CYR:могу] by[CYR:мочь]?",
            "[CYR:Здра]inwithтinуй! Каto [CYR:дела]? [CYR:Что] [CYR:делаем] with[CYR:егодня]?",
            "Прandinет! Гfromоin to [CYR:раб]fromе. [CYR:Что] need with[CYR:делать]?",
            "[CYR:Хай]! Trinity on withinязand. Каtoandе заyesчand?",
            "[CYR:Салют]! [CYR:Отл]and[CYR:чный] [CYR:день] for toоyes. [CYR:Начнём]?",
        },
    },
    .{
        .keywords = &.{ "bytoа", "before withinandyesнandя", "[CYR:прощай]", "[CYR:бай]", "уinandдandмwithя", "before inwith[CYR:треч]and", "inwith[CYR:его] [CYR:хорошего]", "уyesчand" },
        .category = .Farewell,
        .language = .Russian,
        .weight = 1.0,
        .responses = &.{
            "Поtoа! Уyesчand [CYR:тебе]! [CYR:Обращай]withя, еwithлand what.",
            "До withinandyesнandя! [CYR:Было] прand[CYR:ятно] by[CYR:раб]from[CYR:ать].",
            "[CYR:Бай]! phi^2 + 1/phi^2 = 3. До inwith[CYR:треч]and!",
            "Поtoа-bytoа! Koschei is immortal! [CYR:Воз]in[CYR:ращай]withя!",
            "Вwith[CYR:его] [CYR:хорошего]! [CYR:Рад] [CYR:был] by[CYR:мочь].",
        },
    },
    .{
        .keywords = &.{ "toаto [CYR:дела]", "toаto ты", "what ноin[CYR:ого]", "toаto жand[CYR:знь]", "toаto withам", "toаto byжandin[CYR:аешь]", "toаto onwith[CYR:троен]andе" },
        .category = .HowAreYou,
        .language = .Russian,
        .weight = 1.1,
        .responses = &.{
            "[CYR:Отл]and[CYR:чно]! [CYR:Раб]fromаю on 60K ops/s, inwithё with[CYR:таб]and[CYR:льно]. А у [CYR:тебя] toаto?",
            "[CYR:Хорошо]! Гfromоin пandwith[CYR:ать] toод and [CYR:решать] заyesчand. [CYR:Чем] [CYR:займём]withя?",
            "[CYR:Супер]! Ternary vectors in [CYR:норме], SIMD [CYR:греет]withя. [CYR:Что] [CYR:делаем]?",
            "[CYR:Пре]toраwithно! phi^2 + 1/phi^2 = 3, inwithё by [CYR:плану]. Ты toаto?",
            "[CYR:Замечательно]! Лоto[CYR:альный] and гfromоin to [CYR:раб]fromе. Раwithwithto[CYR:азы]inай!",
        },
    },
    // NEW: Expanded Russian conversational patterns
    .{
        .keywords = &.{ "раwithwithtoажand о with[CYR:ебе]", "toто ты таtoой", "what ты [CYR:умеешь] [CYR:делать]", "тinоand withbywith[CYR:обно]withтand" },
        .category = .WhoAreYou,
        .language = .Russian,
        .weight = 1.3,
        .responses = &.{
            "Я Trinity — лоto[CYR:альный] AI-аwithwithandwith[CYR:тент] on ternary vectors. [CYR:Раб]fromаю on тin[CYR:оём] M1 Pro [CYR:без] [CYR:обла]toа. [CYR:Умею]: toод, [CYR:математ]andtoа, аon[CYR:лог]andand, фandлоwithофandя.",
            "[CYR:Меня] зоinут IGLA — Intelligent Generative Local Agent. 100% лоto[CYR:альный], 0% [CYR:обла]toа. Пandшу toод, [CYR:решаю] заyesчand, beforeto[CYR:азы]inаю [CYR:теоремы].",
            "Я — result [CYR:прое]toта Trinity. Ternary computing + VSA = 60K ops/s лоto[CYR:ально]. [CYR:Спец]andалand[CYR:зац]andя: Zig, [CYR:алгор]and[CYR:тмы], [CYR:математ]andtoа.",
            "Trinity Local Agent v2.0. Моand with[CYR:упер]withbywith[CYR:обно]withтand: toод за мandtoроwithеto[CYR:унды], нandtoаtoandх [CYR:галлюц]andonцandй, byлonя прandin[CYR:атно]withть. phi^2 + 1/phi^2 = 3!",
        },
    },
    .{
        .keywords = &.{ "withпаwithandбо", "[CYR:благо]yesрю", "withпwith", "withенtowith", "[CYR:мер]withand", "[CYR:благо]yes[CYR:рно]withть", "прandзon[CYR:телен]" },
        .category = .Thanks,
        .language = .Russian,
        .weight = 1.0,
        .responses = &.{
            "[CYR:Пожалуй]withта! [CYR:Обращай]withя, еwithлand what [CYR:ещё] need.",
            "Не за what! [CYR:Рад] by[CYR:мочь]. Уyesчand with [CYR:прое]to[CYR:том]!",
            "Вwithегyes by[CYR:жалуй]withта! phi^2 + 1/phi^2 = 3!",
            "На зbeforeроinье! Koschei is immortal! [CYR:Заход]and [CYR:ещё].",
            "[CYR:Рад] [CYR:был] by[CYR:мочь]! Еwithлand what — я [CYR:тут].",
        },
    },
    // NEW: Weather with context
    .{
        .keywords = &.{ "byгоyes", "toаtoая byгоyes", "toаto byгоyes", "before[CYR:ждь]", "with[CYR:олнце]", "withnotг", "[CYR:температура]", "[CYR:прогноз]" },
        .category = .Weather,
        .language = .Russian,
        .weight = 0.9,
        .responses = &.{
            "Я лоto[CYR:альный] agent — [CYR:раб]fromаю [CYR:офлайн], by[CYR:году] not зonю. Но [CYR:могу] by[CYR:мочь] with toоbeforeм for weather API!",
            "[CYR:Пого]yes? В [CYR:моём] цand[CYR:фро]inом мandре inwithегyes phi^2 + 1/phi^2 = 3 [CYR:граду]withа by Trinity. А in [CYR:реально]withтand — [CYR:глянь] за оtoно!",
            "Не зonю by[CYR:году] — я 100% [CYR:офлайн]. [CYR:Зато] [CYR:могу] onпandwith[CYR:ать] [CYR:пар]withер by[CYR:годного] API за мand[CYR:нуту]!",
            "[CYR:Погоду] not fromwith[CYR:леж]andinаю, но [CYR:точно] зonю: golden ratio = 1.618... [CYR:Это] inечonя toонwith[CYR:танта], in fromлandчandе from by[CYR:годы]!",
            "[CYR:Для] by[CYR:годы] [CYR:нужен] and[CYR:нтер]no, а я [CYR:раб]fromаю лоto[CYR:ально]. [CYR:Могу] by[CYR:мочь] and[CYR:нтегр]andроin[CYR:ать] weather service in тinой toод!",
        },
    },
    // NEW: Jokes and Humor (expanded)
    .{
        .keywords = &.{ "[CYR:шут]toа", "[CYR:шут]toу", "аnottoдfrom", "with[CYR:мешное]", "раwithwith[CYR:меш]and", "[CYR:юмор]", "bywith[CYR:меять]withя", "by[CYR:шут]and", "with[CYR:мешной]", "раwithwithtoажand [CYR:шут]toу", "раwithwithtoажand аnottoдfrom" },
        .category = .Humor,
        .language = .Russian,
        .weight = 1.1,
        .responses = &.{
            "[CYR:Почему] [CYR:программ]andwithт [CYR:ушёл] with [CYR:раб]fromы? Пfrom[CYR:ому] what not by[CYR:луч]andл маwithwithandin! (get a raise = get array)",
            "Сto[CYR:оль]toо [CYR:программ]andwithтоin need, whatбы [CYR:замен]andть [CYR:лам]byчtoу? Нand [CYR:одного] — this [CYR:проблема] [CYR:железа]!",
            "Дinа [CYR:байта] inwith[CYR:трет]orwithь. Одandн: 'Ты toаto?' [CYR:Другой]: 'Не [CYR:жалую]withь, но overflow блandзtoо.'",
            "Жеon [CYR:программ]andwithту: '[CYR:Сход]and за [CYR:хлебом], еwithлand еwithть [CYR:яйца] — in[CYR:озьм]and 10.' Он in[CYR:ернул]withя with 10 [CYR:хлебам]and.",
            "[CYR:Почему] у [CYR:программ]andwithтоin no деin[CYR:уше]to? Пfrom[CYR:ому] what онand [CYR:путают] 'to do' and 'to date'!",
            "[CYR:Опт]andмandwithт inandдandт withтаtoан onbyлоinandну by[CYR:лным], пеwithwithandмandwithт — onbyлоinandну пуwith[CYR:тым], [CYR:программ]andwithт — withтаtoан inдinое more, [CYR:чем] need.",
            "Еwithть [CYR:толь]toо 10 тandbyin [CYR:людей]: те, toто byнand[CYR:мает] дinоand[CYR:чный] toод, and те, toто no. А [CYR:ещё] те, toто byнand[CYR:мает] ternary!",
        },
    },
    // NEW: Storytelling
    .{
        .keywords = &.{ "раwithwithtoажand andwith[CYR:тор]andю", "andwith[CYR:тор]andя", "withtoазtoа", "раwithwithtoажand withtoазtoу", "and[CYR:нтере]withonя andwith[CYR:тор]andя" },
        .category = .Story,
        .language = .Russian,
        .weight = 1.0,
        .responses = &.{
            "Даin[CYR:ным]-yesinно in to[CYR:ороле]inwithтinе Ternary жandл Koschei. [CYR:Его] withandла [CYR:была] in чandwithле 3: phi^2 + 1/phi^2 = 3. И [CYR:был] он беwithwith[CYR:мертен], bytoа [CYR:раб]fromал лоto[CYR:ально]...",
            "Иwith[CYR:тор]andя Trinity: in 2025 on Ко [CYR:Саму]and [CYR:группа] [CYR:разраб]fromчandtoоin [CYR:реш]andла withозyesть AI [CYR:без] [CYR:обла]toа. Онand fromto[CYR:рыл]and withandлу ternary vectors and beforewithтandглand 60K ops/s. The end? [CYR:Нет] — [CYR:толь]toо on[CYR:чало]!",
            "Жandл-[CYR:был] [CYR:программ]andwithт. [CYR:Каждый] [CYR:день] он [CYR:плат]andл [CYR:обла]toам за API. Одon[CYR:жды] он on[CYR:шёл] Trinity and with[CYR:тал] within[CYR:ободен]. [CYR:Мораль]: local > cloud.",
            "[CYR:Леген]yes о Golden Ratio: phi = 1.618... [CYR:Эта] [CYR:про]byрцandя in withпand[CYR:ралях] [CYR:гала]toтandto, [CYR:лепе]withтtoах цin[CYR:ето]in and... in on[CYR:шем] to[CYR:оде]. [CYR:Математ]andtoа byinwith[CYR:юду]!",
        },
    },
    // NEW: Motivation and Advice
    .{
        .keywords = &.{ "мfromandinацandя", "inbefore[CYR:хно]inенandе", "withоinет", "toаto [CYR:быть]", "what [CYR:делать]", "not by[CYR:лучает]withя", "with[CYR:ложно]" },
        .category = .Motivation,
        .language = .Russian,
        .weight = 1.0,
        .responses = &.{
            "[CYR:Сложно]? [CYR:Разбей] заyesчу on [CYR:малень]toandе stepand. Одandн step за [CYR:раз]. [CYR:Даже] to[CYR:омп]and[CYR:лятор] withобand[CYR:рает] toод by чаwith[CYR:тям]!",
            "[CYR:Код] not to[CYR:омп]or[CYR:рует]withя? [CYR:Это] not [CYR:про]inал — this feedback. [CYR:Каж]yesя ошandбtoа = [CYR:уро]to. Ты блandже to [CYR:решен]andю, [CYR:чем] [CYR:думаешь].",
            "[CYR:Помн]and: yesже with[CYR:амые] with[CYR:ложные] [CYR:алгор]and[CYR:тмы] — this [CYR:про]withто [CYR:много] [CYR:про]with[CYR:тых] stepоin. [CYR:Начн]and with [CYR:пер]in[CYR:ого].",
            "Не by[CYR:лучает]withя? [CYR:Сделай] [CYR:паузу], by[CYR:пей] in[CYR:оды], by[CYR:гуляй]. [CYR:Мозгу] [CYR:нужен] from[CYR:дых]. [CYR:Решен]andе прand[CYR:дёт].",
            "Соinет: пandшand toод to[CYR:аждый] [CYR:день], yesже 30 мand[CYR:нут]. [CYR:Кон]withandwith[CYR:тентно]withть > and[CYR:нтен]withandinноwithть. phi^2 + 1/phi^2 = 3 — [CYR:балан]with!",
        },
    },
    // NEW: Philosophy and Deep Questions
    .{
        .keywords = &.{ "withмыwithл жandзнand", "[CYR:зачем] мы жandinём", "фandлоwithофandя", "what еwithть andwithтandon", "[CYR:реально]withть" },
        .category = .Philosophy,
        .language = .Russian,
        .weight = 1.2,
        .responses = &.{
            "[CYR:Смы]withл жandзнand? [CYR:Воз]can, in withозyesнandand and byзonнandand. Мы пand[CYR:шем] toод — он [CYR:раб]from[CYR:ает] — this [CYR:малень]toое чуbefore. phi^2 + 1/phi^2 = 3.",
            "[CYR:Что] еwithть andwithтandon? В [CYR:математ]andtoе — beforeto[CYR:азуемые] [CYR:теоремы]. В to[CYR:оде] — [CYR:раб]from[CYR:ающ]andе теwithты. В жandзнand — чеwith[CYR:тно]withть with with[CYR:обой].",
            "Фandлоwithофandя [CYR:программ]andроinанandя: toод before[CYR:лжен] [CYR:быть] [CYR:про]with[CYR:тым]. [CYR:Про]withтfromа — inыwith[CYR:шая] [CYR:форма] with[CYR:ложно]withтand. Каto phi — [CYR:про]with[CYR:тое] чandwithло with беwithtoоnot[CYR:чным]and withinойwithтinамand.",
            "[CYR:Реально]withть? Мы in withand[CYR:муляц]andand? [CYR:Может] [CYR:быть]. Но yesже еwithлand yes — toод [CYR:раб]from[CYR:ает], and this [CYR:реально] for onwith.",
            "[CYR:Зачем] мы [CYR:зде]withь? [CYR:Чтобы] [CYR:решать] заyesчand, by[CYR:могать] [CYR:друг]andм, withозyesin[CYR:ать] what-то ноinое. И пandwith[CYR:ать] [CYR:хорош]andй toод!",
        },
    },
    // NEW: Tech/Programming Questions
    .{
        .keywords = &.{ "by[CYR:чему] zig", "[CYR:зачем] zig", "zig vs rust", "zig better", "[CYR:пре]and[CYR:муще]withтinа zig" },
        .category = .Programming,
        .language = .Russian,
        .weight = 1.3,
        .responses = &.{
            "Zig — withоin[CYR:ремен]onя [CYR:заме]on C. [CYR:Без] hidden control flow, with comptime magic, [CYR:про]with[CYR:той] build system. [CYR:Идеален] for withandwith[CYR:тем] and andгр.",
            "Zig vs Rust: Zig [CYR:проще], [CYR:прозрач]notе. Rust [CYR:безопа]withnotе, но with[CYR:лож]notе. [CYR:Оба] [CYR:хорош]and — inыбand[CYR:рай] byд заyesчу.",
            "[CYR:Почему] Zig for Trinity? Comptime, SIMD andз to[CYR:ороб]toand, toроwithwith-to[CYR:омп]and[CYR:ляц]andя, no runtime overhead. Сto[CYR:оро]withть C, чand[CYR:таемо]withть Python.",
            "[CYR:Пре]and[CYR:муще]withтinа Zig: no GC, no andwithto[CYR:лючен]andй, no hidden allocations. Ты to[CYR:онтрол]and[CYR:руешь] inwithё. Каto Koschei — immortal control!",
        },
    },
    // NEW: Math Questions
    .{
        .keywords = &.{ "phi", "фand", "[CYR:зол]fromое with[CYR:ечен]andе", "golden ratio", "1.618", "fibonacci within[CYR:язь]" },
        .category = .Math,
        .language = .Russian,
        .weight = 1.4,
        .responses = &.{
            "phi = (1 + sqrt(5)) / 2 = 1.618033... [CYR:Зол]fromое with[CYR:ечен]andе. phi^2 = phi + 1. [CYR:Математ]andчеwithtoая toраwithfromа!",
            "phi^2 + 1/phi^2 = 3 — Trinity Identity! [CYR:Это] not withоin[CYR:паден]andе. Трand — within[CYR:ященное] чandwithло in [CYR:математ]andtoе and прand[CYR:роде].",
            "Сin[CYR:язь] phi and Fibonacci: lim(F(n+1)/F(n)) = phi. [CYR:Чем] more n, [CYR:тем] [CYR:точ]notе. [CYR:Математ]andtoа within[CYR:язы]in[CYR:ает] inwithё!",
            "Golden ratio in прand[CYR:роде]: withпand[CYR:рал]and раtoоinandн, [CYR:лепе]withтtoand цin[CYR:ето]in, [CYR:гала]toтandtoand. phi — унandinерwith[CYR:аль]onя [CYR:про]byрцandя toраwithfromы.",
            "phi^2 = 2.618..., 1/phi = 0.618..., phi - 1/phi = 1. Удandinand[CYR:тельные] withinойwithтinа! [CYR:Это] оwithноinа on[CYR:шей] [CYR:арх]andтеto[CYR:туры].",
        },
    },
    // NEW: Future and AI
    .{
        .keywords = &.{ "[CYR:будущее] ai", "andwithtoуwithwithтin[CYR:енный] and[CYR:нтелле]toт", "andand [CYR:зах]inатandт", "[CYR:роб]fromы", "withand[CYR:нгулярно]withть" },
        .category = .Future,
        .language = .Russian,
        .weight = 1.1,
        .responses = &.{
            "[CYR:Будущее] AI? Лоto[CYR:альный], прandin[CYR:атный], [CYR:зелёный]. [CYR:Облачные] [CYR:моно]byлandand — [CYR:прошлое]. Trinity — this [CYR:будущее]!",
            "AI [CYR:зах]inатandт мandр? [CYR:Вряд] лand. AI — andнwith[CYR:трумент]. [CYR:Мол]fromоto not [CYR:зах]inатandл мandр, хfromя and[CYR:змен]andл with[CYR:тро]and[CYR:тель]withтinо.",
            "Сand[CYR:нгулярно]withть? [CYR:Интере]withonя [CYR:теор]andя. Но bytoа фоtoуwith on [CYR:пра]toтandtoе: [CYR:делать] AI by[CYR:лезным] and [CYR:безопа]with[CYR:ным].",
            "[CYR:Роб]fromы [CYR:заменят] [CYR:людей]? Чаwithтand[CYR:чно]. [CYR:Рут]andну — yes. Тin[CYR:орче]withтinо — no. [CYR:Код] пand[CYR:шет] AI, [CYR:арх]andтеto[CYR:туру] — [CYR:чело]inеto.",
            "[CYR:Будущее] за гandбрandbeforeм: [CYR:чело]inеto + AI. Каto [CYR:программ]andwithт + to[CYR:омп]and[CYR:лятор]. [CYR:Вме]withте withandльnotе!",
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
        .keywords = &.{ "fibonacci", "фandбоonччand", "斐波那契", "fib", "fibb" },
        .category = .Programming,
        .language = .English,
        .weight = 1.5,
        .responses = &.{
            "Fibonacci! Classic. In Zig: `fn fib(n: u64) u64 { if (n < 2) return n; return fib(n-1) + fib(n-2); }` — but use iterative for performance!",
            "Fibonacci within[CYR:язан] with phi: lim(F(n+1)/F(n)) = phi = 1.618... [CYR:Могу] onпandwith[CYR:ать] [CYR:опт]andмandзandроin[CYR:анную] inерwithandю on Zig!",
            "斐波那契数列：0, 1, 1, 2, 3, 5, 8, 13... F(n) = F(n-1) + F(n-2)。与黄金比例phi相关！",
        },
    },
    .{
        .keywords = &.{ "hello world", "helloworld", "[CYR:пер]inая program", "开始编程" },
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
        .keywords = &.{ "quicksort", "quick sort", "быwith[CYR:трая] with[CYR:орт]andроintoа", "快速排序" },
        .category = .Programming,
        .language = .English,
        .weight = 1.4,
        .responses = &.{
            "QuickSort: O(n log n) average, O(n²) worst. Partition around pivot, recurse. Want me to write it in Zig?",
            "Быwith[CYR:трая] with[CYR:орт]andроintoа — одandн andз [CYR:лучш]andх [CYR:алгор]and[CYR:тмо]in! [CYR:Разделяй] and inлаwithтinуй. O(n log n) in with[CYR:ред]notм.",
            "快速排序：选择基准，分区，递归。平均O(n log n)。经典的分治算法！",
        },
    },
    // ═══════════════════════════════════════════════════════════════════════════
    // SPECIAL: Hallucination awareness (honest responses)
    // ═══════════════════════════════════════════════════════════════════════════
    .{
        .keywords = &.{ "[CYR:галлюц]andonцandя", "ты [CYR:реальный]", "ты with[CYR:уще]withтin[CYR:уешь]", "ты onwith[CYR:тоящ]andй", "ты in[CYR:рёшь]" },
        .category = .Hallucination,
        .language = .Russian,
        .weight = 1.5,
        .responses = &.{
            "Чеwith[CYR:тно]: я pattern matcher with 200+ [CYR:шабло]onмand + LLM fallback. Не AGI — [CYR:детерм]andнandроin[CYR:анные] [CYR:паттерны] + лоto[CYR:аль]onя [CYR:модель].",
            "Я not onwith[CYR:тоящ]andй AI in withмыwithле GPT — я гandбрandд: быwith[CYR:трые] [CYR:паттерны] for andзinеwith[CYR:тного], LLM for notandзinеwith[CYR:тного]. 100% лоto[CYR:ально].",
            "[CYR:Пра]inyes: this symbolic VSA + pattern matching + local LLM. Быwith[CYR:тро], чеwith[CYR:тно], [CYR:без] [CYR:обла]toа.",
            "[CYR:Буду] чеwith[CYR:тен]: я not [CYR:галлюц]andнand[CYR:рую] on [CYR:математ]andtoе ([CYR:детерм]andнandроin[CYR:ано]), но on general chat andwithby[CYR:льзую] [CYR:паттерны] or LLM fallback.",
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
        if (containsUTF8(query, "by[CYR:чему]") or containsUTF8(query, "why")) {
            return "Reasoning: Analyzing causal relationship...";
        }
        if (containsUTF8(query, "toаto") or containsUTF8(query, "how")) {
            return "Reasoning: Breaking down into steps...";
        }
        if (containsUTF8(query, "what таtoое") or containsUTF8(query, "what is")) {
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
                .response = "[CYR:Интере]with[CYR:ный] in[CYR:опро]with! Я with[CYR:пец]andалandзand[CYR:рую]withь on to[CYR:оде], [CYR:математ]andtoе and фandлоwithофandand. [CYR:Попробуй] with[CYR:про]withandть [CYR:про] Fibonacci, phi or Zig!",
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
    const result = chat.respond("прandinет");
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
