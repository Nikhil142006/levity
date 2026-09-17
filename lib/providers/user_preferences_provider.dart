import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class UserPreferencesState {
  final double? weightKg;
  final double? heightCm;
  final int? age;
  final String? gender;
  final bool isDarkMode;
  final bool useMetric;
  final bool notificationsEnabled;
  final bool healthConnectEnabled;

  UserPreferencesState({
    this.weightKg,
    this.heightCm,
    this.age,
    this.gender,
    this.isDarkMode = false,
    this.useMetric = true,
    this.notificationsEnabled = true,
    this.healthConnectEnabled = true,
  });

  UserPreferencesState copyWith({
    double? weightKg,
    double? heightCm,
    int? age,
    String? gender,
    bool? isDarkMode,
    bool? useMetric,
    bool? notificationsEnabled,
    bool? healthConnectEnabled,
  }) {
    return UserPreferencesState(
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      useMetric: useMetric ?? this.useMetric,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      healthConnectEnabled: healthConnectEnabled ?? this.healthConnectEnabled,
    );
  }
}

class UserPreferencesNotifier extends AsyncNotifier<UserPreferencesState> {
  static const _keyWeight = 'user_weight_kg';
  static const _keyHeight = 'user_height_cm';
  static const _keyAge = 'user_age';
  static const _keyGender = 'user_gender';
  static const _keyDarkMode = 'setting_dark_mode';
  static const _keyMetric = 'setting_metric';
  static const _keyNotifications = 'setting_notifications';
  static const _keyHealthConnect = 'setting_health_connect';

  @override
  Future<UserPreferencesState> build() async {
    final prefs = await SharedPreferences.getInstance();
    
    return UserPreferencesState(
      weightKg: prefs.getDouble(_keyWeight),
      heightCm: prefs.getDouble(_keyHeight),
      age: prefs.getInt(_keyAge),
      gender: prefs.getString(_keyGender),
      isDarkMode: prefs.getBool(_keyDarkMode) ?? false,
      useMetric: prefs.getBool(_keyMetric) ?? true,
      notificationsEnabled: prefs.getBool(_keyNotifications) ?? true,
      healthConnectEnabled: prefs.getBool(_keyHealthConnect) ?? true,
    );
  }

  Future<void> updateWeight(double weight) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyWeight, weight);
    state = AsyncData(state.value!.copyWith(weightKg: weight));
  }

  Future<void> updateHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyHeight, height);
    state = AsyncData(state.value!.copyWith(heightCm: height));
  }

  Future<void> updateAge(int age) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAge, age);
    state = AsyncData(state.value!.copyWith(age: age));
  }

  Future<void> updateGender(String gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGender, gender);
    state = AsyncData(state.value!.copyWith(gender: gender));
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
