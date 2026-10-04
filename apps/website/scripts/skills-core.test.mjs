// What the prebuild index refuses, and what it lets through.
//
// The index is the only gate between a committed catalog and a build, so the
// interesting cases are the failures: a spec that moved out from under a
// declared binding, a vendored file whose bytes no longer match the manifest,
// and a link count quietly sliding past the baseline. The fourth case matters
// just as much -- an unbound skill is normal and must NOT fail, or the gate
// teaches people to write bindings they do not mean.
//
//   node --test scripts/skills-core.test.mjs

import test from 'node:test'
import assert from 'node:assert/strict'
import { buildSkillIndex } from './skills-core.mjs'

const SPECS = [
  'specs/demos/hello_world.t27',
  'specs/git/operations.t27',
  'specs/github/prs.t27',
  'specs/tools/registry.t27',
  'compiler/skill/registry.t27',
]

const ref = (text, over = {}) => ({ text, line: 0, declared: true, via: 'site', to: text, candidates: [text], status: 'resolved', ...over })

// A fixture the index would accept: the derived fields agree with the
// references, because the point of most tests below is the ONE thing each of
// them breaks. A fixture that was quietly self-contradictory would fail every
// test for the wrong reason, and hide the one the test is about.
function skill(id, { sha = 'a'.repeat(64), specRefs = [] } = {}) {
  const [repo, dir] = id.split('/')
  const declared = specRefs.filter((r) => r.declared)
  const link = declared.some((r) => r.status !== 'resolved') ? 'broken' : declared.length ? 'bound' : 'unbound'
  return {
    id,
    repo,
    dir,
    path: `${repo}/${dir}/SKILL.md`,
    source: 'SKILL.md',
    name: dir,
    description: `The ${dir} skill.`,
    frontmatter: {},
    hasFrontmatter: true,
    lang: 'en',
    bytes: 100,
    lines: 10,
    sha256: sha,
    headings: [],
    codeBlocks: [],
    links: [],
    hosts: [],
    dates: [],
    extras: [],
    liveShell: false,
    specsDeclared: [],
    specRefs,
    tags: [`lang/en`, `link/${link}`, `src/${repo}`].sort(),
    link,
    health: link === 'broken' ? 'fail' : link === 'bound' ? 'ok' : 'warn',
  }
}

function tally(items) {
  const counts = {}
  for (const item of items) counts[item] = (counts[item] ?? 0) + 1
  return counts
}

function input(skills, over = {}) {
  const publish = {}
  for (const entry of skills) (publish[entry.repo] ??= []).push(entry.dir)
  return {
    manifest: {
      version: 1,
      skillCount: skills.length,
      featured: skills[0]?.id,
      langs: { ru: 0, en: 0, mixed: 0, ...tally(skills.map((entry) => entry.lang)) },
      bySource: tally(skills.map((entry) => entry.source)),
      tags: tally(skills.flatMap((entry) => entry.tags)),
      skills,
    },
    publish,
    specPaths: SPECS,
    fileHashes: Object.fromEntries(skills.map((entry) => [entry.path, entry.sha256])),
    filesOnDisk: skills.map((entry) => entry.path),
    baseline: skills.length,
    provenance: { manifestSha256: 'm', specManifestSha256: 's', indexerSha256: 'i' },
    ...over,
  }
}

test('a declared reference to a spec that no longer exists fails, and says what to write', () => {
  const gone = skill('t27/tri', { specRefs: [ref('specs/git/operations.t27'), ref('specs/tools/gone.t27')] })
  const { problems } = buildSkillIndex(input([gone]))
  assert.ok(problems.some((line) => line.includes('t27/tri') && line.includes('specs/tools/gone.t27')))
  assert.ok(problems.some((line) => line.includes('frontmatter line to add:  - ')), 'the fix has to be copy-pasteable')
})

test('a declared reference that now matches two specs fails as ambiguous', () => {
  const both = skill('t27/tri', { specRefs: [ref('registry.t27')] })
  const { problems, core } = buildSkillIndex(input([both]))
  assert.ok(problems.some((line) => line.includes('matches 2 corpus paths')))
  assert.deepEqual(core.coverage.skillsBroken, ['t27/tri'])
})

test('a vendored file whose bytes drifted from the manifest fails', () => {
  const one = skill('trinity/cloud')
  const tampered = input([one], { fileHashes: { [one.path]: 'b'.repeat(64) } })
  const { problems } = buildSkillIndex(tampered)
  assert.equal(problems.length, 1)
  assert.match(problems[0], /trinity\/cloud: SHA-256 mismatch/)
})

test('a vendored file with no manifest entry, and a manifest entry with no file, both fail', () => {
  const one = skill('trinity/cloud')
  const stray = buildSkillIndex(input([one], { filesOnDisk: [one.path, 'trinity/ghost/SKILL.md'] }))
  assert.ok(stray.problems.some((line) => line.includes('trinity/ghost/SKILL.md') && line.includes('no manifest entry')))
  const absent = buildSkillIndex(input([one], { fileHashes: {} }))
  assert.ok(absent.problems.some((line) => line.includes('vendored file is missing')))
})

test('unbound skills over the baseline fail; the same skills within it pass', () => {
  const skills = [skill('trinity/wave'), skill('trinity/status')]
  const over = buildSkillIndex(input(skills, { baseline: 1 }))
  assert.ok(over.problems.some((line) => line.includes('2 skills declare no spec, over the baseline of 1')))

  const within = buildSkillIndex(input(skills, { baseline: 2 }))
  assert.deepEqual(within.problems, [], 'an unbound skill is not a failure')
  assert.deepEqual(within.core.coverage.skillsUnbound, ['trinity/status', 'trinity/wave'])
  assert.deepEqual(within.core.coverage.skillsBound, [])
  assert.equal(within.core.coverage.baselineUnbound, 2)
  assert.equal(within.core.coverage.specsWithoutSkill, SPECS.length)
})

test('a bound catalog indexes clean, and the two maps are exact inverses', () => {
  const skills = [
    skill('999-multibots-telegraf/git-workflow', { specRefs: [ref('specs/git/operations.t27'), ref('specs/github/prs.t27')] }),
    skill('t27/tri', { specRefs: [ref('specs/tools/registry.t27'), { ...ref('specs/demos/hello_world.t27'), declared: false, via: 'body' }] }),
    skill('trinity/wave'),
  ]
  const { problems, core } = buildSkillIndex(input(skills, { baseline: 1 }))
  assert.deepEqual(problems, [])
  assert.deepEqual(core.coverage.skillsBound, ['999-multibots-telegraf/git-workflow', 't27/tri'])
  assert.deepEqual(core.coverage.skillsUnbound, ['trinity/wave'])
  assert.deepEqual(core.skillToSpecs['t27/tri'], ['specs/tools/registry.t27'], 'a body mention is not coverage')
  assert.deepEqual(core.coverage.specsWithSkill, ['specs/git/operations.t27', 'specs/github/prs.t27', 'specs/tools/registry.t27'])
  assert.equal(core.coverage.specsWithoutSkill, SPECS.length - 3)

  const inverted = {}
  for (const [id, paths] of Object.entries(core.skillToSpecs)) for (const path of paths) (inverted[path] ??= []).push(id)
  for (const path of Object.keys(inverted)) inverted[path].sort()
  assert.deepEqual(core.specToSkills, inverted)
})

test('an unsafe id, a skill off the allowlist and a miscounted manifest all fail', () => {
  const bad = { ...skill('trinity/wave'), id: '../escape' }
  assert.ok(buildSkillIndex(input([bad])).problems.some((line) => line.includes('not a valid catalog id')))

  const one = skill('trinity/wave')
  const off = buildSkillIndex(input([one], { publish: { trinity: [] } }))
  assert.ok(off.problems.some((line) => line.includes('not on the publish allowlist')))

  const miscounted = buildSkillIndex(input([one], { manifest: { version: 1, skillCount: 7, skills: [one] } }))
  assert.ok(miscounted.problems.some((line) => line.includes('skillCount is 7')))
})

test('a manifest that contradicts its own references fails', () => {
  // The coverage lists are computed from specRefs; the card a reader sees is
  // drawn from skill.link. Until these were compared, a skill could advertise
  // a binding it did not have and every gate stayed green.
  const one = skill('trinity/wave')
  const lying = { ...one, link: 'bound', tags: ['lang/en', 'link/bound', 'src/trinity'] }
  const { problems, core } = buildSkillIndex(input([lying]))
  assert.ok(problems.some((line) => line.includes('calls this link "bound"') && line.includes('make it "unbound"')))
  assert.deepEqual(core.coverage.skillsUnbound, ['trinity/wave'], 'the index still believes the references, not the claim')
})

test('health has to follow the link, and an "ok" needs a binding and frontmatter', () => {
  const unbound = skill('trinity/wave')
  const tooHealthy = buildSkillIndex(input([{ ...unbound, health: 'ok' }]))
  assert.ok(tooHealthy.problems.some((line) => line.includes('health "ok" needs a bound link and frontmatter')))

  const bound = skill('t27/tri', { specRefs: [ref('specs/tools/registry.t27')] })
  const notFail = buildSkillIndex(input([{ ...bound, health: 'fail' }]))
  assert.ok(notFail.problems.some((line) => line.includes('only a broken link is a fail')))

  const noFrontmatter = buildSkillIndex(input([{ ...bound, hasFrontmatter: false }]))
  assert.ok(noFrontmatter.problems.some((line) => line.includes('health "ok" needs a bound link and frontmatter')))
})

test('a value outside the unions the page switches on fails', () => {
  const one = skill('trinity/wave')
  const cases = [
    [{ lang: 'klingon' }, 'lang "klingon"'],
    [{ health: 'excellent' }, 'health "excellent"'],
    [{ source: 'NOTES.txt', path: 'trinity/wave/NOTES.txt' }, 'source "NOTES.txt"'],
  ]
  for (const [over, expected] of cases) {
    const { problems } = buildSkillIndex(input([{ ...one, ...over }]))
    assert.ok(problems.some((line) => line.includes(expected)), `${expected} must be refused`)
  }
  const bodyClaim = skill('trinity/wave', { specRefs: [ref('specs/git/operations.t27', { via: 'body' })] })
  assert.ok(
    buildSkillIndex(input([bodyClaim])).problems.some((line) => line.includes('via body but declared=true')),
    'a passing mention must not be able to become a promise',
  )
})

test('identity and the printed size are held to the file they describe', () => {
  const one = skill('trinity/wave')
  const wrongId = buildSkillIndex(input([{ ...one, dir: 'ripple' }]))
  assert.ok(wrongId.problems.some((line) => line.includes('id is not "trinity/ripple"')))

  const wrongPath = buildSkillIndex(input([{ ...one, path: 'trinity/elsewhere/SKILL.md' }], { fileHashes: { 'trinity/elsewhere/SKILL.md': one.sha256 }, filesOnDisk: ['trinity/elsewhere/SKILL.md'] }))
  assert.ok(wrongPath.problems.some((line) => line.includes('is not "<repo>/<dir>/<source>"')))

  const facts = { [one.path]: { bytes: 4096, lines: 120 } }
  const drifted = buildSkillIndex(input([one], { fileFacts: facts }))
  assert.ok(drifted.problems.some((line) => line.includes('says 100 bytes, the file is 4096')))
  assert.ok(drifted.problems.some((line) => line.includes('says 10 lines, the file is 120')))

  const honest = buildSkillIndex(input([one], { fileFacts: { [one.path]: { bytes: 100, lines: 10 } } }))
  assert.deepEqual(honest.problems, [])
})

test('the headline counters are recomputed, not believed', () => {
  const skills = [skill('trinity/wave'), skill('t27/tri')]
  const clean = buildSkillIndex(input(skills))
  assert.deepEqual(clean.problems, [])

  for (const [field, key, value] of [['langs', 'ru', 9], ['bySource', 'SKILL.md', 1], ['tags', 'link/unbound', 7]]) {
    const base = input(skills)
    const cooked = buildSkillIndex({ ...base, manifest: { ...base.manifest, [field]: { ...base.manifest[field], [key]: value } } })
    assert.ok(cooked.problems.some((line) => line.includes(`manifest ${field}."${key}" says ${value}`)), `a bad ${field} count must fail`)
  }

  const ghost = input(skills)
  assert.ok(
    buildSkillIndex({ ...ghost, manifest: { ...ghost.manifest, featured: 'nobody/here' } }).problems.some((line) => line.includes('featured is "nobody/here"')),
    'the tab must not open on a skill that is not there',
  )
})
