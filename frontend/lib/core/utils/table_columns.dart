/// Système de largeurs de colonnes standardisées pour PHARMA+.
/// 
/// Règles :
/// - Codes, quantités, pourcentages, statuts, petites valeurs → COMPACT (60-100px)
/// - Dates → DATE (100-120px)
/// - Noms, descriptions → FLEXIBLE (min 180px, flex 1-3)
/// - Prix, montants → MONEY (90-120px, align right)
/// - Actions → ACTIONS (48-64px fixe)
/// 
/// Breakpoints responsive :
/// - Mobile (<600px) : cartes (ListView/GridView), pas de tableau
/// - Tablette (600-1024px) : tableau avec colonnes compactes, scroll horizontal
/// - Desktop (>1024px) : tableau complet, colonnes flexibles

library;

import 'package:flutter/material.dart';
import '../widgets/shared/app_data_table.dart';

/// Types de colonnes sémantiques — chaque type a une largeur par défaut,
/// min/max, et alignement adaptés au contenu.
enum TableColumnType {
  // === COMPACTES (contenu court, ≤ 4-6 caractères) ===
  /// Code court, identifiant, référence (ex: EAN-13, code interne)
  code,
  /// Quantité entière (ex: 12, 0, 999)
  quantity,
  /// Pourcentage (ex: 20%, 70%)
  percent,
  /// Statut court (ex: "Actif", "Rupture", "En cours")
  status,
  /// Note/évaluation (ex: 4.5, ★★★★☆)
  rating,
  /// Booléen / icône (ex: ✓, ✗, icône)
  flag,

  // === DATES ===
  /// Date courte (JJ/MM/AAAA)
  date,
  /// Date + heure (JJ/MM/AAAA HH:MM)
  datetime,

  // === MONTANTS ===
  /// Prix unitaire, montant (aligné à droite)
  money,
  /// Montant petit (ex: remise, taxe)
  smallMoney,

  // === TEXTES ===
  /// Nom principal (médicament, client, fournisseur) — flexible, min 180px
  name,
  /// Description, détail, présentation — flexible, min 140px
  description,
  /// Texte libre moyen (adresse, note)
  text,
  /// Texte long (composition, notice) — flexible, min 200px
  longText,

  // === ACTIONS ===
  /// Colonne actions (boutons voir/éditer/supprimer) — fixe compacte
  actions,
  /// Colonne actions étendue (plus de boutons)
  actionsWide,

  // === SPÉCIAUX ===
  /// Numéro de ligne / index
  rowNumber,
  /// Case à cocher sélection
  checkbox,
}

/// Configuration de largeur pour un type de colonne.
class ColumnWidthConfig {
  const ColumnWidthConfig({
    required this.defaultWidth,
    required this.minWidth,
    required this.maxWidth,
    this.flex,
    this.alignment = TextAlign.start,
    this.numeric = false,
  });

  final double defaultWidth;
  final double minWidth;
  final double maxWidth;
  final int? flex; // Si non-null, la colonne est flexible (Expanded)
  final TextAlign alignment;
  final bool numeric;
}

/// Registre des configurations par type de colonne.
/// 
/// Les valeurs sont optimisées pour :
/// - Lisibilité : contenu non tronqué dans 95% des cas
/// - Compacité : pas d'espace gaspillé
/// - Responsive : minWidth permet le scroll horizontal sur tablette
class TableColumnWidths {
  static const Map<TableColumnType, ColumnWidthConfig> _configs = {
    // COMPACTES
    TableColumnType.code: ColumnWidthConfig(
      defaultWidth: 110,
      minWidth: 90,
      maxWidth: 140,
      alignment: TextAlign.center,
    ),
    TableColumnType.quantity: ColumnWidthConfig(
      defaultWidth: 80,
      minWidth: 60,
      maxWidth: 100,
      alignment: TextAlign.right,
      numeric: true,
    ),
    TableColumnType.percent: ColumnWidthConfig(
      defaultWidth: 70,
      minWidth: 60,
      maxWidth: 90,
      alignment: TextAlign.right,
      numeric: true,
    ),
    TableColumnType.status: ColumnWidthConfig(
      defaultWidth: 100,
      minWidth: 90,
      maxWidth: 130,
      alignment: TextAlign.center,
    ),
    TableColumnType.rating: ColumnWidthConfig(
      defaultWidth: 60,
      minWidth: 50,
      maxWidth: 80,
      alignment: TextAlign.center,
      numeric: true,
    ),
    TableColumnType.flag: ColumnWidthConfig(
      defaultWidth: 48,
      minWidth: 40,
      maxWidth: 60,
      alignment: TextAlign.center,
    ),

    // DATES
    TableColumnType.date: ColumnWidthConfig(
      defaultWidth: 105,
      minWidth: 95,
      maxWidth: 120,
      alignment: TextAlign.center,
    ),
    TableColumnType.datetime: ColumnWidthConfig(
      defaultWidth: 140,
      minWidth: 125,
      maxWidth: 160,
      alignment: TextAlign.center,
    ),

    // MONTANTS
    TableColumnType.money: ColumnWidthConfig(
      defaultWidth: 100,
      minWidth: 90,
      maxWidth: 130,
      alignment: TextAlign.right,
      numeric: true,
    ),
    TableColumnType.smallMoney: ColumnWidthConfig(
      defaultWidth: 80,
      minWidth: 70,
      maxWidth: 100,
      alignment: TextAlign.right,
      numeric: true,
    ),

    // TEXTES
    TableColumnType.name: ColumnWidthConfig(
      defaultWidth: 220,
      minWidth: 180,
      maxWidth: 400,
      flex: 2,
      alignment: TextAlign.start,
    ),
    TableColumnType.description: ColumnWidthConfig(
      defaultWidth: 160,
      minWidth: 140,
      maxWidth: 300,
      flex: 1,
      alignment: TextAlign.start,
    ),
    TableColumnType.text: ColumnWidthConfig(
      defaultWidth: 180,
      minWidth: 140,
      maxWidth: 300,
      flex: 1,
      alignment: TextAlign.start,
    ),
    TableColumnType.longText: ColumnWidthConfig(
      defaultWidth: 240,
      minWidth: 200,
      maxWidth: 400,
      flex: 2,
      alignment: TextAlign.start,
    ),

    // ACTIONS
    TableColumnType.actions: ColumnWidthConfig(
      defaultWidth: 56,
      minWidth: 48,
      maxWidth: 72,
      alignment: TextAlign.center,
    ),
    TableColumnType.actionsWide: ColumnWidthConfig(
      defaultWidth: 80,
      minWidth: 72,
      maxWidth: 100,
      alignment: TextAlign.center,
    ),

    // SPÉCIAUX
    TableColumnType.rowNumber: ColumnWidthConfig(
      defaultWidth: 48,
      minWidth: 40,
      maxWidth: 60,
      alignment: TextAlign.right,
      numeric: true,
    ),
    TableColumnType.checkbox: ColumnWidthConfig(
      defaultWidth: 48,
      minWidth: 44,
      maxWidth: 56,
      alignment: TextAlign.center,
    ),
  };

  /// Récupère la config pour un type.
  static ColumnWidthConfig get(TableColumnType type) => _configs[type]!;

  /// Récupère la largeur par défaut.
  static double width(TableColumnType type) => _configs[type]!.defaultWidth;

  /// Récupère la largeur min.
  static double minWidth(TableColumnType type) => _configs[type]!.minWidth;

  /// Récupère la largeur max.
  static double maxWidth(TableColumnType type) => _configs[type]!.maxWidth;

  /// Récupère l'alignement.
  static TextAlign alignment(TableColumnType type) => _configs[type]!.alignment;

  /// Récupère le flex (null = largeur fixe).
  static int? flex(TableColumnType type) => _configs[type]!.flex;

  /// Vérifie si la colonne est numérique.
  static bool isNumeric(TableColumnType type) => _configs[type]!.numeric;

  /// Crée un `AppDataColumn` préconfiguré pour le type.
  /// 
  /// Exemple :
  /// ```dart
  /// AppDataColumn<Map<String, dynamic>> col = TableColumnWidths.column(
  ///   key: 'price_sale',
  ///   label: 'PPV',
  ///   type: TableColumnType.money,
  /// );
  /// ```
  static AppDataColumn<T> column<T>({
    required String key,
    required String label,
    required TableColumnType type,
    bool? sortable,
    bool? filterable,
    List<String>? filterOptions,
    Widget Function(BuildContext, T, int)? cellBuilder,
    bool visible = true,
  }) {
    final cfg = _configs[type]!;
    return AppDataColumn<T>(
      key: key,
      label: label,
      width: cfg.defaultWidth,
      minWidth: cfg.minWidth,
      maxWidth: cfg.maxWidth,
      flex: cfg.flex,
      alignment: cfg.alignment,
      numeric: cfg.numeric,
      sortable: sortable ?? true,
      filterable: filterable ?? false,
      filterOptions: filterOptions,
      cellBuilder: cellBuilder,
      visible: visible,
    );
  }
}

/// Helper pour créer plusieurs colonnes d'un coup.
class TableColumns {
  /// Colonnes standards pour liste médicaments/catalogue.
  static List<AppDataColumn<Map<String, dynamic>>> medications(String locale) => [
        TableColumnWidths.column(
          key: 'name',
          label: 'Médicament',
          type: TableColumnType.name,
        ),
        TableColumnWidths.column(
          key: 'dci',
          label: 'DCI',
          type: TableColumnType.description,
        ),
        TableColumnWidths.column(
          key: 'dosage',
          label: 'Dosage',
          type: TableColumnType.code,
        ),
        TableColumnWidths.column(
          key: 'form',
          label: 'Forme',
          type: TableColumnType.code,
        ),
        TableColumnWidths.column(
          key: 'laboratory_name',
          label: 'Laboratoire',
          type: TableColumnType.description,
        ),
        TableColumnWidths.column(
          key: 'price_sale',
          label: 'PPV',
          type: TableColumnType.money,
        ),
        TableColumnWidths.column(
          key: 'status',
          label: 'Statut',
          type: TableColumnType.status,
        ),
        TableColumnWidths.column(
          key: 'stock',
          label: 'Stock',
          type: TableColumnType.quantity,
        ),
        TableColumnWidths.column(
          key: 'actions',
          label: 'Actions',
          type: TableColumnType.actions,
          cellBuilder: _defaultActionsCellBuilder,
        ),
      ];

  /// Colonnes standards pour liste fournisseurs.
  static List<AppDataColumn<Map<String, dynamic>>> suppliers(String locale) => [
        TableColumnWidths.column(
          key: 'name',
          label: 'Fournisseur',
          type: TableColumnType.name,
        ),
        TableColumnWidths.column(
          key: 'city',
          label: 'Ville',
          type: TableColumnType.code,
        ),
        TableColumnWidths.column(
          key: 'contact_name',
          label: 'Contact',
          type: TableColumnType.description,
        ),
        TableColumnWidths.column(
          key: 'rating',
          label: 'Note',
          type: TableColumnType.rating,
        ),
        TableColumnWidths.column(
          key: 'nb_orders',
          label: 'Commandes',
          type: TableColumnType.quantity,
        ),
        TableColumnWidths.column(
          key: 'actions',
          label: 'Actions',
          type: TableColumnType.actions,
          cellBuilder: _defaultActionsCellBuilder,
        ),
      ];

  /// Colonnes standards pour liste clients.
  static List<AppDataColumn<Map<String, dynamic>>> customers(String locale) => [
        TableColumnWidths.column(
          key: 'name',
          label: 'Client',
          type: TableColumnType.name,
        ),
        TableColumnWidths.column(
          key: 'phone',
          label: 'Téléphone',
          type: TableColumnType.code,
        ),
        TableColumnWidths.column(
          key: 'email',
          label: 'Email',
          type: TableColumnType.description,
        ),
        TableColumnWidths.column(
          key: 'credit_balance',
          label: 'Crédit',
          type: TableColumnType.money,
        ),
        TableColumnWidths.column(
          key: 'total_spent',
          label: 'Total achats',
          type: TableColumnType.money,
        ),
        TableColumnWidths.column(
          key: 'actions',
          label: 'Actions',
          type: TableColumnType.actions,
          cellBuilder: _defaultActionsCellBuilder,
        ),
      ];

  /// Colonnes standards pour commandes d'achat.
  static List<AppDataColumn<Map<String, dynamic>>> purchaseOrders(String locale) => [
        TableColumnWidths.column(
          key: 'number',
          label: 'N° commande',
          type: TableColumnType.code,
        ),
        TableColumnWidths.column(
          key: 'supplier_name',
          label: 'Fournisseur',
          type: TableColumnType.name,
        ),
        TableColumnWidths.column(
          key: 'order_date',
          label: 'Date',
          type: TableColumnType.date,
        ),
        TableColumnWidths.column(
          key: 'status',
          label: 'Statut',
          type: TableColumnType.status,
        ),
        TableColumnWidths.column(
          key: 'total',
          label: 'Total',
          type: TableColumnType.money,
        ),
        TableColumnWidths.column(
          key: 'actions',
          label: 'Actions',
          type: TableColumnType.actions,
          cellBuilder: _defaultActionsCellBuilder,
        ),
      ];

  /// Colonnes standards pour stock (par lot).
  static List<AppDataColumn<Map<String, dynamic>>> stockLots(String locale) => [
        TableColumnWidths.column(
          key: 'medication_name',
          label: 'Médicament',
          type: TableColumnType.name,
        ),
        TableColumnWidths.column(
          key: 'med_detail',
          label: 'Détail',
          type: TableColumnType.description,
        ),
        TableColumnWidths.column(
          key: 'lot_number',
          label: 'Lot',
          type: TableColumnType.code,
        ),
        TableColumnWidths.column(
          key: 'expiry_date',
          label: 'Péremption',
          type: TableColumnType.date,
        ),
        TableColumnWidths.column(
          key: 'available',
          label: 'Disponible',
          type: TableColumnType.quantity,
        ),
        TableColumnWidths.column(
          key: 'reorder_level',
          label: 'Seuil',
          type: TableColumnType.quantity,
        ),
        TableColumnWidths.column(
          key: 'price_sale',
          label: 'Prix',
          type: TableColumnType.money,
        ),
        TableColumnWidths.column(
          key: 'status',
          label: 'Statut',
          type: TableColumnType.status,
        ),
        TableColumnWidths.column(
          key: 'actions',
          label: 'Actions',
          type: TableColumnType.actions,
          cellBuilder: _defaultActionsCellBuilder,
        ),
      ];

  /// Cellule d'actions par défaut (voir + éditer).
  static Widget _defaultActionsCellBuilder(
      BuildContext context, dynamic item, int index) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Voir',
          icon: const Icon(Icons.visibility_outlined, size: 18),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          onPressed: () {}, // À surcharger
        ),
        IconButton(
          tooltip: 'Modifier',
          icon: const Icon(Icons.edit_outlined, size: 18),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          onPressed: () {},
        ),
      ],
    );
  }
}

/// Configuration responsive pour les tableaux.
class TableResponsiveConfig {
  /// Seuil mobile : < 600px → cartes, pas de tableau.
  static const double mobileBreakpoint = 600;

  /// Seuil tablette : 600-1024px → tableau compact + scroll horizontal.
  static const double tabletBreakpoint = 1024;

  /// Seuil desktop : > 1024px → tableau complet.
  static const double desktopBreakpoint = 1024;

  /// Détermine le mode d'affichage selon la largeur.
  static TableDisplayMode getMode(double width) {
    if (width < mobileBreakpoint) return TableDisplayMode.cards;
    if (width < tabletBreakpoint) return TableDisplayMode.compactTable;
    return TableDisplayMode.fullTable;
  }

  /// Retourne les largeurs adaptées au mode.
  static ColumnWidthConfig adapt(ColumnWidthConfig base, TableDisplayMode mode) {
    switch (mode) {
      case TableDisplayMode.cards:
        return base; // Non utilisé (cartes)
      case TableDisplayMode.compactTable:
        return ColumnWidthConfig(
          defaultWidth: (base.defaultWidth * 0.85).clamp(base.minWidth, base.maxWidth),
          minWidth: base.minWidth,
          maxWidth: base.maxWidth,
          flex: base.flex,
          alignment: base.alignment,
          numeric: base.numeric,
        );
      case TableDisplayMode.fullTable:
        return base;
    }
  }
}

/// Modes d'affichage responsive.
enum TableDisplayMode {
  cards,          // Mobile : ListView/GridView de cartes
  compactTable,   // Tablette : tableau avec largeurs réduites, scroll horizontal
  fullTable,      // Desktop : tableau complet, colonnes flexibles
}