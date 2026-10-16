import 'dotenv/config';

const bool = (v, def = false) => (v === undefined ? def : String(v).toLowerCase() === 'true');
const int = (v, def) => {
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? n : def;
};

export const config = {
  env: process.env.NODE_ENV || 'development',
  isProd: process.env.NODE_ENV === 'production',
  port: int(process.env.PORT, 4000),
  apiVersion: process.env.API_VERSION || 'v1',
  databaseUrl: process.env.DATABASE_URL,
  jwt: {
    secret: (() => { const s = process.env.JWT_SECRET; if (!s) throw new Error('JWT_SECRET environment variable is required'); return s; })(),
    accessTtl: process.env.JWT_ACCESS_TTL || '15m',
    refreshTtl: process.env.JWT_REFRESH_TTL || '30d',
    issuer: 'pharma-maroc-gold',
  },
  security: {
    maxLoginAttempts: int(process.env.MAX_LOGIN_ATTEMPTS, 5),
    lockoutMinutes: int(process.env.LOCKOUT_MINUTES, 15),
    sessionInactivityMinutes: int(process.env.SESSION_INACTIVITY_MINUTES, 120),
  },
  otp: {
    issuer: process.env.OTP_ISSUER || 'Pharma Maroc Gold',
  },
  storage: {
    driver: process.env.STORAGE_DRIVER || 'local',
    localDir: process.env.STORAGE_LOCAL_DIR || './storage',
    s3: {
      endpoint: process.env.S3_ENDPOINT,
      bucket: process.env.S3_BUCKET,
      region: process.env.S3_REGION,
      accessKey: process.env.S3_ACCESS_KEY,
      secretKey: process.env.S3_SECRET_KEY,
    },
  },
  backup: {
    dir: process.env.BACKUP_DIR || './backups',
    // Clé de chiffrement OBLIGATOIRE : aucune valeur par défaut (prompt
    // sécurité §4 — l'ancien repli codé en dur a été supprimé).
    // Local : renseignée dans .env (non tracké). Production : dashboard
    // Render / secrets GitHub. Démarrage refusé si absente.
    encryptionKey: (() => {
      const k = process.env.BACKUP_ENCRYPTION_KEY;
      if (!k) throw new Error('BACKUP_ENCRYPTION_KEY environment variable is required (aucune valeur par défaut)');
      return k;
    })(),
  },
  corsOrigins: (process.env.CORS_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean),
  // superAdmin supprimé : plus aucun email/mot de passe de secours (§4).
};
