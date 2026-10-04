// TASKS SIDE BY SIDE ON THE BROWSER VIEW: a card is one more lane of the
// person's agent, in a window of its own, while the chat stays on main.
//
// The render (999-multibots-telegraf render/src/browser/lanes.ts, #3554) holds
// the rules; the board mirrors them so it can say them first. Each rule below
// is one a wrong edit would break quietly: the chat starting to send `lane`
// (every old render would still answer, so nobody would notice), a card that
// keeps claiming it runs apart on a render that answered from main, a refusal
// read as a failure, two lanes' steps folded into one line of the journal.
//
//   node --experimental-strip-types qa/queen-browser-lanes-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import {
  AgentLaneRefused,
  EXTRA_LANES,
  LANE_CAP,
  LANE_IDLE_MIN,
  LANE_SHAPE,
  MAIN_LANE,
  canAddLane,
  cardStateAfter,
  laneField,
  laneNameFor,
  laneOfStep,
  refusalOf,
  supportAfter,
} from '../src/lib/queenBrowserLanes.ts'
import { AgentSignedOut, askBrowserAgent, foldRepeats, sayToAgent } from '../src/lib/queenBrowser.ts'

// 1. The render's numbers and shape, as the render states them.
assert.equal(LANE_SHAPE.source, '^[a-z0-9][a-z0-9-]{0,23}$')
assert.equal(LANE_CAP, 3, 'render windows.ts MAX_WINDOWS, main included')
assert.equal(EXTRA_LANES, 2)
assert.equal(LANE_IDLE_MIN, 30)
assert.equal(MAIN_LANE, 'main')

// 2. Card names: the first free task-N, so a closed card's lane is taken again
//    rather than left holding a window; none past the cap.
assert.equal(laneNameFor([]), 'task-2')
assert.equal(laneNameFor(['task-2']), 'task-3')
assert.equal(laneNameFor(['task-3']), 'task-2', 'a closed card frees its name')
assert.equal(laneNameFor(['task-2', 'task-3']), null)
for (const taken of [[], ['task-2'], ['task-3']]) assert.match(laneNameFor(taken), LANE_SHAPE)

// 3. The request field: main is never named, so the chat's request is what it was.
assert.deepEqual(laneField(undefined), {})
assert.deepEqual(laneField('main'), {})
assert.deepEqual(laneField('task-2'), { lane: 'task-2' })
for (const bad of ['Task-2', '-x', 'a_b', 'a'.repeat(25), '']) assert.throws(() => laneField(bad), /not a lane name/, bad)

// 4. What an answer proves about the render.
assert.equal(supportAfter('unknown', 'task-2', 'task-2'), 'yes')
assert.equal(supportAfter('unknown', 'task-2', null), 'no', 'no confirmation: a render from before lanes answered from main')
assert.equal(supportAfter('yes', 'task-2', 'task-3'), 'no', 'a confirmation of another lane is not this one')
for (const prev of ['unknown', 'yes', 'no']) assert.equal(supportAfter(prev, 'main', null), prev, 'main proves nothing')

// 5. The render's refusals, and only those.
const body = (o) => JSON.stringify(o)
assert.equal(refusalOf(409, body({ code: 'lane_limit', error: 'three lanes (main, a, b)' })), 'limit')
assert.equal(refusalOf(400, body({ code: 'bad_request', error: 'lane must be a string matching ...' })), 'shape')
assert.equal(refusalOf(400, body({ code: 'bad_request', error: 'messages must be an array' })), null)
assert.equal(refusalOf(409, body({ code: 'busy' })), null)
assert.equal(refusalOf(409, 'not json'), null)
assert.equal(refusalOf(500, body({ code: 'lane_limit' })), null)

// 6. When a card is offered.
const offer = { live: true, signedIn: true, support: 'unknown', cards: 0, full: false }
assert.equal(canAddLane(offer), true)
assert.equal(canAddLane({ ...offer, support: 'yes', cards: 1 }), true)
assert.equal(canAddLane({ ...offer, cards: EXTRA_LANES }), false, 'not past the cap')
assert.equal(canAddLane({ ...offer, support: 'no' }), false, 'not on a render that answered from main')
assert.equal(canAddLane({ ...offer, full: true }), false, 'not after lane_limit: another device holds a lane')
assert.equal(canAddLane({ ...offer, live: false }), false)
assert.equal(canAddLane({ ...offer, signedIn: false }), false)

// 7. What a card says after its answer or refusal.
assert.equal(cardStateAfter({ lane: 'task-2', confirmed: 'task-2' }), 'answered')
assert.equal(cardStateAfter({ lane: 'task-2', confirmed: null }), 'old')
assert.equal(cardStateAfter({ refusal: 'limit' }), 'limit')
assert.equal(cardStateAfter({ refusal: 'shape' }), 'failed')
assert.equal(cardStateAfter('signedout'), 'signedout')
assert.equal(cardStateAfter('failed'), 'failed')

// 8. The journal's lane.
assert.equal(laneOfStep({ lane: 'task-2' }), 'task-2')
assert.equal(laneOfStep({}), 'main')
assert.equal(laneOfStep({ lane: 'DROP TABLE' }), 'main', 'only a lane-shaped name is shown')
assert.equal(laneOfStep(null), 'main')
const look = (lane) => ({ at: '2026-10-04T00:00:00Z', tool: 'browser_look', ok: true, ms: 1, detail: lane ? { seen: 'a page', lane } : { seen: 'a page' } })
assert.equal(foldRepeats([look(), look()], 'en').length, 1, 'one lane, one folded line')
assert.equal(foldRepeats([look(), look('task-2')], 'en').length, 2, 'two lanes looking at one page are two looks')

// 9. The request and the answer, through a fake render.
function render({ status = 200, lines = [], raw = '' } = {}) {
  const sent = []
  return {
    sent,
    env: {
      token: () => 'tok',
      fetch: async (url, init) => {
        sent.push({ url, init, body: JSON.parse(init.body) })
        return { ok: status >= 200 && status < 300, status, text: async () => raw || lines.map((l) => JSON.stringify(l)).join('\n') }
      },
    },
  }
}
const said = (t) => ({ ['тип']: 'текст', ['текст']: t })

{
  const r = render({ lines: [said('ok')] })
  await askBrowserAgent(r.env, [], 'hi', 'en')
  assert.deepEqual(Object.keys(r.sent[0].body), ['messages'], 'the chat sends no lane: exactly what it sent before lanes')
}
{
  const r = render({ lines: [{ ['тип']: 'lane', lane: 'task-2' }, said('done')] })
  const a = await askBrowserAgent(r.env, [], 'find it', 'en', undefined, 'task-2')
  assert.equal(r.sent[0].body.lane, 'task-2')
  assert.equal(a.lane, 'task-2')
  assert.equal(a.text, 'done')
}
{
  const r = render({ lines: [said('from main')] })
  const a = await askBrowserAgent(r.env, [], 'find it', 'en', undefined, 'task-2')
  assert.equal(a.lane, null, 'a render from before lanes confirms nothing')
}
{
  const r = render({ status: 409, raw: body({ code: 'lane_limit', error: 'three lanes (main, a, b)' }) })
  await assert.rejects(askBrowserAgent(r.env, [], 'x', 'en', undefined, 'task-2'), (e) => e instanceof AgentLaneRefused && e.refusal === 'limit')
}
{
  const r = render({ status: 409, raw: body({ code: 'lane_limit' }) })
  await assert.rejects(askBrowserAgent(r.env, [], 'x', 'en'), (e) => !(e instanceof AgentLaneRefused), 'no lane asked, no lane refusal')
}
{
  const r = render({ status: 401 })
  await assert.rejects(askBrowserAgent(r.env, [], 'x', 'en', undefined, 'task-2'), AgentSignedOut)
}
{
  const r = render({ lines: [said('ok')] })
  await sayToAgent(r.env, 'as me')
  assert.equal('lane' in r.sent[0].body, false, 'the AGENT tab speaks in main')
}

// 10. The panels use these decisions, in the bytes that ship.
const browser = readFileSync(new URL('../src/components/QueenBrowser.tsx', import.meta.url), 'utf8')
const live = browser.slice(browser.indexOf("if (state === 'live' && src)"), browser.indexOf('// none, starting'))
assert.match(live, /<QueenBrowserLanes c=\{c\.lanes\} lang=\{lang\} env=\{brokerEnv\} live=\{live\} \/>/, 'the cards sit on the live view')
assert.match(live, /const lane = laneOfStep\(step\.detail\)/, 'the journal names a step\'s lane')

const cards = readFileSync(new URL('../src/components/QueenBrowserLanes.tsx', import.meta.url), 'utf8')
assert.match(cards, /askBrowserAgent\(\s*env,\s*card\.turns,\s*question,\s*lang,[\s\S]*?\n\s*card\.lane,\n\s*\)/, 'a card asks in its own lane')
assert.match(cards, /setSupport\(prev => supportAfter\(prev, card\.lane, a\.lane\)\)/, 'and believes the render, not itself')
assert.match(cards, /canAddLane\(\{ live, signedIn, support, cards: cards\.length, full \}\)/)
assert.match(cards, /\{support === 'no' \? null : \(/, 'no input on a card whose questions would go to main')
assert.match(cards, /if \(error\.refusal === 'limit'\) setFull\(true\)/)
assert.doesNotMatch(cards, /localStorage|sessionStorage|indexedDB/, 'a card is forgotten when it closes')

const lib = readFileSync(new URL('../src/lib/queenBrowser.ts', import.meta.url), 'utf8')
assert.match(lib, /messages: agentMessages\(history, question, lang\), \.\.\.laneField\(lane\)/)

// 11. The words, in both languages, with the render's numbers in them.
const page = readFileSync(new URL('../src/pages/Queen.tsx', import.meta.url), 'utf8')
const ruStart = page.indexOf('browserWatchHide: "Скрыть"')
const en = page.slice(0, ruStart)
const ru = page.slice(ruStart)
const keys = ['Add', 'AddTitle', 'Region', 'Placeholder', 'Send', 'Working', 'Limit', 'Old', 'SignedOut', 'Failed', 'Close', 'CloseTitle']
const text = (block, key) => block.match(new RegExp(`\\n    browserLanes${key}: "([^"]*)"`))?.[1]
for (const key of keys) {
  assert.ok(text(en, key), `en has browserLanes${key}`)
  assert.ok(!/[Ѐ-ӿ]/.test(text(en, key)), `en is English: ${key}`)
  assert.match(text(ru, key), /[Ѐ-ӿ]/, `ru has browserLanes${key}, in Russian`)
  assert.match(page, new RegExp(`: c\\.browserLanes${key},`), `browserLanes${key} reaches the panel`)
}
for (const [block, cap] of [[en, /Three/], [ru, /трёх/]]) {
  assert.match(text(block, 'Limit'), cap, 'the cap, as the render counts it')
  assert.match(text(block, 'Limit'), new RegExp(`\\b${LANE_IDLE_MIN}\\b`))
  assert.match(text(block, 'CloseTitle'), new RegExp(`\\b${LANE_IDLE_MIN}\\b`), 'closing a card is not closing its window')
}

// 12. On a phone: cards wrap, nothing forces the row wider than the screen,
//     and every control is a full-size touch target.
const css = readFileSync(new URL('../src/components/QueenBrowser.css', import.meta.url), 'utf8')
assert.match(css, /\.queen27-browser-lanes \{[^}]*flex-wrap: wrap/s)
assert.match(css, /\.queen27-browser-task \{[^}]*min-width: 0[^}]*max-width: 100%/s)
assert.match(css, /\.queen27-browser-task-form textarea \{[^}]*min-height: 44px/s)
assert.match(css, /\.queen27-browser-task-head \.queen27-browser-btn \{[^}]*min-width: 44px/s, 'the one-glyph close mark is a full-width target')
assert.match(css, /@media \(pointer: coarse\) \{\s*\.queen27-page\.is-shell \.queen27-browser-task-form textarea \{[^}]*font-size: 16px/s, 'under 16px iOS zooms the page into the field')

console.log(`queen-browser-lanes contract: ok (cap ${LANE_CAP}, ${EXTRA_LANES} cards, ${keys.length} copy keys per language)`)
