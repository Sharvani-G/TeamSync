import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _skillController = TextEditingController();
  final _collabUsernameController = TextEditingController();
  final _collabCountController = TextEditingController(text: '1');
  final _sectionController = TextEditingController();

  final List<String> _skills = [];
  final List<String> _sections = [
    "Problem Statement",
    "Research",
    "Design",
    "Development",
    "Testing"
  ];
  String _visibility = 'private';
  bool _isOpenToRequests = false;
  final List<AppUser> _selectedCollaborators = [];
  bool _isSearchingUser = false;
  bool _isCreating = false;
  String? _userSearchError;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _skillController.dispose();
    _collabUsernameController.dispose();
    _collabCountController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  void _addSection() {
    final section = _sectionController.text.trim();
    if (section.isNotEmpty && !_sections.contains(section)) {
      setState(() {
        _sections.add(section);
        _sectionController.clear();
      });
    }
  }

  void _addSkill() {
    final skill = _skillController.text.trim();
    if (skill.isNotEmpty && !_skills.contains(skill)) {
      setState(() {
        _skills.add(skill);
        _skillController.clear();
      });
    }
  }

  Future<void> _searchAndAddCollaborator() async {
    final username = _collabUsernameController.text.trim();
    if (username.isEmpty) return;

    if (_selectedCollaborators.any((u) => u.username.toLowerCase() == username.toLowerCase())) {
      setState(() => _userSearchError = 'User already added');
      return;
    }

    setState(() {
      _isSearchingUser = true;
      _userSearchError = null;
    });

    try {
      final user = await UserService.instance.getUserByUsername(username);
      if (user != null) {
        final fullUser = await UserService.instance.getUserById(user.$1);
        if (fullUser != null) {
          if (fullUser.id == FirebaseAuth.instance.currentUser?.uid) {
            setState(() => _userSearchError = 'Cannot add yourself');
          } else {
            setState(() {
              _selectedCollaborators.add(fullUser);
              _collabUsernameController.clear();
            });
          }
        } else {
          setState(() => _userSearchError = 'User profile not found');
        }
      } else {
        setState(() => _userSearchError = 'User @$username not found');
      }
    } catch (e) {
      setState(() => _userSearchError = 'Error searching user: $e');
    } finally {
      if (mounted) setState(() => _isSearchingUser = false);
    }
  }

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate() || _isCreating) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isCreating = true);

    try {
      if (_sections.isEmpty) {
        throw Exception('At least one Idea Board section is required');
      }

      final projectId = await ProjectService.instance.createProject(
        title: _nameController.text.trim(),
        description: _descController.text.trim(),
        requiredSkills: _skills,
        visibility: _visibility,
        isOpenForRequests: _isOpenToRequests,
        requiredCollaborators:
            _isOpenToRequests ? int.tryParse(_collabCountController.text) ?? 1 : 0,
        collaboratorUsernames:
            _selectedCollaborators.map((u) => u.username).toList(),
        contactEmail: user.email ?? '',
        ideaBoardSections: _sections,
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/project/$projectId/workspace');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.dpDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: const SimpleAppBar(title: 'Create Project'),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Basic Information Card
                    _FormCard(
                      title: 'Basic Information',
                      subtitle: 'Title and objective of your project',
                      children: [
                        _FieldLabel(label: 'Project Name', isRequired: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                          decoration: _inputDecoration('e.g. HealthTech Collaboration Hub'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Project name is required' : null,
                        ),
                        const SizedBox(height: 18),
                        _FieldLabel(label: 'Project Description', isRequired: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descController,
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                          minLines: 3,
                          maxLines: null,
                          decoration: _inputDecoration(
                              'Describe the scope, objectives, and deliverables for this project...'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Description is required';
                            }
                            if (v.trim().length < 20) {
                              return 'Description must be at least 20 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 2: Visibility & Collaboration Card
                    _FormCard(
                      title: 'Visibility & Access',
                      subtitle: 'Control who can view and join this project',
                      children: [
                        _FieldLabel(label: 'Project Visibility', isRequired: true),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _VisibilityOption(
                              label: 'Private',
                              description: 'Only invited collaborators can access',
                              icon: Icons.lock_outline,
                              value: 'private',
                              groupValue: _visibility,
                              onChanged: (v) => setState(() {
                                _visibility = v!;
                                _isOpenToRequests = false;
                              }),
                            ),
                            const SizedBox(width: 14),
                            _VisibilityOption(
                              label: 'Public',
                              description: 'Visible on the Discover directory',
                              icon: Icons.public,
                              value: 'public',
                              groupValue: _visibility,
                              onChanged: (v) => setState(() => _visibility = v!),
                            ),
                          ],
                        ),
                        if (_visibility == 'public') ...[
                          const SizedBox(height: 20),
                          const Divider(height: 1, color: AppTheme.rule),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Open to Join Requests', style: AppTheme.heading3.copyWith(fontSize: 14.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Allow other users to submit requests to join this project',
                                    style: AppTheme.metadataText,
                                  ),
                                ],
                              ),
                              Switch(
                                value: _isOpenToRequests,
                                activeColor: AppTheme.accent,
                                onChanged: (v) => setState(() => _isOpenToRequests = v),
                              ),
                            ],
                          ),
                          if (_isOpenToRequests) ...[
                            const SizedBox(height: 16),
                            _FieldLabel(label: 'Required Collaborators (1-20)'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _collabCountController,
                              keyboardType: TextInputType.number,
                              style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                              decoration: _inputDecoration('e.g. 4 collaborators needed'),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n < 1 || n > 20) {
                                  return 'Enter a number between 1 and 20';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 3: Skills & Roles Card
                    _FormCard(
                      title: 'Skills & Roles Needed',
                      subtitle: 'Specify expertise or roles to attract the right contributors',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _skillController,
                                style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                                decoration: _inputDecoration('e.g. UI/UX Designer, Flutter Developer'),
                                onSubmitted: (_) => _addSkill(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _addSkill,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                              ),
                              child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        if (_skills.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _skills
                                .map((skill) => Chip(
                                      label: Text(skill, style: AppTheme.labelText.copyWith(color: AppTheme.ink)),
                                      backgroundColor: AppTheme.groundMuted,
                                      side: const BorderSide(color: AppTheme.rule),
                                      deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.inkSecondary),
                                      onDeleted: () => setState(() => _skills.remove(skill)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 4: Idea Board Sections Card
                    _FormCard(
                      title: 'Idea Board Sections',
                      subtitle: 'Phases and milestone levels for structured project ideation',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _sectionController,
                                style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                                decoration: _inputDecoration('Add a custom section (e.g. Architecture)'),
                                onSubmitted: (_) => _addSection(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _addSection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                              ),
                              child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.panel,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.rule, width: 1),
                          ),
                          child: ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) newIndex -= 1;
                                final String item = _sections.removeAt(oldIndex);
                                _sections.insert(newIndex, item);
                              });
                            },
                            children: _sections.asMap().entries.map((entry) {
                              final index = entry.key;
                              final section = entry.value;
                              return ListTile(
                                key: ValueKey(section),
                                dense: true,
                                leading: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: AppColors.dpInfoBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: AppTheme.labelText.copyWith(
                                        color: AppTheme.accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(section, style: AppTheme.bodySmall.copyWith(color: AppTheme.ink)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_sections.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16, color: AppTheme.inkSecondary),
                                        tooltip: 'Remove section',
                                        onPressed: () => setState(() => _sections.removeAt(index)),
                                      ),
                                    const Icon(Icons.drag_handle, size: 18, color: AppTheme.inkSecondary),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 5: Add Collaborators Card
                    _FormCard(
                      title: 'Add Initial Collaborators',
                      subtitle: 'Search and invite registered team members by their username',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _collabUsernameController,
                                style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                                decoration: _inputDecoration('Enter username (without @)').copyWith(
                                  errorText: _userSearchError,
                                  prefixIcon: const Icon(Icons.alternate_email, size: 18, color: AppTheme.inkSecondary),
                                ),
                                onSubmitted: (_) => _searchAndAddCollaborator(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _isSearchingUser
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 14),
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _searchAndAddCollaborator,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                                    ),
                                    child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  ),
                          ],
                        ),
                        if (_selectedCollaborators.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedCollaborators
                                .map((u) => Chip(
                                      avatar: UserAvatar(name: u.name, username: u.username, size: 24),
                                      label: Text(u.name, style: AppTheme.labelText.copyWith(color: AppTheme.ink)),
                                      backgroundColor: AppTheme.groundMuted,
                                      side: const BorderSide(color: AppTheme.rule),
                                      deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.inkSecondary),
                                      onDeleted: () => setState(() => _selectedCollaborators.remove(u)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isCreating ? null : _createProject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        child: _isCreating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Create Project',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
      filled: true,
      fillColor: AppTheme.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.rule, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.rule, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppColors.dpDanger, width: 1),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool isRequired;

  const _FieldLabel({required this.label, this.isRequired = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: AppTheme.labelText.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: AppTheme.labelText.copyWith(
              color: AppColors.dpDanger,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _FormCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
        border: Border.all(color: AppTheme.rule, width: AppTheme.borderHairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0616191F),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.heading3),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTheme.metadataText),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _VisibilityOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return Expanded(
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.dpInfoBg : AppTheme.panel,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: selected ? AppTheme.accent : AppTheme.rule,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? AppTheme.accent : AppTheme.inkSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTheme.heading3.copyWith(
                      fontSize: 14,
                      color: selected ? AppTheme.accent : AppTheme.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: AppTheme.metadataText.copyWith(
                  fontSize: 11.5,
                  color: selected ? AppTheme.ink : AppTheme.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
