#!/usr/bin/env python3
"""
Génère le SQL complet pour les 5892 produits CNOPS
"""

import json
import re

# Charger le rapport d'import
with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\cnops_import_report_20261031_133821.json', 'r', encoding='utf-8') as f:
    report = json.load(f)

nouveaux = report['details']['nouveaux']

# Mapping DCI -> famille thérapeutique (simplifié)
DCI_TO_FAMILY = {
    'PARACETAMOL': 'ANALG', 'IBUPROFENE': 'ANALG', 'ASPIRINE': 'ANALG', 'KETOPROFENE': 'ANALG',
    'AMOXICILLINE': 'INFECT', 'CEFACLOR': 'INFECT', 'CEFOTAXIME': 'INFECT', 'CIPROFLOXACINE': 'INFECT',
    'FLUCONAZOLE': 'INFECT', 'METRONIDAZOLE': 'INFECT', 'SPIRAMYCINE': 'INFECT',
    'SALBUTAMOL': 'RESPIRATOIRE', 'FLUTICASONE': 'RESPIRATOIRE', 'BUDESONIDE': 'RESPIRATOIRE',
    'OMEPRAZOLE': 'GASTRO', 'LANSOPRAZOLE': 'GASTRO', 'RANITIDINE': 'GASTRO',
    'GLICLAZIDE': 'ENDOCRINO', 'METFORMINE': 'ENDOCRINO', 'INSULINE': 'ENDOCRINO',
    'AMLODIPINE': 'CARDIO', 'PERINDOPRIL': 'CARDIO', 'BISOPROLOL': 'CARDIO', 'FUROSEMIDE': 'CARDIO',
    'DICLOFENAC': 'MUSCULO', 'MEBEVERINE': 'GASTRO', 'DOMPERIDONE': 'GASTRO',
    'LORAZEPAM': 'NERVOUS', 'DIAZEPAM': 'NERVOUS', 'ALPRAZOLAM': 'NERVOUS',
    'CETIRIZINE': 'ALLERGIE', 'LORATADINE': 'ALLERGIE', 'DESLORATADINE': 'ALLERGIE',
    'ATENOLOL': 'CARDIO', 'ENALAPRIL': 'CARDIO', 'LOSARTAN': 'CARDIO',
    'SIMVASTATINE': 'CARDIO', 'ATORVASTATINE': 'CARDIO', 'ROSUVASTATINE': 'CARDIO',
    'METOPROLOL': 'CARDIO', 'CARVEDILOL': 'CARDIO', 'INDAPAMIDE': 'CARDIO',
    'ALLOPURINOL': 'MUSCULO', 'COLCHICINE': 'MUSCULO',
    'SERTRALINE': 'NERVOUS', 'FLUOXETINE': 'NERVOUS', 'PAROXETINE': 'NERVOUS',
    'CITALOPRAM': 'NERVOUS', 'ESCITALOPRAM': 'NERVOUS', 'VENLAFAXINE': 'NERVOUS',
    'QUETIAPINE': 'NERVOUS', 'OLANZAPINE': 'NERVOUS', 'RISPERIDONE': 'NERVOUS',
    'VALPROATE': 'NERVOUS', 'LAMOTRIGINE': 'NERVOUS', 'LEVETIRACETAM': 'NERVOUS',
    'TOPIRAMATE': 'NERVOUS', 'GABAPENTINE': 'NERVOUS', 'PREGABALINE': 'NERVOUS',
    'DONEPEZIL': 'NERVOUS', 'MEMANTINE': 'NERVOUS', 'RIVASTIGMINE': 'NERVOUS',
    'TAMSULOSINE': 'URO', 'FINASTERIDE': 'URO', 'DUTASTERIDE': 'URO',
    'SILDENAFIL': 'URO', 'TADALAFIL': 'URO',
    'BIMATOPROST': 'OPHTALMO', 'LATANOPROST': 'OPHTALMO', 'TIMOLOL': 'OPHTALMO',
    'CICLOSPORINE': 'IMMUNO', 'TACROLIMUS': 'IMMUNO', 'MYCOPHENOLATE': 'IMMUNO',
    'RITUXIMAB': 'IMMUNO', 'ADALIMUMAB': 'IMMUNO', 'ETANERCEPT': 'IMMUNO',
    'INFLIXIMAB': 'IMMUNO', 'CERTOLIZUMAB': 'IMMUNO', 'GOLIMUMAB': 'IMMUNO',
    'TOCILIZUMAB': 'IMMUNO', 'ABATACEPT': 'IMMUNO', 'RITUXIMAB': 'IMMUNO',
    'BEVACIZUMAB': 'ANTINEO', 'TRASTUZUMAB': 'ANTINEO', 'RITUXIMAB': 'ANTINEO',
    'CETUXIMAB': 'ANTINEO', 'PANITUMUMAB': 'ANTINEO', 'OXALIPLATINE': 'ANTINEO',
    'CARBOPLATINE': 'ANTINEO', 'CISPLATINE': 'ANTINEO', 'PACLITAXEL': 'ANTINEO',
    'DOCETAXEL': 'ANTINEO', 'GEMCITABINE': 'ANTINEO', 'CAPECITABINE': 'ANTINEO',
    'IMATINIB': 'ANTINEO', 'DASATINIB': 'ANTINEO', 'NILOTINIB': 'ANTINEO',
    'GEFITINIB': 'ANTINEO', 'ERLOTINIB': 'ANTINEO', 'CRIZOTINIB': 'ANTINEO',
    'CERITINIB': 'ANTINEO', 'ALECTINIB': 'ANTINEO', 'BRIGATINIB': 'ANTINEO',
    'LORLATINIB': 'ANTINEO', 'ENTRECTINIB': 'ANTINEO', 'LAROTRECTINIB': 'ANTINEO',
    'PEMBROLIZUMAB': 'ANTINEO', 'NIVOLUMAB': 'ANTINEO', 'IPLIMUMAB': 'ANTINEO',
    'ATEZOLIZUMAB': 'ANTINEO', 'DURVALUMAB': 'ANTINEO', 'AVELUMAB': 'ANTINEO',
}

def get_family(dci):
    dci_upper = dci.upper() if dci else ''
    for key, fam in DCI_TO_FAMILY.items():
        if key in dci_upper:
            return fam
    return 'DIVERS'

def get_category(family):
    cat_map = {
        'ANALG': 'Antalgiques / Antipyrétiques',
        'ANTINEO': 'Cancérologie / Immunomodulation',
        'CARDIO': 'Cardiologie',
        'DERMATO': 'Dermatologie',
        'ENDOCRINO': 'Endocrinologie / Métabolisme',
        'GASTRO': 'Gastro-entérologie',
        'GYNECO': 'Gynécologie',
        'HEMATO': 'Hématologie',
        'IMMUNO': 'Immunologie',
        'INFECT': 'Infectiologie / Parasitologie',
        'MUSCULO': 'Rhumatologie',
        'NERVOUS': 'Neurologie / Psychiatrie',
        'OPHTALMO': 'Ophtalmologie',
        'ORL': 'ORL / Stomatologie',
        'PNEUMO': 'Pneumologie / Allergologie',
        'RENAL': 'Urologie / Néphrologie',
        'RESPIRATOIRE': 'Pneumologie / Allergologie',
        'URO': 'Urologie / Néphrologie',
        'VASCULAIRE': 'Veinologie',
        'ALLERGIE': 'Allergologie',
        'IMMUNO': 'Immunologie',
        'DIVERS': 'Divers',
    }
    return cat_map.get(family, 'Divers')

def escape_sql(s):
    if s is None:
        return 'NULL'
    if isinstance(s, (int, float)):
        return str(s)
    return "'" + str(s).replace("'", "''") + "'"

# Charger le rapport
with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\cnops_import_report_20261031_133821.json', 'r', encoding='utf-8') as f:
    report = json.load(f)

nouveaux = report['details']['nouveaux']

print(f"Génération SQL pour {len(nouveaux)} produits...")

sql_lines = []
sql_lines.append("-- ============================================================")
sql_lines.append("-- PHARMA MAROC GOLD — IMPORT CNOPS 2014 (5 892 produits)")
sql_lines.append("-- Généré automatiquement le 2026-10-31")
sql_lines.append("-- ============================================================")
sql_lines.append("")
sql_lines.append("-- ------------------------------------------------------------")
sql_lines.append("-- 1. FAMILLES THÉRAPEUTIQUES")
sql_lines.append("-- ------------------------------------------------------------")
families = set()
for p in nouveaux:
    fam = get_family(p['dci'])
    families.add((fam, get_category(fam)))

for code, name in sorted(families):
    sql_lines.append(f"INSERT INTO therapeutic_families (pharmacy_id, code, name) VALUES")
    sql_lines.append(f"  ('11111111-1111-1111-1111-111111111111', '{code}', '{name}')")
    sql_lines.append("ON CONFLICT (pharmacy_id, code) DO NOTHING;")
    sql_lines.append("")

sql_lines.append("-- ------------------------------------------------------------")
sql_lines.append("-- 2. LABORATOIRES (extrait CNOPS)")
sql_lines.append("-- ------------------------------------------------------------")
# Extraire les laboratoires uniques depuis les données CNOPS
labs = set()
for p in nouveaux:
    # On n'a pas le labo dans les données brutes, on va utiliser un mapping DCI->labo approximatif
    pass

# Labs principaux connus
main_labs = ['SANOFI', 'GSK', 'PFIZER', 'NOVARTIS', 'ROCHE', 'BAYER', 'MERCK', 'SANDOZ', 'TEVA', 'UPSA', 'SERVIER', 'BOEHRINGER', 'ASTRAZENECA', 'LUNDBECK', 'JANSSEN', 'TAKEDA', 'EISAI', 'DAIICHI SANKYO', 'ALLERGAN', 'BIOGARAN', 'IPSEN', 'MUNDIPHARMA', 'NOVO NORDISK', 'GILEAD', 'BRISTOL-MYERS', 'AMGEN', 'ALKERMES', 'ACTAVIS', 'ALLERGAN']
for lab in sorted(main_labs):
    sql_lines.append(f"INSERT INTO laboratories (pharmacy_id, name, country) VALUES")
    sql_lines.append(f"  ('11111111-1111-1111-1111-111111111111', '{lab}', 'Inconnu')")
    sql_lines.append("ON CONFLICT (pharmacy_id, name) DO NOTHING;")
    sql_lines.append("")

sql_lines.append("-- ------------------------------------------------------------")
sql_lines.append("-- 3. MÉDICAMENTS (5 892 produits)")
sql_lines.append("-- ------------------------------------------------------------")
sql_lines.append("")

def get_lab_from_dci(dci):
    dci_upper = dci.upper() if dci else ''
    if 'SANOFI' in dci_upper or 'SANOFI' in dci_upper: return 'SANOFI'
    if 'GSK' in dci_upper: return 'GSK'
    if 'PFIZER' in dci_upper: return 'PFIZER'
    if 'NOVARTIS' in dci_upper: return 'NOVARTIS'
    if 'ROCHE' in dci_upper: return 'ROCHE'
    if 'BAYER' in dci_upper: return 'BAYER'
    if 'MERCK' in dci_upper: return 'MERCK'
    if 'SANDOZ' in dci_upper: return 'SANDOZ'
    if 'TEVA' in dci_upper: return 'TEVA'
    if 'UPSA' in dci_upper: return 'UPSA'
    if 'SERVIER' in dci_upper: return 'SERVIER'
    if 'BOEHRINGER' in dci_upper: return 'BOEHRINGER'
    if 'ASTRAZENECA' in dci_upper: return 'ASTRAZENECA'
    if 'LUNDBECK' in dci_upper: return 'LUNDBECK'
    if 'JANSSEN' in dci_upper: return 'JANSSEN'
    if 'TAKEDA' in dci_upper: return 'TAKEDA'
    if 'EISAI' in dci_upper: return 'EISAI'
    if 'DAIICHI' in dci_upper: return 'DAIICHI SANKYO'
    if 'ALLERGAN' in dci_upper: return 'ALLERGAN'
    if 'BIOGARAN' in dci_upper: return 'BIOGARAN'
    if 'IPSEN' in dci_upper: return 'IPSEN'
    if 'MUNDIPHARMA' in dci_upper: return 'MUNDIPHARMA'
    if 'NOVO' in dci_upper: return 'NOVO NORDISK'
    if 'GILEAD' in dci_upper: return 'GILEAD'
    if 'BRISTOL' in dci_upper: return 'BRISTOL-MYERS'
    if 'AMGEN' in dci_upper: return 'AMGEN'
    if 'ALKERMES' in dci_upper: return 'ALKERMES'
    if 'ACTAVIS' in dci_upper: return 'ACTAVIS'
    if 'ALLERGAN' in dci_upper: return 'ALLERGAN'
    return 'INCONNU'

batch_size = 100
total = len(nouveaux)

for idx, p in enumerate(nouveaux):
    if idx % batch_size == 0:
        print(f"  Progression: {idx}/{total} ({idx*100//total}%)")
    
    fam = get_family(p['dci'])
    cat = get_category(fam)
    lab = get_lab_from_dci(p['dci'])
    
    # Construire l'INSERT
    vals = [
        "'11111111-1111-1111-1111-111111111111'",  # pharmacy_id
        f"(SELECT id FROM categories WHERE pharmacy_id='11111111-1111-1111-1111-111111111111' AND name={escape_sql(cat)} LIMIT 1)",
        f"(SELECT id FROM therapeutic_families WHERE pharmacy_id='11111111-1111-1111-1111-111111111111' AND code='{fam}' LIMIT 1)",
        f"(SELECT id FROM laboratories WHERE pharmacy_id='11111111-1111-1111-1111-111111111111' AND name='{get_lab_from_dci(p['dci'])}' LIMIT 1)",
        escape_sql(p['nom']),
        escape_sql(p['dci']),
        escape_sql(p['dosage']),
        escape_sql(p['forme']),
        escape_sql(p['presentation']),
        escape_sql(p['ean13']),
        str(p['ppv']) if p['ppv'] is not None else '0',
        str(p['ph']) if p['ph'] is not None else '0',
        '20.00',
        'false' if p.get('princeps_generique') != 'G' else 'false',  # prescription_required
        '5',
        '2',
        "'available'",
        'false',
        'false'
    ]
    
    sql = f"INSERT INTO medications (pharmacy_id, category_id, family_id, laboratory_id, name, dci, dosage, form, presentation, barcode_ean13, price_purchase, price_sale, tva_rate, prescription_required, reorder_level, min_stock, status, is_public, is_parapharmacie) VALUES\n  ({', '.join(vals)});"
    sql_lines.append(sql)
    sql_lines.append("")

# Écrire le fichier
output_path = r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\database\seeds\004_cnops_import_full.sql'
with open(output_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(sql_lines))

print(f"\n[OK] Fichier SQL généré: {output_path}")
print(f"   {len(nouveaux)} produits")
print(f"   {len(sql_lines)} lignes SQL")