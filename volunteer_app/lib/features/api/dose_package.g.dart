import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dose_package.g.dart';

/// 剂次包数据模型
class DosePackageModel {
  final int? id;
  final String name;
  final String triggerTime;
  final int slotIndex;
  final bool enabled;
  final String status; // pending, taken, missed
  final List<DosePackageItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DosePackageModel({
    this.id,
    this.name = '',
    this.triggerTime = '',
    this.slotIndex = 0,
    this.enabled = true,
    this.status = 'pending',
    this.items = const [],
    this.createdAt,
    this.updatedAt,
  });

  DosePackageModel copyWith({
    int? id,
    String? name,
    String? triggerTime,
    int? slotIndex,
    bool? enabled,
    String? status,
    List<DosePackageItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DosePackageModel(
      id: id ?? this.id,
      name: name ?? this.name,
      triggerTime: triggerTime ?? this.triggerTime,
      slotIndex: slotIndex ?? this.slotIndex,
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'trigger_time': triggerTime,
      'slot_index': slotIndex,
      'enabled': enabled,
      'status': status,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory DosePackageModel.fromJson(Map<String, dynamic> json) {
    return DosePackageModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      triggerTime: json['trigger_time'] as String? ?? '',
      slotIndex: json['slot_index'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      status: json['status'] as String? ?? 'pending',
      items: (json['items'] as List?)
              ?.map((item) => DosePackageItem.fromJson(item))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

/// 剂次包项目
class DosePackageItem {
  final int? id;
  final int medicationId;
  final String? medicationName;
  final double quantity;
  final String unit;
  final String? notes;

  DosePackageItem({
    this.id,
    required this.medicationId,
    this.medicationName,
    this.quantity = 1,
    this.unit = '片',
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'medication_id': medicationId,
      'quantity': quantity,
      'unit': unit,
      'notes': notes,
    };
  }

  factory DosePackageItem.fromJson(Map<String, dynamic> json) {
    return DosePackageItem(
      id: json['id'] as int?,
      medicationId: json['medication_id'] as int,
      medicationName: json['medication_name'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: json['unit'] as String? ?? '片',
      notes: json['notes'] as String?,
    );
  }
}

/// 剂次包列表 Provider
@riverpod
class DosePackageList extends _$DosePackageList {
  @override
  Future<List<DosePackageModel>> build() async {
    final apiService = ref.read(dosePackageApiServiceProvider);
    return await apiService.getDosePackages();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> create(DosePackageModel package) async {
    final apiService = ref.read(dosePackageApiServiceProvider);
    await apiService.createDosePackage(package);
    await refresh();
  }

  Future<void> update(DosePackageModel package) async {
    final apiService = ref.read(dosePackageApiServiceProvider);
    await apiService.updateDosePackage(package);
    await refresh();
  }

  Future<void> delete(int id) async {
    final apiService = ref.read(dosePackageApiServiceProvider);
    await apiService.deleteDosePackage(id);
    await refresh();
  }
}
