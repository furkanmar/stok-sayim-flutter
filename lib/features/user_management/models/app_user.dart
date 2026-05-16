class AppUser {
  final String? id;
  final String username;
  final String password;
  final String role;
  final String companyId;
  final List<String> branchIds;

  AppUser({
    this.id,
    required this.username,
    required this.password,
    required this.role,
    required this.companyId,
    required this.branchIds,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString(),
      username: json['username'] ?? '',
      password: '',
      role: json['role'] ?? 'counter',
      companyId: json['companyId'].toString(),
      branchIds: (json['branchIds'] as List)
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'role': role,
      'companyId': companyId,
      'branchIds': branchIds,
    };
  }
}