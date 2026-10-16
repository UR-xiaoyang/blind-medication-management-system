import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('通知设置'),
          _buildSwitchTile(
            icon: Icons.notifications_outlined,
            title: '允许通知',
            subtitle: '接收任务提醒和警告通知',
            value: settings.notificationsEnabled,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).toggleNotifications(value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.volume_up_outlined,
            title: '警告声音',
            subtitle: '播放警告提示音',
            value: settings.soundEnabled,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).toggleSound(value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.vibration,
            title: '警告震动',
            subtitle: '震动提醒（闹钟式震动）',
            value: settings.vibrationEnabled,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).toggleVibration(value);
            },
          ),

          const Divider(),
          _buildSectionHeader('应用设置'),
          _buildSwitchTile(
            icon: Icons.dark_mode_outlined,
            title: '深色模式',
            subtitle: '降低屏幕亮度，保护眼睛',
            value: settings.darkMode,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).toggleDarkMode(value);
            },
          ),
          _buildNavigationTile(
            icon: Icons.language_outlined,
            title: '语言设置',
            subtitle: settings.language == 'zh' ? '简体中文' : 'English',
            onTap: () => _showLanguageDialog(context, ref),
          ),

          const Divider(),
          _buildSectionHeader('隐私和位置'),
          _buildSwitchTile(
            icon: Icons.location_on_outlined,
            title: '位置服务',
            subtitle: '允许获取您的位置信息',
            value: settings.locationEnabled,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).toggleLocation(value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.system_update_outlined,
            title: '自动更新',
            subtitle: '自动检查应用更新',
            value: settings.autoUpdate,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).toggleAutoUpdate(value);
            },
          ),

          const Divider(),
          _buildSectionHeader('关于'),
          _buildNavigationTile(
            icon: Icons.info_outline,
            title: '关于志愿者管理系统',
            subtitle: '版本 1.0.0',
            onTap: () {},
          ),
          _buildNavigationTile(
            icon: Icons.description_outlined,
            title: '用户协议',
            onTap: () {},
          ),
          _buildNavigationTile(
            icon: Icons.privacy_tip_outlined,
            title: '隐私政策',
            onTap: () {},
          ),
          _buildNavigationTile(
            icon: Icons.help_outline,
            title: '帮助与反馈',
            onTap: () {},
          ),

          const Divider(),
          _buildSectionHeader('账号'),
          _buildNavigationTile(
            icon: Icons.delete_outline,
            title: '清除缓存',
            subtitle: '2.5MB',
            onTap: () => _showClearCacheDialog(context),
            titleColor: AppColors.textPrimary,
          ),
          _buildNavigationTile(
            icon: Icons.logout,
            title: '退出登录',
            onTap: () => _showLogoutDialog(context, ref),
            titleColor: AppColors.danger,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      color: Colors.white,
      child: SwitchListTile(
        secondary: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: TextStyle(color: titleColor ?? AppColors.textPrimary),
        ),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
            : null,
        trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.textHint),
        onTap: onTap,
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择语言'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption(context, ref, 'zh', '简体中文', true),
              _buildLanguageOption(context, ref, 'en', 'English', false),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    WidgetRef ref,
    String code,
    String name,
    bool isDefault,
  ) {
    final settings = ref.watch(settingsProvider);
    final isSelected = settings.language == code;

    return ListTile(
      title: Text(name),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primary)
          : null,
      onTap: () {
        ref.read(settingsProvider.notifier).setLanguage(code);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已切换到$name')),
        );
      },
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除应用缓存吗？这不会影响您的个人数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清除')),
              );
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('您确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pop(context);
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
  }
}
