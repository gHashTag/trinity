// THE ARRIVAL HALF OF THE CHANNEL TAGS: a tagged visit to t27.ai is reported
// once, untagged visits never, and a failure never reaches the page.
// Run: node --experimental-strip-types qa/traffic-arrival-contract.mjs
import assert from 'node:assert/strict'
import { arrivalFromSearch, reportArrival, ARRIVAL_URL, carrySource, SOURCE_KEY } from '../src/lib/trafficArrival.ts'

// The form the agents publish: the query BEFORE the hash route.
const blog = new URL('https://t27.ai/?utm_source=x&utm_medium=social&utm_campaign=blog&utm_content=gf-t#/blog/gf-t')
assert.deepEqual(arrivalFromSearch(blog.search), {
  source: 'x', medium: 'social', campaign: 'blog', content: 'gf-t',
})
assert.equal(arrivalFromSearch(''), null, 'no tags, no arrival')
assert.equal(arrivalFromSearch('?utm_medium=social'), null, 'no source, no arrival')
// A query written after the hash is part of the route: not ours to read here.
assert.equal(arrivalFromSearch(new URL('https://t27.ai/#/blog/s?utm_source=x').search), null)

const store = new Map()
const storage = { getItem: k => store.get(k) ?? null, setItem: (k, v) => void store.set(k, v) }
const calls = []
const send = async (url, init) => { calls.push([url, JSON.parse(init.body)]); return new Response('{}') }
assert.equal(await reportArrival('?utm_source=reddit', send, storage), true)
assert.equal(await reportArrival('?utm_source=reddit', send, storage), false, 'once per session')
assert.equal(await reportArrival('', send, new Map() && { getItem: () => null, setItem: () => {} }), false)
assert.deepEqual(calls, [[ARRIVAL_URL, { source: 'reddit' }]])

const failing = async () => { throw new Error('offline') }
assert.equal(await reportArrival('?utm_source=threads', failing, { getItem: () => null, setItem: () => {} }), false)

// The channel rides on into the bot: remembered at the arrival...
assert.equal(store.get(SOURCE_KEY), 'reddit', 'the visit remembers its channel')
// ...and put at the end of OUR bot's /start payload, the way the bot reads it.
assert.equal(carrySource('https://t.me/t27ai_bot?start=website', 'x'), 'https://t.me/t27ai_bot?start=website__x')
assert.equal(carrySource('https://t.me/t27ai_bot?start=foundry', 'Reddit'), 'https://t.me/t27ai_bot?start=foundry__reddit')
assert.equal(carrySource('https://t.me/other_bot?start=website', 'x'), 'https://t.me/other_bot?start=website', 'never somebody else\'s bot')
assert.equal(carrySource('https://t.me/t27_lang', 'x'), 'https://t.me/t27_lang', 'a channel link is not a bot start')
assert.equal(carrySource('https://t.me/t27ai_bot?start=website__x', 'reddit'), 'https://t.me/t27ai_bot?start=website__x', 'a channel already there stays')
assert.equal(carrySource('https://t.me/t27ai_bot?start=website', null), 'https://t.me/t27ai_bot?start=website', 'no channel, no tag')
const long = 'a'.repeat(62) // + '__x' = 65 > 64
assert.equal(carrySource(`https://t.me/t27ai_bot?start=${long}`, 'x'), `https://t.me/t27ai_bot?start=${long}`, 'never past 64 characters')

console.log('traffic-arrival contract: 16 checks passed')
