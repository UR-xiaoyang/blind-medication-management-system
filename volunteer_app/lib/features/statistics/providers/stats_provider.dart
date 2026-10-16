import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';

/// 统计数据模型
class StatData {
  final int serviceHours;
  final int completedTasks;
  final int monthlyTasks;
  final double monthlyGrowth;
  final List<DailyData> weeklyData;
  final List<TaskTypeData> taskTypeData;
  final List<LeaderboardItem> leaderboard;

  StatData({
    this.serviceHours = 0,
    this.completedTasks = 0,
    this.monthlyTasks = 0,
    this.monthlyGrowth = 0,
    this.weeklyData = const [],
    this.taskTypeData = const [],
    this.leaderboard = const [],
  });
}

class DailyData {
  final String day;
  final double hours;
  DailyData(this.day, this.hours);
}

class TaskTypeData {
  final String type;
  final int count;
  final Color color;
  TaskTypeData(this.type, this.count, this.color);
}

class LeaderboardItem {
  final int rank;
  final String name;
  final int hours;
  final int tasks;
  LeaderboardItem(this.rank, this.name, this.hours, this.tasks);
}

/// 统计状态
class StatsState {
  final StatData data;
  final bool isLoading;
  final String period; // 周/月/年

  const StatsState({
    this.data = const StatData(),
    this.isLoading = false,
    this.period = '周',
  });

  StatsState copyWith({StatData? data, bool? isLoading, String? period}) {
    return StatsState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      period: period ?? this.period,
    );
  }
}

class StatsProvider extends StateNotifier<StatsState> {
  StatsProvider() : super(const StatsState()) {
    _loadMockData();
  }

  void _loadMockData() {
    state = state.copyWith(isLoading: true);

    Future.delayed(const Duration(milliseconds: 500), () {
      final data = StatData(
        serviceHours: 128,
        completedTasks: 23,
        monthlyTasks: 12,
        monthlyGrowth: 15.5,
        weeklyData: [
          DailyData('周一', 2.5),
          DailyData('周二', 3.0),
          DailyData('周三', 1.5),
          DailyData('周四', 4.0),
          DailyData('周五', 2.0),
          DailyData('周六', 5.5),
          DailyData('周日', 3.5),
        ],
        taskTypeData: [
          TaskTypeData('社区服务', 8, AppColors.primary),
          TaskTypeData('应急救援', 4, AppColors.danger),
          TaskTypeData('教育辅导', 5, AppColors.accent),
          TaskTypeData('环保宣传', 3, AppColors.success),
          TaskTypeData('其他', 3, AppColors.textSecondary),
        ],
        leaderboard: [
          LeaderboardItem(1, '张志愿', 256, 38),
          LeaderboardItem(2, '李爱心', 198, 27),
          LeaderboardItem(3, '王奉献', 156, 21),
          LeaderboardItem(4, '我', 128, 23),
          LeaderboardItem(5, '刘活跃', 134, 18),
        ],
      );
      state = state.copyWith(data: data, isLoading: false);
    });
  }

  void changePeriod(String period) {
    state = state.copyWith(period: period);
  }
}

final statsProvider = StateNotifierProvider<StatsProvider, StatsState>((ref) {
  return StatsProvider();
});
