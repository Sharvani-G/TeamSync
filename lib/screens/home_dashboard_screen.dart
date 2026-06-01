import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import '../services/project_service.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgDeep,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 20.h, left: 16.w, bottom: 8.h),
                child: Text(
                  'TeamSync',
                  style: TextStyle(
                    color: AppColors.kTextPrimary,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.folder_open, color: AppColors.kAccentLight, size: 20.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'Project Buckets',
                              style: TextStyle(
                                color: AppColors.kTextPrimary,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/create-project'),
                          icon: const Icon(Icons.add, color: AppColors.kWhite),
                          label: const Text('New', style: TextStyle(color: AppColors.kWhite)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.kAccentBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // Projects List
                    StreamBuilder<List<Project>>(
                      stream: ProjectService.instance.watchMyProjects(),
                      builder: (context, snap) {
                        if (snap.hasError) return _errorBox('Error loading projects');
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final projects = snap.data ?? <Project>[];
                        if (projects.isEmpty) return _emptyBox('No projects yet');

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: projects.length,
                          separatorBuilder: (_, __) => SizedBox(height: 16.h),
                          itemBuilder: (c, i) => _ProjectCard(project: projects[i]),
                        );
                      },
                    ),

                    SizedBox(height: 32.h),
                    Text(
                      'Scheduled Meetings',
                      style: TextStyle(
                        color: AppColors.kTextPrimary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    StreamBuilder<List<ProjectMeetingItem>>(
                      stream: ProjectService.instance.watchMyScheduledMeetings(),
                      builder: (context, snap) {
                        if (snap.hasError) return _errorBox('Error loading meetings');
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final meetings = snap.data ?? const <ProjectMeetingItem>[];
                        if (meetings.isEmpty) {
                          return Center(
                            child: Text(
                              "No meetings scheduled",
                              style: TextStyle(color: AppColors.kTextHint, fontSize: 14.sp),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: meetings.length,
                          separatorBuilder: (_, __) => SizedBox(height: 12.h),
                          itemBuilder: (c, i) {
                            final m = meetings[i];
                            final now = DateTime.now();
                            final meetingTime = m.scheduledAt;
                            final windowEnd = meetingTime.add(Duration(minutes: m.durationMinutes * 2));

                            final bool canJoin = now.isAfter(meetingTime) && now.isBefore(windowEnd);
                            final bool isUpcoming = now.isBefore(meetingTime);
                            final bool isExpired = now.isAfter(windowEnd);

                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(m.projectId)
                                  .collection('callSchedules')
                                  .doc(m.id)
                                  .snapshots(),
                              builder: (context, meetingSnap) {
                                final meetingData = meetingSnap.data?.data() as Map<String, dynamic>?;
                                final joinedUids = List<String>.from(meetingData?['joined_uids'] ?? []);

                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.kBgCard,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  padding: EdgeInsets.all(16.w),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.kBgElevated,
                                        child: Icon(Icons.video_call, color: AppColors.kAccentLight),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m.title,
                                              style: TextStyle(
                                                color: AppColors.kTextPrimary,
                                                fontSize: 15.sp,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              m.projectTitle,
                                              style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              DateFormat.yMMMd().add_jm().format(m.scheduledAt),
                                              style: TextStyle(color: AppColors.kTextSecond.withValues(alpha: 0.7), fontSize: 11.sp),
                                            ),
                                            if (isExpired) ...[
                                              SizedBox(height: 4.h),
                                              Text(
                                                '${joinedUids.length} collaborator(s) joined',
                                                style: TextStyle(color: AppColors.kAccentLight, fontSize: 11.sp, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (isUpcoming)
                                        ElevatedButton(
                                          onPressed: null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey.shade800,
                                            disabledBackgroundColor: Colors.grey.shade800,
                                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                          ),
                                          child: Text('Join at ${DateFormat.jm().format(m.scheduledAt)}', style: TextStyle(color: Colors.white38, fontSize: 10.sp)),
                                        ),
                                      if (canJoin)
                                        ElevatedButton(
                                          onPressed: () async {
                                            await ProjectService.instance.joinScheduledMeeting(m.projectId, m.id);
                                            if (c.mounted) {
                                              Navigator.pushNamed(c, '/project/${m.projectId}/workspace/calls');
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                          ),
                                          child: Text('Join Now', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                                        ),
                                      if (isExpired)
                                        Text('Ended', style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),

                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyBox(String message) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        child: Center(
          child: Text(message, style: TextStyle(color: AppColors.kTextSecond, fontSize: 14.sp)),
        ),
      );

  Widget _errorBox(String message) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(color: AppColors.kDanger.withOpacity(0.1), borderRadius: BorderRadius.circular(12.r)),
        child: Text(message, style: TextStyle(color: AppColors.kDanger, fontSize: 14.sp)),
      );
}

class _ProjectCard extends StatefulWidget {
  final Project project;
  const _ProjectCard({required this.project});

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasLongDescription = widget.project.displayDescription.length > 100; // Simplified check

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/project/${widget.project.id}'),
      child: Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder, color: AppColors.kAccentLight, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      widget.project.displayTitle,
                      style: TextStyle(
                        color: AppColors.kTextPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  '👥 ${widget.project.safeCollaboratorCount} collaborators',
                  style: TextStyle(color: AppColors.kTextSecond, fontSize: 12.sp),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              widget.project.displayDescription,
              style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp),
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (hasLongDescription)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      _expanded ? 'Show less ▲' : 'Show more ▼',
                      style: TextStyle(color: AppColors.kAccentLight, fontSize: 12.sp),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
