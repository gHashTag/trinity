// Generation metrics for one compile, with deltas against the spec as shipped.
//
// The delta is the point. Compiling edited source and showing "3481 tokens" in
// isolation says nothing; showing "3481 (+42)" next to what the original
// produced turns the page into an instrument you can actually experiment with.

import type { T27Analysis } from '../lib/t27Compiler'

const MONO = "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace"
const OK = '#00FF88'
const BAD = '#f85149'
const WARN = '#f0a020'
const MUTED = '#8b9490'

interface Row {
  label: string
  value: string
  delta?: number
  /** For counts where growth is neutral (tokens), not good or bad. */
  neutral?: boolean
  bad?: boolean
}

function fmt(n: number): string {
  return n >= 1024 ? `${(n / 1024).toFixed(1)}K` : String(n)
}

function deltaColor(d: number, neutral: boolean, bad: boolean): string {
  if (d === 0) return MUTED
  if (neutral) return MUTED
  // For error counts, up is bad and down is good; for output size, neither.
  return bad ? (d > 0 ? BAD : OK) : d > 0 ? OK : BAD
}

export function SpecMetrics({
  result,
  baseline,
  ms,
  labels,
}: {
  result: T27Analysis
  /** The unedited spec's result, when the source has been changed. */
  baseline?: T27Analysis | null
  ms: number | null
  labels: Record<string, string>
}) {
  const d = (now: number, before?: number) => (baseline && before !== undefined ? now - before : undefined)

  const front: Row[] = [
    { label: labels.tokens, value: fmt(result.tokenCount), delta: d(result.tokenCount, baseline?.tokenCount), neutral: true },
    { label: labels.nodes, value: fmt(result.nodeCount ?? 0), delta: d(result.nodeCount ?? 0, baseline?.nodeCount ?? 0), neutral: true },
    { label: labels.depth, value: String(result.astDepth ?? 0), delta: d(result.astDepth ?? 0, baseline?.astDepth ?? 0), neutral: true },
    {
      label: labels.typeErrs,
      value: String(result.typecheck?.errorCount ?? 0),
      delta: d(result.typecheck?.errorCount ?? 0, baseline?.typecheck?.errorCount ?? 0),
      bad: true,
    },
    {
      label: labels.droppedItems,
      value: String(result.discarded.length + result.swallowed.length + result.lexerDiscarded.length),
      delta: d(
        result.discarded.length + result.swallowed.length + result.lexerDiscarded.length,
        baseline ? baseline.discarded.length + baseline.swallowed.length + baseline.lexerDiscarded.length : undefined,
      ),
      bad: true,
    },
  ]

  const targets = ['zig', 'verilog', 'verilog_hir', 'c', 'rust']

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap', fontFamily: MONO, fontSize: 11.5 }}>
        {front.map((r) => (
          <span key={r.label} style={{ color: MUTED }}>
            {r.label}{' '}
            <span style={{ color: '#d6dde4' }}>{r.value}</span>
            {r.delta !== undefined && r.delta !== 0 && (
              <span style={{ color: deltaColor(r.delta, !!r.neutral, !!r.bad), marginLeft: 3 }}>
                {r.delta > 0 ? '+' : ''}
                {r.delta}
              </span>
            )}
          </span>
        ))}
        {ms !== null && <span style={{ color: MUTED, opacity: 0.7 }}>{ms.toFixed(0)}ms</span>}
      </div>

      {/* What each backend produced, which is the thing an edit is usually
          aimed at changing. */}
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
        {targets.map((k) => {
          const t = result.targets[k]
          const b = baseline?.targets?.[k]
          const delta = baseline && t?.ok && b?.ok ? (t.bytes ?? 0) - (b.bytes ?? 0) : undefined
          const broke = baseline && b?.ok && !t?.ok
          const fixed = baseline && !b?.ok && t?.ok
          return (
            <span
              key={k}
              title={t?.ok ? `${t.bytes} bytes` : t?.error || 'no output'}
              style={{
                display: 'inline-flex',
                alignItems: 'baseline',
                gap: 4,
                padding: '2px 7px',
                borderRadius: 3,
                border: `1px solid ${t?.ok ? 'rgba(0,255,136,0.22)' : BAD}`,
                background: broke ? 'rgba(248,81,73,0.12)' : fixed ? 'rgba(0,255,136,0.10)' : 'transparent',
                fontFamily: MONO,
                fontSize: 10.5,
                color: t?.ok ? MUTED : BAD,
              }}
            >
              <span>{labels[k] ?? k}</span>
              <span style={{ color: t?.ok ? '#d6dde4' : BAD }}>{t?.ok ? fmt(t.bytes ?? 0) : '✕'}</span>
              {delta !== undefined && delta !== 0 && (
                <span style={{ color: MUTED }}>
                  {delta > 0 ? '+' : ''}
                  {delta}
                </span>
              )}
              {broke && <span style={{ color: BAD }}>{labels.brokeIt}</span>}
              {fixed && <span style={{ color: OK }}>{labels.fixedIt}</span>}
            </span>
          )
        })}
      </div>

      {result.astError && (
        <div style={{ color: BAD, fontFamily: MONO, fontSize: 11.5 }}>{result.astError}</div>
      )}
      {!result.astError && (result.typecheck?.errorCount ?? 0) > 0 && (
        <div style={{ color: WARN, fontFamily: MONO, fontSize: 11, opacity: 0.9 }}>
          {result.typecheck?.errors?.[0]}
        </div>
      )}
    </div>
  )
}
