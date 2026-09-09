-- ============================================================
-- 930 — BASE DE RÉFÉRENCE MÉDICAMENTS MAROC (§19-20)
-- ============================================================
-- Tables de référence pour l'import CONTRÔLÉ des médicaments
-- commercialisés au Maroc (snapshot officiel fourni) et des
-- fournisseurs/laboratoires.
--
-- GARANTIES (règle §29 — non-négociable) :
--  · AUCUNE table existante n'est modifiée ou supprimée ;
--  · AUCUNE donnée de production n'est touchée ;
--  · Migration IDEMPOTENTE : migrate.js ré-exécute tous les
--    fichiers SQL — chaque instruction est ré-exécutable
--    (IF NOT EXISTS / WHERE NOT EXISTS) ;
--  · Les id des produits et des runs sont générés côté
--    service (uuid applicatif) → aucun default uuid requis,
--    donc aucune extension à créer.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Catégories thérapeutiques de référence
--    (codes repris du snapshot ; libellés = classes ATC usuelles)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reference_categories (
    code        text PRIMARY KEY,
    name_fr     text NOT NULL,
    name_ar     text,
    name_en     text,
    icon        text,
    color       text,
    sort_order  integer NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- 2. Produits de référence (médicaments commercialisés au Maroc)
--    Colonnes = contrat exact du module backend/reference.
--    Prix en MAD : ppv (prix public TTC), ph (prix hôpital),
--    pfht (prix factory HT).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reference_products (
    id                 uuid PRIMARY KEY,
    category_code      text REFERENCES reference_categories(code),
    name               text NOT NULL,
    dci                text,
    substance_active   text,
    dosage             text,
    form               text,
    presentation       text,
    laboratory         text,
    therapeutic_class  text,
    commercial_status  text,
    amm_number         text,
    code_produit       text,
    barcode_ean13      text UNIQUE,
    qr_code            text,
    ppv                numeric(12,2),
    ph                 numeric(12,2),
    pfht               numeric(12,2),
    tva_rate           numeric(5,2),
    rcp_url            text,
    notice_url         text,
    source             text NOT NULL,
    source_updated_at  timestamptz,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- 3. Historique des synchronisations (journal d'audit)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reference_sync_runs (
    id                   uuid PRIMARY KEY,
    source               text NOT NULL,
    status               text NOT NULL DEFAULT 'running'
                         CHECK (status IN ('running','completed','failed')),
    started_at           timestamptz NOT NULL DEFAULT now(),
    finished_at          timestamptz,
    new_count            integer NOT NULL DEFAULT 0,
    modified_count       integer NOT NULL DEFAULT 0,
    price_changed_count  integer NOT NULL DEFAULT 0,
    status_changed_count integer NOT NULL DEFAULT 0,
    removed_count        integer NOT NULL DEFAULT 0,
    notes                text
);

-- ------------------------------------------------------------
-- 4. Journal des modifications par produit (prix / statut / retrait)
--    Aucune suppression de produit : les retraits sont
--    journalisés uniquement (règle §20 — ne pas écraser).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reference_product_updates (
    id           bigserial PRIMARY KEY,
    sync_run_id  uuid REFERENCES reference_sync_runs(id) ON DELETE CASCADE,
    product_id   uuid REFERENCES reference_products(id) ON DELETE SET NULL,
    barcode      text,
    name         text,
    change_type  text NOT NULL
                 CHECK (change_type IN ('new','modified','price_changed',
                                        'status_changed','removed')),
    fields       jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at   timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- 5. Index de performance (recherche POS + synchronisation)
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_ref_products_category
    ON reference_products (category_code);
CREATE INDEX IF NOT EXISTS idx_ref_products_laboratory
    ON reference_products (laboratory);
CREATE INDEX IF NOT EXISTS idx_ref_products_source
    ON reference_products (source);
CREATE INDEX IF NOT EXISTS idx_ref_products_name_lower
    ON reference_products (lower(name));
CREATE INDEX IF NOT EXISTS idx_ref_products_status
    ON reference_products (commercial_status);
CREATE INDEX IF NOT EXISTS idx_ref_updates_created
    ON reference_product_updates (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ref_updates_run
    ON reference_product_updates (sync_run_id);
CREATE INDEX IF NOT EXISTS idx_ref_sync_runs_started
    ON reference_sync_runs (started_at DESC);

-- ------------------------------------------------------------
-- 6. Seed des 15 catégories thérapeutiques du snapshot
--    (classes ATC usuelles — nomenclature standard, DO NOTHING
--    pour l'idempotence, aucun écrasement de données §29).
-- ------------------------------------------------------------
INSERT INTO reference_categories (code, name_fr, name_ar, name_en, icon, color, sort_order) VALUES
    ('ANALG',   'Analgésiques et antipyrétiques',        'مسكنات وخوافض الحرارة',       'Analgesics',            'healing',           '#43D97C', 1),
    ('INFECT',  'Anti-infectieux (antibiotiques...)',    'مضادات العدوى',               'Anti-infectives',       'medication_liquid', '#43D97C', 2),
    ('GASTRO',  'Gastro-entérologie',                    'الجهاز الهضمي',               'Gastroenterology',      'medication',        '#43D97C', 3),
    ('CARDIO',  'Cardiologie et hypertension',           'القلب وضغط الدم',             'Cardiovascular',        'monitor_heart',     '#E9C873', 4),
    ('NEURO',   'Neurologie et système nerveux',         'الجهاز العصبي',               'Neurology',             'psychology',        '#E9C873', 5),
    ('PNEUMO',  'Pneumologie et allergie respiratoire',  'الجهاز التنفسي',              'Respiratory',           'air',               '#43D97C', 6),
    ('ENDO',    'Endocrinologie (diabète, thyroïde...)', 'الغدد الصماء',                'Endocrinology',         'water_drop',        '#E9C873', 7),
    ('VITAM',   'Vitamines et compléments alimentaires', 'فيتامينات ومكملات غذائية',    'Vitamins & supplements','bolt',              '#43D97C', 8),
    ('DERMO',   'Dermatologie',                          'الجلدية',                     'Dermatology',           'spa',               '#43D97C', 9),
    ('RHUMATO', 'Rhumatologie et anti-inflammatoires',   'الروماتيزم',                  'Rheumatology',          'accessibility_new', '#43D97C', 10),
    ('URO',     'Urologie et néphrologie',               'المسالك البولية',             'Urology',               'water',             '#43D97C', 11),
    ('OPHTA',   'Ophtalmologie',                         'العيون',                      'Ophthalmology',         'visibility',        '#E9C873', 12),
    ('ORL',     'ORL (oreille, nez, gorge)',             'الأنف والأذن والحنجرة',       'ENT',                   'hearing',           '#43D97C', 13),
    ('VEINO',   'Veinotoniques et circulation',          'الدوالي والدورة الدموية',     'Veinotonics',           'bloodtype',         '#43D97C', 14),
    ('ALLER',   'Allergologie',                          'الحساسية',                    'Allergology',           'grass',             '#43D97C', 15)
ON CONFLICT (code) DO NOTHING;

-- ------------------------------------------------------------
-- 7. Permissions du module référence (§22 — permissions réelles).
--    WHERE NOT EXISTS : idempotent sans dépendre d'une
--    contrainte d'unicité éventuellement absente sur code.
-- ------------------------------------------------------------
INSERT INTO permissions (code, name, module)
    SELECT 'reference:view',   'Consulter la base de référence médicaments', 'reference'
    WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'reference:view');
INSERT INTO permissions (code, name, module)
    SELECT 'reference:edit',   'Synchroniser la base de référence',          'reference'
    WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'reference:edit');
INSERT INTO permissions (code, name, module)
    SELECT 'reference:create', 'Importer un produit de référence au catalogue', 'reference'
    WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'reference:create');

-- ------------------------------------------------------------
-- 8. Attribution par rôle (rôles à IDs fixes du seed) :
--    super_admin + pharmacy_admin → tout ;
--    pharmacist → consultation + import catalogue ;
--    stock_manager → consultation.
-- ------------------------------------------------------------
INSERT INTO role_permissions (role_id, permission_code)
    SELECT r.id, p.code
      FROM roles r
      JOIN permissions p ON p.code IN ('reference:view', 'reference:edit', 'reference:create')
     WHERE r.code IN ('super_admin', 'pharmacy_admin')
       AND NOT EXISTS (SELECT 1 FROM role_permissions rp
                        WHERE rp.role_id = r.id AND rp.permission_code = p.code);
INSERT INTO role_permissions (role_id, permission_code)
    SELECT r.id, 'reference:view'
      FROM roles r
     WHERE r.code = 'pharmacist'
       AND NOT EXISTS (SELECT 1 FROM role_permissions rp
                        WHERE rp.role_id = r.id AND rp.permission_code = 'reference:view');
INSERT INTO role_permissions (role_id, permission_code)
    SELECT r.id, 'reference:create'
      FROM roles r
     WHERE r.code = 'pharmacist'
       AND NOT EXISTS (SELECT 1 FROM role_permissions rp
                        WHERE rp.role_id = r.id AND rp.permission_code = 'reference:create');
INSERT INTO role_permissions (role_id, permission_code)
    SELECT r.id, 'reference:view'
      FROM roles r
     WHERE r.code = 'stock_manager'
       AND NOT EXISTS (SELECT 1 FROM role_permissions rp
                        WHERE rp.role_id = r.id AND rp.permission_code = 'reference:view');