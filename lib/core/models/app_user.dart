enum UserRole { student, teacher, parent }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final int xp;
  final int streak;
  final String? photoUrl;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = UserRole.student,
    this.xp = 0,
    this.streak = 0,
    this.photoUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.name,
    'xp': xp,
    'streak': streak,
    'photoUrl': photoUrl,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppUser.fromMap(Map<String, dynamic> map, String id) => AppUser(
    id: id,
    name: map['name'] as String,
    email: map['email'] as String,
    role: UserRole.values.firstWhere((r) => r.name == map['role'], orElse: () => UserRole.student),
    xp: map['xp'] as int? ?? 0,
    streak: map['streak'] as int? ?? 0,
    photoUrl: map['photoUrl'] as String?,
    createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : null,
  );
}
