/// Extraction unifiée des listes renvoyées par l'API.
///
/// Le backend normalisé (Express armé des routes complètes) renvoie
/// `{ success, data: [ … ], meta: { … } }` : `data` est alors un tableau nu.
/// Le backend « brut » (PostgREST / fonction partielle) renvoie un tableau nu
/// directement. Certains endpoints exposent `{ data: { items: [ … ] } }`.
/// Ce helper accepte les trois formes pour qu'une page ne soit jamais vide
/// à cause d'une erreur de parsing.
class ApiList {
  const ApiList._();

  static List<Map<String, dynamic>> of(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map) {
      final items = data['items'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }
      final rows = data['rows'];
      if (rows is List) {
        return rows.whereType<Map<String, dynamic>>().toList();
      }
    }
    return const [];
  }

  static int total(dynamic data, dynamic meta) {
    if (meta is Map) {
      final t = meta['total'];
      if (t is num) return t.toInt();
    }
    if (data is List) return data.length;
    if (data is Map) {
      final items = data['items'];
      if (items is List) return items.length;
    }
    return 0;
  }
}