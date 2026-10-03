// MINE TRI on the landing: src/lib/triMine.ts and components/TriMineBlock.tsx.
//
// Pure, no browser. Holds the "Copy to agent" prompt and the block to:
//   1  the prompt carries the token's honest status in both languages:
//      testnet only, no price and no market, NOT trustless, no mainnet TRI
//   2  it names who earns (the spec author by GitHub login, or a provider of
//      compute) and the guard rails: the human says yes before a PR, no
//      provider key in a PR or a chat, no invented acceptance
//   3  a live rate is quoted with "the ledger states it"; a missing, zero,
//      negative or NaN rate is never printed and the agent is sent to the
//      ledger address instead; the same for minted and cap
//   4  the English prompt has no Cyrillic, and both languages carry the same
//      set of addresses
//   5  the block reads its figures (readMinterState, readEarnings) rather than
//      typing them, passes the real ledger and minter, and App.tsx mounts it
//      right after PlayBlock
//
//   node --experimental-strip-types qa/tri-mine-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { MINE_LINKS, minePrompt } from '../src/lib/triMine.ts'

const read = (rel) => readFileSync(new URL(`../${rel}`, import.meta.url), 'utf8')
let checks = 0
const ok = (value, message) => { checks++; assert.ok(value, message) }

const ROADS = {
  ledger: 'https://queen.example/queen/public-earnings',
  minter: 'https://testnet.tonviewer.com/kQ-minter',
  network: 'testnet',
}
const LIVE = { triPerSpec: 27, minted: '1,234', cap: '10,460,353,203' }

const en = minePrompt('en', ROADS, LIVE)
const ru = minePrompt('ru', ROADS, LIVE)

// 1  honest status
for (const [name, p] of [['en', en], ['ru', ru]]) {
  ok(p.includes('TON testnet'), `${name}: says TON testnet`)
  ok(/NOT trustless|НЕ trustless/.test(p), `${name}: says NOT trustless`)
  ok(/no price|цены нет|нет цены/i.test(p), `${name}: says there is no price`)
  ok(/No mainnet TRI exists|Mainnet TRI не существует/.test(p), `${name}: says no mainnet TRI exists`)
  ok(!/\btrustless\b/i.test(p.replace(/NOT trustless|НЕ trustless/g, '')), `${name}: never claims trustless`)
  ok(!/invest|profit|прибыл|инвест/i.test(p), `${name}: no investment language`)
}

// 2  who earns, and the guard rails
ok(/GitHub login/.test(en) && /логину GitHub/.test(ru), 'names the GitHub login as the one that earns')
ok(/proof of compute/.test(en) && /proof of compute/.test(ru), 'names proof of compute')
ok(/CPU, FPGA or GPU/.test(en) && /CPU, FPGA или GPU/.test(ru), 'names the three kinds of compute')
ok(/Only after my "yes"/.test(en) && /после моего «да»/.test(ru), 'the human says yes before a PR')
ok(/Never put a provider key/.test(en) && /Никогда не вставляй ключ провайдера/.test(ru), 'no provider key in a PR or chat')
ok(/Do not invent an acceptance/.test(en) && /Не выдумывай приёмку/.test(ru), 'no invented acceptance')
ok(/## Boundary/.test(en) && /## Boundary/.test(ru), 'the issue must declare a .t27 file in its boundary')

// 3  live figures, and their absence
ok(en.includes('27 TRI per accepted spec (as the ledger states it now)'), 'en quotes the live rate as the ledger states it')
ok(ru.includes('27 TRI за каждую принятую спеку'), 'ru quotes the live rate')
ok(en.includes('1,234 TRI minted of a 10,460,353,203 cap.'), 'en quotes minted and cap')
for (const bad of [undefined, 0, -3, Number.NaN, Number.POSITIVE_INFINITY]) {
  for (const lang of ['en', 'ru']) {
    const p = minePrompt(lang, ROADS, { triPerSpec: bad })
    ok(p.includes(`${ROADS.ledger} (`), `${lang}: rate ${bad} sends the agent to the ledger`)
    ok(!/\d+ TRI (per|за каждую)/.test(p), `${lang}: rate ${bad} is not printed`)
    ok(p.includes(ROADS.minter), `${lang}: no minted/cap sends the agent to the minter`)
  }
}
ok(minePrompt('en', ROADS, { minted: '5' }).includes(ROADS.minter), 'minted without cap is not half-printed')

// 4  language and addresses
ok(!/[Ѐ-ӿ]/.test(en), 'the English prompt has no Cyrillic')
const urls = (p) => new Set(p.match(/https:\/\/[^\s),]+/g))
assert.deepEqual([...urls(ru)].sort(), [...urls(en)].sort(), 'both languages carry the same addresses'); checks++
for (const [k, v] of Object.entries(MINE_LINKS)) ok(v.startsWith('https://'), `MINE_LINKS.${k} is https`)
for (const v of Object.values(MINE_LINKS)) ok(en.includes(v), `the prompt carries ${v}`)

// 5  the block and its mount
const block = read('src/components/TriMineBlock.tsx')
ok(/readMinterState\(/.test(block) && /readEarnings\(/.test(block), 'the block reads the minter and the ledger')
ok(/ledger: `\$\{QUEEN_API\}\/queen\/public-earnings`/.test(block), 'the block passes the real ledger address')
ok(/minter: TRI_EXPLORER/.test(block) && /network: TRI_NETWORK/.test(block), 'the block passes the real minter and network')
ok(/minePrompt\(key, ROADS, facts\)/.test(block), 'the copied prompt is built from what was read')
ok(!/\b27\b/.test(block), 'the block types no rate in by hand')
ok(/testnet only/.test(block) && /Только TON testnet/.test(block), 'the block shows the testnet status in both languages')
ok(/Copy to agent/.test(block) && /Скопировать агенту/.test(block), 'the button is named in both languages')
ok(/<pre>\{prompt\}<\/pre>/.test(block), 'the prompt is readable and selectable on the page')
ok(/setCopyState\('failed'\)/.test(block), 'a refused clipboard is said, not swallowed')
const app = read('src/App.tsx')
ok(/import TriMineBlock from '\.\/components\/TriMineBlock'/.test(app), 'App.tsx imports the block')
const play = app.indexOf('<PlayBlock />')
const mine = app.indexOf('<TriMineBlock />')
ok(play > 0 && mine > play && app.indexOf('<FaqBlock />') > mine, 'the block sits after PlayBlock and before the FAQ')

console.log(`tri-mine contract: ${checks} checks OK`)
