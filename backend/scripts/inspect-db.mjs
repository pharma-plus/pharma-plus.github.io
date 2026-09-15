import 'dotenv/config';
import { pool } from '../src/db/pool.js';

const leak = await pool.query(`
  SELECT (SELECT count(*)::int FROM suppliers WHERE name LIKE 'TEST-%') AS suppliers,
         (SELECT count(*)::int FROM medications WHERE name LIKE 'TEST-%') AS medications,
         (SELECT count(*)::int FROM purchase_receptions) AS receptions,
         (SELECT count(*)::int FROM purchase_reception_items) AS reception_items
`);
console.log('FUITES:', JSON.stringify(leak.rows[0]));

const def = await pool.query("SELECT pg_get_functiondef('fn_next_number(uuid,text)'::regprocedure) AS d");
console.log('FN_NEXT_NUMBER:', def.rows[0].d.slice(0, 600));

await pool.end();
