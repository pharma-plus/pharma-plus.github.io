#!/usr/bin/env python3
"""
PHASE 3 -- Import Excel CNOPS vers PHARMA+
Reconciliation EAN-13 vs catalogue existant + enrichissement + rapport
"""

import openpyxl
import re
import json
import hashlib
from datetime import datetime
from collections import defaultdict

EXCEL_PATH = r"C:\Users\Merouan\Documents\basse produit\ref-des-medicaments-cnops-2014.xlsx"

# ──────────────────────────────────────────────────────────────────────
# UTILITAIRES
# ──────────────────────────────────────────────────────────────────────

def validate_ean13(ean: str) -> tuple[bool, str]:
    """Valide un EAN-13 (format + cle de controle). Retourne (valide, code_normalise)."""
    if not ean:
        return False, ""
    # Nettoyer : garder seulement les chiffres
    digits = re.sub(r'\D', '', str(ean))
    if len(digits) != 13:
        return False, digits
    # Cle de controle EAN-13
    try:
        check = sum(int(digits[i]) * (1 if i % 2 == 0 else 3) for i in range(12))
        check = (10 - (check % 10)) % 10
        if check != int(digits[12]):
            return False, digits
    except (ValueError, IndexError):
        return False, digits
    return True, digits

def normalize_text(text: str) -> str:
    """Normalise pour comparaison (minuscules, accents, espaces)."""
    if not text:
        return ""
    import unicodedata
    text = unicodedata.normalize('NFD', str(text))
    text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
    return text.lower().strip()

def parse_price(val) -> float | None:
    """Parse un prix (gere virgule, espaces, None)."""
    if val is None or val == '':
        return None
    try:
        return float(str(val).replace(',', '.').replace(' ', ''))
    except (ValueError, TypeError):
        return None

def parse_pct(val) -> int | None:
    """Parse un taux de remboursement (ex: '70%' -> 70)."""
    if val is None or val == '':
        return None
    try:
        return int(str(val).replace('%', '').replace(',', '.').split('.')[0])
    except (ValueError, TypeError):
        return None

# ──────────────────────────────────────────────────────────────────────
# LECTURE EXCEL
# ──────────────────────────────────────────────────────────────────────

print("[BOOK] Lecture du fichier Excel...")
wb = openpyxl.load_workbook(EXCEL_PATH, read_only=True)
ws = wb.active

excel_rows = []
valid_ean = 0
invalid_ean = 0
duplicate_ean = 0
seen_eans = set()

for i, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
    code_raw, nom, dci1, dosage1, unite_dosage1, forme, presentation, ppv, ph, prix_br, princeps_generique, taux_remb = row
    
    # Validation EAN-13
    is_valid, ean_clean = validate_ean13(code_raw)
    if not is_valid:
        invalid_ean += 1
        ean_clean = None
    else:
        valid_ean += 1
        if ean_clean in seen_eans:
            duplicate_ean += 1
        seen_eans.add(ean_clean)
    
    excel_rows.append({
        'row_num': i,
        'ean13': ean_clean,
        'ean13_raw': str(code_raw) if code_raw else '',
        'ean13_valid': is_valid,
        'nom': str(nom).strip() if nom else '',
        'dci': str(dci1).strip() if dci1 else '',
        'dosage': str(dosage1).strip() if dosage1 else '',
        'unite_dosage': str(unite_dosage1).strip() if unite_dosage1 else '',
        'forme': str(forme).strip() if forme else '',
        'presentation': str(presentation).strip() if presentation else '',
        'ppv': parse_price(ppv),
        'ph': parse_price(ph),
        'prix_br': parse_price(prix_br),
        'princeps_generique': str(princeps_generique).strip() if princeps_generique else '',
        'taux_remboursement': parse_pct(taux_remb),
    })

wb.close()

print(f"[OK] Lu {len(excel_rows)} lignes")
print(f"   EAN-13 valides: {valid_ean}")
print(f"   EAN-13 invalides: {invalid_ean}")
print(f"   Doublons EAN-13: {duplicate_ean}")

# ──────────────────────────────────────────────────────────────────────
# RAPPROCHEMENT AVEC CATALOGUE EXISTANT (via API)
# ──────────────────────────────────────────────────────────────────────

# Pour l'instant, on simule la BDD existante avec les donnees seed (003_reference_data.sql)
# En production, on appellerait l'API /catalog/medications ou on ferait du SQL direct

# Charger les donnees de reference existantes (seed_demo)
reference_products = [
    {'ean13': '3400936055412', 'nom': 'Doliprane 1000mg', 'dci': 'Paracetamol', 'dosage': '1000 mg', 'forme': 'Comprime', 'presentation': 'Boite de 8', 'laboratory': 'Sanofi', 'ppv': 12.00, 'ph': 9.60, 'ppc': 8.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400933077190', 'nom': 'Efferalgan 500mg', 'dci': 'Paracetamol', 'dosage': '500 mg', 'forme': 'Comprime effervescent', 'presentation': 'Tube de 16', 'laboratory': 'UPSA', 'ppv': 16.50, 'ph': 13.20, 'ppc': 10.50, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400936544145', 'nom': 'Doliprane 1000mg Suppositoire', 'dci': 'Paracetamol', 'dosage': '1000 mg', 'forme': 'Suppositoire', 'presentation': 'Boite de 8', 'laboratory': 'Sanofi', 'ppv': 13.00, 'ph': 10.40, 'ppc': 8.50, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '6111345000012', 'nom': 'Ibuprofene Maphar 200mg', 'dci': 'Ibuprofene', 'dosage': '200 mg', 'forme': 'Comprime', 'presentation': 'Boite de 20', 'laboratory': 'Maphar', 'ppv': 12.00, 'ph': 9.60, 'ppc': 8.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400936079228', 'nom': 'Augmentin 1g', 'dci': 'Amoxicilline + Acide clavulanique', 'dosage': '1 g', 'forme': 'Comprime pellicule', 'presentation': 'Boite de 12', 'laboratory': 'GSK', 'ppv': 63.00, 'ph': 50.40, 'ppc': 42.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400930885763', 'nom': 'Amoxicilline Sandoz 500mg', 'dci': 'Amoxicilline', 'dosage': '500 mg', 'forme': 'Gelule', 'presentation': 'Boite de 12', 'laboratory': 'Sandoz', 'ppv': 14.00, 'ph': 11.20, 'ppc': 9.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400930196234', 'nom': 'Clamoxyl 500mg', 'dci': 'Amoxicilline', 'dosage': '500 mg', 'forme': 'Gelule', 'presentation': 'Boite de 12', 'laboratory': 'GSK', 'ppv': 13.50, 'ph': 10.80, 'ppc': 8.80, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400930181315', 'nom': 'Ventoline 100?g/dose', 'dci': 'Salbutamol', 'dosage': '100 ?g', 'forme': 'Spray inhalateur', 'presentation': 'Flacon 200 doses', 'laboratory': 'GSK', 'ppv': 38.00, 'ph': 30.40, 'ppc': 25.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400933417808', 'nom': 'Spiriva 18?g', 'dci': 'Tiotropium', 'dosage': '18 ?g', 'forme': 'Gelule inhalee', 'presentation': 'Boite de 30', 'laboratory': 'Boehringer Ingelheim', 'ppv': 110.00, 'ph': 88.00, 'ppc': 73.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400930114153', 'nom': 'Toplexil', 'dci': 'Oxomemazine', 'dosage': 'Sirop', 'forme': 'Sirop', 'presentation': 'Flacon 150 ml', 'laboratory': 'Sanofi', 'ppv': 21.00, 'ph': 16.80, 'ppc': 14.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400933332305', 'nom': 'Smecta', 'dci': 'Diosmectite', 'dosage': '3 g', 'forme': 'Poudre orale', 'presentation': 'Boite de 30 sachets', 'laboratory': 'Ipsen', 'ppv': 34.00, 'ph': 27.20, 'ppc': 22.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400932530324', 'nom': 'Spasfon 80mg', 'dci': 'Phloroglucinol', 'dosage': '80 mg', 'forme': 'Comprime', 'presentation': 'Boite de 30', 'laboratory': 'Teva', 'ppv': 27.00, 'ph': 21.60, 'ppc': 18.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400935963910', 'nom': 'Gaviscon Menthe', 'dci': 'Alginate de sodium', 'dosage': 'Suspension', 'forme': 'Suspension buvable', 'presentation': 'Flacon 250 ml', 'laboratory': 'Reckitt', 'ppv': 46.00, 'ph': 36.80, 'ppc': 30.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400934217121', 'nom': 'Aerius 5mg', 'dci': 'Desloratadine', 'dosage': '5 mg', 'forme': 'Comprime pellicule', 'presentation': 'Boite de 15', 'laboratory': 'MSD', 'ppv': 29.00, 'ph': 23.20, 'ppc': 19.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400933050520', 'nom': 'Telfast 120mg', 'dci': 'Fexofenadine', 'dosage': '120 mg', 'forme': 'Comprime pellicule', 'presentation': 'Boite de 15', 'laboratory': 'Sanofi', 'ppv': 41.00, 'ph': 32.80, 'ppc': 27.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400932411010', 'nom': 'Voltarene Emulgel 1%', 'dci': 'Diclofenac', 'dosage': '1 %', 'forme': 'Gel', 'presentation': 'Tube de 50 g', 'laboratory': 'Novartis', 'ppv': 42.00, 'ph': 33.60, 'ppc': 28.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400930112166', 'nom': 'Zyloric 100mg', 'dci': 'Allopurinol', 'dosage': '100 mg', 'forme': 'Comprime', 'presentation': 'Boite de 30', 'laboratory': 'GSK', 'ppv': 31.00, 'ph': 24.80, 'ppc': 20.50, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400935499093', 'nom': 'Kardegic 75mg', 'dci': 'Acetylsalicylate de lysine', 'dosage': '75 mg', 'forme': 'Poudre orale', 'presentation': 'Boite de 30 sachets', 'laboratory': 'Sanofi', 'ppv': 33.00, 'ph': 26.40, 'ppc': 22.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400930284716', 'nom': 'Lasilix 40mg', 'dci': 'Furosemide', 'dosage': '40 mg', 'forme': 'Comprime', 'presentation': 'Boite de 30', 'laboratory': 'Sanofi', 'ppv': 29.00, 'ph': 23.20, 'ppc': 19.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400930836897', 'nom': 'Betadine Dermique 10%', 'dci': 'Povidone iodee', 'dosage': '10 %', 'forme': 'Solution', 'presentation': 'Flacon 125 ml', 'laboratory': 'Meda', 'ppv': 28.00, 'ph': 22.40, 'ppc': 18.50, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400933763628', 'nom': 'Biseptine', 'dci': 'Chlorhexidine + Cetrimide', 'dosage': 'Antiseptique', 'forme': 'Solution', 'presentation': 'Flacon 250 ml', 'laboratory': 'Bayer', 'ppv': 20.00, 'ph': 16.00, 'ppc': 13.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400933351762', 'nom': 'Pivalone', 'dci': 'Tixocortol', 'dosage': '1 %', 'forme': 'Suspension nasale', 'presentation': 'Flacon 15 ml', 'laboratory': 'JABA', 'ppv': 35.00, 'ph': 28.00, 'ppc': 23.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400934538010', 'nom': 'Detralex 500mg', 'dci': 'Flavonoides', 'dosage': '500 mg', 'forme': 'Comprime pellicule', 'presentation': 'Boite de 60', 'laboratory': 'Servier', 'ppv': 72.00, 'ph': 57.60, 'ppc': 48.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400935885476', 'nom': 'Magne B6', 'dci': 'Magnesium + Vitamine B6', 'dosage': '100 mg', 'forme': 'Comprime', 'presentation': 'Boite de 60', 'laboratory': 'Sanofi', 'ppv': 56.00, 'ph': 44.80, 'ppc': 37.00, 'tva': 20.0, 'source': 'seed_demo'},
    {'ean13': '3400932521668', 'nom': 'Vitamine C UPSA 500mg', 'dci': 'Acide ascorbique', 'dosage': '500 mg', 'forme': 'Comprime effervescent', 'presentation': 'Tube de 24', 'laboratory': 'UPSA', 'ppv': 22.00, 'ph': 17.60, 'ppc': 14.50, 'tva': 20.0, 'source': 'seed_demo'},
]

# Index par EAN-13 pour lookup O(1)
ref_by_ean = {p['ean13']: p for p in reference_products}

# ──────────────────────────────────────────────────────────────────────
# ALGORITHME DE RAPPROCHEMENT
# ──────────────────────────────────────────────────────────────────────

results = {
    'enrichis': [],           # Produit existant enrichi
    'nouveaux': [],           # Nouveau produit a ajouter
    'conflits': [],           # Conflit (EAN deja utilise par autre produit, donnees contradictoires)
    'ean_invalides': [],      # EAN-13 invalide
    'doublons_excel': [],     # Doublons dans le fichier Excel
    'ignores': [],            # Lignes ignorees (raison)
}

# Pour detection doublons par nom normalise
nom_index = defaultdict(list)
for r in reference_products:
    nom_index[normalize_text(r['nom'])].append(r)

for row in excel_rows:
    ean = row['ean13']
    nom = row['nom']
    nom_norm = normalize_text(nom)
    
    if not row['ean13_valid']:
        results['ean_invalides'].append({
            'row': row['row_num'],
            'ean_raw': row['ean13_raw'],
            'nom': nom,
            'raison': 'EAN-13 invalide (format ou cle de controle)'
        })
        continue
    
    if row['ean13_raw'] in seen_eans and list(seen_eans).count(row['ean13_raw']) > 1:
        results['doublons_excel'].append({
            'row': row['row_num'],
            'ean13': ean,
            'nom': nom,
        })
        continue
    
    # 1. Match exact par EAN-13
    if ean in ref_by_ean:
        existing = ref_by_ean[ean]
        # Verifier si enrichissement necessaire
        enrichissements = []
        if not existing.get('dci') and row['dci']:
            enrichissements.append(('dci', row['dci']))
        if not existing.get('dosage') and row['dosage']:
            enrichissements.append(('dosage', row['dosage']))
        if not existing.get('forme') and row['forme']:
            enrichissements.append(('forme', row['forme']))
        if not existing.get('presentation') and row['presentation']:
            enrichissements.append(('presentation', row['presentation']))
        if existing.get('ppv') is None and row['ppv'] is not None:
            enrichissements.append(('ppv', row['ppv']))
        if existing.get('ph') is None and row['ph'] is not None:
            enrichissements.append(('ph', row['ph']))
        if existing.get('ppc') is None and row['prix_br'] is not None:
            enrichissements.append(('ppc', row['prix_br']))
        
        # Detecter contradictions
        contradictions = []
        if existing.get('dci') and row['dci'] and normalize_text(existing['dci']) != normalize_text(row['dci']):
            contradictions.append(f"DCI: '{existing['dci']}' vs '{row['dci']}'")
        if existing.get('nom') and normalize_text(existing['nom']) != nom_norm:
            contradictions.append(f"NOM: '{existing['nom']}' vs '{nom}'")
        
        if contradictions:
            results['conflits'].append({
                'ean13': ean,
                'existant': existing,
                'excel': row,
                'contradictions': contradictions,
            })
        elif enrichissements:
            results['enrichis'].append({
                'ean13': ean,
                'existant': existing,
                'enrichissements': enrichissements,
                'excel_data': {k: v for k, v in row.items() if k not in ['row_num', 'ean13_raw', 'ean13_valid']},
            })
        else:
            results['ignores'].append({
                'ean13': ean,
                'raison': 'Produit deja complet et coherent',
            })
        continue
    
    # 2. Match par nom normalise (si EAN absent de la BDD)
    matches = nom_index.get(nom_norm, [])
    if matches:
        # Plusieurs correspondances possibles → conflit
        if len(matches) > 1:
            results['conflits'].append({
                'ean13': ean,
                'excel': row,
                'matches': matches,
                'raison': f"Multiple matches par nom ({len(matches)} produits)",
            })
        else:
            match = matches[0]
            # Verifier si EAN du match est libre
            if match['ean13'] != ean:
                # L'EAN du fichier Excel differe de celui en BDD
                results['conflits'].append({
                    'ean13': ean,
                    'existant': match,
                    'excel': row,
                    'contradictions': [f"EAN different: BDD={match['ean13']} vs Excel={ean}"],
                })
            else:
                # Meme EAN (cas deja traite ci-dessus normalement)
                results['ignores'].append({
                    'ean13': ean,
                    'raison': 'Match par nom, EAN coherent',
                })
        continue
    
    # 3. Aucun match ? nouveau produit candidat
    # Verifier si l'EAN est deja utilise par un AUTRE produit en BDD (impossible ici car ref_by_ean check)
    results['nouveaux'].append({
        'ean13': ean,
        'nom': row['nom'],
        'dci': row['dci'],
        'dosage': row['dosage'],
        'unite_dosage': row['unite_dosage'],
        'forme': row['forme'],
        'presentation': row['presentation'],
        'ppv': row['ppv'],
        'ph': row['ph'],
        'ppc': row['prix_br'],
        'princeps_generique': row['princeps_generique'],
        'taux_remboursement': row['taux_remboursement'],
        'source': 'cnops_2014',
    })

# ──────────────────────────────────────────────────────────────────────
# RAPPORT FINAL
# ──────────────────────────────────────────────────────────────────────

report = {
    'metadata': {
        'date_import': datetime.now().isoformat(),
        'fichier_source': 'ref-des-medicaments-cnops-2014.xlsx',
        'lignes_totales': len(excel_rows),
        'ean_valides': valid_ean,
        'ean_invalides': invalid_ean,
        'doublons_ean': duplicate_ean,
    },
    'resultats': {
        'produits_enrichis': len(results['enrichis']),
        'nouveaux_produits': len(results['nouveaux']),
        'conflits': len(results['conflits']),
        'ean_invalides': len(results['ean_invalides']),
        'doublons_excel': len(results['doublons_excel']),
        'ignores': len(results['ignores']),
    },
    'details': results,
}

# Sauvegarder rapport JSON
report_path = f"cnops_import_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
with open(report_path, 'w', encoding='utf-8') as f:
    json.dump(report, f, ensure_ascii=False, indent=2)

# Afficher resume
print("\n" + "="*60)
print("[CHART] RAPPORT D'IMPORT CNOPS 2014")
print("="*60)
print(f"Lignes Excel analysees:      {len(excel_rows)}")
print(f"EAN-13 valides:              {valid_ean}")
print(f"EAN-13 invalides:            {invalid_ean}")
print(f"Doublons EAN dans Excel:     {duplicate_ean}")
print("-"*60)
print(f"[OK] Produits enrichis:        {len(results['enrichis'])}")
print(f"[+] Nouveaux produits:          {len(results['nouveaux'])}")
print(f"[WARN]  Conflits detectes:        {len(results['conflits'])}")
print(f"[ERR] EAN invalides:            {len(results['ean_invalides'])}")
print(f"[REFRESH] Doublons Excel:            {len(results['doublons_excel'])}")
print(f"?  Ignores (deja complets):   {len(results['ignores'])}")
print("-"*60)
print(f"Rapport sauvegarde: {report_path}")

# Afficher quelques exemples
if results['enrichis']:
    print(f"\n[MEMO] Exemples enrichis:")
    for e in results['enrichis'][:3]:
        print(f"  - {e['ean13']} | {e['existant']['nom']} ? +{len(e['enrichissements'])} champs")

if results['nouveaux']:
    print(f"\n? Exemples nouveaux:")
    for n in results['nouveaux'][:5]:
        print(f"  - {n['ean13']} | {n['nom']} | PPV={n['ppv']} | {n['forme']}")

if results['conflits']:
    print(f"\n[WARN]  Conflits:")
    for c in results['conflits'][:5]:
        print(f"  - EAN={c.get('ean13', 'N/A')} | {c.get('raison', c.get('contradictions', []))}")

if results['ean_invalides']:
    print(f"\n[ERR] EAN invalides (premiers 10):")
    for inv in results['ean_invalides'][:10]:
        print(f"  - Ligne {inv['row']}: {inv['ean_raw']} ? {inv['nom'][:50]}")

print("\n[OK] Phase 3 -- Import Excel CNOPS : ANALYSE TERMIN?E")
print("   Prochaine etape: Validation manuelle des conflits + generation SQL d'import")