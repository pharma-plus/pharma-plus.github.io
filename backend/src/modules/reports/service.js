import { query } from '../../db/pool.js';

export const reportsService = {
  /** Rapport de ventes par période (journalier/hebdo/mensuel). */
  async salesReport(pharmacyId, { branchId, from, to, groupBy = 'day' }) {
    const params = [pharmacyId, from, to];
    let i = 4;
    let branchFilter = '';
    if (branchId) { params.push(branchId); branchFilter = `AND branch_id = $${i}`; i++; }
    const clause = {
      day: 'date_trunc(\'day\', created_at)',
      week: 'date_trunc(\'week\', created_at)',
      month: 'date_trunc(\'month\', created_at)',
    }[groupBy] || 'date_trunc(\'day\', created_at)';

    const { rows } = await query(
      `SELECT ${clause} AS period,
              count(*) AS nb_sales,
              sum(subtotal)::numeric(14,2) AS subtotal,
              sum(discount_total)::numeric(14,2) AS discounts,
              sum(tax_total)::numeric(14,2) AS taxes,
              sum(total)::numeric(14,2) AS total,
              sum(total - cost_total)::numeric(14,2) AS profit
         FROM sales
        WHERE pharmacy_id = $1 AND status = 'completed'
          AND created_at >= $2 AND created_at < $3 ${branchFilter}
        GROUP BY ${clause}
        ORDER BY ${clause}`,
      params,
    );
    return rows;
  },

  /** Performance des produits (ventes par médicament). */
  async productReport(pharmacyId, { branchId, from, to, limit = 100 }) {
    const params = [pharmacyId, from, to];
    let i = 4;
    let branchFilter = '';
    if (branchId) { params.push(branchId); branchFilter = `AND s.branch_id = $${i}`; i++; }
    const { rows } = await query(
      `SELECT m.id, m.name, m.dci, m.category_id, c.name AS category_name,
              sum(si.quantity)::numeric(12,3) AS qty_sold,
              sum(si.line_total)::numeric(14,2) AS revenue,
              sum(si.quantity * si.cost_price)::numeric(14,2) AS cost,
              (sum(si.line_total) - sum(si.quantity * si.cost_price))::numeric(14,2) AS profit,
              sum(si.line_total) / NULLIF(sum(si.quantity), 0)::numeric(10,2) AS avg_price
         FROM sale_items si
         JOIN sales s ON s.id = si.sale_id AND s.status = 'completed'
         JOIN medications m ON m.id = si.medication_id
         LEFT JOIN categories c ON c.id = m.category_id
        WHERE s.pharmacy_id = $1 AND s.created_at >= $2 AND s.created_at < $3 ${branchFilter}
        GROUP BY m.id, m.name, m.dci, m.category_id, c.name
        ORDER BY qty_sold DESC
        LIMIT $${i}`,
      [...params, limit],
    );
    return rows;
  },

  /** Rapport de stock : valeur, ruptures, péremptions. */
  async stockReport(pharmacyId, { branchId }) {
    const params = [pharmacyId];
    let i = 2;
    let branchFilter = '';
    if (branchId) { params.push(branchId); branchFilter = `AND sb.branch_id = $${i}`; i++; }
    const [value, low, expiring, expired] = await Promise.all([
      query(
        `SELECT COALESCE(sum(sb.quantity * l.cost_price), 0)::numeric(14,2) AS stock_cost,
                COALESCE(sum(sb.quantity * m.price_sale), 0)::numeric(14,2) AS stock_value,
                count(DISTINCT sb.medication_id)::int AS nb_products
           FROM stock_balances sb
           JOIN medications m ON m.id = sb.medication_id
           LEFT JOIN lots l ON l.id = sb.lot_id
          WHERE sb.pharmacy_id = $1 ${branchFilter}`, params),
      query(
        `SELECT count(*)::int AS nb FROM medications m
           WHERE m.pharmacy_id = $1 AND m.status = 'available'
             AND COALESCE((SELECT sum(sb.quantity - sb.reserved_quantity) FROM stock_balances sb
                            WHERE sb.medication_id = m.id ${branchFilter.replace('sb.', 'sb.')}), 0) <= m.reorder_level`,
        params),
      query(
        `SELECT count(*)::int AS nb FROM lots l
           JOIN stock_balances sb ON sb.lot_id = l.id AND sb.quantity > 0
          WHERE l.pharmacy_id = $1 AND l.expiry_date >= CURRENT_DATE
            AND l.expiry_date <= CURRENT_DATE + 90 ${branchFilter.replace('sb.', 'sb.')}`, params),
      query(
        `SELECT count(*)::int AS nb FROM lots l
           JOIN stock_balances sb ON sb.lot_id = l.id AND sb.quantity > 0
          WHERE l.pharmacy_id = $1 AND l.expiry_date < CURRENT_DATE ${branchFilter.replace('sb.', 'sb.')}`, params),
    ]);
    return { value: value.rows[0], low_stock: low.rows[0].nb, expiring: expiring.rows[0].nb, expired: expired.rows[0].nb };
  },

  /** Rapport financier : recettes, dépenses, TVA, créances/dettes. */
  async financialReport(pharmacyId, { branchId, from, to }) {
    const params = [pharmacyId, from, to];
    let i = 4;
    let branchFilter = '';
    if (branchId) { params.push(branchId); branchFilter = `AND branch_id = $${i}`; i++; }

    const [revenue, expenses, receivables, payables, tva] = await Promise.all([
      query(
        `SELECT COALESCE(sum(total),0)::numeric(14,2) AS revenue,
                COALESCE(sum(tax_total),0)::numeric(14,2) AS tva_collected,
                COALESCE(sum(total - cost_total),0)::numeric(14,2) AS gross_profit
           FROM sales WHERE pharmacy_id = $1 AND status = 'completed'
             AND created_at >= $2 AND created_at < $3 ${branchFilter}`, params),
      query(
        `SELECT COALESCE(sum(amount),0)::numeric(14,2) AS total
           FROM expenses WHERE pharmacy_id = $1
             AND expense_date >= $2::date AND expense_date < $3::date ${branchFilter}`, params),
      query(
        `SELECT COALESCE(sum(credit_balance),0)::numeric(14,2) AS total FROM customers
          WHERE pharmacy_id = $1 AND credit_balance > 0`, [pharmacyId]),
      query(
        `SELECT COALESCE(sum(inv.total - inv.paid_amount),0)::numeric(14,2) AS total
           FROM invoices inv WHERE inv.pharmacy_id = $1 AND inv.status IN ('unpaid','partial')`, [pharmacyId]),
      query(
        `SELECT COALESCE(sum(tax_total),0)::numeric(14,2) AS tva_sales,
                COALESCE((SELECT sum(tax_total) FROM purchase_orders
                           WHERE pharmacy_id = $1 AND status IN ('received','partial')
                             AND received_date >= $2::date AND received_date < $3::date), 0)::numeric(14,2) AS tva_purchases
           FROM sales WHERE pharmacy_id = $1 AND status = 'completed'
             AND created_at >= $2 AND created_at < $3 ${branchFilter}`, params),
    ]);

    return {
      revenue: revenue.rows[0],
      expenses: expenses.rows[0].total,
      net_profit: (Number(revenue.rows[0].gross_profit) - Number(expenses.rows[0].total)),
      receivables: receivables.rows[0].total,
      payables: payables.rows[0].total,
      tva: tva.rows[0],
    };
  },

  /** Performance des employés (ventes par vendeur). */
  async employeeReport(pharmacyId, { branchId, from, to }) {
    const params = [pharmacyId, from, to];
    let i = 4;
    let branchFilter = '';
    if (branchId) { params.push(branchId); branchFilter = `AND s.branch_id = $${i}`; i++; }
    const { rows } = await query(
      `SELECT u.id, u.first_name, u.last_name,
              count(s.id)::int AS nb_sales,
              COALESCE(sum(s.total),0)::numeric(14,2) AS revenue,
              COALESCE(sum(s.total - s.cost_total),0)::numeric(14,2) AS profit
         FROM sales s JOIN users u ON u.id = s.user_id
        WHERE s.pharmacy_id = $1 AND s.status = 'completed'
          AND s.created_at >= $2 AND s.created_at < $3 ${branchFilter}
        GROUP BY u.id, u.first_name, u.last_name
        ORDER BY revenue DESC`,
      params,
    );
    return rows;
  },
};
