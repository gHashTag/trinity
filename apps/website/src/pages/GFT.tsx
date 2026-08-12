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
  takumRtl: 'https://github.com/takum-arithmetic/Takum-Codec-RTL',
  takumPaper: 'https://arxiv.org/abs/2404.18603',
  tekumPaper: 'https://arxiv.org/abs/2512.10964',
  rtl: 'https://github.com/gHashTag/trinity/blob/main/fpga/gft/gft_mul_w.v',
  synth: 'https://github.com/gHashTag/trinity/blob/main/fpga/gft/README.md',
  research: 'https://github.com/gHashTag/trinity-fpga/blob/main/research/GFT16_BEATS_TEKUM16_2026-08-05.md',
}

const EMAIL = 'admin@t27.ai'

// The accuracy table this page used to carry — 2.84× and 5.53× against
// tekum16 — is withdrawn. The oracle labelled tekum decoded all 65,536
// sixteen-bit codes identically to the takum oracle, so the comparison was
// never against tekum. What replaces it is the taper diagnostic (Theorem 2),
// which is a measurement of the incumbent's own published behaviour and does
// not depend on any oracle of ours being distinct from anyone else's.
/* Столбцы этой таблицы — Format / Declared M / Recovered M_eff / Slope.
   До 13.08.2026 английские подписи над ней читались «Accuracy against tekum16»
   с колонками GF-T16 / tekum16: остаток отозванного сравнения, разъехавшийся
   с данными. Русская версия уже была честной, а английская — язык по умолчанию.
   Заголовок, пояснение и шапка обязаны меняться вместе с этим массивом. */
const ACCURACY: [string, string, string, string][] = [
  ['TNF16 (fixed fields)', '9', '8.99 / 9.01', '0 — flat'],
  ['GF16 (fixed fields)', '9', '8.99', '0 — flat'],
  ['bfloat16 (fixed fields)', '7', '7.04', '0 — flat'],
  ['takum16 (tapered)', 'variable', '—', '−0.113 bit / binade'],
  ['posit16 (tapered)', 'variable', '—', '−0.254 bit / binade'],
]

const RETRACTED = {
  h: 'What this page used to claim, and why it is gone',
  b: 'Until August 2026 this page reported GF-T as 2.84× and 5.53× more accurate than tekum16 at range. That is withdrawn. The oracle labelled tekum decoded all 65,536 sixteen-bit codes identically to the takum oracle, so the numbers were a comparison with takum wearing the wrong name. Against takum the honest figures are 2.1× at sixteen bits and an exact 2.6× at thirty-two. A real comparison against tekum (arXiv:2512.10964) has not been made, and nothing here should be read as one.',
}

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
  ['No regime decode', 'Any tapered format — posit, takum, tekum — pays for a variable-length regime field on every fabric: find it, compute its length, barrel-shift the significand into place. GF-T has fixed fields, so that cost is a bit slice. Measured consequence: all fourteen fixed-field decoders in the bench sit above all three tapered ones in frequency, and the worst fixed-field format leads the best tapered one by 1.43×.'],
  ['The exponent is balanced ternary', 'Four trits, so 3⁴ = 81 exponent values. On a ternary fabric the exponent add is native: no binary carry, no base conversion. On the binary FPGA everything here was measured on, that property neither wins nor loses — the ternary claim is architectural and is labelled as such.'],
  ['Precision does not taper', 'Nine mantissa bits at every magnitude. The diagnostic above recovers the declared width to 0.01 of a bit for every fixed-field format and separates the tapered ones cleanly by their slope. Flatness on a 76-binade workload: 1.05–1.07, so at most 7% spread.'],
]

const LIMITS = [
  ['The range is bounded, and that is the trade', 'GF-T16 reaches ±40 in powers of two — roughly ±12 decades. A tapered regime field is unbounded, so beyond that point GF-T16 overflows and takum keeps working. Fixed fields buy the cheap datapath and the uniform precision; the price is range, and most ML and DSP workloads never reach it. Theorem 6 makes this a dichotomy rather than a preference: constant precision and unbounded range cannot both hold.'],
  ['It is not the most accurate format at this width', 'posit16 and binary16 are ahead near unity, and binary formats are ahead outright at 32 bits. A reference format does not have to win those comparisons — it has to be the thing they are measured against.'],
  ['Measured on one device family', 'Artix-7, on the open flow. Not multi-corner characterisation, and the ASIC numbers will differ.'],
  ['The comparison is against takum, not tekum', 'The oracle this site once labelled tekum decoded all 65,536 sixteen-bit codes identically to the takum oracle, so every ratio built on it was a takum comparison under the wrong name. Withdrawn rather than rescaled. tekum (arXiv:2512.10964) remains the nearest published work and the nearest open question.'],
  ['The fabric where the ternary exponent pays is not for sale', 'A field of E trits covers 3^E values, and 3^E never divides a power of two, so packing it into a binary machine loses the remainder — 25.0% at four bits, 15.6% at six and eight, 5.1% at sixteen. Ternary lost to binary three separate times in our own measurements. What is contributed is the condition under which the 68-year-old radix argument applies, not the argument itself.'],
  ['No head-to-head in hardware yet', 'takum’s RTL is public and is VHDL (takum-arithmetic/Takum-Codec-RTL). Synthesising it alongside GF-T needs a VHDL front end this bench does not have, so the cost figures here are GF-T’s own. What can be said from their source: their 16-bit codec pulls in a 725-line FloPoCo leading-zero-counter and barrel shifter, generated for a Kintex-7. That is the regime decode GF-T’s fixed fields do not have — a structural difference, not a measured one.'],
]

const RU = {
  eyebrow: 'Формат',
  h1: 'GF-T — float, у которого экспонента тернарная.',
  lede: 'Экспонента — сбалансированное тернарное число, поля фиксированы. Декодирования режима нет — извлечение полей есть битовый срез, а на тернарной фабрике сложение экспонент нативно. Против takum16 — в 2.1 раза меньше средней относительной ошибки, против takum32 — точно в 2.6 раза.',
  layoutTitle: 'Как устроен',
  retractedH: 'Что здесь стояло раньше и почему снято',
  retractedB: 'До августа 2026 на этой странице стояло, что GF-T в 2.84 и 5.53 раза точнее tekum16 на дальности. Заявление отозвано. Оракул, помеченный tekum, декодировал все 65 536 шестнадцатибитных кодов идентично takum-оракулу, то есть цифры были сравнением с takum под чужим именем. Честные числа против takum — 2.1× на шестнадцати битах и точно 2.6× на тридцати двух. Настоящего сравнения с tekum (arXiv:2512.10964) не сделано, и ничто здесь не следует читать как такое сравнение.',
  accuracyTitle: 'Диагностика сужения: восстановленная ширина значащей',
  accuracyNote: 'Теорема 2: эффективная ширина мантиссы M_eff постоянна по бинадам тогда и только тогда, когда формат держит постоянную значащую и не исчерпал диапазон. Инструмент восстанавливает объявленную ширину с точностью 0.01 бита для каждого фиксированно-полевого формата и разделяет tapered-форматы по наклону. Здесь измеряется опубликованное поведение самих конкурентов, а не наш оракул против их оракула.',
  cols: ['Формат', 'Объявлено M', 'Восстановлено M_eff', 'Наклон'],
  accuracy: [
    ['TNF16 (фиксированные поля)', '9', '8.99 / 9.01', '0 — плоско'],
    ['GF16 (фиксированные поля)', '9', '8.99', '0 — плоско'],
    ['bfloat16 (фиксированные поля)', '7', '7.04', '0 — плоско'],
    ['takum16 (tapered)', 'переменная', '—', '−0.113 бита / бинада'],
    ['posit16 (tapered)', 'переменная', '—', '−0.254 бита / бинада'],
  ] as [string, string, string, string][],
  whyTitle: 'Почему фиксированные поля дешевле',
  why: [
    ['Нет декодирования режима', 'Любой tapered-формат — posit, takum, tekum — платит за поле режима переменной длины на любой фабрике: найти его, посчитать длину, выровнять значащую барабанным сдвигом. У GF-T это битовый срез. Измеренное следствие: все четырнадцать фиксированно-полевых декодеров на стенде выше всех трёх tapered по частоте, а худший фиксированный ведёт лучший tapered в 1.43 раза.'],
    ['Экспонента — сбалансированная тернарная', 'Четыре трита, то есть 3⁴ = 81 значение экспоненты. На тернарной фабрике сложение экспонент нативно. На бинарной FPGA, где всё здесь измерено, это свойство ни выигрывает, ни проигрывает — тернарное заявление архитектурное и так и помечено.'],
    ['Точность не сужается', 'Девять бит мантиссы на любой величине. Ровность на нагрузке в 76 бинад: 1.05–1.07, то есть разброс не больше 7%.'],
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
    ['Диапазон ограничен — и это плата', 'GF-T16 доходит до ±40 в степенях двойки, примерно ±12 декад. У tapered-формата поле режима не ограничено, поэтому дальше GF-T16 переполняется, а takum продолжает работать. Теорема 6 делает это дихотомией, а не предпочтением: постоянная точность и неограниченный диапазон несовместны.'],
    ['Это не самый точный формат на данной ширине', 'posit16 и binary16 впереди около единицы, а на 32 битах бинарные форматы впереди прямо. Референсный формат не обязан выигрывать эти сравнения — он обязан быть тем, относительно чего их меряют.'],
    ['Измерено на одном семействе устройств', 'Artix-7, на открытом флоу. Не многоугловая характеризация, и цифры под ASIC будут другими.'],
    ['Сравнение идёт против takum, а не tekum', 'Оракул, который на этом сайте был помечен tekum, декодировал все 65 536 шестнадцатибитных кодов идентично takum-оракулу, то есть любое отношение на его основе было сравнением с takum под чужим именем. Отозвано, а не пересчитано. tekum (arXiv:2512.10964) остаётся ближайшей опубликованной работой и ближайшим открытым вопросом.'],
    ['Фабрика, на которой тернарная экспонента окупается, не продаётся', 'Поле из E тритов покрывает 3^E значений, а 3^E никогда не делит степень двойки, поэтому укладка в бинарную машину теряет остаток: 25.0% на четырёх битах, 15.6% на шести и восьми, 5.1% на шестнадцати. Троичное проиграло бинарному три раза независимо в наших же измерениях. Вклад — условие, при котором 68-летний аргумент применим, а не сам аргумент.'],
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
    'GF-T puts the exponent of a float in balanced ternary and keeps the fields fixed: no regime decode, a mantissa that does not taper, 219 LUTs and zero DSP blocks, 147 MHz pipelined on Artix-7. Measured against takum, not tekum — the earlier tekum figures are withdrawn.',
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
            {c ? c.lede : 'The exponent is a balanced-ternary number and the fields are fixed. There is no regime to decode — extraction is a bit slice — and on a ternary fabric the exponent add is native. Against takum16: 2.1× lower mean relative error; against takum32, an exact 2.6×.'}
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', justifyContent: 'center', marginTop: '1.75rem' }}>
            <a href="#/ip" className="btn" style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
              {c ? c.ctaTitle : 'License GF-T'}
            </a>
            <a href={LINKS.paper} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
              {c ? 'Статья и эталонная модель' : 'The paper and the reference model'}
            </a>
          </div>
        </motion.div>

        {/* The retraction, stated before anything it used to support */}
        <motion.div className="premium-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.6 }} style={{ marginBottom: '2rem', borderLeft: '3px solid var(--accent)' }}>
          <h2 style={{ fontSize: 'clamp(1.1rem, 3vw, 1.4rem)', marginTop: 0, marginBottom: '0.7rem' }}>
            {c ? c.retractedH : RETRACTED.h}
          </h2>
          <p style={{ fontSize: '0.92rem', lineHeight: 1.65, opacity: 0.9, maxWidth: '64ch', margin: 0 }}>
            {c ? c.retractedB : RETRACTED.b}
          </p>
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
            {c ? c.accuracyTitle : 'Taper diagnostic: recovered significand width'}
          </h2>
          <p style={{ fontSize: '0.9rem', lineHeight: 1.6, opacity: 0.85, maxWidth: '64ch', margin: '0 auto 1.2rem' }}>
            {c ? c.accuracyNote : 'Theorem 2: effective mantissa width M_eff is constant across binades iff the format holds a constant significand and has not exhausted its range. The tool recovers the declared width to 0.01 of a bit for every fixed-field format and separates tapered formats by their slope. What is measured here is the competitors\u2019 own published behaviour, not our oracle against theirs.'}
          </p>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: '420px' }}>
              <thead>
                <tr>{(c ? c.cols : ['Format', 'Declared M', 'Recovered M_eff', 'Slope']).map((h) => <th key={h} style={th}>{h}</th>)}</tr>
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
            <a href={LINKS.takumRtl} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>takum codec RTL</a>
            <a href={LINKS.tekumPaper} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>tekum — arXiv:2512.10964</a>
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
