"use client";
import { motion } from 'framer-motion'
import { usePageMeta } from '../hooks/usePageMeta'
import { useI18n } from '../i18n/context'
import VerificationDiagram from '../components/VerificationDiagram'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'
import { THEOREMS, SCIENCE_INTRO_EN, SCIENCE_INTRO_RU } from '../data/verificationScience'

const REQUEST_URL = 'https://github.com/gHashTag/trinity/issues/new?template=verification-request.yml'

const CONTACT = {
  email: 'admin@t27.ai',
  github: 'https://github.com/gHashTag',
  arxiv1: 'https://arxiv.org/abs/2606.05017',
  arxiv2: 'https://arxiv.org/abs/2606.09686',
  sampleReport: 'https://github.com/gHashTag/trinity/blob/main/docs/verification/SAMPLE-REPORT.md',
}

// A prefilled body turns a blank email into a form: the client answers four
// questions, and the first reply can already be a quote instead of a round of
// "could you also tell me...".
const INTAKE_BODY = [
  'Hi Dmitrii,',
  '',
  '1) What the design does (one or two lines):',
  '',
  '2) What "correct" means for it — reference outputs, an algorithm, a paper, or a spec:',
  '',
  '3) Target frequency, and any constraints that matter:',
  '',
  '4) Where the sources are (repo link, or say if you need an NDA first):',
  '',
  'Deadline, if there is one:',
  '',
  'Thanks,',
].join('\n')

const mailto = (subject: string) =>
  `mailto:${CONTACT.email}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(INTAKE_BODY)}`

const PRACTICALS = [
  {
    title: 'Turnaround',
    body: 'A single core is typically back within 3–5 working days. Larger blocks are quoted with a date before any work starts — if a deadline is tight, say so in the first message.',
  },
  {
    title: 'Your RTL stays yours',
    body: 'Sources are used only to produce your report, are never published or reused, and are deleted on request once delivered. Happy to sign your NDA before you send anything.',
  },
  {
    title: 'Payment',
    body: 'Invoice in USD or EUR, or stablecoin — whichever is simpler for you. Payment on delivery of the report; the first module is free, so nothing is owed until you have seen the work.',
  },
  {
    title: 'What I need from you',
    body: 'The RTL or specification, a definition of correct behaviour (reference outputs, an algorithm, or a paper), the target frequency, and any constraints. That is usually enough to start.',
  },
]

const LIMITS = [
  'Device is a Xilinx Artix-7 XC7A200T — designs that exceed it, or need transceivers and hard IP the board does not expose, cannot be measured here.',
  'Encrypted netlists and vendor-encrypted IP cannot go through an open-source flow.',
  'This is functional and timing verification on one device — not full sign-off, DFT, or multi-corner characterisation.',
  'Anything estimated rather than measured is labelled as such. Nothing is reported as measured unless it was measured.',
]

const DELIVERABLES = [
  {
    title: 'Bit-exact conformance',
    body: 'Every node of your datapath checked against an independent reference model with KAT vectors — divergence between spec and RTL surfaces before synthesis, not after tape-out.',
  },
  {
    title: 'Timing & resources',
    body: 'Achieved frequency, slack, LUT/FF/BRAM/DSP usage, and a latch-free check — measured on a live Xilinx Artix-7, not estimated.',
  },
  {
    title: 'Reproducible artefacts',
    body: 'Bitstream, test vectors, logs and the exact open-source toolchain versions, so anyone can re-run the whole flow themselves.',
  },
  {
    title: 'No vendor lock-in',
    body: 'Yosys, nextpnr-xilinx, prjxray, openFPGALoader, iverilog. Nothing in the report depends on a proprietary licence you would need to buy.',
  },
]

const TIERS = [
  { name: 'Single core', price: '$300', body: 'One module or IP core: bit-exact check, timing, resources, report.' },
  { name: 'Block', price: '$800', body: 'A full block with multiple cores, integration checks and a written analysis.' },
  { name: 'Tape-out ready', price: '$2 000', body: 'Full verification pass, latch-free/timing sign-off and a review against your target process.' },
  { name: 'Retainer', price: '$1–3k / mo', body: 'Continuous regression on real hardware for your repository, on every release.' },
]

const PROOF = [
  ['32,252 LUT · 0 DSP48', 'A GF16 4×4 matmul that maps into Artix-7 fabric with no hard multipliers at all — 21,223 LUTs if the 64 DSP blocks are allowed. Combinational, 0 latches.'],
  ['100% held-out', 'A neural network that trains itself on the FPGA — bit-exact from spec to silicon.'],
  ['SKY130 silicon', 'Taped out through Tiny Tapeout: GDS, gate-level test and precheck passed.'],
  ['83 formats', 'Published bit-exact conformance vectors for FP8, BF16, MXFP4 and microscaling.'],
]

const STEPS = [
  'You send RTL or a specification, and say what "correct" means for it.',
  'I build an independent reference model and run your design on a live Artix-7.',
  'You get a signed report — measured numbers, vectors, bitstream, and every command needed to reproduce it.',
]

const AUTO_STEPS: [string, string, string][] = [
  ['minute 0', 'You open one issue', 'Where the RTL is, the top module, and what "correct" means for it. Nothing else.'],
  ['minute 1', 'A bot acknowledges', 'So nobody is left wondering whether it arrived.'],
  ['minute 5', 'Automated checks post back', 'Elaboration, latch check, synthesis, cell counts — publicly, with every command shown.'],
  ['then', 'The part a bot cannot do', 'An independent reference model, per-stage vectors, and a replay on the board.'],
]

// Measured facts, not badges. Nothing here is a claim I cannot show the working for.
const SIGNALS: [string, string][] = [
  ['170,068', 'cycles in the last run'],
  ['0', 'mismatches found'],
  ['48h', 'typical turnaround'],
  ['$0', 'for the first module'],
]

const RELATED = [
  { href: '#/proof', title: 'The evidence', body: 'Every measured number on this site, how it was obtained, and what it is not.' },
  { href: '#/ip', title: 'License a core', body: 'The arithmetic that has already been through silicon — GF-T, the GF16 matmul, the BPSK modem.' },
  { href: '#/course', title: 'Learn the method', body: 'Eight modules from an empty toolchain to a network training on the chip itself.' },
]

const RELATED_RU = [
  { href: '#/proof', title: 'Доказательства', body: 'Все измеренные цифры этого сайта, как они получены и чем они не являются.' },
  { href: '#/ip', title: 'Лицензировать ядро', body: 'Арифметика, уже прошедшая кремний: GF-T, матричный умножитель GF16, BPSK-модем.' },
  { href: '#/course', title: 'Научиться самому', body: 'Восемь модулей от пустого тулчейна до сети, которая учится на самом кристалле.' },
]

// Russian copy. Other locales fall back to English rather than showing gaps.
const RU = {
  autoTitle: 'Начать — без переписки',
  autoLede: 'Открываете одну заявку. Робот подхватывает её, прогоняет проверки, которым человек не нужен, и в считаные минуты публикует результат — со всеми командами, чтобы вы могли перепроверить сами.',
  autoSteps: [
    ['минута 0', 'Вы открываете заявку', 'Где RTL, какой топ-модуль и что для него значит «правильно». Больше ничего.'],
    ['минута 1', 'Робот подтверждает', 'Чтобы не оставалось сомнений, дошло ли.'],
    ['минута 5', 'Автопроверки публикуются', 'Элаборация, защёлки, синтез, счёт ячеек — открыто, со всеми командами.'],
    ['дальше', 'То, что робот не может', 'Независимая эталонная модель, векторы по ступеням и повтор на плате.'],
  ] as [string, string, string][],
  autoCta: 'Открыть заявку',
  diagramTitle: 'Почему внешняя проверка может с вами не согласиться',
  signals: [
    ['170 068', 'циклов в последнем прогоне'],
    ['0', 'найдено расхождений'],
    ['48 ч', 'обычный срок'],
    ['$0', 'за первый модуль'],
  ] as [string, string][],
  eyebrow: 'Верификация на живом железе',
  h1: 'Не симуляция. Измерено на живом кремнии.',
  lede: 'Присылаете RTL — я прогоняю его на настоящем Xilinx Artix-7 и возвращаю подписанный отчёт: побитовое соответствие независимой эталонной модели, достигнутая частота, ресурсы и битстрим. Всё на полностью открытом флоу, поэтому любую цифру вы можете перепроверить сами.',
  ctaRun: 'Запросить прогон',
  ctaSample: 'Посмотреть образец отчёта',
  freeNote: 'Первый модуль — бесплатно, чтобы вы оценили отчёт до того, как за что-то платить.',
  deliverablesTitle: 'Что в отчёте',
  deliverables: [
    { title: 'Побитовое соответствие', body: 'Каждый узел тракта сверяется с независимой моделью по KAT-векторам — расхождение спецификации и RTL всплывает до синтеза, а не после тейпаута.' },
    { title: 'Тайминг и ресурсы', body: 'Достигнутая частота, slack, использование LUT/FF/BRAM/DSP и проверка на защёлки — измерено на живом Artix-7, а не оценено.' },
    { title: 'Воспроизводимые артефакты', body: 'Битстрим, векторы, логи и точные версии инструментов, чтобы весь маршрут можно было повторить у себя.' },
    { title: 'Без вендор-локина', body: 'Yosys, nextpnr-xilinx, prjxray, openFPGALoader, iverilog. Ни одна цифра в отчёте не требует платной лицензии для перепроверки.' },
  ],
  howTitle: 'Как это работает',
  steps: [
    'Вы присылаете RTL или спецификацию и говорите, что для неё значит «правильно».',
    'Я строю независимую эталонную модель и прогоняю ваш дизайн на живом Artix-7.',
    'Вы получаете подписанный отчёт: измеренные числа, векторы, битстрим и все команды для воспроизведения.',
  ],
  pricingTitle: 'Стоимость',
  tiers: [
    { name: 'Одно ядро', price: '$300', body: 'Один модуль или IP-ядро: побитовая проверка, тайминг, ресурсы, отчёт.' },
    { name: 'Блок', price: '$800', body: 'Блок из нескольких ядер, проверка интеграции и письменный разбор.' },
    { name: 'Готовность к тейпауту', price: '$2 000', body: 'Полный проход верификации, latch-free и закрытие тайминга, ревью под ваш процесс.' },
    { name: 'Абонемент', price: '$1–3k / мес', body: 'Постоянные регрессии на реальном железе для вашего репозитория, на каждый релиз.' },
  ],
  proofTitle: 'Почему числам можно верить',
  proofLede: 'Этот пайплайн я построил для собственной работы — тернарный формат чисел прошёл путь от статьи на arXiv до работающего кремния, с побитовой проверкой на каждом шаге.',
  proof: [
    ['32 252 LUT · 0 DSP48', 'Матричный умножитель GF16 4×4 умещается в логику Artix-7 вообще без аппаратных умножителей — 21 223 LUT, если разрешить 64 DSP-блока. Комбинационный, 0 защёлок.'],
    ['100% held-out', 'Нейросеть, обучающаяся прямо на FPGA — путь спека→кремний побитово точен.'],
    ['Кремний SKY130', 'ASIC через TinyTapeout: GDS ✅ · gate-level тест ✅ · precheck ✅.'],
    ['83 формата', 'Опубликованные побитовые векторы соответствия для FP8, BF16, MXFP4 и microscaling.'],
  ],
  practicalsTitle: 'Как мы работаем',
  practicals: [
    { title: 'Сроки', body: 'Одно ядро — обычно 3–5 рабочих дней. По крупным блокам дата называется до начала работ. Если дедлайн горит — скажите сразу.' },
    { title: 'Ваш RTL остаётся вашим', body: 'Исходники используются только для вашего отчёта, никогда не публикуются и не переиспользуются, удаляются по запросу. NDA — пожалуйста, до отправки чего-либо.' },
    { title: 'Оплата', body: 'Инвойс в USD или EUR либо стейблкоин — как вам удобнее. Оплата по факту отчёта; первый модуль бесплатный, так что до результата вы ничего не должны.' },
    { title: 'Что прислать', body: 'RTL или спецификацию, определение правильного поведения (эталонные выходы, алгоритм или статью), целевую частоту и ограничения. Этого обычно достаточно для старта.' },
  ],
  limitsTitle: 'Чем это не является',
  limitsLede: 'Отчёт о верификации чего-то стоит только тогда, когда его границы названы так же ясно, как результаты.',
  limits: [
    'Устройство — Xilinx Artix-7 XC7A200T. Дизайны, которые в него не помещаются или требуют трансиверов и hard-IP, недоступных на плате, измерить здесь нельзя.',
    'Зашифрованные нетлисты и вендор-защищённое IP через открытый флоу не проходят.',
    'Это функциональная и тайминговая верификация на одном устройстве — не замена полного sign-off, DFT или многоугловой характеризации.',
    'Всё, что оценено, а не измерено, помечается как оценка. Ничего не выдаётся за измеренное, если оно не измерено.',
  ],
  finalTitle: 'Есть дизайн для проверки?',
  finalLede: 'Расскажите, что он делает и что для него значит «правильно». Если помещается в Artix-7 — можно измерить.',
  finalNote: 'В письме уже будут четыре коротких вопроса. Ответьте на них — и первым ответом будет оценка и дата, а не новые вопросы. Отвечаю в течение суток.',
}


function ScienceSection({ lang }: { lang: string }) {
  const ru = lang === 'ru'
  return (
    <div style={{ width: '100%', maxWidth: '900px', margin: '3rem auto 0', textAlign: 'left' }}>
      <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.6rem' }}>
        {ru ? 'На чём это стоит' : 'What this rests on'}
      </h2>
      <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.88, margin: '0 0 1.5rem', maxWidth: '64ch' }}>
        {ru ? SCIENCE_INTRO_RU : SCIENCE_INTRO_EN}
      </p>
      {THEOREMS.map((t) => (
        <div key={t.id} className="premium-card" style={{ textAlign: 'left', marginBottom: '0.9rem' }}>
          <div style={{ display: 'flex', gap: '0.7rem', alignItems: 'baseline' }}>
            <code style={{ color: 'var(--accent)', fontSize: '0.78rem', fontWeight: 700 }}>{t.id}</code>
            <h3 style={{ margin: 0, fontSize: 'clamp(0.98rem, 2.6vw, 1.12rem)', lineHeight: 1.35 }}>{t.name}</h3>
          </div>
          <p style={{ fontSize: '0.9rem', lineHeight: 1.62, margin: '0.6rem 0 0' }}>{t.statement}</p>
          {t.worked && (
            <p style={{ fontSize: '0.88rem', lineHeight: 1.6, margin: '0.6rem 0 0', color: 'var(--accent)' }}>
              {t.worked}
            </p>
          )}
          <p style={{ fontSize: '0.85rem', lineHeight: 1.55, margin: '0.7rem 0 0', opacity: 0.8 }}>
            <strong>{ru ? 'Не заявляет: ' : 'Does not claim: '}</strong>{t.doesNotClaim}
          </p>
          <p style={{ fontSize: '0.78rem', margin: '0.6rem 0 0', opacity: 0.6 }}>
            {t.url ? <a href={t.url} target="_blank" rel="noopener noreferrer">{t.citation}</a> : t.citation}
          </p>
        </div>
      ))}
    </div>
  )
}

export default function HardwareVerification() {
  const { lang } = useI18n()
  const ru = lang === 'ru'
  const c = ru ? RU : null
  usePageMeta("Hardware-verified RTL", "Send your RTL and get it measured on a live Xilinx Artix-7: bit-exact conformance against an independent model, timing, resources and the bitstream. From $300, first module free.")
  return (
    <main>
      <QuantumBackground />
      <Navigation />

      <section id="verification" style={{ maxWidth: '900px', alignItems: 'stretch' }}>
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
            {c ? c.eyebrow : 'Hardware-verified RTL'}
          </p>
          <h1 style={{ fontSize: 'clamp(1.9rem, 5.5vw, 2.8rem)', margin: '0 0 1rem', lineHeight: 1.15 }}>
            {c ? c.h1 : 'Not simulated. Measured on live silicon.'}
          </h1>
          <p style={{ fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)', lineHeight: 1.65, margin: 0, maxWidth: '62ch', marginLeft: 'auto', marginRight: 'auto' }}>
            {c ? c.lede : (
              <>
                Send your RTL. It runs on a real Xilinx Artix-7 and comes back with a signed report:
                bit-exact conformance against an independent model, achieved timing, resource usage,
                and the bitstream — on a fully open-source toolchain, so every number can be reproduced.
              </>
            )}
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', marginTop: '1.75rem' }}>
            <motion.a
              href={REQUEST_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="btn"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              style={{ padding: '12px 28px', fontSize: '0.9rem' }}
            >
              {c ? c.ctaRun : 'Request a run'}
            </motion.a>
            <motion.a
              href={CONTACT.sampleReport}
              target="_blank"
              rel="noopener noreferrer"
              className="btn secondary"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              style={{ padding: '12px 28px', fontSize: '0.9rem' }}
            >
              {c ? c.ctaSample : 'Read a sample report'}
            </motion.a>
          </div>
          {/* Trust signals belong beside the CTA, not 1500px below it. These are
              measured facts rather than badges — the only kind this page has earned. */}
          <div style={{
            display: 'flex', flexWrap: 'wrap', gap: '0.5rem 1.5rem', justifyContent: 'center',
            marginTop: '1.5rem', paddingTop: '1.25rem', borderTop: '1px solid var(--border)',
          }}>
            {(c ? c.signals : SIGNALS).map(([value, label]) => (
              <div key={label} style={{ textAlign: 'center', minWidth: '110px' }}>
                <p style={{ margin: 0, fontSize: '1.05rem', fontWeight: 700, color: 'var(--accent)', fontVariantNumeric: 'tabular-nums' }}>{value}</p>
                <p style={{ margin: 0, fontSize: '0.76rem', opacity: 0.72, lineHeight: 1.35 }}>{label}</p>
              </div>
            ))}
          </div>
          <p style={{ fontSize: '0.85rem', opacity: 0.75, marginTop: '1.25rem', marginBottom: 0 }}>
            {c ? c.freeNote : 'First module verified free — so you can judge the report before paying for anything.'}
          </p>
        </motion.div>

        {/* The method, drawn. Placed before the deliverables because every item in
            that list depends on the reader believing this one idea. */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '1.25rem' }}>
            {c ? c.diagramTitle : 'Why an outside check can disagree with you'}
          </h2>
          <VerificationDiagram />
        </motion.div>

        {/* How a request actually starts. Named plainly because "get in touch"
            is the step most people never take. */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.6rem' }}>
            {c ? c.autoTitle : 'No email thread to start it'}
          </h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.9, maxWidth: '62ch', margin: '0 auto 1.5rem' }}>
            {c ? c.autoLede : 'Open one request. A bot picks it up, runs the checks that do not need a human, and posts the result back within minutes — publicly, with every command shown, so you can re-run it yourself.'}
          </p>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(190px, 1fr))', gap: '0.9rem', marginBottom: '1.5rem' }}>
            {(c ? c.autoSteps : AUTO_STEPS).map(([when, what, note], i) => (
              <div key={what} style={{ borderTop: '2px solid var(--accent)', paddingTop: '0.8rem' }}>
                <p style={{ margin: 0, fontSize: '0.72rem', letterSpacing: '0.1em', textTransform: 'uppercase', opacity: 0.6 }}>
                  {String(i + 1).padStart(2, '0')} · {when}
                </p>
                <p style={{ margin: '0.3rem 0 0.2rem', fontSize: '0.98rem', fontWeight: 700, color: 'var(--accent)' }}>{what}</p>
                <p style={{ margin: 0, fontSize: '0.86rem', lineHeight: 1.5, opacity: 0.85 }}>{note}</p>
              </div>
            ))}
          </div>
          <a href={REQUEST_URL} target="_blank" rel="noopener noreferrer" className="btn" style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
            {c ? c.autoCta : 'Open a request'}
          </a>
        </motion.div>

        {/* What you get */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>{c ? c.deliverablesTitle : 'What the report contains'}</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '1rem' }}>
            {(c ? c.deliverables : DELIVERABLES).map((d) => (
              <div key={d.title} className="premium-card" style={{ padding: '1.5rem' }}>
                <h3 style={{ fontSize: '1.05rem', margin: '0 0 0.6rem', color: 'var(--accent)' }}>{d.title}</h3>
                <p style={{ fontSize: '0.92rem', lineHeight: 1.6, margin: 0, opacity: 0.9 }}>{d.body}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* How it works */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '1.25rem' }}>{c ? c.howTitle : 'How it works'}</h2>
          <ol style={{ margin: 0, paddingLeft: '1.25rem', textAlign: 'left', maxWidth: '58ch', marginLeft: 'auto', marginRight: 'auto', display: 'grid', gap: '0.85rem' }}>
            {(c ? c.steps : STEPS).map((s) => (
              <li key={s} style={{ fontSize: '0.95rem', lineHeight: 1.6, opacity: 0.92 }}>{s}</li>
            ))}
          </ol>
        </motion.div>

        {/* Pricing */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>{c ? c.pricingTitle : 'Pricing'}</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '1rem' }}>
            {(c ? c.tiers : TIERS).map((t) => (
              <div key={t.name} className="premium-card" style={{ padding: '1.5rem' }}>
                <p style={{ fontSize: '0.78rem', letterSpacing: '0.12em', textTransform: 'uppercase', opacity: 0.7, margin: '0 0 0.4rem' }}>{t.name}</p>
                <p style={{ fontSize: '1.6rem', fontWeight: 700, color: 'var(--accent)', margin: '0 0 0.6rem' }}>{t.price}</p>
                <p style={{ fontSize: '0.9rem', lineHeight: 1.55, margin: 0, opacity: 0.88 }}>{t.body}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Proof */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.75rem' }}>{c ? c.proofTitle : 'Why trust the numbers'}</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.9, marginTop: 0 }}>
            This pipeline was built for my own research — a ternary floating-point format taken from
            an arXiv paper all the way to working silicon, verified bit-exact at every step.
          </p>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(230px, 1fr))', gap: '1rem', marginTop: '1.25rem' }}>
            {(c ? c.proof : PROOF).map(([metric, note]) => (
              <div key={metric}>
                <p style={{ fontSize: '1.05rem', fontWeight: 700, color: 'var(--accent)', margin: '0 0 0.35rem' }}>{metric}</p>
                <p style={{ fontSize: '0.88rem', lineHeight: 1.55, margin: 0, opacity: 0.85 }}>{note}</p>
              </div>
            ))}
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', marginTop: '1.5rem' }}>
            <a href={CONTACT.arxiv1} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>
              arXiv:2606.05017
            </a>
            <a href={CONTACT.arxiv2} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>
              arXiv:2606.09686
            </a>
          </div>
        </motion.div>

        {/* Related pages. The header dock only carries one link to this service,
            so licensing, evidence and the course are reached from here. */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>
            {c ? 'Смежные страницы' : 'Related'}
          </h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '1rem' }}>
            {(c ? RELATED_RU : RELATED).map((r) => (
              <a key={r.href} href={r.href} className="premium-card" style={{ padding: '1.4rem', textDecoration: 'none', display: 'block' }}>
                <h3 style={{ fontSize: '1.02rem', margin: '0 0 0.5rem', color: 'var(--accent)' }}>{r.title}</h3>
                <p style={{ fontSize: '0.9rem', lineHeight: 1.55, margin: 0, opacity: 0.88 }}>{r.body}</p>
              </a>
            ))}
          </div>
        </motion.div>

        {/* Practicals */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>{c ? c.practicalsTitle : 'Working together'}</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '1rem' }}>
            {(c ? c.practicals : PRACTICALS).map((p) => (
              <div key={p.title} className="premium-card" style={{ padding: '1.5rem' }}>
                <h3 style={{ fontSize: '1.05rem', margin: '0 0 0.6rem', color: 'var(--accent)' }}>{p.title}</h3>
                <p style={{ fontSize: '0.92rem', lineHeight: 1.6, margin: 0, opacity: 0.9 }}>{p.body}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Scope & limits */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.75rem' }}>{c ? c.limitsTitle : 'What this is not'}</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.9, marginTop: 0 }}>
            A verification report is only worth something if its limits are stated as clearly as its results.
          </p>
          <ul style={{ margin: '1rem 0 0', paddingLeft: '1.25rem', display: 'grid', gap: '0.7rem' }}>
            {(c ? c.limits : LIMITS).map((l) => (
              <li key={l} style={{ fontSize: '0.92rem', lineHeight: 1.6, opacity: 0.88 }}>{l}</li>
            ))}
          </ul>
        </motion.div>

        {/* Contact */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ textAlign: 'center' }}
        >
          <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.6rem)', marginTop: 0 }}>{c ? c.finalTitle : 'Have a design to verify?'}</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.6, opacity: 0.9, maxWidth: '52ch', margin: '0 auto 1.5rem' }}>
            Tell me what it does and what correct looks like. If it fits on an Artix-7, it can be measured.
          </p>
          <p style={{ fontSize: '0.85rem', lineHeight: 1.6, opacity: 0.72, maxWidth: '52ch', margin: '0 auto 1.5rem' }}>
            The email opens with four short questions already in it. Answer them and my first
            reply can be a quote and a date rather than more questions. I answer within a day.
          </p>
          <motion.a
            href={mailto('Hardware verification request')}
            className="btn"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            style={{ padding: '12px 30px', fontSize: '0.9rem' }}
          >
            {CONTACT.email}
          </motion.a>
        </motion.div>
      </section>

      <ScienceSection lang={lang} />

      <Footer />
    </main>
  )
}
