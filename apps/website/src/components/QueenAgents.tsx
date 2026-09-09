// The Queen's SKILLS, CRONS, AGENTS, FUNCTIONS, TOOLS and PROJECT views: the real Skill,
// Cron, Agent, Function and Tool Explorers and the system documentation, inside the game.
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
import { loadAgentSpecs, loadCronSpecs, loadFunctionSpecs, loadSkillSpecs, loadToolSpecs } from '../lib/agentSpecs'
import { loadSystemDocs, systemDocsHash } from '../lib/systemDocs'

export type AgentsKind = 'skills' | 'crons' | 'agents' | 'functions' | 'tools' | 'project'

// PROJECT frames #/docs?embed=1. The quick jumps above the frame rewrite the
// frame's hash to a chapter; the page inside follows hashchange, so a jump is a
// chapter switch, not a reload. Chapter stems are those of specs/docs/chapters.
export const PROJECT_JUMPS: readonly { stem: string; en: string; ru: string }[] = [
  { stem: 'project', en: 'Project', ru: 'Проект' },
  { stem: 'rules', en: 'Rules of the game', ru: 'Правила игры' },
  { stem: 'layers', en: 'System', ru: 'Система' },
  { stem: 'alphabet', en: 'Alphabet', ru: 'Алфавит' },
  { stem: 'tooling', en: 'Tools', ru: 'Инструменты' },
  { stem: 'evidence', en: 'Evidence', ru: 'Свидетели' },
] as const

export interface AgentsCopy {
  directive: string
  directiveBody: string
  open: string
  loading: string
  specs: string
  specPlusCode: string
  codeOnly: string
  typecheck: string
  /** Agents only: the witness is experience, and the third number is what no letter claims. */
  specPlusExperience?: string
  unattributed?: string
  /** Tools only: the split is ownership — how many an agent's spec and a source bind, how many nobody has yet. */
  toolsOwned?: string
  toolsUnowned?: string
  /** Project only: chapters, chapters with a Russian body, and sources pinned. */
  projectChapters?: string
  projectRu?: string
  projectSources?: string
}

// For skills and crons the third figure is code-only cards; for agents it is
// the episodes no letter claims (`unattributed`), which is a fact about the log,
// not a defect of any agent. For tools the pair is owned / not yet owned: an
// unbound tool is a gap in the alphabet's bindings, not a broken spec.
interface Counts { specs: number; specPlusCode: number; codeOnly: number; typecheckOk: number; typecheckTotal?: number }

async function loadCounts(kind: AgentsKind): Promise<Counts> {
  if (kind === 'project') {
    // chapters / chapters with a RU body / sources pinned / typecheck ok over document+chapters
    const d = await loadSystemDocs()
    return { specs: d.counts.chapters, specPlusCode: d.counts.ruChapters, codeOnly: d.counts.sources, typecheckOk: d.counts.typecheckOk, typecheckTotal: d.chapters.length + 1 }
  }
  if (kind === 'agents') {
    const c = (await loadAgentSpecs()).counts
    return { specs: c.specs, specPlusCode: c.specPlusExperience, codeOnly: c.episodesUnattributed ?? 0, typecheckOk: c.typecheckOk }
  }
  if (kind === 'functions') {
    // The witness is the vendored functions manifest; code-only are the
    // manifest entries no spec states yet.
    const c = (await loadFunctionSpecs()).counts
    return { specs: c.specs, specPlusCode: c.specPlusCode, codeOnly: c.codeOnly, typecheckOk: c.typecheckOk }
  }
  if (kind === 'tools') {
    const c = (await loadToolSpecs()).counts
    return { specs: c.specs, specPlusCode: c.withAgents, codeOnly: c.specs - c.withAgents, typecheckOk: c.typecheckOk }
  }
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
          <b style={{ color: '#00FF88' }}>{counts.specs}</b> {kind === 'project' ? c.projectChapters ?? c.specs : c.specs}
          {' · '}
          <b style={{ color: (kind === 'agents' || kind === 'tools') && counts.specPlusCode === 0 ? '#8b9490' : '#00FF88' }}>{counts.specPlusCode}</b>{' '}
          {kind === 'agents' ? c.specPlusExperience ?? c.specPlusCode : kind === 'tools' ? c.toolsOwned ?? c.specPlusCode : kind === 'project' ? c.projectRu ?? c.specPlusCode : c.specPlusCode}
          {' · '}
          <b style={{ color: kind === 'project' ? '#00FF88' : counts.codeOnly ? '#f0a020' : '#8b9490' }}>{counts.codeOnly}</b>{' '}
          {kind === 'agents' ? c.unattributed ?? c.codeOnly : kind === 'tools' ? c.toolsUnowned ?? c.codeOnly : kind === 'project' ? c.projectSources ?? c.codeOnly : c.codeOnly}
          {' · '}
          <b style={{ color: counts.typecheckOk === (counts.typecheckTotal ?? counts.specs) ? '#00FF88' : '#f85149' }}>
            {counts.typecheckOk}/{counts.typecheckTotal ?? counts.specs}
          </b>{' '}
          {c.typecheck}
        </span>
      )}
      <a className="queen27-specs-open" href={kind === 'project' ? '#/docs' : `#/${kind}`} target="_blank" rel="noopener">
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
  const [jump, setJump] = useState<string>(PROJECT_JUMPS[0].stem)
  const frameRef = useRef<HTMLIFrameElement>(null)

  // ?lang= rides in the search, where the i18n provider reads it, so the frame
  // follows the shell's language instead of whatever localStorage held.
  // PROJECT is the docs page at #/docs; the first chapter is the initial frame.
  const src = kind === 'project'
    ? `${window.location.pathname}?lang=${lang}${systemDocsHash(PROJECT_JUMPS[0].stem, { embedded: true })}`
    : `${window.location.pathname}?lang=${lang}#/${kind}?embed=1`

  // A quick jump changes only the frame's fragment (same document, same origin),
  // which the docs page answers by switching chapter without reloading.
  const jumpTo = (stem: string) => {
    setJump(stem)
    const win = frameRef.current?.contentWindow
    if (win) {
      try { win.location.hash = systemDocsHash(stem, { embedded: true }).slice(1) } catch { /* cross-origin never happens: same document */ }
    }
  }

  return (
    <div className={`queen27-specs${kind === 'project' ? ' has-jumps' : ''}`} data-directive={showDirective ? 'above' : 'aside'}>
      {showDirective && <QueenAgentsDirective kind={kind} c={c} collapsible />}

      {kind === 'project' && (
        <nav className="queen27-docs-jumps" aria-label={lang === 'ru' ? 'Быстрые переходы по документации' : 'Documentation quick jumps'}>
          {PROJECT_JUMPS.map((j) => (
            <button
              type="button"
              key={j.stem}
              className={`queen27-docs-jump${jump === j.stem ? ' is-active' : ''}`}
              aria-pressed={jump === j.stem}
              onClick={() => jumpTo(j.stem)}
            >
              {lang === 'ru' ? j.ru : j.en}
            </button>
          ))}
        </nav>
      )}

      <div className="queen27-specs-frame-wrap">
        {!ready && (
          <div className="queen27-specs-loading">
            <QueenLoading title={c.loading} facts={[kind === 'project' ? 'specs/docs/system.t27' : `specs/${kind}/*.t27`]} />
          </div>
        )}
        <iframe
          ref={frameRef}
          className="queen27-specs-frame"
          src={src}
          title={kind === 'skills' ? 'Skill Explorer' : kind === 'crons' ? 'Cron Explorer' : kind === 'agents' ? 'Agent Explorer' : kind === 'functions' ? 'Function Explorer' : kind === 'tools' ? 'Tool Explorer' : 'System documentation'}
          onLoad={() => setReady(true)}
          loading="lazy"
        />
      </div>
    </div>
  )
}
