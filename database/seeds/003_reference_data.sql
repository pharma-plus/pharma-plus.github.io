-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- seeds/003_reference_data.sql — Base de référence (démo)
-- Catégories thérapeutiques + fiches produits de référence.
--
-- ATTENTION : ces fiches de démonstration sont marquées
-- source = 'seed_demo'. En production, la base de référence
-- doit être synchronisée depuis un fichier officiel validé
-- (voir module /reference). Aucun prix n'est inventé ici.
-- ============================================================

-- ------------------------------------------------------------
-- Catégories thérapeutiques standard
-- ------------------------------------------------------------
INSERT INTO reference_categories (code, name_fr, name_ar, name_en, icon, color, sort_order) VALUES
 ('ANALG','Antalgiques / Antipyrétiques','مسكنات','Analgesics','bolt','#EF5350',1),
 ('CARDIO','Cardiologie','أمراض القلب','Cardiology','favorite','#E53935',2),
 ('NEURO','Neurologie / Psychiatrie','أمراض الأعصاب','Neurology','psychology','#8E24AA',3),
 ('PNEUMO','Pneumologie / Allergologie','أمراض الجهاز التنفسي','Respiratory','air','#29B6F6',4),
 ('GASTRO','Gastro-entérologie','أمراض الجهاز الهضمي','Gastroenterology','restaurant','#FF7043',5),
 ('ENDO','Endocrinologie / Métabolisme','الغدد الصماء','Endocrinology','monitor_heart','#D81B60',6),
 ('OPHTA','Ophtalmologie','طب العيون','Ophthalmology','visibility','#5E35B1',7),
 ('DERMO','Dermatologie','الأمراض الجلدية','Dermatology','healing','#AB47BC',8),
 ('INFECT','Infectiologie / Parasitologie','الأمراض المعدية','Infectiology','shield','#42A5F5',9),
 ('RHUMATO','Rhumatologie','أمراض المفاصل','Rheumatology','accessibility_new','#8D6E63',10),
 ('URO','Urologie / Néphrologie','أمراض الكلى','Urology','water_drop','#00897B',11),
 ('CANCERO','Cancérologie / Immunomodulation','الأورام','Oncology','biotech','#6D4C41',12),
 ('ANESTH','Anesthésie / Réanimation','التخدير','Anesthesiology','medical_services','#546E7A',13),
 ('ORL','ORL / Stomatologie','الأنف والأذن والحنجرة','ENT','hearing','#F4511E',14),
 ('VEINO','Veinologie','أمراض الأوردة','Vascular','route','#3949AB',15),
 ('ALLER','Allergologie','الحساسية','Allergology','grass','#26A69A',16),
 ('VITAM','Vitamines / Compléments','فيتامينات','Vitamins','spa','#66BB6A',17)
ON CONFLICT (code) DO NOTHING;

-- ------------------------------------------------------------
-- Produits de référence (extrait de démonstration)
-- ------------------------------------------------------------
INSERT INTO reference_products
 (category_code, name, dci, substance_active, dosage, form, presentation,
  laboratory, therapeutic_class, commercial_status, amm_number, barcode_ean13,
  ppv, ph, pfht, tva_rate, source, source_updated_at)
VALUES
 ('ANALG','Doliprane 1000mg','Paracétamol','Paracétamol','1000 mg','Comprimé','Boîte de 8',
  'Sanofi','Antalgique - Antipyrétique','commercialise','34009 360 5541 2','3400936055412',
  12.00, 9.60, 8.00, 20.00, 'seed_demo', now()),
 ('ANALG','Efferalgan 500mg','Paracétamol','Paracétamol','500 mg','Comprimé effervescent','Tube de 16',
  'UPSA','Antalgique - Antipyrétique','commercialise','34009 330 7719 0','3400933077190',
  16.50, 13.20, 10.50, 20.00, 'seed_demo', now()),
 ('ANALG','Doliprane 1000mg Suppositoire','Paracétamol','Paracétamol','1000 mg','Suppositoire','Boîte de 8',
  'Sanofi','Antalgique - Antipyrétique','commercialise','34009 365 4414 5','3400936544145',
  13.00, 10.40, 8.50, 20.00, 'seed_demo', now()),
 ('ANALG','Ibuprofène Maphar 200mg','Ibuprofène','Ibuprofène','200 mg','Comprimé','Boîte de 20',
  'Maphar','Anti-inflammatoire','commercialise','6111345000012','6111345000012',
  12.00, 9.60, 8.00, 20.00, 'seed_demo', now()),
 ('INFECT','Augmentin 1g','Amoxicilline + Acide clavulanique','Co-amoxiclav','1 g','Comprimé pelliculé','Boîte de 12',
  'GSK','Antibiotique','commercialise','34009 360 7922 8','3400936079228',
  63.00, 50.40, 42.00, 20.00, 'seed_demo', now()),
 ('INFECT','Amoxicilline Sandoz 500mg','Amoxicilline','Amoxicilline','500 mg','Gélule','Boîte de 12',
  'Sandoz','Antibiotique','commercialise','34009 308 8576 3','3400930885763',
  14.00, 11.20, 9.00, 20.00, 'seed_demo', now()),
 ('INFECT','Clamoxyl 500mg','Amoxicilline','Amoxicilline','500 mg','Gélule','Boîte de 12',
  'GSK','Antibiotique','commercialise','34009 301 9623 4','3400930196234',
  13.50, 10.80, 8.80, 20.00, 'seed_demo', now()),
 ('PNEUMO','Ventoline 100µg/dose','Salbutamol','Salbutamol','100 µg','Spray inhalateur','Flacon 200 doses',
  'GSK','Bronchodilatateur','commercialise','34009 301 8131 5','3400930181315',
  38.00, 30.40, 25.00, 20.00, 'seed_demo', now()),
 ('PNEUMO','Spiriva 18µg','Tiotropium','Bromure de tiotropium','18 µg','Gélule inhalée','Boîte de 30',
  'Boehringer Ingelheim','Bronchodilatateur','commercialise','34009 334 1780 8','3400933417808',
  110.00, 88.00, 73.00, 20.00, 'seed_demo', now()),
 ('PNEUMO','Toplexil','Oxomémazine','Oxomémazine','Sirops','Sirop','Flacon 150 ml',
  'Sanofi','Antitussif','commercialise','34009 301 1415 3','3400930114153',
  21.00, 16.80, 14.00, 20.00, 'seed_demo', now()),
 ('GASTRO','Smecta','Diosmectite','Smectite di-octaédrique','3 g','Poudre orale','Boîte de 30 sachets',
  'Ipsen','Antidiarrhéique','commercialise','34009 333 3230 5','3400933332305',
  34.00, 27.20, 22.00, 20.00, 'seed_demo', now()),
 ('GASTRO','Spasfon 80mg','Phloroglucinol','Phloroglucinol','80 mg','Comprimé','Boîte de 30',
  'Teva','Antispasmodique','commercialise','34009 325 3032 4','3400932530324',
  27.00, 21.60, 18.00, 20.00, 'seed_demo', now()),
 ('GASTRO','Gaviscon Menthe','Alginate de sodium','Acide alginique','Suspension','Suspension buvable','Flacon 250 ml',
  'Reckitt','Anti-reflux','commercialise','34009 359 6391 0','3400935963910',
  46.00, 36.80, 30.00, 20.00, 'seed_demo', now()),
 ('ALLER','Aerius 5mg','Desloratadine','Desloratadine','5 mg','Comprimé pelliculé','Boîte de 15',
  'MSD','Antihistaminique','commercialise','34009 342 1712 1','3400934217121',
  29.00, 23.20, 19.00, 20.00, 'seed_demo', now()),
 ('ALLER','Telfast 120mg','Fexofénadine','Fexofénadine','120 mg','Comprimé pelliculé','Boîte de 15',
  'Sanofi','Antihistaminique','commercialise','34009 330 5052 0','3400933050520',
  41.00, 32.80, 27.00, 20.00, 'seed_demo', now()),
 ('RHUMATO','Voltarène Emulgel 1%','Diclofénac','Diclofénac','1 %','Gel','Tube de 50 g',
  'Novartis','Anti-inflammatoire local','commercialise','34009 324 1101 0','3400932411010',
  42.00, 33.60, 28.00, 20.00, 'seed_demo', now()),
 ('RHUMATO','Zyloric 100mg','Allopurinol','Allopurinol','100 mg','Comprimé','Boîte de 30',
  'GSK','Anti-uricémiant','commercialise','34009 301 1216 6','3400930112166',
  31.00, 24.80, 20.50, 20.00, 'seed_demo', now()),
 ('CARDIO','Kardégic 75mg','Acétylsalicylate de lysine','Aspirine','75 mg','Poudre orale','Boîte de 30 sachets',
  'Sanofi','Antiagrégant','commercialise','34009 354 9909 3','3400935499093',
  33.00, 26.40, 22.00, 20.00, 'seed_demo', now()),
 ('CARDIO','Lasilix 40mg','Furosémide','Furosémide','40 mg','Comprimé','Boîte de 30',
  'Sanofi','Diurétique','commercialise','34009 302 8471 6','3400930284716',
  29.00, 23.20, 19.00, 20.00, 'seed_demo', now()),
 ('DERMO','Betadine Dermique 10%','Povidone iodée','Povidone iodée','10 %','Solution','Flacon 125 ml',
  'Meda','Antiseptique','commercialise','34009 308 3689 7','3400930836897',
  28.00, 22.40, 18.50, 20.00, 'seed_demo', now()),
 ('DERMO','Biseptine','Chlorhexidine + Cétrimide','Antiseptique','Solution','Solution','Flacon 250 ml',
  'Bayer','Antiseptique','commercialise','34009 337 6362 8','3400933763628',
  20.00, 16.00, 13.00, 20.00, 'seed_demo', now()),
 ('ORL','Pivalone','Tixocortol','Tixocortol','1 %','Suspension nasale','Flacon 15 ml',
  'JABA','Anti-inflammatoire nasal','commercialise','34009 333 5176 2','3400933351762',
  35.00, 28.00, 23.00, 20.00, 'seed_demo', now()),
 ('VEINO','Detralex 500mg','Flavonoïdes','Diosmine + Hespéridine','500 mg','Comprimé pelliculé','Boîte de 60',
  'Servier','Vénotonique','commercialise','34009 345 3801 0','3400934538010',
  72.00, 57.60, 48.00, 20.00, 'seed_demo', now()),
 ('VITAM','Magné B6','Magnésium + Vitamine B6','Pidolate de magnésium','100 mg','Comprimé','Boîte de 60',
  'Sanofi','Complément alimentaire','commercialise','34009 358 8547 6','3400935885476',
  56.00, 44.80, 37.00, 20.00, 'seed_demo', now()),
 ('VITAM','Vitamine C UPSA 500mg','Acide ascorbique','Vitamine C','500 mg','Comprimé effervescent','Tube de 24',
  'UPSA','Complément vitaminique','commercialise','34009 325 2166 8','3400932521668',
  22.00, 17.60, 14.50, 20.00, 'seed_demo', now())
ON CONFLICT (barcode_ean13) DO NOTHING;

-- ------------------------------------------------------------
-- Pharmacie de démonstration : familles thérapeutiques standard
-- ------------------------------------------------------------
INSERT INTO therapeutic_families (pharmacy_id, code, name) VALUES
 ('11111111-1111-1111-1111-111111111111','CARDIO','Cardiologie'),
 ('11111111-1111-1111-1111-111111111111','NEURO','Neurologie / Psychiatrie'),
 ('11111111-1111-1111-1111-111111111111','PNEUMO','Pneumologie / Allergologie'),
 ('11111111-1111-1111-1111-111111111111','GASTRO','Gastro-entérologie'),
 ('11111111-1111-1111-1111-111111111111','ENDO','Endocrinologie / Métabolisme'),
 ('11111111-1111-1111-1111-111111111111','OPHTA','Ophtalmologie'),
 ('11111111-1111-1111-1111-111111111111','INFECT','Infectiologie / Parasitologie'),
 ('11111111-1111-1111-1111-111111111111','RHUMATO','Rhumatologie'),
 ('11111111-1111-1111-1111-111111111111','URO','Urologie / Néphrologie'),
 ('11111111-1111-1111-1111-111111111111','CANCERO','Cancérologie / Immunomodulation'),
 ('11111111-1111-1111-1111-111111111111','PARA','Parapharmacie'),
 ('11111111-1111-1111-1111-111111111111','ORL','ORL / Stomatologie'),
 ('11111111-1111-1111-1111-111111111111','VEINO','Veinologie')
ON CONFLICT (pharmacy_id, code) DO NOTHING;

-- ------------------------------------------------------------
-- Parapharmacie : produits de démonstration
-- ------------------------------------------------------------
INSERT INTO medications
 (id, pharmacy_id, category_id, family_id, laboratory_id, name, dci, generic_name,
  dosage, form, presentation, barcode_ean13, price_purchase, price_sale, tva_rate,
  prescription_required, reorder_level, min_stock, shelf_location, status, is_public, is_parapharmacie)
SELECT v.*
FROM (VALUES
  ('b0000000-0000-0000-0000-000000000006'::uuid,'11111111-1111-1111-1111-111111111111'::uuid,
   'c0000000-0000-0000-0000-000000000006'::uuid,NULL::uuid,NULL::uuid,
   'Biafine Emulsion','Biafine','Trolamine','Emulsion','Emulsion','Tube 93 g','3337876120217',
   45.00, 68.00, 20.00, false, 5, 2, 'P-01', 'available', true, true),
  ('b0000000-0000-0000-0000-000000000007'::uuid,'11111111-1111-1111-1111-111111111111'::uuid,
   'c0000000-0000-0000-0000-000000000006'::uuid,NULL::uuid,NULL::uuid,
   'Cicaplast Baume B5','Cicaplast','Madecassoside','Baume','Baume','Tube 40 ml','3337875543718',
   90.00, 132.00, 20.00, false, 4, 2, 'P-02', 'available', true, true)
) AS v(id, pharmacy_id, category_id, family_id, laboratory_id, name, dci, generic_name,
       dosage, form, presentation, barcode_ean13, price_purchase, price_sale, tva_rate,
       prescription_required, reorder_level, min_stock, shelf_location, status, is_public, is_parapharmacie)
WHERE NOT EXISTS (
  SELECT 1 FROM medications m
  WHERE m.pharmacy_id = v.pharmacy_id AND m.barcode_ean13 = v.barcode_ean13
);
