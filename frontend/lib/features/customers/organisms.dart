/// ============================================================
/// ORGANISMES — Types d'organismes payeurs au Maroc
/// ============================================================
enum OrganismType {
  amo('amo', 'AMO', 'Assurance Maladie Obligatoire', Icons.health_and_safety_outlined),
  cnops('cnops', 'CNOPS', 'Caisse Nationale des Organismes de Prévoyance Sociale', Icons.account_balance_outlined),
  cnss('cnss', 'CNSS', 'Caisse Nationale de Sécurité Sociale', Icons.shield_outlined),
  mutuelle('mutuelle', 'Mutuelle', 'Mutuelle / Assurance Complémentaire', Icons.favorite_outlined),
  assurance_privee('assurance_privee', 'Assurance Privée', 'Assurance Privée / Internationale', Icons.business_outlined),
  autre('autre', 'Autre', 'Autre organisme', Icons.more_horiz);

  const OrganismType(this.code, this.label, this.description, this.icon);

  final String code;
  final String label;
  final String description;
  final IconData icon;

  static OrganismType fromCode(String code) {
    return OrganismType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => OrganismType.autre,
    );
  }
}

/// Affiliation d'un client à un organisme
class ClientAffiliation {
  final String? id;
  final OrganismType organismType;
  final String organismName; // Nom spécifique (ex: "CNOPS - Secteur Public")
  final String affiliationNumber; // Numéro d'affiliation / matricule
  final String? contractNumber; // Numéro de contrat
  final DateTime? validityStart; // Date de début de validité
  final DateTime? validityEnd; // Date de fin de validité
  final String status; // active, expired, suspended, pending
  final double? coverageRate; // Taux de prise en charge (%)
  final double? annualCeiling; // Plafond annuel (DH)
  final String? notes;

  ClientAffiliation({
    this.id,
    required this.organismType,
    required this.organismName,
    required this.affiliationNumber,
    this.contractNumber,
    this.validityStart,
    this.validityEnd,
    this.status = 'active',
    this.coverageRate,
    this.annualCeiling,
    this.notes,
  });

  factory ClientAffiliation.fromJson(Map<String, dynamic> json) {
    return ClientAffiliation(
      id: json['id']?.toString(),
      organismType: OrganismType.fromCode(json['organism_type']?.toString() ?? 'autre'),
      organismName: json['organism_name']?.toString() ?? '',
      affiliationNumber: json['affiliation_number']?.toString() ?? '',
      contractNumber: json['contract_number']?.toString(),
      validityStart: json['validity_start'] != null ? DateTime.tryParse(json['validity_start']) : null,
      validityEnd: json['validity_end'] != null ? DateTime.tryParse(json['validity_end']) : null,
      status: json['status']?.toString() ?? 'active',
      coverageRate: (json['coverage_rate'] as num?)?.toDouble(),
      annualCeiling: (json['annual_ceiling'] as num?)?.toDouble(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'organism_type': organismType.code,
      'organism_name': organismName,
      'affiliation_number': affiliationNumber,
      'contract_number': contractNumber,
      'validity_start': validityStart?.toIso8601String().split('T').first,
      'validity_end': validityEnd?.toIso8601String().split('T').first,
      'status': status,
      'coverage_rate': coverageRate,
      'annual_ceiling': annualCeiling,
      'notes': notes,
    };
  }

  bool get isExpired {
    if (validityEnd == null) return false;
    return DateTime.now().isAfter(validityEnd!);
  }

  bool get isExpiringSoon {
    if (validityEnd == null) return false;
    final daysUntilExpiry = validityEnd!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 30 && daysUntilExpiry >= 0;
  }

  String get statusLabel {
    switch (status) {
      case 'active': return 'Actif';
      case 'expired': return 'Expiré';
      case 'suspended': return 'Suspendu';
      case 'pending': return 'En attente';
      default: return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'active': return Colors.green;
      case 'expired': return Colors.red;
      case 'suspended': return Colors.orange;
      case 'pending': return Colors.blue;
      default: return Colors.grey;
    }
  }
}

/// Organismes pré-définis par type (pour sélection rapide)
const Map<OrganismType, List<String>> PREDEFINED_ORGANISMS = {
  OrganismType.amo: ['AMO - Secteur Public', 'AMO - Secteur Privé', 'AMO - Étudiants', 'AMO - Retraités'],
  OrganismType.cnops: ['CNOPS - Secteur Public', 'CNOPS - Secteur Privé', 'CNOPS - Étudiants'],
  OrganismType.cnss: ['CNSS - Salariés', 'CNSS - Indépendants', 'CNSS - Agricoles'],
  OrganismType.mutuelle: ['MAMDA', 'MCMA', 'Mutuelle Générale', 'Mutuelle des Fonctionnaires', 'Wafa Assurance Mutuelle'],
  OrganismType.assurance_privee: ['AXA', 'Allianz', 'SAHAM', 'Wafa Assurance', 'RMA Watanya', 'Atlanta', 'Saham Assurance'],
  OrganismType.autre: [],
};