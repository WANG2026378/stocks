// Cross-Origin Isolation Service Worker
// 讓 GitHub Pages 支援 SharedArrayBuffer（FFmpeg.wasm WMA 轉檔需要）
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', e => {
  e.respondWith(
    fetch(e.request).then(r => {
      const h = new Headers(r.headers);
      h.set('Cross-Origin-Opener-Policy', 'same-origin');
      h.set('Cross-Origin-Embedder-Policy', 'credentialless');
      return new Response(r.body, { status: r.status, statusText: r.statusText, headers: h });
    }).catch(() => fetch(e.request))
  );
});
