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
                                request.requestedByEmail,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Requested',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
      (project.createdBy, 'Creator', true), // (userId, role, isAdmin)
      ...project.collaborators.entries.map((e) => (e.key, e.value, false)),
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
