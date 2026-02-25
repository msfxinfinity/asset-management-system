import "dart:convert";

import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

import "../models/admin.dart";
import "../models/asset.dart";
import "../models/auth.dart";

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? payload;

  ApiException({
    required this.statusCode,
    required this.message,
    this.payload,
  });

  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "http://localhost:8000",
  );
  static const String sessionTokenKey = "ams_access_token";
  static const String sessionUserKey = "ams_user_profile";

  static String? _accessToken;

  static void setAccessToken(String? token) {
    _accessToken = token;
  }

  static Future<void> saveSession(String token, UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sessionTokenKey, token);
    await prefs.setString(sessionUserKey, jsonEncode(user.toJson()));
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sessionTokenKey);
    await prefs.remove(sessionUserKey);
    setAccessToken(null);
  }

  static Map<String, String> _headers({bool includeJson = true}) {
    final headers = <String, String>{};
    if (includeJson) {
      headers["Content-Type"] = "application/json";
    }
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers["Authorization"] = "Bearer $_accessToken";
    }
    return headers;
  }

  static ApiException _requestException(http.Response response) {
    Map<String, dynamic>? payload;
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        payload = body;
        final detail = body["detail"];
        if (detail != null) {
          return ApiException(
            statusCode: response.statusCode,
            message: detail.toString(),
            payload: payload,
          );
        }
      }
    } catch (_) {
      payload = null;
    }
    return ApiException(
      statusCode: response.statusCode,
      message: "Request failed with ${response.statusCode}",
      payload: payload,
    );
  }

  static Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: _headers(),
      body: jsonEncode({
        "username": username.trim().toLowerCase(),
        "password": password,
      }),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    final payload = LoginResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    setAccessToken(payload.accessToken);
    return payload;
  }

  static Future<UserProfile> fetchMe() async {
    final response = await http.get(
      Uri.parse("$baseUrl/auth/me"),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<void> forgotPassword(String username) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/forgot-password"),
      headers: _headers(),
      body: jsonEncode({"username": username.trim()}),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
  }

  static Future<AssetStats> fetchStats() async {
    final response = await http.get(
      Uri.parse("$baseUrl/assets/stats"),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    return AssetStats.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<List<Asset>> fetchAssets({
    String? query,
    String? status,
    int? departmentId,
  }) async {
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      params["q"] = query.trim();
    }
    if (status != null && status.trim().isNotEmpty && status != "ALL") {
      params["status"] = status.trim().toUpperCase();
    }
    if (departmentId != null) {
      params["department_id"] = "$departmentId";
    }
    final uri = Uri.parse("$baseUrl/assets/").replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers(includeJson: false));
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => Asset.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  static Future<Asset> fetchAsset(int assetId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/assets/$assetId"),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    return Asset.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<Asset> fetchAssetByQr(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/assets/by-token/$token"),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    return Asset.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<Asset> updateAsset({
    required int assetId,
    String? assetName,
    String? assignedTo,
    String? locationText,
    double? latitude,
    double? longitude,
    DateTime? validTill,
    Map<String, dynamic>? attributes,
  }) async {
    final body = <String, dynamic>{};
    if (assetName != null) body["asset_name"] = assetName;
    if (assignedTo != null) body["assigned_to"] = assignedTo;
    if (locationText != null) body["location_text"] = locationText;
    if (latitude != null) body["latitude"] = latitude;
    if (longitude != null) body["longitude"] = longitude;
    if (validTill != null) body["valid_till"] = validTill.toIso8601String();
    if (attributes != null && attributes.isNotEmpty) body["attributes"] = attributes;

    final response = await http.patch(
      Uri.parse("$baseUrl/assets/$assetId"),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    return Asset.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<Asset> archiveAsset(int assetId) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/assets/$assetId/archive"),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    return Asset.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<Asset> activateAsset(int assetId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/assets/$assetId/activate"),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return Asset.fromJson(payload["asset"] as Map<String, dynamic>);
  }

  static Future<List<AssetEvent>> fetchAssetEvents(int assetId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/assets/$assetId/events"),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => AssetEvent.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  static Future<List<DepartmentFieldDefinition>> fetchAssetFields(int assetId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/assets/$assetId/fields"),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map(
          (e) => DepartmentFieldDefinition.fromJson(e as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  static Future<List<RoleType>> fetchRoles() async {
    final response = await http.get(
      Uri.parse("$baseUrl/admin/roles"),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => RoleType.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  static Future<RoleType> createRole({
    required String name,
    required Map<String, dynamic> permissions,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/admin/roles"),
      headers: _headers(),
      body: jsonEncode({"name": name, "permissions": permissions}),
    );
    if (response.statusCode != 201) {
      throw _requestException(response);
    }
    return RoleType.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<void> deleteRole(int roleId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/admin/roles/$roleId"),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode != 204) {
      throw _requestException(response);
    }
  }

  static Future<List<AdminUser>> fetchUsers() async {
    final response = await http.get(
      Uri.parse("$baseUrl/admin/users"),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  static Future<AdminUser> createUser({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required int roleTypeId,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/admin/users"),
      headers: _headers(),
      body: jsonEncode({
        "full_name": fullName,
        "username": username,
        "email": email,
        "password": password,
        "role_type_id": roleTypeId,
      }),
    );
    if (response.statusCode != 201) {
      throw _requestException(response);
    }
    return AdminUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<void> deleteUser(int userId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/admin/users/$userId"),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode != 204) {
      throw _requestException(response);
    }
  }

  static Future<List<Department>> fetchDepartments() async {
    final response = await http.get(
      Uri.parse("$baseUrl/admin/departments"),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => Department.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  static Future<Department> createDepartment({
    required String name,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/admin/departments"),
      headers: _headers(),
      body: jsonEncode({"name": name, "code": code}),
    );
    if (response.statusCode != 201) {
      throw _requestException(response);
    }
    return Department.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<List<DepartmentFieldDefinition>> fetchDepartmentFields(
    int departmentId,
  ) async {
    final response = await http.get(
      Uri.parse("$baseUrl/admin/departments/$departmentId/fields"),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map(
          (e) => DepartmentFieldDefinition.fromJson(e as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  static Future<List<DepartmentFieldDefinition>> updateDepartmentFields({
    required int departmentId,
    required List<DepartmentFieldDefinition> fields,
  }) async {
    final response = await http.put(
      Uri.parse("$baseUrl/admin/departments/$departmentId/fields"),
      headers: _headers(),
      body: jsonEncode({"fields": fields.map((e) => e.toJson()).toList()}),
    );
    if (response.statusCode != 200) {
      throw _requestException(response);
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map(
          (e) => DepartmentFieldDefinition.fromJson(e as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  static Future<QRBatch> createQrBatch({
    required int quantity,
    int? departmentId,
    required List<String> exportFormats,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/admin/qr-batches"),
      headers: _headers(),
      body: jsonEncode({
        "quantity": quantity,
        "department_id": departmentId,
        "export_formats": exportFormats,
      }),
    );
    if (response.statusCode != 201) {
      throw _requestException(response);
    }
    return QRBatch.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static String qrBatchDownloadUrl({
    required int batchId,
    required String format,
  }) {
    final token = Uri.encodeQueryComponent(_accessToken ?? "");
    return "$baseUrl/admin/qr-batches/$batchId/download"
        "?format=$format&access_token=$token";
  }
}
