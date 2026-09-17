import 'package:health/health.dart';

class HealthConnectService {
  final Health _health = Health();

  final types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.WEIGHT,
  ];

  Future<bool> requestPermissions() async {
    try {
      _health.configure();
    } catch (e) {
      print('Health configure error: $e');
    }
    
    final permissions = types.map((e) => HealthDataAccess.READ).toList();
    
    // Check if we already have permissions
    bool? hasPermissions = await _health.hasPermissions(types, permissions: permissions);
    if (hasPermissions == true) {
      return true;
    }

    // Request permissions
    try {
      bool requested = await _health.requestAuthorization(types, permissions: permissions);
      return requested;
    } catch (e) {
      print('Health requestAuthorization error: $e');
      return false;
    }
  }

  Future<List<HealthDataPoint>> getHealthDataForLast7Days() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 7));
    
    try {
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: yesterday,
        endTime: now,
        types: types,
      );
      return Health().removeDuplicates(healthData);
    } catch (e) {
      print("Caught exception in getHealthDataFromTypes: $e");
      return [];
    }
  }

  // Aggregate helpers
  Future<int> getStepsToday() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      int? steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getCaloriesToday() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final healthData = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      double total = 0.0;
      for (var p in healthData) {
        if (p.value is NumericHealthValue) {
          total += (p.value as NumericHealthValue).numericValue.toDouble();
        }
      }
      return total.toInt();
    } catch (e) {
      return 0;
    }
  }

  Future<double> getDistanceToday() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final healthData = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.DISTANCE_DELTA],
      );
      double totalMeters = 0.0;
      for (var p in healthData) {
        if (p.value is NumericHealthValue) {
          totalMeters += (p.value as NumericHealthValue).numericValue.toDouble();
        }
      }
      return totalMeters / 1000.0; // Convert to km
    } catch (e) {
      return 0.0;
    }
  }

  Future<int> getLatestHeartRate() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 1)); // Look back 1 day max
    try {
      final healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.HEART_RATE],
      );
      if (healthData.isEmpty) return 0;
      healthData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final val = healthData.first.value;
      if (val is NumericHealthValue) {
        return val.numericValue.toInt();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<double> getSleepLastNight() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(hours: 24));
    try {
      final healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.SLEEP_ASLEEP],
      );
      double totalMinutes = 0.0;
      for (var p in healthData) {
        if (p.value is NumericHealthValue) {
          totalMinutes += (p.value as NumericHealthValue).numericValue.toDouble();
        }
      }
      return totalMinutes / 60.0; // Convert to hours
    } catch (e) {
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> getSpO2History() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    try {
      final healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.BLOOD_OXYGEN],
      );
      healthData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      
      return healthData.map((p) {
        double val = 0.0;
        if (p.value is NumericHealthValue) {
          val = (p.value as NumericHealthValue).numericValue.toDouble();
        }
        // Health package sometimes returns percentage as decimal (e.g. 0.98) or whole number (98)
        if (val < 1.0 && val > 0.0) val *= 100; 
        
        return {
          'date': p.dateTo.toIso8601String().split('T')[0],
          'time': "${p.dateTo.hour.toString().padLeft(2, '0')}:${p.dateTo.minute.toString().padLeft(2, '0')}",
          'value': val.toInt()
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<double> getLatestWeight() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30)); // Look back 30 days
    try {
      final healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.WEIGHT],
      );
      if (healthData.isEmpty) return 0.0;
      healthData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final val = healthData.first.value;
      if (val is NumericHealthValue) {
        return val.numericValue.toDouble();
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<int> getActiveMinutesToday() async {
    return 0; // Fallback to backend mock since HC metric was missing
  }

  Future<Map<String, dynamic>> getWorkoutMetrics(DateTime startTime) async {
    final now = DateTime.now();
    try {
      final healthData = await _health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: now,
        types: [HealthDataType.HEART_RATE, HealthDataType.ACTIVE_ENERGY_BURNED, HealthDataType.DISTANCE_DELTA],
      );
      
      int latestHr = 0;
      double calories = 0.0;
      double distance = 0.0;
      
      // Sort by date descending so the first heart rate we encounter is the latest
      healthData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      bool hrFound = false;

      for (var p in healthData) {
        if (p.type == HealthDataType.HEART_RATE && p.value is NumericHealthValue && !hrFound) {
          latestHr = (p.value as NumericHealthValue).numericValue.toInt();
          hrFound = true;
        } else if (p.type == HealthDataType.ACTIVE_ENERGY_BURNED && p.value is NumericHealthValue) {
          calories += (p.value as NumericHealthValue).numericValue.toDouble();
        } else if (p.type == HealthDataType.DISTANCE_DELTA && p.value is NumericHealthValue) {
          distance += (p.value as NumericHealthValue).numericValue.toDouble();
        }
      }
      return {
        'heart_rate': latestHr,
        'calories': calories.toInt(),
        'distance': distance / 1000.0, // km
      };
    } catch (e) {
      return {'heart_rate': 0, 'calories': 0, 'distance': 0.0};
    }
  }
}
