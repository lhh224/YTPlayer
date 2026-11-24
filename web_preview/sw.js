const CACHE_NAME = 'ytplayer-pwa-v2';
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
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)).catch(() => {})
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
      fetch(event.request)
        .catch(() => caches.match(event.request))
        .then((resp) => resp.arrayBuffer())
        .then((buf) => new Response(buf, {
          status: 200,
          headers: { 'Content-Type': 'application/x-apple-aspen-config' }
        }))
    );
    return;
  }
  event.respondWith(
    fetch(event.request).catch(() => caches.match(event.request))
  );
});
