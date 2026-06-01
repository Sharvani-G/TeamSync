import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

import '../models/models.dart';
import '../services/project_service.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  static final _cardColor = AppColors.kBgCard;
  static final _subtitleColor = AppColors.kTextSecond;

  static final _headerStyle = TextStyle(
    color: AppColors.kTextPrimary,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    fontFamily: 'Poppins',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.folder, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text('Project Buckets', style: _headerStyle),
                    ]),
                    TextButton.icon(
                      onPressed: () async {
                        // create project
                        if (!context.mounted) return;
                        Navigator.pushNamed(context, '/create-project');
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('New', style: TextStyle(color: Colors.white)),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                    )
                  ],
                ),
                const SizedBox(height: 6),
                const SizedBox(height: 12),

                // Projects grid
                StreamBuilder<List<Project>>(
                  stream: ProjectService.instance.watchMyProjects(),
                  builder: (context, snap) {
                    final projects = snap.data ?? <Project>[];
                    if (snap.hasError) return _errorBox('Error loading projects');
                    if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (projects.isEmpty) return _emptyBox('No projects yet');

                    // Responsive grid - 1..3 columns depending on width
                    return LayoutBuilder(builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final crossAxisCount = maxWidth > 1100 ? 3 : (maxWidth > 700 ? 2 : 1);
                      final itemWidth = (maxWidth - 16 * (crossAxisCount - 1)) / crossAxisCount;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: (itemWidth / 140),
                        ),
                        itemCount: projects.length,
                        itemBuilder: (c, i) {
                          final p = projects[i];
                          return _ProjectCard(project: p);
                        },
                      );
                    });
                  },
                ),

                const SizedBox(height: 24),
                const Text('Scheduled Meetings to Attend', style: _headerStyle),
                const SizedBox(height: 6),
                const Text('Upcoming calls and invites', style: TextStyle(color: _subtitleColor)),
                const SizedBox(height: 12),

                // Scheduled meetings from service
                SizedBox(
                  height: 160,
                  child: StreamBuilder<List<ProjectMeetingItem>>(
                    stream: ProjectService.instance.watchMyScheduledMeetings(),
                    builder: (context, snap) {
                      if (snap.hasError) return _errorBox('Error loading meetings');
                      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      final meetings = snap.data ?? const <ProjectMeetingItem>[];
                      if (meetings.isEmpty) return _emptyBox('No meetings scheduled');

                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: meetings.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (c, i) {
                          final m = meetings[i];
                          return SizedBox(
                            width: 360,
                            child: Container(
                              decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(backgroundColor: AppColors.kAccentMuted, child: const Icon(Icons.video_call, color: Colors.white)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          m.projectTitle,
                                          style: const TextStyle(color: AppColors.kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          DateFormat.yMMMd().add_jm().format(m.scheduledAt),
                                          style: TextStyle(color: _subtitleColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),
                const Text('Global Notifications', style: _headerStyle),
                const SizedBox(height: 6),
                const Text('Recent updates and alerts', style: TextStyle(color: _subtitleColor)),
                const SizedBox(height: 12),

                // Notifications constrained box
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: StreamBuilder<List<ProjectNotificationItem>>(
                    stream: ProjectService.instance.watchMyNotifications(),
                    builder: (context, snap) {
                      if (snap.hasError) return _errorBox('Error loading notifications');
                      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                      final items = snap.data ?? <ProjectNotificationItem>[];
                      if (items.isEmpty) return _emptyBox('No notifications');

                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (c, i) {
                          final n = items[i];
                          return _NotificationCard(item: n);
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyBox(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Text(message, style: const TextStyle(color: _subtitleColor)),
      );

  Widget _errorBox(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(12)),
        child: Text(message, style: const TextStyle(color: Colors.white)),
      );
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  const _ProjectCard({required this.project, super.key});

  @override
  Widget build(BuildContext context) {
    const cardColor = HomeDashboardScreen._cardColor;
    final created = DateFormat.yMMMd().format(project.createdAt);
    final progress = (project.progressValue).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        if (!context.mounted) return;
        Navigator.pushNamed(context, '/project/${project.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
        child: Stack(
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(project.displayTitle,
                      style: const TextStyle(color: AppColors.kTextPrimary, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Row(children: [
                  const Icon(Icons.person, size: 14, color: AppColors.kTextSecond),
                  const SizedBox(width: 4),
                  Text('${project.safeCollaboratorCount}', style: const TextStyle(color: AppColors.kTextSecond, fontSize: 12)),
                ])
              ]),
              const SizedBox(height: 6),
              Text(project.displayDescription, style: TextStyle(color: HomeDashboardScreen._subtitleColor), maxLines: 2, overflow: TextOverflow.ellipsis),
              if ((project.description).length > 120) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    if (!context.mounted) return;
                    Navigator.pushNamed(context, '/project/${project.id}');
                  },
                  child: Text('Show more', style: TextStyle(color: AppColors.kAccentLight, fontSize: 12)),
                ),
              ],
              const Spacer(),
              Text('Created • $created', style: TextStyle(color: HomeDashboardScreen._subtitleColor, fontSize: 12)),
            ]),

            // top-right progress ring
            Positioned(
              right: 0,
              top: 0,
              child: SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(
                  painter: _RingPainter(progress: progress),
                  child: Center(child: Text('${(progress * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 6;
    final bg = Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 6;
    final fg = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, bg);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

class _NotificationCard extends StatelessWidget {
  final ProjectNotificationItem item;
  const _NotificationCard({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    const cardColor = HomeDashboardScreen._cardColor;

    return GestureDetector(
      onTap: () async {
        await ProjectService.instance.markNotificationRead(item.id);
        if (!context.mounted) return;

        final projectId = item.data['projectId'] as String? ?? item.projectId;
        final channelId = item.data['channelId'] as String? ?? '';
        if (projectId.isNotEmpty && channelId.isNotEmpty) {
          Navigator.pushNamed(context, '/projects/$projectId/chat/$channelId');
          return;
        }

        final dynamic maybeLink = item.data['link'];
        if (maybeLink is String && maybeLink.isNotEmpty) {
          Navigator.pushNamed(context, maybeLink);
        }
      },
      child: Container(
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          // left icon
          CircleAvatar(backgroundColor: Colors.blue.shade700, child: const Icon(Icons.notifications, color: Colors.white)),
          const SizedBox(width: 12),
          // center text
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(item.body, style: TextStyle(color: HomeDashboardScreen._subtitleColor), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          // unread indicator
          if (item.read != true) Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
        ]),
      ),
    );
  }
}
