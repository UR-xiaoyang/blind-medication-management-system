import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import '../core/services/network_service.dart';
import '../core/constants/api_constants.dart';
import 'patient.dart';
import 'medication.dart';
import 'dose_package.dart';
import 'schedule.dart';
import 'device.dart';
import 'report.dart';
import 'nursing_record.dart';

part 'patient_api.g.dart';

/// 患者 API 服务
class PatientApiService {
  final NetworkService _network = NetworkService();

  /// 获取患者列表（分页）
  Future<PaginatedResponse<Patient>> getPatients({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    CancelToken? cancelToken,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (keyword != null && keyword.isNotEmpty) {
      queryParams['keyword'] = keyword;
    }

    final response = await _network.get(
      '/patients',
      queryParams: queryParams,
      cancelToken: cancelToken,
    );

    final data = response.data as Map<String, dynamic>;
    final List<dynamic> items = data['data'] ?? [];
    return PaginatedResponse(
      data: items.map((item) => Patient.fromJson(item)).toList(),
      total: data['total'] as int,
      page: data['page'] as int,
      pageSize: data['page_size'] as int,
    );
  }

  /// 获取患者详情
  Future<Patient> getPatientById(int id) async {
    final response = await _network.get('/patients/$id');
    return Patient.fromJson(response.data);
  }

  /// 新增患者
  Future<Patient> createPatient(Patient patient) async {
    final response = await _network.post(
      '/patients',
      data: patient.toJson(),
    );
    return Patient.fromJson(response.data);
  }

  /// 更新患者
  Future<Patient> updatePatient(Patient patient) async {
    final response = await _network.put(
      '/patients/${patient.id}',
      data: patient.toJson(),
    );
    return Patient.fromJson(response.data);
  }

  /// 删除患者
  Future<void> deletePatient(int id) async {
    await _network.delete('/patients/$id');
  }
}

/// 药品 API 服务
class MedicationApiService {
  final NetworkService _network = NetworkService();

  /// 获取药品列表
  Future<List<Medication>> getMedications({
    CancelToken? cancelToken,
  }) async {
    final response = await _network.get(
      '/medications',
      cancelToken: cancelToken,
    );
    final List<dynamic> items = response.data as List<dynamic>;
    return items.map((item) => Medication.fromJson(item)).toList();
  }

  /// 新增药品
  Future<Medication> createMedication(Medication medication) async {
    final response = await _network.post(
      '/medications',
      data: medication.toJson(),
    );
    return Medication.fromJson(response.data);
  }

  /// 更新药品
  Future<Medication> updateMedication(Medication medication) async {
    final response = await _network.put(
      '/medications/${medication.id}',
      data: medication.toJson(),
    );
    return Medication.fromJson(response.data);
  }

  /// 删除药品
  Future<void> deleteMedication(int id) async {
    await _network.delete('/medications/$id');
  }
}

/// 剂次包 API 服务
class DosePackageApiService {
  final NetworkService _network = NetworkService();

  /// 获取剂次包列表
  Future<List<DosePackage>> getDosePackages({
    CancelToken? cancelToken,
  }) async {
    final response = await _network.get(
      '/dose-packages',
      cancelToken: cancelToken,
    );
    final List<dynamic> items = response.data as List<dynamic>;
    return items.map((item) => DosePackage.fromJson(item)).toList();
  }

  /// 新增剂次包
  Future<DosePackage> createDosePackage(DosePackage package) async {
    final response = await _network.post(
      '/dose-packages',
      data: package.toJson(),
    );
    return DosePackage.fromJson(response.data);
  }

  /// 更新剂次包
  Future<DosePackage> updateDosePackage(DosePackage package) async {
    final response = await _network.put(
      '/dose-packages/${package.id}',
      data: package.toJson(),
    );
    return DosePackage.fromJson(response.data);
  }

  /// 删除剂次包
  Future<void> deleteDosePackage(int id) async {
    await _network.delete('/dose-packages/$id');
  }
}

/// 服药计划 API 服务
class ScheduleApiService {
  final NetworkService _network = NetworkService();

  /// 获取计划列表
  Future<List<Schedule>> getSchedules({
    CancelToken? cancelToken,
  }) async {
    final response = await _network.get(
      '/schedules',
      cancelToken: cancelToken,
    );
    final List<dynamic> items = response.data as List<dynamic>;
    return items.map((item) => Schedule.fromJson(item)).toList();
  }

  /// 新增计划
  Future<Schedule> createSchedule(Schedule schedule) async {
    final response = await _network.post(
      '/schedules',
      data: schedule.toJson(),
    );
    return Schedule.fromJson(response.data);
  }

  /// 更新计划
  Future<Schedule> updateSchedule(Schedule schedule) async {
    final response = await _network.put(
      '/schedules/${schedule.id}',
      data: schedule.toJson(),
    );
    return Schedule.fromJson(response.data);
  }

  /// 删除计划
  Future<void> deleteSchedule(int id) async {
    await _network.delete('/schedules/$id');
  }
}

/// 设备 API 服务
class DeviceApiService {
  final NetworkService _network = NetworkService();

  /// 获取设备列表
  Future<List<Device>> getDevices({
    CancelToken? cancelToken,
  }) async {
    final response = await _network.get(
      '/devices',
      cancelToken: cancelToken,
    );
    final List<dynamic> items = response.data as List<dynamic>;
    return items.map((item) => Device.fromJson(item)).toList();
  }

  /// 注册设备
  Future<Device> createDevice(Device device) async {
    final response = await _network.post(
      '/devices',
      data: device.toJson(),
    );
    return Device.fromJson(response.data);
  }

  /// 更新设备
  Future<Device> updateDevice(Device device) async {
    final response = await _network.put(
      '/devices/${device.id}',
      data: device.toJson(),
    );
    return Device.fromJson(response.data);
  }

  /// 删除设备
  Future<void> deleteDevice(int id) async {
    await _network.delete('/devices/$id');
  }

  /// 获取设备实时状态
  Future<DeviceStatus> getDeviceStatus(String deviceId) async {
    final response = await _network.get('/devices/$deviceId/status');
    return DeviceStatus.fromJson(response.data);
  }

  /// 发送远程命令
  Future<void> sendCommand(String deviceId, Map<String, dynamic> command) async {
    await _network.post('/devices/$deviceId/command', data: command);
  }
}

/// 报告 API 服务
class ReportApiService {
  final NetworkService _network = NetworkService();

  /// 获取报告列表（分页）
  Future<PaginatedResponse<Report>> getReports({
    int page = 1,
    int pageSize = 20,
    int? patientId,
    String? type,
    CancelToken? cancelToken,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (patientId != null) queryParams['patient_id'] = patientId;
    if (type != null && type.isNotEmpty) queryParams['type'] = type;

    final response = await _network.get(
      '/reports',
      queryParams: queryParams,
      cancelToken: cancelToken,
    );

    final data = response.data as Map<String, dynamic>;
    final List<dynamic> items = data['data'] ?? [];
    return PaginatedResponse(
      data: items.map((item) => Report.fromJson(item)).toList(),
      total: data['total'] as int,
      page: data['page'] as int,
      pageSize: data['page_size'] as int,
    );
  }

  /// 新增报告
  Future<Report> createReport(Report report) async {
    final response = await _network.post(
      '/reports',
      data: report.toJson(),
    );
    return Report.fromJson(response.data);
  }

  /// 删除报告
  Future<void> deleteReport(int id) async {
    await _network.delete('/reports/$id');
  }
}

/// 护理记录 API 服务
class NursingRecordApiService {
  final NetworkService _network = NetworkService();

  /// 获取护理记录列表（分页）
  Future<PaginatedResponse<NursingRecord>> getNursingRecords({
    int page = 1,
    int pageSize = 20,
    int? patientId,
    CancelToken? cancelToken,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (patientId != null) queryParams['patient_id'] = patientId;

    final response = await _network.get(
      '/nursing-records',
      queryParams: queryParams,
      cancelToken: cancelToken,
    );

    final data = response.data as Map<String, dynamic>;
    final List<dynamic> items = data['data'] ?? [];
    return PaginatedResponse(
      data: items.map((item) => NursingRecord.fromJson(item)).toList(),
      total: data['total'] as int,
      page: data['page'] as int,
      pageSize: data['page_size'] as int,
    );
  }

  /// 新增护理记录
  Future<NursingRecord> createNursingRecord(NursingRecord record) async {
    final response = await _network.post(
      '/nursing-records',
      data: record.toJson(),
    );
    return NursingRecord.fromJson(response.data);
  }

  /// 删除护理记录
  Future<void> deleteNursingRecord(int id) async {
    await _network.delete('/nursing-records/$id');
  }
}

/// 服药日志 API 服务
class MedicationLogApiService {
  final NetworkService _network = NetworkService();

  /// 获取服药日志（分页）
  Future<PaginatedResponse<MedicationLog>> getMedicationLogs({
    int page = 1,
    int pageSize = 20,
    int? patientId,
    String? startDate,
    String? endDate,
    CancelToken? cancelToken,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (patientId != null) queryParams['patient_id'] = patientId;
    if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;

    final response = await _network.get(
      '/medication-logs',
      queryParams: queryParams,
      cancelToken: cancelToken,
    );

    final data = response.data as Map<String, dynamic>;
    final List<dynamic> items = data['data'] ?? [];
    return PaginatedResponse(
      data: items.map((item) => MedicationLog.fromJson(item)).toList(),
      total: data['total'] as int,
      page: data['page'] as int,
      pageSize: data['page_size'] as int,
    );
  }
}

/// 统计 API 服务
class StatsApiService {
  final NetworkService _network = NetworkService();

  /// 获取统计数据
  Future<StatsData> getStats() async {
    final response = await _network.get('/stats');
    return StatsData.fromJson(response.data);
  }
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

/// 统计数据模型
class StatsData {
  final int totalPatients;
  final int totalDevices;
  final int onlineDevices;
  final int totalMedications;
  final int totalSchedules;
  final int totalDosePackages;
  final int totalReports;
  final int totalNursingRecords;

  StatsData({
    required this.totalPatients,
    required this.totalDevices,
    required this.onlineDevices,
    required this.totalMedications,
    required this.totalSchedules,
    required this.totalDosePackages,
    required this.totalReports,
    required this.totalNursingRecords,
  });

  factory StatsData.fromJson(Map<String, dynamic> json) {
    return StatsData(
      totalPatients: json['total_patients'] as int? ?? 0,
      totalDevices: json['total_devices'] as int? ?? 0,
      onlineDevices: json['online_devices'] as int? ?? 0,
      totalMedications: json['total_medications'] as int? ?? 0,
      totalSchedules: json['total_schedules'] as int? ?? 0,
      totalDosePackages: json['total_dose_packages'] as int? ?? 0,
      totalReports: json['total_reports'] as int? ?? 0,
      totalNursingRecords: json['total_nursing_records'] as int? ?? 0,
    );
  }
}

// Riverpod Providers
@riverpod
PatientApiService patientApiService(PatientApiServiceRef ref) {
  return PatientApiService();
}

@riverpod
MedicationApiService medicationApiService(MedicationApiServiceRef ref) {
  return MedicationApiService();
}

@riverpod
DeviceApiService deviceApiService(DeviceApiServiceRef ref) {
  return DeviceApiService();
}

@riverpod
ReportApiService reportApiService(ReportApiServiceRef ref) {
  return ReportApiService();
}

@riverpod
NursingRecordApiService nursingRecordApiService(NursingRecordApiServiceRef ref) {
  return NursingRecordApiService();
}

@riverpod
StatsApiService statsApiService(StatsApiServiceRef ref) {
  return StatsApiService();
}
