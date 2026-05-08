import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ProjectAdminScreen extends StatefulWidget {
  final String projectId;
  final Project project;

  const ProjectAdminScreen({
    super.key,
    required this.projectId,
    required this.project,
  });

  @override
  State<ProjectAdminScreen> createState() => _ProjectAdminScreenState();
}

class _ProjectAdminScreenState extends State<ProjectAdminScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppBar(title: 'Manage: ${widget.project.title}'),
      body: PageView(
        controller: _pageController,
        children: [
          _JoinRequestsTab(projectId: widget.projectId),
          _CollaboratorsTab(projectId: widget.projectId, project: widget.project),
          _LevelsTab(projectId: widget.projectId),
          _SettingsTab(projectId: widget.projectId, project: widget.project),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.mail),
            label: 'Join Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Collaborators',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_list),
            label: 'Levels',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: 0,
        onTap: (index) => _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      ),
    );
  }
}

class _JoinRequestsTab extends StatelessWidget {
  final String projectId;

  const _JoinRequestsTab({required this.projectId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JoinRequest>>(
      stream: ProjectService.instance.watchJoinRequests(projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? [];
        final pendingRequests = requests.where((r) => r.status == 'pending').toList();

        if (pendingRequests.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: Icons.mail_outline,
              title: 'No pending requests',
              subtitle: 'Join requests will appear here',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pendingRequests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final request = pendingRequests[index];
            final githubLink = request.githubLink ?? '';
            final linkedinLink = request.linkedinLink ?? '';
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
                                request.requestedByName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Skills: ${request.skills}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatDate(request.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (githubLink.isNotEmpty || linkedinLink.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (githubLink.isNotEmpty)
                            const Icon(Icons.link, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          if (githubLink.isNotEmpty)
                            const Text('GitHub', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                          const SizedBox(width: 12),
                          if (linkedinLink.isNotEmpty)
                            const Icon(Icons.link, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          if (linkedinLink.isNotEmpty)
                            const Text('LinkedIn', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                        ],
                      ),
                    ],
                    if (request.fileUrls.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${request.fileUrls.length} files attached',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rejectRequest(context, request.id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textMuted,
                              side: const BorderSide(color: AppTheme.border),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _acceptRequest(context, request.id),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  Future<void> _acceptRequest(BuildContext context, String requestId) async {
    try {
      await ProjectService.instance.acceptJoinRequest(requestId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request accepted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _rejectRequest(BuildContext context, String requestId) async {
    try {
      await ProjectService.instance.rejectJoinRequest(requestId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _CollaboratorsTab extends StatelessWidget {
  final String projectId;
  final Project project;

  const _CollaboratorsTab({
    required this.projectId,
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    final allCollaborators = [
      (
        project.createdBy,
        project.collaborators[project.createdBy] ?? 'admin',
        true,
      ), // (userId, role, isAdmin)
      ...project.collaborators.entries
          .where((entry) => entry.key != project.createdBy)
          .map((e) => (e.key, e.value, false)),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Team Members',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...allCollaborators
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final (userId, role, isAdmin) = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User ID: $userId',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Role: $role',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isAdmin)
                      IconButton(
                        onPressed: () =>
                            _removeCollaborator(context, userId),
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppTheme.textMuted),
                      ),
                  ],
                ),
              );
            })
            .toList(),
      ],
    );
  }

  Future<void> _removeCollaborator(BuildContext context, String userId) async {
    try {
      await ProjectService.instance.removeCollaborator(
        projectId: projectId,
        userId: userId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Collaborator removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _LevelsTab extends StatefulWidget {
  final String projectId;

  const _LevelsTab({required this.projectId});

  @override
  State<_LevelsTab> createState() => _LevelsTabState();
}

class _LevelsTabState extends State<_LevelsTab> {
  final TextEditingController _levelTitleController = TextEditingController();

  @override
  void dispose() {
    _levelTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(widget.projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final project = snapshot.data;
        if (project == null) {
          return const Center(child: Text('Project not found'));
        }

        final orderedLevels = [...project.levels]
          ..sort((a, b) => a.order.compareTo(b.order));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Project Levels',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only the project admin can modify levels. Changes sync instantly for everyone.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _levelTitleController,
              decoration: const InputDecoration(
                labelText: 'New level title',
                hintText: 'Enter a level name',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addLevel,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Level'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: orderedLevels.isEmpty ? _restoreDefaults : null,
                  child: const Text('Restore Defaults'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (orderedLevels.isEmpty)
              const EmptyState(
                icon: Icons.view_list_outlined,
                title: 'No levels yet',
                subtitle: 'Restore the default set or add a new level',
              )
            else
              ...orderedLevels.map((level) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.12),
                      foregroundColor: AppTheme.primary,
                      child: Text('${level.order}'),
                    ),
                    title: Text(level.title),
                    subtitle: Text('Created ${level.createdAt.month}/${level.createdAt.day}/${level.createdAt.year}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _renameLevel(level.id, level.title),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteLevel(level.id),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Future<void> _addLevel() async {
    final title = _levelTitleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    try {
      await ProjectService.instance.addProjectLevel(
        projectId: widget.projectId,
        title: title,
      );
      _levelTitleController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Level added'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  Future<void> _restoreDefaults() async {
    try {
      await ProjectService.instance.replaceProjectLevels(
        projectId: widget.projectId,
        levels: const [],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default levels restored'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  Future<void> _renameLevel(String levelId, String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Level'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Level title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newTitle == null || newTitle.isEmpty) {
      return;
    }

    try {
      await ProjectService.instance.renameProjectLevel(
        projectId: widget.projectId,
        levelId: levelId,
        title: newTitle,
      );
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

  Future<void> _deleteLevel(String levelId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Level'),
          content: const Text('Remove this level? Orders will be rebalanced automatically.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ProjectService.instance.removeProjectLevel(
        projectId: widget.projectId,
        levelId: levelId,
      );
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
}

class _SettingsTab extends StatefulWidget {
  final String projectId;
  final Project project;

  const _SettingsTab({
    required this.projectId,
    required this.project,
  });

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late bool _isPublic;
  late bool _isOpenForRequests;

  @override
  void initState() {
    super.initState();
    _isPublic = widget.project.visibility == 'public';
    _isOpenForRequests = widget.project.isOpenForRequests;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Project Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        _SettingTile(
          title: 'Visibility',
          subtitle: _isPublic ? 'Public - Anyone can discover' : 'Private - Only collaborators',
          icon: _isPublic ? Icons.public : Icons.lock,
          trailing: Switch(
            value: _isPublic,
            onChanged: (val) => _updateVisibility(val),
            activeColor: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        if (_isPublic) ...[
          _SettingTile(
            title: 'Open for Requests',
            subtitle: _isOpenForRequests
                ? 'Users can request to join'
                : 'Requests closed',
            icon: _isOpenForRequests ? Icons.mail : Icons.mail_lock,
            trailing: Switch(
              value: _isOpenForRequests,
              onChanged: (val) => _updateOpenForRequests(val),
              activeColor: AppTheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _updateVisibility(bool isPublic) async {
    try {
      await ProjectService.instance.updateProject(
        projectId: widget.projectId,
        visibility: isPublic ? 'public' : 'private',
      );
      setState(() => _isPublic = isPublic);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project visibility updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  Future<void> _updateOpenForRequests(bool value) async {
    try {
      await ProjectService.instance.updateProject(
        projectId: widget.projectId,
        isOpenForRequests: value,
      );
      setState(() => _isOpenForRequests = value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget trailing;

  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
