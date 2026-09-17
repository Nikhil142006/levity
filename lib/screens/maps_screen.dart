import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/location_provider.dart';
import '../providers/notification_service.dart';
import '../providers/user_preferences_provider.dart';

class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({super.key});

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _distanceController = TextEditingController(text: '5.0');
  String _selectedActivity = 'Walking';

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        _mapController.move(LatLng(position.latitude, position.longitude), 16.0);
      }
    } catch (e) {
      // Ignore if permission denied, it will stay at default
    }
  }

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(locationSessionProvider);
    final useMetric = ref.watch(userPreferencesProvider).value?.useMetric ?? true;
    final colorScheme = Theme.of(context).colorScheme;

    // Listen for turnaround notification
    ref.listen<SessionState>(locationSessionProvider, (previous, next) {
      if (previous != null && !previous.turnaroundNotified && next.turnaroundNotified) {
        ref.read(notificationServiceProvider).showHalfwayNotification();
      }
      
      // Update camera if tracking and moving
      if (next.isTracking && next.path.isNotEmpty) {
        _mapController.move(next.path.last, _mapController.camera.zoom);
      }
    });

    // Default target for map if no location yet
    final initialTarget = session.path.isNotEmpty 
        ? session.path.last 
        : const LatLng(37.422, -122.084); // Default to GooglePlex if no location

    return Scaffold(
      appBar: AppBar(title: const Text('Smart Routes')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialTarget,
                initialZoom: 16.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.antigravityhealth.app.frontend',
                  retinaMode: true,
                  keepBuffer: 5,
                  maxNativeZoom: 19,
                ),
                PolylineLayer(
                  polylines: [
                    if (session.path.isNotEmpty)
                      Polyline(
                        points: session.path,
                        color: colorScheme.primary,
                        strokeWidth: 5.0,
                      ),
                  ],
                ),
                if (session.path.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      // User's current live location
                      Marker(
                        point: session.path.last,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.circle, color: Colors.blue, size: 20),
                          ),
                        ),
                      ),
                      // Turnaround Point Flag
                      if (session.turnaroundLocation != null)
                        Marker(
                          point: session.turnaroundLocation!,
                          width: 40,
                          height: 40,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.flag, color: Colors.red, size: 36),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          Flexible(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: SafeArea(
                top: false,
                child: session.isTracking ? _buildLiveDashboard(session, colorScheme, useMetric) : _buildConfigPanel(colorScheme, useMetric),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigPanel(ColorScheme colorScheme, bool useMetric) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Start a Session', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Walking', icon: Icon(Icons.directions_walk)),
                      ButtonSegment(value: 'Running', icon: Icon(Icons.directions_run)),
                      ButtonSegment(value: 'Cycling', icon: Icon(Icons.directions_bike)),
                    ],
                    selected: {_selectedActivity},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedActivity = newSelection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _distanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Goal Distance (${useMetric ? 'km' : 'mi'})',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    double goal = double.tryParse(_distanceController.text) ?? 5.0;
                    if (!useMetric) goal = goal / 0.621371; // Convert entered miles back to km for the backend
                    try {
                      await ref.read(locationSessionProvider.notifier).startSession(_selectedActivity, goal);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('START'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveDashboard(SessionState session, ColorScheme colorScheme, bool useMetric) {
    final progress = session.goalDistanceKm > 0 ? (session.currentDistanceKm / session.goalDistanceKm).clamp(0.0, 1.0) : 0.0;
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.activityType, style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${(useMetric ? session.currentDistanceKm : session.currentDistanceKm * 0.621371).toStringAsFixed(2)} ${useMetric ? 'km' : 'mi'}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Goal', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    '${(useMetric ? session.goalDistanceKm : session.goalDistanceKm * 0.621371).toStringAsFixed(2)} ${useMetric ? 'km' : 'mi'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: session.turnaroundNotified ? colorScheme.secondary : colorScheme.primary,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(locationSessionProvider.notifier).stopSession();
            },
            icon: const Icon(Icons.stop),
            label: const Text('STOP SESSION'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
