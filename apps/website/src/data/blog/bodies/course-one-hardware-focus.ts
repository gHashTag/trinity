import type { Block } from '../types'

// Lesson titles, module names and spec paths come from specs/course/course.t27;
// the counts (27 lessons, 7 courses, 189 lesson specs, 272 asserts, 392 pages,
// 22 tests) are the course generator's own report from the run that shipped this.

export const body: Block[] = [
  {
    "kind": "p",
    "text": "Course 1 set out to teach an FPGA and spent its middle re-teaching course 0: hello world, test blocks, compiler stages, seven backends. Eleven lessons opened files from specs/tutorial that had nothing to do with hardware, and two of the nine modules were named program and compiler. Issue trinity#1478 asked for the dedup. It is done: every lesson of course 1 now opens hardware."
  },
  {
    "kind": "h",
    "text": "What changed"
  },
  {
    "kind": "p",
    "text": "The two compiler modules are gone, replaced by Clocked logic (wires compute, registers remember) and Proof in the spec (testbenches, waves, planted bugs). Six lessons in them are new: wires-and-registers, ready-and-valid, the-design-in-one-spec, a-testbench-is-a-spec, watch-it-in-waves, compiles-is-not-correct. Every lesson that opened a tutorial file now opens a hardware spec instead: the bool and clock types, hybrid arithmetic, the clocked counter, AXI4, the top level, a testbench, the simulator, formal assertions, the UART, timing, and the x7 bench tool. A test in the course spec pins each re-pointed path, so a regression back to specs/tutorial fails the build."
  },
  {
    "kind": "p",
    "text": "The course now names its prerequisite: the description says it starts where the t27 basics course ends, and its lessons hand over to the courses that go deeper -- the clocked-logic module points at clocks-and-cdc, proof-in-the-spec at verify-hardware, the top-level lesson at buses-and-peripherals."
  },
  {
    "kind": "h",
    "text": "What forced the honest shape"
  },
  {
    "kind": "p",
    "text": "The course generator demands that a widget be the main exhibit of at most one lesson across all seven courses. Reshaping the middle modules inside that rule is what exposed the duplication the issue was about: a clock-crossing lesson and a mutation-testing lesson here would have been thin copies of the clocks-and-cdc and verify-hardware courses, and no widgets were left to give them. Their subjects stay where the full courses treat them, and the middle modules teach what only this course does: what changes on a clock edge, and how a hardware spec carries its own proof."
  },
  {
    "kind": "h",
    "text": "Checks"
  },
  {
    "kind": "ul",
    "items": [
      "The generator is clean: 189 lesson specs across 7 courses compile clean, 272 spec asserts hold.",
      "22 course tests pass, including the three tests in course.t27 that pin the new module names, the re-pointed spec paths and the widget rule.",
      "392 lesson pages regenerated for 7 courses, with 14 new cards drawn.",
      "The typecheck ratchet is flat: no file gained type errors."
    ]
  },
  {
    "kind": "h",
    "text": "What it still does not do"
  },
  {
    "kind": "ul",
    "items": [
      "The browser runner cannot execute hardware spec tests (trinity#1477), so the widgets here show recorded t27c runs, not live ones.",
      "The lesson specs live in the site's copy of the spec tree and are not yet in gHashTag/t27."
    ]
  },
  {
    "kind": "h",
    "text": "Try it"
  },
  {
    "kind": "ul",
    "items": [
      "Course 1, From spec to chip: t27.ai/learn/course/",
      "The prerequisite, t27 basics: t27.ai/learn/",
      "The course spec itself: t27.ai/learn/course.t27"
    ]
  }
]

export const ruBody: Block[] = [
  {
    "kind": "p",
    "text": "Курс 1 собирался учить FPGA, а середину у него занимал повтор курса 0: hello world, тестовые блоки, стадии компилятора, семь бэкендов. Одиннадцать уроков открывали файлы из specs/tutorial, не имевшие отношения к железу, а два из девяти модулей назывались program и compiler. Задача trinity#1478 просила убрать дубли. Убраны: теперь каждый урок курса 1 открывает железо."
  },
  {
    "kind": "h",
    "text": "Что изменилось"
  },
  {
    "kind": "p",
    "text": "Два компиляторных модуля ушли, их место заняли «Тактовая логика» (провода считают, регистры помнят) и «Доказательство в спеке» (тестбенчи, волны, посаженные ошибки). Шесть уроков в них новые: wires-and-registers, ready-and-valid, the-design-in-one-spec, a-testbench-is-a-spec, watch-it-in-waves, compiles-is-not-correct. Каждый урок, открывавший туториальный файл, теперь открывает аппаратную спеку: типы bool и clock, гибридная арифметика, тактируемый счётчик, AXI4, верхний уровень, тестбенч, симулятор, формальные утверждения, UART, тайминг и инструмент x7-bench. Тест в спеке курса закрепляет каждый переназначенный путь, поэтому откат к specs/tutorial ломает сборку."
  },
  {
    "kind": "p",
    "text": "Курс называет свой пререквизит: описание говорит, что он начинается там, где заканчивается курс основ t27, а уроки передают эстафету курсам, которые идут глубже, -- модуль тактовой логики указывает на clocks-and-cdc, доказательство в спеке -- на verify-hardware, урок о верхнем уровне -- на buses-and-peripherals."
  },
  {
    "kind": "h",
    "text": "Что заставило форму остаться честной"
  },
  {
    "kind": "p",
    "text": "Генератор курсов требует, чтобы виджет был главным экспонатом не больше чем одного урока из всех семи курсов. Перестройка средних модулей внутри этого правила и вскрыла дубль, о котором шла задача: урок о переходе между доменами и урок о мутационном тестировании были бы тонкими копиями курсов clocks-and-cdc и verify-hardware, и свободных виджетов для них не осталось. Их темы живут там, где им посвящены целые курсы, а средние модули учат тому, чего никто кроме этого курса не учит: что меняется на фронте такта и как аппаратная спека несёт собственное доказательство."
  },
  {
    "kind": "h",
    "text": "Проверки"
  },
  {
    "kind": "ul",
    "items": [
      "Генератор чист: 189 спек уроков по 7 курсам компилируются без ошибок, 272 утверждения в спеках выполняются.",
      "Проходят 22 теста курсов, включая три теста в course.t27, которые закрепляют новые имена модулей, переназначенные пути спек и правило виджетов.",
      "Перегенерированы 392 страницы уроков по 7 курсам, нарисованы 14 новых карточек.",
      "Хомут типизации не сдвинулся: ни один файл не получил ошибок."
    ]
  },
  {
    "kind": "h",
    "text": "Чего он пока не делает"
  },
  {
    "kind": "ul",
    "items": [
      "Раннер в браузере не умеет исполнять тесты аппаратных спек (trinity#1477), поэтому виджеты показывают записанные прогоны t27c, а не живые.",
      "Спеки уроков лежат в копии дерева спек на сайте, в gHashTag/t27 их пока нет."
    ]
  },
  {
    "kind": "h",
    "text": "Попробовать"
  },
  {
    "kind": "ul",
    "items": [
      "Курс 1, «От спеки к чипу»: t27.ai/ru/learn/course/",
      "Пререквизит, основы t27: t27.ai/ru/learn/",
      "Сама спека курса: t27.ai/learn/course.t27"
    ]
  }
]
