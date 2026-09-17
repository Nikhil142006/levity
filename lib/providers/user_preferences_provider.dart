import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class UserPreferencesState {
  final bool isDarkMode;
  final bool useMetric;
  final bool notificationsEnabled;
  final bool healthConnectEnabled;

  UserPreferencesState({
    this.isDarkMode = false,
    this.useMetric = true,
    this.notificationsEnabled = true,
    this.healthConnectEnabled = true,
  });

  UserPreferencesState copyWith({
    bool? isDarkMode,
    bool? useMetric,
    bool? notificationsEnabled,
    bool? healthConnectEnabled,
  }) {
    return UserPreferencesState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      useMetric: useMetric ?? this.useMetric,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      healthConnectEnabled: healthConnectEnabled ?? this.healthConnectEnabled,
    );
  }
}

class UserPreferencesNotifier extends AsyncNotifier<UserPreferencesState> {
  static const _keyDarkMode = 'setting_dark_mode';
  static const _keyMetric = 'setting_metric';
  static const _keyNotifications = 'setting_notifications';
  static const _keyHealthConnect = 'setting_health_connect';

  @override
  Future<UserPreferencesState> build() async {
    final prefs = await SharedPreferences.getInstance();
    
    return UserPreferencesState(
      isDarkMode: prefs.getBool(_keyDarkMode) ?? false,
      useMetric: prefs.getBool(_keyMetric) ?? true,
      notificationsEnabled: prefs.getBool(_keyNotifications) ?? true,
      healthConnectEnabled: prefs.getBool(_keyHealthConnect) ?? true,
    );
  }

  Future<void> toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
    state = AsyncData(state.value!.copyWith(isDarkMode: value));
  }

  Future<void> toggleMetric(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMetric, value);
    state = AsyncData(state.value!.copyWith(useMetric: value));
  }

  Future<void> toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, value);
    state = AsyncData(state.value!.copyWith(notificationsEnabled: value));
    
    final notifService = ref.read(notificationServiceProvider);
    if (value) {
      await notifService.init();
    } else {
      await notifService.cancelAllNotifications();
    }
  }

  Future<void> toggleHealthConnect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHealthConnect, value);
    state = AsyncData(state.value!.copyWith(healthConnectEnabled: value));
  }
}

final userPreferencesProvider = AsyncNotifierProvider<UserPreferencesNotifier, UserPreferencesState>(() {
  return UserPreferencesNotifier();
});
