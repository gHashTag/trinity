// The Queen's SKILLS and CRONS views: the real Skill and Cron Explorers,
// inside the game.
//
// Same shape as QueenSpecs, for the same reasons: the Explorers own a
// full-viewport layout and the Skill/Cron pages boot the compiler wasm to
// colour their specs, so each is an iframe of our own page at
// #/skills?embed=1 or #/crons?embed=1 — a layout boundary, not a sandbox one.
//
// The strip above the frame (or beside it, on a wide screen) reads the generated
// spec catalog and states the witness split in numbers: how many specs, how many
// backed by code, how many cards have code and no spec yet, and how many the
// compiler accepted. It counts; it does not grade.

import { useEffect, useRef, useState } from 'react'
import { useI18n } from '../i18n/context'
import { QueenLoading } from './QueenLoading'
import { loadCronSpecs, loadSkillSpecs } from '../lib/agentSpecs'

export type AgentsKind = 'skills' | 'crons'

export interface AgentsCopy {
  directive: string
  directiveBody: string
  open: string
  loading: string
  specs: string
  specPlusCode: string
  codeOnly: string
  typecheck: string
}

interface Counts { specs: number; specPlusCode: number; codeOnly: number; typecheckOk: number }

async function loadCounts(kind: AgentsKind): Promise<Counts> {
  const c = kind === 'skills' ? (await loadSkillSpecs()).counts : (await loadCronSpecs()).counts
  return { specs: c.specs, specPlusCode: c.specPlusCode, codeOnly: c.codeOnly, typecheckOk: c.typecheckOk }
}

/** The directive, the witness counts and the way out to the full page. */
export function QueenAgentsDirective({ kind, c, collapsible = false }: { kind: AgentsKind; c: AgentsCopy; collapsible?: boolean }) {
  const [counts, setCounts] = useState<Counts | null>(null)

  useEffect(() => {
    let alive = true
    loadCounts(kind)
      .then((n) => { if (alive) setCounts(n) })
      .catch(() => {})
    return () => { alive = false }
  }, [kind])

  const body = (
    <>
      <p>{c.directiveBody}</p>
      {counts && (
        <span className="queen27-specs-counts">
          <b style={{ color: '#00FF88' }}>{counts.specs}</b> {c.specs}
          {' · '}
          <b style={{ color: '#00FF88' }}>{counts.specPlusCode}</b> {c.specPlusCode}
          {' · '}
          <b style={{ color: counts.codeOnly ? '#f0a020' : '#8b9490' }}>{counts.codeOnly}</b> {c.codeOnly}
          {' · '}
          <b style={{ color: counts.typecheckOk === counts.specs ? '#00FF88' : '#f85149' }}>
            {counts.typecheckOk}/{counts.specs}
          </b>{' '}
          {c.typecheck}
        </span>
      )}
      <a className="queen27-specs-open" href={`#/${kind}`} target="_blank" rel="noopener">
        {c.open}
      </a>
    </>
  )

  if (collapsible) {
    return (
      <details className="queen27-specs-strip is-collapsible">
        <summary>{c.directive}</summary>
        {body}
      </details>
    )
  }

  return (
    <div className="queen27-specs-strip">
      <span className="queen27-section-label">{c.directive}</span>
      {body}
    </div>
  )
}

export function QueenAgents({ kind, c, showDirective = true }: { kind: AgentsKind; c: AgentsCopy; showDirective?: boolean }) {
  const { lang } = useI18n()
  const [ready, setReady] = useState(false)
  const frameRef = useRef<HTMLIFrameElement>(null)

  // ?lang= rides in the search, where the i18n provider reads it, so the frame
  // follows the shell's language instead of whatever localStorage held.
  const src = `${window.location.pathname}?lang=${lang}#/${kind}?embed=1`

  return (
    <div className="queen27-specs" data-directive={showDirective ? 'above' : 'aside'}>
      {showDirective && <QueenAgentsDirective kind={kind} c={c} collapsible />}

      <div className="queen27-specs-frame-wrap">
        {!ready && (
          <div className="queen27-specs-loading">
            <QueenLoading title={c.loading} facts={[kind === 'skills' ? 'specs/skills/*.t27' : 'specs/crons/*.t27']} />
          </div>
        )}
        <iframe
          ref={frameRef}
          className="queen27-specs-frame"
          src={src}
          title={kind === 'skills' ? 'Skill Explorer' : 'Cron Explorer'}
          onLoad={() => setReady(true)}
          loading="lazy"
        />
      </div>
    </div>
  )
}
