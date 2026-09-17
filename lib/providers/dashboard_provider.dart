import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_provider.dart';
import 'auth_provider.dart';
import 'health_provider.dart';

final dashboardMetricsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final apiService = ref.watch(apiServiceProvider);
  
  final user = auth.currentUser;
  if (user == null) return null;
  
  try {
    // Get backend mock data (AI insights, goals, etc)
    final metrics = await apiService.getDashboardMetrics(user.uid);
    
    // Try to get real health data
    try {
      final results = await Future.wait([
        ref.watch(todayStepsProvider.future).timeout(const Duration(seconds: 15), onTimeout: () => 0),
        ref.watch(todayCaloriesProvider.future).timeout(const Duration(seconds: 15), onTimeout: () => 0),
        ref.watch(todayDistanceProvider.future).timeout(const Duration(seconds: 15), onTimeout: () => 0.0),
        ref.watch(latestHeartRateProvider.future).timeout(const Duration(seconds: 15), onTimeout: () => 0),
        ref.watch(lastNightSleepProvider.future).timeout(const Duration(seconds: 15), onTimeout: () => 0.0),
        ref.watch(activeMinutesProvider.future).timeout(const Duration(seconds: 15), onTimeout: () => 0),
      ]);
      
      final realSteps = results[0] as int;
      final realCalories = results[1] as int;
      final realDistance = results[2] as double;
      final realHeartRate = results[3] as int;
      final realSleep = results[4] as double;
      final realActiveMinutes = results[5] as int;

      if (realSteps > 0) metrics['steps'] = realSteps;
      if (realCalories > 0) metrics['calories_burned'] = realCalories;
      if (realDistance > 0) metrics['distance_km'] = double.parse(realDistance.toStringAsFixed(2));
      if (realHeartRate > 0) metrics['heart_rate_bpm'] = realHeartRate;
      if (realSleep > 0) metrics['sleep_hours'] = double.parse(realSleep.toStringAsFixed(1));
      if (realActiveMinutes > 0) metrics['active_minutes'] = realActiveMinutes;
      
      // Calculate local daily score based on steps and calories
      int currentSteps = metrics['steps'] ?? 0;
      int currentCalories = metrics['calories_burned'] ?? 0;
      
      // Step goal: 10,000 (up to 50 points)
      int stepScore = ((currentSteps / 10000.0) * 50).clamp(0, 50).toInt();
      // Calorie goal: 2,000 (up to 50 points)
      int calorieScore = ((currentCalories / 2000.0) * 50).clamp(0, 50).toInt();
      
      metrics['daily_score'] = stepScore + calorieScore;
      
      // Fire and forget background sync
      apiService.syncMetrics(user.uid, metrics);
      
    } catch (e) {
      // Ignore health connect errors and fall back to mock data
      print('Health connect error: $e');
    }

    return metrics;
  } catch (e) {
    if (e.toString().contains('404')) {
      return null;
    }
    print('Dashboard API error: $e');
    return null;
  }
});
