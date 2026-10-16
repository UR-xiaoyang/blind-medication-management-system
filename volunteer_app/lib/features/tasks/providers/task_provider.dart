import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';

/// 任务列表状态
class TaskListState {
  final List<Task> tasks;
  final bool isLoading;
  final String? error;
  final TaskStatus? filterStatus;
  final String searchQuery;

  const TaskListState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.filterStatus,
    this.searchQuery = '',
  });

  List<Task> get filteredTasks {
    var result = tasks;
    if (filterStatus != null) {
      result = result.where((t) => t.status == filterStatus).toList();
    }
    if (searchQuery.isNotEmpty) {
      result = result
          .where((t) =>
              t.title.contains(searchQuery) ||
              t.location.contains(searchQuery))
          .toList();
    }
    return result;
  }

  TaskListState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    String? error,
    TaskStatus? filterStatus,
    String? searchQuery,
    bool clearFilter = false,
  }) {
    return TaskListState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// 任务 Provider
class TaskProvider extends StateNotifier<TaskListState> {
  TaskProvider() : super(const TaskListState()) {
    _loadMockTasks();
  }

  /// 加载模拟任务数据
  void _loadMockTasks() {
    state = state.copyWith(isLoading: true);

    Future.delayed(const Duration(milliseconds: 500), () {
      final now = DateTime.now();
      final mockTasks = [
        Task(
          id: 'task_001',
          title: '社区老年人健康关怀',
          description: '为社区独居老人提供健康检查、生活陪伴等服务',
          location: '朝阳区XX社区服务中心',
          latitude: 39.9219,
          longitude: 116.4435,
          startTime: now.add(const Duration(hours: 2)),
          endTime: now.add(const Duration(hours: 5)),
          status: TaskStatus.pending,
          priority: TaskPriority.high,
          creatorId: 'admin_001',
          participantIds: ['user_001', 'user_002'],
          maxParticipants: 5,
          requiredSkills: const ['医疗救助', '心理辅导'],
          createdAt: now,
        ),
        Task(
          id: 'task_002',
          title: '应急救援演练',
          description: '参与消防应急救援演练活动',
          location: '海淀区体育中心',
          latitude: 39.9847,
          longitude: 116.3081,
          startTime: now.add(const Duration(days: 1)),
          endTime: now.add(const Duration(days: 1, hours: 3)),
          status: TaskStatus.pending,
          priority: TaskPriority.urgent,
          creatorId: 'admin_001',
          participantIds: ['user_001'],
          maxParticipants: 20,
          requiredSkills: const ['应急救援'],
          createdAt: now,
        ),
        Task(
          id: 'task_003',
          title: '环保宣传活动',
          description: '在公园进行环保知识宣传',
          location: '奥林匹克森林公园',
          latitude: 40.0023,
          longitude: 116.3876,
          startTime: now.subtract(const Duration(days: 1)),
          endTime: now.subtract(const Duration(hours: 22)),
          status: TaskStatus.completed,
          priority: TaskPriority.medium,
          creatorId: 'admin_001',
          participantIds: ['user_001', 'user_003', 'user_004'],
          maxParticipants: 10,
          requiredSkills: const [],
          createdAt: now.subtract(const Duration(days: 3)),
          completedAt: now.subtract(const Duration(hours: 22)),
        ),
        Task(
          id: 'task_004',
          title: '交通引导志愿活动',
          description: '协助交警进行交通疏导',
          location: '西单商业区',
          latitude: 39.9075,
          longitude: 116.3722,
          startTime: now.add(const Duration(hours: 6)),
          endTime: now.add(const Duration(hours: 10)),
          status: TaskStatus.inProgress,
          priority: TaskPriority.high,
          creatorId: 'admin_002',
          participantIds: ['user_001', 'user_005'],
          maxParticipants: 8,
          requiredSkills: const ['交通引导'],
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
        Task(
          id: 'task_005',
          title: '儿童教育辅导',
          description: '为留守儿童提供课业辅导',
          location: '希望小学',
          latitude: 39.9288,
          longitude: 116.3889,
          startTime: now.add(const Duration(days: 2)),
          endTime: now.add(const Duration(days: 2, hours: 4)),
          status: TaskStatus.pending,
          priority: TaskPriority.medium,
          creatorId: 'admin_001',
          participantIds: [],
          maxParticipants: 6,
          requiredSkills: const ['教育辅导'],
          createdAt: now,
        ),
      ];

      state = state.copyWith(tasks: mockTasks, isLoading: false);
    });
  }

  /// 刷新任务列表
  Future<void> refresh() async {
    _loadMockTasks();
  }

  /// 参与任务
  Future<void> joinTask(String taskId, String userId) async {
    final updatedTasks = state.tasks.map((task) {
      if (task.id == taskId && !task.isFull) {
        return task.copyWith(
          participantIds: [...task.participantIds, userId],
        );
      }
      return task;
    }).toList();
    state = state.copyWith(tasks: updatedTasks);
  }

  /// 退出任务
  Future<void> leaveTask(String taskId, String userId) async {
    final updatedTasks = state.tasks.map((task) {
      if (task.id == taskId) {
        return task.copyWith(
          participantIds:
              task.participantIds.where((id) => id != userId).toList(),
        );
      }
      return task;
    }).toList();
    state = state.copyWith(tasks: updatedTasks);
  }

  /// 更新任务状态
  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    final updatedTasks = state.tasks.map((task) {
      if (task.id == taskId) {
        return task.copyWith(
          status: status,
          completedAt: status == TaskStatus.completed ? DateTime.now() : null,
        );
      }
      return task;
    }).toList();
    state = state.copyWith(tasks: updatedTasks);
  }

  /// 设置筛选
  void setFilter(TaskStatus? status) {
    state = state.copyWith(
      filterStatus: status,
      clearFilter: status == null,
    );
  }

  /// 设置搜索
  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// 根据ID获取任务
  Task? getTaskById(String taskId) {
    try {
      return state.tasks.firstWhere((t) => t.id == taskId);
    } catch (e) {
      return null;
    }
  }
}

/// 任务 Provider 实例
final taskProvider = StateNotifierProvider<TaskProvider, TaskListState>((ref) {
  return TaskProvider();
});

/// 单个任务 Provider
final taskByIdProvider = Provider.family<Task?, String>((ref, taskId) {
  final taskState = ref.watch(taskProvider);
  return taskState.tasks.firstWhere(
    (t) => t.id == taskId,
    orElse: () => Task(
      id: taskId,
      title: '未知任务',
      description: '',
      location: '',
      startTime: DateTime.now(),
      endTime: DateTime.now(),
      creatorId: '',
      createdAt: DateTime.now(),
    ),
  );
});
