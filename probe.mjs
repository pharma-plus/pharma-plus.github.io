import { query } from './backend/src/db/pool.js';
const pharm = '11111111-1111-1111-1111-111111111111';
await query("SELECT set_config('app.pharmacy_id', $1, true)", [pharm]);
const q = `SELECT m.id, COALESCE(sb.stock_available, 0) AS stock_available
  FROM medications m
  LEFT JOIN (
    SELECT medication_id, COALESCE(sum(quantity - reserved_quantity), 0) AS stock_available
      FROM stock_balances GROUP BY medication_id
  ) sb ON sb.medication_id = m.id
 WHERE m.pharmacy_id = $1
 ORDER BY m.name
 LIMIT $2 OFFSET $3`;
try { const r = await query(q, [pharm, 20, 0]); console.log('OK rows', r.rows.length); } catch (e) { console.log('ERR', e.code, e.position, '|', JSON.stringify(q.slice(0, 90))); }
process.exit(0);
