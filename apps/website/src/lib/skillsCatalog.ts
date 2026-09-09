import type { SkillEntry, SkillsManifest } from './skillsLoader.ts'

const SEGMENT = /^[A-Za-z0-9_.-]+$/

/** `<repo>/<dir>`: exactly two safe segments, no traversal, no URL syntax. */
export function validSkillId(id: string): boolean {
  const parts = id.split('/')
  if (parts.length !== 2) return false
  return parts.every(
    (p) => SEGMENT.test(p) && p !== '.' && p !== '..' && !Array.from(p).some((c) => c.charCodeAt(0) < 32 || c.charCodeAt(0) === 127),
  )
}

/** One public address per skill; embed and revision pins are viewing context. */
export function skillExplorerHash(id: string, options: { embedded?: boolean; sha256?: string } = {}): string {
  if (!validSkillId(id)) throw new Error('Invalid catalog skill id')
  if (options.sha256 !== undefined && !/^[a-f0-9]{64}$/.test(options.sha256)) throw new Error('Invalid catalog SHA-256')
  const params = new URLSearchParams({ skill: id })
  if (options.embedded) params.set('embed', '1')
  if (options.sha256) params.set('sha256', options.sha256)
  return `#/skills?${params}`
}

export function canonicalSkillUrl(id: string): string {
  return `https://t27.ai/${skillExplorerHash(id)}`
}

/** An explicit broken link must never silently show a different featured skill. */
export function resolveManifestSkill(manifest: SkillsManifest, id: string | null): SkillEntry {
  if (id === null) {
    const first = manifest.skills.find((s) => s.id === manifest.featured) ?? manifest.skills[0]
    if (!first) throw new Error('Skill catalog is empty')
    return first
  }
  skillExplorerHash(id)
  const matches = manifest.skills.filter((s) => s.id === id)
  if (matches.length !== 1) throw new Error(`Skill catalog id is missing or ambiguous: ${id}`)
  return matches[0]
}
