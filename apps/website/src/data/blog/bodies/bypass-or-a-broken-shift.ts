import type { Block } from '../types'

// Numbers here come from t27 specs/port/tools/jtag/tdo_verdict.t27 at commit 60166a56 (gHashTag/t27#8032,
// 8 tests), the recording public/term/tri-fpga-jtag-ir/ (2026-10-09, every command exit 0), and the
// bench IDCODE 0x13636093 read from the XC7A200T on 2026-10-04 (openFPGALoader 1.1.1).

type Lang = 'en' | 'ru'

const GOLD = '#ffd700'
const RED = '#ff5c5c'

const FIG_TEXT = {
  en: {
    label: 'The same DR word 0x13636092 with two IR captures: 0x35 gives BYPASS, 0x34 gives a broken shift',
    dr: 'DR word 0x13636092 (bit 0 = 0)',
    left: 'IR capture 0x35',
    right: 'IR capture 0x34',
    lowOk: 'low bits 01',
    lowBad: 'low bits 00',
    bypass: 'BYPASS',
    broken: 'broken shift',
    okWhy: 'the TAP shifts; IDCODE not loaded',
    badWhy: 'the DR word means nothing yet',
  },
  ru: {
    label: 'Одно и то же слово DR 0x13636092 при двух захватах IR: 0x35 даёт BYPASS, 0x34 даёт сломанный сдвиг',
    dr: 'слово DR 0x13636092 (бит 0 = 0)',
    left: 'захват IR 0x35',
    right: 'захват IR 0x34',
    lowOk: 'младшие биты 01',
    lowBad: 'младшие биты 00',
    bypass: 'BYPASS',
    broken: 'сломанный сдвиг',
    okWhy: 'TAP сдвигает; IDCODE не загружен',
    badWhy: 'слово DR пока ничего не значит',
  },
}

function bitsSvg(x: number, y: number, v: number, colour: string): string {
  let s = ''
  for (let b = 0; b < 6; b++) {
    const bit = (v >> (5 - b)) & 1
    const low = b >= 4
    const bx = x + b * 34
    s += `<rect x="${bx}" y="${y}" width="28" height="32" rx="5" fill="none" stroke="${low ? colour : 'currentColor'}" stroke-opacity="${low ? 1 : 0.35}" stroke-width="${low ? 2 : 1}"/>`
    s += `<text x="${bx + 14}" y="${y + 22}" font-size="16" font-weight="700" text-anchor="middle" fill="${low ? colour : 'currentColor'}">${bit}</text>`
  }
  return s
}

function twoVerdictsSvg(lang: Lang = 'en'): string {
  const t = FIG_TEXT[lang]
  let s = `<svg viewBox="0 0 720 210" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${t.label}" style="width:100%;height:auto;font-family:inherit">`
  s += `<text x="10" y="22" font-size="15" font-weight="700" fill="currentColor">${t.dr}</text>`
  const sides = [
    { x: 10, ir: 0x35, c: GOLD, title: t.left, low: t.lowOk, name: t.bypass, why: t.okWhy },
    { x: 370, ir: 0x34, c: RED, title: t.right, low: t.lowBad, name: t.broken, why: t.badWhy },
  ]
  for (const p of sides) {
    s += `<rect x="${p.x}" y="40" width="340" height="160" rx="12" fill="none" stroke="${p.c}" stroke-width="2"/>`
    s += `<text x="${p.x + 16}" y="64" font-size="13" fill="currentColor" fill-opacity="0.7">${p.title} · ${p.low}</text>`
    s += bitsSvg(p.x + 16, 78, p.ir, p.c)
    s += `<text x="${p.x + 16}" y="150" font-size="26" font-weight="800" fill="${p.c}">${p.name}</text>`
    s += `<text x="${p.x + 16}" y="178" font-size="13" fill="currentColor" fill-opacity="0.8">${p.why}</text>`
  }
  return s + '</svg>'
}

export const body: Block[] = [
  {
    kind: 'p',
    text: 'A JTAG decoder reads 32 bits out of a chip and has to say what they mean. A question on X put the weak spot of ours plainly: when the word that comes back has bit 0 clear, how does it tell **BYPASS** from a shift that is simply broken? Until today it did not. It read only the data word, and an even word looked like BYPASS whatever had happened on the wire.',
  },
  { kind: 'h', text: 'The rule that was already in the standard' },
  {
    kind: 'p',
    text: 'IEEE 1149.1 fixes one thing about every TAP: on Capture-IR, the instruction register loads binary 01 into its two lowest cells. So the first two bits out of TDO after an IR scan are 1, then 0, on every compliant chip. The bits above them are the vendor\'s. The Xilinx 7-series IR is 6 bits wide, and its BSDL files give the capture value as `XXXX01`, the upper four being status. We use 0x35 (binary 110101) as the example of that shape; it is not a value we read off a cable in this session.',
  },
  {
    kind: 'p',
    text: 'That gives a check that needs no knowledge of the chip. If the IR capture does not end in 01, the shift is broken: the clock, the TMS sequence, or the TDO path. Then the data word means nothing yet, and calling it BYPASS would send someone to load an instruction on a link that cannot shift.',
  },
  { kind: 'figure', svg: twoVerdictsSvg('en'), caption: 'The same even data word, read twice. With an IR capture ending in 01 it is BYPASS: the link works and the IDCODE instruction is not loaded. With an IR capture ending in 00 it is a broken shift. The two boxed bits decide.' },
  { kind: 'h', text: 'Five checks, in a fixed order' },
  {
    kind: 'ol',
    items: [
      '**stuck high**: the data word is all ones, so nothing drives TDO.',
      '**stuck low**: the data word and the IR capture are both 0.',
      '**broken shift**: the IR capture does not end in 01.',
      '**BYPASS**: the IR capture ends in 01 and bit 0 of the data word is 0.',
      '**IDCODE**: everything else. Only now is the word looked up as a chip ID.',
    ],
  },
  {
    kind: 'p',
    text: 'The order is the point. Stuck lines are tested first, because an all-ones word would otherwise pass the IR test by accident. The IR rule comes before bit 0, so an even word is only called BYPASS once the link has proved it can shift.',
  },
  { kind: 'h', text: 'Where the rule lives' },
  {
    kind: 'p',
    text: 'The rule is a t27 spec: `specs/port/tools/jtag/tdo_verdict.t27`, with the mask 0x3, the expected value 0x1, and 8 tests over the cases above (gHashTag/t27#8032). The bench command `tri fpga-jtag --decode WORD --ir CAPTURE` prints the same verdict and exits 0 only for a real IDCODE. The recording below runs three verdicts, the self-test, the spec\'s own tests, and then a mutant: the capture check replaced by `return true`. The checker reports 6 failures for the mutant, so the tests do look at that line.',
  },
  {
    kind: 'terminal',
    src: 'term/tri-fpga-jtag-ir/session.cast',
    share: 'https://t27.ai/term/tri-fpga-jtag-ir/',
    title: 'tri fpga-jtag --ir · the IR capture must end in 01',
    caption: 'Seven commands in 30.2 s; every shell line returns 0. The decoder itself prints exit 0 for the real IDCODE and exit 1 for BYPASS and for the broken shift. Then the self-test; tdo_verdict.t27 with 8 tests and 8 asserts clean; the mutant, which fails 6 checks.',
  },
  { kind: 'h', text: 'Try it on your own reading' },
  {
    kind: 'p',
    text: 'The **JTAG verdict** widget at t27.ai/widgets/jtag-verdict/ runs the same five checks in the page. Type the IR capture and the data word your probe read, or pick one of the spec\'s seven test vectors, and it shows which check decided, the bits it looked at, and the `tri` command that prints the same answer. The values stay in the page; nothing is read from a cable. For a word that passes as an IDCODE, the widget links to the IDCODE decoder, which takes the 32 bits apart field by field.',
  },
  { kind: 'h', text: 'What this does not show' },
  {
    kind: 'ul',
    items: [
      'A clean verdict means the shift looks sane. It does not mean the chip is configured or the design is healthy.',
      'The IR value in the recording is typed, not read from our board in this session. The board\'s IDCODE, 0x13636093, is a real reading from 2026-10-04.',
      'The bench `tri` command lives in a local tools folder, not yet in a public repository; the spec and the widget are public.',
    ],
  },
]

export const ruBody: Block[] = [
  {
    kind: 'p',
    text: 'Декодер JTAG читает из микросхемы 32 бита и должен сказать, что они значат. Вопрос в X точно указал на наше слабое место: если у вернувшегося слова бит 0 сброшен, как отличить **BYPASS** от сдвига, который просто сломан? До сегодняшнего дня никак. Декодер смотрел только на слово данных, и чётное слово выглядело как BYPASS, что бы ни происходило на проводе.',
  },
  { kind: 'h', text: 'Правило, которое уже было в стандарте' },
  {
    kind: 'p',
    text: 'IEEE 1149.1 фиксирует для любого TAP одну вещь: при Capture-IR регистр инструкций загружает в две младшие ячейки двоичное 01. Значит, первые два бита из TDO после сдвига IR на любой совместимой микросхеме — 1, затем 0. Биты выше принадлежат производителю. У Xilinx 7-й серии IR шириной 6 бит, и в BSDL-файлах значение захвата записано как `XXXX01`, где старшие четыре — статус. Как пример такой формы мы берём 0x35 (двоичное 110101); это не значение, прочитанное с кабеля в этой сессии.',
  },
  {
    kind: 'p',
    text: 'Отсюда проверка, которой не нужно знать микросхему. Если захват IR не заканчивается на 01, сдвиг сломан: такт, последовательность TMS или путь TDO. Тогда слово данных пока ничего не значит, и назвать его BYPASS — значит отправить человека загружать инструкцию по линии, которая не умеет сдвигать.',
  },
  { kind: 'figure', svg: twoVerdictsSvg('ru'), caption: 'Одно и то же чётное слово данных, прочитанное дважды. Если захват IR заканчивается на 01, это BYPASS: линия работает, инструкция IDCODE не загружена. Если на 00 — сломанный сдвиг. Решают два выделенных бита.' },
  { kind: 'h', text: 'Пять проверок в строгом порядке' },
  {
    kind: 'ol',
    items: [
      '**залипание в 1**: слово данных из одних единиц, TDO никто не ведёт.',
      '**залипание в 0**: и слово данных, и захват IR равны 0.',
      '**сломанный сдвиг**: захват IR не заканчивается на 01.',
      '**BYPASS**: захват IR заканчивается на 01, а бит 0 слова данных равен 0.',
      '**IDCODE**: всё остальное. Только теперь слово ищут как идентификатор микросхемы.',
    ],
  },
  {
    kind: 'p',
    text: 'Весь смысл в порядке. Залипания проверяются первыми, иначе слово из одних единиц случайно прошло бы проверку IR. Правило IR стоит раньше бита 0, поэтому чётное слово называется BYPASS только после того, как линия доказала, что умеет сдвигать.',
  },
  { kind: 'h', text: 'Где живёт правило' },
  {
    kind: 'p',
    text: 'Правило — спецификация t27: `specs/port/tools/jtag/tdo_verdict.t27`, маска 0x3, ожидаемое значение 0x1 и 8 тестов на случаи выше (gHashTag/t27#8032). Команда стенда `tri fpga-jtag --decode WORD --ir CAPTURE` печатает тот же вердикт и возвращает 0 только для настоящего IDCODE. В записи ниже — три вердикта, самопроверка, собственные тесты спецификации, а затем мутант: проверка захвата заменена на `return true`. Для мутанта проверка сообщает о 6 провалах, то есть тесты действительно смотрят на эту строку.',
  },
  {
    kind: 'terminal',
    src: 'term/tri-fpga-jtag-ir/session.cast',
    share: 'https://t27.ai/term/tri-fpga-jtag-ir/',
    title: 'tri fpga-jtag --ir · захват IR должен заканчиваться на 01',
    caption: 'Семь команд за 30.2 с; каждая строка оболочки возвращает 0. Сам декодер печатает exit 0 для настоящего IDCODE и exit 1 для BYPASS и сломанного сдвига. Дальше самопроверка; tdo_verdict.t27 — 8 тестов и 8 утверждений без ошибок; мутант, который проваливает 6 проверок.',
  },
  { kind: 'h', text: 'Проверьте на своём чтении' },
  {
    kind: 'p',
    text: 'Виджет **JTAG verdict** на t27.ai/widgets/jtag-verdict/ выполняет те же пять проверок прямо на странице. Введите захват IR и слово данных, которые прочитал ваш пробник, или выберите один из семи тестовых векторов спецификации — виджет покажет, какая проверка решила, на какие биты она смотрела, и команду `tri`, которая печатает тот же ответ. Значения остаются на странице, с кабеля ничего не читается. Для слова, прошедшего как IDCODE, виджет ведёт в декодер IDCODE, который разбирает 32 бита по полям.',
  },
  { kind: 'h', text: 'Чего это не показывает' },
  {
    kind: 'ul',
    items: [
      'Чистый вердикт значит, что сдвиг выглядит здоровым. Он не значит, что микросхема сконфигурирована или проект исправен.',
      'Значение IR в записи введено руками, а не прочитано с нашей платы в этой сессии. IDCODE платы, 0x13636093, — настоящее чтение от 2026-10-04.',
      'Команда `tri` стенда лежит в локальной папке инструментов, ещё не в публичном репозитории; спецификация и виджет публичны.',
    ],
  },
]
