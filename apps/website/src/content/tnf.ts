// Единственный источник правды для главной страницы t27.ai.
//
// Каждое число здесь взято из статьи «Trinity S³AI: Ternary Network Floats»
// (D. Vasilev, 11.08.2026) и несёт тег происхождения. Правило дома: цифра без
// тега на страницу не попадает. Теги:
//   measured    — наблюдено запуском названного инструмента на железе автора
//   proved      — доказано в статье (номер теоремы указан)
//   coq         — машинно проверено в Coq
//   spec        — свойство спецификации, не измерение
//   derived     — выведено из измеренного, не наблюдено напрямую
//   competitor  — результат конкурента, воспроизведён и признан
//   retracted   — заявление отозвано; показывается как отозванное
//
// Тулчейн всех аппаратных чисел: openXC7 (Yosys 0.65 + nextpnr-xilinx 1743d0f)
// + Icarus Verilog 13.0, XC7A200T (ALINX AX7203), медиана 5 seed'ов,
// DSP-инференс выключен.

/* 'terms' и 'plan' добавлены под блок инвестиций: условия предложения и план
   расходования — это не измерения и не теоремы, и метка обязана это говорить,
   иначе они читаются как остальные числа страницы. */
export type Tag = 'measured' | 'proved' | 'coq' | 'spec' | 'derived' | 'competitor' | 'retracted' | 'terms' | 'plan' | 'external'

export const TAG_LABEL: Record<Tag, { en: string; ru: string; color: string }> = {
  measured: { en: 'measured', ru: 'измерено', color: '#00FF88' },
  proved: { en: 'proved', ru: 'доказано', color: '#7CC7FF' },
  coq: { en: 'machine-checked in Coq', ru: 'машинно проверено в Coq', color: '#C08CFF' },
  spec: { en: 'specification', ru: 'спецификация', color: '#FFD700' },
  derived: { en: 'derived', ru: 'выведено', color: '#FFA45C' },
  competitor: { en: 'competitor result', ru: 'результат конкурента', color: '#9BA3AF' },
  retracted: { en: 'retracted', ru: 'отозвано', color: '#FF6B6B' },
  terms: { en: 'offer terms', ru: 'условия предложения', color: '#E0C878' },
  plan: { en: 'plan, not a result', ru: 'план, не результат', color: '#B0B8C4' },
  external: { en: 'third-party figure', ru: 'внешний источник', color: '#7FB3FF' },
}

export const PAPER = {
  title: { en: 'Trinity S³AI: Ternary Network Floats', ru: 'Trinity S³AI: Ternary Network Floats' },
  author: 'D. Vasilev',
  orcid: '0009-0008-4294-6159',
  date: { en: '11 August 2026', ru: '11 августа 2026' },
  theorems: 52,
  retractions: 16,
  pages: 60,
}

/* ─────────────────────────── HERO ─────────────────────────── */

export const hero = {
  eyebrow: {
    en: 'TNF · GFTernary — a reference pair for the ternary datapath',
    ru: 'TNF · GFTernary — референсная пара для тернарного датапути',
  },
  identity: 'r² = r + 1',
  headline: {
    en: 'Where the weight is a code, the format is not a preference.',
    ru: 'Там, где вес — это код, формат перестаёт быть предпочтением.',
  },
  sub: {
    en: 'A ternary neuron has exactly three sites where a number format could live and needs one. GFTernary closes the weight. TNF closes the accumulator. No published pair closes both.',
    ru: 'У тернарного нейрона ровно три места, где мог бы жить числовой формат, и нужен только одному. GFTernary закрывает вес. TNF закрывает аккумулятор. Ни одна опубликованная пара не закрывает оба.',
  },
  metrics: [
    {
      value: '66 LUT',
      unit: '@ 974.66 MHz',
      label: { en: 'GFTernary decoder, isolated', ru: 'декодер GFTernary, изолированно' },
      note: { en: 'Bare wire on the same part is 112 LUT @ 827.81 MHz', ru: 'Голый провод на той же части — 112 LUT @ 827.81 МГц' },
      tag: 'measured' as Tag,
    },
    {
      value: '0.1797',
      unit: 'MHz/LUT',
      label: { en: 'Throughput per area, 20 range-bearing formats', ru: 'Пропускная способность на площадь, 20 форматов с диапазоном' },
      note: { en: '+10.2% over binary32 (0.1631); 6.1× over posit32 (0.0295)', ru: '+10.2% к binary32 (0.1631); 6.1× к posit32 (0.0295)' },
      tag: 'measured' as Tag,
    },
    {
      value: '0',
      unit: { en: 'rounding error', ru: 'ошибок округления' } as any,
      label: { en: 'Whole linear path in Z[φ], any fan-in, any depth', ru: 'Весь линейный путь в Z[φ], любой fan-in, любая глубина' },
      note: { en: 'Theorem 26; weight application is a Fibonacci step (a,b) ↦ (b, a+b)', ru: 'Теорема 26; применение веса = шаг Фибоначчи (a,b) ↦ (b, a+b)' },
      tag: 'coq' as Tag,
    },
    {
      value: '28 LUT',
      unit: { en: 'per weight', ru: 'на вес' } as any,
      label: { en: 'Ternary neuron, zero DSP at any fan-in', ru: 'Тернарный нейрон, нулевой DSP при любом fan-in' },
      note: { en: 'fan-in 8, DSP inference disabled', ru: 'fan-in 8, DSP-инференс выключен' },
      tag: 'measured' as Tag,
    },
  ],
  ctaPrimary: { en: 'Read the claim', ru: 'Читать тезис' },
  ctaSecondary: { en: 'Limits and retractions', ru: 'Границы и ретракции' },
}

/* ──────────────────── THE CLAIM: three legs ──────────────────── */

export const claim = {
  badge: { en: 'WHAT IS CLAIMED', ru: 'ЧТО ИМЕННО ЗАЯВЛЕНО' },
  title: {
    en: 'For a ternary datapath, {GFTernary, TNF} is a reference format',
    ru: 'Для тернарного датапути пара {GFTernary, TNF} — референсный формат',
  },
  sub: {
    en: 'Reference is not a superlative. It rests on three properties, each of which is a measurement rather than a preference — and each of which can be attacked directly.',
    ru: '«Референсный» — не превосходная степень. Слово держится на трёх свойствах, каждое из которых — измерение, а не предпочтение, и каждое можно атаковать напрямую.',
  },
  legs: [
    {
      n: '1',
      name: { en: 'Completeness', ru: 'Полнота' },
      body: {
        en: 'Three sites: the weight (multiplication is a sign-select, so the weight is a code), the sample (arrives ADC-native), the accumulator (the only object carrying dynamic range). GFTernary closes the weight, TNF closes the accumulator. Ternary methods in the literature answer the weight and leave the accumulator in fp16 or int8; the format literature answers the accumulator and assumes a multiplier exists.',
        ru: 'Три места: вес (умножение = sign-select, значит вес — это код), сэмпл (приходит ADC-native), аккумулятор (единственный объект с динамическим диапазоном). GFTernary закрывает вес, TNF закрывает аккумулятор. Тернарные методы в литературе отвечают на вес и оставляют аккумулятор в fp16 или int8; форматная литература отвечает на аккумулятор и предполагает, что умножитель есть.',
      },
      tag: 'proved' as Tag,
    },
    {
      n: '2',
      name: { en: 'Forced, not chosen', ru: 'Вынужденность, а не выбор' },
      body: {
        en: 'The alphabet radix is the only r > 1 with r² = r + 1 (Theorem 25). The E/M split is the solution of a maximisation with the range constraint active (Theorem 23). Once the workload range is measured, there is no free parameter left to tune.',
        ru: 'Основание алфавита — единственное r > 1 с r² = r + 1 (Теорема 25). Разбиение E/M — решение задачи максимизации с активным ограничением диапазона (Теорема 23). Как только диапазон нагрузки измерен, свободного параметра для тюнинга не остаётся.',
      },
      tag: 'proved' as Tag,
    },
    {
      n: '3',
      name: { en: 'Predictive', ru: 'Предсказательность' },
      body: {
        en: 'Mean relative error is a closed form in one number, the mantissa width: E[|rel err|] = ½·E[1/s]·2^−(M+1), independent of the exponent (Theorem 1). Predicted 0.3861 on our workload; measured 0.3756 on average across eight rungs, spread 0.369–0.390. The accumulator can therefore be sized before it is built.',
        ru: 'Средняя относительная ошибка — замкнутая форма от одного числа, ширины мантиссы: E[|отн. ошибка|] = ½·E[1/s]·2^−(M+1), независимо от экспоненты (Теорема 1). Предсказание 0.3861 на нашей нагрузке; измерено в среднем 0.3756 на восьми ступенях, разброс 0.369–0.390. Значит, аккумулятор можно отмерить до того, как он построен.',
      },
      tag: 'measured' as Tag,
    },
  ],
}

/* ──────────────────────── THE TWO FORMATS ──────────────────────── */

export const formats = {
  badge: { en: 'THE TWO FORMATS', ru: 'ДВА ФОРМАТА' },
  title: { en: 'One closes the weight. One closes the accumulator.', ru: 'Один закрывает вес. Другой — аккумулятор.' },
  tnf: {
    name: 'TNF16',
    layout: { en: '[ s | E_t = 4 balanced-ternary trits | M = 11 bits ]', ru: '[ s | E_t = 4 балансно-троичных трита | M = 11 бит ]' },
    value: 'v = (−1)^s · (1 + M/2⁹) · 2^e,  e = Σ tᵢ·3ⁱ ∈ [−40, +40]',
    rule: { en: 'Width rule: 1 + E_t + M = N', ru: 'Правило ширины: 1 + E_t + M = N' },
    props: [
      {
        h: { en: 'No regime decode', ru: 'Нет regime-декода' },
        b: {
          en: 'The dominant cost of a tapered format is the variable regime: find it, compute its length, barrel-shift the significand. With fixed fields this is a bit slice.',
          ru: 'Доминирующая цена tapered-формата — переменный regime: найти его, посчитать длину, barrel-shift значащей. У фиксированных полей это битовый срез.',
        },
        tag: 'spec' as Tag,
      },
      {
        h: { en: 'The exponent is already ternary', ru: 'Экспонента уже троичная' },
        b: {
          en: '4 trits = 3⁴ = 81 exponent steps. On a ternary fabric exponent addition is native. On the binary FPGA where every number here was measured, it neither wins nor loses — and is labelled as architectural.',
          ru: '4 трита = 3⁴ = 81 шаг экспоненты. На троичной фабрике сложение экспонент нативно. На бинарной FPGA, где измерены все числа здесь, оно ни выигрывает, ни проигрывает — и помечено как архитектурное.',
        },
        tag: 'spec' as Tag,
      },
      {
        h: { en: 'Precision does not narrow', ru: 'Точность не сужается' },
        b: {
          en: '9 mantissa bits at every magnitude. Flatness 1.05–1.07 — at most 7% spread across a workload spanning 76 binades. For posit16 the same diagnostic reads −0.254 bits per binade, for takum16 −0.113.',
          ru: '9 бит мантиссы на каждой величине. Flatness 1.05–1.07 — разброс не более 7% на нагрузке в 76 бинад. Та же диагностика даёт для posit16 −0.254 бита на бинаду, для takum16 −0.113.',
        },
        tag: 'measured' as Tag,
      },
    ],
  },
  gft: {
    name: 'GFTernary',
    layout: { en: 'Two-bit alphabet { −φ, 0, +φ }', ru: 'Двухбитный алфавит { −φ, 0, +φ }' },
    value: 'Z[φ] = { a + bφ } is a ring;  φ·(a + bφ) = b + (a+b)φ',
    rule: { en: 'Weight application = one integer addition, no shift', ru: 'Применение веса = одно целочисленное сложение, без сдвига' },
    props: [
      {
        h: { en: 'Uniqueness of the golden alphabet', ru: 'Уникальность золотого алфавита' },
        b: {
          en: 'Require that the product of two weights be expressible in the additive lattice the datapath already computes — that is r² = r + 1 — and r = φ follows uniquely (Theorem 25).',
          ru: 'Потребуем, чтобы произведение двух весов выражалось в аддитивной решётке, которую датапуть уже считает, то есть r² = r + 1 — и r = φ следует единственно (Теорема 25).',
        },
        tag: 'proved' as Tag,
      },
      {
        h: { en: 'Depth costs no multiplier', ru: 'Глубина не стоит умножителя' },
        b: {
          en: 'The gain of k stacked φ-layers is φᵏ = F_k·φ + F_{k−1} — a pair of integers, exact. With {−1, 0, +1} the layer gain is 1 and carries no information, so every published method attaches a learned real α per layer — and multiplying by α puts the multiplier back.',
          ru: 'Усиление k сложенных φ-слоёв = φᵏ = F_k·φ + F_{k−1} — пара целых, точно. У алфавита {−1, 0, +1} усиление слоя равно 1 и не несёт информации, поэтому каждый опубликованный метод навешивает обучаемый вещественный α на слой — а умножение на α возвращает умножитель.',
        },
        tag: 'proved' as Tag,
      },
      {
        h: { en: 'Between the shift and φ there is nothing', ru: 'Между сдвигом и φ ничего нет' },
        b: {
          en: 'A scale is multiply-free iff it is an algebraic integer whose companion matrix has entries in {0, ±1} (Theorem 27). Degree 1 gives ±2^k. Degree 2 gives exactly r² = r + 1 and r² = −r + 1, the same ladder. φ is the only multiply-free refinement of the powers of two at two registers.',
          ru: 'Масштаб применим без умножителя ⟺ он алгебраическое целое, у которого companion-матрица имеет элементы в {0, ±1} (Теорема 27). Степень 1 даёт ±2^k. Степень 2 даёт ровно r² = r + 1 и r² = −r + 1 — та же лестница. φ — единственное multiply-free уточнение степеней двойки при двух регистрах.',
        },
        tag: 'proved' as Tag,
      },
    ],
  },
}

/* ─────────────────────── MEASURED FRONTIER ─────────────────────── */

export const frontier = {
  badge: { en: 'MEASURED ON SILICON', ru: 'ИЗМЕРЕНО НА КРЕМНИИ' },
  title: { en: 'Isolated decoder, and one whole ternary neuron', ru: 'Изолированный декодер и один целый тернарный нейрон' },
  sub: {
    en: 'XC7A200T (ALINX AX7203) on the open flow: Yosys 0.65 + nextpnr-xilinx 1743d0f + Icarus Verilog 13.0, median of 5 seeds, DSP inference disabled. One device family. Not a multi-corner characterisation; an ASIC mapping will differ.',
    ru: 'XC7A200T (ALINX AX7203) на открытом потоке: Yosys 0.65 + nextpnr-xilinx 1743d0f + Icarus Verilog 13.0, медиана 5 seed’ов, DSP-инференс выключен. Одна family устройств. Это не многоугловая характеризация; ASIC-маппинг будет отличаться.',
  },
  decoderCaption: {
    en: 'Isolated decoder — area and frequency (bare wire: 112 LUT @ 827.81 MHz)',
    ru: 'Изолированный декодер — площадь и частота (голый провод: 112 LUT @ 827.81 МГц)',
  },
  decoder: [
    { rank: 1, name: 'GFTernary', kind: { en: 'fixed', ru: 'фикс.' }, lut: 66, fmax: 974.66, ours: true },
    { rank: 2, name: 'int8', kind: { en: 'fixed', ru: 'фикс.' }, lut: 76, fmax: 925.93, ours: false },
    { rank: 3, name: 'binary32', kind: { en: 'fixed', ru: 'фикс.' }, lut: 112, fmax: 886.52, ours: false },
    { rank: 4, name: 'TNF16', kind: { en: 'fixed', ru: 'фикс.' }, lut: 101, fmax: 407.66, ours: true },
    { rank: 6, name: 'BNF16', kind: { en: 'fixed', ru: 'фикс.' }, lut: 97, fmax: 388.35, ours: true },
    { rank: 13, name: 'binary16', kind: { en: 'fixed', ru: 'фикс.' }, lut: 164, fmax: 235.18, ours: false },
    { rank: 15, name: 'LNS16', kind: { en: 'log', ru: 'лог.' }, lut: 270, fmax: 93.17, ours: false },
    { rank: 17, name: 'posit16', kind: { en: 'tapered', ru: 'tapered' }, lut: 302, fmax: 62.39, ours: false },
    { rank: 18, name: 'posit32', kind: { en: 'tapered', ru: 'tapered' }, lut: 517, fmax: 49.05, ours: false },
  ],
  decoderNote: {
    en: 'GFTernary lands at 66 LUT where the bare wire is 112: decoding a two-bit alphabet lets the synthesiser simplify the register downstream. Against posit32 that is 7.8× in area and 19.9× in frequency.',
    ru: 'GFTernary даёт 66 LUT там, где голый провод — 112: декод двухбитного алфавита позволяет синтезатору упростить регистр ниже по потоку. Против posit32 это 7.8× по площади и 19.9× по частоте.',
  },
  neuronCaption: {
    en: 'One ternary neuron, whole accumulator observable — throughput per area, MHz per LUT',
    ru: 'Один тернарный нейрон, весь аккумулятор наблюдаем — пропускная способность на площадь, МГц на LUT',
  },
  neuron: [
    { rank: 1, name: 'GFTernary', lut: 463, tpa: 0.1797, ours: true },
    { rank: 2, name: 'binary32', lut: 472, tpa: 0.1631, ours: false },
    { rank: 3, name: 'fp8 e5m2', lut: 480, tpa: 0.1397, ours: false },
    { rank: 4, name: 'VAX F', lut: 527, tpa: 0.1395, ours: false },
    { rank: 5, name: 'fp8 e4m3', lut: 485, tpa: 0.1382, ours: false },
    { rank: 6, name: 'GF10', lut: 533, tpa: 0.1354, ours: true },
    { rank: 7, name: 'binary16', lut: 522, tpa: 0.1213, ours: false },
    { rank: 10, name: 'TNF32', lut: 569, tpa: 0.1176, ours: true },
    { rank: 12, name: 'TNF16', lut: 565, tpa: 0.1173, ours: true },
    { rank: 17, name: 'takum16', lut: 789, tpa: 0.0747, ours: false },
    { rank: 20, name: 'posit32', lut: 953, tpa: 0.0295, ours: false },
  ],
  neuronNote: {
    en: '8 of the 20 slots are ours (GFTernary, TNF, BNF, GF families). The advantage over the next format is +10.2%; over the last, 6.1×. The claim that survives on buyable silicon is about fixed fields: no regime codec, no exponent to compute.',
    ru: '8 из 20 позиций — наши (GFTernary, TNF, BNF, семейства GF). Преимущество над следующим форматом +10.2%, над последним — 6.1×. На покупаемом кремнии выживает заявление про фиксированные поля: нет regime-кодека, нет экспоненты для вычисления.',
  },
  ops: {
    title: { en: 'What an operation costs', ru: 'Сколько стоит операция' },
    rows: [
      {
        family: 'LNS / takum',
        mul: { en: 'free — exponents add', ru: 'бесплатно — экспоненты складываются' },
        add: { en: 'log(1+2^x) table — 10 967 LUT', ru: 'таблица log(1+2^x) — 10 967 LUT' },
      },
      {
        family: 'Z[φ]',
        mul: { en: 'Fibonacci step — one adder', ru: 'шаг Фибоначчи — один сумматор' },
        add: { en: 'component-wise — 64 LUT', ru: 'покомпонентно — 64 LUT' },
      },
    ],
    tag: 'measured' as Tag,
  },
}

/* ───────────────────────── THE LADDER ───────────────────────── */

export const ladder = {
  badge: { en: 'WHICH RUNG THE BUDGET BUYS', ru: 'КАКУЮ СТУПЕНЬ ПОКУПАЕТ БЮДЖЕТ' },
  title: { en: 'The optimum has a closed form in the weight histogram', ru: 'Оптимум имеет замкнутую форму в гистограмме весов' },
  sub: {
    en: 'SmolLM2-135M on wikitext-2, 12 windows × 2048 tokens, fp32 = 14.36. The same ordering and the same winner at each budget reproduces on Qwen2.5-0.5B (fp32 = 12.27). Predictions were printed before the numbers were computed.',
    ru: 'SmolLM2-135M на wikitext-2, 12 окон × 2048 токенов, fp32 = 14.36. Тот же порядок и тот же победитель на каждом бюджете воспроизводится на Qwen2.5-0.5B (fp32 = 12.27). Предсказания печатались до вычисления чисел.',
  },
  header: { en: ['bits', 'shift (2)', 'φ (1.618)', 'supergolden (1.4656)', 'plastic (1.3247)'], ru: ['бит', 'сдвиг (2)', 'φ (1.618)', 'supergolden (1.4656)', 'plastic (1.3247)'] },
  rows: [
    { bits: 3, vals: ['2309.86', '41835.53', '1367268.11', '6720092.29'], win: 0 },
    { bits: 4, vals: ['76.81', '24.43', '25.10', '55.72'], win: 1 },
    { bits: 5, vals: ['77.52', '22.73', '18.93', '16.45'], win: 3 },
  ],
  hw: {
    title: { en: 'What each rung costs in hardware, at one adder', ru: 'Сколько стоит ступень в железе, при одном сумматоре' },
    rows: [
      { rung: 'φ, 4 bits', lut: '—', fmax: '—', ppl: '24.43', vs: { en: 'best 4-bit scale', ru: 'лучший 4-битный масштаб' } },
      { rung: 'r⁵ = r³ + 1, 5 bits', lut: '95 LUT', fmax: '482.39 MHz', ppl: '15.9242', vs: { en: '+10.9% of fp32', ru: '+10.9% к fp32' } },
      { rung: 'r⁶ = r + 1, 6 bits', lut: '122 LUT', fmax: '612.00 MHz', ppl: '14.8882', vs: { en: '+3.7% of fp32', ru: '+3.7% к fp32' } },
    ],
    tag: 'measured' as Tag,
  },
  block: {
    title: { en: 'The block axis, including where we do not win', ru: 'Блочная ось — включая то, где мы не выигрываем' },
    closed: {
      en: 'The element is closed, and not by us: the best 8-level codebook beats the unrolled one by 0.9% in perplexity, with squared error nearly 15× better. That axis does not belong to the element format at all — it belongs to MXFP4. Stated as a competitor result, with the bound that makes a fourth attempt of ours unjustified.',
      ru: 'Элемент закрыт, и не нами: лучший 8-уровневый кодбук бьёт развёрнутый на 0.9% по perplexity, при squared error лучше почти в 15 раз. Эта ось не принадлежит формату элемента вообще — она принадлежит MXFP4. Заявлено как результат конкурента, с границей, делающей четвёртую нашу попытку неоправданной.',
    },
    openTitle: { en: 'The scale is not closed', ru: 'Масштаб не закрыт' },
    rows: [
      { scheme: 'φ^k, 4b/32', scaleBits: '0.1250', total: '4.1250', a: '21.3545', b: '14.8512', ours: true },
      { scheme: '2^k, 4b/32', scaleBits: '0.1250', total: '4.1250', a: '22.4998', b: '14.9447', ours: false },
      { scheme: 'MXFP4, E8M0 8b/32', scaleBits: '0.2500', total: '4.2500', a: '22.4998', b: '14.9447', ours: false },
    ],
    caveat: {
      en: 'This is not “our format beats MXFP4”. The element stays E2M1; only the radix of the scale changes. It wins on two models at 0.125 fewer bits per weight. Above 4.25 bits per weight the frontier belongs to scales that carry a mantissa (E4M3).',
      ru: 'Это не «наш формат бьёт MXFP4». Элемент остаётся E2M1; меняется только основание масштаба. Выигрыш на двух моделях при 0.125 бита на вес дешевле. Выше 4.25 бита на вес фронтир принадлежит масштабам, несущим мантиссу (E4M3).',
    },
  },
}

/* ───────────────────────── THEOREM MAP ───────────────────────── */

export const theorems = {
  badge: { en: '52 THEOREMS — THE LOAD-BEARING ONES', ru: '52 ТЕОРЕМЫ — НЕСУЩИЕ' },
  title: { en: 'The results the rest of the paper is built on', ru: 'Результаты, на которых стоит остальная работа' },
  items: [
    {
      id: 'T1',
      name: { en: 'Precision law', ru: 'Закон точности' },
      stmt: { en: 'E[|rel err|] = ½·E[1/s]·2^−(M+1), independent of the exponent. Constants: ½ln2 = 0.3466 for a uniform significand on [1,2), ½(2ln2)⁻¹ = 0.3607 under Benford.', ru: 'E[|отн. ошибка|] = ½·E[1/s]·2^−(M+1), независимо от экспоненты. Константы: ½ln2 = 0.3466 при равномерной значащей на [1,2), ½(2ln2)⁻¹ = 0.3607 по Бенфорду.' },
      why: { en: 'Predicted 0.3861, measured 0.3756 across eight rungs. This is what makes the accumulator sizeable before it is built.', ru: 'Предсказано 0.3861, измерено 0.3756 на восьми ступенях. Именно это позволяет отмерить аккумулятор до постройки.' },
      tag: 'measured' as Tag,
    },
    {
      id: 'T2',
      name: { en: 'The diagnostic', ru: 'Диагностика' },
      stmt: { en: 'Effective mantissa M_eff is constant across binades iff the format holds a constant significand width and has not exhausted its range. For a tapered format M_eff falls with |e|, and the slope is the narrowing rate.', ru: 'Эффективная мантисса M_eff постоянна по бинадам ⟺ формат держит постоянную ширину значащей и не исчерпал диапазон. Для tapered-формата M_eff падает с |e|, наклон = скорость сужения.' },
      why: { en: 'Recovers the declared M to 0.01 bit for every fixed-field format (TNF16 9 → 8.99/9.01, GF16 9 → 8.99, bfloat16 7 → 7.04) and separates tapered cleanly.', ru: 'Восстанавливает объявленную M до 0.01 бита для каждого фиксированно-полевого формата (TNF16 9 → 8.99/9.01, GF16 9 → 8.99, bfloat16 7 → 7.04) и чисто отделяет tapered.' },
      tag: 'measured' as Tag,
    },
    {
      id: 'T6',
      name: { en: 'Range–precision dichotomy', ru: 'Дихотомия диапазон–точность' },
      stmt: { en: 'If the exponent takes unboundedly many values, the significand length falls to zero — and by T1 so does M_eff. Constant precision and unbounded range are incompatible.', ru: 'Если экспонента принимает неограниченно много значений, длина значащей падает до нуля — и по Т1 вместе с ней M_eff. Постоянная точность и неограниченный диапазон несовместимы.' },
      why: { en: 'This is why there is a ladder at all, rather than one universal format.', ru: 'Именно поэтому существует лестница, а не один универсальный формат.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T7',
      name: { en: 'Radix economy', ru: 'Экономия основания' },
      stmt: { en: 'The cost b·log_b R is minimised at r = e; three is the nearest integer. Ternary sits 0.46% above the optimum, binary 6.15%.', ru: 'Цена b·log_b R минимальна при r = e; три — ближайшее целое. Троичное на 0.46% выше оптимума, бинарное — на 6.15%.' },
      why: { en: 'The 68-year-old argument, stated exactly, so that its limits can be stated too.', ru: '68-летний аргумент, сформулированный точно — чтобы можно было сформулировать и его границы.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T8',
      name: { en: 'No free range on a binary fabric', ru: 'На бинарной фабрике диапазон не бесплатен' },
      stmt: { en: 'A field of E_t trits covers 3^{E_t} values, and 3^{E_t} never divides a power of two — the remainder is lost. Ternary buys 0.3691·E positions and costs 1.683 per position when packed into a binary fabric.', ru: 'Поле из E_t тритов покрывает 3^{E_t} значений, а 3^{E_t} никогда не делит степень двойки — остаток теряется. Троичное покупает 0.3691·E позиций и стоит 1.683 за позицию при упаковке в бинарную фабрику.' },
      why: { en: 'This theorem is the reason our own ternary claim is architectural and not commercial. It is also why BNF16 and TNF16 synthesise within 1% of each other.', ru: 'Эта теорема — причина, по которой наше собственное троичное заявление архитектурное, а не коммерческое. И она же объясняет, почему BNF16 и TNF16 синтезируются в пределах 1% друг от друга.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T22',
      name: { en: 'The width rule generates the frontier', ru: 'Правило ширины порождает фронтир' },
      stmt: { en: 'The family F_N = {(E_t, M) : 1 + E_t + M = N} is exactly the Pareto frontier in (M_eff, range).', ru: 'Семейство F_N = {(E_t, M) : 1 + E_t + M = N} есть в точности Парето-фронтир в (M_eff, диапазон).' },
      why: { en: 'The ladder is not a design catalogue. It is the frontier, and there is nothing off it to choose.', ru: 'Лестница — не каталог дизайнов. Это фронтир, и вне него выбирать нечего.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T23',
      name: { en: 'Optimal member for a named range', ru: 'Оптимальный член для названного диапазона' },
      stmt: { en: 'E_t* = ⌈log₃(b+1)⌉ and M* = N − 1 − ⌈log₃(b+1)⌉, a unique maximum.', ru: 'E_t* = ⌈log₃(b+1)⌉ и M* = N − 1 − ⌈log₃(b+1)⌉, единственный максимум.' },
      why: { en: 'No free parameter once the workload is named — and naming the workload is a measurement, not a choice.', ru: 'Свободного параметра нет, как только нагрузка названа — а именование нагрузки есть измерение, не выбор.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T24',
      name: { en: 'Regret of a misnamed range', ru: 'Штраф за неверно названный диапазон' },
      stmt: { en: 'The penalty is asymmetric: oversizing pays in precision logarithmically at every value, undersizing pays in range linearly but only on the tail. Under uncertainty, round up.', ru: 'Штраф асимметричен: пере-размер платит точностью логарифмически на каждом значении, недо-размер платит диапазоном линейно, но только на хвосте. При неопределённости округлять вверх.' },
      why: { en: 'This contradicts the intuition that a wider exponent is the conservative choice.', ru: 'Это противоречит интуиции, что более широкая экспонента — консервативный выбор.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T25',
      name: { en: 'Uniqueness of the golden alphabet', ru: 'Уникальность золотого алфавита' },
      stmt: { en: 'Requiring the product of two weights to lie in the additive lattice the datapath already computes gives r² = r + 1, hence r = φ, uniquely.', ru: 'Требование, чтобы произведение двух весов лежало в аддитивной решётке, которую датапуть уже считает, даёт r² = r + 1, откуда r = φ единственно.' },
      why: { en: 'The radix is forced by closure, not selected for elegance.', ru: 'Основание вынуждено замкнутостью, а не выбрано за элегантность.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T26',
      name: { en: 'Exactness of the multiply-free path', ru: 'Точность multiply-free пути' },
      stmt: { en: 'In Z[φ] the whole linear path of a network — any fan-in, any depth — is computed with no rounding error at all.', ru: 'В Z[φ] весь линейный путь сети — любой fan-in, любая глубина — вычисляется без ошибки округления вообще.' },
      why: { en: 'Machine-checked in Coq. This is the strongest single statement in the paper, and it is the one a reviewer can check without hardware.', ru: 'Машинно проверено в Coq. Это сильнейшее одиночное утверждение работы, и именно его рецензент может проверить без железа.' },
      tag: 'coq' as Tag,
    },
    {
      id: 'T27',
      name: { en: 'Enumeration of multiply-free scales', ru: 'Перечисление multiply-free масштабов' },
      stmt: { en: 'A scale is applicable without a multiplier iff it is an algebraic integer whose companion matrix has entries in {0, ±1}. Degree 1: ±2^k. Degree 2: exactly φ and φ⁻¹. Degree 3: plastic 1.3247, supergolden 1.4656, tribonacci 1.8393. Degree 4: the coefficient vector loses sparsity and the cost doubles.', ru: 'Масштаб применим без умножителя ⟺ он алгебраическое целое, у которого companion-матрица имеет элементы в {0, ±1}. Степень 1: ±2^k. Степень 2: ровно φ и φ⁻¹. Степень 3: plastic 1.3247, supergolden 1.4656, tribonacci 1.8393. Степень 4: коэффициентный вектор теряет разрежённость, цена удваивается.' },
      why: { en: 'Fineness costs registers, not adders: r^d = r + 1 reaches any granularity at one adder and d registers.', ru: 'Тонкость стоит регистров, не сумматоров: r^d = r + 1 достигает любой гранулярности при одном сумматоре и d регистрах.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T36',
      name: { en: 'Composition depth is free only for φ^k', ru: 'Глубина композиции бесплатна только для φ^k' },
      stmt: { en: 'φ^k is the only applier whose area does not depend on composition depth: at d = 2, APoT-8 costs 1217 LUT where the pair still costs 173.', ru: 'φ^k — единственный applier, чья площадь не зависит от глубины композиции: при d = 2 APoT-8 стоит 1217 LUT там, где пара всё ещё 173.' },
      why: { en: 'The earlier and larger claim about φ^k area over APoT was retracted — it came from a 5-bit shift field where the workload needed 2. This is what survived.', ru: 'Более раннее и более крупное заявление о площади φ^k против APoT отозвано — оно вышло из 5-битного поля сдвига там, где нагрузке нужно 2. Это — то, что выжило.' },
      tag: 'measured' as Tag,
    },
    {
      id: 'T49',
      name: { en: 'The radix argument holds on positions, not on bits', ru: 'Аргумент основания держится на позициях, а не на битах' },
      stmt: { en: 'Packing loss: 4 bits 6/8 = −25.0%; 6 bits 27/32 = −15.6%; 8 bits 108/128 = −15.6%; 16 bits 31 104/32 768 = −5.1%.', ru: 'Потери на упаковке: 4 бита 6/8 = −25.0%; 6 бит 27/32 = −15.6%; 8 бит 108/128 = −15.6%; 16 бит 31 104/32 768 = −5.1%.' },
      why: { en: 'The remainder is arithmetic, not engineering, and it is largest exactly where modern formats live.', ru: 'Остаток — арифметика, а не инженерия, и он максимален именно там, где живут современные форматы.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T3/T4',
      name: { en: 'The exact taper of posit and takum', ru: 'Точный taper posit и takum' },
      stmt: { en: 'The significand of a posit narrows by exactly 2^−es per binade; takum fixes a 3-bit regime field. Applied to 51 formats with a published oracle, the 83-format catalogue resolves into four ladder shapes and no fifth.', ru: 'Значащая posit сужается ровно на 2^−es за бинаду; takum фиксирует 3-битное regime-поле. Применённое к 51 формату с опубликованным оракулом, это разрешает каталог 83 форматов в четыре формы лестницы и никакой пятой.' },
      why: { en: 'A taxonomy that predicts rather than describes: given the ladder shape, the decode cost and the precision profile follow.', ru: 'Таксономия, которая предсказывает, а не описывает: по форме лестницы следуют и цена декода, и профиль точности.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T5',
      name: { en: 'Precision wobble', ru: 'Дрожание точности' },
      stmt: { en: 'A format that scales by r^e with a uniformly quantised significand has wobble — precision oscillates within each scale step unless r = 2.', ru: 'Формат, шкалирующий r^e при равномерно квантованной значащей, имеет wobble — точность колеблется внутри шага масштаба, если r ≠ 2.' },
      why: { en: 'This reproduces a result sixty years older (IBM System/360 hex) and is the second independent argument for a binary scale inside TNF.', ru: 'Это воспроизводит результат на шестьдесят лет старше (IBM System/360, hex) и служит вторым независимым аргументом за бинарную шкалу внутри TNF.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T9',
      name: { en: 'Unallocated positions are a pure loss', ru: 'Нераспределённые позиции — чистая потеря' },
      stmt: { en: 'Every position the encoding does not allocate still costs 2^k of the code space; there is no neutral spare capacity in a fixed-width format.', ru: 'Каждая позиция, которую кодировка не распределила, всё равно стоит 2^k кодового пространства; нейтрального запаса в формате фиксированной ширины не существует.' },
      why: { en: 'This is why the width rule is an equality, 1 + E_t + M = N, and not an inequality.', ru: 'Именно поэтому правило ширины — равенство 1 + E_t + M = N, а не неравенство.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T10',
      name: { en: 'Why the scale radix is 2 and not 3', ru: 'Почему основание шкалы 2, а не 3' },
      stmt: { en: 'On the scale of a floating-point value, a binary radix beats a ternary one by 0.331 position per number.', ru: 'На шкале значения с плавающей точкой бинарное основание опережает троичное на 0.331 позиции на число.' },
      why: { en: 'Our own ternary claim is therefore confined to the exponent field, not to the scale. A result against us, stated in our own numbers.', ru: 'Поэтому наше собственное троичное заявление ограничено полем экспоненты, а не шкалой. Результат против нас, изложенный нашими же числами.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T13/T14',
      name: { en: 'The regime radius does not matter; the scan does', ru: 'Радиус regime не имеет значения — имеет скан' },
      stmt: { en: 'A ladder is a function of codeword lengths, and a logarithmic ladder is the floor: ℓ(e) ≥ log₂|e|. The regime radius is irrelevant to cost; the decode cost is set by the scan, not by the ladder. Unbounded range costs 40.', ru: 'Лестница есть функция длин кодовых слов, а логарифмическая лестница — пол: ℓ(e) ≥ log₂|e|. Радиус regime на цену не влияет; цену декода задаёт скан, а не лестница. Неограниченный диапазон стоит 40.' },
      why: { en: 'T13 retracts an earlier construction of our own. What remains is the stronger statement: the scan is the price, and a fixed field has no scan.', ru: 'Т13 отзывает нашу же более раннюю конструкцию. Остаётся более сильное утверждение: цена — это скан, а у фиксированного поля скана нет.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T15/T17/T18',
      name: { en: 'Area and precision are commensurable', ru: 'Площадь и точность соизмеримы' },
      stmt: { en: 'With λ = dA/dM the area of a regime codec converts into mantissa bits of silicon; A(M) = cM^α, and the precision value of a regime falls as 1/M.', ru: 'При λ = dA/dM площадь regime-кодека переводится в биты мантиссы кремния; A(M) = cM^α, а ценность regime в точности падает как 1/M.' },
      why: { en: 'It makes "is the regime worth it?" a computation instead of an opinion — and the answer turns negative as the format widens.', ru: 'Это превращает вопрос «стоит ли regime своих денег?» в вычисление вместо мнения — и ответ становится отрицательным по мере роста ширины формата.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T19/T20',
      name: { en: 'The value law costs more than the field layout', ru: 'Закон значения дороже раскладки полей' },
      stmt: { en: 'A logarithmic decode is priced by the TARGET precision, not by the width of the source field — verified against takum32 at d = 2.', ru: 'Логарифмический декод оценивается по ЦЕЛЕВОЙ точности, а не по ширине исходного поля — проверено против takum32 при d = 2.' },
      why: { en: 'Two formats with identical field widths can differ by an order of magnitude in decoder area if one of them is logarithmic.', ru: 'Два формата с идентичными ширинами полей могут отличаться на порядок по площади декодера, если один из них логарифмический.' },
      tag: 'measured' as Tag,
    },
    {
      id: 'T21',
      name: { en: 'The binary scale is the unique implementable optimum', ru: 'Бинарная шкала — единственный реализуемый оптимум' },
      stmt: { en: 'Scaling is a shift if and only if the radix is 2. Corollary 21: between the shift and φ there is nothing.', ru: 'Шкалирование есть сдвиг ⟺ основание равно 2. Следствие 21: между сдвигом и φ ничего нет.' },
      why: { en: 'Together with T25 this closes the radix question from both sides: 2 for the scale, φ for the alphabet, and no third option in between.', ru: 'Вместе с Т25 это закрывает вопрос основания с двух сторон: 2 для шкалы, φ для алфавита, и никакого третьего варианта между ними.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'Cor.18/26',
      name: { en: 'Where the trit wins and where it draws', ru: 'Где трит выигрывает и где играет вничью' },
      stmt: { en: 'A ternary field buys ∆ = E(1 − log₃2) = 0.3691·E positions and costs κ(3)/κ(2) = 1.683 per position when packed into a binary fabric; the two cancel at ∆ = 0.331·E_t.', ru: 'Троичное поле покупает ∆ = E(1 − log₃2) = 0.3691·E позиций и стоит κ(3)/κ(2) = 1.683 за позицию при упаковке в бинарную фабрику; они сокращаются при ∆ = 0.331·E_t.' },
      why: { en: 'On positions the trit wins unconditionally; on binary bits it draws. This is why BNF16 and TNF16 synthesise within 1% of each other.', ru: 'На позициях трит выигрывает безусловно, на бинарных битах — играет вничью. Поэтому BNF16 и TNF16 синтезируются в пределах 1% друг от друга.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T39–T42',
      name: { en: 'Taper is paid in delay, not in area', ru: 'Taper платится задержкой, а не площадью' },
      stmt: { en: 'All 14 fixed-field decoders clear all 3 tapered ones in frequency, and the worst fixed leads the best tapered by 1.43×; in area they overlap (posit8 214 LUT against IBM hex 243). A barrel shifter is sized by range, not by width: 210 layers → 3.15 octaves → 2 bits suffice.', ru: 'Все 14 фиксированно-полевых декодеров выше всех 3 tapered по частоте, и худший фиксированный ведёт лучший tapered в 1.43×; по площади они перекрываются (posit8 214 LUT против IBM hex 243). Barrel-сдвигатель оценивается по диапазону, а не по ширине: 210 слоёв → 3.15 октавы → достаточно 2 бита.' },
      why: { en: 'The regime inversion is here too: the ordering of areas flips depending on whether the scale is a compile-time constant or a runtime variable.', ru: 'Здесь же и regime-инверсия: порядок площадей переворачивается в зависимости от того, константа ли масштаб на компиляции или переменная в рантайме.' },
      tag: 'measured' as Tag,
    },
    {
      id: 'T48',
      name: { en: 'Transforms and formats do not compose', ru: 'Преобразования и форматы не композируются' },
      stmt: { en: 'A data transform (block scaling, rotation, a learned codebook) and a number format cannot be evaluated independently and then combined — the pair has to be measured as a pair.', ru: 'Преобразование данных (блочное масштабирование, поворот, обученный codebook) и числовой формат нельзя оценить независимо и потом сложить — пару надо мерить как пару.' },
      why: { en: 'This is the theorem that catches most published format comparisons, including three of our own retracted ones.', ru: 'Именно эта теорема ловит большинство публикуемых сравнений форматов, включая три наших собственных отозванных.' },
      tag: 'proved' as Tag,
    },
    {
      id: 'T50–T52',
      name: { en: 'The document is an artefact', ru: 'Документ — это артефакт' },
      stmt: { en: 'The ladder shape decides whether a window is needed at all; wobble admits no crossover; and the taxonomy is prescriptive rather than descriptive — pairs of (transform, format) must be guarded, not just listed.', ru: 'Форма лестницы решает, нужно ли окно вообще; wobble не допускает кроссовера; таксономия предписательна, а не описательна — пары (преобразование, формат) надо охранять, а не просто перечислять.' },
      why: { en: 'A format specification that does not say which pairings are forbidden is incomplete, and every retraction in this work came from a missing guard.', ru: 'Спецификация формата, не говорящая, какие пары запрещены, неполна — и каждая ретракция в этой работе выросла из отсутствующего охранника.' },
      tag: 'proved' as Tag,
    },
  ],
}

/* ───────────────────── LIMITS AND RETRACTIONS ───────────────────── */

export const limits = {
  badge: { en: 'LIMITS AND RETRACTIONS', ru: 'ГРАНИЦЫ И РЕТРАКЦИИ' },
  title: { en: 'Sixteen claims were withdrawn while the work was being done', ru: 'Шестнадцать заявлений отозвано в ходе работы' },
  sub: {
    en: 'Two of those withdrawals were themselves later withdrawn. In almost every case the measurement was right and the comparison around it was wrong. The rule that would have caught all three of the largest: write down what a competitor would build if they were trying to win, and measure that.',
    ru: 'Два из этих отзывов позже были отозваны сами. Почти в каждом случае измерение было верным, а сравнение вокруг него — нет. Правило, которое поймало бы все три крупнейших: записать, что построил бы конкурент, если бы пытался выиграть, и мерить это.',
  },
  items: [
    {
      h: { en: 'The fabric on which this format is optimal is not for sale', ru: 'Фабрика, на которой этот формат оптимален, не продаётся' },
      b: { en: 'T8 locks the benefit of ternary encoding to a ternary fabric, and no commercially available process provides one. Every hardware number here was measured on a binary FPGA, where the ternary exponent neither wins nor loses. The ternary claim is architectural and is labelled as such.', ru: 'Т8 запирает выгоду троичного кодирования на троичной фабрике, а коммерчески доступного процесса нет. Каждое аппаратное число здесь измерено на бинарной FPGA, где троичная экспонента ни выигрывает, ни проигрывает. Троичное заявление архитектурное и так и помечено.' },
    },
    {
      h: { en: 'Ternary lost to binary three times, independently', ru: 'Троичное проиграло бинарному три раза, независимо' },
      b: { en: 'BNF16 against TNF16 within 1% in placed silicon; GF8 against GF-T8; MXFP4 against TNF4 on the block axis. We add no support to “ternary beats binary” as a general statement. We measured it three times and each time it went against us. The contribution is the condition under which the 68-year-old argument applies.', ru: 'BNF16 против TNF16 в пределах 1% в размещённом кремнии; GF8 против GF-T8; MXFP4 против TNF4 на блочной оси. Мы не добавляем поддержки утверждению «троичное бьёт бинарное» как общему. Мы измерили его трижды, и каждый раз он был против нас. Вклад — условие, при котором применим 68-летний аргумент.' },
    },
    {
      h: { en: 'TNF is not the most accurate format at its width', ru: 'TNF — не самый точный формат на своей ширине' },
      b: { en: 'posit16 and binary16 are ahead near unity; binary formats are ahead outright at 32 bits. A reference is not required to win those comparisons. It is required to be the thing they are measured against.', ru: 'posit16 и binary16 впереди около единицы; бинарные форматы впереди прямо на 32 битах. Референс не обязан выигрывать эти сравнения. Он обязан быть тем, относительно чего их измеряют.' },
    },
    {
      h: { en: 'The comparison is against takum16, not tekum16', ru: 'Сравнение идёт против takum16, а не tekum16' },
      b: { en: 'The oracle labelled tekum decodes all 65 536 sixteen-bit codes identically to the takum oracle. The real comparison against tekum has not been made. The earlier figure for tekum16 moved from 4.2–6.5 to 2.1, and takum32 moved from 5.9–10.2 to an exact 2.6.', ru: 'Оракул, помеченный tekum, декодирует все 65 536 шестнадцатибитных кодов идентично takum-оракулу. Настоящее сравнение с tekum ещё не сделано. Более раннее число для tekum16 переехало с 4.2–6.5 на 2.1, а takum32 — с 5.9–10.2 на точные 2.6.' },
      tag: 'retracted' as Tag,
    },
    {
      h: { en: 'Five of nine rungs are measured in hardware', ru: 'Пять из девяти ступеней измерены в железе' },
      b: { en: 'TNF4 through TNF64 (TNF64: 7479 LUT @ 48.20 MHz). TNF128 (M = 119) does not close routing on this part and is not claimed; TNF256 and above exceed a single Artix-7 fabric entirely. The specification table and the placed-and-routed table are kept apart on purpose.', ru: 'TNF4…TNF64 (TNF64: 7479 LUT @ 48.20 МГц). TNF128 (M = 119) не сходится в разводке на этой части и не заявляется; TNF256 и выше превышают одну фабрику Artix-7 целиком. Таблица спецификации и таблица размещённого-разведённого держатся отдельно намеренно.' },
    },
    {
      h: { en: 'No head-to-head in hardware against takum', ru: 'Нет head-to-head в железе против takum' },
      b: { en: 'Its codec RTL is public (VHDL, arXiv:2408.10594) but we did not synthesise it alongside, so the cost figures are TNF’s own. What is visible in the source as structure rather than measurement: the 16-bit codec instantiates a generated 725-line leading-zero counter and a barrel shifter — the regime decode a fixed-field format does not have.', ru: 'Его codec RTL публичен (VHDL, arXiv:2408.10594), но мы не синтезировали его рядом, поэтому цифры цены — собственные у TNF. Что видно в исходнике как структура, а не измерение: 16-битный кодек инстанцирует сгенерированный 725-строчный leading-zero-counter и barrel shifter — regime-декод, которого у фиксированно-полевого формата нет.' },
    },
    {
      h: { en: 'A tool limit, stated rather than smoothed', ru: 'Ограничение инструмента, заявленное, а не сглаженное' },
      b: { en: 'The APoT sweep is non-monotone — 130, 380, 230, 384 LUT at shift widths 2 to 5 — with a demonstrably applied parameter and a deterministic tool. LUT count from a single logic synthesis is therefore not a reliable area metric at this granularity. A claim resting on a 30% difference between two such points is unsafe; one resting on 10× is not.', ru: 'APoT-развёртка немонотонна — 130, 380, 230, 384 LUT при ширинах сдвига 2–5 — при демонстративно применённом параметре и детерминированном инструменте. Значит, LUT-счёт из одного логического синтеза не является надёжной метрикой площади на этой гранулярности. Заявление, опирающееся на 30% разницу между двумя такими точками, небезопасно; опирающееся на 10× — да.' },
    },
    {
      h: { en: 'An oracle defect, now fixed', ru: 'Дефект оракула, теперь исправленный' },
      b: { en: 'Round-tripping 1.5 returned −1.5 at 21 and 25 mantissa bits: the sign bit sat at a fixed position and the exponent mask took more bits than the field holds. TNF32 fell from 5.4e−1 to 5.3e−9. The lesson outlives the bug: the ladder check was add/mul commutativity, and an inverted sign survives both sides of a + b = b + a. The check was real and blind to the class. A round-trip assertion sees it, costs one line per probe, and now runs on all nine rungs.', ru: 'Round-trip 1.5 возвращал −1.5 на 21 и 25 битах мантиссы: знаковый бит стоял на фиксированной позиции, а маска экспоненты брала больше бит, чем держит поле. TNF32 упал с 5.4e−1 до 5.3e−9. Урок переживает баг: проверкой лестницы была коммутативность add/mul, а инвертированный знак выживает на обеих сторонах a + b = b + a. Проверка была настоящей и слепой к классу. Round-trip-ассерт его видит, стоит одну строку на пробу и теперь идёт на всех девяти ступенях.' },
    },
    {
      h: { en: 'Not a 7% win over int8', ru: 'Не 7% выигрыш над int8' },
      b: { en: 'int8 carries no range and is not doing the same work. Range is stated separately: ±40 in powers of two, roughly ±12 decades, where a regime field is unbounded.', ru: 'int8 не несёт диапазона и делает не ту же работу. Диапазон заявляется отдельно: ±40 в степенях двойки, примерно ±12 декад, там где regime-поле неограниченно.' },
    },
    {
      h: { en: 'Precision above TNF32 is limited by the instrument', ru: 'Точность выше TNF32 ограничена измерительным инструментом' },
      b: { en: 'TNF64 carries 52 mantissa bits — exactly the significand of the IEEE double in which the metric is computed. An AI assistant was used in preparing the software, the measurement harness and the manuscript; every number was obtained by running the named tools on hardware the author owns, no measurement is estimated, and where a figure is derived rather than observed it is labelled.', ru: 'TNF64 несёт 52 бита мантиссы — ровно значащую IEEE double, в которой считается метрика. AI-ассистент использовался при подготовке ПО, измерительного харнесса и рукописи; каждое число получено запуском названных инструментов на железе в собственности автора, ни одно измерение не оценено, а где цифра выведена, а не наблюдена, она помечена.' },
    },
  ],
}

/* ───────────────────────── LANDSCAPE ───────────────────────── */

export const landscape = {
  badge: { en: 'LANDSCAPE', ru: 'ЛАНДШАФТ' },
  title: { en: 'Who else is on this ground, and where the line falls', ru: 'Кто ещё на этой земле и где проходит граница' },
  sub: {
    en: 'Each entry states what the other work does, and what specifically distinguishes it — not who is better. Where a negative statement is made it is scoped to the verified search window, not to the literature.',
    ru: 'Каждая запись говорит, что делает чужая работа и что именно её отличает — а не кто лучше. Где сделано отрицательное утверждение, оно ограничено проверенным окном поиска, а не литературой в целом.',
  },
  items: [
    {
      name: 'Tekum',
      who: 'L. Hunhold, 2025',
      url: 'https://arxiv.org/abs/2512.10964',
      kind: 'threat' as const,
      line: {
        en: 'Balanced-ternary tapered-precision arithmetic — the same niche, and the closest work that exists. The line: tekum tapers, so its significand width varies with magnitude; TNF fixes its fields, so it does not. No tekum RTL was found in the verified search window, and our own tekum oracle turned out to decode identically to takum, so the head-to-head is open work, not a settled comparison.',
        ru: 'Балансно-троичная tapered-арифметика — та же ниша и ближайшая существующая работа. Граница: tekum сужается, поэтому ширина его значащей меняется с величиной; TNF фиксирует поля, поэтому не меняется. RTL для tekum в проверенном окне поиска не найден, а наш собственный tekum-оракул оказался декодирующим идентично takum — значит, head-to-head это открытая работа, а не решённое сравнение.',
      },
    },
    {
      name: 'Takum',
      who: 'L. Hunhold, 2024',
      url: 'https://arxiv.org/abs/2404.18603',
      kind: 'threat' as const,
      line: {
        en: 'Tapered precision with a fixed 3-bit regime field, and a public codec RTL in VHDL (arXiv:2408.10594). The diagnostic of T2 reads its narrowing directly: −0.113 bits per binade. Cost figures here are TNF’s own; we did not synthesise the takum codec alongside.',
        ru: 'Tapered-точность с фиксированным 3-битным regime-полем и публичным codec RTL на VHDL (arXiv:2408.10594). Диагностика Т2 читает его сужение прямо: −0.113 бита на бинаду. Цифры цены здесь собственные у TNF; мы не синтезировали takum-кодек рядом.',
      },
    },
    {
      name: 'Posit',
      who: 'Gustafson & Yonemoto, 2017',
      url: 'https://posithub.org/docs/Posits4.pdf',
      kind: 'context' as const,
      line: {
        en: 'The reference tapered family. Measured here, not argued about: posit16 at 302 LUT and 62.39 MHz isolated, posit32 at 953 LUT and 0.0295 MHz/LUT in the neuron. Its narrowing is −0.254 bits per binade. Taper is paid in latency rather than area: all fourteen fixed-field formats sit above all three tapered ones in frequency, while in area they overlap.',
        ru: 'Референсное tapered-семейство. Здесь оно измерено, а не обсуждается: posit16 — 302 LUT и 62.39 МГц изолированно, posit32 — 953 LUT и 0.0295 МГц/LUT в нейроне. Сужение — −0.254 бита на бинаду. Taper платится задержкой, а не площадью: все четырнадцать фиксированно-полевых форматов выше всех трёх tapered по частоте, тогда как по площади они перекрываются.',
      },
    },
    {
      name: 'MXFP4 / NVFP4',
      who: 'Egiazarian et al.; NVIDIA, 2025',
      url: 'https://arxiv.org/abs/2509.23202',
      kind: 'confirms' as const,
      line: {
        en: 'Owns the block-element axis, and we say so: the best 8-level codebook beats the unrolled one by 0.9% with squared error nearly 15× better, which is the bound that makes a fourth attempt of ours unjustified. The scale radix is a separate question, and there a φ-grid wins on two models at 0.125 fewer bits per weight — with the element unchanged at E2M1.',
        ru: 'Владеет осью блочного элемента, и мы это говорим: лучший 8-уровневый кодбук бьёт развёрнутый на 0.9% при squared error лучше почти в 15 раз, и это граница, делающая четвёртую нашу попытку неоправданной. Основание масштаба — отдельный вопрос, и там φ-сетка выигрывает на двух моделях при 0.125 бита на вес дешевле — при элементе, неизменно остающемся E2M1.',
      },
    },
    {
      name: 'FQP — Fibonacci Quantization Processor',
      who: 'DAC 2024',
      url: 'https://doi.org/10.1145/3649329.3656502',
      kind: 'threat' as const,
      line: {
        en: 'Nearest hardware neighbour in the Fibonacci direction, and the clearest illustration of Corollary 20: it carries two arithmetic blocks plus topological-order routing, because F₄·F₄ = 9 is not a Fibonacci number, so the product leaves the representable set. Closure under Z[φ] is what removes that machinery.',
        ru: 'Ближайший аппаратный сосед в фибоначчиевом направлении и самая ясная иллюстрация Следствия 20: он несёт два арифметических блока плюс routing в топологическом порядке, потому что F₄·F₄ = 9 не число Фибоначчи, и произведение выходит из представимого множества. Замкнутость в Z[φ] — это то, что убирает такую машинерию.',
      },
    },
    {
      name: { en: 'Fibbinary for neuromorphic radio', ru: 'Fibbinary для нейроморфного радио' },
      who: '2025',
      url: 'https://arxiv.org/abs/2511.01921',
      kind: 'context' as const,
      line: {
        en: 'Saves 45% multiplier power and 44% multiplier area. The distinction is the verb: the multiplier is made cheaper, not removed. In Z[φ] the weight application is a Fibonacci step and there is no multiplier to make cheaper.',
        ru: 'Экономит 45% мощности и 44% площади умножителя. Отличие — в глаголе: умножитель удешевлён, а не убран. В Z[φ] применение веса есть шаг Фибоначчи, и удешевлять нечего.',
      },
    },
    {
      name: { en: 'BitNet b1.58 and the {−1, 0, +1} hardware line', ru: 'BitNet b1.58 и аппаратная линия {−1, 0, +1}' },
      who: '2024–2026',
      url: 'https://arxiv.org/abs/2402.17764',
      kind: 'confirms' as const,
      line: {
        en: 'Confirms the demand side: ternary weights are worth building hardware for. It also shows the gap this work addresses — the layer gain of a {−1, 0, +1} alphabet is 1 and carries no information, so a learned real scale per layer is attached, and that scale is a multiplication.',
        ru: 'Подтверждает сторону спроса: под тернарные веса стоит строить железо. И показывает разрыв, который закрывает эта работа: усиление слоя у алфавита {−1, 0, +1} равно 1 и не несёт информации, поэтому на слой навешивается обучаемый вещественный масштаб — а этот масштаб есть умножение.',
      },
    },
    {
      name: { en: 'GoldenFloat · the 83-format catalog', ru: 'GoldenFloat · каталог из 83 форматов' },
      who: 'D. Vasilev, 2026',
      url: 'https://arxiv.org/abs/2606.05017',
      kind: 'ours' as const,
      line: {
        en: 'Our own prior work, and the base this stands on: a φ-derived static-split float family (arXiv:2606.05017v3) and an 83-format catalog with bit-exact conformance vectors (arXiv:2606.09686v2). There φ chose field widths. Here it enters the weight alphabet, which is a different and stronger statement — closure rather than density.',
        ru: 'Наша собственная предыдущая работа и база, на которой стоит эта: φ-производное семейство float’ов со статическим разбиением (arXiv:2606.05017v3) и каталог 83 форматов с бит-точными conformance-векторами (arXiv:2606.09686v2). Там φ выбирало ширины полей. Здесь оно входит в весовой алфавит, а это другое и более сильное утверждение — про замкнутость, а не про плотность.',
      },
    },
  ],
  negatives: {
    title: { en: 'Searched for and not found — scoped to the verified window', ru: 'Искали и не нашли — в границах проверенного окна' },
    items: [
      { en: 'No work using plastic, supergolden or tribonacci constants as a scale base for quantisation, although T27 enumerates them as the degree-3 rung.', ru: 'Нет работ, использующих plastic, supergolden или tribonacci как основание масштаба для квантизации, хотя Т27 перечисляет их как ступень степени 3.' },
      { en: 'No adaptation of the Quire or Kulisch accumulator to a ternary or φ datapath.', ru: 'Нет адаптации аккумулятора Quire или Kulisch к троичному или φ-датапути.' },
      { en: 'No RTL for tekum, and no company found working specifically on ternary or φ inference formats; the nearest commercial multiplier-free efforts are logarithmic.', ru: 'Нет RTL для tekum и не найдено компании, работающей именно над троичными или φ-форматами инференса; ближайшие коммерческие multiply-free попытки — логарифмические.' },
    ],
    caveat: { en: 'These are statements about a search, not about priority. None of them is stated as “first”.', ru: 'Это утверждения о поиске, а не о приоритете. Ни одно из них не заявлено как «первый».' },
  },
}

/* ───────────── FINDINGS FROM THE 2026 LITERATURE REVIEW ───────────── */

export const findings = {
  badge: { en: 'CONCLUSIONS FROM THE REVIEW · AUGUST 2026', ru: 'ВЫВОДЫ ИЗ ИССЛЕДОВАНИЯ · АВГУСТ 2026' },
  title: {
    en: 'What a full read of the 2025–2026 literature changes about this claim',
    ru: 'Что сплошное чтение литературы 2025–2026 меняет в этом заявлении',
  },
  sub: {
    en: 'Twenty-eight works were checked by direct retrieval of the arXiv or publisher page; two entries could not be confirmed and are marked as such in the notes rather than cited here. What follows is what survived the read — including the parts that went against us.',
    ru: 'Двадцать восемь работ проверены прямым обращением к странице arXiv или издателя; две записи подтвердить не удалось, и они помечены в заметках, а не процитированы здесь. Ниже — то, что пережило чтение, включая места, сыгравшие против нас.',
  },
  items: [
    {
      n: '01',
      h: { en: 'A theorem-chosen radix against an empirically chosen one', ru: 'Основание, выбранное теоремой, против выбранного эмпирически' },
      b: {
        en: 'AetherFloat (26 Feb 2026) removes the hidden leading bit, base-2 normalisation and sign-magnitude coding to escape the AMAX block-scaling penalty — the same ground we stand on. The difference is not the outcome but the warrant: their quad-radix is proposed, ours is forced. T25 gives r² = r + 1 as the only closure condition, and T27 enumerates every multiply-free scale by companion-matrix sparsity. We can state what cannot exist; an empirical radix cannot.',
        ru: 'AetherFloat (26.02.2026) убирает скрытый ведущий бит, нормализацию по основанию 2 и sign-magnitude кодирование, чтобы уйти от штрафа блочного масштабирования AMAX — это та же земля, на которой стоим мы. Разница не в результате, а в основании права: их quad-radix предложен, наш — вынужден. Т25 даёт r² = r + 1 как единственное условие замкнутости, Т27 перечисляет все multiply-free шкалы по разрежённости companion-матрицы. Мы можем сказать, чего существовать не может; эмпирический радикс — не может.',
      },
      tag: 'proved' as Tag,
      refs: [{ label: 'AetherFloat · arXiv:2603.08741', url: 'https://arxiv.org/abs/2603.08741' }],
    },
    {
      n: '02',
      h: { en: 'The nearest neighbour tapers; we fix the fields', ru: 'Ближайший сосед сужается; мы фиксируем поля' },
      b: {
        en: 'Tekum (Hunhold, 25 Nov 2025) is balanced-ternary tapered-precision arithmetic and its abstract claims to surpass both posit and takum. That is the same word — ternary — over a different hardware contract. Tekum carries a variable-length regime and therefore a scan; TNF carries a fixed ternary exponent field and therefore a constant-latency decode. By T2 the two are separable by measurement alone: a tapered format loses M_eff with |e| (posit16 −0.254 bit/binade, takum16 −0.113), a fixed-field one does not (TNF16 9 → 8.99/9.01).',
        ru: 'Tekum (Hunhold, 25.11.2025) — балансно-троичная арифметика с taper, и её абстракт заявляет превосходство над posit и takum. Это то же слово — троичность — над иным аппаратным контрактом. У tekum regime переменной длины, а значит скан; у TNF фиксированное троичное поле экспоненты, а значит декод постоянной задержки. По Т2 их разделяет одно измерение: tapered-формат теряет M_eff с ростом |e| (posit16 −0.254 бита/бинада, takum16 −0.113), фиксированно-полевой — нет (TNF16 9 → 8.99/9.01).',
      },
      tag: 'measured' as Tag,
      refs: [
        { label: 'Tekum · arXiv:2512.10964', url: 'https://arxiv.org/abs/2512.10964' },
        { label: 'takum · arXiv:2404.18603', url: 'https://arxiv.org/abs/2404.18603' },
      ],
    },
    {
      n: '03',
      h: { en: 'The proof bar rose, and it rose in our favour', ru: 'Планка доказательства поднялась — и поднялась в нашу пользу' },
      b: {
        en: 'Two 2026 clusters now formalise low-precision arithmetic: FLoPS puts P3109 into Lean, and ARCH HDL generates SystemVerilog, SMT-LIB and a Lean 4 model from one bit-vector IR, proving multiplier-free operators over all 2^64 inputs. Both verify a given encoding exhaustively. T26 is a different kind of statement: in Z[φ] the whole linear path carries no rounding error at any fan-in and any depth, machine-checked in Coq — a property of the algebra, not of a bit pattern, so no input enumeration is involved. Exhaustive checking and algebraic closure are different layers, and a reviewer can check ours without hardware.',
        ru: 'Два кластера 2026 года формализуют малоразрядную арифметику: FLoPS переносит P3109 в Lean, а ARCH HDL генерирует SystemVerilog, SMT-LIB и модель Lean 4 из единого bit-vector IR, доказывая multiplier-free операторы на всех 2^64 входах. Оба верифицируют заданную кодировку исчерпывающе. Т26 — утверждение иного рода: в Z[φ] весь линейный путь не несёт ошибки округления при любом fan-in и любой глубине, машинно проверено в Coq — свойство алгебры, а не битового шаблона, так что перечисление входов не участвует. Исчерпывающая проверка и алгебраическая замкнутость — разные слои, и наш слой рецензент может проверить без железа.',
      },
      tag: 'coq' as Tag,
      refs: [
        { label: 'FLoPS · arXiv:2602.15965', url: 'https://arxiv.org/abs/2602.15965' },
        { label: 'ARCH HDL · arXiv:2607.23715', url: 'https://arxiv.org/abs/2607.23715' },
        { label: 'P3109 for ML · arXiv:2606.04028', url: 'https://arxiv.org/abs/2606.04028' },
      ],
    },
    {
      n: '04',
      h: { en: 'The block-scaling cluster argues our motivation for us', ru: 'Кластер блочного масштабирования аргументирует нашу мотивацию за нас' },
      b: {
        en: 'Four independent 2026 works say the same thing about current practice: max-magnitude block scales are suboptimal by quantisation error (ScaleSearch), FP4 sensitivity is layer- and block-dependent (NVFP4/MXFP4 diagnosis), block-based inference needs a co-designed pipeline to hold up across attention (Harmonia), and non-linear block scaling breaks end-to-end checks under fault injection (BFP-NPU reliability). A precision law in closed form is the alternative these papers describe the need for without naming.',
        ru: 'Четыре независимые работы 2026 года говорят о текущей практике одно и то же: масштабы блока по max-magnitude субоптимальны по ошибке квантизации (ScaleSearch), чувствительность FP4 зависит от слоя и блока (диагностика NVFP4/MXFP4), блочный инференс требует co-design всего конвейера, чтобы удержаться на attention (Harmonia), а нелинейное блочное масштабирование ломает end-to-end проверки под инъекцией сбоев (надёжность BFP-NPU). Закон точности в замкнутой форме — та альтернатива, потребность в которой эти работы описывают, не называя.',
      },
      tag: 'competitor' as Tag,
      refs: [
        { label: 'ScaleSearch · arXiv:2605.12464', url: 'https://arxiv.org/abs/2605.12464' },
        { label: 'FP4 diagnosis · arXiv:2603.08747', url: 'https://arxiv.org/abs/2603.08747' },
        { label: 'Harmonia · arXiv:2602.04595', url: 'https://arxiv.org/abs/2602.04595' },
        { label: 'BFP-NPU reliability · arXiv:2604.10494', url: 'https://arxiv.org/abs/2604.10494' },
      ],
    },
    {
      n: '05',
      h: { en: 'Ternary weights are cheap; ternary hardware is not', ru: 'Троичные веса дешевы; троичное железо — нет' },
      b: {
        en: 'The 1.58-bit line is thriving on the algorithmic side and expensive on the physical one. BitROM states that LLaMA-7B needs more than 1000 cm² of silicon on advanced CMOS nodes and answers with a bidirectional ROM array; LUT-based accelerator generation replaces multiplication with conditional additions in TSMC 16 nm; NativeTernary reaches exactly 2.000 bit/weight but as a wire format; TernaryLM trains natively to 58.42 validation perplexity on TinyStories. None of them changes the multiplication itself. GFTernary does — the weight application is one integer addition, a Fibonacci step in Z[φ], and by T8 the reason our own ternary claim stays architectural is written into the same theory.',
        ru: 'Линия 1.58 бита процветает на алгоритмической стороне и дорога на физической. BitROM указывает, что LLaMA-7B требует более 1000 см² кремния на продвинутых узлах CMOS, и отвечает двунаправленным ROM-массивом; генерация LUT-ускорителей заменяет умножение условными сложениями в TSMC 16 нм; NativeTernary достигает ровно 2.000 бита/вес, но как формат передачи; TernaryLM обучается нативно до validation perplexity 58.42 на TinyStories. Ни одна из них не меняет само умножение. GFTernary меняет: применение веса — одно целочисленное сложение, шаг Фибоначчи в Z[φ]; и по Т8 причина, по которой наше собственное троичное заявление остаётся архитектурным, записана в той же теории.',
      },
      tag: 'competitor' as Tag,
      refs: [
        { label: 'BitROM · arXiv:2509.08542', url: 'https://arxiv.org/abs/2509.08542' },
        { label: 'LUT 1.58-bit · arXiv:2604.25183', url: 'https://arxiv.org/abs/2604.25183' },
        { label: 'NativeTernary · arXiv:2604.03336', url: 'https://arxiv.org/abs/2604.03336' },
        { label: 'TernaryLM · arXiv:2602.07374', url: 'https://arxiv.org/abs/2602.07374' },
      ],
    },
    {
      n: '06',
      h: { en: 'Degree-three scales are an empty field, as of August 2026', ru: 'Шкалы третьей степени — пустое поле на август 2026' },
      b: {
        en: 'T27 names three degree-three multiply-free scales — plastic 1.3247, supergolden 1.4656, tribonacci 1.8393 — and a targeted search of 2025–2026 arXiv found no hardware-arithmetic work on any of them; the only tribonacci results found are pure number theory. This is a statement about a search, not a proof of absence, and it is dated: it can stop being true next month. It also cuts both ways — the same silence means no external result confirms the ladder rungs above 4 bits either.',
        ru: 'Т27 называет три multiply-free шкалы третьей степени — plastic 1.3247, supergolden 1.4656, tribonacci 1.8393 — и целевой поиск по arXiv 2025–2026 не нашёл ни одной работы по аппаратной арифметике ни для одной из них; единственные найденные результаты по трибоначчи — чистая теория чисел. Это утверждение о поиске, а не доказательство отсутствия, и оно датировано: перестать быть верным оно может в следующем месяце. Режет оно и в обе стороны — та же тишина означает, что и ступени лестницы выше 4 бит никем извне не подтверждены.',
      },
      tag: 'derived' as Tag,
      refs: [{ label: 'GoldenFloat · arXiv:2606.05017', url: 'https://arxiv.org/abs/2606.05017' }],
    },
    {
      n: '07',
      h: { en: 'The standard is moving fast enough to be a deadline', ru: 'Стандарт движется достаточно быстро, чтобы быть сроком' },
      b: {
        en: 'IEEE P3109 went v2.0 (29 Oct 2024) → v3.0 (21 Jul 2025) → v3.2 (5 Jan 2026) → v3.2.1 → v3.2.2 (13 Mar 2026) → v4.0 (26 Jun 2026): six releases in twenty months. Our own 83-format catalogue already carries a P3109 v3.2.0 cross-walk, which is now two minor versions behind. A format proposal that is not tracked against this cadence dates itself, and the cross-walk is a maintenance obligation rather than a completed deliverable.',
        ru: 'IEEE P3109 прошёл v2.0 (29.10.2024) → v3.0 (21.07.2025) → v3.2 (05.01.2026) → v3.2.1 → v3.2.2 (13.03.2026) → v4.0 (26.06.2026): шесть выпусков за двадцать месяцев. Наш собственный каталог 83 форматов уже несёт cross-walk к P3109 v3.2.0, и он отстал на две минорные версии. Предложение формата, не отслеживаемое против этого темпа, само себя датирует, а cross-walk — обязательство по поддержке, а не закрытая поставка.',
      },
      tag: 'spec' as Tag,
      refs: [
        { label: '83 formats · arXiv:2606.09686', url: 'https://arxiv.org/abs/2606.09686' },
        { label: 'P3109 Interim Report v4.0', url: 'https://docenti.ing.unipi.it/m.cococcioni/IEEE_P3109_WG_Interim_Report_ver_4.0_2026_06_26.pdf' },
      ],
    },
    {
      n: '08',
      h: { en: 'The open flow is the method, and it has a benchmark', ru: 'Открытый поток — это метод, и у него есть эталон' },
      b: {
        en: 'Every hardware number on this page comes from Yosys 0.65 + nextpnr-xilinx 1743d0f + Icarus 13.0, median of five seeds, DSP inference off — no Vivado in the loop. Basilisk quantifies what that costs: a tuned open flow reached 2.3× frequency and 1.6× logic area over baseline Yosys+OpenROAD in open 130 nm. So an open-flow number is not a weaker number, but it is a number attached to a toolchain version, and we publish the version with the number.',
        ru: 'Каждое аппаратное число на этой странице получено на Yosys 0.65 + nextpnr-xilinx 1743d0f + Icarus 13.0, медиана пяти seed’ов, инференс DSP выключен — без Vivado в цепи. Basilisk оценивает, чего это стоит: настроенный открытый поток дал 2.3× по частоте и 1.6× по площади логики относительно базового Yosys+OpenROAD в открытом 130 нм. Значит, число открытого потока не слабее — но это число, привязанное к версии тулчейна, и мы публикуем версию вместе с числом.',
      },
      tag: 'measured' as Tag,
      refs: [{ label: 'Basilisk · arXiv:2405.04257', url: 'https://arxiv.org/abs/2405.04257' }],
    },
    {
      n: '09',
      h: { en: 'We wrote the competitor’s decoder ourselves, and it is a distinct oracle', ru: 'Мы сами написали декодер конкурента — и это отдельный оракул' },
      b: {
        en: 'Reading a rival’s abstract is not a comparison. So Definitions 7–8 of the tekum paper were implemented directly — anchor, regime r, c = max(0, |r| − 2), fraction, specials, value s(1+f)·3^e — and run against our own takum16 and GF16 oracles. One accounting point has to be stated first: native tekum at n = 16 has 3^16 = 43 046 721 trit words, so a 65 536-input sweep is an explicitly labelled rank adapter, not a bit-level encoding. On that adapter, 65 536 of 65 536 codes differ from takum16 (2 special mismatches) and 65 536 of 65 536 differ from GF16 (1 023 special mismatches), with no bijection between value sets in either case. A nearest-grid model fits M_eff at −0.1210 bit/binade over |e| = 0…30, which is window-dependent modelling and is tagged as such.',
        ru: 'Прочитать абстракт конкурента — не сравнение. Поэтому Определения 7–8 работы по tekum реализованы напрямую — anchor, regime r, c = max(0, |r| − 2), fraction, специальные значения, значение s(1+f)·3^e — и прогнаны против наших собственных оракулов takum16 и GF16. Одну учётную вещь надо сказать вперёд: нативный tekum при n = 16 имеет 3^16 = 43 046 721 тритовых слов, поэтому перебор 65 536 входов — явно помеченный rank-адаптер, а не побитовая кодировка. На этом адаптере 65 536 из 65 536 кодов расходятся с takum16 (2 расхождения по особым значениям) и 65 536 из 65 536 — с GF16 (1 023 расхождения), и биекции между множествами значений нет ни в одном случае. Модель nearest-grid даёт наклон M_eff −0.1210 бита/бинада на |e| = 0…30, и это оконно-зависимое моделирование, так и помечено.',
      },
      tag: 'measured' as Tag,
      refs: [{ label: 'Tekum · arXiv:2512.10964', url: 'https://arxiv.org/abs/2512.10964' }],
    },
    {
      n: '10',
      h: { en: 'At four bits, software cannot pick the radix — and we tried', ru: 'На четырёх битах софт основание не выбирает — и мы пробовали' },
      b: {
        en: 'The 4-bit rung of the ladder was decided by perplexity alone, and perplexity at that width is noisy. Seven radices — φ, supergolden 1.4656, plastic 1.3247, and the controls 2, √2, √3, 1.5 — were therefore compared on eight independent software proxies: worst-case and L1 scale-quantisation error, a curvature-weighted error under normal, Student t(3) and Laplace weights, round-trip SQNR per 32-weight block, scale-code overload, and binade coverage. Medians over five seeds, and a repeat run byte-identical. The leaders conflict: √2 leads the curvature proxy under normal weights, 1.5 leads L1 and the Laplace SQNR, √3 leads under a heavy tail, and the L1 winner changes with the required range (plastic at 6 binades, √2 at 8, 1.5 at 10, √3 at 12). Five of eight margins fall inside the seed spread. The honest reading is that the 4-bit choice is not resolvable in software at all: it needs the same runtime-variable scale-applier synthesised for every candidate in one flow, measured for LUT, routed Fmax, critical-path depth and register count over five seeds. Until that runs, the φ pick at 4 bits stands on the perplexity result alone, and we say so.',
        ru: '4-битная ступень лестницы была решена одной перплексией, а перплексия на этой ширине шумна. Поэтому семь оснований — φ, supergolden 1.4656, plastic 1.3247 и контроли 2, √2, √3, 1.5 — сравнены по восьми независимым программным прокси: worst-case и L1 ошибка квантизации масштаба, ошибка, взвешенная кривизной, при нормальных, стьюдентовых t(3) и лапласовых весах, round-trip SQNR по блокам из 32 весов, перегрузка кода масштаба и покрытие бинад. Медианы по пяти seed’ам, повторный прогон побайтно идентичен. Лидеры конфликтуют: √2 ведёт по кривизне при нормальных весах, 1.5 — по L1 и по лапласову SQNR, √3 — при тяжёлом хвосте, а победитель по L1 меняется с требуемым диапазоном (plastic на 6 бинадах, √2 на 8, 1.5 на 10, √3 на 12). Пять отрывов из восьми лежат внутри разброса по seed’ам. Честное чтение: 4-битный выбор в софте не разрешается вообще — нужен один и тот же runtime-variable applier масштаба, синтезированный для каждого кандидата в одном потоке, с измерением LUT, разведённого Fmax, глубины критического пути и числа регистров на пяти seed’ах. Пока это не прогнано, выбор φ на 4 битах стоит на одном перплексити-результате, и мы это говорим.',
      },
      tag: 'measured' as Tag,
      refs: [{ label: 'FP4 diagnosis · arXiv:2603.08747', url: 'https://arxiv.org/abs/2603.08747' }, { label: 'AetherFloat · arXiv:2603.08741', url: 'https://arxiv.org/abs/2603.08741' }],
    },
  ],
  footer: {
    en: 'The full review, with the two unconfirmed entries and the works judged not relevant, is kept with the sources rather than summarised away.',
    ru: 'Полный обзор, вместе с двумя неподтверждёнными записями и работами, признанными нерелевантными, хранится при источниках, а не сворачивается в резюме.',
  },
}

/* ───────────────────────── LINEAGE ───────────────────────── */

export const lineage = {
  badge: { en: 'A 68-YEAR-OLD ARGUMENT', ru: '68-ЛЕТНИЙ АРГУМЕНТ' },
  title: { en: 'The ternary line was ended administratively, not technically', ru: 'Троичная линия была прекращена административно, а не технически' },
  items: [
    { year: 'c. 1840', h: { en: 'Thomas Fowler, Devon', ru: 'Томас Фаулер, Девон' }, b: { en: 'Builds a balanced-ternary calculating machine. The radix argument is made mechanically, before it is made electronically.', ru: 'Строит балансно-троичную вычислительную машину. Аргумент основания сделан механически — раньше, чем электронно.' } },
    { year: '1958', h: { en: 'Setun, Moscow State University', ru: 'Сетунь, МГУ' }, b: { en: 'N. P. Brusentsov builds it with S. L. Sobolev’s support, using paired ferrite cores for three stable states. The argument becomes a working computer.', ru: 'Н. П. Брусенцов строит её при поддержке С. Л. Соболева, используя парные ферритовые сердечники для трёх устойчивых состояний. Аргумент становится работающим компьютером.' } },
    { year: '1959–1965', h: { en: 'About fifty machines shipped', ru: 'Выпущено около пятидесяти машин' }, b: { en: 'A production ternary computer existed and was used.', ru: 'Серийный троичный компьютер существовал и использовался.' } },
    { year: '1970', h: { en: 'Setun-70', ru: 'Сетунь-70' }, b: { en: 'Its instruction-set ideas anticipate arguments later made independently for RISC. It never reaches series production, and the line is ended administratively.', ru: 'Идеи её системы команд предвосхищают аргументы, позже независимо сделанные для RISC. Серийного производства она не достигает, и линия прекращается административно.' } },
    { year: '1980s–', h: { en: 'Knuth keeps it in circulation', ru: 'Кнут удерживает идею в обороте' }, b: { en: 'Calling balanced ternary “perhaps the prettiest number system of all”. The line continues in device work rather than architecture: CNTFET and memristor ternary logic, and recently silicon-photonic balanced-ternary proposals.', ru: 'Называя балансно-троичную «пожалуй, самой красивой системой счисления». Линия продолжается в приборной работе, а не в архитектуре: CNTFET- и мемристорная троичная логика, недавно — кремний-фотонные балансно-троичные предложения.' } },
    { year: '2026', h: { en: 'The missing piece was not a fabric', ru: 'Не хватало не фабрики' }, b: { en: 'What the ternary programme lacked was a radix under which its symbols compose. The golden ratio has had that property — r² = r + 1 — since Euclid divided a segment in extreme and mean ratio. Putting it in the weight alphabet turns the old argument from a claim about storage density into a statement about arithmetic closure.', ru: 'Троичной программе не хватало не лучшей фабрики, а основания, при котором её символы компонуются. У золотого сечения это свойство — r² = r + 1 — было со времён Евклида, делившего отрезок в крайнем и среднем отношении. Помещение его в весовой алфавит превращает старый аргумент из заявления о плотности хранения в утверждение об арифметической замкнутости.' } },
  ],
}

/* ───────────────────────── REPRODUCE ───────────────────────── */

/* Блок автора и сотрудничества: авторство, способ связи и только те числа,
   что лежат на этой же странице с указанным происхождением. */
export const author = {
  badge: { en: 'WHO MEASURED THIS', ru: 'КТО ЭТО ИЗМЕРИЛ' },
  title: {
    en: 'One engineer, one board, and a public record of what did not work',
    ru: 'Один инженер, одна плата и публичный список того, что не сработало',
  },
  sub: {
    en: 'Every number on this page was measured by the person named here, on hardware named here, with a toolchain anyone can install.',
    ru: 'Каждое число на этой странице измерено человеком, названным здесь, на железе, названном здесь, тулчейном, который может поставить любой.',
  },
  name: 'Dmitrii Vasilev',
  nameRu: 'Дмитрий Васильев',
  role: {
    en: 'FPGA/RTL and hardware-AI engineer · author of the GF-T ternary format · specification → RTL → open synthesis flow',
    ru: 'Инженер FPGA/RTL и аппаратного ИИ · автор тернарного формата GF-T · спецификация → RTL → открытый поток синтеза',
  },
  photo: 'https://avatars.githubusercontent.com/u/6774813?v=4',
  orcid: '0009-0008-4294-6159',
  email: 'admin@t27.ai',
  facts: [
    { v: '2', l: { en: 'preprints, both public', ru: 'препринта, оба публичны' }, tag: 'spec' },
    { v: '52 / 16', l: { en: 'theorems / retractions in the paper', ru: 'теорем / ретракций в статье' }, tag: 'proved' },
    { v: '83', l: { en: 'formats in the catalog', ru: 'формата в каталоге' }, tag: 'spec' },
    { v: '974.66 MHz', l: { en: 'GFTernary decoder, 66 LUT, XC7A200T', ru: 'декодер GFTernary, 66 LUT, XC7A200T' }, tag: 'measured' },
  ],
  notClaimed: {
    en: 'Not claimed here: silicon (none exists), a ternary fabric (none was available), and any comparison against tekum — the comparison is against takum, which is a different format.',
    ru: 'Здесь не заявляется: кремний (его нет), тернарная фабрика (её не было) и любое сравнение с tekum — сравнение идёт с takum, а это другой формат.',
  },
  links: [
    { label: { en: 'Full biography and CV', ru: 'Полная биография и CV' }, href: '#/about', note: { en: 'Track record, publications, contacts', ru: 'Опыт, публикации, контакты' } },
    { label: { en: 'Licence the arithmetic cores', ru: 'Лицензировать арифметические ядра' }, href: '#/ip', note: { en: 'Cores that have been through the open flow', ru: 'Ядра, прошедшие открытый поток' } },
    { label: { en: 'Send RTL, get it measured', ru: 'Присылайте RTL — измерю' }, href: '#/verification', note: { en: 'Same board, same flow, same seeds', ru: 'Та же плата, тот же поток, те же seed’ы' } },
    { label: { en: 'Joint work, review, funding', ru: 'Совместная работа, рецензия, финансирование' }, href: 'mailto:admin@t27.ai?subject=Trinity%20—%20collaboration', note: { en: 'Terms are in the investment section below, and are discussed directly.', ru: 'Условия — в блоке «Инвестиции» ниже, обсуждаются напрямую' } },
  ],
}

/* Блок инвестиций. Порядок разделов взят из канона питча, а не из удобства
   автора: purpose → problem/why now → market → business model → traction →
   defensibility → use of funds → milestones → risks → ask. Совпадающее
   требование Sequoia («define your company in a single declarative sentence»,
   «What's changed?») и YC («do not bury the lead»); DocSend меряет средний
   просмотр деки менее 3,5 минут, поэтому методологическая оговорка ушла из
   первого экрана в сноску под цифрами.

   Правило тегов действует и здесь: `terms` — условия предложения, `plan` —
   план, а не результат, `external` — чужое число с прямой ссылкой на источник.
   Публичной цены за долю в блоке нет: ни на одном из десяти просмотренных
   сайтов чиповых компаний ранней стадии её нет, а публичная реклама условий
   размещения — отдельный регуляторный режим. */
export const invest = {
  badge: { en: 'INVESTMENT', ru: 'ИНВЕСТИЦИИ' },
  title: {
    en: 'Trinity licenses synthesisable arithmetic: numeric formats with decoders, cores and conformance vectors that a chip team can drop into an SoC',
    ru: 'Trinity лицензирует синтезируемую арифметику: численные форматы с декодерами, ядрами и conformance-векторами, которые команда чипа ставит в свой SoC',
  },
  sub: {
    en: 'Low precision became the default in one generation, and the standards did not keep up: the MX specification is license-free but says nothing about hardware conformance, and IEEE P3109 is still an active PAR whose drafts must not be used for conformance. What a chip team is missing is not another format — it is proof that a format behaves identically in silicon and in the reference model.',
    ru: 'Низкая точность стала нормой за одно поколение, а стандарты за ней не успели: спецификация MX бесплатна, но об аппаратном conformance в ней ничего нет, а IEEE P3109 — до сих пор активный PAR, черновики которого запрещено использовать для conformance. Команде чипа не хватает не ещё одного формата, а доказательства, что формат ведёт себя в кремнии так же, как в эталонной модели.',
  },
  factsTitle: { en: 'The terms, and where this stands today', ru: 'Условия и где это сейчас' },
  facts: [
    { v: '$3M', l: { en: 'for 1% equity — the asking terms', ru: 'за 1% equity — запрашиваемые условия' }, tag: 'terms' },
    { v: '$300M', l: { en: 'valuation asked, pre-money', ru: 'запрашиваемая оценка, pre-money' }, tag: 'terms' },
    { v: '100%', l: { en: 'founder-held today, no prior round', ru: 'у основателя сегодня, прежних раундов нет' }, tag: 'terms' },
    { v: '18', l: { en: 'months of runway planned, in three tranches', ru: 'месяцев дистанции в плане, тремя траншами' }, tag: 'plan' },
    { v: 'FPGA', l: { en: 'stage: measured on FPGA, no silicon yet', ru: 'стадия: измерено на FPGA, кремния пока нет' }, tag: 'measured' },
    { v: '83 / 52', l: { en: 'formats catalogued and theorems proved behind the ask', ru: 'форматов в каталоге и теорем доказано за этим запросом' }, tag: 'proved' },
  ],
  whyTitle: { en: 'Why this is money now, not later', ru: 'Почему это деньги сейчас, а не потом' },
  why: [
    {
      t: { en: 'Four bits went mainstream in one generation', ru: 'Четыре бита стали мейнстримом за одно поколение' },
      d: { en: 'NVIDIA reports NVFP4 holding within 1% of FP8 accuracy at roughly 25% of FP16 memory, and up to 1.59× training throughput against BF16 over trillion-token runs. Precision is now a hardware design variable, not a software detail.', ru: 'NVIDIA сообщает, что NVFP4 держится в пределах 1% точности FP8 при примерно 25% памяти FP16, и до 1,59× пропускной способности обучения против BF16 на прогонах в триллион токенов. Точность стала переменной проектирования железа, а не деталью софта.' },
      src: { u: 'https://developer.nvidia.com/blog/introducing-nvfp4-for-efficient-and-accurate-low-precision-inference/', n: 'NVIDIA' },
      tag: 'external',
    },
    {
      t: { en: 'The format is free; the conformance is not written', ru: 'Формат бесплатен, conformance не написан' },
      d: { en: 'OCP released the MX formats in September 2023 in an open, license-free form, authored by Microsoft, AMD, Arm, Intel, Meta, NVIDIA and Qualcomm. A free specification does not tell a chip team whether their decoder matches it bit for bit. That gap is the product.', ru: 'OCP выпустила форматы MX в сентябре 2023 в открытой бесплатной форме, авторы — Microsoft, AMD, Arm, Intel, Meta, NVIDIA, Qualcomm. Бесплатная спецификация не говорит команде чипа, совпадает ли их декодер с ней бит в бит. Этот разрыв и есть продукт.' },
      src: { u: 'https://www.opencompute.org/documents/ocp-microscaling-formats-mx-v1-0-spec-final-pdf', n: 'OCP MX v1.0' },
      tag: 'external',
    },
    {
      t: { en: 'The standard is not ratified yet', ru: 'Стандарт ещё не утверждён' },
      d: { en: 'IEEE P3109, «Arithmetic Formats for Machine Learning», has been an active PAR since February 2023 and is not approved; the working group states its drafts must not be used for conformance claims. Anyone shipping low-precision silicon today has no ratified reference to check against.', ru: 'IEEE P3109, «Arithmetic Formats for Machine Learning», — активный PAR с февраля 2023 года и не утверждён; рабочая группа прямо указывает, что её черновики нельзя использовать для заявлений о conformance. У всех, кто выпускает малобитный кремний сегодня, утверждённого эталона для сверки нет.' },
      src: { u: 'https://standards.ieee.org/ieee/3109/11165/', n: 'IEEE SA' },
      tag: 'external',
    },
    {
      t: { en: 'The cost curve makes the bits expensive', ru: 'Кривая затрат делает биты дорогими' },
      d: { en: 'Epoch AI puts the cost of a frontier training run on a 2.4× per year trend since 2016, crossing a billion dollars per run before 2027. When a run costs that much, a bit-level error in a format is not an academic matter.', ru: 'Epoch AI оценивает стоимость фронтир-прогона обучения трендом 2,4× в год с 2016 года, с переходом за миллиард долларов на прогон до 2027-го. При такой стоимости прогона битовая ошибка в формате — уже не академический вопрос.' },
      src: { u: 'https://epoch.ai/publications/how-much-does-it-cost-to-train-frontier-ai-models', n: 'Epoch AI' },
      tag: 'external',
    },
  ],
  marketTitle: { en: 'The market, counted from the bottom', ru: 'Рынок, считаемый снизу' },
  marketSub: {
    en: 'Not the AI chip market — the agencies disagree about its 2025 base by a factor of two, and a number nobody can decompose is not evidence. The market a core is sold into is the IP licensing market, and its unit economics are published by the companies that live in it.',
    ru: 'Это не рынок ИИ-чипов — агентства расходятся по его базе 2025 года вдвое, а число, которое нельзя разложить, доказательством не является. Ядро продаётся на рынок лицензирования IP, и его юнит-экономику публикуют сами компании, которые на нём живут.',
  },
  market: [
    { v: { en: '$9.8B', ru: '$9,8 млрд' }, l: { en: 'semiconductor IP licensing, 2025, with the top five holding 62.2%', ru: 'лицензирование semiconductor IP, 2025; топ-5 держат 62,2%' }, src: { u: 'https://www.gminsights.com/industry-analysis/semiconductor-intellectual-property-ip-market', n: 'GMInsights' }, tag: 'external' },
    { v: { en: '~$1.2M', ru: '~$1,2 млн' }, l: { en: 'average per licence: Ceva signed 54 agreements for $63.6M in 2025', ru: 'средний чек лицензии: Ceva подписала 54 соглашения на $63,6 млн за 2025' }, src: { u: 'https://www.ceva-ip.com/press/ceva-inc-announces-fourth-quarter-and-full-year-2025-financial-results/', n: 'Ceva FY2025' }, tag: 'derived' },
    { v: '~5% / ~10%', l: { en: 'royalty rates Arm itself discloses for CPU IP and for CSS', ru: 'ставки роялти, раскрытые самой Arm: CPU IP и CSS' }, src: { u: 'https://investors.arm.com/static-files/11881690-3c08-4148-bf7f-1504442b4ec4', n: 'Arm IR' }, tag: 'external' },
    { v: '97,9%', l: { en: 'Arm gross margin, Q4 FY2026 — why this model is worth building', ru: 'валовая маржа Arm, Q4 FY2026 — почему эту модель стоит строить' }, src: { u: 'https://www.sec.gov/Archives/edgar/data/1973239/000197323926000062/exhibit992fye26q431-marx26.htm', n: 'Arm, SEC' }, tag: 'external' },
  ],
  modelTitle: { en: 'What is actually sold', ru: 'Что на самом деле продаётся' },
  model: [
    { t: { en: 'Not the format', ru: 'Не формат' }, d: { en: 'A number format cannot be sold: MX is license-free by design, and IEEE formats are public by definition. Selling a format was never the plan.', ru: 'Числовой формат продать нельзя: MX бесплатен по замыслу, форматы IEEE публичны по определению. Продажа формата планом и не была.' }, tag: 'spec' },
    { t: { en: 'The implementation', ru: 'Реализация' }, d: { en: 'Synthesisable decoders and arithmetic cores that have been through an open flow on real hardware, delivered as RTL with the synthesis commands that produced the numbers.', ru: 'Синтезируемые декодеры и арифметические ядра, прошедшие открытый поток на реальном железе, отдаются как RTL с теми же командами синтеза, что дали числа.' }, tag: 'measured' },
    { t: { en: 'The conformance suite', ru: 'Conformance-набор' }, d: { en: 'Bit-exact vectors per format, plus the second-oracle checks. This is the part a chip team cannot download and cannot cheaply build, and the part that survives whichever standard wins.', ru: 'Бит-точные векторы на каждый формат плюс проверки вторым оракулом. Именно это команда чипа не может скачать и не может дешево построить — и именно это переживёт любой победивший стандарт.' }, tag: 'spec' },
  ],
  doneTitle: { en: 'What exists before the money', ru: 'Что существует до денег' },
  done: [
    { v: '2', l: { en: 'preprints, both public', ru: 'препринта, оба публичны' }, tag: 'spec' },
    { v: '52', l: { en: 'theorems proved in the paper', ru: 'теоремы, доказанные в статье' }, tag: 'proved' },
    { v: '83', l: { en: 'formats in the catalog', ru: 'формата в каталоге' }, tag: 'spec' },
    { v: '5 / 9', l: { en: 'ladder rungs standing in hardware', ru: 'ступеней лестницы стоят в железе' }, tag: 'measured' },
    { v: '66 LUT', l: { en: 'GFTernary decoder at 974.66 MHz on XC7A200T', ru: 'декодер GFTernary на 974.66 МГц на XC7A200T' }, tag: 'measured' },
    { v: '2.1× / 2.6×', l: { en: 'mean relative error against takum16 / takum32', ru: 'средней относительной ошибки против takum16 / takum32' }, tag: 'measured' },
  ],
  moatTitle: { en: 'Defensibility, stated exactly', ru: 'Защищённость — точно как есть' },
  moat: [
    { t: { en: 'No patents', ru: 'Патентов нет' }, d: { en: 'Nothing is granted and nothing is filed. Preprints and open RTL create priority of publication, not exclusivity — and publishing first forecloses a patent on the same disclosure. This is a deliberate trade and an investor should price it as one.', ru: 'Ничего не выдано и ничего не подано. Препринты и открытый RTL дают приоритет публикации, а не исключительность — и публикация первым закрывает патент на то же раскрытие. Это осознанный обмен, и инвестор должен оценивать его как обмен.' }, tag: 'spec' },
    { t: { en: 'The defensible asset is the bench', ru: 'Защищённый актив — стенд' }, d: { en: 'The vectors, the second oracle, the seeds and the flow that make a claim checkable. Copying a format takes an afternoon; reproducing a conformance corpus that a chip team will trust does not.', ru: 'Векторы, второй оракул, seed’ы и поток, которые делают заявление проверяемым. Скопировать формат — дело вечера; воспроизвести conformance-корпус, которому поверит команда чипа, — нет.' }, tag: 'measured' },
    { t: { en: 'The named alternatives', ru: 'Названные альтернативы' }, d: { en: 'takum and tekum (Hunhold), posit (Gustafson and the Calligo Tech line), and the plain IEEE and MX formats. They are on this page by name, with their results reproduced and credited rather than paraphrased.', ru: 'takum и tekum (Hunhold), posit (Gustafson и линия Calligo Tech), а также обычные форматы IEEE и MX. Они названы на этой странице, их результаты воспроизведены и зачтены, а не пересказаны.' }, tag: 'competitor' },
  ],
  useTitle: { en: 'Where the money goes', ru: 'На что идут деньги' },
  uses: [
    { p: '60%', t: { en: 'Engineering', ru: 'Инженерия' }, d: { en: 'ASIC track for the arithmetic cores, and the compute axis of the catalog that the FPGA cannot close', ru: 'ASIC-трек для арифметических ядер и вычислительная ось каталога, которую FPGA закрыть не может' } },
    { p: '25%', t: { en: 'Verification', ru: 'Верификация' }, d: { en: 'Conformance vectors for the remaining formats, second-oracle checks, and machine-checked proofs beyond the current set', ru: 'Conformance-векторы для оставшихся форматов, проверки вторым оракулом и машинно проверенные доказательства за пределами текущего набора' } },
    { p: '15%', t: { en: 'Operations', ru: 'Операции' }, d: { en: 'Boards, tooling, publication costs, and the time to answer a reviewer properly', ru: 'Платы, инструменты, публикационные расходы и время на нормальный ответ рецензенту' } },
  ],
  milestonesTitle: { en: 'Three tranches, each released by a check anyone can run', ru: 'Три транша, каждый открывается проверкой, которую может прогнать любой' },
  milestonesSub: {
    en: 'Hardware money is released against milestones rather than months — the gate for a semiconductor company is a tape-out and working chips. Each tranche below states its own gate, and a gate that does not close is a reason not to release the next one.',
    ru: 'Деньги в железе выдаются под майлстоуны, а не под месяцы: гейт для полупроводниковой компании — тейп-аут и работающие чипы. Каждый транш ниже несёт свой гейт, и незакрытый гейт — причина не открывать следующий.',
  },
  milestones: [
    { n: { en: 'Tranche 1 — months 1–6', ru: 'Транш 1 — месяцы 1–6' }, g: { en: 'Gate: the compute axis of the catalog closed as far as the open FPGA flow allows, with the vectors published alongside, and a head-to-head against takum RTL on one flow — which needs a VHDL front end this bench does not have.', ru: 'Гейт: вычислительная ось каталога закрыта настолько, насколько позволяет открытый FPGA-поток, с публикацией векторов, и прямое сравнение с RTL takum на одном потоке — для него нужен VHDL-фронтенд, которого у этого стенда нет.' } },
    { n: { en: 'Tranche 2 — months 7–12', ru: 'Транш 2 — месяцы 7–12' }, g: { en: 'Gate: the paper through peer review, and a first external design partner running the cores on their own hardware — an evaluation agreement, not a mention.', ru: 'Гейт: статья прошла рецензирование, и первый внешний design partner прогоняет ядра на своём железе — соглашение об оценке, а не упоминание.' } },
    { n: { en: 'Tranche 3 — months 13–18', ru: 'Транш 3 — месяцы 13–18' }, g: { en: 'Gate: the arithmetic cores taped out, so the numbers stop being FPGA numbers, and a first paid licence of a core that has been through the flow.', ru: 'Гейт: арифметические ядра отправлены в кремний, чтобы числа перестали быть FPGA-числами, и первая платная лицензия на ядро, прошедшее поток.' } },
  ],
  riskTitle: { en: 'What an investor is buying, and what they are not', ru: 'Что инвестор покупает, а что — нет' },
  risks: [
    { en: 'There is no silicon. Every hardware number here was measured on a binary FPGA — an ALINX AX7203, XC7A200T — on an open flow, and an ASIC will differ.', ru: 'Кремния нет. Каждое аппаратное число здесь измерено на бинарной FPGA — ALINX AX7203, XC7A200T — открытым потоком, и на ASIC оно будет другим.' },
    { en: 'There is no ternary fabric to buy. The ternary exponent is an architectural property; on binary hardware it neither wins nor loses, and ternary lost to binary three separate times in our own measurements.', ru: 'Тернарной фабрики не купить. Тернарная экспонента — архитектурное свойство; на бинарном железе она не выигрывает и не проигрывает, а тернарность трижды независимо проиграла бинарности в наших же измерениях.' },
    { en: 'There is no energy number on offer. Energy was not measured on this bench, and area and frequency do not stand in for it.', ru: 'Числа по энергии в предложении нет. Энергия на этом стенде не измерялась, а площадь и частота её не заменяют.' },
    { en: 'This is one engineer with one board, no revenue and no signed licensee. The plan above is what money changes; the record above is what exists without it.', ru: 'Это один инженер с одной платой, без выручки и без подписанного лицензиата. План выше — то, что меняют деньги; запись выше — то, что существует без них.' },
  ],
  takeawayTitle: { en: 'Three things to keep', ru: 'Три вещи, которые стоит запомнить' },
  takeaways: [
    { en: 'Precision became a hardware variable, and the standard that would settle it is not ratified.', ru: 'Точность стала переменной железа, а стандарт, который её закрыл бы, не утверждён.' },
    { en: 'The sellable asset is not the format but the conformance bench behind it, in a market where a licence averages about $1.2M and royalties run at rates Arm publishes.', ru: 'Продаваемый актив — не формат, а conformance-стенд за ним, на рынке, где лицензия в среднем около $1,2 млн, а роялти идут по ставкам, которые публикует Arm.' },
    { en: 'The record is checkable today on an open toolchain, and everything it does not cover is written down on this page.', ru: 'Запись проверяема сегодня на открытом тулчейне, а всё, что она не покрывает, выписано на этой же странице.' },
  ],
  note: {
    en: 'The tags are not decoration. Offer terms are an asking position, not a measurement; the allocation and the tranches are a plan, not a result; third-party figures link to the page they came from. The engineering figures are the same ones measured above, with the same origins.',
    ru: 'Теги здесь не украшение. Условия предложения — запрашиваемая позиция, а не измерение; распределение и транши — план, а не результат; внешние числа ведут ссылкой на страницу, откуда взяты. Инженерные цифры — те же, что измерены выше, с тем же происхождением.',
  },
  ctas: [
    { label: { en: 'Investor — request the deck and the terms', ru: 'Инвестор — запросить деку и условия' }, href: 'mailto:admin@t27.ai?subject=Trinity%20—%20investment' },
    { label: { en: 'Licence a core', ru: 'Лицензировать ядро' }, href: '#/ip' },
    { label: { en: 'Every measured number, and its limits', ru: 'Все измеренные числа и их границы' }, href: '#/proof' },
  ],
  contact: 'admin@t27.ai',
}

export const reproduce = {
  badge: { en: 'REPRODUCE IT', ru: 'ВОСПРОИЗВЕСТИ' },
  title: { en: 'A result nobody can reproduce without buying something is not a public result', ru: 'Результат, который нельзя воспроизвести не купив что-то, не является публичным результатом' },
  sub: {
    en: 'The oracle, the RTL, the equivalence testbenches and the synthesis commands are public. The whole toolchain is open and none of it requires a licence.',
    ru: 'Оракул, RTL, эквивалентностные тестбенчи и команды синтеза публичны. Весь тулчейн открыт, и ничто в нём не требует лицензии.',
  },
  chain: ['Yosys 0.65', 'nextpnr-xilinx 1743d0f', 'Icarus Verilog 13.0', 'Python 3.14', 'XC7A200T / ALINX AX7203'],
  links: [
    { label: { en: 'Ternary Network Floats — the paper', ru: 'Ternary Network Floats — статья' }, href: '#/resources', note: { en: '52 theorems, 16 retractions', ru: '52 теоремы, 16 ретракций' } },
    { label: { en: 'GoldenFloat — arXiv:2606.05017', ru: 'GoldenFloat — arXiv:2606.05017' }, href: 'https://arxiv.org/abs/2606.05017', note: { en: 'φ-derived static-split family, GF4 to GF1024', ru: 'φ-производное семейство со статическим разбиением, GF4…GF1024' }, external: true },
    { label: { en: '83-format catalog — arXiv:2606.09686', ru: 'Каталог 83 форматов — arXiv:2606.09686' }, href: 'https://arxiv.org/abs/2606.09686', note: { en: 'bit-exact conformance vectors', ru: 'бит-точные conformance-векторы' }, external: true },
    { label: { en: 'Send RTL, get it measured', ru: 'Присылайте RTL — измерю' }, href: '#/verification', note: { en: 'On the same board, the same flow, the same seeds', ru: 'На той же плате, тем же потоком, теми же seed’ами' } },
    { label: { en: 'Licensing the arithmetic cores', ru: 'Лицензирование арифметических ядер' }, href: '#/ip', note: { en: 'Cores that have been through the flow', ru: 'Ядра, прошедшие поток' } },
    { label: { en: 'Every measured number, and its limits', ru: 'Все измеренные числа и их границы', }, href: '#/proof', note: { en: 'The proof page', ru: 'Страница доказательств' } },
  ],
  contact: 'admin@t27.ai',
}
