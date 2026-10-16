import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/alert_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/home/screens/home_screen.dart';
import 'features/tasks/screens/task_list_screen.dart';
import 'features/alerts/screens/alert_screen.dart';
import 'features/team/screens/team_screen.dart';
import 'features/statistics/screens/stats_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 注册语言
  // Intl.defaultLocale = 'zh_CN';

  runApp(
    const ProviderScope(
      child: VolunteerApp(),
    ),
  );
}

class VolunteerApp extends ConsumerStatefulWidget {
  const VolunteerApp({super.key});

  @override
  ConsumerState<VolunteerApp> createState() => _VolunteerAppState();
}

class _VolunteerAppState extends ConsumerState<VolunteerApp> {
  final AlertService _alertService = AlertService();

  @override
  void initState() {
    super.initState();
    // 全局监听警告状态
    _alertService.alertStatusStream.listen((status) {
      if (status == AlertStatus.active && mounted) {
        _showGlobalAlertDialog();
      }
    });
  }

  void _showGlobalAlertDialog() {
    // 使用 NavigatorKey 显示全局对话框
    // 这里简化处理，实际应该使用 NavigatorKey
  }

  @override
  void dispose() {
    _alertService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: '志愿者管理系统',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
    );
  }
}

/// 设置 Provider 需要导入
import 'features/settings/providers/settings_provider.dart';
