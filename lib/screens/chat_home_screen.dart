import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import 'chat_channel_screen.dart';

class ChatHomeScreen extends StatelessWidget {
  final String projectId;
  const ChatHomeScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(projectId),
      builder: (context, snapshot) {
        final project = snapshot.data;
        if (project == null) return const Scaffold(backgroundColor: AppColors.kBgDeep, body: Center(child: CircularProgressIndicator()));

        final currentUser = FirebaseAuth.instance.currentUser;
        final isAdmin = project.isAdmin(currentUser?.uid ?? '');

        return Scaffold(
          backgroundColor: AppColors.kBgDeep,
          appBar: AppBar(
            backgroundColor: AppColors.kBgDeep,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: AppColors.kTextPrimary, size: 20.sp),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(project.title, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600)),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ProjectChannel>>(
                  stream: ProjectService.instance.watchProjectChannels(projectId),
                  builder: (context, chSnap) {
                    final channels = chSnap.data ?? [];
                    if (channels.isEmpty && chSnap.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    return ListView.separated(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      itemCount: channels.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.kDivider, height: 1),
                      itemBuilder: (context, index) {
                        final ch = channels[index];
                        return ListTile(
                          leading: Icon(Icons.tag, color: AppColors.kAccentLight, size: 20.sp),
                          title: Text(
                            ch.name.startsWith('#') ? ch.name.substring(1) : ch.name,
                            style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                          ),
                          trailing: Icon(Icons.chevron_right, color: AppColors.kTextSecond, size: 20.sp),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatChannelScreen(projectId: projectId, channelId: ch.id))),
                        );
                      },
                    );
                  },
                ),
              ),
              if (isAdmin)
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showCreateChannelDialog(context, project),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kAccentBlue,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      ),
                      child: Text('Create Channel', style: TextStyle(color: AppColors.kWhite, fontSize: 14.sp, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  void _showCreateChannelDialog(BuildContext context, Project project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.kBgDeep,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) => _CreateChannelSheet(projectId: projectId, project: project),
    );
  }
}

class _CreateChannelSheet extends StatefulWidget {
  final String projectId;
  final Project project;
  const _CreateChannelSheet({required this.projectId, required this.project});

  @override
  State<_CreateChannelSheet> createState() => _CreateChannelSheetState();
}

class _CreateChannelSheetState extends State<_CreateChannelSheet> {
  final _controller = TextEditingController();
  final Map<String, bool> _selectedMembers = {};
  List<AppUser> _collaborators = [];
  bool _isLoadingCollabs = true;

  @override
  void initState() {
    super.initState();
    _loadCollaborators();
  }

  Future<void> _loadCollaborators() async {
    final memberIds = widget.project.collaborators.keys.toList();
    if (!memberIds.contains(widget.project.createdBy)) memberIds.add(widget.project.createdBy);

    // Exclude admin from checkboxes (always added)
    memberIds.remove(widget.project.createdBy);

    try {
      final users = await UserService.instance.getUsersByIds(memberIds);
      if (mounted) {
        setState(() {
          _collaborators = users.values.toList();
          for (var u in _collaborators) {
            _selectedMembers[u.id] = true;
          }
          _isLoadingCollabs = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCollabs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24.w, right: 24.w, top: 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create New Channel', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 16.h),
          TextField(
            controller: _controller,
            style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: 'e.g. general, idea-space',
              hintStyle: TextStyle(color: AppColors.kTextHint),
              filled: true,
              fillColor: AppColors.kBgInput,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: BorderSide.none),
            ),
          ),
          SizedBox(height: 24.h),
          Text('Add collaborators to this channel', style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          if (_isLoadingCollabs)
            Center(child: CircularProgressIndicator())
          else if (_collaborators.isEmpty)
            Text('No collaborators to add', style: TextStyle(color: AppColors.kTextHint, fontSize: 12.sp))
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 200.h),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _collaborators.length,
                itemBuilder: (context, index) {
                  final user = _collaborators[index];
                  return CheckboxListTile(
                    title: Text(user.name, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp)),
                    value: _selectedMembers[user.id],
                    onChanged: (v) => setState(() => _selectedMembers[user.id] = v!),
                    activeColor: AppColors.kAccentLight,
                    checkColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final name = _controller.text.trim();
                if (name.isNotEmpty) {
                  final memberUids = _selectedMembers.entries.where((e) => e.value).map((e) => e.key).toList();
                  // Admin is always a member
                  if (!memberUids.contains(widget.project.createdBy)) memberUids.add(widget.project.createdBy);

                  await ProjectService.instance.createChannel(
                    projectId: widget.projectId,
                    name: name,
                    invitedMembers: memberUids,
                    isPrivate: true, // If we filter by members, it's effectively private
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kAccentBlue,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              child: Text('Create Channel', style: TextStyle(color: AppColors.kWhite, fontSize: 14.sp, fontWeight: FontWeight.w500)),
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}
