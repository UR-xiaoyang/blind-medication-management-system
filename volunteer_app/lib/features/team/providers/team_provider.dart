import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 团队成员状态
enum MemberStatus { online, offline, busy }

extension MemberStatusExtension on MemberStatus {
  String get label {
    switch (this) {
      case MemberStatus.online:
        return '在线';
      case MemberStatus.offline:
        return '离线';
      case MemberStatus.busy:
        return '忙碌';
    }
  }

  Color get color {
    switch (this) {
      case MemberStatus.online:
        return const Color(0xFF4CAF50);
      case MemberStatus.offline:
        return const Color(0xFF9E9E9E);
      case MemberStatus.busy:
        return const Color(0xFFFF9800);
    }
  }
}

/// 团队成员模型
class TeamMember {
  final String id;
  final String name;
  final String avatar;
  final String role;
  final List<String> skills;
  final MemberStatus status;
  final int serviceHours;
  final int completedTasks;
  final double rating;
  final String? location;

  TeamMember({
    required this.id,
    required this.name,
    required this.avatar,
    required this.role,
    required this.skills,
    required this.status,
    required this.serviceHours,
    required this.completedTasks,
    this.rating = 5.0,
    this.location,
  });
}

/// 团队消息模型
class TeamMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isMe;
  final MessageType type;

  TeamMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.isMe = false,
    this.type = MessageType.text,
  });
}

enum MessageType { text, image, location, alert }

/// 团队状态
class TeamState {
  final List<TeamMember> members;
  final List<TeamMessage> messages;
  final bool isLoading;

  const TeamState({
    this.members = const [],
    this.messages = const [],
    this.isLoading = false,
  });

  List<TeamMember> get onlineMembers =>
      members.where((m) => m.status == MemberStatus.online).toList();

  TeamState copyWith({
    List<TeamMember>? members,
    List<TeamMessage>? messages,
    bool? isLoading,
  }) {
    return TeamState(
      members: members ?? this.members,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 团队 Provider
class TeamProvider extends StateNotifier<TeamState> {
  TeamProvider() : super(const TeamState()) {
    _loadMockData();
  }

  void _loadMockData() {
    state = state.copyWith(isLoading: true);

    Future.delayed(const Duration(milliseconds: 400), () {
      final mockMembers = [
        TeamMember(
          id: 'user_001',
          name: '张志愿',
          avatar: '张',
          role: '团队负责人',
          skills: const ['医疗救助', '应急救援'],
          status: MemberStatus.online,
          serviceHours: 256,
          completedTasks: 38,
          rating: 4.9,
          location: '北京',
        ),
        TeamMember(
          id: 'user_002',
          name: '李爱心',
          avatar: '李',
          role: '资深志愿者',
          skills: const ['心理辅导', '社区服务'],
          status: MemberStatus.online,
          serviceHours: 198,
          completedTasks: 27,
          rating: 4.8,
          location: '北京',
        ),
        TeamMember(
          id: 'user_003',
          name: '王奉献',
          avatar: '王',
          role: '志愿者',
          skills: const ['教育辅导'],
          status: MemberStatus.busy,
          serviceHours: 156,
          completedTasks: 21,
          rating: 4.7,
          location: '上海',
        ),
        TeamMember(
          id: 'user_004',
          name: '陈热情',
          avatar: '陈',
          role: '志愿者',
          skills: const ['法律援助'],
          status: MemberStatus.offline,
          serviceHours: 98,
          completedTasks: 15,
          rating: 4.6,
          location: '广州',
        ),
        TeamMember(
          id: 'user_005',
          name: '刘活跃',
          avatar: '刘',
          role: '志愿者',
          skills: const ['翻译服务', '社区服务'],
          status: MemberStatus.online,
          serviceHours: 134,
          completedTasks: 18,
          rating: 4.8,
          location: '深圳',
        ),
      ];

      final mockMessages = [
        TeamMessage(
          id: 'msg_001',
          senderId: 'user_002',
          senderName: '李爱心',
          content: '大家好，明天的任务有人参与吗？',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        TeamMessage(
          id: 'msg_002',
          senderId: 'user_001',
          senderName: '张志愿',
          content: '我报名！',
          timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
          isMe: true,
        ),
        TeamMessage(
          id: 'msg_003',
          senderId: 'user_003',
          senderName: '王奉献',
          content: '我也可以参加',
          timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        TeamMessage(
          id: 'msg_004',
          senderId: 'user_002',
          senderName: '李爱心',
          content: '好的，明天早上8点在社区服务中心集合',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

      state = state.copyWith(
        members: mockMembers,
        messages: mockMessages,
        isLoading: false,
      );
    });
  }

  void sendMessage(String content) {
    if (content.trim().isEmpty) return;

    final message = TeamMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'user_001',
      senderName: '我',
      content: content,
      timestamp: DateTime.now(),
      isMe: true,
    );

    state = state.copyWith(messages: [...state.messages, message]);
  }

  void updateMemberStatus(String memberId, MemberStatus status) {
    final updatedMembers = state.members.map((member) {
      if (member.id == memberId) {
        return TeamMember(
          id: member.id,
          name: member.name,
          avatar: member.avatar,
          role: member.role,
          skills: member.skills,
          status: status,
          serviceHours: member.serviceHours,
          completedTasks: member.completedTasks,
          rating: member.rating,
          location: member.location,
        );
      }
      return member;
    }).toList();
    state = state.copyWith(members: updatedMembers);
  }
}

final teamProvider = StateNotifierProvider<TeamProvider, TeamState>((ref) {
  return TeamProvider();
});
