import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/health_connect_service.dart';
import 'package:health/health.dart';
import 'user_preferences_provider.dart';

final healthServiceProvider = Provider<HealthConnectService>((ref) {
  return HealthConnectService();
});

final healthPermissionsProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(healthServiceProvider);
  return await service.requestPermissions();
});

final healthDataProvider = FutureProvider<List<HealthDataPoint>>((ref) async {
  final permissions = await ref.watch(healthPermissionsProvider.future);
  if (!permissions) {
    throw Exception('Health permissions not granted');
  }
  
  final service = ref.watch(healthServiceProvider);
  return await service.getHealthDataForLast7Days();
});

final todayStepsProvider = FutureProvider<int>((ref) async {
  final prefs = ref.watch(userPreferencesProvider).value;
  if (prefs != null && !prefs.healthConnectEnabled) return 0;
  final permissions = await ref.watch(healthPermissionsProvider.future);
  if (!permissions) return 0;
  return await ref.watch(healthServiceProvider).getStepsToday();
});

final todayCaloriesProvider = FutureProvider<int>((ref) async {
  final prefs = ref.watch(userPreferencesProvider).value;
  if (prefs != null && !prefs.healthConnectEnabled) return 0;
  final permissions = await ref.watch(healthPermissionsProvider.future);
  if (!permissions) return 0;
  return await ref.watch(healthServiceProvider).getCaloriesToday();
});

final todayDistanceProvider = FutureProvider<double>((ref) async {
  final prefs = ref.watch(userPreferencesProvider).value;
  if (prefs != null && !prefs.healthConnectEnabled) return 0.0;
  final permissions = await ref.watch(healthPermissionsProvider.future);
  if (!permissions) return 0.0;
  return await ref.watch(healthServiceProvider).getDistanceToday();
});

final latestHeartRateProvider = FutureProvider<int>((ref) async {
  final prefs = ref.watch(userPreferencesProvider).value;
  if (prefs != null && !prefs.healthConnectEnabled) return 0;
  final permissions = await ref.watch(healthPermissionsProvider.future);
  if (!permissions) return 0;
  return await ref.watch(healthServiceProvider).getLatestHeartRate();
});

final lastNightSleepProvider = FutureProvider<double>((ref) async {
  final prefs = ref.watch(userPreferencesProvider).value;
  if (prefs != null && !prefs.healthConnectEnabled) return 0.0;
  final permissions = await ref.watch(healthPermissionsProvider.future);
  if (!permissions) return 0.0;
  return await ref.watch(healthServiceProvider).getSleepLastNight();
});

final activeMinutesProvider = FutureProvider<int>((ref) async {
  final prefs = ref.watch(userPreferencesProvider).value;
  if (prefs != null && !prefs.healthConnectEnabled) return 0;
  final permissions = await ref.watch(healthPermissionsProvider.future);
  if (!permissions) return 0;
  return await ref.watch(healthServiceProvider).getActiveMinutesToday();
});

final spo2HistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final permissions = await ref.watch(healthPermissionsProvider.future);
  if (!permissions) return [];
  return await ref.watch(healthServiceProvider).getSpO2History();
});

final latestWeightProvider = FutureProvider<double>((ref) async {
  final permissions = await ref.watch(healthPermissionsProvider.future);
  if (!permissions) return 0.0;
  return await ref.watch(healthServiceProvider).getLatestWeight();
});
