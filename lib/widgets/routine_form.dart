import 'package:flutter/material.dart';

class RoutineFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const RoutineFormDialog({super.key, this.initialData});

  @override
  State<RoutineFormDialog> createState() => _RoutineFormDialogState();
}

class _RoutineFormDialogState extends State<RoutineFormDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _subtitleCtrl;
  late TextEditingController _exercisesCtrl;
  String _iconName = 'fitness_center';
  String _colorHex = 'FF2196F3';

  final Map<String, String> _icons = {
    'Dumbbell': 'fitness_center',
    'Yoga & Stretching': 'self_improvement',
    'Sleep & Rest': 'nights_stay',
    'Running': 'directions_run',
    'Swimming': 'pool',
    'Cycling': 'directions_bike',
  };
  final Map<String, String> _colors = {
    'Blue': 'FF2196F3',
    'Red': 'FFF44336',
    'Purple': 'FF9C27B0',
    'Green': 'FF4CAF50',
    'Orange': 'FFFF9800',
    'Teal': 'FF009688',
  };

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialData?['title'] ?? '');
    _subtitleCtrl = TextEditingController(text: widget.initialData?['subtitle'] ?? '');
    _exercisesCtrl = TextEditingController(text: (widget.initialData?['total_exercises'] ?? 5).toString());
    if (widget.initialData != null) {
      _iconName = widget.initialData!['icon_name'];
      _colorHex = widget.initialData!['color_hex'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialData == null ? 'New Routine' : 'Edit Routine'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _subtitleCtrl, decoration: const InputDecoration(labelText: 'Subtitle')),
            TextField(controller: _exercisesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Exercises')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _iconName,
              decoration: const InputDecoration(labelText: 'Icon'),
              items: _icons.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
              onChanged: (v) => setState(() => _iconName = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _colorHex,
              decoration: const InputDecoration(labelText: 'Color'),
              items: _colors.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
              onChanged: (v) => setState(() => _colorHex = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, <String, dynamic>{
              'title': _titleCtrl.text,
              'subtitle': _subtitleCtrl.text,
              'icon_name': _iconName,
              'color_hex': _colorHex,
              'total_exercises': int.tryParse(_exercisesCtrl.text) ?? 5,
              'completed_exercises': widget.initialData?['completed_exercises'] ?? 0,
            });
          },
          child: const Text('Save'),
        )
      ],
    );
  }
}
