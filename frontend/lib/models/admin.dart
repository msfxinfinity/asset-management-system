class RoleType {
  final int id;
  final int tenantId;
  final String name;
  final Map<String, dynamic> permissions;
  final bool isSystem;

  RoleType({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.permissions,
    required this.isSystem,
  });

  factory RoleType.fromJson(Map<String, dynamic> json) {
    return RoleType(
      id: json["id"] as int,
      tenantId: json["tenant_id"] as int,
      name: json["name"] as String,
      permissions: (json["permissions"] as Map<String, dynamic>?) ?? {},
      isSystem: json["is_system"] as bool? ?? false,
    );
  }
}

class AdminUser {
  final int id;
  final int tenantId;
  final int roleTypeId;
  final String fullName;
  final String username;
  final String email;
  final bool isActive;

  AdminUser({
    required this.id,
    required this.tenantId,
    required this.roleTypeId,
    required this.fullName,
    required this.username,
    required this.email,
    required this.isActive,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json["id"] as int,
      tenantId: json["tenant_id"] as int,
      roleTypeId: json["role_type_id"] as int,
      fullName: json["full_name"] as String,
      username: json["username"] as String,
      email: json["email"] as String,
      isActive: json["is_active"] as bool? ?? false,
    );
  }
}

class Department {
  final int id;
  final int tenantId;
  final String name;
  final String code;

  Department({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.code,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json["id"] as int,
      tenantId: json["tenant_id"] as int,
      name: json["name"] as String,
      code: json["code"] as String,
    );
  }
}

class QRBatch {
  final int id;
  final int quantity;
  final int? departmentId;
  final List<String> exportFormats;
  final List<int> assetIds;
  final DateTime createdAt;

  QRBatch({
    required this.id,
    required this.quantity,
    required this.departmentId,
    required this.exportFormats,
    required this.assetIds,
    required this.createdAt,
  });

  factory QRBatch.fromJson(Map<String, dynamic> json) {
    return QRBatch(
      id: json["id"] as int,
      quantity: json["quantity"] as int,
      departmentId: json["department_id"] as int?,
      exportFormats: ((json["export_formats"] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      assetIds: ((json["asset_ids"] as List?) ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      createdAt: DateTime.parse(json["created_at"] as String),
    );
  }
}
