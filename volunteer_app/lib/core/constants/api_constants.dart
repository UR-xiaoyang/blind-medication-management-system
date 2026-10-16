/// API 配置常量
class ApiConstants {
  // 基础配置 - 可根据环境修改
  // 注意: 这里留了修改接口，可以配置不同的环境
  static const String _devBaseUrl = 'http://localhost:8080/api';
  static const String _prodBaseUrl = 'https://your-production-domain.com/api';
  static const String _stagingBaseUrl = 'https://staging.your-domain.com/api';

  // 当前环境 - 修改这里切换环境
  static const String currentEnv = 'development'; // development, staging, production

  // 获取当前环境的 Base URL
  static String get baseUrl {
    switch (currentEnv) {
      case 'production':
        return _prodBaseUrl;
      case 'staging':
        return _stagingBaseUrl;
      case 'development':
      default:
        return _devBaseUrl;
    }
  }

  // 超时配置
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // 分页默认值
  static const int defaultPage = 1;
  static const int defaultPageSize = 20;

  // WebSocket 配置
  static String get wsUrl {
    switch (currentEnv) {
      case 'production':
        return 'wss://your-production-domain.com/api/ws';
      case 'staging':
        return 'wss://staging.your-domain.com/api/ws';
      case 'development':
      default:
        return 'ws://localhost:8080/api/ws';
    }
  }
}
