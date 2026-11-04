import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { AppError } from '../../utils/errors.js';
import { reportsService } from './service.js';

const router = Router();
router.use(requireAuth);

const periodSchema = Joi.object({
  branchId: Joi.string().uuid().allow(null),
  from: Joi.date().iso().required(),
  to: Joi.date().iso().required(),
  groupBy: Joi.string().valid('day', 'week', 'month'),
  limit: Joi.number().integer().min(1).max(1000),
});

router.get('/sales', requirePerm('reports:view'), validate({ query: periodSchema }),
  wrap(async (req, res) => {
    const rows = await reportsService.salesReport(req.user.pharmacyId, req.query);
    return ok(res, rows);
  }));

router.get('/products', requirePerm('reports:view'), validate({ query: periodSchema }),
  wrap(async (req, res) => {
    const rows = await reportsService.productReport(req.user.pharmacyId, req.query);
    return ok(res, rows);
  }));

router.get('/stock', requirePerm('reports:view'), validate({
  query: Joi.object({ branchId: Joi.string().uuid().allow(null) }),
}), wrap(async (req, res) => {
  const data = await reportsService.stockReport(req.user.pharmacyId, req.query);
  return ok(res, data);
}));

router.get('/financial', requirePerm('accounting:view'), validate({ query: periodSchema }),
  wrap(async (req, res) => {
    const data = await reportsService.financialReport(req.user.pharmacyId, req.query);
    return ok(res, data);
  }));

router.get('/employees', requirePerm('reports:view'), validate({ query: periodSchema }),
  wrap(async (req, res) => {
    const rows = await reportsService.employeeReport(req.user.pharmacyId, req.query);
    return ok(res, rows);
  }));

// ── GET /reports/:type/export ── (export CSV pour Excel)
router.get(
  '/:type/export',
  requirePerm('reports:view'),
  validate({ params: Joi.object({ type: Joi.string().valid('sales', 'products', 'stock', 'financial', 'employees') }) }),
  wrap(async (req, res) => {
    const { type } = req.params;
    const pharmacyId = req.user.pharmacyId;
    const queryParams = { ...req.query, branchId: req.query.branchId, from: req.query.from, to: req.query.to, groupBy: req.query.groupBy };

    let rows;
    let headers;
    let filename;

    switch (type) {
      case 'sales':
        rows = await reportsService.salesReport(pharmacyId, queryParams);
        headers = ['Période', 'Nb ventes', 'Sous-total', 'Remises', 'Taxes', 'Total', 'Profit'];
        filename = `rapport_ventes_${queryParams.from}_${queryParams.to}.csv`;
        break;
      case 'products':
        rows = await reportsService.productReport(pharmacyId, queryParams);
        headers = ['Produit', 'DCI', 'Catégorie', 'Qté vendue', 'Revenu', 'Coût', 'Profit', 'Prix moyen'];
        filename = `rapport_produits_${queryParams.from}_${queryParams.to}.csv`;
        break;
      case 'stock':
        rows = await reportsService.stockReport(pharmacyId, queryParams);
        headers = ['Produit', 'Stock', 'Valeur', 'Coût'];
        filename = `rapport_stock_${Date.now()}.csv`;
        break;
      case 'financial':
        rows = await reportsService.financialReport(pharmacyId, queryParams);
        headers = ['Période', 'Revenu', 'Dépenses', 'Profit'];
        filename = `rapport_financier_${queryParams.from}_${queryParams.to}.csv`;
        break;
      case 'employees':
        rows = await reportsService.employeeReport(pharmacyId, queryParams);
        headers = ['Employé', 'Ventes', 'Heures', 'Présences'];
        filename = `rapport_employes_${queryParams.from}_${queryParams.to}.csv`;
        break;
      default:
        throw new AppError('Type de rapport invalide', 400, 'INVALID_REPORT_TYPE');
    }

    // Construire le CSV
    const csvLines = [headers.join(';')];
    for (const row of rows) {
      const values = headers.map(h => {
        const key = h.toLowerCase().replace(/ /g, '_');
        const v = row[key] ?? row[Object.keys(row)[headers.indexOf(h)]] ?? '';
        return String(v).replace(/;/g, ',').replace(/\n/g, ' ');
      });
      csvLines.push(values.join(';'));
    }

    const csvContent = csvLines.join('\n');

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(csvContent);
  })
);

export const reportsRouter = router;
