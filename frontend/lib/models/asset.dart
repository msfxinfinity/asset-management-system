class Asset {
  final int id;
  final String assetToken;
  final String? serialNumber;
  final int tenantId;
  final int? departmentId;
  final String? assetName;
  final String? city;
  final String? building;
  final String? floor;
  final String? room;
  final String? street;
  final String? locality;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final DateTime? validTill;
  final DateTime createdAt;
  final Map<String, dynamic> attributes;
  final String? mapsUrl;

  Asset({
    required this.id,
    required this.assetToken,
    required this.tenantId,
    required this.createdAt,
    required this.attributes,
    this.serialNumber,
    this.departmentId,
    this.assetName,
    this.city,
    this.building,
    this.floor,
    this.room,
    this.street,
    this.locality,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.validTill,
    this.mapsUrl,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json["id"] as int,
      assetToken: json["asset_token"] as String,
      serialNumber: json["serial_number"] as String?,
      tenantId: json["tenant_id"] as int,
      departmentId: json["department_id"] as int?,
      assetName: json["asset_name"] as String?,
      city: json["city"] as String?,
      building: json["building"] as String?,
      floor: json["floor"] as String?,
      room: json["room"] as String?,
      street: json["street"] as String?,
      locality: json["locality"] as String?,
      postalCode: json["postal_code"] as String?,
      latitude: (json["latitude"] as num?)?.toDouble(),
      longitude: (json["longitude"] as num?)?.toDouble(),
      imageUrl: json["image_url"] as String?,
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
  final List<String> cities;
  final List<String> projectNames;

  const AssetStats({
    required this.totalAssets,
    required this.cities,
    required this.projectNames,
  });

  factory AssetStats.fromJson(Map<String, dynamic> json) {
    return AssetStats(
      totalAssets: json["total_assets"] as int? ?? 0,
      cities: ((json["cities"] as List?) ?? []).map((e) => e.toString()).toList(),
      projectNames: ((json["project_names"] as List?) ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class AssetDropdowns {
  final List<String> cities;
  final List<String> buildings;
  final List<String> floors;
  final List<String> rooms;
  final List<String> assetNames;
  final List<String> projectNames;
  final List<String> statuses;
  final List<String> conditions;
  final Map<String, List<String>> customAttributes;

  const AssetDropdowns({
    required this.cities,
    required this.buildings,
    required this.floors,
    required this.rooms,
    required this.assetNames,
    required this.projectNames,
    required this.statuses,
    required this.conditions,
    this.customAttributes = const {},
  });

  factory AssetDropdowns.fromJson(Map<String, dynamic> json) {
    return AssetDropdowns(
      cities: ((json["cities"] as List?) ?? []).map((e) => e.toString()).toList(),
      buildings: ((json["buildings"] as List?) ?? []).map((e) => e.toString()).toList(),
      floors: ((json["floors"] as List?) ?? []).map((e) => e.toString()).toList(),
      rooms: ((json["rooms"] as List?) ?? []).map((e) => e.toString()).toList(),
      assetNames: ((json["asset_names"] as List?) ?? []).map((e) => e.toString()).toList(),
      projectNames: ((json["project_names"] as List?) ?? []).map((e) => e.toString()).toList(),
      statuses: ((json["statuses"] as List?) ?? []).map((e) => e.toString()).toList(),
      conditions: ((json["conditions"] as List?) ?? []).map((e) => e.toString()).toList(),
      customAttributes: (json["custom_attributes"] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()),
      ) ?? {},
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

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "asset_id": assetId,
      "event_type": eventType,
      "user_id": userId,
      "user_role": userRole,
      "created_at": createdAt.toIso8601String(),
      "geolocation": geolocation,
    };
  }
}
