import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.taskList),
        actions: [
          IconButton(
            onPressed: () => _showFilterDialog(context),
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildSearchBar(),
          _buildStatusFilter(),
          Expanded(
            child: _buildTaskList(taskState),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索任务标题或地点',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    ref.read(taskProvider.notifier).setSearch('');
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (value) {
          ref.read(taskProvider.notifier).setSearch(value);
        },
      ),
    );
  }

  Widget _buildStatusFilter() {
    final currentFilter = ref.watch(taskProvider).filterStatus;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('全部', currentFilter == null, () {
              ref.read(taskProvider.notifier).setFilter(null);
            }),
            const SizedBox(width: 8),
            ...TaskStatus.values.map((status) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  status.label,
                  currentFilter == status,
                  () {
                    ref.read(taskProvider.notifier).setFilter(status);
                  },
                  color: status.color,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap, {
    Color? color,
  }) {
    final baseColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? baseColor : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? baseColor : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(TaskListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final tasks = state.filteredTasks;

    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(taskProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return TaskCard(
            task: task,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskDetailScreen(taskId: task.id),
                ),
              );
            },
            onJoin: () {
              ref.read(taskProvider.notifier).joinTask(task.id, 'user_001');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已成功参与任务')),
              );
            },
            onLeave: () {
              ref.read(taskProvider.notifier).leaveTask(task.id, 'user_001');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已退出任务')),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          const Text(
            AppStrings.noData,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '排序方式',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('按时间排序'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.priority_high),
                title: const Text('按优先级排序'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('按距离排序'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
