// Coverage gate: every command of every tri has a card, and every published recording reaches its cards.
//
// Three programs answer to `tri`; each has a command list committed under qa/tri-commands/ with the
// commit it was read at (scripts/tri-commands.mjs):
//   t27      gHashTag/t27 cli/tri/src/main.rs           -> cards in specs/tools/tri/
//   trinity  this repository's src/tri dispatcher        -> cards in specs/tools/trinity/{tri,cli}/
//   trios    gHashTag/BrowserOS trios/bin/tri            -> cards in specs/tools/trios/tri/
// This gate fails when
//   * the Trinity snapshot no longer matches src/tri of this checkout (the other two are external
//     checkouts, so their snapshot is the gate's input and its SHA the card's pin);
//   * a command (its name or one of its aliases) has no card in its CLI's card dirs;
//   * a card names a command its CLI's snapshot does not list;
//   * specs/tools/trinity/cli/ is not what scripts/tools-from-trinity-tri.mjs writes today;
//   * a published recording (public/term/<id>/meta.json commands) runs `tri X`, X belongs to exactly one
//     CLI, and that CLI's card for X has no CAST -- or X belongs to more than one CLI and a card of it
//     carries that recording anyway (meta.json does not say which binary ran).
// It prints, per CLI: commands, cards, cards with a recording, cards without one.
//
//   node --experimental-strip-types qa/tools-coverage-contract.mjs

import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { readToolCatalog, readCasts, castCommands } from '../scripts/agents-from-specs.mjs'
import { CLIS, readSnapshot, trinityFromTree, REPO_ROOT, TRINITY_FILES } from '../scripts/tri-commands.mjs'
import { cards as trinityCards, inputs as trinityInputs, OUT_DIR as TRINITY_OUT } from '../scripts/tools-from-trinity-tri.mjs'

// A card's dir under specs/tools/ ("trinity/cli" for specs/tools/trinity/cli/bench.t27) and its command word(s).
const dirOf = (card) => String(card.specPath ?? '').replace(/^specs\/tools\//, '').replace(/\/[^/]+\.t27$/, '')
const wordOf = (card) => String(card.command ?? '').replace(/^tri /, '')

// Every command of every CLI must be covered by a card.
export function coverage(snapshots, tools) {
  const out = { problems: [], rows: [] }
  for (const [cli, meta] of Object.entries(CLIS)) {
    const snap = snapshots[cli]
    if (!snap) { out.problems.push(`qa/tri-commands/${cli}.json is missing`); continue }
    const dirs = new Set(meta.cardDirs)
    const mine = tools.filter((t) => t.family === 'tri-cli' && dirs.has(dirOf(t)))
    const byWord = new Map(mine.map((t) => [wordOf(t), t]))
    const tokenOwner = new Map()
    for (const c of snap.commands) for (const tok of [c.name, ...(c.aliases ?? [])]) tokenOwner.set(tok, c.name)
    const uncovered = snap.commands.filter((c) => ![c.name, ...(c.aliases ?? [])].some((tok) => byWord.has(tok)))
    for (const c of uncovered) out.problems.push(`${cli}: \`tri ${c.name}\` (${snap.repo}@${snap.commit.slice(0, 12)}) has no card in ${meta.cardDirs.map((d) => `specs/tools/${d}/`).join(' or ')}`)
    const stray = mine.filter((t) => !tokenOwner.has(wordOf(t)))
    for (const t of stray) out.problems.push(`${cli}: ${t.specPath} names \`${t.command}\`, which qa/tri-commands/${cli}.json does not list`)
    const withCast = mine.filter((t) => t.cast !== null && t.cast !== undefined).length
    out.rows.push({ cli, repo: snap.repo, commit: snap.commit, commands: snap.commands.length, cards: mine.length, withCast, withoutCast: mine.length - withCast })
  }
  return out
}

// Every `tri X` a published recording ran: X in exactly one CLI -> that CLI's card has the CAST;
// X in several -> no card carries this recording.
export function castCoverage(snapshots, tools, casts) {
  const out = []
  const owners = (word) => Object.entries(snapshots).filter(([, s]) => s?.commands.some((c) => [c.name, ...(c.aliases ?? [])].includes(word))).map(([cli]) => cli)
  for (const [id, c] of casts) {
    const words = [...new Set(castCommands(c).map((line) => /^tri ([^\s]+)/.exec(String(line))?.[1]).filter(Boolean))]
    for (const word of words) {
      const clis = owners(word)
      const src = `term/${id}/session.cast`
      const carrying = tools.filter((t) => t.family === 'tri-cli' && t.cast?.src === src && wordOf(t) === word)
      const isAmbiguous = clis.length > 1
      if (isAmbiguous) {
        for (const t of carrying) out.push(`${t.specPath}: carries ${src}, but \`tri ${word}\` exists in ${clis.join(' and ')} and meta.json does not say which ran`)
        continue
      }
      if (clis.length === 0) continue
      const dirs = new Set(CLIS[clis[0]].cardDirs)
      const snap = snapshots[clis[0]]
      const name = snap.commands.find((x) => [x.name, ...(x.aliases ?? [])].includes(word)).name
      const tokens = new Set(snap.commands.find((x) => x.name === name).aliases.concat(name))
      const card = tools.find((t) => t.family === 'tri-cli' && dirs.has(dirOf(t)) && tokens.has(wordOf(t)))
      const hasThisCast = card?.cast?.src === src
      const missesCast = card !== undefined && !hasThisCast && !card.cast
      if (missesCast) out.push(`${card.specPath}: public/term/${id}/meta.json runs \`tri ${word}\` (${clis[0]} only), but the card has no CAST`)
    }
  }
  return out
}

function main() {
  const problems = []
  const fail = (m) => problems.push(m)
  const snapshots = Object.fromEntries(Object.keys(CLIS).map((cli) => [cli, readSnapshot(cli)]))

  // 1. The Trinity snapshot is what this checkout's dispatcher says.
  {
    const filesHere = Object.values(TRINITY_FILES).every((p) => existsSync(join(REPO_ROOT, p)))
    if (filesHere) {
      const now = trinityFromTree()
      const was = snapshots.trinity
      const same = was && JSON.stringify(now.commands) === JSON.stringify(was.commands) && JSON.stringify(now.notCounted) === JSON.stringify(was.notCounted)
      if (!same) fail(`qa/tri-commands/trinity.json is stale against src/tri of this checkout; run node scripts/tri-commands.mjs --cli trinity --commit "$(git log -1 --format=%H -- ${Object.values(TRINITY_FILES).join(' ')})"`)
    } else {
      fail(`${Object.values(TRINITY_FILES).join(', ')} not found under ${REPO_ROOT}`)
    }
  }

  // 2. trinity/cli is what the generator writes today.
  {
    const want = trinityCards(trinityInputs())
    const dir = join(REPO_ROOT, 'apps/website', TRINITY_OUT)
    const have = existsSync(dir) ? readdirSync(dir).filter((f) => f.endsWith('.t27')) : []
    const drift = [...[...want].filter(([f, t]) => !existsSync(join(dir, f)) || readFileSync(join(dir, f), 'utf8') !== t).map(([f]) => f), ...have.filter((f) => !want.has(f))]
    if (drift.length) fail(`${TRINITY_OUT}: ${drift.length} card(s) differ from scripts/tools-from-trinity-tri.mjs (${drift.slice(0, 6).join(', ')})`)
  }

  // 3. Every command has a card; every card a command.
  const tools = readToolCatalog().tools
  const cov = coverage(snapshots, tools)
  problems.push(...cov.problems)

  // 4. Recordings reach their cards.
  problems.push(...castCoverage(snapshots, tools, readCasts()))

  const pad = (s, n) => String(s).padEnd(n)
  console.log(`${pad('cli', 8)} ${pad('source', 34)} ${pad('commands', 9)} ${pad('cards', 6)} ${pad('recorded', 9)} no recording yet`)
  for (const r of cov.rows) console.log(`${pad(r.cli, 8)} ${pad(`${r.repo}@${r.commit.slice(0, 12)}`, 34)} ${pad(r.commands, 9)} ${pad(r.cards, 6)} ${pad(r.withCast, 9)} ${r.withoutCast}`)
  const total = (k) => cov.rows.reduce((a, r) => a + r[k], 0)
  console.log(`${pad('total', 8)} ${pad('', 34)} ${pad(total('commands'), 9)} ${pad(total('cards'), 6)} ${pad(total('withCast'), 9)} ${total('withoutCast')}`)

  if (problems.length) {
    for (const p of problems) console.error(`  - ${p}`)
    console.error(`tools coverage: ${problems.length} problem(s)`)
    process.exit(1)
  }
  console.log('tools coverage: every tri command has a card, every card a command, every unambiguous recorded command its CAST')
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main()
