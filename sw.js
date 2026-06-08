// Service Worker — 离线缓存 + 后台同步
const CACHE_NAME = 'timeline-v2';
const ASSETS_TO_CACHE = [
  '/',
  '/index.html',
];

// 安装时缓存静态资源
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(ASSETS_TO_CACHE))
  );
  self.skipWaiting();
});

// 激活时清理旧缓存
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// 网络优先，失败时回退缓存
self.addEventListener('fetch', (event) => {
  // 跳过 Supabase API 请求（让它们走网络）
  if (event.request.url.includes('supabase.co') || event.request.url.includes('supabase.in')) {
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then(response => {
        // 只缓存成功响应
        if (response.status === 200) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
        }
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});
