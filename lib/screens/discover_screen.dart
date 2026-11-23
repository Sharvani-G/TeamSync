import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

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
      backgroundColor: AppTheme.ground,
      appBar: const SimpleAppBar(
        title: 'Discover',
        showBack: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                  decoration: InputDecoration(
                    hintText: 'Search public projects by title...',
                    hintStyle: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.inkSecondary, size: 20),
                    filled: true,
                    fillColor: AppTheme.panel,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: const BorderSide(color: AppTheme.rule, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: const BorderSide(color: AppTheme.rule, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                    ),
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
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
                        }
                        final projects = snapshot.data ?? [];
                        final filtered = projects
                            .where((p) => p.title.toLowerCase().contains(_query.toLowerCase()))
                            .toList();

                        if (filtered.isEmpty) {
                          return const EmptyState(
                            icon: Icons.search_off_outlined,
                            title: 'No public projects found',
                            subtitle: 'Try a different search keyword or check back later.',
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
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
        ),
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  final Project project;
  final String currentUid;
  final String? requestStatus;

  const _DiscoverCard({
    required this.project,
    required this.currentUid,
    this.requestStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: AppTheme.heading3.copyWith(fontSize: 16.5),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<AppUser?>(
                      future: UserService.instance.getUserById(project.createdBy),
                      builder: (context, userSnap) {
                        final adminName = userSnap.data?.name ?? 'Admin';
                        return Text(
                          'Created by $adminName',
                          style: AppTheme.metadataText,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (project.requiredSkills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: project.requiredSkills
                  .map(
                    (skill) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.groundMuted,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: AppTheme.rule),
                      ),
                      child: Text(
                        skill,
                        style: AppTheme.labelText.copyWith(
                          color: AppTheme.inkSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            project.description,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.inkSecondary, height: 1.45),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.group_outlined, size: 16, color: AppTheme.inkSecondary),
                  const SizedBox(width: 5),
                  Text(
                    '${project.currentCollaborators}/${project.collaboratorsRequired} members',
                    style: AppTheme.metadataText,
                  ),
                ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.groundMuted,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.rule),
        ),
        child: Text(
          'Your Project',
          style: AppTheme.labelText.copyWith(color: AppTheme.inkSecondary),
        ),
      );
    }

    if (project.collaborators.containsKey(currentUid) ||
        requestStatus == 'accepted' ||
        requestStatus == 'approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.dpSuccessBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppColors.dpSuccess.withOpacity(0.3)),
        ),
        child: Text(
          'Member',
          style: AppTheme.labelText.copyWith(color: AppColors.dpSuccess),
        ),
      );
    }

    if (requestStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.dpWarningBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppColors.dpWarning.withOpacity(0.3)),
        ),
        child: Text(
          'Request Pending',
          style: AppTheme.labelText.copyWith(color: AppColors.dpWarning),
        ),
      );
    }

    final isFull = project.currentCollaborators >= project.collaboratorsRequired;
    if (!project.isOpenForRequests || isFull) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.groundMuted,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.rule),
        ),
        child: Text(
          'Closed to Requests',
          style: AppTheme.labelText.copyWith(color: AppTheme.inkSecondary),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => _showJoinRequestSheet(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: const Text(
        'Request to Join',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
      ),
    );
  }

  void _showJoinRequestSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.rule,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Request to Join',
            style: AppTheme.heading2,
          ),
          const SizedBox(height: 4),
          Text(
            widget.project.title,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.inkSecondary),
          ),
          const SizedBox(height: 12),
          if (widget.project.contactEmail.isNotEmpty)
            Row(
              children: [
                Text('Admin Contact: ', style: AppTheme.metadataText),
                Flexible(
                  child: InkWell(
                    onTap: () => launchUrl(Uri.parse('mailto:${widget.project.contactEmail}')),
                    child: Text(
                      widget.project.contactEmail,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.metadataText.copyWith(
                        color: AppTheme.accent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: 300,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
            decoration: InputDecoration(
              hintText: 'Introduce yourself, relevant skills, and why you would like to collaborate...',
              hintStyle: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.groundMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.rule, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.rule, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
              ),
              counterStyle: AppTheme.metadataText.copyWith(fontSize: 11),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          setState(() => _isSubmitting = true);
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
                                content: Text('Request sent successfully! Awaiting admin approval.'),
                                backgroundColor: AppColors.dpSuccess,
                              ),
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to submit request: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isSubmitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
