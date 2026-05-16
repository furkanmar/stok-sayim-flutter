class LoginResponse {
  final String token;
  final String role;
  final String companyId;
  final String username;

  LoginResponse({
    required this.token,
    required this.role,
    required this.companyId,
    required this.username,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'],
      role: json['role'],
      companyId: json['companyId'],
      username: json['username'],
    );
  }
}