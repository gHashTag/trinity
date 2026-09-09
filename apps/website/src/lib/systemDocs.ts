// The system documentation as the site reads it: public/docs/system-docs.json,
// written by scripts/docs-from-specs.mjs from specs/docs/**.t27 through the real
// compiler. Types mirror that file; nothing here invents a field the generator
// does not write, and the page renders what is here or says what is missing.

export type Run = { t: 'text' | 'code' | 'strong'; v: string } | { t: 'link'; v: string; href: string }

export type Block =
  | { type: 'p'; runs: Run[] }
  | { type: 'quote'; runs: Run[] }
  | { type: 'h'; level: number; text: string; id: string }
  | { type: 'ul'; items: Run[][] }
  | { type: 'ol'; items: Run[][] }
  | { type: 'code'; text: string }

export interface RenderedSection { id: string; heading: string; blocks: Block[] }
export interface RenderedBody { lead: Block[]; sections: RenderedSection[] }

export type Localized = { en: string } & Partial<Record<string, string>>

export interface DocSource {
  path: string
  repo: 't27' | 'trinity'
  rel: string
  kind: 'file' | 'dir' | null
  where: 'vendored' | 'checkout' | 'missing'
  sha256: string | null
  url: string
}

export type TableKind = 'claims' | 'laws' | 'ladder-counts' | 'agents' | 'phases' | 'tools' | 'witnesses'
export type DiagramKind = 'ladder' | 'agent-ring' | 'phase-cycle' | 'law-hierarchy' | 'skills-crons-agents' | 'tools-map'

export interface DocTable { kind: TableKind; columns: string[]; rows: Record<string, unknown>[]; source: string; note: string }

export interface DocChapter {
  id: string
  stem: string
  order: number
  enabled: boolean
  specPath: string
  sha256: string
  moduleName: string | null
  typecheckOk: boolean
  discarded: number
  title: Localized
  sections: { id: string; heading: Localized }[]
  body: { en: RenderedBody } & Partial<Record<string, RenderedBody>>
  bodyPath: string
  bodySha256: string | null
  diagram: DiagramKind | null
  table: DocTable | null
  sources: DocSource[]
  links: { spec: string; body: string }
}

export interface LadderCounts { specs: number; skills: number; crons: number; agents: number; tools: number; docsChapters: number }

export interface RingAgent { letter: string; ordinal: number; layer: 'Archetypal' | 'Spiritual' | 'Physical'; name: string; skills: number; tools: number }
export interface PhaseNode { n: number; name: string; note: string; steps: number }
export interface LawNode { law: string; name: string }
export interface GraphEdge { from: string; to: string; kind: 'cron-runs-skill' | 'agent-holds-skill' | 'agent-holds-tool' }

export interface DocFigures {
  ladder: { counts: LadderCounts; source: string }
  'agent-ring': { agents: RingAgent[]; source: string }
  'phase-cycle': { phases: PhaseNode[]; source: string }
  'law-hierarchy': { laws: LawNode[]; priority: string | null; source: string }
  'skills-crons-agents': { edges: GraphEdge[]; counts: { skills: number; crons: number; agents: number; tools: number }; source: string }
  'tools-map': { triByAgent: Record<string, string[]>; mcpByRepo: Record<string, string[]>; external: string[]; source: string }
}

export interface DocI18n { locale: string; spec: string; sha256: string; bundle: string; enabled: boolean; fields: string[]; scope: string[]; coverage: { n: number; total: number }; missing: string[] }

export interface SystemDocs {
  version: number
  compilerWasmSha256: string
  generatedAt: string
  contentSha256: string
  pin: { ref: string; trinity: string; source: string }
  document: {
    id: string
    title: Localized
    specPath: string
    sha256: string
    typecheckOk: boolean
    chapters: string[]
    diagrams: DiagramKind[]
    locales: string[]
    enabled: boolean
    sources: DocSource[]
    link: string
  }
  chapters: DocChapter[]
  figures: DocFigures
  ladder: LadderCounts
  counts: Record<string, number>
  i18n: DocI18n[]
  warnings: string[]
}

let docsPromise: Promise<SystemDocs> | null = null

export function loadSystemDocs(): Promise<SystemDocs> {
  if (!docsPromise) {
    docsPromise = fetch('docs/system-docs.json', { credentials: 'omit' }).then((r) => {
      if (!r.ok) throw new Error(`could not load system-docs (${r.status})`)
      return r.json() as Promise<SystemDocs>
    })
    docsPromise.catch(() => { docsPromise = null })
  }
  return docsPromise
}

/** The chapter's text in `lang`, falling back to English (the contract's FALLBACK). */
export function bodyFor(chapter: DocChapter, lang: string): { body: RenderedBody; lang: string } {
  const b = chapter.body[lang]
  return b ? { body: b, lang } : { body: chapter.body.en, lang: 'en' }
}

export function localized(x: Localized, lang: string): string {
  return x[lang] ?? x.en
}

/** `#/docs/<stem>` or `#/docs?chapter=<stem>`; both keep `embed=1` when given. */
export function systemDocsHash(stem: string | null, opts: { embedded?: boolean; section?: string } = {}): string {
  const q = opts.embedded ? '?embed=1' : ''
  const frag = opts.section ? `#${opts.section}` : ''
  return `#/docs${stem ? `/${stem}` : ''}${q}${frag}`
}

/** The chapter a route names, tolerant of `docs/<stem>`, `<stem>` and a trailing `.t27`/`.md`. */
export function resolveChapter(docs: SystemDocs, wanted: string | null | undefined): DocChapter {
  const first = docs.chapters[0]
  if (!wanted) return first
  const stem = wanted.replace(/^docs\//, '').replace(/\.(t27|md)$/, '').toLowerCase()
  return docs.chapters.find((c) => c.stem === stem) ?? first
}
