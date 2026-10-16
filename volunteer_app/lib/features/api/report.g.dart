import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'report.g.dart';

/// 报告数据模型
class ReportModel {
  final int? id;
  final String type; // blood_pressure, blood_sugar, heart_rate, temperature, other
  final String value;
  final String unit;
  final String source; // manual, device
  final int? patientId;
  final DateTime? measuredAt;
  final DateTime? createdAt;

  const ReportModel({
    this.id,
    this.type = 'other',
    this.value = '',
    this.unit = '',
    this.source = 'manual',
    this.patientId,
    this.measuredAt,
    this.createdAt,
  });

  ReportModel copyWith({
    int? id,
    String? type,
    String? value,
    String? unit,
    String? source,
    int? patientId,
    DateTime? measuredAt,
    DateTime? createdAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      type: type ?? this.type,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      source: source ?? this.source,
      patientId: patientId ?? this.patientId,
      measuredAt: measuredAt ?? this.measuredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'value': value,
      'unit': unit,
      'source': source,
      'patient_id': patientId,
      'measured_at': measuredAt?.toIso8601String(),
    };
  }

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as int,
      type: json['type'] as String? ?? 'other',
      value: json['value'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      source: json['source'] as String? ?? 'manual',
      patientId: json['patient_id'] as int?,
      measuredAt: json['measured_at'] != null
          ? DateTime.parse(json['measured_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

/// 报告类型枚举
enum ReportType {
  bloodPressure('blood_pressure', '血压', 'mmHg'),
  bloodSugar('blood_sugar', '血糖', 'mmol/L'),
  heartRate('heart_rate', '心率', '次/分'),
  temperature('temperature', '体温', '°C'),
  other('other', '其他', '');

  const ReportType(this.value, this.label, this.unit);
  final String value;
  final String label;
  final String unit;

  static ReportType fromValue(String value) {
    return ReportType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ReportType.other,
    );
  }
}

/// 报告列表 Provider
@riverpod
class ReportList extends _$ReportList {
  @override
  Future<List<ReportModel>> build({int? patientId, String? type}) async {
    final apiService = ref.read(reportApiServiceProvider);
    final response = await apiService.getReports(
      patientId: patientId,
      type: type,
    );
    return response.data;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> create(ReportModel report) async {
    final apiService = ref.read(reportApiServiceProvider);
    await apiService.createReport(report);
    await refresh();
  }

  Future<void> delete(int id) async {
    final apiService = ref.read(reportApiServiceProvider);
    await apiService.deleteReport(id);
    await refresh();
  }
}
