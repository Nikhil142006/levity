import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class NotificationService {
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(settings: initSettings);

    // Request permissions
    final androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _initialized = true;
  }

  Future<void> scheduleWaterReminder({required int intervalSeconds}) async {
    await init();
    
    // Cancel existing
    await cancelWaterReminders();

    const androidDetails = AndroidNotificationDetails(
      'water_channel_v3',
      'Water Reminders',
      channelDescription: 'Reminds you to drink water',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
    );
    const details = NotificationDetails(android: androidDetails);

    final now = tz.TZDateTime.now(tz.local);
    
    // Show an immediate confirmation notification
    await flutterLocalNotificationsPlugin.show(
      id: -1,
      title: 'Timer Set! 💧',
      body: 'Reminders scheduled successfully.',
      notificationDetails: details,
    );
    
    int numberOfNotifications = (24 * 60 * 60) ~/ intervalSeconds;
    if (numberOfNotifications > 50) {
      numberOfNotifications = 50; // Cap to 50 to avoid OS limits on scheduled notifications
    }
    
    for (int i = 0; i < numberOfNotifications; i++) {
      final scheduledDate = now.add(Duration(seconds: intervalSeconds * (i + 1)));
      
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: i,
        title: 'Time to Hydrate! 💧',
        body: 'Grab a glass of water to keep your daily streak going.',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelWaterReminders() async {
    for (int i = 0; i < 50; i++) {
      await flutterLocalNotificationsPlugin.cancel(id: i);
    }
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> showHalfwayNotification() async {
    await init();
    
    const androidDetails = AndroidNotificationDetails(
      'activity_channel',
      'Activity Alerts',
      channelDescription: 'Alerts during your workout',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      id: 1,
      title: 'Halfway There! 🎯',
      body: 'You have reached half your goal distance! Time to turn back.',
      notificationDetails: details,
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
