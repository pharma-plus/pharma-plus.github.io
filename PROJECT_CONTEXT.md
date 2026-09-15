# PHARMA+ — PROJECT CONTEXT

## 1. IDENTITÉ DU PROJET

Nom du projet : PHARMA+ / PHARMA MAROC GOLD

Objectif :
Construire une véritable application professionnelle de gestion de pharmacie destinée aux pharmacies marocaines.

Ce projet n'est PAS une simple maquette, une démonstration ou un prototype visuel.

Toutes les fonctions visibles doivent être réellement connectées et opérationnelles.

---

## 2. RÈGLE ABSOLUE — PRÉSERVER L'EXISTANT

AVANT TOUTE MODIFICATION :

* Lire ce fichier.
* Examiner le code existant.
* Comprendre l'architecture réelle.
* Réutiliser les composants, services, routes et fonctions déjà présents.
* Ne pas reconstruire inutilement ce qui existe déjà.
* Ne pas remplacer une fonctionnalité fonctionnelle par une nouvelle version fictive.
* Ne pas supprimer des données existantes.
* Ne pas supprimer les tables Supabase.
* Ne pas recréer la base de données.
* Ne pas réinitialiser Supabase.
* Ne pas modifier ou supprimer les secrets `.env`.
* Ne pas modifier les URLs API existantes sans nécessité réelle.
* Ne pas changer le design validé globalement.
* Ne pas remplacer les images validées.
* Ne pas changer le logo officiel PHARMA+.
* Ne pas changer la structure générale du dashboard sans nécessité fonctionnelle.

Toute modification doit être minimale, ciblée et compatible avec l'existant.

---

## 3. BACKEND ET SUPABASE

Backend existant :

* Supabase
* PostgreSQL
* Auth
* Storage
* API backend existante
* Tables existantes
* Données existantes

La base actuelle doit être considérée comme une base de production à préserver.

NE JAMAIS :

* DROP TABLE
* DELETE massif
* TRUNCATE
* recréer les tables existantes
* réinitialiser Supabase
* écraser les données existantes
* remplacer les données réelles par des données fictives.

Si une migration est réellement nécessaire :

* l'analyser avant modification ;
* utiliser une migration additive ;
* préserver les données existantes ;
* ne jamais effectuer de migration destructive sans autorisation explicite.

---

## 4. DONNÉES RÉELLES

L'application doit utiliser les données réellement disponibles dans Supabase.

Ne jamais afficher de fausses statistiques ou de fausses données uniquement pour rendre l'interface jolie.

Exemples de valeurs fictives à NE PAS utiliser :

* 12 540 MAD
* 28 450 MAD
* 1 248 clients
* 2 350 médicaments
* faux fournisseurs
* fausses ventes
* faux bénéfices.

Si la base est vide :

* afficher 0 ;
* afficher une liste vide propre ;
* afficher un état "Aucune donnée" ;
* proposer l'action appropriée.

Les données doivent être calculées à partir des données réelles.

---

## 5. DESIGN VALIDÉ

Le design actuel validé doit être conservé.

Direction artistique :

* Premium
* Professionnelle
* Pharmacie moderne
* Vert foncé / vert pétrole
* Noir
* Or 24K / champagne
* Effets 3D maîtrisés
* Logo officiel PHARMA+
* Interface moderne
* Cartes KPI premium
* Responsive
* Touchscreen friendly

NE PAS transformer l'application en interface classique, blanche, générique ou administrative.

NE PAS changer la direction artistique simplement pour "refaire le design".

Les améliorations doivent respecter le design existant.

---

## 6. STRUCTURE PRINCIPALE DU DASHBOARD

Sidebar principale prévue :

1. Tableau de bord
2. Point de vente
3. Catalogue
4. Médicaments
5. Stock
6. Fournisseurs
7. Commandes
8. Clients
9. Employés
10. Rapports
11. Plan 3D
12. Paramètres

Modules supplémentaires pouvant exister :

* Caméras
* Scanner
* Autres modules

Le menu doit rester cohérent et toutes les entrées visibles doivent avoir une destination fonctionnelle.

---

## 7. DASHBOARD

Le dashboard doit afficher les données réelles.

KPI prévus :

* Ventes du jour
* Médicaments
* Stock faible
* Commandes
* Fournisseurs
* Clients
* Employés
* Bénéfice

Chaque KPI doit être cliquable lorsque prévu et conduire vers la page ou le filtre correspondant.

Exemples :

Ventes du jour → ventes/POS du jour

Médicaments → Catalogue/Médicaments

Stock faible → Stock avec filtre faible

Commandes → Commandes

Fournisseurs → Fournisseurs

Clients → Clients

Employés → Employés

Bénéfice → Rapports financiers

---

## 8. FONCTIONS DE CALCUL

Réutiliser les helpers existants lorsqu'ils existent.

Fonctions importantes :

calculateSaleTotal

calculateDiscount

calculateProfit

calculateLowStock

calculateExpiredProducts

calculateDailySales

calculateMonthlySales

calculateSupplierTotals

calculateCustomerTotals

Ne pas créer une deuxième logique concurrente si une logique fiable existe déjà.

---

## 9. POINT DE VENTE / POS

Le Point de vente doit être réellement fonctionnel.

Fonctions attendues :

* recherche produit ;
* sélection médicament ;
* quantité ;
* prix ;
* remise ;
* calcul total ;
* encaissement ;
* vente ;
* décrémentation du stock ;
* traçabilité ;
* historique ;
* impression lorsque prévue ;
* scanner code-barres ;
* interaction tactile.

Le total doit être calculé à partir des données réelles.

Après une vente validée :

* le stock doit être correctement décrémenté ;
* la vente doit être enregistrée ;
* les statistiques doivent être mises à jour.

---

## 10. VENTE DU JOUR

La page Vente du jour ne doit pas être vide artificiellement.

Elle doit récupérer les ventes réelles du jour depuis le backend/Supabase.

Afficher correctement :

* ventes ;
* produits ;
* quantités ;
* montant ;
* remises ;
* total ;
* éventuellement bénéfice ;
* historique.

S'il n'y a aucune vente :
afficher proprement "Aucune vente aujourd'hui" avec valeur 0 lorsque nécessaire.

Le bouton/icône Home doit réellement ramener au dashboard.

---

## 11. CATALOGUE

La page Catalogue doit être fonctionnelle.

Elle doit récupérer les médicaments/produits existants.

Fonctions attendues selon l'architecture existante :

* recherche ;
* filtre ;
* affichage ;
* catégorie ;
* prix ;
* stock ;
* état ;
* sélection ;
* ajout au POS.

Ne pas afficher une liste fictive.

---

## 12. MÉDICAMENTS

Les médicaments doivent provenir des données réelles.

La base actuelle contient déjà des médicaments.

Lorsqu'un enrichissement/import est nécessaire :

* utiliser uniquement des informations vérifiables ;
* ne pas inventer de médicaments ;
* ne pas écraser les données existantes ;
* éviter les doublons ;
* respecter le schéma existant.

Les médicaments commercialisés au Maroc doivent être traités avec des données vérifiables.

---

## 13. FOURNISSEURS

La page Fournisseurs doit être réellement connectée aux données existantes.

La base contient déjà des fournisseurs.

La page doit permettre selon les fonctions existantes :

* affichage ;
* recherche ;
* détails ;
* commandes ;
* contact ;
* historique ;
* statistiques ;
* ajout/modification si prévu.

Ne pas remplacer les fournisseurs existants par des données fictives.

---

## 14. COMMANDES

Les commandes doivent être reliées aux fournisseurs et aux produits.

Préserver la logique existante.

Une commande validée doit pouvoir être tracée.

Les opérations de stock doivent rester cohérentes.

---

## 15. STOCK

Le stock doit utiliser les données réelles.

Fonctions importantes :

* stock disponible ;
* stock faible ;
* produits expirés ;
* mouvements ;
* entrées ;
* sorties ;
* historique ;
* filtres.

Le KPI "Stock faible" doit ouvrir correctement la page Stock avec le filtre approprié.

---

## 16. CLIENTS

Les clients doivent être liés aux données réelles.

Ne pas inventer de statistiques.

Les informations doivent provenir de Supabase/API.

---

## 17. EMPLOYÉS

Les employés doivent utiliser les données et l'authentification existantes.

Préserver :

* comptes ;
* permissions ;
* rôles ;
* traçabilité.

---

## 18. RAPPORTS

Les rapports doivent utiliser les données réelles.

Prévoir selon l'architecture :

* ventes journalières ;
* ventes mensuelles ;
* bénéfice ;
* stock ;
* fournisseurs ;
* clients ;
* export ;
* impression.

---

## 19. PLAN 3D

Le Plan 3D est une fonctionnalité importante.

Il doit permettre :

* rotation ;
* zoom ;
* sélection ;
* plein écran ;
* retour ;
* navigation correcte ;
* fermeture des panneaux ;
* interaction avec les éléments ;
* compatibilité navigateur.

Problème connu à corriger :

Une ComboBox/panneau contenant les boutons liés au rangement des médicaments reste actuellement bloquée même lorsqu'on demande sa fermeture.

Les boutons doivent réellement fonctionner.

Le bouton Retour doit fonctionner.

Le bouton Home doit fonctionner.

Le navigateur "Back" doit rester cohérent.

Prévoir un fallback propre si une fonction 3D n'est pas disponible.

NE PAS supprimer le Plan 3D pour résoudre un bug.

---

## 20. ASSISTANT IA

L'Assistant IA doit être fonctionnel.

Il existe déjà une interface/service backend.

Avant de créer quoi que ce soit :

* localiser l'interface existante ;
* localiser le service existant ;
* vérifier la configuration ;
* vérifier le réseau ;
* vérifier les erreurs ;
* réutiliser l'architecture existante.

Ne pas créer un faux chatbot qui répond uniquement avec des réponses codées en dur.

---

## 21. AUTHENTIFICATION

Le flux attendu :

Connexion → authentification → application/dashboard.

La connexion doit fonctionner avec Supabase/Auth existant.

Ne pas créer un faux login.

Les utilisateurs et pharmacies existants doivent être préservés.

---

## 22. PHARMACIE / MULTI-PHARMACIE

L'application doit être conçue pour pouvoir servir plusieurs pharmacies.

Chaque pharmacie doit pouvoir avoir :

* son nom ;
* son logo ;
* ses utilisateurs ;
* ses données ;
* ses paramètres.

Respecter les relations existantes dans Supabase.

Ne pas casser l'isolation des données.

---

## 23. PARAMÈTRES

Les paramètres doivent permettre, lorsque prévu par l'application :

* nom de pharmacie ;
* logo ;
* mot de passe ;
* informations de pharmacie ;
* préférences.

Les modifications doivent être réellement sauvegardées.

---

## 24. RESPONSIVE

Tester au minimum :

* 1366 × 768
* 1536 × 864
* 1536 × 1024
* 1920 × 1080
* tablette
* mobile

L'interface doit rester utilisable.

Le menu mobile/hamburger doit fonctionner.

Le clic extérieur doit fermer les menus lorsqu'il est prévu.

ESC doit fermer les overlays lorsqu'il est prévu.

Aucun footer ou élément fixe ne doit cacher le contenu important.

---

## 25. NAVIGATION

Toutes les routes doivent fonctionner.

Corriger notamment :

* Home ;
* Dashboard ;
* Vente du jour ;
* Catalogue ;
* Médicaments ;
* Fournisseurs ;
* Stock ;
* Plan 3D ;
* Paramètres.

Aucune page ne doit rester bloquée sans possibilité de retour.

Les boutons visibles doivent avoir une action réelle.

---

## 26. RÈGLE CONTRE LES FAUSSES RÉUSSITES

NE PAS déclarer une fonctionnalité "corrigée" uniquement parce que :

* le fichier existe ;
* la route existe ;
* le composant se charge ;
* une fonction est présente.

Une fonctionnalité est considérée comme corrigée uniquement si son comportement réel fonctionne.

Tester les interactions.

---

## 27. TESTS

Après chaque correction importante :

* vérifier le build ;
* vérifier les erreurs console ;
* vérifier les routes ;
* vérifier les appels API ;
* vérifier Supabase ;
* vérifier les données ;
* vérifier les interactions.

Ne pas considérer un simple build réussi comme preuve que l'application fonctionne.

---

## 28. GIT

Avant une modification importante :

* vérifier le statut Git ;
* conserver l'historique ;
* éviter les suppressions massives ;
* créer un commit de sauvegarde lorsque nécessaire.

Ne pas réinitialiser le dépôt.

Ne pas supprimer les branches ou commits existants.

---

## 29. MÉTHODE DE TRAVAIL DE L'AGENT

Avant de modifier :

1. Lire PROJECT_CONTEXT.md.
2. Localiser le code réellement utilisé.
3. Comprendre la route.
4. Comprendre le composant.
5. Comprendre le service/API.
6. Vérifier la connexion aux données.
7. Corriger uniquement ce qui est nécessaire.
8. Tester.
9. Corriger les erreurs générées.
10. Tester à nouveau.

NE PAS supposer que les fichiers ont exactement les noms indiqués dans ce document.

Les noms de fichiers et composants de ce document décrivent les fonctionnalités attendues, pas nécessairement leurs noms physiques.

Toujours rechercher l'implémentation réelle dans le projet.

---

## 30. MODE DE COMMUNICATION

Pendant une tâche :

MODE SILENCIEUX.

Ne pas envoyer de messages intermédiaires répétitifs.

Ne pas demander une confirmation pour chaque petite étape.

Travailler jusqu'à obtenir un résultat vérifié.

Si une décision importante bloque réellement la tâche, demander uniquement la décision nécessaire.

À la fin seulement :

* résumé des corrections ;
* fichiers modifiés ;
* tests effectués ;
* problèmes restant éventuellement.

---

## 31. RÈGLE FINALE

PHARMA+ doit devenir une véritable application de pharmacie professionnelle.

Priorités :

1. Fonctionnalité réelle.
2. Données réelles.
3. Préservation Supabase.
4. Préservation du design validé.
5. Navigation fiable.
6. POS fonctionnel.
7. Stock cohérent.
8. Catalogue et médicaments fonctionnels.
9. Fournisseurs fonctionnels.
10. Plan 3D fonctionnel.
11. Assistant IA fonctionnel.
12. Responsive.
13. Tests réels.

NE JAMAIS sacrifier les données ou le backend existant pour une correction visuelle.

NE JAMAIS remplacer une fonctionnalité réelle par une démo.

NE JAMAIS inventer de données pour masquer une fonctionnalité vide.

FIN DU CONTEXTE PHARMA+
