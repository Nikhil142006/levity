import 'package:health/health.dart';

class HealthConnectService {
  final Health _health = Health();
  
  // Cache for batch-fetched today's data
  List<HealthDataPoint>? _todayCache;
  DateTime? _todayCacheTime;
  static const _cacheDuration = Duration(seconds: 30);

  final types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.WEIGHT,
  ];

  bool _permissionsCached = false;
  bool _permissionsResult = false;

  Future<bool> requestPermissions() async {
    if (_permissionsCached) return _permissionsResult;
    
    try {
      _health.configure();
    } catch (e) {
      print('Health configure error: $e');
    }
    
    final permissions = types.map((e) => HealthDataAccess.READ).toList();
    
    bool? hasPermissions = await _health.hasPermissions(types, permissions: permissions);
    if (hasPermissions == true) {
      _permissionsCached = true;
      _permissionsResult = true;
      return true;
    }

    try {
      bool requested = await _health.requestAuthorization(types, permissions: permissions);
      _permissionsCached = true;
      _permissionsResult = requested;
      return requested;
    } catch (e) {
      print('Health requestAuthorization error: $e');
      return false;
    }
  }

  /// Batch fetch all today's health data in one call and cache it
  Future<List<HealthDataPoint>> _getTodayData() async {
    final now = DateTime.now();
    
    // Return cache if still fresh
    if (_todayCache != null && _todayCacheTime != null &&
        now.difference(_todayCacheTime!) < _cacheDuration) {
      return _todayCache!;
    }
    
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final healthData = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [
          HealthDataType.HEART_RATE,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.DISTANCE_DELTA,
        ],
      );
      _todayCache = Health().removeDuplicates(healthData);
      _todayCacheTime = now;
      return _todayCache!;
    } catch (e) {
      print("Batch fetch error: $e");
      return [];
    }
  }

  /// Get all today's metrics in a single batch call
  Future<Map<String, dynamic>> getAllTodayMetrics() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    
    // Fetch raw data (calories, distance, heart rate), total steps, sleep, and weight all in PARALLEL
    final results = await Future.wait([
      _getTodayData(),
      _health.getTotalStepsInInterval(midnight, now).catchError((_) => null),
      _getSleepData(now),
      _getWeightData(now),
    ]);
    
    final data = results[0] as List<HealthDataPoint>;
    int steps = (results[1] as int?) ?? 0;
    double sleepHours = results[2] as double;
    double weight = results[3] as double;
    
    // Parse calories, distance, heart rate from batch data
    double calories = 0;
    double distanceMeters = 0;
    int latestHr = 0;
    DateTime? latestHrTime;
    
    for (var p in data) {
      if (p.value is! NumericHealthValue) continue;
      final val = (p.value as NumericHealthValue).numericValue.toDouble();
      
      switch (p.type) {
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          calories += val;
          break;
        case HealthDataType.DISTANCE_DELTA:
          distanceMeters += val;
          break;
        case HealthDataType.HEART_RATE:
          if (latestHrTime == null || p.dateTo.isAfter(latestHrTime)) {
            latestHr = val.toInt();
            latestHrTime = p.dateTo;
          }
          break;
        default:
          break;
      }
    }
    
    return {
      'steps': steps,
      'calories_burned': calories.toInt(),
      'distance_km': double.parse((distanceMeters / 1000.0).toStringAsFixed(2)),
      'heart_rate_bpm': latestHr,
      'sleep_hours': double.parse(sleepHours.toStringAsFixed(1)),
      'active_minutes': 0,
      'weight': weight,
    };
  }
  
  Future<double> _getSleepData(DateTime now) async {
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
      return totalMinutes / 60.0;
    } catch (e) {
      return 0.0;
    }
  }
  
  Future<double> _getWeightData(DateTime now) async {
    final start = now.subtract(const Duration(days: 30));
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

  /// Invalidate the cache so next fetch is fresh
  void invalidateCache() {
    _todayCache = null;
    _todayCacheTime = null;
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

  // Keep individual methods for backward compatibility
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
    final data = await _getTodayData();
    double total = 0.0;
    for (var p in data) {
      if (p.type == HealthDataType.ACTIVE_ENERGY_BURNED && p.value is NumericHealthValue) {
        total += (p.value as NumericHealthValue).numericValue.toDouble();
      }
    }
    return total.toInt();
  }

  Future<double> getDistanceToday() async {
    final data = await _getTodayData();
    double totalMeters = 0.0;
    for (var p in data) {
      if (p.type == HealthDataType.DISTANCE_DELTA && p.value is NumericHealthValue) {
        totalMeters += (p.value as NumericHealthValue).numericValue.toDouble();
      }
    }
    return totalMeters / 1000.0;
  }

  Future<int> getLatestHeartRate() async {
    final data = await _getTodayData();
    DateTime? latestTime;
    int latestHr = 0;
    for (var p in data) {
      if (p.type == HealthDataType.HEART_RATE && p.value is NumericHealthValue) {
        if (latestTime == null || p.dateTo.isAfter(latestTime)) {
          latestHr = (p.value as NumericHealthValue).numericValue.toInt();
          latestTime = p.dateTo;
        }
      }
    }
    return latestHr;
  }

  Future<double> getSleepLastNight() async {
    return _getSleepData(DateTime.now());
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
    return _getWeightData(DateTime.now());
  }

  Future<int> getActiveMinutesToday() async {
    return 0;
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
        'distance': distance / 1000.0,
      };
    } catch (e) {
      return {'heart_rate': 0, 'calories': 0, 'distance': 0.0};
    }
  }
}
