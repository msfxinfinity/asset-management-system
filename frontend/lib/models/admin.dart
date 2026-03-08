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
  final bool isSuperadmin;
  final bool isPrimary;

  AdminUser({
    required this.id,
    required this.tenantId,
    required this.roleTypeId,
    required this.fullName,
    required this.username,
    required this.email,
    required this.isActive,
    this.isSuperadmin = false,
    this.isPrimary = false,
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
      isSuperadmin: json["is_superadmin"] as bool? ?? false,
      isPrimary: json["is_primary"] as bool? ?? false,
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

class Tenant {
  final int id;
  final String name;
  final String code;
  final String? adminEmail;
  final String? adminUsername;
  final String? adminPassword;

  Tenant({
    required this.id,
    required this.name,
    required this.code,
    this.adminEmail,
    this.adminUsername,
    this.adminPassword,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json["id"] as int,
      name: json["name"] as String,
      code: json["code"] as String,
      adminEmail: json["admin_email"] as String?,
      adminUsername: json["admin_username"] as String?,
      adminPassword: json["admin_password"] as String?,
    );
  }
}

class DepartmentFieldDefinition {
  final int id;
  final int departmentId;
  final String fieldKey;
  final String label;
  final String fieldType;
  final bool required;
  final bool visibleWhenBlank;
  final List<String> editableByRoles;
  final int displayOrder;

  DepartmentFieldDefinition({
    required this.id,
    required this.departmentId,
    required this.fieldKey,
    required this.label,
    required this.fieldType,
    required this.required,
    required this.visibleWhenBlank,
    required this.editableByRoles,
    required this.displayOrder,
  });

  factory DepartmentFieldDefinition.fromJson(Map<String, dynamic> json) {
    return DepartmentFieldDefinition(
      id: json["id"] as int,
      departmentId: json["department_id"] as int,
      fieldKey: json["field_key"] as String,
      label: json["label"] as String,
      fieldType: json["field_type"] as String,
      required: json["required"] as bool? ?? false,
      visibleWhenBlank: json["visible_when_blank"] as bool? ?? true,
      editableByRoles: ((json["editable_by_roles"] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      displayOrder: json["display_order"] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "department_id": departmentId,
      "field_key": fieldKey,
      "label": label,
      "field_type": fieldType,
      "required": required,
      "visible_when_blank": visibleWhenBlank,
      "editable_by_roles": editableByRoles,
      "display_order": displayOrder,
    };
  }
}
