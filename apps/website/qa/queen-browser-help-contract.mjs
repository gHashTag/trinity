// THE QUEEN ON THE BROWSER TAB: who answers there, what an empty conversation
// says, and the first questions offered.
//
// On BROWSER the chat asks the person's own agent (services/queenModel.ts,
// askQueenInBrowser), not the Queen server whose health the panel polls. The
// panel used to put that server's OFFLINE chip and "No Queen is answering"
// over this view anyway. Each rule below is one a wrong edit would break
// quietly: the chip going back to the wrong server, a starter that asks the
// agent to pay or send, a starter row shown to someone who cannot send it.
//
//   node --experimental-strip-types qa/queen-browser-help-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import {
  BROWSER_STARTERS,
  NEVER_IN_A_STARTER,
  backendOf,
  emptyNote,
  headState,
  startersFor,
} from '../src/lib/queenBrowserHelp.ts'

// 1. Who answers.
assert.equal(backendOf('browser'), 'agent')
for (const view of ['specs', 'tri', 'kanban', 'crm', '']) assert.equal(backendOf(view), 'queen', view)

// 2. The chip names who answers on BROWSER, whatever the Queen server says;
//    everywhere else it is that server's health, unchanged.
for (const live of [true, false, null]) assert.equal(headState('browser', live), 'agent', `browser, queen ${live}`)
assert.equal(headState('specs', true), 'live')
assert.equal(headState('specs', false), 'offline')
assert.equal(headState('specs', null), 'checking')

// 3. The empty conversation: never "no Queen is answering" over BROWSER.
for (const live of [true, false, null]) assert.equal(emptyNote('browser', live), 'browserEmpty')
assert.equal(emptyNote('specs', false), 'offlineNote')
assert.equal(emptyNote('specs', true), 'empty')
assert.equal(emptyNote('specs', null), 'empty')

// 4. The starters: the same number in both languages, English in English and
//    Russian in Russian, short enough to read before pressing.
assert.equal(BROWSER_STARTERS.en.length, BROWSER_STARTERS.ru.length)
assert.ok(BROWSER_STARTERS.en.length >= 3 && BROWSER_STARTERS.en.length <= 5)
for (const line of BROWSER_STARTERS.en) {
  assert.ok(!/[Ѐ-ӿ]/.test(line), `no Cyrillic in English: ${line}`)
  assert.ok(line.length <= 80, `short: ${line}`)
}
for (const line of BROWSER_STARTERS.ru) {
  assert.ok(/[Ѐ-ӿ]/.test(line), `Russian is Russian: ${line}`)
  assert.ok(line.length <= 80, `short: ${line}`)
}

// 5. No starter asks for what cannot be taken back. A starter is one press,
//    and the agent it reaches can act.
const banned = (line) => NEVER_IN_A_STARTER.filter((w) => line.toLowerCase().includes(w))
for (const line of [...BROWSER_STARTERS.en, ...BROWSER_STARTERS.ru]) {
  assert.deepEqual(banned(line), [], `a starter that acts for good: ${line}`)
}
// The check can see: the words it guards against are found when present.
assert.deepEqual(banned('Pay for the order'), ['pay', 'order'])
assert.deepEqual(banned('Отправь письмо'), ['отправ'])
assert.deepEqual(banned('Удали этот файл'), ['удал'])

// 6. A password is mentioned only to say who types it: the person.
for (const line of BROWSER_STARTERS.en.filter((l) => /password/i.test(l))) assert.match(line, /I will type/)
for (const line of BROWSER_STARTERS.ru.filter((l) => /пароль/i.test(l))) assert.match(line, /введу я/)

// 7. When they are offered: BROWSER, before the first question, signed in, idle.
const idle = { turns: 0, signedIn: true, busy: false }
assert.deepEqual(startersFor('browser', idle, 'en'), BROWSER_STARTERS.en)
assert.deepEqual(startersFor('browser', idle, 'ru'), BROWSER_STARTERS.ru)
assert.deepEqual(startersFor('specs', idle, 'en'), [], 'not on a view the Queen server answers')
assert.deepEqual(startersFor('browser', { ...idle, turns: 1 }, 'en'), [], 'not once the conversation has begun')
assert.deepEqual(startersFor('browser', { ...idle, signedIn: false }, 'en'), [], 'not to someone who cannot send them')
assert.deepEqual(startersFor('browser', { ...idle, busy: true }, 'en'), [], 'not while an answer is coming')

// 8. The panel uses these decisions, in the bytes that ship.
const panel = readFileSync(new URL('../src/components/QueenChat.tsx', import.meta.url), 'utf8')
assert.match(panel, /const head = headState\(context\.view, live\)/, 'the chip is decided by the view, not by the Queen server alone')
assert.match(panel, /t\[emptyNote\(context\.view, live\)\]/, 'and so is the empty sentence')
assert.match(panel, /onClick=\{\(\) => send\(line\)\}/, 'a starter is sent the way a typed question is, as the person')
assert.match(
  panel,
  /scrollTo\(\{ top: turns\.length === 0 \? 0 : log\.current\.scrollHeight \}\)/,
  'an empty log stays at its top, so the sentence above the starters is not scrolled away',
)
assert.doesNotMatch(
  panel,
  /live === false \? t\.offlineNote : t\.empty/,
  'the old empty line read the Queen server on every view, BROWSER included',
)
const ru = panel.slice(panel.indexOf('  ru: {'), panel.indexOf('} as const'))
for (const key of ['browserEmpty', 'agentState', 'agentStateTitle', 'starters']) {
  assert.match(panel, new RegExp(`\\n    ${key}: '`), `en has ${key}`)
  assert.match(ru, new RegExp(`\\n    ${key}: '[^']*[\\u0400-\\u04FF]`), `ru has ${key}, in Russian`)
}

const css = readFileSync(new URL('../src/components/QueenChat.css', import.meta.url), 'utf8')
assert.match(css, /\.queen-chat-state\.is-agent \{/, 'the agent chip has a colour of its own')
assert.match(css, /\.queen-chat-starter \{[^}]*min-height: 44px/s, 'a starter is a full-size touch target')

console.log(
  `queen-browser-help contract: ok (${BROWSER_STARTERS.en.length} starters per language, ` +
    `${NEVER_IN_A_STARTER.length} guarded words)`,
)
