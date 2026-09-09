// The header every Explorer page wears: back link, title, subtitle, a
// provenance line naming the snapshot each source came from, and the language
// switcher. Lifted out of SpecExplorer so a second explorer cannot drift a
// pixel away from the first.
//
// Everything after the title may shrink and then clip: on a narrow window the
// provenance would otherwise wrap under the heading and overlap it. The title
// truncates rather than refusing to give, because a control standing beside a
// heading must stay reachable — that is what pushed the switcher off a 375px
// screen once already.

import { Link } from 'react-router-dom'
import LanguageSwitcher from './LanguageSwitcher'
import { C } from '../lib/explorerTheme'

export interface Provenance {
  /** owner/name, as the manifest records it. */
  repo: string
  shortCommit: string
  dirty?: boolean
  /** A private repository has no public link to its files. */
  private?: boolean
}

export function ExplorerHeader({
  title,
  subtitle,
  back,
  backHref = '/',
  note,
  provenance,
  provenanceLabel,
  dirtyLabel,
  narrow,
  phone,
  right,
}: {
  title: string
  subtitle: string
  back: string
  backHref?: string
  /** A short claim shown in accent, e.g. "Real compiler, run in your browser". */
  note?: string
  provenance?: Provenance[]
  provenanceLabel?: string
  dirtyLabel?: string
  narrow: boolean
  phone: boolean
  /** Replaces the provenance block, e.g. a session panel. */
  right?: React.ReactNode
}) {
  return (
    <header
      style={{
        minHeight: 52,
        flexShrink: 0,
        borderBottom: `1px solid ${C.border}`,
        display: 'flex',
        alignItems: 'center',
        gap: 16,
        padding: '0 16px',
        overflow: 'hidden',
      }}
    >
      <Link to={backHref} style={{ color: C.muted, textDecoration: 'none', fontSize: 13, flexShrink: 0 }}>
        {back}
      </Link>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, minWidth: 0, flexShrink: 1 }}>
        <span
          style={{
            fontSize: 16,
            fontWeight: 700,
            color: C.golden,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {title}
        </span>
        {!narrow && (
          <span style={{ fontSize: 12, color: C.muted, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            {subtitle}
          </span>
        )}
      </div>
      <div
        style={{
          marginLeft: 'auto',
          display: 'flex',
          alignItems: 'center',
          gap: 14,
          fontSize: 11,
          color: C.muted,
          minWidth: 0,
          overflow: 'hidden',
        }}
      >
        {note && !narrow && <span style={{ color: C.accent, whiteSpace: 'nowrap', flexShrink: 0 }}>◆ {note}</span>}
        {right}
        {/* Not on a phone: provenance is developer metadata about which
            snapshot is loaded, and truncated to nine characters it tells
            nobody anything. The page title is its identity. */}
        {!right && provenance && provenance.length > 0 && !phone && (
          <span
            style={{ fontFamily: C.mono, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', minWidth: 0 }}
            title={provenance.map((p) => `${p.repo}@${p.shortCommit}`).join('  ')}
          >
            {provenanceLabel}{' '}
            {provenance.map((p, i) => (
              <span key={p.repo}>
                {i > 0 && ' · '}
                {p.repo.split('/').pop()}@{p.shortCommit}
                {p.dirty && dirtyLabel ? ` (${dirtyLabel})` : ''}
              </span>
            ))}
          </span>
        )}
      </div>
      {/* Outside the provenance block and never shrinking: that block is
          deliberately allowed to clip, and a control that disappears on a
          narrow header is the bug this fixed, not a smaller version of it. */}
      <div style={{ flexShrink: 0, display: 'flex', alignItems: 'center', marginLeft: 12 }}>
        <LanguageSwitcher />
      </div>
    </header>
  )
}
