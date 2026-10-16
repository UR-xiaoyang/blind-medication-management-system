import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/alert_service.dart';
import '../models/alert.dart';

class AlertListItem extends StatelessWidget {
  final Alert alert;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final VoidCallback? onTrigger;

  const AlertListItem({
    super.key,
    required this.alert,
    this.onTap,
    this.onDismiss,
    this.onTrigger,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDismiss?.call(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSeverityIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 6),
                      Text(
                        alert.message,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (alert.location != null) ...[
                        const SizedBox(height: 8),
                        _buildLocation(),
                      ],
                      const SizedBox(height: 8),
                      _buildFooter(),
                    ],
                  ),
                ),
                if (!alert.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 8, left: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: alert.severityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        alert.severityIcon,
        color: alert.severityColor,
        size: 24,
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: alert.severityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            alert.severityText,
            style: TextStyle(
              color: alert.severityColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            alert.title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: alert.isRead ? FontWeight.w500 : FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLocation() {
    return Row(
      children: [
        const Icon(Icons.location_on_outlined,
            size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            alert.location!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Icon(Icons.access_time, size: 12, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(
          _formatTime(alert.createdAt),
          style: const TextStyle(
            color: AppColors.textHint,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        if (onTrigger != null)
          TextButton.icon(
            onPressed: onTrigger,
            icon: const Icon(Icons.notifications_active, size: 14),
            label: const Text('测试提醒'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: const Size(0, 28),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('MM-dd HH:mm').format(time);
  }
}
