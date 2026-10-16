import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/home/screens/home_screen.dart';
import '../features/tasks/screens/task_list_screen.dart';
import '../features/tasks/screens/task_detail_screen.dart';
import '../features/alerts/screens/alert_screen.dart';
import '../features/alerts/screens/alert_detail_screen.dart';
import '../features/team/screens/team_screen.dart';
import '../features/team/screens/team_chat_screen.dart';
import '../features/statistics/screens/stats_screen.dart';
import '../features/location/screens/map_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/settings/screens/settings_screen.dart';

/// 路由配置
final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // 如果未登录且不在登录页，重定向到登录页
      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }

      // 如果已登录且在登录页，重定向到首页
      if (isLoggedIn && isLoginRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/tasks',
        builder: (context, state) => const TaskListScreen(),
      ),
      GoRoute(
        path: '/tasks/:id',
        builder: (context, state) {
          final taskId = state.pathParameters['id']!;
          return TaskDetailScreen(taskId: taskId);
        },
      ),
      GoRoute(
        path: '/alerts',
        builder: (context, state) => const AlertScreen(),
      ),
      GoRoute(
        path: '/alerts/:id',
        builder: (context, state) {
          final alertId = state.pathParameters['id']!;
          return AlertDetailScreen(alertId: alertId);
        },
      ),
      GoRoute(
        path: '/team',
        builder: (context, state) => const TeamScreen(),
      ),
      GoRoute(
        path: '/chat/:memberId',
        builder: (context, state) {
          final memberId = state.pathParameters['memberId']!;
          return TeamChatScreen(memberId: memberId);
        },
      ),
      GoRoute(
        path: '/stats',
        builder: (context, state) => const StatsScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '页面未找到',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  );
});
