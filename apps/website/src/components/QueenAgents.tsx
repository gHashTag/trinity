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

import { useEffect, useRef, useState, type ReactNode } from 'react'
import { useI18n } from '../i18n/context'
import { QueenLoading } from './QueenLoading'
import { useQueenExplorerFrame } from './useQueenExplorerFrame'
import { loadAgentSpecs, loadCronSpecs, loadFunctionSpecs, loadSkillSpecs, loadToolSpecs } from '../lib/agentSpecs'
import { loadSystemDocs } from '../lib/systemDocs'
import { QueenMcp, mcpCopy } from './QueenMcp'
import type { ExplorerTab } from '../lib/queenEmbed'

export type AgentsKind = 'skills' | 'crons' | 'agents' | 'functions' | 'tools' | 'project'

// PROJECT frames #/docs?embed=1. A quick jump above the frame is a chapter written
// to the Queen address (chapter=), like a pick inside the frame; the frame's hash
// follows, and the page inside answers hashchange, so a jump is a chapter switch,
// not a reload. Chapter stems are those of specs/docs/chapters.
export const PROJECT_JUMPS: readonly { stem: string; en: string; ru: string }[] = [
  { stem: 'project', en: 'Project', ru: 'Проект' },
  { stem: 'rules', en: 'Rules of the game', ru: 'Правила игры' },
  { stem: 'layers', en: 'System', ru: 'Система' },
  { stem: 'alphabet', en: 'Alphabet', ru: 'Алфавит' },
  { stem: 'tooling', en: 'Tools', ru: 'Инструменты' },
  { stem: 'evidence', en: 'Evidence', ru: 'Свидетели' },
] as const

// TOOLS answers two questions, so it has two faces and one tab. The Explorer is
// the spec catalogue: what a tool is declared to be. The fleet is whether the
// MCP servers behind those tools answer right now, read live from a hub on the
// owner's own machine. A declared server that is offline and a healthy one are
// the same text in a spec, which is the half the catalogue cannot show.
export const TOOL_FACES: readonly { id: 'specs' | 'mcp'; en: string; ru: string }[] = [
  { id: 'specs', en: 'Specs', ru: 'Спеки' },
  { id: 'mcp', en: '🔌 MCP fleet', ru: '🔌 Парк MCP' },
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

export function QueenAgents({ kind, c, showDirective = true, onNavigate, ladder }: { kind: AgentsKind; c: AgentsCopy; showDirective?: boolean; onNavigate: (tab: ExplorerTab, card: string | null) => void; ladder?: ReactNode }) {
  const { lang } = useI18n()
  const [ready, setReady] = useState(false)
  // The card in the frame is the card in the Queen address: skill=, cron=, agent=,
  // function=, tool= or chapter= (lib/queenEmbed). PROJECT opens on the first chapter.
  const frameRef = useRef<HTMLIFrameElement>(null)
  const frame = useQueenExplorerFrame(kind, onNavigate, frameRef)
  const jump = frame.card ?? PROJECT_JUMPS[0].stem
  // TOOLS only. `seenMcp` keeps the fleet from probing the hub for a reader who
  // never asks for it, and keeps it mounted once they have: both faces stay in
  // the tree and are hidden rather than unmounted, because the Explorer boots
  // the compiler wasm and a face switch must not pay for that twice.
  const [face, setFace] = useState<'specs' | 'mcp'>('specs')
  const [seenMcp, setSeenMcp] = useState(false)
  const hasFaces = kind === 'tools'
  const showMcp = hasFaces && face === 'mcp'

  return (
    <div className={`queen27-specs${kind === 'project' || hasFaces ? ' has-jumps' : ''}${ladder ? ' has-ladder' : ''}`} data-directive={showDirective ? 'above' : 'aside'}>
      {ladder}
      {showDirective && <QueenAgentsDirective kind={kind} c={c} collapsible />}

      {hasFaces && (
        <nav className="queen27-docs-jumps" aria-label={lang === 'ru' ? 'Что показывает вкладка инструментов' : 'What the tools view shows'}>
          {TOOL_FACES.map((f) => (
            <button
              type="button"
              key={f.id}
              className={`queen27-docs-jump${face === f.id ? ' is-active' : ''}`}
              aria-pressed={face === f.id}
              onClick={() => { setFace(f.id); if (f.id === 'mcp') setSeenMcp(true) }}
            >
              {lang === 'ru' ? f.ru : f.en}
            </button>
          ))}
        </nav>
      )}

      {kind === 'project' && (
        <nav className="queen27-docs-jumps" aria-label={lang === 'ru' ? 'Быстрые переходы по документации' : 'Documentation quick jumps'}>
          {PROJECT_JUMPS.map((j) => (
            <button
              type="button"
              key={j.stem}
              className={`queen27-docs-jump${jump === j.stem ? ' is-active' : ''}`}
              aria-pressed={jump === j.stem}
              onClick={() => frame.show(j.stem)}
            >
              {lang === 'ru' ? j.ru : j.en}
            </button>
          ))}
        </nav>
      )}

      {seenMcp && (
        // Its own copy table travels with the component: "answering" and the
        // hub-down command are this view's vocabulary and nothing else's.
        <QueenMcp c={mcpCopy(lang)} lang={lang} hidden={!showMcp} />
      )}

      <div className="queen27-specs-frame-wrap" hidden={showMcp}>
        {!ready && (
          <div className="queen27-specs-loading">
            <QueenLoading title={c.loading} facts={[kind === 'project' ? 'specs/docs/system.t27' : `specs/${kind}/*.t27`]} />
          </div>
        )}
        <iframe
          key={frame.frameKey}
          ref={frameRef}
          name={frame.frameName}
          className="queen27-specs-frame"
          src={frame.src}
          title={kind === 'skills' ? 'Skill Explorer' : kind === 'crons' ? 'Cron Explorer' : kind === 'agents' ? 'Agent Explorer' : kind === 'functions' ? 'Function Explorer' : kind === 'tools' ? 'Tool Explorer' : 'System documentation'}
          onLoad={() => { setReady(true); frame.onFrameLoad() }}
          loading="lazy"
        />
      </div>
    </div>
  )
}
