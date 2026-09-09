// The readers in scripts/sync-skills.mjs, held to a case.
//
// The sync itself walks three working copies and cannot be run in a test, so
// everything it decides was written as a function of its arguments. These are
// the arguments. The cases that matter are the ones that already bit: a
// lowercase skill.md on a case-insensitive filesystem, a bare `registry.t27`
// that names two real specs, and a body mention treated as a promise.
//
//   node --test scripts/sync-skills.test.mjs

import test from 'node:test'
import assert from 'node:assert/strict'
import {
  parseFrontmatter,
  scanBody,
  detectLang,
  extractLinks,
  extractDates,
  extractBodyRefs,
  resolveSpecRef,
  findSecret,
  reviewHits,
  deriveLink,
  deriveHealth,
  deriveTags,
  clampDescription,
  pickMain,
} from './sync-skills.mjs'

// Cyrillic is built from code points rather than typed, so this file stays
// English while still feeding the language detector real letters.
const cyrillic = (n) => Array.from({ length: n }, (_, i) => String.fromCodePoint(0x430 + (i % 32))).join('')

const CORPUS = [
  'specs/demos/hello_world.t27',
  'compiler/skill/registry.t27',
  'specs/tools/registry.t27',
  'specs/server/http.t27',
  'specs/automation/wrapup-auto.t27',
]

test('frontmatter: quoted values, both quote styles, and the specs list', () => {
  const text = [
    '---',
    'name: "Quoted Name"',
    "description: 'Single quoted description'",
    'version: 1.2.0',
    'specs:',
    '  - specs/tools/registry.t27',
    '  - "specs/server/http.t27"',
    '---',
    '',
    '# Heading',
  ].join('\n')
  const { hasFrontmatter, frontmatter, specs, bodyStart } = parseFrontmatter(text)
  assert.equal(hasFrontmatter, true)
  assert.equal(frontmatter.name, 'Quoted Name')
  assert.equal(frontmatter.description, 'Single quoted description')
  assert.equal(frontmatter.version, '1.2.0')
  assert.deepEqual(specs, [
    { text: 'specs/tools/registry.t27', line: 6 },
    { text: 'specs/server/http.t27', line: 7 },
  ])
  assert.equal(bodyStart, 8)
  assert.equal(frontmatter.specs, undefined, 'a list key is not also a scalar')
})

test('frontmatter: absent, and an opening rule that never closes', () => {
  const none = parseFrontmatter('# Title\n\nBody text.\n')
  assert.deepEqual(none, { hasFrontmatter: false, frontmatter: {}, specs: [], bodyStart: 0 })
  const unterminated = parseFrontmatter('---\nname: adrift\n\nBody text.\n')
  assert.equal(unterminated.hasFrontmatter, false, 'a horizontal rule is not a header')
  assert.deepEqual(unterminated.specs, [])
})

test('body scan: fenced code never contributes a heading', () => {
  const text = [
    '# Real Heading',
    '',
    'The opening paragraph, on',
    'two lines.',
    '',
    '```bash',
    '# not a heading, a shell comment',
    'echo hi',
    '```',
    '',
    '## Second Heading',
  ].join('\n')
  const { headings, codeBlocks, firstParagraph } = scanBody(text)
  assert.deepEqual(headings.map((h) => h.text), ['Real Heading', 'Second Heading'])
  assert.deepEqual(headings.map((h) => h.level), [1, 2])
  assert.equal(headings[0].line, 1)
  assert.deepEqual(codeBlocks, [{ lang: 'bash', lines: 2 }])
  assert.equal(firstParagraph, 'The opening paragraph, on two lines.')
})

test('language: by letter ratio, with mixed as a real answer', () => {
  assert.equal(detectLang(`${cyrillic(80)} abc`), 'ru')
  assert.equal(detectLang('plain english prose about a skill'), 'en')
  assert.equal(detectLang(cyrillic(20) + 'a'.repeat(30)), 'mixed')
  assert.equal(detectLang(cyrillic(6) + 'a'.repeat(4)), 'mixed', 'exactly 0.6 is not "more than 0.6"')
  assert.equal(detectLang('1234 !!'), 'en', 'no letters is not a language failure')
})

test('links, hosts and dates come out deduped and sorted', () => {
  const text = 'See https://t27.ai/#/specs and https://t27.ai/#/specs again, plus http://example.test/a.\nShipped 2026-09-08, revised 2026-09-08, not 2026-13-40.'
  const { links, hosts } = extractLinks(text)
  assert.deepEqual(links, ['https://t27.ai/#/specs', 'http://example.test/a'])
  assert.deepEqual(hosts, ['example.test', 't27.ai'])
  assert.deepEqual(extractDates(text), ['2026-09-08'])
})

test('.t27 tokens: first occurrence keeps the line, repeats are dropped', () => {
  const body = [
    'It reads specs/demos/hello_world.t27 first.',
    'Then specs/demos/hello_world.t27 again, and registry.t27 too.',
  ].join('\n')
  assert.deepEqual(extractBodyRefs(body), [
    { text: 'specs/demos/hello_world.t27', line: 1 },
    { text: 'registry.t27', line: 2 },
  ])
})

test('resolution: exact, unique suffix, ambiguous, missing', () => {
  assert.deepEqual(resolveSpecRef('specs/demos/hello_world.t27', CORPUS), {
    to: 'specs/demos/hello_world.t27',
    candidates: ['specs/demos/hello_world.t27'],
    status: 'resolved',
  })
  assert.deepEqual(resolveSpecRef('server/http.t27', CORPUS), {
    to: 'specs/server/http.t27',
    candidates: ['specs/server/http.t27'],
    status: 'resolved',
  })
  const ambiguous = resolveSpecRef('registry.t27', CORPUS)
  assert.equal(ambiguous.status, 'ambiguous')
  assert.equal(ambiguous.to, null, 'two real files must not be collapsed into one link')
  assert.deepEqual(ambiguous.candidates, ['compiler/skill/registry.t27', 'specs/tools/registry.t27'])
  assert.deepEqual(resolveSpecRef('specs/ring-NNN-name.t27', CORPUS), { to: null, candidates: [], status: 'missing' })
})

test('secret refusal: every shape, with the needle built at runtime', () => {
  // Assembled here so this file never carries a literal that looks like a
  // credential to the next scanner that reads it.
  const cases = [
    ['api-key', `key: ${'sk-'}${'a'.repeat(24)}`],
    ['github-token', `${'ghp_'}${'b'.repeat(30)}`],
    ['github-fine-grained-token', `${'github'}_pat_x`],
    ['json-web-token', `${'eyJ'}${'c'.repeat(24)}.${'d'.repeat(14)}`],
    ['aws-access-key', `${'AKIA'}${'E'.repeat(16)}`],
    ['slack-token', `${'xox'}b-1-2`],
    ['private-key-block', `${'-----BEGIN'} RSA PRIVATE KEY-----`],
    ['telegram-bot-token', `${'1'.repeat(9)}:${'f'.repeat(35)}`],
    ['url-credentials', `${'postgres'}://user:pw@db.example.test/app`],
  ]
  for (const [name, needle] of cases) {
    assert.equal(findSecret(`before\n${needle}\nafter`), name, `${name} must stop a publish`)
  }
  assert.equal(findSecret('A skill about deploying, with no credential in it.'), null)
})

test('review hits: counted per pattern, never treated as a secret', () => {
  const text = 'Use ssh to reach the box at 10.0.0.1, then check railway.app and Infisical.'
  assert.deepEqual(reviewHits(text), [
    { pattern: 'ipv4', count: 1 },
    { pattern: 'ssh', count: 1 },
    { pattern: 'railway-host', count: 1 },
    { pattern: 'infisical', count: 1 },
  ])
  assert.equal(findSecret(text), null, 'an operations note is withheld, not refused')
  assert.deepEqual(reviewHits('Plain prose about writing tests.'), [])
})

test('review hits: a hardcoded home directory counts, a repository-relative path does not', () => {
  // The published catalog carried these before the pattern existed: a command
  // written against one laptop's account, which a reader of the public site
  // can neither run nor learn anything from.
  assert.deepEqual(reviewHits('Run /Users/someone/trinity-w1/zig-out/bin/tri status'), [{ pattern: 'home-path', count: 1 }])
  assert.deepEqual(reviewHits('and /home/runner/work/repo/bin/tri'), [{ pattern: 'home-path', count: 1 }])
  assert.deepEqual(reviewHits('Run `zig build` then `./zig-out/bin/tri status` from the repository root.'), [])
  assert.deepEqual(reviewHits('src/services/inngest/functions/trainModel.ts'), [])
})

test('link: only declared references decide it', () => {
  const declared = (status) => ({ declared: true, status })
  assert.equal(deriveLink([declared('resolved'), declared('resolved')]), 'bound')
  assert.equal(deriveLink([declared('resolved'), declared('missing')]), 'broken')
  assert.equal(deriveLink([declared('ambiguous')]), 'broken')
  assert.equal(deriveLink([]), 'unbound')
  assert.equal(
    deriveLink([{ declared: false, status: 'missing' }]),
    'unbound',
    'a sentence that mentions a spec has promised nothing',
  )
})

test('health: broken fails, unbound or an undeclared header warns', () => {
  const clean = { hasFrontmatter: true, duplicateFile: false }
  assert.equal(deriveHealth('broken', clean), 'fail')
  assert.equal(deriveHealth('bound', clean), 'ok')
  assert.equal(deriveHealth('unbound', clean), 'warn')
  assert.equal(deriveHealth('bound', { hasFrontmatter: false, duplicateFile: false }), 'warn')
  assert.equal(deriveHealth('bound', { hasFrontmatter: true, duplicateFile: true }), 'warn')
})

test('tags: derived from what the skill is, never hand-applied', () => {
  const tags = deriveTags({
    repo: 't27',
    lang: 'ru',
    link: 'bound',
    hasFrontmatter: true,
    liveShell: true,
    extras: ['scripts'],
    codeBlocks: [{ lang: 'bash', lines: 3 }],
    bytes: 9000,
    duplicateFile: true,
    specRefs: [
      { declared: true, status: 'resolved' },
      { declared: false, status: 'missing' },
    ],
  })
  assert.deepEqual(tags, [
    'has/code',
    'has/extras',
    'has/frontmatter',
    'has/live-shell',
    'issue/dangling-candidate',
    'issue/duplicate-file',
    'lang/ru',
    'link/bound',
    'size/medium',
    'src/t27',
  ])

  const bare = deriveTags({
    repo: 'trinity',
    lang: 'en',
    link: 'unbound',
    hasFrontmatter: false,
    liveShell: false,
    extras: [],
    codeBlocks: [],
    bytes: 900,
    duplicateFile: false,
    specRefs: [],
  })
  assert.deepEqual(bare, ['issue/no-frontmatter', 'lang/en', 'link/unbound', 'size/tiny', 'src/trinity'])
})

test('size buckets sit on their boundaries', () => {
  const at = (bytes) => deriveTags({ repo: 'x', lang: 'en', link: 'unbound', hasFrontmatter: true, liveShell: false, extras: [], codeBlocks: [], bytes, duplicateFile: false, specRefs: [] }).find((t) => t.startsWith('size/'))
  assert.equal(at(2047), 'size/tiny')
  assert.equal(at(2048), 'size/small')
  assert.equal(at(8192), 'size/medium')
  assert.equal(at(32768), 'size/large')
})

test('descriptions are clamped to 240 characters', () => {
  assert.equal(clampDescription('  spaced   out  '), 'spaced out')
  const long = clampDescription('word '.repeat(200))
  assert.ok(long.length <= 240)
  assert.ok(long.endsWith('...'))
})

test('the main file is picked by exact name, not by a case-blind filesystem', () => {
  assert.deepEqual(pickMain(['SKILL.md']), { source: 'SKILL.md', duplicateFile: false })
  assert.deepEqual(pickMain(['skill.md', 'notes.md']), { source: 'skill.md', duplicateFile: false })
  assert.deepEqual(pickMain(['README.md']), { source: 'README.md', duplicateFile: false })
  assert.deepEqual(pickMain(['README.md', 'skill.md']), { source: 'skill.md', duplicateFile: false })
  assert.deepEqual(pickMain(['SKILL.md', 'skill.md']), { source: 'SKILL.md', duplicateFile: true })
  assert.deepEqual(pickMain(['notes.md']), { source: null, duplicateFile: false })
})
