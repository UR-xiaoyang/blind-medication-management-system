import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/alert_service.dart';
import '../models/alert.dart';

/// 警告列表状态
class AlertListState {
  final List<Alert> alerts;
  final bool isLoading;
  final String? error;

  const AlertListState({
    this.alerts = const [],
    this.isLoading = false,
    this.error,
  });

  List<Alert> get unreadAlerts => alerts.where((a) => !a.isRead).toList();

  List<Alert> get criticalAlerts =>
      alerts.where((a) => a.severity == AlertSeverity.critical).toList();

  AlertListState copyWith({
    List<Alert>? alerts,
    bool? isLoading,
    String? error,
  }) {
    return AlertListState(
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 警告 Provider
class AlertProvider extends StateNotifier<AlertListState> {
  AlertProvider() : super(const AlertListState()) {
    _loadMockAlerts();
  }

  /// 加载模拟警告数据
  void _loadMockAlerts() {
    state = state.copyWith(isLoading: true);

    Future.delayed(const Duration(milliseconds: 300), () {
      final now = DateTime.now();
      final mockAlerts = [
        Alert(
          id: 'alert_001',
          title: '社区紧急求助',
          message: 'XX小区发生紧急情况，需要志愿者立即前往协助',
          severity: AlertSeverity.critical,
          location: '朝阳区XX小区',
          latitude: 39.9219,
          longitude: 116.4435,
          createdAt: now.subtract(const Duration(minutes: 5)),
          isRead: false,
        ),
        Alert(
          id: 'alert_002',
          title: '天气预警',
          message: '未来2小时内将有大雨，请做好防护准备',
          severity: AlertSeverity.high,
          createdAt: now.subtract(const Duration(hours: 1)),
          isRead: false,
        ),
        Alert(
          id: 'alert_003',
          title: '志愿者培训通知',
          message: '本周六下午2点将进行应急救援培训',
          severity: AlertSeverity.medium,
          createdAt: now.subtract(const Duration(hours: 3)),
          isRead: false,
        ),
        Alert(
          id: 'alert_004',
          title: '系统更新',
          message: 'APP已更新到最新版本',
          severity: AlertSeverity.low,
          createdAt: now.subtract(const Duration(days: 1)),
          isRead: true,
        ),
        Alert(
          id: 'alert_005',
          title: '任务提醒',
          message: '您参与的任务将在30分钟后开始',
          severity: AlertSeverity.medium,
          createdAt: now.subtract(const(days: 2)),
          isRead: true,
        ),
      ];

      state = state.copyWith(alerts: mockAlerts, isLoading: false);
    });
  }

  /// 触发新警告（模拟接收推送）
  Future<void> triggerNewAlert(Alert alert) async {
    state = state.copyWith(alerts: [alert, ...state.alerts]);

    // 调用核心警告服务（震动+响铃）
    final alertService = AlertService();
    await alertService.triggerAlert(
      alertId: alert.id,
      message: alert.message,
      severity: alert.severity,
    );
  }

  /// 标记为已读
  void markAsRead(String alertId) {
    final updatedAlerts = state.alerts.map((alert) {
      if (alert.id == alertId) {
        return alert.copyWith(isRead: true);
      }
      return alert;
    }).toList();
    state = state.copyWith(alerts: updatedAlerts);
  }

  /// 全部标记为已读
  void markAllAsRead() {
    final updatedAlerts = state.alerts
        .map((alert) => alert.copyWith(isRead: true))
        .toList();
    state = state.copyWith(alerts: updatedAlerts);
  }

  /// 删除警告
  void deleteAlert(String alertId) {
    final updatedAlerts = state.alerts.where((a) => a.id != alertId).toList();
    state = state.copyWith(alerts: updatedAlerts);
  }

  /// 根据ID获取警告
  Alert? getAlertById(String id) {
    try {
      return state.alerts.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 刷新
  Future<void> refresh() async {
    _loadMockAlerts();
  }
}

/// 警告 Provider 实例
final alertProvider = StateNotifierProvider<AlertProvider, AlertListState>((ref) {
  return AlertProvider();
});

/// 单个警告 Provider
final alertByIdProvider = Provider.family<Alert?, String>((ref, id) {
  final alertState = ref.watch(alertProvider);
  return alertState.alerts.firstWhere(
    (a) => a.id == id,
    orElse: () => Alert(
      id: id,
      title: '未知警告',
      message: '',
      severity: AlertSeverity.low,
      createdAt: DateTime.now(),
    ),
  );
});
