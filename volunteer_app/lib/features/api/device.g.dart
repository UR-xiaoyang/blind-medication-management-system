import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device.g.dart';

/// 设备数据模型
class DeviceModel {
  final int? id;
  final String deviceId;
  final String? deviceName;
  final String? firmware;
  final String status; // online, offline, error
  final DateTime? lastOnline;
  final String? ipAddress;
  final int? signal;
  final int? battery;
  final double? temperature;
  final String? slotStates;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DeviceModel({
    this.id,
    this.deviceId = '',
    this.deviceName,
    this.firmware,
    this.status = 'offline',
    this.lastOnline,
    this.ipAddress,
    this.signal,
    this.battery,
    this.temperature,
    this.slotStates,
    this.createdAt,
    this.updatedAt,
  });

  DeviceModel copyWith({
    int? id,
    String? deviceId,
    String? deviceName,
    String? firmware,
    String? status,
    DateTime? lastOnline,
    String? ipAddress,
    int? signal,
    int? battery,
    double? temperature,
    String? slotStates,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      firmware: firmware ?? this.firmware,
      status: status ?? this.status,
      lastOnline: lastOnline ?? this.lastOnline,
      ipAddress: ipAddress ?? this.ipAddress,
      signal: signal ?? this.signal,
      battery: battery ?? this.battery,
      temperature: temperature ?? this.temperature,
      slotStates: slotStates ?? this.slotStates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'firmware': firmware,
      'status': status,
    };
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as int,
      deviceId: json['device_id'] as String? ?? '',
      deviceName: json['device_name'] as String?,
      firmware: json['firmware'] as String?,
      status: json['status'] as String? ?? 'offline',
      lastOnline: json['last_online'] != null
          ? DateTime.parse(json['last_online'] as String)
          : null,
      ipAddress: json['ip_address'] as String?,
      signal: json['signal'] as int?,
      battery: json['battery'] as int?,
      temperature: json['temperature'] as double?,
      slotStates: json['slot_states'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

/// 设备实时状态模型
class DeviceStatus {
  final String deviceId;
  final String status;
  final DateTime? lastSeen;
  final int? battery;
  final double? temperature;
  final String? slotStates;
  final String? ipAddress;
  final int? signal;

  DeviceStatus({
    required this.deviceId,
    required this.status,
    this.lastSeen,
    this.battery,
    this.temperature,
    this.slotStates,
    this.ipAddress,
    this.signal,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      deviceId: json['device_id'] as String,
      status: json['status'] as String? ?? 'offline',
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      battery: json['battery'] as int?,
      temperature: json['temperature'] as double?,
      slotStates: json['slot_states'] as String?,
      ipAddress: json['ip_address'] as String?,
      signal: json['signal'] as int?,
    );
  }
}

/// 设备列表 Provider
@riverpod
class DeviceList extends _$DeviceList {
  @override
  Future<List<DeviceModel>> build() async {
    final apiService = ref.read(deviceApiServiceProvider);
    return await apiService.getDevices();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> create(DeviceModel device) async {
    final apiService = ref.read(deviceApiServiceProvider);
    await apiService.createDevice(device);
    await refresh();
  }

  Future<void> update(DeviceModel device) async {
    final apiService = ref.read(deviceApiServiceProvider);
    await apiService.updateDevice(device);
    await refresh();
  }

  Future<void> delete(int id) async {
    final apiService = ref.read(deviceApiServiceProvider);
    await apiService.deleteDevice(id);
    await refresh();
  }
}

/// 设备实时状态 Provider
@riverpod
Future<DeviceStatus> deviceStatus(
  DeviceStatusRef ref,
  String deviceId,
) async {
  final apiService = ref.read(deviceApiServiceProvider);
  return await apiService.getDeviceStatus(deviceId);
}
