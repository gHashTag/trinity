import type { Block } from '../types'

// Numbers here come from specs/course/goldenfloat.t27 and the vendored specs it
// opens, and from the synthesis runs of 2026-10-08: yosys 0.67+post (git sha1
// b8e7da6f), nextpnr-xilinx 0.9.2-107-g7037c948, part xc7a200tfbg676-1, seed 1,
// each operator wrapped in a register-shell bench whose empty cost is 143 LUTs
// and 830.56 MHz. The binary gfN specs carry no arithmetic functions (gf16 has
// extract/encode/decode only), so the cost table covers the GF-T16 operators,
// which are the ops the family specs define. Read on 2026-10-08.

export const body: Block[] = [
  {
    kind: 'p',
    text: 'Course 3 taught GoldenFloat one width at a time, and 17 of its 27 lessons were a width and its table. It is regrouped around concepts now: the ladder of splits read as one table, rounding to nearest even, the family beside the IEEE widths, what the operators cost in silicon, the exponent in trits, and a last lesson that states what the course claims. Still 27 lessons in 9 modules of 3, still every lesson one widget and one spec.',
  },
  { kind: 'h', text: 'What changed and what did not' },
  {
    kind: 'p',
    text: 'No widget was minted and none was dropped: the 27 mains of the old course are the 27 mains of the new one, redistributed, and the width widgets also surface as ALSO chips on the concept lessons that name them. Modules 1 and 2 (the rule, why phi, why three), the GF16 module, the trit modules and the decode lesson kept their texts; 10 lessons are new; the near-identical width pages are gone. The honest-table rule is unchanged: outside the cost module every number is a constant or test value of the spec a lesson opens, or arithmetic of them.',
  },
  { kind: 'h', text: 'Four operators, one bench, real numbers' },
  {
    kind: 'p',
    text: 'The new module quotes one named synthesis run per lesson. Method: each operator generated to Verilog by t27c, wrapped in a register shell -- LFSR-driven inputs, a checksum accumulator collapsed to a parity bit so the top has three pins -- synthesized by yosys, placed and routed by nextpnr-xilinx to the xc7a200tfbg676-1 chipdb, seed 1. The empty shell costs 143 LUTs and routes at 830.56 MHz; every marginal below subtracts it.',
  },
  {
    kind: 'table',
    head: ['Operator', 'LUT', 'CARRY4', 'FF', 'DSP48E1', 'Fmax post-route', 'LUT over shell'],
    rows: [
      ['gft_smul, the signed update w\' = w - eta * g', '1134', '79', '96', '0', '22.74 MHz', '991'],
      ['gft_sadd, the signed add and negate', '3236', '223', '96', '0', '15.59 MHz', '3093'],
      ['gft_add_rne, the rounded magnitude add', '1010', '72', '80', '0', '38.90 MHz', '867'],
      ['gft_mul_rne, the rounded magnitude multiply', '960', '79', '80', '0', '24.94 MHz', '817'],
    ],
  },
  {
    kind: 'p',
    text: 'Three findings worth the module. Zero DSP48E1 anywhere: yosys maps these operators to fabric only. The add, not the multiply, sets the update\'s clock -- 223 carry cells against 79, the alignment and borrow chains of subtraction -- and 3236 of 269200 LUTs is about one percent of the part. And the rounded multiply keeps 16 fewer flip-flops than the shell\'s 96: its magnitude result is 16 bits wide, so the top half of the checksum register is provably always zero, and synthesis deletes flip-flops that can never change. The scope is stated in the lessons: the binary gfN specs define no arithmetic, so this table prices the GF-T16 operators, which are the ops the family specs have.',
  },
  { kind: 'h', text: 'What the browser still does not run' },
  {
    kind: 'p',
    text: 'The player compiles every lesson spec and evaluates its constant asserts; function tests still run under t27c on a machine (trinity#1477). The new last lesson, "What this course claims", is the receipts page: which numbers are spec constants, which come from the named synthesis run, and which the browser never ran. Where next: the AI numbers course runs these operators inside networks, and course 1 takes one spec to a bitstream.',
  },
  { kind: 'h', text: 'Try it' },
  {
    kind: 'p',
    text: 'The course is at t27.ai/learn/goldenfloat/, Russian and English. Lesson 19, "What a multiply costs", opens gft_smul.t27 next to its measured row; lesson 21, "Rounding in silicon", shows the flip-flops the synthesiser deletes.',
  },
]

export const ruBody: Block[] = [
  {
    kind: 'p',
    text: 'Курс 3 учил GoldenFloat по одной ширине за раз, и 17 из 27 уроков были «ширина и её таблица». Теперь он перегруппирован по понятиям: лестница делений как одна таблица, округление к ближайшему чётному, семейство рядом с ширинами IEEE, цена операторов в кремнии, порядок в тритах и последний урок, который говорит, что курс утверждает. По-прежнему 27 уроков в 9 модулях по 3, в каждом виджет и спека.',
  },
  { kind: 'h', text: 'Что изменилось и что нет' },
  {
    kind: 'p',
    text: 'Ни один виджет не создан и не выброшен: 27 главных виджетов старого курса — это 27 главных виджетов нового, перераспределённые, а виджеты ширин дополнительно выходят чипами ALSO на уроках-понятиях, которые их называют. Модули 1 и 2 (правило, почему phi, почему три), модуль GF16, модули тритов и урок декодирования сохранили тексты; 10 уроков новые; почти одинаковые страницы ширин ушли. Правило честной таблицы не изменилось: вне модуля цены каждое число — константа или тестовое значение спеки, которую открывает урок, или арифметика над ними.',
  },
  { kind: 'h', text: 'Четыре оператора, один стенд, настоящие числа' },
  {
    kind: 'p',
    text: 'Новый модуль цитирует по одному именованному прогону синтеза на урок. Метод: каждый оператор сгенерирован в Verilog командой t27c, завёрнут в регистровую оболочку — входы от LFSR, аккумулятор контрольной суммы, свёрнутый в бит чётности, чтобы верх имел три ноги — синтезирован yosys, размещён и протрассирован nextpnr-xilinx на chipdb xc7a200tfbg676-1, seed 1. Пустая оболочка стоит 143 LUT и трассируется на 830.56 MHz; каждое предельное число ниже вычитает её.',
  },
  {
    kind: 'table',
    head: ['Оператор', 'LUT', 'CARRY4', 'FF', 'DSP48E1', 'Fmax после трассировки', 'LUT сверх оболочки'],
    rows: [
      ['gft_smul, знаковое обновление w\' = w - eta * g', '1134', '79', '96', '0', '22.74 MHz', '991'],
      ['gft_sadd, знаковое сложение и отрицание', '3236', '223', '96', '0', '15.59 MHz', '3093'],
      ['gft_add_rne, округлённое сложение мантисс', '1010', '72', '80', '0', '38.90 MHz', '867'],
      ['gft_mul_rne, округлённое умножение мантисс', '960', '79', '80', '0', '24.94 MHz', '817'],
    ],
  },
  {
    kind: 'p',
    text: 'Три находки, ради которых модуль существует. Ноль DSP48E1 везде: yosys кладёт эти операторы только на фабрику. Часы обновлению задаёт сложение, а не умножение — 223 ячейки переноса против 79, цепи выравнивания и заёма вычитания — а 3236 из 269200 LUT — около одного процента платы. И округлённое умножение держит на 16 триггеров меньше, чем оболочка со своими 96: результат мантиссы имеет ширину 16 битов, поэтому верхняя половина регистра контрольной суммы заведомо всегда ноль, и синтез удаляет триггеры, которые никогда не изменятся. Границы сказаны в уроках: двоичные спеки gfN не определяют арифметики, поэтому таблица оценивает операторы GF-T16 — те операции, которые в спеках семейства есть.',
  },
  { kind: 'h', text: 'Чего браузер по-прежнему не запускает' },
  {
    kind: 'p',
    text: 'Плеер компилирует каждую спеку урока и вычисляет её константные проверки; функциональные тесты по-прежнему идут под t27c на машине (trinity#1477). Новый последний урок, «Что этот курс утверждает», — страница квитанций: какие числа — константы спек, какие взяты из именованного прогона синтеза и чего браузер никогда не запускал. Что дальше: курс об ИИ-числах запускает эти операторы внутри сетей, а курс 1 доводит одну спеку до битстрима.',
  },
  { kind: 'h', text: 'Попробуйте' },
  {
    kind: 'p',
    text: 'Курс — на t27.ai/learn/goldenfloat/, по-русски и по-английски. Урок 19, «Сколько стоит умножение», открывает gft_smul.t27 рядом с его измеренной строкой; урок 21, «Округление в кремнии», показывает триггеры, которые синтезатор удаляет.',
  },
]
