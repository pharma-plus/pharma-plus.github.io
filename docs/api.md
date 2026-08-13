# API — PHARMA MAROC GOLD ENTERPRISE V2.0

Base URL : `http://<host>:4000/api/v1`

Format de réponse normalisé :
```json
{ "success": true, "data": …, "meta": { "page": 1, "limit": 20, "total": 5, "pages": 1 } }
```

Erreurs :
```json
{ "success": false, "error": { "code": "VALIDATION_ERROR", "message": "…", "details": [{ "field": "…", "message": "…" }] } }
```

## Authentification

Toutes les routes (sauf `/auth`, `/health`, `/public/website`) exigent :
`Authorization: Bearer <access_token>`.

| Méthode | Route | Description |
| --- | --- | --- |
| POST | `/auth/login` | Connexion (email, password, device). Retourne `accessToken`, `refreshToken`, `user`. |
| POST | `/auth/verify-2fa` | Valide le code TOTP lors d'une connexion 2FA. |
| POST | `/auth/refresh` | Rotation du refresh token (`refreshToken`). |
| POST | `/auth/logout` | Révoque la session courante. |
| GET | `/auth/me` | Profil + permissions. |
| POST | `/auth/password` | Changement de mot de passe (ancien + nouveau). |
| POST | `/auth/2fa/setup` | Active la 2FA → `secret`, `qrCodeUrl`. |
| POST | `/auth/2fa/confirm` | Confirme l'activation avec un code. |

## Santé
| GET | `/health` | Statut du service et de la base. |

## Coeur

### Users `/users`
| GET | `/` | Liste (recherche, status, pagination). `users:view` |
| GET | `/:id` | Détail. |
| POST | `/` | Création d'utilisateur. `users:create` |
| PUT | `/:id` | Modification. `users:edit` |
| PUT | `/:id/status` | Activer / désactiver. `users:edit` |
| POST | `/:id/reset-password` | Réinitialisation. `users:edit` |

### Roles `/roles`
| GET | `/` | Rôles de la pharmacie + permissions. `roles:view` |
| GET | `/permissions` | Catalogue complet des permissions. |
| POST | `/` | Créer un rôle personnalisé. `roles:create` |
| PUT | `/:id` | Renommer. `roles:edit` |
| PUT | `/:id/permissions` | Remplacer les permissions. `roles:edit` |
| DELETE | `/:id` | Supprimer. `roles:delete` |

### Pharmacies `/pharmacies` (Super Admin sauf mention contraire)
| GET | `/` | Liste des tenants. |
| POST | `/` | **Provisioning** : crée pharmacie + licence + succursale + rôles + admin. |
| GET | `/global-stats` | Vue d'ensemble de toutes les pharmacies. |
| GET | `/me` | Pharmacie de l'utilisateur connecté. |
| GET | `/self` | Alias de `/me`. |
| PUT | `/me` | Mise à jour de la pharmacie de l'utilisateur connecté. |
| GET | `/:id` | Détail. |
| PUT | `/:id` | Mise à jour. |
| PUT | `/:id/settings` | Réglages JSON. |
| PUT | `/:id/colors` | Palette (thème). |
| DELETE | `/:id` | Suppression (soft). |
| POST | `/:id/status` | Suspension / activation / suppression (`suspended`, `active`, `deleted`). |
| GET | `/:id/stats` | Statistiques du tenant (succursales, utilisateurs, ventes, CA, achats, licence). |

### Succursales `/branches`
| GET | `/` | Liste. `branches:view` |
| POST | `/` | Création. `branches:create` |
| PUT | `/:id` | Modification. `branches:edit` |
| DELETE | `/:id` | Suppression. `branches:delete` |

### Licences `/licenses` (Super Admin)
| GET | `/` | Liste. |
| POST | `/` | Attribution. |
| POST | `/:id/renew` | Renouvellement. |
| PUT | `/:id/status` | Activer / suspendre. |

### Audit `/audit`
| GET | `/` | Journal (filtres). `audit:view` |
| GET | `/entity/:entity/:entityId` | Historique d'une entité. |
| GET | `/stats` | Résumé des actions. |

## Modules métier

### Catalogue `/catalog`
| GET | `/categories` / POST `/categories` | Catégories. `catalog:*` |
| GET | `/families` / POST `/families` | Familles thérapeutiques. |
| GET | `/laboratories` / POST `/laboratories` | Laboratoires. |
| GET | `/medications` | Médicaments (q, barcode, catégorie, pagination). |
| POST | `/medications` | Création (EAN-13 validé, recherche automatique). |
| GET | `/medications/barcode/:code` | Recherche exacte par code-barres EAN-13. |
| POST | `/medications/bulk` | Import en masse. |
| PUT | `/medications/:id` | Modification. |
| DELETE | `/medications/:id` | Suppression (soft si référencé). |
| GET | `/medications/:id/equivalents` | Équivalents thérapeutiques. |
| POST | `/medications/:id/equivalents` | Ajouter un équivalent. |

### Stock `/stock`
| GET | `/balances` | Niveaux par médicament (alertes incluses). `stock:view` |
| POST | `/entries` | Entrée de stock (lot + mouvement). `stock:create` |
| POST | `/adjustments` | Ajustement (écart inventaire). `stock:edit` |
| POST | `/write-off` | Perte / mise au rebut. `stock:edit` |
| POST | `/transfers` | Transfert entre succursales. `stock:create` |
| GET | `/transfers` | Liste des transferts (statuts). |
| GET | `/movements` | Journal des mouvements (filtres). |
| GET | `/lots` | Lots (péremptions). |
| GET | `/alerts` | Alertes seuil bas + péremption. |

### Ventes / POS `/sales`
| GET | `/` | Liste des ventes. `sales:view` |
| POST | `/` | **Créer une vente** (lignes, paiements, remises, TVA, client). `sales:create` |
| GET | `/:id` | Détail + lignes + paiements. |
| GET | `/invoices` | Liste des factures. |
| POST | `/returns` | Retour / remboursement / échange (par lot d'origine). `sales:create` |
| POST | `/payments` | Paiement complémentaire sur facture ou vente. `sales:create` |
| GET | `/reservations` | Liste des réservations clients. |
| POST | `/reservations` | Créer une réservation (réserve le stock). |
| POST | `/reservations/:id/release` | Libérer une réservation. `sales:edit` |

Règles de calcul (`computeLine`) : TVA 20 %, remise %, arrondi au centime, prix FEFO
(premier expiré premier servi), stock négatif refusé, retour par lot d'origine.

### Achats `/purchases`
| GET | `/orders` | Commandes (statuts). `purchases:view` |
| POST | `/orders` | Création (draft). `purchases:create` |
| GET | `/orders/:id` | Détail (lignes + réceptions). |
| POST | `/orders/:id/status` | `draft` → `sent` → `confirmed` / `cancelled`. `purchases:edit` |
| POST | `/orders/:id/receive` | **Réception** → création des lots + mouvements de stock. `purchases:create` |
| GET | `/receptions` | Liste des réceptions. `purchases:view` |

### Fournisseurs `/suppliers`
| GET | `/` / POST `/` / GET `/:id` / PUT `/:id` / DELETE `/:id` | CRUD. `suppliers:*` |
| POST | `/:id/payments` | Paiement fournisseur. |
| GET | `/performance` | Délais, volumes, note. `reports:view` |

### Clients `/customers`
| GET | `/` / POST `/` / GET `/:id` / PUT `/:id` / DELETE `/:id` | CRUD. `customers:*` |
| GET | `/:id/history` | Historique d'achats + soldes. |

### Tableau de bord `/dashboard`
| GET | `/overview` | CA, panier moyen, transactions, top produits, alertes stock. |
| GET | `/top-products` | Top produits sur la période. |
| GET | `/sales-trend` | Série jour/semaine/mois. |
| GET | `/compare` | Comparaison période vs période précédente. |

### Rapports `/reports`
| GET | `/sales` | Ventes agrégées par période (groupBy). `reports:view` |
| GET | `/products` | Top / répartition produits. |
| GET | `/stock` | État du stock + valeur. |
| GET | `/financial` | CA, remises, marges, TVA. `accounting:view` |
| GET | `/employees` | Pointage / heures / congés. |

### Ordonnances `/prescriptions`
| GET | `/` / POST `/` / GET `/:id` / PUT `/:id` / DELETE `/:id` | CRUD. `prescriptions:*` |
| POST | `/:id/dispense` | Marquer les lignes comme délivrées (→ `filled`). |
| POST | `/:id/status` | Changement de statut. |

### Employés `/employees`
| GET | `/` / POST `/` / GET `/:id` / PUT `/:id` / DELETE `/:id` | CRUD. `employees:*` |
| POST | `/:id/documents` / DELETE `/:id/documents/:docId` | Documents RH. |
| POST | `/:id/bonuses` | Prime. |
| POST | `/:id/evaluations` | Évaluation. |
| GET | `/summary` | Masse salariale, effectifs. |

### Pointage & congés `/attendance`
| GET | `/` | Journal de pointage. `attendance:view` |
| POST | `/clock-in` / `/clock-out` | Pointage (PIN/QR/biométrie). `attendance:edit` |
| POST | `/manual` | Saisie manuelle / correction. |
| GET | `/leaves` / POST `/leaves` / POST `/leaves/:id/decide` | Congés. `attendance:approve` |
| PUT | `/schedules` / GET `/employees/:id/schedule` | Plannings. |
| GET | `/summary` | Synthèse mensuelle (paie). |

### Comptabilité `/accounting`
| GET | `/accounts` / POST `/accounts` | Plan comptable. `accounting:*` |
| GET | `/journal` / GET `/journal/:id` / POST `/journal` | Écritures (équilibrées). |
| GET | `/trial-balance` | Balance par compte. |
| GET | `/registers/:branchId/open` | Caisse ouverte. |
| POST | `/registers` | Ouvrir une caisse. |
| POST | `/registers/:id/movements` | Mouvement (entrée/sortie). |
| POST | `/registers/:id/close` | Clôture (différence calculée). |
| GET | `/expense-categories` / POST | Catégories de dépenses. |
| GET | `/expenses` / POST `/expenses` | Dépenses. |
| POST | `/closings` | Clôture mensuelle/annuelle. |

### Notifications `/notifications`
| GET | `/` | Liste (+ compteur non lues). `notifications:view` |
| POST | `/:id/read` | Marquer comme lue. |
| POST | `/read-all` | Tout marquer. |
| GET | `/alerts/stock` | Alertes stock générées. |

### Sauvegardes `/backups`
| GET | `/` | Historique. `backups:view` |
| POST | `/` | Lancer une sauvegarde (worker). `backups:create` |
| POST | `/:id/restore` | Restauration. `backups:approve` |
| POST | `/:id/verify` | Vérification du checksum. `backups:edit` |
| DELETE | `/:id` | Suppression d'un fichier. `backups:delete` |
| GET | `/stats/global` | Super Admin. |

### Synchronisation `/sync`
| GET | `/state` | Révisions par entité. `sync:view` |
| POST | `/push` | Enregistrer l'état d'un appareil. `sync:edit` |
| GET | `/pull/:entity` | Delta depuis une révision (catalogue). |

### Support `/support`
| GET | `/` / POST `/` / GET `/:id` | Tickets. `support:*` |
| POST | `/:id/messages` | Répondre. |
| POST | `/:id/status` | Changer le statut. |

### Site Web & Blog
| GET | `/public/website/:slug` | **Public** : site de la pharmacie (infos, catalogue public, blog, succursales). |
| GET | `/public/website/:slug/blog/:postSlug` | **Public** : article de blog. |
| GET | `/website/settings` / PUT `/website/settings` | Réglages du site. `website:view/edit` |
| GET | `/website/blog/categories` / POST | Catégories. |
| GET | `/website/blog/posts` / POST | Articles. |
| PUT | `/website/blog/posts/:id` / DELETE | Édition / suppression. |

### Assistant IA `/ai`
| GET | `/insights` | Réapprovisionnement, péremptions, invendus, top ventes. `ai:view` |
| POST | `/chat` | Assistant conversationnel (règles). |

## Erreurs principales
| Code HTTP | `code` | Signification |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | Champs invalides (`details`). |
| 401 | `UNAUTHORIZED` | Jeton manquant / invalide / expiré. |
| 403 | `FORBIDDEN` | Permission ou licence manquante. |
| 404 | `NOT_FOUND` | Ressource absente. |
| 409 | `CONFLICT` | Violation d'unicité (ex. EAN-13). |
| 422 | `UNPROCESSABLE` | Règle métier (écriture non équilibrée, stock négatif…). |
| 429 | `TOO_MANY_REQUESTS` | Rate limit. |
| 500 | `INTERNAL_ERROR` | Erreur serveur. |
