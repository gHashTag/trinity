#!/usr/bin/env node
// Index the vendored skill catalog at prebuild, and refuse to ship a broken one.
//
// scripts/sync-skills.mjs runs by hand, on a laptop, against three working
// copies; this runs on every build, against the committed bytes alone. So the
// two ask different questions. The sync asks "what is out there?"; this asks
// "does what we committed still hold?" -- do the files hash to what the
// manifest claims, is every published skill still on the allowlist, and do the
// specs a skill declares still exist in the CURRENT corpus, which
// sync-t27-specs.mjs may have moved since.
//
//   node scripts/skills-core.mjs index
//
// A skill with no declared spec is not a failure. Most skills are prose about
// how to work and have no spec to point at; failing them would only teach
// people to write a binding they do not mean. What fails is a claim that no
// longer holds, and a link count that drifts past public/skills/link-baseline.json.

import { readFileSync, writeFileSync, renameSync, readdirSync, existsSync, statSync } from 'node:fs'
import { resolve, dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'
import ts from 'typescript'
// The same resolution rule the sync used, imported rather than restated: two
// copies of "does this path name a spec?" would drift, and the drift would show
// up as a link that is bound in the manifest and broken in the index.
import { resolveSpecRef, deriveLink } from './sync-skills.mjs'

const SITE = resolve(dirname(fileURLToPath(import.meta.url)), '..')
// Type-erase the page's own id rule from the same source the browser runs, the
// way spec-core.mjs erases sharedSpecCore.ts. A second validator here would be
// a second answer to "is this id safe", and one of them would be wrong.
const catalogSource = readFileSync(new URL('../src/lib/skillsCatalog.ts', import.meta.url), 'utf8')
const catalogJs = ts.transpileModule(catalogSource, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText
const { validSkillId } = await import(`data:text/javascript;base64,${Buffer.from(catalogJs).toString('base64')}`)

const hash = (bytes) => createHash('sha256').update(bytes).digest('hex')

function walk(dir, base = dir) {
  if (!existsSync(dir)) return []
  const out = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name)
    if (entry.isDirectory()) out.push(...walk(path, base))
    else if (statSync(path).isFile()) out.push(relative(base, path))
  }
  return out.sort()
}

// The unions src/lib/skillsLoader.ts declares. The page switches on these and
// has no branch for anything else, so a value outside them is not a cosmetic
// error -- it is a manifest the typed reader is lying about.
const LANGS = new Set(['ru', 'en', 'mixed'])
const HEALTHS = new Set(['ok', 'warn', 'fail'])
const SOURCES = new Set(['SKILL.md', 'skill.md', 'README.md'])
const VIAS = new Set(['frontmatter', 'site', 'body'])

/** Aggregate counters, recomputed rather than believed. */
function tally(items) {
  const counts = {}
  for (const item of items) counts[item] = (counts[item] ?? 0) + 1
  return counts
}

function disagrees(claimed, actual) {
  const keys = [...new Set([...Object.keys(claimed ?? {}), ...Object.keys(actual)])].sort()
  return keys.filter((key) => (claimed?.[key] ?? 0) !== (actual[key] ?? 0))
}

/**
 * Everything the index decides, as a function of what was read.
 *
 * Kept pure so scripts/skills-core.test.mjs can put a tampered hash, a vanished
 * spec or a drifting link count in front of it without staging a repository.
 *
 * `fileFacts` is optional and carries { bytes, lines } per vendored path, so
 * the two numbers the card prints can be held to the file they describe. The
 * SHA already pins the bytes, but the SHA is not what a reader sees.
 */
export function buildSkillIndex({ manifest, publish, specPaths, fileHashes, filesOnDisk, fileFacts = {}, baseline, provenance }) {
  const problems = []
  const allowed = new Set(Object.entries(publish).flatMap(([repo, dirs]) => dirs.map((dir) => `${repo}/${dir}`)))
  const manifestPaths = new Set(manifest.skills.map((skill) => skill.path))

  if (manifest.skillCount !== manifest.skills.length) {
    problems.push(`  manifest skillCount is ${manifest.skillCount} but it carries ${manifest.skills.length} skills`)
  }
  if (!manifest.skills.some((skill) => skill.id === manifest.featured)) {
    problems.push(`  manifest featured is "${manifest.featured}", which is not one of the published skills`)
  }
  for (const path of filesOnDisk) {
    if (!manifestPaths.has(path)) problems.push(`  public/skills/files/${path} has no manifest entry`)
  }

  const skillToSpecs = {}
  const bound = []
  const unbound = []
  const broken = []

  for (const skill of manifest.skills) {
    if (!validSkillId(skill.id)) problems.push(`  ${skill.id}: not a valid catalog id (<repo>/<dir>, no traversal, no URL syntax)`)
    if (!allowed.has(`${skill.repo}/${skill.dir}`)) problems.push(`  ${skill.id}: in the manifest but not on the publish allowlist`)

    // Identity, then the unions the page switches on.
    if (skill.id !== `${skill.repo}/${skill.dir}`) problems.push(`  ${skill.id}: id is not "${skill.repo}/${skill.dir}"`)
    if (!SOURCES.has(skill.source)) problems.push(`  ${skill.id}: source "${skill.source}" is not one of ${[...SOURCES].join(', ')}`)
    if (skill.path !== `${skill.repo}/${skill.dir}/${skill.source}`) problems.push(`  ${skill.id}: path "${skill.path}" is not "<repo>/<dir>/<source>"`)
    if (!LANGS.has(skill.lang)) problems.push(`  ${skill.id}: lang "${skill.lang}" is not one of ${[...LANGS].join(', ')}`)
    if (!HEALTHS.has(skill.health)) problems.push(`  ${skill.id}: health "${skill.health}" is not one of ${[...HEALTHS].join(', ')}`)

    const actual = fileHashes[skill.path]
    if (actual === undefined) problems.push(`  ${skill.id}: vendored file is missing -- public/skills/files/${skill.path}`)
    else if (actual !== skill.sha256) problems.push(`  ${skill.id}: SHA-256 mismatch -- the vendored file is not what the manifest describes`)

    const facts = fileFacts[skill.path]
    if (facts && skill.bytes !== facts.bytes) problems.push(`  ${skill.id}: the manifest says ${skill.bytes} bytes, the file is ${facts.bytes}`)
    if (facts && skill.lines !== facts.lines) problems.push(`  ${skill.id}: the manifest says ${skill.lines} lines, the file is ${facts.lines}`)

    // Re-resolution, against the corpus as it stands now rather than as it
    // stood when the skill was vendored.
    const refs = skill.specRefs.map((ref) => ({ ...ref, ...resolveSpecRef(ref.text, specPaths) }))
    const resolved = []
    for (const ref of refs) {
      if (!VIAS.has(ref.via)) problems.push(`  ${skill.id}: reference "${ref.text}" has via "${ref.via}", which is not one of ${[...VIAS].join(', ')}`)
      // A body mention is a candidate; only frontmatter and the site's own
      // bindings are claims. Flipping the flag would let a passing sentence
      // silently become a promise, or a real binding stop being checked.
      else if (ref.declared !== (ref.via !== 'body')) problems.push(`  ${skill.id}: reference "${ref.text}" is via ${ref.via} but declared=${ref.declared}`)
      if (!ref.declared) continue
      if (ref.status === 'resolved') { resolved.push(ref.to); continue }
      if (ref.status === 'ambiguous') {
        problems.push(`  ${skill.id}: declared spec "${ref.text}" (via ${ref.via}) matches ${ref.candidates.length} corpus paths`)
        problems.push(`      name one in full:  - ${ref.candidates[0]}`)
        continue
      }
      const base = ref.text.split('/').pop()
      const near = specPaths.filter((path) => path.split('/').pop() === base).sort()
      problems.push(`  ${skill.id}: declared spec "${ref.text}" (via ${ref.via}) is no longer in the corpus`)
      problems.push(`      frontmatter line to add:  - ${near.length === 1 ? near[0] : ref.text}`)
      if (near.length > 1) problems.push(`      or one of: ${near.slice(0, 5).join(', ')}`)
    }
    const link = deriveLink(refs)

    // The coverage lists below are computed from the references; the card the
    // reader sees is drawn from skill.link. Nothing else compares the two, so
    // without this a skill could advertise "bound" with no binding at all.
    if (skill.link !== link) problems.push(`  ${skill.id}: the manifest calls this link "${skill.link}", its references make it "${link}"`)
    if ((skill.health === 'fail') !== (link === 'broken')) problems.push(`  ${skill.id}: health "${skill.health}" and link "${link}" disagree -- only a broken link is a fail`)
    if (skill.health === 'ok' && (link !== 'bound' || !skill.hasFrontmatter)) problems.push(`  ${skill.id}: health "ok" needs a bound link and frontmatter`)
    for (const tag of [`src/${skill.repo}`, `lang/${skill.lang}`, `link/${skill.link}`]) {
      if (!skill.tags.includes(tag)) problems.push(`  ${skill.id}: tags are missing "${tag}", which the page filters on`)
    }

    if (link === 'broken') broken.push(skill.id)
    else if (link === 'bound') bound.push(skill.id)
    else unbound.push(skill.id)
    if (resolved.length) skillToSpecs[skill.id] = [...new Set(resolved)].sort()
  }

  // The headline numbers. They are the first thing anyone reads and the last
  // thing anyone recomputes, so they are recomputed here.
  for (const [field, actual] of [
    ['langs', { ru: 0, en: 0, mixed: 0, ...tally(manifest.skills.map((skill) => skill.lang)) }],
    ['bySource', tally(manifest.skills.map((skill) => skill.source))],
    ['tags', tally(manifest.skills.flatMap((skill) => skill.tags))],
  ]) {
    for (const key of disagrees(manifest[field], actual)) {
      problems.push(`  manifest ${field}."${key}" says ${manifest[field]?.[key] ?? 0}, the entries say ${actual[key] ?? 0}`)
    }
  }

  const specToSkills = {}
  for (const [id, paths] of Object.entries(skillToSpecs)) {
    for (const path of paths) (specToSkills[path] ??= []).push(id)
  }
  for (const path of Object.keys(specToSkills)) specToSkills[path].sort()

  const specsWithSkill = Object.keys(specToSkills).sort()
  const baselineUnbound = baseline ?? unbound.length
  if (unbound.length > baselineUnbound) {
    problems.push(`  ${unbound.length} skills declare no spec, over the baseline of ${baselineUnbound}`)
    problems.push(`      bind one, or raise public/skills/link-baseline.json deliberately`)
  }

  const core = {
    version: 1,
    provenance,
    skillCount: manifest.skills.length,
    coverage: {
      skillsBound: bound.sort(),
      skillsUnbound: unbound.sort(),
      skillsBroken: broken.sort(),
      specsWithSkill,
      specsWithoutSkill: specPaths.length - specsWithSkill.length,
      baselineUnbound,
    },
    skillToSpecs: Object.fromEntries(Object.entries(skillToSpecs).sort((a, b) => a[0].localeCompare(b[0]))),
    specToSkills: Object.fromEntries(Object.entries(specToSkills).sort((a, b) => a[0].localeCompare(b[0]))),
  }
  return { core, problems }
}

function index() {
  const manifestBytes = readFileSync(resolve(SITE, 'public/skills/manifest.json'))
  const specBytes = readFileSync(resolve(SITE, 'public/t27/manifest.json'))
  const manifest = JSON.parse(manifestBytes)
  const specPaths = JSON.parse(specBytes).specs.map((spec) => spec.path)
  const publish = JSON.parse(readFileSync(resolve(SITE, 'public/skills/publish.json')))

  const filesRoot = resolve(SITE, 'public/skills/files')
  const filesOnDisk = walk(filesRoot)
  const fileHashes = {}
  const fileFacts = {}
  for (const path of filesOnDisk) {
    const bytes = readFileSync(join(filesRoot, path))
    fileHashes[path] = hash(bytes)
    fileFacts[path] = { bytes: bytes.length, lines: bytes.toString('utf8').split('\n').length }
  }

  const baselinePath = resolve(SITE, 'public/skills/link-baseline.json')
  const baseline = existsSync(baselinePath) ? JSON.parse(readFileSync(baselinePath)).unbound : null

  const { core, problems } = buildSkillIndex({
    manifest,
    publish,
    specPaths,
    fileHashes,
    filesOnDisk,
    fileFacts,
    baseline,
    provenance: {
      manifestSha256: hash(manifestBytes),
      specManifestSha256: hash(specBytes),
      indexerSha256: hash(readFileSync(fileURLToPath(import.meta.url))),
    },
  })

  if (problems.length) {
    console.error('skills-core: the committed catalog does not hold')
    for (const line of problems) console.error(line)
    process.exit(1)
  }

  const dest = resolve(SITE, 'public/skills/skills-core.json')
  const temp = `${dest}.${process.pid}.tmp`
  writeFileSync(temp, `${JSON.stringify(core)}\n`, { flag: 'wx' })
  renameSync(temp, dest)

  const { coverage } = core
  if (baseline === null) console.log(`  note: no link-baseline.json; write { "unbound": ${coverage.skillsUnbound.length} } to hold the line`)
  console.log(`skills-core: ${core.skillCount} skills · ${coverage.skillsBound.length} bound · ${coverage.skillsUnbound.length} unbound (baseline ${coverage.baselineUnbound}) · ${coverage.skillsBroken.length} broken · ${coverage.specsWithSkill.length} of ${coverage.specsWithSkill.length + coverage.specsWithoutSkill} specs have a skill`)
}

const command = process.argv[2] ?? 'help'
try {
  if (command === 'index') index()
  else if (command === 'help') {
    process.stdout.write([
      'Skill catalog index (verification, not discovery)',
      '  node scripts/skills-core.mjs index   check the committed catalog and write public/skills/skills-core.json',
      '  node scripts/skills-core.mjs help',
      'Reads only committed bytes. No network, no repositories, no writes outside public/skills/skills-core.json.',
      'An unbound skill passes; a declared spec that no longer resolves does not.',
      '',
    ].join('\n'))
  } else throw new Error('Unknown command; use help')
} catch (error) {
  console.error(`skills-core: ${error.message}`)
  process.exitCode = 1
}
