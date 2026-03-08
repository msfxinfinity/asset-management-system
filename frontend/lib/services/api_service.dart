import "dart:convert";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

import "../models/admin.dart";
import "../models/asset.dart";
import "../models/auth.dart";

/// Custom exception class for capturing and communicating detailed API error states.
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

/// Specialized response for QR scanning operations.
class QrLookupResponse {
  final Asset asset;
  final bool isNew;
  QrLookupResponse({required this.asset, required this.isNew});
}

/// Centralized service for all communication between the Flutter frontend and the FastAPI backend.
/// Handles authentication headers, session persistence, and error normalization.
class ApiService {
  static const String baseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "http://localhost:8000",
  );
  
  static const String sessionTokenKey = "ams_access_token";
  static const String sessionUserKey = "ams_user_profile";

  static String? _accessToken;

  /// Sets the JWT token for the current active session.
  static void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// Persists the user session to local storage for automatic re-authentication.
  static Future<void> saveSession(String token, UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sessionTokenKey, token);
    await prefs.setString(sessionUserKey, jsonEncode(user.toJson()));
  }

  /// Clears all local session data (Logout).
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sessionTokenKey);
    await prefs.remove(sessionUserKey);
    setAccessToken(null);
  }

  /// Retrieves default headers, automatically injecting the Bearer token if available.
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

  /// Standard error handler to convert HTTP responses into structured [ApiException]s.
  static ApiException _requestException(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final msg = body["detail"]?.toString() ?? "API Request Failed (${res.statusCode})";
      return ApiException(statusCode: res.statusCode, message: msg, payload: body);
    } catch (_) {
      return ApiException(statusCode: res.statusCode, message: "Critical Server Error");
    }
  }

  // --- AUTHENTICATION ENDPOINTS ---

  /// Authenticats a user and initializes the session.
  static Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    try {
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
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: "Network connection error. Please check your internet.");
    }
  }

  /// Retrieves the profile of the currently logged-in user.
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

  /// Triggers the background account recovery process.
  static Future<String> forgotPassword(String username) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/forgot-password"),
      headers: _headers(),
      body: jsonEncode({"username": username}),
    );
    if (response.statusCode != 200) throw _requestException(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data["message"] as String;
  }

  // --- ASSET MANAGEMENT ENDPOINTS ---

  /// Fetches a paginated and filtered list of assets.
  static Future<List<Asset>> fetchAssets({
    String? query,
    String? city,
    int? departmentId,
    String? projectName,
    Map<String, String>? attributes,
    DateTime? startDate,
    DateTime? endDate,
    String? sortBy = "newest",
    int skip = 0,
    int limit = 100,
  }) async {
    final params = <String, String>{
      "skip": skip.toString(),
      "limit": limit.toString(),
      if (sortBy != null) "sort_by": sortBy,
    };
    if (query != null && query.isNotEmpty) params["query"] = query;
    if (city != null && city.isNotEmpty) params["city"] = city;
    if (departmentId != null) params["department_id"] = departmentId.toString();
    if (projectName != null) params["project_name"] = projectName;
    if (startDate != null) params["start_date"] = startDate.toIso8601String();
    if (endDate != null) params["end_date"] = endDate.toIso8601String();
    if (attributes != null && attributes.isNotEmpty) {
      params["attributes"] = jsonEncode(attributes);
    }

    final uri = Uri.parse("$baseUrl/assets/").replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers(includeJson: false));
    if (response.statusCode != 200) throw _requestException(response);
    
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => Asset.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Specialized lookup for QR codes. Returns existing asset or placeholders for registration.
  static Future<QrLookupResponse> fetchAssetByQr(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/assets/by-qr/$token"),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _requestException(response);
    }
    return QrLookupResponse(
      asset: Asset.fromJson(jsonDecode(response.body) as Map<String, dynamic>),
      isNew: response.statusCode == 201,
    );
  }

  /// Commits a partial or full update to an asset's data.
  static Future<Asset> updateAsset({
    required int assetId,
    int? departmentId,
    String? assetName,
    String? city,
    String? building,
    String? floor,
    String? room,
    String? street,
    String? locality,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? imageBase64,
    DateTime? validTill,
    Map<String, dynamic>? attributes,
  }) async {
    final body = <String, dynamic>{};
    if (departmentId != null) body["department_id"] = departmentId;
    if (assetName != null) body["asset_name"] = assetName;
    if (city != null) body["city"] = city;
    if (building != null) body["building"] = building;
    if (floor != null) body["floor"] = floor;
    if (room != null) body["room"] = room;
    if (street != null) body["street"] = street;
    if (locality != null) body["locality"] = locality;
    if (postalCode != null) body["postal_code"] = postalCode;
    if (latitude != null) body["latitude"] = latitude;
    if (longitude != null) body["longitude"] = longitude;
    if (imageUrl != null) body["image_url"] = imageUrl;
    if (imageBase64 != null) body["image_base64"] = imageBase64;
    if (validTill != null) body["valid_till"] = validTill.toIso8601String();
    if (attributes != null) body["attributes"] = attributes;

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

  // --- REPORTING ENDPOINTS ---

  /// Downloads a report from the system.
  static String getReportUrl(String type) {
    return "$baseUrl/admin/reports/$type/";
  }
}
