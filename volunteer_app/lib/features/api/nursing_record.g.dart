import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'nursing_record.g.dart';

/// 护理记录数据模型
class NursingRecordModel {
  final int? id;
  final String type; // medication_check, health_visit, phone_followup, emergency
  final String content;
  final int? patientId;
  final int? adminId;
  final DateTime? createdAt;

  const NursingRecordModel({
    this.id,
    this.type = 'medication_check',
    this.content = '',
    this.patientId,
    this.adminId,
    this.createdAt,
  });

  NursingRecordModel copyWith({
    int? id,
    String? type,
    String? content,
    int? patientId,
    int? adminId,
    DateTime? createdAt,
  }) {
    return NursingRecordModel(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      patientId: patientId ?? this.patientId,
      adminId: adminId ?? this.adminId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'content': content,
      'patient_id': patientId,
    };
  }

  factory NursingRecordModel.fromJson(Map<String, dynamic> json) {
    return NursingRecordModel(
      id: json['id'] as int,
      type: json['type'] as String? ?? 'medication_check',
      content: json['content'] as String? ?? '',
      patientId: json['patient_id'] as int?,
      adminId: json['admin_id'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

/// 护理类型枚举
enum NursingType {
  medicationCheck('medication_check', '用药检查'),
  healthVisit('health_visit', '健康随访'),
  phoneFollowup('phone_followup', '电话随访'),
  emergency('emergency', '紧急处理');

  const NursingType(this.value, this.label);
  final String value;
  final String label;

  static NursingType fromValue(String value) {
    return NursingType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NursingType.medicationCheck,
    );
  }
}

/// 护理记录列表 Provider
@riverpod
class NursingRecordList extends _$NursingRecordList {
  @override
  Future<List<NursingRecordModel>> build({int? patientId}) async {
    final apiService = ref.read(nursingRecordApiServiceProvider);
    final response = await apiService.getNursingRecords(patientId: patientId);
    return response.data;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> create(NursingRecordModel record) async {
    final apiService = ref.read(nursingRecordApiServiceProvider);
    await apiService.createNursingRecord(record);
    await refresh();
  }

  Future<void> delete(int id) async {
    final apiService = ref.read(nursingRecordApiServiceProvider);
    await apiService.deleteNursingRecord(id);
    await refresh();
  }
}
