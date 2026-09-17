import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../providers/user_provider.dart';
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isEditingWeight = false;
  bool _isEditingHeight = false;
  bool _isEditingAge = false;
  bool _isEditingName = false;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _saveWeight(WidgetRef ref, bool useMetric) {
    if (_weightController.text.isNotEmpty) {
      final val = double.tryParse(_weightController.text);
      if (val != null) {
        ref.read(userProfileProvider.notifier).createProfile({
          'weight_kg': useMetric ? val : val / 2.20462,
        });
      }
    }
    setState(() => _isEditingWeight = false);
  }

  void _saveHeight(WidgetRef ref) {
    if (_heightController.text.isNotEmpty) {
      final val = double.tryParse(_heightController.text);
      if (val != null) {
        ref.read(userProfileProvider.notifier).createProfile({
          'height_cm': val,
        });
      }
    }
    setState(() => _isEditingHeight = false);
  }

  void _saveAge(WidgetRef ref) {
    if (_ageController.text.isNotEmpty) {
      final val = int.tryParse(_ageController.text);
      if (val != null) {
        ref.read(userProfileProvider.notifier).createProfile({
          'age': val,
        });
      }
    }
    setState(() => _isEditingAge = false);
  }

  Future<void> _saveName(User? user) async {
    if (user != null && _nameController.text.isNotEmpty) {
      await user.updateDisplayName(_nameController.text);
      await user.reload();
      ref.invalidate(authStateProvider);
    }
    setState(() => _isEditingName = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final prefsState = ref.watch(userPreferencesProvider);
    final profileState = ref.watch(userProfileProvider);
    final user = authState.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: prefsState.when(
        data: (prefs) {
          return profileState.when(
            data: (profile) => _buildBody(user, prefs, profile, ref),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildBody(user, UserPreferencesState prefs, Map<String, dynamic>? profile, WidgetRef ref) {
    final notifier = ref.read(userPreferencesProvider.notifier);
    final cardColor = Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userPreferencesProvider);
        await Future.delayed(const Duration(milliseconds: 800));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // User Header
        Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              child: Icon(Icons.person, size: 40, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _isEditingName
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  hintText: 'Your Name',
                                  isDense: true,
                                ),
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _saveName(user);
                              },
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                user?.displayName ?? 'Healthy Hero',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _nameController.text = user?.displayName ?? '';
                                setState(() => _isEditingName = true);
                              },
                            ),
                          ],
                        ),
                  Text(
                    user?.email ?? 'Unknown Email',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        
        // Personal Metrics
        Text('Personal Metrics', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: cardColor,
          child: Column(
            children: [
              _buildMetricInline(
                label: 'Weight',
                value: profile?['weight_kg'] != null 
                    ? (prefs.useMetric 
                        ? '${(profile!['weight_kg'] as num).toStringAsFixed(1)} kg' 
                        : '${((profile!['weight_kg'] as num) * 2.20462).toStringAsFixed(1)} lbs') 
                    : 'Not set',
                isEditing: _isEditingWeight,
                controller: _weightController,
                onEdit: () {
                  _weightController.text = profile?['weight_kg'] != null 
                      ? (prefs.useMetric ? (profile!['weight_kg'] as num).toStringAsFixed(1) : ((profile!['weight_kg'] as num) * 2.20462).toStringAsFixed(1))
                      : '';
                  setState(() => _isEditingWeight = true);
                },
                onSave: () => _saveWeight(ref, prefs.useMetric),
              ),
              const Divider(height: 1),
              _buildMetricInline(
                label: 'Height',
                value: profile?['height_cm'] != null ? '${profile!['height_cm']} cm' : 'Not set',
                isEditing: _isEditingHeight,
                controller: _heightController,
                onEdit: () {
                  _heightController.text = profile?['height_cm']?.toString() ?? '';
                  setState(() => _isEditingHeight = true);
                },
                onSave: () => _saveHeight(ref),
              ),
              const Divider(height: 1),
              _buildMetricInline(
                label: 'Age',
                value: profile?['age'] != null ? '${profile!['age']} yrs' : 'Not set',
                isEditing: _isEditingAge,
                controller: _ageController,
                onEdit: () {
                  _ageController.text = profile?['age']?.toString() ?? '';
                  setState(() => _isEditingAge = true);
                },
                onSave: () => _saveAge(ref),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Gender'),
                subtitle: Text(profile?['gender'] as String? ?? 'Not set'),
                trailing: DropdownButton<String>(
                  value: profile?['gender'] as String?,
                  hint: const Text('Select'),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(userProfileProvider.notifier).createProfile({'gender': val});
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        // Integrations
        Text('Integrations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: cardColor,
          child: ListTile(
            leading: const Icon(Icons.health_and_safety, color: Colors.green),
            title: const Text('Health Connect'),
            subtitle: const Text('Sync steps and vitals'),
            trailing: Switch(
              value: prefs.healthConnectEnabled,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                notifier.toggleHealthConnect(val);
              },
            ),
          ),
        ),

        const SizedBox(height: 32),
        // Preferences
        Text('Preferences', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: cardColor,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Dark Mode'),
                value: prefs.isDarkMode,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  notifier.toggleDarkMode(val);
                },
                secondary: const Icon(Icons.dark_mode),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Metric Units'),
                subtitle: const Text('Use km and kg'),
                value: prefs.useMetric,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  notifier.toggleMetric(val);
                },
                secondary: const Icon(Icons.straighten),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Notifications'),
                value: prefs.notificationsEnabled,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  notifier.toggleNotifications(val);
                },
                secondary: const Icon(Icons.notifications),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
      ),
    );
  }

  Widget _buildMetricInline({
    required String label,
    required String value,
    required bool isEditing,
    required TextEditingController controller,
    required VoidCallback onEdit,
    required VoidCallback onSave,
  }) {
    return ListTile(
      title: Text(label),
      subtitle: isEditing
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    autofocus: true,
                    onSubmitted: (_) => onSave(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () {
                  HapticFeedback.lightImpact();
                  onSave();
                }),
              ],
            )
          : Text(value),
      trailing: isEditing ? null : IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () {
        HapticFeedback.lightImpact();
        onEdit();
      }),
    );
  }
}
