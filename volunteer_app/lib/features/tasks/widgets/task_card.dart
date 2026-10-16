import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onJoin,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildTitleAndStatus(),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.location_on_outlined, task.location),
              const SizedBox(height: 4),
              _buildInfoRow(
                Icons.access_time,
                '${DateFormat('MM-dd HH:mm').format(task.startTime)} - '
                    '${DateFormat('HH:mm').format(task.endTime)}',
              ),
              if (task.requiredSkills.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSkills(),
              ],
              const SizedBox(height: 12),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: task.priority.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            task.priority.label,
            style: TextStyle(
              color: task.priority.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        Text(
          '${task.participantIds.length}/${task.maxParticipants}人',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTitleAndStatus() {
    return Row(
      children: [
        Expanded(
          child: Text(
            task.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: task.status.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            task.status.label,
            style: TextStyle(
              color: task.status.color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSkills() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: task.requiredSkills.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            skill,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          '已参与 ${task.participantIds.length} 人',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        if (task.status == TaskStatus.pending)
          ElevatedButton(
            onPressed: task.isFull ? null : (onJoin ?? () {}),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              minimumSize: const Size(0, 32),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(task.isFull ? '已满员' : '参与任务'),
          )
        else if (task.status == TaskStatus.inProgress)
          TextButton(
            onPressed: onLeave ?? () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('查看进度',
                style: TextStyle(fontSize: 12, color: AppColors.primary)),
          )
        else
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('查看详情', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}
