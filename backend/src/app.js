import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import { config } from './config/index.js';
import { errorHandler, notFound } from './middleware/error.js';
import { healthRouter } from './core/health/index.js';
import { authRouter } from './core/auth/index.js';
import { usersRouter } from './core/users/index.js';
import { rolesRouter } from './core/roles/index.js';
import { pharmaciesRouter } from './core/pharmacies/index.js';
import { branchesRouter } from './core/branches/index.js';
import { licensesRouter } from './core/licenses/index.js';
import { auditRouter } from './core/audit/index.js';
import { catalogRouter } from './modules/catalog/index.js';
import { stockRouter } from './modules/stock/index.js';
import { salesRouter } from './modules/sales/index.js';
import { purchasesRouter } from './modules/purchases/index.js';
import { suppliersRouter } from './modules/suppliers/index.js';
import { customersRouter } from './modules/customers/index.js';
import { dashboardRouter } from './modules/dashboard/index.js';
import { reportsRouter } from './modules/reports/index.js';
import { prescriptionsRouter } from './modules/prescriptions/index.js';
import { employeesRouter } from './modules/employees/index.js';
import { attendanceRouter } from './modules/attendance/index.js';
import { accountingRouter } from './modules/accounting/index.js';
import { notificationsRouter } from './modules/notifications/index.js';
import { backupsRouter } from './modules/backups/index.js';
import { syncRouter } from './modules/sync/index.js';
import { supportRouter } from './modules/support/index.js';
import { websiteRouter, websitePublicRouter } from './modules/website/index.js';
import { aiRouter } from './modules/ai/index.js';
import { referenceRouter } from './modules/reference/index.js';
import { camerasRouter } from './modules/cameras/index.js';

export function createApp() {
  const app = express();

  app.set('trust proxy', 1);
  app.use(helmet({
    contentSecurityPolicy: false, // géré par les SPA/PWA
    crossOriginEmbedderPolicy: false,
  }));
  app.use(cors({
    origin: config.corsOrigins.length ? config.corsOrigins : '*',
    credentials: true,
  }));
  app.use(express.json({ limit: '2mb' }));
  app.use(express.urlencoded({ extended: true }));
  app.use(morgan(config.isProd ? 'combined' : 'dev'));

  const api = express.Router();
  api.use('/health', healthRouter);
  api.use('/auth', authRouter);
  api.use('/users', usersRouter);
  api.use('/roles', rolesRouter);
  api.use('/pharmacies', pharmaciesRouter);
  api.use('/branches', branchesRouter);
  api.use('/licenses', licensesRouter);
  api.use('/audit', auditRouter);
  api.use('/catalog', catalogRouter);
  api.use('/stock', stockRouter);
  api.use('/sales', salesRouter);
  api.use('/purchases', purchasesRouter);
  api.use('/suppliers', suppliersRouter);
  api.use('/customers', customersRouter);
  api.use('/dashboard', dashboardRouter);
  api.use('/reports', reportsRouter);
  api.use('/prescriptions', prescriptionsRouter);
  api.use('/employees', employeesRouter);
  api.use('/attendance', attendanceRouter);
  api.use('/accounting', accountingRouter);
  api.use('/notifications', notificationsRouter);
  api.use('/backups', backupsRouter);
  api.use('/sync', syncRouter);
  api.use('/support', supportRouter);
  api.use('/website', websiteRouter);
  api.use('/ai', aiRouter);
  api.use('/reference', referenceRouter);
  api.use('/cameras', camerasRouter);

  app.use(`/api/${config.apiVersion}`, api);

  // Site public de chaque pharmacie (sans authentification)
  app.use('/public/website', websitePublicRouter);

  app.get('/', (_req, res) => {
    res.json({
      name: 'PHARMA MAROC GOLD ENTERPRISE API',
      version: '2.0.0',
      docs: '/api-docs (à venir)',
      health: `/api/${config.apiVersion}/health`,
    });
  });

  app.use(notFound);
  app.use(errorHandler);

  return app;
}
