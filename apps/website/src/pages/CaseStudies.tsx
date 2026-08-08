"use client";
import { motion } from 'framer-motion'
import { usePageMeta } from '../hooks/usePageMeta'
import { useI18n } from '../i18n/context'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'

const CONTACT = {
  email: 'admin@t27.dev',
  sampleReport: 'https://github.com/gHashTag/trinity/blob/main/docs/verification/SAMPLE-REPORT.md',
}

/**
 * Client work, newest first.
 *
 * Empty on purpose until a real run finishes — an invented case study is worth
 * less than an honest empty page, because the whole offer rests on measured
 * claims. To add one, append an entry here; the page switches out of its empty
 * state on its own.
 *
 * Every field must come from the run itself:
 *   design    what was verified, in the client's words where possible
 *   found     what the check surfaced (including "nothing" — that is a result)
 *   measured  the numbers, from the board
 *   quote     verbatim, with permission, or omitted entirely
 */
type CaseStudy = {
  client: string
  anonymous?: boolean
  design: string
  found: string
  measured: { label: string; value: string }[]
  turnaround: string
  quote?: { text: string; who: string }
  reportUrl?: string
}

const CASES: CaseStudy[] = []

const RU = {
  eyebrow: 'Работы',
  h1: 'Что показали чужие дизайны.',
  lede: 'Каждый прогон заканчивается отчётом: что проверялось, что нашлось и какие цифры сняты с платы. Здесь они собраны — с разрешения клиента и без правок в его пользу.',
  emptyTitle: 'Пока пусто — и это честно',
  emptyBody: 'Первые прогоны идут бесплатно, и до тех пор, пока хотя бы один не закончится, здесь ничего не будет. Выдуманный кейс стоил бы дешевле пустой страницы: всё предложение держится на том, что цифры измерены.',
  emptyCta: 'Пока смотрите образец отчёта — на моём собственном дизайне, с теми же разделами, которые получит ваш.',
  ctaSample: 'Образец отчёта',
  ctaRequest: 'Запросить прогон',
  found: 'Что нашлось',
  turnaround: 'Срок',
  design: 'Что проверялось',
}

const EN = {
  eyebrow: 'Case studies',
  h1: 'What other people’s designs turned out to be.',
  lede: 'Every run ends in a report: what was checked, what it surfaced, and the numbers taken off the board. They are collected here, with the client’s permission and without edits in my favour.',
  emptyTitle: 'Empty for now, and honestly so',
  emptyBody: 'The first runs are free, and until one of them finishes there will be nothing here. An invented case study would be worth less than an empty page: the whole offer rests on the numbers being measured.',
  emptyCta: 'In the meantime, read the sample report — my own design, with the same sections yours would get.',
  ctaSample: 'Sample report',
  ctaRequest: 'Request a run',
  found: 'What it surfaced',
  turnaround: 'Turnaround',
  design: 'What was checked',
}

function mailto(subject: string) {
  return `mailto:${CONTACT.email}?subject=${encodeURIComponent(subject)}`
}

export default function CaseStudies() {
  const { lang } = useI18n()
  const c = lang === 'ru' ? RU : EN
  usePageMeta(
    lang === 'ru' ? 'Работы' : 'Case studies',
    'Verification runs on other people’s RTL: what was checked, what it surfaced, and the numbers measured on a live Artix-7.',
  )

  return (
    <main>
      <QuantumBackground />
      <Navigation />

      <section id="cases" style={{ maxWidth: '900px' }}>
        <div className="radial-glow" style={{ opacity: 0.2, background: 'radial-gradient(circle at center, rgba(0, 255, 136, 0.08) 0%, transparent 60%)' }} />

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7 }}
          style={{ marginBottom: '2rem' }}
        >
          <p style={{ color: 'var(--accent)', letterSpacing: '0.14em', textTransform: 'uppercase', fontSize: '0.75rem', margin: '0 0 0.75rem' }}>
            {c.eyebrow}
          </p>
          <h1 style={{ fontSize: 'clamp(1.9rem, 5.5vw, 2.8rem)', margin: '0 0 1rem', lineHeight: 1.15 }}>
            {c.h1}
          </h1>
          <p style={{ fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)', lineHeight: 1.65, margin: 0, maxWidth: '62ch', marginLeft: 'auto', marginRight: 'auto' }}>
            {c.lede}
          </p>
        </motion.div>

        {CASES.length === 0 ? (
          <motion.div
            className="premium-card"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6 }}
          >
            <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.6rem)', marginTop: 0, marginBottom: '0.8rem' }}>{c.emptyTitle}</h2>
            <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.9, maxWidth: '58ch', margin: '0 auto 0.9rem' }}>
              {c.emptyBody}
            </p>
            <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.9, maxWidth: '58ch', margin: '0 auto 1.4rem' }}>
              {c.emptyCta}
            </p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', justifyContent: 'center' }}>
              <a href={CONTACT.sampleReport} target="_blank" rel="noopener noreferrer" className="btn" style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
                {c.ctaSample}
              </a>
              <a href={mailto('Hardware verification request')} className="btn secondary" style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
                {c.ctaRequest}
              </a>
            </div>
          </motion.div>
        ) : (
          <div style={{ display: 'grid', gap: '1.25rem' }}>
            {CASES.map((s) => (
              <motion.article
                key={s.client}
                className="premium-card"
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.6 }}
                style={{ padding: '1.75rem', textAlign: 'left' }}
              >
                <h2 style={{ fontSize: '1.2rem', margin: '0 0 0.9rem', color: 'var(--accent)' }}>{s.client}</h2>

                <p style={{ fontSize: '0.78rem', letterSpacing: '0.12em', textTransform: 'uppercase', opacity: 0.6, margin: '0 0 0.25rem' }}>{c.design}</p>
                <p style={{ fontSize: '0.94rem', lineHeight: 1.6, margin: '0 0 1rem', opacity: 0.9 }}>{s.design}</p>

                <p style={{ fontSize: '0.78rem', letterSpacing: '0.12em', textTransform: 'uppercase', opacity: 0.6, margin: '0 0 0.25rem' }}>{c.found}</p>
                <p style={{ fontSize: '0.94rem', lineHeight: 1.6, margin: '0 0 1rem', opacity: 0.9 }}>{s.found}</p>

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '0.9rem', margin: '0 0 1rem' }}>
                  {s.measured.map((m) => (
                    <div key={m.label}>
                      <p style={{ fontSize: '1.15rem', fontWeight: 700, color: 'var(--accent)', margin: 0, fontVariantNumeric: 'tabular-nums' }}>{m.value}</p>
                      <p style={{ fontSize: '0.82rem', margin: 0, opacity: 0.7 }}>{m.label}</p>
                    </div>
                  ))}
                  <div>
                    <p style={{ fontSize: '1.15rem', fontWeight: 700, color: 'var(--accent)', margin: 0 }}>{s.turnaround}</p>
                    <p style={{ fontSize: '0.82rem', margin: 0, opacity: 0.7 }}>{c.turnaround}</p>
                  </div>
                </div>

                {s.quote && (
                  <blockquote style={{ borderLeft: '2px solid var(--accent)', paddingLeft: '1rem', margin: '0 0 1rem' }}>
                    <p style={{ fontSize: '0.96rem', lineHeight: 1.6, margin: '0 0 0.35rem', fontStyle: 'italic' }}>{s.quote.text}</p>
                    <footer style={{ fontSize: '0.85rem', opacity: 0.7 }}>{s.quote.who}</footer>
                  </blockquote>
                )}

                {s.reportUrl && (
                  <a href={s.reportUrl} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>
                    {c.ctaSample}
                  </a>
                )}
              </motion.article>
            ))}
          </div>
        )}
      </section>

      <Footer />
    </main>
  )
}
