"use client";
import { motion } from 'framer-motion'
import { usePageMeta } from '../hooks/usePageMeta'
import { useI18n } from '../i18n/context'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'

const LINKS = {
  github: 'https://github.com/gHashTag',
  arxiv1: 'https://arxiv.org/abs/2606.05017',
  arxiv2: 'https://arxiv.org/abs/2606.09686',
  sampleReport: 'https://github.com/gHashTag/trinity/blob/main/docs/verification/SAMPLE-REPORT.md',
  triNet: 'https://github.com/gHashTag/tri-net',
  t27: 'https://github.com/gHashTag/t27',
}

const RESULTS = [
  {
    metric: '2.84× / 5.53×',
    title: 'GF-T beats tekum16 on tekum16\u2019s own ground',
    body: 'A float whose exponent is a balanced-ternary number and whose fields are fixed. That removes tekum16\u2019s largest cost \u2014 regime decode \u2014 and makes the exponent add native on a ternary fabric, while a uniform 9-bit mantissa holds precision where tekum16 tapers to four. Mean relative error against tekum16: a tie near unity (0.92\u00d7), 2.84\u00d7 lower at |e| 8\u201320, 5.53\u00d7 lower at |e| 20\u201338. Range is bounded at \u00b140 in powers of two, where tekum16\u2019s regime is not \u2014 that is the trade.',
    how: 'Re-measured independently against the same oracles on 8 August 2026; the ratios reproduce exactly.',
  },
  {
    metric: '4.125 vs 4.250 bits',
    title: 'A four-bit geometric scale strictly dominates MXFP4’s eight-bit E8M0',
    body: 'MXFP4 spends eight bits on the shared exponent of every 32-weight block — 0.25 bits per weight. A geometric grid of powers of φ needs four for the same job. Measured end to end at 4-bit elements: φᵏ 4b/32 costs 4.125 bits per weight and reaches perplexity 21.3545 on SmolLM2 and 14.8512 on Qwen, against MXFP4’s 4.250 bits and 22.4998 / 14.9447. Cheaper and more accurate on both models — domination in both coordinates, not a trade. Behind it is an inequality rather than a fit: for scales read as multipliers, a geometric grid beats a float grid at every width, the advantage rising to 1/ln 2 = 1.4427.',
    how: 'Perplexity on two checkpoints, fp32 baselines 14.4874 and 12.2277 verified before any comparison. An ICLR 2026 paper independently names power-of-two scale quantisation as MXFP4’s accuracy defect — the same diagnosis, reached separately.',
  },
  {
    metric: '36.4 MHz · 3.6× pipelined',
    title: 'GF16 4×4 matmul on Artix-7',
    body: 'A 4×4 matrix multiplier over my own GF16 format. As written it is purely combinational — no registers, so no clock and no frequency belongs to it. Pipelined into three stages it closes at 36.36 MHz post-route on an XC7A200T for the whole 4×4, against 9.97 MHz for the same core with a single register stage: 3.6× for a latency of three cycles and one result per cycle. A single four-term dot product reaches 58.49 MHz, up from 18.83, and bit-identical to the original over 59,993 cycles of random and special-case operands. Fabric-only mapping needs no hard multipliers at all.',
    how: 'Post-route on XC7A200T, nextpnr-xilinx, 8 August 2026. Equivalence proven, not assumed.',
  },
  {
    metric: '100% held-out',
    title: 'A neural network that trains itself on the FPGA',
    body: 'Forward pass, gradient and weight update all in RTL, with no host in the loop. A 2-layer ReLU network learns XOR on the chip itself, 4 of 4 correct.',
    how: 'Every node bit-exact from specification through to silicon.',
  },
  {
    metric: 'SKY130',
    title: 'Tape-out through Tiny Tapeout',
    body: 'The same source that runs on the FPGA went to an open ASIC process: GDS produced, gate-level test passed, precheck passed.',
    how: 'The full path from an arXiv paper to a fabricated design.',
  },

  {
    metric: 'Over the air',
    title: 'tri-net — a full ternary network stack',
    body: '133 formal specifications: GF16 physical layer, BPSK modem on AD9361, ETX mesh routing, AEAD crypto (ChaCha20-Poly1305 / X25519). Text and images carried between physically separate boards.',
    how: 'Device to device on real radios, with no infrastructure in between.',
  },
  {
    metric: '83 formats',
    title: 'A conformance catalogue anyone can check against',
    body: 'Bit-exact test vectors for FP8, BF16, MXFP4 and microscaling formats — a vendor-neutral reference for verifying low-precision arithmetic.',
    how: 'Published openly so the vectors can be used against any implementation.',
  },
]

const METHOD = [
  ['Independent model, not a mirror', 'The reference model is written from the specification, never from the RTL. A testbench derived from the same assumptions as the design will agree with the design even when both are wrong.'],
  ['Per-stage vectors', 'Known-answer vectors at every pipeline stage, so a regression points at the stage that broke instead of at the top level.'],
  ['Hardware replay', 'The same vectors run again on the physical board. Simulation agreement does not prove silicon agreement — synthesis, place-and-route and timing all get a vote.'],
  ['Open toolchain', 'Yosys, nextpnr-xilinx, prjxray, openFPGALoader, iverilog. No proprietary licence stands between a claim here and someone reproducing it.'],
]

const NOT_CLAIMS = [
  'Competition entries are entries. A DARPA CLARA submission and an OpenAI Parameter Golf entry are exactly that — submitted work, not awarded contracts or won prizes.',
  'Measurements come from one device family, a Xilinx Artix-7. They are not multi-corner characterisation and do not claim to be.',
  'The on-chip training result is a proven primitive at small scale — a real network learning on real silicon, not a production training accelerator.',
  'The scale result above is not a claim that we beat MXFP4 overall. A block format has two fields, and the scale is the one we win. On the element field we lose, measured: at 4 bits MXFP4 reaches 21.9397 perplexity against 36.7214 for our TNF4, and at 6 bits MXFP6 reaches 14.7269 against 18.0275. Three attacks on that axis failed and a Lloyd-Max bound says a fourth is not warranted. Both statements are about the same format and belong together.',
  'The element-axis comparison was measured on unrotated weights, while the 2026 state of the art applies a Hadamard rotation first. Our own measurement puts the median excess-kurtosis change from rotation at −1.601, so the distribution being quantised in a current deployment is not the one measured. That scopes the result; it does not soften it, since rotation helps whatever is quantised afterwards and nothing suggests it favours ours.',
  'Anything estimated rather than measured is labelled as estimated, here and in every report I send.',
  'This page previously reported 323 MHz and 41.2 GOPS for the GF16 matmul. Re-checking the RTL on 8 August 2026 showed the block holds no registers in any of its nine copies in my repositories, so it has no clock and no frequency can belong to it. The figure is withdrawn rather than explained away, and the synthesis numbers above replace it.',
]

// Russian copy. Other locales fall back to English rather than showing gaps.
const RU = {
  eyebrow: 'Измеренные доказательства',
  h1: 'Каждая цифра здесь измерена.',
  lede: 'Заявления про железо дёшево делать и трудно проверять, поэтому здесь собраны результаты, стоящие за всем остальным на сайте: что построено, что оно показало и как это проверено. Где перед вами заявка, а не победа, и прототип, а не продукт — так и написано.',
  ctaReport: 'Прочитать отчёт о верификации',
  ctaSource: 'Посмотреть исходники',
  resultsTitle: 'Результаты',
  results: [
    { metric: '2.84× / 5.53×', title: 'GF-T обходит tekum16 на его же территории', body: 'Float, у которого экспонента — сбалансированное тернарное число, а поля фиксированы. Это убирает главную статью расхода tekum16 — декодирование режима — и делает сложение экспонент нативным на тернарной фабрике, а равномерные 9 бит мантиссы держат точность там, где tekum16 сужается до четырёх. Средняя относительная ошибка против tekum16: ничья у единицы (0.92×), в 2.84 раза меньше при |e| 8–20, в 5.53 раза меньше при |e| 20–38. Диапазон ограничен ±40 в степенях двойки, а у режима tekum16 предела нет — это и есть плата.', how: 'Перемерено независимо по тем же оракулам 8 августа 2026 — отношения воспроизводятся точно.' },
    { metric: '4.125 против 4.250 бита', title: 'Четырёхбитная геометрическая сетка масштаба строго доминирует восьмибитную E8M0 у MXFP4', body: 'MXFP4 тратит восемь бит на общую экспоненту каждого блока из 32 весов — 0.25 бита на вес. Геометрической сетке из степеней φ на ту же работу хватает четырёх. Замер целиком, при четырёхбитных элементах: φᵏ 4b/32 стоит 4.125 бита на вес и даёт перплексию 21.3545 на SmolLM2 и 14.8512 на Qwen, против 4.250 бита и 22.4998 / 14.9447 у MXFP4. Дешевле и точнее на обеих моделях — доминирование по обеим координатам, а не размен. За этим стоит неравенство, а не подгонка: для масштабов, читаемых как множители, геометрическая сетка бьёт float-сетку на любой ширине, и выигрыш растёт до 1/ln 2 = 1.4427.', how: 'Перплексия на двух чекпойнтах, базовые fp32 14.4874 и 12.2277 проверены до любого сравнения. Статья ICLR 2026 независимо называет квантование масштаба по степеням двойки дефектом точности MXFP4 — тот же диагноз, поставленный отдельно.' },
    { metric: '36.4 МГц · 3.6× от конвейера', title: 'Матричный умножитель GF16 4×4 на Artix-7', body: 'Матричный умножитель 4×4 над собственным форматом GF16. Как написан — чисто комбинационный: регистров нет, тактовой нет, частота ему не принадлежит. Разрезанный на три ступени конвейера, он закрывается на 36.36 МГц post-route на XC7A200T целиком, против 9.97 МГц у того же ядра с одной регистровой ступенью: рост 3.6× за латентность три такта и результат каждый такт. Отдельное четырёхчленное скалярное произведение доходит до 58.49 МГц против 18.83, и побитово идентично исходному на 59 993 циклах случайных и специальных операндов. В логику укладывается вообще без аппаратных умножителей.', how: 'Post-route на XC7A200T, nextpnr-xilinx, 8 августа 2026. Эквивалентность доказана, а не предположена.' },
    { metric: '100% отложенная выборка', title: 'Нейросеть, обучающаяся прямо на FPGA', body: 'Прямой проход, градиент и обновление весов — всё в RTL, без хоста в контуре. Двухслойная ReLU-сеть учит XOR на самом кристалле, 4 из 4.', how: 'Каждый узел побитово — от спецификации до кремния.' },
    { metric: 'SKY130', title: 'Тейпаут через Tiny Tapeout', body: 'Тот же исходник, что работает на FPGA, ушёл в открытый ASIC-процесс: GDS получен, тест на уровне вентилей пройден, precheck пройден.', how: 'Полный путь от статьи на arXiv до изготовленного дизайна.' },
    
    { metric: 'По эфиру', title: 'tri-net — полный тернарный сетевой стек', body: '133 формальные спецификации: физический уровень GF16, BPSK-модем на AD9361, mesh-маршрутизация ETX, AEAD-криптография (ChaCha20-Poly1305 / X25519). Текст и изображения передаются между физически разными платами.', how: 'От устройства к устройству на настоящих радио, без инфраструктуры между ними.' },
    { metric: '83 формата', title: 'Каталог соответствия, с которым может свериться любой', body: 'Побитовые тест-векторы для FP8, BF16, MXFP4 и microscaling-форматов — вендоронезависимый эталон для проверки арифметики низкой разрядности.', how: 'Опубликованы открыто, чтобы векторы можно было применить к любой реализации.' },
  ],
  methodTitle: 'Как всё это проверяется',
  method: [
    ['Независимая модель, а не зеркало', 'Эталонная модель пишется от спецификации, никогда от RTL. Тестбенч, выведенный из тех же предпосылок, что и дизайн, согласится с ним даже когда оба неправы.'],
    ['Векторы по ступеням', 'Векторы с известным ответом на каждой ступени конвейера — регрессия указывает на сломавшуюся ступень, а не на верхний уровень.'],
    ['Повтор на железе', 'Те же векторы снова прогоняются на физической плате. Согласие в симуляции не доказывает согласия на кремнии: синтез, разводка и тайминг тоже имеют голос.'],
    ['Открытый тулчейн', 'Yosys, nextpnr-xilinx, prjxray, openFPGALoader, iverilog. Между заявлением здесь и его воспроизведением никто не ставит проприетарную лицензию.'],
  ],
  notTitle: 'Чем эти результаты не являются',
  not: [
    'Заявка на конкурс — это заявка. Подача в DARPA CLARA и участие в OpenAI Parameter Golf — именно это: отправленная работа, а не выигранные контракты или взятые призы.',
    'Измерения сняты на одном семействе устройств, Xilinx Artix-7. Это не многоугловая характеризация и не претендует ею быть.',
    'Обучение на кристалле — доказанный примитив малого масштаба: настоящая сеть, обучающаяся на настоящем кремнии, а не продакшн-ускоритель обучения.',
    'Результат про масштаб выше — не заявление, что мы обходим MXFP4 в целом. У блочного формата два поля, и масштаб — то, где мы выигрываем. На поле элемента мы проигрываем, и это измерено: при 4 битах MXFP4 даёт перплексию 21.9397 против 36.7214 у нашего TNF4, при 6 битах MXFP6 — 14.7269 против 18.0275. Три захода на эту ось провалились, а граница Ллойда–Макса говорит, что четвёртый не оправдан. Оба утверждения — об одном и том же формате и идут вместе.',
    'Сравнение по оси элемента снято на неповёрнутых весах, тогда как уровень 2026 года сначала применяет преобразование Адамара. Наш собственный замер даёт медианное изменение избыточного куртозиса от поворота −1.601, то есть распределение, которое квантуется в сегодняшнем развёртывании, — не то, что мерилось. Это ограничивает область результата, но не смягчает его: поворот помогает всему, что квантуется после него, и ничто не указывает, что нашему формату он помогает сильнее.',
    'Всё, что оценено, а не измерено, помечено как оценка — и здесь, и в каждом отчёте, который я отправляю.',
    'На этой странице раньше стояли 323 МГц и 41.2 GOPS для матмула GF16. Перепроверка RTL 8 августа 2026 показала, что во всех девяти копиях в моих репозиториях в этом блоке нет регистров — а значит нет тактовой, и никакая частота ему принадлежать не может. Цифра снята, а не объяснена, и заменена приведёнными выше числами синтеза.',
  ],
  finalTitle: 'Проверьте сами',
  finalLede: 'Статьи, исходники и полный пример отчёта — всё открыто. В этом и смысл: заявление, которое нельзя проверить, — просто предложение.',
}

export default function Proof() {
  const { lang } = useI18n()
  const c = lang === 'ru' ? RU : null
  usePageMeta("Measured evidence", "Every hardware claim on this site with the measurement behind it — and a plain statement of what these results are not.")
  return (
    <main>
      <QuantumBackground />
      <Navigation />

      <section id="proof" style={{ maxWidth: '900px', alignItems: 'stretch' }}>
        <div className="radial-glow" style={{ opacity: 0.2, background: 'radial-gradient(circle at center, rgba(0, 255, 136, 0.08) 0%, transparent 60%)' }} />

        {/* Hero */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7 }}
          style={{ marginBottom: '2rem' }}
        >
          <p style={{ color: 'var(--accent)', letterSpacing: '0.14em', textTransform: 'uppercase', fontSize: '0.75rem', margin: '0 0 0.75rem' }}>
            Evidence
          </p>
          <h1 style={{ fontSize: 'clamp(1.9rem, 5.5vw, 2.8rem)', margin: '0 0 1rem', lineHeight: 1.15 }}>
            {c ? c.h1 : 'Every number here was measured.'}
          </h1>
          <p style={{ fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)', lineHeight: 1.65, margin: 0, maxWidth: '62ch', marginLeft: 'auto', marginRight: 'auto' }}>
            {c ? c.lede : (
              <>
                Hardware claims are cheap to make and hard to check, so this page collects the results
                behind everything else on this site — what was built, what it measured, and how it was
                verified. Where something is a submission rather than a win, or a prototype rather than
                a product, it says so.
              </>
            )}
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', marginTop: '1.75rem' }}>
            <motion.a href={LINKS.sampleReport} target="_blank" rel="noopener noreferrer" className="btn" whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
              {c ? c.ctaReport : 'Read a verification report'}
            </motion.a>
            <motion.a href={LINKS.github} target="_blank" rel="noopener noreferrer" className="btn secondary" whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
              {c ? c.ctaSource : 'See the source'}
            </motion.a>
          </div>
        </motion.div>

        {/* Results */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>{c ? c.resultsTitle : 'Results'}</h2>
          <div style={{ display: 'grid', gap: '1rem' }}>
            {(c ? c.results : RESULTS).map((r) => (
              <div key={r.title} className="premium-card" style={{ padding: '1.6rem' }}>
                <p style={{ fontSize: '1.35rem', fontWeight: 700, color: 'var(--accent)', margin: '0 0 0.4rem', fontVariantNumeric: 'tabular-nums' }}>{r.metric}</p>
                <h3 style={{ fontSize: '1.05rem', margin: '0 0 0.55rem' }}>{r.title}</h3>
                <p style={{ fontSize: '0.93rem', lineHeight: 1.6, margin: '0 0 0.7rem', opacity: 0.9 }}>{r.body}</p>
                <p style={{ fontSize: '0.85rem', lineHeight: 1.55, margin: 0, opacity: 0.75, borderLeft: '2px solid var(--accent)', paddingLeft: '0.85rem' }}>{r.how}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Method */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '1rem' }}>{c ? c.methodTitle : 'How any of this is checked'}</h2>
          <div style={{ display: 'grid', gap: '1.1rem' }}>
            {(c ? c.method : METHOD).map(([t, b]) => (
              <div key={t}>
                <h3 style={{ fontSize: '1rem', margin: '0 0 0.4rem', color: 'var(--accent)' }}>{t}</h3>
                <p style={{ fontSize: '0.91rem', lineHeight: 1.6, margin: 0, opacity: 0.88 }}>{b}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Honesty */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.55rem)', marginTop: 0, marginBottom: '0.8rem' }}>{c ? c.notTitle : 'What these results are not'}</h2>
          <ul style={{ margin: 0, paddingLeft: '1.25rem', display: 'grid', gap: '0.65rem' }}>
            {(c ? c.not : NOT_CLAIMS).map((n) => (
              <li key={n} style={{ fontSize: '0.91rem', lineHeight: 1.6, opacity: 0.88 }}>{n}</li>
            ))}
          </ul>
        </motion.div>

        {/* Sources */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ textAlign: 'center' }}
        >
          <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.6rem)', marginTop: 0 }}>{c ? c.finalTitle : 'Check it yourself'}</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.6, opacity: 0.9, maxWidth: '52ch', margin: '0 auto 1.5rem' }}>
            {c ? c.finalLede : (
              <>
                The papers, the source and a full example report are all public. That is the point —
                a claim you cannot verify is just a sentence.
              </>
            )}
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', justifyContent: 'center' }}>
            <a href={LINKS.arxiv1} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '10px 22px', fontSize: '0.82rem' }}>arXiv:2606.05017</a>
            <a href={LINKS.arxiv2} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '10px 22px', fontSize: '0.82rem' }}>arXiv:2606.09686</a>
            <a href={LINKS.t27} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '10px 22px', fontSize: '0.82rem' }}>t27</a>
            <a href={LINKS.triNet} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '10px 22px', fontSize: '0.82rem' }}>tri-net</a>
          </div>
        </motion.div>
      </section>

      <Footer />
    </main>
  )
}
