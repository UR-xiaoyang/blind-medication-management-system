import 'package:flutter/material.dart';

/// 任务状态枚举
enum TaskStatus {
  pending,    // 待进行
  inProgress, // 进行中
  completed,  // 已完成
  cancelled,  // 已取消
}

extension TaskStatusExtension on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.pending:
        return '待进行';
      case TaskStatus.inProgress:
        return '进行中';
      case TaskStatus.completed:
        return '已完成';
      case TaskStatus.cancelled:
        return '已取消';
    }
  }

  Color get color {
    switch (this) {
      case TaskStatus.pending:
        return const Color(0xFFFF9800);
      case TaskStatus.inProgress:
        return const Color(0xFF2196F3);
      case TaskStatus.completed:
        return const Color(0xFF4CAF50);
      case TaskStatus.cancelled:
        return const Color(0xFF9E9E9E);
    }
  }
}

/// 任务优先级
enum TaskPriority {
  low,
  medium,
  high,
  urgent,
}

extension TaskPriorityExtension on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.low:
        return '低';
      case TaskPriority.medium:
        return '中';
      case TaskPriority.high:
        return '高';
      case TaskPriority.urgent:
        return '紧急';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return const Color(0xFF4CAF50);
      case TaskPriority.medium:
        return const Color(0xFFFF9800);
      case TaskPriority.high:
        return const Color(0xFFF44336);
      case TaskPriority.urgent:
        return const Color(0xFF9C27B0);
    }
  }
}

/// 任务数据模型
class Task {
  final String id;
  final String title;
  final String description;
  final String location;
  final double? latitude;
  final double? longitude;
  final DateTime startTime;
  final DateTime endTime;
  final TaskStatus status;
  final TaskPriority priority;
  final String creatorId;
  final List<String> participantIds;
  final int maxParticipants;
  final List<String> requiredSkills;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? remark;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    this.latitude,
    this.longitude,
    required this.startTime,
    required this.endTime,
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.medium,
    required this.creatorId,
    this.participantIds = const [],
    this.maxParticipants = 10,
    this.requiredSkills = const [],
    required this.createdAt,
    this.completedAt,
    this.remark,
  });

  bool get isFull => participantIds.length >= maxParticipants;
  bool get isUrgent => priority == TaskPriority.urgent;
  Duration get remainingTime => endTime.difference(DateTime.now());
  bool get isOngoing =>
      status == TaskStatus.inProgress &&
      DateTime.now().isAfter(startTime) &&
      DateTime.now().isBefore(endTime);

  Task copyWith({
    String? title,
    String? description,
    String? location,
    double? latitude,
    double? longitude,
    DateTime? startTime,
    DateTime? endTime,
    TaskStatus? status,
    TaskPriority? priority,
    List<String>? participantIds,
    int? maxParticipants,
    List<String>? requiredSkills,
    DateTime? completedAt,
    String? remark,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      creatorId: creatorId,
      participantIds: participantIds ?? this.participantIds,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      remark: remark ?? this.remark,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'status': status.name,
        'priority': priority.name,
        'creatorId': creatorId,
        'participantIds': participantIds,
        'maxParticipants': maxParticipants,
        'requiredSkills': requiredSkills,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'remark': remark,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        location: json['location'] as String,
        latitude: json['latitude'] as double?,
        longitude: json['longitude'] as double?,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        status: TaskStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TaskStatus.pending,
        ),
        priority: TaskPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => TaskPriority.medium,
        ),
        creatorId: json['creatorId'] as String,
        participantIds: (json['participantIds'] as List?)?.cast<String>() ?? [],
        maxParticipants: json['maxParticipants'] as int? ?? 10,
        requiredSkills: (json['requiredSkills'] as List?)?.cast<String>() ?? [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        remark: json['remark'] as String?,
      );
}
