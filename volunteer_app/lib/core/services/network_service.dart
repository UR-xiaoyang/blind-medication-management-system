import 'package:dio/dio.dart';
import '../constants/api_constants.dart';

/// 网络服务基类
class NetworkService {
  static NetworkService? _instance;
  late Dio _dio;

  NetworkService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    // 添加拦截器
    _dio.interceptors.addAll([
      _AuthInterceptor(),
      _LogInterceptor(),
      _ErrorInterceptor(),
    ]);
  }

  factory NetworkService() {
    _instance ??= NetworkService._internal();
    return _instance!;
  }

  Dio get dio => _dio;

  // GET 请求
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
  }) {
    return _dio.get(
      path,
      queryParameters: queryParams,
      cancelToken: cancelToken,
    );
  }

  // POST 请求
  Future<Response> post(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) {
    return _dio.post(
      path,
      data: data,
      cancelToken: cancelToken,
    );
  }

  // PUT 请求
  Future<Response> put(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) {
    return _dio.put(
      path,
      data: data,
      cancelToken: cancelToken,
    );
  }

  // DELETE 请求
  Future<Response> delete(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) {
    return _dio.delete(
      path,
      data: data,
      cancelToken: cancelToken,
    );
  }

  // 更新 Token
  void updateToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // 清除 Token
  void clearToken() {
    _dio.options.headers.remove('Authorization');
  }
}

/// 认证拦截器 - 自动添加 Token
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 这里可以从本地存储读取 token
    // final token = StorageService().getToken();
    // if (token != null) {
    //   options.headers['Authorization'] = 'Bearer $token';
    // }
    handler.next(options);
  }
}

/// 日志拦截器 - 开发环境显示请求日志
class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('╔══════════════════════════════════════════════════════════════════');
    print('║ REQUEST: ${options.method} ${options.uri}');
    print('║ Headers: ${options.headers}');
    if (options.data != null) {
      print('║ Data: ${options.data}');
    }
    if (options.queryParameters.isNotEmpty) {
      print('║ Query: ${options.queryParameters}');
    }
    print('╚══════════════════════════════════════════════════════════════════');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('╔══════════════════════════════════════════════════════════════════');
    print('║ RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
    print('║ Data: ${response.data}');
    print('╚══════════════════════════════════════════════════════════════════');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('╔══════════════════════════════════════════════════════════════════');
    print('║ ERROR: ${err.type} - ${err.message}');
    if (err.response != null) {
      print('║ Response: ${err.response?.data}');
    }
    print('╚══════════════════════════════════════════════════════════════════');
    handler.next(err);
  }
}

/// 错误拦截器 - 统一处理错误
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw ApiException(
          code: -1,
          message: '网络超时，请检查网络设置',
        );
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final data = err.response?.data;
        throw ApiException(
          code: statusCode ?? -1,
          message: _handleBadResponse(statusCode, data),
        );
      case DioExceptionType.cancel:
        throw ApiException(
          code: -2,
          message: '请求已取消',
        );
      case DioExceptionType.connectionError:
        throw ApiException(
          code: -3,
          message: '网络连接失败，请检查网络设置',
        );
      default:
        throw ApiException(
          code: -4,
          message: '网络错误: ${err.message}',
        );
    }
  }

  String _handleBadResponse(int? statusCode, dynamic data) {
    String message = '服务器错误';
    try {
      if (data is Map) {
        message = data['error']?.toString() ?? data['message']?.toString() ?? message;
      } else if (data is String) {
        message = data;
      }
    } catch (_) {}

    switch (statusCode) {
      case 400:
        return message;
      case 401:
        return '登录已过期，请重新登录';
      case 403:
        return '没有权限访问';
      case 404:
        return '请求的资源不存在';
      case 500:
        return '服务器错误';
      default:
        return message;
    }
  }
}

/// API 异常类
class ApiException implements Exception {
  final int code;
  final String message;

  ApiException({required this.code, required this.message});

  @override
  String toString() => 'ApiException($code): $message';
}
