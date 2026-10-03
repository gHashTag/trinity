import type { Block } from '../types'
import { FLOW, LAYERS, flowBefore, flowAfter, savedPerBuild, ceiling, hoursPerYear } from '../../devkit'

// Every number comes from src/data/devkit.ts, the record of one `tri devkit flow --build` run.
const pct = (s: number) => `${((100 * s) / flowBefore).toFixed(1)} %`
const open = LAYERS.filter(l => !l.t27)

export const body: Block[] = [
  {
    kind: 'p',
    text: `The previous post rebuilt the back half of openXC7 from t27 specs. FASM to frames and frames to bitstream now come from the specs, byte for byte. That raises the next question: what would it be worth to do the same for every layer of the flow? To answer it we timed every layer of one real build and put the numbers next to each other.`,
  },
  { kind: 'h', text: 'One build, every layer' },
  {
    kind: 'p',
    text: `The design is ${FLOW.design} for the ${FLOW.part} on an AX7203 board, ${FLOW.fasmLines.toLocaleString('en-US')} lines of FASM. \`tri devkit flow --build\` runs the openXC7 flow with every step timed. It then runs the t27 replacements on the same FASM, three times each, and compares their output with openXC7's byte for byte. The times are wall seconds on one laptop at a load of ${FLOW.load}.`,
  },
  {
    kind: 'table',
    head: ['Layer', 'openXC7 tool', 'Now', 'Share', 't27', 'Same bytes'],
    rows: [
      ...LAYERS.map(l => [
        `${l.id} ${l.name}`,
        `\`${l.tool}\``,
        `${l.s.toFixed(2)} s`,
        pct(l.s),
        l.t27 ? `\`${l.t27.tool}\` ${l.t27.s.toFixed(2)} s` : 'not yet',
        l.t27 ? (l.t27.identical ? 'yes' : 'no') : '–',
      ]),
      ['Whole flow', '', `${flowBefore.toFixed(2)} s`, '', `${flowAfter.toFixed(2)} s (${(flowBefore / flowAfter).toFixed(2)}×)`, ''],
    ],
  },
  {
    kind: 'terminal',
    src: FLOW.cast,
    share: FLOW.share,
    title: 'tri devkit · the FPGA flow, layer by layer',
    caption: 'The recorded run: `tri devkit flow --build` and `tri devkit impact`. Every byte printed is real and arrives when it did; the prompt and the typing are staged, and silences over 2 s are shortened, with a note in the title bar while that happens.',
  },
  {
    kind: 'p',
    text: `The rewrite so far saves ${savedPerBuild.toFixed(1)} s on this build, all of it in L3. L4 is a tie: \`bitwalk --write\` took 0.25 s against 0.22 s for \`xc7frames2bit\`. The bitstream is the same file either way, so this is a faster route to the same result, not a better result.`,
  },
  { kind: 'h', text: 'Where the rest of the time goes' },
  {
    kind: 'p',
    text: `After L3, place and route is ${pct(LAYERS[1].s)} of the build and synthesis is ${pct(LAYERS[0].s)}. Amdahl's law gives the most a rewrite of either could ever give: make the layer take 0 s and see what is left.`,
  },
  {
    kind: 'table',
    head: ['If this took 0 s', 'Flow', 'Against openXC7 today'],
    rows: open.map(l => {
      const c = ceiling(l)
      return [`${l.id} ${l.name}`, `${flowAfter.toFixed(1)} s → ${c.flow.toFixed(1)} s`, `${c.x.toFixed(2)}×`]
    }),
  },
  {
    kind: 'p',
    text: 'So the next lever is place and route, by a wide margin. A spec-driven synthesis step, even an instant one, caps the whole flow at 1.65×. These are ceilings, not plans. nextpnr-xilinx is a large, mature C++ program, and the realistic path is work inside it (we already send patches upstream) plus spec-checked timing and routing rules, not a rewrite from zero.',
  },
  { kind: 'h', text: 'What it is worth in hours' },
  {
    kind: 'p',
    text: `\`tri devkit impact\` turns the saving into hours. At an assumed 20 builds a day for one person over 230 working days, ${savedPerBuild.toFixed(1)} s a build is ${hoursPerYear(savedPerBuild, 20, 1).toFixed(1)} hours a year of waiting. The builds and the people are assumptions, so the page at t27.ai/#/devkit lets you put in your own.`,
  },
  { kind: 'h', text: 'Can I run it?' },
  {
    kind: 'p',
    text: 'Not yet. The run above used a local build of `tri devkit`, and `bitwalk` is built from an open pull request, gHashTag/t27#5609. Neither is in a `tri` release, so there is no install command to give here. Both are to ship in the `tri` release archives with a one-line install; that work is tracked in github.com/gHashTag/trinity/issues/1272, and this post will get the command when a release has it.',
  },
  { kind: 'h', text: 'What this does not show' },
  {
    kind: 'ul',
    items: [
      'One design on one laptop. The 1.40× is for this build; a design that spends less time in fasm2frames gains less.',
      'The openXC7 times come from the build, and the t27 times were taken right after it in the same session. Load moved between them.',
      'L1 and L2 are not rewritten. Their rows are ceilings.',
      'Loading onto the board (16.7 s SRAM load in the earlier board run) is outside the flow time above.',
    ],
  },
]

// The same post in Russian, from the same numbers. Decimal comma, as in the other Russian posts.
const ru = (n: number, d = 2) => n.toFixed(d).replace('.', ',')
const pctRu = (s: number) => `${ru((100 * s) / flowBefore, 1)} %`
const loadRu = FLOW.load.replace(/^([\d.]+) on (\d+) cpus$/, (_, a: string, n: string) => `${a.replace('.', ',')} на ${n} ядрах`)
const NAME_RU: Record<string, string> = {
  L1: 'Синтез',
  L2: 'Размещение и разводка',
  L3: 'FASM → кадры',
  L4: 'Кадры → .bit',
}

export const ruBody: Block[] = [
  {
    kind: 'p',
    text: `В прошлом посте мы пересобрали заднюю половину openXC7 из t27-спеков. FASM в кадры и кадры в битстрим теперь получаются из спеков, байт в байт. Отсюда следующий вопрос: сколько стоило бы сделать то же самое для каждого слоя flow? Чтобы ответить, мы засекли каждый слой одной настоящей сборки и поставили числа рядом.`,
  },
  { kind: 'h', text: 'Одна сборка, все слои' },
  {
    kind: 'p',
    text: `Дизайн — ${FLOW.design} для ${FLOW.part} на плате AX7203, ${FLOW.fasmLines.toLocaleString('ru-RU')} строк FASM. Команда \`tri devkit flow --build\` запускает flow openXC7 с замером каждого шага. Затем она трижды запускает t27-замены на том же FASM и сравнивает их вывод с выводом openXC7 байт в байт. Время — секунды по часам на одном ноутбуке при нагрузке ${loadRu}.`,
  },
  {
    kind: 'table',
    head: ['Слой', 'Инструмент openXC7', 'Сейчас', 'Доля', 't27', 'Те же байты'],
    rows: [
      ...LAYERS.map(l => [
        `${l.id} ${NAME_RU[l.id]}`,
        `\`${l.tool}\``,
        `${ru(l.s)} с`,
        pctRu(l.s),
        l.t27 ? `\`${l.t27.tool}\` ${ru(l.t27.s)} с` : 'пока нет',
        l.t27 ? (l.t27.identical ? 'да' : 'нет') : '–',
      ]),
      ['Весь flow', '', `${ru(flowBefore)} с`, '', `${ru(flowAfter)} с (${ru(flowBefore / flowAfter)}×)`, ''],
    ],
  },
  {
    kind: 'terminal',
    src: FLOW.cast,
    share: FLOW.share,
    title: 'tri devkit · the FPGA flow, layer by layer',
    caption: 'Записанный прогон: `tri devkit flow --build` и `tri devkit impact`. Каждый напечатанный байт настоящий и появляется тогда, когда появился; приглашение и набор команд постановочные, паузы длиннее 2 с сокращены, и пока это происходит, в заголовке окна стоит пометка. Сама запись на английском.',
  },
  {
    kind: 'p',
    text: `Переписанное на сегодня экономит ${ru(savedPerBuild, 1)} с на этой сборке, и всё это в L3. L4 — ничья: \`bitwalk --write\` занял 0,25 с против 0,22 с у \`xc7frames2bit\`. Битстрим в обоих случаях один и тот же файл, так что это более быстрый путь к тому же результату, а не лучший результат.`,
  },
  { kind: 'h', text: 'Куда уходит остальное время' },
  {
    kind: 'p',
    text: `После L3 размещение и разводка — ${pctRu(LAYERS[1].s)} сборки, синтез — ${pctRu(LAYERS[0].s)}. Закон Амдала даёт максимум, который мог бы дать переписанный любой из них: пусть слой занимает 0 с, и посмотрим, что останется.`,
  },
  {
    kind: 'table',
    head: ['Если бы это заняло 0 с', 'Flow', 'Против openXC7 сегодня'],
    rows: open.map(l => {
      const c = ceiling(l)
      return [`${l.id} ${NAME_RU[l.id]}`, `${ru(flowAfter, 1)} с → ${ru(c.flow, 1)} с`, `${ru(c.x)}×`]
    }),
  },
  {
    kind: 'p',
    text: 'Значит, следующий рычаг — размещение и разводка, с большим отрывом. Синтез из спеков, даже мгновенный, ограничивает весь flow 1,65×. Это потолки, а не планы. nextpnr-xilinx — большая зрелая программа на C++, и реалистичный путь — работа внутри неё (мы уже отправляем туда патчи) плюс проверяемые спеками правила тайминга и разводки, а не переписывание с нуля.',
  },
  { kind: 'h', text: 'Сколько это в часах' },
  {
    kind: 'p',
    text: `\`tri devkit impact\` переводит экономию в часы. При допущении 20 сборок в день у одного человека за 230 рабочих дней ${ru(savedPerBuild, 1)} с на сборку — это ${ru(hoursPerYear(savedPerBuild, 20, 1), 1)} часа ожидания в год. Число сборок и людей — допущения, поэтому страница t27.ai/#/devkit даёт подставить свои.`,
  },
  { kind: 'h', text: 'Можно ли это запустить у себя?' },
  {
    kind: 'p',
    text: 'Пока нет. Прогон выше сделан локальной сборкой `tri devkit`, а `bitwalk` собран из открытого pull request, gHashTag/t27#5609. Ни того, ни другого нет в релизе `tri`, поэтому команды установки здесь нет. Оба должны войти в архивы релиза `tri` с установкой одной строкой; эта работа ведётся в github.com/gHashTag/trinity/issues/1272, и команда появится в посте, когда она будет в релизе.',
  },
  { kind: 'h', text: 'Чего это не показывает' },
  {
    kind: 'ul',
    items: [
      'Один дизайн на одном ноутбуке. 1,40× — для этой сборки; дизайн, который проводит меньше времени в fasm2frames, выиграет меньше.',
      'Время openXC7 взято из сборки, время t27 — сразу после неё в той же сессии. Нагрузка между ними менялась.',
      'L1 и L2 не переписаны. Их строки — потолки.',
      'Загрузка в плату (16,7 с загрузки в SRAM в прошлом прогоне на плате) не входит во время flow выше.',
    ],
  },
]
