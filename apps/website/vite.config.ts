import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'
import path from 'path'

// https://vite.dev/config/
export default defineConfig(() => ({
  // Relative base so the built SPA works wherever it is served from: the apex
  // (t27.ai/) and the project-pages subpath (t27.ai/trinity/) alike. With '/'
  // the subpath deploy asked for /assets/... at the apex root, got 404s, and
  // the page rendered blank. Safe here because routing is HashRouter.
  base: './',
  plugins: [react()],
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
