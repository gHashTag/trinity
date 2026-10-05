"use client";
import { motion } from 'framer-motion'
import { usePageMeta } from '../hooks/usePageMeta'
import { useI18n } from '../i18n/context'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'

const CONTACT = {
  email: 'admin@t27.ai',
  github: 'https://github.com/gHashTag',
}

const MODULES = [
  { n: '01', title: 'The open flow, from nothing', body: 'Yosys, nextpnr-xilinx, prjxray, openFPGALoader and iverilog installed and proven on macOS arm64 or Linux. Your first bitstream blinking on a real board — with no vendor licence anywhere in the chain.' },
  { n: '02', title: 'Exactly as much Verilog as you need', body: 'Synchronous design, registers versus latches, and why an accidental latch is the classic bug that only shows up on silicon. Your first module and testbench.' },
  { n: '03', title: 'Arithmetic — the foundation of ML in hardware', body: 'Why floating point is expensive, what quantisation really costs, and where ternary and low-precision formats come from. GF-T and the BitNet wave, explained from the inside.' },
  { n: '04', title: 'Bit-exact verification (the heart of the course)', body: 'An independent reference model in Python, KAT vectors per stage, cross-checked through iverilog. Why a testbench written from the same assumptions as the design will happily agree with the bug.' },
  { n: '05', title: 'A matrix multiplier that closes timing', body: 'MAC to array to pipeline. Reading the router’s timing report and fighting for frequency on a real case — including why a hard multiplier in the path can leave you with no frequency report at all.' },
  { n: '06', title: 'Neural network inference on the FPGA', body: 'Layers, activations, dataflow and on-chip memory — running on the board, not in a simulator.' },
  { n: '07', title: 'Training on-chip (the capstone)', body: 'Backward pass and SGD in RTL. The network learns XOR on the FPGA itself — 4/4, bit-exact against the reference. Almost nobody has built this by hand.' },
  { n: '08', title: 'Onward to silicon', body: 'The Tiny Tapeout path: preparing a design, what changes between FPGA and ASIC, and where the open-silicon ecosystem stands after the move to IHP.' },
]

const TIERS = [
  { name: 'Self-paced', price: '$149', body: 'Video, code, KAT vector sets, community access.' },
  { name: 'Self-paced + hardware', price: '$249', body: 'Everything above, plus remote runs on my Artix-7 boards — no need to own one.' },
  { name: 'Cohort · 4 weeks', price: '$599', body: 'Live sessions, code review, and your own design taken apart with you.' },
  { name: 'Team workshop', price: 'from $9 000', body: 'Two days with your engineers, built around a problem you actually have.' },
]

const AUDIENCE = [
  ['ML engineers', 'You know the models. Textbooks stop at simulation, so hardware still feels like someone else’s country.'],
  ['Students & researchers', 'No vendor licences, no expensive boards, no gatekeeping — the whole flow here is free and open.'],
  ['Embedded developers', 'Comfortable with microcontrollers, moving into edge AI, and needing RTL that carries ML.'],
  ['Tiny Tapeout participants', 'You want the path from specification to verified RTL to a shuttle, without guessing.'],
]

// Named plainly, because a buyer who knows this field will ask anyway, and a
// page that pretends the free alternatives do not exist reads as dishonest.
const ALTERNATIVES = [
  { name: 'hls4ml (CERN)', free: 'Free', gap: 'Inference only, generated through HLS, and the flow underneath it is a vendor toolchain. Excellent at what it does — it does not train on the chip, and it does not leave you able to read the RTL it produced.' },
  { name: 'Vendor courses (Intel, AMD)', free: 'Free', gap: 'Built to teach you their tools on their silicon. Nothing you learn transfers to a flow you can run without a licence.' },
  { name: 'University FPGA courses', free: 'Free or credit-bearing', gap: 'Usually stop at simulation, and where they reach a board it is through Vivado or Quartus.' },
]

const DIFFERENCE = 'Two things here exist nowhere on that list: a backward pass running on the chip itself, and a flow with no vendor licence anywhere in it. If inference through HLS is what you need, use hls4ml — it is good, it is free, and I would tell you the same in an email.'


// Russian copy. Other locales fall back to English rather than showing gaps.
const RU = {
  eyebrow: 'Курс',
  h1: 'Обучите нейросеть прямо на FPGA.',
  lede: 'Не инференс — именно обучение, на самом кристалле. Восемь модулей: от пустого тулчейна до сети, которая учится прямо на FPGA-плате. Полностью на открытых инструментах: без Vivado, без лицензий, без единого шага, который вы не сможете повторить сами.',
  ctaSeat: 'Забронировать место',
  ctaVerif: 'Посмотреть работы по верификации',
  seatNote: 'Следующий поток стартует, когда наберётся группа — напишите, и я придержу место.',
  whyTitle: 'Зачем этот курс',
  why1: 'Вендорские курсы учат вендорским инструментам. Курсы по ASIC заканчиваются на тейпауте. Никто не учит тому, что мне пришлось доказать на железе: нейросеть, делающая обратный проход прямо на FPGA, проверенная побитово — на тулчейне, который студент ставит бесплатно на свой ноутбук.',
  why2: 'Я учу этому, потому что сам это построил: собственный формат чисел от статьи на arXiv через RTL, умещающийся в логику без единого аппаратного умножителя, до дизайна, подготовленного для SKY130 через Tiny Tapeout (заявка отозвана до изготовления, кристалла нет) — и до этого обучил больше тысячи разработчиков.',
  modulesTitle: 'Восемь модулей',
  modules: [
    { n: '01', title: 'Открытый флоу с нуля', body: 'Yosys, nextpnr-xilinx, prjxray, openFPGALoader и iverilog, установленные и проверенные на macOS arm64 или Linux. Первый битстрим мигает светодиодом на реальной плате — и ни одной вендор-лицензии в цепочке.' },
    { n: '02', title: 'Verilog ровно столько, сколько нужно', body: 'Синхронный дизайн, регистры против защёлок и почему случайная защёлка — классический баг, который вылезает только на кремнии. Первый модуль и тестбенч.' },
    { n: '03', title: 'Арифметика — фундамент ML в железе', body: 'Почему float дорог, чего на самом деле стоит квантизация и откуда берутся тернарные и низкоразрядные форматы. GF-T и волна BitNet — изнутри.' },
    { n: '04', title: 'Побитовая верификация (сердце курса)', body: 'Независимая эталонная модель на Python, KAT-векторы по ступеням, сверка через iverilog. Почему тестбенч, написанный из тех же предпосылок, что и дизайн, радостно соглашается с багом.' },
    { n: '05', title: 'Матричный умножитель, который закрывает тайминг', body: 'MAC → массив → конвейер. Чтение отчёта разводчика о тайминге и борьба за частоту на реальном примере — включая то, почему аппаратный умножитель в тракте может оставить вас вообще без отчёта о частоте.' },
    { n: '06', title: 'Инференс нейросети на FPGA', body: 'Слои, активации, потоки данных и память на кристалле — работающие на плате, а не в симуляторе.' },
    { n: '07', title: 'Обучение на кристалле (капстоун)', body: 'Обратный проход и SGD в RTL. Сеть учит XOR прямо на FPGA — 4 из 4, побитово против эталона. Руками это почти никто не делал.' },
    { n: '08', title: 'Дальше — на кремний', body: 'Путь Tiny Tapeout: подготовка дизайна, что меняется между FPGA и ASIC, и где сейчас открытая кремниевая экосистема после перехода на IHP.' },
  ],
  audienceTitle: 'Кому это',
  audience: [
    ['ML-инженеры', 'Вы знаете модели. Учебники обрываются на симуляции, и железо остаётся чужой территорией.'],
    ['Студенты и исследователи', 'Ни лицензий, ни дорогих плат, ни привратников — весь флоу здесь бесплатный и открытый.'],
    ['Embedded-разработчики', 'Микроконтроллеры знакомы, идёте в edge-AI, нужен RTL, который несёт ML.'],
    ['Участники Tiny Tapeout', 'Нужен путь от спецификации к проверенному RTL и шаттлу — без угадывания.'],
  ],
  altTitle: 'Чем это отличается от бесплатных курсов',
  alternatives: [
    { name: 'hls4ml (CERN)', free: 'Бесплатно', gap: 'Только инференс, через HLS, а под ним всё равно вендорский тулчейн. Своё дело делает отлично — но не учит на кристалле и не оставляет вас способным прочитать сгенерированный RTL.' },
    { name: 'Вендорские курсы (Intel, AMD)', free: 'Бесплатно', gap: 'Написаны, чтобы научить вас их инструментам на их кремнии. Ничто из выученного не переносится на флоу, который вы запустите без лицензии.' },
    { name: 'Университетские курсы по FPGA', free: 'Бесплатно или за зачёт', gap: 'Обычно заканчиваются на симуляции, а где доходят до платы — там Vivado или Quartus.' },
  ],
  difference: 'Двух вещей в этом списке нет нигде: обратного прохода, исполняемого прямо на кристалле, и флоу, в котором нет ни одной вендорской лицензии. Если вам нужен инференс через HLS — берите hls4ml: он хорош, он бесплатен, и я напишу вам то же самое в письме.',
  formatsTitle: 'Форматы',
  tiers: [
    { name: 'Самостоятельно', price: '$149', body: 'Видео, код, наборы KAT-векторов, доступ к сообществу.' },
    { name: 'Самостоятельно + железо', price: '$249', body: 'То же плюс удалённые прогоны на моих Artix-7 — своя плата не нужна.' },
    { name: 'Поток · 4 недели', price: '$599', body: 'Живые сессии, разбор кода и вашего дизайна вместе с вами.' },
    { name: 'Воркшоп для команды', price: 'от $9 000', body: 'Два дня с вашими инженерами вокруг задачи, которая у вас реально есть.' },
  ],
  prereq: 'Требуется: базовый Python и представление о цифровой логике. Verilog учим с нуля. Плата не обязательна — в двух форматах прогоны на моём железе включены.',
  finalTitle: 'Хотите место в ближайшем потоке?',
  finalLede: 'Напишите, с чего начинаете и что хотите построить. Честно скажу, подходит вам этот курс или нет.',
}

export default function Course() {
  const { lang } = useI18n()
  const c = lang === 'ru' ? RU : null
  usePageMeta("FPGA training course", "Eight modules from an empty toolchain to a neural network that trains itself on an FPGA — fully open-source, no Vivado, no vendor licence.")
  return (
    <main>
      <QuantumBackground />
      <Navigation />

      <section id="course" className="subpage-layout" style={{ maxWidth: '900px', alignItems: 'stretch', textAlign: 'left' }}>
        <div className="radial-glow" style={{ opacity: 0.2, background: 'radial-gradient(circle at center, rgba(0, 255, 136, 0.08) 0%, transparent 60%)' }} />

        {/* Hero */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7 }}
          style={{ marginBottom: '2rem', textAlign: 'center' }}
        >
          <p style={{ color: 'var(--accent)', letterSpacing: '0.14em', textTransform: 'uppercase', fontSize: '0.75rem', margin: '0 0 0.75rem' }}>
            {c ? c.eyebrow : 'Course'}
          </p>
          <h1 style={{ fontSize: 'clamp(1.9rem, 5.5vw, 2.8rem)', margin: '0 0 1rem', lineHeight: 1.15 }}>
            {c ? c.h1 : 'Train a neural network on an FPGA.'}
          </h1>
          <p style={{ fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)', lineHeight: 1.65, margin: 0, maxWidth: '68ch' }}>
            {c ? c.lede : (
              <>
              Not inference — <strong>training</strong>, on the chip itself. Eight modules from an empty
              toolchain to a network that learns on the FPGA board itself, built entirely on open-source tools.
              No Vivado, no licence, nothing you cannot reproduce yourself.
              </>
            )}
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', marginTop: '1.75rem' }}>
            <motion.a
              href={`mailto:${CONTACT.email}?subject=Course%20—%20reserve%20a%20seat`}
              className="btn"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              style={{ padding: '12px 28px', fontSize: '0.9rem' }}
            >
              {c ? c.ctaSeat : 'Reserve a seat'}
            </motion.a>
            <motion.a
              href="#/verification"
              className="btn secondary"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              style={{ padding: '12px 28px', fontSize: '0.9rem' }}
            >
              {c ? c.ctaVerif : 'See the verification work'}
            </motion.a>
          </div>
          <p style={{ fontSize: '0.85rem', opacity: 0.75, margin: '1.25rem 0 0' }}>
            {c ? c.seatNote : 'The next cohort runs when enough people are in — say the word and I will hold you a place.'}
          </p>
        </motion.div>

        {/* Why this exists */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.75rem' }}>{c ? c.whyTitle : 'Why this course exists'}</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.9, margin: 0 }}>
            {c ? c.why1 : `Vendor courses teach you vendor tools. ASIC courses stop at the tape-out. Nobody teaches the thing I actually had to prove on hardware: a neural network performing its own backward pass on an FPGA, verified bit-exact against an independent model — with a toolchain a student can install for free on a laptop.`}
          </p>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.9, margin: '0.9rem 0 0' }}>
            {c ? c.why2 : `I teach it because I built it: a number format of my own from an arXiv paper, through RTL that needs no hard multipliers at all, to a design prepared for SKY130 through Tiny Tapeout — the submission was withdrawn before fabrication, so no die exists. And I taught over a thousand developers before that.`}
          </p>
        </motion.div>

        {/* Modules */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>{c ? c.modulesTitle : 'Eight modules'}</h2>
          <div style={{ display: 'grid', gap: '0.85rem' }}>
            {(c ? c.modules : MODULES).map((m) => (
              <div key={m.n} className="premium-card" style={{ padding: '1.35rem 1.5rem', display: 'flex', flexDirection: 'row', gap: '1.25rem', alignItems: 'flex-start' }}>
                <span style={{ color: 'var(--accent)', fontWeight: 700, fontSize: '0.95rem', fontVariantNumeric: 'tabular-nums', opacity: 0.8, paddingTop: '0.15rem' }}>{m.n}</span>
                <div>
                  <h3 style={{ fontSize: '1.02rem', margin: '0 0 0.45rem' }}>{m.title}</h3>
                  <p style={{ fontSize: '0.9rem', lineHeight: 1.6, margin: 0, opacity: 0.88 }}>{m.body}</p>
                </div>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Audience */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>{c ? c.audienceTitle : 'Who it is for'}</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1rem' }}>
            {(c ? c.audience : AUDIENCE).map(([who, why]) => (
              <div key={who} className="premium-card" style={{ padding: '1.5rem' }}>
                <h3 style={{ fontSize: '1.02rem', margin: '0 0 0.55rem', color: 'var(--accent)' }}>{who}</h3>
                <p style={{ fontSize: '0.9rem', lineHeight: 1.6, margin: 0, opacity: 0.88 }}>{why}</p>
              </div>
            ))}
          </div>
          <p style={{ fontSize: '0.9rem', opacity: 0.8, margin: '1.25rem 0 0' }}>
            {c ? c.prereq : 'Prerequisites: basic Python and the idea of digital logic. Verilog is taught from zero. A board is optional — runs on my hardware are included in two of the tiers.'}
          </p>
        </motion.div>

        {/* How this differs from the free alternatives */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '1rem' }}>
            {c ? c.altTitle : 'How this differs from the free alternatives'}
          </h2>
          <div style={{ display: 'grid', gap: '0.9rem', textAlign: 'left', maxWidth: '68ch' }}>
            {(c ? c.alternatives : ALTERNATIVES).map((a) => (
              <div key={a.name} style={{ borderLeft: '2px solid var(--border)', paddingLeft: '0.9rem' }}>
                <p style={{ fontSize: '0.95rem', fontWeight: 700, margin: '0 0 0.15rem' }}>
                  {a.name} <span style={{ fontWeight: 400, opacity: 0.6, fontSize: '0.85rem' }}>· {a.free}</span>
                </p>
                <p style={{ fontSize: '0.9rem', lineHeight: 1.55, margin: 0, opacity: 0.85 }}>{a.gap}</p>
              </div>
            ))}
          </div>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.65, marginTop: '1.25rem', marginBottom: 0, maxWidth: '68ch' }}>
            {c ? c.difference : DIFFERENCE}
          </p>
        </motion.div>

        {/* Pricing */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>{c ? c.formatsTitle : 'Formats'}</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1rem' }}>
            {(c ? c.tiers : TIERS).map((t) => (
              <div key={t.name} className="premium-card" style={{ padding: '1.5rem' }}>
                <p style={{ fontSize: '0.78rem', letterSpacing: '0.12em', textTransform: 'uppercase', opacity: 0.7, margin: '0 0 0.4rem' }}>{t.name}</p>
                <p style={{ fontSize: '1.6rem', fontWeight: 700, color: 'var(--accent)', margin: '0 0 0.6rem' }}>{t.price}</p>
                <p style={{ fontSize: '0.9rem', lineHeight: 1.55, margin: 0, opacity: 0.88 }}>{t.body}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* CTA */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ textAlign: 'center' }}
        >
          <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.6rem)', marginTop: 0 }}>{c ? c.finalTitle : 'Want a seat in the next cohort?'}</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.6, opacity: 0.9, maxWidth: '52ch', margin: '0 auto 1.5rem' }}>
            {c ? c.finalLede : 'Tell me where you are starting from and what you want to build. I will tell you honestly whether this course is the right thing for you.'}
          </p>
          <motion.a
            href={`mailto:${CONTACT.email}?subject=Course%20—%20reserve%20a%20seat`}
            className="btn"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            style={{ padding: '12px 30px', fontSize: '0.9rem' }}
          >
            {CONTACT.email}
          </motion.a>
        </motion.div>
      </section>

      <Footer />
    </main>
  )
}
