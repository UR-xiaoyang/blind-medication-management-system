import 'dart:async';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'audio_service.dart';

/// 警告级别枚举
enum AlertSeverity {
  low,      // 低级: 仅通知，无震动响铃
  medium,   // 中级: 震动 + 短响铃
  high,     // 高级: 震动 + 持续响铃 + 全屏弹窗
  critical, // 紧急: 闹钟式提醒，必须手动关闭
}

/// 警告状态
enum AlertStatus {
  inactive,
  active,
  dismissed,
}

/// 警告服务 - 核心功能
class AlertService {
  // 单例模式
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  // 依赖服务
  final AudioService _audioService = AudioService();

  // 状态
  bool _isAlerting = false;
  AlertSeverity? _currentSeverity;
  String? _currentAlertId;
  Timer? _alertTimer;
  Timer? _vibrationTimer;
  String? _currentMessage;

  // 状态流控制器
  final StreamController<AlertStatus> _statusController =
      StreamController<AlertStatus>.broadcast();

  Stream<AlertStatus> get alertStatusStream => _statusController.stream;
  bool get isAlerting => _isAlerting;
  AlertSeverity? get currentSeverity => _currentSeverity;
  String? get currentMessage => _currentMessage;

  /// 触发警告 - 闹钟式提醒
  Future<void> triggerAlert({
    required String alertId,
    required String message,
    required AlertSeverity severity,
  }) async {
    if (_isAlerting) {
      print('警告已在触发中，忽略新警告: $alertId');
      return;
    }

    _isAlerting = true;
    _currentSeverity = severity;
    _currentAlertId = alertId;
    _currentMessage = message;

    _statusController.add(AlertStatus.active);

    print('触发警告: $alertId, 级别: $severity, 消息: $message');

    // 根据警告级别执行不同的提醒策略
    switch (severity) {
      case AlertSeverity.low:
        await _handleLowSeverity();
        break;
      case AlertSeverity.medium:
        await _handleMediumSeverity();
        break;
      case AlertSeverity.high:
        await _handleHighSeverity();
        break;
      case AlertSeverity.critical:
        await _handleCriticalSeverity();
        break;
    }

    // 超时自动停止（防止无限提醒）
    _alertTimer = Timer(const Duration(minutes: 2), () {
      print('警告超时自动关闭');
      dismissAlert();
    });
  }

  /// 低级警告处理 - 仅播放短铃声
  Future<void> _handleLowSeverity() async {
    await _audioService.playAlertSound(loop: false);
    Timer(const Duration(seconds: 3), () {
      if (_isAlerting && _currentSeverity == AlertSeverity.low) {
        _audioService.stopSound();
      }
    });
  }

  /// 中级警告处理 - 震动 + 短铃声
  Future<void> _handleMediumSeverity() async {
    await _audioService.playAlertSound(loop: false);
    await _startVibrationOnce();
    Timer(const Duration(seconds: 5), () {
      if (_isAlerting && _currentSeverity == AlertSeverity.medium) {
        _audioService.stopSound();
      }
    });
  }

  /// 高级警告处理 - 震动 + 持续响铃
  Future<void> _handleHighSeverity() async {
    await _audioService.playAlertSound(loop: true);
    _startVibrationPattern();
  }

  /// 紧急警告处理 - 闹钟式提醒（必须手动关闭）
  Future<void> _handleCriticalSeverity() async {
    HapticFeedback.heavyImpact();

    await _audioService.playAlertSound(loop: true);
    _startAlarmVibration();

    // 每隔3秒再次触发系统震动（增强提醒效果）
    _vibrationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isAlerting) {
        HapticFeedback.heavyImpact();
        _startAlarmVibration();
      } else {
        timer.cancel();
      }
    });
  }

  /// 单次震动
  Future<void> _startVibrationOnce() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: 500);
    }
  }

  /// 间歇震动模式 - 模拟闹钟
  void _startVibrationPattern() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      final pattern = [500, 200, 500, 200, 500, 200];
      await Vibration.vibrate(pattern: pattern, repeat: 0);
    }
  }

  /// 闹钟式震动 - 强烈震动模式
  void _startAlarmVibration() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      final alarmPattern = [1000, 300, 1000, 300, 1000, 300];
      await Vibration.vibrate(pattern: alarmPattern, repeat: 0);
    }
  }

  /// 关闭警告
  Future<void> dismissAlert() async {
    if (!_isAlerting) return;

    print('关闭警告: $_currentAlertId');

    _isAlerting = false;
    _currentSeverity = null;
    _currentAlertId = null;
    _currentMessage = null;

    _alertTimer?.cancel();
    _vibrationTimer?.cancel();

    await _audioService.stopSound();
    await Vibration.cancel();

    _statusController.add(AlertStatus.dismissed);
  }

  void dispose() {
    dismissAlert();
    _statusController.close();
  }
}
