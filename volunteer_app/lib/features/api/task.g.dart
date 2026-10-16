import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import '../core/services/network_service.dart';
import '../core/constants/api_constants.dart';

part 'task.g.dart';

/// 任务 API 服务
class TaskApiService {
  final NetworkService _network = NetworkService();

  /// 获取任务列表（分页）
  Future<PaginatedResponse<TaskModel>> getTasks({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    int? patientId,
    CancelToken? cancelToken,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (keyword != null && keyword.isNotEmpty) queryParams['keyword'] = keyword;
    if (patientId != null) queryParams['patient_id'] = patientId;

    final response = await _network.get(
      '/tasks',
      queryParams: queryParams,
      cancelToken: cancelToken,
    );

    final data = response.data as Map<String, dynamic>;
    final List<dynamic> items = data['data'] ?? [];
    return PaginatedResponse(
      data: items.map((item) => TaskModel.fromJson(item)).toList(),
      total: data['total'] as int,
      page: data['page'] as int,
      pageSize: data['page_size'] as int,
    );
  }

  /// 获取任务详情
  Future<TaskModel> getTaskById(int id) async {
    final response = await _network.get('/tasks/$id');
    return TaskModel.fromJson(response.data);
  }

  /// 创建任务
  Future<TaskModel> createTask(TaskModel task) async {
    final response = await _network.post('/tasks', data: task.toJson());
    return TaskModel.fromJson(response.data);
  }

  /// 更新任务
  Future<TaskModel> updateTask(TaskModel task) async {
    final response = await _network.put('/tasks/${task.id}', data: task.toJson());
    return TaskModel.fromJson(response.data);
  }

  /// 删除任务
  Future<void> deleteTask(int id) async {
    await _network.delete('/tasks/$id');
  }

  /// 获取患者的服药计划
  Future<List<ScheduleModel>> getSchedulesByPatient(int patientId) async {
    final response = await _network.get('/schedules', queryParams: {'patient_id': patientId});
    final List<dynamic> items = response.data as List<dynamic>;
    return items.map((item) => ScheduleModel.fromJson(item)).toList();
  }
}

/// 任务数据模型
class TaskModel {
  final int? id;
  final String title;
  final String description;
  final String status; // pending, in_progress, completed, cancelled
  final int? patientId;
  final String? patientName;
  final DateTime? dueDate;
  final List<int> assigneeIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TaskModel({
    this.id,
    this.title = '',
    this.description = '',
    this.status = 'pending',
    this.patientId,
    this.patientName,
    this.dueDate,
    this.assigneeIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  TaskModel copyWith({
    int? id,
    String? title,
    String? description,
    String? status,
    int? patientId,
    String? patientName,
    DateTime? dueDate,
    List<int>? assigneeIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      dueDate: dueDate ?? this.dueDate,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'status': status,
      'patient_id': patientId,
      'due_date': dueDate?.toIso8601String(),
      'assignee_ids': assigneeIds,
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      patientId: json['patient_id'] as int?,
      patientName: json['patient_name'] as String?,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      assigneeIds: (json['assignee_ids'] as List?)?.cast<int>() ?? [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }
}

/// 服药计划数据模型
class ScheduleModel {
  final int? id;
  final int patientId;
  final int medicationId;
  final String? medicationName;
  final String triggerTime;
  final int slotIndex;
  final bool enabled;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ScheduleModel({
    this.id,
    required this.patientId,
    required this.medicationId,
    this.medicationName,
    this.triggerTime = '',
    this.slotIndex = 0,
    this.enabled = true,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
  });

  ScheduleModel copyWith({
    int? id,
    int? patientId,
    int? medicationId,
    String? medicationName,
    String? triggerTime,
    int? slotIndex,
    bool? enabled,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      medicationId: medicationId ?? this.medicationId,
      medicationName: medicationName ?? this.medicationName,
      triggerTime: triggerTime ?? this.triggerTime,
      slotIndex: slotIndex ?? this.slotIndex,
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient_id': patientId,
      'medication_id': medicationId,
      'trigger_time': triggerTime,
      'slot_index': slotIndex,
      'enabled': enabled,
      'status': status,
    };
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] as int,
      patientId: json['patient_id'] as int,
      medicationId: json['medication_id'] as int,
      medicationName: json['medication_name'] as String?,
      triggerTime: json['trigger_time'] as String? ?? '',
      slotIndex: json['slot_index'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }
}

/// 任务列表 Provider
@riverpod
class TaskList extends _$TaskList {
  @override
  Future<List<TaskModel>> build() async {
    final apiService = ref.read(taskApiServiceProvider);
    final response = await apiService.getTasks();
    return response.data;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> createTask(TaskModel task) async {
    final apiService = ref.read(taskApiServiceProvider);
    await apiService.createTask(task);
    await refresh();
  }

  Future<void> updateTask(TaskModel task) async {
    final apiService = ref.read(taskApiServiceProvider);
    await apiService.updateTask(task);
    await refresh();
  }

  Future<void> deleteTask(int id) async {
    final apiService = ref.read(taskApiServiceProvider);
    await apiService.deleteTask(id);
    await refresh();
  }
}

/// 单个任务 Provider
@riverpod
Future<TaskModel> task(TaskRef ref, int taskId) async {
  final apiService = ref.read(taskApiServiceProvider);
  return await apiService.getTaskById(taskId);
}

/// 患者服药计划列表 Provider
@riverpod
Future<List<ScheduleModel>> schedulesByPatient(SchedulesByPatientRef ref, int patientId) async {
  final apiService = ref.read(taskApiServiceProvider);
  return await apiService.getSchedulesByPatient(patientId);
}

/// 分页响应包装类
class PaginatedResponse<T> {
  final List<T> data;
  final int total;
  final int page;
  final int pageSize;

  PaginatedResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
  });
}

@riverpod
TaskApiService taskApiService(TaskApiServiceRef ref) {
  return TaskApiService();
}
