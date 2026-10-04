// Contract for the IGLA board on WARS. Every number lives in
// specs/queen/igla_board.t27 (generated in gHashTag/igla-coder-gpu by
// scripts/board_t27.py); the UI and public files are projections of it.
import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const ROOT = new URL('..', import.meta.url).pathname
const read = (rel) => readFileSync(join(ROOT, rel), 'utf8')

const SPEC = 'specs/queen/igla_board.t27'
const JSON_OUT = 'public/queen/igla-board.json'
const PUBLIC_SPEC = 'public/queen/igla-board.t27'
const COMPONENT = 'src/components/IglaBoard.tsx'
const CSS = 'src/components/IglaBoard.css'
for (const file of [SPEC, 'scripts/igla-board-from-spec.mjs', 'src/lib/iglaBoard.generated.ts', JSON_OUT, PUBLIC_SPEC, COMPONENT, CSS]) {
  assert.ok(existsSync(join(ROOT, file)), `${file} is missing`)
}

const spec = read(SPEC)
assert.doesNotMatch(spec, /[^\x00-\x7f]/, 'the IGLA board .t27 must stay ASCII')
assert.match(spec, /^module queen_igla_board;/m)
assert.equal(read(PUBLIC_SPEC), spec, 'public/queen/igla-board.t27 must be byte-identical to the source spec')

const board = JSON.parse(read(JSON_OUT))
assert.equal(board.source.spec, SPEC)
assert.match(board.source.commit, /^[0-9a-f]{40}$/)
assert.match(board.live.state, /^https:\/\//)
// A lever verdict without two seeds is a single-seed claim (the m12 +6 was one).
for (const lever of board.levers) {
  assert.ok(new Set(lever.pairs.map((pair) => pair.seed)).size >= 2, `${lever.id} is not paired on two seeds`)
}
assert.ok(board.candidates.some((item) => /negative control/.test(item.verdict)), 'the arena lost its negative control')

const component = read(COMPONENT)
assert.match(component, /IGLA_BOARD/)
assert.match(component, /SESSION-OBSERVED/, 'the live strip must be labelled as read at view time')
assert.match(component, /credentials: 'omit'/)
assert.match(component, /data-outcome=/)
assert.doesNotMatch(component, /target="_blank"/, 'WARS stays inside the single Queen game window')
assert.doesNotMatch(component, /dangerouslySetInnerHTML/, 'live board text is data, never markup')
assert.match(read('src/components/QueenWars.tsx'), /<IglaBoard lang=\{lang\} \/>/)

const css = read(CSS)
assert.match(css, /\.igla-board\s*\{[^}]*display:\s*block;/s, 'the board must reset the global flex section layout')
assert.match(css, /\.igla-board-details > summary\s*\{[^}]*min-height:\s*44px;/s)
assert.match(css, /\.igla-board-cta\s*\{[^}]*min-height:\s*44px;/s)
assert.doesNotMatch(css, /font(?:-size)?\s*:[^;{}]*\b(?:8|9|10)px\b/, 'technical text must be at least 11px')
// Owner, 2026-10-01: the field is black, no green-tinted panels.
for (const [name, text] of [[CSS, css], ['src/components/QueenWars.css', read('src/components/QueenWars.css')]]) {
  assert.doesNotMatch(text, /rgba\(\s*[0-2],\s*(?:[4-9]|1\d),\s*\d+,/, `${name}: green-tinted dark background`)
  assert.doesNotMatch(text, /#0[0-3]1[0-9a-f]0[0-9a-f]/i, `${name}: green-tinted dark background`)
}
// Every device: wide tables stack into cards; each cell names its column.
assert.match(read('src/components/QueenWars.css'), /@media \(max-width: 860px\)[^@]*table\[data-stack\][^@]*attr\(data-label\)/s)
for (const table of component.match(/<table[^>]*>[\s\S]*?<\/table>/g) ?? []) {
  assert.match(table, /^<table data-stack=""/, 'an IGLA table without data-stack scrolls sideways on phones')
  const cells = table.match(/<td\b[^>]*>/g) ?? []
  assert.ok(cells.length && cells.every((td) => /data-label=/.test(td)), 'every IGLA cell needs data-label for the phone card')
}

console.log(`igla-board-contract: ${board.candidates.length} candidates, ${board.levers.length} levers, ${board.levers.reduce((n, l) => n + l.pairs.length, 0)} pairs; .t27 is authoritative`)
