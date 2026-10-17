import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/**
 * PHASE 5 — facturation (§6) : la table invoices existe déjà en
 * production (schéma 007_sales.sql, 007 factures 0 lignes), mais le
 * routeur Edge retournait 501 sur /invoices (commentaire périmé
 * « table inexistante »). On vérifie ici que le port Edge 2.3.0 :
 *
 *  (a) supprime le 501 et sert GET /invoices (liste paginée, contrat
 *      Express listInvoices), GET /invoices/:id (détail + lignes),
 *      GET /invoice-items ;
 *  (b) interdit toute écriture manuelle (405) — création uniquement
 *      via POST /sales (vente crédit → FAC) ou /sales/returns
 *      (fn_sale_return → AVR) ;
 *  (c) crée l'en-tête FAC dans le flux POST /sales quand sale_type
 *      = credit (contrat Express _createInvoice : due +30j, status
 *      paid/unpaid) ;
 *  (d) applique le solde facture sur POST /payments portant un
 *      invoiceId (contrat Express recordPayment : paid_amount +
 *      status + crédit client) ;
 *  (e) garde l'isolation pharmacie sur chaque lecture facture.
 */

const readRel = (p) => readFileSync(fileURLToPath(new URL(p, import.meta.url)), 'utf8');
const edge = readRel('../../supabase/functions/pharma-api/index.ts');

test('factures : le 501 NOT_IMPLEMENTED périmé a disparu', () => {
  assert.ok(!edge.includes('NOT_IMPLEMENTED'), 'plus de code NOT_IMPLEMENTED sur invoices');
  assert.ok(
    !/la table invoices n'existe pas en production/i.test(edge),
    'commentaire périmé supprimé',
  );
  assert.ok(edge.includes('EDGE_VERSION = "2.5.8"'), 'version bumpée (2.5.8 — refresh contrôlé + révocation sessions désactivation)');
});

test('factures : GET /invoices, /invoices/:id, /invoice-items servis', () => {
  assert.match(edge, /path === "invoices" && req\.method === "GET"/, 'liste factures');
  assert.match(edge, /invoices\\\/\(\[0-9a-f-\]\{36\}\)\$\/i/, 'détail facture par id');
  assert.match(edge, /path === "invoice-items" && req\.method === "GET"/, 'lignes facture');
  assert.ok(edge.includes('customers(name), branches(name)'), 'embed client + succursale');
  assert.ok(edge.includes('invoice_items(*)'), 'embed lignes sur le détail');
  assert.ok(
    edge.includes("fn_next_number") && edge.includes('p_prefix: "FAC"'),
    'numérotation FAC séquentielle (fn_next_number)',
  );
});

test('factures : isolation pharmacie sur chaque lecture', () => {
  // La liste, le détail et les lignes filtrent eq("pharmacy_id", pid).
  const listBlock = edge.slice(
    edge.indexOf('path === "invoices" && req.method === "GET"'),
    edge.indexOf('path === "invoice-items" && req.method === "GET"'),
  );
  assert.ok(listBlock.includes('.eq("pharmacy_id", pid)'), 'liste filtrée pharmacie');
  assert.ok(
    listBlock.split('.eq("pharmacy_id", pid)').length >= 3,
    'détail + lignes aussi filtrés pharmacie',
  );
});

test('factures : écriture manuelle interdite (405) sur POST/PUT/PATCH/DELETE', () => {
  assert.ok(edge.includes('Écriture manuelle interdite'), 'message garde 405 présent');
  assert.match(
    edge,
    /path === "invoices"[\s\S]{0,400}req\.method !== "GET"/,
    'condition non-GET sur invoices',
  );
  assert.match(
    edge,
    /invoice-items\/"[\s\S]{0,120}req\.method !== "GET"[\s\S]{0,400}405/,
    'code HTTP 405 après la condition',
  );
  assert.ok(edge.includes('/sales/returns'), 'renvoie vers avoirs');
});

test('vente crédit : en-tête FAC créé dans POST /sales', () => {
  const salesIdx = edge.indexOf('const wantsInvoice');
  assert.ok(salesIdx > 0, 'drapeau wantsInvoice présent');
  const block = edge.slice(salesIdx, salesIdx + 1600);
  assert.ok(block.includes('saleType === "credit"'), 'déclencheur crédit');
  assert.ok(block.includes('generateInvoice'), 'déclencheur generateInvoice');
  assert.ok(block.includes('type: "invoice"'), 'type invoice');
  assert.ok(block.includes('dueD.setDate(dueD.getDate() + 30)'), 'échéance +30 jours');
  assert.ok(
    block.includes("paidAmount >= total ? \"paid\" : \"unpaid\""),
    'statut paid/unpaid selon encaissement',
  );
  assert.ok(block.includes('catch (eInv)'), 'best-effort : échec facture n annule pas la vente');
});

test('paiement facture : POST /payments + invoiceId applique le solde (recordPayment)', () => {
  const payIdx = edge.indexOf('PAIEMENT FACTURE');
  assert.ok(payIdx > 0, 'bloc paiement facture présent');
  const block = edge.slice(payIdx, edge.indexOf('FACTURES — la table invoices'));
  assert.ok(block.includes('path === "payments" && req.method === "POST"'), 'route payments POST');
  assert.ok(block.includes('invoiceId'), 'lecture du champ invoiceId');
  assert.ok(block.includes('.from("invoices")'), 'facture lue');
  assert.ok(block.includes('paid_amount: newPaid'), 'solde mis à jour');
  assert.ok(block.includes("newPaid >= Number(invP.total) ? \"paid\""), 'statut paid');
  assert.ok(block.includes('newPaid > 0 ? "partial"'), 'statut partial');
  assert.ok(block.includes('credit_balance'), 'crédit client débité');
  assert.ok(block.includes('"NOT_FOUND"'), '404 facture introuvable');
  assert.ok(block.includes('audit_logs'), 'audit journalisé');
  assert.ok(block.includes('proxy générique'), 'sans invoiceId : chute proxy (vente)');
});

test('avoirs : fn_sale_return inchangée côté Edge (déjà portée)', () => {
  assert.ok(
    edge.includes('fn_sale_return') && edge.includes('sales/returns'),
    'POST /sales/returns délègue à fn_sale_return (AVR)',
  );
});

test('e-facture : export structuré pharma-facture-v1 (art. 145-III)', () => {
  assert.match(
    edge,
    /invoices\\\/\(\[0-9a-f-\]\{36\}\)\\\/export\$\/i/,
    'route GET /invoices/:id/export',
  );
  assert.ok(edge.includes('pharma-facture-v1'), 'format versionné présent');
  assert.ok(edge.includes('attente-decret-145-IX'), 'canal DGI marqué en attente de décret');
  const xIdx = edge.lastIndexOf('pharma-facture-v1');
  const xBlock = edge.slice(xIdx - 800, xIdx + 3500);
  assert.ok(xBlock.includes('.eq("pharmacy_id", pid)'), 'isolation pharmacie export');
  assert.ok(xBlock.includes('ice:') && xBlock.includes('rc:') && xBlock.includes('if:'),
    'mentions ICE/RC/IF (art. 145-III)');
  assert.ok(xBlock.includes('subtotal_ht') && xBlock.includes('total_ttc'), 'totaux HT/TTC');
  assert.ok(xBlock.includes('tva_rate'), 'TVA par ligne');
  assert.ok(xBlock.includes('NOT_FOUND'), '404 facture introuvable');
});
