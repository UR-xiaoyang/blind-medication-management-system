import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/team_provider.dart';
import 'team_chat_screen.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final teamState = ref.watch(teamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('团队协作'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _tabIndex == 0
                ? _buildMembersList(teamState)
                : _buildChatList(teamState),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.surface,
      child: Row(
        children: [
          _buildTab('成员', 0),
          _buildTab('消息', 1),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMembersList(TeamState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildOnlineStats(state),
        Expanded(
          child: ListView.builder(
            itemCount: state.members.length,
            itemBuilder: (context, index) {
              final member = state.members[index];
              return _buildMemberTile(member);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineStats(TeamState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              '在线',
              state.onlineMembers.length.toString(),
              MemberStatus.online.color,
            ),
          ),
          Container(width: 1, height: 30, color: AppColors.divider),
          Expanded(
            child: _buildStatItem(
              '总成员',
              state.members.length.toString(),
              AppColors.primary,
            ),
          ),
          Container(width: 1, height: 30, color: AppColors.divider),
          Expanded(
            child: _buildStatItem(
              '总服务时长',
              '${state.members.fold<int>(0, (sum, m) => sum + m.serviceHours)}h',
              AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberTile(TeamMember member) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary,
              child: Text(
                member.avatar,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: member.status.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          member.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              member.role,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                const SizedBox(width: 2),
                Text(
                  member.rating.toString(),
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(width: 8),
                Icon(Icons.access_time, size: 12, color: AppColors.textHint),
                const SizedBox(width: 2),
                Text(
                  '${member.serviceHours}h',
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(width: 8),
                Icon(Icons.task_alt, size: 12, color: AppColors.textHint),
                const SizedBox(width: 2),
                Text(
                  '${member.completedTasks}任务',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: () {},
          icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildChatList(TeamState state) {
    if (state.messages.isEmpty) {
      return const Center(child: Text('暂无消息'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.members.length,
      itemBuilder: (context, index) {
        final member = state.members[index];
        final lastMessage = state.messages.lastWhere(
          (m) => m.senderId == member.id,
          orElse: () => TeamMessage(
            id: '',
            senderId: member.id,
            senderName: member.name,
            content: '点击开始聊天',
            timestamp: DateTime.now(),
          ),
        );
        return _buildChatTile(member, lastMessage);
      },
    );
  }

  Widget _buildChatTile(TeamMember member, TeamMessage lastMessage) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                member.avatar,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (member.status == MemberStatus.online)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: MemberStatus.online.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        title: Text(member.name),
        subtitle: Text(
          lastMessage.content,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: Text(
          _formatTime(lastMessage.timestamp),
          style: const TextStyle(
            color: AppColors.textHint,
            fontSize: 11,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeamChatScreen(memberId: member.id),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟';
    if (diff.inHours < 24) return '${diff.inHours}小时';
    return '${diff.inDays}天';
  }
}
