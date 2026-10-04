import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test, { afterEach } from 'node:test'
import { collectVersions, loadCaptions, loadPublishedPosts, renderVersions } from './update-blog-cover-versions.mjs'

const scratch = []
afterEach(() => { for (const path of scratch.splice(0)) rmSync(path, { recursive: true }) })

// A minimal PNG header is enough to exercise the dimensions gate; production
// files are generated and fully decoded by the static repo's build-og.py.
function png(width = 1200, height = 630, text = 'v1') {
  const header = Buffer.alloc(24)
  Buffer.from('89504e470d0a1a0a', 'hex').copy(header)
  header.write('IHDR', 12)
  header.writeUInt32BE(width, 16)
  header.writeUInt32BE(height, 20)
  return Buffer.concat([header, Buffer.from(text)])
}

function fixture() {
  const root = mkdtempSync(join(tmpdir(), 't27-cover-versions-'))
  scratch.push(root)
  mkdirSync(join(root, 'og-art'))
  const posts = [{ slug: 'three-panels' }]
  const en = png(), ru = png(1200, 630, 'Russian')
  writeFileSync(join(root, 'og-art/three-panels.jpg'), 'original artwork')
  writeFileSync(join(root, 'og-blog-three-panels.png'), en)
  writeFileSync(join(root, 'og-blog-three-panels-ru.png'), ru)
  return { root, posts, en, ru }
}

test('hashes exact served bytes independently for EN and RU', () => {
  const { root, posts, en, ru } = fixture()
  const versions = collectVersions(root, posts)
  assert.deepEqual(versions['three-panels'], {
    en: createHash('sha256').update(en).digest('hex').slice(0, 12),
    ru: createHash('sha256').update(ru).digest('hex').slice(0, 12),
  })
  const old = versions['three-panels'].en
  writeFileSync(join(root, 'og-blog-three-panels.png'), png(1200, 630, 'v2'))
  assert.notEqual(collectVersions(root, posts)['three-panels'].en, old)
})

test('refuses missing artwork, missing PNG, and a wrong aspect ratio', () => {
  const { root, posts } = fixture()
  assert.throws(() => collectVersions(root, [{ slug: 'missing' }]), /missing triptych/)
  writeFileSync(join(root, 'og-art/missing.jpg'), 'original')
  assert.throws(() => collectVersions(root, [{ slug: 'missing' }]), /missing PNG/)
  writeFileSync(join(root, 'og-blog-three-panels.png'), png(1200, 675))
  assert.throws(() => collectVersions(root, posts), /1200.*630/)
})

test('runs the actual module so quote style and unpublished entries cannot drift', () => {
  const { root } = fixture()
  const source = join(root, 'posts.ts')
  writeFileSync(source, `
    const posts = [{slug: 'single-quoted', published: true},
      {slug: "double-quoted", published: true}, {slug: 'draft', published: false}]
    export const publishedPosts = () => posts.filter(post => post.published)
  `)
  assert.deepEqual(loadPublishedPosts(source).map(p => p.slug), ['single-quoted', 'double-quoted'])
})

test('empty or unsafe post data is refused', () => {
  const { root } = fixture()
  assert.throws(() => collectVersions(root, []), /no published posts/)
  assert.throws(() => collectVersions(root, [{ slug: '../outside' }]), /invalid slug/)
  assert.throws(() => collectVersions(root, [{ slug: 'three-panels' }, { slug: 'three-panels' }]), /duplicate slug/)
})

test('generated output is stable and typed, without timestamps', () => {
  const versions = { z: { en: 'a', ru: 'b' }, a: { en: 'c', ru: 'd' } }
  const source = renderVersions(versions)
  assert.equal(source, renderVersions({ a: versions.a, z: versions.z }))
  assert.match(source, /export const BLOG_COVER_VERSIONS/)
  assert.ok(source.indexOf('"a"') < source.indexOf('"z"'))
})

test('optional captions are exported from the same static source and updates change output', () => {
  const { root, posts } = fixture()
  assert.deepEqual(loadCaptions(root), {})
  const panels = [1, 2, 3].map(n => ({ heading: `PANEL ${n}`, caption: `Finding ${n}.` }))
  writeFileSync(join(root, 'og-art/captions.json'), JSON.stringify({ 'three-panels': { en: panels } }))
  const versions = collectVersions(root, posts)
  const before = renderVersions(versions, loadCaptions(root))
  assert.match(before, /export const BLOG_COVER_CAPTIONS/)
  assert.match(before, /Finding 3/)
  panels[2].caption = 'The limitation changed.'
  writeFileSync(join(root, 'og-art/captions.json'), JSON.stringify({ 'three-panels': { en: panels } }))
  assert.notEqual(before, renderVersions(versions, loadCaptions(root)))
  assert.deepEqual(collectVersions(root, posts), versions)
})

test('caption metadata must contain exactly three nonempty heading/caption pairs', () => {
  const { root } = fixture()
  for (const invalid of [[], { en: [] }, { en: [{ heading: 'One', caption: 'Only one.' }] },
    { en: [{ heading: '', caption: 'Empty heading.' }, { heading: 'Two', caption: 'x' }, { heading: 'Three', caption: 'x' }] }]) {
    writeFileSync(join(root, 'og-art/captions.json'), JSON.stringify({ 'three-panels': invalid }))
    assert.throws(() => loadCaptions(root), /captions/)
  }
})
