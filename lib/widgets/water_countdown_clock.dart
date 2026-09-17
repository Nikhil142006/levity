import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

class WaterCountdownClock extends StatefulWidget {
  final DateTime nextReminderTime;
  final Color color;

  const WaterCountdownClock({
    super.key,
    required this.nextReminderTime,
    required this.color,
  });

  @override
  State<WaterCountdownClock> createState() => _WaterCountdownClockState();
}

class _WaterCountdownClockState extends State<WaterCountdownClock> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimeLeft());
  }

  void _updateTimeLeft() {
    final now = DateTime.now();
    if (widget.nextReminderTime.isAfter(now)) {
      setState(() {
        _timeLeft = widget.nextReminderTime.difference(now);
      });
    } else {
      setState(() {
        _timeLeft = Duration.zero;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(_timeLeft.inHours);
    final minutes = twoDigits(_timeLeft.inMinutes.remainder(60));
    final seconds = twoDigits(_timeLeft.inSeconds.remainder(60));

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined, size: 48, color: widget.color.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            '$hours:$minutes:$seconds',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: widget.color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Until next reminder',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
