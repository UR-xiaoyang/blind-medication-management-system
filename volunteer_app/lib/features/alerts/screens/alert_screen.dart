import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/alert_service.dart';
import '../models/alert.dart';
import '../providers/alert_provider.dart';
import '../widgets/alert_list_item.dart';
import 'alert_detail_screen.dart';

class AlertScreen extends ConsumerStatefulWidget {
  const AlertScreen({super.key});

  @override
  ConsumerState<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends ConsumerState<AlertScreen> {
  @override
  Widget build(BuildContext context) {
    final alertState = ref.watch(alertProvider);
    final unreadCount = alertState.unreadAlerts.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('警告中心'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(alertProvider.notifier).markAllAsRead();
              },
              child: const Text(
                '全部已读',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildStatsBar(alertState),
          _buildTestButtons(),
          Expanded(
            child: _buildAlertList(alertState),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(AlertListState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        children: [
          _buildStatItem(
            '总警告',
            state.alerts.length.toString(),
            AppColors.primary,
            Icons.notifications,
          ),
          const SizedBox(width: 12),
          _buildStatItem(
            '未读',
            state.unreadAlerts.length.toString(),
            AppColors.danger,
            Icons.mark_email_unread,
          ),
          const SizedBox(width: 12),
          _buildStatItem(
            '紧急',
            state.criticalAlerts.length.toString(),
            AppColors.alertCritical,
            Icons.dangerous,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTestButton('低级', AlertSeverity.low, AppColors.alertLow),
            const SizedBox(width: 8),
            _buildTestButton('中级', AlertSeverity.medium, AppColors.alertMedium),
            const SizedBox(width: 8),
            _buildTestButton('高级', AlertSeverity.high, AppColors.alertHigh),
            const SizedBox(width: 8),
            _buildTestButton('紧急', AlertSeverity.critical, AppColors.alertCritical),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(String label, AlertSeverity severity, Color color) {
    return ElevatedButton(
      onPressed: () => _triggerTestAlert(severity),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(0, 36),
        textStyle: const TextStyle(fontSize: 13),
      ),
      child: Text('测试$label警告'),
    );
  }

  void _triggerTestAlert(AlertSeverity severity) async {
    final id = 'test_${DateTime.now().millisecondsSinceEpoch}';
    final testAlert = Alert(
      id: id,
      title: '${_getSeverityText(severity)}警告测试',
      message: '这是一条${_getSeverityText(severity)}警告测试消息。\n请注意震动和响铃效果。',
      severity: severity,
      createdAt: DateTime.now(),
    );

    // 触发警告
    await AlertService().triggerAlert(
      alertId: id,
      message: testAlert.message,
      severity: severity,
    );

    // 添加到列表
    ref.read(alertProvider.notifier).triggerNewAlert(testAlert);
  }

  String _getSeverityText(AlertSeverity severity) {
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

  Widget _buildAlertList(AlertListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 80, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text('暂无警告', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(alertProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.alerts.length,
        itemBuilder: (context, index) {
          final alert = state.alerts[index];
          return AlertListItem(
            alert: alert,
            onTap: () {
              ref.read(alertProvider.notifier).markAsRead(alert.id);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlertDetailScreen(alertId: alert.id),
                ),
              );
            },
            onDismiss: () {
              ref.read(alertProvider.notifier).deleteAlert(alert.id);
            },
            onTrigger: () {
              _triggerTestAlert(alert.severity);
            },
          );
        },
      ),
    );
  }
}
