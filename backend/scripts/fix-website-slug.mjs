// Rend slug nullable sur website_settings (ancien schema) pour que le
// service bundle puisse INSERT INTO website_settings (pharmacy_id) ...
import 'dotenv/config';
import pg from 'pg';

const url = (process.env.DATABASE_URL || '').replace(/[?&]sslmode=[^&]*/g, '');
const p = new pg.Pool({ connectionString: url, ssl: { rejectUnauthorized: false } });

await p.query(`ALTER TABLE website_settings ALTER COLUMN slug DROP NOT NULL`);
console.log('website_settings.slug : NOT NULL retire.');

// Verification du flux GET du service (select + insert auto)
try {
  await p.query(
    `INSERT INTO website_settings (pharmacy_id) VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
     ON CONFLICT (pharmacy_id) DO NOTHING`,
  );
  const r = await p.query(
    `SELECT pharmacy_id, slug, hero_title FROM website_settings
      WHERE pharmacy_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'`,
  );
  console.log('Ligne settings:', JSON.stringify(r.rows));
} catch (e) {
  console.log('KO:', e.code, e.message);
}
await p.end();
