import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ApiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double _calculateBmi(double weightKg, double heightCm) {
    double heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  double _calculateBmr(double weightKg, double heightCm, int age, String gender) {
    if (gender.toLowerCase() == 'male') {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    } else {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    }
  }

  double _calculateTdee(double bmr, String lifestyle) {
    final multipliers = {
      "sedentary": 1.2,
      "lightly active": 1.375,
      "moderately active": 1.55,
      "very active": 1.725,
      "extra active": 1.9
    };
    return bmr * (multipliers[lifestyle.toLowerCase()] ?? 1.2);
  }

  Future<Map<String, dynamic>> createProfile(Map<String, dynamic> userData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not logged in");

      userData['id'] = user.uid;
      userData['created_at'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(user.uid).set(userData, SetOptions(merge: true));
      return userData;
    } catch (e) {
      throw Exception('Failed to create profile: $e');
    }
  }

  Future<Map<String, dynamic>> getHealthProfile(String firebaseUid) async {
    try {
      final doc = await _firestore.collection('users').doc(firebaseUid).get();
      if (!doc.exists) throw Exception("User not found");

      final userData = doc.data()!;
      double weightKg = (userData['weight_kg'] ?? 0).toDouble();
      double heightCm = (userData['height_cm'] ?? 0).toDouble();
      int age = userData['age'] ?? 0;
      String gender = userData['gender'] ?? 'Other';
      String lifestyle = userData['lifestyle'] ?? 'sedentary';

      double bmi = _calculateBmi(weightKg, heightCm);
      double bmr = _calculateBmr(weightKg, heightCm, age, gender);
      double tdee = _calculateTdee(bmr, lifestyle);

      String fitnessCategory = "Normal";
      if (bmi < 18.5) {
        fitnessCategory = "Underweight";
      } else if (bmi >= 25 && bmi < 30) {
        fitnessCategory = "Overweight";
      } else if (bmi >= 30) {
        fitnessCategory = "Obese";
      }

      return {
        "bmi": bmi,
        "bmr": bmr,
        "tdee": tdee,
        "fitness_category": fitnessCategory,
        "estimated_body_fat_pct": 0.0,
        "height_cm": heightCm,
        "weight_kg": weightKg,
        "age": age,
        "gender": gender,
      };
    } catch (e) {
      if (e.toString().contains('User not found')) {
        throw Exception('404');
      }
      throw Exception('Failed to load health profile: $e');
    }
  }

  Future<Map<String, dynamic>> getDashboardMetrics(String firebaseUid) async {
    try {
      String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final results = await Future.wait([
        _firestore.collection('users').doc(firebaseUid).get(),
        _firestore
            .collection('users')
            .doc(firebaseUid)
            .collection('daily_metrics')
            .doc(todayStr)
            .get(),
      ]);

      final userDoc = results[0];
      final metricsDoc = results[1];

      if (!userDoc.exists) throw Exception("User not found");

      final userData = userDoc.data()!;
      double weightKg = (userData['weight_kg'] ?? 0).toDouble();
      double heightCm = (userData['height_cm'] ?? 0).toDouble();
      double bmi = _calculateBmi(weightKg, heightCm);

      String aiInsight = "You're doing great! Keep up the good work.";
      String lifestyle = userData['lifestyle'] ?? 'sedentary';
      int age = userData['age'] ?? 0;

      if (lifestyle.toLowerCase() == "sedentary") {
        aiInsight = "Since your lifestyle is mostly sedentary, let's aim for a short 15-minute walk today to boost your energy!";
      } else if (lifestyle.toLowerCase() == "very active") {
        aiInsight = "You're very active! Make sure to stay hydrated and get enough protein for recovery.";
      } else if (bmi > 25) {
        aiInsight = "A slight calorie deficit combined with daily walks can help you reach your weight goals steadily.";
      } else if (age > 50) {
        aiInsight = "Focusing on strength training and flexibility will help maintain muscle mass and joint health.";
      } else if (bmi < 18.5) {
        aiInsight = "Consider adding a nutrient-dense protein shake to help build healthy lean mass.";
      }

      Map<String, dynamic> metricsData = {};
      if (metricsDoc.exists) {
        metricsData = metricsDoc.data()!;
      }

      return {
        "daily_score": metricsData["daily_score"] ?? 0,
        "calories_burned": metricsData["calories_burned"] ?? 0,
        "calories_goal": metricsData["calories_goal"] ?? 2400,
        "steps": metricsData["steps"] ?? 0,
        "steps_goal": metricsData["steps_goal"] ?? 10000,
        "distance_km": metricsData["distance_km"]?.toDouble() ?? 0.0,
        "active_minutes": metricsData["active_minutes"] ?? 0,
        "heart_rate_bpm": metricsData["heart_rate_bpm"] ?? 0,
        "sleep_hours": metricsData["sleep_hours"]?.toDouble() ?? 0.0,
        "water_liters": metricsData["water_liters"]?.toDouble() ?? 0.0,
        "streak_days": metricsData["streak_days"] ?? 0,
        "ai_insight": aiInsight
      };
    } catch (e) {
      if (e.toString().contains('User not found')) {
        throw Exception('404');
      }
      throw Exception('Failed to load dashboard metrics: $e');
    }
  }

  Future<Map<String, dynamic>> getMetricHistory(String firebaseUid, String metricType, String period) async {
    try {
      final unitMap = {
        "calories": ["calories_burned", "kcal"],
        "steps": ["steps", "steps"],
        "distance": ["distance_km", "km"],
        "active": ["active_minutes", "min"],
        "heart rate": ["heart_rate_bpm", "bpm"],
        "sleep": ["sleep_hours", "h"],
        "water": ["water_liters", "L"],
        "streak": ["streak_days", "Days"],
      };

      String dbField = unitMap[metricType.toLowerCase()]?[0] ?? metricType.toLowerCase();
      String unit = unitMap[metricType.toLowerCase()]?[1] ?? "";

      int daysToFetch = 7;
      int points = 7;
      int groupSize = 1;

      if (period.toLowerCase() == 'weekly') {
        daysToFetch = 28;
        points = 4;
        groupSize = 7;
      } else if (period.toLowerCase() == 'monthly') {
        daysToFetch = 180;
        points = 6;
        groupSize = 30;
      }

      final today = DateTime.now();
      final startDate = today.subtract(Duration(days: daysToFetch - 1));
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);

      final snapshot = await _firestore
          .collection('users')
          .doc(firebaseUid)
          .collection('daily_metrics')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateStr)
          .get();

      Map<String, double> dataMap = {};
      for (var doc in snapshot.docs) {
        dataMap[doc.id] = (doc.data()[dbField] ?? 0.0).toDouble();
      }

      List<Map<String, dynamic>> history = [];
      for (int p = points - 1; p >= 0; p--) {
        double groupVal = 0.0;
        int startOffset = p * groupSize;
        for (int j = 0; j < groupSize; j++) {
          final dateStr = DateFormat('yyyy-MM-dd').format(today.subtract(Duration(days: startOffset + j)));
          groupVal += dataMap[dateStr] ?? 0.0;
        }
        groupVal = groupVal / groupSize;

        String label = "";
        if (period.toLowerCase() == 'daily') {
          label = DateFormat('yyyy-MM-dd').format(today.subtract(Duration(days: p)));
        } else if (period.toLowerCase() == 'weekly') {
          label = "Week ${points - p}";
        } else {
          label = "Month ${points - p}";
        }

        history.add({
          "date": label,
          "value": double.parse(groupVal.toStringAsFixed(1))
        });
      }

      return {
        "metric_type": metricType,
        "unit": unit,
        "history": history
      };
    } catch (e) {
      throw Exception('Failed to load metric history: $e');
    }
  }

  Future<Map<String, dynamic>> getRoutines(String firebaseUid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(firebaseUid).collection('routines').get();
      List<Map<String, dynamic>> routines = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        data['id'] = doc.id;
        routines.add(data);
      }
      return {"routines": routines};
    } catch (e) {
      throw Exception('Failed to load routines: $e');
    }
  }

  Future<Map<String, dynamic>> createRoutine(String firebaseUid, Map<String, dynamic> routineData) async {
    try {
      final docRef = _firestore.collection('users').doc(firebaseUid).collection('routines').doc();
      await docRef.set(routineData);
      routineData['id'] = docRef.id;
      return routineData;
    } catch (e) {
      throw Exception('Failed to create routine: $e');
    }
  }

  Future<Map<String, dynamic>> updateRoutine(String firebaseUid, String routineId, Map<String, dynamic> routineData) async {
    try {
      final docRef = _firestore.collection('users').doc(firebaseUid).collection('routines').doc(routineId);
      await docRef.update(routineData);
      final doc = await docRef.get();
      var data = doc.data()!;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      throw Exception('Failed to update routine: $e');
    }
  }

  Future<void> deleteRoutine(String firebaseUid, String routineId) async {
    try {
      await _firestore.collection('users').doc(firebaseUid).collection('routines').doc(routineId).delete();
    } catch (e) {
      throw Exception('Failed to delete routine: $e');
    }
  }

  Future<void> syncMetrics(String firebaseUid, Map<String, dynamic> metrics) async {
    try {
      final payload = {
        if (metrics.containsKey('steps')) 'steps': metrics['steps'],
        if (metrics.containsKey('calories_burned')) 'calories_burned': metrics['calories_burned'],
        if (metrics.containsKey('distance_km')) 'distance_km': metrics['distance_km'],
        if (metrics.containsKey('heart_rate_bpm')) 'heart_rate_bpm': metrics['heart_rate_bpm'],
        if (metrics.containsKey('sleep_hours')) 'sleep_hours': metrics['sleep_hours'],
        if (metrics.containsKey('active_minutes')) 'active_minutes': metrics['active_minutes'],
        'last_synced': FieldValue.serverTimestamp(),
      };
      
      if (payload.isNotEmpty) {
        String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await _firestore
            .collection('users')
            .doc(firebaseUid)
            .collection('daily_metrics')
            .doc(todayStr)
            .set(payload, SetOptions(merge: true));
      }
    } catch (e) {
      print('Failed to sync metrics: $e');
    }
  }

  Future<void> setWaterLiters(String firebaseUid, double newAmount) async {
    try {
      String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await _firestore
          .collection('users')
          .doc(firebaseUid)
          .collection('daily_metrics')
          .doc(todayStr)
          .set({'water_liters': newAmount}, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to set water: $e');
    }
  }
}
