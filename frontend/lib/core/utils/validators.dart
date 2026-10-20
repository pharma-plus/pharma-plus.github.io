/// Validateurs de formulaire partagés (étape formulaires PHARMA+).
/// Les messages sont injectés par l'appelant (i18n via S.t) pour rester
/// découplés de la locale. Format téléphone : chiffres, +, espaces,
/// parenthèses et tirets (6 à 20 caractères) — accepte les numéros
/// marocains et internationaux.

final RegExp _phoneRe = RegExp(r'^[0-9+()\- ]{6,20}$');
final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

/// Champ obligatoire : non vide après trim.
String? validateRequired(String? value, String message) {
  if (value == null || value.trim().isEmpty) return message;
  return null;
}

/// Téléphone optionnel : vide accepté, format vérifié si renseigné.
String? validatePhone(String? value, String message) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  if (!_phoneRe.hasMatch(v)) return message;
  return null;
}

/// E-mail optionnel : vide accepté, format vérifié si renseigné.
String? validateEmail(String? value, String message) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  if (!_emailRe.hasMatch(v)) return message;
  return null;
}

/// Nombre décimal ≥ 0 (plafond de crédit, quantités…) — accepte la
/// virgule décimale française.
String? validateNonNegativeNumber(String? value, String message) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  final n = double.tryParse(v.replaceAll(',', '.'));
  if (n == null || n < 0) return message;
  return null;
}
