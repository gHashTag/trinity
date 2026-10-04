// The Explorer family's shared look: the Spec Explorer's palette and the few
// inline styles every sibling page (skills, crons, clients) repeats. Lifted
// here so a second explorer cannot drift a shade away from the first.
//
// Values are the site's own tokens (index.css :root); panels sit a step above
// pure black because white text on #000 smears during scroll on OLED.

export const C = {
  bg: '#000000',
  panel: '#0b0d0c',
  raised: '#121614',
  border: 'rgba(0,255,136,0.10)',
  borderBright: 'rgba(0,255,136,0.34)',
  text: '#FFFFFF',
  muted: '#8b9490',
  accent: '#00FF88',
  golden: '#FFD700',
  bad: '#f85149',
  warn: '#f0a020',
  blue: '#58a6ff',
  mono: "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace",
} as const

export type Health = 'ok' | 'warn' | 'fail'

export const HEALTH_COLOR: Record<Health, string> = { ok: C.accent, warn: C.warn, fail: C.bad }

/** Shape as well as colour, so status survives a colour-blind reader. */
export const HEALTH_GLYPH: Record<Health, string> = { ok: '✓', warn: '⚠', fail: '✕' }

export function tagChip(on: boolean, dead: boolean): React.CSSProperties {
  return {
    background: on ? 'rgba(0,255,136,0.14)' : 'transparent',
    border: `1px solid ${on ? C.accent : C.border}`,
    borderRadius: 999,
    color: dead ? 'rgba(139,148,144,0.35)' : on ? C.accent : C.muted,
    padding: '1px 7px',
    cursor: dead ? 'default' : 'pointer',
    fontSize: 10.5,
    fontFamily: C.mono,
  }
}

export const ctrlBtn: React.CSSProperties = {
  background: 'transparent',
  border: `1px solid ${C.border}`,
  borderRadius: 4,
  color: C.muted,
  padding: '3px 9px',
  cursor: 'pointer',
  fontSize: 11.5,
  fontFamily: 'inherit',
}

export const preStyle: React.CSSProperties = {
  margin: 0,
  padding: 14,
  fontFamily: C.mono,
  fontSize: 12.5,
  lineHeight: 1.6,
  color: '#d8d8d8',
  whiteSpace: 'pre-wrap',
  wordBreak: 'break-word',
}

export const pill: React.CSSProperties = {
  background: 'transparent',
  border: '1px solid rgba(0,255,136,0.18)',
  borderRadius: 999,
  color: C.muted,
  padding: '2px 10px',
  fontSize: 10.5,
  fontFamily: C.mono,
  textDecoration: 'none',
  cursor: 'pointer',
  whiteSpace: 'nowrap',
}

export const inputStyle: React.CSSProperties = {
  background: C.raised,
  border: `1px solid ${C.border}`,
  borderRadius: 4,
  color: C.text,
  padding: '7px 9px',
  fontSize: 13,
  fontFamily: 'inherit',
  outline: 'none',
}

/** The panel every layer body sits in; embedded frames get a veil, pages a panel. */
export function panelBox(embedded: boolean): React.CSSProperties {
  return {
    background: embedded ? 'rgba(2, 8, 6, 0.66)' : C.panel,
    ...(embedded ? { backdropFilter: 'blur(7px)' } : null),
    border: `1px solid ${C.border}`,
    borderRadius: 6,
  }
}

export function fmtBytes(n: number): string {
  if (n < 1024) return `${n}B`
  return `${(n / 1024).toFixed(1)}K`
}

/** The chevron the /specs category select draws, with room around it. */
export const selectStyle: React.CSSProperties = {
  appearance: 'none',
  background: `${C.raised} url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath d='m2 4 4 4 4-4' fill='none' stroke='%23e7f7fa' stroke-width='1.6' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E") no-repeat right 10px center`,
  backgroundSize: '11px 11px',
  border: `1px solid ${C.border}`,
  borderRadius: 4,
  color: C.text,
  padding: '6px 32px 6px 8px',
  fontSize: 12.5,
  fontFamily: 'inherit',
  outline: 'none',
}
