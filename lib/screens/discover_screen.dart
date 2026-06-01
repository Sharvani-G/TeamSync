import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Discover'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(57),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search public projects...',
                prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<JoinRequest>>(
        stream: ProjectService.instance.watchMyJoinRequests(),
        builder: (context, requestSnapshot) {
          final requestStatusByProject = <String, String>{};
          for (final request in requestSnapshot.data ?? const <JoinRequest>[]) {
            if (request.projectId.isNotEmpty) {
              requestStatusByProject.putIfAbsent(request.projectId, () => request.status);
            }
          }

          return StreamBuilder<List<Project>>(
            stream: ProjectService.instance.watchPublicProjects(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }

              final projects = snapshot.data ?? const <Project>[];
              final filtered = projects
                  .where((project) =>
                      _query.isEmpty ||
                      project.title.toLowerCase().contains(_query.toLowerCase()) ||
                      project.description.toLowerCase().contains(_query.toLowerCase()))
                  .toList();

              if (filtered.isEmpty) {
                return const EmptyState(
                  icon: Icons.search_off,
                  title: 'No projects found',
                  subtitle: 'Try a different search term',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final project = filtered[index];
                  final isAccepting = project.isOpenToRequests &&
                      (project.currentCollaborators < project.collaboratorsRequired);
                  final requestStatus = requestStatusByProject[project.id];

                  return Card(
                    color: AppColors.kBgCard,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            project.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Members: ${project.currentCollaborators}/${project.collaboratorsRequired}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          if (project.requiredSkills.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Skills needed: ${project.requiredSkills.join(', ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            project.contactEmail.isNotEmpty
                                ? 'Contact: ${project.contactEmail}'
                                : 'Contact: unavailable',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 10),
                          _RequestToJoinButton(
                            key: ValueKey(project.id),
                            project: project,
                            isAccepting: isAccepting,
                            requestStatus: requestStatus,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestToJoinButton extends StatefulWidget {
  final Project project;
  final bool isAccepting;
  final String? requestStatus;

  const _RequestToJoinButton({
    super.key,
    required this.project,
    required this.isAccepting,
    required this.requestStatus,
  });

  @override
  State<_RequestToJoinButton> createState() => _RequestToJoinButtonState();
}

class _RequestToJoinButtonState extends State<_RequestToJoinButton> {
  bool _submitted = false;

  @override
  void didUpdateWidget(covariant _RequestToJoinButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _submitted = widget.requestStatus == 'pending';
  }

  Future<void> _requestToJoin() async {
    final project = widget.project;
    final messageController = TextEditingController();
    var isSending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (isSending) return;
              setSheetState(() => isSending = true);
              try {
                await ProjectService.instance.createJoinRequest(
                  projectId: project.id,
                  message: messageController.text.trim(),
                );
                _submitted = true;
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                if (!mounted) return;
                setState(() {});
              } catch (e) {
                if (!sheetContext.mounted) return;
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isSending = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.kBgCard,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.mail_outline, size: 20, color: AppTheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Request to join ${project.displayTitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: project.contactEmail.isEmpty
                            ? null
                            : () => launchUrl(
                                  Uri(scheme: 'mailto', path: project.contactEmail),
                                  mode: LaunchMode.externalApplication,
                                ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.kBgInput,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 18, color: AppTheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  project.contactEmail.isNotEmpty
                                      ? project.contactEmail
                                      : 'No contact email available',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.open_in_new, size: 16, color: AppTheme.textMuted),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: messageController,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: 'Message to admin (optional)',
                          counterText: '',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      Row(
                        children: [
                          const Spacer(),
                          Text(
                            '${messageController.text.length}/500',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSending ? null : () => Navigator.of(sheetContext).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'Cancel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSending ? null : submit,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: AppTheme.primary,
                                foregroundColor: AppTheme.textPrimary,
                              ),
                              child: isSending
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Send request',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.requestStatus == 'approved') {
      return _statusPill(
        color: const Color(0xFFE8F5E9),
        foreground: const Color(0xFF1B5E20),
        label: 'Joined',
      );
    }

    if (_submitted || widget.requestStatus == 'pending') {
      return _statusPill(
        color: const Color(0xFFFFF3CD),
        foreground: const Color(0xFF8A6D00),
        label: 'Waiting for approval',
      );
    }

    if (!widget.isAccepting) {
      return _statusPill(
        color: const Color(0xFFF1F5F9),
        foreground: AppTheme.textMuted,
        label: 'Not accepting requests',
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _requestToJoin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text(
          'Request to Join',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _statusPill({
    required Color color,
    required Color foreground,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
