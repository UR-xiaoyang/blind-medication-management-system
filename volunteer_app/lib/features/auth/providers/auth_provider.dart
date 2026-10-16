import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/network_service.dart';
import '../core/constants/api_constants.dart';
import '../shared/models/user.dart';

/// 认证 API 服务
class AuthApiService {
  final NetworkService _network = NetworkService();

  /// 管理员登录
  Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    final response = await _network.post(
      '/login',
      data: {
        'username': username,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final admin = data['admin'] as Map<String, dynamic>;

      // 更新 token
      _network.updateToken(token);

      return AuthResponse(
        token: token,
        user: User(
          id: admin['id'].toString(),
          name: admin['real_name']?.toString() ?? admin['username'].toString(),
          phone: admin['phone']?.toString() ?? '',
          email: '',
          role: admin['role']?.toString() ?? 'admin',
          skills: const [],
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        ),
      );
    } else {
      throw ApiException(
        code: response.statusCode ?? -1,
        message: response.data?['error']?.toString() ?? '登录失败',
      );
    }
  }

  /// 初始化管理员（首次运行）
  Future<void> initAdmin({
    required String username,
    required String password,
  }) async {
    await _network.post(
      '/init-admin',
      data: {
        'username': username,
        'password': password,
      },
    );
  }

  /// 获取当前用户信息
  Future<User> getProfile() async {
    final response = await _network.get('/profile');
    final data = response.data as Map<String, dynamic>;
    return User.fromJson(data);
  }
}

/// 认证响应
class AuthResponse {
  final String token;
  final User user;

  AuthResponse({required this.token, required this.user});
}

/// 认证状态
class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null && token != null;

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: clearUser ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 认证 Provider
class AuthProvider extends StateNotifier<AuthState> {
  final AuthApiService _apiService = AuthApiService();

  AuthProvider() : super(const AuthState());

  /// 登录
  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _apiService.login(
        username: username,
        password: password,
      );

      state = state.copyWith(
        user: response.user,
        token: response.token,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 退出登录
  Future<void> logout() async {
    state = state.copyWith(clearUser: true, isLoading: false);
    NetworkService().clearToken();
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// 认证 Provider 实例
final authProvider = StateNotifierProvider<AuthProvider, AuthState>((ref) {
  return AuthProvider();
});

/// 是否已登录 Provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isAuthenticated;
});
