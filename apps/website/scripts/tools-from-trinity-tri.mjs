#!/usr/bin/env node
// tools-from-trinity-tri.mjs -- a card for every command of the gHashTag/trinity Zig tri that has none.
//
// specs/tools/trinity/tri/ holds the 29 commands the binary's own registry export marks mcp_enabled
// (registry-export witness). Every other command scripts/tri-commands.mjs found in this repository's
// dispatcher (qa/tri-commands/trinity.json) gets a card here, under specs/tools/trinity/cli/<name>.t27:
//   * a command is covered when its name or one of its aliases is the COMMAND of a trinity/tri card;
//     covered commands get no second card;
//   * ABOUT is the command's own help text from the snapshot (registry description, `tri help` line,
//     or `tri <name> --help`), else "no help text in gHashTag/trinity@<sha>" -- never a guess;
//   * COLLIDES_WITH names the t27 card of the same command, when qa/tri-commands/t27.json lists it;
//   * CAST names a published recording (public/term/<id>/) whose meta.json lists a run of the command,
//     only when no other tri (qa/tri-commands/t27.json, trios.json) has a command of that name: meta
//     does not say which binary ran, so an ambiguous name never gets someone else's recording.
// Witness source-parse: the source was read as text at SOURCE_COMMIT; the CLI was not built or run.
//
// Run:  node scripts/tools-from-trinity-tri.mjs           write the cards (empties trinity/cli/ first)
//       node scripts/tools-from-trinity-tri.mjs --check   exit 1 when a card differs
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { castCommandRuns, castCommands, readCasts } from './agents-from-specs.mjs'
import { ascii, castFor } from './tools-from-trios-tri.mjs'
import { readSnapshot } from './tri-commands.mjs'

const SITE = join(dirname(fileURLToPath(import.meta.url)), '..')
export const OUT_DIR = 'public/t27/files/specs/tools/trinity/cli'
export const COVERING_DIR = 'public/t27/files/specs/tools/trinity/tri'
export const REPO = 'gHashTag/trinity'
// The snapshot's routeKind -> the card's ROUTE_KIND (agents-from-specs TOOL_ROUTE_KINDS).
export const ROUTE_KIND_OF = { early: 'main_chain', namespace: 'namespace', parse_command: 'parse_command', registry: 'none' }
export const ENTRY_OF = {
  early: 'src/tri/main.zig (the first_arg routes before any parser)',
  namespace: 'src/tri/main.zig dispatchNamespacedCommand',
  parse_command: 'src/tri/main.zig (switch on tri_utils.parseCommand)',
  registry: 'src/registry/command_table.zig (no dispatcher names it)',
}
export const SOURCE_OF = { early: 'src/tri/main.zig', namespace: 'src/tri/tri_namespace.zig', parse_command: 'src/tri/tri_utils.zig', registry: 'src/registry/command_table.zig' }

export const noHelp = (commit) => `no help text in ${REPO}@${commit.slice(0, 12)}`

// The COMMAND words of the registry-export cards: a command whose name or parser alias is one of them
// already has a card. The cards' registry ALIASES do not count: the registry calls "c" an alias of
// constants and "forge" one of fpga, while the dispatcher sends `tri c` to chat and `tri forge` to a namespace.
export function coveredTokens(texts) {
  const out = new Set()
  for (const t of texts) {
    const cmd = /pub const COMMAND : str = "tri ([^"]+)";/.exec(t)?.[1]
    if (cmd) out.add(cmd)
  }
  return out
}

const tokensOf = (snap) => new Set((snap?.commands ?? []).flatMap((c) => [c.name, ...c.aliases]))
const q = (s) => `"${s.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`
const arr = (xs) => `[${xs.length}]str = [${xs.map(q).join(', ')}]`
export const modName = (base) => `tool_trinity_cli_${base.replace(/[^A-Za-z0-9]+/g, '_')}`

export function cards({ snapshot, covered, t27, others, casts = new Map() }) {
  const commit = snapshot.commit
  if (!/^[0-9a-f]{40}$/.test(commit ?? '')) throw new Error('qa/tri-commands/trinity.json: commit is not a full 40-hex SHA')
  const t27Names = new Set((t27?.commands ?? []).map((c) => c.name))
  const out = new Map()
  for (const c of snapshot.commands) {
    const isCovered = [c.name, ...c.aliases].some((t) => covered.has(t))
    if (isCovered) continue
    const where = `tri ${c.name}`
    const about = ascii(c.help || `${noHelp(commit)}: neither the registry, \`tri help\` nor \`tri ${c.name} --help\` describes it`, where)
    const aboutSource = c.help ? `${c.helpSource}, at ${commit.slice(0, 12)}` : `${REPO}@${commit.slice(0, 12)}: src/registry/command_table.zig, printHelp and printCommandHelp of src/tri/tri_utils.zig name no description`
    const routeNote = ascii(`${c.route}${c.comment ? `. Source comment above the route (${c.comment.replace(/:.*/, '')}): ${c.comment.replace(/^[^:]*:\d+: /, '')}` : ''}`, where)
    const ambiguous = others.some((s) => s.has(c.name))
    const recording = ambiguous ? null : castFor(`tri ${c.name}`, casts)
    const castLines = recording === null ? [] : [
      `; public/term/${recording.id}/meta.json lists ${castCommands(recording).filter((line) => castCommandRuns(line, `tri ${c.name}`)).length} run(s) of \`tri ${c.name}\`, and no other tri has a command of that name.`,
      `pub const CAST : str = ${q(`term/${recording.id}/session.cast`)};`,
    ]
    const lines = [
      '// SPDX-License-Identifier: Apache-2.0',
      `; specs/tools/trinity/cli/${c.name}.t27 -- tool ${REPO}:tri/${c.name}, the \`tri ${c.name}\` command of the Trinity Zig tri`,
      `; Generated by apps/website/scripts/tools-from-trinity-tri.mjs from apps/website/qa/tri-commands/trinity.json`,
      `; (${REPO} at ${commit.slice(0, 12)}, read by scripts/tri-commands.mjs); do not edit.`,
      '; A command the registry export does not mark mcp_enabled, so specs/tools/trinity/tri/ has no card for it.',
      '; It is another program than the Rust tri of gHashTag/t27, so the ID is repository-qualified.',
      '; A card is data and carries no test block. ASCII only (L3). phi^2 + 1/phi^2 = 3 | TRINITY',
      '',
      `module ${modName(c.name)};`,
      '',
      'pub const KIND : str = "tool";',
      'pub const FAMILY : str = "tri-cli";',
      `pub const ID : str = ${q(`${REPO}:tri/${c.name}`)};`,
      `pub const REPO : str = ${q(REPO)};`,
      `pub const QUALIFIED_ID : str = ${q(`${REPO}:tri/${c.name}`)};`,
      'pub const SCHEMA : u32 = 2;',
      `pub const COMMAND : str = ${q(`tri ${c.name}`)};`,
      '; The first dispatcher layer of src/tri/main.zig that names the command (early route, namespace, parser), or none.',
      `pub const VARIANT : str = ${q(ascii(c.route.split('; then ')[0], where))};`,
      `pub const SOURCE : str = ${q(SOURCE_OF[c.routeKind])};`,
      `pub const ENTRY : str = ${q(ENTRY_OF[c.routeKind])};`,
      `pub const SOURCE_COMMIT : str = ${q(commit)};`,
      `pub const ROUTED : bool = ${c.routed};`,
      `pub const ROUTE_KIND : str = ${q(ROUTE_KIND_OF[c.routeKind])};`,
      `pub const ROUTE_NOTE : str = ${q(routeNote)};`,
      `pub const IN_REGISTRY : bool = ${c.inRegistry};`,
      `pub const ABOUT : str = ${q(about)};`,
      `pub const ABOUT_SOURCE : str = ${q(ascii(aboutSource, where))};`,
      'pub const ACTIONS : [0]str = [];',
      'pub const ACTIONS_ABOUT : [0]str = [];',
      'pub const ARGS : [0]str = [];',
      `pub const ALIASES : ${arr(c.aliases.map((a) => ascii(a, where)))};`,
      `pub const COLLIDES_WITH : str = ${q(t27Names.has(c.name) ? `gHashTag/t27:tri/${c.name}` : '')};`,
      'pub const AGENTS : [0]str = [];',
      `pub const AGENTS_NOTE : str = ${q('No source binds an agent letter to this command: docs/agents/AGENTS_ALPHABET.md and .claude/agents/*.md of gHashTag/t27 name the t27 tri, not this binary.')};`,
      `pub const WHEN_TO_USE : str = ${q(about)};`,
      ...castLines,
      'pub const WITNESS : str = "source-parse";',
      `pub const WITNESS_SOURCE : str = ${q(`${REPO} at ${commit}: src/tri/main.zig, src/tri/tri_namespace.zig, src/tri/tri_utils.zig and src/registry/command_table.zig read as text by apps/website/scripts/tri-commands.mjs; the CLI was not built or run`)};`,
      'pub const ENABLED : bool = true;',
      '',
    ]
    out.set(`${c.name}.t27`, lines.join('\n'))
  }
  return out
}

export function inputs(site = SITE) {
  const snapshot = readSnapshot('trinity', site)
  if (!snapshot) throw new Error('qa/tri-commands/trinity.json is missing; run node scripts/tri-commands.mjs --cli trinity')
  const dir = join(site, COVERING_DIR)
  const covered = coveredTokens(readdirSync(dir).filter((f) => f.endsWith('.t27')).map((f) => readFileSync(join(dir, f), 'utf8')))
  const t27 = readSnapshot('t27', site)
  const others = [tokensOf(t27), tokensOf(readSnapshot('trios', site))]
  return { snapshot, covered, t27, others, casts: readCasts(site) }
}

function main() {
  const check = process.argv.includes('--check')
  const input = inputs()
  const want = cards(input)
  const dir = join(SITE, OUT_DIR)
  const have = existsSync(dir) ? readdirSync(dir).filter((f) => f.endsWith('.t27')) : []
  const drift = [...[...want].filter(([f, t]) => !existsSync(join(dir, f)) || readFileSync(join(dir, f), 'utf8') !== t).map(([f]) => f), ...have.filter((f) => !want.has(f))]
  const noHelpCount = [...want.values()].filter((t) => t.includes('pub const ABOUT : str = "no help text in ')).length
  const withCast = [...want.values()].filter((t) => t.includes('pub const CAST : str = ')).length
  const sha = input.snapshot.commit.slice(0, 12)
  if (check) {
    if (drift.length) { console.error(`trinity tri cards: ${drift.length} drifted (${drift.slice(0, 8).join(', ')}${drift.length > 8 ? ', ...' : ''}); run node scripts/tools-from-trinity-tri.mjs`); process.exit(1) }
    console.log(`trinity tri cards: ${want.size} in step with ${REPO}@${sha} (${input.snapshot.count - want.size} covered by trinity/tri, ${noHelpCount} without help text, ${withCast} with a recorded run)`)
    return
  }
  rmSync(dir, { recursive: true, force: true })
  mkdirSync(dir, { recursive: true })
  for (const [f, t] of want) writeFileSync(join(dir, f), t)
  console.log(`trinity tri cards: wrote ${want.size} to ${OUT_DIR} from ${REPO}@${sha} (${input.snapshot.count - want.size} covered by trinity/tri, ${noHelpCount} without help text, ${withCast} with a recorded run, ${drift.length} changed)`)
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main()
