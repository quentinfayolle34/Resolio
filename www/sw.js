/* Service worker de l'app web Resolio.
 * Il garde seulement une copie des fichiers de l'app (HTML, polices, icônes) pour qu'elle s'ouvre vite
 * et affiche « hors ligne » proprement. Aucune donnée : tout reste dans Supabase.
 * Réseau d'abord : une nouvelle version publiée est prise dès qu'il y a internet.
 */
const CACHE = 'resolio-shell-v1';
const SHELL = ['./', 'index.html', 'config.js', 'vendor/supabase.js', 'fonts/fonts.css', 'manifest.webmanifest', 'icons/icon-192.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request, url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== self.location.origin) return;   // Supabase et photos : jamais interceptés
  e.respondWith(
    fetch(req).then(res => {
      if (res.ok && res.type === 'basic') { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
      return res;
    }).catch(() => caches.match(req, { ignoreSearch: req.mode === 'navigate' }).then(r => r || (req.mode === 'navigate' ? caches.match('index.html') : undefined)))
  );
});
