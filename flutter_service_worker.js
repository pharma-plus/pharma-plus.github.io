'use strict';

// SW AUTO-DESTRUCTEUR v2
// Objectif : ne JAMAIS servir une version cacee du site.
// 1) install  -> skipWaiting (prend le controle immediatement)
// 2) activate -> purge TOUS les caches du domaine, claim (controle les
//    onglets ouverts), recharge chaque onglet, puis desinscription.
// Aucun fetch handler : aucune reponse ne vient jamais du cache.

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      try {
        const keys = await caches.keys();
        await Promise.all(keys.map((k) => caches.delete(k)));
      } catch (e) {
        console.warn('Cache purge failed:', e);
      }
      try {
        await self.clients.claim();
      } catch (e) {
        console.warn('Claim failed:', e);
      }
      try {
        const clients = await self.clients.matchAll({ type: 'window' });
        clients.forEach((client) => {
          if (client && client.url) {
            client.navigate(client.url).catch(() => {});
          }
        });
      } catch (e) {
        console.warn('Client reload failed:', e);
      }
      try {
        await self.registration.unregister();
      } catch (e) {
        console.warn('Unregister failed:', e);
      }
    })()
  );
});