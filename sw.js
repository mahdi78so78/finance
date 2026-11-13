/* سرویس‌ورکر: فقط برای باز شدن سریع و نصب‌پذیری.
   داده‌های Supabase هرگز کش نمی‌شوند و همیشه از سرور خوانده می‌شوند. */
const VER = "finance-v4-jalali-calendar";
const SHELL = ["./", "index.html", "manifest.webmanifest", "icon-192.png", "icon-512.png", "icon-maskable-512.png", "apple-touch-icon.png"];
const CDN = /^https:\/\/(cdn\.jsdelivr\.net|unpkg\.com|fonts\.googleapis\.com|fonts\.gstatic\.com)\//;

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(VER).then((c) => Promise.all(SHELL.map((u) => c.add(u).catch(() => {})))).then(() => self.skipWaiting()));
});
self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== VER).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});

async function networkFirst(req) {
  const cache = await caches.open(VER);
  try {
    const res = await fetch(req);
    if (res && res.ok) cache.put(req, res.clone());
    return res;
  } catch (err) {
    return (await cache.match(req)) || (await cache.match("index.html")) || Response.error();
  }
}
async function staleWhileRevalidate(req) {
  const cache = await caches.open(VER);
  const hit = await cache.match(req);
  const net = fetch(req).then((res) => { if (res && (res.ok || res.type === "opaque")) cache.put(req, res.clone()); return res; }).catch(() => null);
  return hit || (await net) || Response.error();
}

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.hostname.endsWith(".supabase.co")) return; // API و ورود: دست نمی‌زنیم
  if (req.mode === "navigate" && url.origin === location.origin) { e.respondWith(networkFirst(req)); return; }
  if (url.origin === location.origin || CDN.test(req.url)) e.respondWith(staleWhileRevalidate(req));
});
