import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    port: 5173,
    host: '0.0.0.0',
    allowedHosts: [
      'localhost',
      '127.0.0.1',
      '.gitpod.dev',
      '.gitpod.io',
      '5173--019c11f7-ac99-7331-aaf5-d160ef109e39.eu-central-1-01.gitpod.dev'
    ],
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8080',
        changeOrigin: true,
        secure: false
      }
    }
  }
});
