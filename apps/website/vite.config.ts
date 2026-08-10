import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react-swc'
import fs from 'fs'
import path from 'path'

const escapeHtml = (s: unknown) =>
  String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')

/**
 * Write the first screen into index.html at build time.
 *
 * The page is a client-rendered SPA, so #root shipped empty: nothing was on
 * screen until 524 kB of JavaScript had downloaded, parsed and mounted, and
 * anything that does not run JS — every preview bot, and crawlers on their
 * first pass — saw a document with no heading and no prose at all.
 *
 * The copy is read from messages/en.json rather than written here, so it cannot
 * drift from the hero it stands in for. The links are the clean static paths,
 * not the #/ hash routes the app uses: those pages are real HTML and work with
 * JavaScript switched off, which is the whole point of this shell.
 *
 * React clears #root on its first render, so nothing has to remove it.
 */
function prerenderHero(): Plugin {
  return {
    name: 'prerender-hero',
    transformIndexHtml(html) {
      const file = path.resolve(__dirname, 'messages/en.json')
      const hero = JSON.parse(fs.readFileSync(file, 'utf-8')).hero
      // Fail the build rather than ship the placeholder: a silently un-replaced
      // shell would claim less than the page does and nobody would notice.
      for (const k of ['tag', 'headline', 'subheadline', 'cta', 'ctaSecondary']) {
        if (!hero?.[k]) throw new Error(`prerender-hero: messages/en.json hero.${k} is missing`)
      }
      const shell = `<div id="boot">
      <img src="trinity-logo-with-label.svg" alt="TRINITY" width="1080" height="1080" />
      <h1>${escapeHtml(hero.tag)}</h1>
      <p class="eq">${escapeHtml(hero.headline)}</p>
      <p class="sub">${escapeHtml(hero.subheadline)}</p>
      <div class="btns">
        <a class="primary" href="ip/">${escapeHtml(hero.cta)}</a>
        <a href="proof/">${escapeHtml(hero.ctaSecondary)}</a>
      </div>
    </div><!-- /boot -->`
      const marker = /<div id="boot">[\s\S]*?<!-- \/boot -->/
      if (!marker.test(html)) throw new Error('prerender-hero: #boot block not found in index.html')
      return html.replace(marker, shell)
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
  plugins: [react(), prerenderHero()],
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
