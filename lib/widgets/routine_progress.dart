import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/routines_provider.dart';
import '../providers/user_provider.dart';

class RoutineProgressDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> routine;
  const RoutineProgressDialog({super.key, required this.routine});

  @override
  ConsumerState<RoutineProgressDialog> createState() => _RoutineProgressDialogState();
}

class _RoutineProgressDialogState extends ConsumerState<RoutineProgressDialog> {
  late int completed;

  @override
  void initState() {
    super.initState();
    completed = widget.routine['completed_exercises'];
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.routine['total_exercises'] as int;
    final progress = total > 0 ? completed / total : 0.0;

    return AlertDialog(
      title: Text(widget.routine['title']),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 16),
          Text('$completed of $total exercises completed', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 40),
                onPressed: completed > 0 ? () => setState(() => completed--) : null,
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 40),
                onPressed: completed < total ? () => setState(() => completed++) : null,
              ),
            ],
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            // Optimistic update
            ref.read(routinesProvider.notifier).updateRoutineData(widget.routine['id'], {'completed_exercises': completed});
            
            final api = ref.read(apiServiceProvider);
            final user = ref.read(firebaseAuthProvider).currentUser;
            if (user != null) {
              api.updateRoutine(user.uid, widget.routine['id'], {'completed_exercises': completed}).catchError((_) {
                ref.invalidate(routinesProvider); // Revert on error
                return <String, dynamic>{};
              });
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save Progress'),
        )
      ],
    );
  }
}
