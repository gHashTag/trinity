// WHAT THE QUEEN MAY DO ON THE BOARD, AND HOW SHE SAYS IT.
//
// The owner, 2026-09-22: the Queen should know which tab of the game the
// person is on and what it shows, switch tabs herself to show her work, and on
// the AGENT tab help the person talk to their agent - write to it for them.
//
// Her backend carries a message and nothing else (queenModel.askQueen), so both
// halves travel as text. What she can do goes out in the bracketed context
// prefix (directiveHelp); what she decided comes back as markers in her answer:
//
//   [[open:kanban]]          show that tab
//   [[agent: text ...]]      a message for the person's agent
//
// readDirectives strips them, so the person reads her answer, not the markers.
// Opening a tab happens at once - it only changes what is shown. A message to
// the agent is a DRAFT: it is sent as the person, and the agent can act (the
// browser, a Telegram reply), so the person presses Send. Pure, and driven
// through its arguments, so qa/queen-directives-contract.mjs calls it directly.

/** Where [[open:NAME]] may take the board: the rail's own names, lower case. */
export const OPEN_TARGETS: Readonly<Record<string, { view: string; screen?: string }>> = {
  comb: { view: 'comb' },
  specs: { view: 'specs' },
  kanban: { view: 'kanban' },
  project: { view: 'project' },
  feed: { view: 'tri', screen: 'feed' },
  agent: { view: 'tri', screen: 'chat' },
  ai: { view: 'tri', screen: 'script' },
  crm: { view: 'tri', screen: 'crm' },
  browser: { view: 'browser' },
  roadmap: { view: 'roadmap' },
  profile: { view: 'tri', screen: 'profile' },
}

export interface Directives {
  /** The answer as the person reads it: markers removed, whitespace tidied. */
  text: string
  /** The first valid [[open:NAME]], or null. Unknown names are dropped. */
  open: string | null
  /** The message for the agent, or null. Empty drafts are dropped. */
  agent: string | null
}

const OPEN = /\[\[\s*open\s*:\s*([a-z][a-z-]{0,20})\s*\]\]/gi
const AGENT = /\[\[\s*agent\s*:\s*([\s\S]*?)\]\]/i

export function readDirectives(answer: string): Directives {
  let open: string | null = null
  for (const match of answer.matchAll(OPEN)) {
    const name = match[1].toLowerCase()
    if (Object.hasOwn(OPEN_TARGETS, name)) {
      open = name
      break
    }
  }
  const agentMatch = AGENT.exec(answer)
  const draft = agentMatch ? agentMatch[1].trim() : ''
  const text = answer
    .replace(OPEN, '')
    .replace(AGENT, '')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
  return { text, open, agent: draft ? draft.slice(0, 4000) : null }
}

/**
 * What she is told she can do, sent with every question. On the agent tab the
 * draft marker is offered too; elsewhere it is not, so she does not write to
 * the agent about a kanban card.
 */
export function directiveHelp(onAgentTab: boolean): string {
  const names = Object.keys(OPEN_TARGETS).join(' ')
  const open =
    `To show the person a tab, put [[open:NAME]] on its own line; NAME is one of: ${names}. ` +
    'Use it when showing your work is clearer than describing it.'
  if (!onAgentTab) return open
  return (
    `${open} The person is on the AGENT tab, talking to their own agent. ` +
    'When they ask you to write to it, or a message would help them, put the exact ' +
    'message in [[agent: ...]], written as the person in their language; it is ' +
    'shown to them as a draft and sent only when they press Send.'
  )
}

/**
 * What is on the screen, as text, for the question's context. Chats read from
 * the end (the newest messages are at the bottom); everything else from the top.
 */
export function screenExcerpt(text: string, fromEnd: boolean, max = 700): string {
  const flat = text.replace(/\s+/g, ' ').trim()
  if (flat.length <= max) return flat
  return fromEnd ? `...${flat.slice(-max)}` : `${flat.slice(0, max)}...`
}
