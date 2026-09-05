// Inline SVG for the spec explorer. No chart library: every shape here is a
// handful of rects, which stays sharp at 12px and adds nothing to the bundle.

import type { Health, T27Analysis } from '../lib/t27Compiler'

export const HEALTH_COLOR: Record<Health, string> = {
  ok: '#00FF88',
  warn: '#f0a020',
  fail: '#f85149',
}

/**
 * Corpus health as one stacked bar.
 *
 * A waffle chart (one cell per spec) was the other candidate and is prettier,
 * but 668 cells cannot be read as proportions and the six failures would be
 * three pixels lost in the grid. A stacked bar keeps the ratio legible and the
 * counts live in the legend beside it, where they can be exact.
 */
export function HealthBar({ health, total }: { health: Record<Health, number>; total: number }) {
  const order: Health[] = ['ok', 'warn', 'fail']
  let x = 0
  return (
    <svg
      viewBox="0 0 100 3"
      preserveAspectRatio="none"
      style={{ width: '100%', height: 6, display: 'block', borderRadius: 3, overflow: 'hidden' }}
      role="img"
      aria-label={`${health.ok} healthy, ${health.warn} with warnings, ${health.fail} failing, of ${total}`}
    >
      {order.map((k) => {
        const w = total > 0 ? (health[k] / total) * 100 : 0
        const el = <rect key={k} x={x} y={0} width={w} height={3} fill={HEALTH_COLOR[k]} />
        x += w
        return el
      })}
    </svg>
  )
}

/** A single spec's status as a 3px rail. Sits in a list row without adding height. */
export function HealthDot({ health }: { health: Health }) {
  return (
    <span
      aria-hidden="true"
      style={{
        display: 'inline-block',
        width: 3,
        height: 13,
        borderRadius: 2,
        background: HEALTH_COLOR[health],
        flexShrink: 0,
      }}
    />
  )
}

interface Stage {
  key: string
  label: string
  /** null = this stage produced nothing. */
  value: number | null
  ok: boolean
}

/**
 * The pipeline as a row of bars, one per stage, height scaled to output size.
 *
 * This is the view that answers "where does this spec die?" and "why is the
 * Verilog four times the Zig?" without opening five tabs. Magnitude is encoded
 * as height on a shared log scale -- linear would flatten every stage next to
 * a 45 KB Verilog output.
 */
export function PipelineRibbon({
  result,
  active,
  onPick,
  labels,
}: {
  result: T27Analysis
  active: string
  onPick: (id: string) => void
  labels: Record<string, string>
}) {
  const stages: Stage[] = [
    { key: 'source', label: labels.source, value: result.sourceBytes, ok: true },
    { key: 'tokens', label: labels.tokens, value: result.tokenCount, ok: true },
    { key: 'ast', label: labels.ast, value: result.nodeCount ?? null, ok: !result.astError },
    { key: 'typecheck', label: labels.typecheck, value: result.typecheck?.errorCount ?? 0, ok: (result.typecheck?.errorCount ?? 0) === 0 },
    { key: 'hir', label: labels.hir, value: result.hir.ok ? result.hir.text?.length ?? 0 : null, ok: result.hir.ok },
    ...['zig', 'verilog', 'verilog_hir', 'c', 'rust'].map((k) => ({
      key: k,
      label: labels[k],
      value: result.targets[k]?.ok ? result.targets[k].bytes ?? 0 : null,
      ok: !!result.targets[k]?.ok,
    })),
  ]

  const max = Math.max(...stages.map((s) => (s.value && s.value > 0 ? Math.log10(s.value + 1) : 0)), 1)

  return (
    <div style={{ display: 'flex', gap: 3, alignItems: 'flex-end', height: 34 }}>
      {stages.map((s) => {
        const mag = s.value && s.value > 0 ? Math.log10(s.value + 1) / max : 0
        const h = s.ok ? Math.max(3, mag * 26) : 26
        const color = !s.ok ? HEALTH_COLOR.fail : s.key === 'typecheck' && (s.value ?? 0) > 0 ? HEALTH_COLOR.warn : HEALTH_COLOR.ok
        const isActive = active === s.key
        return (
          <button
            key={s.key}
            onClick={() => onPick(s.key)}
            title={`${s.label}: ${s.ok ? (s.value ?? 0).toLocaleString() : 'failed'}`}
            aria-label={`${s.label}, ${s.ok ? String(s.value ?? 0) : 'failed'}`}
            style={{
              flex: 1,
              minWidth: 0,
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'flex-end',
              height: '100%',
              background: 'transparent',
              border: 'none',
              padding: 0,
              cursor: 'pointer',
            }}
          >
            <span
              style={{
                display: 'block',
                height: h,
                background: color,
                opacity: isActive ? 1 : 0.42,
                borderRadius: 2,
                // Hover/selection is the only thing that moves here; the bar
                // heights are data and must not animate on every spec change.
                transition: 'opacity 140ms ease-out',
              }}
            />
          </button>
        )
      })}
    </div>
  )
}
