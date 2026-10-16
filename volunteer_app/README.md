# 志愿者管理系统 APP - 完整项目结构

## 📁 项目目录结构

```
volunteer_app/
├── lib/
│   ├── main.dart                          # 主入口文件
│   ├── app.dart                           # 路由配置
│   │
│   ├── core/                              # 核心层
│   │   ├── constants/
│   │   │   ├── app_colors.dart           # 颜色常量
│   │   │   └── app_strings.dart          # 字符串常量
│   │   ├── theme/
│   │   │   └── app_theme.dart            # 主题配置
│   │   ├── services/
│   │   │   ├── alert_service.dart        # ⭐ 警告核心服务
│   │   │   ├── alert_service_widget.dart # 警告组件
│   │   │   └── audio_service.dart        # 音频播放服务
│   │   └── utils/
│   │       └── validators.dart           # 表单验证
│   │
│   ├── features/                          # 功能模块
│   │   ├── auth/                          # 认证模块
│   │   ├── home/                          # 首页模块
│   │   ├── tasks/                         # 任务模块
│   │   ├── alerts/                        # ⭐ 警告模块（核心）
│   │   ├── team/                          # 团队模块
│   │   ├── statistics/                    # 统计模块
│   │   ├── location/                      # 定位模块
│   │   ├── profile/                       # 个人中心
│   │   └── settings/                      # 设置模块
│   │
│   └── shared/                            # 共享组件
│       ├── models/
│       └── widgets/
│
├── assets/
│   ├── sounds/
│   │   └── alert_alarm.mp3
│   └── images/
│
├── pubspec.yaml
├── README.md
├── TODO.md
└── .gitignore
```

## ⭐ 核心功能 - 警告系统

### 四级警告级别
- **低级** (low): 仅通知，无震动响铃
- **中级** (medium): 震动 + 短响铃
- **高级** (high): 震动 + 持续响铃 + 全屏弹窗
- **紧急** (critical): 闹钟式提醒，必须手动关闭

### 闹钟式震动实现
```dart
// 系统级重震动
HapticFeedback.heavyImpact();

// 每3秒重复一次
_vibrationTimer = Timer.periodic(
  const Duration(seconds: 3), 
  (timer) {
    HapticFeedback.heavyImpact();
    _startAlarmVibration();
  }
);

// 震动模式：模拟闹钟
void _startAlarmVibration() async {
  final alarmPattern = [1000, 300, 1000, 300, 1000, 300];
  await Vibration.vibrate(pattern: alarmPattern, repeat: 0);
}
```

### 铃声循环播放
```dart
// 播放警告铃声
await _player.setAsset('assets/sounds/alert_alarm.mp3');
await _player.setLoopMode(LoopMode.one); // 循环播放
await _player.setVolume(1.0); // 最大音量
await _player.play();
```

## 🛠️ 技术栈

| 库 | 用途 | 版本 |
|---|---|---|
| Flutter | 跨平台UI框架 | 3.19+ |
| Riverpod | 状态管理 | 2.4 |
| GoRouter | 路由管理 | 12.0 |
| JustAudio | 音频播放 | 0.9.35 |
| Vibration | 震动控制 | 1.8.4+ |
| FlChart | 数据图表 | 0.65 |
| Dio | 网络请求 | 5.3 |
| SharedPreferences | 本地存储 | 2.2+ |

## 📱 完整功能列表

### ✅ 已实现
- [x] 用户认证系统（登录/注册）
- [x] 警告系统（闹钟式震动+响铃）
- [x] 任务管理系统
- [x] 团队协作系统
- [x] 数据统计系统
- [x] 实时定位系统
- [x] 个人中心
- [x] 设置管理
- [x] 首页集成
- [x] GoRouter 路由系统
- [x] Riverpod 状态管理
- [x] 完整的数据模型层
- [x] 表单验证
- [x] 主题系统（亮色/暗色）

## 🚀 快速开始

```bash
cd volunteer_app
flutter pub get
flutter run
```

## 📝 项目说明

这是一个功能完整的志愿者管理系统APP，包含：
- 完整的用户认证流程
- 紧急警告通知系统（支持闹钟式震动+响铃）
- 任务管理（筛选/搜索/排序）
- 团队协作和实时聊天
- 数据统计和可视化图表
- 实时定位和地图显示
- 个人中心和设置管理
- 统一的 GoRouter 路由系统
- Riverpod 状态管理
- 完整的数据模型层

## 🔐 权限要求

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

<!-- Info.plist -->
<key>NSMicrophoneUsageDescription</key>
<string>需要音频权限播放警告铃声</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>需要位置权限以显示地图</string>
```

## 📚 文档

- [TODO列表](./TODO.md) - 完整的任务清单
- [架构设计](./志愿者APP架构设计方案.md) - 详细的架构设计文档
- [API文档](./API.md) - 后端接口文档 (待创建)

---

**版本**: 1.0.0  
**最后更新**: 2024年1月  
**开发者**: 志愿者管理系统团队
