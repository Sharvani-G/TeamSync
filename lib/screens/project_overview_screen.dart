import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';
import 'project_admin_screen.dart';

class ProjectOverviewScreen extends StatelessWidget {
  final String projectId;
  const ProjectOverviewScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.kBgDeep,
            appBar: AppBar(backgroundColor: AppColors.kBgDeep, elevation: 0),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final project = snapshot.data;
        if (project == null) {
          return Scaffold(
            backgroundColor: AppColors.kBgDeep,
            appBar: AppBar(backgroundColor: AppColors.kBgDeep, elevation: 0),
            body: Center(child: Text('Project not found', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 16.sp))),
          );
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        final isAdmin = currentUser != null && project.isAdmin(currentUser.uid);
        final memberIds = <String>{project.createdBy, ...project.collaborators.keys}.toList();

        return Scaffold(
          backgroundColor: AppColors.kBgDeep,
          appBar: AppBar(
            backgroundColor: AppColors.kBgDeep,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: AppColors.kTextPrimary, size: 20.sp),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              project.title,
              style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600),
            ),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: Icon(Icons.settings, color: AppColors.kAccentLight, size: 22.sp),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProjectAdminScreen(
                          projectId: projectId,
                          project: project,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'Project Info'),
                SizedBox(height: 8.h),
                _InfoCard(
                  children: [
                    _InfoRow(label: 'Description', value: project.description),
                    const Divider(color: AppColors.kDivider, height: 1),
                    _InfoRow(label: 'Visibility', value: project.visibility.toUpperCase()),
                    const Divider(color: AppColors.kDivider, height: 1),
                    _InfoRow(label: 'Created On', value: _formatDate(project.createdAt)),
                  ],
                ),
                SizedBox(height: 24.h),
                _SectionHeader(title: 'Collaborators'),
                SizedBox(height: 8.h),
                FutureBuilder<Map<String, AppUser>>(
                  future: UserService.instance.getUsersByIds(memberIds),
                  builder: (context, memberSnapshot) {
                    final members = memberSnapshot.data ?? {};
                    return _InfoCard(
                      children: memberIds.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final userId = entry.value;
                        final user = members[userId];
                        final isOwner = project.isAdmin(userId);
                        final displayName = user?.name ?? 'Unknown User';
                        final isLast = idx == memberIds.length - 1;

                        return Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    name: displayName,
                                    username: user?.username,
                                    size: 32.r,
                                    imageUrl: user?.photoUrl,
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(displayName, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 15.sp, fontWeight: FontWeight.w500)),
                                        if (user?.username != null)
                                          Text('@${user!.username}', style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp)),
                                      ],
                                    ),
                                  ),
                                  if (isOwner)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                      decoration: BoxDecoration(color: AppColors.kBgElevated, borderRadius: BorderRadius.circular(4.r)),
                                      child: Text('ADMIN', style: TextStyle(color: AppColors.kAccentLight, fontSize: 10.sp, fontWeight: FontWeight.w600)),
                                    ),
                                ],
                              ),
                            ),
                            if (!isLast) const Divider(color: AppColors.kDivider, height: 1),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/project/$projectId/workspace'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kAccentBlue,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: Text(
                      'Open Project Workspace',
                      style: TextStyle(color: AppColors.kWhite, fontSize: 16.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp, fontWeight: FontWeight.w600),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.kBgCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.kDivider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.kTextSecond, fontSize: 12.sp)),
          SizedBox(height: 4.h),
          Text(value, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 15.sp)),
        ],
      ),
    );
  }
}
