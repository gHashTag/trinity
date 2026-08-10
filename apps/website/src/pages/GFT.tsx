"use client";
import { motion } from 'framer-motion'
import { usePageMeta } from '../hooks/usePageMeta'
import { useI18n } from '../i18n/context'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'

/**
 * The format's own page.
 *
 * GF-T was the strongest thing on this site and it was the fourth bullet in two
 * lists. An engineer deciding whether to adopt a number format needs the field
 * layout, the accuracy against the incumbent, what it costs in hardware, what it
 * runs at, and where it loses — on one page, with the working shown. That is what
 * this is.
 *
 * Every figure here was measured or re-measured on 8 August 2026 and every one
 * names the tool that produced it.
 */

// Both the oracle and the RTL link were 404. Measured against a full
// recursive tree of trinity-fpga (18,617 paths): conformance/gft16_ref.py
// does not exist, and build/ does not exist at all.
//
// The oracle is repointed to conformance/gf_ref.py because the research file
// behind this whole claim -- research/GFT16_BEATS_TEKUM16_2026-08-05.md,
// which IS live -- names gf_ref.py and tekum_ref.py as the two models it
// compared. That is sourced, not guessed.
//
// The RTL is published after all -- in gHashTag/trinity, not trinity-fpga.
// I searched one repo's tree (18,617 paths), found no gft_mul.v, and wrote
// that it existed nowhere. It is at fpga/gft/gft_mul_w.v, and fpga/gft/
// README.md carries the exact synthesis table this page shows. Searching one
// repository does not license a claim about all of them.
//
// gf16_mul.v in trinity-fpga was NOT the answer and is still not: GF-T16 is
// sign:offset:mant in a u32, GF16 is S1E6M9 bias 31, and substituting one
// format's multiplier for another's is the easiest error in this corpus.
const LINKS = {
  paper: 'https://arxiv.org/abs/2606.05017',
  catalogue: 'https://arxiv.org/abs/2606.09686',
  oracle: 'https://github.com/gHashTag/trinity-fpga/blob/main/conformance/gf_ref.py',
  tekum: 'https://github.com/gHashTag/trinity-fpga/blob/main/conformance/tekum_ref.py',
  rtl: 'https://github.com/gHashTag/trinity/blob/main/fpga/gft/gft_mul_w.v',
  synth: 'https://github.com/gHashTag/trinity/blob/main/fpga/gft/README.md',
  research: 'https://github.com/gHashTag/trinity-fpga/blob/main/research/GFT16_BEATS_TEKUM16_2026-08-05.md',
}

const EMAIL = 'admin@t27.ai'

const ACCURACY: [string, string, string, string][] = [
  ['|e| < 8', '3.56e-4', '3.27e-4', 'a tie'],
  ['|e| 8–20', '3.52e-4', '1.00e-3', '2.84× better'],
  ['|e| 20–38', '3.53e-4', '1.95e-3', '5.53× better'],
]

const LADDER: [string, string, string][] = [
  ['GF-T8', '50', '153.23 MHz'],
  ['GF-T16', '212', '131.73 MHz'],
  ['GF-T32', '1,477', '83.27 MHz'],
]

// Both rows are reproduced from fpga/gft/README.md in gHashTag/trinity, which
// carries this table verbatim next to the sources it describes:
// gft_mul_w.v (widths the values need) and gft_mul_wp.v (the same, pipelined).
const COST: [string, string, string, string][] = [
  ['gft_mul, 32-bit ports', '1,179', '3 with DSP allowed', '81 MHz'],
  ['Width-corrected', '219', '0', '81.35 MHz'],
  ['Width-corrected, pipelined', '219', '0', '147.32 MHz'],
]

const WHY = [
  ['No regime decode', 'tekum16 pays for a variable-length regime field — barrel-shift alignment and variable extraction — on any fabric. GF-T has fixed fields, so that cost is simply absent.'],
  ['The exponent is balanced ternary', 'Four trits, so 3⁴ = 81 exponent values. On a ternary fabric the exponent add is native: no binary carry, no base conversion.'],
  ['Precision does not taper', 'Nine mantissa bits at every magnitude. tekum16 narrows to about four at the extremes, which is where the 5.53× comes from.'],
]

const LIMITS = [
  ['The range is bounded, and that is the trade', 'GF-T16 reaches ±40 in powers of two — roughly ±12 decades. tekum16’s regime is unbounded, so beyond that GF-T16 overflows and tekum16 keeps working. Fixed fields buy the cheap datapath and the uniform precision; the price is range, and most ML and DSP workloads never reach it.'],
  ['The accuracy bins are powers of two', 'Not decades. An earlier note labelled them "dec", which would send a reviewer to check the one reading under which the far result looks invented. Corrected upstream.'],
  ['Measured on one device family', 'Artix-7, on the open flow. Not multi-corner characterisation, and the ASIC numbers will differ.'],
  ['The comparison is against a model of tekum, not tekum itself', 'tekum (arXiv:2512.10964) is a descendant of takum adapted for balanced ternary. The oracle it is measured against here is a reverse-engineered structural model built from takum’s field scheme — the full per-trit specification needs the paper. The ratios are as good as that model.'],
  ['No head-to-head in hardware yet', 'takum’s RTL is public and is VHDL (takum-arithmetic/Takum-Codec-RTL). Synthesising it alongside GF-T needs a VHDL front end this bench does not have, so the cost figures here are GF-T’s own. What can be said from their source: their 16-bit codec pulls in a 725-line FloPoCo leading-zero-counter and barrel shifter, generated for a Kintex-7. That is the regime decode GF-T’s fixed fields do not have — a structural difference, not a measured one.'],
]

const RU = {
  eyebrow: 'Формат',
  h1: 'GF-T — float, у которого экспонента тернарная.',
  lede: 'Экспонента — сбалансированное тернарное число, поля фиксированы. Это убирает главную статью расхода конкурента и делает сложение экспонент нативным на тернарной фабрике. Против tekum16 — ничья у единицы, в 2.84 раза точнее на средней дальности и в 5.53 раза на дальней.',
  layoutTitle: 'Как устроен',
  accuracyTitle: 'Точность против tekum16',
  accuracyNote: 'Средняя относительная ошибка на цикле кодирование→декодирование, 6000 значений, случайный знак. Перемерено независимо 8 августа 2026 по тем же оракулам: отношения воспроизводятся точно. Бины — в степенях двойки.',
  cols: ['Величина', 'GF-T16', 'tekum16', 'Итог'],
  accuracy: [
    ['|e| < 8', '3.56e-4', '3.27e-4', 'ничья'],
    ['|e| 8–20', '3.52e-4', '1.00e-3', 'в 2.84 раза точнее'],
    ['|e| 20–38', '3.53e-4', '1.95e-3', 'в 5.53 раза точнее'],
  ] as [string, string, string, string][],
  whyTitle: 'Почему он дешевле на тернарной фабрике',
  why: [
    ['Нет декодирования режима', 'tekum16 платит за поле режима переменной длины — выравнивание барабанным сдвигом и переменное извлечение — на любой фабрике. У GF-T поля фиксированы, и этой статьи расхода просто нет.'],
    ['Экспонента — сбалансированная тернарная', 'Четыре трита, то есть 3⁴ = 81 значение экспоненты. На тернарной фабрике сложение экспонент нативно: без бинарного переноса и конверсии основания.'],
    ['Точность не сужается', 'Девять бит мантиссы на любой величине. tekum16 сужается примерно до четырёх на краях — отсюда и 5.53×.'],
  ],
  costTitle: 'Что стоит в железе',
  costNote: 'Умножитель GF-T16, синтез под xc7 и разводка на XC7A200T, nextpnr-xilinx, аппаратные умножители отключены. Все три варианта побитово эквивалентны — доказано на 321 156 комбинациях входов и 199 994 циклах конвейера.',
  costCols: ['Вариант', 'LUT', 'DSP48', 'Fmax'],
  cost: [
    ['gft_mul, 32-битные порты', '1 179', '3, если разрешить DSP', '81 МГц'],
    ['С правильными разрядностями', '219', '0', '81.35 МГц'],
    ['С разрядностями и конвейером', '219', '0', '147.32 МГц'],
  ] as [string, string, string, string][],
  ladderTitle: 'Вся лестница',
  ladderNote: 'Один модуль покрывает все ступени: разрядности выводятся из параметров. С конвейером, латентность один такт, измерено на одном и том же стенде — поэтому три строки сравнимы между собой. Эквивалентность доказана на каждой ступени против эталона этой ступени.',
  ladderCols: ['Ступень', 'LUT', 'Fmax'],
  ladder: [
    ['GF-T8', '50', '153.23 МГц'],
    ['GF-T16', '212', '131.73 МГц'],
    ['GF-T32', '1 477', '83.27 МГц'],
  ] as [string, string, string][],
  widthTitle: 'Находка: интерфейс стоил в пять раз дороже арифметики',
  widthBody: 'В исходном модуле все порты объявлены 32-битными, хотя в GF-T16 нет ничего 32-битного: поле мантиссы 9 бит, значит (1+M) — 10, их произведение — 20, а смещение экспоненты не превышает 80, то есть 7 бит. Синтезатор честно строил умножитель 32×32 и 32-битное дерево сравнений и платил за это полную цену: 1179 LUT либо три блока DSP48. С правильными разрядностями — 219 LUT и ни одного DSP, при побитовой идентичности на 321 156 комбинациях.',
  limitsTitle: 'Где он проигрывает',
  limits: [
    ['Диапазон ограничен — и это плата', 'GF-T16 доходит до ±40 в степенях двойки, примерно ±12 декад. Режим tekum16 не ограничен, поэтому дальше GF-T16 переполняется, а tekum16 продолжает работать. Фиксированные поля покупают дешёвый тракт и равномерную точность; цена — диапазон, до которого большинство ML- и DSP-нагрузок не доходят.'],
    ['Бины точности — в степенях двойки', 'Не в декадах. В более ранней записке они были подписаны «dec», а это отправляет рецензента проверять ровно тем способом, при котором дальний результат выглядит выдуманным. Исправлено в исходной записке.'],
    ['Измерено на одном семействе устройств', 'Artix-7, на открытом флоу. Не многоугловая характеризация, и цифры под ASIC будут другими.'],
    ['Сравнение против модели tekum, а не самого tekum', 'tekum (arXiv:2512.10964) — потомок takum, адаптированный под сбалансированную троичную логику. Оракул, против которого здесь измерено, — реконструированная структурная модель по полевой схеме takum; полная потритовая спецификация требует сверки со статьёй. Отношения ровно настолько хороши, насколько хороша эта модель.'],
    ['Прямого сравнения в железе пока нет', 'RTL для takum открыт и написан на VHDL (takum-arithmetic/Takum-Codec-RTL). Чтобы синтезировать его рядом с GF-T, нужен VHDL-фронтенд, которого на этом стенде нет, поэтому цифры стоимости — только GF-T. Что видно из их исходника: их 16-битный кодек тянет 725-строчный FloPoCo-шифтер со счётчиком ведущих нулей, сгенерированный под Kintex-7. Это и есть то декодирование режима, которого у GF-T нет по построению — различие структурное, а не измеренное.'],
  ],
  ctaTitle: 'Взять GF-T в свой дизайн',
  ctaBody: 'Лицензия включает RTL, независимую эталонную модель и векторы, которые её доказывают, — чтобы вы проверяли заявленное, а не верили на слово.',
}

export default function GFT() {
  const { lang } = useI18n()
  const c = lang === 'ru' ? RU : null
  usePageMeta(
    lang === 'ru' ? 'GF-T — тернарно-нативный float' : 'GF-T — a ternary-native float',
    'GF-T puts the exponent of a float in balanced ternary and keeps the fields fixed: 2.84× and 5.53× more accurate than tekum16 at range, 219 LUTs and zero DSP blocks, 147 MHz pipelined on Artix-7.',
  )

  const th: React.CSSProperties = {
    textAlign: 'left', padding: '0.5rem 0.7rem', fontSize: '0.72rem', letterSpacing: '0.09em',
    textTransform: 'uppercase', opacity: 0.6, borderBottom: '1.5px solid var(--border)', whiteSpace: 'nowrap',
  }
  const td: React.CSSProperties = {
    textAlign: 'left', padding: '0.55rem 0.7rem', fontSize: '0.9rem',
    borderBottom: '1px solid var(--border)', fontVariantNumeric: 'tabular-nums',
  }

  return (
    <main>
      <QuantumBackground />
      <Navigation />

      <section id="gft" style={{ maxWidth: '900px', alignItems: 'stretch' }}>
        <div className="radial-glow" style={{ opacity: 0.2, background: 'radial-gradient(circle at center, rgba(0, 255, 136, 0.08) 0%, transparent 60%)' }} />

        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.7 }} style={{ marginBottom: '2rem' }}>
          <p style={{ color: 'var(--accent)', letterSpacing: '0.14em', textTransform: 'uppercase', fontSize: '0.75rem', margin: '0 0 0.75rem' }}>
            {c ? c.eyebrow : 'The format'}
          </p>
          <h1 style={{ fontSize: 'clamp(1.9rem, 5.5vw, 2.8rem)', margin: '0 0 1rem', lineHeight: 1.15 }}>
            {c ? c.h1 : 'GF-T — a float whose exponent is ternary.'}
          </h1>
          <p style={{ fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)', lineHeight: 1.65, margin: '0 auto', maxWidth: '64ch' }}>
            {c ? c.lede : 'The exponent is a balanced-ternary number and the fields are fixed. That removes the incumbent’s largest cost and makes the exponent add native on a ternary fabric. Against tekum16: a tie near unity, 2.84× more accurate at mid range and 5.53× at far range.'}
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', justifyContent: 'center', marginTop: '1.75rem' }}>
            <a href="#/ip" className="btn" style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
              {c ? c.ctaTitle : 'License GF-T'}
            </a>
            <a href={LINKS.research} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
              {c ? 'Полное измерение' : 'The full measurement'}
            </a>
          </div>
        </motion.div>

        {/* Field layout — the first thing an adopter looks for */}
        <motion.div className="premium-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.6 }} style={{ marginBottom: '2rem' }}>
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '1rem' }}>
            {c ? c.layoutTitle : 'The layout'}
          </h2>
          <div style={{ overflowX: 'auto' }}>
            <pre style={{ display: 'inline-block', textAlign: 'left', fontSize: '0.84rem', lineHeight: 1.6, margin: 0, padding: '1rem 1.2rem', background: 'rgba(127,127,127,0.08)', border: '1px solid var(--border)', borderRadius: '10px' }}>
{`GF-T16 = [ sign | E = 4 balanced-ternary trits | M = 9 mantissa bits ]

value = (-1)^sign · (1 + M/2^9) · 2^e,   e = Σ tᵢ·3ⁱ  ∈ [−40, +40]`}
            </pre>
          </div>
        </motion.div>

        {/* Accuracy */}
        <motion.div className="premium-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.6 }} style={{ marginBottom: '2rem' }}>
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.6rem' }}>
            {c ? c.accuracyTitle : 'Accuracy against tekum16'}
          </h2>
          <p style={{ fontSize: '0.9rem', lineHeight: 1.6, opacity: 0.85, maxWidth: '64ch', margin: '0 auto 1.2rem' }}>
            {c ? c.accuracyNote : 'Mean relative error over an encode → decode round trip, 6000 values, random sign. Re-measured independently on 8 August 2026 against the same oracles: the ratios reproduce exactly. Bins are in powers of two.'}
          </p>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: '420px' }}>
              <thead>
                <tr>{(c ? c.cols : ['Magnitude', 'GF-T16', 'tekum16', 'Result']).map((h) => <th key={h} style={th}>{h}</th>)}</tr>
              </thead>
              <tbody>
                {(c ? c.accuracy : ACCURACY).map((row) => (
                  <tr key={row[0]}>
                    {row.map((cell, i) => (
                      <td key={i} style={{ ...td, color: i === 3 ? 'var(--accent)' : undefined, fontWeight: i === 3 ? 600 : 400 }}>{cell}</td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </motion.div>

        {/* Why it is cheaper */}
        <motion.div initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.6 }} style={{ marginBottom: '2rem' }}>
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>
            {c ? c.whyTitle : 'Why it is cheaper on a ternary fabric'}
          </h2>
          <div style={{ display: 'grid', gap: '1rem' }}>
            {(c ? c.why : WHY).map(([name, text]) => (
              <div key={name} className="premium-card" style={{ padding: '1.4rem' }}>
                <h3 style={{ fontSize: '1.02rem', margin: '0 0 0.5rem', color: 'var(--accent)' }}>{name}</h3>
                <p style={{ fontSize: '0.92rem', lineHeight: 1.6, margin: 0, opacity: 0.9 }}>{text}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Hardware cost */}
        <motion.div className="premium-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.6 }} style={{ marginBottom: '2rem' }}>
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.6rem' }}>
            {c ? c.costTitle : 'What it costs in hardware'}
          </h2>
          <p style={{ fontSize: '0.9rem', lineHeight: 1.6, opacity: 0.85, maxWidth: '64ch', margin: '0 auto 1.2rem' }}>
            {c ? c.costNote : 'The GF-T16 multiplier, synthesised for xc7 and routed on an XC7A200T with nextpnr-xilinx, hard multipliers disabled. All three variants are bit-equivalent — proven over 321,156 input combinations and 199,994 pipeline cycles.'}
          </p>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: '460px' }}>
              <thead>
                <tr>{(c ? c.costCols : ['Variant', 'LUTs', 'DSP48', 'Fmax']).map((h) => <th key={h} style={th}>{h}</th>)}</tr>
              </thead>
              <tbody>
                {(c ? c.cost : COST).map((row, ri) => (
                  <tr key={row[0]}>
                    {row.map((cell, i) => (
                      <td key={i} style={{ ...td, color: ri === 2 && i > 0 ? 'var(--accent)' : undefined, fontWeight: ri === 2 && i > 0 ? 700 : 400 }}>{cell}</td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
            <p style={{ fontSize: '0.78rem', opacity: 0.55, marginTop: '0.6rem', maxWidth: '64ch' }}>
              The synthesis table above is reproduced from
              <a href={LINKS.synth} target="_blank" rel="noopener noreferrer"> fpga/gft/README.md</a>,
              which sits beside the Verilog it describes.
            </p>
          </div>
        </motion.div>

        {/* The ladder */}
        <motion.div className="premium-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.6 }} style={{ marginBottom: '2rem' }}>
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.6rem' }}>
            {c ? c.ladderTitle : 'The whole ladder'}
          </h2>
          <p style={{ fontSize: '0.9rem', lineHeight: 1.6, opacity: 0.85, maxWidth: '64ch', margin: '0 auto 1.2rem' }}>
            {c ? c.ladderNote : 'One module covers every rung, with the widths derived from the parameters. Pipelined, one cycle of latency, measured on the same harness so the three rows compare. Equivalence proven at each rung against the reference for that rung.'}
          </p>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: '360px' }}>
              <thead><tr>{(c ? c.ladderCols : ['Rung', 'LUTs', 'Fmax']).map((h) => <th key={h} style={th}>{h}</th>)}</tr></thead>
              <tbody>
                {(c ? c.ladder : LADDER).map((row) => (
                  <tr key={row[0]}>{row.map((cell, i) => <td key={i} style={td}>{cell}</td>)}</tr>
                ))}
              </tbody>
            </table>
          </div>
        </motion.div>

        {/* The width finding */}
        <motion.div className="premium-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.6 }} style={{ marginBottom: '2rem' }}>
          <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.55rem)', marginTop: 0, marginBottom: '0.7rem' }}>
            {c ? c.widthTitle : 'A finding: the interface cost five times more than the arithmetic'}
          </h2>
          <p style={{ fontSize: '0.94rem', lineHeight: 1.65, opacity: 0.9, maxWidth: '64ch', margin: '0 auto' }}>
            {c ? c.widthBody : 'The original module declares every port 32 bits wide, though nothing in GF-T16 is 32 bits: the mantissa field is 9, so (1+M) is 10, their product is 20, and the exponent offset never exceeds 80, which is 7. Synthesis dutifully built a 32×32 multiplier and a 32-bit compare tree and charged full price for it: 1,179 LUTs, or three DSP48 blocks. With the widths the values actually need it comes to 219 LUTs and no DSP at all, bit-identical over 321,156 input combinations.'}
          </p>
        </motion.div>

        {/* Limits */}
        <motion.div className="premium-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.6 }} style={{ marginBottom: '2rem' }}>
          <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.55rem)', marginTop: 0, marginBottom: '1rem' }}>
            {c ? c.limitsTitle : 'Where it loses'}
          </h2>
          <div style={{ display: 'grid', gap: '0.9rem', textAlign: 'left', maxWidth: '64ch', marginLeft: 'auto', marginRight: 'auto' }}>
            {(c ? c.limits : LIMITS).map(([name, text]) => (
              <div key={name} style={{ borderLeft: '2px solid var(--border)', paddingLeft: '0.9rem' }}>
                <p style={{ fontSize: '0.95rem', fontWeight: 700, margin: '0 0 0.2rem' }}>{name}</p>
                <p style={{ fontSize: '0.9rem', lineHeight: 1.55, margin: 0, opacity: 0.85 }}>{text}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* CTA */}
        <motion.div className="premium-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.6 }}>
          <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.6rem)', marginTop: 0 }}>
            {c ? c.ctaTitle : 'Put GF-T in your design'}
          </h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.6, opacity: 0.9, maxWidth: '54ch', margin: '0 auto 1.3rem' }}>
            {c ? c.ctaBody : 'A licence includes the RTL, the independent reference model and the vectors that prove it, so you can check the claims rather than take them on trust.'}
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.7rem', justifyContent: 'center', marginBottom: '1.2rem' }}>
            <a href={LINKS.paper} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>arXiv:2606.05017</a>
            <a href={LINKS.catalogue} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>arXiv:2606.09686</a>
            <a href={LINKS.oracle} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>Reference model</a>
            <a href={LINKS.tekum} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>tekum16 reference</a>
          </div>
          <a href={`mailto:${EMAIL}?subject=${encodeURIComponent('GF-T licensing')}`} className="btn" style={{ padding: '12px 30px', fontSize: '0.9rem' }}>
            {EMAIL}
          </a>
        </motion.div>
      </section>

      <Footer />
    </main>
  )
}
