class UserProfile {
  final int? id;
  final String name;
  final DateTime createdAt;
  final DateTime lastActive;

  UserProfile({
    this.id,
    required this.name,
    required this.createdAt,
    required this.lastActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_active': lastActive.millisecondsSinceEpoch,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      lastActive: DateTime.fromMillisecondsSinceEpoch(map['last_active']),
    );
  }
}