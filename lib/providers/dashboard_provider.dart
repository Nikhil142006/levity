import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_provider.dart';
import 'auth_provider.dart';
import 'health_provider.dart';
import 'user_preferences_provider.dart';

final dashboardMetricsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final apiService = ref.watch(apiServiceProvider);
  final healthService = ref.watch(healthServiceProvider);
  
  final user = auth.currentUser;
  if (user == null) return null;
  
  try {
    // Check health connect preferences
    final prefs = ref.watch(userPreferencesProvider).value;
    final healthEnabled = prefs == null || prefs.healthConnectEnabled;
    
    // Fetch backend data and health data in PARALLEL
    final results = await Future.wait([
      apiService.getDashboardMetrics(user.uid),
      if (healthEnabled) _fetchHealthData(healthService),
    ]);
    
    final metrics = results[0] as Map<String, dynamic>;
    
    if (healthEnabled && results.length > 1) {
      final healthData = results[1] as Map<String, dynamic>;
      
      // Overlay real health data on top of backend data
      if ((healthData['steps'] as int) > 0) metrics['steps'] = healthData['steps'];
      if ((healthData['calories_burned'] as int) > 0) metrics['calories_burned'] = healthData['calories_burned'];
      if ((healthData['distance_km'] as double) > 0) metrics['distance_km'] = healthData['distance_km'];
      if ((healthData['heart_rate_bpm'] as int) > 0) metrics['heart_rate_bpm'] = healthData['heart_rate_bpm'];
      if ((healthData['sleep_hours'] as double) > 0) metrics['sleep_hours'] = healthData['sleep_hours'];
    }
    
    // Calculate local daily score based on steps and calories
    int currentSteps = metrics['steps'] ?? 0;
    int currentCalories = metrics['calories_burned'] ?? 0;
    int stepScore = ((currentSteps / 10000.0) * 50).clamp(0, 50).toInt();
    int calorieScore = ((currentCalories / 2000.0) * 50).clamp(0, 50).toInt();
    metrics['daily_score'] = stepScore + calorieScore;
    
    // Fire and forget background sync
    apiService.syncMetrics(user.uid, metrics);
    
    return metrics;
  } catch (e) {
    if (e.toString().contains('404')) {
      return null;
    }
    print('Dashboard API error: $e');
    return null;
  }
});

Future<Map<String, dynamic>> _fetchHealthData(healthService) async {
  final empty = {'steps': 0, 'calories_burned': 0, 'distance_km': 0.0, 'heart_rate_bpm': 0, 'sleep_hours': 0.0, 'active_minutes': 0};
  try {
    final hasPermission = await healthService.requestPermissions();
    if (!hasPermission) return empty;
    
    return await healthService.getAllTodayMetrics()
        .timeout(const Duration(seconds: 10), onTimeout: () => empty);
  } catch (e) {
    print('Health data fetch error: $e');
    return empty;
  }
}
