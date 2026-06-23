import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';

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
    
    // Explicitly use your core data mapping to determine if the tab should render
    _isOpenForRequests = widget.project.isOpenForRequests;
    
    int initialIndex = 0;
    if (widget.initialTab == 'join_requests' && _isOpenForRequests) {
      initialIndex = 2; // Join Requests is at index 2
    }
    
    // Ensure the tab controller matches the total tabs rendered below
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
      hintStyle: TextStyle(color: AppColors.kTextHint),
      filled: true,
      fillColor: AppColors.kBgInput,
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.kAccentBlue, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const Tab(text: 'Edit Project'),
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
      backgroundColor: AppColors.kBgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.kBgDeep,
        elevation: 0,
        title: Text('Manage Project', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.kAccentLight,
          unselectedLabelColor: AppColors.kTextSecond,
          indicatorColor: AppColors.kAccentLight,
          tabs: tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabViews,
      ),
    );
  }

  Widget _buildEditProjectTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Project Name'),
          SizedBox(height: 8.h),
          TextField(controller: _nameController, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp), decoration: _inputDecoration('Name')),
          SizedBox(height: 20.h),
          _Label('Description'),
          SizedBox(height: 8.h),
          TextField(controller: _descController, minLines: 3, maxLines: null, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp), decoration: _inputDecoration('Description')),
          SizedBox(height: 20.h),
          _Label('Skills needed'),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(child: TextField(controller: _skillController, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp), decoration: _inputDecoration('Add skill'))),
              SizedBox(width: 8.w),
              ElevatedButton(onPressed: () {
                if (_skillController.text.isNotEmpty) {
                  setState(() {
                    _skills.add(_skillController.text.trim());
                    _skillController.clear();
                  });
                }
              }, child: const Text('Add')),
            ],
          ),
          Wrap(
            spacing: 8.w,
            children: _skills.map((s) => Chip(label: Text(s), onDeleted: () => setState(() => _skills.remove(s)))).toList(),
          ),
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                setState(() => _isLoading = true);
                try {
                  await ProjectService.instance.updateProjectDetails(
                    projectId: widget.projectId,
                    title: _nameController.text.trim(),
                    description: _descController.text.trim(),
                    requiredSkills: _skills,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project updated')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              child: _isLoading ? const CircularProgressIndicator() : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorsTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _collabUsernameController, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp), decoration: _inputDecoration('Enter username'))),
              SizedBox(width: 8.w),
              ElevatedButton(onPressed: () async {
                final username = _collabUsernameController.text.trim();
                if (username.isNotEmpty) {
                  try {
                    await ProjectService.instance.addCollaboratorByUsername(projectId: widget.projectId, collaboratorUsername: username);
                    _collabUsernameController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collaborator added')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              }, child: const Text('Add')),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<Project?>(
            stream: _projectStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final adminUid = snapshot.data!.createdBy;
              final collaborators = snapshot.data!.collaborators;
              final allUids = [
                adminUid,
                ...collaborators.keys.where((uid) => uid != adminUid),
              ];

              return ListView.builder(
                itemCount: allUids.length,
                itemBuilder: (context, index) {
                  final uid = allUids[index];
                  return FutureBuilder<AppUser?>(
                    future: UserService.instance.getUserById(uid),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData) return const ListTile(title: Text('Loading...'));
                      final user = userSnap.data!;
                      final isCreator = uid == adminUid;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.photoUrl.isNotEmpty
                              ? NetworkImage(user.photoUrl)
                              : null,
                          child: user.photoUrl.isEmpty
                              ? Text(user.username.isNotEmpty
                                  ? user.username[0].toUpperCase()
                                  : 'U')
                              : null,
                        ),
                        title: Text(
                          user.username.isNotEmpty ? '@${user.username}' : 'User',
                          style: const TextStyle(color: AppColors.kTextPrimary),
                        ),
                        subtitle: Text(
                          user.name,
                          style: const TextStyle(color: AppColors.kTextSecond),
                        ),
                        trailing: isCreator
                            ? Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: AppColors.kBgElevated,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.workspace_premium,
                                        color: Colors.amber, size: 14.sp),
                                    SizedBox(width: 4.w),
                                    Text(
                                      'Admin',
                                      style: TextStyle(
                                        color: AppColors.kAccentLight,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: AppColors.kDanger),
                                onPressed: () => _confirmRemoveCollaborator(uid),
                              ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRemoveCollaborator(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Collaborator'),
        content: const Text('Are you sure you want to remove this collaborator?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: AppColors.kDanger))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ProjectService.instance.removeCollaborator(projectId: widget.projectId, userId: uid);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    
    if (difference.inDays >= 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays >= 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays >= 7) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'just now';
    }
  }

  Widget _buildJoinRequestsTab() {
    return StreamBuilder<List<JoinRequest>>(
      stream: ProjectService.instance.watchPendingJoinRequests(widget.projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, color: AppColors.kTextHint, size: 48.sp),
                SizedBox(height: 12.h),
                const Text('No pending join requests', style: TextStyle(color: AppColors.kTextSecond)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            final requesterUsername = req.requestedByUsername.isNotEmpty ? '@${req.requestedByUsername}' : 'User';
            return Card(
              color: AppColors.kBgCard,
              margin: EdgeInsets.only(bottom: 12.h),
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(child: Text(req.requestedByName.isNotEmpty ? req.requestedByName[0] : 'U')),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(requesterUsername, style: const TextStyle(color: AppColors.kTextPrimary, fontWeight: FontWeight.bold)),
                              Text(req.requestedByName, style: const TextStyle(color: AppColors.kTextSecond)),
                              Text('Requested ${_timeAgo(req.createdAt)}', style: TextStyle(color: AppColors.kTextHint, fontSize: 12.sp)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (req.message.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Text(req.message, style: const TextStyle(color: AppColors.kTextPrimary)),
                    ],
                    SizedBox(height: 12.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            try {
                              await ProjectService.instance.rejectJoinRequest(req.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Request denied.')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.kDanger), foregroundColor: AppColors.kDanger),
                          child: const Text('Deny'),
                        ),
                        SizedBox(width: 8.w),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              await ProjectService.instance.acceptJoinRequest(req.id, projectId: widget.projectId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Request accepted. User added as collaborator.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.kSuccess),
                          child: const Text('Accept'),
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

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Visibility'),
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
                activeColor: AppColors.kAccentLight,
              ),
              const Text('Private', style: TextStyle(color: AppColors.kTextPrimary)),
              SizedBox(width: 20.w),
              Radio<String>(
                value: 'public',
                groupValue: _visibility,
                onChanged: (v) => setState(() => _visibility = v!),
                activeColor: AppColors.kAccentLight,
              ),
              const Text('Public', style: TextStyle(color: AppColors.kTextPrimary)),
            ],
          ),
          if (_visibility == 'public') ...[
            SwitchListTile(
              title: const Text('Open to join requests', style: TextStyle(color: AppColors.kTextPrimary)),
              value: _isOpenForRequests,
              onChanged: (v) {
                setState(() {
                  _isOpenForRequests = v;
                  _updateTabController();
                });
              },
              activeColor: AppColors.kAccentLight,
            ),
            if (_isOpenForRequests) ...[
              _Label('Collaborators required'),
              TextField(controller: _collabCountController, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.kTextPrimary)),
            ],
          ],
          SizedBox(height: 40.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await ProjectService.instance.updateProject(
                    projectId: widget.projectId,
                    visibility: _visibility,
                    isOpenForRequests: _isOpenForRequests,
                    requiredCollaborators: int.tryParse(_collabCountController.text) ?? 0,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Save Settings'),
            ),
          ),
          SizedBox(height: 20.h),
          const Divider(color: AppColors.kDivider),
          SizedBox(height: 20.h),
          Text('Danger Zone', style: TextStyle(color: AppColors.kDanger, fontWeight: FontWeight.bold, fontSize: 16.sp)),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmDeleteProject,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.kDanger),
              child: const Text('Delete Project', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteProject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text('Are you sure you want to delete this project? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.kDanger))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ProjectService.instance.deleteProject(widget.projectId);
        Navigator.pop(context); 
        Navigator.pop(context); 
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp, fontWeight: FontWeight.w600));
  }
}
