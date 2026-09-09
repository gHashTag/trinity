// The ladder every Explorer stands on: Specs → Skills → Crons → Agents → Tools → Functions.
//
// One compact strip, one link and one live count per layer, drawn from the
// catalog the page already loaded (spec-agents.json carries `ladder`). The
// counts are generated, never typed here; a layer whose count the catalog
// could not measure shows `—` rather than a remembered number.

import { C } from '../lib/explorerTheme'

export interface LadderStep {
  key: string
  label: string
  count: number | null
  href: string
  /** The layer the reader is standing on; drawn as the current step. */
  current?: boolean
}

export function LayerLadder({ steps, caption }: { steps: LadderStep[]; caption?: string }) {
  return (
    <nav
      aria-label={caption}
      className="spec-x-ladder"
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 6,
        flexWrap: 'wrap',
        padding: '6px 14px',
        borderBottom: `1px solid ${C.border}`,
        background: C.panel,
        fontFamily: C.mono,
        fontSize: 11,
      }}
    >
      {caption && <span style={{ color: C.muted, marginRight: 4 }}>{caption}</span>}
      {steps.map((s, i) => (
        <span key={s.key} style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          {i > 0 && <span aria-hidden="true" style={{ color: C.muted }}>→</span>}
          <a
            href={s.href}
            aria-current={s.current ? 'page' : undefined}
            style={{
              display: 'inline-flex',
              alignItems: 'baseline',
              gap: 5,
              padding: '2px 8px',
              borderRadius: 4,
              border: `1px solid ${s.current ? C.accent : C.border}`,
              color: s.current ? C.accent : '#d8d8d8',
              textDecoration: 'none',
            }}
          >
            <span>{s.label}</span>
            <b style={{ color: s.current ? C.accent : C.golden }} data-lang-exempt="live">
              {s.count === null ? '—' : s.count}
            </b>
          </a>
        </span>
      ))}
    </nav>
  )
}
