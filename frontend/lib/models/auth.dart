class UserProfile {
  final int id;
  final String fullName;
  final String username;
  final String email;
  final String role;
  final Map<String, dynamic> permissions;
  final bool isSuperadmin;
  final String? profilePicture;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.role,
    required this.permissions,
    this.isSuperadmin = false,
    this.profilePicture,
  });

  bool get isAdmin => permissions["is_admin"] == true;

  bool hasPermission(String key) => permissions[key] == true;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json["id"] as int,
      fullName: json["full_name"] as String,
      username: json["username"] as String,
      email: json["email"] as String,
      role: json["role"] as String,
      permissions: (json["permissions"] as Map<String, dynamic>?) ?? {},
      isSuperadmin: json["is_superadmin"] as bool? ?? false,
      profilePicture: json["profile_picture"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "full_name": fullName,
      "username": username,
      "email": email,
      "role": role,
      "permissions": permissions,
      "is_superadmin": isSuperadmin,
      "profile_picture": profilePicture,
    };
  }
}

class LoginResponse {
  final String accessToken;
  final String tokenType;
  final UserProfile user;

  LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json["access_token"] as String,
      tokenType: json["token_type"] as String? ?? "bearer",
      user: UserProfile.fromJson(json["user"] as Map<String, dynamic>),
    );
  }
}
