import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../widgets/shared_widgets.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late final Stream<List<Project>> _projectsStream;
  late final Stream<List<ProjectMeetingItem>> _meetingsStream;

  @override
  void initState() {
    super.initState();
    _projectsStream = ProjectService.instance.watchMyProjects();
    _meetingsStream = ProjectService.instance.watchMyScheduledMeetings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Page Title
                    Text(
                      'TeamSync',
                      style: AppTheme.display2.copyWith(color: AppTheme.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Collaborative projects, tasks, and scheduled sessions',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.inkSecondary),
                    ),
                    const SizedBox(height: 28),

                    // Section 1: Project Buckets Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.dpInfoBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.folder_outlined,
                                color: AppTheme.accent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Project Buckets',
                              style: AppTheme.heading2,
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/create-project'),
                          icon: const Icon(Icons.add, size: 18, color: Colors.white),
                          label: const Text('New Project'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Projects List
                    StreamBuilder<List<Project>>(
                      stream: _projectsStream,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return _errorBox('Error loading projects: ${snap.error}');
                        }
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          );
                        }
                        final projects = snap.data ?? <Project>[];
                        if (projects.isEmpty) {
                          return const EmptyState(
                            icon: Icons.folder_open_outlined,
                            title: 'No projects yet',
                            subtitle: 'Create a new project or discover public teams to start collaborating.',
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: projects.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (c, i) => _DashboardProjectCard(project: projects[i]),
                        );
                      },
                    ),

                    const SizedBox(height: 36),

                    // Section 2: Scheduled Meetings Header
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.dpInfoBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.videocam_outlined,
                            color: AppTheme.accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Scheduled Meetings',
                          style: AppTheme.heading2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Meetings List
                    StreamBuilder<List<ProjectMeetingItem>>(
                      stream: _meetingsStream,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return _errorBox('Error loading meetings: ${snap.error}');
                        }
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          );
                        }
                        final meetings = snap.data ?? const <ProjectMeetingItem>[];
                        if (meetings.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                            decoration: BoxDecoration(
                              color: AppTheme.panel,
                              borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
                              border: Border.all(color: AppTheme.rule, width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_available, color: AppTheme.inkSecondary, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'No upcoming calls scheduled',
                                  style: AppTheme.bodySmall,
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: meetings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (c, i) {
                            return _ScheduledMeetingCard(meeting: meetings[i]);
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBox(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.dpDangerBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
          border: Border.all(color: AppColors.dpDanger.withOpacity(0.3)),
        ),
        child: Text(message, style: AppTheme.bodySmall.copyWith(color: AppColors.dpDanger)),
      );
}

class _ScheduledMeetingCard extends StatefulWidget {
  final ProjectMeetingItem meeting;
  const _ScheduledMeetingCard({required this.meeting});

  @override
  State<_ScheduledMeetingCard> createState() => _ScheduledMeetingCardState();
}

class _ScheduledMeetingCardState extends State<_ScheduledMeetingCard> {
  late final Stream<DocumentSnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.meeting.projectId)
        .collection('callSchedules')
        .doc(widget.meeting.id)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meeting;
    final now = DateTime.now();
    final meetingTime = m.scheduledAt;
    final enableAt = meetingTime.subtract(const Duration(minutes: 5));
    final disableAt = meetingTime.add(Duration(minutes: m.durationMinutes * 2));

    final bool canJoin = now.isAfter(enableAt) && now.isBefore(disableAt);
    final bool isUpcoming = now.isBefore(enableAt);
    final bool isExpired = now.isAfter(disableAt);

    return StreamBuilder<DocumentSnapshot>(
      stream: _stream,
      builder: (context, meetingSnap) {
        final meetingData = meetingSnap.data?.data() as Map<String, dynamic>?;
        final joinedUids = List<String>.from(meetingData?['joined_uids'] ?? m.joinedUids);

        return Container(
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: canJoin ? AppColors.dpSuccessBg : AppColors.dpInfoBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: canJoin ? AppColors.dpSuccess.withOpacity(0.3) : AppTheme.rule,
                  ),
                ),
                child: Icon(
                  Icons.videocam_outlined,
                  color: canJoin ? AppColors.dpSuccess : AppTheme.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      style: AppTheme.heading3.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.projectTitle,
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.inkSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: AppTheme.inkSecondary),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat.yMMMd().add_jm().format(m.scheduledAt),
                          style: AppTheme.metadataText.copyWith(fontSize: 11.5),
                        ),
                        if (isExpired) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${joinedUids.length} attended',
                            style: AppTheme.metadataText.copyWith(fontSize: 11.5),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isUpcoming)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.groundMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.rule),
                  ),
                  child: Text(
                    DateFormat.jm().format(m.scheduledAt),
                    style: AppTheme.labelText.copyWith(color: AppTheme.inkSecondary),
                  ),
                ),
              if (canJoin)
                ElevatedButton(
                  onPressed: () async {
                    await ProjectService.instance.joinScheduledMeeting(m.projectId, m.id);
                    if (context.mounted) {
                      Navigator.pushNamed(context, '/project/${m.projectId}/workspace/calls');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dpSuccess,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: const Text('Join Now', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              if (isExpired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.groundMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ended',
                    style: AppTheme.labelText.copyWith(color: AppTheme.inkSecondary),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardProjectCard extends StatefulWidget {
  final Project project;
  const _DashboardProjectCard({required this.project});

  @override
  State<_DashboardProjectCard> createState() => _DashboardProjectCardState();
}

class _DashboardProjectCardState extends State<_DashboardProjectCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasLongDescription = widget.project.displayDescription.length > 90;

    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/project/${widget.project.id}'),
      borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
      child: Container(
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
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.dpInfoBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.folder, color: AppTheme.accent, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.project.displayTitle,
                          style: AppTheme.heading3.copyWith(fontSize: 15.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.groundMuted,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.rule),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline, size: 12, color: AppTheme.inkSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.project.safeCollaboratorCount}',
                        style: AppTheme.labelText.copyWith(color: AppTheme.inkSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.project.displayDescription,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.inkSecondary, height: 1.45),
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (hasLongDescription)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _expanded ? 'Show less ▲' : 'Show more ▼',
                      style: AppTheme.labelText.copyWith(color: AppTheme.accent),
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
