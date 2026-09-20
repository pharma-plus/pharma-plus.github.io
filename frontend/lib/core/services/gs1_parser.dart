/// ============================================================
/// PHARMA+ — Parseur GS1 (DataMatrix / QR / GS1-128).
///
/// Extrait les Application Identifiers (AI) réellement présents dans
/// le code brut d'un code-barres 2D pharmaceutique :
///   01 → GTIN (14 chiffres)
///   10 → numéro de lot (variable)
///   17 → date de péremption YYMMDD
///   21 → numéro de série (variable)
///   11 → date de fabrication YYMMDD
///
/// Les séparateurs FNC1 traduits en ASCII 0x1D (GS) ou 0x1C (RS)
/// terminent les champs variables.
/// Ne jamais inventer une valeur absente : les champs non détectés
/// restent `null`.
/// ============================================================
class Gs1Data {
  final String? gtin; // AI 01, sans les 00 de padding éventuels
  final String? lot; // AI 10
  final String? expiry; // AI 17 (YYMMDD → YYYY-MM-DD)
  final String? serial; // AI 21
  final String? productionDate; // AI 11

  const Gs1Data({
    this.gtin,
    this.lot,
    this.expiry,
    this.serial,
    this.productionDate,
  });

  bool get isEmpty =>
      gtin == null && lot == null && expiry == null && serial == null &&
      productionDate == null;

  Map<String, dynamic> toJson() => {
        if (gtin != null) 'gtin': gtin,
        if (lot != null) 'lot': lot,
        if (expiry != null) 'expiry': expiry,
        if (serial != null) 'serial': serial,
        if (productionDate != null) 'production_date': productionDate,
      };
}

class Gs1Parser {
  const Gs1Parser._();

  static const String _gs = '\x1D'; // FNC1 (group separator)
  static const String _rs = '\x1C'; // FNC1 (record separator)

  /// Parse un code brut. Retourne une [Gs1Data] vide si ce n'est
  /// pas un code GS1 structuré (EAN-13 nu, Code 128 logistique…).
  static Gs1Data parse(String raw) {
    var code = raw.trim();
    if (code.length < 4) return const Gs1Data();

    // Le FNC1 symbol-identifier de certains scanners : "]d2", "]Q3", "]C1"…
    if (code.startsWith(']')) {
      final idx = code.indexOf(RegExp(r'^\][A-Za-z][0-9]'));
      if (idx == 0) code = code.substring(3);
    }

    // Un code GS1 commence par un AI à 2 chiffres connu (01/10/11/17/21…).
    final head = int.tryParse(code.substring(0, 2));
    if (head == null) return const Gs1Data();
    const known = {01, 10, 11, 17, 21, 240, 30, 37, 3100};
    if (!known.contains(head)) return const Gs1Data();

    // Normalise les séparateurs.
    code = code.replaceAll(_rs, _gs);

    String? gtin, lot, expiry, serial, prodDate;
    var i = 0;
    while (i + 2 <= code.length) {
      final ai = int.tryParse(code.substring(i, i + 2));
      if (ai == null) break;
      final rest = code.substring(i + 2);
      switch (ai) {
        case 01: // GTIN — fixe 14
          if (rest.length < 14) return _partial(gtin, lot, expiry, serial, prodDate);
          gtin = _normalizeGtin(rest.substring(0, 14));
          i += 2 + 14;
          break;
        case 11: // date fabrication — fixe 6
          if (rest.length < 6) return _partial(gtin, lot, expiry, serial, prodDate);
          prodDate = _date(rest.substring(0, 6));
          i += 2 + 6;
          break;
        case 17: // péremption — fixe 6
          if (rest.length < 6) return _partial(gtin, lot, expiry, serial, prodDate);
          expiry = _date(rest.substring(0, 6));
          i += 2 + 6;
          break;
        case 10: // lot — variable
          final f = _variable(rest);
          lot = f.value;
          i += 2 + f.consumed;
          break;
        case 21: // série — variable
          final f = _variable(rest);
          serial = f.value;
          i += 2 + f.consumed;
          break;
        default:
          // AI non géré : on saute son champ (fixe 6 si connu sinon variable).
          final f = _variable(rest);
          i += 2 + f.consumed;
      }
      // Un séparateur (GS) consommé entre deux champs.
      if (i < code.length && code[i] == _gs) i++;
    }

    return _partial(gtin, lot, expiry, serial, prodDate);
  }

  static Gs1Data _partial(String? g, String? l, String? e, String? s, String? p) =>
      Gs1Data(gtin: g, lot: l, expiry: e, serial: s, productionDate: p);

  /// Champ variable : s'arrête au premier GS ou à la fin.
  static ({String value, int consumed}) _variable(String rest) {
    final gsIdx = rest.indexOf(_gs);
    if (gsIdx == -1) return (value: rest.trim(), consumed: rest.length);
    return (value: rest.substring(0, gsIdx).trim(), consumed: gsIdx + 1);
  }

  /// GTIN : supprime les zéros de tête en conservant 13 chiffres max
  /// pour matcher un EAN-13/EAN-8 en base.
  static String _normalizeGtin(String gtin) {
    final trimmed = gtin.replaceAll(RegExp(r'^0+'), '');
    return trimmed.isEmpty ? gtin : trimmed;
  }

  /// YYMMDD → YYYY-MM-DD ('00' jour → 01 ; années 00-49 → 2000-2049).
  static String? _date(String ymd) {
    if (ymd.length != 6) return null;
    final yy = int.tryParse(ymd.substring(0, 2));
    final mm = int.tryParse(ymd.substring(2, 4));
    var dd = int.tryParse(ymd.substring(4, 6));
    if (yy == null || mm == null || mm < 1 || mm > 12) return null;
    dd ??= 1;
    if (dd < 1 || dd > 31) dd = 1;
    final year = 2000 + yy;
    return '$year-${mm.toString().padLeft(2, '0')}-${dd.toString().padLeft(2, '0')}';
  }

  /// Vérifie la clé de contrôle d'un EAN-8/EAN-13/UPC.
  /// `null` si longueur non supportée ; `false` = code invalide.
  static bool? checkDigitValid(String code) {
    final digits = code.trim();
    if (![8, 12, 13, 14].contains(digits.length)) return null;
    if (int.tryParse(digits) == null) return null;
    var sum = 0;
    final rev = digits.split('').reversed.toList();
    for (var i = 1; i < rev.length; i++) {
      final d = int.parse(rev[i]);
      // Poids 3 sur les positions impaires en partant de la droite (i=1,3…).
      sum += d * (i.isOdd ? 3 : 1);
    }
    return (10 - (sum % 10)) % 10 == int.parse(rev[0]);
  }
}
