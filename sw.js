/* RouteFast Planner — service worker
   Offline kaart-cache + app-shell. Tiles van tiles.openfreemap.org worden
   cache-first bewaard, zodat eerder bezochte gebieden offline blijven werken.
   Bump CACHE_VERSION bij een nieuwe build om oude caches te verversen. */
'use strict';
const CACHE_VERSION = 'v1-build41';
const SHELL = 'rf-shell-' + CACHE_VERSION;
const TILES = 'rf-tiles-' + CACHE_VERSION;
const SHELL_ASSETS = ['./', './index.html', './icon.png', './gps-icon.png'];

self.addEventListener('install', e => {
  self.skipWaiting();
  e.waitUntil(caches.open(SHELL).then(c =>
    Promise.allSettled(SHELL_ASSETS.map(u => c.add(u)))
  ));
});

self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k !== SHELL && k !== TILES).map(k => caches.delete(k)));
    await self.clients.claim();
  })());
});

const isTile = u => /tiles\.openfreemap\.org/i.test(u);
const isCDN  = u => /unpkg\.com|cdnjs\.cloudflare\.com/i.test(u);
const isAPI  = u => /pdok\.nl|project-osrm|osrm/i.test(u);

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = req.url;
  if (isAPI(url)) return;                                         // dynamisch, niet cachen
  if (isTile(url)) { e.respondWith(cacheFirst(req, TILES)); return; }
  if (isCDN(url))  { e.respondWith(staleWhileRevalidate(req, SHELL)); return; }
  if (req.mode === 'navigate') { e.respondWith(networkFirst(req, SHELL)); return; }
  if (new URL(url).origin === self.location.origin) {
    e.respondWith(staleWhileRevalidate(req, SHELL));
  }
});

async function cacheFirst(req, name) {
  const cache = await caches.open(name);
  const hit = await cache.match(req);
  if (hit) return hit;
  try {
    const res = await fetch(req);
    if (res && (res.ok || res.type === 'opaque')) cache.put(req, res.clone());
    return res;
  } catch (err) {
    return hit || Response.error();
  }
}

async function networkFirst(req, name) {
  const cache = await caches.open(name);
  try {
    const res = await fetch(req);
    if (res && res.ok) cache.put(req, res.clone());
    return res;
  } catch (err) {
    return (await cache.match(req)) || (await cache.match('./index.html')) || Response.error();
  }
}

async function staleWhileRevalidate(req, name) {
  const cache = await caches.open(name);
  const hit = await cache.match(req);
  const net = fetch(req).then(res => {
    if (res && (res.ok || res.type === 'opaque')) cache.put(req, res.clone());
    return res;
  }).catch(() => hit);
  return hit || net;
}
