'use strict';

// BUILD STAMP : __PMG_BUILD_STAMP__
// Ce SW est volontairement « auto-destructeur » : il purge TOUS les caches
// du domaine, recharge les onglets ouverts puis se désinscrit.
// IMPORTANT : le fichier DOIT changer à chaque build (empreinte injectée par
// le workflow deploy-web.yml). Sans cela, le navigateur considère le script
// inchangé → il n'installe jamais cette version → l'ancien SW Flutter
// (qui sert les assets en cache) reste actif et l'utilisateur continue de
// voir les illustrations d'une version précédente, indéfiniment, sur mobile.

self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
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