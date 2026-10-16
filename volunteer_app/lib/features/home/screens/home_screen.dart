import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/alert_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../../alerts/providers/alert_provider.dart';
import '../../tasks/models/task.dart' show TaskStatus;
import '../../alerts/models/alert.dart' show Alert;
import '../../tasks/screens/task_list_screen.dart';
import '../../alerts/screens/alert_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final taskState = ref.watch(taskProvider);
    final alertState = ref.watch(alertProvider);

    final today = DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(DateTime.now());
    final greeting = _getGreeting();

    final pendingTasks = taskState.tasks
        .where((t) => t.status == TaskStatus.pending)
        .length;
    final inProgressTasks = taskState.tasks
        .where((t) => t.status == TaskStatus.inProgress)
        .length;
    final completedTasks = taskState.tasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final unreadAlerts = alertState.unreadAlerts.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(taskProvider.notifier).refresh();
          ref.read(alertProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context, ref, user?.name ?? '志愿者', greeting, today),
              const SizedBox(height: 16),
              _buildStatsRow(pendingTasks, inProgressTasks, completedTasks),
              const SizedBox(height: 16),
              _buildAlertBanner(context, ref, unreadAlerts),
              const SizedBox(height: 16),
              _buildQuickActions(context),
              const SizedBox(height: 16),
              _buildRecentTasks(context, ref, taskState),
              const SizedBox(height: 16),
              _buildRecentAlerts(context, ref, alertState),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    if (hour < 22) return '晚上好';
    return '夜深了';
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, String name,
      String greeting, String today) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: Text(
                  name.substring(0, 1),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      today,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int pending, int inProgress, int completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard('待进行', pending, AppColors.alertMedium, Icons.schedule),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard('进行中', inProgress, AppColors.primary, Icons.play_circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard('已完成', completed, AppColors.success, Icons.check_circle),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(BuildContext context, WidgetRef ref, int unreadCount) {
    if (unreadCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.danger, AppColors.dangerLight],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '您有 $unreadCount 条未读警告',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '点击查看详情',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // 模拟触发紧急警告测试
              AlertService().triggerAlert(
                alertId: 'home_test',
                message: '测试警告',
                severity: AlertSeverity.high,
              );
              context.push('/alerts');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.danger,
            ),
            child: const Text('查看'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '快捷功能',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildActionItem(context, '查看任务', Icons.assignment, AppColors.primary, () {
                context.push('/tasks');
              })),
              const SizedBox(width: 8),
              Expanded(child: _buildActionItem(context, '紧急警告', Icons.warning, AppColors.danger, () {
                AlertService().triggerAlert(
                  alertId: 'quick_test',
                  message: '紧急求助',
                  severity: AlertSeverity.critical,
                );
              })),
              const SizedBox(width: 8),
              Expanded(child: _buildActionItem(context, '联系团队', Icons.group, AppColors.accent, () {
                context.push('/team');
              })),
              const SizedBox(width: 8),
              Expanded(child: _buildActionItem(context, '查看地图', Icons.map, AppColors.success, () {
                context.push('/map');
              })),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTasks(BuildContext context, WidgetRef ref, TaskListState state) {
    final recentTasks = state.tasks.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '最近任务',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  context.push('/tasks');
                },
                child: const Text('查看全部'),
              ),
            ],
          ),
          if (recentTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('暂无任务', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ...recentTasks.map((task) => _buildTaskItem(task)),
        ],
      ),
    );
  }

  Widget _buildTaskItem(task) {
    final taskObj = task;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: taskObj.priority.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.assignment_outlined,
            color: taskObj.priority.color,
          ),
        ),
        title: Text(
          taskObj.title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          '${taskObj.location} · ${taskObj.status.label}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
        onTap: () {
          context.push('/tasks/${taskObj.id}');
        },
      ),
    );
  }

  Widget _buildRecentAlerts(BuildContext context, WidgetRef ref, AlertListState state) {
    final recentAlerts = state.alerts.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '最近警告',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  context.push('/alerts');
                },
                child: const Text('查看全部'),
              ),
            ],
          ),
          if (recentAlerts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('暂无警告', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ...recentAlerts.map((alert) => _buildAlertItem(alert)),
        ],
      ),
    );
  }

  Widget _buildAlertItem(alert) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: alert.severityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(alert.severityIcon, color: alert.severityColor),
        ),
        title: Text(
          alert.title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          alert.message,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: !alert.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          context.push('/alerts/${alert.id}');
        },
      ),
    );
  }
}
