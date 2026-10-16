import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/stats_provider.dart';
import '../widgets/weekly_chart.dart';
import '../widgets/task_type_pie_chart.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsState = ref.watch(statsProvider);
    final data = statsState.data;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('数据统计'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              ref.read(statsProvider.notifier).changePeriod(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '周', child: Text('本周')),
              const PopupMenuItem(value: '月', child: Text('本月')),
              const PopupMenuItem(value: '年', child: Text('本年')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(statsState.period, style: const TextStyle(color: Colors.white)),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
      body: statsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverviewCards(data),
                  const SizedBox(height: 16),
                  _buildWeeklySection(data),
                  const SizedBox(height: 16),
                  _buildTaskTypeSection(data),
                  const SizedBox(height: 16),
                  _buildLeaderboardSection(data),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCards(StatData data) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '服务时长',
            '${data.serviceHours}h',
            '本月 +${data.monthlyGrowth}%',
            Icons.access_time,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '完成任务',
            '${data.completedTasks}',
            '本月 ${data.monthlyTasks}个',
            Icons.task_alt,
            AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String growth,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              growth,
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySection(StatData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本周服务时长',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          WeeklyChart(data: data.weeklyData),
        ],
      ),
    );
  }

  Widget _buildTaskTypeSection(StatData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '任务类型分布',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TaskTypePieChart(data: data.taskTypeData),
        ],
      ),
    );
  }

  Widget _buildLeaderboardSection(StatData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '团队排行榜',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...data.leaderboard.map((item) => _buildLeaderboardItem(item)),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(LeaderboardItem item) {
    Color rankColor;
    IconData? rankIcon;
    if (item.rank == 1) {
      rankColor = const Color(0xFFFFD700);
      rankIcon = Icons.emoji_events;
    } else if (item.rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
      rankIcon = Icons.emoji_events;
    } else if (item.rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      rankIcon = Icons.emoji_events;
    } else {
      rankColor = AppColors.textHint;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: rankIcon != null
                ? Icon(rankIcon, color: rankColor, size: 18)
                : Text(
                    '${item.rank}',
                    style: TextStyle(
                      color: rankColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                fontWeight: item.rank <= 3 ? FontWeight.w600 : FontWeight.normal,
                color: item.name == '我' ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '${item.hours}h',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${item.tasks}任务',
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
