// The spec-first side of the skills and crons catalogs.
//
// public/skills/spec-skills.json and public/crons/spec-crons.json are written
// at prebuild by scripts/agents-from-specs.mjs from the .t27 files under
// public/t27/files/specs/{skills,crons}/, through the real compiler. This file
// is the one place the page reads them, and the one place the management
// strip's facts are derived: where the canonical spec is edited, where the
// vendored copy lives, where "run now" goes for each host, and whether a live
// control plane is configured at all. Every helper is a pure function of the
// entry and the environment; nothing here guesses a URL the spec does not
// justify.

export type Witness = 'spec+code' | 'spec-only' | 'code-only'
export type Health = 'ok' | 'warn' | 'fail'
export type CronHostKind = 'github-actions' | 'inngest' | 'railway-cron' | 'timer'
export type CronControl = 'github-actions-dispatch' | 'railway-dashboard' | 'inngest-dashboard' | 'code-only'

export interface SkillSpecFields {
  KIND: 'skill'
  ID: string
  NAME: string
  REPO: string
  SOURCE: string
  SUMMARY_EN: string
  SUMMARY_RU: string
  COMMAND: string
  SPECS: string[]
  TAGS: string[]
  ENABLED: boolean
  TIMEOUT_MIN: number
}

export interface CronSpecFields {
  KIND: 'cron'
  ID: string
  NAME: string
  HOST: CronHostKind
  REPO: string
  SERVICE: string
  SUMMARY_EN: string
  SUMMARY_RU: string
  SCHEDULE?: string
  SCHEDULE_NOTE?: string
  INTERVAL_MS?: number
  TZ: string
  RUNS: string[]
  RUNS_NOTE: string
  ENABLED: boolean
  NOTE?: string
  ON_FAILURE: 'issue' | 'log' | 'unknown'
  CONTROL: CronControl
}

interface SpecEntryBase {
  id: string
  /** Corpus-relative, e.g. `specs/skills/trinity-doctor.t27`. */
  specPath: string
  sha256: string
  typecheckOk: boolean
  discarded: number
  moduleName: string | null
  /** Whether public/t27/manifest.json (the vendored corpus index) lists this path yet. */
  inSpecCorpus: boolean
  witness: Exclude<Witness, 'code-only'>
  health: Health
  messages: string[]
}

export interface SkillSpecEntry extends SpecEntryBase {
  fields: SkillSpecFields
  code: { path: string; sha256: string; health: Health; link: string } | null
  /** Cron ids whose RUNS name this skill. */
  runBy: string[]
}

export interface CronSpecEntry extends SpecEntryBase {
  fields: CronSpecFields
  code: { where: { file: string | null; line: number | null; host: string | null; service: string | null }; sourceUrl: string | null; health: Health; kind: CronHostKind; repoPrivate: boolean } | null
  runs: string[]
  runsResolved: { id: string; ok: boolean }[]
  control: CronControl
  /** Resolved at build time by the generator from scripts/railway-services.json. */
  runNow: RunNowTarget
}

interface SpecCatalogBase {
  version: number
  generatedAt: string
  compilerWasmSha256: string
  contentSha256: string
  codeOnly: string[]
}

export interface SkillSpecCatalog extends SpecCatalogBase {
  counts: { specs: number; specPlusCode: number; specOnly: number; codeOnly: number; typecheckOk: number; runBy: number }
  skills: SkillSpecEntry[]
}

export interface CronSpecCatalog extends SpecCatalogBase {
  counts: { specs: number; specPlusCode: number; specOnly: number; codeOnly: number; typecheckOk: number; withRuns: number; byHost: Record<CronHostKind, number> }
  crons: CronSpecEntry[]
}

let skillsPromise: Promise<SkillSpecCatalog> | null = null
let cronsPromise: Promise<CronSpecCatalog> | null = null

export function loadSkillSpecs(): Promise<SkillSpecCatalog> {
  if (!skillsPromise) {
    skillsPromise = fetch('skills/spec-skills.json', { credentials: 'omit' }).then((r) => {
      if (!r.ok) throw new Error(`could not load spec-skills (${r.status})`)
      return r.json() as Promise<SkillSpecCatalog>
    })
    skillsPromise.catch(() => { skillsPromise = null })
  }
  return skillsPromise
}

export function loadCronSpecs(): Promise<CronSpecCatalog> {
  if (!cronsPromise) {
    cronsPromise = fetch('crons/spec-crons.json', { credentials: 'omit' }).then((r) => {
      if (!r.ok) throw new Error(`could not load spec-crons (${r.status})`)
      return r.json() as Promise<CronSpecCatalog>
    })
    cronsPromise.catch(() => { cronsPromise = null })
  }
  return cronsPromise
}

/** The spec's own bytes, from the vendored corpus, checked against the catalog's hash when the page can. */
export async function loadAgentSpecSource(specPath: string): Promise<string> {
  const r = await fetch(`t27/files/${specPath}`, { credentials: 'omit' })
  if (!r.ok) throw new Error(`could not load ${specPath} (${r.status})`)
  return r.text()
}

// ---------------------------------------------------------------------------
// Where things are.
// ---------------------------------------------------------------------------
/** gHashTag/t27's default branch, checked with `gh api repos/gHashTag/t27 --jq .default_branch` on 2026-09-09. */
export const T27_DEFAULT_BRANCH = 'master'

export function specSlug(specPath: string): string {
  return specPath.replace(/^specs\/(skills|crons)\//, '').replace(/\.t27$/, '')
}

/** The canonical spec: the file in gHashTag/t27, opened in GitHub's editor. */
export function canonicalSpecEditUrl(specPath: string): string {
  return `https://github.com/gHashTag/t27/edit/${T27_DEFAULT_BRANCH}/${specPath}`
}

/** The vendored copy the site actually serves. */
export function vendoredSpecUrl(specPath: string): string {
  return `https://github.com/gHashTag/trinity/blob/main/apps/website/public/t27/files/${specPath}`
}

export type RunNowTarget =
  | { kind: 'link'; url: string; via: 'github-actions' | 'railway' | 'inngest' }
  | { kind: 'disabled'; reason: 'timer' | 'unknown-service' }

// ---------------------------------------------------------------------------
// The optional live control plane. See docs/agent-control-api.md.
// ---------------------------------------------------------------------------
export function agentControlUrl(): string | null {
  const raw = (import.meta.env?.VITE_AGENT_CONTROL_URL as string | undefined) ?? ''
  const url = raw.trim().replace(/\/+$/, '')
  return url.length > 0 ? url : null
}

export type ControlAction = 'run' | 'enable' | 'disable'

export function controlEndpoint(base: string, kind: 'skill' | 'cron', id: string, action: ControlAction): string {
  return `${base}/${kind === 'skill' ? 'skills' : 'crons'}/${id.split('/').map(encodeURIComponent).join('/')}/${action}`
}

export async function requestControl(base: string, kind: 'skill' | 'cron', id: string, action: ControlAction): Promise<{ ok: boolean; status: number; body: string }> {
  const r = await fetch(controlEndpoint(base, kind, id, action), {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ id, requestedAt: new Date().toISOString() }),
    credentials: 'omit',
  })
  return { ok: r.ok, status: r.status, body: await r.text().catch(() => '') }
}

// ---------------------------------------------------------------------------
// Labels shared by both Explorers.
// ---------------------------------------------------------------------------
export const WITNESS_LABEL: Record<Witness, { en: string; ru: string }> = {
  'spec+code': { en: 'spec+code', ru: 'спека+код' },
  'spec-only': { en: 'spec-only', ru: 'только спека' },
  'code-only': { en: 'code-only', ru: 'только код' },
}

export function witnessOf<T extends { id: string }>(specById: Map<string, T>, id: string): Witness {
  return specById.has(id) ? 'spec+code' : 'code-only'
}
