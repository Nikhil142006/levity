import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_provider.dart';

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

  Future<void> createProfile(Map<String, dynamic> profileData) async {
    state = const AsyncValue.loading();
    try {
      final auth = ref.read(firebaseAuthProvider);
      final apiService = ref.read(apiServiceProvider);
      
      final user = auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      profileData['firebase_uid'] = user.uid;
      profileData['email'] = user.email ?? '';
      
      await apiService.createProfile(profileData);
      
      final newProfile = await _loadUserProfile();
      state = AsyncValue.data(newProfile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final userProfileProvider = AsyncNotifierProvider<UserNotifier, Map<String, dynamic>?>(() {
  return UserNotifier();
});
