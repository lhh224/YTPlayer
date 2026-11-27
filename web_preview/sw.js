const CACHE_NAME = 'ytplayer-pwa-v7';
const APP_SHELL = [
  './',
  './index.html',
  './install.html',
  './YTPlayer.mobileconfig',
  './manifest.json',
  './icons/apple-touch-icon.png',
  './icons/icon-192.png',
  './icons/icon-512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) =>
      Promise.all(
        APP_SHELL.map((url) =>
          fetch(url, { cache: 'no-cache' })
            .then((resp) => (resp.ok ? cache.put(url, resp) : undefined))
            .catch(() => {})
        )
      )
    )
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  if (url.pathname.endsWith('.mobileconfig')) {
    event.respondWith(
      fetch(event.request, { cache: 'no-cache' })
        .catch(() => caches.match(event.request))
        .then((resp) => resp.arrayBuffer())
        .then((buf) => new Response(buf, {
          status: 200,
          headers: { 'Content-Type': 'application/x-apple-aspen-config' }
        }))
    );
    return;
  }

  // Always revalidate HTML documents so the installed iPhone Profile App gets updates immediately
  const isHTML = event.request.mode === 'navigate' || url.pathname.endsWith('/') || url.pathname.endsWith('.html');
  event.respondWith(
    fetch(event.request, isHTML ? { cache: 'no-cache' } : undefined)
      .then((resp) => {
        if (resp && resp.ok) {
          const copy = resp.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy)).catch(() => {});
        }
        return resp;
      })
      .catch(() => caches.match(event.request))
  );
});
