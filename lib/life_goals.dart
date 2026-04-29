import 'package:flutter/material.dart';
import 'package:myapp/services/appwrite_service.dart';
import 'package:provider/provider.dart';

class LifeGoalsScreen extends StatefulWidget {
  const LifeGoalsScreen({super.key});

  @override
  State<LifeGoalsScreen> createState() => _LifeGoalsScreenState();
}

class _LifeGoalsScreenState extends State<LifeGoalsScreen> {
  bool _isLoading = true;
  bool _isMutating = false;
  List<Map<String, dynamic>> _goals = [];

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      final docs = await appwrite.getLifeGoals();
      if (!mounted) return;

      final mapped = docs.map((d) {
        final targetRaw = d.data['target'];
        final progressRaw = d.data['progress'];
        final target = targetRaw is num
            ? targetRaw.toInt()
            : int.tryParse(targetRaw?.toString() ?? '') ?? 0;
        final progress = progressRaw is num
            ? progressRaw.toInt()
            : int.tryParse(progressRaw?.toString() ?? '') ?? 0;

        return <String, dynamic>{
          'id': d.$id,
          'title': (d.data['title'] ?? '').toString(),
          'description': (d.data['description'] ?? '').toString(),
          'category': (d.data['category'] ?? '').toString(),
          'target': target < 0 ? 0 : target,
          'progress': progress < 0 ? 0 : progress,
          'unit': (d.data['unit'] ?? '').toString(),
        };
      }).toList();

      setState(() => _goals = mapped);
    } catch (e) {
      _showMessage('Failed to load life goals: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _saveGoal({
    String? documentId,
    required String title,
    required String category,
    required String target,
    required String progress,
    required String description,
    required String unit,
  }) async {
    final targetValue = int.tryParse(target.trim()) ?? 0;
    final progressValue = int.tryParse(progress.trim()) ?? 0;

    if (title.trim().isEmpty) {
      _showMessage('Title is required');
      return;
    }
    if (category.trim().isEmpty) {
      _showMessage('Category is required');
      return;
    }
    if (targetValue <= 0) {
      _showMessage('Target should be greater than 0');
      return;
    }

    if (!mounted) return;
    setState(() => _isMutating = true);
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      final payload = <String, dynamic>{
        'title': title.trim(),
        'category': category.trim(),
        'target': targetValue,
        'progress': progressValue < 0 ? 0 : progressValue,
        'description': description.trim(),
        'unit': unit.trim(),
      };
      if (documentId == null) {
        await appwrite.createLifeGoal(payload);
      } else {
        await appwrite.updateLifeGoal(documentId, payload);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      await _loadGoals();
      _showMessage(
        documentId == null ? 'Life goal created' : 'Life goal updated',
      );
    } catch (e) {
      _showMessage('Unable to save life goal: $e');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _deleteGoal(String id) async {
    if (!mounted) return;
    setState(() => _isMutating = true);
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      await appwrite.deleteLifeGoal(id);
      if (!mounted) return;
      await _loadGoals();
      _showMessage('Life goal deleted');
    } catch (e) {
      _showMessage('Unable to delete life goal: $e');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _updateProgress(String id, int progress) async {
    if (!mounted) return;
    setState(() => _isMutating = true);
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      await appwrite.updateLifeGoalProgress(id, progress < 0 ? 0 : progress);
      if (!mounted) return;
      setState(() {
        _goals = _goals.map((goal) {
          if (goal['id'] != id) return goal;
          return {...goal, 'progress': progress < 0 ? 0 : progress};
        }).toList();
      });
    } catch (e) {
      _showMessage('Unable to update progress: $e');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  void _openGoalSheet({Map<String, dynamic>? existing}) {
    final titleCtrl = TextEditingController(
      text: (existing?['title'] ?? '').toString(),
    );
    final categoryCtrl = TextEditingController(
      text: (existing?['category'] ?? '').toString(),
    );
    final targetCtrl = TextEditingController(
      text: (existing?['target'] ?? 0).toString(),
    );
    final progressCtrl = TextEditingController(
      text: (existing?['progress'] ?? 0).toString(),
    );
    final descriptionCtrl = TextEditingController(
      text: (existing?['description'] ?? '').toString(),
    );
    final unitCtrl = TextEditingController(
      text: (existing?['unit'] ?? '').toString(),
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existing == null ? 'Create Life Goal' : 'Edit Life Goal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _field(titleCtrl, 'Title'),
                _field(categoryCtrl, 'Category'),
                _field(targetCtrl, 'Target', isNumber: true),
                _field(progressCtrl, 'Progress', isNumber: true),
                _field(descriptionCtrl, 'Description', maxLines: 3),
                _field(unitCtrl, 'Unit (optional)'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isMutating
                        ? null
                        : () => _saveGoal(
                            documentId: existing?['id'] as String?,
                            title: titleCtrl.text,
                            category: categoryCtrl.text,
                            target: targetCtrl.text,
                            progress: progressCtrl.text,
                            description: descriptionCtrl.text,
                            unit: unitCtrl.text,
                          ),
                    child: Text(existing == null ? 'Save Goal' : 'Update Goal'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      titleCtrl.dispose();
      categoryCtrl.dispose();
      targetCtrl.dispose();
      progressCtrl.dispose();
      descriptionCtrl.dispose();
      unitCtrl.dispose();
    });
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Life Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isMutating ? null : () => _openGoalSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Add Goal'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
          ? const Center(child: Text('No life goals yet'))
          : RefreshIndicator(
              onRefresh: _loadGoals,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: _goals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final goal = _goals[index];
                  final target = (goal['target'] as int?) ?? 0;
                  final progress = (goal['progress'] as int?) ?? 0;
                  final safeTarget = target <= 0 ? 1 : target;
                  final ratio = (progress / safeTarget)
                      .clamp(0.0, 1.0)
                      .toDouble();
                  final unit = (goal['unit'] ?? '').toString().trim();
                  final progressText = unit.isEmpty
                      ? '$progress / $target'
                      : '$progress / $target $unit';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (goal['title'] ?? '').toString(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (goal['category'] ?? '').toString(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _openGoalSheet(existing: goal);
                                  } else if (value == 'delete') {
                                    _deleteGoal(goal['id'] as String);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if ((goal['description'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text((goal['description'] ?? '').toString()),
                          ],
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: ratio),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(progressText),
                              const Spacer(),
                              IconButton(
                                onPressed: _isMutating
                                    ? null
                                    : () => _updateProgress(
                                        goal['id'] as String,
                                        progress - 1,
                                      ),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              IconButton(
                                onPressed: _isMutating
                                    ? null
                                    : () => _updateProgress(
                                        goal['id'] as String,
                                        progress + 1,
                                      ),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
