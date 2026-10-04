import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react-swc'
import fs from 'fs'
import path from 'path'
// Read at config time, so the tag is the hash of the file this build is about
// to copy. Shared with qa/spec-catalog-contract.mjs, which hands the same
// value to the same driver under node -- see that module for why the compiler
// needs a content-addressed URL at all.
import { t27WasmTag } from './scripts/t27-wasm-tag.ts'
import { bootShell, escapeHtml } from './scripts/boot-shell.ts'

/**
 * Write the first screen into index.html at build time: scripts/boot-shell.ts
 * holds the words and the links, and says why they are what they are.
 */
function prerenderHero(): Plugin {
  return {
    name: 'prerender-hero',
    transformIndexHtml(html) {
      const marker = /<div id="boot">[\s\S]*?<!-- \/boot -->/
      if (!marker.test(html)) throw new Error('prerender-hero: #boot block not found in index.html')
      return html.replace(marker, bootShell())
    },
  }
}

/**
 * Emit dist/rss.xml from the same posts.ts the page renders.
 *
 * Generated rather than hand-kept, because a feed that drifts from the site is
 * worse than no feed: it is a second source of truth that nobody looks at until
 * it is wrong. The publisher rsyncs the whole dist tree to the apex, so this
 * lands at https://t27.ai/rss.xml with no change on that side.
 *
 * The posts module is loaded by transpiling it with esbuild rather than by
 * pattern-matching the file, so the feed cannot disagree with what the site
 * shows — if the schema changes, this breaks loudly instead of quietly
 * emitting nonsense.
 */
function rssFeed(): Plugin {
  return {
    name: 'rss-feed',
    apply: 'build',
    async closeBundle() {
      const esbuild = await import('esbuild')
      const entry = path.resolve(__dirname, 'src/data/blog/posts.ts')
      const out = path.resolve(__dirname, 'node_modules/.rss-posts.mjs')

      await esbuild.build({
        entryPoints: [entry],
        outfile: out,
        bundle: true,
        format: 'esm',
        platform: 'node',
        logLevel: 'silent',
      })

      const mod = await import(`${out}?t=${Date.now()}`)
      const posts = (mod.publishedPosts?.() ?? []) as Array<{
        slug: string
        title: string
        summary: string
        date: string
        tags: string[]
      }>
      if (!posts.length) throw new Error('rss-feed: publishedPosts() returned nothing')

      const site = 'https://t27.ai'
      const rfc822 = (d: string) => new Date(`${d}T12:00:00Z`).toUTCString()
      const sorted = [...posts].sort((a, b) => (a.date < b.date ? 1 : -1))

      const items = sorted
        .map((p) => {
          const link = `${site}/#/blog/${p.slug}`
          return `    <item>
      <title>${escapeHtml(p.title)}</title>
      <link>${escapeHtml(link)}</link>
      <guid isPermaLink="false">${escapeHtml(p.slug)}</guid>
      <pubDate>${rfc822(p.date)}</pubDate>
      <description>${escapeHtml(p.summary)}</description>
${(p.tags ?? []).map((t) => `      <category>${escapeHtml(t)}</category>`).join('\n')}
    </item>`
        })
        .join('\n')

      const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>Trinity — measured results</title>
    <link>${site}/#/blog</link>
    <atom:link href="${site}/rss.xml" rel="self" type="application/rss+xml" />
    <description>Measured results and the methods behind them. Every post names what is not proven.</description>
    <language>en</language>
    <lastBuildDate>${rfc822(sorted[0].date)}</lastBuildDate>
${items}
  </channel>
</rss>
`
      const dist = path.resolve(__dirname, 'dist')
      fs.mkdirSync(dist, { recursive: true })
      fs.writeFileSync(path.join(dist, 'rss.xml'), xml, 'utf-8')
      fs.rmSync(out, { force: true })
    },
  }
}

// https://vite.dev/config/
export default defineConfig(() => ({
  // Relative base so the built SPA works wherever it is served from: the apex
  // (t27.ai/) and the project-pages subpath (t27.ai/trinity/) alike. With '/'
  // the subpath deploy asked for /assets/... at the apex root, got 404s, and
  // the page rendered blank. Safe here because routing is HashRouter.
  base: './',
  plugins: [react(), prerenderHero(), rssFeed()],
  // Textually replaced, so `t27/t27_compiler.wasm?v=${__T27_WASM_TAG__}` in the
  // bundle is a literal. Deliberately NOT given a fallback: a context that
  // evaluates this identifier without defining it throws a ReferenceError,
  // which is louder than quietly serving the unversioned URL this exists to
  // replace. The node-side gate sets it on globalThis for the same reason.
  define: { __T27_WASM_TAG__: JSON.stringify(t27WasmTag()) },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  build: {
    rollupOptions: {
      output: {
        // Split the big vendors apart. Previously only `three` was named, so
        // React ended up in a chunk called "three" while react-router (347 kB
        // of source) and framer-motion (425 kB) sat in the entry chunk — any
        // app edit then re-downloaded all of it.
        //
        // Matched by module id, not by package name: framer-motion v12 splits
        // its runtime across motion-dom and motion-utils, which a name list
        // silently misses. Order matters — react-router before react.
        manualChunks(id) {
          if (!id.includes('node_modules')) return
          if (id.includes('/react-router')) return 'router'
          if (/\/(framer-motion|motion-dom|motion-utils)\//.test(id)) return 'motion'
          if (/\/(three|@react-three)\//.test(id)) return 'three'
          if (/\/(react|react-dom|scheduler)\//.test(id)) return 'react'
        },
      },
    },
  },
  server: {
    host: '0.0.0.0',
    port: 5173,
    allowedHosts: ['.gitpod.dev', '.gitpod.io', 'localhost'],
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    },
  },
}))
