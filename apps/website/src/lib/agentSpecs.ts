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
/** An agent's witness: at least one experience episode names its letter, or none does. */
export type AgentWitness = 'spec+experience' | 'spec-only'
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
  /**
   * SUMMARY_EN and NAME by locale. `en` is the spec text. Every other key is a
   * translation connected through a contract spec (specs/i18n/agents-<locale>.t27)
   * whose bundle the generator loaded; a locale with no entry for this spec is
   * simply absent, and the catalog's `i18n` list says which contract each
   * locale came from. Specs themselves are English-only (t27 LANG-EN).
   */
  summary: Localized
  name: Localized
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

export type AgentLayer = 'Archetypal' | 'Spiritual' | 'Physical'

export interface AgentSpecFields {
  KIND: 'agent'
  ID: string
  LETTER: string
  ORDINAL: number
  LETTER_NAME: string
  NAME: string
  DOMAIN: string
  ARCHETYPE: string
  REGISTER: string
  LAYER: AgentLayer
  SUMMARY_EN: string
  SOUL: string
  AGENTS_DOC: string
  ALPHABET: string
  KEY_FILES: string[]
  ENTRY_INVARIANT: string
  EXIT_INVARIANT: string
  CLARA_ROLE: string
  SKILLS: string[]
  SKILLS_NOTE: string
  TOOLS?: string[]
  TOOLS_NOTE?: string
  EXPERIENCE_LOG: string
  ENABLED: boolean
}

/** The slice of public/agents/experience.json joined to one agent by LETTER. */
export interface AgentExperience {
  episodes: number
  first: string | null
  last: string | null
  lastTask: string | null
  outcomes: Record<string, number>
  lessons: string[]
  files: string[]
}

export interface AgentSpecEntry extends Omit<SpecEntryBase, 'witness'> {
  letter: string
  ordinal: number
  fields: AgentSpecFields
  skills: { id: string; ok: boolean }[]
  /** Derived: crons whose RUNS name one of this agent's SKILLS. */
  crons: string[]
  tools: string[]
  experience: AgentExperience
  links: { soul: string; agentsDoc: string; alphabet: string; experienceLog: string | null; pinnedAt: string; pinSource: string }
  witness: AgentWitness
}

// Layer 5: the Inngest functions of 999-multibots-telegraf (specs/functions/<id>.t27),
// witnessed by the vendored functions manifest at public/functions/manifest.json.
export type FunctionTrigger = 'event' | 'cron'
export type FunctionOnFailure = 'admin-telegram' | 'log' | 'refund+notify'
export type FunctionSideEffect = 'charges-balance' | 'paid-api' | 'messages-user' | 'messages-owners' | 'messages-admin' | 'db-write' | 'external-webhook' | 'none'
export type FunctionProbeResult = 'COMPLETED' | 'FAILED-at-guard' | 'skipped' | 'not-deployed'

export interface FunctionSpecFields {
  KIND: 'function'
  ID: string
  LEGACY_ID: string
  NAME: string
  REPO: string
  /** `file:line` of the `createFunction(` call, repo-relative. */
  SERVICE: string
  DOMAIN: string
  TRIGGER: FunctionTrigger
  EVENT: string
  LEGACY_EVENTS: string[]
  CRON: string
  TZ: string
  SUMMARY_EN: string
  STEPS: string[]
  RETRIES: number
  ON_FAILURE: FunctionOnFailure
  SIDE_EFFECTS: FunctionSideEffect[]
  GUARD: string
  /** JSON of the safe-mode payload, or "" when no probe was sent. */
  SAFE_PROBE: string
  PROBE_RESULT: FunctionProbeResult
  CONTROL: Witness
  NOTE: string
}

/** One field where the spec and the manifest entry read different values. */
export interface FunctionDifference { field: string; spec: unknown; code: unknown }

export interface FunctionSpecEntry extends SpecEntryBase {
  fields: FunctionSpecFields
  /** The manifest entry with the same id, or null when the manifest does not list it. */
  code: { legacyId: string | null; file: string | null; deployed: boolean | null; probeResult: string | null; retries: number | null; steps: number | null; control: string | null } | null
  differences: FunctionDifference[]
  /** The cron card (specs/crons) that states the same schedule, joined by REPO + LEGACY_ID; null when none does. */
  cronSpec: string | null
}

export interface FunctionSpecCatalog extends SpecCatalogBase {
  counts: {
    specs: number; specPlusCode: number; specOnly: number; codeOnly: number; typecheckOk: number
    deployed: number; notDeployed: number; deployUnknown: number; withCronSpec: number; withDifferences: number
    byTrigger: Record<FunctionTrigger, number>; byDomain: Record<string, number>; bySideEffect: Record<FunctionSideEffect, number>; byProbeResult: Record<FunctionProbeResult, number>
  }
  ladder: { specs: number | null; skills: number; crons: number; agents: number; functions: number }
  manifest: { repo: string | null; generatedFrom: { branch?: string; commit?: string; note?: string } | null; probedAt: string | null; deployedApp: { name?: string; sdk?: string; baseFunctions?: number; mainRegisters?: number } | null; entries: number } | null
  functions: FunctionSpecEntry[]
}

export type Localized = { en: string } & Partial<Record<string, string>>

/** One translation contract (a specs/i18n/*.t27) as it applies to one catalog. */
export interface I18nContract {
  locale: string
  /** Corpus path of the contract spec, e.g. `specs/i18n/agents-ru.t27`. */
  spec: string
  sha256: string
  /** Repo-relative path of the bundle the spec points to. */
  bundle: string
  enabled: boolean
  fields: string[]
  scope: string[]
  coverage: { n: number; total: number }
  /** Spec ids in this catalog with no entry in the bundle. */
  missing: string[]
}

interface SpecCatalogBase {
  version: number
  generatedAt: string
  compilerWasmSha256: string
  contentSha256: string
  codeOnly: string[]
  i18n: I18nContract[]
}

export interface SkillSpecCatalog extends SpecCatalogBase {
  counts: { specs: number; specPlusCode: number; specOnly: number; codeOnly: number; typecheckOk: number; runBy: number }
  skills: SkillSpecEntry[]
}

export interface CronSpecCatalog extends SpecCatalogBase {
  counts: { specs: number; specPlusCode: number; specOnly: number; codeOnly: number; typecheckOk: number; withRuns: number; byHost: Record<CronHostKind, number> }
  crons: CronSpecEntry[]
}

export interface AgentSpecCatalog extends Omit<SpecCatalogBase, 'codeOnly'> {
  counts: {
    specs: number; enabled: number; typecheckOk: number; withSkills: number; withCrons: number; withTools: number; withExperience: number; withClaraRole: number
    specPlusExperience: number; specOnly: number; byLayer: Record<AgentLayer, number>
    episodesAttributed: number; episodesUnattributed: number | null; episodesTotal: number | null
  }
  /** Specs -> Skills -> Crons -> Agents, the counts the ladder header shows. */
  ladder: { specs: number | null; skills: number; crons: number; agents: number }
  pin: { ref: string; source: string }
  experienceSnapshot: {
    generatedAt: string
    sources: { repo: string; commit: string; files: number; episodes: number; unreadable: number }[]
    counts: { episodes: number; attributed: number; unattributed: number; agentsWithEpisodes: number; unreadableFiles: number } | null
    attribution: { fields: string[]; letters: string[]; rule: string } | null
  } | null
  agents: AgentSpecEntry[]
}

let skillsPromise: Promise<SkillSpecCatalog> | null = null
let cronsPromise: Promise<CronSpecCatalog> | null = null
let agentsPromise: Promise<AgentSpecCatalog> | null = null
let functionsPromise: Promise<FunctionSpecCatalog> | null = null

export function loadFunctionSpecs(): Promise<FunctionSpecCatalog> {
  if (!functionsPromise) {
    functionsPromise = fetch('functions/spec-functions.json', { credentials: 'omit' }).then((r) => {
      if (!r.ok) throw new Error(`could not load spec-functions (${r.status})`)
      return r.json() as Promise<FunctionSpecCatalog>
    })
    functionsPromise.catch(() => { functionsPromise = null })
  }
  return functionsPromise
}

export function loadAgentSpecs(): Promise<AgentSpecCatalog> {
  if (!agentsPromise) {
    agentsPromise = fetch('agents/spec-agents.json', { credentials: 'omit' }).then((r) => {
      if (!r.ok) throw new Error(`could not load spec-agents (${r.status})`)
      return r.json() as Promise<AgentSpecCatalog>
    })
    agentsPromise.catch(() => { agentsPromise = null })
  }
  return agentsPromise
}

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
  return specPath.replace(/^specs\/(skills|crons|agents|functions)\//, '').replace(/\.t27$/, '')
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
export const WITNESS_LABEL: Record<Witness | AgentWitness, { en: string; ru: string }> = {
  'spec+code': { en: 'spec+code', ru: 'спека+код' },
  'spec-only': { en: 'spec-only', ru: 'только спека' },
  'code-only': { en: 'code-only', ru: 'только код' },
  'spec+experience': { en: 'spec+experience', ru: 'спека+опыт' },
}

export function witnessOf<T extends { id: string }>(specById: Map<string, T>, id: string): Witness {
  return specById.has(id) ? 'spec+code' : 'code-only'
}
