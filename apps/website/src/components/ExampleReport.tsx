"use client";
import { useI18n } from '../i18n/context'
import report from '../data/exampleReport.json'

// What comes back, shown rather than described.
//
// The page could say what the check reports, and could link to a sample written
// by hand. Neither is the thing a reader wants before spending six lines of YAML
// on it: they want the actual output, with the actual numbers, from a run they
// can open. A hand-written sample drifts from what the tool says. This is
// extracted from the run's own log, so it cannot.
//
// It is deliberately placed directly under the snippet. Paste that, get this.

type Job = { name: string; lines: string[] }

const JOBS = (report.jobs ?? []) as Job[]

const T = {
  en: {
    h3: 'And this is what comes back',
    lede: 'Not a sample. These are the lines the check wrote in its most recent successful run, extracted from the log of that run, on two designs targeting a Tiny Tapeout shuttle (RTL scaffolds; no die exists).',
    open: 'Open the run',
    caveat: 'Four facts and the command behind each. Every one of them is structural: none of it says the design is correct, and the summary of every run says so in the same words.',
  },
  ru: {
    h3: 'А вот что приходит в ответ',
    lede: 'Это не образец. Это строки, которые проверка написала в последнем успешном прогоне, извлечённые из лога этого прогона, на двух дизайнах, нацеленных на шаттл Tiny Tapeout (RTL-заготовки; кристалла нет).',
    open: 'Открыть прогон',
    caveat: 'Четыре факта и команда под каждым. Все они структурные: ни один не говорит, что дизайн верен, — и сводка каждого прогона говорит это теми же словами.',
  },
}

function line(text: string, i: number) {
  // "- **PASS** elaborates — every module ..." → verdict + rest
  const m = text.match(/^- \*\*(\w+)\*\*\s*(.*)$/)
  const verdict = m ? m[1] : ''
  const rest = m ? m[2] : text.replace(/^- /, '')
  const colour = verdict === 'PASS' ? 'var(--accent)' : verdict === 'FAIL' ? '#ff8a6b' : 'inherit'
  return (
    <li key={i} style={{ display: 'flex', gap: '0.6rem', alignItems: 'baseline', marginBottom: '0.3rem' }}>
      <span style={{ color: colour, fontWeight: 700, fontSize: '0.74rem', letterSpacing: '0.06em', minWidth: '3.2rem' }}>
        {verdict}
      </span>
      <span style={{ fontSize: '0.86rem', lineHeight: 1.55, opacity: 0.9 }}>{rest}</span>
    </li>
  )
}

export default function ExampleReport() {
  const { lang } = useI18n()
  const t = lang === 'ru' ? T.ru : T.en

  if (!JOBS.length) return null

  return (
    <div className="premium-card" style={{ textAlign: 'left', marginBottom: '2rem' }}>
      <h3 style={{ fontSize: 'clamp(1.1rem, 3vw, 1.4rem)', marginTop: 0, marginBottom: '0.5rem' }}>{t.h3}</h3>
      <p style={{ fontSize: '0.92rem', lineHeight: 1.6, opacity: 0.85, margin: '0 0 1.2rem', maxWidth: '68ch' }}>{t.lede}</p>

      <div style={{ display: 'grid', gap: '1rem', marginBottom: '1.1rem' }}>
        {JOBS.map((j) => (
          <div key={j.name} style={{
            padding: '0.9rem 1rem', borderRadius: '10px',
            background: 'rgba(0,0,0,0.28)', border: '1px solid rgba(255,255,255,0.08)',
          }}>
            <p style={{ margin: '0 0 0.6rem', fontFamily: 'monospace', fontSize: '0.78rem', opacity: 0.7 }}>{j.name}</p>
            <ul style={{ listStyle: 'none', margin: 0, padding: 0 }}>{j.lines.map(line)}</ul>
          </div>
        ))}
      </div>

      <p style={{ fontSize: '0.84rem', lineHeight: 1.6, opacity: 0.75, margin: '0 0 0.9rem' }}>{t.caveat}</p>

      <a href={report.runUrl} target="_blank" rel="noopener noreferrer" className="btn secondary"
         style={{ padding: '9px 20px', fontSize: '0.82rem' }}>
        {t.open} · {report.sha} · {(report.at ?? '').slice(0, 10)}
      </a>
    </div>
  )
}
