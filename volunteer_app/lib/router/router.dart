import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/tasks/screens/task_list_screen.dart';
import '../features/alerts/screens/alert_screen.dart';
import '../features/team/screens/team_screen.dart';
import '../features/statistics/screens/stats_screen.dart';
import '../features/location/screens/map_screen.dart';
import 'main.dart';

/// 路由提供者
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login';

      // 如果未认证且不在登录页，则重定向到登录页
      if (!isAuthenticated && !isLoginRoute) {
        return '/login';
      }

      // 如果已认证且在登录页，则重定向到首页
      if (isAuthenticated && isLoginRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // 登录路由
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // 主路由
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainScreen(navigationShell: navigationShell),
        branches: [
          // 首页
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // 任务
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const TaskListScreen(),
              ),
            ],
          ),
          // 警告
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/alerts',
                builder: (context, state) => const AlertScreen(),
              ),
            ],
          ),
          // 团队
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/team',
                builder: (context, state) => const TeamScreen(),
              ),
            ],
          ),
          // 统计
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
          // 地图
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
