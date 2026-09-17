import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_provider.dart';
import 'auth_provider.dart';

class RoutinesNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    final auth = ref.watch(firebaseAuthProvider);
    final apiService = ref.watch(apiServiceProvider);
    
    final user = auth.currentUser;
    if (user == null) return <String, dynamic>{'routines': []};
    
    try {
      final response = await apiService.getRoutines(user.uid);
      return response;
    } catch (e) {
      print('Failed to load routines: $e');
      return <String, dynamic>{'routines': []};
    }
  }

  void removeRoutine(String routineId) {
    if (state.hasValue) {
      final currentData = state.value!;
      final currentRoutines = List.from(currentData['routines'] ?? []);
      currentRoutines.removeWhere((r) => r['id'] == routineId);
      state = AsyncData(<String, dynamic>{'routines': currentRoutines});
    }
  }

  void addRoutine(Map<String, dynamic> routine) {
    if (state.hasValue) {
      final currentData = state.value!;
      final currentRoutines = List.from(currentData['routines'] ?? []);
      currentRoutines.add(routine);
      state = AsyncData(<String, dynamic>{'routines': currentRoutines});
    }
  }

  void updateRoutineData(String routineId, Map<String, dynamic> updated) {
    if (state.hasValue) {
      final currentData = state.value!;
      final currentRoutines = List.from(currentData['routines'] ?? []);
      final index = currentRoutines.indexWhere((r) => r['id'] == routineId);
      if (index != -1) {
        currentRoutines[index] = <String, dynamic>{...currentRoutines[index], ...updated};
        state = AsyncData(<String, dynamic>{'routines': currentRoutines});
      }
    }
  }
}

final routinesProvider = AsyncNotifierProvider<RoutinesNotifier, Map<String, dynamic>>(RoutinesNotifier.new);
