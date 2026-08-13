# Déploiement — PHARMA MAROC GOLD ENTERPRISE V2.0

Guide de mise en production de la plateforme **multi-tenant** : API Node.js/Express, PostgreSQL, application Flutter et portail Super Admin.

---

## 1. Prérequis

| Composant | Version minimale | Notes |
|-----------|------------------|-------|
| Node.js   | 20+ (testé sur 24) | ESM (`"type": "module"`) |
| PostgreSQL| 14+ | Extensions `pgcrypto`, `uuid-ossp` (installées par la migration 001) |
| Flutter   | 3.27+ (pour compiler l'app) | Mobile, desktop, web, PWA |
| Nginx / Caddy | stable | Reverse proxy + TLS |

---

## 2. Base de données

### 2.1 Création des rôles et de la base

```sql
CREATE ROLE pmg WITH LOGIN PASSWORD 'choisir-un-mot-de-passe-fort';
CREATE DATABASE pharma_maroc_gold OWNER pmg;
```

### 2.2 Fichier d'environnement

Créer `backend/.env` (jamais committé) :

```ini
NODE_ENV=production
PORT=4000
API_VERSION=v1

DATABASE_URL=postgres://pmg:mot-de-passe@localhost:5432/pharma_maroc_gold

JWT_SECRET=generer-avec-openssl-rand-hex-64
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=30d

# Sécurité
MAX_LOGIN_ATTEMPTS=5
LOCKOUT_MINUTES=15
SESSION_INACTIVITY_MINUTES=120

# Super Admin (identifiants créés au seed)
SUPER_ADMIN_EMAIL=superadmin@pharmamarocgold.com
SUPER_ADMIN_PASSWORD=ChoisirUnMotDePasseFort_123!

# Stockage (local par défaut)
STORAGE_DRIVER=local
STORAGE_LOCAL_DIR=./storage

# Backups
BACKUP_DIR=./backups
BACKUP_ENCRYPTION_KEY=generer-une-cle-aes-256

# CORS (origines de l'app web/PWA, séparées par des virgules)
CORS_ORIGINS=https://app.pharmamarocgold.com,https://admin.pharmamarocgold.com
```

Génération des secrets :

```bash
openssl rand -hex 64   # JWT_SECRET
openssl rand -hex 32   # BACKUP_ENCRYPTION_KEY
```

### 2.3 Migration et seed

```bash
cd backend
npm.cmd install --no-audit --no-fund   # ou npm install sur Linux
npm.cmd run db:migrate                 # applique database/schema/001..012
npm.cmd run db:seed                    # super admin + rôle/perm système + pharmacie démo
```

Le seed crée :

- **Super Admin** : les identifiants issus de `SUPER_ADMIN_EMAIL` / `SUPER_ADMIN_PASSWORD`.
- **Pharmacie démo** : `admin@demo.ma` / `Demo123!` (à supprimer en production).
- **Rôles système** (`super_admin`, `pharmacy_admin`, `pharmacist`, `cashier`, `stock_manager`, `accountant`, `technician`) avec permissions — ils seront clonés par pharmacie à chaque provisionnement.

Vérification :

```bash
npm.cmd start
curl http://localhost:4000/api/v1/health
```

---

## 3. Service / daemon

### 3.1 Linux (systemd)

Fichier `/etc/systemd/system/pharma-maroc-gold.service` :

```ini
[Unit]
Description=Pharma Maroc Gold API
After=network.target postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/pharma-maroc-gold/backend
EnvironmentFile=/opt/pharma-maroc-gold/backend/.env
ExecStart=/usr/bin/node src/server.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now pharma-maroc-gold
sudo systemctl status pharma-maroc-gold
```

### 3.2 Windows Server (NSSM)

```powershell
nssm install PharmaMarocGold "C:\Program Files\nodejs\node.exe" "C:\pharma-maroc-gold\backend\src\server.js"
nssm set PharmaMarocGold AppDirectory "C:\pharma-maroc-gold\backend"
nssm set PharmaMarocGold AppEnvironmentExtra NODE_ENV=production
nssm start PharmaMarocGold
```

---

## 4. Reverse proxy + TLS

### 4.1 Nginx

```nginx
server {
    listen 443 ssl http2;
    server_name api.pharmamarocgold.com;

    ssl_certificate     /etc/letsencrypt/live/api.pharmamarocgold.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.pharmamarocgold.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:4000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 4.2 Portail Super Admin

Servir `portal/` (statique) sur `admin.pharmamarocgold.com` et configurer l'API :
`const API = 'https://api.pharmamarocgold.com/api/v1';` en tête de `portal/index.html`.

### 4.3 App Flutter

Compiler la PWA/web :

```bash
cd frontend
flutter build web --dart-define=API_URL=https://api.pharmamarocgold.com/api/v1
```

Servir `frontend/build/web/` sur `app.pharmamarocgold.com`.

---

## 5. Sauvegardes

- **PG dumps planifiés** (cron) :

```cron
0 2 * * * pg_dump "postgres://pmg:...@localhost/pharma_maroc_gold" -Fc -f /var/backups/pmg/$(date +\%F).dump
0 3 * * * find /var/backups/pmg -name "*.dump" -mtime +30 -delete
```

- **Sauvegardes applicatives** : l'API expose `POST /backups` (Super Admin / pharmacie) — dumps chiffrés AES-256 stockés dans `BACKUP_DIR` + téléversement S3 optionnel (`S3_BUCKET`).

---

## 6. Sécurité (liste de contrôle)

- [ ] `JWT_SECRET`, `BACKUP_ENCRYPTION_KEY` uniques et aléatoires
- [ ] `SUPER_ADMIN_PASSWORD` fort, comptes démo (`admin@demo.ma`) supprimés
- [ ] TLS en vigueur ; HSTS activé (helmet) ; `CORS_ORIGINS` restreint
- [ ] Accès Postgres limité au rôle `pmg` (pas de superutilisateur)
- [ ] 2FA activé pour les comptes administrateurs (QR OTP à l'inscription)
- [ ] Audits journalisés (`audit_logs`) et revue périodique
- [ ] Sauvegardes testées par restauration au moins mensuellement

---

## 7. Surveillance

- `GET /api/v1/health` → uptime, version, état de la connexion PostgreSQL
- `GET /api/v1/dashboard` → KPIs temps réel (CA, ventes, stock bas, péremptions)
- Logs applicatifs via morgan (accès) + erreurs JSON centralisées

---

## 8. Démarrage rapide (développement)

```bash
# Terminal 1 — base de données (Docker ou Postgres local)
docker run -d --name pmg-db -p 5432:5432 -e POSTGRES_PASSWORD=dev -e POSTGRES_DB=pharma_maroc_gold postgres:16

# Terminal 2 — API
cd backend
cp .env.example .env        # adapter DATABASE_URL
npm.cmd install --no-audit --no-fund
npm.cmd run db:migrate
npm.cmd run db:seed
npm.cmd run dev

# Tests
npm.cmd test
```
