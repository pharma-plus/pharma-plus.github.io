import 'dotenv/config';
import { pool } from '../src/db/pool.js';

const table = process.argv[2] || 'sale_items';
const { rows } = await pool.query(
  "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = $1 ORDER BY ordinal_position",
  [table],
);
console.log(table, '=>', rows.map((r) => `${r.column_name}:${r.data_type}`).join(', '));
await pool.end();
