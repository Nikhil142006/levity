import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/metric_chart.dart';
import '../providers/routines_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/metric_chart.dart';
import '../providers/routines_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/manage_routines_sheet.dart';
import '../widgets/routine_progress.dart';
import '../widgets/routine_form.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/health_provider.dart';
import '../providers/user_preferences_provider.dart';

class HiddenWidgetsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];
  
  void hide(String widget) => state = [...state, widget];
  void restore() => state = [];
}

final hiddenWidgetsProvider = NotifierProvider<HiddenWidgetsNotifier, List<String>>(HiddenWidgetsNotifier.new);
class RoutineFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';
  void setFilter(String filter) => state = filter;
}

final routineFilterProvider = NotifierProvider<RoutineFilterNotifier, String>(RoutineFilterNotifier.new);

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> with SingleTickerProviderStateMixin {
  String? _activeWorkout;
  DateTime? _workoutStartTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  
  bool _isEditing = false;
  late AnimationController _wiggleController;
  
  int _liveHr = 0;
  int _liveCalories = 0;
  double _liveDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  }

  void _startWorkout(String type) {
    setState(() {
      _activeWorkout = type;
      _workoutStartTime = DateTime.now();
      _elapsed = Duration.zero;
      _liveHr = 0;
      _liveCalories = 0;
      _liveDistance = 0.0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_workoutStartTime!);
      });
      if (timer.tick % 5 == 0) {
        final metrics = await ref.read(healthServiceProvider).getWorkoutMetrics(_workoutStartTime!);
        if (mounted) {
          setState(() {
            _liveHr = metrics['heart_rate'] > 0 ? metrics['heart_rate'] : _liveHr;
            _liveCalories = metrics['calories'];
            _liveDistance = metrics['distance'];
          });
        }
      }
    });
  }

  void _endWorkout() {
    _timer?.cancel();
    setState(() {
      _activeWorkout = null;
      _workoutStartTime = null;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wiggleController.dispose();
    super.dispose();
  }

  void _showStartWorkoutDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Start Workout', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.directions_bike),
                title: const Text('Cycling'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  _startWorkout('Cycling');
                },
              ),
              ListTile(
                leading: const Icon(Icons.directions_run),
                title: const Text('Running'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  _startWorkout('Running');
                },
              ),
              ListTile(
                leading: const Icon(Icons.fitness_center),
                title: const Text('Strength Training'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  _startWorkout('Strength Training');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(routinesProvider);
          ref.invalidate(spo2HistoryProvider);
          ref.invalidate(latestWeightProvider);
          await Future.delayed(const Duration(milliseconds: 800));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverAppBar.large(
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            title: const Text('Activity & Health'),
            centerTitle: false,
            actions: [
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isEditing = !_isEditing;
                    if (_isEditing) {
                      _wiggleController.repeat(reverse: true);
                    } else {
                      _wiggleController.stop();
                      _wiggleController.reset();
                    }
                  });
                },
                child: Text(_isEditing ? 'Done' : 'Edit', style: TextStyle(color: colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                onSelected: (value) {
                  HapticFeedback.lightImpact();
                  ref.read(routineFilterProvider.notifier).setFilter(value);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'All', child: Text('All Routines')),
                  const PopupMenuItem(value: 'Completed', child: Text('Completed')),
                  const PopupMenuItem(value: 'Incomplete', child: Text('Incomplete')),
                ],
              ),
            ],
          ),
          
          if (_activeWorkout != null)
            SliverToBoxAdapter(
              child: _buildActiveWorkoutWidget(ref.watch(userPreferencesProvider).value?.useMetric ?? true),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(ref.watch(routineFilterProvider) == 'All' ? 'My Routines' : '${ref.watch(routineFilterProvider)} Routines', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildRoutinesSection(context, ref),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text('Health Metrics Hub', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                _buildExpandableCategory(
                  context, 'Steps', Icons.directions_walk, Colors.blue,
                  ['Daily', 'Weekly', 'Monthly'],
                  chartTitle: 'Steps',
                ),
                _buildExpandableCategory(
                  context, 'Workouts', Icons.fitness_center, Colors.orange,
                  ['Walking', 'Running', 'Cycling', 'Strength training', 'HIIT', 'Yoga'],
                ),
                _buildExpandableCategory(
                  context, 'Heart Rate', Icons.favorite, Colors.red,
                  ['Daily', 'Weekly', 'Monthly'],
                  chartTitle: 'Heart Rate',
                ),
                _buildExpandableCategory(
                  context, 'Calories', Icons.local_fire_department, Colors.orangeAccent,
                  ['Daily', 'Weekly', 'Monthly'],
                  chartTitle: 'Calories',
                ),
                _buildExpandableCategory(
                  context, 'Distance', Icons.map, Colors.purple,
                  ['Daily', 'Weekly', 'Monthly'],
                  chartTitle: 'Distance',
                ),
                _buildExpandableCategory(
                  context, 'Sleep', Icons.nights_stay, Colors.indigo,
                  ['Daily', 'Weekly', 'Monthly'],
                  chartTitle: 'Sleep',
                ),
                _buildSpO2Section(context),
                _buildBodyMetricsSection(context),
                
                if (ref.watch(hiddenWidgetsProvider).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: TextButton.icon(
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore Hidden Widgets'),
                      onPressed: () => ref.read(hiddenWidgetsProvider.notifier).restore(),
                    ),
                  ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      ),
    );
  }

  Widget _buildActiveWorkoutWidget(bool useMetric) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(_elapsed.inHours);
    final minutes = twoDigits(_elapsed.inMinutes.remainder(60));
    final seconds = twoDigits(_elapsed.inSeconds.remainder(60));
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.timer, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Active: $_activeWorkout',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                '$hours:$minutes:$seconds',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w300, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLiveMetric('${_liveHr > 0 ? _liveHr : "--"} bpm', 'Heart Rate'),
                  _buildLiveMetric('$_liveCalories kcal', 'Burned'),
                  if (_activeWorkout == 'Cycling' || _activeWorkout == 'Running' || _activeWorkout == 'Walking')
                    _buildLiveMetric('${(useMetric ? _liveDistance : _liveDistance * 0.621371).toStringAsFixed(2)} ${useMetric ? 'km' : 'mi'}', 'Distance'),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _endWorkout();
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('End Workout'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveMetric(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
      ],
    );
  }

  Widget _buildRoutinesSection(BuildContext context, WidgetRef ref) {
    final routinesState = ref.watch(routinesProvider);
    final filter = ref.watch(routineFilterProvider);
    
    return routinesState.when(
      data: (data) {
        var routines = (data == null || data['routines'] == null) ? [] : data['routines'] as List;
        
        if (filter == 'Completed') {
          routines = routines.where((r) => (r['completed_exercises'] as int) == (r['total_exercises'] as int) && (r['total_exercises'] as int) > 0).toList();
        } else if (filter == 'Incomplete') {
          routines = routines.where((r) => (r['completed_exercises'] as int) < (r['total_exercises'] as int) || (r['total_exercises'] as int) == 0).toList();
        }
        
        if (routines.isEmpty && !_isEditing) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('No routines assigned yet. Tap Edit to add one.'),
          );
        }
        
        return SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: routines.length + (_isEditing ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == routines.length) {
                return _buildAddRoutineCard(context, ref);
              }
              
              final routine = routines[index];
              final title = routine['title'] as String;
              final subtitle = routine['subtitle'] as String;
              final total = routine['total_exercises'] as int;
              final completed = routine['completed_exercises'] as int;
              final progress = total > 0 ? completed / total : 0.0;
              
              IconData iconData = Icons.fitness_center;
              if (routine['icon_name'] == 'self_improvement') iconData = Icons.self_improvement;
              if (routine['icon_name'] == 'nights_stay') iconData = Icons.nights_stay;

              String hexString = routine['color_hex'] as String;
              if (hexString.length == 8) hexString = '0x$hexString';
              Color color = Color(int.tryParse(hexString) ?? 0xFF2196F3);

              Widget card = Card(
                clipBehavior: Clip.hardEdge,
                color: Theme.of(context).colorScheme.surface,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(iconData, color: color),
                          ),
                          const Spacer(),
                          if (completed == total && !_isEditing)
                            const Icon(Icons.check_circle, color: Colors.green)
                        ],
                      ),
                      const Spacer(),
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: color.withOpacity(0.2),
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('$completed/$total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              );

              if (_isEditing) {
                card = AnimatedBuilder(
                  animation: _wiggleController,
                  builder: (context, child) {
                    final angle = (_wiggleController.value - 0.5) * 0.05;
                    return Transform.rotate(
                      angle: angle,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          child!,
                          Positioned(
                            top: -5,
                            right: -5,
                            child: GestureDetector(
                              onTap: () {
                                ref.read(routinesProvider.notifier).removeRoutine(routine['id']);
                                final api = ref.read(apiServiceProvider);
                                final user = ref.read(firebaseAuthProvider).currentUser;
                                api.deleteRoutine(user!.uid, routine['id']).catchError((_) {
                                  ref.invalidate(routinesProvider);
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: card,
                );
              }

              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () async {
                    if (_isEditing) {
                      final updated = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (_) => RoutineFormDialog(initialData: routine),
                      );
                      if (updated != null) {
                        ref.read(routinesProvider.notifier).updateRoutineData(routine['id'], updated);
                        final api = ref.read(apiServiceProvider);
                        final user = ref.read(firebaseAuthProvider).currentUser;
                        api.updateRoutine(user!.uid, routine['id'], updated).catchError((_) {
                          ref.invalidate(routinesProvider);
                        });
                      }
                    } else {
                      showDialog(
                        context: context,
                        builder: (_) => RoutineProgressDialog(routine: routine),
                      );
                    }
                  },
                  child: card,
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
      error: (e, s) => SizedBox(height: 180, child: Center(child: Text('Failed to load routines: $e'))),
    );
  }

  Widget _buildAddRoutineCard(BuildContext context, WidgetRef ref) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () async {
          final newRoutine = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (_) => const RoutineFormDialog(),
          );
          if (newRoutine != null) {
            final tempId = DateTime.now().millisecondsSinceEpoch.toString();
            newRoutine['id'] = tempId;
            ref.read(routinesProvider.notifier).addRoutine(newRoutine);
            
            final api = ref.read(apiServiceProvider);
            final user = ref.read(firebaseAuthProvider).currentUser;
            api.createRoutine(user!.uid, newRoutine).then((createdRoutine) {
              ref.read(routinesProvider.notifier).updateRoutineData(tempId, createdRoutine);
            }).catchError((_) {
              ref.invalidate(routinesProvider);
            });
          }
        },
        child: AnimatedBuilder(
          animation: _wiggleController,
          builder: (context, child) {
            final angle = (_wiggleController.value - 0.5) * 0.05;
            return Transform.rotate(angle: angle, child: child);
          },
          child: Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 2, style: BorderStyle.solid) // Wait, dashed is not standard, let's use solid
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, size: 40),
                  SizedBox(height: 8),
                  Text('Add Routine', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableCategory(BuildContext context, String title, IconData icon, Color color, List<String> items, {String? chartTitle}) {
    final hiddenWidgets = ref.watch(hiddenWidgetsProvider);
    if (hiddenWidgets.contains(title)) return const SizedBox.shrink();

    Widget card = Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          if (chartTitle != null)
            Container(
              height: 150,
              padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
              child: MetricChart(metricType: chartTitle, color: color),
            ),
          const SizedBox(height: 8),
          ...items.map((item) {
            bool isSelectedPeriod = false;
            if (chartTitle != null) {
               final periods = ref.watch(chartPeriodsProvider);
               final period = periods[chartTitle] ?? 'daily';
               if (item.toLowerCase() == period.toLowerCase()) isSelectedPeriod = true;
            }
            return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
                title: Text(item, style: TextStyle(fontSize: 14, fontWeight: isSelectedPeriod ? FontWeight.bold : FontWeight.normal)),
                trailing: isSelectedPeriod ? Icon(Icons.check, color: color, size: 20) : const Icon(Icons.chevron_right, size: 16),
                onTap: () {
                  if (title == 'Workouts') {
                    _startWorkout(item);
                  } else if (chartTitle != null) {
                    if (item.toLowerCase() == 'daily') ref.read(chartPeriodsProvider.notifier).setPeriod(chartTitle, 'daily');
                    else if (item.toLowerCase() == 'weekly') ref.read(chartPeriodsProvider.notifier).setPeriod(chartTitle, 'weekly');
                    else if (item.toLowerCase() == 'monthly') ref.read(chartPeriodsProvider.notifier).setPeriod(chartTitle, 'monthly');
                  }
                },
              );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );

    if (_isEditing) {
      return AnimatedBuilder(
        animation: _wiggleController,
        builder: (context, child) {
          final angle = (_wiggleController.value - 0.5) * 0.05;
          return Transform.rotate(
            angle: angle,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                child!,
                Positioned(
                  top: -5,
                  left: -5,
                  child: GestureDetector(
                    onTap: () {
                      ref.read(hiddenWidgetsProvider.notifier).hide(title);
                    },
                    child: Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: card,
      );
    }
    
    return card;
  }

  Widget _wrapWiggle(Widget child, String title) {
    return AnimatedBuilder(
      animation: _wiggleController,
      builder: (context, childWidget) {
        final angle = (_wiggleController.value - 0.5) * 0.05;
        return Transform.rotate(
          angle: angle,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              childWidget!,
              Positioned(
                top: -5,
                right: -5,
                child: GestureDetector(
                  onTap: () {
                    ref.read(hiddenWidgetsProvider.notifier).hide(title);
                  },
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildSpO2Section(BuildContext context) {
    final hiddenWidgets = ref.watch(hiddenWidgetsProvider);
    if (hiddenWidgets.contains('Blood Oxygen')) return const SizedBox.shrink();

    final spo2State = ref.watch(spo2HistoryProvider);

    Widget card = Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.air, color: Colors.cyan),
        ),
        title: const Text('Blood Oxygen', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          spo2State.when(
            data: (history) {
              if (history.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No SpO₂ data found in Health Connect.'),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('SpO₂', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: history.map((e) => DataRow(cells: [
                    DataCell(Text(e['date'])),
                    DataCell(Text(e['time'])),
                    DataCell(Text('${e['value']}%')),
                  ])).toList(),
                ),
              );
            },
            loading: () => const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
            error: (e, s) => Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e')),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );

    if (_isEditing) return _wrapWiggle(card, 'Blood Oxygen');
    return card;
  }

  Widget _buildBodyMetricsSection(BuildContext context) {
    final hiddenWidgets = ref.watch(hiddenWidgetsProvider);
    if (hiddenWidgets.contains('Body Metrics')) return const SizedBox.shrink();

    final weightState = ref.watch(latestWeightProvider);
    final profileState = ref.watch(userProfileProvider);
    final prefsState = ref.watch(userPreferencesProvider);

    Widget card = Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.monitor_weight, color: Colors.teal),
        ),
        title: const Text('Body Metrics', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          weightState.when(
            data: (healthWeight) {
              return profileState.when(
                data: (profile) {
                  return prefsState.when(
                    data: (prefs) {
                      if (profile == null) {
                         return const Padding(
                           padding: EdgeInsets.all(16.0),
                           child: Text('Please complete your profile to view body metrics.'),
                         );
                      }
                      
                      final heightCm = prefs.heightCm ?? profile['height_cm'] as double;
                      final heightM = heightCm / 100;
                      final age = prefs.age ?? profile['age'] as int;
                      final genderStr = prefs.gender ?? profile['gender'] as String;
                      
                      // Use local prefs weight if set, else Health Connect weight, else fallback to profile
                      final w = prefs.weightKg ?? (healthWeight > 0 ? healthWeight : (profile['weight_kg'] as double));
                  
                  final bmi = w / (heightM * heightM);
                  
                  int genderCode = genderStr.toLowerCase() == 'male' ? 1 : 0;
                  final bodyFatPct = (1.20 * bmi) + (0.23 * age) - (10.8 * genderCode) - 5.4;
                  final bodyFatClean = bodyFatPct < 2.0 ? 2.0 : bodyFatPct; // min body fat guard
                  
                  final leanMass = w * (1 - (bodyFatClean / 100));

                      return Column(
                        children: [
                          ListTile(title: const Text('Weight'), trailing: Text('${w.toStringAsFixed(1)} kg')),
                          ListTile(title: const Text('BMI'), trailing: Text(bmi.toStringAsFixed(1))),
                          ListTile(title: const Text('Body fat %'), trailing: Text('${bodyFatClean.toStringAsFixed(1)}%')),
                          ListTile(title: const Text('Lean mass'), trailing: Text('${leanMass.toStringAsFixed(1)} kg')),
                        ],
                      );
                    },
                    loading: () => const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
                    error: (e, s) => Padding(padding: const EdgeInsets.all(16), child: Text('Error loading preferences: $e')),
                  );
                },
                loading: () => const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
                error: (e, s) => Padding(padding: const EdgeInsets.all(16), child: Text('Error loading profile: $e')),
              );
            },
            loading: () => const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
            error: (e, s) => Padding(padding: const EdgeInsets.all(16), child: Text('Error loading weight: $e')),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );

    if (_isEditing) return _wrapWiggle(card, 'Body Metrics');
    return card;
  }
}
