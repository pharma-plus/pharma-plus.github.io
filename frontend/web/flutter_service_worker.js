'use strict';
// No-op service worker — empêche la boucle de rechargement
// qui causait l'écran vert pétrole vide sur Mac/Safari.
// Flutter gère lui-même ses ressources.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', () => {});
