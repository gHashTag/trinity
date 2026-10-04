// The vendored skill catalog: `public/skills/` is written by
// scripts/sync-skills.mjs (manual, local) and indexed by scripts/skills-core.mjs
// at prebuild. The page reads only these committed files -- never a repo, never
// a network beyond its own origin.

import { resolveManifestSkill, skillExplorerHash } from './skillsCatalog.ts'

export type SkillLang = 'ru' | 'en' | 'mixed'
export type LinkStatus = 'bound' | 'unbound' | 'broken'
export type RefStatus = 'resolved' | 'ambiguous' | 'missing'
export type Health = 'ok' | 'warn' | 'fail'

export interface SkillSpecRef {
  /** The text as written in the skill. */
  text: string
  line: number
  /** From the `specs:` frontmatter list or the site's bindings (true), or a `.t27` token in the body (false). */
  declared: boolean
  /** Where the reference was written: the skill's own frontmatter, the site's public/skills/bindings.json, or the body text. */
  via: 'frontmatter' | 'site' | 'body'
  /** The manifest path it resolved to, when exactly one matched. */
  to: string | null
  candidates: string[]
  status: RefStatus
}

export interface SkillEntry {
  /** `<repo>/<dir>` */
  id: string
  repo: string
  dir: string
  /** Path under public/skills/files/. */
  path: string
  source: 'SKILL.md' | 'skill.md' | 'README.md'
  name: string
  description: string
  frontmatter: Record<string, string>
  hasFrontmatter: boolean
  lang: SkillLang
  bytes: number
  lines: number
  sha256: string
  headings: { level: number; text: string; line: number }[]
  codeBlocks: { lang: string; lines: number }[]
  links: string[]
  hosts: string[]
  dates: string[]
  extras: string[]
  liveShell: boolean
  specsDeclared: string[]
  specRefs: SkillSpecRef[]
  tags: string[]
  link: LinkStatus
  health: Health
}

export interface SkillsManifest {
  version: number
  generatedAt: string
  generatedFrom: { repo: string; commit: string; shortCommit: string; branch: string; dirty: boolean; private: boolean }[]
  specManifestCommit: string
  skillCount: number
  /** Skills present in the repositories but not on the publish allowlist. */
  withheld: number
  bySource: Record<string, number>
  langs: Record<SkillLang, number>
  tags: Record<string, number>
  featured: string
  skills: SkillEntry[]
}

export interface SkillsCore {
  version: number
  provenance: { manifestSha256: string; specManifestSha256: string; indexerSha256: string }
  skillCount: number
  coverage: {
    skillsBound: string[]
    skillsUnbound: string[]
    skillsBroken: string[]
    specsWithSkill: string[]
    specsWithoutSkill: number
    baselineUnbound: number
  }
  skillToSpecs: Record<string, string[]>
  specToSkills: Record<string, string[]>
}

let manifestPromise: Promise<SkillsManifest> | null = null
let corePromise: Promise<SkillsCore> | null = null

export function loadSkillsManifest(): Promise<SkillsManifest> {
  if (!manifestPromise) {
    manifestPromise = fetch('skills/manifest.json', { credentials: 'omit' }).then((r) => {
      if (!r.ok) throw new Error(`could not load skills manifest (${r.status})`)
      return r.json() as Promise<SkillsManifest>
    })
    manifestPromise.catch(() => { manifestPromise = null })
  }
  return manifestPromise
}

export function loadSkillsCore(): Promise<SkillsCore> {
  if (!corePromise) {
    corePromise = fetch('skills/skills-core.json', { credentials: 'omit' }).then((r) => {
      if (!r.ok) throw new Error(`could not load skills core (${r.status})`)
      return r.json() as Promise<SkillsCore>
    })
    corePromise.catch(() => { corePromise = null })
  }
  return corePromise
}

// Bodies are fetched on pick only; the largest published skill is hundreds of
// kilobytes and the manifest must never carry bodies. A small FIFO keeps the
// last few open so switching back is free.
const CACHE_MAX = 24
const cache = new Map<string, string>()
const inflight = new Map<string, Promise<string>>()

export async function loadSkillSource(id: string, expectedSha256?: string): Promise<string> {
  skillExplorerHash(id, { sha256: expectedSha256 })
  const entry = resolveManifestSkill(await loadSkillsManifest(), id)
  const cached = cache.get(entry.path)
  if (cached !== undefined && !expectedSha256) return cached
  const url = `skills/files/${entry.path.split('/').map(encodeURIComponent).join('/')}`
  const res = await fetch(url, { credentials: 'omit' })
  if (!res.ok) throw new Error(`could not fetch skill ${id} (${res.status})`)
  const bytes = await res.arrayBuffer()
  if (expectedSha256) {
    const hash = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)), (b) => b.toString(16).padStart(2, '0')).join('')
    if (hash !== expectedSha256) throw new Error(`Skill SHA-256 mismatch: ${id}`)
  }
  const text = new TextDecoder().decode(bytes)
  cache.set(entry.path, text)
  if (cache.size > CACHE_MAX) cache.delete(cache.keys().next().value as string)
  return text
}

/** Hover-time warm-up; failures are the pick's to report. */
export function prefetchSkill(id: string): Promise<void> {
  if (inflight.has(id)) return inflight.get(id)!.then(() => undefined, () => undefined)
  const p = loadSkillSource(id)
  inflight.set(id, p)
  return p.then(() => undefined, () => undefined).finally(() => inflight.delete(id))
}
