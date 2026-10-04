// A card tap posts open-card to the app framing the board, and nothing else does.
// Run: node --experimental-strip-types --test scripts/queen-card-chat.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'
import { OPEN_CARD, openCardInApp, openCardMessage, sameOriginParent } from '../src/lib/queenCardChat.ts'

const APP = 'https://app.t27.ai'

function tap(extra = {}) {
  const t = { defaultPrevented: false, button: 0, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false, prevented: 0 }
  t.preventDefault = () => { t.prevented += 1 }
  return Object.assign(t, extra)
}

function framed(parentOrigin) {
  const sent = []
  const parent = {
    get location() {
      if (parentOrigin !== APP) throw new DOMException('Blocked a frame', 'SecurityError')
      return { origin: parentOrigin }
    },
    postMessage: (m, origin) => sent.push({ m, origin }),
  }
  return { win: { parent, location: { origin: APP } }, sent }
}

const msg = openCardMessage('gHashTag/trinity', 7, 'Ship the sheet', 'running')

test('the envelope is the one the player reads (spec MSG_V, MSG_TYPE, MSG_KIND)', () => {
  assert.deepEqual(OPEN_CARD, { v: 1, type: 't27-app', kind: 'open-card' })
  assert.deepEqual(msg, { v: 1, type: 't27-app', kind: 'open-card', repo: 'gHashTag/trinity', number: 7, title: 'Ship the sheet', column: 'running' })
})

test('framed by the app on the same origin: the tap opens the chat, not GitHub', () => {
  const { win, sent } = framed(APP)
  const t = tap()
  assert.equal(openCardInApp(t, msg, win), true)
  assert.equal(t.prevented, 1)
  assert.deepEqual(sent, [{ m: msg, origin: APP }])
})

test('framed by another origin, or not framed: the link is followed', () => {
  const other = framed('https://t27.ai')
  const t = tap()
  assert.equal(openCardInApp(t, msg, other.win), false)
  assert.equal(t.prevented, 0)
  assert.equal(other.sent.length, 0)

  const alone = { location: { origin: APP } }
  alone.parent = alone
  assert.equal(openCardInApp(tap(), msg, alone), false)
  assert.equal(sameOriginParent(alone), null)
  assert.equal(openCardInApp(tap(), msg, undefined), false)
})

test('cmd-click, middle click and an already handled click keep the link', () => {
  const { win, sent } = framed(APP)
  for (const extra of [{ metaKey: true }, { ctrlKey: true }, { shiftKey: true }, { altKey: true }, { button: 1 }, { defaultPrevented: true }]) {
    const t = tap(extra)
    assert.equal(openCardInApp(t, msg, win), false, JSON.stringify(extra))
    assert.equal(t.prevented, 0)
  }
  assert.equal(sent.length, 0)
})
