import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

class UserNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async {
    return _loadUserProfile();
  }

  Future<Map<String, dynamic>?> _loadUserProfile() async {
    final auth = ref.read(firebaseAuthProvider);
    final apiService = ref.read(apiServiceProvider);
    
    final user = auth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final profile = await apiService.getHealthProfile(user.uid);
      return profile;
    } catch (e) {
      if (e.toString().contains('404')) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> updateProfileField(Map<String, dynamic> fieldData) async {
    // Optimistically update state with the new field values merged into old profile
    final currentProfile = state.value;
    if (currentProfile != null) {
      final updated = Map<String, dynamic>.from(currentProfile);
      fieldData.forEach((key, value) {
        updated[key] = value;
      });
      // Recalculate BMI/BMR locally for instant feedback
      final weightKg = (updated['weight_kg'] as num?)?.toDouble() ?? 0;
      final heightCm = (updated['height_cm'] as num?)?.toDouble() ?? 0;
      final age = (updated['age'] as int?) ?? 0;
      final gender = (updated['gender'] as String?) ?? 'Other';
      if (heightCm > 0 && weightKg > 0) {
        final heightM = heightCm / 100;
        final bmi = weightKg / (heightM * heightM);
        double bmr;
        if (gender.toLowerCase() == 'male') {
          bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
        } else {
          bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
        }
        updated['bmi'] = bmi;
        updated['bmr'] = bmr;
        String fitnessCategory = "Normal";
        if (bmi < 18.5) {
          fitnessCategory = "Underweight";
        } else if (bmi >= 25 && bmi < 30) {
          fitnessCategory = "Overweight";
        } else if (bmi >= 30) {
          fitnessCategory = "Obese";
        }
        updated['fitness_category'] = fitnessCategory;
      }
      state = AsyncValue.data(updated);
    }

    // Persist to Firestore in background
    try {
      final auth = ref.read(firebaseAuthProvider);
      final apiService = ref.read(apiServiceProvider);
      
      final user = auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      fieldData['firebase_uid'] = user.uid;
      fieldData['email'] = user.email ?? '';
      
      await apiService.createProfile(fieldData);
      
      // Reload full profile from Firestore to ensure consistency
      final newProfile = await _loadUserProfile();
      state = AsyncValue.data(newProfile);
      
      // Also refresh dashboard metrics
      ref.invalidate(dashboardMetricsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createProfile(Map<String, dynamic> profileData) async {
    return updateProfileField(profileData);
  }
}

final userProfileProvider = AsyncNotifierProvider<UserNotifier, Map<String, dynamic>?>(() {
  return UserNotifier();
});
