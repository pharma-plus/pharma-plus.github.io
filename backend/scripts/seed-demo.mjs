// Seed demo idempotent pour la premiere pharmacie active existante :
// categories, familles, labos, medicaments, lots, mouvements, clients.
import 'dotenv/config';
import pg from 'pg';

const url = (process.env.DATABASE_URL || '').replace(/[?&]sslmode=[^&]*/g, '');
const p = new pg.Pool({ connectionString: url, ssl: { rejectUnauthorized: false } });
const PH = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const BR = '22222222-2222-2222-2222-222222222222';

const q = (t, v) => p.query(t, v);

try {
  await q('BEGIN');

  // 0. Pharmacie cible + succursale (reutilisee si elle existe deja)
  const ph = await q('SELECT id FROM pharmacies WHERE id = $1', [PH]);
  if (ph.rowCount === 0) throw new Error(`Pharmacie ${PH} introuvable`);
  let br = await q(
    'SELECT id FROM branches WHERE pharmacy_id = $1 ORDER BY created_at LIMIT 1',
    [PH],
  );
  if (br.rowCount === 0) {
    await q(
      `INSERT INTO branches (id, pharmacy_id, code, name, city, status)
       VALUES ($1,$2,'MAIN','Succursale principale','Casablanca','active')`,
      [BR, PH],
    );
    br = await q('SELECT id FROM branches WHERE id = $1', [BR]);
  }
  const branchId = br.rows[0].id;

  // 1. Categories
  const cats = [
    ['c0000000-0000-0000-0000-000000000001', 'Antalgiques', 'bolt', '#EF5350'],
    ['c0000000-0000-0000-0000-000000000002', 'Antibiotiques', 'shield', '#42A5F5'],
    ['c0000000-0000-0000-0000-000000000003', 'Vitamines', 'favorite', '#66BB6A'],
    ['c0000000-0000-0000-0000-000000000004', 'Dermatologie', 'healing', '#AB47BC'],
    ['c0000000-0000-0000-0000-000000000005', 'PÃ©diatrie', 'child_care', '#FFA726'],
    ['c0000000-0000-0000-0000-000000000006', 'HygiÃ¨ne & Soins', 'spa', '#26A69A'],
  ];
  for (const [id, name, icon, color] of cats) {
    await q(
      `INSERT INTO categories (id, pharmacy_id, name, icon, color)
       VALUES ($1,$2,$3,$4,$5) ON CONFLICT (id) DO NOTHING`,
      [id, PH, name, icon, color],
    );
  }
  // 2. Familles + labos
  const fams = [
    ['f0000000-0000-0000-0000-000000000001', 'ANALG', 'AnalgÃ©siques'],
    ['f0000000-0000-0000-0000-000000000002', 'ANTIBIO', 'Antibiotiques'],
    ['f0000000-0000-0000-0000-000000000003', 'VIT', 'ComplÃ©ments vitaminiques'],
    ['f0000000-0000-0000-0000-000000000004', 'DERMO', 'Dermatologie'],
  ];
  for (const [id, code, name] of fams) {
    await q(
      `INSERT INTO therapeutic_families (id, pharmacy_id, code, name)
       VALUES ($1,$2,$3,$4) ON CONFLICT (id) DO NOTHING`,
      [id, PH, code, name],
    );
  }
  const labs = [
    ['a0000000-0000-0000-0000-000000000001', 'Sanofi', 'France'],
    ['a0000000-0000-0000-0000-000000000002', 'Sothema', 'Maroc'],
    ['a0000000-0000-0000-0000-000000000003', 'GSK', 'Royaume-Uni'],
    ['a0000000-0000-0000-0000-000000000004', 'Pharmaghreb', 'Maroc'],
  ];
  for (const [id, name, country] of labs) {
    await q(
      `INSERT INTO laboratories (id, pharmacy_id, name, country)
       VALUES ($1,$2,$3,$4) ON CONFLICT (id) DO NOTHING`,
      [id, PH, name, country],
    );
  }
  // 3. Medicaments (5 classiques + 2 parapharmacie)
  const meds = [
    ['b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
      'Doliprane 1000mg', 'ParacÃ©tamol', 'ParacÃ©tamol', '1000 mg', 'ComprimÃ©', 'BoÃ®te de 8', '3400936055412', 8, 12, false, 20, 10, 'A-01', false],
    ['b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
      'Efferalgan 500mg', 'ParacÃ©tamol', 'ParacÃ©tamol', '500 mg', 'ComprimÃ© effervescent', 'Tube de 16', '3400933077190', 10.5, 16.5, false, 15, 8, 'A-02', false],
    ['b0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000003',
      'Augmentin 1g', 'Amoxicilline + Acide clavulanique', 'Co-amoxiclav', '1 g', 'ComprimÃ©', 'BoÃ®te de 12', '3400936079228', 42, 63, true, 10, 5, 'B-01', false],
    ['b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000003', 'f0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000002',
      'OligoVit Zinc', 'Zinc', 'Zinc 15mg', '15 mg', 'ComprimÃ©', 'BoÃ®te de 30', '6111345223001', 25, 39, false, 12, 6, 'C-01', false],
    ['b0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000004', 'f0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000002',
      'Bepanthen Plus', 'DexpanthÃ©nol', 'DexpanthÃ©nol 5%', '5 %', 'Pommade', 'Tube 30 g', '4005808851075', 38, 55, false, 8, 4, 'D-01', false],
    ['b0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000006', null, 'a0000000-0000-0000-0000-000000000002',
      'Biafine Emulsion', 'Biafine', 'Trolamine', 'Emulsion', 'Emulsion', 'Tube 93 g', '3337876120217', 45, 68, false, 5, 2, 'P-01', true],
    ['b0000000-0000-0000-0000-000000000007', 'c0000000-0000-0000-0000-000000000006', null, 'a0000000-0000-0000-0000-000000000002',
      'Cicaplast Baume B5', 'Cicaplast', 'Madecassoside', 'Baume', 'Baume', 'Tube 40 ml', '3337875543718', 90, 132, false, 4, 2, 'P-02', true],
  ];
  let nMeds = 0;
  for (const [id, cat, fam, lab, name, dci, gen, dosage, form, pres, barcode, buy, sell, ord, reorder, minst, shelf, para] of meds) {
    const r = await q(
      `INSERT INTO medications
        (id, pharmacy_id, category_id, family_id, laboratory_id, name, dci, generic_name,
         dosage, form, presentation, barcode_ean13, price_purchase, price_sale, tva_rate,
         prescription_required, reorder_level, min_stock, shelf_location, status, is_public, is_parapharmacie)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,20,$15,$16,$17,$18,'available',true,$19)
       ON CONFLICT (id) DO NOTHING`,
      [id, PH, cat, fam, lab, name, dci, gen, dosage, form, pres, barcode, buy, sell, ord, reorder, minst, shelf, para],
    );
    nMeds += r.rowCount;
  }
  // 4. Lots + mouvements de stock initial
  const lots = [
    ['e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'LOT-2024-001', '2024-01-05', '2026-06-30', 8],
    ['e0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'LOT-2024-002', '2024-02-20', '2025-12-31', 10.5],
    ['e0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003', 'LOT-2024-003', '2024-01-10', '2025-09-30', 42],
    ['e0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000004', 'LOT-2024-004', '2024-03-01', '2026-03-01', 25],
    ['e0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000005', 'LOT-2024-005', '2024-02-15', '2025-12-15', 30],
    ['e0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000006', 'LOT-2024-006', '2024-04-01', '2027-01-01', 45],
    ['e0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000007', 'LOT-2024-007', '2024-04-01', '2027-01-01', 90],
  ];
  const qty = [100, 80, 60, 50, 40, 30, 25];
  for (let i = 0; i < lots.length; i++) {
    const [lotId, medId, num, mfg, exp, cost] = lots[i];
    await q(
      `INSERT INTO lots (id, pharmacy_id, medication_id, lot_number, manufacture_date, expiry_date, cost_price)
       VALUES ($1,$2,$3,$4,$5,$6,$7) ON CONFLICT (id) DO NOTHING`,
      [lotId, PH, medId, num, mfg, exp, cost],
    );
    await q(
      `INSERT INTO stock_movements (id, pharmacy_id, branch_id, medication_id, lot_id,
                                    movement_type, quantity, unit_cost, reference_type, notes)
       VALUES (md5(random()::text || clock_timestamp()::text)::uuid, $1,$2,$3,$4,'inventory_in',$5,$6,'seed','Stock initial')`,
      [PH, branchId, medId, lotId, qty[i], cost],
    );
  }
  // 5. Clients de demo
  const custs = [
    ['0000000c-0000-0000-0000-000000000001', 'Fatima Zahra Idrissi', '+212 6 61 00 00 00', 'fz.idrissi@email.com', 'Casablanca', 120, 500],
    ['0000000c-0000-0000-0000-000000000002', 'Mohammed Benali', '+212 6 62 00 00 00', 'm.benali@email.com', 'Casablanca', 45, 300],
    ['0000000c-0000-0000-0000-000000000003', 'Khadija El Mansouri', '+212 6 63 00 00 00', null, 'Rabat', 0, 0],
  ];
  for (const [id, fullName, phone, email, city, pts, credit] of custs) {
    const parts = fullName.split(' ');
    const firstName = parts[0];
    const lastName = parts.slice(1).join(' ') || '-';
    await q(
      `INSERT INTO customers (id, pharmacy_id, first_name, last_name, name, phone, whatsapp,
                              email, city, loyalty_points, credit_limit)
       VALUES ($1,$2,$3,$4,$5,$6,$6,$7,$8,$9,$10)
       ON CONFLICT (id) DO NOTHING`,
      [id, PH, firstName, lastName, fullName, phone, email, city, pts, credit],
    );
  }

  // 6. Employes de demo
  const emps = [
    ['f0000000-0000-0000-0000-000000000101', 'EMP-001', 'Youssef', 'El Amrani', 'y.elamrani@pharma-demo.ma', '+212 6 71 11 22 33', 'Pharmacien responsable', 'Officine', 14000, 'cdi'],
    ['f0000000-0000-0000-0000-000000000102', 'EMP-002', 'Salma', 'Bennis', 's.bennis@pharma-demo.ma', '+212 6 72 44 55 66', 'Préparatrice', 'Officine', 7500, 'cdi'],
    ['f0000000-0000-0000-0000-000000000103', 'EMP-003', 'Karim', 'Tazi', 'k.tazi@pharma-demo.ma', '+212 6 73 77 88 99', 'Caissier', 'Caisse', 4500, 'cdd'],
  ];
  for (const [id, num, fn, ln, email, phone, position, dept, salary, contract] of emps) {
    await q(
      `INSERT INTO employees (id, pharmacy_id, branch_id, employee_number, first_name, last_name,
                              email, phone, hire_date, position, department, salary, salary_type,
                              contract_type, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'2024-01-15',$9,$10,$11,'monthly',$12,'active')
       ON CONFLICT (id) DO NOTHING`,
      [id, PH, branchId, num, fn, ln, email, phone, position, dept, salary, contract],
    );
  }

  // 7. Presences du jour (pointage manuel)
  for (const [id] of emps) {
    await q(
      `INSERT INTO attendance (id, pharmacy_id, employee_id, date, check_in, check_out,
                               break_minutes, status, method, late_minutes,
                               overtime_minutes, hours_worked)
       VALUES (md5(random()::text || clock_timestamp()::text)::uuid, $1,$2, CURRENT_DATE,
               date_trunc('day', now()) + INTERVAL '8 hours',
               date_trunc('day', now()) + INTERVAL '17 hours',
               60, 'present', 'manual', 0, 0, 8) ON CONFLICT (employee_id, date) DO NOTHING`,
      [PH, id],
    );
  }

  // 8. Commandes d'achat de demo + lignes (fournisseurs existants)
  const sup = await q('SELECT id FROM suppliers WHERE pharmacy_id = $1 ORDER BY name LIMIT 2', [PH]);
  const medsPo = await q(
    `SELECT id, price_purchase FROM medications WHERE pharmacy_id = $1 AND is_parapharmacie = false LIMIT 3`,
    [PH],
  );
  const poStatuses = ['received', 'sent'];
  for (let i = 0; i < sup.rowCount; i++) {
    const orderId = `d0000000-0000-0000-0000-00000000000${i + 1}`;
    const st = poStatuses[i % poStatuses.length];
    const qty = 40 + i * 10;
    const unit = Number(medsPo.rows[0]?.price_purchase ?? 10);
    const total = Math.round(qty * unit * medsPo.rowCount * 100) / 100;
    await q(
      `INSERT INTO purchase_orders (id, pharmacy_id, branch_id, supplier_id, number, status,
                                    order_date, expected_date, subtotal, discount_total, tax_total, total)
       VALUES ($1,$2,$3,$4,$5,$6, CURRENT_DATE - 5, CURRENT_DATE + 2, $7, 0, 0, $7)
       ON CONFLICT (id) DO NOTHING`,
      [orderId, PH, branchId, sup.rows[i].id, `PO-2026-00${i + 1}`, st, total],
    );
    for (let j = 0; j < medsPo.rowCount; j++) {
      await q(
        `INSERT INTO purchase_order_items (id, pharmacy_id, purchase_order_id, order_id, medication_id,
                                           quantity_ordered, quantity_received, unit_cost,
                                           discount_percent, tax_rate)
         VALUES (md5(random()::text || clock_timestamp()::text)::uuid, $1,$2,$2,$3,$4,$5,$6,0,20)`,
        [PH, orderId, medsPo.rows[j].id, qty, st === 'received' ? qty : 0, Number(medsPo.rows[j].price_purchase)],
      );
    }
  }

  // 9. Ordonnances de demo (clients existants)
  const custs2 = await q('SELECT id FROM customers WHERE pharmacy_id = $1 ORDER BY created_at LIMIT 2', [PH]);
  const presc = [
    ['pending', 'Dr. Hassan Rifai'],
    ['dispensed', 'Dr. Leila Ouazzani'],
  ];
  for (let i = 0; i < custs2.rowCount && i < presc.length; i++) {
    const pr = await q(
      `INSERT INTO prescriptions (id, pharmacy_id, branch_id, customer_id, prescriber_name,
                                  prescribed_date, status, source, doctor_name)
       VALUES (md5(random()::text || clock_timestamp()::text)::uuid, $1,$2,$3,$4,
               CURRENT_DATE, $5, 'manual', $4)
       RETURNING id`,
      [PH, branchId, custs2.rows[i].id, presc[i][1], presc[i][0]],
    );
    const prescId = pr.rows[0].id;
    const items = await q(
      `SELECT id, dosage FROM medications WHERE pharmacy_id = $1 AND prescription_required = true LIMIT 2`,
      [PH],
    );
    for (const m of items.rows) {
      await q(
        `INSERT INTO prescription_items (id, pharmacy_id, prescription_id, medication_id,
                                         dosage, frequency, duration, quantity, is_dispensed)
         VALUES (md5(random()::text || clock_timestamp()::text)::uuid, $1,$2,$3,
                 $4, '3 fois par jour', '5 jours', 20, $5)`,
        [PH, prescId, m.id, m.dosage ?? '1 unite', presc[i][0] === 'dispensed'],
      );
    }
  }

  await q('COMMIT');
  const cnt = await q('SELECT count(*)::int AS n FROM medications WHERE pharmacy_id = $1', [PH]);
  const emp = await q('SELECT count(*)::int AS n FROM employees WHERE pharmacy_id = $1', [PH]);
  const po = await q('SELECT count(*)::int AS n FROM purchase_orders WHERE pharmacy_id = $1', [PH]);
  const pr = await q('SELECT count(*)::int AS n FROM prescriptions WHERE pharmacy_id = $1', [PH]);
  console.log(`Seed OK - medicaments: ${cnt.rows[0].n}, employes: ${emp.rows[0].n}, commandes: ${po.rows[0].n}, ordonnances: ${pr.rows[0].n}`);
} catch (err) {
  await q('ROLLBACK');
  console.error('Seed KO:', err.message);
  process.exitCode = 1;
} finally {
  await p.end();
}







