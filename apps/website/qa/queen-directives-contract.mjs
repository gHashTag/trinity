// The Queen's markers: what she may open and what she may draft for the agent.
// Run: node --experimental-strip-types qa/queen-directives-contract.mjs
import assert from 'node:assert/strict'
import { OPEN_TARGETS, directiveHelp, readDirectives, screenExcerpt } from '../src/lib/queenDirectives.ts'
import { HUD_VIEWS } from '../src/components/queenHud.ts'
import { TRI_SCREENS } from '../src/lib/triScreens.ts'

let checks = 0
const eq = (a, b, m) => { assert.deepEqual(a, b, m); checks++ }
const ok = (v, m) => { assert.ok(v, m); checks++ }

// Every target lands somewhere the board has: a HUD view, and on TRI a screen.
const screens = TRI_SCREENS.map((s) => s.screen)
for (const [name, target] of Object.entries(OPEN_TARGETS)) {
  ok(HUD_VIEWS.includes(target.view), `${name}: ${target.view} is a view the board has`)
  if (target.screen) ok(screens.includes(target.screen), `${name}: ${target.screen} is a TRI screen`)
}

// Opening: the marker is removed, the first KNOWN name wins, unknown names are dropped.
eq(readDirectives('Here it is.\n[[open:kanban]]'), { text: 'Here it is.', open: 'kanban', agent: null }, 'open on its own line')
eq(readDirectives('[[ OPEN : Agent ]] look').open, 'agent', 'case and spaces are forgiven')
eq(readDirectives('[[open:nowhere]] [[open:crm]]').open, 'crm', 'an unknown name does not block a known one')
eq(readDirectives('[[open:constructor]]').open, null, 'an object key is not a tab')
eq(readDirectives('[[open:nowhere]] text').text, 'text', 'even an unknown marker is not shown to the person')

// The agent draft: kept whole, multi-line, and never sent by parsing it.
const drafted = readDirectives('I would write:\n[[agent: Привет! Пришли, пожалуйста,\nсжатую версию видео]]\nThen wait.')
eq(drafted.agent, 'Привет! Пришли, пожалуйста,\nсжатую версию видео', 'a multi-line draft is kept whole')
eq(drafted.text, 'I would write:\n\nThen wait.', 'the draft is taken out of the answer')
eq(readDirectives('[[agent:   ]]').agent, null, 'an empty draft is no draft')
eq(readDirectives('both [[open:agent]] [[agent: hi]]'), { text: 'both', open: 'agent', agent: 'hi' }, 'both markers in one answer')
eq(readDirectives('plain answer').text, 'plain answer', 'an answer without markers is untouched')

// What she is told: the draft marker only on the agent tab.
ok(directiveHelp(false).includes('[[open:NAME]]'), 'the open marker is always offered')
ok(!directiveHelp(false).includes('[[agent:'), 'no agent drafts off the agent tab')
ok(directiveHelp(true).includes('[[agent: ...]]'), 'agent drafts on the agent tab')
ok(directiveHelp(true).includes('only when they press Send'), 'she is told a draft is not sent by itself')

// The screen excerpt: chats from the end, everything else from the top.
const long = 'a'.repeat(400) + ' MIDDLE ' + 'z'.repeat(400)
ok(screenExcerpt(long, true).endsWith('z'), 'a chat keeps its newest end')
ok(screenExcerpt(long, false).startsWith('a'), 'a board keeps its top')
eq(screenExcerpt('  one\n\n two  ', false), 'one two', 'whitespace is flattened')

console.log(`Queen directives contract: PASS (${checks} checks)`)
