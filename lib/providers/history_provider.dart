import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_provider.dart';
import 'auth_provider.dart';

class ChartPeriodsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {};
  
  void setPeriod(String metric, String period) {
    state = {...state, metric: period};
  }
}

final chartPeriodsProvider = NotifierProvider<ChartPeriodsNotifier, Map<String, String>>(ChartPeriodsNotifier.new);

final metricHistoryProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, metricType) async {
  final auth = ref.watch(firebaseAuthProvider);
  final apiService = ref.watch(apiServiceProvider);
  final periods = ref.watch(chartPeriodsProvider);
  final period = periods[metricType] ?? 'daily';
  
  final user = auth.currentUser;
  if (user == null) return null;
  
  try {
    final history = await apiService.getMetricHistory(user.uid, metricType, period);
    return history;
  } catch (e) {
    if (e.toString().contains('404')) {
      return null;
    }
    rethrow;
  }
});
