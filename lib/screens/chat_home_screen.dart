import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';
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
        if (project == null) {
          return const Scaffold(
            backgroundColor: AppTheme.ground,
            body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        final isAdmin = project.isAdmin(currentUser?.uid ?? '');

        return Scaffold(
          backgroundColor: AppTheme.ground,
          appBar: SimpleAppBar(
            title: '${project.title} • Channels',
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<List<ProjectChannel>>(
                      stream: ProjectService.instance.watchProjectChannels(projectId),
                      builder: (context, chSnap) {
                        final channels = chSnap.data ?? [];
                        if (channels.isEmpty && chSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
                        }
                        if (channels.isEmpty) {
                          return EmptyState(
                            icon: Icons.chat_bubble_outline,
                            title: 'No channels yet',
                            subtitle: isAdmin
                                ? 'Create your first communication channel to get started.'
                                : 'No channels have been created for this project yet.',
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          itemCount: channels.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final ch = channels[index];
                            final cleanName = ch.name.startsWith('#') ? ch.name.substring(1) : ch.name;

                            return InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatChannelScreen(
                                    projectId: projectId,
                                    channelId: ch.id,
                                  ),
                                ),
                              ),
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
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.dpInfoBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '#',
                                          style: TextStyle(
                                            color: AppTheme.accent,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cleanName,
                                            style: AppTheme.heading3.copyWith(fontSize: 15),
                                          ),
                                          if (ch.isPrivate)
                                            Text(
                                              'Private channel • ${ch.members.length} members',
                                              style: AppTheme.metadataText,
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: AppTheme.inkSecondary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (isAdmin)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => _showCreateChannelDialog(context, project),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Create New Channel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreateChannelDialog(BuildContext context, Project project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadCollaborators();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCollaborators() async {
    final memberIds = widget.project.collaborators.keys.toList();
    if (!memberIds.contains(widget.project.createdBy)) memberIds.add(widget.project.createdBy);

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
          Text('Create New Channel', style: AppTheme.heading2),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
            decoration: InputDecoration(
              hintText: 'e.g. general, announcements, dev-talk',
              hintStyle: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.tag, size: 20, color: AppTheme.inkSecondary),
              filled: true,
              fillColor: AppTheme.groundMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.rule),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.rule),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Channel Members',
            style: AppTheme.labelText.copyWith(fontWeight: FontWeight.w700, color: AppTheme.ink),
          ),
          const SizedBox(height: 8),
          if (_isLoadingCollabs)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_collaborators.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'All project members will be included automatically.',
                style: AppTheme.metadataText,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _collaborators.length,
                itemBuilder: (context, index) {
                  final user = _collaborators[index];
                  return CheckboxListTile(
                    title: Text(user.name, style: AppTheme.bodySmall.copyWith(color: AppTheme.ink)),
                    subtitle: user.username.isNotEmpty
                        ? Text('@${user.username}', style: AppTheme.metadataText)
                        : null,
                    value: _selectedMembers[user.id] ?? false,
                    onChanged: (v) => setState(() => _selectedMembers[user.id] = v ?? false),
                    activeColor: AppTheme.accent,
                    checkColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isCreating
                  ? null
                  : () async {
                      final name = _controller.text.trim();
                      if (name.isNotEmpty) {
                        setState(() => _isCreating = true);
                        try {
                          final memberUids =
                              _selectedMembers.entries.where((e) => e.value).map((e) => e.key).toList();
                          if (!memberUids.contains(widget.project.createdBy)) {
                            memberUids.add(widget.project.createdBy);
                          }

                          await ProjectService.instance.createChannel(
                            projectId: widget.projectId,
                            name: name,
                            invitedMembers: memberUids,
                            isPrivate: true,
                          );
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.dpDanger),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isCreating = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
              ),
              child: _isCreating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Channel', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
