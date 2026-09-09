// The modules of the Queen's shell, and the only place their identity is
// written down.
//
// One entry is one module: the glyph the rail draws, the key that opens it (the
// digits 1-0 are taken by the first ten; later modules use a letter, named in
// their hint),
// the one-line hint the rail shows, and a paragraph saying what that view
// actually shows — checked against the view, not against its name. The homepage
// renders one identical block per entry and the shell answers `?tab=` for each,
// so a seventh module is a seventh entry here and nothing else: no new
// component, no new section, no new link to remember.
//
// `screen` says how the block shows it. Every module is an iframe of the shell
// at ?tab=<tab>&embed=1; the comb additionally needs the 3D scene, which embed
// mode otherwise skips so that a page full of previews is not a page full of
// WebGL contexts.
export const MODULES = [
  {
    tab: 'comb',
    key: '1',
    glyph: '▽',
    en: {
      name: 'COMB',
      hint: 'The board as a field of marks',
      body: 'The shared map. Every gold cell is a .t27 spec, every red one a GitHub issue that pays for it, and the gold line between two cells is the same spec in the shared core and in the repository it came from. Click a cell to read the spec itself over the map.',
    },
    ru: {
      name: 'СОТЫ',
      hint: 'Доска как поле меток',
      body: 'Общая карта. Каждая золотая сота — спека .t27, каждая красная — GitHub issue, которая за неё платит, а золотая линия между сотами — одна и та же спека в общем ядре и в репозитории-источнике. Клик по соте открывает саму спеку поверх карты.',
    },
  },
  {
    tab: 'specs',
    key: '2',
    glyph: '⬡',
    en: {
      name: 'SPECS',
      hint: 'The corpus she is generated from',
      body: 'The Spec Explorer, embedded whole: search the corpus, read a spec, and watch it become tokens, an AST, types, HIR, and five target languages — Zig, Verilog, C, Rust and a chip. Editing here is a draft, not an accepted spec.',
    },
    ru: {
      name: 'СПЕКИ',
      hint: 'Корпус, из которого она порождена',
      body: 'Обозреватель спек целиком: поиск по корпусу, чтение спеки и её превращение в токены, AST, типы, HIR и пять целевых языков — Zig, Verilog, C, Rust и чип. Правка здесь — черновик, а не принятая спека.',
    },
  },
  {
    tab: 'kanban',
    key: '3',
    glyph: '▦',
    en: {
      name: 'KANBAN',
      hint: 'Operational columns',
      body: 'The board as six columns — backlog, blocked, running, in review, done, dropped — with the issue cards themselves, each carrying its number and how many acceptance criteria it states.',
    },
    ru: {
      name: 'КАНБАН',
      hint: 'Операционные колонки',
      body: 'Доска шестью колонками — бэклог, заблокировано, в работе, на ревью, готово, отложено — с самими карточками задач: номер и сколько критериев приёмки в ней заявлено.',
    },
  },
  {
    tab: 'map',
    key: '4',
    glyph: '⌘',
    en: {
      name: 'MISSION MAP',
      hint: 'Strategic lifecycle sectors',
      body: 'The same six sectors read as territory rather than as a queue: what each holds, what share of the board it is, and which of them the bees are working in now.',
    },
    ru: {
      name: 'КАРТА МИССИЙ',
      hint: 'Стратегические секторы жизненного цикла',
      body: 'Те же шесть секторов, прочитанные как территория, а не как очередь: что в каждом, какую долю доски он занимает и в каком из них сейчас работают пчёлы.',
    },
  },
  {
    tab: 'factory',
    key: '5',
    glyph: '⚙',
    en: {
      name: 'FACTORY',
      hint: 'Live engineering production',
      body: 'What is being built: the bee hangars and which are idle, the construction partials a spec has produced, the research detail behind them, and the hardware foundry with what it has actually programmed.',
    },
    ru: {
      name: 'ФАБРИКА',
      hint: 'Живое инженерное производство',
      body: 'Что строится: ангары пчёл и кто из них простаивает, частичные сборки, порождённые спекой, исследовательская деталь за ними и аппаратная литейная с тем, что она действительно прошила.',
    },
  },
  {
    tab: 'research',
    key: '6',
    glyph: '◈',
    en: {
      name: 'TECHNOLOGY TREE',
      hint: 'Canonical evidence graph',
      body: 'Research as a graph with prerequisites: what is seeded, what is locked behind what, and what is being researched now — with the evidence each node rests on, and nothing claimed that has none.',
    },
    ru: {
      name: 'ДЕРЕВО ТЕХНОЛОГИЙ',
      hint: 'Канонический граф свидетельств',
      body: 'Исследования как граф с предпосылками: что засеяно, что за чем закрыто и что исследуется сейчас — со свидетельством под каждым узлом, и без утверждений, под которыми его нет.',
    },
  },
  {
    tab: 'skills',
    key: '7',
    glyph: '⟁',
    en: {
      name: 'SKILLS',
      hint: 'Agent skills, each stated by a .t27 spec',
      body: 'The Skill Explorer, embedded whole: every published agent skill with the .t27 spec that states it first — its bytes, its hash, the compiler’s verdict — then the SKILL.md the sync script saw. A card with a spec and code is labelled spec+code; one with code alone says code-only. ENABLED is read from the spec and changed there.',
    },
    ru: {
      name: 'СКИЛЛЫ',
      hint: 'Скиллы агентов, каждый заявлен спекой .t27',
      body: 'Обозреватель скиллов целиком: каждый опубликованный скилл агента сначала со спекой .t27, которая его заявляет — байты, хеш, вердикт компилятора, — затем SKILL.md, который увидел скрипт синхронизации. Карточка со спекой и кодом помечена «спека+код»; карточка только с кодом говорит «только код». ENABLED читается из спеки и меняется там.',
    },
  },
  {
    tab: 'crons',
    key: '8',
    glyph: '◷',
    en: {
      name: 'CRONS',
      hint: 'Scheduled jobs, each stated by a .t27 spec',
      body: 'The Cron Explorer, embedded whole: every scheduled job on GitHub Actions, Railway, Inngest and in-process timers, with the .t27 spec that states it first, then what the code scan found. Each card links to the skills its RUNS names, says where “run now” really goes for its host, and admits when a timer has no outside handle at all.',
    },
    ru: {
      name: 'КРОНЫ',
      hint: 'Расписания, каждое заявлено спекой .t27',
      body: 'Обозреватель кронов целиком: каждое задание по расписанию на GitHub Actions, Railway, Inngest и во внутрипроцессных таймерах, сначала со спекой .t27, которая его заявляет, затем с тем, что нашло сканирование кода. Каждая карточка ведёт к скиллам из своего RUNS, говорит, куда на самом деле идёт «Запустить сейчас» для её хоста, и признаёт, когда у таймера нет внешней ручки.',
    },
  },
  {
    tab: 'agents',
    key: '9',
    glyph: 'Ω',
    en: {
      name: 'AGENTS',
      hint: 'The 27-letter alphabet, each agent stated by a .t27 spec',
      body: 'The Agent Explorer, embedded whole. Level by level the system is built: Specs state what exists, Skills state what a run does, Crons state what starts a run, and Agents — the fourth layer — state who holds the skills, under which law (SOUL.md, AGENTS.md), with which entry and exit invariant. Twenty-seven letters, A to Z and the reserved Ti, each with its spec first, then its skills, its derived crons, and its experience joined from the episode log by evidence: an agent no episode names says so.',
    },
    ru: {
      name: 'АГЕНТЫ',
      hint: 'Алфавит из 27 букв, каждый агент заявлен спекой .t27',
      body: 'Обозреватель агентов целиком. Уровень за уровнем мы создаём систему: спеки говорят, что существует, скиллы — что делает запуск, кроны — что его запускает, а агенты — четвёртый слой — кто держит скиллы, под каким законом (SOUL.md, AGENTS.md), с каким входным и выходным инвариантом. Двадцать семь букв, от A до Z и зарезервированная Ti, у каждой сначала спека, затем её скиллы, выведенные кроны и опыт, присоединённый из журнала эпизодов по свидетельствам: агент, которого не называет ни один эпизод, говорит об этом сам.',
    },
  },
  {
    tab: 'functions',
    key: '0',
    glyph: 'ƒ',
    en: {
      name: 'FUNCTIONS',
      hint: 'The 28 Inngest functions of the bot, each stated by a .t27 spec',
      body: 'The Function Explorer, embedded whole: the layer where a spec meets a running service — sixth on this site\'s ladder, after Tools, although specs/functions/README.md in t27 calls it layer 5 (as specs/tools/README.md does for tools; the two READMEs disagree and this page says so rather than picking one). Each of the 28 Inngest functions of 999-multibots-telegraf is stated by a .t27 spec under specs/functions — trigger, event and legacy events or cron, steps in source order, retries, what happens on failure, side effects, the guard step, the safe probe and its result — and witnessed by a vendored copy of the functions manifest read from the repository. Live run counts come from the bot once a minute; when the status source does not answer, the page says so and shows unknown, never zero.',
    },
    ru: {
      name: 'ФУНКЦИИ',
      hint: '28 функций Inngest бота, каждая заявлена спекой .t27',
      body: 'Обозреватель функций целиком: слой, где спека встречается с работающим сервисом — шестой на лестнице этого сайта, после инструментов, хотя specs/functions/README.md в t27 называет его пятым (как и specs/tools/README.md — инструменты; два README расходятся, и страница говорит об этом, а не выбирает одно). Каждая из 28 функций Inngest бота 999-multibots-telegraf заявлена спекой .t27 в specs/functions — триггер, событие и старые события или крон, шаги в порядке исходника, повторы, действие при сбое, побочные эффекты, шаг-страж, безопасная проба и её результат — и засвидетельствована копией манифеста функций, прочитанного из репозитория. Живые счётчики запусков приходят с бота раз в минуту; когда источник статуса не отвечает, страница говорит об этом и показывает «неизвестно», а не ноль.',
    },
  },
  {
    tab: 'tools',
    key: 't',
    glyph: '⟐',
    en: {
      name: 'TOOLS',
      hint: 'The tri CLI and the MCP servers, each stated by a .t27 spec (key t)',
      body: 'The Tool Explorer, embedded whole: the tools every agent should know. The fifth layer of the ladder, Specs → Skills → Crons → Agents → Tools → Functions, in two families: the commands of the t27 tri CLI, read from the clap enum and its doc comments, and the MCP servers of both repositories with their tool lists, read from their manifests and source. Each card is a .t27 spec under specs/tools first, then its synopsis, when to use it, the letters that own it, and the file and commit it was read from; a tool no agent has bound says so.',
    },
    ru: {
      name: 'ИНСТРУМЕНТЫ',
      hint: 'tri CLI и MCP-серверы, каждый заявлен спекой .t27 (клавиша t)',
      body: 'Обозреватель инструментов целиком: инструменты, о которых должен знать каждый агент. Пятый слой лестницы — спеки → скиллы → кроны → агенты → инструменты → функции — в двух семействах: команды t27 tri CLI, прочитанные из enum clap и его doc-комментариев, и MCP-серверы обоих репозиториев со списками их инструментов, прочитанными из манифестов и исходников. У каждой карточки сначала спека .t27 в specs/tools, затем синопсис, когда использовать, буквы-владельцы и файл с коммитом, из которого она прочитана; инструмент, который не привязал ни один агент, говорит об этом сам.',
    },
  },
] as const

export type QueenModule = (typeof MODULES)[number];
export type QueenModuleTab = QueenModule['tab'];
