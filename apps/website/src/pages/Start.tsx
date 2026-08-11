"use client";
import { useState } from 'react'
import { usePageMeta } from '../hooks/usePageMeta'
import { useI18n } from '../i18n/context'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'
import { CHECKS, START_INTRO, START_DEBT } from '../data/checks'

// One page for all four checks, in the order worth adopting them.
//
// They were scattered across two pages, each introduced where it happened to be
// written, so somebody deciding whether to use any of this could not see them
// together and had no reason to prefer one first. The order is the content: the
// cheapest and narrowest goes first, because the first thing a new reader runs
// should be the one that cannot waste their afternoon.

function Snippet({ code }: { code: string }) {
  const { lang } = useI18n()
  const [copied, setCopied] = useState(false)
  return (
    <div style={{ position: 'relative', marginBottom: '1rem' }}>
      <button
        onClick={() => navigator.clipboard?.writeText(code).then(() => {
          setCopied(true); setTimeout(() => setCopied(false), 2000)
        })}
        className="btn secondary"
        style={{ position: 'absolute', top: '8px', right: '8px', padding: '5px 12px', fontSize: '0.72rem', zIndex: 2 }}
      >
        {copied ? (lang === 'ru' ? 'Скопировано' : 'Copied') : (lang === 'ru' ? 'Скопировать' : 'Copy')}
      </button>
      <pre style={{
        margin: 0, padding: '0.9rem 1rem', overflowX: 'auto',
        background: 'rgba(0,0,0,0.35)', border: '1px solid rgba(255,255,255,0.09)',
        borderRadius: '10px', fontSize: '0.79rem', lineHeight: 1.6,
      }}><code>{code}</code></pre>
    </div>
  )
}

export default function Start() {
  const { lang } = useI18n()
  const ru = lang === 'ru'
  const L = (v: { en: string; ru: string }) => (ru ? v.ru : v.en)
  usePageMeta(
    ru ? 'С чего начать — четыре проверки RTL' : 'Where to start — four RTL checks',
    ru
      ? 'Четыре проверки в порядке принятия. Все идут на вашем раннере, по вашему checkout, без загрузки исходников куда-либо.'
      : 'Four checks in the order worth adopting them. All run on your runner, against your checkout, with nothing uploaded anywhere.',
  )

  return (
    <main>
      <QuantumBackground />
      <Navigation />
      <section id="start" style={{ maxWidth: '900px', alignItems: 'stretch' }}>
        <div className="radial-glow" style={{ opacity: 0.2, background: 'radial-gradient(circle at center, rgba(0,255,136,0.08) 0%, transparent 60%)' }} />

        <div style={{ marginBottom: '2rem' }}>
          <p style={{ color: 'var(--accent)', letterSpacing: '0.14em', textTransform: 'uppercase', fontSize: '0.75rem', margin: '0 0 0.75rem' }}>
            {ru ? 'С чего начать' : 'Where to start'}
          </p>
          <h1 style={{ fontSize: 'clamp(1.9rem, 5.5vw, 2.8rem)', margin: '0 0 1rem', lineHeight: 1.15 }}>
            {ru ? 'Четыре проверки, в порядке принятия' : 'Four checks, in the order worth adopting them'}
          </h1>
          <p style={{ fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)', lineHeight: 1.65, margin: 0, maxWidth: '64ch' }}>
            {L(START_INTRO)}
          </p>
        </div>

        <div style={{
          padding: '0.9rem 1.1rem', borderRadius: '10px', textAlign: 'left',
          background: 'rgba(255,255,255,0.04)', border: '1px solid var(--border)',
          marginBottom: '2rem', fontSize: '0.88rem', lineHeight: 1.6,
        }}>
          <strong style={{ display: 'block', marginBottom: '0.3rem' }}>
            {ru ? 'Если репозиторий сломан давно' : 'If the repository has been broken a while'}
          </strong>
          {L(START_DEBT)}
        </div>

        {CHECKS.map((c) => (
          <div key={c.id} className="premium-card" style={{ textAlign: 'left', marginBottom: '1.6rem' }}>
            <div style={{ display: 'flex', gap: '0.8rem', alignItems: 'baseline', flexWrap: 'wrap', marginBottom: '0.5rem' }}>
              <span style={{
                flex: '0 0 auto', width: '26px', height: '26px', borderRadius: '50%',
                border: '1px solid var(--accent)', color: 'var(--accent)',
                display: 'grid', placeItems: 'center', fontSize: '0.78rem',
              }}>{c.order}</span>
              <h2 style={{ fontSize: 'clamp(1.05rem, 2.8vw, 1.35rem)', margin: 0, lineHeight: 1.3 }}>{L(c.name)}</h2>
            </div>

            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4rem 1.4rem', margin: '0 0 0.9rem', fontSize: '0.8rem', opacity: 0.75 }}>
              <span>{ru ? 'Нужно' : 'Needs'}: {L(c.needs)}</span>
              <span>{ru ? 'Время' : 'Time'}: {L(c.time)}</span>
              <span style={{ color: 'var(--accent)' }}>{L(c.price)}</span>
            </div>

            <p style={{ margin: '0 0 1rem', fontSize: '0.9rem', lineHeight: 1.6, opacity: 0.88, maxWidth: '68ch' }}>{L(c.why)}</p>

            <Snippet code={c.snippet} />

            <p style={{ margin: '0 0 0.35rem', fontSize: '0.82rem', letterSpacing: '0.06em', textTransform: 'uppercase', opacity: 0.6 }}>
              {ru ? 'Что устанавливает' : 'What it establishes'}
            </p>
            <ul style={{ margin: '0 0 0.9rem', paddingLeft: '1.1rem' }}>
              {(ru ? c.establishes.ru : c.establishes.en).map((li) => (
                <li key={li} style={{ fontSize: '0.87rem', lineHeight: 1.55, marginBottom: '0.25rem', opacity: 0.88 }}>{li}</li>
              ))}
            </ul>

            <p style={{ margin: '0 0 0.9rem', fontSize: '0.86rem', lineHeight: 1.6, opacity: 0.75 }}>
              <strong style={{ opacity: 0.9 }}>{ru ? 'Чего не устанавливает: ' : 'What it refuses to claim: '}</strong>
              {L(c.refuses)}
            </p>

            {c.evidence && (
              <p style={{
                margin: 0, padding: '0.7rem 0.9rem', borderRadius: '8px',
                background: 'rgba(0,255,136,0.05)', border: '1px solid rgba(0,255,136,0.16)',
                fontSize: '0.85rem', lineHeight: 1.55,
              }}>{L(c.evidence)}</p>
            )}
          </div>
        ))}
      </section>
      <Footer />
    </main>
  )
}
