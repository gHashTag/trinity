// What the tri command lists, the Trinity card generator, the coverage gate and the --help recorder
// refuse, and what they let through.
//
//   node --test scripts/tri-commands.test.mjs

import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { readCasts } from './agents-from-specs.mjs'
import { CLIS, earlyRoutes, kebab, parserGroups, readSnapshot, t27Commands, trinityFromTree, zigString } from './tri-commands.mjs'
import { cards as trinityCards, coveredTokens, noHelp, inputs as trinityInputs } from './tools-from-trinity-tri.mjs'
import { bareEnv, castId, castLines } from './tri-help-casts.mjs'
import { castCoverage, coverage } from '../qa/tools-coverage-contract.mjs'

const SHA = '0123456789abcdef0123456789abcdef01234567'

const castFixture = (recordings) => {
  const root = mkdtempSync(join(tmpdir(), 'tri-cast-'))
  for (const { id, commands } of recordings) {
    const dir = join(root, 'public/term', id)
    mkdirSync(dir, { recursive: true })
    const lines = [JSON.stringify({ version: 2, width: 80, height: 24, title: id, commands }), ...commands.map((_, i) => JSON.stringify([i + 1, 'x', '0']))]
    writeFileSync(join(dir, 'session.cast'), lines.join('\n') + '\n')
    writeFileSync(join(dir, 'meta.json'), JSON.stringify({ id, title: id, url: `https://t27.ai/term/${id}/`, recorded: '2026-10-03 00:00 UTC', commands, exit_codes: commands.map(() => '0') }))
  }
  return readCasts(root)
}

test('t27: clap variants, kebab-case, help = the first paragraph of the /// doc, attributes skipped', () => {
  const src = [
    'enum Commands {',
    '    /// Show the status.',
    '    ///',
    '    /// Longer text that is not the summary.',
    '    Status,',
    '    #[command(hide = true)]',
    '    GenAll {',
    '        #[arg(long)]',
    '        out: String,',
    '    },',
    '    /// Two lines',
    '    /// of help.',
    '    #[command(alias = "x")]',
    '    XBoard,',
    '}',
  ].join('\n')
  const out = t27Commands(src)
  assert.deepEqual(out.map((c) => c.name), ['status', 'gen-all', 'x-board'])
  assert.equal(out[0].help, 'Show the status.')
  assert.equal(out[1].help, '', 'an undocumented variant has no help, not a guess')
  assert.equal(out[2].help, 'Two lines of help.')
  assert.equal(kebab('PerfClk'), 'perf-clk')
  assert.throws(() => t27Commands('fn main() {}'), /no `enum Commands/)
})

test('zigString decodes \\x byte escapes as UTF-8, \\u{...} and \\n', () => {
  assert.equal(zigString('\\xce\\xbc-core'), 'μ-core')
  assert.equal(zigString('\\u{3c6}'), 'φ')
  assert.equal(zigString('a\\nb\\"c'), 'a\nb"c')
})

test('parserGroups: the first `if` that matches a token wins; a later variant keeps only its unclaimed tokens', () => {
  const utils = [
    'pub fn parseCommand(arg: []const u8) Command {',
    '    if (std.mem.eql(u8, arg, "omega") or std.mem.eql(u8, arg, "--omega")) return .omega;',
    '    if (std.mem.eql(u8, arg, "omega") or std.mem.eql(u8, arg, "omega-phase")) return .omega_cmd;',
    '    if (std.mem.eql(u8, arg, "chat")) return .none;',
    '}',
  ].join('\n')
  const g = parserGroups(utils)
  assert.deepEqual(g.map((x) => [x.variant, x.tokens]), [['omega', ['omega']], ['omega_cmd', ['omega-phase']]])
})

test('earlyRoutes: a multi-line `if` is one route; only the comment line right above it is kept', () => {
  const main = [
    '    // CLARA namespace (belongs to the route above)',
    '    if (std.mem.eql(u8, first_arg, "clara")) {',
    '    }',
    '    // the bench runner',
    '    if (std.mem.eql(u8, first_arg, "bench") or',
    '        std.mem.eql(u8, first_arg, "benchmark") or std.mem.eql(u8, first_arg, "--bench")) {',
    '    }',
    '',
    '    if (std.mem.eql(u8, first_arg, "quiet")) {',
  ].join('\n')
  const r = earlyRoutes(main)
  assert.deepEqual(r.map((x) => x.tokens), [['clara'], ['bench', 'benchmark'], ['quiet']])
  assert.equal(r[1].comment, 'the bench runner')
  assert.equal(r[2].comment, '', 'a blank line above means no comment')
})

test('coveredTokens: only a card\'s COMMAND word covers a command, not the registry ALIASES it lists', () => {
  const card = 'pub const COMMAND : str = "tri constants";\npub const ALIASES : [1]str = ["c"];'
  assert.deepEqual([...coveredTokens([card])], ['constants'])
})

test('trinity/cli cards: no help says so with the pin; a name another tri has gets no recording; one it alone has does', () => {
  const snapshot = {
    commit: SHA,
    commands: [
      { name: 'quiet', aliases: [], help: '', helpSource: '', route: 'r', routeKind: 'early', routed: true, inRegistry: false, comment: '' },
      { name: 'status', aliases: ['st'], help: 'Show status', helpSource: 'registry description', route: 'r', routeKind: 'parse_command', routed: true, inRegistry: true, comment: '' },
      { name: 'ghost', aliases: [], help: 'Registry only', helpSource: 'registry description', route: 'r', routeKind: 'registry', routed: false, inRegistry: true, comment: '' },
      { name: 'covered', aliases: [], help: 'x', helpSource: 'x', route: 'r', routeKind: 'parse_command', routed: true, inRegistry: true, comment: '' },
    ],
  }
  const casts = castFixture([{ id: 'run-a', commands: ['tri quiet', 'tri status --all'] }])
  const t27 = { commands: [{ name: 'status', aliases: [] }] }
  const out = trinityCards({ snapshot, covered: new Set(['covered']), t27, others: [new Set(['status'])], casts })
  assert.deepEqual([...out.keys()].sort(), ['ghost.t27', 'quiet.t27', 'status.t27'], 'a command a trinity/tri card covers gets no second card')
  const quiet = out.get('quiet.t27')
  assert.match(quiet, new RegExp(`pub const ABOUT : str = "${noHelp(SHA)}`))
  assert.ok(noHelp(SHA).includes(SHA.slice(0, 12)))
  assert.match(quiet, /pub const CAST : str = "term\/run-a\/session\.cast";/, 'only Trinity has quiet, so the recording is its')
  const status = out.get('status.t27')
  assert.doesNotMatch(status, /pub const CAST/, 't27 also has status: meta.json cannot say which binary ran it')
  assert.match(status, /pub const COLLIDES_WITH : str = "gHashTag\/t27:tri\/status";/)
  assert.match(status, /pub const ALIASES : \[1\]str = \["st"\];/)
  assert.match(out.get('ghost.t27'), /pub const ROUTED : bool = false;\npub const ROUTE_KIND : str = "none";/)
  assert.throws(() => trinityCards({ snapshot: { ...snapshot, commit: 'abc' }, covered: new Set(), t27, others: [], casts }), /40-hex/)
})

test('coverage: an uncovered command and a card naming no command both fail; aliases cover', () => {
  const snapshots = {
    t27: { repo: 'gHashTag/t27', commit: SHA, commands: [{ name: 'gen', aliases: [] }, { name: 'test', aliases: [] }] },
    trinity: { repo: 'gHashTag/trinity', commit: SHA, commands: [{ name: 'bench', aliases: ['benchmark'] }] },
    trios: { repo: 'gHashTag/BrowserOS', commit: SHA, commands: [] },
  }
  const card = (dir, word, cast = null) => ({ family: 'tri-cli', specPath: `specs/tools/${dir}/${word}.t27`, command: `tri ${word}`, cast })
  const tools = [card('tri', 'gen'), card('tri', 'old'), card('trinity/tri', 'benchmark')]
  const r = coverage(snapshots, tools)
  assert.equal(r.problems.length, 2)
  assert.match(r.problems[0], /t27: `tri test` .* has no card/)
  assert.match(r.problems[1], /names `tri old`, which qa\/tri-commands\/t27\.json does not list/)
  assert.deepEqual(r.rows.map((x) => [x.cli, x.commands, x.cards]), [['t27', 2, 2], ['trinity', 1, 1], ['trios', 0, 0]])
})

test('castCoverage: an unambiguous recorded command needs its CAST; an ambiguous one must not carry it', () => {
  const snapshots = {
    t27: { commands: [{ name: 'status', aliases: [] }] },
    trinity: { commands: [{ name: 'status', aliases: [] }] },
    trios: { commands: [{ name: 'devkit', aliases: [] }] },
  }
  const casts = castFixture([{ id: 'rec', commands: ['tri devkit flow', 'tri status'] }])
  const src = 'term/rec/session.cast'
  const card = (dir, word, cast = null) => ({ family: 'tri-cli', specPath: `specs/tools/${dir}/${word}.t27`, command: `tri ${word}`, cast })
  const bad = castCoverage(snapshots, [card('trios/tri', 'devkit'), card('tri', 'status', { src })], casts)
  assert.equal(bad.length, 2)
  assert.match(bad.find((m) => m.includes('devkit')), /runs `tri devkit` \(trios only\), but the card has no CAST/)
  assert.match(bad.find((m) => m.includes('status')), /exists in t27 and trinity/)
  assert.deepEqual(castCoverage(snapshots, [card('trios/tri', 'devkit', { src }), card('tri', 'status')], casts), [])
})

test('tri-help-casts: an asciicast v2 header naming the command, staged typing, real output, the exit event last', () => {
  const lines = castLines({ title: 't', command: 'tri gen --help', chunks: [{ at: 0.01, text: 'usage\nline' }], exit: '0', timestamp: 1 }).trim().split('\n').map((l) => JSON.parse(l))
  assert.equal(lines[0].version, 2)
  assert.deepEqual(lines[0].commands, ['tri gen --help'])
  assert.ok(lines.slice(1).every((e) => Array.isArray(e) && e.length === 3))
  assert.ok(lines.some((e) => e[1] === 'o' && e[2] === 'usage\r\nline'))
  assert.deepEqual(lines.at(-1).slice(1), ['x', '0'])
  assert.equal(castId('trinity', 'Omega_Phase'), 'help-trinity-omega-phase')
  const env = bareEnv({ PATH: '/bin', GITHUB_TOKEN: 'x', TELEGRAM_BOT_TOKEN: 'y', LANG: 'C' })
  assert.equal(env.GITHUB_TOKEN, undefined)
  assert.equal(env.TELEGRAM_BOT_TOKEN, undefined)
  assert.equal(env.PATH, '/bin')
})

test('the committed snapshots: three CLIs, full SHAs, Trinity matches this checkout, trinity/cli matches its generator', () => {
  for (const cli of Object.keys(CLIS)) {
    const s = readSnapshot(cli)
    assert.match(s.commit, /^[0-9a-f]{40}$/, `${cli}: full SHA`)
    assert.equal(s.count, s.commands.length)
    assert.equal(new Set(s.commands.map((c) => c.name)).size, s.count, `${cli}: no duplicate names`)
  }
  const now = trinityFromTree()
  assert.deepEqual(now.commands, readSnapshot('trinity').commands)
  const out = trinityCards(trinityInputs())
  assert.ok(out.size > 0)
})
