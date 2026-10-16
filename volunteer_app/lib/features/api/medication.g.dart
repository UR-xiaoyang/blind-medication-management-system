import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'medication.g.dart';

/// 药品数据模型
class MedicationModel {
  final int? id;
  final String name;
  final String specification;
  final String dosage;
  final String frequency;
  final int stockTotal;
  final int stockUsed;
  final String? sideEffects;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MedicationModel({
    this.id,
    this.name = '',
    this.specification = '',
    this.dosage = '',
    this.frequency = '',
    this.stockTotal = 0,
    this.stockUsed = 0,
    this.sideEffects,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  MedicationModel copyWith({
    int? id,
    String? name,
    String? specification,
    String? dosage,
    String? frequency,
    int? stockTotal,
    int? stockUsed,
    String? sideEffects,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      specification: specification ?? this.specification,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      stockTotal: stockTotal ?? this.stockTotal,
      stockUsed: stockUsed ?? this.stockUsed,
      sideEffects: sideEffects ?? this.sideEffects,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'specification': specification,
      'dosage': dosage,
      'frequency': frequency,
      'stock_total': stockTotal,
      'stock_used': stockUsed,
      'side_effects': sideEffects,
      'notes': notes,
    };
  }

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    return MedicationModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      specification: json['specification'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      stockTotal: json['stock_total'] as int? ?? 0,
      stockUsed: json['stock_used'] as int? ?? 0,
      sideEffects: json['side_effects'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

/// 药品列表 Provider
@riverpod
class MedicationList extends _$MedicationList {
  @override
  Future<List<MedicationModel>> build() async {
    final apiService = ref.read(medicationApiServiceProvider);
    return await apiService.getMedications();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> create(MedicationModel medication) async {
    final apiService = ref.read(medicationApiServiceProvider);
    await apiService.createMedication(medication);
    await refresh();
  }

  Future<void> update(MedicationModel medication) async {
    final apiService = ref.read(medicationApiServiceProvider);
    await apiService.updateMedication(medication);
    await refresh();
  }

  Future<void> delete(int id) async {
    final apiService = ref.read(medicationApiServiceProvider);
    await apiService.deleteMedication(id);
    await refresh();
  }
}
