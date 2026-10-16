import 'package:flutter/material.dart';

/// 警告数据模型
class Alert {
  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime? dismissedAt;
  final String? dismissedBy;
  final bool isRead;
  final String? actionUrl;
  final String? relatedTaskId;

  Alert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    this.location,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.dismissedAt,
    this.dismissedBy,
    this.isRead = false,
    this.actionUrl,
    this.relatedTaskId,
  });

  Color get severityColor {
    switch (severity) {
      case AlertSeverity.low:
        return const Color(0xFF2196F3);
      case AlertSeverity.medium:
        return const Color(0xFFFF9800);
      case AlertSeverity.high:
        return const Color(0xFFF44336);
      case AlertSeverity.critical:
        return const Color(0xFF9C27B0);
    }
  }

  IconData get severityIcon {
    switch (severity) {
      case AlertSeverity.low:
        return Icons.info_outline;
      case AlertSeverity.medium:
        return Icons.warning_amber_rounded;
      case AlertSeverity.high:
        return Icons.error_outline;
      case AlertSeverity.critical:
        return Icons.dangerous_outlined;
    }
  }

  String get severityText {
    switch (severity) {
      case AlertSeverity.low:
        return '低级';
      case AlertSeverity.medium:
        return '中级';
      case AlertSeverity.high:
        return '高级';
      case AlertSeverity.critical:
        return '紧急';
    }
  }

  Alert copyWith({
    String? title,
    String? message,
    AlertSeverity? severity,
    String? location,
    double? latitude,
    double? longitude,
    DateTime? dismissedAt,
    String? dismissedBy,
    bool? isRead,
    String? actionUrl,
    String? relatedTaskId,
  }) {
    return Alert(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      dismissedBy: dismissedBy ?? this.dismissedBy,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl ?? this.actionUrl,
      relatedTaskId: relatedTaskId ?? this.relatedTaskId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'severity': severity.name,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': createdAt.toIso8601String(),
        'dismissedAt': dismissedAt?.toIso8601String(),
        'dismissedBy': dismissedBy,
        'isRead': isRead,
        'actionUrl': actionUrl,
        'relatedTaskId': relatedTaskId,
      };

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        severity: AlertSeverity.values.firstWhere(
          (e) => e.name == json['severity'],
          orElse: () => AlertSeverity.low,
        ),
        location: json['location'] as String?,
        latitude: json['latitude'] as double?,
        longitude: json['longitude'] as double?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        dismissedAt: json['dismissedAt'] != null
            ? DateTime.parse(json['dismissedAt'] as String)
            : null,
        dismissedBy: json['dismissedBy'] as String?,
        isRead: json['isRead'] as bool? ?? false,
        actionUrl: json['actionUrl'] as String?,
        relatedTaskId: json['relatedTaskId'] as String?,
      );
}
