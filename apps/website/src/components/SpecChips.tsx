// The link between a skill and the .t27 spec it stands on, drawn in both
// directions.
//
// Forward (skill → spec) is DECLARED: the skill's own `specs:` frontmatter, or
// the site's public/skills/bindings.json for repositories whose files are not
// ours to edit. Backward (spec → skill) is DERIVED at index time and never
// written into a .t27 file: a spec is an issue-bound, test-carrying artifact,
// and a generated back-reference inside one would be hand-written state in a
// repository whose laws forbid exactly that.
//
// A path found in a skill's prose is a CANDIDATE, shown with its status.
// Discovery is evidence, never acceptance — the same wording the shared spec
// core uses for import resolution.

import { useEffect, useState } from 'react'
import { specExplorerHash } from '../lib/specCatalog'
import { skillExplorerHash } from '../lib/skillsCatalog'
import { loadSkillsCore, type SkillSpecRef } from '../lib/skillsLoader'
import { C } from '../lib/explorerTheme'

const STATUS_COLOR: Record<string, string> = {
  resolved: C.accent,
  ambiguous: C.warn,
  missing: C.bad,
}

function chipStyle(color: string): React.CSSProperties {
  return {
    display: 'inline-flex',
    alignItems: 'center',
    gap: 5,
    background: 'transparent',
    border: `1px solid ${color}`,
    borderRadius: 999,
    color,
    padding: '1px 9px',
    fontSize: 10.5,
    fontFamily: C.mono,
    textDecoration: 'none',
    whiteSpace: 'nowrap',
    maxWidth: '100%',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  }
}

/** In the Skill Explorer: the specs one skill names, declared ones first. */
export function SkillSpecChips({
  refs,
  labels,
  onOpen,
}: {
  refs: SkillSpecRef[]
  labels: { declared: string; candidate: string; missing: string; ambiguous: string; openSpec: string; via: Record<string, string> }
  /** Opens the spec inside the page instead of navigating away. */
  onOpen?: (path: string) => void
}) {
  if (!refs.length) return null
  const ordered = [...refs].sort((a, b) => Number(b.declared) - Number(a.declared) || a.text.localeCompare(b.text))
  return (
    <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
      {ordered.map((r) => {
        const color = STATUS_COLOR[r.status] ?? C.muted
        const title = [
          r.declared ? labels.declared : labels.candidate,
          labels.via[r.via] ?? r.via,
          r.status === 'missing' ? labels.missing : r.status === 'ambiguous' ? labels.ambiguous : '',
          ...(r.candidates.length > 1 ? r.candidates : []),
        ]
          .filter(Boolean)
          .join(' · ')
        const label = (
          <>
            <span aria-hidden="true">{r.declared ? '◆' : '·'}</span>
            <span style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.to ?? r.text}</span>
          </>
        )
        if (!r.to) {
          return (
            <span key={`${r.via}:${r.text}`} title={title} style={{ ...chipStyle(color), opacity: 0.85 }}>
              {label}
            </span>
          )
        }
        const to = r.to
        return onOpen ? (
          <button key={`${r.via}:${r.text}`} onClick={() => onOpen(to)} title={`${labels.openSpec} · ${title}`} style={{ ...chipStyle(color), cursor: 'pointer' }}>
            {label}
          </button>
        ) : (
          <a key={`${r.via}:${r.text}`} href={specExplorerHash(to)} title={`${labels.openSpec} · ${title}`} style={chipStyle(color)}>
            {label}
          </a>
        )
      })}
    </div>
  )
}

/**
 * In the Spec Explorer: the skills that stand on this spec.
 *
 * The derived direction, read from the same skills-core.json the coverage
 * layer reads. It renders nothing at all when the corpus has no skill for this
 * spec, and nothing when the catalog is unreachable: a spec page must not grow
 * an empty box because a sibling artifact failed to load.
 */
export function SpecSkillChips({
  specPath,
  labels,
}: {
  specPath: string
  labels: { skillsUsing: string; openSkill: string }
}) {
  const [ids, setIds] = useState<string[]>([])
  useEffect(() => {
    let alive = true
    loadSkillsCore()
      .then((core) => {
        if (alive) setIds(core.specToSkills?.[specPath] ?? [])
      })
      .catch(() => {
        if (alive) setIds([])
      })
    return () => {
      alive = false
    }
  }, [specPath])

  if (!ids.length) return null
  return (
    <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap', alignItems: 'center' }}>
      <span style={{ fontSize: 10, color: C.muted, opacity: 0.7, fontFamily: C.mono }}>{labels.skillsUsing}</span>
      {ids.map((id) => (
        <a key={id} href={skillExplorerHash(id)} title={`${labels.openSkill}: ${id}`} style={chipStyle(C.golden)}>
          <span aria-hidden="true">◆</span>
          <span style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>{id.split('/')[1]}</span>
        </a>
      ))}
    </div>
  )
}
