/// Utilisateur connecté (persisté localement pour la restauration de session).
class User {
  final String id;
  final String? pharmacyId;
  final String? branchId;
  final String? roleId;
  final String firstName;
  final String lastName;
  final String email;
  final bool isSuperAdmin;
  final Set<String> permissions;

  const User({
    required this.id,
    this.pharmacyId,
    this.branchId,
    this.roleId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.isSuperAdmin = false,
    this.permissions = const {},
  });

  String get fullName => '$firstName $lastName';
  String get initials => firstName.isNotEmpty && lastName.isNotEmpty
      ? '${firstName[0]}${lastName[0]}'.toUpperCase()
      : (firstName.isEmpty ? lastName : firstName)[0].toUpperCase();

  bool hasPermission(String permission) =>
      isSuperAdmin || permissions.contains(permission);

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
        isSuperAdmin: json['is_super_admin'] as bool? ??
            json['isSuperAdmin'] as bool? ??
            false,
        permissions: (json['permissions'] as List? ?? const [])
            .whereType<String>()
            .toSet(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'pharmacy_id': pharmacyId,
        'branch_id': branchId,
        'role_id': roleId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'is_super_admin': isSuperAdmin,
        'permissions': permissions.toList(),
      };
}
