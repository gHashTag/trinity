import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  base: '/',
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
      '/health': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
  // Railway serves this through `npm start`, which is `vite preview`. Vite's
  // preview server answers any Host it was not told about with 403 -- the
  // DNS-rebinding guard that arrived in 6.0.9 and is on by default. The
  // platform's own probe comes in as `healthcheck.railway.app`, so every
  // deployment built cleanly, started, and then failed its healthcheck five
  // times in thirty seconds. Four merges on 2026-09-21 never reached a running
  // replica, and the build log said SUCCESS above the failure each time.
  //
  // A leading dot allows a domain and every subdomain, so one entry covers both
  // the probe and the generated `*.up.railway.app` service domain -- neither of
  // which is written down anywhere else, and the generated one can be reissued.
  // The guard stays on for every other Host: `allowedHosts: true` would switch
  // it off entirely, which is more than this failure asks for.
  preview: {
    allowedHosts: ['.railway.app'],
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
});
