class Asset {
  final int id;
  final String assetToken;
  final String serialNumber;
  final int tenantId;
  final int? departmentId;
  final String status;
  final String? assetName;
  final String? assignedTo;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final DateTime? validTill;
  final DateTime createdAt;
  final Map<String, dynamic> attributes;
  final String? mapsUrl;

  Asset({
    required this.id,
    required this.assetToken,
    required this.serialNumber,
    required this.tenantId,
    required this.status,
    required this.createdAt,
    required this.attributes,
    this.departmentId,
    this.assetName,
    this.assignedTo,
    this.locationText,
    this.latitude,
    this.longitude,
    this.validTill,
    this.mapsUrl,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json["id"] as int,
      assetToken: json["asset_token"] as String,
      serialNumber: json["serial_number"] as String,
      tenantId: json["tenant_id"] as int,
      departmentId: json["department_id"] as int?,
      status: json["status"] as String,
      assetName: json["asset_name"] as String?,
      assignedTo: json["assigned_to"] as String?,
      locationText: json["location_text"] as String?,
      latitude: (json["latitude"] as num?)?.toDouble(),
      longitude: (json["longitude"] as num?)?.toDouble(),
      validTill: json["valid_till"] != null
          ? DateTime.tryParse(json["valid_till"] as String)
          : null,
      createdAt: DateTime.parse(json["created_at"] as String),
      attributes: (json["attributes"] as Map<String, dynamic>?) ?? {},
      mapsUrl: json["maps_url"] as String?,
    );
  }
}

class AssetStats {
  final int totalAssets;
  final int activeAssets;
  final int archivedAssets;
  final int unassignedAssets;

  const AssetStats({
    required this.totalAssets,
    required this.activeAssets,
    required this.archivedAssets,
    required this.unassignedAssets,
  });

  factory AssetStats.fromJson(Map<String, dynamic> json) {
    return AssetStats(
      totalAssets: json["total_assets"] as int? ?? 0,
      activeAssets: json["active_assets"] as int? ?? 0,
      archivedAssets: json["archived_assets"] as int? ?? 0,
      unassignedAssets: json["unassigned_assets"] as int? ?? 0,
    );
  }
}

class AssetEvent {
  final int id;
  final int assetId;
  final String eventType;
  final int userId;
  final String userRole;
  final DateTime createdAt;
  final Map<String, dynamic>? geolocation;

  AssetEvent({
    required this.id,
    required this.assetId,
    required this.eventType,
    required this.userId,
    required this.userRole,
    required this.createdAt,
    required this.geolocation,
  });

  factory AssetEvent.fromJson(Map<String, dynamic> json) {
    return AssetEvent(
      id: json["id"] as int,
      assetId: json["asset_id"] as int,
      eventType: json["event_type"] as String,
      userId: json["user_id"] as int,
      userRole: json["user_role"] as String,
      createdAt: DateTime.parse(json["created_at"] as String),
      geolocation: json["geolocation"] as Map<String, dynamic>?,
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
      visibleWhenBlank: json["visible_when_blank"] as bool? ?? false,
      editableByRoles: ((json["editable_by_roles"] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      displayOrder: json["display_order"] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
