import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
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
  int _selectedIndex = 0;

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
    final isOwner = FirebaseAuth.instance.currentUser?.uid == widget.project.createdBy;
    final tabs = <_AdminTabEntry>[
      if (isOwner)
        _AdminTabEntry(
          label: 'Join Requests',
          icon: Icons.mail,
          page: _JoinRequestsTab(projectId: widget.projectId, project: widget.project),
        ),
      _AdminTabEntry(
        label: 'Collaborators',
        icon: Icons.people,
        page: _CollaboratorsTab(projectId: widget.projectId, project: widget.project),
      ),
      _AdminTabEntry(
        label: 'Levels',
        icon: Icons.view_list,
        page: _LevelsTab(projectId: widget.projectId),
      ),
      _AdminTabEntry(
        label: 'Settings',
        icon: Icons.settings,
        page: _SettingsTab(projectId: widget.projectId, project: widget.project),
      ),
    ];

    return Scaffold(
      appBar: SimpleAppBar(title: 'Manage ${widget.project.title}'),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: tabs.map((tab) => tab.page).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: tabs
            .map(
              (tab) => BottomNavigationBarItem(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
        currentIndex: _selectedIndex.clamp(0, tabs.length - 1),
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        },
      ),
    );
  }
}

class _AdminTabEntry {
  final String label;
  final IconData icon;
  final Widget page;

  const _AdminTabEntry({
    required this.label,
    required this.icon,
    required this.page,
  });
}

class _JoinRequestsTab extends StatefulWidget {
  final String projectId;
  final Project project;

  const _JoinRequestsTab({
    required this.projectId,
    required this.project,
  });

  @override
  State<_JoinRequestsTab> createState() => _JoinRequestsTabState();
}

class _JoinRequestsTabState extends State<_JoinRequestsTab> {
  String? _expandedRequestId;
  String? _pendingApprovalRequestId;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != widget.project.createdBy) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<JoinRequest>>(
      stream: ProjectService.instance.watchPendingJoinRequests(widget.projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
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
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final request = requests[index];
            return FutureBuilder<AppUser?>(
              future: UserService.instance.getUserById(request.requestedBy),
              builder: (context, userSnapshot) {
                final user = userSnapshot.data;
                final displayName = user?.name.isNotEmpty == true ? user!.name : request.requestedByName;
                final username = user?.username.isNotEmpty == true ? user!.username : request.requestedByUsername;
                final initials = _initials(displayName.isNotEmpty ? displayName : username);
                final isExpanded = _expandedRequestId == request.id;
                final snippet = request.message.trim().isEmpty
                    ? 'No message provided.'
                    : request.message.trim();
                final relativeTime = _relativeTime(request.createdAt);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 21,
                              backgroundColor: AppTheme.primary.withOpacity(0.12),
                              child: Text(
                                initials,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '@$username',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          snippet.length > 80 ? '${snippet.substring(0, 80)}...' : snippet,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => setState(() {
                                          _expandedRequestId = isExpanded ? null : request.id;
                                        }),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          minimumSize: const Size(0, 30),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Read more',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isExpanded) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      request.message.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Sent ${DateFormat('MMM d, h:mm a').format(request.createdAt)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          relativeTime,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 20),
                        if (_pendingApprovalRequestId == request.id) ...[
                          Text(
                            'Approve $displayName as collaborator?',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => setState(() => _pendingApprovalRequestId = null),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _approveRequest(request.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text(
                                    'Confirm',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _confirmReject(context, request.id),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFB91C1C),
                                    side: const BorderSide(color: Color(0xFFB91C1C)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text(
                                    'Reject',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => setState(() => _pendingApprovalRequestId = request.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text(
                                    'Approve',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) {
      return 'Requested just now';
    }
    if (diff.inHours < 1) {
      return 'Requested ${diff.inMinutes} minutes ago';
    }
    if (diff.inDays < 1) {
      return 'Requested ${diff.inHours} hours ago';
    }
    return 'Requested ${diff.inDays} days ago';
  }

  String _initials(String source) {
    final clean = source.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final first = parts.first.substring(0, 1).toUpperCase();
    final last = parts.last.substring(0, 1).toUpperCase();
    return '$first$last';
  }

  Future<void> _approveRequest(String requestId) async {
    setState(() => _pendingApprovalRequestId = null);
    try {
      await ProjectService.instance.acceptJoinRequest(requestId, projectId: widget.projectId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request approved',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmReject(BuildContext context, String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deny request?'),
        content: const Text(
          'This will reject the join request immediately.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ProjectService.instance.rejectJoinRequest(requestId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request denied',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
    final collaboratorIds = <String>{project.createdBy, ...project.collaborators.keys}.toList();

    return FutureBuilder<Map<String, AppUser>>(
      future: UserService.instance.getUsersByIds(collaboratorIds),
      builder: (context, snapshot) {
        final users = snapshot.data ?? {};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Collaborators',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showAddCollaboratorDialog(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_alt_1, size: 15),
                      SizedBox(width: 5),
                      Text('Add'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...collaboratorIds.map((userId) {
              final user = users[userId];
              final isAdmin = project.isAdmin(userId) || project.collaborators[userId] == 'admin';
              final roleLabel = isAdmin ? 'ADMIN' : 'Collaborator';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      name: user?.name ?? user?.username ?? userId,
                      username: user?.username ?? userId,
                      size: 40,
                      imageUrl: user?.photoUrl,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? user?.username ?? 'Unknown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                                          '@${user?.username.isNotEmpty == true ? user!.username : '?'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                                  const SizedBox(width: 10),
                    Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isAdmin ? AppTheme.primary.withOpacity(0.12) : AppTheme.primaryLight.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        roleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isAdmin ? AppTheme.primary : AppTheme.primaryLight,
                        ),
                      ),
                    ),
                                  if (!isAdmin) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      onPressed: () => _confirmRemoveCollaborator(context, userId),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textMuted),
                                    ),
                                  ],
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _showAddCollaboratorDialog(BuildContext context) async {
    final controller = TextEditingController();
    bool makeAdmin = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Collaborator'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: makeAdmin,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Make admin'),
                    subtitle: const Text('Can manage collaborators, levels, and requests'),
                    onChanged: (value) {
                      setDialogState(() {
                        makeAdmin = value ?? false;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'username': controller.text.trim(),
                'makeAdmin': makeAdmin,
              }),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    final username = result?['username'] as String? ?? '';
    final grantAdmin = result?['makeAdmin'] as bool? ?? false;

    if (username.isEmpty) {
      return;
    }

    try {
      await ProjectService.instance.addCollaboratorByUsername(
        projectId: projectId,
        collaboratorUsername: username,
        makeAdmin: grantAdmin,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collaborator added'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _confirmRemoveCollaborator(BuildContext context, String userId) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove collaborator'),
          content: const Text('Choose whether to keep or delete their contributions.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'keep'),
              child: const Text('Remove only'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, 'delete'),
              child: const Text('Remove + delete contributions'),
            ),
          ],
        );
      },
    );

    if (choice == null) return;

    try {
      await ProjectService.instance.removeCollaborator(
        projectId: projectId,
        userId: userId,
        deleteContributions: choice == 'delete',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collaborator removed'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), behavior: SnackBarBehavior.floating),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only the project admin can modify levels. Changes sync instantly for everyone.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                final levelIndex = orderedLevels.indexOf(level);
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
                    title: Text(
                      level.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${level.percentage}% complete · ${level.completed ? 'Completed' : 'In progress'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up),
                          onPressed: levelIndex == 0 ? null : () => _moveLevel(level.id, true),
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down),
                          onPressed: levelIndex == orderedLevels.length - 1 ? null : () => _moveLevel(level.id, false),
                        ),
                        IconButton(
                          icon: const Icon(Icons.percent_outlined),
                          onPressed: () => _updateProgress(level),
                        ),
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

  Future<void> _updateProgress(ProjectLevel level) async {
    final percentageController = TextEditingController(text: level.percentage.toString());
    bool completed = level.completed;

    final result = await showDialog<_ProgressEditResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Progress'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: percentageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Percentage'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: completed,
                    onChanged: (value) => setDialogState(() => completed = value),
                    title: const Text('Mark completed'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final parsed = int.tryParse(percentageController.text.trim()) ?? 0;
                    Navigator.pop(
                      dialogContext,
                      _ProgressEditResult(percentage: parsed.clamp(0, 100), completed: completed),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    percentageController.dispose();

    if (result == null) {
      return;
    }

    try {
      await ProjectService.instance.updateProjectLevelProgress(
        projectId: widget.projectId,
        levelId: level.id,
        percentage: result.percentage,
        completed: result.completed,
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

  Future<void> _moveLevel(String levelId, bool moveUp) async {
    try {
      await ProjectService.instance.moveProjectLevel(
        projectId: widget.projectId,
        levelId: levelId,
        moveUp: moveUp,
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

class _ProgressEditResult {
  final int percentage;
  final bool completed;

  const _ProgressEditResult({required this.percentage, required this.completed});
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
