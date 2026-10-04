#!/usr/bin/env node
// Vendor the `.claude/skills` prose of three repositories into public/skills/.
//
// The Skill Explorer is the prose sibling of the spec Explorer: where
// sync-t27-specs.mjs vendors 760 .t27 sources and compiles them, this vendors
// the Markdown that tells an agent how to work, and links each skill back to
// the specs it claims to be about. Same trade as there -- a copy in public/
// means the page works offline and deterministically, and the cost is drift,
// so the manifest records the exact commit of every repository it read.
//
// Run it by hand, locally. It never touches the network:
//
//   node scripts/sync-skills.mjs --propose   # rebuild the publish allowlist
//   node scripts/sync-skills.mjs             # vendor what the allowlist names
//
// Two of the three repositories are private and none of the three was written
// for publication, so nothing ships on the strength of "it looked fine". Every
// skill is scanned and reported; only the ones named in public/skills/publish.json
// are copied out; and a published body that matches a credential shape stops
// the run outright.

import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync, readdirSync, statSync, realpathSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'

const HERE = dirname(fileURLToPath(import.meta.url))
const WEBSITE = join(HERE, '..')

// `trinity` is the website's own superproject, so it is found by walking up
// rather than by hardcoding a path that only exists on one machine.
const ROOTS = [
  { repo: '999-multibots-telegraf', root: process.env.BOT_ROOT || '/Users/playom/999-multibots-telegraf', private: true },
  { repo: 't27', root: process.env.T27_ROOT || '/Users/playom/t27', private: false },
  { repo: 'trinity', root: process.env.TRINITY_ROOT || resolve(WEBSITE, '../..'), private: false },
]

const OUT_DIR = join(WEBSITE, 'public/skills')
const FILES_OUT = join(OUT_DIR, 'files')
const BINDINGS_PATH = join(OUT_DIR, 'bindings.json')
const PUBLISH_PATH = join(OUT_DIR, 'publish.json')
const MANIFEST_PATH = join(OUT_DIR, 'manifest.json')
const SPEC_MANIFEST_PATH = join(WEBSITE, 'public/t27/manifest.json')
const EXC_PATH = join(WEBSITE, 'qa/language-exceptions.json')

// The one skill that explains how this repository decides a test is real. It
// opens the tab when it is published; otherwise the first entry does.
const FEATURED = '999-multibots-telegraf/blind-guards'

const MAIN_FILES = ['SKILL.md', 'skill.md', 'README.md']

// ---------------------------------------------------------------------------
// Review and refusal
//
// Two different jobs, deliberately not merged.
//
// REVIEW_PATTERNS are not secrets. They are the shapes that a private
// operations note tends to carry -- a host address, an ssh recipe, the name of
// the secret manager, a chat deep link, a nine-digit account id, the absolute
// path of somebody's home directory. None of them is dangerous on its own and
// all of them are uninteresting to a reader of the public site, so a skill
// that trips any of them stays off the allowlist until a human says otherwise.
// `--propose` writes the allowlist from exactly the skills that trip none.
//
// SECRET_PATTERNS are credentials. A match in something about to be published
// is not a judgement call, so it stops the run. The message names the file and
// nothing else: printing the match would copy the credential into a terminal
// scrollback, a CI log and this script's own output, which is the failure it
// exists to prevent.
// ---------------------------------------------------------------------------
export const REVIEW_PATTERNS = [
  ['ipv4', /\b\d{1,3}(\.\d{1,3}){3}\b/g],
  ['ssh', /\bssh\b/gi],
  ['railway-host', /railway\.(app|internal)/gi],
  ['infisical', /infisical/gi],
  ['long-id', /\b\d{9,10}\b/g],
  ['t-me', /t\.me\//gi],
  ['bearer', /Bearer /g],
  ['token-param', /token=/g],
  // `/Users/<someone>/...` names the account a laptop belongs to, and it is
  // the one shape here that a reader of the public site can neither use nor
  // ignore: the command it appears in cannot work on any other machine.
  ['home-path', /\/(Users|home)\/[A-Za-z0-9_.-]+/g],
]

export const SECRET_PATTERNS = [
  ['api-key', /sk-[A-Za-z0-9]{20,}/],
  ['github-token', /ghp_[A-Za-z0-9]{20,}/],
  ['github-fine-grained-token', /github_pat_/],
  ['json-web-token', /eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}/],
  ['aws-access-key', /AKIA[0-9A-Z]{16}/],
  ['slack-token', /xox[baprs]-/],
  ['private-key-block', /-----BEGIN [A-Z ]*PRIVATE KEY/],
  ['telegram-bot-token', /\b\d{8,10}:[A-Za-z0-9_-]{35}\b/],
  ['url-credentials', /(postgres|postgresql|mysql|redis|mongodb):\/\/[^\s:]+:[^\s@]+@/],
]

// ---------------------------------------------------------------------------
// Pure readers
//
// Everything below this line is a function of its arguments, so
// scripts/sync-skills.test.mjs can hold each one to a case without a
// filesystem, a repository or a network.
// ---------------------------------------------------------------------------

function unquote(value) {
  const text = value.trim()
  const quoted = text.length >= 2 && ((text[0] === '"' && text.endsWith('"')) || (text[0] === "'" && text.endsWith("'")))
  return quoted ? text.slice(1, -1) : text
}

/**
 * The opening `---` block, read the way a skill actually writes one.
 *
 * Not YAML: skills use a flat `key: value` header plus, where the author
 * bothered, a `specs:` list of the .t27 files the skill is about. Parsing the
 * subset that exists keeps a dependency out of the tree and keeps the failure
 * mode legible -- an unrecognised line is skipped, never guessed at.
 *
 * An opening `---` with no closing `---` is not a header, it is a horizontal
 * rule at the top of a document, and is reported as no frontmatter at all.
 */
export function parseFrontmatter(text) {
  const none = { hasFrontmatter: false, frontmatter: {}, specs: [], bodyStart: 0 }
  const lines = text.split('\n')
  if (lines[0]?.trim() !== '---') return none
  const frontmatter = {}
  const specs = []
  let list = null
  for (let i = 1; i < lines.length; i++) {
    const line = lines[i]
    if (line.trim() === '---') return { hasFrontmatter: true, frontmatter, specs, bodyStart: i + 1 }
    const item = line.match(/^\s*-\s+(.*\S)\s*$/)
    if (item) {
      if (list === 'specs') specs.push({ text: unquote(item[1]), line: i + 1 })
      continue
    }
    const pair = line.match(/^([A-Za-z0-9_.-]+):[ \t]*(.*)$/)
    if (!pair) continue
    const value = pair[2].trim()
    // A key with nothing after the colon opens a list; only `specs:` is read.
    if (value === '') { list = pair[1]; continue }
    list = null
    frontmatter[pair[1]] = unquote(value)
  }
  return none
}

/**
 * Headings, fenced code and the opening paragraph, in one pass.
 *
 * The pass tracks fences because a shell block full of `# comment` lines would
 * otherwise contribute a dozen phantom level-1 headings, and the first of them
 * would become the skill's name.
 */
export function scanBody(text, bodyStart = 0) {
  const lines = text.split('\n')
  const headings = []
  const codeBlocks = []
  const paragraph = []
  let fence = null
  let fenceLang = ''
  let fenceLines = 0
  let paragraphDone = false
  for (let i = bodyStart; i < lines.length; i++) {
    const line = lines[i].trim()
    const fenceMark = line.match(/^(`{3,}|~{3,})(.*)$/)
    if (fence) {
      if (fenceMark && fenceMark[1][0] === fence[0] && fenceMark[1].length >= fence.length && !fenceMark[2].trim()) {
        codeBlocks.push({ lang: fenceLang, lines: fenceLines })
        fence = null
      } else fenceLines++
      continue
    }
    if (fenceMark) {
      fence = fenceMark[1]
      fenceLang = fenceMark[2].trim().split(/\s+/)[0] || ''
      fenceLines = 0
      if (paragraph.length) paragraphDone = true
      continue
    }
    const heading = line.match(/^(#{1,6})\s+(.*\S)\s*$/)
    if (heading) {
      headings.push({ level: heading[1].length, text: heading[2].trim(), line: i + 1 })
      if (paragraph.length) paragraphDone = true
      continue
    }
    if (!line) {
      if (paragraph.length) paragraphDone = true
      continue
    }
    if (!paragraphDone) paragraph.push(line)
  }
  // An unterminated fence still says how much code the skill carries.
  if (fence) codeBlocks.push({ lang: fenceLang, lines: fenceLines })
  return { headings, codeBlocks, firstParagraph: paragraph.join(' ').replace(/\s+/g, ' ').trim() }
}

/**
 * Which language the prose is in, by counting letters rather than guessing.
 *
 * These skills are written in Russian, in English, and often in both at once
 * -- an English command list under a Russian explanation. `mixed` is a real
 * answer here, not a failure to decide.
 */
export function detectLang(text) {
  const letters = text.match(/\p{L}/gu)?.length ?? 0
  if (!letters) return 'en'
  const cyrillic = text.match(/\p{Script=Cyrillic}/gu)?.length ?? 0
  const ratio = cyrillic / letters
  return ratio > 0.6 ? 'ru' : ratio < 0.1 ? 'en' : 'mixed'
}

export function extractLinks(text) {
  const links = []
  for (const raw of text.match(/https?:\/\/[^\s)<>"'`\]]+/g) ?? []) {
    const url = raw.replace(/[.,;:!?]+$/, '')
    if (!links.includes(url)) links.push(url)
  }
  const hosts = []
  for (const url of links) {
    try {
      const { hostname } = new URL(url)
      if (hostname && !hosts.includes(hostname)) hosts.push(hostname)
    } catch {
      // Not a URL the platform can name; the link text still ships.
    }
  }
  return { links, hosts: hosts.sort() }
}

export function extractDates(text) {
  const found = text.match(/\b\d{4}-\d{2}-\d{2}\b/g) ?? []
  const dates = found.filter((d) => {
    const [, month, day] = d.split('-').map(Number)
    return month >= 1 && month <= 12 && day >= 1 && day <= 31
  })
  return [...new Set(dates)].sort()
}

/** Every `.t27` token in the prose, first occurrence wins the line number. */
export function extractBodyRefs(text) {
  const refs = []
  const seen = new Set()
  const lines = text.split('\n')
  for (let i = 0; i < lines.length; i++) {
    for (const match of lines[i].matchAll(/[A-Za-z0-9_./-]+\.t27/g)) {
      if (seen.has(match[0])) continue
      seen.add(match[0])
      refs.push({ text: match[0], line: i + 1 })
    }
  }
  return refs
}

/**
 * A written reference against the vendored spec corpus.
 *
 * Skills name specs the way people talk about them -- `registry.t27`, not
 * `compiler/skill/registry.t27` -- so a bare tail is accepted when exactly one
 * corpus path ends in it. Two matches is `ambiguous`, not a coin toss: the
 * catalog would otherwise link a reader to whichever of two real files sorted
 * first, and be confidently wrong.
 */
export function resolveSpecRef(text, specPaths) {
  if (specPaths.includes(text)) return { to: text, candidates: [text], status: 'resolved' }
  const candidates = specPaths.filter((path) => path.endsWith(`/${text}`)).sort()
  if (candidates.length === 1) return { to: candidates[0], candidates, status: 'resolved' }
  if (candidates.length > 1) return { to: null, candidates, status: 'ambiguous' }
  return { to: null, candidates: [], status: 'missing' }
}

/** The name of the first credential shape the text matches, or null. */
export function findSecret(text) {
  for (const [name, pattern] of SECRET_PATTERNS) if (pattern.test(text)) return name
  return null
}

export function reviewHits(text) {
  const hits = []
  for (const [pattern, expression] of REVIEW_PATTERNS) {
    const count = (text.match(expression) ?? []).length
    if (count) hits.push({ pattern, count })
  }
  return hits
}

/**
 * Declared references decide the link; body mentions never do.
 *
 * A skill that merely says the word `parser.t27` in a sentence has not claimed
 * anything, so it cannot be broken by that sentence. Only what the author (or
 * the site's bindings file) declared is held to resolve.
 */
export function deriveLink(specRefs) {
  const declared = specRefs.filter((ref) => ref.declared)
  if (declared.some((ref) => ref.status !== 'resolved')) return 'broken'
  return declared.length ? 'bound' : 'unbound'
}

export function deriveHealth(link, { hasFrontmatter, duplicateFile }) {
  if (link === 'broken') return 'fail'
  if (link === 'unbound' || !hasFrontmatter || duplicateFile) return 'warn'
  return 'ok'
}

export function deriveTags(entry) {
  const tags = new Set([`src/${entry.repo}`, `lang/${entry.lang}`, `link/${entry.link}`])
  if (entry.hasFrontmatter) tags.add('has/frontmatter')
  else tags.add('issue/no-frontmatter')
  if (entry.liveShell) tags.add('has/live-shell')
  if (entry.extras.length) tags.add('has/extras')
  if (entry.codeBlocks.length) tags.add('has/code')
  tags.add(entry.bytes < 2048 ? 'size/tiny' : entry.bytes < 8192 ? 'size/small' : entry.bytes < 32768 ? 'size/medium' : 'size/large')
  if (entry.duplicateFile) tags.add('issue/duplicate-file')
  // A `.t27` named in the prose that no longer exists: not a broken promise,
  // but the likeliest place a rename left the documentation behind.
  if (entry.specRefs.some((ref) => !ref.declared && ref.status === 'missing')) tags.add('issue/dangling-candidate')
  return [...tags].sort()
}

export function clampDescription(text) {
  const clean = (text ?? '').replace(/\s+/g, ' ').trim()
  return clean.length > 240 ? `${clean.slice(0, 237).trimEnd()}...` : clean
}

/**
 * The main file of a skill directory, by exact name.
 *
 * macOS is case-insensitive, so `existsSync('SKILL.md')` answers true for a
 * directory that only holds `skill.md` -- which would silently mislabel every
 * lowercase skill and hide the real duplicate case. The name is matched
 * against the directory listing instead.
 */
export function pickMain(names) {
  const present = MAIN_FILES.filter((name) => names.includes(name))
  return {
    source: present[0] ?? null,
    duplicateFile: names.includes('SKILL.md') && names.includes('skill.md'),
  }
}

// ---------------------------------------------------------------------------
// The run
// ---------------------------------------------------------------------------

function fail(message) {
  console.error(`sync-skills: ${message}`)
  process.exit(1)
}

function listSkillDirs(root) {
  const base = join(root, '.claude/skills')
  if (!existsSync(base)) return []
  return readdirSync(base, { withFileTypes: true })
    .filter((entry) => entry.name !== '_shared' && (entry.isDirectory() || (entry.isSymbolicLink() && statSync(join(base, entry.name), { throwIfNoEntry: false })?.isDirectory())))
    .map((entry) => entry.name)
    .sort()
}

function repoFacts(root) {
  const git = (args) => execFileSync('git', ['-C', root, ...args], { encoding: 'utf8' }).trim()
  const commit = git(['rev-parse', 'HEAD'])
  return {
    commit,
    shortCommit: commit.slice(0, 9),
    branch: git(['rev-parse', '--abbrev-ref', 'HEAD']),
    dirty: git(['status', '--porcelain', '--', '.claude/skills']).length > 0,
  }
}

function collect(specPaths) {
  const found = []
  const generatedFrom = []
  for (const source of ROOTS) {
    if (!existsSync(source.root)) fail(`repository not found at ${source.root} (set BOT_ROOT / T27_ROOT / TRINITY_ROOT)`)
    let facts
    try {
      facts = repoFacts(source.root)
    } catch (error) {
      fail(`could not read git facts for ${source.repo}: ${error.message}`)
    }
    generatedFrom.push({ repo: `gHashTag/${source.repo}`, ...facts, private: source.private })

    const base = join(source.root, '.claude/skills')
    for (const dir of listSkillDirs(source.root)) {
      const names = readdirSync(join(base, dir)).sort()
      const { source: main, duplicateFile } = pickMain(names)
      if (!main) {
        console.log(`  note: ${source.repo}/${dir} has no SKILL.md, skill.md or README.md -- skipped`)
        continue
      }
      const bytes = readFileSync(join(base, dir, main))
      const text = bytes.toString('utf8')
      found.push({
        repo: source.repo,
        dir,
        id: `${source.repo}/${dir}`,
        source: main,
        path: `${source.repo}/${dir}/${main}`,
        duplicateFile,
        extras: names.filter((name) => name !== main),
        siblingJson: names.includes('skill.json') ? join(base, dir, 'skill.json') : null,
        bytes,
        text,
        hits: reviewHits(text),
      })
    }
  }
  found.sort((a, b) => a.repo.localeCompare(b.repo) || a.dir.localeCompare(b.dir))
  return { found, generatedFrom, specPaths }
}

function buildEntry(raw, bindings, specPaths) {
  const { hasFrontmatter, frontmatter, specs, bodyStart } = parseFrontmatter(raw.text)
  const { headings, codeBlocks, firstParagraph } = scanBody(raw.text, bodyStart)

  let sidecar = {}
  if (raw.siblingJson) {
    try {
      sidecar = JSON.parse(readFileSync(raw.siblingJson, 'utf8'))
    } catch {
      // A malformed sidecar is not worth failing a sync over; it is a fallback.
    }
  }

  const name = frontmatter.name || sidecar.name || headings[0]?.text || raw.dir
  const description = clampDescription(frontmatter.description || sidecar.description || firstParagraph)
  const { links, hosts } = extractLinks(raw.text)

  // Three origins, one shape. `declared` is the whole difference: the site's
  // bindings and the skill's own frontmatter are claims that must hold, a
  // token in the prose is only a candidate.
  const seen = new Set()
  const specRefs = []
  const add = (text, line, via, declared) => {
    const key = `${text} ${via}`
    if (seen.has(key)) return
    seen.add(key)
    specRefs.push({ text, line, declared, via, ...resolveSpecRef(text, specPaths) })
  }
  for (const spec of specs) add(spec.text, spec.line, 'frontmatter', true)
  for (const path of bindings[raw.id] ?? []) add(path, 0, 'site', true)
  for (const ref of extractBodyRefs(raw.text)) add(ref.text, ref.line, 'body', false)

  const link = deriveLink(specRefs)
  const entry = {
    id: raw.id,
    repo: raw.repo,
    dir: raw.dir,
    path: raw.path,
    source: raw.source,
    name,
    description,
    frontmatter,
    hasFrontmatter,
    lang: detectLang(raw.text),
    bytes: raw.bytes.length,
    lines: raw.text.split('\n').length,
    sha256: createHash('sha256').update(raw.bytes).digest('hex'),
    headings,
    codeBlocks,
    links,
    hosts,
    dates: extractDates(raw.text),
    extras: raw.extras,
    // `!` immediately before a backtick is the live-shell prefix: the skill is
    // asking an agent to run a command, not to read one.
    liveShell: raw.text.includes('!`'),
    specsDeclared: specs.map((spec) => spec.text),
    specRefs,
    tags: [],
    link,
    health: deriveHealth(link, { hasFrontmatter, duplicateFile: raw.duplicateFile }),
  }
  entry.tags = deriveTags({ ...entry, duplicateFile: raw.duplicateFile })
  return entry
}

function main() {
  const propose = process.argv.includes('--propose')

  if (!existsSync(SPEC_MANIFEST_PATH)) fail('public/t27/manifest.json is missing -- run scripts/sync-t27-specs.mjs first')
  const specManifest = JSON.parse(readFileSync(SPEC_MANIFEST_PATH, 'utf8'))
  const specPaths = specManifest.specs.map((spec) => spec.path)
  const specPathSet = new Set(specPaths)

  if (!existsSync(BINDINGS_PATH)) fail('public/skills/bindings.json is missing')
  const bindings = JSON.parse(readFileSync(BINDINGS_PATH, 'utf8'))

  const { found, generatedFrom } = collect(specPaths)
  if (!found.length) fail('no skills found under any .claude/skills')

  // The allowlist. `--propose` rebuilds it from exactly the skills that trip no
  // review pattern; without the flag it is read as written, so a human decision
  // to publish something noisier survives the next sync.
  if (propose) {
    const proposal = {}
    for (const { repo } of ROOTS) proposal[repo] = []
    for (const skill of found) if (!skill.hits.length) proposal[skill.repo].push(skill.dir)
    for (const repo of Object.keys(proposal)) proposal[repo].sort()
    mkdirSync(OUT_DIR, { recursive: true })
    writeFileSync(PUBLISH_PATH, `${JSON.stringify(proposal, null, 2)}\n`)
    console.log(`  proposed publish.json: ${Object.values(proposal).reduce((n, list) => n + list.length, 0)} skills with zero review hits`)
  }
  if (!existsSync(PUBLISH_PATH)) fail('public/skills/publish.json is missing -- run with --propose to write one')
  const publish = JSON.parse(readFileSync(PUBLISH_PATH, 'utf8'))
  const allowed = new Set(Object.entries(publish).flatMap(([repo, dirs]) => dirs.map((dir) => `${repo}/${dir}`)))

  // The review report, every skill, published or not. A withheld skill is not a
  // secret -- what it is has to stay visible or the allowlist becomes folklore.
  console.log('review:')
  for (const skill of found) {
    const detail = skill.hits.map((hit) => `${hit.pattern}:${hit.count}`).join(' ')
    const total = skill.hits.reduce((sum, hit) => sum + hit.count, 0)
    console.log(`  ${skill.id} hits=${total} [${detail}] ${allowed.has(skill.id) ? 'published' : 'withheld'}`)
  }

  const published = found.filter((skill) => allowed.has(skill.id))
  if (!published.length) fail('the publish allowlist names no skill that exists')
  for (const id of allowed) if (!found.some((skill) => skill.id === id)) console.log(`  note: publish.json names ${id}, which no repository has`)

  // Refusal, before a single byte is copied.
  for (const skill of published) if (findSecret(skill.text)) fail(`refusing to publish ${skill.path} -- it carries a credential shape (the match is not printed)`)

  for (const [id, paths] of Object.entries(bindings)) {
    for (const path of paths) if (!specPathSet.has(path)) fail(`bindings.json points ${id} at ${path}, which is not in the spec corpus`)
    if (!allowed.has(id)) console.log(`  note: binding for ${id} ignored -- the skill is not on the publish allowlist`)
  }

  const entries = published.map((raw) => buildEntry(raw, bindings, specPaths))

  rmSync(FILES_OUT, { recursive: true, force: true })
  mkdirSync(FILES_OUT, { recursive: true })
  for (let i = 0; i < entries.length; i++) {
    const dest = join(FILES_OUT, entries[i].path)
    mkdirSync(dirname(dest), { recursive: true })
    writeFileSync(dest, published[i].bytes)
  }

  const bySource = {}
  for (const name of MAIN_FILES) {
    const count = entries.filter((entry) => entry.source === name).length
    if (count) bySource[name] = count
  }
  const langs = { ru: 0, en: 0, mixed: 0 }
  for (const entry of entries) langs[entry.lang]++
  const tagCounts = {}
  for (const entry of entries) for (const tag of entry.tags) tagCounts[tag] = (tagCounts[tag] ?? 0) + 1

  const manifest = {
    version: 1,
    generatedAt: new Date().toISOString(),
    generatedFrom,
    specManifestCommit: specManifest.generatedFrom.shortCommit,
    skillCount: entries.length,
    withheld: found.length - entries.length,
    bySource,
    langs,
    tags: Object.fromEntries(Object.entries(tagCounts).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))),
    /*
     * The page opens on the featured skill, so it should be one that SHOWS the
     * thing the page is about. If the preferred skill is not published, fall to
     * the first skill that actually stands on a spec, and only then to the
     * first of all -- landing a first-time reader on an unbound skill would
     * demonstrate the absence of the link this tab exists to draw.
     */
    featured:
      entries.find((entry) => entry.id === FEATURED)?.id ??
      entries.find((entry) => entry.link === 'bound')?.id ??
      entries[0].id,
    skills: entries,
  }
  // Indented, unlike the spec manifest: this one is 43 entries rather than 760,
  // and a reviewer reading the diff of what became public is the point.
  writeFileSync(MANIFEST_PATH, `${JSON.stringify(manifest, null, 2)}\n`)

  // ---------------------------------------------------------------------------
  // Language-audit exceptions
  //
  // `qa/ru_audit.mjs` fails the build on any English sentence over 45 characters
  // rendered under ?lang=ru, and it should stay that strict: it is there to
  // catch untranslated UI. A skill description is not UI -- it is quoted out of
  // a source file in whatever language its author wrote. Same treatment the
  // spec descriptions already get, generated rather than hand-kept.
  // ---------------------------------------------------------------------------
  if (existsSync(EXC_PATH)) {
    const exc = JSON.parse(readFileSync(EXC_PATH, 'utf8'))
    exc.ru = exc.ru || {}
    exc.ru.skills = [...new Set(entries.map((entry) => entry.description).filter(Boolean))].filter((d) => d.length > 45).sort()
    writeFileSync(EXC_PATH, `${JSON.stringify(exc, null, 2)}\n`)
    console.log(`  qa exceptions: ${exc.ru.skills.length} skill descriptions registered for the RU audit`)
  }

  const links = { bound: 0, unbound: 0, broken: 0 }
  for (const entry of entries) links[entry.link]++
  const health = { ok: 0, warn: 0, fail: 0 }
  for (const entry of entries) health[entry.health]++
  const byRepo = ROOTS.map(({ repo }) => `${repo} ${entries.filter((e) => e.repo === repo).length}/${found.filter((e) => e.repo === repo).length}`)

  console.log(`sync-skills: ${entries.length} published, ${manifest.withheld} withheld`)
  console.log(`  published/found: ${byRepo.join(' · ')}`)
  console.log(`  link: ${links.bound} bound · ${links.unbound} unbound · ${links.broken} broken`)
  console.log(`  health: ${health.ok} ok · ${health.warn} warn · ${health.fail} fail`)
  for (const from of generatedFrom) console.log(`  ${from.repo} @ ${from.shortCommit} (${from.branch})${from.dirty ? ' DIRTY' : ''}${from.private ? ' private' : ''}`)
  console.log(`  specs @ ${manifest.specManifestCommit}, featured ${manifest.featured}`)
}

// Importing this file gets the readers above and runs nothing, so the test
// suite can hold them to a case without a repository under them.
function invokedDirectly() {
  try {
    return Boolean(process.argv[1]) && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url))
  } catch {
    return false
  }
}

if (invokedDirectly()) main()
