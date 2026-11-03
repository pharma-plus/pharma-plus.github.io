/// Utilisateur connecté (persisté localement pour la restauration de session).
///
/// Le statut Super Admin est TRI-ÉTAT :
///  - `isSuperAdminFlag == true`  → confirmé par une réponse serveur ;
///  - `isSuperAdminFlag == false` → refusé explicitement par le serveur ;
///  - `isSuperAdminFlag == null`  → inconnu (champ absent/null, profil local
///    restauré, erreur réseau) → l'accès au CRM est refusé jusqu'à
///    confirmation serveur. Une valeur locale n'est JAMAIS une autorisation.
class User {
  final String id;
  final String? pharmacyId;
  final String? branchId;
  final String? roleId;
  final String firstName;
  final String lastName;
  final String email;

  /// Statut Super Admin tel que renvoyé par le serveur (null = inconnu).
  /// Ne jamais déduire cette valeur côté client (ni du rôle, ni d'un
  /// ancien stockage local).
  final bool? isSuperAdminFlag;
  final Set<String> permissions;
  final String? pharmacyName;
  final String? roleName;

  /// Modules visibles par cet utilisateur (null = tous visibles).
  final List<String>? visibleModules;

  /// Un PIN est-il configuré (jamais la valeur ni le hash).
  final bool hasPin;

  const User({
    required this.id,
    this.pharmacyId,
    this.branchId,
    this.roleId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.isSuperAdminFlag,
    this.permissions = const {},
    this.pharmacyName,
    this.roleName,
    this.visibleModules,
    this.hasPin = false,
  });

  String get fullName => '$firstName $lastName';
  String get initials => firstName.isNotEmpty && lastName.isNotEmpty
      ? '${firstName[0]}${lastName[0]}'.toUpperCase()
      : (firstName.isEmpty ? lastName : firstName)[0].toUpperCase();

  /// Autorisation Super Admin : uniquement une confirmation serveur
  /// explicite (`true`). Toute valeur inconnue (null) vaut refus —
  /// les contrôles réels restent côté backend / fonction Edge.
  bool get isSuperAdmin => isSuperAdminFlag ?? false;

  bool hasPermission(String permission) =>
      isSuperAdmin || permissions.contains(permission);

  /// Parse le champ admin en distinguant absent/null (→ null, statut
  /// inconnu, refus) d'un booléen explicite. Un type inattendu est traité
  /// comme inconnu (jamais converti en autorisation, jamais une exception).
  static bool? _parseAdminFlag(dynamic snake, dynamic camel) {
    if (snake is bool) return snake;
    if (camel is bool) return camel;
    return null;
  }

  /// Profil restauré depuis le stockage local : la confirmation admin
  /// éventuelle est rétrogradée en « inconnu ». Seule une réponse serveur
  /// authentifiée peut (re)confirmer `true`.
  User withoutAdminConfirmation() => User(
        id: id,
        pharmacyId: pharmacyId,
        branchId: branchId,
        roleId: roleId,
        firstName: firstName,
        lastName: lastName,
        email: email,
        isSuperAdminFlag: null,
        permissions: permissions,
        pharmacyName: pharmacyName,
        roleName: roleName,
        visibleModules: visibleModules,
        hasPin: hasPin,
      );

  /// Décision de synchronisation au démarrage (`_doInit`) :
  ///  - réponse serveur complète (champ admin explicite) → profil serveur ;
  ///  - réponse absente ou incomplète → profil local sans confirmation.
  /// Les informations non sensibles du profil sont conservées pour
  /// l'affichage, sans jamais accorder de privilège.
  User applyServerConfirmation(User? server) =>
      (server != null && server.isSuperAdminFlag != null)
          ? server
          : withoutAdminConfirmation();

  /// Construit l'utilisateur à partir de la réponse de connexion /
  /// rafraîchissement : fusionne `user` + `pharmacy` + `role` renvoyés
  /// par l'API afin d'afficher de vraies identités dans l'interface.
  static User fromSession(Map<String, dynamic> data) {
    final userJson = Map<String, dynamic>.from(data['user'] as Map? ?? {});
    final pharmacy = data['pharmacy'] as Map?;
    final role = data['role'] as Map?;
    userJson['pharmacy_name'] ??= pharmacy?['name'];
    userJson['role_name'] ??= role?['name'];
    return User.fromJson(userJson);
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        pharmacyId:
            json['pharmacy_id'] as String? ?? json['pharmacyId'] as String?,
        branchId: json['branch_id'] as String? ?? json['branchId'] as String?,
        roleId: json['role_id'] as String? ?? json['roleId'] as String?,
        firstName:
            json['first_name'] as String? ?? json['firstName'] as String? ?? '',
        lastName:
            json['last_name'] as String? ?? json['lastName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        isSuperAdminFlag: _parseAdminFlag(
            json['is_super_admin'], json['isSuperAdmin']),
        permissions: (json['permissions'] as List? ?? const [])
            .whereType<String>()
            .toSet(),
        pharmacyName: json['pharmacy_name'] as String? ??
            json['pharmacyName'] as String?,
        roleName:
            json['role_name'] as String? ?? json['roleName'] as String?,
        visibleModules: json['visible_modules'] is List
            ? (json['visible_modules'] as List).whereType<String>().toList()
            : json['visibleModules'] is List
                ? (json['visibleModules'] as List).whereType<String>().toList()
                : null,
        hasPin: json['has_pin'] as bool? ?? json['hasPin'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'pharmacy_id': pharmacyId,
        'branch_id': branchId,
        'role_id': roleId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        // null (inconnu) est conservé tel quel : une valeur locale jamais
        // confirmée par le serveur ne doit pas devenir une autorisation.
        'is_super_admin': isSuperAdminFlag,
        'permissions': permissions.toList(),
        if (pharmacyName != null) 'pharmacy_name': pharmacyName,
        if (roleName != null) 'role_name': roleName,
        if (visibleModules != null) 'visible_modules': visibleModules,
        'has_pin': hasPin,
      };
}
