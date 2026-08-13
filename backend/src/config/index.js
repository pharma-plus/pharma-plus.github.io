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
    secret: process.env.JWT_SECRET || 'insecure-dev-secret',
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
    encryptionKey: process.env.BACKUP_ENCRYPTION_KEY || 'insecure-backup-key',
  },
  corsOrigins: (process.env.CORS_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean),
  superAdmin: {
    email: process.env.SUPER_ADMIN_EMAIL || 'admin@pharmamarocgold.com',
    password: process.env.SUPER_ADMIN_PASSWORD || 'ChangeMe_123!',
  },
};
