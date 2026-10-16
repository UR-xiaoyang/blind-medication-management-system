import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/alert_service.dart';
import '../providers/alert_provider.dart';

class AlertDetailScreen extends ConsumerWidget {
  final String alertId;

  const AlertDetailScreen({super.key, required this.alertId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(alertByIdProvider(alertId));

    if (alert == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('警告详情')),
        body: const Center(child: Text('警告不存在')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('警告详情'),
        backgroundColor: alert.severityColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(alert.severityColor),
            const SizedBox(height: 16),
            _buildMessageCard(alert.message),
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 16),
            if (alert.location != null) _buildLocationCard(),
            const SizedBox(height: 24),
            _buildActionButtons(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Color color) {
    final alert = ref.read(alertByIdProvider(alertId));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(alert.severityIcon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            alert.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              alert.severityText,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '警告内容',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final alert = ref.read(alertByIdProvider(alertId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('触发时间',
                DateFormat('yyyy-MM-dd HH:mm:ss').format(alert.createdAt)),
            const Divider(height: 16),
            _buildInfoRow('警告级别', alert.severityText),
            if (alert.dismissedAt != null) ...[
              const Divider(height: 16),
              _buildInfoRow('处理时间',
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(alert.dismissedAt!)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final alert = ref.read(alertByIdProvider(alertId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '位置信息',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.location!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            if (alert.latitude != null && alert.longitude != null) ...[
              const SizedBox(height: 8),
              Text(
                '坐标: ${alert.latitude!.toStringAsFixed(4)}, ${alert.longitude!.toStringAsFixed(4)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    final alert = ref.read(alertByIdProvider(alertId));
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              AlertService().triggerAlert(
                alertId: alert.id,
                message: alert.message,
                severity: alert.severity,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已触发警告提醒（震动+响铃）')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: alert.severityColor,
            ),
            child: const Text('再次触发提醒'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              AlertService().dismissAlert();
              ref.read(alertProvider.notifier).markAsRead(alert.id);
              Navigator.pop(context);
            },
            child: const Text('确认并关闭'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
