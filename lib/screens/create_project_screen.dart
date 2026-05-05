import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/project_service.dart';
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
  final _emailController = TextEditingController();
  final _requiredCollabController = TextEditingController();
  
  bool _isPublic = false;
  bool _isOpenForRequests = true;
  final Map<String, String> _collaborators = {}; // Map<userId, role>
  final List<String> _requiredSkills = [];
  final List<String> _skillInputList = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _collabController.dispose();
    _emailController.dispose();
    _requiredCollabController.dispose();
    super.dispose();
  }

  /// Look up user by email or username
  Future<void> _addCollaborator() async {
    final input = _collabController.text.trim();
    if (input.isEmpty) return;

    try {
      // Search for user by email or display name in Firestore
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: input)
          .limit(1)
          .get();

      if (usersQuery.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not found'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final userId = usersQuery.docs.first.id;
      final userName = usersQuery.docs.first.data()['name'] as String? ?? input;

      if (_collaborators.containsKey(userId)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User already added'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        _collaborators[userId] = 'collaborator';
        _collabController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeCollaborator(String userId) =>
      setState(() => _collaborators.remove(userId));

  void _addSkill() {
    final skill = _skillInputList.isNotEmpty ? _skillInputList.last : '';
    if (skill.isNotEmpty && !_requiredSkills.contains(skill)) {
      setState(() => _requiredSkills.add(skill));
      _skillInputList.clear();
    }
  }

  void _removeSkill(String skill) =>
      setState(() => _requiredSkills.remove(skill));

  Future<void> _createProject() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter project title'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter project description'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ProjectService.instance.createProject(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        collaborators: _collaborators,
        visibility: _isPublic ? 'public' : 'private',
        isOpenForRequests: _isOpenForRequests,
        requiredCollaborators: int.tryParse(_requiredCollabController.text) ?? 0,
        requiredSkills: _requiredSkills,
        contactEmail: _emailController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project created successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
            _label('Contact Email'),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(hintText: 'project@example.com'),
            ),
            const SizedBox(height: 20),
            _label('Visibility'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                    child: _VisibilityButton(
                        label: 'Public',
                        selected: _isPublic,
                        onTap: () => setState(() => _isPublic = true))),
                const SizedBox(width: 10),
                Expanded(
                    child: _VisibilityButton(
                        label: 'Private',
                        selected: !_isPublic,
                        onTap: () => setState(() => _isPublic = false))),
              ],
            ),
            const SizedBox(height: 20),
            if (_isPublic) ...[
              _label('Open for Join Requests?'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Checkbox(
                    value: _isOpenForRequests,
                    onChanged: (val) =>
                        setState(() => _isOpenForRequests = val ?? false),
                    activeColor: AppTheme.primary,
                  ),
                  const Text('Allow users to request to join'),
                ],
              ),
              const SizedBox(height: 20),
            ],
            _label('Add Collaborators (by email)'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _collabController,
                    decoration: const InputDecoration(
                        hintText: 'Search user by email'),
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
                children: _collaborators.entries
                    .map((entry) => Chip(
                          label: Text(entry.key),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => _removeCollaborator(entry.key),
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
            _label('Required Number of Collaborators'),
            const SizedBox(height: 6),
            TextField(
              controller: _requiredCollabController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '5'),
            ),
            const SizedBox(height: 20),
            _label('Required Skills'),
            const SizedBox(height: 6),
            ..._requiredSkills.map((skill) => _SkillTile(
                label: skill, onRemove: () => _removeSkill(skill))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) {
                      if (_skillInputList.isEmpty) {
                        _skillInputList.add(val);
                      } else {
                        _skillInputList[0] = val;
                      }
                    },
                    decoration:
                        const InputDecoration(hintText: 'Add skill (e.g., Flutter)'),
                    onSubmitted: (_) => _addSkill(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _addSkill,
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
                onPressed: _isLoading ? null : _createProject,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Create Project'),
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

class _SkillTile extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _SkillTile({required this.label, required this.onRemove});

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
