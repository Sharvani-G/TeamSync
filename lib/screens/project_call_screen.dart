import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ProjectCallScreen extends StatefulWidget {
  final String projectId;

  const ProjectCallScreen({super.key, required this.projectId});

  @override
  State<ProjectCallScreen> createState() => _ProjectCallScreenState();
}

class _ProjectCallScreenState extends State<ProjectCallScreen> {
  bool _audioEnabled = true;
  bool _videoEnabled = true;
  bool _screenSharing = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(widget.projectId),
      builder: (context, projectSnapshot) {
        final project = projectSnapshot.data;
        if (projectSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (project == null) {
          return const Scaffold(body: Center(child: Text('Project not found')));
        }

        final memberIds = <String>{project.createdBy, ...project.collaborators.keys}.toList();

        return Scaffold(
          appBar: SimpleAppBar(
            title: 'Call • ${project.title}',
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: _showHistory,
              ),
            ],
          ),
          body: StreamBuilder<ProjectCallSession?>(
            stream: ProjectService.instance.watchActiveProjectCall(widget.projectId),
            builder: (context, callSnapshot) {
              final activeCall = callSnapshot.data;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF111827)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Project Call Room',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activeCall == null ? 'No active call' : 'Live ${activeCall.type} call',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Room state, invitations, participants, and call history are synchronized in Firestore.',
                          style: TextStyle(color: Colors.white.withOpacity(0.78), height: 1.45),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _InfoChip(icon: Icons.people_outline, label: '${project.collaboratorCount} collaborators'),
                            _InfoChip(icon: Icons.videocam_outlined, label: activeCall?.active == true ? 'Active' : 'Idle'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (activeCall == null) ...[
                    ElevatedButton.icon(
                      onPressed: () => _startCall(type: 'team'),
                      icon: const Icon(Icons.groups_outlined),
                      label: const Text('Start Team Call'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _startSelectedCall(memberIds),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Start Selected Call'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Collaborators',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<Map<String, AppUser>>(
                      future: UserService.instance.getUsersByIds(memberIds),
                      builder: (context, usersSnapshot) {
                        final users = usersSnapshot.data ?? {};
                        return Column(
                          children: memberIds.map((userId) {
                            final user = users[userId];
                            final isAdmin = userId == project.createdBy;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    name: user?.name ?? user?.username ?? userId,
                                    size: 38,
                                    imageUrl: user?.photoUrl,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user?.name ?? user?.username ?? userId,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '@${user?.username ?? userId.substring(0, 6)}',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isAdmin ? const Color(0xFFDBEAFE) : const Color(0xFFEDE9FE),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      isAdmin ? 'ADMIN' : 'Collaborator',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF6D28D9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ] else ...[
                    _LiveCallPanel(
                      call: activeCall,
                      projectId: widget.projectId,
                      audioEnabled: _audioEnabled,
                      videoEnabled: _videoEnabled,
                      screenSharing: _screenSharing,
                      onToggleAudio: () async {
                        setState(() => _audioEnabled = !_audioEnabled);
                        await ProjectService.instance.updateCallState(
                          projectId: widget.projectId,
                          callId: activeCall.id,
                          audioEnabled: _audioEnabled,
                        );
                      },
                      onToggleVideo: () async {
                        setState(() => _videoEnabled = !_videoEnabled);
                        await ProjectService.instance.updateCallState(
                          projectId: widget.projectId,
                          callId: activeCall.id,
                          videoEnabled: _videoEnabled,
                        );
                      },
                      onToggleScreenShare: () async {
                        setState(() => _screenSharing = !_screenSharing);
                        await ProjectService.instance.updateCallState(
                          projectId: widget.projectId,
                          callId: activeCall.id,
                          screenSharing: _screenSharing,
                        );
                      },
                      onJoin: () => ProjectService.instance.joinProjectCall(projectId: widget.projectId, callId: activeCall.id),
                      onLeave: () => ProjectService.instance.leaveProjectCall(projectId: widget.projectId, callId: activeCall.id),
                      onEnd: () => ProjectService.instance.endProjectCall(projectId: widget.projectId, callId: activeCall.id),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Participants',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<Map<String, AppUser>>(
                      future: UserService.instance.getUsersByIds(activeCall.participants),
                      builder: (context, usersSnapshot) {
                        final users = usersSnapshot.data ?? {};
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: activeCall.participants.map((userId) {
                            final user = users[userId];
                            return _ParticipantTile(
                              name: user?.name ?? user?.username ?? userId,
                              username: user?.username ?? userId,
                              imageUrl: user?.photoUrl,
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Call participants share room state, chat, and notifications in realtime.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.45),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _startCall({required String type}) async {
    try {
      await ProjectService.instance.startProjectCall(
        projectId: widget.projectId,
        type: type,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _startSelectedCall(List<String> memberIds) async {
    final selected = <String>{};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Participants'),
              content: SizedBox(
                width: double.maxFinite,
                child: FutureBuilder<Map<String, AppUser>>(
                  future: UserService.instance.getUsersByIds(memberIds),
                  builder: (context, usersSnapshot) {
                    final users = usersSnapshot.data ?? {};
                    return ListView(
                      shrinkWrap: true,
                      children: memberIds.where((id) => id != FirebaseAuth.instance.currentUser?.uid).map((userId) {
                        final user = users[userId];
                        final label = user?.name ?? user?.username ?? userId;
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selected.contains(userId),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selected.add(userId);
                              } else {
                                selected.remove(userId);
                              }
                            });
                          },
                          title: Text(label),
                          subtitle: Text('@${user?.username ?? userId.substring(0, 6)}'),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(dialogContext, selected), child: const Text('Start Call')),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      await ProjectService.instance.startProjectCall(
        projectId: widget.projectId,
        type: 'selected',
        invitedParticipants: result.toList(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _showHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: StreamBuilder<List<ProjectCallSession>>(
              stream: ProjectService.instance.watchProjectCallHistory(widget.projectId),
              builder: (context, snapshot) {
                final sessions = snapshot.data ?? [];
                if (sessions.isEmpty) {
                  return const Center(
                    child: EmptyState(
                      icon: Icons.history,
                      title: 'No call history',
                      subtitle: 'Call sessions will appear here after they are started.',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: session.active ? const Color(0xFFDCFCE7) : const Color(0xFFE5E7EB),
                            child: Icon(session.active ? Icons.fiber_manual_record : Icons.history, size: 18, color: session.active ? const Color(0xFF15803D) : AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(session.type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('Started by ${session.startedBy} · ${session.participants.length} participants', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _LiveCallPanel extends StatelessWidget {
  final ProjectCallSession call;
  final String projectId;
  final bool audioEnabled;
  final bool videoEnabled;
  final bool screenSharing;
  final VoidCallback onToggleAudio;
  final VoidCallback onToggleVideo;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onEnd;

  const _LiveCallPanel({
    required this.call,
    required this.projectId,
    required this.audioEnabled,
    required this.videoEnabled,
    required this.screenSharing,
    required this.onToggleAudio,
    required this.onToggleVideo,
    required this.onToggleScreenShare,
    required this.onJoin,
    required this.onLeave,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isHost = FirebaseAuth.instance.currentUser?.uid == call.startedBy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: call.participants
              .map(
                (userId) => Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person, size: 36, color: AppTheme.primary),
                        const SizedBox(height: 10),
                        Text(userId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ControlButton(
              icon: audioEnabled ? Icons.mic : Icons.mic_off,
              label: audioEnabled ? 'Mute' : 'Unmute',
              onPressed: onToggleAudio,
            ),
            _ControlButton(
              icon: videoEnabled ? Icons.videocam : Icons.videocam_off,
              label: videoEnabled ? 'Video off' : 'Video on',
              onPressed: onToggleVideo,
            ),
            _ControlButton(
              icon: screenSharing ? Icons.stop_screen_share : Icons.screen_share,
              label: screenSharing ? 'Stop share' : 'Share screen',
              onPressed: onToggleScreenShare,
            ),
            _ControlButton(
              icon: Icons.login,
              label: 'Join',
              onPressed: onJoin,
            ),
            _ControlButton(
              icon: Icons.logout,
              label: 'Leave',
              onPressed: onLeave,
            ),
            if (isHost)
              _ControlButton(
                icon: Icons.call_end,
                label: 'End call',
                destructive: true,
                onPressed: onEnd,
              ),
          ],
        ),
      ],
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final String name;
  final String username;
  final String? imageUrl;

  const _ParticipantTile({required this.name, required this.username, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          UserAvatar(name: name, size: 44, imageUrl: imageUrl),
          const SizedBox(height: 10),
          Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('@$username', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback onPressed;

  const _ControlButton({required this.icon, required this.label, required this.onPressed, this.destructive = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: destructive ? const Color(0xFFDC2626) : AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
