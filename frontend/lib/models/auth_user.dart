class AuthUser {
  final String id;
  final String fullName;
  final int roleId;

  const AuthUser({
    required this.id,
    required this.fullName,
    required this.roleId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json["id"].toString(),
      fullName: (json["full_name"] ?? "").toString(),
      roleId: (json["role_id"] as num).toInt(),
    );
  }
}
