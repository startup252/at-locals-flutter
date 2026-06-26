class AppUser {
  final String id;
  final String email;
  final String? name;
  final String role;
  final String? avatarUrl;
  final String? accountStatus;

  const AppUser({
    required this.id,
    required this.email,
    this.name,
    required this.role,
    this.avatarUrl,
    this.accountStatus,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String,
        name: j['name'] as String?,
        role: j['role'] as String? ?? 'GUEST',
        avatarUrl: j['avatarUrl'] as String?,
        accountStatus: j['accountStatus'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role,
        'avatarUrl': avatarUrl,
        'accountStatus': accountStatus,
      };

  String get displayName => name ?? email.split('@').first;
}
