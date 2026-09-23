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
// `play` is the second sentence a reader needs and `body` never answered: not
// what the view shows, but what it is for — what a person standing in front of
// it can do, decide, or find out. Every module had a description and none had a
// reason, so a visitor scrolling the homepage read fourteen accurate paragraphs
// about someone else's instruments. It is one sentence, it is checked for
// length by the same contracts that check `body`, and it may only name
// something the view actually offers: a `play` describing a move that does not
// exist is the same defect as a `body` describing a panel that is not there.
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
      play: 'Where you choose. Click a cell to read the spec behind it, or the issue that pays for it, before you take on either.',
    },
    ru: {
      name: 'СОТЫ',
      hint: 'Доска как поле меток',
      body: 'Общая карта. Каждая золотая сота — спека .t27, каждая красная — GitHub issue, которая за неё платит, а золотая линия между сотами — одна и та же спека в общем ядре и в репозитории-источнике. Клик по соте открывает саму спеку поверх карты.',
      play: 'Место выбора. Клик по соте открывает спеку за ней или задачу, которая за неё платит, — до того, как вы за что-то возьмётесь.',
    },
  },
  {
    tab: 'specs',
    key: '2',
    glyph: '⬡',
    en: {
      name: 'SPECS',
      hint: 'The corpus she is generated from',
      body: 'The Spec Explorer, embedded whole: search the corpus, read a spec, and watch it become tokens, an AST, types, HIR, and every target it reaches — Zig, Verilog, C, Rust, JavaScript, TypeScript and a chip. Editing here is a draft, not an accepted spec.',
      play: 'Where you write. The real compiler runs on what you type here, so you can watch your spec become Zig, Verilog, C, Rust, JavaScript and TypeScript before you send a line of it anywhere.',
    },
    ru: {
      name: 'СПЕКИ',
      hint: 'Корпус, из которого она порождена',
      body: 'Обозреватель спек целиком: поиск по корпусу, чтение спеки и её превращение в токены, AST, типы, HIR и все цели, до которых она доходит, — Zig, Verilog, C, Rust, JavaScript, TypeScript и чип. Правка здесь — черновик, а не принятая спека.',
      play: 'Место письма. Здесь на ваш текст работает настоящий компилятор, и спеку можно увидеть на Zig, Verilog, C, Rust, JavaScript и TypeScript ещё до того, как вы куда-то её отправите.',
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
      play: 'Where you read the contract. The acceptance criteria a card states are what a review will hold you to; a card that states none is a card nobody can be judged against.',
    },
    ru: {
      name: 'КАНБАН',
      hint: 'Операционные колонки',
      body: 'Доска шестью колонками — бэклог, заблокировано, в работе, на ревью, готово, отложено — с самими карточками задач: номер и сколько критериев приёмки в ней заявлено.',
      play: 'Место, где читают договор. Критерии приёмки на карточке — это то, по чему вас будет судить ревью; карточка без них — карточка, по которой судить нечем.',
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
      play: 'Where you see the gaps: which sectors hold most of the board, and which of them no bee is working in right now.',
    },
    ru: {
      name: 'КАРТА МИССИЙ',
      hint: 'Стратегические секторы жизненного цикла',
      body: 'Те же шесть секторов, прочитанные как территория, а не как очередь: что в каждом, какую долю доски он занимает и в каком из них сейчас работают пчёлы.',
      play: 'Место, где видны пробелы: какие секторы держат бо́льшую часть доски и в каком из них сейчас не работает ни одна пчела.',
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
      play: 'Where the work is visibly happening. An idle hangar is capacity with nothing it is allowed to take — the state a written boundary ends.',
    },
    ru: {
      name: 'ФАБРИКА',
      hint: 'Живое инженерное производство',
      body: 'Что строится: ангары пчёл и кто из них простаивает, частичные сборки, порождённые спекой, исследовательская деталь за ними и аппаратная литейная с тем, что она действительно прошила.',
      play: 'Место, где работа видна. Простаивающий ангар — это мощность, которой нечего взять; именно это состояние и заканчивает написанная граница.',
    },
  },
  {
    tab: 'research',
    key: '6',
    glyph: '◈',
    en: {
      name: 'TECH TREE',
      hint: 'How the .t27 language got here',
      body: 'The evolution of the .t27 language as a graph with prerequisites: the seed compiler, the constructs the corpus actually uses, the checks each spec passes, the backends it generates to, the repositories that have adopted it, and the silicon path — every node carrying the count it rests on, read from the corpus index the site ships.',
      play: 'Where a claim has to show its evidence before it is drawn at all. Read it to see how far the language has got, counted off the corpus index on the page rather than asserted here.',
    },
    ru: {
      name: 'ТЕХ-ДЕРЕВО',
      hint: 'Как язык .t27 дошёл до этого места',
      body: 'Эволюция языка .t27 как граф с предпосылками: компилятор-семя, конструкции, которые корпус действительно использует, проверки, которые проходит каждая спека, бэкенды, в которые она порождается, репозитории, принявшие язык, и путь к кремнию — у каждого узла стоит число, на котором он держится, прочитанное из индекса корпуса, который сайт отдаёт вместе со страницей.',
      play: 'Место, где утверждение обязано предъявить свидетельство, прежде чем его вообще нарисуют. Здесь видно, как далеко ушёл язык — число посчитано по индексу корпуса на самой странице, а не вписано сюда руками.',
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
      play: 'Where an unfinished piece names itself. A card labelled code-only is a skill nobody has stated in a spec yet, and the shape of that work is already obvious.',
    },
    ru: {
      name: 'СКИЛЛЫ',
      hint: 'Скиллы агентов, каждый заявлен спекой .t27',
      body: 'Обозреватель скиллов целиком: каждый опубликованный скилл агента сначала со спекой .t27, которая его заявляет — байты, хеш, вердикт компилятора, — затем SKILL.md, который увидел скрипт синхронизации. Карточка со спекой и кодом помечена «спека+код»; карточка только с кодом говорит «только код». ENABLED читается из спеки и меняется там.',
      play: 'Место, где незаконченное называет себя само. Карточка «только код» — это скилл, который ещё никто не заявил спекой, и форма этой работы уже очевидна.',
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
      play: 'Where the schedule admits its holes. A job the page says has no outside handle is one nobody can start or stop from here — a gap stated rather than hidden.',
    },
    ru: {
      name: 'КРОНЫ',
      hint: 'Расписания, каждое заявлено спекой .t27',
      body: 'Обозреватель кронов целиком: каждое задание по расписанию на GitHub Actions, Railway, Inngest и во внутрипроцессных таймерах, сначала со спекой .t27, которая его заявляет, затем с тем, что нашло сканирование кода. Каждая карточка ведёт к скиллам из своего RUNS, говорит, куда на самом деле идёт «Запустить сейчас» для её хоста, и признаёт, когда у таймера нет внешней ручки.',
      play: 'Место, где расписание признаёт свои дыры. Задание, у которого, как сказано, нет внешней ручки, отсюда нельзя ни запустить, ни остановить, — и об этом сказано, а не умолчано.',
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
      play: 'Where the players on the other side are named. Twenty-seven letters, each with the law it works under; an agent no episode names has no recorded experience yet, and says so itself.',
    },
    ru: {
      name: 'АГЕНТЫ',
      hint: 'Алфавит из 27 букв, каждый агент заявлен спекой .t27',
      body: 'Обозреватель агентов целиком. Уровень за уровнем мы создаём систему: спеки говорят, что существует, скиллы — что делает запуск, кроны — что его запускает, а агенты — четвёртый слой — кто держит скиллы, под каким законом (SOUL.md, AGENTS.md), с каким входным и выходным инвариантом. Двадцать семь букв, от A до Z и зарезервированная Ti, у каждой сначала спека, затем её скиллы, выведенные кроны и опыт, присоединённый из журнала эпизодов по свидетельствам: агент, которого не называет ни один эпизод, говорит об этом сам.',
      play: 'Место, где названы игроки с той стороны. Двадцать семь букв, у каждой свой закон; агент, которого не называет ни один эпизод, ещё не имеет записанного опыта — и говорит об этом сам.',
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
      play: 'Where a spec meets people who are not playing. These 28 functions run a bot that real users talk to, so this is the shortest distance between a spec you wrote and somebody using it.',
    },
    ru: {
      name: 'ФУНКЦИИ',
      hint: '28 функций Inngest бота, каждая заявлена спекой .t27',
      body: 'Обозреватель функций целиком: слой, где спека встречается с работающим сервисом — шестой на лестнице этого сайта, после инструментов, хотя specs/functions/README.md в t27 называет его пятым (как и specs/tools/README.md — инструменты; два README расходятся, и страница говорит об этом, а не выбирает одно). Каждая из 28 функций Inngest бота 999-multibots-telegraf заявлена спекой .t27 в specs/functions — триггер, событие и старые события или крон, шаги в порядке исходника, повторы, действие при сбое, побочные эффекты, шаг-страж, безопасная проба и её результат — и засвидетельствована копией манифеста функций, прочитанного из репозитория. Живые счётчики запусков приходят с бота раз в минуту; когда источник статуса не отвечает, страница говорит об этом и показывает «неизвестно», а не ноль.',
      play: 'Место, где спека встречает людей, которые не играют. Эти 28 функций крутят бота, с которым говорят настоящие пользователи: это кратчайшее расстояние от написанной вами спеки до того, кто ею пользуется.',
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
      play: 'Where you learn what an agent can reach for. A tool no agent has bound is either a missing binding or a tool nobody needs, and finding out which is itself a move.',
    },
    ru: {
      name: 'ИНСТРУМЕНТЫ',
      hint: 'tri CLI и MCP-серверы, каждый заявлен спекой .t27 (клавиша t)',
      body: 'Обозреватель инструментов целиком: инструменты, о которых должен знать каждый агент. Пятый слой лестницы — спеки → скиллы → кроны → агенты → инструменты → функции — в двух семействах: команды t27 tri CLI, прочитанные из enum clap и его doc-комментариев, и MCP-серверы обоих репозиториев со списками их инструментов, прочитанными из манифестов и исходников. У каждой карточки сначала спека .t27 в specs/tools, затем синопсис, когда использовать, буквы-владельцы и файл с коммитом, из которого она прочитана; инструмент, который не привязал ни один агент, говорит об этом сам.',
      play: 'Место, где видно, чем агент вообще может воспользоваться. Инструмент, который не привязал ни один агент, — это либо недостающая привязка, либо ненужный инструмент, и выяснить, что именно, — уже ход.',
    },
  },
  {
    tab: 'project',
    key: 'p',
    glyph: '§',
    en: {
      name: 'PROJECT',
      hint: 'The project, the rules of the game for its agents, and the system in detail (key p)',
      body: 'The system documentation, embedded whole: seven chapters read from one declared document, specs/docs/system.t27 — what the project claims and how each claim is tagged; the constitution and the rules of the game its agents follow; the six-step ladder, Specs → Skills → Crons → Agents → Tools → Functions, with live counts; the 27-letter alphabet; the Queen\'s 6+1 phase cycle; the tools; and how every number on the site is witnessed. Prose comes from docs/system/*.md through the compiler, tables are generated from the catalogs, figures are drawn from data, and each carries its source and commit. The digits 1–0 are taken, so this view opens on the letter p.',
      play: 'Where the rules are written down. The constitution the agents obey is the one you play under too, so this is the page to read before a first spec rather than after a rejected one.',
    },
    ru: {
      name: 'ПРОЕКТ',
      hint: 'проект, правила игры для агентов и система в деталях (клавиша p)',
      body: 'Документация системы целиком: семь глав, прочитанных из одного объявленного документа specs/docs/system.t27 — что проект утверждает и как помечено каждое утверждение; конституция и правила игры, по которым живут агенты; лестница из шести ступеней спеки → скиллы → кроны → агенты → инструменты → функции с живыми числами; алфавит из 27 букв; цикл Королевы 6+1; инструменты; и то, как засвидетельствовано каждое число на сайте. Проза берётся из docs/system/*.md через компилятор, таблицы порождаются из каталогов, рисунки строятся по данным, и у каждого указан источник и коммит. Цифры 1–0 заняты, поэтому этот вид открывается буквой p.',
      play: 'Место, где записаны правила. Конституция, которой подчиняются агенты, — та же, по которой играете вы, так что эту страницу стоит читать до первой спеки, а не после отклонённой.',
    },
  },
  {
    tab: 'tri',
    key: 'r',
    glyph: '△',
    en: {
      name: 'TRI',
      hint: 'The app inside the game: feed, agent, AI generation, profile and CRM (key r)',
      body: 'The app at app.t27.ai, inside the game. Each screen is the real app page in a frame: the feed, the agent, the AI pipeline from the script through voice, photo, lipsync and video to the editor, a profile, and the owner\'s CRM. The screen is in the address (?tab=tri&screen=chat, and path= for one profile), so a link opens it and a reload keeps it. On t27.ai Telegram does not let its sign-in load inside another site, so the screens that need a person say so and link out to the app; the feed works for everyone. Until the app allows t27.ai to frame it, a screen does not answer and says so, with the same link out. Opens on the letter r.',
      play: 'Where the network stops being a game. The app has its own users who never touch the board, and they are who the swarm’s work eventually reaches.',
    },
    ru: {
      name: 'TRI',
      hint: 'Приложение внутри игры: лента, агент, ИИ-генерация, профиль и CRM (клавиша r)',
      body: 'Приложение app.t27.ai внутри игры. Каждый экран — настоящая страница приложения во фрейме: лента, агент, ИИ-конвейер от сценария через голос, фото, липсинк и видео к редактору, профиль и CRM владельца. Экран записан в адресе (?tab=tri&screen=chat, а для одного профиля ещё path=), поэтому ссылка его открывает, а перезагрузка сохраняет. На t27.ai Telegram не даёт своему входу загрузиться внутри чужого сайта, поэтому экраны, которым нужен человек, говорят об этом и ведут в само приложение; лента работает для всех. Пока приложение не разрешит t27.ai показывать себя во фрейме, экран не отвечает и говорит об этом. Открывается буквой r.',
      play: 'Место, где сеть перестаёт быть игрой. У приложения свои пользователи, которые доски не касаются, — именно до них в итоге доходит работа роя.',
    },
  },
  {
    tab: 'passport',
    key: 'b',
    glyph: '▤',
    en: {
      name: 'PASSPORT',
      hint: 'What must travel with a result (key b)',
      body: 'The record a reported result has to carry so that a reader who holds neither the part nor the workload can tell whether two numbers differ because the systems do or because the conditions did — fourteen fields, proposed for team review to the OCP neuromorphic working group on 16 September 2026, and proposed is all it is: nobody has agreed to include it. Five fields are marked †, meaning a measured failure of our own pays for them: one set of weights that read as two models 4.44 standard errors apart, two artefacts differing in 43.70 percent of their parameters behind a metric that moved 0.084 of a standard error, and one function whose two implementations differed 5.4× in LUTs over the field widths rather than the algorithm. A sixth carries ‡ — it rests only on a case this document itself withdrew, and is counted apart rather than quietly with the rest; the version sent to the working group says four, which was simply wrong, and a correction is owed. The cases are not neuromorphic and no silicon exists; both are stated on the page rather than smoothed. The record has since been filled against seven results other people published: 98 cells, 5 stated, 65 partial, 28 absent — and the control, taken from a body that already operates disclosure rules, is the only column with no gap at all. Opens on the letter b.',
      play: 'Where the community’s stake reaches outside this repository. A disclosure record proposed to an industry working group and accepted by nobody yet: reviewing it, or filling it against a result you have published, is a contribution that touches no code.',
    },
    ru: {
      name: 'ПАСПОРТ',
      hint: 'Что обязано ехать вместе с результатом (клавиша b)',
      body: 'Запись, которую обязан нести опубликованный результат, чтобы читатель, у которого нет ни микросхемы, ни нагрузки, мог понять: два числа расходятся потому, что различаются системы, — или потому, что различались условия. Четырнадцать полей, поданных на рассмотрение рабочей группы OCP по нейроморфным вычислениям 16 сентября 2026 года, и поданных — это всё: включить их никто пока не согласился. Пять полей помечены †: за них платит наш собственный измеренный промах — один набор весов, прочитанный как две модели в 4.44 стандартной ошибки друг от друга; два артефакта, различающиеся в 43,70 процента параметров за метрикой, сдвинувшейся на 0.084 стандартной ошибки; и одна функция, чьи две реализации разошлись в 5,4 раза по LUT из-за ширин полей, а не из-за алгоритма. Шестое несёт ‡ — оно стоит только на случае, который этот документ сам и отозвал, и считается отдельно, а не тихо вместе со всеми; в версии, отправленной рабочей группе, стоит «четыре», и это просто неверно — по ней причитается поправка. Случаи не нейроморфные, и кремния не существует; и то и другое сказано на странице, а не сглажено. С тех пор запись заполнена по семи результатам, опубликованным другими: 98 клеток, 5 раскрыто, 65 частично, 28 отсутствует, — и контроль, взятый из организации, которая уже применяет правила раскрытия, единственная колонка вообще без пробелов. Открывается буквой b.',
      play: 'Место, где интерес сообщества выходит за пределы этого репозитория. Запись о раскрытии, поданная в отраслевую рабочую группу и пока никем не принятая: её разбор — или её заполнение по вашему собственному опубликованному результату — это вклад, не трогающий код.',
    },
  },
  {
    tab: 'browser',
    key: 'w',
    glyph: '◍',
    en: {
      name: 'BROWSER',
      hint: 'Your own browser, the one your agent drives (key w)',
      body: 'Your own real browser, running on a server: your profile, your logins, your cookies. It is the same browser the app\'s Browser tab shows and your agent drives -- not a copy -- so every click the agent makes happens here in front of you, and you can take the wheel at any moment. Passwords are typed by you inside the window and go straight into it. Opening it starts a machine, so this view only reads its state until you press Open. Works when signed in to the app at app.t27.ai. Opens on the letter w.',
      play: 'Where you watch your agent work and take over. Open it, sign in to a site yourself, then let the agent carry on in the same window.',
    },
    ru: {
      name: 'БРАУЗЕР',
      hint: 'Ваш собственный браузер, которым водит ваш агент (клавиша w)',
      body: 'Ваш собственный настоящий браузер на сервере: ваш профиль, ваши входы, ваши cookies. Это тот же браузер, что во вкладке «Браузер» приложения и которым водит ваш агент, — не копия, поэтому каждое нажатие агента происходит здесь у вас на глазах, и руль можно взять в любой момент. Пароли вы вводите сами внутри окна, и они уходят прямо в него. Открытие запускает машину, поэтому до нажатия «Открыть» этот вид только читает состояние. Работает, когда вы вошли в приложение на app.t27.ai. Открывается буквой w.',
      play: 'Место, где видно, как работает агент, и где его можно подменить. Откройте, войдите на сайт сами — и пусть агент продолжает в том же окне.',
    },
  },
  {
    tab: 'roadmap',
    key: 'm',
    glyph: '⇶',
    en: {
      name: 'ROADMAP',
      hint: 'The game: the whole stack rewritten in .t27 (key m)',
      body: 'The goal of the game, measured. Everything below the interface is to be written once in .t27 and generated to its target, with one exception: the seed, t27c, stays hand-written Rust. This view counts what the code that runs app.t27.ai is written in today -- every repository behind it, by language, from the files git tracks at a named commit -- and lays out the rewrite as stages, each one a goal issue labelled roadmap whose state is read live. Opens on the letter m.',
      play: 'Where the whole swarm\'s work adds up to one number: the share of the stack in .t27. Pick a stage, port its files, and watch the dial move.',
    },
    ru: {
      name: 'ДОРОЖНАЯ КАРТА',
      hint: 'Игра: весь стек переписать на .t27 (клавиша m)',
      body: 'Цель игры в цифрах. Всё ниже интерфейса должно быть написано один раз на .t27 и сгенерировано в свою цель, с одним исключением: зерно, t27c, остаётся рукописным Rust. Этот вид считает, на чём сегодня написан код, который держит app.t27.ai, — каждый репозиторий за ним, по языкам, по файлам, которые отслеживает git, на названном коммите, — и раскладывает переписывание на этапы, каждый из которых — задача-цель с меткой roadmap, чьё состояние читается вживую. Открывается буквой m.',
      play: 'Место, где работа всего роя сходится в одно число: доля стека на .t27. Возьмите этап, перенесите его файлы — и смотрите, как сдвигается стрелка.',
    },
  },
  {
    tab: 'wars',
    key: 'x',
    glyph: '⚔',
    en: {
      name: 'WARS',
      hint: 'Real-task agent benchmarks generated from one .t27 ledger (key x)',
      body: 'The controlled arena for Bees, JEV-assisted decisions, IGLA CODER and IGLA RACE. Every experiment pins a real GitHub issue, base commit, prompt, tools, budget and acceptance gates in specs/queen/wars.t27; missing runs remain unknown rather than becoming zero, and the interface is only a generated projection of that ledger.',
      play: 'Where an agent configuration earns its place. Compare witnessed work under equal conditions, keep one accepted patch, and carry every losing or blocked arm forward as evidence rather than erasing it.',
    },
    ru: {
      name: 'ВОЙНЫ',
      hint: 'Бенчмарки агентов на реальных задачах из единого журнала .t27 (клавиша x)',
      body: 'Контролируемая арена для Bees, решений с JEV, IGLA CODER и IGLA RACE. Каждый эксперимент закрепляет реальную GitHub issue, базовый commit, prompt, инструменты, бюджет и ворота приёмки в specs/queen/wars.t27; отсутствующие запуски остаются неизвестными, а не превращаются в нули, а интерфейс служит только порождённой проекцией этого журнала.',
      play: 'Место, где конфигурация агента заслуживает своё место. Сравнивайте подтверждённую работу в равных условиях, принимайте только один patch и сохраняйте проигравшие или заблокированные руки как свидетельство.',
    },
  },
] as const

export type QueenModule = (typeof MODULES)[number];
export type QueenModuleTab = QueenModule['tab'];
