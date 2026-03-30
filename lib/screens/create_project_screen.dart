import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _collabController = TextEditingController();
  final _levelController = TextEditingController();
  bool _isPrivate = true;
  final List<String> _collaborators = [];
  final List<String> _levels = [
    'Problem Statement',
    'Ideation',
    'Research',
    'Development',
    'Testing',
    'Documentation',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _collabController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  void _addCollaborator() {
    final val = _collabController.text.trim();
    if (val.isNotEmpty && !_collaborators.contains(val)) {
      setState(() => _collaborators.add(val));
      _collabController.clear();
    }
  }

  void _removeCollaborator(String c) =>
      setState(() => _collaborators.remove(c));

  void _addLevel() {
    final val = _levelController.text.trim();
    if (val.isNotEmpty && !_levels.contains(val)) {
      setState(() => _levels.add(val));
      _levelController.clear();
    }
  }

  void _removeLevel(String l) => setState(() => _levels.remove(l));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SimpleAppBar(title: 'Create Project'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Project Title'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'Enter project name'),
            ),
            const SizedBox(height: 20),
            _label('Project Description'),
            const SizedBox(height: 6),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration:
                  const InputDecoration(hintText: 'Describe your project'),
            ),
            const SizedBox(height: 20),
            _label('Collaborators'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _collabController,
                    decoration: const InputDecoration(
                        hintText: 'Search user by username or email'),
                    onSubmitted: (_) => _addCollaborator(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addCollaborator,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14)),
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_collaborators.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _collaborators
                    .map((c) => Chip(
                          label: Text(c),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => _removeCollaborator(c),
                          backgroundColor: const Color(0xFFEFF6FF),
                          labelStyle: const TextStyle(
                              fontSize: 13, color: AppTheme.primary),
                          deleteIconColor: AppTheme.primary,
                          side: BorderSide.none,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            _label('Visibility'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                    child: _VisibilityButton(
                        label: 'Public',
                        selected: !_isPrivate,
                        onTap: () => setState(() => _isPrivate = false))),
                const SizedBox(width: 10),
                Expanded(
                    child: _VisibilityButton(
                        label: 'Private',
                        selected: _isPrivate,
                        onTap: () => setState(() => _isPrivate = true))),
              ],
            ),
            const SizedBox(height: 20),
            _label('Project Levels'),
            const SizedBox(height: 6),
            ..._levels.map((level) =>
                _LevelTile(label: level, onRemove: () => _removeLevel(level))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _levelController,
                    decoration:
                        const InputDecoration(hintText: 'Add custom stage'),
                    onSubmitted: (_) => _addLevel(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _addLevel,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.border),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Project created successfully'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                child: const Text('Create Project'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary));
}

class _VisibilityButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
              )),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _LevelTile({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textPrimary))),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
