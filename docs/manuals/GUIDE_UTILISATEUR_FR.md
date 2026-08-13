# Guide de l'utilisateur — PHARMA MAROC GOLD ENTERPRISE V2.0

## 1. Première connexion

1. Ouvrez l'application (mobile, desktop ou web).
2. Saisissez votre **e-mail** et votre **mot de passe** fournis par l'administrateur.
3. Si la **double authentification (2FA)** est activée, saisissez le code à 6 chiffres généré par votre application d'authentification (Google Authenticator, etc.).
4. La page d'accueil s'affiche avec les indicateurs du jour.

> Lors de la première connexion, un changement de mot de passe est obligatoire (`must_change_password`).

---

## 2. Tableau de bord

- **CA du jour**, **nombre de ventes**, **panier moyen**, **stock bas** et **péremptions à venir**.
- Cliquez sur une carte pour accéder au module correspondant.
- La bannière de synchronisation indique l'état de la connexion : `À jour` ou `En attente de synchro` (mode hors ligne).

---

## 3. Ventes au comptoir (POS)

1. Onglet **Ventes** → **Nouvelle vente**.
2. **Scanner** le code-barres (mobile) ou rechercher par nom.
3. Renseignez la **quantité** et, si nécessaire, le **prix unitaire** et le **n° d'ordonnance**.
4. Appliquez une remise éventuelle, sélectionnez le **mode de paiement** (espèces, carte, crédit…).
5. **Valider** : la caisse reçoit le ticket, le stock est mis à jour automatiquement.
6. En l'absence de réseau, la vente est mise en **file d'attente** et synchronisée plus tard.

> Les remboursements nécessitent un **code PIN** (configurable).

---

## 4. Catalogue et stock

- **Médicaments** : fiche avec code-barres (EAN-13), prix, TVA, seuil d'alerte, date de péremption.
- **FEFO** : les articles qui périment le plus tôt sortent en premier.
- **Stock** : historique des mouvements (réception, transfert, réservation, vente). Les réserves sont suivies par lot.
- Alertes automatiques : stock sous le seuil et médicaments expirant sous 90 jours.

---

## 5. Achats et fournisseurs

- **Nouvel achat** : choisissez le fournisseur, ajoutez les articles (prix d'achat, TVA), la facture est enregistrée et le stock réceptionné.
- Le fournisseur conserve son historique : achats, factures, retards de livraison.

---

## 6. Ordonnances et patients

- Saisie d'une **ordonnance** (items + posologie) et **délivrance** progressive.
- L'ordonnance passe automatiquement à l'état `remplie` lorsque tous les items sont délivrés.
- Historique patient (achats, allergies, antécédents) accessible avec les droits adéquats.

---

## 7. Employés et pointage

- **Employés** : fiches, documents (CNI, diplômes), primes, évaluations, synthèse de paie.
- **Pointage** : badgeage d'entrée/sortie, retards calculés par rapport à 09:00, congés, plannings, synthèse mensuelle.

---

## 8. Comptabilité

- **Plan comptable**, **écritures** (équilibrées), **catégories de dépenses**, **dépenses**.
- **Caisse** : ouverture, mouvements, clôture (contrôle des écarts).
- **Balance de vérification** et **clôtures** périodiques.

---

## 9. Notifications

- Tâches et alertes : stock bas, péremptions, événements.
- Marquer comme **lue** ou **tout marquer comme lu**.

---

## 10. Paramètres

- Profil, changement de mot de passe, langue de l'interface (**FR / AR / EN**).
- Personnalisation de la pharmacie (logo, couleurs, coordonnées, devise).
- Gestion des utilisateurs et des rôles (pour l'administrateur).

---

## 11. Mode hors ligne

L'application enregistre les ventes localement et les **synchronise** dès que la connexion revient. L'état de synchronisation est affiché en permanence.

---

## 12. Aide et support

- Depuis **Aide** : créer un **ticket**, suivre sa progression et échanger avec l'équipe support.
- Consultez ce guide ou contactez votre administrateur pour toute question.
