import 'package:flutter/material.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
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
  final _usernameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _requiredCollabController = TextEditingController();
  final _customLevelController = TextEditingController();
  
  bool _isPublic = false;
  bool _isOpenForRequests = false;
  final List<String> _collaboratorUsernames = [];
  final List<String> _requiredSkills = [];
  final _skillController = TextEditingController();
  bool _isLoading = false;
  
  // Default levels
  late List<Map<String, dynamic>> _levels;

  @override
  void initState() {
    super.initState();
    _initializeDefaultLevels();
  }

  void _initializeDefaultLevels() {
    _levels = [
      {'title': 'Problem Statement', 'order': 1},
      {'title': 'Ideation', 'order': 2},
      {'title': 'Research', 'order': 3},
      {'title': 'Development', 'order': 4},
      {'title': 'Testing', 'order': 5},
      {'title': 'Documentation', 'order': 6},
    ];
  }

  void _removeLevel(int index) {
    setState(() {
      _levels.removeAt(index);
      // Reorder
      for (int i = 0; i < _levels.length; i++) {
        _levels[i]['order'] = i + 1;
      }
    });
  }

  void _addCustomLevel() {
    final title = _customLevelController.text.trim();
    if (title.isEmpty) {
      _showSnackBar('Please enter a level name');
      return;
    }

    if (_levels.any((l) => l['title'].toLowerCase() == title.toLowerCase())) {
      _showSnackBar('Level "$title" already exists');
      return;
    }

    setState(() {
      _levels.add({
        'title': title,
        'order': _levels.length + 1,
      });
      _customLevelController.clear();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _usernameController.dispose();
    _contactEmailController.dispose();
    _requiredCollabController.dispose();
    _customLevelController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  /// Add collaborator by username with validation
  Future<void> _addCollaborator() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showSnackBar('Please enter a username');
      return;
    }

    // Check for duplicates
    if (_collaboratorUsernames.contains(username.toLowerCase())) {
      _showSnackBar('User "@$username" already added');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verify user exists
      final user = await UserService.instance.getUserByUsername(username);
      if (user == null) {
        _showSnackBar('User "@$username" not found');
        return;
      }

      setState(() {
        _collaboratorUsernames.add(username.toLowerCase());
        _usernameController.clear();
      });

      _showSnackBar('Added @${user.$2} as collaborator');
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removeCollaborator(String username) {
    setState(() => _collaboratorUsernames.remove(username));
  }

  void _addSkill() {
    final skill = _skillController.text.trim();
    if (skill.isEmpty) {
      _showSnackBar('Please enter a skill');
      return;
    }

    if (_requiredSkills.contains(skill.toLowerCase())) {
      _showSnackBar('Skill "$skill" already added');
      return;
    }

    setState(() {
      _requiredSkills.add(skill.toLowerCase());
      _skillController.clear();
    });
  }

  void _removeSkill(String skill) {
    setState(() => _requiredSkills.remove(skill));
  }

  Future<void> _createProject() async {
    // Validate inputs
    final title = _titleController.text.trim();
    final description = _descController.text.trim();

    if (title.isEmpty) {
      _showSnackBar('Please enter project title');
      return;
    }

    if (description.isEmpty) {
      _showSnackBar('Please enter project description');
      return;
    }

    if (_levels.isEmpty) {
      _showSnackBar('Please add at least one project level');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ProjectService.instance.createProject(
        title: title,
        description: description,
        collaboratorUsernames: _collaboratorUsernames,
        visibility: _isPublic ? 'public' : 'private',
        isOpenForRequests: _isOpenForRequests,
        requiredCollaborators: int.tryParse(_requiredCollabController.text) ?? 0,
        requiredSkills: _requiredSkills,
        contactEmail: _contactEmailController.text.trim(),
        levels: _levels,
      );

      if (!mounted) return;

      _showSnackBar('Project created successfully!');
      Navigator.of(context).pop(); // Go back to home
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
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
            // Project Title
            _label('Project Title *'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Enter project name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Project Description
            _label('Project Description *'),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe your project goals and scope',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Contact Email
            _label('Contact Email'),
            const SizedBox(height: 8),
            TextField(
              controller: _contactEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'project@example.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Project Levels
            _label('Project Levels'),
            const SizedBox(height: 8),
            // Display current levels
            Column(
              children: List.generate(
                _levels.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _levels[index]['title'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _levels.length > 1
                              ? () => _removeLevel(index)
                              : null,
                          color: _levels.length > 1
                              ? AppTheme.danger
                              : const Color(0xFFD1D5DB),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Add custom level
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customLevelController,
                    decoration: InputDecoration(
                      hintText: 'Add custom stage',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _addCustomLevel(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addCustomLevel,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Visibility
            _label('Project Visibility *'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _VisibilityButton(
                    label: 'Public',
                    icon: Icons.people,
                    selected: _isPublic,
                    onTap: () => setState(() {
                      _isPublic = true;
                      _isOpenForRequests = false; // Reset requests
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VisibilityButton(
                    label: 'Private',
                    icon: Icons.lock,
                    selected: !_isPublic,
                    onTap: () => setState(() {
                      _isPublic = false;
                      _isOpenForRequests = false; // Disable for private
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_isPublic)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDEBD47)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, size: 18, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Private projects are only visible to collaborators',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Open for Requests (only for public projects)
            if (_isPublic) ...[
              _label('Open for Join Requests?'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _isOpenForRequests,
                            onChanged: (val) =>
                                setState(() => _isOpenForRequests = val ?? false),
                            activeColor: AppTheme.primary,
                          ),
                          const Expanded(
                            child: Text(
                              'Allow users to request to join this project',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      if (_isOpenForRequests) ...[
                        const Divider(height: 16),
                        _label('Required Number of Collaborators'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _requiredCollabController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g., 5',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _label('Required Skills'),
                        const SizedBox(height: 8),
                        ..._requiredSkills.map((skill) =>
                            _SkillTile(
                              skill: skill,
                              onRemove: () => _removeSkill(skill),
                            )),
                        if (_requiredSkills.isNotEmpty)
                          const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _skillController,
                                decoration: InputDecoration(
                                  hintText: 'Add skill (e.g., Flutter)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
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
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Add Collaborators
            _label('Add Collaborators (by username)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: 'e.g., john_doe',
                      prefixText: '@',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (_) => _addCollaborator(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _addCollaborator,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),

            if (_collaboratorUsernames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _collaboratorUsernames
                    .map((username) => Chip(
                      avatar: const Icon(Icons.person, size: 18),
                      label: Text('@$username'),
                      onDeleted: () => _removeCollaborator(username),
                      backgroundColor: const Color(0xFFEFF6FF),
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.primary,
                      ),
                      deleteIconColor: AppTheme.primary,
                      side: BorderSide.none,
                    ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 28),

            // Create Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createProject,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

  Widget _label(String text, {bool required = false}) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
    ),
  );
}

class _VisibilityButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppTheme.primary : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? AppTheme.primary : const Color(0xFF6B7280),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  final String skill;
  final VoidCallback onRemove;

  const _SkillTile({
    required this.skill,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                skill,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFEE2E2),
            ),
            iconSize: 16,
            color: AppTheme.danger,
          ),
        ],
      ),
    );
  }
}

