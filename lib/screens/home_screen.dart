import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/water_reminder_provider.dart';
import '../widgets/metric_chart.dart';
import '../widgets/water_countdown_clock.dart';

class DashboardViewModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final dashboardViewModeProvider = NotifierProvider<DashboardViewModeNotifier, bool>(DashboardViewModeNotifier.new);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProfileProvider);
    final user = ref.watch(authStateProvider).value;
    final dashboardState = ref.watch(dashboardMetricsProvider);
    final prefsState = ref.watch(userPreferencesProvider);
    final useMetric = prefsState.value?.useMetric ?? true;
    final isListView = ref.watch(dashboardViewModeProvider);
    
    // We get colors from the new Theme
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(isListView ? Icons.grid_view : Icons.view_list),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(dashboardViewModeProvider.notifier).toggle();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: userState.when(
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Please complete onboarding to generate your profile.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/onboarding'),
                    child: const Text('Complete Onboarding'),
                  ),
                ],
              ),
            );
          }

          return dashboardState.when(
            data: (metrics) {
              if (metrics == null) return const Center(child: Text('Failed to load metrics.'));

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(dashboardMetricsProvider);
                  ref.invalidate(userProfileProvider);
                  await Future.delayed(const Duration(milliseconds: 800));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting & Daily Score
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${user?.displayName ?? 'Healthy Hero'}!',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            Text(
                              'Your Daily Score',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.secondary, width: 2),
                          ),
                          child: Text(
                            '${metrics['daily_score']}',
                            style: textTheme.headlineMedium?.copyWith(
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // AI Insights Card
                    const AiInsightCard(),
                    const SizedBox(height: 24),

                    Text(
                      'Today\'s Metrics',
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Metrics Grid
                    Builder(
                      builder: (context) {
                        final cards = [
                          _buildMetricCard(context, 'Calories', '${metrics['calories_burned']}', 'kcal', Icons.local_fire_department, Colors.orange, isList: isListView),
                          _buildMetricCard(context, 'Steps', '${metrics['steps']}', 'steps', Icons.directions_walk, colorScheme.primary, isList: isListView),
                          _buildMetricCard(context, 'Distance', useMetric ? '${metrics['distance_km']}' : '${((metrics['distance_km'] ?? 0) * 0.621371).toStringAsFixed(2)}', useMetric ? 'km' : 'mi', Icons.map, Colors.purple, isList: isListView),
                          _buildMetricCard(context, 'Active', '${metrics['active_minutes']}', 'min', Icons.timer, colorScheme.secondary, isList: isListView),
                          _buildMetricCard(context, 'Heart Rate', '${metrics['heart_rate_bpm']}', 'bpm', Icons.favorite, Colors.red, isList: isListView),
                          _buildMetricCard(context, 'Sleep', '${metrics['sleep_hours']}', 'h', Icons.bedtime, Colors.indigo, isList: isListView),
                          _buildMetricCard(context, 'Water', useMetric ? '${metrics['water_liters']}' : '${((metrics['water_liters'] ?? 0) * 33.814).toStringAsFixed(0)}', useMetric ? 'L' : 'oz', Icons.water_drop, Colors.blue, isList: isListView),
                          _buildMetricCard(context, 'Streak', '${metrics['streak_days']}', 'Days', Icons.whatshot, Colors.deepOrange, isList: isListView),
                        ];

                        if (isListView) {
                          return Column(
                            children: cards.expand((c) => [c, const SizedBox(height: 12)]).toList()..removeLast(),
                          );
                        } else {
                          return GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: cards,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Dashboard Error: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showEditWaterDialog(BuildContext context, WidgetRef ref) {
    final state = ref.read(dashboardMetricsProvider).value;
    final useMetric = ref.read(userPreferencesProvider).value?.useMetric ?? true;
    final currentLiters = state?['water_liters'] ?? 0.0;
    final currentValue = useMetric ? currentLiters : (currentLiters * 33.814);
    
    final TextEditingController controller = TextEditingController(text: currentValue.toStringAsFixed(useMetric ? 1 : 0));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Water'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'e.g. \${useMetric ? "2.5" : "64"}',
              suffixText: useMetric ? 'Liters' : 'oz',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(controller.text);
                if (amount != null && amount >= 0) {
                  final litersToSave = useMetric ? amount : (amount / 33.814);
                  final user = ref.read(firebaseAuthProvider).currentUser;
                  if (user != null) {
                    try {
                      await ref.read(apiServiceProvider).setWaterLiters(user.uid, litersToSave);
                      ref.invalidate(dashboardMetricsProvider);
                    } catch (e) {
                      debugPrint('Error updating water: \$e');
                    }
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, String unit, IconData icon, Color color, {bool isList = false}) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => _showMetricDetailSheet(context, title, value, unit, icon, color),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isList ? Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        unit,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ) : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        unit,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryMetric(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => _showMetricDetailSheet(context, title, value, '', icon, color),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMetricDetailSheet(BuildContext context, String title, String value, String unit, IconData icon, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Consumer(
                  builder: (context, ref, child) {
                    final state = ref.watch(dashboardMetricsProvider).value;
                    final useMetric = ref.watch(userPreferencesProvider).value?.useMetric ?? true;
                    
                    String displayValue = value;
                    if (state != null) {
                      if (title == 'Water') {
                        displayValue = useMetric ? (state['water_liters'] ?? 0).toString() : ((state['water_liters'] ?? 0) * 33.814).toStringAsFixed(0);
                      } else if (title == 'Calories') {
                        displayValue = (state['calories_burned'] ?? 0).toString();
                      } else if (title == 'Steps') {
                        displayValue = (state['steps'] ?? 0).toString();
                      } else if (title == 'Distance') {
                        displayValue = useMetric ? (state['distance_km'] ?? 0).toString() : ((state['distance_km'] ?? 0) * 0.621371).toStringAsFixed(2);
                      } else if (title == 'Active') {
                        displayValue = (state['active_minutes'] ?? 0).toString();
                      } else if (title == 'Heart Rate') {
                        displayValue = (state['heart_rate_bpm'] ?? 0).toString();
                      } else if (title == 'Sleep') {
                        displayValue = (state['sleep_hours'] ?? 0).toString();
                      } else if (title == 'Streak') {
                        displayValue = (state['streak_days'] ?? 0).toString();
                      }
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          displayValue,
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            unit,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ),
                        if (title == 'Water')
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                            child: IconButton(
                              icon: const Icon(Icons.edit),
                              color: color,
                              onPressed: () => _showEditWaterDialog(context, ref),
                              tooltip: 'Edit Water',
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 40),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Consumer(
                      builder: (context, ref, child) {
                        if (title == 'Water') {
                          final waterState = ref.watch(waterReminderProvider).value;
                          if (waterState != null && waterState.isEnabled && waterState.nextReminderTime != null) {
                            return WaterCountdownClock(
                              nextReminderTime: waterState.nextReminderTime!,
                              color: color,
                            );
                          } else {
                            return Center(
                              child: Text(
                                'Reminders Disabled',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            );
                          }
                        }
                        return MetricChart(
                          metricType: title,
                          color: color,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (title == 'Water') _WaterReminderSettings(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/activity');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color.withOpacity(0.1),
                      foregroundColor: color,
                      elevation: 0,
                    ),
                    child: const Text('View Full History', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 64),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AiInsightCard extends ConsumerStatefulWidget {
  const AiInsightCard({super.key});

  @override
  ConsumerState<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends ConsumerState<AiInsightCard> {
  int _currentIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    final aiInsightsState = ref.watch(aiInsightsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          context.go('/coach');
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: colorScheme.secondary, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Coach Insight',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    aiInsightsState.when(
                      data: (insights) {
                        if (insights.isEmpty) {
                          return Text(
                            'Tap here to chat with your AI Coach!',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          );
                        }
                        
                        // We use a simple Future-based delay to cycle them every 5 seconds if there are multiple.
                        // We can use an AnimatedSwitcher for a smooth fade.
                        Future.delayed(const Duration(seconds: 5), () {
                          if (mounted) {
                            setState(() {
                              _currentIndex = ((_currentIndex + 1) % insights.length).toInt();
                            });
                          }
                        });
                        
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            insights[_currentIndex],
                            key: ValueKey<int>(_currentIndex),
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        );
                      },
                      loading: () => Text(
                        'Generating dynamic insights...',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      error: (err, _) => Text(
                        'Tap here to ask your Coach a question!',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaterReminderSettings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(waterReminderProvider);
    return stateAsync.when(
      data: (state) {
        final notifier = ref.read(waterReminderProvider.notifier);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 16),
            Text('Water Intake Settings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Daily Target', style: TextStyle(fontSize: 16)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        notifier.decrementTarget();
                      },
                    ),
                    Text('${state.targetLiters.toStringAsFixed(1)} L', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        notifier.incrementTarget();
                      },
                    ),
                  ],
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Reminders'),
              subtitle: Text(
                'Get notified every ${state.intervalSeconds >= 3600 ? '${state.intervalSeconds ~/ 3600}h ' : ''}${((state.intervalSeconds % 3600) ~/ 60)}m ${state.intervalSeconds % 60}s',
              ),
              value: state.isEnabled,
              onChanged: (val) {
                HapticFeedback.mediumImpact();
                notifier.toggleReminder(val);
              },
            ),
            if (state.isEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder Interval'),
                trailing: TextButton(
                  onPressed: () {
                    int tempSeconds = state.intervalSeconds;
                    showModalBottomSheet(
                      context: context,
                      builder: (BuildContext builder) {
                        return Container(
                          height: 300,
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      if (tempSeconds > 0 && tempSeconds != state.intervalSeconds) {
                                        HapticFeedback.mediumImpact();
                                        notifier.setInterval(tempSeconds);
                                      }
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Done'),
                                  ),
                                ],
                              ),
                              Expanded(
                                child: CupertinoTimerPicker(
                                  mode: CupertinoTimerPickerMode.hms,
                                  initialTimerDuration: Duration(seconds: state.intervalSeconds),
                                  onTimerDurationChanged: (Duration newDuration) {
                                    if (newDuration.inSeconds > 0) {
                                      tempSeconds = newDuration.inSeconds;
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: Text(
                    '${state.intervalSeconds >= 3600 ? '${state.intervalSeconds ~/ 3600}h ' : ''}${((state.intervalSeconds % 3600) ~/ 60)}m ${state.intervalSeconds % 60}s',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const SizedBox(),
    );
  }
}
