// Ajoute la contrainte UNIQUE(pharmacy_id) manquante sur website_settings
// (le service backend fait INSERT ... ON CONFLICT (pharmacy_id)).
import 'dotenv/config';
import pg from 'pg';

const url = (process.env.DATABASE_URL || '').replace(/[?&]sslmode=[^&]*/g, '');
const p = new pg.Pool({ connectionString: url, ssl: { rejectUnauthorized: false } });

// 1. Dedoublonnage eventuel (on garde la ligne la plus recente par pharmacie)
const dup = await p.query(
  `DELETE FROM website_settings a
    USING website_settings b
    WHERE a.pharmacy_id = b.pharmacy_id
      AND a.updated_at < b.updated_at`,
);
console.log(`Doublons supprimes: ${dup.rowCount}`);

// 2. Contrainte UNIQUE si absente
const has = await p.query(
  `SELECT 1 FROM pg_constraint
    WHERE conrelid = 'website_settings'::regclass AND contype = 'u'
      AND conkey @> ARRAY[
        (SELECT attnum::smallint FROM pg_attribute
          WHERE attrelid = 'website_settings'::regclass AND attname = 'pharmacy_id')]`,
);
if (has.rowCount === 0) {
  await p.query(
    `ALTER TABLE website_settings
       ADD CONSTRAINT website_settings_pharmacy_id_uniq UNIQUE (pharmacy_id)`,
  );
  console.log('Contrainte UNIQUE(pharmacy_id) ajoutee.');
} else {
  console.log('Contrainte UNIQUE(pharmacy_id) deja presente.');
}

// 3. Verification
const ok = await p.query(
  `INSERT INTO website_settings (pharmacy_id) VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
   ON CONFLICT (pharmacy_id) DO NOTHING RETURNING pharmacy_id`,
);
console.log(`Test ON CONFLICT : OK (insere: ${ok.rowCount})`);
await p.end();
