import { Client } from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const raw = process.env.DATABASE_URL.replace(/[?&]sslmode=[^&]*/g, '');
const c = new Client({ connectionString: raw, ssl: { rejectUnauthorized: false } });
await c.connect();
const pid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

const { rows: es } = await c.query(
  `SELECT status, COUNT(*) FROM employees WHERE pharmacy_id = $1 GROUP BY status`, [pid]);
console.log("employees status:", JSON.stringify(es));

const { rows: ucols } = await c.query(
  `SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='users' AND column_name LIKE '%employee%'`);
console.log("users.employee* cols:", JSON.stringify(ucols));

const { rows: ecols } = await c.query(
  `SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='employees' AND column_name IN ('user_id','status','archived_at')`);
console.log("employees link/cols:", JSON.stringify(ecols));

const { rows: links } = await c.query(
  `SELECT e.id, e.first_name, e.last_name, e.status, e.user_id, u.email FROM employees e LEFT JOIN users u ON u.id = e.user_id WHERE e.pharmacy_id = $1`, [pid]);
console.log("employee→user links:", JSON.stringify(links, null, 1));

await c.end();
