import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import 'package:intl/intl.dart';

class ProjectAdminScreen extends StatefulWidget {
  final String projectId;
  final Project project;

  const ProjectAdminScreen({super.key, required this.projectId, required this.project});

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
  bool _isOpenToRequests = false;

  late Stream<Project?> _projectStream;

  @override
  void initState() {
    super.initState();
    _projectStream = ProjectService.instance.watchProject(widget.projectId);
    final hasRequests = widget.project.isOpenToRequests;
    _tabController = TabController(length: hasRequests ? 4 : 3, vsync: this);
    _nameController.text = widget.project.title;
    _descController.text = widget.project.description;
    _skills.addAll(widget.project.requiredSkills);
    _visibility = widget.project.visibility;
    _isOpenToRequests = widget.project.isOpenForRequests;
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

  Future<void> _saveEditProject() async {
    setState(() => _isLoading = true);
    try {
      await ProjectService.instance.updateProject(
        projectId: widget.projectId,
        // Assuming updateProject can also take name and description if needed,
        // but current signature in ProjectService doesn't have them.
        // I should probably update ProjectService.updateProject.
      );
      // Let's update ProjectService.updateProject first.
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          tabs: [
            Tab(text: 'Edit Project'),
            Tab(text: 'Collaborators'),
            if (widget.project.isOpenToRequests) Tab(text: 'Join Requests'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEditProjectTab(),
          _buildCollaboratorsTab(),
          if (widget.project.isOpenToRequests) _buildJoinRequestsTab(),
          _buildSettingsTab(),
        ],
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
              }, child: Text('Add')),
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
                  // I'll update ProjectService.updateProject below
                  await ProjectService.instance.updateProjectDetails(
                    projectId: widget.projectId,
                    title: _nameController.text.trim(),
                    description: _descController.text.trim(),
                    requiredSkills: _skills,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Project updated')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              child: _isLoading ? CircularProgressIndicator() : Text('Save Changes'),
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Collaborator added')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              }, child: Text('Add')),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<Project?>(
            stream: _projectStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              final collaborators = snapshot.data!.collaborators;
              final memberIds = collaborators.keys.where((id) => id != snapshot.data!.createdBy).toList();

              return ListView.builder(
                itemCount: memberIds.length,
                itemBuilder: (context, index) {
                  final uid = memberIds[index];
                  return FutureBuilder<AppUser?>(
                    future: UserService.instance.getUserById(uid),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData) return ListTile(title: Text('Loading...'));
                      final user = userSnap.data!;
                      return ListTile(
                        leading: CircleAvatar(backgroundImage: NetworkImage(user.photoUrl.isNotEmpty ? user.photoUrl : 'https://ui-avatars.com/api/?name=${user.name}')),
                        title: Text(user.name, style: TextStyle(color: AppColors.kTextPrimary)),
                        subtitle: Text('@${user.username}', style: TextStyle(color: AppColors.kTextSecond)),
                        trailing: IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: AppColors.kDanger),
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
        title: Text('Remove Collaborator'),
        content: Text('Are you sure you want to remove this collaborator?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Remove', style: TextStyle(color: AppColors.kDanger))),
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

  Widget _buildJoinRequestsTab() {
    return StreamBuilder<List<JoinRequest>>(
      stream: ProjectService.instance.watchPendingJoinRequests(widget.projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        final requests = snapshot.data ?? [];

        if (requests.isEmpty) return Center(child: Text('No pending requests', style: TextStyle(color: AppColors.kTextSecond)));

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
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
                        CircleAvatar(child: Text(req.requestedByName[0])),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(req.requestedByName, style: TextStyle(color: AppColors.kTextPrimary, fontWeight: FontWeight.bold)),
                              Text(DateFormat.yMMMd().format(req.createdAt), style: TextStyle(color: AppColors.kTextSecond, fontSize: 12.sp)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (req.message.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Text(req.message, style: TextStyle(color: AppColors.kTextPrimary)),
                    ],
                    SizedBox(height: 12.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => ProjectService.instance.rejectJoinRequest(req.id),
                          style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.kDanger), foregroundColor: AppColors.kDanger),
                          child: Text('Reject'),
                        ),
                        SizedBox(width: 8.w),
                        ElevatedButton(
                          onPressed: () => ProjectService.instance.acceptJoinRequest(req.id, projectId: widget.projectId),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.kSuccess),
                          child: Text('Approve'),
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
              Radio<String>(value: 'private', groupValue: _visibility, onChanged: (v) => setState(() => _visibility = v!), activeColor: AppColors.kAccentLight),
              Text('Private', style: TextStyle(color: AppColors.kTextPrimary)),
              SizedBox(width: 20.w),
              Radio<String>(value: 'public', groupValue: _visibility, onChanged: (v) => setState(() => _visibility = v!), activeColor: AppColors.kAccentLight),
              Text('Public', style: TextStyle(color: AppColors.kTextPrimary)),
            ],
          ),
          if (_visibility == 'public') ...[
            SwitchListTile(
              title: Text('Open to join requests', style: TextStyle(color: AppColors.kTextPrimary)),
              value: _isOpenToRequests,
              onChanged: (v) => setState(() => _isOpenToRequests = v),
              activeColor: AppColors.kAccentLight,
            ),
            if (_isOpenToRequests) ...[
              _Label('Collaborators required'),
              TextField(controller: _collabCountController, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.kTextPrimary)),
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
                    isOpenForRequests: _isOpenToRequests,
                    requiredCollaborators: int.tryParse(_collabCountController.text) ?? 0,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Settings saved')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: Text('Save Settings'),
            ),
          ),
          SizedBox(height: 20.h),
          Divider(color: AppColors.kDivider),
          SizedBox(height: 20.h),
          Text('Danger Zone', style: TextStyle(color: AppColors.kDanger, fontWeight: FontWeight.bold, fontSize: 16.sp)),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmDeleteProject,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.kDanger),
              child: Text('Delete Project', style: TextStyle(color: Colors.white)),
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
        title: Text('Delete Project'),
        content: Text('Are you sure you want to delete this project? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: TextStyle(color: AppColors.kDanger))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ProjectService.instance.deleteProject(widget.projectId);
        Navigator.pop(context); // Close Manage Project
        Navigator.pop(context); // Close Workspace
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
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
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp, fontWeight: FontWeight.w600));
  }
}
