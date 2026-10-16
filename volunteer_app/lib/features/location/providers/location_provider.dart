import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocationState {
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool isLoading;
  final List<MapMarker> nearbyTasks;
  final List<MapMarker> nearbyAlerts;

  const LocationState({
    this.latitude,
    this.longitude,
    this.address,
    this.isLoading = false,
    this.nearbyTasks = const [],
    this.nearbyAlerts = const [],
  });

  LocationState copyWith({
    double? latitude,
    double? longitude,
    String? address,
    bool? isLoading,
    List<MapMarker>? nearbyTasks,
    List<MapMarker>? nearbyAlerts,
  }) {
    return LocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      isLoading: isLoading ?? this.isLoading,
      nearbyTasks: nearbyTasks ?? this.nearbyTasks,
      nearbyAlerts: nearbyAlerts ?? this.nearbyAlerts,
    );
  }
}

class MapMarker {
  final String id;
  final String title;
  final double latitude;
  final double longitude;
  final MarkerType type;
  final String? description;

  MapMarker({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.description,
  });
}

enum MarkerType {
  task,
  alert,
  me,
  team,
}

class LocationProvider extends StateNotifier<LocationState> {
  LocationProvider() : super(const LocationState()) {
    _initLocation();
  }

  void _initLocation() {
    state = state.copyWith(isLoading: true);

    // 模拟获取位置（北京天安门）
    Future.delayed(const Duration(milliseconds: 800), () {
      state = state.copyWith(
        latitude: 39.9087,
        longitude: 116.3975,
        address: '北京市东城区天安门广场',
        isLoading: false,
        nearbyTasks: [
          MapMarker(
            id: 'task_loc_1',
            title: '社区服务任务',
            latitude: 39.9219,
            longitude: 116.4435,
            type: MarkerType.task,
            description: '朝阳区XX社区',
          ),
          MapMarker(
            id: 'task_loc_2',
            title: '应急救援演练',
            latitude: 39.9847,
            longitude: 116.3081,
            type: MarkerType.task,
            description: '海淀区体育中心',
          ),
        ],
        nearbyAlerts: [
          MapMarker(
            id: 'alert_loc_1',
            title: '紧急警告',
            latitude: 39.9075,
            longitude: 116.3722,
            type: MarkerType.alert,
            description: '需要立即关注',
          ),
        ],
      );
    });
  }

  void updateLocation(double lat, double lng, String address) {
    state = state.copyWith(
      latitude: lat,
      longitude: lng,
      address: address,
    );
  }
}

final locationProvider = StateNotifierProvider<LocationProvider, LocationState>((ref) {
  return LocationProvider();
});
