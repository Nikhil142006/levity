import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import 'auth_provider.dart';

class AiInsightsNotifier extends AsyncNotifier<List<String>> {
  Timer? _pollingTimer;

  @override
  FutureOr<List<String>> build() async {
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchInsights();
    });
    
    return await _fetchInsights();
  }

  Future<List<String>> _fetchInsights() async {
    final aiService = ref.read(aiServiceProvider);
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return [];
    
    try {
      final insights = await aiService.getSuggestions(user.uid);
      state = AsyncValue.data(insights);
      return insights;
    } catch (e, stack) {
      if (!state.hasValue) {
         state = AsyncValue.error(e, stack);
      }
      return state.value ?? [];
    }
  }
}

final aiInsightsProvider = AsyncNotifierProvider<AiInsightsNotifier, List<String>>(() {
  return AiInsightsNotifier();
});
