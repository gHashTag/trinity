// Deep links into the Agent Explorer.
//
// An agent is addressed by its LETTER (`A`…`Z`, `TI`), the same key the
// alphabet, the specs (`specs/agents/<letter>.t27`) and experience.json use.
// The full id `t27/<LETTER>` is accepted too, so a chip that carries an id can
// link without a lookup. Nothing here reads the catalog: a bad letter is a
// thrown error, never a silently different agent.

import type { AgentSpecCatalog, AgentSpecEntry } from './agentSpecs'

const LETTER = /^[A-Z]{1,2}$/

export function normalizeAgentLetter(raw: string): string {
  const s = raw.trim()
  const letter = (s.startsWith('t27/') ? s.slice(4) : s).toUpperCase()
  if (!LETTER.test(letter)) throw new Error('Invalid agent letter')
  return letter
}

export function agentExplorerHash(letterOrId: string, options: { embedded?: boolean } = {}): string {
  const params = new URLSearchParams({ agent: normalizeAgentLetter(letterOrId) })
  if (options.embedded) params.set('embed', '1')
  return `#/agents?${params}`
}

export function canonicalAgentUrl(letterOrId: string): string {
  return `https://t27.ai/${agentExplorerHash(letterOrId)}`
}

/** An explicit broken link must never silently show a different agent. */
export function resolveAgent(catalog: AgentSpecCatalog, wanted: string | null): AgentSpecEntry {
  if (wanted === null) {
    const first = catalog.agents[0]
    if (!first) throw new Error('The agent catalog is empty')
    return first
  }
  const letter = normalizeAgentLetter(wanted)
  const hit = catalog.agents.find((a) => a.letter === letter)
  if (!hit) throw new Error(`No agent with letter ${letter} in the catalog`)
  return hit
}
