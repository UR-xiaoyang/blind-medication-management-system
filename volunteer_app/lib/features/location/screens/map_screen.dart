import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/location_provider.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('实时地图'),
        backgroundColor: AppColors.success,
      ),
      body: location.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildLocationInfoCard(location),
                Expanded(
                  child: _buildMapPlaceholder(location),
                ),
                _buildBottomInfo(location),
              ],
            ),
    );
  }

  Widget _buildLocationInfoCard(LocationState location) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.my_location, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前位置',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  location.address ?? '正在获取...',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.refresh),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder(LocationState location) {
    return Container(
      color: const Color(0xFFE8F5E9),
      child: Stack(
        children: [
          // 模拟地图网格
          CustomPaint(
            size: Size.infinite,
            painter: MapGridPainter(),
          ),

          // 中心位置标记
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.success, width: 2),
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: AppColors.success,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Text(
                    '我的位置',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // 任务标记
          Positioned(
            top: 80,
            left: 60,
            child: _buildMapMarker('社区任务', AppColors.primary, Icons.assignment),
          ),
          Positioned(
            top: 180,
            right: 80,
            child: _buildMapMarker('救援任务', AppColors.accent, Icons.emergency),
          ),
          Positioned(
            bottom: 120,
            left: 40,
            child: _buildMapMarker('紧急警告', AppColors.danger, Icons.warning),
          ),
          Positioned(
            bottom: 200,
            right: 100,
            child: _buildMapMarker('团队成员', AppColors.success, Icons.person),
          ),

          // 缩放按钮
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {},
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {},
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'my_location',
                  onPressed: () {},
                  backgroundColor: AppColors.success,
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapMarker(String label, Color color, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomInfo(LocationState location) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: _buildInfoItem('附近任务', '${location.nearbyTasks.length}', AppColors.primary),
            ),
            Container(width: 1, height: 30, color: AppColors.divider),
            Expanded(
              child: _buildInfoItem('紧急警告', '${location.nearbyAlerts.length}', AppColors.danger),
            ),
            Container(width: 1, height: 30, color: AppColors.divider),
            Expanded(
              child: _buildInfoItem('团队成员', '5', AppColors.success),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.success.withOpacity(0.1)
      ..strokeWidth = 1;

    const gridSize = 40.0;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
