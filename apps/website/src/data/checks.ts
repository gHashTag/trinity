// The four checks, in the order worth adopting them.
//
// They were scattered across two pages, each introduced where it happened to be
// written. Somebody deciding whether to use any of this had no way to see them
// together, and no reason to prefer one first — so the order is stated here and
// it is not arbitrary: cheapest and narrowest first, so the first thing a new
// reader runs is the one that cannot waste their afternoon.
//
// Every one runs on the customer's runner, against the customer's checkout.
// Nothing is uploaded. That is not a courtesy: the closest comparable service
// moved off hosted CI because chip designers will not upload RTL, and an intake
// that asks them to is turning away the people it exists for.

export type Check = {
  id: string
  order: number
  name: { en: string; ru: string }
  needs: { en: string; ru: string }
  time: { en: string; ru: string }
  price: { en: string; ru: string }
  /** Why it goes here in the order, not somewhere else. */
  why: { en: string; ru: string }
  establishes: { en: string[]; ru: string[] }
  refuses: { en: string; ru: string }
  snippet: string
  evidence?: { en: string; ru: string }
}

export const CHECKS: Check[] = [
  {
    id: 'paths',
    order: 1,
    name: { en: 'Every path your build names exists', ru: 'Все пути, которые называет сборка, существуют' },
    needs: { en: 'Nothing. No toolchain is installed.', ru: 'Ничего. Никакой тулчейн не ставится.' },
    time: { en: 'Seconds', ru: 'Секунды' },
    price: { en: 'Free', ru: 'Бесплатно' },
    why: {
      en: 'First because it is the cheapest thing that can be wrong and the easiest to miss. A file that moves out from under a build script breaks it, and detecting that needs no cleverness — the file is either there or it is not. One of my repositories spent four months red on exactly that.',
      ru: 'Первой — потому что это самое дешёвое из того, что может быть не так, и самое лёгкое, чтобы не заметить. Файл, уехавший из-под скрипта сборки, ломает её, и чтобы это увидеть, не нужно никакой изощрённости: файл либо есть, либо нет. Один мой репозиторий провёл на этом четыре месяца в красном.',
    },
    establishes: {
      en: [
        'Every path build.zig names is present.',
        'Which missing files a build root can actually reach — separated from the ones no target visits.',
        'Whether a missing import is bound to a name anything uses, since an unused one is never loaded.',
      ],
      ru: [
        'Каждый путь, который называет build.zig, на месте.',
        'До каких отсутствующих файлов сборка реально дотягивается — отдельно от тех, куда не заходит ни одна цель.',
        'Привязан ли отсутствующий импорт к имени, которое где-то используется: неиспользуемый никогда не загружается.',
      ],
    },
    refuses: {
      en: 'That the design compiles, or is correct. It checks that files exist. And its own headline number is a bound rather than a count: matching is textual, and a name can belong to something else.',
      ru: 'Что дизайн компилируется или верен. Она проверяет, что файлы на месте. И её собственная главная цифра — граница, а не счёт: совпадение текстовое, а имя может принадлежать чему-то другому.',
    },
    snippet: `jobs:
  paths:
    uses: gHashTag/trinity/.github/workflows/build-paths-check.yml@main`,
    evidence: {
      en: 'Run across nine of my public repositories: one confirmed fault, in a library whose CI had been failing since April, and nothing in five others.',
      ru: 'Прогон по девяти моим открытым репозиториям: один подтверждённый дефект — в библиотеке, чей CI падал с апреля, — и ничего в пяти других.',
    },
  },
  {
    id: 'structural',
    order: 2,
    name: { en: 'It elaborates, infers no latch, and synthesises', ru: 'Собирается, не выводит защёлок, синтезируется' },
    needs: { en: 'yosys and iverilog, installed by the job', ru: 'yosys и iverilog, ставит само задание' },
    time: { en: 'About a minute', ru: 'Около минуты' },
    price: { en: 'Free for a public repository', ru: 'Бесплатно для публичного репозитория' },
    why: {
      en: 'Second because it is the first one that opens your RTL. It answers four structural questions and prints the command behind each, so any of them can be re-run by hand.',
      ru: 'Второй — потому что это первая, которая открывает ваш RTL. Она отвечает на четыре структурных вопроса и печатает команду под каждым, чтобы любой можно было перезапустить руками.',
    },
    establishes: {
      en: [
        'Every file your info.yaml declares is present, and the design elaborates from that list alone.',
        'No latch is inferred by the published flow.',
        'It synthesises, with the cell count including submodules.',
        'How many flip-flops the netlist holds — which says whether a clock frequency is a meaningful question, not what the answer is.',
      ],
      ru: [
        'Каждый файл, объявленный в вашем info.yaml, на месте, и дизайн собирается из этого списка.',
        'Опубликованный флоу не выводит ни одной защёлки.',
        'Синтезируется — со счётом ячеек по всему дизайну.',
        'Сколько триггеров в нетлисте: это говорит, осмыслен ли вопрос о частоте, а не каков ответ.',
      ],
    },
    refuses: {
      en: 'Correctness. Nothing here compares your design against a specification, and generic yosys cells are not silicon area.',
      ru: 'Корректность. Ничто здесь не сверяет ваш дизайн со спецификацией, а обобщённые ячейки yosys — не площадь на кристалле.',
    },
    snippet: `jobs:
  check:
    uses: gHashTag/trinity/.github/workflows/rtl-check.yml@main
    with:
      top: my_top_module`,
    evidence: {
      en: 'It found a shuttle-blocking defect in two of my own designs and none in the third-party designs it has been run on.',
      ru: 'Нашла блокирующий шаттл дефект в двух моих дизайнах и ни одного в чужих дизайнах, на которых запускалась.',
    },
  },
  {
    id: 'signal',
    order: 3,
    name: { en: 'Is your build still carrying information?', ru: 'Несёт ли ваша сборка ещё информацию?' },
    needs: { en: 'actions: read on your own repository', ru: 'actions: read на вашем же репозитории' },
    time: { en: 'Seconds', ru: 'Секунды' },
    price: { en: 'Free', ru: 'Бесплатно' },
    why: {
      en: 'Third because the first two are worth nothing if their red arrives into a build that is always red. A run that fails every time carries −log₂(1) = 0 bits: it cannot distinguish the world before it from the world after.',
      ru: 'Третьей — потому что первые две ничего не стоят, если их красное приходит в сборку, которая красная всегда. Прогон, падающий каждый раз, несёт −log₂(1) = 0 бит: он не отличает мир до себя от мира после.',
    },
    establishes: {
      en: [
        'The current failure streak, and whether the window can even see its start.',
        'The self-information of the next red, in bits.',
        'Which run began the streak — the one worth reading, because the later ones are echoes.',
      ],
      ru: [
        'Текущую серию падений и видно ли её начало в окне вообще.',
        'Собственную информацию очередного красного, в битах.',
        'Какой прогон начал серию — тот, который стоит читать: остальные эхо.',
      ],
    },
    refuses: {
      en: 'Any opinion about your code. It measures the instrument, not the thing measured.',
      ru: 'Любое суждение о вашем коде. Она измеряет прибор, а не измеряемое.',
    },
    snippet: `jobs:
  signal:
    uses: gHashTag/trinity/.github/workflows/signal-health.yml@main
    with:
      workflow: ci.yml`,
    evidence: {
      en: 'The first thing it did here was report 379 consecutive failures in the repository this service is built in, last green in March. Those numbers are published on the verification page.',
      ru: 'Первое, что она здесь сделала, — сообщила о 379 падениях подряд в репозитории, где построен этот сервис, последний зелёный в марте. Эти цифры опубликованы на странице верификации.',
    },
  },
  {
    id: 'conformance',
    order: 4,
    name: { en: 'Every code point, against an implementation neither of us wrote', ru: 'Каждая кодовая точка против реализации, которую не писал ни один из нас' },
    needs: { en: 'iverilog and ml_dtypes, installed by the job', ru: 'iverilog и ml_dtypes, ставит само задание' },
    time: { en: 'Minutes', ru: 'Минуты' },
    price: { en: 'From $2 500 per core, first module free', ru: 'От $2 500 за ядро, первый модуль бесплатно' },
    why: {
      en: 'Last because it is the only one that says anything about whether your design is correct, and it is worth its price only because the three above say plainly that they do not.',
      ru: 'Последней — потому что только она говорит хоть что-то о том, верен ли ваш дизайн, и стоит своих денег лишь потому, что три предыдущие прямо говорят, что они этого не делают.',
    },
    establishes: {
      en: [
        'Every code point of the format applied, compared as bit patterns — a count over the whole input space, not a bound over a sample.',
        'The reference is ml_dtypes from the JAX project: not written by you, not written by me, not derived from the design under test.',
        'The reference itself described by enumeration — max, min subnormal, infinities, NaN count — before any verdict is printed.',
      ],
      ru: [
        'Применена каждая кодовая точка формата, сверка по битовым образам: счёт по всему пространству входов, а не граница по выборке.',
        'Эталон — ml_dtypes из проекта JAX: не ваш, не мой и не выведенный из проверяемого дизайна.',
        'Сам эталон описан перечислением — максимум, минимальный субнормал, бесконечности, число NaN — до того, как напечатан любой вердикт.',
      ],
    },
    refuses: {
      en: 'Anything about the design that instantiates the module, about sequences of inputs, about synthesis preserving the behaviour, or about formats the reference does not implement.',
      ru: 'Что-либо о дизайне, который инстанцирует модуль, о последовательностях входов, о сохранении поведения при синтезе или о форматах, которых нет в эталоне.',
    },
    snippet: `jobs:
  e5m2:
    uses: gHashTag/trinity/.github/workflows/conformance-check.yml@main
    with:
      module: fp8_e5m2_decode
      sources: src/rtl/fp8_e5m2_decode.v
      input_port: e5m2_in
      width: 8
      reference: float8_e5m2`,
    evidence: {
      en: '66,448 code points across seven formats on my own chip. Six agreed on every one; the seventh disagreed on eight of sixty-four, including the format maximum, and that is now fixed.',
      ru: '66 448 кодовых точек по семи форматам на моём же чипе. Шесть сошлись на каждой; седьмой разошёлся на восьми из шестидесяти четырёх, включая максимум формата, — и это исправлено.',
    },
  },
]

export const START_INTRO = {
  en: 'Four checks, in the order worth adopting them: cheapest and narrowest first, so the first thing you run is the one that cannot waste your afternoon. All four run on your runner, against your checkout. Nothing is uploaded anywhere and none of them has access to anything of mine.',
  ru: 'Четыре проверки в том порядке, в котором их стоит принимать: самая дешёвая и узкая первой, чтобы первое, что вы запустите, не могло съесть ваш день. Все четыре идут на вашем раннере и по вашему checkout. Никуда ничего не загружается, и ни одна не имеет доступа ни к чему моему.',
}

export const START_DEBT = {
  en: 'If a repository has been broken for a while, start the first check with a baseline: name a file that does not exist yet and the run generates it, prints what to commit, and fails with that one instruction. After that it passes on everything already broken and fails only on breakage that is new. A check introduced onto existing debt is otherwise a wall of red about things nobody did today, and it gets switched off before it has caught anything.',
  ru: 'Если репозиторий сломан давно, начните первую проверку с базы: укажите файл, которого ещё нет, и прогон сам его создаст, напечатает, что закоммитить, и упадёт с одной этой инструкцией. Дальше он проходит по всему, что уже сломано, и падает только на новом. Иначе проверка, введённая поверх накопленного долга, — это стена красного о том, чего сегодня никто не делал, и её выключат раньше, чем она что-нибудь поймает.',
}
