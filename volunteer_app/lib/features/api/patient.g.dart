import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'api_service.dart';

part 'patient.g.dart';

/// 患者数据模型
@riverpod
class Patient extends _$Patient {
  @override
  PatientModel build() {
    return const PatientModel();
  }
}

/// 患者数据模型
class PatientModel {
  final int? id;
  final String name;
  final String gender;
  final int age;
  final String? phone;
  final String? address;
  final String? emergencyName;
  final String? emergencyPhone;
  final String? medicalNotes;
  final String? deviceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PatientModel({
    this.id,
    this.name = '',
    this.gender = '男',
    this.age = 0,
    this.phone,
    this.address,
    this.emergencyName,
    this.emergencyPhone,
    this.medicalNotes,
    this.deviceId,
    this.createdAt,
    this.updatedAt,
  });

  PatientModel copyWith({
    int? id,
    String? name,
    String? gender,
    int? age,
    String? phone,
    String? address,
    String? emergencyName,
    String? emergencyPhone,
    String? medicalNotes,
    String? deviceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      emergencyName: emergencyName ?? this.emergencyName,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gender': gender,
      'age': age,
      'phone': phone,
      'address': address,
      'emergency_name': emergencyName,
      'emergency_phone': emergencyPhone,
      'medical_notes': medicalNotes,
      'device_id': deviceId,
    };
  }

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      gender: json['gender'] as String? ?? '男',
      age: json['age'] as int? ?? 0,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      emergencyName: json['emergency_name'] as String?,
      emergencyPhone: json['emergency_phone'] as String?,
      medicalNotes: json['medical_notes'] as String?,
      deviceId: json['device_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

/// 患者列表 Provider
@riverpod
class PatientList extends _$PatientList {
  @override
  Future<List<PatientModel>> build() async {
    final apiService = ref.read(patientApiServiceProvider);
    final response = await apiService.getPatients();
    return response.data;
  }

  /// 刷新列表
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// 创建患者
  Future<void> createPatient(PatientModel patient) async {
    final apiService = ref.read(patientApiServiceProvider);
    await apiService.createPatient(patient);
    await refresh();
  }

  /// 更新患者
  Future<void> updatePatient(PatientModel patient) async {
    final apiService = ref.read(patientApiServiceProvider);
    await apiService.updatePatient(patient);
    await refresh();
  }

  /// 删除患者
  Future<void> deletePatient(int id) async {
    final apiService = ref.read(patientApiServiceProvider);
    await apiService.deletePatient(id);
    await refresh();
  }
}

/// 搜索关键词 Provider
@riverpod
class PatientSearchQuery extends _$PatientSearchQuery {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

/// 搜索患者 Provider
@riverpod
Future<List<PatientModel>> searchPatients(SearchPatientsRef ref) async {
  final query = ref.watch(patientSearchQueryProvider);
  if (query.isEmpty) {
    return ref.watch(patientListProvider.future);
  }

  final apiService = ref.read(patientApiServiceProvider);
  final response = await apiService.getPatients(keyword: query);
  return response.data;
}
