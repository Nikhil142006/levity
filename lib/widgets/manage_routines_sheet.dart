import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/routines_provider.dart';
import '../providers/user_provider.dart';
import 'routine_form.dart';

class ManageRoutinesSheet extends ConsumerWidget {
  const ManageRoutinesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesState = ref.watch(routinesProvider);
    
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Manage Routines', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          routinesState.when(
            data: (data) {
              final routines = (data['routines'] ?? []) as List;
              return Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: routines.length,
                  itemBuilder: (context, index) {
                    final r = routines[index];
                    return ListTile(
                      title: Text(r['title']),
                      subtitle: Text(r['subtitle']),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () async {
                              final updated = await showDialog<Map<String, dynamic>>(
                                context: context,
                                builder: (_) => RoutineFormDialog(initialData: r),
                              );
                              if (updated != null) {
                                // Optimistic update
                                ref.read(routinesProvider.notifier).updateRoutineData(r['id'], updated);
                                
                                final api = ref.read(apiServiceProvider);
                                final user = ref.read(firebaseAuthProvider).currentUser;
                                api.updateRoutine(user!.uid, r['id'], updated).catchError((_) {
                                  ref.invalidate(routinesProvider); // Revert on failure
                                  return <String, dynamic>{};
                                });
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              // Optimistic deletion
                              ref.read(routinesProvider.notifier).removeRoutine(r['id']);
                              
                              final api = ref.read(apiServiceProvider);
                              final user = ref.read(firebaseAuthProvider).currentUser;
                              api.deleteRoutine(user!.uid, r['id']).catchError((_) {
                                ref.invalidate(routinesProvider); // Revert on failure
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add New Routine'),
                onPressed: () async {
                  final newRoutine = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => const RoutineFormDialog(),
                  );
                  if (newRoutine != null) {
                    // Create a temporary ID for optimistic addition
                    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
                    newRoutine['id'] = tempId;
                    ref.read(routinesProvider.notifier).addRoutine(newRoutine);
                    
                    final api = ref.read(apiServiceProvider);
                    final user = ref.read(firebaseAuthProvider).currentUser;
                    api.createRoutine(user!.uid, newRoutine).then((createdRoutine) {
                      // Replace temp ID with real ID
                      ref.read(routinesProvider.notifier).updateRoutineData(tempId, createdRoutine);
                    }).catchError((_) {
                      ref.invalidate(routinesProvider); // Revert on failure
                    });
                  }
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}
