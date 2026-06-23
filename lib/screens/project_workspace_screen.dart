import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_colors.dart';
import 'idea_board_screen.dart';
import 'chat_home_screen.dart';
import 'calls_screen.dart';

import 'project_admin_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProjectWorkspaceScreen extends StatefulWidget {
  final String projectId;
  final int initialTabIndex;

  const ProjectWorkspaceScreen({
    super.key,
    required this.projectId,
    this.initialTabIndex = 0,
  });

  @override
  State<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialTabIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChatHomeScreen(projectId: widget.projectId)),
          );
        }
      });
    } else if (widget.initialTabIndex == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CallsScreen(projectId: widget.projectId)),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(widget.projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.kBgDeep,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final project = snapshot.data;
        if (project == null) {
          return const Scaffold(
            backgroundColor: AppColors.kBgDeep,
            body: Center(child: Text('Project not found', style: TextStyle(color: AppColors.kTextPrimary))),
          );
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        final role = getMyRole(
          currentUid: currentUser?.uid ?? '',
          adminUid: project.createdBy,
          collaboratorUids: project.collaborators.keys.toList(),
        );
        final isAdmin = role == ProjectRole.admin;

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
              style: TextStyle(
                color: AppColors.kTextPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              if (isAdmin)
                IconButton(
                  tooltip: 'Manage project',
                  icon: Icon(Icons.settings, color: AppColors.kTextPrimary, size: 20.sp),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectAdminScreen(projectId: widget.projectId, project: project),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: [
                SizedBox(height: 32.h),
                _WorkspaceButton(
                  label: 'Idea Board',
                  icon: Icons.lightbulb_outline,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => IdeaBoardScreen(projectId: widget.projectId)),
                  ),
                ),
                SizedBox(height: 16.h),
                _WorkspaceButton(
                  label: 'Chat',
                  icon: Icons.chat_bubble_outline,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ChatHomeScreen(projectId: widget.projectId)),
                  ),
                ),
                SizedBox(height: 16.h),
                _WorkspaceButton(
                  label: 'Calls',
                  icon: Icons.call_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CallsScreen(projectId: widget.projectId)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _WorkspaceButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 85.h,
        decoration: BoxDecoration(
          color: AppColors.kBgElevated,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.kAccentMuted),
        ),
        child: Row(
          children: [
            SizedBox(width: 24.w),
            Icon(icon, size: 28.sp, color: AppColors.kAccentLight),
            SizedBox(width: 16.w),
            Text(
              label,
              style: TextStyle(
                color: AppColors.kTextPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
