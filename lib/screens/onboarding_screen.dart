import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/user_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _name = '';
  int _age = 25;
  String _gender = 'Male';
  double _heightCm = 175.0;
  double _weightKg = 70.0;
  double _targetWeightKg = 65.0;
  String _lifestyle = 'Moderately Active';

  final List<String> _lifestyles = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active',
    'Extra Active'
  ];

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final profileData = {
        'name': _name,
        'age': _age,
        'gender': _gender,
        'height_cm': _heightCm,
        'weight_kg': _weightKg,
        'target_weight_kg': _targetWeightKg,
        'lifestyle': _lifestyle,
      };

      await ref.read(userProfileProvider.notifier).createProfile(profileData);
      
      if (mounted) {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Build Your Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Let the AI Coach know about you.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                onSaved: (val) => _name = val ?? '',
                validator: (val) => val!.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      initialValue: _age.toString(),
                      onSaved: (val) => _age = int.parse(val ?? '25'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                      value: _gender,
                      items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (val) => setState(() => _gender = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      initialValue: _heightCm.toString(),
                      onSaved: (val) => _heightCm = double.parse(val ?? '175'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      initialValue: _weightKg.toString(),
                      onSaved: (val) => _weightKg = double.parse(val ?? '70'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Target Weight (kg)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                initialValue: _targetWeightKg.toString(),
                onSaved: (val) => _targetWeightKg = double.parse(val ?? '65'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Lifestyle', border: OutlineInputBorder()),
                value: _lifestyle,
                items: _lifestyles.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (val) => setState(() => _lifestyle = val!),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Generate AI Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
