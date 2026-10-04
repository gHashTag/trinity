#!/usr/bin/env node
// After rendering the final PNGs in the apex static repo:
//   node scripts/update-blog-cover-versions.mjs /path/to/static
//   node scripts/update-blog-cover-versions.mjs /path/to/static --check
// Hash the served EN/RU PNG bytes, not a remembered slug list or arbitrary date.
import { createHash } from 'node:crypto'
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { buildSync } from 'esbuild'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const OUTPUT = join(ROOT, 'src/data/blog/coverVersions.ts')

export function loadPublishedPosts(source = join(ROOT, 'src/data/blog/index.ts')) {
  const result = buildSync({ entryPoints: [source], bundle: true, platform: 'node',
    format: 'cjs', write: false, logLevel: 'error' })
  const module = { exports: {} }
  new Function('module', 'exports', 'require', result.outputFiles[0].text)(
    module, module.exports, createRequire(source))
  return module.exports.publishedPosts()
}

export function collectVersions(staticRoot, posts) {
  if (!Array.isArray(posts) || !posts.length) throw new Error('no published posts')
  const versions = {}
  for (const { slug } of posts) {
    if (typeof slug !== 'string' || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug)) {
      throw new Error(`invalid slug: ${slug}`)
    }
    if (Object.hasOwn(versions, slug)) throw new Error(`duplicate slug: ${slug}`)
    if (!existsSync(join(staticRoot, 'og-art', `${slug}.jpg`))) {
      throw new Error(`missing triptych: og-art/${slug}.jpg`)
    }
    versions[slug] = {}
    for (const lang of ['en', 'ru']) {
      const name = `og-blog-${slug}${lang === 'ru' ? '-ru' : ''}.png`
      const file = join(staticRoot, name)
      if (!existsSync(file)) throw new Error(`missing PNG: ${name}`)
      const bytes = readFileSync(file)
      if (bytes.length < 24 || bytes.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a'
          || bytes.subarray(12, 16).toString() !== 'IHDR'
          || bytes.readUInt32BE(16) !== 1200 || bytes.readUInt32BE(20) !== 630) {
        throw new Error(`${name}: expected a 1200 x 630 PNG`)
      }
      versions[slug][lang] = createHash('sha256').update(bytes).digest('hex').slice(0, 12)
    }
  }
  return versions
}

export function loadCaptions(staticRoot) {
  const path = join(staticRoot, 'og-art/captions.json')
  if (!existsSync(path)) return {}
  const captions = JSON.parse(readFileSync(path, 'utf8'))
  if (!captions || Array.isArray(captions) || typeof captions !== 'object') {
    throw new Error('captions.json must map slugs to locale entries')
  }
  for (const [slug, entry] of Object.entries(captions)) {
    if (!entry || Array.isArray(entry) || typeof entry !== 'object') {
      throw new Error(`captions for ${slug} must map locales to panels`)
    }
    for (const [lang, panels] of Object.entries(entry)) {
      if (!['en', 'ru'].includes(lang) || !Array.isArray(panels) || panels.length !== 3) {
        throw new Error(`captions for ${slug}/${lang} need exactly three panels in en or ru`)
      }
      if (panels.some(p => !p || ['heading', 'caption'].some(k => typeof p[k] !== 'string' || !p[k].trim()))) {
        throw new Error(`captions for ${slug}/${lang} need nonempty headings and captions`)
      }
    }
  }
  return captions
}

export function renderVersions(versions, captions = {}) {
  const sorted = Object.fromEntries(Object.entries(versions).sort(([a], [b]) => a.localeCompare(b)))
  const selectedCaptions = Object.fromEntries(Object.keys(sorted)
    .filter(slug => captions[slug]).map(slug => [slug, captions[slug]]))
  return '// Generated from final apex PNG bytes by scripts/update-blog-cover-versions.mjs.\n'
    + '// Captions come from the same static repo og-art/captions.json.\n'
    + '// Regenerate after changing artwork or captions; do not edit by hand.\n'
    + 'export const BLOG_COVER_VERSIONS: Record<string, { en: string; ru: string }> = '
    + JSON.stringify(sorted, null, 2) + '\n'
    + '\nexport type BlogCoverPanel = { heading: string; caption: string }\n'
    + 'export const BLOG_COVER_CAPTIONS: Record<string, Partial<Record<\'en\' | \'ru\', BlogCoverPanel[]>>> = '
    + JSON.stringify(selectedCaptions, null, 2) + '\n'
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = process.argv.slice(2)
    if (args.length < 1 || args.length > 2 || args[0].startsWith('--')
        || (args[1] && args[1] !== '--check')) {
      throw new Error('usage: node scripts/update-blog-cover-versions.mjs STATIC_REPO [--check]')
    }
    const versions = collectVersions(resolve(args[0]), loadPublishedPosts())
    const output = renderVersions(versions, loadCaptions(resolve(args[0])))
    if (args.includes('--check')) {
      if (!existsSync(OUTPUT) || readFileSync(OUTPUT, 'utf8') !== output) {
        throw new Error('coverVersions.ts is stale; run this command without --check before rebuilding')
      }
      console.log(`Cover versions match ${Object.keys(versions).length} published triptychs (EN/RU).`)
    } else {
      writeFileSync(OUTPUT, output)
      console.log(`Updated coverVersions.ts from ${Object.keys(versions).length} final triptychs (EN/RU).`)
    }
  } catch (error) {
    console.error(`blog-cover-versions: ${error.message}`)
    process.exitCode = 1
  }
}
