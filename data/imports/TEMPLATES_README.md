# Templates d'import

Formats fournis : **CSV** (ouvrable nativement dans Excel/LibreOffice — équivalent XLSX sans dépendance binaire) et **JSON**.

## Laboratoires (`laboratories_template.csv` / `.json`)
- `nom_original` : **obligatoire** (nom affiché tel quel).
- `laboratory_id`, `nom_normalise`, `fabricant`, `exploitant`, `source`, `nombre_de_produits` : facultatifs, traçabilité.
- Import : `node data/imports/import_laboratories.mjs chemin.csv` (dry-run) puis `--apply`.
- Idempotent : un labo au nom normalisé identique n'est jamais recréé ; les variantes orthographiques proches sont signalées mais **jamais fusionnées automatiquement**.

## Fournisseurs (`suppliers_template.csv` / `.json`)
- `name` : **obligatoire**.
- Tous les autres champs : facultatifs — **jamais inventés** ; un champ vide laisse la valeur existante intacte.
- `type` : `laboratoire` | `grossiste` | `autre` (un grossiste distribue plusieurs laboratoires — ne pas confondre).
- `status` : `active` | `inactive`.
- Import : `node data/imports/import_suppliers.mjs chemin.csv` (dry-run) puis `--apply`.
- Rapports : `reports/imports/import_*.json` + backups JSON réversibles.

Rapports d'import : `reports/imports/`. Aucun secret ni donnée bancaire dans un template.
