import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

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
            title: 'Calls • ${project.title}',
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Call history',
                onPressed: _showHistory,
              ),
            ],
          ),
          body: StreamBuilder<ProjectCallSession?>(
            stream: ProjectService.instance.watchActiveProjectCall(widget.projectId),
            builder: (context, callSnapshot) {
              final activeCall = callSnapshot.data;

              if (activeCall != null && activeCall.active) {
                // ACTIVE CALL: Show call controls only
                return _buildActiveCallUI(context, activeCall, memberIds, isMobile);
              } else {
                // NO ACTIVE CALL: Show start options
                return _buildPreCallUI(context, project, memberIds, isMobile);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildPreCallUI(BuildContext context, Project project, List<String> memberIds, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Call Room Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.videocam_outlined, size: 40, color: AppTheme.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Ready to Start',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${memberIds.length} collaborators available',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Start Call Button
          ElevatedButton.icon(
            onPressed: () => _startCall(type: 'team'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.videocam),
            label: const Text('Start Team Call', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),

          // Schedule Button
          OutlinedButton.icon(
            onPressed: () => _showScheduleDialog(memberIds),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.calendar_today_outlined),
            label: const Text('Schedule Call', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 24),

          // Upcoming Calls Section
          const Text(
            'Upcoming Calls',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<ProjectCallSchedule>>(
            stream: ProjectService.instance.watchProjectCallSchedules(widget.projectId),
            builder: (context, scheduleSnapshot) {
              final schedules = scheduleSnapshot.data ?? [];
              final upcoming = schedules.where((schedule) => schedule.status == 'scheduled').toList();
              
              if (upcoming.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: const EmptyState(
                    icon: Icons.event_outlined,
                    title: 'No upcoming calls',
                    subtitle: 'Schedule a call to get started',
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: upcoming.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final schedule = upcoming[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(schedule.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(
                            'When: ${_formatDateTime(schedule.scheduledAt)} • ${schedule.durationMinutes} min',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCallUI(BuildContext context, ProjectCallSession activeCall, List<String> memberIds, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Call Status
          Card(
            color: const Color(0xFFFEF3C7),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 12, color: Color(0xFFD97706)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Call in progress...',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                    ),
                  ),
                  Text(
                    '${activeCall.participants.length} joined',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Call Control Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    setState(() => _audioEnabled = !_audioEnabled);
                    await ProjectService.instance.updateCallState(
                      projectId: widget.projectId,
                      callId: activeCall.id,
                      audioEnabled: _audioEnabled,
                    );
                  },
                  icon: Icon(_audioEnabled ? Icons.mic : Icons.mic_off),
                  label: Text(_audioEnabled ? 'Mute' : 'Unmute', style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    setState(() => _videoEnabled = !_videoEnabled);
                    await ProjectService.instance.updateCallState(
                      projectId: widget.projectId,
                      callId: activeCall.id,
                      videoEnabled: _videoEnabled,
                    );
                  },
                  icon: Icon(_videoEnabled ? Icons.videocam : Icons.videocam_off),
                  label: Text(_videoEnabled ? 'Stop' : 'Start', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openRoom(
              activeCall.roomUrl.isNotEmpty
                  ? activeCall.roomUrl
                  : 'https://meet.jit.si/${activeCall.roomName.isNotEmpty ? activeCall.roomName : 'teamsync-${widget.projectId}-${activeCall.id}'}',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Join Room', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ProjectService.instance.leaveProjectCall(projectId: widget.projectId, callId: activeCall.id),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.danger),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.call_end, size: 18),
            label: const Text('Leave Call', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 20),

          // Participants
          const Text(
            'Participants',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, AppUser>>(
            future: UserService.instance.getUsersByIds(activeCall.participants),
            builder: (context, usersSnapshot) {
              final users = usersSnapshot.data ?? {};
              if (activeCall.participants.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No participants yet', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: activeCall.participants.map((userId) {
                  final user = users[userId];
                  return Chip(
                    avatar: UserAvatar(
                      name: user?.name ?? user?.username ?? userId,
                      username: user?.username ?? userId,
                      size: 28,
                      imageUrl: user?.photoUrl,
                    ),
                    label: Text(user?.name.split(' ')[0] ?? user?.username ?? 'User', maxLines: 1),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
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
                          subtitle: Text('@${user?.username.isNotEmpty == true ? user!.username : '?'}'),
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

  Future<void> _showScheduleDialog(List<String> memberIds) async {
    final titleController = TextEditingController();
    final agendaController = TextEditingController();
    final descriptionController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    DateTime? scheduledAt;
    final invited = <String>{};
    var inviteAll = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Schedule Call'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Call title'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: agendaController,
                      decoration: const InputDecoration(labelText: 'Agenda / topic'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Discussion description'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Duration estimate (minutes)'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            scheduledAt == null
                                ? 'Choose date and time'
                                : _formatDateTime(scheduledAt!),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              initialDate: DateTime.now().add(const Duration(days: 1)),
                            );
                            if (date == null) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time == null) return;
                            setDialogState(() {
                              scheduledAt = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          },
                          child: const Text('Pick'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Invite all collaborators'),
                      value: inviteAll,
                      onChanged: (value) {
                        setDialogState(() {
                          inviteAll = value;
                          if (value) {
                            invited.clear();
                          }
                        });
                      },
                    ),
                    if (!inviteAll)
                      FutureBuilder<Map<String, AppUser>>(
                        future: UserService.instance.getUsersByIds(memberIds),
                        builder: (context, usersSnapshot) {
                          final users = usersSnapshot.data ?? {};
                          return Column(
                            children: memberIds.map((userId) {
                              final user = users[userId];
                              final label = user?.name ?? user?.username ?? userId;
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: invited.contains(userId),
                                onChanged: (checked) {
                                  setDialogState(() {
                                    if (checked == true) {
                                      invited.add(userId);
                                    } else {
                                      invited.remove(userId);
                                    }
                                  });
                                },
                                title: Text(label),
                              );
                            }).toList(),
                          );
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: scheduledAt == null ? null : () => Navigator.pop(dialogContext, true),
                  child: const Text('Schedule'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || scheduledAt == null) {
      return;
    }

    final inviteList = inviteAll ? memberIds : invited.toList();

    try {
      await ProjectService.instance.scheduleProjectCall(
        projectId: widget.projectId,
        title: titleController.text.trim().isEmpty ? 'Project Call' : titleController.text.trim(),
        agenda: agendaController.text.trim(),
        description: descriptionController.text.trim(),
        scheduledAt: scheduledAt!,
        durationMinutes: int.tryParse(durationController.text.trim()) ?? 30,
        invitedParticipants: inviteList,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _openRoom(String roomUrl) async {
    await launchUrl(Uri.parse(roomUrl), mode: LaunchMode.externalApplication);
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day $hour12:$minute $period';
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
  final VoidCallback onOpenRoom;
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
    required this.onOpenRoom,
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
              icon: Icons.meeting_room_outlined,
              label: 'Room',
              onPressed: onOpenRoom,
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
          UserAvatar(name: name, username: username, size: 44, imageUrl: imageUrl),
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
