// The Queen frames the Explorers, and the Queen's address names the card each one shows.
//
// A Queen tab that embeds an Explorer carries that Explorer's selection in its own
// address -- #/queen?tab=skills&skill=t27%2Ftri -- so a link, a reload, Back and the
// language toggle land on the same card. Measured on t27.ai before this: a pick
// inside the frame changed only the frame's own hash, #/queen?tab=skills&skill=...
// opened the default skill, and the ladder link Skills inside the agents frame put
// the Skill Explorer under a rail and an address that still said AGENTS.
//
// This module is the Queen's half of the contract; lib/queenFrame is the Explorer's.
// The Explorer page, when the frame's name says the Queen hosts it, reports each card
// it writes to its address and hands every link to an Explorer route to the Queen
// instead of following it. The Queen checks the origin and that the message came from
// its own frame, validates the id here, writes its address, and moves the frame by
// replacing the frame's fragment.
//
// Every id goes through the Explorer's own hash helper, which throws on an id it
// refuses; here a refused id is no selection, so the frame opens its default and the
// address takes the default the frame reports. An id the helper accepts but the
// catalog does not hold is the Explorer's to answer, as on its own page: the frame
// shows the Explorer's own "not in the catalog" card rather than a different card,
// and the address keeps the id it was given. The docs page is the exception, because
// it has no such card: an unknown chapter opens the first one, and in a frame the page
// writes the chapter it opened to its address, which the Queen then takes.

import { agentExplorerHash, normalizeAgentLetter } from './agentsCatalog'
import { cronExplorerHash } from './cronsCatalog'
import { functionExplorerHash } from './functionsCatalog'
import { explorerRouteParts } from './queenFrame'
import { skillExplorerHash } from './skillsCatalog'
import { specExplorerHash } from './specCatalog'
import { systemDocsHash } from './systemDocs'
import { toolExplorerHash } from './toolsCatalog'

export type ExplorerTab = 'specs' | 'skills' | 'crons' | 'agents' | 'functions' | 'tools' | 'project'

/** The key of the Queen address that names each tab's card. */
export const SELECTION_KEY: Readonly<Record<ExplorerTab, string>> = {
  specs: 'spec',
  skills: 'skill',
  crons: 'cron',
  agents: 'agent',
  functions: 'function',
  tools: 'tool',
  project: 'chapter',
}

export function isExplorerTab(value: string): value is ExplorerTab {
  return Object.prototype.hasOwnProperty.call(SELECTION_KEY, value)
}

/** The spec the SPECS tab opens when its address names none. */
export const FEATURED_SPEC = 'specs/demos/hello_world.t27'
const FIRST_CHAPTER = 'project'
/** A chapter stem (specs/docs/chapters/<stem>.t27): lower-case kebab, nothing else. */
const CHAPTER = /^[a-z0-9]+(?:-[a-z0-9]+)*$/

/** The frame's route for one card. Throws on an id the Explorer's helper refuses. */
function cardHash(tab: ExplorerTab, id: string): string {
  switch (tab) {
    case 'specs': return specExplorerHash(id, { embedded: true })
    case 'skills': return skillExplorerHash(id, { embedded: true })
    case 'crons': return cronExplorerHash(id, { embedded: true })
    case 'agents': return agentExplorerHash(id, { embedded: true })
    case 'functions': return functionExplorerHash(id, { embedded: true })
    case 'tools': return toolExplorerHash(id, { embedded: true })
    case 'project':
      if (!CHAPTER.test(id)) throw new Error('Invalid chapter stem')
      return systemDocsHash(id, { embedded: true })
  }
}

/** The id as the address carries it, or null when there is none or the Explorer's helper refuses it. */
export function validSelection(tab: ExplorerTab, id: string | null): string | null {
  if (!id) return null
  try {
    cardHash(tab, id)
    return tab === 'agents' ? normalizeAgentLetter(id) : id
  } catch {
    return null
  }
}

/** The frame's route for a tab: the named card, or the Explorer's default when the id is missing or refused. */
export function explorerFrameHash(tab: ExplorerTab, id: string | null): string {
  const valid = validSelection(tab, id)
  if (valid) return cardHash(tab, valid)
  if (tab === 'specs') return specExplorerHash(FEATURED_SPEC, { embedded: true })
  if (tab === 'project') return systemDocsHash(FIRST_CHAPTER, { embedded: true })
  return `#/${tab}?embed=1`
}

/** The Queen tab and card an Explorer route names, or null when the hash is not an Explorer route. */
export function explorerRouteOf(hash: string): { tab: ExplorerTab; id: string | null } | null {
  const parts = explorerRouteParts(hash)
  if (!parts) return null
  if (parts.route === 'docs') return { tab: 'project', id: validSelection('project', parts.sub || parts.query.get('chapter')) }
  const tab = parts.route as ExplorerTab
  return { tab, id: validSelection(tab, parts.query.get(SELECTION_KEY[tab])) }
}
