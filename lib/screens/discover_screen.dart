import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _query = '';
  late final Stream<List<JoinRequest>> _requestsStream;
  late final Stream<List<Project>> _projectsStream;

  @override
  void initState() {
    super.initState();
    _requestsStream = ProjectService.instance.watchMyJoinRequests();
    _projectsStream = ProjectService.instance.watchPublicProjects();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.kBgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.kBgDeep,
        elevation: 0,
        title: Text('Discover', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 20.sp, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: 'Search public projects...',
                hintStyle: TextStyle(color: AppColors.kTextHint),
                prefixIcon: Icon(Icons.search, color: AppColors.kTextHint, size: 20.sp),
                filled: true,
                fillColor: AppColors.kBgInput,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<JoinRequest>>(
              stream: _requestsStream,
              builder: (context, requestSnap) {
                final myRequests = requestSnap.data ?? [];
                final requestStatusMap = {for (var r in myRequests) r.projectId: r.status};

                return StreamBuilder<List<Project>>(
                  stream: _projectsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final projects = snapshot.data ?? [];
                    final filtered = projects.where((p) => p.title.toLowerCase().contains(_query.toLowerCase())).toList();

                    if (filtered.isEmpty) return Center(child: Text('No projects found', style: TextStyle(color: AppColors.kTextSecond, fontSize: 14.sp)));

                    return ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => SizedBox(height: 16.h),
                      itemBuilder: (context, index) {
                        final project = filtered[index];
                        return _DiscoverCard(
                          project: project,
                          currentUid: uid,
                          requestStatus: requestStatusMap[project.id],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  final Project project;
  final String currentUid;
  final String? requestStatus;

  const _DiscoverCard({required this.project, required this.currentUid, this.requestStatus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.kBgCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: TextStyle(
                        color: AppColors.kTextPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    FutureBuilder<AppUser?>(
                      future: UserService.instance.getUserById(project.createdBy),
                      builder: (context, userSnap) {
                        final adminName = userSnap.data?.name ?? 'Admin';
                        return Text(
                          'Created by: $adminName',
                          style: TextStyle(
                            color: AppColors.kTextSecond,
                            fontSize: 12.sp,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (project.requiredSkills.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 4.h,
              children: project.requiredSkills
                  .map((skill) => Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: AppColors.kBgElevated,
                          borderRadius: BorderRadius.circular(4.r),
                          border: Border.all(color: AppColors.kDivider),
                        ),
                        child: Text(
                          skill,
                          style: TextStyle(
                            color: AppColors.kAccentLight,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          SizedBox(height: 12.h),
          Text(
            project.description,
            style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${project.currentCollaborators}/${project.collaboratorsRequired} members',
                style: TextStyle(color: AppColors.kTextSecond, fontSize: 12.sp),
              ),
              _buildActionButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (project.createdBy == currentUid) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text(
          'Your Project',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 12.sp,
          ),
        ),
      );
    }

    if (project.collaborators.containsKey(currentUid) ||
        requestStatus == 'accepted' ||
        requestStatus == 'approved') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppColors.kSuccess.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text(
          'Member',
          style: TextStyle(
            color: AppColors.kSuccess,
            fontWeight: FontWeight.bold,
            fontSize: 12.sp,
          ),
        ),
      );
    }

    if (requestStatus == 'pending') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text(
          'Request Sent',
          style: TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: 12.sp,
          ),
        ),
      );
    }

    final isFull = project.currentCollaborators >= project.collaboratorsRequired;
    if (!project.isOpenForRequests || isFull) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text(
          'Not Accepting',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 12.sp,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => _showJoinRequestSheet(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.kAccentBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      ),
      child: Text(
        'Send Request',
        style: TextStyle(
          color: AppColors.kWhite,
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showJoinRequestSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.kBgDeep,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) => _JoinRequestSheet(project: project),
    );
  }
}

class _JoinRequestSheet extends StatefulWidget {
  final Project project;
  const _JoinRequestSheet({required this.project});

  @override
  State<_JoinRequestSheet> createState() => _JoinRequestSheetState();
}

class _JoinRequestSheetState extends State<_JoinRequestSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24.w, right: 24.w, top: 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Request to join ${widget.project.title}', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          Row(
            children: [
              Text('Contact admin: ', style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp)),
              InkWell(
                onTap: () => launchUrl(Uri.parse('mailto:${widget.project.contactEmail}')),
                child: Text(widget.project.contactEmail, style: TextStyle(color: AppColors.kAccentLight, fontSize: 13.sp, decoration: TextDecoration.underline)),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: 300,
            style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: 'Introduce yourself and why you want to join...',
              hintStyle: TextStyle(color: AppColors.kTextHint),
              filled: true,
              fillColor: AppColors.kBgInput,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
              counterStyle: TextStyle(color: AppColors.kTextSecond),
            ),
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: AppColors.kTextSecond)),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await ProjectService.instance.createJoinRequest(
                        projectId: widget.project.id,
                        message: _controller.text.trim(),
                      );
                      if (mounted) {
                        Navigator.pop(context);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Request sent! Waiting for admin approval.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.kAccentBlue),
                  child: Text('Send Request', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}
