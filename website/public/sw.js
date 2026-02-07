// Self-destroying service worker - unregisters itself and clears all caches
self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    Promise.all([
      // Unregister this service worker
      self.registration.unregister(),
      // Clear all caches
      caches.keys().then((keys) => {
        return Promise.all(keys.map((key) => caches.delete(key)));
      })
    ])
  );
});

// Don't intercept any requests
self.addEventListener('fetch', () => {});
