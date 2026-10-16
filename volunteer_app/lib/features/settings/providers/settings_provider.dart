import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_provider.dart';

/// 设置状态
class SettingsState {
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool darkMode;
  final String language;
  final bool locationEnabled;
  final bool autoUpdate;

  const SettingsState({
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.darkMode = false,
    this.language = 'zh',
    this.locationEnabled = true,
    this.autoUpdate = true,
  });

  SettingsState copyWith({
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? darkMode,
    String? language,
    bool? locationEnabled,
    bool? autoUpdate,
  }) {
    return SettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      autoUpdate: autoUpdate ?? this.autoUpdate,
    );
  }
}

class SettingsProvider extends StateNotifier<SettingsState> {
  SettingsProvider() : super(const SettingsState());

  void toggleNotifications(bool value) {
    state = state.copyWith(notificationsEnabled: value);
  }

  void toggleSound(bool value) {
    state = state.copyWith(soundEnabled: value);
  }

  void toggleVibration(bool value) {
    state = state.copyWith(vibrationEnabled: value);
  }

  void toggleDarkMode(bool value) {
    state = state.copyWith(darkMode: value);
  }

  void setLanguage(String language) {
    state = state.copyWith(language: language);
  }

  void toggleLocation(bool value) {
    state = state.copyWith(locationEnabled: value);
  }

  void toggleAutoUpdate(bool value) {
    state = state.copyWith(autoUpdate: value);
  }
}

final settingsProvider = StateNotifierProvider<SettingsProvider, SettingsState>((ref) {
  return SettingsProvider();
});
