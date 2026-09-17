import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class WaterReminderState {
  final double targetLiters;
  final bool isEnabled;
  final DateTime? nextReminderTime;
  final int intervalSeconds;

  WaterReminderState({
    this.targetLiters = 2.0,
    this.isEnabled = false,
    this.nextReminderTime,
    this.intervalSeconds = 3600,
  });

  WaterReminderState copyWith({
    double? targetLiters,
    bool? isEnabled,
    DateTime? nextReminderTime,
    int? intervalSeconds,
  }) {
    return WaterReminderState(
      targetLiters: targetLiters ?? this.targetLiters,
      isEnabled: isEnabled ?? this.isEnabled,
      nextReminderTime: nextReminderTime ?? this.nextReminderTime,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
    );
  }
}

class WaterReminderNotifier extends AsyncNotifier<WaterReminderState> {
  static const _keyTarget = 'water_target_liters';
  static const _keyEnabled = 'water_reminder_enabled';
  static const _keyNextReminder = 'water_next_reminder';
  static const _keyInterval = 'water_interval_seconds';

  @override
  Future<WaterReminderState> build() async {
    final prefs = await SharedPreferences.getInstance();
    
    final nextRemStr = prefs.getString(_keyNextReminder);
    DateTime? nextRem;
    final isEnabled = prefs.getBool(_keyEnabled) ?? false;
    final intervalSecs = prefs.getInt(_keyInterval) ?? 3600;
    
    if (nextRemStr != null) {
      nextRem = DateTime.parse(nextRemStr);
      if (isEnabled && nextRem.isBefore(DateTime.now())) {
        while(nextRem!.isBefore(DateTime.now())) {
           nextRem = nextRem.add(Duration(seconds: intervalSecs));
        }
        await prefs.setString(_keyNextReminder, nextRem.toIso8601String());
      }
    }

    return WaterReminderState(
      targetLiters: prefs.getDouble(_keyTarget) ?? 2.0,
      isEnabled: isEnabled,
      nextReminderTime: nextRem,
      intervalSeconds: intervalSecs,
    );
  }

  Future<void> setTarget(double target) async {
    if (target < 0.5) return;
    if (target > 5.0) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTarget, target);
    state = AsyncData(state.value!.copyWith(targetLiters: target));
  }

  Future<void> incrementTarget() async {
    if (state.value != null) {
      await setTarget(state.value!.targetLiters + 0.5);
    }
  }

  Future<void> decrementTarget() async {
    if (state.value != null) {
      await setTarget(state.value!.targetLiters - 0.5);
    }
  }

  Future<void> toggleReminder(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);

    DateTime? nextRem;
    final notifService = ref.read(notificationServiceProvider);
    final currentInterval = state.value?.intervalSeconds ?? 3600;
    
    if (enabled) {
      nextRem = DateTime.now().add(Duration(seconds: currentInterval));
      await prefs.setString(_keyNextReminder, nextRem.toIso8601String());
      await notifService.scheduleWaterReminder(intervalSeconds: currentInterval);
    } else {
      await prefs.remove(_keyNextReminder);
      await notifService.cancelWaterReminders();
    }

    state = AsyncData(state.value!.copyWith(
      isEnabled: enabled, 
      nextReminderTime: nextRem,
    ));
  }

  Future<void> setInterval(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyInterval, seconds);
    
    state = AsyncData(state.value!.copyWith(intervalSeconds: seconds));
    
    // If currently enabled, restart the schedule with the new interval
    if (state.value?.isEnabled == true) {
      await toggleReminder(true);
    }
  }
}

final waterReminderProvider = AsyncNotifierProvider<WaterReminderNotifier, WaterReminderState>(() {
  return WaterReminderNotifier();
});
