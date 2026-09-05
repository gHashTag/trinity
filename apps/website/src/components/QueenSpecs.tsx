// The Queen's spec view: the corpus she is meant to be generated from.
//
// This is the doctrine's own scoreboard. The stated goal is that the whole
// project is generated from .t27 -- so the honest thing to show here is not a
// banner saying so, but how far that actually is, measured. The numbers come
// from the same manifest the Spec Explorer uses, which is produced by running
// the real compiler over every spec.
//
// Deliberately shows the gap. A directive with no counter next to it is a
// slogan; a directive with 522/760 next to it is a plan.

import { useEffect, useState } from 'react'

interface Manifest {
  specCount: number
  totalLines: number
  health: { ok: number; warn: number; fail: number }
  repos: { repo: string; specs: number }[]
  totals: { tokens: number; nodes: number }
  generatedFrom: { repo: string; shortCommit: string }
}

const OK = '#00FF88'
const WARN = '#f0a020'
const BAD = '#f85149'

export interface SpecsCopy {
  title: string
  directive: string
  directiveBody: string
  corpus: string
  clean: string
  warnings: string
  broken: string
  specs: string
  lines: string
  nodes: string
  sources: string
  open: string
  gapTitle: string
  gapBody: string
  unavailable: string
  loading: string
}

export function QueenSpecs({ c }: { c: SpecsCopy }) {
  const [m, setM] = useState<Manifest | null>(null)
  const [err, setErr] = useState(false)

  useEffect(() => {
    let alive = true
    fetch('t27/manifest.json')
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(String(r.status)))))
      .then((d) => { if (alive) setM(d) })
      .catch(() => { if (alive) setErr(true) })
    return () => { alive = false }
  }, [])

  if (err) return <div className="queen27-specs-empty">{c.unavailable}</div>
  if (!m) return <div className="queen27-specs-empty">{c.loading}</div>

  const pct = (n: number) => ((n / m.specCount) * 100).toFixed(1)

  return (
    <div className="queen27-specs">
      <section className="queen27-specs-directive">
        <span className="queen27-section-label">{c.directive}</span>
        <p>{c.directiveBody}</p>
      </section>

      <section className="queen27-specs-bar" aria-label={c.corpus}>
        <svg viewBox="0 0 100 3" preserveAspectRatio="none" role="img"
             aria-label={`${m.health.ok} ${c.clean}, ${m.health.warn} ${c.warnings}, ${m.health.fail} ${c.broken}`}>
          <rect x="0" y="0" width={pct(m.health.ok)} height="3" fill={OK} />
          <rect x={pct(m.health.ok)} y="0" width={pct(m.health.warn)} height="3" fill={WARN} />
          <rect x={Number(pct(m.health.ok)) + Number(pct(m.health.warn))} y="0" width={pct(m.health.fail)} height="3" fill={BAD} />
        </svg>
      </section>

      <section className="queen27-specs-stats">
        <div><strong style={{ color: OK }}>{m.health.ok}</strong><span>{c.clean}</span></div>
        <div><strong style={{ color: WARN }}>{m.health.warn}</strong><span>{c.warnings}</span></div>
        <div><strong style={{ color: BAD }}>{m.health.fail}</strong><span>{c.broken}</span></div>
        <div><strong>{m.specCount}</strong><span>{c.specs}</span></div>
        <div><strong>{m.totalLines.toLocaleString()}</strong><span>{c.lines}</span></div>
        <div><strong>{m.totals.nodes.toLocaleString()}</strong><span>{c.nodes}</span></div>
      </section>

      <section className="queen27-specs-repos">
        <span className="queen27-section-label">{c.sources}</span>
        <ul>
          {m.repos.map((r) => (
            <li key={r.repo}><code>{r.repo}</code><span>{r.specs}</span></li>
          ))}
        </ul>
      </section>

      {/* The part that keeps this honest. */}
      <section className="queen27-specs-gap">
        <span className="queen27-section-label">{c.gapTitle}</span>
        <p>{c.gapBody}</p>
      </section>

      <a className="queen27-specs-open" href="#/specs">{c.open}</a>
    </div>
  )
}
