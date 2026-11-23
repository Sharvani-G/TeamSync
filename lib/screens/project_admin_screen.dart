import 'package:flutter/material.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';

class ProjectAdminScreen extends StatefulWidget {
  final String projectId;
  final Project project;
  final String? initialTab;

  const ProjectAdminScreen({super.key, required this.projectId, required this.project, this.initialTab});

  @override
  State<ProjectAdminScreen> createState() => _ProjectAdminScreenState();
}

class _ProjectAdminScreenState extends State<ProjectAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _skillController = TextEditingController();
  final _collabUsernameController = TextEditingController();
  final _collabCountController = TextEditingController();

  final List<String> _skills = [];
  bool _isLoading = false;
  String _visibility = 'private';
  bool _isOpenForRequests = false;

  late Stream<Project?> _projectStream;

  void _updateTabController() {
    final int targetLength = _isOpenForRequests ? 4 : 3;
    if (_tabController.length != targetLength) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: targetLength,
        vsync: this,
        initialIndex: oldIndex.clamp(0, targetLength - 1),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _projectStream = ProjectService.instance.watchProject(widget.projectId);
    
    _isOpenForRequests = widget.project.isOpenForRequests;
    
    int initialIndex = 0;
    if (widget.initialTab == 'join_requests' && _isOpenForRequests) {
      initialIndex = 2;
    }
    
    _tabController = TabController(length: _isOpenForRequests ? 4 : 3, vsync: this, initialIndex: initialIndex);
    
    _nameController.text = widget.project.title;
    _descController.text = widget.project.description;
    _skills.addAll(widget.project.requiredSkills);
    _visibility = widget.project.visibility;
    _collabCountController.text = widget.project.requiredCollaborators.toString();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _skillController.dispose();
    _collabUsernameController.dispose();
    _collabCountController.dispose();
    super.dispose();
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
        borderSide: const BorderSide(color: AppTheme.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const Tab(text: 'Edit Details'),
      const Tab(text: 'Collaborators'),
      if (_isOpenForRequests) const Tab(text: 'Join Requests'),
      const Tab(text: 'Settings'),
    ];

    final tabViews = [
      _buildEditProjectTab(),
      _buildCollaboratorsTab(),
      if (_isOpenForRequests) _buildJoinRequestsTab(),
      _buildSettingsTab(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: AppBar(
        title: Text('Project Administration', style: AppTheme.heading2),
        backgroundColor: AppTheme.panel,
        foregroundColor: AppTheme.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppTheme.ink),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.rule, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.inkSecondary,
              labelStyle: AppTheme.labelText.copyWith(fontWeight: FontWeight.w700),
              unselectedLabelStyle: AppTheme.labelText.copyWith(fontWeight: FontWeight.w500),
              indicatorColor: AppTheme.accent,
              indicatorWeight: 2.5,
              tabs: tabs,
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: TabBarView(
            controller: _tabController,
            children: tabViews,
          ),
        ),
      ),
    );
  }

  Widget _buildEditProjectTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                _Label('Project Name'),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                  decoration: _inputDecoration('Project title'),
                ),
                const SizedBox(height: 18),
                _Label('Project Description'),
                const SizedBox(height: 6),
                TextField(
                  controller: _descController,
                  minLines: 3,
                  maxLines: null,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                  decoration: _inputDecoration('Project description and objectives'),
                ),
                const SizedBox(height: 18),
                _Label('Required Skills'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _skillController,
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                        decoration: _inputDecoration('Add a skill or role (e.g. Flutter)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        if (_skillController.text.trim().isNotEmpty) {
                          setState(() {
                            _skills.add(_skillController.text.trim());
                            _skillController.clear();
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
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
                        .map(
                          (s) => Chip(
                            label: Text(s, style: AppTheme.labelText.copyWith(color: AppTheme.ink)),
                            backgroundColor: AppTheme.groundMuted,
                            side: const BorderSide(color: AppTheme.rule),
                            deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.inkSecondary),
                            onDeleted: () => setState(() => _skills.remove(s)),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() => _isLoading = true);
                      try {
                        await ProjectService.instance.updateProjectDetails(
                          projectId: widget.projectId,
                          title: _nameController.text.trim(),
                          description: _descController.text.trim(),
                          requiredSkills: _skills,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Project details updated successfully!'),
                              backgroundColor: AppColors.dpSuccess,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.dpDanger),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _collabUsernameController,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                  decoration: _inputDecoration('Enter username to invite').copyWith(
                    prefixIcon: const Icon(Icons.alternate_email, size: 18, color: AppTheme.inkSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () async {
                  final username = _collabUsernameController.text.trim();
                  if (username.isNotEmpty) {
                    try {
                      await ProjectService.instance.addCollaboratorByUsername(
                        projectId: widget.projectId,
                        collaboratorUsername: username,
                      );
                      _collabUsernameController.clear();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Collaborator added!'), backgroundColor: AppColors.dpSuccess),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.dpDanger),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                ),
                child: const Text('Add User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: StreamBuilder<Project?>(
              stream: _projectStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                final adminUid = snapshot.data!.createdBy;
                final collaborators = snapshot.data!.collaborators;
                final allUids = [
                  adminUid,
                  ...collaborators.keys.where((uid) => uid != adminUid),
                ];

                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.panel,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
                    border: Border.all(color: AppTheme.rule, width: AppTheme.borderHairline),
                  ),
                  child: ListView.separated(
                    itemCount: allUids.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.rule),
                    itemBuilder: (context, index) {
                      final uid = allUids[index];
                      return FutureBuilder<AppUser?>(
                        future: UserService.instance.getUserById(uid),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData) {
                            return const ListTile(title: Text('Loading user...'));
                          }
                          final user = userSnap.data!;
                          final isCreator = uid == adminUid;

                          return ListTile(
                            leading: UserAvatar(name: user.name, username: user.username, size: 36),
                            title: Text(
                              user.name.isNotEmpty ? user.name : user.username,
                              style: AppTheme.heading3.copyWith(fontSize: 14.5),
                            ),
                            subtitle: user.username.isNotEmpty
                                ? Text('@${user.username}', style: AppTheme.metadataText)
                                : null,
                            trailing: isCreator
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.dpInfoBg,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      'Owner / Admin',
                                      style: AppTheme.labelText.copyWith(color: AppTheme.accent, fontSize: 10.5),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.dpDanger, size: 20),
                                    tooltip: 'Remove collaborator',
                                    onPressed: () => _confirmRemoveCollaborator(uid),
                                  ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveCollaborator(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Collaborator'),
        content: const Text('Are you sure you want to remove this collaborator from the project?'),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dpDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ProjectService.instance.removeCollaborator(projectId: widget.projectId, userId: uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Collaborator removed'), backgroundColor: AppColors.dpSuccess),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.dpDanger),
          );
        }
      }
    }
  }

  Widget _buildJoinRequestsTab() {
    return StreamBuilder<List<JoinRequest>>(
      stream: ProjectService.instance.watchPendingJoinRequests(widget.projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
        }
        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No Pending Join Requests',
            subtitle: 'When other users request to join this public project, their requests will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final req = requests[index];
            final requesterUsername =
                req.requestedByUsername.isNotEmpty ? '@${req.requestedByUsername}' : 'User';

            return Container(
              padding: const EdgeInsets.all(16),
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
                  Row(
                    children: [
                      UserAvatar(name: req.requestedByName, username: req.requestedByUsername, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(req.requestedByName, style: AppTheme.heading3.copyWith(fontSize: 14.5)),
                            Text(requesterUsername, style: AppTheme.metadataText),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.dpWarningBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.dpWarning.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Pending',
                          style: AppTheme.labelText.copyWith(color: AppColors.dpWarning, fontSize: 10.5),
                        ),
                      ),
                    ],
                  ),
                  if (req.message.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.groundMuted,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Text(
                        req.message,
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.ink, height: 1.4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          try {
                            await ProjectService.instance.rejectJoinRequest(req.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Join request declined.')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.dpDanger,
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                        ),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await ProjectService.instance.acceptJoinRequest(req.id, projectId: widget.projectId);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Request approved! User added as collaborator.'),
                                  backgroundColor: AppColors.dpSuccess,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.dpSuccess,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Approve & Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
              border: Border.all(color: AppTheme.rule, width: AppTheme.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label('Visibility'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Radio<String>(
                      value: 'private',
                      groupValue: _visibility,
                      onChanged: (v) => setState(() {
                        _visibility = v!;
                        _isOpenForRequests = false;
                        _updateTabController();
                      }),
                      activeColor: AppTheme.accent,
                    ),
                    Text('Private', style: AppTheme.bodySmall.copyWith(color: AppTheme.ink)),
                    const SizedBox(width: 20),
                    Radio<String>(
                      value: 'public',
                      groupValue: _visibility,
                      onChanged: (v) => setState(() => _visibility = v!),
                      activeColor: AppTheme.accent,
                    ),
                    Text('Public', style: AppTheme.bodySmall.copyWith(color: AppTheme.ink)),
                  ],
                ),
                if (_visibility == 'public') ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Open to Join Requests', style: AppTheme.heading3.copyWith(fontSize: 14)),
                    subtitle: Text('Allow members to request access on Discover', style: AppTheme.metadataText),
                    value: _isOpenForRequests,
                    onChanged: (v) {
                      setState(() {
                        _isOpenForRequests = v;
                        _updateTabController();
                      });
                    },
                    activeColor: AppTheme.accent,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_isOpenForRequests) ...[
                    const SizedBox(height: 10),
                    _Label('Collaborators Required'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _collabCountController,
                      keyboardType: TextInputType.number,
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                      decoration: _inputDecoration('Number of collaborators needed'),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await ProjectService.instance.updateProject(
                          projectId: widget.projectId,
                          visibility: _visibility,
                          isOpenForRequests: _isOpenForRequests,
                          requiredCollaborators: int.tryParse(_collabCountController.text) ?? 0,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: AppColors.dpSuccess),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Danger Zone
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.dpDangerBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
              border: Border.all(color: AppColors.dpDanger.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.dpDanger, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Danger Zone',
                      style: AppTheme.heading3.copyWith(color: AppColors.dpDanger, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Deleting a project permanently deletes its idea boards, channels, messages, and calls. This action cannot be reversed.',
                  style: AppTheme.bodySmall.copyWith(color: AppColors.dpDanger, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _confirmDeleteProject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dpDanger,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Permanently Delete Project'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteProject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text(
          'Are you sure you want to permanently delete this project? All associated ideas, channels, and records will be deleted.',
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dpDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ProjectService.instance.deleteProject(widget.projectId);
        if (mounted) {
          Navigator.pop(context);
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.labelText.copyWith(fontWeight: FontWeight.w700, color: AppTheme.ink),
    );
  }
}
