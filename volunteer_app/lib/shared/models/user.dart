/// 用户数据模型
class User {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? avatar;
  final String role; // volunteer, admin
  final List<String> skills; // 技能标签
  final String? teamId;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final int serviceHours;
  final int completedTasks;

  User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.avatar,
    this.role = 'volunteer',
    this.skills = const [],
    this.teamId,
    required this.createdAt,
    this.lastLoginAt,
    this.serviceHours = 0,
    this.completedTasks = 0,
  });

  User copyWith({
    String? name,
    String? phone,
    String? email,
    String? avatar,
    String? role,
    List<String>? skills,
    String? teamId,
    DateTime? lastLoginAt,
    int? serviceHours,
    int? completedTasks,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      skills: skills ?? this.skills,
      teamId: teamId ?? this.teamId,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      serviceHours: serviceHours ?? this.serviceHours,
      completedTasks: completedTasks ?? this.completedTasks,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'avatar': avatar,
        'role': role,
        'skills': skills,
        'teamId': teamId,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'serviceHours': serviceHours,
        'completedTasks': completedTasks,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String?,
        avatar: json['avatar'] as String?,
        role: json['role'] as String? ?? 'volunteer',
        skills: (json['skills'] as List?)?.cast<String>() ?? [],
        teamId: json['teamId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastLoginAt: json['lastLoginAt'] != null
            ? DateTime.parse(json['lastLoginAt'] as String)
            : null,
        serviceHours: json['serviceHours'] as int? ?? 0,
        completedTasks: json['completedTasks'] as int? ?? 0,
      );
}

/// 用户角色枚举
enum UserRole {
  volunteer,
  admin,
  teamLeader,
}

extension UserRoleExtension on UserRole {
  String get label {
    switch (this) {
      case UserRole.volunteer:
        return '志愿者';
      case UserRole.admin:
        return '管理员';
      case UserRole.teamLeader:
        return '团队负责人';
    }
  }
}
