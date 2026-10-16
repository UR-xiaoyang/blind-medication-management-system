import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../services/alert_service.dart';
import '../services/audio_service.dart';

/// 警告提醒 Widget - 用于显示警告状态
class AlertReminderWidget extends StatefulWidget {
  final String alertId;
  final String message;
  final AlertSeverity severity;
  final VoidCallback? onDismiss;

  const AlertReminderWidget({
    super.key,
    required this.alertId,
    required this.message,
    required this.severity,
    this.onDismiss,
  });

  @override
  State<AlertReminderWidget> createState() => _AlertReminderWidgetState();
}

class _AlertReminderWidgetState extends State<AlertReminderWidget>
    with TickerProviderStateMixin {
  final AlertService _alertService = AlertService();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startReminder();
  }

  void _setupAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.elasticIn,
      ),
    );

    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reverse();
      }
    });
  }

  Future<void> _startReminder() async {
    // 触发震动
    await _alertService.triggerAlert(
      alertId: widget.alertId,
      message: widget.message,
      severity: widget.severity,
    );

    // 启动抖动动画
    _startShakeAnimation();
  }

  void _startShakeAnimation() {
    _shakeController.forward();
  }

  void _dismissReminder() {
    setState(() {
      _isVisible = false;
    });

    _alertService.dismissAlert();
    widget.onDismiss?.call();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: _buildAlertCard(),
        );
      },
    );
  }

  Widget _buildAlertCard() {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (widget.severity) {
      case AlertSeverity.low:
        backgroundColor = AppColors.alertLow;
        textColor = Colors.white;
        icon = Icons.info_outline;
        break;
      case AlertSeverity.medium:
        backgroundColor = AppColors.alertMedium;
        textColor = Colors.white;
        icon = Icons.warning_amber_rounded;
        break;
      case AlertSeverity.high:
        backgroundColor = AppColors.alertHigh;
        textColor = Colors.white;
        icon = Icons.error_outline;
        break;
      case AlertSeverity.critical:
        backgroundColor = AppColors.alertCritical;
        textColor = Colors.white;
        icon = Icons.dangerous_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 警告头部
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 警告图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: textColor,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 12),

                // 警告信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getSeverityText(),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.message,
                        style: TextStyle(
                          color: textColor.withOpacity(0.9),
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // 关闭按钮
                IconButton(
                  onPressed: _dismissReminder,
                  icon: Icon(
                    Icons.close,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          // 操作按钮
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // 查看详情
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      // TODO: 导航到警告详情页
                    },
                    child: Text(
                      '查看详情',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.3),
                ),

                // 确认关闭
                Expanded(
                  child: TextButton(
                    onPressed: _dismissReminder,
                    child: Text(
                      '确认关闭',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSeverityText() {
    switch (widget.severity) {
      case AlertSeverity.low:
        return '低级警告';
      case AlertSeverity.medium:
        return '中级警告';
      case AlertSeverity.high:
        return '高级警告';
      case AlertSeverity.critical:
        return '紧急警告';
    }
  }
}

/// 警告状态指示器
class AlertStatusIndicator extends StatelessWidget {
  final bool isAlerting;
  final AlertSeverity? severity;

  const AlertStatusIndicator({
    super.key,
    required this.isAlerting,
    this.severity,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAlerting) {
      return const SizedBox.shrink();
    }

    Color color;
    String text;

    switch (severity) {
      case AlertSeverity.low:
        color = AppColors.alertLow;
        text = '低级警告';
        break;
      case AlertSeverity.medium:
        color = AppColors.alertMedium;
        text = '中级警告';
        break;
      case AlertSeverity.high:
        color = AppColors.alertHigh;
        text = '高级警告';
        break;
      case AlertSeverity.critical:
        color = AppColors.alertCritical;
        text = '紧急警告';
        break;
      default:
        color = AppColors.alertLow;
        text = '警告中';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 闪烁动画
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// 声音控制按钮
class SoundControlButton extends StatefulWidget {
  const SoundControlButton({super.key});

  @override
  State<SoundControlButton> createState() => _SoundControlButtonState();
}

class _SoundControlButtonState extends State<SoundControlButton> {
  final AudioService _audioService = AudioService();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        if (_audioService.isPlaying) {
          _audioService.stopSound();
        } else {
          _audioService.playAlertSound();
        }
        setState(() {});
      },
      icon: Icon(
        _audioService.isPlaying ? Icons.volume_up : Icons.volume_off,
        color: _audioService.isPlaying ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }
}
