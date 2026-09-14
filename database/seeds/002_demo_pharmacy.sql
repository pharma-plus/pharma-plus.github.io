-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- seeds/002_demo_pharmacy.sql — Pharmacie de démonstration
-- (les mots de passe sont créés par scripts/seed.js — argon2)
-- ============================================================

INSERT INTO pharmacies (id, slug, name, legal_name, city, phone, email, currency,
                        languages, default_lang, status)
VALUES ('11111111-1111-1111-1111-111111111111', 'pharmacie-demo',
        'Pharmacie El Amal', 'Pharmacie El Amal SARL', 'Casablanca',
        '+212 5 22 00 00 00', 'contact@elamal.ma', 'MAD',
        ARRAY['fr','ar','en'], 'fr', 'active');

INSERT INTO branches (id, pharmacy_id, name, code, address, city, phone, is_main)
VALUES ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111',
        'Pharmacie El Amal - Centre', 'BR-001', '12 Rue Mohammed V', 'Casablanca',
        '+212 5 22 00 00 00', true);

-- Licence de démonstration
INSERT INTO licenses (id, pharmacy_id, type, status, billing_cycle,
                      activation_date, expiry_date, max_users, max_branches, modules)
VALUES ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111',
        'professional', 'active', 'monthly',
        now() - interval '30 days', now() + interval '330 days',
        10, 3,
        '{"catalog":true,"stock":true,"sales":true,"purchases":true,"suppliers":true,
          "customers":true,"prescriptions":true,"employees":true,"attendance":true,
          "accounting":true,"reports":true,"ai":true,"website":true,"sync":true}');

-- Clonage des rôles système pour la pharmacie de démo
INSERT INTO roles (id, pharmacy_id, name, code, is_system)
SELECT gen_random_uuid(),
       '11111111-1111-1111-1111-111111111111', name, code, is_system
FROM roles WHERE pharmacy_id IS NULL;

INSERT INTO role_permissions (role_id, permission_code)
SELECT r.id, rp.permission_code
  FROM roles r
  JOIN roles gr ON gr.code = r.code AND gr.pharmacy_id IS NULL
  JOIN role_permissions rp ON rp.role_id = gr.id
 WHERE r.pharmacy_id = '11111111-1111-1111-1111-111111111111'
ON CONFLICT DO NOTHING;

-- Catégories
INSERT INTO categories (id, pharmacy_id, name, icon, color) VALUES
 ('c0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','Antalgiques','bolt','#EF5350'),
 ('c0000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','Antibiotiques','shield','#42A5F5'),
 ('c0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','Vitamines','favorite','#66BB6A'),
 ('c0000000-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111','Dermatologie','healing','#AB47BC'),
 ('c0000000-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111','Pédiatrie','child_care','#FFA726'),
 ('c0000000-0000-0000-0000-000000000006','11111111-1111-1111-1111-111111111111','Hygiène & Soins','spa','#26A69A');

-- Familles thérapeutiques
INSERT INTO therapeutic_families (id, pharmacy_id, code, name) VALUES
 ('f0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','ANALG','Analgésiques'),
 ('f0000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','ANTIBIO','Antibiotiques'),
 ('f0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','VIT','Compléments vitaminiques'),
 ('f0000000-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111','DERMO','Dermatologie');

-- Laboratoires
INSERT INTO laboratories (id, pharmacy_id, name, country) VALUES
 ('a0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','Sanofi','France'),
 ('a0000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','Sothema','Maroc'),
 ('a0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','GSK','Royaume-Uni'),
 ('a0000000-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111','Pharmaghreb','Maroc');

-- Médicaments de démonstration
INSERT INTO medications
 (id, pharmacy_id, category_id, family_id, laboratory_id, name, dci, generic_name,
  dosage, form, presentation, barcode_ean13, price_purchase, price_sale, tva_rate,
  prescription_required, reorder_level, min_stock, shelf_location, status, is_public)
VALUES
 ('b0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
  'c0000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001',
  'Doliprane 1000mg','Paracétamol','Paracétamol','1000 mg','Comprimé','Boîte de 8','3400936055412',
  8.00, 12.00, 20.00, false, 20, 10, 'A-01', 'available', true),
 ('b0000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
  'c0000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001',
  'Efferalgan 500mg','Paracétamol','Paracétamol','500 mg','Comprimé effervescent','Tube de 16','3400933077190',
  10.50, 16.50, 20.00, false, 15, 8, 'A-02', 'available', true),
 ('b0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
  'c0000000-0000-0000-0000-000000000002','f0000000-0000-0000-0000-000000000002','a0000000-0000-0000-0000-000000000003',
  'Augmentin 1g','Amoxicilline + Acide clavulanique','Co-amoxiclav','1 g','Comprimé','Boîte de 12','3400936079228',
  42.00, 63.00, 20.00, true, 10, 5, 'B-01', 'available', false),
 ('b0000000-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111',
  'c0000000-0000-0000-0000-000000000003','f0000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000002',
  'OligoVit Zinc','Zinc','Zinc 15mg','15 mg','Comprimé','Boîte de 30','6111345223001',
  25.00, 39.00, 20.00, false, 12, 6, 'C-01', 'available', true),
 ('b0000000-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111',
  'c0000000-0000-0000-0000-000000000005','f0000000-0000-0000-0000-000000000004','a0000000-0000-0000-0000-000000000001',
  'Gaviscon Menthe','Alginate de sodium','Acide alginique','Suspension','Suspension buvable','Flacon 250 ml','3400935963910',
  30.00, 46.00, 20.00, false, 8, 4, 'D-01', 'available', true);

-- Lots (avec une péremption proche pour tester les alertes)
INSERT INTO lots (id, pharmacy_id, medication_id, lot_number, manufacture_date, expiry_date, cost_price) VALUES
 ('e0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','b0000000-0000-0000-0000-000000000001','LOT-2024-001','2024-01-15','2026-01-15',8.00),
 ('e0000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','b0000000-0000-0000-0000-000000000002','LOT-2024-002','2024-02-01','2026-02-01',10.50),
 ('e0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','b0000000-0000-0000-0000-000000000003','LOT-2024-003','2024-01-10','2025-09-30',42.00),
 ('e0000000-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111','b0000000-0000-0000-0000-000000000004','LOT-2024-004','2024-03-01','2026-03-01',25.00),
 ('e0000000-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111','b0000000-0000-0000-0000-000000000005','LOT-2024-005','2024-02-15','2025-12-15',30.00);

-- Balances initiales + mouvements (via le moteur de stock)
INSERT INTO stock_movements (id, pharmacy_id, branch_id, medication_id, lot_id,
                             movement_type, quantity, unit_cost, reference_type, notes)
VALUES
 ('d0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','inventory_in',100,8.00,'seed','Stock initial'),
 ('d0000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000002','e0000000-0000-0000-0000-000000000002','inventory_in',80,10.50,'seed','Stock initial'),
 ('d0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000003','e0000000-0000-0000-0000-000000000003','inventory_in',60,42.00,'seed','Stock initial'),
 ('d0000000-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000004','e0000000-0000-0000-0000-000000000004','inventory_in',50,25.00,'seed','Stock initial'),
 ('d0000000-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000005','e0000000-0000-0000-0000-000000000005','inventory_in',40,30.00,'seed','Stock initial');

-- Fournisseurs & clients
INSERT INTO suppliers (id, pharmacy_id, name, contact_name, phone, city, payment_terms, delivery_delay, rating) VALUES
 ('90000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','Sothema','S. Benjelloun','+212 5 22 50 00 00','Aïn Sebaâ, Casablanca','30 jours',2,4.5),
 ('90000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','Cooper Pharma','M. El Fassi','+212 5 37 60 00 00','Aïn Atiq, Rabat','15 jours',3,4.0),
 ('90000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','DistriPharm Maroc','N. Alaoui','+212 5 22 30 00 00','Casablanca','Comptant',1,4.8);

INSERT INTO customers (id, pharmacy_id, name, phone, whatsapp, email, city, loyalty_points, credit_limit) VALUES
 ('0000000c-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','Fatima Zahra Idrissi','+212 6 61 00 00 00','+212 6 61 00 00 00','fz.idrissi@email.com','Casablanca',120,500),
 ('0000000c-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','Mohammed Benali','+212 6 62 00 00 00','+212 6 62 00 00 00','m.benali@email.com','Casablanca',45,300),
 ('0000000c-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','Khadija El Mansouri','+212 6 63 00 00 00',NULL,NULL,'Rabat',0,0);

-- Paramètres site Web de démo
INSERT INTO website_settings (pharmacy_id, hero_title, hero_subtitle, about, opening_hours)
VALUES ('11111111-1111-1111-1111-111111111111',
        'Votre pharmacie de confiance à Casablanca',
        'Service professionnel, conseils personnalisés et produits authentiques.',
        'La Pharmacie El Amal est une pharmacie moderne située au cœur de Casablanca, au service de votre santé depuis 2005.',
        '[{"day":"Lundi-Vendredi","hours":"08:00 - 21:00"},{"day":"Samedi","hours":"08:30 - 20:00"},{"day":"Dimanche","hours":"09:00 - 13:00"}]');
