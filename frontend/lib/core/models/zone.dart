/// Zones du plan 3D de la pharmacie. partagées entre le Catalogue/Stock
/// (sélection de l'emplacement d'un médicament) et le Plan 3D (surbrillance).
class PlanZone {
  final String id;
  final String labelKey;
  final int colorValue;
  const PlanZone(this.id, this.labelKey, this.colorValue);
}

const List<PlanZone> kPlanZones = <PlanZone>[
  PlanZone('entrance', 'zoneEntrance', 0xFF9E9E9E),
  PlanZone('counter', 'zoneCounter', 0xFFFFB300),
  PlanZone('meds', 'zoneMedications', 0xFF2E7D32),
  PlanZone('para', 'zoneParapharmacy', 0xFF00BFA5),
  PlanZone('cos', 'zoneCosmetics', 0xFFD81B60),
  PlanZone('presc', 'zonePrescriptions', 0xFF7B1FA2),
  PlanZone('vac', 'zoneVaccines', 0xFF039BE5),
];

/// Renvoie la zone correspondant à un `shelf_location` stocké, ou `meds` par défaut.
PlanZone planZoneFromId(String? id) =>
    kPlanZones.firstWhere((z) => z.id == id, orElse: () => kPlanZones[2]);
