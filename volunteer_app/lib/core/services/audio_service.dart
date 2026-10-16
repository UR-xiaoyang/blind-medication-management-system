import 'package:just_audio/just_audio.dart';

/// 音频服务 - 管理警告铃声播放
class AudioService {
  // 单例模式
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // 音频播放器
  final AudioPlayer _player = AudioPlayer();

  // 状态
  bool _isPlaying = false;
  double _volume = 1.0; // 最大音量

  bool get isPlaying => _isPlaying;

  /// 播放警告铃声
  Future<void> playAlertSound({bool loop = false}) async {
    try {
      // 停止当前播放
      await stopSound();

      // 设置音频源
      // 注意: 需要在 assets/sounds/ 目录下放置 alert_alarm.mp3 文件
      await _player.setAsset('assets/sounds/alert_alarm.mp3');

      // 设置循环模式
      await _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);

      // 设置音量
      await _player.setVolume(_volume);

      // 开始播放
      await _player.play();

      _isPlaying = true;
      print('开始播放警告铃声, 循环: $loop, 音量: $_volume');
    } catch (e) {
      print('播放警告铃声失败: $e');
      _isPlaying = false;
    }
  }

  /// 停止播放
  Future<void> stopSound() async {
    try {
      await _player.stop();
      _isPlaying = false;
      print('停止播放警告铃声');
    } catch (e) {
      print('停止播放失败: $e');
    }
  }

  /// 暂停播放
  Future<void> pauseSound() async {
    try {
      await _player.pause();
      _isPlaying = false;
    } catch (e) {
      print('暂停播放失败: $e');
    }
  }

  /// 恢复播放
  Future<void> resumeSound() async {
    try {
      await _player.play();
      _isPlaying = true;
    } catch (e) {
      print('恢复播放失败: $e');
    }
  }

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  /// 释放资源
  Future<void> dispose() async {
    await _player.dispose();
  }
}
